import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/team_video_analysis/models/tactical_annotation_models.dart';

class TacticalAnnotationPainter extends CustomPainter {
  final List<TacticalAnnotation> items;
  final String? selectedId;

  const TacticalAnnotationPainter({
    required this.items,
    this.selectedId,
  });

  Offset _scalePoint(Offset p, Size size) {
    return Offset(p.dx * size.width, p.dy * size.height);
  }

  Paint _basePaint(TacticalAnnotation item) {
    return Paint()
      ..color = item.color.withOpacity(item.opacity)
      ..strokeWidth = item.strokeWidth
      ..style = item.filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 10.0;
    const dashSpace = 7.0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance <= 0) return;

    final vx = dx / distance;
    final vy = dy / distance;

    double drawn = 0;
    while (drawn < distance) {
      final x1 = start.dx + vx * drawn;
      final y1 = start.dy + vy * drawn;
      final next = math.min(drawn + dashWidth, distance);
      final x2 = start.dx + vx * next;
      final y2 = start.dy + vy * next;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      drawn += dashWidth + dashSpace;
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);

    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final wing = 16.0 + paint.strokeWidth;
    final wingAngle = math.pi / 7;

    final p1 = Offset(
      end.dx - wing * math.cos(angle - wingAngle),
      end.dy - wing * math.sin(angle - wingAngle),
    );

    final p2 = Offset(
      end.dx - wing * math.cos(angle + wingAngle),
      end.dy - wing * math.sin(angle + wingAngle),
    );

