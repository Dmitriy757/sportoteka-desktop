import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/ai_match_analysis_models.dart';

class AiMatchAnalysisService {
  final Dio _dio;
  final String baseUrl;

  AiMatchAnalysisService({
    Dio? dio,
    required this.baseUrl,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(minutes: 2),
                sendTimeout: const Duration(minutes: 60),
                receiveTimeout: const Duration(minutes: 60),
                headers: {
                  'Accept': 'application/json',
                },
              ),
            );

  Future<AiCreateJobResponse> createJob({
    int? matchId,
    String? title,
    String? videoUrl,
    String? videoPath,
    String homeTeamKey = 'home',
    String awayTeamKey = 'away',
  }) async {
    final response = await _dio.post(
      '/api/video-analysis/jobs',
      data: {
        'match_id': matchId,
        'title': title,
        'video_url': videoUrl,
        'video_path': videoPath,
        'home_team_key': homeTeamKey,
        'away_team_key': awayTeamKey,
      },
    );

    return AiCreateJobResponse.fromJson(_normalizeJson(response.data));
  }

  Future<AiUploadVideoResponse> uploadVideo({
    required String jobId,
    required File file,
    ProgressCallback? onSendProgress,
  }) async {
    final filename = file.path.split('/').last;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: filename,
      ),
    });

    final response = await _dio.post(
      '/api/video-analysis/jobs/$jobId/upload',
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    return AiUploadVideoResponse.fromJson(_normalizeJson(response.data));
  }

  Future<AiRunAnalysisResponse> runJobAnalysis({
    required String jobId,
    double samplingFps = 5.0,
  }) async {
    final formData = FormData.fromMap({
      'sampling_fps': samplingFps,
    });

    final response = await _dio.post(
      '/api/video-analysis/jobs/$jobId/run',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    return AiRunAnalysisResponse.fromJson(_normalizeJson(response.data));
  }

  Future<AiJobStatus> getJobStatus(String jobId) async {
    final response = await _dio.get('/api/analysis/$jobId/status');
    return AiJobStatus.fromJson(_normalizeJson(response.data));
  }

  Future<AiSummaryResponse> getSummary(String jobId) async {
    final response = await _dio.get('/api/analysis/$jobId/summary');
    return AiSummaryResponse.fromJson(_normalizeJson(response.data));
  }

  Future<AiEventsResponse> getEvents(String jobId) async {
    final response = await _dio.get('/api/analysis/$jobId/events');
    return AiEventsResponse.fromJson(_normalizeJson(response.data));
  }

  Future<AiAutoTtdResponse> getAutoTtd(String jobId) async {
    final response = await _dio.get('/api/analysis/$jobId/auto-ttd');
    return AiAutoTtdResponse.fromJson(_normalizeJson(response.data));
  }

  Future<AiMatchStatsResponse> getMatchStats(String jobId) async {
    final response = await _dio.get('/api/analysis/$jobId/match-stats');
    return AiMatchStatsResponse.fromJson(_normalizeJson(response.data));
  }

  Future<AiAnalysisBundle> loadAnalysisBundle(String jobId) async {
    final results = await Future.wait([
      getSummary(jobId),
      getEvents(jobId),
      getAutoTtd(jobId),
      getMatchStats(jobId),
      getJobStatus(jobId),
    ]);

    return AiAnalysisBundle(
      summary: results[0] as AiSummaryResponse,
      events: results[1] as AiEventsResponse,
      autoTtd: results[2] as AiAutoTtdResponse,
      matchStats: results[3] as AiMatchStatsResponse,
      status: results[4] as AiJobStatus,
    );
  }

  Future<AiCreateAndRunResponse> createUploadAndRun({
    int? matchId,
    String? title,
    String homeTeamKey = 'home',
    String awayTeamKey = 'away',
    double samplingFps = 5.0,
    required File file,
    ProgressCallback? onSendProgress,
  }) async {
    final filename = file.path.split('/').last;

    final formData = FormData.fromMap({
      'match_id': matchId,
      'title': title,
      'home_team_key': homeTeamKey,
      'away_team_key': awayTeamKey,
      'sampling_fps': samplingFps,
      'file': await MultipartFile.fromFile(
        file.path,
        filename: filename,
      ),
    });

    final response = await _dio.post(
      '/api/video-analysis/jobs/create-and-run',
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    return AiCreateAndRunResponse.fromJson(_normalizeJson(response.data));
  }

  Map<String, dynamic> _normalizeJson(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);

    if (raw is String) {
      final cleaned = _extractJsonString(raw);
      final decoded = json.decode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Unexpected response format: ${raw.runtimeType}');
  }

  String _extractJsonString(String source) {
    final start = source.indexOf('{');
    if (start == -1) return source;
    return source.substring(start);
  }
}

class AiAnalysisBundle {
  final AiSummaryResponse summary;
  final AiEventsResponse events;
  final AiAutoTtdResponse autoTtd;
  final AiMatchStatsResponse matchStats;
  final AiJobStatus status;

  const AiAnalysisBundle({
    required this.summary,
    required this.events,
    required this.autoTtd,
    required this.matchStats,
    required this.status,
  });
}

class AiCreateAndRunResponse {
  final bool success;
  final String jobId;
  final Map<String, dynamic> upload;
  final AiRunAnalysisResponse analysis;

  const AiCreateAndRunResponse({
    required this.success,
    required this.jobId,
    required this.upload,
    required this.analysis,
  });

  factory AiCreateAndRunResponse.fromJson(Map<String, dynamic> json) {
    return AiCreateAndRunResponse(
      success: json['success'] == true,
      jobId: (json['job_id'] ?? '').toString(),
      upload: Map<String, dynamic>.from(json['upload'] ?? const {}),
      analysis: AiRunAnalysisResponse.fromJson(
        Map<String, dynamic>.from(json['analysis'] ?? const {}),
      ),
    );
  }
}