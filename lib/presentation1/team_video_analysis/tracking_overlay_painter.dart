import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/team_video_analysis/ai_tracking_controller.dart';
import 'package:sportoteka/presentation/team_video_analysis/tracking_models.dart';

class TrackingOverlayPainter extends CustomPainter {
  final AiTrackingController controller;
  final int currentVideoTimeMs;

  TrackingOverlayPainter({
    required this.controller,
    required this.currentVideoTimeMs,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final tracks = controller.tracks;
    if (tracks.isEmpty) return;

    for (final track in tracks) {
      final isSelected = controller.selectedTrackId == track.id;

      if (controller.showOnlySelectedPlayer && !isSelected) {
        continue;
      }

      final baseColor = isSelected ? Colors.redAccent : track.color;
      final color = _resolvedTrackColor(baseColor, track, isSelected);

      _drawTrail(canvas, track, color, isSelected);
      _drawBoundingBox(canvas, track, color, isSelected);
      _drawPredictedRect(canvas, track, color, isSelected);
      _drawAnchorPoint(canvas, track, color, isSelected);
      _drawLabel(canvas, size, track, color, isSelected);
      _drawSpeed(canvas, size, track, color, isSelected);
    }
  }

  Color _resolvedTrackColor(Color fallback, PlayerTrack track, bool isSelected) {
    if (isSelected) return Colors.redAccent;

    if (track.teamTag == 'home') {
      return const Color(0xFF2563EB);
    }
    if (track.teamTag == 'away') {
      return const Color(0xFFDC2626);
    }
    return fallback;
  }

  Offset _anchorPoint(PlayerTrack track) {
    if (track.points.isNotEmpty) {
      return track.points.last.position;
    }

    final rect = track.currentBoundingBox;
    if (rect != null) {
      return Offset(rect.center.dx, rect.bottom);
    }

    return Offset.zero;
  }

  void _drawTrail(Canvas canvas, PlayerTrack track, Color color, bool isSelected) {
    if (!controller.showTrails || track.points.length < 2) return;

    final recent = track.points.length > 22
        ? track.points.sublist(track.points.length - 22)
        : track.points;

    for (int i = 1; i < recent.length; i++) {
      final p1 = recent[i - 1].position;
      final p2 = recent[i].position;

      final t = i / recent.length;
      final opacity = isSelected
          ? (0.18 + 0.72 * t).clamp(0.0, 1.0)
          : (0.08 + 0.40 * t).clamp(0.0, 1.0);

      final stroke = isSelected
          ? (1.6 + 1.8 * t)
          : (1.0 + 1.0 * t);

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, paint);
    }

    final last = recent.last.position;

    final glowPaint = Paint()
      ..color = color.withOpacity(isSelected ? 0.20 : 0.10)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(last, isSelected ? 8 : 6, glowPaint);
    canvas.drawCircle(last, isSelected ? 4.2 : 3.2, dotPaint);
  }

  void _drawBoundingBox(Canvas canvas, PlayerTrack track, Color color, bool isSelected) {
    if (!controller.showBoundingBoxes) return;

    final rect = track.currentBoundingBox;
    if (rect == null) return;

    final fillPaint = Paint()
      ..color = color.withOpacity(isSelected ? 0.12 : 0.06)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withOpacity(isSelected ? 0.95 : 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.2 : 1.5;

    final boxRRect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(8),
    );

    canvas.drawRRect(boxRRect, fillPaint);
    canvas.drawRRect(boxRRect, strokePaint);

    if (isSelected) {
      final outerGlow = Paint()
        ..color = color.withOpacity(0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(10)),
        outerGlow,
      );
    }

