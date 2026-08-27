import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:sportoteka/call/audio_call_screen.dart';
import 'package:sportoteka/call/call_session_service.dart';
import 'package:sportoteka/call/ios_native_call_bridge.dart';

String _sportotekaCallUuid(int callId) {
  var hex = callId <= 0 ? '0' : callId.toRadixString(16);
  if (hex.length > 12) {
    hex = hex.substring(hex.length - 12);
  }
  hex = hex.padLeft(12, '0');
  return '00000000-0000-4000-8000-$hex';
}

int _sportotekaPushInt(dynamic value) =>
    int.tryParse('${value ?? ''}'.trim()) ?? 0;

CallKitParams _sportotekaCallKitParams(Map<String, dynamic> data) {
  final callId = _sportotekaPushInt(data['call_id']);
  final callerId = _sportotekaPushInt(data['caller_id']);
  final calleeId = _sportotekaPushInt(data['callee_id']);

  final uuid = '${data['uuid'] ?? ''}'.trim().isNotEmpty
      ? '${data['uuid']}'.trim()
      : _sportotekaCallUuid(callId);

  final callerName = '${data['caller_name'] ?? ''}'.trim().isNotEmpty
      ? '${data['caller_name']}'.trim()
      : (callerId > 0 ? 'Пользователь #$callerId' : 'Входящий звонок');

  final avatar = '${data['caller_photo'] ?? ''}'.trim();

  return CallKitParams(
    id: uuid,
    nameCaller: callerName,
    appName: 'SPORTOTEKA',
    avatar: avatar.isEmpty ? null : avatar,
    handle: 'SPORTOTEKA',
    type: 0,
    duration: 90000,
    missedCallNotification: const NotificationParams(
      showNotification: true,
      isShowCallback: false,
      subtitle: 'Пропущенный звонок',
      callbackText: 'Перезвонить',
    ),
    extra: <String, dynamic>{
      'type': 'incoming_call',
      'call_id': callId.toString(),
      'caller_id': callerId.toString(),
      'callee_id': calleeId.toString(),
      'channel_id': '${data['channel_id'] ?? ''}',
      'caller_name': callerName,
      'caller_photo': avatar,
      'transport': '${data['transport'] ?? 'livekit'}',
      'uuid': uuid,
    },
    android: const AndroidParams(
      isCustomNotification: false,
      isShowLogo: false,
      isShowCallID: false,
      ringtonePath: 'ringtone_default',
      actionColor: '#00A750',
      textColor: '#0B0F14',
      incomingCallNotificationChannelName: 'Входящие звонки SPORTOTEKA',
      missedCallNotificationChannelName: 'Пропущенные звонки SPORTOTEKA',
      isShowFullLockedScreen: true,
      // ВАЖНО: false здесь не отключает полноэкранный входящий экран.
      // Плагин создаёт notification с fullScreenIntent.
      // Зато проходят ringtone + activeCalls lifecycle.
      isFullScreen: false,
      isImportant: true,
      textAccept: 'Принять',
      textDecline: 'Отклонить',
    ),
    ios: const IOSParams(
      handleType: 'generic',
      supportsVideo: false,
      maximumCallGroups: 1,
      maximumCallsPerCallGroup: 1,
      audioSessionMode: 'voiceChat',
      audioSessionActive: true,
      audioSessionPreferredSampleRate: 44100.0,
      audioSessionPreferredIOBufferDuration: 0.005,
      configureAudioSession: true,
      supportsDTMF: false,
      supportsHolding: false,
      supportsGrouping: false,
      supportsUngrouping: false,
      ringtonePath: 'system_ringtone_default',
    ),
  );
}

Future<bool> _sportotekaCallIsStillRinging({
  required int callId,
  required int userId,
}) async {
  if (callId <= 0) return false;

  // Если user_id по какой-то причине ещё неизвестен,
  // не рискуем потерять настоящий звонок.
  if (userId <= 0) return true;

  try {
    final response = await http.post(
      Uri.parse(
        'https://sportotekaapp.ru/api/calls/status.php',
      ),
      body: <String, String>{
        'call_id': callId.toString(),
        'user_id': userId.toString(),
      },
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode != 200) {
      return true;
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      return true;
    }

    final map = decoded.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );

    final state = '${map['call_status'] ?? ''}'.trim().toLowerCase();

    // Старый сервер без call_status — не блокируем звонок.
    if (state.isEmpty) return true;

    return state == 'ringing';
  } catch (_) {
    // Сетевой сбой не должен приводить к пропущенному звонку.
    return true;
  }
}

@pragma('vm:entry-point')
Future<void> sportotekaFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();

  final data = Map<String, dynamic>.from(message.data);

  if ('${data['type'] ?? ''}' != 'incoming_call') {
    return;
  }

  if (!Platform.isAndroid) {
    return;
  }

  final callId = _sportotekaPushInt(data['call_id']);

  final userId = _sportotekaPushInt(data['callee_id']);

  if (callId <= 0) {
    return;
  }

  // КРИТИЧНО:
  // FCM может доставить старый incoming_call после того,
  // как звонок уже принят/завершён.
  // Такой пакет больше НЕ должен поднимать экран звонка.
  final ringing = await _sportotekaCallIsStillRinging(
    callId: callId,
    userId: userId,
  );

  if (!ringing) {
    debugPrint(
      '[PUSH] stale Android incoming ignored '
      'callId=$callId',
    );
    return;
  }

  await FlutterCallkitIncoming.showCallkitIncoming(
    _sportotekaCallKitParams(data),
  );
}

