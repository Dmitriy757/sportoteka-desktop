import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_video_analysis_models.dart';

class AiVideoAnalysisService {
  final String baseUrl;
  final http.Client _client;

  AiVideoAnalysisService({
    required String baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalizedPath');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: query.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Future<AiJobCreateResponse> createJob(AiJobCreateRequest request) async {
    final uri = _uri('/api/video-analysis/jobs');
    final payload = request.toJson();

    // ignore: avoid_print
    print('AI CREATE JOB URL = $uri');
    // ignore: avoid_print
    print('AI CREATE JOB PAYLOAD = $payload');

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 45));

    final json = _decodeResponse(response);
    return AiJobCreateResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> runJob(
    String jobId, {
    double samplingFps = 0.5,
    double maxMinutes = 2.0,
  }) async {
    final uri = _uri('/api/video-analysis/jobs/$jobId/run');

    final request = http.MultipartRequest('POST', uri)
      ..fields['sampling_fps'] = samplingFps.toString()
      ..fields['max_minutes'] = maxMinutes.toString();

    final streamed = await request.send().timeout(const Duration(minutes: 10));
    final response = await http.Response.fromStream(streamed);

    return _decodeResponse(response);
  }

  Future<AiJobStatusResponse> getJobStatus(String jobId) async {
    final raw = await getJobStatusRaw(jobId);
    if (raw == null) {
      throw Exception('Empty AI job status');
    }
    return AiJobStatusResponse.fromJson(raw);
  }

  Future<Map<String, dynamic>?> getJobStatusRaw(String jobId) async {
    final uri = _uri('/api/video-analysis/jobs/$jobId');
    final response = await _client.get(uri).timeout(const Duration(seconds: 45));
    return _decodeResponse(response);
  }

  Future<AiJobStatusResponse> pollUntilDone(
    String jobId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 5),
    void Function(AiJobStatusResponse value)? onProgress,
  }) async {
    final startedAt = DateTime.now();

    while (DateTime.now().difference(startedAt) < timeout) {
      final status = await getJobStatus(jobId);
      onProgress?.call(status);

      if (status.isDone || status.isFailed) {
        return status;
      }

      await Future.delayed(interval);
    }

    throw TimeoutException('AI job polling timeout: $jobId');
  }

  Future<AiFramePacket> getFramePacket({
    required String jobId,
    required int timeMs,
  }) async {
    final uri = _uri(
      '/api/video-analysis/jobs/$jobId/frame',
      {'time_ms': timeMs},
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 45));
    final json = _decodeResponse(response);
    return AiFramePacket.fromJson(json);
  }

  Future<void> sendCalibration({
    required String jobId,
    required List<AiCalibrationPoint> points,
  }) async {
    final uri = _uri('/api/video-analysis/jobs/$jobId/calibration');
    final payload = {
      'points': points.map((e) => e.toJson()).toList(),
    };

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 45));

    _decodeResponse(response);
  }

  Future<AiPlayerSummary> getPlayerSummary({
    required String jobId,
    required String trackId,
  }) async {
    final uri = _uri('/api/video-analysis/jobs/$jobId/players/$trackId');
    final response = await _client.get(uri).timeout(const Duration(seconds: 45));
    return AiPlayerSummary.fromJson(_decodeResponse(response));
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.body;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body.isNotEmpty
          ? body
          : 'AI server error: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);

    throw Exception('AI server returned non-object JSON');
  }
}
