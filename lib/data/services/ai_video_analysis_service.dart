import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/ai_video_analysis_models.dart';

class AiVideoAnalysisService {
  final Dio _dio;

  AiVideoAnalysisService({
    required String baseUrl,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 60),
                headers: const {
  'Accept': 'application/json',
},

              ),
            );

  Future<AiJobCreateResponse> createJob(AiJobCreateRequest request) async {
    try {
      debugPrint('AI BASE URL = ${_dio.options.baseUrl}');
      debugPrint(
        'AI CREATE JOB URL = ${_dio.options.baseUrl}/api/video-analysis/jobs',
      );
      debugPrint('AI CREATE JOB PAYLOAD = ${request.toJson()}');

      final response = await _dio.post(
        '/api/video-analysis/jobs',
        data: request.toJson(),
      );

      debugPrint('📦 FULL CREATE RESPONSE: ${response.data}');
      debugPrint('📦 RESPONSE TYPE: ${response.data.runtimeType}');

      if (response.data is String) {
        return AiJobCreateResponse(
          jobId: response.data as String,
          success: true,
        );
      }

      if (response.data is Map) {
        final dataMap = Map<String, dynamic>.from(response.data as Map);

        if (dataMap['job_id'] != null) {
          return AiJobCreateResponse.fromJson(dataMap);
        }

        final jobMap = dataMap['job'];
        if (jobMap is Map && jobMap['job_id'] != null) {
          return AiJobCreateResponse(
            jobId: jobMap['job_id'].toString(),
            success: dataMap['success'] == true,
          );
        }
      }

      throw Exception('Сервер не вернул job_id');
    } on DioException catch (e) {
      debugPrint('AI DIO ERROR: ${e.response?.data}');
      throw Exception(_extractError(e, 'Не удалось создать AI job'));
    }
  }

