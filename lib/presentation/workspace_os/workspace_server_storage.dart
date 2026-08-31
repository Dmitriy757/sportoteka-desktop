import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';

class WorkspaceServerSnapshot {
  const WorkspaceServerSnapshot({
    required this.nodes,
    required this.noteBodies,
    required this.favorites,
    required this.recent,
  });

  final List<WorkspaceFinderNode> nodes;
  final Map<String, String> noteBodies;
  final Set<String> favorites;
  final List<String> recent;
}

class WorkspaceServerStorage {
  WorkspaceServerStorage({
    required this.clubId,
    this.userId = 0,
    this.apiUrl = 'https://sportotekaapp.ru/api/workspace/index.php',
  });

  final int clubId;
  final int userId;
  final String apiUrl;

  String _preview(String value, {int max = 1200}) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= max) return compact;
    return '${compact.substring(0, max)}…(${compact.length} chars)';
  }

  String _requestMeta(String action, Map<String, dynamic> data) {
    final uid = '${data['client_uid'] ?? data['document_key'] ?? ''}'.trim();
    final title = '${data['title'] ?? ''}'.trim();
    final body = data['body'];
    final blocks = data['blocks_json'];
    return 'action=$action club=$clubId user=$userId'
        '${uid.isEmpty ? '' : ' uid=$uid'}'
        '${title.isEmpty ? '' : ' title=${_preview(title, max: 100)}'}'
        '${body is String ? ' bodyLen=${body.length}' : ''}'
        '${blocks is String ? ' blocksLen=${blocks.length}' : ''}';
  }

  void _log(String message) {
    debugPrint('[WORKSPACE_SYNC][HTTP] $message');
  }

  Uri _uri([Map<String, String>? query]) {
    final base = Uri.parse(apiUrl);
    return base.replace(queryParameters: <String, String>{
      ...base.queryParameters,
      'club_id': '$clubId',
      if (userId > 0) 'user_id': '$userId',
      ...?query,
    });
  }

  Future<Map<String, dynamic>> _get(Map<String, String> query) async {
    final action = query['action'] ?? 'GET';
    final uri = _uri(query);
    _log('GET -> action=$action club=$clubId user=$userId uri=${uri.path}');
    late http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 10));
    } catch (e, st) {
      _log('GET !! action=$action NETWORK_ERROR=$e');
      _log('GET !! stack=${_preview('$st', max: 900)}');
      rethrow;
    }
    _log('GET <- action=$action status=${response.statusCode} response=${_preview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = response.body.trim();
      throw Exception(
        'Workspace API ${response.statusCode}${detail.isEmpty ? '' : ': $detail'}',
      );
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      _log('GET !! action=$action JSON_DECODE_ERROR=$e body=${_preview(response.body)}');
      rethrow;
    }
    if (decoded is! Map) {
      _log('GET !! action=$action INVALID_JSON_TYPE=${decoded.runtimeType}');
      throw Exception('Некорректный ответ Workspace API');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['success'] != true) {
      _log('GET !! action=$action API_ERROR=${data['message'] ?? data['error']} debug_id=${data['debug_id'] ?? ''}');
      throw Exception('${data['message'] ?? data['error'] ?? 'Workspace API error'}');
    }
    return data;
  }

  Future<Map<String, dynamic>> _post(String action, Map<String, dynamic> data) async {
    final meta = _requestMeta(action, data);
    final uri = _uri();
    _log('POST -> $meta uri=${uri.path}');
    late http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(<String, dynamic>{
              'action': action,
              'club_id': clubId,
              if (userId > 0) 'user_id': userId,
              ...data,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e, st) {
      _log('POST !! $meta NETWORK_ERROR=$e');
      _log('POST !! stack=${_preview('$st', max: 900)}');
      rethrow;
    }
    _log('POST <- $meta status=${response.statusCode} response=${_preview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = response.body.trim();
      throw Exception(
        'Workspace API ${response.statusCode}${detail.isEmpty ? '' : ': $detail'}',
      );
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      _log('POST !! $meta JSON_DECODE_ERROR=$e body=${_preview(response.body)}');
      rethrow;
    }
    if (decoded is! Map) {
      _log('POST !! $meta INVALID_JSON_TYPE=${decoded.runtimeType}');
      throw Exception('Некорректный ответ Workspace API');
    }
    final result = Map<String, dynamic>.from(decoded);
    if (result['success'] != true) {
      _log('POST !! $meta API_ERROR=${result['message'] ?? result['error']} debug_id=${result['debug_id'] ?? ''}');
      throw Exception('${result['message'] ?? result['error'] ?? 'Workspace API error'}');
    }
    _log('POST OK $meta debug_id=${result['debug_id'] ?? ''}');
    return result;
  }

  Future<WorkspaceServerSnapshot> load() async {
    final data = await _get(const <String, String>{'action': 'bootstrap'});
    final nodesRaw = data['nodes'];
    final nodes = <WorkspaceFinderNode>[];
    if (nodesRaw is List) {
      for (final item in nodesRaw.whereType<Map>()) {
        final node = _nodeFromServer(Map<String, dynamic>.from(item));
        if (node != null) nodes.add(node);
      }
    }

    final notes = <String, String>{};
    final notesRaw = data['documents'];
    if (notesRaw is Map) {
      for (final entry in notesRaw.entries) {
        notes['${entry.key}'] = '${entry.value ?? ''}';
      }
    }

    final favorites = <String>{};
    final recent = <String>[];
    final stateRaw = data['state'];
    if (stateRaw is Map) {
      final fav = stateRaw['favorites'];
      final rec = stateRaw['recent'];
      if (fav is List) favorites.addAll(fav.map((e) => '$e'));
      if (rec is List) recent.addAll(rec.map((e) => '$e'));
    }

    return WorkspaceServerSnapshot(
      nodes: nodes,
      noteBodies: notes,
      favorites: favorites,
      recent: recent,
    );
  }

  WorkspaceFinderNode? _nodeFromServer(Map<String, dynamic> json) {
    final id = '${json['client_uid'] ?? json['id'] ?? ''}'.trim();
    final title = '${json['title'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty) return null;
    final kindName = '${json['kind'] ?? 'folder'}'.trim();
    final kind = WorkspaceFinderNodeKind.values.firstWhere(
      (e) => e.name == kindName,
      orElse: () => WorkspaceFinderNodeKind.folder,
    );
    Map<String, dynamic>? payload;
    final rawPayload = json['payload'];
    if (rawPayload is Map) {
      payload = Map<String, dynamic>.from(rawPayload);
    } else if (rawPayload is String && rawPayload.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(rawPayload);
        if (parsed is Map) payload = Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }
    payload = <String, dynamic>{
      ...?payload,
      '_workspace_server_id': json['server_id'] ?? json['id'],
      '_workspace_server': true,
    };
    return WorkspaceFinderNode(
      id: id,
      title: title,
      subtitle: '${json['subtitle'] ?? ''}',
      kind: kind,
      moduleKey: json['module_key'] == null ? null : '${json['module_key']}',
      payload: payload,
      parentId: json['parent_key'] == null ? null : '${json['parent_key']}',
      isSystem: false,
      isShortcut: json['is_shortcut'] == true || '${json['is_shortcut']}' == '1',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'.replaceFirst(' ', 'T')),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'.replaceFirst(' ', 'T')),
    );
  }

  Map<String, dynamic>? _cleanPayload(WorkspaceFinderNode node) {
    final raw = node.payload;
    if (raw == null) return null;
    final clean = <String, dynamic>{...raw};
    clean.remove('_workspace_server_id');
    clean.remove('_workspace_server');
    return clean;
  }

  Map<String, dynamic> _nodePayload(WorkspaceFinderNode node) => <String, dynamic>{
        'client_uid': node.id,
        'parent_key': node.parentId ?? 'home',
        'kind': node.kind.name,
        'title': node.title,
        'subtitle': node.subtitle,
        'module_key': node.moduleKey,
        'payload': _cleanPayload(node),
        'is_shortcut': node.isShortcut,
      };

  Future<void> createNode(WorkspaceFinderNode node) async {
    await _post('create_node', _nodePayload(node));
  }

  Future<void> updateNode(WorkspaceFinderNode node) async {
    await _post('update_node', _nodePayload(node));
  }

  Future<void> deleteNode(String clientUid) async {
    await _post('delete_node', <String, dynamic>{'client_uid': clientUid});
  }

  Future<void> moveNode(String clientUid, String parentKey) async {
    await _post('move_node', <String, dynamic>{
      'client_uid': clientUid,
      'parent_key': parentKey,
    });
  }

  Future<void> saveDocument({
    required String clientUid,
    required String title,
    required String body,
    String format = 'sportoteka-richtext-v1',
  }) async {
    await _post('save_document', <String, dynamic>{
      'client_uid': clientUid,
      'title': title,
      'body': body,
      'format': format,
    });
  }

  /// Loads one document directly from the server. This is used immediately
  /// before opening the editor so another device's latest saved copy is not
  /// hidden behind an old SharedPreferences cache.
  Future<Map<String, dynamic>?> loadDocument({required String clientUid}) async {
    final data = await _get(<String, String>{
      'action': 'load_document',
      'client_uid': clientUid,
    });
    final raw = data['document'];
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }


  /// Saves a node and its document body as one logical sync operation.
  ///
  /// The second create/update attempt is intentional: it makes retries safe
  /// after a partial request (for example, the node was created but the body
  /// upload failed). The final error is propagated so the editor can show that
  /// the document is cached locally but has not reached the server yet.
  Future<void> syncNodeDocument({
    required WorkspaceFinderNode node,
    required String body,
    bool createHint = false,
  }) async {
    _log('SYNC BEGIN uid=${node.id} title=${_preview(node.title, max: 100)} bodyLen=${body.length} createHint=$createHint club=$clubId user=$userId');
    if (createHint) {
      try {
        await createNode(node);
        _log('SYNC NODE create OK uid=${node.id}');
      } catch (e) {
        _log('SYNC NODE create FAILED uid=${node.id} error=$e -> trying update');
        await updateNode(node);
        _log('SYNC NODE update-after-create-fail OK uid=${node.id}');
      }
    } else {
      try {
        await updateNode(node);
        _log('SYNC NODE update OK uid=${node.id}');
      } catch (e) {
        _log('SYNC NODE update FAILED uid=${node.id} error=$e -> trying create');
        await createNode(node);
        _log('SYNC NODE create-after-update-fail OK uid=${node.id}');
      }
    }
    try {
      await saveDocument(clientUid: node.id, title: node.title, body: body);
      _log('SYNC DOCUMENT OK uid=${node.id} bodyLen=${body.length}');
    } catch (e) {
      _log('SYNC DOCUMENT FAILED uid=${node.id} bodyLen=${body.length} error=$e');
      rethrow;
    }
    _log('SYNC END uid=${node.id} SUCCESS');
  }

  Future<void> saveState({
    required Iterable<String> favorites,
    required Iterable<String> recent,
  }) async {
    await _post('save_state', <String, dynamic>{
      'state': <String, dynamic>{
        'favorites': favorites.toList(),
        'recent': recent.toList(),
      },
    });
  }

  Future<void> migrateLocal({
    required Iterable<WorkspaceFinderNode> nodes,
    required Map<String, String> noteBodies,
  }) async {
    for (final node in nodes) {
      await createNode(node);
      if (node.kind == WorkspaceFinderNodeKind.note) {
        await saveDocument(
          clientUid: node.id,
          title: node.title,
          body: noteBodies[node.id] ?? '',
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> listAttachments({
    required String entityType,
    required int entityId,
    String sectionKey = 'documents',
  }) async {
    final data = await _get(<String, String>{
      'action': 'list_attachments',
      'entity_type': entityType,
      'entity_id': '$entityId',
      'section_key': sectionKey,
    });
    final raw = data['attachments'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> uploadAttachment({
    required String filePath,
    required String entityType,
    required int entityId,
    String sectionKey = 'documents',
    String title = '',
  }) async {
    _log('UPLOAD -> action=upload_attachment club=$clubId user=$userId entity=$entityType:$entityId section=$sectionKey file=$filePath');
    final request = http.MultipartRequest('POST', _uri());
    request.fields['action'] = 'upload_attachment';
    request.fields['club_id'] = '$clubId';
    if (userId > 0) request.fields['user_id'] = '$userId';
    request.fields['entity_type'] = entityType;
    request.fields['entity_id'] = '$entityId';
    request.fields['section_key'] = sectionKey;
    request.fields['title'] = title;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    late http.Response response;
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      response = await http.Response.fromStream(streamed);
    } catch (e, st) {
      _log('UPLOAD !! entity=$entityType:$entityId NETWORK_ERROR=$e');
      _log('UPLOAD !! stack=${_preview('$st', max: 900)}');
      rethrow;
    }
    _log('UPLOAD <- entity=$entityType:$entityId status=${response.statusCode} response=${_preview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = response.body.trim();
      throw Exception('Workspace upload ${response.statusCode}${detail.isEmpty ? '' : ': $detail'}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw Exception('Некорректный ответ Workspace upload');
    final result = Map<String, dynamic>.from(decoded);
    if (result['success'] != true) throw Exception('${result['message'] ?? result['error'] ?? 'Upload error'}');
    final attachment = result['attachment'];
    _log('UPLOAD OK entity=$entityType:$entityId attachmentId=${attachment is Map ? attachment['id'] : ''} debug_id=${result['debug_id'] ?? ''}');
    return attachment is Map ? Map<String, dynamic>.from(attachment) : <String, dynamic>{};
  }

  Future<void> deleteAttachment(int attachmentId) async {
    await _post('delete_attachment', <String, dynamic>{'attachment_id': attachmentId});
  }


  Future<String> loadLiveBlocks(String documentKey) async {
    final data = await _get(<String, String>{
      'action': 'load_live_blocks',
      'document_key': documentKey,
    });
    return '${data['blocks_json'] ?? '[]'}';
  }

  Future<void> saveLiveBlocks({
    required String documentKey,
    required String blocksJson,
  }) async {
    await _post('save_live_blocks', <String, dynamic>{
      'document_key': documentKey,
      'blocks_json': blocksJson,
    });
  }

  Future<void> linkDocument({
    required String documentKey,
    required String entityType,
    required String entityId,
    String sectionKey = '',
    String title = '',
  }) async {
    if (documentKey.trim().isEmpty || entityType.trim().isEmpty || entityId.trim().isEmpty) return;
    await _post('link_document', <String, dynamic>{
      'document_key': documentKey.trim(),
      'entity_type': entityType.trim(),
      'entity_id': entityId.trim(),
      'section_key': sectionKey.trim(),
      'title': title.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> listEntityDocuments({
    required String entityType,
    required String entityId,
    String sectionKey = '',
  }) async {
    if (entityType.trim().isEmpty || entityId.trim().isEmpty) return <Map<String, dynamic>>[];
    final data = await _get(<String, String>{
      'action': 'list_entity_documents',
      'entity_type': entityType.trim(),
      'entity_id': entityId.trim(),
      if (sectionKey.trim().isNotEmpty) 'section_key': sectionKey.trim(),
    });
    final raw = data['documents'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

}
