

DateTime? _trackerParseServerInstant(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty || raw == 'null') return null;
  final normalized = raw.replaceFirst(' ', 'T');
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
      .hasMatch(normalized);
  if (hasZone) return DateTime.tryParse(normalized)?.toUtc();

  final naive = DateTime.tryParse(normalized);
  if (naive == null) return null;
  // Серверные MySQL-строки без timezone считаем UTC.
  return DateTime.utc(
    naive.year,
    naive.month,
    naive.day,
    naive.hour,
    naive.minute,
    naive.second,
    naive.millisecond,
    naive.microsecond,
  );
}

DateTime? _trackerMoscowDateTime(dynamic value) {
  final instant = _trackerParseServerInstant(value);
  if (instant == null) return null;
  final moscow = instant.add(const Duration(hours: 3));
  // Возвращаем wall-clock Moscow без зависимости от timezone устройства.
  return DateTime(
    moscow.year,
    moscow.month,
    moscow.day,
    moscow.hour,
    moscow.minute,
    moscow.second,
    moscow.millisecond,
    moscow.microsecond,
  );
}

DateTime _trackerMoscowFromEpochMs(int millisecondsSinceEpoch) {
  final moscow = DateTime.fromMillisecondsSinceEpoch(
    millisecondsSinceEpoch,
    isUtc: true,
  ).add(const Duration(hours: 3));
  return DateTime(
    moscow.year,
    moscow.month,
    moscow.day,
    moscow.hour,
    moscow.minute,
    moscow.second,
    moscow.millisecond,
    moscow.microsecond,
  );
}

class TrackerTrainingReport {
  final int sessionId;
  final List<int> sessionIds;
  final String title;
  final String dateLabel;
  final int teamId;
  final String teamName;
  final String teamLogoUrl;
  final String opponent;
  final String durationLabel;
  final int playersCount;
  final int pointsCount;
  final bool hasData;
  final String dataStatus;
  final TrackerReportSummary summary;
  final List<TrackerExercisePeriod> periods;
  final List<TrackerMicrocyclePoint> microcycle;
  final List<TrackerTrainingPlayerRow> players;
  final List<TrackerTrainingPlayerRow> diagnosticPlayers;
  final List<TrackerReportPoint> routePoints;
  final List<TrackerReportPoint> heatmapPoints;
  final List<TrackerSpeedZone> speedZones;
  final List<TrackerHeartRatePoint> heartRateTimeline;

  const TrackerTrainingReport({
    required this.sessionId,
    this.sessionIds = const [],
    required this.title,
    required this.dateLabel,
    this.teamId = 0,
    required this.teamName,
    this.teamLogoUrl = '',
    required this.opponent,
    required this.durationLabel,
    required this.playersCount,
    this.pointsCount = 0,
    this.hasData = false,
    this.dataStatus = '',
    required this.summary,
    required this.periods,
    required this.microcycle,
    required this.players,
    this.diagnosticPlayers = const [],
    this.routePoints = const [],
    this.heatmapPoints = const [],
    this.speedZones = const [],
    this.heartRateTimeline = const [],
  });

  factory TrackerTrainingReport.fromJson(Map<String, dynamic> json) {
    final playerRows = _playerRowList(json['players'] ?? json['player_summaries'] ?? json['locomotor_players'] ?? _nested(json, 'locomotor', 'players') ?? _nested(json, 'heart_rate', 'players') ?? _nested(json, 'internal', 'players'));
    final diagnosticRows = _playerRowList(json['diagnostic_players'] ?? json['diagnostics'] ?? json['raw_players']);
    final playerSource = playerRows.isNotEmpty ? playerRows : diagnosticRows;
    final routePoints = _combinedReportPointList(json, heat: false);
    final heatmapPoints = _combinedReportPointList(json, heat: true);
    final speedZones = _speedZoneList(_firstPresent([
      json['speed_zones'],
      json['zones'],
      _nested(json, 'speed', 'zones'),
      _nested(json, 'locomotor', 'speed_zones'),
      _nested(json, 'locomotor', 'zones'),
      _nested(json, 'summary', 'speed_zones'),
    ]));
    final heartRateTimeline = _combinedHrPointList(json);
    final summary = _summaryWithFallbacks(
      TrackerReportSummary.fromJson(Map<String, dynamic>.from((json['summary'] ?? json['totals'] ?? json['team_summary'] ?? json) as Map? ?? const {})),
      playerSource,
      routePoints,
      heartRateTimeline,
    );
    final periods = _periodList(json['periods'] ?? json['exercises'] ?? json['drills'] ?? _nested(json, 'training', 'periods'));
    final microcycle = _microcycleList(json['microcycle'] ?? json['microcycle_points'] ?? _nested(json, 'microcycle', 'items'));
    final playersCount = _i(json['players_count'], playerSource.length);
    final pointsCount = _i(json['points_count'] ?? json['gps_points_count'], routePoints.length);
    final hasData = _b(json['has_data']) ||
        routePoints.isNotEmpty ||
        heartRateTimeline.isNotEmpty ||
        playerSource.any((p) => p.distanceM > 0 || p.maxSpeedKmh > 0 || p.pointsCount > 0 || p.heartRateSamplesCount > 0);
    return TrackerTrainingReport(
      sessionId: _i(json['session_id'] ?? json['id']),
      sessionIds: (json['session_ids'] as List? ?? const []).map((e) => _i(e)).where((e) => e > 0).toList(),
      title: '${json['title'] ?? 'Отчёт по тренировке'}',
      dateLabel: '${json['date_label'] ?? json['date'] ?? json['started_at'] ?? ''}',
      teamId: _i(json['team_id']),
      teamName: '${json['team_name'] ?? json['team'] ?? ''}',
      teamLogoUrl: _s(_firstPresent([
        json['team_logo_url'],
        json['team_logo'],
        json['club_logo_url'],
        json['club_logo'],
        json['logo_url'],
        _nested(json, 'team', 'logo_url'),
        _nested(json, 'team', 'logo'),
        _nested(json, 'club', 'logo_url'),
        _nested(json, 'club', 'logo'),
      ])),
      opponent: '${json['opponent'] ?? ''}',
      durationLabel: '${json['duration_label'] ?? json['duration'] ?? '00:00:00'}',
      playersCount: playersCount,
      pointsCount: pointsCount,
      hasData: hasData,
      dataStatus: _s(json['data_status']),
      summary: summary,
      periods: periods,
      microcycle: microcycle,
      players: playerRows,
      diagnosticPlayers: diagnosticRows,
      routePoints: routePoints,
      heatmapPoints: heatmapPoints,
      speedZones: speedZones,
      heartRateTimeline: heartRateTimeline,
    );
  }

