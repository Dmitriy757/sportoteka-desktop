import 'package:flutter/material.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import '../../data/models/video_folder_model.dart';
import '../../data/services/video_lessons_service.dart';
import 'video_lesson_folder_screen.dart';
import 'widgets/create_video_folder_dialog.dart';

class VideoLessonsPalette {
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
  static const dark = Color(0xFF111827);
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


class _VideoLessonTilePatternPainter extends CustomPainter {
  final Color color;

  const _VideoLessonTilePatternPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final circlePaint = Paint()
      ..color = color.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    for (var i = -1; i < 5; i++) {
      final dx = size.width * (0.18 + i * 0.22);
      canvas.drawCircle(
        Offset(dx, size.height * 0.22),
        18 + i.abs() * 2,
        paint,
      );
    }

    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.76),
      46,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.78),
      7,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _VideoLessonTilePatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class VideoLessonsScreen extends StatefulWidget {
  final int ownerUserId;
  final String ownerName;
  final bool isMyMode;
  final bool embedded;

  const VideoLessonsScreen({
    super.key,
    required this.ownerUserId,
    required this.ownerName,
    this.isMyMode = false,
    this.embedded = false,
  });

  @override
  State<VideoLessonsScreen> createState() => _VideoLessonsScreenState();
}

class _VideoLessonsScreenState extends State<VideoLessonsScreen> {
  List<VideoFolderModel> folders = [];
  bool isLoading = true;
  bool isRefreshing = false;
  int currentUserId = 0;

  final TextEditingController _searchController = TextEditingController();
  String selectedCategory = 'Все';
  bool isGrid = true;

  final List<String> categories = const [
    'Все',
    'С уроками',
    'С подпапками',
    'Пустые',
  ];

  bool _isVideoTileLayout(BuildContext context) {
    // Плиточный режим нужен уже на планшете и в широком мобильном окне.
    // Иначе папки/видео выглядят как обычный список друг под другом.
    return MediaQuery.sizeOf(context).width >= 600;
  }

