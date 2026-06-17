import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/models/ai_video_analysis_models.dart';
import '../../data/services/ai_video_analysis_service.dart';

class AiVideoAnalysisController extends ChangeNotifier {
  final AiVideoAnalysisService service;

  AiVideoAnalysisController({
    required this.service,
  });

  String? jobId;
  bool isCreatingJob = false;
  bool isPollingStatus = false;
  bool isLoadingFrame = false;
  bool isSendingCalibration = false;
  bool isLoadingSummary = false;
  bool isStartingRun = false;

  String? errorText;

  AiJobStatusResponse? jobStatus;
  AiFramePacket? currentFramePacket;
  AiPlayerSummary? currentPlayerSummary;

  int _lastRequestedTimeMs = -1;
  Timer? _frameDebounce;

  bool get hasJob => jobId != null && jobId!.isNotEmpty;
  bool get isReady => jobStatus?.isDone == true;

  Future<String?> createAnalysisJob({
    int? matchId,
    String? videoUrl,
    String? localVideoPath,
  }) async {
    isCreatingJob = true;
    errorText = null;
    notifyListeners();

    try {
      final response = await service.createJob(
        AiJobCreateRequest(
          matchId: matchId,
          videoUrl: videoUrl,
          localVideoPath: localVideoPath,
        ),
      );

      jobId = response.jobId;
      debugPrint('✅ Job created: $jobId');
      notifyListeners();
      return response.jobId;
    } catch (e) {
      errorText = e.toString();
      debugPrint('❌ Failed to create job: $errorText');
      notifyListeners();
      return null;
    } finally {
      isCreatingJob = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> runAnalysisJob({
    double samplingFps = 1.0,
    double maxMinutes = 2.0,
  }) async {
    if (!hasJob || jobId == null || jobId!.isEmpty) return null;

    isStartingRun = true;
    errorText = null;
    notifyListeners();

    try {
      debugPrint(
        '🚀 runAnalysisJob params: samplingFps=$samplingFps, maxMinutes=$maxMinutes, jobId=$jobId',
      );

      final result = await service.runJob(
        jobId!,
        samplingFps: samplingFps,
        maxMinutes: maxMinutes,
      );

      return result;
    } catch (e) {
      errorText = e.toString();
      debugPrint('❌ runAnalysisJob error: $errorText');
      return null;
    } finally {
      isStartingRun = false;
      notifyListeners();
    }
  }

  Future<AiJobStatusResponse?> refreshStatus() async {
    if (!hasJob) return null;

    try {
      final status = await service.getJobStatus(jobId!);
      jobStatus = status;
      errorText = null;
      debugPrint('🔄 Status refreshed: ${status.status}');
      notifyListeners();
      return status;
    } catch (e) {
      errorText = e.toString();
      debugPrint('❌ Failed to refresh status: $errorText');
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> loadJobStatus() async {
    if (!hasJob) return null;

    try {
      final result = await service.getJobStatusRaw(jobId!);
      if (result == null) return null;
      errorText = null;
      notifyListeners();
      return Map<String, dynamic>.from(result);
    } catch (e) {
      errorText = e.toString();
      debugPrint('❌ Failed to load job status raw: $errorText');
      notifyListeners();
      return null;
    }
  }

  Future<bool> waitUntilDone({
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 5),
    bool skipStatusCheck = false,
  }) async {
    if (!hasJob) {
      debugPrint('❌ No job ID available');
      return false;
    }

    if (skipStatusCheck) {
      debugPrint(
        '⏳ Skipping status check, waiting ${timeout.inSeconds} seconds...',
      );
      await Future.delayed(timeout);
      return true;
    }

    isPollingStatus = true;
    errorText = null;
    notifyListeners();

    try {
      debugPrint('⏳ Starting waitUntilDone for job: $jobId');

      final status = await service.pollUntilDone(
        jobId!,
        interval: interval,
        timeout: timeout,
        onProgress: (value) {
          jobStatus = value;
          debugPrint('📊 Progress update: ${value.status}');
          notifyListeners();
        },
      );

      jobStatus = status;
      debugPrint('🏁 Final status: ${status.status}');

      if (status.isFailed) {
        errorText = status.error ?? 'AI анализ завершился с ошибкой';
        debugPrint('❌ Analysis failed: $errorText');
        notifyListeners();
        return false;
      }

      debugPrint('✅ Analysis completed successfully!');
      return status.isDone;
    } catch (e) {
      errorText = e.toString();
      debugPrint('❌ waitUntilDone error: $errorText');
      notifyListeners();
      return false;
    } finally {
      isPollingStatus = false;
      notifyListeners();
    }
  }

  Future<AiFramePacket?> loadFramePacket(int timeMs) async {
    if (!hasJob) {
      debugPrint('❌ No job ID for frame packet');
      return null;
    }

    isLoadingFrame = true;
    errorText = null;
    notifyListeners();

    try {
      debugPrint('📸 Loading frame packet for job: $jobId at ${timeMs}ms');

      final packet = await service.getFramePacket(
        jobId: jobId!,
        timeMs: timeMs,
      );

      currentFramePacket = packet;
      _lastRequestedTimeMs = timeMs;
      debugPrint('✅ Frame packet loaded: ${packet.tracks.length} tracks');
      notifyListeners();
      return packet;
    } catch (e) {
      errorText = e.toString();
      debugPrint('❌ Failed to load frame packet: $errorText');
      notifyListeners();
      return null;
    } finally {
      isLoadingFrame = false;
      notifyListeners();
    }
  }

  void loadFramePacketDebounced(
    int timeMs, {
    Duration delay = const Duration(milliseconds: 120),
  }) {
    if (!hasJob) return;

    if ((timeMs - _lastRequestedTimeMs).abs() < 60) {
      return;
    }

    _frameDebounce?.cancel();
    _frameDebounce = Timer(delay, () {
      unawaited(loadFramePacket(timeMs));
    });
  }

  Future<bool> submitCalibration(List<AiCalibrationPoint> points) async {
    if (!hasJob) return false;

    isSendingCalibration = true;
    errorText = null;
    notifyListeners();

    try {
      await service.sendCalibration(
        jobId: jobId!,
        points: points,
      );
      debugPrint('✅ Calibration sent successfully');
      return true;
    } catch (e) {
      errorText = e.toString();
      debugPrint('❌ Failed to send calibration: $errorText');
      notifyListeners();
      return false;
    } finally {
      isSendingCalibration = false;
      notifyListeners();
    }
  }

  Future<AiPlayerSummary?> loadPlayerSummary(String trackId) async {
    if (!hasJob) return null;

    isLoadingSummary = true;
    errorText = null;
    notifyListeners();

    try {
      final summary = await service.getPlayerSummary(
        jobId: jobId!,
        trackId: trackId,
      );

      currentPlayerSummary = summary;
      debugPrint('✅ Player summary loaded for track: $trackId');
      notifyListeners();
      return summary;
    } catch (e) {
      errorText = e.toString();
      debugPrint('❌ Failed to load player summary: $errorText');
      notifyListeners();
      return null;
    } finally {
      isLoadingSummary = false;
      notifyListeners();
    }
  }

  void clearSession() {
    _frameDebounce?.cancel();
    _frameDebounce = null;

    jobId = null;
    jobStatus = null;
    currentFramePacket = null;
    currentPlayerSummary = null;
    errorText = null;
    _lastRequestedTimeMs = -1;

    debugPrint('🧹 Session cleared');
    notifyListeners();
  }

  @override
  void dispose() {
    _frameDebounce?.cancel();
    super.dispose();
  }
}