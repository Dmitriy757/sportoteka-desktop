import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/presentation/team_video_analysis/tracking_models.dart';

class PythonTrackingResult {
  final List<DetectedPlayerBox> detections;
  final Rect? ballRect;
  final double? ballConfidence;
  final double? frameWidth;
  final double? frameHeight;

  const PythonTrackingResult({
    required this.detections,
    this.ballRect,
    this.ballConfidence,
    this.frameWidth,
    this.frameHeight,
  });

  bool get hasBall => ballRect != null;

  factory PythonTrackingResult.empty() {
    return const PythonTrackingResult(
      detections: [],
      ballRect: null,
      ballConfidence: null,
      frameWidth: null,
      frameHeight: null,
    );
  }
}

class PythonTrackingService {
  final String baseUrl;

  PythonTrackingService({required this.baseUrl});

  Future<PythonTrackingResult> detectFrame({
    required File frameFile,
    required int timeMs,
  }) async {
    try {
      final url = '$baseUrl/analyze_frame';
      debugPrint('🚀 PYTHON URL: $url');
      debugPrint('🕒 timeMs: $timeMs');
      debugPrint('🖼 frame path: ${frameFile.path}');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(url),
      );

      request.fields['timeMs'] = timeMs.toString();
      request.files.add(
        await http.MultipartFile.fromPath(
          'frame',
          frameFile.path,
        ),
      );

      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );

      final response = await http.Response.fromStream(streamed).timeout(
        const Duration(seconds: 20),
      );

      debugPrint('📥 PYTHON STATUS: ${response.statusCode}');
      debugPrint('📥 PYTHON BODY: ${response.body}');

      if (response.statusCode != 200) {
        return PythonTrackingResult.empty();
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] != true) {
        debugPrint('❌ PYTHON success=false: ${data['error']}');
        return PythonTrackingResult.empty();
      }

      return _parseTrackingResult(data);
    } catch (e) {
      debugPrint('❌ PYTHON detectFrame error: $e');
      return PythonTrackingResult.empty();
    }
  }

  Future<PythonTrackingResult> detectFrameFromUrl({
    required String videoUrl,
    required int timeMs,
  }) async {
    try {
      final url = '$baseUrl/analyze_frame_from_url';
      debugPrint('🚀 PYTHON URL STREAM: $url');
      debugPrint('🎬 videoUrl: $videoUrl');
      debugPrint('🕒 timeMs: $timeMs');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'video_url': videoUrl,
              'timeMs': timeMs,
            }),
          )
          .timeout(const Duration(seconds: 25));

      debugPrint('📥 PYTHON STREAM STATUS: ${response.statusCode}');
      debugPrint('📥 PYTHON STREAM BODY: ${response.body}');

      if (response.statusCode != 200) {
        return PythonTrackingResult.empty();
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] != true) {
        debugPrint('❌ PYTHON STREAM success=false: ${data['error']}');
        return PythonTrackingResult.empty();
      }

      return _parseTrackingResult(data);
    } catch (e) {
      debugPrint('❌ PYTHON detectFrameFromUrl error: $e');
      return PythonTrackingResult.empty();
    }
  }

  PythonTrackingResult _parseTrackingResult(Map<String, dynamic> data) {
    final detectionsRaw = (data['detections'] as List?) ?? const [];

    final detections = detectionsRaw
        .map(
          (item) => DetectedPlayerBox.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    Rect? ballRect;
    double? ballConfidence;

    final rawBall = data['ball'];
    if (rawBall is Map) {
      final ballMap = Map<String, dynamic>.from(rawBall);

      final left = (ballMap['left'] ?? ballMap['x'] ?? 0).toDouble();
      final top = (ballMap['top'] ?? ballMap['y'] ?? 0).toDouble();

      final right = ballMap['right'] != null
          ? (ballMap['right']).toDouble()
          : left + (ballMap['width'] ?? 0).toDouble();

      final bottom = ballMap['bottom'] != null
          ? (ballMap['bottom']).toDouble()
          : top + (ballMap['height'] ?? 0).toDouble();

      if (right > left && bottom > top) {
        ballRect = Rect.fromLTRB(left, top, right, bottom);
        ballConfidence = (ballMap['confidence'] ?? 0).toDouble();
      }
    }

    final frameWidth = (data['frame_width'] as num?)?.toDouble();
    final frameHeight = (data['frame_height'] as num?)?.toDouble();

    return PythonTrackingResult(
      detections: detections,
      ballRect: ballRect,
      ballConfidence: ballConfidence,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    );
  }
}