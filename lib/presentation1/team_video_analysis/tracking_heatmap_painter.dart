// lib/presentation/team_video_analysis/tracking_heatmap_painter.dart

import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/team_video_analysis/tracking_models.dart';

class TrackingHeatmapPainter extends CustomPainter {
  final List<TrackPoint> points;
  final Color color;

  const TrackingHeatmapPainter({
    required this.points,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Рисуем тепловую карту на основе плотности точек
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i].position;
      final p2 = points[i + 1].position;
      
      canvas.drawLine(p1, p2, paint);
      
      // Рисуем круги для областей с высокой плотностью
      final opacity = (i / points.length).clamp(0.1, 0.5);
      final circlePaint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(p1, 5, circlePaint);
    }

    // Последняя точка
    if (points.isNotEmpty) {
      final lastPaint = Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points.last.position, 8, lastPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TrackingHeatmapPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}