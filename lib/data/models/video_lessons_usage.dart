class VideoLessonsUsage {
  final int used;
  final int limit;
  final bool hasPaidAccess;
  final bool canCreate;

  const VideoLessonsUsage({
    required this.used,
    required this.limit,
    required this.hasPaidAccess,
    required this.canCreate,
  });

  factory VideoLessonsUsage.fromJson(Map<String, dynamic> json) {
    return VideoLessonsUsage(
      used: int.tryParse(json['used'].toString()) ?? 0,
      limit: int.tryParse(json['limit'].toString()) ?? 0,
      hasPaidAccess: json['has_paid_access'] == true,
      canCreate: json['can_create'] == true,
    );
  }
}