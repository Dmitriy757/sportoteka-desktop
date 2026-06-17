import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/team_video_analysis/ai_analytics_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/tracking_models.dart';

class _TrackFilterState {
  final Offset position;
  final Offset velocity;
  final int timeMs;
  final double confidence;

  const _TrackFilterState({
    required this.position,
    required this.velocity,
    required this.timeMs,
    required this.confidence,
  });

  _TrackFilterState copyWith({
    Offset? position,
    Offset? velocity,
    int? timeMs,
    double? confidence,
  }) {
    return _TrackFilterState(
      position: position ?? this.position,
      velocity: velocity ?? this.velocity,
      timeMs: timeMs ?? this.timeMs,
      confidence: confidence ?? this.confidence,
    );
  }
}

class AiTrackingController extends ChangeNotifier {
  bool isRunning = false;

  int sampleMs = 80;

  List<PlayerTrack> tracks = [];

  String? selectedTrackId;
  PlayerTrack? selectedTrack;

  bool showTrails = true;
  bool showLabels = true;
  bool showSpeed = true;
  bool showBoundingBoxes = true;
  bool showOnlySelectedPlayer = false;

  BallTrack? ballTrack;

  final List<BallPossessionSegment> possessionSegments = [];
  final List<PassArrow> passArrows = [];
  final List<PassEdge> passEdges = [];

  bool showBall = true;
  bool showBallTrail = true;
  bool showPossessionOverlay = true;
  bool showPassNetwork = true;

  String? currentBallOwnerTrackId;
  String? currentBallOwnerName;
  String? currentBallOwnerTeamTag;
  int? currentBallOwnerStartedAtMs;

  String? _lastBallOwnerTrackId;
  int _lastBallOwnerTimeMs = 0;

  Timer? _loopTimer;
  bool _isProcessingFrame = false;

  double _pixelsToMeters = 0.028;

  bool isLocked = false;
  bool isSelectingTarget = false;

  PlayerTrack? lockedTrack;
  Rect? lockedRect;
  Offset? lockedPosition;

  int _missedLockedFrames = 0;
  final int _maxMissedLockedFrames = 8;

  List<DetectedPlayerBox> _lastDetections = [];
  int _lastDetectionTimeMs = 0;

  final double _maxPlayerSpeedKmh = 40.0;
  final int _maxPointsPerTrack = 120;

  double _positionSmoothFactor = 0.22;
  double _speedSmoothFactor = 0.18;
  double _maxJumpDistance = 120.0;
  bool _usePrediction = true;
  double _predictionFactor = 0.3;

  int _lastUpdateTimeMs = 0;
  double _lastSpeedKmh = 0;
  Offset _lastVelocity = Offset.zero;

  final List<AiDetectedEvent> autoEvents = [];
  final List<AiTtdSuggestion> ttdSuggestions = [];
  final List<AiPassNetworkEdge> aiPassNetwork = [];
final List<AiAveragePosition> aiAveragePositions = [];
final List<AiDangerMoment> aiDangerMoments = [];
final List<AiPlayerStat> aiPlayerStats = [];

  Map<String, dynamic>? aiSummary;
  Map<String, dynamic>? aiMatchStats;
  Map<String, dynamic>? aiVideoMeta;
  List<Map<String, dynamic>> aiPossessionTimeline = [];

  bool useServerAiResults = true;

  double averageSpeedKmh = 0;
  double maxSpeedKmh = 0;
  double totalDistanceMeters = 0;
  int sprintCount = 0;
  int directionChangeCount = 0;
  int accelerationBurstCount = 0;

  int _lastSprintEventTimeMs = 0;
  int _lastDirectionEventTimeMs = 0;
  int _lastAccelerationEventTimeMs = 0;
  int _lastTtdSuggestionTimeMs = 0;

  _TrackFilterState? _filterState;

  double _alphaBetaAlpha = 0.22;
  double _alphaBetaBeta = 0.06;

  double _maxMeasurementJumpPx = 90.0;
  double _hardRejectJumpPx = 160.0;

  double _displaySmoothFactor = 0.20;

