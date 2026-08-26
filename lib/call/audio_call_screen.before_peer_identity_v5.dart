// lib/call/audio_call_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    super.key,
    required this.callId,
    required this.userId,
    required this.isCaller,
    this.peerName,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  static const String _apiBase = 'https://sportotekaapp.ru/api/calls';

  lk.Room? _room;
  Timer? _connectTimeout;
  Timer? _durationTimer;
  Timer? _statusTimer;

  bool _muted = false;
  bool _speakerOn = false;
  bool _closing = false;
  bool _endNotified = false;
  bool _statusPollBusy = false;
  String? _roomName;
  String? _fatalError;
  DateTime? _connectedAt;
  Duration _duration = Duration.zero;

  bool get _supportsSpeakerToggle {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (!mounted) return;
      setState(
        () => _fatalError = 'Нет разрешения на использование микрофона',
      );
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
        final current = _room;
        if (current == null ||
            current.connectionState != lk.ConnectionState.connected) {
          setState(() => _fatalError = 'Не удалось установить соединение');
        }
      });

      await room.prepareConnection(details.serverUrl, details.token);
      await room.connect(
        details.serverUrl,
        details.token,
      );

      await room.localParticipant?.setMicrophoneEnabled(true);

      // Телефонный разговор начинаем через обычный разговорный динамик.
      // Громкая связь включается только пользователем кнопкой ниже.
      if (_supportsSpeakerToggle) {
        try {
          await lk.AudioManager.instance.setSpeakerOutputPreferred(false);
        } catch (_) {
          // Аудиосеанс уже может быть активирован системой — звонок не роняем.
        }
      }

      _connectTimeout?.cancel();
      _startStatusPolling();
      _syncConnectedTimer();

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
    _syncConnectedTimer();
    setState(() {});
  }

  void _syncConnectedTimer() {
    final room = _room;
    final connected = room?.connectionState == lk.ConnectionState.connected &&
        (room?.remoteParticipants.isNotEmpty ?? false);

    if (!connected) return;

    _connectedAt ??= DateTime.now();

    _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _connectedAt;
      if (!mounted || started == null) return;
      setState(() {
        _duration = DateTime.now().difference(started);
      });
    });
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

  Future<void> _toggleSpeaker() async {
    if (!_supportsSpeakerToggle) return;

    final next = !_speakerOn;
    try {
      await lk.AudioManager.instance.setSpeakerOutputPreferred(next);
      if (!mounted) return;
      setState(() => _speakerOn = next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось переключить аудиовыход'),
        ),
      );
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    unawaited(_pollCallStatus());
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollCallStatus());
    });
  }

  Future<void> _pollCallStatus() async {
    if (_statusPollBusy || _closing) return;
    _statusPollBusy = true;

    try {
      final response = await http.post(
        Uri.parse('$_apiBase/status.php'),
        body: {
          'call_id': widget.callId.toString(),
          'user_id': widget.userId.toString(),
        },
      ).timeout(const Duration(seconds: 4));

      Map<String, dynamic> data = const {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}

      if (response.statusCode != 200 || data['status'] != 'ok') return;

      final callStatus =
          (data['call_status'] ?? '').toString().trim().toLowerCase();
      if (!mounted || _closing) return;

      if (callStatus == 'declined') {
        _statusTimer?.cancel();
        setState(() => _fatalError = 'Вызов отклонён');
        Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (mounted && !_closing) unawaited(_closeFromRemoteStatus());
        });
        return;
      }

      if (callStatus == 'missed') {
        _statusTimer?.cancel();
        setState(() => _fatalError = 'Нет ответа');
        Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (mounted && !_closing) unawaited(_closeFromRemoteStatus());
        });
        return;
      }

      if (callStatus == 'canceled' || callStatus == 'cancelled') {
        _statusTimer?.cancel();
        setState(() => _fatalError = 'Вызов отменён');
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted && !_closing) unawaited(_closeFromRemoteStatus());
        });
        return;
      }

      if (callStatus == 'ended') {
        _statusTimer?.cancel();
        await _closeFromRemoteStatus();
      }
    } catch (_) {
      // Временная ошибка status API не должна ронять медиасессию.
    } finally {
      _statusPollBusy = false;
    }
  }

  Future<void> _closeFromRemoteStatus() async {
    if (_closing) return;
    _closing = true;
    if (mounted) setState(() {});

    _connectTimeout?.cancel();
    _durationTimer?.cancel();
    _statusTimer?.cancel();

    final room = _room;
    _room = null;
    if (room != null) {
      await _disposeRoom(room);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _notifyEnded() async {
    if (_endNotified) return;
    _endNotified = true;

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
    _durationTimer?.cancel();
    _statusTimer?.cancel();
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
            : 'На связи';
      case lk.ConnectionState.disconnected:
        return 'Отключено';
    }
  }

  Color _statusColor() {
    if (_fatalError != null) return const Color(0xFFD92D20);
    final room = _room;
    if (room?.connectionState == lk.ConnectionState.connected) {
      return const Color(0xFF00A750);
    }
    return const Color(0xFF667085);
  }

  String _durationText() {
    final seconds = _duration.inSeconds;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _connectTimeout?.cancel();
    _durationTimer?.cancel();
    _statusTimer?.cancel();

    // Если экран был закрыт внешней навигацией/ошибкой, всё равно
    // закрываем серверный lifecycle. Повторный вызов безопасен.
    if (!_endNotified) {
      unawaited(_notifyEnded());
    }

    final room = _room;
    _room = null;
    if (room != null) {
      unawaited(_disposeRoom(room));
    }

    // Не оставляем предпочтение громкой связи для следующего вызова.
    if (_supportsSpeakerToggle && _speakerOn) {
      unawaited(
        lk.AudioManager.instance.setSpeakerOutputPreferred(false),
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final remoteCount = room?.remoteParticipants.length ?? 0;
    final peer = (widget.peerName ?? '').trim();
    final connected = room?.connectionState == lk.ConnectionState.connected &&
        remoteCount > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_hangup());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _statusColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _statusText(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (connected)
                      Text(
                        _durationText(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .62),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 50,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                peer.isEmpty ? 'Аудиозвонок' : peer,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isCaller ? 'Исходящий звонок' : 'Входящий звонок',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .55),
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 22,
                runSpacing: 18,
                children: [
                  _CallControl(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _muted ? 'Микрофон выкл.' : 'Микрофон',
                    active: _muted,
                    onTap: _closing ? null : _toggleMute,
                  ),
                  if (_supportsSpeakerToggle)
                    _CallControl(
                      icon: _speakerOn
                          ? Icons.volume_up_rounded
                          : Icons.hearing_rounded,
                      label: _speakerOn ? 'Динамик' : 'Обычный',
                      active: _speakerOn,
                      onTap: _closing ? null : _toggleSpeaker,
                    ),
                  _CallControl(
                    icon: Icons.call_end_rounded,
                    label: 'Завершить',
                    danger: true,
                    onTap: _closing ? null : _hangup,
                  ),
                ],
              ),
              const SizedBox(height: 34),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  final Future<void> Function()? onTap;

  const _CallControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFE53935)
        : active
            ? const Color(0xFF00A750)
            : const Color(0xFF1E2A44);

    return GestureDetector(
      onTap: onTap == null ? null : () => unawaited(onTap!()),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? .45 : 1,
        child: SizedBox(
          width: 84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .62),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
