import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/tracker_pro_models.dart';

class TrackerHeatmapPainter extends CustomPainter {
  TrackerHeatmapPainter({required this.points});

  final List<TrackerHeatPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      Paint()..color = const Color(0xFF0E1216),
    );

    final pitch = Rect.fromLTWH(18, 18, size.width - 36, size.height - 36);
    final pitchRRect = RRect.fromRectAndRadius(pitch, const Radius.circular(20));
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF113D2A), Color(0xFF0D5B33), Color(0xFF0C6A3A)],
      ).createShader(pitch);
    canvas.drawRRect(pitchRRect, bg);

    final stripe = Paint()..color = Colors.white.withOpacity(.032);
    final stripeW = pitch.width / 10;
    for (var i = 0; i < 10; i++) {
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(pitch.left + stripeW * i, pitch.top, stripeW, pitch.height), stripe);
      }
    }

    final maxValue = points.fold<double>(1, (m, p) => p.value > m ? p.value : m);
    for (final p in points) {
      final dx = pitch.left + p.x.clamp(0, 1) * pitch.width;
      final dy = pitch.top + p.y.clamp(0, 1) * pitch.height;
      final ratio = (p.value / maxValue).clamp(.06, 1.0).toDouble();
      final radius = 16 + 42 * ratio;
      final color = ratio > .72
          ? const Color(0xFFE11D48)
          : ratio > .38
              ? const Color(0xFFF97316)
              : const Color(0xFF2DD4BF);

      canvas.drawCircle(
        Offset(dx.toDouble(), dy.toDouble()),
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withOpacity(.42 * ratio),
              color.withOpacity(.16 * ratio),
              Colors.transparent,
            ],
            stops: const [0, .48, 1],
          ).createShader(Rect.fromCircle(center: Offset(dx.toDouble(), dy.toDouble()), radius: radius)),
      );
    }

    _drawLines(canvas, pitch, pitchRRect);
  }

  void _drawLines(Canvas canvas, Rect pitch, RRect pitchRRect) {
    final line = Paint()
      ..color = Colors.white.withOpacity(.84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final thin = Paint()
      ..color = Colors.white.withOpacity(.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

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

  @override
  bool shouldRepaint(covariant TrackerHeatmapPainter oldDelegate) => oldDelegate.points != points;
}
