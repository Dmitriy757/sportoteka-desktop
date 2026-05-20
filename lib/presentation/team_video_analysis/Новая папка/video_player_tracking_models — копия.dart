import 'dart:ui';
import 'package:flutter/material.dart';

enum PlayerMarkerType {
  triangle,
  circle,
  square,
  diamond,
}

class TrackedPoint {
  final int timeMs;
  final double x; // 0..1
  final double y; // 0..1
  final bool isManual;
  final double confidence;

  const TrackedPoint({
    required this.timeMs,
    required this.x,
    required this.y,
    this.isManual = true,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'time_ms': timeMs,
      'x': x,
      'y': y,
      'is_manual': isManual ? 1 : 0,
      'confidence': confidence,
    };
  }

  factory TrackedPoint.fromJson(Map<String, dynamic> json) {
    return TrackedPoint(
      timeMs: int.tryParse('${json['time_ms']}') ?? 0,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      isManual: (json['is_manual'] ?? 1).toString() == '1',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class TrackedPlayer {
  final int playerId;
  final String playerName;
  final int? number;
  final String position;
  final PlayerMarkerType markerType;
  final Color markerColor;
  final List<TrackedPoint> points;
  final bool enabled;

  const TrackedPlayer({
    required this.playerId,
    required this.playerName,
    this.number,
    this.position = '',
    this.markerType = PlayerMarkerType.triangle,
    this.markerColor = Colors.green,
    this.points = const [],
    this.enabled = true,
  });

  TrackedPlayer copyWith({
    int? playerId,
    String? playerName,
    int? number,
    String? position,
    PlayerMarkerType? markerType,
    Color? markerColor,
    List<TrackedPoint>? points,
    bool? enabled,
  }) {
    return TrackedPlayer(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      number: number ?? this.number,
      position: position ?? this.position,
      markerType: markerType ?? this.markerType,
      markerColor: markerColor ?? this.markerColor,
      points: points ?? this.points,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'player_id': playerId,
      'player_name': playerName,
      'number': number,
      'position': position,
      'marker_type': markerType.name,
      'marker_color': markerColor.value,
      'enabled': enabled ? 1 : 0,
      'points': points.map((e) => e.toJson()).toList(),
    };
  }

  factory TrackedPlayer.fromJson(Map<String, dynamic> json) {
    final typeName = '${json['marker_type'] ?? 'triangle'}';

    return TrackedPlayer(
      playerId: int.tryParse('${json['player_id']}') ?? 0,
      playerName: '${json['player_name'] ?? ''}',
      number: json['number'] == null ? null : int.tryParse('${json['number']}'),
      position: '${json['position'] ?? ''}',
      markerType: PlayerMarkerType.values.firstWhere(
        (e) => e.name == typeName,
        orElse: () => PlayerMarkerType.triangle,
      ),
      markerColor: Color(
        int.tryParse('${json['marker_color']}') ?? Colors.green.value,
      ),
      enabled: '${json['enabled'] ?? 1}' == '1',
      points: (json['points'] is List)
          ? (json['points'] as List)
              .map((e) => TrackedPoint.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [],
    );
  }
}

class TrackingStats {
  final double totalDistanceUnits;
  final double avgSpeedUnitsPerSec;
  final double maxSpeedUnitsPerSec;

  const TrackingStats({
    required this.totalDistanceUnits,
    required this.avgSpeedUnitsPerSec,
    required this.maxSpeedUnitsPerSec,
  });
}