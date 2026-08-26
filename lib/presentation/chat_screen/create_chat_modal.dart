import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';

class _CreateChatUi {
  static const Color bg = Color(0xFFF6F7F9);
  static const Color card = Colors.white;
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color border = Color(0xFFEFF1F4);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF6B7280);

  static TextStyle title(double size) {
    final base = size >= 15
        ? AppTypography.screenTitle(color: text)
        : size >= 13.4
            ? AppTypography.subsectionTitle(color: text)
            : AppTypography.itemTitle(color: text);
    return base.copyWith(fontWeight: FontWeight.w700);
  }

  static TextStyle mutedText(double size) {
    final base = size >= 11.5
        ? AppTypography.secondary(color: muted)
        : AppTypography.caption(color: muted);
    return base.copyWith(fontWeight: FontWeight.w500);
  }
}

Future<int?> showCreatePrivateChatModal(
  BuildContext context, {
  required int me,
}) async {
  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _CreateChatUi.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _CreatePrivateChatSheet(me: me),
  );
}

class _CreatePrivateChatSheet extends StatefulWidget {
  final int me;
  const _CreatePrivateChatSheet({required this.me});

  @override
  State<_CreatePrivateChatSheet> createState() => _CreatePrivateChatSheetState();
}

class _CreatePrivateChatSheetState extends State<_CreatePrivateChatSheet> {
  final TextEditingController _search = TextEditingController();
  bool _loading = false;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    _loadUsers();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = List<Map<String, dynamic>>.from(_users));
      return;
    }
    setState(() {
      _filtered = _users.where((u) {
        final fn = (u['first_name'] ?? '').toString().toLowerCase();
        final ln = (u['last_name'] ?? '').toString().toLowerCase();
        final em = (u['email'] ?? '').toString().toLowerCase();
        final full = ('$fn $ln').trim();
        return full.contains(q) || em.contains(q);
      }).toList();
    });
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_users.php?me=${widget.me}');
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final raw = res.body.trimLeft();
        final data = json.decode(raw);
        final list = (data is List) ? List<Map<String, dynamic>>.from(data) : <Map<String, dynamic>>[];
        final cleaned = list.where((u) => int.tryParse(u['id'].toString()) != widget.me).toList();

        setState(() {
          _users = cleaned;
          _filtered = List<Map<String, dynamic>>.from(cleaned);
        });
      } else {
        _toast('Не удалось загрузить пользователей (HTTP ${res.statusCode})');
      }
    } catch (e) {
      _toast('Ошибка загрузки пользователей: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _title(Map<String, dynamic> u) {
    final fn = (u['first_name'] ?? '').toString().trim();
    final ln = (u['last_name'] ?? '').toString().trim();
    final full = ('$fn $ln').trim();
    return full.isNotEmpty ? full : (u['email'] ?? 'Пользователь').toString();
  }

  String _photo(Map<String, dynamic> u) {
    final raw = (u['photo'] ?? '').toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    if (raw.startsWith('http')) return raw;
    return 'https://sportotekaapp.ru/uploads/$raw';
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _createPrivate(int peerId) async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_or_create_private_chat.php');
      final res = await http.post(uri, body: {
        'me': widget.me.toString(),
        'peer_id': peerId.toString(),
      });

      final raw = res.body.trimLeft();
      final data = json.decode(raw);

      if (res.statusCode == 200 && data is Map && data['success'] == true) {
        final chatId = int.tryParse(data['chat_id'].toString());
        if (chatId != null) {
          Navigator.pop(context, chatId);
          return;
        }
      }

      final err = (data is Map && data['error'] != null) ? data['error'].toString() : 'HTTP ${res.statusCode}';
      _toast('Ошибка создания лички: $err');
    } catch (e) {
      _toast('Сеть/исключение: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _avatar(String photo, String title) {
    final initials = title.trim().isEmpty ? 'П' : title.trim().substring(0, 1).toUpperCase();
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _CreateChatUi.greenSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CreateChatUi.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isNotEmpty
          ? Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(initials, style: const TextStyle(color: _CreateChatUi.greenDark, fontWeight: FontWeight.w700))))
          : Center(child: Text(initials, style: const TextStyle(color: _CreateChatUi.greenDark, fontWeight: FontWeight.w700))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: const TextScaler.linear(1.08)),
      child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .76,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: _CreateChatUi.greenSoft, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: _CreateChatUi.greenDark, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Личный чат', style: _CreateChatUi.title(15.2)),
                          const SizedBox(height: 3),
                          Text('Выберите пользователя для диалога', style: _CreateChatUi.mutedText(11.2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: _CreateChatUi.border)),
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(hintText: 'Поиск пользователя...', border: InputBorder.none, isDense: true, prefixIcon: Icon(Icons.search_rounded, size: 18)),
                    style: AppTypography.formText(color: _CreateChatUi.text)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _CreateChatUi.green))
                    : _filtered.isEmpty
                        ? Center(child: Text('Пользователи не найдены', style: _CreateChatUi.mutedText(12)))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 7),
                            itemBuilder: (_, i) {
                              final u = _filtered[i];
                              final id = int.tryParse(u['id'].toString()) ?? 0;
                              final title = _title(u);
                              final photo = _photo(u);
                              return Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _createPrivate(id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Row(children: [
                                      _avatar(photo, title),
                                      const SizedBox(width: 9),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CreateChatUi.title(13.2)),
                                        const SizedBox(height: 3),
                                        Text((u['email'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: _CreateChatUi.mutedText(11)),
                                      ])),
                                      const Icon(Icons.chevron_right_rounded, size: 18, color: _CreateChatUi.muted),
                                    ]),
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
    ),
    );
  }
}
