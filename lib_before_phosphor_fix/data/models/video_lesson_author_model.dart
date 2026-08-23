class VideoLessonAuthorModel {
  final int id;
  final String name;
  final String surname;
  final String avatar;
  final double rating;
  final int foldersCount;
  final int lessonsCount;

  VideoLessonAuthorModel({
    required this.id,
    required this.name,
    required this.surname,
    required this.avatar,
    required this.rating,
    required this.foldersCount,
    required this.lessonsCount,
  });

  factory VideoLessonAuthorModel.fromJson(Map<String, dynamic> json) {
    return VideoLessonAuthorModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: (json['name'] ?? '').toString(),
      surname: (json['surname'] ?? '').toString(),
      avatar: (json['avatar'] ?? '').toString(),
      rating: double.tryParse(json['rating'].toString()) ?? 0.0,
      foldersCount: int.tryParse(json['folders_count'].toString()) ?? 0,
      lessonsCount: int.tryParse(json['lessons_count'].toString()) ?? 0,
    );
  }
}