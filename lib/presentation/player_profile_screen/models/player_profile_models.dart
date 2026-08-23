import 'package:flutter/material.dart';

enum PlayerProfileSection {
  overview,
  diary,
  readiness,
  activity,
  matches,
  analytics,
  testing,
  health,
  documents,
  card,
}

class PlayerProfilePoint {
  final double x;
  final double y;
  final double? value;
  const PlayerProfilePoint(this.x, this.y, {this.value});
}

class PlayerProfileSession {
  final int id;
  final DateTime? date;
  final String title;
  final double distanceM;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final int durationSec;
  final int sprintCount;
  final double hsrDistanceM;
  final double sprintDistanceM;
  final int accelCount;
  final int decelCount;
  final double loadScore;
  final double avgHr;
  final double maxHr;
  final double minHr;
  final List<PlayerProfilePoint> route;
  final List<PlayerProfilePoint> heatmap;
  final List<double> speedTimeline;
  final List<double> heartRateTimeline;
  final List<double> heartRateTimelineSec;
  final Map<String, dynamic> trackerReportJson;

  const PlayerProfileSession({
    required this.id,
    required this.date,
    required this.title,
    required this.distanceM,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.durationSec,
    required this.sprintCount,
    this.hsrDistanceM = 0,
    this.sprintDistanceM = 0,
    this.accelCount = 0,
    this.decelCount = 0,
    this.loadScore = 0,
    required this.avgHr,
    required this.maxHr,
    this.minHr = 0,
    this.route = const [],
    this.heatmap = const [],
    this.speedTimeline = const [],
    this.heartRateTimeline = const [],
    this.heartRateTimelineSec = const [],
    this.trackerReportJson = const <String, dynamic>{},
  });

  PlayerProfileSession copyWith({
    List<PlayerProfilePoint>? route,
    List<PlayerProfilePoint>? heatmap,
    List<double>? speedTimeline,
    List<double>? heartRateTimeline,
    List<double>? heartRateTimelineSec,
    double? avgHr,
    double? maxHr,
    double? minHr,
    Map<String, dynamic>? trackerReportJson,
  }) => PlayerProfileSession(
        id: id,
        date: date,
        title: title,
        distanceM: distanceM,
        maxSpeedKmh: maxSpeedKmh,
        avgSpeedKmh: avgSpeedKmh,
        durationSec: durationSec,
        sprintCount: sprintCount,
        hsrDistanceM: hsrDistanceM,
        sprintDistanceM: sprintDistanceM,
        accelCount: accelCount,
        decelCount: decelCount,
        loadScore: loadScore,
        avgHr: avgHr ?? this.avgHr,
        maxHr: maxHr ?? this.maxHr,
        minHr: minHr ?? this.minHr,
        route: route ?? this.route,
        heatmap: heatmap ?? this.heatmap,
        speedTimeline: speedTimeline ?? this.speedTimeline,
        heartRateTimeline: heartRateTimeline ?? this.heartRateTimeline,
        heartRateTimelineSec: heartRateTimelineSec ?? this.heartRateTimelineSec,
        trackerReportJson: trackerReportJson ?? this.trackerReportJson,
      );
}

class PlayerReadinessSummary {
  final double score;
  final double objectiveScore;
  final double subjectiveScore;
  final String label;
  final bool hasCheckin;
  final double acute7;
  final double chronicWeek;
  final double? ratio;
  final int sessions7;
  final int sessions28;
  final double sleepHours;
  final int fatigue;
  final int pain;
  final int rpe;
  final List<String> recommendations;
  final String referenceDate;

  const PlayerReadinessSummary({
    required this.score,
    required this.objectiveScore,
    required this.subjectiveScore,
    required this.label,
    required this.hasCheckin,
    required this.acute7,
    required this.chronicWeek,
    required this.ratio,
    required this.sessions7,
    required this.sessions28,
    required this.sleepHours,
    required this.fatigue,
    required this.pain,
    required this.rpe,
    required this.recommendations,
    required this.referenceDate,
  });
}

class PlayerTimelineItem {
  final DateTime? date;
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  const PlayerTimelineItem({required this.date, required this.type, required this.title, required this.subtitle, required this.icon});
}

class PlayerProfileSnapshot {
  final Map<String, dynamic> player;
  final List<Map<String, dynamic>> trainings;
  final List<Map<String, dynamic>> attendance;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> tests;
  final List<Map<String, dynamic>> coachRatings;
  final List<Map<String, dynamic>> selfAssessments;
  final List<Map<String, dynamic>> diaryEntries;
  final List<Map<String, dynamic>> weeklyGoals;
  final List<Map<String, dynamic>> mediaFeed;
  final List<Map<String, dynamic>> medical;
  final List<Map<String, dynamic>> documents;
  final Map<String, dynamic> schoolProfile;
  final Map<String, dynamic>? schoolProfileRecord;
  final List<PlayerProfileSession> sessions;
  final List<PlayerTimelineItem> timeline;
  final PlayerReadinessSummary? readiness;

