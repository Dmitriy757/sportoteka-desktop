import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/video_lesson_author_model.dart';
import '../../data/services/video_lessons_service.dart';
import 'video_lessons_screen.dart';

class VideoLessonsAuthorsPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);

  static const lightGreen = Color(0xFFE8F5E9);
  static const superLightGreen = Color(0xFFF2FFF5);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);

  static const background = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);
  static const gold = Color(0xFFFFC83D);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class VideoLessonsAuthorsScreen extends StatefulWidget {
  const VideoLessonsAuthorsScreen({super.key});

  @override
  State<VideoLessonsAuthorsScreen> createState() =>
      _VideoLessonsAuthorsScreenState();
}

class _VideoLessonsAuthorsScreenState extends State<VideoLessonsAuthorsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  bool _error = false;
  bool _refreshing = false;
  String? _errorMessage;

  List<VideoLessonAuthorModel> _authors = [];
  List<String> _hashtags = [];
  String _selectedHashtag = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _loadAuthors();
    });
  }

  Future<void> _loadAll() async {
    if (!mounted) return;

    setState(() {
      if (_authors.isEmpty) _loading = true;
      _refreshing = true;
      _error = false;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        VideoLessonsService.getAuthors(
          query: _searchCtrl.text.trim(),
          hashtag: _selectedHashtag,
        ),
        VideoLessonsService.getHashtags(),
      ]);

      if (!mounted) return;

      setState(() {
        _authors = results[0] as List<VideoLessonAuthorModel>;
        _hashtags = results[1] as List<String>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _errorMessage = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _loadAuthors() async {
    if (!mounted) return;

    setState(() {
      if (_authors.isEmpty) _loading = true;
      _refreshing = true;
      _error = false;
      _errorMessage = null;
    });

    try {
      final data = await VideoLessonsService.getAuthors(
        query: _searchCtrl.text.trim(),
        hashtag: _selectedHashtag,
      );

      if (!mounted) return;
      setState(() {
        _authors = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _errorMessage = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  String _normalizeMediaUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('/')) return 'https://sportotekaapp.ru$s';
    return 'https://sportotekaapp.ru/$s';
  }

  Widget _whiteCard({
    required Widget child,
    EdgeInsets? padding,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VideoLessonsAuthorsPalette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VideoLessonsAuthorsPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
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
              fontSize: 15,
              color: VideoLessonsAuthorsPalette.text,
            ),
          ),
        ),
        if (action != null)
          Text(
            action,
            style: const TextStyle(
              color: VideoLessonsAuthorsPalette.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _metricChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: VideoLessonsAuthorsPalette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: VideoLessonsAuthorsPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: VideoLessonsAuthorsPalette.primaryGreen,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: VideoLessonsAuthorsPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(double rating) {
    final rounded = rating.round().clamp(0, 5);
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rounded ? Icons.star_rounded : Icons.star_border_rounded,
          size: 16,
          color: VideoLessonsAuthorsPalette.gold,
        );
      }),
    );
  }

  int get _totalLessons =>
      _authors.fold<int>(0, (sum, author) => sum + author.lessonsCount);

  int get _totalFolders =>
      _authors.fold<int>(0, (sum, author) => sum + author.foldersCount);

  double get _avgRating {
    if (_authors.isEmpty) return 0;
    final total = _authors.fold<double>(0, (sum, author) => sum + author.rating);
    return total / _authors.length;
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            VideoLessonsAuthorsPalette.primaryGreen.withOpacity(0.12),
            VideoLessonsAuthorsPalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VideoLessonsAuthorsPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: VideoLessonsAuthorsPalette.greenGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.video_library_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Авторы видеоуроков',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: VideoLessonsAuthorsPalette.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Поиск тренеров и каталог их видеоуроков',
                      style: TextStyle(
                        color: VideoLessonsAuthorsPalette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: VideoLessonsAuthorsPalette.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: VideoLessonsAuthorsPalette.border),
                ),
                child: Text(
                  '${_authors.length} авторов',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: VideoLessonsAuthorsPalette.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(Icons.people_alt_rounded, 'Авторов ${_authors.length}'),
              _metricChip(Icons.folder_copy_rounded, 'Папок $_totalFolders'),
              _metricChip(Icons.play_circle_fill_rounded, 'Уроков $_totalLessons'),
              _metricChip(
                Icons.star_rounded,
                _avgRating == 0 ? '0.0' : _avgRating.toStringAsFixed(1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return _whiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 22,
            color: VideoLessonsAuthorsPalette.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Поиск по тренеру или видеоуроку',
                hintStyle: TextStyle(
                  color: VideoLessonsAuthorsPalette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchCtrl.clear();
                _loadAuthors();
              },
              icon: const Icon(Icons.close_rounded),
              color: VideoLessonsAuthorsPalette.textMuted,
            ),
          Container(
            decoration: BoxDecoration(
              gradient: VideoLessonsAuthorsPalette.greenGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _loadAll,
              tooltip: 'Обновить',
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashtagsBlock() {
    if (_hashtags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _hashtags.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          if (index == 0) {
            final selected = _selectedHashtag.isEmpty;
            return _HashChip(
              label: 'Все',
              selected: selected,
              onTap: () {
                setState(() => _selectedHashtag = '');
                _loadAuthors();
              },
            );
          }

          final tag = _hashtags[index - 1];
          final selected = _selectedHashtag == tag;

          return _HashChip(
            label: tag,
            selected: selected,
            onTap: () {
              setState(() => _selectedHashtag = tag);
              _loadAuthors();
            },
          );
        },
      ),
    );
  }

  Widget _buildAuthorCard(VideoLessonAuthorModel author) {
    final avatar = _normalizeMediaUrl(author.avatar);
    final fullName = '${author.name} ${author.surname}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _whiteCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoLessonsScreen(
                ownerUserId: author.id,
                ownerName: fullName.isEmpty ? 'Автор' : fullName,
                isMyMode: false,
              ),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: VideoLessonsAuthorsPalette.lightGreen,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: VideoLessonsAuthorsPalette.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar.isNotEmpty
                  ? Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        color: VideoLessonsAuthorsPalette.primaryGreen,
                        size: 28,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: VideoLessonsAuthorsPalette.primaryGreen,
                      size: 28,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName.isEmpty ? 'Автор' : fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                      color: VideoLessonsAuthorsPalette.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStars(author.rating),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metricChip(
                        Icons.folder_copy_rounded,
                        'Папок ${author.foldersCount}',
                      ),
                      _metricChip(
                        Icons.play_circle_fill_rounded,
                        'Уроков ${author.lessonsCount}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: VideoLessonsAuthorsPalette.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    Widget bar({double? w, double h = 10}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(999),
          ),
        );

    return _whiteCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(w: 150, h: 12),
                const SizedBox(height: 8),
                bar(w: 90, h: 10),
                const SizedBox(height: 10),
                bar(w: 130, h: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return _whiteCard(
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 10),
          const Text(
            'Ошибка загрузки',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: VideoLessonsAuthorsPalette.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Попробуйте ещё раз',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VideoLessonsAuthorsPalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              gradient: VideoLessonsAuthorsPalette.greenGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextButton(
              onPressed: _loadAll,
              child: const Text(
                'Повторить',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return _whiteCard(
      child: Column(
        children: const [
          Icon(
            Icons.video_library_outlined,
            size: 36,
            color: VideoLessonsAuthorsPalette.textMuted,
          ),
          SizedBox(height: 10),
          Text(
            'Пока нет авторов видеоуроков',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: VideoLessonsAuthorsPalette.text,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VideoLessonsAuthorsPalette.background,
      child: RefreshIndicator(
        onRefresh: _loadAll,
        color: VideoLessonsAuthorsPalette.primaryGreen,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 12),
            _buildSearchCard(),
            const SizedBox(height: 10),
            _buildHashtagsBlock(),
            const SizedBox(height: 12),
            _sectionTitle('Авторы', action: '${_authors.length}'),
            const SizedBox(height: 8),
            if (_loading && _authors.isEmpty) ...[
              _buildSkeletonCard(),
              const SizedBox(height: 10),
              _buildSkeletonCard(),
              const SizedBox(height: 10),
              _buildSkeletonCard(),
            ] else if (_error) ...[
              _buildErrorState(),
            ] else if (_authors.isEmpty) ...[
              _buildEmptyState(),
            ] else ...[
              ..._authors.map(_buildAuthorCard),
              if (_refreshing)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: VideoLessonsAuthorsPalette.primaryGreen,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HashChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HashChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? VideoLessonsAuthorsPalette.superLightGreen
        : VideoLessonsAuthorsPalette.white;

    final border = selected
        ? VideoLessonsAuthorsPalette.primaryGreen.withOpacity(0.25)
        : VideoLessonsAuthorsPalette.border;

    final text = selected
        ? VideoLessonsAuthorsPalette.primaryGreen
        : VideoLessonsAuthorsPalette.textMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}