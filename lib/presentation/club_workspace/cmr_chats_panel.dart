// lib/presentation/club_workspace/cmr_chats_panel.dart
// Inter typography aligned with Club Workspace, Teams, Roster and Trainers.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';
import 'package:sportoteka/presentation/chat_screen/chat_screen.dart';
import 'package:sportoteka/presentation/chat_screen/create_group_chat_screen.dart';
import 'package:sportoteka/presentation/chat_screen/cmr_notifications_panel.dart';
import 'package:sportoteka/presentation/chat_screen/call_history_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_club_ai_assistant_panel.dart';

enum _CmrChatMode { privateChats, groups, users }

class CmrChatsPanel extends StatefulWidget {
  final int userId;

  /// Нужен для ИИ-клуба: поиск отчетов, игроков и сессий внутри клуба.
  /// Оставлен nullable, чтобы старые вызовы CmrChatsPanel не сломались.
  final int? clubId;
  final String? clubName;
  final int? teamId;
  final String? teamName;
  final ValueChanged<int>? onUnreadChanged;

  /// Переходы из карточек ИИ: player_profile / tracker / report / calendar / match / testing / plans / attendance.
  final void Function(String target, Map<String, dynamic> payload)?
      onAiNavigate;

  /// Открытие PDF из карточки ИИ. Можно подключить url_launcher или свой PDF-viewer.
  final void Function(String url)? onAiOpenPdf;

