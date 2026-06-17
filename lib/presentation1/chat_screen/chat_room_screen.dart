// lib/presentation/chat_screen/chat_room_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mime/mime.dart';
import 'package:shimmer/shimmer.dart';

import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';
import 'package:sportoteka/presentation/chat_screen/edit_group_chat_screen.dart';
import 'package:sportoteka/call/audio_call_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final int chatId;
  final int userId;
  final String chatName;

  /// Когда чат открыт внутри CMR/workspace, убираем поведение отдельного экрана.
  final bool embedded;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.userId,
    required this.chatName,
    this.embedded = false,
  });

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

  String _excerptFromMsg(Map<String, dynamic> m) {
    final type = (m['type'] ?? '').toString().toLowerCase();
    if (['image', 'photo', 'picture'].contains(type) ||
        (m['file_url'] != null && m['file_url'].toString().isNotEmpty)) {
      return '[Фото]';
    }
    final t = (m['content'] ?? '').toString();
    if (t.isEmpty) return '[Сообщение]';
    return t.length > 80 ? '${t.substring(0, 80)}…' : t;
  }

  // ====================== API ======================

  Future<void> _loadMessages({bool initial = false, bool fromPoll = false}) async {
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
          final newLastId = serverCount > 0 ? (newMessages.last['id'] as int) : 0;

          // Локальные «отправляются»
          final localPending = messages.where((m) => m['_local'] == true).toList();

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
        final decoded = json.decode(
            body.startsWith('{') || body.startsWith('[') ? body : '[]');

        final list = decoded is List
            ? decoded
            : (decoded is Map ? (decoded['members'] ?? decoded['data'] ?? []) : []);

        if (!mounted) return;
        setState(() => members = List<Map<String, dynamic>>.from(
            list.map((e) => Map<String, dynamic>.from(e))));
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

  int _addOptimisticImage(String localPath) {
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
      'type': 'image',
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

  void _replaceTempWithServer(int tempId, {required int newId, String? fileUrl}) {
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
          final newId =
              (data is Map) ? int.tryParse('${data['message_id'] ?? ''}') : null;
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

  Future<void> _sendImage(File file) async {
    final tempId = _addOptimisticImage(file.path);

    try {
      final uri =
          Uri.parse('https://sportotekaapp.ru/api/send_file_message.php');

      final mime = lookupMimeType(file.path) ?? 'image/jpeg';
      final parts = mime.split('/');
      final contentType = MediaType(parts.first, parts.last);

      final req = http.MultipartRequest('POST', uri)
        ..fields['chat_id'] = widget.chatId.toString()
        ..fields['sender_id'] = widget.userId.toString()
        ..fields['user_id'] = widget.userId.toString()
        ..fields['type'] = 'image';

      if (replyingToId != null) {
        req.fields['reply_to_id'] = replyingToId.toString();
      }

      req.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: file.path.split('/').last,
        contentType: contentType,
      ));

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      setState(() {
        replyingToId = null;
        replyingToMessage = null;
      });

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
            _replaceTempWithServer(tempId, newId: newId, fileUrl: absUrl);
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
      _showError('Ошибка отправки изображения: $e');
    }
  }

  // ====================== ЗВОНКИ (Agora) ======================

  Future<String?> _fetchAgoraToken(String channelId, int uid) async {
    try {
      final uri = Uri.parse(
        'https://sportotekaapp.ru/api/get_agora_token.php?channel=$channelId&uid=$uid',
      );
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final t = data['token'];
        if (t is String) return t;
      } else {
        _showError('Ошибка токена (${res.statusCode})');
      }
    } catch (e) {
      _showError('Сеть: не удалось получить токен');
    }
    return null;
  }

  Future<int?> _createCallOnServer({
    required int calleeId,
    required String channelId,
    required String token,
  }) async {
    final resp = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/calls/create.php'),
      body: {
        'caller_id': widget.userId.toString(),
        'callee_id': calleeId.toString(),
        'channel_id': channelId,
        'token': token,
      },
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return int.tryParse('${data['call_id']}');
    }
    return null;
  }

  Future<void> _startAudioCallTo(int calleeId) async {
    final channelId = 'chat_${widget.chatId}_${widget.userId}_$calleeId';
    final token = await _fetchAgoraToken(channelId, widget.userId);
    if (token == null || token.isEmpty) {
      _showError('Не удалось получить токен');
      return;
    }

    final callId = await _createCallOnServer(
      calleeId: calleeId,
      channelId: channelId,
      token: token,
    );
    if (callId == null) {
      _showError('Не удалось инициировать вызов');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioCallScreen(
          channelId: channelId,
          uid: widget.userId,
          token: token,
        ),
      ),
    );
  }

  Future<void> _startAudioCall() async {
    final channelId = 'chat_${widget.chatId}';
    final myUid = widget.userId;

    final token = await _fetchAgoraToken(channelId, myUid);
    if (token == null || token.isEmpty) {
      _showError('Не удалось получить токен Agora (Certificate включён).');
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioCallScreen(
          channelId: channelId,
          uid: myUid,
          token: token,
        ),
      ),
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
        final id =
            (m['id'] is int) ? m['id'] as int : int.tryParse(m['id'].toString()) ?? 0;
        final type = (m['type'] ?? '').toString().toLowerCase();
        final content = (m['content'] ?? '').toString().toLowerCase();
        final name =
            ('${m['first_name'] ?? ''} ${m['last_name'] ?? ''}').toString().toLowerCase();

        final textMatch = (type != 'image' && content.contains(q));
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
        style: base.copyWith(backgroundColor: Colors.yellowAccent.withOpacity(0.6)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(preview, style: const TextStyle(color: Colors.black54, fontSize: 12)),
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
            icon: const Icon(Icons.close, size: 18),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(left: BorderSide(color: Colors.amber.shade400, width: 3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              preview.isEmpty ? 'Редактирование сообщения' : 'Редактирование: $preview',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: 'Отменить',
            onPressed: () => setState(() => editingMessageId = null),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  // ====================== Message Menus ======================

  void _startReply(Map<String, dynamic> msg) {
    setState(() {
      final id = (msg['id'] is int) ? msg['id'] : int.tryParse(msg['id'].toString());
      replyingToId = id;
      replyingToMessage = msg;
      editingMessageId = null;
    });
    _inputFocus.requestFocus();
  }

  void _startEdit(Map<String, dynamic> msg) {
    _controller.text = (msg['content'] ?? '').toString();
    setState(() {
      final id = (msg['id'] is int) ? msg['id'] : int.tryParse(msg['id'].toString());
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
                    Uri.parse('https://sportotekaapp.ru/api/delete_message.php'),
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
                Clipboard.setData(ClipboardData(text: (msg['content'] ?? '').toString()));
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
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine)
            CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              radius: 18,
            ),
          const SizedBox(width: 8),
          Container(
            width: 120 + (index % 3) * 60,
            height: 30 + (index % 2) * 18,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _replyBubblePreview(Map<String, dynamic> msg) {
    final reply = (msg['reply'] is Map) ? Map<String, dynamic>.from(msg['reply']) : null;
    final replyId = (reply?['id'] ?? msg['reply_to_id']);
    if (replyId == null) return const SizedBox.shrink();

    final replyAuthor = (reply?['sender_name']) ??
        '${msg['reply_first_name'] ?? ''} ${msg['reply_last_name'] ?? ''}'.trim();

    final replyType = (reply?['type'] ?? msg['reply_type'] ?? '').toString().toLowerCase();
    final replyContent = (reply?['content'] ?? msg['reply_content'] ?? '').toString();

    final hasImage =
        ((reply?['file_url'] ?? msg['reply_file_url']) ?? '').toString().isNotEmpty ||
            ['image', 'photo', 'picture'].contains(replyType);

    final text = hasImage ? '[Фото]' : (replyContent.isEmpty ? '[Сообщение]' : replyContent);
    final preview = text.length > 80 ? '${text.substring(0, 80)}…' : text;

    return InkWell(
      onTap: () {
        final idInt = (replyId is int) ? replyId : int.tryParse(replyId.toString());
        if (idInt != null) _scrollToMessageId(idInt);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border(left: BorderSide(color: Colors.blue.shade300, width: 3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((replyAuthor ?? '').toString().isNotEmpty)
              Text(
                (replyAuthor ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            const SizedBox(height: 2),
            Text(
              preview,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, {bool showAvatarAndName = true}) {
    final isMine = msg['sender_id'] == widget.userId;
    final isDeleted = _asBool(msg['is_deleted']);

    final senderName = '${msg['first_name']} ${msg['last_name']}';
    final messageDate = _safeParseDate(msg['created_at']).toLocal();
    final isEdited = (msg['updated_at'] != null && msg['updated_at'].toString().isNotEmpty);

    final id = (msg['id'] is int) ? msg['id'] as int : int.tryParse(msg['id'].toString()) ?? 0;
    final key = _messageKeys.putIfAbsent(id, () => GlobalKey());
    final heroTag = 'img_$id';

    final isLocalSending = msg['_local'] == true && (msg['_status'] == 'sending');

    return Container(
      key: key,
      child: InkWell(
        onLongPress: () => _showMessageMenu(context, msg),
        splashColor: isMine ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMine && showAvatarAndName)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyProfileScreen(userId: msg['sender_id']),
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          msg['avatar_url'] != null ? NetworkImage(msg['avatar_url']) : null,
                      backgroundColor: const Color(0xFF1E74C4),
                      child: msg['avatar_url'] == null
                          ? Text(
                              (msg['first_name'] ?? 'U').toString().substring(0, 1),
                              style: const TextStyle(color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                ),
              Flexible(
                child: Column(
                  crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMine && showAvatarAndName)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          senderName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E74C4),
                          ),
                        ),
                      ),
                    Stack(
                      children: [
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMine ? const Color(0xFFE3F2FD) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if ((msg['reply_to_id'] ?? msg['reply']) != null)
                                _replyBubblePreview(msg),

                              if (isDeleted)
                                const Text(
                                  'Сообщение удалено',
                                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                )
                              else ...() {
                                final type = (msg['type'] ?? '').toString().toLowerCase();
                                final fileUrl = _resolveUrl(
                                  (msg['file_url'] ??
                                          msg['image_url'] ??
                                          msg['url'] ??
                                          msg['path'])
                                      ?.toString(),
                                );
                                final text = (msg['content'] ?? '').toString();

                                if ((['image', 'file', 'photo', 'picture'].contains(type)) &&
                                    (msg['local_path'] ?? '').toString().isNotEmpty) {
                                  return [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => _FullImageLocalScreen(
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

                                if ((['image', 'file', 'photo', 'picture'].contains(type)) &&
                                    fileUrl.isNotEmpty) {
                                  return [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => _FullImageScreen(
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
                                                const Text('Ошибка загрузки изображения'),
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
                                              builder: (_) => _FullImageScreen(
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
                                            errorBuilder: (_, __, ___) => Text(
                                              text,
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  ];
                                } else {
                                  final style = const TextStyle(fontSize: 16);
                                  if (searchQuery.isNotEmpty &&
                                      text.toLowerCase().contains(searchQuery.toLowerCase())) {
                                    return [_highlightedText(text, searchQuery, style)];
                                  }
                                  return [Text(text, style: style)];
                                }
                              }(),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat.Hm().format(messageDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isMine
                                          ? Colors.blueGrey.shade300
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  if (isEdited)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Text(
                                        '· изменено',
                                        style: TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ),
                                  if (isMine)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.done_all,
                                        size: 16,
                                        color: msg['is_read'] == 1 ? Colors.blue : Colors.grey,
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
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
        title: searchMode
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Поиск по чату…',
                  border: InputBorder.none,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (members.isNotEmpty)
                    Text(
                      '${members.length} участников',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
        actions: [
          if (searchMode) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  searchHits.isEmpty
                      ? '0/0'
                      : '${(currentHit >= 0 ? currentHit + 1 : 0)}/${searchHits.length}',
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Предыдущее',
              icon: const Icon(Icons.keyboard_arrow_up, color: Colors.black),
              onPressed: searchHits.isEmpty ? null : _prevHit,
            ),
            IconButton(
              tooltip: 'Следующее',
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
              onPressed: searchHits.isEmpty ? null : _nextHit,
            ),
            IconButton(
              tooltip: 'Закрыть поиск',
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: _toggleSearch,
            ),
          ] else ...[
            IconButton(
              tooltip: 'Поиск',
              icon: const Icon(Icons.search, color: Colors.black),
              onPressed: _toggleSearch,
            ),
            IconButton(
              tooltip: 'Аудиозвонок',
              icon: const Icon(Icons.call, color: Colors.black),
              onPressed: _startAudioCall,
            ),
            IconButton(
              icon: const Icon(Icons.group, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditGroupChatScreen(
                      chatId: widget.chatId,
                      currentUserId: widget.userId,
                      chatName: widget.chatName,
                    ),
                  ),
                ).then((_) => _loadMembers());
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _buildEditChip(),
          _buildReplyChip(),
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: Colors.white,
                  child: isLoading
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: 10,
                            itemBuilder: (context, index) => _buildSkeletonMessage(index),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          addAutomaticKeepAlives: true,
                          addRepaintBoundaries: true,
                          cacheExtent: 1000,
                          itemBuilder: (context, index) {
                            final currentMessage = messages[index];

                            final currentDate =
                                _safeParseDate(currentMessage['created_at']).toLocal();
                            final previousMessage =
                                index > 0 ? messages[index - 1] : null;
                            final prevDate = previousMessage != null
                                ? _safeParseDate(previousMessage['created_at']).toLocal()
                                : null;

                            final isSameUser = previousMessage != null &&
                                previousMessage['sender_id'] == currentMessage['sender_id'];

                            final messageWidget = _buildMessage(
                              currentMessage,
                              showAvatarAndName: !isSameUser,
                            );

                            if (prevDate == null ||
                                !DateUtils.isSameDay(currentDate, prevDate)) {
                              return Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      DateFormat.yMMMMd('ru_RU').format(currentDate),
                                      style: TextStyle(
                                          color: Colors.grey.shade600, fontSize: 12),
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
                  bottom: 20,
                  right: 20,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _showScrollToBottomVN,
                    builder: (_, visible, __) {
                      return AnimatedOpacity(
                        opacity: visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: FloatingActionButton.small(
                          backgroundColor: Colors.blue,
                          onPressed: _scrollToBottom,
                          child: const Icon(Icons.arrow_downward, size: 20),
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
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              focusNode: _inputFocus,
                              controller: _controller,
                              decoration: InputDecoration(
                                hintText: editingMessageId != null
                                    ? 'Изменить сообщение…'
                                    : (replyingToId != null ? 'Ответить…' : 'Написать сообщение…'),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (v) =>
                                  setState(() => isTyping = v.trim().isNotEmpty),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          if (isTyping)
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.blue),
                              onPressed: _sendMessage,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!isTyping)
                    GestureDetector(
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressEnd: (_) => _stopRecording(),
                      child: IconButton(
                        icon: Icon(isRecording ? Icons.mic_off : Icons.mic),
                        color: isRecording ? Colors.red : Colors.grey,
                        onPressed: () {},
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

// ====================== Fullscreen Image ======================

class _FullImageScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  const _FullImageScreen({super.key, required this.imageUrl, required this.heroTag});

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
  const _FullImageLocalScreen({super.key, required this.file, required this.heroTag});

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