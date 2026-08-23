// lib/presentation/innovation/screens/ai_technique_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sportoteka/data/innovation_api.dart';

class AiTechniqueScreen extends StatefulWidget {
  const AiTechniqueScreen({super.key});
  @override
  State<AiTechniqueScreen> createState() => _AiTechniqueScreenState();
}

class _AiTechniqueScreenState extends State<AiTechniqueScreen> {
  CameraController? _cam;
  bool _started = false;
  bool _busy = false;

  late final PoseDetector _detector;

  DateTime _sessionStart = DateTime.now();
  int _reps = 0;
  bool _inBottom = false;

  double? _elbow, _knee, _hip, _trunk;
  String _advice = 'Держи осанку, работай ровно';

  final _timeline = <_AngleSample>[];

  @override
  void initState() {
    super.initState();
    _detector = PoseDetector(options: PoseDetectorOptions());
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      _cam = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await _cam!.initialize();
      await _cam!.startImageStream(_onFrame);
      if (mounted) setState(() => _started = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Камера недоступна: $e')),
      );
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    _detector.close();
    super.dispose();
  }

  Future<void> _onFrame(CameraImage img) async {
    if (!_started || _busy) return;
    _busy = true;
    try {
      final input = _toInputImage(img, _cam!.description.sensorOrientation);
      final poses = await _detector.processImage(input);
      if (poses.isNotEmpty) {
        _handlePose(poses.first);
      }
    } catch (_) {}
    _busy = false;
  }

  void _handlePose(Pose pose) {
    Offset? p(PoseLandmarkType t) {
      final lm = pose.landmarks[t];
      if (lm == null) return null;
      return Offset(lm.x, lm.y);
    }

    final rShoulder = p(PoseLandmarkType.rightShoulder);
    final rElbow    = p(PoseLandmarkType.rightElbow);
    final rWrist    = p(PoseLandmarkType.rightWrist);

    final rHip      = p(PoseLandmarkType.rightHip);
    final rKnee     = p(PoseLandmarkType.rightKnee);
    final rAnkle    = p(PoseLandmarkType.rightAnkle);

    double? angle(Offset? a, Offset? b, Offset? c) {
      if (a == null || b == null || c == null) return null;
      final ab = a - b;
      final cb = c - b;
      final dot = ab.dx * cb.dx + ab.dy * cb.dy;
      final magA = ab.distance;
      final magB = cb.distance;
      if (magA == 0 || magB == 0) return null;
      final cosang = (dot / (magA * magB)).clamp(-1.0, 1.0);
      return (math.acos(cosang) * 180 / math.pi);
    }

    _elbow = angle(rShoulder, rElbow, rWrist);           // локоть
    _knee  = angle(rHip, rKnee, rAnkle);                 // колено
    _hip   = angle(rShoulder, rHip, rKnee);              // таз (грубо)
    _trunk = _calcTrunk(rShoulder, rHip);                // наклон корпуса

    // советы
    _advice = _composeAdvice(_elbow, _knee, _hip, _trunk);

    // счётчик приседов
    if (_knee != null) {
      if (_knee! < 100 && !_inBottom) _inBottom = true;
      if (_knee! > 160 && _inBottom) { _reps++; _inBottom = false; }
    }

    // лог для выгрузки
    _timeline.add(_AngleSample(
      t: DateTime.now(),
      elbow: _elbow,
      knee: _knee,
      hip: _hip,
      trunk: _trunk,
      advice: _advice,
    ));
    setState(() {});
  }

  double? _calcTrunk(Offset? shoulder, Offset? hip) {
    if (shoulder == null || hip == null) return null;
    final dy = (shoulder.dy - hip.dy);
    final dx = (shoulder.dx - hip.dx);
    final a = (math.atan2(dy, dx) * 180 / math.pi);
    return (90 - a.abs()).abs(); // 0=горизонталь, 90=вертикаль
  }

