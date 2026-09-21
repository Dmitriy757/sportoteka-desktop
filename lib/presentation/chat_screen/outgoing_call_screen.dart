// lib/presentation/chat_screen/outgoing_call_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/call/audio_call_screen.dart';

/// Shows the call immediately, while create.php delivers push notifications.
/// The local ringback is feedback for the caller, not proof that the other
/// device has already received the push notification.
class OutgoingCallScreen extends StatefulWidget {
  const OutgoingCallScreen({
    super.key,
    required this.userId,
    required this.calleeId,
    required this.channelId,
    required this.peerName,
  });

  final int userId;
  final int calleeId;
  final String channelId;
  final String peerName;

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  static const _base = 'https://sportotekaapp.ru/api/calls';
  final AudioPlayer _ringback = AudioPlayer();
  final Stopwatch _elapsed = Stopwatch()..start();
  late final Future<void> _toneStarting;
  Future<void>? _audioDisposal;
  Timer? _pollTimer;
  Timer? _noAnswerTimer;
  int? _callId;
  bool _polling = false;
  bool _finished = false;
  bool _handoff = false;
  String _status = 'Соединяем…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _toneStarting = _playRingback();
    unawaited(_createCall());
  }

  void _log(String event) {
    if (kDebugMode) {
      debugPrint('OUTGOING CALL $event +${_elapsed.elapsedMilliseconds}ms');
    }
  }

  Future<void> _playRingback() async {
    try {
      await _ringback.setReleaseMode(ReleaseMode.loop);
      if (_finished) return;
      await _ringback.play(
        AssetSource('sounds/outgoing_ringback.wav'),
        volume: 0.45,
      );
    } catch (e) {
      _log('ringback playback error: $e');
    }
  }

  Future<void> _releaseAudio() => _audioDisposal ??= _releaseAudioOnce();

  Future<void> _releaseAudioOnce() async {
    await _toneStarting;
    try {
      await _ringback.stop();
    } catch (_) {}
    try {
      await _ringback.dispose();
    } catch (_) {}
  }

  Map<String, dynamic> _json(String body) {
    try {
      final value = jsonDecode(body.trim());
      return value is Map ? Map<String, dynamic>.from(value) : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _createCall() async {
    try {
      final response = await http.post(
        Uri.parse('$_base/create.php'),
        body: {
          'caller_id': widget.userId.toString(),
          'callee_id': widget.calleeId.toString(),
          'channel_id': widget.channelId,
        },
      ).timeout(const Duration(seconds: 45));
      final data = _json(response.body);
      final id = int.tryParse('${data['call_id']}') ?? 0;
      _log('create response HTTP ${response.statusCode} call_id=$id');

      // A cancellation during create.php must also cancel the late call ID.
      if (_finished || !mounted) {
        if (id > 0) unawaited(_cancelCall(id));
        return;
      }
      if (response.statusCode != 200 || data['status'] != 'ok' || id <= 0) {
        if (id > 0) unawaited(_cancelCall(id));
        _finishWithError('Не удалось начать звонок');
        return;
      }

      _callId = id;
      setState(() => _status = 'Ожидание ответа…');
      _pollTimer = Timer.periodic(
        const Duration(milliseconds: 900),
        (_) => unawaited(_pollStatus()),
      );
      _noAnswerTimer = Timer(const Duration(seconds: 70), () {
        if (_finished) return;
        unawaited(_cancelCall(id));
        _finishWithError('Нет ответа');
      });
      unawaited(_pollStatus());
    } catch (e) {
      _log('create error: $e');
      if (!_finished && mounted) {
        _finishWithError('Сеть недоступна. Звонок не удалось начать');
      }
    }
  }

  Future<void> _pollStatus() async {
    final id = _callId;
    if (id == null || _polling || _finished) return;
    _polling = true;
    try {
      final response = await http.post(
        Uri.parse('$_base/status.php'),
        body: {'call_id': '$id', 'user_id': '${widget.userId}'},
      ).timeout(const Duration(seconds: 4));
      if (_finished || !mounted || response.statusCode != 200) return;
      final data = _json(response.body);
      final state = '${data['call_status'] ?? ''}'.trim().toLowerCase();
      if (state == 'accepted') {
        _log('accepted');
        _pollTimer?.cancel();
        _noAnswerTimer?.cancel();
        await _releaseAudio(); // No ringback over the LiveKit conversation.
        if (_finished || !mounted) return;
        _handoff = true;
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => AudioCallScreen(
              callId: id,
              userId: widget.userId,
              isCaller: true,
              peerName: widget.peerName,
            ),
          ),
        );
      } else if ({'declined', 'busy', 'missed', 'canceled', 'cancelled', 'ended'}
          .contains(state)) {
        _log('finished: $state');
        _finishWithError(switch (state) {
          'declined' || 'busy' => 'Вызов отклонён',
          'missed' => 'Нет ответа',
          _ => 'Вызов завершён',
        });
      }
      // A malformed or transient status response cannot end a real call.
    } catch (e) {
      _log('status retry: $e');
    } finally {
      _polling = false;
    }
  }

  Future<void> _cancelCall(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/cancel.php'),
        body: {'call_id': '$id', 'user_id': '${widget.userId}'},
      ).timeout(const Duration(seconds: 4));
      if (_json(response.body)['final_status'] == 'accepted') {
        // The other person answered at the same moment we hung up.
        await http.post(
          Uri.parse('$_base/end.php'),
          body: {'call_id': '$id', 'user_id': '${widget.userId}'},
        ).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      _log('cancel error: $e');
    }
  }

  void _finishWithError(String message) {
    if (_finished || !mounted) return;
    _finished = true;
    _pollTimer?.cancel();
    _noAnswerTimer?.cancel();
    unawaited(_releaseAudio());
    setState(() => _error = message);
  }

  void _hangup() {
    if (_handoff) return;
    if (!_finished) {
      _finished = true;
      _pollTimer?.cancel();
      _noAnswerTimer?.cancel();
      final id = _callId;
      if (id != null) unawaited(_cancelCall(id));
    }
    unawaited(_releaseAudio());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (!_finished && !_handoff) {
      _finished = true;
      final id = _callId;
      if (id != null) unawaited(_cancelCall(id));
    }
    _pollTimer?.cancel();
    _noAnswerTimer?.cancel();
    unawaited(_releaseAudio());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hangup();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Color(0xFF1E2A44),
                  child: Icon(
                    Icons.person_rounded,
                    size: 52,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.peerName.trim().isEmpty ? 'Аудиозвонок' : widget.peerName,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _error == null ? Colors.white70 : Colors.orangeAccent,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Center(
                child: TextButton.icon(
                  onPressed: _hangup,
                  icon: Icon(
                    _error == null ? Icons.call_end_rounded : Icons.close,
                  ),
                  label: Text(_error == null ? 'Завершить' : 'Закрыть'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFFD92D20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 44),
            ],
          ),
        ),
      ),
    );
  }
}
