import 'package:flutter/material.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import '../../data/models/video_folder_model.dart';
import '../../data/models/video_lesson_model.dart';
import '../../data/services/video_lessons_service.dart';
import 'cmr_video_lessons_theme.dart';
import 'widgets/create_video_folder_dialog.dart';
import 'add_edit_video_lesson_screen.dart';
import 'video_lesson_detail_screen.dart';

class VideoLessonFolderPalette {
  static const primaryGreen = CmrVideoColors.green;
  static const primaryGreenDark = CmrVideoColors.greenDark;
  static const primaryGreenLight = CmrVideoColors.green;

  static const lightGreen = CmrVideoColors.greenSoft;
  static const superLightGreen = CmrVideoColors.greenSoft2;

  static const white = CmrVideoColors.panel;
  static const text = CmrVideoColors.text;
  static const textMuted = CmrVideoColors.muted;
  static const textSoft = CmrVideoColors.subtle;

  static const background = CmrVideoColors.bg;
  static const soft = CmrVideoColors.soft;
  static const border = Colors.transparent;
  static const danger = CmrVideoColors.red;

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final cardShadowSoft = [
    BoxShadow(
      color: Colors.black.withOpacity(.018),
      blurRadius: 20,
      offset: const Offset(0, 8),
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

  bool _useLessonTileLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 720;
  }

  int _lessonGridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 1500) return 4;
    if (width >= 1180) return 3;
    if (width >= 720) return 2;
    return 1;
  }

  double _lessonGridAspectRatio(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 1180) return 1.18;
    if (width >= 720) return 1.08;
    return 1.0;
  }

  Color _parseColor(String value) {
    try {
      var hex = value.trim().replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length != 8) {
        return VideoLessonFolderPalette.primaryGreen;
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return VideoLessonFolderPalette.primaryGreen;
    }
  }

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
      builder: (dialogContext) => CmrVideoDialogShell(
        title: 'Редактировать папку',
        subtitle: 'Измените название раздела',
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          cursorColor: CmrVideoColors.greenDark,
          style: CmrVideoText.body(
            11,
            color: CmrVideoColors.text,
            weight: FontWeight.w500,
          ),
          decoration: cmrVideoInputDecoration(
            'Название папки',
            hint: 'Введите название',
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) Navigator.of(dialogContext).pop(trimmed);
          },
        ),
        actions: <Widget>[
          CmrVideoTextButton(
            label: 'Отмена',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          CmrVideoTextButton(
            label: 'Сохранить',
            primary: true,
            onTap: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
          ),
        ],
      ),
    );
    controller.dispose();

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
        SnackBar(content: Text(ok ? 'Папка обновлена' : 'Не удалось обновить папку')),
      );

      if (ok) await _loadData();
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
      builder: (dialogContext) => CmrVideoDialogShell(
        title: 'Удалить папку?',
        subtitle: 'Это действие нельзя отменить',
        dotColor: CmrVideoColors.red,
        child: Text(
          'Папка «${folder.title}» будет удалена.',
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

    if (confirmed != true) return;

    try {
      final ok = await VideoLessonsService.deleteFolder(folder.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Папка удалена' : 'Не удалось удалить папку')),
      );

      if (ok) await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления папки: $e')),
      );
    }
  }

  Widget _whiteCard({
    required Widget child,
    EdgeInsets? padding,
    VoidCallback? onTap,
    Color color = VideoLessonFolderPalette.white,
  }) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      ),
    );
  }

  Widget _sectionTitle(String title, {String? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
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
              fontWeight: FontWeight.w600,
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
        color: VideoLessonFolderPalette.superLightGreen,
        borderRadius: BorderRadius.circular(999),
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
              fontWeight: FontWeight.w600,
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

    return _whiteCard(
      padding: const EdgeInsets.all(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VideoLessonFolderPalette.lightGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: VideoLessonFolderPalette.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.folder_copy_rounded,
                    color: color,
                    size: 25,
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
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: VideoLessonFolderPalette.text,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Материалы, вложенные папки и уроки',
                        style: TextStyle(
                          color: VideoLessonFolderPalette.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: VideoLessonFolderPalette.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Управление',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: VideoLessonFolderPalette.primaryGreen,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              widget.folder.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: VideoLessonFolderPalette.text,
                fontWeight: FontWeight.w600,
                fontSize: 24,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 14),
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
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: filled ? VideoLessonFolderPalette.greenGradient : null,
        color: filled ? null : VideoLessonFolderPalette.lightGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor:
              filled ? Colors.white : VideoLessonFolderPalette.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildActionRow(bool canManage) {
    if (!canManage) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final folderButton = _buildActionButton(
          title: 'Новая папка',
          icon: Icons.create_new_folder_rounded,
          onTap: _createSubfolder,
          filled: false,
        );
        final lessonButton = _buildActionButton(
          title: 'Добавить урок',
          icon: Icons.add_to_queue_rounded,
          onTap: _addLesson,
          filled: true,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              folderButton,
              const SizedBox(height: 10),
              lessonButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: folderButton),
            const SizedBox(width: 10),
            Expanded(child: lessonButton),
          ],
        );
      },
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
        color: VideoLessonFolderPalette.soft,
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
                        fontWeight: FontWeight.w600,
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
                        fontWeight: FontWeight.w500,
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
                      color: VideoLessonFolderPalette.white,
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
        color: VideoLessonFolderPalette.soft,
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
                        fontWeight: FontWeight.w600,
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
                        fontWeight: FontWeight.w500,
                        color: VideoLessonFolderPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Комментарии: ${lesson.commentsCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  Widget _buildLessonTile(VideoLessonModel lesson) {
    final author = '${lesson.authorName} ${lesson.authorSurname}'.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoLessonDetailScreen(lessonId: lesson.id),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: VideoLessonFolderPalette.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: VideoLessonFolderPalette.cardShadowSoft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: Colors.black12,
                      child: lesson.thumbnail.isNotEmpty
                          ? Image.network(
                              lesson.thumbnail,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 42,
                                  color: VideoLessonFolderPalette.primaryGreen,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                size: 46,
                                color: VideoLessonFolderPalette.primaryGreen,
                              ),
                            ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.10),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.42),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_fill_rounded,
                              size: 13,
                              color: VideoLessonFolderPalette.primaryGreen,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Урок',
                              style: TextStyle(
                                color: VideoLessonFolderPalette.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: VideoLessonFolderPalette.superLightGreen,
                          shape: BoxShape.circle,

                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 17,
                          color: VideoLessonFolderPalette.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lesson.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VideoLessonFolderPalette.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.18,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              author.isEmpty ? 'Автор урока' : author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VideoLessonFolderPalette.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Комментарии: ${lesson.commentsCount}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VideoLessonFolderPalette.textSoft,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.more_vert_rounded,
                        size: 19,
                        color: VideoLessonFolderPalette.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLessonsList() {
    if (!_useLessonTileLayout(context)) {
      return Column(
        children: lessons.map(_buildLessonItem).toList(),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lessons.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _lessonGridColumns(context),
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: _lessonGridAspectRatio(context),
      ),
      itemBuilder: (_, index) => _buildLessonTile(lessons[index]),
    );
  }


  @override
  Widget build(BuildContext context) {
    final canManage = widget.isMyMode && currentUserId == widget.ownerUserId;

    return CmrVideoThemeScope(
      child: Scaffold(
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
            fontWeight: FontWeight.w600,
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
                      padding: const EdgeInsets.all(22),
                      color: VideoLessonFolderPalette.soft,
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
                              fontWeight: FontWeight.w600,
                              color: VideoLessonFolderPalette.text,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Добавьте первый видеоурок или создайте вложенную папку',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: VideoLessonFolderPalette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildLessonsList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      ),
    );
  }
}