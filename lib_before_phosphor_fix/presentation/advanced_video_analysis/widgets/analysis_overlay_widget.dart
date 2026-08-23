// lib/presentation/advanced_video_analysis/widgets/analysis_overlay_widget.dart

import 'package:flutter/material.dart';
import '../models/player_detection.dart';
import 'player_label_widget.dart';

class AnalysisOverlayWidget extends StatelessWidget {
  final List<PlayerDetection> players;
  final Map<String, dynamic> stats;

  /// Оставлено для совместимости со старым вызовом из AdvancedVideoAnalysisScreen.
  /// Реальный размер overlay берётся через LayoutBuilder.
  final Size videoSize;

  const AnalysisOverlayWidget({
    Key? key,
    required this.players,
    required this.stats,
    required this.videoSize,
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
