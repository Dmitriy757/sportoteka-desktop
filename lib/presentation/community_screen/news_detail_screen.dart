import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/community_screen/app_video_player_screen.dart';
import 'package:sportoteka/presentation/community_screen/create_post_editor_screen.dart';
import 'package:sportoteka/presentation/community_screen/in_app_web_video_screen.dart';
import 'package:sportoteka/presentation/community_screen/post_blocks.dart';

class NewsPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const lightGreen = Color(0xFFE8F5E9);

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

enum _CommentSort { best, newest, oldest }

class NewsDetailScreen extends StatefulWidget {
  final String title;
  final String body;
  final int newsId;
  final String imageUrl;
  final bool focusCommentOnOpen;

  const NewsDetailScreen({
    super.key,
    required this.title,
    required this.body,
    required this.newsId,
    required this.imageUrl,
    this.focusCommentOnOpen = false,
  });

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  static const _apiBase = "https://sportotekaapp.ru/api";

  bool _postLoading = false;
  Map<String, dynamic>? _post;
  int _postOwnerId = 0;

  String get _postTitle => (_post?["title"] ?? widget.title).toString();

  String get _postCover =>
      _fixUrl((_post?["image"] ?? _post?["image_url"] ?? widget.imageUrl).toString());

  String get _postBodyRaw => (_post?["body"] ?? widget.body).toString();

  List<Map<String, dynamic>> _flatComments = [];
  final Map<int, Map<String, dynamic>> _byId = {};
  List<_CNode> _tree = [];

  int _currentUserId = 0;

  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocus = FocusNode();

  bool _isLoading = false;
  bool _isSending = false;

  _CommentSort _sort = _CommentSort.best;

  String? _selectedGifUrl;
  String? _selectedGifPreview;
  File? _selectedImageFile;

  int? _replyToCommentId;
  String? _replyToUserLabel;
  String? _replyQuote;

  int? _editingCommentId;

  final Set<int> _collapsed = <int>{};

