import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// Следит за серверным статусом доступа клуба.
///
/// Если администратор переводит клуб обратно в состояние,
/// где требуется Club Key (`requires_activation = true`),
/// вызывается [onAccessBlocked].
///
/// Legacy-клубы (`legacy = true`) никогда не блокируются этим guard.
class ClubAccessGuard with WidgetsBindingObserver {
  ClubAccessGuard({
    required this.userId,
    required this.email,
    required this.onAccessBlocked,
    this.interval = const Duration(seconds: 20),
  });

  static const String _statusUrl =
      'https://sportotekaapp.ru/api/club_access/status.php';

  final int userId;
  final String email;
  final Duration interval;
  final FutureOr<void> Function() onAccessBlocked;

  Timer? _timer;

  bool _started = false;
  bool _checking = false;
  bool _blocked = false;
  bool _disposed = false;

  /// Запускает проверку сразу и затем по таймеру.
  void start() {
    if (_started || _disposed) return;

    _started = true;

    WidgetsBinding.instance.addObserver(this);

    unawaited(_checkAccess());

    _timer = Timer.periodic(
      interval,
      (_) => unawaited(_checkAccess()),
    );
  }

  /// Можно вызвать вручную, если нужна немедленная проверка.
  Future<void> checkNow() async {
    await _checkAccess();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || _blocked) return;

    // При возврате приложения сразу узнаём,
    // не сбросил ли администратор доступ.
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkAccess());
    }
  }

  Future<void> _checkAccess() async {
    if (_disposed || _blocked || _checking || userId <= 0) {
      return;
    }

    _checking = true;

    try {
      final response = await http
          .post(
            Uri.parse(_statusUrl),
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(
              <String, dynamic>{
                'user_id': userId,
                if (email.trim().isNotEmpty) 'email': email.trim(),
              },
            ),
          )
          .timeout(
            const Duration(seconds: 12),
          );

      if (_disposed || _blocked) return;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Сетевой/серверный сбой не должен выбрасывать клуб из приложения.
        return;
      }

      final Map<String, dynamic>? data = _safeJson(response.body);

      if (data == null) return;

      final status = '${data['status'] ?? ''}'.trim().toLowerCase();

      if (status.isNotEmpty && status != 'success') {
        return;
      }

      final bool legacy = _asBool(
        data['legacy'] ??
            (data['application'] is Map
                ? (data['application'] as Map)['is_legacy']
                : null),
      );

      // Защита существующих клубов.
      if (legacy) {
        return;
      }

      final bool requiresActivation = _asBool(
        data['requires_activation'] ??
            (data['application'] is Map
                ? (data['application'] as Map)['requires_activation']
                : null),
      );

      if (!requiresActivation) {
        return;
      }

      _blocked = true;

      _timer?.cancel();
      _timer = null;

      if (!_disposed) {
        WidgetsBinding.instance.removeObserver(this);
      }

      await Future<void>.sync(() => onAccessBlocked());
    } on TimeoutException {
      // Ничего не делаем: временная сеть не должна блокировать доступ.
    } catch (_) {
      // Любая ошибка проверки считается временной.
      // Блокируем только по явному requires_activation=true от сервера.
    } finally {
      _checking = false;
    }
  }

  Map<String, dynamic>? _safeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return null;
  }

  bool _asBool(dynamic value) {
    if (value == true) return true;
    if (value == false || value == null) return false;

    if (value is num) {
      return value != 0;
    }

    final text = value.toString().trim().toLowerCase();

    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'on';
  }

  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _started = false;

    _timer?.cancel();
    _timer = null;

    WidgetsBinding.instance.removeObserver(this);
  }
}
