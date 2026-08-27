import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'call_session_service.dart';

class IosNativeCallBridge {
  IosNativeCallBridge._();

  static const MethodChannel _channel =
      MethodChannel('sportoteka/native_call_bridge');

  static bool _installed = false;
  static bool _acceptBusy = false;

  // PushService подписывается сюда.
  // После успешного native CallKit Accept + LiveKit connect
  // foreground SPORTOTEKA сможет сразу открыть AudioCallScreen.
  static Future<void> Function(Map<String, dynamic> data)?
      onAccepted;

  static Future<void> install() async {
    if (!Platform.isIOS || _installed) return;

    _installed = true;

    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'callAccepted') {
        return _handleAcceptedCall(call.arguments);
      }

      return null;
    });

    // Если пользователь успел нажать "Ответить" раньше,
    // чем Dart зарегистрировал MethodChannel, AppDelegate
    // сохраняет Accept нативно. Подбираем его здесь.
    try {
      final pending =
          await _channel.invokeMethod<dynamic>('consumePendingAccept');

      if (pending is Map && pending.isNotEmpty) {
        final ok = await _handleAcceptedCall(pending);

        if (ok) {
          await _channel.invokeMethod<void>('clearPendingAccept');
        }
      }
    } catch (_) {
      // При обычном запуске pending Accept может отсутствовать.
    }
  }

  static Future<bool> _handleAcceptedCall(dynamic raw) async {
    if (_acceptBusy) return true;

    if (raw is! Map) return false;

    final data = raw.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );

    final callId =
        int.tryParse('${data['call_id'] ?? ''}'.trim()) ?? 0;

    final userId =
        int.tryParse('${data['user_id'] ?? ''}'.trim()) ?? 0;

    final uuid = '${data['uuid'] ?? ''}'.trim();

    if (callId <= 0 || userId <= 0) {
      return false;
    }

    _acceptBusy = true;

    try {
      // Не ждём Navigator/AudioCallScreen.
      // Сам разговор начинает жить здесь.
      await CallSessionService.instance.ensureConnected(
        callId: callId,
        userId: userId,
      );

      // Обычный голосовой звонок iPhone стартует на receiver.
      // Кнопка "Динамик" в CallKit после этого остаётся доступной.
      try {
        await lk.AudioManager.instance
            .setSpeakerOutputPreferred(false);
      } catch (_) {}

      // CallKit получает подтверждение, что медиа уже подключено.
      if (uuid.isNotEmpty) {
        try {
          await FlutterCallkitIncoming.setCallConnected(uuid);
        } catch (_) {}
      }

      // LiveKit уже подключён. Теперь UI может открыть PushService,
      // но только если он уже инициализирован.
      final callback = onAccepted;
      if (callback != null) {
        try {
          await callback(data);
        } catch (_) {}
      }

      return true;
    } catch (_) {
      return false;
    } finally {
      _acceptBusy = false;
    }
  }
}
