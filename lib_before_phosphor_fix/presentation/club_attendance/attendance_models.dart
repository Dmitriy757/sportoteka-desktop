// lib/presentation/club_attendance/attendance_models.dart

class AttendanceEvent {
  final int id;
  final String title;
  final DateTime date;

  AttendanceEvent({
    required this.id,
    required this.title,
    required this.date,
  });

  static DateTime _parseDate(String s) {
    // ожидаем 'YYYY-MM-DD' или 'YYYY-MM-DD HH:mm:ss'
    final clean = s.trim();
    if (clean.isEmpty) return DateTime.now();
    return DateTime.tryParse(clean.replaceAll(' ', 'T')) ?? DateTime.now();
  }

  factory AttendanceEvent.fromJson(Map<String, dynamic> j) {
    return AttendanceEvent(
      id: int.tryParse((j["id"] ?? "0").toString()) ?? 0,
      title: (j["title"] ?? j["name"] ?? "").toString(),
      date: _parseDate((j["event_date"] ?? j["date"] ?? "").toString()),
    );
  }
}

class AttendancePlayer {
  final int id;
  final String firstName;
  final String lastName;
  final String? photo;

  AttendancePlayer({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
  });

  String get fullName {
    final n = ("$lastName $firstName").trim();
    return n.isEmpty ? "Игрок #$id" : n;
  }

  factory AttendancePlayer.fromJson(Map<String, dynamic> j) {
    return AttendancePlayer(
      id: int.tryParse((j["id"] ?? "0").toString()) ?? 0,
      firstName: (j["first_name"] ?? j["firstname"] ?? "").toString(),
      lastName: (j["last_name"] ?? j["lastname"] ?? "").toString(),
      photo: (j["photo"] ?? j["avatar"] ?? "").toString().trim().isEmpty
          ? null
          : (j["photo"] ?? j["avatar"]).toString(),
    );
  }
}

class AttendanceMark {
  // "*" / "н" / "б" / "т" / "ип" / "в"
  static const present = "*";
  static const absent = "н";
  static const sick = "б";
  static const injury = "т";
  static const individual = "ип";
  static const dayoff = "в";

  static const all = [present, absent, sick, injury, individual, dayoff];
}
