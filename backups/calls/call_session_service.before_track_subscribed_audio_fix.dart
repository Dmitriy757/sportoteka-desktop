import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;

class CallSessionService extends ChangeNotifier {
  CallSessionService._();

  static final CallSessionService instance = CallSessionService._();

  static const String _apiBase =
      'https://sportotekaapp.ru/api/calls';

  static const MethodChannel _androidCallAudio =
      MethodChannel('sportoteka/call_audio');

  lk.Room? _room;
  int? _callId;
  int? _userId;
  String? _roomName;

  Future<lk.Room>? _connectFuture;
  Timer? _statusTimer;
  bool _statusBusy = false;

  lk.Room? get room => _room;
  int? get callId => _callId;
  int? get userId => _userId;
  String? get roomName => _roomName;

  bool get isConnected =>
      _room?.connectionState == lk.ConnectionState.connected;


  String _sportotekaAndroidCallUuid(int callId) {
    var hex = callId <= 0 ? '0' : callId.toRadixString(16);

    if (hex.length > 12) {
      hex = hex.substring(hex.length - 12);
    }

    hex = hex.padLeft(12, '0');

    return '00000000-0000-4000-8000-$hex';
  }

  Future<void> applyAndroidAudioRoute({
    required int callId,
    String? callUuid,
    bool speaker = false,
  }) async {
    if (!Platform.isAndroid) return;

    final suppliedUuid =
        (callUuid ?? '').trim();

    final uuid = suppliedUuid.isNotEmpty
        ? suppliedUuid
        : _sportotekaAndroidCallUuid(callId);

    // После CallKit/Telecom ACTION_CONNECTED Android может
    // повторно изменить communication device. Поэтому route
    // применяем несколько раз уже ПОСЛЕ перевода call в ACTIVE.
    const delays = <int>[0, 300, 750];

    for (final delayMs in delays) {
      if (delayMs > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: delayMs),
        );
      }

