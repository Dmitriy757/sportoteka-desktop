import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import '../../data/models/video_lesson_comment_model.dart';
import '../../data/models/video_lesson_model.dart';
import '../../data/services/video_lessons_service.dart';
import 'add_edit_video_lesson_screen.dart';
import 'cmr_video_lessons_theme.dart';

class VideoLessonDetailPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = CmrVideoColors.greenDark;
  static const primaryGreenSoft = CmrVideoColors.greenSoft;

  static const white = Color(0xFFFFFFFF);

  /// Общий фон страницы — белый, как просили.
  static const background = CmrVideoColors.panel;

  /// Мягкий внутренний фон для полей, комментариев и пустых состояний.
  static const surface = CmrVideoColors.soft;

  static const card = Color(0xFFFFFFFF);
  static const border = Colors.transparent;

  static const text = CmrVideoColors.text;
  static const textMuted = CmrVideoColors.muted;
  static const textLight = CmrVideoColors.subtle;

  static const videoBlack = Color(0xFF050505);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class VideoLessonDetailScreen extends StatefulWidget {
  final int lessonId;

  /// Если экран открыт из хаба по нажатию на карточку,
  /// видео сразу начинает проигрываться как в YouTube/Rutube.
  final bool autoPlay;
  final bool embedded;

  const VideoLessonDetailScreen({
    super.key,
    required this.lessonId,
    this.autoPlay = false,
    this.embedded = false,
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

  bool get _hasReadyVideo =>
      _videoController != null && _videoController!.value.isInitialized;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Не сбрасываем ориентацию здесь, чтобы после fullscreen планшет
    // нормально возвращался к текущему положению.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreSystemUi();
    _videoController?.removeListener(_videoTick);
    _videoController?.dispose();
    commentController.dispose();
    super.dispose();
  }

  Widget _withStableTextScale(Widget child) {
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(1.0).clamp(1.0, 1.06).toDouble();

    return CmrVideoThemeScope(
      child: MediaQuery(
        data: media.copyWith(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    );
  }

  void _videoTick() {
    if (!mounted) return;
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {});
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
        _videoController!.removeListener(_videoTick);
        await _videoController!.dispose();
        _videoController = null;
      }

      if (lessonData != null && lessonData.videoUrl.isNotEmpty) {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(lessonData.videoUrl),
        );

        controller.addListener(_videoTick);
        await controller.initialize();
        await controller.setLooping(false);

        if (widget.autoPlay) {
          await controller.play();
        }

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

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _enterFullScreen() async {
    if (_isFullScreen || !_hasReadyVideo) return;

    if (mounted) {
      setState(() => _isFullScreen = true);
    }

    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitFullScreen() async {
    if (!_isFullScreen) return;

    if (mounted) {
      setState(() => _isFullScreen = false);
    }

    await _restoreSystemUi();
  }

  void _togglePlay() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
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
    }

    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
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
    if (dateTimeString == null || dateTimeString.isEmpty) return '';

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

  String _authorName(VideoLessonModel item) {
    final fullName = '${item.authorName} ${item.authorSurname}'.trim();
    return fullName.isEmpty ? 'Автор урока' : fullName;
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    Color color = VideoLessonDetailPalette.card,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(
    String title, {
    String? counter,
    IconData? icon,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          const CmrVideoDot(size: 7),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Text(
            title,
            style: CmrVideoText.title(17),
          ),
        ),
        if (counter != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: VideoLessonDetailPalette.primaryGreenSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              counter,
              style: CmrVideoText.chip(
                color: VideoLessonDetailPalette.primaryGreen,
                active: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip({
    required IconData icon,
    required String text,
    Color color = VideoLessonDetailPalette.primaryGreen,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.transparent, width: 0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: CmrVideoText.chip(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarTitle(VideoLessonModel? currentLesson) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CmrVideoDot(size: 7),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            currentLesson?.title.trim().isNotEmpty == true
                ? currentLesson!.title
                : 'Видеоурок',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CmrVideoText.title(16),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlaceholder() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: VideoLessonDetailPalette.videoBlack,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: VideoLessonDetailPalette.greenGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: VideoLessonDetailPalette.primaryGreen.withOpacity(0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
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
      ),
    );
  }

  Widget _buildVideoSurface({
    required bool compactControls,
    required bool fullScreenMode,
  }) {
    if (!_hasReadyVideo) {
      return _buildVideoPlaceholder();
    }

    final controller = _videoController!;
    final value = controller.value;

    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: VideoLessonDetailPalette.videoBlack,
          borderRadius:
              fullScreenMode ? BorderRadius.zero : BorderRadius.circular(24),
          boxShadow: fullScreenMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius:
              fullScreenMode ? BorderRadius.zero : BorderRadius.circular(24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio:
                      value.aspectRatio <= 0 ? 16 / 9 : value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.12),
                          Colors.transparent,
                          Colors.black.withOpacity(0.58),
                        ],
                        stops: const [0.0, 0.48, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              if (!value.isPlaying)
                Container(
                  width: fullScreenMode ? 86 : 76,
                  height: fullScreenMode ? 86 : 76,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.46),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.22),
                    ),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: fullScreenMode ? 58 : 50,
                  ),
                ),
              Positioned(
                top: fullScreenMode ? 24 : 14,
                right: fullScreenMode ? 24 : 14,
                child: Row(
                  children: [
                    if (!fullScreenMode)
                      _videoCircleButton(
                        icon: Icons.fullscreen_rounded,
                        onTap: _enterFullScreen,
                      ),
                    if (fullScreenMode)
                      _videoCircleButton(
                        icon: Icons.close_rounded,
                        onTap: _exitFullScreen,
                        iconSize: 28,
                      ),
                  ],
                ),
              ),
              Positioned(
                left: fullScreenMode ? 24 : 14,
                right: fullScreenMode ? 24 : 14,
                bottom: fullScreenMode ? 24 : 14,
                child: _buildVideoControls(
                  controller: controller,
                  compact: compactControls,
                  fullScreenMode: fullScreenMode,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 22,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.44),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoControls({
    required VideoPlayerController controller,
    required bool compact,
    required bool fullScreenMode,
  }) {
    final value = controller.value;
    final position = _formatDuration(value.position);
    final duration = _formatDuration(value.duration);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.38),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.13)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: _togglePlay,
                borderRadius: BorderRadius.circular(999),
                child: Icon(
                  value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: compact ? 36 : 42,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  colors: VideoProgressColors(
                    playedColor: VideoLessonDetailPalette.primaryGreen,
                    bufferedColor: Colors.white.withOpacity(0.38),
                    backgroundColor: Colors.white.withOpacity(0.16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                compact ? position : '$position / $duration',
                style: CmrVideoText.body(
                  compact ? 11.0 : 12.0,
                  color: Colors.white,
                  weight: FontWeight.w500,
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
      body: SafeArea(
        child: Center(
          child: _buildVideoSurface(
            compactControls: false,
            fullScreenMode: true,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBlock(bool isPhone) {
    return _buildVideoSurface(
      compactControls: isPhone,
      fullScreenMode: false,
    );
  }

  Widget _buildLessonInfo(VideoLessonModel currentLesson) {
    final authorFullName = _authorName(currentLesson);

    return _card(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentLesson.title.trim().isEmpty
                ? 'Без названия'
                : currentLesson.title,
            style: CmrVideoText.title(17),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                icon: Icons.person_rounded,
                text: authorFullName,
              ),
              _chip(
                icon: Icons.mode_comment_rounded,
                text: '${comments.length} коммент.',
              ),
              if (currentLesson.duration.trim().isNotEmpty)
                _chip(
                  icon: Icons.schedule_rounded,
                  text: currentLesson.duration,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: currentLesson.authorAvatar.isNotEmpty
                    ? NetworkImage(currentLesson.authorAvatar)
                    : null,
                backgroundColor: VideoLessonDetailPalette.primaryGreenSoft,
                child: currentLesson.authorAvatar.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: VideoLessonDetailPalette.primaryGreen,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorFullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CmrVideoText.title(15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Автор видеоурока',
                      style: CmrVideoText.secondary(
                        color: VideoLessonDetailPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _editLesson,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: VideoLessonDetailPalette.primaryGreenSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: VideoLessonDetailPalette.primaryGreen
                              .withOpacity(0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 17,
                            color: VideoLessonDetailPalette.primaryGreen,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Изменить',
                            style: CmrVideoText.action(
                              VideoLessonDetailPalette.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(VideoLessonModel currentLesson) {
    final description = currentLesson.description.trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Описание',
            icon: Icons.notes_rounded,
          ),
          const SizedBox(height: 12),
          Text(
            description.isEmpty
                ? 'Описание пока не добавлено. Здесь можно указать цель урока, ключевые моменты, технику выполнения и рекомендации тренера.'
                : description,
            style: CmrVideoText.body(
              13,
              color: description.isEmpty
                  ? VideoLessonDetailPalette.textMuted
                  : VideoLessonDetailPalette.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputCard() {
    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Комментарий',
            icon: Icons.add_comment_rounded,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentController,
            style: CmrVideoText.formText(
              color: VideoLessonDetailPalette.text,
            ),
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Написать комментарий...',
              hintStyle: CmrVideoText.formHint(
                color: VideoLessonDetailPalette.textLight,
              ),
              filled: true,
              fillColor: VideoLessonDetailPalette.surface,
              contentPadding: const EdgeInsets.all(14),
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
          SizedBox(
            width: double.infinity,
            height: 46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: VideoLessonDetailPalette.greenGradient,
                borderRadius: BorderRadius.circular(15),
              ),
              child: ElevatedButton.icon(
                onPressed: isCommentLoading ? null : _sendComment,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
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
                    : const Icon(Icons.send_rounded, size: 19),
                label: Text(
                  isCommentLoading ? 'Отправка...' : 'Отправить',
                  style: CmrVideoText.action(Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Комментарии',
            counter: '${comments.length}',
            icon: Icons.forum_rounded,
          ),
          const SizedBox(height: 12),
          if (comments.isEmpty)
            _buildEmptyComments()
          else
            ...comments.map(_buildCommentItem),
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Center(
                child: CircularProgressIndicator(
                  color: VideoLessonDetailPalette.primaryGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyComments() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      decoration: BoxDecoration(
        color: VideoLessonDetailPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.transparent, width: 0),
      ),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: VideoLessonDetailPalette.textMuted,
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            'Комментариев пока нет',
            style: CmrVideoText.emptyTitle(
              color: VideoLessonDetailPalette.text,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Оставьте первый комментарий к видеоуроку.',
            textAlign: TextAlign.center,
            style: CmrVideoText.emptyText(
              color: VideoLessonDetailPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(VideoLessonCommentModel comment) {
    final authorFullName =
        '${comment.authorName} ${comment.authorSurname}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VideoLessonDetailPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.transparent, width: 0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundImage: comment.authorAvatar.isNotEmpty
                ? NetworkImage(comment.authorAvatar)
                : null,
            backgroundColor: VideoLessonDetailPalette.primaryGreenSoft,
            child: comment.authorAvatar.isEmpty
                ? const Icon(
                    Icons.person_rounded,
                    color: VideoLessonDetailPalette.primaryGreen,
                    size: 22,
                  )
                : null,
          ),
          const SizedBox(width: 11),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CmrVideoText.commentAuthor(
                          color: VideoLessonDetailPalette.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatCommentTime(comment.createdAt),
                      style: CmrVideoText.commentMeta(
                        color: VideoLessonDetailPalette.textLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  comment.comment,
                  style: CmrVideoText.commentText(
                    color: VideoLessonDetailPalette.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonPage() {
    Widget bar({
      double? width,
      double height = 12,
      BorderRadius? radius,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: radius ?? BorderRadius.circular(999),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _buildVideoPlaceholder(),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(width: 260, height: 22),
              const SizedBox(height: 12),
              bar(width: double.infinity),
              const SizedBox(height: 8),
              bar(width: 220),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(width: 150),
                      const SizedBox(height: 8),
                      bar(width: 100, height: 10),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(width: 160, height: 18),
              const SizedBox(height: 14),
              bar(width: double.infinity),
              const SizedBox(height: 8),
              bar(width: double.infinity),
              const SizedBox(height: 8),
              bar(width: 180),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_library_rounded,
                size: 54,
                color: VideoLessonDetailPalette.textMuted,
              ),
              SizedBox(height: 12),
              Text(
                'Урок не найден',
                style: CmrVideoText.emptyTitle(
                  color: VideoLessonDetailPalette.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(VideoLessonModel currentLesson) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVideoBlock(true),
        const SizedBox(height: 12),
        _buildLessonInfo(currentLesson),
        const SizedBox(height: 12),
        _buildDescriptionCard(currentLesson),
        const SizedBox(height: 12),
        _buildCommentInputCard(),
        const SizedBox(height: 12),
        _buildCommentsSection(),
      ],
    );
  }

  Widget _buildWideLayout(VideoLessonModel currentLesson) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVideoBlock(false),
              const SizedBox(height: 14),
              _buildLessonInfo(currentLesson),
              const SizedBox(height: 14),
              _buildDescriptionCard(currentLesson),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildCommentInputCard(),
              const SizedBox(height: 14),
              _buildCommentsSection(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen && _hasReadyVideo) {
      return _withStableTextScale(
        WillPopScope(
          onWillPop: () async {
            await _exitFullScreen();
            return false;
          },
          child: _buildFullScreenVideo(),
        ),
      );
    }

    final currentLesson = lesson;

    return _withStableTextScale(
      WillPopScope(
        onWillPop: () async {
          await _restoreSystemUi();
          return true;
        },
        child: Scaffold(
          backgroundColor: VideoLessonDetailPalette.background,
          appBar: widget.embedded ? null : AppBar(
            elevation: 0,
            backgroundColor: VideoLessonDetailPalette.white,
            surfaceTintColor: Colors.transparent,
            foregroundColor: VideoLessonDetailPalette.text,
            centerTitle: false,
            titleSpacing: 0,
            title: _buildTopBarTitle(currentLesson),
            actions: [
              if (isOwner)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: IconButton(
                    tooltip: 'Редактировать',
                    onPressed: _editLesson,
                    icon: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: CmrVideoColors.greenSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: CmrVideoColors.greenDark,
                        size: 17,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: isLoading
              ? _buildSkeletonPage()
              : currentLesson == null
                  ? _buildNotFoundState()
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: VideoLessonDetailPalette.primaryGreen,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final isWide = width >= 980;
                          final isPhone = width < 640;

                          final pagePadding = widget.embedded
                              ? const EdgeInsets.fromLTRB(16, 14, 16, 22)
                              : isWide
                              ? const EdgeInsets.fromLTRB(24, 18, 24, 30)
                              : isPhone
                                  ? const EdgeInsets.fromLTRB(12, 10, 12, 22)
                                  : const EdgeInsets.fromLTRB(18, 14, 18, 26);

                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: pagePadding,
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 1360),
                                child: isWide
                                    ? _buildWideLayout(currentLesson)
                                    : _buildMobileLayout(currentLesson),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}