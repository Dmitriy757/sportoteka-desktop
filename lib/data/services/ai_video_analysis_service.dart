import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/ai_video_analysis_models.dart';

/// Native WebSocket client for SPORTOTEKA Video AI.
///
/// Production endpoint:
///   wss://sportotekaapp.ru/ws-video-analysis/
///
/// The legacy REST job API is preserved at the method level so the existing
/// controller/UI can keep using createJob -> runJob -> getFramePacket. Internally
/// these methods now use the real SPORTOTEKA Video AI WebSocket protocol.
class AiVideoAnalysisService {
  final String baseUrl;
  final String webSocketUrl;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<AiFramePacket> _frameController =
      StreamController<AiFramePacket>.broadcast();

  AiJobCreateRequest? _pendingRequest;
  String? _syntheticJobId;
  String? _activeMatchLiveId;
  Completer<Map<String, dynamic>>? _runCompleter;

  final List<AiFramePacket> _frameCache = <AiFramePacket>[];
  final List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  final Set<String> _eventKeys = <String>{};

  Map<String, dynamic>? _latestFrameRaw;
  Map<String, dynamic>? _latestReport;
  Map<String, dynamic>? _latestStatus;
  Map<String, dynamic> _latestStats = <String, dynamic>{};

  final Set<String> _sentPlayerBindings = <String>{};

  // 0..100 progress of the current recording analysis. The WebSocket server
  // doesn't send a dedicated progress field, so we derive it from the analyzed
  // video timestamp and fps/frame_count reported in each analysis_frame.
  int _progressPercent = 0;
  double _requestedMaxMinutes = 0.0;

  // WebSocket resilience. A recording analysis may run for more than an hour,
  // so a short network interruption must not turn a successfully started job
  // into "Video AI WebSocket disconnected".
  int _socketGeneration = 0;
  int _reconnectAttempts = 0;
  int _lastFrameTimeMs = 0;
  int _framePacketCount = 0;
  bool _reconnectInProgress = false;
  bool _stopRequested = false;
  bool _intentionalClose = false;
  Timer? _reconnectTimer;
  Timer? _resumeWatchdog;
  Map<String, dynamic>? _activeRunPayload;

  static const int _maxReconnectAttempts = 8;

  bool _disposed = false;

