// lib/presentation/chat_screen/chat_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';
import 'package:sportoteka/presentation/chat_screen/create_group_chat_screen.dart';



class _ChatStyle {
  static const Color bg = Color(0xFFF1F3F5);
  static const Color card = Colors.white;
  static const Color soft = Color(0xFFF1F3F5);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color greenBorder = Color(0xFFD7F0E2);
  static const Color border = Color(0xFFEFF1F4);
  static const Color text = Color(0xFF0B0F14);
  static const Color text2 = Color(0xFF182230);
  static const Color muted = Color(0xFF6B7280);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
  static const Color orange = Color(0xFFF59E0B);

  static const String fontFamily = 'Segoe UI';
  static const List<String> fontFallback = <String>[
    'SF Pro Display',
    'SF Pro Text',
    'Inter',
    'Roboto',
    'Arial',
  ];
}


class ChatScreen extends StatefulWidget {
  final int userId;

  /// ✅ отдаём наверх актуальный total unread (для bottom bar)
  final ValueChanged<int>? onUnreadChanged;

  const ChatScreen({
    super.key,
    required this.userId,
    this.onUnreadChanged,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum _ChatTab { privateChats, groups }

class _ChatScreenState extends State<ChatScreen> {
  static const _apiBase = 'https://sportotekaapp.ru/api';

  // ✅ endpoints
  static const _createChatUrl = '$_apiBase/create_chat.php';
  static const _searchUsersUrl = '$_apiBase/search_users.php';

  static const _unreadTotalUrl = '$_apiBase/get_unread_total.php';
  static const _markReadUrl = '$_apiBase/mark_chat_read.php';

  static const _deleteChatUrl = '$_apiBase/delete_chat_force.php';
  static const _privateChatsUrl = '$_apiBase/get_user_chats.php';
  static const _groupsFeedUrl = '$_apiBase/get_groups_feed.php';
  static const _joinGroupUrl = '$_apiBase/join_group.php';
  static const _leaveChatUrl = '$_apiBase/leave_chat.php';

  // ✅ groups endpoints
  static const _leaveGroupUrl = '$_apiBase/leave_group.php';
  static const _deleteGroupUrl = '$_apiBase/delete_group_force.php';

  // ===== DATA =====
  List<Map<String, dynamic>> _privateChats = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _filtered = [];

  bool isLoading = true;
  bool isSearching = false;

  Timer? _unreadTimer;
  int _unreadTotal = 0; // ✅ держим, но не рисуем наверху

  _ChatTab _tab = _ChatTab.privateChats;

  final TextEditingController _searchController = TextEditingController();

  // ===== TELEGRAM-LIKE LOCAL STATE =====
  final Set<int> _pinned = <int>{};
  final Set<int> _archived = <int>{};

  static const _prefsPinnedKey = "chat_pinned_ids_v1";
  static const _prefsArchivedKey = "chat_archived_ids_v1";

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _startUnreadPolling();
    _searchController.addListener(_applyFiltersAndSorting);
  }

  Future<void> _bootstrap() async {
    await _loadLocalState();
    await _reloadCurrentTab();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _unreadTimer?.cancel();
    super.dispose();
  }

  // ===== LOCAL mark read (list + total + PrefUtils + callback) =====
Future<void> _markChatReadLocal(int chatId, int unread) async {
  void patch(List<Map<String, dynamic>> list) {
    final i = list.indexWhere((e) => _asInt(e['id']) == chatId);
    if (i >= 0) list[i]['unread_count'] = 0;
  }

  if (!mounted) return;

  setState(() {
    patch(_privateChats);
    patch(_groups);
    patch(_filtered);

    if (unread > 0) {
      _unreadTotal = (_unreadTotal - unread).clamp(0, 999999);
    }
  });

  // ✅ ВАЖНО: синхронизируем то, что рисует bottom bar
  await PrefUtils.setUnreadChatsCount(_unreadTotal);
  widget.onUnreadChanged?.call(_unreadTotal);
}
  // ===== LOCAL STATE =====
  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final pinned = prefs.getStringList(_prefsPinnedKey) ?? <String>[];
    final archived = prefs.getStringList(_prefsArchivedKey) ?? <String>[];

    if (!mounted) return;
    setState(() {
      _pinned
        ..clear()
        ..addAll(pinned.map((e) => int.tryParse(e)).whereType<int>());

      _archived
        ..clear()
        ..addAll(archived.map((e) => int.tryParse(e)).whereType<int>());
    });
  }

  Future<void> _saveLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsPinnedKey,
      _pinned.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList(
      _prefsArchivedKey,
      _archived.map((e) => e.toString()).toList(),
    );
  }

  // ===== HELPERS =====
  int _asInt(dynamic v) => int.tryParse(v.toString()) ?? 0;

