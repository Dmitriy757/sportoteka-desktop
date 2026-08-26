import 'package:flutter/material.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import '../../data/models/video_lesson_preview_data.dart';
import '../../data/services/video_lessons_service.dart';
import 'cmr_video_lessons_theme.dart';
import 'add_edit_video_lesson_screen.dart';
import 'video_lesson_detail_screen.dart';

class _C {
  static const bg = CmrVideoColors.bg;
  static const panel = CmrVideoColors.panel;
  static const soft = CmrVideoColors.soft;
  static const soft2 = CmrVideoColors.soft2;
  static const text = CmrVideoColors.text;
  static const muted = CmrVideoColors.muted;
  static const subtle = CmrVideoColors.subtle;
  static const line = CmrVideoColors.line;
  static const green = CmrVideoColors.green;
  static const greenDark = CmrVideoColors.greenDark;
  static const greenSoft = CmrVideoColors.greenSoft;
}

class _T {
  static TextStyle title(double size) => CmrVideoText.title(size);

  static TextStyle body(double size, {Color color = _C.muted}) =>
      CmrVideoText.body(size, color: color);

  static TextStyle action({Color color = _C.text}) =>
      CmrVideoText.action(color);
}

enum _HubSection { catalog, authors, mine }
enum _RightPaneMode { empty, lesson, add }

class VideoLessonsHubScreen extends StatefulWidget {
  const VideoLessonsHubScreen({super.key});

  @override
  State<VideoLessonsHubScreen> createState() => _VideoLessonsHubScreenState();
}

