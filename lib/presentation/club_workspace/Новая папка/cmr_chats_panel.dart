// lib/presentation/club_workspace/cmr_chats_panel.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

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
      return Container(
        color: _CmrChatColors.bg,
        child: const _CmrChatEmpty(
          icon: Icons.forum_rounded,
          title: 'Чаты недоступны',
          subtitle: 'Не удалось определить пользователя для загрузки сообщений.',
        ),
      );
    }

    final items = _visibleItems();

    return Container(
      color: _CmrChatColors.bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 640;
          final compact = constraints.maxWidth < 980;
          final listWidth = math.min(480.0, constraints.maxWidth * .45);

          if (mobile) {
            return _buildCompact(items);
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: listWidth,
                child: _buildLeft(items, mobile: mobile, compact: compact),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildRight()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompact(List<Map<String, dynamic>> items) {
    if (_selectedChatId != null) return _buildRight(showBack: true);
    return _buildLeft(items, mobile: true, compact: true);
  }

  Widget _buildLeft(
    List<Map<String, dynamic>> items, {
    required bool mobile,
    required bool compact,
  }) {
    return Container(
      decoration: _CmrChatDecor.panel(radius: mobile ? 14 : 16, elevated: true),
      padding: EdgeInsets.all(mobile ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChatsToolbar(
            clubName: widget.clubName,
            teamName: widget.teamName,
            unreadTotal: _unreadTotal,
            onRefresh: _refresh,
            onCreateGroup: _openCreateGroup,
            onOpenFull: _openFullChat,
            mobile: mobile,
          ),
          SizedBox(height: mobile ? 10 : 12),
          _ChatSearch(
            controller: _search,
            hintText: _mode == _CmrChatMode.users ? 'Найти пользователя...' : 'Поиск по чатам...',
            mobile: mobile,
          ),
          const SizedBox(height: 8),
          _ChatModeBar(
            value: _mode,
            privateCount: _privateChats.length,
            groupsCount: _groups.length,
            usersCount: _users.length,
            onChanged: (mode) {
              setState(() => _mode = mode);
              if (mode == _CmrChatMode.privateChats && _privateChats.isEmpty) _loadPrivateChats();
              if (mode == _CmrChatMode.groups && _groups.isEmpty) _loadGroups();
              if (mode == _CmrChatMode.users && _users.isEmpty) _loadUsers();
            },
            mobile: mobile,
          ),
          if (_error != null) ...[
            SizedBox(height: mobile ? 8 : 10),
            _InlineError(text: _error!, onRefresh: _refresh),
          ],
          SizedBox(height: mobile ? 9 : 10),
          Expanded(
            child: _loading || (_mode == _CmrChatMode.users && _loadingUsers)
                ? const _ChatListSkeleton()
                : items.isEmpty
                    ? _emptyForMode()
                    : RefreshIndicator(
                        color: _CmrChatColors.green,
                        onRefresh: _refresh,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(bottom: mobile ? 20 : 8),
                          itemBuilder: (_, i) {
                            final item = items[i];
                            if (_mode == _CmrChatMode.users) {
                              return _UserRow(
                                title: _userTitle(item),
                                subtitle: (item['email'] ?? 'Нажмите, чтобы начать диалог').toString(),
                                avatarUrl: _photo(item),
                                initials: _initials(_userTitle(item)),
                                onTap: () => _createPrivateWithUser(item),
                                mobile: mobile,
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
                              mobile: mobile,
                            );
                          },
                          separatorBuilder: (_, __) => SizedBox(height: mobile ? 6 : 7),
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
        decoration: _CmrChatDecor.panel(radius: 14, elevated: true),
        padding: const EdgeInsets.all(18),
        child: const _CmrChatEmpty(
          icon: Icons.forum_rounded,
          title: 'Выберите чат',
          subtitle: 'Слева выберите личный диалог, группу или пользователя. Переписка откроется здесь же, без ухода из workspace.',
        ),
      );
    }

    final chat = _selectedChat;
    final avatar = chat == null ? '' : _photo(chat);
    final subtitle = chat == null
        ? 'Рабочая переписка'
        : (_isPrivate(chat) ? _subtitle(chat) : '${_subtitle(chat)} · группа');

    return Container(
      decoration: _CmrChatDecor.panel(radius: 14, elevated: true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            _EmbeddedChatHeader(
              title: _selectedChatName.isEmpty ? 'Чат' : _selectedChatName,
              subtitle: subtitle,
              avatarUrl: avatar,
              initials: _initials(_selectedChatName),
              isGroup: chat == null ? false : !_isPrivate(chat),
              onBack: showBack
                  ? () => setState(() {
                        _selectedChatId = null;
                        _selectedChat = null;
                      })
                  : null,
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
      ),
    );
  }

}

class _ChatsToolbar extends StatelessWidget {
  final String? clubName;
  final String? teamName;
  final int unreadTotal;
  final VoidCallback onRefresh;
  final VoidCallback onOpenFull;
  final VoidCallback onCreateGroup;
  final bool mobile;

  const _ChatsToolbar({
    required this.clubName,
    required this.teamName,
    required this.unreadTotal,
    required this.onRefresh,
    required this.onOpenFull,
    required this.onCreateGroup,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final scope = [
      if ((clubName ?? '').trim().isNotEmpty) clubName!.trim(),
      if ((teamName ?? '').trim().isNotEmpty) teamName!.trim(),
    ].join(' · ');

    return Row(
      children: [
        Container(
          width: mobile ? 34 : 36,
          height: mobile ? 34 : 36,
          decoration: BoxDecoration(
            color: _CmrChatColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _CmrChatColors.green.withOpacity(.42), width: 1),
          ),
          child: const Icon(Icons.forum_rounded, color: _CmrChatColors.green, size: 18),
        ),
        SizedBox(width: mobile ? 9 : 10),
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
                      style: _CmrChatText.title(mobile ? 15.5 : 16.5),
                    ),
                  ),
                  if (unreadTotal > 0) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _CmrChatColors.graphite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _CmrChatColors.green.withOpacity(.5), width: 1),
                      ),
                      child: Text(
                        unreadTotal > 99 ? '99+' : unreadTotal.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                scope.isEmpty ? 'Диалоги, группы и пользователи' : scope,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrChatText.muted(mobile ? 11.2 : 12),
              ),
            ],
          ),
        ),
        if (!mobile) ...[
          _CircleAction(icon: Icons.refresh_rounded, onTap: onRefresh, tooltip: 'Обновить'),
          const SizedBox(width: 7),
          _CircleAction(icon: Icons.open_in_new_rounded, onTap: onOpenFull, tooltip: 'Открыть полный экран'),
          const SizedBox(width: 7),
        ],
        _CircleAction(
          icon: Icons.group_add_rounded,
          onTap: onCreateGroup,
          tooltip: 'Создать группу',
          emphasized: true,
        ),
      ],
    );
  }
}

