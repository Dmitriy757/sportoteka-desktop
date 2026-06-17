import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

Future<int?> showCreatePrivateChatModal(
  BuildContext context, {
  required int me,
}) async {
  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
      // ⚠️ Поставь сюда свой эндпоинт получения пользователей
      // Например: get_users.php или search_users.php
      // Он должен возвращать массив пользователей: [{id, first_name, last_name, photo, email}, ...]
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_users.php?me=${widget.me}');
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final raw = res.body.trimLeft();
        final data = json.decode(raw);
        final list = (data is List) ? List<Map<String, dynamic>>.from(data) : <Map<String, dynamic>>[];
        // исключаем самого себя
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

      // ignore: avoid_print
      print('GET_OR_CREATE_PRIVATE status=${res.statusCode}, body=$raw');

      if (res.statusCode == 200 && data is Map && data['success'] == true) {
        final chatId = int.tryParse(data['chat_id'].toString());
        if (chatId != null) {
          Navigator.pop(context, chatId); // ✅ вернём chatId наружу
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Личный чат', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Поиск пользователя...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SizedBox(
                height: 420,
                child: _filtered.isEmpty
                    ? const Center(child: Text('Пользователи не найдены'))
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final u = _filtered[i];
                          final id = int.tryParse(u['id'].toString()) ?? 0;
                          final photo = _photo(u);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE3F2FD),
                              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                              child: photo.isEmpty ? const Icon(Icons.person, color: Color(0xFF1E74C4)) : null,
                            ),
                            title: Text(_title(u), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text((u['email'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => _createPrivate(id),
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