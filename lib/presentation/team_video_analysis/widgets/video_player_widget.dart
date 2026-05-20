import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'common_widgets.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoPlayerController controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onTogglePlayPause;
  final Function(int) onSeek;
  final Widget? overlay;
  final bool showAiStatus;
  final bool isAiRunning;
  final String aiStatusText;

  const VideoPlayerWidget({
    super.key,
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onTogglePlayPause,
    required this.onSeek,
    this.overlay,
    this.showAiStatus = false,
    this.isAiRunning = false,
    this.aiStatusText = 'AI idle',
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return "${h.toString().padLeft(2, '0')}:$m:$s";
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: widget.controller.value.isInitialized
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: GestureDetector(
                        onDoubleTap: widget.onToggleFullscreen,
                        child: AspectRatio(
                          aspectRatio: widget.controller.value.aspectRatio == 0
                              ? 16 / 9
                              : widget.controller.value.aspectRatio,
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            panEnabled: true,
                            scaleEnabled: true,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: widget.controller.value.size.width,
                                      height: widget.controller.value.size.height,
                                      child: VideoPlayer(widget.controller),
                                    ),
                                  ),
                                ),
                                if (widget.overlay != null) widget.overlay!,
                                if (widget.showAiStatus)
                                  Positioned(
                                    left: 12,
                                    top: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.55),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: widget.isAiRunning
                                                  ? const Color(0xFF22C55E)
                                                  : const Color(0xFF94A3B8),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            widget.aiStatusText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.controller.value.isInitialized) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: VideoProgressIndicator(
                widget.controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formatDuration(widget.controller.value.position),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildControlButton(Icons.replay_10, () => widget.onSeek(-10)),
                const SizedBox(width: 6),
                _buildPlayPauseButton(),
                const SizedBox(width: 6),
                _buildControlButton(Icons.forward_10, () => widget.onSeek(10)),
                const SizedBox(width: 6),
                _buildControlButton(
                  widget.isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  widget.onToggleFullscreen,
                ),
                const Spacer(),
                Text(
                  _formatDuration(widget.controller.value.duration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    return InkWell(
      onTap: widget.onTogglePlayPause,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          widget.controller.value.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: Colors.black,
          size: 28,
        ),
      ),
    );
  }
}