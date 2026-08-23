// lib/presentation/advanced_video_analysis/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/analysis_result.dart';

class WebSocketService {
  static const String wsUrl = 'wss://sportotekaapp.ru/ws-video-analysis/';

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _reconnectTimer;
  Timer? _noDataTimer;
  bool _disposed = false;
  bool _manualClose = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  int _connectToken = 0;
  Map<String, dynamic>? _lastRequest;
  String _lastRequestKey = '';

  final _analysisController = StreamController<AnalysisResult>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _packetController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<AnalysisResult> get analysisStream => _analysisController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get packetStream => _packetController.stream;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  /// Backwards-compatible recording start. Match/team/tracker metadata is sent
  /// when it is present in [params].
  Future<void> connect(
    String videoUrl, {
    Map<String, dynamic>? params,
  }) {
    final sourceMode = (params?['sourceMode'] ?? params?['source_mode'] ?? 'recording')
        .toString()
        .toLowerCase();
    final payload = _protocolParams(params);
    payload['action'] = sourceMode == 'live'
        ? 'start_live_match'
        : 'start_recording_analysis';
    if (videoUrl.trim().isNotEmpty) payload['video_url'] = videoUrl.trim();
    return connectRequest(payload);
  }

  /// Opens a control connection and asks for cameras without starting analysis.
  Future<void> connectControl() => connectRequest({'action': 'list_cameras'});

  Future<void> connectRequest(Map<String, dynamic> request) async {
    if (_disposed) return;
    final payload = Map<String, dynamic>.from(request);
    final mode = (payload['source_mode'] ?? payload['sourceMode'] ?? '').toString();
    final action = (payload['action'] ?? '').toString();
    final isLive = mode == 'live' || action == 'start_live_match' || action == 'start_live';
    final videoUrl = (payload['video_url'] ?? payload['videoUrl'] ?? '').toString();
    if (!isLive && action != 'list_cameras' && videoUrl.trim().isEmpty) {
      _safeStatus('❌ Не передан video_url');
      return;
    }

    final requestKey = jsonEncode(payload);
    if (_isConnecting) return;
    if (_isConnected && requestKey == _lastRequestKey) return;
    _lastRequest = payload;
    _lastRequestKey = requestKey;
    _manualClose = false;
    _isConnecting = true;
    final token = ++_connectToken;
    await _closeCurrentChannel(silent: true, bumpToken: false);

    try {
      _safeStatus('🔄 Подключение к AI-серверу...');
      final socket = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 18),
        onTimeout: () => throw TimeoutException('AI-сервер не ответил за 18 секунд'),
      );
      socket.pingInterval = const Duration(seconds: 15);
      if (_disposed || _manualClose || token != _connectToken) {
        await socket.close();
        return;
      }

