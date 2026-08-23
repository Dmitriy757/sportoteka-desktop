class VideoFolderModel {
  final int id;
  final int userId;
  final int? parentId;
  final String title;
  final String color;
  final String? banner;
  final int subfoldersCount;
  final int lessonsCount;
  final String? createdAt;

  VideoFolderModel({
    required this.id,
    required this.userId,
    required this.parentId,
    required this.title,
    required this.color,
    this.banner,
    required this.subfoldersCount,
    required this.lessonsCount,
    this.createdAt,
  });

  factory VideoFolderModel.fromJson(Map<String, dynamic> json) {
    return VideoFolderModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      parentId: json['parent_id'] == null
          ? null
          : int.tryParse(json['parent_id'].toString()),
      title: json['title'] ?? '',
      color: json['color'] ?? '#1976D2',
      banner: json['banner'],
      subfoldersCount: int.tryParse(json['subfolders_count'].toString()) ?? 0,
      lessonsCount: int.tryParse(json['lessons_count'].toString()) ?? 0,
      createdAt: json['created_at'],
    );
  }
}