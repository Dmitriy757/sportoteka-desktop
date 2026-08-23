import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/club_ai_visualization.dart';

class ClubAiVisualizationCard extends StatelessWidget {
  const ClubAiVisualizationCard({
    super.key,
    required this.visualization,
    this.compact = false,
  });

  final ClubAiVisualization visualization;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final body = switch (visualization.type) {
      ClubAiVisualizationType.tacticalBoard =>
        _TacticalBoard(data: visualization.data),
      ClubAiVisualizationType.heartRate => _SeriesChart(
          data: visualization.data,
          icon: Icons.monitor_heart_rounded,
          unit: 'уд/мин',
        ),
      ClubAiVisualizationType.speed => _SeriesChart(
          data: visualization.data,
          icon: Icons.speed_rounded,
          unit: 'км/ч',
        ),
      ClubAiVisualizationType.load => _SeriesChart(
          data: visualization.data,
          icon: Icons.bolt_rounded,
          unit: '',
        ),
      ClubAiVisualizationType.trajectory =>
        _TrajectoryChart(data: visualization.data),
      ClubAiVisualizationType.metrics =>
        _MetricsGrid(data: visualization.data),
      ClubAiVisualizationType.unknown =>
        _UnknownVisualization(data: visualization.data),
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(color: const Color(0xFFE5EAE7)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D122018),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _VisualIcon(type: visualization.type),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visualization.title,
                      style: TextStyle(
                        color: const Color(0xFF16231C),
                        fontSize: compact ? 12.5 : 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (visualization.subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        visualization.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF738078),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          body,
        ],
      ),
    );
  }
}

class _VisualIcon extends StatelessWidget {
  const _VisualIcon({required this.type});

  final ClubAiVisualizationType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      ClubAiVisualizationType.tacticalBoard => Icons.sports_soccer_rounded,
      ClubAiVisualizationType.heartRate => Icons.monitor_heart_rounded,
      ClubAiVisualizationType.speed => Icons.speed_rounded,
      ClubAiVisualizationType.load => Icons.bolt_rounded,
      ClubAiVisualizationType.trajectory => Icons.route_rounded,
      ClubAiVisualizationType.metrics => Icons.grid_view_rounded,
      ClubAiVisualizationType.unknown => Icons.auto_graph_rounded,
    };

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 18, color: const Color(0xFF158347)),
    );
  }
}

class _SeriesChart extends StatelessWidget {
  const _SeriesChart({
    required this.data,
    required this.icon,
    required this.unit,
  });

  final Map<String, dynamic> data;
  final IconData icon;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final points = ClubAiSeriesPoint.parse(data);
    final minValue = points.isEmpty
        ? 0.0
        : points.map((e) => e.y).reduce(math.min);
    final maxValue = points.isEmpty
        ? 0.0
        : points.map((e) => e.y).reduce(math.max);
    final avgValue = points.isEmpty
        ? 0.0
        : points.fold<double>(0, (sum, e) => sum + e.y) / points.length;

    if (points.length < 2) {
      return const _EmptyVisual(
        text: 'Для построения графика недостаточно точек.',
      );
    }

    return Column(
      children: [
        Row(
          children: [
            _Metric(label: 'Среднее', value: avgValue, unit: unit),
            const SizedBox(width: 8),
            _Metric(label: 'Максимум', value: maxValue, unit: unit),
            const SizedBox(width: 8),
            _Metric(label: 'Минимум', value: minValue, unit: unit),
          ],
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 2.25,
          child: CustomPaint(
            painter: _SeriesPainter(
              points: points,
              zones: data['zones'] is List
                  ? List<dynamic>.from(data['zones'] as List)
                  : const <dynamic>[],
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8F7),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7B8780),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${value.toStringAsFixed(value >= 100 ? 0 : 1)}'
              '${unit.isEmpty ? '' : ' $unit'}',
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFF1B2921),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesPainter extends CustomPainter {
  const _SeriesPainter({
    required this.points,
    required this.zones,
  });

  final List<ClubAiSeriesPoint> points;
  final List<dynamic> zones;

  @override
  void paint(Canvas canvas, Size size) {
    const padLeft = 6.0;
    const padTop = 8.0;
    const padBottom = 12.0;
    final graph = Rect.fromLTRB(
      padLeft,
      padTop,
      size.width - 4,
      size.height - padBottom,
    );

    final minX = points.map((e) => e.x).reduce(math.min);
    final maxX = points.map((e) => e.x).reduce(math.max);
    var minY = points.map((e) => e.y).reduce(math.min);
    var maxY = points.map((e) => e.y).reduce(math.max);

    if ((maxY - minY).abs() < 0.001) {
      minY -= 1;
      maxY += 1;
    }

    final dx = math.max(0.000001, maxX - minX);
    final dy = math.max(0.000001, maxY - minY);

    final gridPaint = Paint()
      ..color = const Color(0xFFE7ECE9)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = graph.top + graph.height * i / 4;
      canvas.drawLine(
        Offset(graph.left, y),
        Offset(graph.right, y),
        gridPaint,
      );
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = graph.left + (point.x - minX) / dx * graph.width;
      final y = graph.bottom - (point.y - minY) / dy * graph.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(graph.right, graph.bottom)
      ..lineTo(graph.left, graph.bottom)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x441A9A55),
            Color(0x001A9A55),
          ],
        ).createShader(graph),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF168849)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    final last = points.last;
    final lastX = graph.left + (last.x - minX) / dx * graph.width;
    final lastY = graph.bottom - (last.y - minY) / dy * graph.height;
    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()..color = const Color(0xFF168849),
    );
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.zones != zones;
  }
}