class _VideoLessonsHubScreenState extends State<VideoLessonsHubScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  int _currentUserId = 0;
  bool _loading = true;
  _HubSection _section = _HubSection.catalog;
  _RightPaneMode _rightPaneMode = _RightPaneMode.empty;
  VideoLessonPreviewData? _selectedLesson;
  List<VideoLessonPreviewData> _lessons = <VideoLessonPreviewData>[];

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
    _init();
  }

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    _currentUserId = await PrefUtils.getUserId() ?? 0;
    await _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await VideoLessonsService.getRandomPreviewLessons(limit: 60);
      if (!mounted) return;
      setState(() {
        _lessons = data;
        if (_selectedLesson != null) {
          final id = _selectedLesson!.lesson.id;
          VideoLessonPreviewData? refreshed;
          for (final item in data) {
            if (item.lesson.id == id) {
              refreshed = item;
              break;
            }
          }
          _selectedLesson = refreshed;
          if (refreshed == null && _rightPaneMode == _RightPaneMode.lesson) {
            _rightPaneMode = _RightPaneMode.empty;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить каталог: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<VideoLessonPreviewData> get _visibleLessons {
    final query = _search.text.trim().toLowerCase();
    final source = switch (_section) {
      _HubSection.catalog => _lessons,
      _HubSection.authors => _uniqueAuthors,
      _HubSection.mine => _lessons
          .where((item) => item.lesson.userId == _currentUserId)
          .toList(),
    };

    if (query.isEmpty) return source;
    return source.where((item) {
      final author = _authorName(item).toLowerCase();
      return item.lesson.title.toLowerCase().contains(query) ||
          item.lesson.description.toLowerCase().contains(query) ||
          item.folderTitle.toLowerCase().contains(query) ||
          author.contains(query);
    }).toList();
  }

  List<VideoLessonPreviewData> get _uniqueAuthors {
    final result = <String, VideoLessonPreviewData>{};
    for (final item in _lessons) {
      final key = '${item.lesson.userId}:${_authorName(item)}';
      result.putIfAbsent(key, () => item);
    }
    return result.values.toList();
  }

  String _authorName(VideoLessonPreviewData item) {
    final value =
        '${item.lesson.authorName ?? ''} ${item.lesson.authorSurname ?? ''}'
            .trim();
    return value.isEmpty ? 'Автор не указан' : value;
  }

  Future<void> _openLesson(VideoLessonPreviewData item) async {
    if (item.lesson.id <= 0) return;
    final desktop = MediaQuery.sizeOf(context).width >= 700;
    if (desktop) {
      setState(() {
        _selectedLesson = item;
        _rightPaneMode = _RightPaneMode.lesson;
      });
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VideoLessonDetailScreen(
          lessonId: item.lesson.id,
          autoPlay: true,
        ),
      ),
    );
    await _loadData();
  }

  Future<void> _openAddLesson() async {
    if (_currentUserId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить пользователя')),
      );
      return;
    }

    final desktop = MediaQuery.sizeOf(context).width >= 700;
    if (desktop) {
      setState(() => _rightPaneMode = _RightPaneMode.add);
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddEditVideoLessonScreen(
          folderId: 0,
          userId: _currentUserId,
          onUploadComplete: _loadData,
        ),
      ),
    );
    await _loadData();
  }

  void _selectSection(_HubSection value) {
    setState(() => _section = value);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return CmrVideoThemeScope(
      child: MediaQuery(
        data: media.copyWith(
        textScaler: TextScaler.linear(
          media.textScaler.scale(1).clamp(1.0, 1.08).toDouble(),
        ),
      ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 700;
            if (mobile) return _buildMobile();
            return _buildWorkspace(constraints.maxWidth);
          },
        ),
      ),
    );
  }

  Widget _buildWorkspace(double width) {
    final compact = width < 1050;
    final catalogWidth = compact ? 470.0 : 540.0;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: catalogWidth.clamp(420.0, width * .52).toDouble(),
            child: _buildCatalogPane(mobile: false),
          ),
          Container(width: .65, color: _C.line),
          Expanded(child: _buildRightPane()),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(child: _buildCatalogPane(mobile: true)),
    );
  }

  Widget _buildCatalogPane({required bool mobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          mobile: mobile,
          section: _section,
          onBack: () => Navigator.of(context).maybePop(),
          onRefresh: _loadData,
          onAdd: _openAddLesson,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(mobile ? 10 : 12, 9, mobile ? 10 : 12, 0),
          child: _SearchField(controller: _search),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 10 : 12,
              vertical: 7,
            ),
            children: [
              _SectionPill(
                label: 'Каталог',
                icon: Icons.video_library_outlined,
                active: _section == _HubSection.catalog,
                onTap: () => _selectSection(_HubSection.catalog),
              ),
              const SizedBox(width: 6),
              _SectionPill(
                label: 'Авторы',
                icon: Icons.groups_outlined,
                active: _section == _HubSection.authors,
                onTap: () => _selectSection(_HubSection.authors),
              ),
              const SizedBox(width: 6),
              _SectionPill(
                label: 'Мои материалы',
                icon: Icons.folder_outlined,
                active: _section == _HubSection.mine,
                onTap: () => _selectSection(_HubSection.mine),
              ),
            ],
          ),
        ),
        Expanded(child: _buildContent(mobile: mobile)),
      ],
    );
  }

  Widget _buildContent({required bool mobile}) {
    if (_loading) return _LoadingGrid(mobile: mobile);
    final items = _visibleLessons;
    if (items.isEmpty) {
      return _EmptyState(onAdd: _openAddLesson);
    }

    return RefreshIndicator(
      color: _C.green,
      onRefresh: _loadData,
      child: GridView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(mobile ? 10 : 12, 2, mobile ? 10 : 12, mobile ? 128 : 16),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: mobile ? 1 : 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: mobile ? 1.48 : 1.03,
        ),
        itemBuilder: (_, index) {
          final item = items[index];
          return _VideoTile(
            item: item,
            author: _authorName(item),
            selected: _selectedLesson?.lesson.id == item.lesson.id &&
                _rightPaneMode == _RightPaneMode.lesson,
            authorMode: _section == _HubSection.authors,
            onTap: () => _openLesson(item),
          );
        },
      ),
    );
  }

  Widget _buildRightPane() {
    switch (_rightPaneMode) {
      case _RightPaneMode.lesson:
        final selected = _selectedLesson;
        if (selected == null) return const _RightPlaceholder();
        return Column(
          children: [
            _RightHeader(
              title: 'Просмотр видеоурока',
              subtitle: selected.lesson.title,
              icon: Icons.play_circle_outline_rounded,
              onClose: () => setState(() => _rightPaneMode = _RightPaneMode.empty),
            ),
            Expanded(
              child: VideoLessonDetailScreen(
                key: ValueKey<int>(selected.lesson.id),
                lessonId: selected.lesson.id,
                autoPlay: true,
                embedded: true,
              ),
            ),
          ],
        );
      case _RightPaneMode.add:
        return Column(
          children: [
            _RightHeader(
              title: 'Добавить урок',
              subtitle: 'Видео и описание материала',
              icon: Icons.add_circle_outline_rounded,
              onClose: () => setState(() => _rightPaneMode = _RightPaneMode.empty),
            ),
            Expanded(
              child: AddEditVideoLessonScreen(
                key: const ValueKey<String>('add-video-lesson'),
                folderId: 0,
                userId: _currentUserId,
                embedded: true,
                onClose: () => setState(() => _rightPaneMode = _RightPaneMode.empty),
                onUploadComplete: () async {
                  await _loadData();
                  if (mounted) {
                    setState(() {
                      _section = _HubSection.mine;
                      _rightPaneMode = _RightPaneMode.empty;
                    });
                  }
                },
              ),
            ),
          ],
        );
      case _RightPaneMode.empty:
        return const _RightPlaceholder();
    }
  }
}

class _Toolbar extends StatelessWidget {
  final bool mobile;
  final _HubSection section;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;

