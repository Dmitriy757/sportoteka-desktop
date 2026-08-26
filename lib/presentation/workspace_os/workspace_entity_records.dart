import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_document_editor.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_server_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkspaceEntityProperty {
  const WorkspaceEntityProperty(this.label, this.value);
  final String label;
  final String value;
}

class WorkspaceEntityRecordBrowser extends StatefulWidget {
  const WorkspaceEntityRecordBrowser({
    super.key,
    required this.ownerTitle,
    required this.sectionTitle,
    required this.iconKind,
    required this.loadRecords,
    required this.titleFor,
    required this.subtitleFor,
    required this.dateFor,
    required this.propertiesFor,
    required this.openRecord,
    this.emptyText = 'Записей пока нет',
    this.localStorageKey = '',
    this.contextLabel = 'Рабочая запись',
    this.clubId = 0,
    this.serverParentKey = '',
    this.attachmentEntityType = '',
    this.attachmentEntityId = 0,
    this.attachmentSectionKey = 'documents',
    this.externalUploadPaths,
    this.showBackButton = true,
  });

  final String ownerTitle;
  final String sectionTitle;
  final SportotekaWorkspaceIconKind iconKind;
  final Future<List<Map<String, dynamic>>> Function() loadRecords;
  final String Function(Map<String, dynamic>) titleFor;
  final String Function(Map<String, dynamic>) subtitleFor;
  final String Function(Map<String, dynamic>) dateFor;
  final List<WorkspaceEntityProperty> Function(Map<String, dynamic>) propertiesFor;
  final Future<void> Function(BuildContext context, Map<String, dynamic> record) openRecord;
  final String emptyText;
  final String localStorageKey;
  final String contextLabel;
  final int clubId;
  final String serverParentKey;
  final String attachmentEntityType;
  final int attachmentEntityId;
  final String attachmentSectionKey;
  final Future<void> Function(List<String> paths)? externalUploadPaths;
  final bool showBackButton;

  @override
  State<WorkspaceEntityRecordBrowser> createState() => _WorkspaceEntityRecordBrowserState();
}

