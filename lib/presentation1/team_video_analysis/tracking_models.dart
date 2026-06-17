import 'dart:ui';
import 'package:flutter/material.dart';

enum PlayerMarkerType {
  box,
  circle,
  triangle,
}

class TrackPoint {
  final Offset position;
  final int timeMs;
  final double speed;

  final double vx;
  final double vy;
  final double ax;
  final double ay;

  final Rect? rect;

  const TrackPoint({
    required this.position,
    required this.timeMs,
    this.speed = 0,
    this.vx = 0,
    this.vy = 0,
    this.ax = 0,
    this.ay = 0,
    this.rect,
  });

  Rect? get boundingBox => rect;

  Map<String, dynamic> toJson() {
    return {
      'x': position.dx,
      'y': position.dy,
      'timeMs': timeMs,
      'speed': speed,
      'vx': vx,
      'vy': vy,
      'ax': ax,
      'ay': ay,
      'rect': rect == null
          ? null
          : {
              'left': rect!.left,
              'top': rect!.top,
              'right': rect!.right,
              'bottom': rect!.bottom,
            },
    };
  }

  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    Rect? parsedRect;
    final rawRect = json['rect'] ?? json['boundingBox'];
    if (rawRect is Map) {
      parsedRect = Rect.fromLTRB(
        (rawRect['left'] ?? 0).toDouble(),
        (rawRect['top'] ?? 0).toDouble(),
        (rawRect['right'] ?? 0).toDouble(),
        (rawRect['bottom'] ?? 0).toDouble(),
      );
    }

    return TrackPoint(
      position: Offset(
        (json['x'] ?? 0).toDouble(),
        (json['y'] ?? 0).toDouble(),
      ),
      timeMs: (json['timeMs'] ?? 0) as int,
      speed: (json['speed'] ?? 0).toDouble(),
      vx: (json['vx'] ?? 0).toDouble(),
      vy: (json['vy'] ?? 0).toDouble(),
      ax: (json['ax'] ?? 0).toDouble(),
      ay: (json['ay'] ?? 0).toDouble(),
      rect: parsedRect,
    );
  }
}

class DetectedPlayerBox {
  final int id;
  final Rect rect;
  final double confidence;
  final int? classId;
  final String? label;

  const DetectedPlayerBox({
    required this.id,
    required this.rect,
    this.confidence = 0,
    this.classId,
    this.label,
  });

  Offset get center => rect.center;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'left': rect.left,
      'top': rect.top,
      'right': rect.right,
      'bottom': rect.bottom,
      'confidence': confidence,
      'classId': classId,
      'label': label,
    };
  }

  factory DetectedPlayerBox.fromJson(Map<String, dynamic> json) {
    final left = (json['left'] ?? json['x'] ?? 0).toDouble();
    final top = (json['top'] ?? json['y'] ?? 0).toDouble();

    final right = json['right'] != null
        ? (json['right']).toDouble()
        : left + (json['width'] ?? 0).toDouble();

    final bottom = json['bottom'] != null
        ? (json['bottom']).toDouble()
        : top + (json['height'] ?? 0).toDouble();

    return DetectedPlayerBox(
      id: (json['id'] ?? 0) as int,
      rect: Rect.fromLTRB(left, top, right, bottom),
      confidence: (json['confidence'] ?? 0).toDouble(),
      classId: json['classId'] as int?,
      label: json['label']?.toString(),
    );
  }
}

class PlayerTrack {
  final String id;
  int? boundPlayerId;
  String boundPlayerName;
  final Color color;
  final List<TrackPoint> points;
  double? speed;
  final bool isLocked;
  final int createdAtMs;
  final int lastSeenTimeMs;
  final Rect? lockedBox;

  final String? teamTag;
  final int? jerseyNumber;

  PlayerTrack({
    required this.id,
    required this.boundPlayerName,
    required this.color,
    required this.points,
    required this.createdAtMs,
    required this.lastSeenTimeMs,
    this.boundPlayerId,
    this.speed,
    this.isLocked = false,
    this.lockedBox,
    this.teamTag,
    this.jerseyNumber,
  });

  TrackPoint? get lastPoint => points.isNotEmpty ? points.last : null;

  Offset? get currentPosition => lastPoint?.position;

  Rect? get currentBoundingBox => lastPoint?.rect ?? lockedBox;

