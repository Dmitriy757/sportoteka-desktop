import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelPreview extends StatefulWidget {
  final String videoUrl;
  final String thumbnail;
  
  const ReelPreview({
    Key? key,
    required this.videoUrl,
    required this.thumbnail,
  }) : super(key: key);

  @override
  State<ReelPreview> createState() => _ReelPreviewState();
}

class _ReelPreviewState extends State<ReelPreview> {
  late VideoPlayerController _videoController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _videoController.setLooping(true);
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _videoController.play() : _videoController.pause();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoController.value.isInitialized)
            VideoPlayer(_videoController)
          else
            Image.network(
              widget.thumbnail,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.videocam, size: 50, color: Colors.white),
              ),
            ),
          
          if (!_isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                size: 50,
                color: Colors.white70,
              ),
            ),
          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}