  AiVideoAnalysisService({
    required String baseUrl,
    String? webSocketUrl,
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        webSocketUrl = _normalizeWsUrl(
          (webSocketUrl == null || webSocketUrl.trim().isEmpty)
              ? _deriveWsUrl(baseUrl)
              : webSocketUrl,
        );

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<AiFramePacket> get framePackets => _frameController.stream;

  bool get isConnected => _socket?.readyState == WebSocket.open;
  String? get activeMatchLiveId => _activeMatchLiveId;

  static String _deriveWsUrl(String value) {
    final uri = Uri.parse(value.trim());
    if (uri.scheme == 'ws' || uri.scheme == 'wss') {
      return uri.toString();
    }

    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri
        .replace(
          scheme: wsScheme,
          path: '/ws-video-analysis/',
          query: null,
          fragment: null,
        )
        .toString();
  }

  static String _normalizeWsUrl(String value) {
    var result = value.trim();
    if (!result.endsWith('/')) result = '$result/';
    return result;
  }

  Future<void> connect({bool force = false}) async {
    if (_disposed) {
      throw StateError('AiVideoAnalysisService is already disposed');
    }

    if (isConnected && !force) return;

    final generation = ++_socketGeneration;

    final previousSubscription = _socketSubscription;
    _socketSubscription = null;
    if (previousSubscription != null) {
      try {
        await previousSubscription.cancel();
      } catch (_) {}
    }

    final previous = _socket;
    _socket = null;
    if (previous != null) {
      try {
        await previous.close();
      } catch (_) {}
    }

    final socket = await WebSocket.connect(webSocketUrl)
        .timeout(const Duration(seconds: 25));

    if (_disposed || generation != _socketGeneration) {
      try {
        await socket.close();
      } catch (_) {}
      return;
    }

    socket.pingInterval = const Duration(seconds: 20);

    _socket = socket;
    _socketSubscription = socket.listen(
      (raw) => _handleIncoming(raw, generation),
      onError: (Object error) => _handleSocketError(error, generation),
      onDone: () => _handleSocketDone(generation),
      cancelOnError: false,
    );
  }

  Future<AiJobCreateResponse> createJob(AiJobCreateRequest request) async {
    // Do NOT stop an already running analysis just because the UI asked to
    // "create" the same compatibility job again. The previous implementation
    // sent stop_analysis here, which made duplicate starts much more likely
    // after a transient UI/network event.
    final activeCompleter = _runCompleter;
    if (activeCompleter != null && !activeCompleter.isCompleted) {
      return AiJobCreateResponse(
        success: true,
        jobId: _activeMatchLiveId ?? _syntheticJobId ?? 'ws_active',
        status: 'processing',
        raw: <String, dynamic>{
          'success': true,
          'job_id': _activeMatchLiveId ?? _syntheticJobId ?? 'ws_active',
          'match_live_id': _activeMatchLiveId,
          'status': 'processing',
          'transport': 'websocket',
          'reused_active_job': true,
          'websocket_url': webSocketUrl,
        },
      );
    }

    _resetRunState();
    _pendingRequest = request;
    _syntheticJobId =
        'ws_${request.matchId ?? 0}_${DateTime.now().millisecondsSinceEpoch}';

    await connect();

    return AiJobCreateResponse(
      success: true,
      jobId: _syntheticJobId!,
      status: 'created',
      raw: <String, dynamic>{
        'success': true,
        'job_id': _syntheticJobId,
        'status': 'created',
        'transport': 'websocket',
        'websocket_url': webSocketUrl,
      },
    );
  }

  Future<Map<String, dynamic>> runJob(
    String jobId, {
    double samplingFps = 0.5,
    double maxMinutes = 2.0,
  }) async {
    // If this compatibility method is called twice while the same match is
    // already being processed, attach to the existing future instead of
    // sending a second start_recording_analysis.
    final existing = _runCompleter;
    if (existing != null && !existing.isCompleted) {
      return existing.future;
    }

    final request = _pendingRequest;
    if (request == null) {
      throw StateError('AI job was not created before runJob');
    }

    await connect();

    final source = (request.videoUrl ?? '').trim().isNotEmpty
        ? request.videoUrl!.trim()
        : (request.videoPath ?? request.localVideoPath ?? '').trim();

    if (source.isEmpty) {
      throw ArgumentError('videoUrl/videoPath is required for Video AI');
    }

    final completer = Completer<Map<String, dynamic>>();
    _runCompleter = completer;
    _requestedMaxMinutes = maxMinutes;
    _progressPercent = 1;
    _lastFrameTimeMs = 0;
    _framePacketCount = 0;
    _reconnectAttempts = 0;
    _stopRequested = false;
    _intentionalClose = false;

    final payload = <String, dynamic>{
      'action': 'start_recording_analysis',
      'video_url': source,
      'match_id': request.matchId,
      'team_id': request.teamId,
      'club_id': request.clubId,
      'team_name': request.title,
      'team_colors': request.teamColors,
      'home_team_key': request.homeTeamKey,
      'away_team_key': request.awayTeamKey,
      'focus_team': request.homeTeamKey,
      'sampling_fps': samplingFps,
      'max_minutes': maxMinutes,
    };
    payload.removeWhere(
      (_, value) =>
          value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is Map && value.isEmpty),
    );

    _activeRunPayload = Map<String, dynamic>.from(payload);
    _socket!.add(jsonEncode(payload));

    try {
      return await completer.future.timeout(const Duration(hours: 6));
    } on TimeoutException {
      await stopAnalysis();
      rethrow;
    } finally {
      if (identical(_runCompleter, completer)) {
        _runCompleter = null;
      }
      if (completer.isCompleted) {
        _activeRunPayload = null;
        _cancelReconnectTimers();
      }
    }
  }

  Future<AiJobStatusResponse> getJobStatus(String jobId) async {
    final raw = await getJobStatusRaw(jobId);
    if (raw == null) {
      throw Exception('Empty AI job status');
    }
    return AiJobStatusResponse.fromJson(raw);
  }

  Future<Map<String, dynamic>?> getJobStatusRaw(String jobId) async {
    return _buildAggregate();
  }

  Future<AiJobStatusResponse> pollUntilDone(
    String jobId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 5),
    void Function(AiJobStatusResponse value)? onProgress,
  }) async {
    final startedAt = DateTime.now();

    while (DateTime.now().difference(startedAt) < timeout) {
      final status = AiJobStatusResponse.fromJson(_buildAggregate());
      onProgress?.call(status);

      if (status.isDone || status.isFailed) return status;
      await Future.delayed(interval);
    }

    throw TimeoutException('AI job polling timeout: $jobId');
  }

  /// Returns the nearest already received WebSocket frame for the requested
  /// video timestamp. This keeps old UI code compatible with the former REST
  /// /frame endpoint while the live stream continues to feed frames in real time.
  Future<AiFramePacket> getFramePacket({
    required String jobId,
    required int timeMs,
  }) async {
    if (_frameCache.isEmpty) {
      try {
        await framePackets.first.timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    if (_frameCache.isEmpty) {
      return AiFramePacket.fromJson(<String, dynamic>{
        'success': true,
        'has_frame': false,
        'job_id': _activeMatchLiveId ?? _syntheticJobId ?? jobId,
        'requested_time_ms': timeMs,
        'time_ms': timeMs,
        'players': const <dynamic>[],
      });
    }

    AiFramePacket best = _frameCache.first;
    var bestDistance = (best.timeMs - timeMs).abs();

    for (final packet in _frameCache.skip(1)) {
      final distance = (packet.timeMs - timeMs).abs();
      if (distance < bestDistance) {
        best = packet;
        bestDistance = distance;
      }
    }

    return best;
  }

  /// The current Video AI WebSocket protocol doesn't expose calibration as a
  /// separate action. Keep this as a safe no-op for compatibility.
  Future<void> sendCalibration({
    required String jobId,
    required List<AiCalibrationPoint> points,
  }) async {
    _latestStatus = <String, dynamic>{
      ...?_latestStatus,
      'calibration_points': points.map((e) => e.toJson()).toList(),
    };
  }

  Future<AiPlayerSummary> getPlayerSummary({
    required String jobId,
    required String trackId,
  }) async {
    for (final packet in _frameCache.reversed) {
      for (final track in packet.tracks) {
        if (track.trackId == trackId) {
          return AiPlayerSummary(trackId: trackId, raw: track.raw);
        }
      }
    }

    return AiPlayerSummary(
      trackId: trackId,
      raw: <String, dynamic>{
        'track_id': trackId,
        'status': 'not_seen_yet',
      },
    );
  }

  Future<void> bindPlayer({
    required String trackId,
    required int playerId,
    required String playerName,
  }) async {
    if (_disposed || playerId <= 0 || trackId.trim().isEmpty) return;

    final matchLiveId = (_activeMatchLiveId ?? '').trim();
    if (matchLiveId.isEmpty) return;

    final numericTrackId = int.tryParse(trackId.trim());
    if (numericTrackId == null || numericTrackId <= 0) return;

    final key = '$matchLiveId|$numericTrackId|$playerId';
    if (_sentPlayerBindings.contains(key)) return;

    if (!isConnected) {
      try {
        await connect();
      } catch (_) {
        return;
      }
    }
    if (!isConnected) return;

    _socket!.add(jsonEncode(<String, dynamic>{
      'action': 'bind_player',
      'match_live_id': matchLiveId,
      'track_id': numericTrackId,
      'player_id': playerId,
      'player_name': playerName,
    }));
    _sentPlayerBindings.add(key);
  }

  Future<void> stopAnalysis() async {
    _stopRequested = true;
    _cancelReconnectTimers();
    if (isConnected) {
      _socket!.add(jsonEncode(<String, dynamic>{'action': 'stop_analysis'}));
    } else {
      _completeRun(_buildAggregate(statusOverride: 'stopped'));
    }
  }

  void _handleIncoming(dynamic raw, int generation) {
    if (_disposed || generation != _socketGeneration) return;

    try {
      final text = raw is String
          ? raw
          : raw is List<int>
              ? utf8.decode(raw)
              : raw.toString();
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;

      final message = Map<String, dynamic>.from(decoded);
      _handleMessage(message);
    } catch (_) {
      // Keep the WebSocket alive if one malformed packet is received.
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = (message['type'] ?? '').toString();
    final status = (message['status'] ?? '').toString().toLowerCase().trim();

    if (!_messageController.isClosed) {
      _messageController.add(message);
    }

    if (type == 'match_started') {
      _activeMatchLiveId =
          (message['match_live_id'] ?? _activeMatchLiveId)?.toString();
      _latestStatus = message;
      return;
    }

    if (type == 'analysis_frame') {
      _activeMatchLiveId =
          (message['match_live_id'] ?? _activeMatchLiveId)?.toString();

      _framePacketCount += 1;
      final rawTime = message['time_ms'] ?? message['timestamp'];
      final parsedTime = rawTime is num
          ? rawTime.toInt()
          : int.tryParse('${rawTime ?? ''}') ?? 0;
      if (parsedTime > _lastFrameTimeMs) {
        _lastFrameTimeMs = parsedTime;
      }

      // A frame after reconnect proves the resumed stream is alive.
      _resumeWatchdog?.cancel();
      _resumeWatchdog = null;
      _reconnectAttempts = 0;
      _reconnectInProgress = false;

      final stats = message['stats'];
      if (stats is Map) {
        _latestStats = Map<String, dynamic>.from(stats);
      }

      _progressPercent = _deriveProgressPercent(message, _latestStats);

      final rawWithJob = <String, dynamic>{
        ...message,
        'job_id': message['job_id'] ??
            message['match_live_id'] ??
            _activeMatchLiveId ??
            _syntheticJobId,
        'status': 'processing',
        'progress': _progressPercent,
      };

      final packet = AiFramePacket.fromJson(rawWithJob);
      _latestFrameRaw = rawWithJob;

      _appendEvents(message['events']);

      _frameCache.add(packet);
      if (_frameCache.length > 12000) {
        _frameCache.removeRange(0, _frameCache.length - 12000);
      }

      if (!_frameController.isClosed) {
        _frameController.add(packet);
      }
      return;
    }

    if (type == 'match_report') {
      final report = message['report'];
      if (report is Map) {
        _latestReport = Map<String, dynamic>.from(report);
        _appendEvents(_latestReport!['events']);
        final stats = _latestReport!['stats'] ?? _latestReport!['final_stats'];
        if (stats is Map) {
          _latestStats = Map<String, dynamic>.from(stats);
        }
      }
      return;
    }

    if (type == 'status') {
      _latestStatus = message;
      _activeMatchLiveId =
          (message['match_live_id'] ?? _activeMatchLiveId)?.toString();

      if (status == 'done' ||
          status == 'completed' ||
          status == 'complete' ||
          status == 'finished') {
        _completeRun(_buildAggregate(statusOverride: 'completed'));
      } else if (status == 'failed' || status == 'error') {
        final error = (message['message'] ?? message['error'] ?? 'Video AI failed')
            .toString();
        _completeRunError(error);
      } else if (status == 'stopped') {
        _completeRun(_buildAggregate(statusOverride: 'stopped'));
      }
      return;
    }

    if (type == 'error') {
      final error = (message['message'] ?? message['error'] ?? 'Video AI error')
          .toString();
      final code = (message['code'] ?? '').toString();

      // The old socket's server task can need a few seconds to stop. A newly
      // opened socket may temporarily receive analysis_busy. Retry instead of
      // converting this into a visible fatal error.
      if (code == 'analysis_busy' &&
          _runCompleter != null &&
          !_runCompleter!.isCompleted &&
          !_stopRequested) {
        _resumeWatchdog?.cancel();
        _resumeWatchdog = null;
        _scheduleReconnect('analysis_busy');
        return;
      }

      _latestStatus = <String, dynamic>{
        ...message,
        'status': 'failed',
        'error': error,
      };
      _completeRunError(error);
    }
  }


  int _deriveProgressPercent(
    Map<String, dynamic> message,
    Map<String, dynamic> stats,
  ) {
    final currentMs = _asDouble(message['time_ms'] ?? message['timestamp']);
    final fps = _asDouble(stats['fps']);
    final frameCount = _asDouble(stats['frame_count']);

    double totalMs = 0.0;
    if (fps > 0 && frameCount > 0) {
      totalMs = frameCount / fps * 1000.0;
    }

    if (_requestedMaxMinutes > 0) {
      final requestedMs = _requestedMaxMinutes * 60.0 * 1000.0;
      if (totalMs <= 0 || requestedMs < totalMs) {
        totalMs = requestedMs;
      }
    }

    if (totalMs <= 0) {
      // We know analysis is alive as soon as the first frame arrives. Keep a
      // visible non-zero progress until duration metadata becomes available.
      return _progressPercent <= 0 ? 1 : _progressPercent.clamp(1, 99);
    }

    final percent = ((currentMs / totalMs) * 100.0).floor();
    return percent.clamp(1, 99);
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0.0;
  }

  void _appendEvents(dynamic raw) {
    if (raw is! List) return;

    for (final item in raw) {
      if (item is! Map) continue;
      final event = Map<String, dynamic>.from(item);
      final key = (event['id'] ??
              '${event['type'] ?? event['event_type'] ?? ''}|'
                  '${event['time_ms'] ?? event['start_ms'] ?? ''}|'
                  '${event['track_id'] ?? event['player_id'] ?? ''}')
          .toString();

      if (_eventKeys.add(key)) {
        _events.add(event);
      }
    }

    if (_events.length > 5000) {
      final removeCount = _events.length - 5000;
      _events.removeRange(0, removeCount);
      _eventKeys
        ..clear()
        ..addAll(_events.map((event) => (event['id'] ??
                '${event['type'] ?? event['event_type'] ?? ''}|'
                    '${event['time_ms'] ?? event['start_ms'] ?? ''}|'
                    '${event['track_id'] ?? event['player_id'] ?? ''}')
            .toString()));
    }
  }

  Map<String, dynamic> _buildAggregate({String? statusOverride}) {
    final status = statusOverride ??
        (_latestStatus?['status'] ??
                (_runCompleter != null && !_runCompleter!.isCompleted
                    ? 'processing'
                    : 'created'))
            .toString();

    final report = _latestReport ?? const <String, dynamic>{};

    return <String, dynamic>{
      ...report,
      'success': status != 'failed' && status != 'error',
      'job_id': _activeMatchLiveId ?? _syntheticJobId ?? '',
      'match_live_id': _activeMatchLiveId,
      'status': status,
      'progress': (status == 'completed' || status == 'done')
          ? 100
          : _progressPercent.clamp(0, 99),
      'events': List<Map<String, dynamic>>.from(_events),
      // Existing Flutter analytics understands auto_ttd. The Video AI event
      // engine already emits the source actions, so expose them under both keys.
      'auto_ttd': List<Map<String, dynamic>>.from(_events),
      'stats': Map<String, dynamic>.from(_latestStats),
      if (_latestFrameRaw != null) 'latest_frame': _latestFrameRaw,
      if (_latestReport != null) 'report': _latestReport,
      if (_latestStatus?['error'] != null) 'error': _latestStatus!['error'],
    };
  }

  void _completeRun(Map<String, dynamic> result) {
    final completer = _runCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  void _completeRunError(String message) {
    final completer = _runCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(Exception(message));
    }
  }

  void _handleSocketError(Object error, int generation) {
    if (_disposed ||
        _intentionalClose ||
        generation != _socketGeneration) {
      return;
    }

    _scheduleReconnect('socket_error: $error');
  }

  void _handleSocketDone(int generation) {
    if (generation != _socketGeneration) return;

    _socket = null;
    if (_disposed || _intentionalClose || _stopRequested) {
      return;
    }

    _scheduleReconnect('socket_done');
  }

  void _scheduleReconnect(String reason) {
    final completer = _runCompleter;
    if (_disposed ||
        _intentionalClose ||
        _stopRequested ||
        completer == null ||
        completer.isCompleted) {
      return;
    }

    if (_reconnectTimer != null || _reconnectInProgress) {
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _latestStatus = <String, dynamic>{
        'status': 'failed',
        'error':
            'Video AI connection lost after $_reconnectAttempts reconnect attempts',
      };
      _completeRunError(
        'Video AI WebSocket disconnected after $_reconnectAttempts reconnect attempts',
      );
      return;
    }

    final nextAttempt = _reconnectAttempts + 1;
    final delayMs = nextAttempt <= 2
        ? 1200 * nextAttempt
        : nextAttempt <= 4
            ? 3000
            : 5000;

    _emitSyntheticStatus(
      status: 'reconnecting',
      message:
          'Восстанавливаю связь с Video AI • попытка $nextAttempt/$_maxReconnectAttempts',
      extra: <String, dynamic>{
        'reconnect_attempt': nextAttempt,
        'resume_from_ms': _lastFrameTimeMs,
        'reason': reason,
      },
    );

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      _reconnectTimer = null;
      unawaited(_reconnectAndResume(nextAttempt));
    });
  }

  Future<void> _reconnectAndResume(int attempt) async {
    final completer = _runCompleter;
    final basePayload = _activeRunPayload;

    if (_disposed ||
        _intentionalClose ||
        _stopRequested ||
        completer == null ||
        completer.isCompleted ||
        basePayload == null) {
      return;
    }

    if (_reconnectInProgress) return;
    _reconnectInProgress = true;
    _reconnectAttempts = attempt;

    try {
      await connect(force: true);

      if (_disposed ||
          _intentionalClose ||
          _stopRequested ||
          !isConnected ||
          _runCompleter == null ||
          _runCompleter!.isCompleted) {
        _reconnectInProgress = false;
        return;
      }

      final resumeFromMs =
          _lastFrameTimeMs > 1500 ? _lastFrameTimeMs - 1500 : 0;
      final previousMatchLiveId = _activeMatchLiveId;
      final packetCountBeforeResume = _framePacketCount;

      final payload = <String, dynamic>{
        ...basePayload,
        'resume_from_ms': resumeFromMs,
        'resume_attempt': attempt,
        if (previousMatchLiveId != null && previousMatchLiveId.isNotEmpty)
          'resume_previous_match_live_id': previousMatchLiveId,
      };

      _socket!.add(jsonEncode(payload));

      _emitSyntheticStatus(
        status: 'reconnecting',
        message:
            'Связь восстановлена, продолжаю AI с ${Duration(milliseconds: resumeFromMs)}',
        extra: <String, dynamic>{
          'reconnect_attempt': attempt,
          'resume_from_ms': resumeFromMs,
        },
      );

      // If the connection opens but the server never resumes sending frames,
      // force another reconnect rather than hanging forever.
      _resumeWatchdog?.cancel();
      _resumeWatchdog = Timer(const Duration(seconds: 14), () {
        if (_disposed ||
            _stopRequested ||
            _runCompleter == null ||
            _runCompleter!.isCompleted) {
          return;
        }

        if (_framePacketCount == packetCountBeforeResume) {
          final socket = _socket;
          _socket = null;
          if (socket != null) {
            unawaited(socket.close());
          }
          _reconnectInProgress = false;
          _scheduleReconnect('resume_watchdog');
        }
      });
    } catch (error) {
      _reconnectInProgress = false;
      _scheduleReconnect('reconnect_failed: $error');
      return;
    }

    _reconnectInProgress = false;
  }

  void _emitSyntheticStatus({
    required String status,
    required String message,
    Map<String, dynamic>? extra,
  }) {
    final payload = <String, dynamic>{
      'type': 'status',
      'status': status,
      'message': message,
      'job_id': _activeMatchLiveId ?? _syntheticJobId ?? '',
      'match_live_id': _activeMatchLiveId,
      'progress': _progressPercent.clamp(0, 99),
      ...?extra,
    };

    _latestStatus = payload;
    if (!_messageController.isClosed) {
      _messageController.add(payload);
    }
  }

  void _cancelReconnectTimers() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _resumeWatchdog?.cancel();
    _resumeWatchdog = null;
    _reconnectInProgress = false;
  }

  void _resetRunState() {
    _cancelReconnectTimers();
    _activeMatchLiveId = null;
    _latestFrameRaw = null;
    _latestReport = null;
    _latestStatus = null;
    _latestStats = <String, dynamic>{};
    _progressPercent = 0;
    _requestedMaxMinutes = 0.0;
    _lastFrameTimeMs = 0;
    _framePacketCount = 0;
    _reconnectAttempts = 0;
    _stopRequested = false;
    _intentionalClose = false;
    _activeRunPayload = null;
    _sentPlayerBindings.clear();
    _frameCache.clear();
    _events.clear();
    _eventKeys.clear();
  }

  Future<void> close() async {
    if (_disposed) return;

    _intentionalClose = true;
    _disposed = true;
    _cancelReconnectTimers();
    ++_socketGeneration;

    final subscription = _socketSubscription;
    _socketSubscription = null;
    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (_) {}
    }

    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close(WebSocketStatus.normalClosure, 'SPORTOTEKA dispose');
      } catch (_) {}
    }

    await _messageController.close();
    await _frameController.close();
  }

}
