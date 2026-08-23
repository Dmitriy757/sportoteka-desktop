import 'dart:convert';

import 'package:http/http.dart' as http;

class TrackerPerformanceProfile {
  const TrackerPerformanceProfile({
    required this.playerId,
    this.thresholdMode = 'team',
    this.hsrThresholdKmh,
    this.sprintThresholdKmh,
    this.accelerationThresholdMps2 = 1.8,
    this.decelerationThresholdMps2 = 1.8,
    this.referenceMaxSpeedKmh,
    this.matchSessionIds = const <int>[],
    this.updatedAt = '',
  });

  final int playerId;
  final String thresholdMode;
  final double? hsrThresholdKmh;
  final double? sprintThresholdKmh;
  final double accelerationThresholdMps2;
  final double decelerationThresholdMps2;
  final double? referenceMaxSpeedKmh;
  final List<int> matchSessionIds;
  final String updatedAt;

  factory TrackerPerformanceProfile.fromJson(
    Map<String, dynamic> json, {
    required int fallbackPlayerId,
  }) {
    final rawMatchIds = json['match_session_ids'];
    final matchIds = <int>{};
    if (rawMatchIds is List) {
      for (final value in rawMatchIds) {
        final id = _readinessInt(value);
        if (id > 0) matchIds.add(id);
      }
    } else if (rawMatchIds is String && rawMatchIds.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMatchIds);
        if (decoded is List) {
          for (final value in decoded) {
            final id = _readinessInt(value);
            if (id > 0) matchIds.add(id);
          }
        }
      } catch (_) {
        for (final value in rawMatchIds.split(',')) {
          final id = _readinessInt(value.trim());
          if (id > 0) matchIds.add(id);
        }
      }
    }
    return TrackerPerformanceProfile(
      playerId: _readinessInt(json['player_id']) > 0
          ? _readinessInt(json['player_id'])
          : fallbackPlayerId,
      thresholdMode: _readinessThresholdMode(json['threshold_mode']),
      hsrThresholdKmh: _readinessNullableDouble(json['hsr_threshold_kmh']),
      sprintThresholdKmh:
          _readinessNullableDouble(json['sprint_threshold_kmh']),
      accelerationThresholdMps2:
          _readinessDouble(json['acceleration_threshold_mps2'], 1.8),
      decelerationThresholdMps2:
          _readinessDouble(json['deceleration_threshold_mps2'], 1.8),
      referenceMaxSpeedKmh:
          _readinessNullableDouble(json['reference_max_speed_kmh']),
      matchSessionIds: matchIds.toList(growable: false)..sort(),
      updatedAt: '${json['updated_at'] ?? ''}',
    );
  }

  TrackerPerformanceProfile copyWith({
    String? thresholdMode,
    double? hsrThresholdKmh,
    double? sprintThresholdKmh,
    double? accelerationThresholdMps2,
    double? decelerationThresholdMps2,
    double? referenceMaxSpeedKmh,
    List<int>? matchSessionIds,
    String? updatedAt,
  }) {
    return TrackerPerformanceProfile(
      playerId: playerId,
      thresholdMode: thresholdMode ?? this.thresholdMode,
      hsrThresholdKmh: hsrThresholdKmh ?? this.hsrThresholdKmh,
      sprintThresholdKmh: sprintThresholdKmh ?? this.sprintThresholdKmh,
      accelerationThresholdMps2:
          accelerationThresholdMps2 ?? this.accelerationThresholdMps2,
      decelerationThresholdMps2:
          decelerationThresholdMps2 ?? this.decelerationThresholdMps2,
      referenceMaxSpeedKmh:
          referenceMaxSpeedKmh ?? this.referenceMaxSpeedKmh,
      matchSessionIds: matchSessionIds ?? this.matchSessionIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'player_id': playerId,
        'threshold_mode': _readinessThresholdMode(thresholdMode),
        'hsr_threshold_kmh': hsrThresholdKmh,
        'sprint_threshold_kmh': sprintThresholdKmh,
        'acceleration_threshold_mps2': accelerationThresholdMps2,
        'deceleration_threshold_mps2': decelerationThresholdMps2,
        'reference_max_speed_kmh': referenceMaxSpeedKmh,
        'match_session_ids': matchSessionIds,
      };
}