  PlayerTrack copyWith({
    String? id,
    int? boundPlayerId,
    String? boundPlayerName,
    Color? color,
    List<TrackPoint>? points,
    double? speed,
    bool? isLocked,
    int? createdAtMs,
    int? lastSeenTimeMs,
    Rect? lockedBox,
    String? teamTag,
    int? jerseyNumber,
  }) {
    return PlayerTrack(
      id: id ?? this.id,
      boundPlayerId: boundPlayerId ?? this.boundPlayerId,
      boundPlayerName: boundPlayerName ?? this.boundPlayerName,
      color: color ?? this.color,
      points: points ?? this.points,
      speed: speed ?? this.speed,
      isLocked: isLocked ?? this.isLocked,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      lastSeenTimeMs: lastSeenTimeMs ?? this.lastSeenTimeMs,
      lockedBox: lockedBox ?? this.lockedBox,
      teamTag: teamTag ?? this.teamTag,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boundPlayerId': boundPlayerId,
      'boundPlayerName': boundPlayerName,
      'color': color.value,
      'speed': speed,
      'isLocked': isLocked,
      'createdAtMs': createdAtMs,
      'lastSeenTimeMs': lastSeenTimeMs,
      'lockedBox': lockedBox == null
          ? null
          : {
              'left': lockedBox!.left,
              'top': lockedBox!.top,
              'right': lockedBox!.right,
              'bottom': lockedBox!.bottom,
            },
      'teamTag': teamTag,
      'jerseyNumber': jerseyNumber,
      'points': points.map((e) => e.toJson()).toList(),
    };
  }

