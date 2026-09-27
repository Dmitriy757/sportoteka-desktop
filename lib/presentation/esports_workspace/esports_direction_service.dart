import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EsportsDirectionState {
  final bool active;
  final bool serverConfirmed;
  final String status;
  final List<String> disciplines;
  final String? message;

  const EsportsDirectionState({
    required this.active,
    required this.serverConfirmed,
    required this.status,
    this.disciplines = const <String>[],
    this.message,
  });

  EsportsDirectionState copyWith({
    bool? active,
    bool? serverConfirmed,
    String? status,
    List<String>? disciplines,
    String? message,
  }) {
    return EsportsDirectionState(
      active: active ?? this.active,
      serverConfirmed: serverConfirmed ?? this.serverConfirmed,
      status: status ?? this.status,
      disciplines: disciplines ?? this.disciplines,
      message: message ?? this.message,
    );
  }
}

class EsportsDirectionService {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String _statusUrl = '$apiBase/esports/directions/status.php';
  static const String _activateUrl = '$apiBase/esports/directions/activate.php';
  static const String _deactivateUrl = '$apiBase/esports/directions/deactivate.php';

  static String _activeKey(int clubId) => 'sportoteka_esports_direction_active_$clubId';
  static String _disciplinesKey(int clubId) => 'sportoteka_esports_direction_disciplines_$clubId';

  static Future<EsportsDirectionState> load({
    required int clubId,
    required int userId,
  }) async {
    if (clubId <= 0) {
      return const EsportsDirectionState(
        active: false,
        serverConfirmed: false,
        status: 'not_configured',
      );
    }

    try {
      final uri = Uri.parse(_statusUrl).replace(
        queryParameters: <String, String>{
          'club_id': '$clubId',
          if (userId > 0) 'user_id': '$userId',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final stateMap = map['direction'] is Map
              ? Map<String, dynamic>.from(map['direction'] as Map)
              : map;
          final active = _asBool(
            stateMap['active'] ??
                stateMap['enabled'] ??
                stateMap['is_active'] ??
                stateMap['has_esports'] ??
                stateMap['esports'],
          ) || _clean(stateMap['status']).toLowerCase() == 'active';
          final disciplines = _asStringList(
            stateMap['disciplines'] ?? stateMap['games'] ?? stateMap['sports'],
          );
          final status = _clean(stateMap['status']).isEmpty
              ? (active ? 'active' : 'inactive')
              : _clean(stateMap['status']).toLowerCase();
          await _cache(clubId, active, disciplines);
          return EsportsDirectionState(
            active: active,
            serverConfirmed: true,
            status: status,
            disciplines: disciplines,
            message: _clean(map['message']).isEmpty ? null : _clean(map['message']),
          );
        }
      }
    } catch (_) {
      // До установки серверных endpoints используем локальный кэш интерфейса.
    }

    return _loadCached(clubId);
  }

  static Future<EsportsDirectionState> activate({
    required int clubId,
    required int userId,
    required List<String> disciplines,
  }) async {
    final cleaned = disciplines
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    try {
      final response = await http
          .post(
            Uri.parse(_activateUrl),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'club_id': clubId,
              if (userId > 0) 'user_id': userId,
              'direction': 'esports',
              'disciplines': cleaned,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final ok = _asBool(map['success']) ||
              _clean(map['status']).toLowerCase() == 'success' ||
              _clean(map['status']).toLowerCase() == 'ok';
          if (ok) {
            await _cache(clubId, true, cleaned);
            return EsportsDirectionState(
              active: true,
              serverConfirmed: true,
              status: 'active',
              disciplines: cleaned,
              message: _clean(map['message']).isEmpty ? null : _clean(map['message']),
            );
          }
        }
      }
    } catch (_) {
      // См. комментарий в load().
    }

    await _cache(clubId, true, cleaned);
    return EsportsDirectionState(
      active: true,
      serverConfirmed: false,
      status: 'active_local',
      disciplines: cleaned,
      message: 'Направление включено в приложении. Серверную синхронизацию можно подключить позже.',
    );
  }

  static Future<EsportsDirectionState> deactivate({
    required int clubId,
    required int userId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_deactivateUrl),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'club_id': clubId,
              if (userId > 0) 'user_id': userId,
              'direction': 'esports',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final ok = _asBool(map['success']) ||
              _clean(map['status']).toLowerCase() == 'success' ||
              _clean(map['status']).toLowerCase() == 'ok';
          if (ok) {
            await _cache(clubId, false, const <String>[]);
            return const EsportsDirectionState(
              active: false,
              serverConfirmed: true,
              status: 'inactive',
            );
          }
        }
      }
    } catch (_) {
      // См. комментарий в load().
    }

    await _cache(clubId, false, const <String>[]);
    return const EsportsDirectionState(
      active: false,
      serverConfirmed: false,
      status: 'inactive_local',
      message: 'Направление отключено в приложении. Серверную синхронизацию можно подключить позже.',
    );
  }

  static Future<EsportsDirectionState> _loadCached(int clubId) async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_activeKey(clubId)) ?? false;
    final disciplines = prefs.getStringList(_disciplinesKey(clubId)) ?? const <String>[];
    return EsportsDirectionState(
      active: active,
      serverConfirmed: false,
      status: active ? 'active_local' : 'not_configured',
      disciplines: disciplines,
    );
  }

  static Future<void> _cache(
    int clubId,
    bool active,
    List<String> disciplines,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey(clubId), active);
    await prefs.setStringList(_disciplinesKey(clubId), disciplines);
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = _clean(value).toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'active' || text == 'enabled';
  }

  static String _clean(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map(_clean)
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}
