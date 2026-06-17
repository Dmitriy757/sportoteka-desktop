import 'dart:convert';
import 'package:flutter/material.dart';

enum AnnotationToolType {
  freehand,
  line,
  arrow,
  rect,
  circle,
  text,
}

class AnnotationItem {
  final String id;
  final AnnotationToolType type;
  final Color color;
  final double strokeWidth;

  final Offset? start;
  final Offset? end;

  final List<Offset>? points;

  final String? text;
  final double? fontSize;
  final Offset? textOffset;

  AnnotationItem({
    required this.id,
    required this.type,
    required this.color,
    required this.strokeWidth,
    this.start,
    this.end,
    this.points,
    this.text,
    this.fontSize,
    this.textOffset,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'color': color.value,
      'strokeWidth': strokeWidth,
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
      'fontSize': fontSize,
      'textX': textOffset?.dx,
      'textY': textOffset?.dy,
    };
  }

  factory AnnotationItem.fromJson(Map<String, dynamic> json) {
    return AnnotationItem(
      id: (json['id'] ?? '').toString(),
      type: AnnotationToolType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AnnotationToolType.line,
      ),
      color: Color((json['color'] as num?)?.toInt() ?? Colors.red.value),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      start: (json['startX'] != null && json['startY'] != null)
          ? Offset(
              (json['startX'] as num).toDouble(),
              (json['startY'] as num).toDouble(),
            )
          : null,
      end: (json['endX'] != null && json['endY'] != null)
          ? Offset(
              (json['endX'] as num).toDouble(),
              (json['endY'] as num).toDouble(),
            )
          : null,
      points: (json['points'] as List?)
          ?.map((e) => Offset(
                (e['x'] as num).toDouble(),
                (e['y'] as num).toDouble(),
              ))
          .toList(),
      text: json['text']?.toString(),
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      textOffset: (json['textX'] != null && json['textY'] != null)
          ? Offset(
              (json['textX'] as num).toDouble(),
              (json['textY'] as num).toDouble(),
            )
          : null,
    );
  }

  static String encodeList(List<AnnotationItem> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }

  static List<AnnotationItem> decodeList(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) => AnnotationItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}