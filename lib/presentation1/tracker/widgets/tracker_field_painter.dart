import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/tracker_pro_models.dart';

class TrackerFieldPainter extends CustomPainter {
  TrackerFieldPainter({
    required this.field,
    this.activeCorner,
  });

  final TrackerFieldModel? field;
  final String? activeCorner;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
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
    _drawCalibrationMarkers(canvas, pitch);
    _drawTitle(canvas, size);
  }

  void _drawTexture(Canvas canvas, Rect pitch) {
    final stripe = Paint()..color = Colors.white.withOpacity(.034);
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

  void _drawCalibrationMarkers(Canvas canvas, Rect pitch) {
    final f = field;
    final aOk = f?.cornerALat != null && f?.cornerALng != null;
    final bOk = f?.cornerBLat != null && f?.cornerBLng != null;
    final cOk = f?.cornerCLat != null && f?.cornerCLng != null;
    final dOk = f?.cornerDLat != null && f?.cornerDLng != null;

    marker(canvas, pitch, 'A', 'левый низ', pitch.bottomLeft, aOk);
    marker(canvas, pitch, 'B', 'правый низ', pitch.bottomRight, bOk);
    marker(canvas, pitch, 'C', 'правый верх', pitch.topRight, cOk);
    marker(canvas, pitch, 'D', 'левый верх', pitch.topLeft, dOk);
  }

  void marker(Canvas canvas, Rect pitch, String key, String label, Offset pos, bool ok) {
    final isActive = activeCorner == key;
    final accent = isActive
        ? const Color(0xFFFACC15)
        : ok
            ? const Color(0xFF86EFAC)
            : Colors.white.withOpacity(.50);

    canvas.drawCircle(
      pos,
      isActive ? 24 : 18,
      Paint()
        ..color = accent.withOpacity(.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(pos, isActive ? 10 : 8, Paint()..color = accent);
    canvas.drawCircle(
      pos,
      isActive ? 15 : 12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 2.4 : 1.6
        ..color = Colors.white.withOpacity(.88),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '$key · $label',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);

    final dx = pos.dx < pitch.center.dx ? 12.0 : -tp.width - 12.0;
    final dy = pos.dy < pitch.center.dy ? 10.0 : -tp.height - 10.0;
    tp.paint(canvas, pos + Offset(dx, dy));
  }

  void _drawTitle(Canvas canvas, Size size) {
    final f = field;
    final title = f == null ? 'Поле не выбрано' : '${f.title} · ${f.lengthM.toStringAsFixed(0)}×${f.widthM.toStringAsFixed(0)} м';
    final status = f?.hasCalibration == true ? 'Калибровка готова' : 'Нужно зафиксировать 4 угла поля';
    final color = f?.hasCalibration == true ? const Color(0xFF86EFAC) : const Color(0xFFFACC15);

    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
          TextSpan(text: '\n$status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);

    final badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(16, 14, tp.width + 22, tp.height + 16),
      const Radius.circular(16),
    );
    canvas.drawRRect(badge, Paint()..color = const Color(0xCC0E1216));
    canvas.drawRRect(
      badge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(.12),
    );
    tp.paint(canvas, Offset(badge.left + 11, badge.top + 8));
  }

  @override
  bool shouldRepaint(covariant TrackerFieldPainter oldDelegate) {
    return oldDelegate.field != field || oldDelegate.activeCorner != activeCorner;
  }
}
