import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'package:sportoteka/core/theme/app_typography.dart';

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

  String _normalizeMediaUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return 'https://sportotekaapp.ru$value';
    }
    return 'https://sportotekaapp.ru/$value';
  }

  TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
    double height = 1.2,
  }) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: height,
      letterSpacing: 0,
    );
  }

  Widget _dot(
    Color color, {
    double size = 5,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _brandDots({
    Color color = const Color(0xFF00A750),
  }) {
    const values = <List<double>>[
      <double>[3.0, .34],
      <double>[3.8, .48],
      <double>[4.6, .68],
      <double>[5.4, 1],
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < values.length; i++) ...[
          Container(
            width: values[i][0],
            height: values[i][0],
            decoration: BoxDecoration(
              color: color.withOpacity(values[i][1]),
              shape: BoxShape.circle,
            ),
          ),
          if (i != values.length - 1)
            const SizedBox(width: 3),
        ],
      ],
    );
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
            'video_url': _normalizeMediaUrl(video),
            'thumbnail': _normalizeMediaUrl(thumb),
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

      if (reels.isNotEmpty) {
        _currentPage = _currentPage.clamp(0, reels.length - 1).toInt();
      } else {
        _currentPage = 0;
      }

      if (!mounted) return;
      setState(() => loading = false);

      if (reels.isNotEmpty) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
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
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00A750),
                strokeWidth: 2,
              ),
            )
          : reels.isEmpty
              ? Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _brandDots(),
                      const SizedBox(width: 8),
                      Text(
                        'Пока нет Reels',
                        style: _t(
                          10.4,
                          color: Colors.white70,
                        ),
                      ),
                    ],
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
                        _currentPage = index;

                        await _ensureController(
                          index,
                          autoplay: true,
                        );
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
                            if (controller != null &&
                                controller.value.isInitialized)
                              GestureDetector(
                                onTap: () {
                                  controller.value.isPlaying
                                      ? controller.pause()
                                      : controller.play();
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
                                  if ((reel['thumbnail'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                                    Image.network(
                                      reel['thumbnail'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(),
                                    ),
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF00A750),
                                      strokeWidth: 2,
                                    ),
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
                                        Colors.black.withOpacity(.30),
                                        Colors.transparent,
                                        Colors.black.withOpacity(.76),
                                      ],
                                      stops: const [0, .48, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 34,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if ((reel['description'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      (reel['description'] ?? '').toString(),
                                      style: _t(
                                        10.7,
                                        color: Colors.white,
                                        height: 1.3,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 9),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _metric(
                                        '${reel['likes'] ?? 0}',
                                        const Color(0xFFD92D20),
                                      ),
                                      _metric(
                                        '${reel['comments'] ?? 0}',
                                        const Color(0xFF00A750),
                                      ),
                                      _metric(
                                        '${reel['views'] ?? 0}',
                                        const Color(0xFFF59E0B),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (controller != null &&
                                controller.value.isInitialized &&
                                !controller.value.isPlaying)
                              Center(
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(.28),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            10,
                            8,
                            12,
                            8,
                          ),
                          child: Row(
                            children: [
                              Material(
                                color: Colors.black.withOpacity(.26),
                                borderRadius: BorderRadius.circular(9),
                                child: InkWell(
                                  onTap: () => Navigator.maybePop(context),
                                  borderRadius: BorderRadius.circular(9),
                                  child: const SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),
                              _brandDots(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _t(
                                    11.6,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _metric(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.28),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(
            color,
            size: 4.5,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: _t(
              9.3,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

}
