import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/community_screen/create_post_editor_screen.dart';
import 'package:sportoteka/presentation/community_screen/post_blocks.dart';

enum _ClubNewsView { all, published, archived, trash }

class CmrClubNewsPanel extends StatefulWidget {
  final int clubId;
  final String clubName;
  final int currentUserId;
  final List<Map<String, dynamic>> teams;
  final int? selectedTeamId;
  final bool canManage;
  final VoidCallback? onChanged;

  const CmrClubNewsPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.currentUserId,
    required this.teams,
    this.selectedTeamId,
    this.canManage = false,
    this.onChanged,
  });

  @override
  State<CmrClubNewsPanel> createState() => _CmrClubNewsPanelState();
}

class _CmrClubNewsPanelState extends State<CmrClubNewsPanel> {
  static const _apiBase = 'https://sportotekaapp.ru/api';
  static const _green = Color(0xFF00A750);
  static const _greenDark = Color(0xFF067A46);
  static const _greenSoft = Color(0xFFF3FAF6);
  static const _line = Color(0xFFE9ECEA);
  static const _soft = Color(0xFFF7F9F8);
  static const _text = Color(0xFF0B0F14);
  static const _muted = Color(0xFF667085);
  static const _red = Color(0xFFD92D20);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _posts = <Map<String, dynamic>>[];
  Map<String, dynamic>? _editingPost;
  bool _editorOpen = false;
  _ClubNewsView _view = _ClubNewsView.all;
  int _teamFilter = 0;

  @override
  void initState() {
    super.initState();
    _teamFilter = widget.selectedTeamId ?? 0;
    _load();
  }

