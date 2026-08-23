import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../data/services/video_lessons_service.dart';
import 'cmr_video_lessons_theme.dart';

class AddEditVideoLessonScreen extends StatefulWidget {
  final int folderId;
  final int userId;
  final int? lessonId;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialDuration;
  final VoidCallback? onUploadComplete;
  final VoidCallback? onClose;
  final bool embedded;

  const AddEditVideoLessonScreen({
    super.key,
    required this.folderId,
    required this.userId,
    this.lessonId,
    this.initialTitle,
    this.initialDescription,
    this.initialDuration,
    this.onUploadComplete,
    this.onClose,
    this.embedded = false,
  });

  @override
  State<AddEditVideoLessonScreen> createState() =>
      _AddEditVideoLessonScreenState();
}

class _AddEditVideoLessonScreenState extends State<AddEditVideoLessonScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _durationController;

  File? _videoFile;
  VideoPlayerController? _videoController;

  bool _isUploading = false;
  double _uploadProgress = 0;

  bool get isEdit => widget.lessonId != null;
  bool get hasVideo => _videoFile != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
    _durationController =
        TextEditingController(text: widget.initialDuration ?? '');

    _titleController.addListener(_refresh);
    _descriptionController.addListener(_refresh);
    _durationController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.removeListener(_refresh);
    _descriptionController.removeListener(_refresh);
    _durationController.removeListener(_refresh);
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _disposeVideoController();
    super.dispose();
  }

  void _disposeVideoController() {
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      controller.pause();
      controller.dispose();
    }
  }

  void _close([bool? result]) {
    if (widget.embedded) {
      widget.onClose?.call();
      return;
    }
    Navigator.of(context).pop(result);
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);
      _disposeVideoController();

      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoFile = file;
        _videoController = controller;
      });

      await controller.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _showSnack('Не удалось выбрать видео: $e');
    }
  }

  void _removeVideo() {
    _disposeVideoController();
    setState(() => _videoFile = null);
  }

  Future<void> _togglePlay() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final duration = _durationController.text.trim();

    if (title.isEmpty) {
      _showSnack('Введите название урока');
      return;
    }
    if (_videoFile == null) {
      _showSnack('Выберите видео');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final success = !isEdit
          ? await VideoLessonsService.addLessonWithChunks(
              folderId: widget.folderId,
              userId: widget.userId,
              title: title,
              description: description,
              videoFile: _videoFile!,
              duration: duration,
              onProgress: _setProgress,
            )
          : await VideoLessonsService.updateLessonWithChunks(
              id: widget.lessonId!,
              title: title,
              description: description,
              duration: duration,
              videoFile: _videoFile!,
              onProgress: _setProgress,
            );

      if (!mounted) return;
      if (!success) {
        _showSnack('Не удалось сохранить урок');
        return;
      }

      setState(() => _uploadProgress = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? 'Урок обновлён' : 'Урок добавлен',
            style: CmrVideoText.body(11, color: Colors.white),
          ),
          backgroundColor: CmrVideoColors.greenDark,
        ),
      );

      widget.onUploadComplete?.call();
      if (!widget.embedded) _close(true);
    } catch (e) {
      if (mounted) _showSnack('Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  void _setProgress(double progress) {
    if (!mounted) return;
    setState(() => _uploadProgress = progress);
  }

  Future<void> _delete() async {
    if (!isEdit) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CmrVideoDialogShell(
        title: 'Удалить урок?',
        subtitle: 'Это действие нельзя отменить',
        dotColor: CmrVideoColors.red,
        child: Text(
          'Видео и связанные с ним данные будут удалены из библиотеки.',
          style: CmrVideoText.body(10.6),
        ),
        actions: <Widget>[
          CmrVideoTextButton(
            label: 'Отмена',
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          CmrVideoTextButton(
            label: 'Удалить',
            danger: true,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isUploading = true);

    try {
      final success = await VideoLessonsService.deleteLesson(widget.lessonId!);
      if (!mounted) return;
      if (success) {
        widget.onUploadComplete?.call();
        _close(true);
      } else {
        _showSnack('Не удалось удалить урок');
      }
    } catch (e) {
      if (mounted) _showSnack('Ошибка удаления: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: CmrVideoText.body(11, color: Colors.white))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        !_isUploading && _titleController.text.trim().isNotEmpty && hasVideo;

    final body = Column(
      children: <Widget>[
        if (!widget.embedded) _buildHeader(canSave),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              widget.embedded ? 14 : 16,
              widget.embedded ? 12 : 14,
              widget.embedded ? 14 : 16,
              24,
            ),
            children: <Widget>[
              CmrVideoSectionTitle(
                title: 'Видеофайл',
                subtitle: hasVideo
                    ? 'Видео выбрано и готово к загрузке'
                    : 'MP4 / MOV из галереи устройства',
                trailing: hasVideo
                    ? CmrVideoDotCluster(color: CmrVideoColors.green)
                    : null,
              ),
              const SizedBox(height: 10),
              _buildVideoCard(),
              const SizedBox(height: 18),
              const CmrVideoSectionTitle(
                title: 'Информация об уроке',
                subtitle: 'Название, описание и длительность',
              ),
              const SizedBox(height: 10),
              _buildFields(),
              if (_isUploading) ...<Widget>[
                const SizedBox(height: 14),
                _buildUploadingCard(),
              ],
              const SizedBox(height: 14),
              _buildActions(canSave),
            ],
          ),
        ),
      ],
    );

    return CmrVideoThemeScope(
      child: Scaffold(
        backgroundColor: CmrVideoColors.bg,
        body: SafeArea(top: !widget.embedded, child: body),
      ),
    );
  }

  Widget _buildHeader(bool canSave) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: CmrVideoColors.line, width: .65),
        ),
      ),
      child: Row(
        children: <Widget>[
          CmrVideoIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Назад',
            onTap: _isUploading ? null : _close,
          ),
          const SizedBox(width: 11),
          const CmrVideoDot(size: 7),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isEdit ? 'Редактировать урок' : 'Добавить урок',
                  style: CmrVideoText.title(16),
                ),
                Text(
                  'Видеоуроки · рабочая область',
                  style: CmrVideoText.body(9.8),
                ),
              ],
            ),
          ),
          if (isEdit) ...<Widget>[
            CmrVideoIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Удалить',
              danger: true,
              onTap: _isUploading ? null : _delete,
            ),
            const SizedBox(width: 7),
          ],
          CmrVideoIconButton(
            icon: Icons.save_rounded,
            tooltip: 'Сохранить',
            accent: true,
            onTap: canSave ? _save : null,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard() {
    return CmrVideoSurface(
      color: CmrVideoColors.soft,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!hasVideo)
            Material(
              color: CmrVideoColors.greenSoft2,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _isUploading ? null : _pickVideo,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CmrVideoDotCluster(),
                        const SizedBox(height: 13),
                        Text('Выбрать видео', style: CmrVideoText.title(14)),
                        const SizedBox(height: 4),
                        Text(
                          'Нажмите, чтобы выбрать файл',
                          style: CmrVideoText.body(10.2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            _buildVideoPreview(),
          if (hasVideo) ...<Widget>[
            const SizedBox(height: 9),
            Row(
              children: <Widget>[
                Expanded(
                  child: CmrVideoTextButton(
                    label: 'Заменить',
                    onTap: _isUploading ? null : _pickVideo,
                    leading: const Icon(Icons.swap_horiz_rounded),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: CmrVideoTextButton(
                    label: 'Убрать',
                    danger: true,
                    onTap: _isUploading ? null : _removeVideo,
                    leading: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    final controller = _videoController;
    final aspectRatio = controller != null &&
            controller.value.isInitialized &&
            controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Container(color: Colors.black),
            if (controller != null && controller.value.isInitialized)
              GestureDetector(
                onTap: _togglePlay,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
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
            if (controller != null && controller.value.isInitialized)
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: controller.value.isPlaying ? 0 : 1,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.34),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFields() {
    final fieldStyle = CmrVideoText.body(
      11,
      color: CmrVideoColors.text,
      weight: FontWeight.w500,
    );

    return CmrVideoSurface(
      color: Colors.white,
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          TextField(
            controller: _titleController,
            enabled: !_isUploading,
            cursorColor: CmrVideoColors.greenDark,
            style: fieldStyle,
            decoration: cmrVideoInputDecoration(
              'Название урока',
              hint: 'Например: Техника удара по мячу',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            enabled: !_isUploading,
            minLines: 5,
            maxLines: 9,
            cursorColor: CmrVideoColors.greenDark,
            style: fieldStyle,
            decoration: cmrVideoInputDecoration(
              'Описание',
              hint: 'Кратко опишите содержание и задачу урока',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _durationController,
            enabled: !_isUploading,
            cursorColor: CmrVideoColors.greenDark,
            style: fieldStyle,
            decoration: cmrVideoInputDecoration(
              'Длительность',
              hint: 'Например: 10:30 или 12 мин',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingCard() {
    final safeProgress = _uploadProgress.isNaN ? 0.0 : _uploadProgress;
    final percent = (safeProgress * 100).clamp(0, 100).toStringAsFixed(0);

    return CmrVideoSurface(
      color: CmrVideoColors.greenSoft2,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const CmrVideoDot(size: 6),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  safeProgress > 0
                      ? 'Загрузка видео · $percent%'
                      : 'Подготовка к загрузке',
                  style: CmrVideoText.body(
                    10.6,
                    color: CmrVideoColors.text,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: safeProgress > 0 ? safeProgress : null,
              minHeight: 5,
              backgroundColor: CmrVideoColors.soft2,
              color: CmrVideoColors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool canSave) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (isEdit)
          CmrVideoTextButton(
            label: 'Удалить',
            danger: true,
            onTap: _isUploading ? null : _delete,
          ),
        if (isEdit) const SizedBox(width: 7),
        CmrVideoTextButton(
          label: 'Отмена',
          onTap: _isUploading ? null : _close,
        ),
        const SizedBox(width: 7),
        CmrVideoTextButton(
          label: isEdit ? 'Сохранить' : 'Добавить урок',
          primary: true,
          onTap: canSave ? _save : null,
          leading: _isUploading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Colors.white,
                  ),
                )
              : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded),
        ),
      ],
    );
  }
}
