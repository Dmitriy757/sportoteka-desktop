// lib/presentation/advanced_video_analysis/models/analysis_result.dart

import 'player_detection.dart';

class AnalysisResult {
  final List<PlayerDetection> players;
  final Map<String, dynamic> stats;
  final int frame;
  final double timestamp;

  AnalysisResult({
    required this.players,
    required this.stats,
    required this.frame,
    required this.timestamp,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final normalized = _unwrap(json);
    final rawPlayers = _extractPlayers(normalized);

    final rawStats = normalized['stats'] is Map
        ? Map<String, dynamic>.from(normalized['stats'] as Map)
        : <String, dynamic>{};

    // Переносим размеры кадра в stats, чтобы overlay мог правильно масштабировать bbox.
    for (final key in [
      'video_width',
      'video_height',
      'frame_width',
      'frame_height',
      'width',
      'height',
      'source_width',
      'source_height',
    ]) {
      if (normalized.containsKey(key)) rawStats[key] = normalized[key];
    }

    return AnalysisResult(
      players: rawPlayers
          .whereType<Map>()
          .map((e) => PlayerDetection.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => !p.bbox.isEmpty)
          .toList(),
      stats: rawStats,
      frame: _asInt(normalized['frame'] ?? normalized['frame_index'] ?? normalized['frameIndex']),
      timestamp: _asDouble(normalized['time_ms'] ?? normalized['timestamp_ms'] ?? normalized['timestamp'] ?? normalized['time']),
    );
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    // Иногда сервер заворачивает ответ в {type: ..., data: {...}} или {result: {...}}.
    final data = json['data'] ?? json['result'] ?? json['payload'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  static List<dynamic> _extractPlayers(Map<String, dynamic> json) {
    final raw = json['players'] ??
        json['detections'] ??
        json['objects'] ??
        json['tracks'] ??
        json['player_detections'];
    return raw is List ? raw : const [];
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? double.tryParse(value.toString())?.round() ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }
}
