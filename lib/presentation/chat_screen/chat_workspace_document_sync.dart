import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_server_storage.dart';

/// Adds chat documents to the club's existing Workspace OS tree. Files stay
/// at their chat upload URL; Workspace stores only a shared index entry.
class ChatWorkspaceDocumentSync {
  ChatWorkspaceDocumentSync({
    required this.clubId,
    required this.userId,
    required this.chatId,
    required this.chatTitle,
  }) : _storage = clubId > 0
            ? WorkspaceServerStorage(clubId: clubId, userId: userId)
            : null;

  final int clubId;
  final int userId;
  final int chatId;
  final String chatTitle;
  final WorkspaceServerStorage? _storage;

  static const rootId = 'local-folder:chat-documents';
  final Map<String, Future<void>> _folders = <String, Future<void>>{};
  final Map<int, Future<void>> _messages = <int, Future<void>>{};
  final Set<int> _completed = <int>{};

  bool get available => _storage != null && userId > 0;

  Future<void> _upsert(WorkspaceFinderNode node) async {
    final storage = _storage!;
    try {
      await storage.createNode(node);
    } catch (_) {
      // Existing club node: keep its shared ID and update its file URL.
      await storage.updateNode(node);
    }
  }

  Future<void> _ensureFolder(WorkspaceFinderNode node) {
    final existing = _folders[node.id];
    if (existing != null) return existing;
    final operation = _upsert(node);
    _folders[node.id] = operation;
    operation.then((_) {}, onError: (Object _) {
      if (identical(_folders[node.id], operation)) _folders.remove(node.id);
    });
    return operation;
  }

  Future<void> sync({
    required int messageId,
    required String fileUrl,
    required String fileName,
    required DateTime sentAt,
    String mimeType = '',
  }) {
    if (!available || messageId <= 0 || fileUrl.trim().isEmpty) {
      return Future<void>.error(StateError('Не указан клуб или ссылка на документ'));
    }
    if (_completed.contains(messageId)) return Future<void>.value();
    final pending = _messages[messageId];
    if (pending != null) return pending;

    final operation = _sync(
      messageId: messageId,
      fileUrl: fileUrl,
      fileName: fileName,
      sentAt: sentAt,
      mimeType: mimeType,
    );
    _messages[messageId] = operation;
    operation.then((_) {
      _completed.add(messageId);
      _messages.remove(messageId);
    }, onError: (Object _) {
      _messages.remove(messageId);
    });
    return operation;
  }

  Future<void> _sync({
    required int messageId,
    required String fileUrl,
    required String fileName,
    required DateTime sentAt,
    required String mimeType,
  }) async {
    final local = sentAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final dateKey = '${local.year}-${two(local.month)}-${two(local.day)}';
    final dayId = '$rootId:$dateKey';
    final dateTitle = '${two(local.day)}.${two(local.month)}.${local.year}';

    await _ensureFolder(WorkspaceFinderNode(
      id: rootId,
      title: 'Файлы из чатов',
      subtitle: 'Документы переписки',
      kind: WorkspaceFinderNodeKind.folder,
      parentId: 'documents',
    ));
    await _ensureFolder(WorkspaceFinderNode(
      id: dayId,
      title: dateTitle,
      subtitle: 'Документы за $dateTitle',
      kind: WorkspaceFinderNodeKind.folder,
      parentId: rootId,
      createdAt: DateTime(local.year, local.month, local.day),
      payload: <String, dynamic>{
        '_workspace_chat_date': true,
        'document_date': dateKey,
      },
    ));

    final safeName = fileName.trim().isEmpty ? 'Документ' : fileName.trim();
    await _upsert(WorkspaceFinderNode(
      id: 'chat-document:$chatId:$messageId',
      title: safeName,
      subtitle: 'Чат «$chatTitle» · $dateTitle',
      kind: WorkspaceFinderNodeKind.document,
      parentId: dayId,
      createdAt: sentAt,
      updatedAt: sentAt,
      payload: <String, dynamic>{
        '_workspace_uploaded_file': true,
        '_workspace_chat_document': true,
        '_workspace_folder_key': dayId,
        'file_url': fileUrl,
        'document_date': dateKey,
        'mime_type': mimeType,
        'original_name': safeName,
        'chat_id': chatId,
        'message_id': messageId,
      },
    ));
  }
}
