class TrackerPlayerOption {
  final int id;
  final String name;
  final String? avatar;
  final String? number;
  final String? position;

  const TrackerPlayerOption({
    required this.id,
    required this.name,
    this.avatar,
    this.number,
    this.position,
  });

  factory TrackerPlayerOption.fromJson(Map<String, dynamic> json) {
    final firstName = '${json['first_name'] ?? json['firstName'] ?? ''}'.trim();
    final lastName = '${json['last_name'] ?? json['lastName'] ?? ''}'.trim();
    final full = '${json['name'] ?? json['full_name'] ?? json['fullName'] ?? '$firstName $lastName'}'.trim();

    return TrackerPlayerOption(
      id: int.tryParse('${json['id'] ?? json['player_id'] ?? json['playerId'] ?? 0}') ?? 0,
      name: full.isEmpty ? 'Игрок' : full,
      avatar: '${json['avatar_url'] ?? json['avatar'] ?? json['photo_url'] ?? json['user_photo'] ?? json['photo'] ?? json['image'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['avatar_url'] ?? json['avatar'] ?? json['photo_url'] ?? json['user_photo'] ?? json['photo'] ?? json['image']}',
      number: '${json['jersey_number'] ?? json['jersey_number'] ?? json['number'] ?? json['shirt_number'] ?? ''}'.trim().isEmpty ? null : '${json['jersey_number'] ?? json['number'] ?? json['shirt_number']}',
      position: '${json['position'] ?? ''}'.trim().isEmpty ? null : '${json['position']}',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'number': number,
        'position': position,
      };
}

class TrackerDeviceModel {
  final int? id;
  final int? clubId;
  final int? teamId;
  final int? playerId;
  final String deviceUuid;
  final String deviceName;
  final int? batteryPercent;
  final bool isNearby;
  final String? playerName;

  const TrackerDeviceModel({
    this.id,
    this.clubId,
    this.teamId,
    this.playerId,
    required this.deviceUuid,
    required this.deviceName,
    this.batteryPercent,
    this.isNearby = false,
    this.playerName,
  });

  factory TrackerDeviceModel.fromJson(Map<String, dynamic> json) {
    return TrackerDeviceModel(
      id: int.tryParse('${json['id'] ?? ''}'),
      clubId: int.tryParse('${json['club_id'] ?? json['clubId'] ?? ''}'),
      teamId: int.tryParse('${json['team_id'] ?? json['teamId'] ?? ''}'),
      playerId: int.tryParse('${json['player_id'] ?? json['playerId'] ?? ''}'),
      deviceUuid: '${json['device_uuid'] ?? json['device_id'] ?? json['uuid'] ?? ''}',
      deviceName: '${json['device_name'] ?? json['name'] ?? 'Трекер'}',
      batteryPercent: int.tryParse('${json['battery_percent'] ?? ''}'),
      isNearby: '${json['is_nearby'] ?? json['nearby'] ?? 0}' == '1' || json['is_nearby'] == true,
      playerName: '${json['player_name'] ?? ''}'.trim().isEmpty ? null : '${json['player_name']}',
    );
  }
}

class TrackerSpeedSettings {
  final String preset;
  final double jogRuleMps;
  final double mediumRuleMps;
  final double highRuleMps;
  final double sprintRuleMps;
  final double sprintTimeSec;
  final double accelerationRuleMps2;
  final bool isSprintTraceMode;

  const TrackerSpeedSettings({
    this.preset = 'youth',
    this.jogRuleMps = 1.2,
    this.mediumRuleMps = 3.0,
    this.highRuleMps = 5.0,
    this.sprintRuleMps = 5.5,
    this.sprintTimeSec = 2.0,
    this.accelerationRuleMps2 = 0.3,
    this.isSprintTraceMode = true,
  });

