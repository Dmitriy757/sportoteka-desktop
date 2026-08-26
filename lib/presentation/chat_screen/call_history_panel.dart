// lib/presentation/chat_screen/call_history_panel.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/call/audio_call_screen.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';

class CallHistoryPanel extends StatefulWidget {
  final int userId;

  const CallHistoryPanel({
    super.key,
    required this.userId,
  });

  @override
  State<CallHistoryPanel> createState() => _CallHistoryPanelState();
}

class _CallHistoryPanelState extends State<CallHistoryPanel> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _listUrl = '$_apiBase/calls/list.php';
  static const String _createCallUrl = '$_apiBase/calls/create.php';
  static const String _createChatUrl = '$_apiBase/create_chat.php';

  List<Map<String, dynamic>> _calls = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _asInt(dynamic value) => int.tryParse((value ?? '').toString()) ?? 0;

  String _clean(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  dynamic _decode(String body) {
    var raw = body.trimLeft();
    if (raw.isNotEmpty && raw.codeUnitAt(0) == 0xFEFF) {
      raw = raw.substring(1);
    }
    final obj = raw.indexOf('{');
    final arr = raw.indexOf('[');
    final starts = <int>[obj, arr].where((e) => e >= 0).toList();
    if (starts.isNotEmpty) {
      starts.sort();
      if (starts.first > 0) raw = raw.substring(starts.first);
    }
    return jsonDecode(raw);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    Map<String, dynamic>? payload;
    String debugReason = '';

    Future<Map<String, dynamic>?> readResponse(http.Response response) async {
      try {
        final decoded = _decode(response.body);
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            decoded is Map &&
            decoded['success'] == true) {
          return Map<String, dynamic>.from(decoded);
        }

        if (decoded is Map) {
          debugReason =
              'HTTP ${response.statusCode}: ${decoded['error'] ?? decoded['message'] ?? 'unknown_error'}';
        } else {
          debugReason = 'HTTP ${response.statusCode}';
        }
      } catch (e) {
        debugReason = 'decode_error: $e';
      }
      return null;
    }

    try {
      // Основной вариант — GET.
      try {
        final uri = Uri.parse(
          '$_listUrl?user_id=${widget.userId}&limit=100',
        );
        final response =
            await http.get(uri).timeout(const Duration(seconds: 12));
        payload = await readResponse(response);
      } catch (e) {
        debugReason = 'GET: $e';
      }

      // Fallback на POST: endpoint v2 принимает оба способа.
      if (payload == null) {
        try {
          final response = await http.post(
            Uri.parse(_listUrl),
            body: {
              'user_id': widget.userId.toString(),
              'limit': '100',
            },
          ).timeout(const Duration(seconds: 12));
          payload = await readResponse(response);
        } catch (e) {
          debugReason = 'POST: $e';
        }
      }

      if (payload == null) {
        throw Exception(
            debugReason.isEmpty ? 'history_api_failed' : debugReason);
      }

      final raw = payload!['calls'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _calls = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CALL HISTORY LOAD ERROR: $e');
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить историю звонков';
      });
    }
  }

  String _peerName(Map<String, dynamic> call) {
    final name = _clean(call['peer_name']);
    if (name.isNotEmpty) return name;

    final id = _asInt(call['peer_id']);
    return id > 0 ? 'Пользователь #$id' : 'Пользователь';
  }

  String _peerPhoto(Map<String, dynamic> call) {
    final raw = _clean(call['peer_photo']);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/')) {
      return 'https://sportotekaapp.ru$raw';
    }
    return 'https://sportotekaapp.ru/uploads/$raw';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();

    if (parts.isEmpty) return 'С';
    return parts.map((e) => e.substring(0, 1).toUpperCase()).join();
  }

  bool _incoming(Map<String, dynamic> call) =>
      _clean(call['direction']).toLowerCase() == 'incoming';

  String _status(Map<String, dynamic> call) {
    final status = _clean(call['status']).toLowerCase();
    final incoming = _incoming(call);

    switch (status) {
      case 'accepted':
        return incoming ? 'Входящий · принят' : 'Исходящий · принят';
      case 'ended':
        return incoming ? 'Входящий · завершён' : 'Исходящий · завершён';
      case 'missed':
        return incoming ? 'Пропущенный' : 'Без ответа';
      case 'declined':
        return incoming ? 'Отклонён' : 'Не принят';
      case 'canceled':
      case 'cancelled':
        return incoming ? 'Пропущенный' : 'Отменён';
      case 'ringing':
        return incoming ? 'Пропущенный' : 'Без ответа';
      default:
        return incoming ? 'Входящий звонок' : 'Исходящий звонок';
    }
  }

  bool _isMissed(Map<String, dynamic> call) {
    final status = _clean(call['status']).toLowerCase();
    return _incoming(call) &&
        <String>{'missed', 'declined', 'canceled', 'cancelled', 'ringing'}
            .contains(status);
  }

  bool _sameCalendarDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _callDate(Map<String, dynamic> call) {
    return _parseDate(call['created_at']) ??
        _parseDate(call['started_at']) ??
        _parseDate(call['updated_at']);
  }

  List<Map<String, dynamic>> _groupCalls(
    List<Map<String, dynamic>> source,
  ) {
    final grouped = <Map<String, dynamic>>[];

    for (final raw in source) {
      final call = Map<String, dynamic>.from(raw);
      final peerId = _asInt(call['peer_id']);
      final callDate = _callDate(call);

      if (grouped.isNotEmpty) {
        final last = grouped.last;
        final lastPeer = _asInt(last['peer_id']);
        final lastDate = _callDate(last);

        if (peerId > 0 &&
            peerId == lastPeer &&
            _sameCalendarDay(callDate, lastDate)) {
          final count = _asInt(last['_group_count']);
          last['_group_count'] = count <= 0 ? 2 : count + 1;

          final ids = (last['_group_call_ids'] is List)
              ? List<int>.from(
                  (last['_group_call_ids'] as List)
                      .map((e) => _asInt(e))
                      .where((e) => e > 0),
                )
              : <int>[_asInt(last['id'])];
          final id = _asInt(call['id']);
          if (id > 0) ids.add(id);
          last['_group_call_ids'] = ids;

          // Если в пачке есть пропущенный вызов, сохраняем этот факт,
          // но основной статус/время оставляем от самого свежего звонка.
          if (_isMissed(call)) last['_group_has_missed'] = true;
          continue;
        }
      }

      call['_group_count'] = 1;
      call['_group_call_ids'] = <int>[
        if (_asInt(call['id']) > 0) _asInt(call['id']),
      ];
      call['_group_has_missed'] = _isMissed(call);
      grouped.add(call);
    }

    return grouped;
  }

  String _callCountText(int count) {
    if (count <= 1) return '';
    final mod10 = count % 10;
    final mod100 = count % 100;
    final word = (mod10 == 1 && mod100 != 11)
        ? 'звонок'
        : (mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14))
            ? 'звонка'
            : 'звонков';
    return '$count $word';
  }

  String _durationLabel(Map<String, dynamic> call) {
    final seconds = _asInt(call['duration_seconds']);
    if (seconds <= 0) return '';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')}';
  }

  String _statusLine(Map<String, dynamic> call) {
    final parts = <String>[_status(call)];
    final duration = _durationLabel(call);
    if (duration.isNotEmpty) parts.add(duration);
    final countText = _callCountText(_asInt(call['_group_count']));
    if (countText.isNotEmpty) parts.add(countText);
    return parts.join(' · ');
  }

  IconData _directionIcon(Map<String, dynamic> call) {
    if (_isMissed(call)) return Icons.phone_missed_rounded;
    return _incoming(call)
        ? Icons.call_received_rounded
        : Icons.call_made_rounded;
  }

  Color _directionColor(Map<String, dynamic> call) {
    if (_isMissed(call)) return const Color(0xFFD92D20);
    return const Color(0xFF067A46);
  }

  DateTime? _parseDate(dynamic value) {
    final raw = _clean(value);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(
      raw.contains('T') ? raw : raw.replaceFirst(' ', 'T'),
    )?.toLocal();
  }

  String _time(Map<String, dynamic> call) {
    final dt = _parseDate(call['created_at']) ??
        _parseDate(call['started_at']) ??
        _parseDate(call['updated_at']);

    if (dt == null) return '';

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');

    if (now.year == dt.year && now.month == dt.month && now.day == dt.day) {
      return '${two(dt.hour)}:${two(dt.minute)}';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == dt.year &&
        yesterday.month == dt.month &&
        yesterday.day == dt.day) {
      return 'Вчера · ${two(dt.hour)}:${two(dt.minute)}';
    }

    return '${two(dt.day)}.${two(dt.month)} · '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _startCall(Map<String, dynamic> call) async {
    final peerId = _asInt(call['peer_id']);
    if (peerId <= 0 || peerId == widget.userId || _actionBusy) return;

    setState(() => _actionBusy = true);

    try {
      final channelId =
          'history_${widget.userId}_${peerId}_${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.post(
        Uri.parse(_createCallUrl),
        body: {
          'caller_id': widget.userId.toString(),
          'callee_id': peerId.toString(),
          'channel_id': channelId,
        },
      ).timeout(const Duration(seconds: 12));

      final data = _decode(response.body);
      final callId = data is Map ? _asInt(data['call_id']) : 0;
      final ok = response.statusCode == 200 &&
          data is Map &&
          data['status'] == 'ok' &&
          callId > 0;

      if (!ok) {
        _toast('Не удалось начать звонок');
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AudioCallScreen(
            callId: callId,
            userId: widget.userId,
            isCaller: true,
            peerName: _peerName(call),
          ),
        ),
      );

      await _load();
    } catch (_) {
      _toast('Ошибка соединения при запуске звонка');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openChat(Map<String, dynamic> call) async {
    final peerId = _asInt(call['peer_id']);
    if (peerId <= 0 || peerId == widget.userId || _actionBusy) return;

    setState(() => _actionBusy = true);

    try {
      final response = await http.post(
        Uri.parse(_createChatUrl),
        body: {
          'type': 'private',
          'user_id': widget.userId.toString(),
          'peer_id': peerId.toString(),
        },
      ).timeout(const Duration(seconds: 12));

      final data = _decode(response.body);
      final chatId = data is Map ? _asInt(data['chat_id']) : 0;
      final ok = response.statusCode == 200 &&
          data is Map &&
          data['success'] == true &&
          chatId > 0;

      if (!ok) {
        _toast('Не удалось открыть чат');
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatRoomScreen(
            chatId: chatId,
            userId: widget.userId,
            chatName: _peerName(call),
          ),
        ),
      );
    } catch (_) {
      _toast('Ошибка соединения при открытии чата');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _openContact(Map<String, dynamic> call) async {
    final peerName = _peerName(call);
    final photo = _peerPhoto(call);
    final status = _statusLine(call);
    final time = _time(call);

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.18),
      builder: (dialogContext) {
        final width = MediaQuery.sizeOf(dialogContext).width;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: width < 520 ? 14 : 28,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.08),
                    blurRadius: 28,
                    spreadRadius: -12,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const _CallDots(compact: true),
                      const Spacer(),
                      Material(
                        color: const Color(0xFFF6F8F7),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(dialogContext).pop(),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _CallAvatar(
                    url: photo,
                    initials: _initials(peerName),
                    size: 72,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    peerName,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: _CallText.title(16),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [status, if (time.isNotEmpty) time].join(' · '),
                    textAlign: TextAlign.center,
                    style: _CallText.muted(10.8),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _CallActionButton(
                          icon: Icons.call_rounded,
                          label: 'Позвонить',
                          primary: true,
                          onTap: _actionBusy ? null : () => _startCall(call),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CallActionButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Написать',
                          onTap: _actionBusy ? null : () => _openChat(call),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF00A750),
        ),
      );
    }

    if (_error != null) {
      return _CallEmpty(
        icon: Icons.cloud_off_rounded,
        title: 'История недоступна',
        subtitle: _error!,
        action: _load,
      );
    }

    if (_calls.isEmpty) {
      return const _CallEmpty(
        icon: Icons.call_outlined,
        title: 'Звонков пока нет',
        subtitle: 'Здесь появятся входящие, исходящие и пропущенные звонки.',
      );
    }

    final displayCalls = _groupCalls(_calls);

    return RefreshIndicator(
      color: const Color(0xFF00A750),
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 24),
        itemCount: displayCalls.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, index) {
          final call = displayCalls[index];
          final name = _peerName(call);
          final photo = _peerPhoto(call);
          final status = _statusLine(call);
          final time = _time(call);
          final tone = _directionColor(call);

          return Material(
            color:
                _isMissed(call) ? const Color(0xFFFFF7F6) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openContact(call),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _CallAvatar(
                      url: photo,
                      initials: _initials(name),
                      size: 42,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CallText.title(11.8),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                _directionIcon(call),
                                size: 13,
                                color: tone,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _CallText.muted(
                                    9.8,
                                    color: _isMissed(call)
                                        ? const Color(0xFFD92D20)
                                        : const Color(0xFF667085),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: _CallText.muted(
                          8.9,
                          color: const Color(0xFF98A2B3),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3FAF6),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 17,
                        color: Color(0xFF067A46),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CallAvatar extends StatelessWidget {
  final String url;
  final String initials;
  final double size;

  const _CallAvatar({
    required this.url,
    required this.initials,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF6),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: _CallText.title(
          size >= 60 ? 16 : 11,
          color: const Color(0xFF067A46),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback? onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? const Color(0xFF00A750) : const Color(0xFFF6F8F7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: primary ? Colors.white : const Color(0xFF111827),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: _CallText.action(
                  color: primary ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? action;

  const _CallEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3FAF6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: const Color(0xFF00A750),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: _CallText.title(15),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: _CallText.muted(10.8),
              ),
              if (action != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: action,
                  child: Text(
                    'Повторить',
                    style: _CallText.action(),
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

class _CallDots extends StatelessWidget {
  final bool compact;

  const _CallDots({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scale = compact ? .8 : 1.0;
    const color = Color(0xFF00A750);
    const values = <double>[.30, .48, .72, 1];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(values.length, (index) {
        final size = (3.4 + index) * scale;
        return Padding(
          padding: EdgeInsets.only(right: index == values.length - 1 ? 0 : 3),
          child: Opacity(
            opacity: values[index],
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CallText {
  static TextStyle title(
    double size, {
    Color color = const Color(0xFF0B0F14),
  }) =>
      AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: color,
        height: 1.18,
      );

  static TextStyle muted(
    double size, {
    Color color = const Color(0xFF667085),
  }) =>
      AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: color,
        height: 1.25,
      );

  static TextStyle action({
    Color color = const Color(0xFF067A46),
  }) =>
      AppTypography.custom(
        size: 11.1,
        weight: FontWeight.w600,
        color: color,
        height: 1.1,
      );
}