class _TrajectoryChart extends StatelessWidget {
  const _TrajectoryChart({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final points = ClubAiTrackPoint.parse(data);
    if (points.length < 2) {
      return const _EmptyVisual(
        text: 'Для траектории недостаточно координат.',
      );
    }

    return AspectRatio(
      aspectRatio: 1.55,
      child: CustomPaint(
        painter: _TrajectoryPainter(points: points),
      ),
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  const _TrajectoryPainter({required this.points});

  final List<ClubAiTrackPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final field = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );

    canvas.drawRRect(
      field,
      Paint()..color = const Color(0xFF218D51),
    );

    final line = Paint()
      ..color = Colors.white.withOpacity(.82)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
        const Radius.circular(10),
      ),
      line,
    );
    canvas.drawLine(
      Offset(size.width / 2, 6),
      Offset(size.width / 2, size.height - 6),
      line,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      math.min(size.width, size.height) * .12,
      line,
    );

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = 9 + p.x * (size.width - 18);
      final y = 9 + (1 - p.y) * (size.height - 18);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFE087)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    final first = points.first;
    final last = points.last;
    canvas.drawCircle(
      Offset(
        9 + first.x * (size.width - 18),
        9 + (1 - first.y) * (size.height - 18),
      ),
      4,
      Paint()..color = const Color(0xFFB9F6CA),
    );
    canvas.drawCircle(
      Offset(
        9 + last.x * (size.width - 18),
        9 + (1 - last.y) * (size.height - 18),
      ),
      5,
      Paint()..color = const Color(0xFFFFC857),
    );
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _TacticalBoard extends StatelessWidget {
  const _TacticalBoard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final rawPlayers = data['players'];
    if (rawPlayers is! List || rawPlayers.isEmpty) {
      return const _EmptyVisual(text: 'В схеме нет игроков.');
    }

    return AspectRatio(
      aspectRatio: .72,
      child: CustomPaint(
        painter: _TacticalPainter(data: data),
      ),
    );
  }
}

class _TacticalPainter extends CustomPainter {
  const _TacticalPainter({required this.data});

  final Map<String, dynamic> data;

  double _coord(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse('$value') ?? 0;
    return parsed.abs() <= 1.2 ? parsed : parsed / 100;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final field = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(15),
    );
    canvas.drawRRect(field, Paint()..color = const Color(0xFF208D50));

    final white = Paint()
      ..color = Colors.white.withOpacity(.86)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final bounds = Rect.fromLTWH(7, 7, size.width - 14, size.height - 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(11)),
      white,
    );
    canvas.drawLine(
      Offset(7, size.height / 2),
      Offset(size.width - 7, size.height / 2),
      white,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      math.min(size.width, size.height) * .12,
      white,
    );

    final zones = data['zones'];
    if (zones is List) {
      for (final item in zones.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final rect = Rect.fromLTWH(
          _coord(map['x']) * size.width,
          _coord(map['y']) * size.height,
          _coord(map['w']) * size.width,
          _coord(map['h']) * size.height,
        );
        canvas.drawRect(
          rect,
          Paint()..color = Colors.white.withOpacity(.10),
        );
      }
    }

    final arrows = data['arrows'];
    if (arrows is List) {
      for (final item in arrows.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final from = map['from'];
        final to = map['to'];
        if (from is! List || to is! List || from.length < 2 || to.length < 2) {
          continue;
        }

        final a = Offset(
          _coord(from[0]) * size.width,
          _coord(from[1]) * size.height,
        );
        final b = Offset(
          _coord(to[0]) * size.width,
          _coord(to[1]) * size.height,
        );

        final arrowPaint = Paint()
          ..color = const Color(0xFFFFE087)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(a, b, arrowPaint);
        final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
        const head = 8.0;
        canvas.drawLine(
          b,
          Offset(
            b.dx - head * math.cos(angle - .55),
            b.dy - head * math.sin(angle - .55),
          ),
          arrowPaint,
        );
        canvas.drawLine(
          b,
          Offset(
            b.dx - head * math.cos(angle + .55),
            b.dy - head * math.sin(angle + .55),
          ),
          arrowPaint,
        );
      }
    }

    final players = data['players'] as List;
    for (final item in players.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final x = _coord(map['x']) * size.width;
      final y = _coord(map['y']) * size.height;
      final role = '${map['role'] ?? map['label'] ?? map['name'] ?? ''}';

      canvas.drawCircle(
        Offset(x, y),
        13,
        Paint()..color = const Color(0xFF142D21),
      );
      canvas.drawCircle(
        Offset(x, y),
        13,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );

      final painter = TextPainter(
        text: TextSpan(
          text: role,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 28);
      painter.paint(
        canvas,
        Offset(x - painter.width / 2, y - painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final raw = data['items'] ?? data['metrics'] ?? data;
    final items = <MapEntry<String, dynamic>>[];

    if (raw is Map) {
      items.addAll(
        Map<String, dynamic>.from(raw)
            .entries
            .where((e) => e.value is num || e.value is String),
      );
    } else if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        items.add(
          MapEntry(
            '${map['label'] ?? map['title'] ?? ''}',
            map['value'] ?? '',
          ),
        );
      }
    }

    if (items.isEmpty) {
      return const _EmptyVisual(text: 'Нет показателей для отображения.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.take(8).map((entry) {
        return Container(
          width: 132,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF77847C),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${entry.value}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF18261E),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _UnknownVisualization extends StatelessWidget {
  const _UnknownVisualization({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return _EmptyVisual(
      text: '${data['message'] ?? 'Этот формат визуализации пока не поддерживается.'}',
    );
  }
}

class _EmptyVisual extends StatelessWidget {
  const _EmptyVisual({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF7A867F),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
