import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'package:sportoteka/core/constants/app_colors.dart';

class MatchVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const MatchVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<MatchVideoPlayerScreen> createState() => _MatchVideoPlayerScreenState();
}

class _MatchVideoPlayerScreenState extends State<MatchVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await controller.initialize();
      await controller.setLooping(false);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;

    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${d.inMinutes}:$seconds';
  }

  Widget _buildPlayer(VideoPlayerController c, bool isLandscape) {
    final aspectRatio = c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio;

    if (isLandscape) {
      return Center(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: c.value.size.width <= 0 ? 1280 : c.value.size.width,
              height: c.value.size.height <= 0 ? 720 : c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: VideoPlayer(c),
      ),
    );
  }

  Widget _buildControls(VideoPlayerController c, bool isLandscape) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (_, value, __) {
        final position = value.position;
        final duration = value.duration;
        final maxMs = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
        final currentMs = position.inMilliseconds.clamp(0, maxMs);

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _showControls ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_showControls,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x22000000),
                    Color(0x88000000),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    if (isLandscape)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () async {
                            final current = c.value.position;
                            final target = current - const Duration(seconds: 10);
                            await c.seekTo(
                              target < Duration.zero ? Duration.zero : target,
                            );
                          },
                          icon: const Icon(
                            Icons.replay_10_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: IconButton(
                            onPressed: _togglePlay,
                            icon: Icon(
                              c.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () async {
                            final current = c.value.position;
                            final duration = c.value.duration;
                            final target = current + const Duration(seconds: 10);
                            await c.seekTo(
                              target > duration ? duration : target,
                            );
                          },
                          icon: const Icon(
                            Icons.forward_10_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 24 : 20,
                      ),
                      child: Column(
                        children: [
                          Slider(
                            value: currentMs.toDouble(),
                            min: 0,
                            max: maxMs.toDouble(),
                            activeColor: AppColors.primaryGreen,
                            inactiveColor: Colors.white24,
                            onChanged: (v) async {
                              await c.seekTo(
                                Duration(milliseconds: v.toInt()),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(bool isLandscape) {
    final c = _controller;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_failed || c == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            "Не удалось открыть видео",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: _buildPlayer(c, isLandscape),
          ),
          Positioned.fill(
            child: _buildControls(c, isLandscape),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: isLandscape
              ? null
              : AppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
          body: _buildBody(isLandscape),
        );
      },
    );
  }
}