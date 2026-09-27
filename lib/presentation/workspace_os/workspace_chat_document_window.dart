import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_attachment_preview.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_document_editor.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_server_storage.dart';

/// Opens the unchanged uploaded file first, with an editable Workspace copy
/// beside it. Saving the copy never replaces the original DOCX/PDF binary.
class WorkspaceChatDocumentWindow extends StatefulWidget {
  const WorkspaceChatDocumentWindow({
    super.key,
    required this.title,
    required this.fileUrl,
    required this.sourceNodeId,
    required this.folderId,
    required this.clubId,
    required this.userId,
    this.clubName = '',
    this.mimeType = '',
    this.onClose,
    this.ensureIndexed,
    this.onSaved,
  });

  final String title;
  final String fileUrl;
  final String mimeType;
  final String sourceNodeId;
  final String folderId;
  final int clubId;
  final int userId;
  final String clubName;
  final VoidCallback? onClose;
  final Future<void> Function()? ensureIndexed;
  final Future<void> Function()? onSaved;

  @override
  State<WorkspaceChatDocumentWindow> createState() =>
      _WorkspaceChatDocumentWindowState();
}

Future<void> openWorkspaceChatDocument(
  BuildContext context, {
  required String title,
  required String fileUrl,
  required String sourceNodeId,
  required String folderId,
  required int clubId,
  required int userId,
  String clubName = '',
  String mimeType = '',
  Future<void> Function()? ensureIndexed,
  Future<void> Function()? onSaved,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (routeContext) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: WorkspaceChatDocumentWindow(
            title: title,
            fileUrl: fileUrl,
            sourceNodeId: sourceNodeId,
            folderId: folderId,
            clubId: clubId,
            userId: userId,
            clubName: clubName,
            mimeType: mimeType,
            ensureIndexed: ensureIndexed,
            onSaved: onSaved,
            onClose: () => Navigator.of(routeContext).maybePop(),
          ),
        ),
      ),
    ),
  );
}

class _WorkspaceChatDocumentWindowState extends State<WorkspaceChatDocumentWindow> {
  static const _green = Color(0xFF0B8F55);
  static const _muted = Color(0xFF66736B);
  static const _line = Color(0xFFE4E9E6);

  late final WorkspaceServerStorage _storage = WorkspaceServerStorage(
    clubId: widget.clubId,
    userId: widget.userId,
  );
  bool _editing = false;
  bool _openingEditor = false;
  bool _editorReady = false;
  bool _copyExists = false;
  String _editorBody = '';
  late String _editorTitle = 'Редакция: ${widget.title}';
  String? _error;

  String get _copyId => 'chat-edit:${widget.sourceNodeId}';

  String get _extension {
    final name = widget.title.split('?').first.trim().toLowerCase();
    final pos = name.lastIndexOf('.');
    return pos < 0 ? '' : name.substring(pos + 1);
  }

  bool get _canEdit => widget.clubId > 0 &&
      const <String>{
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        'odt', 'ods', 'odp', 'rtf', 'txt', 'csv', 'tsv',
        'md', 'json', 'xml', 'yaml', 'yml', 'log',
      }.contains(_extension);

  Future<void> _showEditor() async {
    if (!_canEdit || _openingEditor) return;
    if (_editorReady) {
      setState(() => _editing = true);
      return;
    }
    setState(() {
      _openingEditor = true;
      _error = null;
    });
    try {
      final remote = await _storage.loadDocument(clientUid: _copyId);
      final exists = remote?['exists'] == true;
      final body = exists
          ? '${remote?['body'] ?? ''}'
          : await loadWorkspaceEditableAttachmentBody(
              title: widget.title,
              fileUrl: widget.fileUrl,
              mimeType: widget.mimeType,
            );
      if (!mounted) return;
      setState(() {
        _copyExists = exists;
        if (exists && '${remote?['title'] ?? ''}'.trim().isNotEmpty) {
          _editorTitle = '${remote?['title']}'.trim();
        }
        _editorBody = body;
        _editorReady = true;
        _editing = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось открыть документ для редактирования: $e');
    } finally {
      if (mounted) setState(() => _openingEditor = false);
    }
  }

  Future<void> _save(String title, String body) async {
    try {
      if (widget.ensureIndexed != null) await widget.ensureIndexed!();
      final dateKey = widget.folderId.startsWith('local-folder:chat-documents:')
          ? widget.folderId.substring('local-folder:chat-documents:'.length)
          : '';
      final node = WorkspaceFinderNode(
        id: _copyId,
        title: title.trim().isEmpty ? 'Редакция: ${widget.title}' : title.trim(),
        subtitle: 'Редактируемая копия · оригинал сохранён',
        kind: WorkspaceFinderNodeKind.note,
        parentId: widget.folderId,
        payload: <String, dynamic>{
          '_workspace_chat_edit_copy': true,
          '_workspace_original_file_url': widget.fileUrl,
          '_workspace_original_node_id': widget.sourceNodeId,
          'document_date': dateKey,
        },
      );
      await _storage.syncNodeDocument(
        node: node,
        body: body,
        createHint: !_copyExists,
      );
      _copyExists = true;
      if (mounted) setState(() => _error = null);
      if (widget.onSaved != null) {
        try {
          await widget.onSaved!();
        } catch (_) {
          // The saved version is on the server; a refresh can be retried later.
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Правки не сохранены в ОС: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: <Widget>[
                if (widget.onClose != null)
                  IconButton(
                    tooltip: 'Закрыть документ',
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: widget.onClose,
                  ),
                if (!compact) ...<Widget>[
                  Expanded(
                    child: Text(widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.itemTitle(color: const Color(0xFF17201B))),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton.icon(
                  onPressed: () => setState(() => _editing = false),
                  icon: const Icon(Icons.description_outlined, size: 17),
                  label: const Text('Оригинал'),
                  style: TextButton.styleFrom(
                    foregroundColor: _editing ? _muted : _green,
                  ),
                ),
                if (_canEdit) ...<Widget>[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _openingEditor ? null : _showEditor,
                    icon: _openingEditor
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined, size: 17),
                    label: Text(compact ? 'Править' : 'Редактировать'),
                    style: TextButton.styleFrom(
                      foregroundColor: _editing ? _green : _muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF4E5),
              padding: const EdgeInsets.all(10),
              child: Text(_error!, style: AppTypography.caption(color: const Color(0xFFB54708))),
            ),
          Expanded(
            child: IndexedStack(
              index: _editing ? 1 : 0,
              children: <Widget>[
                WorkspaceAttachmentInlinePreview(
                  title: widget.title,
                  fileUrl: widget.fileUrl,
                  mimeType: widget.mimeType,
                ),
                _editorReady
                    ? WorkspaceDocumentEditor(
                        initialTitle: _editorTitle,
                        initialBody: _editorBody,
                        contextLabel: 'Файлы из чатов',
                        contextName: widget.clubName,
                        documentType: 'Документ чата',
                        compactWorkspaceChrome: true,
                        liveBlocksKey: _copyId,
                        aiClubId: widget.clubId,
                        aiUserId: widget.userId,
                        aiClubName: widget.clubName,
                        aiDocumentKey: _copyId,
                        onSave: _save,
                        onClose: () => setState(() => _editing = false),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