  int _folderGridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 1500) return 5;
    if (width >= 1120) return 4;
    if (width >= 720) return 3;
    return 2;
  }

  double _folderGridAspectRatio(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 1120) return 1.28;
    if (width >= 720) return 1.18;
    return 0.82;
  }

  EdgeInsets _pagePadding(
    BuildContext context, {
    double top = 0,
    double bottom = 0,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 1120 ? 24.0 : 16.0;

    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  SliverGridDelegateWithFixedCrossAxisCount _folderGridDelegate(
    BuildContext context,
  ) {
    final wide = _isVideoTileLayout(context);

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _folderGridColumns(context),
      mainAxisSpacing: wide ? 22 : 14,
      crossAxisSpacing: wide ? 22 : 14,
      childAspectRatio: _folderGridAspectRatio(context),
    );
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final id = await PrefUtils.getUserId();
    currentUserId = id ?? 0;
    await _loadFolders();
  }

  Future<void> _loadFolders() async {
    if (!mounted) return;

    setState(() {
      if (folders.isEmpty) isLoading = true;
      isRefreshing = true;
    });

    try {
      folders = await VideoLessonsService.getFolders(
        // В режиме "Мои видеоуроки" показываем только свои папки.
        // В общем каталоге ownerId не передаём, чтобы поиск и список видели
        // папки, созданные другими пользователями.
        ownerId: widget.isMyMode ? widget.ownerUserId : null,
      );
    } catch (e) {
      debugPrint('VideoLessonsScreen getFolders error: $e');
      folders = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки папок: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
      }
    }
  }

  Future<void> _showCreateFolderDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => CreateVideoFolderDialog(
        userId: currentUserId,
        parentId: null,
      ),
    );

    if (created == true) {
      await _loadFolders();
    }
  }

  Future<void> _renameFolder(VideoFolderModel folder) async {
    final controller = TextEditingController(text: folder.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: VideoLessonsPalette.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text(
          'Редактировать папку',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: VideoLessonsPalette.text,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Название папки',
            labelStyle: const TextStyle(
              color: VideoLessonsPalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: VideoLessonsPalette.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: VideoLessonsPalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: VideoLessonsPalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: VideoLessonsPalette.primaryGreen,
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
                color: VideoLessonsPalette.textMuted,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: VideoLessonsPalette.greenGradient,
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
        await _loadFolders();
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
        backgroundColor: VideoLessonsPalette.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text(
          'Удалить папку?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: VideoLessonsPalette.text,
          ),
        ),
        content: Text(
          'Папка "${folder.title}" будет удалена.',
          style: const TextStyle(
            color: VideoLessonsPalette.textMuted,
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
                color: VideoLessonsPalette.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VideoLessonsPalette.danger,
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
        await _loadFolders();
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
      return VideoLessonsPalette.primaryGreen;
    }
  }

  List<VideoFolderModel> get _filteredFolders {
    final query = _searchController.text.trim().toLowerCase();

    return folders.where((folder) {
      final matchesSearch =
          query.isEmpty || folder.title.toLowerCase().contains(query);

      bool matchesCategory = true;

      switch (selectedCategory) {
        case 'С уроками':
          matchesCategory = folder.lessonsCount > 0;
          break;
        case 'С подпапками':
          matchesCategory = folder.subfoldersCount > 0;
          break;
        case 'Пустые':
          matchesCategory =
              folder.lessonsCount == 0 && folder.subfoldersCount == 0;
          break;
        default:
          matchesCategory = true;
      }

      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _openFolder(VideoFolderModel folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoLessonFolderScreen(
          folder: folder,
          ownerUserId: widget.ownerUserId,
          isMyMode: widget.isMyMode,
        ),
      ),
    ).then((_) => _loadFolders());
  }

  Widget _sectionHeader(String title, {String? subtitle, Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: VideoLessonsPalette.text,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: VideoLessonsPalette.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildTopBar(bool canManage) {
    final title = widget.isMyMode ? 'Мои видеоуроки' : widget.ownerName;

    return Container(
      decoration: const BoxDecoration(
        color: VideoLessonsPalette.white,
        border: Border(
          bottom: BorderSide(color: VideoLessonsPalette.border),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: VideoLessonsPalette.greenGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.video_library_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: VideoLessonsPalette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isMyMode
                          ? 'Ваши папки и подборки уроков'
                          : 'Каталог папок и видеоуроков',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: VideoLessonsPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: VideoLessonsPalette.superLightGreen,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: VideoLessonsPalette.border),
                ),
                child: IconButton(
                  onPressed: _loadFolders,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: VideoLessonsPalette.text,
                  ),
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: 8),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: VideoLessonsPalette.greenGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    tooltip: 'Создать папку',
                    onPressed: _showCreateFolderDialog,
                    icon: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmbeddedManageBar(bool canManage) {
    if (!widget.embedded) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: VideoLessonsPalette.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: VideoLessonsPalette.border),
                boxShadow: VideoLessonsPalette.cardShadowSoft,
              ),
              child: TextButton.icon(
                onPressed: _loadFolders,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: VideoLessonsPalette.text,
                ),
                label: const Text(
                  'Обновить',
                  style: TextStyle(
                    color: VideoLessonsPalette.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          if (canManage) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  gradient: VideoLessonsPalette.greenGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton.icon(
                  onPressed: _showCreateFolderDialog,
                  icon: const Icon(
                    Icons.create_new_folder_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Добавить папку',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: VideoLessonsPalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VideoLessonsPalette.border),
        boxShadow: VideoLessonsPalette.cardShadowSoft,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: VideoLessonsPalette.text,
        ),
        decoration: InputDecoration(
          hintText: widget.isMyMode ? 'Поиск моих папок' : 'Поиск по всем папкам',
          hintStyle: const TextStyle(
            color: VideoLessonsPalette.textMuted,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: VideoLessonsPalette.textMuted,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }

  Widget _buildHeroBlock(bool canManage) {
    final totalFolders = folders.length;
    final totalLessons =
        folders.fold<int>(0, (sum, item) => sum + item.lessonsCount);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            VideoLessonsPalette.primaryGreen.withOpacity(0.12),
            VideoLessonsPalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: VideoLessonsPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: VideoLessonsPalette.greenGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.video_library_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.isMyMode
                      ? 'Каталог ваших видеоуроков'
                      : 'Каталог видеоуроков',
                  style: const TextStyle(
                    color: VideoLessonsPalette.text,
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            canManage
                ? 'Создавайте папки, распределяйте материалы и собирайте уроки в красивый структурированный каталог.'
                : 'Смотрите подборки папок и переходите к видеоурокам.',
            style: const TextStyle(
              color: VideoLessonsPalette.textMuted,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroStat(Icons.folder_open_rounded, 'Папок', '$totalFolders'),
              _heroStat(Icons.play_circle_fill_rounded, 'Уроков', '$totalLessons'),
              if (!widget.isMyMode)
                _heroStat(Icons.person_rounded, 'Автор', widget.ownerName),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: VideoLessonsPalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VideoLessonsPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: VideoLessonsPalette.primaryGreen,
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VideoLessonsPalette.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: VideoLessonsPalette.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = categories[index];
          final selected = item == selectedCategory;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = item;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: selected ? VideoLessonsPalette.greenGradient : null,
                color: selected ? null : VideoLessonsPalette.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : VideoLessonsPalette.border,
                ),
              ),
              child: Text(
                item,
                style: TextStyle(
                  color: selected ? Colors.white : VideoLessonsPalette.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedFolders(bool canManage) {
    final items = _filteredFolders.take(8).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    final useTileGrid = width >= 720;

    if (useTileGrid) {
      final columns = width >= 1500
          ? 5
          : width >= 1120
              ? 4
              : 3;

      return GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 22,
          crossAxisSpacing: 22,
          childAspectRatio: width >= 1120 ? 1.34 : 1.24,
        ),
        itemBuilder: (_, index) {
          return _buildFolderVideoTile(items[index], canManage);
        },
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, index) {
          final folder = items[index];
          final folderColor = _parseColor(folder.color);

          return GestureDetector(
            onTap: () => _openFolder(folder),
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: VideoLessonsPalette.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: VideoLessonsPalette.border),
                boxShadow: VideoLessonsPalette.cardShadowSoft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 128,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          folderColor,
                          folderColor.withOpacity(0.72),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${folder.lessonsCount} видео',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 52,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: folderColor.withOpacity(0.15),
                            child: Icon(
                              Icons.folder_rounded,
                              color: folderColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  folder.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: VideoLessonsPalette.text,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${folder.lessonsCount} уроков • ${folder.subfoldersCount} подпапок',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: VideoLessonsPalette.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: VideoLessonsPalette.textMuted,
                            ),
                            onSelected: (value) async {
                              if (value == 'open') {
                                _openFolder(folder);
                              } else if (value == 'edit') {
                                await _renameFolder(folder);
                              } else if (value == 'delete') {
                                await _deleteFolder(folder);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem<String>(
                                value: 'open',
                                child: Text('Открыть'),
                              ),
                              if (canManage)
                                const PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text('Редактировать'),
                                ),
                              if (canManage)
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text(
                                    'Удалить',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFolderGrid(VideoFolderModel folder, bool canManage) {
    if (_isVideoTileLayout(context)) {
      return _buildFolderVideoTile(folder, canManage);
    }

    final folderColor = _parseColor(folder.color);

    return GestureDetector(
      onTap: () => _openFolder(folder),
      child: Container(
        decoration: BoxDecoration(
          color: VideoLessonsPalette.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: VideoLessonsPalette.border),
          boxShadow: VideoLessonsPalette.cardShadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 112,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                gradient: LinearGradient(
                  colors: [
                    folderColor,
                    folderColor.withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.video_collection_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                      ),
                      onSelected: (value) async {
                        if (value == 'open') {
                          _openFolder(folder);
                        } else if (value == 'edit') {
                          await _renameFolder(folder);
                        } else if (value == 'delete') {
                          await _deleteFolder(folder);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'open',
                          child: Text('Открыть'),
                        ),
                        if (canManage)
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Редактировать'),
                          ),
                        if (canManage)
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(
                              'Удалить',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: VideoLessonsPalette.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${folder.lessonsCount} уроков',
                      style: const TextStyle(
                        color: VideoLessonsPalette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${folder.subfoldersCount} подпапок',
                      style: const TextStyle(
                        color: VideoLessonsPalette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: VideoLessonsPalette.superLightGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Открыть',
                                style: TextStyle(
                                  color: VideoLessonsPalette.primaryGreen,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderVideoTile(VideoFolderModel folder, bool canManage) {
    final folderColor = _parseColor(folder.color);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openFolder(folder),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: VideoLessonsPalette.background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        folderColor,
                        folderColor.withOpacity(0.72),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: VideoLessonsPalette.cardShadowSoft,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CustomPaint(
                            painter: _VideoLessonTilePatternPainter(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${folder.lessonsCount} видео',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 8,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                          ),
                          onSelected: (value) async {
                            if (value == 'open') {
                              _openFolder(folder);
                            } else if (value == 'edit') {
                              await _renameFolder(folder);
                            } else if (value == 'delete') {
                              await _deleteFolder(folder);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem<String>(
                              value: 'open',
                              child: Text('Открыть'),
                            ),
                            if (canManage)
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Редактировать'),
                              ),
                            if (canManage)
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text(
                                  'Удалить',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.24),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.38),
                            ),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.52),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Папка',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: folderColor.withOpacity(0.14),
                    child: Icon(
                      Icons.folder_rounded,
                      color: folderColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              height: 1.18,
                              color: VideoLessonsPalette.text,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${folder.lessonsCount} уроков • ${folder.subfoldersCount} подпапок',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: VideoLessonsPalette.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderList(VideoFolderModel folder, bool canManage) {
    final folderColor = _parseColor(folder.color);

    return GestureDetector(
      onTap: () => _openFolder(folder),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VideoLessonsPalette.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VideoLessonsPalette.border),
          boxShadow: VideoLessonsPalette.cardShadowSoft,
        ),
        child: Row(
          children: [
            Container(
              width: 114,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    folderColor,
                    folderColor.withOpacity(0.75),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 38,
                ),
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
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: VideoLessonsPalette.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${folder.lessonsCount} уроков • ${folder.subfoldersCount} подпапок',
                    style: const TextStyle(
                      color: VideoLessonsPalette.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.more_vert_rounded,
                color: VideoLessonsPalette.textMuted,
              ),
              onSelected: (value) async {
                if (value == 'open') {
                  _openFolder(folder);
                } else if (value == 'edit') {
                  await _renameFolder(folder);
                } else if (value == 'delete') {
                  await _deleteFolder(folder);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'open',
                  child: Text('Открыть'),
                ),
                if (canManage)
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Редактировать'),
                  ),
                if (canManage)
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(
                      'Удалить',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: VideoLessonsPalette.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VideoLessonsPalette.border),
      ),
      child: Column(
        children: [
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool canManage) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: VideoLessonsPalette.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VideoLessonsPalette.border),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: VideoLessonsPalette.superLightGreen,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.video_library_outlined,
              size: 36,
              color: VideoLessonsPalette.primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Пока здесь пусто',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: VideoLessonsPalette.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canManage
                ? 'Создайте первую папку и начните собирать видеоуроки.'
                : 'У этого пользователя пока нет добавленных папок.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VideoLessonsPalette.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (canManage) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                gradient: VideoLessonsPalette.greenGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextButton.icon(
                onPressed: _showCreateFolderDialog,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  'Создать папку',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(bool canManage) {
    final filtered = _filteredFolders;

    return RefreshIndicator(
      onRefresh: _loadFolders,
      color: VideoLessonsPalette.primaryGreen,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: _pagePadding(context, top: 14),
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 14),
                  _buildHeroBlock(canManage),
                  _buildEmbeddedManageBar(canManage),
                  const SizedBox(height: 16),
                  _buildCategoryChips(),
                  const SizedBox(height: 18),
                  _sectionHeader(
                    'Рекомендуемые папки',
                    subtitle: 'Быстрый доступ к подборкам',
                  ),
                  const SizedBox(height: 12),
                  if (isLoading && folders.isEmpty)
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 3,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, __) => SizedBox(
                          width: 280,
                          child: _buildSkeletonCard(),
                        ),
                      ),
                    )
                  else
                    _buildFeaturedFolders(canManage),
                  const SizedBox(height: 22),
                  _sectionHeader(
                    'Все папки',
                    subtitle: '${filtered.length} элементов',
                    trailing: Container(
                      decoration: BoxDecoration(
                        color: VideoLessonsPalette.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: VideoLessonsPalette.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() => isGrid = true);
                            },
                            icon: Icon(
                              Icons.grid_view_rounded,
                              color: isGrid
                                  ? VideoLessonsPalette.primaryGreen
                                  : VideoLessonsPalette.textMuted,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() => isGrid = false);
                            },
                            icon: Icon(
                              Icons.view_agenda_rounded,
                              color: !isGrid
                                  ? VideoLessonsPalette.primaryGreen
                                  : VideoLessonsPalette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          if (isLoading && folders.isEmpty)
            SliverPadding(
              padding: _pagePadding(context, bottom: 20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => _buildSkeletonCard(),
                  childCount: 6,
                ),
                gridDelegate: _folderGridDelegate(context),
              ),
            )
          else if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: _pagePadding(context, bottom: 20),
                child: _buildEmptyState(canManage),
              ),
            )
          else if (isGrid || _isVideoTileLayout(context))
            SliverPadding(
              padding: _pagePadding(context, bottom: 20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, index) => _buildFolderGrid(filtered[index], canManage),
                  childCount: filtered.length,
                ),
                gridDelegate: _folderGridDelegate(context),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: _pagePadding(context, bottom: 20),
                child: Column(
                  children: filtered
                      .map((folder) => _buildFolderList(folder, canManage))
                      .toList(),
                ),
              ),
            ),
          if (isRefreshing && folders.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: VideoLessonsPalette.primaryGreen,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.isMyMode && currentUserId == widget.ownerUserId;

    final content = Column(
      children: [
        if (!widget.embedded) _buildTopBar(canManage),
        Expanded(child: _buildContent(canManage)),
      ],
    );

    if (widget.embedded) {
      return Container(
        color: VideoLessonsPalette.background,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: VideoLessonsPalette.background,
      body: content,
    );
  }
}