class _ChatSearch extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool mobile;

  const _ChatSearch({required this.controller, required this.hintText, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mobile ? 40 : 42,
      decoration: _CmrChatDecor.softCard(radius: mobile ? 10 : 11),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _CmrChatColors.muted, size: 21),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                isDense: true,
              ),
              style: _CmrChatText.value(mobile ? 12.5 : 13),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: controller.clear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: _CmrChatColors.muted, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatModeBar extends StatelessWidget {
  final _CmrChatMode value;
  final int privateCount;
  final int groupsCount;
  final int usersCount;
  final ValueChanged<_CmrChatMode> onChanged;
  final bool mobile;

  const _ChatModeBar({
    required this.value,
    required this.privateCount,
    required this.groupsCount,
    required this.usersCount,
    required this.onChanged,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_CmrChatMode, _ChatModeData>{
      _CmrChatMode.privateChats: _ChatModeData('Личные', Icons.chat_bubble_rounded, privateCount),
      _CmrChatMode.groups: _ChatModeData('Группы', Icons.groups_2_rounded, groupsCount),
      _CmrChatMode.users: _ChatModeData('Люди', Icons.person_search_rounded, usersCount),
    };

    return SizedBox(
      height: mobile ? 33 : 35,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: mobile ? 6 : 8),
        itemBuilder: (_, index) {
          final mode = items.keys.elementAt(index);
          final data = items[mode]!;
          return _ChatModePill(
            label: data.label,
            icon: data.icon,
            count: data.count,
            active: mode == value,
            dense: mobile,
            onTap: () => onChanged(mode),
          );
        },
      ),
    );
  }
}