      final channel = IOWebSocketChannel(socket);
      _channel = channel;
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _channelSub = channel.stream.listen(
        _handleMessage,
        onError: (Object error) {
          _safeStatus('❌ Ошибка WebSocket: $error');
          _isConnected = false;
          _isConnecting = false;
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _isConnecting = false;
          if (!_manualClose && !_disposed) {
            _safeStatus('🔴 Соединение закрыто. Пробую переподключиться...');
            _scheduleReconnect();
          }
        },
      );
      channel.sink.add(jsonEncode(payload));
      _safeStatus(action == 'list_cameras'
          ? '✅ Подключено. Получаю камеры...'
          : '✅ Подключено. Запускаю анализ...');
      _startNoDataTimer();
    } on TimeoutException {
      _connectFailure('❌ Таймаут подключения к AI-серверу');
    } on SocketException catch (error) {
      _connectFailure('❌ AI-сервер недоступен: $error');
    } catch (error, stack) {
      debugPrint('WebSocket connect failed: $error\n$stack');
      _connectFailure('❌ Ошибка подключения к AI-серверу: $error');
    }
  }

  void send(Map<String, dynamic> payload) {
    if (!_isConnected || _channel == null) {
      _safeStatus('❌ Нет соединения с AI-сервером');
      return;
    }
    _channel!.sink.add(jsonEncode(payload));
  }

  void listCameras() => send({'action': 'list_cameras'});

  void stop({String? matchLiveId}) => send({
        'action': 'stop_match',
        if ((matchLiveId ?? '').isNotEmpty) 'match_live_id': matchLiveId,
      });

  void bindPlayer({
    required String matchLiveId,
    required int trackId,
    required int playerId,
    String playerName = '',
  }) =>
      send({
        'action': 'bind_player',
        'match_live_id': matchLiveId,
        'track_id': trackId,
        'player_id': playerId,
        'player_name': playerName,
      });

  void reviewEvent({
    required String eventId,
    required bool confirmed,
    int? coachId,
    Map<String, dynamic>? correction,
  }) =>
      send({
        'action': correction == null
            ? (confirmed ? 'confirm_event' : 'reject_event')
            : 'correct_event',
        'event_id': eventId,
        if (coachId != null) 'coach_id': coachId,
        if (correction != null) 'correction': correction,
      });

  void requestReport(String matchLiveId) => send({
        'action': 'get_match_report',
        'match_live_id': matchLiveId,
      });

  void requestTrainingDataset({String? matchLiveId, int limit = 2000}) => send({
        'action': 'get_training_dataset',
        if ((matchLiveId ?? '').isNotEmpty) 'match_live_id': matchLiveId,
        'limit': limit,
      });

  void _handleMessage(dynamic message) {
    _noDataTimer?.cancel();
    try {
      final decoded = jsonDecode(message.toString());
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      if (!_packetController.isClosed) _packetController.add(data);

      if (data['type'] == 'error' || data.containsKey('error')) {
        _safeStatus('❌ ${data['error'] ?? data['message'] ?? 'AI server error'}');
        return;
      }
      final type = (data['type'] ?? '').toString();
      final status = (data['status'] ?? '').toString();
      final messageText = (data['message'] ?? '').toString();
      if (type == 'camera_list') {
        _safeStatus('✅ Камеры получены');
        return;
      }
      if (type == 'match_report') {
        _safeStatus('✅ Отчёт матча сохранён');
        return;
      }
      if (type == 'event_reviewed') {
        _safeStatus('✅ Событие принято тренером');
        return;
      }
      if (type == 'status' || type == 'match_started' || type == 'progress') {
        _safeStatus('⏳ ${messageText.isNotEmpty ? messageText : status}');
      }
      if (status == 'done' || status == 'completed') {
        _safeStatus('✅ Анализ завершён');
        return;
      }

      final isFrame = type == 'analysis_frame' ||
          data.containsKey('players') ||
          data.containsKey('detections');
      if (!isFrame) {
        _startNoDataTimer(seconds: 25);
        return;
      }
      final result = AnalysisResult.fromJson(data);
      if (!_analysisController.isClosed) _analysisController.add(result);
      final ballSuffix = result.ball == null ? '' : ' + мяч';
      _safeStatus('✅ Анализ: ${result.players.length} игроков$ballSuffix');
    } catch (error, stack) {
      debugPrint('WebSocket parse error: $error\n$stack');
      _safeStatus('❌ Ошибка разбора ответа AI-сервера: $error');
    }
  }

  Map<String, dynamic> _protocolParams(Map<String, dynamic>? params) {
    final source = Map<String, dynamic>.from(params ?? const {});
    final result = <String, dynamic>{};
    const aliases = <String, String>{
      'sourceMode': 'source_mode',
      'matchId': 'match_id',
      'clubId': 'club_id',
      'teamId': 'team_id',
      'fieldId': 'field_id',
      'cameraId': 'camera_id',
      'teamName': 'team_name',
      'matchTitle': 'match_title',
      'teamColors': 'team_colors',
      'fieldConfig': 'field_config',
      'sessionIds': 'session_ids',
      'playerBindings': 'player_bindings',
    };
    source.forEach((key, value) {
      if (value != null) result[aliases[key] ?? key] = value;
    });
    return result;
  }

  void _connectFailure(String message) {
    _isConnected = false;
    _isConnecting = false;
    _safeStatus(message);
    _scheduleReconnect();
  }

  void _startNoDataTimer({int seconds = 18}) {
    _noDataTimer?.cancel();
    _noDataTimer = Timer(Duration(seconds: seconds), () {
      if (!_disposed && !_manualClose) {
        _safeStatus('⏳ Сервер подключен, ожидаю кадры...');
      }
    });
  }

  void _scheduleReconnect() {
    if (_disposed || _manualClose || _lastRequest == null) return;
    if (_reconnectAttempts >= 3) {
      _safeStatus('❌ Не удалось подключиться после 3 попыток');
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(seconds: (_reconnectAttempts * 4).clamp(4, 16));
    _safeStatus('🔄 Переподключение ${_reconnectAttempts}/3 через ${delay.inSeconds} сек...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      final request = _lastRequest;
      if (!_disposed && !_manualClose && request != null) {
        _lastRequestKey = '';
        connectRequest(request);
      }
    });
  }

  Future<void> disconnect({bool silent = false}) async {
    _manualClose = true;
    await _closeCurrentChannel(silent: silent, bumpToken: true);
  }

  Future<void> _closeCurrentChannel({required bool silent, required bool bumpToken}) async {
    if (bumpToken) _connectToken++;
    _reconnectTimer?.cancel();
    _noDataTimer?.cancel();
    await _channelSub?.cancel();
    _channelSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    if (!silent) _safeStatus('🔴 Отключено');
  }

  void dispose() {
    _disposed = true;
    _manualClose = true;
    _reconnectTimer?.cancel();
    _noDataTimer?.cancel();
    _channelSub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    if (!_analysisController.isClosed) _analysisController.close();
    if (!_statusController.isClosed) _statusController.close();
    if (!_packetController.isClosed) _packetController.close();
  }

  void _safeStatus(String value) {
    if (!_statusController.isClosed) _statusController.add(value);
  }
}
