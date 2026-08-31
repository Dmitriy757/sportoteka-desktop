import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';
import 'package:sportoteka/presentation/community_screen/app_video_player_screen.dart';
import 'package:sportoteka/presentation/community_screen/in_app_web_video_screen.dart';
import 'package:sportoteka/presentation/community_screen/news_detail_screen.dart';
import 'package:sportoteka/presentation/community_screen/create_post_editor_screen.dart';
import 'package:sportoteka/presentation/community_screen/create_content_screen.dart';
import 'package:sportoteka/presentation/community_screen/post_blocks.dart';

class FeedPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF067A46);
  static const primaryGreenLight = Color(0xFF00C060);

  static const lightGreen = Color(0xFFE8F5E9);
  static const superLightGreen = Color(0xFFF2FFF5);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF0B0F14);
  static const textMuted = Color(0xFF667085);

  static const background = Color(0xFFFFFFFF);
  static const border = Color(0xFFF0F2F1);
  static const soft = Color(0xFFF7F9F8);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenBorder = Color(0xFFD7F0E2);
  static const graphite = Color(0xFF111827);
  static const secondary = Color(0xFF5F6670);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class SportCommunityScreen extends StatefulWidget {
  final String sportName;
  final bool embedded;

  const SportCommunityScreen({
    super.key,
    required this.sportName,
    this.embedded = false,
  });

  @override
  State<SportCommunityScreen> createState() => _SportCommunityScreenState();
}

class _SportCommunityScreenState extends State<SportCommunityScreen> {
  static const _apiBase = "https://sportotekaapp.ru/api";

  List<Map<String, dynamic>> posts = [];
  bool isLoading = false;
  bool isRefreshing = false;
  bool _showCreateEditor = false;
  Map<String, dynamic>? _editingPost;
  Map<String, dynamic>? _openedPost;
  bool _openedPostFocusComment = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyMine = false;

  int _currentUserId = 0;

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
    final uid = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;
    setState(() => _currentUserId = uid);
    await _fetchPosts();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _htmlToPlain(String html) {
    var t = html;

    t = t.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    t = t.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n');
    t = t.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');

    t = t.replaceAll('&nbsp;', ' ');
    t = t.replaceAll('&amp;', '&');
    t = t.replaceAll('&quot;', '"');
    t = t.replaceAll('&#39;', "'");
    t = t.replaceAll('&lt;', '<');
    t = t.replaceAll('&gt;', '>');

    return t.trim();
  }

  bool _looksLikeHtml(String s) {
    final t = s.trim().toLowerCase();
    return t.contains('<p') ||
        t.contains('<br') ||
        t.contains('</') ||
        t.contains('<div') ||
        t.contains('<span') ||
        t.contains('<video') ||
        t.contains('<a ') ||
        t.contains('<img');
  }

  String _safeStr(dynamic v) => (v ?? '').toString();
  int _safeInt(dynamic v) => int.tryParse(_safeStr(v)) ?? 0;

  String _fixUrl(String s) {
    final u = s.trim();
    if (u.isEmpty) return "";
    if (u.startsWith("http://") || u.startsWith("https://")) return u;
    return "https://sportotekaapp.ru/$u";
  }

  bool _looksLikeDirectVideoUrl(String url) {
    final clean = url.toLowerCase().split('?').first.split('#').first;
    return clean.endsWith(".mp4") ||
        clean.endsWith(".mov") ||
        clean.endsWith(".m4v") ||
        clean.endsWith(".webm") ||
        clean.endsWith(".m3u8");
  }

  bool _looksLikeExternalVideoPage(String url) {
    final u = url.toLowerCase();
    return u.contains("youtube.com/") ||
        u.contains("youtu.be/") ||
        u.contains("vimeo.com/") ||
        u.contains("rutube.ru/") ||
        u.contains("vkvideo.ru/") ||
        u.contains("vk.com/video") ||
        u.contains("dailymotion.com/") ||
        u.contains("tiktok.com/") ||
        u.contains("drive.google.com/") ||
        u.contains("dropbox.com/");
  }