  factory TrackerTrainingReport.empty({required int sessionId, required String teamName}) {
    return TrackerTrainingReport(
      sessionId: sessionId,
      sessionIds: sessionId > 0 ? [sessionId] : const [],
      title: 'Отчёт по тренировке',
      dateLabel: '',
      teamName: teamName,
      opponent: '',
      durationLabel: '00:00:00',
      playersCount: 0,
      pointsCount: 0,
      hasData: false,
      summary: const TrackerReportSummary(),
      periods: const [],
      microcycle: const [],
      players: const [],
      diagnosticPlayers: const [],
      routePoints: const [],
      heatmapPoints: const [],
      speedZones: const [],
      heartRateTimeline: const [],
    );
  }
}

class TrackerReportSummary {
  final double averageDistanceM;
  final double totalDistanceM;
  final double highSpeedDistanceM;
  final double playerLoad;
  final double accDecPerMin;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final double distancePerMin;
  final int accelerationCount;
  final int decelerationCount;
  final int explosiveActions;
  final int sprintCount;
  final double sprintDistanceM;
  final double v3RunM;
  final double v4HsrM;
  final double v5SprintM;
  final double heartRateAvgBpm;
  final double heartRateMaxBpm;
  final int heartRateSamplesCount;

  const TrackerReportSummary({
    this.averageDistanceM = 0,
    this.totalDistanceM = 0,
    this.highSpeedDistanceM = 0,
    this.playerLoad = 0,
    this.accDecPerMin = 0,
    this.maxSpeedKmh = 0,
    this.avgSpeedKmh = 0,
    this.distancePerMin = 0,
    this.accelerationCount = 0,
    this.decelerationCount = 0,
    this.explosiveActions = 0,
    this.sprintCount = 0,
    this.sprintDistanceM = 0,
    this.v3RunM = 0,
    this.v4HsrM = 0,
    this.v5SprintM = 0,
    this.heartRateAvgBpm = 0,
    this.heartRateMaxBpm = 0,
    this.heartRateSamplesCount = 0,
  });

  factory TrackerReportSummary.fromJson(Map<String, dynamic> json) {
    final hrRaw = json['heart_rate'] ?? json['hr'] ?? json['polar'] ?? json['heart_rate_summary'];
    final hr = hrRaw is Map ? Map<String, dynamic>.from(hrRaw) : const <String, dynamic>{};

    return TrackerReportSummary(
      averageDistanceM: _d(json['average_distance_m'] ?? json['avg_distance_m']),
      totalDistanceM: _d(json['total_distance_m'] ?? json['distance_m']),
      highSpeedDistanceM: _d(json['high_speed_distance_m'] ?? json['hsr_m']),
      playerLoad: _d(json['player_load'] ?? json['load_score']),
      accDecPerMin: _d(json['acc_dec_per_min']),
      maxSpeedKmh: _speedFromJson(json['max_speed_kmh'] ?? json['max_speed'] ?? json['top_speed'], json['max_speed_mps']),
      avgSpeedKmh: _speedFromJson(json['avg_speed_kmh'] ?? json['average_speed_kmh'] ?? json['avg_speed'], json['avg_speed_mps']),
      distancePerMin: _d(json['distance_per_min_m'] ?? json['meters_per_min']),
      accelerationCount: _i(json['acceleration_count'] ?? json['accelerations']),
      decelerationCount: _i(json['deceleration_count'] ?? json['decelerations']),
      explosiveActions: _i(json['explosive_actions']),
      sprintCount: _i(json['sprint_count']),
      sprintDistanceM: _d(json['sprint_distance_m']),
      v3RunM: _d(json['v3_run_m']),
      v4HsrM: _d(json['v4_hsr_m'] ?? json['v4_vsb_m']),
      v5SprintM: _d(json['v5_sprint_m'] ?? json['sprint_distance_m']),
      heartRateAvgBpm: _d(json['heart_rate_avg_bpm'] ?? json['avg_bpm'] ?? hr['avg_bpm'] ?? hr['avg'] ?? hr['average_bpm']),
      heartRateMaxBpm: _d(json['heart_rate_max_bpm'] ?? json['max_bpm'] ?? hr['max_bpm'] ?? hr['max']),
      heartRateSamplesCount: _i(json['heart_rate_samples_count'] ?? json['samples_count'] ?? hr['samples_count'] ?? hr['samples']),
    );
  }
}

