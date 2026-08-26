import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SportotekaWorkspaceIconKind {
  home,
  recent,
  favorite,
  teams,
  players,
  trainers,
  matches,
  trainings,
  plans,
  tracker,
  testing,
  calendar,
  documents,
  video,
  reports,
  medical,
  chat,
  parents,
  folder,
  document,
  shortcut,
  note,
  menu,
  back,
  refresh,
  search,
  add,
  grid,
  list,
  chevronRight,
  more,
  close,
  emptyFolder,
  bold,
  italic,
  heading,
  bullets,
  numbered,
  quote,
  save,
}

class SportotekaWorkspaceIcon extends StatelessWidget {
  const SportotekaWorkspaceIcon({
    super.key,
    required this.kind,
    this.size = 24,
    this.color = const Color(0xFF29332D),
    this.accentColor = const Color(0xFF0B8F55),
    this.strokeWidth,
  });

  final SportotekaWorkspaceIconKind kind;
  final double size;
  final Color color;
  final Color accentColor;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SportotekaWorkspaceIconPainter(
          kind: kind,
          color: color,
          accentColor: accentColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

/// Единая папка Sportoteka OS.
///
/// Силуэт намеренно простой: одна цельная форма с мягким скруглённым
/// контуром. Так папка одинаково читается в сетке, списке и карточках
/// игрока/команды/тренера, не превращаясь в отдельную иллюстрацию.
class SportotekaWorkspaceFolderIcon extends StatelessWidget {
  const SportotekaWorkspaceFolderIcon({
    super.key,
    this.size = 64,
    this.color = const Color(0xFF8D9490),
    this.fillColor = const Color(0xFFF2F3F2),
    this.accentColor = const Color(0xFF0B8F55),
    this.showBrandDots = false,
  });

  final double size;
  final Color color;
  final Color fillColor;
  final Color accentColor;
  final bool showBrandDots;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SportotekaWorkspaceFolderPainter(
          color: color,
          fillColor: fillColor,
          accentColor: accentColor,
          showBrandDots: showBrandDots,
        ),
      ),
    );
  }
}

class _SportotekaWorkspaceFolderPainter extends CustomPainter {
  const _SportotekaWorkspaceFolderPainter({
    required this.color,
    required this.fillColor,
    required this.accentColor,
    required this.showBrandDots,
  });

  final Color color;
  final Color fillColor;
  final Color accentColor;
  final bool showBrandDots;

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = math.min(size.width, size.height);
    final folder = Path()
      ..moveTo(size.width * .16, size.height * .30)
      ..quadraticBezierTo(
        size.width * .16,
        size.height * .25,
        size.width * .22,
        size.height * .25,
      )
      ..lineTo(size.width * .41, size.height * .25)
      ..quadraticBezierTo(
        size.width * .45,
        size.height * .25,
        size.width * .48,
        size.height * .29,
      )
      ..lineTo(size.width * .53, size.height * .35)
      ..lineTo(size.width * .79, size.height * .35)
      ..quadraticBezierTo(
        size.width * .85,
        size.height * .35,
        size.width * .85,
        size.height * .41,
      )
      ..lineTo(size.width * .85, size.height * .70)
      ..quadraticBezierTo(
        size.width * .85,
        size.height * .76,
        size.width * .79,
        size.height * .76,
      )
      ..lineTo(size.width * .21, size.height * .76)
      ..quadraticBezierTo(
        size.width * .15,
        size.height * .76,
        size.width * .15,
        size.height * .70,
      )
      ..lineTo(size.width * .15, size.height * .31)
      ..close();

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = (shortestSide * .072).clamp(2.2, 4.6).toDouble()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(folder, fill);
    canvas.drawPath(folder, stroke);