  String? _tryBuildAutoThumbnail(String url) {
    try {
      final uri = Uri.parse(url);

      if (uri.host.contains("youtu.be")) {
        if (uri.pathSegments.isNotEmpty) {
          final id = uri.pathSegments.first.trim();
          if (id.isNotEmpty) {
            return "https://img.youtube.com/vi/$id/hqdefault.jpg";
          }
        }
      }

      if (uri.host.contains("youtube.com")) {
        final v = uri.queryParameters["v"];
        if (v != null && v.trim().isNotEmpty) {
          return "https://img.youtube.com/vi/${v.trim()}/hqdefault.jpg";
        }

        final segments = uri.pathSegments;

        final shortsIndex = segments.indexOf("shorts");
        if (shortsIndex != -1 && shortsIndex + 1 < segments.length) {
          final id = segments[shortsIndex + 1].trim();
          if (id.isNotEmpty) {
            return "https://img.youtube.com/vi/$id/hqdefault.jpg";
          }
        }

        final embedIndex = segments.indexOf("embed");
        if (embedIndex != -1 && embedIndex + 1 < segments.length) {
          final id = segments[embedIndex + 1].trim();
          if (id.isNotEmpty) {
            return "https://img.youtube.com/vi/$id/hqdefault.jpg";
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Map<String, dynamic> _extractPostPreview(String rawBody) {
    final html = _looksLikeHtml(rawBody)
        ? rawBody
        : '<p>${const HtmlEscape().convert(rawBody)}</p>';

    final blocks = PostHtmlParser.htmlToBlocks(html);

    String previewImage = "";
    String videoUrl = "";
    bool hasVideo = false;

    for (final b in blocks) {
      if (b is VideoBlock) {
        hasVideo = true;
        videoUrl = _fixUrl(b.url);

        if (b.thumbnail.trim().isNotEmpty) {
          previewImage = _fixUrl(b.thumbnail);
          break;
        }

        final autoThumb = _tryBuildAutoThumbnail(b.url);
        if ((autoThumb ?? '').isNotEmpty) {
          previewImage = autoThumb ?? '';
          break;
        }
      }
    }

    return {
      "hasVideo": hasVideo,
      "videoUrl": videoUrl,
      "previewImage": previewImage,
    };
  }

  String _formatPostDate(dynamic v) {
    if (v is! DateTime) return '';
    final now = DateTime.now();
    final diff = now.difference(v);

    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return '${v.day.toString().padLeft(2, '0')}.${v.month.toString().padLeft(2, '0')}.${v.year}';
  }

  Future<void> _fetchPosts() async {
    if (!mounted) return;
    setState(() {
      if (posts.isEmpty) isLoading = true;
      isRefreshing = true;
    });

    try {
      final uri = Uri.parse('$_apiBase/get_posts.php?user_id=$_currentUserId');
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);

        final List<dynamic> data = decoded is List
            ? decoded
            : (decoded is Map && decoded['posts'] is List)
                ? (decoded['posts'] as List)
                : [];

        // Community и профиль — разные источники публикаций.
        // Даже если get_posts.php вернёт оба типа, профильные посты
        // никогда не должны попадать в общую Community-ленту.
        final filtered = data.where((raw) {
          if (raw is! Map) return false;

          final category =
              (raw['category'] ?? '').toString().trim().toLowerCase();
          if (category != widget.sportName.toLowerCase()) return false;

          final visibility =
              (raw['visibility'] ?? '').toString().trim().toLowerCase();
          if (visibility == 'profile') return false;

          final postType =
              (raw['post_type'] ?? '').toString().trim().toLowerCase();
          if (postType.isNotEmpty && postType != 'post') return false;

          return true;
        });

        final list = filtered.map((raw) {
          final firstName = _safeStr(raw['first_name']);
          final lastName = _safeStr(raw['last_name']);
          final fullName = ('$firstName $lastName').trim();

          final image = _fixUrl(_safeStr(raw['image']));
          final avatar = _fixUrl(
            _safeStr(raw['photo'] ?? raw['photo_url'] ?? raw['avatar']),
          );

          final rawBody = _safeStr(raw['body']);
          final plainBody = _looksLikeHtml(rawBody) ? _htmlToPlain(rawBody) : rawBody;

          final preview = _extractPostPreview(rawBody);
          final previewImage = _safeStr(preview['previewImage']);
          final hasVideo = preview['hasVideo'] == true;
          final videoUrl = _safeStr(preview['videoUrl']);

          return <String, dynamic>{
            'id': _safeInt(raw['id']),
            'title': _safeStr(raw['title']),
            'text': plainBody,
            'rawBody': rawBody,
            'category': _safeStr(raw['category']),
            'team': _safeStr(raw['team'] ?? raw['team_name']),
            'coverUrl': image,
            'imageUrl': image.isNotEmpty ? image : previewImage,
            'hasVideo': hasVideo,
            'videoUrl': videoUrl,
            'date': DateTime.tryParse(_safeStr(raw['created_at'])) ?? DateTime.now(),
            'authorName': fullName.isNotEmpty
                ? fullName
                : (_safeStr(raw['author_name']).isNotEmpty
                    ? _safeStr(raw['author_name'])
                    : 'Пользователь'),
            'user_id': _safeInt(raw['user_id']),
            'authorAvatar': avatar,
            'likes': _safeInt(raw['likes_count']),
            'comments': _safeInt(raw['comments_count']),
            'liked': (_safeInt(raw['liked_by_me']) == 1) ||
                (_safeStr(raw['liked_by_me']).toLowerCase() == 'true'),
          };
        }).toList();

        if (!mounted) return;
        setState(() => posts = list);
      } else {
        _showError('Ошибка загрузки: ${res.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка загрузки: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
    }
  }

  Future<void> _openCreateEditor() async {
    if (!mounted) return;
    setState(() {
      _editingPost = null;
      _openedPost = null;
      _showCreateEditor = true;
    });
  }

  Future<void> _openEditEditor(Map<String, dynamic> post) async {
    if (!mounted) return;
    if (_safeInt(post['user_id']) != _currentUserId) return;
    setState(() {
      _editingPost = Map<String, dynamic>.from(post);
      _openedPost = null;
      _showCreateEditor = true;
    });
  }

  Future<void> _closeCreateEditor({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      _showCreateEditor = false;
      _editingPost = null;
    });
    if (refresh) await _fetchPosts();
  }

  Future<void> _toggleLike(int postId) async {
    if (_currentUserId <= 0) {
      _showError("Нужно войти в аккаунт");
      return;
    }

    final index = posts.indexWhere((p) => _safeInt(p['id']) == postId);
    if (index < 0) return;
    final bool wasLiked = (posts[index]['liked'] == true);

    setState(() {
      posts[index]['liked'] = !wasLiked;
      posts[index]['likes'] =
          (posts[index]['likes'] ?? 0) + (wasLiked ? -1 : 1);
      if ((posts[index]['likes'] ?? 0) < 0) posts[index]['likes'] = 0;
    });

    try {
      final endpoint =
          wasLiked ? '$_apiBase/unlike_post.php' : '$_apiBase/like_post.php';

      final res = await http.post(
        Uri.parse(endpoint),
        body: {
          'post_id': postId.toString(),
          'user_id': _currentUserId.toString(),
        },
      );

      if (res.statusCode != 200) {
        setState(() {
          posts[index]['liked'] = wasLiked;
          posts[index]['likes'] =
              (posts[index]['likes'] ?? 0) + (wasLiked ? 1 : -1);
          if ((posts[index]['likes'] ?? 0) < 0) posts[index]['likes'] = 0;
        });
        return;
      }

      final j = json.decode(res.body);
      final ok = (j is Map &&
          (j['success'] == true ||
              j['status'] == 'ok' ||
              j['status'] == 'already_liked'));
      if (!ok) {
        setState(() {
          posts[index]['liked'] = wasLiked;
          posts[index]['likes'] =
              (posts[index]['likes'] ?? 0) + (wasLiked ? 1 : -1);
          if ((posts[index]['likes'] ?? 0) < 0) posts[index]['likes'] = 0;
        });
      }
    } catch (_) {
      setState(() {
        posts[index]['liked'] = wasLiked;
        posts[index]['likes'] =
            (posts[index]['likes'] ?? 0) + (wasLiked ? 1 : -1);
        if ((posts[index]['likes'] ?? 0) < 0) posts[index]['likes'] = 0;
      });
    }
  }

  List<String> _hashtagsForPost(Map<String, dynamic> post) {
    final source = '${_safeStr(post['title'])} ${_safeStr(post['text'])}';
    final matches = RegExp(r'#([A-Za-zА-Яа-яЁё0-9_]{2,40})', unicode: true)
        .allMatches(source);
    final out = <String>[];
    final seen = <String>{};
    for (final match in matches) {
      final value = '#${match.group(1) ?? ''}';
      final key = value.toLowerCase();
      if (value.length > 1 && seen.add(key)) out.add(value);
    }
    return out;
  }

  List<Map<String, dynamic>> get _visiblePosts {
    final q = _searchQuery.trim().toLowerCase();
    return posts.where((post) {
      if (_onlyMine && _safeInt(post['user_id']) != _currentUserId) {
        return false;
      }
      if (q.isEmpty) return true;
      final tags = _hashtagsForPost(post).join(' ');
      final haystack = <String>[
        _safeStr(post['title']),
        _safeStr(post['text']),
        _safeStr(post['authorName']),
        _safeStr(post['team']),
        _safeStr(post['category']),
        tags,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList(growable: false);
  }

  void _setSearch(String value) {
    if (!mounted) return;
    setState(() => _searchQuery = value);
  }

  void _activateHashtag(String hashtag) {
    _searchController.text = hashtag;
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
    _setSearch(hashtag);
  }

  void _clearSearch() {
    _searchController.clear();
    _setSearch('');
  }

  Future<void> _deleteOwnPost(Map<String, dynamic> post) async {
    final postId = _safeInt(post['id']);
    if (postId <= 0 || _safeInt(post['user_id']) != _currentUserId) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить публикацию?'),
        content: const Text('Публикация и её комментарии будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final res = await http.post(
        Uri.parse('$_apiBase/delete_post.php'),
        body: {
          'post_id': postId.toString(),
          'user_id': _currentUserId.toString(),
        },
      );
      if (res.statusCode != 200) {
        _showError('Не удалось удалить публикацию');
        return;
      }
      final decoded = json.decode(res.body);
      final success = decoded is Map &&
          (decoded['success'] == true ||
              decoded['status'] == 'ok' ||
              decoded['status'] == 'deleted');
      if (!success) {
        _showError('Не удалось удалить публикацию');
        return;
      }
      if (!mounted) return;
      setState(() {
        posts.removeWhere((p) => _safeInt(p['id']) == postId);
        if (_safeInt(_openedPost?['id']) == postId) _openedPost = null;
      });
    } catch (_) {
      _showError('Ошибка сети при удалении');
    }
  }

  void _openVideoInsideApp({
    required String title,
    required String url,
    String thumbnail = "",
  }) {
    if (_looksLikeDirectVideoUrl(url)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppVideoPlayerScreen(
            title: title,
            videoUrl: url,
            thumbnailUrl: thumbnail,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InAppWebVideoScreen(
            title: title,
            url: url,
          ),
        ),
      );
    }
  }

  void _openPost(Map<String, dynamic> post, {required bool focusComment}) {
    final width = MediaQuery.sizeOf(context).width;

    // Как в CMR roster: на планшете и ПК детали раскрываются внутри
    // текущего рабочего окна. Отдельный маршрут оставляем только телефону.
    if (width >= 640) {
      setState(() {
        _openedPost = Map<String, dynamic>.from(post);
        _openedPostFocusComment = focusComment;
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(
          title: _safeStr(post['title']).isNotEmpty
              ? _safeStr(post['title'])
              : widget.sportName,
          body: _safeStr(post['text']),
          newsId: _safeInt(post['id']),
          imageUrl: _safeStr(post['imageUrl']),
          focusCommentOnOpen: focusComment,
        ),
      ),
    ).then((_) => _fetchPosts());
  }

  void _closeOpenedPost() {
    if (!mounted) return;
    setState(() {
      _openedPost = null;
      _openedPostFocusComment = false;
    });
    _fetchPosts();
  }

  TextStyle _title(double size, {FontWeight weight = FontWeight.w600, Color color = FeedPalette.text}) {
    final TextStyle base;
    if (size >= 15.5) {
      base = AppTypography.screenTitle(color: color);
    } else if (size >= 14) {
      base = AppTypography.sectionTitle(color: color);
    } else if (size >= 13) {
      base = AppTypography.subsectionTitle(color: color);
    } else if (size >= 11.5) {
      base = AppTypography.itemTitle(color: color);
    } else {
      base = AppTypography.captionMedium(color: color);
    }
    return base.copyWith(fontWeight: weight);
  }

  TextStyle _text(double size, {FontWeight weight = FontWeight.w400, Color color = FeedPalette.secondary}) {
    final TextStyle base;
    if (size >= 12.5) {
      base = AppTypography.body(color: color);
    } else if (size >= 11.2) {
      base = AppTypography.secondary(color: color);
    } else if (size >= 10) {
      base = AppTypography.caption(color: color);
    } else {
      base = AppTypography.commentMeta(color: color);
    }
    return base.copyWith(fontWeight: weight);
  }

  Widget _statusDot({
    required Color color,
    double size = 5,
    bool glow = true,
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
                  color: color.withOpacity(.16),
                  blurRadius: size * 1.8,
                  spreadRadius: .2,
                ),
              ]
            : null,
      ),
    );
  }

  Color _postAccent(Map<String, dynamic> post) {
    final hasVideo = post['hasVideo'] == true;
    final image = _safeStr(post['imageUrl']).trim();
    final text = _safeStr(post['text']).toLowerCase();
    if (hasVideo) return const Color(0xFFF59E0B);
    if (image.isNotEmpty) return const Color(0xFFF59E0B);
    if (text.contains('http://') || text.contains('https://')) {
      return FeedPalette.primaryGreenDark;
    }
    return FeedPalette.primaryGreen;
  }

  String _postKind(Map<String, dynamic> post) {
    final hasVideo = post['hasVideo'] == true;
    final image = _safeStr(post['imageUrl']).trim();
    final text = _safeStr(post['text']).toLowerCase();
    if (hasVideo) return 'Видео';
    if (image.isNotEmpty) return 'Фото';
    if (text.contains('http://') || text.contains('https://')) {
      return 'Ссылка';
    }
    return 'Текст';
  }

  Widget _brandDots({Color color = FeedPalette.primaryGreen}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final item in const <(double, double)>[
          (3.5, .34),
          (4.5, .48),
          (5.5, .68),
          (6.5, 1.0),
        ]) ...[
          Container(
            width: item.$1,
            height: item.$1,
            decoration: BoxDecoration(
              color: color.withOpacity(item.$2),
              shape: BoxShape.circle,
              boxShadow: item.$2 >= .9
                  ? [
                      BoxShadow(
                        color: color.withOpacity(.16),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 3),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final mobile = width < 640;
        final desktop = width >= 700;
        final supportsSidePanel = width >= 600;
        final horizontal = mobile ? 0.0 : 10.0;
        final visiblePosts = _visiblePosts;

        final feed = RefreshIndicator(
          onRefresh: _fetchPosts,
          color: FeedPalette.primaryGreen,
          child: ListView(
            physics: mobile
                ? const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  )
                : const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontal,
              mobile ? 0 : 10,
              horizontal,
              mobile ? 116 : 18,
            ),
            children: [
              if (!mobile) ...[
                _buildHeaderCard(),
                const SizedBox(height: 10),
              ],
              _buildFeedControls(
                mobile: mobile,
                resultCount: visiblePosts.length,
              ),
              if (!mobile) ...[
                const SizedBox(height: 10),
                _buildCreatePostCard(),
              ],
              SizedBox(height: mobile ? 2 : 10),
              if (isLoading && posts.isEmpty) ...[
                _buildSkeletonPost(),
                const SizedBox(height: 8),
                _buildSkeletonPost(),
              ] else if (visiblePosts.isEmpty) ...[
                _buildEmptyFeedState(),
              ] else ...[
                ...List.generate(
                  visiblePosts.length,
                  (i) => _buildPostCard(visiblePosts[i], i),
                ),
                if (isRefreshing)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: FeedPalette.primaryGreen,
                        strokeWidth: 2.2,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );

        final core = Container(
          color: Colors.white,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: desktop ? (width >= 900 ? 780 : 620) : double.infinity,
              ),
              child: feed,
            ),
          ),
        );

        Widget? sidePanel;
        if (_showCreateEditor) {
          final editing = _editingPost;
          if (editing == null) {
            sidePanel = CreateContentScreen(
              initialType: CreateContentType.post,
              sportName: widget.sportName,
              postDestination: CreatePostDestination.community,
              allowReels: false,
              embedded: true,
              onClose: () => _closeCreateEditor(),
              onPostSaved: () => _fetchPosts(),
            );
          } else {
            final rawBody = _safeStr(editing['rawBody']);
            sidePanel = CreatePostEditorScreen(
              sportName: widget.sportName,
              isEdit: true,
              postId: _safeInt(editing['id']),
              initialTitle: _safeStr(editing['title']),
              initialCoverUrl: _safeStr(editing['coverUrl']),
              initialBlocks: PostHtmlParser.htmlToBlocks(rawBody),
              embedded: true,
              onClose: () => _closeCreateEditor(),
              onSaved: () => _closeCreateEditor(refresh: true),
            );
          }
        } else if (_openedPost != null) {
          final openedPost = _openedPost!;
          sidePanel = NewsDetailScreen(
            key: ValueKey(
              'community-detail-${_safeInt(openedPost['id'])}',
            ),
            title: _safeStr(openedPost['title']).isNotEmpty
                ? _safeStr(openedPost['title'])
                : widget.sportName,
            body: _safeStr(openedPost['text']),
            newsId: _safeInt(openedPost['id']),
            imageUrl: _safeStr(openedPost['imageUrl']),
            focusCommentOnOpen: _openedPostFocusComment,
            embedded: true,
            onClose: _closeOpenedPost,
          );
        }

        final workspaceBody = supportsSidePanel
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: core),
                  if (sidePanel != null) ...[
                    Container(width: .7, color: FeedPalette.border),
                    SizedBox(
                      width: width >= 1400
                          ? 560
                          : width >= 1180
                              ? 520
                              : width >= 900
                                  ? 480
                                  : (width * .58).clamp(390.0, 460.0),
                      child: ClipRect(child: sidePanel),
                    ),
                  ] else if (desktop) ...[
                    Container(width: .7, color: FeedPalette.border),
                    SizedBox(
                      width: width >= 1240 ? 340 : width >= 900 ? 300 : 260,
                      child: _buildDesktopInsightsRail(),
                    ),
                  ],
                ],
              )
            : (sidePanel ?? core);

        final workspace = Container(
          color: Colors.white,
          child: workspaceBody,
        );

        if (widget.embedded) {
          // На телефоне Community открывается внутри оболочки профиля, где
          // внешняя AppBar скрыта. Поэтому верхний safe-area должен учитывать
          // сам embedded-экран, иначе поиск и кнопка создания попадают под
          // status bar / Dynamic Island и часть зоны нажатия блокируется.
          if (mobile) {
            return SafeArea(
              top: true,
              bottom: false,
              child: workspace,
            );
          }
          return workspace;
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            titleSpacing: 14,
            title: Text('Соцлента и новости', style: _title(15.5)),
            actions: [
              if (!mobile)
                IconButton(
                  tooltip: 'Создать',
                  onPressed: _openCreateEditor,
                  icon: const Icon(
                    Icons.add_rounded,
                    color: FeedPalette.primaryGreen,
                  ),
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: workspace,
        );
      },
    );
  }


  Widget _buildDesktopInsightsRail() {
    final latest = posts.take(4).toList(growable: false);

    Widget sectionTitle(String title, IconData icon) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: FeedPalette.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: _title(12.6, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    Widget quickAction({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: FeedPalette.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: FeedPalette.primaryGreen),
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
                        style: _title(11.6, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(9.8),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF98A2B3),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget latestPostTile(Map<String, dynamic> post) {
      final title = _safeStr(post['title']).trim();
      final body = _safeStr(post['text']).trim();
      final label = title.isNotEmpty ? title : body;
      final image = _safeStr(post['imageUrl']).trim();
      final author = _safeStr(post['authorName']).trim();

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPost(post, focusComment: false),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 46,
                    height: 46,
                    color: FeedPalette.greenSoft,
                    child: image.isNotEmpty
                        ? Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.article_outlined,
                              color: FeedPalette.primaryGreen,
                              size: 20,
                            ),
                          )
                        : const Icon(
                            Icons.article_outlined,
                            color: FeedPalette.primaryGreen,
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.isEmpty ? 'Публикация сообщества' : label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _title(10.8, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _statusDot(
                            color: _postAccent(post),
                            size: 4.5,
                            glow: false,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              author.isEmpty ? widget.sportName : author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _text(9.4),
                            ),
                          ),
                        ],
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

    return Container(
      color: const Color(0xFFFCFDFC),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 100),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FeedPalette.greenSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: FeedPalette.primaryGreen,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Обзор сообщества',
                        style: _title(12.4, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${posts.length} публикаций · ${widget.sportName}',
                        style: _text(9.9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          sectionTitle('Быстрые действия', Icons.bolt_rounded),
          quickAction(
            icon: Icons.add_box_outlined,
            title: 'Создать публикацию',
            subtitle: 'Фото, текст или видео',
            onTap: _openCreateEditor,
          ),
          quickAction(
            icon: Icons.refresh_rounded,
            title: 'Обновить ленту',
            subtitle: 'Загрузить новые записи',
            onTap: _fetchPosts,
          ),
          const SizedBox(height: 8),
          sectionTitle('Последние публикации', Icons.schedule_rounded),
          if (latest.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FeedPalette.border),
              ),
              child: Text(
                'Публикаций пока нет',
                style: _text(10.5),
              ),
            )
          else
            ...latest.map(latestPostTile),
          const SizedBox(height: 8),
          sectionTitle('SPORTOTEKA', Icons.shield_outlined),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FeedPalette.border),
            ),
            child: Text(
              'Новости игроков, тренеров и клубов в одной спортивной ленте.',
              style: _text(10.2, color: const Color(0xFF667085)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopRail() {
    Widget item(IconData icon, String title, String subtitle, {bool active = false, VoidCallback? onTap}) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: active ? FeedPalette.greenSoft : Colors.transparent,
              border: Border(left: BorderSide(color: active ? FeedPalette.primaryGreen : Colors.transparent, width: 3)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: active ? FeedPalette.primaryGreenDark : FeedPalette.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _title(12.2, weight: active ? FontWeight.w600 : FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _text(10.2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('СООБЩЕСТВО', style: _text(9.2, weight: FontWeight.w600, color: const Color(0xFF8A9099))),
                const SizedBox(height: 5),
                Text(widget.sportName, style: _title(16)),
                const SizedBox(height: 3),
                Text('${posts.length} публикаций', style: _text(10.5)),
              ],
            ),
          ),
          item(Icons.dynamic_feed_rounded, 'Общая лента', 'публикации и новости', active: true),
          item(Icons.add_box_outlined, 'Создать', 'фото, текст или видео', onTap: _openCreateEditor),
          item(Icons.refresh_rounded, 'Обновить', 'загрузить новые записи', onTap: _fetchPosts),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text('SPORTOTEKA', style: _text(9.5, weight: FontWeight.w600, color: const Color(0xFF98A2B3))),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedControls({
    required bool mobile,
    required int resultCount,
  }) {
    final hasQuery = _searchQuery.trim().isNotEmpty;

    Widget filterButton({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Material(
        color: selected ? FeedPalette.graphite : FeedPalette.soft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              label,
              style: _text(
                10.4,
                weight: FontWeight.w600,
                color: selected ? Colors.white : FeedPalette.text,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 10 : 12,
        mobile ? 8 : 10,
        mobile ? 10 : 12,
        mobile ? 8 : 10,
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _setSearch,
                  textInputAction: TextInputAction.search,
                  style: _text(12.2, color: FeedPalette.text),
                  decoration: InputDecoration(
                    hintText: 'Поиск публикаций и #хэштегов',
                    hintStyle:
                        _text(11.5, color: const Color(0xFF98A2B3)),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: FeedPalette.secondary,
                    ),
                    suffixIcon: hasQuery
                        ? IconButton(
                            tooltip: 'Очистить поиск',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close_rounded, size: 18),
                          )
                        : null,
                    filled: true,
                    fillColor: FeedPalette.soft,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: FeedPalette.greenBorder,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              if (_currentUserId > 0) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Создать',
                  child: IconButton(
                    onPressed: _openCreateEditor,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Container(
                      width: 25,
                      height: 25,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: FeedPalette.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              filterButton(
                label: 'Все',
                selected: !_onlyMine,
                onTap: () => setState(() => _onlyMine = false),
              ),
              const SizedBox(width: 7),
              filterButton(
                label: 'Мои',
                selected: _onlyMine,
                onTap: () => setState(() => _onlyMine = true),
              ),
              const Spacer(),
              Text(
                '$resultCount',
                style: _text(
                  10.2,
                  weight: FontWeight.w600,
                  color: FeedPalette.textMuted,
                ),
              ),
            ],
          ),
          if (hasQuery && _searchQuery.trim().startsWith('#')) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.tag_rounded,
                  size: 15,
                  color: FeedPalette.primaryGreenDark,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Публикации по ${_searchQuery.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(
                      10.2,
                      weight: FontWeight.w600,
                      color: FeedPalette.primaryGreenDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyFeedState() {
    final hasQuery = _searchQuery.trim().isNotEmpty;
    final title = hasQuery
        ? 'Ничего не найдено'
        : _onlyMine
            ? 'У вас пока нет публикаций'
            : 'Пока нет публикаций';
    final subtitle = hasQuery
        ? 'Попробуйте другой текст или нажмите на хэштег в публикации.'
        : _onlyMine
            ? 'Создайте свой первый пост — он появится здесь и в общей ленте.'
            : 'Создайте первый пост — он появится в общей ленте.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: _whiteCard(
        child: Column(
          children: [
            Icon(
              hasQuery ? Icons.search_off_rounded : Icons.dynamic_feed_outlined,
              size: 32,
              color: FeedPalette.secondary,
            ),
            const SizedBox(height: 10),
            Text(title, style: _title(14.5)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: _text(11.8),
            ),
            if (!hasQuery && _currentUserId > 0) ...[
              const SizedBox(height: 12),
              _buildCreateButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPostHashtags(Map<String, dynamic> post) {
    final tags = _hashtagsForPost(post);
    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Wrap(
        spacing: 7,
        runSpacing: 6,
        children: [
          for (final tag in tags.take(6))
            InkWell(
              onTap: () => _activateHashtag(tag),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  tag,
                  style: _text(
                    11.6,
                    weight: FontWeight.w600,
                    color: FeedPalette.primaryGreenDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOwnPostMenu(Map<String, dynamic> post) {
    if (_safeInt(post['user_id']) != _currentUserId || _currentUserId <= 0) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'Действия с публикацией',
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 21,
        color: FeedPalette.text,
      ),
      onSelected: (value) {
        if (value == 'edit') _openEditEditor(post);
        if (value == 'delete') _deleteOwnPost(post);
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 9),
              Text('Редактировать'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              SizedBox(width: 9),
              Text('Удалить', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return FilledButton.icon(
      onPressed: _openCreateEditor,
      style: FilledButton.styleFrom(
        backgroundColor: FeedPalette.graphite,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.add_rounded, size: 17),
      label: Text('Создать', style: _text(11.5, weight: FontWeight.w600, color: Colors.white)),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: FeedPalette.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _brandDots(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Соцлента и новости', style: _title(13.6)),
                const SizedBox(height: 2),
                Text(
                  'Публикации игроков, тренеров и клубов',
                  style: _text(10.2),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${posts.length}', style: _title(10.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePostCard() {
    return Material(
      color: FeedPalette.greenSoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _openCreateEditor,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _brandDots(color: FeedPalette.primaryGreenDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Добавить публикацию, фото или видео…',
                  style: _text(
                    11.2,
                    weight: FontWeight.w500,
                    color: FeedPalette.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: FeedPalette.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Создать',
                  style: _text(
                    10.2,
                    weight: FontWeight.w600,
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

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final author = (post['authorName'] ?? 'Пользователь').toString();
    final userId = _safeInt(post['user_id']);
    final title = _safeStr(post['title']);
    final text = _safeStr(post['text']);
    final img = _safeStr(post['imageUrl']);
    final avatar = _safeStr(post['authorAvatar']);
    final hasVideo = post['hasVideo'] == true;
    final videoUrl = _safeStr(post['videoUrl']);

    final likes = _safeInt(post['likes']);
    final comments = _safeInt(post['comments']);
    final liked = post['liked'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (hasVideo && videoUrl.isNotEmpty) {
            _openVideoInsideApp(
              title: title,
              url: videoUrl,
              thumbnail: img,
            );
            return;
          }

          _openPost(post, focusComment: false);
        },
        child: _whiteCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: InkWell(
                  onTap: () {
                    if (userId <= 0) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyProfileScreen(userId: userId, publicView: true),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      _AvatarCircle(radius: 18, name: author, url: avatar),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              author,
                              style: _title(14, weight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatPostDate(post['date']),
                              style: _text(11.2, weight: FontWeight.w400),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: FeedPalette.greenSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _statusDot(
                                  color: _postAccent(post),
                                  size: 4.5,
                                  glow: false,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.sportName,
                                  style: _text(
                                    9.6,
                                    weight: FontWeight.w600,
                                    color: FeedPalette.primaryGreenDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_safeInt(post['user_id']) == _currentUserId) ...[
                            const SizedBox(width: 2),
                            _buildOwnPostMenu(post),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (title.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _statusDot(
                          color: _postAccent(post),
                          size: 6,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _title(16.2, weight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              if (text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Text(
                    text,
                    style: _text(13.2, weight: FontWeight.w400, color: FeedPalette.text),
                    maxLines: img.isEmpty ? 6 : 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              _buildPostHashtags(post),
              if (img.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: FeedPalette.soft),
                        Image.network(
                          img,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          loadingBuilder: (c, child, p) {
                            if (p == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: FeedPalette.primaryGreen,
                              ),
                            );
                          },
                        ),
                        if (hasVideo) ...[
                          Container(color: Colors.black.withOpacity(0.18)),
                          const Center(
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.play_arrow,
                                color: FeedPalette.primaryGreen,
                                size: 32,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 2),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: liked ? 'Убрать отметку' : 'Нравится',
                      onPressed: () => _toggleLike(_safeInt(post['id'])),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          key: ValueKey(liked),
                          size: 24,
                          color: liked ? const Color(0xFFE53935) : FeedPalette.text,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Комментарий',
                      onPressed: () => _openPost(post, focusComment: true),
                      icon: const Icon(
                        Icons.mode_comment_outlined,
                        size: 23,
                        color: FeedPalette.text,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Открыть публикацию',
                      onPressed: () => _openPost(post, focusComment: false),
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        size: 21,
                        color: FeedPalette.text,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _postKind(post),
                      style: _text(
                        9.8,
                        weight: FontWeight.w500,
                        color: FeedPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (likes > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    '$likes ${likes == 1 ? 'отметка' : 'отметок'}',
                    style: _text(
                      11.2,
                      weight: FontWeight.w600,
                      color: FeedPalette.text,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: InkWell(
                  onTap: () => _openPost(post, focusComment: true),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      comments > 0
                          ? 'Посмотреть все комментарии ($comments)'
                          : 'Добавить комментарий…',
                      style: _text(
                        11.6,
                        weight: FontWeight.w500,
                        color: const Color(0xFF8A9099),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whiteCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FeedPalette.white,
        borderRadius: BorderRadius.circular(14),
              ),
      child: child,
    );
  }

  Widget _buildSkeletonPost() {
    Widget bar({double w = 120, double h = 10}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(999),
          ),
        );

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(w: 140),
                  const SizedBox(height: 8),
                  bar(w: 90, h: 9),
                ],
              ),
              const Spacer(),
              bar(w: 70, h: 24),
            ],
          ),
          const SizedBox(height: 12),
          bar(w: double.infinity, h: 10),
          const SizedBox(height: 8),
          bar(w: double.infinity, h: 10),
          const SizedBox(height: 8),
          bar(w: 220, h: 10),
          const SizedBox(height: 12),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final double radius;
  final String name;
  final String url;

  const _AvatarCircle({
    required this.radius,
    required this.name,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isNotEmpty ? name.trim().characters.first.toUpperCase() : 'П';
    final hasUrl = url.trim().isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: FeedPalette.lightGreen,
      backgroundImage: hasUrl ? NetworkImage(url) : null,
      onBackgroundImageError: hasUrl ? (_, __) {} : null,
      child: hasUrl
          ? null
          : Text(
              initial,
              style: AppTypography.captionMedium(
                color: FeedPalette.primaryGreen,
              ),
            ),
    );
  }
}