  bool _isPrivate(Map<String, dynamic> chat) =>
      (chat['is_private'] == 1 ||
          chat['is_private'] == "1" ||
          chat['is_private'] == true);

  bool _isPublicGroup(Map<String, dynamic> chat) =>
      (chat['is_public'] == 1 ||
          chat['is_public'] == "1" ||
          chat['is_public'] == true);

  bool _iAmMember(Map<String, dynamic> chat) =>
      (chat['i_am_member'] == 1 ||
          chat['i_am_member'] == "1" ||
          chat['i_am_member'] == true);

  bool _iAmOwner(Map<String, dynamic> chat) =>
      _asInt(chat['owner_id']) == widget.userId;

  String _chatTitle(Map<String, dynamic> chat) {
    final isPrivate = _isPrivate(chat);
    final t = (chat['title'] ?? '').toString().trim();
    final n = (chat['name'] ?? '').toString().trim();

    if (isPrivate) {
      if (t.isNotEmpty) return t;
      return n.isNotEmpty ? n : "Личный чат";
    }
    return n.isNotEmpty ? n : (t.isNotEmpty ? t : "Группа");
  }

  String _peerPhoto(Map<String, dynamic> chat) {
    final isPrivate = _isPrivate(chat);
    if (!isPrivate) return "";
    final raw = (chat['peer_photo'] ?? '').toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return "";
    if (raw.startsWith('http')) return raw;
    return "https://sportotekaapp.ru/uploads/$raw";
  }

  // ===== TELEGRAM-LIKE TIME =====
  DateTime? _parseAnyDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;