class _ChatModeData {
  final String label;
  final IconData icon;
  final int count;
  const _ChatModeData(this.label, this.icon, this.count);
}

class _ChatModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool active;
  final bool dense;
  final VoidCallback onTap;

  const _ChatModePill({
    required this.label,
    required this.icon,
    required this.count,
    required this.active,
    required this.dense,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: dense ? 9 : 11, vertical: dense ? 7 : 8),
          decoration: BoxDecoration(
            color: active ? _CmrChatColors.graphite : _CmrChatColors.soft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? _CmrChatColors.green.withOpacity(.42) : _CmrChatColors.line,
              width: active ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dense ? 18 : 20,
                height: dense ? 18 : 20,
                decoration: BoxDecoration(
                  color: active ? Colors.white.withOpacity(.08) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: active ? _CmrChatColors.green.withOpacity(.5) : _CmrChatColors.line,
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: active ? _CmrChatColors.green : _CmrChatColors.muted, size: dense ? 14 : 15),
              ),
              const SizedBox(width: 7),
              Text(label, style: _CmrChatText.tab(active: active)),
              const SizedBox(width: 7),
              Text(
                count.toString(),
                style: TextStyle(
                  color: active ? Colors.white.withOpacity(.72) : _CmrChatColors.muted2,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 7),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: _CmrChatColors.green, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmbeddedChatHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String avatarUrl;
  final String initials;
  final bool isGroup;
  final VoidCallback? onBack;

  const _EmbeddedChatHeader({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.initials,
    required this.isGroup,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: _CmrChatColors.panel,
        border: Border(bottom: BorderSide(color: _CmrChatColors.line, width: 1)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            _CircleAction(icon: Icons.arrow_back_rounded, onTap: onBack!, tooltip: 'К списку чатов'),
            const SizedBox(width: 9),
          ],
          _Avatar(
            url: avatarUrl,
            initials: initials,
            icon: isGroup ? Icons.groups_2_rounded : Icons.person_rounded,
            size: 42,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrChatText.title(15.5)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrChatText.muted(11.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: _CmrChatColors.greenSoft,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _CmrChatColors.greenBorder, width: 1),
            ),
            child: Text(isGroup ? 'Группа' : 'Диалог', style: _CmrChatText.pill(color: _CmrChatColors.greenDark)),
          ),
        ],
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
  final bool mobile;

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
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected;
    final meta = canOpen ? subtitle : 'Нажмите, чтобы вступить в группу';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: EdgeInsets.symmetric(horizontal: mobile ? 9 : 10, vertical: mobile ? 8 : 9),
          decoration: BoxDecoration(
            color: _CmrChatColors.panel,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active ? _CmrChatColors.green.withOpacity(.42) : _CmrChatColors.line,
              width: active ? 1.2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: 3,
                height: mobile ? 42 : 46,
                decoration: BoxDecoration(
                  color: active ? _CmrChatColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(width: active ? 8 : 6),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _Avatar(
                    url: avatarUrl,
                    initials: initials,
                    icon: isGroup ? Icons.groups_2_rounded : Icons.person_rounded,
                    size: mobile ? 40 : 44,
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: _ChatStatusBadge(
                      isGroup: isGroup,
                      unread: unread,
                      active: active,
                    ),
                  ),
                ],
              ),
              SizedBox(width: mobile ? 9 : 10),
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
                            style: _CmrChatText.title(mobile ? 13.4 : 14.2),
                          ),
                        ),
                        if (lastTime.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            lastTime,
                            maxLines: 1,
                            style: _CmrChatText.caption().copyWith(
                              color: unread > 0 ? _CmrChatColors.greenDark : _CmrChatColors.muted2,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrChatText.muted(mobile ? 10.8 : 11.2).copyWith(
                        color: canOpen
                            ? unread > 0
                                ? _CmrChatColors.text2
                                : _CmrChatColors.muted
                            : _CmrChatColors.blue,
                        fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w700,
                      ),
                    ),
                    if (isGroup && !mobile) ...[
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
      ),
    );
  }
}

