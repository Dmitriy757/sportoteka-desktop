import 'dart:convert';

import 'package:http/http.dart' as http;

class AiWorkspaceAction {
  const AiWorkspaceAction({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    required this.requiresConfirmation,
    required this.payload,
    required this.result,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final String status;
  final bool requiresConfirmation;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> result;

  String get actionToken => '${payload['action_token'] ?? ''}'.trim();

  bool get canConfirm =>
      requiresConfirmation && status == 'pending' && actionToken.length >= 32;

  factory AiWorkspaceAction.fromMap(Map<String, dynamic> map) {
    return AiWorkspaceAction(
      id: '${map['id'] ?? ''}',
      type: '${map['type'] ?? ''}',
      title: '${map['title'] ?? ''}',
      description: '${map['description'] ?? ''}',
      status: '${map['status'] ?? 'pending'}',
      requiresConfirmation: map['requires_confirmation'] == true,
      payload: map['payload'] is Map
          ? Map<String, dynamic>.from(map['payload'] as Map)
          : const <String, dynamic>{},
      result: map['result'] is Map
          ? Map<String, dynamic>.from(map['result'] as Map)
          : const <String, dynamic>{},
    );
  }
}

/// Безопасный клиент Action Bridge v15.9.1.
///
/// Метод принимает только одноразовый токен, выданный серверным предпросмотром.
/// Параметра confirmed со значением по умолчанию здесь намеренно нет: запись
/// возможна только после отдельного явного действия пользователя в UI.
class AiWorkspaceActionApi {
  static const String confirmUrl =
      'https://sportotekaapp.ru/api/ai/v1/assistant/universal-action/confirm';

  static Future<Map<String, dynamic>> confirm({
    required int clubId,
    required int userId,
    required int teamId,
    required String actionToken,
  }) async {
    final token = actionToken.trim();
    if (clubId <= 0 || userId <= 0 || teamId <= 0) {
      throw ArgumentError('Не указан контекст клуба, пользователя или команды');
    }
    if (token.length < 32) {
      throw ArgumentError('Некорректный одноразовый токен действия');
    }

    final response = await http
        .post(
          Uri.parse(confirmUrl),
          headers: const <String, String>{
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'club_id': clubId,
            'user_id': userId,
            'team_id': teamId,
            'action_token': token,
            'confirmed': true,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final decoded = _decode(response.body);
    if (response.statusCode != 200 || decoded is! Map) {
      throw Exception('Action HTTP ${response.statusCode}: ${response.body}');
    }

    final result = Map<String, dynamic>.from(decoded);
    if (result['success'] != true || result['action_status'] != 'completed') {
      throw Exception(
        '${result['answer'] ?? result['message'] ?? result['error_code'] ?? 'Действие не выполнено'}',
      );
    }
    return result;
  }

  static dynamic _decode(String body) {
    var text = body.trimLeft();
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    final objectStart = text.indexOf('{');
    if (objectStart > 0) text = text.substring(objectStart);
    return jsonDecode(text);
  }
}
