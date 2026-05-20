import 'package:flutter/material.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import '../../data/models/video_folder_model.dart';
import '../../data/models/video_lesson_model.dart';
import '../../data/services/video_lessons_service.dart';
import 'widgets/create_video_folder_dialog.dart';
import 'add_edit_video_lesson_screen.dart';
import 'video_lesson_detail_screen.dart';

class VideoLessonFolderPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);

  static const lightGreen = Color(0xFFE8F5E9);
  static const superLightGreen = Color(0xFFF2FFF5);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);
  static const textSoft = Color(0xFF9CA3AF);

  static const background = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);
  static const danger = Color(0xFFE53935);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardShadowSoft = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 12,
      offset: Offset(0, 5),
    ),
  ];
}

class VideoLessonFolderScreen extends StatefulWidget {
  final VideoFolderModel folder;
  final int ownerUserId;
  final bool isMyMode;

  const VideoLessonFolderScreen({
    super.key,
    required this.folder,
    required this.ownerUserId,
    this.isMyMode = false,
  });

  @override
  State<VideoLessonFolderScreen> createState() =>
      _VideoLessonFolderScreenState();
}

class _VideoLessonFolderScreenState extends State<VideoLessonFolderScreen> {
  List<VideoFolderModel> subfolders = [];
  List<VideoLessonModel> lessons = [];
  bool isLoading = true;
  int currentUserId = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await PrefUtils.getUserId();
    currentUserId = id ?? 0;
    await _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final folders = await VideoLessonsService.getFolders(
        ownerId: widget.ownerUserId,
        parentId: widget.folder.id,
      );

      final lessonsData = await VideoLessonsService.getLessons(
        folderId: widget.folder.id,
      );

