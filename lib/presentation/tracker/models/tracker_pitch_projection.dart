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
    final cLat = field.cornerCLat;
    final cLng = field.cornerCLng;
    final dLat = field.cornerDLat;
    final dLng = field.cornerDLng;

    if (aLat == null ||
        aLng == null ||
        bLat == null ||
        bLng == null ||
        cLat == null ||
        cLng == null ||
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
    final c = _toLocalMeters(
      originLat: aLat,
      originLng: aLng,
      latitude: cLat,
      longitude: cLng,
    );

    final den = _cross(b.x, b.y, d.x, d.y);
    if (den.abs() < 0.000001) return null;

    // Начальное приближение — прежняя аффинная проекция A/B/D.
    // Затем учитываем четвёртый угол C и решаем обратное билинейное
    // преобразование. Это не растягивает реальное трапециевидное поле за
    // границы виртуальной схемы и точно ставит все четыре угла в 0/1.
    var u = _cross(p.x, p.y, d.x, d.y) / den;
    var v = _cross(b.x, b.y, p.x, p.y) / den;
    final ex = c.x - b.x - d.x;
    final ey = c.y - b.y - d.y;
    for (var iteration = 0; iteration < 7; iteration++) {
      final fx = b.x * u + d.x * v + ex * u * v - p.x;
      final fy = b.y * u + d.y * v + ey * u * v - p.y;
      final j11 = b.x + ex * v;
      final j12 = d.x + ex * u;
      final j21 = b.y + ey * v;
      final j22 = d.y + ey * u;
      final jacobian = j11 * j22 - j12 * j21;
      if (jacobian.abs() < 0.000001) break;
      final deltaU = (fx * j22 - fy * j12) / jacobian;
      final deltaV = (j11 * fy - j21 * fx) / jacobian;
      u -= deltaU;
      v -= deltaV;
      if (deltaU.abs() + deltaV.abs() < 0.0000001) break;
    }
    if (!u.isFinite || !v.isFinite) return null;

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
