import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_server_storage.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_document_editor.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_window_manager.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:sportoteka/presentation/plans/plan_detail_screen.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'training_lifecycle_api.dart';

class TrainingMaterialsPanel extends StatefulWidget {
  final String apiBase;
  final int clubId;
  final int teamId;
  final int eventId;
  final int currentUserId;

  const TrainingMaterialsPanel({
    super.key,
    required this.apiBase,
    required this.clubId,
    required this.teamId,
    required this.eventId,
    this.currentUserId = 0,
  });

  @override
  State<TrainingMaterialsPanel> createState() => _TrainingMaterialsPanelState();
}

class _TrainingMaterialsPanelState extends State<TrainingMaterialsPanel> {
  static const _green = Color(0xFF14915D);
  static const _greenDark = Color(0xFF0F7B50);
  static const _greenSoft = Color(0xFFF7FBF8);
  static const _soft = Color(0xFFF8FAF9);
  static const _line = Color(0xFFE5ECE8);
  static const _text = Color(0xFF0B0F14);
  static const _muted = Color(0xFF667085);

  bool loading = true;
  bool uploading = false;
  bool linking = false;
  bool planPickerOpen = false;
  String? error;
  int linkedPlanId = 0;
  List<Map<String, dynamic>> plans = [];
  List<Map<String, dynamic>> attachments = [];
  List<Map<String, dynamic>> linkedDocuments = [];

  final List<OverlayEntry> _floatingWindows = <OverlayEntry>[];
  int _floatingWindowSerial = 0;

