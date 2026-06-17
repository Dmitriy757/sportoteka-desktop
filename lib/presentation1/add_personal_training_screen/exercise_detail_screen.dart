import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final int exerciseId;
  final String title;
  final String image; // оставлено для совместимости, не используется
  final String? description;
  final int trainerId;
  final String? videoUrl;

  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
    required this.title,
    required this.image,
    this.description,
    required this.trainerId,
    this.videoUrl,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> videos = [];
  Map<int, List<dynamic>> comments = {};
  Map<int, int> commentIdToVideoId = {};

  bool loading = true;
  late AnimationController _animationController;

  final PageController _pageCtrl = PageController();
  int _currentIndex = 0;
  VideoPlayerController? _videoController;
  bool _isVideoLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    fetchVideos();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _disposeVideo();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchVideos() async {
    setState(() => loading = true);
    try {
      final userId = await PrefUtils.getUserId() ?? 0;
      final url =
          'https://sportotekaapp.ru/api/get_exercise_videos.php?exercise_id=${widget.exerciseId}&user_id=$userId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        videos = data;
        setState(() {});

        for (var v in data) {
          final videoId = int.parse(v['id'].toString());
          await fetchComments(videoId);
        }

        if (videos.isNotEmpty) {
          await _playIndex(0);
        }
      } else {
        Get.snackbar(
          "Ошибка",
          "Не удалось загрузить видео (${response.statusCode})",
        );
      }
    } catch (_) {
      Get.snackbar("Ошибка", "Не удалось загрузить видео");
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> fetchComments(int videoId) async {
    try {
      final url =
          'https://sportotekaapp.ru/api/get_video_comments.php?video_id=$videoId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> commentList = json.decode(response.body);
        setState(() {
          comments[videoId] = commentList;
          for (var c in commentList) {
            commentIdToVideoId[int.parse(c['id'].toString())] = videoId;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> likeComment(int commentId) async {
    try {
      final userId = await PrefUtils.getUserId();
      final url = 'https://sportotekaapp.ru/api/like_video_comment.php';
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'comment_id': commentId, 'user_id': userId}),
      );

      final videoId = commentIdToVideoId[commentId];
      if (videoId != null) {
        await fetchComments(videoId);
        setState(() {});
      }
    } catch (_) {}
  }

  void addVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final lower = picked.path.toLowerCase();
    final ok = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi');
    if (!ok) {
      Get.snackbar("Ошибка", "Поддерживаются: mp4, mov, m4v, webm, avi");
      return;
    }

    String description = '';

    await Get.dialog(
      FadeTransition(
        opacity: _animationController,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: FeedPalette.greenGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.video_library,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Добавить видео",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: FeedPalette.text,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Добавьте описание для обучающего видео",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FeedPalette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Краткое описание...',
                    hintStyle: const TextStyle(
                      color: FeedPalette.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: FeedPalette.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FeedPalette.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FeedPalette.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: FeedPalette.primaryGreen,
                        width: 1.4,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  onChanged: (val) => description = val,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FeedPalette.textMuted,
                          side: const BorderSide(color: FeedPalette.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Отмена",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: FeedPalette.greenGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            Get.back();
                            await uploadVideo(picked, description);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Загрузить",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> uploadVideo(XFile picked, String description) async {
    try {
      final userId = await PrefUtils.getUserId() ?? widget.trainerId;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://sportotekaapp.ru/api/add_exercise_video.php'),
      );

      request.fields['trainer_id'] = userId.toString();
      request.fields['exercise_id'] = widget.exerciseId.toString();
      request.fields['description'] = description;
      request.files.add(await http.MultipartFile.fromPath('video', picked.path));

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final jsonResp = jsonDecode(body);
        if (jsonResp is Map && jsonResp['success'] == true) {
          Get.snackbar(
            "Успешно",
            "Видео загружено",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          await fetchVideos();
        } else {
          final err = (jsonResp is Map && jsonResp['error'] != null)
              ? jsonResp['error'].toString()
              : 'Неизвестная ошибка';
          throw Exception(err);
        }
      } else {
        throw Exception('Код ${streamed.statusCode}');
      }
    } catch (e) {
      Get.snackbar(
        "Ошибка",
        "Не удалось загрузить видео: $e",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _openCommentsSheet(int videoId) async {
    if (comments[videoId] == null) {
      await fetchComments(videoId);
    }

    final TextEditingController textCtrl = TextEditingController();
    int rating = 5;
    bool sending = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FeedPalette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final list = comments[videoId] ?? [];

            Future<void> submit() async {
              if (sending) return;
              final text = textCtrl.text.trim();
              if (text.isEmpty) {
                Get.snackbar("Внимание", "Напишите комментарий");
                return;
              }
              setModalState(() => sending = true);
              try {
                final userId = await PrefUtils.getUserId();

                await http.post(
                  Uri.parse(
                    'https://sportotekaapp.ru/api/add_video_comment.php',
                  ),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'video_id': videoId,
                    'user_id': userId,
                    'comment': text,
                  }),
                );

                await http.post(
                  Uri.parse('https://sportotekaapp.ru/api/add_video_rating.php'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'video_id': videoId,
                    'user_id': userId,
                    'rating': rating,
                  }),
                );

                textCtrl.clear();
                await fetchComments(videoId);
                setModalState(() {});
              } catch (e) {
                Get.snackbar("Ошибка", "Не удалось отправить отзыв");
              } finally {
                setModalState(() => sending = false);
              }
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 6,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: FeedPalette.superLightGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                              color: FeedPalette.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Комментарии",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: FeedPalette.text,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${list.length}",
                            style: const TextStyle(
                              color: FeedPalette.textMuted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: list.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Пока нет комментариев — будьте первым!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: FeedPalette.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                              itemBuilder: (_, i) =>
                                  _buildCommentItem(list[i], insideSheet: true),
                              separatorBuilder: (_, __) => Divider(
                                height: 12,
                                color: Colors.grey.withOpacity(0.12),
                              ),
                              itemCount: list.length,
                            ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Column(
                        children: [
                          Row(
                            children: List.generate(5, (i) {
                              final filled = i < rating;
                              return IconButton(
                                icon: Icon(
                                  filled ? Icons.star : Icons.star_border,
                                  color: filled ? Colors.amber : Colors.grey,
                                  size: 22,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setModalState(() => rating = i + 1);
                                },
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: FeedPalette.white,
                                    border: Border.all(
                                      color: FeedPalette.border,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: TextField(
                                    controller: textCtrl,
                                    minLines: 1,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      hintText: 'Добавьте комментарий...',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: FeedPalette.greenGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton(
                                  onPressed: sending ? null : submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  child: sending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send,
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> likeVideo(int videoId) async {
    try {
      final userId = await PrefUtils.getUserId();
      final response = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/like_video.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'video_id': videoId, 'user_id': userId}),
      );
      if (response.statusCode == 200) {
        await fetchVideos();
        if (_currentIndex < videos.length) {
          await _playIndex(_currentIndex);
        }
      }
    } catch (_) {}
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= videos.length) return;
    _disposeVideo();

    final url = videos[index]['video_url'] as String;
    setState(() {
      _isVideoLoading = true;
      _currentIndex = index;
    });

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();

      setState(() {
        _videoController = controller;
        _isVideoLoading = false;
      });
    } catch (_) {
      setState(() => _isVideoLoading = false);
      Get.snackbar("Ошибка", "Не удалось воспроизвести видео");
    }
  }

  void _disposeVideo() {
    if (_videoController != null) {
      _videoController!.pause();
      _videoController!.dispose();
      _videoController = null;
    }
  }

  Widget _reelsPage(Map<String, dynamic> video, int index) {
    final videoId = int.parse(video['id'].toString());
    final double avgRating =
        double.tryParse(video['average_rating']?.toString() ?? '') ?? 0;
    final List<dynamic> videoComments = comments[videoId] ?? [];
    final bool isLiked = video['is_liked'] == true || video['is_liked'] == 1;
    final likeCount = video['like_count'] ?? video['likes'] ?? 0;

    final isCurrent = _currentIndex == index;
    final isReady = isCurrent && _videoController?.value.isInitialized == true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: isReady
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                : Container(
                    color: Colors.black,
                    child: Center(
                      child: _isVideoLoading && isCurrent
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Icon(
                              Icons.play_circle_fill,
                              size: 64,
                              color: Colors.white.withOpacity(0.9),
                            ),
                    ),
                  ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withOpacity(0.58),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 80,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (avgRating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  video['description'] ?? 'Без описания',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${video['first_name']} ${video['last_name']}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 24,
            child: Column(
              children: [
                _circleIconButton(
                  icon: isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: "$likeCount",
                  onTap: () => likeVideo(videoId),
                ),
                const SizedBox(height: 12),
                _circleIconButton(
                  icon: Icons.comment_outlined,
                  label: "${videoComments.length}",
                  onTap: () => _openCommentsSheet(videoId),
                ),
                const SizedBox(height: 12),
                _circleIconButton(
                  icon: Icons.share_outlined,
                  label: "Поделиться",
                  onTap: () => _shareVideo(video),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 64,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentItem(
    Map<String, dynamic> comment, {
    bool insideSheet = false,
  }) {
    final textColor = insideSheet ? FeedPalette.text : Colors.grey.shade100;
    final subColor = insideSheet ? Colors.black54 : Colors.grey.shade300;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        insideSheet ? 8 : 16,
        0,
        insideSheet ? 8 : 16,
        12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: FeedPalette.superLightGreen,
            child: const Icon(
              Icons.person_outline,
              size: 16,
              color: FeedPalette.primaryGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: insideSheet
                    ? FeedPalette.white
                    : Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
                border: insideSheet
                    ? Border.all(color: FeedPalette.border)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment['user_name'] ?? 'Аноним',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment['comment'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _timeAgo(comment['created_at']),
                        style: TextStyle(
                          fontSize: 11,
                          color: subColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 14),
                      InkWell(
                        onTap: () => likeComment(
                          int.parse(comment['id'].toString()),
                        ),
                        borderRadius: BorderRadius.circular(999),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.thumb_up_outlined,
                              size: 14,
                              color: insideSheet
                                  ? Colors.black87
                                  : Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${comment['likes'] ?? 0}",
                              style: TextStyle(
                                fontSize: 11,
                                color: subColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareVideo(Map<String, dynamic> video) async {
    try {
      final url = video['video_url'];
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      Get.snackbar(
        "Ошибка",
        "Не удалось поделиться видео",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String _timeAgo(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final d = now.difference(date);
      if (d.inDays > 365) return '${(d.inDays / 365).floor()} лет назад';
      if (d.inDays > 30) return '${(d.inDays / 30).floor()} мес. назад';
      if (d.inDays > 0) return '${d.inDays} дн. назад';
      if (d.inHours > 0) return '${d.inHours} ч. назад';
      if (d.inMinutes > 0) return '${d.inMinutes} мин. назад';
      return 'Только что';
    } catch (_) {
      return '';
    }
  }

  Widget _buildTopCard() {
    return Container(
      margin: const EdgeInsets.all(16),
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
            child: const Icon(Icons.fitness_center, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: FeedPalette.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.description ?? 'Описание упражнения отсутствует',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FeedPalette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        "ОБУЧАЮЩИЕ ВИДЕО",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: FeedPalette.textMuted,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FeedPalette.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: FeedPalette.text,
            fontSize: 16,
          ),
        ),
        backgroundColor: FeedPalette.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: FeedPalette.greenGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: FeedPalette.primaryGreen.withOpacity(0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: addVideo,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: FadeTransition(
        opacity: _animationController,
        child: Column(
          children: [
            _buildTopCard(),
            _buildSectionLabel(),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : videos.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Пока нет обучающих видео',
                            style: TextStyle(
                              color: FeedPalette.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: PageView.builder(
                              controller: _pageCtrl,
                              scrollDirection: Axis.vertical,
                              onPageChanged: (i) async {
                                await _playIndex(i);
                              },
                              itemCount: videos.length,
                              itemBuilder: (context, i) =>
                                  _reelsPage(videos[i], i),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

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