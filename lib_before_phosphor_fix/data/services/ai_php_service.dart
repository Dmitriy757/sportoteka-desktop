import 'dart:convert';

import 'package:dio/dio.dart';

class AiPhpService {
  final Dio _dio;

  AiPhpService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://sportotekaapp.ru/api',
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(minutes: 5),
                sendTimeout: const Duration(minutes: 5),
                headers: {
                  'Accept': 'application/json',
                },
              ),
            );

  Future<Map<String, dynamic>> startAiAnalysis({
    required int matchId,
    required String videoUrl,
    int? userId,
    String homeTeamKey = 'home',
    String awayTeamKey = 'away',
    double samplingFps = 5.0,
  }) async {
    final response = await _dio.post(
      '/start_ai_analysis.php',
      data: jsonEncode({
        'match_id': matchId,
        'user_id': userId,
        'video_url': videoUrl,
        'home_team_key': homeTeamKey,
        'away_team_key': awayTeamKey,
        'sampling_fps': samplingFps,
      }),
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
    );

    return _normalize(response.data);
  }

  Future<Map<String, dynamic>> getAiStatus({
    required int matchId,
  }) async {
    final response = await _dio.get(
      '/get_ai_analysis_status.php',
      queryParameters: {'match_id': matchId},
    );
    return _normalize(response.data);
  }

  Future<Map<String, dynamic>> getAiEvents({
    required int matchId,
  }) async {
    final response = await _dio.get(
      '/get_ai_events.php',
      queryParameters: {'match_id': matchId},
    );
    return _normalize(response.data);
  }

  Future<Map<String, dynamic>> getAiTtd({
    required int matchId,
  }) async {
    final response = await _dio.get(
      '/get_ai_ttd.php',
      queryParameters: {'match_id': matchId},
    );
    return _normalize(response.data);
  }

  Future<Map<String, dynamic>> getAiMatchStats({
    required int matchId,
  }) async {
    final response = await _dio.get(
      '/get_ai_match_stats.php',
      queryParameters: {'match_id': matchId},
    );
    return _normalize(response.data);
  }

  Map<String, dynamic> _normalize(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);

    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Unexpected response format: ${raw.runtimeType}');
  }
}