  WorkspaceServerStorage get _storage => WorkspaceServerStorage(
        clubId: widget.clubId,
        userId: widget.currentUserId,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final entry in List<OverlayEntry>.from(_floatingWindows)) {
      entry.remove();
    }
    _floatingWindows.clear();
    super.dispose();
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      final i = body.indexOf('{');
      if (i >= 0) {
        try {
          return jsonDecode(body.substring(i));
        } catch (_) {}
      }
      return <String, dynamic>{};
    }
  }

  List<Map<String, dynamic>> _list(dynamic data, List<String> keys) {
    dynamic raw = data;
    if (data is Map) {
      for (final key in keys) {
        if (data[key] is List) {
          raw = data[key];
          break;
        }
      }
    }
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  int _id(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;

  String _planTitle(Map<String, dynamic> p) {
    final value = '${p['theme'] ?? p['title'] ?? p['name'] ?? p['plan_title'] ?? ''}'.trim();
    return value.isEmpty ? 'План тренировки' : value;
  }

  String _firstText(Map<String, dynamic> p, List<String> keys) {
    for (final key in keys) {
      final value = '${p[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  String _personName(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final full = _firstText(map, const [
        'full_name',
        'fullName',
        'name',
        'display_name',
        'username',
      ]);
      if (full.isNotEmpty) return full;
      final first = _firstText(map, const ['first_name', 'firstName']);
      final last = _firstText(map, const ['last_name', 'lastName']);
      return '$first $last'.trim();
    }
    final value = '${raw ?? ''}'.trim();
    return value == 'null' ? '' : value;
  }

  String _planAuthor(Map<String, dynamic> p) {
    final direct = _firstText(p, const [
      'created_by_name',
      'creator_name',
      'author_name',
      'coach_name',
      'user_name',
      'created_by_label',
    ]);
    if (direct.isNotEmpty) return direct;

    for (final key in const ['creator', 'author', 'coach', 'created_by_user', 'user']) {
      final name = _personName(p[key]);
      if (name.isNotEmpty) return name;
    }

    final first = _firstText(p, const ['creator_first_name', 'author_first_name', 'coach_first_name']);
    final last = _firstText(p, const ['creator_last_name', 'author_last_name', 'coach_last_name']);
    final combined = '$first $last'.trim();
    return combined.isEmpty ? 'Автор не указан' : combined;
  }

  String _planDescription(Map<String, dynamic> p) {
    final value = _firstText(p, const [
      'short_description',
      'description',
      'summary',
      'goal',
      'objective',
      'objectives',
      'notes',
      'comment',
    ]);
    return value;
  }

  String _planDate(Map<String, dynamic> p) {
    final raw = _firstText(p, const [
      'created_at',
      'createdAt',
      'plan_date',
      'date',
      'created',
      'updated_at',
    ]);
    if (raw.isEmpty) return 'Дата не указана';

    DateTime? dt;
    try {
      dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
    } catch (_) {}
    if (dt == null) {
      if (raw.length >= 10 && raw[4] == '-' && raw[7] == '-') {
        return '${raw.substring(8, 10)}.${raw.substring(5, 7)}.${raw.substring(0, 4)}';
      }
      return raw;
    }
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  String _planMeta(Map<String, dynamic> p) {
    return '${_planDate(p)} · ${_planAuthor(p)}';
  }

  String _fileTitle(Map<String, dynamic> row) {
    final value = '${row['title'] ?? row['original_name'] ?? row['file_name'] ?? row['name'] ?? 'Документ'}'.trim();
    return value.isEmpty ? 'Документ' : value;
  }

  String _fileUrl(Map<String, dynamic> row) {
    for (final key in const ['url', 'file_url', 'download_url', 'path']) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.startsWith('http://') || value.startsWith('https://')) return value;
      if (value.startsWith('/')) return 'https://sportotekaapp.ru$value';
    }
    return '';
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _loadPlans(),
        _loadLinkedPlan(),
        _storage.listAttachments(
          entityType: 'training',
          entityId: widget.eventId,
          sectionKey: 'documents',
        ),
        _storage.listEntityDocuments(
          entityType: 'training',
          entityId: '${widget.eventId}',
        ),
      ]);

      if (!mounted) return;
      setState(() {
        plans = results[0] as List<Map<String, dynamic>>;
        linkedPlanId = results[1] as int;
        attachments = results[2] as List<Map<String, dynamic>>;
        linkedDocuments = results[3] as List<Map<String, dynamic>>;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadPlans() async {
    try {
      final uri = Uri.parse('${widget.apiBase}/get_latest_training_plans.php').replace(
        queryParameters: <String, String>{
          'team_id': '${widget.teamId}',
          'club_id': '${widget.clubId}',
          'limit': '30',
        },
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      return _list(_decode(r.body), const ['plans', 'items', 'data', 'result']);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<int> _loadLinkedPlan() async {
    try {
      final uri = Uri.parse('${widget.apiBase}/training_plan_link.php').replace(
        queryParameters: <String, String>{'event_id': '${widget.eventId}'},
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode < 200 || r.statusCode >= 300) return 0;
      final data = _decode(r.body);
      if (data is! Map || data['success'] == false) return 0;
      return _id(data['plan_id'] ?? (data['link'] is Map ? data['link']['plan_id'] : 0));
    } catch (_) {
      return 0;
    }
  }

  Future<void> _linkPlan(int planId) async {
    if (linking || planId <= 0) return;
    setState(() => linking = true);
    try {
      final r = await http.post(
        Uri.parse('${widget.apiBase}/training_plan_link.php'),
        body: <String, String>{
          'event_id': '${widget.eventId}',
          'team_id': '${widget.teamId}',
          'club_id': '${widget.clubId}',
          'plan_id': '$planId',
          if (widget.currentUserId > 0) 'linked_by': '${widget.currentUserId}',
        },
      ).timeout(const Duration(seconds: 10));
      final data = _decode(r.body);
      if (r.statusCode < 200 || r.statusCode >= 300 || data is! Map || data['success'] == false) {
        throw Exception(data is Map ? '${data['message'] ?? 'Не удалось привязать план'}' : 'Не удалось привязать план');
      }
      if (widget.currentUserId > 0) {
        final match = plans.where((p) => _id(p['id'] ?? p['plan_id']) == planId).toList();
        try {
          await TrainingLifecycleApi(
            apiBase: widget.apiBase,
            clubId: widget.clubId,
            teamId: widget.teamId,
            eventId: widget.eventId,
          ).recordPlanLinked(
            userId: widget.currentUserId,
            planId: planId,
            planTitle: match.isEmpty ? '' : _planTitle(match.first),
          );
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        linkedPlanId = planId;
        planPickerOpen = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('План привязан к тренировке')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => linking = false);
    }
  }

  Future<void> _upload() async {
    if (uploading) return;
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) return;
    final paths = result.files.map((f) => f.path).whereType<String>().where((p) => p.trim().isNotEmpty).toList();
    if (paths.isEmpty) return;

    setState(() => uploading = true);
    try {
      for (final path in paths) {
        final name = path.split(RegExp(r'[\\/]')).last;
        await _storage.uploadAttachment(
          filePath: path,
          entityType: 'training',
          entityId: widget.eventId,
          sectionKey: 'documents',
          title: name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
        );
        if (widget.currentUserId > 0) {
          try {
            await TrainingLifecycleApi(
              apiBase: widget.apiBase,
              clubId: widget.clubId,
              teamId: widget.teamId,
              eventId: widget.eventId,
            ).recordDocumentAdded(
              userId: widget.currentUserId,
              fileName: name,
            );
          } catch (_) {}
        }
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Документы добавлены в тренировку и Sportoteka OS')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Map<String, dynamic> _planDetailArgs(Map<String, dynamic> plan) {
    final planId = _id(plan['id'] ?? plan['plan_id']);
    final author = _planAuthor(plan);
    final teamName = _firstText(plan, const ['team_name', 'teamName', '_team_name']);
    final clubName = _firstText(plan, const ['club_name', 'clubName']);
    final folderName = _firstText(plan, const ['folder_title', 'folder_name', 'folderName']);
    final folderId = _id(plan['folder_id'] ?? plan['folderId']);

    return <String, dynamic>{
      'planId': planId,
      'plan_id': planId,
      'clubId': widget.clubId,
      'club_id': widget.clubId,
      'clubName': clubName.isEmpty ? 'Клуб' : clubName,
      'club_name': clubName.isEmpty ? 'Клуб' : clubName,
      'teamId': widget.teamId,
      'team_id': widget.teamId,
      'teamName': teamName.isEmpty ? 'Команда' : teamName,
      'team_name': teamName.isEmpty ? 'Команда' : teamName,
      'folderId': folderId,
      'folder_id': folderId,
      'folderName': folderName,
      'folder_name': folderName,
      'trainerName': author == 'Автор не указан' ? 'Тренер' : author,
      'trainer_name': author == 'Автор не указан' ? 'Тренер' : author,
    };
  }

  void _showFloatingWindow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Size preferredSize = const Size(880, 650),
  }) {
    if (!mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final cascade = _floatingWindowSerial++;
    late OverlayEntry entry;
    var closed = false;

    void close() {
      if (closed) return;
      closed = true;
      _floatingWindows.remove(entry);
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => _TrainingFloatingWindow(
        title: title,
        subtitle: subtitle,
        icon: icon,
        cascadeIndex: cascade,
        preferredSize: preferredSize,
        onClose: close,
        child: child,
      ),
    );

    _floatingWindows.add(entry);
    overlay.insert(entry);
  }

  void _openPlan(Map<String, dynamic> plan) {
    final planId = _id(plan['id'] ?? plan['plan_id']);
    if (planId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У плана отсутствует ID для открытия')),
      );
      return;
    }

    final args = _planDetailArgs(plan);
    showWorkspaceManagedWindow(
      context,
      id: 'training-plan:$planId',
      title: _planTitle(plan),
      subtitle: '${_planMeta(plan)} · План-конспект',
      iconKind: SportotekaWorkspaceIconKind.plans,
      preferredSize: const Size(1040, 720),
      builder: (closeWindow) => PlanDetailScreen(
        embedded: true,
        workspaceWindowMode: true,
        initialArgs: args,
        onClose: closeWindow,
        onSaved: (_) {
          if (mounted) _load();
        },
      ),
    );
  }


  Future<void> _saveWorkspaceDocument({
    required String clientUid,
    required String title,
    required String body,
  }) async {
    final safeUid = clientUid.trim();
    if (safeUid.isEmpty) throw Exception('Не найден ключ документа Workspace');

    final response = await http
        .post(
          Uri.parse('https://sportotekaapp.ru/api/workspace/index.php'),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(<String, dynamic>{
            'action': 'save_document',
            'club_id': widget.clubId,
            'user_id': widget.currentUserId,
            'client_uid': safeUid,
            'title': title.trim().isEmpty ? 'Без названия' : title.trim(),
            'body': body,
            'format': 'sportoteka-richtext-v1',
          }),
        )
        .timeout(const Duration(seconds: 15));

    final data = _decode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data is! Map ||
        data['success'] != true) {
      final message = data is Map ? '${data['message'] ?? 'Не удалось сохранить документ'}' : 'Не удалось сохранить документ';
      throw Exception(message);
    }

    if (mounted) {
      await _load();
    }
  }

  Widget _floatingFileViewer(Map<String, dynamic> row) {
    final url = _fileUrl(row);
    final title = _fileTitle(row);
    final ext = _extensionFromRow(row);
    final lower = ext.toLowerCase();
    final isPdf = lower == 'pdf';
    final isImage = const {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'}.contains(lower);
    final isText = const {'txt', 'md', 'json', 'csv', 'log', 'xml'}.contains(lower);

    if (isPdf) {
      return ColoredBox(
        color: Colors.white,
        child: SfPdfViewer.network(
          url,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          enableDoubleTapZooming: true,
        ),
      );
    }

    if (isImage) {
      return ColoredBox(
        color: const Color(0xFFF8FAF9),
        child: InteractiveViewer(
          minScale: .7,
          maxScale: 5,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _green));
              },
              errorBuilder: (_, __, ___) => _previewUnsupported(title, ext),
            ),
          ),
        ),
      );
    }

    if (isText) {
      return FutureBuilder<String>(
        future: _loadTextPreview(url),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _green));
          }
          return ColoredBox(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: SelectableText(
                snapshot.data ?? 'Документ пуст.',
                style: AppTypography.body(color: _text),
              ),
            ),
          );
        },
      );
    }

    return _previewUnsupported(title, ext);
  }

  String _absoluteWorkspaceFileUrl(Map<String, dynamic> row) {
    for (final key in const ['url', 'file_url', 'download_url', 'path', 'file']) {
      var value = '${row[key] ?? ''}'.trim();
      if (value.isEmpty || value == 'null') continue;
      if (value.startsWith('http://') || value.startsWith('https://')) return value;
      while (value.startsWith('../')) value = value.substring(3);
      while (value.startsWith('./')) value = value.substring(2);
      while (value.startsWith('/')) value = value.substring(1);
      return 'https://sportotekaapp.ru/$value';
    }
    return '';
  }

  Future<String?> _uploadDocumentImage(String filePath) async {
    final attachment = await _storage.uploadAttachment(
      filePath: filePath,
      entityType: 'training',
      entityId: widget.eventId,
      sectionKey: 'document_images',
      title: 'Изображение документа',
    );
    final url = _absoluteWorkspaceFileUrl(attachment);
    if (url.isEmpty) {
      throw Exception('Сервер не вернул ссылку на изображение');
    }
    return url;
  }

  Future<void> _openWorkspaceDocument(Map<String, dynamic> row) async {
    final documentKey = _firstText(
      row,
      const ['document_key', 'client_uid', 'documentKey'],
    );
    if (documentKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не найден ключ документа Sportoteka OS')),
      );
      return;
    }

    Map<String, dynamic> latest = Map<String, dynamic>.from(row);
    try {
      final server = await _storage.loadDocument(clientUid: documentKey);
      if (server != null) latest = <String, dynamic>{...latest, ...server};
    } catch (_) {}
    if (!mounted) return;

    final initialTitle = _firstText(latest, const ['title', 'name']).isEmpty
        ? _fileTitle(row)
        : _firstText(latest, const ['title', 'name']);
    final initialBody = '${latest['body'] ?? row['body'] ?? ''}';

    showWorkspaceManagedWindow(
      context,
      id: 'workspace-document:$documentKey',
      title: initialTitle,
      subtitle: 'Sportoteka OS · Документ тренировки',
      iconKind: SportotekaWorkspaceIconKind.document,
      preferredSize: const Size(960, 720),
      builder: (closeWindow) => WorkspaceDocumentEditor(
        initialTitle: initialTitle,
        initialBody: initialBody,
        contextLabel: 'Тренировка',
        contextName: 'Команда ${widget.teamId}',
        documentType: 'Документ',
        liveBlocksKey: documentKey,
        aiDocumentKey: documentKey,
        aiClubId: widget.clubId,
        aiUserId: widget.currentUserId,
        aiTeamId: widget.teamId,
        aiExtraPayload: <String, dynamic>{
          'workspace_section': 'trainings',
          'workspace_entity_type': 'training',
          'workspace_entity_id': widget.eventId,
        },
        onUploadImage: _uploadDocumentImage,
        onClose: closeWindow,
        onSave: (title, body) async {
          final safeTitle =
              title.trim().isEmpty ? 'Без названия' : title.trim();

          // list_entity_documents may contain a legacy/canonical document_key
          // whose Workspace node has not yet been created (or was deleted).
          // save_document alone then returns 404 "Workspace node not found".
          //
          // Use the same self-healing upsert flow as the rest of Sportoteka OS:
          // update node -> create node if missing -> save body -> restore link
          // to this training.
          final node = WorkspaceFinderNode(
            id: documentKey,
            title: safeTitle,
            subtitle: 'Документ тренировки',
            kind: WorkspaceFinderNodeKind.note,
            moduleKey: 'trainings',
            parentId: 'entity:training:${widget.eventId}',
            payload: <String, dynamic>{
              'club_id': widget.clubId,
              'team_id': widget.teamId,
              'entity_type': 'training',
              'entity_id': widget.eventId,
            },
            updatedAt: DateTime.now(),
          );

          await _storage.syncNodeDocument(
            node: node,
            body: body,
          );

          // Keep the Workspace document attached to the same calendar training.
          await _storage.linkDocument(
            documentKey: documentKey,
            entityType: 'training',
            entityId: '${widget.eventId}',
            sectionKey: 'documents',
            title: safeTitle,
          );

          // Keep autosave silent: reloading the whole materials panel here
          // showed a full loading state after every pause in typing. The editor
          // already contains the saved text, so no immediate reload is needed.
        },
      ),
    );
  }

  void _openFile(Map<String, dynamic> row, {required bool linked}) {
    if (linked) {
      _openWorkspaceDocument(row);
      return;
    }

    final raw = _fileUrl(row);
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У документа нет ссылки для просмотра')),
      );
      return;
    }

    showWorkspaceManagedWindow(
      context,
      id: 'training-file:${_id(row['id'] ?? row['attachment_id'])}:${_fileTitle(row)}',
      title: _fileTitle(row),
      subtitle: _fileSubtitle(row, linked: false).isEmpty
          ? 'Документ тренировки'
          : _fileSubtitle(row, linked: false),
      iconKind: SportotekaWorkspaceIconKind.document,
      preferredSize: const Size(900, 680),
      builder: (_) => _floatingFileViewer(row),
    );
  }


  String _fileExtension(String value) {
    final clean = value.trim().split('?').first.split('#').first;
    final match = RegExp(r'\.([A-Za-z0-9]{2,6})$').firstMatch(clean);
    return match == null ? '' : (match.group(1) ?? '').toUpperCase();
  }

  String _extensionFromRow(Map<String, dynamic> row) {
    for (final value in <String>[
      '${row['original_name'] ?? ''}',
      '${row['file_name'] ?? ''}',
      '${row['name'] ?? ''}',
      '${row['title'] ?? ''}',
      _fileUrl(row),
    ]) {
      final ext = _fileExtension(value);
      if (ext.isNotEmpty) return ext;
    }
    return '';
  }

  String _documentSource(Map<String, dynamic> row, {required bool linked}) {
    if (linked) return 'Sportoteka OS';
    final type = '${row['entity_type'] ?? ''}'.trim();
    if (type.isNotEmpty) return type == 'training' ? 'Документ тренировки' : type;
    return 'Документ тренировки';
  }

  String _formatBytes(dynamic value) {
    final bytes = int.tryParse('${value ?? 0}') ?? 0;
    if (bytes <= 0) return '';
    const units = ['Б', 'КБ', 'МБ', 'ГБ'];
    double size = bytes.toDouble();
    var idx = 0;
    while (size >= 1024 && idx < units.length - 1) {
      size /= 1024;
      idx++;
    }
    final digits = size >= 10 || idx == 0 ? 0 : 1;
    return '${size.toStringAsFixed(digits)} ${units[idx]}';
  }

  String _fileSubtitle(Map<String, dynamic> row, {required bool linked}) {
    final parts = <String>[];
    final source = _documentSource(row, linked: linked);
    if (source.isNotEmpty) parts.add(source);
    final ext = _extensionFromRow(row);
    if (ext.isNotEmpty) parts.add(ext);
    final size = _formatBytes(row['size'] ?? row['file_size'] ?? row['bytes']);
    if (size.isNotEmpty) parts.add(size);
    return parts.join(' · ');
  }

  Future<String> _loadTextPreview(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'Не удалось загрузить документ (${response.statusCode}).';
      }
      if (response.body.length > 150000) {
        return '${response.body.substring(0, 150000)}\n\n… предпросмотр сокращён';
      }
      return response.body;
    } catch (e) {
      return 'Не удалось загрузить документ: $e';
    }
  }

  Widget _previewUnsupported(String title, String ext) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _TrainingBrandDots(),
              const SizedBox(height: 14),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.description_outlined, color: _greenDark, size: 24),
              ),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: AppTypography.subsectionTitle(color: _text)),
              const SizedBox(height: 6),
              Text(
                ext.isEmpty
                    ? 'Формат файла не удалось определить. Просмотр остаётся внутри карточки тренировки.'
                    : 'Формат $ext пока не поддерживает встроенный предпросмотр. PDF, изображения и текстовые файлы открываются прямо здесь.',
                textAlign: TextAlign.center,
                style: AppTypography.secondary(color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planPickerCard(Map<String, dynamic> plan) {
    final id = _id(plan['id'] ?? plan['plan_id']);
    final title = _planTitle(plan);
    final description = _planDescription(plan);
    final active = id > 0 && id == linkedPlanId;

    return Material(
      color: active ? _greenSoft : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: linking || id <= 0 ? null : () => _linkPlan(id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : _soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  active ? Icons.assignment_turned_in_rounded : Icons.description_outlined,
                  size: 18,
                  color: active ? _greenDark : _muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.itemTitle(color: _text),
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Выбран',
                              style: AppTypography.captionMedium(color: _greenDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: _muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _planMeta(plan),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(color: _muted),
                          ),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.secondary(color: _muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: linking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1.6, color: _green),
                      )
                    : const Icon(Icons.chevron_right_rounded, size: 18, color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planPicker() {
    if (plans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment_outlined, color: _muted, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Доступных планов команды пока нет.',
                style: AppTypography.secondary(color: _muted),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Выберите план', style: AppTypography.itemTitle(color: _text)),
                      const SizedBox(height: 2),
                      Text(
                        'Показываем название, дату, автора и краткое описание.',
                        style: AppTypography.caption(color: _muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${plans.length}',
                  style: AppTypography.captionMedium(color: _greenDark),
                ),
              ],
            ),
          ),
          for (var i = 0; i < plans.length; i++) ...[
            _planPickerCard(plans[i]),
            if (i != plans.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _linkedPlanCard(Map<String, dynamic> plan) {
    final description = _planDescription(plan);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openPlan(plan),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, color: _greenDark, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _planTitle(plan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.itemTitle(color: _text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _planMeta(plan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(color: _muted),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.secondary(color: _muted),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text('План привязан к этой тренировке', style: AppTypography.caption(color: _greenDark)),
                        const Spacer(),
                        Text('Открыть', style: AppTypography.captionMedium(color: _greenDark)),
                        const SizedBox(width: 3),
                        const Icon(Icons.open_in_new_rounded, size: 14, color: _greenDark),
                      ],
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _green, strokeWidth: 2));
    }

    final linked = plans.where((p) => _id(p['id'] ?? p['plan_id']) == linkedPlanId).toList();
    final linkedPlan = linked.isEmpty ? null : linked.first;

    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
        children: [
          _section(
            icon: Icons.assignment_turned_in_outlined,
            title: 'План на тренировку',
            subtitle: linkedPlan == null ? 'Не выбран' : 'Привязан',
            trailing: TextButton.icon(
              onPressed: linking
                  ? null
                  : () => setState(() => planPickerOpen = !planPickerOpen),
              style: TextButton.styleFrom(
                foregroundColor: _greenDark,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              ),
              icon: Icon(
                planPickerOpen ? Icons.close_rounded : Icons.add_rounded,
                size: 17,
              ),
              label: Text(
                planPickerOpen
                    ? 'Закрыть'
                    : linkedPlan == null
                        ? 'Добавить'
                        : 'Сменить',
              ),
            ),
            child: planPickerOpen
                ? _planPicker()
                : linkedPlan == null
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _greenSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.assignment_add,
                                color: _greenDark,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'План пока не привязан',
                                    style: AppTypography.itemTitle(color: _text),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Нажмите «Добавить», чтобы выбрать план команды для этой тренировки.',
                                    style: AppTypography.secondary(color: _muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _linkedPlanCard(linkedPlan),
          ),
          const SizedBox(height: 12),
          _section(
            icon: Icons.folder_copy_outlined,
            title: 'Документы тренировки',
            subtitle: '${attachments.length + linkedDocuments.length} ${_filesWord(attachments.length + linkedDocuments.length)}',
            trailing: TextButton.icon(
              onPressed: uploading ? null : _upload,
              style: TextButton.styleFrom(foregroundColor: _greenDark),
              icon: uploading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: _green))
                  : const Icon(Icons.add_rounded, size: 17),
              label: Text(uploading ? 'Загрузка...' : 'Добавить'),
            ),
            child: attachments.isEmpty && linkedDocuments.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                                          ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _greenSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.folder_open_rounded, color: _greenDark, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Документов пока нет. Добавленные здесь файлы автоматически будут доступны в Sportoteka OS у этой тренировки.',
                            style: AppTypography.secondary(color: _muted),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (final row in attachments) _fileRow(row, Icons.attach_file_rounded, linked: false),
                      for (final row in linkedDocuments) _fileRow(row, Icons.description_outlined, linked: true),
                    ],
                  ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: AppTypography.caption(color: Colors.red.shade700)),
          ],
        ],
      ),
    );
  }

  String _filesWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'файл';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'файла';
    return 'файлов';
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
    String? subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(16),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _TrainingBrandDots(),
              const SizedBox(width: 9),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                                  ),
                child: Icon(icon, size: 16, color: _greenDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.subsectionTitle(color: _text)),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTypography.caption(color: _muted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _fileRow(Map<String, dynamic> row, IconData icon, {required bool linked}) {
    final url = _fileUrl(row);
    final canOpen = linked || url.isNotEmpty;
    final subtitle = _fileSubtitle(row, linked: linked);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canOpen ? () => _openFile(row, linked: linked) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
                      ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: linked ? _greenSoft : _soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: _greenDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileTitle(row),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.itemTitle(color: _text),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(color: _muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (canOpen) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(10),
                                      ),
                  child: const Icon(Icons.visibility_outlined, size: 15, color: _muted),
                ),
                const SizedBox(width: 6),
              ],
              PopupMenuButton<String>(
                tooltip: 'Действия',
                onSelected: (value) {
                  if (value == 'open' && canOpen) _openFile(row, linked: linked);
                  if (value == 'refresh') _load();
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  if (canOpen)
                    PopupMenuItem<String>(
                      value: 'open',
                      child: Text(linked ? 'Открыть в редакторе' : 'Открыть в новом окне'),
                    ),
                  const PopupMenuItem<String>(
                    value: 'refresh',
                    child: Text('Обновить список'),
                  ),
                ],
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(10),
                                      ),
                  child: const Icon(Icons.more_horiz_rounded, size: 17, color: _muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingFloatingWindow extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int cascadeIndex;
  final Size preferredSize;
  final VoidCallback onClose;
  final Widget child;

  const _TrainingFloatingWindow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.cascadeIndex,
    required this.preferredSize,
    required this.onClose,
    required this.child,
  });

  @override
  State<_TrainingFloatingWindow> createState() => _TrainingFloatingWindowState();
}

