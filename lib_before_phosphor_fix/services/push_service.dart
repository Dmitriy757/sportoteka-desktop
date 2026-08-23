// lib/services/push_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // ВАЖНО для бэкграунда
  // обработка data-пейлоада по желанию
}

final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();

Future<void> initPush({
  required int userId,
  required BuildContext context,
  required String appBundleId,
}) async {
  // НЕ вызываем Firebase.initializeApp() здесь — он уже в main()

  FirebaseMessaging.onBackgroundMessage(_bgHandler);

  // iOS разрешения (на Android не мешает)
  await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

  // Получаем токен
  String? fcmToken;
  try {
    fcmToken = await FirebaseMessaging.instance.getToken();
  } catch (e) {
    debugPrint('getToken error: $e');
  }

  // Локальные уведомления (для форграунда)
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await flnp.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));

  final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

  // Регистрируем устройство — не блокируем старт, ловим ошибки
  unawaited(() async {
    try {
      await http.post(
        Uri.parse('https://sportotekaapp.ru/api/register_device.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'platform': platform,
          'token': fcmToken ?? '',
          'app_bundle': appBundleId,
        }),
      );
    } catch (e) {
      debugPrint('register_device error: $e');
    }
  }());

  // Показ уведомлений в форграунде
  FirebaseMessaging.onMessage.listen((m) async {
    final n = m.notification;
    if (n != null) {
      await flnp.show(
        n.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails('chat','Чат', importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
        payload: jsonEncode(m.data),
      );
    }
  });

  // Клик по уведомлению
  FirebaseMessaging.onMessageOpenedApp.listen((m) {
    final data = m.data;
    if (data['type'] == 'chat' && data['chat_id'] != null) {
      // TODO: переход в экран чата, например через Get:
      // Get.to(() => ChatRoomScreen(chatId: int.parse(data['chat_id'])));
    }
  });
}
