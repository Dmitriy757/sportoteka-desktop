// lib/presentation/chat_screen/sportoteka_news_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';

class SportotekaNewsScreen extends StatefulWidget {
  final int userId;
  final bool embedded;
  final ValueChanged<int>? onUnreadChanged;
  final VoidCallback? onHidden;

  const SportotekaNewsScreen({
    super.key,
    required this.userId,
    this.embedded = false,
    this.onUnreadChanged,
    this.onHidden,
  });

  @override
  State<SportotekaNewsScreen> createState() => _SportotekaNewsScreenState();
}

class _SportotekaNewsScreenState extends State<SportotekaNewsScreen> {
  static const _base = 'https://sportotekaapp.ru/api/sportoteka_news';

  final ScrollController _scroll = ScrollController();

  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _hiding = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _timer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final uri = Uri.parse(
        '$_base/list.php?user_id=${widget.userId}&limit=100',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['success'] != true) return;

      final raw = decoded['items'];
      final next = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      final changed = next.length != _items.length ||
          (next.isNotEmpty &&
              (_items.isEmpty || next.last['id'] != _items.last['id']));

      if (initial || changed) {
        setState(() {
          _items = next;
          _loading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients) return;
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      } else if (_loading) {
        setState(() => _loading = false);
      }

      await _markRead();
    } catch (_) {
      if (mounted && initial) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markRead() async {
    try {
      await http.post(
        Uri.parse('$_base/mark_read.php'),
        body: <String, String>{
          'user_id': widget.userId.toString(),
        },
      ).timeout(const Duration(seconds: 8));
      widget.onUnreadChanged?.call(0);
    } catch (_) {}
  }

  Future<void> _hideChannel() async {
    if (_hiding) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Удалить SPORTOTEKA Новости?',
          style: AppTypography.sectionTitle(
            color: const Color(0xFF111827),
          ),
        ),
        content: Text(
          'Канал исчезнет из списка чатов. '
          'Когда SPORTOTEKA опубликует новое сообщение, он появится снова.',
          style: AppTypography.body(
            color: const Color(0xFF667085),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _hiding = true);

    try {
      final res = await http.post(
        Uri.parse('$_base/hide.php'),
        body: <String, String>{
          'user_id': widget.userId.toString(),
        },
      ).timeout(const Duration(seconds: 8));

      final decoded = jsonDecode(res.body);
      final success =
          res.statusCode == 200 && decoded is Map && decoded['success'] == true;

      if (!success || !mounted) return;

      widget.onUnreadChanged?.call(0);
      widget.onHidden?.call();

      if (!widget.embedded && Navigator.of(context).canPop()) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось удалить канал из списка'),
        ),
      );
    } finally {
      if (mounted) setState(() => _hiding = false);
    }
  }

  String _resolveMedia(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return 'https://sportotekaapp.ru${value.startsWith('/') ? '' : '/'}$value';
  }

  String _formatDate(dynamic raw) {
    final dt = DateTime.tryParse('${raw ?? ''}')?.toLocal();
    if (dt == null) return '';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.${dt.year} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: <Widget>[
        _buildHeader(),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00A750),
                  ),
                )
              : _items.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
                      itemCount: _items.length,
                      itemBuilder: (_, index) {
                        return _buildMessage(_items[index]);
                      },
                    ),
        ),
        _buildReadonlyBar(),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(
        color: Colors.white,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: content),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFEDF0EE),
            width: .7,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (!widget.embedded) ...<Widget>[
            _SquareAction(
              icon: Icons.chevron_left_rounded,
              onTap: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 8),
          ],
          const _NewsLogo(size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SPORTOTEKA Новости',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.itemTitle(
                    color: const Color(0xFF0B0F14),
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'официальный канал · только для чтения',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.commentMeta(
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          _SquareAction(
            icon: _hiding
                ? Icons.hourglass_top_rounded
                : Icons.delete_outline_rounded,
            onTap: _hiding ? () {} : _hideChannel,
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> item) {
    final title = '${item['title'] ?? 'SPORTOTEKA Новости'}'.trim();
    final body = '${item['body'] ?? ''}'.trim();
    final media = _resolveMedia('${item['media_url'] ?? ''}');
    final action = '${item['action_url'] ?? ''}'.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: _NewsLogo(size: 30),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 620),
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3FAF6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title.isEmpty ? 'SPORTOTEKA Новости' : title,
                          style: AppTypography.itemTitle(
                            color: const Color(0xFF067A46),
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: Color(0xFF00A750),
                      ),
                    ],
                  ),
                  if (media.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(
                        media,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  if (body.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 7),
                    Text(
                      body,
                      style: AppTypography.secondary(
                        color: const Color(0xFF111827),
                      ).copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.36,
                      ),
                    ),
                  ],
                  if (action.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Подробнее · $action',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.commentMeta(
                          color: const Color(0xFF067A46),
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(item['created_at']),
                    style: AppTypography.commentMeta(
                      color: const Color(0xFF98A2B3),
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

  Widget _buildReadonlyBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(0xFFEDF0EE),
              width: .7,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            const _NewsDots(compact: true),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Официальные сообщения SPORTOTEKA',
                style: AppTypography.caption(
                  color: const Color(0xFF667085),
                ),
              ),
            ),
            Text(
              'ответы отключены',
              style: AppTypography.commentMeta(
                color: const Color(0xFF98A2B3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _NewsLogo(size: 54),
          const SizedBox(height: 12),
          Text(
            'SPORTOTEKA Новости',
            style: AppTypography.sectionTitle(
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Пока нет публикаций',
            style: AppTypography.secondary(
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsLogo extends StatelessWidget {
  final double size;

  const _NewsLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF6),
        borderRadius: BorderRadius.circular(size * .28),
      ),
      alignment: Alignment.center,
      child: _NewsDots(compact: size < 36),
    );
  }
}

class _NewsDots extends StatelessWidget {
  final bool compact;

  const _NewsDots({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final s = compact ? .75 : 1.0;
    final values = <double>[3.2, 4.2, 5.2, 6.2];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < values.length; i++) ...<Widget>[
          Container(
            width: values[i] * s,
            height: values[i] * s,
            decoration: BoxDecoration(
              color: const Color(0xFF00A750).withOpacity(
                <double>[.34, .52, .74, 1][i],
              ),
              shape: BoxShape.circle,
            ),
          ),
          if (i != values.length - 1) SizedBox(width: 2.7 * s),
        ],
      ],
    );
  }
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SquareAction({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F9F8),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 17,
            color: const Color(0xFF344054),
          ),
        ),
      ),
    );
  }
}
