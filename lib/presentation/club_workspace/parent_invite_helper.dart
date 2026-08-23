import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';

/// Единый вызов выдачи Parent Key непосредственно из карточки игрока.
///
/// Ключ всегда создаётся для конкретного player_id.
/// Родителю передаётся только одноразовый код; после активации сервер
/// создаёт постоянную связь parent_user_id -> player_id.
class ParentInviteHelper {
  static const String _apiUrl =
      'https://sportotekaapp.ru/api/create_parent_invite.php';

  static int _i(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  static String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  static String playerName(Map<String, dynamic> player) {
    final full = _s(
      player['full_name'] ??
          player['fullName'] ??
          player['name'],
    );
    if (full.isNotEmpty) return full;

    final first = _s(player['first_name'] ?? player['firstName']);
    final last = _s(player['last_name'] ?? player['lastName']);
    final value = '$last $first'.trim();
    return value.isEmpty ? 'Игрок' : value;
  }

  static dynamic _decode(String body) {
    final raw = body.trim();
    if (raw.isEmpty) return null;

    try {
      return jsonDecode(raw);
    } catch (_) {
      final objectStart = raw.indexOf('{');
      final arrayStart = raw.indexOf('[');
      final starts = <int>[
        if (objectStart >= 0) objectStart,
        if (arrayStart >= 0) arrayStart,
      ];
      if (starts.isEmpty) return null;

      starts.sort();
      final start = starts.first;
      final endObject = raw.lastIndexOf('}');
      final endArray = raw.lastIndexOf(']');
      final end = endObject > endArray ? endObject : endArray;
      if (end <= start) return null;

      try {
        return jsonDecode(raw.substring(start, end + 1));
      } catch (_) {
        return null;
      }
    }
  }

  static Future<void> issueForPlayer({
    required BuildContext context,
    required Map<String, dynamic> player,
    int? clubId,
    int? teamId,
  }) async {
    final resolvedPlayerId = _i(
      player['player_id'] ??
          player['playerId'] ??
          player['id'],
    );
    final resolvedTeamId = (teamId ?? 0) > 0
        ? teamId!
        : _i(player['team_id'] ?? player['teamId']);
    final resolvedClubId = (clubId ?? 0) > 0
        ? clubId!
        : _i(player['club_id'] ?? player['clubId']);
    final currentUserId = await PrefUtils.getUserId() ?? 0;

    if (resolvedPlayerId <= 0) {
      Get.snackbar('Ключ родителю', 'Не найден ID выбранного игрока');
      return;
    }
    if (resolvedTeamId <= 0) {
      Get.snackbar('Ключ родителю', 'Не найдена команда выбранного игрока');
      return;
    }
    if (resolvedClubId <= 0) {
      Get.snackbar('Ключ родителю', 'Не найден клуб выбранного игрока');
      return;
    }
    if (currentUserId <= 0) {
      Get.snackbar('Ключ родителю', 'Не найден текущий пользователь');
      return;
    }

    final name = playerName(player);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Color(0xFF00A750)),
            SizedBox(width: 10),
            Expanded(child: Text('Выдать ключ родителю')),
          ],
        ),
        content: Text(
          'Создать одноразовый Parent Key для игрока $name?\n\n'
          'Родитель после ввода ключа получит доступ только к этому ребёнку.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.key_rounded, size: 18),
            label: const Text('Создать ключ'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00A750),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'club_id': resolvedClubId,
              'team_id': resolvedTeamId,
              'player_id': resolvedPlayerId,
              'created_by': currentUserId,
            }),
          )
          .timeout(const Duration(seconds: 18));

      final decoded = _decode(response.body);
      if (decoded is! Map) {
        throw Exception(
          'Некорректный ответ сервера (${response.statusCode}). '
          'Проверьте create_parent_invite.php.',
        );
      }

      final data = Map<String, dynamic>.from(decoded);
      final success =
          data['success'] == true || _s(data['status']).toLowerCase() == 'success';

      if (!success) {
        final message = _s(data['message'] ?? data['error']);
        throw Exception(
          message.isEmpty ? 'Сервер не создал Parent Key' : message,
        );
      }

      final code = _s(
        data['invite_code'] ??
            data['code'] ??
            data['parent_key'],
      );
      final expires = _s(data['expires_at'] ?? data['expires']);

      if (code.isEmpty) {
        throw Exception('Сервер создал приглашение, но не вернул код');
      }

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.key_rounded,
                      color: Color(0xFF00A750),
                      size: 26,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Parent Key создан',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1FBF6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF067A46),
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Передайте этот код родителю. После активации код '
                  'одноразово свяжет аккаунт родителя с этим игроком.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11.8,
                    height: 1.4,
                  ),
                ),
                if (expires.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    'Действует до: $expires',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 10.8,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: code),
                          );
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Ключ скопирован'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Копировать'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00A750),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Готово'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Get.snackbar(
        'Ключ родителю',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
