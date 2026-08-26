import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/call/audio_call_screen.dart';

class PushService with WidgetsBindingObserver {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _saveTokenUrl = '$_apiBase/save_fcm_token.php';
  static const String _acceptCallUrl = '$_apiBase/calls/accept.php';
  static const String _declineCallUrl = '$_apiBase/calls/decline.php';
  static const String _privateChatsUrl = '$_apiBase/get_user_chats.php';
  static const String _groupsFeedUrl = '$_apiBase/get_groups_feed.php';
  static const String _notificationsUnreadUrl =
      '$_apiBase/notifications/unread_count.php';
  static const String _newsSummaryUrl =
      '$_apiBase/sportoteka_news/summary.php';

  static const String _chatChannelId = 'chat_messages';
  static const String _callChannelId = 'calls';

  bool _inited = false;
  int? _userId;

  int? _visibleCallId;
  bool _callActionInProgress = false;

  Timer? _badgeSyncTimer;
  bool _badgeSyncInProgress = false;
  int _lastAppliedBadge = -1;

  /// Лог только для Debug
  void _log(Object msg) {
    if (kDebugMode) {
      debugPrint(msg.toString());
    }
  }

  Future<void> init({required int userId}) async {
    _userId = userId;

    if (_inited) {
      _log('PUSH already initialized. userId=$userId');
      unawaited(syncAppBadge(userId: userId));
      return;
    }

    _inited = true;
    WidgetsBinding.instance.addObserver(this);

    _log('PUSH INIT START userId=$userId');

    await _initLocalNotifications();
    await _requestPermission();

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

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
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
      await androidPlugin?.createNotificationChannel(callsChannel);
    }
  }

  Future<void> _handleIncomingCall(
    Map<String, dynamic> data, {
    required bool showDialog,
  }) async {
    final callId = int.tryParse((data['call_id'] ?? '').toString()) ?? 0;
    final callerId = int.tryParse((data['caller_id'] ?? '').toString()) ?? 0;

    if (callId <= 0) {
      _log('INCOMING CALL ignored: invalid call_id. data=$data');
      return;
    }

    _log(
      'INCOMING CALL callId=$callId callerId=$callerId userId=$_userId',
    );

    // Не открываем одно и то же окно несколько раз.
    if (_visibleCallId == callId && Get.isDialogOpen == true) {
      _log('INCOMING CALL dialog already visible for callId=$callId');
      return;
    }

    _visibleCallId = callId;

    if (!showDialog || Get.context == null) {
      await _showIncomingCallLocal(data);
      return;
    }

    final callerLabel =
        callerId > 0 ? 'Пользователь #$callerId' : 'Входящий звонок';

    await Get.dialog<void>(
      WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Входящий звонок'),
          content: Text('$callerLabel звонит вам'),
          actions: [
            TextButton(
              onPressed: _callActionInProgress
                  ? null
                  : () async {
                      await _declineIncomingCall(callId);
                    },
              child: const Text('Отклонить'),
            ),
            FilledButton(
              onPressed: _callActionInProgress
                  ? null
                  : () async {
                      await _acceptIncomingCall(
                        callId: callId,
                        callerId: callerId,
                      );
                    },
              child: const Text('Принять'),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );

    if (_visibleCallId == callId) {
      _visibleCallId = null;
    }
  }

  Future<void> _acceptIncomingCall({
    required int callId,
    required int callerId,
  }) async {
    final userId = _userId;
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
        body: {
          'call_id': callId.toString(),
          'user_id': userId.toString(),
        },
      );

      final body = _decodeJson(response.body);

      _log(
        'CALL ACCEPT RESPONSE ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body['status'] == 'ok') {
        if (Get.isDialogOpen == true) {
          Get.back<void>();
        }

        _visibleCallId = null;

        await Get.to<void>(
          () => AudioCallScreen(
            callId: callId,
            userId: userId,
            isCaller: false,
            peerName:
                callerId > 0 ? 'Пользователь #$callerId' : 'Входящий звонок',
          ),
        );

        return;
      }

      final serverStatus = (body['status'] ?? '').toString();
      final error = (body['error'] ?? '').toString();

      if (error == 'not_ringing' && serverStatus == 'accepted') {
        if (Get.isDialogOpen == true) {
          Get.back<void>();
        }

        _visibleCallId = null;
        _showError('Этот звонок уже принят на другом устройстве.');
        return;
      }

      if (Get.isDialogOpen == true) {
        Get.back<void>();
      }

      _visibleCallId = null;
      _showError('Не удалось принять звонок.');
    } catch (e) {
      _log('CALL ACCEPT ERROR: $e');
      _showError('Ошибка соединения при принятии звонка.');
    } finally {
      _callActionInProgress = false;
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
    } catch (e) {
      _log('CALL DECLINE ERROR: $e');
      _showError('Не удалось отклонить звонок.');
    } finally {
      _callActionInProgress = false;
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

    const details = NotificationDetails(
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

    const android = AndroidNotificationDetails(
      _chatChannelId,
      'Chat messages',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const apple = DarwinNotificationDetails(
      presentAlert: true,
      // Badge управляется централизованно через syncAppBadge().
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(
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