    if (!showBrandDots) return;
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor;
    final radius = (shortestSide * .014).clamp(.75, 1.25).toDouble();
    final y = size.height * .64;
    for (final x in <double>[.68, .735, .79]) {
      canvas.drawCircle(Offset(size.width * x, y), radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SportotekaWorkspaceFolderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.showBrandDots != showBrandDots;
  }
}

class _SportotekaWorkspaceIconPainter extends CustomPainter {
  const _SportotekaWorkspaceIconPainter({
    required this.kind,
    required this.color,
    required this.accentColor,
    required this.strokeWidth,
  });

  final SportotekaWorkspaceIconKind kind;
  final Color color;
  final Color accentColor;
  final double? strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final main = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth ?? 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accent = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth ?? 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accentFill = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    switch (kind) {
      case SportotekaWorkspaceIconKind.home:
        _home(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.recent:
        _recent(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.favorite:
        _star(canvas, accent);
        break;
      case SportotekaWorkspaceIconKind.teams:
        _moduleFolder(canvas, main, accent, _teamGlyph);
        break;
      case SportotekaWorkspaceIconKind.players:
        _moduleFolder(canvas, main, accent, _playersGlyph);
        break;
      case SportotekaWorkspaceIconKind.trainers:
        _moduleFolder(canvas, main, accent, _trainerGlyph);
        break;
      case SportotekaWorkspaceIconKind.matches:
        _moduleFolder(canvas, main, accent, _matchGlyph);
        break;
      case SportotekaWorkspaceIconKind.trainings:
        _moduleFolder(canvas, main, accent, _trainingGlyph);
        break;
      case SportotekaWorkspaceIconKind.plans:
        _moduleFolder(canvas, main, accent, _plansGlyph);
        break;
      case SportotekaWorkspaceIconKind.tracker:
        _moduleFolder(canvas, main, accent, _trackerGlyph);
        break;
      case SportotekaWorkspaceIconKind.testing:
        _moduleFolder(canvas, main, accent, _testingGlyph);
        break;
      case SportotekaWorkspaceIconKind.calendar:
        _moduleFolder(canvas, main, accent, _calendarGlyph);
        break;
      case SportotekaWorkspaceIconKind.documents:
        _moduleFolder(canvas, main, accent, _documentGlyph);
        break;
      case SportotekaWorkspaceIconKind.video:
        _moduleFolder(canvas, main, accent, _videoGlyph);
        break;
      case SportotekaWorkspaceIconKind.reports:
        _moduleFolder(canvas, main, accent, _reportsGlyph);
        break;
      case SportotekaWorkspaceIconKind.medical:
        _moduleFolder(canvas, main, accent, _medicalGlyph);
        break;
      case SportotekaWorkspaceIconKind.chat:
        _moduleFolder(canvas, main, accent, _chatGlyph);
        break;
      case SportotekaWorkspaceIconKind.parents:
        _moduleFolder(canvas, main, accent, _parentsGlyph);
        break;
      case SportotekaWorkspaceIconKind.folder:
        _folder(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.document:
        _page(canvas, main, accent, note: false);
        break;
      case SportotekaWorkspaceIconKind.note:
        _page(canvas, main, accent, note: true);
        break;
      case SportotekaWorkspaceIconKind.shortcut:
        _shortcut(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.menu:
        _menu(canvas, main, accentFill);
        break;
      case SportotekaWorkspaceIconKind.back:
        _back(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.refresh:
        _refresh(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.search:
        _search(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.add:
        _plus(canvas, accent);
        break;
      case SportotekaWorkspaceIconKind.grid:
        _grid(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.list:
        _list(canvas, main, accentFill);
        break;
      case SportotekaWorkspaceIconKind.chevronRight:
        _chevron(canvas, main);
        break;
      case SportotekaWorkspaceIconKind.more:
        _more(canvas, accentFill);
        break;
      case SportotekaWorkspaceIconKind.close:
        _close(canvas, main);
        break;
      case SportotekaWorkspaceIconKind.emptyFolder:
        _emptyFolder(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.bold:
        _bold(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.italic:
        _italic(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.heading:
        _heading(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.bullets:
        _bullets(canvas, main, accentFill);
        break;
      case SportotekaWorkspaceIconKind.numbered:
        _numbered(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.quote:
        _quote(canvas, main, accent);
        break;
      case SportotekaWorkspaceIconKind.save:
        _save(canvas, main, accent);
        break;
    }

    canvas.restore();
  }

  void _moduleFolder(
    Canvas canvas,
    Paint main,
    Paint accent,
    void Function(Canvas, Paint, Paint) glyph,
  ) {
    final neutral = Paint()
      ..color = const Color(0xFF7F8782)
      ..style = PaintingStyle.stroke
      ..strokeWidth = main.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _folder(canvas, neutral, accent);
  }

  void _folder(Canvas canvas, Paint main, Paint accent, {bool compact = false}) {
    final path = Path()
      ..moveTo(3.2, 7.2)
      ..quadraticBezierTo(3.2, 5.6, 4.8, 5.6)
      ..lineTo(9.1, 5.6)
      ..lineTo(10.9, 7.4)
      ..lineTo(19.2, 7.4)
      ..quadraticBezierTo(20.8, 7.4, 20.8, 9)
      ..lineTo(20.8, 17.9)
      ..quadraticBezierTo(20.8, 19.5, 19.2, 19.5)
      ..lineTo(4.8, 19.5)
      ..quadraticBezierTo(3.2, 19.5, 3.2, 17.9)
      ..close();
    canvas.drawPath(path, main);
    if (!compact) {
      final dot = Paint()
        ..style = PaintingStyle.fill
        ..color = accent.color;
      for (final x in const <double>[15.2, 17.3, 19.4]) {
        canvas.drawCircle(Offset(x, 16.7), .72, dot);
      }
    }
  }

  void _emptyFolder(Canvas canvas, Paint main, Paint accent) {
    final back = Path()
      ..moveTo(3.2, 8)
      ..lineTo(3.2, 6.7)
      ..quadraticBezierTo(3.2, 5.4, 4.7, 5.4)
      ..lineTo(9, 5.4)
      ..lineTo(10.7, 7.1)
      ..lineTo(19.2, 7.1)
      ..quadraticBezierTo(20.7, 7.1, 20.7, 8.6)
      ..lineTo(20.7, 10.2);
    canvas.drawPath(back, main);
    final front = Path()
      ..moveTo(4.0, 10.1)
      ..lineTo(20.3, 10.1)
      ..lineTo(18.5, 18.5)
      ..quadraticBezierTo(18.2, 19.6, 16.9, 19.6)
      ..lineTo(5.4, 19.6)
      ..quadraticBezierTo(4.1, 19.6, 3.8, 18.3)
      ..lineTo(2.9, 11.5)
      ..quadraticBezierTo(2.7, 10.1, 4.0, 10.1);
    canvas.drawPath(front, accent);
  }

  void _teamGlyph(Canvas c, Paint main, Paint accent) {
    _circle(c, const Offset(12, 12.2), 1.2, accent);
    _circle(c, const Offset(8.4, 15.1), .9, main);
    _circle(c, const Offset(15.6, 15.1), .9, main);
    c.drawLine(const Offset(12, 13.4), const Offset(12, 15.0), accent);
    c.drawLine(const Offset(12, 14.4), const Offset(8.4, 15.1), main);
    c.drawLine(const Offset(12, 14.4), const Offset(15.6, 15.1), main);
  }

  void _playersGlyph(Canvas c, Paint main, Paint accent) {
    _circle(c, const Offset(10.1, 12.3), 1.35, accent);
    _circle(c, const Offset(14.5, 12.9), 1.05, main);
    c.drawArc(const Rect.fromLTWH(7.8, 14.3, 4.7, 3.4), math.pi, math.pi, false, accent);
    c.drawArc(const Rect.fromLTWH(12.5, 14.7, 4.0, 2.8), math.pi, math.pi, false, main);
  }

  void _trainerGlyph(Canvas c, Paint main, Paint accent) {
    final shield = Path()
      ..moveTo(12, 11)
      ..lineTo(16.3, 12.1)
      ..lineTo(15.8, 16.3)
      ..quadraticBezierTo(12, 18.4, 8.2, 16.3)
      ..lineTo(7.7, 12.1)
      ..close();
    c.drawPath(shield, main);
    c.drawLine(const Offset(10.1, 14.4), const Offset(11.5, 15.7), accent);
    c.drawLine(const Offset(11.5, 15.7), const Offset(14.2, 12.9), accent);
  }

  void _matchGlyph(Canvas c, Paint main, Paint accent) {
    _circle(c, const Offset(12, 14.4), 3.25, main);
    final pent = Path()
      ..moveTo(12, 12.4)
      ..lineTo(13.7, 13.6)
      ..lineTo(13.0, 15.6)
      ..lineTo(11.0, 15.6)
      ..lineTo(10.3, 13.6)
      ..close();
    c.drawPath(pent, accent);
    c.drawLine(const Offset(12, 11.15), const Offset(12, 12.4), main);
    c.drawLine(const Offset(9.1, 13.2), const Offset(10.3, 13.6), main);
    c.drawLine(const Offset(14.9, 13.2), const Offset(13.7, 13.6), main);
  }

  void _trainingGlyph(Canvas c, Paint main, Paint accent) {
    final cone = Path()
      ..moveTo(12, 11.0)
      ..lineTo(15.2, 17.0)
      ..lineTo(8.8, 17.0)
      ..close();
    c.drawPath(cone, main);
    c.drawLine(const Offset(10.1, 14.4), const Offset(13.9, 14.4), accent);
    c.drawLine(const Offset(8.2, 18.1), const Offset(15.8, 18.1), accent);
  }

  void _plansGlyph(Canvas c, Paint main, Paint accent) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8.4, 11.2, 7.2, 6.1), const Radius.circular(1.1)), main);
    c.drawLine(const Offset(10, 13.1), const Offset(14, 13.1), accent);
    c.drawLine(const Offset(10, 15.0), const Offset(14.7, 15.0), main);
    c.drawLine(const Offset(10, 16.6), const Offset(12.9, 16.6), main);
  }

  void _trackerGlyph(Canvas c, Paint main, Paint accent) {
    _circle(c, const Offset(12, 14.5), 3.4, main);
    _circle(c, const Offset(12, 14.5), 1.7, main);
    c.drawLine(const Offset(12, 14.5), const Offset(14.7, 12.7), accent);
    _circle(c, const Offset(14.7, 12.7), .45, accent);
  }

  void _testingGlyph(Canvas c, Paint main, Paint accent) {
    c.drawLine(const Offset(10.2, 11.1), const Offset(13.8, 11.1), main);
    c.drawLine(const Offset(11.0, 11.1), const Offset(11.0, 13.3), main);
    c.drawLine(const Offset(13.0, 11.1), const Offset(13.0, 13.3), main);
    final flask = Path()
      ..moveTo(11, 13.3)
      ..lineTo(8.9, 17.1)
      ..quadraticBezierTo(8.5, 18.0, 9.5, 18.0)
      ..lineTo(14.5, 18.0)
      ..quadraticBezierTo(15.5, 18.0, 15.1, 17.1)
      ..lineTo(13.0, 13.3);
    c.drawPath(flask, main);
    c.drawLine(const Offset(9.8, 16.2), const Offset(14.2, 16.2), accent);
  }

  void _calendarGlyph(Canvas c, Paint main, Paint accent) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8.3, 11.2, 7.4, 6.5), const Radius.circular(1.1)), main);
    c.drawLine(const Offset(8.5, 13.4), const Offset(15.5, 13.4), accent);
    c.drawLine(const Offset(10.1, 10.6), const Offset(10.1, 12.2), main);
    c.drawLine(const Offset(13.9, 10.6), const Offset(13.9, 12.2), main);
    _circle(c, const Offset(10.5, 15.3), .35, accent);
    _circle(c, const Offset(13.5, 15.3), .35, accent);
  }

  void _documentGlyph(Canvas c, Paint main, Paint accent) {
    _pageGlyph(c, main, accent);
  }

  void _videoGlyph(Canvas c, Paint main, Paint accent) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8.2, 11.5, 7.6, 6.0), const Radius.circular(1.2)), main);
    final play = Path()
      ..moveTo(11.2, 13.2)
      ..lineTo(14.2, 14.5)
      ..lineTo(11.2, 15.8)
      ..close();
    c.drawPath(play, accent);
  }

