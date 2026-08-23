
String _firstNonEmpty(Map<String, dynamic> json, List<String> keys, [String fallback = '']) {
  for (final key in keys) {
    final value = '${json[key] ?? ''}'.trim();
    if (value.isNotEmpty && value != 'null') return value;
  }
  return fallback;
}

String _sessionGroupKeyAny(Map<String, dynamic> json, List<String> keys) {
  final value = _firstNonEmpty(json, keys).trim();
  if (value.isEmpty || value == '0' || value == '-' || value.toLowerCase() == 'null') return '';
  return value;
}

int? _intAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null || '$value'.trim().isEmpty || '$value' == 'null') continue;
    if (value is num) return value.toInt();
    final parsed = int.tryParse('$value') ?? double.tryParse('$value')?.toInt();
    if (parsed != null) return parsed;
  }
  return null;
}

String? _photoAny(Map<String, dynamic> json) {
  final raw = _firstNonEmpty(json, const ['photo', 'avatar', 'image', 'photo_url', 'avatar_url', 'user_photo', 'profile_photo', 'player_photo']);
  return raw.isEmpty ? null : raw;
}

class TrackerPlayerOption {
  final int id;
  final String name;
  final String? avatar;
  final String? number;
  final String? position;
  /// Все известные серверные идентификаторы игрока: players.id, player_id, user_id.
  /// Нужны для сопоставления личных сессий и Polar, где API может вернуть user_id
  /// вместо внутреннего players.id.
  final Set<int> identityIds;

  const TrackerPlayerOption({
    required this.id,
    required this.name,
    this.avatar,
    this.number,
    this.position,
    this.identityIds = const <int>{},
  });

