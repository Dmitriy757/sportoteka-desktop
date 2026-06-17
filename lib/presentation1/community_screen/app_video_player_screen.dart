import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AppVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String videoUrl;
  final String thumbnailUrl;

  const AppVideoPlayerScreen({
    super.key,
    required this.title,
    required this.videoUrl,
    this.thumbnailUrl = "",
  });

  @override
  State<AppVideoPlayerScreen> createState() => _AppVideoPlayerScreenState();
}

class _AppVideoPlayerScreenState extends State<AppVideoPlayerScreen> {
  VideoPlayerController? _videoController;

  bool _loading = true;
  bool _hasError = false;
  String _errorText = "";

  bool _looksLikeDirectVideoUrl(String url) {
    final clean = url.toLowerCase().split('?').first.split('#').first;
    return clean.endsWith(".mp4") ||
        clean.endsWith(".mov") ||
        clean.endsWith(".m4v") ||
        clean.endsWith(".webm") ||
        clean.endsWith(".m3u8");
  }

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (!_looksLikeDirectVideoUrl(widget.videoUrl)) {
        throw Exception("Эта ссылка не является прямым видеофайлом");
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      _videoController = controller;

      await controller.initialize();
      await controller.setLooping(false);

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
        _errorText = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildVideoPlayer() {
    final c = _videoController!;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(c),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (c.value.isPlaying) {
                      c.pause();
                    } else {
                      c.play();
                    }
                  });
                },
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: c.value.isPlaying ? 0.0 : 1.0,
                  child: Container(
                    color: Colors.black.withOpacity(0.20),
                    child: const Center(
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.play_arrow,
                          color: Color(0xFF00A750),
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.black87,
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    if (c.value.isPlaying) {
                      c.pause();
                    } else {
                      c.play();
                    }
                  });
                },
                icon: Icon(
                  c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              "Не удалось открыть видео",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorText.isEmpty ? "Неизвестная ошибка" : _errorText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = widget.title.trim().isEmpty ? "Видео" : widget.title;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          pageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _hasError
              ? _buildError()
              : Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (_videoController != null) _buildVideoPlayer(),
                      ],
                    ),
                  ),
                ),
    );
  }
}