class TrackerReadinessCheckin {
  const TrackerReadinessCheckin({
    required this.playerId,
    required this.date,
    this.hasEntry = false,
    this.sleepHours = 8,
    this.sleepQuality = 3,
    this.fatigue = 3,
    this.muscleSoreness = 2,
    this.stress = 2,
    this.mood = 3,
    this.pain = 0,
    this.rpe = 0,
    this.rpeSessionId,
    this.note = '',
    this.updatedAt = '',
  });

  final int playerId;
  final String date;
  final bool hasEntry;
  final double sleepHours;
  final int sleepQuality;
  final int fatigue;
  final int muscleSoreness;
  final int stress;
  final int mood;
  final int pain;
  final int rpe;
  final int? rpeSessionId;
  final String note;
  final String updatedAt;

  factory TrackerReadinessCheckin.fromJson(
    Map<String, dynamic> json, {
    required int fallbackPlayerId,
    required String fallbackDate,
  }) {
    final hasData = json.isNotEmpty &&
        (json['id'] != null || json['checkin_date'] != null);
    return TrackerReadinessCheckin(
      playerId: _readinessInt(json['player_id']) > 0
          ? _readinessInt(json['player_id'])
          : fallbackPlayerId,
      date: '${json['checkin_date'] ?? fallbackDate}',
      hasEntry: hasData,
      sleepHours:
          _readinessDouble(json['sleep_hours'], 8).clamp(0, 16).toDouble(),
      sleepQuality: _readinessScale(json['sleep_quality'], 3),
      fatigue: _readinessScale(json['fatigue'], 3),
      muscleSoreness: _readinessScale(json['muscle_soreness'], 2),
      stress: _readinessScale(json['stress_level'], 2),
      mood: _readinessScale(json['mood'], 3),
      pain: _readinessInt(json['pain_score']).clamp(0, 10).toInt(),
      rpe: _readinessInt(json['rpe']).clamp(0, 10).toInt(),
      rpeSessionId: _readinessNullableInt(json['rpe_session_id']),
      note: '${json['note'] ?? ''}',
      updatedAt: '${json['updated_at'] ?? ''}',
    );
  }

  TrackerReadinessCheckin copyWith({
    bool? hasEntry,
    double? sleepHours,
    int? sleepQuality,
    int? fatigue,
    int? muscleSoreness,
    int? stress,
    int? mood,
    int? pain,
    int? rpe,
    int? rpeSessionId,
    bool clearRpeSessionId = false,
    String? note,
    String? updatedAt,
  }) {
    return TrackerReadinessCheckin(
      playerId: playerId,
      date: date,
      hasEntry: hasEntry ?? this.hasEntry,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      fatigue: fatigue ?? this.fatigue,
      muscleSoreness: muscleSoreness ?? this.muscleSoreness,
      stress: stress ?? this.stress,
      mood: mood ?? this.mood,
      pain: pain ?? this.pain,
      rpe: rpe ?? this.rpe,
      rpeSessionId:
          clearRpeSessionId ? null : rpeSessionId ?? this.rpeSessionId,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'player_id': playerId,
        'checkin_date': date,
        'sleep_hours': sleepHours,
        'sleep_quality': sleepQuality,
        'fatigue': fatigue,
        'muscle_soreness': muscleSoreness,
        'stress_level': stress,
        'mood': mood,
        'pain_score': pain,
        'rpe': rpe,
        'rpe_session_id': rpeSessionId,
        'note': note,
      };
}

class TrackerReadinessRemoteSnapshot {
  const TrackerReadinessRemoteSnapshot({
    required this.profile,
    required this.checkin,
    this.serverAvailable = true,
  });

  final TrackerPerformanceProfile profile;
  final TrackerReadinessCheckin checkin;
  final bool serverAvailable;
}

class TrackerReadinessApi {
  TrackerReadinessApi({
    required this.apiBaseUrl,
    this.timeout = const Duration(seconds: 12),
  });

  final String apiBaseUrl;
  final Duration timeout;

  Future<TrackerReadinessRemoteSnapshot> load({
    required int clubId,
    required int teamId,
    required int playerId,
    required String referenceDate,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/get_tracker_readiness.php').replace(
      queryParameters: <String, String>{
        'club_id': '$clubId',
        'team_id': '$teamId',
        'player_id': '$playerId',
        'reference_date': referenceDate,
      },
    );
    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(timeout);
    if (response.statusCode == 404) {
      throw const TrackerReadinessApiUnavailable();
    }
    final root = _decodeResponse(response);
    return TrackerReadinessRemoteSnapshot(
      profile: TrackerPerformanceProfile.fromJson(
        _map(root['profile']),
        fallbackPlayerId: playerId,
      ),
      checkin: TrackerReadinessCheckin.fromJson(
        _map(root['checkin']),
        fallbackPlayerId: playerId,
        fallbackDate: referenceDate,
      ),
    );
  }

