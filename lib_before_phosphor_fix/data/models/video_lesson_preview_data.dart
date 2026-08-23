import 'video_lesson_model.dart';

class VideoLessonPreviewData {
  final VideoLessonModel lesson;
  final int folderId;
  final String folderTitle;
  final String folderColor;
  final int? parentId;

  const VideoLessonPreviewData({
    required this.lesson,
    required this.folderId,
    required this.folderTitle,
    required this.folderColor,
    required this.parentId,
  });
}