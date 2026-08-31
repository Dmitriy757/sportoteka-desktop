import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// Проверяет доступ уже открытой club-сессии.
///
/// Сервер после admin action `reset_access` сразу возвращает
/// requires_activation=true. Этот guard позволяет приложению обнаружить
/// блокировку не только при следующем логине, но и при resume / периодической
/// проверке.
///
/// Навигацию и очистку локальной сессии передаём callback-ом, чтобы сервис не
/// зависел от конкретного экрана/маршрута приложения.
class ClubAccessGuard with WidgetsBindingObserver {
  ClubAccessGuard({
    required this.userId,
    required this.email,
    required this.onAccessBlocked,
    this.interval = const Duration(minutes: 1),
  });

  final int userId;
  final String email;
  final Future<void> Function() onAccessBlocked;
  final Duration interval;

  static const _url =
      'https://sportotekaapp.ru/api/club_access/status.php';

  Timer? _timer;
  bool _checking = false;
  bool _blockedHandled = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => checkNow());
    unawaited(checkNow());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkNow());
    }
  }

  Future<void> checkNow() async {
    if (_checking || _blockedHandled || userId <= 0) return;
    _checking = true;
    try {
      final response = await http
          .post(
            Uri.parse(_url),
            headers: const {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'user_id': userId, 'email': email}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return;
      final raw = jsonDecode(response.body);
      if (raw is! Map) return;

      final legacy = raw['legacy'] == true;
      final requiresActivation = raw['requires_activation'] == true;

      if (!legacy && requiresActivation) {
        _blockedHandled = true;
        await onAccessBlocked();
      }
    } catch (_) {
      // При временной сетевой ошибке не разлогиниваем пользователя.
    } finally {
      _checking = false;
    }
  }
}