class TrackerExercisePeriod {
  final String title;
  final String startLabel;
  final String endLabel;
  final int durationSec;
  final double distanceM;
  final double highSpeedDistanceM;
  final int accDecCount;

  const TrackerExercisePeriod({
    required this.title,
    required this.startLabel,
    required this.endLabel,
    required this.durationSec,
    this.distanceM = 0,
    this.highSpeedDistanceM = 0,
    this.accDecCount = 0,
  });

  factory TrackerExercisePeriod.fromJson(Map<String, dynamic> json) {
    return TrackerExercisePeriod(
      title: '${json['title'] ?? json['name'] ?? 'Период'}',
      startLabel: '${json['start_label'] ?? json['start_time'] ?? ''}',
      endLabel: '${json['end_label'] ?? json['end_time'] ?? ''}',
      durationSec: _i(json['duration_sec']),
      distanceM: _d(json['distance_m'] ?? json['total_distance_m'] ?? json['distance'] ?? json['distanceMeters']),
      highSpeedDistanceM: _d(json['high_speed_distance_m']),
      accDecCount: _i(json['acc_dec_count']),
    );
  }
}

class TrackerMicrocyclePoint {
  final String label;
  final double distanceM;
  final double highSpeedRunningM;
  final double accDec;

  const TrackerMicrocyclePoint({
    required this.label,
    required this.distanceM,
    required this.highSpeedRunningM,
    required this.accDec,
  });

  factory TrackerMicrocyclePoint.fromJson(Map<String, dynamic> json) {
    return TrackerMicrocyclePoint(
      label: '${json['label'] ?? json['date'] ?? ''}',
      distanceM: _d(json['distance_m'] ?? json['total_distance_m'] ?? json['distance'] ?? json['distanceMeters']),
      highSpeedRunningM: _d(json['high_speed_running_m'] ?? json['hsr_m']),
      accDec: _d(json['acc_dec'] ?? json['accdec']),
    );
  }
}

class TrackerTrainingPlayerRow {
  final int? playerId;
  final String name;
  final String avatarUrl;
  final String number;
  final String position;
  final String deviceName;
  final String trackerUid;
  final String duration;
  final double distanceM;
  final double metersPerMin;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final int accelerations;
  final int decelerations;
  final double accDecPerMin;
  final int explosiveActions;
  final double v3RunM;
  final double v4HsrM;
  final double v5SprintM;
  final int sprintCount;
  final double highSpeedWorkM;
  final int highSpeedActions;
  final double playerLoad;
  final double heartRateMaxPercent;
  final double hrExertion;
  final double heartRateAvgBpm;
  final double heartRateMaxBpm;
  final double heartRateMinBpm;
  final int heartRateSamplesCount;
  final int hrZ1Samples;
  final int hrZ2Samples;
  final int hrZ3Samples;
  final int hrZ4Samples;
  final int hrZ5Samples;
  final int pointsCount;
  final int sessionsCount;
  final bool hasMovement;

  const TrackerTrainingPlayerRow({
    this.playerId,
    required this.name,
    this.avatarUrl = '',
    this.number = '',
    this.position = '',
    this.deviceName = '',
    this.trackerUid = '',
    required this.duration,
    required this.distanceM,
    required this.metersPerMin,
    required this.maxSpeedKmh,
    this.avgSpeedKmh = 0,
    required this.accelerations,
    required this.decelerations,
    required this.accDecPerMin,
    required this.explosiveActions,
    required this.v3RunM,
    required this.v4HsrM,
    required this.v5SprintM,
    required this.sprintCount,
    required this.highSpeedWorkM,
    required this.highSpeedActions,
    required this.playerLoad,
    required this.heartRateMaxPercent,
    required this.hrExertion,
    this.heartRateAvgBpm = 0,
    this.heartRateMaxBpm = 0,
    this.heartRateMinBpm = 0,
    this.heartRateSamplesCount = 0,
    this.hrZ1Samples = 0,
    this.hrZ2Samples = 0,
    this.hrZ3Samples = 0,
    this.hrZ4Samples = 0,
    this.hrZ5Samples = 0,
    this.pointsCount = 0,
    this.sessionsCount = 0,
    this.hasMovement = false,
  });

  TrackerTrainingPlayerRow copyWith({
    String? name,
    String? avatarUrl,
    String? number,
    String? position,
  }) {
    return TrackerTrainingPlayerRow(
      playerId: playerId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      number: number ?? this.number,
      position: position ?? this.position,
      deviceName: deviceName,
      trackerUid: trackerUid,
      duration: duration,
      distanceM: distanceM,
      metersPerMin: metersPerMin,
      maxSpeedKmh: maxSpeedKmh,
      avgSpeedKmh: avgSpeedKmh,
      accelerations: accelerations,
      decelerations: decelerations,
      accDecPerMin: accDecPerMin,
      explosiveActions: explosiveActions,
      v3RunM: v3RunM,
      v4HsrM: v4HsrM,
      v5SprintM: v5SprintM,
      sprintCount: sprintCount,
      highSpeedWorkM: highSpeedWorkM,
      highSpeedActions: highSpeedActions,
      playerLoad: playerLoad,
      heartRateMaxPercent: heartRateMaxPercent,
      hrExertion: hrExertion,
      heartRateAvgBpm: heartRateAvgBpm,
      heartRateMaxBpm: heartRateMaxBpm,
      heartRateMinBpm: heartRateMinBpm,
      heartRateSamplesCount: heartRateSamplesCount,
      hrZ1Samples: hrZ1Samples,
      hrZ2Samples: hrZ2Samples,
      hrZ3Samples: hrZ3Samples,
      hrZ4Samples: hrZ4Samples,
      hrZ5Samples: hrZ5Samples,
      pointsCount: pointsCount,
      sessionsCount: sessionsCount,
      hasMovement: hasMovement,
    );
  }

