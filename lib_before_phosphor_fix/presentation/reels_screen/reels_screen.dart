// lib/presentation/reels_screen/reels_screen.dart
//
// ✅ Исправлено:
// 1) Добавлена поддержка initialReelId / initialIndex
// 2) ReelsScreen открывается с нужного ролика, а не с первого/последнего
// 3) Убраны лишние глобальные переменные
// 4) Нормализованы URL для видео / preview / avatar
// 5) Сохранены трансформации видео (rotation / crop / scale / dx / dy)
// 6) Убран размытый фон в contain-режиме
// 7) Видео отображается ближе к редактору

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/reels_screen/upload_reel_screen.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';

class ReelsScreen extends StatefulWidget {
  final int? initialReelId;
  final int initialIndex;

  const ReelsScreen({
    super.key,
    this.initialReelId,
    this.initialIndex = 0,
  });

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen>
    with SingleTickerProviderStateMixin {
  static const bool kShowAll = true;

  // ===== API =====
  static const String _apiBase = "https://sportotekaapp.ru/api";
  static const String _getReelsUrl = "$_apiBase/get_reels.php";
  static const String _toggleLikeUrl = "$_apiBase/toggle_reel_like.php";
  static const String _getCommentsUrl = "$_apiBase/get_reel_comments.php";
  static const String _addCommentUrl = "$_apiBase/add_reel_comment.php";
  static const String _deleteCommentUrl = "$_apiBase/delete_reel_comment.php";
  static const String _addViewUrl = "$_apiBase/add_reel_view.php";

  List<Map<String, dynamic>> reels = [];

  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initializing = {};

  bool isLoading = true;
  int _currentPage = 0;
  late final PageController _pageController;

  bool _muted = false;
  bool _fitModeContain = true;
  bool _userForcedFitMode = false;

  final Set<int> _blockedUserIds = {};
  final Set<int> _serverFlaggedReelIds = {};
  List<String> _bannedWords = ["badword1", "badword2", "offense1"];

  int _me = 1;
  final Set<int> _likeBusyReels = {};

  final Map<int, List<Map<String, dynamic>>> _commentsCache = {};
  final Map<int, bool> _commentsLoading = {};

  final Set<int> _viewCountedReelIds = {};
  Timer? _viewTimer;
  int? _viewTimerReelId;

  _ReplyTarget? _replyTarget;

  bool _showBigHeart = false;
  late final AnimationController _heartAnim;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();

    _currentPage = widget.initialIndex < 0 ? 0 : widget.initialIndex;
    _pageController = PageController(initialPage: _currentPage);

    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _heartScale = CurvedAnimation(parent: _heartAnim, curve: Curves.elasticOut);

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _bootstrap();
  }

  @override
  void dispose() {
    _cancelViewTimer();
    _disposeAllControllers();
    _pageController.dispose();
    _heartAnim.dispose();

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);

    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (mounted) setState(() => isLoading = true);

    await _loadMe();
    await Future.wait([
      _fetchFilters(),
      _fetchBlockedUsers(),
    ]);