@pragma('vm:entry-point')
Future<void> sportotekaCallkitBackgroundHandler(CallEvent event) async {
  CallKitParams? params;
  String? action;

  if (event is CallEventActionCallAccept) {
    params = event.callKitParams;
    action = 'accept';
  } else if (event is CallEventActionCallDecline) {
    params = event.callKitParams;
    action = 'decline';
  } else if (event is CallEventActionCallEnded) {
    params = event.callKitParams;
    action = 'end';
  }

  if (params == null || action == null) return;

  final callId = _sportotekaPushInt(params.extra?['call_id']);
  final userId = _sportotekaPushInt(params.extra?['callee_id']);

  if (callId <= 0 || userId <= 0) return;

  try {
    await http.post(
      Uri.parse(
        'https://sportotekaapp.ru/api/calls/$action.php',
      ),
      body: <String, String>{
        'call_id': callId.toString(),
        'user_id': userId.toString(),
      },
    ).timeout(const Duration(seconds: 8));
  } catch (_) {
    // Foreground isolate retries Accept after it resumes.
  }
}

@pragma('vm:entry-point')
void sportotekaCallkitAcceptHandle(Map<dynamic, dynamic> data) {
  PushService.instance.handleCallkitAcceptHandle(data);
}

class PushService with WidgetsBindingObserver {
  PushService._() {
    if (Platform.isIOS) {
      IosNativeCallBridge.onAccepted = _handleIosNativeAcceptedCall;
    }
  }

  static final PushService instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _saveTokenUrl = '$_apiBase/save_fcm_token.php';
  static const String _acceptCallUrl = '$_apiBase/calls/accept.php';
  static const String _declineCallUrl = '$_apiBase/calls/decline.php';
  static const String _registerVoipTokenUrl =
      '$_apiBase/calls/register_voip_token.php';
  static const String _privateChatsUrl = '$_apiBase/get_user_chats.php';
  static const String _groupsFeedUrl = '$_apiBase/get_groups_feed.php';
  static const String _notificationsUnreadUrl =
      '$_apiBase/notifications/unread_count.php';
  static const String _newsSummaryUrl = '$_apiBase/sportoteka_news/summary.php';

  static const String _chatChannelId = 'chat_messages';
  static const String _updatesChannelId = 'sportoteka_updates';
  static const String _callChannelId = 'calls';

  bool _lifecycleObserverAdded = false;
  bool _inited = false;
  int? _userId;

  int? _visibleCallId;
  bool _callActionInProgress = false;

  // Один AudioCallScreen на один callId.
  final Set<int> _openingAcceptedCallIds = <int>{};
  StreamSubscription<CallEvent?>? _callkitEventSubscription;

  Timer? _badgeSyncTimer;
  bool _badgeSyncInProgress = false;
  int _lastAppliedBadge = -1;

  /// Лог только для Debug
  void _log(Object msg) {
    if (kDebugMode) {
      debugPrint(msg.toString());
    }
  }

  Map<String, dynamic>? _pendingCallkitAccept;

  Future<void> init({required int userId}) async {
    _userId = userId;

    if (!_lifecycleObserverAdded) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverAdded = true;
      _log('CALLKIT lifecycle observer registered');
    }

    if (_inited) {
      _log('PUSH already initialized. userId=$userId');

      try {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _sendTokenToServer(userId: userId, token: token);
        }
      } catch (_) {}

