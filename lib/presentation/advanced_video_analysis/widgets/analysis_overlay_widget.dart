// lib/presentation/advanced_video_analysis/widgets/analysis_overlay_widget.dart

import 'package:flutter/material.dart';
import '../models/player_detection.dart';
import 'player_label_widget.dart';

class AnalysisOverlayWidget extends StatelessWidget {
  final List<PlayerDetection> players;
  final Map<String, dynamic> stats;
  final Map<String, dynamic>? ball;

  /// Оставлено для совместимости со старым вызовом из AdvancedVideoAnalysisScreen.
  /// Реальный размер overlay берётся через LayoutBuilder.
  final Size videoSize;

  const AnalysisOverlayWidget({
    Key? key,
    required this.players,
    required this.stats,
    required this.videoSize,
    this.ball,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
          final sourceVideoSize = _sourceVideoSizeFromStats(stats);

          return Stack(
            fit: StackFit.expand,
            children: [
              for (final player in players)
                PlayerLabelWidget(
                  player: player,
                  overlaySize: overlaySize,
                  sourceVideoSize: sourceVideoSize,
                ),
              if (ball != null)
                _BallMarker(
                  ball: ball!,
                  overlaySize: overlaySize,
                  sourceVideoSize: sourceVideoSize,
                ),
            ],
          );
        },
      ),
    );
  }

  Size _sourceVideoSizeFromStats(Map<String, dynamic> stats) {
    final w = _asDouble(
      stats['video_width'] ??
          stats['frame_width'] ??
          stats['source_width'] ??
          stats['width'],
    );
    final h = _asDouble(
      stats['video_height'] ??
          stats['frame_height'] ??
          stats['source_height'] ??
          stats['height'],
    );

    // По твоим логам сервер анализирует 1920x1080, поэтому это правильный fallback.
    if (w <= 0 || h <= 0) return const Size(1920, 1080);
    return Size(w, h);
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }
}

class _BallMarker extends StatelessWidget {
  final Map<String, dynamic> ball;
  final Size overlaySize;
  final Size sourceVideoSize;

  const _BallMarker({
    required this.ball,
    required this.overlaySize,
    required this.sourceVideoSize,
  });

  @override
  Widget build(BuildContext context) {
    final center = ball['center'];
    final bbox = ball['bbox'];
    var x = center is Map ? _number(center['x']) : 0.0;
    var y = center is Map ? _number(center['y']) : 0.0;
    if ((x <= 0 || y <= 0) && bbox is List && bbox.length >= 4) {
      x = (_number(bbox[0]) + _number(bbox[2])) / 2;
      y = (_number(bbox[1]) + _number(bbox[3])) / 2;
    }
    if (x <= 0 || y <= 0) return const SizedBox.shrink();

    final sourceW = sourceVideoSize.width <= 0 ? 1920.0 : sourceVideoSize.width;
    final sourceH = sourceVideoSize.height <= 0 ? 1080.0 : sourceVideoSize.height;
    if (x <= 1.5 && y <= 1.5) {
      x *= sourceW;
      y *= sourceH;
    }
    final scale = (overlaySize.width / sourceW) < (overlaySize.height / sourceH)
        ? overlaySize.width / sourceW
        : overlaySize.height / sourceH;
    final dx = (overlaySize.width - sourceW * scale) / 2 + x * scale;
    final dy = (overlaySize.height - sourceH * scale) / 2 + y * scale;
    const marker = 17.0;
    return Positioned(
      left: dx - marker / 2,
      top: dy - marker / 2,
      child: Container(
        width: marker,
        height: marker,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF00A750), width: 3),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 5)],
        ),
      ),
    );
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