  factory TrackerTrainingPlayerRow.fromJson(Map<String, dynamic> json) {
    final hrRaw = json['heart_rate'] ?? json['hr'] ?? json['polar'];
    final hr = hrRaw is Map ? Map<String, dynamic>.from(hrRaw) : const <String, dynamic>{};
    final zonesRaw = json['hr_zones'] ?? json['zones'] ?? hr['zones'];
    final zones = zonesRaw is Map ? Map<String, dynamic>.from(zonesRaw) : const <String, dynamic>{};
    return TrackerTrainingPlayerRow(
      playerId: int.tryParse('${json['player_id'] ?? json['playerId'] ?? json['id'] ?? ''}'),
      name: _playerDisplayName(json),
      avatarUrl: _s(json['avatar_url'] ?? json['avatar'] ?? json['photo'] ?? json['photo_url'] ?? json['image'] ?? json['image_url']),
      number: _s(json['number'] ?? json['shirt_number'] ?? json['game_number']),
      position: _s(json['position'] ?? json['position_name'] ?? json['role'] ?? json['amplua']),
      deviceName: _s(json['device_name'] ?? json['tracker_name']),
      trackerUid: _s(json['tracker_uid'] ?? json['device_uid'] ?? json['device_mac']),
      duration: '${json['duration'] ?? json['duration_label'] ?? json['moving_time'] ?? '00:00:00'}',
      distanceM: _d(json['distance_m'] ?? json['total_distance_m'] ?? json['distance'] ?? json['distanceMeters']),
      metersPerMin: _d(json['meters_per_min'] ?? json['distance_per_min_m'] ?? json['m_per_min']),
      maxSpeedKmh: _speedFromJson(json['max_speed_kmh'] ?? json['max_speed'] ?? json['top_speed'], json['max_speed_mps']),
      avgSpeedKmh: _speedFromJson(json['avg_speed_kmh'] ?? json['average_speed_kmh'] ?? json['avg_speed'], json['avg_speed_mps']),
      accelerations: _i(json['accelerations'] ?? json['acceleration_count'] ?? json['accel_count'] ?? json['acc_count']),
      decelerations: _i(json['decelerations'] ?? json['deceleration_count'] ?? json['decel_count'] ?? json['dec_count']),
      accDecPerMin: _d(json['acc_dec_per_min']),
      explosiveActions: _i(json['explosive_actions']),
      v3RunM: _d(json['v3_run_m']),
      v4HsrM: _d(json['v4_hsr_m'] ?? json['v4_vsb_m']),
      v5SprintM: _d(json['v5_sprint_m'] ?? json['sprint_distance_m']),
      sprintCount: _i(json['sprint_count']),
      highSpeedWorkM: _d(json['high_speed_work_m'] ?? json['high_speed_distance_m']),
      highSpeedActions: _i(json['high_speed_actions'] ?? json['turn_count'] ?? json['cod_count']),
      playerLoad: _d(json['player_load'] ?? json['load_score']),
      heartRateMaxPercent: _d(json['heart_rate_max_percent'] ?? json['hr_max_percent'] ?? hr['max_percent']),
      hrExertion: _d(json['hr_exertion'] ?? json['heart_rate_load'] ?? hr['exertion'] ?? hr['load']),
      heartRateAvgBpm: _d(json['heart_rate_avg_bpm'] ?? json['avg_bpm'] ?? hr['avg_bpm'] ?? hr['avg'] ?? hr['average_bpm']),
      heartRateMaxBpm: _d(json['heart_rate_max_bpm'] ?? json['max_bpm'] ?? hr['max_bpm'] ?? hr['max']),
      heartRateMinBpm: _d(json['heart_rate_min_bpm'] ?? json['min_bpm'] ?? hr['min_bpm'] ?? hr['min']),
      heartRateSamplesCount: _i(json['heart_rate_samples_count'] ?? json['samples_count'] ?? hr['samples_count'] ?? hr['samples']),
      hrZ1Samples: _i(json['hr_z1_samples'] ?? json['z1'] ?? zones['z1']),
      hrZ2Samples: _i(json['hr_z2_samples'] ?? json['z2'] ?? zones['z2']),
      hrZ3Samples: _i(json['hr_z3_samples'] ?? json['z3'] ?? zones['z3']),
      hrZ4Samples: _i(json['hr_z4_samples'] ?? json['z4'] ?? zones['z4']),
      hrZ5Samples: _i(json['hr_z5_samples'] ?? json['z5'] ?? zones['z5']),
      pointsCount: _i(json['points_count'] ?? json['gps_points_count'] ?? json['samples_count']),
      sessionsCount: _i(json['sessions_count']),
      hasMovement: _b(json['has_movement']),
    );
  }
}

class TrackerReportPoint {
  final int? playerId;
  final String playerName;
  final double x;
  final double y;
  final double speedKmh;
  final double value;
  final double distanceM;
  final int timeMs;
  final bool breakBefore;

  const TrackerReportPoint({
    this.playerId,
    this.playerName = '',
    required this.x,
    required this.y,
    this.speedKmh = 0,
    this.value = 1,
    this.distanceM = 0,
    this.timeMs = 0,
    this.breakBefore = false,
  });