  factory TrackerPlayerOption.fromJson(Map<String, dynamic> json) {
    final firstName = '${json['first_name'] ?? json['firstName'] ?? ''}'.trim();
    final lastName = '${json['last_name'] ?? json['lastName'] ?? ''}'.trim();
    final full = _firstNonEmpty(json, const ['player_name', 'name', 'full_name', 'fullName'], '$firstName $lastName').trim();

    final primaryId = _intAny(json, const ['id', 'player_id', 'playerId', 'user_id']) ?? 0;
    final identities = <int>{};
    for (final key in const ['id', 'player_id', 'playerId', 'user_id', 'userId', 'owner_user_id', 'ownerUserId']) {
      final parsed = _intAny(json, <String>[key]);
      if (parsed != null && parsed > 0) identities.add(parsed);
    }
    if (primaryId > 0) identities.add(primaryId);

    return TrackerPlayerOption(
      id: primaryId,
      name: full.isEmpty ? 'Игрок' : full,
      avatar: _photoAny(json),
      number: _firstNonEmpty(json, const ['jersey_number', 'number', 'shirt_number']).isEmpty ? null : _firstNonEmpty(json, const ['jersey_number', 'number', 'shirt_number']),
      position: '${json['position'] ?? ''}'.trim().isEmpty ? null : '${json['position']}',
      identityIds: identities,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'number': number,
        'position': position,
        'identity_ids': identityIds.toList(growable: false),
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
    final nearbyRaw =
        '${json['is_nearby'] ?? json['nearby'] ?? 0}' == '1' ||
        json['is_nearby'] == true;
    final nearbySeenAt = _trackerDeviceServerUtc(
      json['nearby_at'] ??
          json['last_seen_at'] ??
          json['updated_at'] ??
          json['created_at'],
    );
    final nearbyAgeSec = nearbySeenAt == null
        ? null
        : DateTime.now().toUtc().difference(nearbySeenAt).inSeconds;
    final nearbyFresh =
        nearbyAgeSec != null && nearbyAgeSec >= -15 && nearbyAgeSec <= 90;
    return TrackerDeviceModel(
      id: int.tryParse('${json['id'] ?? ''}'),
      clubId: int.tryParse('${json['club_id'] ?? json['clubId'] ?? ''}'),
      teamId: int.tryParse('${json['team_id'] ?? json['teamId'] ?? ''}'),
      playerId: int.tryParse('${json['player_id'] ?? json['playerId'] ?? ''}'),
      deviceUuid: '${json['device_uuid'] ?? json['device_id'] ?? json['uuid'] ?? ''}',
      deviceName: '${json['device_name'] ?? json['name'] ?? 'Трекер'}',
      batteryPercent: int.tryParse('${json['battery_percent'] ?? ''}'),
      // is_nearby в старой таблице не сбрасывался после scan и оставался 1
      // сутками. Показываем «рядом» только при свежей серверной отметке.
      isNearby: nearbyRaw && nearbyFresh,
      playerName: _firstNonEmpty(json, const ['player_name', 'full_name', 'fullName', 'name', 'fio']).isEmpty ? null : _firstNonEmpty(json, const ['player_name', 'full_name', 'fullName', 'name', 'fio']),
    );
  }
}

DateTime? _trackerDeviceServerUtc(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
  final normalized = raw.replaceFirst(' ', 'T');
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return null;
  final hasZone =
      RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
          .hasMatch(normalized);
  if (hasZone) return parsed.toUtc();
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
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
      preset: normalizePreset(json['preset']),
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
        'preset': normalizePreset(preset),
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


  static String normalizePreset(dynamic raw) {
    final value = '${raw ?? ''}'.trim().toLowerCase();
    if (value == 'u13' || value == 'academy' || value == 'дети') return 'u13';
    if (value == 'u17' || value == 'semi-pro' || value == 'semipro') return 'u17';
    if (value == 'pro' || value == 'elite' || value == 'профи') return 'pro';
    if (value == 'custom' || value == 'manual' || value == 'свой') return 'custom';
    if (value == 'youth' || value.isEmpty) return 'youth';
    // Безопасно режем любые длинные подписи, чтобы серверные старые колонки не падали.
    return value.replaceAll(RegExp(r'[^a-z0-9_\-]'), '_').substring(0, value.length > 24 ? 24 : value.length);
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
      playerId: _intAny(json, const ['player_id', 'playerId', 'id', 'user_id']),
      playerName: _firstNonEmpty(json, const ['player_name', 'full_name', 'fullName', 'name', 'fio'], 'Игрок'),
      avatar: _photo(json),
      sessionsCount: _intAny(json, const ['sessions_count', 'session_count', 'sessions']) ?? 0,
      distanceM: _d(json['distance_m'] ?? json['total_distance_m'] ?? json['distance']),
      avgSpeedKmh: _d(json['avg_speed_kmh'] ?? json['average_speed_kmh']),
      maxSpeedKmh: _d(json['max_speed_kmh'] ?? json['top_speed_kmh']),
      highSpeedDistanceM: _d(json['high_speed_distance_m'] ?? json['hsr_distance_m'] ?? json['hir_distance_m'] ?? json['vhir_distance_m']),
      sprintDistanceM: _d(json['sprint_distance_m'] ?? json['spr_distance_m']),
      sprintCount: _intAny(json, const ['sprint_count', 'sprints_count', 'sprints']) ?? 0,
      accelerationCount: _intAny(json, const ['acceleration_count', 'accel_count', 'accelerations']) ?? 0,
      decelerationCount: _intAny(json, const ['deceleration_count', 'decel_count', 'decelerations']) ?? 0,
      loadScore: _d(json['load_score'] ?? json['tracker_load'] ?? json['hr_load']),
    );
  }

  static String? _photo(Map<String, dynamic> json) {
    return _photoAny(json);
  }

  static double _d(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static bool _boolAny(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final raw = '${json[key] ?? ''}'.trim().toLowerCase();
      if (raw == '1' || raw == 'true' || raw == 'yes') return true;
    }
    return false;
  }

