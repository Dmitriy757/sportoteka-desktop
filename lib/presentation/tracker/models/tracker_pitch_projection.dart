import 'dart:math' as math;

import 'tracker_pro_models.dart';

class TrackerPitchProjection {
  const TrackerPitchProjection({
    required this.xM,
    required this.yM,
    required this.nx,
    required this.ny,
    required this.isInside,
  });

  final double xM;
  final double yM;
  final double nx;
  final double ny;
  final bool isInside;

  double get clampedNx => nx.clamp(0.0, 1.0).toDouble();
  double get clampedNy => ny.clamp(0.0, 1.0).toDouble();
}

class TrackerPitchProjector {
  const TrackerPitchProjector._();

  static TrackerPitchProjection? projectGps(
    TrackerFieldModel? field, {
    required double latitude,
    required double longitude,
  }) {
    if (field == null || !field.hasCalibration) return null;

    final aLat = field.cornerALat;
    final aLng = field.cornerALng;
    final bLat = field.cornerBLat;
    final bLng = field.cornerBLng;
    final dLat = field.cornerDLat;
    final dLng = field.cornerDLng;

    if (aLat == null ||
        aLng == null ||
        bLat == null ||
        bLng == null ||
        dLat == null ||
        dLng == null) {
      return null;
    }

    final p = _toLocalMeters(
      originLat: aLat,
      originLng: aLng,
      latitude: latitude,
      longitude: longitude,
    );
    final b = _toLocalMeters(
      originLat: aLat,
      originLng: aLng,
      latitude: bLat,
      longitude: bLng,
    );
    final d = _toLocalMeters(
      originLat: aLat,
      originLng: aLng,
      latitude: dLat,
      longitude: dLng,
    );

    final den = _cross(b.x, b.y, d.x, d.y);
    if (den.abs() < 0.000001) return null;

    final u = _cross(p.x, p.y, d.x, d.y) / den;
    final v = _cross(b.x, b.y, p.x, p.y) / den;

    final nx = u;
    final ny = v;
    final xM = nx * field.lengthM;
    final yM = ny * field.widthM;

    return TrackerPitchProjection(
      xM: xM,
      yM: yM,
      nx: nx,
      ny: ny,
      isInside: nx >= -0.03 && nx <= 1.03 && ny >= -0.03 && ny <= 1.03,
    );
  }

  static TrackerPitchProjection fromFieldMeters(
    TrackerFieldModel? field, {
    required double xM,
    required double yM,
  }) {
    final length = (field?.lengthM ?? 105).clamp(1.0, 500.0).toDouble();
    final width = (field?.widthM ?? 68).clamp(1.0, 500.0).toDouble();
    final nx = xM / length;
    final ny = yM / width;
    return TrackerPitchProjection(
      xM: xM,
      yM: yM,
      nx: nx,
      ny: ny,
      isInside: nx >= -0.03 && nx <= 1.03 && ny >= -0.03 && ny <= 1.03,
    );
  }

  static _MeterPoint _toLocalMeters({
    required double originLat,
    required double originLng,
    required double latitude,
    required double longitude,
  }) {
    const earthRadiusM = 6371000.0;
    final latRad = _degToRad(originLat);
    final x = _degToRad(longitude - originLng) * earthRadiusM * math.cos(latRad);
    final y = _degToRad(latitude - originLat) * earthRadiusM;
    return _MeterPoint(x, y);
  }

  static double _cross(double ax, double ay, double bx, double by) {
    return ax * by - ay * bx;
  }

  static double _degToRad(double v) => v * math.pi / 180.0;
}

class _MeterPoint {
  const _MeterPoint(this.x, this.y);
  final double x;
  final double y;
}