  void startLoop({
    required Future<List<DetectedPlayerBox>> Function(int) frameDetector,
    required int Function() currentTimeMs,
  }) {
    stopLoop();

    isRunning = true;
    notifyListeners();

    _loopTimer = Timer.periodic(Duration(milliseconds: sampleMs), (timer) async {
      if (_isProcessingFrame) return;

      _isProcessingFrame = true;
      try {
        final timeMs = currentTimeMs();
        final detections = await frameDetector(timeMs);

        _lastDetections = detections;
        _lastDetectionTimeMs = timeMs;

        if (isLocked) {
          updateLockedTrack(detections, timeMs);
        }
      } catch (e) {
        debugPrint('❌ AI tracking loop error: $e');
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  void stopLoop() {
    _loopTimer?.cancel();
    _loopTimer = null;
    _isProcessingFrame = false;
    isRunning = false;
    notifyListeners();
  }

void applyServerAnalysis(Map<String, dynamic> json) {
  debugPrint('✅ applyServerAnalysis CALLED');
  debugPrint('incoming keys = ${json.keys.toList()}');

  final eventsRaw = (json['events'] as List?) ?? const [];
  final autoTtdRaw = (json['auto_ttd'] as List?) ?? const [];

  final parsedEvents = eventsRaw
      .whereType<Map>()
      .map(
        (e) => AiDetectedEvent.fromBackendJson(
          Map<String, dynamic>.from(e),
        ),
      )
      .toList();

  final parsedSuggestions = autoTtdRaw
      .whereType<Map>()
      .map(
        (e) => AiTtdSuggestion.fromBackendJson(
          Map<String, dynamic>.from(e),
        ),
      )
      .toList();
      
      aiPassNetwork
  ..clear()
  ..addAll(
    ((json['pass_network'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AiPassNetworkEdge.fromJson(Map<String, dynamic>.from(e))),
  );

aiAveragePositions
  ..clear()
  ..addAll(
    ((json['average_positions'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AiAveragePosition.fromJson(Map<String, dynamic>.from(e))),
  );

aiDangerMoments
  ..clear()
  ..addAll(
    ((json['danger_moments'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AiDangerMoment.fromJson(Map<String, dynamic>.from(e))),
  );

aiPlayerStats
  ..clear()
  ..addAll(
    ((json['player_stats'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AiPlayerStat.fromJson(Map<String, dynamic>.from(e))),
  );

  autoEvents
    ..clear()
    ..addAll(parsedEvents);

  ttdSuggestions
    ..clear()
    ..addAll(parsedSuggestions);

  final summaryMap = json['summary'] is Map
      ? Map<String, dynamic>.from(json['summary'] as Map)
      : null;

  aiSummary = summaryMap;

  final directMatchStats = json['match_stats'] is Map
      ? Map<String, dynamic>.from(json['match_stats'] as Map)
      : null;

  final summaryMatchStats = summaryMap?['match_stats'] is Map
      ? Map<String, dynamic>.from(summaryMap!['match_stats'] as Map)
      : null;

  final rawMatchStats = directMatchStats ?? summaryMatchStats;

  if (rawMatchStats != null && rawMatchStats['match_stats'] is Map) {
    aiMatchStats = Map<String, dynamic>.from(
      rawMatchStats['match_stats'] as Map,
    );
  } else {
    aiMatchStats = rawMatchStats;
  }

  final directVideoMeta = json['video_meta'] is Map
      ? Map<String, dynamic>.from(json['video_meta'] as Map)
      : null;

  final summaryVideoMeta = summaryMap?['video'] is Map
      ? Map<String, dynamic>.from(summaryMap!['video'] as Map)
      : null;

  aiVideoMeta = directVideoMeta ?? summaryVideoMeta;

  aiPossessionTimeline = ((json['possession_timeline'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  debugPrint('✅ Server AI applied');
  debugPrint('   events: ${autoEvents.length}');
  debugPrint('   ttd suggestions: ${ttdSuggestions.length}');
  debugPrint('   aiSummary = $aiSummary');
  debugPrint('   aiMatchStats = $aiMatchStats');
  debugPrint('   aiVideoMeta = $aiVideoMeta');
  debugPrint('   aiPossessionTimeline: ${aiPossessionTimeline.length}');

  notifyListeners();
}
  void clearServerAnalysis() {
    autoEvents.clear();
    ttdSuggestions.clear();
    aiSummary = null;
    aiMatchStats = null;
    aiVideoMeta = null;
    aiPossessionTimeline.clear();
    
    aiPassNetwork.clear();
aiAveragePositions.clear();
aiDangerMoments.clear();
aiPlayerStats.clear();
    notifyListeners();
  }

  void resetTracks() {
      
      aiPassNetwork.clear();
aiAveragePositions.clear();
aiDangerMoments.clear();
aiPlayerStats.clear();
      
    tracks.clear();
    selectedTrackId = null;
    selectedTrack = null;

    lockedTrack = null;
    lockedRect = null;
    lockedPosition = null;
    isLocked = false;
    isSelectingTarget = false;
    _missedLockedFrames = 0;

    _lastDetections = [];
    _lastDetectionTimeMs = 0;
    _lastVelocity = Offset.zero;
    _lastSpeedKmh = 0;
    _filterState = null;

    if (!useServerAiResults) {
      autoEvents.clear();
      ttdSuggestions.clear();
    }

    averageSpeedKmh = 0;
    maxSpeedKmh = 0;
    totalDistanceMeters = 0;
    sprintCount = 0;
    directionChangeCount = 0;
    accelerationBurstCount = 0;

    _lastSprintEventTimeMs = 0;
    _lastDirectionEventTimeMs = 0;
    _lastAccelerationEventTimeMs = 0;
    _lastTtdSuggestionTimeMs = 0;

    ballTrack = null;
    possessionSegments.clear();
    passArrows.clear();
    passEdges.clear();

    currentBallOwnerTrackId = null;
    currentBallOwnerName = null;
    currentBallOwnerTeamTag = null;
    currentBallOwnerStartedAtMs = null;

    _lastBallOwnerTrackId = null;
    _lastBallOwnerTimeMs = 0;

    notifyListeners();
  }

  void disposeController() {
    stopLoop();
  }

  @override
  void dispose() {
    stopLoop();
    super.dispose();
  }

  void startTargetSelection() {
    isSelectingTarget = true;
    notifyListeners();
  }

  void clearLock() {
    isLocked = false;
    isSelectingTarget = false;

    lockedTrack = null;
    lockedRect = null;
    lockedPosition = null;

    tracks = [];
    selectedTrackId = null;
    selectedTrack = null;
    _missedLockedFrames = 0;
    _lastVelocity = Offset.zero;
    _lastSpeedKmh = 0;
    _filterState = null;

    if (!useServerAiResults) {
      autoEvents.clear();
      ttdSuggestions.clear();
    }

    averageSpeedKmh = 0;
    maxSpeedKmh = 0;
    totalDistanceMeters = 0;
    sprintCount = 0;
    directionChangeCount = 0;
    accelerationBurstCount = 0;

    _lastSprintEventTimeMs = 0;
    _lastDirectionEventTimeMs = 0;
    _lastAccelerationEventTimeMs = 0;
    _lastTtdSuggestionTimeMs = 0;

    ballTrack = null;
    possessionSegments.clear();
    passArrows.clear();
    passEdges.clear();

    currentBallOwnerTrackId = null;
    currentBallOwnerName = null;
    currentBallOwnerTeamTag = null;
    currentBallOwnerStartedAtMs = null;

    _lastBallOwnerTrackId = null;
    _lastBallOwnerTimeMs = 0;

    notifyListeners();
  }

  void setDetectionsForSelection(List<DetectedPlayerBox> detections, int timeMs) {
    _lastDetections = detections;
    _lastDetectionTimeMs = timeMs;
  }

  void selectTrackByTap(Offset tapPosition) {
    if (_lastDetections.isEmpty) {
      debugPrint('⚠️ No detections available for tap-lock');
      return;
    }

    lockOnDetections(
      tapPosition: tapPosition,
      detections: _lastDetections,
      timeMs: _lastDetectionTimeMs,
    );
  }

  void lockOnDetections({
    required Offset tapPosition,
    required List<DetectedPlayerBox> detections,
    required int timeMs,
  }) {
    if (detections.isEmpty) return;

    DetectedPlayerBox? best;
    double bestDistance = double.infinity;

    for (final d in detections) {
      final dist = (_footPoint(d.rect) - tapPosition).distance;
      if (dist < bestDistance) {
        bestDistance = dist;
        best = d;
      }
    }

    if (best == null) return;

    final initialPosition = _footPoint(best.rect);

    _filterState = _TrackFilterState(
      position: initialPosition,
      velocity: Offset.zero,
      timeMs: timeMs,
      confidence: 1.0,
    );

    final newTrack = PlayerTrack(
      id: 'track_$timeMs',
      color: Colors.red,
      points: [
        TrackPoint(
          position: initialPosition,
          timeMs: timeMs,
          speed: 0,
          rect: best.rect,
          vx: 0,
          vy: 0,
          ax: 0,
          ay: 0,
        ),
      ],
      speed: 0,
      boundPlayerId: selectedTrack?.boundPlayerId,
      boundPlayerName: selectedTrack?.boundPlayerName ?? 'Игрок',
      createdAtMs: timeMs,
      lastSeenTimeMs: timeMs,
      lockedBox: best.rect,
      teamTag: selectedTrack?.teamTag,
      jerseyNumber: selectedTrack?.jerseyNumber,
    );

    lockedTrack = newTrack;
    lockedRect = best.rect;
    lockedPosition = initialPosition;

    isLocked = true;
    isSelectingTarget = false;
    _missedLockedFrames = 0;
    _lastUpdateTimeMs = timeMs;
    _lastVelocity = Offset.zero;
    _lastSpeedKmh = 0;

    tracks = [newTrack];
    selectedTrackId = newTrack.id;
    selectedTrack = newTrack;

    _recalculateLiveStats(newTrack);
    notifyListeners();
  }

  void updateLockedTrack(List<DetectedPlayerBox> detections, int timeMs) {
    if (!isLocked || lockedTrack == null || lockedRect == null || _filterState == null) {
      return;
    }

    final prevTrack = lockedTrack!;
    final prevRect = lockedRect!;
    final prevFilter = _filterState!;

    _lastUpdateTimeMs = timeMs;

    if (detections.isEmpty) {
      _missedLockedFrames++;

      if (_missedLockedFrames > _maxMissedLockedFrames) {
        clearLock();
      } else {
        final predictedOnly = _predictFilteredPosition(prevFilter, timeMs);

        _filterState = prevFilter.copyWith(
          position: predictedOnly,
          timeMs: timeMs,
          confidence: (prevFilter.confidence * 0.92).clamp(0.15, 1.0),
        );

        notifyListeners();
      }
      return;
    }

    final predictedPoint = _predictFilteredPosition(prevFilter, timeMs);

    DetectedPlayerBox? best;
    double bestScore = double.infinity;

    for (final d in detections) {
      final measuredPoint = _footPoint(d.rect);
      final pointDistance = (measuredPoint - predictedPoint).distance;
      final iou = _computeIoU(prevRect, d.rect);
      final sizePenalty = _sizePenalty(prevRect, d.rect);

      final score = pointDistance - (iou * 120) + (sizePenalty * 40);

      if (score < bestScore) {
        bestScore = score;
        best = d;
      }
    }

    if (best == null) {
      _missedLockedFrames++;
      if (_missedLockedFrames > _maxMissedLockedFrames) {
        clearLock();
      } else {
        notifyListeners();
      }
      return;
    }

    final measuredPointRaw = _footPoint(best.rect);
    final measuredPoint = _softClampMeasurement(
      predicted: predictedPoint,
      measured: measuredPointRaw,
      maxJumpPx: _maxMeasurementJumpPx,
    );

    final measurementConfidence = _estimateMeasurementConfidence(
      previousRect: prevRect,
      nextRect: best.rect,
      predictedPoint: predictedPoint,
      measuredPoint: measuredPointRaw,
    );

    if ((measuredPointRaw - predictedPoint).distance > _hardRejectJumpPx &&
        measurementConfidence < 0.20) {
      _missedLockedFrames++;

      if (_missedLockedFrames > _maxMissedLockedFrames) {
        clearLock();
      } else {
        _filterState = prevFilter.copyWith(
          position: predictedPoint,
          timeMs: timeMs,
          confidence: (prevFilter.confidence * 0.90).clamp(0.12, 1.0),
        );
        notifyListeners();
      }
      return;
    }

    _missedLockedFrames = 0;

    final updatedFilter = _updateAlphaBetaFilter(
      previous: prevFilter,
      measurement: measuredPoint,
      timeMs: timeMs,
      confidence: measurementConfidence,
    );

    _filterState = updatedFilter;

    final newRect = _smoothRectFast(prevRect, best.rect, _positionSmoothFactor);

    final filteredPosition = updatedFilter.position;
    final dt = ((timeMs - prevTrack.points.last.timeMs) / 1000.0).clamp(0.04, 0.25);

    final vx = updatedFilter.velocity.dx;
    final vy = updatedFilter.velocity.dy;

    final prevPoint = prevTrack.points.last;
    final ax = (vx - prevPoint.vx) / dt;
    final ay = (vy - prevPoint.vy) / dt;

    final previewPoints = List<TrackPoint>.from(prevTrack.points)
      ..add(
        TrackPoint(
          position: filteredPosition,
          timeMs: timeMs,
          speed: 0,
          rect: newRect,
          vx: vx,
          vy: vy,
          ax: ax,
          ay: ay,
        ),
      );

    final rawWindowSpeed = _computeWindowSpeedKmhFromPoints(previewPoints);
    final displaySpeed = _smoothDisplaySpeed(prevPoint.speed, rawWindowSpeed);

    final updatedPoints = List<TrackPoint>.from(prevTrack.points)
      ..add(
        TrackPoint(
          position: filteredPosition,
          timeMs: timeMs,
          speed: displaySpeed,
          rect: newRect,
          vx: vx,
          vy: vy,
          ax: ax,
          ay: ay,
        ),
      );

    final trimmedPoints = updatedPoints.length > _maxPointsPerTrack
        ? updatedPoints.sublist(updatedPoints.length - _maxPointsPerTrack)
        : updatedPoints;

    final updatedTrack = PlayerTrack(
      id: prevTrack.id,
      color: prevTrack.color,
      points: trimmedPoints,
      speed: displaySpeed,
      boundPlayerId: prevTrack.boundPlayerId,
      boundPlayerName: prevTrack.boundPlayerName,
      createdAtMs: prevTrack.createdAtMs,
      lastSeenTimeMs: timeMs,
      lockedBox: newRect,
      teamTag: prevTrack.teamTag,
      jerseyNumber: prevTrack.jerseyNumber,
    );

    lockedTrack = updatedTrack;
    lockedRect = newRect;
    lockedPosition = filteredPosition;

    _lastVelocity = Offset(vx, vy);
    _lastSpeedKmh = displaySpeed;

    tracks = [updatedTrack];
    selectedTrackId = updatedTrack.id;
    selectedTrack = updatedTrack;

    _recalculateLiveStats(updatedTrack);

    if (!useServerAiResults) {
      _generateAiEvents(updatedTrack);
      _generateTtdSuggestions(updatedTrack);
    }

    notifyListeners();
  }

  Offset _footPoint(Rect rect) => Offset(rect.center.dx, rect.bottom);

  Offset _predictFilteredPosition(_TrackFilterState state, int timeMs) {
    final dt = ((timeMs - state.timeMs) / 1000.0).clamp(0.0, 0.25);
    return Offset(
      state.position.dx + state.velocity.dx * dt,
      state.position.dy + state.velocity.dy * dt,
    );
  }

  _TrackFilterState _updateAlphaBetaFilter({
    required _TrackFilterState previous,
    required Offset measurement,
    required int timeMs,
    required double confidence,
  }) {
    final dt = ((timeMs - previous.timeMs) / 1000.0).clamp(0.016, 0.25);

    final predictedPosition = Offset(
      previous.position.dx + previous.velocity.dx * dt,
      previous.position.dy + previous.velocity.dy * dt,
    );

    final predictedVelocity = previous.velocity;

    final residual = measurement - predictedPosition;

    final alpha = _alphaBetaAlpha * confidence;
    final beta = _alphaBetaBeta * confidence;

    final correctedPosition = Offset(
      predictedPosition.dx + residual.dx * alpha,
      predictedPosition.dy + residual.dy * alpha,
    );

    final correctedVelocity = Offset(
      predictedVelocity.dx + (residual.dx * beta / dt),
      predictedVelocity.dy + (residual.dy * beta / dt),
    );

    return _TrackFilterState(
      position: correctedPosition,
      velocity: correctedVelocity,
      timeMs: timeMs,
      confidence: confidence,
    );
  }

  double _estimateMeasurementConfidence({
    required Rect previousRect,
    required Rect nextRect,
    required Offset predictedPoint,
    required Offset measuredPoint,
  }) {
    final jump = (measuredPoint - predictedPoint).distance;
    final iou = _computeIoU(previousRect, nextRect);
    final sizePenalty = _sizePenalty(previousRect, nextRect);

    double confidence = 1.0;

    if (jump > _maxMeasurementJumpPx) {
      confidence *= 0.45;
    }

    if (jump > _hardRejectJumpPx) {
      confidence *= 0.15;
    }

    confidence *= (0.55 + iou * 0.45);
    confidence *= (1.0 - sizePenalty.clamp(0.0, 0.6) * 0.7);

    return confidence.clamp(0.12, 1.0);
  }

  Offset _softClampMeasurement({
    required Offset predicted,
    required Offset measured,
    required double maxJumpPx,
  }) {
    final delta = measured - predicted;
    final dist = delta.distance;

    if (dist <= maxJumpPx || dist == 0) return measured;

    final k = maxJumpPx / dist;
    return Offset(
      predicted.dx + delta.dx * k,
      predicted.dy + delta.dy * k,
    );
  }

  double _computeWindowSpeedKmhFromPoints(List<TrackPoint> points) {
    if (points.length < 2) return 0;

    final recent = points.length > 8
        ? points.sublist(points.length - 8)
        : points;

    double totalDistanceMeters = 0;
    double totalSeconds = 0;

    for (int i = 1; i < recent.length; i++) {
      final p1 = recent[i - 1];
      final p2 = recent[i];

      final dt = ((p2.timeMs - p1.timeMs) / 1000.0).clamp(0.04, 0.20);
      final dx = p2.position.dx - p1.position.dx;
      final dy = p2.position.dy - p1.position.dy;
      final distPx = sqrt(dx * dx + dy * dy);

      final localScale = _localPixelsToMeters(p2.position.dy);

      totalDistanceMeters += distPx * localScale;
      totalSeconds += dt;
    }

    if (totalSeconds <= 0) return 0;

    final kmh = (totalDistanceMeters / totalSeconds) * 3.6;
    return kmh.clamp(0, _maxPlayerSpeedKmh);
  }

  double _localPixelsToMeters(double y) {
    final normalizedY = (y / 1080.0).clamp(0.0, 1.0);

    final farScale = _pixelsToMeters * 1.85;
    final nearScale = _pixelsToMeters * 0.72;

    return farScale + (nearScale - farScale) * normalizedY;
  }

  double _smoothDisplaySpeed(double previous, double next) {
    double factor = _displaySmoothFactor;

    if ((next - previous).abs() > 10) {
      factor = 0.08;
    }

    final value = previous + (next - previous) * factor;
    return value.clamp(0, _maxPlayerSpeedKmh);
  }

  Offset _predictNextPosition(PlayerTrack track, int timeMs, int deltaTimeMs) {
    if (_filterState != null) {
      return _predictFilteredPosition(_filterState!, timeMs);
    }

    if (track.points.isEmpty) return Offset.zero;
    return track.points.last.position;
  }

  Offset getPredictedPositionForTrack(PlayerTrack track, int currentVideoTimeMs) {
    if (_filterState != null) {
      return _predictFilteredPosition(_filterState!, currentVideoTimeMs);
    }

    if (track.points.isEmpty) return Offset.zero;
    return track.points.last.position;
  }

  Rect? getPredictedRectForTrack(PlayerTrack track, int currentVideoTimeMs) {
    if (track.points.isEmpty) return null;

    final last = track.points.last;
    final baseRect = last.rect;
    if (baseRect == null) return null;

    final predictedPos = getPredictedPositionForTrack(track, currentVideoTimeMs);
    final offset = predictedPos - last.position;

    return baseRect.shift(offset);
  }

  Rect _smoothRectFast(Rect prev, Rect next, double t) {
    return Rect.fromLTRB(
      prev.left * (1 - t) + next.left * t,
      prev.top * (1 - t) + next.top * t,
      prev.right * (1 - t) + next.right * t,
      prev.bottom * (1 - t) + next.bottom * t,
    );
  }

  Rect _smoothRect(Rect prev, Rect next, double t) {
    return _smoothRectFast(prev, next, t);
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

  bool isSprintNow() {
    if (lockedTrack == null || lockedTrack!.points.isEmpty) return false;
    return lockedTrack!.points.last.speed >= 24.0;
  }

  double currentAcceleration() {
    if (lockedTrack == null || lockedTrack!.points.isEmpty) return 0;
    final p = lockedTrack!.points.last;
    return sqrt(p.ax * p.ax + p.ay * p.ay);
  }

  double? getCurrentSelectedPlayerSpeed() {
    if (lockedTrack != null && lockedTrack!.points.isNotEmpty) {
      return lockedTrack!.points.last.speed;
    }
    return null;
  }

  void bindSelectedTrackToPlayer({
    required int playerId,
    required String playerName,
  }) {
    if (lockedTrack == null) return;

    lockedTrack!.boundPlayerId = playerId;
    lockedTrack!.boundPlayerName = playerName;

    if (tracks.isNotEmpty) {
      tracks[0].boundPlayerId = playerId;
      tracks[0].boundPlayerName = playerName;
    }

    if (selectedTrack != null) {
      selectedTrack!.boundPlayerId = playerId;
      selectedTrack!.boundPlayerName = playerName;
    }

    debugPrint('✅ Locked track bound to player $playerName');
    notifyListeners();
  }

  void updateBall({
    required Rect rect,
    required int timeMs,
    double confidence = 1.0,
  }) {
    final point = BallPoint(
      position: rect.center,
      timeMs: timeMs,
      rect: rect,
      confidence: confidence,
    );

    final updatedPoints = List<BallPoint>.from(ballTrack?.points ?? [])..add(point);

    final trimmedPoints = updatedPoints.length > 50
        ? updatedPoints.sublist(updatedPoints.length - 50)
        : updatedPoints;

    ballTrack = BallTrack(
      points: trimmedPoints,
      lastSeenTimeMs: timeMs,
      lastRect: rect,
    );

    updateBallPossession(timeMs, rect.center);
    detectPassFromBall(timeMs);

    notifyListeners();
  }

  String? findNearestTrackToBall(
    Offset ballPos, {
    double maxDistance = 46,
  }) {
    String? bestId;
    double bestDistance = double.infinity;

    for (final track in tracks) {
      final pos = track.currentPosition;
      if (pos == null) continue;

      final d = (pos - ballPos).distance;
      if (d < bestDistance && d <= maxDistance) {
        bestDistance = d;
        bestId = track.id;
      }
    }

    return bestId;
  }

  void updateBallPossession(int timeMs, Offset ballPos) {
    final nextOwnerId = findNearestTrackToBall(ballPos);

    if (nextOwnerId == null) return;

    final nextOwnerIndex = tracks.indexWhere((t) => t.id == nextOwnerId);
    if (nextOwnerIndex == -1) return;

    final nextOwner = tracks[nextOwnerIndex];

    if (currentBallOwnerTrackId == null) {
      currentBallOwnerTrackId = nextOwner.id;
      currentBallOwnerStartedAtMs = timeMs;
      currentBallOwnerName = nextOwner.boundPlayerName;
      currentBallOwnerTeamTag = nextOwner.teamTag;
      return;
    }

    if (currentBallOwnerTrackId != nextOwner.id) {
      possessionSegments.insert(
        0,
        BallPossessionSegment(
          trackId: currentBallOwnerTrackId!,
          playerName: currentBallOwnerName ?? 'Игрок',
          teamTag: currentBallOwnerTeamTag,
          startedAtMs: currentBallOwnerStartedAtMs ?? timeMs,
          endedAtMs: timeMs,
        ),
      );

      if (possessionSegments.length > 100) {
        possessionSegments.removeRange(100, possessionSegments.length);
      }

      currentBallOwnerTrackId = nextOwner.id;
      currentBallOwnerStartedAtMs = timeMs;
      currentBallOwnerName = nextOwner.boundPlayerName;
      currentBallOwnerTeamTag = nextOwner.teamTag;
    }
  }

  void registerPassEdge(String fromTrackId, String toTrackId) {
    final index = passEdges.indexWhere(
      (e) => e.fromTrackId == fromTrackId && e.toTrackId == toTrackId,
    );

    if (index == -1) {
      final fromTrackIndex = tracks.indexWhere((t) => t.id == fromTrackId);
      final toTrackIndex = tracks.indexWhere((t) => t.id == toTrackId);

      final fromTrack = fromTrackIndex != -1 ? tracks[fromTrackIndex] : null;
      final toTrack = toTrackIndex != -1 ? tracks[toTrackIndex] : null;

      passEdges.add(
        PassEdge(
          fromTrackId: fromTrackId,
          toTrackId: toTrackId,
          count: 1,
          fromTeamTag: fromTrack?.teamTag,
          toTeamTag: toTrack?.teamTag,
        ),
      );
    } else {
      final current = passEdges[index];
      passEdges[index] = current.copyWith(count: current.count + 1);
    }
  }

  void detectPassFromBall(int timeMs) {
    final ball = ballTrack?.lastPoint;
    if (ball == null) return;

    final currentOwner = findNearestTrackToBall(ball.position);
    if (currentOwner == null) return;

    if (_lastBallOwnerTrackId == null) {
      _lastBallOwnerTrackId = currentOwner;
      _lastBallOwnerTimeMs = timeMs;
      return;
    }

    if (currentOwner != _lastBallOwnerTrackId &&
        timeMs - _lastBallOwnerTimeMs < 2200) {
      final fromTrackIndex = tracks.indexWhere((t) => t.id == _lastBallOwnerTrackId);
      final toTrackIndex = tracks.indexWhere((t) => t.id == currentOwner);

      if (fromTrackIndex != -1 && toTrackIndex != -1) {
        final fromTrack = tracks[fromTrackIndex];
        final toTrack = tracks[toTrackIndex];

        final fromPos = fromTrack.currentPosition ?? fromTrack.points.last.position;
        final toPos = toTrack.currentPosition ?? toTrack.points.last.position;

        passArrows.insert(
          0,
          PassArrow(
            fromTrackId: fromTrack.id,
            toTrackId: toTrack.id,
            from: fromPos,
            to: toPos,
            timeMs: timeMs,
            confidence: 0.72,
          ),
        );

        if (passArrows.length > 20) {
          passArrows.removeRange(20, passArrows.length);
        }

        registerPassEdge(fromTrack.id, toTrack.id);
      }
    }

    _lastBallOwnerTrackId = currentOwner;
    _lastBallOwnerTimeMs = timeMs;
  }

  void assignTrackTeam(String trackId, String teamTag) {
    final index = tracks.indexWhere((t) => t.id == trackId);
    if (index == -1) return;

    final track = tracks[index];

    Color nextColor = track.color;
    if (teamTag == 'home') {
      nextColor = const Color(0xFF2563EB);
    } else if (teamTag == 'away') {
      nextColor = const Color(0xFFDC2626);
    }

    tracks[index] = track.copyWith(
      color: nextColor,
      teamTag: teamTag,
    );

    if (lockedTrack != null && lockedTrack!.id == trackId) {
      lockedTrack = tracks[index];
    }
    if (selectedTrack != null && selectedTrack!.id == trackId) {
      selectedTrack = tracks[index];
    }

    notifyListeners();
  }

  Map<String, dynamic> exportJson() {
    return {
      'locked': isLocked,
      'track': lockedTrack?.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
      'stats': _calculateStats(),
      'is_sprint_now': isSprintNow(),
      'current_acceleration': currentAcceleration(),
      'auto_events': autoEvents
          .map((e) => {
                'type': e.type,
                'title': e.title,
                'subtitle': e.subtitle,
                'timeMs': e.timeMs,
                'confidence': e.confidence,
                'meta': e.meta,
              })
          .toList(),
      'ttd_suggestions': ttdSuggestions
          .map((e) => {
                'code': e.code,
                'title': e.title,
                'section': e.section,
                'timeMs': e.timeMs,
                'confidence': e.confidence,
                'success': e.success,
                'meta': e.meta,
              })
          .toList(),
      'ball_track': ballTrack == null
          ? null
          : {
              'lastSeenTimeMs': ballTrack!.lastSeenTimeMs,
              'points': ballTrack!.points.map((e) => e.toJson()).toList(),
            },
      'current_ball_owner': {
        'trackId': currentBallOwnerTrackId,
        'playerName': currentBallOwnerName,
        'teamTag': currentBallOwnerTeamTag,
        'startedAtMs': currentBallOwnerStartedAtMs,
      },
      'possession_segments': possessionSegments
          .map((e) => {
                'trackId': e.trackId,
                'playerName': e.playerName,
                'teamTag': e.teamTag,
                'startedAtMs': e.startedAtMs,
                'endedAtMs': e.endedAtMs,
                'durationMs': e.durationMs,
              })
          .toList(),
      'pass_arrows': passArrows
          .map((e) => {
                'fromTrackId': e.fromTrackId,
                'toTrackId': e.toTrackId,
                'from': {'x': e.from.dx, 'y': e.from.dy},
                'to': {'x': e.to.dx, 'y': e.to.dy},
                'timeMs': e.timeMs,
                'confidence': e.confidence,
              })
          .toList(),
      'pass_edges': passEdges
          .map((e) => {
                'fromTrackId': e.fromTrackId,
                'toTrackId': e.toTrackId,
                'count': e.count,
                'fromTeamTag': e.fromTeamTag,
                'toTeamTag': e.toTeamTag,
              })
          .toList(),
      'ai_summary': aiSummary,
      'ai_match_stats': aiMatchStats,
      'ai_video_meta': aiVideoMeta,
      'ai_possession_timeline': aiPossessionTimeline,
      'pass_network': aiPassNetwork.map((e) => {
  'from_track_id': e.fromTrackId,
  'to_track_id': e.toTrackId,
  'team': e.team,
  'count': e.count,
  'successful': e.successful,
  'avg_start_x': e.avgStartX,
  'avg_start_y': e.avgStartY,
  'avg_end_x': e.avgEndX,
  'avg_end_y': e.avgEndY,
}).toList(),

'average_positions': aiAveragePositions.map((e) => {
  'track_id': e.trackId,
  'team': e.team,
  'player_name': e.playerName,
  'avg_x': e.avgX,
  'avg_y': e.avgY,
  'samples': e.samples,
}).toList(),

'danger_moments': aiDangerMoments.map((e) => {
  'time_ms': e.timeMs,
  'team': e.team,
  'type': e.type,
  'title': e.title,
  'danger_score': e.dangerScore,
}).toList(),

'player_stats': aiPlayerStats.map((e) => {
  'track_id': e.trackId,
  'team': e.team,
  'player_name': e.playerName,
  'touches': e.touches,
  'passes': e.passes,
  'successful_passes': e.successfulPasses,
  'shots': e.shots,
  'interceptions': e.interceptions,
  'distance_m': e.distanceM,
  'max_speed_kmh': e.maxSpeedKmh,
  'rating': e.rating,
}).toList(),

    };
  }

  Map<String, dynamic> _calculateStats() {
    if (lockedTrack == null) {
      return {
        'total_tracks': 0,
        'total_points': 0,
        'total_distance_m': 0.0,
        'max_speed_kmh': 0.0,
      };
    }

    double totalDistance = 0;
    double maxSpeed = 0;
    final pts = lockedTrack!.points;

    for (final point in pts) {
      maxSpeed = max(maxSpeed, point.speed);
    }

    for (int i = 1; i < pts.length; i++) {
      final p1 = pts[i - 1].position;
      final p2 = pts[i].position;
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      totalDistance += sqrt(dx * dx + dy * dy) * _localPixelsToMeters(p2.dy);
    }

    return {
      'total_tracks': 1,
      'total_points': pts.length,
      'total_distance_m': totalDistance,
      'max_speed_kmh': maxSpeed,
    };
  }

  void calibratePixelsToMeters(double knownDistanceMeters, double pixelsDistance) {
    if (pixelsDistance > 0) {
      _pixelsToMeters = knownDistanceMeters / pixelsDistance;
      debugPrint('📏 Calibrated pixelsToMeters = $_pixelsToMeters');
      notifyListeners();
    }
  }

  void autoCalibrateStandardField(double fieldPixelsLength) {
    if (fieldPixelsLength > 0) {
      _pixelsToMeters = 105.0 / fieldPixelsLength;

      debugPrint('📏 Auto calibration (field):');
      debugPrint(
        '   fieldPixelsLength = ${fieldPixelsLength.toStringAsFixed(1)} px',
      );
      debugPrint(
        '   scale = 1px = ${(_pixelsToMeters * 100).toStringAsFixed(1)} cm',
      );

      notifyListeners();
    }
  }

  bool get isCalibrating => false;
  double get currentScale => _pixelsToMeters;
  String get currentScaleText =>
      '1px = ${(_pixelsToMeters * 100).toStringAsFixed(1)}cm';

  void setTrackingSensitivity({
    required double positionSmoothFactor,
    required double speedSmoothFactor,
    required double maxJumpDistance,
    required bool usePrediction,
    required double predictionFactor,
  }) {
    _positionSmoothFactor = positionSmoothFactor.clamp(0.08, 0.70);
    _speedSmoothFactor = speedSmoothFactor.clamp(0.05, 0.50);
    _maxJumpDistance = maxJumpDistance.clamp(60, 250);
    _usePrediction = usePrediction;
    _predictionFactor = predictionFactor.clamp(0.0, 0.5);

    debugPrint('⚙️ Tracking sensitivity updated:');
    debugPrint('   positionSmooth=$_positionSmoothFactor');
    debugPrint('   speedSmooth=$_speedSmoothFactor');
    debugPrint('   maxJump=$_maxJumpDistance');
    debugPrint('   usePrediction=$_usePrediction');
    debugPrint('   predictionFactor=$_predictionFactor');
  }

  void setAdvancedTrackingTuning({
    double? alpha,
    double? beta,
    double? maxMeasurementJumpPx,
    double? hardRejectJumpPx,
    double? displaySmoothFactor,
    double? pixelsToMeters,
    int? sampleIntervalMs,
  }) {
    if (alpha != null) {
      _alphaBetaAlpha = alpha.clamp(0.08, 0.45);
    }
    if (beta != null) {
      _alphaBetaBeta = beta.clamp(0.01, 0.16);
    }
    if (maxMeasurementJumpPx != null) {
      _maxMeasurementJumpPx = maxMeasurementJumpPx.clamp(30.0, 180.0);
    }
    if (hardRejectJumpPx != null) {
      _hardRejectJumpPx = hardRejectJumpPx.clamp(60.0, 260.0);
    }
    if (displaySmoothFactor != null) {
      _displaySmoothFactor = displaySmoothFactor.clamp(0.05, 0.45);
    }
    if (pixelsToMeters != null) {
      _pixelsToMeters = pixelsToMeters.clamp(0.005, 0.20);
    }
    if (sampleIntervalMs != null) {
      sampleMs = sampleIntervalMs.clamp(33, 250);
    }

    notifyListeners();
  }

  void _recalculateLiveStats(PlayerTrack track) {
    if (track.points.isEmpty) {
      averageSpeedKmh = 0;
      maxSpeedKmh = 0;
      totalDistanceMeters = 0;
      sprintCount = 0;
      return;
    }

    double sumSpeed = 0;
    double maxSpeed = 0;
    double totalDistance = 0;

    int sprints = 0;
    bool sprintOpen = false;

    for (int i = 0; i < track.points.length; i++) {
      final p = track.points[i];
      sumSpeed += p.speed;
      if (p.speed > maxSpeed) maxSpeed = p.speed;

      if (p.speed >= 24.0 && !sprintOpen) {
        sprintOpen = true;
        sprints++;
      } else if (p.speed < 20.0) {
        sprintOpen = false;
      }

      if (i > 0) {
        final prev = track.points[i - 1].position;
        final dx = p.position.dx - prev.dx;
        final dy = p.position.dy - prev.dy;
        totalDistance += sqrt(dx * dx + dy * dy) * _localPixelsToMeters(p.position.dy);
      }
    }

    averageSpeedKmh = sumSpeed / track.points.length;
    maxSpeedKmh = maxSpeed;
    totalDistanceMeters = totalDistance;
    sprintCount = sprints;
  }

  void _generateAiEvents(PlayerTrack track) {
    if (track.points.length < 3) return;

    final last = track.points.last;
    final prev = track.points[track.points.length - 2];

    final accel = sqrt(last.ax * last.ax + last.ay * last.ay);
    final speed = last.speed;

    final directionNow = atan2(last.vy, last.vx);
    final directionPrev = atan2(prev.vy, prev.vx);
    double directionDelta = (directionNow - directionPrev).abs();
    if (directionDelta > pi) {
      directionDelta = 2 * pi - directionDelta;
    }

    if (speed >= 24.0 && last.timeMs - _lastSprintEventTimeMs > 4000) {
      _lastSprintEventTimeMs = last.timeMs;

      autoEvents.insert(
        0,
        AiDetectedEvent(
          type: 'sprint',
          title: 'Рывок',
          subtitle: 'Игрок резко набрал высокую скорость',
          timeMs: last.timeMs,
          confidence: 0.86,
          icon: Icons.flash_on_rounded,
          color: const Color(0xFFF59E0B),
          meta: {'speed': speed},
        ),
      );
    }

    if (accel >= 120.0 && last.timeMs - _lastAccelerationEventTimeMs > 3500) {
      _lastAccelerationEventTimeMs = last.timeMs;
      accelerationBurstCount++;

      autoEvents.insert(
        0,
        AiDetectedEvent(
          type: 'acceleration',
          title: 'Резкое ускорение',
          subtitle: 'Выраженный импульс ускорения',
          timeMs: last.timeMs,
          confidence: 0.78,
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF16A34A),
          meta: {'acceleration': accel},
        ),
      );
    }

    if (directionDelta >= 0.65 &&
        speed >= 8.0 &&
        last.timeMs - _lastDirectionEventTimeMs > 3000) {
      _lastDirectionEventTimeMs = last.timeMs;
      directionChangeCount++;

      autoEvents.insert(
        0,
        AiDetectedEvent(
          type: 'direction_change',
          title: 'Смена направления',
          subtitle: 'Возможный манёвр, обыгрыш или уход от соперника',
          timeMs: last.timeMs,
          confidence: 0.74,
          icon: Icons.turn_right_rounded,
          color: const Color(0xFF2563EB),
          meta: {'delta': directionDelta},
        ),
      );
    }

    if (autoEvents.length > 50) {
      autoEvents.removeRange(50, autoEvents.length);
    }
  }

  void _generateTtdSuggestions(PlayerTrack track) {
    if (track.points.length < 3) return;

    final last = track.points.last;
    final prev = track.points[track.points.length - 2];

    final accel = sqrt(last.ax * last.ax + last.ay * last.ay);

    final directionNow = atan2(last.vy, last.vx);
    final directionPrev = atan2(prev.vy, prev.vx);
    double directionDelta = (directionNow - directionPrev).abs();
    if (directionDelta > pi) {
      directionDelta = 2 * pi - directionDelta;
    }

    if (last.timeMs - _lastTtdSuggestionTimeMs < 2500) return;

    if (directionDelta >= 0.70 && last.speed >= 10.0) {
      _lastTtdSuggestionTimeMs = last.timeMs;

      ttdSuggestions.insert(
        0,
        AiTtdSuggestion(
          code: 'feint_dribble',
          title: 'Финт / дриблинг',
          section: 'Основные действия',
          timeMs: last.timeMs,
          confidence: 0.72,
          success: true,
          meta: {
            'speed': last.speed,
            'direction_delta': directionDelta,
          },
        ),
      );
    } else if (last.speed >= 6.0 && last.speed <= 18.0 && accel >= 90.0) {
      _lastTtdSuggestionTimeMs = last.timeMs;

      ttdSuggestions.insert(
        0,
        AiTtdSuggestion(
          code: 'forward_short',
          title: 'Передача вперед короткая',
          section: 'Передачи',
          timeMs: last.timeMs,
          confidence: 0.64,
          success: true,
          meta: {
            'speed': last.speed,
            'acceleration': accel,
          },
        ),
      );
    } else if (last.speed >= 12.0 && accel >= 130.0) {
      _lastTtdSuggestionTimeMs = last.timeMs;

      ttdSuggestions.insert(
        0,
        AiTtdSuggestion(
          code: 'interception',
          title: 'Перехват',
          section: 'Основные действия',
          timeMs: last.timeMs,
          confidence: 0.58,
          success: true,
          meta: {
            'speed': last.speed,
            'acceleration': accel,
          },
        ),
      );
    }

    if (ttdSuggestions.length > 50) {
      ttdSuggestions.removeRange(50, ttdSuggestions.length);
    }
  }
}

class TrackMotionResult {
  final double speedKmh;
  final double vx;
  final double vy;
  final double ax;
  final double ay;

  const TrackMotionResult({
    required this.speedKmh,
    required this.vx,
    required this.vy,
    required this.ax,
    required this.ay,
  });
}