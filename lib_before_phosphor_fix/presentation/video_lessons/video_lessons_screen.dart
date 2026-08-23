import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import '../../data/models/video_folder_model.dart';
import '../../data/models/video_lesson_model.dart';
import '../../data/services/video_lessons_service.dart';
import 'add_edit_video_lesson_screen.dart';
import 'video_lesson_detail_screen.dart';
import 'widgets/create_video_folder_dialog.dart';

class _C {
  static const bg = Color(0xFFF6F7F6);
  static const panel = Colors.white;
  static const soft = Color(0xFFF7F8F7);
  static const soft2 = Color(0xFFF2F4F2);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF5F6670);
  static const subtle = Color(0xFF8A9099);
  static const line = Color(0xFFE9ECEA);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenBorder = Color(0xFFD7F0E2);
}

class _T {
  static TextStyle title(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _C.text,
        height: 1.18,
        letterSpacing: 0,
        features: const [FontFeature.tabularFigures()],
      );

  static TextStyle body(double size, {Color color = _C.muted}) =>
      AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: color,
        height: 1.32,
        letterSpacing: 0,
      );

  static TextStyle action({Color color = _C.text}) => AppTypography.custom(
        size: 12,
        weight: FontWeight.w600,
        color: color,
        height: 1.2,
        letterSpacing: 0,
      );
}