  @override
  void initState() {
    super.initState();
    _initUserAndLoad();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.focusCommentOnOpen) {
        _commentFocus.requestFocus();
        _scrollToComposer();
      }
    });
  }

  Future<void> _initUserAndLoad() async {
    final uid = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;
    setState(() => _currentUserId = uid);

    await _fetchPost();
    await _fetchCommentsTree();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _snack(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  int _asInt(dynamic v) =>
      v is int ? v : int.tryParse((v ?? "").toString()) ?? 0;

  DateTime _asDate(dynamic v) {
    final s = (v ?? "").toString();
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _scrollToComposer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 340,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _safeName(Map<String, dynamic> c) {
    final fn = (c['first_name'] ?? '').toString().trim();
    final ln = (c['last_name'] ?? '').toString().trim();
    final full = ('$fn $ln').trim();
    final uname = (c['user_name'] ?? '').toString().trim();
    if (full.isNotEmpty) return full;
    if (uname.isNotEmpty) return uname;
    return 'Пользователь';
  }

  String _safeInitial(Map<String, dynamic> c) {
    final name = _safeName(c);
    return name.isNotEmpty ? name.characters.first.toUpperCase() : 'П';
  }

  String _formatDateTime(dynamic v) {
    final dt = _asDate(v);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _buildQuote(Map<String, dynamic> c) {
    final text = (c["comment"] ?? "").toString().trim();
    final gif = (c["gif_url"] ?? "").toString().trim();
    final img = (c["image_url"] ?? "").toString().trim();

    if (text.isNotEmpty && text != "Комментарий удалён") {
      return text.length > 80 ? "${text.substring(0, 80)}…" : text;
    }
    if (img.isNotEmpty) return "[Фото]";
    if (gif.isNotEmpty) return "[GIF]";
    return "…";
  }

  int _countAll(List<_CNode> nodes) {
    int n = 0;

    void walk(List<_CNode> xs) {
      for (final x in xs) {
        n++;
        walk(x.children);
      }
    }

    walk(nodes);
    return n;
  }

  int _countDesc(_CNode n) {
    int c = 0;

    void w(_CNode x) {
      for (final ch in x.children) {
        c++;
        w(ch);
      }
    }

    w(n);
    return c;
  }

  String _fixUrl(String s) {
    final u = s.trim();
    if (u.isEmpty) return "";
    if (u.startsWith("http://") || u.startsWith("https://")) return u;
    return "https://sportotekaapp.ru/$u";
  }

  bool _looksLikeHtml(String s) {
    final t = s.trim().toLowerCase();
    return t.contains("<p") ||
        t.contains("<br") ||
        t.contains("<img") ||
        t.contains("<div") ||
        t.contains("<video") ||
        t.contains("<a ");
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

  String _textToHtml(String txt) {
    final esc = const HtmlEscape();
    final safe = esc.convert(txt).replaceAll('\n', '<br/>');
    return '<p>$safe</p>';
  }

  List<PostBlock> _postBlocks() {
    final raw = _postBodyRaw;
    final html = _looksLikeHtml(raw) ? raw : _textToHtml(raw);
    final blocks = PostHtmlParser.htmlToBlocks(html);

    final normalized = <PostBlock>[];
    final videoUrls = <String>{};
    final addedLinks = <String>{};
    final addedImages = <String>{};

    for (final b in blocks) {
      if (b is ImageBlock) {
        final u = _fixUrl(b.url).trim();
        if (u.isNotEmpty && !addedImages.contains(u)) {
          normalized.add(ImageBlock(u));
          addedImages.add(u);
        }
        continue;
      }

      if (b is TextBlock) {
        final t = b.text.trim();
        if (t.isNotEmpty) {
          normalized.add(TextBlock(t));
        }
        continue;
      }

      if (b is VideoBlock) {
        final u = _fixUrl(b.url).trim();
        String thumb = b.thumbnail.trim().isEmpty ? "" : _fixUrl(b.thumbnail).trim();

        if (thumb.isEmpty) {
          thumb = _tryBuildAutoThumbnail(u) ?? "";
        }

        if (u.isNotEmpty && !videoUrls.contains(u)) {
          normalized.add(
            VideoBlock(
              url: u,
              title: b.title.trim(),
              thumbnail: thumb,
            ),
          );
          videoUrls.add(u);
        }
        continue;
      }

      if (b is LinkBlock) {
        final u = _fixUrl(b.url).trim();

        if (u.isEmpty || videoUrls.contains(u) || addedLinks.contains(u)) {
          continue;
        }

        if (_looksLikeDirectVideoUrl(u) || _looksLikeExternalVideoPage(u)) {
          normalized.add(
            VideoBlock(
              url: u,
              title: b.title.trim(),
              thumbnail: _tryBuildAutoThumbnail(u) ?? "",
            ),
          );
          videoUrls.add(u);
          continue;
        }

        normalized.add(
          LinkBlock(
            url: u,
            title: b.title,
          ),
        );
        addedLinks.add(u);
      }
    }

    return normalized;
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _snack("Некорректная ссылка");
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _snack("Не удалось открыть ссылку");
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

  bool get _canEditPost =>
      _currentUserId > 0 && _postOwnerId > 0 && _postOwnerId == _currentUserId;

  Future<void> _fetchPost() async {
    setState(() => _postLoading = true);
    try {
      final uri = Uri.parse(
        "$_apiBase/get_post.php?post_id=${widget.newsId}&user_id=$_currentUserId",
      );
      final r = await http.get(uri);
      if (r.statusCode != 200) return;

      final j = json.decode(r.body);
      if (j is Map && (j["success"] == true) && j["post"] is Map) {
        final p = Map<String, dynamic>.from(j["post"] as Map);
        _post = p;
        _postOwnerId = _asInt(p["user_id"]);
        if (mounted) setState(() {});
      }
    } catch (_) {
      //
    } finally {
      if (mounted) setState(() => _postLoading = false);
    }
  }

  Future<void> _openEditPost() async {
    final blocks = _postBlocks();

    final ok = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostEditorScreen(
          sportName: widget.title,
          isEdit: true,
          postId: widget.newsId,
          initialTitle: _postTitle,
          initialCoverUrl: _postCover,
          initialBlocks: blocks,
        ),
      ),
    );

    if (ok == true) {
      await _fetchPost();
      if (mounted) setState(() {});
    }
  }

  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Удалить пост?"),
        content: const Text("Пост будет удалён. Это действие нельзя отменить."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Удалить", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final r = await http.post(
        Uri.parse("$_apiBase/delete_post.php"),
        body: {
          "post_id": widget.newsId.toString(),
          "user_id": _currentUserId.toString(),
        },
      );

      if (r.statusCode != 200) {
        _snack("Ошибка удаления: HTTP ${r.statusCode}");
        return;
      }

      final j = json.decode(r.body);
      final success =
          (j is Map) && (j["success"] == true || j["status"] == "ok");
      if (!success) {
        _snack("Ошибка удаления: ${r.body}");
        return;
      }

      if (!mounted) return;
      Navigator.pop(context, {"deleted": true});
    } catch (e) {
      _snack("Ошибка удаления: $e");
    }
  }

  Future<void> _fetchCommentsTree() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(
        "$_apiBase/get_comments_tree.php?post_id=${widget.newsId}&user_id=$_currentUserId",
      );
      final r = await http.get(uri);
      if (r.statusCode != 200) {
        _snack("Ошибка загрузки: HTTP ${r.statusCode}");
        return;
      }

      final j = json.decode(r.body);
      if (j is! Map || j["success"] != true) {
        _snack(
          "Ошибка загрузки: ${(j is Map ? (j["message"] ?? "Ошибка") : "Ошибка")}",
        );
        return;
      }

      final items = (j["items"] is List) ? (j["items"] as List) : <dynamic>[];
      final parsed = <Map<String, dynamic>>[];

      for (final it in items) {
        if (it is Map) parsed.add(Map<String, dynamic>.from(it));
      }

      _flatComments = parsed;
      _byId
        ..clear()
        ..addEntries(
          parsed
              .map((m) => MapEntry(_asInt(m["id"]), m))
              .where((e) => e.key > 0),
        );

      _tree = _buildTree(_flatComments, sort: _sort);

      if (mounted) setState(() {});
    } catch (e) {
      _snack("Ошибка загрузки: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_CNode> _buildTree(
    List<Map<String, dynamic>> flat, {
    required _CommentSort sort,
  }) {
    final byId = <int, _CNode>{};
    final roots = <_CNode>[];

    for (final c in flat) {
      final id = _asInt(c["id"]);
      if (id <= 0) continue;
      byId[id] = _CNode(id: id, data: c);
    }

    for (final node in byId.values) {
      final pid = _asInt(node.data["parent_id"]);
      if (pid > 0 && byId.containsKey(pid)) {
        byId[pid]!.children.add(node);
      } else {
        roots.add(node);
      }
    }

    int score(_CNode n) => _asInt(n.data["score"]);
    DateTime created(_CNode n) => _asDate(n.data["created_at"]);

    int cmp(_CNode a, _CNode b) {
      switch (sort) {
        case _CommentSort.best:
          final s = score(b).compareTo(score(a));
          if (s != 0) return s;
          return created(a).compareTo(created(b));
        case _CommentSort.newest:
          return created(b).compareTo(created(a));
        case _CommentSort.oldest:
          return created(a).compareTo(created(b));
      }
    }

    void sortRec(List<_CNode> list) {
      list.sort(cmp);
      for (final n in list) {
        sortRec(n.children);
      }
    }

    sortRec(roots);
    return roots;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _selectedImageFile = File(x.path));
  }

  void _clearComposer() {
    _commentController.clear();
    _selectedGifUrl = null;
    _selectedGifPreview = null;
    _selectedImageFile = null;
    _replyToCommentId = null;
    _replyToUserLabel = null;
    _replyQuote = null;
    _editingCommentId = null;
  }

  void _startReply(_CNode node) {
    final name = _safeName(node.data);
    setState(() {
      _replyToCommentId = node.id;
      _replyToUserLabel = name;
      _replyQuote = _buildQuote(node.data);
      _editingCommentId = null;
    });

    _commentFocus.requestFocus();
    _scrollToComposer();
  }

  void _startEdit(_CNode node) {
    final txt = (node.data["comment"] ?? "").toString();
    final gif = (node.data["gif_url"] ?? "").toString().trim();

    setState(() {
      _editingCommentId = node.id;

      _replyToCommentId = null;
      _replyToUserLabel = null;
      _replyQuote = null;

      _commentController.text = txt == "Комментарий удалён" ? "" : txt;

      _selectedGifUrl = gif.isNotEmpty ? gif : null;
      _selectedGifPreview = gif.isNotEmpty ? gif : null;

      _selectedImageFile = null;
    });

    _commentFocus.requestFocus();
    _scrollToComposer();
  }

  Future<void> _openGifPicker() async {
    final picked = await showModalBottomSheet<_GifPickResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _GifPickerSheet(),
    );

    if (!mounted || picked == null) return;

    setState(() {
      _selectedGifUrl = picked.url;
      _selectedGifPreview = picked.preview;
    });
  }

  Future<void> _send() async {
    if (_currentUserId <= 0) {
      _snack("Не найден пользователь. Войдите заново.");
      return;
    }

    final text = _commentController.text.trim();
    final hasText = text.isNotEmpty;
    final hasGif = (_selectedGifUrl ?? "").trim().isNotEmpty;
    final hasImg = _selectedImageFile != null;

    if (!hasText && !hasGif && !hasImg) return;
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      if (_editingCommentId != null) {
        final r = await http.post(
          Uri.parse("$_apiBase/update_comment.php"),
          body: {
            "comment_id": _editingCommentId.toString(),
            "user_id": _currentUserId.toString(),
            "comment": text,
            "gif_url": _selectedGifUrl ?? "",
          },
        );

        if (r.statusCode != 200) {
          _snack("Ошибка редактирования: HTTP ${r.statusCode}");
          return;
        }

        final j = json.decode(r.body);
        if (j is! Map || j["success"] != true) {
          _snack(
            "Ошибка редактирования: ${(j is Map ? (j["message"] ?? "Ошибка") : "Ошибка")}",
          );
          return;
        }

        final idx = _flatComments.indexWhere(
          (x) => _asInt(x["id"]) == _editingCommentId,
        );

        if (idx >= 0) {
          _flatComments[idx] = {
            ..._flatComments[idx],
            "comment": text,
            "gif_url": _selectedGifUrl ?? "",
            "edited_at": DateTime.now().toIso8601String(),
          };
          _byId[_editingCommentId!] = _flatComments[idx];
          _tree = _buildTree(_flatComments, sort: _sort);
        }

        if (mounted) setState(() {});
        _clearComposer();
        FocusScope.of(context).unfocus();
        return;
      }

      final req =
          http.MultipartRequest("POST", Uri.parse("$_apiBase/add_comment.php"));
      req.fields["post_id"] = widget.newsId.toString();
      req.fields["user_id"] = _currentUserId.toString();
      req.fields["comment"] = text;
      req.fields["gif_url"] = _selectedGifUrl ?? "";

      if (_replyToCommentId != null) {
        req.fields["parent_id"] = _replyToCommentId.toString();
      }

      if (_selectedImageFile != null) {
        req.files.add(
          await http.MultipartFile.fromPath("image", _selectedImageFile!.path),
        );
      }

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        _snack("Ошибка отправки: HTTP ${streamed.statusCode}");
        return;
      }

      final j = json.decode(body);
      if (j is! Map || j["success"] != true || j["comment"] is! Map) {
        _snack(
          "Ошибка отправки: ${(j is Map ? (j["message"] ?? "Ошибка") : "Ошибка")}",
        );
        return;
      }

      final newComment = Map<String, dynamic>.from(j["comment"] as Map);

      _flatComments.add(newComment);
      _byId[_asInt(newComment["id"])] = newComment;
      _tree = _buildTree(_flatComments, sort: _sort);

      if (mounted) setState(() {});
      _clearComposer();
      FocusScope.of(context).unfocus();
    } catch (e) {
      _snack("Ошибка: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(_CNode node) async {
    if (_currentUserId <= 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Удалить комментарий?"),
        content: const Text("Удалить можно только свой комментарий."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Удалить", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final r = await http.post(
        Uri.parse("$_apiBase/delete_comment.php"),
        body: {
          "comment_id": node.id.toString(),
          "user_id": _currentUserId.toString(),
        },
      );

      if (r.statusCode != 200) {
        _snack("Ошибка удаления: HTTP ${r.statusCode}");
        return;
      }

      final j = json.decode(r.body);
      if (j is! Map || j["success"] != true) {
        _snack(
          "Ошибка удаления: ${(j is Map ? (j["message"] ?? "Ошибка") : "Ошибка")}",
        );
        return;
      }

      final idx = _flatComments.indexWhere((x) => _asInt(x["id"]) == node.id);
      if (idx >= 0) {
        _flatComments[idx] = {
          ..._flatComments[idx],
          "comment": "Комментарий удалён",
          "gif_url": "",
          "image_url": "",
          "edited_at": DateTime.now().toIso8601String(),
        };
        _byId[node.id] = _flatComments[idx];
        _tree = _buildTree(_flatComments, sort: _sort);
        if (mounted) setState(() {});
      }
    } catch (e) {
      _snack("Ошибка удаления: $e");
    }
  }

  Future<void> _vote(int commentId, int value) async {
    if (_currentUserId <= 0) {
      _snack("Нужно войти в аккаунт");
      return;
    }

    final m = _byId[commentId];
    if (m != null) {
      final my = _asInt(m["my_vote"]);
      final score = _asInt(m["score"]);

      int newMy;
      int newScore;

      if (my == value) {
        newMy = 0;
        newScore = score - value;
      } else if (my == 0) {
        newMy = value;
        newScore = score + value;
      } else {
        newMy = value;
        newScore = score - my + value;
      }

      _byId[commentId] = {...m, "my_vote": newMy, "score": newScore};
      final idx = _flatComments.indexWhere((x) => _asInt(x["id"]) == commentId);
      if (idx >= 0) {
        _flatComments[idx] = _byId[commentId]!;
      }
      _tree = _buildTree(_flatComments, sort: _sort);
      if (mounted) setState(() {});
    }

    try {
      final r = await http.post(
        Uri.parse("$_apiBase/vote_comment.php"),
        body: {
          "comment_id": commentId.toString(),
          "user_id": _currentUserId.toString(),
          "value": value.toString(),
        },
      );

      if (r.statusCode != 200) return;

      final j = json.decode(r.body);
      if (j is! Map || j["success"] != true) return;

      final cid = _asInt(j["comment_id"]);
      final score = _asInt(j["score"]);
      final myVote = _asInt(j["my_vote"]);

      final cur = _byId[cid];
      if (cur != null) {
        _byId[cid] = {...cur, "score": score, "my_vote": myVote};
        final idx = _flatComments.indexWhere((x) => _asInt(x["id"]) == cid);
        if (idx >= 0) {
          _flatComments[idx] = _byId[cid]!;
        }
        _tree = _buildTree(_flatComments, sort: _sort);
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Widget _sortChips() {
    Widget chip(String label, _CommentSort v) {
      final selected = _sort == v;
      return GestureDetector(
        onTap: () {
          setState(() {
            _sort = v;
            _tree = _buildTree(_flatComments, sort: _sort);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected ? NewsPalette.greenGradient : null,
            color: selected ? null : NewsPalette.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: NewsPalette.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : NewsPalette.textMuted,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip("Лучшие", _CommentSort.best),
        chip("Новые", _CommentSort.newest),
        chip("Старые", _CommentSort.oldest),
      ],
    );
  }

  void _openImageFullScreen(String url, String heroTag) {
    final u = _fixUrl(url);
    if (u.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _FullScreenImageViewer(imageUrl: u, heroTag: heroTag),
    );
  }

  Widget _postBlocksView() {
    final blocks = _postBlocks();
    if (blocks.isEmpty) {
      return const Text(
        "Нет текста",
        style: TextStyle(
          color: NewsPalette.textMuted,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final children = <Widget>[];

    for (int i = 0; i < blocks.length; i++) {
      final b = blocks[i];

      if (b is TextBlock) {
        children.add(
          Text(
            b.text,
            style: const TextStyle(
              color: NewsPalette.text,
              fontSize: 15.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        children.add(const SizedBox(height: 12));
        continue;
      }

      if (b is ImageBlock) {
        final url = _fixUrl(b.url);
        final hero = "post_block_img_${widget.newsId}_${i}_${url.hashCode}";

        children.add(
          GestureDetector(
            onTap: () => _openImageFullScreen(url, hero),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Hero(
                tag: hero,
                child: Container(
                  color: Colors.black,
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                      loadingBuilder: (c, child, p) {
                        if (p == null) return child;
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(
                              color: NewsPalette.primaryGreen,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        children.add(const SizedBox(height: 12));
        continue;
      }

      if (b is LinkBlock) {
        children.add(
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openExternalUrl(b.url),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NewsPalette.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NewsPalette.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: NewsPalette.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.link, color: NewsPalette.primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.title.trim().isEmpty ? "Ссылка" : b.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            color: NewsPalette.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b.url,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
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
        children.add(const SizedBox(height: 12));
        continue;
      }

      if (b is VideoBlock) {
        children.add(
          _InlineVideoBlockCard(
            title: b.title.trim(),
            videoUrl: b.url,
            thumbnailUrl: b.thumbnail.trim(),
            onOpenExternal: () => _openExternalUrl(b.url),
            onOpenInside: () => _openVideoInsideApp(
              title: b.title.trim(),
              url: b.url,
              thumbnail: b.thumbnail.trim(),
            ),
          ),
        );
        children.add(const SizedBox(height: 12));
      }
    }

    if (children.isNotEmpty && children.last is SizedBox) {
      children.removeLast();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroNews = 'news_image_${widget.newsId}';
    final totalComments = _countAll(_tree);
    final cover = _postCover;

    return Scaffold(
      backgroundColor: NewsPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: NewsPalette.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          _postTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: NewsPalette.text,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Обновить",
            onPressed: (_isLoading || _postLoading)
                ? null
                : () async {
                    await _fetchPost();
                    await _fetchCommentsTree();
                  },
            icon: const Icon(Icons.refresh),
          ),
          if (_canEditPost)
            PopupMenuButton<String>(
              tooltip: "Действия",
              offset: const Offset(0, 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (v) {
                if (v == "edit") _openEditPost();
                if (v == "delete") _deletePost();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: "edit", child: Text("Редактировать пост")),
                PopupMenuItem(value: "delete", child: Text("Удалить пост")),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.more_vert, color: Colors.grey.shade800),
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cover.isNotEmpty)
                    GestureDetector(
                      onTap: () => _openImageFullScreen(cover, heroNews),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Hero(
                          tag: heroNews,
                          child: Container(
                            width: double.infinity,
                            color: Colors.black,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                cover,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _whiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _postBlocksView(),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: NewsPalette.greenGradient,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Комментарии ($totalComments)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (_postLoading)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: NewsPalette.primaryGreen,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _sortChips(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: NewsPalette.primaryGreen,
                        ),
                      ),
                    )
                  else if (_tree.isEmpty)
                    _whiteCard(
                      child: const Center(
                        child: Text(
                          'Пока нет комментариев. Будьте первым!',
                          style: TextStyle(
                            color: NewsPalette.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    _ThreadList(
                      nodes: _tree,
                      currentUserId: _currentUserId,
                      collapsed: _collapsed,
                      countDesc: _countDesc,
                      byId: _byId,
                      onToggleCollapse: (id) {
                        setState(() {
                          if (_collapsed.contains(id)) {
                            _collapsed.remove(id);
                          } else {
                            _collapsed.add(id);
                          }
                        });
                      },
                      onReply: _startReply,
                      onEdit: _startEdit,
                      onDelete: _deleteComment,
                      onVote: _vote,
                      onOpenImage: _openImageFullScreen,
                      safeName: _safeName,
                      safeInitial: _safeInitial,
                      formatDate: _formatDateTime,
                      quoteFor: (m) => _buildQuote(m),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: 10 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: NewsPalette.white,
              border: Border(top: BorderSide(color: NewsPalette.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyToCommentId != null || _editingCommentId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NewsPalette.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: NewsPalette.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _editingCommentId != null ? Icons.edit : Icons.reply,
                          color: NewsPalette.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _editingCommentId != null
                                    ? "Редактирование"
                                    : "Ответ: ${_replyToUserLabel ?? ""}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_editingCommentId == null &&
                                  (_replyQuote ?? "").isNotEmpty)
                                Text(
                                  _replyQuote!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: NewsPalette.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _replyToCommentId = null;
                            _replyToUserLabel = null;
                            _replyQuote = null;
                            _editingCommentId = null;
                          }),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                if ((_selectedGifPreview ?? '').isNotEmpty ||
                    _selectedImageFile != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NewsPalette.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: NewsPalette.border),
                    ),
                    child: Row(
                      children: [
                        if (_selectedImageFile != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _selectedImageFile!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (_selectedImageFile != null &&
                            (_selectedGifPreview ?? "").isNotEmpty)
                          const SizedBox(width: 10),
                        if ((_selectedGifPreview ?? '').isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _selectedGifPreview!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Вложение добавлено",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _selectedGifUrl = null;
                            _selectedGifPreview = null;
                            _selectedImageFile = null;
                          }),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      tooltip: "GIF",
                      onPressed: _openGifPicker,
                      icon: const Icon(
                        Icons.gif_box_outlined,
                        color: NewsPalette.primaryGreen,
                      ),
                    ),
                    IconButton(
                      tooltip: "Фото",
                      onPressed: _pickImage,
                      icon: const Icon(
                        Icons.photo_outlined,
                        color: NewsPalette.primaryGreen,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        focusNode: _commentFocus,
                        controller: _commentController,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: _editingCommentId != null
                              ? "Редактировать..."
                              : "Написать комментарий...",
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: NewsPalette.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: NewsPalette.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: NewsPalette.primaryGreen.withOpacity(0.65),
                              width: 1.6,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: NewsPalette.primaryGreen,
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: NewsPalette.greenGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: IconButton(
                              onPressed: _send,
                              icon: Icon(
                                _editingCommentId != null
                                    ? Icons.check
                                    : Icons.send,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NewsPalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NewsPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CNode {
  final int id;
  final Map<String, dynamic> data;
  final List<_CNode> children = [];
  _CNode({required this.id, required this.data});
}

class _ThreadList extends StatelessWidget {
  final List<_CNode> nodes;
  final int currentUserId;
  final Set<int> collapsed;
  final int Function(_CNode) countDesc;
  final Map<int, Map<String, dynamic>> byId;
  final void Function(int id) onToggleCollapse;
  final void Function(_CNode node) onReply;
  final void Function(_CNode node) onEdit;
  final void Function(_CNode node) onDelete;
  final void Function(int commentId, int value) onVote;
  final void Function(String url, String heroTag) onOpenImage;
  final String Function(Map<String, dynamic>) safeName;
  final String Function(Map<String, dynamic>) safeInitial;
  final String Function(dynamic) formatDate;
  final String Function(Map<String, dynamic>) quoteFor;

  const _ThreadList({
    required this.nodes,
    required this.currentUserId,
    required this.collapsed,
    required this.countDesc,
    required this.byId,
    required this.onToggleCollapse,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onVote,
    required this.onOpenImage,
    required this.safeName,
    required this.safeInitial,
    required this.formatDate,
    required this.quoteFor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: nodes
          .map(
            (n) => _ThreadNode(
              node: n,
              depth: 0,
              currentUserId: currentUserId,
              collapsed: collapsed,
              countDesc: countDesc,
              byId: byId,
              onToggleCollapse: onToggleCollapse,
              onReply: onReply,
              onEdit: onEdit,
              onDelete: onDelete,
              onVote: onVote,
              onOpenImage: onOpenImage,
              safeName: safeName,
              safeInitial: safeInitial,
              formatDate: formatDate,
              quoteFor: quoteFor,
            ),
          )
          .toList(),
    );
  }
}

class _ThreadNode extends StatelessWidget {
  final _CNode node;
  final int depth;
  final int currentUserId;
  final Set<int> collapsed;
  final int Function(_CNode) countDesc;
  final Map<int, Map<String, dynamic>> byId;
  final void Function(int id) onToggleCollapse;
  final void Function(_CNode node) onReply;
  final void Function(_CNode node) onEdit;
  final void Function(_CNode node) onDelete;
  final void Function(int commentId, int value) onVote;
  final void Function(String url, String heroTag) onOpenImage;
  final String Function(Map<String, dynamic>) safeName;
  final String Function(Map<String, dynamic>) safeInitial;
  final String Function(dynamic) formatDate;
  final String Function(Map<String, dynamic>) quoteFor;

  const _ThreadNode({
    required this.node,
    required this.depth,
    required this.currentUserId,
    required this.collapsed,
    required this.countDesc,
    required this.byId,
    required this.onToggleCollapse,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onVote,
    required this.onOpenImage,
    required this.safeName,
    required this.safeInitial,
    required this.formatDate,
    required this.quoteFor,
  });

  int _asInt(dynamic v) =>
      v is int ? v : int.tryParse((v ?? "").toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final c = node.data;

    final name = safeName(c);
    final date = formatDate(c["created_at"]);
    final edited = (c["edited_at"] ?? "").toString().trim().isNotEmpty;

    final gifUrl = (c["gif_url"] ?? "").toString().trim();
    final imgUrl = (c["image_url"] ?? "").toString().trim();
    final text = (c["comment"] ?? "").toString().trim();

    final isMine = _asInt(c["user_id"]) == currentUserId;
    final hasChildren = node.children.isNotEmpty;
    final isCollapsed = collapsed.contains(node.id);

    final score = _asInt(c["score"]);
    final myVote = _asInt(c["my_vote"]);

    final parentId = _asInt(c["parent_id"]);
    final parent = parentId > 0 ? byId[parentId] : null;

    final d = depth.clamp(0, 6);
    final leftPad = 8.0 + (d * 12.0);

    final compact = MediaQuery.of(context).size.width < 360;
    final hiddenCount = countDesc(node);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: leftPad),
          if (d > 0)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 18, right: 8),
              decoration: BoxDecoration(
                color: NewsPalette.primaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: NewsPalette.primaryGreen.withOpacity(0.25),
                ),
              ),
            ),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(compact ? 10 : 12),
              decoration: BoxDecoration(
                color: NewsPalette.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NewsPalette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: NewsPalette.lightGreen,
                        child: Text(
                          safeInitial(c),
                          style: const TextStyle(
                            color: NewsPalette.primaryGreen,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: NewsPalette.text,
                          ),
                        ),
                      ),
                      if (date.isNotEmpty)
                        Text(
                          date,
                          style: const TextStyle(
                            color: NewsPalette.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (parent != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: NewsPalette.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NewsPalette.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 3,
                            height: 38,
                            decoration: BoxDecoration(
                              color: NewsPalette.primaryGreen.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  safeName(parent),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  quoteFor(parent),
                                  style: const TextStyle(
                                    color: NewsPalette.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (imgUrl.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => onOpenImage(imgUrl, "cimg_${node.id}"),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          color: Colors.black,
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (gifUrl.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => onOpenImage(gifUrl, "gif_${node.id}"),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          color: Colors.black,
                          child: AspectRatio(
                            aspectRatio: 1.6,
                            child: Image.network(
                              gifUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (text.isNotEmpty)
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: text == "Комментарий удалён"
                            ? Colors.grey.shade600
                            : NewsPalette.text,
                        fontWeight: text == "Комментарий удалён"
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 10),
                  _CommentActionsRow(
                    score: score,
                    myVote: myVote,
                    hasChildren: hasChildren,
                    isCollapsed: isCollapsed,
                    hiddenCount: hiddenCount,
                    isMine: isMine,
                    edited: edited,
                    onUpvote: () => onVote(node.id, 1),
                    onDownvote: () => onVote(node.id, -1),
                    onReply: () => onReply(node),
                    onToggleCollapse:
                        hasChildren ? () => onToggleCollapse(node.id) : null,
                    onEdit: isMine ? () => onEdit(node) : null,
                    onDelete: isMine ? () => onDelete(node) : null,
                  ),
                  if (!isCollapsed && hasChildren) ...[
                    const SizedBox(height: 6),
                    Column(
                      children: node.children
                          .map(
                            (ch) => _ThreadNode(
                              node: ch,
                              depth: depth + 1,
                              currentUserId: currentUserId,
                              collapsed: collapsed,
                              countDesc: countDesc,
                              byId: byId,
                              onToggleCollapse: onToggleCollapse,
                              onReply: onReply,
                              onEdit: onEdit,
                              onDelete: onDelete,
                              onVote: onVote,
                              onOpenImage: onOpenImage,
                              safeName: safeName,
                              safeInitial: safeInitial,
                              formatDate: formatDate,
                              quoteFor: quoteFor,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentActionsRow extends StatelessWidget {
  final int score;
  final int myVote;
  final bool hasChildren;
  final bool isCollapsed;
  final int hiddenCount;
  final bool isMine;
  final bool edited;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback onReply;
  final VoidCallback? onToggleCollapse;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CommentActionsRow({
    super.key,
    required this.score,
    required this.myVote,
    required this.hasChildren,
    required this.isCollapsed,
    required this.hiddenCount,
    required this.isMine,
    required this.edited,
    required this.onUpvote,
    required this.onDownvote,
    required this.onReply,
    this.onToggleCollapse,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final compact = w < 360;

    Color voteColor(int v) =>
        myVote == v ? NewsPalette.primaryGreen : Colors.grey.shade600;

    Widget votePill() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: NewsPalette.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: NewsPalette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onUpvote,
              child: Icon(Icons.arrow_drop_up, size: 24, color: voteColor(1)),
            ),
            Text(
              score.toString(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            InkWell(
              onTap: onDownvote,
              child: Icon(Icons.arrow_drop_down, size: 24, color: voteColor(-1)),
            ),
          ],
        ),
      );
    }

    Widget replyBtn() {
      return TextButton.icon(
        onPressed: onReply,
        icon: const Icon(Icons.reply, size: 18),
        label: Text(compact ? "Ответ" : "Ответить"),
        style: TextButton.styleFrom(
          foregroundColor: NewsPalette.primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size(0, 0),
        ),
      );
    }

    Widget collapseBtn() {
      if (!hasChildren) return const SizedBox.shrink();
      return TextButton(
        onPressed: onToggleCollapse,
        style: TextButton.styleFrom(
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size(0, 0),
        ),
        child: Text(isCollapsed ? "+$hiddenCount" : (compact ? "Сверн." : "Свернуть")),
      );
    }

    Widget moreMenu() {
      if (!isMine) return const SizedBox.shrink();
      return _AnimatedMoreMenu(onEdit: onEdit, onDelete: onDelete);
    }

    return Row(
      children: [
        votePill(),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              replyBtn(),
              if (hasChildren) collapseBtn(),
              if (edited)
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Text(
                    "изменено",
                    style: TextStyle(
                      color: NewsPalette.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
        moreMenu(),
      ],
    );
  }
}

class _AnimatedMoreMenu extends StatefulWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _AnimatedMoreMenu({this.onEdit, this.onDelete});

  @override
  State<_AnimatedMoreMenu> createState() => _AnimatedMoreMenuState();
}

class _AnimatedMoreMenuState extends State<_AnimatedMoreMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    reverseDuration: const Duration(milliseconds: 120),
  );

  late final Animation<double> _scale =
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _c.value = 1.0;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = <PopupMenuEntry<String>>[
      if (widget.onEdit != null)
        const PopupMenuItem<String>(value: "edit", child: Text("Редактировать")),
      if (widget.onDelete != null)
        const PopupMenuItem<String>(value: "delete", child: Text("Удалить")),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: "Действия",
      splashRadius: 20,
      offset: const Offset(0, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onOpened: () => _c.forward(from: 0.0),
      onCanceled: () => _c.reverse(),
      onSelected: (v) {
        _c.reverse();
        if (v == "edit") widget.onEdit?.call();
        if (v == "delete") widget.onDelete?.call();
      },
      itemBuilder: (_) => items,
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Icon(Icons.more_vert, color: Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullScreenImageViewer({
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineVideoBlockCard extends StatelessWidget {
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final VoidCallback onOpenExternal;
  final VoidCallback onOpenInside;

  const _InlineVideoBlockCard({
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.onOpenExternal,
    required this.onOpenInside,
  });

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

  @override
  Widget build(BuildContext context) {
    final isDirect = _looksLikeDirectVideoUrl(videoUrl);
    final isExternal = _looksLikeExternalVideoPage(videoUrl);

    String preview = thumbnailUrl.trim();
    if (preview.isEmpty) {
      preview = _tryBuildAutoThumbnail(videoUrl) ?? "";
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: NewsPalette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NewsPalette.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpenInside,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (preview.isNotEmpty)
                      Image.network(
                        preview,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF111827),
                          child: const Center(
                            child: Icon(Icons.video_library, color: Colors.white54),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: const Color(0xFF111827),
                        child: const Center(
                          child: Icon(
                            Icons.video_library,
                            color: Colors.white54,
                            size: 40,
                          ),
                        ),
                      ),
                    Container(color: Colors.black.withOpacity(0.20)),
                    const Center(
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.play_arrow,
                          color: NewsPalette.primaryGreen,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.trim().isNotEmpty) ...[
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: NewsPalette.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    isDirect
                        ? "Прямой видеофайл"
                        : isExternal
                            ? "Видео по внешней ссылке"
                            : "Видеоисточник",
                    style: const TextStyle(
                      color: NewsPalette.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: NewsPalette.greenGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isDirect ? "Смотреть" : "Открыть",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onOpenExternal,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text(
                          "Открыть ссылку",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: NewsPalette.primaryGreen,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    );
  }
}

class _GifPickResult {
  final String preview;
  final String url;
  const _GifPickResult(this.preview, this.url);
}

class _GifPickerSheet extends StatefulWidget {
  const _GifPickerSheet();

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> {
  final TextEditingController _q = TextEditingController();
  bool loading = false;
  List<_GifPickResult> items = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _search("");
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final uri = Uri.parse(
        "https://sportotekaapp.ru/api/tenor_search.php?q=${Uri.encodeComponent(query)}&limit=36",
      );
      final r = await http.get(uri);

      if (r.statusCode != 200) {
        setState(() => error = "HTTP ${r.statusCode}");
        return;
      }

      final j = json.decode(r.body);
      if (j is! Map || j["success"] != true) {
        setState(() => error =
            (j is Map ? (j["message"] ?? "Ошибка") : "Ошибка").toString());
        return;
      }

      final list = (j["items"] is List) ? (j["items"] as List) : [];
      final parsed = <_GifPickResult>[];

      for (final it in list) {
        if (it is Map) {
          final preview = (it["preview"] ?? "").toString();
          final url = (it["url"] ?? "").toString();
          if (preview.isNotEmpty && url.isNotEmpty) {
            parsed.add(_GifPickResult(preview, url));
          }
        }
      }

      setState(() => items = parsed);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Row(
                children: [
                  const Text(
                    "GIF",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _q,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => _search(v.trim()),
                decoration: InputDecoration(
                  hintText: "Поиск GIF…",
                  filled: true,
                  fillColor: NewsPalette.background,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: NewsPalette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: NewsPalette.primaryGreen.withOpacity(0.65),
                      width: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: NewsPalette.primaryGreen,
                    ),
                  ),
                )
              else if (error != null)
                Expanded(
                  child: Center(
                    child: Text(
                      "Ошибка: $error",
                      style: const TextStyle(color: NewsPalette.textMuted),
                    ),
                  ),
                )
              else
                Expanded(
                  child: GridView.builder(
                    controller: scroll,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final g = items[i];
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, g),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            color: Colors.black,
                            child: Image.network(
                              g.preview,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}