  static bool _sessionKindLooksPersonal(Map<String, dynamic> json) {
    final value = '${json['session_kind'] ?? json['source'] ?? json['activity_source'] ?? json['started_by_role'] ?? ''}'.trim().toLowerCase();
    return value.contains('personal') || value.contains('player_tracker') || value == 'player';
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
  final String source;
  final String title;
  final String createdAt;
  final String processingStatus;
  final double distanceM;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final double metersPerMinute;
  final double hsrDistanceM;
  final double hirDistanceM;
  final double vhirDistanceM;
  final double sprintDistanceM;
  final int sprintCount;
  final int accelCount;
  final int decelCount;
  final int durationSec;
  final double loadScore;
  final double loadPerMinute;
  final double fatigueIndex;
  final bool personalSession;
  final int heartRateSamplesCount;
  final int polarDurationSec;
  final int gpsDurationSec;
  final int participantsCount;
  final List<int> participantIds;
  final List<String> participantNames;
  /// Stable server-side identifier shared by all player rows of one team
  /// training. Older endpoints do not return it, so the analytics UI also has
  /// a conservative time-based fallback.
  final String sessionGroupKey;

  const TrackerSessionModel({
    required this.id,
    this.playerId,
    this.playerName,
    required this.deviceName,
    this.source = '',
    required this.title,
    required this.createdAt,
    required this.processingStatus,
    required this.distanceM,
    required this.maxSpeedKmh,
    this.avgSpeedKmh = 0,
    this.metersPerMinute = 0,
    this.hsrDistanceM = 0,
    this.hirDistanceM = 0,
    this.vhirDistanceM = 0,
    this.sprintDistanceM = 0,
    required this.sprintCount,
    this.accelCount = 0,
    this.decelCount = 0,
    this.durationSec = 0,
    required this.loadScore,
    this.loadPerMinute = 0,
    this.fatigueIndex = 0,
    this.personalSession = false,
    this.heartRateSamplesCount = 0,
    this.polarDurationSec = 0,
    this.gpsDurationSec = 0,
    this.participantsCount = 0,
    this.participantIds = const <int>[],
    this.participantNames = const <String>[],
    this.sessionGroupKey = '',
  });

  factory TrackerSessionModel.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['players'] ?? json['participants'] ?? json['session_players'] ?? json['members'];
    final participantIds = <int>{};
    final participantNames = <String>[];
    if (rawParticipants is List) {
      for (final value in rawParticipants) {
        if (value is Map) {
          final row = Map<String, dynamic>.from(value);
          final id = _intAny(row, const ['player_id', 'playerId', 'id', 'user_id', 'userId']);
          if (id != null && id > 0) participantIds.add(id);
          final name = _firstNonEmpty(row, const ['player_name', 'full_name', 'fullName', 'name', 'fio']);
          if (name.isNotEmpty && !participantNames.contains(name)) participantNames.add(name);
        } else {
          final id = int.tryParse('$value');
          if (id != null && id > 0) participantIds.add(id);
        }
      }
    }
    final directPlayerId = _intAny(json, const ['player_id', 'playerId', 'user_id']);
    if (directPlayerId != null && directPlayerId > 0) participantIds.add(directPlayerId);
    final directPlayerName = _firstNonEmpty(json, const ['player_name', 'full_name', 'fullName', 'name', 'fio']);
    if (directPlayerName.isNotEmpty && !participantNames.contains(directPlayerName)) participantNames.add(directPlayerName);
    final participantsCount = _intAny(json, const [
          'players_count',
          'player_count',
          'participants_count',
          'participantsCount',
          'members_count',
          'athletes_count',
        ]) ??
        participantIds.length;
    return TrackerSessionModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      playerId: _intAny(json, const ['player_id', 'playerId', 'user_id']),
      playerName: _firstNonEmpty(json, const ['player_name', 'full_name', 'fullName', 'name', 'fio']).isEmpty ? null : _firstNonEmpty(json, const ['player_name', 'full_name', 'fullName', 'name', 'fio']),
      deviceName: '${json['device_name'] ?? 'Трекер'}',
      source: '${json['source'] ?? json['session_source'] ?? json['device_source'] ?? ''}',
      title: '${json['title'] ?? 'Сессия'}',
      createdAt: '${json['created_at'] ?? ''}',
      processingStatus: '${json['processing_status'] ?? 'new'}',
      distanceM: _d(json['distance_m'] ?? json['total_distance_m'] ?? json['distance']),
      maxSpeedKmh: _d(json['max_speed_kmh'] ?? json['top_speed_kmh']),
      avgSpeedKmh: _d(json['avg_speed_kmh']),
      metersPerMinute: _d(json['meterage_per_min'] ?? json['meters_per_minute']),
      hsrDistanceM: _d(json['hsr_distance_m'] ?? json['high_speed_distance_m']),
      hirDistanceM: _d(json['hir_distance_m']),
      vhirDistanceM: _d(json['vhir_distance_m']),
      sprintDistanceM: _d(json['sprint_distance_m']),
      sprintCount: _intAny(json, const ['sprint_count', 'sprints_count', 'sprints']) ?? 0,
      accelCount: int.tryParse('${json['accel_count'] ?? json['acceleration_count'] ?? 0}') ?? 0,
      decelCount: int.tryParse('${json['decel_count'] ?? json['deceleration_count'] ?? 0}') ?? 0,
      durationSec: int.tryParse('${json['duration_sec'] ?? 0}') ?? 0,
      loadScore: _d(json['load_score'] ?? json['tracker_load'] ?? json['hr_load']),
      loadPerMinute: _d(json['load_per_min']),
      fatigueIndex: _d(json['fatigue_index']),
      personalSession: _boolAny(json, const ['personal_session', 'is_personal']) || _sessionKindLooksPersonal(json),
      heartRateSamplesCount: int.tryParse('${json['heart_rate_samples_count'] ?? json['hr_samples_count'] ?? 0}') ?? 0,
      polarDurationSec: _intAny(json, const [
            'polar_duration_sec',
            'heart_rate_duration_sec',
            'hr_duration_sec',
            'polar_work_sec',
          ]) ??
          0,
      gpsDurationSec: _intAny(json, const [
            'gps_duration_sec',
            'tracker_duration_sec',
            'gps_work_sec',
            'device_duration_sec',
          ]) ??
          0,
      participantsCount: participantsCount,
      participantIds: participantIds.toList(growable: false),
      participantNames: participantNames,
      sessionGroupKey: _sessionGroupKeyAny(json, const [
        'team_session_id',
        'teamSessionId',
        'session_group_id',
        'sessionGroupId',
        'group_session_id',
        'groupSessionId',
        'team_training_id',
        'teamTrainingId',
        'team_live_group_id',
        'teamLiveGroupId',
        'session_batch_id',
        'sessionBatchId',
        'training_id',
        'trainingId',
        'workout_id',
        'workoutId',
        'batch_id',
        'batchId',
        'live_batch_id',
        'liveBatchId',
        'parent_session_id',
        'parentSessionId',
      ]),
    );
  }

  static double _d(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static bool _boolAny(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final raw = '${json[key] ?? ''}'.trim().toLowerCase();
      if (raw == '1' || raw == 'true' || raw == 'yes') return true;
    }
    return false;
  }

  static bool _sessionKindLooksPersonal(Map<String, dynamic> json) {
    final value = '${json['session_kind'] ?? json['source'] ?? json['activity_source'] ?? json['started_by_role'] ?? ''}'.trim().toLowerCase();
    return value.contains('personal') || value.contains('player_tracker') || value == 'player';
  }
}

class TrackerHeatPoint {
  final double x;
  final double y;
  final double value;

  const TrackerHeatPoint({required this.x, required this.y, required this.value});

  factory TrackerHeatPoint.fromJson(Map<String, dynamic> json) {
    // Серверы разных версий возвращали координаты как x/y, field_x/field_y,
    // x_m/y_m или local_x/local_y. Не даём всем точкам падать в 0:0.
    return TrackerHeatPoint(
      x: _d(json['x'] ?? json['field_x'] ?? json['field_x_m'] ?? json['x_m'] ?? json['local_x'] ?? json['local_x_m'] ?? json['pos_x']),
      y: _d(json['y'] ?? json['field_y'] ?? json['field_y_m'] ?? json['y_m'] ?? json['local_y'] ?? json['local_y_m'] ?? json['pos_y']),
      value: _d(json['value'] ?? json['intensity'] ?? json['weight'] ?? json['count'], 1),
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
