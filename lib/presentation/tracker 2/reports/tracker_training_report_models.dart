
import '../models/tracker_pro_models.dart';

class TrackerTrainingReport {
  final TrackerTrainingReportSummary summary;
  final List<TrackerTrainingPlayerRow> players;
  final List<TrackerMicrocyclePoint> microcycle;
  final List<TrackerReportChartBar> mdComparison;
  final List<TrackerReportChartBar> accelerations;
  final List<TrackerReportChartBar> decelerations;
  final List<TrackerReportChartBar> explosiveActions;
  final List<TrackerReportStackedBar> heartRateZones;
  final List<TrackerReportStackedBar> heartRateDistanceZones;

  const TrackerTrainingReport({
    required this.summary,
    required this.players,
    required this.microcycle,
    required this.mdComparison,
    required this.accelerations,
    required this.decelerations,
    required this.explosiveActions,
    required this.heartRateZones,
    required this.heartRateDistanceZones,
  });

  factory TrackerTrainingReport.fromJson(Map<String, dynamic> json, {TrackerSessionModel? fallbackSession}) {
    final rows = (json['players'] as List? ?? json['rows'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => TrackerTrainingPlayerRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return TrackerTrainingReport(
      summary: TrackerTrainingReportSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
        fallbackSession: fallbackSession,
        playersCount: rows.length,
      ),
      players: rows,
      microcycle: _list(json['microcycle']).map(TrackerMicrocyclePoint.fromJson).toList(),
      mdComparison: _list(json['md_comparison'] ?? json['mdComparison']).map(TrackerReportChartBar.fromJson).toList(),
      accelerations: _list(json['accelerations']).map(TrackerReportChartBar.fromJson).toList(),
      decelerations: _list(json['decelerations']).map(TrackerReportChartBar.fromJson).toList(),
      explosiveActions: _list(json['explosive_actions'] ?? json['explosiveActions']).map(TrackerReportChartBar.fromJson).toList(),
      heartRateZones: _list(json['heart_rate_zones'] ?? json['heartRateZones']).map(TrackerReportStackedBar.fromJson).toList(),
      heartRateDistanceZones: _list(json['heart_rate_distance_zones'] ?? json['heartRateDistanceZones']).map(TrackerReportStackedBar.fromJson).toList(),
    );
  }

  factory TrackerTrainingReport.fallback({
    required TrackerSessionModel session,
    required List<TrackerPlayerOption> rosterPlayers,
  }) {
    final players = rosterPlayers.isEmpty
        ? <TrackerTrainingPlayerRow>[
            TrackerTrainingPlayerRow(
              number: session.playerName == null ? '1' : '',
              name: session.playerName ?? 'Игрок',
              duration: '00:00:00',
              distanceM: session.distanceM,
              metersPerMin: 0,
              maxSpeedKmh: session.maxSpeedKmh,
              accelerations: 0,
              decelerations: 0,
              accDecPerMin: 0,
              explosiveActions: 0,
              runV3M: 0,
              hsrV4M: 0,
              sprintV5M: 0,
              sprintCount: session.sprintCount,
              highSpeedWorkM: 0,
              highSpeedActions: 0,
            ),
          ]
        : rosterPlayers.map((p) {
            final selected = session.playerId == null || p.id == session.playerId;
            return TrackerTrainingPlayerRow(
              number: p.number ?? '',
              name: p.name,
              duration: '00:00:00',
              distanceM: selected ? session.distanceM : 0,
              metersPerMin: 0,
              maxSpeedKmh: selected ? session.maxSpeedKmh : 0,
              accelerations: 0,
              decelerations: 0,
              accDecPerMin: 0,
              explosiveActions: 0,
              runV3M: 0,
              hsrV4M: 0,
              sprintV5M: 0,
              sprintCount: selected ? session.sprintCount : 0,
              highSpeedWorkM: 0,
              highSpeedActions: 0,
            );
          }).toList();

    return TrackerTrainingReport(
      summary: TrackerTrainingReportSummary(
        title: session.title,
        date: session.createdAt,
        trainingTime: '00:00:00',
        averageDistanceM: players.isEmpty ? 0 : players.map((e) => e.distanceM).reduce((a,b)=>a+b) / players.length,
        playersCount: players.length,
        highSpeedDistanceM: players.map((e) => e.highSpeedWorkM).fold<double>(0, (a,b)=>a+b),
        playerLoad: session.loadScore,
        accDec: players.map((e) => e.accelerations + e.decelerations).fold<int>(0, (a,b)=>a+b).toDouble(),
      ),
      players: players,
      microcycle: const [
        TrackerMicrocyclePoint(label: 'Тр-4', distanceM: 0, hsrM: 0, accDec: 0),
        TrackerMicrocyclePoint(label: 'Тр-3', distanceM: 0, hsrM: 0, accDec: 0),
        TrackerMicrocyclePoint(label: 'Тр-2', distanceM: 0, hsrM: 0, accDec: 0),
        TrackerMicrocyclePoint(label: 'Текущая', distanceM: 0, hsrM: 0, accDec: 0),
      ],
      mdComparison: [
        TrackerReportChartBar(label: 'Дистанция', value: session.distanceM > 0 ? 47 : 0),
        const TrackerReportChartBar(label: 'Метры/мин', value: 0),
        TrackerReportChartBar(label: 'Макс. скорость', value: session.maxSpeedKmh > 0 ? 71 : 0),
        const TrackerReportChartBar(label: 'Ускорения', value: 0),
        const TrackerReportChartBar(label: 'Торможения', value: 0),
        TrackerReportChartBar(label: 'Спринты', value: session.sprintCount > 0 ? 2 : 0),
      ],
      accelerations: players.map((e) => TrackerReportChartBar(label: e.shortName, value: e.accelerations.toDouble())).toList(),
      decelerations: players.map((e) => TrackerReportChartBar(label: e.shortName, value: e.decelerations.toDouble())).toList(),
      explosiveActions: players.map((e) => TrackerReportChartBar(label: e.shortName, value: e.explosiveActions.toDouble())).toList(),
      heartRateZones: players.map((e) => TrackerReportStackedBar(label: e.shortName, low: 0, mid: 0, high: 0)).toList(),
      heartRateDistanceZones: players.map((e) => TrackerReportStackedBar(label: e.shortName, low: 0, mid: 0, high: 0)).toList(),
    );
  }

  static List<Map<String, dynamic>> _list(dynamic value) {
    return (value as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class TrackerTrainingReportSummary {
  final String title;
  final String date;
  final String trainingTime;
  final double averageDistanceM;
  final int playersCount;
  final double highSpeedDistanceM;
  final double playerLoad;
  final double accDec;

  const TrackerTrainingReportSummary({
    required this.title,
    required this.date,
    required this.trainingTime,
    required this.averageDistanceM,
    required this.playersCount,
    required this.highSpeedDistanceM,
    required this.playerLoad,
    required this.accDec,
  });

  factory TrackerTrainingReportSummary.fromJson(
    Map<String, dynamic> json, {
    TrackerSessionModel? fallbackSession,
    int playersCount = 0,
  }) {
    return TrackerTrainingReportSummary(
      title: '${json['title'] ?? fallbackSession?.title ?? 'Тренировка'}',
      date: '${json['date'] ?? json['created_at'] ?? fallbackSession?.createdAt ?? ''}',
      trainingTime: '${json['training_time'] ?? json['trainingTime'] ?? '00:00:00'}',
      averageDistanceM: _d(json['average_distance_m'] ?? json['averageDistanceM'] ?? fallbackSession?.distanceM),
      playersCount: int.tryParse('${json['players_count'] ?? json['playersCount'] ?? playersCount}') ?? playersCount,
      highSpeedDistanceM: _d(json['high_speed_distance_m'] ?? json['highSpeedDistanceM']),
      playerLoad: _d(json['player_load'] ?? json['playerLoad'] ?? fallbackSession?.loadScore),
      accDec: _d(json['acc_dec'] ?? json['accDec']),
    );
  }
}

class TrackerTrainingPlayerRow {
  final String number;
  final String name;
  final String duration;
  final double distanceM;
  final double metersPerMin;
  final double maxSpeedKmh;
  final int accelerations;
  final int decelerations;
  final double accDecPerMin;
  final int explosiveActions;
  final double runV3M;
  final double hsrV4M;
  final double sprintV5M;
  final int sprintCount;
  final double highSpeedWorkM;
  final int highSpeedActions;

  const TrackerTrainingPlayerRow({
    required this.number,
    required this.name,
    required this.duration,
    required this.distanceM,
    required this.metersPerMin,
    required this.maxSpeedKmh,
    required this.accelerations,
    required this.decelerations,
    required this.accDecPerMin,
    required this.explosiveActions,
    required this.runV3M,
    required this.hsrV4M,
    required this.sprintV5M,
    required this.sprintCount,
    required this.highSpeedWorkM,
    required this.highSpeedActions,
  });

  String get shortName {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'Игрок';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last.substring(0, 1)}.';
  }

  factory TrackerTrainingPlayerRow.fromJson(Map<String, dynamic> json) {
    return TrackerTrainingPlayerRow(
      number: '${json['number'] ?? json['jersey_number'] ?? json['jerseyNumber'] ?? ''}',
      name: '${json['name'] ?? json['player_name'] ?? json['playerName'] ?? 'Игрок'}',
      duration: '${json['duration'] ?? json['time'] ?? '00:00:00'}',
      distanceM: _d(json['distance_m'] ?? json['distanceM'] ?? json['distance']),
      metersPerMin: _d(json['meters_per_min'] ?? json['metersPerMin']),
      maxSpeedKmh: _d(json['max_speed_kmh'] ?? json['maxSpeedKmh']),
      accelerations: _i(json['accelerations']),
      decelerations: _i(json['decelerations']),
      accDecPerMin: _d(json['acc_dec_per_min'] ?? json['accDecPerMin']),
      explosiveActions: _i(json['explosive_actions'] ?? json['explosiveActions']),
      runV3M: _d(json['run_v3_m'] ?? json['runV3M']),
      hsrV4M: _d(json['hsr_v4_m'] ?? json['hsrV4M']),
      sprintV5M: _d(json['sprint_v5_m'] ?? json['sprintV5M']),
      sprintCount: _i(json['sprint_count'] ?? json['sprintCount']),
      highSpeedWorkM: _d(json['high_speed_work_m'] ?? json['highSpeedWorkM']),
      highSpeedActions: _i(json['high_speed_actions'] ?? json['highSpeedActions']),
    );
  }
}

class TrackerMicrocyclePoint {
  final String label;
  final double distanceM;
  final double hsrM;
  final double accDec;

  const TrackerMicrocyclePoint({
    required this.label,
    required this.distanceM,
    required this.hsrM,
    required this.accDec,
  });

  factory TrackerMicrocyclePoint.fromJson(Map<String, dynamic> json) => TrackerMicrocyclePoint(
        label: '${json['label'] ?? json['date'] ?? ''}',
        distanceM: _d(json['distance_m'] ?? json['distanceM']),
        hsrM: _d(json['hsr_m'] ?? json['hsrM']),
        accDec: _d(json['acc_dec'] ?? json['accDec']),
      );
}

class TrackerReportChartBar {
  final String label;
  final double value;

  const TrackerReportChartBar({required this.label, required this.value});

  factory TrackerReportChartBar.fromJson(Map<String, dynamic> json) => TrackerReportChartBar(
        label: '${json['label'] ?? json['name'] ?? ''}',
        value: _d(json['value']),
      );
}

class TrackerReportStackedBar {
  final String label;
  final double low;
  final double mid;
  final double high;

  const TrackerReportStackedBar({
    required this.label,
    required this.low,
    required this.mid,
    required this.high,
  });

  factory TrackerReportStackedBar.fromJson(Map<String, dynamic> json) => TrackerReportStackedBar(
        label: '${json['label'] ?? json['name'] ?? ''}',
        low: _d(json['low']),
        mid: _d(json['mid']),
        high: _d(json['high']),
      );
}

double _d(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

int _i(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value') ?? 0;
}
