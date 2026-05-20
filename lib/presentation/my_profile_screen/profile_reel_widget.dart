// lib/presentation/my_profile_screen/profile_reel_widget.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PlayerProfileReelWidget extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final bool autoPlay;
  final bool muted;
  final VoidCallback? onTap;
  
  // ✅ Параметры трансформаций из базы данных
  final int? rotationDeg;      // ручной поворот
  final String? cropMode;      // 'fit' или 'fill'
  final double? cropScale;     // масштаб при fill
  final double? cropDx;        // смещение по X
  final double? cropDy;        // смещение по Y

  const PlayerProfileReelWidget({
    super.key,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.autoPlay = false,
    this.muted = true,
    this.onTap,
    this.rotationDeg,
    this.cropMode,
    this.cropScale,
    this.cropDx,
    this.cropDy,
  });

  @override
  State<PlayerProfileReelWidget> createState() => _PlayerProfileReelWidgetState();
}

class _PlayerProfileReelWidgetState extends State<PlayerProfileReelWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(PlayerProfileReelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initializeController();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  Future<void> _initializeController() async {
    if (widget.videoUrl.isEmpty) return;

    try {
      _hasError = false;
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await controller.initialize();
      
      if (!mounted) {
        controller.dispose();
        return;
      }

      controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0.0 : 1.0);

      if (widget.autoPlay) {
        await controller.play();
      }

      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('❌ Error initializing reel in profile: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
  }

  int _normalizeDegrees(int deg) => ((deg % 360) + 360) % 360;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          _togglePlayPause();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(0), // убираем скругление для сетки
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Видео или превью
            if (_isInitialized && _controller != null && !_hasError)
              _buildVideoWithTransformations()
            else if (widget.thumbnailUrl.isNotEmpty && !_hasError)
              _buildThumbnail()
            else if (_hasError)
              _buildErrorWidget()
            else
              _buildLoadingWidget(),

            // Индикатор воспроизведения (пауза)
            if (_isInitialized && _controller != null && !_controller!.value.isPlaying)
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 32,
                ),
              ),

            // Индикатор звука (muted)
            if (widget.muted)
              const Positioned(
                bottom: 8,
                right: 8,
                child: Icon(
                  Icons.volume_off_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoWithTransformations() {
    if (_controller == null) return const SizedBox();

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        // Получаем автоматический поворот из метаданных видео
        final int autoRotate = _controller!.value.rotationCorrection;
        
        // Суммарный поворот = автоматический + ручной из БД
        final int totalRotate = _normalizeDegrees(autoRotate + (widget.rotationDeg ?? 0));
        final double rotRad = totalRotate * math.pi / 180.0;

        final Size s = _controller!.value.size;
        double w = s.width;
        double h = s.height;

        if (w <= 0 || h <= 0) {
          final ar = _controller!.value.aspectRatio;
          if (ar <= 0) return const SizedBox();
          w = ar >= 1.0 ? ar : 1.0;
          h = ar >= 1.0 ? 1.0 : (1.0 / ar);
        }

        final bool swap = (totalRotate == 90 || totalRotate == 270);
        final double rw = swap ? h : w;
        final double rh = swap ? w : h;

        // Базовое видео с поворотом
        Widget video = SizedBox(
          width: rw,
          height: rh,
          child: Transform.rotate(
            angle: rotRad,
            alignment: Alignment.center,
            child: VideoPlayer(_controller!),
          ),
        );

        // Применяем кроп/масштабирование если был режим fill
        final bool isFillMode = widget.cropMode == 'fill' && 
                                 widget.cropScale != null && 
                                 widget.cropScale! > 1.0;

        if (isFillMode) {
          video = ClipRect(
            child: Transform.translate(
              offset: Offset(widget.cropDx ?? 0, widget.cropDy ?? 0),
              child: Transform.scale(
                scale: widget.cropScale!,
                alignment: Alignment.center,
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    child: video,
                  ),
                ),
              ),
            ),
          );
        }

        // Для профиля используем BoxFit.cover чтобы красиво заполнить ячейку
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: video,
          ),
        );
      },
    );
  }

  Widget _buildThumbnail() {
    return Image.network(
      widget.thumbnailUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorWidget();
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: Colors.white54,
          size: 32,
        ),
      ),
    );
  }
}

// ==================== ПОЛНОЭКРАННЫЙ ПРОСМОТРЩИК ====================
// Если вам нужен полноэкранный режим при тапе на Reel в профиле,
// добавьте эти классы в этот же файл или создайте отдельный

