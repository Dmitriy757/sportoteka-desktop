class TrackerLiveSessionModel {
  final int id;
  final int? clubId;
  final int teamId;
  final int? playerId;
  final String? playerName;
  final String? avatarUrl;
  final String deviceUuid;
  final String deviceName;
  final int? fieldId;
  final String status;
  final String source;
  final double totalDistanceM;
  final double maxSpeedKmh;
  final int sprintCount;
  final double loadScore;
  final double? latitude;
  final double? longitude;
  final double? fieldXM;
  final double? fieldYM;
  final double speedKmh;
  final int? batteryPercent;
  final String? lastSeenAt;

  const TrackerLiveSessionModel({
    required this.id,
    this.clubId,
    required this.teamId,
    this.playerId,
    this.playerName,
    this.avatarUrl,
    required this.deviceUuid,
    required this.deviceName,
    this.fieldId,
    required this.status,
    required this.source,
    required this.totalDistanceM,
    required this.maxSpeedKmh,
    required this.sprintCount,
    required this.loadScore,
    this.latitude,
    this.longitude,
    this.fieldXM,
    this.fieldYM,
    required this.speedKmh,
    this.batteryPercent,
    this.lastSeenAt,
  });

  bool get isOnline {
    if (status != 'active') return false;
    if (lastSeenAt == null || lastSeenAt!.trim().isEmpty) return false;
    final dt = DateTime.tryParse(lastSeenAt!.replaceFirst(' ', 'T'));
    if (dt == null) return true;
    return DateTime.now().difference(dt).inSeconds <= 45;
  }

  factory TrackerLiveSessionModel.fromJson(Map<String, dynamic> json) {
    return TrackerLiveSessionModel(
      id: _i(json['id']),
      clubId: _inull(json['club_id']),
      teamId: _i(json['team_id']),
      playerId: _inull(json['player_id']),
      playerName: _snull(json['player_name']),
      avatarUrl: _snull(json['avatar_url']),
      deviceUuid: '${json['device_uuid'] ?? json['device_id'] ?? ''}',
      deviceName: '${json['device_name'] ?? 'Трекер'}',
      fieldId: _inull(json['field_id']),
      status: '${json['status'] ?? 'active'}',
      source: '${json['source'] ?? 'tracker'}',
      totalDistanceM: _d(json['total_distance_m']),
      maxSpeedKmh: _d(json['max_speed_kmh']),
      sprintCount: _i(json['sprint_count']),
      loadScore: _d(json['load_score']),
      latitude: _dn(json['last_latitude'] ?? json['latitude']),
      longitude: _dn(json['last_longitude'] ?? json['longitude']),
      fieldXM: _dn(json['last_field_x_m'] ?? json['field_x_m']),
      fieldYM: _dn(json['last_field_y_m'] ?? json['field_y_m']),
      speedKmh: _d(json['last_speed_kmh'] ?? json['speed_kmh']),
      batteryPercent: _inull(json['battery_percent']),
      lastSeenAt: _snull(json['last_seen_at']),
    );
  }

  static int _i(dynamic v) => int.tryParse('$v') ?? (v is num ? v.toInt() : 0);
  static int? _inull(dynamic v) {
    final s = '$v'.trim();
    if (s.isEmpty || s == 'null') return null;
    return int.tryParse(s) ?? (v is num ? v.toInt() : null);
  }

  static double _d(dynamic v) => double.tryParse('$v') ?? (v is num ? v.toDouble() : 0);
  static double? _dn(dynamic v) {
    if (v == null) return null;
    final s = '$v'.trim();
    if (s.isEmpty || s == 'null') return null;
    return double.tryParse(s) ?? (v is num ? v.toDouble() : null);
  }

  static String? _snull(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty || s == 'null' ? null : s;
  }
}

class TrackerLivePointPayload {
  final int liveSessionId;
  final int clubId;
  final int teamId;
  final int? playerId;
  final String deviceUuid;
  final double latitude;
  final double longitude;
  final int timeMs;
  final int? batteryPercent;
  final double? fieldXM;
  final double? fieldYM;

  const TrackerLivePointPayload({
    required this.liveSessionId,
    required this.clubId,
    required this.teamId,
    required this.playerId,
    required this.deviceUuid,
    required this.latitude,
    required this.longitude,
    required this.timeMs,
    this.batteryPercent,
    this.fieldXM,
    this.fieldYM,
  });

  Map<String, dynamic> toJson() => {
        'live_session_id': liveSessionId,
        'club_id': clubId,
        'team_id': teamId,
        'player_id': playerId,
        'device_uuid': deviceUuid,
        'latitude': latitude,
        'longitude': longitude,
        'time_ms': timeMs,
        'battery_percent': batteryPercent,
        'field_x_m': fieldXM,
        'field_y_m': fieldYM,
      };
}