enum _VideoFilter { all, folders, videos }

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
  final TextEditingController _search = TextEditingController();

  List<VideoFolderModel> _folders = [];
  List<VideoLessonModel> _lessons = [];
  VideoFolderModel? _selectedFolder;
  VideoLessonModel? _selectedLesson;
  _VideoFilter _filter = _VideoFilter.all;
  int _currentUserId = 0;
  bool _loadingFolders = true;
  bool _loadingLessons = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _init();
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    _currentUserId = await PrefUtils.getUserId() ?? 0;
    await _loadFolders();
  }

  Future<void> _loadFolders() async {
    if (mounted) setState(() => _loadingFolders = true);
    try {
      final data = await VideoLessonsService.getFolders(
        ownerId: widget.isMyMode ? widget.ownerUserId : null,
      );
      if (!mounted) return;

      VideoFolderModel? nextFolder = _selectedFolder;
      if (nextFolder == null && data.isNotEmpty) nextFolder = data.first;
      if (nextFolder != null && !data.any((e) => e.id == nextFolder!.id)) {
        nextFolder = data.isEmpty ? null : data.first;
      }

      setState(() {
        _folders = data;
        _selectedFolder = nextFolder;
      });

      if (nextFolder != null) {
        await _loadLessons(nextFolder, preserveSelection: true);
      } else if (mounted) {
        setState(() {
          _lessons = [];
          _selectedLesson = null;
        });
      }
    } catch (e) {
      _showError('Не удалось загрузить папки: $e');
    } finally {
      if (mounted) setState(() => _loadingFolders = false);
    }
  }

  Future<void> _loadLessons(
    VideoFolderModel folder, {
    bool preserveSelection = false,
  }) async {
    final previousLessonId = preserveSelection ? _selectedLesson?.id : null;
    if (mounted) {
      setState(() {
        _selectedFolder = folder;
        _loadingLessons = true;
        if (!preserveSelection) _selectedLesson = null;
      });
    }

    try {
      final data = await VideoLessonsService.getLessons(folderId: folder.id);
      if (!mounted || _selectedFolder?.id != folder.id) return;

      VideoLessonModel? nextLesson;
      if (previousLessonId != null) {
        for (final lesson in data) {
          if (lesson.id == previousLessonId) {
            nextLesson = lesson;
            break;
          }
        }
      }
      nextLesson ??= data.isEmpty ? null : data.first;

      setState(() {
        _lessons = data;
        _selectedLesson = nextLesson;
      });
    } catch (e) {
      _showError('Не удалось загрузить видео: $e');
    } finally {
      if (mounted) setState(() => _loadingLessons = false);
    }
  }

  void _showError(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _createFolder() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => CreateVideoFolderDialog(userId: _currentUserId),
    );
    if (created == true) await _loadFolders();
  }

  Future<void> _addLesson() async {
    final folder = _selectedFolder;
    if (folder == null) {
      _showError('Сначала выберите папку');
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditVideoLessonScreen(
          folderId: folder.id,
          userId: _currentUserId,
        ),
      ),
    );
    if (saved == true) await _loadLessons(folder, preserveSelection: true);
  }

  Future<void> _openLesson(VideoLessonModel lesson) async {
    setState(() => _selectedLesson = lesson);
    final mobile = MediaQuery.sizeOf(context).width < 640;
    if (!mobile) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoLessonDetailScreen(
          lessonId: lesson.id,
          autoPlay: true,
        ),
      ),
    );
  }

  void _openSelectedLesson() {
    final lesson = _selectedLesson;
    if (lesson == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoLessonDetailScreen(
          lessonId: lesson.id,
          autoPlay: true,
        ),
      ),
    );
  }

  List<VideoFolderModel> get _visibleFolders {
    final q = _search.text.trim().toLowerCase();
    return _folders.where((folder) {
      final matchesSearch = q.isEmpty || folder.title.toLowerCase().contains(q);
      final matchesFilter = switch (_filter) {
        _VideoFilter.all => true,
        _VideoFilter.folders => folder.lessonsCount > 0,
        _VideoFilter.videos => folder.lessonsCount == 0,
      };
      return matchesSearch && matchesFilter;
    }).toList();
  }

  List<VideoLessonModel> get _visibleLessons {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _lessons;
    return _lessons.where((lesson) {
      final author = '${lesson.authorName} ${lesson.authorSurname}'.toLowerCase();
      return lesson.title.toLowerCase().contains(q) || author.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 640;
        final compact = constraints.maxWidth < 980;
        final listWidth = math.min(
          compact ? 430.0 : 480.0,
          constraints.maxWidth * (compact ? .43 : .45),
        );

        final leftPane = _FoldersPane(
          ownerName: widget.ownerName,
          folders: _visibleFolders,
          selectedFolderId: _selectedFolder?.id,
          filter: _filter,
          searchController: _search,
          loading: _loadingFolders,
          onFilterChanged: (value) => setState(() => _filter = value),
          onRefresh: _loadFolders,
          onCreateFolder: _createFolder,
          onSelectFolder: (folder) => _loadLessons(folder),
          mobile: mobile,
        );

        if (mobile) {
          return Container(
            color: _C.bg,
            padding: const EdgeInsets.all(6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ColoredBox(color: Colors.white, child: leftPane),
            ),
          );
        }

        return Container(
          color: _C.bg,
          padding: EdgeInsets.all(compact ? 8 : 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 18 : 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(compact ? 18 : 20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.035),
                    blurRadius: 28,
                    spreadRadius: -18,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: listWidth, child: leftPane),
                  Container(width: 1, color: _C.line),
                  Expanded(
                    child: _FolderOverviewPane(
                      folder: _selectedFolder,
                      lessons: _lessons,
                      selectedLessonId: _selectedLesson?.id,
                      loading: _loadingLessons,
                      onOpenLesson: (lesson) {
                        setState(() => _selectedLesson = lesson);
                        _openSelectedLesson();
                      },
                      onSelectLesson: (lesson) => setState(() => _selectedLesson = lesson),
                      onAddLesson: _addLesson,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (widget.embedded) return content;
    return Scaffold(backgroundColor: _C.bg, body: SafeArea(child: content));
  }
}

class _FoldersPane extends StatelessWidget {
  final String ownerName;
  final List<VideoFolderModel> folders;
  final int? selectedFolderId;
  final _VideoFilter filter;
  final TextEditingController searchController;
  final bool loading;
  final ValueChanged<_VideoFilter> onFilterChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreateFolder;
  final ValueChanged<VideoFolderModel> onSelectFolder;
  final bool mobile;

  const _FoldersPane({
    required this.ownerName,
    required this.folders,
    required this.selectedFolderId,
    required this.filter,
    required this.searchController,
    required this.loading,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onCreateFolder,
    required this.onSelectFolder,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(mobile ? 14 : 18, 16, mobile ? 14 : 18, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Видеоуроки', style: _T.title(mobile ? 22 : 24)),
                      const SizedBox(height: 4),
                      Text(ownerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: _T.body(12.5)),
                    ],
                  ),
                ),
                _SquareButton(icon: Icons.refresh_rounded, onTap: onRefresh),
                const SizedBox(width: 8),
                _SquareButton(icon: Icons.add_rounded, onTap: onCreateFolder, accent: true),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(mobile ? 14 : 18, 10, mobile ? 14 : 18, 10),
            child: Container(
              height: 54,
              decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Поиск папки',
                  hintStyle: _T.action(color: _C.text),
                  prefixIcon: const Icon(Icons.search_rounded, color: _C.muted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 17),
                ),
                style: _T.action(),
              ),
            ),
          ),
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 18, vertical: 7),
              children: [
                _FilterChip(label: 'Все', selected: filter == _VideoFilter.all, onTap: () => onFilterChanged(_VideoFilter.all)),
                const SizedBox(width: 10),
                _FilterChip(label: 'С видео', selected: filter == _VideoFilter.folders, onTap: () => onFilterChanged(_VideoFilter.folders)),
                const SizedBox(width: 10),
                _FilterChip(label: 'Пустые', selected: filter == _VideoFilter.videos, onTap: () => onFilterChanged(_VideoFilter.videos)),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: _C.green))
                : folders.isEmpty
                    ? Center(child: Text('Папки не найдены', style: _T.body(13)))
                    : RefreshIndicator(
                        color: _C.green,
                        onRefresh: onRefresh,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: folders.length,
                          itemBuilder: (_, index) {
                            final folder = folders[index];
                            return _FolderTile(
                              folder: folder,
                              selected: selectedFolderId == folder.id,
                              onTap: () => onSelectFolder(folder),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final VideoFolderModel folder;
  final bool selected;
  final VoidCallback onTap;

  const _FolderTile({required this.folder, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _C.greenSoft : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 86),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _C.line, width: .7))),
          child: Row(
            children: [
              Container(width: 4, height: 54, margin: const EdgeInsets.only(left: 14), decoration: BoxDecoration(color: selected ? _C.green : Colors.transparent, borderRadius: BorderRadius.circular(99))),
              const SizedBox(width: 14),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: selected ? Colors.white : _C.soft, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.folder_rounded, color: selected ? _C.green : _C.muted, size: 29),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(folder.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _T.title(15)),
                    const SizedBox(height: 5),
                    Text('${folder.lessonsCount} видео · ${folder.subfoldersCount} подпапок', style: _T.body(12)),
                    if (selected) ...[
                      const SizedBox(height: 4),
                      Text('ВЫБРАННАЯ ПАПКА', style: _T.action(color: _C.greenDark).copyWith(fontSize: 10.5)),
                    ],
                  ],
                ),
              ),
              const Padding(padding: EdgeInsets.only(right: 18), child: Icon(Icons.chevron_right_rounded, color: _C.subtle)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderOverviewPane extends StatelessWidget {
  final VideoFolderModel? folder;
  final List<VideoLessonModel> lessons;
  final int? selectedLessonId;
  final bool loading;
  final ValueChanged<VideoLessonModel> onOpenLesson;
  final ValueChanged<VideoLessonModel> onSelectLesson;
  final VoidCallback onAddLesson;

  const _FolderOverviewPane({
    required this.folder,
    required this.lessons,
    required this.selectedLessonId,
    required this.loading,
    required this.onOpenLesson,
    required this.onSelectLesson,
    required this.onAddLesson,
  });

  @override
  Widget build(BuildContext context) {
    final f = folder;
    if (f == null) {
      return Center(child: Text('Выберите папку слева', style: _T.body(14)));
    }

    final totalDuration = lessons.fold<int>(0, (sum, item) => sum + _durationMinutes(item.duration));
    final authors = lessons.map((e) => '${e.authorName} ${e.authorSurname}'.trim()).where((e) => e.isNotEmpty).toSet().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FolderHero(folder: f),
          const SizedBox(height: 18),
          _ActionGroup(
            actions: [
              _ActionData(Icons.play_circle_outline_rounded, 'Открыть первое видео', lessons.isEmpty ? null : () => onOpenLesson(lessons.first)),
              _ActionData(Icons.video_library_outlined, 'Видеоуроки папки', () {}),
              _ActionData(Icons.person_outline_rounded, 'Авторы', authors == 0 ? null : () {}),
              _ActionData(Icons.add_circle_outline_rounded, 'Добавить видео', onAddLesson),
            ],
          ),
          const SizedBox(height: 20),
          _MetricsStrip(items: [
            _Metric('${lessons.length}', 'Видео'),
            _Metric('${f.subfoldersCount}', 'Подпапки'),
            _Metric('$authors', 'Авторы'),
            _Metric(totalDuration == 0 ? '—' : '$totalDuration мин', 'Длительность'),
          ]),
          const SizedBox(height: 18),
          _NoticeCard(title: 'Сводка выбранной папки', text: lessons.isEmpty ? 'В этой папке пока нет видеоуроков. Добавьте первое видео кнопкой выше.' : 'В папке «${f.title}» доступно ${lessons.length} видеоуроков. Ниже можно выбрать урок, открыть просмотр или продолжить работу с материалами.'),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text('Видеоуроки', style: _T.title(17))),
              Text('${lessons.length}', style: _T.body(12)),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: _C.green)))
          else if (lessons.isEmpty)
            _EmptyLessons(onAddLesson: onAddLesson)
          else
            ...lessons.map((lesson) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LessonRow(
                    lesson: lesson,
                    selected: selectedLessonId == lesson.id,
                    onTap: () => onSelectLesson(lesson),
                    onOpen: () => onOpenLesson(lesson),
                  ),
                )),
        ],
      ),
    );
  }
}

