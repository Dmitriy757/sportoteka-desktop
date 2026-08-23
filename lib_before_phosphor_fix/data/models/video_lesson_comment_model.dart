class VideoLessonCommentModel {
  final int id;
  final int lessonId;
  final int userId;
  final String comment;
  final String? createdAt;
  final String authorName;
  final String authorSurname;
  final String authorAvatar;

  VideoLessonCommentModel({
    required this.id,
    required this.lessonId,
    required this.userId,
    required this.comment,
    this.createdAt,
    required this.authorName,
    required this.authorSurname,
    required this.authorAvatar,
  });

  factory VideoLessonCommentModel.fromJson(Map<String, dynamic> json) {
    return VideoLessonCommentModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      lessonId: int.tryParse(json['lesson_id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      comment: json['comment'] ?? '',
      createdAt: json['created_at'],
      authorName: json['name'] ?? '',
      authorSurname: json['surname'] ?? '',
      authorAvatar: json['avatar'] ?? '',
    );
  }
}