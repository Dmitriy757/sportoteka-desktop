// lib/presentation/club_workspace/cmr_chats_panel.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';
import 'package:sportoteka/presentation/chat_screen/chat_screen.dart';
import 'package:sportoteka/presentation/chat_screen/create_group_chat_screen.dart';

enum _CmrChatMode { privateChats, groups, users }

class CmrChatsPanel extends StatefulWidget {
  final int userId;
  final String? clubName;
  final int? teamId;
  final String? teamName;
  final ValueChanged<int>? onUnreadChanged;

  const CmrChatsPanel({
    super.key,
    required this.userId,
    this.clubName,
    this.teamId,
    this.teamName,
    this.onUnreadChanged,
  });

  @override
  State<CmrChatsPanel> createState() => _CmrChatsPanelState();
}

class _CmrChatsPanelState extends State<CmrChatsPanel> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';

  static const String _privateChatsUrl = '$_apiBase/get_user_chats.php';
  static const String _groupsFeedUrl = '$_apiBase/get_groups_feed.php';
  static const String _searchUsersUrl = '$_apiBase/search_users.php';
  static const String _createChatUrl = '$_apiBase/create_chat.php';
  static const String _joinGroupUrl = '$_apiBase/join_group.php';
  static const String _markReadUrl = '$_apiBase/mark_chat_read.php';
  static const String _unreadTotalUrl = '$_apiBase/get_unread_total.php';

  final TextEditingController _search = TextEditingController();

  _CmrChatMode _mode = _CmrChatMode.privateChats;

  List<Map<String, dynamic>> _privateChats = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _groups = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _users = <Map<String, dynamic>>[];

  Map<String, dynamic>? _selectedChat;
  int? _selectedChatId;
  String _selectedChatName = '';

  bool _loading = true;
  bool _loadingUsers = false;
  String? _error;
  int _unreadTotal = 0;
  Timer? _unreadTimer;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _bootstrap();
    _startUnreadPolling();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _unreadTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  int _asInt(dynamic v) => int.tryParse((v ?? '').toString()) ?? 0;

  bool _truthy(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();
    return v == true || v == 1 || s == '1' || s == 'true' || s == 'yes';
  }

  bool _isPrivate(Map<String, dynamic> chat) => _truthy(chat['is_private']);

  bool _iAmMember(Map<String, dynamic> chat) => _truthy(chat['i_am_member']);

  String _initials(String title) {
    String firstLetter(String value) {
      final s = value.trim();
      if (s.isEmpty) return '';
      return s.substring(0, 1).toUpperCase();
    }

    final parts = title.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'Ч';
    if (parts.length == 1) return firstLetter(parts.first);
    return '${firstLetter(parts[0])}${firstLetter(parts[1])}';
  }

  dynamic _decodeJson(String body) {
    var t = body;
    if (t.isNotEmpty && t.codeUnitAt(0) == 0xFEFF) {
      t = t.substring(1);
    }
    t = t.trimLeft();
    final startObj = t.indexOf('{');
    final startArr = t.indexOf('[');
    int start = -1;
    if (startObj >= 0 && startArr >= 0) {
      start = startObj < startArr ? startObj : startArr;
    } else {
      start = startObj >= 0 ? startObj : startArr;
    }
    if (start > 0) t = t.substring(start);
    return json.decode(t);
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    final list = raw is List
        ? raw
        : raw is Map
            ? (raw['data'] ?? raw['items'] ?? raw['chats'] ?? raw['groups'] ?? raw['users'] ?? <dynamic>[])
            : <dynamic>[];
    if (list is! List) return <Map<String, dynamic>>[];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _bootstrap() async {
    await Future.wait(<Future<void>>[
      _loadPrivateChats(),
      _loadGroups(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
    _autoSelectFirstChat();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _bootstrap();
  }

  Future<void> _loadPrivateChats() async {
    try {
      final res = await http.get(Uri.parse('$_privateChatsUrl?user_id=${widget.userId}'));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = _decodeJson(res.body);
      final list = _asMapList(data).where(_isPrivate).toList();
      if (!mounted) return;
      setState(() => _privateChats = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить личные чаты: $e');
    }
  }

  Future<void> _loadGroups() async {
    try {
      final res = await http.get(Uri.parse('$_groupsFeedUrl?user_id=${widget.userId}'));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = _decodeJson(res.body);
      final list = _asMapList(data);
      if (!mounted) return;
      setState(() => _groups = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить группы: $e');
    }
  }

  Future<void> _loadUsers({String query = ''}) async {
    setState(() => _loadingUsers = true);
    try {
      final q = Uri.encodeQueryComponent(query.trim());
      final uri = q.isEmpty
          ? Uri.parse('$_searchUsersUrl?q=&exclude=${widget.userId}')
          : Uri.parse('$_searchUsersUrl?q=$q&exclude=${widget.userId}');
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = _decodeJson(res.body);
      final list = _asMapList(data)
          .where((u) => _asInt(u['id'] ?? u['user_id']) != widget.userId)
          .toList();
      if (!mounted) return;
      setState(() => _users = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить пользователей: $e');
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  void _onSearchChanged() {
    if (_mode != _CmrChatMode.users) {
      setState(() {});
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadUsers(query: _search.text);
    });
  }

  void _startUnreadPolling() {
    _unreadTimer?.cancel();
    _fetchUnreadTotal();
    _unreadTimer = Timer.periodic(const Duration(seconds: 6), (_) => _fetchUnreadTotal());
  }

  Future<void> _fetchUnreadTotal() async {
    try {
      final res = await http.get(Uri.parse('$_unreadTotalUrl?user_id=${widget.userId}'));
      if (res.statusCode != 200) return;
      final data = _decodeJson(res.body);
      if (data is! Map || data['success'] != true) return;
      final total = _asInt(data['unread_total']);
      if (!mounted) return;
      setState(() => _unreadTotal = total);
      await PrefUtils.setUnreadChatsCount(total);
      widget.onUnreadChanged?.call(total);
    } catch (_) {}
  }

  void _autoSelectFirstChat() {
    if (_selectedChatId != null) return;
    final chats = _visibleChatsRaw();
    if (chats.isEmpty) return;
    _selectChat(chats.first);
  }

  String _clean(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '';
    return s;
  }

  bool _isBadChatName(String value) {
    final s = value.trim().toLowerCase();
    return s.isEmpty ||
        s == 'null' ||
        s == 'чат' ||
        s == 'личный чат' ||
        s == 'личный диалог' ||
        s == 'без названия';
  }

  String _chatTitle(Map<String, dynamic> chat) {
    final isPrivate = _isPrivate(chat);

    if (isPrivate) {
      // ВАЖНО: get_user_chats.php в обычном ChatScreen отдаёт имя собеседника
      // чаще всего в title/name, а фото — в peer_photo.
      // Поэтому сначала берём специальные поля собеседника, потом title/name.
      final privateCandidates = <dynamic>[
        chat['peer_name'],
        chat['other_user_name'],
        chat['peer_full_name'],
        chat['companion_name'],
        chat['interlocutor_name'],
        chat['opponent_name'],
        chat['member_name'],
        chat['user_name'],
        chat['participant_name'],
        chat['receiver_name'],
        chat['sender_name'],

        // Совместимость с текущим chat_screen.dart:
        chat['title'],
        chat['name'],
        chat['chat_name'],
      ];

      for (final c in privateCandidates) {
        final s = _clean(c);
        if (!_isBadChatName(s)) return s;
      }

      final first = _clean(
        chat['peer_first_name'] ??
            chat['opponent_first_name'] ??
            chat['companion_first_name'] ??
            chat['interlocutor_first_name'] ??
            chat['first_name'],
      );

      final last = _clean(
        chat['peer_last_name'] ??
            chat['opponent_last_name'] ??
            chat['companion_last_name'] ??
            chat['interlocutor_last_name'] ??
            chat['last_name'],
      );

      final full = '$first $last'.trim();
      if (!_isBadChatName(full)) return full;

      final email = _clean(
        chat['peer_email'] ??
            chat['opponent_email'] ??
            chat['companion_email'] ??
            chat['email'],
      );
      if (!_isBadChatName(email)) return email;

      final phone = _clean(chat['peer_phone'] ?? chat['opponent_phone'] ?? chat['phone']);
      if (!_isBadChatName(phone)) return phone;

      return 'Личный чат';
    }

    final groupCandidates = <dynamic>[
      chat['name'],
      chat['chat_name'],
      chat['title'],
      chat['group_name'],
    ];

    for (final c in groupCandidates) {
      final s = _clean(c);
      if (!_isBadChatName(s)) return s;
    }

    return 'Группа';
  }

  String _userTitle(Map<String, dynamic> user) {
    final first = _clean(user['first_name'] ?? user['firstname']);
    final last = _clean(user['last_name'] ?? user['lastname']);
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final name = _clean(user['name'] ?? user['username']);
    if (name.isNotEmpty) return name;
    final email = _clean(user['email']);
    return email.isNotEmpty ? email : 'Пользователь';
  }

  String _subtitle(Map<String, dynamic> chat) {
    final last = _clean(
      chat['last_message'] ??
          chat['last_message_text'] ??
          chat['last_text'] ??
          chat['message'] ??
          chat['content'] ??
          chat['body'],
    );

    if (last.isNotEmpty) return last;

    final type = _clean(chat['last_message_type'] ?? chat['message_type'] ?? chat['type']).toLowerCase();
    final file = _clean(
      chat['last_file_url'] ??
          chat['file_url'] ??
          chat['attachment'] ??
          chat['media_url'],
    ).toLowerCase();

    if (file.isNotEmpty) {
      if (type == 'image' || file.endsWith('.jpg') || file.endsWith('.jpeg') || file.endsWith('.png') || file.endsWith('.webp')) {
        return 'Фото';
      }
      if (type == 'video' || file.endsWith('.mp4') || file.endsWith('.mov') || file.endsWith('.avi')) {
        return 'Видео';
      }
      return 'Файл';
    }

    if (_isPrivate(chat)) return 'Нет сообщений';

    final members = _asInt(chat['members_count'] ?? chat['member_count'] ?? chat['members']);
    final publicText = _truthy(chat['is_public']) ? 'Открытая группа' : 'Закрытая группа';
    return members > 0 ? '$publicText · $members участников' : publicText;
  }

  String _chatLastTime(Map<String, dynamic> chat) {
    final raw = _clean(
      chat['last_message_at'] ??
          chat['last_message_date'] ??
          chat['last_created_at'] ??
          chat['last_time'] ??
          chat['updated_at'] ??
          chat['created_at'],
    );

    if (raw.isEmpty) return '';

    DateTime? dt;
    try {
      dt = DateTime.parse(raw).toLocal();
    } catch (_) {
      return raw;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    String two(int n) => n.toString().padLeft(2, '0');

    if (date == today) {
      return '${two(dt.hour)}:${two(dt.minute)}';
    }

    if (date == today.subtract(const Duration(days: 1))) {
      return 'Вчера';
    }

    if (now.difference(dt).inDays < 7) {
      const days = <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      return days[dt.weekday - 1];
    }

    return '${two(dt.day)}.${two(dt.month)}.${dt.year.toString().substring(2)}';
  }

  String _photo(Map<String, dynamic> item) {
    final raw = (item['peer_photo'] ??
            item['opponent_photo'] ??
            item['companion_photo'] ??
            item['interlocutor_photo'] ??
            item['avatar_url'] ??
            item['avatar'] ??
            item['photo'] ??
            item['image'] ??
            item['logo'] ??
            '')
        .toString()
        .trim();

    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/uploads/$raw';
  }

  List<Map<String, dynamic>> _visibleChatsRaw() {
    switch (_mode) {
      case _CmrChatMode.privateChats:
        return _privateChats;
      case _CmrChatMode.groups:
        return _groups;
      case _CmrChatMode.users:
        return _users;
    }
  }

  List<Map<String, dynamic>> _visibleItems() {
    final q = _search.text.trim().toLowerCase();
    final raw = _visibleChatsRaw();
    if (q.isEmpty || _mode == _CmrChatMode.users) return raw;

    return raw.where((e) {
      final title = _chatTitle(e).toLowerCase();
      final sub = _subtitle(e).toLowerCase();
      return title.contains(q) || sub.contains(q);
    }).toList();
  }

  void _selectChat(Map<String, dynamic> chat) {
    final id = _asInt(chat['id'] ?? chat['chat_id']);
    if (id <= 0) return;
    final title = _chatTitle(chat);
    final unread = _asInt(chat['unread_count']);
    setState(() {
      _selectedChat = chat;
      _selectedChatId = id;
      _selectedChatName = title;
      chat['unread_count'] = 0;
    });
    if (unread > 0) {
      _markReadServer(id);
      _fetchUnreadTotal();
    }
  }

  Future<void> _markReadServer(int chatId) async {
    try {
      await http.post(Uri.parse(_markReadUrl), body: {
        'user_id': widget.userId.toString(),
        'chat_id': chatId.toString(),
      });
    } catch (_) {}
  }

  Future<void> _createPrivateWithUser(Map<String, dynamic> user) async {
    final peerId = _asInt(user['id'] ?? user['user_id']);
    if (peerId <= 0) return;
    try {
      final res = await http.post(Uri.parse(_createChatUrl), body: {
        'type': 'private',
        'user_id': widget.userId.toString(),
        'peer_id': peerId.toString(),
      });
      final data = _decodeJson(res.body);
      if (res.statusCode == 200 && data is Map && data['success'] == true) {
        final chatId = _asInt(data['chat_id']);
        if (chatId > 0) {
          await _loadPrivateChats();
          final title = _userTitle(user);
          if (!mounted) return;
          setState(() {
            _mode = _CmrChatMode.privateChats;
            _selectedChatId = chatId;
            _selectedChatName = title;
            _selectedChat = {
              'id': chatId,
              'name': title,
              'is_private': 1,
              'peer_name': title,
            };
          });
          return;
        }
      }
      _toast('Не удалось открыть личный чат');
    } catch (e) {
      _toast('Ошибка сети: $e');
    }
  }

  Future<void> _joinGroup(Map<String, dynamic> chat) async {
    final chatId = _asInt(chat['id'] ?? chat['chat_id']);
    if (chatId <= 0) return;
    try {
      final res = await http.post(Uri.parse(_joinGroupUrl), body: {
        'chat_id': chatId.toString(),
        'user_id': widget.userId.toString(),
      });
      final data = _decodeJson(res.body);
      final ok = res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        _toast('Не удалось вступить в группу');
        return;
      }
      await _loadGroups();
      _selectChat({...chat, 'i_am_member': 1});
    } catch (e) {
      _toast('Ошибка сети: $e');
    }
  }

  Future<void> _openCreateGroup() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupChatScreen(userId: widget.userId),
      ),
    );
    if (changed == true) {
      await _loadGroups();
      if (!mounted) return;
      setState(() => _mode = _CmrChatMode.groups);
      _autoSelectFirstChat();
    }
  }

  void _openFullChat() {
    Get.to(() => ChatScreen(
          userId: widget.userId,
          onUnreadChanged: widget.onUnreadChanged,
        ));
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId <= 0) {
      return const _CmrChatEmpty(
        icon: Icons.forum_rounded,
        title: 'Чаты недоступны',
        subtitle: 'Не удалось определить пользователя для загрузки сообщений.',
      );
    }

    final panelWidth = MediaQuery.of(context).size.width;
    final compact = panelWidth < 720;
    final items = _visibleItems();

    return Container(
      decoration: _CmrChatDecor.panel(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Header(
            unreadTotal: _unreadTotal,
            clubName: widget.clubName,
            teamName: widget.teamName,
            onRefresh: _refresh,
            onOpenFull: _openFullChat,
            onCreateGroup: _openCreateGroup,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 0, compact ? 10 : 14, compact ? 10 : 14),
              child: compact
                  ? _buildCompact(items)
                  : Row(
                      children: [
                        SizedBox(width: panelWidth < 1050 ? 320 : 390, child: _buildLeft(items)),
                        const SizedBox(width: 14),
                        Expanded(child: _buildRight()),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(List<Map<String, dynamic>> items) {
    if (_selectedChatId != null) return _buildRight(showBack: true);
    return _buildLeft(items);
  }

  Widget _buildLeft(List<Map<String, dynamic>> items) {
    return Container(
      decoration: _CmrChatDecor.innerPanel(),
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ModeChip(
                        text: 'Личные',
                        icon: Icons.chat_bubble_rounded,
                        count: _privateChats.length,
                        selected: _mode == _CmrChatMode.privateChats,
                        onTap: () {
                          setState(() => _mode = _CmrChatMode.privateChats);
                          if (_privateChats.isEmpty) _loadPrivateChats();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeChip(
                        text: 'Группы',
                        icon: Icons.groups_rounded,
                        count: _groups.length,
                        selected: _mode == _CmrChatMode.groups,
                        onTap: () {
                          setState(() => _mode = _CmrChatMode.groups);
                          if (_groups.isEmpty) _loadGroups();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ModeChip(
                  text: 'Пользователи',
                  icon: Icons.person_search_rounded,
                  count: _users.length,
                  selected: _mode == _CmrChatMode.users,
                  onTap: () {
                    setState(() => _mode = _CmrChatMode.users);
                    if (_users.isEmpty) _loadUsers();
                  },
                  wide: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: _mode == _CmrChatMode.users
                        ? 'Найти пользователя...'
                        : 'Поиск по чатам...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => _search.clear(),
                          ),
                    filled: true,
                    fillColor: _CmrChatColors.soft,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: _CmrChatColors.green, width: 1.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _InlineError(text: _error!, onRefresh: _refresh),
            ),
          Expanded(
            child: _loading || (_mode == _CmrChatMode.users && _loadingUsers)
                ? const _ChatListSkeleton()
                : items.isEmpty
                    ? _emptyForMode()
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                          itemBuilder: (_, i) {
                            final item = items[i];
                            if (_mode == _CmrChatMode.users) {
                              return _UserRow(
                                title: _userTitle(item),
                                subtitle: (item['email'] ?? 'Нажмите, чтобы начать диалог').toString(),
                                avatarUrl: _photo(item),
                                initials: _initials(_userTitle(item)),
                                onTap: () => _createPrivateWithUser(item),
                              );
                            }

                            final id = _asInt(item['id'] ?? item['chat_id']);
                            final selected = id == _selectedChatId;
                            final isGroup = _mode == _CmrChatMode.groups;
                            final canOpen = !isGroup || _iAmMember(item);
                            final chatTitle = _chatTitle(item);

                            return _ChatRow(
                              title: chatTitle,
                              subtitle: _subtitle(item),
                              lastTime: _chatLastTime(item),
                              avatarUrl: _photo(item),
                              initials: _initials(chatTitle),
                              selected: selected,
                              unread: _asInt(item['unread_count']),
                              isGroup: isGroup,
                              isPublic: _truthy(item['is_public']),
                              canOpen: canOpen,
                              onTap: () => canOpen ? _selectChat(item) : _joinGroup(item),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemCount: items.length,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyForMode() {
    switch (_mode) {
      case _CmrChatMode.privateChats:
        return const _CmrChatEmpty(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Личных чатов пока нет',
          subtitle: 'Откройте вкладку «Пользователи» и начните диалог.',
        );
      case _CmrChatMode.groups:
        return _CmrChatEmpty(
          icon: Icons.groups_2_rounded,
          title: 'Групп пока нет',
          subtitle: 'Создайте группу для команды, тренеров или родителей.',
          actionText: 'Создать группу',
          onAction: _openCreateGroup,
        );
      case _CmrChatMode.users:
        return const _CmrChatEmpty(
          icon: Icons.person_search_rounded,
          title: 'Пользователи не найдены',
          subtitle: 'Введите имя, фамилию или email для поиска.',
        );
    }
  }

  Widget _buildRight({bool showBack = false}) {
    final chatId = _selectedChatId;
    if (chatId == null || chatId <= 0) {
      return Container(
        decoration: _CmrChatDecor.softCard(radius: 24),
        child: const Center(
          child: _CmrChatEmpty(
            icon: Icons.forum_rounded,
            title: 'Выберите чат',
            subtitle: 'Слева выберите личный диалог, группу или пользователя. Переписка откроется здесь же, без ухода из workspace.',
          ),
        ),
      );
    }

    return Container(
      decoration: _CmrChatDecor.innerPanel(),
      child: Column(
        children: [
          if (showBack)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'К списку чатов',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() {
                      _selectedChatId = null;
                      _selectedChat = null;
                    }),
                  ),
                  Expanded(
                    child: Text(
                      _selectedChatName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ChatRoomScreen(
              key: ValueKey('cmr-chat-$chatId'),
              chatId: chatId,
              userId: widget.userId,
              chatName: _selectedChatName,
              embedded: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int unreadTotal;
  final String? clubName;
  final String? teamName;
  final VoidCallback onRefresh;
  final VoidCallback onOpenFull;
  final VoidCallback onCreateGroup;

  const _Header({
    required this.unreadTotal,
    required this.clubName,
    required this.teamName,
    required this.onRefresh,
    required this.onOpenFull,
    required this.onCreateGroup,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    final subtitle = [
      if ((clubName ?? '').trim().isNotEmpty) clubName!.trim(),
      if ((teamName ?? '').trim().isNotEmpty) teamName!.trim(),
    ].join(' · ');

    final titleBlock = Row(
      children: [
        Container(
          width: compact ? 42 : 48,
          height: compact ? 42 : 48,
          decoration: BoxDecoration(
            color: _CmrChatColors.greenSoft,
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
          ),
          child: Icon(Icons.forum_rounded, color: _CmrChatColors.green, size: compact ? 22 : 25),
        ),
        SizedBox(width: compact ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Чаты',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 16 : 18,
                        fontWeight: FontWeight.w900,
                        color: _CmrChatColors.text,
                      ),
                    ),
                  ),
                  if (unreadTotal > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        compact ? '$unreadTotal' : '$unreadTotal новых',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle.isEmpty
                    ? 'Личные диалоги, группы и пользователи'
                    : '$subtitle · диалоги и группы',
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _CmrChatColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 18, compact ? 12 : 14, compact ? 10 : 14, compact ? 10 : 14),
      decoration: const BoxDecoration(color: Colors.white),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _HeaderButton(
                        icon: Icons.group_add_rounded,
                        text: 'Группа',
                        onTap: onCreateGroup,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CircleAction(icon: Icons.refresh_rounded, onTap: onRefresh, tooltip: 'Обновить'),
                    const SizedBox(width: 8),
                    _CircleAction(icon: Icons.open_in_new_rounded, onTap: onOpenFull, tooltip: 'Полный экран'),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 10),
                _HeaderButton(
                  icon: Icons.group_add_rounded,
                  text: 'Группа',
                  onTap: onCreateGroup,
                ),
                const SizedBox(width: 8),
                _CircleAction(icon: Icons.refresh_rounded, onTap: onRefresh, tooltip: 'Обновить'),
                const SizedBox(width: 8),
                _CircleAction(icon: Icons.open_in_new_rounded, onTap: onOpenFull, tooltip: 'Открыть полный экран'),
              ],
            ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final bool wide;

  const _ModeChip({
    required this.text,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _CmrChatColors.greenSoft : _CmrChatColors.soft;
    final fg = selected ? _CmrChatColors.green : _CmrChatColors.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: null,
        ),
        child: Row(
          mainAxisAlignment: wide ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: TextStyle(color: fg.withOpacity(.72), fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String lastTime;
  final String avatarUrl;
  final String initials;
  final bool selected;
  final int unread;
  final bool isGroup;
  final bool isPublic;
  final bool canOpen;
  final VoidCallback onTap;

  const _ChatRow({
    required this.title,
    required this.subtitle,
    required this.lastTime,
    required this.avatarUrl,
    required this.initials,
    required this.selected,
    required this.unread,
    required this.isGroup,
    required this.isPublic,
    required this.canOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _CmrChatColors.greenSoft : _CmrChatColors.soft;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: null,
        ),
        child: Row(
          children: [
            _Avatar(
              url: avatarUrl,
              initials: initials,
              icon: isGroup ? Icons.groups_rounded : Icons.person_rounded,
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
                          style: const TextStyle(
                            color: _CmrChatColors.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (lastTime.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          lastTime,
                          maxLines: 1,
                          style: TextStyle(
                            color: unread > 0 ? _CmrChatColors.green : _CmrChatColors.muted,
                            fontSize: 11,
                            fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                      ],
                      if (unread > 0) ...[
                        const SizedBox(width: 7),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22, minHeight: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _CmrChatColors.green,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canOpen ? subtitle : 'Нажмите, чтобы вступить в группу',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: canOpen
                          ? unread > 0
                              ? _CmrChatColors.text
                              : _CmrChatColors.muted
                          : const Color(0xFF1D4ED8),
                      fontSize: 12,
                      fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                  if (isGroup) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _TinyBadge(text: isPublic ? 'Открытая' : 'Закрытая'),
                        if (!canOpen) ...[
                          const SizedBox(width: 6),
                          const _TinyBadge(text: 'Вступить', blue: true),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String avatarUrl;
  final String initials;
  final VoidCallback onTap;

  const _UserRow({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.initials,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _CmrChatColors.soft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            _Avatar(url: avatarUrl, initials: initials, icon: Icons.person_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _CmrChatColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _CmrChatColors.greenSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 18, color: _CmrChatColors.green),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final String initials;
  final IconData icon;

  const _Avatar({required this.url, required this.initials, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          url,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _CmrChatColors.greenSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: initials.isNotEmpty
            ? Text(initials, style: const TextStyle(color: _CmrChatColors.green, fontWeight: FontWeight.w900, fontSize: 13))
            : Icon(icon, color: _CmrChatColors.green),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;
  final bool blue;

  const _TinyBadge({required this.text, this.blue = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: blue ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: blue ? const Color(0xFFD8EAFE) : _CmrChatColors.greenBorder),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: blue ? const Color(0xFF1D4ED8) : _CmrChatColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrChatColors.green,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 7),
              Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _CircleAction({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _CmrChatColors.soft,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: _CmrChatColors.text, size: 20),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String text;
  final VoidCallback onRefresh;

  const _InlineError({required this.text, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFEA580C), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF9A3412), fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(onPressed: onRefresh, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

class _CmrChatEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const _CmrChatEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: _CmrChatColors.greenSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: _CmrChatColors.green, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _CmrChatColors.text, fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _CmrChatColors.muted, fontSize: 12, fontWeight: FontWeight.w700, height: 1.35),
              ),
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: 14),
                _HeaderButton(icon: Icons.add_rounded, text: actionText!, onTap: onAction!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatListSkeleton extends StatelessWidget {
  const _ChatListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      itemBuilder: (_, i) => Container(
        height: 76,
        decoration: BoxDecoration(
          color: _CmrChatColors.soft,
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: 8,
    );
  }
}

class _CmrChatColors {
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF6F8FA);
  static const Color border = Color(0xFFE5EAF0);
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color green = Color(0xFF1F7A4D);
  static const Color greenSoft = Color(0xFFF2F7F4);
  static const Color greenBorder = Color(0xFFD7E8DE);
}

class _CmrChatDecor {
  static BoxDecoration panel() => BoxDecoration(
        color: _CmrChatColors.panel,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.018),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration innerPanel() => BoxDecoration(
        color: _CmrChatColors.panel,
        borderRadius: BorderRadius.circular(24),
      );

  static BoxDecoration softCard({double radius = 22}) => BoxDecoration(
        color: _CmrChatColors.soft,
        borderRadius: BorderRadius.circular(radius),
      );
}
