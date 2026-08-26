// lib/presentation/chat_screen/cmr_notifications_panel.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';

class CmrNotificationsPanel extends StatefulWidget {
  final int userId;
  final VoidCallback? onBack;
  final ValueChanged<int>? onUnreadChanged;
  final void Function(String target, Map<String, dynamic> payload)? onNavigate;

  const CmrNotificationsPanel({
    super.key,
    required this.userId,
    this.onBack,
    this.onUnreadChanged,
    this.onNavigate,
  });

  @override
  State<CmrNotificationsPanel> createState() => _CmrNotificationsPanelState();
}

class _CmrNotificationsPanelState extends State<CmrNotificationsPanel> {
  static const _apiBase = 'https://sportotekaapp.ru/api/notifications';
  static const _listUrl = '$_apiBase/list.php';
  static const _markReadUrl = '$_apiBase/mark_read.php';
  static const _markAllReadUrl = '$_apiBase/mark_all_read.php';

  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  Timer? _timer;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _asInt(dynamic v) => int.tryParse((v ?? '').toString()) ?? 0;

  bool _truthy(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();
    return v == true || v == 1 || s == '1' || s == 'true' || s == 'yes';
  }

  dynamic _decode(String raw) {
    var s = raw.trimLeft();
    if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) {
      s = s.substring(1);
    }
    final obj = s.indexOf('{');
    final arr = s.indexOf('[');
    final starts = <int>[obj, arr].where((e) => e >= 0).toList();
    if (starts.isNotEmpty) {
      starts.sort();
      if (starts.first > 0) s = s.substring(starts.first);
    }
    return jsonDecode(s);
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final uri = Uri.parse(
        '$_listUrl?user_id=${widget.userId}&limit=100',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      final data = _decode(res.body);

      if (res.statusCode != 200 || data is! Map || data['success'] != true) {
        throw Exception(
          data is Map
              ? (data['error'] ?? 'HTTP ${res.statusCode}')
              : 'HTTP ${res.statusCode}',
        );
      }

      final raw = data['items'];
      final items = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final unread = _asInt(data['unread_count']);

      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _unread = unread;
        _loading = false;
        _error = null;
      });
      widget.onUnreadChanged?.call(unread);
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить уведомления';
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = _asInt(item['id']);
    if (id <= 0 || _truthy(item['is_read'])) return;

    try {
      final response = await http.post(
        Uri.parse(_markReadUrl),
        body: {
          'user_id': widget.userId.toString(),
          'notification_id': id.toString(),
        },
      ).timeout(const Duration(seconds: 10));

      final data = _decode(response.body);
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data is Map &&
          data['success'] == true;

      if (!ok) {
        throw Exception(
          data is Map
              ? (data['error'] ?? 'HTTP ${response.statusCode}')
              : 'HTTP ${response.statusCode}',
        );
      }

      item['is_read'] = 1;
      if (_unread > 0) _unread--;
      if (mounted) setState(() {});
      widget.onUnreadChanged?.call(_unread);

      // Подтверждаем итог сервером, чтобы badge нигде не зависал.
      await _load(silent: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NOTIFICATION MARK READ ERROR: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось отметить уведомление прочитанным'),
        ),
      );
    }
  }

  Future<void> _markAllRead() async {
    if (_unread <= 0) return;

    try {
      final response = await http.post(
        Uri.parse(_markAllReadUrl),
        body: {'user_id': widget.userId.toString()},
      ).timeout(const Duration(seconds: 10));

      final data = _decode(response.body);
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data is Map &&
          data['success'] == true;

      if (!ok) {
        throw Exception(
          data is Map
              ? (data['error'] ?? 'HTTP ${response.statusCode}')
              : 'HTTP ${response.statusCode}',
        );
      }

      for (final item in _items) {
        item['is_read'] = 1;
      }
      _unread = 0;
      if (mounted) setState(() {});
      widget.onUnreadChanged?.call(0);

      // Сервер — единственный источник истины.
      await _load(silent: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NOTIFICATION MARK ALL ERROR: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось обновить уведомления'),
        ),
      );
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    await _markRead(item);

    final target = (item['action_target'] ?? '').toString().trim();
    if (target.isEmpty || widget.onNavigate == null) return;

    Map<String, dynamic> payload = <String, dynamic>{};
    final raw = item['action_payload'];

    if (raw is Map) {
      payload = Map<String, dynamic>.from(raw);
    } else if (raw != null && raw.toString().trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw.toString());
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    for (final key in const [
      'player_id',
      'team_id',
      'club_id',
      'event_id',
      'session_id',
      'match_id',
      'test_id',
      'document_id',
    ]) {
      final value = _asInt(item[key]);
      if (value > 0 && !payload.containsKey(key)) {
        payload[key] = value;
      }
    }

    widget.onNavigate!(target, payload);
  }

  IconData _icon(String type) {
    final t = type.toLowerCase();
    if (t.contains('diary') || t.contains('note')) {
      return Icons.note_alt_outlined;
    }
    if (t.contains('training') || t.contains('live')) {
      return Icons.sports_soccer_outlined;
    }
    if (t.contains('test')) return Icons.science_outlined;
    if (t.contains('attendance')) return Icons.fact_check_outlined;
    if (t.contains('document') || t.contains('report')) {
      return Icons.description_outlined;
    }
    if (t.contains('match')) return Icons.sports_soccer_outlined;
    if (t.contains('readiness')) return Icons.favorite_border_rounded;
    if (t.contains('call')) return Icons.call_outlined;
    return Icons.notifications_none_rounded;
  }

  String _time(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    final dt = DateTime.tryParse(s.replaceFirst(' ', 'T'))?.toLocal();
    if (dt == null) return s;

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

    return '${two(dt.day)}.${two(dt.month)} · ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _Header(
            unread: _unread,
            onBack: widget.onBack,
            onRefresh: () => _load(),
            onMarkAll: _unread > 0 ? _markAllRead : null,
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _N.green,
                    ),
                  )
                : _error != null
                    ? _Empty(
                        icon: Icons.cloud_off_rounded,
                        title: 'Уведомления недоступны',
                        subtitle: _error!,
                        action: () => _load(),
                      )
                    : _items.isEmpty
                        ? const _Empty(
                            icon: Icons.notifications_none_rounded,
                            title: 'Пока всё спокойно',
                            subtitle:
                                'Здесь появятся важные события по игрокам, командам, тренировкам и дневнику.',
                          )
                        : RefreshIndicator(
                            color: _N.green,
                            onRefresh: () => _load(),
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 10, 14, 24),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 5),
                              itemBuilder: (_, index) {
                                final item = _items[index];
                                return _NotificationRow(
                                  title: (item['title'] ?? 'Уведомление')
                                      .toString(),
                                  body: (item['body'] ?? '').toString(),
                                  time: _time(item['created_at']),
                                  icon: _icon(
                                    (item['type'] ?? '').toString(),
                                  ),
                                  unread: !_truthy(item['is_read']),
                                  onTap: () => _open(item),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int unread;
  final VoidCallback? onBack;
  final VoidCallback onRefresh;
  final VoidCallback? onMarkAll;

  const _Header({
    required this.unread,
    required this.onBack,
    required this.onRefresh,
    required this.onMarkAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      child: Row(
        children: [
          if (onBack != null) ...[
            _IconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Назад',
              onTap: onBack!,
            ),
            const SizedBox(width: 8),
          ],
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _N.greenSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 18,
              color: _N.greenDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Уведомления',
                      style: _Text.title(15),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _N.graphite,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : unread.toString(),
                          style: _Text.badge(),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Важные события SPORTOTEKA',
                  style: _Text.muted(10.8),
                ),
              ],
            ),
          ),
          if (onMarkAll != null)
            TextButton(
              onPressed: onMarkAll,
              child: Text(
                'Прочитать все',
                style: _Text.action(),
              ),
            ),
          _IconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Обновить',
            onTap: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final bool unread;
  final VoidCallback onTap;

  const _NotificationRow({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.unread,
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
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 9, 10, 9),
          decoration: BoxDecoration(
            color: unread ? const Color(0xFFF3FBF7) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: unread ? Colors.white : _N.soft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: unread ? _N.greenDark : _N.muted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _Text.title(12.8),
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(time, style: _Text.time()),
                        ],
                      ],
                    ),
                    if (body.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: _Text.muted(11.2),
                      ),
                    ],
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: _N.green,
                    shape: BoxShape.circle,
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

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 16, color: _N.greenDark),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? action;

  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 370),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _N.soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _N.green, size: 25),
              ),
              const SizedBox(height: 13),
              Text(title, textAlign: TextAlign.center, style: _Text.title(16)),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: _Text.muted(12),
              ),
              if (action != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: action,
                  child: Text('Повторить', style: _Text.action()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Text {
  static TextStyle title(double size) {
    if (size >= 15) {
      return AppTypography.screenTitle(color: _N.text);
    }
    if (size >= 13.5) {
      return AppTypography.sectionTitle(color: _N.text);
    }
    return AppTypography.itemTitle(color: _N.text);
  }

  static TextStyle muted(double size) {
    if (size >= 11.5) {
      return AppTypography.secondary(color: _N.muted);
    }
    return AppTypography.caption(color: _N.muted);
  }

  static TextStyle time() => AppTypography.commentMeta(color: _N.muted2)
      .copyWith(fontWeight: FontWeight.w500);

  static TextStyle action() => AppTypography.action(color: _N.greenDark);

  static TextStyle badge() => AppTypography.badge(color: Colors.white)
      .copyWith(fontWeight: FontWeight.w600);
}

class _N {
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF374151);
  static const Color muted2 = Color(0xFF6B7280);
  static const Color graphite = Color(0xFF111827);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color soft = Color(0xFFF6F8F7);
}
