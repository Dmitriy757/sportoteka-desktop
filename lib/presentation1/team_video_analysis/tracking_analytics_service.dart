import 'package:sportoteka/presentation/team_video_analysis/tracking_models.dart';

class TrackingAnalyticsService {
  static TrackingStats compute(List<TrackPoint> pts) {
    if (pts.isEmpty || pts.length < 2) {
      return const TrackingStats.empty();
    }

    double totalDistance = 0;
    double maxSpeed = 0;
    double totalSpeed = 0;

    for (int i = 1; i < pts.length; i++) {
      totalDistance += (pts[i].position - pts[i - 1].position).distance;
    }

    for (final p in pts) {
      totalSpeed += p.speed;
      if (p.speed > maxSpeed) {
        maxSpeed = p.speed;
      }
    }

    final durationMs = pts.last.timeMs - pts.first.timeMs;
    final averageSpeed = pts.isEmpty ? 0.0 : totalSpeed / pts.length;

    return TrackingStats(
      totalDistance: totalDistance.toDouble(),
      averageSpeed: averageSpeed.toDouble(),
      maxSpeed: maxSpeed.toDouble(),
      durationMs: durationMs,
    );
  }
}