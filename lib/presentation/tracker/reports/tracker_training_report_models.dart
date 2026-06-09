class TrackerTrainingReport {
  final int sessionId;
  final String title;
  final String dateLabel;
  final String teamName;
  final String opponent;
  final String durationLabel;
  final int playersCount;
  final TrackerReportSummary summary;
  final List<TrackerExercisePeriod> periods;
  final List<TrackerMicrocyclePoint> microcycle;
  final List<TrackerTrainingPlayerRow> players;

  const TrackerTrainingReport({
    required this.sessionId,
    required this.title,
    required this.dateLabel,
    required this.teamName,
    required this.opponent,
    required this.durationLabel,
    required this.playersCount,
    required this.summary,
    required this.periods,
    required this.microcycle,
    required this.players,
  });

  factory TrackerTrainingReport.fromJson(Map<String, dynamic> json) {
    return TrackerTrainingReport(
      sessionId: _i(json['session_id'] ?? json['id']),
      title: '${json['title'] ?? 'Отчёт по тренировке'}',
      dateLabel: '${json['date_label'] ?? json['date'] ?? ''}',
      teamName: '${json['team_name'] ?? ''}',
      opponent: '${json['opponent'] ?? ''}',
      durationLabel: '${json['duration_label'] ?? '00:00:00'}',
      playersCount: _i(json['players_count']),
      summary: TrackerReportSummary.fromJson(Map<String, dynamic>.from(json['summary'] as Map? ?? const {})),
      periods: (json['periods'] as List? ?? const [])
          .map((e) => TrackerExercisePeriod.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      microcycle: (json['microcycle'] as List? ?? const [])
          .map((e) => TrackerMicrocyclePoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      players: (json['players'] as List? ?? const [])
          .map((e) => TrackerTrainingPlayerRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  factory TrackerTrainingReport.empty({required int sessionId, required String teamName}) {
    return TrackerTrainingReport(
      sessionId: sessionId,
      title: 'Отчёт по тренировке',
      dateLabel: '',
      teamName: teamName,
      opponent: '',
      durationLabel: '00:00:00',
      playersCount: 0,
      summary: const TrackerReportSummary(),
      periods: const [],
      microcycle: const [],
      players: const [],
    );
  }
}

class TrackerReportSummary {
  final double averageDistanceM;
  final double highSpeedDistanceM;
  final double playerLoad;
  final double accDecPerMin;
  final double maxSpeedKmh;
  final double distancePerMin;
  final int accelerationCount;
  final int decelerationCount;
  final int explosiveActions;

  const TrackerReportSummary({
    this.averageDistanceM = 0,
    this.highSpeedDistanceM = 0,
    this.playerLoad = 0,
    this.accDecPerMin = 0,
    this.maxSpeedKmh = 0,
    this.distancePerMin = 0,
    this.accelerationCount = 0,
    this.decelerationCount = 0,
    this.explosiveActions = 0,
  });

  factory TrackerReportSummary.fromJson(Map<String, dynamic> json) {
    return TrackerReportSummary(
      averageDistanceM: _d(json['average_distance_m'] ?? json['avg_distance_m']),
      highSpeedDistanceM: _d(json['high_speed_distance_m'] ?? json['hsr_m']),
      playerLoad: _d(json['player_load'] ?? json['load_score']),
      accDecPerMin: _d(json['acc_dec_per_min']),
      maxSpeedKmh: _d(json['max_speed_kmh']),
      distancePerMin: _d(json['distance_per_min_m']),
      accelerationCount: _i(json['acceleration_count']),
      decelerationCount: _i(json['deceleration_count']),
      explosiveActions: _i(json['explosive_actions']),
    );
  }
}

class TrackerExercisePeriod {
  final String title;
  final String startLabel;
  final String endLabel;
  final int durationSec;

  const TrackerExercisePeriod({
    required this.title,
    required this.startLabel,
    required this.endLabel,
    required this.durationSec,
  });

  factory TrackerExercisePeriod.fromJson(Map<String, dynamic> json) {
    return TrackerExercisePeriod(
      title: '${json['title'] ?? json['name'] ?? 'Период'}',
      startLabel: '${json['start_label'] ?? json['start_time'] ?? ''}',
      endLabel: '${json['end_label'] ?? json['end_time'] ?? ''}',
      durationSec: _i(json['duration_sec']),
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
      distanceM: _d(json['distance_m']),
      highSpeedRunningM: _d(json['high_speed_running_m'] ?? json['hsr_m']),
      accDec: _d(json['acc_dec'] ?? json['accdec']),
    );
  }
}

class TrackerTrainingPlayerRow {
  final int? playerId;
  final String name;
  final String duration;
  final double distanceM;
  final double metersPerMin;
  final double maxSpeedKmh;
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

  const TrackerTrainingPlayerRow({
    this.playerId,
    required this.name,
    required this.duration,
    required this.distanceM,
    required this.metersPerMin,
    required this.maxSpeedKmh,
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
  });

  factory TrackerTrainingPlayerRow.fromJson(Map<String, dynamic> json) {
    return TrackerTrainingPlayerRow(
      playerId: int.tryParse('${json['player_id'] ?? ''}'),
      name: '${json['name'] ?? json['player_name'] ?? 'Игрок'}',
      duration: '${json['duration'] ?? json['duration_label'] ?? '00:00:00'}',
      distanceM: _d(json['distance_m']),
      metersPerMin: _d(json['meters_per_min'] ?? json['distance_per_min_m']),
      maxSpeedKmh: _d(json['max_speed_kmh']),
      accelerations: _i(json['accelerations'] ?? json['acceleration_count']),
      decelerations: _i(json['decelerations'] ?? json['deceleration_count']),
      accDecPerMin: _d(json['acc_dec_per_min']),
      explosiveActions: _i(json['explosive_actions']),
      v3RunM: _d(json['v3_run_m']),
      v4HsrM: _d(json['v4_hsr_m'] ?? json['v4_vsb_m']),
      v5SprintM: _d(json['v5_sprint_m'] ?? json['sprint_distance_m']),
      sprintCount: _i(json['sprint_count']),
      highSpeedWorkM: _d(json['high_speed_work_m'] ?? json['high_speed_distance_m']),
      highSpeedActions: _i(json['high_speed_actions']),
      playerLoad: _d(json['player_load'] ?? json['load_score']),
      heartRateMaxPercent: _d(json['heart_rate_max_percent']),
      hrExertion: _d(json['hr_exertion']),
    );
  }
}

double _d(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

int _i(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}
