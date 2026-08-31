// lib/call/audio_call_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';
import 'package:sportoteka/call/call_session_service.dart';


String _sportotekaCallUuid(int callId) {
  var hex = callId <= 0 ? '0' : callId.toRadixString(16);

  if (hex.length > 12) {
    hex = hex.substring(hex.length - 12);
  }

  hex = hex.padLeft(12, '0');

  return '00000000-0000-4000-8000-$hex';
}

class AudioCallScreen extends StatefulWidget {
  final int callId;
  final int userId;
  final bool isCaller;
  final String? peerName;
  final String? peerUsername;
  final String? peerPhotoUrl;

  const AudioCallScreen({
    super.key,
    required this.callId,
    required this.userId,
    required this.isCaller,
    this.peerName,
    this.peerUsername,
    this.peerPhotoUrl,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  static const String _apiBase = 'https://sportotekaapp.ru/api/calls';

  static const MethodChannel _androidCallAudio =
      MethodChannel('sportoteka/call_audio');

  lk.Room? _room;
  Timer? _connectTimeout;
  Timer? _durationTimer;
  Timer? _statusTimer;

  bool _muted = false;
  bool _speakerOn = false;
  bool _closing = false;
  bool _endNotified = false;
  bool _nativeCallUiEnded = false;
  bool _statusPollBusy = false;
  String? _roomName;
  String? _fatalError;
  DateTime? _connectedAt;
  Duration _duration = Duration.zero;

  String _peerName = '';
  String _peerUsername = '';
  String _peerPhotoUrl = '';
  String _peerRole = '';
  int _peerId = 0;

  bool get _supportsSpeakerToggle {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _peerName = (widget.peerName ?? '').trim();
    _peerUsername = (widget.peerUsername ?? '').trim();
    _peerPhotoUrl = _normalizePhoto(widget.peerPhotoUrl);
    unawaited(_init());
  }

  Future<void> _init() async {
    // Сразу загружаем профиль второго участника по call_id, чтобы имя и
    // аватар появились ещё до установления медиасоединения.
    await _refreshPeerIdentity();

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (!mounted) return;
      setState(
        () => _fatalError = 'Нет разрешения на использование микрофона',
      );
      return;
    }

    try {
      final room =
          await CallSessionService.instance.ensureConnected(
        callId: widget.callId,
        userId: widget.userId,
      );

      if (!mounted) return;

      room.addListener(_onRoomChanged);
      _room = room;
      _roomName = CallSessionService.instance.roomName;

      // Android начинаем через обычный разговорный динамик.
      // На iOS CallKit сам владеет AVAudioSession и маршрутом в момент Accept.
      // Не переопределяем его сразу после подключения LiveKit.
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        try {


          await _androidCallAudio.invokeMethod<bool>(
            'setSpeaker',
            <String, dynamic>{
              'enabled': false,
              'callUuid': _sportotekaCallUuid(widget.callId),
            },
          );
        } catch (_) {}
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

  String _normalizePhoto(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final clean = value.startsWith('/') ? value.substring(1) : value;
    if (clean.startsWith('uploads/')) {
      return 'https://sportotekaapp.ru/$clean';
    }
    return 'https://sportotekaapp.ru/uploads/$clean';
  }

  String _normalizeUsername(dynamic raw) {
    var value = (raw ?? '').toString().trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    if (value.contains('@') && value.contains('.')) return '';
    while (value.startsWith('@')) {
      value = value.substring(1);
    }
    return value.trim();
  }

  String _roleLabel(String raw) {
    final role = raw.trim().toLowerCase();
    if (role.isEmpty) return '';
    if (role == 'player' || role.contains('игрок')) return 'Игрок';
    if (role == 'coach' || role == 'trainer' || role.contains('тренер')) {
      return 'Тренер';
    }
    if (role == 'club' || role.contains('клуб')) return 'Клуб';
    if (role == 'parent' || role.contains('родител')) return 'Родитель';
    return raw.trim();
  }

  void _applyPeerData(Map<String, dynamic> data) {
    final peerId = int.tryParse('${data['peer_id'] ?? 0}') ?? 0;
    final peerName = (data['peer_name'] ?? '').toString().trim();
    final username = _normalizeUsername(data['peer_username']);
    final photo = _normalizePhoto(data['peer_photo']);
    final role = _roleLabel((data['peer_role'] ?? '').toString());

    final changed = peerId != _peerId ||
        (peerName.isNotEmpty && peerName != _peerName) ||
        (username.isNotEmpty && username != _peerUsername) ||
        (photo.isNotEmpty && photo != _peerPhotoUrl) ||
        (role.isNotEmpty && role != _peerRole);

    if (!changed) return;

    if (!mounted) {
      _peerId = peerId > 0 ? peerId : _peerId;
      if (peerName.isNotEmpty) _peerName = peerName;
      if (username.isNotEmpty) _peerUsername = username;
      if (photo.isNotEmpty) _peerPhotoUrl = photo;
      if (role.isNotEmpty) _peerRole = role;
      return;
    }

    setState(() {
      if (peerId > 0) _peerId = peerId;
      if (peerName.isNotEmpty) _peerName = peerName;
      if (username.isNotEmpty) _peerUsername = username;
      if (photo.isNotEmpty) _peerPhotoUrl = photo;
      if (role.isNotEmpty) _peerRole = role;
    });
  }

  Future<void> _refreshPeerIdentity() async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/status.php'),
        body: {
          'call_id': widget.callId.toString(),
          'user_id': widget.userId.toString(),
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      if (data['status'] != 'ok') return;
      _applyPeerData(data);
    } catch (_) {
      // Профиль — декоративная часть. Ошибка не должна мешать звонку.
    }
  }

  String get _peerDisplayName {
    final value = _peerName.trim();
    if (value.isNotEmpty) return value;
    if (_peerId > 0) return 'Пользователь #$_peerId';
    return widget.isCaller ? 'Исходящий звонок' : 'Входящий звонок';
  }

  String get _peerInitials {
    final words = _peerDisplayName
        .split(RegExp(r'\\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) return 'S';
    if (words.length == 1) {
      return words.first.characters.first.toUpperCase();
    }
    return '${words[0].characters.first}${words[1].characters.first}'
        .toUpperCase();
  }

  Widget _buildSportotekaCallBrand() {
    Widget dot(double size, double opacity) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF00A750).withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(3.2, .36),
        const SizedBox(width: 3),
        dot(4.1, .52),
        const SizedBox(width: 3),
        dot(5.0, .72),
        const SizedBox(width: 3),
        dot(6.0, 1),
        const SizedBox(width: 9),
        Text(
          'SPORTOTEKA CALL',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .72),
            fontSize: 10.4,
            fontWeight: FontWeight.w700,
            letterSpacing: .75,
          ),
        ),
      ],
    );
  }

  Widget _buildPeerAvatar() {
    final photo = _peerPhotoUrl.trim();

    return Container(
      width: 122,
      height: 122,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .08),
        border: Border.all(
          color: Colors.white.withValues(alpha: .15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00A750).withValues(alpha: .16),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: photo.isNotEmpty
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPeerInitials(),
              )
            : _buildPeerInitials(),
      ),
    );
  }

  Widget _buildPeerInitials() {
    return Container(
      color: const Color(0xFF152238),
      alignment: Alignment.center,
      child: Text(
        _peerInitials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
      ),
    );
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

    final room = _room;

    if (room == null ||
        room.connectionState != lk.ConnectionState.connected) {
      return;
    }

    final next = !_speakerOn;

    try {
      // Сначала LiveKit обновляет собственный AudioSwitch.


      // Затем на Android фиксируем тот же маршрут нативно,
      // включая self-managed Telecom Connection.
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        await _androidCallAudio.invokeMethod<bool>(
          'setSpeaker',
          <String, dynamic>{
            'enabled': next,
            'callUuid': _sportotekaCallUuid(widget.callId),
          },
        );
      }
 else {
        // На iOS маршрутом продолжает управлять
        // LiveKit / CallKit.
        await lk.AudioManager.instance
            .setSpeakerOutputPreferred(
          next,
          force: next,
        );
      }

      if (!mounted) return;

      setState(() => _speakerOn = next);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось переключить аудиовыход: $e',
          ),
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

      _applyPeerData(data);

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

    await _endNativeCallUi();

    if (mounted) Navigator.pop(context);
  }


  Future<void> _endNativeCallUi() async {
    if (_nativeCallUiEnded) return;
    _nativeCallUiEnded = true;

    if (kIsWeb) return;

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      await FlutterCallkitIncoming.endCall(
        _sportotekaCallUuid(widget.callId),
      );
    } catch (_) {
      // Если системный экран уже закрыт, это нормально.
    }
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

    if (identical(CallSessionService.instance.room, room)) {
      await CallSessionService.instance.disconnect();
      return;
    }

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
    await _endNativeCallUi();

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
      return 'Медиасоединение прервано. Выполняется восстановление соединения.';
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

    // AudioCallScreen больше НЕ владеет LiveKit lifecycle.
    //
    // Экран может исчезнуть из-за:
    // - CallKit foreground/background transition,
    // - навигации,
    // - rebuild приложения,
    // - разблокировки iPhone.
    //
    // Ни одно из этих событий не означает завершение разговора.
    final room = _room;
    _room = null;

    if (room != null) {
      try {
        room.removeListener(_onRoomChanged);
      } catch (_) {}
    }

    // ВАЖНО:
    // здесь больше НЕТ:
    // _notifyEnded()
    // _disposeRoom()
    // _endNativeCallUi()
    // setSpeakerOutputPreferred(false)
    //
    // Завершать звонок имеют право только:
    // _hangup()
    // _closeFromRemoteStatus()
    // CallSessionService status polling.

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final remoteCount = room?.remoteParticipants.length ?? 0;
    final connected = room?.connectionState == lk.ConnectionState.connected &&
        remoteCount > 0;
    final username = _peerUsername.trim();
    final role = _peerRole.trim();

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildSportotekaCallBrand(),
                ),
              ),
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
              _buildPeerAvatar(),
              const SizedBox(height: 19),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _peerDisplayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.12,
                    letterSpacing: -.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (username.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '@$username',
                  style: TextStyle(
                    color: const Color(0xFF57D895).withValues(alpha: .95),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 7,
                runSpacing: 5,
                children: [
                  if (role.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .62),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Text(
                    widget.isCaller ? 'Исходящий звонок' : 'Входящий звонок',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .52),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