    canvas.drawLine(end, p1, paint);
    canvas.drawLine(end, p2, paint);
  }

  void _drawRunArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    final curvedPaint = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final mid = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2 - 36,
    );

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);

    if (paint.color.opacity > 0) {
      if (paint.strokeWidth > 0) {
        if (paint.style == PaintingStyle.stroke) {
          canvas.drawPath(path, curvedPaint);
        }
      }
    }

    final tangentStart = Offset(
      end.dx - mid.dx,
      end.dy - mid.dy,
    );
    final angle = math.atan2(tangentStart.dy, tangentStart.dx);
    final wing = 16.0 + paint.strokeWidth;
    final wingAngle = math.pi / 7;

    final p1 = Offset(
      end.dx - wing * math.cos(angle - wingAngle),
      end.dy - wing * math.sin(angle - wingAngle),
    );
    final p2 = Offset(
      end.dx - wing * math.cos(angle + wingAngle),
      end.dy - wing * math.sin(angle + wingAngle),
    );

    canvas.drawLine(end, p1, curvedPaint);
    canvas.drawLine(end, p2, curvedPaint);
  }

  void _drawPlayerMarker(
    Canvas canvas,
    Size size,
    TacticalAnnotation item,
    Paint paint,
  ) {
    final pos = item.start != null
        ? _scalePoint(item.start!, size)
        : (item.textOffset != null ? _scalePoint(item.textOffset!, size) : null);
    if (pos == null) return;

    final fillPaint = Paint()
      ..color = item.color.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pos, 20, fillPaint);
    canvas.drawCircle(
      pos,
      20,
      Paint()
        ..color = item.color.withOpacity(item.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = item.strokeWidth,
    );

    final text = item.text?.trim().isNotEmpty == true ? item.text!.trim() : 'P';

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: item.color,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(
        pos.dx - tp.width / 2,
        pos.dy - tp.height / 2,
      ),
    );
  }

  void _drawFreePath(Canvas canvas, Size size, TacticalAnnotation item, Paint paint) {
    final pts = item.points;
    if (pts == null || pts.length < 2) return;

    final path = Path();
    final first = _scalePoint(pts.first, size);
    path.moveTo(first.dx, first.dy);

    for (final p in pts.skip(1)) {
      final pp = _scalePoint(p, size);
      path.lineTo(pp.dx, pp.dy);
    }

    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, Size size, TacticalAnnotation item) {
    if (item.text == null || item.textOffset == null) return;

    final pos = _scalePoint(item.textOffset!, size);

    final tp = TextPainter(
      text: TextSpan(
        text: item.text!,
        style: TextStyle(
          color: item.color.withOpacity(item.opacity),
          fontSize: item.fontSize ?? 18,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(
              blurRadius: 4,
              color: Colors.black26,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.6);

    tp.paint(canvas, pos);
  }

  void _drawSelection(Canvas canvas, Size size, TacticalAnnotation item) {
    if (item.id != selectedId) return;

    final highlightPaint = Paint()
      ..color = const Color(0xFF2563EB).withOpacity(0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    Rect? bounds;

    if (item.start != null && item.end != null) {
      bounds = Rect.fromPoints(
        _scalePoint(item.start!, size),
        _scalePoint(item.end!, size),
      );
    } else if (item.points != null && item.points!.isNotEmpty) {
      final scaled = item.points!.map((p) => _scalePoint(p, size)).toList();
      double minX = scaled.first.dx;
      double maxX = scaled.first.dx;
      double minY = scaled.first.dy;
      double maxY = scaled.first.dy;

      for (final p in scaled) {
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
      bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    } else if (item.textOffset != null) {
      final pos = _scalePoint(item.textOffset!, size);
      bounds = Rect.fromLTWH(pos.dx - 6, pos.dy - 6, 110, 36);
    }

    if (bounds == null) return;

    final padded = bounds.inflate(8);
    _drawDashedLine(canvas, padded.topLeft, padded.topRight, highlightPaint);
    _drawDashedLine(canvas, padded.topRight, padded.bottomRight, highlightPaint);
    _drawDashedLine(canvas, padded.bottomRight, padded.bottomLeft, highlightPaint);
    _drawDashedLine(canvas, padded.bottomLeft, padded.topLeft, highlightPaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in items) {
      final paint = _basePaint(item);

      switch (item.type) {
        case TacticalToolType.passArrow:
          if (item.start != null && item.end != null) {
            final s = _scalePoint(item.start!, size);
            final e = _scalePoint(item.end!, size);
            _drawArrow(canvas, s, e, paint);
          }
          break;

        case TacticalToolType.runArrow:
          if (item.start != null && item.end != null) {
            final s = _scalePoint(item.start!, size);
            final e = _scalePoint(item.end!, size);
            _drawRunArrow(canvas, s, e, paint);
          }
          break;

        case TacticalToolType.straightLine:
          if (item.start != null && item.end != null) {
            final s = _scalePoint(item.start!, size);
            final e = _scalePoint(item.end!, size);
            canvas.drawLine(s, e, paint);
          }
          break;

        case TacticalToolType.dashedLine:
          if (item.start != null && item.end != null) {
            final s = _scalePoint(item.start!, size);
            final e = _scalePoint(item.end!, size);
            _drawDashedLine(canvas, s, e, paint);
          }
          break;

        case TacticalToolType.circle:
          if (item.start != null && item.end != null) {
            final rect = Rect.fromPoints(
              _scalePoint(item.start!, size),
              _scalePoint(item.end!, size),
            );
            canvas.drawOval(rect, paint);
          }
          break;

        case TacticalToolType.rect:
        case TacticalToolType.zone:
          if (item.start != null && item.end != null) {
            final rect = Rect.fromPoints(
              _scalePoint(item.start!, size),
              _scalePoint(item.end!, size),
            );
            canvas.drawRect(rect, paint);
          }
          break;

        case TacticalToolType.playerMarker:
          _drawPlayerMarker(canvas, size, item, paint);
          break;

        case TacticalToolType.text:
          _drawText(canvas, size, item);
          break;

        case TacticalToolType.freeDraw:
          _drawFreePath(canvas, size, item, paint);
          break;

        case TacticalToolType.select:
        case TacticalToolType.eraser:
          break;
      }

      _drawSelection(canvas, size, item);
    }
  }

  @override
  bool shouldRepaint(covariant TacticalAnnotationPainter oldDelegate) {
    return oldDelegate.items != items || oldDelegate.selectedId != selectedId;
  }
}