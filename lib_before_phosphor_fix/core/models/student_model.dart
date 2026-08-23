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

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'first_name': firstName,
      'last_name': lastName,
      'status': status,
    };
  }
}
