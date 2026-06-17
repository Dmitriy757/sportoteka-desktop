import 'dart:io';
import 'dart:math' as math;
import 'dart:convert'; 
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class UploadReelScreen extends StatefulWidget {
  final VoidCallback onUploadComplete;

  const UploadReelScreen({
    super.key,
    required this.onUploadComplete,
  });

  @override
  State<UploadReelScreen> createState() => _UploadReelScreenState();
}

class _UploadReelScreenState extends State<UploadReelScreen>
    with SingleTickerProviderStateMixin {
  File? _videoFile;
  VideoPlayerController? _videoController;

  final TextEditingController _descriptionController = TextEditingController();

  bool _isUploading = false;
  double _uploadProgress = 0.0;

  /// ручной поворот предпросмотра (0/90/180/270)
  int _manualRotateDeg = 0;

  /// режим предпросмотра:
  /// true = Fill 9:16 (Instagram Reels)
  /// false = Fit по аспекту
  bool _previewReelsMode = true;

  /// Instagram crop/zoom для Fill 9:16
  double _cropScale = 1.0; // 1..4
  Offset _cropOffset = Offset.zero;

  // gesture helpers
  double _startScale = 1.0;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  /// grid like Instagram
  bool _showGrid = true;

  /// double tap zoom animation
  late final AnimationController _zoomAnim;
  Animation<double>? _zoomTween;
  Animation<Offset>? _offsetTween;

  static const String _uploadUrl = "https://sportotekaapp.ru/api/upload_reel.php";

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onDescriptionChanged);

    _zoomAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        final z = _zoomTween;
        final o = _offsetTween;
        if (z == null || o == null) return;
        setState(() {
          _cropScale = z.value;
          _cropOffset = o.value;
        });
      });
  }

  void _onDescriptionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    _disposeVideoController();
    _zoomAnim.dispose();
    super.dispose();
  }

  void _disposeVideoController() {
    final c = _videoController;
    _videoController = null;
    if (c != null) {
      c.pause();
      c.dispose();
    }
  }

  void _resetCrop() {
    _zoomAnim.stop();
    setState(() {
      _cropScale = 1.0;
      _cropOffset = Offset.zero;
    });
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);

      _disposeVideoController();

      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0);

      if (!mounted) return;

      // ✅ НЕ применяем автоматический поворот, показываем как есть
      setState(() {
        _videoFile = file;
        _videoController = controller;
        _manualRotateDeg = 0;
        _cropScale = 1.0;
        _cropOffset = Offset.zero;

        // определяем ориентацию для выбора режима по умолчанию
        final isLandscape = _isLandscape(controller);
        _previewReelsMode = !isLandscape; // для landscape лучше Fit
      });

      await controller.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Не удалось выбрать/открыть видео: $e")),
      );
    }
  }

  // ✅ Просто проверяем ориентацию без учета поворота
  bool _isLandscape(VideoPlayerController c) {
    if (!c.value.isInitialized) return false;

    final s = c.value.size;
    if (s.width <= 0 || s.height <= 0) return false;

    return s.width >= s.height;
  }

  void _removeVideo() {
    _disposeVideoController();
    setState(() {
      _videoFile = null;
      _manualRotateDeg = 0;
      _previewReelsMode = true;
      _cropScale = 1.0;
      _cropOffset = Offset.zero;
    });
  }

  Future<void> _togglePlay() async {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;

    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  int _normDeg(int deg) => ((deg % 360) + 360) % 360;

  /// Повернуть предпросмотр на 90° по часовой
  void _rotate90() {
    setState(() {
      _manualRotateDeg = (_manualRotateDeg + 90) % 360;
    });
  }

  void _toggleMode(bool reels) {
    setState(() {
      _previewReelsMode = reels;
      if (_previewReelsMode) {
        _cropScale = 1.0;
        _cropOffset = Offset.zero;
      }
    });
  }

  void _toggleGrid() {
    setState(() => _showGrid = !_showGrid);
  }

  /// double tap zoom like Instagram: 1x <-> 2x
  void _doubleTapZoom({
    required VideoPlayerController controller,
    required Size viewport,
    required TapDownDetails details,
  }) {
    if (!_previewReelsMode) return;

    final target = (_cropScale < 1.25) ? 2.0 : 1.0;

    final beginScale = _cropScale;
    final beginOffset = _cropOffset;

    final local = details.localPosition;
    final center = Offset(viewport.width / 2, viewport.height / 2);
    final fromCenter = local - center;

    final scaleRatio = target / beginScale;
    Offset nextOffset = beginOffset - fromCenter * (scaleRatio - 1.0);

    nextOffset = _clampOffsetForFill(
      controller: controller,
      viewport: viewport,
      scale: target,
      offset: nextOffset,
    );

    _zoomTween = Tween<double>(begin: beginScale, end: target).animate(
      CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOut),
    );
    _offsetTween = Tween<Offset>(begin: beginOffset, end: nextOffset).animate(
      CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOut),
    );

    _zoomAnim.forward(from: 0);
  }

  /// clamp чтобы в Fill не появлялись пустые поля
  Offset _clampOffsetForFill({
    required VideoPlayerController controller,
    required Size viewport,
    required double scale,
    required Offset offset,
  }) {
    final s = controller.value.size;
    double vw = s.width;
    double vh = s.height;
    if (vw <= 0 || vh <= 0) return offset;

    // Учитываем только ручной поворот для предпросмотра
    final swap = (_manualRotateDeg == 90 || _manualRotateDeg == 270);
    if (swap) {
      final tmp = vw;
      vw = vh;
      vh = tmp;
    }

    final videoAR = vw / vh;
    final viewAR = viewport.width / viewport.height;

    final coverFactor = (videoAR > viewAR) ? (videoAR / viewAR) : (viewAR / videoAR);
    final effectiveScale = coverFactor * scale;

    final extraW = (effectiveScale - 1.0) * viewport.width;
    final extraH = (effectiveScale - 1.0) * viewport.height;

    final maxDx = extraW / 2;
    final maxDy = extraH / 2;

    final dx = offset.dx.clamp(-maxDx, maxDx);
    final dy = offset.dy.clamp(-maxDy, maxDy);

    return Offset(dx.toDouble(), dy.toDouble());
  }

  Future<void> _uploadReel() async {
    final desc = _descriptionController.text.trim();

    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Выберите видео")),
      );
      return;
    }
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Введите описание")),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final userId = await PrefUtils.getUserId();
      final uid = (userId ?? 0);
      if (uid <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ошибка: user_id не найден")),
        );
        setState(() => _isUploading = false);
        return;
      }

      final firstName = PrefUtils().getUserFirstName();
      final lastName = PrefUtils().getUserLastName();

      final username = ('$firstName $lastName').trim().isNotEmpty
          ? ('$firstName $lastName').trim()
          : 'Пользователь';

      final photo = (await PrefUtils.getUserPhoto()) ??
          'https://sportotekaapp.ru/uploads/avatars/default_avatar.png';

      final cropMode = _previewReelsMode ? "fill" : "fit";

      // ✅ Отправляем все параметры как строки для избежания FormatException
      final formData = FormData.fromMap({
        "user_id": uid.toString(),
        "username": username,
        "description": desc,
        "user_avatar": photo,
        "rotate": _manualRotateDeg.toString(),
        "crop_mode": cropMode,
        "crop_scale": _cropScale.toString(),
        "crop_dx": _cropOffset.dx.toString(),
        "crop_dy": _cropOffset.dy.toString(),
        "video": await MultipartFile.fromFile(
          _videoFile!.path,
          filename: "reel.mp4",
        ),
      });

      final dio = Dio();

      final response = await dio.post(
        _uploadUrl,
        data: formData,
        onSendProgress: (sent, total) {
          if (!mounted) return;
          if (total <= 0) return;
          setState(() => _uploadProgress = sent / total);
        },
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
          validateStatus: (status) => true, // Не кидать исключения на HTTP ошибки
        ),
      );

      final data = response.data;
      
      // ✅ Более надежная проверка ответа
      bool success = false;
      if (data is Map) {
        success = data['success'] == true || data['success'] == 'true' || data['success'] == 1;
      } else if (data is String) {
        try {
          final jsonData = json.decode(data);
          success = jsonData['success'] == true;
        } catch (_) {}
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Видео загружено")),
        );
        widget.onUploadComplete();
        Navigator.pop(context);
      } else {
        String errorMsg = "Ошибка при загрузке";
        if (data is Map && data['error'] != null) {
          errorMsg = data['error'].toString();
        } else if (data is String) {
          errorMsg = data;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка сети: $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = !_isUploading &&
        _videoFile != null &&
        _descriptionController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          "Загрузка Reels",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_videoFile != null)
            IconButton(
              tooltip: _showGrid ? "Скрыть сетку" : "Показать сетку",
              onPressed: _toggleGrid,
              icon: Icon(
                Icons.grid_on_rounded,
                color: _showGrid ? AppColors.primaryGreen : AppColors.textSecondary,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _SectionTitle(
            title: "Видео",
            right: _videoFile == null ? "не выбрано" : "готово",
          ),
          const SizedBox(height: 8),
          _buildVideoCard(),
          const SizedBox(height: 16),
          const _SectionTitle(title: "Описание", right: ""),
          const SizedBox(height: 8),
          _buildDescriptionCard(),
          const SizedBox(height: 16),
          if (_isUploading) _buildUploadingCard(),
          if (_isUploading) const SizedBox(height: 12),
          _buildActions(canUpload),
        ],
      ),
    );
  }

  Widget _buildVideoCard() {
    final hasVideo = _videoFile != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasVideo)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isUploading ? null : _pickVideo,
              child: Container(
                height: 210,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryGreen.withOpacity(0.18),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.video_call_outlined,
                        size: 44,
                        color: AppColors.primaryGreen,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Выбрать видео",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "MP4 / MOV — из галереи",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            _buildVideoPreview(),

          const SizedBox(height: 12),

          // ✅ ВСЕ КНОПКИ УДАЛЕНЫ - только кнопки замены и удаления
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickVideo,
                  icon: const Icon(Icons.change_circle_outlined),
                  label: const Text("Заменить"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isUploading || _videoFile == null) ? null : _removeVideo,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text("Убрать"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.25)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    final c = _videoController;

    if (_previewReelsMode) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: LayoutBuilder(
            builder: (ctx, cons) {
              final viewport = Size(cons.maxWidth, cons.maxHeight);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black),

                  if (c != null && c.value.isInitialized)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlay,
                      onDoubleTapDown: (d) => _doubleTapZoom(
                        controller: c,
                        viewport: viewport,
                        details: d,
                      ),
                      onScaleStart: (d) {
                        _startScale = _cropScale;
                        _startOffset = _cropOffset;
                        _startFocal = d.focalPoint;
                      },
                      onScaleUpdate: (d) {
                        final nextScale = (_startScale * d.scale).clamp(_minScale, _maxScale);
                        final delta = d.focalPoint - _startFocal;
                        var nextOffset = _startOffset + delta;

                        nextOffset = _clampOffsetForFill(
                          controller: c,
                          viewport: viewport,
                          scale: nextScale.toDouble(),
                          offset: nextOffset,
                        );

                        setState(() {
                          _cropScale = nextScale.toDouble();
                          _cropOffset = nextOffset;
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _InstagramFillVideo(
                            controller: c,
                            manualRotateDeg: _manualRotateDeg,
                            scale: _cropScale,
                            offset: _cropOffset,
                          ),

                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.20),
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.30),
                                    ],
                                    stops: const [0.0, 0.62, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          if (_showGrid)
                            const Positioned.fill(
                              child: IgnorePointer(child: _InstaGridOverlay()),
                            ),

                          Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 160),
                              opacity: c.value.isPlaying ? 0.0 : 1.0,
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                "FILL 9:16  •  x${_cropScale.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    }

    final ar = (c != null && c.value.isInitialized && c.value.aspectRatio > 0)
        ? c.value.aspectRatio
        : 16 / 9;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: ar,
        child: _previewStackFit(c),
      ),
    );
  }

  Widget _previewStackFit(VideoPlayerController? c) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),

        if (c != null && c.value.isInitialized)
          GestureDetector(
            onTap: _togglePlay,
            child: _FitVideoWithRotate(
              controller: c,
              manualRotateDeg: _manualRotateDeg,
            ),
          )
        else
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),

        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.transparent,
                    Colors.black.withOpacity(0.25),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),

        if (c != null && c.value.isInitialized)
          Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: c.value.isPlaying ? 0.0 : 1.0,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),

        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              "FIT  •  rotate=$_manualRotateDeg°",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [AppColors.cardShadow],
      ),
      child: TextField(
        controller: _descriptionController,
        enabled: !_isUploading,
        maxLines: 4,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: "Например: Лучший момент тренировки / гол / техника…",
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildUploadingCard() {
    final percent = (_uploadProgress * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Загрузка…",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (_uploadProgress <= 0 || _uploadProgress.isNaN) ? null : _uploadProgress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$percent%",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool canUpload) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isUploading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text("Отмена"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canUpload ? _uploadReel : null,
            icon: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text("Загрузить"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String right;

  const _SectionTitle({
    required this.title,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        if (right.isNotEmpty)
          Text(
            right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _InstagramFillVideo extends StatelessWidget {
  final VideoPlayerController controller;
  final int manualRotateDeg;
  final double scale;
  final Offset offset;

  const _InstagramFillVideo({
    required this.controller,
    required this.manualRotateDeg,
    required this.scale,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.value.isInitialized) return const SizedBox();

        final rotRad = manualRotateDeg * math.pi / 180.0;

        final s = controller.value.size;
        double w = s.width;
        double h = s.height;
        if (w <= 0 || h <= 0) return const SizedBox();

        final swap = manualRotateDeg == 90 || manualRotateDeg == 270;
        final rw = swap ? h : w;
        final rh = swap ? w : h;

        final video = SizedBox(
          width: rw,
          height: rh,
          child: Transform.rotate(
            angle: rotRad,
            alignment: Alignment.center,
            child: VideoPlayer(controller),
          ),
        );

        return ClipRect(
          child: Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: scale,
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
      },
    );
  }
}

class _FitVideoWithRotate extends StatelessWidget {
  final VideoPlayerController controller;
  final int manualRotateDeg;

  const _FitVideoWithRotate({
    required this.controller,
    required this.manualRotateDeg,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.value.isInitialized) return const SizedBox();

        final rotRad = manualRotateDeg * math.pi / 180.0;

        final s = controller.value.size;
        double w = s.width;
        double h = s.height;
        if (w <= 0 || h <= 0) return const SizedBox();

        final swap = manualRotateDeg == 90 || manualRotateDeg == 270;
        final rw = swap ? h : w;
        final rh = swap ? w : h;

        final video = SizedBox(
          width: rw,
          height: rh,
          child: Transform.rotate(
            angle: rotRad,
            alignment: Alignment.center,
            child: VideoPlayer(controller),
          ),
        );

        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: video,
          ),
        );
      },
    );
  }
}

class _InstaGridOverlay extends StatelessWidget {
  const _InstaGridOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 1;

    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(w / 3, 0), Offset(w / 3, h), paint);
    canvas.drawLine(Offset(2 * w / 3, 0), Offset(2 * w / 3, h), paint);
    canvas.drawLine(Offset(0, h / 3), Offset(w, h / 3), paint);
    canvas.drawLine(Offset(0, 2 * h / 3), Offset(w, 2 * h / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}