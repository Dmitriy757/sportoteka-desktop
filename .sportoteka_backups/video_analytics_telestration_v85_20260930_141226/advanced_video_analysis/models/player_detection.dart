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

  /// Canonical field coordinate in percent (0..100 x 0..100), produced by
  /// server-side pitch homography. Never infer this from bbox pixels.
  final Offset? fieldPosition;
  final double fieldConfidence;
  final double identityConfidence;
  final double jerseyConfidence;
  final double teamConfidence;
  final bool identityConfirmed;
  final Map<String, dynamic> raw;

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
    this.fieldPosition,
    this.fieldConfidence = 0,
    this.identityConfidence = 0,
    this.jerseyConfidence = 0,
    this.teamConfidence = 0,
    this.identityConfirmed = false,
    this.raw = const <String, dynamic>{},
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
    Offset? fieldPosition,
    double? fieldConfidence,
    double? identityConfidence,
    double? jerseyConfidence,
    double? teamConfidence,
    bool? identityConfirmed,
    Map<String, dynamic>? raw,
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
      fieldPosition: fieldPosition ?? this.fieldPosition,
      fieldConfidence: fieldConfidence ?? this.fieldConfidence,
      identityConfidence: identityConfidence ?? this.identityConfidence,
      jerseyConfidence: jerseyConfidence ?? this.jerseyConfidence,
      teamConfidence: teamConfidence ?? this.teamConfidence,
      identityConfirmed: identityConfirmed ?? this.identityConfirmed,
      raw: raw ?? this.raw,
    );
  }

  factory PlayerDetection.fromJson(Map<String, dynamic> json) {
    final trackId = _asInt(json['track_id'] ?? json['trackId'] ?? json['id']);
    final rawPlayerId = _asInt(json['player_id'] ?? json['playerId']);
    final identityConfidence = _confidence(json, const [
      'identity_confidence',
      'identityConfidence',
      'player_confidence',
      'playerConfidence',
      'identity_score',
    ]);
    final jerseyConfidence = _confidence(json, const [
      'jersey_confidence',
      'jerseyConfidence',
      'number_confidence',
      'numberConfidence',
      'ocr_confidence',
    ]);
    final teamConfidence = _confidence(json, const [
      'team_confidence',
      'teamConfidence',
      'side_confidence',
    ]);
    final fieldConfidenceRaw = _confidence(json, const [
      'field_confidence',
      'fieldConfidence',
      'homography_confidence',
      'homographyConfidence',
      'pitch_confidence',
    ]);
    final identityConfirmed = _asBool(
      json['identity_confirmed'] ??
          json['identityConfirmed'] ??
          json['manual_identity'],
    );

    final identityAccepted = rawPlayerId > 0 &&
        (identityConfirmed ||
            identityConfidence == null ||
            identityConfidence >= .72);
    final rawNumber = _asInt(
      json['number'] ??
          json['jersey'] ??
          json['shirt_number'] ??
          json['jersey_number'],
    );
    final numberAccepted =
        rawNumber > 0 && (jerseyConfidence == null || jerseyConfidence >= .55);
    final rawTeam =
        (json['team_id'] ?? json['teamId'] ?? json['team'] ?? '').toString();
    final teamAccepted = teamConfidence == null || teamConfidence >= .50;
    final fieldPosition = _parseFieldPosition(json);
    final fieldAccepted = fieldPosition != null &&
        (fieldConfidenceRaw == null || fieldConfidenceRaw >= .35);

    final rawName = (json['name'] ?? json['player_name'] ?? json['label'] ?? '')
        .toString()
        .trim();

    return PlayerDetection(
      id: identityAccepted
          ? rawPlayerId.toString()
          : (json['id'] ?? trackId).toString(),
      number: numberAccepted ? rawNumber : 0,
      name: identityAccepted ? rawName : '',
      bbox: _parseBBox(json),
      teamColor:
          _parseColor(json['team_color'] ?? json['teamColor'] ?? json['color']),
      teamId: teamAccepted ? rawTeam : '',
      confidence:
          _asDouble(json['confidence'] ?? json['conf'] ?? json['score']),
      position: (json['position'] ?? '').toString(),
      trackId: trackId,
      trajectory:
          _parseTrajectory(json['trajectory'] ?? json['trail'] ?? json['path']),
      metrics: Map<String, dynamic>.from(
        json['metrics'] is Map ? json['metrics'] as Map : const {},
      ),
      fieldPosition: fieldAccepted ? fieldPosition : null,
      fieldConfidence: fieldAccepted
          ? (fieldConfidenceRaw ?? 1.0)
          : (fieldConfidenceRaw ?? 0.0),
      identityConfidence: identityConfidence ?? (identityAccepted ? 1.0 : 0.0),
      jerseyConfidence: jerseyConfidence ?? (numberAccepted ? 1.0 : 0.0),
      teamConfidence: teamConfidence ?? (rawTeam.isNotEmpty ? 1.0 : 0.0),
      identityConfirmed: identityConfirmed,
      raw: Map<String, dynamic>.from(json),
    );
  }

  static Offset? _parseFieldPosition(Map<String, dynamic> json) {
    double? x = _optionalDouble(
      json['field_x'] ?? json['fieldX'] ?? json['pitch_x'] ?? json['pitchX'],
    );
    double? y = _optionalDouble(
      json['field_y'] ?? json['fieldY'] ?? json['pitch_y'] ?? json['pitchY'],
    );
    final nested = json['field_position'] ?? json['fieldPosition'];
    if ((x == null || y == null) && nested is Map) {
      x ??= _optionalDouble(nested['x_percent'] ?? nested['x'] ?? nested['nx']);
      y ??= _optionalDouble(nested['y_percent'] ?? nested['y'] ?? nested['ny']);
    }
    if (x == null || y == null || !x.isFinite || !y.isFinite) return null;
    if (x >= 0 && x <= 1.2 && y >= 0 && y <= 1.2) {
      x *= 100.0;
      y *= 100.0;
    }
    return Offset(
      x.clamp(0.0, 100.0).toDouble(),
      y.clamp(0.0, 100.0).toDouble(),
    );
  }

  static Rect _parseBBox(Map<String, dynamic> json) {
    final dynamic raw =
        json['bbox'] ?? json['box'] ?? json['xyxy'] ?? json['rect'];
    if (raw is List && raw.length >= 4) {
      return Rect.fromLTRB(
        _asDouble(raw[0]),
        _asDouble(raw[1]),
        _asDouble(raw[2]),
        _asDouble(raw[3]),
      );
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
    if (json.containsKey('x') ||
        json.containsKey('w') ||
        json.containsKey('width')) {
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
    return raw
        .map((e) {
          if (e is Map) return Offset(_asDouble(e['x']), _asDouble(e['y']));
          if (e is List && e.length >= 2) {
            return Offset(_asDouble(e[0]), _asDouble(e[1]));
          }
          return Offset.zero;
        })
        .where((p) => p != Offset.zero)
        .toList();
  }

  static double? _confidence(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = _optionalDouble(json[key]);
      if (value == null || !value.isFinite) continue;
      final normalized = value > 1 && value <= 100 ? value / 100.0 : value;
      return normalized.clamp(0.0, 1.0).toDouble();
    }
    return null;
  }

  static int _parseColor(dynamic value) {
    if (value == null) return 0xFF00A750;
    if (value is int) return value <= 0xFFFFFF ? (0xFF000000 | value) : value;
    final text = value.toString().trim();
    if (text.isEmpty) return 0xFF00A750;
    final normalized =
        text.replaceAll('#', '').replaceAll('0x', '').replaceAll('0X', '');
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return 0xFF00A750;
    return parsed <= 0xFFFFFF ? (0xFF000000 | parsed) : parsed;
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ??
        double.tryParse(value.toString())?.round() ??
        0;
  }

  static double _asDouble(dynamic value) => _optionalDouble(value) ?? 0.0;

  static double? _optionalDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = (value ?? '').toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes' || s == 'confirmed';
  }
}
