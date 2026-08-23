import 'dart:math' as math;
import 'package:flutter/material.dart';

class PlayerTrackerLoadPoint {
  const PlayerTrackerLoadPoint({required this.sec, required this.value});
  final double sec;
  final double value;
}

class PlayerTrackerHrPoint {
  const PlayerTrackerHrPoint({required this.sec, required this.bpm});
  final double sec;
  final double bpm;
}

class PlayerTrackerHrChart extends StatefulWidget {
  const PlayerTrackerHrChart({required this.values, required this.compact, this.loadPoints = const <PlayerTrackerLoadPoint>[]});
  final List<PlayerTrackerHrPoint> values;
  final bool compact;
  final List<PlayerTrackerLoadPoint> loadPoints;
  @override
  State<PlayerTrackerHrChart> createState() => PlayerTrackerHrChartState();
}

class PlayerTrackerHrChartState extends State<PlayerTrackerHrChart> {
  int? selected;
  bool followLive = true;
  double windowSec = 180;
  double? viewEndSec;
  Offset _panDistance = Offset.zero;
  bool _horizontalPan = false;

  double get _maxSec => widget.values.isEmpty ? 1 : math.max(1.0, widget.values.last.sec);
  double get _endSec => followLive ? _maxSec : (viewEndSec ?? _maxSec).clamp(windowSec, _maxSec).toDouble();
  double get _startSec => math.max(0, _endSec - windowSec);

  void _shift(double seconds) {
    setState(() {
      followLive = false;
      viewEndSec = (_endSec + seconds).clamp(windowSec, _maxSec).toDouble();
    });
  }

  void _select(Offset p, Size size) {
    if (widget.values.isEmpty || size.width <= 0) return;
    final target = _startSec + (p.dx.clamp(0.0, size.width) / size.width) * math.max(1.0, _endSec - _startSec);
    var best = 0;
    var delta = double.infinity;
    for (var i=0;i<widget.values.length;i++) { final d=(widget.values[i].sec-target).abs(); if(d<delta){delta=d;best=i;} }
    setState(() => selected = best);
  }

