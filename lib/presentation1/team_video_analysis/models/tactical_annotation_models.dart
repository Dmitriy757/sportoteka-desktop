import 'dart:convert';
import 'package:flutter/material.dart';

enum TacticalToolType {
  select,
  passArrow,
  runArrow,
  straightLine,
  dashedLine,
  circle,
  rect,
  zone,
  playerMarker,
  text,
  freeDraw,
  eraser,
}

enum TacticalLineStyle {
  solid,
  dashed,
}

class TacticalAnnotation {
  final String id;
  final TacticalToolType type;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final TacticalLineStyle lineStyle;

  final Offset? start;
  final Offset? end;

  final List<Offset>? points;

  final String? text;
  final Offset? textOffset;
  final double? fontSize;

  final bool filled;

  const TacticalAnnotation({
    required this.id,
    required this.type,
    required this.color,
    required this.strokeWidth,
    this.opacity = 1.0,
    this.lineStyle = TacticalLineStyle.solid,
    this.start,
    this.end,
    this.points,
    this.text,
    this.textOffset,
    this.fontSize,
    this.filled = false,
  });

  TacticalAnnotation copyWith({
    String? id,
    TacticalToolType? type,
    Color? color,
    double? strokeWidth,
    double? opacity,
    TacticalLineStyle? lineStyle,
    Offset? start,
    Offset? end,
    List<Offset>? points,
    String? text,
    Offset? textOffset,
    double? fontSize,
    bool? filled,
  }) {
    return TacticalAnnotation(
      id: id ?? this.id,
      type: type ?? this.type,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      lineStyle: lineStyle ?? this.lineStyle,
      start: start ?? this.start,
      end: end ?? this.end,
      points: points ?? this.points,
      text: text ?? this.text,
      textOffset: textOffset ?? this.textOffset,
      fontSize: fontSize ?? this.fontSize,
      filled: filled ?? this.filled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'color': color.value,
      'strokeWidth': strokeWidth,
      'opacity': opacity,
      'lineStyle': lineStyle.name,
      'startX': start?.dx,
      'startY': start?.dy,
      'endX': end?.dx,
      'endY': end?.dy,
      'points': points
          ?.map((p) => {
                'x': p.dx,
                'y': p.dy,
              })
          .toList(),
      'text': text,
      'textX': textOffset?.dx,
      'textY': textOffset?.dy,
      'fontSize': fontSize,
      'filled': filled,
    };
  }

  factory TacticalAnnotation.fromJson(Map<String, dynamic> json) {
    TacticalToolType parseType(dynamic raw) {
      final value = (raw ?? '').toString();
      return TacticalToolType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TacticalToolType.straightLine,
      );
    }

    TacticalLineStyle parseLineStyle(dynamic raw) {
      final value = (raw ?? '').toString();
      return TacticalLineStyle.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TacticalLineStyle.solid,
      );
    }

    Offset? parseOffset(dynamic x, dynamic y) {
      if (x == null || y == null) return null;
      return Offset(
        (x as num).toDouble(),
        (y as num).toDouble(),
      );
    }

    List<Offset>? parsePoints(dynamic raw) {
      if (raw is! List) return null;
      return raw.map((e) {
        return Offset(
          (e['x'] as num).toDouble(),
          (e['y'] as num).toDouble(),
        );
      }).toList();
    }

    return TacticalAnnotation(
      id: (json['id'] ?? '').toString(),
      type: parseType(json['type']),
      color: Color((json['color'] as num?)?.toInt() ?? Colors.red.value),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 4.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      lineStyle: parseLineStyle(json['lineStyle']),
      start: parseOffset(json['startX'], json['startY']),
      end: parseOffset(json['endX'], json['endY']),
      points: parsePoints(json['points']),
      text: json['text']?.toString(),
      textOffset: parseOffset(json['textX'], json['textY']),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
      filled: json['filled'] == true || json['filled'] == 1 || json['filled'] == '1',
    );
  }

  static String encodeList(List<TacticalAnnotation> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }

  static List<TacticalAnnotation> decodeList(String raw) {
    if (raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .map((e) => TacticalAnnotation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}