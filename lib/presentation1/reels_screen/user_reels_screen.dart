import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class UserReelsScreen extends StatefulWidget {
  final int userId;
  final int initialIndex;
  final String title;

  const UserReelsScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
    this.title = "Reels пользователя",
  });

  @override
  State<UserReelsScreen> createState() => _UserReelsScreenState();
}

class _UserReelsScreenState extends State<UserReelsScreen> {
  List<Map<String, dynamic>> reels = [];
  bool loading = true;

  late PageController _pageController;
  int _currentPage = 0;

  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initializing = {};

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _fetchUserReels();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString().replaceAll(RegExp('[^0-9]'), '')) ?? 0;
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

          final String video =
              (m['video_url'] ?? m['video'] ?? m['url'] ?? m['src'] ?? '')
                  .toString()
                  .trim();

          String thumb =
              (m['thumbnail'] ?? m['thumb'] ?? m['poster'] ?? '').toString().trim();
          if (thumb.isEmpty && m['preview'] != null) thumb = m['preview'].toString().trim();

          return {
            'id': _toInt(m['id'] ?? m['reel_id'] ?? 0),
            'user_id': _toInt(m['user_id'] ?? m['author_id'] ?? 0),
            'video_url': video,
            'thumbnail': thumb,
            'username': (m['username'] ?? '').toString(),
            'user_avatar': (m['user_avatar'] ?? '').toString(),
            'description': (m['description'] ?? m['caption'] ?? '').toString(),
            'likes': _toInt(m['likes'] ?? m['like_count'] ?? 0),
            'comments': _toInt(m['comments'] ?? m['comment_count'] ?? 0),
            'views': _toInt(m['views'] ?? m['view_count'] ?? 0),
            '_raw': m,
          };
        })
        .where((e) => (e['video_url'] as String).isNotEmpty)
        .toList();
  }

  Future<void> _fetchUserReels() async {
    setState(() => loading = true);

    try {
      final url = Uri.parse(
        "https://sportotekaapp.ru/api/get_reels.php?limit=200&offset=0&user_id=${widget.userId}",
      );

      final resp = await http.get(url);
      if (resp.statusCode != 200) {
        if (mounted) setState(() => loading = false);
        return;
      }

      final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      final jsonAny = json.decode(body);

      final parsed = _parseReels(jsonAny);

      // ✅ на всякий — фильтруем именно по userId (если сервер не фильтрует)
      reels = parsed.where((m) => (m['user_id'] ?? 0) == widget.userId).toList();

      if (!mounted) return;
      setState(() => loading = false);

      if (reels.isNotEmpty) {
        await _ensureController(_currentPage, autoplay: true);
        _ensureController(_currentPage + 1);
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

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

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0);
      _controllers[index] = controller;

      if (!mounted) return;
      if (autoplay && index == _currentPage) controller.play();
      setState(() {});
    } finally {
      _initializing.remove(index);
    }
  }

  void _trimControllersKeepAround(int center) {
    final toKeep = {center - 1, center, center + 1};
    final keys = _controllers.keys.toList();
    for (final k in keys) {
      if (!toKeep.contains(k)) {
        _controllers.remove(k)?.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : (reels.isEmpty
              ? const Center(
                  child: Text("Пока нет Reels", style: TextStyle(color: Colors.white70)),
                )
              : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: reels.length,
                  onPageChanged: (index) async {
                    _currentPage = index;

                    await _ensureController(index, autoplay: true);
                    _ensureController(index + 1);
                    _ensureController(index - 1);

                    _controllers.forEach((i, c) {
                      if (i == index) {
                        if (!c.value.isPlaying) c.play();
                      } else {
                        if (c.value.isPlaying) c.pause();
                      }
                    });

                    _trimControllersKeepAround(index);
                    if (mounted) setState(() {});
                  },
                  itemBuilder: (context, index) {
                    final reel = reels[index];
                    final controller = _controllers[index];

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // видео / превью
                        if (controller != null && controller.value.isInitialized)
                          GestureDetector(
                            onTap: () {
                              controller.value.isPlaying ? controller.pause() : controller.play();
                              setState(() {});
                            },
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: controller.value.size.width,
                                height: controller.value.size.height,
                                child: VideoPlayer(controller),
                              ),
                            ),
                          )
                        else
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              if ((reel['thumbnail'] ?? '').toString().trim().isNotEmpty)
                                Image.network(
                                  reel['thumbnail'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(),
                                ),
                              const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            ],
                          ),

                        // градиент
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.25),
                                  Colors.black.withOpacity(0.75),
                                ],
                                stops: const [0.0, 0.6, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // описание
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 40,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (reel['description'] ?? '').toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.25),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _pill("${reel['likes'] ?? 0} ❤"),
                                  const SizedBox(width: 8),
                                  _pill("${reel['comments'] ?? 0} 💬"),
                                  const SizedBox(width: 8),
                                  _pill("${reel['views'] ?? 0} 👁"),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                )),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}
