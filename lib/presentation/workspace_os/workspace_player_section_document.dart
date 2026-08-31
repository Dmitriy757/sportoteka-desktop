import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_document_editor.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_entity_identity.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_player_data_bridge.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_server_storage.dart';
import 'package:url_launcher/url_launcher.dart';

enum WorkspacePlayerSection {
  card,
  diary,
  readiness,
  activity,
  matches,
  testing,
  health,
  documents,
}

class WorkspacePlayerSectionDocument extends StatefulWidget {
  const WorkspacePlayerSectionDocument({
    super.key,
    required this.player,
    required this.clubId,
    required this.section,
    this.teamId,
    this.teamName = '',
    this.record,
    this.recordTitle,
    this.onRefresh,
    this.currentUserId = 0,
  });

  final Map<String, dynamic> player;
  final int clubId;
  final int? teamId;
  final String teamName;
  final WorkspacePlayerSection section;
  final Map<String, dynamic>? record;
  final String? recordTitle;
  final Future<void> Function()? onRefresh;
  final int currentUserId;

  @override
  State<WorkspacePlayerSectionDocument> createState() =>
      _WorkspacePlayerSectionDocumentState();
}

class _WorkspacePlayerSectionDocumentState
    extends State<WorkspacePlayerSectionDocument> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);

  final WorkspacePlayerDataBridge _bridge = WorkspacePlayerDataBridge();
  WorkspaceServerStorage? _serverStorage;
  bool _serverAvailable = false;
  bool _loading = false;
  bool _uploading = false;
  bool _savingServerRecord = false;
  bool _draggingFile = false;
  bool _recordDetailsOpen = false;
  String? _error;
  List<Map<String, dynamic>> _medicalRecords = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _diary = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _recordAttachments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _recordDocuments = <Map<String, dynamic>>[];
  String _workspaceNote = '';

  String get _playerName {
    final last = '${widget.player['last_name'] ?? widget.player['lastname'] ?? ''}'.trim();
    final first = '${widget.player['first_name'] ?? widget.player['firstname'] ?? ''}'.trim();
    final full = '${widget.player['full_name'] ?? widget.player['fullName'] ?? widget.player['name'] ?? ''}'.trim();
    final joined = <String>[last, first].where((e) => e.isNotEmpty).join(' ').trim();
    return joined.isNotEmpty ? joined : (full.isNotEmpty ? full : 'Игрок');
  }

  String get _sectionTitle {
    switch (widget.section) {
      case WorkspacePlayerSection.card:
        return 'Карточка игрока';
      case WorkspacePlayerSection.diary:
        return 'Дневник';
      case WorkspacePlayerSection.readiness:
        return 'Готовность';
      case WorkspacePlayerSection.activity:
        return 'Активность';
      case WorkspacePlayerSection.matches:
        return 'Матчи';
      case WorkspacePlayerSection.testing:
        return 'Тестирование';
      case WorkspacePlayerSection.health:
        return 'Здоровье';
      case WorkspacePlayerSection.documents:
        return 'Документы';
    }
  }

  String get _effectiveRecordTitle {
    final record = widget.record;
    if (record == null) return _sectionTitle;
    switch (widget.section) {
      case WorkspacePlayerSection.matches:
        final opponent = '${record['opponent'] ?? record['opponent_name'] ?? record['opponent_team'] ?? record['opponent_team_name'] ?? record['rival'] ?? record['rival_name'] ?? ''}'.trim();
        if (opponent.isNotEmpty) return 'Матч — $opponent';
        break;
      case WorkspacePlayerSection.health:
      case WorkspacePlayerSection.documents:
        final title = '${record['title'] ?? record['name'] ?? ''}'.trim();
        if (title.isNotEmpty) return title;
        break;
      case WorkspacePlayerSection.activity:
        final title = '${record['title'] ?? record['training_title'] ?? record['event_title'] ?? record['name'] ?? ''}'.trim();
        if (title.isNotEmpty) return title;
        break;
      case WorkspacePlayerSection.diary:
      case WorkspacePlayerSection.readiness:
        final title = '${record['title'] ?? record['training_title'] ?? record['event_title'] ?? ''}'.trim();
        if (title.isNotEmpty) return title;
        break;
      case WorkspacePlayerSection.testing:
        final title = '${record['title'] ?? record['name'] ?? record['session_name'] ?? ''}'.trim();
        if (title.isNotEmpty) return title;
        break;
      case WorkspacePlayerSection.card:
        break;
    }
    return widget.recordTitle?.trim().isNotEmpty == true ? widget.recordTitle!.trim() : _sectionTitle;
  }

  String get _legacyNoteStorageKey {
    final playerId = _bridge.resolvePlayerId(widget.player);
    final record = widget.record;
    String recordKey = 'folder';
    if (record != null) {
      for (final key in const <String>[
        'id', 'match_id', 'event_id', 'session_id', 'test_id',
        'record_id', 'date', 'test_date', 'match_date', 'created_at',
      ]) {
        final value = '${record[key] ?? ''}'.trim();
        if (value.isNotEmpty && value != 'null') {
          recordKey = '$key:$value';
          break;
        }
      }
      if (recordKey == 'folder') {
        recordKey = widget.recordTitle?.trim().isNotEmpty == true
            ? widget.recordTitle!.trim()
            : 'record';
      }
    }
    final safe = recordKey.replaceAll(RegExp(r'[^a-zA-Z0-9_:-]+'), '_');
    return 'sportoteka_player_doc_v2_${widget.clubId}_${playerId}_${widget.section.name}_$safe';
  }

  WorkspaceEntityIdentity? get _recordIdentity {
    final record = widget.record;
    if (record == null) return null;
    final playerId = _bridge.resolvePlayerId(widget.player);
    return WorkspaceEntityIdentity.resolve(
      clubId: widget.clubId,
      record: record,
      sectionHint: widget.section.name,
      fallbackType: 'player_${widget.section.name}',
      fallbackId: '${playerId}_${_legacyNoteStorageKey.hashCode.abs()}',
    );
  }

  String get _noteStorageKey => _recordIdentity?.key ?? _legacyNoteStorageKey;
  String get _notePendingStorageKey => '${_noteStorageKey}_workspace_sync_pending_v1';

  String get _serverParentKey {
    final identity = _recordIdentity;
    if (identity != null) return 'entity:${identity.type}:${identity.id}';
    return 'player:${_bridge.resolvePlayerId(widget.player)}:${widget.section.name}:documents';
  }

  bool get _canUseRecordAttachments =>
      widget.record != null && _bridge.resolvePlayerId(widget.player) > 0;

  String get _recordAttachmentSectionKey {
    final identity = _recordIdentity;
    if (identity != null) {
      return '${widget.section.name}:${identity.type}:${identity.id}';
    }
    final safe = _noteStorageKey.replaceAll(RegExp(r'[^a-zA-Z0-9_:-]+'), '_');
    return '${widget.section.name}:record:$safe';
  }

  String get _recordDocumentsStorageKey => '${_noteStorageKey}_children';

  @override
  void initState() {
    super.initState();
    _serverStorage = WorkspaceServerStorage(
      clubId: widget.clubId,
      userId: widget.currentUserId,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      var note = prefs.getString(_noteStorageKey) ?? '';
      if (note.isEmpty && _legacyNoteStorageKey != _noteStorageKey) {
        note = prefs.getString(_legacyNoteStorageKey) ?? '';
      }
      final notePendingSync = prefs.getBool(_notePendingStorageKey) ?? false;
      var recordAttachments = <Map<String, dynamic>>[];
      var recordDocuments = <Map<String, dynamic>>[];
      if (widget.record != null) {
        final rawChildren = prefs.getString(_recordDocumentsStorageKey);
        if (rawChildren != null && rawChildren.trim().isNotEmpty) {
          try {
            final decodedChildren = jsonDecode(rawChildren);
            if (decodedChildren is List) {
              recordDocuments = decodedChildren
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList();
            }
          } catch (_) {}
        }
      }
      final server = _serverStorage;
      if (server != null) {
        try {
          if (notePendingSync) {
            final pendingNode = WorkspaceFinderNode(
              id: _noteStorageKey,
              title: _effectiveRecordTitle,
              subtitle: 'Рабочий документ игрока',
              kind: WorkspaceFinderNodeKind.note,
              parentId: _serverParentKey,
              updatedAt: DateTime.now(),
            );
            await server.syncNodeDocument(node: pendingNode, body: note);
            final pendingIdentity = _recordIdentity;
            if (pendingIdentity != null) {
              await server.linkDocument(
                documentKey: _noteStorageKey,
                entityType: pendingIdentity.type,
                entityId: pendingIdentity.id,
                sectionKey: widget.section.name,
                title: _effectiveRecordTitle,
              );
            }
            await prefs.setBool(_notePendingStorageKey, false);
          }
          var snapshot = await server.load();
          final canonicalServerBody = snapshot.noteBodies[_noteStorageKey];
          if (canonicalServerBody != null && canonicalServerBody.isNotEmpty) {
            note = canonicalServerBody;
          } else if (note.isEmpty && _legacyNoteStorageKey != _noteStorageKey) {
            final legacyServerBody = snapshot.noteBodies[_legacyNoteStorageKey];
            if (legacyServerBody != null && legacyServerBody.isNotEmpty) note = legacyServerBody;
          }
          final hasNode = snapshot.nodes.any((node) => node.id == _noteStorageKey);
          if (!hasNode && note.isNotEmpty) {
            final node = WorkspaceFinderNode(
              id: _noteStorageKey,
              title: _effectiveRecordTitle,
              subtitle: 'Рабочий документ игрока',
              kind: WorkspaceFinderNodeKind.note,
              parentId: _serverParentKey,
              createdAt: DateTime.now(),
            );
            await server.syncNodeDocument(node: node, body: note, createHint: true);
            snapshot = await server.load();
          }
          final serverBody = snapshot.noteBodies[_noteStorageKey];
          if (serverBody != null) note = serverBody;
          final identity = _recordIdentity;
          if (identity != null) {
            await server.linkDocument(
              documentKey: _noteStorageKey,
              entityType: identity.type,
              entityId: identity.id,
              sectionKey: widget.section.name,
              title: _effectiveRecordTitle,
            );
          }
          if (widget.record != null) {
            var syncedPendingChild = false;
            for (var i = 0; i < recordDocuments.length; i++) {
              final document = recordDocuments[i];
              if (document['_workspace_pending_sync'] != true) continue;
              final childId = '${document['id'] ?? ''}'.trim();
              if (childId.isEmpty) continue;
              final childTitle = '${document['title'] ?? 'Документ'}'.trim();
              final childNode = WorkspaceFinderNode(
                id: childId,
                title: childTitle.isEmpty ? 'Документ' : childTitle,
                subtitle: 'Материал · $_effectiveRecordTitle',
                kind: WorkspaceFinderNodeKind.note,
                parentId: _serverParentKey,
                createdAt: DateTime.tryParse('${document['created_at'] ?? ''}'),
                updatedAt: DateTime.tryParse('${document['updated_at'] ?? ''}') ?? DateTime.now(),
              );
              await server.syncNodeDocument(
                node: childNode,
                body: '${document['body'] ?? ''}',
              );
              final childIdentity = _recordIdentity;
              if (childIdentity != null) {
                await server.linkDocument(
                  documentKey: childId,
                  entityType: childIdentity.type,
                  entityId: childIdentity.id,
                  sectionKey: widget.section.name,
                  title: childNode.title,
                );
              }
              recordDocuments[i] = <String, dynamic>{
                ...document,
                '_workspace_server': true,
                '_workspace_pending_sync': false,
              };
              syncedPendingChild = true;
            }
            if (syncedPendingChild) {
              await prefs.setString(_recordDocumentsStorageKey, jsonEncode(recordDocuments));
              snapshot = await server.load();
            }
            final mergedDocuments = <String, Map<String, dynamic>>{
              for (final row in recordDocuments)
                if ('${row['id'] ?? ''}'.trim().isNotEmpty)
                  '${row['id']}': Map<String, dynamic>.from(row),
            };
            for (final node in snapshot.nodes.where(
              (node) =>
                  node.parentId == _serverParentKey &&
                  node.kind == WorkspaceFinderNodeKind.note &&
                  node.id != _noteStorageKey,
            )) {
              final localChild = mergedDocuments[node.id];
              if (localChild?['_workspace_pending_sync'] == true) continue;
              mergedDocuments[node.id] = <String, dynamic>{
                'id': node.id,
                'title': node.title,
                'body': snapshot.noteBodies[node.id] ?? '',
                'created_at': node.createdAt?.toIso8601String() ?? '',
                'updated_at': node.updatedAt?.toIso8601String() ?? '',
                '_workspace_record_document': true,
              };
            }
            recordDocuments = mergedDocuments.values.toList()
              ..sort((a, b) => '${b['updated_at'] ?? ''}'.compareTo('${a['updated_at'] ?? ''}'));
            await prefs.setString(_recordDocumentsStorageKey, jsonEncode(recordDocuments));
          }
          if (_canUseRecordAttachments) {
            try {
              recordAttachments = await server.listAttachments(
                entityType: 'player',
                entityId: _bridge.resolvePlayerId(widget.player),
                sectionKey: _recordAttachmentSectionKey,
              );
            } catch (_) {
              recordAttachments = <Map<String, dynamic>>[];
            }
          }
          _serverAvailable = true;
        } catch (_) {
          _serverAvailable = false;
        }
      }
      List<Map<String, dynamic>> medical = const <Map<String, dynamic>>[];
      List<Map<String, dynamic>> diary = const <Map<String, dynamic>>[];
      if (widget.record == null) {
        if (widget.section == WorkspacePlayerSection.health ||
            widget.section == WorkspacePlayerSection.documents) {
          medical = await _bridge.loadMedicalRecords(widget.player);
        }
        if (widget.section == WorkspacePlayerSection.diary) {
          diary = await _bridge.loadDiary(
            player: widget.player,
            teamId: widget.teamId,
            clubId: widget.clubId,
          );
        }
      }
      if (note.isNotEmpty && _legacyNoteStorageKey != _noteStorageKey) {
        await prefs.setString(_noteStorageKey, note);
      }
      if (!mounted) return;
      setState(() {
        _workspaceNote = note;
        _medicalRecords = medical;
        _diary = diary;
        _recordAttachments = recordAttachments;
        _recordDocuments = recordDocuments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _saveWorkspaceNote(String title, String body) async {
    // Root Diary is not a separate Workspace-only document anymore. Its body
    // is also persisted as a real player_diary_entries row so the ordinary
    // player profile and Finder work with the same sporting record.
    if (widget.section == WorkspacePlayerSection.diary &&
        widget.record == null &&
        body.trim().isNotEmpty) {
      await _bridge.saveDiaryNote(
        player: widget.player,
        clubId: widget.clubId,
        teamId: widget.teamId,
        note: body,
      );
      _diary = await _bridge.loadDiary(
        player: widget.player,
        teamId: widget.teamId,
        clubId: widget.clubId,
      );
      await widget.onRefresh?.call();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_noteStorageKey, body);
    await prefs.setBool(_notePendingStorageKey, true);
    final server = _serverStorage;
    if (server != null) {
      try {
        final node = WorkspaceFinderNode(
          id: _noteStorageKey,
          title: title.trim().isEmpty ? _effectiveRecordTitle : title.trim(),
          subtitle: 'Рабочий документ игрока',
          kind: WorkspaceFinderNodeKind.note,
          parentId: _serverParentKey,
          updatedAt: DateTime.now(),
        );
        await server.syncNodeDocument(node: node, body: body);
        _serverAvailable = true;
        final identity = _recordIdentity;
        if (identity != null) {
          await server.linkDocument(
            documentKey: _noteStorageKey,
            entityType: identity.type,
            entityId: identity.id,
            sectionKey: widget.section.name,
            title: node.title,
          );
        }
        await prefs.setBool(_notePendingStorageKey, false);
      } catch (e) {
        _serverAvailable = false;
        if (mounted) setState(() => _workspaceNote = body);
        throw Exception('Документ сохранён локально, но серверная синхронизация не выполнена: $e');
      }
    }
    if (mounted) setState(() => _workspaceNote = body);
  }

  Future<void> _refreshAll() async {
    await _load();
    await widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DocumentHeader(
          title: '$_playerName — $_effectiveRecordTitle',
          subtitle: _headerSubtitle,
          onBack: () => Navigator.of(context).maybePop(),
          onRefresh: _refreshAll,
        ),
        const Divider(height: 1, color: _line),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFFFF3F1),
            child: Text(_error!, style: AppTypography.caption(color: const Color(0xFFB42318))),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _green))
              : _buildSection(),
        ),
      ],
    );
  }

  String get _headerSubtitle {
    if (widget.record != null) {
      final date = _humanRecordDate(widget.record!);
      return <String>[_sectionTitle, if (date.isNotEmpty) date]
          .where((e) => e.isNotEmpty)
          .join(' · ');
    }
    if (widget.section == WorkspacePlayerSection.card) {
      return 'Карточка игрока · изменения сохраняются в профиль';
    }
    if (widget.section == WorkspacePlayerSection.health) {
      return 'Медицинские записи и вложения игрока';
    }
    if (widget.section == WorkspacePlayerSection.documents) {
      return 'Документы и файлы игрока';
    }
    return _sectionTitle;
  }

  String _humanRecordDate(Map<String, dynamic> record) {
    for (final key in const <String>[
      'date', 'record_date', 'match_date', 'test_date', 'event_date', 'scheduled_at', 'start_at', 'start_time', 'datetime', 'created_at',
    ]) {
      final raw = '${record[key] ?? ''}'.trim();
      if (raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      if (parsed == null) return raw;
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year}';
    }
    return '';
  }

  Widget _buildSection() {
    if (widget.record != null) {
      return _buildRecordDocument(widget.record!);
    }
    switch (widget.section) {
      case WorkspacePlayerSection.card:
        return _PlayerCardDocument(
          player: widget.player,
          teamId: widget.teamId,
          bridge: _bridge,
          onSaved: _refreshAll,
        );
      case WorkspacePlayerSection.health:
        return _buildMedicalDocument(documentsOnly: false);
      case WorkspacePlayerSection.documents:
        return _buildMedicalDocument(documentsOnly: true);
      case WorkspacePlayerSection.diary:
        return _buildGenericDocument(liveSummary: _buildDiarySummary());
      case WorkspacePlayerSection.readiness:
      case WorkspacePlayerSection.activity:
      case WorkspacePlayerSection.matches:
      case WorkspacePlayerSection.testing:
        return _buildGenericDocument(liveSummary: _buildPlayerPayloadSummary());
    }
  }

  Widget _buildRecordDocument(Map<String, dynamic> record) {
    final pairs = _recordPairs(record);
    final fileUrl = _recordFileUrl(record);
    final title = _effectiveRecordTitle;
    final summary = <(String, String)>[];
    final details = <(String, String)>[];
    for (final pair in pairs) {
      if (summary.length < 4 && pair.$2.length <= 64) {
        summary.add(pair);
      } else {
        details.add(pair);
      }
    }

    return Column(
      children: [
        if (summary.isNotEmpty || details.isNotEmpty || _canEditServerRecord(record) || fileUrl.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final pair in summary)
                            _CompactRecordProperty(label: pair.$1, value: pair.$2),
                          if (details.isNotEmpty)
                            InkWell(
                              onTap: () => setState(() => _recordDetailsOpen = !_recordDetailsOpen),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                                child: Text(
                                  _recordDetailsOpen ? 'Скрыть данные' : 'Все данные',
                                  style: AppTypography.action(color: _green),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_canEditServerRecord(record))
                      TextButton(
                        onPressed: _savingServerRecord ? null : () => _editServerRecord(record),
                        child: Text(
                          _savingServerRecord ? 'Сохранение…' : 'Редактировать',
                          style: AppTypography.actionStrong(color: _green),
                        ),
                      ),
                    if (fileUrl.isNotEmpty)
                      TextButton(
                        onPressed: () => _openRecordFile(fileUrl),
                        child: Text('Вложение', style: AppTypography.actionStrong(color: _green)),
                      ),
                  ],
                ),
                if (_recordDetailsOpen && details.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  const Divider(height: 1, color: _line),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 20,
                    runSpacing: 9,
                    children: [
                      for (final pair in details)
                        SizedBox(
                          width: pair.$2.length > 90 ? 440 : 230,
                          child: _CompactRecordProperty(label: pair.$1, value: pair.$2, multiline: true),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        if (_canUseRecordAttachments) _buildRecordMaterials(),
        const Divider(height: 1, color: _line),
        Expanded(
          child: DropTarget(
            onDragEntered: (_) => setState(() => _draggingFile = true),
            onDragExited: (_) => setState(() => _draggingFile = false),
            onDragDone: (details) async {
              setState(() => _draggingFile = false);
              await _handleRecordDroppedFiles(details.files);
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: WorkspaceDocumentEditor(
                    key: ValueKey('${widget.section.name}:$_noteStorageKey'),
                    initialTitle: '$title — $_playerName',
                    initialBody: _workspaceNote,
                    titleReadOnly: true,
                    contextLabel: 'Игрок · $title',
                    contextName: _playerName,
                    documentType: widget.section == WorkspacePlayerSection.matches
                        ? 'Рабочий документ матча'
                        : widget.section == WorkspacePlayerSection.activity
                            ? 'Рабочий документ тренировки'
                            : 'Заметка тренера',
                    liveBlocksKey: _noteStorageKey,
                    onSave: _saveWorkspaceNote,
                  ),
                ),
                if (_draggingFile)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.white.withOpacity(.84),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Отпустите файл — добавить внутрь этой записи',
                            style: AppTypography.menuTitle(color: _green),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordMaterials() {
    final documents = _recordDocuments;
    final attachments = _recordAttachments;
    final count = documents.length + attachments.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          color: const Color(0xFFFBFCFB),
          child: Row(
            children: [
              const Icon(Icons.folder_open_rounded, size: 18, color: _green),
              const SizedBox(width: 8),
              Text(
                compact ? '$count' : 'Материалы · $count',
                style: AppTypography.menuTitle(color: _text),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: count == 0
                    ? Text(
                        'Документы и файлы этой записи',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(color: _muted),
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final document in documents) ...[
                            _recordMaterialChip(
                              title: '${document['title'] ?? 'Документ'}',
                              icon: Icons.description_outlined,
                              onOpen: () => _openRecordDocument(document),
                              onDelete: () => _deleteRecordDocument(document),
                            ),
                            const SizedBox(width: 6),
                          ],
                          for (final attachment in attachments) ...[
                            _recordMaterialChip(
                              title: _recordAttachmentTitle(attachment),
                              icon: Icons.insert_drive_file_outlined,
                              onOpen: () => _openRecordAttachment(attachment),
                              onDelete: () => _deleteRecordAttachment(attachment),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
              ),
              const SizedBox(width: 6),
              if (compact)
                IconButton(
                  tooltip: 'Создать документ',
                  onPressed: _createRecordDocument,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                  icon: const Icon(Icons.note_add_outlined, size: 19, color: _green),
                )
              else
                TextButton.icon(
                  onPressed: _createRecordDocument,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.note_add_outlined, size: 17, color: _green),
                  label: Text('Документ', style: AppTypography.actionStrong(color: _green)),
                ),
              if (compact)
                IconButton(
                  tooltip: 'Добавить файл',
                  onPressed: _uploading ? null : _pickRecordAttachment,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                  icon: _uploading
                      ? const SizedBox.square(
                          dimension: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                        )
                      : const Icon(Icons.add_rounded, size: 20, color: _green),
                )
              else
                TextButton.icon(
                  onPressed: _uploading ? null : _pickRecordAttachment,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: _uploading
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                        )
                      : const Icon(Icons.add_rounded, size: 17, color: _green),
                  label: Text(
                    _uploading ? 'Загрузка…' : 'Файл',
                    style: AppTypography.actionStrong(color: _green),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _recordMaterialChip({
    required String title,
    required IconData icon,
    required VoidCallback onOpen,
    required VoidCallback onDelete,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 235),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 5, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: _green),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      title.trim().isEmpty ? 'Документ' : title.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.captionMedium(color: _text),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Удалить',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded, size: 15, color: _muted),
          ),
        ],
      ),
    );
  }

  Future<void> _persistRecordDocuments() async {
    if (widget.record == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordDocumentsStorageKey, jsonEncode(_recordDocuments));
  }

  Future<void> _createRecordDocument() async {
    if (widget.record == null) return;
    final now = DateTime.now();
    final document = <String, dynamic>{
      'id': 'workspace_record_${now.microsecondsSinceEpoch}',
      'title': 'Новый документ',
      'body': '',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      '_workspace_record_document': true,
      '_workspace_pending_sync': true,
    };
    setState(() => _recordDocuments = <Map<String, dynamic>>[document, ..._recordDocuments]);
    await _persistRecordDocuments();
    try {
      await _syncRecordDocument(document, create: true);
    } catch (_) {
      // Keep the local copy open; the first edit retries server synchronization.
    }
    if (mounted) await _openRecordDocument(document);
  }

  Future<void> _openRecordDocument(Map<String, dynamic> document) async {
    final id = '${document['id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (routeContext, animation, secondaryAnimation) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: WorkspaceDocumentEditor(
              initialTitle: '${document['title'] ?? 'Документ'}',
              initialBody: '${document['body'] ?? ''}',
              contextLabel: '$_sectionTitle · $_effectiveRecordTitle',
              contextName: _playerName,
              documentType: 'Документ Sportoteka OS',
              liveBlocksKey: id,
              onSave: (title, body) => _saveRecordDocument(id, title, body),
              onClose: () => Navigator.of(routeContext).maybePop(),
            ),
          ),
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(.018, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _saveRecordDocument(String id, String title, String body) async {
    final now = DateTime.now().toIso8601String();
    Map<String, dynamic>? updated;
    setState(() {
      _recordDocuments = _recordDocuments.map((row) {
        if ('${row['id'] ?? ''}' != id) return row;
        updated = <String, dynamic>{
          ...row,
          'title': title.trim().isEmpty ? 'Документ' : title.trim(),
          'body': body,
          'updated_at': now,
          '_workspace_record_document': true,
          '_workspace_pending_sync': true,
        };
        return updated!;
      }).toList();
    });
    await _persistRecordDocuments();
    if (updated != null) await _syncRecordDocument(updated!, create: false);
  }

  Future<void> _markRecordDocumentSynced(String id) async {
    if (id.isEmpty) return;
    if (mounted) {
      setState(() {
        _recordDocuments = _recordDocuments.map((row) {
          if ('${row['id'] ?? ''}' != id) return row;
          return <String, dynamic>{
            ...row,
            '_workspace_server': true,
            '_workspace_pending_sync': false,
          };
        }).toList();
      });
    } else {
      _recordDocuments = _recordDocuments.map((row) {
        if ('${row['id'] ?? ''}' != id) return row;
        return <String, dynamic>{
          ...row,
          '_workspace_server': true,
          '_workspace_pending_sync': false,
        };
      }).toList();
    }
    await _persistRecordDocuments();
  }

  Future<void> _syncRecordDocument(
    Map<String, dynamic> document, {
    required bool create,
  }) async {
    final server = _serverStorage;
    if (server == null) return;
    final id = '${document['id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    final title = '${document['title'] ?? 'Документ'}'.trim();
    final node = WorkspaceFinderNode(
      id: id,
      title: title.isEmpty ? 'Документ' : title,
      subtitle: 'Материал · $_effectiveRecordTitle',
      kind: WorkspaceFinderNodeKind.note,
      parentId: _serverParentKey,
      createdAt: DateTime.tryParse('${document['created_at'] ?? ''}'),
      updatedAt: DateTime.now(),
    );
    try {
      await server.syncNodeDocument(
        node: node,
        body: '${document['body'] ?? ''}',
        createHint: create,
      );
      final identity = _recordIdentity;
      if (identity != null) {
        await server.linkDocument(
          documentKey: id,
          entityType: identity.type,
          entityId: identity.id,
          sectionKey: widget.section.name,
          title: node.title,
        );
      }
      _serverAvailable = true;
      await _markRecordDocumentSynced(id);
    } catch (e) {
      _serverAvailable = false;
      throw Exception('Документ сохранён локально, но серверная синхронизация не выполнена: $e');
    }
  }

  Future<void> _deleteRecordDocument(Map<String, dynamic> document) async {
    final id = '${document['id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('Удалить документ?', style: AppTypography.sectionTitle(color: _text)),
        content: Text('${document['title'] ?? 'Документ'}', style: AppTypography.body(color: _text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Отмена', style: AppTypography.action(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Удалить', style: AppTypography.action(color: const Color(0xFFB42318))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _recordDocuments.removeWhere((row) => '${row['id'] ?? ''}' == id));
    await _persistRecordDocuments();
    final server = _serverStorage;
    if (server != null) {
      try {
        await server.deleteNode(id);
      } catch (_) {
        _serverAvailable = false;
      }
    }
  }

  String _recordAttachmentTitle(Map<String, dynamic> attachment) {
    final title = '${attachment['title'] ?? attachment['original_name'] ?? attachment['file_name'] ?? attachment['name'] ?? ''}'.trim();
    return title.isEmpty ? 'Файл' : title;
  }

  int _recordAttachmentId(Map<String, dynamic> attachment) =>
      int.tryParse('${attachment['id'] ?? attachment['attachment_id'] ?? ''}'.trim()) ?? 0;

  String _recordAttachmentUrl(Map<String, dynamic> attachment) =>
      '${attachment['file_url'] ?? attachment['url'] ?? attachment['file'] ?? ''}'.trim();

  Future<void> _reloadRecordAttachments() async {
    if (!_canUseRecordAttachments) return;
    final server = _serverStorage;
    if (server == null) return;
    try {
      final rows = await server.listAttachments(
        entityType: 'player',
        entityId: _bridge.resolvePlayerId(widget.player),
        sectionKey: _recordAttachmentSectionKey,
      );
      if (!mounted) return;
      setState(() {
        _recordAttachments = rows;
        _serverAvailable = true;
      });
    } catch (_) {
      _serverAvailable = false;
    }
  }

  Future<void> _openRecordAttachment(Map<String, dynamic> attachment) async {
    final raw = _recordAttachmentUrl(attachment);
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(_absoluteFileUrl(raw));
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickRecordAttachment() async {
    if (!_canUseRecordAttachments || _uploading) return;
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    await _uploadRecordAttachment(result.files.first);
  }

  Future<void> _handleRecordDroppedFiles(List<XFile> files) async {
    if (!_canUseRecordAttachments || files.isEmpty || _uploading) return;
    for (final xfile in files) {
      if (!mounted) return;
      final size = await xfile.length();
      final platformFile = PlatformFile(
        name: xfile.name,
        size: size,
        path: kIsWeb ? null : xfile.path,
        bytes: kIsWeb ? await xfile.readAsBytes() : null,
      );
      await _uploadRecordAttachment(platformFile);
    }
  }

  Future<void> _uploadRecordAttachment(PlatformFile file) async {
    if (!_canUseRecordAttachments || _uploading) return;
    final path = file.path?.trim() ?? '';
    if (path.isEmpty) {
      if (mounted) _snack('Для загрузки файла нужен локальный путь');
      return;
    }
    final title = await _askRecordAttachmentTitle(file.name);
    if (title == null || !mounted) return;
    final server = _serverStorage;
    if (server == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await server.uploadAttachment(
        filePath: path,
        entityType: 'player',
        entityId: _bridge.resolvePlayerId(widget.player),
        sectionKey: _recordAttachmentSectionKey,
        title: title,
      );
      _serverAvailable = true;
      await _reloadRecordAttachments();
      if (mounted) _snack('Файл добавлен внутрь записи');
    } catch (e) {
      _serverAvailable = false;
      if (mounted) _snack('Не удалось добавить файл: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String?> _askRecordAttachmentTitle(String fileName) async {
    final controller = TextEditingController(
      text: fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('Добавить файл в запись', style: AppTypography.sectionTitle(color: _text)),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: controller,
            autofocus: true,
            style: AppTypography.formText(color: _text),
            decoration: InputDecoration(
              labelText: 'Название',
              hintText: fileName,
              labelStyle: AppTypography.formLabel(color: _muted),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Отмена', style: AppTypography.action(color: _muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green, elevation: 0),
            onPressed: () => Navigator.of(dialogContext).pop(
              controller.text.trim().isEmpty ? fileName : controller.text.trim(),
            ),
            child: Text('Добавить', style: AppTypography.actionStrong(color: Colors.white)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _deleteRecordAttachment(Map<String, dynamic> attachment) async {
    final id = _recordAttachmentId(attachment);
    if (id <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('Удалить файл?', style: AppTypography.sectionTitle(color: _text)),
        content: Text(_recordAttachmentTitle(attachment), style: AppTypography.body(color: _text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Отмена', style: AppTypography.action(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Удалить', style: AppTypography.action(color: const Color(0xFFB42318))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final server = _serverStorage;
    if (server == null) return;
    try {
      await server.deleteAttachment(id);
      await _reloadRecordAttachments();
      if (mounted) _snack('Файл удалён');
    } catch (e) {
      if (mounted) _snack('Не удалось удалить файл: $e');
    }
  }

  List<(String, String)> _recordPairs(Map<String, dynamic> record) {
    final out = <(String, String)>[];
    void add(String label, Iterable<String> keys) {
      for (final key in keys) {
        final value = '${record[key] ?? ''}'.trim();
        if (value.isNotEmpty && value != 'null') {
          out.add((label, value));
          return;
        }
      }
    }

    for (final key in const <String>['test_date', 'match_date', 'event_date', 'record_date', 'date', 'start_at', 'created_at']) {
      final raw = '${record[key] ?? ''}'.trim();
      if (raw.isEmpty || raw == 'null') continue;
      out.add(('Дата', _formatRecordDateTime(raw)));
      break;
    }
    switch (widget.section) {
      case WorkspacePlayerSection.matches:
        add('Соперник', const ['opponent', 'opponent_name', 'opponent_team', 'opponent_team_name', 'rival', 'rival_name']);
        final our = '${record['our_score'] ?? record['team_score'] ?? record['score_for'] ?? record['home_score'] ?? ''}'.trim();
        final opp = '${record['opponent_score'] ?? record['score_against'] ?? record['away_score'] ?? ''}'.trim();
        if (our.isNotEmpty || opp.isNotEmpty) out.add(('Счёт', '$our:$opp'));
        add('Турнир', const ['competition_name', 'tournament_name', 'competition', 'event_type', 'league_name']);
        add('Стадион', const ['stadium']);
        add('Тур', const ['tour_label']);
        add('Минуты', const ['minutes']);
        add('Голы', const ['goals']);
        add('Передачи', const ['assists']);
        add('Рейтинг', const ['rating']);
        add('Заметка', const ['coach_comment', 'notes', 'comment']);
        break;
      case WorkspacePlayerSection.testing:
        add('Название', const ['title', 'name', 'session_name']);
        add('Категория', const ['category', 'category_code']);
        add('Этап', const ['stage', 'stage_code']);
        add('Автор', const ['created_by']);
        final metrics = record['workspace_results'];
        if (metrics is List) {
          for (final raw in metrics.whereType<Map>().take(8)) {
            final metric = Map<String, dynamic>.from(raw);
            final metricTitle = '${metric['title'] ?? metric['code'] ?? 'Тест'}'.trim();
            final value = '${metric['value'] ?? ''}'.trim();
            final unit = '${metric['unit'] ?? ''}'.trim();
            final rating = '${metric['rating'] ?? metric['status'] ?? ''}'.trim();
            final points = '${metric['points'] ?? ''}'.trim();
            final details = <String>[
              <String>[value, unit].where((e) => e.isNotEmpty).join(' '),
              if (rating.isNotEmpty) rating,
              if (points.isNotEmpty) '$points б.',
            ].where((e) => e.isNotEmpty).join(' · ');
            if (metricTitle.isNotEmpty && details.isNotEmpty) {
              out.add((metricTitle, details));
            }
          }
        }
        break;
      case WorkspacePlayerSection.activity:
        add('Тренировка', const ['title', 'event_title', 'event_name', 'training_title', 'training_type', 'name', 'event_type']);
        add('Статус', const ['mark', 'status', 'attendance_status']);
        add('Оценка игрока', const ['player_rating', 'self_rating', 'rating']);
        add('Оценка тренера', const ['coach_rating', 'trainer_rating']);
        add('Комментарий', const ['coach_note', 'trainer_note', 'note', 'comment']);
        break;
      case WorkspacePlayerSection.diary:
      case WorkspacePlayerSection.readiness:
        add('Самооценка', const ['self_rating', 'player_rating', 'rating']);
        add('Самочувствие', const ['wellbeing', 'mood', 'feeling', 'readiness']);
        add('Сон', const ['sleep', 'sleep_quality', 'sleep_hours']);
        add('Нагрузка', const ['load', 'rpe', 'fatigue']);
        add('Заметка игрока', const ['player_note', 'self_note', 'diary_note', 'note', 'comment']);
        add('Комментарий тренера', const ['coach_comment', 'trainer_comment', 'coach_note']);
        break;
      case WorkspacePlayerSection.health:
      case WorkspacePlayerSection.documents:
        add('Название', const ['title', 'name']);
        add('Тип', const ['type', 'record_type']);
        add('Значение', const ['value']);
        add('Комментарий', const ['comment', 'notes']);
        break;
      case WorkspacePlayerSection.card:
        break;
    }
    return out.take(12).toList();
  }

  String _formatRecordDateTime(String raw) {
    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed == null) return raw;
    String two(int v) => v.toString().padLeft(2, '0');
    final hasTime = raw.contains(':');
    return hasTime
        ? '${two(parsed.day)}.${two(parsed.month)}.${parsed.year} · ${two(parsed.hour)}:${two(parsed.minute)}'
        : '${two(parsed.day)}.${two(parsed.month)}.${parsed.year}';
  }

  String _recordFileUrl(Map<String, dynamic> record) {
    for (final key in const <String>['file_url', 'file', 'url', 'document_url', 'pdf_url', 'clips_url']) {
      final value = '${record[key] ?? ''}'.trim();
      if (value.startsWith('http://') || value.startsWith('https://')) return value;
    }
    return '';
  }

  Future<void> _openRecordFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  int _diaryEntryId(Map<String, dynamic> record) {
    final direct = int.tryParse('${record['diary_entry_id'] ?? ''}'.trim()) ?? 0;
    if (direct > 0) return direct;
    final source = '${record['_workspace_diary_source'] ?? ''}'.trim();
    if (source != 'player_diary') return 0;
    final raw = int.tryParse('${record['id'] ?? ''}'.trim()) ?? 0;
    return raw.abs();
  }

  bool _isGenericDiaryRecord(Map<String, dynamic> record) =>
      _diaryEntryId(record) > 0 || '${record['_workspace_diary_source'] ?? ''}'.trim() == 'player_diary';

  bool _canEditServerRecord(Map<String, dynamic> record) {
    switch (widget.section) {
      case WorkspacePlayerSection.health:
      case WorkspacePlayerSection.documents:
        return (int.tryParse('${record['id'] ?? record['record_id'] ?? ''}'.trim()) ?? 0) > 0;
      case WorkspacePlayerSection.matches:
        return (int.tryParse('${record['match_id'] ?? record['id'] ?? ''}'.trim()) ?? 0) > 0;
      case WorkspacePlayerSection.diary:
        if (_isGenericDiaryRecord(record)) return true;
        return (int.tryParse(
                  '${record['event_id'] ?? record['team_event_id'] ?? record['training_id'] ?? ''}'.trim(),
                ) ??
                0) >
            0;
      case WorkspacePlayerSection.activity:
      case WorkspacePlayerSection.readiness:
        return (int.tryParse(
                  '${record['event_id'] ?? record['team_event_id'] ?? record['training_id'] ?? ''}'.trim(),
                ) ??
                0) >
            0;
      case WorkspacePlayerSection.card:
      case WorkspacePlayerSection.testing:
        return false;
    }
  }

  Future<void> _editServerRecord(Map<String, dynamic> record) async {
    switch (widget.section) {
      case WorkspacePlayerSection.health:
      case WorkspacePlayerSection.documents:
        await _editMedicalServerRecord(record);
        break;
      case WorkspacePlayerSection.matches:
        await _editMatchServerRecord(record);
        break;
      case WorkspacePlayerSection.diary:
        if (_isGenericDiaryRecord(record)) {
          await _editGenericDiaryRecord(record);
        } else {
          await _editEventNote(record);
        }
        break;
      case WorkspacePlayerSection.activity:
      case WorkspacePlayerSection.readiness:
        await _editEventNote(record);
        break;
      case WorkspacePlayerSection.card:
      case WorkspacePlayerSection.testing:
        break;
    }
  }

  DateTime _recordDate(Map<String, dynamic> record) {
    for (final key in const <String>[
      'date', 'record_date', 'match_date', 'test_date', 'event_date', 'scheduled_at', 'start_at', 'start_time', 'datetime', 'created_at',
    ]) {
      final raw = '${record[key] ?? ''}'.trim();
      if (raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  String _ymd(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  Future<bool> _showServerEditor({
    required String title,
    required Widget Function(BuildContext context, StateSetter setLocal) fields,
  }) async {
    final mobile = MediaQuery.sizeOf(context).width < 700;

    Widget content(BuildContext sheetContext, StateSetter setLocal) {
      return SafeArea(
        top: !mobile,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 620, maxHeight: MediaQuery.sizeOf(sheetContext).height * .90),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(mobile ? 18 : 14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 15, 12, 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _line)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(title, style: AppTypography.sectionTitle(color: _text))),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close_rounded, size: 19),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: fields(sheetContext, setLocal),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _line)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: Text('Отмена', style: AppTypography.action(color: _muted)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        style: FilledButton.styleFrom(backgroundColor: _green, elevation: 0),
                        child: Text('Сохранить', style: AppTypography.actionStrong(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (mobile) {
      return (await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => StatefulBuilder(
              builder: (sheetContext, setLocal) => Align(
                alignment: Alignment.bottomCenter,
                child: content(sheetContext, setLocal),
              ),
            ),
          )) ??
          false;
    }

    return (await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(.14),
          builder: (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            child: StatefulBuilder(
              builder: (dialogContext, setLocal) => content(dialogContext, setLocal),
            ),
          ),
        )) ??
        false;
  }

  InputDecoration _editorDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppTypography.formLabel(color: _muted),
      hintStyle: AppTypography.formHint(color: _muted),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _green, width: 1.1),
      ),
    );
  }

  Future<void> _editMedicalServerRecord(Map<String, dynamic> record) async {
    final titleC = TextEditingController(text: '${record['title'] ?? record['name'] ?? ''}'.trim());
    final typeC = TextEditingController(text: '${record['type'] ?? record['record_type'] ?? (_sectionTitle == 'Документы' ? 'Документ' : 'Запись')}'.trim());
    final valueC = TextEditingController(text: '${record['value'] ?? ''}'.trim());
    final commentC = TextEditingController(text: '${record['comment'] ?? record['notes'] ?? ''}'.trim());
    var date = _recordDate(record);

    final confirmed = await _showServerEditor(
      title: widget.section == WorkspacePlayerSection.documents ? 'Редактировать документ' : 'Редактировать медицинскую запись',
      fields: (sheetContext, setLocal) => Column(
        children: [
          TextField(controller: titleC, style: AppTypography.formText(color: _text), decoration: _editorDecoration('Название')),
          const SizedBox(height: 10),
          TextField(controller: typeC, style: AppTypography.formText(color: _text), decoration: _editorDecoration('Тип')),
          const SizedBox(height: 10),
          TextField(controller: valueC, minLines: 2, maxLines: 4, style: AppTypography.formText(color: _text), decoration: _editorDecoration('Описание / значение')),
          const SizedBox(height: 10),
          TextField(controller: commentC, minLines: 2, maxLines: 4, style: AppTypography.formText(color: _text), decoration: _editorDecoration('Комментарий')),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: sheetContext,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setLocal(() => date = picked);
              },
              child: Text('Дата: ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}', style: AppTypography.action()),
            ),
          ),
        ],
      ),
    );

    if (!confirmed || !mounted) {
      titleC.dispose();
      typeC.dispose();
      valueC.dispose();
      commentC.dispose();
      return;
    }

    setState(() => _savingServerRecord = true);
    try {
      await _bridge.updateMedicalRecord(
        record: record,
        player: widget.player,
        type: typeC.text,
        title: titleC.text,
        value: valueC.text,
        comment: commentC.text,
        date: date,
      );
      record.addAll(<String, dynamic>{
        'title': titleC.text.trim(),
        'type': typeC.text.trim(),
        'value': valueC.text.trim(),
        'comment': commentC.text.trim(),
        'date': _ymd(date),
      });
      await widget.onRefresh?.call();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Запись обновлена')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      titleC.dispose();
      typeC.dispose();
      valueC.dispose();
      commentC.dispose();
      if (mounted) setState(() => _savingServerRecord = false);
    }
  }

  Future<void> _editMatchServerRecord(Map<String, dynamic> record) async {
    final opponentC = TextEditingController(text: '${record['opponent'] ?? record['opponent_name'] ?? ''}'.trim());
    final dateC = TextEditingController(text: '${record['match_date'] ?? record['date'] ?? ''}'.toString().split(' ').first);
    final competitionC = TextEditingController(text: '${record['competition_name'] ?? ''}'.trim());
    final ourScoreC = TextEditingController(text: '${record['our_score'] ?? ''}'.trim());
    final opponentScoreC = TextEditingController(text: '${record['opponent_score'] ?? ''}'.trim());
    final videoC = TextEditingController(text: '${record['video_url'] ?? record['video'] ?? ''}'.trim());
    final ttdC = TextEditingController(text: '${record['ttd_text'] ?? record['ttd'] ?? ''}'.trim());
    final notesC = TextEditingController(text: '${record['notes'] ?? record['coach_comment'] ?? ''}'.trim());

    final confirmed = await _showServerEditor(
      title: 'Редактировать матч',
      fields: (sheetContext, setLocal) => Column(
        children: [
          TextField(controller: opponentC, style: AppTypography.formText(color: _text), decoration: _editorDecoration('Соперник')),
          const SizedBox(height: 10),
          TextField(controller: dateC, style: AppTypography.formText(color: _text), decoration: _editorDecoration('Дата матча', hint: '2026-08-25')),
          const SizedBox(height: 10),
          TextField(controller: competitionC, style: AppTypography.formText(color: _text), decoration: _editorDecoration('Турнир / соревнование')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: ourScoreC, keyboardType: TextInputType.number, style: AppTypography.formText(color: _text), decoration: _editorDecoration('Голы команды'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: opponentScoreC, keyboardType: TextInputType.number, style: AppTypography.formText(color: _text), decoration: _editorDecoration('Голы соперника'))),
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: videoC, style: AppTypography.formText(color: _text), decoration: _editorDecoration('Ссылка на видео')),
          const SizedBox(height: 10),
          TextField(controller: ttdC, minLines: 2, maxLines: 4, style: AppTypography.formText(color: _text), decoration: _editorDecoration('ТТД')),
          const SizedBox(height: 10),
          TextField(controller: notesC, minLines: 2, maxLines: 4, style: AppTypography.formText(color: _text), decoration: _editorDecoration('Комментарий тренера')),
        ],
      ),
    );

    if (!confirmed || !mounted) {
      for (final c in <TextEditingController>[opponentC, dateC, competitionC, ourScoreC, opponentScoreC, videoC, ttdC, notesC]) {
        c.dispose();
      }
      return;
    }

    final fields = <String, String>{
      'opponent': opponentC.text.trim(),
      'match_date': dateC.text.trim(),
      'competition_name': competitionC.text.trim(),
      'our_score': ourScoreC.text.trim(),
      'opponent_score': opponentScoreC.text.trim(),
      'video_url': videoC.text.trim(),
      'ttd_text': ttdC.text.trim(),
      'notes': notesC.text.trim(),
    };

    setState(() => _savingServerRecord = true);
    try {
      await _bridge.updatePlayerMatch(
        player: widget.player,
        teamId: widget.teamId,
        record: record,
        fields: fields,
      );
      record.addAll(fields);
      await widget.onRefresh?.call();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Матч обновлён')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      for (final c in <TextEditingController>[opponentC, dateC, competitionC, ourScoreC, opponentScoreC, videoC, ttdC, notesC]) {
        c.dispose();
      }
      if (mounted) setState(() => _savingServerRecord = false);
    }
  }

  Future<void> _editGenericDiaryRecord(Map<String, dynamic> record) async {
    final diaryEntryId = _diaryEntryId(record);
    if (diaryEntryId <= 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Не удалось определить запись дневника')),
      );
      return;
    }

    final noteC = TextEditingController(
      text: '${record['note'] ?? record['coach_note'] ?? record['comment'] ?? ''}'.trim(),
    );
    var date = _recordDate(record);
    final confirmed = await _showServerEditor(
      title: 'Редактировать запись дневника',
      fields: (sheetContext, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: noteC,
            minLines: 7,
            maxLines: 14,
            style: AppTypography.formText(color: _text),
            decoration: _editorDecoration('Заметка тренера'),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: sheetContext,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setLocal(() => date = picked);
              },
              child: Text(
                'Дата: ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                style: AppTypography.action(),
              ),
            ),
          ),
        ],
      ),
    );

    if (!confirmed || !mounted) {
      noteC.dispose();
      return;
    }
    if (noteC.text.trim().isEmpty) {
      noteC.dispose();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Заметка не может быть пустой')),
      );
      return;
    }

    setState(() => _savingServerRecord = true);
    try {
      await _bridge.updateDiaryEntry(
        player: widget.player,
        clubId: widget.clubId,
        teamId: widget.teamId,
        diaryEntryId: diaryEntryId,
        note: noteC.text,
        date: date,
      );
      record['note'] = noteC.text.trim();
      record['coach_note'] = noteC.text.trim();
      record['entry_date'] = _ymd(date);
      record['start_at'] = _ymd(date);
      record['updated_at'] = DateTime.now().toIso8601String();
      await widget.onRefresh?.call();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Запись дневника обновлена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      noteC.dispose();
      if (mounted) setState(() => _savingServerRecord = false);
    }
  }

  Future<void> _editEventNote(Map<String, dynamic> record) async {
    final noteC = TextEditingController(
      text: '${record['coach_note'] ?? record['trainer_note'] ?? record['note'] ?? record['coach_comment'] ?? ''}'.trim(),
    );
    final confirmed = await _showServerEditor(
      title: 'Комментарий тренера',
      fields: (sheetContext, setLocal) => TextField(
        controller: noteC,
        minLines: 5,
        maxLines: 10,
        style: AppTypography.formText(color: _text),
        decoration: _editorDecoration('Комментарий к записи'),
      ),
    );
    if (!confirmed || !mounted) {
      noteC.dispose();
      return;
    }
    setState(() => _savingServerRecord = true);
    try {
      await _bridge.savePlayerEventNote(player: widget.player, record: record, note: noteC.text);
      record['coach_note'] = noteC.text.trim();
      record['note'] = noteC.text.trim();
      await widget.onRefresh?.call();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Комментарий сохранён')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      noteC.dispose();
      if (mounted) setState(() => _savingServerRecord = false);
    }
  }

  Widget _buildGenericDocument({required Widget liveSummary}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Column(
          children: [
            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxHeight: compact ? 128 : 150),
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 10, compact ? 12 : 18, 10),
              child: SingleChildScrollView(child: liveSummary),
            ),
            const Divider(height: 1, color: _line),
            Expanded(
              child: WorkspaceDocumentEditor(
                key: ValueKey(widget.section.name),
                initialTitle: '$_sectionTitle — $_playerName',
                initialBody: _workspaceNote,
                titleReadOnly: true,
                contextLabel: 'Игрок · $_sectionTitle',
                contextName: _playerName,
                documentType: 'Заметка тренера',
                liveBlocksKey: _noteStorageKey,
                onSave: _saveWorkspaceNote,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiarySummary() {
    if (_diary.isEmpty) {
      return Row(
        children: [
          const _SyncDot(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Серверных записей дневника пока нет. Рабочая заметка ниже всё равно сохраняется.',
              style: AppTypography.secondary(color: _muted),
            ),
          ),
        ],
      );
    }
    final items = _diary.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const _SyncDot(),
            const SizedBox(width: 8),
            Text('Живой дневник · ${_diary.length} записей', style: AppTypography.menuTitle(color: _text)),
          ],
        ),
        const SizedBox(height: 7),
        ...items.map((item) {
          final title = '${item['title'] ?? item['training_title'] ?? 'Тренировка'}';
          final date = '${item['start_at'] ?? item['updated_at'] ?? item['created_at'] ?? ''}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $title${date.trim().isEmpty ? '' : ' · $date'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(color: _muted),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlayerPayloadSummary() {
    final keys = _summaryKeysForSection(widget.section);
    final rows = <MapEntry<String, String>>[];
    for (final item in keys) {
      final value = '${widget.player[item.$2] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') {
        rows.add(MapEntry(item.$1, value));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const _SyncDot(),
            const SizedBox(width: 8),
            Text('Данные профиля', style: AppTypography.menuTitle(color: _text)),
            const SizedBox(width: 8),
            Text('read-only snapshot', style: AppTypography.menuGroup(color: _muted)),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(
            'В карточке игрока нет готовых полей для этой сводки. Рабочий документ ниже можно вести вручную.',
            style: AppTypography.secondary(color: _muted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: rows
                .map(
                  (row) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _line),
                    ),
                    child: Text('${row.key}: ${row.value}', style: AppTypography.captionMedium(color: _text)),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  List<(String, String)> _summaryKeysForSection(WorkspacePlayerSection section) {
    switch (section) {
      case WorkspacePlayerSection.readiness:
        return const <(String, String)>[
          ('Готовность', 'readiness'),
          ('Самочувствие', 'wellbeing'),
          ('Сон', 'sleep'),
          ('Усталость', 'fatigue'),
          ('Нагрузка', 'load_score'),
        ];
      case WorkspacePlayerSection.activity:
        return const <(String, String)>[
          ('Активность', 'activity_label'),
          ('Дистанция', 'distance'),
          ('Скорость', 'max_speed'),
          ('Тренировок', 'trainings_count'),
          ('ЧСС', 'heart_rate'),
        ];
      case WorkspacePlayerSection.matches:
        return const <(String, String)>[
          ('Матчей', 'matches_count'),
          ('Голов', 'goals'),
          ('Передач', 'assists'),
          ('Минут', 'minutes_played'),
        ];
      case WorkspacePlayerSection.testing:
        return const <(String, String)>[
          ('Последний тест', 'last_test'),
          ('Скорость', 'test_speed'),
          ('Выносливость', 'endurance'),
          ('Рейтинг', 'testing_rating'),
        ];
      default:
        return const <(String, String)>[];
    }
  }

  Widget _buildMedicalDocument({required bool documentsOnly}) {
    final records = documentsOnly
        ? _medicalRecords.where(_looksLikeDocument).toList()
        : _medicalRecords;
    return Column(
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _line)),
          ),
          child: Row(
            children: [
              const _SyncDot(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  documentsOnly
                      ? 'Файлы игрока · ${records.length}'
                      : 'Медицинские записи · ${records.length}',
                  style: AppTypography.menuTitle(color: _text),
                ),
              ),
              FilledButton.icon(
                onPressed: _uploading ? null : () => _pickAndUpload(documentsOnly: documentsOnly),
                style: FilledButton.styleFrom(backgroundColor: _green, elevation: 0),
                icon: _uploading
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_rounded, size: 17),
                label: Text(
                  documentsOnly ? 'Добавить файл' : 'Добавить запись/файл',
                  style: AppTypography.actionStrong(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: DropTarget(
            onDragEntered: (_) => setState(() => _draggingFile = true),
            onDragExited: (_) => setState(() => _draggingFile = false),
            onDragDone: (details) async {
              setState(() => _draggingFile = false);
              await _handleDroppedFiles(details.files, documentsOnly: documentsOnly);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: _draggingFile ? const Color(0xFFF0F8F4) : Colors.white,
                border: _draggingFile
                    ? Border.all(color: _green, width: 1.4)
                    : null,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: records.isEmpty
                        ? _MedicalEmpty(
                            documentsOnly: documentsOnly,
                            onAdd: () => _pickAndUpload(documentsOnly: documentsOnly),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                            itemCount: records.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, index) => _MedicalRecordRow(
                              record: records[index],
                              onOpen: () => _openRecord(records[index]),
                            ),
                          ),
                  ),
                  if (_draggingFile)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.white.withOpacity(.82),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF5EF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              documentsOnly
                                  ? 'Отпустите файл — добавить в документы игрока'
                                  : 'Отпустите файл — добавить в медкарту игрока',
                              style: AppTypography.menuTitle(color: _green),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _looksLikeDocument(Map<String, dynamic> record) {
    final type = '${record['type'] ?? ''}'.toLowerCase();
    final url = '${record['file_url'] ?? record['file'] ?? record['url'] ?? ''}'.trim();
    return url.isNotEmpty ||
        type.contains('док') ||
        type.contains('справ') ||
        type.contains('файл') ||
        type.contains('document');
  }

  Future<void> _openRecord(Map<String, dynamic> record) async {
    final raw = '${record['file_url'] ?? record['file'] ?? record['url'] ?? ''}'.trim();
    if (raw.isEmpty) return;
    final url = _absoluteFileUrl(raw);
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _absoluteFileUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/${raw.replaceFirst(RegExp(r'^\./+'), '')}';
  }

  Future<void> _handleDroppedFiles(
    List<XFile> files, {
    required bool documentsOnly,
  }) async {
    if (files.isEmpty || _uploading) return;
    for (final xfile in files) {
      if (!mounted) return;
      final size = await xfile.length();
      final platformFile = PlatformFile(
        name: xfile.name,
        size: size,
        path: kIsWeb ? null : xfile.path,
        bytes: kIsWeb ? await xfile.readAsBytes() : null,
      );
      final meta = await _askUploadMetadata(
        fileName: platformFile.name,
        documentsOnly: documentsOnly,
      );
      if (meta == null || !mounted) continue;
      setState(() {
        _uploading = true;
        _error = null;
      });
      try {
        await _bridge.uploadMedicalAttachment(
          player: widget.player,
          file: platformFile,
          title: meta.title,
          type: documentsOnly ? 'Документ' : meta.type,
          comment: meta.comment,
          date: meta.date,
        );
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }
    if (mounted) {
      await _refreshAll();
      _snack('Файлы привязаны к игроку');
    }
  }

  Future<void> _pickAndUpload({required bool documentsOnly}) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const <String>[
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'jpg',
        'jpeg',
        'png',
        'heic',
        'txt',
      ],
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;

    final meta = await _askUploadMetadata(
      fileName: file.name,
      documentsOnly: documentsOnly,
    );
    if (meta == null || !mounted) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await _bridge.uploadMedicalAttachment(
        player: widget.player,
        file: file,
        title: meta.title,
        type: documentsOnly ? 'Документ' : meta.type,
        comment: meta.comment,
        date: meta.date,
      );
      await _refreshAll();
      if (mounted) _snack('Файл сохранён и привязан к игроку');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<_UploadMeta?> _askUploadMetadata({
    required String fileName,
    required bool documentsOnly,
  }) async {
    final title = TextEditingController(text: fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''));
    final comment = TextEditingController();
    var type = documentsOnly ? 'Документ' : 'Справка';
    var date = DateTime.now();

    final result = await showDialog<_UploadMeta>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(documentsOnly ? 'Новый документ' : 'Новый медицинский файл', style: AppTypography.sectionTitle()),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _muted)),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  autofocus: true,
                  style: AppTypography.formText(),
                  decoration: InputDecoration(labelText: 'Название', labelStyle: AppTypography.formLabel()),
                ),
                if (!documentsOnly) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: type,
                    style: AppTypography.formText(color: _text),
                    decoration: InputDecoration(labelText: 'Тип', labelStyle: AppTypography.formLabel()),
                    items: const <String>['Справка', 'Осмотр', 'Травма', 'Допуск', 'Рекомендация', 'Документ']
                        .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) => setDialogState(() => type = value ?? type),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: comment,
                  maxLines: 2,
                  style: AppTypography.formText(),
                  decoration: InputDecoration(labelText: 'Комментарий', labelStyle: AppTypography.formLabel()),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  child: Text('Дата: ${_displayDate(date)}', style: AppTypography.action()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('Отмена', style: AppTypography.action())),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                _UploadMeta(
                  title: title.text.trim().isEmpty ? fileName : title.text.trim(),
                  type: type,
                  comment: comment.text.trim(),
                  date: date,
                ),
              ),
              child: Text('Добавить', style: AppTypography.actionStrong(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    comment.dispose();
    return result;
  }

  String _displayDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year}';
  }

  void _snack(String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
  }
}

class _CompactRecordProperty extends StatelessWidget {
  const _CompactRecordProperty({required this.label, required this.value, this.multiline = false});
  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: multiline ? 440 : 220),
      child: RichText(
        maxLines: multiline ? 5 : 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(text: '$label  ', style: AppTypography.caption(color: _WorkspacePlayerSectionDocumentState._muted)),
            TextSpan(text: value, style: AppTypography.secondaryMedium(color: _WorkspacePlayerSectionDocumentState._text)),
          ],
        ),
      ),
    );
  }
}

class _RecordField extends StatelessWidget {
  const _RecordField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7EAE7), width: .7),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTypography.caption(color: const Color(0xFF758079))),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.secondaryMedium(color: const Color(0xFF101814)),
          ),
        ],
      ),
    );
  }
}

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onRefresh,
  });
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Container(
      height: compact ? 58 : 66,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(onPressed: onBack, tooltip: 'Назад', icon: const Icon(Icons.arrow_back_rounded, size: 20)),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.screenTitle(color: _WorkspacePlayerSectionDocumentState._text)),
                if (!compact)
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _WorkspacePlayerSectionDocumentState._muted)),
              ],
            ),
          ),
          IconButton(onPressed: onRefresh, tooltip: 'Обновить', icon: const Icon(Icons.refresh_rounded, size: 19)),
        ],
      ),
    );
  }
}

