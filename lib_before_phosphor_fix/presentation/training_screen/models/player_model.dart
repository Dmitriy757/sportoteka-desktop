class PlayerModel {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String birthDate;
  final String nationality;
  final String sportData;

  PlayerModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.birthDate,
    required this.nationality,
    required this.sportData,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: int.parse(json['player_id'].toString()),
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      birthDate: json['birth_date'] ?? '',
      nationality: json['nationality'] ?? '',
      sportData: json['sport_data'] ?? '',
    );
  }
}

