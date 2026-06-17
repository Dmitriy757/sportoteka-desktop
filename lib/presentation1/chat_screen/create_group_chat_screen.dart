import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CreateGroupChatScreen extends StatefulWidget {
  final int userId;
  const CreateGroupChatScreen({super.key, required this.userId});

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  /// ✅ true = закрытая (можно выбирать участников), false = открытая (все видят, вступают сами)
  bool isClosedGroup = false;

  List<dynamic> users = [];
  final List<int> selectedUserIds = [];

  bool isLoading = false;
  bool isSubmitting = false;

  static const _apiBase = 'https://sportotekaapp.ru/api';

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => users = []);
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/search_users.php?q=$q&exclude=${widget.userId}'),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => users = (data is List) ? data : []);
      } else {
        _toast('Ошибка поиска: HTTP ${res.statusCode}');
      }
    } catch (e) {
      _toast('Ошибка сети: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _toast("Введите название группы");
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final uri = Uri.parse('$_apiBase/create_group_chat.php');

      // ✅ members НЕ обязателен
      final members = <int>{widget.userId};
      if (isClosedGroup) {
        members.addAll(selectedUserIds);
      }

      final res = await http.post(uri, body: {
        'user_id': widget.userId.toString(),
        'name': name,
        'is_public': isClosedGroup ? '0' : '1', // ✅ 1 open, 0 closed
        'members': jsonEncode(members.toList()), // ok: для open будет только создатель
      });

      // ignore: avoid_print
      print("CREATE_GROUP status=${res.statusCode} body=${res.body}");

      final data = jsonDecode(res.body);
      final ok = res.statusCode == 200 && data is Map && data['success'] == true;

      if (ok) {
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      final err = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : res.body;
      _toast("Не удалось создать группу: $err");
    } catch (e) {
      _toast("Сеть/ошибка: $e");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPicker = isClosedGroup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая группа'),
        backgroundColor: const Color(0xFF1E74C4),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Название группы'),
            ),
            const SizedBox(height: 10),

            SwitchListTile(
              value: isClosedGroup,
              onChanged: (val) => setState(() {
                isClosedGroup = val;
                users = [];
                selectedUserIds.clear();
                _searchController.clear();
              }),
              title: const Text('Сделать группу закрытой'),
              subtitle: const Text('Закрытая = приглашения, открытая = вступают сами'),
            ),

            const SizedBox(height: 8),

            if (showPicker) ...[
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Поиск участников',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _searchUsers,
              ),
              const SizedBox(height: 12),

              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Expanded(
                  child: users.isEmpty
                      ? const Center(child: Text('Нет результатов'))
                      : ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index] as Map;
                            final id = int.tryParse(user['id'].toString()) ?? 0;

                            final fn = (user['first_name'] ?? '').toString();
                            final ln = (user['last_name'] ?? '').toString();
                            final email = (user['email'] ?? '').toString();

                            final checked = selectedUserIds.contains(id);

                            return CheckboxListTile(
                              value: checked,
                              title: Text('$fn $ln'.trim()),
                              subtitle: Text(email),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedUserIds.add(id);
                                  } else {
                                    selectedUserIds.remove(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
            ] else
              const Spacer(),

            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isSubmitting ? null : _createGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E74C4),
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(
                isSubmitting ? 'Создаём...' : 'Создать группу',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}