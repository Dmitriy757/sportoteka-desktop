import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'cmr_video_lessons_theme.dart';
import '../../data/services/video_lessons_service.dart';

class AddEditVideoLessonScreen extends StatefulWidget {
  final int folderId;
  final int userId;
  final int? lessonId;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialDuration;
  final VoidCallback? onUploadComplete;
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
  double _uploadProgress = 0.0;

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
    if (!mounted) return;
    setState(() {});
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
    final c = _videoController;
    _videoController = null;
    if (c != null) {
      c.pause();
      c.dispose();
    }
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

      if (!mounted) return;

      setState(() {
        _videoFile = file;
        _videoController = controller;
      });

      await controller.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      _showSnack("Не удалось выбрать видео: $e");
    }
  }

  void _removeVideo() {
    _disposeVideoController();
    setState(() {
      _videoFile = null;
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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final duration = _durationController.text.trim();

    if (title.isEmpty) {
      _showSnack("Введите название урока");
      return;
    }

    if (_videoFile == null) {
      _showSnack("Выберите видео");
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      bool success = false;

      if (!isEdit) {
        success = await VideoLessonsService.addLessonWithChunks(
          folderId: widget.folderId,
          userId: widget.userId,
          title: title,
          description: description,
          videoFile: _videoFile!,
          duration: duration,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _uploadProgress = progress;
            });
          },
        );
      } else {
        success = await VideoLessonsService.updateLessonWithChunks(
          id: widget.lessonId!,
          title: title,
          description: description,
          duration: duration,
          videoFile: _videoFile!,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _uploadProgress = progress;
            });
          },
        );
      }

      if (!mounted) return;

      if (success) {
        setState(() {
          _uploadProgress = 1.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? "Урок обновлён" : "Урок добавлен"),
            backgroundColor: CmrVideoColors.green,
          ),
        );

        widget.onUploadComplete?.call();
        Navigator.pop(context, true);
      } else {
        _showSnack("Не удалось сохранить урок");
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack("Ошибка: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<void> _delete() async {
    if (!isEdit) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Удалить урок?"),
        content: const Text("Это действие нельзя отменить"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: CmrVideoColors.red),
            child: const Text("Удалить"),
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
        Navigator.pop(context, true);
      } else {
        _showSnack("Не удалось удалить урок");
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack("Ошибка удаления: $e");
    } finally {
      if (!mounted) return;
      setState(() => _isUploading = false);
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        !_isUploading && _titleController.text.trim().isNotEmpty && hasVideo;

    return Scaffold(
      backgroundColor: CmrVideoColors.panel,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: CmrVideoColors.bg,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              iconTheme: const IconThemeData(color: CmrVideoColors.text),
              title: Text(
                isEdit ? "Редактировать урок" : "Добавить урок",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: CmrVideoColors.text,
                ),
              ),
              actions: [
                if (isEdit)
                  IconButton(
                    onPressed: _isUploading ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: CmrVideoColors.red,
                  ),
              ],
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _SectionTitle(
            title: "Видео",
            right: _videoFile != null ? "файл" : "не выбрано",
          ),
          const SizedBox(height: 8),
          _buildVideoCard(),
          const SizedBox(height: 16),
          const _SectionTitle(title: "Название", right: ""),
          const SizedBox(height: 8),
          _buildTitleCard(),
          const SizedBox(height: 16),
          const _SectionTitle(title: "Описание", right: ""),
          const SizedBox(height: 8),
          _buildDescriptionCard(),
          const SizedBox(height: 16),
          const _SectionTitle(title: "Длительность", right: ""),
          const SizedBox(height: 8),
          _buildDurationCard(),
          const SizedBox(height: 16),
          if (_isUploading) _buildUploadingCard(),
          if (_isUploading) const SizedBox(height: 12),
          _buildActions(canSave),
        ],
      ),
    );
  }

  Widget _buildVideoCard() {
    final hasLocalVideo = _videoFile != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CmrVideoColors.panel,
        borderRadius: BorderRadius.circular(12),
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasLocalVideo)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isUploading ? null : _pickVideo,
              child: Container(
                height: 210,
                decoration: BoxDecoration(
                  color: CmrVideoColors.green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.video_call_outlined,
                        size: 44,
                        color: CmrVideoColors.green,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Выбрать видео",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CmrVideoColors.text,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "MP4 / MOV — из галереи",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CmrVideoColors.muted,
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
          if (hasLocalVideo)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isUploading ? null : _pickVideo,
                    icon: const Icon(Icons.change_circle_outlined),
                    label: const Text("Заменить"),
                    style: FilledButton.styleFrom(backgroundColor: CmrVideoColors.soft,
                      foregroundColor: CmrVideoColors.muted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        (_isUploading || _videoFile == null) ? null : _removeVideo,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text("Убрать"),
                    style: FilledButton.styleFrom(backgroundColor: CmrVideoColors.soft,
                      foregroundColor: CmrVideoColors.red,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

    final ar = (c != null && c.value.isInitialized && c.value.aspectRatio > 0)
        ? c.value.aspectRatio
        : 16 / 9;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: ar,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black),
            if (c != null && c.value.isInitialized)
              GestureDetector(
                onTap: _togglePlay,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
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
          ],
        ),
      ),
    );
  }

  Widget _buildTitleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: CmrVideoColors.panel,
        borderRadius: BorderRadius.circular(12),
        
      ),
      child: TextField(
        controller: _titleController,
        enabled: !_isUploading,
        style: const TextStyle(
          color: CmrVideoColors.text,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        decoration: const InputDecoration(
          hintText: "Например: Техника удара по мячу",
          hintStyle: TextStyle(
            color: CmrVideoColors.subtle,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CmrVideoColors.panel,
        borderRadius: BorderRadius.circular(12),
        
      ),
      child: TextField(
        controller: _descriptionController,
        enabled: !_isUploading,
        maxLines: 4,
        style: const TextStyle(
          color: CmrVideoColors.text,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: "Описание урока...",
          hintStyle: const TextStyle(
            color: CmrVideoColors.subtle,
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: CmrVideoColors.bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDurationCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: CmrVideoColors.panel,
        borderRadius: BorderRadius.circular(12),
        
      ),
      child: TextField(
        controller: _durationController,
        enabled: !_isUploading,
        style: const TextStyle(
          color: CmrVideoColors.text,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          hintText: "Например: 10:30 или 12 мин",
          hintStyle: TextStyle(
            color: CmrVideoColors.subtle,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildUploadingCard() {
    final safeProgress = _uploadProgress.isNaN ? 0.0 : _uploadProgress;
    final percent = (safeProgress * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CmrVideoColors.panel,
        borderRadius: BorderRadius.circular(12),
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            safeProgress > 0
                ? "Загрузка видео... $percent%"
                : "Подготовка к загрузке...",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: CmrVideoColors.text,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: safeProgress > 0 ? safeProgress : null,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              color: CmrVideoColors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            safeProgress > 0 ? "$percent%" : "Подождите...",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CmrVideoColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool canSave) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: _isUploading ? null : () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: CmrVideoColors.soft,
              foregroundColor: CmrVideoColors.muted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text("Отмена"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canSave ? _save : null,
            icon: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded),
            label: Text(isEdit ? "Сохранить" : "Добавить"),
            style: ElevatedButton.styleFrom(
              backgroundColor: CmrVideoColors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: CmrVideoColors.subtle,
            ),
          ),
        ),
        if (right.isNotEmpty)
          Text(
            right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CmrVideoColors.muted,
            ),
          ),
      ],
    );
  }
}