    await _fetchReels();
  }

  // ===== HELPERS =====
  String _normalizeMediaUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('/')) return 'https://sportotekaapp.ru$s';
    return 'https://sportotekaapp.ru/$s';
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString().replaceAll(RegExp('[^0-9-]'), '')) ?? 0;
  }

  double _toDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? fallback;
  }

  int _safeInitialIndex(int length) {
    if (length <= 0) return 0;
    return widget.initialIndex.clamp(0, length - 1);
  }

  // ===== ME =====
  Future<void> _loadMe() async {
    try {
      final v = await PrefUtils.getUserId();
      if (v != null && v > 0) {
        _me = v;
        return;
      }
    } catch (_) {}
    _me = 1;
  }

  int _meId() => _me;

  // ===== FILTERS / BLOCKS =====
  Future<void> _fetchFilters() async {
    try {
      final url = Uri.parse("$_apiBase/get_content_filters.php");
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
        final jsonAny = json.decode(body);
        final words = (jsonAny['banned_words'] as List?)?.cast<String>() ?? [];
        final flagged = (jsonAny['flagged_reel_ids'] as List?)
                ?.map((e) => int.tryParse(e.toString()) ?? 0)
                .where((e) => e > 0)
                .toSet() ??
            {};
        if (words.isNotEmpty) _bannedWords = words;
        _serverFlaggedReelIds
          ..clear()
          ..addAll(flagged);
      }
    } catch (_) {}
  }

  Future<void> _fetchBlockedUsers() async {
    try {
      final url = Uri.parse("$_apiBase/get_blocked_users.php?me=${_meId()}");
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
        final data = json.decode(body);
        final ids = (data['blocked_user_ids'] as List?)
                ?.map((e) => int.tryParse(e.toString()) ?? 0)
                .where((e) => e > 0)
                .toSet() ??
            {};
        _blockedUserIds
          ..clear()
          ..addAll(ids);
      }
    } catch (_) {}
  }

  // ===== REELS =====
  Future<void> _fetchReels() async {
    try {
      final url = Uri.parse("$_getReelsUrl?limit=100&offset=0&me=${_meId()}");
      final resp = await http.get(url);

      if (!mounted) return;

      if (resp.statusCode != 200) {
        setState(() => isLoading = false);
        debugPrint('❌ get_reels.php HTTP ${resp.statusCode}');
        return;
      }

      final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      dynamic jsonAny;
      try {
        jsonAny = json.decode(body);
      } catch (e) {
        setState(() => isLoading = false);
        debugPrint('❌ JSON parse error: $e\n$body');
        return;
      }

      final parsed = _parseReels(jsonAny);

      if (kShowAll) {
        reels = parsed.where((m) {
          final vu = (m['video_url'] ?? '').toString().trim();
          return vu.isNotEmpty;
        }).toList();
      } else {
        reels = parsed.where((m) {
          final blockedAuthor = _blockedUserIds.contains(m['user_id'] ?? -1);
          if (blockedAuthor) return false;

          final status = (m['moderation_status'] ?? 'ok').toString();
          if (status == 'blocked' || status == 'flagged') return false;

          if (_isObjectionable(m)) return false;
          return true;
        }).toList();
      }

      int targetIndex = 0;
      if (reels.isNotEmpty) {
        if (widget.initialReelId != null && widget.initialReelId! > 0) {
          final foundIndex = reels.indexWhere(
            (r) => _toInt(r['id']) == widget.initialReelId,
          );
          if (foundIndex != -1) {
            targetIndex = foundIndex;
          } else {
            targetIndex = _safeInitialIndex(reels.length);
          }
        } else {
          targetIndex = _safeInitialIndex(reels.length);
        }
      }

      _currentPage = targetIndex;
      _cancelViewTimer();
      _disposeAllControllers();

      if (mounted) {
        setState(() => isLoading = false);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || reels.isEmpty) return;

        if (_pageController.hasClients) {
          _pageController.jumpToPage(targetIndex);
        }

        await _ensureController(targetIndex, autoplay: true);
        _ensureController(targetIndex + 1);
        _ensureController(targetIndex - 1);

        final currentController = _controllers[targetIndex];
        if (currentController != null && currentController.value.isInitialized) {
          _userForcedFitMode = false;
          _fitModeContain = _isLandscapeReel(currentController);
        }

        _scheduleViewForIndex(targetIndex);

        if (mounted) {
          setState(() {});
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint('❌ _fetchReels error: $e');
    }
  }

  List<Map<String, dynamic>> _parseReels(dynamic jsonAny) {
    List raw;
    if (jsonAny is Map) {
      raw = (jsonAny['reels'] ??
              jsonAny['data'] ??
              jsonAny['items'] ??
              jsonAny['list'] ??
              []) as List? ??
          [];
    } else if (jsonAny is List) {
      raw = jsonAny;
    } else {
      raw = const [];
    }

    return raw
        .map<Map<String, dynamic>>((e) {
          final m = Map<String, dynamic>.from(e as Map);

          final String videoRaw =
              (m['video_url'] ?? m['video'] ?? m['url'] ?? m['src'] ?? '')
                  .toString();
          String thumbRaw =
              (m['thumbnail'] ?? m['thumb'] ?? m['poster'] ?? '').toString();
          if (thumbRaw.isEmpty && m['preview'] != null) {
            thumbRaw = m['preview'].toString();
          }

          final String avatarRaw =
              (m['user_avatar'] ?? m['avatar'] ?? m['photo'] ?? '').toString();

          final int likes = _toInt(m['likes'] ?? m['like_count'] ?? 0);
          final int comments = _toInt(m['comments'] ?? m['comment_count'] ?? 0);
          final int views = _toInt(m['views'] ?? m['view_count'] ?? 0);

          final int userId = _toInt(m['user_id'] ?? m['author_id'] ?? 0);
          final int reelId = _toInt(m['id'] ?? m['reel_id'] ?? 0);

          final bool liked = (m['liked'] == true || _toInt(m['liked']) == 1);

          final int rotation = _toInt(m['rotation'] ?? 0);
          final String cropMode = m['crop_mode']?.toString() ?? 'fit';
          final double cropScale = _toDouble(m['crop_scale'], 1.0);
          final double cropDx = _toDouble(m['crop_dx'], 0.0);
          final double cropDy = _toDouble(m['crop_dy'], 0.0);

          return {
            'id': reelId,
            'user_id': userId,
            'video_url': _normalizeMediaUrl(videoRaw),
            'thumbnail': _normalizeMediaUrl(thumbRaw),
            'username':
                (m['username'] ?? m['user'] ?? m['author_name'] ?? '').toString(),
            'user_avatar': _normalizeMediaUrl(avatarRaw),
            'description':
                (m['description'] ?? m['title'] ?? m['caption'] ?? '').toString(),
            'likes': likes,
            'comments': comments,
            'views': views,
            'liked': liked,
            'moderation_status':
                (m['moderation_status'] ?? 'ok').toString().toLowerCase(),
            'rotation': rotation,
            'crop_mode': cropMode,
            'crop_scale': cropScale,
            'crop_dx': cropDx,
            'crop_dy': cropDy,
            '_raw': m,
          };
        })
        .where((e) => (e['video_url'] as String).isNotEmpty)
        .toList();
  }

  // ===== CONTROLLERS =====
  Future<void> _ensureController(int index, {bool autoplay = false}) async {
    if (index < 0 || index >= reels.length) return;
    if (_controllers.containsKey(index)) return;
    if (_initializing.contains(index)) return;
    _initializing.add(index);

    final url = (reels[index]['video_url'] ?? '').toString().trim();
    if (url.isEmpty) {
      _initializing.remove(index);
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await controller.initialize();
      controller.setLooping(true);
      await controller.setVolume(_muted ? 0.0 : 1.0);

      _controllers[index] = controller;

      if (!mounted) return;

      if (autoplay && index == _currentPage) {
        await controller.play();
      }

      setState(() {});
    } catch (e) {
      debugPrint("❌ controller init error: $e");
      await controller.dispose();
    } finally {
      _initializing.remove(index);
    }
  }

  void _disposeController(int index) {
    final c = _controllers.remove(index);
    c?.dispose();
  }

  void _disposeAllControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _initializing.clear();
  }

  void _trimControllersKeepAround(int center) {
    final toKeep = {center - 1, center, center + 1};
    final keys = _controllers.keys.toList();
    for (final k in keys) {
      if (!toKeep.contains(k)) _disposeController(k);
    }
  }

  // ===== VIDEO ORIENTATION =====
  bool _isLandscapeReel(VideoPlayerController c) {
    if (!c.value.isInitialized) return false;

    final rotDeg = c.value.rotationCorrection;
    final s = c.value.size;
    var w = s.width;
    var h = s.height;

    if (w <= 0 || h <= 0) return false;

    final norm = ((rotDeg % 360) + 360) % 360;
    final swap = (norm == 90 || norm == 270);
    if (swap) {
      final tmp = w;
      w = h;
      h = tmp;
    }

    return w >= h;
  }

  // ===== CONTENT FILTER =====
  bool _isObjectionable(Map<String, dynamic> reel) {
    if (kShowAll) return false;
    final int reelId = reel['id'] ?? 0;
    if (reelId != 0 && _serverFlaggedReelIds.contains(reelId)) return true;

    final String text = (reel['description'] ?? '').toString().toLowerCase();
    for (final w in _bannedWords) {
      if (w.isEmpty) continue;
      if (text.contains(w.toLowerCase())) return true;
    }
    return false;
  }

  // ===== VIEWS =====
  void _cancelViewTimer() {
    _viewTimer?.cancel();
    _viewTimer = null;
    _viewTimerReelId = null;
  }

  void _scheduleViewForIndex(int index) {
    if (index < 0 || index >= reels.length) return;

    final reel = reels[index];
    final int reelId = _toInt(reel['id']);
    if (reelId <= 0) return;
    if (_viewCountedReelIds.contains(reelId)) return;

    _cancelViewTimer();
    _viewTimerReelId = reelId;

    _viewTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      if (_currentPage != index) return;
      if (_viewTimerReelId != reelId) return;

      final c = _controllers[index];
      if (c == null || !c.value.isInitialized) return;
      if (!c.value.isPlaying) return;

      await _sendViewAndUpdate(index);
    });
  }

  Future<void> _sendViewAndUpdate(int index) async {
    final reel = reels[index];
    final int reelId = _toInt(reel['id']);
    if (reelId <= 0) return;
    if (_viewCountedReelIds.contains(reelId)) return;

    _viewCountedReelIds.add(reelId);

    final oldViews = _toInt(reel['views']);
    if (mounted) {
      setState(() {
        reel['views'] = oldViews + 1;
      });
    }

    try {
      final resp = await http.post(
        Uri.parse(_addViewUrl),
        body: {
          "reel_id": reelId.toString(),
          "user_id": _meId().toString(),
        },
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final raw = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
        dynamic data;
        try {
          data = json.decode(raw);
        } catch (_) {
          data = null;
        }

        if (data is Map && data['success'] == true) {
          final int serverViews = _toInt(data['views']);
          if (serverViews > 0) {
            setState(() {
              reel['views'] = serverViews;
            });
          }
        }
      }
    } catch (_) {}
  }

  // ===== LIKE =====
  Future<void> _toggleLike(int index, {bool fromDoubleTap = false}) async {
    final reel = reels[index];
    final int reelId = reel['id'] ?? 0;
    if (reelId <= 0) return;
    if (_likeBusyReels.contains(reelId)) return;

    _likeBusyReels.add(reelId);

    final bool wasLiked = reel['liked'] == true;
    final int oldLikes = _toInt(reel['likes']);
    final bool willLike = fromDoubleTap ? true : !wasLiked;

    if (mounted) {
      setState(() {
        reel['liked'] = willLike;
        if (willLike && !wasLiked) {
          reel['likes'] = oldLikes + 1;
        } else if (!willLike && wasLiked) {
          reel['likes'] = oldLikes - 1;
        }
      });
    }

    try {
      final resp = await http.post(Uri.parse(_toggleLikeUrl), body: {
        "reel_id": reelId.toString(),
        "user_id": _meId().toString(),
      });

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
        dynamic data;
        try {
          data = json.decode(body);
        } catch (_) {
          data = null;
        }

        if (data is Map && data['success'] == true) {
          final liked = (data['liked'] == true || _toInt(data['liked']) == 1);
          final likesCount = _toInt(data['likes_count']);

          setState(() {
            reel['liked'] = liked;
            reel['likes'] = likesCount;
          });
        } else {
          setState(() {
            reel['liked'] = wasLiked;
            reel['likes'] = oldLikes;
          });
        }
      } else {
        setState(() {
          reel['liked'] = wasLiked;
          reel['likes'] = oldLikes;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        reel['liked'] = wasLiked;
        reel['likes'] = oldLikes;
      });
    } finally {
      _likeBusyReels.remove(reelId);
    }
  }

  // ===== SHARE =====
  Future<void> _shareReel(int index) async {
    try {
      final reel = reels[index];
      final videoUrl = (reel['video_url'] ?? '').toString().trim();
      if (videoUrl.isEmpty) return;

      final username = (reel['username'] ?? '').toString();
      final desc = (reel['description'] ?? '').toString();

      final text = [
        "🎬 Reels от $username",
        if (desc.isNotEmpty) desc,
        videoUrl,
      ].join("\n");

      await Share.share(text);
    } catch (e) {
      debugPrint("❌ share error: $e");
    }
  }

  // ===== PROFILE =====
  void _openUserProfile(int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyProfileScreen(userId: userId),
      ),
    );
  }

  // ===== COMMENTS =====
  Future<List<Map<String, dynamic>>> _fetchComments(int reelId,
      {int limit = 200, int offset = 0}) async {
    final url = Uri.parse(
        "$_getCommentsUrl?reel_id=$reelId&me=${_meId()}&limit=$limit&offset=$offset");
    final resp = await http.get(url);
    if (resp.statusCode != 200) return [];

    final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
    final data = json.decode(body);

    final list = (data is Map ? (data['comments'] as List?) : null) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<int?> _addComment(int reelId, String text, {int? replyTo}) async {
    final url = Uri.parse(_addCommentUrl);
    final body = <String, String>{
      "reel_id": reelId.toString(),
      "user_id": _meId().toString(),
      "text": text,
    };
    if (replyTo != null && replyTo > 0) {
      body["reply_to"] = replyTo.toString();
    }

    final resp = await http.post(url, body: body);
    if (resp.statusCode != 200) return null;

    final raw = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
    final data = json.decode(raw);

    if (data is Map && data['success'] == true) {
      return _toInt(data['comment_id']);
    }
    return null;
  }

  Future<bool> _deleteComment(int commentId) async {
    try {
      final url = Uri.parse(_deleteCommentUrl);
      final resp = await http.post(url, body: {
        "comment_id": commentId.toString(),
        "user_id": _meId().toString(),
      });
      if (resp.statusCode != 200) return false;
      final raw = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      final data = json.decode(raw);
      return (data is Map && data["success"] == true);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openCommentsSheet(int index) async {
    final reel = reels[index];
    final int reelId = reel['id'] ?? 0;
    if (reelId <= 0) return;

    final textCtrl = TextEditingController();
    _replyTarget = null;

    if (_commentsCache[reelId] == null) {
      _commentsLoading[reelId] = true;
      if (mounted) setState(() {});
      final items = await _fetchComments(reelId);
      _commentsCache[reelId] = items;
      _commentsLoading[reelId] = false;

      if (mounted) {
        setState(() {
          reel['comments'] = items.length;
        });
      }
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                final loading = _commentsLoading[reelId] == true;
                final items = _commentsCache[reelId] ?? [];

                Future<void> refresh() async {
                  _commentsLoading[reelId] = true;
                  setLocal(() {});
                  final fresh = await _fetchComments(reelId);
                  _commentsCache[reelId] = fresh;
                  _commentsLoading[reelId] = false;

                  setLocal(() {});
                  if (mounted) {
                    setState(() {
                      reel['comments'] = fresh.length;
                    });
                  }
                }

                void setReplyFromComment(Map<String, dynamic> c) {
                  final int cid = _toInt(c['id']);
                  if (cid <= 0) return;

                  _replyTarget = _ReplyTarget(
                    commentId: cid,
                    username: (c['username'] ?? 'User').toString(),
                    text: (c['text'] ?? '').toString(),
                  );
                  setLocal(() {});
                }

                return SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.78,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Комментарии (${items.length})",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              )
                            : RefreshIndicator(
                                color: Colors.white,
                                backgroundColor: Colors.black,
                                onRefresh: refresh,
                                child: (items.isEmpty)
                                    ? ListView(
                                        children: const [
                                          SizedBox(height: 120),
                                          Center(
                                            child: Text(
                                              "Пока нет комментариев",
                                              style:
                                                  TextStyle(color: Colors.white70),
                                            ),
                                          ),
                                        ],
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 8, 12, 8),
                                        itemCount: items.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(color: Colors.white12),
                                        itemBuilder: (_, i) {
                                          final c = items[i];

                                          final int cid = _toInt(c['id']);
                                          final int uid = _toInt(c['user_id']);
                                          final avatar =
                                              (c['user_avatar'] ?? '').toString();
                                          final username =
                                              (c['username'] ?? 'User').toString();
                                          final text =
                                              (c['text'] ?? '').toString();

                                          final bool isMine =
                                              (c['is_mine'] == 1) || (uid == _meId());

                                          final int? replyToId =
                                              c['reply_to_comment_id'] == null
                                                  ? null
                                                  : _toInt(c['reply_to_comment_id']);
                                          final replyUsername =
                                              (c['reply_username'] ?? '').toString();
                                          final replyText =
                                              (c['reply_text'] ?? '').toString();

                                          String timeText = "";
                                          try {
                                            final dt = DateTime.tryParse(
                                                (c['created_at'] ?? '').toString());
                                            if (dt != null) {
                                              final hh = dt.hour
                                                  .toString()
                                                  .padLeft(2, '0');
                                              final mm = dt.minute
                                                  .toString()
                                                  .padLeft(2, '0');
                                              timeText = "$hh:$mm";
                                            }
                                          } catch (_) {}

                                          return Dismissible(
                                            key: ValueKey("c_$cid"),
                                            direction: DismissDirection.startToEnd,
                                            confirmDismiss: (_) async {
                                              setReplyFromComment(c);
                                              return false;
                                            },
                                            background: Container(
                                              padding: const EdgeInsets.only(left: 16),
                                              alignment: Alignment.centerLeft,
                                              color: Colors.white10,
                                              child: const Icon(
                                                Icons.reply_rounded,
                                                color: Colors.white70,
                                              ),
                                            ),
                                            child: InkWell(
                                              onLongPress: () => setReplyFromComment(c),
                                              onTap: () => setReplyFromComment(c),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: Colors.white10,
                                                    backgroundImage: avatar.isNotEmpty
                                                        ? NetworkImage(
                                                            _normalizeMediaUrl(avatar),
                                                          )
                                                        : null,
                                                    child: avatar.isEmpty
                                                        ? const Icon(
                                                            Icons.person,
                                                            color: Colors.white70,
                                                            size: 18,
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                username,
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.w700,
                                                                ),
                                                              ),
                                                            ),
                                                            if (timeText.isNotEmpty)
                                                              Text(
                                                                timeText,
                                                                style: const TextStyle(
                                                                  color: Colors.white38,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            if (isMine)
                                                              PopupMenuButton<String>(
                                                                color: Colors.black87,
                                                                icon: const Icon(
                                                                  Icons.more_horiz,
                                                                  color: Colors.white54,
                                                                  size: 18,
                                                                ),
                                                                onSelected: (v) async {
                                                                  if (v == 'delete') {
                                                                    final ok =
                                                                        await _deleteComment(cid);
                                                                    if (!ok) return;

                                                                    setLocal(() {
                                                                      items.removeWhere((x) =>
                                                                          _toInt(x['id']) == cid);
                                                                    });

                                                                    _commentsCache[reelId] = items;

                                                                    if (mounted) {
                                                                      setState(() {
                                                                        reel['comments'] = items.length;
                                                                      });
                                                                    }
                                                                  }
                                                                },
                                                                itemBuilder: (_) => const [
                                                                  PopupMenuItem(
                                                                    value: 'delete',
                                                                    child: Text(
                                                                      'Удалить',
                                                                      style: TextStyle(
                                                                          color: Colors.white),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                          ],
                                                        ),
                                                        if (replyToId != null &&
                                                            replyToId > 0 &&
                                                            (replyUsername.isNotEmpty ||
                                                                replyText.isNotEmpty))
                                                          Container(
                                                            margin: const EdgeInsets.only(
                                                                top: 6, bottom: 6),
                                                            padding: const EdgeInsets.symmetric(
                                                                horizontal: 10, vertical: 8),
                                                            decoration: BoxDecoration(
                                                              color: Colors.white10,
                                                              borderRadius:
                                                                  BorderRadius.circular(12),
                                                              border: const Border(
                                                                left: BorderSide(
                                                                    color: Colors.white30,
                                                                    width: 3),
                                                              ),
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  replyUsername.isEmpty
                                                                      ? "Комментарий"
                                                                      : replyUsername,
                                                                  style: const TextStyle(
                                                                    color: Colors.white,
                                                                    fontWeight: FontWeight.w700,
                                                                    fontSize: 12,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 2),
                                                                Text(
                                                                  replyText.isEmpty ? "…" : replyText,
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: const TextStyle(
                                                                    color: Colors.white70,
                                                                    fontSize: 12,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        Text(
                                                          text,
                                                          style: const TextStyle(
                                                            color: Colors.white70,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                      ),
                      if (_replyTarget != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(14),
                            border: const Border(
                              left: BorderSide(color: Colors.white30, width: 3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Ответ: ${_replyTarget!.username}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _replyTarget!.text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white70),
                                onPressed: () {
                                  _replyTarget = null;
                                  setLocal(() {});
                                },
                              )
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white12)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: textCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: _replyTarget == null
                                      ? "Добавить комментарий..."
                                      : "Ответить...",
                                  hintStyle:
                                      const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: Colors.white10,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.send_rounded,
                                  color: Colors.white),
                              onPressed: () async {
                                final text = textCtrl.text.trim();
                                if (text.isEmpty) return;

                                final reply = _replyTarget;
                                textCtrl.clear();
                                _replyTarget = null;
                                setLocal(() {});

                                final optimistic = <String, dynamic>{
                                  "id": -DateTime.now().millisecondsSinceEpoch,
                                  "reel_id": reelId,
                                  "user_id": _meId(),
                                  "username": "Вы",
                                  "user_avatar": "",
                                  "text": text,
                                  "created_at": DateTime.now().toIso8601String(),
                                  "is_mine": 1,
                                  "likes_count": 0,
                                  "liked": 0,
                                  "reply_to_comment_id": reply?.commentId,
                                  "reply_username": reply?.username ?? "",
                                  "reply_text": reply?.text ?? "",
                                };

                                setLocal(() {
                                  items.insert(0, optimistic);
                                });

                                final newId = await _addComment(
                                  reelId,
                                  text,
                                  replyTo: reply?.commentId,
                                );

                                if (newId == null) {
                                  setLocal(() {
                                    items.removeWhere(
                                        (x) => x['id'] == optimistic['id']);
                                  });
                                  return;
                                }

                                setLocal(() {
                                  optimistic['id'] = newId;
                                });

                                _commentsCache[reelId] = items;

                                if (mounted) {
                                  setState(() {
                                    reel['comments'] = items.length;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ===== TOP BAR =====
  Widget _buildTopBar(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final iconSize = isLandscape ? 18.0 : 20.0;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              IconButton(
                splashRadius: 18,
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: iconSize),
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 4),
              const Text(
                "Reels",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              IconButton(
                splashRadius: 18,
                tooltip: _fitModeContain ? "FIT (вписать)" : "COVER (заполнить)",
                icon: Icon(
                  _fitModeContain
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: iconSize + 2,
                ),
                onPressed: () {
                  setState(() {
                    _fitModeContain = !_fitModeContain;
                    _userForcedFitMode = true;
                  });
                },
              ),
              IconButton(
                splashRadius: 18,
                icon: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: iconSize + 2,
                ),
                onPressed: () async {
                  setState(() => _muted = !_muted);
                  final c = _controllers[_currentPage];
                  if (c != null && c.value.isInitialized) {
                    await c.setVolume(_muted ? 0.0 : 1.0);
                  }
                },
              ),
              IconButton(
                splashRadius: 18,
                icon: Icon(Icons.add_a_photo_rounded,
                    color: Colors.white, size: iconSize + 2),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UploadReelScreen(onUploadComplete: _fetchReels),
                    ),
                  );
                  _fetchReels();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : (reels.isEmpty
              ? const Center(
                  child: Text(
                    'Пока нет видео',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: reels.length,
                      onPageChanged: (index) async {
                        final prev = _currentPage;
                        _currentPage = index;

                        _cancelViewTimer();

                        final prevC = _controllers[prev];
                        if (prevC != null &&
                            prevC.value.isInitialized &&
                            prevC.value.isPlaying) {
                          await prevC.pause();
                        }

                        await _ensureController(index, autoplay: true);

                        if (!_userForcedFitMode) {
                          final curC2 = _controllers[index];
                          if (curC2 != null && curC2.value.isInitialized) {
                            _fitModeContain = _isLandscapeReel(curC2);
                          }
                        }

                        final curC = _controllers[index];
                        if (curC != null && curC.value.isInitialized) {
                          await curC.setVolume(_muted ? 0.0 : 1.0);
                          if (!curC.value.isPlaying) {
                            await curC.play();
                          }
                        }

                        _ensureController(index + 1);
                        _ensureController(index - 1);
                        _trimControllersKeepAround(index);

                        _scheduleViewForIndex(index);

                        if (mounted) setState(() {});
                      },
                      itemBuilder: (context, index) {
                        final reel = reels[index];
                        final controller = _controllers[index];

                        final mq = MediaQuery.of(context);
                        final isLandscape = mq.orientation == Orientation.landscape;

                        final bottomSafe = mq.padding.bottom;
                        final topSafe = mq.padding.top;

                        final overlayBottom = (isLandscape ? 14.0 : 78.0) + bottomSafe;
                        final actionGap = isLandscape ? 12.0 : 18.0;
                        final actionIcon = isLandscape ? 20.0 : 22.0;

                        final bool liked = reel['liked'] == true;
                        final int authorId = _toInt(reel['user_id']);
                        final String authorName =
                            (reel['username'] ?? '').toString();
                        final String authorAvatar =
                            (reel['user_avatar'] ?? '').toString();

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (controller != null && controller.value.isInitialized)
                              GestureDetector(
                                onTap: () async {
                                  if (!controller.value.isInitialized) return;
                                  if (controller.value.isPlaying) {
                                    await controller.pause();
                                    _cancelViewTimer();
                                  } else {
                                    await controller.play();
                                    if (index == _currentPage) {
                                      _scheduleViewForIndex(index);
                                    }
                                  }
                                  if (mounted) setState(() {});
                                },
                                onDoubleTap: () async {
                                  _playBigHeart();
                                  await _toggleLike(index, fromDoubleTap: true);
                                },
                                child: _ReelVideoCover(
                                  controller: controller,
                                  contain: _fitModeContain,
                                  manualRotateDeg: reel['rotation'] as int?,
                                  cropMode: reel['crop_mode'] as String?,
                                  cropScale: (reel['crop_scale'] as num?)?.toDouble(),
                                  cropDx: (reel['crop_dx'] as num?)?.toDouble(),
                                  cropDy: (reel['crop_dy'] as num?)?.toDouble(),
                                ),
                              )
                            else
                              Stack(
                                fit: StackFit.expand,
                                children: [
                                  if ((reel['thumbnail'] ?? '').toString().isNotEmpty)
                                    Image.network(
                                      (reel['thumbnail'] ?? '').toString(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(),
                                    ),
                                  const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white),
                                  ),
                                ],
                              ),

                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.25),
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.35),
                                        Colors.black.withOpacity(0.80),
                                      ],
                                      stops: const [0.0, 0.35, 0.65, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            if (_showBigHeart)
                              Center(
                                child: ScaleTransition(
                                  scale: _heartScale,
                                  child: const Icon(
                                    Icons.favorite,
                                    color: Colors.white,
                                    size: 120,
                                  ),
                                ),
                              ),

                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: overlayBottom,
                              child: SafeArea(
                                top: false,
                                left: false,
                                right: false,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: _BottomCaption(
                                        avatarUrl: authorAvatar,
                                        username: authorName,
                                        description:
                                            (reel['description'] ?? '').toString(),
                                        onOpenProfile: () => _openUserProfile(authorId),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _RightActionsColumn(
                                      liked: liked,
                                      likes: (reel['likes'] ?? 0).toString(),
                                      comments: (reel['comments'] ?? 0).toString(),
                                      views: (reel['views'] ?? 0).toString(),
                                      iconSize: actionIcon,
                                      gap: actionGap,
                                      onLike: () => _toggleLike(index),
                                      onComments: () => _openCommentsSheet(index),
                                      onShare: () => _shareReel(index),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (controller != null &&
                                controller.value.isInitialized &&
                                !controller.value.isPlaying)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 54,
                                  ),
                                ),
                              ),

                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: _MiniProgressBar(controller: controller),
                            ),

                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Container(
                                  height: topSafe + 70,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.55),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    _buildTopBar(context),
                  ],
                )),
    );
  }

  void _playBigHeart() async {
    if (_showBigHeart) return;
    setState(() => _showBigHeart = true);
    _heartAnim.reset();
    _heartAnim.forward();
    await Future.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    setState(() => _showBigHeart = false);
  }
}

class _RightActionsColumn extends StatelessWidget {
  final bool liked;
  final String likes;
  final String comments;
  final String views;
  final double iconSize;
  final double gap;

  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onShare;

  const _RightActionsColumn({
    required this.liked,
    required this.likes,
    required this.comments,
    required this.views,
    required this.iconSize,
    required this.gap,
    required this.onLike,
    required this.onComments,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionBtn(
          icon: Icons.favorite_rounded,
          count: likes,
          color: liked ? Colors.redAccent : Colors.white,
          iconSize: iconSize,
          onTap: onLike,
        ),
        SizedBox(height: gap),
        _ActionBtn(
          icon: Icons.mode_comment_rounded,
          count: comments,
          iconSize: iconSize,
          onTap: onComments,
        ),
        SizedBox(height: gap),
        _ActionBtn(
          icon: Icons.visibility_rounded,
          count: views,
          iconSize: iconSize,
          onTap: null,
        ),
        SizedBox(height: gap),
        _ActionBtn(
          icon: Icons.send_rounded,
          iconSize: iconSize,
          onTap: onShare,
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String? count;
  final double iconSize;
  final VoidCallback? onTap;
  final Color? color;

  const _ActionBtn({
    required this.icon,
    this.count,
    required this.iconSize,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Icon(icon, color: color ?? Colors.white, size: iconSize),
            if ((count ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  count!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomCaption extends StatelessWidget {
  final String avatarUrl;
  final String username;
  final String description;
  final VoidCallback onOpenProfile;

  const _BottomCaption({
    required this.avatarUrl,
    required this.username,
    required this.description,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedAvatar = avatarUrl.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onOpenProfile,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white10,
                  backgroundImage:
                      normalizedAvatar.isNotEmpty ? NetworkImage(normalizedAvatar) : null,
                  child: normalizedAvatar.isEmpty
                      ? const Icon(Icons.person, color: Colors.white70, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (description.trim().isNotEmpty)
          Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.8,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  final VideoPlayerController? controller;
  const _MiniProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null || !c.value.isInitialized) return const SizedBox(height: 3);

    final pos = c.value.position.inMilliseconds.toDouble();
    final dur = c.value.duration.inMilliseconds.toDouble();
    final v = (dur <= 0) ? 0.0 : (pos / dur).clamp(0.0, 1.0);

    return Container(
      height: 3,
      color: Colors.white10,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: v,
        child: Container(height: 3, color: Colors.white54),
      ),
    );
  }
}

class _ReplyTarget {
  final int commentId;
  final String username;
  final String text;

  const _ReplyTarget({
    required this.commentId,
    required this.username,
    required this.text,
  });
}

class _ReelVideoCover extends StatelessWidget {
  final VideoPlayerController controller;
  final bool contain;

  final int? manualRotateDeg;
  final String? cropMode;
  final double? cropScale;
  final double? cropDx;
  final double? cropDy;

  const _ReelVideoCover({
    required this.controller,
    required this.contain,
    this.manualRotateDeg,
    this.cropMode,
    this.cropScale,
    this.cropDx,
    this.cropDy,
  });

  int _normDeg(int deg) => ((deg % 360) + 360) % 360;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.value.isInitialized) return const SizedBox();

        final int autoRotate = controller.value.rotationCorrection;
        final int totalRotate = _normDeg(autoRotate + (manualRotateDeg ?? 0));
        final double rotRad = totalRotate * math.pi / 180.0;

        final Size s = controller.value.size;
        double w = s.width;
        double h = s.height;

        if (w <= 0 || h <= 0) {
          final ar = controller.value.aspectRatio;
          if (ar <= 0) return const SizedBox();
          w = ar >= 1.0 ? ar : 1.0;
          h = ar >= 1.0 ? 1.0 : (1.0 / ar);
        }

        final bool swap = (totalRotate == 90 || totalRotate == 270);
        final double rw = swap ? h : w;
        final double rh = swap ? w : h;

        Widget video = SizedBox(
          width: rw,
          height: rh,
          child: Transform.rotate(
            angle: rotRad,
            alignment: Alignment.center,
            child: VideoPlayer(controller),
          ),
        );

        if (cropMode == 'fill' && cropScale != null && cropScale! > 1.0) {
          video = ClipRect(
            child: Transform.translate(
              offset: Offset(cropDx ?? 0, cropDy ?? 0),
              child: Transform.scale(
                scale: cropScale!,
                alignment: Alignment.center,
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    child: video,
                  ),
                ),
              ),
            ),
          );
        }

        if (!contain) {
          return SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: video,
            ),
          );
        }

        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: video,
          ),
        );
      },
    );
  }
}