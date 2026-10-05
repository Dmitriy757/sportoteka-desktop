// lib/presentation/chat_screen/chat_room_screen.dart
// Windows 11 / Fluent refresh based on CMR workspace typography.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mime/mime.dart';
import 'package:record/record.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';
import 'package:sportoteka/presentation/chat_screen/edit_group_chat_screen.dart';
import 'package:sportoteka/presentation/chat_screen/channel_management_screen.dart';
import 'package:sportoteka/presentation/chat_screen/outgoing_call_screen.dart';
import 'package:sportoteka/presentation/chat_screen/chat_workspace_document_sync.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_attachment_preview.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_chat_document_window.dart';

class _WinChatColors {
  static const Color bg = Colors.white;
  static const Color panel = Colors.white;
  static const Color glass = Color(0xF7FFFFFF);
  static const Color soft = Color(0xFFF7F9F8);
  static const Color soft2 = Color(0xFFF2F5F3);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF6B7280);
  static const Color graphite = Color(0xFF111827);
  static const Color graphite2 = Color(0xFF1F2937);
  static const Color green = Color(0xFF00A750);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanSoft = Color(0xFFEFFBFF);
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetSoft = Color(0xFFF5F0FF);
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkSoft = Color(0xFFFFF1F8);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color red = Color(0xFFD92D20);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenBorder = Color(0xFFD7F0E2);
  static const Color line = Color(0xFFEDF0EE);
}

Color _messageAccent(int index) => _WinChatColors.greenDark;

Color _messageAccentSoft(int index) => _WinChatColors.soft;

class _WinChatText {
  static TextStyle title(
    double size, {
    Color color = _WinChatColors.text,
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
    Color color = _WinChatColors.text,
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

  /// Текст непосредственно внутри пузыря сообщения.
  /// Отдельный стиль нужен, чтобы размер сообщения не зависел от
  /// семантического порога `_WinChatText.body()`.
  static TextStyle messageBody({
    Color color = _WinChatColors.text,
    FontWeight weight = FontWeight.w500,
  }) =>
      AppTypography.custom(
        size: 13.5,
        weight: weight,
        color: color,
        height: 1.38,
      );

  static TextStyle caption({
    Color color = _WinChatColors.muted,
  }) =>
      AppTypography.commentMeta(color: color)
          .copyWith(fontWeight: FontWeight.w500);
}

class _RoomDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _RoomDot({
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

class _RoomDots extends StatelessWidget {
  final Color color;
  final bool compact;

  const _RoomDots({
    this.color = _WinChatColors.green,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scale = compact ? .76 : 1.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _RoomDot(
          color: color,
          size: 3.4 * scale,
          opacity: .32,
        ),
        SizedBox(width: 3 * scale),
        _RoomDot(
          color: color,
          size: 4.4 * scale,
          opacity: .55,
        ),
        SizedBox(width: 3 * scale),
        _RoomDot(
          color: color,
          size: 5.4 * scale,
          opacity: .78,
        ),
        SizedBox(width: 3 * scale),
        _RoomDot(
          color: color,
          size: 6.4 * scale,
        ),
      ],
    );
  }
}

class _WinChatDecor {
  static BoxDecoration workspaceBg() => const BoxDecoration(
        color: Color(0xFFF7F9F8),
      );

  static BoxDecoration inputBar() => const BoxDecoration(
        color: Colors.white,
      );
}

class ChatRoomScreen extends StatefulWidget {
  final int chatId;
  final int userId;
  final int clubId;
  final String chatName;
  final bool isGroup;
  final String groupAvatarUrl;

  /// Канал отличается от обычной группы: подписчики читают и реагируют,
  /// а публиковать могут только владелец и назначенные администраторы.
  final bool isChannel;
  final String channelRole;
  final int channelSubscriberCount;

  /// Данные собеседника для личного чата. Они особенно важны, когда чат
  /// открывается из Club Workspace: список чатов уже знает пользователя,
  /// а get_chat_members.php может прийти чуть позже или вернуть старый формат.
  final int peerUserId;
  final String peerAvatarUrl;

  /// Когда чат открыт внутри CMR/workspace, убираем поведение отдельного экрана.
  final bool embedded;

  const ChatRoomScreen({
    Key? key,
    required this.chatId,
    required this.userId,
    this.clubId = 0,
    required this.chatName,
    this.isGroup = false,
    this.groupAvatarUrl = '',
    this.isChannel = false,
    this.channelRole = '',
    this.channelSubscriberCount = 0,
    this.peerUserId = 0,
    this.peerAvatarUrl = '',
    this.embedded = false,
  }) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  // ✅ endpoints (ДОЛЖНЫ БЫТЬ ВНУТРИ КЛАССА, не снаружи)
  static const String _apiBase = "https://sportotekaapp.ru/api";
  static const String _markReadUrl = "$_apiBase/mark_read.php";
  static const String _readStatusUrl = "$_apiBase/get_chat_read_status.php";
  static const String _searchUsersUrl = "$_apiBase/search_users.php";
  static const String _forwardMessageUrl = "$_apiBase/forward_message.php";

  String get _sendMessageUrl => widget.isChannel
      ? "$_apiBase/channel_send_message.php"
      : "$_apiBase/send_message.php";

  String get _sendFileMessageUrl => widget.isChannel
      ? "$_apiBase/channel_send_file_message.php"
      : "$_apiBase/send_file_message.php";
  static const String _toggleReactionUrl = "$_apiBase/toggle_message_reaction.php";
  static const String _getReactionsUrl = "$_apiBase/get_message_reactions.php";

  // GIPHY: отдельные beta API keys по платформам, как требует GIPHY.
  static const String _giphyAndroidApiKey =
      'CF9fOJoYOJDrSJ6m7hmtCvSImvzoPvOh';
  static const String _giphyIosApiKey =
      '3d3Q3LA2zvItq3TZfXUcNdb3F5fnNsP2';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Offset? _lastMessagePressPosition;

  late String _chatTitle;
  late String _currentChannelRole;
  int _currentChannelSubscriberCount = 0;
  late ChatWorkspaceDocumentSync _documentSync;
  final Set<int> _queuedDocuments = <int>{};
  Future<void> _documentQueue = Future<void>.value();
  bool _clubMissingNoticeShown = false;

  // Сообщения/участники
  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> members = [];
  bool _callOpening = false;
  bool _resolvingCall = false;

  // Индексы и состояния
  bool isLoading = true;
  Timer? _refreshTimer;
  Timer? _reactionsTimer;
  Timer? _membersTimer;
  Timer? _readStatusTimer;

  // Последнее сообщение текущего пользователя, которое уже прочитал(и)
  // собеседник/остальные участники. Новый endpoint является fallback для
  // старого get_messages.php, где is_read не возвращался.
  int _peerLastReadMessageId = 0;
  bool? _readStatusSupported;

  // Реакции сгруппированы по message_id.
  final Map<int, List<Map<String, dynamic>>> _messageReactions = {};

  // Локальный fallback для цитат ответа. Нужен на случай, если старый
  // get_messages.php пока не возвращает reply_to_id/reply_* после отправки.
  // Серверные данные остаются приоритетными; кэш только не даёт цитате
  // исчезнуть при следующем poll/reload на этом устройстве.
  final Map<int, Map<String, dynamic>> _replyPreviewCache = {};

  String get _replyPreviewCacheKey =>
      'chat_reply_previews_v2_${widget.userId}_${widget.chatId}';

  bool isTyping = false;
  int? editingMessageId; // ID редактируемого сообщения
  int lastMessageId = 0;

  bool isRecording = false;
  final AudioRecorder _voiceRecorder = AudioRecorder();
  Timer? _voiceTimer;
  Duration _voiceDuration = Duration.zero;
  bool _voiceCancelArmed = false;
  bool _voicePressHeld = false;
  double? _voicePressStartX;
  double _voiceSwipeDistance = 0;

  // Во время пакетной отправки медиа не запускаем фоновые poll-запросы.
  // Это уменьшает одновременную нагрузку на nginx/php-fpm и не даёт
  // нескольким фото конфликтовать с ежесекундным обновлением чата.
  bool _mediaBatchSending = false;

  // Отдельный HTTP-клиент для вложений. Нужен, чтобы показывать реальный
  // прогресс отправки по байтам, а не бесконечный spinner.
  final http.Client _uploadClient = http.Client();

  // Ответ на сообщение
  int? replyingToId;
  Map<String, dynamic>? replyingToMessage;

  // Ключи виджетов сообщений — для скролла к quote
  final Map<int, GlobalKey> _messageKeys = {};

  // Быстрый опрос (видно обновления сразу)
  Duration pollInterval = const Duration(seconds: 1);

  // Поиск по чату
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool searchMode = false;
  String searchQuery = '';
  List<int> searchHits = []; // id сообщений-совпадений
  int currentHit = -1;

  // Для устранения "дёрганья" + подавления ошибок
  int _prevServerCount = 0;
  String _serverMessageSignature = '';
  bool _didInitialAutoScroll = false;
  bool _initialDataLoaded = false;
  int _netErrorStreak = 0;

  // ✅ Scroll-to-bottom без setState на каждый пиксель
  final ValueNotifier<bool> _showScrollToBottomVN = ValueNotifier<bool>(false);
  bool _lastShowScroll = false;
  Timer? _scrollThrottle;

  bool get _channelCanPublish =>
      !widget.isChannel ||
      const <String>{'owner', 'admin'}.contains(_currentChannelRole);

  bool get _channelCanManage =>
      widget.isChannel &&
      const <String>{'owner', 'admin'}.contains(_currentChannelRole);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    initializeDateFormatting('ru_RU');
    _chatTitle = _normalizeChatTitle(widget.chatName);
    _currentChannelRole = widget.channelRole.trim().toLowerCase();
    _currentChannelSubscriberCount = widget.channelSubscriberCount;
    _documentSync = ChatWorkspaceDocumentSync(
      clubId: widget.clubId,
      userId: widget.userId,
      chatId: widget.chatId,
      chatTitle: _chatTitle,
    );

    // ✅ ВАЖНО: помечаем чат как прочитанный на сервере при входе
    _markThisChatRead();

    unawaited(
      _restoreReplyPreviewCache().then((_) => _loadMessages(initial: true)),
    );
    _loadMembers();
    if (widget.isChannel) unawaited(_loadChannelState());
    _loadReactions();
    _startPolling();
    _startReactionPolling();
    _startMemberPolling();
    _loadPeerReadStatus();
    _startReadStatusPolling();

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;

      // throttle чтобы не дергать UI на каждый пиксель
      if (_scrollThrottle?.isActive ?? false) return;
      _scrollThrottle = Timer(const Duration(milliseconds: 70), () {
        if (!mounted || !_scrollController.hasClients) return;
        final pos = _scrollController.position;
        final next = pos.pixels < pos.maxScrollExtent - 100;
        if (next != _lastShowScroll) {
          _lastShowScroll = next;
          _showScrollToBottomVN.value = next;
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ✅ не опрашиваем сервер в фоне
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _startReactionPolling();
      _startMemberPolling();
      _loadPeerReadStatus();
      _startReadStatusPolling();
      _loadMessages(fromPoll: true);
      _loadMembers();
      if (widget.isChannel) unawaited(_loadChannelState());
      _loadReactions(silent: true);

      // ✅ на всякий случай при возврате в чат
      _markThisChatRead();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
      _reactionsTimer?.cancel();
      _membersTimer?.cancel();
      _readStatusTimer?.cancel();
    }
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(pollInterval, (_) {
      if (!mounted || _mediaBatchSending) return;
      unawaited(_loadMessages(fromPoll: true));
    });
  }

  void _startReactionPolling() {
    _reactionsTimer?.cancel();
    _reactionsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      unawaited(_loadReactions(silent: true));
    });
  }

  void _startMemberPolling() {
    _membersTimer?.cancel();
    _membersTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      // Нужен не только для аватаров/имён, но и как fallback для ✓✓,
      // если сервер хранит last_read_message_id/last_read_at у участника.
      unawaited(_loadMembers());
    });
  }