Future<Map<String, dynamic>?> runJob(
  String jobId, {
  double samplingFps = 1.0,
  double maxMinutes = 2.0,
}) async {
  try {
    debugPrint(
      '▶️ RUN JOB URL = ${_dio.options.baseUrl}/api/video-analysis/jobs/$jobId/run',
    );
    debugPrint(
      '▶️ RUN JOB PARAMS: sampling_fps=$samplingFps, max_minutes=$maxMinutes',
    );

    final formData = FormData.fromMap({
      'sampling_fps': samplingFps,
      'max_minutes': maxMinutes,
    });

    final response = await _dio.post(
      '/api/video-analysis/jobs/$jobId/run',
      data: formData,
      options: Options(
        contentType: Headers.multipartFormDataContentType,
        sendTimeout: const Duration(minutes: 15),
        receiveTimeout: const Duration(minutes: 15),
      ),
    );

    debugPrint('✅ RUN RESPONSE: ${response.data}');

    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }

    return null;
  } on DioException catch (e) {
    debugPrint('❌ RUN ERROR TYPE: ${e.type}');
    debugPrint('❌ RUN ERROR MESSAGE: ${e.message}');
    debugPrint('❌ RUN ERROR: ${e.error}');
    debugPrint('❌ RUN ERROR CODE: ${e.response?.statusCode}');
    debugPrint('❌ RUN ERROR DATA: ${e.response?.data}');
    throw Exception(_extractError(e, 'Не удалось запустить AI анализ'));
  }
}

  Future<AiJobStatusResponse> getJobStatus(String jobId) async {
    try {
      debugPrint('🔍 Getting status for job: $jobId');

      final response = await _dio.get('/api/video-analysis/jobs/$jobId');

      debugPrint('📡 STATUS CODE: ${response.statusCode}');
      debugPrint('📦 STATUS DATA: ${response.data}');

      final raw = _normalizeJobStatusPayload(response.data, jobId);
      if (raw == null) {
        throw Exception('Пустой или некорректный ответ статуса AI job');
      }

      return AiJobStatusResponse.fromJson(raw);
    } on DioException catch (e) {
      debugPrint('❌ STATUS ERROR: ${e.response?.statusCode}');
      debugPrint('❌ STATUS ERROR DATA: ${e.response?.data}');
      throw Exception(_extractError(e, 'Не удалось получить статус AI job'));
    }
  }

  Future<Map<String, dynamic>?> getJobStatusRaw(String jobId) async {
  try {
    final response = await _dio.get('/api/video-analysis/jobs/$jobId');
    return _normalizeJobStatusPayload(response.data, jobId);
  } on DioException catch (e) {
    debugPrint('❌ RAW STATUS ERROR TYPE: ${e.type}');
    debugPrint('❌ RAW STATUS ERROR MESSAGE: ${e.message}');
    debugPrint('❌ RAW STATUS ERROR CODE: ${e.response?.statusCode}');
    debugPrint('❌ RAW STATUS ERROR DATA: ${e.response?.data}');
    return null;
  }
}
  
  Future<AiFramePacket> getFramePacket({
    required String jobId,
    required int timeMs,
  }) async {
    try {
      debugPrint('📸 Getting frame packet for job: $jobId at ${timeMs}ms');

      final response = await _dio.get(
        '/api/video-analysis/jobs/$jobId/frame',
        queryParameters: {
          'time_ms': timeMs,
        },
      );

      debugPrint('✅ Frame packet received');

      return AiFramePacket.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      debugPrint('❌ Frame packet error: ${e.response?.statusCode}');
      throw Exception(_extractError(e, 'Не удалось получить frame packet'));
    }
  }

  Future<void> sendCalibration({
    required String jobId,
    required List<AiCalibrationPoint> points,
  }) async {
    try {
      await _dio.post(
        '/api/video-analysis/jobs/$jobId/calibration',
        data: {
          'points': points.map((e) => e.toJson()).toList(),
        },
      );
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'Не удалось отправить калибровку'));
    }
  }

  Future<AiPlayerSummary> getPlayerSummary({
    required String jobId,
    required String trackId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/video-analysis/jobs/$jobId/player/$trackId/summary',
      );

      return AiPlayerSummary.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'Не удалось получить summary игрока'));
    }
  }

  Future<Map<String, dynamic>?> getJobResults(String jobId) async {
    try {
      final urls = [
        '/api/video-analysis/jobs/$jobId/results',
        '/api/video-analysis/jobs/$jobId/result',
        '/api/video-analysis/results/$jobId',
      ];

      for (final url in urls) {
        try {
          final response = await _dio.get(url);
          if (response.statusCode == 200 && response.data != null) {
            debugPrint('✅ Found results at: $url');
            return response.data is Map
                ? Map<String, dynamic>.from(response.data as Map)
                : null;
          }
        } catch (_) {
          debugPrint('❌ No results at: $url');
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> listJobs() async {
    try {
      final response = await _dio.get('/api/video-analysis/jobs');
      debugPrint('📋 ALL JOBS: ${response.data}');
      return response.data is List ? response.data as List : [];
    } catch (e) {
      debugPrint('Failed to list jobs: $e');
      return [];
    }
  }

  Future<AiJobStatusResponse> pollUntilDone(
    String jobId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 30),
    void Function(AiJobStatusResponse status)? onProgress,
  }) async {
    final startedAt = DateTime.now();
    int createdAttempts = 0;
    int notFoundAttempts = 0;

    while (true) {
      if (DateTime.now().difference(startedAt) > timeout) {
        throw Exception('Таймаут ожидания AI анализа');
      }

      final status = await getJobStatus(jobId);
      onProgress?.call(status);

      if (status.status == 'not_found') {
        notFoundAttempts++;
        debugPrint(
          '⚠️ Job not found yet, waiting... (attempt $notFoundAttempts)',
        );

        if (notFoundAttempts >= 5) {
          throw Exception('AI job не найден на сервере: $jobId');
        }

        await Future.delayed(interval);
        continue;
      }

      if (status.status == 'created' || status.status == 'queued') {
        createdAttempts++;
        debugPrint(
          '⏳ Job exists but not started yet: ${status.status} (attempt $createdAttempts)',
        );

        if (createdAttempts >= 120) {
          throw Exception('AI job завис в статусе ${status.status}');
        }

        await Future.delayed(interval);
        continue;
      }

      createdAttempts = 0;
      notFoundAttempts = 0;

      if (status.isDone || status.isFailed) {
        return status;
      }

      await Future.delayed(interval);
    }
  }

  Map<String, dynamic>? _normalizeJobStatusPayload(dynamic data, String jobId) {
    if (data == null) return null;
    if (data is! Map) return null;

    final map = Map<String, dynamic>.from(data as Map);
    final nestedJob = map['job'] is Map
        ? Map<String, dynamic>.from(map['job'] as Map)
        : <String, dynamic>{};

    return <String, dynamic>{
      ...map,
      'job_id': map['job_id'] ?? nestedJob['job_id'] ?? jobId,
      'status': map['status'] ?? nestedJob['status'] ?? 'created',
      'progress': map['progress'] ?? nestedJob['progress'] ?? 0,
      'message': map['message'] ?? nestedJob['message'] ?? 'AI job found',
      'error': map['error'] ?? nestedJob['error'],
    };
  }

  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;

    if (data is Map<String, dynamic>) {
      final detail = data['detail']?.toString();
      final message = data['message']?.toString();
      final error = data['error']?.toString();
      return detail ?? message ?? error ?? fallback;
    }

    if (data is Map) {
      final mapped = Map<String, dynamic>.from(data);
      final detail = mapped['detail']?.toString();
      final message = mapped['message']?.toString();
      final error = mapped['error']?.toString();
      return detail ?? message ?? error ?? fallback;
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    return fallback;
  }
}