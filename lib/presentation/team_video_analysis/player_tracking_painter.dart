import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/team_video_analysis/ai_tracking_controller.dart';
import 'package:sportoteka/presentation/team_video_analysis/tracking_models.dart';

class PlayerTrackingPainter extends CustomPainter {
  final AiTrackingController controller;
  final int currentTimeMs;
  final Size fieldSize;

  PlayerTrackingPainter({
    required this.controller,
    required this.currentTimeMs,
    required this.fieldSize,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    _drawDangerZones(canvas, size);
    _drawTeamShapes(canvas);

    for (final track in controller.tracks) {
      final isSelected = controller.selectedTrackId == track.id;

      if (controller.showOnlySelectedPlayer && !isSelected) {
        continue;
      }

      _drawTrail(canvas, track, isSelected);
    }

    _drawPassArrows(canvas);
    _drawBall(canvas);

    for (final track in controller.tracks) {
      final isSelected = controller.selectedTrackId == track.id;

      if (controller.showOnlySelectedPlayer && !isSelected) {
        continue;
      }

      _drawBoundingBox(canvas, track, isSelected);
      _drawLabel(canvas, track, isSelected);
      _drawSpeed(canvas, track, isSelected);
      _drawPredictedRect(canvas, track, isSelected);
    }
  }

  void _drawTrail(Canvas canvas, PlayerTrack track, bool isSelected) {
    if (!controller.showTrails || track.points.length < 2) return;

    for (int i = 1; i < track.points.length; i++) {
      final p1 = track.points[i - 1].position;
      final p2 = track.points[i].position;
      final t = i / track.points.length;

      final glowPaint = Paint()
        ..color = track.color.withOpacity((0.10 + 0.18 * t).clamp(0.0, 1.0))
        ..strokeWidth = 4 + 2 * t
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final linePaint = Paint()
        ..color = track.color.withOpacity((0.28 + 0.72 * t).clamp(0.0, 1.0))
        ..strokeWidth = (isSelected ? 2.8 : 1.8) + 1.8 * t
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, linePaint);
    }

    final currentDotPaint = Paint()..color = track.color;
    canvas.drawCircle(
      track.points.last.position,
      isSelected ? 5.5 : 4.0,
      currentDotPaint,
    );
  }

