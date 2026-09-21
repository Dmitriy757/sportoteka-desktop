// lib/presentation/chat_screen/chat_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';
import 'package:sportoteka/presentation/chat_screen/call_history_panel.dart';
import 'package:sportoteka/presentation/chat_screen/cmr_notifications_panel.dart';
import 'package:sportoteka/presentation/chat_screen/create_group_chat_screen.dart';
import 'package:sportoteka/presentation/chat_screen/sportoteka_news_screen.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_club_ai_assistant_panel.dart';

class _ChatStyle {
  static const Color bg = Colors.white;
  static const Color card = Colors.white;
  static const Color soft = Color(0xFFF7F9F8);
  static const Color soft2 = Color(0xFFF2F5F3);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color line = Color(0xFFEDF0EE);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF667085);
  static const Color muted2 = Color(0xFF98A2B3);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFD92D20);
  static const Color blue = Color(0xFF067A46);
  static const Color blueSoft = Color(0xFFF3FAF6);
  static const Color orange = Color(0xFFF59E0B);
  static const Color border = Color(0xFFEDF0EE);
  static const Color greenBorder = Color(0xFFDDEFE5);
}

class _ChatText {
  static TextStyle title(
    double size, {
    Color color = _ChatStyle.text,
    FontWeight weight = FontWeight.w600,
  }) {
    final TextStyle base;
    if (size >= 15) {
      base = AppTypography.screenTitle(color: color);
    } else if (size >= 13.5) {
      base = AppTypography.sectionTitle(color: color);
    } else if (size >= 11.5) {
      base = AppTypography.itemTitle(color: color);
    } else {
      base = AppTypography.captionMedium(color: color);
    }
    return base.copyWith(fontWeight: weight);
  }

  static TextStyle body(
    double size, {
    Color color = _ChatStyle.muted,
    FontWeight weight = FontWeight.w400,
  }) {
    final TextStyle base;
    if (size >= 12.2) {
      base = AppTypography.body(color: color);
    } else if (size >= 11) {
      base = AppTypography.secondary(color: color);
    } else if (size >= 10) {
      base = AppTypography.caption(color: color);
    } else {
      base = AppTypography.commentMeta(color: color);
    }
    return base.copyWith(fontWeight: weight);
  }
}