      subfolders = folders;
      lessons = lessonsData;
    } catch (e) {
      debugPrint('VideoLessonFolderScreen load error: $e');
      subfolders = [];
      lessons = [];
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _createSubfolder() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => CreateVideoFolderDialog(
        userId: currentUserId,
        parentId: widget.folder.id,
      ),
    );

    if (created == true) {
      await _loadData();
    }
  }

  Future<void> _addLesson() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditVideoLessonScreen(
          folderId: widget.folder.id,
          userId: currentUserId,
        ),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _renameFolder(VideoFolderModel folder) async {
    final controller = TextEditingController(text: folder.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: VideoLessonFolderPalette.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text(
          'Редактировать папку',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: VideoLessonFolderPalette.text,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Название папки',
            filled: true,
            fillColor: VideoLessonFolderPalette.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: VideoLessonFolderPalette.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: VideoLessonFolderPalette.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: VideoLessonFolderPalette.primaryGreen,
                width: 1.4,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: VideoLessonFolderPalette.textMuted,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: VideoLessonFolderPalette.greenGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(context, value);
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Сохранить',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.trim().isEmpty) return;

    try {
      final ok = await VideoLessonsService.updateFolder(
        id: folder.id,
        title: newTitle.trim(),
        color: folder.color,
        banner: folder.banner,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Папка обновлена' : 'Не удалось обновить папку'),
        ),
      );

      if (ok) {
        await _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обновления папки: $e')),
      );
    }
  }

  Future<void> _deleteFolder(VideoFolderModel folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: VideoLessonFolderPalette.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text(
          'Удалить папку?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: VideoLessonFolderPalette.text,
          ),
        ),
        content: Text(
          'Папка "${folder.title}" будет удалена.',
          style: const TextStyle(
            color: VideoLessonFolderPalette.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Отмена',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: VideoLessonFolderPalette.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VideoLessonFolderPalette.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ok = await VideoLessonsService.deleteFolder(folder.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Папка удалена' : 'Не удалось удалить папку'),
        ),
      );

      if (ok) {
        await _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления папки: $e')),
      );
    }
  }

  Color _parseColor(String hex) {
    try {
      final value = hex.replaceAll('#', '');
      return Color(int.parse('FF$value', radix: 16));
    } catch (_) {
      return VideoLessonFolderPalette.primaryGreen;
    }
  }

  Widget _whiteCard({
    required Widget child,
    EdgeInsets? padding,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: VideoLessonFolderPalette.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VideoLessonFolderPalette.border),
        boxShadow: VideoLessonFolderPalette.cardShadowSoft,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: card,
    );
  }

  Widget _sectionTitle(String title, {String? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: VideoLessonFolderPalette.text,
            ),
          ),
        ),
        if (action != null)
          Text(
            action,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: VideoLessonFolderPalette.textMuted,
            ),
          ),
      ],
    );
  }

  Widget _metricChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: VideoLessonFolderPalette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: VideoLessonFolderPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: VideoLessonFolderPalette.primaryGreen,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: VideoLessonFolderPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderHeader(bool canManage) {
    final color = _parseColor(widget.folder.color);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.18),
            VideoLessonFolderPalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VideoLessonFolderPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.folder_copy_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Папка видеоуроков',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: VideoLessonFolderPalette.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Уроки, вложенные папки и материалы',
                      style: TextStyle(
                        color: VideoLessonFolderPalette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: VideoLessonFolderPalette.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: VideoLessonFolderPalette.border),
                  ),
                  child: const Text(
                    'Управление',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: VideoLessonFolderPalette.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.folder.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VideoLessonFolderPalette.text,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(
                Icons.folder_open_rounded,
                'Папок: ${subfolders.length}',
              ),
              _metricChip(
                Icons.play_circle_fill_rounded,
                'Уроков: ${lessons.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(bool canManage) {
    if (!canManage) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: VideoLessonFolderPalette.greenGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ElevatedButton.icon(
              onPressed: _createSubfolder,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.create_new_folder_rounded),
              label: const Text(
                'Добавить папку',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _addLesson,
            style: OutlinedButton.styleFrom(
              foregroundColor: VideoLessonFolderPalette.primaryGreen,
              side: const BorderSide(
                color: VideoLessonFolderPalette.primaryGreen,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_to_queue_rounded),
            label: const Text(
              'Добавить урок',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderItem(VideoFolderModel folder, bool canManage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _whiteCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoLessonFolderScreen(
                folder: folder,
                ownerUserId: widget.ownerUserId,
                isMyMode: canManage,
              ),
            ),
          ).then((_) => _loadData());
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _parseColor(folder.color),
                      _parseColor(folder.color).withOpacity(0.78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: VideoLessonFolderPalette.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Папок: ${folder.subfoldersCount}, уроков: ${folder.lessonsCount}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: VideoLessonFolderPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (canManage)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _renameFolder(folder);
                    } else if (value == 'delete') {
                      _deleteFolder(folder);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Редактировать'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: VideoLessonFolderPalette.danger,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Удалить',
                            style: TextStyle(
                              color: VideoLessonFolderPalette.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: VideoLessonFolderPalette.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: VideoLessonFolderPalette.textMuted,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: VideoLessonFolderPalette.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLessonItem(VideoLessonModel lesson) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _whiteCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoLessonDetailScreen(lessonId: lesson.id),
            ),
          ).then((_) => _loadData());
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 90,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(14),
                  image: lesson.thumbnail.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(lesson.thumbnail),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: lesson.thumbnail.isEmpty
                    ? const Icon(
                        Icons.play_circle_fill_rounded,
                        size: 34,
                        color: VideoLessonFolderPalette.primaryGreen,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: VideoLessonFolderPalette.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${lesson.authorName} ${lesson.authorSurname}'.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: VideoLessonFolderPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Комментарии: ${lesson.commentsCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: VideoLessonFolderPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: VideoLessonFolderPalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.isMyMode && currentUserId == widget.ownerUserId;

    return Scaffold(
      backgroundColor: VideoLessonFolderPalette.background,
      appBar: AppBar(
        backgroundColor: VideoLessonFolderPalette.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: VideoLessonFolderPalette.text,
        title: Text(
          widget.folder.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: VideoLessonFolderPalette.text,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: VideoLessonFolderPalette.primaryGreen,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: VideoLessonFolderPalette.primaryGreen,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _buildFolderHeader(canManage),
                  const SizedBox(height: 12),
                  _buildActionRow(canManage),
                  const SizedBox(height: 18),
                  if (subfolders.isNotEmpty) ...[
                    _sectionTitle(
                      'Вложенные папки',
                      action: '${subfolders.length}',
                    ),
                    const SizedBox(height: 10),
                    ...subfolders.map((folder) => _buildFolderItem(folder, canManage)),
                    const SizedBox(height: 10),
                  ],
                  _sectionTitle(
                    'Видеоуроки',
                    action: '${lessons.length}',
                  ),
                  const SizedBox(height: 10),
                  if (lessons.isEmpty)
                    _whiteCard(
                      padding: const EdgeInsets.all(20),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 36,
                            color: VideoLessonFolderPalette.textMuted,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Пока нет видеоуроков в этой папке',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: VideoLessonFolderPalette.text,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Добавьте первый видеоурок или создайте вложенную папку',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: VideoLessonFolderPalette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...lessons.map(_buildLessonItem),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}