import 'dart:io';
import 'dart:math' as math;
import 'dart:convert'; 
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
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

  TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = const Color(0xFF0B0F14),
    double height = 1.25,
  }) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: height,
      letterSpacing: 0,
    );
  }

  Widget _dot(
    Color color, {
    double size = 5,
    bool glow = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withOpacity(.18),
                  blurRadius: size * 2,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _brandDots({
    Color color = const Color(0xFF00A750),
  }) {
    const values = <List<double>>[
      <double>[3.5, .34],
      <double>[4.5, .48],
      <double>[5.5, .68],
      <double>[6.5, 1],
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < values.length; i++) ...[
          Container(
            width: values[i][0],
            height: values[i][0],
            decoration: BoxDecoration(
              color: color.withOpacity(values[i][1]),
              shape: BoxShape.circle,
            ),
          ),
          if (i != values.length - 1)
            const SizedBox(width: 3),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = !_isUploading &&
        _videoFile != null &&
        _descriptionController.text.trim().isNotEmpty;

    final base = Theme.of(context);

    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(
          fontFamily: AppTypography.fontFamily,
          bodyColor: const Color(0xFF0B0F14),
          displayColor: const Color(0xFF0B0F14),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _header(canUpload),
              const Divider(
                height: 1,
                thickness: .6,
                color: Color(0xFFEEF1EF),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    _section(
                      title: 'Видео',
                      subtitle: _videoFile == null
                          ? 'Выберите ролик из галереи'
                          : 'Видео готово к публикации',
                      color: _videoFile == null
                          ? const Color(0xFF98A2B3)
                          : const Color(0xFFF59E0B),
                      child: _buildVideoCard(),
                    ),
                    const SizedBox(height: 8),
                    _section(
                      title: 'Описание',
                      subtitle: 'Коротко опишите момент или тренировку',
                      color: _descriptionController.text.trim().isEmpty
                          ? const Color(0xFF98A2B3)
                          : const Color(0xFF00A750),
                      child: _buildDescriptionCard(),
                    ),
                    if (_isUploading) ...[
                      const SizedBox(height: 8),
                      _buildUploadingCard(),
                    ],
                    const SizedBox(height: 10),
                    _buildActions(canUpload),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(bool canUpload) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF7F9F8),
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: _isUploading ? null : () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(9),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: Color(0xFF0B0F14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _brandDots(),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Новый Reels',
                  style: _t(
                    14.2,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Подготовьте видео и описание',
                  style: _t(
                    9.5,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          if (_videoFile != null)
            Material(
              color: _showGrid
                  ? const Color(0xFFF3FAF6)
                  : const Color(0xFFF7F9F8),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _toggleGrid,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      _dot(
                        _showGrid
                            ? const Color(0xFF00A750)
                            : const Color(0xFF98A2B3),
                        size: 4.5,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Сетка',
                        style: _t(
                          9.1,
                          weight: FontWeight.w600,
                          color: _showGrid
                              ? const Color(0xFF067A46)
                              : const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _dot(
                color,
                size: 6,
                glow: color != const Color(0xFF98A2B3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _t(
                        11.4,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: _t(
                        9.3,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildVideoCard() {
    final hasVideo = _videoFile != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasVideo)
            InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: _isUploading ? null : _pickVideo,
              child: Container(
                height: 210,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _brandDots(
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 9),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Выбрать видео',
                            style: _t(
                              11.2,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'MP4 / MOV · из галереи',
                            style: _t(
                              9.4,
                              color: const Color(0xFF667085),
                            ),
                          ),
                        ],
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
                child: _softAction(
                  label: 'Заменить',
                  color: const Color(0xFF067A46),
                  onTap: _isUploading ? null : _pickVideo,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _softAction(
                  label: 'Убрать',
                  color: const Color(0xFFD92D20),
                  onTap: (_isUploading || _videoFile == null)
                      ? null
                      : _removeVideo,
                  danger: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _softAction({
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool danger = false,
  }) {
    return Material(
      color: danger
          ? const Color(0xFFFFF1F1)
          : const Color(0xFFF3FAF6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dot(
                onTap == null
                    ? const Color(0xFF98A2B3)
                    : color,
                size: 4.5,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: _t(
                  9.4,
                  weight: FontWeight.w600,
                  color: onTap == null
                      ? const Color(0xFF98A2B3)
                      : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    final c = _videoController;

    if (_previewReelsMode) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
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
                                  fontWeight: FontWeight.w600,
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
      borderRadius: BorderRadius.circular(9),
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
                fontWeight: FontWeight.w600,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: TextField(
        controller: _descriptionController,
        enabled: !_isUploading,
        maxLines: 4,
        style: _t(
          10.2,
          color: const Color(0xFF0B0F14),
        ),
        decoration: InputDecoration(
          hintText: "Например: Лучший момент тренировки / гол / техника…",
          hintStyle: _t(
            9.7,
            color: const Color(0xFF98A2B3),
          ),
          filled: true,
          fillColor: const Color(0xFFF7F9F8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
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
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _dot(
                const Color(0xFF00A750),
                size: 5,
                glow: true,
              ),
              const SizedBox(width: 7),
              Text(
                'Загрузка…',
                style: _t(
                  10.5,
                  weight: FontWeight.w600,
                ),
              ),
            ],
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
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool canUpload) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _softAction(
          label: 'Отмена',
          color: const Color(0xFF667085),
          onTap: _isUploading ? null : () => Navigator.pop(context),
        ),
        const SizedBox(width: 6),
        FilledButton(
          onPressed: canUpload ? _uploadReel : null,
          style: FilledButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF00A750),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Опубликовать',
                  style: _t(
                    9.8,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
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