  factory TrackerReportPoint.fromJson(Map<String, dynamic> json) {
    return TrackerReportPoint(
      playerId: int.tryParse('${json['player_id'] ?? json['playerId'] ?? json['id'] ?? ''}'),
      playerName: _s(json['player_name'] ?? json['name'] ?? json['player']),
      x: _pointCoord(json, isY: false),
      y: _pointCoord(json, isY: true),
      speedKmh: _speedFromJson(json['speed_kmh'] ?? json['speed_kph'] ?? json['speed'], json['speed_mps']),
      value: _d(json['value'] ?? json['intensity'] ?? json['count'], 1),
      distanceM: _d(json['distance_m'] ?? json['total_distance_m']),
      timeMs: _pointTimeMs(json),
      breakBefore: _b(json['break_before']),
    );
  }
}

class TrackerSpeedZone {
  final String label;
  final double fromKmh;
  final double toKmh;
  final double distanceM;
  final int pointsCount;

  const TrackerSpeedZone({
    required this.label,
    required this.fromKmh,
    required this.toKmh,
    required this.distanceM,
    required this.pointsCount,
  });

  factory TrackerSpeedZone.fromJson(Map<String, dynamic> json) {
    return TrackerSpeedZone(
      label: _s(json['label'] ?? json['name']),
      fromKmh: _d(json['from_kmh'] ?? json['min_kmh'] ?? json['from']),
      toKmh: _d(json['to_kmh'] ?? json['max_kmh'] ?? json['to']),
      distanceM: _d(json['distance_m'] ?? json['total_distance_m'] ?? json['distance'] ?? json['distanceMeters']),
      pointsCount: _i(json['points_count']),
    );
  }
}

class TrackerHeartRatePoint {
  final int? playerId;
  final String playerName;
  final int timeMs;
  final int minute;
  final int bpm;
  final double hrLoad;
  final String zone;
  final double speedKmh;

  const TrackerHeartRatePoint({
    this.playerId,
    this.playerName = '',
    required this.timeMs,
    required this.minute,
    required this.bpm,
    this.hrLoad = 0,
    this.zone = '',
    this.speedKmh = 0,
  });

  factory TrackerHeartRatePoint.fromJson(Map<String, dynamic> json) {
    final measured = _s(json['measured_at'] ?? json['created_at'] ?? json['time']);
    final parsed = measured.isEmpty ? null : _trackerMoscowDateTime(measured);
    final rawTimeMs = _i(json['time_ms'] ?? json['timestamp_ms'] ?? json['ts_ms']);
    final timeMs = rawTimeMs > 0 ? rawTimeMs : (parsed == null ? 0 : parsed.millisecondsSinceEpoch);
    final minute = _i(json['minute'] ?? json['minute_index'] ?? json['t_min']);
    final bpm = _i(json['bpm'] ?? json['heart_rate'] ?? json['hr']);
    return TrackerHeartRatePoint(
      playerId: int.tryParse('${json['player_id'] ?? json['playerId'] ?? json['id'] ?? ''}'),
      playerName: _s(json['player_name'] ?? json['name'] ?? json['player']),
      timeMs: timeMs,
      minute: minute,
      bpm: bpm,
      hrLoad: _d(json['hr_load'] ?? json['load'] ?? json['hr_exertion']),
      zone: _s(json['hr_zone'] ?? json['zone']).toLowerCase(),
      speedKmh: _speedFromJson(json['speed_kmh'] ?? json['speed_kph'] ?? json['speed'], json['speed_mps']),
    );
  }
}


dynamic _nested(Map<String, dynamic> json, String parent, String child) {
  final raw = json[parent];
  if (raw is Map) return raw[child];
  return null;
}

dynamic _firstPresent(List<dynamic> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value is List && value.isEmpty) continue;
    if (value is Map && value.isEmpty) continue;
    return value;
  }
  return null;
}

List<dynamic> _asList(dynamic raw) {
  var value = raw;
  if (value is Map) value = value['items'] ?? value['players'] ?? value['rows'] ?? value['points'] ?? value['timeline'] ?? value['periods'] ?? value['exercises'] ?? value['zones'] ?? value['heatmap'] ?? value['data'] ?? const [];
  if (value is List) return value;
  return const <dynamic>[];
}

Map<String, dynamic> _withPlayerIdentity(Map<String, dynamic> point, {int? playerId, String playerName = '', bool breakBefore = false}) {
  final out = Map<String, dynamic>.from(point);
  if (playerId != null && playerId > 0 && out['player_id'] == null && out['playerId'] == null) out['player_id'] = playerId;
  if (playerName.trim().isNotEmpty && out['player_name'] == null && out['name'] == null && out['player'] == null) out['player_name'] = playerName;
  if (breakBefore && out['break_before'] == null) out['break_before'] = true;
  return out;
}

String _playerDisplayName(Map<String, dynamic> json) {
  final direct = _s(json['player_name'] ?? json['full_name'] ?? json['fullName'] ?? json['fio'] ?? json['display_name'] ?? json['name']);
  if (direct.isNotEmpty) return direct;
  final composed = [_s(json['last_name'] ?? json['lastName'] ?? json['surname']), _s(json['first_name'] ?? json['firstName']), _s(json['middle_name'] ?? json['middleName'] ?? json['patronymic'])].where((p) => p.isNotEmpty).join(' ');
  return composed.isNotEmpty ? composed : 'Игрок';
}

