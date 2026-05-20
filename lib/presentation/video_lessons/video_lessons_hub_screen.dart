import 'package:flutter/material.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import '../../data/models/video_lesson_preview_data.dart';
import '../../data/services/video_lessons_service.dart';
import 'my_video_lessons_screen.dart';
import 'video_lesson_detail_screen.dart';
import 'video_lessons_authors_screen.dart';

enum _VideoFilter { all, recommended, my }

class VideoLessonsHubPalette {
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
  static const gold = Color(0xFFFFC83D);

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

class VideoLessonsHubScreen extends StatefulWidget {
  const VideoLessonsHubScreen({super.key});

  @override
  State<VideoLessonsHubScreen> createState() => _VideoLessonsHubScreenState();
}

class _VideoLessonsHubScreenState extends State<VideoLessonsHubScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _catalogScrollController = ScrollController();
  late TabController _tabController;

  int currentUserId = 0;
  bool isLoading = true;
  bool _isScrolled = false;

  List<VideoLessonPreviewData> previewLessons = [];
  _VideoFilter _filter = _VideoFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _catalogScrollController.addListener(() {
      final v = _catalogScrollController.offset > 8;
      if (v != _isScrolled && mounted) {
        setState(() => _isScrolled = v);
      }
    });

    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _catalogScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final id = await PrefUtils.getUserId();
    currentUserId = id ?? 0;
    await _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      previewLessons = await VideoLessonsService.getRandomPreviewLessons(
        limit: 40,
      );
    } catch (e) {
      debugPrint('VideoLessonsHubScreen load error: $e');
      previewLessons = [];
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _openLessonDetail(VideoLessonPreviewData item) async {
    final lessonId = item.lesson.id;

    if (lessonId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть видеоурок')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoLessonDetailScreen(lessonId: lessonId),
      ),
    );

    if (mounted) {
      await _loadData();
    }
  }

  bool _isTablet(double width) => width >= 900;

  int _gridCount(double width, Orientation orientation) {
    if (orientation == Orientation.portrait) {
      if (width >= 900) return 2;
      return 1;
    }

    if (width >= 900) return 3;
    return 1;
  }

  double _gridAspectRatio(double width, Orientation orientation) {
    if (orientation == Orientation.portrait) {
      if (width >= 900) return 1.18;
      return 0.86;
    }

    if (width >= 900) return 1.22;
    return 0.84;
  }

  List<VideoLessonPreviewData> get _filteredLessons {
    final q = _searchController.text.trim().toLowerCase();

    return previewLessons.where((item) {
      final title = item.lesson.title.toLowerCase();
      final desc = item.lesson.description.toLowerCase();

      final matchesSearch = q.isEmpty || title.contains(q) || desc.contains(q);

      bool matchesFilter = true;
      if (_filter == _VideoFilter.my) {
        matchesFilter = item.lesson.userId == currentUserId;
      } else if (_filter == _VideoFilter.recommended) {
        matchesFilter = true;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  String _buildMeta(VideoLessonPreviewData item) {
    final author =
        '${item.lesson.authorName ?? ''} ${item.lesson.authorSurname ?? ''}'
            .trim();

    final parts = <String>[];

    if (author.isNotEmpty) parts.add(author);
    if (item.lesson.duration.trim().isNotEmpty) {
      parts.add(item.lesson.duration.trim());
    }

    return parts.isEmpty ? 'Видеоурок' : parts.join(' • ');
  }

  String _buildTabletMeta(VideoLessonPreviewData item) {
    final author =
        '${item.lesson.authorName ?? ''} ${item.lesson.authorSurname ?? ''}'
            .trim();

    final parts = <String>[];

    if (author.isNotEmpty) {
      parts.add(author);
    }

    if (item.lesson.duration.trim().isNotEmpty) {
      parts.add(item.lesson.duration.trim());
    }

    return parts.isEmpty ? 'Видеоурок' : parts.join(' • ');
  }

  Widget _whiteCard({
    required Widget child,
    EdgeInsets? padding,
    VoidCallback? onTap,
    BorderRadius? radius,
  }) {
    final r = radius ?? BorderRadius.circular(20);

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: VideoLessonsHubPalette.white,
        borderRadius: r,
        border: Border.all(color: VideoLessonsHubPalette.border),
        boxShadow: VideoLessonsHubPalette.cardShadowSoft,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(
      borderRadius: r,
      onTap: onTap,
      child: card,
    );
  }

  void _openMenuPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: VideoLessonsHubPalette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VideoLessonsHubPalette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 20),
                _menuTile(
                  icon: Icons.ondemand_video_rounded,
                  title: 'Каталог',
                  subtitle: 'Все видеоуроки',
                  selected: _tabController.index == 0,
                  onTap: () {
                    Navigator.pop(context);
                    _tabController.animateTo(0);
                  },
                ),
                _menuTile(
                  icon: Icons.groups_rounded,
                  title: 'Авторы',
                  subtitle: 'Тренеры и создатели',
                  selected: _tabController.index == 1,
                  onTap: () {
                    Navigator.pop(context);
                    _tabController.animateTo(1);
                  },
                ),
                _menuTile(
                  icon: Icons.folder_rounded,
                  title: 'Мои материалы',
                  subtitle: 'Ваши уроки и папки',
                  selected: _tabController.index == 2,
                  onTap: () {
                    Navigator.pop(context);
                    _tabController.animateTo(2);
                  },
                ),
                const SizedBox(height: 8),
                const Divider(color: VideoLessonsHubPalette.border),
                const SizedBox(height: 8),
                _menuTile(
                  icon: Icons.refresh_rounded,
                  title: 'Обновить',
                  subtitle: 'Перезагрузить каталог',
                  selected: false,
                  onTap: () async {
                    Navigator.pop(context);
                    await _loadData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: selected ? VideoLessonsHubPalette.greenGradient : null,
            color: selected ? null : VideoLessonsHubPalette.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected ? Colors.transparent : VideoLessonsHubPalette.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.18)
                      : VideoLessonsHubPalette.superLightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? Colors.white
                      : VideoLessonsHubPalette.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: selected
                            ? Colors.white
                            : VideoLessonsHubPalette.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: selected
                            ? Colors.white.withOpacity(0.85)
                            : VideoLessonsHubPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar({
    required bool isTablet,
  }) {
    final title = _tabController.index == 0
        ? 'Видеоуроки'
        : _tabController.index == 1
            ? 'Авторы'
            : 'Мои материалы';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: VideoLessonsHubPalette.white,
        border: Border(
          bottom: BorderSide(
            color: _isScrolled
                ? VideoLessonsHubPalette.border
                : Colors.transparent,
          ),
        ),
        boxShadow: _isScrolled ? VideoLessonsHubPalette.cardShadowSoft : [],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 20 : 16,
            12,
            isTablet ? 20 : 16,
            12,
          ),
          child: Row(
            children: [
              if (!isTablet)
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: VideoLessonsHubPalette.superLightGreen,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: VideoLessonsHubPalette.border,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: VideoLessonsHubPalette.text,
                    ),
                  ),
                ),
              if (!isTablet) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: VideoLessonsHubPalette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tabController.index == 0
                          ? 'Каталог всех видеоуроков'
                          : _tabController.index == 1
                              ? 'Авторы и преподаватели'
                              : 'Ваши загруженные материалы',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: VideoLessonsHubPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  showSearch(
                    context: context,
                    delegate: _VideoSearchDelegate(
                      lessons: previewLessons,
                      onSelected: _openLessonDetail,
                    ),
                  );
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: VideoLessonsHubPalette.superLightGreen,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: VideoLessonsHubPalette.border,
                    ),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: VideoLessonsHubPalette.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openMenuPanel,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: VideoLessonsHubPalette.greenGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final items = [
      (
        icon: Icons.ondemand_video_rounded,
        title: 'Каталог',
        subtitle: 'Все видео',
        index: 0,
      ),
      (
        icon: Icons.groups_rounded,
        title: 'Авторы',
        subtitle: 'Сообщество',
        index: 1,
      ),
      (
        icon: Icons.folder_rounded,
        title: 'Мои материалы',
        subtitle: 'Ваш раздел',
        index: 2,
      ),
    ];

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: VideoLessonsHubPalette.white,
        border: const Border(
          right: BorderSide(color: VideoLessonsHubPalette.border),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      VideoLessonsHubPalette.primaryGreen.withOpacity(0.14),
                      VideoLessonsHubPalette.superLightGreen,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: VideoLessonsHubPalette.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: VideoLessonsHubPalette.greenGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.smart_display_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Видеоуроки',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: VideoLessonsHubPalette.text,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Каталог видео',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: VideoLessonsHubPalette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    ...items.map((item) {
                      final selected = _tabController.index == item.index;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _tabController.animateTo(item.index),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? VideoLessonsHubPalette.greenGradient
                                  : null,
                              color: selected
                                  ? null
                                  : VideoLessonsHubPalette.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? Colors.transparent
                                    : VideoLessonsHubPalette.border,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: VideoLessonsHubPalette
                                            .primaryGreen
                                            .withOpacity(0.16),
                                        blurRadius: 16,
                                        offset: const Offset(0, 7),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.white.withOpacity(0.18)
                                        : VideoLessonsHubPalette.superLightGreen,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    size: 20,
                                    color: selected
                                        ? Colors.white
                                        : VideoLessonsHubPalette.primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: selected
                                              ? Colors.white
                                              : VideoLessonsHubPalette.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.subtitle,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? Colors.white.withOpacity(0.86)
                                              : VideoLessonsHubPalette.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    _whiteCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Быстрые действия',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: VideoLessonsHubPalette.text,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _sidebarAction(
                            icon: Icons.refresh_rounded,
                            title: 'Обновить данные',
                            onTap: _loadData,
                          ),
                          const SizedBox(height: 8),
                          _sidebarAction(
                            icon: Icons.search_rounded,
                            title: 'Поиск уроков',
                            onTap: () {
                              showSearch(
                                context: context,
                                delegate: _VideoSearchDelegate(
                                  lessons: previewLessons,
                                  onSelected: _openLessonDetail,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebarAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: VideoLessonsHubPalette.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VideoLessonsHubPalette.border),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: VideoLessonsHubPalette.primaryGreen,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: VideoLessonsHubPalette.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: VideoLessonsHubPalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VideoLessonsHubPalette.border),
        boxShadow: VideoLessonsHubPalette.cardShadowSoft,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Поиск по названию или описанию',
          hintStyle: const TextStyle(
            color: VideoLessonsHubPalette.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: VideoLessonsHubPalette.textMuted,
            size: 20,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected ? VideoLessonsHubPalette.greenGradient : null,
            color: selected ? null : VideoLessonsHubPalette.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected ? Colors.transparent : VideoLessonsHubPalette.border,
            ),
            boxShadow: selected ? [] : VideoLessonsHubPalette.cardShadowSoft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? Colors.white
                      : VideoLessonsHubPalette.primaryGreen,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? Colors.white : VideoLessonsHubPalette.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogHeader(double width) {
    final isTablet = _isTablet(width);

    return Container(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 18 : 16,
        12,
        isTablet ? 18 : 16,
        8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSearchField()),
              const SizedBox(width: 10),
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: VideoLessonsHubPalette.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VideoLessonsHubPalette.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.video_library_outlined,
                      color: VideoLessonsHubPalette.primaryGreen,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${_filteredLessons.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: VideoLessonsHubPalette.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  label: 'Все видео',
                  icon: Icons.apps_rounded,
                  selected: _filter == _VideoFilter.all,
                  onTap: () {
                    setState(() {
                      _filter = _VideoFilter.all;
                    });
                  },
                ),
                _buildFilterChip(
                  label: 'Рекомендуемые',
                  icon: Icons.auto_awesome_rounded,
                  selected: _filter == _VideoFilter.recommended,
                  onTap: () {
                    setState(() {
                      _filter = _VideoFilter.recommended;
                    });
                  },
                ),
                _buildFilterChip(
                  label: 'Мои',
                  icon: Icons.person_rounded,
                  selected: _filter == _VideoFilter.my,
                  onTap: () {
                    setState(() {
                      _filter = _VideoFilter.my;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumb({
    required VideoLessonPreviewData item,
    BorderRadius radius = BorderRadius.zero,
  }) {
    final thumb = item.lesson.thumbnail;

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: thumb.isNotEmpty
                ? Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildThumbFallback(),
                  )
                : _buildThumbFallback(),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.28),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    size: 12,
                    color: VideoLessonsHubPalette.primaryGreen,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Урок',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: VideoLessonsHubPalette.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.74),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.lesson.duration.isNotEmpty ? item.lesson.duration : '00:00',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbFallback() {
    return Container(
      color: VideoLessonsHubPalette.superLightGreen,
      child: Center(
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: VideoLessonsHubPalette.greenGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: VideoLessonsHubPalette.primaryGreen.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorAvatar(String? avatar) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: VideoLessonsHubPalette.border, width: 2),
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundImage:
            (avatar ?? '').isNotEmpty ? NetworkImage(avatar!) : null,
        backgroundColor: VideoLessonsHubPalette.lightGreen,
        child: (avatar ?? '').isEmpty
            ? const Icon(
                Icons.person,
                color: VideoLessonsHubPalette.primaryGreen,
                size: 18,
              )
            : null,
      ),
    );
  }

  Widget _buildSmallAuthorAvatar(String? avatar) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: VideoLessonsHubPalette.border, width: 1.2),
      ),
      child: CircleAvatar(
        radius: 13,
        backgroundImage:
            (avatar ?? '').isNotEmpty ? NetworkImage(avatar!) : null,
        backgroundColor: VideoLessonsHubPalette.lightGreen,
        child: (avatar ?? '').isEmpty
            ? const Icon(
                Icons.person,
                color: VideoLessonsHubPalette.primaryGreen,
                size: 13,
              )
            : null,
      ),
    );
  }

  Widget _buildMobileVideoItem(VideoLessonPreviewData item) {
    final lesson = item.lesson;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: _whiteCard(
        radius: BorderRadius.circular(22),
        onTap: () => _openLessonDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumb(
              item: item,
              radius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAuthorAvatar(lesson.authorAvatar),
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
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                            color: VideoLessonsHubPalette.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _buildMeta(item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: VideoLessonsHubPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: VideoLessonsHubPalette.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: VideoLessonsHubPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletVideoCard(VideoLessonPreviewData item) {
    final lesson = item.lesson;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openLessonDetail(item),
      child: Container(
        decoration: BoxDecoration(
          color: VideoLessonsHubPalette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VideoLessonsHubPalette.border),
          boxShadow: VideoLessonsHubPalette.cardShadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumb(
              item: item,
              radius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSmallAuthorAvatar(lesson.authorAvatar),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.18,
                            fontWeight: FontWeight.w800,
                            color: VideoLessonsHubPalette.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _buildTabletMeta(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: VideoLessonsHubPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: VideoLessonsHubPalette.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.more_vert_rounded,
                      size: 16,
                      color: VideoLessonsHubPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton({required bool tablet}) {
    if (!tablet) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 20),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Container(
            decoration: BoxDecoration(
              color: VideoLessonsHubPalette.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: VideoLessonsHubPalette.border),
            ),
            child: Column(
              children: [
                Container(
                  height: 210,
                  decoration: BoxDecoration(
                    color: VideoLessonsHubPalette.superLightGreen,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: VideoLessonsHubPalette.superLightGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: VideoLessonsHubPalette.superLightGreen,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 12,
                              width: 150,
                              decoration: BoxDecoration(
                                color: VideoLessonsHubPalette.superLightGreen,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(
        color: VideoLessonsHubPalette.primaryGreen,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _whiteCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      VideoLessonsHubPalette.primaryGreen.withOpacity(0.12),
                      VideoLessonsHubPalette.superLightGreen,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.video_library_outlined,
                  size: 42,
                  color: VideoLessonsHubPalette.primaryGreen,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Видеоуроки не найдены',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: VideoLessonsHubPalette.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Попробуйте изменить поиск или фильтры',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: VideoLessonsHubPalette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCatalog() {
    final items = _filteredLessons;

    if (isLoading) return _buildLoadingSkeleton(tablet: false);
    if (items.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: VideoLessonsHubPalette.primaryGreen,
      child: ListView.builder(
        controller: _catalogScrollController,
        padding: const EdgeInsets.only(top: 12, bottom: 20),
        itemCount: items.length,
        itemBuilder: (_, index) => _buildMobileVideoItem(items[index]),
      ),
    );
  }

  Widget _buildTabletCatalog(double width, Orientation orientation) {
    final items = _filteredLessons;
    final crossAxisCount = _gridCount(width, orientation);

    if (isLoading) return _buildLoadingSkeleton(tablet: true);
    if (items.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: VideoLessonsHubPalette.primaryGreen,
      child: GridView.builder(
        controller: _catalogScrollController,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: _gridAspectRatio(width, orientation),
        ),
        itemBuilder: (_, index) => _buildTabletVideoCard(items[index]),
      ),
    );
  }

  Widget _buildCatalogTab(double width, Orientation orientation) {
    final isTablet = _isTablet(width);

    return Container(
      color: VideoLessonsHubPalette.background,
      child: Column(
        children: [
          _buildCatalogHeader(width),
          Expanded(
            child: isTablet
                ? _buildTabletCatalog(width, orientation)
                : _buildMobileCatalog(),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorsTab() {
    return Container(
      color: VideoLessonsHubPalette.background,
      child: const SafeArea(
        top: false,
        bottom: false,
        child: VideoLessonsAuthorsScreen(),
      ),
    );
  }

  Widget _buildMyLessonsTab() {
    return Container(
      color: VideoLessonsHubPalette.background,
      child: const SafeArea(
        top: false,
        bottom: false,
        child: MyVideoLessonsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isTablet = _isTablet(width);

            if (isTablet) {
              final contentWidth = width - 240;

              return Scaffold(
                backgroundColor: VideoLessonsHubPalette.background,
                body: Row(
                  children: [
                    _buildSidebar(),
                    Expanded(
                      child: Column(
                        children: [
                          _buildTopBar(isTablet: true),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildCatalogTab(contentWidth, orientation),
                                _buildAuthorsTab(),
                                _buildMyLessonsTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              backgroundColor: VideoLessonsHubPalette.background,
              body: Column(
                children: [
                  _buildTopBar(isTablet: false),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildCatalogTab(width, orientation),
                        _buildAuthorsTab(),
                        _buildMyLessonsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _VideoSearchDelegate extends SearchDelegate {
  final List<VideoLessonPreviewData> lessons;
  final Future<void> Function(VideoLessonPreviewData item) onSelected;

  _VideoSearchDelegate({
    required this.lessons,
    required this.onSelected,
  });

  @override
  String? get searchFieldLabel => 'Поиск видеоуроков';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);

    return theme.copyWith(
      scaffoldBackgroundColor: VideoLessonsHubPalette.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: VideoLessonsHubPalette.white,
        foregroundColor: VideoLessonsHubPalette.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: const TextStyle(
          color: VideoLessonsHubPalette.text,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.close_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchList(context);
  }

  Widget _buildSearchList(BuildContext context) {
    final q = query.trim().toLowerCase();

    final items = lessons.where((e) {
      final title = e.lesson.title.toLowerCase();
      final desc = e.lesson.description.toLowerCase();
      return q.isEmpty || title.contains(q) || desc.contains(q);
    }).toList();

    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: VideoLessonsHubPalette.textSoft,
            ),
            SizedBox(height: 14),
            Text(
              'Ничего не найдено',
              style: TextStyle(
                color: VideoLessonsHubPalette.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final author =
            '${item.lesson.authorName ?? ''} ${item.lesson.authorSurname ?? ''}'
                .trim();

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              close(context, null);
              await onSelected(item);
            },
            child: Container(
              decoration: BoxDecoration(
                color: VideoLessonsHubPalette.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: VideoLessonsHubPalette.border),
                boxShadow: VideoLessonsHubPalette.cardShadowSoft,
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: VideoLessonsHubPalette.lightGreen,
                  backgroundImage: (item.lesson.authorAvatar ?? '').isNotEmpty
                      ? NetworkImage(item.lesson.authorAvatar!)
                      : null,
                  child: (item.lesson.authorAvatar ?? '').isEmpty
                      ? const Icon(
                          Icons.play_arrow_rounded,
                          color: VideoLessonsHubPalette.primaryGreen,
                        )
                      : null,
                ),
                title: Text(
                  item.lesson.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: VideoLessonsHubPalette.text,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    author.isEmpty ? 'Видеоурок' : author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: VideoLessonsHubPalette.textMuted,
                    ),
                  ),
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: VideoLessonsHubPalette.superLightGreen,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: VideoLessonsHubPalette.primaryGreen,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}