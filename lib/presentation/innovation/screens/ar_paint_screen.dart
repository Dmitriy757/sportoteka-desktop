// lib/presentation/innovation/screens/ar_paint_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sportoteka/data/innovation_api.dart';

class ArPaintScreen extends StatefulWidget {
  const ArPaintScreen({super.key});
  @override
  State<ArPaintScreen> createState() => _ArPaintScreenState();
}

enum DrawMode { freehand, line, arrow, circle }

class _ArPaintScreenState extends State<ArPaintScreen> {
  CameraController? _controller;
  bool _initialized = false;

  final _paths = <_PaintPath>[];
  final _redo = <_PaintPath>[];

  Color _color = Colors.cyanAccent;
  double _stroke = 6;
  bool _targets = true;
  DrawMode _mode = DrawMode.freehand;

  Offset? _lineStart;
  Offset? _last;

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      _controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      setState(() => _initialized = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Камера недоступна: $e')));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _startStroke(Offset p) {
    _lineStart = p;
    if (_mode == DrawMode.freehand) {
      final path = _PaintPath(color: _color, stroke: _stroke)..points.add(p);
      setState(() { _paths.add(path); _redo.clear(); });
    }
  }

  void _extendStroke(Offset p) {
    _last = p;
    if (_mode == DrawMode.freehand) {
      setState(() => _paths.last.points.add(p));
    }
  }

  void _endStroke() {
    if (_mode == DrawMode.freehand) return;
    if (_lineStart == null || _last == null) return;
    final pts = _shapeFrom(_mode, _lineStart!, _last!);
    final path = _PaintPath(color: _color, stroke: _stroke)..points.addAll(pts);
    setState(() {
      _paths.add(path);
      _lineStart = null;
      _redo.clear();
    });
  }

  List<Offset> _shapeFrom(DrawMode m, Offset a, Offset b) {
    switch (m) {
      case DrawMode.line:
        return [a, b];
      case DrawMode.arrow:
        final list = <Offset>[a, b];
        final v = (b - a);
        final len = v.distance;
        if (len > 0) {
          final dir = Offset(v.dx / len, v.dy / len);
          final orth = Offset(-dir.dy, dir.dx);
          final tip1 = b - dir * 20 + orth * 10;
          final tip2 = b - dir * 20 - orth * 10;
          list..add(b)..add(tip1)..add(b)..add(tip2);
        }
        return list;
      case DrawMode.circle:
        final c = (a + b) / 2;
        final r = (b - c).distance;
        final pts = <Offset>[];
        for (int i = 0; i <= 36; i++) {
          final t = 2 * math.pi * i / 36;
          pts.add(Offset(c.dx + r * math.cos(t), c.dy + r * math.sin(t)));
        }
        return pts;
      default:
        return [a, b];
    }
  }

  void _undo() {
    if (_paths.isNotEmpty) setState(() => _redo.add(_paths.removeLast()));
  }

  void _redoAct() {
    if (_redo.isNotEmpty) setState(() => _paths.add(_redo.removeLast()));
  }

