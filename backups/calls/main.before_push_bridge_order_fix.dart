import 'dart:io';
import 'dart:io' show Platform;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:sportoteka/call/ios_native_call_bridge.dart';
import 'package:flutter/services.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:get/get.dart';

import 'core/app_export.dart';
import 'core/utils/pref_utils.dart';
import 'core/utils/route_observer.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:sportoteka/core/push/push_service.dart';
bool get _isMobileFirebasePlatform {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS CallKit owns AVAudioSession activation/deactivation.
  // LiveKit only uses the audio engine inside CallKit's active window.
  if (Platform.isIOS) {
    await lk.AudioManager.instance.setAudioSessionManagementMode(
      lk.AudioSessionManagementMode.externalCallSystem,
    );
  }

  // Регистрируем native CallKit -> Dart bridge максимально рано.
  // Он запускает LiveKit даже когда экран iPhone остаётся заблокирован.
  await IosNativeCallBridge.install();

  // Firebase Messaging оставляем только для Android/iOS.
  // На macOS из-за этого был чёрный экран при запуске.
  if (_isMobileFirebasePlatform) {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(
      sportotekaFirebaseMessagingBackgroundHandler,
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

  // SPORTOTEKA_CALLKIT_COLD_START_INIT
  // Login screens initialize PushService after a new sign-in.
  // This also covers a saved session that bypasses the login screen.
  if (_isMobileFirebasePlatform) {
    final sportotekaPushUserId = await PrefUtils.getUserId() ?? 0;

    if (sportotekaPushUserId > 0) {
      unawaited(
        PushService.instance.init(userId: sportotekaPushUserId),
      );
    }
  }

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