  String _composeAdvice(double? elbow, double? knee, double? hip, double? trunk) {
    final tips = <String>[];
    if (elbow != null) {
      if (elbow < 120) tips.add('Локоть: меньше сгиб');
      else if (elbow > 175) tips.add('Локоть: не переразгибай');
    }
    if (knee != null) {
      if (knee < 90) tips.add('Колено: глубоко — держи спину');
      else if (knee > 170) tips.add('Колено: можно глубже');
    }
    if (hip != null && hip < 120) tips.add('Таз: активнее толчок');
    if (trunk != null && trunk < 70) tips.add('Корпус: выпрямись');
    if (tips.isEmpty) return 'Отлично! Держи темп';
    return tips.join(' • ');
  }

  // ---------- EXPORT & SAVE ----------

  Future<void> _exportCsv() async {
    final buf = StringBuffer();
    buf.writeln('t,elbow,knee,hip,trunk,advice');
    for (final s in _timeline) {
      buf.writeln('${s.t.toIso8601String()},'
          '${s.elbow?.toStringAsFixed(1) ?? ''},'
          '${s.knee?.toStringAsFixed(1) ?? ''},'
          '${s.hip?.toStringAsFixed(1) ?? ''},'
          '${s.trunk?.toStringAsFixed(1) ?? ''},'
          '"${s.advice}"');
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/ai_session_${_sessionStart.millisecondsSinceEpoch}.csv');
    await f.writeAsString(buf.toString(), flush: true);
    await Share.shareXFiles([XFile(f.path)], text: 'AI-Coach CSV (🇧🇾 РБ — Sportoteka)');
  }

  Future<void> _saveToServer() async {
    try {
      final id = await InnovationApi.saveAiSession(
        startedAt: _sessionStart,
        duration: DateTime.now().difference(_sessionStart),
        reps: _reps,
        samples: _timeline.map((s) => s.toJson()).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI-сессия сохранена (ID $id)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = (_cam?.value.isInitialized ?? false)
        ? CameraPreview(_cam!)
        : const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-анализ техники'),
        actions: [
          IconButton(icon: const Icon(Icons.file_download), tooltip: 'Экспорт CSV', onPressed: _exportCsv),
          IconButton(icon: const Icon(Icons.cloud_upload), tooltip: 'Сохранить на сервер', onPressed: _saveToServer),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: preview),
          Positioned(
            left: 12, top: 12,
            child: _MetricsBox(reps: _reps, elbow: _elbow, knee: _knee, hip: _hip, trunk: _trunk),
          ),
          Positioned(
            left: 12, bottom: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: const Text('🇧🇾 Разработано в РБ — Sportoteka', style: TextStyle(color: Colors.white70)),
            ),
          ),
          Positioned(
            bottom: 24, right: 12,
            child: _Advice(advice: _advice),
          ),
        ],
      ),
    );
  }

  InputImage _toInputImage(CameraImage img, int rotation) {
    final plane = img.planes.first;
    final bytes = plane.bytes;
    final format = Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;
    final metadata = InputImageMetadata(
      size: Size(img.width.toDouble(), img.height.toDouble()),
      rotation: InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }
}

class _AngleSample {
  final DateTime t;
  final double? elbow, knee, hip, trunk;
  final String advice;
  _AngleSample({required this.t, this.elbow, this.knee, this.hip, this.trunk, required this.advice});

  Map<String, dynamic> toJson() => {
        't': t.toIso8601String(),
        'elbow': elbow,
        'knee': knee,
        'hip': hip,
        'trunk': trunk,
        'advice': advice,
      };
}

class _MetricsBox extends StatelessWidget {
  final int reps;
  final double? elbow, knee, hip, trunk;
  const _MetricsBox({required this.reps, this.elbow, this.knee, this.hip, this.trunk});

  @override
  Widget build(BuildContext context) {
    String f(double? v) => v == null ? '--' : v.toStringAsFixed(0) + '°';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Повторы: $reps', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Локоть: ${f(elbow)}'),
            Text('Колено: ${f(knee)}'),
            Text('Таз: ${f(hip)}'),
            Text('Корпус: ${f(trunk)}'),
          ],
        ),
      ),
    );
  }
}

class _Advice extends StatelessWidget {
  final String advice;
  const _Advice({required this.advice});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(advice, style: const TextStyle(color: Colors.white)),
    );
  }
}
