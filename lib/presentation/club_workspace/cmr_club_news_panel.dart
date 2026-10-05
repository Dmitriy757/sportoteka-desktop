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
  final Set<String> _expandedPostKeys = <String>{};

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

  String _dateLabel(dynamic raw) {
    final value = _s(raw);
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (parsed == null) return value;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year} · ${two(parsed.hour)}:${two(parsed.minute)}';
  }

  String _cover(Map<String, dynamic> post) =>
      _normalizeMedia(_s(post['image'] ?? post['image_url'] ?? post['cover_url']));

  String _statusLabel(Map<String, dynamic> post) {
    if (_s(post['deleted_at']).isNotEmpty) return 'В корзине';
    final status = _s(post['status']).toLowerCase();
    if (status == 'archived') return 'Снята';
    return 'Опубликована';
  }

  Color _statusColor(Map<String, dynamic> post) {
    if (_s(post['deleted_at']).isNotEmpty) return _red;
    if (_s(post['status']).toLowerCase() == 'archived') {
      return const Color(0xFFC77700);
    }
    return _greenDark;
  }

  Color _statusSoft(Map<String, dynamic> post) {
    if (_s(post['deleted_at']).isNotEmpty) return const Color(0xFFFFF1F1);
    if (_s(post['status']).toLowerCase() == 'archived') {
      return const Color(0xFFFFF7E8);
    }
    return _greenSoft;
  }

  int _viewCount(_ClubNewsView view) {
    return _posts.where((post) {
      final deleted = _s(post['deleted_at']).isNotEmpty;
      final status = _s(post['status']).toLowerCase();
      switch (view) {
        case _ClubNewsView.all:
          return !deleted;
        case _ClubNewsView.published:
          return !deleted && (status.isEmpty || status == 'published');
        case _ClubNewsView.archived:
          return !deleted && status == 'archived';
        case _ClubNewsView.trash:
          return deleted;
      }
    }).length;
  }

  Widget _metaPill(IconData icon, String text, {Color? color}) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final c = color ?? _muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.commentMeta(color: c),
            ),
          ),
        ],
      ),
    );
  }

  String _authorInitials(Map<String, dynamic> post) {
    final value = _author(post).trim();
    if (value.isEmpty) return 'С';
    final parts = value.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'С';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  Widget _authorAvatar(Map<String, dynamic> post) {
    final avatar = _normalizeMedia(
      _s(post['author_avatar'] ?? post['avatar'] ?? post['avatar_url']),
    );
    if (avatar.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatar,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _authorAvatarFallback(post),
        ),
      );
    }
    return _authorAvatarFallback(post);
  }

  Widget _authorAvatarFallback(Map<String, dynamic> post) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _greenSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        _authorInitials(post),
        style: AppTypography.custom(
          size: 11.5,
          weight: FontWeight.w700,
          color: _greenDark,
          height: 1,
        ),
      ),
    );
  }

  Widget _newsBadge(Map<String, dynamic> post) {
    final deleted = _s(post['deleted_at']).isNotEmpty;
    final archived = _s(post['status']).toLowerCase() == 'archived';
    final color = _statusColor(post);
    final text = deleted
        ? 'Корзина'
        : archived
            ? 'Снята'
            : _audience(post);

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: deleted || archived ? _statusSoft(post) : _greenSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4.5,
            height: 4.5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.custom(
                size: 9.8,
                weight: FontWeight.w600,
                color: deleted || archived ? color : _greenDark,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _postKey(Map<String, dynamic> post) {
    final id = _i(post['id']);
    if (id > 0) return 'id:$id';
    return '${_s(post['created_at'])}|${_s(post['title'])}|${_s(post['user_id'])}';
  }

  String _plainPostBody(Map<String, dynamic> post) {
    var text = _s(post['body'] ?? post['text']);
    if (text.isEmpty) return '';
    text = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    return text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  bool _bodyNeedsExpansion(String body) {
    return body.length > 220 || body.split('\n').length > 4;
  }

  Widget _postTile(Map<String, dynamic> post) {
    final deleted = _s(post['deleted_at']).isNotEmpty;
    final archived = _s(post['status']).toLowerCase() == 'archived';
    final title = _s(post['title']).isEmpty ? 'Без заголовка' : _s(post['title']);
    final body = _plainPostBody(post);
    final postKey = _postKey(post);
    final expanded = _expandedPostKeys.contains(postKey);
    final canExpand = _bodyNeedsExpansion(body);
    final cover = _cover(post);
    final canEditThis = widget.canManage && post['can_edit'] == true && !deleted;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final horizontal = compact ? 10.0 : 14.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: canEditThis ? () => _openEdit(post) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line.withOpacity(.82), width: .75),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(.018),
                      blurRadius: 18,
                      spreadRadius: -12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 12 : 14,
                        compact ? 12 : 14,
                        compact ? 8 : 10,
                        10,
                      ),
                      child: Row(
                        children: [
                          _authorAvatar(post),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _author(post),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.itemTitle(color: _text),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _dateLabel(post['created_at']),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption(color: _muted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _newsBadge(post),
                          if (widget.canManage) ...[
                            const SizedBox(width: 2),
                            PopupMenuButton<String>(
                              tooltip: 'Действия',
                              elevation: 10,
                              color: Colors.white,
                              surfaceTintColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                size: 20,
                                color: _muted,
                              ),
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
                                      child: Row(
                                        children: [
                                          Icon(Icons.restore_rounded, size: 18),
                                          SizedBox(width: 9),
                                          Text('Восстановить'),
                                        ],
                                      ),
                                    ),
                                  ];
                                }
                                return <PopupMenuEntry<String>>[
                                  if (post['can_edit'] == true)
                                    const PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18),
                                          SizedBox(width: 9),
                                          Text('Редактировать'),
                                        ],
                                      ),
                                    ),
                                  PopupMenuItem<String>(
                                    value: archived ? 'publish' : 'archive',
                                    child: Row(
                                      children: [
                                        Icon(
                                          archived
                                              ? Icons.publish_rounded
                                              : Icons.archive_outlined,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 9),
                                        Text(
                                          archived
                                              ? 'Опубликовать снова'
                                              : 'Снять с публикации',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: _red,
                                        ),
                                        SizedBox(width: 9),
                                        Text(
                                          'Удалить',
                                          style: TextStyle(color: _red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ];
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 12 : 14,
                        0,
                        compact ? 12 : 14,
                        8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _statusColor(post),
                                shape: BoxShape.circle,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: _statusColor(post).withOpacity(.18),
                                    blurRadius: 8,
                                    spreadRadius: .4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: compact ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.custom(
                                size: compact ? 16.0 : 16.5,
                                weight: FontWeight.w600,
                                color: _text,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (body.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 14,
                          0,
                          compact ? 12 : 14,
                          10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              body,
                              maxLines: expanded ? null : (cover.isEmpty ? 5 : 4),
                              overflow: expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: AppTypography.custom(
                                size: compact ? 12.8 : 13.2,
                                weight: FontWeight.w400,
                                color: _text,
                                height: 1.42,
                              ),
                            ),
                            if (canExpand) ...[
                              const SizedBox(height: 6),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    setState(() {
                                      if (expanded) {
                                        _expandedPostKeys.remove(postKey);
                                      } else {
                                        _expandedPostKeys.add(postKey);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 3,
                                    ),
                                    child: Text(
                                      expanded ? 'Свернуть' : 'Показать полностью',
                                      style: AppTypography.custom(
                                        size: 11.7,
                                        weight: FontWeight.w600,
                                        color: _greenDark,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (cover.isNotEmpty)
                      AspectRatio(
                        aspectRatio: compact ? 1.35 : 1.65,
                        child: Container(
                          width: double.infinity,
                          color: _soft,
                          child: Image.network(
                            cover,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: _soft,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 30,
                                color: _muted,
                              ),
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: _green,
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 12 : 14,
                        9,
                        compact ? 12 : 14,
                        11,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.groups_2_outlined,
                            size: 17,
                            color: _muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _audience(post),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.commentMeta(color: _muted),
                            ),
                          ),
                          if (_i(post['updated_by']) > 0 &&
                              _i(post['updated_by']) != _i(post['user_id'])) ...[
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.edit_note_rounded,
                              size: 16,
                              color: _greenDark,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Изменено',
                              style: AppTypography.commentMeta(color: _greenDark),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filterButton(
    String label,
    _ClubNewsView value,
    IconData icon,
  ) {
    final selected = _view == value;
    final count = _viewCount(value);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          if (_view == value) return;
          setState(() => _view = value);
          await _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? _greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFFD7EEE1) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? _greenDark : _muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption(
                  color: selected ? _greenDark : _text,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : _soft,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.commentMeta(
                    color: selected ? _greenDark : _muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamSelector() {
    String label = 'Все команды';
    if (_teamFilter > 0) {
      for (final team in widget.teams) {
        if (_teamId(team) == _teamFilter) {
          label = _teamName(team);
          break;
        }
      }
    }

    return PopupMenuButton<int>(
      tooltip: 'Фильтр по команде',
      initialValue: _teamFilter,
      elevation: 10,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) => setState(() => _teamFilter = value),
      itemBuilder: (_) => <PopupMenuEntry<int>>[
        const PopupMenuItem<int>(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.groups_2_outlined, size: 18),
              SizedBox(width: 9),
              Text('Все команды'),
            ],
          ),
        ),
        ...widget.teams.where((team) => _teamId(team) > 0).map(
              (team) => PopupMenuItem<int>(
                value: _teamId(team),
                child: Text(_teamName(team)),
              ),
            ),
      ],
      child: Container(
        height: 36,
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_2_outlined, size: 16, color: _muted),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(color: _text),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final veryCompact = constraints.maxWidth < 470;

        final titleBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: compact ? 38 : 42,
              height: compact ? 38 : 42,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _green.withOpacity(.28),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _green.withOpacity(.58),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _green.withOpacity(.16),
                            blurRadius: 10,
                            spreadRadius: .2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Новости клуба',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.screenTitle(color: _text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.clubName.isEmpty
                        ? 'Внутренняя клубная лента'
                        : '${widget.clubName} · внутренняя лента',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(color: _muted),
                  ),
                ],
              ),
            ),
          ],
        );

        final createButton = widget.canManage
            ? SizedBox(
                height: 38,
                child: FilledButton.icon(
                  onPressed: _openCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(veryCompact ? 'Создать' : 'Новая новость'),
                ),
              )
            : const SizedBox.shrink();

        final filters = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterButton('Все', _ClubNewsView.all, Icons.grid_view_rounded),
              const SizedBox(width: 4),
              _filterButton(
                'Опубликованы',
                _ClubNewsView.published,
                Icons.check_circle_outline_rounded,
              ),
              const SizedBox(width: 4),
              _filterButton(
                'Сняты',
                _ClubNewsView.archived,
                Icons.archive_outlined,
              ),
              const SizedBox(width: 4),
              _filterButton(
                'Корзина',
                _ClubNewsView.trash,
                Icons.delete_outline_rounded,
              ),
            ],
          ),
        );

        return Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 16,
            compact ? 12 : 14,
            compact ? 12 : 16,
            10,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _line, width: .7)),
          ),
          child: Column(
            children: [
              if (compact) ...[
                titleBlock,
                if (widget.canManage) ...[
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: createButton),
                ],
              ] else
                Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 14),
                    createButton,
                  ],
                ),
              const SizedBox(height: 11),
              if (veryCompact) ...[
                Align(alignment: Alignment.centerLeft, child: _teamSelector()),
                const SizedBox(height: 7),
                filters,
              ] else
                Row(
                  children: [
                    Expanded(child: filters),
                    const SizedBox(width: 10),
                    _teamSelector(),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState() {
    final trash = _view == _ClubNewsView.trash;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: trash ? const Color(0xFFFFF4F3) : _greenSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                trash ? Icons.delete_outline_rounded : Icons.newspaper_outlined,
                size: 27,
                color: trash ? _red : _greenDark,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              trash ? 'Корзина пуста' : 'Новостей пока нет',
              style: AppTypography.sectionTitle(color: _text),
            ),
            const SizedBox(height: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                trash
                    ? 'Удалённые публикации появятся здесь и их можно будет восстановить.'
                    : widget.canManage
                        ? 'Создай первую внутреннюю новость для клуба или выбранных команд.'
                        : 'Когда пресс-служба клуба опубликует новость, она появится здесь.',
                textAlign: TextAlign.center,
                style: AppTypography.caption(color: _muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_editorOpen) return _editor();

    final visible = _visiblePosts;
    return Container(
      color: const Color(0xFFF4F6F5),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: const Color(0xFFFBFCFB),
          child: Column(
            children: [
              _toolbar(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: _green,
                            strokeWidth: 2.6,
                          ),
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.cloud_off_outlined,
                                    size: 34,
                                    color: _muted,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.caption(color: _muted),
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton.icon(
                                    onPressed: _load,
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    label: const Text('Повторить'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : visible.isEmpty
                            ? _emptyState()
                            : RefreshIndicator(
                                color: _green,
                                onRefresh: _load,
                                child: ListView.builder(
                                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: visible.length,
                                  itemBuilder: (_, index) => _postTile(visible[index]),
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
