// lib/presentation/innovation/screens/heatmap_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import 'package:sportoteka/data/innovation_api.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});
  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  bool _tracking = false;
  StreamSubscription<Position>? _sub;
  final _points = <Position>[];

  DateTime? _start;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<bool> _ensurePerms() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) return false;
    return perm == LocationPermission.whileInUse || perm == LocationPermission.always;
    }

  Future<void> _startTrack() async {
    if (!await _ensurePerms()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет разрешения на геолокацию')));
      return;
    }
    _sub?.cancel();
    _points.clear();
    _start = DateTime.now();
    setState(() => _tracking = true);
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen((p) => setState(() => _points.add(p)));
  }

  Future<void> _stopTrack() async {
    await _sub?.cancel();
    setState(() => _tracking = false);
    await _saveToServer(); // сохранение по стопу
  }

  double _totalDistanceKm() {
    double d = 0;
    for (int i = 1; i < _points.length; i++) {
      d += Geolocator.distanceBetween(
        _points[i - 1].latitude, _points[i - 1].longitude,
        _points[i].latitude, _points[i].longitude,
      );
    }
    return d / 1000.0;
  }

  Duration _elapsed() {
    if (_points.isEmpty) return Duration.zero;
    final start = _start ?? _points.first.timestamp ?? DateTime.now();
    final end = _tracking ? DateTime.now() : (_points.last.timestamp ?? DateTime.now());
    return end.difference(start);
  }

  String _paceStr() {
    final km = _totalDistanceKm();
    if (km <= 0.001) return '--';
    final secsPerKm = _elapsed().inSeconds / km;
    final m = (secsPerKm ~/ 60);
    final s = (secsPerKm % 60).round().toString().padLeft(2, '0');
    return '$m:$s /км';
  }

  Map<String, int> _zoneSeconds() {
    if (_points.length < 2) return {};
    final lats = _points.map((e) => e.latitude).toList();
    final lons = _points.map((e) => e.longitude).toList();
    final minLat = lats.reduce(math.min), maxLat = lats.reduce(math.max);
    final minLon = lons.reduce(math.min), maxLon = lons.reduce(math.max);

    int zone(double x, double y) {
      final c = (x * 3).clamp(0, 2.9999);
      final r = (y * 2).clamp(0, 1.9999);
      final ci = c.floor(), ri = r.floor();
      return ri * 3 + ci; // 0..5
    }

    final map = <String, int>{};
    for (int i = 1; i < _points.length; i++) {
      final p = _points[i];
      final prev = _points[i - 1];
      final dt = (p.timestamp ?? DateTime.now()).difference(prev.timestamp ?? DateTime.now()).inSeconds;
      final x = (p.longitude - minLon) / ((maxLon - minLon) == 0 ? 1 : (maxLon - minLon));
      final y = 1 - (p.latitude - minLat) / ((maxLat - minLat) == 0 ? 1 : (maxLat - minLat));
      final z = zone(x, y);
      map['Z$z'] = (map['Z$z'] ?? 0) + dt;
    }
    return map;
  }

  String _buildGpx() {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<gpx version="1.1" creator="Sportoteka" xmlns="http://www.topografix.com/GPX/1/1">');
    buf.writeln('<trk><name>Sportoteka Track</name><trkseg>');
    for (final p in _points) {
      final ts = (p.timestamp ?? DateTime.now()).toUtc().toIso8601String();
      buf.writeln('<trkpt lat="${p.latitude}" lon="${p.longitude}"><time>$ts</time></trkpt>');
    }
    buf.writeln('</trkseg></trk></gpx>');
    return buf.toString();
  }

  Future<void> _exportGpxFile() async {
    if (_points.isEmpty) return;
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/track_${DateTime.now().millisecondsSinceEpoch}.gpx');
    await f.writeAsBytes(utf8.encode(_buildGpx()), flush: true);
    await Share.shareXFiles([XFile(f.path)], text: 'GPX трек (🇧🇾 РБ — Sportoteka)');
  }

  Future<void> _saveToServer() async {
    if (_points.length < 2) return;
    try {
      final id = await InnovationApi.saveHeatmapSession(
        startedAt: _start ?? _points.first.timestamp ?? DateTime.now(),
        duration: _elapsed(),
        distanceKm: _totalDistanceKm(),
        pace: _paceStr(),
        gpx: _buildGpx(),
        zones: _zoneSeconds().map((k, v) => MapEntry(k, v)), // Map<String, dynamic>
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Сессия heatmap сохранена (ID $id)')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dist = _totalDistanceKm().toStringAsFixed(2);
    final elapsed = _elapsed();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тепловая карта активности'),
        actions: [
          IconButton(onPressed: _exportGpxFile, icon: const Icon(Icons.route)),
          if (_tracking)
            IconButton(onPressed: _stopTrack, icon: const Icon(Icons.stop_circle))
          else
            IconButton(onPressed: _startTrack, icon: const Icon(Icons.play_circle_fill)),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.black12,
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Дист: $dist км'),
                Text('Время: ${elapsed.inMinutes} мин'),
                Text('Темп: ${_paceStr()}'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: AspectRatio(
                aspectRatio: 105 / 68,
                child: CustomPaint(
                  painter: _HeatmapPainter(_points),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
            child: Wrap(
              spacing: 8,
              children: List.generate(6, (i) {
                final sec = _zoneSeconds()['Z$i'] ?? 0;
                final mm = (sec ~/ 60).toString().padLeft(2, '0');
                final ss = (sec % 60).toString().padLeft(2, '0');
                return Chip(label: Text('Zone $i: $mm:$ss'));
              }),
            ),
          ),
          const SizedBox(height: 8),
          const Text('🇧🇾 Разработано в РБ — Sportoteka', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<Position> pts;
  _HeatmapPainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    _drawField(canvas, size);
    if (pts.isEmpty) return;

    final lats = pts.map((e) => e.latitude).toList();
    final lons = pts.map((e) => e.longitude).toList();
    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);
    final minLon = lons.reduce(math.min);
    final maxLon = lons.reduce(math.max);

    Offset toXY(Position p) {
      final x = (p.longitude - minLon) / ((maxLon - minLon) == 0 ? 1 : (maxLon - minLon));
      final y = (p.latitude - minLat) / ((maxLat - minLat) == 0 ? 1 : (maxLat - minLat));
      return Offset(x * size.width, size.height - y * size.height);
    }

    for (final p in pts) {
      final o = toXY(p);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.redAccent.withOpacity(0.35),
            Colors.orange.withOpacity(0.15),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: o, radius: 24));
      canvas.drawCircle(o, 24, paint);
    }
  }

  void _drawField(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0b6f2f);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)), bg);

    final line = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)), line);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.shortestSide * 0.12, line);

    final boxW = size.width * 0.18;
    final boxH = size.height * 0.32;
    canvas.drawRect(Rect.fromLTWH(0, (size.height - boxH) / 2, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH(size.width - boxW, (size.height - boxH) / 2, boxW, boxH), line);
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) => oldDelegate.pts != pts;
}