class _WorkspaceEntityRecordBrowserState extends State<WorkspaceEntityRecordBrowser> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);
  static const _soft = Color(0xFFF7F8F7);

  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _localRecords = <Map<String, dynamic>>[];
  Map<String, dynamic>? _selected;
  bool _newestFirst = true;
  WorkspaceServerStorage? _serverStorage;
  bool _serverAvailable = false;
  bool _uploadingAttachment = false;
  bool _draggingAttachment = false;

  bool get _usesWorkspaceAttachments =>
      widget.clubId > 0 &&
      widget.attachmentEntityType.trim().isNotEmpty &&
      widget.attachmentEntityId > 0;

  bool get _canUploadAttachments =>
      widget.externalUploadPaths != null || _usesWorkspaceAttachments;

  @override
  void initState() {
    super.initState();
    if (widget.clubId > 0 && widget.serverParentKey.trim().isNotEmpty) {
      _serverStorage = WorkspaceServerStorage(clubId: widget.clubId);
    }
    _search.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    _search
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  DateTime _date(Map<String, dynamic> row) {
    final raw = _dateFor(row).trim();
    if (raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw.replaceFirst(' ', 'T')) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _isLocal(Map<String, dynamic> row) => row['_workspace_local'] == true;
  bool _isAttachment(Map<String, dynamic> row) => row['_workspace_attachment'] == true;

  String _titleFor(Map<String, dynamic> row) {
    if (_isLocal(row)) return '${row['title'] ?? 'Рабочая заметка'}'.trim();
    if (_isAttachment(row)) return '${row['title'] ?? row['original_name'] ?? 'Файл'}'.trim();
    return widget.titleFor(row);
  }

  String _subtitleFor(Map<String, dynamic> row) {
    if (_isLocal(row)) return '${row['subtitle'] ?? 'Редактируемая заметка'}'.trim();
    if (_isAttachment(row)) {
      final mime = '${row['mime_type'] ?? ''}'.trim();
      final size = int.tryParse('${row['file_size'] ?? '0'}') ?? 0;
      final sizeLabel = size <= 0 ? '' : (size < 1024 * 1024 ? '${(size / 1024).toStringAsFixed(0)} КБ' : '${(size / 1024 / 1024).toStringAsFixed(1)} МБ');
      return <String>[mime, sizeLabel].where((e) => e.isNotEmpty).join(' · ');
    }
    return widget.subtitleFor(row);
  }

  String _dateFor(Map<String, dynamic> row) {
    if (_isLocal(row) || _isAttachment(row)) return '${row['updated_at'] ?? row['created_at'] ?? ''}'.trim();
    return widget.dateFor(row);
  }

  List<WorkspaceEntityProperty> _propertiesFor(Map<String, dynamic> row) {
    if (_isAttachment(row)) {
      final size = int.tryParse('${row['file_size'] ?? '0'}') ?? 0;
      final sizeLabel = size <= 0 ? '—' : (size < 1024 * 1024 ? '${(size / 1024).toStringAsFixed(0)} КБ' : '${(size / 1024 / 1024).toStringAsFixed(1)} МБ');
      return <WorkspaceEntityProperty>[
        const WorkspaceEntityProperty('Тип', 'Файл'),
        WorkspaceEntityProperty('Раздел', widget.sectionTitle),
        WorkspaceEntityProperty('Имя файла', '${row['original_name'] ?? ''}'),
        WorkspaceEntityProperty('Размер', sizeLabel),
        WorkspaceEntityProperty('Добавлено', _friendlyDate(_dateFor(row))),
      ];
    }
    if (_isLocal(row)) {
      return <WorkspaceEntityProperty>[
        const WorkspaceEntityProperty('Тип', 'Рабочая заметка'),
        WorkspaceEntityProperty('Раздел', widget.sectionTitle),
        WorkspaceEntityProperty('Обновлено', _friendlyDate(_dateFor(row))),
      ];
    }
    return widget.propertiesFor(row);
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.trim().toLowerCase();
    final rows = _records.where((r) {
      if (q.isEmpty) return true;
      final props = _propertiesFor(r).map((p) => '${p.label} ${p.value}').join(' ');
      return '${_titleFor(r)} ${_subtitleFor(r)} ${_dateFor(r)} $props'.toLowerCase().contains(q);
    }).map((e) => Map<String, dynamic>.from(e)).toList();
    rows.sort((a, b) => _newestFirst ? _date(b).compareTo(_date(a)) : _date(a).compareTo(_date(b)));
    return rows;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.loadRecords();
      final localRows = await _readLocalRecords();
      var attachments = <Map<String, dynamic>>[];
      if (_usesWorkspaceAttachments && _serverStorage != null) {
        try {
          attachments = (await _serverStorage!.listAttachments(
            entityType: widget.attachmentEntityType,
            entityId: widget.attachmentEntityId,
            sectionKey: widget.attachmentSectionKey,
          )).map((row) => <String, dynamic>{...row, '_workspace_attachment': true}).toList();
        } catch (_) {}
      }
      final merged = <Map<String, dynamic>>[
        ...rows.map((row) => Map<String, dynamic>.from(row)),
        ...attachments,
        ...localRows,
      ];
      if (!mounted) return;
      setState(() {
        _localRecords = localRows;
        _records = merged;
        _selected = merged.isEmpty ? null : merged.first;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final localRows = await _readLocalRecords();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
        _localRecords = localRows;
        _records = localRows;
        _selected = localRows.isEmpty ? null : localRows.first;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _readLocalRecords() async {
    // Empty localStorageKey means this browser represents canonical Sportoteka
    // entities. Never mix Workspace-only notes into Matches/Trainings/Plans/etc.
    if (widget.localStorageKey.trim().isEmpty) return <Map<String, dynamic>>[];
    var local = <Map<String, dynamic>>[];
    if (widget.localStorageKey.trim().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(widget.localStorageKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            local = decoded.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).where(_isLocal).toList();
          }
        } catch (_) {}
      }
    }

    final server = _serverStorage;
    if (server == null) return local;
    try {
      var snapshot = await server.load();
      final serverNodes = snapshot.nodes.where((n) => n.parentId == widget.serverParentKey && n.kind == WorkspaceFinderNodeKind.note).toList();
      final serverIds = serverNodes.map((e) => e.id).toSet();
      final unsynced = local.where((row) => !serverIds.contains('${row['id'] ?? ''}')).toList();
      for (final row in unsynced) {
        final id = '${row['id'] ?? ''}';
        if (id.isEmpty) continue;
        final node = WorkspaceFinderNode(
          id: id,
          title: '${row['title'] ?? 'Рабочая заметка'}',
          subtitle: '${row['subtitle'] ?? 'Редактируемая заметка'}',
          kind: WorkspaceFinderNodeKind.note,
          parentId: widget.serverParentKey,
          createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
          updatedAt: DateTime.tryParse('${row['updated_at'] ?? ''}'),
        );
        await server.createNode(node);
        await server.saveDocument(clientUid: id, title: node.title, body: '${row['workspace_note'] ?? ''}');
      }
      if (unsynced.isNotEmpty) snapshot = await server.load();
      _serverAvailable = true;
      return snapshot.nodes
          .where((n) => n.parentId == widget.serverParentKey && n.kind == WorkspaceFinderNodeKind.note)
          .map((node) => <String, dynamic>{
                'id': node.id,
                '_workspace_local': true,
                '_workspace_server': true,
                'title': node.title,
                'subtitle': node.subtitle,
                'workspace_note': snapshot.noteBodies[node.id] ?? '',
                'created_at': node.createdAt?.toIso8601String() ?? '',
                'updated_at': node.updatedAt?.toIso8601String() ?? '',
              })
          .toList();
    } catch (_) {
      _serverAvailable = false;
      return local;
    }
  }

  Future<void> _persistLocalRecords() async {
    if (widget.localStorageKey.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.localStorageKey, jsonEncode(_localRecords));
  }

  Future<void> _createLocalRecord() async {
    final now = DateTime.now();
    final row = <String, dynamic>{
      'id': 'workspace_${now.microsecondsSinceEpoch}',
      '_workspace_local': true,
      'title': 'Новая заметка',
      'subtitle': 'Редактируемая заметка',
      'workspace_note': '',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    setState(() {
      _localRecords = <Map<String, dynamic>>[row, ..._localRecords];
      _records = <Map<String, dynamic>>[row, ..._records];
      _selected = row;
    });
    await _persistLocalRecords();
    await _syncCreateLocalRecord(row);
    if (mounted) await _openLocalRecord(row);
  }

  Future<void> _open(Map<String, dynamic> row) async {
    if (_isLocal(row)) {
      await _openLocalRecord(row);
      return;
    }
    if (_isAttachment(row)) {
      final raw = '${row['file_url'] ?? ''}'.trim();
      if (raw.isEmpty) return;
      final url = raw.startsWith('http://') || raw.startsWith('https://')
          ? raw
          : 'https://sportotekaapp.ru/${raw.replaceFirst(RegExp(r'^/+'), '')}';
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    await widget.openRecord(context, row);
  }

  Future<void> _openLocalRecord(Map<String, dynamic> row) async {
    final id = '${row['id'] ?? ''}';
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (routeContext, animation, secondaryAnimation) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: WorkspaceDocumentEditor(
              initialTitle: _titleFor(row),
              initialBody: '${row['workspace_note'] ?? ''}',
              contextLabel: '${widget.contextLabel} · ${widget.sectionTitle}',
              contextName: widget.ownerTitle,
              documentType: 'Рабочая заметка',
              liveBlocksKey: 'entity_local_$id',
              onSave: (title, body) => _updateLocalRecord(id, title, body),
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

  Future<void> _updateLocalRecord(String id, String title, String body) async {
    final now = DateTime.now().toIso8601String();
    Map<String, dynamic> update(Map<String, dynamic> row) {
      if ('${row['id'] ?? ''}' != id) return row;
      return <String, dynamic>{
        ...row,
        'title': title.trim().isEmpty ? 'Рабочая заметка' : title.trim(),
        'subtitle': _preview(body),
        'workspace_note': body,
        'updated_at': now,
      };
    }
    setState(() {
      _localRecords = _localRecords.map(update).toList();
      _records = _records.map(update).toList();
      final matches = _records.where((row) => '${row['id'] ?? ''}' == id);
      if (matches.isNotEmpty) _selected = matches.first;
    });
    await _persistLocalRecords();
    final matches = _localRecords.where((row) => '${row['id'] ?? ''}' == id);
    if (matches.isNotEmpty) await _syncUpdateLocalRecord(matches.first);
  }

  Future<void> _syncCreateLocalRecord(Map<String, dynamic> row) async {
    final server = _serverStorage;
    if (server == null) return;
    try {
      if (!_serverAvailable) {
        await server.load();
        _serverAvailable = true;
      }
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) return;
      final node = WorkspaceFinderNode(
        id: id,
        title: '${row['title'] ?? 'Рабочая заметка'}',
        subtitle: '${row['subtitle'] ?? 'Редактируемая заметка'}',
        kind: WorkspaceFinderNodeKind.note,
        parentId: widget.serverParentKey,
        createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
      );
      await server.createNode(node);
      await server.saveDocument(clientUid: id, title: node.title, body: '${row['workspace_note'] ?? ''}');
    } catch (_) {
      _serverAvailable = false;
    }
  }

  Future<void> _syncUpdateLocalRecord(Map<String, dynamic> row) async {
    final server = _serverStorage;
    if (server == null || !_serverAvailable) return;
    try {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) return;
      final node = WorkspaceFinderNode(
        id: id,
        title: '${row['title'] ?? 'Рабочая заметка'}',
        subtitle: '${row['subtitle'] ?? ''}',
        kind: WorkspaceFinderNodeKind.note,
        parentId: widget.serverParentKey,
        updatedAt: DateTime.now(),
      );
      await server.updateNode(node);
      await server.saveDocument(clientUid: id, title: node.title, body: '${row['workspace_note'] ?? ''}');
    } catch (_) {
      _serverAvailable = false;
    }
  }

  String _preview(String body) {
    final clean = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return 'Редактируемая заметка';
    return clean.length <= 92 ? clean : '${clean.substring(0, 92)}…';
  }

  Future<void> _duplicate(Map<String, dynamic> source) async {
    final now = DateTime.now();
    final body = _isLocal(source)
        ? '${source['workspace_note'] ?? ''}'
        : 'Копия записи из раздела «${widget.sectionTitle}»\n\nИсточник: ${_titleFor(source)}\nДата: ${_friendlyDate(_dateFor(source))}\n\n${_subtitleFor(source)}';
    final copy = <String, dynamic>{
      'id': 'workspace_${now.microsecondsSinceEpoch}',
      '_workspace_local': true,
      'title': 'Копия — ${_titleFor(source)}',
      'subtitle': _preview(body),
      'workspace_note': body,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    setState(() {
      _localRecords = <Map<String, dynamic>>[copy, ..._localRecords];
      _records = <Map<String, dynamic>>[copy, ..._records];
      _selected = copy;
    });
    await _persistLocalRecords();
    await _syncCreateLocalRecord(copy);
    if (mounted) await _openLocalRecord(copy);
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!_isLocal(row) && !_isAttachment(row)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(_isAttachment(row) ? 'Удалить файл?' : 'Удалить заметку?', style: AppTypography.sectionTitle(color: _text)),
        content: Text('«${_titleFor(row)}» будет удалён из раздела.', style: AppTypography.secondary(color: _muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Удалить', style: AppTypography.action(color: const Color(0xFFB42318)))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = '${row['id'] ?? ''}';
    if (_isAttachment(row)) {
      final attachmentId = int.tryParse(id) ?? 0;
      final server = _serverStorage;
      if (attachmentId > 0 && server != null) {
        try {
          await server.deleteAttachment(attachmentId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось удалить файл: $e')));
          }
          return;
        }
      }
      if (mounted) await _load();
      return;
    }
    setState(() {
      _localRecords.removeWhere((item) => '${item['id'] ?? ''}' == id);
      _records.removeWhere((item) => '${item['id'] ?? ''}' == id);
      _selected = _records.isEmpty ? null : _records.first;
    });
    await _persistLocalRecords();
    final server = _serverStorage;
    if (server != null && _serverAvailable) {
      try {
        await server.deleteNode(id);
      } catch (_) {
        _serverAvailable = false;
      }
    }
  }

  Future<void> _pickAttachment() async {
    if (!_canUploadAttachments || _uploadingAttachment) return;
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) return;
    final paths = result.files.map((f) => f.path).whereType<String>().where((p) => p.isNotEmpty).toList();
    if (paths.isEmpty) return;
    await _uploadAttachmentPaths(paths);
  }

  Future<void> _uploadAttachmentPaths(Iterable<String> paths) async {
    if (!_canUploadAttachments || _uploadingAttachment) return;
    final normalized = paths.where((path) => path.trim().isNotEmpty).toList();
    if (normalized.isEmpty) return;
    setState(() => _uploadingAttachment = true);
    try {
      if (widget.externalUploadPaths != null) {
        await widget.externalUploadPaths!(normalized);
      } else {
        final server = _serverStorage;
        if (server == null) return;
        for (final path in normalized) {
          final name = path.split(RegExp(r'[\/]')).last;
          await server.uploadAttachment(
            filePath: path,
            entityType: widget.attachmentEntityType,
            entityId: widget.attachmentEntityId,
            sectionKey: widget.attachmentSectionKey,
            title: name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
          );
        }
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки файла: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _properties(Map<String, dynamic> row) async {
    final mobile = MediaQuery.sizeOf(context).width < 920;
    if (!mobile) {
      setState(() => _selected = row);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: _EntityProperties(
            title: _titleFor(row),
            iconKind: widget.iconKind,
            properties: _propertiesFor(row),
            onOpen: () async {
              Navigator.of(sheetContext).pop();
              await _open(row);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _menu(Map<String, dynamic> row, Offset position) async {
    final action = await showMenu<String>(
      context: context,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'open', child: Text(_isLocal(row) ? 'Редактировать' : 'Открыть', style: AppTypography.menuTitle(color: _text))),
        if (_isLocal(row)) PopupMenuItem<String>(value: 'copy', child: Text('Создать копию', style: AppTypography.menuTitle(color: _text))),
        PopupMenuItem<String>(value: 'properties', child: Text('Свойства', style: AppTypography.menuTitle(color: _text))),
        if (_isLocal(row) || _isAttachment(row)) const PopupMenuDivider(),
        if (_isLocal(row) || _isAttachment(row)) PopupMenuItem<String>(value: 'delete', child: Text('Удалить', style: AppTypography.menuTitle(color: const Color(0xFFB42318)))),
      ],
    );
    if (!mounted) return;
    if (action == 'open') await _open(row);
    if (action == 'copy') await _duplicate(row);
    if (action == 'properties') await _properties(row);
    if (action == 'delete') await _delete(row);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        final inspector = constraints.maxWidth >= 920;
        return ColoredBox(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                height: mobile ? 58 : 64,
                padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 12),
                child: Row(
                  children: [
                    if (widget.showBackButton) ...[
                      IconButton(
                        tooltip: 'Назад',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.back, size: 20),
                      ),
                      const SizedBox(width: 3),
                    ],
                    SportotekaWorkspaceIcon(kind: widget.iconKind, size: mobile ? 31 : 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.sectionTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.screenTitle(color: _text)),
                          Text(widget.ownerTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.secondary(color: _muted)),
                        ],
                      ),
                    ),
                    if (widget.localStorageKey.trim().isNotEmpty)
                      mobile
                          ? IconButton(
                              tooltip: 'Новая заметка',
                              onPressed: _createLocalRecord,
                              icon: const Icon(Icons.add_rounded, color: _green, size: 21),
                            )
                          : FilledButton.icon(
                              onPressed: _createLocalRecord,
                              style: FilledButton.styleFrom(backgroundColor: _green, elevation: 0),
                              icon: const Icon(Icons.add_rounded, size: 17),
                              label: Text('Новая заметка', style: AppTypography.actionStrong(color: Colors.white)),
                            ),
                    if (_canUploadAttachments) ...[
                      const SizedBox(width: 6),
                      mobile
                          ? IconButton(
                              tooltip: 'Добавить файл',
                              onPressed: _uploadingAttachment ? null : _pickAttachment,
                              icon: const Icon(Icons.upload_file_rounded, color: _green, size: 20),
                            )
                          : OutlinedButton.icon(
                              onPressed: _uploadingAttachment ? null : _pickAttachment,
                              icon: const Icon(Icons.upload_file_rounded, size: 17),
                              label: Text(_uploadingAttachment ? 'Загрузка…' : 'Добавить файл', style: AppTypography.actionStrong(color: _green)),
                            ),
                    ],
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Обновить',
                      onPressed: _load,
                      icon: const SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.refresh, size: 19),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _line),
              Container(
                padding: EdgeInsets.fromLTRB(mobile ? 10 : 14, 9, mobile ? 10 : 14, 9),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _search,
                          style: AppTypography.formText(color: _text),
                          decoration: InputDecoration(
                            hintText: 'Поиск по разделу',
                            hintStyle: AppTypography.formHint(color: _muted),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(9),
                              child: SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.search, size: 17),
                            ),
                            filled: true,
                            fillColor: _soft,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _newestFirst = !_newestFirst),
                      child: Text(_newestFirst ? 'Сначала новые' : 'Сначала старые', style: AppTypography.action(color: _muted)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _line),
              if (_error != null)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF3F1),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(_error!, style: AppTypography.caption(color: const Color(0xFFB42318))),
                ),
              Expanded(
                child: DropTarget(
                  onDragEntered: (_) {
                    if (_canUploadAttachments && mounted) setState(() => _draggingAttachment = true);
                  },
                  onDragExited: (_) {
                    if (mounted) setState(() => _draggingAttachment = false);
                  },
                  onDragDone: (details) async {
                    if (mounted) setState(() => _draggingAttachment = false);
                    if (!_canUploadAttachments) return;
                    final paths = details.files.map((XFile f) => f.path).where((p) => p.isNotEmpty).toList();
                    if (paths.isNotEmpty) await _uploadAttachmentPaths(paths);
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Row(
                          children: [
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator(color: _green))
                          : _visible.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SportotekaWorkspaceIcon(kind: widget.iconKind, size: 48, color: const Color(0xFF6E7A73)),
                                        const SizedBox(height: 12),
                                        Text(widget.emptyText, textAlign: TextAlign.center, style: AppTypography.secondary(color: _muted)),
                                        if (widget.localStorageKey.trim().isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          FilledButton(
                                            onPressed: _createLocalRecord,
                                            style: FilledButton.styleFrom(backgroundColor: _green, elevation: 0),
                                            child: Text('Новая заметка', style: AppTypography.actionStrong(color: Colors.white)),
                                          ),
                                        ],
                                        if (_canUploadAttachments) ...[
                                          const SizedBox(height: 8),
                                          OutlinedButton(
                                            onPressed: _uploadingAttachment ? null : _pickAttachment,
                                            child: Text(_uploadingAttachment ? 'Загрузка…' : 'Добавить файл', style: AppTypography.actionStrong(color: _green)),
                                          ),
                                          const SizedBox(height: 7),
                                          Text('Можно перетащить файл из Finder/Проводника прямо сюда.', textAlign: TextAlign.center, style: AppTypography.caption(color: _muted)),
                                        ],
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 20),
                                  itemCount: _visible.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 58, color: _line),
                                  itemBuilder: (_, index) {
                                    final row = _visible[index];
                                    final selected = identical(_selected, row) || (_selected != null && _sameRecord(_selected!, row));
                                    final title = _titleFor(row);
                                    final subtitle = _subtitleFor(row);
                                    final date = _friendlyDate(_dateFor(row));
                                    final tile = Material(
                                      color: selected ? const Color(0xFFF1F7F4) : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () {
                                          if (mobile) {
                                            _open(row);
                                          } else {
                                            setState(() => _selected = row);
                                          }
                                        },
                                        onDoubleTap: mobile ? null : () => _open(row),
                                        onLongPress: () => _properties(row),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(color: const Color(0xFFF1F7F4), borderRadius: BorderRadius.circular(11)),
                                                alignment: Alignment.center,
                                                child: SportotekaWorkspaceIcon(kind: widget.iconKind, size: 25),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _text)),
                                                    if (subtitle.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.secondary(color: _muted)),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (date.isNotEmpty)
                                                SizedBox(width: mobile ? 76 : 104, child: Text(date, textAlign: TextAlign.right, style: AppTypography.captionMedium(color: _text))),
                                              const SizedBox(width: 4),
                                              PopupMenuButton<String>(
                                                tooltip: 'Действия',
                                                color: Colors.white,
                                                surfaceTintColor: Colors.white,
                                                onSelected: (action) async {
                                                  if (action == 'open') await _open(row);
                                                  if (action == 'copy') await _duplicate(row);
                                                  if (action == 'properties') await _properties(row);
                                                  if (action == 'delete') await _delete(row);
                                                },
                                                itemBuilder: (_) => [
                                                  PopupMenuItem(value: 'open', child: Text(_isLocal(row) ? 'Редактировать' : 'Открыть', style: AppTypography.menuTitle())),
                                                  if (_isLocal(row)) PopupMenuItem(value: 'copy', child: Text('Создать копию', style: AppTypography.menuTitle())),
                                                  PopupMenuItem(value: 'properties', child: Text('Свойства', style: AppTypography.menuTitle())),
                                                  if (_isLocal(row) || _isAttachment(row)) const PopupMenuDivider(),
                                                  if (_isLocal(row) || _isAttachment(row)) PopupMenuItem(value: 'delete', child: Text('Удалить', style: AppTypography.menuTitle(color: const Color(0xFFB42318)))),
                                                ],
                                                icon: const Icon(Icons.more_horiz_rounded, size: 19),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onSecondaryTapDown: (d) => _menu(row, d.globalPosition),
                                      child: tile,
                                    );
                                  },
                                ),
                    ),
                    if (inspector) ...[
                      const VerticalDivider(width: 1, color: _line),
                      SizedBox(
                        width: 280,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _selected == null
                              ? Center(child: Text('Выберите запись', style: AppTypography.secondary(color: _muted)))
                              : _EntityProperties(
                                  title: _titleFor(_selected!),
                                  iconKind: widget.iconKind,
                                  properties: _propertiesFor(_selected!),
                                  onOpen: () => _open(_selected!),
                                ),
                        ),
                      ),
                    ],
                          ],
                        ),
                      ),
                      if (_draggingAttachment && _canUploadAttachments)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              color: _green.withOpacity(.07),
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _green),
                                ),
                                child: Text('Отпустите файл — он будет добавлен в этот раздел', style: AppTypography.itemTitle(color: _green)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _sameRecord(Map<String, dynamic> a, Map<String, dynamic> b) {
    for (final key in const <String>['id', 'match_id', 'event_id', 'session_id', 'plan_id', 'record_id', 'date', 'created_at']) {
      final av = '${a[key] ?? ''}';
      final bv = '${b[key] ?? ''}';
      if (av.isNotEmpty && bv.isNotEmpty && av == bv) return true;
    }
    return identical(a, b);
  }

  String _friendlyDate(String raw) {
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }
}