class _ChatStatusBadge extends StatelessWidget {
  final bool isGroup;
  final int unread;
  final bool active;

  const _ChatStatusBadge({required this.isGroup, required this.unread, required this.active});

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    return Container(
      width: hasUnread ? 23 : 19,
      height: 19,
      decoration: BoxDecoration(
        color: hasUnread || active ? _CmrChatColors.graphite : _CmrChatColors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active || hasUnread ? _CmrChatColors.green.withOpacity(.58) : _CmrChatColors.line,
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: hasUnread
          ? Text(
              unread > 99 ? '99+' : unread.toString(),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            )
          : Icon(
              isGroup ? Icons.groups_2_rounded : Icons.chat_bubble_rounded,
              color: active ? Colors.white : _CmrChatColors.muted,
              size: 12,
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
  final bool mobile;

  const _UserRow({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.initials,
    required this.onTap,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 9 : 10, vertical: mobile ? 8 : 9),
          decoration: BoxDecoration(
            color: _CmrChatColors.panel,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _CmrChatColors.line, width: 1),
          ),
          child: Row(
            children: [
              const SizedBox(width: 9),
              _Avatar(url: avatarUrl, initials: initials, icon: Icons.person_rounded, size: mobile ? 40 : 44),
              SizedBox(width: mobile ? 9 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrChatText.title(mobile ? 13.4 : 14.2)),
                    const SizedBox(height: 4),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrChatText.muted(mobile ? 10.8 : 11.2)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _CmrChatColors.greenSoft,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _CmrChatColors.greenBorder),
                ),
                child: const Icon(Icons.arrow_forward_rounded, size: 18, color: _CmrChatColors.greenDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final String initials;
  final IconData icon;
  final double size;

  const _Avatar({
    required this.url,
    required this.initials,
    required this.icon,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final radius = math.min(12.0, size * .28);
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(radius),
        ),
      );
    }
    return _fallback(radius);
  }

  Widget _fallback(double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CmrChatColors.greenSoft,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _CmrChatColors.greenBorder, width: 1),
      ),
      child: Center(
        child: initials.isNotEmpty
            ? Text(initials, style: _CmrChatText.title(size <= 40 ? 12.5 : 13.5).copyWith(color: _CmrChatColors.greenDark))
            : Icon(icon, color: _CmrChatColors.greenDark, size: size * .45),
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
          fontWeight: FontWeight.w700,
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
              Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
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
  final bool emphasized;

  const _CircleAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(15);

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: emphasized ? _CmrChatColors.green : _CmrChatColors.soft,
          borderRadius: radius,
          border: Border.all(
            color: emphasized ? _CmrChatColors.greenDark.withOpacity(.22) : _CmrChatColors.line,
            width: 1,
          ),
          boxShadow: emphasized
              ? [
                  BoxShadow(
                    color: _CmrChatColors.green.withOpacity(.18),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Icon(
              icon,
              color: emphasized ? Colors.white : _CmrChatColors.text,
              size: 20,
            ),
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
        color: _CmrChatColors.orangeSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _CmrChatColors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _CmrChatText.muted(11).copyWith(color: const Color(0xFF9A3412), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onRefresh, child: Text('Повторить', style: _CmrChatText.action(color: _CmrChatColors.orange))),
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
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _CmrChatColors.panel,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _CmrChatColors.green.withOpacity(.42), width: 1),
                ),
                child: Icon(icon, color: _CmrChatColors.green, size: 28),
              ),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: _CmrChatText.title(16)),
              const SizedBox(height: 7),
              Text(subtitle, textAlign: TextAlign.center, style: _CmrChatText.muted(12)),
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
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (_, i) => Container(
        height: 64,
        decoration: _CmrChatDecor.softCard(radius: 11),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemCount: 8,
    );
  }
}