  Future<File> _renderOverlayPng({Size? forceSize}) async {
    final recorder = ui.PictureRecorder();
    final size = forceSize ?? MediaQuery.of(context).size;
    final canvas = Canvas(recorder, Offset.zero & size);

    if (_targets) _drawTargets(canvas, size);
    _drawPaths(canvas, size: size);

    final pic = recorder.endRecording();
    final img = await pic.toImage(size.width.toInt(), size.height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/overlay_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<File?> _saveComposite() async {
    if (!_initialized || _controller == null) return null;
    final shot = await _controller!.takePicture();
    final bytes = await File(shot.path).readAsBytes();
    final camImage = await decodeImageFromList(bytes);

    final overlay = await _renderOverlayPng(forceSize: Size(camImage.width.toDouble(), camImage.height.toDouble()));

    // Сливаем на канве
    final recorder = ui.PictureRecorder();
    final size = Size(camImage.width.toDouble(), camImage.height.toDouble());
    final canvas = Canvas(recorder, Offset.zero & size);
    canvas.drawImage(camImage, Offset.zero, Paint());

    final overlayBytes = await overlay.readAsBytes();
    final overlayImg = await decodeImageFromList(overlayBytes);
    canvas.drawImage(overlayImg, Offset.zero, Paint());

    final pic = recorder.endRecording();
    final out = await pic.toImage(camImage.width, camImage.height);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/composite_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _upload({required bool withComposite}) async {
    try {
      final overlay = await _renderOverlayPng();
      File? composite;
      if (withComposite) {
        composite = await _saveComposite();
      }
      final id = await InnovationApi.saveArOverlay(
        overlayPath: overlay.path,
        compositePath: composite?.path,
        notes: 'AR Paint overlay',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AR-слой сохранён (ID $id)')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = (_initialized && _controller != null)
        ? CameraPreview(_controller!)
        : const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('AR-Paint цели'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Режим рисования',
            icon: const Icon(Icons.brush),
            onSelected: (v) {
              setState(() {
                _mode = {
                  'free': DrawMode.freehand,
                  'line': DrawMode.line,
                  'arrow': DrawMode.arrow,
                  'circle': DrawMode.circle,
                }[v]!;
              });
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'free', child: Text('Кисть')),
              PopupMenuItem(value: 'line', child: Text('Линия')),
              PopupMenuItem(value: 'arrow', child: Text('Стрелка')),
              PopupMenuItem(value: 'circle', child: Text('Круг')),
            ],
          ),
          IconButton(icon: const Icon(Icons.undo), onPressed: _undo),
          IconButton(icon: const Icon(Icons.redo), onPressed: _redoAct),
          PopupMenuButton<String>(
            icon: const Icon(Icons.cloud_upload),
            onSelected: (v) => _upload(withComposite: v == 'composite'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'overlay', child: Text('Загрузить overlay.png')),
              PopupMenuItem(value: 'composite', child: Text('Загрузить фото+overlay')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: preview),
          Positioned.fill(
            child: GestureDetector(
              onPanStart: (d) => _startStroke(d.localPosition),
              onPanUpdate: (d) => _extendStroke(d.localPosition),
              onPanEnd: (_) => _endStroke(),
              child: CustomPaint(
                painter: _PaintLayer(paths: _paths, showTargets: _targets),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            left: 12, bottom: 16,
            child: _Toolbar(
              color: _color,
              stroke: _stroke,
              targets: _targets,
              onColor: (c) => setState(() => _color = c),
              onStroke: (s) => setState(() => _stroke = s),
              onToggleTargets: () => setState(() => _targets = !_targets),
            ),
          ),
          const Positioned(
            right: 12, bottom: 18,
            child: Text('🇧🇾 Разработано в РБ — Sportoteka', style: TextStyle(color: Colors.white70)),
          )
        ],
      ),
    );
  }

  void _drawTargets(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.deepOrangeAccent.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final cx = size.width * 0.7, cy = size.height * 0.4;
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(cx, cy), 18.0 + i * 10.0, p);
    }
    final guide = Paint()..color = Colors.white.withOpacity(0.35)..strokeWidth = 2;
    canvas.drawLine(Offset(size.width * 0.1, size.height * 0.6), Offset(size.width * 0.9, size.height * 0.6), guide);
    canvas.drawLine(Offset(size.width * 0.1, size.height * 0.75), Offset(size.width * 0.9, size.height * 0.75), guide);
  }

  void _drawPaths(Canvas canvas, {Size? size}) {
    for (final path in _paths) {
      final paint = Paint()
        ..color = path.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = path.stroke;
      for (int i = 0; i < path.points.length - 1; i++) {
        final a = path.points[i], b = path.points[i + 1];
        canvas.drawLine(a, b, paint);
      }
    }
  }
}

class _PaintPath {
  final List<Offset> points = [];
  final Color color;
  final double stroke;
  _PaintPath({required this.color, required this.stroke});
}

class _PaintLayer extends CustomPainter {
  final List<_PaintPath> paths;
  final bool showTargets;
  _PaintLayer({required this.paths, required this.showTargets});

  @override
  void paint(Canvas canvas, Size size) {
    if (showTargets) {
      final p = Paint()
        ..color = Colors.deepOrangeAccent.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final cx = size.width * 0.7, cy = size.height * 0.4;
      for (int i = 0; i < 3; i++) {
        canvas.drawCircle(Offset(cx, cy), 18.0 + i * 10.0, p);
      }
      final guide = Paint()..color = Colors.white.withOpacity(0.35)..strokeWidth = 2;
      canvas.drawLine(Offset(size.width * 0.1, size.height * 0.6), Offset(size.width * 0.9, size.height * 0.6), guide);
      canvas.drawLine(Offset(size.width * 0.1, size.height * 0.75), Offset(size.width * 0.9, size.height * 0.75), guide);
    }
    for (final path in paths) {
      final paint = Paint()
        ..color = path.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = path.stroke;
      for (int i = 0; i < path.points.length - 1; i++) {
        canvas.drawLine(path.points[i], path.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaintLayer oldDelegate) => oldDelegate.paths != paths || oldDelegate.showTargets != showTargets;
}

class _Toolbar extends StatelessWidget {
  final Color color;
  final double stroke;
  final bool targets;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onStroke;
  final VoidCallback onToggleTargets;

  const _Toolbar({
    super.key,
    required this.color,
    required this.stroke,
    required this.targets,
    required this.onColor,
    required this.onStroke,
    required this.onToggleTargets,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.cyanAccent, Colors.redAccent, Colors.yellowAccent, Colors.greenAccent, Colors.white];
    return Card(
      color: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                ...colors.map((c) {
                  final sel = c.value == color.value;
                  return GestureDetector(
                    onTap: () => onColor(c),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: sel ? 26 : 22,
                      height: sel ? 26 : 22,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: sel ? Colors.white : Colors.white38, width: sel ? 2 : 1),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onToggleTargets,
                  icon: Icon(targets ? Icons.center_focus_strong : Icons.center_focus_weak, color: Colors.white),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.brush, color: Colors.white70, size: 18),
                Slider(value: stroke, min: 2, max: 18, divisions: 8, onChanged: onStroke),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