  const CmrChatsPanel({
    super.key,
    required this.userId,
    this.clubId,
    this.clubName,
    this.teamId,
    this.teamName,
    this.onUnreadChanged,
    this.onAiNavigate,
    this.onAiOpenPdf,
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
  static const String _callsUnreadUrl = '$_apiBase/calls/unread.php';
  static const String _callsMarkSeenUrl = '$_apiBase/calls/mark_seen.php';

  final TextEditingController _search = TextEditingController();

  _CmrChatMode _mode = _CmrChatMode.privateChats;

  // ИИ клуба открываем первым: для клуба это рабочий поиск по отчетам/игрокам/сессиям.
  bool _notificationsSelected = false;
  bool _callsSelected = false;
  int _notificationsUnread = 0;
  int _callsUnread = 0;
  bool _aiSelected = false;
  bool _openingAiRoute = false;

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

    final parts =
        title.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
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
            ? (raw['data'] ??
                raw['items'] ??
                raw['chats'] ??
                raw['groups'] ??
                raw['users'] ??
                <dynamic>[])
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
      final res = await http
          .get(Uri.parse('$_privateChatsUrl?user_id=${widget.userId}'));
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
      final res =
          await http.get(Uri.parse('$_groupsFeedUrl?user_id=${widget.userId}'));
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

    unawaited(_fetchUnreadTotal());
    unawaited(_fetchCallsUnread());

    _unreadTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) {
        unawaited(_fetchUnreadTotal());
        unawaited(_fetchCallsUnread());
      },
    );
  }

  Future<void> _fetchCallsUnread() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_callsUnreadUrl?user_id=${widget.userId}',
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final decoded = _decodeJson(response.body);

      if (decoded is! Map || decoded['success'] != true) {
        return;
      }

      final unread = _asInt(decoded['unread']).clamp(0, 999).toInt();

      if (!mounted) return;

      if (_callsUnread != unread) {
        setState(() {
          _callsUnread = unread;
        });
      }
    } catch (_) {
      // Badge звонков не должен ломать экран чатов.
    }
  }

  int _sumUnreadRows(dynamic raw) {
    if (raw is! List) return 0;

    var total = 0;
    for (final entry in raw.whereType<Map>()) {
      final value = _asInt(entry['unread_count']);
      if (value > 0) total += value;
    }
    return total;
  }

  Future<int> _snapshotPrivateUnread() async {
    try {
      final res = await http
          .get(Uri.parse('$_privateChatsUrl?user_id=${widget.userId}'))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return 0;

      final data = _decodeJson(res.body);
      final rows = _asMapList(data).where(_isPrivate).toList();
      return _sumUnreadRows(rows);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _snapshotGroupUnread() async {
    try {
      final res = await http
          .get(Uri.parse('$_groupsFeedUrl?user_id=${widget.userId}'))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return 0;

      final data = _decodeJson(res.body);
      final rows = _asMapList(data).where(_iAmMember).toList();
      return _sumUnreadRows(rows);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _fetchUnreadTotal() async {
    final values = await Future.wait<int>(<Future<int>>[
      _snapshotPrivateUnread(),
      _snapshotGroupUnread(),
    ]);

    final total = (values[0] + values[1]).clamp(0, 9999).toInt();

    if (!mounted) return;

    if (_unreadTotal != total) {
      setState(() => _unreadTotal = total);
    }

    // Только реальное число из unread_count самих диалогов.
    // Старый get_unread_total.php больше не может вернуть фантомные 15.
    await PrefUtils.setUnreadChatsCount(total);
    widget.onUnreadChanged?.call(total);
  }

  void _autoSelectFirstChat() {
    if (_notificationsSelected || _callsSelected) return;
    if (_aiSelected) return;
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

      final phone =
          _clean(chat['peer_phone'] ?? chat['opponent_phone'] ?? chat['phone']);
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

    final type = _clean(
            chat['last_message_type'] ?? chat['message_type'] ?? chat['type'])
        .toLowerCase();
    final file = _clean(
      chat['last_file_url'] ??
          chat['file_url'] ??
          chat['attachment'] ??
          chat['media_url'],
    ).toLowerCase();

    if (file.isNotEmpty) {
      if (type == 'image' ||
          file.endsWith('.jpg') ||
          file.endsWith('.jpeg') ||
          file.endsWith('.png') ||
          file.endsWith('.webp')) {
        return 'Фото';
      }
      if (type == 'video' ||
          file.endsWith('.mp4') ||
          file.endsWith('.mov') ||
          file.endsWith('.avi')) {
        return 'Видео';
      }
      return 'Файл';
    }

    if (_isPrivate(chat)) return 'Нет сообщений';

    final members = _asInt(
        chat['members_count'] ?? chat['member_count'] ?? chat['members']);
    final publicText =
        _truthy(chat['is_public']) ? 'Открытая группа' : 'Закрытая группа';
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

  bool get _phoneMessengerLayout {
    final media = MediaQuery.maybeOf(context);
    final w = media?.size.width ?? 9999;
    return w < 700;
  }

  Future<void> _openAiFullscreen() async {
    if (_openingAiRoute) return;
    if (!mounted) return;
    setState(() => _openingAiRoute = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF6F8FA),
          resizeToAvoidBottomInset: true,
          body: CmrClubAiAssistantPanel(
            clubId: widget.clubId ?? 0,
            userId: widget.userId,
            teamId: widget.teamId,
            clubName: widget.clubName,
            teamName: widget.teamName,
            onNavigate: widget.onAiNavigate ?? _fallbackAiNavigate,
            onOpenPdf: widget.onAiOpenPdf,
            onBack: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _openingAiRoute = false;
      _aiSelected = false;
      _selectedChatName = '';
    });
  }

  void _selectNotifications() {
    setState(() {
      _notificationsSelected = true;
      _callsSelected = false;
      _aiSelected = false;
      _selectedChat = null;
      _selectedChatId = null;
      _selectedChatName = 'Уведомления';
    });
  }

  Future<void> _markCallsSeen() async {
    try {
      final response = await http.post(
        Uri.parse(_callsMarkSeenUrl),
        body: {
          'user_id': widget.userId.toString(),
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        await _fetchCallsUnread();
        return;
      }

      if (!mounted) return;

      if (_callsUnread != 0) {
        setState(() {
          _callsUnread = 0;
        });
      }
    } catch (_) {
      // Следующий polling восстановит значение при ошибке сети.
    }
  }

  void _selectCalls() {
    setState(() {
      _callsSelected = true;
      _callsUnread = 0;
      _notificationsSelected = false;
      _aiSelected = false;
      _selectedChat = null;
      _selectedChatId = null;
      _selectedChatName = 'Звонки';
    });

    unawaited(_markCallsSeen());
  }

  void _selectAiClub() {
    // На телефоне ИИ открываем отдельным маршрутом: нижний dock Club Workspace
    // исчезает, а поле ввода остаётся в самом низу как в обычном мессенджере.
    if (_phoneMessengerLayout) {
      _openAiFullscreen();
      return;
    }
    // На планшете/ПК оставляем ИИ справа внутри рабочей области чатов.
    setState(() {
      _notificationsSelected = false;
      _callsSelected = false;
      _aiSelected = true;
      _selectedChat = null;
      _selectedChatId = null;
      _selectedChatName = 'ИИ клуба';
    });
  }

  void _fallbackAiNavigate(String target, Map<String, dynamic> payload) {
    // Без внешнего роутера не показываем тренеру технический payload.
    // Для полноценного открытия экранов передайте onAiNavigate из ClubWorkspaceScreen.
    if (target == 'report') {
      final url =
          (payload['open_url'] ?? payload['pdf_url'] ?? '').toString().trim();
      if (url.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: url));
        _toast(
            'Отчет найден: ссылка скопирована. Подключите onAiNavigate, чтобы открывать экран отчета сразу.');
        return;
      }
      final sessionId = _asInt(payload['session_id']);
      _toast(sessionId > 0
          ? 'Отчет найден: сессия #$sessionId. Подключите переход в экран отчета.'
          : 'Отчет найден. Подключите переход в экран отчета.');
      return;
    }
    if (target == 'player_profile') {
      final playerId = _asInt(payload['player_id']);
      _toast(playerId > 0
          ? 'Игрок найден: #$playerId. Подключите переход в профиль игрока.'
          : 'Игрок найден. Подключите переход в профиль.');
      return;
    }
    _toast(
        'Результат найден. Подключите onAiNavigate, чтобы открывать нужный экран из ИИ.');
  }

  Future<void> _openChatFullscreen({
    required int chatId,
    required String title,
    Map<String, dynamic>? chat,
  }) async {
    if (chatId <= 0) return;
    final unread = _asInt(chat?['unread_count']);
    if (chat != null) chat['unread_count'] = 0;
    if (mounted) setState(() {});
    if (unread > 0) {
      _markReadServer(chatId);
      _fetchUnreadTotal();
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRoomScreen(
          chatId: chatId,
          userId: widget.userId,
          chatName: title,
          embedded: false,
        ),
      ),
    );
    if (!mounted) return;
    await _loadPrivateChats();
    await _loadGroups();
    _fetchUnreadTotal();
  }

  void _selectChat(Map<String, dynamic> chat) {
    final id = _asInt(chat['id'] ?? chat['chat_id']);
    if (id <= 0) return;
    final title = _chatTitle(chat);
    _notificationsSelected = false;
    _callsSelected = false;
    _aiSelected = false;
    if (_phoneMessengerLayout) {
      unawaited(_openChatFullscreen(chatId: id, title: title, chat: chat));
      return;
    }
    final unread = _asInt(chat['unread_count']);
    setState(() {
      _aiSelected = false;
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
          if (_phoneMessengerLayout) {
            setState(() {
              _notificationsSelected = false;
              _aiSelected = false;
              _mode = _CmrChatMode.privateChats;
            });
            unawaited(_openChatFullscreen(
              chatId: chatId,
              title: title,
              chat: {
                'id': chatId,
                'name': title,
                'is_private': 1,
                'peer_name': title,
              },
            ));
            return;
          }
          setState(() {
            _notificationsSelected = false;
            _aiSelected = false;
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
      final ok =
          res.statusCode == 200 && data is Map && data['success'] == true;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : media.width;
        final safeHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 120
                ? constraints.maxHeight
                : math.max(
                    620.0,
                    media.height - MediaQuery.paddingOf(context).vertical - 18,
                  );

        if (widget.userId <= 0) {
          return SizedBox(
            width: double.infinity,
            height: safeHeight,
            child: Container(
              decoration: _CmrChatDecor.workspaceBg(),
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: _CmrChatDecor.unifiedWindow(radius: 16),
                  child: const _CmrChatEmpty(
                    icon: Icons.forum_rounded,
                    title: 'Чаты недоступны',
                    subtitle:
                        'Не удалось определить пользователя для загрузки сообщений.',
                  ),
                ),
              ),
            ),
          );
        }

        final items = _visibleItems();
        final phone = width < 700;
        final tablet = width >= 700 && width < 1120;
        final compact = width < 920;
        final showInfoRail = width >= 1280 && _selectedChatId != null;
        final listWidth = phone
            ? width
            : tablet
                ? math.min(360.0, math.max(300.0, width * .36))
                : math.min(390.0, math.max(335.0, width * .28));

        if (phone) {
          return SizedBox(
            width: double.infinity,
            height: safeHeight,
            child: Container(
              decoration: _CmrChatDecor.workspaceBg(),
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: _CmrChatDecor.unifiedWindow(radius: 16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _buildCompact(items),
                  ),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          height: safeHeight,
          child: Container(
            decoration: _CmrChatDecor.workspaceBg(),
            padding: EdgeInsets.all(tablet ? 8 : 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tablet ? 16 : 18),
              child: Container(
                decoration:
                    _CmrChatDecor.unifiedWindow(radius: tablet ? 16 : 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                        width: listWidth,
                        child:
                            _buildLeft(items, mobile: false, compact: compact)),
                    Container(
                        width: 1, color: _CmrChatColors.line.withOpacity(.90)),
                    Expanded(child: _buildRight()),
                    if (showInfoRail) ...[
                      Container(
                          width: 1,
                          color: _CmrChatColors.line.withOpacity(.90)),
                      SizedBox(
                          width: 250,
                          child: _ChatInfoRail(
                            title: _selectedChatName.isEmpty
                                ? 'Чат'
                                : _selectedChatName,
                            subtitle: _selectedChat == null
                                ? 'Рабочая переписка'
                                : (_isPrivate(_selectedChat!)
                                    ? 'Личный диалог'
                                    : _subtitle(_selectedChat!)),
                            avatarUrl: _selectedChat == null
                                ? ''
                                : _photo(_selectedChat!),
                            initials: _initials(_selectedChatName),
                            isGroup: _selectedChat == null
                                ? false
                                : !_isPrivate(_selectedChat!),
                            unreadTotal: _unreadTotal,
                            onOpenFull: _openFullChat,
                            onRefresh: _refresh,
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompact(List<Map<String, dynamic>> items) {
    if (_notificationsSelected) {
      return _buildRight(
        showBack: true,
        key: const ValueKey('notifications-phone'),
      );
    }
    if (_callsSelected) {
      return _buildRight(
        showBack: true,
        key: const ValueKey('calls-phone'),
      );
    }
    if (_aiSelected) {
      // Если раздел «Чаты» открылся сразу с выбранным ИИ, на телефоне не
      // встраиваем его под нижний dock, а открываем полноценным экраном.
      if (!_openingAiRoute) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !_aiSelected ||
              !_phoneMessengerLayout ||
              _openingAiRoute) return;
          _openAiFullscreen();
        });
      }
      return _buildLeft(items,
          mobile: true,
          compact: true,
          key: const ValueKey('chat-list-phone-ai-bg'));
    }
    if (_selectedChatId != null) {
      return _buildRight(
        showBack: true,
        key: ValueKey('chat-room-phone-${_selectedChatId ?? 0}'),
      );
    }
    return _buildLeft(items,
        mobile: true, compact: true, key: const ValueKey('chat-list-phone'));
  }

  Widget _buildLeft(
    List<Map<String, dynamic>> items, {
    required bool mobile,
    required bool compact,
    Key? key,
  }) {
    return Container(
      key: key,
      decoration: _CmrChatDecor.seamlessPane(),
      padding: EdgeInsets.all(mobile ? 8 : (compact ? 10 : 12)),
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
          SizedBox(height: mobile ? 9 : 10),
          _NotificationsPinnedRow(
            selected: _notificationsSelected,
            unread: _notificationsUnread,
            mobile: mobile,
            onTap: _selectNotifications,
          ),
          SizedBox(height: mobile ? 6 : 7),
          _CallsPinnedRow(
            selected: _callsSelected,
            unread: _callsUnread,
            mobile: mobile,
            onTap: _selectCalls,
          ),
          SizedBox(height: mobile ? 6 : 7),
          _AiPinnedChatRow(
            selected: _aiSelected,
            mobile: mobile,
            onTap: _selectAiClub,
          ),
          SizedBox(height: mobile ? 9 : 10),
          _ChatSearch(
            controller: _search,
            hintText: _mode == _CmrChatMode.users
                ? 'Найти пользователя...'
                : 'Поиск по чатам...',
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
              if (mode == _CmrChatMode.privateChats && _privateChats.isEmpty)
                _loadPrivateChats();
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
                                subtitle: (item['email'] ??
                                        'Нажмите, чтобы начать диалог')
                                    .toString(),
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
                              onTap: () => canOpen
                                  ? _selectChat(item)
                                  : _joinGroup(item),
                              mobile: mobile,
                            );
                          },
                          separatorBuilder: (_, __) =>
                              SizedBox(height: mobile ? 6 : 7),
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

  Widget _buildRight({bool showBack = false, Key? key}) {
    if (_notificationsSelected) {
      return CmrNotificationsPanel(
        key: const ValueKey('cmr-notifications'),
        userId: widget.userId,
        onUnreadChanged: (value) {
          if (!mounted) return;
          setState(() => _notificationsUnread = value);
        },
        onNavigate: widget.onAiNavigate,
        onBack: showBack
            ? () => setState(() {
                  _notificationsSelected = false;
                  _selectedChatName = '';
                })
            : null,
      );
    }
    if (_callsSelected) {
      return Container(
        key: const ValueKey('cmr-call-history'),
        color: Colors.white,
        child: Column(
          children: [
            if (showBack)
              _EmbeddedChatHeader(
                title: 'Звонки',
                subtitle: 'История входящих и исходящих',
                avatarUrl: '',
                initials: 'З',
                isGroup: false,
                onBack: () => setState(() {
                  _callsSelected = false;
                  _selectedChatName = '';
                }),
              ),
            Expanded(
              child: CallHistoryPanel(userId: widget.userId),
            ),
          ],
        ),
      );
    }
    if (_aiSelected) {
      return CmrClubAiAssistantPanel(
        key: const ValueKey('cmr-club-ai-chat'),
        clubId: widget.clubId ?? 0,
        userId: widget.userId,
        teamId: widget.teamId,
        clubName: widget.clubName,
        teamName: widget.teamName,
        onNavigate: widget.onAiNavigate ?? _fallbackAiNavigate,
        onOpenPdf: widget.onAiOpenPdf,
        onBack: showBack
            ? () => setState(() {
                  _aiSelected = false;
                  _selectedChatName = '';
                })
            : null,
      );
    }
    final chatId = _selectedChatId;
    if (chatId == null || chatId <= 0) {
      return Container(
        key: key,
        decoration: _CmrChatDecor.seamlessPane(),
        padding: const EdgeInsets.all(18),
        child: const _CmrChatEmpty(
          icon: Icons.forum_rounded,
          title: 'Выберите чат',
          subtitle:
              'Слева выберите личный диалог, группу или пользователя. На планшете и ПК переписка откроется здесь, на телефоне — отдельным полноэкранным окном.',
        ),
      );
    }

    final chat = _selectedChat;
    final avatar = chat == null ? '' : _photo(chat);
    final subtitle = chat == null
        ? 'Рабочая переписка'
        : (_isPrivate(chat) ? _subtitle(chat) : '${_subtitle(chat)} · группа');

    return Container(
      key: key,
      decoration: _CmrChatDecor.seamlessPane(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
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

class _NotificationsPinnedRow extends StatelessWidget {
  final bool selected;
  final int unread;
  final bool mobile;
  final VoidCallback onTap;

  const _NotificationsPinnedRow({
    required this.selected,
    required this.unread,
    required this.mobile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 9 : 10,
            vertical: mobile ? 8 : 9,
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE2F7EA) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: 3,
                height: mobile ? 42 : 44,
                decoration: BoxDecoration(
                  color: selected ? _CmrChatColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: mobile ? 38 : 40,
                height: mobile ? 38 : 40,
                decoration: BoxDecoration(
                  color: _CmrChatColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: _CmrChatColors.greenDark,
                  size: 19,
                ),
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
                            'Уведомления',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrChatText.title(
                              mobile ? 13.5 : 13.8,
                            ),
                          ),
                        ),
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _CmrChatColors.graphite,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : unread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.8,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Дневник, тренировки, тесты и важные события',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrChatText.muted(
                        mobile ? 10.8 : 11.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: _CmrChatColors.greenDark,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallsPinnedRow extends StatelessWidget {
  final bool selected;
  final int unread;
  final bool mobile;
  final VoidCallback onTap;

  const _CallsPinnedRow({
    required this.selected,
    required this.unread,
    required this.mobile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 9 : 10,
            vertical: mobile ? 8 : 9,
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE2F7EA) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: 3,
                height: mobile ? 42 : 44,
                decoration: BoxDecoration(
                  color: selected ? _CmrChatColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: mobile ? 38 : 40,
                height: mobile ? 38 : 40,
                decoration: BoxDecoration(
                  color: _CmrChatColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.call_outlined,
                  color: _CmrChatColors.greenDark,
                  size: 19,
                ),
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
                            'Звонки',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrChatText.title(
                              mobile ? 13.5 : 13.8,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 20,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD92D20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unread > 99 ? '99+' : unread.toString(),
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
                    const SizedBox(height: 4),
                    Text(
                      'Входящие, исходящие и пропущенные',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrChatText.muted(mobile ? 12.8 : 12.8),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: _CmrChatColors.greenDark,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiPinnedChatRow extends StatelessWidget {
  final bool selected;
  final bool mobile;
  final VoidCallback onTap;

  const _AiPinnedChatRow(
      {required this.selected, required this.mobile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: EdgeInsets.symmetric(
              horizontal: mobile ? 9 : 10, vertical: mobile ? 8 : 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE2F7EA) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: 3,
                height: mobile ? 42 : 44,
                decoration: BoxDecoration(
                  color: selected ? _CmrChatColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: mobile ? 38 : 40,
                height: mobile ? 38 : 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_CmrChatColors.green, _CmrChatColors.blue],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 19),
              ),
              SizedBox(width: mobile ? 9 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text('ИИ клуба',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    _CmrChatText.title(mobile ? 13.5 : 13.8))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                              color: _CmrChatColors.graphite,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('beta',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.6,
                                  fontWeight: FontWeight.w600,
                                  height: 1)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Найду отчет, игрока, тренировку, PDF и аналитику',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrChatText.muted(mobile ? 12.8 : 12.8)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: _CmrChatColors.greenSoft,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _CmrChatColors.greenBorder)),
                child: const Icon(Icons.arrow_forward_rounded,
                    color: _CmrChatColors.greenDark, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatInfoRail extends StatelessWidget {
  final String title;
  final String subtitle;
  final String avatarUrl;
  final String initials;
  final bool isGroup;
  final int unreadTotal;
  final VoidCallback onOpenFull;
  final VoidCallback onRefresh;

  const _ChatInfoRail({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.initials,
    required this.isGroup,
    required this.unreadTotal,
    required this.onOpenFull,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _Avatar(
              url: avatarUrl,
              initials: initials,
              icon: isGroup ? Icons.groups_2_rounded : Icons.person_rounded,
              size: 62,
            ),
          ),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _CmrChatText.title(14.4)),
          const SizedBox(height: 5),
          Text(subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _CmrChatText.muted(11.0)),
          const SizedBox(height: 14),
          _InfoRailTile(
              icon: Icons.notifications_rounded,
              title: 'Непрочитанные',
              value: unreadTotal > 0 ? unreadTotal.toString() : 'нет'),
          const SizedBox(height: 8),
          _InfoRailTile(
              icon: isGroup ? Icons.groups_rounded : Icons.lock_outline_rounded,
              title: isGroup ? 'Тип чата' : 'Диалог',
              value: isGroup ? 'группа' : 'личный'),
          const Spacer(),
          Row(
            children: [
              Expanded(
                  child: _InfoRailButton(
                      icon: Icons.refresh_rounded,
                      text: 'Обновить',
                      onTap: onRefresh)),
              const SizedBox(width: 8),
              Expanded(
                  child: _InfoRailButton(
                      icon: Icons.open_in_new_rounded,
                      text: 'Открыть',
                      onTap: onOpenFull)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRailTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRailTile(
      {required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _CmrChatColors.soft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: _CmrChatColors.greenSoft,
              borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: _CmrChatColors.greenDark, size: 15),
        ),
        const SizedBox(width: 9),
        Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrChatText.muted(10.8))),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _CmrChatText.value(11.2)),
      ]),
    );
  }
}

class _InfoRailButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _InfoRailButton(
      {required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: _CmrChatColors.greenDark),
            const SizedBox(width: 5),
            Text(text,
                style: _CmrChatText.action(color: _CmrChatColors.text2)
                    .copyWith(fontSize: 10.8)),
          ]),
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
            color: _CmrChatColors.greenSoft,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _CmrChatColors.green.withOpacity(.07),
                blurRadius: 18,
                spreadRadius: -11,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.forum_rounded,
              color: _CmrChatColors.greenDark, size: mobile ? 18 : 19),
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
                      style: _CmrChatText.title(mobile ? 15.0 : 15.4),
                    ),
                  ),
                  if (unreadTotal > 0) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _CmrChatColors.graphite,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        unreadTotal > 99 ? '99+' : unreadTotal.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w500,
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
                style: _CmrChatText.muted(mobile ? 10.8 : 11.2),
              ),
            ],
          ),
        ),
        if (!mobile) ...[
          _CircleAction(
              icon: Icons.refresh_rounded,
              onTap: onRefresh,
              tooltip: 'Обновить'),
          const SizedBox(width: 7),
          _CircleAction(
              icon: Icons.open_in_new_rounded,
              onTap: onOpenFull,
              tooltip: 'Открыть полный экран'),
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

  const _ChatSearch(
      {required this.controller, required this.hintText, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mobile ? 38 : 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              color: _CmrChatColors.muted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                isDense: true,
              ),
              style: _CmrChatText.value(mobile ? 13.0 : 13.3),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: controller.clear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded,
                    color: _CmrChatColors.muted, size: 16),
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
      _CmrChatMode.privateChats:
          _ChatModeData('Личные', Icons.chat_bubble_rounded, privateCount),
      _CmrChatMode.groups:
          _ChatModeData('Группы', Icons.groups_2_rounded, groupsCount),
      _CmrChatMode.users:
          _ChatModeData('Люди', Icons.person_search_rounded, usersCount),
    };

    return SizedBox(
      height: mobile ? 31 : 32,
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
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 9 : 10,
            vertical: dense ? 5 : 6,
          ),
          decoration: active
              ? _CmrChatDecor.fluentSurface(
                  radius: 999,
                  accent: _CmrChatColors.green,
                  active: true,
                  compact: true,
                )
              : BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _CmrChatColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                icon,
                color: active ? _CmrChatColors.greenDark : _CmrChatColors.muted,
                size: dense ? 13 : 14,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: _CmrChatText.tab(active: active, dense: dense),
              ),
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: _CmrChatText.chip(
                  size: dense ? 10.2 : 10.8,
                  color:
                      active ? _CmrChatColors.greenDark : _CmrChatColors.muted2,
                ),
              ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            _CircleAction(
                icon: Icons.arrow_back_rounded,
                onTap: onBack!,
                tooltip: 'К списку чатов'),
            const SizedBox(width: 8),
          ],
          _Avatar(
            url: avatarUrl,
            initials: initials,
            icon: isGroup ? Icons.groups_2_rounded : Icons.person_rounded,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrChatText.title(14.4)),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrChatText.subtle(10.6)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: _CmrChatColors.green,
              shape: BoxShape.circle,
            ),
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
    final accent = _chatAccent(title.hashCode + (isGroup ? 7 : 0));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: EdgeInsets.symmetric(
              horizontal: mobile ? 8 : 9, vertical: mobile ? 7 : 7),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE2F7EA) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: 3,
                height: mobile ? 38 : 40,
                decoration: BoxDecoration(
                  color: active ? accent : Colors.transparent,
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
                    icon:
                        isGroup ? Icons.groups_2_rounded : Icons.person_rounded,
                    size: mobile ? 36 : 38,
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
                            style: _CmrChatText.title(mobile ? 13.5 : 13.8),
                          ),
                        ),
                        if (lastTime.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            lastTime,
                            maxLines: 1,
                            style: _CmrChatText.caption().copyWith(
                              color: unread > 0
                                  ? _CmrChatColors.greenDark
                                  : _CmrChatColors.muted2,
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
                      style: _CmrChatText.muted(mobile ? 12.8 : 12.8).copyWith(
                        color: canOpen
                            ? unread > 0
                                ? _CmrChatColors.text2
                                : _CmrChatColors.muted
                            : _CmrChatColors.blue,
                        fontWeight:
                            unread > 0 ? FontWeight.w500 : FontWeight.w500,
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

  const _ChatStatusBadge(
      {required this.isGroup, required this.unread, required this.active});

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    return Container(
      width: hasUnread ? 23 : 19,
      height: 19,
      decoration: BoxDecoration(
        color: hasUnread || active
            ? _CmrChatColors.graphite
            : _CmrChatColors.panel,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: hasUnread
          ? Text(
              unread > 99 ? '99+' : unread.toString(),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.85,
                fontWeight: FontWeight.w500,
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
          padding: EdgeInsets.symmetric(
              horizontal: mobile ? 8 : 9, vertical: mobile ? 7 : 7),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: 3,
                height: mobile ? 38 : 40,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(width: mobile ? 6 : 6),
              _Avatar(
                  url: avatarUrl,
                  initials: initials,
                  icon: Icons.person_rounded,
                  size: mobile ? 36 : 38),
              SizedBox(width: mobile ? 9 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrChatText.title(mobile ? 13.5 : 13.8)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrChatText.muted(mobile ? 12.8 : 12.8)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _CmrChatColors.greenSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.arrow_forward_rounded,
                    size: 16, color: _CmrChatColors.greenDark),
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
    final radius = size / 2;
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
      ),
      child: Center(
        child: initials.isNotEmpty
            ? Text(initials,
                style: _CmrChatText.title(size <= 40 ? 12.5 : 13.5)
                    .copyWith(color: _CmrChatColors.greenDark))
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
      ),
      child: Text(
        text,
        style: TextStyle(
          color: blue ? const Color(0xFF1D4ED8) : _CmrChatColors.muted,
          fontSize: 10.2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _HeaderButton(
      {required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: _CmrChatColors.green,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: _CmrChatColors.green.withOpacity(.18),
                  blurRadius: 18,
                  spreadRadius: -10,
                  offset: const Offset(0, 9)),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 7),
              Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.55)),
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
    final radius = BorderRadius.circular(10);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            width: 34,
            height: 34,
            decoration: _CmrChatDecor.fluentSurface(
              radius: 10,
              accent: emphasized ? _CmrChatColors.green : _CmrChatColors.blue,
              active: emphasized,
              compact: true,
            ),
            child: Icon(
              icon,
              color:
                  emphasized ? _CmrChatColors.greenDark : _CmrChatColors.blue,
              size: 16,
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
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: _CmrChatColors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _CmrChatText.muted(11).copyWith(
                  color: const Color(0xFF9A3412), fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
              onPressed: onRefresh,
              child: Text('Повторить',
                  style: _CmrChatText.action(color: _CmrChatColors.orange))),
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
                ),
                child: Icon(icon, color: _CmrChatColors.green, size: 25),
              ),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center, style: _CmrChatText.title(16)),
              const SizedBox(height: 7),
              Text(subtitle,
                  textAlign: TextAlign.center, style: _CmrChatText.muted(12)),
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: 14),
                _HeaderButton(
                    icon: Icons.add_rounded,
                    text: actionText!,
                    onTap: onAction!),
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
  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required Color color,
    double height = 1.20,
    double letterSpacing = 0,
    List<FontFeature>? features,
  }) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      features: features,
    );
  }

  static TextStyle title(double size) => _base(
        size: size,
        weight: FontWeight.w600,
        color: _CmrChatColors.text,
        height: 1.18,
      );

  static TextStyle value(double size) => _base(
        size: size,
        weight: FontWeight.w600,
        color: _CmrChatColors.text2,
        height: 1.16,
        features: const <FontFeature>[
          FontFeature.tabularFigures(),
        ],
      );

  static TextStyle muted(double size) => _base(
        size: size,
        weight: FontWeight.w400,
        color: _CmrChatColors.muted,
        height: 1.32,
      );

  static TextStyle subtle(double size) => _base(
        size: size,
        weight: FontWeight.w400,
        color: _CmrChatColors.muted2,
        height: 1.30,
      );

  static TextStyle chip({
    double size = 10.8,
    Color? color,
  }) =>
      _base(
        size: size,
        weight: FontWeight.w600,
        color: color ?? _CmrChatColors.text,
        height: 1.16,
      );

  static TextStyle caption() => _base(
        size: 10.8,
        weight: FontWeight.w500,
        color: _CmrChatColors.muted2,
        height: 1.18,
      );

  static TextStyle pill({Color? color}) => _base(
        size: 11.8,
        weight: FontWeight.w600,
        color: color ?? _CmrChatColors.text2,
        height: 1.10,
      );

  static TextStyle tab({
    bool active = false,
    bool dense = false,
  }) =>
      _base(
        size: dense ? 11.0 : 11.4,
        weight: active ? FontWeight.w700 : FontWeight.w500,
        color: active ? _CmrChatColors.greenDark : _CmrChatColors.muted,
        height: 1.12,
      );

  static TextStyle action({
    Color color = _CmrChatColors.text,
  }) =>
      _base(
        size: 11.8,
        weight: FontWeight.w600,
        color: color,
        height: 1.16,
      );
}

class _CmrChatColors {
  static const Color bg = Color(0xFFF6F7F6);
  static const Color panel = Colors.white;
  static const Color glass = Color(0xF7FFFFFF);
  static const Color soft = Color(0xFFFAFBFA);
  static const Color soft2 = Color(0xFFF4F6F4);

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
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanSoft = Color(0xFFEFFBFF);
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetSoft = Color(0xFFF5F0FF);
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkSoft = Color(0xFFFFF1F8);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF7ED);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color line = Color(0xFFE7EBE8);
}

Color _chatAccent(int index) => _CmrChatColors.green;

Color _chatAccentSoft(int index) => _CmrChatColors.greenSoft;

class _CmrChatDecor {
  static BoxDecoration workspaceBg() => const BoxDecoration(
        color: Color(0xFFF6F7F6),
      );

  static BoxDecoration panel({double radius = 22, bool elevated = true}) =>
      BoxDecoration(
        color: _CmrChatColors.panel,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.045),
                  blurRadius: 34,
                  spreadRadius: -14,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 10,
                  spreadRadius: -7,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      );

  static BoxDecoration softCard({double radius = 18, bool active = false}) =>
      BoxDecoration(
        color: active ? _CmrChatColors.panel : _CmrChatColors.soft,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.045),
                  blurRadius: 24,
                  spreadRadius: -12,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      );

  static BoxDecoration unifiedWindow({double radius = 18}) => BoxDecoration(
        color: _CmrChatColors.panel,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration seamlessPane({double radius = 0}) => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration fluentSurface({
    double radius = 16,
    Color accent = _CmrChatColors.blue,
    bool active = false,
    bool compact = false,
  }) {
    return BoxDecoration(
      color: active ? const Color(0xFFE2F7EA) : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  static BoxDecoration greenCard({double radius = 16}) => BoxDecoration(
        color: _CmrChatColors.green,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: _CmrChatColors.green.withOpacity(.14),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      );
}
