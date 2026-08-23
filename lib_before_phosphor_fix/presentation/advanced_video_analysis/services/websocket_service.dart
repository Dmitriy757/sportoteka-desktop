// lib/presentation/advanced_video_analysis/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/analysis_result.dart';

class WebSocketService {
  static const String _wsUrl = 'wss://sportotekaapp.ru/ws-video-analysis/';

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
  String? _lastVideoUrl;

  final _analysisStreamController = StreamController<AnalysisResult>.broadcast();
  Stream<AnalysisResult> get analysisStream => _analysisStreamController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  Future<void> connect(String videoUrl) async {
    if (_disposed) return;
    if (videoUrl.trim().isEmpty) {
      _safeStatus('❌ Не передан video_url');
      return;
    }

    // Не запускаем второй анализ поверх первого. Это убирает дубли start_analysis
    // и повторные SocketException timeout из Flutter.
    if (_isConnecting) {
      debugPrint('⚠️ WebSocket connect skipped: connection is already in progress');
      return;
    }
    if (_isConnected && _lastVideoUrl == videoUrl) {
      debugPrint('⚠️ WebSocket connect skipped: already connected for this video');
      return;
    }

    _lastVideoUrl = videoUrl;
    _manualClose = false;
    _isConnecting = true;
    final int token = ++_connectToken;

    await _closeCurrentChannel(silent: true, bumpToken: false);

    try {
      _safeStatus('🔄 Подключение к AI-серверу...');
      debugPrint('Connecting to $_wsUrl');

      final socket = await WebSocket.connect(_wsUrl).timeout(
        const Duration(seconds: 18),
        onTimeout: () {
          throw TimeoutException('AI-сервер не ответил за 18 секунд');
        },
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
        (message) => _handleMessage(message),
        onError: (error) {
          debugPrint('❌ WebSocket stream error: $error');
          _safeStatus('❌ Ошибка WebSocket: $error');
          _isConnected = false;
          _isConnecting = false;
          _scheduleReconnect(videoUrl);
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _isConnected = false;
          _isConnecting = false;
          if (!_manualClose && !_disposed) {
            _safeStatus('🔴 Соединение закрыто. Пробую переподключиться...');
            _scheduleReconnect(videoUrl);
          }
        },
        cancelOnError: false,
      );

      final payload = <String, dynamic>{
        'action': 'start_analysis',
        'video_url': videoUrl,
      };

      channel.sink.add(jsonEncode(payload));
      _safeStatus('✅ Подключено. Видео отправлено, жду detections...');
      debugPrint('✅ Connected to $_wsUrl');
      debugPrint('📤 Sent: ${jsonEncode(payload)}');

      _startNoDataTimer();
    } on TimeoutException catch (e) {
      debugPrint('❌ Connection timeout: $e');
      _isConnected = false;
      _isConnecting = false;
      _safeStatus('❌ Таймаут подключения к AI-серверу. Проверь Nginx location /ws-video-analysis/ и Python-сервер на 127.0.0.1:8765.');
      _scheduleReconnect(videoUrl);
    } on SocketException catch (e) {
      debugPrint('❌ SocketException: $e');
      _isConnected = false;
      _isConnecting = false;
      _safeStatus('❌ Socket timeout: AI-сервер недоступен через wss://sportotekaapp.ru/ws-video-analysis/. Проверь Nginx и Python.');
      _scheduleReconnect(videoUrl);
    } catch (e, st) {
      debugPrint('❌ WebSocket connect failed: $e');
      debugPrint('$st');
      _isConnected = false;
      _isConnecting = false;
      _safeStatus('❌ Ошибка подключения к AI-серверу: $e');
      _scheduleReconnect(videoUrl);
    }
  }

  void _handleMessage(dynamic message) {
    _noDataTimer?.cancel();
    try {
      final raw = message.toString();
      debugPrint('📩 WS raw: ${_short(raw)}');

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);

      if (data['type'] == 'error' || data.containsKey('error')) {
        _safeStatus('❌ ${data['error'] ?? data['message'] ?? 'AI server error'}');
        return;
      }

      final type = data['type']?.toString();
      final status = data['status']?.toString();
      final messageText = data['message']?.toString();

      if (type == 'status' || type == 'progress' || status == 'processing' || status == 'opening_video') {
        final progress = data['progress'];
        final suffix = progress == null ? '' : ' $progress%';
        _safeStatus('⏳ ${messageText ?? status ?? 'AI анализирует видео'}$suffix');

        // Если это только статус, но без players/detections, дальше не парсим как кадр.
        if (!data.containsKey('players') && !data.containsKey('detections') && !data.containsKey('tracks')) {
          _startNoDataTimer(seconds: 25);
          return;
        }
      }

      if (type == 'done' || status == 'done' || status == 'completed') {
        _safeStatus('✅ Анализ завершён');
        return;
      }

      final result = AnalysisResult.fromJson(data);
      debugPrint('📊 Frame ${result.frame}, Players: ${result.players.length}');

      if (result.players.isNotEmpty) {
        final first = result.players.first;
        debugPrint('👤 First bbox=${first.bbox} track=${first.trackId} conf=${first.confidence}');
        if (!_analysisStreamController.isClosed) {
          _analysisStreamController.add(result);
        }
        _safeStatus('✅ Анализ: ${result.players.length} игроков');
      } else {
        _safeStatus('⚠️ Сервер ответил, но players/detections пустые');
        _startNoDataTimer(seconds: 25);
      }
    } catch (e, st) {
      debugPrint('❌ Parse error: $e');
      debugPrint('$st');
      _safeStatus('❌ Ошибка разбора ответа AI-сервера: $e');
    }
  }

  void _startNoDataTimer({int seconds = 18}) {
    _noDataTimer?.cancel();
    _noDataTimer = Timer(Duration(seconds: seconds), () {
      if (_disposed || _manualClose) return;
      _safeStatus('⏳ Сервер подключен, но кадры ещё не пришли. Проверь серверный лог: [AI] sent=... players=...');
    });
  }

  void _scheduleReconnect(String videoUrl) {
    if (_disposed || _manualClose) return;
    if (_reconnectAttempts >= 3) {
      _safeStatus('❌ Не удалось подключиться после 3 попыток. Проверь Nginx proxy и AI-сервер на 8765.');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: (_reconnectAttempts * 4).clamp(4, 16));
    _safeStatus('🔄 Переподключение ${_reconnectAttempts}/3 через ${delay.inSeconds} сек...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_disposed || _manualClose) return;
      connect(videoUrl);
    });
  }

  Future<void> disconnect({bool silent = false}) async {
    _manualClose = true;
    await _closeCurrentChannel(silent: silent, bumpToken: true);
  }

  Future<void> _closeCurrentChannel({required bool silent, required bool bumpToken}) async {
    if (bumpToken) _connectToken++;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _noDataTimer?.cancel();
    _noDataTimer = null;

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
    if (!_analysisStreamController.isClosed) _analysisStreamController.close();
    if (!_statusController.isClosed) _statusController.close();
  }

  void _safeStatus(String value) {
    if (!_statusController.isClosed) {
      _statusController.add(value);
    }
  }

  String _short(String value) {
    if (value.length <= 1200) return value;
    return '${value.substring(0, 1200)}...';
  }
}
