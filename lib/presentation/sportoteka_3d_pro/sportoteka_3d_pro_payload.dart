import 'dart:convert';

class Sportoteka3DProPayload {
  const Sportoteka3DProPayload({
    required this.clubId,
    required this.clubName,
    required this.teamId,
    required this.teamName,
    required this.players,
    this.teamLogo = '',
  });

  final int clubId;
  final String clubName;
  final int teamId;
  final String teamName;
  final String teamLogo;
  final List<Sportoteka3DProPlayerPayload> players;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'clubId': clubId,
        'clubName': clubName,
        'teamId': teamId,
        'teamName': teamName,
        'teamLogo': teamLogo,
        'players': players.map((e) => e.toJson()).toList(),
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  static Sportoteka3DProPayload fromRaw({
    required int clubId,
    required String clubName,
    required int teamId,
    required String teamName,
    required List<Map<String, dynamic>> players,
    String teamLogo = '',
  }) {
    return Sportoteka3DProPayload(
      clubId: clubId,
      clubName: clubName.trim().isEmpty ? 'Клуб' : clubName.trim(),
      teamId: teamId,
      teamName: teamName.trim().isEmpty ? 'Команда' : teamName.trim(),
      teamLogo: _normalizeImage(teamLogo),
      players: players.map(Sportoteka3DProPlayerPayload.fromMap).toList(),
    );
  }
}

class Sportoteka3DProPlayerPayload {
  const Sportoteka3DProPlayerPayload({
    required this.id,
    required this.number,
    required this.name,
    required this.position,
    required this.role,
    required this.avatarUrl,
    required this.avatarPath,
    required this.teamColor,
  });

  final int id;
  final int number;
  final String name;
  final String position;
  final String role;
  final String avatarUrl;
  final String avatarPath;
  final String teamColor;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'number': number,
        'name': name,
        'position': position,
        'role': role,
        'avatarUrl': avatarUrl,
        'avatarPath': avatarPath,
        'teamColor': teamColor,
        'initials': initials,
      };

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.length == 1 && parts[0].length >= 2) return parts[0].substring(0, 2).toUpperCase();
    return number > 0 ? '$number' : 'ИГ';
  }

  factory Sportoteka3DProPlayerPayload.fromMap(Map<String, dynamic> map) {
    final id = _intFromAny(
      map['id'] ??
          map['player_id'] ??
          map['playerId'] ??
          map['athlete_id'] ??
          map['student_id'],
    );

    final number = _intFromAny(
      map['number'] ??
          map['player_number'] ??
          map['playerNumber'] ??
          map['shirt_number'] ??
          map['shirtNumber'] ??
          map['jersey'] ??
          map['jersey_number'],
    );

    final full = _s(
      map['full_name'] ??
          map['fullName'] ??
          map['player_name'] ??
          map['playerName'] ??
          map['fio'] ??
          map['name'],
    );

    final last = _s(map['last_name'] ?? map['lastName'] ?? map['surname']);
    final first = _s(map['first_name'] ?? map['firstName']);
    final resolvedName = full.isNotEmpty
        ? full
        : [last, first].where((e) => e.trim().isNotEmpty).join(' ').trim();

    final position = _s(
      map['position'] ??
          map['role'] ??
          map['amplua'] ??
          map['player_position'] ??
          map['playerPosition'] ??
          map['position_name'],
    );

    final avatar = _normalizeImage(
      _s(
        map['photo'] ??
            map['photo_url'] ??
            map['photoUrl'] ??
            map['avatar'] ??
            map['avatar_url'] ??
            map['avatarUrl'] ??
            map['image'] ??
            map['image_url'] ??
            map['imageUrl'],
      ),
    );

    return Sportoteka3DProPlayerPayload(
      id: id,
      number: number,
      name: resolvedName.isEmpty ? 'Игрок ${number > 0 ? number : id}' : resolvedName,
      position: position.isEmpty ? 'Игрок' : position,
      role: _roleFromPosition(position),
      avatarUrl: avatar,
      avatarPath: _s(map['avatarPath'] ?? map['local_avatar'] ?? map['localAvatar']),
      teamColor: _s(map['teamColor'] ?? map['team_color']).isEmpty
          ? '#00A750'
          : _s(map['teamColor'] ?? map['team_color']),
    );
  }
}

String _roleFromPosition(String raw) {
  final p = raw.toLowerCase().trim();
  if (p.contains('вр') || p.contains('врат') || p.contains('gk') || p.contains('goal')) return 'Вратари';
  if (p.contains('защ') || p.contains('цз') || p.contains('пз') || p.contains('лз') || p.contains('def')) {
    return 'Защита';
  }
  if (p.contains('пзщ') ||
      p.contains('полу') ||
      p.contains('оп') ||
      p.contains('цп') ||
      p.contains('ап') ||
      p.contains('mid')) {
    return 'Полузащита';
  }
  if (p.contains('нап') || p.contains('нп') || p.contains('wing') || p.contains('ата') || p.contains('forw')) {
    return 'Атака';
  }
  return 'Состав';
}

int _intFromAny(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
}

String _s(dynamic value) => value == null ? '' : value.toString().trim();

String _normalizeImage(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('file://')) return value;
  if (value.startsWith('/')) return 'https://sportotekaapp.ru$value';
  return 'https://sportotekaapp.ru/$value';
}