class _ChatDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _ChatDot({
    required this.color,
    required this.size,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ChatDots extends StatelessWidget {
  final Color color;
  final bool compact;

  const _ChatDots({
    this.color = _ChatStyle.green,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scale = compact ? .76 : 1.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ChatDot(
          color: color,
          size: 3.4 * scale,
          opacity: .32,
        ),
        SizedBox(width: 3 * scale),
        _ChatDot(
          color: color,
          size: 4.4 * scale,
          opacity: .55,
        ),
        SizedBox(width: 3 * scale),
        _ChatDot(
          color: color,
          size: 5.4 * scale,
          opacity: .78,
        ),
        SizedBox(width: 3 * scale),
        _ChatDot(
          color: color,
          size: 6.4 * scale,
        ),
      ],
    );
  }
}

class ChatScreen extends StatefulWidget {
  final int userId;

  /// ✅ отдаём наверх актуальный total unread (для bottom bar)
  final ValueChanged<int>? onUnreadChanged;

  /// Контекст клубного режима. В обычном аккаунте SPORTOTEKA AI работает
  /// как личный помощник, а из Club Workspace — как клубный AI.
  final bool clubMode;
  final int? clubId;
  final int? teamId;
  final String? clubName;
  final String? teamName;

  const ChatScreen({
    super.key,
    required this.userId,
    this.onUnreadChanged,
    this.clubMode = false,
    this.clubId,
    this.teamId,
    this.clubName,
    this.teamName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum _ChatTab { notifications, privateChats, groups, calls }

class _ChatScreenState extends State<ChatScreen> {
  static const _apiBase = 'https://sportotekaapp.ru/api';

  // ✅ endpoints
  static const _createChatUrl = '$_apiBase/create_chat.php';
  static const _searchUsersUrl = '$_apiBase/search_users.php';

  static const _unreadTotalUrl = '$_apiBase/get_unread_total.php';
  static const _markReadUrl = '$_apiBase/mark_chat_read.php';

  static const _deleteChatUrl = '$_apiBase/delete_chat_soft.php';
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
  int _unreadTotal = 0; // ✅ сообщения
  int _notificationUnread = 0; // ✅ системные уведомления
  int _newsUnread = 0;
  bool _newsVisible = false;
  Map<String, dynamic>? _newsLatest;

  _ChatTab _tab = _ChatTab.privateChats;

  // На планшете и ПК чат открываем внутри этого же экрана, а не через
  // вложенный Navigator. На планшете список остаётся слева, переписка справа;
  // это совпадает с рабочей логикой CMR и ускоряет переключение между чатами.
  Map<String, dynamic>? _selectedChat;
  int? _selectedChatId;
  String _selectedChatName = '';

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _chatListScrollController = ScrollController();

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
    await _fetchUnreadTotal();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chatListScrollController.dispose();
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

  bool get _useEmbeddedChatLayout {
    if (!mounted) return false;
    final localWidth = context.size?.width;
    final mediaWidth = MediaQuery.maybeOf(context)?.size.width;
    final width = localWidth ?? mediaWidth ?? 0;
    return width >= 700;
  }

  void _closeEmbeddedChat() {
    if (!mounted) return;
    setState(() {
      _selectedChat = null;
      _selectedChatId = null;
      _selectedChatName = '';
    });
  }

  bool _isPrivate(Map<String, dynamic> chat) => (chat['is_private'] == 1 ||
      chat['is_private'] == "1" ||
      chat['is_private'] == true);

  bool _isPublicGroup(Map<String, dynamic> chat) => (chat['is_public'] == 1 ||
      chat['is_public'] == "1" ||
      chat['is_public'] == true);

  bool _iAmMember(Map<String, dynamic> chat) => (chat['i_am_member'] == 1 ||
      chat['i_am_member'] == "1" ||
      chat['i_am_member'] == true);

  bool _iAmOwner(Map<String, dynamic> chat) =>
      _asInt(chat['owner_id']) == widget.userId;

  bool _isDeletedChat(Map<String, dynamic> chat) {
    final raw = chat['is_deleted'] ?? chat['deleted'];
    if (raw == true || raw == 1 || raw == '1') return true;
    final status = (chat['status'] ?? chat['chat_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return status == 'deleted' || status == 'archived_deleted';
  }

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
    } else if (_tab == _ChatTab.groups) {
      await _loadGroups();
    } else {
      if (mounted) setState(() => isLoading = false);
      return;
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

  Future<int> _snapshotNewsUnread() async {
    try {
      final uri = Uri.parse(
        '$_apiBase/sportoteka_news/summary.php?user_id=${widget.userId}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return 0;

      final decoded = json.decode(res.body);
      if (decoded is! Map || decoded['success'] != true) return 0;

      final visible = decoded['visible'] == true ||
          decoded['visible'] == 1 ||
          decoded['visible'] == '1';
      final unread = int.tryParse('${decoded['unread_count'] ?? 0}') ?? 0;
      final latest = decoded['latest'] is Map
          ? Map<String, dynamic>.from(decoded['latest'] as Map)
          : null;

      if (mounted) {
        final changed = visible != _newsVisible ||
            unread != _newsUnread ||
            '${latest?['id'] ?? ''}' != '${_newsLatest?['id'] ?? ''}';

        if (changed) {
          setState(() {
            _newsVisible = visible;
            _newsUnread = visible ? unread : 0;
            _newsLatest = latest;
          });
        }
      }

      return visible ? unread : 0;
    } catch (_) {
      return _newsVisible ? _newsUnread : 0;
    }
  }

  Future<void> _openSportotekaNews() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SportotekaNewsScreen(
          userId: widget.userId,
          onUnreadChanged: (_) {
            if (!mounted) return;
            setState(() => _newsUnread = 0);
          },
          onHidden: () {
            if (!mounted) return;
            setState(() {
              _newsVisible = false;
              _newsUnread = 0;
            });
          },
        ),
      ),
    );

    await _fetchUnreadTotal();
  }

  Future<void> _hideSportotekaNews() async {
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/sportoteka_news/hide.php'),
        body: <String, String>{
          'user_id': widget.userId.toString(),
        },
      ).timeout(const Duration(seconds: 8));

      final decoded = json.decode(res.body);
      if (res.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true &&
          mounted) {
        setState(() {
          _newsVisible = false;
          _newsUnread = 0;
        });
        await _fetchUnreadTotal();
      }
    } catch (_) {}
  }

  Future<bool> _confirmHideSportotekaNews() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Удалить SPORTOTEKA Новости?',
          style: _ChatText.title(13.5),
        ),
        content: Text(
          'Канал исчезнет из списка. После следующего сообщения '
          'SPORTOTEKA он появится снова автоматически.',
          style: _ChatText.body(11.0),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _ChatStyle.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Widget _sportotekaNewsEntry() {
    final latestTitle =
        '${_newsLatest?['title'] ?? 'SPORTOTEKA Новости'}'.trim();
    final latestBody = '${_newsLatest?['body'] ?? ''}'.trim();

    final preview = latestBody.isNotEmpty
        ? latestBody
        : (latestTitle.isNotEmpty
            ? latestTitle
            : 'Официальный канал SPORTOTEKA');

    return Dismissible(
      key: const ValueKey<String>('sportoteka-news-channel'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmHideSportotekaNews(),
      onDismissed: (_) => unawaited(_hideSportotekaNews()),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: _ChatStyle.red,
          size: 18,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openSportotekaNews,
          onLongPress: () async {
            final hide = await _confirmHideSportotekaNews();
            if (hide) await _hideSportotekaNews();
          },
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _ChatStyle.greenSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: const _ChatDots(compact: true),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              'SPORTOTEKA Новости',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _ChatText.title(
                                11.8,
                                color: _ChatStyle.text,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: _ChatStyle.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _ChatText.body(
                          9.7,
                          color: _ChatStyle.muted,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_newsUnread > 0)
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: _ChatStyle.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _newsUnread > 99 ? '99+' : '$_newsUnread',
                          style: _ChatText.body(
                            9.2,
                            color: _ChatStyle.red,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: _ChatStyle.muted2,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startUnreadPolling() {
    _unreadTimer?.cancel();
    unawaited(_fetchUnreadTotal());
    unawaited(_fetchNotificationUnread());
    _unreadTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      unawaited(_fetchUnreadTotal());
      unawaited(_fetchNotificationUnread());
    });
  }

  int _sumUnread(List<Map<String, dynamic>> items) {
    var total = 0;
    for (final item in items) {
      final value = int.tryParse((item['unread_count'] ?? '0').toString()) ?? 0;
      if (value > 0) total += value;
    }
    return total;
  }

  Future<int> _snapshotPrivateUnread() async {
    try {
      final uri = Uri.parse('$_privateChatsUrl?user_id=${widget.userId}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return 0;

      final decoded = json.decode(res.body);
      if (decoded is! List) return 0;

      final items = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where(_isPrivate)
          .toList();

      return _sumUnread(items);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _snapshotGroupUnread() async {
    try {
      final uri = Uri.parse('$_groupsFeedUrl?user_id=${widget.userId}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return 0;

      final decoded = json.decode(res.body);
      if (decoded is! Map || decoded['success'] != true) return 0;

      final raw = decoded['groups'];
      if (raw is! List) return 0;

      final items = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => _iAmMember(e))
          .toList();

      return _sumUnread(items);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _fetchUnreadTotal() async {
    final values = await Future.wait<int>([
      _snapshotPrivateUnread(),
      _snapshotGroupUnread(),
      _snapshotNewsUnread(),
    ]);

    final total = (values[0] + values[1] + values[2]).clamp(0, 9999);

    if (!mounted) return;

    if (total != _unreadTotal) {
      setState(() => _unreadTotal = total);
    }

    await PrefUtils.setUnreadChatsCount(total);
    widget.onUnreadChanged?.call(total);
  }

  Future<void> _fetchNotificationUnread() async {
    var value = 0;
    try {
      final uri = Uri.parse(
        '$_apiBase/notifications/unread_count.php?user_id=${widget.userId}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is Map && decoded['success'] == true) {
          value =
              int.tryParse((decoded['unread_count'] ?? '0').toString()) ?? 0;
        }
      }
    } catch (_) {
      value = 0;
    }

    value = value.clamp(0, 9999);
    if (!mounted || value == _notificationUnread) return;
    setState(() => _notificationUnread = value);
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
    if (_tab == _ChatTab.calls || _tab == _ChatTab.notifications) {
      if (mounted && _filtered.isNotEmpty) {
        setState(() => _filtered = <Map<String, dynamic>>[]);
      }
      return;
    }

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

    // Сразу снимаем локально, чтобы бейдж исчез без задержки.
    if (unread > 0) {
      await _markChatReadLocal(chatId, unread);
      _markChatReadServer(chatId);
      final newTotal = _unreadTotal;
      unawaited(PrefUtils.setUnreadChatsCount(newTotal));
      widget.onUnreadChanged?.call(newTotal);
    }

    if (!mounted) return;

    // Планшет/ПК: не пушим новый экран во вложенный Navigator профиля.
    // Вместо этого открываем переписку в адаптивной области текущего экрана.
    if (_useEmbeddedChatLayout) {
      setState(() {
        _selectedChat = Map<String, dynamic>.from(chat);
        _selectedChatId = chatId;
        _selectedChatName = title;
      });
      return;
    }

    // Телефон: обычный полноэкранный маршрут.
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

    if (!mounted) return;
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

      final ok =
          res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'HTTP ${res.statusCode}';
        if (mounted && messenger.mounted)
          messenger.showSnackBar(
            SnackBar(content: Text("Не удалось создать чат: $err")),
          );
        return;
      }

      final chatId = int.tryParse((data['chat_id'] ?? '0').toString()) ?? 0;
      if (chatId <= 0) {
        if (mounted && messenger.mounted)
          messenger.showSnackBar(
            const SnackBar(content: Text("Не удалось получить chat_id")),
          );
        return;
      }

      if (!mounted) return;

      final title = peerTitleForHeader ?? "Личный чат";

      if (_useEmbeddedChatLayout) {
        setState(() {
          _tab = _ChatTab.privateChats;
          _selectedChatId = chatId;
          _selectedChatName = title;
          _selectedChat = <String, dynamic>{
            'id': chatId,
            'title': title,
            'name': title,
            'is_private': 1,
          };
        });
        unawaited(_reloadCurrentTab());
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            chatId: chatId,
            userId: widget.userId,
            chatName: title,
          ),
        ),
      ).then((_) {
        if (mounted) unawaited(_reloadCurrentTab());
      });
    } catch (e) {
      if (mounted && messenger.mounted)
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

      final ok =
          res.statusCode == 200 && data is Map && data['success'] == true;

      if (!ok) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'unknown';
        if (mounted && messenger.mounted)
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
      if (mounted && messenger.mounted)
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

      final ok =
          res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'HTTP ${res.statusCode}';
        messenger
            .showSnackBar(SnackBar(content: Text("Не удалось выйти: $err")));
        return;
      }

      setState(() {
        _privateChats.removeWhere((c) => _asInt(c['id']) == chatId);
        _filtered.removeWhere((c) => _asInt(c['id']) == chatId);
      });

      _pinned.remove(chatId);
      _archived.remove(chatId);
      await _saveLocalState();

      if (mounted && messenger.mounted)
        messenger.showSnackBar(
          SnackBar(
            content: const Text("Вы вышли из личного чата"),
            action:
                SnackBarAction(label: "Обновить", onPressed: _reloadCurrentTab),
          ),
        );

      await _loadPrivateChats();
      _applyFiltersAndSorting();
    } catch (e) {
      if (mounted && messenger.mounted)
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

      final ok =
          res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'HTTP ${res.statusCode}';
        messenger
            .showSnackBar(SnackBar(content: Text("Не удалось выйти: $err")));
        return;
      }

      setState(() {
        _groups.removeWhere((c) => _asInt(c['id']) == chatId);
        _filtered.removeWhere((c) => _asInt(c['id']) == chatId);
      });

      if (mounted && messenger.mounted)
        messenger.showSnackBar(
          SnackBar(
            content: const Text("Вы вышли из группы"),
            action:
                SnackBarAction(label: "Обновить", onPressed: _reloadCurrentTab),
          ),
        );

      await _loadGroups();
      _applyFiltersAndSorting();
    } catch (e) {
      if (mounted && messenger.mounted)
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

      final ok =
          res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'HTTP ${res.statusCode}';
        if (mounted && messenger.mounted)
          messenger.showSnackBar(SnackBar(content: Text("Не удалено: $err")));
        return;
      }

      setState(() {
        _groups.removeWhere((c) => _asInt(c['id']) == chatId);
        _filtered.removeWhere((c) => _asInt(c['id']) == chatId);
      });

      if (mounted && messenger.mounted)
        messenger.showSnackBar(
          SnackBar(
            content: const Text("Группа удалена"),
            action:
                SnackBarAction(label: "Обновить", onPressed: _reloadCurrentTab),
          ),
        );

      await _loadGroups();
      _applyFiltersAndSorting();
    } catch (e) {
      if (mounted && messenger.mounted)
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

      final ok =
          res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        final err = (data is Map &&
                (data['error'] != null || data['message'] != null))
            ? (data['error'] ?? data['message']).toString()
            : 'HTTP ${res.statusCode}';
        if (mounted && messenger.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Не удалось удалить чат: $err')),
          );
        }
        return;
      }

      // Soft delete: физически чат и сообщения не удаляем.
      // Для текущего пользователя чат сразу уходит из основного списка.
      setState(() {
        _archived.add(id);
        _privateChats.removeWhere((c) => _asInt(c['id']) == id);
        _filtered.removeWhere((c) => _asInt(c['id']) == id);
      });

      _pinned.remove(id);
      await _saveLocalState();

      if (mounted && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Чат перемещён в архив'),
          ),
        );
      }

      await _loadPrivateChats();
      _applyFiltersAndSorting();
    } catch (e) {
      if (mounted && messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Ошибка сети: $e')));
      }
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> chat) async {
    final title = _chatTitle(chat);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить чат?'),
        content: Text(
          '«$title» будет перемещён в архив.\n'
          'Сообщения не удаляются с сервера. Для остальных участников '
          'чат будет отмечен как «Чат удалён».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
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
                  leading: Icon(pinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded),
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
                  subtitle: "В архив. История останется на сервере.",
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

  Widget _wideChatActions(Map<String, dynamic> chat) {
    final isPrivate = _isPrivate(chat);
    final deleted = _isDeletedChat(chat);
    final id = _asInt(chat['id']);
    final pinned = _pinned.contains(id);

    return PopupMenuButton<String>(
      tooltip: 'Действия с чатом',
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: _ChatStyle.muted,
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        switch (value) {
          case 'open':
            if (!deleted) _openChat(chat);
            break;
          case 'pin':
            if (isPrivate && !deleted) await _togglePin(chat);
            break;
          case 'archive':
            if (isPrivate && !deleted) await _archiveChat(chat);
            break;
          case 'leave':
            if (isPrivate && !deleted) await _confirmLeavePrivateChat(chat);
            break;
          case 'delete':
            if (isPrivate && !deleted) await _confirmDelete(chat);
            break;
          case 'leave_group':
            if (!isPrivate && !deleted) await _confirmLeaveGroup(chat);
            break;
          case 'delete_group':
            if (!isPrivate && !deleted) await _confirmDeleteGroup(chat);
            break;
        }
      },
      itemBuilder: (_) {
        if (deleted) {
          return const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              enabled: false,
              value: 'deleted',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 19),
                  SizedBox(width: 10),
                  Text('Чат удалён'),
                ],
              ),
            ),
          ];
        }

        if (isPrivate) {
          return <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'open',
              child: Text('Открыть'),
            ),
            PopupMenuItem<String>(
              value: 'pin',
              child: Text(pinned ? 'Открепить' : 'Закрепить'),
            ),
            const PopupMenuItem<String>(
              value: 'archive',
              child: Text('В архив'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'leave',
              child: Text('Выйти из чата'),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Text(
                'Удалить чат',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          ];
        }

        final items = <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'leave_group',
            child: Text('Выйти из группы'),
          ),
        ];
        if (_iAmOwner(chat)) {
          items.add(
            const PopupMenuItem<String>(
              value: 'delete_group',
              child: Text(
                'Удалить группу',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          );
        }
        return items;
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

  bool get _aiUnlocked => widget.userId > 0;

  bool get _clubAiMode => widget.clubMode && (widget.clubId ?? 0) > 0;

  Future<void> _openSportotekaAi() async {
    if (!_aiUnlocked) {
      await _showSportotekaAiLocked();
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) => Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            top: true,
            bottom: false,
            child: CmrClubAiAssistantPanel(
              clubId: _clubAiMode ? widget.clubId! : 0,
              userId: widget.userId,
              teamId: _clubAiMode ? widget.teamId : null,
              clubName: _clubAiMode ? widget.clubName : 'Личный помощник',
              teamName: _clubAiMode ? widget.teamName : null,
              personalProfileMode: !_clubAiMode,
              onBack: () => Navigator.of(routeContext).maybePop(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSportotekaAiLocked() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
        actionsPadding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _ChatStyle.greenSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const _ChatDots(compact: true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'SPORTOTEKA ИИ',
                style: _ChatText.title(14.2),
              ),
            ),
            const Icon(
              Icons.lock_rounded,
              color: _ChatStyle.greenDark,
              size: 18,
            ),
          ],
        ),
        content: Text(
          'Не удалось определить пользователя. Войдите в профиль SPORTOTEKA и повторите попытку.',
          style: _ChatText.body(11.4, color: _ChatStyle.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Widget _sportotekaAiEntry() {
    final unlocked = _aiUnlocked;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openSportotekaAi,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: unlocked ? _ChatStyle.greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unlocked ? _ChatStyle.greenBorder : _ChatStyle.line,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _ChatStyle.greenSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const _ChatDots(compact: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'SPORTOTEKA ИИ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _ChatText.title(
                              11.8,
                              color: _ChatStyle.text,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (unlocked)
                          const Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: _ChatStyle.green,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unlocked
                          ? (_clubAiMode
                              ? 'ИИ клуба · анализ, изображения и видео'
                              : 'Личный AI · чат, изображения и видео')
                          : 'Спортотека AI временно недоступен',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ChatText.body(
                        9.7,
                        color: _ChatStyle.muted,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                unlocked ? Icons.chevron_right_rounded : Icons.lock_rounded,
                size: unlocked ? 18 : 16,
                color: unlocked ? _ChatStyle.greenDark : _ChatStyle.muted2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final subtitle = switch (_tab) {
      _ChatTab.notifications => _notificationUnread > 0
          ? '$_notificationUnread непрочитанных'
          : 'Всё прочитано',
      _ChatTab.privateChats => '${_filtered.length} диалогов',
      _ChatTab.groups => '${_filtered.length} групп',
      _ChatTab.calls => 'История звонков',
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: true,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;

              final phone = width < 700;
              final tablet = width >= 700 && width < 1280;
              final chatsTab = _tab == _ChatTab.privateChats ||
                  _tab == _ChatTab.groups;
              final splitMessenger = width >= 700 && chatsTab;

              // И на телефоне, и на планшете список чатов получает собственную
              // складывающуюся шапку. Большие карточки уходят вверх вместе со
              // списком, а сверху остаётся только короткая понятная панель.
              final useCollapsingListHeader =
                  chatsTab && (phone || tablet);
              final hideMainAppBar = useCollapsingListHeader;

              return Scaffold(
                extendBody: true,
                resizeToAvoidBottomInset: true,
                backgroundColor: Colors.white,
                appBar: hideMainAppBar ? null : _buildMainAppBar(subtitle),
                body: splitMessenger
                    ? _buildDesktopMessenger(
                        scrollListHeaderAway: tablet,
                      )
                    : _buildMainListContent(
                        compactPane: !phone && width < 900,
                        scrollHeaderAway: useCollapsingListHeader,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMainAppBar(String subtitle) {
    return AppBar(
      toolbarHeight: 58,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        children: <Widget>[
          const _ChatDots(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Чаты',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ChatText.title(15.2),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ChatText.body(10.0),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: _ChatHeaderAction(
            label: isSearching ? 'Закрыть' : 'Поиск',
            active: isSearching,
            onTap: () {
              setState(() {
                if (_tab == _ChatTab.calls ||
                    _tab == _ChatTab.notifications) {
                  _tab = _ChatTab.privateChats;
                  _selectedChat = null;
                  _selectedChatId = null;
                  _selectedChatName = '';
                  isSearching = true;
                } else {
                  isSearching = !isSearching;
                }
                if (!isSearching) {
                  _searchController.clear();
                }
              });
              _applyFiltersAndSorting();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: _ChatHeaderAction(
            label: _tab == _ChatTab.groups ? 'Новая группа' : 'Новый чат',
            emphasized: true,
            onTap: () async {
              if (_tab == _ChatTab.groups) {
                final ok = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateGroupChatScreen(
                      userId: widget.userId,
                    ),
                  ),
                );

                if (ok == true) {
                  await _reloadCurrentTab();
                }
              } else {
                await _openNewPrivateChatSheet();
              }
            },
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: .6,
          color: _ChatStyle.line,
        ),
      ),
    );
  }

  Widget _buildDesktopMessenger({bool scrollListHeaderAway = false}) {
    final width = MediaQuery.sizeOf(context).width;
    final listWidth = width < 900
        ? math.min(330.0, math.max(285.0, width * .40))
        : width < 1280
            ? math.min(380.0, math.max(320.0, width * .34))
            : math.min(420.0, math.max(360.0, width * .30));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: listWidth,
          child: _buildMainListContent(
            compactPane: true,
            scrollHeaderAway: scrollListHeaderAway,
          ),
        ),
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: _ChatStyle.line,
        ),
        Expanded(
          child: _selectedChatId != null && _selectedChatId! > 0
              ? _buildEmbeddedChatPane(showBack: false)
              : _buildDesktopEmptyPane(),
        ),
      ],
    );
  }

  Widget _buildDesktopEmptyPane() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _ChatStyle.greenSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: _ChatStyle.green,
                size: 27,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Выберите чат',
              textAlign: TextAlign.center,
              style: _ChatText.title(15.0),
            ),
            const SizedBox(height: 6),
            Text(
              'Переписка откроется справа. На планшете список чатов '
              'остаётся слева, чтобы можно было быстро переключаться между диалогами.',
              textAlign: TextAlign.center,
              style: _ChatText.body(11.0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedChatPane({required bool showBack}) {
    final chatId = _selectedChatId;
    if (chatId == null || chatId <= 0) {
      return _buildDesktopEmptyPane();
    }

    final chat = _selectedChat;
    final title =
        _selectedChatName.trim().isEmpty ? 'Чат' : _selectedChatName.trim();
    final isPrivate = chat == null ? true : _isPrivate(chat);
    final avatarUrl = chat == null ? '' : _peerPhoto(chat);

    return Container(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          _ProfileChatHeader(
            title: title,
            subtitle: isPrivate ? 'Личный диалог' : 'Групповой чат',
            avatarUrl: avatarUrl,
            isGroup: !isPrivate,
            onBack: showBack ? _closeEmbeddedChat : null,
          ),
          const Divider(
            height: 1,
            thickness: .6,
            color: _ChatStyle.line,
          ),
          Expanded(
            child: ChatRoomScreen(
              key: ValueKey('profile-chat-$chatId'),
              chatId: chatId,
              userId: widget.userId,
              chatName: title,
              embedded: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainListContent({
    bool compactPane = false,
    bool scrollHeaderAway = false,
  }) {
    if (scrollHeaderAway &&
        (_tab == _ChatTab.privateChats || _tab == _ChatTab.groups)) {
      return _buildScrollableMainListContent(compactPane: compactPane);
    }

    return Column(
      children: <Widget>[
        if (_newsVisible)
          Padding(
            padding: EdgeInsets.fromLTRB(
              compactPane ? 8 : 10,
              8,
              compactPane ? 8 : 10,
              2,
            ),
            child: _sportotekaNewsEntry(),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            compactPane ? 8 : 10,
            _newsVisible ? 4 : 8,
            compactPane ? 8 : 10,
            2,
          ),
          child: _notificationsEntry(),
        ),
        if (_tab == _ChatTab.privateChats)
          Padding(
            padding: EdgeInsets.fromLTRB(
              compactPane ? 8 : 10,
              6,
              compactPane ? 8 : 10,
              1,
            ),
            child: _sportotekaAiEntry(),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            compactPane ? 8 : 10,
            6,
            compactPane ? 8 : 10,
            7,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _tabChip(
                  label: 'Личные',
                  selected: _tab == _ChatTab.privateChats,
                  onTap: () async {
                    if (_tab == _ChatTab.privateChats) return;
                    setState(() {
                      _tab = _ChatTab.privateChats;
                      _selectedChat = null;
                      _selectedChatId = null;
                      _selectedChatName = '';
                      isSearching = false;
                      _searchController.clear();
                    });
                    await _reloadCurrentTab();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _tabChip(
                  label: 'Группы',
                  selected: _tab == _ChatTab.groups,
                  onTap: () async {
                    if (_tab == _ChatTab.groups) return;
                    setState(() {
                      _tab = _ChatTab.groups;
                      _selectedChat = null;
                      _selectedChatId = null;
                      _selectedChatName = '';
                      isSearching = false;
                      _searchController.clear();
                    });
                    await _reloadCurrentTab();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _tabChip(
                  label: 'Звонки',
                  selected: _tab == _ChatTab.calls,
                  onTap: () {
                    if (_tab == _ChatTab.calls) return;
                    setState(() {
                      _tab = _ChatTab.calls;
                      _selectedChat = null;
                      _selectedChatId = null;
                      _selectedChatName = '';
                      isSearching = false;
                      _searchController.clear();
                      isLoading = false;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        if (isSearching &&
            (_tab == _ChatTab.privateChats || _tab == _ChatTab.groups))
          Padding(
            padding: EdgeInsets.fromLTRB(
              compactPane ? 8 : 10,
              0,
              compactPane ? 8 : 10,
              7,
            ),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: _ChatStyle.soft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: <Widget>[
                  const _ChatDots(
                    color: _ChatStyle.muted2,
                    compact: true,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: _ChatText.body(
                        11.2,
                        color: _ChatStyle.text,
                        weight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: _tab == _ChatTab.privateChats
                            ? 'Поиск диалогов'
                            : 'Поиск групп',
                        hintStyle: _ChatText.body(
                          10.8,
                          color: _ChatStyle.muted2,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _tab == _ChatTab.notifications
              ? CmrNotificationsPanel(
                  userId: widget.userId,
                  onUnreadChanged: (value) {
                    if (!mounted) return;
                    setState(() => _notificationUnread = value);
                  },
                )
              : _tab == _ChatTab.calls
                  ? CallHistoryPanel(userId: widget.userId)
                  : isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _ChatStyle.green,
                          ),
                        )
                      : _filtered.isEmpty
                          ? _emptyState()
                          : RefreshIndicator(
                              color: _ChatStyle.green,
                              onRefresh: _reloadCurrentTab,
                              child: _TelegramList(
                                children: List<Widget>.generate(
                                  _filtered.length,
                                  (i) =>
                                      _buildDismissibleCard(_filtered[i]),
                                ),
                              ),
                            ),
        ),
      ],
    );
  }

  Widget _buildScrollableMainListContent({bool compactPane = true}) {
    Widget tabsRow() {
      return Row(
        children: <Widget>[
          Expanded(
            child: _tabChip(
              label: 'Личные',
              selected: _tab == _ChatTab.privateChats,
              onTap: () async {
                if (_tab == _ChatTab.privateChats) return;
                setState(() {
                  _tab = _ChatTab.privateChats;
                  _selectedChat = null;
                  _selectedChatId = null;
                  _selectedChatName = '';
                  isSearching = false;
                  _searchController.clear();
                });
                await _reloadCurrentTab();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _tabChip(
              label: 'Группы',
              selected: _tab == _ChatTab.groups,
              onTap: () async {
                if (_tab == _ChatTab.groups) return;
                setState(() {
                  _tab = _ChatTab.groups;
                  _selectedChat = null;
                  _selectedChatId = null;
                  _selectedChatName = '';
                  isSearching = false;
                  _searchController.clear();
                });
                await _reloadCurrentTab();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _tabChip(
              label: 'Звонки',
              selected: _tab == _ChatTab.calls,
              onTap: () {
                if (_tab == _ChatTab.calls) return;
                setState(() {
                  _tab = _ChatTab.calls;
                  _selectedChat = null;
                  _selectedChatId = null;
                  _selectedChatName = '';
                  isSearching = false;
                  _searchController.clear();
                  isLoading = false;
                });
              },
            ),
          ),
        ],
      );
    }

    void toggleSidebarSearch() {
      setState(() {
        isSearching = !isSearching;
        if (!isSearching) {
          _searchController.clear();
        }
      });
      _applyFiltersAndSorting();
    }

    Future<void> createSidebarChat() async {
      if (_tab == _ChatTab.groups) {
        final ok = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateGroupChatScreen(userId: widget.userId),
          ),
        );
        if (ok == true) {
          await _reloadCurrentTab();
        }
        return;
      }
      await _openNewPrivateChatSheet();
    }

    void scrollHeaderToTop() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_chatListScrollController.hasClients) return;
        _chatListScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      });
    }

    void openNotificationsFromHeader() {
      setState(() {
        _tab = _ChatTab.notifications;
        _selectedChat = null;
        _selectedChatId = null;
        _selectedChatName = '';
        isSearching = false;
        _searchController.clear();
        isLoading = false;
      });
    }

    void openCallsFromHeader() {
      setState(() {
        _tab = _ChatTab.calls;
        _selectedChat = null;
        _selectedChatId = null;
        _selectedChatName = '';
        isSearching = false;
        _searchController.clear();
        isLoading = false;
      });
    }

    void toggleCompactSearch() {
      final opening = !isSearching;
      toggleSidebarSearch();
      if (opening) scrollHeaderToTop();
    }

    final horizontal = compactPane ? 8.0 : 10.0;

    return RefreshIndicator(
      color: _ChatStyle.green,
      onRefresh: _reloadCurrentTab,
      child: CustomScrollView(
        controller: _chatListScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: <Widget>[
          SliverPersistentHeader(
            pinned: true,
            delegate: _ChatCollapsingHeaderDelegate(
              minHeight: 48,
              maxHeight: 62,
              builder: (context, progress, overlapsContent) {
                final iconBox = 31.0 - progress * 3.0;
                final subtitleOpacity =
                    (1 - progress * 1.8).clamp(0.0, 1.0).toDouble();
                final normalActionsOpacity =
                    (1 - progress * 2.1).clamp(0.0, 1.0).toDouble();
                final compactActionsOpacity =
                    ((progress - .34) / .66).clamp(0.0, 1.0).toDouble();
                final countLabel = _tab == _ChatTab.groups
                    ? '${_filtered.length} групп'
                    : '${_filtered.length} диалогов';

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: overlapsContent || progress > .60
                            ? _ChatStyle.line
                            : Colors.transparent,
                        width: .7,
                      ),
                    ),
                    boxShadow: progress > .70
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x08000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : const <BoxShadow>[],
                  ),
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    4 - progress * 2,
                    horizontal,
                    5 - progress * 2,
                  ),
                  child: Row(
                    children: <Widget>[
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: scrollHeaderToTop,
                        child: Container(
                          width: iconBox,
                          height: iconBox,
                          decoration: BoxDecoration(
                            color: _ChatStyle.greenSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const _ChatDots(
                            color: _ChatStyle.greenDark,
                            compact: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Чаты',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _ChatText.title(14.5 - progress * .7),
                            ),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 80),
                              opacity: subtitleOpacity,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  countLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _ChatText.body(9.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 139,
                        height: 34,
                        child: Stack(
                          alignment: Alignment.centerRight,
                          children: <Widget>[
                            Opacity(
                              opacity: normalActionsOpacity,
                              child: IgnorePointer(
                                ignoring: progress > .46,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    _SidebarHeaderIcon(
                                      icon: isSearching
                                          ? Icons.close_rounded
                                          : Icons.search_rounded,
                                      tooltip: isSearching
                                          ? 'Закрыть поиск'
                                          : 'Поиск',
                                      active: isSearching,
                                      onTap: toggleSidebarSearch,
                                    ),
                                    const SizedBox(width: 5),
                                    _SidebarHeaderIcon(
                                      icon: _tab == _ChatTab.groups
                                          ? Icons.group_add_rounded
                                          : Icons.add_comment_rounded,
                                      tooltip: _tab == _ChatTab.groups
                                          ? 'Новая группа'
                                          : 'Новый чат',
                                      emphasized: true,
                                      onTap: () =>
                                          unawaited(createSidebarChat()),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: compactActionsOpacity,
                              child: IgnorePointer(
                                ignoring: progress < .48,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    _SidebarHeaderIcon(
                                      icon: Icons.notifications_none_rounded,
                                      tooltip: 'Уведомления',
                                      badge: _notificationUnread,
                                      onTap: openNotificationsFromHeader,
                                    ),
                                    const SizedBox(width: 3),
                                    _SidebarHeaderIcon(
                                      icon: Icons.call_outlined,
                                      tooltip: 'Звонки',
                                      onTap: openCallsFromHeader,
                                    ),
                                    const SizedBox(width: 3),
                                    _SidebarHeaderIcon(
                                      icon: Icons.auto_awesome_rounded,
                                      tooltip: 'SPORTOTEKA ИИ',
                                      ai: true,
                                      onTap: () =>
                                          unawaited(_openSportotekaAi()),
                                    ),
                                    const SizedBox(width: 3),
                                    _SidebarHeaderIcon(
                                      icon: isSearching
                                          ? Icons.close_rounded
                                          : Icons.search_rounded,
                                      tooltip: isSearching
                                          ? 'Закрыть поиск'
                                          : 'Поиск',
                                      active: isSearching,
                                      onTap: toggleCompactSearch,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_newsVisible)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 2),
                child: _sportotekaNewsEntry(),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                _newsVisible ? 4 : 8,
                horizontal,
                2,
              ),
              child: _notificationsEntry(),
            ),
          ),
          if (_tab == _ChatTab.privateChats)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 1),
                child: _sportotekaAiEntry(),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 7),
              child: tabsRow(),
            ),
          ),
          if (isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 7),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: _ChatStyle.soft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: <Widget>[
                      const _ChatDots(
                        color: _ChatStyle.muted2,
                        compact: true,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: _ChatText.body(
                            11.2,
                            color: _ChatStyle.text,
                            weight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: _tab == _ChatTab.privateChats
                                ? 'Поиск диалогов'
                                : 'Поиск групп',
                            hintStyle: _ChatText.body(
                              10.8,
                              color: _ChatStyle.muted2,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _ChatStyle.green,
                ),
              ),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                8,
                3,
                8,
                MediaQuery.paddingOf(context).bottom + 100,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _filtered.length - 1 ? 0 : 1,
                    ),
                    child: _buildDismissibleCard(_filtered[index]),
                  ),
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _ChatDots(
              color: _ChatStyle.muted2,
            ),
            const SizedBox(height: 12),
            Text(
              isSearching ? 'Ничего не найдено' : 'Пока пусто',
              style: _ChatText.title(12.3),
            ),
            const SizedBox(height: 4),
            Text(
              _tab == _ChatTab.groups
                  ? 'Создайте группу или вступите в открытую'
                  : 'Создайте первый личный диалог',
              style: _ChatText.body(10.0),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ===== Telegram-like tile (STRICT 2 lines) =====
  Widget _buildTelegramTile(
    Map<String, dynamic> chat,
  ) {
    final title = _chatTitle(chat);
    final peerPhoto = _peerPhoto(chat);
    final isPrivate = _isPrivate(chat);
    final isGroup = !isPrivate;
    final rightTime = _chatRightTime(chat);

    final unread = int.tryParse(
          (chat['unread_count'] ?? '0').toString(),
        ) ??
        0;

    final id = _asInt(chat['id']);
    final selected = id == _selectedChatId;
    final pinned = _pinned.contains(id);
    final deleted = _isDeletedChat(chat);
    final showWideActions = MediaQuery.sizeOf(context).width >= 600;

    final isPublic = isGroup ? _isPublicGroup(chat) : false;
    final iAmMember = isGroup ? _iAmMember(chat) : true;

    final rawLast = (chat['last_message'] ?? '').toString().trim();

    final secondLine = deleted
        ? 'Чат удалён'
        : rawLast.isNotEmpty
            ? rawLast
            : (isGroup
                ? _groupStatusLine(
                    isPublic: isPublic,
                    iAmMember: iAmMember,
                  )
                : 'Напишите первым');

    final initials = title
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    return Material(
      color: selected
          ? const Color(0xFFE2F7EA)
          : unread > 0
              ? _ChatStyle.greenSoft
              : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (deleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Этот чат удалён')),
            );
            return;
          }
          if (isGroup && isPublic && !iAmMember) {
            _showJoinDialog(chat);
            return;
          }
          _openChat(chat);
        },
        onLongPress: isPrivate && !deleted
            ? () => _showPrivateActions(chat)
            : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 8,
          ),
          child: Row(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _ChatStyle.soft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: isPrivate && peerPhoto.isNotEmpty
                        ? Image.network(
                            peerPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                initials.isEmpty ? 'П' : initials,
                                style: _ChatText.title(
                                  10.5,
                                  color: _ChatStyle.greenDark,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: isGroup
                                ? const _ChatDots(compact: true)
                                : Text(
                                    initials.isEmpty ? 'П' : initials,
                                    style: _ChatText.title(
                                      10.5,
                                      color: _ChatStyle.greenDark,
                                    ),
                                  ),
                          ),
                  ),
                  if (unread > 0)
                    const Positioned(
                      right: -2,
                      top: -2,
                      child: _ChatDot(
                        color: _ChatStyle.green,
                        size: 7,
                      ),
                    ),
                  if (pinned)
                    const Positioned(
                      right: -2,
                      bottom: -2,
                      child: _ChatDot(
                        color: _ChatStyle.amber,
                        size: 6,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.custom(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: _ChatStyle.text,
                              height: 1.18,
                            ),
                          ),
                        ),
                        if (isGroup) ...<Widget>[
                          const SizedBox(width: 7),
                          _MiniChip(
                            text: isPublic ? 'Открытая' : 'Закрытая',
                            tone: isPublic ? _ChipTone.blue : _ChipTone.orange,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      secondLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.custom(
                        size: 12.8,
                        weight: FontWeight.w400,
                        color: deleted
                            ? _ChatStyle.red
                            : rawLast.isNotEmpty
                                ? _ChatStyle.muted
                                : _ChatStyle.muted2,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    rightTime,
                    style: _ChatText.body(
                      8.9,
                      color: _ChatStyle.muted2,
                      weight: FontWeight.w500,
                    ),
                  ),
                  if (unread > 0) ...<Widget>[
                    const SizedBox(height: 5),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _ChatStyle.green,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: _ChatText.body(
                          8.4,
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (showWideActions) ...<Widget>[
                const SizedBox(width: 4),
                _wideChatActions(chat),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationsEntry() {
    final selected = _tab == _ChatTab.notifications;
    final hasUnread = _notificationUnread > 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          if (_tab == _ChatTab.notifications) return;
          setState(() {
            _tab = _ChatTab.notifications;
            _selectedChat = null;
            _selectedChatId = null;
            _selectedChatName = '';
            isSearching = false;
            _searchController.clear();
            isLoading = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: selected ? _ChatStyle.greenSoft : _ChatStyle.soft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : _ChatStyle.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 18,
                  color: _ChatStyle.greenDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Уведомления',
                      style: _ChatText.title(
                        11.8,
                        color:
                            selected ? _ChatStyle.greenDark : _ChatStyle.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasUnread
                          ? '$_notificationUnread новых событий'
                          : 'Важные события · всё прочитано',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ChatText.body(
                        9.6,
                        color: _ChatStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasUnread)
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _ChatStyle.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _notificationUnread > 99 ? '99+' : '$_notificationUnread',
                    style: AppTypography.custom(
                      size: 8.8,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: _ChatStyle.muted2,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Material(
      color: selected ? _ChatStyle.greenSoft : _ChatStyle.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _ChatDot(
                color: selected ? _ChatStyle.green : _ChatStyle.muted2,
                size: selected ? 5.5 : 4.5,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: _ChatText.body(
                  10.5,
                  color: selected ? _ChatStyle.greenDark : _ChatStyle.muted,
                  weight: FontWeight.w600,
                ),
              ),
              if (badge > 0) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  badge > 99 ? '99+' : '$badge',
                  style: _ChatText.body(
                    8.7,
                    color: selected ? _ChatStyle.greenDark : _ChatStyle.muted2,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} // ✅ _ChatScreenState

class _ProfileChatHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String avatarUrl;
  final bool isGroup;
  final VoidCallback? onBack;

  const _ProfileChatHeader({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.isGroup,
    this.onBack,
  });

  String get _initials {
    final parts = title
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'Ч';
    return parts.map((e) => e.substring(0, 1).toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white,
      child: Row(
        children: <Widget>[
          if (onBack != null) ...<Widget>[
            Material(
              color: _ChatStyle.soft,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(9),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 19,
                    color: _ChatStyle.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
          ],
          Container(
            width: 36,
            height: 36,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _ChatStyle.greenSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: isGroup
                          ? const _ChatDots(compact: true)
                          : Text(
                              _initials,
                              style: _ChatText.title(
                                10.7,
                                color: _ChatStyle.greenDark,
                              ),
                            ),
                    ),
                  )
                : Center(
                    child: isGroup
                        ? const _ChatDots(compact: true)
                        : Text(
                            _initials,
                            style: _ChatText.title(
                              10.7,
                              color: _ChatStyle.greenDark,
                            ),
                          ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ChatText.title(13.8),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ChatText.body(9.8),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: _ChatStyle.green,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatCollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget Function(BuildContext context, double progress, bool overlapsContent)
      builder;

  const _ChatCollapsingHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.builder,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => math.max(maxHeight, minHeight).toDouble();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = math.max(1.0, maxExtent - minExtent).toDouble();
    final progress = (shrinkOffset / range).clamp(0.0, 1.0).toDouble();
    return builder(context, progress, overlapsContent);
  }

  @override
  bool shouldRebuild(covariant _ChatCollapsingHeaderDelegate oldDelegate) {
    return oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight ||
        oldDelegate.builder != builder;
  }
}

class _SidebarHeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final bool emphasized;
  final bool ai;
  final int badge;

  const _SidebarHeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.emphasized = false,
    this.ai = false,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bg = emphasized || active
        ? _ChatStyle.greenSoft
        : _ChatStyle.soft;
    final fg = emphasized || active
        ? _ChatStyle.greenDark
        : _ChatStyle.muted;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ai ? null : bg,
                      gradient: ai
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xFF00A76F),
                                Color(0xFF2574E8),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: ai ? Colors.white : fg,
                    ),
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _ChatStyle.red,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: AppTypography.custom(
                          size: 7.1,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
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

class _ChatHeaderAction extends StatelessWidget {
  final String label;
  final bool active;
  final bool emphasized;
  final VoidCallback onTap;

  const _ChatHeaderAction({
    required this.label,
    required this.onTap,
    this.active = false,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized
          ? _ChatStyle.greenSoft
          : active
              ? _ChatStyle.greenSoft
              : _ChatStyle.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ChatDot(
                color: emphasized || active
                    ? _ChatStyle.green
                    : _ChatStyle.greenDark,
                size: emphasized || active ? 5.5 : 4.8,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: _ChatText.body(
                  9.5,
                  color: _ChatStyle.greenDark,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
        final last = (x['last_name'] ?? x['lastname'] ?? '').toString().trim();
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
                    child: const Center(
                        child: _ChatDots(
                            color: _ChatStyle.greenDark, compact: true)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Новый чат',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTypography.screenTitle(color: _ChatStyle.text),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Выберите пользователя для диалога',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTypography.secondary(color: _ChatStyle.muted)
                                  .copyWith(fontWeight: FontWeight.w500),
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
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 18, color: _ChatStyle.muted),
                    hintText: 'Поиск: имя, фамилия или email',
                    isDense: true,
                  ),
                  style: AppTypography.formText(color: _ChatStyle.text)
                      .copyWith(fontWeight: FontWeight.w500),
                  autofocus: true,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _ChatStyle.green))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              _error!,
                              style: AppTypography.secondaryMedium(
                                color: const Color(0xFFEF4444),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Text(
                                'Никого не нашли',
                                style: AppTypography.secondary(
                                        color: _ChatStyle.muted)
                                    .copyWith(fontWeight: FontWeight.w500),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (_, i) {
                                final u = _items[i];
                                return Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => Navigator.pop(context, u),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      child: Row(
                                        children: [
                                          _UserAvatar(
                                              photo: u.photo, title: u.title),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  u.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      AppTypography.itemTitle(
                                                              color: _ChatStyle
                                                                  .text)
                                                          .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700),
                                                ),
                                                if (u.subtitle
                                                        ?.trim()
                                                        .isNotEmpty ??
                                                    false) ...[
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    u.subtitle!,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        AppTypography.secondary(
                                                                color:
                                                                    _ChatStyle
                                                                        .muted)
                                                            .copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 18,
                                              color: _ChatStyle.muted),
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
                        fontWeight: FontWeight.w900, color: _ChatStyle.green),
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
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(
          8, 3, 8, MediaQuery.paddingOf(context).bottom + 100),
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
    final fg =
        tone == _ChipTone.blue ? _ChatStyle.green : const Color(0xFFB45309);

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
                          style: AppTypography.sectionTitle(
                            color: const Color(0xFF991B1B),
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: AppTypography.secondary(
                            color: const Color(0xFF7F1D1D),
                          ),
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
