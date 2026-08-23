import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _saveTokenUrl = '$_apiBase/save_fcm_token.php';

  bool _inited = false;

  /// Лог только для Debug
  void _log(Object msg) {
    if (kDebugMode) {
      debugPrint(msg.toString());
    }
  }

  Future<void> init({required int userId}) async {
    if (_inited) return;
    _inited = true;

    _log("PUSH INIT START userId=$userId");

    await _initLocalNotifications();
    await _requestPermission();

    // 🔹 iOS: проверяем APNS token
    if (Platform.isIOS) {
      final apns = await _messaging.getAPNSToken();
      _log("APNS TOKEN = $apns");
    }

    // 🔹 Получаем FCM token
    String? token = await _messaging.getToken();

    // iOS иногда отдаёт null с первого раза
    if (token == null && Platform.isIOS) {
      await Future.delayed(const Duration(seconds: 2));
      token = await _messaging.getToken();
    }

    _log("FCM TOKEN = $token");

    if (token != null) {
      await _sendTokenToServer(userId: userId, token: token);
    }

    // 🔹 Обновление токена
    _messaging.onTokenRefresh.listen((newToken) async {
      _log("FCM TOKEN REFRESHED = $newToken");
      await _sendTokenToServer(userId: userId, token: newToken);
    });

    // 🔹 Foreground уведомления
    FirebaseMessaging.onMessage.listen((msg) async {
      await _showLocal(msg);
    });

    // 🔹 Нажатие на уведомление
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _log("Notification opened: ${msg.data}");
    });

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
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
    );

    await _local.initialize(
  settings: init,
);

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'chat_messages',
        'Chat messages',
        description: 'Notifications for chat messages',
        importance: Importance.high,
      );

      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> _showLocal(RemoteMessage msg) async {
    final title = msg.notification?.title ?? 'Сообщение';
    final body = msg.notification?.body ?? '';

    const android = AndroidNotificationDetails(
      'chat_messages',
      'Chat messages',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: android, iOS: ios);

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

  Future<void> _sendTokenToServer({
    required int userId,
    required String token,
  }) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';

      _log("SEND TOKEN -> userId=$userId platform=$platform");

      final res = await http.post(
        Uri.parse(_saveTokenUrl),
        body: {
          'user_id': userId.toString(),
          'token': token,
          'platform': platform,
        },
      );

      _log("SAVE TOKEN RESPONSE: ${res.statusCode}");
    } catch (e) {
      _log("SAVE TOKEN ERROR: $e");
    }
  }
}