// class_model.dart
class ClassModel {
  final int id;
  final String name;
  final String sportType;

  ClassModel({required this.id, required this.name, required this.sportType});

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      sportType: json['sport_type'] ?? '',
    );
  }
}

// student_model.dart
class StudentModel {
  final int id;
  final String firstName;
  final String lastName;
  final String status;

  StudentModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.status,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: int.parse(json['id'].toString()),
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      status: json['status'] ?? 'pending',
    );
  }
}
