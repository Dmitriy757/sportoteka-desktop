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


class ReelComposerController extends ChangeNotifier {
  Future<void> Function()? _submitHandler;
  bool _saving = false;
  bool _disposed = false;

  bool get saving => _saving;
  bool get attached => _submitHandler != null;

  Future<void> submit() async {
    final handler = _submitHandler;
    if (handler != null && !_saving) {
      await handler();
    }
  }

  void _attach(Future<void> Function() handler) {
    if (_disposed) return;
    _submitHandler = handler;
  }

  void _detach() {
    if (_disposed) return;
    _submitHandler = null;
    _saving = false;
  }

  void _setSaving(bool value) {
    if (_disposed || _saving == value) return;
    _saving = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _submitHandler = null;
    super.dispose();
  }
}

class UploadReelScreen extends StatefulWidget {
  final VoidCallback onUploadComplete;
  final ReelComposerController? composerController;
  final bool embedded;
  final bool hideChrome;
  final VoidCallback? onClose;
  final bool active;

  const UploadReelScreen({
    super.key,
    required this.onUploadComplete,
    this.composerController,
    this.embedded = false,
    this.hideChrome = false,
    this.onClose,
    this.active = true,
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
    widget.composerController?._attach(_uploadReel);

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
  void didUpdateWidget(covariant UploadReelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.composerController != widget.composerController) {
      oldWidget.composerController?._detach();
      widget.composerController?._attach(_uploadReel);
    }
    if (oldWidget.active != widget.active) {
      final controller = _videoController;
      if (controller != null && controller.value.isInitialized) {
        if (widget.active) {
          controller.play();
        } else {
          controller.pause();
        }
      }
    }
  }

  @override
  void dispose() {
    widget.composerController?._detach();
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
    widget.composerController?._setSaving(true);

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
        if (!widget.embedded) {
          Navigator.pop(context);
        }
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
      widget.composerController?._setSaving(false);
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

  void _closeComposer() {
    if (widget.embedded) {
      widget.onClose?.call();
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = !_isUploading &&
        _videoFile != null &&
        _descriptionController.text.trim().isNotEmpty;

    final base = Theme.of(context);

    Widget content() {
      return Column(
        children: [
          if (_isUploading) _buildSlimUploadProgress(),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
              children: [
                _buildInstagramVideoComposer(),
                const SizedBox(height: 12),
                _buildInstagramCaption(),
                const SizedBox(height: 18),
                if (_videoFile == null)
                  Center(
                    child: Text(
                      'Сначала выберите ролик из галереи',
                      style: _t(
                        9.4,
                        color: const Color(0xFF98A2B3),
                      ),
                    ),
                  )
                else if (_descriptionController.text.trim().isEmpty)
                  Center(
                    child: Text(
                      'Добавьте короткую подпись, чтобы опубликовать Reels',
                      textAlign: TextAlign.center,
                      style: _t(
                        9.4,
                        color: const Color(0xFF98A2B3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    final themedContent = Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(
          fontFamily: AppTypography.fontFamily,
          bodyColor: const Color(0xFF0B0F14),
          displayColor: const Color(0xFF0B0F14),
        ),
      ),
      child: content(),
    );

    if (widget.hideChrome) {
      return Container(
        color: Colors.white,
        child: themedContent,
      );
    }

    if (widget.embedded) {
      return SafeArea(
        bottom: false,
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              _instagramHeader(canUpload),
              const Divider(
                height: 1,
                thickness: .6,
                color: Color(0xFFEEF1EF),
              ),
              Expanded(child: themedContent),
            ],
          ),
        ),
      );
    }

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
              _instagramHeader(canUpload),
              const Divider(
                height: 1,
                thickness: .6,
                color: Color(0xFFEEF1EF),
              ),
              Expanded(child: content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instagramHeader(bool canUpload) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Назад',
              onPressed: _isUploading ? null : _closeComposer,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 2),
            _brandDots(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Новый Reels',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(
                  14.6,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: canUpload ? _uploadReel : null,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00A750),
                disabledForegroundColor: const Color(0xFFB8C1BC),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00A750),
                      ),
                    )
                  : Text(
                      'Поделиться',
                      style: _t(
                        10.5,
                        weight: FontWeight.w700,
                        color: canUpload
                            ? const Color(0xFF00A750)
                            : const Color(0xFFB8C1BC),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlimUploadProgress() {
    final value = (_uploadProgress <= 0 || _uploadProgress.isNaN)
        ? null
        : _uploadProgress.clamp(0.0, 1.0);

    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        value: value,
        minHeight: 3,
        backgroundColor: const Color(0xFFE9EEF3),
        color: const Color(0xFF00A750),
      ),
    );
  }

  Widget _buildInstagramVideoComposer() {
    final hasVideo = _videoFile != null;

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: hasVideo
                ? _buildVideoPreview()
                : AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Material(
                      color: const Color(0xFFF2F6F3),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isUploading ? null : _pickVideo,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFF4F8F5),
                                      Color(0xFFEAF5EE),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(.06),
                                          blurRadius: 18,
                                          offset: const Offset(0, 7),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      size: 30,
                                      color: Color(0xFF00A750),
                                    ),
                                  ),
                                  const SizedBox(height: 13),
                                  Text(
                                    'Выбрать видео',
                                    style: _t(
                                      12.2,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'MP4 / MOV · из галереи',
                                    style: _t(
                                      9.5,
                                      color: const Color(0xFF667085),
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
          ),
        ),
        if (hasVideo) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _reelTool(
                  icon: Icons.video_library_outlined,
                  label: 'Заменить',
                  onTap: _isUploading ? null : _pickVideo,
                ),
                _reelTool(
                  icon: _previewReelsMode
                      ? Icons.crop_portrait_rounded
                      : Icons.fit_screen_rounded,
                  label: _previewReelsMode ? 'Заполнить' : 'Вписать',
                  active: _previewReelsMode,
                  onTap: _isUploading
                      ? null
                      : () => _toggleMode(!_previewReelsMode),
                ),
                _reelTool(
                  icon: Icons.rotate_90_degrees_cw_rounded,
                  label: 'Повернуть',
                  onTap: _isUploading ? null : _rotate90,
                ),
                _reelTool(
                  icon: Icons.grid_3x3_rounded,
                  label: 'Сетка',
                  active: _showGrid,
                  onTap: _isUploading ? null : _toggleGrid,
                ),
                _reelTool(
                  icon: Icons.restart_alt_rounded,
                  label: 'Сбросить',
                  onTap: _isUploading ? null : _resetCrop,
                ),
                _reelTool(
                  icon: Icons.delete_outline_rounded,
                  label: 'Удалить',
                  danger: true,
                  onTap: _isUploading ? null : _removeVideo,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _reelTool({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool active = false,
    bool danger = false,
  }) {
    final foreground = danger
        ? const Color(0xFFD92D20)
        : active
            ? const Color(0xFF067A46)
            : const Color(0xFF344054);
    final background = danger
        ? const Color(0xFFFFF3F2)
        : active
            ? const Color(0xFFF1FBF6)
            : const Color(0xFFF6F7F6);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: onTap == null ? const Color(0xFFF3F4F6) : background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: onTap == null
                      ? const Color(0xFFB8C1BC)
                      : foreground,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: _t(
                    9.1,
                    weight: FontWeight.w600,
                    color: onTap == null
                        ? const Color(0xFFB8C1BC)
                        : foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstagramCaption() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFEEF1EF), width: .7),
          bottom: BorderSide(color: Color(0xFFEEF1EF), width: .7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1FBF6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: Color(0xFF00A750),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: _descriptionController,
                  enabled: !_isUploading,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 500,
                  style: _t(
                    10.8,
                    color: const Color(0xFF111827),
                    height: 1.38,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Добавьте подпись…  #тренировка #гол',
                    hintStyle: _t(
                      10.4,
                      color: const Color(0xFF98A2B3),
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 43),
            child: Row(
              children: [
                Text(
                  '${_descriptionController.text.characters.length}/500',
                  style: _t(
                    8.8,
                    color: const Color(0xFF98A2B3),
                  ),
                ),
                const Spacer(),
                if (_videoFile != null)
                  Text(
                    _previewReelsMode ? '9:16 · Reels' : 'Исходный формат',
                    style: _t(
                      8.8,
                      color: const Color(0xFF98A2B3),
                    ),
                  ),
              ],
            ),
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
                        final nextScale =
                            (_startScale * d.scale).clamp(_minScale, _maxScale);
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
                                      Colors.black.withOpacity(0.10),
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.18),
                                    ],
                                    stops: const [0.0, 0.68, 1.0],
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
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.34),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 9,
                            bottom: 9,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(.42),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '×${_cropScale.toStringAsFixed(1)}',
                                style: _t(
                                  8.7,
                                  weight: FontWeight.w600,
                                  color: Colors.white,
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
        child: Stack(
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
            if (c != null && c.value.isInitialized)
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: c.value.isPlaying ? 0.0 : 1.0,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.34),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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