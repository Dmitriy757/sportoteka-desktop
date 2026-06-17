import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/team_video_analysis/tracking_models.dart';

class TrackedPlayer {
  final String id;
  final String name;
  final Color color;
  final Offset position;
  final Rect boundingBox;
  final List<Offset> trail;
  final bool isSelected;
  final double speed;
  final double averageSpeed;
  final double totalDistance;
  final PlayerMarkerType markerType;
  final List<TrackPoint> trackPoints;

  const TrackedPlayer({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.boundingBox,
    required this.trail,
    required this.isSelected,
    required this.speed,
    required this.averageSpeed,
    required this.totalDistance,
    this.markerType = PlayerMarkerType.box,
    this.trackPoints = const [],
  });

  factory TrackedPlayer.fromTrack(
    PlayerTrack track, {
    bool isSelected = false,
  }) {
    final pts = track.points;
    final position = pts.isNotEmpty ? pts.last.position : Offset.zero;
    final rect = pts.isNotEmpty && pts.last.rect != null
        ? pts.last.rect!
        : (track.lockedBox ?? Rect.fromCenter(center: position, width: 40, height: 60));

    double totalDistance = 0;
    double totalSpeed = 0;

    for (int i = 1; i < pts.length; i++) {
      totalDistance += (pts[i].position - pts[i - 1].position).distance;
    }

    for (final p in pts) {
      totalSpeed += p.speed;
    }

    final avgSpeed = pts.isEmpty ? 0.0 : totalSpeed / pts.length;

    return TrackedPlayer(
      id: track.id,
      name: track.boundPlayerName,
      color: track.color,
      position: position,
      boundingBox: rect,
      trail: pts.map((e) => e.position).toList(),
      isSelected: isSelected,
      speed: (track.speed ?? (pts.isNotEmpty ? pts.last.speed : 0)).toDouble(),
      averageSpeed: avgSpeed.toDouble(),
      totalDistance: totalDistance.toDouble(),
      markerType: PlayerMarkerType.box,
      trackPoints: pts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'position': {
        'x': position.dx,
        'y': position.dy,
      },
      'boundingBox': {
        'left': boundingBox.left,
        'top': boundingBox.top,
        'right': boundingBox.right,
        'bottom': boundingBox.bottom,
      },
      'trail': trail
          .map((e) => {
                'x': e.dx,
                'y': e.dy,
              })
          .toList(),
      'isSelected': isSelected,
      'speed': speed,
      'averageSpeed': averageSpeed,
      'totalDistance': totalDistance,
      'markerType': markerType.name,
      'trackPoints': trackPoints.map((p) => p.toJson()).toList(),
    };
  }
}