  @override
  void didUpdateWidget(covariant CmrClubNewsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clubId != widget.clubId) {
      _teamFilter = widget.selectedTeamId ?? 0;
      _load();
    }
  }

  int _i(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  String _teamName(Map<String, dynamic> team) {
    final value = _s(team['name'] ?? team['team_name'] ?? team['teamName']);
    return value.isEmpty ? 'Команда' : value;
  }

  int _teamId(Map<String, dynamic> team) =>
      _i(team['id'] ?? team['team_id'] ?? team['teamId']);

  String _normalizeMedia(String raw) {
    var value = raw.trim();
    if (value.isEmpty || value == 'null') return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    value = value.replaceFirst(RegExp(r'^/+'), '');
    if (value.startsWith('uploads/')) {
      return 'https://sportotekaapp.ru/api/$value';
    }
    if (value.startsWith('api/')) {
      return 'https://sportotekaapp.ru/$value';
    }
    return 'https://sportotekaapp.ru/api/uploads/$value';
  }

  List<int> _targetIds(Map<String, dynamic> post) {
    final raw = post['target_team_ids'];
    if (raw is List) {
      return raw.map(_i).where((id) => id > 0).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map(_i).where((id) => id > 0).toList();
        }
      } catch (_) {}
    }
    final fallback = _i(post['team_id']);
    return fallback > 0 ? <int>[fallback] : <int>[];
  }

  List<PostBlock> _blocks(Map<String, dynamic> post) {
    final body = _s(post['body'] ?? post['text']);
    if (body.isEmpty) return const <PostBlock>[];
    final html = body.contains('<')
        ? body
        : '<p>${const HtmlEscape().convert(body)}</p>';
    return PostHtmlParser.htmlToBlocks(html);
  }

  Future<void> _load() async {
    if (widget.clubId <= 0 || widget.currentUserId <= 0) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final uri = Uri.parse('$_apiBase/get_club_news.php').replace(
        queryParameters: <String, String>{
          'viewer_id': '${widget.currentUserId}',
          'club_id': '${widget.clubId}',
          'include_archived': '1',
          if (_view == _ClubNewsView.trash) 'include_deleted': '1',
          'limit': '500',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 || decoded is! Map) {
        throw Exception('HTTP ${response.statusCode}');
      }
      if (decoded['success'] != true) {
        throw Exception(_s(decoded['message'] ?? decoded['error']));
      }
      final raw = decoded['posts'];
      final posts = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _visiblePosts {
    return _posts.where((post) {
      final deleted = _s(post['deleted_at']).isNotEmpty;
      final status = _s(post['status']).toLowerCase();
      switch (_view) {
        case _ClubNewsView.all:
          if (deleted) return false;
          break;
        case _ClubNewsView.published:
          if (deleted || (status.isNotEmpty && status != 'published')) {
            return false;
          }
          break;
        case _ClubNewsView.archived:
          if (deleted || status != 'archived') return false;
          break;
        case _ClubNewsView.trash:
          if (!deleted) return false;
          break;
      }

      if (_teamFilter > 0) {
        final ids = _targetIds(post);
        if (ids.isNotEmpty && !ids.contains(_teamFilter)) return false;
      }
      return true;
    }).toList();
  }

  Future<Map<String, dynamic>> _postForm(
    String endpoint,
    Map<String, String> fields,
  ) async {
    final response = await http
        .post(Uri.parse('$_apiBase/$endpoint'), body: fields)
        .timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'success': false, 'message': 'Некорректный ответ'};
  }

  Future<bool> _confirm(String title, String text, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action, style: const TextStyle(color: _red)),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _delete(Map<String, dynamic> post) async {
    if (!await _confirm(
      'Удалить новость?',
      'Новость будет перемещена в корзину. Клубный администратор сможет её восстановить.',
      'Удалить',
    )) return;
    final data = await _postForm('delete_post.php', <String, String>{
      'post_id': '${_i(post['id'])}',
      'user_id': '${widget.currentUserId}',
    });
    if (data['success'] == true) {
      await _load();
      widget.onChanged?.call();
    } else {
      _snack(_s(data['message'] ?? data['error']).isEmpty
          ? 'Не удалось удалить новость'
          : _s(data['message'] ?? data['error']));
    }
  }

  Future<void> _restore(Map<String, dynamic> post) async {
    final data = await _postForm('restore_club_news.php', <String, String>{
      'post_id': '${_i(post['id'])}',
      'user_id': '${widget.currentUserId}',
    });
    if (data['success'] == true) {
      await _load();
      widget.onChanged?.call();
    } else {
      _snack(_s(data['message'] ?? data['error']));
    }
  }

  Future<void> _setStatus(Map<String, dynamic> post, String status) async {
    final data = await _postForm('set_club_news_status.php', <String, String>{
      'post_id': '${_i(post['id'])}',
      'user_id': '${widget.currentUserId}',
      'status': status,
    });
    if (data['success'] == true) {
      await _load();
      widget.onChanged?.call();
    } else {
      _snack(_s(data['message'] ?? data['error']));
    }
  }

  void _snack(String text) {
    if (!mounted || text.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openCreate() {
    setState(() {
      _editingPost = null;
      _editorOpen = true;
    });
  }

  void _openEdit(Map<String, dynamic> post) {
    if (!widget.canManage || post['can_edit'] != true) return;
    setState(() {
      _editingPost = Map<String, dynamic>.from(post);
      _editorOpen = true;
    });
  }

  Future<void> _closeEditor({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      _editorOpen = false;
      _editingPost = null;
    });
    if (refresh) {
      await _load();
      widget.onChanged?.call();
    }
  }

  Widget _editor() {
    final post = _editingPost;
    return CreatePostEditorScreen(
      sportName: 'Футбол',
      isEdit: post != null,
      postId: post == null ? null : _i(post['id']),
      initialTitle: post == null ? '' : _s(post['title']),
      initialCoverUrl: post == null
          ? ''
          : _normalizeMedia(_s(post['image'] ?? post['image_url'])),
      initialBlocks: post == null ? const <PostBlock>[] : _blocks(post),
      embedded: true,
      clubId: widget.clubId,
      teamId: 0,
      teamName: '',
      visibility: 'club_internal',
      targetTeamIds: post == null ? const <int>[] : _targetIds(post),
      availableTargetTeams: widget.teams,
      allowWholeClubTarget: true,
      authorLabel: widget.clubName,
      onClose: () => _closeEditor(),
      onSaved: () => _closeEditor(refresh: true),
    );
  }

  String _audience(Map<String, dynamic> post) {
    final ids = _targetIds(post);
    if (ids.isEmpty) return 'Весь клуб';
    final names = <String>[];
    for (final id in ids) {
      for (final team in widget.teams) {
        if (_teamId(team) == id) {
          names.add(_teamName(team));
          break;
        }
      }
    }
    if (names.isEmpty) return '${ids.length} команд(ы)';
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  String _author(Map<String, dynamic> post) {
    final name = '${_s(post['first_name'])} ${_s(post['last_name'])}'.trim();
    if (name.isNotEmpty) return name;
    final author = _s(post['author']);
    return author.isEmpty ? 'Пресс-служба' : author;
  }

  Widget _postTile(Map<String, dynamic> post) {
    final deleted = _s(post['deleted_at']).isNotEmpty;
    final archived = _s(post['status']).toLowerCase() == 'archived';
    final title = _s(post['title']).isEmpty ? 'Без заголовка' : _s(post['title']);
    final body = _s(post['body'])
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: deleted || !widget.canManage ? null : () => _openEdit(post),
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _line, width: .6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: deleted
                      ? const Color(0xFFFFF1F1)
                      : archived
                          ? const Color(0xFFFFF7E8)
                          : _greenSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  deleted
                      ? Icons.delete_outline_rounded
                      : archived
                          ? Icons.archive_outlined
                          : Icons.newspaper_rounded,
                  size: 19,
                  color: deleted
                      ? _red
                      : archived
                          ? const Color(0xFFF59E0B)
                          : _greenDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.itemTitle(color: _text),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(color: _muted),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      '${_audience(post)} · ${_author(post)} · ${_s(post['created_at'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.commentMeta(color: _muted),
                    ),
                    if (_i(post['updated_by']) > 0 &&
                        _i(post['updated_by']) != _i(post['user_id'])) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Изменено администратором клуба',
                        style: AppTypography.commentMeta(color: _greenDark),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.canManage)
                PopupMenuButton<String>(
                  tooltip: 'Действия',
                  onSelected: (value) {
                    if (value == 'edit') _openEdit(post);
                    if (value == 'archive') _setStatus(post, 'archived');
                    if (value == 'publish') _setStatus(post, 'published');
                    if (value == 'delete') _delete(post);
                    if (value == 'restore') _restore(post);
                  },
                  itemBuilder: (_) {
                    if (deleted) {
                      return const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'restore',
                          child: Text('Восстановить'),
                        ),
                      ];
                    }
                    return <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Редактировать'),
                      ),
                      PopupMenuItem<String>(
                        value: archived ? 'publish' : 'archive',
                        child: Text(archived ? 'Опубликовать снова' : 'Снять с публикации'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Удалить', style: TextStyle(color: _red)),
                      ),
                    ];
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    Widget filter(String label, _ClubNewsView value) {
      return ChoiceChip(
        label: Text(label),
        selected: _view == value,
        onSelected: (_) async {
          setState(() => _view = value);
          await _load();
        },
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line, width: .6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Новости клуба',
                      style: AppTypography.screenTitle(color: _text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Внутренние новости · не попадают в общую ленту',
                      style: AppTypography.caption(color: _muted),
                    ),
                  ],
                ),
              ),
              if (widget.canManage)
                FilledButton.icon(
                  onPressed: _openCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Новая новость'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      filter('Все', _ClubNewsView.all),
                      const SizedBox(width: 6),
                      filter('Опубликованы', _ClubNewsView.published),
                      const SizedBox(width: 6),
                      filter('Сняты', _ClubNewsView.archived),
                      const SizedBox(width: 6),
                      filter('Корзина', _ClubNewsView.trash),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<int>(
                value: _teamFilter,
                underline: const SizedBox.shrink(),
                items: <DropdownMenuItem<int>>[
                  const DropdownMenuItem<int>(
                    value: 0,
                    child: Text('Все команды'),
                  ),
                  ...widget.teams
                      .where((team) => _teamId(team) > 0)
                      .map(
                        (team) => DropdownMenuItem<int>(
                          value: _teamId(team),
                          child: Text(_teamName(team)),
                        ),
                      ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _teamFilter = value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_editorOpen) return _editor();

    final visible = _visiblePosts;
    return Container(
      color: const Color(0xFFF6F7F6),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              _toolbar(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _green),
                      )
                    : _error != null
                        ? Center(
                            child: TextButton(
                              onPressed: _load,
                              child: Text('$_error\nПовторить'),
                            ),
                          )
                        : visible.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.newspaper_outlined,
                                        size: 36,
                                        color: _muted,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _view == _ClubNewsView.trash
                                            ? 'Корзина пуста'
                                            : 'Новостей пока нет',
                                        style: AppTypography.sectionTitle(
                                          color: _text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                color: _green,
                                onRefresh: _load,
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: visible.length,
                                  itemBuilder: (_, index) =>
                                      _postTile(visible[index]),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
