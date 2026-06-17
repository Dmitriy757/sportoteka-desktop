import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'episode_annotation_model.dart';

class EpisodeAnnotationPainter extends CustomPainter {
  final List<AnnotationItem> items;
  final Size originalSize;

  EpisodeAnnotationPainter({
    required this.items,
    required this.originalSize,
  });

  Offset _scalePoint(Offset p, Size size) {
    return Offset(p.dx * size.width, p.dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in items) {
      final paint = Paint()
        ..color = item.color
        ..strokeWidth = item.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      switch (item.type) {
        case AnnotationToolType.line:
          if (item.start != null && item.end != null) {
            canvas.drawLine(
              _scalePoint(item.start!, size),
              _scalePoint(item.end!, size),
              paint,
            );
          }
          break;

        case AnnotationToolType.arrow:
          if (item.start != null && item.end != null) {
            final start = _scalePoint(item.start!, size);
            final end = _scalePoint(item.end!, size);
            canvas.drawLine(start, end, paint);

            final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
            const arrowSize = 14.0;

            final path = Path()
              ..moveTo(end.dx, end.dy)
              ..lineTo(
                end.dx - arrowSize * math.cos(angle - math.pi / 6),
                end.dy - arrowSize * math.sin(angle - math.pi / 6),
              )
              ..moveTo(end.dx, end.dy)
              ..lineTo(
                end.dx - arrowSize * math.cos(angle + math.pi / 6),
                end.dy - arrowSize * math.sin(angle + math.pi / 6),
              );

            canvas.drawPath(path, paint);
          }
          break;

        case AnnotationToolType.rect:
          if (item.start != null && item.end != null) {
            final rect = Rect.fromPoints(
              _scalePoint(item.start!, size),
              _scalePoint(item.end!, size),
            );
            canvas.drawRect(rect, paint);
          }
          break;

        case AnnotationToolType.circle:
          if (item.start != null && item.end != null) {
            final rect = Rect.fromPoints(
              _scalePoint(item.start!, size),
              _scalePoint(item.end!, size),
            );
            canvas.drawOval(rect, paint);
          }
          break;

        case AnnotationToolType.freehand:
          final pts = item.points;
          if (pts != null && pts.length > 1) {
            final path = Path()..moveTo(
              _scalePoint(pts.first, size).dx,
              _scalePoint(pts.first, size).dy,
            );
            for (final p in pts.skip(1)) {
              final pp = _scalePoint(p, size);
              path.lineTo(pp.dx, pp.dy);
            }
            canvas.drawPath(path, paint);
          }
          break;

        case AnnotationToolType.text:
          if (item.text != null && item.textOffset != null) {
            final tp = TextPainter(
              text: TextSpan(
                text: item.text!,
                style: TextStyle(
                  color: item.color,
                  fontSize: item.fontSize ?? 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, _scalePoint(item.textOffset!, size));
          }
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant EpisodeAnnotationPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}