import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import '../../data/models/video_lesson_comment_model.dart';
import '../../data/models/video_lesson_model.dart';
import '../../data/services/video_lessons_service.dart';
import 'add_edit_video_lesson_screen.dart';

class VideoLessonDetailPalette {
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

class VideoLessonDetailScreen extends StatefulWidget {
  final int lessonId;

  const VideoLessonDetailScreen({
    super.key,
    required this.lessonId,
  });

  @override
  State<VideoLessonDetailScreen> createState() =>
      _VideoLessonDetailScreenState();
}

class _VideoLessonDetailScreenState extends State<VideoLessonDetailScreen>
    with WidgetsBindingObserver {
  VideoLessonModel? lesson;
  List<VideoLessonCommentModel> comments = [];
  VideoPlayerController? _videoController;
  final TextEditingController commentController = TextEditingController();

  bool isLoading = true;
  bool isCommentLoading = false;
  bool _isFullScreen = false;
  bool _isRefreshing = false;
  int userId = 0;

  bool get isOwner => lesson != null && lesson!.userId == userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!_isFullScreen) {
      _exitFullScreen();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreSystemUi();
    _videoController?.dispose();
    commentController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final id = await PrefUtils.getUserId();
    userId = id ?? 0;
    await _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        if (lesson == null) isLoading = true;
        _isRefreshing = true;
      });
    }

    try {
      final lessonData = await VideoLessonsService.getLessonDetail(
        lessonId: widget.lessonId,
      );

      final commentsData = await VideoLessonsService.getComments(
        lessonId: widget.lessonId,
      );

      if (_videoController != null) {
        await _videoController!.dispose();
        _videoController = null;
      }

      if (lessonData != null && lessonData.videoUrl.isNotEmpty) {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(lessonData.videoUrl),
        );
        await controller.initialize();
        await controller.setLooping(false);
        _videoController = controller;
      }

      lesson = lessonData;
      comments = commentsData;
    } catch (e) {
      debugPrint('VideoLessonDetailScreen _loadData error: $e');
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
      _isRefreshing = false;
    });
  }

  void _restoreSystemUi() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _enterFullScreen() {
    setState(() {
      _isFullScreen = true;
    });

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullScreen() {
    if (!_isFullScreen) return;

    setState(() {
      _isFullScreen = false;
    });

    _restoreSystemUi();
  }

  Future<void> _sendComment() async {
    final text = commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => isCommentLoading = true);

    try {
      final success = await VideoLessonsService.addComment(
        lessonId: widget.lessonId,
        userId: userId,
        comment: text,
      );

      if (success) {
        commentController.clear();
        comments = await VideoLessonsService.getComments(
          lessonId: widget.lessonId,
        );
      }
    } catch (e) {
      debugPrint('VideoLessonDetailScreen _sendComment error: $e');
    }

    if (!mounted) return;
    setState(() => isCommentLoading = false);
  }

 Future<void> _editLesson() async {
  final l = lesson;
  if (l == null) return;

  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddEditVideoLessonScreen(
        folderId: l.folderId,
        userId: l.userId,
        lessonId: l.id,
        initialTitle: l.title,
        initialDescription: l.description,
        initialDuration: l.duration,
      ),
    ),
  );

  if (result == true) {
    await _loadData();
  }
}

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  String _getDayWord(int days) {
    if (days % 10 == 1 && days % 100 != 11) {
      return 'день';
    } else if (days % 10 >= 2 &&
        days % 10 <= 4 &&
        (days % 100 < 10 || days % 100 >= 20)) {
      return 'дня';
    } else {
      return 'дней';
    }
  }

  String _formatCommentTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return '';
    }

    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ${_getDayWord(difference.inDays)} назад';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ч назад';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} мин назад';
      } else {
        return 'только что';
      }
    } catch (_) {
      return dateTimeString;
    }
  }

  Widget _whiteCard({
    required Widget child,
    EdgeInsets? padding,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VideoLessonDetailPalette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VideoLessonDetailPalette.border),
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
              color: VideoLessonDetailPalette.text,
            ),
          ),
        ),
        if (action != null)
          Text(
            action,
            style: const TextStyle(
              color: VideoLessonDetailPalette.textMuted,
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
        color: VideoLessonDetailPalette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: VideoLessonDetailPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: VideoLessonDetailPalette.primaryGreen,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: VideoLessonDetailPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: VideoLessonDetailPalette.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VideoLessonDetailPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: VideoLessonDetailPalette.greenGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: VideoLessonDetailPalette.primaryGreen.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 52,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBlock() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return _buildVideoPlaceholder();
    }

    return GestureDetector(
      onTap: _enterFullScreen,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.45),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: _enterFullScreen,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.38),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.16),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (_videoController!.value.isPlaying) {
                                  _videoController!.pause();
                                } else {
                                  _videoController!.play();
                                }
                              });
                            },
                            icon: Icon(
                              _videoController!.value.isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              _videoController!,
                              allowScrubbing: true,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              colors: VideoProgressColors(
                                playedColor:
                                    VideoLessonDetailPalette.primaryGreen,
                                bufferedColor: Colors.white.withOpacity(0.45),
                                backgroundColor: Colors.white.withOpacity(0.18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.26),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _formatDuration(_videoController!.value.position),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildFullScreenVideo() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          Positioned(
            top: 28,
            left: 16,
            child: IconButton(
              onPressed: _exitFullScreen,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.14),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (_videoController!.value.isPlaying) {
                              _videoController!.pause();
                            } else {
                              _videoController!.play();
                            }
                          });
                        },
                        icon: Icon(
                          _videoController!.value.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          _videoController!,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor:
                                VideoLessonDetailPalette.primaryGreen,
                            bufferedColor: Colors.white.withOpacity(0.35),
                            backgroundColor: Colors.white.withOpacity(0.12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_formatDuration(_videoController!.value.position)} / ${_formatDuration(_videoController!.value.duration)}',
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(VideoLessonModel currentLesson) {
    final authorFullName =
        '${currentLesson.authorName} ${currentLesson.authorSurname}'.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            VideoLessonDetailPalette.primaryGreen.withOpacity(0.12),
            VideoLessonDetailPalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VideoLessonDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: VideoLessonDetailPalette.greenGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.ondemand_video_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Видеоурок',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: VideoLessonDetailPalette.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Просмотр урока, описание и комментарии',
                      style: TextStyle(
                        color: VideoLessonDetailPalette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (currentLesson.duration.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: VideoLessonDetailPalette.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: VideoLessonDetailPalette.border),
                  ),
                  child: Text(
                    currentLesson.duration,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: VideoLessonDetailPalette.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currentLesson.title,
            style: const TextStyle(
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: VideoLessonDetailPalette.text,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(Icons.person_rounded, authorFullName.isEmpty
                  ? 'Автор'
                  : authorFullName),
              _metricChip(Icons.comment_rounded, 'Комментарии ${comments.length}'),
              if (currentLesson.duration.isNotEmpty)
                _metricChip(Icons.timer_rounded, currentLesson.duration),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorCard(VideoLessonModel currentLesson) {
    final authorFullName =
        '${currentLesson.authorName} ${currentLesson.authorSurname}'.trim();

    return _whiteCard(
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: VideoLessonDetailPalette.border,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundImage: currentLesson.authorAvatar.isNotEmpty
                  ? NetworkImage(currentLesson.authorAvatar)
                  : null,
              backgroundColor: VideoLessonDetailPalette.lightGreen,
              child: currentLesson.authorAvatar.isEmpty
                  ? const Icon(
                      Icons.person,
                      color: VideoLessonDetailPalette.primaryGreen,
                      size: 28,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Автор урока',
                  style: TextStyle(
                    fontSize: 12,
                    color: VideoLessonDetailPalette.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authorFullName.isEmpty ? 'Неизвестный автор' : authorFullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: VideoLessonDetailPalette.text,
                  ),
                ),
              ],
            ),
          ),
          if (currentLesson.duration.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: VideoLessonDetailPalette.superLightGreen,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: VideoLessonDetailPalette.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: VideoLessonDetailPalette.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentLesson.duration,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: VideoLessonDetailPalette.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(VideoLessonModel currentLesson) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Описание'),
          const SizedBox(height: 10),
          Text(
            currentLesson.description.trim().isEmpty
                ? 'Описание пока не добавлено'
                : currentLesson.description,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: VideoLessonDetailPalette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Добавить комментарий'),
          const SizedBox(height: 12),
          TextField(
            controller: commentController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Написать комментарий...',
              hintStyle: const TextStyle(
                color: VideoLessonDetailPalette.textMuted,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: VideoLessonDetailPalette.background,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: VideoLessonDetailPalette.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: VideoLessonDetailPalette.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: VideoLessonDetailPalette.primaryGreen,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: VideoLessonDetailPalette.greenGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ElevatedButton.icon(
              onPressed: isCommentLoading ? null : _sendComment,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isCommentLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                isCommentLoading
                    ? 'Отправка...'
                    : 'Отправить комментарий',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCommentsCard() {
    return _whiteCard(
      child: Column(
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 34,
            color: VideoLessonDetailPalette.textMuted,
          ),
          const SizedBox(height: 10),
          const Text(
            'Комментариев пока нет',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: VideoLessonDetailPalette.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Будьте первым, кто оставит комментарий.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VideoLessonDetailPalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(VideoLessonCommentModel comment) {
    final authorFullName =
        '${comment.authorName} ${comment.authorSurname}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _whiteCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: comment.authorAvatar.isNotEmpty
                  ? NetworkImage(comment.authorAvatar)
                  : null,
              backgroundColor: VideoLessonDetailPalette.lightGreen,
              child: comment.authorAvatar.isEmpty
                  ? const Icon(
                      Icons.person,
                      color: VideoLessonDetailPalette.primaryGreen,
                      size: 22,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          authorFullName.isEmpty
                              ? 'Пользователь'
                              : authorFullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            color: VideoLessonDetailPalette.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCommentTime(comment.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: VideoLessonDetailPalette.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment.comment,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: VideoLessonDetailPalette.text,
                      fontWeight: FontWeight.w700,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(w: 170, h: 16),
          const SizedBox(height: 12),
          bar(w: double.infinity),
          const SizedBox(height: 8),
          bar(w: 220),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(w: 120),
                  const SizedBox(height: 8),
                  bar(w: 80, h: 9),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _whiteCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.video_library_rounded,
                size: 54,
                color: VideoLessonDetailPalette.textMuted,
              ),
              SizedBox(height: 12),
              Text(
                'Урок не найден',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: VideoLessonDetailPalette.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen && _videoController != null) {
      return _buildFullScreenVideo();
    }

    final currentLesson = lesson;

    return Scaffold(
      backgroundColor: VideoLessonDetailPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: VideoLessonDetailPalette.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: const Text(
          'Видеоурок',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: VideoLessonDetailPalette.text,
            fontSize: 16,
          ),
        ),
        actions: [
          if (isOwner)
            IconButton(
              tooltip: 'Редактировать',
              onPressed: _editLesson,
              icon: Container(
                decoration: BoxDecoration(
                  gradient: VideoLessonDetailPalette.greenGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.edit_rounded, color: Colors.white),
              ),
            ),
          if (isOwner) const SizedBox(width: 10),
        ],
      ),
      body: isLoading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                _buildVideoPlaceholder(),
                const SizedBox(height: 12),
                _buildSkeletonCard(),
                const SizedBox(height: 12),
                _buildSkeletonCard(),
              ],
            )
          : currentLesson == null
              ? _buildNotFoundState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: VideoLessonDetailPalette.primaryGreen,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      _buildVideoBlock(),
                      const SizedBox(height: 12),
                      _buildHeaderCard(currentLesson),
                      const SizedBox(height: 12),
                      _buildAuthorCard(currentLesson),
                      const SizedBox(height: 12),
                      _buildDescriptionCard(currentLesson),
                      const SizedBox(height: 12),
                      _buildCommentInputCard(),
                      const SizedBox(height: 12),
                      _sectionTitle(
                        'Комментарии',
                        action: '${comments.length}',
                      ),
                      const SizedBox(height: 8),
                      if (comments.isEmpty)
                        _buildEmptyCommentsCard()
                      else
                        ...comments.map(_buildCommentCard),
                      if (_isRefreshing)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: VideoLessonDetailPalette.primaryGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}