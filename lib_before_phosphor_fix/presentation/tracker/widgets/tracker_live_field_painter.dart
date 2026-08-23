import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/tracker_live_models.dart';
import '../models/tracker_pitch_projection.dart';
import '../models/tracker_pro_models.dart';

class TrackerLiveFieldPainter extends CustomPainter {
  TrackerLiveFieldPainter({
    required this.field,
    required this.sessions,
    this.showHeatmap = true,
    this.showLabels = true,
  });

  final TrackerFieldModel? field;
  final List<TrackerLiveSessionModel> sessions;
  final bool showHeatmap;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(26)),
      Paint()..color = const Color(0xFF0E1216),
    );

    final pitch = Rect.fromLTWH(18, 18, size.width - 36, size.height - 36);
    final pitchRRect = RRect.fromRectAndRadius(pitch, const Radius.circular(22));
    final grass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF113D2A), Color(0xFF0D5B33), Color(0xFF0C6A3A)],
      ).createShader(pitch);
    canvas.drawRRect(pitchRRect, grass);

    _drawTexture(canvas, pitch);
    _drawPitchLines(canvas, pitch, pitchRRect);

    final gpsSessions = sessions
        .where((s) => s.latitude != null && s.longitude != null)
        .toList(growable: false);

    double? minLat;
    double? maxLat;
    double? minLon;
    double? maxLon;
    for (final s in gpsSessions) {
      final lat = s.latitude!;
      final lon = s.longitude!;
      minLat = minLat == null ? lat : math.min(minLat, lat);
      maxLat = maxLat == null ? lat : math.max(maxLat, lat);
      minLon = minLon == null ? lon : math.min(minLon, lon);
      maxLon = maxLon == null ? lon : math.max(maxLon, lon);
    }

    if (showHeatmap) {
      for (final s in sessions) {
        final pos = _sessionOffset(s, pitch, minLat, maxLat, minLon, maxLon);
        if (pos == null) continue;
        final color = _speedColor(s.speedKmh);
        final radius = (22 + s.speedKmh * 1.35).clamp(22.0, 58.0).toDouble();
        canvas.drawCircle(
          pos,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                color.withOpacity(.24),
                color.withOpacity(.08),
                Colors.transparent,
              ],
              stops: const [0, .48, 1],
            ).createShader(Rect.fromCircle(center: pos, radius: radius)),
        );
      }
    }

    for (final s in sessions) {
      final pos = _sessionOffset(s, pitch, minLat, maxLat, minLon, maxLon);
      if (pos == null) continue;
      final color = !s.isOnline ? const Color(0xFF94A3B8) : _speedColor(s.speedKmh);

      canvas.drawCircle(
        pos,
        25,
        Paint()
          ..color = color.withOpacity(.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawCircle(pos, 11, Paint()..color = color);
      canvas.drawCircle(
        pos,
        15,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withOpacity(.92),
      );
      canvas.drawCircle(pos, 4, Paint()..color = Colors.white);

      if (showLabels) {
        final label = '${s.playerName ?? s.deviceName} · ${s.speedKmh.toStringAsFixed(1)} км/ч';
        _drawLabel(canvas, pitch, pos, label, color);
      }
    }

    if (sessions.isEmpty) {
      _drawCenterText(
        canvas,
        size,
        field?.hasCalibration == true ? 'Live-точки появятся после старта' : 'Сначала откалибруйте поле',
      );
    }
  }

  Offset? _sessionOffset(
    TrackerLiveSessionModel session,
    Rect pitch,
    double? minLat,
    double? maxLat,
    double? minLon,
    double? maxLon,
  ) {
    TrackerPitchProjection? projection;

    if (session.fieldXM != null && session.fieldYM != null) {
      projection = TrackerPitchProjector.fromFieldMeters(
        field,
        xM: session.fieldXM!,
        yM: session.fieldYM!,
      );
    } else if (session.latitude != null && session.longitude != null) {
      projection = TrackerPitchProjector.projectGps(
        field,
        latitude: session.latitude!,
        longitude: session.longitude!,
      );
    }

    if (projection != null) {
      return Offset(
        pitch.left + projection.clampedNx * pitch.width,
        pitch.bottom - projection.clampedNy * pitch.height,
      );
    }

    if (session.latitude == null || session.longitude == null || minLat == null || maxLat == null || minLon == null || maxLon == null) {
      return null;
    }

    final latRange = (maxLat - minLat).abs();
    final lonRange = (maxLon - minLon).abs();
    final nx = lonRange < 0.000001
        ? 0.5
        : ((session.longitude! - minLon) / lonRange).clamp(.06, .94).toDouble();
    final ny = latRange < 0.000001
        ? 0.5
        : ((session.latitude! - minLat) / latRange).clamp(.06, .94).toDouble();

    return Offset(pitch.left + nx * pitch.width, pitch.bottom - ny * pitch.height);
  }

  void _drawTexture(Canvas canvas, Rect pitch) {
    final stripe = Paint()..color = Colors.white.withOpacity(.035);
    final stripeW = pitch.width / 10;
    for (var i = 0; i < 10; i++) {
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(pitch.left + stripeW * i, pitch.top, stripeW, pitch.height), stripe);
      }
    }

    final lane = Paint()
      ..color = Colors.white.withOpacity(.06)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = pitch.top + pitch.height / 4 * i;
      canvas.drawLine(Offset(pitch.left, y), Offset(pitch.right, y), lane);
    }
    for (var i = 1; i <= 5; i++) {
      final x = pitch.left + pitch.width / 6 * i;
      canvas.drawLine(Offset(x, pitch.top), Offset(x, pitch.bottom), lane);
    }
  }

  void _drawPitchLines(Canvas canvas, Rect pitch, RRect pitchRRect) {
    final line = Paint()
      ..color = Colors.white.withOpacity(.88)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final thin = Paint()
      ..color = Colors.white.withOpacity(.40)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(pitchRRect, line);
    canvas.drawLine(Offset(pitch.center.dx, pitch.top), Offset(pitch.center.dx, pitch.bottom), line);
    canvas.drawCircle(pitch.center, math.min(pitch.width, pitch.height) * .11, line);
    canvas.drawCircle(pitch.center, 3, Paint()..color = Colors.white.withOpacity(.92));

    final penaltyW = pitch.width * .165;
    final penaltyH = pitch.height * .52;
    final goalW = pitch.width * .060;
    final goalH = pitch.height * .24;
    canvas.drawRect(Rect.fromLTWH(pitch.left, pitch.center.dy - penaltyH / 2, penaltyW, penaltyH), line);
    canvas.drawRect(Rect.fromLTWH(pitch.right - penaltyW, pitch.center.dy - penaltyH / 2, penaltyW, penaltyH), line);
    canvas.drawRect(Rect.fromLTWH(pitch.left, pitch.center.dy - goalH / 2, goalW, goalH), thin);
    canvas.drawRect(Rect.fromLTWH(pitch.right - goalW, pitch.center.dy - goalH / 2, goalW, goalH), thin);
  }

  void _drawLabel(Canvas canvas, Rect pitch, Offset pos, String label, Color accent) {
    final text = label.length > 24 ? '${label.substring(0, 24)}…' : label;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 190);

    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        (pos.dx + 14).clamp(pitch.left, pitch.right - tp.width - 24).toDouble(),
        (pos.dy - 32).clamp(pitch.top, pitch.bottom - 28).toDouble(),
        tp.width + 16,
        24,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(bg, Paint()..color = const Color(0xCC0E1216));
    canvas.drawRRect(
      bg,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withOpacity(.5),
    );
    tp.paint(canvas, Offset(bg.left + 8, bg.top + 5));
  }

  Color _speedColor(double speedKmh) {
    if (speedKmh >= 25) return const Color(0xFFE11D48);
    if (speedKmh >= 20) return const Color(0xFFF97316);
    if (speedKmh >= 13) return const Color(0xFFFACC15);
    if (speedKmh >= 7) return const Color(0xFF2DD4BF);
    return const Color(0xFF86EFAC);
  }

  void _drawCenterText(Canvas canvas, Size size, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.white.withOpacity(.88), fontSize: 16, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 60);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant TrackerLiveFieldPainter oldDelegate) {
    return oldDelegate.field != field ||
        oldDelegate.sessions != sessions ||
        oldDelegate.showHeatmap != showHeatmap ||
        oldDelegate.showLabels != showLabels;
  }
}