    _drawCornerAccents(canvas, rect, color, isSelected);
  }

  void _drawCornerAccents(Canvas canvas, Rect rect, Color color, bool isSelected) {
    final accentPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.6 : 1.8
      ..strokeCap = StrokeCap.round;

    final corner = isSelected ? 10.0 : 7.0;

    // top-left
    canvas.drawLine(rect.topLeft, Offset(rect.left + corner, rect.top), accentPaint);
    canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + corner), accentPaint);

    // top-right
    canvas.drawLine(rect.topRight, Offset(rect.right - corner, rect.top), accentPaint);
    canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + corner), accentPaint);

    // bottom-left
    canvas.drawLine(rect.bottomLeft, Offset(rect.left + corner, rect.bottom), accentPaint);
    canvas.drawLine(rect.bottomLeft, Offset(rect.left, rect.bottom - corner), accentPaint);

    // bottom-right
    canvas.drawLine(rect.bottomRight, Offset(rect.right - corner, rect.bottom), accentPaint);
    canvas.drawLine(rect.bottomRight, Offset(rect.right, rect.bottom - corner), accentPaint);
  }

  void _drawAnchorPoint(Canvas canvas, PlayerTrack track, Color color, bool isSelected) {
    final point = _anchorPoint(track);
    if (point == Offset.zero) return;

    final outer = Paint()
      ..color = Colors.black.withOpacity(isSelected ? 0.30 : 0.18)
      ..style = PaintingStyle.fill;

    final inner = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(point, isSelected ? 5.2 : 4.0, outer);
    canvas.drawCircle(point, isSelected ? 3.0 : 2.4, inner);
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    PlayerTrack track,
    Color color,
    bool isSelected,
  ) {
    if (!controller.showLabels) return;

    final rect = track.currentBoundingBox;
    final pos = track.currentPosition;
    if (rect == null && pos == null) return;

    final label = _buildTrackLabel(track);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: isSelected ? 12 : 11,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 180);

    double left = rect?.left ?? pos!.dx;
    double top = (rect?.top ?? pos!.dy) - 26;

    final width = textPainter.width + 14;
    const height = 20.0;

    if (left + width > size.width - 4) {
      left = size.width - width - 4;
    }
    if (left < 4) left = 4;
    if (top < 4) {
      top = (rect?.bottom ?? pos!.dy) + 6;
    }

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(8),
    );

    final bgPaint = Paint()
      ..color = color.withOpacity(isSelected ? 0.94 : 0.86)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawRRect(bgRect.shift(const Offset(0, 1.5)), shadowPaint);
    canvas.drawRRect(bgRect, bgPaint);

    textPainter.paint(canvas, Offset(left + 7, top + 4));
  }

  String _buildTrackLabel(PlayerTrack track) {
    final number = track.jerseyNumber != null ? '#${track.jerseyNumber}' : '';
    final name = track.boundPlayerName.trim().isNotEmpty
        ? track.boundPlayerName.trim()
        : 'Игрок';

    if (number.isNotEmpty) {
      return '$number $name';
    }
    return name;
  }

  void _drawSpeed(
    Canvas canvas,
    Size size,
    PlayerTrack track,
    Color color,
    bool isSelected,
  ) {
    if (!controller.showSpeed) return;
    if (track.points.isEmpty) return;

    // Лучше показывать скорость только выбранному игроку,
    // чтобы экран не выглядел шумно.
    if (!isSelected) return;

    final rect = track.currentBoundingBox;
    final pos = track.currentPosition;
    if (rect == null && pos == null) return;

    final speed = track.points.last.speed;
    final shownSpeed = speed < 1.2 ? 0.0 : speed;
    final speedText = '${shownSpeed.toStringAsFixed(1)} км/ч';

    final speedColor = _speedColor(shownSpeed);

    final textPainter = TextPainter(
      text: TextSpan(
        text: speedText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    double left = rect?.left ?? pos!.dx;
    double top = (rect?.bottom ?? pos!.dy) + 8;

    final width = textPainter.width + 22;
    const height = 20.0;

    if (left + width > size.width - 4) {
      left = size.width - width - 4;
    }
    if (left < 4) left = 4;
    if (top + height > size.height - 4) {
      top = (rect?.top ?? pos!.dy) - 26;
    }

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(8),
    );

    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.68)
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = speedColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(bgRect, bgPaint);

    final accentRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + 4, top + 4, 7, height - 8),
      const Radius.circular(4),
    );
    canvas.drawRRect(accentRect, accentPaint);

    textPainter.paint(canvas, Offset(left + 15, top + 4));
  }

  Color _speedColor(double speed) {
    if (speed < 7) {
      return const Color(0xFFE5E7EB);
    } else if (speed < 14) {
      return const Color(0xFFFACC15);
    } else if (speed < 22) {
      return const Color(0xFFF59E0B);
    } else {
      return const Color(0xFFEF4444);
    }
  }

  void _drawPredictedRect(Canvas canvas, PlayerTrack track, Color color, bool isSelected) {
    if (!controller.isLocked) return;
    if (controller.lockedTrack?.id != track.id) return;

    final predicted = controller.getPredictedRectForTrack(track, currentVideoTimeMs);
    if (predicted == null) return;

    final paint = Paint()
      ..color = color.withOpacity(isSelected ? 0.42 : 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.5 : 1.1;

    _drawDashedRoundedRect(
      canvas,
      RRect.fromRectAndRadius(predicted, const Radius.circular(8)),
      paint,
    );
  }

  void _drawDashedRoundedRect(Canvas canvas, RRect rrect, Paint paint) {
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      const dash = 7.0;
      const gap = 5.0;

      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        final extract = metric.extractPath(distance, next);
        canvas.drawPath(extract, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant TrackingOverlayPainter oldDelegate) {
    return oldDelegate.currentVideoTimeMs != currentVideoTimeMs ||
        oldDelegate.controller != controller;
  }
}