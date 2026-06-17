

class MultiPlayerTrackingController extends ChangeNotifier {
  final List<PlayerTrack> _activeTracks = [];
  final List<PlayerTrack> _archivedTracks = [];

  List<PlayerTrack> get activeTracks => List.unmodifiable(_activeTracks);
  List<PlayerTrack> get archivedTracks => List.unmodifiable(_archivedTracks);

  int _nextStableTrackId = 1;

  double pixelsToMeters = 0.12;

  int maxMissedFrames = 10;
  int maxPointsPerTrack = 180;

  double maxMatchDistancePx = 160.0;
  double minIoUForBonus = 0.10;
  double maxSpeedKmh = 42.0;

  double positionSmoothFactor = 0.82;
  double speedSmoothFactor = 0.72;

  final Map<String, int> _missedFramesByTrackId = {};

  void reset() {
    _activeTracks.clear();
    _archivedTracks.clear();
    _missedFramesByTrackId.clear();
    _nextStableTrackId = 1;
    notifyListeners();
  }

  void calibratePixelsToMeters(double value) {
    if (value > 0) {
      pixelsToMeters = value;
      notifyListeners();
    }
  }

  void updateTracks({
    required List<DetectedPlayerBox> detections,
    required int timeMs,
  }) {
    if (_activeTracks.isEmpty) {
      _bootstrapTracks(detections, timeMs);
      notifyListeners();
      return;
    }

    final unmatchedDetections = List<DetectedPlayerBox>.from(detections);
    final matchedTrackIds = <String>{};

    final sortedTracks = List<PlayerTrack>.from(_activeTracks)
      ..sort((a, b) {
        final aSeen = a.lastSeenTimeMs;
        final bSeen = b.lastSeenTimeMs;
        return bSeen.compareTo(aSeen);
      });

    for (final track in sortedTracks) {
      final match = _findBestDetectionForTrack(track, unmatchedDetections);

      if (match == null) {
        _missedFramesByTrackId[track.id] =
            (_missedFramesByTrackId[track.id] ?? 0) + 1;
        continue;
      }

      unmatchedDetections.remove(match);

      final updated = _updateTrackFromDetection(
        track: track,
        detection: match,
        timeMs: timeMs,
      );

      final index = _activeTracks.indexWhere((t) => t.id == track.id);
      if (index != -1) {
        _activeTracks[index] = updated;
      }

      _missedFramesByTrackId[track.id] = 0;
      matchedTrackIds.add(track.id);
    }

    for (final detection in unmatchedDetections) {
      final newTrack = _createTrackFromDetection(detection, timeMs);
      _activeTracks.add(newTrack);
      _missedFramesByTrackId[newTrack.id] = 0;
    }

    _archiveLostTracks();
    notifyListeners();
  }

  PlayerTrack? findTrackByStableId(int stableTrackId) {
    for (final track in _activeTracks) {
      final parsed = _stableIdOfTrack(track);
      if (parsed == stableTrackId) return track;
    }
    for (final track in _archivedTracks) {
      final parsed = _stableIdOfTrack(track);
      if (parsed == stableTrackId) return track;
    }
    return null;
  }

  PlayerTrack? findNearestTrack(Offset position) {
    if (_activeTracks.isEmpty) return null;

    PlayerTrack? best;
    double bestDistance = double.infinity;

    for (final track in _activeTracks) {
      final current = track.currentPosition;
      if (current == null) continue;

      final distance = (current - position).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = track;
      }
    }

