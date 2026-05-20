// lib/call/audio_call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// Твой App ID из Agora Console
const kAgoraAppId = 'c59170dfa9a747bdbde8cb63e571f325';

/// Экран аудиозвонка на Agora.
/// При включённом App Certificate — передавай валидный token (не пустой).
class AudioCallScreen extends StatefulWidget {
  final String channelId; // например: chat_123
  final int uid;          // твой userId
  final String token;     // dev: '' (если Certificate OFF), prod: реальный токен

  const AudioCallScreen({
    super.key,
    required this.channelId,
    required this.uid,
    required this.token,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  late RtcEngine _engine;

  bool _joined = false;
  bool _muted = false;
  final Set<int> _remotes = {};

  ConnectionStateType _connState =
      ConnectionStateType.connectionStateDisconnected;

  Timer? _connectTimeout;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1) Разрешение микрофона
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    // 2) Инициализация Agora Engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: kAgoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 🔇 Отключаем внутренний лог Agora SDK
    // (в 6.x это делается через setParameters с ключом rtc.log_filter = 0)
    try {
      await _engine.setParameters('{"rtc.log_filter":0}');
    } catch (_) {
      // игнорируем, если платформа не поддерживает
    }

    // 3) Обработчики событий — без логов/SnackBar
    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection c, int elapsed) {
        if (!mounted) return;
        setState(() {
          _joined = true;
          _connState = ConnectionStateType.connectionStateConnected;
        });
      },
      onUserJoined: (RtcConnection c, int remoteUid, int elapsed) {
        if (!mounted) return;
        setState(() => _remotes.add(remoteUid));
      },
      onUserOffline:
          (RtcConnection c, int remoteUid, UserOfflineReasonType reason) {
        if (!mounted) return;
        setState(() => _remotes.remove(remoteUid));
      },
      onLeaveChannel: (RtcConnection c, RtcStats stats) {
        if (!mounted) return;
        setState(() {
          _joined = false;
          _remotes.clear();
          _connState = ConnectionStateType.connectionStateDisconnected;
        });
      },
      // ✅ В 6.5.3 здесь 3 параметра
      onConnectionStateChanged: (
        RtcConnection c,
        ConnectionStateType state,
        ConnectionChangedReasonType reason,
      ) {
        if (!mounted) return;
        setState(() => _connState = state);
      },
      onError: (ErrorCodeType err, String msg) {
        // Тихий режим: ничего не показываем
      },
    ));

    await _engine.enableAudio();
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // 4) Таймаут попытки соединения — тихо
    _connectTimeout?.cancel();
    _connectTimeout = Timer(const Duration(seconds: 20), () {
      // Никаких уведомлений — тихий режим
    });

    // 5) Join
    await _engine.joinChannel(
      token: widget.token,
      channelId: widget.channelId,
      uid: widget.uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  @override
  void dispose() {
    _connectTimeout?.cancel();
    // Покидаем канал и освобождаем ресурсы
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _engine.muteLocalAudioStream(_muted);
    // Альтернатива: await _engine.enableLocalAudio(!_muted);
  }

  Future<void> _hangup() async {
    try {
      await _engine.leaveChannel();
    } finally {
      await _engine.release();
      if (mounted) Navigator.pop(context);
    }
  }

  String _prettyConnState(ConnectionStateType s) {
    switch (s) {
      case ConnectionStateType.connectionStateConnecting:
        return 'Подключение…';
      case ConnectionStateType.connectionStateConnected:
        return 'Вызов идёт';
      case ConnectionStateType.connectionStateDisconnected:
        return 'Отключено';
      case ConnectionStateType.connectionStateReconnecting:
        return 'Переподключение…';
      case ConnectionStateType.connectionStateFailed:
        return 'Ошибка соединения';
      default:
        return s.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _prettyConnState(_connState);
    final remoteCount = _remotes.length;

    return Scaffold(
      backgroundColor: const Color(0xff0B1220),
      body: SafeArea(
        child: Column(
          children: [
            // Верхний баннер статуса
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _connState == ConnectionStateType.connectionStateConnected
                    ? Colors.green.shade600
                    : (_connState == ConnectionStateType.connectionStateFailed
                        ? Colors.red.shade700
                        : Colors.blueGrey.shade700),
              ),
              child: Row(
                children: [
                  Icon(
                    _connState == ConnectionStateType.connectionStateConnected
                        ? Icons.phone_in_talk
                        : Icons.wifi_tethering,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$status · канал: ${widget.channelId} · UID: ${widget.uid} · удалённых: $remoteCount',
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Список подключённых удалённых UID
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: _remotes
                  .map(
                    (id) => Chip(
                      label: Text('UID $id'),
                      backgroundColor: Colors.white10,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  )
                  .toList(),
            ),

            const Spacer(),

            // Кнопки управления
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _roundBtn(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  onTap: _toggleMute,
                ),
                _roundBtn(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onTap: _hangup,
                ),
              ],
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    Color color = const Color(0xff1E2A44),
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}