  void _drawBoundingBox(Canvas canvas, PlayerTrack track, bool isSelected) {
    if (!controller.showBoundingBoxes) return;

    final rect = track.currentBoundingBox;
    if (rect == null) return;

    final strokePaint = Paint()
      ..color = track.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.8 : 2.0;

    final glowPaint = Paint()
      ..color = track.color.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      glowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      strokePaint,
    );
  }

  void _drawLabel(Canvas canvas, PlayerTrack track, bool isSelected) {
    if (!controller.showLabels) return;

    final rect = track.currentBoundingBox;
    if (rect == null) return;

    final label = (track.boundPlayerName.isNotEmpty
            ? track.boundPlayerName
            : track.id)
        .trim();

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: isSelected ? 12 : 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 160);

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left,
        math.max(0, rect.top - 22),
        textPainter.width + 12,
        18,
      ),
      const Radius.circular(6),
    );

    final bgPaint = Paint()..color = track.color.withOpacity(0.92);

    canvas.drawRRect(bgRect, bgPaint);
    textPainter.paint(canvas, Offset(bgRect.left + 6, bgRect.top + 2));
  }

  void _drawSpeed(Canvas canvas, PlayerTrack track, bool isSelected) {
    if (!controller.showSpeed || track.points.isEmpty) return;

    final rect = track.currentBoundingBox;
    if (rect == null) return;

    final speedText = '${track.points.last.speed.toStringAsFixed(1)} км/ч';

    final textPainter = TextPainter(
      text: TextSpan(
        text: speedText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left,
        rect.bottom + 4,
        textPainter.width + 10,
        16,
      ),
      const Radius.circular(6),
    );

    final bgPaint = Paint()..color = Colors.black.withOpacity(0.65);

    canvas.drawRRect(bgRect, bgPaint);
    textPainter.paint(canvas, Offset(bgRect.left + 5, bgRect.top + 2));
  }

  void _drawPredictedRect(Canvas canvas, PlayerTrack track, bool isSelected) {
    if (!isSelected) return;

    final predicted = controller.getPredictedRectForTrack(track, currentTimeMs);
    if (predicted == null) return;

    final paint = Paint()
      ..color = track.color.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    _drawDashedRRect(
      canvas,
      RRect.fromRectAndRadius(predicted, const Radius.circular(8)),
      paint,
    );
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    final rect = rrect.outerRect;
    const dash = 7.0;
    const gap = 4.0;

    void drawDashedLine(Offset a, Offset b) {
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance == 0) return;

      final ux = dx / distance;
      final uy = dy / distance;

      double start = 0;
      while (start < distance) {
        final end = math.min(start + dash, distance);
        final p1 = Offset(a.dx + ux * start, a.dy + uy * start);
        final p2 = Offset(a.dx + ux * end, a.dy + uy * end);
        canvas.drawLine(p1, p2, paint);
        start += dash + gap;
      }
    }

    drawDashedLine(rect.topLeft, rect.topRight);
    drawDashedLine(rect.topRight, rect.bottomRight);
    drawDashedLine(rect.bottomRight, rect.bottomLeft);
    drawDashedLine(rect.bottomLeft, rect.topLeft);
  }

  void _drawBall(Canvas canvas) {
    if (!controller.showBall) return;

    final ballTrack = controller.ballTrack;
    final ball = ballTrack?.lastPoint;
    if (ball == null) return;

    if (controller.showBallTrail && ballTrack!.points.length > 1) {
      for (int i = 1; i < ballTrack.points.length; i++) {
        final p1 = ballTrack.points[i - 1].position;
        final p2 = ballTrack.points[i].position;
        final t = i / ballTrack.points.length;

        final paint = Paint()
          ..color = Colors.white.withOpacity((0.15 + 0.55 * t).clamp(0.0, 1.0))
          ..strokeWidth = 1.2 + 1.2 * t
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(p1, p2, paint);
      }
    }

    final glow = Paint()
      ..color = const Color(0xFFFFF59D).withOpacity(0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final fill = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(ball.position, 10, glow);
    canvas.drawCircle(ball.position, 5, fill);
    canvas.drawCircle(ball.position, 5, ring);
  }

  void _drawPassArrows(Canvas canvas) {
    if (!controller.showPassNetwork && controller.passArrows.isEmpty) return;

    for (final arrow in controller.passArrows) {
      final age = currentTimeMs - arrow.timeMs;
      if (age > 3500) continue;

      final alpha = 1.0 - (age / 3500).clamp(0, 1);
      final color =
          const Color(0xFF38BDF8).withOpacity((0.20 + 0.70 * alpha).clamp(0.0, 1.0));

      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(arrow.from, arrow.to, paint);

      final dir = arrow.to - arrow.from;
      final len = dir.distance;
      if (len > 0) {
        final n = Offset(dir.dx / len, dir.dy / len);
        final left = Offset(-n.dy, n.dx);

        final tip = arrow.to;
        final wing1 = tip - n * 14 + left * 7;
        final wing2 = tip - n * 14 - left * 7;

        canvas.drawLine(tip, wing1, paint);
        canvas.drawLine(tip, wing2, paint);
      }
    }
  }

  void _drawDangerZones(Canvas canvas, Size size) {
    final finalThird = Rect.fromLTWH(
      size.width * 0.75,
      0,
      size.width * 0.25,
      size.height,
    );

    final paint = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.05);

    canvas.drawRect(finalThird, paint);
  }

  void _drawTeamShapes(Canvas canvas) {
    _drawTeamShape(canvas, _getTeamShapeRect('home'), const Color(0xFF2563EB));
    _drawTeamShape(canvas, _getTeamShapeRect('away'), const Color(0xFFDC2626));
  }

  Rect? _getTeamShapeRect(String teamTag) {
    final teamTracks = controller.tracks.where((t) => t.teamTag == teamTag).toList();
    if (teamTracks.length < 2) return null;

    final positions = teamTracks
        .map((t) => t.currentPosition)
        .whereType<Offset>()
        .toList();

    if (positions.length < 2) return null;

    final minX = positions.map((e) => e.dx).reduce(math.min);
    final maxX = positions.map((e) => e.dx).reduce(math.max);
    final minY = positions.map((e) => e.dy).reduce(math.min);
    final maxY = positions.map((e) => e.dy).reduce(math.max);

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _drawTeamShape(Canvas canvas, Rect? rect, Color color) {
    if (rect == null) return;

    final expanded = rect.inflate(18);

    final fill = Paint()
      ..color = color.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = color.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(expanded, const Radius.circular(22));

    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, stroke);
  }

  @override
  bool shouldRepaint(covariant PlayerTrackingPainter oldDelegate) {
    return oldDelegate.currentTimeMs != currentTimeMs ||
        oldDelegate.fieldSize != fieldSize ||
        oldDelegate.controller != controller;
  }
}