import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Thin API bridge for the account-owned Sportoteka OS.
/// Every operation is scoped by user_id; no club_id/team_id fallback is used.
class PersonalWorkspaceOsService {
  const PersonalWorkspaceOsService._();

  static const String base =
      'https://sportotekaapp.ru/api/personal_workspace_os';

  static Map<String, dynamic> _decodeBody(String body) {
    try {
      final raw = body.trim();
      final start = raw.indexOf('{');
      if (start < 0) {
        return <String, dynamic>{
          'success': false,
          'message': 'Некорректный ответ сервера',
        };
      }
      final decoded = jsonDecode(raw.substring(start));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{
      'success': false,
      'message': 'Не удалось разобрать ответ сервера',
    };
  }

  static Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, String> body,
  ) async {
    try {
      final response = await http
          .post(Uri.parse('$base/$endpoint'), body: body)
          .timeout(const Duration(seconds: 25));
      final data = _decodeBody(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{
          ...data,
          'success': false,
          'http_status': response.statusCode,
        };
      }
      return data;
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': 'Ошибка соединения: $e',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> list({
    required int userId,
    required String category,
    int? parentId,
  }) async {
    if (userId <= 0) return <Map<String, dynamic>>[];
    final data = await _post('list.php', <String, String>{
      'user_id': '$userId',
      'category': category,
      if (parentId != null && parentId > 0) 'parent_id': '$parentId',
    });
    if (data['success'] != true || data['items'] is! List) {
      throw StateError('${data['message'] ?? 'Не удалось загрузить Sportoteka OS'}');
    }
    return (data['items'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> listRecursive({
    required int userId,
    required String category,
    String rootTitle = '',
  }) async {
    if (userId <= 0) return <Map<String, dynamic>>[];

    final out = <Map<String, dynamic>>[];
    final queue = <Map<String, dynamic>>[
      <String, dynamic>{'parent_id': null, 'parent_title': rootTitle},
    ];
    final seenFolders = <int>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final parentRaw = current['parent_id'];
      final parentId = parentRaw is int ? parentRaw : int.tryParse('${parentRaw ?? ''}');
      final parentTitle = '${current['parent_title'] ?? ''}'.trim();
      final nodes = await list(
        userId: userId,
        category: category,
        parentId: parentId != null && parentId > 0 ? parentId : null,
      );

      for (final raw in nodes) {
        final node = <String, dynamic>{
          ...raw,
          '_workspace_parent_id': parentId,
          '_workspace_parent_title': parentTitle,
        };
        out.add(node);
        if ('${raw['kind'] ?? ''}' == 'folder') {
          final idRaw = raw['id'];
          final id = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}');
          if (id != null && id > 0 && seenFolders.add(id)) {
            queue.add(<String, dynamic>{
              'parent_id': id,
              'parent_title': '${raw['name'] ?? parentTitle}'.trim(),
            });
          }
        }
      }
    }

    return out;
  }

  static Future<Map<String, dynamic>> saveDocument({
    required int userId,
    required String category,
    required String name,
    required String content,
    int id = 0,
    int? parentId,
  }) async {
    return _post('save_document.php', <String, String>{
      'user_id': '$userId',
      'category': category,
      'name': name,
      'content': content,
      if (id > 0) 'id': '$id',
      if (parentId != null && parentId > 0) 'parent_id': '$parentId',
    });
  }

  static Future<Map<String, dynamic>> createFolder({
    required int userId,
    required String category,
    required String name,
    int? parentId,
  }) {
    return _post('create_folder.php', <String, String>{
      'user_id': '$userId',
      'category': category,
      'name': name,
      if (parentId != null && parentId > 0) 'parent_id': '$parentId',
    });
  }

  static Future<Map<String, dynamic>> rename({
    required int userId,
    required int id,
    required String name,
  }) {
    return _post('rename.php', <String, String>{
      'user_id': '$userId',
      'id': '$id',
      'name': name,
    });
  }

  static Future<Map<String, dynamic>> delete({
    required int userId,
    required int id,
  }) {
    return _post('delete.php', <String, String>{
      'user_id': '$userId',
      'id': '$id',
    });
  }

  static Future<Map<String, dynamic>> uploadFile({
    required int userId,
    required String category,
    required File file,
    int? parentId,
    String? filename,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$base/upload.php'))
        ..fields['user_id'] = '$userId'
        ..fields['category'] = category;
      if (parentId != null && parentId > 0) {
        request.fields['parent_id'] = '$parentId';
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: filename,
        ),
      );
      final response = await request.send().timeout(const Duration(minutes: 3));
      final body = await response.stream.bytesToString();
      final data = _decodeBody(body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{...data, 'success': false};
      }
      return data;
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': 'Ошибка загрузки файла: $e',
      };
    }
  }

  static Map<String, dynamic>? decodeDocumentContent(
    Map<String, dynamic> node,
  ) {
    final raw = '${node['content'] ?? ''}'.trim();
    if (raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (_) {}
    return null;
  }
}
