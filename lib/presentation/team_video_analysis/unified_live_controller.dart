import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

class UnifiedLiveController extends ChangeNotifier {
  UnifiedLiveController({
    this.endpoint = 'wss://sportotekaapp.ru/ai/',
  });

  final String endpoint;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;

  bool connected = false;
  bool connecting = false;
  bool live = false;
  bool aiPaused = false;
  bool recording = false;
  bool phoneConnected = false;
  String status = 'offline';
  String statusText = '';
  String matchLiveId = '';
  String pairId = '';
  String pairToken = '';
  String pairUrl = '';
  Uint8List? pairQrPng;
  int timeMs = 0;
  int detectedPlayers = 0;
  double aiConfidence = 0;
  Uint8List? previewJpeg;
  Map<String, dynamic> stats = <String, dynamic>{};
  List<Map<String, dynamic>> recentEvents = <Map<String, dynamic>>[];

  Map<String, dynamic> _lastMatchParams = <String, dynamic>{};

  Future<void> connect({Map<String, dynamic>? matchParams}) async {
    if (matchParams != null) _lastMatchParams = Map<String, dynamic>.from(matchParams);
    if (connected || connecting || _disposed) return;
    connecting = true;
    statusText = 'Подключение LIVE…';
    notifyListeners();
    try {
      final socket = await WebSocket.connect(endpoint).timeout(const Duration(seconds: 8));
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      connected = true;
      connecting = false;
      status = 'connected';
      statusText = 'LIVE сервер подключён';
      _subscription = socket.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: false,
      );
      notifyListeners();
      await attachActive();
    } catch (e) {
      connected = false;
      connecting = false;
      status = 'offline';
      statusText = 'LIVE недоступен';
      notifyListeners();
      _scheduleReconnect();
    }
  }

  Future<void> attachActive() async {
    await _send({
      'action': 'attach_active_analysis',
      'match_id': _lastMatchParams['match_id'],
      'team_id': _lastMatchParams['team_id'],
    });
  }

  Future<void> startCameraLive({
    String cameraId = '',
    String streamUrl = '',
  }) async {
    await connect();
    final payload = <String, dynamic>{
      ..._lastMatchParams,
      'action': 'start_live_match',
      'record': true,
      'camera_id': cameraId.isEmpty ? null : cameraId,
      'stream_url': streamUrl.isEmpty ? null : streamUrl,
      'm3u8_url': streamUrl.isEmpty ? null : streamUrl,
      'rtsp_url': streamUrl.isEmpty ? null : streamUrl,
    };
    await _send(payload);
    live = true;
    recording = true;
    status = 'starting';
    notifyListeners();
  }

  Future<void> createPhonePairing() async {
    await connect();
    await _send({
      ..._lastMatchParams,
      'action': 'create_phone_pairing',
      'fps': 25,
      'width': 1280,
      'height': 720,
    });
  }

  Future<void> pauseAi() async {
    aiPaused = !aiPaused;
    // The current server keeps recording while UI AI is paused. A server-side
    // inference throttle can be added later without changing this controller.
    notifyListeners();
  }

  Future<void> finishMatch() async {
    await _send({
      'action': 'stop_match',
      'match_live_id': matchLiveId.isEmpty ? null : matchLiveId,
    });
    status = 'finishing';
    statusText = 'Финальный OCR и отчёт…';
    notifyListeners();
  }

  Future<void> addManualMoment({String title = 'Момент'}) async {
    // Unified timeline keeps the marker immediately in UI. The server-side
    // manual-event persistence action is intentionally compatible with a future
    // endpoint and does not interrupt the stream.
    final event = <String, dynamic>{
      'event_type': 'manual_moment',
      'title': title,
      'time_ms': timeMs,
      'confidence': 1.0,
      'source': 'coach',
    };
    recentEvents = <Map<String, dynamic>>[event, ...recentEvents].take(50).toList();
    notifyListeners();
    await _send({
      'action': 'add_manual_event',
      'match_live_id': matchLiveId,
      ...event,
    }, swallowErrors: true);
  }

  Future<void> _send(Map<String, dynamic> payload, {bool swallowErrors = false}) async {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      if (swallowErrors) return;
      await connect();
    }
    try {
      _socket?.add(jsonEncode(payload));
    } catch (_) {
      if (!swallowErrors) rethrow;
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    final type = '${data['type'] ?? ''}';
    final incomingId = '${data['match_live_id'] ?? ''}'.trim();
    if (incomingId.isNotEmpty) matchLiveId = incomingId;

    if (type == 'active_analysis') {
      live = data['active'] == true;
      recording = live;
      timeMs = _toInt(data['time_ms']);
      status = '${data['status'] ?? (live ? 'processing' : 'idle')}';
      final report = data['report'];
      if (report is Map) _consumeReport(Map<String, dynamic>.from(report));
    } else if (type == 'phone_pairing') {
      pairId = '${data['pair_id'] ?? ''}';
      pairToken = '${data['pair_token'] ?? ''}';
      pairUrl = '${data['pair_url'] ?? ''}';
      final qr = '${data['qr_png_base64'] ?? ''}';
      if (qr.isNotEmpty) {
        try { pairQrPng = base64Decode(qr); } catch (_) {}
      }
      statusText = 'Откройте камеру Sportoteka на телефоне';
    } else if (type == 'phone_pairing_state' || type == 'phone_pairing_claimed') {
      phoneConnected = data['claimed'] == true || data['ready'] == true || data['phone_connected'] == true;
    } else if (type == 'match_started') {
      live = true;
      recording = true;
      status = '${data['status'] ?? 'processing'}';
    } else if (type == 'analysis_frame') {
      live = true;
      recording = true;
      status = 'processing';
      timeMs = _toInt(data['time_ms'] ?? data['timestamp']);
      final p = data['players'];
      if (p is List) detectedPlayers = p.whereType<Map>().length;
      final s = data['stats'];
      if (s is Map) stats = Map<String, dynamic>.from(s);
      final events = data['recent_events'];
      if (events is List) {
        recentEvents = events.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList().reversed.take(50).toList();
      }
      final encoded = '${data['frame_jpeg_base64'] ?? ''}';
      if (encoded.isNotEmpty) {
        try { previewJpeg = base64Decode(encoded); } catch (_) {}
      }
      aiConfidence = _estimateConfidence(data);
    } else if (type == 'match_report') {
      final report = data['report'];
      if (report is Map) _consumeReport(Map<String, dynamic>.from(report));
    } else if (type == 'status') {
      status = '${data['status'] ?? status}';
      statusText = '${data['message'] ?? statusText}';
      timeMs = _toInt(data['time_ms'] ?? timeMs);
    } else if (type == 'error') {
      statusText = '${data['message'] ?? data['error'] ?? 'LIVE ошибка'}';
    }
    notifyListeners();
  }

  void _consumeReport(Map<String, dynamic> report) {
    final s = report['stats'] ?? report['final_stats'];
    if (s is Map) stats = Map<String, dynamic>.from(s);
    final events = report['events'];
    if (events is List) {
      recentEvents = events.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList().reversed.take(50).toList();
    }
  }

  double _estimateConfidence(Map<String, dynamic> packet) {
    final players = packet['players'];
    if (players is! List || players.isEmpty) return aiConfidence;
    var total = 0.0;
    var count = 0;
    for (final raw in players.whereType<Map>()) {
      final v = raw['identity_confidence'] ?? raw['confidence'] ?? raw['conf'];
      final n = double.tryParse('$v');
      if (n != null) { total += n; count++; }
    }
    return count == 0 ? aiConfidence : (total / count).clamp(0.0, 1.0);
  }

  int _toInt(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;

  void _onDisconnected() {
    connected = false;
    connecting = false;
    _socket = null;
    _subscription = null;
    if (!_disposed) {
      statusText = live ? 'Связь с LIVE восстанавливается…' : 'LIVE сервер отключён';
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 2), () => connect());
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
    super.dispose();
  }
}
