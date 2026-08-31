import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/utils/pref_utils.dart';

import 'post_composer_screen.dart';
import 'post_detail_screen.dart';

class PostsScreen extends StatefulWidget {
  final String? selectedCategory;
  final String? selectedTeam;

  const PostsScreen({
    super.key,
    this.selectedCategory,
    this.selectedTeam,
  });

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const Color _green = Color(0xFF00A750);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF667085);
  static const Color _line = Color(0xFFE5E7EB);
  static const Color _soft = Color(0xFFF7F8FA);

  final TextEditingController _searchController = TextEditingController();

  List<_PostItem> _allPosts = <_PostItem>[];
  List<_PostItem> _filteredPosts = <_PostItem>[];
  String? _selectedSport;
  String? _selectedTeam;
  int _currentUserId = 0;
  bool _mineOnly = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedSport = widget.selectedCategory;
    _selectedTeam = widget.selectedTeam;
    _searchController.addListener(_onSearchChanged);
    _loadInitial();
  }

  @override
  void didUpdateWidget(covariant PostsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory ||
        oldWidget.selectedTeam != widget.selectedTeam) {
      _selectedSport = widget.selectedCategory;
      _selectedTeam = widget.selectedTeam;
      setState(_applyFilters);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final userId = await PrefUtils.getUserId();
    if (mounted) {
      setState(() => _currentUserId = userId ?? 0);
    }
    await loadPosts();
  }

  Future<void> loadPosts() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await http
          .get(Uri.parse('$_apiBase/get_posts.php'))
          .timeout(const Duration(seconds: 18));

      if (response.statusCode != 200) {
        throw Exception('Сервер вернул ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final dynamic rawList = decoded is List
          ? decoded
          : decoded is Map
              ? (decoded['posts'] ?? decoded['data'] ?? decoded['items'] ?? const [])
              : const [];

      if (rawList is! List) {
        throw const FormatException('Неверный формат списка публикаций');
      }

      final posts = rawList
          .whereType<Map>()
          .map((raw) => _PostItem.fromMap(Map<String, dynamic>.from(raw)))
          .where((post) => post.isUserPost)
          .toList()
        ..sort((a, b) {
          final ad = a.createdAt;
          final bd = b.createdAt;
          if (ad != null && bd != null) return bd.compareTo(ad);
          return b.id.compareTo(a.id);
        });

      if (!mounted) return;
      setState(() {
        _allPosts = posts;
        _applyFilters();
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

  void _onSearchChanged() {
    if (!mounted) return;
    setState(_applyFilters);
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final category = (_selectedSport ?? '').trim().toLowerCase();
    final team = (_selectedTeam ?? '').trim().toLowerCase();

    _filteredPosts = _allPosts.where((post) {
      if (category.isNotEmpty && post.category.toLowerCase() != category) {
        return false;
      }
      if (team.isNotEmpty && post.team.toLowerCase() != team) return false;
      if (_mineOnly && _currentUserId > 0 && post.userId != _currentUserId) {
        return false;
      }
      if (query.isEmpty) return true;

      if (query.startsWith('#')) {
        final normalized = query.replaceAll(RegExp(r'\s+'), '');
        return post.hashtags.any((tag) => tag.toLowerCase() == normalized) ||
            post.searchText.contains(query);
      }
      return post.searchText.contains(query);
    }).toList();
  }

  Future<void> _openComposer({_PostItem? post}) async {
    if (_currentUserId <= 0) {
      _showMessage('Не удалось определить пользователя. Войдите в профиль ещё раз.');
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PostComposerScreen(
          initialPost: post?.raw,
          selectedCategory: _selectedSport,
          selectedTeam: _selectedTeam,
        ),
      ),
    );

    if (changed == true) await loadPosts();
  }

  Future<void> _openPost(_PostItem post) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: post.rawForDetail),
      ),
    );
    await loadPosts();
  }

  void _searchByHashtag(String hashtag) {
    _searchController.value = TextEditingValue(
      text: hashtag,
      selection: TextSelection.collapsed(offset: hashtag.length),
    );
  }

  Future<void> _showPostMenu(_PostItem post) async {
    final own = _currentUserId > 0 && post.userId == _currentUserId;
    if (!own) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: _ink),
                  title: const Text(
                    'Редактировать публикацию',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openComposer(post: post);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD92D20)),
                  title: const Text(
                    'Удалить',
                    style: TextStyle(
                      color: Color(0xFFD92D20),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deletePost(post);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePost(_PostItem post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить публикацию?'),
        content: const Text('Публикация будет удалена без возможности восстановления.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await http.post(
        Uri.parse('$_apiBase/delete_post.php'),
        body: <String, String>{
          'user_id': _currentUserId.toString(),
          'post_id': post.id.toString(),
        },
      ).timeout(const Duration(seconds: 16));

      final dynamic data = response.body.trim().isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (data == null ||
              data is! Map ||
              data['success'] == true ||
              data['status'] == 'success' ||
              data['status'] == 'deleted');
      if (!ok) throw Exception('Не удалось удалить публикацию');

      if (!mounted) return;
      setState(() {
        _allPosts.removeWhere((item) => item.id == post.id);
        _applyFilters();
      });
      _showMessage('Публикация удалена');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 700;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(compact),
                const SizedBox(height: 12),
                _buildSearch(compact),
                const SizedBox(height: 10),
                _buildFeedTabs(compact),
                const SizedBox(height: 12),
                if (_loading && _allPosts.isEmpty)
                  const _PostsLoading()
                else if (_error != null && _allPosts.isEmpty)
                  _PostsError(message: _error!, onRetry: loadPosts)
                else if (_filteredPosts.isEmpty)
                  _PostsEmpty(
                    hasQuery: _searchController.text.trim().isNotEmpty,
                    mineOnly: _mineOnly,
                    onCreate: () => _openComposer(),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(bottom: compact ? 12 : 24),
                    itemCount: _filteredPosts.length,
                    separatorBuilder: (_, __) => SizedBox(height: compact ? 10 : 14),
                    itemBuilder: (context, index) {
                      final post = _filteredPosts[index];
                      return _PostCard(
                        key: ValueKey('post_${post.id}'),
                        post: post,
                        compact: compact,
                        isOwn: _currentUserId > 0 && post.userId == _currentUserId,
                        onOpen: () => _openPost(post),
                        onComments: () => _openPost(post),
                        onHashtag: _searchByHashtag,
                        onMenu: () => _showPostMenu(post),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool compact) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Публикации',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Фото, подписи, хэштеги и обсуждения',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading ? null : loadPosts,
            icon: _loading
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: _ink),
          ),
          const SizedBox(width: 4),
          if (compact)
            Material(
              color: _green,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Новая публикация',
                onPressed: () => _openComposer(),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 27),
              ),
            )
          else
            FilledButton.icon(
              onPressed: () => _openComposer(),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text(
                'Новая публикация',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool compact) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 0),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Поиск по публикациям и #хэштегам',
          hintStyle: const TextStyle(
            color: Color(0xFF98A2B3),
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 21),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Очистить',
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close_rounded, color: _muted, size: 19),
                ),
          filled: true,
          fillColor: _soft,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: _green, width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedTabs(bool compact) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 0),
      child: Row(
        children: [
          _PostFilterChip(
            label: 'Все',
            icon: Icons.dynamic_feed_outlined,
            selected: !_mineOnly,
            onTap: () => setState(() {
              _mineOnly = false;
              _applyFilters();
            }),
          ),
          const SizedBox(width: 8),
          _PostFilterChip(
            label: 'Мои',
            icon: Icons.person_outline_rounded,
            selected: _mineOnly,
            enabled: _currentUserId > 0,
            onTap: () => setState(() {
              _mineOnly = true;
              _applyFilters();
            }),
          ),
          const Spacer(),
          Text(
            '${_filteredPosts.length}',
            style: const TextStyle(
              color: _muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostItem {
  final Map<String, dynamic> raw;
  final int id;
  final int userId;
  final String title;
  final String body;
  final String author;
  final String avatar;
  final String category;
  final String team;
  final String link;
  final DateTime? createdAt;
  final int likes;
  final int comments;
  final List<String> media;
  final List<String> hashtags;

  const _PostItem({
    required this.raw,
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.author,
    required this.avatar,
    required this.category,
    required this.team,
    required this.link,
    required this.createdAt,
    required this.likes,
    required this.comments,
    required this.media,
    required this.hashtags,
  });

  bool get isUserPost => link.trim().isEmpty;

  String get searchText => '$title $body $author $category $team ${hashtags.join(' ')}'.toLowerCase();

  Map<String, dynamic> get rawForDetail => <String, dynamic>{
        ...raw,
        'id': id,
        'user_id': userId,
        'title': title,
        'body': body,
        'author': author,
        'created_at': createdAt?.toIso8601String() ?? _value(raw['created_at']),
        'image': media.isEmpty ? '' : media.first,
        'likes_count': likes,
        'comments_count': comments,
      };

  factory _PostItem.fromMap(Map<String, dynamic> raw) {
    final body = _plainText(
      raw['body'] ?? raw['text'] ?? raw['caption'] ?? raw['description'],
    );
    final title = _plainText(raw['title']);
    final first = _value(raw['first_name'] ?? raw['firstname']);
    final last = _value(raw['last_name'] ?? raw['lastname']);
    final fullName = '$first $last'.trim();
    final author = _firstNonEmpty(<dynamic>[
      raw['author_name'],
      raw['author'],
      raw['full_name'],
      raw['username'],
      fullName,
    ]);

    final media = _extractMedia(raw);
    final tags = <String>{};
    for (final match in RegExp(r'#[A-Za-zА-Яа-яЁё0-9_]+').allMatches('$title $body')) {
      final tag = match.group(0);
      if (tag != null && tag.length > 1) tags.add(tag);
    }

    return _PostItem(
      raw: raw,
      id: _asInt(raw['id'] ?? raw['post_id']),
      userId: _asInt(raw['user_id'] ?? raw['author_id'] ?? raw['owner_user_id']),
      title: title,
      body: body,
      author: author.isEmpty ? 'Пользователь' : author,
      avatar: _absoluteUrl(
        _firstNonEmpty(<dynamic>[
          raw['author_avatar'],
          raw['avatar_url'],
          raw['avatar'],
          raw['photo'],
          raw['user_photo'],
        ]),
      ),
      category: _value(raw['category']),
      team: _value(raw['team'] ?? raw['team_name']),
      link: _value(raw['link']),
      createdAt: _parseDate(raw['created_at'] ?? raw['date'] ?? raw['published_at']),
      likes: _asInt(raw['likes_count'] ?? raw['likes'] ?? raw['like_count']),
      comments: _asInt(
        raw['comments_count'] ?? raw['comments'] ?? raw['comment_count'],
      ),
      media: media,
      hashtags: tags.toList(),
    );
  }

  static String _value(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _value(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_value(value)) ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    final text = _value(value);
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String _plainText(dynamic value) {
    var text = _value(value);
    if (!text.contains('<')) return text;
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    return text.trim();
  }

  static String _absoluteUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    return 'https://sportotekaapp.ru/$clean';
  }

  static List<String> _extractMedia(Map<String, dynamic> raw) {
    final result = <String>[];

    void add(dynamic value) {
      final text = _value(value);
      if (text.isEmpty) return;
      final url = _absoluteUrl(text);
      if (url.isNotEmpty && !result.contains(url)) result.add(url);
    }

    void addDynamic(dynamic value) {
      if (value == null) return;
      if (value is List) {
        for (final item in value) {
          if (item is Map) {
            add(item['url'] ?? item['image'] ?? item['image_url'] ?? item['src']);
          } else {
            add(item);
          }
        }
        return;
      }
      if (value is Map) {
        add(value['url'] ?? value['image'] ?? value['image_url'] ?? value['src']);
        return;
      }
      final text = _value(value);
      if (text.startsWith('[') || text.startsWith('{')) {
        try {
          addDynamic(jsonDecode(text));
          return;
        } catch (_) {}
      }
      if (text.contains(',')) {
        for (final part in text.split(',')) {
          add(part);
        }
      } else {
        add(text);
      }
    }

    addDynamic(raw['images']);
    addDynamic(raw['image_urls']);
    addDynamic(raw['media']);
    addDynamic(raw['attachments']);
    add(raw['image'] ?? raw['image_url'] ?? raw['cover'] ?? raw['photo']);
    return result;
  }
}

class _PostCard extends StatelessWidget {
  final _PostItem post;
  final bool compact;
  final bool isOwn;
  final VoidCallback onOpen;
  final VoidCallback onComments;
  final ValueChanged<String> onHashtag;
  final VoidCallback onMenu;

  const _PostCard({
    super.key,
    required this.post,
    required this.compact,
    required this.isOwn,
    required this.onOpen,
    required this.onComments,
    required this.onHashtag,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(compact ? 0 : 18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: compact ? const Color(0xFFF0F1F3) : _PostsScreenState._line,
            ),
            borderRadius: BorderRadius.circular(compact ? 0 : 18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTop(),
              if (post.media.isNotEmpty)
                _PostMediaCarousel(
                  postId: post.id,
                  media: post.media,
                  compact: compact,
                ),
              _buildActions(),
              _buildCaption(),
            ],
          ),
        ),
      ),
    );

    if (!compact) return card;
    return card;
  }

  Widget _buildTop() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 9),
      child: Row(
        children: [
          _PostAvatar(url: post.avatar, name: post.author),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        post.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _PostsScreenState._ink,
                          fontSize: 13.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isOwn) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _PostsScreenState._green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _postMeta(post),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _PostsScreenState._muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isOwn)
            IconButton(
              tooltip: 'Действия',
              onPressed: onMenu,
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: _PostsScreenState._ink,
                size: 23,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final commentsText = post.comments > 0 ? '${post.comments}' : '';
    final likesText = post.likes > 0 ? '${post.likes}' : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 0),
      child: Row(
        children: [
          _PostAction(
            icon: Icons.favorite_border_rounded,
            label: likesText,
            tooltip: 'Открыть реакции',
            onTap: onOpen,
          ),
          const SizedBox(width: 3),
          _PostAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: commentsText,
            tooltip: 'Комментарии',
            onTap: onComments,
          ),
          const Spacer(),
          _PostAction(
            icon: Icons.open_in_new_rounded,
            label: '',
            tooltip: 'Открыть публикацию',
            onTap: onOpen,
          ),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    final hasText = post.body.isNotEmpty || post.title.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 5, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.title.isNotEmpty) ...[
            Text(
              post.title,
              style: const TextStyle(
                color: _PostsScreenState._ink,
                fontSize: 13.5,
                height: 1.3,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (post.body.isNotEmpty) const SizedBox(height: 4),
          ],
          if (post.body.isNotEmpty)
            Text(
              post.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 13,
                height: 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (!hasText && post.media.isNotEmpty)
            const Text(
              'Публикация',
              style: TextStyle(
                color: _PostsScreenState._muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (post.hashtags.isNotEmpty) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 4,
              runSpacing: 3,
              children: post.hashtags.take(8).map((tag) {
                return InkWell(
                  onTap: () => onHashtag(tag),
                  borderRadius: BorderRadius.circular(5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: _PostsScreenState._green,
                        fontSize: 12.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          InkWell(
            onTap: onComments,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                post.comments > 0
                    ? 'Посмотреть комментарии (${post.comments})'
                    : 'Добавить комментарий',
                style: const TextStyle(
                  color: _PostsScreenState._muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _postMeta(_PostItem post) {
    final parts = <String>[];
    final time = _relativeDate(post.createdAt);
    if (time.isNotEmpty) parts.add(time);
    if (post.team.isNotEmpty) {
      parts.add(post.team);
    } else if (post.category.isNotEmpty) {
      parts.add(post.category);
    }
    return parts.isEmpty ? 'SPORTOTEKA' : parts.join(' • ');
  }

  static String _relativeDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    var diff = now.difference(date);
    if (diff.isNegative) diff = Duration.zero;
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин';
    if (diff.inHours < 24) return '${diff.inHours} ч';
    if (diff.inDays < 7) return '${diff.inDays} дн';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}

class _PostMediaCarousel extends StatefulWidget {
  final int postId;
  final List<String> media;
  final bool compact;

  const _PostMediaCarousel({
    required this.postId,
    required this.media,
    required this.compact,
  });

  @override
  State<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<_PostMediaCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: widget.media.length,
            physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) {
              return ColoredBox(
                color: _PostsScreenState._soft,
                child: Image.network(
                  widget.media[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: _PostsScreenState._muted,
                      size: 36,
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.media.length > 1) ...[
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.58),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_page + 1}/${widget.media.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 9,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.media.length, (index) {
                  final selected = index == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 7 : 5,
                    height: selected ? 7 : 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: selected
                          ? _PostsScreenState._green
                          : Colors.white.withOpacity(.82),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 2),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PostAvatar extends StatelessWidget {
  final String url;
  final String name;

  const _PostAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'S' : name.trim().characters.first.toUpperCase();
    return Container(
      width: 38,
      height: 38,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _PostsScreenState._green.withOpacity(.55), width: 1.3),
      ),
      child: ClipOval(
        child: url.isEmpty
            ? ColoredBox(
                color: _PostsScreenState._soft,
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: _PostsScreenState._ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: _PostsScreenState._soft,
                  child: Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  const _PostAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: _PostsScreenState._ink),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: _PostsScreenState._ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PostFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PostFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _PostsScreenState._ink : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? _PostsScreenState._ink : _PostsScreenState._line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : _PostsScreenState._muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _PostsScreenState._ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostsLoading extends StatelessWidget {
  const _PostsLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
    );
  }
}

class _PostsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PostsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 34, color: _PostsScreenState._muted),
          const SizedBox(height: 9),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _PostsScreenState._muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}

class _PostsEmpty extends StatelessWidget {
  final bool hasQuery;
  final bool mineOnly;
  final VoidCallback onCreate;

  const _PostsEmpty({
    required this.hasQuery,
    required this.mineOnly,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final title = hasQuery
        ? 'Ничего не найдено'
        : mineOnly
            ? 'У вас пока нет публикаций'
            : 'Пока нет публикаций';
    final subtitle = hasQuery
        ? 'Попробуйте другой текст или нажмите на хэштег в публикации.'
        : 'Добавьте первую публикацию — фото, подпись и хэштеги.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 34, 16, 46),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _PostsScreenState._green.withOpacity(.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              color: _PostsScreenState._green,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _PostsScreenState._ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _PostsScreenState._muted,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: _PostsScreenState._green,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Создать публикацию',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
