class AiJobCreateRequest {
  final int? matchId;
  final String? videoUrl;
  final String? localVideoPath;

  const AiJobCreateRequest({
    this.matchId,
    this.videoUrl,
    this.localVideoPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'match_id': matchId,
      'video_url': videoUrl,
      'local_video_path': localVideoPath,
    };
  }
}

class AiJobCreateResponse {
  final bool success;
  final String jobId;

  const AiJobCreateResponse({
    required this.success,
    required this.jobId,
  });

  factory AiJobCreateResponse.fromJson(Map<String, dynamic> json) {
    return AiJobCreateResponse(
      success: json['success'] == true,
      jobId: json['job_id']?.toString() ?? '',
    );
  }
}

class AiJobStatusResponse {
  final String jobId;
  final String status;
  final int progress;
  final String? error;

  const AiJobStatusResponse({
    required this.jobId,
    required this.status,
    required this.progress,
    this.error,
  });

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing';
  bool get isQueued => status == 'queued';

  factory AiJobStatusResponse.fromJson(Map<String, dynamic> json) {
    return AiJobStatusResponse(
      jobId: json['job_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'queued',
      progress: (json['progress'] ?? 0) is int
          ? (json['progress'] ?? 0) as int
          : int.tryParse(json['progress'].toString()) ?? 0,
      error: json['error']?.toString(),
    );
  }
}

class AiBBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const AiBBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;

  factory AiBBox.fromJson(Map<String, dynamic> json) {
    return AiBBox(
      left: (json['left'] ?? 0).toDouble(),
      top: (json['top'] ?? 0).toDouble(),
      right: (json['right'] ?? 0).toDouble(),
      bottom: (json['bottom'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
    };
  }
}

class AiPoint2D {
  final double x;
  final double y;

  const AiPoint2D({
    required this.x,
    required this.y,
  });

  factory AiPoint2D.fromJson(Map<String, dynamic> json) {
    return AiPoint2D(
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }
}

class AiTrackPacket {
  final String trackId;
  final int? playerId;
  final String playerName;
  final String? teamTag;
  final int? jerseyNumber;
  final AiBBox? bbox;
  final AiBBox? displayBBox;
  final AiPoint2D? imagePoint;
  final AiPoint2D? fieldPointM;
  final double speedKmh;
  final double confidence;
  final bool isOccluded;

  const AiTrackPacket({
    required this.trackId,
    this.playerId,
    required this.playerName,
    this.teamTag,
    this.jerseyNumber,
    this.bbox,
    this.displayBBox,
    this.imagePoint,
    this.fieldPointM,
    required this.speedKmh,
    required this.confidence,
    required this.isOccluded,
  });

  factory AiTrackPacket.fromJson(Map<String, dynamic> json) {
    return AiTrackPacket(
      trackId: json['track_id']?.toString() ?? '',
      playerId: json['player_id'] as int?,
      playerName: json['player_name']?.toString() ?? 'Игрок',
      teamTag: json['team_tag']?.toString(),
      jerseyNumber: json['jersey_number'] as int?,
      bbox: json['bbox'] is Map<String, dynamic>
          ? AiBBox.fromJson(json['bbox'] as Map<String, dynamic>)
          : null,
      displayBBox: json['display_bbox'] is Map<String, dynamic>
          ? AiBBox.fromJson(json['display_bbox'] as Map<String, dynamic>)
          : null,
      imagePoint: json['image_point'] is Map<String, dynamic>
          ? AiPoint2D.fromJson(json['image_point'] as Map<String, dynamic>)
          : null,
      fieldPointM: json['field_point_m'] is Map<String, dynamic>
          ? AiPoint2D.fromJson(json['field_point_m'] as Map<String, dynamic>)
          : null,
      speedKmh: (json['speed_kmh'] ?? 0).toDouble(),
      confidence: (json['confidence'] ?? 0).toDouble(),
      isOccluded: json['is_occluded'] == true,
    );
  }
}

class AiBallPacket {
  final AiBBox? bbox;
  final AiPoint2D? imagePoint;
  final AiPoint2D? fieldPointM;
  final double confidence;

  const AiBallPacket({
    this.bbox,
    this.imagePoint,
    this.fieldPointM,
    required this.confidence,
  });

  factory AiBallPacket.fromJson(Map<String, dynamic> json) {
    return AiBallPacket(
      bbox: json['bbox'] is Map<String, dynamic>
          ? AiBBox.fromJson(json['bbox'] as Map<String, dynamic>)
          : null,
      imagePoint: json['image_point'] is Map<String, dynamic>
          ? AiPoint2D.fromJson(json['image_point'] as Map<String, dynamic>)
          : null,
      fieldPointM: json['field_point_m'] is Map<String, dynamic>
          ? AiPoint2D.fromJson(json['field_point_m'] as Map<String, dynamic>)
          : null,
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}

class AiFramePacket {
  final int timeMs;
  final List<AiTrackPacket> tracks;
  final AiBallPacket? ball;

  const AiFramePacket({
    required this.timeMs,
    required this.tracks,
    this.ball,
  });

  factory AiFramePacket.fromJson(Map<String, dynamic> json) {
    final rawTracks = (json['tracks'] as List?) ?? const [];

    return AiFramePacket(
      timeMs: (json['time_ms'] ?? 0) is int
          ? (json['time_ms'] ?? 0) as int
          : int.tryParse(json['time_ms'].toString()) ?? 0,
      tracks: rawTracks
          .whereType<Map>()
          .map((e) => AiTrackPacket.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      ball: json['ball'] is Map<String, dynamic>
          ? AiBallPacket.fromJson(json['ball'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AiCalibrationPoint {
  final double imageX;
  final double imageY;
  final double fieldXM;
  final double fieldYM;

  const AiCalibrationPoint({
    required this.imageX,
    required this.imageY,
    required this.fieldXM,
    required this.fieldYM,
  });

  Map<String, dynamic> toJson() {
    return {
      'image_x': imageX,
      'image_y': imageY,
      'field_x_m': fieldXM,
      'field_y_m': fieldYM,
    };
  }
}

class AiPlayerSummary {
  final String trackId;
  final double distanceM;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final int sprintCount;

  const AiPlayerSummary({
    required this.trackId,
    required this.distanceM,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.sprintCount,
  });

  factory AiPlayerSummary.fromJson(Map<String, dynamic> json) {
    return AiPlayerSummary(
      trackId: json['track_id']?.toString() ?? '',
      distanceM: (json['distance_m'] ?? 0).toDouble(),
      avgSpeedKmh: (json['avg_speed_kmh'] ?? 0).toDouble(),
      maxSpeedKmh: (json['max_speed_kmh'] ?? 0).toDouble(),
      sprintCount: (json['sprint_count'] ?? 0) is int
          ? (json['sprint_count'] ?? 0) as int
          : int.tryParse(json['sprint_count'].toString()) ?? 0,
    );
  }
}