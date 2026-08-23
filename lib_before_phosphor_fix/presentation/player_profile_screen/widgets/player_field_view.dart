import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/player_profile_models.dart';

class PlayerFieldView extends StatelessWidget {
  final List<PlayerProfilePoint> route;
  final List<PlayerProfilePoint> heatmap;

  const PlayerFieldView({
    super.key,
    this.route = const [],
    this.heatmap = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        painter: _TrackerStyleFieldPainter(route: route, heatmap: heatmap),
        child: route.isEmpty && heatmap.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'В отчёте выбранной сессии нет координат или heatmap.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

class _TrackerStyleFieldPainter extends CustomPainter {
  final List<PlayerProfilePoint> route;
  final List<PlayerProfilePoint> heatmap;

  const _TrackerStyleFieldPainter({required this.route, required this.heatmap});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    canvas.drawRect(outer, Paint()..color = const Color(0xFF0E1216));

    final pitch = Rect.fromLTWH(16, 16, size.width - 32, size.height - 32);
    final pitchRRect = RRect.fromRectAndRadius(pitch, const Radius.circular(18));
    final grass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF113D2A), Color(0xFF0D5B33), Color(0xFF0C6A3A)],
      ).createShader(pitch);
    canvas.drawRRect(pitchRRect, grass);

    final stripe = Paint()..color = Colors.white.withOpacity(.035);
    final stripeWidth = pitch.width / 10;
    for (var i = 0; i < 10; i++) {
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(pitch.left + stripeWidth * i, pitch.top, stripeWidth, pitch.height),
          stripe,
        );
      }
    }

    _drawHeatmap(canvas, pitch);
    _drawPitch(canvas, pitch, pitchRRect);
    _drawRoute(canvas, pitch);
  }

  void _drawPitch(Canvas canvas, Rect pitch, RRect pitchRRect) {
    final line = Paint()
      ..color = Colors.white.withOpacity(.84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final thin = Paint()
      ..color = Colors.white.withOpacity(.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(pitchRRect, line);
    canvas.drawLine(Offset(pitch.center.dx, pitch.top), Offset(pitch.center.dx, pitch.bottom), line);
    canvas.drawCircle(pitch.center, math.min(pitch.width, pitch.height) * .11, line);
    canvas.drawCircle(pitch.center, 2.5, Paint()..color = Colors.white.withOpacity(.9));

    final penaltyW = pitch.width * .165;
    final penaltyH = pitch.height * .52;
    final goalW = pitch.width * .06;
    final goalH = pitch.height * .24;
    canvas.drawRect(Rect.fromLTWH(pitch.left, pitch.center.dy - penaltyH / 2, penaltyW, penaltyH), line);
    canvas.drawRect(Rect.fromLTWH(pitch.right - penaltyW, pitch.center.dy - penaltyH / 2, penaltyW, penaltyH), line);
    canvas.drawRect(Rect.fromLTWH(pitch.left, pitch.center.dy - goalH / 2, goalW, goalH), thin);
    canvas.drawRect(Rect.fromLTWH(pitch.right - goalW, pitch.center.dy - goalH / 2, goalW, goalH), thin);
  }

  void _drawHeatmap(Canvas canvas, Rect pitch) {
    if (heatmap.isEmpty) return;
    final maxValue = heatmap.fold<double>(1, (m, p) => (p.value ?? 1) > m ? (p.value ?? 1) : m);
    for (final p in heatmap) {
      final point = _mapPoint(p, pitch);
      final ratio = ((p.value ?? 1) / maxValue).clamp(.08, 1.0).toDouble();
      final radius = 12 + 34 * ratio;
      final color = ratio > .72
          ? const Color(0xFFE11D48)
          : ratio > .38
              ? const Color(0xFFF97316)
              : const Color(0xFF2DD4BF);
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withOpacity(.42 * ratio),
              color.withOpacity(.15 * ratio),
              Colors.transparent,
            ],
            stops: const [0, .5, 1],
          ).createShader(Rect.fromCircle(center: point, radius: radius)),
      );
    }
  }

  void _drawRoute(Canvas canvas, Rect pitch) {
    if (route.length < 2) return;
    final path = Path();
    final first = _mapPoint(route.first, pitch);
    path.moveTo(first.dx, first.dy);
    for (final p in route.skip(1)) {
      final point = _mapPoint(p, pitch);
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF86EFAC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(first, 4.2, Paint()..color = const Color(0xFFFACC15));
    canvas.drawCircle(_mapPoint(route.last, pitch), 4.2, Paint()..color = const Color(0xFFF43F5E));
  }

  Offset _mapPoint(PlayerProfilePoint value, Rect pitch) {
    double x = value.x;
    double y = value.y;
    final all = [...route, ...heatmap];
    if ((x.abs() > 1 || y.abs() > 1) && all.isNotEmpty) {
      final xs = all.map((e) => e.x).toList();
      final ys = all.map((e) => e.y).toList();
      final minX = xs.reduce(math.min);
      final maxX = xs.reduce(math.max);
      final minY = ys.reduce(math.min);
      final maxY = ys.reduce(math.max);
      x = maxX == minX ? .5 : (value.x - minX) / (maxX - minX);
      y = maxY == minY ? .5 : (value.y - minY) / (maxY - minY);
    }
    return Offset(
      pitch.left + x.clamp(0, 1) * pitch.width,
      pitch.top + (1 - y.clamp(0, 1)) * pitch.height,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackerStyleFieldPainter oldDelegate) {
    return oldDelegate.route != route || oldDelegate.heatmap != heatmap;
  }
}
