// lib/presentation/club_workspace/widgets/club_ai_tactical_diagram_card.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/club_ai_tactical_diagram.dart';

class ClubAiTacticalDiagramCard extends StatelessWidget {
  const ClubAiTacticalDiagramCard({
    super.key,
    required this.diagram,
    this.compact = false,
    this.onOpenFullscreen,
    this.onSaveToPlan,
  });

  final ClubAiTacticalDiagram diagram;
  final bool compact;
  final VoidCallback? onOpenFullscreen;
  final VoidCallback? onSaveToPlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF1F4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 18,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: compact ? 30 : 34,
              height: compact ? 30 : 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF3FBF7),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFFD7F0E2)),
              ),
              child: const Icon(Icons.sports_soccer_rounded, color: Color(0xFF067A46), size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                diagram.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF0B0F14),
                  fontSize: compact ? 12.5 : 13.4,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              if (diagram.subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  diagram.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: const Color(0xFF6B7280), fontSize: compact ? 10.4 : 11.0, fontWeight: FontWeight.w600),
                ),
              ],
            ])),
          ]),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: compact ? .74 : .78,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: CustomPaint(
                painter: _ClubAiTacticalFieldPainter(diagram: diagram),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          if (diagram.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3FBF7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD7F0E2)),
              ),
              child: Text(
                diagram.note,
                style: TextStyle(color: const Color(0xFF182230), fontSize: compact ? 10.8 : 11.4, fontWeight: FontWeight.w600, height: 1.32),
              ),
            ),
          ],
          const SizedBox(height: 9),
          Wrap(spacing: 7, runSpacing: 7, children: [
            _DiagramMiniButton(icon: Icons.open_in_full_rounded, text: 'Развернуть', onTap: onOpenFullscreen ?? () {}),
            _DiagramMiniButton(icon: Icons.playlist_add_rounded, text: 'В план', onTap: onSaveToPlan ?? () {}),
            const _DiagramLegend(color: Color(0xFFFFD54A), text: 'пас'),
            const _DiagramLegend(color: Color(0xFF60A5FA), text: 'движение'),
          ]),
        ],
      ),
    );
  }
}

class _DiagramMiniButton extends StatelessWidget {
  const _DiagramMiniButton({required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3FBF7),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFD7F0E2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: const Color(0xFF067A46)),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(color: Color(0xFF067A46), fontSize: 10.2, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _DiagramLegend extends StatelessWidget {
  const _DiagramLegend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFFAFBFC), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFEFF1F4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ClubAiTacticalFieldPainter extends CustomPainter {
  _ClubAiTacticalFieldPainter({required this.diagram});
  final ClubAiTacticalDiagram diagram;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0E8F4D);
    canvas.drawRect(Offset.zero & size, bg);

    final stripe = Paint()..color = Colors.white.withOpacity(.045);
    for (var i = 0; i < 9; i++) {
      if (i.isEven) canvas.drawRect(Rect.fromLTWH(0, size.height / 9 * i, size.width, size.height / 9), stripe);
    }

    final rect = Rect.fromLTWH(12, 12, size.width - 24, size.height - 24);
    final line = Paint()
      ..color = Colors.white.withOpacity(.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;

    canvas.drawRect(rect, line);
    canvas.drawLine(Offset(rect.left, rect.center.dy), Offset(rect.right, rect.center.dy), line);
    canvas.drawCircle(rect.center, rect.width * .13, line);
    canvas.drawCircle(rect.center, 2.4, Paint()..color = Colors.white.withOpacity(.95));

    final boxW = rect.width * .43;
    final boxH = rect.height * .16;
    final sixW = rect.width * .22;
    final sixH = rect.height * .07;
    canvas.drawRect(Rect.fromLTWH(rect.center.dx - boxW / 2, rect.top, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH(rect.center.dx - boxW / 2, rect.bottom - boxH, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH(rect.center.dx - sixW / 2, rect.top, sixW, sixH), line);
    canvas.drawRect(Rect.fromLTWH(rect.center.dx - sixW / 2, rect.bottom - sixH, sixW, sixH), line);

    _drawArrows(canvas, rect);
    _drawPlayers(canvas, rect);
  }

  void _drawArrows(Canvas canvas, Rect rect) {
    for (final a in diagram.arrows) {
      final from = Offset(rect.left + rect.width * a.fromX, rect.top + rect.height * a.fromY);
      final to = Offset(rect.left + rect.width * a.toX, rect.top + rect.height * a.toY);
      final color = a.kind == 'pass'
          ? const Color(0xFFFFD54A)
          : a.kind == 'press'
              ? const Color(0xFFF97316)
              : const Color(0xFF60A5FA);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = a.kind == 'cover' ? 2.0 : 3.0
        ..strokeCap = StrokeCap.round;
      if (a.kind == 'pass') {
        _drawDashed(canvas, from, to, paint);
      } else {
        canvas.drawLine(from, to, paint);
      }
      _drawHead(canvas, from, to, color);
    }
  }

  void _drawPlayers(Canvas canvas, Rect rect) {
    for (final p in diagram.players) {
      final o = Offset(rect.left + rect.width * p.x, rect.top + rect.height * p.y);
      final fillColor = p.team == 'away'
          ? const Color(0xFFEF4444)
          : p.team == 'ball'
              ? Colors.white
              : const Color(0xFF111827);
      final fill = Paint()..color = fillColor;
      final stroke = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final radius = p.team == 'ball' ? 8.5 : 14.0;
      canvas.drawCircle(o, radius, fill);
      canvas.drawCircle(o, radius, stroke);

      final label = p.label.trim();
      if (label.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: p.team == 'ball' ? const Color(0xFF111827) : Colors.white, fontSize: p.team == 'ball' ? 8.4 : 9.4, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 38);
      tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy - tp.height / 2));
    }
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 7.0;
    const gap = 5.0;
    final vector = end - start;
    final total = vector.distance;
    if (total <= 0) return;
    final unit = vector / total;
    var current = 0.0;
    while (current < total) {
      final s = start + unit * current;
      final e = start + unit * math.min(current + dash, total);
      canvas.drawLine(s, e, paint);
      current += dash + gap;
    }
  }

  void _drawHead(Canvas canvas, Offset from, Offset to, Color color) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const size = 9.0;
    final p1 = Offset(to.dx - size * math.cos(angle - math.pi / 6), to.dy - size * math.sin(angle - math.pi / 6));
    final p2 = Offset(to.dx - size * math.cos(angle + math.pi / 6), to.dy - size * math.sin(angle + math.pi / 6));
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ClubAiTacticalFieldPainter oldDelegate) => oldDelegate.diagram != diagram;
}
