// lib/call/audio_call_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

class AudioCallScreen extends StatefulWidget {
  final int callId;
  final int userId;
  final bool isCaller;
  final String? peerName;

  const AudioCallScreen({
    Key? key,
    required this.callId,
    required this.userId,
    required this.isCaller,
    this.peerName,
  }) : super(key: key);

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  static const String _apiBase = 'https://sportotekaapp.ru/api/calls';

  lk.Room? _room;
  Timer? _connectTimeout;

  bool _muted = false;
  bool _closing = false;
  String? _roomName;
  String? _fatalError;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (!mounted) return;
      setState(() => _fatalError = 'Нет разрешения на использование микрофона');
      return;
    }

    try {
      final details = await _fetchConnectionDetails();
      if (!mounted) return;

      final room = lk.Room(
        roomOptions: const lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      room.addListener(_onRoomChanged);
      _room = room;
      _roomName = details.roomName;

      _connectTimeout?.cancel();
      _connectTimeout = Timer(const Duration(seconds: 25), () {
        if (!mounted) return;
        final r = _room;
        if (r == null || r.connectionState != lk.ConnectionState.connected) {
          setState(() => _fatalError = 'Не удалось установить соединение');
        }
      });

      await room.prepareConnection(details.serverUrl, details.token);
      await room.connect(
        details.serverUrl,
        details.token,
      );

      await room.localParticipant?.setMicrophoneEnabled(true);
      _connectTimeout?.cancel();

      if (mounted) setState(() {});
    } catch (e) {
      _connectTimeout?.cancel();
      if (!mounted) return;
      setState(() => _fatalError = _friendlyError(e));
    }
  }

  Future<_LiveKitConnectionDetails> _fetchConnectionDetails() async {
    final response = await http.post(
      Uri.parse('$_apiBase/livekit_token.php'),
      body: {
        'call_id': widget.callId.toString(),
        'user_id': widget.userId.toString(),
      },
    );

    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    if (response.statusCode != 200 || data['status'] != 'ok') {
      final error =
          (data['error'] ?? 'token_http_${response.statusCode}').toString();
      throw StateError(error);
    }

    final serverUrl = (data['server_url'] ?? '').toString().trim();
    final token = (data['participant_token'] ?? '').toString().trim();
    final roomName = (data['room_name'] ?? '').toString().trim();

    if (serverUrl.isEmpty || token.isEmpty || roomName.isEmpty) {
      throw StateError('bad_livekit_response');
    }

    return _LiveKitConnectionDetails(
      serverUrl: serverUrl,
      token: token,
      roomName: roomName,
    );
  }

  void _onRoomChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleMute() async {
    final room = _room;
    if (room == null || room.connectionState != lk.ConnectionState.connected) {
      return;
    }

    final nextMuted = !_muted;
    await room.localParticipant?.setMicrophoneEnabled(!nextMuted);
    if (!mounted) return;
    setState(() => _muted = nextMuted);
  }

  Future<void> _notifyEnded() async {
    try {
      await http.post(
        Uri.parse('$_apiBase/end.php'),
        body: {
          'call_id': widget.callId.toString(),
          'user_id': widget.userId.toString(),
        },
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Завершение локального WebRTC не блокируем из-за API.
    }
  }

  Future<void> _disposeRoom(lk.Room room) async {
    room.removeListener(_onRoomChanged);
    try {
      await room.disconnect();
    } catch (_) {}
    try {
      await room.dispose();
    } catch (_) {}
  }

  Future<void> _hangup() async {
    if (_closing) return;
    _closing = true;
    if (mounted) setState(() {});

    _connectTimeout?.cancel();
    await _notifyEnded();

    final room = _room;
    _room = null;
    if (room != null) {
      await _disposeRoom(room);
    }

    if (mounted) Navigator.pop(context);
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('call_not_accepted')) return 'Вызов ещё не принят';
    if (raw.contains('call_not_joinable')) return 'Этот вызов уже завершён';
    if (raw.contains('call_not_found')) return 'Вызов не найден';
    if (raw.contains('MediaConnectException')) {
      return 'Нет соединения с медиасервером. Проверьте WebRTC-порты.';
    }
    return 'Ошибка соединения: $raw';
  }

  String _statusText() {
    if (_fatalError != null) return _fatalError!;

    final room = _room;
    if (room == null) return 'Подключение…';

    switch (room.connectionState) {
      case lk.ConnectionState.connecting:
        return 'Подключение…';
      case lk.ConnectionState.reconnecting:
        return 'Переподключение…';
      case lk.ConnectionState.connected:
        return room.remoteParticipants.isEmpty
            ? 'Ожидание собеседника…'
            : 'Вызов идёт';
      case lk.ConnectionState.disconnected:
        return 'Отключено';
    }
  }

  Color _statusColor() {
    if (_fatalError != null) return Colors.red.shade700;
    final room = _room;
    if (room?.connectionState == lk.ConnectionState.connected) {
      return Colors.green.shade600;
    }
    return Colors.blueGrey.shade700;
  }

  @override
  void dispose() {
    _connectTimeout?.cancel();
    final room = _room;
    _room = null;
    if (room != null) {
      unawaited(_disposeRoom(room));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final remoteCount = room?.remoteParticipants.length ?? 0;
    final peer = (widget.peerName ?? '').trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_hangup());
      },
      child: Scaffold(
        backgroundColor: const Color(0xff0B1220),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: _statusColor(),
                child: Row(
                  children: [
                    const Icon(Icons.phone_in_talk, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusText(),
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white12,
                child: const Icon(Icons.person_rounded,
                    size: 52, color: Colors.white70),
              ),
              const SizedBox(height: 18),
              Text(
                peer.isEmpty ? 'Аудиозвонок' : peer,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SPORTOTEKA · LiveKit',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .55), fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Комната: ${_roomName ?? '...'} · участников: ${remoteCount + (room?.localParticipant != null ? 1 : 0)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .45), fontSize: 12),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _roundBtn(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    onTap: _closing ? null : _toggleMute,
                  ),
                  _roundBtn(
                    icon: Icons.call_end_rounded,
                    color: Colors.red,
                    onTap: _closing ? null : _hangup,
                  ),
                ],
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    Color color = const Color(0xff1E2A44),
    Future<void> Function()? onTap,
  }) {
    return GestureDetector(
      onTap: onTap == null ? null : () => unawaited(onTap()),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? .45 : 1,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class _LiveKitConnectionDetails {
  final String serverUrl;
  final String token;
  final String roomName;

  const _LiveKitConnectionDetails({
    required this.serverUrl,
    required this.token,
    required this.roomName,
  });
}
