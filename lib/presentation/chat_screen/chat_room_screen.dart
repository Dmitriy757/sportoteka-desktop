// lib/presentation/chat_screen/chat_room_screen.dart
// Windows 11 / Fluent refresh based on CMR workspace typography.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mime/mime.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';
import 'package:sportoteka/presentation/chat_screen/edit_group_chat_screen.dart';
import 'package:sportoteka/call/audio_call_screen.dart';

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
  final String chatName;

  /// Когда чат открыт внутри CMR/workspace, убираем поведение отдельного экрана.
  final bool embedded;

  const ChatRoomScreen({
    Key? key,
    required this.chatId,
    required this.userId,
    required this.chatName,
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

  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late String _chatTitle;

  // Сообщения/участники
  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> members = [];

  // Индексы и состояния
  bool isLoading = true;
  Timer? _refreshTimer;

  bool isTyping = false;
  int? editingMessageId; // ID редактируемого сообщения
  int lastMessageId = 0;

  bool isRecording = false;

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
  bool _didInitialAutoScroll = false;
  bool _initialDataLoaded = false;
  int _netErrorStreak = 0;

  // ✅ Scroll-to-bottom без setState на каждый пиксель
  final ValueNotifier<bool> _showScrollToBottomVN = ValueNotifier<bool>(false);
  bool _lastShowScroll = false;
  Timer? _scrollThrottle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    initializeDateFormatting('ru_RU');
    _chatTitle = _normalizeChatTitle(widget.chatName);

    // ✅ ВАЖНО: помечаем чат как прочитанный на сервере при входе
    _markThisChatRead();

    _loadMessages(initial: true);
    _loadMembers();
    _startPolling();

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;

      // throttle чтобы не дергать UI на каждый пиксель
      if (_scrollThrottle?.isActive ?? false) return;
      _scrollThrottle = Timer(const Duration(milliseconds: 70), () {
        if (!_scrollController.hasClients) return;
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
      _loadMessages(fromPoll: true);

      // ✅ на всякий случай при возврате в чат
      _markThisChatRead();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
    }
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer =
        Timer.periodic(pollInterval, (_) => _loadMessages(fromPoll: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _refreshTimer?.cancel();
    _searchDebounce?.cancel();
    _scrollThrottle?.cancel();

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
    if (raw == null || raw.isEmpty) return '';
    raw = raw.replaceAll('\\', '/').trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://sportotekaapp.ru${raw.startsWith('/') ? '' : '/'}$raw';
  }

  bool _looksLikeImageUrl(String s) {
    final low = s.toLowerCase();
    return low.startsWith('http') &&
        (low.endsWith('.jpg') ||
            low.endsWith('.jpeg') ||
            low.endsWith('.png') ||
            low.endsWith('.gif') ||
            low.contains('=image'));
  }

  bool _isVideoType(String type, [String url = '']) {
    final t = type.toLowerCase().trim();
    final u = url.toLowerCase();
    return t == 'video' ||
        u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.m4v') ||
        u.endsWith('.webm');
  }

  bool _isImageType(String type, [String url = '']) {
    final t = type.toLowerCase().trim();
    final u = url.toLowerCase();
    return ['image', 'photo', 'picture'].contains(t) ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.png') ||
        u.endsWith('.gif') ||
        u.endsWith('.webp');
  }

  String _excerptFromMsg(Map<String, dynamic> m) {
    final type = (m['type'] ?? '').toString().toLowerCase();
    final fileUrl = (m['file_url'] ?? '').toString();

    if (_isVideoType(type, fileUrl)) return '[Видео]';
    if (_isImageType(type, fileUrl)) return '[Фото]';

    final t = (m['content'] ?? '').toString();
    if (t.isEmpty) {
      if (fileUrl.isNotEmpty) return '[Файл]';
      return '[Сообщение]';
    }
    return t.length > 80 ? '${t.substring(0, 80)}…' : t;
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
    final raw = (member['photo'] ??
            member['photo_url'] ??
            member['avatar'] ??
            member['avatar_url'] ??
            '')
        .toString()
        .trim();

    if (raw.isEmpty || raw.toLowerCase() == 'null') {
      return '';
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    if (raw.startsWith('/')) {
      return 'https://sportotekaapp.ru$raw';
    }

    return 'https://sportotekaapp.ru/uploads/$raw';
  }

  String get _peerPhoto {
    for (final member in members) {
      final id = _memberUserId(member);
      if (id > 0 && id != widget.userId) {
        return _memberPhoto(member);
      }
    }
    return '';
  }

  void _refreshTitleFromMembers() {
    if (!_isGenericChatTitle(_chatTitle)) return;

    final otherMembers = members.where((member) {
      final id = int.tryParse(
              '${member['id'] ?? member['user_id'] ?? member['userId'] ?? 0}') ??
          0;
      return id != widget.userId;
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

          // Приведение типов
          for (final m in newMessages) {
            final rawId = m['id'];
            if (rawId is! int) m['id'] = int.tryParse(rawId.toString()) ?? 0;

            final rawSender = m['sender_id'];
            if (rawSender is! int) {
              m['sender_id'] = int.tryParse(rawSender.toString()) ?? 0;
            }

            final rawReply = m['reply_to_id'];
            if (rawReply != null && rawReply is! int) {
              m['reply_to_id'] = int.tryParse(rawReply.toString());
            }
          }

          final serverCount = newMessages.length;
          final newLastId =
              serverCount > 0 ? (newMessages.last['id'] as int) : 0;

          // Локальные «отправляются»
          final localPending =
              messages.where((m) => m['_local'] == true).toList();

          final hasServerChange =
              (newLastId != lastMessageId) || (serverCount != _prevServerCount);

          if (hasServerChange) {
            if (mounted) {
              setState(() {
                messages = [...newMessages, ...localPending];
                lastMessageId = newLastId;
                _prevServerCount = serverCount;
              });
            }

            // ✅ как только увидели апдейт — считаем чат прочитанным
            // (убирает верхний баннер "непрочитанных" из get_unread_total.php)
            _markThisChatRead();

            if (initial && !_didInitialAutoScroll) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom(jump: true);
                _didInitialAutoScroll = true;
              });
            } else if (_isNearBottom()) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());
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

  Future<void> _loadMembers() async {
    try {
      final uri = Uri.parse(
          'https://sportotekaapp.ru/api/get_chat_members.php?chat_id=${widget.chatId}');
      final res = await http.get(uri, headers: {'Accept': 'application/json'});
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
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    Map<String, dynamic>? replyObj;
    if (replyingToMessage != null) {
      replyObj = {
        'id': replyingToMessage!['id'],
        'content': (replyingToMessage!['content'] ?? '').toString(),
        'type': (replyingToMessage!['type'] ?? '').toString(),
        'file_url': replyingToMessage!['file_url'],
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
      '_status': 'sending',
    };

    setState(() {
      messages.add(optimistic);
    });
    if (_isNearBottom()) _scrollToBottom();
    return tempId;
  }

  int _addOptimisticMedia(
    String localPath, {
    required String type,
  }) {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    Map<String, dynamic>? replyObj;
    if (replyingToMessage != null) {
      replyObj = {
        'id': replyingToMessage!['id'],
        'content': (replyingToMessage!['content'] ?? '').toString(),
        'type': (replyingToMessage!['type'] ?? '').toString(),
        'file_url': replyingToMessage!['file_url'],
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
      'content': '',
      'created_at': nowIso,
      'type': type,
      'file_url': null,
      'local_path': localPath,
      'is_deleted': 0,
      'updated_at': null,
      'reply_to_id': replyingToId,
      if (replyObj != null) 'reply': replyObj,
      '_local': true,
      '_status': 'sending',
    };

    setState(() {
      messages.add(optimistic);
    });
    if (_isNearBottom()) _scrollToBottom();
    return tempId;
  }

  int _addOptimisticImage(String localPath) {
    return _addOptimisticMedia(localPath, type: 'image');
  }

  int _addOptimisticVideo(String localPath) {
    return _addOptimisticMedia(localPath, type: 'video');
  }

  void _replaceTempWithServer(int tempId,
      {required int newId, String? fileUrl}) {
    final idx = messages.indexWhere((m) => m['id'] == tempId);
    if (idx == -1) return;

    final updated = Map<String, dynamic>.from(messages[idx]);
    updated['id'] = newId;
    updated['_local'] = null;
    updated['_status'] = null;
    if (fileUrl != null) {
      updated['file_url'] = fileUrl;
      updated.remove('local_path');
    }

    setState(() {
      messages[idx] = updated;
    });
  }

  void _removeTemp(int tempId) {
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
          Uri.parse('https://sportotekaapp.ru/api/send_message.php'),
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
                    title: 'Фото',
                    subtitle: 'Выбрать изображение',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickImage();
                    },
                  ),
                  const SizedBox(height: 5),
                  _AttachmentAction(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Видео',
                    subtitle: 'MP4, MOV, M4V или WebM',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickVideo();
                    },
                  ),
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
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (picked == null) return;
      await _sendImage(File(picked.path));
    } catch (e) {
      _showError('Не удалось выбрать изображение: $e');
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

    return MediaType('image', 'jpeg');
  }

  Future<void> _sendMedia(
    File file, {
    required String type,
  }) async {
    final tempId = type == 'video'
        ? _addOptimisticVideo(file.path)
        : _addOptimisticImage(file.path);

    try {
      final uri =
          Uri.parse('https://sportotekaapp.ru/api/send_file_message.php');

      final contentType = _mediaTypeForFile(file, type);

      final req = http.MultipartRequest('POST', uri)
        ..fields['chat_id'] = widget.chatId.toString()
        ..fields['sender_id'] = widget.userId.toString()
        ..fields['user_id'] = widget.userId.toString()
        ..fields['type'] = type;

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

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (mounted) {
        setState(() {
          replyingToId = null;
          replyingToMessage = null;
        });
      }

      if (res.statusCode != 200) {
        _removeTemp(tempId);
        _showError('Ошибка загрузки (${res.statusCode}): ${res.body}');
        return;
      }

      try {
        final data = json.decode(res.body);
        final status = '${data['status'] ?? ''}'.toLowerCase();
        final ok = data['success'] == true ||
            status == 'ok' ||
            status == 'success' ||
            status == '200';

        final newId = int.tryParse('${data['message_id'] ?? ''}');
        final absUrl = (data['url'] ?? data['file_url'])?.toString();

        if (ok) {
          if (newId != null) {
            _replaceTempWithServer(
              tempId,
              newId: newId,
              fileUrl: absUrl,
            );
          }
          _loadMessages();
          _markThisChatRead();
        } else {
          _removeTemp(tempId);
          _showError('Сервер вернул ошибку: ${res.body}');
        }
      } catch (_) {
        _loadMessages();
        _markThisChatRead();
      }
    } catch (e) {
      _removeTemp(tempId);
      _showError(
        type == 'video'
            ? 'Ошибка отправки видео: $e'
            : 'Ошибка отправки изображения: $e',
      );
    }
  }

  // ====================== ЗВОНКИ (LiveKit) ======================

  int _memberUserId(Map<String, dynamic> member) {
    return int.tryParse(
          '${member['id'] ?? member['user_id'] ?? member['userId'] ?? 0}',
        ) ??
        0;
  }

  Future<int?> _createCallOnServer({
    required int calleeId,
    required String channelId,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/calls/create.php'),
        body: {
          'caller_id': widget.userId.toString(),
          'callee_id': calleeId.toString(),
          'channel_id': channelId,
        },
      );

      Map<String, dynamic> data = const {};
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      if (resp.statusCode == 200 && data['status'] == 'ok') {
        return int.tryParse('${data['call_id']}');
      }

      final error = (data['error'] ?? 'HTTP ${resp.statusCode}').toString();
      _showError('Не удалось инициировать вызов: $error');
    } catch (e) {
      _showError('Сеть: не удалось инициировать вызов');
    }
    return null;
  }

  Future<void> _startAudioCallTo(int calleeId, {String? peerName}) async {
    if (calleeId <= 0 || calleeId == widget.userId) {
      _showError('Некорректный получатель звонка');
      return;
    }

    final channelId = 'chat_${widget.chatId}_${widget.userId}_$calleeId';
    final callId = await _createCallOnServer(
      calleeId: calleeId,
      channelId: channelId,
    );

    if (callId == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioCallScreen(
          callId: callId,
          userId: widget.userId,
          isCaller: true,
          peerName: peerName,
        ),
      ),
    );
  }

  Future<void> _startAudioCall() async {
    if (members.isEmpty) {
      await _loadMembers();
    }

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

    if (!mounted) return;
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

    if (selectedId == null) return;
    final member = others.firstWhere((m) => _memberUserId(m) == selectedId);
    await _startAudioCallTo(
      selectedId,
      peerName: _memberDisplayName(member),
    );
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

  void _showMessageMenu(BuildContext context, Map<String, dynamic> msg) {
    final isMine = msg['sender_id'] == widget.userId;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Редактировать'),
                onTap: () {
                  Navigator.pop(context);
                  _startEdit(msg);
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Удалить'),
                onTap: () async {
                  Navigator.pop(context);
                  await http.post(
                    Uri.parse(
                        'https://sportotekaapp.ru/api/delete_message.php'),
                    body: {'message_id': msg['id'].toString()},
                  );
                  _loadMessages();
                  _markThisChatRead();
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Ответить'),
              onTap: () {
                Navigator.pop(context);
                _startReply(msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Копировать'),
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: (msg['content'] ?? '').toString()));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Текст скопирован')),
                );
              },
            ),
          ],
        ),
      ),
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
    final reply =
        (msg['reply'] is Map) ? Map<String, dynamic>.from(msg['reply']) : null;
    final replyId = (reply?['id'] ?? msg['reply_to_id']);
    if (replyId == null) return const SizedBox.shrink();

    final replyAuthor = (reply?['sender_name']) ??
        '${msg['reply_first_name'] ?? ''} ${msg['reply_last_name'] ?? ''}'
            .trim();

    final replyType =
        (reply?['type'] ?? msg['reply_type'] ?? '').toString().toLowerCase();
    final replyContent =
        (reply?['content'] ?? msg['reply_content'] ?? '').toString();

    final replyFile =
        ((reply?['file_url'] ?? msg['reply_file_url']) ?? '').toString();

    final hasVideo = _isVideoType(replyType, replyFile);
    final hasImage = _isImageType(replyType, replyFile);

    final text = hasVideo
        ? '[Видео]'
        : hasImage
            ? '[Фото]'
            : (replyContent.isEmpty ? '[Сообщение]' : replyContent);
    final preview = text.length > 80 ? '${text.substring(0, 80)}…' : text;

    return InkWell(
      onTap: () {
        final idInt =
            (replyId is int) ? replyId : int.tryParse(replyId.toString());
        if (idInt != null) _scrollToMessageId(idInt);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _WinChatColors.greenSoft,
          border: const Border(
              left: BorderSide(color: _WinChatColors.green, width: 3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((replyAuthor ?? '').toString().isNotEmpty)
              Text(
                (replyAuthor ?? '').toString(),
                style: AppTypography.commentAuthor(color: _WinChatColors.text),
              ),
            const SizedBox(height: 2),
            Text(
              preview,
              style: AppTypography.secondary(color: _WinChatColors.muted),
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

    final senderName = '${msg['first_name']} ${msg['last_name']}';
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
    final bubbleAccent =
        isMine ? _WinChatColors.green : _messageAccent(senderName.hashCode);
    final bubbleSoft = isMine
        ? _WinChatColors.greenSoft
        : _messageAccentSoft(senderName.hashCode);

    return Container(
      key: key,
      child: InkWell(
        onLongPress: () => _showMessageMenu(context, msg),
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
                          int.tryParse((msg['sender_id'] ?? '').toString());
                      if (senderId == null || senderId <= 0) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MyProfileScreen(userId: senderId),
                        ),
                      );
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: _WinChatColors.greenSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: msg['avatar_url'] != null
                          ? Image.network(
                              msg['avatar_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  (msg['first_name'] ?? 'П')
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: _WinChatText.title(
                                    10.2,
                                    color: _WinChatColors.greenDark,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                (msg['first_name'] ?? 'П')
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
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
                        child: Text(
                          senderName,
                          style: _WinChatText.body(
                            10.0,
                            color: bubbleAccent,
                            weight: FontWeight.w600,
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
                              if ((msg['reply_to_id'] ?? msg['reply']) != null)
                                _replyBubblePreview(msg),
                              if (isDeleted)
                                Text(
                                  'Сообщение удалено',
                                  style: _WinChatText.body(
                                    11.3,
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

                                  if ((['image', 'file', 'photo', 'picture']
                                          .contains(type)) &&
                                      (msg['local_path'] ?? '')
                                          .toString()
                                          .isNotEmpty) {
                                    return [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    _FullImageLocalScreen(
                                                  file: File(msg['local_path']),
                                                  heroTag: heroTag,
                                                ),
                                              ),
                                            );
                                          },
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

                                  if ((['image', 'file', 'photo', 'picture']
                                          .contains(type)) &&
                                      fileUrl.isNotEmpty) {
                                    return [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    _FullImageScreen(
                                                  imageUrl: fileUrl,
                                                  heroTag: heroTag,
                                                ),
                                              ),
                                            );
                                          },
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
                                  } else if (_looksLikeImageUrl(text)) {
                                    final u = _resolveUrl(text);
                                    return [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    _FullImageScreen(
                                                  imageUrl: u,
                                                  heroTag: heroTag,
                                                ),
                                              ),
                                            );
                                          },
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
                                    final style = _WinChatText.body(
                                      11.3,
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
                                      child: Icon(
                                        Icons.done_all,
                                        size: 15,
                                        color: msg['is_read'] == 1
                                            ? _WinChatColors.green
                                            : Colors.grey.shade500,
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
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================== Build ======================

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 520;

    final messagePadding = EdgeInsets.fromLTRB(
      compact ? 7 : 12,
      compact ? 7 : 10,
      compact ? 7 : 12,
      compact ? 9 : 12,
    );

    final peerPhoto = _peerPhoto;

    return Scaffold(
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
              systemOverlayStyle: SystemUiOverlayStyle.dark,
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
                  : Row(
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
                                  errorBuilder: (_, __, ___) => const Center(
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
                                members.length > 2
                                    ? '${members.length} участников'
                                    : 'Личная переписка',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _WinChatText.caption(),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      if (members.length > 2)
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
                compact ? 6 : 9,
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
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 38),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _WinChatColors.soft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: TextField(
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
                            10.8,
                            color: _WinChatColors.muted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 9),
                        ),
                        style: _WinChatText.body(
                          11.3,
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
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressEnd: (_) => _stopRecording(),
                      child: _RoomInputAction(
                        icon: isRecording
                            ? Icons.mic_off_rounded
                            : Icons.mic_none_rounded,
                        color: isRecording
                            ? _WinChatColors.red
                            : _WinChatColors.muted,
                        onTap: () {},
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================== Voice stubs ======================

  void _startRecording() {
    setState(() => isRecording = true);
    // TODO: Реализация начала записи (audio recorder)
  }

  void _stopRecording() {
    setState(() => isRecording = false);
    // TODO: Отправка на сервер (multipart как _sendImage)
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
                    final maxMs =
                        duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
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

// ====================== Fullscreen Image ======================

class _FullImageScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  const _FullImageScreen({
    Key? key,
    required this.imageUrl,
    required this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Hero(
            tag: heroTag,
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _FullImageLocalScreen extends StatelessWidget {
  final File file;
  final String heroTag;
  const _FullImageLocalScreen({
    Key? key,
    required this.file,
    required this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Hero(
            tag: heroTag,
            child: Image.file(file, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
