import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class TgId {
  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}

class TgMath {
  static Offset rotate(Offset v, double a) {
    final c = math.cos(a);
    final s = math.sin(a);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  static Offset norm(Offset v) {
    final l = v.distance;
    if (l == 0) return const Offset(1, 0);
    return v / l;
  }

  static double clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);

  static List<Offset> wavyPoints(Offset a, Offset b, {int steps = 24, double amp = 10}) {
    final d = b - a;
    final len = d.distance;
    if (len < 1) return [a, b];

    final dir = d / len;
    final n = Offset(-dir.dy, dir.dx);

    final pts = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * len;
      final y = math.sin(t * math.pi * 2) * amp;
      pts.add(a + dir * x + n * y);
    }
    return pts;
  }

  static ui.Path dashedPath(ui.Path src, double dash, double gap) {
    final ui.Path out = ui.Path();
    for (final m in src.computeMetrics()) {
      double dist = 0;
      while (dist < m.length) {
        final double next = math.min(dist + dash, m.length);
        out.addPath(m.extractPath(dist, next), ui.Offset.zero);
        dist = next + gap;
      }
    }
    return out;
  }

  static Future<Uint8List?> renderWidgetToPng(GlobalKey repaintKey, {double pixelRatio = 3}) async {
    final ctx = repaintKey.currentContext;
    if (ctx == null) return null;

    final ro = ctx.findRenderObject();
    if (ro == null) return null;

    // ignore: cast_nullable_to_non_nullable
    final boundary = ro as RenderRepaintBoundary;
    final ui.Image img = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}
