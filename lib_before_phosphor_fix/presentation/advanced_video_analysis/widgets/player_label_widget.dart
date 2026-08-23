// lib/presentation/advanced_video_analysis/widgets/player_label_widget.dart

import 'package:flutter/material.dart';
import '../models/player_detection.dart';

class PlayerLabelWidget extends StatelessWidget {
  final PlayerDetection player;
  final Size overlaySize;
  final Size sourceVideoSize;

  const PlayerLabelWidget({
    Key? key,
    required this.player,
    required this.overlaySize,
    required this.sourceVideoSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rect = _mapBoxToOverlay(
      bbox: player.bbox,
      overlaySize: overlaySize,
      sourceSize: sourceVideoSize,
    );

    if (rect.width <= 2 || rect.height <= 2) {
      return const SizedBox.shrink();
    }

    final Color teamColor = Color(player.teamColor);
    final bool compact = overlaySize.width < 560 || overlaySize.height < 300;
    final String title = compact ? _compactLabelText() : _labelText();
    final double borderWidth = compact ? 1.35 : 2.2;
    final double radius = compact ? 3.0 : 5.0;
    final double labelTop = compact ? -17.0 : -24.0;
    final double labelFont = compact ? 8.2 : 11.0;
    final double labelMaxWidth = compact ? 54.0 : 160.0;
    final EdgeInsets labelPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 7, vertical: 3);

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: teamColor, width: borderWidth),
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            if (title.isNotEmpty)
              Positioned(
                left: 0,
                top: labelTop,
                child: Container(
                  constraints: BoxConstraints(maxWidth: labelMaxWidth),
                  padding: labelPadding,
                  decoration: BoxDecoration(
                    color: teamColor.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.85), width: 1),
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: labelFont,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: -5,
              bottom: -5,
              child: Container(
                width: compact ? 7 : 10,
                height: compact ? 7 : 10,
                decoration: BoxDecoration(
                  color: teamColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactLabelText() {
    if (player.number > 0) return '${player.number}';
    final name = player.name.trim();
    final match = RegExp(r'(\d+)').firstMatch(name);
    if (match != null) return match.group(1)!;
    if (player.trackId > 0) return '${player.trackId}';
    return '';
  }

  String _labelText() {
    if (player.number > 0 && player.name.isNotEmpty) return '#${player.number} ${player.name}';
    if (player.number > 0) return '#${player.number}';
    if (player.name.isNotEmpty) return player.name;
    if (player.trackId > 0) return 'ID ${player.trackId}';
    return 'Игрок';
  }

  Rect _mapBoxToOverlay({
    required Rect bbox,
    required Size overlaySize,
    required Size sourceSize,
  }) {
    if (overlaySize.width <= 0 || overlaySize.height <= 0) return Rect.zero;

    double sourceW = sourceSize.width <= 0 ? 1920 : sourceSize.width;
    double sourceH = sourceSize.height <= 0 ? 1080 : sourceSize.height;

    Rect sourceBox = bbox;

    // Если сервер отдаёт bbox в нормализованных координатах 0..1.
    if (bbox.right <= 1.5 && bbox.bottom <= 1.5) {
      sourceBox = Rect.fromLTRB(
        bbox.left * sourceW,
        bbox.top * sourceH,
        bbox.right * sourceW,
        bbox.bottom * sourceH,
      );
    }

    // Если bbox пришёл как x/y/w/h, но был прочитан как left/top/right/bottom,
    // правый/нижний край окажется меньше левого/верхнего. Исправляем безопасно.
    if (sourceBox.right < sourceBox.left || sourceBox.bottom < sourceBox.top) {
      sourceBox = Rect.fromLTWH(
        sourceBox.left,
        sourceBox.top,
        sourceBox.right.abs(),
        sourceBox.bottom.abs(),
      );
    }

    final scale = (overlaySize.width / sourceW) < (overlaySize.height / sourceH)
        ? overlaySize.width / sourceW
        : overlaySize.height / sourceH;

    final displayedW = sourceW * scale;
    final displayedH = sourceH * scale;
    final dx = (overlaySize.width - displayedW) / 2;
    final dy = (overlaySize.height - displayedH) / 2;

    final mapped = Rect.fromLTRB(
      dx + sourceBox.left * scale,
      dy + sourceBox.top * scale,
      dx + sourceBox.right * scale,
      dy + sourceBox.bottom * scale,
    );

    return Rect.fromLTRB(
      mapped.left.clamp(0.0, overlaySize.width),
      mapped.top.clamp(0.0, overlaySize.height),
      mapped.right.clamp(0.0, overlaySize.width),
      mapped.bottom.clamp(0.0, overlaySize.height),
    );
  }
}