  factory TrackerSpeedSettings.fromJson(Map<String, dynamic> json) {
    return TrackerSpeedSettings(
      preset: '${json['preset'] ?? 'youth'}',
      jogRuleMps: _d(json['jog_rule_mps'], 1.2),
      mediumRuleMps: _d(json['medium_rule_mps'], 3.0),
      highRuleMps: _d(json['high_rule_mps'], 5.0),
      sprintRuleMps: _d(json['sprint_rule_mps'], 5.5),
      sprintTimeSec: _d(json['sprint_time_sec'], 2.0),
      accelerationRuleMps2: _d(json['acceleration_rule_mps2'], 0.3),
      isSprintTraceMode: '${json['is_sprint_trace_mode'] ?? 1}' == '1' || json['is_sprint_trace_mode'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'preset': preset,
        'jog_rule_mps': jogRuleMps,
        'medium_rule_mps': mediumRuleMps,
        'high_rule_mps': highRuleMps,
        'sprint_rule_mps': sprintRuleMps,
        'sprint_time_sec': sprintTimeSec,
        'acceleration_rule_mps2': accelerationRuleMps2,
        'is_sprint_trace_mode': isSprintTraceMode ? 1 : 0,
      };

  TrackerSpeedSettings copyWith({
    String? preset,
    double? jogRuleMps,
    double? mediumRuleMps,
    double? highRuleMps,
    double? sprintRuleMps,
    double? sprintTimeSec,
    double? accelerationRuleMps2,
    bool? isSprintTraceMode,
  }) {
    return TrackerSpeedSettings(
      preset: preset ?? this.preset,
      jogRuleMps: jogRuleMps ?? this.jogRuleMps,
      mediumRuleMps: mediumRuleMps ?? this.mediumRuleMps,
      highRuleMps: highRuleMps ?? this.highRuleMps,
      sprintRuleMps: sprintRuleMps ?? this.sprintRuleMps,
      sprintTimeSec: sprintTimeSec ?? this.sprintTimeSec,
      accelerationRuleMps2: accelerationRuleMps2 ?? this.accelerationRuleMps2,
      isSprintTraceMode: isSprintTraceMode ?? this.isSprintTraceMode,
    );
  }

  static double _d(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }
}

class TrackerPlayerLoadRow {
  final int? playerId;
  final String playerName;
  final String? avatar;
  final int sessionsCount;
  final double distanceM;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double highSpeedDistanceM;
  final double sprintDistanceM;
  final int sprintCount;
  final int accelerationCount;
  final int decelerationCount;
  final double loadScore;

  const TrackerPlayerLoadRow({
    required this.playerId,
    required this.playerName,
    this.avatar,
    required this.sessionsCount,
    required this.distanceM,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.highSpeedDistanceM,
    required this.sprintDistanceM,
    required this.sprintCount,
    required this.accelerationCount,
    required this.decelerationCount,
    required this.loadScore,
  });

  factory TrackerPlayerLoadRow.fromJson(Map<String, dynamic> json) {
    return TrackerPlayerLoadRow(
      playerId: int.tryParse('${json['player_id'] ?? ''}'),
      playerName: '${json['player_name'] ?? json['name'] ?? json['full_name'] ?? 'Игрок'}',
      avatar: _photo(json),
      sessionsCount: int.tryParse('${json['sessions_count'] ?? 0}') ?? 0,
      distanceM: _d(json['distance_m']),
      avgSpeedKmh: _d(json['avg_speed_kmh']),
      maxSpeedKmh: _d(json['max_speed_kmh']),
      highSpeedDistanceM: _d(json['high_speed_distance_m']),
      sprintDistanceM: _d(json['sprint_distance_m']),
      sprintCount: int.tryParse('${json['sprint_count'] ?? 0}') ?? 0,
      accelerationCount: int.tryParse('${json['acceleration_count'] ?? 0}') ?? 0,
      decelerationCount: int.tryParse('${json['deceleration_count'] ?? 0}') ?? 0,
      loadScore: _d(json['load_score']),
    );
  }

  static String? _photo(Map<String, dynamic> json) {
    final raw = '${json['photo'] ?? json['avatar'] ?? json['image'] ?? json['photo_url'] ?? json['avatar_url'] ?? json['user_photo'] ?? ''}'.trim();
    if (raw.isEmpty || raw == 'null') return null;
    return raw;
  }

  static double _d(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}

class TrackerDashboardModel {
  final Map<String, dynamic> summary;
  final List<TrackerPlayerLoadRow> players;
  final List<Map<String, dynamic>> alerts;

  const TrackerDashboardModel({
    required this.summary,
    required this.players,
    required this.alerts,
  });

  factory TrackerDashboardModel.fromJson(Map<String, dynamic> json) {
    return TrackerDashboardModel(
      summary: Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
      players: (json['players'] as List? ?? const [])
          .map((e) => TrackerPlayerLoadRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      alerts: (json['alerts'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

class TrackerSessionModel {
  final int id;
  final int? playerId;
  final String? playerName;
  final String deviceName;
  final String title;
  final String createdAt;
  final String processingStatus;
  final double distanceM;
  final double maxSpeedKmh;
  final int sprintCount;
  final double loadScore;

  const TrackerSessionModel({
    required this.id,
    this.playerId,
    this.playerName,
    required this.deviceName,
    required this.title,
    required this.createdAt,
    required this.processingStatus,
    required this.distanceM,
    required this.maxSpeedKmh,
    required this.sprintCount,
    required this.loadScore,
  });

  factory TrackerSessionModel.fromJson(Map<String, dynamic> json) {
    return TrackerSessionModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      playerId: int.tryParse('${json['player_id'] ?? ''}'),
      playerName: '${json['player_name'] ?? ''}'.trim().isEmpty ? null : '${json['player_name']}',
      deviceName: '${json['device_name'] ?? 'Трекер'}',
      title: '${json['title'] ?? 'Сессия'}',
      createdAt: '${json['created_at'] ?? ''}',
      processingStatus: '${json['processing_status'] ?? 'new'}',
      distanceM: _d(json['distance_m']),
      maxSpeedKmh: _d(json['max_speed_kmh']),
      sprintCount: int.tryParse('${json['sprint_count'] ?? 0}') ?? 0,
      loadScore: _d(json['load_score']),
    );
  }

  static double _d(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}

class TrackerHeatPoint {
  final double x;
  final double y;
  final double value;

  const TrackerHeatPoint({required this.x, required this.y, required this.value});

  factory TrackerHeatPoint.fromJson(Map<String, dynamic> json) {
    return TrackerHeatPoint(
      x: _d(json['x']),
      y: _d(json['y']),
      value: _d(json['value'], 1),
    );
  }

  static double _d(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }
}


class TrackerFieldModel {
  final int? id;
  final int? clubId;
  final int? teamId;
  final String title;
  final double lengthM;
  final double widthM;
  final double? cornerALat;
  final double? cornerALng;
  final double? cornerBLat;
  final double? cornerBLng;
  final double? cornerCLat;
  final double? cornerCLng;
  final double? cornerDLat;
  final double? cornerDLng;
  final bool isDefault;

  const TrackerFieldModel({
    this.id,
    this.clubId,
    this.teamId,
    required this.title,
    this.lengthM = 105,
    this.widthM = 68,
    this.cornerALat,
    this.cornerALng,
    this.cornerBLat,
    this.cornerBLng,
    this.cornerCLat,
    this.cornerCLng,
    this.cornerDLat,
    this.cornerDLng,
    this.isDefault = false,
  });

  bool get hasCalibration =>
      cornerALat != null &&
      cornerALng != null &&
      cornerBLat != null &&
      cornerBLng != null &&
      cornerCLat != null &&
      cornerCLng != null &&
      cornerDLat != null &&
      cornerDLng != null;

  factory TrackerFieldModel.fromJson(Map<String, dynamic> json) {
    return TrackerFieldModel(
      id: int.tryParse('${json['id'] ?? ''}'),
      clubId: int.tryParse('${json['club_id'] ?? json['clubId'] ?? ''}'),
      teamId: int.tryParse('${json['team_id'] ?? json['teamId'] ?? ''}'),
      title: '${json['title'] ?? json['name'] ?? 'Поле'}',
      lengthM: _d(json['length_m'], 105),
      widthM: _d(json['width_m'], 68),
      cornerALat: _dn(json['corner_a_lat']),
      cornerALng: _dn(json['corner_a_lng']),
      cornerBLat: _dn(json['corner_b_lat']),
      cornerBLng: _dn(json['corner_b_lng']),
      cornerCLat: _dn(json['corner_c_lat']),
      cornerCLng: _dn(json['corner_c_lng']),
      cornerDLat: _dn(json['corner_d_lat']),
      cornerDLng: _dn(json['corner_d_lng']),
      isDefault: '${json['is_default'] ?? 0}' == '1' || json['is_default'] == true,
    );
  }

  Map<String, dynamic> toJson({int? overrideClubId, int? overrideTeamId}) => {
        'id': id,
        'club_id': overrideClubId ?? clubId,
        'team_id': overrideTeamId ?? teamId,
        'title': title,
        'length_m': lengthM,
        'width_m': widthM,
        'corner_a_lat': cornerALat,
        'corner_a_lng': cornerALng,
        'corner_b_lat': cornerBLat,
        'corner_b_lng': cornerBLng,
        'corner_c_lat': cornerCLat,
        'corner_c_lng': cornerCLng,
        'corner_d_lat': cornerDLat,
        'corner_d_lng': cornerDLng,
        'is_default': isDefault ? 1 : 0,
      };

  static double _d(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  static double? _dn(dynamic value) {
    if (value == null) return null;
    final s = '$value'.trim();
    if (s.isEmpty) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(s);
  }
}