  void _reportsGlyph(Canvas c, Paint main, Paint accent) {
    c.drawLine(const Offset(8.2, 17.7), const Offset(16.1, 17.7), main);
    c.drawLine(const Offset(9.1, 17.2), const Offset(9.1, 14.8), main);
    c.drawLine(const Offset(12.0, 17.2), const Offset(12.0, 12.4), accent);
    c.drawLine(const Offset(14.9, 17.2), const Offset(14.9, 13.7), main);
  }

  void _medicalGlyph(Canvas c, Paint main, Paint accent) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8.4, 11.4, 7.2, 6.2), const Radius.circular(1.4)), main);
    c.drawLine(const Offset(12, 12.8), const Offset(12, 16.3), accent);
    c.drawLine(const Offset(10.3, 14.55), const Offset(13.7, 14.55), accent);
  }

  void _chatGlyph(Canvas c, Paint main, Paint accent) {
    final bubble = Path()
      ..moveTo(8.5, 11.7)
      ..quadraticBezierTo(8.5, 10.9, 9.4, 10.9)
      ..lineTo(14.7, 10.9)
      ..quadraticBezierTo(15.6, 10.9, 15.6, 11.8)
      ..lineTo(15.6, 15.5)
      ..quadraticBezierTo(15.6, 16.4, 14.7, 16.4)
      ..lineTo(11.1, 16.4)
      ..lineTo(9.2, 18.0)
      ..lineTo(9.6, 16.4)
      ..lineTo(9.4, 16.4)
      ..quadraticBezierTo(8.5, 16.4, 8.5, 15.5)
      ..close();
    c.drawPath(bubble, main);
    c.drawLine(const Offset(10.5, 13.3), const Offset(13.7, 13.3), accent);
  }

  void _parentsGlyph(Canvas c, Paint main, Paint accent) {
    _circle(c, const Offset(10.4, 12.6), 1.15, accent);
    _circle(c, const Offset(14.1, 13.2), .9, main);
    c.drawArc(const Rect.fromLTWH(8.2, 14.4, 4.4, 3.1), math.pi, math.pi, false, accent);
    c.drawArc(const Rect.fromLTWH(12.4, 14.8, 3.4, 2.4), math.pi, math.pi, false, main);
  }

  void _pageGlyph(Canvas c, Paint main, Paint accent) {
    final path = Path()
      ..moveTo(9.2, 10.9)
      ..lineTo(13.7, 10.9)
      ..lineTo(15.8, 13)
      ..lineTo(15.8, 17.7)
      ..lineTo(9.2, 17.7)
      ..close();
    c.drawPath(path, main);
    c.drawLine(const Offset(13.7, 10.9), const Offset(13.7, 13), main);
    c.drawLine(const Offset(13.7, 13), const Offset(15.8, 13), main);
    c.drawLine(const Offset(10.6, 14.5), const Offset(14.3, 14.5), accent);
    c.drawLine(const Offset(10.6, 16.1), const Offset(13.5, 16.1), main);
  }

  void _page(Canvas c, Paint main, Paint accent, {required bool note}) {
    final path = Path()
      ..moveTo(6.3, 3.5)
      ..lineTo(14.5, 3.5)
      ..lineTo(18.4, 7.4)
      ..lineTo(18.4, 20.4)
      ..lineTo(6.3, 20.4)
      ..close();
    c.drawPath(path, main);
    c.drawLine(const Offset(14.5, 3.5), const Offset(14.5, 7.4), main);
    c.drawLine(const Offset(14.5, 7.4), const Offset(18.4, 7.4), main);
    c.drawLine(const Offset(8.8, 11.1), const Offset(15.9, 11.1), accent);
    c.drawLine(const Offset(8.8, 14.1), const Offset(15.1, 14.1), main);
    c.drawLine(const Offset(8.8, 17.1), Offset(note ? 13.3 : 14.2, 17.1), main);
  }

  void _shortcut(Canvas c, Paint main, Paint accent) {
    c.drawLine(const Offset(5.5, 17.8), const Offset(17.7, 5.6), main);
    c.drawLine(const Offset(12.2, 5.6), const Offset(17.7, 5.6), accent);
    c.drawLine(const Offset(17.7, 5.6), const Offset(17.7, 11.1), accent);
    c.drawLine(const Offset(5.5, 17.8), const Offset(10.2, 17.8), main);
  }

  void _home(Canvas c, Paint main, Paint accent) {
    final roof = Path()
      ..moveTo(3.8, 11.5)
      ..lineTo(12, 4.7)
      ..lineTo(20.2, 11.5);
    c.drawPath(roof, accent);
    final house = Path()
      ..moveTo(6.0, 10.1)
      ..lineTo(6.0, 19.0)
      ..lineTo(18.0, 19.0)
      ..lineTo(18.0, 10.1);
    c.drawPath(house, main);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(10.1, 13.0, 3.8, 6.0), const Radius.circular(.8)), main);
  }

  void _recent(Canvas c, Paint main, Paint accent) {
    _circle(c, const Offset(12.3, 12.2), 7.2, main);
    c.drawLine(const Offset(12.3, 12.2), const Offset(12.3, 8.0), accent);
    c.drawLine(const Offset(12.3, 12.2), const Offset(15.7, 14.1), accent);
    c.drawLine(const Offset(4.3, 8.4), const Offset(3.5, 5.8), main);
    c.drawLine(const Offset(3.5, 5.8), const Offset(6.2, 6.0), main);
  }

  void _star(Canvas c, Paint p) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? 7.4 : 3.4;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(12 + math.cos(a) * r, 12 + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    c.drawPath(path, p);
  }

  void _menu(Canvas c, Paint main, Paint accentFill) {
    c.drawLine(const Offset(5, 7), const Offset(19, 7), main);
    c.drawLine(const Offset(5, 12), const Offset(16, 12), main);
    c.drawLine(const Offset(5, 17), const Offset(19, 17), main);
    c.drawCircle(const Offset(19, 12), 1.1, accentFill);
  }

  void _back(Canvas c, Paint main, Paint accent) {
    c.drawLine(const Offset(19, 12), const Offset(5.5, 12), main);
    c.drawLine(const Offset(5.5, 12), const Offset(10.1, 7.4), accent);
    c.drawLine(const Offset(5.5, 12), const Offset(10.1, 16.6), accent);
  }

  void _refresh(Canvas c, Paint main, Paint accent) {
    c.drawArc(const Rect.fromLTWH(5, 5, 14, 14), -.2, math.pi * 1.55, false, main);
    c.drawLine(const Offset(18.6, 5.5), const Offset(18.9, 10.0), accent);
    c.drawLine(const Offset(18.9, 10.0), const Offset(14.6, 9.2), accent);
  }

  void _search(Canvas c, Paint main, Paint accent) {
    _circle(c, const Offset(10.6, 10.6), 5.4, main);
    c.drawLine(const Offset(14.5, 14.5), const Offset(19.2, 19.2), accent);
  }

  void _plus(Canvas c, Paint accent) {
    c.drawLine(const Offset(12, 5), const Offset(12, 19), accent);
    c.drawLine(const Offset(5, 12), const Offset(19, 12), accent);
  }

  void _grid(Canvas c, Paint main, Paint accent) {
    for (final r in <Rect>[
      const Rect.fromLTWH(5, 5, 5.2, 5.2),
      const Rect.fromLTWH(13.8, 5, 5.2, 5.2),
      const Rect.fromLTWH(5, 13.8, 5.2, 5.2),
      const Rect.fromLTWH(13.8, 13.8, 5.2, 5.2),
    ]) {
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1.2)), r.left > 10 && r.top < 10 ? accent : main);
    }
  }

  void _list(Canvas c, Paint main, Paint accentFill) {
    for (final y in <double>[6.5, 12, 17.5]) {
      c.drawCircle(Offset(5.4, y), .9, accentFill);
      c.drawLine(Offset(8.5, y), Offset(19, y), main);
    }
  }

  void _chevron(Canvas c, Paint main) {
    c.drawLine(const Offset(9, 6.5), const Offset(14.5, 12), main);
    c.drawLine(const Offset(14.5, 12), const Offset(9, 17.5), main);
  }

  void _more(Canvas c, Paint fill) {
    for (final x in <double>[6.5, 12, 17.5]) {
      c.drawCircle(Offset(x, 12), 1.25, fill);
    }
  }

  void _close(Canvas c, Paint main) {
    c.drawLine(const Offset(6.5, 6.5), const Offset(17.5, 17.5), main);
    c.drawLine(const Offset(17.5, 6.5), const Offset(6.5, 17.5), main);
  }

  void _bold(Canvas c, Paint main, Paint accent) {
    final p = Path()
      ..moveTo(8.2, 5.0)
      ..lineTo(8.2, 19.0)
      ..lineTo(13.1, 19.0)
      ..quadraticBezierTo(17.2, 19.0, 17.2, 15.2)
      ..quadraticBezierTo(17.2, 12.7, 14.6, 12.2)
      ..quadraticBezierTo(16.5, 11.4, 16.5, 8.8)
      ..quadraticBezierTo(16.5, 5.0, 12.8, 5.0)
      ..close();
    c.drawPath(p, main);
    c.drawLine(const Offset(8.4, 12.1), const Offset(13.5, 12.1), accent);
  }

  void _italic(Canvas c, Paint main, Paint accent) {
    c.drawLine(const Offset(10.0, 5.3), const Offset(17.1, 5.3), main);
    c.drawLine(const Offset(6.9, 18.7), const Offset(14.0, 18.7), main);
    c.drawLine(const Offset(13.9, 5.3), const Offset(10.1, 18.7), accent);
  }

  void _heading(Canvas c, Paint main, Paint accent) {
    c.drawLine(const Offset(6.0, 6.0), const Offset(6.0, 18.0), main);
    c.drawLine(const Offset(13.0, 6.0), const Offset(13.0, 18.0), main);
    c.drawLine(const Offset(6.0, 12.0), const Offset(13.0, 12.0), accent);
    c.drawLine(const Offset(16.2, 9.0), const Offset(18.6, 7.4), accent);
    c.drawLine(const Offset(18.6, 7.4), const Offset(18.6, 16.6), accent);
  }

  void _bullets(Canvas c, Paint main, Paint fill) {
    for (final y in <double>[7.0, 12.0, 17.0]) {
      c.drawCircle(Offset(5.5, y), 1.0, fill);
      c.drawLine(Offset(9.0, y), Offset(19.0, y), main);
    }
  }

  void _numbered(Canvas c, Paint main, Paint accent) {
    c.drawLine(const Offset(8.8, 7.0), const Offset(19.0, 7.0), main);
    c.drawLine(const Offset(8.8, 12.0), const Offset(19.0, 12.0), main);
    c.drawLine(const Offset(8.8, 17.0), const Offset(19.0, 17.0), main);
    c.drawLine(const Offset(4.7, 5.9), const Offset(5.8, 5.2), accent);
    c.drawLine(const Offset(5.8, 5.2), const Offset(5.8, 8.5), accent);
    c.drawArc(const Rect.fromLTWH(4.2, 10.0, 3.0, 2.4), math.pi, math.pi, false, accent);
    c.drawLine(const Offset(7.2, 11.2), const Offset(4.4, 13.8), accent);
    c.drawLine(const Offset(4.4, 13.8), const Offset(7.2, 13.8), accent);
    c.drawArc(const Rect.fromLTWH(4.3, 15.2, 2.8, 2.3), -math.pi / 2, math.pi, false, accent);
    c.drawArc(const Rect.fromLTWH(4.3, 16.6, 2.8, 2.3), -math.pi / 2, math.pi, false, accent);
  }

  void _quote(Canvas c, Paint main, Paint accent) {
    final left = RRect.fromRectAndRadius(const Rect.fromLTWH(5.3, 6.8, 5.0, 6.2), const Radius.circular(1.4));
    final right = RRect.fromRectAndRadius(const Rect.fromLTWH(13.7, 6.8, 5.0, 6.2), const Radius.circular(1.4));
    c.drawRRect(left, main);
    c.drawRRect(right, main);
    c.drawLine(const Offset(9.1, 12.3), const Offset(6.9, 17.0), accent);
    c.drawLine(const Offset(17.5, 12.3), const Offset(15.3, 17.0), accent);
  }

  void _save(Canvas c, Paint main, Paint accent) {
    final p = Path()
      ..moveTo(5.0, 4.8)
      ..lineTo(16.8, 4.8)
      ..lineTo(19.2, 7.2)
      ..lineTo(19.2, 19.2)
      ..lineTo(4.8, 19.2)
      ..close();
    c.drawPath(p, main);
    c.drawRect(const Rect.fromLTWH(8.0, 5.0, 7.2, 4.4), main);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8.0, 13.1, 8.0, 4.8), const Radius.circular(1.0)), accent);
  }

  void _circle(Canvas c, Offset center, double radius, Paint p) {
    c.drawCircle(center, radius, p);
  }

  @override
  bool shouldRepaint(covariant _SportotekaWorkspaceIconPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.color != color ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

SportotekaWorkspaceIconKind sportotekaWorkspaceIconForModuleKey(String key) {
  switch (key) {
    case 'teams':
      return SportotekaWorkspaceIconKind.teams;
    case 'players':
      return SportotekaWorkspaceIconKind.players;
    case 'trainers':
      return SportotekaWorkspaceIconKind.trainers;
    case 'matches':
      return SportotekaWorkspaceIconKind.matches;
    case 'trainings':
      return SportotekaWorkspaceIconKind.trainings;
    case 'plans':
      return SportotekaWorkspaceIconKind.plans;
    case 'tracker':
      return SportotekaWorkspaceIconKind.tracker;
    case 'testing':
      return SportotekaWorkspaceIconKind.testing;
    case 'calendar':
      return SportotekaWorkspaceIconKind.calendar;
    case 'documents':
      return SportotekaWorkspaceIconKind.documents;
    case 'video':
      return SportotekaWorkspaceIconKind.video;
    case 'reports':
      return SportotekaWorkspaceIconKind.reports;
    case 'medical':
      return SportotekaWorkspaceIconKind.medical;
    case 'chat':
      return SportotekaWorkspaceIconKind.chat;
    case 'parents':
      return SportotekaWorkspaceIconKind.parents;
    default:
      return SportotekaWorkspaceIconKind.folder;
  }
}
