import 'dart:convert';

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
  final String activityType;
  final double totalDistanceM;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final double metersPerMinute;
  final double loadScore;
  final double loadPerMinute;
  final double fatigueIndex;
  final double speedDropPercent;
  final double hsrDistanceM;
  final double hirDistanceM;
  final double vhirDistanceM;
  final double sprintDistanceM;
  final int sprintCount;
  final int accelCount;
  final int decelCount;
  final int changeOfDirectionCount;
  final int footballMovementScore;
  final double metabolicPowerProxy;
  final int durationSec;
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
    this.activityType = '',
    required this.totalDistanceM,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.metersPerMinute,
    required this.loadScore,
    required this.loadPerMinute,
    required this.fatigueIndex,
    required this.speedDropPercent,
    required this.hsrDistanceM,
    required this.hirDistanceM,
    required this.vhirDistanceM,
    required this.sprintDistanceM,
    required this.sprintCount,
    required this.accelCount,
    required this.decelCount,
    required this.changeOfDirectionCount,
    required this.footballMovementScore,
    required this.metabolicPowerProxy,
    required this.durationSec,
    this.latitude,
    this.longitude,
    this.fieldXM,
    this.fieldYM,
    required this.speedKmh,
    this.batteryPercent,
    this.lastSeenAt,
  });

  bool get isOnline {
    if (status != 'active' && status != 'online' && status != 'live') return false;
    if (lastSeenAt == null || lastSeenAt!.trim().isEmpty) return true;
    final dt = DateTime.tryParse(lastSeenAt!.replaceFirst(' ', 'T'));
    if (dt == null) return true;
    return DateTime.now().difference(dt).inSeconds <= 45;
  }

  factory TrackerLiveSessionModel.fromJson(Map<String, dynamic> json) {
    final distance = _dAny(json, const [
      'total_distance_m',
      'distance_m',
      'distance',
      'total_distance',
      'session_distance_m',
    ]);
    final speed = _dAny(json, const [
      'last_speed_kmh',
      'speed_kmh',
      'current_speed_kmh',
      'speed',
    ]);
    final maxSpeed = _dAny(json, const [
      'max_speed_kmh',
      'top_speed_kmh',
      'max_speed',
    ]);
    final avgSpeed = _dAny(json, const [
      'avg_speed_kmh',
      'average_speed_kmh',
      'avg_speed',
    ]);
    final metersPerMinute = _dAny(json, const [
      'meterage_per_min',
      'meters_per_minute',
      'meters_per_min',
      'm_per_min',
      'distance_per_min',
    ]);
    final load = _dAny(json, const [
      'load_score',
      'player_load',
      'player_load_estimate',
      'load',
    ]);
    final hsr = _dAny(json, const [
      'hsr_distance_m',
      'high_speed_distance_m',
      'high_intensity_distance_m',
    ]);
    final hir = _dAny(json, const [
      'hir_distance_m',
      'hir_m',
      'hir',
      'run_distance_m',
      'high_intensity_run_m',
    ]);
    final vhir = _dAny(json, const [
      'vhir_distance_m',
      'vhir_m',
      'vhir',
      'very_high_intensity_distance_m',
    ]);
    final sprint = _dAny(json, const [
      'sprint_distance_m',
      'sprint_distance',
      'sprint_m',
      'sprints_distance_m',
    ]);

    return TrackerLiveSessionModel(
      id: _i(json['id'] ?? json['live_session_id']),
      clubId: _inull(json['club_id']),
      teamId: _i(json['team_id']),
      playerId: _inull(json['player_id']),
      playerName: _snull(json['player_name'] ?? json['name'] ?? json['full_name']),
      avatarUrl: _snull(json['avatar_url'] ?? json['avatar'] ?? json['photo_url'] ?? json['photo']),
      deviceUuid: '${json['device_uuid'] ?? json['device_id'] ?? json['uuid'] ?? ''}',
      deviceName: '${json['device_name'] ?? json['tracker_name'] ?? json['name'] ?? 'Трекер'}',
      fieldId: _inull(json['field_id']),
      status: '${json['status'] ?? 'active'}',
      source: '${json['source'] ?? 'tracker'}',
      activityType: '${json['activity_type'] ?? ''}',
      totalDistanceM: distance,
      maxSpeedKmh: maxSpeed <= 0 ? speed : maxSpeed,
      avgSpeedKmh: avgSpeed,
      metersPerMinute: metersPerMinute,
      loadScore: load,
      loadPerMinute: _dAny(json, const ['load_per_min', 'load_per_minute']),
      fatigueIndex: _dAny(json, const ['fatigue_index', 'fatigue_percent', 'fatigue']),
      speedDropPercent: _dAny(json, const ['speed_drop_percent', 'speed_drop']),
      hsrDistanceM: hsr,
      hirDistanceM: hir,
      vhirDistanceM: vhir <= 0 ? hsr : vhir,
      sprintDistanceM: sprint,
      sprintCount: _iAny(json, const ['sprint_count', 'sprints_count', 'sprints']),
      accelCount: _iAny(json, const ['accel_count', 'acc_count', 'acc', 'accelerations', 'acceleration_count', 'accelerations_count']),
      decelCount: _iAny(json, const ['decel_count', 'dec_count', 'dec', 'decelerations', 'deceleration_count', 'decelerations_count']),
      changeOfDirectionCount: _iAny(json, const ['change_of_direction_count', 'cod_count', 'cod', 'turn_count', 'turns', 'change_of_direction']),
      footballMovementScore: _iAny(json, const ['football_movement_score', 'movement_score']),
      metabolicPowerProxy: _dAny(json, const ['metabolic_power_proxy', 'metabolic_power', 'metabolic_score']),
      durationSec: _iAny(json, const ['duration_sec', 'duration_seconds', 'session_duration_sec']),
      latitude: _dn(json['last_latitude'] ?? json['latitude'] ?? json['lat']),
      longitude: _dn(json['last_longitude'] ?? json['longitude'] ?? json['lng'] ?? json['lon']),
      fieldXM: _dn(json['last_field_x_m'] ?? json['field_x_m'] ?? json['x_m']),
      fieldYM: _dn(json['last_field_y_m'] ?? json['field_y_m'] ?? json['y_m']),
      speedKmh: speed,
      batteryPercent: _inull(json['battery_percent'] ?? json['battery']),
      lastSeenAt: _snull(json['last_seen_at'] ?? json['updated_at'] ?? json['last_point_at']),
    );
  }

  static int _i(dynamic v) => int.tryParse('$v') ?? (v is num ? v.toInt() : 0);
  static int? _inull(dynamic v) {
    final s = '$v'.trim();
    if (s.isEmpty || s == 'null') return null;
    return int.tryParse(s) ?? (v is num ? v.toInt() : null);
  }

  static int _iAny(Map<String, dynamic> json, List<String> keys) {
    int? zeroCandidate;
    for (final map in _metricMaps(json)) {
      for (final k in keys) {
        final value = map[k];
        if (value == null) continue;
        final parsed = int.tryParse('$value') ?? (value is num ? value.toInt() : null);
        if (parsed == null) continue;
        if (parsed != 0) return parsed;
        zeroCandidate ??= parsed;
      }
    }
    return zeroCandidate ?? 0;
  }

  static double _d(dynamic v) => double.tryParse('$v') ?? (v is num ? v.toDouble() : 0);
  static double _dAny(Map<String, dynamic> json, List<String> keys) {
    double? zeroCandidate;
    for (final map in _metricMaps(json)) {
      for (final k in keys) {
        final value = map[k];
        if (value == null) continue;
        final parsed = double.tryParse('$value') ?? (value is num ? value.toDouble() : null);
        if (parsed == null || parsed.isNaN || parsed.isInfinite) continue;
        if (parsed.abs() > 0.000001) return parsed;
        zeroCandidate ??= parsed;
      }
    }
    return zeroCandidate ?? 0;
  }

  static List<Map<String, dynamic>> _metricMaps(Map<String, dynamic> json) {
    final out = <Map<String, dynamic>>[json];
    final seen = <int>{identityHashCode(json)};

    void add(dynamic value) {
      if (value == null) return;
      dynamic decoded = value;
      if (value is String) {
        final text = value.trim();
        if (text.isEmpty || text == 'null') return;
        try {
          decoded = jsonDecode(text);
        } catch (_) {
          return;
        }
      }
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final hash = identityHashCode(map);
        if (seen.add(hash)) out.add(map);
        for (final nestedKey in const [
          'analysis_json',
          'analysis',
          'metrics',
          'live_metrics',
          'movement_profile',
          'football_movement_profile',
          'zones',
          'speed_zones',
          'summary',
        ]) {
          add(map[nestedKey]);
        }
      }
    }

    for (final key in const [
      'analysis_json',
      'analysis',
      'metrics',
      'live_metrics',
      'movement_profile',
      'football_movement_profile',
      'zones',
      'speed_zones',
      'summary',
    ]) {
      add(json[key]);
    }
    return out;
  }

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

  // Локально рассчитанные Live-показатели. Если PHP уже умеет принимать эти поля,
  // сервер сохранит не только координату, но и всю онлайн-аналитику.
  final double? speedKmh;
  final double? rawSpeedKmh;
  final double? distanceDeltaM;
  final double? totalDistanceM;
  final double? maxSpeedKmh;
  final double? avgSpeedKmh;
  final double? meteragePerMin;
  final double? loadScore;
  final double? loadPerMin;
  final double? fatigueIndex;
  final double? speedDropPercent;
  final double? hsrDistanceM;
  final double? hirDistanceM;
  final double? vhirDistanceM;
  final double? sprintDistanceM;
  final int? sprintCount;
  final int? accelCount;
  final int? decelCount;
  final int? changeOfDirectionCount;
  final int? footballMovementScore;
  final double? metabolicPowerProxy;
  final int? durationSec;
  final Map<String, dynamic>? analysisJson;
  final String? rawHex;

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
    this.speedKmh,
    this.rawSpeedKmh,
    this.distanceDeltaM,
    this.totalDistanceM,
    this.maxSpeedKmh,
    this.avgSpeedKmh,
    this.meteragePerMin,
    this.loadScore,
    this.loadPerMin,
    this.fatigueIndex,
    this.speedDropPercent,
    this.hsrDistanceM,
    this.hirDistanceM,
    this.vhirDistanceM,
    this.sprintDistanceM,
    this.sprintCount,
    this.accelCount,
    this.decelCount,
    this.changeOfDirectionCount,
    this.footballMovementScore,
    this.metabolicPowerProxy,
    this.durationSec,
    this.analysisJson,
    this.rawHex,
  });

  Map<String, dynamic> toJson() => _withoutNulls({
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
        'speed_kmh': speedKmh,
        'raw_speed_kmh': rawSpeedKmh,
        'distance_delta_m': distanceDeltaM,
        'total_distance_m': totalDistanceM,
        'distance_m': totalDistanceM,
        'max_speed_kmh': maxSpeedKmh,
        'avg_speed_kmh': avgSpeedKmh,
        'meterage_per_min': meteragePerMin,
        'meters_per_minute': meteragePerMin,
        'load_score': loadScore,
        'load_per_min': loadPerMin,
        'fatigue_index': fatigueIndex,
        'speed_drop_percent': speedDropPercent,
        'hsr_distance_m': hsrDistanceM,
        'hir_distance_m': hirDistanceM,
        'vhir_distance_m': vhirDistanceM,
        'sprint_distance_m': sprintDistanceM,
        'sprint_count': sprintCount,
        'accel_count': accelCount,
        'decel_count': decelCount,
        'change_of_direction_count': changeOfDirectionCount,
        'football_movement_score': footballMovementScore,
        'metabolic_power_proxy': metabolicPowerProxy,
        'duration_sec': durationSec,
        'analysis_json': analysisJson,
        'raw_hex': rawHex,
      });

  static Map<String, dynamic> _withoutNulls(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    input.forEach((key, value) {
      if (value != null) out[key] = value;
    });
    return out;
  }
}