List<Map<String, dynamic>> _rawPlayerMaps(Map<String, dynamic> json) {
  final out = <Map<String, dynamic>>[];
  void add(dynamic raw) {
    for (final item in _asList(raw)) {
      if (item is Map) out.add(Map<String, dynamic>.from(item));
    }
  }
  add(json['players']);
  add(json['player_summaries']);
  add(json['locomotor_players']);
  add(_nested(json, 'locomotor', 'players'));
  add(_nested(json, 'heart_rate', 'players'));
  add(_nested(json, 'internal', 'players'));
  return out;
}

List<TrackerExercisePeriod> _periodList(dynamic raw) {
  return _asList(raw).whereType<Map>().map((e) => TrackerExercisePeriod.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
}

List<TrackerMicrocyclePoint> _microcycleList(dynamic raw) {
  return _asList(raw).whereType<Map>().map((e) => TrackerMicrocyclePoint.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
}

List<TrackerReportPoint> _combinedReportPointList(Map<String, dynamic> json, {required bool heat}) {
  final out = <TrackerReportPoint>[];
  final seen = <String>{};
  void addPoint(Map<String, dynamic> map, {int? playerId, String playerName = '', bool breakBefore = false}) {
    final point = TrackerReportPoint.fromJson(_withPlayerIdentity(map, playerId: playerId, playerName: playerName, breakBefore: breakBefore));
    final key = '${point.playerId ?? 0}|${point.playerName}|${point.timeMs}|${point.x.toStringAsFixed(5)}|${point.y.toStringAsFixed(5)}|${point.speedKmh.toStringAsFixed(2)}|${point.value.toStringAsFixed(2)}';
    if (seen.add(key)) out.add(point);
  }
  void addRaw(dynamic raw, {int? playerId, String playerName = ''}) {
    var first = true;
    for (final item in _asList(raw)) {
      if (item is Map) {
        addPoint(Map<String, dynamic>.from(item), playerId: playerId, playerName: playerName, breakBefore: first);
        first = false;
      }
    }
  }

  if (heat) {
    addRaw(json['heatmap_points']);
    addRaw(json['heatmap']);
    addRaw(json['heat_points']);
    addRaw(_nested(json, 'maps', 'heatmap_points'));
    addRaw(_nested(json, 'maps', 'heatmap'));
    addRaw(_nested(json, 'heatmap', 'points'));
    addRaw(_nested(json, 'activity_map', 'heatmap'));
  } else {
    addRaw(json['route_points']);
    addRaw(json['gps_points']);
    addRaw(json['points']);
    addRaw(json['track_points']);
    addRaw(_nested(json, 'maps', 'route_points'));
    addRaw(_nested(json, 'maps', 'points'));
    addRaw(_nested(json, 'activity_map', 'points'));
    addRaw(_nested(json, 'route', 'points'));
    addRaw(_nested(json, 'timeline', 'points'));
  }

  for (final player in _rawPlayerMaps(json)) {
    final playerId = int.tryParse('${player['player_id'] ?? player['playerId'] ?? player['id'] ?? ''}');
    final playerName = _playerDisplayName(player);
    if (heat) {
      addRaw(player['heatmap_points'] ?? player['heatmap'] ?? player['heat_points'], playerId: playerId, playerName: playerName);
    } else {
      addRaw(player['route_points'] ?? player['gps_points'] ?? player['points'] ?? player['track_points'] ?? player['timeline'], playerId: playerId, playerName: playerName);
    }
  }
  return _normalizeReportPointBreaks(out);
}

List<TrackerReportPoint> _normalizeReportPointBreaks(List<TrackerReportPoint> points) {
  if (points.length < 2) return points;
  final groups = <String, List<TrackerReportPoint>>{};
  for (final p in points) {
    final name = p.playerName.trim().toLowerCase();
    final key = p.playerId != null && p.playerId! > 0 ? 'id:${p.playerId}' : (name.isNotEmpty ? 'name:$name' : 'team');
    groups.putIfAbsent(key, () => <TrackerReportPoint>[]).add(p);
  }
  final result = <TrackerReportPoint>[];
  for (final group in groups.values) {
    if (group.any((p) => p.timeMs > 0)) {
      group.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    }
    for (var i = 0; i < group.length; i++) {
      final p = group[i];
      result.add(TrackerReportPoint(
        playerId: p.playerId,
        playerName: p.playerName,
        x: p.x,
        y: p.y,
        speedKmh: p.speedKmh,
        value: p.value,
        distanceM: p.distanceM,
        timeMs: p.timeMs,
        breakBefore: i == 0 || p.breakBefore,
      ));
    }
  }
  return result;
}

List<TrackerHeartRatePoint> _combinedHrPointList(Map<String, dynamic> json) {
  final out = <TrackerHeartRatePoint>[];
  final seen = <String>{};
  void addPoint(Map<String, dynamic> map, {int? playerId, String playerName = ''}) {
    final point = TrackerHeartRatePoint.fromJson(_withPlayerIdentity(map, playerId: playerId, playerName: playerName));
    if (point.bpm <= 0) return;
    final key = '${point.playerId ?? 0}|${point.playerName}|${point.timeMs}|${point.minute}|${point.bpm}';
    if (seen.add(key)) out.add(point);
  }
  void addRaw(dynamic raw, {int? playerId, String playerName = ''}) {
    for (final item in _asList(raw)) {
      if (item is Map) addPoint(Map<String, dynamic>.from(item), playerId: playerId, playerName: playerName);
    }
  }
  addRaw(json['heart_rate_timeline']);
  addRaw(json['hr_timeline']);
  addRaw(json['heartRateTimeline']);
  addRaw(_nested(json, 'heart_rate', 'timeline'));
  addRaw(_nested(json, 'hr', 'timeline'));
  addRaw(_nested(json, 'polar', 'timeline'));
  addRaw(_nested(json, 'internal', 'timeline'));
  for (final player in _rawPlayerMaps(json)) {
    final playerId = int.tryParse('${player['player_id'] ?? player['playerId'] ?? player['id'] ?? ''}');
    final playerName = _playerDisplayName(player);
    addRaw(player['heart_rate_timeline'] ?? player['hr_timeline'] ?? player['hr_points'] ?? player['polar_timeline'], playerId: playerId, playerName: playerName);
  }
  out.sort((a, b) {
    final ka = a.timeMs > 0 ? a.timeMs : a.minute * 60000;
    final kb = b.timeMs > 0 ? b.timeMs : b.minute * 60000;
    return ka.compareTo(kb);
  });
  return out;
}

TrackerReportSummary _summaryWithFallbacks(TrackerReportSummary summary, List<TrackerTrainingPlayerRow> players, List<TrackerReportPoint> routePoints, List<TrackerHeartRatePoint> hr) {
  final movingPlayers = players.where((p) => p.distanceM > 0 || p.maxSpeedKmh > 0 || p.pointsCount > 0 || p.heartRateSamplesCount > 0).toList(growable: false);
  final src = movingPlayers.isEmpty ? players : movingPlayers;
  double sum(double Function(TrackerTrainingPlayerRow p) pick) => src.fold<double>(0, (a, p) => a + pick(p));
  double avg(double Function(TrackerTrainingPlayerRow p) pick) => src.isEmpty ? 0 : sum(pick) / src.length;
  int isum(int Function(TrackerTrainingPlayerRow p) pick) => src.fold<int>(0, (a, p) => a + pick(p));
  final hrPlayers = src.where((p) => p.heartRateSamplesCount > 0 || p.heartRateAvgBpm > 0).toList(growable: false);
  final hrWeight = hrPlayers.fold<int>(0, (a, p) => a + (p.heartRateSamplesCount > 0 ? p.heartRateSamplesCount : 1));
  final routeMaxSpeed = routePoints.fold<double>(0, (m, p) => p.speedKmh > m ? p.speedKmh : m);
  final routeAvgSpeed = routePoints.where((p) => p.speedKmh > 0).fold<double>(0, (a, p) => a + p.speedKmh);
  final routeSpeedCount = routePoints.where((p) => p.speedKmh > 0).length;
  final avgHrFromTimeline = hr.isEmpty ? 0.0 : hr.fold<double>(0, (a, p) => a + p.bpm) / hr.length;
  final maxHrFromTimeline = hr.fold<double>(0, (m, p) => p.bpm > m ? p.bpm.toDouble() : m);
  return TrackerReportSummary(
    averageDistanceM: summary.averageDistanceM > 0 ? summary.averageDistanceM : avg((p) => p.distanceM),
    totalDistanceM: summary.totalDistanceM > 0 ? summary.totalDistanceM : sum((p) => p.distanceM),
    highSpeedDistanceM: summary.highSpeedDistanceM > 0 ? summary.highSpeedDistanceM : sum((p) => p.highSpeedWorkM > 0 ? p.highSpeedWorkM : p.v4HsrM + p.v5SprintM),
    playerLoad: summary.playerLoad > 0 ? summary.playerLoad : sum((p) => p.playerLoad),
    accDecPerMin: summary.accDecPerMin > 0 ? summary.accDecPerMin : avg((p) => p.accDecPerMin),
    maxSpeedKmh: summary.maxSpeedKmh > 0 ? summary.maxSpeedKmh : (routeMaxSpeed > 0 ? routeMaxSpeed : src.fold<double>(0, (m, p) => p.maxSpeedKmh > m ? p.maxSpeedKmh : m)),
    avgSpeedKmh: summary.avgSpeedKmh > 0 ? summary.avgSpeedKmh : (avg((p) => p.avgSpeedKmh) > 0 ? avg((p) => p.avgSpeedKmh) : (routeSpeedCount > 0 ? routeAvgSpeed / routeSpeedCount : 0)),
    distancePerMin: summary.distancePerMin > 0 ? summary.distancePerMin : avg((p) => p.metersPerMin),
    accelerationCount: summary.accelerationCount > 0 ? summary.accelerationCount : isum((p) => p.accelerations),
    decelerationCount: summary.decelerationCount > 0 ? summary.decelerationCount : isum((p) => p.decelerations),
    explosiveActions: summary.explosiveActions > 0 ? summary.explosiveActions : isum((p) => p.explosiveActions),
    sprintCount: summary.sprintCount > 0 ? summary.sprintCount : isum((p) => p.sprintCount),
    sprintDistanceM: summary.sprintDistanceM > 0 ? summary.sprintDistanceM : sum((p) => p.v5SprintM),
    v3RunM: summary.v3RunM > 0 ? summary.v3RunM : sum((p) => p.v3RunM),
    v4HsrM: summary.v4HsrM > 0 ? summary.v4HsrM : sum((p) => p.v4HsrM),
    v5SprintM: summary.v5SprintM > 0 ? summary.v5SprintM : sum((p) => p.v5SprintM),
    heartRateAvgBpm: summary.heartRateAvgBpm > 0 ? summary.heartRateAvgBpm : (avgHrFromTimeline > 0 ? avgHrFromTimeline : (hrWeight <= 0 ? 0 : hrPlayers.fold<double>(0, (a, p) => a + p.heartRateAvgBpm * (p.heartRateSamplesCount > 0 ? p.heartRateSamplesCount : 1)) / hrWeight)),
    heartRateMaxBpm: summary.heartRateMaxBpm > 0 ? summary.heartRateMaxBpm : (maxHrFromTimeline > 0 ? maxHrFromTimeline : hrPlayers.fold<double>(0, (m, p) => p.heartRateMaxBpm > m ? p.heartRateMaxBpm : m)),
    heartRateSamplesCount: summary.heartRateSamplesCount > 0 ? summary.heartRateSamplesCount : (hr.isNotEmpty ? hr.length : hrPlayers.fold<int>(0, (a, p) => a + p.heartRateSamplesCount)),
  );
}

List<TrackerTrainingPlayerRow> _playerRowList(dynamic raw) {
  if (raw is Map) raw = raw['items'] ?? raw['players'] ?? raw['rows'] ?? const [];
  if (raw is! List) return const <TrackerTrainingPlayerRow>[];
  return raw.whereType<Map>().map((e) => TrackerTrainingPlayerRow.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
}

List<TrackerReportPoint> _reportPointList(dynamic raw) {
  if (raw is Map) raw = raw['items'] ?? raw['points'] ?? raw['timeline'] ?? const [];
  if (raw is! List) return const <TrackerReportPoint>[];
  return raw.whereType<Map>().map((e) => TrackerReportPoint.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
}

List<TrackerSpeedZone> _speedZoneList(dynamic raw) {
  if (raw is Map) raw = raw['items'] ?? raw['zones'] ?? const [];
  if (raw is! List) return const <TrackerSpeedZone>[];
  return raw.whereType<Map>().map((e) => TrackerSpeedZone.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
}

List<TrackerHeartRatePoint> _hrPointList(dynamic raw) {
  dynamic list = raw;
  if (list is Map) list = list['items'] ?? list['points'] ?? list['timeline'] ?? const [];
  if (list is! List) return const <TrackerHeartRatePoint>[];
  final out = <TrackerHeartRatePoint>[];
  for (final e in list) {
    if (e is Map) {
      final point = TrackerHeartRatePoint.fromJson(Map<String, dynamic>.from(e));
      if (point.bpm > 0) out.add(point);
    }
  }
  out.sort((a, b) {
    final ta = a.timeMs > 0 ? a.timeMs : a.minute;
    final tb = b.timeMs > 0 ? b.timeMs : b.minute;
    return ta.compareTo(tb);
  });
  return out;
}


double _pointCoord(Map<String, dynamic> json, {required bool isY}) {
  // Отчётный API теперь отдаёт x/y уже нормализованными (0..1).
  // Но старые серверные файлы могли отдавать x/y в метрах, из-за этого все точки
  // схлопывались в угол после clamp(0..1). Поэтому нормализованными считаем
  // только значения около диапазона 0..1; большие значения трактуем как метры поля.
  final normalized = json[isY ? 'ny' : 'nx'] ?? json[isY ? 'field_y_norm' : 'field_x_norm'] ?? json[isY ? 'y_norm' : 'x_norm'] ?? json[isY ? 'field_y_pct' : 'field_x_pct'];
  if (normalized != null) return _d(normalized).clamp(0.0, 1.0).toDouble();

  final direct = json[isY ? 'y' : 'x'] ?? json[isY ? 'field_y_percent' : 'field_x_percent'];
  if (direct != null) {
    final v = _d(direct);
    if (v >= -0.05 && v <= 1.05) return v.clamp(0.0, 1.0).toDouble();
    final denom = isY ? 68.0 : 105.0;
    return (v / denom).clamp(0.0, 1.0).toDouble();
  }

  final meters = json[isY ? 'field_y_m' : 'field_x_m'] ?? json[isY ? 'field_y' : 'field_x'] ?? json[isY ? 'local_y' : 'local_x'] ?? json[isY ? 'pos_y' : 'pos_x'];
  final v = _d(meters);
  if (v.abs() <= 1.25) return v.clamp(0.0, 1.0).toDouble();
  final denom = isY ? 68.0 : 105.0;
  return (v / denom).clamp(0.0, 1.0).toDouble();
}


double _speedFromJson(dynamic kmhValue, dynamic mpsValue) {
  final kmh = _d(kmhValue);
  if (kmh > 0) return kmh;
  final mps = _d(mpsValue);
  return mps > 0 ? mps * 3.6 : 0;
}

int _pointTimeMs(Map<String, dynamic> json) {
  final direct = _i(json['time_ms'] ?? json['timestamp_ms'] ?? json['ts_ms']);
  if (direct > 0) return direct;
  final seconds = _d(json['time_s'] ?? json['timestamp_s'] ?? json['seconds'] ?? json['t']);
  if (seconds > 0) return (seconds * 1000).round();
  final measured = _s(json['measured_at'] ?? json['created_at'] ?? json['time'] ?? json['timestamp']);
  final parsed = measured.isEmpty ? null : _trackerMoscowDateTime(measured);
  return parsed == null ? 0 : parsed.millisecondsSinceEpoch;
}

String _s(dynamic value) => value == null ? '' : '$value'.trim();

bool _b(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = '$value'.toLowerCase().trim();
  return s == 'true' || s == '1' || s == 'yes' || s == 'ok';
}

double _d(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.')) ?? fallback;
}

int _i(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}