class _TrainingFloatingWindowState extends State<_TrainingFloatingWindow> {
  Offset? _position;
  bool _maximized = false;

  static const _green = Color(0xFF14915D);
  static const _greenDark = Color(0xFF0F7B50);
  static const _line = Color(0xFFE5ECE8);
  static const _muted = Color(0xFF667085);
  static const _text = Color(0xFF0B0F14);

  void _move(DragUpdateDetails details, Size viewport, Size windowSize) {
    final current = _position ?? Offset.zero;
    final maxX = (viewport.width - windowSize.width).clamp(0.0, double.infinity).toDouble();
    final maxY = (viewport.height - windowSize.height).clamp(0.0, double.infinity).toDouble();
    setState(() {
      _position = Offset(
        (current.dx + details.delta.dx).clamp(0.0, maxX).toDouble(),
        (current.dy + details.delta.dy).clamp(0.0, maxY).toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewport = media.size;
    final compact = viewport.width < 720 || viewport.height < 560;
    final safeTop = media.padding.top;
    final safeBottom = media.padding.bottom;

    if (compact) {
      return Positioned(
        left: 6,
        right: 6,
        top: safeTop + 6,
        bottom: safeBottom + 6,
        child: _windowBody(compact: true, viewport: viewport, windowSize: viewport),
      );
    }

    final preferredWidth = widget.preferredSize.width.clamp(560.0, viewport.width - 24).toDouble();
    final preferredHeight = widget.preferredSize.height.clamp(420.0, viewport.height - safeTop - 24).toDouble();
    final windowSize = _maximized
        ? Size(viewport.width - 20, viewport.height - safeTop - safeBottom - 20)
        : Size(preferredWidth, preferredHeight);

    if (_position == null) {
      final cascade = (widget.cascadeIndex % 7) * 26.0;
      final centeredX = ((viewport.width - windowSize.width) / 2).clamp(8.0, double.infinity).toDouble();
      final centeredY = ((viewport.height - windowSize.height) / 2).clamp(safeTop + 8.0, double.infinity).toDouble();
      _position = _maximized ? Offset(10, safeTop + 10) : Offset(centeredX + cascade / 2, centeredY + cascade / 2);
    }

    final maxX = (viewport.width - windowSize.width).clamp(0.0, double.infinity).toDouble();
    final maxY = (viewport.height - windowSize.height - safeBottom).clamp(safeTop, double.infinity).toDouble();
    final pos = _maximized
        ? Offset(10, safeTop + 10)
        : Offset(
            _position!.dx.clamp(0.0, maxX).toDouble(),
            _position!.dy.clamp(safeTop, maxY).toDouble(),
          );

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: windowSize.width,
      height: windowSize.height,
      child: _windowBody(compact: false, viewport: viewport, windowSize: windowSize),
    );
  }

  Widget _windowBody({required bool compact, required Size viewport, required Size windowSize}) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(compact ? 18 : 20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 18 : 20),
          border: Border.all(color: _line, width: .8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.16),
              blurRadius: 38,
              spreadRadius: -12,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: compact || _maximized ? null : (details) => _move(details, viewport, windowSize),
              onDoubleTap: compact
                  ? null
                  : () => setState(() {
                        _maximized = !_maximized;
                        _position = null;
                      }),
              child: Container(
                height: 54,
                padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAF9),
                  border: Border(bottom: BorderSide(color: _line, width: .7)),
                ),
                child: Row(
                  children: [
                    const _TrainingBrandDots(),
                    const SizedBox(width: 10),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F7F3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, size: 17, color: _greenDark),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.itemTitle(color: _text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            compact ? widget.subtitle : '${widget.subtitle} · потяните за верхнюю панель, чтобы переместить',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      IconButton(
                        tooltip: _maximized ? 'Восстановить размер' : 'Развернуть',
                        onPressed: () => setState(() {
                          _maximized = !_maximized;
                          _position = null;
                        }),
                        icon: Icon(_maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded, size: 17),
                        color: _muted,
                      ),
                    ],
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded, size: 19),
                      color: _muted,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: Colors.white,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceTrainingDocumentEditor extends StatefulWidget {
  final String initialTitle;
  final String initialBody;
  final int version;
  final String updatedAt;
  final Future<void> Function(String title, String body) onSave;

  const _WorkspaceTrainingDocumentEditor({
    required this.initialTitle,
    required this.initialBody,
    required this.version,
    required this.updatedAt,
    required this.onSave,
  });

  @override
  State<_WorkspaceTrainingDocumentEditor> createState() => _WorkspaceTrainingDocumentEditorState();
}

class _WorkspaceTrainingDocumentEditorState extends State<_WorkspaceTrainingDocumentEditor> {
  static const _green = Color(0xFF14915D);
  static const _greenDark = Color(0xFF0F7B50);
  static const _greenSoft = Color(0xFFF3F8F5);
  static const _line = Color(0xFFE5ECE8);
  static const _soft = Color(0xFFF8FAF9);
  static const _text = Color(0xFF0B0F14);
  static const _muted = Color(0xFF667085);

  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _saving = false;
  bool _dirty = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
    _titleController.addListener(_markDirty);
    _bodyController.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(_titleController.text, _bodyController.text);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Документ сохранён в Sportoteka OS')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveError = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 700;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(compact ? 10 : 16, 10, compact ? 10 : 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _line, width: .7)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  maxLines: 1,
                  style: AppTypography.subsectionTitle(color: _text),
                  decoration: InputDecoration(
                    hintText: 'Название документа',
                    filled: true,
                    fillColor: _soft,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _saving || (!_dirty && _saveError == null) ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _greenDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _greenSoft,
                  disabledForegroundColor: _greenDark.withOpacity(.55),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _saving
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 17),
                label: Text(_saving ? 'Сохраняю' : 'Сохранить'),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: 8),
          color: _soft,
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_done_outlined, size: 14, color: _green),
                const SizedBox(width: 5),
                Text('Sportoteka OS', style: AppTypography.captionMedium(color: _greenDark)),
              ]),
              if (widget.version > 0) Text('Версия ${widget.version}', style: AppTypography.caption(color: _muted)),
              if (widget.updatedAt.trim().isNotEmpty) Text('Обновлён: ${widget.updatedAt}', style: AppTypography.caption(color: _muted)),
              if (_dirty) Text('Есть несохранённые изменения', style: AppTypography.captionMedium(color: const Color(0xFFB7791F))),
            ],
          ),
        ),
        if (_saveError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFFFF5F5),
            child: Text(_saveError!, style: AppTypography.caption(color: const Color(0xFFB42318))),
          ),
        Expanded(
          child: Container(
            color: const Color(0xFFF4F6F5),
            padding: EdgeInsets.all(compact ? 8 : 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.035),
                        blurRadius: 18,
                        spreadRadius: -10,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _bodyController,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    style: AppTypography.body(color: _text).copyWith(height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'Текст документа…',
                      hintStyle: AppTypography.body(color: _muted.withOpacity(.7)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(compact ? 14 : 28, compact ? 16 : 24, compact ? 14 : 28, 28),
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


class _TrainingBrandDot extends StatelessWidget {
  final double size;
  final double opacity;
  final Color color;

  const _TrainingBrandDot({required this.size, required this.opacity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _TrainingBrandDots extends StatelessWidget {
  const _TrainingBrandDots();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF14915D);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _TrainingBrandDot(size: 3.5, opacity: .28, color: color),
        SizedBox(width: 3),
        _TrainingBrandDot(size: 4.5, opacity: .48, color: color),
        SizedBox(width: 3),
        _TrainingBrandDot(size: 5.5, opacity: .72, color: color),
        SizedBox(width: 3),
        _TrainingBrandDot(size: 6.5, opacity: 1, color: color),
      ],
    );
  }
}
