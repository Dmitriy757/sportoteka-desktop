import 'dart:math' as math;

enum ClubAiVisualizationType {
  tacticalBoard,
  heartRate,
  speed,
  load,
  trajectory,
  metrics,
  unknown,
}

class ClubAiVisualization {
  const ClubAiVisualization({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.data,
  });

  final String id;
  final ClubAiVisualizationType type;
  final String title;
  final String subtitle;
  final Map<String, dynamic> data;

  factory ClubAiVisualization.fromMap(
    Map<String, dynamic> map, {
    int fallbackIndex = 0,
  }) {
    final rawType = '${map['type'] ?? map['kind'] ?? ''}'.toLowerCase();
    final nested = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map['payload'] is Map
            ? Map<String, dynamic>.from(map['payload'] as Map)
            : Map<String, dynamic>.from(map);

    return ClubAiVisualization(
      id: '${map['id'] ?? '${rawType}_$fallbackIndex'}',
      type: _parseType(rawType, nested),
      title: '${map['title'] ?? nested['title'] ?? _defaultTitle(rawType)}',
      subtitle: '${map['subtitle'] ?? nested['subtitle'] ?? ''}',
      data: nested,
    );
  }

  static ClubAiVisualizationType _parseType(
    String raw,
    Map<String, dynamic> data,
  ) {
    final type = raw.replaceAll('-', '_');

    if (type.contains('tactical') ||
        type.contains('diagram') ||
        data['formation'] != null ||
        data['players'] is List) {
      return ClubAiVisualizationType.tacticalBoard;
    }
    if (type.contains('heart') ||
        type.contains('pulse') ||
        type.contains('cardio') ||
        type == 'hr') {
      return ClubAiVisualizationType.heartRate;
    }
    if (type.contains('speed')) {
      return ClubAiVisualizationType.speed;
    }
    if (type.contains('load')) {
      return ClubAiVisualizationType.load;
    }
    if (type.contains('trajectory') ||
        type.contains('track') ||
        type.contains('route') ||
        type.contains('heatmap')) {
      return ClubAiVisualizationType.trajectory;
    }
    if (type.contains('metric') || type.contains('summary')) {
      return ClubAiVisualizationType.metrics;
    }
    return ClubAiVisualizationType.unknown;
  }

  static String _defaultTitle(String type) {
    if (type.contains('heart') || type.contains('pulse')) {
      return 'Пульс';
    }
    if (type.contains('speed')) return 'Скорость';
    if (type.contains('load')) return 'Нагрузка';
    if (type.contains('trajectory') || type.contains('track')) {
      return 'Траектория';
    }
    if (type.contains('tactical') || type.contains('diagram')) {
      return 'Тактическая схема';
    }
    return 'Визуализация';
  }

  static List<ClubAiVisualization> fromResponse(
    Map<String, dynamic> response,
  ) {
    final result = <ClubAiVisualization>[];

    final visualizations = response['visualizations'];
    if (visualizations is List) {
      for (var i = 0; i < visualizations.length; i++) {
        final item = visualizations[i];
        if (item is Map) {
          result.add(
            ClubAiVisualization.fromMap(
              Map<String, dynamic>.from(item),
              fallbackIndex: i,
            ),
          );
        }
      }
    }

    // Core 2.0 / V60 compatibility.
    final board = response['tactical_board'];
    if (board is Map &&
        !result.any((e) => e.type == ClubAiVisualizationType.tacticalBoard)) {
      result.add(
        ClubAiVisualization.fromMap(
          <String, dynamic>{
            'id': 'legacy_tactical_board',
            'type': 'tactical_board',
            'title': 'Тактическая схема',
            'data': Map<String, dynamic>.from(board),
          },
        ),
      );
    }

    final diagrams = response['diagrams'];
    if (diagrams is List &&
        !result.any((e) => e.type == ClubAiVisualizationType.tacticalBoard)) {
      for (final item in diagrams.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        if ('${map['format'] ?? ''}'.toLowerCase() == 'json' &&
            map['data'] is Map) {
          result.add(
            ClubAiVisualization.fromMap(
              <String, dynamic>{
                'id': 'legacy_diagram',
                'type': 'tactical_board',
                'title': 'Тактическая схема',
                'data': Map<String, dynamic>.from(map['data'] as Map),
              },
            ),
          );
          break;
        }
      }
    }

    return result;
  }
}

class ClubAiSeriesPoint {
  const ClubAiSeriesPoint({
    required this.x,
    required this.y,
    required this.label,
  });

  final double x;
  final double y;
  final String label;

  static List<ClubAiSeriesPoint> parse(Map<String, dynamic> data) {
    final raw = data['points'] ??
        data['samples'] ??
        data['series'] ??
        data['values'] ??
        const <dynamic>[];

    if (raw is! List) return const <ClubAiSeriesPoint>[];

    final output = <ClubAiSeriesPoint>[];

    for (var i = 0; i < raw.length; i++) {
      final value = raw[i];

      if (value is num) {
        output.add(
          ClubAiSeriesPoint(
            x: i.toDouble(),
            y: value.toDouble(),
            label: '$i',
          ),
        );
        continue;
      }

      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final y = _toDouble(
          map['value'] ??
              map['y'] ??
              map['bpm'] ??
              map['heart_rate'] ??
              map['speed_kmh'] ??
              map['speed'] ??
              map['load'],
        );
        if (y == null) continue;

        output.add(
          ClubAiSeriesPoint(
            x: _toDouble(
                  map['x'] ??
                      map['second'] ??
                      map['seconds'] ??
                      map['time_sec'] ??
                      map['index'],
                ) ??
                i.toDouble(),
            y: y,
            label: '${map['label'] ?? map['time'] ?? map['timestamp'] ?? i}',
          ),
        );
      }
    }

    return output;
  }
}

class ClubAiTrackPoint {
  const ClubAiTrackPoint({
    required this.x,
    required this.y,
    this.speed = 0,
  });

  final double x;
  final double y;
  final double speed;

  static List<ClubAiTrackPoint> parse(Map<String, dynamic> data) {
    final raw = data['points'] ??
        data['track'] ??
        data['trajectory'] ??
        const <dynamic>[];

    if (raw is! List) return const <ClubAiTrackPoint>[];

    final parsed = <ClubAiTrackPoint>[];

    for (final item in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final x = _toDouble(
        map['x'] ??
            map['field_x'] ??
            map['field_x_m'] ??
            map['longitude'] ??
            map['lng'],
      );
      final y = _toDouble(
        map['y'] ??
            map['field_y'] ??
            map['field_y_m'] ??
            map['latitude'] ??
            map['lat'],
      );
      if (x == null || y == null) continue;

      parsed.add(
        ClubAiTrackPoint(
          x: x,
          y: y,
          speed: _toDouble(map['speed_kmh'] ?? map['speed']) ?? 0,
        ),
      );
    }

    if (parsed.isEmpty) return parsed;

    final minX = parsed.map((e) => e.x).reduce(math.min);
    final maxX = parsed.map((e) => e.x).reduce(math.max);
    final minY = parsed.map((e) => e.y).reduce(math.min);
    final maxY = parsed.map((e) => e.y).reduce(math.max);
    final dx = math.max(0.000001, maxX - minX);
    final dy = math.max(0.000001, maxY - minY);

    return parsed
        .map(
          (e) => ClubAiTrackPoint(
            x: ((e.x - minX) / dx).clamp(0.0, 1.0),
            y: ((e.y - minY) / dy).clamp(0.0, 1.0),
            speed: e.speed,
          ),
        )
        .toList(growable: false);
  }
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.'));
}
