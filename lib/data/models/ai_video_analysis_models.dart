class AiJobCreateRequest {
  final int? matchId;
  final String? title;
  final String? videoUrl;
  final String? localVideoPath;
  final String? videoPath;
  final String homeTeamKey;
  final String awayTeamKey;

  const AiJobCreateRequest({
    this.matchId,
    this.title,
    this.videoUrl,
    this.localVideoPath,
    this.videoPath,
    this.homeTeamKey = 'home',
    this.awayTeamKey = 'away',
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'match_id': matchId,
      'title': title,
      'video_url': videoUrl,
      'local_video_path': localVideoPath,
      'video_path': videoPath,
      'home_team_key': homeTeamKey,
      'away_team_key': awayTeamKey,
    };
    data.removeWhere((_, v) => v == null || (v is String && v.trim().isEmpty));
    return data;
  }
}

class AiJobCreateResponse {
  final bool success;
  final String jobId;
  final String status;
  final Map<String, dynamic> raw;

  const AiJobCreateResponse({
    required this.success,
    required this.jobId,
    required this.status,
    required this.raw,
  });

  factory AiJobCreateResponse.fromJson(Map<String, dynamic> json) {
    return AiJobCreateResponse(
      success: json['success'] != false,
      jobId: (json['job_id'] ?? json['jobId'] ?? json['id'] ?? '').toString(),
      status: (json['status'] ?? 'created').toString(),
      raw: json,
    );
  }
}

class AiJobStatusResponse {
  final bool success;
  final String jobId;
  final String status;
  final int progress;
  final String? error;
  final Map<String, dynamic> raw;

  const AiJobStatusResponse({
    required this.success,
    required this.jobId,
    required this.status,
    required this.progress,
    required this.raw,
    this.error,
  });

  bool get isDone {
    final s = status.toLowerCase().trim();
    return s == 'done' ||
        s == 'completed' ||
        s == 'complete' ||
        s == 'success' ||
        s == 'finished' ||
        progress >= 100;
  }

  bool get isFailed {
    final s = status.toLowerCase().trim();
    return s == 'failed' || s == 'error' || s == 'cancelled';
  }