  @override
  Widget build(BuildContext context) {
    final chart = LayoutBuilder(builder: (_, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _select(d.localPosition, size),
        onPanStart: (_) {
          _panDistance = Offset.zero;
          _horizontalPan = false;
        },
        onPanUpdate: (d) {
          _panDistance += d.delta;
          // Не выключаем прямой эфир при обычной вертикальной прокрутке страницы.
          // Режим истории включается только после явного горизонтального свайпа.
          if (!_horizontalPan &&
              _panDistance.dx.abs() > 10 &&
              _panDistance.dx.abs() > _panDistance.dy.abs() * 1.25) {
            _horizontalPan = true;
            if (widget.values.length > 1) {
              setState(() => followLive = false);
            }
          }
          if (_horizontalPan) {
            _shift(-d.delta.dx / math.max(1.0, size.width) * windowSec);
          }
        },
        onPanEnd: (_) {
          _panDistance = Offset.zero;
          _horizontalPan = false;
        },
        onPanCancel: () {
          _panDistance = Offset.zero;
          _horizontalPan = false;
        },
        child: CustomPaint(
          painter: PlayerTrackerHrChartPainter(widget.values, detailed: !widget.compact, selected: selected, minSec: widget.compact ? 0 : _startSec, maxSec: widget.compact ? _maxSec : _endSec, loadPoints: widget.loadPoints),
          size: Size.infinite,
        ),
      );
    });
    if (widget.compact) {
      final historyAvailable = _maxSec > windowSec + 5;
      final progress = !historyAvailable
          ? 1.0
          : ((_endSec - windowSec) / math.max(1.0, _maxSec - windowSec))
              .clamp(0.0, 1.0)
              .toDouble();
      return Column(
        children: [
          Expanded(child: chart),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (_, c) {
              final thumbWidth = historyAvailable
                  ? math.max(34.0, c.maxWidth * .24)
                  : c.maxWidth;
              final left = (c.maxWidth - thumbWidth) * progress;
              return SizedBox(
                height: 7,
                child: Stack(
                  children: [
                    Positioned.fill(
                      top: 2.5,
                      bottom: 2.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE1E1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Positioned(
                      left: left,
                      top: 0,
                      width: thumbWidth,
                      height: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: historyAvailable
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFFCA5A5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(
                Icons.swipe_rounded,
                size: 13,
                color: Color(0xFF98A2B3),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  historyAvailable
                      ? 'Листайте график влево и вправо'
                      : 'История пульса накапливается',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 8.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  minimumSize: const Size(0, 26),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: followLive
                    ? null
                    : () => setState(() {
                          followLive = true;
                          viewEndSec = null;
                        }),
                icon: Icon(
                  Icons.radio_button_checked_rounded,
                  size: 13,
                  color: followLive
                      ? const Color(0xFF00A750)
                      : const Color(0xFFDC2626),
                ),
                label: Text(
                  followLive ? 'Прямой эфир' : 'Продолжить эфир',
                  style: TextStyle(
                    color: followLive
                        ? const Color(0xFF00A750)
                        : const Color(0xFFDC2626),
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Column(children: [
      Expanded(child: chart),
      const SizedBox(height: 4),
      Row(children: [
        IconButton(onPressed: () => _shift(-windowSec * .65), icon: const Icon(Icons.chevron_left_rounded, size: 19), tooltip: 'Раньше'),
        Expanded(child: Text('Интервал ${(_startSec/60).floor()}–${(_endSec/60).ceil()} мин', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 9.6, fontWeight: FontWeight.w700))),
        IconButton(onPressed: () => _shift(windowSec * .65), icon: const Icon(Icons.chevron_right_rounded, size: 19), tooltip: 'Позже'),
        TextButton.icon(
          onPressed: () => setState(() { followLive = true; viewEndSec = null; }),
          icon: Icon(Icons.radio_button_checked_rounded, size: 15, color: followLive ? const Color(0xFF00A750) : const Color(0xFF98A2B3)),
          label: Text(followLive ? 'В прямом эфире' : 'Продолжить прямой эфир'),
        ),
      ]),
    ]);
  }
}

class PlayerTrackerHrChartPainter extends CustomPainter {
  const PlayerTrackerHrChartPainter(this.values, {this.detailed = false, this.selected, this.minSec = 0, this.maxSec, this.loadPoints = const <PlayerTrackerLoadPoint>[]});
  final List<PlayerTrackerHrPoint> values;
  final bool detailed;
  final int? selected;
  final double minSec;
  final double? maxSec;
  final List<PlayerTrackerLoadPoint> loadPoints;
  @override
  void paint(Canvas canvas, Size size) {
    final labelHeight = 15.0;
    final chartHeight = math.max(24.0, size.height - labelHeight);
    final grid = Paint()
      ..color = const Color(0xFFFFE4E4)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Нет данных Polar',
          style: TextStyle(
            color: Color(0xFF98A2B3),
            fontSize: 11.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (chartHeight - tp.height) / 2),
      );
      return;
    }

    final endSec = maxSec ?? values.last.sec;
    final visible =
        values.where((p) => p.sec >= minSec && p.sec <= endSec).toList();
    final plotValues = visible.isEmpty ? values : visible;
    final rangeSec = math.max(1.0, endSec - minSec);

    void drawTimeLabels() {
      for (var i = 0; i <= 4; i++) {
        final sec = minSec + rangeSec * i / 4;
        final totalSeconds = sec.round();
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;
        final label = seconds == 0
            ? '$minutes мин'
            : '$minutes:${seconds.toString().padLeft(2, '0')}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Color(0xFF98A2B3),
              fontSize: 8.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            (size.width * i / 4 - tp.width / 2)
                .clamp(0.0, size.width - tp.width),
            chartHeight + 2,
          ),
        );
      }
    }

    if (plotValues.length == 1) {
      final p = plotValues.first;
      final y = chartHeight * .5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0xFFDC2626).withOpacity(.35)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        Offset(size.width * .5, y),
        5,
        Paint()..color = const Color(0xFFDC2626),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${p.bpm.round()} bpm',
          style: const TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 11.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, math.max(0, y - 22)),
      );
      drawTimeLabels();
      return;
    }

    final minPoint =
        plotValues.reduce((a, b) => a.bpm <= b.bpm ? a : b);
    final maxPoint =
        plotValues.reduce((a, b) => a.bpm >= b.bpm ? a : b);
    final minV = math.max(40.0, minPoint.bpm - 10);
    final maxV = math.min(220.0, maxPoint.bpm + 10);
    final span = math.max(1.0, maxV - minV);

    Offset pos(PlayerTrackerHrPoint p) => Offset(
          size.width *
              ((p.sec - minSec) / rangeSec).clamp(0.0, 1.0),
          chartHeight -
              ((p.bpm - minV) / span).clamp(0.0, 1.0) * chartHeight,
        );

    final path = Path();
    final first = pos(plotValues.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < plotValues.length; i++) {
      final previous = pos(plotValues[i - 1]);
      final current = pos(plotValues[i]);
      final mid = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(previous.dx, previous.dy, mid.dx, mid.dy);
      if (i == plotValues.length - 1) {
        path.quadraticBezierTo(
          current.dx,
          current.dy,
          current.dx,
          current.dy,
        );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFDC2626)
        ..strokeWidth = detailed ? 2.4 : 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );


    void marker(PlayerTrackerHrPoint p, Color color, String text) {
      final o = pos(p);
      canvas.drawCircle(o, detailed ? 4 : 3, Paint()..color = color);
      if (detailed) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: 10.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            (o.dx - tp.width / 2).clamp(0.0, size.width - tp.width),
            (o.dy - 18).clamp(0.0, chartHeight - tp.height),
          ),
        );
      }
    }

    marker(
      minPoint,
      const Color(0xFF2563EB),
      'мин ${minPoint.bpm.round()} · ${(minPoint.sec / 60).floor()} мин',
    );
    marker(
      maxPoint,
      const Color(0xFFDC2626),
      'макс ${maxPoint.bpm.round()} · ${(maxPoint.sec / 60).floor()} мин',
    );

    if (detailed && loadPoints.isNotEmpty) {
      final loadPaint = Paint()..color = const Color(0xFF00A750);
      for (final lp
          in loadPoints.where((p) => p.sec >= minSec && p.sec <= endSec)) {
        final x = size.width *
            ((lp.sec - minSec) / rangeSec).clamp(0.0, 1.0);
        canvas.drawCircle(Offset(x, chartHeight - 8), 3.2, loadPaint);
      }
    }

    if (selected != null && selected! >= 0 && selected! < values.length) {
      final point = values[selected!];
      final o = pos(point);
      canvas.drawLine(
        Offset(o.dx, 0),
        Offset(o.dx, chartHeight),
        Paint()
          ..color = const Color(0xFF6B746E)
          ..strokeWidth = 1,
      );
      marker(
        point,
        const Color(0xFF101828),
        '${point.bpm.round()} · ${(point.sec / 60).floor()}:${((point.sec % 60).round()).toString().padLeft(2, '0')}',
      );
    }
    drawTimeLabels();
  }

  @override
  bool shouldRepaint(covariant PlayerTrackerHrChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.detailed != detailed ||
        oldDelegate.selected != selected ||
        oldDelegate.minSec != minSec ||
        oldDelegate.maxSec != maxSec ||
        oldDelegate.loadPoints != loadPoints;
  }
}