class _EntityProperties extends StatelessWidget {
  const _EntityProperties({required this.title, required this.iconKind, required this.properties, required this.onOpen});
  final String title;
  final SportotekaWorkspaceIconKind iconKind;
  final List<WorkspaceEntityProperty> properties;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    const text = Color(0xFF101814);
    const muted = Color(0xFF758079);
    const green = Color(0xFF0B8F55);
    final visible = properties.where((p) => p.value.trim().isNotEmpty && p.value.trim() != '—').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SportotekaWorkspaceIcon(kind: iconKind, size: 34),
            const SizedBox(width: 10),
            Expanded(child: Text('Свойства', style: AppTypography.sectionTitle(color: text))),
          ],
        ),
        const SizedBox(height: 14),
        Text(title, style: AppTypography.itemTitle(color: text)),
        const SizedBox(height: 14),
        for (final prop in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prop.label, style: AppTypography.caption(color: muted)),
                const SizedBox(height: 2),
                Text(prop.value, maxLines: 4, overflow: TextOverflow.ellipsis, style: AppTypography.secondaryMedium(color: text)),
              ],
            ),
          ),
        const SizedBox(height: 6),
        FilledButton(
          onPressed: onOpen,
          style: FilledButton.styleFrom(backgroundColor: green, elevation: 0),
          child: Text('Открыть', style: AppTypography.actionStrong(color: Colors.white)),
        ),
      ],
    );
  }
}