class _PlayerCardDocument extends StatefulWidget {
  const _PlayerCardDocument({
    required this.player,
    required this.teamId,
    required this.bridge,
    required this.onSaved,
  });

  final Map<String, dynamic> player;
  final int? teamId;
  final WorkspacePlayerDataBridge bridge;
  final Future<void> Function() onSaved;

  @override
  State<_PlayerCardDocument> createState() => _PlayerCardDocumentState();
}

class _PlayerCardDocumentState extends State<_PlayerCardDocument> {
  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};
  bool _saving = false;
  String? _error;

  static const _fields = <(String, String, String)>[
    ('first_name', 'Имя', 'Имя игрока'),
    ('last_name', 'Фамилия', 'Фамилия игрока'),
    ('birth_date', 'Дата рождения', 'YYYY-MM-DD'),
    ('position', 'Амплуа', 'Например: полузащитник'),
    ('number', 'Номер', 'Игровой номер'),
    ('email', 'Email', 'email@example.com'),
    ('phone', 'Телефон', '+...'),
    ('height', 'Рост', 'см'),
    ('weight', 'Вес', 'кг'),
  ];

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      _controllers[field.$1] = TextEditingController(text: _initialValue(field.$1));
    }
  }

  String _initialValue(String key) {
    final aliases = <String, List<String>>{
      'first_name': const <String>['first_name', 'firstname', 'firstName'],
      'last_name': const <String>['last_name', 'lastname', 'lastName'],
      'birth_date': const <String>['birth_date', 'birthDate', 'birthday'],
      'position': const <String>['position', 'amplua', 'role_on_field'],
      'number': const <String>['number', 'shirt_number', 'player_number'],
      'email': const <String>['email'],
      'phone': const <String>['phone', 'phone_number'],
      'height': const <String>['height', 'height_cm'],
      'weight': const <String>['weight', 'weight_kg'],
    };
    for (final alias in aliases[key] ?? <String>[key]) {
      final value = '${widget.player[alias] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fields = <String, String>{
        for (final field in _fields) field.$1: _controllers[field.$1]!.text.trim(),
      };
      await widget.bridge.updatePlayerFields(
        player: widget.player,
        teamId: widget.teamId,
        fields: fields,
      );
      widget.player.addAll(fields);
      await widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Карточка игрока сохранена')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Column(
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _WorkspacePlayerSectionDocumentState._line)),
          ),
          child: Row(
            children: [
              Text('Редактирование карточки', style: AppTypography.menuTitle(color: _WorkspacePlayerSectionDocumentState._text)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: _WorkspacePlayerSectionDocumentState._green, elevation: 0),
                icon: _saving
                    ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 17),
                label: Text('Сохранить', style: AppTypography.actionStrong(color: Colors.white)),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Text(_error!, style: AppTypography.caption(color: const Color(0xFFB42318))),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(mobile ? 12 : 24, 18, mobile ? 12 : 24, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _WorkspacePlayerSectionDocumentState._line),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Color(0x0E000000), blurRadius: 20, offset: Offset(0, 8)),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(mobile ? 16 : 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Карточка игрока', style: AppTypography.screenTitle(color: _WorkspacePlayerSectionDocumentState._text)),
                        const SizedBox(height: 4),
                        Text('Изменения записываются через update_player.php и используются обычным профилем.', style: AppTypography.secondary(color: _WorkspacePlayerSectionDocumentState._muted)),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 650 ? 2 : 1;
                            final width = columns == 2 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _fields.map((field) {
                                return SizedBox(
                                  width: width,
                                  child: TextField(
                                    controller: _controllers[field.$1],
                                    style: AppTypography.formText(),
                                    decoration: InputDecoration(
                                      labelText: field.$2,
                                      hintText: field.$3,
                                      labelStyle: AppTypography.formLabel(),
                                      hintStyle: AppTypography.formHint(),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _WorkspacePlayerSectionDocumentState._line)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _WorkspacePlayerSectionDocumentState._line)),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MedicalRecordRow extends StatelessWidget {
  const _MedicalRecordRow({required this.record, required this.onOpen});
  final Map<String, dynamic> record;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = '${record['title'] ?? record['name'] ?? 'Запись'}'.trim();
    final type = '${record['type'] ?? 'Медкарта'}'.trim();
    final date = '${record['date'] ?? record['record_date'] ?? record['created_at'] ?? ''}'.trim();
    final comment = '${record['comment'] ?? record['notes'] ?? ''}'.trim();
    final file = '${record['file_url'] ?? record['file'] ?? record['url'] ?? ''}'.trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: file.isEmpty ? null : onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5EF),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(file.isEmpty ? Icons.medical_information_outlined : Icons.description_outlined, size: 19, color: _WorkspacePlayerSectionDocumentState._green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.isEmpty ? 'Без названия' : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _WorkspacePlayerSectionDocumentState._text)),
                    const SizedBox(height: 2),
                    Text(
                      <String>[type, if (date.isNotEmpty) date].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(color: _WorkspacePlayerSectionDocumentState._muted),
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(comment, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _WorkspacePlayerSectionDocumentState._muted)),
                    ],
                  ],
                ),
              ),
              if (file.isNotEmpty) const Icon(Icons.open_in_new_rounded, size: 17, color: _WorkspacePlayerSectionDocumentState._muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicalEmpty extends StatelessWidget {
  const _MedicalEmpty({required this.documentsOnly, required this.onAdd});
  final bool documentsOnly;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFFB9C2BC)),
            const SizedBox(height: 10),
            Text(documentsOnly ? 'Документов пока нет' : 'Медицинских записей пока нет', style: AppTypography.sectionTitle()),
            const SizedBox(height: 5),
            Text(
              'Добавленный здесь файл будет привязан к этому игроку на сервере.',
              textAlign: TextAlign.center,
              style: AppTypography.secondary(color: _WorkspacePlayerSectionDocumentState._muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAdd, child: Text('Добавить файл', style: AppTypography.action())),
          ],
        ),
      ),
    );
  }
}

class _SyncDot extends StatelessWidget {
  const _SyncDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(color: _WorkspacePlayerSectionDocumentState._green, shape: BoxShape.circle),
    );
  }
}

class _UploadMeta {
  const _UploadMeta({required this.title, required this.type, required this.comment, required this.date});
  final String title;
  final String type;
  final String comment;
  final DateTime date;
}
