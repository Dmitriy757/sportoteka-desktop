import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:get/get.dart';

import 'core/app_export.dart';
import 'core/utils/pref_utils.dart';
import 'core/utils/route_observer.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

bool get _isMobileFirebasePlatform {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (_isMobileFirebasePlatform) {
    await Firebase.initializeApp();
    debugPrint("Background message: ${message.messageId}");
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase Messaging оставляем только для Android/iOS.
  // На macOS из-за этого был чёрный экран при запуске.
  if (_isMobileFirebasePlatform) {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );

    final NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('Permission: ${settings.authorizationStatus}');
  }

  await initializeDateFormatting('ru_RU', null);
  await PrefUtils().init();

  final bool isSignedIn = await PrefUtils.getIsSignIn();

  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final logicalSize = view.physicalSize / view.devicePixelRatio;
  final shortestSide = logicalSize.shortestSide;

  final bool isTablet = shortestSide >= 600;

  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    if (isTablet) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  Logger.init(kReleaseMode ? LogMode.live : LogMode.debug);

  runApp(MyApp(
    isSignedIn: isSignedIn,
  ));
}

class MyApp extends StatelessWidget {
  final bool isSignedIn;

  const MyApp({
    super.key,
    required this.isSignedIn,
  });

  @override
  Widget build(BuildContext context) {
    final String initialRoute = isSignedIn
        ? AppRoutes.homeContainerScreen
        : AppRoutes.loginScreen;

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      title: 'sportoteka',
      translations: AppLocalization(),
      locale: Get.deviceLocale,
      fallbackLocale: const Locale('en', 'US'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      navigatorObservers: [routeObserver],
      initialBinding: InitialBindings(),
      initialRoute: initialRoute,
      getPages: AppRoutes.pages,
    );
  }
}