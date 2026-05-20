class VideoLessonModel {
  final int id;
  final int folderId;
  final int userId;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnail;
  final String duration;
  final String? createdAt;
  final String? updatedAt;
  final String authorName;
  final String authorSurname;
  final String authorAvatar;
  final int commentsCount;

  VideoLessonModel({
    required this.id,
    required this.folderId,
    required this.userId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnail,
    required this.duration,
    this.createdAt,
    this.updatedAt,
    required this.authorName,
    required this.authorSurname,
    required this.authorAvatar,
    required this.commentsCount,
  });

  factory VideoLessonModel.fromJson(Map<String, dynamic> json) {
    return VideoLessonModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      folderId: int.tryParse(json['folder_id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: json['video_url'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      duration: json['duration'] ?? '',
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      authorName: json['name'] ?? '',
      authorSurname: json['surname'] ?? '',
      authorAvatar: json['avatar'] ?? '',
      commentsCount: int.tryParse(json['comments_count'].toString()) ?? 0,
    );
  }
}