class _FolderHero extends StatelessWidget {
  final VideoFolderModel folder;
  const _FolderHero({required this.folder});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 96, height: 96, decoration: BoxDecoration(color: _C.greenSoft, borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.folder_rounded, color: _C.green, size: 48)),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Container(width: 7, height: 7, decoration: const BoxDecoration(color: _C.green, shape: BoxShape.circle)), const SizedBox(width: 8), Text('Выбранная папка', style: _T.body(12, color: _C.greenDark))]),
              const SizedBox(height: 9),
              Text(folder.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _T.title(28)),
              const SizedBox(height: 8),
              Text('${folder.lessonsCount} видео  ·  ${folder.subfoldersCount} подпапок', style: _T.body(13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionData {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  const _ActionData(this.icon, this.title, this.onTap);
}

class _ActionGroup extends StatelessWidget {
  final List<_ActionData> actions;
  const _ActionGroup({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(13)),
      child: Column(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            _ActionRow(data: actions[i]),
            if (i != actions.length - 1) Container(height: .7, margin: const EdgeInsets.only(left: 58), color: _C.line),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final _ActionData data;
  const _ActionRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final enabled = data.onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 18),
              Icon(data.icon, color: enabled ? _C.green : _C.subtle, size: 22),
              const SizedBox(width: 18),
              Expanded(child: Text(data.title, style: _T.title(14).copyWith(color: enabled ? _C.text : _C.subtle))),
              Icon(enabled ? Icons.chevron_right_rounded : Icons.lock_outline_rounded, color: _C.subtle, size: 21),
              const SizedBox(width: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric { final String value; final String label; const _Metric(this.value, this.label); }

class _MetricsStrip extends StatelessWidget {
  final List<_Metric> items;
  const _MetricsStrip({required this.items});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(13)),
      child: Row(children: [for (var i = 0; i < items.length; i++) Expanded(child: Container(decoration: i == 0 ? null : const BoxDecoration(border: Border(left: BorderSide(color: _C.line))), child: Column(children: [Text(items[i].value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _T.title(18)), const SizedBox(height: 5), Text(items[i].label, style: _T.body(11.5))])))]),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String title;
  final String text;
  const _NoticeCard({required this.title, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.greenSoft, borderRadius: BorderRadius.circular(13)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.video_library_outlined, color: _C.green)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _T.title(14)), const SizedBox(height: 5), Text(text, style: _T.body(12.5))]))]),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final VideoLessonModel lesson;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  const _LessonRow({required this.lesson, required this.selected, required this.onTap, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final author = '${lesson.authorName} ${lesson.authorSurname}'.trim();
    return Material(
      color: selected ? _C.greenSoft : _C.soft,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            _LessonThumb(url: lesson.thumbnail),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(lesson.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _T.title(14)), const SizedBox(height: 5), Text([if (author.isNotEmpty) author, if (lesson.duration.isNotEmpty) lesson.duration].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: _T.body(11.5))])),
            IconButton(onPressed: onOpen, icon: const Icon(Icons.play_circle_fill_rounded, color: _C.green, size: 30)),
          ]),
        ),
      ),
    );
  }
}