  factory PlayerTrack.fromJson(Map<String, dynamic> json) {
    Rect? parsedLockedBox;
    final rawLockedBox = json['lockedBox'];
    if (rawLockedBox is Map) {
      parsedLockedBox = Rect.fromLTRB(
        (rawLockedBox['left'] ?? 0).toDouble(),
        (rawLockedBox['top'] ?? 0).toDouble(),
        (rawLockedBox['right'] ?? 0).toDouble(),
        (rawLockedBox['bottom'] ?? 0).toDouble(),
      );
    }

    final rawPoints = (json['points'] as List?) ?? const [];

    return PlayerTrack(
      id: json['id']?.toString() ?? '',
      boundPlayerId: json['boundPlayerId'] as int?,
      boundPlayerName: json['boundPlayerName']?.toString() ?? 'Игрок',
      color: Color((json['color'] ?? Colors.red.value) as int),
      speed: json['speed'] == null ? null : (json['speed'] as num).toDouble(),
      isLocked: json['isLocked'] == true,
      createdAtMs: (json['createdAtMs'] ?? 0) as int,
      lastSeenTimeMs: (json['lastSeenTimeMs'] ?? 0) as int,
      lockedBox: parsedLockedBox,
      teamTag: json['teamTag']?.toString(),
      jerseyNumber: json['jerseyNumber'] as int?,
      points: rawPoints
          .whereType<Map>()
          .map((e) => TrackPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class TrackingStats {
  final double totalDistance;
  final double averageSpeed;
  final double maxSpeed;
  final int durationMs;

  const TrackingStats({
    required this.totalDistance,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.durationMs,
  });

  const TrackingStats.empty()
      : totalDistance = 0,
        averageSpeed = 0,
        maxSpeed = 0,
        durationMs = 0;
}

class BallPoint {
  final Offset position;
  final int timeMs;
  final double confidence;
  final Rect? rect;

  const BallPoint({
    required this.position,
    required this.timeMs,
    this.confidence = 0,
    this.rect,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': position.dx,
      'y': position.dy,
      'timeMs': timeMs,
      'confidence': confidence,
      'rect': rect == null
          ? null
          : {
              'left': rect!.left,
              'top': rect!.top,
              'right': rect!.right,
              'bottom': rect!.bottom,
            },
    };
  }

  factory BallPoint.fromJson(Map<String, dynamic> json) {
    Rect? parsedRect;
    final rawRect = json['rect'];
    if (rawRect is Map) {
      parsedRect = Rect.fromLTRB(
        (rawRect['left'] ?? 0).toDouble(),
        (rawRect['top'] ?? 0).toDouble(),
        (rawRect['right'] ?? 0).toDouble(),
        (rawRect['bottom'] ?? 0).toDouble(),
      );
    }

    return BallPoint(
      position: Offset(
        (json['x'] ?? 0).toDouble(),
        (json['y'] ?? 0).toDouble(),
      ),
      timeMs: (json['timeMs'] ?? 0) as int,
      confidence: (json['confidence'] ?? 0).toDouble(),
      rect: parsedRect,
    );
  }
}

class BallTrack {
  final List<BallPoint> points;
  final int lastSeenTimeMs;
  final Rect? lastRect;

  const BallTrack({
    required this.points,
    required this.lastSeenTimeMs,
    this.lastRect,
  });

  BallPoint? get lastPoint => points.isNotEmpty ? points.last : null;

  Map<String, dynamic> toJson() {
    return {
      'lastSeenTimeMs': lastSeenTimeMs,
      'lastRect': lastRect == null
          ? null
          : {
              'left': lastRect!.left,
              'top': lastRect!.top,
              'right': lastRect!.right,
              'bottom': lastRect!.bottom,
            },
      'points': points.map((e) => e.toJson()).toList(),
    };
  }

  factory BallTrack.fromJson(Map<String, dynamic> json) {
    Rect? parsedRect;
    final rawRect = json['lastRect'];
    if (rawRect is Map) {
      parsedRect = Rect.fromLTRB(
        (rawRect['left'] ?? 0).toDouble(),
        (rawRect['top'] ?? 0).toDouble(),
        (rawRect['right'] ?? 0).toDouble(),
        (rawRect['bottom'] ?? 0).toDouble(),
      );
    }

    final rawPoints = (json['points'] as List?) ?? const [];

    return BallTrack(
      points: rawPoints
          .whereType<Map>()
          .map((e) => BallPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      lastSeenTimeMs: (json['lastSeenTimeMs'] ?? 0) as int,
      lastRect: parsedRect,
    );
  }
}

class BallPossessionSegment {
  final String trackId;
  final String playerName;
  final String? teamTag;
  final int startedAtMs;
  final int endedAtMs;

  const BallPossessionSegment({
    required this.trackId,
    required this.playerName,
    required this.teamTag,
    required this.startedAtMs,
    required this.endedAtMs,
  });

  int get durationMs => endedAtMs - startedAtMs;

  Map<String, dynamic> toJson() {
    return {
      'trackId': trackId,
      'playerName': playerName,
      'teamTag': teamTag,
      'startedAtMs': startedAtMs,
      'endedAtMs': endedAtMs,
      'durationMs': durationMs,
    };
  }

  factory BallPossessionSegment.fromJson(Map<String, dynamic> json) {
    return BallPossessionSegment(
      trackId: json['trackId']?.toString() ?? '',
      playerName: json['playerName']?.toString() ?? 'Игрок',
      teamTag: json['teamTag']?.toString(),
      startedAtMs: (json['startedAtMs'] ?? 0) as int,
      endedAtMs: (json['endedAtMs'] ?? 0) as int,
    );
  }
}

class PassArrow {
  final String fromTrackId;
  final String toTrackId;
  final Offset from;
  final Offset to;
  final int timeMs;
  final double confidence;

  const PassArrow({
    required this.fromTrackId,
    required this.toTrackId,
    required this.from,
    required this.to,
    required this.timeMs,
    required this.confidence,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromTrackId': fromTrackId,
      'toTrackId': toTrackId,
      'from': {
        'x': from.dx,
        'y': from.dy,
      },
      'to': {
        'x': to.dx,
        'y': to.dy,
      },
      'timeMs': timeMs,
      'confidence': confidence,
    };
  }

  factory PassArrow.fromJson(Map<String, dynamic> json) {
    final rawFrom = json['from'] as Map<String, dynamic>? ?? {};
    final rawTo = json['to'] as Map<String, dynamic>? ?? {};

    return PassArrow(
      fromTrackId: json['fromTrackId']?.toString() ?? '',
      toTrackId: json['toTrackId']?.toString() ?? '',
      from: Offset(
        (rawFrom['x'] ?? 0).toDouble(),
        (rawFrom['y'] ?? 0).toDouble(),
      ),
      to: Offset(
        (rawTo['x'] ?? 0).toDouble(),
        (rawTo['y'] ?? 0).toDouble(),
      ),
      timeMs: (json['timeMs'] ?? 0) as int,
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}

class PassEdge {
  final String fromTrackId;
  final String toTrackId;
  final int count;
  final String? fromTeamTag;
  final String? toTeamTag;

  const PassEdge({
    required this.fromTrackId,
    required this.toTrackId,
    required this.count,
    this.fromTeamTag,
    this.toTeamTag,
  });

  PassEdge copyWith({
    int? count,
    String? fromTrackId,
    String? toTrackId,
    String? fromTeamTag,
    String? toTeamTag,
  }) {
    return PassEdge(
      fromTrackId: fromTrackId ?? this.fromTrackId,
      toTrackId: toTrackId ?? this.toTrackId,
      count: count ?? this.count,
      fromTeamTag: fromTeamTag ?? this.fromTeamTag,
      toTeamTag: toTeamTag ?? this.toTeamTag,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromTrackId': fromTrackId,
      'toTrackId': toTrackId,
      'count': count,
      'fromTeamTag': fromTeamTag,
      'toTeamTag': toTeamTag,
    };
  }

  factory PassEdge.fromJson(Map<String, dynamic> json) {
    return PassEdge(
      fromTrackId: json['fromTrackId']?.toString() ?? '',
      toTrackId: json['toTrackId']?.toString() ?? '',
      count: (json['count'] ?? 0) as int,
      fromTeamTag: json['fromTeamTag']?.toString(),
      toTeamTag: json['toTeamTag']?.toString(),
    );
  }
}