  void _startReadStatusPolling() {
    _readStatusTimer?.cancel();
    _readStatusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _readStatusSupported == false) return;
      unawaited(_loadPeerReadStatus());
    });
  }

  Future<void> _loadPeerReadStatus() async {
    if (_readStatusSupported == false) return;
    try {
      final uri = Uri.parse(_readStatusUrl).replace(queryParameters: {
        'chat_id': widget.chatId.toString(),
        'user_id': widget.userId.toString(),
      });
      final res = await http.get(uri, headers: {'Accept': 'application/json'});

      // Старый сервер может пока не иметь endpoint. В этом случае просто
      // остаются встроенные проверки is_read/read_at + данные участников.
      if (res.statusCode == 404) {
        _readStatusSupported = false;
        _readStatusTimer?.cancel();
        return;
      }
      if (res.statusCode != 200) return;

      final raw = res.body.trim();
      if (raw.isEmpty || !(raw.startsWith('{') || raw.startsWith('['))) return;
      final decoded = json.decode(raw);
      if (decoded is! Map) return;

      final readId = int.tryParse(
            '${decoded['peer_last_read_message_id'] ?? decoded['last_read_message_id'] ?? decoded['read_to_message_id'] ?? 0}',
          ) ??
          0;
      _readStatusSupported = true;
      if (!mounted || readId == _peerLastReadMessageId) return;
      setState(() => _peerLastReadMessageId = readId);
    } catch (_) {
      // Не мешаем чату работать, если старый сервер временно недоступен.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _refreshTimer?.cancel();
    _reactionsTimer?.cancel();
    _membersTimer?.cancel();
    _readStatusTimer?.cancel();
    _searchDebounce?.cancel();
    _scrollThrottle?.cancel();
    _voiceTimer?.cancel();
    if (isRecording) {
      unawaited(_voiceRecorder.cancel());
    }
    unawaited(_voiceRecorder.dispose());
    _uploadClient.close();

    _showScrollToBottomVN.dispose();

    _searchController.dispose();
    _controller.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ====================== Read marker ======================

  Future<void> _markThisChatRead() async {
    try {
      await http.post(
        Uri.parse(_markReadUrl),
        body: {
          'chat_id': widget.chatId.toString(),
          'user_id': widget.userId.toString(),
        },
      );
    } catch (_) {
      // silently ignore
    }
  }

  // ====================== Helpers ======================

  String get _giphyApiKey {
    if (Platform.isAndroid) return _giphyAndroidApiKey;
    if (Platform.isIOS) return _giphyIosApiKey;
    return '';
  }

  bool _asBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == '1' || s == 'true' || s == 'yes';
  }

  DateTime _safeParseDate(dynamic v) {
    try {
      if (v == null) return DateTime.now();
      return DateTime.parse(v.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  void _applyBackoffIfNeeded() {
    // 0..2 ошибки — 1s, дальше 2s, 3s, 5s
    final secs = _netErrorStreak <= 2
        ? 1
        : _netErrorStreak == 3
            ? 2
            : _netErrorStreak == 4
                ? 3
                : 5;

    final next = Duration(seconds: secs);
    if (pollInterval != next) {
      pollInterval = next;
      _startPolling();
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels < 150;
  }

  bool _messageIsRead(Map<String, dynamic> msg) {
    if (_asBool(msg['is_read']) ||
        _asBool(msg['read']) ||
        _asBool(msg['seen']) ||
        _asBool(msg['is_seen']) ||
        _asBool(msg['read_by_peer']) ||
        _asBool(msg['read_by_other']) ||
        _asBool(msg['peer_read'])) {
      return true;
    }

    for (final key in const [
      'read_at',
      'seen_at',
      'peer_read_at',
      'other_read_at',
    ]) {
      final value = (msg[key] ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return true;
    }

    for (final key in const [
      'read_count',
      'seen_count',
      'readers_count',
      'read_by_count',
    ]) {
      if ((int.tryParse('${msg[key] ?? 0}') ?? 0) > 0) return true;
    }

    final status = (msg['status'] ?? msg['message_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status == 'read' || status == 'seen' || status == 'viewed') {
      return true;
    }

    // Совместимость с API, которые возвращают список прочитавших.
    for (final key in const ['read_by', 'readers', 'reads', 'seen_by']) {
      final value = msg[key];
      if (value is List && value.isNotEmpty) return true;
      if (value is Map && value.isNotEmpty) return true;
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty &&
          text != '[]' &&
          text != '{}' &&
          text != '0' &&
          text.toLowerCase() != 'null') {
        return true;
      }
    }

    // Fallback для старой схемы SPORTOTEKA: если get_messages.php не отдаёт
    // is_read, но get_chat_members.php хранит позицию чтения участника.
    return _peerHasReadMessage(msg);
  }

  bool _peerHasReadMessage(Map<String, dynamic> msg) {
    final senderId = int.tryParse('${msg['sender_id'] ?? 0}') ?? 0;
    if (senderId != widget.userId) return false;

    final messageId = int.tryParse('${msg['id'] ?? 0}') ?? 0;
    if (messageId > 0 &&
        _peerLastReadMessageId > 0 &&
        messageId <= _peerLastReadMessageId) {
      return true;
    }

    final messageAt = DateTime.tryParse('${msg['created_at'] ?? ''}')?.toLocal();

    for (final member in members) {
      final memberId = _memberUserId(member);
      if (memberId <= 0 || memberId == widget.userId) continue;

      for (final key in const [
        'last_read_message_id',
        'last_read_id',
        'read_message_id',
        'last_seen_message_id',
      ]) {
        final readId = int.tryParse('${member[key] ?? 0}') ?? 0;
        if (messageId > 0 && readId >= messageId) return true;
      }

      for (final key in const [
        'last_read_at',
        'read_at',
        'last_seen_at',
      ]) {
        final raw = (member[key] ?? '').toString().trim();
        if (raw.isEmpty || raw.toLowerCase() == 'null' || messageAt == null) {
          continue;
        }
        final readAt = DateTime.tryParse(raw)?.toLocal();
        if (readAt != null && !readAt.isBefore(messageAt)) return true;
      }
    }
    return false;
  }

  Future<void> _restoreReplyPreviewCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_replyPreviewCacheKey);
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = json.decode(raw);
      if (decoded is! Map) return;

      _replyPreviewCache.clear();
      decoded.forEach((key, value) {
        final id = int.tryParse(key.toString()) ?? 0;
        if (id <= 0 || value is! Map) return;
        _replyPreviewCache[id] = Map<String, dynamic>.from(value);
      });
    } catch (e) {
      debugPrint('Не удалось восстановить локальные ответы: $e');
    }
  }

  Future<void> _persistReplyPreviewCache() async {
    try {
      // Не раздуваем SharedPreferences бесконечно. Для живого чата
      // последних нескольких сотен ответов более чем достаточно.
      while (_replyPreviewCache.length > 400) {
        _replyPreviewCache.remove(_replyPreviewCache.keys.first);
      }

      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        for (final entry in _replyPreviewCache.entries)
          entry.key.toString(): entry.value,
      };
      await prefs.setString(_replyPreviewCacheKey, json.encode(payload));
    } catch (e) {
      debugPrint('Не удалось сохранить локальные ответы: $e');
    }
  }

  void _cacheReplyPreview(int messageId, Map<String, dynamic> reply) {
    if (messageId <= 0) return;
    final replyId = int.tryParse('${reply['id'] ?? 0}') ?? 0;
    if (replyId <= 0) return;

    _replyPreviewCache[messageId] = <String, dynamic>{
      'id': replyId,
      'content': (reply['content'] ?? '').toString(),
      'type': (reply['type'] ?? 'text').toString(),
      'file_url': reply['file_url'],
      'sender_id': reply['sender_id'],
      'sender_name': (reply['sender_name'] ?? '').toString(),
    };
    unawaited(_persistReplyPreviewCache());
  }

  String _messagesSignature(List<Map<String, dynamic>> list) {
    return list.map((m) {
      final reply = m['reply'];
      final replyId = reply is Map ? reply['id'] : m['reply_to_id'];
      final replyContent = reply is Map ? reply['content'] : m['reply_content'];
      return [
        m['id'],
        m['updated_at'],
        m['is_deleted'],
        m['type'],
        m['content'],
        m['file_url'],
        m['avatar_url'],
        m['sender_photo'],
        m['photo'],
        _messageIsRead(m),
        m['read_at'],
        m['read_count'],
        m['seen_count'],
        replyId,
        replyContent,
      ].join('¦');
    }).join('§');
  }

  void _hydrateReplyPreviews(List<Map<String, dynamic>> list) {
    final byId = <int, Map<String, dynamic>>{};
    for (final item in list) {
      final id = int.tryParse('${item['id'] ?? 0}') ?? 0;
      if (id > 0) byId[id] = item;
    }

    bool cacheChanged = false;

    for (final item in list) {
      final messageId = int.tryParse('${item['id'] ?? 0}') ?? 0;
      final cached = messageId > 0 ? _replyPreviewCache[messageId] : null;
      final nestedReply = item['reply'] is Map
          ? Map<String, dynamic>.from(item['reply'])
          : item['reply_message'] is Map
              ? Map<String, dynamic>.from(item['reply_message'])
              : item['reply_to'] is Map
                  ? Map<String, dynamic>.from(item['reply_to'])
                  : <String, dynamic>{};

      final rawReplyId = item['reply_to_id'] ??
          item['reply_message_id'] ??
          item['quoted_message_id'] ??
          item['reply_to_message_id'] ??
          item['parent_message_id'] ??
          nestedReply['id'] ??
          cached?['id'];
      final replyId = int.tryParse('${rawReplyId ?? ''}');
      if (replyId == null || replyId <= 0) continue;
      item['reply_to_id'] = replyId;

      final existingMap = <String, dynamic>{};
      if (cached != null) existingMap.addAll(cached);
      existingMap.addAll(nestedReply);

      final original = byId[replyId];
      if (original != null) {
        existingMap['id'] = replyId;
        if ((existingMap['content'] ?? '').toString().isEmpty) {
          existingMap['content'] = (original['content'] ?? '').toString();
        }
        if ((existingMap['type'] ?? '').toString().isEmpty) {
          existingMap['type'] = (original['type'] ?? 'text').toString();
        }
        existingMap['file_url'] ??= original['file_url'];
        existingMap['sender_id'] ??= original['sender_id'];
        if ((existingMap['sender_name'] ?? '').toString().trim().isEmpty) {
          existingMap['sender_name'] =
              '${original['first_name'] ?? ''} ${original['last_name'] ?? ''}'
                  .trim();
        }
      } else {
        existingMap['id'] = replyId;
        if ((existingMap['content'] ?? '').toString().isEmpty) {
          existingMap['content'] = (item['reply_content'] ?? '').toString();
        }
        if ((existingMap['type'] ?? '').toString().isEmpty) {
          existingMap['type'] = (item['reply_type'] ?? 'text').toString();
        }
        existingMap['file_url'] ??= item['reply_file_url'];
        existingMap['sender_id'] ??= item['reply_sender_id'];
        if ((existingMap['sender_name'] ?? '').toString().trim().isEmpty) {
          existingMap['sender_name'] =
              '${item['reply_first_name'] ?? ''} ${item['reply_last_name'] ?? ''}'
                  .trim();
        }
      }

      item['reply'] = existingMap;
      if (messageId > 0) {
        final previous = _replyPreviewCache[messageId];
        final signature = json.encode(existingMap);
        if (previous == null || json.encode(previous) != signature) {
          _replyPreviewCache[messageId] = Map<String, dynamic>.from(existingMap);
          cacheChanged = true;
        }
      }
    }

    if (cacheChanged) unawaited(_persistReplyPreviewCache());
  }

  void _scheduleScrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollToBottom(jump: jump);

      // Медиа может изменить высоту сообщения уже после первого layout.
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollToBottom(jump: jump);
      });
    });
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (jump) {
      _scrollController.jumpTo(max);
    } else {
      _scrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToMessageId(int id) {
    final key = _messageKeys[id];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
        curve: Curves.easeOut,
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _resolveUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    raw = raw.replaceAll('\\', '/').trim();
    if (raw.toLowerCase() == 'null') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://sportotekaapp.ru${raw.startsWith('/') ? '' : '/'}$raw';
  }

  String _photoUrl(dynamic value) {
    final raw = (value ?? '').toString().replaceAll('\\', '/').trim();
    if (raw.isEmpty ||
        const {'null', 'undefined', 'false', '0'}.contains(raw.toLowerCase())) {
      return '';
    }
    if (raw.startsWith('https://') || raw.startsWith('http://')) return raw;
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    if (raw.startsWith('uploads/') || raw.startsWith('api/')) {
      return 'https://sportotekaapp.ru/$raw';
    }
    return 'https://sportotekaapp.ru/uploads/$raw';
  }

  String _firstPhoto(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final url = _photoUrl(source[key]);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  String _messagePhoto(Map<String, dynamic> msg) {
    final fromMessage = _firstPhoto(msg, const [
      'avatar_url',
      'sender_avatar_url',
      'sender_photo',
      'sender_photo_url',
      'photo_url',
      'photo',
      'avatar',
    ]);
    if (fromMessage.isNotEmpty) return fromMessage;

    final senderId = int.tryParse('${msg['sender_id'] ?? ''}');
    if (senderId == null) return '';
    return _memberPhotoForUser(senderId);
  }

  String _memberPhotoForUser(int userId) {
    for (final member in members) {
      if (_memberUserId(member) == userId) return _memberPhoto(member);
    }
    return '';
  }

  String _messageInitial(Map<String, dynamic> msg) {
    final first = (msg['first_name'] ?? '').toString().trim();
    final last = (msg['last_name'] ?? '').toString().trim();
    final name = first.isNotEmpty && first.toLowerCase() != 'null' ? first : last;
    return name.isEmpty || name.toLowerCase() == 'null'
        ? 'П'
        : name.substring(0, 1).toUpperCase();
  }

  String _mediaUrlPath(String url) {
    final value = url.trim();
    if (value.isEmpty) return '';
    final parsed = Uri.tryParse(value);
    return (parsed?.path ?? value).toLowerCase();
  }

  bool _isGifUrl(String value) {
    final low = value.trim().toLowerCase();
    if (!low.startsWith('http')) return false;
    final path = _mediaUrlPath(value);
    return path.endsWith('.gif') ||
        (low.contains('giphy.com/') && path.contains('/media/'));
  }

  bool _looksLikeImageUrl(String s) {
    final low = s.trim().toLowerCase();
    if (!low.startsWith('http')) return false;
    final path = _mediaUrlPath(s);
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        low.contains('=image') ||
        low.contains('giphy.com/');
  }

  bool _isVideoType(String type, [String url = '']) {
    final t = type.toLowerCase().trim();
    final path = _mediaUrlPath(url);
    return t == 'video' ||
        path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v') ||
        path.endsWith('.webm');
  }

  bool _isImageType(String type, [String url = '']) {
    final t = type.toLowerCase().trim();
    final path = _mediaUrlPath(url);
    return ['image', 'photo', 'picture', 'gif'].contains(t) ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
  }

  bool _isAudioType(String type, [String url = '']) {
    final t = type.toLowerCase().trim();
    final path = _mediaUrlPath(url);
    return ['audio', 'voice', 'voice_message'].contains(t) ||
        path.endsWith('.m4a') ||
        path.endsWith('.aac') ||
        path.endsWith('.mp3') ||
        path.endsWith('.wav') ||
        path.endsWith('.ogg') ||
        path.endsWith('.opus');
  }

  bool _isGifMessage(Map<String, dynamic> m) {
    final type = (m['type'] ?? '').toString().toLowerCase().trim();
    final fileUrl = (m['file_url'] ?? '').toString();
    final content = (m['content'] ?? '').toString();
    return type == 'gif' || _isGifUrl(fileUrl) || _isGifUrl(content);
  }

  String _excerptFromMsg(Map<String, dynamic> m) {
    final type = (m['type'] ?? '').toString().toLowerCase();
    final fileUrl = (m['file_url'] ?? '').toString();

    if (_isVideoType(type, fileUrl)) return '[Видео]';
    if (_isGifMessage(m)) return '[GIF]';
    if (_isImageType(type, fileUrl)) return '[Фото]';
    if (_isAudioType(type, fileUrl)) return '[Голосовое]';

    if (type == 'file' || type == 'document') return '[Файл]';

    final t = (m['content'] ?? '').toString();
    if (t.isEmpty) {
      if (fileUrl.isNotEmpty) return '[Файл]';
      return '[Сообщение]';
    }
    return t.length > 80 ? '${t.substring(0, 80)}…' : t;
  }

  List<_ChatImageItem> _collectChatImages() {
    final out = <_ChatImageItem>[];
    for (final msg in messages) {
      if (_asBool(msg['is_deleted'])) continue;

      final id = int.tryParse('${msg['id'] ?? 0}') ?? 0;
      final type = (msg['type'] ?? '').toString().toLowerCase();
      final localPath = (msg['local_path'] ?? '').toString().trim();
      final rawUrl = (msg['file_url'] ??
              msg['image_url'] ??
              msg['url'] ??
              msg['path'] ??
              '')
          .toString()
          .trim();
      final resolvedUrl = _resolveUrl(rawUrl);
      final text = (msg['content'] ?? '').toString().trim();

      if (localPath.isNotEmpty && _isImageType(type, localPath)) {
        out.add(_ChatImageItem(
          messageId: id,
          localPath: localPath,
          heroTag: 'img_$id',
        ));
        continue;
      }

      if (resolvedUrl.isNotEmpty && _isImageType(type, resolvedUrl)) {
        out.add(_ChatImageItem(
          messageId: id,
          url: resolvedUrl,
          heroTag: 'img_$id',
        ));
        continue;
      }

      if (_looksLikeImageUrl(text)) {
        out.add(_ChatImageItem(
          messageId: id,
          url: _resolveUrl(text),
          heroTag: 'img_$id',
        ));
      }
    }
    return out;
  }

  void _openImageGallery(Map<String, dynamic> msg) {
    final items = _collectChatImages();
    if (items.isEmpty) return;

    final id = int.tryParse('${msg['id'] ?? 0}') ?? 0;
    var initialIndex = items.indexWhere((item) => item.messageId == id);
    if (initialIndex < 0) initialIndex = 0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullImageGalleryScreen(
          items: items,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _loadReactions({bool silent = false}) async {
    try {
      final uri = Uri.parse(_getReactionsUrl).replace(queryParameters: {
        'chat_id': widget.chatId.toString(),
        'user_id': widget.userId.toString(),
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;

      final data = json.decode(res.body);
      if (data is! Map || data['success'] != true) return;
      final raw = (data['reactions'] as List?) ?? const [];
      final next = <int, List<Map<String, dynamic>>>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final messageId = int.tryParse('${map['message_id'] ?? 0}') ?? 0;
        if (messageId <= 0) continue;
        map['count'] = int.tryParse('${map['count'] ?? 0}') ?? 0;
        map['mine'] = _asBool(map['mine']);
        next.putIfAbsent(messageId, () => <Map<String, dynamic>>[]).add(map);
      }

      if (!mounted) return;
      setState(() {
        _messageReactions
          ..clear()
          ..addAll(next);
      });
    } catch (e) {
      if (!silent) debugPrint('Не удалось загрузить реакции: $e');
    }
  }

  Future<void> _toggleReaction(Map<String, dynamic> msg, String reaction) async {
    final messageId = int.tryParse('${msg['id'] ?? 0}') ?? 0;
    if (messageId <= 0 || msg['_local'] == true) return;

    final before = (_messageReactions[messageId] ?? const <Map<String, dynamic>>[])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // Реакция должна ощущаться мгновенной, как в обычном мессенджере.
    // Сначала меняем локально, затем подтверждаем состояние с сервера.
    final optimistic = before
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final tappedIndex = optimistic.indexWhere(
      (e) => (e['reaction'] ?? '').toString() == reaction,
    );
    final tappedWasMine = tappedIndex >= 0 && _asBool(optimistic[tappedIndex]['mine']);

    for (var i = optimistic.length - 1; i >= 0; i--) {
      if (!_asBool(optimistic[i]['mine'])) continue;
      final isTapped = (optimistic[i]['reaction'] ?? '').toString() == reaction;
      final count = int.tryParse('${optimistic[i]['count'] ?? 0}') ?? 0;
      optimistic[i]['mine'] = false;
      final nextCount = count > 0 ? count - 1 : 0;
      optimistic[i]['count'] = nextCount;
      if (nextCount <= 0) optimistic.removeAt(i);
      if (isTapped && tappedWasMine) break;
    }

    if (!tappedWasMine) {
      final target = optimistic.indexWhere(
        (e) => (e['reaction'] ?? '').toString() == reaction,
      );
      if (target >= 0) {
        optimistic[target]['count'] =
            (int.tryParse('${optimistic[target]['count'] ?? 0}') ?? 0) + 1;
        optimistic[target]['mine'] = true;
      } else {
        optimistic.add(<String, dynamic>{
          'message_id': messageId,
          'reaction': reaction,
          'count': 1,
          'mine': true,
        });
      }
    }

    if (mounted) {
      setState(() {
        if (optimistic.isEmpty) {
          _messageReactions.remove(messageId);
        } else {
          _messageReactions[messageId] = optimistic;
        }
      });
    }

    try {
      HapticFeedback.selectionClick();
      final res = await http.post(
        Uri.parse(_toggleReactionUrl),
        body: {
          'message_id': messageId.toString(),
          'user_id': widget.userId.toString(),
          'reaction': reaction,
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        if (mounted) {
          setState(() {
            if (before.isEmpty) {
              _messageReactions.remove(messageId);
            } else {
              _messageReactions[messageId] = before;
            }
          });
        }
        _showError('Не удалось поставить реакцию');
        return;
      }
      await _loadReactions(silent: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (before.isEmpty) {
            _messageReactions.remove(messageId);
          } else {
            _messageReactions[messageId] = before;
          }
        });
      }
      _showError('Не удалось поставить реакцию');
    }
  }

  Widget _buildReactionChips(
    int messageId, {
    required bool isMine,
  }) {
    final reactions = _messageReactions[messageId] ?? const [];
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Transform.translate(
      offset: Offset(isMine ? -5 : 5, -5),
      child: Wrap(
        spacing: 4,
        runSpacing: 3,
        alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
        children: reactions.map((r) {
          final reaction = (r['reaction'] ?? '').toString();
          final count = int.tryParse('${r['count'] ?? 0}') ?? 0;
          final mine = _asBool(r['mine']);
          return Material(
            color: mine ? const Color(0xFFF1FBF5) : Colors.white,
            elevation: 1.2,
            shadowColor: Colors.black.withOpacity(.12),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                final msg = messages.firstWhere(
                  (m) => int.tryParse('${m['id'] ?? 0}') == messageId,
                  orElse: () => <String, dynamic>{},
                );
                if (msg.isNotEmpty) _toggleReaction(msg, reaction);
              },
              child: Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: mine
                        ? _WinChatColors.greenBorder
                        : const Color(0xFFE4E9E6),
                    width: .8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reaction,
                      style: const TextStyle(fontSize: 14.5, height: 1),
                    ),
                    if (count > 1) ...[
                      const SizedBox(width: 3),
                      Text(
                        '$count',
                        style: _WinChatText.body(
                          10.2,
                          color: mine
                              ? _WinChatColors.greenDark
                              : _WinChatColors.muted,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _forwardMessage(Map<String, dynamic> msg) async {
    final messageId = int.tryParse('${msg['id'] ?? 0}') ?? 0;
    if (messageId <= 0 || msg['_local'] == true) return;

    final chosen = await showModalBottomSheet<_ForwardUser?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ForwardUserSheet(
        apiUrl: _searchUsersUrl,
        myUserId: widget.userId,
      ),
    );

    if (chosen == null || !mounted) return;

    try {
      final res = await http.post(
        Uri.parse(_forwardMessageUrl),
        body: {
          'message_id': messageId.toString(),
          'user_id': widget.userId.toString(),
          'target_user_id': chosen.id.toString(),
        },
      ).timeout(const Duration(seconds: 10));

      dynamic data;
      try {
        data = json.decode(res.body);
      } catch (_) {
        data = null;
      }

      final ok = res.statusCode == 200 && data is Map && data['success'] == true;
      if (!ok) {
        final reason = data is Map
            ? (data['message'] ?? data['error'] ?? 'ошибка сервера').toString()
            : 'HTTP ${res.statusCode}';
        _showError('Не удалось переслать: $reason');
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Сообщение переслано: ${chosen.title}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showError('Не удалось переслать сообщение');
    }
  }

  String _normalizeChatTitle(String raw) {
    final title = raw.trim();
    if (title.isEmpty || title.toLowerCase() == 'null') return 'Чат';
    return title;
  }

  bool _isGenericChatTitle(String raw) {
    final title = raw.trim().toLowerCase();
    return title.isEmpty ||
        title == 'чат' ||
        title == 'личный чат' ||
        title == 'групповой чат' ||
        title == 'новый чат' ||
        title == 'null';
  }

  String _memberDisplayName(Map<String, dynamic> member) {
    final name = [
      member['first_name'],
      member['last_name'],
    ]
        .where((v) => v != null && v.toString().trim().isNotEmpty)
        .map((v) => v.toString().trim())
        .join(' ')
        .trim();

    if (name.isNotEmpty) return name;

    for (final key in const [
      'name',
      'full_name',
      'username',
      'email',
      'phone'
    ]) {
      final value = (member[key] ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  String _memberPhoto(
    Map<String, dynamic> member,
  ) {
    return _firstPhoto(member, const [
      'photo',
      'photo_url',
      'avatar',
      'avatar_url',
      'user_photo',
      'user_avatar',
    ]);
  }

  String get _peerPhoto {
    if (widget.isGroup) return _photoUrl(widget.groupAvatarUrl);

    // При входе из команды/Club Workspace фото уже есть в карточке чата.
    // Используем его сразу, не дожидаясь отдельного запроса участников.
    final supplied = _photoUrl(widget.peerAvatarUrl);
    if (supplied.isNotEmpty) return supplied;

    for (final member in members) {
      final id = _memberUserId(member);
      if (id > 0 && id != widget.userId) {
        final photo = _memberPhoto(member);
        if (photo.isNotEmpty) return photo;
      }
    }
    return '';
  }

  int get _peerUserId {
    if (widget.isGroup) return 0;
    if (widget.peerUserId > 0 && widget.peerUserId != widget.userId) {
      return widget.peerUserId;
    }
    for (final member in members) {
      final id = _memberUserId(member);
      if (id > 0 && id != widget.userId) return id;
    }
    return 0;
  }

  void _openUserProfile(int userId) {
    if (userId <= 0 || userId == widget.userId || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyProfileScreen(userId: userId, publicView: true),
      ),
    );
  }

  void _openPeerProfile() => _openUserProfile(_peerUserId);

  void _refreshTitleFromMembers() {
    if (!_isGenericChatTitle(_chatTitle)) return;

    final otherMembers = members.where((member) {
      return _memberUserId(member) != widget.userId;
    }).toList();

    final names = otherMembers
        .map(_memberDisplayName)
        .where((name) => name.trim().isNotEmpty)
        .toList();

    if (names.isEmpty) return;

    final nextTitle = names.length == 1
        ? names.first
        : names.take(3).join(', ') + (names.length > 3 ? ' +' : '');

    if (nextTitle.trim().isEmpty || nextTitle == _chatTitle) return;
    if (mounted) setState(() => _chatTitle = nextTitle);
  }

  // ====================== API ======================

  Future<void> _loadMessages(
      {bool initial = false, bool fromPoll = false}) async {
    if (fromPoll && _mediaBatchSending) return;
    try {
      final uri = Uri.https(
        'sportotekaapp.ru',
        '/api/get_messages.php',
        {
          'chat_id': widget.chatId.toString(),
          'user_id': widget.userId.toString(),
        },
      );

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        if (data is Map && data['error'] != null) {
          if (!fromPoll && mounted) _showError(data['error']);
          return;
        }

        if (data is List) {
          final newMessages = List<Map<String, dynamic>>.from(data);
          final wasNearBottom = _isNearBottom();

          // Приведение типов
          for (final m in newMessages) {
            final rawId = m['id'];
            if (rawId is! int) m['id'] = int.tryParse(rawId.toString()) ?? 0;

            final rawSender = m['sender_id'];
            if (rawSender is! int) {
              m['sender_id'] = int.tryParse(rawSender.toString()) ?? 0;
            }

            final rawReply = m['reply_to_id'] ??
                m['reply_message_id'] ??
                m['quoted_message_id'];
            if (rawReply != null) {
              m['reply_to_id'] = rawReply is int
                  ? rawReply
                  : int.tryParse(rawReply.toString());
            }
          }

          // Если API вернул только reply_to_id, достраиваем окно ответа
          // из уже загруженного исходного сообщения.
          _hydrateReplyPreviews(newMessages);

          final serverCount = newMessages.length;
          final newLastId =
              serverCount > 0 ? (newMessages.last['id'] as int) : 0;

          // Локальные «отправляются»
          final localPending =
              messages.where((m) => m['_local'] == true).toList();

          final nextSignature = _messagesSignature(newMessages);
          final hasServerChange = (newLastId != lastMessageId) ||
              (serverCount != _prevServerCount) ||
              (nextSignature != _serverMessageSignature);

          if (hasServerChange) {
            _indexChatDocuments(newMessages);
            if (mounted) {
              setState(() {
                messages = [...newMessages, ...localPending];
                lastMessageId = newLastId;
                _prevServerCount = serverCount;
                _serverMessageSignature = nextSignature;
              });
            }

            // ✅ как только увидели апдейт — считаем чат прочитанным
            // (убирает верхний баннер "непрочитанных" из get_unread_total.php)
            _markThisChatRead();

            if (initial && !_didInitialAutoScroll) {
              _didInitialAutoScroll = true;
              _scheduleScrollToBottom(jump: true);
            } else if (wasNearBottom) {
              // Важно проверять позицию ДО добавления нового сообщения,
              // иначе maxScrollExtent уже меняется и чат перестаёт опускаться.
              _scheduleScrollToBottom();
            }

            _initialDataLoaded = true;
            _netErrorStreak = 0;

            // ✅ вернуть быстрый poll после успеха
            if (pollInterval != const Duration(seconds: 1)) {
              pollInterval = const Duration(seconds: 1);
              _startPolling();
            }

            if (searchQuery.isNotEmpty) _rebuildHits();
          } else {
            // даже если контент не изменился — при первом заходе отметим прочитанным
            if (initial && !_initialDataLoaded) {
              _markThisChatRead();
              _initialDataLoaded = true;
            }
          }
        }
      } else {
        if (!fromPoll) {
          _showError('Ошибка загрузки сообщений (${res.statusCode})');
        } else {
          _netErrorStreak++;
          _applyBackoffIfNeeded();
        }
      }
    } on SocketException catch (e) {
      _netErrorStreak++;
      _applyBackoffIfNeeded();
      debugPrint('SocketException suppressed: $e');
    } on http.ClientException catch (e) {
      _netErrorStreak++;
      _applyBackoffIfNeeded();
      debugPrint('ClientException suppressed: $e');
    } catch (e) {
      if (!fromPoll) {
        _showError('Не удалось загрузить сообщения');
        debugPrint('Other error in _loadMessages: $e');
      } else {
        _netErrorStreak++;
        _applyBackoffIfNeeded();
        debugPrint('Suppressed error in poll: $e');
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _indexChatDocuments(List<Map<String, dynamic>> serverMessages) {
    if (!_documentSync.available) return;
    for (final message in serverMessages) {
      final type = '${message['type'] ?? ''}'.toLowerCase();
      final id = int.tryParse('${message['id'] ?? 0}') ?? 0;
      if ((type != 'file' && type != 'document') ||
          id <= 0 ||
          _asBool(message['is_deleted'])) {
        continue;
      }
      final url = _resolveUrl(
        '${message['file_url'] ?? message['url'] ?? ''}',
      );
      if (url.isEmpty || !_queuedDocuments.add(id)) continue;
      final name = _documentName(message, url);
      _documentQueue = _documentQueue.then((_) async {
        try {
          await _documentSync.sync(
            messageId: id,
            fileUrl: url,
            fileName: name,
            sentAt: _safeParseDate(message['created_at']),
            mimeType: '${message['mime_type'] ?? lookupMimeType(name) ?? ''}',
          );
        } catch (error) {
          debugPrint('Не удалось сохранить документ чата в ОС: $error');
        }
      });
    }
  }

  String _documentName(Map<String, dynamic> message, String url) {
    final value = '${message['file_name'] ?? message['filename'] ?? message['original_name'] ?? message['content'] ?? ''}'
        .trim();
    if (value.isNotEmpty && !value.startsWith('http')) return value;
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    return segments.isEmpty ? 'Документ' : Uri.decodeComponent(segments.last);
  }

  Future<void> _syncSentDocument({
    required int messageId,
    required String fileUrl,
    required String fileName,
    required String mimeType,
    required DateTime sentAt,
  }) async {
    if (!_documentSync.available || messageId <= 0 || fileUrl.isEmpty) {
      if (mounted && !_clubMissingNoticeShown) {
        _clubMissingNoticeShown = true;
        _showError('Файл отправлен в чат. Для сохранения в ОС нужен ID клуба и подтверждение файла сервером.');
      }
      return;
    }
    try {
      await _documentSync.sync(
        messageId: messageId,
        fileUrl: _resolveUrl(fileUrl),
        fileName: fileName,
        sentAt: sentAt,
        mimeType: mimeType,
      );
    } catch (error) {
      debugPrint('Чат сохранил файл, но ОС не сохранила документ: $error');
      if (mounted) {
        _showError('Файл отправлен в чат, но в Спортотека ОС пока не сохранился.');
      }
    }
  }

  Future<void> _loadChannelState() async {
    if (!widget.isChannel) return;
    try {
      final uri = Uri.parse(
        '$_apiBase/channel_manage.php?chat_id=${widget.chatId}&user_id=${widget.userId}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final decoded = json.decode(res.body);
      if (decoded is! Map || decoded['success'] != true) return;
      final channel = decoded['channel'];
      if (channel is! Map || !mounted) return;
      final role = (channel['my_role'] ?? '').toString().trim().toLowerCase();
      final count = int.tryParse('${channel['subscriber_count'] ?? 0}') ?? 0;
      if (role == _currentChannelRole && count == _currentChannelSubscriberCount) {
        return;
      }
      setState(() {
        _currentChannelRole = role;
        _currentChannelSubscriberCount = count;
      });
    } catch (_) {
      // Старый сервер без channel API не должен ломать сам чат.
    }
  }

  Future<void> _openChannelManagement() async {
    if (!widget.isChannel || !mounted) return;
    final leftOrDeleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ChannelManagementScreen(
          chatId: widget.chatId,
          currentUserId: widget.userId,
        ),
      ),
    );
    if (!mounted) return;
    if (leftOrDeleted == true) {
      if (widget.embedded) {
        setState(() {
          _currentChannelRole = '';
          _currentChannelSubscriberCount = 0;
          messages = <Map<String, dynamic>>[];
        });
        _showError('Канал покинут. Вернитесь к списку чатов.');
      } else {
        Navigator.maybePop(context, true);
      }
      return;
    }
    await _loadChannelState();
    await _loadMembers();
  }

  Widget _buildChannelReadOnlyBar() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: _WinChatColors.line, width: .6),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _WinChatColors.greenSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                size: 18,
                color: _WinChatColors.greenDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Канал только для чтения',
                    style: _WinChatText.body(
                      11.5,
                      color: _WinChatColors.text,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Публиковать могут владелец и администраторы',
                    style: _WinChatText.body(10.2),
                  ),
                ],
              ),
            ),
            _RoomHeaderIcon(
              tooltip: 'О канале',
              icon: Icons.info_outline_rounded,
              onTap: _openChannelManagement,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMembers() async {
    try {
      final uri = Uri.parse(
          'https://sportotekaapp.ru/api/get_chat_members.php?chat_id=${widget.chatId}');
      final res = await http.get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = res.body.trimLeft();
        final decoded = json
            .decode(body.startsWith('{') || body.startsWith('[') ? body : '[]');

        final list = decoded is List
            ? decoded
            : (decoded is Map
                ? (decoded['members'] ?? decoded['data'] ?? [])
                : []);

        if (!mounted) return;
        setState(() {
          members = List<Map<String, dynamic>>.from(
            list.map((e) => Map<String, dynamic>.from(e)),
          );
        });
        _refreshTitleFromMembers();
      } else {
        debugPrint('get_chat_members HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('Ошибка загрузки участников: $e');
    }
  }

  // ====================== ОПТИМИСТИЧЕСКИЕ ХЕЛПЕРЫ ======================

  int _addOptimisticText(String text) {
    final tempId = -DateTime.now().microsecondsSinceEpoch;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    Map<String, dynamic>? replyObj;
    if (replyingToMessage != null) {
      replyObj = {
        'id': replyingToMessage!['id'],
        'content': (replyingToMessage!['content'] ?? '').toString(),
        'type': (replyingToMessage!['type'] ?? '').toString(),
        'file_url': replyingToMessage!['file_url'],
        'sender_id': replyingToMessage!['sender_id'],
        'sender_name':
            '${replyingToMessage!['first_name'] ?? ''} ${replyingToMessage!['last_name'] ?? ''}'
                .trim(),
      };
    }

    final optimistic = {
      'id': tempId,
      'chat_id': widget.chatId,
      'sender_id': widget.userId,
      'first_name': null,
      'last_name': null,
      'avatar_url': null,
      'content': text,
      'created_at': nowIso,
      'type': 'text',
      'file_url': null,
      'is_deleted': 0,
      'updated_at': null,
      'reply_to_id': replyingToId,
      if (replyObj != null) 'reply': replyObj,
      '_local': true,
      'is_read': 0,
      '_status': 'sending',
    };

    setState(() {
      messages.add(optimistic);
    });
    _scheduleScrollToBottom();
    return tempId;
  }

  int _addOptimisticMedia(
    String localPath, {
    required String type,
  }) {
    final tempId = -DateTime.now().microsecondsSinceEpoch;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    Map<String, dynamic>? replyObj;
    if (replyingToMessage != null) {
      replyObj = {
        'id': replyingToMessage!['id'],
        'content': (replyingToMessage!['content'] ?? '').toString(),
        'type': (replyingToMessage!['type'] ?? '').toString(),
        'file_url': replyingToMessage!['file_url'],
        'sender_id': replyingToMessage!['sender_id'],
        'sender_name':
            '${replyingToMessage!['first_name'] ?? ''} ${replyingToMessage!['last_name'] ?? ''}'
                .trim(),
      };
    }

    final optimistic = {
      'id': tempId,
      'chat_id': widget.chatId,
      'sender_id': widget.userId,
      'first_name': null,
      'last_name': null,
      'avatar_url': null,
      'content': type == 'file'
          ? localPath.split(Platform.pathSeparator).last
          : '',
      'file_name': localPath.split(Platform.pathSeparator).last,
      'created_at': nowIso,
      'type': type,
      'file_url': null,
      'local_path': localPath,
      'is_deleted': 0,
      'updated_at': null,
      'reply_to_id': replyingToId,
      if (replyObj != null) 'reply': replyObj,
      '_local': true,
      'is_read': 0,
      '_status': 'sending',
      '_upload_progress': 0.0,
      '_upload_error': null,
    };

    setState(() {
      messages.add(optimistic);
    });
    _scheduleScrollToBottom();
    return tempId;
  }

  void _updateUploadState(
    int tempId, {
    double? progress,
    String? status,
    String? error,
  }) {
    if (!mounted) return;
    final idx = messages.indexWhere((m) => m['id'] == tempId);
    if (idx < 0) return;

    final updated = Map<String, dynamic>.from(messages[idx]);
    if (progress != null) {
      updated['_upload_progress'] = progress.clamp(0.0, 1.0);
    }
    if (status != null) updated['_status'] = status;
    updated['_upload_error'] = error;

    setState(() => messages[idx] = updated);
  }

  Future<void> _retryMediaMessage(Map<String, dynamic> msg) async {
    final tempId = int.tryParse('${msg['id'] ?? ''}') ?? 0;
    final localPath = (msg['local_path'] ?? '').toString();
    final type = (msg['type'] ?? 'file').toString();
    if (tempId >= 0 || localPath.isEmpty) return;

    final file = File(localPath);
    if (!await file.exists()) {
      _updateUploadState(
        tempId,
        status: 'failed',
        error: 'Локальный файл больше недоступен',
      );
      return;
    }

    await _sendMedia(
      file,
      type: type,
      existingTempId: tempId,
    );
  }

  int _addOptimisticGif(_GiphyGif gif) {
    final tempId = -DateTime.now().microsecondsSinceEpoch;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    Map<String, dynamic>? replyObj;
    if (replyingToMessage != null) {
      replyObj = {
        'id': replyingToMessage!['id'],
        'content': (replyingToMessage!['content'] ?? '').toString(),
        'type': (replyingToMessage!['type'] ?? '').toString(),
        'file_url': replyingToMessage!['file_url'],
        'sender_id': replyingToMessage!['sender_id'],
        'sender_name':
            '${replyingToMessage!['first_name'] ?? ''} ${replyingToMessage!['last_name'] ?? ''}'
                .trim(),
      };
    }

    final optimistic = <String, dynamic>{
      'id': tempId,
      'chat_id': widget.chatId,
      'sender_id': widget.userId,
      'first_name': null,
      'last_name': null,
      'avatar_url': null,
      'content': gif.url,
      'created_at': nowIso,
      'type': 'gif',
      'file_url': gif.url,
      'gif_id': gif.id,
      'gif_preview_url': gif.previewUrl,
      'is_deleted': 0,
      'updated_at': null,
      'reply_to_id': replyingToId,
      if (replyObj != null) 'reply': replyObj,
      '_local': true,
      'is_read': 0,
      '_status': 'sending',
    };

    setState(() => messages.add(optimistic));
    _scheduleScrollToBottom();
    return tempId;
  }

  void _replaceTempWithServer(int tempId,
      {required int newId, String? fileUrl}) {
    if (!mounted) return;
    final idx = messages.indexWhere((m) => m['id'] == tempId);
    if (idx == -1) return;

    final updated = Map<String, dynamic>.from(messages[idx]);
    updated['id'] = newId;
    if (updated['reply'] is Map) {
      _cacheReplyPreview(
        newId,
        Map<String, dynamic>.from(updated['reply']),
      );
    }
    updated['_local'] = null;
    updated['_status'] = null;
    if (fileUrl != null) {
      updated['file_url'] = fileUrl;
      updated.remove('local_path');
    }

    setState(() {
      messages[idx] = updated;
    });
    _scheduleScrollToBottom();
  }

  void _removeTemp(int tempId) {
    if (!mounted) return;
    setState(() {
      messages.removeWhere((m) => m['id'] == tempId);
    });
  }

  // ====================== ОТПРАВКА СООБЩЕНИЙ ======================

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      if (editingMessageId != null) {
        // Редактирование
        final res = await http.post(
          Uri.parse('https://sportotekaapp.ru/api/update_message.php'),
          body: {
            'message_id': editingMessageId.toString(),
            'new_content': text,
            'user_id': widget.userId.toString(),
          },
        );
        if (res.statusCode == 200) {
          _controller.clear();
          setState(() {
            editingMessageId = null;
            isTyping = false;
          });
          await _loadMessages();
          _scrollToBottom();
          _markThisChatRead();
        } else {
          _showError('Не удалось обновить сообщение (${res.statusCode})');
        }
      } else {
        // Оптимистически добавим сообщение
        final tempId = _addOptimisticText(text);

        // Отправляем на сервер
        final body = {
          'chat_id': widget.chatId.toString(),
          'user_id': widget.userId.toString(),
          'content': text,
          'type': 'text',
          if (replyingToId != null) 'reply_to_id': replyingToId.toString(),
        };

        _controller.clear();
        setState(() {
          isTyping = false;
          replyingToId = null;
          replyingToMessage = null;
        });

        final res = await http.post(
          Uri.parse(_sendMessageUrl),
          body: body,
        );

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final newId = (data is Map)
              ? int.tryParse('${data['message_id'] ?? ''}')
              : null;
          if (newId != null) {
            _replaceTempWithServer(tempId, newId: newId);
            _loadMessages();
          } else {
            _loadMessages();
          }
          _markThisChatRead();
        } else {
          _removeTemp(tempId);
          _showError('Не удалось отправить сообщение (${res.statusCode})');
        }
      }
    } catch (e) {
      _showError('Ошибка отправки: $e');
    }
  }

  Future<void> _openGifPicker() async {
    final apiKey = _giphyApiKey;
    if (apiKey.isEmpty) {
      _showError(
        Platform.isMacOS
            ? 'Для GIF на macOS нужен отдельный GIPHY API key'
            : 'Для этой платформы пока не настроен GIPHY API key',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _GiphyPickerSheet(
        apiKey: apiKey,
        onSelected: (gif) {
          Navigator.of(sheetContext).pop();
          unawaited(_sendGif(gif));
        },
      ),
    );
  }

  Future<void> _sendGif(_GiphyGif gif) async {
    final replyId = replyingToId;
    final tempId = _addOptimisticGif(gif);

    if (mounted) {
      setState(() {
        replyingToId = null;
        replyingToMessage = null;
      });
    }

    try {
      final res = await http.post(
        Uri.parse(_sendMessageUrl),
        body: <String, String>{
          'chat_id': widget.chatId.toString(),
          'user_id': widget.userId.toString(),
          // На сервер отправляем как image для совместимости со старой схемой БД.
          // Сам клиент распознаёт GIPHY URL и показывает его именно как GIF.
          'type': 'image',
          'content': gif.url,
          if (replyId != null) 'reply_to_id': replyId.toString(),
        },
      );

      if (res.statusCode != 200) {
        _removeTemp(tempId);
        _showError('Не удалось отправить GIF (${res.statusCode})');
        return;
      }

      dynamic decoded;
      try {
        decoded = json.decode(res.body);
      } catch (_) {
        decoded = null;
      }
      final newId = decoded is Map
          ? int.tryParse(
              '${decoded['message_id'] ?? decoded['id'] ?? ''}',
            )
          : null;

      if (newId != null && newId > 0) {
        _replaceTempWithServer(tempId, newId: newId, fileUrl: gif.url);
      } else {
        _removeTemp(tempId);
      }
      await _loadMessages();
      unawaited(_markThisChatRead());
    } catch (e) {
      _removeTemp(tempId);
      _showError('Ошибка отправки GIF: $e');
    }
  }

  void _insertEmoji(String emoji) {
    final value = _controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final nextText = value.text.replaceRange(start, end, emoji);
    final caret = start + emoji.length;

    _controller.value = value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
    if (!isTyping) setState(() => isTyping = true);
    _inputFocus.requestFocus();
  }

  Future<void> _openReactionPicker(Map<String, dynamic> msg) async {
    const reactions = <String>[
      '❤️', '👍', '👎', '😂', '🤣', '😊', '😍', '🥰',
      '😮', '😢', '😭', '😡', '👏', '🙏', '🔥', '🎉',
      '💪', '🤝', '⚽', '✅', '💯', '🙌', '👌', '👀',
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.add_reaction_outlined,
                      size: 20,
                      color: _WinChatColors.greenDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Реакция на сообщение',
                        style: _WinChatText.title(14),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: reactions.map((reaction) {
                    return Material(
                      color: _WinChatColors.soft,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _toggleReaction(msg, reaction);
                        },
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Text(
                              reaction,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEmojiPicker() async {
    const emoji = <String>[
      '😀', '😃', '😄', '😁', '😊', '🙂', '😉', '😍',
      '🥰', '😎', '🤩', '😂', '🤣', '😅', '🥲', '😢',
      '😭', '😔', '🤔', '😮', '😳', '😡', '🙏', '👏',
      '👍', '👎', '❤️', '🔥', '⚽', '🎉', '💪', '🤝',
      '✅', '💯', '🙌', '👌', '👀', '🤗', '😴', '🥳',
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Смайлики',
                        style: _WinChatText.title(14),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: emoji.map((item) {
                    return Material(
                      color: _WinChatColors.soft,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _insertEmoji(item),
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: Center(
                            child: Text(
                              item,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAttachmentMenu() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: _WinChatColors.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  _AttachmentAction(
                    icon: Icons.image_outlined,
                    title: 'Фото из галереи',
                    subtitle: 'Выбрать изображение',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickImage();
                    },
                  ),
                  const SizedBox(height: 5),
                  _AttachmentAction(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Видео из галереи',
                    subtitle: 'MP4, MOV, M4V или WebM',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickVideo();
                    },
                  ),
                  const SizedBox(height: 5),
                  _AttachmentAction(
                    icon: Icons.insert_drive_file_outlined,
                    title: 'Файлы',
                    subtitle: 'Выбрать несколько файлов · до 250 МБ каждый',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickFile();
                    },
                  ),
                  if (Platform.isIOS || Platform.isAndroid) ...[
                    const SizedBox(height: 5),
                    _AttachmentAction(
                      icon: Icons.photo_camera_outlined,
                      title: 'Снять фото',
                      subtitle: 'Снять фото · проверить перед отправкой',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _capturePhoto();
                      },
                    ),
                    const SizedBox(height: 5),
                    _AttachmentAction(
                      icon: Icons.videocam_outlined,
                      title: 'Снять видео',
                      subtitle: 'Записать короткое видео и сразу отправить',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _captureVideo();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    try {
      final files = <File>[];

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final result = await FilePicker.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        if (result != null) {
          for (final item in result.files) {
            final path = item.path;
            if (path != null && path.isNotEmpty) files.add(File(path));
          }
        }
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickMultiImage(
          imageQuality: 86,
          maxWidth: 2400,
        );
        files.addAll(picked.map((item) => File(item.path)));
      }

      if (files.isEmpty) return;
      await _previewAndSendPhotos(files);
    } catch (e) {
      _showError('Не удалось выбрать изображения: $e');
    }
  }

  Future<void> _previewAndSendPhotos(List<File> initialFiles) async {
    if (!mounted || initialFiles.isEmpty) return;

    final selected = await Navigator.of(context).push<List<File>>(
      MaterialPageRoute<List<File>>(
        fullscreenDialog: true,
        builder: (_) => _ChatPhotoSendPreview(
          initialFiles: initialFiles,
          allowCamera: Platform.isIOS || Platform.isAndroid,
        ),
      ),
    );

    if (!mounted || selected == null || selected.isEmpty) return;

    var sent = 0;
    if (mounted) setState(() => _mediaBatchSending = true);
    try {
      for (var i = 0; i < selected.length; i++) {
        if (!mounted) break;
        final ok = await _sendMedia(
          selected[i],
          type: 'image',
          refreshAfterSend: false,
          clearReplyAfterSend: false,
        );
        if (ok) sent++;

        // Небольшой разрыв между multipart-загрузками помогает nginx/php-fpm
        // корректно завершить предыдущий запрос перед следующим файлом.
        if (i < selected.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 280));
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _mediaBatchSending = false;
          if (sent > 0) {
            replyingToId = null;
            replyingToMessage = null;
          }
        });
        await _loadMessages();
      }
    }

    if (mounted && selected.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Отправлено фото: $sent из ${selected.length}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      File? file;

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final result = await FilePicker.pickFiles(
          type: FileType.video,
          allowMultiple: false,
        );
        final path = result?.files.single.path;
        if (path != null && path.isNotEmpty) {
          file = File(path);
        }
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickVideo(
          source: ImageSource.gallery,
        );
        if (picked != null) {
          file = File(picked.path);
        }
      }

      if (file == null) return;
      await _sendVideo(file);
    } catch (e) {
      _showError('Не удалось выбрать видео: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result == null) return;
      var sent = 0;
      if (mounted) setState(() => _mediaBatchSending = true);
      try {
        for (var i = 0; i < result.files.length; i++) {
          if (!mounted) break;
          final selected = result.files[i];
          final path = selected.path;
          if (path == null || path.isEmpty) {
            _showError('Не удалось получить файл «${selected.name}»');
            continue;
          }
          final extension = selected.name.split('.').last.toLowerCase();
          final type = const <String>{'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'}
                  .contains(extension)
              ? 'image'
              : const <String>{'mp4', 'mov', 'm4v', 'webm'}
                      .contains(extension)
                  ? 'video'
                  : 'file';
          final ok = await _sendMedia(
            File(path),
            type: type,
            refreshAfterSend: false,
            clearReplyAfterSend: false,
          );
          if (ok) sent++;
          if (i < result.files.length - 1) {
            await Future<void>.delayed(const Duration(milliseconds: 280));
          }
        }
      } finally {
        if (mounted) {
          setState(() {
            _mediaBatchSending = false;
            if (sent > 0) {
              replyingToId = null;
              replyingToMessage = null;
            }
          });
          await _loadMessages();
        }
      }
      if (mounted && result.files.length > 1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Отправлено файлов: $sent из ${result.files.length}'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      _showError('Не удалось выбрать файл: $e');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 2400,
      );
      if (picked == null) return;
      await _previewAndSendPhotos(<File>[File(picked.path)]);
    } catch (e) {
      _showError('Не удалось сделать фото: $e');
    }
  }

  Future<void> _captureVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked == null) return;
      await _sendVideo(File(picked.path));
    } catch (e) {
      _showError('Не удалось записать видео: $e');
    }
  }

  Future<void> _sendImage(File file) async {
    await _sendMedia(file, type: 'image');
  }

  Future<void> _sendVideo(File file) async {
    await _sendMedia(file, type: 'video');
  }

  MediaType _mediaTypeForFile(File file, String type) {
    final guessed = lookupMimeType(file.path);

    if (guessed != null && guessed.contains('/')) {
      final parts = guessed.split('/');
      return MediaType(parts.first, parts.last);
    }

    final low = file.path.toLowerCase();

    if (type == 'video') {
      if (low.endsWith('.mov')) return MediaType('video', 'quicktime');
      if (low.endsWith('.webm')) return MediaType('video', 'webm');
      if (low.endsWith('.m4v')) return MediaType('video', 'mp4');
      return MediaType('video', 'mp4');
    }

    if (type == 'audio') {
      if (low.endsWith('.mp3')) return MediaType('audio', 'mpeg');
      if (low.endsWith('.wav')) return MediaType('audio', 'wav');
      if (low.endsWith('.ogg') || low.endsWith('.opus')) {
        return MediaType('audio', 'ogg');
      }
      return MediaType('audio', 'mp4');
    }

    if (type == 'file') return MediaType('application', 'octet-stream');

    return MediaType('image', 'jpeg');
  }

  Future<bool> _sendMedia(
    File file, {
    required String type,
    bool refreshAfterSend = true,
    bool clearReplyAfterSend = true,
    int? existingTempId,
  }) async {
    int? tempId;

    try {
      final sizeBytes = await file.length();
      const maxBytes = 250 * 1024 * 1024;
      if (sizeBytes <= 0) {
        _showError('Файл пустой и не может быть отправлен');
        return false;
      }
      if (sizeBytes > maxBytes) {
        _showError(
            'Файл слишком большой. Максимум ${maxBytes ~/ (1024 * 1024)} МБ');
        return false;
      }
      if (!mounted) return false;
      final pendingId = existingTempId ?? _addOptimisticMedia(file.path, type: type);
      tempId = pendingId;
      _updateUploadState(
        pendingId,
        progress: 0.0,
        status: 'sending',
        error: null,
      );

      final uri =
          Uri.parse(_sendFileMessageUrl);

      final contentType = _mediaTypeForFile(file, type);

      final req = http.MultipartRequest('POST', uri)
        // Не держим upload-соединение живым между файлами пачки. На некоторых
        // nginx/php-fpm конфигурациях это устраняет premature connection close.
        ..headers['Connection'] = 'close'
        ..fields['chat_id'] = widget.chatId.toString()
        ..fields['sender_id'] = widget.userId.toString()
        ..fields['user_id'] = widget.userId.toString()
        ..fields['type'] = type;

      if (type == 'file') {
        req.fields['content'] = file.path.split(Platform.pathSeparator).last;
      }

      if (replyingToId != null) {
        req.fields['reply_to_id'] = replyingToId.toString();
      }

      req.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.path.split(Platform.pathSeparator).last,
          contentType: contentType,
        ),
      );

      // MultipartRequest сам по себе не сообщает прогресс загрузки.
      // Финализируем multipart и прокачиваем его в StreamedRequest вручную,
      // считая реально переданные байты.
      final multipartStream = req.finalize();
      final totalBytes = req.contentLength;
      final outgoing = http.StreamedRequest('POST', uri)
        ..headers.addAll(req.headers)
        ..contentLength = totalBytes;

      var sentBytes = 0;
      var lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      final pump = outgoing.sink.addStream(
        multipartStream.transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (chunk, sink) {
              sentBytes += chunk.length;
              final now = DateTime.now();
              if (totalBytes > 0 &&
                  (now.difference(lastUiUpdate).inMilliseconds >= 90 ||
                      sentBytes >= totalBytes)) {
                lastUiUpdate = now;
                _updateUploadState(
                  pendingId,
                  progress: sentBytes / totalBytes,
                  status: 'sending',
                );
              }
              sink.add(chunk);
            },
          ),
        ),
      );

      final responseFuture = _uploadClient.send(outgoing);
      await pump.timeout(
        type == 'video'
            ? const Duration(minutes: 10)
            : const Duration(minutes: 3),
      );
      await outgoing.sink.close();

      final streamed = await responseFuture.timeout(
        type == 'video'
            ? const Duration(minutes: 10)
            : const Duration(minutes: 3),
      );
      final res = await http.Response.fromStream(streamed).timeout(
        const Duration(minutes: 2),
      );

      if (res.statusCode != 200) {
        _updateUploadState(
          pendingId,
          status: 'failed',
          error: res.statusCode == 413
              ? 'Превышен лимит загрузки'
              : 'HTTP ${res.statusCode}: ${_uploadError(res.body)}',
        );
        if (res.statusCode == 413) {
          _showError(
            'Файл не принят сервером: превышен лимит загрузки (HTTP 413)',
          );
        } else {
          _showError('Ошибка загрузки (HTTP ${res.statusCode}): '
              '${_uploadError(res.body)}');
        }
        return false;
      }

      dynamic decoded;
      try {
        decoded = json.decode(res.body);
      } catch (_) {
        _updateUploadState(
          pendingId,
          status: 'failed',
          error: 'Сервер вернул некорректный ответ',
        );
        _showError('Сервер вернул некорректный ответ при отправке файла');
        return false;
      }
      if (decoded is! Map) {
        _updateUploadState(
          pendingId,
          status: 'failed',
          error: 'Сервер не подтвердил отправку файла',
        );
        _showError('Сервер не подтвердил отправку файла');
        return false;
      }

      final data = Map<String, dynamic>.from(decoded);
      final nested = data['message'] is Map
          ? Map<String, dynamic>.from(data['message'])
          : data['data'] is Map
              ? Map<String, dynamic>.from(data['data'])
              : <String, dynamic>{};
      final status = '${data['status'] ?? ''}'.toLowerCase();
      final newId = int.tryParse(
          '${data['message_id'] ?? nested['message_id'] ?? nested['id'] ?? ''}');
      final fileUrl = (data['file_url'] ??
              data['url'] ??
              nested['file_url'] ??
              nested['url'])
          ?.toString();
      final rejected = data['success'] == false ||
          (data['error'] != null && data['error'].toString().trim().isNotEmpty) ||
          const {'error', 'failed', 'fail'}.contains(status);
      final accepted = !rejected &&
          (_asBool(data['success']) ||
              const {'ok', 'success', '200'}.contains(status) ||
              (newId != null && newId > 0));
      if (!accepted) {
        _updateUploadState(
          pendingId,
          status: 'failed',
          error: _uploadError(res.body),
        );
        _showError('Не удалось отправить файл: ${_uploadError(res.body)}');
        return false;
      }

      if (mounted && clearReplyAfterSend) {
        setState(() {
          replyingToId = null;
          replyingToMessage = null;
        });
      }
      if (newId != null && newId > 0) {
        _replaceTempWithServer(pendingId, newId: newId, fileUrl: fileUrl);
      } else {
        // При ответе без ID локальное сообщение не должно висеть вечно.
        _removeTemp(pendingId);
      }
      if (refreshAfterSend) {
        await _loadMessages();
      }
      if (type == 'file') {
        Map<String, dynamic>? savedMessage;
        for (final item in messages) {
          if (item['id'] == newId && item['_local'] != true) {
            savedMessage = item;
            break;
          }
        }
        unawaited(_syncSentDocument(
          messageId: newId ?? 0,
          fileUrl: fileUrl?.isNotEmpty == true
              ? fileUrl!
              : '${savedMessage?['file_url'] ?? ''}',
          fileName: file.path.split(Platform.pathSeparator).last,
          mimeType: '${data['mime'] ?? lookupMimeType(file.path) ?? ''}',
          sentAt: _safeParseDate(savedMessage?['created_at']),
        ));
      }
      unawaited(_markThisChatRead());
      return true;
    } catch (e) {
      if (tempId != null) {
        _updateUploadState(
          tempId,
          status: 'failed',
          error: e.toString(),
        );
      }
      _showError(
        type == 'video'
            ? 'Ошибка отправки видео: $e'
            : type == 'image'
                ? 'Ошибка отправки изображения: $e'
                : type == 'audio'
                    ? 'Ошибка отправки голосового сообщения: $e'
                    : 'Ошибка отправки файла: $e',
      );
      return false;
    }
  }

  String _uploadError(String body) {
    try {
      final data = json.decode(body);
      if (data is Map) {
        final detail = (data['error'] ?? data['message'] ?? '').toString().trim();
        if (detail.isNotEmpty) return detail;
      }
    } catch (_) {}
    final detail = body.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    return detail.isEmpty
        ? 'сервер не указал причину'
        : detail.substring(0, math.min(detail.length, 180));
  }

  // ====================== ЗВОНКИ (LiveKit) ======================

  int _memberUserId(Map<String, dynamic> member) {
    for (final key in const ['user_id', 'userId', 'id']) {
      final id = int.tryParse('${member[key] ?? ''}');
      if (id != null && id > 0) return id;
    }
    return 0;
  }

  Future<void> _startAudioCallTo(int calleeId, {String? peerName}) async {
    if (_callOpening) return;
    if (calleeId <= 0 || calleeId == widget.userId) {
      _showError('Некорректный получатель звонка');
      return;
    }
    _callOpening = true;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OutgoingCallScreen(
            userId: widget.userId,
            calleeId: calleeId,
            channelId: 'chat_${widget.chatId}_${widget.userId}_'
                '${calleeId}_${DateTime.now().microsecondsSinceEpoch}',
            peerName: peerName ?? '',
          ),
        ),
      );
    } finally {
      _callOpening = false;
    }
  }

  Future<void> _startAudioCall() async {
    if (_resolvingCall || _callOpening) return;
    _resolvingCall = true;
    try {
      if (members.isEmpty) await _loadMembers();
      if (!mounted) return;

      final others = members.where((member) {
        final id = _memberUserId(member);
        return id > 0 && id != widget.userId;
      }).toList();

      if (others.isEmpty) {
        _showError('В чате нет другого участника для звонка');
        return;
      }

      if (others.length == 1) {
        final member = others.first;
        await _startAudioCallTo(
          _memberUserId(member),
          peerName: _memberDisplayName(member),
        );
        return;
      }

      final selectedId = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          return SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              itemCount: others.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final member = others[index];
                final id = _memberUserId(member);
                final name = _memberDisplayName(member);
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                  title: Text(name.isEmpty ? 'Участник $id' : name),
                  trailing: const Icon(Icons.call_rounded),
                  onTap: () => Navigator.pop(sheetContext, id),
                );
              },
            ),
          );
        },
      );

      if (selectedId == null || !mounted) return;
      final member = others.firstWhere((m) => _memberUserId(m) == selectedId);
      await _startAudioCallTo(
        selectedId,
        peerName: _memberDisplayName(member),
      );
    } finally {
      _resolvingCall = false;
    }
  }

  // ====================== SEARCH ======================

  void _toggleSearch() {
    setState(() {
      searchMode = !searchMode;
    });
    if (!searchMode) {
      _clearSearch();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).unfocus();
      });
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      searchQuery = '';
      searchHits = [];
      currentHit = -1;
    });
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {
        searchQuery = v.trim();
      });
      _rebuildHits();
    });
  }

  void _rebuildHits() {
    final q = searchQuery.toLowerCase();
    final hits = <int>[];
    if (q.isNotEmpty) {
      for (final m in messages) {
        final id = (m['id'] is int)
            ? m['id'] as int
            : int.tryParse(m['id'].toString()) ?? 0;
        final type = (m['type'] ?? '').toString().toLowerCase();
        final content = (m['content'] ?? '').toString().toLowerCase();
        final name = ('${m['first_name'] ?? ''} ${m['last_name'] ?? ''}')
            .toString()
            .toLowerCase();

        final textMatch =
            (type != 'image' && type != 'video' && content.contains(q));
        final nameMatch = name.contains(q);

        if (textMatch || nameMatch) hits.add(id);
      }
    }

    setState(() {
      searchHits = hits;
      currentHit = hits.isNotEmpty ? 0 : -1;
    });

    if (currentHit >= 0) _jumpToCurrentHit();
  }

  void _jumpToCurrentHit() {
    if (currentHit >= 0 && currentHit < searchHits.length) {
      _scrollToMessageId(searchHits[currentHit]);
    }
  }

  void _nextHit() {
    if (searchHits.isEmpty) return;
    setState(() {
      currentHit = (currentHit + 1) % searchHits.length;
    });
    _jumpToCurrentHit();
  }

  void _prevHit() {
    if (searchHits.isEmpty) return;
    setState(() {
      currentHit = (currentHit - 1 + searchHits.length) % searchHits.length;
    });
    _jumpToCurrentHit();
  }

  Widget _highlightedText(String text, String query, TextStyle base) {
    if (query.isEmpty) return Text(text, style: base);
    final reg = RegExp(RegExp.escape(query), caseSensitive: false);
    final matches = reg.allMatches(text);
    if (matches.isEmpty) return Text(text, style: base);

    final spans = <TextSpan>[];
    int last = 0;
    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: base.copyWith(
            backgroundColor: Colors.yellowAccent.withOpacity(0.6)),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return RichText(text: TextSpan(children: spans));
  }

  // ====================== Reply/Edit chips ======================

  Widget _buildReplyChip() {
    if (replyingToId == null || replyingToMessage == null) {
      return const SizedBox.shrink();
    }
    final author =
        '${replyingToMessage?['first_name'] ?? ''} ${replyingToMessage?['last_name'] ?? ''}'
            .trim();
    final preview = _excerptFromMsg(replyingToMessage!);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(left: BorderSide(color: Colors.blue.shade300, width: 3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _scrollToMessageId(replyingToId!),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ответ на $author',
                      style:
                          AppTypography.bodyMedium(color: _WinChatColors.text)),
                  const SizedBox(height: 2),
                  Text(preview,
                      style:
                          AppTypography.secondary(color: _WinChatColors.muted)),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Отменить ответ',
            onPressed: () => setState(() {
              replyingToId = null;
              replyingToMessage = null;
            }),
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEditChip() {
    if (editingMessageId == null) return const SizedBox.shrink();
    final msg = messages.firstWhere(
      (m) => m['id'] == editingMessageId,
      orElse: () => {},
    );
    final preview = msg.isNotEmpty ? _excerptFromMsg(msg) : '';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border:
            Border(left: BorderSide(color: Colors.amber.shade400, width: 3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              preview.isEmpty
                  ? 'Редактирование сообщения'
                  : 'Редактирование: $preview',
              style: AppTypography.body(color: _WinChatColors.text),
            ),
          ),
          IconButton(
            tooltip: 'Отменить',
            onPressed: () => setState(() => editingMessageId = null),
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }

  // ====================== Message Menus ======================

  void _startReply(Map<String, dynamic> msg) {
    setState(() {
      final id =
          (msg['id'] is int) ? msg['id'] : int.tryParse(msg['id'].toString());
      replyingToId = id;
      replyingToMessage = msg;
      editingMessageId = null;
    });
    _inputFocus.requestFocus();
  }

  void _startEdit(Map<String, dynamic> msg) {
    _controller.text = (msg['content'] ?? '').toString();
    setState(() {
      final id =
          (msg['id'] is int) ? msg['id'] : int.tryParse(msg['id'].toString());
      editingMessageId = id;
      replyingToId = null;
      replyingToMessage = null;
      isTyping = _controller.text.trim().isNotEmpty;
    });
    _inputFocus.requestFocus();
  }

  Future<void> _showMessageMenu(
    BuildContext context,
    Map<String, dynamic> msg, {
    Offset? globalPosition,
  }) async {
    final isMine = msg['sender_id'] == widget.userId;
    final messenger = ScaffoldMessenger.of(context);
    final messageId = int.tryParse('${msg['id'] ?? 0}') ?? 0;

    final roomBox = context.findRenderObject() as RenderBox?;
    final roomOrigin = roomBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final roomSize = roomBox?.size ?? MediaQuery.sizeOf(context);
    final roomRect = roomOrigin & roomSize;

    final anchor = globalPosition ??
        Offset(
          roomRect.left + roomRect.width * .68,
          roomRect.top + roomRect.height * .52,
        );

    final actionCount = 3 + (isMine ? 2 : 0);
    final popupWidth = math
        .min(318.0, math.max(270.0, roomRect.width - 24))
        .toDouble();
    final popupHeight = 62.0 + actionCount * 43.0 + 14.0;

    double left = anchor.dx - popupWidth * .55;
    left = left.clamp(
      roomRect.left + 10,
      math.max(roomRect.left + 10, roomRect.right - popupWidth - 10),
    ).toDouble();

    final spaceBelow = roomRect.bottom - anchor.dy;
    double top = spaceBelow >= popupHeight + 18
        ? anchor.dy + 10
        : anchor.dy - popupHeight - 10;
    top = top.clamp(
      roomRect.top + 8,
      math.max(roomRect.top + 8, roomRect.bottom - popupHeight - 8),
    ).toDouble();

    Future<void> deleteMessage() async {
      await http.post(
        Uri.parse('https://sportotekaapp.ru/api/delete_message.php'),
        body: {'message_id': msg['id'].toString()},
      );
      _loadMessages();
      _markThisChatRead();
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть меню сообщения',
      barrierColor: Colors.black.withOpacity(.10),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dialogContext, _, __) {
        void closeAnd(VoidCallback action) {
          Navigator.of(dialogContext).pop();
          Future<void>.delayed(Duration.zero, action);
        }

        Widget actionRow({
          required IconData icon,
          required String label,
          required VoidCallback onTap,
          Color? color,
        }) {
          final c = color ?? _WinChatColors.text;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 43,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Icon(icon, size: 19, color: c),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: _WinChatText.body(
                            13.0,
                            color: c,
                            weight: FontWeight.w600,
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

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: popupWidth,
                child: Material(
                  color: Colors.white,
                  elevation: 14,
                  shadowColor: Colors.black.withOpacity(.18),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(7, 7, 7, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (messageId > 0)
                          Container(
                            height: 49,
                            decoration: BoxDecoration(
                              color: _WinChatColors.soft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                ...['❤️', '👍', '😂', '😮', '😢', '👏'].map(
                                  (reaction) => InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () => closeAnd(
                                      () => _toggleReaction(msg, reaction),
                                    ),
                                    child: SizedBox(
                                      width: 37,
                                      height: 40,
                                      child: Center(
                                        child: Text(
                                          reaction,
                                          style: const TextStyle(fontSize: 21),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message: 'Другие реакции',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () => closeAnd(
                                      () => _openReactionPicker(msg),
                                    ),
                                    child: const SizedBox(
                                      width: 38,
                                      height: 40,
                                      child: Center(
                                        child: Icon(
                                          Icons.add_reaction_outlined,
                                          size: 21,
                                          color: _WinChatColors.greenDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (messageId > 0) const SizedBox(height: 5),
                        actionRow(
                          icon: Icons.reply_rounded,
                          label: 'Ответить',
                          onTap: () => closeAnd(() => _startReply(msg)),
                        ),
                        if (messageId > 0)
                          actionRow(
                            icon: Icons.forward_to_inbox_rounded,
                            label: 'Переслать',
                            onTap: () => closeAnd(() => _forwardMessage(msg)),
                          ),
                        actionRow(
                          icon: Icons.copy_rounded,
                          label: 'Копировать',
                          onTap: () => closeAnd(() {
                            Clipboard.setData(
                              ClipboardData(
                                text: (msg['content'] ?? '').toString(),
                              ),
                            );
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Текст скопирован')),
                            );
                          }),
                        ),
                        if (isMine)
                          actionRow(
                            icon: Icons.edit_rounded,
                            label: 'Редактировать',
                            onTap: () => closeAnd(() => _startEdit(msg)),
                          ),
                        if (isMine)
                          actionRow(
                            icon: Icons.delete_outline_rounded,
                            label: 'Удалить',
                            color: const Color(0xFFD92D20),
                            onTap: () => closeAnd(() {
                              unawaited(deleteMessage());
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .97, end: 1).animate(curved),
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
    );
  }

  // ====================== UI: Skeleton & Bubbles ======================

  Widget _buildSkeletonMessage(int index) {
    final isMine = index % 3 == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine)
            CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              radius: 16,
            ),
          const SizedBox(width: 8),
          Container(
            width: 120 + (index % 3) * 60,
            height: 30 + (index % 2) * 18,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _replyBubblePreview(Map<String, dynamic> msg) {
    Map<String, dynamic>? reply = (msg['reply'] is Map)
        ? Map<String, dynamic>.from(msg['reply'])
        : (msg['reply_message'] is Map)
            ? Map<String, dynamic>.from(msg['reply_message'])
            : null;
    final messageId = int.tryParse('${msg['id'] ?? 0}') ?? 0;
    final cached = messageId > 0 ? _replyPreviewCache[messageId] : null;
    reply ??= cached == null ? null : Map<String, dynamic>.from(cached);

    final replyId = reply?['id'] ??
        msg['reply_to_id'] ??
        msg['reply_message_id'] ??
        msg['quoted_message_id'] ??
        msg['reply_to_message_id'] ??
        msg['parent_message_id'];
    if (replyId == null) return const SizedBox.shrink();

    final replyIdInt = int.tryParse(replyId.toString());
    if ((reply == null ||
            ((reply['content'] ?? '').toString().isEmpty &&
                (reply['file_url'] ?? '').toString().isEmpty)) &&
        replyIdInt != null) {
      final original = messages.firstWhere(
        (m) => int.tryParse('${m['id'] ?? 0}') == replyIdInt,
        orElse: () => <String, dynamic>{},
      );
      if (original.isNotEmpty) {
        reply = <String, dynamic>{
          'id': replyIdInt,
          'content': (original['content'] ?? '').toString(),
          'type': (original['type'] ?? 'text').toString(),
          'file_url': original['file_url'],
          'sender_id': original['sender_id'],
          'sender_name':
              '${original['first_name'] ?? ''} ${original['last_name'] ?? ''}'
                  .trim(),
        };
      }
    }

    final replySenderId = int.tryParse(
      '${reply?['sender_id'] ?? msg['reply_sender_id'] ?? 0}',
    );
    var replyAuthor = (reply?['sender_name'] ??
            '${msg['reply_first_name'] ?? ''} ${msg['reply_last_name'] ?? ''}')
        .toString()
        .trim();
    if (replyAuthor.isEmpty && replySenderId == widget.userId) {
      replyAuthor = 'Вы';
    }
    if (replyAuthor.isEmpty) replyAuthor = 'Сообщение';

    final replyType =
        (reply?['type'] ?? msg['reply_type'] ?? '').toString().toLowerCase();
    final replyContent =
        (reply?['content'] ?? msg['reply_content'] ?? '').toString();
    final replyFile =
        ((reply?['file_url'] ?? msg['reply_file_url']) ?? '').toString();

    final hasVideo = _isVideoType(replyType, replyFile);
    final hasGif = replyType == 'gif' ||
        _isGifUrl(replyFile) ||
        _isGifUrl(replyContent);
    final hasImage = !hasGif && _isImageType(replyType, replyFile);
    final hasAudio = _isAudioType(replyType, replyFile);
    final hasFile = replyType == 'file' || replyType == 'document';

    final text = hasVideo
        ? 'Видео'
        : hasGif
            ? 'GIF'
            : hasImage
                ? 'Фото'
                : hasAudio
                    ? 'Голосовое сообщение'
                    : hasFile
                        ? (replyContent.isEmpty ? 'Документ' : replyContent)
                        : (replyContent.isEmpty ? 'Сообщение' : replyContent);
    final preview = text.length > 110 ? '${text.substring(0, 110)}…' : text;
    final isMine = msg['sender_id'] == widget.userId;
    final replyMediaUrl = replyFile.isNotEmpty
        ? replyFile
        : (hasGif ? replyContent : '');
    final resolvedReplyFile = _resolveUrl(replyMediaUrl);

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () {
        final idInt =
            (replyId is int) ? replyId : int.tryParse(replyId.toString());
        if (idInt != null) _scrollToMessageId(idInt);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(9, 6, 7, 6),
        decoration: BoxDecoration(
          color: isMine ? Colors.white.withOpacity(.72) : _WinChatColors.soft2,
          border: const Border(
            left: BorderSide(color: _WinChatColors.green, width: 3),
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    replyAuthor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _WinChatText.body(
                      11.2,
                      color: _WinChatColors.greenDark,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (hasVideo) ...[
                        const Icon(
                          Icons.videocam_rounded,
                          size: 14,
                          color: _WinChatColors.muted,
                        ),
                        const SizedBox(width: 4),
                      ] else if (hasGif) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _WinChatColors.greenSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'GIF',
                            style: AppTypography.commentMeta(
                              color: _WinChatColors.greenDark,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ] else if (hasImage) ...[
                        const Icon(
                          Icons.photo_rounded,
                          size: 14,
                          color: _WinChatColors.muted,
                        ),
                        const SizedBox(width: 4),
                      ] else if (hasFile) ...[
                        const Icon(
                          Icons.insert_drive_file_rounded,
                          size: 14,
                          color: _WinChatColors.muted,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.secondary(
                            color: _WinChatColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if ((hasImage || hasGif) && resolvedReplyFile.isNotEmpty) ...[
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.network(
                  resolvedReplyFile,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 42,
                    height: 42,
                    color: _WinChatColors.soft,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.photo_rounded,
                      size: 19,
                      color: _WinChatColors.muted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fileMessage(Map<String, dynamic> msg, String fileUrl) {
    final localPath = (msg['local_path'] ?? '').toString();
    final rawName = (msg['file_name'] ??
            msg['filename'] ??
            msg['original_name'] ??
            msg['content'] ??
            '')
        .toString()
        .trim();
    final segments = Uri.tryParse(fileUrl)?.pathSegments ?? const <String>[];
    final pathName = localPath.isNotEmpty
        ? localPath.split(Platform.pathSeparator).last
        : (segments.isEmpty ? '' : segments.last);
    final name = rawName.isNotEmpty
        ? rawName
        : (pathName.isNotEmpty ? Uri.decodeComponent(pathName) : 'Файл');

    Future<void> openDocument() async {
      final messageId = int.tryParse('${msg['id'] ?? 0}') ?? 0;
      final mimeType = '${msg['mime_type'] ?? lookupMimeType(name) ?? ''}';
      if (widget.clubId <= 0 || messageId <= 0) {
        await openWorkspaceAttachmentPreview(
          context,
          title: name,
          fileUrl: fileUrl,
          mimeType: mimeType,
        );
        return;
      }
      final date = _safeParseDate(msg['created_at']).toLocal();
      String two(int value) => value.toString().padLeft(2, '0');
      final folderId = 'local-folder:chat-documents:'
          '${date.year}-${two(date.month)}-${two(date.day)}';
      await openWorkspaceChatDocument(
        context,
        title: name,
        fileUrl: fileUrl,
        mimeType: mimeType,
        sourceNodeId: 'chat-document:${widget.chatId}:$messageId',
        folderId: folderId,
        clubId: widget.clubId,
        userId: widget.userId,
        clubName: widget.chatName,
        ensureIndexed: () => _documentSync.sync(
          messageId: messageId,
          fileUrl: fileUrl,
          fileName: name,
          sentAt: date,
          mimeType: mimeType,
        ),
      );
    }

    return InkWell(
      onTap: fileUrl.isEmpty
          ? null
          : openDocument,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.insert_drive_file_outlined,
                color: _WinChatColors.greenDark, size: 23),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _WinChatText.messageBody()),
                  Text(
                    fileUrl.isEmpty
                        ? 'Отправляется…'
                        : 'Нажмите, чтобы скопировать ссылку',
                    style: _WinChatText.caption(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg,
      {bool showAvatarAndName = true}) {
    final isMine = msg['sender_id'] == widget.userId;
    final isDeleted = _asBool(msg['is_deleted']);

    final senderName = [msg['first_name'], msg['last_name']]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .map((part) => part.toString().trim())
        .join(' ');
    final avatarUrl = _messagePhoto(msg);
    final memberPhoto = _memberPhotoForUser(
      int.tryParse('${msg['sender_id'] ?? ''}') ?? 0,
    );
    final backupPhoto = avatarUrl == memberPhoto ? '' : memberPhoto;
    final messageDate = _safeParseDate(msg['created_at']).toLocal();
    final isEdited =
        (msg['updated_at'] != null && msg['updated_at'].toString().isNotEmpty);

    final id = (msg['id'] is int)
        ? msg['id'] as int
        : int.tryParse(msg['id'].toString()) ?? 0;
    final key = _messageKeys.putIfAbsent(id, () => GlobalKey());
    final heroTag = 'img_$id';

    final isLocalSending =
        msg['_local'] == true && (msg['_status'] == 'sending');
    final isLocalFailed =
        msg['_local'] == true && (msg['_status'] == 'failed');
    final uploadProgress = ((msg['_upload_progress'] is num)
            ? (msg['_upload_progress'] as num).toDouble()
            : 0.0)
        .clamp(0.0, 1.0)
        .toDouble();
    final uploadPercent = (uploadProgress * 100).round();
    final bubbleAccent =
        isMine ? _WinChatColors.green : _messageAccent(senderName.hashCode);
    final bubbleSoft = isMine
        ? _WinChatColors.greenSoft
        : _messageAccentSoft(senderName.hashCode);

    return Container(
      key: key,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 420 || isDeleted || id <= 0) return;
          HapticFeedback.selectionClick();
          _startReply(msg);
        },
        child: InkWell(
        onTapDown: (details) {
          _lastMessagePressPosition = details.globalPosition;
        },
        onLongPress: () => _showMessageMenu(
          context,
          msg,
          globalPosition: _lastMessagePressPosition,
        ),
        onDoubleTap: () => _toggleReaction(msg, '❤️'),
        splashColor: isMine
            ? Colors.blue.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMine && showAvatarAndName)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      final senderId =
                          int.tryParse((msg['sender_id'] ?? '').toString()) ?? 0;
                      _openUserProfile(senderId);
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: _WinChatColors.greenSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => backupPhoto.isNotEmpty
                                  ? Image.network(backupPhoto, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          _messageInitial(msg),
                                          style: _WinChatText.title(10.2,
                                              color: _WinChatColors.greenDark),
                                        ),
                                      ))
                                  : Center(
                                      child: Text(
                                        _messageInitial(msg),
                                        style: _WinChatText.title(10.2,
                                            color: _WinChatColors.greenDark),
                                      ),
                                    ),
                            )
                          : Center(
                              child: Text(
                                _messageInitial(msg),
                                style: _WinChatText.title(
                                  10.2,
                                  color: _WinChatColors.greenDark,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              Flexible(
                child: Column(
                  crossAxisAlignment: isMine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isMine && showAvatarAndName)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => _openUserProfile(
                            int.tryParse('${msg['sender_id'] ?? 0}') ?? 0,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 1,
                            ),
                            child: Text(
                              senderName,
                              style: _WinChatText.body(
                                11.0,
                                color: bubbleAccent,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Stack(
                      children: [
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width *
                                (MediaQuery.of(context).size.width < 420
                                    ? 0.80
                                    : 0.70),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: isMine
                                ? _WinChatColors.greenSoft
                                : Colors.white,
                            borderRadius: BorderRadius.circular(11),
                            border: null,
                            boxShadow: null,
                          ),
                          child: Column(
                            crossAxisAlignment: isMine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if ((msg['reply_to_id'] ??
                                      msg['reply_message_id'] ??
                                      msg['quoted_message_id'] ??
                                      msg['reply']) !=
                                  null)
                                _replyBubblePreview(msg),
                              if (isDeleted)
                                Text(
                                  'Сообщение удалено',
                                  style: _WinChatText.body(
                                    12.3,
                                    color: _WinChatColors.muted,
                                    weight: FontWeight.w400,
                                  ).copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else
                                ...() {
                                  final type = (msg['type'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final fileUrl = _resolveUrl(
                                    (msg['file_url'] ??
                                            msg['image_url'] ??
                                            msg['url'] ??
                                            msg['path'])
                                        ?.toString(),
                                  );
                                  final text =
                                      (msg['content'] ?? '').toString();

                                  final localPath =
                                      (msg['local_path'] ?? '').toString();

                                  if (_isVideoType(type, fileUrl) &&
                                      localPath.isNotEmpty) {
                                    return [
                                      _ChatVideoPreview(
                                        file: File(localPath),
                                        onOpen: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  _FullVideoScreen.file(
                                                file: File(localPath),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ];
                                  }

                                  if (_isVideoType(type, fileUrl) &&
                                      fileUrl.isNotEmpty) {
                                    return [
                                      _ChatVideoPreview(
                                        url: fileUrl,
                                        onOpen: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  _FullVideoScreen.network(
                                                url: fileUrl,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ];
                                  }

                                  if (_isAudioType(type, localPath) &&
                                      localPath.isNotEmpty) {
                                    return [
                                      _VoiceMessageBubble(
                                        localPath: localPath,
                                        isMine: isMine,
                                      ),
                                    ];
                                  }

                                  if (_isAudioType(type, fileUrl) &&
                                      fileUrl.isNotEmpty) {
                                    return [
                                      _VoiceMessageBubble(
                                        url: fileUrl,
                                        isMine: isMine,
                                      ),
                                    ];
                                  }

                                  if (_isImageType(type, localPath) &&
                                      (msg['local_path'] ?? '')
                                          .toString()
                                          .isNotEmpty) {
                                    return [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: GestureDetector(
                                          onTap: () => _openImageGallery(msg),
                                          child: Hero(
                                            tag: heroTag,
                                            child: Image.file(
                                              File(msg['local_path']),
                                              width: 220,
                                              height: 160,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      )
                                    ];
                                  }

                                  if (_isImageType(type, fileUrl) &&
                                      fileUrl.isNotEmpty) {
                                    return [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: GestureDetector(
                                          onTap: () => _openImageGallery(msg),
                                          child: Hero(
                                            tag: heroTag,
                                            child: Image.network(
                                              fileUrl,
                                              width: 220,
                                              height: 160,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Text(
                                                      'Ошибка загрузки изображения'),
                                            ),
                                          ),
                                        ),
                                      )
                                    ];
                                  } else if (type == 'file' || type == 'document' ||
                                      localPath.isNotEmpty || fileUrl.isNotEmpty) {
                                    return [_fileMessage(msg, fileUrl)];
                                  } else if (_looksLikeImageUrl(text)) {
                                    final u = _resolveUrl(text);
                                    return [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: GestureDetector(
                                          onTap: () => _openImageGallery(msg),
                                          child: Hero(
                                            tag: heroTag,
                                            child: Image.network(
                                              u,
                                              width: 220,
                                              height: 160,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Text(
                                                text,
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    ];
                                  } else {
                                    final style = _WinChatText.messageBody(
                                      color: _WinChatColors.text,
                                      weight: FontWeight.w500,
                                    );
                                    if (searchQuery.isNotEmpty &&
                                        text.toLowerCase().contains(
                                            searchQuery.toLowerCase())) {
                                      return [
                                        _highlightedText(
                                            text, searchQuery, style)
                                      ];
                                    }
                                    return [Text(text, style: style)];
                                  }
                                }(),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat.Hm().format(messageDate),
                                    style: AppTypography.commentMeta(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (isEdited)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Text(
                                        '· изменено',
                                        style: AppTypography.commentMeta(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  if (isMine)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Tooltip(
                                        message: _messageIsRead(msg)
                                            ? 'Прочитано'
                                            : 'Доставлено',
                                        child: Icon(
                                          _messageIsRead(msg)
                                              ? Icons.done_all_rounded
                                              : Icons.done_rounded,
                                          size: 15,
                                          color: _messageIsRead(msg)
                                              ? _WinChatColors.green
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isLocalSending)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.58),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.94),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          value: uploadProgress > 0
                                              ? uploadProgress
                                              : null,
                                          strokeWidth: 2.5,
                                          color: _WinChatColors.green,
                                          backgroundColor:
                                              _WinChatColors.greenSoft,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        uploadProgress > 0
                                            ? 'Загрузка $uploadPercent%'
                                            : 'Подготовка…',
                                        style: _WinChatText.body(
                                          11.2,
                                          color: _WinChatColors.greenDark,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (isLocalFailed)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Material(
                          color: _WinChatColors.soft,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => unawaited(_retryMediaMessage(msg)),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                    color: _WinChatColors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Не загружено · Повторить',
                                    style: _WinChatText.body(
                                      10.8,
                                      color: _WinChatColors.red,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!isDeleted && id > 0)
                      _buildReactionChips(id, isMine: isMine),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // ====================== Build ======================

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final compact = width < 520;
    final keyboardVisible = media.viewInsets.bottom > 0;

    // В CMR/workspace глобальная плавающая кнопка ИИ поднимается над
    // клавиатурой и на части планшетов попадает поверх кнопки отправки.
    // Пока клавиатура открыта, резервируем справа место под эту кнопку.
    final aiButtonClearance =
        widget.embedded && keyboardVisible ? (compact ? 52.0 : 58.0) : 0.0;

    final messagePadding = EdgeInsets.fromLTRB(
      compact ? 7 : 12,
      compact ? 7 : 10,
      compact ? 7 : 12,
      compact ? 9 : 12,
    );

    final peerPhoto = _peerPhoto;

    final scaffold = Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: widget.embedded
          ? null
          : AppBar(
              toolbarHeight: compact ? 54 : 58,
              automaticallyImplyLeading: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.white,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
              leadingWidth: 46,
              leading: Center(
                child: Material(
                  color: _WinChatColors.soft,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(9),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: _WinChatColors.graphite,
                      ),
                    ),
                  ),
                ),
              ),
              titleSpacing: 0,
              title: searchMode
                  ? Container(
                      height: 36,
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _WinChatColors.soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: <Widget>[
                          const _RoomDots(
                            color: _WinChatColors.muted,
                            compact: true,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onChanged: _onSearchChanged,
                              onSubmitted: _onSearchChanged,
                              style: _WinChatText.body(
                                11.1,
                                color: _WinChatColors.text,
                                weight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Поиск',
                                hintStyle: _WinChatText.body(
                                  10.8,
                                  color: _WinChatColors.muted,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.isGroup || _peerUserId <= 0
                            ? null
                            : _openPeerProfile,
                        borderRadius: BorderRadius.circular(11),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 38,
                                height: 38,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: _WinChatColors.soft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: peerPhoto.isNotEmpty
                                    ? Image.network(
                                        peerPhoto,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(
                                          child: _RoomDots(compact: true),
                                        ),
                                      )
                                    : const Center(
                                        child: _RoomDots(compact: true),
                                      ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      _chatTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _WinChatText.title(
                                        compact ? 13.2 : 14.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.isChannel
                                          ? '${_currentChannelSubscriberCount > 0 ? _currentChannelSubscriberCount : members.length} подписчиков · канал'
                                          : (widget.isGroup || members.length > 2
                                              ? '${members.length} участников'
                                              : 'Личная переписка · профиль'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _WinChatText.caption(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              actions: searchMode
                  ? <Widget>[
                      Center(
                        child: Text(
                          searchHits.isEmpty
                              ? '0/0'
                              : '${currentHit >= 0 ? currentHit + 1 : 0}/${searchHits.length}',
                          style: _WinChatText.body(
                            10.0,
                            color: _WinChatColors.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 18,
                        ),
                        onPressed: searchHits.isEmpty ? null : _prevHit,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                        ),
                        onPressed: searchHits.isEmpty ? null : _nextHit,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                        ),
                        onPressed: _toggleSearch,
                      ),
                    ]
                  : <Widget>[
                      _RoomHeaderIcon(
                        tooltip: 'Поиск',
                        icon: Icons.search_rounded,
                        onTap: _toggleSearch,
                      ),
                      _RoomHeaderIcon(
                        tooltip: 'Аудиозвонок',
                        icon: Icons.call_rounded,
                        onTap: _startAudioCall,
                      ),
                      if (widget.isChannel)
                        _RoomHeaderIcon(
                          tooltip: _channelCanManage ? 'Управление каналом' : 'О канале',
                          icon: _channelCanManage
                              ? Icons.settings_rounded
                              : Icons.info_outline_rounded,
                          onTap: _openChannelManagement,
                        )
                      else if (members.length > 2)
                        _RoomHeaderIcon(
                          tooltip: 'Участники',
                          icon: Icons.group_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditGroupChatScreen(
                                  chatId: widget.chatId,
                                  currentUserId: widget.userId,
                                  chatName: _chatTitle,
                                ),
                              ),
                            ).then((_) => _loadMembers());
                          },
                        ),
                      const SizedBox(width: 5),
                    ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  thickness: .6,
                  color: _WinChatColors.line,
                ),
              ),
            ),
      body: Column(
        children: <Widget>[
          _buildEditChip(),
          _buildReplyChip(),
          Expanded(
            child: Stack(
              children: <Widget>[
                Container(
                  decoration: _WinChatDecor.workspaceBg(),
                  child: isLoading
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: ListView.builder(
                            padding: messagePadding,
                            itemCount: 10,
                            itemBuilder: (context, index) =>
                                _buildSkeletonMessage(index),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          controller: _scrollController,
                          padding: messagePadding,
                          itemCount: messages.length,
                          addAutomaticKeepAlives: true,
                          addRepaintBoundaries: true,
                          cacheExtent: 1000,
                          itemBuilder: (context, index) {
                            final currentMessage = messages[index];
                            final currentDate = _safeParseDate(
                              currentMessage['created_at'],
                            ).toLocal();

                            final previousMessage =
                                index > 0 ? messages[index - 1] : null;

                            final prevDate = previousMessage != null
                                ? _safeParseDate(
                                    previousMessage['created_at'],
                                  ).toLocal()
                                : null;

                            final isSameUser = previousMessage != null &&
                                previousMessage['sender_id'] ==
                                    currentMessage['sender_id'];

                            final messageWidget = _buildMessage(
                              currentMessage,
                              showAvatarAndName: !isSameUser,
                            );

                            if (prevDate == null ||
                                !DateUtils.isSameDay(
                                  currentDate,
                                  prevDate,
                                )) {
                              return Column(
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 5,
                                      top: 3,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        const _RoomDot(
                                          color: _WinChatColors.muted,
                                          size: 3.5,
                                          opacity: .45,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          DateFormat.yMMMMd('ru_RU')
                                              .format(currentDate),
                                          style: _WinChatText.caption(),
                                        ),
                                        const SizedBox(width: 6),
                                        const _RoomDot(
                                          color: _WinChatColors.muted,
                                          size: 3.5,
                                          opacity: .45,
                                        ),
                                      ],
                                    ),
                                  ),
                                  messageWidget,
                                ],
                              );
                            }

                            return messageWidget;
                          },
                        ),
                ),
                Positioned(
                  bottom: compact ? 8 : 12,
                  right: compact ? 8 : 12,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _showScrollToBottomVN,
                    builder: (_, visible, __) {
                      return IgnorePointer(
                        ignoring: !visible,
                        child: AnimatedOpacity(
                          opacity: visible ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Material(
                            color: _WinChatColors.greenSoft,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: _scrollToBottom,
                              borderRadius: BorderRadius.circular(10),
                              child: const SizedBox(
                                width: 34,
                                height: 34,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: _WinChatColors.greenDark,
                                ),
                              ),
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
          if (widget.isChannel && !_channelCanPublish)
            _buildChannelReadOnlyBar()
          else
            SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: _WinChatColors.line,
                      width: .6,
                    ),
                  ),
                ),
              padding: EdgeInsets.fromLTRB(
                compact ? 6 : 9,
                6,
                (compact ? 6 : 9) + aiButtonClearance,
                6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _RoomInputAction(
                    icon: Icons.attach_file_rounded,
                    onTap: _openAttachmentMenu,
                  ),
                  const SizedBox(width: 5),
                  _RoomInputAction(
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    onTap: _openEmojiPicker,
                  ),
                  const SizedBox(width: 5),
                  _RoomGifAction(onTap: _openGifPicker),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 38),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _WinChatColors.soft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: isRecording
                          ? Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: _WinChatColors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatVoiceDuration(_voiceDuration),
                                  style: _WinChatText.body(
                                    11.5,
                                    color: _WinChatColors.red,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 140),
                                    child: Row(
                                      key: ValueKey<bool>(_voiceCancelArmed),
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _voiceCancelArmed
                                              ? Icons.delete_outline_rounded
                                              : Icons.chevron_left_rounded,
                                          size: 17,
                                          color: _voiceCancelArmed
                                              ? _WinChatColors.red
                                              : _WinChatColors.muted,
                                        ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            _voiceCancelArmed
                                                ? 'Отпустите — запись отменится'
                                                : 'Свайп влево для отмены',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: _WinChatText.body(
                                              10.8,
                                              color: _voiceCancelArmed
                                                  ? _WinChatColors.red
                                                  : _WinChatColors.muted,
                                              weight: _voiceCancelArmed
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : TextField(
                              focusNode: _inputFocus,
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: editingMessageId != null
                                    ? 'Изменить сообщение…'
                                    : (replyingToId != null
                                        ? 'Ответить…'
                                        : 'Сообщение…'),
                                hintStyle: _WinChatText.body(
                                  11.0,
                                  color: _WinChatColors.muted,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 9),
                              ),
                              style: _WinChatText.body(
                                12.3,
                                color: _WinChatColors.text,
                                weight: FontWeight.w500,
                              ),
                              onChanged: (v) => setState(
                                () => isTyping = v.trim().isNotEmpty,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  if (isTyping)
                    _RoomSendAction(onTap: _sendMessage)
                  else
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPressStart: (details) {
                        _voicePressHeld = true;
                        _voicePressStartX = details.globalPosition.dx;
                        _voiceSwipeDistance = 0;
                        _voiceCancelArmed = false;
                        _startRecording();
                      },
                      onLongPressMoveUpdate: (details) {
                        final startX = _voicePressStartX;
                        if (startX == null || !isRecording) return;
                        final distance = math.max(
                          0.0,
                          startX - details.globalPosition.dx,
                        );
                        final armed = distance >= 72;
                        if (armed != _voiceCancelArmed ||
                            (distance - _voiceSwipeDistance).abs() >= 8) {
                          setState(() {
                            _voiceSwipeDistance = distance;
                            _voiceCancelArmed = armed;
                          });
                          if (armed) HapticFeedback.selectionClick();
                        }
                      },
                      onLongPressEnd: (_) {
                        _voicePressHeld = false;
                        _stopRecording(cancel: _voiceCancelArmed);
                      },
                      onLongPressCancel: () {
                        _voicePressHeld = false;
                        _stopRecording(cancel: true);
                      },
                      child: _RoomInputAction(
                        icon: isRecording
                            ? Icons.mic_off_rounded
                            : Icons.mic_none_rounded,
                        color: isRecording
                            ? _WinChatColors.red
                            : _WinChatColors.muted,
                        onTap: () {
                          _showError('Удерживайте микрофон для записи голосового');
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return scaffold;

    // iOS: SafeArea itself does not paint the status-bar inset.
    // Without a background the top inset can become black while the
    // status-bar icons stay dark, making time/signal/battery invisible.
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
          child: scaffold,
        ),
      ),
    );
  }

  // ====================== Voice messages ======================

  String _formatVoiceDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString();
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _startRecording() async {
    if (isRecording) return;
    try {
      final permitted = await _voiceRecorder.hasPermission();
      if (!permitted) {
        _showError('Разрешите доступ к микрофону для голосовых сообщений');
        return;
      }

      final path = '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'sportoteka_voice_${widget.chatId}_${DateTime.now().microsecondsSinceEpoch}.m4a';

      await _voiceRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );

      // Если пользователь успел отпустить кнопку, пока ОС открывала микрофон,
      // не оставляем скрытую запись работать в фоне.
      if (!_voicePressHeld) {
        final abandoned = await _voiceRecorder.stop();
        final abandonedPath = (abandoned ?? path).trim();
        if (abandonedPath.isNotEmpty) {
          try {
            final abandonedFile = File(abandonedPath);
            if (await abandonedFile.exists()) await abandonedFile.delete();
          } catch (_) {}
        }
        return;
      }

      _voiceTimer?.cancel();
      if (!mounted) return;
      setState(() {
        isRecording = true;
        _voiceDuration = Duration.zero;
        _voiceCancelArmed = false;
        _voiceSwipeDistance = 0;
      });
      HapticFeedback.mediumImpact();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !isRecording) return;
        setState(() => _voiceDuration += const Duration(seconds: 1));
      });
    } catch (e) {
      _voiceTimer?.cancel();
      if (mounted) {
        setState(() {
          isRecording = false;
          _voiceDuration = Duration.zero;
          _voiceCancelArmed = false;
          _voiceSwipeDistance = 0;
          _voicePressStartX = null;
        });
      }
      _showError('Не удалось начать запись голосового: $e');
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    if (!isRecording) return;
    _voiceTimer?.cancel();
    final recordedFor = _voiceDuration;

    String? path;
    try {
      path = await _voiceRecorder.stop();
    } catch (e) {
      if (!cancel) _showError('Не удалось завершить запись: $e');
    }

    if (!mounted) return;
    setState(() {
      isRecording = false;
      _voiceDuration = Duration.zero;
      _voiceCancelArmed = false;
      _voiceSwipeDistance = 0;
      _voicePressStartX = null;
    });

    final resolved = (path ?? '').trim();
    if (resolved.isEmpty) return;

    final file = File(resolved);

    if (cancel) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      HapticFeedback.mediumImpact();
      return;
    }

    if (recordedFor.inMilliseconds < 700) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      _showError('Голосовое слишком короткое');
      return;
    }

    HapticFeedback.lightImpact();
    final sent = await _sendMedia(file, type: 'audio');
    if (sent) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

}

class _ChatPhotoSendPreview extends StatefulWidget {
  final List<File> initialFiles;
  final bool allowCamera;

  const _ChatPhotoSendPreview({
    required this.initialFiles,
    required this.allowCamera,
  });

  @override
  State<_ChatPhotoSendPreview> createState() => _ChatPhotoSendPreviewState();
}

class _ChatPhotoSendPreviewState extends State<_ChatPhotoSendPreview> {
  static const int _maxPhotos = 20;
  late final List<File> _files;
  int _activeIndex = 0;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _files = _dedupe(widget.initialFiles).take(_maxPhotos).toList();
  }

  List<File> _dedupe(Iterable<File> items) {
    final seen = <String>{};
    final out = <File>[];
    for (final file in items) {
      final path = file.path.trim();
      if (path.isEmpty || !seen.add(path)) continue;
      out.add(file);
    }
    return out;
  }

  void _appendFiles(Iterable<File> items) {
    final merged = _dedupe(<File>[..._files, ...items]).take(_maxPhotos).toList();
    setState(() {
      _files
        ..clear()
        ..addAll(merged);
      if (_activeIndex >= _files.length) {
        _activeIndex = math.max(0, _files.length - 1);
      }
    });
  }

  Future<void> _addFromGallery() async {
    if (_adding || _files.length >= _maxPhotos) return;
    setState(() => _adding = true);
    try {
      final next = <File>[];
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final result = await FilePicker.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        if (result != null) {
          for (final item in result.files) {
            final path = item.path;
            if (path != null && path.isNotEmpty) next.add(File(path));
          }
        }
      } else {
        final picked = await ImagePicker().pickMultiImage(
          imageQuality: 86,
          maxWidth: 2400,
        );
        next.addAll(picked.map((item) => File(item.path)));
      }
      if (next.isNotEmpty) _appendFiles(next);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _addFromCamera() async {
    if (_adding || !widget.allowCamera || _files.length >= _maxPhotos) return;
    setState(() => _adding = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 2400,
      );
      if (picked != null) _appendFiles(<File>[File(picked.path)]);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _removeAt(int index) {
    if (index < 0 || index >= _files.length) return;
    setState(() {
      _files.removeAt(index);
      if (_files.isEmpty) {
        _activeIndex = 0;
      } else if (_activeIndex >= _files.length) {
        _activeIndex = _files.length - 1;
      } else if (index < _activeIndex) {
        _activeIndex--;
      }
    });
  }

  Widget _image(File file, {BoxFit fit = BoxFit.cover}) {
    return Image.file(
      file,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        color: _WinChatColors.soft,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: _WinChatColors.muted,
        ),
      ),
    );
  }

  Widget _thumbnail(int index, {double size = 76}) {
    final active = index == _activeIndex;
    return GestureDetector(
      onTap: () => setState(() => _activeIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: active ? _WinChatColors.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active ? _WinChatColors.green : _WinChatColors.line,
            width: active ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: _image(_files[index]),
            ),
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? _WinChatColors.green : Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '${index + 1}',
                  style: _WinChatText.caption(
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Positioned(
              left: 4,
              bottom: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => _removeAt(index),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: _WinChatColors.soft,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: _WinChatColors.greenDark),
              const SizedBox(width: 7),
              Text(
                label,
                style: _WinChatText.body(
                  10.8,
                  color: _WinChatColors.text,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _files.length;
    final activeFile = count == 0 ? null : _files[_activeIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          count == 0 ? 'Фото не выбраны' : 'Предпросмотр · $count',
          style: _WinChatText.title(14.2, color: _WinChatColors.text),
        ),
        actions: [
          if (count > 0)
            TextButton(
              onPressed: () => setState(() {
                _files.clear();
                _activeIndex = 0;
              }),
              child: const Text('Снять выбор'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 820;

            final preview = Container(
              color: const Color(0xFFF0F2F1),
              alignment: Alignment.center,
              child: activeFile == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 46,
                          color: _WinChatColors.muted,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Добавьте фото перед отправкой',
                          style: _WinChatText.body(
                            12,
                            color: _WinChatColors.muted,
                          ),
                        ),
                      ],
                    )
                  : InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: _image(activeFile, fit: BoxFit.contain),
                      ),
                    ),
            );

            final gallery = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          count == 0
                              ? 'Нет выбранных фотографий'
                              : 'Выбрано $count из $_maxPhotos',
                          style: _WinChatText.body(
                            11.4,
                            color: _WinChatColors.text,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_adding)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _WinChatColors.green,
                          ),
                        ),
                    ],
                  ),
                ),
                if (count > 0)
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: desktop ? 2 : 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: count,
                      itemBuilder: (_, index) => _thumbnail(
                        index,
                        size: desktop ? 92 : 72,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _action(
                        icon: Icons.add_photo_alternate_outlined,
                        label: 'Добавить фото',
                        onTap: _adding || count >= _maxPhotos
                            ? null
                            : _addFromGallery,
                      ),
                      if (widget.allowCamera)
                        _action(
                          icon: Icons.photo_camera_outlined,
                          label: 'Камера',
                          onTap: _adding || count >= _maxPhotos
                              ? null
                              : _addFromCamera,
                        ),
                    ],
                  ),
                ),
              ],
            );

            return Column(
              children: [
                Expanded(
                  child: desktop
                      ? Row(
                          children: [
                            Expanded(flex: 7, child: preview),
                            SizedBox(
                              width: math.min(330, constraints.maxWidth * .32),
                              child: gallery,
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(flex: 7, child: preview),
                            SizedBox(height: 210, child: gallery),
                          ],
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: _WinChatColors.line, width: .7),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Отмена'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: count == 0
                            ? null
                            : () => Navigator.of(context).pop(
                                  List<File>.from(_files),
                                ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _WinChatColors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 17),
                        label: Text(
                          count <= 1 ? 'Отправить' : 'Отправить $count',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


class _VoiceMessageBubble extends StatefulWidget {
  final String? localPath;
  final String? url;
  final bool isMine;

  const _VoiceMessageBubble({
    this.localPath,
    this.url,
    required this.isMine,
  });

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  late final AudioPlayer _player;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _durationSub = _player.onDurationChanged.listen((value) {
      if (!mounted) return;
      setState(() => _duration = value);
    });
    _positionSub = _player.onPositionChanged.listen((value) {
      if (!mounted) return;
      setState(() => _position = value);
    });
    _stateSub = _player.onPlayerStateChanged.listen((value) {
      if (!mounted) return;
      setState(() {
        _playing = value == PlayerState.playing;
        if (value != PlayerState.playing) _loading = false;
      });
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _loading = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  String _time(Duration value) {
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _toggle() async {
    if (_loading) return;
    try {
      if (_playing) {
        await _player.pause();
        return;
      }

      if (_position > Duration.zero &&
          _duration > Duration.zero &&
          _position < _duration) {
        await _player.resume();
        return;
      }

      setState(() => _loading = true);
      final path = (widget.localPath ?? '').trim();
      final url = (widget.url ?? '').trim();
      if (path.isNotEmpty) {
        await _player.play(DeviceFileSource(path));
      } else if (url.isNotEmpty) {
        await _player.play(UrlSource(url));
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seek(double seconds) async {
    if (_duration.inMilliseconds <= 0) return;
    final target = Duration(milliseconds: (seconds * 1000).round());
    await _player.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = math.max(1, _duration.inMilliseconds);
    final posMs = _position.inMilliseconds.clamp(0, totalMs);
    final maxSeconds = totalMs / 1000.0;
    final valueSeconds = posMs / 1000.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 290),
      child: Row(
        children: [
          Material(
            color: widget.isMine
                ? _WinChatColors.green
                : _WinChatColors.greenSoft,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _toggle,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: _loading
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.isMine
                              ? Colors.white
                              : _WinChatColors.greenDark,
                        ),
                      )
                    : Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: widget.isMine
                            ? Colors.white
                            : _WinChatColors.greenDark,
                        size: 22,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 11,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxSeconds,
                    value: valueSeconds.clamp(0.0, maxSeconds).toDouble(),
                    activeColor: _WinChatColors.green,
                    inactiveColor: _WinChatColors.line,
                    onChanged: _duration.inMilliseconds <= 0
                        ? null
                        : (value) => _seek(value),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mic_rounded,
                        size: 13,
                        color: _WinChatColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _duration == Duration.zero
                            ? 'Голосовое сообщение'
                            : '${_time(_position)} / ${_time(_duration)}',
                        style: _WinChatText.caption(
                          color: _WinChatColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AttachmentAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _WinChatColors.soft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _WinChatColors.greenSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: _WinChatColors.greenDark,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: _WinChatText.title(11.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: _WinChatText.body(
                        9.8,
                        color: _WinChatColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _WinChatColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomHeaderIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _RoomHeaderIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: _WinChatColors.soft,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                icon,
                size: 16,
                color: _WinChatColors.graphite,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomInputAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoomInputAction({
    required this.icon,
    required this.onTap,
    this.color = _WinChatColors.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _WinChatColors.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 17,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _RoomGifAction extends StatelessWidget {
  final VoidCallback onTap;

  const _RoomGifAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'GIF',
      child: Material(
        color: _WinChatColors.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 40,
            height: 36,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _WinChatColors.muted.withOpacity(.68),
                    width: 1.1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'GIF',
                  style: AppTypography.commentMeta(
                    color: _WinChatColors.graphite,
                  ).copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: .1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomSendAction extends StatelessWidget {
  final VoidCallback onTap;

  const _RoomSendAction({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _WinChatColors.greenSoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: _RoomDots(
              color: _WinChatColors.greenDark,
              compact: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _GiphyGif {
  final String id;
  final String url;
  final String previewUrl;
  final String title;

  const _GiphyGif({
    required this.id,
    required this.url,
    required this.previewUrl,
    required this.title,
  });

  static _GiphyGif? fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    if (images is! Map) return null;

    String readUrl(String key) {
      final node = images[key];
      if (node is Map) return (node['url'] ?? '').toString().trim();
      return '';
    }

    final sendUrl = readUrl('downsized').isNotEmpty
        ? readUrl('downsized')
        : readUrl('fixed_width').isNotEmpty
            ? readUrl('fixed_width')
            : readUrl('original');
    final previewUrl = readUrl('fixed_width_small').isNotEmpty
        ? readUrl('fixed_width_small')
        : readUrl('fixed_width').isNotEmpty
            ? readUrl('fixed_width')
            : sendUrl;

    if (sendUrl.isEmpty || previewUrl.isEmpty) return null;
    return _GiphyGif(
      id: (json['id'] ?? '').toString(),
      url: sendUrl,
      previewUrl: previewUrl,
      title: (json['title'] ?? 'GIF').toString(),
    );
  }
}

class _GiphyPickerSheet extends StatefulWidget {
  final String apiKey;
  final ValueChanged<_GiphyGif> onSelected;

  const _GiphyPickerSheet({
    required this.apiKey,
    required this.onSelected,
  });

  @override
  State<_GiphyPickerSheet> createState() => _GiphyPickerSheetState();
}

class _GiphyPickerSheetState extends State<_GiphyPickerSheet> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  List<_GiphyGif> _items = const [];
  bool _loading = true;
  String _error = '';
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (mounted) setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      _load(value.trim());
    });
  }

  Future<void> _load(String query) async {
    final version = ++_requestVersion;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    try {
      final isSearch = query.isNotEmpty;
      final uri = Uri.https(
        'api.giphy.com',
        isSearch ? '/v1/gifs/search' : '/v1/gifs/trending',
        <String, String>{
          'api_key': widget.apiKey,
          'limit': '30',
          'rating': 'pg-13',
          if (isSearch) 'q': query,
          if (isSearch) 'lang': 'ru',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = json.decode(response.body);
      final data = decoded is Map ? decoded['data'] : null;
      final list = data is List ? data : const [];
      final result = <_GiphyGif>[];
      for (final item in list) {
        if (item is! Map) continue;
        final gif = _GiphyGif.fromJson(Map<String, dynamic>.from(item));
        if (gif != null) result.add(gif);
      }

      if (!mounted || version != _requestVersion) return;
      setState(() {
        _items = result;
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить GIF';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final columns = screen.width >= 700 ? 4 : (screen.width >= 480 ? 3 : 2);

    return SafeArea(
      child: Container(
        height: screen.height * .78,
        margin: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _WinChatColors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'GIF',
                      style: _WinChatText.title(16),
                    ),
                  ),
                  Text(
                    'Powered by GIPHY',
                    style: AppTypography.commentMeta(
                      color: _WinChatColors.muted,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: TextField(
                controller: _search,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Найти GIF',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                            _load('');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                  filled: true,
                  fillColor: _WinChatColors.soft,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _search.text.trim().isEmpty ? 'Популярные' : 'Результаты',
                  style: _WinChatText.body(
                    11.2,
                    color: _WinChatColors.muted,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _error.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error,
                                style: _WinChatText.body(
                                  12,
                                  color: _WinChatColors.muted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _load(_search.text.trim()),
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Text(
                                'Ничего не найдено',
                                style: _WinChatText.body(
                                  12,
                                  color: _WinChatColors.muted,
                                ),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                                childAspectRatio: 1.22,
                              ),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final gif = _items[index];
                                return Material(
                                  color: _WinChatColors.soft,
                                  borderRadius: BorderRadius.circular(10),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () => widget.onSelected(gif),
                                    child: Image.network(
                                      gif.previewUrl,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: _WinChatColors.muted,
                                        ),
                                      ),
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.8,
                                            ),
                                          ),
                                        );
                                      },
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

class _ChatVideoPreview extends StatefulWidget {
  final String? url;
  final File? file;
  final VoidCallback onOpen;

  const _ChatVideoPreview({
    this.url,
    this.file,
    required this.onOpen,
  }) : assert(url != null || file != null);

  @override
  State<_ChatVideoPreview> createState() => _ChatVideoPreviewState();
}

class _ChatVideoPreviewState extends State<_ChatVideoPreview> {
  VideoPlayerController? _controller;
  Future<void>? _initializing;

  @override
  void initState() {
    super.initState();

    final controller = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));

    _controller = controller;
    _initializing = controller.initialize().then((_) async {
      await controller.setLooping(false);
      await controller.pause();
      if (mounted) setState(() {});
    }).catchError((Object _) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _durationLabel(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return GestureDetector(
      onTap: widget.onOpen,
      child: Container(
        width: 230,
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _WinChatColors.graphite,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (controller != null)
              FutureBuilder<void>(
                future: _initializing,
                builder: (_, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done ||
                      !controller.value.isInitialized) {
                    return const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }

                  final aspect = controller.value.aspectRatio > 0
                      ? controller.value.aspectRatio
                      : 16 / 9;

                  return Center(
                    child: AspectRatio(
                      aspectRatio: aspect,
                      child: VideoPlayer(controller),
                    ),
                  );
                },
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withOpacity(.03),
                      Colors.black.withOpacity(.24),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 27,
                  color: _WinChatColors.graphite,
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 7,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.videocam_outlined,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Видео',
                    style: AppTypography.commentMeta(
                      color: Colors.white,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (controller != null && controller.value.isInitialized)
              Positioned(
                right: 8,
                bottom: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _durationLabel(controller.value.duration),
                    style: AppTypography.commentMeta(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullVideoScreen extends StatefulWidget {
  final String? url;
  final File? file;

  const _FullVideoScreen.network({
    super.key,
    required String this.url,
  }) : file = null;

  const _FullVideoScreen.file({
    super.key,
    required File this.file,
  }) : url = null;

  @override
  State<_FullVideoScreen> createState() => _FullVideoScreenState();
}

class _FullVideoScreenState extends State<_FullVideoScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializing;

  @override
  void initState() {
    super.initState();

    _controller = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));

    _initializing = _controller.initialize().then((_) async {
      await _controller.setLooping(false);
      await _controller.play();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _time(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B0E),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF090B0E),
        foregroundColor: Colors.white,
        title: Text(
          'Видео',
          style: AppTypography.sectionTitle(color: Colors.white),
        ),
      ),
      body: FutureBuilder<void>(
        future: _initializing,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (!_controller.value.isInitialized) {
            return Center(
              child: Text(
                'Не удалось открыть видео',
                style: AppTypography.body(color: Colors.white),
              ),
            );
          }

          return SafeArea(
            top: false,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio > 0
                          ? _controller.value.aspectRatio
                          : 16 / 9,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    final value = _controller.value;
                    final duration = value.duration;
                    final position = value.position;
                    final maxMs = duration.inMilliseconds <= 0
                        ? 1
                        : duration.inMilliseconds;
                    final posMs =
                        position.inMilliseconds.clamp(0, maxMs).toDouble();

                    return Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      color: const Color(0xFF090B0E),
                      child: Column(
                        children: <Widget>[
                          Slider(
                            value: posMs,
                            max: maxMs.toDouble(),
                            onChanged: (v) {
                              _controller.seekTo(
                                Duration(milliseconds: v.round()),
                              );
                            },
                          ),
                          Row(
                            children: <Widget>[
                              Material(
                                color: Colors.white.withOpacity(.10),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  onTap: () async {
                                    if (value.isPlaying) {
                                      await _controller.pause();
                                    } else {
                                      await _controller.play();
                                    }
                                    if (mounted) setState(() {});
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 42,
                                    height: 42,
                                    child: Icon(
                                      value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${_time(position)} / ${_time(duration)}',
                                style: AppTypography.secondary(
                                  color: Colors.white70,
                                ),
                              ),
                              const Spacer(),
                              const _RoomDots(
                                color: _WinChatColors.green,
                                compact: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ====================== Fullscreen Image Gallery ======================

class _ChatImageItem {
  final int messageId;
  final String? url;
  final String? localPath;
  final String heroTag;

  const _ChatImageItem({
    required this.messageId,
    required this.heroTag,
    this.url,
    this.localPath,
  });
}

class _FullImageGalleryScreen extends StatefulWidget {
  final List<_ChatImageItem> items;
  final int initialIndex;

  const _FullImageGalleryScreen({
    required this.items,
    required this.initialIndex,
  });

  @override
  State<_FullImageGalleryScreen> createState() =>
      _FullImageGalleryScreenState();
}

class _FullImageGalleryScreenState extends State<_FullImageGalleryScreen> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1).toInt();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.items.length - 1).toInt();
    if (next == _index) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _viewer(_ChatImageItem item) {
    final image = item.localPath != null && item.localPath!.isNotEmpty
        ? Image.file(
            File(item.localPath!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text(
                'Не удалось открыть изображение',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        : Image.network(
            item.url ?? '',
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, __, ___) => const Center(
              child: Text(
                'Не удалось открыть изображение',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );

    return Center(
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 5,
        child: Hero(
          tag: item.heroTag,
          child: image,
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.black.withOpacity(.48),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 23),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 700;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (_, i) => _viewer(widget.items[i]),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _roundButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Закрыть',
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          if (widget.items.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 17),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (wide && widget.items.length > 1 && _index > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: _roundButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Предыдущее фото',
                  onTap: () => _go(-1),
                ),
              ),
            ),
          if (wide && widget.items.length > 1 &&
              _index < widget.items.length - 1)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _roundButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Следующее фото',
                  onTap: () => _go(1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ====================== Forward user picker ======================

class _ForwardUser {
  final int id;
  final String title;
  final String subtitle;
  final String photo;

  const _ForwardUser({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.photo,
  });
}

class _ForwardUserSheet extends StatefulWidget {
  final String apiUrl;
  final int myUserId;

  const _ForwardUserSheet({
    required this.apiUrl,
    required this.myUserId,
  });

  @override
  State<_ForwardUserSheet> createState() => _ForwardUserSheetState();
}

class _ForwardUserSheetState extends State<_ForwardUserSheet> {
  final TextEditingController _q = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<_ForwardUser> _items = [];

  @override
  void initState() {
    super.initState();
    _q.addListener(_queryChanged);
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _queryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () {
      _load(_q.text.trim());
    });
  }

  String _photoUrl(dynamic rawValue) {
    final raw = (rawValue ?? '').toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/uploads/$raw';
  }

  Future<void> _load(String query) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(widget.apiUrl).replace(queryParameters: {
        'q': query,
        'exclude_id': widget.myUserId.toString(),
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final data = json.decode(res.body);
      List raw = const [];
      if (res.statusCode == 200 && data is Map && data['success'] == true) {
        raw = (data['users'] as List?) ?? const [];
      } else if (res.statusCode == 200 && data is List) {
        raw = data;
      }

      final parsed = <_ForwardUser>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final id = int.tryParse('${item['id'] ?? 0}') ?? 0;
        if (id <= 0 || id == widget.myUserId) continue;
        final first = (item['first_name'] ?? '').toString().trim();
        final last = (item['last_name'] ?? '').toString().trim();
        final email = (item['email'] ?? '').toString().trim();
        final fullName = '$first $last'.trim();
        parsed.add(
          _ForwardUser(
            id: id,
            title: fullName.isNotEmpty
                ? fullName
                : (email.isNotEmpty ? email : 'Пользователь #$id'),
            subtitle: email,
            photo: _photoUrl(item['photo'] ?? item['avatar']),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _items = parsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = [];
        _error = 'Не удалось загрузить пользователей';
      });
    }
  }

  Widget _avatar(_ForwardUser user) {
    final letter = user.title.isEmpty ? 'П' : user.title.substring(0, 1);
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _WinChatColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: user.photo.isNotEmpty
          ? Image.network(
              user.photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  letter.toUpperCase(),
                  style: _WinChatText.title(
                    12,
                    color: _WinChatColors.greenDark,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                letter.toUpperCase(),
                style: _WinChatText.title(
                  12,
                  color: _WinChatColors.greenDark,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .76,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 10),
                decoration: BoxDecoration(
                  color: _WinChatColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Переслать сообщение',
                            style: _WinChatText.title(15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Кому отправить?',
                            style: AppTypography.secondary(
                              color: _WinChatColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: _WinChatColors.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _q,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Поиск: имя, фамилия или email',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _WinChatColors.green,
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: AppTypography.secondary(
                                color: _WinChatColors.red,
                              ),
                            ),
                          )
                        : _items.isEmpty
                            ? Center(
                                child: Text(
                                  'Пользователи не найдены',
                                  style: AppTypography.secondary(
                                    color: _WinChatColors.muted,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 4),
                                itemBuilder: (_, index) {
                                  final user = _items[index];
                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () =>
                                          Navigator.pop(context, user),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            _avatar(user),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: _WinChatText.body(
                                                      12.2,
                                                      weight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (user.subtitle.isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 2),
                                                      child: Text(
                                                        user.subtitle,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: AppTypography
                                                            .secondary(
                                                          color: _WinChatColors
                                                              .muted,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: _WinChatColors.muted,
                                            ),
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
      ),
    );
  }
}