  Future<Map<int, TrackerReadinessRemoteSnapshot>> loadTeam({
    required int clubId,
    required int teamId,
    required String referenceDate,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/get_tracker_readiness_team.php').replace(
      queryParameters: <String, String>{
        'club_id': '$clubId',
        'team_id': '$teamId',
        'reference_date': referenceDate,
      },
    );
    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(timeout);
    if (response.statusCode == 404) {
      throw const TrackerReadinessApiUnavailable();
    }
    final root = _decodeResponse(response);
    final rows = root['items'] is List ? root['items'] as List : const [];
    final out = <int, TrackerReadinessRemoteSnapshot>{};
    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final playerId = _readinessInt(row['player_id']);
      if (playerId <= 0) continue;
      out[playerId] = TrackerReadinessRemoteSnapshot(
        profile: TrackerPerformanceProfile.fromJson(
          _map(row['profile']),
          fallbackPlayerId: playerId,
        ),
        checkin: TrackerReadinessCheckin.fromJson(
          _map(row['checkin']),
          fallbackPlayerId: playerId,
          fallbackDate: referenceDate,
        ),
      );
    }
    return out;
  }

  Future<TrackerPerformanceProfile> saveProfile({
    required int clubId,
    required int teamId,
    required int userId,
    required TrackerPerformanceProfile profile,
  }) async {
    final root = await _post(<String, dynamic>{
      'action': 'save_profile',
      'club_id': clubId,
      'team_id': teamId,
      'created_by': userId,
      ...profile.toJson(),
    });
    return TrackerPerformanceProfile.fromJson(
      _map(root['profile']),
      fallbackPlayerId: profile.playerId,
    );
  }

  Future<TrackerReadinessCheckin> saveCheckin({
    required int clubId,
    required int teamId,
    required int userId,
    required TrackerReadinessCheckin checkin,
  }) async {
    final root = await _post(<String, dynamic>{
      'action': 'save_checkin',
      'club_id': clubId,
      'team_id': teamId,
      'created_by': userId,
      ...checkin.toJson(),
    });
    return TrackerReadinessCheckin.fromJson(
      _map(root['checkin']),
      fallbackPlayerId: checkin.playerId,
      fallbackDate: checkin.date,
    );
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> payload) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/save_tracker_readiness.php'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    if (response.statusCode == 404) {
      throw const TrackerReadinessApiUnavailable();
    }
    return _decodeResponse(response);
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw TrackerReadinessApiException(
        'HTTP ${response.statusCode}: сервер вернул не JSON',
      );
    }
    final root = _map(decoded);
    final success = root['success'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        success == false) {
      final message = '${root['message'] ?? root['error'] ?? 'Ошибка API'}';
      throw TrackerReadinessApiException(message);
    }
    return root;
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

class TrackerReadinessApiUnavailable implements Exception {
  const TrackerReadinessApiUnavailable();

  @override
  String toString() => 'Серверный модуль готовности ещё не установлен';
}

class TrackerReadinessApiException implements Exception {
  const TrackerReadinessApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

int _readinessInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ??
      double.tryParse('${value ?? ''}')?.toInt() ??
      0;
}

int? _readinessNullableInt(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty || raw == 'null' || raw == '0') return null;
  final parsed = _readinessInt(value);
  return parsed > 0 ? parsed : null;
}

double _readinessDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? fallback;
}

double? _readinessNullableDouble(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty || raw == 'null') return null;
  final parsed = _readinessDouble(value, double.nan);
  return parsed.isFinite ? parsed : null;
}

int _readinessScale(dynamic value, int fallback) =>
    _readinessInt(value) == 0
        ? fallback
        : _readinessInt(value).clamp(1, 5).toInt();

String _readinessThresholdMode(dynamic value) {
  final mode = '${value ?? ''}'.trim().toLowerCase();
  if (mode == 'manual' || mode == 'history') return mode;
  return 'team';
}