class WorkspaceEntityRecordDocument extends StatefulWidget {
  const WorkspaceEntityRecordDocument({
    super.key,
    required this.ownerTitle,
    required this.sectionTitle,
    required this.title,
    required this.iconKind,
    required this.record,
    required this.properties,
    required this.noteKey,
    this.legacyNoteKeys = const <String>[],
    this.entityType = '',
    this.entityId = '',
    this.onEdit,
    this.onRefresh,
    this.fileUrl = '',
    this.clubId = 0,
    this.serverParentKey = '',
    this.onClose,
  });

  final String ownerTitle;
  final String sectionTitle;
  final String title;
  final SportotekaWorkspaceIconKind iconKind;
  final Map<String, dynamic> record;
  final List<WorkspaceEntityProperty> properties;
  final String noteKey;
  final List<String> legacyNoteKeys;
  final String entityType;
  final String entityId;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onRefresh;
  final String fileUrl;
  final int clubId;
  final String serverParentKey;
  final VoidCallback? onClose;

  @override
  State<WorkspaceEntityRecordDocument> createState() => _WorkspaceEntityRecordDocumentState();
}

class _WorkspaceEntityRecordDocumentState extends State<WorkspaceEntityRecordDocument> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);
  String _note = '';
  bool _busy = false;
  bool _detailsOpen = false;
  WorkspaceServerStorage? _serverStorage;
  bool _serverAvailable = false;

  @override
  void initState() {
    super.initState();
    if (widget.clubId > 0 && widget.serverParentKey.trim().isNotEmpty) {
      _serverStorage = WorkspaceServerStorage(clubId: widget.clubId);
    }
    _loadNote();
  }

  Future<void> _loadNote() async {
    final prefs = await SharedPreferences.getInstance();
    var note = prefs.getString(widget.noteKey) ?? '';
    String migratedFrom = '';
    if (note.isEmpty) {
      for (final legacyKey in widget.legacyNoteKeys) {
        final candidate = prefs.getString(legacyKey) ?? '';
        if (candidate.isNotEmpty) {
          note = candidate;
          migratedFrom = legacyKey;
          break;
        }
      }
    }

    final server = _serverStorage;
    if (server != null) {
      try {
        var snapshot = await server.load();
        final serverBody = snapshot.noteBodies[widget.noteKey];
        if (serverBody != null && serverBody.isNotEmpty) {
          note = serverBody;
        } else if (note.isEmpty) {
          for (final legacyKey in widget.legacyNoteKeys) {
            final candidate = snapshot.noteBodies[legacyKey];
            if (candidate != null && candidate.isNotEmpty) {
              note = candidate;
              migratedFrom = legacyKey;
              break;
            }
          }
        }

        final exists = snapshot.nodes.any((node) => node.id == widget.noteKey);
        if (!exists && note.isNotEmpty) {
          final node = WorkspaceFinderNode(
            id: widget.noteKey,
            title: widget.title,
            subtitle: widget.sectionTitle,
            kind: WorkspaceFinderNodeKind.note,
            parentId: widget.serverParentKey,
            createdAt: DateTime.now(),
          );
          await server.createNode(node);
          await server.saveDocument(clientUid: node.id, title: node.title, body: note);
          snapshot = await server.load();
        }
        if (widget.entityType.isNotEmpty && widget.entityId.isNotEmpty) {
          await server.linkDocument(
            documentKey: widget.noteKey,
            entityType: widget.entityType,
            entityId: widget.entityId,
            sectionKey: widget.sectionTitle,
            title: widget.title,
          );
        }
        final canonicalBody = snapshot.noteBodies[widget.noteKey];
        if (canonicalBody != null) note = canonicalBody;
        _serverAvailable = true;
      } catch (_) {
        _serverAvailable = false;
      }
    }
    if (note.isNotEmpty) {
      await prefs.setString(widget.noteKey, note);
      if (migratedFrom.isNotEmpty && migratedFrom != widget.noteKey) {
        // Keep the legacy key as a fallback for one release, but the canonical
        // key becomes authoritative immediately.
      }
    }
    if (!mounted) return;
    setState(() => _note = note);
  }

  Future<void> _saveNote(String title, String body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.noteKey, body);
    final server = _serverStorage;
    if (server != null) {
      try {
        final node = WorkspaceFinderNode(
          id: widget.noteKey,
          title: widget.title,
          subtitle: widget.sectionTitle,
          kind: WorkspaceFinderNodeKind.note,
          parentId: widget.serverParentKey,
          updatedAt: DateTime.now(),
        );
        if (_serverAvailable) {
          await server.updateNode(node);
        } else {
          await server.createNode(node);
          _serverAvailable = true;
        }
        final savedTitle = title.trim().isEmpty ? node.title : title.trim();
        await server.saveDocument(clientUid: node.id, title: savedTitle, body: body);
        if (widget.entityType.isNotEmpty && widget.entityId.isNotEmpty) {
          await server.linkDocument(
            documentKey: widget.noteKey,
            entityType: widget.entityType,
            entityId: widget.entityId,
            sectionKey: widget.sectionTitle,
            title: savedTitle,
          );
        }
      } catch (_) {
        _serverAvailable = false;
      }
    }
    if (mounted) setState(() => _note = body);
    await widget.onRefresh?.call();
  }

  Future<void> _edit() async {
    if (widget.onEdit == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onEdit!.call();
      await widget.onRefresh?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAttachment() async {
    final uri = Uri.tryParse(widget.fileUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.properties.where((p) => p.value.trim().isNotEmpty && p.value.trim() != '—').toList();
    final headline = visible.take(4).toList();
    final rest = visible.skip(4).toList();
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
                  icon: const SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.back, size: 20),
                ),
                const SizedBox(width: 3),
                SportotekaWorkspaceIcon(kind: widget.iconKind, size: 31),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${widget.ownerTitle} — ${widget.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.screenTitle(color: _text)),
                      Text(widget.sectionTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _muted)),
                    ],
                  ),
                ),
                if (widget.onEdit != null)
                  TextButton(onPressed: _busy ? null : _edit, child: Text(_busy ? 'Сохранение…' : 'Редактировать', style: AppTypography.actionStrong(color: _green))),
                if (widget.fileUrl.isNotEmpty)
                  TextButton(onPressed: _openAttachment, child: Text('Вложение', style: AppTypography.actionStrong(color: _green))),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          if (headline.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 9),
              color: const Color(0xFFFAFBFA),
              child: Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  for (final p in headline)
                    _RibbonProperty(label: p.label, value: p.value),
                  if (rest.isNotEmpty)
                    InkWell(
                      onTap: () => setState(() => _detailsOpen = !_detailsOpen),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(_detailsOpen ? 'Скрыть данные' : 'Все данные', style: AppTypography.action(color: _green)),
                      ),
                    ),
                ],
              ),
            ),
          if (_detailsOpen && rest.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
              child: Wrap(
                spacing: 22,
                runSpacing: 10,
                children: [
                  for (final p in rest)
                    SizedBox(width: 230, child: _RibbonProperty(label: p.label, value: p.value, multiline: true)),
                ],
              ),
            )
          else
            const Divider(height: 1, color: _line),
          Expanded(
            child: WorkspaceDocumentEditor(
              key: ValueKey(widget.noteKey),
              initialTitle: '${widget.title} — ${widget.ownerTitle}',
              initialBody: _note,
              titleReadOnly: true,
              contextLabel: widget.sectionTitle,
              contextName: widget.ownerTitle,
              documentType: 'Рабочая заметка',
              liveBlocksKey: widget.noteKey,
              onSave: _saveNote,
            ),
          ),
        ],
      ),
    );
  }
}

class _RibbonProperty extends StatelessWidget {
  const _RibbonProperty({required this.label, required this.value, this.multiline = false});
  final String label;
  final String value;
  final bool multiline;
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: multiline ? 230 : 190),
      child: RichText(
        maxLines: multiline ? 4 : 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: AppTypography.secondary(color: const Color(0xFF101814)),
          children: [
            TextSpan(text: '$label  ', style: AppTypography.caption(color: const Color(0xFF758079))),
            TextSpan(text: value, style: AppTypography.secondaryMedium(color: const Color(0xFF101814))),
          ],
        ),
      ),
    );
  }
}