class _CmrChatText {
  static const String font = 'Roboto';

  static double _compact(double size) => size <= 10 ? size : size - 1.25;

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required Color color,
    double height = 1.18,
    double letterSpacing = -0.12,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontFamily: font,
      color: color,
      fontSize: _compact(size),
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: features,
    );
  }

  static TextStyle title(double size) => _base(
        size: size,
        weight: FontWeight.w700,
        color: _CmrChatColors.text,
        height: 1.12,
        letterSpacing: -0.25,
      );

  static TextStyle value(double size) => _base(
        size: size,
        weight: FontWeight.w600,
        color: _CmrChatColors.text2,
        height: 1.22,
        features: const [FontFeature.tabularFigures()],
      );

  static TextStyle muted(double size) => _base(
        size: size,
        weight: FontWeight.w700,
        color: _CmrChatColors.muted,
        height: 1.34,
        letterSpacing: -0.05,
      );

  static TextStyle caption() => _base(
        size: 12,
        weight: FontWeight.w600,
        color: _CmrChatColors.muted2,
        height: 1.12,
        letterSpacing: .08,
      );

  static TextStyle pill({Color? color}) => _base(
        size: 12,
        weight: FontWeight.w600,
        color: color ?? _CmrChatColors.text2,
        height: 1,
      );

  static TextStyle tab({bool active = false}) => _base(
        size: 13,
        weight: FontWeight.w700,
        color: active ? Colors.white : _CmrChatColors.text2,
        height: 1,
      );

  static TextStyle action({Color color = _CmrChatColors.text}) => _base(
        size: 13,
        weight: FontWeight.w700,
        color: color,
        height: 1.1,
      );
}

class _CmrChatColors {
  static const Color bg = Color(0xFFF5F6F7);
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF8F9FA);
  static const Color soft2 = Color(0xFFF1F3F5);

  static const Color text = Color(0xFF0B0F14);
  static const Color text2 = Color(0xFF182230);
  static const Color muted = Color(0xFF374151);
  static const Color muted2 = Color(0xFF6B7280);

  static const Color graphite = Color(0xFF111827);
  static const Color graphiteSoft = Color(0xFF1F2937);

  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color greenSoft2 = Color(0xFFF8FEFA);
  static const Color greenBorder = Color(0xFFD7F0E2);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF7ED);
  static const Color line = Color(0xFFE5E7EB);
}

class _CmrChatDecor {
  static double _hardRadius(double radius, {double max = 14}) => math.min(radius, max);

  static BoxDecoration panel({double radius = 14, bool elevated = false}) => BoxDecoration(
        color: _CmrChatColors.panel,
        borderRadius: BorderRadius.circular(_hardRadius(radius, max: 14)),
        border: Border.all(color: _CmrChatColors.line, width: 1),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      );

  static BoxDecoration softCard({double radius = 10, bool active = false}) => BoxDecoration(
        color: active ? _CmrChatColors.panel : _CmrChatColors.soft,
        borderRadius: BorderRadius.circular(_hardRadius(radius, max: 12)),
        border: Border.all(
          color: active ? _CmrChatColors.green.withOpacity(.42) : _CmrChatColors.line,
          width: active ? 1.2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      );

  static BoxDecoration greenCard({double radius = 10}) => BoxDecoration(
        color: _CmrChatColors.panel,
        borderRadius: BorderRadius.circular(_hardRadius(radius, max: 12)),
        border: Border.all(color: _CmrChatColors.green.withOpacity(.38), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      );
}
