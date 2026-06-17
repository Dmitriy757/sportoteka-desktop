import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';
import 'package:sportoteka/presentation/community_screen/app_video_player_screen.dart';
import 'package:sportoteka/presentation/community_screen/in_app_web_video_screen.dart';
import 'package:sportoteka/presentation/community_screen/news_detail_screen.dart';
import 'package:sportoteka/presentation/community_screen/create_post_editor_screen.dart';
import 'package:sportoteka/presentation/community_screen/post_blocks.dart';

class FeedPalette {
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

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class SportCommunityScreen extends StatefulWidget {
  final String sportName;
  const SportCommunityScreen({super.key, required this.sportName});

  @override
  State<SportCommunityScreen> createState() => _SportCommunityScreenState();
}

class _SportCommunityScreenState extends State<SportCommunityScreen> {
  static const _apiBase = "https://sportotekaapp.ru/api";

  List<Map<String, dynamic>> posts = [];
  bool isLoading = false;
  bool isRefreshing = false;

  int _currentUserId = 0;

  @override
  void initState() {
    super.initState();
    _init();
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
          previewImage = autoThumb!;
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

        final filtered = data.where(
          (raw) =>
              (raw['category'] ?? '').toString().toLowerCase() ==
              widget.sportName.toLowerCase(),
        );

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
    final ok = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostEditorScreen(
          sportName: widget.sportName,
          isEdit: false,
        ),
      ),
    );

    if (ok == true) {
      await _fetchPosts();
    }
  }

  Future<void> _toggleLike(int postId, int index) async {
    if (_currentUserId <= 0) {
      _showError("Нужно войти в аккаунт");
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FeedPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: FeedPalette.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          widget.sportName,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: FeedPalette.text,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Новый пост",
            onPressed: _openCreateEditor,
            icon: Container(
              decoration: BoxDecoration(
                gradient: FeedPalette.greenGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPosts,
        color: FeedPalette.primaryGreen,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 12),
            _buildCreatePostCard(),
            const SizedBox(height: 12),
            if (isLoading && posts.isEmpty) ...[
              _buildSkeletonPost(),
              const SizedBox(height: 10),
              _buildSkeletonPost(),
              const SizedBox(height: 10),
              _buildSkeletonPost(),
            ] else if (posts.isEmpty) ...[
              _whiteCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.forum_outlined,
                      size: 34,
                      color: FeedPalette.textMuted,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Пока нет постов",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: FeedPalette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Создайте первый пост — он появится в ленте.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: FeedPalette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: FeedPalette.greenGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextButton.icon(
                        onPressed: _openCreateEditor,
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          "Создать пост",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...List.generate(posts.length, (i) => _buildPostCard(posts[i], i)),
              const SizedBox(height: 8),
              if (isRefreshing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: CircularProgressIndicator(
                      color: FeedPalette.primaryGreen,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FeedPalette.primaryGreen.withOpacity(0.12),
            FeedPalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FeedPalette.border),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: FeedPalette.greenGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(10),
            child: const Icon(Icons.public, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Спортивное сообщество",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  "Обсуждения, новости, фото и реакции",
                  style: TextStyle(
                    color: FeedPalette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: FeedPalette.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FeedPalette.border),
            ),
            child: Text(
              "${posts.length} постов",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: FeedPalette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePostCard() {
    return InkWell(
      onTap: _openCreateEditor,
      borderRadius: BorderRadius.circular(18),
      child: _whiteCard(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: FeedPalette.greenGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Что у вас нового?",
                style: TextStyle(
                  color: FeedPalette.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: FeedPalette.superLightGreen,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: FeedPalette.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: const Text(
                "Создать",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: FeedPalette.primaryGreen,
                ),
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(18),
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
                        builder: (_) => MyProfileScreen(userId: userId),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatPostDate(post['date']),
                              style: const TextStyle(
                                color: FeedPalette.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: FeedPalette.greenGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.sportName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
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
                      Container(
                        width: 4,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: FeedPalette.greenGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                            color: FeedPalette.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: FeedPalette.text,
                    ),
                    maxLines: img.isEmpty ? 5 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (img.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
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
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _toggleLike(_safeInt(post['id']), index),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: FeedPalette.background,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: FeedPalette.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Icon(
                                liked ? Icons.favorite : Icons.favorite_border,
                                key: ValueKey(liked),
                                size: 18,
                                color: liked
                                    ? Colors.redAccent
                                    : FeedPalette.textMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              likes.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: FeedPalette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => _openPost(post, focusComment: true),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: FeedPalette.background,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: FeedPalette.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.comment_outlined,
                              size: 18,
                              color: FeedPalette.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              comments.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: FeedPalette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _openPost(post, focusComment: false),
                      style: TextButton.styleFrom(
                        foregroundColor: FeedPalette.primaryGreen,
                      ),
                      child: const Text(
                        "Подробнее",
                        style: TextStyle(fontWeight: FontWeight.w900),
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

  Widget _whiteCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FeedPalette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FeedPalette.border),
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
              style: const TextStyle(
                color: FeedPalette.primaryGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}