import 'package:flutter/material.dart';


class AiPassNetworkEdge {
  final String fromTrackId;
  final String toTrackId;
  final String? team;
  final int count;
  final int successful;
  final double avgStartX;
  final double avgStartY;
  final double avgEndX;
  final double avgEndY;

  const AiPassNetworkEdge({
    required this.fromTrackId,
    required this.toTrackId,
    required this.team,
    required this.count,
    required this.successful,
    required this.avgStartX,
    required this.avgStartY,
    required this.avgEndX,
    required this.avgEndY,
  });

  factory AiPassNetworkEdge.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    int asInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return AiPassNetworkEdge(
      fromTrackId: '${json['from_track_id'] ?? ''}',
      toTrackId: '${json['to_track_id'] ?? ''}',
      team: json['team']?.toString(),
      count: asInt(json['count']),
      successful: asInt(json['successful']),
      avgStartX: asDouble(json['avg_start_x']),
      avgStartY: asDouble(json['avg_start_y']),
      avgEndX: asDouble(json['avg_end_x']),
      avgEndY: asDouble(json['avg_end_y']),
    );
  }
}

class AiAveragePosition {
  final String trackId;
  final String? team;
  final String playerName;
  final double avgX;
  final double avgY;
  final int samples;

  const AiAveragePosition({
    required this.trackId,
    required this.team,
    required this.playerName,
    required this.avgX,
    required this.avgY,
    required this.samples,
  });

  factory AiAveragePosition.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    int asInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return AiAveragePosition(
      trackId: '${json['track_id'] ?? ''}',
      team: json['team']?.toString(),
      playerName: '${json['player_name'] ?? 'Игрок'}',
      avgX: asDouble(json['avg_x']),
      avgY: asDouble(json['avg_y']),
      samples: asInt(json['samples']),
    );
  }
}

class AiDangerMoment {
  final int timeMs;
  final String? team;
  final String type;
  final String title;
  final double dangerScore;

  const AiDangerMoment({
    required this.timeMs,
    required this.team,
    required this.type,
    required this.title,
    required this.dangerScore,
  });

  factory AiDangerMoment.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    int asInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return AiDangerMoment(
      timeMs: asInt(json['time_ms']),
      team: json['team']?.toString(),
      type: '${json['type'] ?? 'danger'}',
      title: '${json['title'] ?? 'Опасный момент'}',
      dangerScore: asDouble(json['danger_score']),
    );
  }
}

class AiPlayerStat {
  final String trackId;
  final String? team;
  final String playerName;
  final int touches;
  final int passes;
  final int successfulPasses;
  final int shots;
  final int interceptions;
  final double distanceM;
  final double maxSpeedKmh;
  final double rating;

  const AiPlayerStat({
    required this.trackId,
    required this.team,
    required this.playerName,
    required this.touches,
    required this.passes,
    required this.successfulPasses,
    required this.shots,
    required this.interceptions,
    required this.distanceM,
    required this.maxSpeedKmh,
    required this.rating,
  });

  factory AiPlayerStat.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    int asInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return AiPlayerStat(
      trackId: '${json['track_id'] ?? ''}',
      team: json['team']?.toString(),
      playerName: '${json['player_name'] ?? 'Игрок'}',
      touches: asInt(json['touches']),
      passes: asInt(json['passes']),
      successfulPasses: asInt(json['successful_passes']),
      shots: asInt(json['shots']),
      interceptions: asInt(json['interceptions']),
      distanceM: asDouble(json['distance_m']),
      maxSpeedKmh: asDouble(json['max_speed_kmh']),
      rating: asDouble(json['rating']),
    );
  }
}


class AiDetectedEvent {
  final String type;
  final String title;
  final String subtitle;
  final int timeMs;
  final double confidence;
  final IconData icon;
  final Color color;
  final Map<String, dynamic>? meta;

  const AiDetectedEvent({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timeMs,
    required this.confidence,
    required this.icon,
    required this.color,
    this.meta,
  });

  factory AiDetectedEvent.fromBackendJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString().trim();
    final title = (json['title'] ?? 'Событие').toString().trim();
    final team = (json['team'] ?? '').toString().trim();
    final startMs = ((json['start_ms'] ?? 0) as num).toInt();
    final endMs = ((json['end_ms'] ?? startMs) as num).toInt();
    final confidence = ((json['confidence'] ?? 0) as num).toDouble();
    final success = json['success'] == true;