  const _Toolbar({
    required this.mobile,
    required this.section,
    required this.onBack,
    required this.onRefresh,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (section) {
      _HubSection.catalog => 'Все видеоуроки',
      _HubSection.authors => 'Авторы и преподаватели',
      _HubSection.mine => 'Ваши материалы',
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.line, width: .55)),
      ),
      child: Row(
        children: [
          if (mobile) ...[
            _IconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
            const SizedBox(width: 7),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Видеоуроки', style: _T.title(mobile ? 15.5 : 16.5)),
                const SizedBox(height: 3),
                Text(subtitle, style: _T.body(11.2)),
              ],
            ),
          ),
          if (!mobile) ...[
            _IconButton(icon: Icons.refresh_rounded, onTap: onRefresh),
            const SizedBox(width: 6),
          ],
          _IconButton(icon: Icons.add_rounded, onTap: onAdd, accent: true),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: _C.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _C.muted, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Поиск по уроку, автору или папке...',
                border: InputBorder.none,
                isDense: true,
              ),
              style: _T.body(12.5, color: _C.text),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            InkWell(
              onTap: controller.clear,
              borderRadius: BorderRadius.circular(99),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 17, color: _C.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SectionPill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active ? _C.greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? _C.greenDark : _C.subtle),
              const SizedBox(width: 6),
              Text(
                label,
                style: _T.action(color: active ? _C.greenDark : _C.muted),
              ),
              if (active) ...[
                const SizedBox(width: 6),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _C.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final VideoLessonPreviewData item;
  final String author;
  final bool selected;
  final bool authorMode;
  final VoidCallback onTap;

  const _VideoTile({
    required this.item,
    required this.author,
    required this.selected,
    required this.authorMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lesson = item.lesson;
    final preview = lesson.thumbnail.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: selected ? _C.greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (preview.isNotEmpty)
                        Image.network(
                          preview,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _VideoFallback(),
                        )
                      else
                        const _VideoFallback(),
                      Container(color: Colors.black.withOpacity(.08)),
                      const Center(
                        child: _PlayButton(),
                      ),
                      if (lesson.duration.trim().isNotEmpty)
                        Positioned(
                          right: 7,
                          bottom: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.68),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              lesson.duration.trim(),
                              style: CmrVideoText.commentMeta(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                authorMode ? author : lesson.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _T.title(12.5),
              ),
              const SizedBox(height: 4),
              Text(
                authorMode ? '${item.folderTitle} · открыть материалы' : '$author · ${item.folderTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _T.body(10.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.soft2,
      alignment: Alignment.center,
      child: const Icon(Icons.video_library_outlined, color: _C.subtle, size: 34),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.play_arrow_rounded, color: _C.green, size: 25),
    );
  }
}

class _RightHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onClose;

  const _RightHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.line, width: .55)),
      ),
      child: Row(
        children: [
          const CmrVideoDot(size: 7),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _T.title(14)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _T.body(10.8)),
              ],
            ),
          ),
          const CmrVideoDotCluster(),
          const SizedBox(width: 9),
          _IconButton(icon: Icons.close_rounded, onTap: onClose),
        ],
      ),
    );
  }
}

class _RightPlaceholder extends StatelessWidget {
  const _RightPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _C.soft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.play_lesson_outlined, color: _C.green, size: 30),
            ),
            const SizedBox(height: 15),
            Text('Выберите видеоурок', style: _T.title(20)),
            const SizedBox(height: 7),
            Text(
              'Каталог остаётся слева, а видео или добавление нового урока открывается в этой рабочей области.',
              textAlign: TextAlign.center,
              style: _T.body(12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  const _IconButton({required this.icon, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? _C.greenSoft : _C.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 17, color: accent ? _C.green : _C.text),
        ),
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  final bool mobile;
  const _LoadingGrid({required this.mobile});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
      itemCount: mobile ? 4 : 8,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: mobile ? 1 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        childAspectRatio: mobile ? 1.48 : 1.03,
      ),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: _C.soft2, borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Container(height: 11, decoration: BoxDecoration(color: _C.soft2, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 6),
            FractionallySizedBox(
              widthFactor: .62,
              child: Container(height: 9, decoration: BoxDecoration(color: _C.soft2, borderRadius: BorderRadius.circular(99))),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.video_library_outlined, color: _C.green, size: 26),
            ),
            const SizedBox(height: 13),
            Text('Видеоуроки не найдены', style: _T.title(16)),
            const SizedBox(height: 6),
            Text('Измените поиск или добавьте новый материал.', textAlign: TextAlign.center, style: _T.body(11.5)),
            const SizedBox(height: 12),
            Material(
              color: _C.green,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(11),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  child: Text('Добавить урок', style: _T.action(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
