import 'package:flutter/material.dart';

enum PlayerProfileSection { overview, activity, matches, analytics, testing, health, card }

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
  final List<Map<String, dynamic>> medical;
  final List<PlayerProfileSession> sessions;
  final List<PlayerTimelineItem> timeline;

  const PlayerProfileSnapshot({
    required this.player,
    this.trainings = const [],
    this.attendance = const [],
    this.matches = const [],
    this.tests = const [],
    this.medical = const [],
    this.sessions = const [],
    this.timeline = const [],
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

  PlayerProfileSnapshot copyWith({List<PlayerProfileSession>? sessions, List<PlayerTimelineItem>? timeline}) => PlayerProfileSnapshot(
        player: player,
        trainings: trainings,
        attendance: attendance,
        matches: matches,
        tests: tests,
        medical: medical,
        sessions: sessions ?? this.sessions,
        timeline: timeline ?? this.timeline,
      );
}
