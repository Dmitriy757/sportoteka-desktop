import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';

/// Полноэкранный выбор папки для сохранения из модулей Спортотеки.
///
/// Важно: это именно режим Sportoteka OS, а не отдельный CMR-диалог.
/// Пользователь может зайти в папку, создать вложенную, переименовать или
/// удалить её и вернуть выбранное место вызывающему экрану.
class WorkspacePlanFolderPickerScreen extends StatefulWidget {
  const WorkspacePlanFolderPickerScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.teamId = 0,
    this.teamName = '',
    this.initialFolderId = 0,
    this.initialFolderTitle = '',
    this.title = 'Сохранение схемы',
    this.embedded = false,
    this.onFolderSelected,
    this.onCancel,
  });

  final int clubId;
  final String clubName;
  final int teamId;
  final String teamName;
  final int initialFolderId;
  final String initialFolderTitle;
  final String title;
  final bool embedded;
  final ValueChanged<Map<String, dynamic>>? onFolderSelected;
  final VoidCallback? onCancel;

  @override
  State<WorkspacePlanFolderPickerScreen> createState() =>
      _WorkspacePlanFolderPickerScreenState();
}

class _WorkspacePlanFolderPickerScreenState
    extends State<WorkspacePlanFolderPickerScreen> {
  static const _green = Color(0xFF0B8F55);
  static const _greenSoft = Color(0xFFEAF5EF);
  static const _bg = Color(0xFFF6F7F6);
  static const _surface = Colors.white;
  static const _line = Color(0xFFE5E8E5);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _danger = Color(0xFFC63D3D);

  final TextEditingController _search = TextEditingController();
  final TextEditingController _newFolderNameController = TextEditingController();
  final FocusNode _newFolderNameFocus = FocusNode();
  bool _showInlineFolderCreator = false;
  bool _creatingFolder = false;
  String? _folderCreateError;
  String _newFolderType = 'custom';

  List<dynamic> _tree = const <dynamic>[];
  List<Map<String, dynamic>> _folders = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _crumbs = <Map<String, dynamic>>[
    <String, dynamic>{'id': 0, 'title': 'Планы-конспекты'},
  ];

  int _parentId = 0;
  String _parentTitle = 'Планы-конспекты';
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _initialLocationApplied = false;
  WorkspaceFinderViewMode _viewMode = WorkspaceFinderViewMode.list;
  bool _showSidebarOnCompact = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _newFolderNameController.dispose();
    _newFolderNameFocus.dispose();
    super.dispose();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  String _asString(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    final body = response.body.trim();
    if (body.isEmpty) {
      return <String, dynamic>{
        'success': false,
        'message': 'Сервер вернул пустой ответ',
      };
    }
    final lower = body.toLowerCase();
    if (body.startsWith('<') || lower.contains('<html') || lower.contains('<br')) {
      return <String, dynamic>{
        'success': false,
        'message': 'Сервер вернул HTML вместо JSON',
      };
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{
      'success': false,
      'message': 'Не удалось прочитать ответ сервера',
    };
  }

  Future<Map<String, dynamic>> _listFolders() async {
    final response = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/list_plan_folders.php'),
      headers: const <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(<String, dynamic>{'club_id': widget.clubId}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _createFolderApi({
    required String title,
    required String type,
  }) async {
    final createdBy = await PrefUtils.getUserId() ?? 0;
    final response = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/create_plan_folder.php'),
      body: <String, String>{
        'club_id': widget.clubId.toString(),
        'parent_id': _parentId.toString(),
        'name': title.trim(),
        'title': title.trim(),
        'type': type,
        'created_by': createdBy.toString(),
      },
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _renameFolderApi({
    required int folderId,
    required String title,
  }) async {
    final response = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/rename_plan_folder.php'),
      headers: const <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(<String, dynamic>{
        'club_id': widget.clubId,
        'folder_id': folderId,
        'title': title.trim(),
        'name': title.trim(),
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _deleteFolderApi(int folderId) async {
    final response = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/delete_plan_folder.php'),
      headers: const <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(<String, dynamic>{
        'club_id': widget.clubId,
        'folder_id': folderId,
      }),
    );
    return _decode(response);
  }

  List<Map<String, dynamic>> _childrenOf(int parentId) {
    final result = <Map<String, dynamic>>[];

    void walk(List<dynamic> nodes) {
      for (final raw in nodes) {
        if (raw is! Map) continue;
        final node = Map<String, dynamic>.from(raw);
        if (_asInt(node['parent_id']) == parentId) result.add(node);
        final children = (node['children'] as List?) ?? const <dynamic>[];
        if (children.isNotEmpty) walk(children);
      }
    }

    walk(_tree);
    return result;
  }

  List<Map<String, dynamic>>? _pathToFolder(int folderId) {
    if (folderId <= 0) {
      return <Map<String, dynamic>>[
        <String, dynamic>{'id': 0, 'title': 'Планы-конспекты'},
      ];
    }

    List<Map<String, dynamic>>? found;
    void walk(List<dynamic> nodes, List<Map<String, dynamic>> parents) {
      if (found != null) return;
      for (final raw in nodes) {
        if (raw is! Map) continue;
        final node = Map<String, dynamic>.from(raw);
        final id = _asInt(node['id']);
        final title = _asString(node['title']).isNotEmpty
            ? _asString(node['title'])
            : 'Папка';
        final next = <Map<String, dynamic>>[
          ...parents,
          <String, dynamic>{'id': id, 'title': title},
        ];
        if (id == folderId) {
          found = next;
          return;
        }
        final children = (node['children'] as List?) ?? const <dynamic>[];
        if (children.isNotEmpty) walk(children, next);
      }
    }

    walk(
      _tree,
      <Map<String, dynamic>>[
        <String, dynamic>{'id': 0, 'title': 'Планы-конспекты'},
      ],
    );
    return found;
  }

  void _refreshVisibleFolders() {
    if (!mounted) return;
    final query = _search.text.trim().toLowerCase();
    final all = _childrenOf(_parentId);
    setState(() {
      _folders = query.isEmpty
          ? all
          : all.where((folder) {
              return _asString(folder['title'])
                      .toLowerCase()
                      .contains(query) ||
                  _asString(folder['name']).toLowerCase().contains(query) ||
                  _asString(folder['type']).toLowerCase().contains(query);
            }).toList(growable: false);
    });
  }

  Future<void> _load({int? focusFolderId}) async {
    if (widget.clubId <= 0) {
      setState(() {
        _loading = false;
        _error = 'Не удалось определить клуб.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _listFolders();
      if (response['success'] != true) {
        throw Exception('${response['message'] ?? 'Не удалось загрузить папки'}');
      }

      _tree = (response['tree'] as List?) ??
          (response['folders'] as List?) ??
          (response['data'] as List?) ??
          const <dynamic>[];

      if (!_initialLocationApplied) {
        _initialLocationApplied = true;
        final initialId = widget.initialFolderId;
        final path = _pathToFolder(initialId);
        if (path != null && path.isNotEmpty) {
          _crumbs
            ..clear()
            ..addAll(path);
          _parentId = _asInt(path.last['id']);
          _parentTitle = _asString(path.last['title']).isNotEmpty
              ? _asString(path.last['title'])
              : 'Планы-конспекты';
        } else if (initialId > 0) {
          _parentId = initialId;
          _parentTitle = widget.initialFolderTitle.trim().isNotEmpty
              ? widget.initialFolderTitle.trim()
              : 'Папка';
        }
      }

      if (focusFolderId != null && focusFolderId > 0) {
        final path = _pathToFolder(focusFolderId);
        if (path != null && path.isNotEmpty) {
          _crumbs
            ..clear()
            ..addAll(path);
          _parentId = _asInt(path.last['id']);
          _parentTitle = _asString(path.last['title']);
        }
      }

      _search.clear();
      final current = _childrenOf(_parentId);
      if (!mounted) return;
      setState(() {
        _folders = current;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _enterFolder(Map<String, dynamic> folder) async {
    final id = _asInt(folder['id']);
    if (id <= 0) return;
    final title = _asString(folder['title']).isNotEmpty
        ? _asString(folder['title'])
        : 'Папка';
    setState(() {
      _parentId = id;
      _parentTitle = title;
      _crumbs.add(<String, dynamic>{'id': id, 'title': title});
      _search.clear();
      _folders = _childrenOf(id);
    });
  }

  void _goToCrumb(int index) {
    if (index < 0 || index >= _crumbs.length) return;
    final target = _crumbs[index];
    setState(() {
      _parentId = _asInt(target['id']);
      _parentTitle = _asString(target['title']).isNotEmpty
          ? _asString(target['title'])
          : 'Планы-конспекты';
      _crumbs.removeRange(index + 1, _crumbs.length);
      _search.clear();
      _folders = _childrenOf(_parentId);
    });
  }

  void _selectCurrentFolder() {
    final result = <String, dynamic>{
      'id': _parentId,
      'title': _parentTitle,
    };
    final callback = widget.onFolderSelected;
    if (callback != null) {
      callback(result);
      return;
    }
    Navigator.of(context).pop(result);
  }

  void _cancelPicker() {
    final callback = widget.onCancel;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _goUp() {
    if (_crumbs.length <= 1) return;
    _goToCrumb(_crumbs.length - 2);
  }

  void _resetToRoot() {
    if (_crumbs.isEmpty) return;
    _goToCrumb(0);
  }

  void _showSelectionModeHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Для сохранения схемы выберите папку в разделе «Планы-конспекты».',
          style: AppTypography.body(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _createFolder() async {
    if (_busy || _creatingFolder) return;
    setState(() {
      _showInlineFolderCreator = true;
      _folderCreateError = null;
      _newFolderType = 'custom';
      _newFolderNameController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _newFolderNameFocus.requestFocus();
    });
  }

  void _cancelInlineFolderCreator() {
    if (_creatingFolder) return;
    setState(() {
      _showInlineFolderCreator = false;
      _folderCreateError = null;
      _newFolderNameController.clear();
      _newFolderType = 'custom';
    });
  }

  Future<void> _commitInlineFolderCreator() async {
    if (_creatingFolder || _busy) return;
    final title = _newFolderNameController.text.trim();
    if (title.isEmpty) {
      setState(() => _folderCreateError = 'Введите название папки');
      _newFolderNameFocus.requestFocus();
      return;
    }

    setState(() {
      _creatingFolder = true;
      _folderCreateError = null;
    });

    try {
      final response = await _createFolderApi(
        title: title,
        type: _newFolderType,
      );
      if (response['success'] != true) {
        throw Exception('${response['message'] ?? 'Не удалось создать папку'}');
      }
      final createdId = _asInt(response['id'] ?? response['folder_id']);
      if (mounted) {
        setState(() {
          _showInlineFolderCreator = false;
          _creatingFolder = false;
          _newFolderNameController.clear();
          _newFolderType = 'custom';
        });
      }
      await _load(focusFolderId: createdId > 0 ? createdId : null);
      if (createdId <= 0) {
        final justCreated = _childrenOf(_parentId)
            .where((folder) => _asString(folder['title']) == title)
            .toList();
        if (justCreated.isNotEmpty) await _enterFolder(justCreated.last);
      }
      _showNotice('Папка создана');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingFolder = false;
        _folderCreateError = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _renameFolder(Map<String, dynamic> folder) async {
    final id = _asInt(folder['id']);
    if (id <= 0) return;
    final controller = TextEditingController(text: _asString(folder['title']));
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Переименовать папку'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Новое название'),
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    setState(() => _busy = true);
    try {
      final response = await _renameFolderApi(folderId: id, title: name);
      if (response['success'] != true) {
        throw Exception('${response['message'] ?? 'Не удалось переименовать'}');
      }
      await _load();
      _showNotice('Папка переименована');
    } catch (e) {
      _showNotice('$e'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteFolder(Map<String, dynamic> folder) async {
    final id = _asInt(folder['id']);
    if (id <= 0) return;
    final title = _asString(folder['title']).isNotEmpty
        ? _asString(folder['title'])
        : 'Папка';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить папку?'),
        content: Text('Папка «$title» будет удалена, если она не содержит защищённых материалов.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final response = await _deleteFolderApi(id);
      if (response['success'] != true) {
        throw Exception('${response['message'] ?? 'Не удалось удалить папку'}');
      }
      await _load();
      _showNotice('Папка удалена');
    } catch (e) {
      _showNotice('$e'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showNotice(String message, {bool error = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _line),
        ),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: error ? _danger : _green,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body(color: _text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _folderMeta(Map<String, dynamic> folder) {
    final parts = <String>[];
    final plans = _asInt(folder['plans_count']);
    final schemes = _asInt(folder['schemes_count']);
    final files = _asInt(folder['files_count']);
    if (plans > 0) parts.add('$plans планов');
    if (schemes > 0) parts.add('$schemes схем');
    if (files > 0) parts.add('$files файлов');
    return parts.isEmpty ? 'Папка' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 700;
    final compact = size.width < 980;
    final showSidebar = !compact || _showSidebarOnCompact;

    final content = ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Row(
            children: [
              if (showSidebar)
                SizedBox(
                  width: mobile ? (size.width * .82).clamp(220.0, 280.0).toDouble() : 226.0,
                  child: _buildWorkspaceSidebar(compact: compact),
                ),
              Expanded(
                child: _buildWorkspaceMain(mobile: mobile, compact: compact),
              ),
            ],
          ),
          if (compact && showSidebar)
            Positioned(
              right: 12,
              top: 12,
              child: IconButton.filledTonal(
                onPressed: () => setState(() => _showSidebarOnCompact = false),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Закрыть меню',
              ),
            ),
          if (_showInlineFolderCreator)
            Positioned(
              top: mobile ? 68 : 72,
              right: mobile ? 10 : 18,
              child: _buildInlineFolderCreator(mobile: mobile),
            ),
        ],
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildStandaloneTopBar(),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildStandaloneTopBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Закрыть',
            onPressed: _busy ? null : _cancelPicker,
            icon: const Icon(Icons.close_rounded, size: 19, color: _muted),
          ),
          const SportotekaWorkspaceIcon(
            kind: SportotekaWorkspaceIconKind.plans,
            size: 18,
            color: _green,
            accentColor: _green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Спортотека OS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.menuTitle(color: _text),
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    widget.clubName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(color: _muted),
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _green),
            ),
        ],
      ),
    );
  }

  Widget _buildInlineFolderCreator({required bool mobile}) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = mobile
        ? (width - 20).clamp(260.0, 360.0).toDouble()
        : 360.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _line, width: .8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.10),
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F6F3),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.create_new_folder_outlined,
                    color: _green,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Новая папка',
                          style: AppTypography.itemTitle(color: _text)),
                      const SizedBox(height: 1),
                      Text(
                        'Создать в «$_parentTitle»',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(color: _muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: _creatingFolder ? null : _cancelInlineFolderCreator,
                  icon: const Icon(Icons.close_rounded, color: _muted, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 9),
            TextField(
              controller: _newFolderNameController,
              focusNode: _newFolderNameFocus,
              enabled: !_creatingFolder,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_folderCreateError != null) {
                  setState(() => _folderCreateError = null);
                }
              },
              onSubmitted: (_) => _commitInlineFolderCreator(),
              style: AppTypography.formText(color: _text),
              decoration: InputDecoration(
                hintText: 'Название папки',
                hintStyle: AppTypography.formHint(color: _muted),
                errorText: _folderCreateError,
                filled: true,
                fillColor: const Color(0xFFF7F9F8),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: _line, width: .7),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: _green, width: 1.1),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _FolderTypeChip(
                  label: 'Обычная',
                  selected: _newFolderType == 'custom',
                  onTap: () => setState(() => _newFolderType = 'custom'),
                ),
                _FolderTypeChip(
                  label: 'Возраст',
                  selected: _newFolderType == 'age',
                  onTap: () => setState(() => _newFolderType = 'age'),
                ),
                _FolderTypeChip(
                  label: 'Категория',
                  selected: _newFolderType == 'category',
                  onTap: () => setState(() => _newFolderType = 'category'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _creatingFolder ? null : _cancelInlineFolderCreator,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _text,
                      side: const BorderSide(color: _line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _creatingFolder ? null : _commitInlineFolderCreator,
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    icon: _creatingFolder
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_rounded, size: 17),
                    label: Text(_creatingFolder ? 'Создание...' : 'Создать'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceSidebar({required bool compact}) {
    void handleModule(String key) {
      if (key == 'plans') {
        _resetToRoot();
        if (compact) setState(() => _showSidebarOnCompact = false);
        return;
      }
      _showSelectionModeHint();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _line)),
      ),
      child: SafeArea(
        right: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 4, 9, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SPORTOTEKA OS',
                      style: AppTypography.menuGroup(color: _green)),
                  const SizedBox(height: 4),
                  Text(
                    widget.clubName.trim().isEmpty
                        ? 'Пространство клуба'
                        : widget.clubName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.itemTitle(color: _text),
                  ),
                ],
              ),
            ),
            _PickerSideItem(
              icon: Icons.home_rounded,
              title: 'Главная',
              selected: false,
              onTap: _showSelectionModeHint,
            ),
            _PickerSideItem(
              icon: Icons.schedule_rounded,
              title: 'Недавние',
              selected: false,
              onTap: _showSelectionModeHint,
            ),
            _PickerSideItem(
              icon: Icons.star_rounded,
              title: 'Избранное',
              selected: false,
              onTap: _showSelectionModeHint,
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Text('КЛУБ', style: AppTypography.menuGroup(color: _muted)),
            ),
            const SizedBox(height: 5),
            for (final module in kWorkspaceFinderModules.take(9))
              _PickerSideItem(
                icon: module.icon,
                title: module.title,
                selected: module.key == 'plans',
                onTap: () => handleModule(module.key),
              ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Text('ЕЩЁ', style: AppTypography.menuGroup(color: _muted)),
            ),
            const SizedBox(height: 5),
            for (final module in kWorkspaceFinderModules.skip(9))
              _PickerSideItem(
                icon: module.icon,
                title: module.title,
                selected: false,
                onTap: () => handleModule(module.key),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceMain({required bool mobile, required bool compact}) {
    return Column(
      children: [
        _buildWorkspaceToolbar(mobile: mobile, compact: compact),
        _buildWorkspaceBreadcrumbs(mobile: mobile),
        Expanded(
          child: _loading
              ? const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: _green,
                    ),
                  ),
                )
              : _error != null
                  ? _buildError()
                  : _folders.isEmpty
                      ? _buildEmptyWorkspaceState()
                      : _viewMode == WorkspaceFinderViewMode.list
                          ? _buildWorkspaceList(mobile: mobile)
                          : _buildWorkspaceGrid(mobile: mobile),
        ),
        _buildWorkspaceStatusBar(),
      ],
    );
  }

  Widget _buildWorkspaceToolbar({required bool mobile, required bool compact}) {
    return Container(
      height: mobile ? 58 : 62,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          if (compact)
            IconButton(
              onPressed: () => setState(() => _showSidebarOnCompact = true),
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Разделы',
            ),
          IconButton(
            onPressed: _crumbs.length <= 1 ? null : _goUp,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Назад',
          ),
          if (!mobile) ...[
            IconButton(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Обновить',
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Container(
              height: 36,
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _search,
                onChanged: (_) => _refreshVisibleFolders(),
                style: AppTypography.formText(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: mobile ? 'Поиск' : 'Поиск в «$_parentTitle»',
                  hintStyle: AppTypography.formHint(),
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Создать',
            onSelected: (value) {
              if (value == 'folder') _createFolder();
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'folder',
                child: Text('Новая папка', style: AppTypography.menuTitle()),
              ),
            ],
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  if (!mobile) ...[
                    const SizedBox(width: 5),
                    Text('Создать',
                        style: AppTypography.actionStrong(color: Colors.white)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (!mobile)
            Material(
              color: const Color(0xFFEAF5EF),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _busy ? null : _selectCurrentFolder,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.save_outlined, size: 17, color: _green),
                      const SizedBox(width: 6),
                      Text(
                        'Сохранить сюда',
                        style: AppTypography.actionStrong(color: _green),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Сохранить сюда',
              onPressed: _busy ? null : _selectCurrentFolder,
              icon: const Icon(Icons.save_outlined, color: _green),
            ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == WorkspaceFinderViewMode.grid
                    ? WorkspaceFinderViewMode.list
                    : WorkspaceFinderViewMode.grid;
              });
            },
            icon: Icon(
              _viewMode == WorkspaceFinderViewMode.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
            tooltip: _viewMode == WorkspaceFinderViewMode.grid
                ? 'Список'
                : 'Иконки',
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceBreadcrumbs({required bool mobile}) {
    return Container(
      height: mobile ? 42 : 46,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 18),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _crumbs.length,
              separatorBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right_rounded,
                    size: 16, color: _muted),
              ),
              itemBuilder: (context, index) {
                final active = index == _crumbs.length - 1;
                final title = _asString(_crumbs[index]['title']);
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: active ? null : () => _goToCrumb(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: active
                          ? AppTypography.menuTitle(color: _text)
                          : AppTypography.menuTitle(color: _muted),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!mobile && widget.teamName.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5EF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.teamName,
                style: AppTypography.captionMedium(color: _green),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SportotekaWorkspaceFolderIcon(
              size: 58,
              color: Color(0xFFAAB8B1),
              fillColor: Colors.white,
              showBrandDots: false,
            ),
            const SizedBox(height: 12),
            Text('Не удалось загрузить папки',
                style: AppTypography.sectionTitle(color: _text)),
            const SizedBox(height: 5),
            Text(
              _error ?? 'Неизвестная ошибка',
              textAlign: TextAlign.center,
              style: AppTypography.secondary(color: _muted),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Обновить данные', style: AppTypography.action()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWorkspaceState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SportotekaWorkspaceFolderIcon(
              size: 58,
              color: Color(0xFFAAB8B1),
              fillColor: Colors.white,
              showBrandDots: false,
            ),
            const SizedBox(height: 12),
            Text('Здесь пока пусто',
                style: AppTypography.sectionTitle(color: _text)),
            const SizedBox(height: 5),
            Text(
              _search.text.trim().isNotEmpty
                  ? 'По запросу ничего не найдено.'
                  : 'Создайте папку для схем и методических материалов.',
              textAlign: TextAlign.center,
              style: AppTypography.secondary(color: _muted),
            ),
            if (_search.text.trim().isEmpty) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _busy ? null : _createFolder,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: Text('Новая папка', style: AppTypography.action()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceList({required bool mobile}) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(mobile ? 8 : 14, 2, mobile ? 8 : 14, 28),
      itemCount: _folders.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 52, color: _line),
      itemBuilder: (context, index) {
        final folder = _folders[index];
        final title = _asString(folder['title']).isNotEmpty
            ? _asString(folder['title'])
            : 'Папка';
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: _busy ? null : () => _enterFolder(folder),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  const SportotekaWorkspaceFolderIcon(
                    size: 34,
                    color: Color(0xFF8D9490),
                    fillColor: Color(0xFFF2F3F2),
                    showBrandDots: false,
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
                                style: AppTypography.menuTitle(color: _text),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const _WorkspaceBrandDots(compact: true),
                          ],
                        ),
                        Text(
                          _folderMeta(folder),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Действия с папкой',
                    enabled: !_busy,
                    icon: const Icon(Icons.more_horiz_rounded, size: 19),
                    onSelected: (value) {
                      if (value == 'rename') _renameFolder(folder);
                      if (value == 'delete') _deleteFolder(folder);
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'rename',
                        child: Text('Переименовать', style: AppTypography.menuTitle()),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Удалить', style: AppTypography.menuTitle()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkspaceGrid({required bool mobile}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = mobile ? 142.0 : 154.0;
        final count = (constraints.maxWidth / targetWidth).floor().clamp(2, 12).toInt();
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(mobile ? 10 : 18, 4, mobile ? 10 : 18, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisExtent: mobile ? 142 : 150,
            crossAxisSpacing: mobile ? 6 : 10,
            mainAxisSpacing: mobile ? 6 : 10,
          ),
          itemCount: _folders.length,
          itemBuilder: (context, index) {
            final folder = _folders[index];
            final title = _asString(folder['title']).isNotEmpty
                ? _asString(folder['title'])
                : 'Папка';
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _busy ? null : () => _enterFolder(folder),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  child: Column(
                    children: [
                      const Expanded(
                        child: Center(
                          child: SportotekaWorkspaceFolderIcon(
                            size: 74,
                            color: Color(0xFF8D9490),
                            fillColor: Color(0xFFF2F3F2),
                            showBrandDots: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTypography.menuTitle(color: _text),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const _WorkspaceBrandDots(),
                        ],
                      ),
                      if (!mobile) ...[
                        const SizedBox(height: 2),
                        Text(
                          _folderMeta(folder),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.caption(color: _muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWorkspaceStatusBar() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Text('${_folders.length} объектов',
              style: AppTypography.caption(color: _muted)),
          const Spacer(),
          Flexible(
            child: Text(
              'Место сохранения: $_parentTitle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(color: _muted),
            ),
          ),
        ],
      ),
    );
  }

}

class _WorkspaceBrandDots extends StatelessWidget {
  const _WorkspaceBrandDots({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dot = compact ? 5.0 : 6.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: index == 1
                  ? const Color(0xFF17A36A)
                  : const Color(0xFFB8D9C6),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerSideItem extends StatelessWidget {
  const _PickerSideItem({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? const Color(0xFFF1F7F4) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? const Color(0xFF0B8F55)
                      : const Color(0xFF667169),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.menuTitle(
                      color: selected
                          ? const Color(0xFF101814)
                          : const Color(0xFF4F5A53),
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderTypeChip extends StatelessWidget {
  const _FolderTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF5EF) : const Color(0xFFF7F8F7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF0B8F55) : const Color(0xFFE5E8E5),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.captionMedium(
            color: selected ? const Color(0xFF0B8F55) : const Color(0xFF758079),
          ),
        ),
      ),
    );
  }
}