    return best;
  }

  Map<String, dynamic> exportJson() {
    return {
      'active_tracks': _activeTracks.map((e) => e.toJson()).toList(),
      'archived_tracks': _archivedTracks.map((e) => e.toJson()).toList(),
      'pixels_to_meters': pixelsToMeters,
    };
  }

  void _bootstrapTracks(List<DetectedPlayerBox> detections, int timeMs) {
    for (final detection in detections) {
      final track = _createTrackFromDetection(detection, timeMs);
      _activeTracks.add(track);
      _missedFramesByTrackId[track.id] = 0;
    }
  }

  PlayerTrack _createTrackFromDetection(
    DetectedPlayerBox detection,
    int timeMs,
  ) {
    final stableId = _nextStableTrackId++;
    final trackId = 'multi_track_$stableId';

    return PlayerTrack(
      id: trackId,
      boundPlayerName: 'Игрок $stableId',
      color: _colorForStableId(stableId),
      points: [
        TrackPoint(
          position: detection.rect.center,
          timeMs: timeMs,
          speed: 0,
          vx: 0,
          vy: 0,
          ax: 0,
          ay: 0,
          rect: detection.rect,
        ),
      ],
      createdAtMs: timeMs,
      lastSeenTimeMs: timeMs,
      speed: 0,
      lockedBox: detection.rect,
    );
  }

  DetectedPlayerBox? _findBestDetectionForTrack(
    PlayerTrack track,
    List<DetectedPlayerBox> detections,
  ) {
    if (detections.isEmpty) return null;
    if (track.points.isEmpty) return null;

    final currentRect = track.currentBoundingBox;
    final currentPos = track.currentPosition;
    if (currentRect == null || currentPos == null) return null;

    DetectedPlayerBox? best;
    double bestScore = double.infinity;

    for (final detection in detections) {
      final distance = (detection.rect.center - currentPos).distance;
      if (distance > maxMatchDistancePx) continue;

      final iou = _computeIoU(currentRect, detection.rect);
      final sizePenalty = _sizePenalty(currentRect, detection.rect);

      double score = distance + sizePenalty * 55.0;

      if (iou >= minIoUForBonus) {
        score -= iou * 35.0;
      }

      if (score < bestScore) {
        bestScore = score;
        best = detection;
      }
    }

    return best;
  }

  PlayerTrack _updateTrackFromDetection({
    required PlayerTrack track,
    required DetectedPlayerBox detection,
    required int timeMs,
  }) {
    final previousPoint = track.points.isNotEmpty ? track.points.last : null;
    final previousRect = track.currentBoundingBox ?? detection.rect;

    final smoothedRect = _smoothRect(previousRect, detection.rect, positionSmoothFactor);
    final newCenter = smoothedRect.center;

    double vx = 0;
    double vy = 0;
    double ax = 0;
    double ay = 0;
    double speedKmh = 0;

    if (previousPoint != null) {
      final dt = ((timeMs - previousPoint.timeMs) / 1000.0).clamp(0.01, 0.25);

      final rawVx = (newCenter.dx - previousPoint.position.dx) / dt;
      final rawVy = (newCenter.dy - previousPoint.position.dy) / dt;

      vx = previousPoint.vx * (1 - speedSmoothFactor) + rawVx * speedSmoothFactor;
      vy = previousPoint.vy * (1 - speedSmoothFactor) + rawVy * speedSmoothFactor;

      ax = (vx - previousPoint.vx) / dt;
      ay = (vy - previousPoint.vy) / dt;

      final distancePx =
          sqrt(pow(newCenter.dx - previousPoint.position.dx, 2) +
              pow(newCenter.dy - previousPoint.position.dy, 2));

      final distanceM = distancePx * pixelsToMeters;
      speedKmh = (distanceM / dt) * 3.6;

      if (speedKmh > maxSpeedKmh) {
        speedKmh = previousPoint.speed;
      }
    }

    final newPoint = TrackPoint(
      position: newCenter,
      timeMs: timeMs,
      speed: speedKmh,
      vx: vx,
      vy: vy,
      ax: ax,
      ay: ay,
      rect: smoothedRect,
    );

    final updatedPoints = List<TrackPoint>.from(track.points)..add(newPoint);

    final trimmedPoints = updatedPoints.length > maxPointsPerTrack
        ? updatedPoints.sublist(updatedPoints.length - maxPointsPerTrack)
        : updatedPoints;

    return track.copyWith(
      points: trimmedPoints,
      speed: speedKmh,
      lastSeenTimeMs: timeMs,
      lockedBox: smoothedRect,
    );
  }

  void _archiveLostTracks() {
    final lost = <PlayerTrack>[];

    for (final track in _activeTracks) {
      final missed = _missedFramesByTrackId[track.id] ?? 0;
      if (missed > maxMissedFrames) {
        lost.add(track);
      }
    }

    for (final track in lost) {
      _activeTracks.removeWhere((t) => t.id == track.id);
      _missedFramesByTrackId.remove(track.id);
      _archivedTracks.add(track);
    }
  }

  int _stableIdOfTrack(PlayerTrack track) {
    final id = track.id;
    if (id.startsWith('multi_track_')) {
      return int.tryParse(id.replaceFirst('multi_track_', '')) ?? 0;
    }
    return 0;
  }

  Rect _smoothRect(Rect prev, Rect next, double t) {
    return Rect.fromLTRB(
      prev.left * (1 - t) + next.left * t,
      prev.top * (1 - t) + next.top * t,
      prev.right * (1 - t) + next.right * t,
      prev.bottom * (1 - t) + next.bottom * t,
    );
  }

  double _sizePenalty(Rect a, Rect b) {
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    if (areaA <= 0) return 0;
    return ((areaB - areaA).abs() / areaA);
  }

  double _computeIoU(Rect a, Rect b) {
    final left = max(a.left, b.left);
    final top = max(a.top, b.top);
    final right = min(a.right, b.right);
    final bottom = min(a.bottom, b.bottom);

    if (right <= left || bottom <= top) return 0.0;

    final intersection = (right - left) * (bottom - top);
    final union = a.width * a.height + b.width * b.height - intersection;
    if (union <= 0) return 0.0;

    return intersection / union;
  }

  Color _colorForStableId(int stableId) {
    final colors = <Color>[
      const Color(0xFF2563EB),
      const Color(0xFFDC2626),
      const Color(0xFF16A34A),
      const Color(0xFFF59E0B),
      const Color(0xFF7C3AED),
      const Color(0xFF0891B2),
      const Color(0xFFEA580C),
      const Color(0xFFBE123C),
      const Color(0xFF4F46E5),
      const Color(0xFF0F766E),
    ];

    return colors[(stableId - 1) % colors.length];
  }
}