    final participants = ((json['participants'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final meta = json['meta'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['meta'] as Map<String, dynamic>)
        : json['meta'] is Map
            ? Map<String, dynamic>.from(json['meta'] as Map)
            : <String, dynamic>{};

    final subtitle = _buildSubtitle(
      type: type,
      team: team,
      participants: participants,
      meta: meta,
    );

    return AiDetectedEvent(
      type: type.isEmpty ? 'unknown' : type,
      title: title.isEmpty ? 'Событие' : title,
      subtitle: subtitle,
      timeMs: startMs,
      confidence: confidence,
      icon: _iconForType(type),
      color: _colorForType(type),
      meta: {
        ...meta,
        'team': team,
        'start_ms': startMs,
        'end_ms': endMs,
        'success': success,
        'participants': participants,
        'player_id': json['player_id'],
        'target_player_id': json['target_player_id'],
        'track_id': json['track_id'],
        'target_track_id': json['target_track_id'],
        'description': json['description'],
        'id': json['id'],
      },
    );
  }

  static String _buildSubtitle({
    required String type,
    required String team,
    required List<Map<String, dynamic>> participants,
    required Map<String, dynamic> meta,
  }) {
    final names = participants
        .map((p) => (p['name'] ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (type == 'pass' && names.length >= 2) {
      return '${names[0]} → ${names[1]}';
    }

    if (names.isNotEmpty) {
      return team.isEmpty ? names.join(', ') : '$team • ${names.join(', ')}';
    }

    if (type == 'pass') {
      final direction = (meta['direction'] ?? '').toString();
      final lengthType = (meta['length_type'] ?? '').toString();
      final parts = [direction, lengthType].where((e) => e.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        return team.isEmpty ? parts.join(' ') : '$team • ${parts.join(' ')}';
      }
    }

    if (meta['from_team'] != null && meta['to_team'] != null) {
      return '${meta['from_team']} → ${meta['to_team']}';
    }

    return team.isEmpty ? 'AI событие' : team;
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'pass':
        return Icons.compare_arrows_rounded;
      case 'interception':
        return Icons.shield_outlined;
      case 'recovery':
        return Icons.autorenew_rounded;
      case 'sprint':
        return Icons.flash_on_rounded;
      case 'acceleration':
        return Icons.trending_up_rounded;
      case 'direction_change':
        return Icons.turn_right_rounded;
      case 'shot':
        return Icons.sports_soccer_rounded;
      default:
        return Icons.analytics_outlined;
    }
  }

  static Color _colorForType(String type) {
    switch (type) {
      case 'pass':
        return const Color(0xFF2563EB);
      case 'interception':
        return const Color(0xFFDC2626);
      case 'recovery':
        return const Color(0xFF16A34A);
      case 'sprint':
        return const Color(0xFFF59E0B);
      case 'acceleration':
        return const Color(0xFF0F766E);
      case 'direction_change':
        return const Color(0xFF7C3AED);
      case 'shot':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF334155);
    }
  }
}

class AiTtdSuggestion {
  final String code;
  final String title;
  final String section;
  final int timeMs;
  final double confidence;
  final bool success;
  final Map<String, dynamic>? meta;

  const AiTtdSuggestion({
    required this.code,
    required this.title,
    required this.section,
    required this.timeMs,
    required this.confidence,
    required this.success,
    this.meta,
  });

  factory AiTtdSuggestion.fromBackendJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['code'] ?? '').toString().trim();
    final title = (json['title'] ?? 'AI ТТД').toString().trim();
    final timeMs = ((json['start_ms'] ?? json['timeMs'] ?? 0) as num).toInt();
    final confidence = ((json['confidence'] ?? 0) as num).toDouble();
    final success = json['success'] != false;

    final meta = json['meta'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['meta'] as Map<String, dynamic>)
        : json['meta'] is Map
            ? Map<String, dynamic>.from(json['meta'] as Map)
            : <String, dynamic>{};

    return AiTtdSuggestion(
      code: type.isEmpty ? 'unknown' : type,
      title: title.isEmpty ? 'AI ТТД' : title,
      section: _sectionForType(type),
      timeMs: timeMs,
      confidence: confidence,
      success: success,
      meta: {
        ...meta,
        'team': json['team'],
        'participants': json['participants'],
        'track_id': json['track_id'],
        'target_track_id': json['target_track_id'],
        'description': json['description'],
        'id': json['id'],
      },
    );
  }

  static String _sectionForType(String type) {
    switch (type) {
      case 'pass':
      case 'forward_short':
      case 'forward_medium':
      case 'forward_long':
      case 'back_short':
      case 'back_medium':
      case 'back_long':
      case 'lateral_short':
      case 'lateral_medium':
      case 'lateral_long':
        return 'Передачи';

      case 'save':
      case 'goalkeeper_save':
      case 'goalkeeper_exit':
        return 'Вратарские действия';

      default:
        return 'Основные действия';
    }
  }
}