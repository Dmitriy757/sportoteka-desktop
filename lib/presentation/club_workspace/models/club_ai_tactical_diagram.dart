// lib/presentation/club_workspace/models/club_ai_tactical_diagram.dart

class ClubAiTacticalDiagram {
  const ClubAiTacticalDiagram({
    required this.title,
    required this.subtitle,
    required this.note,
    required this.players,
    required this.arrows,
  });

  final String title;
  final String subtitle;
  final String note;
  final List<ClubAiDiagramPlayer> players;
  final List<ClubAiDiagramArrow> arrows;

  factory ClubAiTacticalDiagram.fromJson(Map<String, dynamic> json) {
    final playersRaw = json['players'] is List ? json['players'] as List : const <dynamic>[];
    final arrowsRaw = json['arrows'] is List ? json['arrows'] as List : const <dynamic>[];
    return ClubAiTacticalDiagram(
      title: '${json['title'] ?? 'Тактическая схема'}',
      subtitle: '${json['subtitle'] ?? ''}',
      note: '${json['note'] ?? ''}',
      players: playersRaw
          .whereType<Map>()
          .map((e) => ClubAiDiagramPlayer.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      arrows: arrowsRaw
          .whereType<Map>()
          .map((e) => ClubAiDiagramArrow.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'subtitle': subtitle,
        'note': note,
        'players': players.map((item) => item.toJson()).toList(growable: false),
        'arrows': arrows.map((item) => item.toJson()).toList(growable: false),
      };
}

class ClubAiDiagramPlayer {
  const ClubAiDiagramPlayer({
    required this.label,
    required this.x,
    required this.y,
    required this.team,
  });

  final String label;
  final double x;
  final double y;
  final String team;

  factory ClubAiDiagramPlayer.fromJson(Map<String, dynamic> json) {
    return ClubAiDiagramPlayer(
      label: '${json['label'] ?? ''}',
      x: _asDouble(json['x'], .5).clamp(0.0, 1.0).toDouble(),
      y: _asDouble(json['y'], .5).clamp(0.0, 1.0).toDouble(),
      team: '${json['team'] ?? 'home'}',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'x': x,
        'y': y,
        'team': team,
      };
}

class ClubAiDiagramArrow {
  const ClubAiDiagramArrow({
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    required this.kind,
  });

  final double fromX;
  final double fromY;
  final double toX;
  final double toY;
  final String kind; // pass / run / press / cover

  factory ClubAiDiagramArrow.fromJson(Map<String, dynamic> json) {
    return ClubAiDiagramArrow(
      fromX: _asDouble(json['fromX'] ?? json['from_x'], 0).clamp(0.0, 1.0).toDouble(),
      fromY: _asDouble(json['fromY'] ?? json['from_y'], 0).clamp(0.0, 1.0).toDouble(),
      toX: _asDouble(json['toX'] ?? json['to_x'], 0).clamp(0.0, 1.0).toDouble(),
      toY: _asDouble(json['toY'] ?? json['to_y'], 0).clamp(0.0, 1.0).toDouble(),
      kind: '${json['kind'] ?? 'run'}',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'from_x': fromX,
        'from_y': fromY,
        'to_x': toX,
        'to_y': toY,
        'kind': kind,
      };
}

double _asDouble(dynamic v, double fallback) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(',', '.')) ?? fallback;
}
