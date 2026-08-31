import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'call_session_service.dart';

class IosNativeCallBridge {
  IosNativeCallBridge._();

  static const MethodChannel _channel =
      MethodChannel('sportoteka/native_call_bridge');

  static bool _installed = false;
  static bool _acceptBusy = false;

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

      // CallKit получает подтверждение, что медиа уже подключено.
      if (uuid.isNotEmpty) {
        try {
          await FlutterCallkitIncoming.setCallConnected(uuid);
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