      try {
        await lk.AudioManager.instance
            .setSpeakerOutputPreferred(
          speaker,
          force: speaker,
        );

        await _androidCallAudio.invokeMethod<bool>(
          'setSpeaker',
          <String, dynamic>{
            'enabled': speaker,
            'callUuid': uuid,
          },
        );

        debugPrint(
          '[CALL_SESSION] Android POST-ACTIVE route '
          'callId=$callId '
          'uuid=$uuid '
          'speaker=$speaker '
          'delay=$delayMs',
        );
      } catch (e) {
        debugPrint(
          '[CALL_SESSION] Android POST-ACTIVE route ERROR '
          'callId=$callId '
          'delay=$delayMs error=$e',
        );
      }
    }
  }

  Future<lk.Room> ensureConnected({
    required int callId,
    required int userId,
  }) async {
    var current = _room;

    // Уже запущенный connect этого же callId всегда ждём,
    // а не создаём второй Room.
    final running = _connectFuture;

    if (_callId == callId && running != null) {
      debugPrint(
        '[CALL_SESSION] reuse pending connect '
        'callId=$callId',
      );

      return running;
    }

    if (_callId == callId && current != null) {
      if (current.connectionState ==
          lk.ConnectionState.connected) {
        debugPrint(
          '[CALL_SESSION] reuse connected room '
          'callId=$callId',
        );

        return current;
      }

      // connecting/reconnecting может восстановиться самостоятельно,
      // но не разрешаем висеть в этом состоянии бесконечно.
      if (current.connectionState ==
              lk.ConnectionState.connecting ||
          current.connectionState ==
              lk.ConnectionState.reconnecting) {
        debugPrint(
          '[CALL_SESSION] waiting stale room '
          'callId=$callId '
          'state=${current.connectionState}',
        );

        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(
            const Duration(milliseconds: 250),
          );

          // За время ожидания уже мог начаться другой звонок.
          if (_callId != callId ||
              !identical(_room, current)) {
            break;
          }

          if (current.connectionState ==
              lk.ConnectionState.connected) {
            debugPrint(
              '[CALL_SESSION] room recovered '
              'callId=$callId',
            );

            return current;
          }

          if (current.connectionState ==
              lk.ConnectionState.disconnected) {
            break;
          }
        }
      }

      // Если через ~2 секунды Room так и не восстановился,
      // это уже stale/reconnect loop.
      //
      // Удаляем только медиасессию.
      // Серверный звонок при этом НЕ завершаем.
      if (_callId == callId &&
          identical(_room, current)) {
        debugPrint(
          '[CALL_SESSION] stale room reset '
          'callId=$callId '
          'state=${current.connectionState}',
        );

        await disconnect();
      }

      current = null;
    }

    // Если осталась сессия другого звонка — сначала очищаем её.
    if (_callId != null &&
        _callId != callId) {
      debugPrint(
        '[CALL_SESSION] replacing previous call '
        'old=$_callId new=$callId',
      );

      await disconnect();
    }

    final future = _connect(
      callId: callId,
      userId: userId,
    );

    _connectFuture = future;

    try {
      return await future;
    } finally {
      if (identical(_connectFuture, future)) {
        _connectFuture = null;
      }
    }
  }

  Future<lk.Room> _connect({
    required int callId,
    required int userId,
  }) async {
    if (_callId != null && _callId != callId) {
      await disconnect();
    }

    _callId = callId;
    _userId = userId;

    final details = await _fetchDetailsWithRetry(
      callId: callId,
      userId: userId,
    );

    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );

    _room = room;
    _roomName = details.roomName;

    await room.prepareConnection(
      details.serverUrl,
      details.token,
    );

    debugPrint(
      '[CALL_SESSION] CONNECT START '
      'callId=$callId url=${details.serverUrl} '
      'room=${details.roomName}',
    );

    await room.connect(
      details.serverUrl,
      details.token,
    );

    debugPrint(
      '[CALL_SESSION] CONNECTED '
      'callId=$callId '
      'state=${room.connectionState} '
      'remoteParticipants=${room.remoteParticipants.length}',
    );

    await room.localParticipant?.setMicrophoneEnabled(true);

    debugPrint(
      '[CALL_SESSION] MIC ENABLED '
      'callId=$callId',
    );

    for (final participant in room.remoteParticipants.values) {
      debugPrint(
        '[CALL_SESSION] REMOTE PARTICIPANT '
        'callId=$callId '
        'identity=${participant.identity} '
        'tracks=${participant.trackPublications.length}',
      );

      for (final publication
          in participant.trackPublications.values) {
        debugPrint(
          '[CALL_SESSION] REMOTE TRACK '
          'callId=$callId '
          'kind=${publication.kind} '
          'subscribed=${publication.subscribed} '
          'muted=${publication.muted}',
        );
      }
    }

    // Android incoming call:
    // после рингтона Telecom и LiveKit должны получить ОДИНАКОВЫЙ
    // communication route. Это тот же native bridge, который уже
    // работает в исходящих звонках.
    if (Platform.isAndroid) {
      final uuid = _sportotekaAndroidCallUuid(callId);

      try {
        await lk.AudioManager.instance.setSpeakerOutputPreferred(
          false,
        );

        await _androidCallAudio.invokeMethod<bool>(
          'setSpeaker',
          <String, dynamic>{
            'enabled': false,
            'callUuid': uuid,
          },
        );

        debugPrint(
          '[CALL_SESSION] Android incoming audio route #1 '
          'callId=$callId',
        );

        // Telecom переводит self-managed connection в ACTIVE
        // асинхронно. Повторяем route после этого перехода.
        await Future<void>.delayed(
          const Duration(milliseconds: 450),
        );

        await lk.AudioManager.instance.setSpeakerOutputPreferred(
          false,
        );

        await _androidCallAudio.invokeMethod<bool>(
          'setSpeaker',
          <String, dynamic>{
            'enabled': false,
            'callUuid': uuid,
          },
        );

        debugPrint(
          '[CALL_SESSION] Android incoming audio route #2 '
          'callId=$callId',
        );
      } catch (e) {
        debugPrint(
          '[CALL_SESSION] Android incoming audio route ERROR '
          'callId=$callId error=$e',
        );
      }
    }

    _startStatusPolling();

    notifyListeners();

    return room;
  }

  Future<_CallConnectionDetails> _fetchDetailsWithRetry({
    required int callId,
    required int userId,
  }) async {
    Object? lastError;

    // Native CallKit accept.php и Dart могут стартовать почти одновременно.
    // Даём серверу короткое время перейти ringing -> accepted.
    for (var attempt = 0; attempt < 12; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$_apiBase/livekit_token.php'),
          body: <String, String>{
            'call_id': callId.toString(),
            'user_id': userId.toString(),
          },
        ).timeout(const Duration(seconds: 5));

        Map<String, dynamic> data = <String, dynamic>{};

        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            data = decoded.map<String, dynamic>(
              (key, value) => MapEntry(key.toString(), value),
            );
          }
        } catch (_) {}

        if (response.statusCode == 200 &&
            data['status'] == 'ok') {
          final serverUrl =
              '${data['server_url'] ?? ''}'.trim();
          final token =
              '${data['participant_token'] ?? ''}'.trim();
          final roomName =
              '${data['room_name'] ?? ''}'.trim();

          if (serverUrl.isNotEmpty &&
              token.isNotEmpty &&
              roomName.isNotEmpty) {
            return _CallConnectionDetails(
              serverUrl: serverUrl,
              token: token,
              roomName: roomName,
            );
          }
        }

        final error = '${data['error'] ?? ''}';

        if (error != 'call_not_accepted' &&
            error != 'not_ringing') {
          throw StateError(
            error.isEmpty
                ? 'livekit_token_${response.statusCode}'
                : error,
          );
        }

        lastError = StateError(error);
      } catch (e) {
        lastError = e;
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 250),
      );
    }

    throw lastError ?? StateError('livekit_token_failed');
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();

    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_pollStatus()),
    );
  }

  Future<void> _pollStatus() async {
    if (_statusBusy) return;

    final callId = _callId;
    final userId = _userId;

    if (callId == null || userId == null) return;

    _statusBusy = true;

    try {
      final response = await http.post(
        Uri.parse('$_apiBase/status.php'),
        body: <String, String>{
          'call_id': callId.toString(),
          'user_id': userId.toString(),
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;

      final data = Map<String, dynamic>.from(decoded);

      final status =
          '${data['call_status'] ?? ''}'.trim().toLowerCase();

      if (status == 'ended' ||
          status == 'declined' ||
          status == 'missed' ||
          status == 'canceled' ||
          status == 'cancelled') {
        await _closeNativeCall(callId);
        await disconnect();
      }
    } catch (_) {
      // Короткий сетевой сбой не должен ронять разговор.
    } finally {
      _statusBusy = false;
    }
  }

  Future<void> _closeNativeCall(int callId) async {
    try {
      if (Platform.isAndroid) {
        // SPORTOTEKA разрешает только один звонок одновременно.
        // Это также очищает возможный зависший Android duplicate.
        await FlutterCallkitIncoming.endAllCalls();
      } else if (Platform.isIOS) {
        await FlutterCallkitIncoming.endCall(
          _uuidForCall(callId),
        );
      }
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _statusTimer?.cancel();
    _statusTimer = null;

    final room = _room;

    _room = null;
    _roomName = null;
    _callId = null;
    _userId = null;

    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {}

      try {
        await room.dispose();
      } catch (_) {}
    }

    notifyListeners();
  }

  String _uuidForCall(int callId) {
    var hex = callId.toRadixString(16);

    if (hex.length > 12) {
      hex = hex.substring(hex.length - 12);
    }

    hex = hex.padLeft(12, '0');

    return '00000000-0000-4000-8000-$hex';
  }
}

class _CallConnectionDetails {
  final String serverUrl;
  final String token;
  final String roomName;

  const _CallConnectionDetails({
    required this.serverUrl,
    required this.token,
    required this.roomName,
  });
}