class FullscreenReelViewer extends StatefulWidget {
  final List<Map<String, dynamic>> reels;
  final int initialIndex;

  const FullscreenReelViewer({
    super.key,
    required this.reels,
    required this.initialIndex,
  });

  @override
  State<FullscreenReelViewer> createState() => _FullscreenReelViewerState();
}

class _FullscreenReelViewerState extends State<FullscreenReelViewer> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.reels.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          final reel = widget.reels[index];
          
          return Stack(
            fit: StackFit.expand,
            children: [
              // Видео плеер с трансформациями
              _FullscreenReelVideo(
                videoUrl: reel['video_url'] ?? '',
                thumbnailUrl: reel['thumbnail'] ?? '',
                rotationDeg: reel['rotation'] as int?,
                cropMode: reel['crop_mode'] as String?,
                cropScale: (reel['crop_scale'] as num?)?.toDouble(),
                cropDx: (reel['crop_dx'] as num?)?.toDouble(),
                cropDy: (reel['crop_dy'] as num?)?.toDouble(),
              ),
              
              // Кнопка назад
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              // Информация о видео (описание, лайки и т.д.)
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reel['description'] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${reel['likes'] ?? 0}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.comment, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${reel['comments'] ?? 0}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.remove_red_eye, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${reel['views'] ?? 0}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Видео плеер для полноэкранного режима
class _FullscreenReelVideo extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final int? rotationDeg;
  final String? cropMode;
  final double? cropScale;
  final double? cropDx;
  final double? cropDy;

  const _FullscreenReelVideo({
    required this.videoUrl,
    required this.thumbnailUrl,
    this.rotationDeg,
    this.cropMode,
    this.cropScale,
    this.cropDx,
    this.cropDy,
  });

  @override
  State<_FullscreenReelVideo> createState() => _FullscreenReelVideoState();
}

class _FullscreenReelVideoState extends State<_FullscreenReelVideo> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = true;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeController() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await controller.initialize();
      
      if (!mounted) {
        controller.dispose();
        return;
      }

      controller.setLooping(true);
      await controller.play();

      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('❌ Error initializing fullscreen reel: $e');
    }
  }

  void _togglePlay() {
    if (_controller == null) return;
    
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {
      _isPlaying = _controller!.value.isPlaying;
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    
    _muted = !_muted;
    _controller!.setVolume(_muted ? 0.0 : 1.0);
    setState(() {});
  }

  int _normalizeDegrees(int deg) => ((deg % 360) + 360) % 360;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitialized && _controller != null)
            AnimatedBuilder(
              animation: _controller!,
              builder: (context, child) {
                final int autoRotate = _controller!.value.rotationCorrection;
                final int totalRotate = _normalizeDegrees(autoRotate + (widget.rotationDeg ?? 0));
                final double rotRad = totalRotate * math.pi / 180.0;

                final Size s = _controller!.value.size;
                double w = s.width;
                double h = s.height;

                if (w <= 0 || h <= 0) {
                  final ar = _controller!.value.aspectRatio;
                  if (ar <= 0) return const SizedBox();
                  w = ar >= 1.0 ? ar : 1.0;
                  h = ar >= 1.0 ? 1.0 : (1.0 / ar);
                }

                final bool swap = (totalRotate == 90 || totalRotate == 270);
                final double rw = swap ? h : w;
                final double rh = swap ? w : h;

                Widget video = SizedBox(
                  width: rw,
                  height: rh,
                  child: Transform.rotate(
                    angle: rotRad,
                    alignment: Alignment.center,
                    child: VideoPlayer(_controller!),
                  ),
                );

                final bool isFillMode = widget.cropMode == 'fill' && 
                                         widget.cropScale != null && 
                                         widget.cropScale! > 1.0;

                if (isFillMode) {
                  video = ClipRect(
                    child: Transform.translate(
                      offset: Offset(widget.cropDx ?? 0, widget.cropDy ?? 0),
                      child: Transform.scale(
                        scale: widget.cropScale!,
                        alignment: Alignment.center,
                        child: SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            child: video,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: video,
                  ),
                );
              },
            )
          else if (widget.thumbnailUrl.isNotEmpty)
            Image.network(
              widget.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
            )
          else
            Container(color: Colors.grey[900]),

          // Плей/пауза индикатор
          if (!_isPlaying)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 64,
              ),
            ),

          // Кнопка mute
          Positioned(
            bottom: 20,
            right: 20,
            child: IconButton(
              icon: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white70,
                size: 28,
              ),
              onPressed: _toggleMute,
            ),
          ),
        ],
      ),
    );
  }
}