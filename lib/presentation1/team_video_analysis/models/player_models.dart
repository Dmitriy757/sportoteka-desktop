import 'package:flutter/material.dart';

class Player {
  final int id;
  final String firstName;
  final String lastName;
  final String? photo;
  final String? position;
  final int? jerseyNumber;

  Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
    this.position,
    this.jerseyNumber,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      firstName: json['first_name']?.toString() ?? json['name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? json['surname']?.toString() ?? '',
      photo: json['photo']?.toString() ?? json['image']?.toString(),
      position: json['position']?.toString(),
      jerseyNumber: int.tryParse(json['jersey_number']?.toString() ?? ''),
    );
  }

  String get fullName => '$lastName $firstName'.trim();

  String get initials {
    if (lastName.isNotEmpty) return lastName[0].toUpperCase();
    if (firstName.isNotEmpty) return firstName[0].toUpperCase();
    return '?';
  }
}

// Вспомогательные функции для работы с игроками
class PlayerHelpers {
  static String firstName(Map<String, dynamic> p) {
    return (p["first_name"]?.toString() ?? "").isNotEmpty 
        ? p["first_name"].toString() 
        : (p["name"]?.toString() ?? "");
  }

  static String lastName(Map<String, dynamic> p) {
    return (p["last_name"]?.toString() ?? "").isNotEmpty 
        ? p["last_name"].toString() 
        : (p["surname"]?.toString() ?? "");
  }

  static String fullName(Map<String, dynamic> p) {
    return "${lastName(p)} ${firstName(p)}".trim();
  }

  static String photo(Map<String, dynamic> p) {
    return (p["photo"]?.toString() ?? "").isNotEmpty 
        ? p["photo"].toString() 
        : (p["image"]?.toString() ?? "");
  }

  static String position(Map<String, dynamic> p) => p["position"]?.toString() ?? "";

  static List<Map<String, dynamic>> filterPlayers(
    List<Map<String, dynamic>> players, 
    String query
  ) {
    if (query.isEmpty) return List.from(players);
    
    final q = query.toLowerCase();
    return players.where((player) {
      final firstName = PlayerHelpers.firstName(player).toLowerCase();
      final lastName = PlayerHelpers.lastName(player).toLowerCase();
      final position = PlayerHelpers.position(player).toLowerCase();
      final fullName = PlayerHelpers.fullName(player).toLowerCase();

      return firstName.contains(q) ||
          lastName.contains(q) ||
          fullName.contains(q) ||
          position.contains(q);
    }).toList();
  }
}