class _LessonThumb extends StatelessWidget {
  final String url;
  const _LessonThumb({required this.url});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: 88, height: 54, child: url.trim().isEmpty ? const ColoredBox(color: _C.soft2, child: Icon(Icons.play_arrow_rounded, color: _C.green)) : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: _C.soft2, child: Icon(Icons.play_arrow_rounded, color: _C.green)))),
    );
  }
}

class _EmptyLessons extends StatelessWidget {
  final VoidCallback onAddLesson;
  const _EmptyLessons({required this.onAddLesson});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(13)), child: Column(children: [const Icon(Icons.video_library_outlined, color: _C.subtle, size: 36), const SizedBox(height: 10), Text('В папке пока нет видео', style: _T.title(14)), const SizedBox(height: 10), TextButton.icon(onPressed: onAddLesson, icon: const Icon(Icons.add_rounded), label: const Text('Добавить видео'))]));
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;
  const _SquareButton({required this.icon, required this.onTap, this.accent = false});
  @override
  Widget build(BuildContext context) {
    return Material(color: accent ? _C.greenSoft : Colors.white, borderRadius: BorderRadius.circular(12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(width: 48, height: 48, decoration: BoxDecoration(border: Border.all(color: accent ? _C.greenBorder : _C.line), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: accent ? _C.green : _C.text, size: 22))));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(color: selected ? _C.greenSoft : Colors.transparent, borderRadius: BorderRadius.circular(12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: selected ? _C.greenBorder : Colors.transparent), borderRadius: BorderRadius.circular(12)), child: Row(children: [Text(label, style: _T.action(color: selected ? _C.greenDark : _C.muted)), if (selected) ...[const SizedBox(width: 7), Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.green, shape: BoxShape.circle))]]))));
  }
}

int _durationMinutes(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 0;
  final parts = value.split(':').map((e) => int.tryParse(e) ?? 0).toList();
  if (parts.length == 3) return parts[0] * 60 + parts[1] + (parts[2] >= 30 ? 1 : 0);
  if (parts.length == 2) return parts[0] + (parts[1] >= 30 ? 1 : 0);
  return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}