      await _registerCurrentVoipToken(userId);
      unawaited(syncAppBadge(userId: userId));
      return;
    }

    _inited = true;
    WidgetsBinding.instance.addObserver(this);

    _log('PUSH INIT START userId=$userId');

    await _initLocalNotifications();
    await _requestPermission();
    await _initCallKit();

    // If the user accepted from the native lock-screen UI while SPORTOTEKA
    // was being launched, recover the accepted call even if the first event
    // arrived before the Dart listener was ready.
    unawaited(_resumeAcceptedCallIfNeeded());
    unawaited(_consumePendingCallkitAccept());

    // Apple platforms: iOS + macOS.
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        final apns = await _messaging.getAPNSToken();
        _log('APNS TOKEN = $apns');
      } catch (e) {
        _log('APNS TOKEN ERROR: $e');
      }
    }

    // FCM token.
    String? token = await _messaging.getToken();

    // На Apple-платформах токен иногда появляется не мгновенно.
    if (token == null && (Platform.isIOS || Platform.isMacOS)) {
      await Future.delayed(const Duration(seconds: 2));
      token = await _messaging.getToken();
    }

    _log('FCM TOKEN = $token');

    if (token != null && token.isNotEmpty) {
      await _sendTokenToServer(userId: userId, token: token);
    }

    await _registerCurrentVoipToken(userId);

    // Обновление FCM token.
    _messaging.onTokenRefresh.listen((newToken) async {
      _log('FCM TOKEN REFRESHED = $newToken');
      await _sendTokenToServer(
        userId: _userId ?? userId,
        token: newToken,
      );
    });

    // Приложение открыто.
    FirebaseMessaging.onMessage.listen((msg) async {
      _log('FCM FOREGROUND: ${msg.data}');

      if (_isIncomingCall(msg.data)) {
        await _handleIncomingCall(msg.data, showDialog: true);
        return;
      }

      await _showLocal(msg);

      // Сервер уже должен успеть записать новое unread-состояние.
      Future<void>.delayed(const Duration(milliseconds: 700), () async {
        await syncAppBadge();
      });
    });

    // Пользователь нажал системный FCM push, пока приложение было background.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
      _log('FCM OPENED APP: ${msg.data}');
      await _handleRemoteMessage(msg);
    });

    // Пользователь запустил приложение нажатием push из terminated state.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _log('FCM INITIAL MESSAGE: ${initialMessage.data}');

      // Даём GetMaterialApp/навигации завершить первый кадр.
      Future<void>.delayed(const Duration(milliseconds: 500), () async {
        await _handleRemoteMessage(initialMessage);
      });
    }

    // Foreground notifications are rendered by _showLocal() on both
    // platforms. Disable Firebase's second Apple presentation to prevent
    // duplicate banners/sounds.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    _startBadgeSync();
    await syncAppBadge(userId: userId);

    _log('PUSH INIT DONE userId=$userId');
  }

  Future<void> _handleRemoteMessage(RemoteMessage msg) async {
    if (_isIncomingCall(msg.data)) {
      await _handleIncomingCall(msg.data, showDialog: true);
      return;
    }

    _log('Notification opened: ${msg.data}');

    // После открытия push пересчитываем реальное состояние, а не доверяем
    // badge из старого push payload.
    Future<void>.delayed(const Duration(milliseconds: 450), () async {
      await syncAppBadge();
    });
  }

  bool _isIncomingCall(Map<String, dynamic> data) {
    return (data['type'] ?? '').toString() == 'incoming_call';
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    const init = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _local.initialize(
      settings: init,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;

        try {
          final decoded = jsonDecode(payload);
          if (decoded is! Map) return;

          final data = decoded.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          );

          _log('LOCAL NOTIFICATION TAP: $data');

          if (_isIncomingCall(data)) {
            await _handleIncomingCall(data, showDialog: true);
          }
        } catch (e) {
          _log('LOCAL PAYLOAD ERROR: $e');
        }
      },
    );

    if (Platform.isAndroid) {
      const chatChannel = AndroidNotificationChannel(
        _chatChannelId,
        'Chat messages',
        description: 'Notifications for chat messages',
        importance: Importance.high,
      );

      const updatesChannel = AndroidNotificationChannel(
        _updatesChannelId,
        'SPORTOTEKA',
        description: 'Официальные уведомления SPORTOTEKA',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      const callsChannel = AndroidNotificationChannel(
        _callChannelId,
        'Incoming calls',
        description: 'Incoming SPORTOTEKA calls',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(chatChannel);
      await androidPlugin?.createNotificationChannel(updatesChannel);
      await androidPlugin?.createNotificationChannel(callsChannel);
    }
  }

  Future<void> _handleIncomingCall(
    Map<String, dynamic> data, {
    required bool showDialog,
  }) async {
    final callId = int.tryParse((data['call_id'] ?? '').toString()) ?? 0;

    if (callId <= 0) {
      _log('INCOMING CALL ignored: invalid call_id. data=$data');
      return;
    }

    if (Platform.isAndroid) {
      final calleeId = _sportotekaPushInt(data['callee_id']);

      // Запоздавший FCM после accepted/ended/declined игнорируем.
      final ringing = await _sportotekaCallIsStillRinging(
        callId: callId,
        userId: calleeId,
      );

      if (!ringing) {
        _log(
          'INCOMING CALL stale Android push ignored '
          'callId=$callId',
        );
        return;
      }

      // Background isolate мог уже показать системный звонок,
      // а foreground isolate проснулся следом.
      // Не создаём второй native call для того же call_id.
      try {
        final activeCalls = await FlutterCallkitIncoming.activeCalls();

        for (final active in activeCalls) {
          final activeId = _sportotekaPushInt(
            active.extra?['call_id'],
          );

          if (activeId == callId) {
            _visibleCallId = callId;

            _log(
              'INCOMING CALL already exists natively '
              'callId=$callId',
            );

            return;
          }
        }
      } catch (_) {}
    }

    // Если сервер уже доставил iOS VoIP PushKit, системный CallKit создаётся
    // AppDelegate-ом. Не создаём второй экран по FCM-дубликату.
    final voipExpected = '${data['voip_expected'] ?? '0'}' == '1';
    if (Platform.isIOS && voipExpected) {
      _log('INCOMING CALL iOS is owned by PushKit callId=$callId');
      return;
    }

    if (_visibleCallId == callId) {
      _log('INCOMING CALL already visible callId=$callId');
      return;
    }

    _visibleCallId = callId;

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(
        _sportotekaCallKitParams(data),
      );
      _log('CALLKIT shown callId=$callId');
    } catch (e) {
      _visibleCallId = null;
      _log('CALLKIT show error: $e');

      // Последний fallback: обычное высокоприоритетное уведомление.
      await _showIncomingCallLocal(data);
    }
  }

  Future<void> _handleIosNativeAcceptedCall(
    Map<String, dynamic> data,
  ) async {
    if (!Platform.isIOS) return;

    final callId = _sportotekaPushInt(data['call_id']);

    final userId = _sportotekaPushInt(data['user_id']);

    final callerId = _sportotekaPushInt(data['caller_id']);

    final callerName = '${data['caller_name'] ?? ''}'.trim();

    if (callId <= 0 || userId <= 0) {
      _log(
        'IOS NATIVE ACCEPT UI invalid data '
        'callId=$callId userId=$userId',
      );
      return;
    }

    _log(
      'IOS NATIVE ACCEPT LiveKit ready '
      'callId=$callId lifecycle='
      '${WidgetsBinding.instance.lifecycleState}',
    );

    // При заблокированном iPhone остаёмся на системном CallKit.
    // Не пытаемся насильно открыть SPORTOTEKA.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      _log(
        'IOS NATIVE ACCEPT background '
        'callId=$callId — CallKit owns UI',
      );
      return;
    }

    // Приложение уже открыто:
    // native bridge становится гарантированным источником навигации.
    await _openAcceptedCallScreen(
      callId: callId,
      userId: userId,
      callerId: callerId,
      callerName: callerName.isEmpty ? null : callerName,
    );
  }

  Future<void> _acceptIncomingCall({
    required int callId,
    required int callerId,
    int? calleeId,
    String? callerName,
    String? callUuid,
    bool allowAlreadyAccepted = false,
  }) async {
    final userId = _userId ?? calleeId;

    final suppliedUuid = (callUuid ?? '').trim();

    final nativeCallUuid =
        suppliedUuid.isNotEmpty ? suppliedUuid : _sportotekaCallUuid(callId);
    if (userId == null || userId <= 0) {
      _showError('Не удалось определить пользователя.');
      return;
    }

    if (_callActionInProgress) return;
    _callActionInProgress = true;

    try {
      _log('CALL ACCEPT -> callId=$callId userId=$userId');

      final response = await http.post(
        Uri.parse(_acceptCallUrl),
        body: <String, String>{
          'call_id': callId.toString(),
          'user_id': userId.toString(),
        },
      );

      final body = _decodeJson(response.body);

      _log(
        'CALL ACCEPT RESPONSE ${response.statusCode}: ${response.body}',
      );

      final serverStatus = (body['status'] ?? '').toString();
      final error = (body['error'] ?? '').toString();

      final acceptedNow = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          serverStatus == 'ok';

      // On iOS the native CallKit delegate also accepts the server call so
      // the action is reliable even if Dart starts a moment later. In that
      // path a second Dart POST legitimately gets "not_ringing/accepted".
      final acceptedByNative = allowAlreadyAccepted &&
          error == 'not_ringing' &&
          serverStatus == 'accepted';

      if (acceptedNow || acceptedByNative) {
        // КРИТИЧНО ДЛЯ iOS:
        // LiveKit должен подключаться сразу после системного CallKit Accept,
        // даже когда iPhone заблокирован и Navigator ещё недоступен.
        try {
          _log(
            'CALL ACCEPT LiveKit background connect '
            'callId=$callId userId=$userId',
          );

          await CallSessionService.instance.ensureConnected(
            callId: callId,
            userId: userId,
          );

          _log(
            'CALL ACCEPT LiveKit CONNECTED '
            'callId=$callId',
          );

          // Сообщаем iOS CallKit, что медиа реально подключено.
          if (Platform.isIOS || Platform.isAndroid) {
            try {
              await FlutterCallkitIncoming.setCallConnected(
                nativeCallUuid,
              );

              // Android Telecom только сейчас окончательно переводит
              // self-managed call в ACTIVE. Поэтому audio route
              // обязательно применяем ПОСЛЕ setCallConnected().
              if (Platform.isAndroid) {
                await CallSessionService.instance.applyAndroidAudioRoute(
                  callId: callId,
                  callUuid: nativeCallUuid,
                  speaker: false,
                );
              }
            } catch (e) {
              _log(
                'CALLKIT setCallConnected/audio route error: $e',
              );
            }
          }
        } catch (e) {
          _log(
            'CALL ACCEPT background LiveKit error '
            'callId=$callId error=$e',
          );
        }

        if (Get.isDialogOpen == true) {
          Get.back<void>();
        }

        // Экран вторичен.
        // Если телефон заблокирован, Room уже работает без него.
        await _openAcceptedCallScreen(
          callId: callId,
          userId: userId,
          callerId: callerId,
          callerName: callerName,
        );
        return;
      }

      if (error == 'not_ringing' && serverStatus == 'accepted') {
        _visibleCallId = null;
        _showError('Этот звонок уже принят на другом устройстве.');
        return;
      }

      _visibleCallId = null;
      _showError('Не удалось принять звонок.');
    } catch (e) {
      _log('CALL ACCEPT ERROR: $e');

      // If native iOS already accepted the server call, a short Dart-side
      // network failure must not strand the user on the CallKit screen.
      if (allowAlreadyAccepted) {
        try {
          await CallSessionService.instance.ensureConnected(
            callId: callId,
            userId: userId,
          );

          if (Platform.isIOS) {
            try {
              await FlutterCallkitIncoming.setCallConnected(
                nativeCallUuid,
              );
            } catch (_) {}
          }
        } catch (connectError) {
          _log(
            'CALL ACCEPT fallback LiveKit error '
            'callId=$callId error=$connectError',
          );
        }

        await _openAcceptedCallScreen(
          callId: callId,
          userId: userId,
          callerId: callerId,
          callerName: callerName,
        );
      } else {
        _showError('Ошибка соединения при принятии звонка.');
      }
    } finally {
      _callActionInProgress = false;
    }
  }

  Future<void> _openAcceptedCallScreen({
    required int callId,
    required int userId,
    required int callerId,
    String? callerName,
  }) async {
    if (_openingAcceptedCallIds.contains(callId)) {
      _log(
        'CALL SCREEN duplicate open ignored '
        'callId=$callId',
      );
      return;
    }

    _openingAcceptedCallIds.add(callId);

    try {
      final peerName = (callerName ?? '').trim().isNotEmpty
          ? callerName!.trim()
          : (callerId > 0 ? 'Пользователь #$callerId' : 'Входящий звонок');

      _visibleCallId = callId;

      // CallKit may have woken SPORTOTEKA from terminated state.
      // Wait briefly for GetMaterialApp/Navigator to exist.
      for (var i = 0; i < 40 && Get.context == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      if (Get.context == null) {
        _log('CALL ACCEPTED but navigation context is not ready');
        return;
      }

      await Get.to<void>(
        () => AudioCallScreen(
          isIncoming: true,
          callId: callId,
          userId: userId,
          isCaller: false,
          peerName: peerName,
        ),
      );

      _visibleCallId = null;

      // Возврат из AudioCallScreen сам по себе больше НЕ означает конец звонка.
      // Например, iOS может заменить экран приложения системным CallKit UI.
      final session = CallSessionService.instance;
      final activeRoom = session.room;

      final sameCallStillActive = session.callId == callId &&
          activeRoom != null &&
          activeRoom.connectionState != lk.ConnectionState.disconnected;

      if (sameCallStillActive) {
        _log(
          'CALL SCREEN closed but session remains active '
          'callId=$callId state=${activeRoom.connectionState}',
        );
      } else if (Platform.isAndroid || Platform.isIOS) {
        try {
          await FlutterCallkitIncoming.endCall(
            _sportotekaCallUuid(callId),
          );
        } catch (_) {}
      }
    } finally {
      _openingAcceptedCallIds.remove(callId);
    }
  }

  Future<void> _declineIncomingCall(int callId) async {
    final userId = _userId;
    if (userId == null || userId <= 0) {
      _showError('Не удалось определить пользователя.');
      return;
    }

    if (_callActionInProgress) return;
    _callActionInProgress = true;

    try {
      _log('CALL DECLINE -> callId=$callId userId=$userId');

      final response = await http.post(
        Uri.parse(_declineCallUrl),
        body: {
          'call_id': callId.toString(),
          'user_id': userId.toString(),
        },
      );

      _log(
        'CALL DECLINE RESPONSE ${response.statusCode}: ${response.body}',
      );

      if (Get.isDialogOpen == true) {
        Get.back<void>();
      }

      _visibleCallId = null;

      try {
        await FlutterCallkitIncoming.endCall(
          _sportotekaCallUuid(callId),
        );
      } catch (_) {}
    } catch (e) {
      _log('CALL DECLINE ERROR: $e');
      _showError('Не удалось отклонить звонок.');
    } finally {
      _callActionInProgress = false;
    }
  }

  void handleCallkitAcceptHandle(Map<dynamic, dynamic> raw) {
    final data = raw.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );

    _pendingCallkitAccept = data;

    _log('CALLKIT ACCEPT HANDLE received: $data');

    unawaited(_consumePendingCallkitAccept());
  }

  Map<String, dynamic> _callkitStringMap(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return <String, dynamic>{};
  }

  int _callIdFromCallkitUuid(dynamic value) {
    final uuid = '${value ?? ''}'.trim();
    if (uuid.isEmpty) return 0;

    // SPORTOTEKA UUID:
    // 00000000-0000-4000-8000-00000000002c -> call_id 44
    final parts = uuid.split('-');
    if (parts.isEmpty) return 0;

    final tail = parts.last.trim();

    final hex = int.tryParse(tail, radix: 16);
    if (hex != null && hex > 0) {
      return hex;
    }

    return int.tryParse(uuid) ?? 0;
  }

  Future<void> _consumePendingCallkitAccept() async {
    final pending = _pendingCallkitAccept;
    if (pending == null) return;

    final body = _callkitStringMap(
      pending['body'] ?? pending['data'] ?? pending['callData'] ?? pending,
    );

    final extra = _callkitStringMap(body['extra']);

    var callId = _sportotekaPushInt(
      extra['call_id'] ?? body['call_id'],
    );

    if (callId <= 0) {
      callId = _callIdFromCallkitUuid(
        body['id'] ?? pending['id'],
      );
    }

    final callerId = _sportotekaPushInt(
      extra['caller_id'] ?? body['caller_id'],
    );

    var calleeId = _sportotekaPushInt(
      extra['callee_id'] ?? body['callee_id'],
    );

    if (calleeId <= 0) {
      calleeId = _userId ?? 0;
    }

    final callerName =
        '${extra['caller_name'] ?? body['caller_name'] ?? body['nameCaller'] ?? 'Входящий звонок'}'
            .trim();

    if (callId <= 0 || calleeId <= 0) {
      _log(
        'CALLKIT ACCEPT HANDLE invalid IDs '
        'callId=$callId calleeId=$calleeId',
      );
      return;
    }

    // КРИТИЧНО:
    // LiveKit запускаем сразу из CallKit Accept.
    // Navigator/Get.context здесь НЕ нужен.
    try {
      _log(
        'CALLKIT BACKGROUND CONNECT '
        'callId=$callId userId=$calleeId',
      );

      await CallSessionService.instance.ensureConnected(
        callId: callId,
        userId: calleeId,
      );

      _log(
        'CALLKIT BACKGROUND CONNECTED '
        'callId=$callId',
      );
    } catch (e) {
      _log(
        'CALLKIT BACKGROUND CONNECT ERROR '
        'callId=$callId error=$e',
      );
    }

    _pendingCallkitAccept = null;

    // Экран разговора открываем только если/когда UI реально доступен.
    for (var attempt = 0; attempt < 40; attempt++) {
      if (Get.context == null) {
        await Future<void>.delayed(
          const Duration(milliseconds: 250),
        );
        continue;
      }

      await _acceptIncomingCall(
        callId: callId,
        callerId: callerId,
        calleeId: calleeId,
        callerName: callerName,
        allowAlreadyAccepted: true,
      );

      return;
    }

    _log(
      'CALLKIT background call connected, '
      'UI remains locked callId=$callId',
    );
  }

  Future<void> _recoverAcceptedCallOnResume() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _log('CALLKIT foreground recovery START');

    // После системного Accept CallKit и Flutter могут проснуться
    // с небольшой разницей по времени.
    for (var attempt = 1; attempt <= 12; attempt++) {
      if (_callActionInProgress) {
        _log(
          'CALLKIT foreground recovery: '
          'call action already running',
        );
        return;
      }

      try {
        final calls = await FlutterCallkitIncoming.activeCalls();

        _log(
          'CALLKIT foreground recovery '
          'attempt=$attempt activeCalls=${calls.length}',
        );

        for (final params in calls) {
          if (!params.isAccepted) continue;

          final callId = _extraInt(params, 'call_id');
          if (callId <= 0) continue;

          final callerId = _extraInt(params, 'caller_id');

          var calleeId = _extraInt(
            params,
            'callee_id',
          );

          if (calleeId <= 0) {
            calleeId = _userId ?? 0;
          }

          if (calleeId <= 0) continue;

          final callerName = _extraString(
            params,
            'caller_name',
          );

          _log(
            'CALLKIT foreground recovery accepted '
            'callId=$callId '
            'callerId=$callerId '
            'calleeId=$calleeId',
          );

          // Если background Accept уже успел подключить LiveKit,
          // ensureConnected просто вернёт существующий Room.
          // Если событие background было потеряно — подключаем здесь.
          try {
            await CallSessionService.instance.ensureConnected(
              callId: callId,
              userId: calleeId,
            );
          } catch (e) {
            _log(
              'CALLKIT foreground LiveKit recovery '
              'callId=$callId error=$e',
            );
          }

          if (Get.context == null) {
            await Future<void>.delayed(
              const Duration(milliseconds: 250),
            );
            continue;
          }

          _visibleCallId = null;

          await _acceptIncomingCall(
            callId: callId,
            callerId: callerId,
            calleeId: calleeId,
            callerName: callerName,
            allowAlreadyAccepted: true,
          );

          return;
        }
      } catch (e) {
        _log(
          'CALLKIT foreground recovery '
          'attempt=$attempt error=$e',
        );
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 300),
      );
    }

    _log(
      'CALLKIT foreground recovery: '
      'no accepted call found',
    );
  }

  Future<void> _initCallKit() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    FlutterCallkitIncoming.acceptCallHandle(
      sportotekaCallkitAcceptHandle,
    );

    // Plugin-level killed/background action handler.
    await FlutterCallkitIncoming.onBackgroundMessage(
      sportotekaCallkitBackgroundHandler,
    );

    _callkitEventSubscription ??=
        FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      unawaited(_handleCallKitEvent(event));
    });

    if (Platform.isAndroid) {
      try {
        final canUse = await FlutterCallkitIncoming.canUseFullScreenIntent();
        _log('CALLKIT fullScreenIntent allowed=$canUse');

        if (!canUse) {
          await FlutterCallkitIncoming.requestFullIntentPermission();
        }
      } catch (e) {
        _log('CALLKIT fullScreenIntent permission error: $e');
      }
    }
  }

  CallKitParams? _paramsFromCallEvent(CallEvent event) {
    try {
      final dynamic dynamicEvent = event;
      final dynamic params = dynamicEvent.callKitParams;
      return params is CallKitParams ? params : null;
    } catch (_) {
      return null;
    }
  }

  int _extraInt(CallKitParams? params, String key) {
    final value = params?.extra?[key];
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  String _extraString(CallKitParams? params, String key) =>
      '${params?.extra?[key] ?? ''}'.trim();

  Future<void> _handleCallKitEvent(CallEvent event) async {
    final eventName = event.eventName.toLowerCase();
    final params = _paramsFromCallEvent(event);

    _log('CALLKIT EVENT ${event.eventName} params=$params');

    if (eventName.contains('device_push_token_voip')) {
      final userId = _userId ?? 0;
      if (userId > 0) {
        await _registerCurrentVoipToken(userId);
      }
      return;
    }

    final callId = _extraInt(params, 'call_id');
    final callerId = _extraInt(params, 'caller_id');
    final calleeId = _extraInt(params, 'callee_id');
    final callerName = _extraString(params, 'caller_name');

    if (eventName.contains('accept')) {
      if (callId <= 0) return;

      // Android 3.1.x использует self-managed Telecom.
      // После ACTION_CALL_ACCEPT не скрываем CallKit вручную:
      // native Telecom сам завершает ringing lifecycle.
      // Иначе можно разрушить audio lifecycle до запуска WebRTC.

      await _acceptIncomingCall(
        callId: callId,
        callerId: callerId,
        calleeId: calleeId,
        callerName: callerName,
        callUuid: _extraString(params, 'uuid'),
        allowAlreadyAccepted: true,
      );
      return;
    }

    if (eventName.contains('decline')) {
      if (callId > 0) {
        await _declineIncomingCall(callId);
      }
      return;
    }

    if (eventName.contains('timeout')) {
      _visibleCallId = null;
      _log('CALLKIT timeout callId=$callId');
      return;
    }

    if (eventName.contains('ended')) {
      _visibleCallId = null;
    }
  }

  Future<void> _resumeAcceptedCallIfNeeded() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    await Future<void>.delayed(const Duration(milliseconds: 450));

    try {
      final calls = await FlutterCallkitIncoming.activeCalls();

      for (final params in calls) {
        if (!params.isAccepted) continue;

        final callId = _extraInt(params, 'call_id');
        if (callId <= 0) continue;
        if (_visibleCallId == callId || _callActionInProgress) return;

        final callerId = _extraInt(params, 'caller_id');
        final calleeId = _extraInt(params, 'callee_id');
        final callerName = _extraString(params, 'caller_name');

        _log('CALLKIT resume accepted callId=$callId');

        await _acceptIncomingCall(
          callId: callId,
          callerId: callerId,
          calleeId: calleeId,
          callerName: callerName,
          allowAlreadyAccepted: true,
        );
        return;
      }
    } catch (e) {
      _log('CALLKIT resume error: $e');
    }
  }

  Future<void> _registerCurrentVoipToken(int userId) async {
    if (!Platform.isIOS || userId <= 0) return;

    try {
      String? token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();

      if ((token ?? '').trim().isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      }

      final clean = (token ?? '').trim();
      if (clean.isEmpty) {
        _log('VOIP TOKEN is not ready yet');
        return;
      }

      final response = await http.post(
        Uri.parse(_registerVoipTokenUrl),
        body: <String, String>{
          'user_id': userId.toString(),
          'token': clean,
          'platform': 'ios',
        },
      ).timeout(const Duration(seconds: 10));

      _log(
        'VOIP TOKEN SAVE ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      _log('VOIP TOKEN SAVE ERROR: $e');
    }
  }

  Map<String, dynamic> _decodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      // ignore
    }

    return <String, dynamic>{};
  }

  void _showError(String text) {
    if (Get.context == null) {
      _log(text);
      return;
    }

    Get.snackbar(
      'Звонок',
      text,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _showIncomingCallLocal(Map<String, dynamic> data) async {
    final callId = int.tryParse((data['call_id'] ?? '').toString()) ??
        DateTime.now().millisecondsSinceEpoch;

    final callerId = int.tryParse((data['caller_id'] ?? '').toString()) ?? 0;

    const android = AndroidNotificationDetails(
      _callChannelId,
      'Incoming calls',
      channelDescription: 'Incoming SPORTOTEKA calls',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: true,
    );

    const apple = DarwinNotificationDetails(
      presentAlert: true,
      // Badge управляется централизованно через syncAppBadge().
      presentBadge: false,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: android,
      iOS: apple,
      macOS: apple,
    );

    await _local.show(
      id: callId % 2147483647,
      title: 'Входящий звонок',
      body: callerId > 0 ? 'Пользователь #$callerId звонит вам' : 'Вам звонят…',
      notificationDetails: details,
      payload: jsonEncode(data),
    );
  }

  Future<void> _showLocal(RemoteMessage msg) async {
    final title = msg.notification?.title ??
        (msg.data['title'] ?? 'Сообщение').toString();
    final body = msg.notification?.body ?? (msg.data['body'] ?? '').toString();

    final isSportotekaUpdate =
        (msg.data['type'] ?? '').toString() == 'sportoteka_notification' ||
            (msg.data['type'] ?? '').toString() == 'sportoteka_news';

    final android = AndroidNotificationDetails(
      isSportotekaUpdate ? _updatesChannelId : _chatChannelId,
      isSportotekaUpdate ? 'SPORTOTEKA' : 'Chat messages',
      channelDescription: isSportotekaUpdate
          ? 'Официальные уведомления SPORTOTEKA'
          : 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const apple = DarwinNotificationDetails(
      presentAlert: true,
      // Badge управляется централизованно через syncAppBadge().
      presentBadge: false,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: android,
      iOS: apple,
      macOS: apple,
    );

    final id = (int.tryParse(msg.data['message_id'] ?? '') ??
            DateTime.now().millisecondsSinceEpoch) %
        2147483647;

    await _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(msg.data),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_recoverAcceptedCallOnResume());
    }

    if (state == AppLifecycleState.resumed) {
      _startBadgeSync();
      unawaited(syncAppBadge());
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _badgeSyncTimer?.cancel();
      _badgeSyncTimer = null;
    }
  }

  void _startBadgeSync() {
    _badgeSyncTimer?.cancel();

    // Пока приложение открыто, раз в несколько секунд приводим launcher badge
    // к серверной истине. Поэтому после чтения уведомления цифра исчезнет,
    // даже если конкретный экран не знает о системном badge.
    _badgeSyncTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => unawaited(syncAppBadge()),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  bool _isPrivateChat(Map<dynamic, dynamic> chat) {
    final type =
        '${chat['type'] ?? chat['chat_type'] ?? ''}'.trim().toLowerCase();

    if (type == 'private' || type == 'personal' || type == 'direct') {
      return true;
    }

    final flag = chat['is_private'];
    return flag == 1 || flag == '1' || flag == true;
  }

  bool _isGroupMember(Map<dynamic, dynamic> group) {
    final flag = group['i_am_member'];

    // Старые версии API могли не присылать поле. Тогда строка уже относится
    // к доступным группам пользователя.
    return flag == null || flag == 1 || flag == '1' || flag == true;
  }

  int _sumUnreadRows(
    dynamic raw, {
    bool Function(Map<dynamic, dynamic>)? filter,
  }) {
    if (raw is! List) return 0;

    var total = 0;

    for (final entry in raw.whereType<Map>()) {
      if (filter != null && !filter(entry)) continue;

      final unread = _asInt(entry['unread_count']);
      if (unread > 0) total += unread;
    }

    return total;
  }

  Future<int> _fetchPrivateChatUnread(int userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_privateChatsUrl?user_id=$userId'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return 0;

      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        return _sumUnreadRows(
          decoded,
          filter: _isPrivateChat,
        );
      }
    } catch (e) {
      _log('BADGE private chats error: $e');
    }

    return 0;
  }

  Future<int> _fetchGroupUnread(int userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_groupsFeedUrl?user_id=$userId'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return 0;

      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded['success'] == true) {
        return _sumUnreadRows(
          decoded['groups'],
          filter: _isGroupMember,
        );
      }
    } catch (e) {
      _log('BADGE groups error: $e');
    }

    return 0;
  }

  Future<int> _fetchImportantUnread(int userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_notificationsUnreadUrl?user_id=$userId'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return 0;

      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded['success'] == true) {
        return _asInt(decoded['unread_count']).clamp(0, 9999).toInt();
      }
    } catch (e) {
      _log('BADGE notifications error: $e');
    }

    return 0;
  }

  Future<int> _fetchSportotekaNewsUnread(int userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_newsSummaryUrl?user_id=$userId'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return 0;

      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded['success'] == true) {
        final visible = decoded['visible'] == true ||
            decoded['visible'] == 1 ||
            decoded['visible'] == '1';

        if (!visible) return 0;

        return _asInt(decoded['unread_count']).clamp(0, 9999).toInt();
      }
    } catch (e) {
      _log('BADGE SPORTOTEKA news error: $e');
    }

    return 0;
  }

  /// Единый источник системной цифры на иконке приложения.
  ///
  /// Считаются только реальные серверные unread:
  /// - личные чаты;
  /// - группы;
  /// - Центр уведомлений;
  /// - SPORTOTEKA Новости.
  ///
  /// Если всё прочитано, выставляем 0 и системная цифра снимается.
  Future<int> syncAppBadge({int? userId}) async {
    final resolvedUserId = userId ?? _userId ?? 0;

    if (resolvedUserId <= 0 || _badgeSyncInProgress) {
      return _lastAppliedBadge < 0 ? 0 : _lastAppliedBadge;
    }

    _badgeSyncInProgress = true;

    try {
      final values = await Future.wait<int>(<Future<int>>[
        _fetchPrivateChatUnread(resolvedUserId),
        _fetchGroupUnread(resolvedUserId),
        _fetchImportantUnread(resolvedUserId),
        _fetchSportotekaNewsUnread(resolvedUserId),
      ]);

      final total = values.fold<int>(0, (sum, value) => sum + value);
      final badge = total.clamp(0, 9999).toInt();

      if (_lastAppliedBadge == badge) {
        return badge;
      }

      try {
        final supported = await AppBadgePlus.isSupported();

        if (supported) {
          await AppBadgePlus.updateBadge(badge);
          _lastAppliedBadge = badge;
          _log(
            'APP BADGE = $badge '
            '(chat=${values[0]}, groups=${values[1]}, '
            'notifications=${values[2]}, news=${values[3]})',
          );
        } else {
          _log('APP BADGE not supported on this launcher/platform');
        }
      } catch (e) {
        _log('APP BADGE native error: $e');
      }

      return badge;
    } finally {
      _badgeSyncInProgress = false;
    }
  }

  Future<void> _sendTokenToServer({
    required int userId,
    required String token,
  }) async {
    try {
      // Текущая серверная схема использует android/ios.
      // macOS относится к Apple/APNs, поэтому сохраняем его как ios.
      final platform = (Platform.isIOS || Platform.isMacOS) ? 'ios' : 'android';

      _log('SEND TOKEN -> userId=$userId platform=$platform');

      final res = await http.post(
        Uri.parse(_saveTokenUrl),
        body: {
          'user_id': userId.toString(),
          'token': token,
          'platform': platform,
        },
      );

      _log('SAVE TOKEN RESPONSE: ${res.statusCode} ${res.body}');
    } catch (e) {
      _log('SAVE TOKEN ERROR: $e');
    }
  }
}