    final asInt = int.tryParse(s);
    if (asInt != null) {
      if (asInt > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(asInt).toLocal();
      }
      if (asInt > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(asInt * 1000).toLocal();
      }
    }
    final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized)?.toLocal();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatTelegramTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d0 = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(d0).inDays;

    if (diffDays == 0) return "${_two(dt.hour)}:${_two(dt.minute)}";
    if (diffDays == 1) return "Вчера";
    return "${_two(dt.day)}.${_two(dt.month)}";
  }

  String _chatRightTime(Map<String, dynamic> chat) {
    final dt = _parseAnyDate(chat['last_time']) ??
        _parseAnyDate(chat['last_message_time']) ??
        _parseAnyDate(chat['created_at']);
    if (dt == null) return "";
    return _formatTelegramTime(dt);
  }

  String _groupStatusLine({
    required bool isPublic,
    required bool iAmMember,
  }) {
    if (isPublic) return iAmMember ? "Вы участник" : "Нажмите, чтобы вступить";
    return iAmMember ? "Вы участник" : "Доступ по приглашению";
  }

  // ===== API LOAD =====
  Future<void> _reloadCurrentTab() async {
    if (_tab == _ChatTab.privateChats) {
      await _loadPrivateChats();
    } else {
      await _loadGroups();
    }
    _applyFiltersAndSorting();
  }

  Future<void> _loadPrivateChats() async {
    setState(() => isLoading = true);
    try {
      final uri = Uri.parse('$_privateChatsUrl?user_id=${widget.userId}');
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = (data is List)
            ? List<Map<String, dynamic>>.from(data)
            : <Map<String, dynamic>>[];

        final onlyPrivate = list.where((c) => _isPrivate(c)).toList();

        if (!mounted) return;
        setState(() => _privateChats = onlyPrivate);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки личных чатов: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadGroups() async {
    setState(() => isLoading = true);
    try {
      final uri = Uri.parse('$_groupsFeedUrl?user_id=${widget.userId}');
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        final ok = data is Map && data['success'] == true;
        final listRaw = ok ? (data['groups'] as List? ?? []) : [];
        final list = List<Map<String, dynamic>>.from(listRaw);

        if (!mounted) return;
        setState(() => _groups = list);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки групп: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startUnreadPolling() {
    _unreadTimer?.cancel();
    _fetchUnreadTotal();
    _unreadTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchUnreadTotal();
    });
  }

  Future<void> _fetchUnreadTotal() async {
    try {
      final uri = Uri.parse('$_unreadTotalUrl?user_id=${widget.userId}');
      final res = await http.get(uri);

      if (res.statusCode != 200) return;

      final data = json.decode(res.body);
      if (data is! Map || data['success'] != true) return;

      final total = int.tryParse((data['unread_total'] ?? '0').toString()) ?? 0;

          if (!mounted) return;

if (total != _unreadTotal) {
  setState(() => _unreadTotal = total);

  // ✅ обновим кеш для bottom bar
  await PrefUtils.setUnreadChatsCount(total);

  // ✅ сообщим вниз (bottom bar) сразу
  widget.onUnreadChanged?.call(total);
}
    } catch (_) {}
  }

  Future<void> _markChatReadServer(int chatId) async {
    try {
      final res = await http.post(Uri.parse(_markReadUrl), body: {
        'chat_id': chatId.toString(),
        'user_id': widget.userId.toString(),
      });

      if (res.statusCode == 200) {
        await _fetchUnreadTotal();
      }
    } catch (_) {}
  }

  // ===== FILTER / SORT =====
  void _applyFiltersAndSorting() {
    final q = _searchController.text.toLowerCase().trim();
    final baseSrc = (_tab == _ChatTab.privateChats) ? _privateChats : _groups;

    List<Map<String, dynamic>> base = baseSrc.where((c) {
      final id = _asInt(c['id']);
      if (_archived.contains(id)) return false;
      if (q.isEmpty) return true;
      return _chatTitle(c).toLowerCase().contains(q);
    }).toList();

    base.sort((a, b) {
      final ia = _asInt(a['id']);
      final ib = _asInt(b['id']);

      if (_tab == _ChatTab.privateChats) {
        final pa = _pinned.contains(ia) ? 0 : 1;
        final pb = _pinned.contains(ib) ? 0 : 1;
        if (pa != pb) return pa.compareTo(pb);
      }

      final ta = (a['last_time'] ?? a['last_message_time'] ?? '').toString();
      final tb = (b['last_time'] ?? b['last_message_time'] ?? '').toString();
      return tb.compareTo(ta);
    });

    if (!mounted) return;
    setState(() => _filtered = base);
  }

  // ===== OPEN CHAT =====
  Future<void> _openChat(Map<String, dynamic> chat) async {
    final title = _chatTitle(chat);
    final chatId = _asInt(chat['id']);

    final unread = int.tryParse((chat['unread_count'] ?? '0').toString()) ?? 0;

    // ✅ 1) СРАЗУ снимаем локально (бейдж справа исчезнет мгновенно + BottomBar)
    if (unread > 0) {
      await _markChatReadLocal(chatId, unread);

      // ✅ 2) Серверный mark_read в фоне (не тормозим открытие)
      _markChatReadServer(chatId);
      final newTotal = _unreadTotal;
unawaited(PrefUtils.setUnreadChatsCount(newTotal));
widget.onUnreadChanged?.call(newTotal);
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          chatId: chatId,
          userId: widget.userId,
          chatName: title,
        ),
      ),
    );

    // ✅ 3) После возврата — перезагрузка списка (истина с сервера)
    await _reloadCurrentTab();
    await _fetchUnreadTotal();
  }

  // ===== CREATE/OPEN PRIVATE =====
  Future<void> _createOrOpenPrivateChat({
    required int peerId,
    String? peerTitleForHeader,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final uri = Uri.parse(_createChatUrl);
      final res = await http.post(uri, body: {
        'type': 'private',
        'user_id': widget.userId.toString(),
        'peer_id': peerId.toString(),
      });

      dynamic data;
      try {
        data = json.decode(res.body);
      } catch (_) {
        data = null;
      }

      final ok = res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'HTTP ${res.statusCode}';
        messenger.showSnackBar(
          SnackBar(content: Text("Не удалось создать чат: $err")),
        );
        return;
      }

      final chatId = int.tryParse((data['chat_id'] ?? '0').toString()) ?? 0;
      if (chatId <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Не удалось получить chat_id")),
        );
        return;
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            chatId: chatId,
            userId: widget.userId,
            chatName: peerTitleForHeader ?? "Личный чат",
          ),
        ),
      ).then((_) => _reloadCurrentTab());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Ошибка сети: $e")));
    }
  }

  // ===== JOIN GROUP =====
  Future<void> _joinGroup(Map<String, dynamic> chat) async {
    final chatId = _asInt(chat['id']);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final uri = Uri.parse(_joinGroupUrl);
      final res = await http.post(uri, body: {
        'chat_id': chatId.toString(),
        'user_id': widget.userId.toString(),
      });

      dynamic data;
      try {
        data = json.decode(res.body);
      } catch (_) {
        data = null;
      }

      final ok = res.statusCode == 200 && data is Map && data['success'] == true;

      if (!ok) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'unknown';
        messenger.showSnackBar(
          SnackBar(content: Text("Не удалось вступить: $err")),
        );
        return;
      }

      await _loadGroups();
      _applyFiltersAndSorting();

      if (!mounted) return;
      _openChat(chat);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Ошибка сети: $e")));
    }
  }

  Future<void> _showJoinDialog(Map<String, dynamic> chat) async {
    final title = _chatTitle(chat);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Вступить в группу?"),
        content: Text(
          "Вступить в «$title»?\nПосле вступления сможете читать и писать сообщения.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ChatStyle.green,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Вступить"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _joinGroup(chat);
    }
  }

  // ===== LEAVE PRIVATE CHAT =====
  Future<void> _leavePrivateChat(Map<String, dynamic> chat) async {
    final chatId = _asInt(chat['id']);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final res = await http.post(Uri.parse(_leaveChatUrl), body: {
        'chat_id': chatId.toString(),
        'user_id': widget.userId.toString(),
      });

      dynamic data;
      try {
        data = json.decode(res.body);
      } catch (_) {
        data = null;
      }

      final ok = res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'HTTP ${res.statusCode}';
        messenger.showSnackBar(SnackBar(content: Text("Не удалось выйти: $err")));
        return;
      }

      setState(() {
        _privateChats.removeWhere((c) => _asInt(c['id']) == chatId);
        _filtered.removeWhere((c) => _asInt(c['id']) == chatId);
      });

      _pinned.remove(chatId);
      _archived.remove(chatId);
      await _saveLocalState();

      messenger.showSnackBar(
        SnackBar(
          content: const Text("Вы вышли из личного чата"),
          action: SnackBarAction(label: "Обновить", onPressed: _reloadCurrentTab),
        ),
      );

      await _loadPrivateChats();
      _applyFiltersAndSorting();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Ошибка сети: $e")));
    }
  }

  Future<void> _confirmLeavePrivateChat(Map<String, dynamic> chat) async {
    final title = _chatTitle(chat);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Выйти из чата?"),
        content: Text("Выйти из «$title»?\nЧат исчезнет из списка."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Выйти"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _leavePrivateChat(chat);
    }
  }

  // ===== LEAVE GROUP =====
  Future<void> _leaveGroup(Map<String, dynamic> chat) async {
    final chatId = _asInt(chat['id']);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final uri = Uri.parse(_leaveGroupUrl);
      final res = await http.post(uri, body: {
        'chat_id': chatId.toString(),
        'user_id': widget.userId.toString(),
      });

      dynamic data;
      try {
        data = json.decode(res.body);
      } catch (_) {
        data = null;
      }

      final ok = res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'HTTP ${res.statusCode}';
        messenger.showSnackBar(SnackBar(content: Text("Не удалось выйти: $err")));
        return;
      }

      setState(() {
        _groups.removeWhere((c) => _asInt(c['id']) == chatId);
        _filtered.removeWhere((c) => _asInt(c['id']) == chatId);
      });

      messenger.showSnackBar(
        SnackBar(
          content: const Text("Вы вышли из группы"),
          action: SnackBarAction(label: "Обновить", onPressed: _reloadCurrentTab),
        ),
      );

      await _loadGroups();
      _applyFiltersAndSorting();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Ошибка сети: $e")));
    }
  }

  Future<void> _confirmLeaveGroup(Map<String, dynamic> chat) async {
    final title = _chatTitle(chat);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Выйти из группы?"),
        content: Text("Выйти из «$title»?\nВы больше не будете участником."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Выйти"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _leaveGroup(chat);
    }
  }

  // ===== DELETE GROUP =====
  Future<void> _deleteGroup(Map<String, dynamic> chat) async {
    final chatId = _asInt(chat['id']);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final uri = Uri.parse(_deleteGroupUrl);
      final res = await http.post(uri, body: {
        'chat_id': chatId.toString(),
        'user_id': widget.userId.toString(),
      });

      dynamic data;
      try {
        data = json.decode(res.body);
      } catch (_) {
        data = null;
      }

      final ok = res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'HTTP ${res.statusCode}';
        messenger.showSnackBar(SnackBar(content: Text("Не удалено: $err")));
        return;
      }

      setState(() {
        _groups.removeWhere((c) => _asInt(c['id']) == chatId);
        _filtered.removeWhere((c) => _asInt(c['id']) == chatId);
      });

      messenger.showSnackBar(
        SnackBar(
          content: const Text("Группа удалена"),
          action: SnackBarAction(label: "Обновить", onPressed: _reloadCurrentTab),
        ),
      );

      await _loadGroups();
      _applyFiltersAndSorting();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Ошибка сети: $e")));
    }
  }

  Future<void> _confirmDeleteGroup(Map<String, dynamic> chat) async {
    final title = _chatTitle(chat);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Удалить группу?"),
        content: Text(
          "Удалить «$title»?\nВсе сообщения и участники будут удалены.\nДействие необратимо.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteGroup(chat);
    }
  }

  // ===== PRIVATE ACTIONS =====
  Future<void> _togglePin(Map<String, dynamic> chat) async {
    final id = _asInt(chat['id']);
    setState(() {
      if (_pinned.contains(id)) {
        _pinned.remove(id);
      } else {
        _pinned.add(id);
      }
    });
    await _saveLocalState();
    _applyFiltersAndSorting();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_pinned.contains(id) ? "Чат закреплён" : "Чат откреплён"),
      ),
    );
  }

  Future<void> _archiveChat(Map<String, dynamic> chat) async {
    final id = _asInt(chat['id']);
    setState(() => _archived.add(id));
    await _saveLocalState();
    _applyFiltersAndSorting();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Чат перемещён в архив"),
        action: SnackBarAction(
          label: "Отмена",
          onPressed: () async {
            setState(() => _archived.remove(id));
            await _saveLocalState();
            _applyFiltersAndSorting();
          },
        ),
      ),
    );
  }

  Future<void> _deleteChat(Map<String, dynamic> chat) async {
    final id = _asInt(chat['id']);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final uri = Uri.parse(_deleteChatUrl);
      final res = await http.post(uri, body: {
        'chat_id': id.toString(),
        'user_id': widget.userId.toString(),
      });

      dynamic data;
      try {
        data = json.decode(res.body);
      } catch (_) {
        data = null;
      }

      final ok = res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'HTTP ${res.statusCode}';
        messenger.showSnackBar(SnackBar(content: Text("Не удалено: $err")));
        return;
      }

      setState(() {
        _privateChats.removeWhere((c) => _asInt(c['id']) == id);
        _filtered.removeWhere((c) => _asInt(c['id']) == id);
      });

      _pinned.remove(id);
      _archived.remove(id);
      await _saveLocalState();

      messenger.showSnackBar(
        SnackBar(
          content: const Text("Чат удалён"),
          action: SnackBarAction(label: "Обновить", onPressed: _reloadCurrentTab),
        ),
      );

      await _loadPrivateChats();
      _applyFiltersAndSorting();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Ошибка сети: $e")));
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> chat) async {
    final title = _chatTitle(chat);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Удалить чат?"),
        content: Text("Удалить «$title»?\nДействие необратимо."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteChat(chat);
    }
  }

  void _showPrivateActions(Map<String, dynamic> chat) {
    final id = _asInt(chat['id']);
    final pinned = _pinned.contains(id);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: const Text("Открыть"),
                  onTap: () {
                    Navigator.pop(context);
                    _openChat(chat);
                  },
                ),
                ListTile(
                  leading: Icon(
                      pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
                  title: Text(pinned ? "Открепить" : "Закрепить"),
                  onTap: () async {
                    Navigator.pop(context);
                    await _togglePin(chat);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.archive_rounded),
                  title: const Text("В архив"),
                  onTap: () async {
                    Navigator.pop(context);
                    await _archiveChat(chat);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.exit_to_app_rounded,
                      color: Color(0xFFF59E0B)),
                  title: const Text("Выйти из чата"),
                  onTap: () async {
                    Navigator.pop(context);
                    await _confirmLeavePrivateChat(chat);
                  },
                ),
                const SizedBox(height: 10),
                _DangerActionButton(
                  title: "Удалить чат",
                  subtitle: "Чат исчезнет из списка. Действие необратимо.",
                  icon: Icons.delete_rounded,
                  onTap: () async {
                    Navigator.pop(context);
                    await _confirmDelete(chat);
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== NEW CHAT: Search users =====
  Future<void> _openNewPrivateChatSheet() async {
    final chosen = await showModalBottomSheet<_UserPick?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _ChatStyle.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _NewPrivateChatSheet(
        apiUrl: _searchUsersUrl,
        myUserId: widget.userId,
      ),
    );

    if (chosen == null) return;
    await _createOrOpenPrivateChat(
      peerId: chosen.id,
      peerTitleForHeader: chosen.title,
    );
  }

  // ===== DISMISSIBLE =====
  Widget _buildDismissibleCard(Map<String, dynamic> chat) {
    final id = _asInt(chat['id']);
    final isPrivate = _isPrivate(chat);

    // ===== GROUPS =====
    if (!isPrivate) {
      final iAmMember = _iAmMember(chat);
      if (!iAmMember) return _buildTelegramTile(chat);

      final bgAction = Container(
        color: const Color(0xFFEEF2FF),
        padding: const EdgeInsets.only(right: 18),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.more_horiz_rounded, color: _ChatStyle.green),
            SizedBox(width: 8),
            Text(
              "Действие",
              style: TextStyle(
                color: _ChatStyle.green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

      return Dismissible(
        key: ValueKey("group_$id"),
        direction: DismissDirection.endToStart,
        background: bgAction,
        confirmDismiss: (_) async {
          final isOwner = _iAmOwner(chat);
          final title = _chatTitle(chat);

          final action = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            builder: (_) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.exit_to_app_rounded,
                            color: Color(0xFFF59E0B)),
                        title: const Text("Выйти из группы"),
                        subtitle:
                            Text("Вы больше не будете участником «$title»."),
                        onTap: () => Navigator.pop(context, "leave"),
                      ),
                      if (isOwner) ...[
                        const SizedBox(height: 6),
                        ListTile(
                          leading: const Icon(Icons.delete_forever_rounded,
                              color: Color(0xFFEF4444)),
                          title: const Text("Удалить группу"),
                          subtitle: const Text(
                              "Удалит участников и все сообщения. Необратимо."),
                          onTap: () => Navigator.pop(context, "delete"),
                        ),
                      ],
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              );
            },
          );

          if (action == "leave") {
            await _confirmLeaveGroup(chat);
          } else if (action == "delete") {
            await _confirmDeleteGroup(chat);
          }
          return false;
        },
        child: _buildTelegramTile(chat),
      );
    }

    // ===== PRIVATE CHATS (2-way swipe) =====
    final bgLeave = Container(
      color: const Color(0xFFFFF7ED),
      padding: const EdgeInsets.only(left: 18),
      alignment: Alignment.centerLeft,
      child: const Row(
        children: [
          Icon(Icons.exit_to_app_rounded, color: Color(0xFFF59E0B)),
          SizedBox(width: 8),
          Text(
            "Выйти",
            style: TextStyle(
              color: Color(0xFFF59E0B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    final bgDelete = Container(
      color: const Color(0xFFFFF1F2),
      padding: const EdgeInsets.only(right: 18),
      alignment: Alignment.centerRight,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
          SizedBox(width: 8),
          Text(
            "Удалить",
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    return Dismissible(
      key: ValueKey("chat_$id"),
      direction: DismissDirection.horizontal,
      background: bgLeave,
      secondaryBackground: bgDelete,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _confirmLeavePrivateChat(chat);
        } else if (direction == DismissDirection.endToStart) {
          await _confirmDelete(chat);
        }
        return false;
      },
      child: _buildTelegramTile(chat),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final title = _tab == _ChatTab.privateChats ? 'Личные чаты' : 'Группы';
    final subtitle = _tab == _ChatTab.privateChats
        ? '${_filtered.length} диалогов'
        : '${_filtered.length} групп';

    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: const TextScaler.linear(1.08)),
      child: Scaffold(
      extendBody: true,
      backgroundColor: _ChatStyle.bg,
      appBar: AppBar(
        toolbarHeight: 66,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _ChatStyle.bg,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 10,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _tab == _ChatTab.privateChats
                    ? Icons.chat_bubble_rounded
                    : Icons.groups_rounded,
                color: _ChatStyle.green,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ChatStyle.text,
                      fontSize: 17.2,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ChatStyle.muted,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w500,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _HeaderCircleButton(
              icon: isSearching ? Icons.close_rounded : Icons.search_rounded,
              onTap: () {
                setState(() {
                  isSearching = !isSearching;
                  if (!isSearching) _searchController.clear();
                });
                _applyFiltersAndSorting();
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _tabChip(
                      label: "Личные",
                      icon: Icons.chat_bubble_rounded,
                      selected: _tab == _ChatTab.privateChats,
                      onTap: () async {
                        if (_tab == _ChatTab.privateChats) return;
                        setState(() => _tab = _ChatTab.privateChats);
                        await _reloadCurrentTab();
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _tabChip(
                      label: "Группы",
                      icon: Icons.groups_rounded,
                      selected: _tab == _ChatTab.groups,
                      onTap: () async {
                        if (_tab == _ChatTab.groups) return;
                        setState(() => _tab = _ChatTab.groups);
                        await _reloadCurrentTab();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
              child: _MatteSurface(
                radius: 13,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _tab == _ChatTab.privateChats
                        ? 'Поиск личных чатов...'
                        : 'Поиск групп...',
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search_rounded, color: _ChatStyle.muted, size: 18),
                    isDense: true,
                  ),
                  autofocus: true,
                ),
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: _ChatStyle.green))
                : _filtered.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        color: _ChatStyle.green,
                        onRefresh: _reloadCurrentTab,
                        child: _TelegramList(
                          children: List<Widget>.generate(_filtered.length, (i) {
                            final item = _filtered[i];
                            return _buildDismissibleCard(item);
                          }),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 0,
        backgroundColor: _ChatStyle.green,
        shape: const CircleBorder(),
        onPressed: () async {
          if (_tab == _ChatTab.groups) {
            final ok = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateGroupChatScreen(userId: widget.userId),
              ),
            );
            if (ok == true) await _reloadCurrentTab();
          } else {
            await _openNewPrivateChatSheet();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 52,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'Ничего не найдено' : 'Пока пусто',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _tab == _ChatTab.groups
                  ? 'Создайте группу или вступите в открытую'
                  : 'Нажмите +, чтобы начать диалог',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ===== Telegram-like tile (STRICT 2 lines) =====
  Widget _buildTelegramTile(Map<String, dynamic> chat) {
    final title = _chatTitle(chat);
    final peerPhoto = _peerPhoto(chat);

    final isPrivate = _isPrivate(chat);
    final isGroup = !isPrivate;

    final rightTime = _chatRightTime(chat);
    final unread = int.tryParse((chat['unread_count'] ?? '0').toString()) ?? 0;
    final id = _asInt(chat['id']);
    final pinned = _pinned.contains(id);

    final isPublic = isGroup ? _isPublicGroup(chat) : false;
    final iAmMember = isGroup ? _iAmMember(chat) : true;

    final rawLast = (chat['last_message'] ?? '').toString().trim();
    final hasLast = rawLast.isNotEmpty;
    final secondLine = hasLast
        ? rawLast
        : (isGroup
            ? _groupStatusLine(isPublic: isPublic, iAmMember: iAmMember)
            : "Напишите первым");

    return Container(
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (isGroup && isPublic && !iAmMember) {
              _showJoinDialog(chat);
              return;
            }
            _openChat(chat);
          },
          onLongPress: isPrivate ? () => _showPrivateActions(chat) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isPrivate ? _ChatStyle.greenSoft : const Color(0xFFF4F7FF),
                        shape: BoxShape.circle,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: (isPrivate && peerPhoto.isNotEmpty)
                            ? Image.network(
                                peerPhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.person_rounded, color: _ChatStyle.green),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  isPrivate
                                      ? Icons.person_rounded
                                      : (isPublic ? Icons.public_rounded : Icons.lock_outline_rounded),
                                  color: isPrivate ? _ChatStyle.green : _ChatStyle.blue,
                                ),
                              ),
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: const BoxDecoration(
                            color: _ChatStyle.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (isPrivate && pinned)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: _ChatStyle.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.push_pin_rounded, size: 13, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13.4,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                color: _ChatStyle.text,
                                letterSpacing: -.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isGroup) ...[
                            const SizedBox(width: 8),
                            _MiniChip(
                              text: isPublic ? "Открытая" : "Закрытая",
                              tone: isPublic ? _ChipTone.blue : _ChipTone.orange,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        secondLine,
                        style: TextStyle(
                          fontSize: 11.2,
                          height: 1.15,
                          color: hasLast ? _ChatStyle.muted : const Color(0xFF98A2B3),
                          fontWeight: hasLast ? FontWeight.w500 : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rightTime,
                      style: const TextStyle(fontSize: 10.3, color: Color(0xFF98A2B3), fontWeight: FontWeight.w600),
                    ),
                    if (unread > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _ChatStyle.green,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(color: Colors.white, fontSize: 9.8, fontWeight: FontWeight.w700, height: 1.0),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _tabChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE2F7EA) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? _ChatStyle.green : _ChatStyle.muted, size: 17),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? _ChatStyle.green : const Color(0xFF344054),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.4,
                  height: 1.0,
                ),
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? _ChatStyle.green : const Color(0xFFEFF2F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge > 99 ? "99+" : badge.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : _ChatStyle.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} // ✅ _ChatScreenState


class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _ChatStyle.text, size: 19),
        ),
      ),
    );
  }
}

/// ====== New private chat sheet ======
class _NewPrivateChatSheet extends StatefulWidget {
  final String apiUrl;
  final int myUserId;

  const _NewPrivateChatSheet({
    required this.apiUrl,
    required this.myUserId,
  });

  @override
  State<_NewPrivateChatSheet> createState() => _NewPrivateChatSheetState();
}

class _NewPrivateChatSheetState extends State<_NewPrivateChatSheet> {
  final TextEditingController _q = TextEditingController();
  Timer? _deb;
  bool _loading = false;
  String? _error;

  List<_UserPick> _items = [];

  @override
  void initState() {
    super.initState();
    _q.addListener(_onQueryChanged);
    _load("");
  }

  @override
  void dispose() {
    _deb?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 280), () {
      _load(_q.text.trim());
    });
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(widget.apiUrl).replace(queryParameters: {
        'q': query,
        'exclude_id': widget.myUserId.toString(),
      });

      final res = await http.get(uri);

      dynamic data;
      try {
        data = json.decode(res.body);
      } catch (_) {
        data = null;
      }

      if (res.statusCode != 200 || data == null) {
        setState(() {
          _error = "Не удалось загрузить пользователей";
          _items = [];
          _loading = false;
        });
        return;
      }

      List list;
      if (data is Map && data['success'] == true) {
        list = (data['users'] as List? ?? const []);
      } else if (data is List) {
        list = data;
      } else {
        list = const [];
      }

      final parsed = <_UserPick>[];
      for (final x in list) {
        if (x is! Map) continue;
        final id = int.tryParse((x['id'] ?? '0').toString()) ?? 0;
        if (id <= 0) continue;
        if (id == widget.myUserId) continue;

        final first =
            (x['first_name'] ?? x['firstname'] ?? '').toString().trim();
        final last =
            (x['last_name'] ?? x['lastname'] ?? '').toString().trim();
        final email = (x['email'] ?? '').toString().trim();

        final full = ("$first $last").trim();
        final title = full.isNotEmpty
            ? full
            : (email.isNotEmpty ? email : "Пользователь #$id");

        final rawPhoto = (x['photo'] ?? x['avatar'] ?? '').toString().trim();
        final photo = rawPhoto.isEmpty || rawPhoto.toLowerCase() == 'null'
            ? ""
            : (rawPhoto.startsWith('http')
                ? rawPhoto
                : "https://sportotekaapp.ru/uploads/$rawPhoto");

        parsed.add(
            _UserPick(id: id, title: title, subtitle: email, photo: photo));
      }

      setState(() {
        _items = parsed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Ошибка сети: $e";
        _items = [];
        _loading = false;
      });
    }
  }

    @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.76,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _ChatStyle.greenSoft,
                      borderRadius: BorderRadius.circular(12),
                      
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: _ChatStyle.greenDark, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Новый чат',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _ChatStyle.text,
                            fontSize: 15.2,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                            letterSpacing: -.22,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Выберите пользователя для диалога',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _ChatStyle.muted,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _MatteSurface(
                radius: 13,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 0),
                child: TextField(
                  controller: _q,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: _ChatStyle.muted),
                    hintText: 'Поиск: имя, фамилия или email',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  autofocus: true,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _ChatStyle.green))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? const Center(
                              child: Text(
                                'Никого не нашли',
                                style: TextStyle(color: _ChatStyle.muted, fontSize: 12.2, fontWeight: FontWeight.w500),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 1),
                              itemBuilder: (_, i) {
                                final u = _items[i];
                                return Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => Navigator.pop(context, u),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Row(
                                        children: [
                                          _UserAvatar(photo: u.photo, title: u.title),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  u.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13.0,
                                                    fontWeight: FontWeight.w700,
                                                    color: _ChatStyle.text,
                                                    height: 1.1,
                                                  ),
                                                ),
                                                if (u.subtitle?.trim().isNotEmpty ?? false) ...[
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    u.subtitle!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 11.0,
                                                      color: _ChatStyle.muted,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right_rounded, size: 18, color: _ChatStyle.muted),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

}

class _UserPick {
  final int id;
  final String title;
  final String? subtitle;
  final String photo;

  const _UserPick({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.photo,
  });
}

class _UserAvatar extends StatelessWidget {
  final String photo;
  final String title;

  const _UserAvatar({
    required this.photo,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final initials = title.trim().isEmpty
        ? "U"
        : title
            .trim()
            .split(RegExp(r"\s+"))
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : "")
            .join();

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _ChatStyle.greenSoft,
        
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: (photo.isNotEmpty)
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _ChatStyle.green),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, color: _ChatStyle.green),
                ),
              ),
      ),
    );
  }
}