  factory AiJobStatusResponse.fromJson(Map<String, dynamic> json) {
    return AiJobStatusResponse(
      success: json['success'] != false,
      jobId: (json['job_id'] ?? json['jobId'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      progress: _asInt(json['progress']),
      error: json['error']?.toString(),
      raw: json,
    );
  }
}

class AiFramePacket {
  final bool success;
  final bool hasFrame;
  final String jobId;
  final int requestedTimeMs;
  final int timeMs;
  final int? frameIndex;
  final List<AiTrackPacket> tracks;
  final Map<String, dynamic>? frame;
  final Map<String, dynamic>? ball;
  final Map<String, dynamic>? pitchRoi;
  final Map<String, dynamic> raw;

  const AiFramePacket({
    required this.success,
    required this.hasFrame,
    required this.jobId,
    required this.requestedTimeMs,
    required this.timeMs,
    required this.tracks,
    required this.raw,
    this.frameIndex,
    this.frame,
    this.ball,
    this.pitchRoi,
  });

  factory AiFramePacket.fromJson(Map<String, dynamic> json) {
    final frame = _asMap(json['frame']);
    final rawTracks = _asList(json['tracks']).isNotEmpty
        ? _asList(json['tracks'])
        : _asList(json['players']).isNotEmpty
            ? _asList(json['players'])
            : _asList(frame?['tracks']).isNotEmpty
                ? _asList(frame?['tracks'])
                : _asList(frame?['players']);

    final time = _asInt(json['time_ms'] ?? frame?['time_ms']);

    return AiFramePacket(
      success: json['success'] != false,
      hasFrame: json['has_frame'] == true || frame != null || rawTracks.isNotEmpty,
      jobId: (json['job_id'] ?? json['jobId'] ?? '').toString(),
      requestedTimeMs: _asInt(json['requested_time_ms'] ?? json['requestedTimeMs']),
      timeMs: time,
      frameIndex: json.containsKey('frame_index')
          ? _asInt(json['frame_index'])
          : frame != null && frame.containsKey('frame_index')
              ? _asInt(frame['frame_index'])
              : null,
      frame: frame,
      ball: _asMap(json['ball'] ?? frame?['ball']),
      pitchRoi: _asMap(json['pitch_roi'] ?? frame?['pitch_roi']),
      tracks: rawTracks
          .whereType<Map>()
          .map((e) => AiTrackPacket.fromJson(Map<String, dynamic>.from(e), fallbackTimeMs: time))
          .where((e) => e.trackId.trim().isNotEmpty)
          .toList(),
      raw: json,
    );
  }
}

class AiTrackPacket {
  final String trackId;
  final int? playerId;
  final String playerName;
  final String? teamTag;
  final double speedKmh;
  final int? jerseyNumber;
  final AiBox? bbox;
  final AiBox? displayBBox;
  final AiPoint? imagePoint;
  final int timeMs;
  final double confidence;
  final bool hasBall;
  final Map<String, dynamic> raw;

  const AiTrackPacket({
    required this.trackId,
    required this.playerName,
    required this.timeMs,
    required this.raw,
    this.playerId,
    this.teamTag,
    this.speedKmh = 0,
    this.jerseyNumber,
    this.bbox,
    this.displayBBox,
    this.imagePoint,
    this.confidence = 0,
    this.hasBall = false,
  });

  factory AiTrackPacket.fromJson(
    Map<String, dynamic> json, {
    int fallbackTimeMs = 0,
  }) {
    final rawTrackId = json['track_id'] ?? json['trackId'] ?? json['id'];
    final trackId = rawTrackId == null || rawTrackId.toString().trim().isEmpty
        ? (json['player_id'] ?? '').toString()
        : rawTrackId.toString();

    final bbox = AiBox.fromAny(json['bbox'] ?? json['box'] ?? json['rect']);

    // Новый AI-сервер отдаёт x/y как координаты стандартного поля 0..100.
    final x = _firstDouble([
      json['field_x'],
      json['fieldX'],
      json['pitch_x'],
      json['pitchX'],
      json['x'],
    ]);
    final y = _firstDouble([
      json['field_y'],
      json['fieldY'],
      json['pitch_y'],
      json['pitchY'],
      json['y'],
    ]);

    AiPoint? point;
    if (x != null && y != null) {
      point = AiPoint(x: x.clamp(0.0, 100.0), y: y.clamp(0.0, 100.0));
    } else if (json['point'] is Map) {
      final p = Map<String, dynamic>.from(json['point'] as Map);
      point = AiPoint(
        x: _asDouble(p['x']).clamp(0.0, 100.0),
        y: _asDouble(p['y']).clamp(0.0, 100.0),
      );
    } else if (bbox != null) {
      point = AiPoint(x: bbox.centerX, y: bbox.bottom);
    }

    return AiTrackPacket(
      trackId: trackId,
      playerId: _nullableInt(json['player_id'] ?? json['playerId']),
      playerName: (json['name'] ??
              json['player_name'] ??
              json['playerName'] ??
              'Трек $trackId')
          .toString(),
      teamTag: (json['team'] ?? json['team_key'] ?? json['teamTag'])?.toString(),
      speedKmh: _asDouble(json['speed_kmh'] ?? json['speedKmh'] ?? json['speed']),
      jerseyNumber: _nullableInt(json['jersey_number'] ?? json['number']),
      bbox: bbox,
      displayBBox: AiBox.fromAny(json['display_bbox'] ?? json['displayBBox']) ?? bbox,
      imagePoint: point,
      timeMs: _asInt(json['time_ms'] ?? json['timeMs'] ?? fallbackTimeMs),
      confidence: _asDouble(json['confidence'] ?? json['conf']),
      hasBall: _asBool(json['has_ball'] ?? json['hasBall']),
      raw: json,
    );
  }
}

class AiBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const AiBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get centerX => (left + right) / 2.0;
  double get centerY => (top + bottom) / 2.0;

  static AiBox? fromAny(dynamic raw) {
    if (raw is List && raw.length >= 4) {
      return AiBox(
        left: _asDouble(raw[0]),
        top: _asDouble(raw[1]),
        right: _asDouble(raw[2]),
        bottom: _asDouble(raw[3]),
      );
    }

    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final left = _asDouble(m['left'] ?? m['x1'] ?? m['x']);
      final top = _asDouble(m['top'] ?? m['y1'] ?? m['y']);

      if (m.containsKey('right') || m.containsKey('x2')) {
        return AiBox(
          left: left,
          top: top,
          right: _asDouble(m['right'] ?? m['x2']),
          bottom: _asDouble(m['bottom'] ?? m['y2']),
        );
      }

      return AiBox(
        left: left,
        top: top,
        right: left + _asDouble(m['width'] ?? m['w']),
        bottom: top + _asDouble(m['height'] ?? m['h']),
      );
    }

    return null;
  }
}

class AiPoint {
  final double x;
  final double y;

  const AiPoint({
    required this.x,
    required this.y,
  });
}

class AiCalibrationPoint {
  final String key;
  final double x;
  final double y;

  const AiCalibrationPoint({
    required this.key,
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'x': x,
        'y': y,
      };
}

class AiPlayerSummary {
  final String trackId;
  final Map<String, dynamic> raw;

  const AiPlayerSummary({
    required this.trackId,
    required this.raw,
  });

  factory AiPlayerSummary.fromJson(Map<String, dynamic> json) {
    return AiPlayerSummary(
      trackId: (json['track_id'] ?? json['trackId'] ?? '').toString(),
      raw: json,
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  return const [];
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0.0;
}

double? _firstDouble(List<dynamic> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse('$value'.replaceAll(',', '.'));
    if (parsed != null) return parsed;
  }
  return null;
}

bool _asBool(dynamic value) {
  if (value == true || value == 1) return true;
  final s = '${value ?? ''}'.toLowerCase().trim();
  return s == 'true' || s == '1' || s == 'yes';
}