  const PlayerProfileSnapshot({
    required this.player,
    this.trainings = const [],
    this.attendance = const [],
    this.matches = const [],
    this.tests = const [],
    this.coachRatings = const [],
    this.selfAssessments = const [],
    this.diaryEntries = const [],
    this.weeklyGoals = const [],
    this.mediaFeed = const [],
    this.medical = const [],
    this.documents = const [],
    this.schoolProfile = const <String, dynamic>{},
    this.schoolProfileRecord,
    this.sessions = const [],
    this.timeline = const [],
    this.readiness,
  });


  PlayerProfileSession? get trackerMaxHrSession {
    final rows = sessions.where((e) => e.maxHr > 0).toList();
    if (rows.isEmpty) return null;
    rows.sort((a, b) => b.maxHr.compareTo(a.maxHr));
    return rows.first;
  }

  PlayerProfileSession? get trackerRestHrSession {
    final rows = sessions.where((e) => e.minHr >= 30 && e.minHr <= 120).toList();
    if (rows.isEmpty) return null;
    rows.sort((a, b) => a.minHr.compareTo(b.minHr));
    return rows.first;
  }

  int get attendancePercent {
    if (attendance.isEmpty) return 0;
    final present = attendance.where((e) {
      final value = '${e['status'] ?? e['mark'] ?? ''}'.toLowerCase();
      return value == 'present' || value.contains('прис');
    }).length;
    return ((present / attendance.length) * 100).round();
  }

  double get coachRatingAverage {
    final rows = <Map<String, dynamic>>[
      ...coachRatings,
      ...diaryEntries.where((e) {
        final role = '${e['author_role'] ?? ''}'.trim().toLowerCase();
        return (role == 'coach' || role == 'manager') && _toDouble(e['rating']) > 0;
      }),
    ];
    return _averageRating(rows);
  }

  double get selfRatingAverage {
    final rows = <Map<String, dynamic>>[
      ...selfAssessments,
      ...diaryEntries.where((e) {
        final role = '${e['author_role'] ?? ''}'.trim().toLowerCase();
        return role == 'player' && _toDouble(e['rating']) > 0;
      }),
    ];
    return _averageRating(rows);
  }

  int get testingScorePercent {
    final values = <double>[];
    for (final test in tests) {
      final rating = '${test['rating'] ?? test['rating_code'] ?? ''}'.trim().toLowerCase();
      if (rating.isNotEmpty) {
        switch (rating) {
          case 'excellent':
            values.add(100);
            continue;
          case 'good':
            values.add(80);
            continue;
          case 'satisfactory':
            values.add(60);
            continue;
          case 'poor':
            values.add(40);
            continue;
        }
      }
      final points = _toDouble(test['points']);
      if (points > 0) values.add((points / 4 * 100).clamp(0, 100).toDouble());
    }
    if (values.isEmpty) return 0;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  int get compositeRating {
    final parts = <({double value, double weight})>[];
    if (coachRatingAverage > 0) {
      parts.add((value: coachRatingAverage * 20, weight: .35));
    }
    if (selfRatingAverage > 0) {
      parts.add((value: selfRatingAverage * 20, weight: .20));
    }
    if (attendance.isNotEmpty) {
      parts.add((value: attendancePercent.toDouble(), weight: .20));
    }
    if (testingScorePercent > 0) {
      parts.add((value: testingScorePercent.toDouble(), weight: .25));
    }
    if (parts.isEmpty) return 0;
    final totalWeight = parts.fold<double>(0, (sum, e) => sum + e.weight);
    final score = parts.fold<double>(0, (sum, e) => sum + e.value * e.weight) / totalWeight;
    return score.round().clamp(0, 100).toInt();
  }

  static double _averageRating(List<Map<String, dynamic>> rows) {
    final values = rows.map((e) => _toDouble(e['rating'])).where((e) => e > 0).toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0;
  }

  PlayerProfileSnapshot copyWith({List<PlayerProfileSession>? sessions, List<PlayerTimelineItem>? timeline, PlayerReadinessSummary? readiness}) => PlayerProfileSnapshot(
        player: player,
        trainings: trainings,
        attendance: attendance,
        matches: matches,
        tests: tests,
        coachRatings: coachRatings,
        selfAssessments: selfAssessments,
        diaryEntries: diaryEntries,
        weeklyGoals: weeklyGoals,
        mediaFeed: mediaFeed,
        medical: medical,
        documents: documents,
        schoolProfile: schoolProfile,
        schoolProfileRecord: schoolProfileRecord,
        sessions: sessions ?? this.sessions,
        timeline: timeline ?? this.timeline,
        readiness: readiness ?? this.readiness,
      );
}