/// ====== Telegram-like list wrapper ======
class _TelegramList extends StatelessWidget {
  const _TelegramList({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(6, 4, 6, MediaQuery.paddingOf(context).bottom + 112),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 1),
      itemBuilder: (_, i) => children[i],
    );
  }
}

class _TelegramDivider extends StatelessWidget {
  const _TelegramDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 8);
}

enum _ChipTone { blue, orange }

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.text, required this.tone});
  final String text;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final bg = tone == _ChipTone.blue
        ? const Color(0xFFE3F2FD)
        : const Color(0xFFFFF3E0);
    final fg = tone == _ChipTone.blue
        ? _ChatStyle.green
        : const Color(0xFFB45309);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.2,
          fontWeight: FontWeight.w700,
          height: 1.0,
          color: fg,
        ),
      ),
    );
  }
}

/// ===== Mat surface =====
class _MatteSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _MatteSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          onLongPress: onLongPress,
          child: content,
        ),
      );
    }
    return content;
  }
}

/// ===== Красная “опасная” кнопка =====
class _DangerActionButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DangerActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_DangerActionButton> createState() => _DangerActionButtonState();
}

class _DangerActionButtonState extends State<_DangerActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _press() async {
    await _c.forward();
    await _c.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final scale = 1.0 - (t * 0.04);

        return Transform.scale(
          scale: scale,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _press,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE1E1)),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF5F5), Color(0xFFFFECEC)],
                ),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x22EF4444),
                      blurRadius: 18,
                      offset: Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x33EF4444),
                            blurRadius: 14,
                            offset: Offset(0, 6)),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF7F1D1D)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF991B1B)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}