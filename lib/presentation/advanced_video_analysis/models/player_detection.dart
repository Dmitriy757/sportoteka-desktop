// lib/presentation/advanced_video_analysis/models/player_detection.dart

import 'package:flutter/material.dart';

class PlayerDetection {
  final String id;
  final int number;
  final String name;
  final Rect bbox;
  final int teamColor;
  final String teamId;
  final double confidence;
  final String position;
  final int trackId;
  final List<Offset> trajectory;
  final Map<String, dynamic> metrics;

  PlayerDetection({
    required this.id,
    required this.number,
    required this.name,
    required this.bbox,
    required this.teamColor,
    required this.teamId,
    required this.confidence,
    required this.position,
    required this.trackId,
    required this.trajectory,
    required this.metrics,
  });


  PlayerDetection copyWith({
    String? id,
    int? number,
    String? name,
    Rect? bbox,
    int? teamColor,
    String? teamId,
    double? confidence,
    String? position,
    int? trackId,
    List<Offset>? trajectory,
    Map<String, dynamic>? metrics,
  }) {
    return PlayerDetection(
      id: id ?? this.id,
      number: number ?? this.number,
      name: name ?? this.name,
      bbox: bbox ?? this.bbox,
      teamColor: teamColor ?? this.teamColor,
      teamId: teamId ?? this.teamId,
      confidence: confidence ?? this.confidence,
      position: position ?? this.position,
      trackId: trackId ?? this.trackId,
      trajectory: trajectory ?? this.trajectory,
      metrics: metrics ?? this.metrics,
    );
  }

  factory PlayerDetection.fromJson(Map<String, dynamic> json) {
    final trackId = _asInt(json['track_id'] ?? json['trackId'] ?? json['id']);
    final number = _asInt(json['number'] ?? json['jersey'] ?? json['shirt_number']);

    return PlayerDetection(
      id: (json['id'] ?? json['player_id'] ?? json['playerId'] ?? trackId).toString(),
      number: number,
      name: (json['name'] ?? json['player_name'] ?? json['label'] ?? '').toString(),
      bbox: _parseBBox(json),
      teamColor: _parseColor(json['team_color'] ?? json['teamColor'] ?? json['color']),
      teamId: (json['team_id'] ?? json['teamId'] ?? json['team'] ?? '').toString(),
      confidence: _asDouble(json['confidence'] ?? json['conf'] ?? json['score']),
      position: (json['position'] ?? '').toString(),
      trackId: trackId,
      trajectory: _parseTrajectory(json['trajectory'] ?? json['trail'] ?? json['path']),
      metrics: Map<String, dynamic>.from(json['metrics'] is Map ? json['metrics'] as Map : const {}),
    );
  }

  static Rect _parseBBox(Map<String, dynamic> json) {
    final dynamic raw = json['bbox'] ?? json['box'] ?? json['xyxy'] ?? json['rect'];

    if (raw is List && raw.length >= 4) {
      final a = _asDouble(raw[0]);
      final b = _asDouble(raw[1]);
      final c = _asDouble(raw[2]);
      final d = _asDouble(raw[3]);

      // YOLO чаще отдаёт [x1, y1, x2, y2]. Если третий/четвёртый похожи на width/height,
      // всё равно Rect.fromLTRB ниже не сломает реальные xyxy. Для x/y/w/h сервер обычно шлёт map.
      return Rect.fromLTRB(a, b, c, d);
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map.containsKey('x1') || map.containsKey('left')) {
        return Rect.fromLTRB(
          _asDouble(map['x1'] ?? map['left']),
          _asDouble(map['y1'] ?? map['top']),
          _asDouble(map['x2'] ?? map['right']),
          _asDouble(map['y2'] ?? map['bottom']),
        );
      }
      if (map.containsKey('x') || map.containsKey('w')) {
        return Rect.fromLTWH(
          _asDouble(map['x']),
          _asDouble(map['y']),
          _asDouble(map['w'] ?? map['width']),
          _asDouble(map['h'] ?? map['height']),
        );
      }
    }

    if (json.containsKey('x1') || json.containsKey('left')) {
      return Rect.fromLTRB(
        _asDouble(json['x1'] ?? json['left']),
        _asDouble(json['y1'] ?? json['top']),
        _asDouble(json['x2'] ?? json['right']),
        _asDouble(json['y2'] ?? json['bottom']),
      );
    }

    if (json.containsKey('x') || json.containsKey('w') || json.containsKey('width')) {
      return Rect.fromLTWH(
        _asDouble(json['x']),
        _asDouble(json['y']),
        _asDouble(json['w'] ?? json['width']),
        _asDouble(json['h'] ?? json['height']),
      );
    }

    return Rect.zero;
  }

  static List<Offset> _parseTrajectory(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) {
        return Offset(_asDouble(e['x']), _asDouble(e['y']));
      }
      if (e is List && e.length >= 2) {
        return Offset(_asDouble(e[0]), _asDouble(e[1]));
      }
      return Offset.zero;
    }).where((p) => p != Offset.zero).toList();
  }

  static int _parseColor(dynamic value) {
    if (value == null) return 0xFF00A750;
    if (value is int) {
      return value <= 0xFFFFFF ? (0xFF000000 | value) : value;
    }
    final text = value.toString().trim();
    if (text.isEmpty) return 0xFF00A750;
    final normalized = text
        .replaceAll('#', '')
        .replaceAll('0x', '')
        .replaceAll('0X', '');
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return 0xFF00A750;
    return parsed <= 0xFFFFFF ? (0xFF000000 | parsed) : parsed;
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? double.tryParse(value.toString())?.round() ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }
}
