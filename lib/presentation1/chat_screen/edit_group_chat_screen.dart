import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EditGroupChatScreen extends StatefulWidget {
  final int chatId;
  final int currentUserId;
  final String chatName;

  const EditGroupChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.chatName,
  });

  @override
  State<EditGroupChatScreen> createState() => _EditGroupChatScreenState();
}

class _EditGroupChatScreenState extends State<EditGroupChatScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> searchResults = [];

  bool isSearching = false;
  bool isLoadingMembers = false;

  String? lastError; // покажем текст под блоком, если сервер вернул что-то не то

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  // ---------- УТИЛИТЫ ----------

  String _sanitizeBody(String body) {
    if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
      body = body.substring(1); // убрать BOM
    }
    return body.trimLeft();
  }

  /// Безопасный JSON-декодер: пустое тело -> null; не JSON -> FormatException
  dynamic _safeJsonDecode(String body) {
    final t = _sanitizeBody(body);
    if (t.isEmpty) return null;
    if (!(t.startsWith('{') || t.startsWith('['))) {
      final preview = t.substring(0, t.length > 200 ? 200 : t.length);
      throw const FormatException('Сервер вернул не JSON');
    }
    return json.decode(t);
  }

  /// Жёсткий декодер для GET-методов, где точно должен прийти JSON
  dynamic _decodeJsonOrThrow(String body) {
    final t = _sanitizeBody(body);
    if (!(t.startsWith('{') || t.startsWith('['))) {
      final preview = t.substring(0, t.length > 200 ? 200 : t.length);
      throw FormatException('Ответ не JSON. Начало: $preview');
    }
    return json.decode(t);
  }

  List<Map<String, dynamic>> _parseList(dynamic body) {
    final raw = body is List
        ? body
        : (body is Map
            ? (body['members'] ?? body['users'] ?? body['data'] ?? body['list'] ?? [])
            : []);
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  ({int? id, String first, String last, String email, String avatar}) _u(Map<String, dynamic> m) {
    final idRaw = m['id'] ?? m['user_id'];
    final id = idRaw is String ? int.tryParse(idRaw) : (idRaw is int ? idRaw : null);
    final first = (m['first_name'] ?? m['firstname'] ?? '').toString();
    final last = (m['last_name'] ?? m['lastname'] ?? '').toString();
    final email = (m['email'] ?? '').toString();
    final avatar = (m['avatar_url'] ?? m['avatar'] ?? '').toString();
    return (id: id, first: first, last: last, email: email, avatar: avatar);
  }

  // ---------- API ----------

  Future<void> _loadMembers() async {
    setState(() {
      isLoadingMembers = true;
      lastError = null;
    });
    try {
      final uri = Uri.parse(
        'https://sportotekaapp.ru/api/get_chat_members.php?chat_id=${widget.chatId}',
      );
      final res = await http.get(uri, headers: {'Accept': 'application/json'});

      if (res.statusCode == 200) {
        final body = _decodeJsonOrThrow(res.body);
        final list = _parseList(body);
        if (!mounted) return;
        setState(() => members = list);
      } else {
        if (!mounted) return;
        setState(() => lastError = 'HTTP ${res.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки участников')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => lastError = 'Ошибка загрузки: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is FormatException
              ? 'Ошибка загрузки: сервер вернул не JSON'
              : 'Ошибка загрузки: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoadingMembers = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        searchResults = [];
        lastError = null;
      });
      return;
    }
    setState(() {
      isSearching = true;
      lastError = null;
    });
    try {
      final uri = Uri.parse(
        'https://sportotekaapp.ru/api/search_users.php?q=${Uri.encodeComponent(query)}&exclude=${widget.currentUserId}',
      );
      final res = await http.get(uri, headers: {'Accept': 'application/json'});

      if (res.statusCode == 200) {
        final body = _decodeJsonOrThrow(res.body);
        final list = _parseList(body);
        if (!mounted) return;
        setState(() => searchResults = list);
      } else {
        if (!mounted) return;
        setState(() => lastError = 'HTTP ${res.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка поиска')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => lastError = 'Ошибка поиска: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is FormatException
              ? 'Ошибка поиска: сервер вернул не JSON'
              : 'Ошибка поиска: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
  }

  Future<void> _addUserToChat(int userIdToAdd) async {
    try {
      final res = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/add_user_to_chat.php'),
        headers: {'Accept': 'application/json'},
        body: {
          'chat_id': widget.chatId.toString(),
          'user_id': userIdToAdd.toString(),
          'actor_id': widget.currentUserId.toString(), // ВАЖНО
        },
      );

      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Добавление: HTTP ${res.statusCode}')),
        );
        return;
      }

      final data = _safeJsonDecode(res.body);
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Добавление: пустой ответ сервера')),
        );
        return;
      }

      final ok = data is Map && (data['success'] == true || data['status'] == 'ok');
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь добавлен'), backgroundColor: Colors.green),
        );
        await _loadMembers();
        _searchController.clear();
        if (mounted) setState(() => searchResults = []);
      } else {
        final err = data is Map ? (data['error'] ?? data['message'] ?? 'Ошибка') : 'Ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Добавление: $err'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка добавления: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmAndRemoveUserFromChat(int userId, String userName) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить участника?'),
        content: Text('Вы уверены, что хотите удалить $userName из чата?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (sure != true) return;

    try {
      final res = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/remove_user_from_chat.php'),
        headers: {'Accept': 'application/json'},
        body: {
          'chat_id': widget.chatId.toString(),
          'user_id': userId.toString(),
          'actor_id': widget.currentUserId.toString(), // ВАЖНО
        },
      );

      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Удаление: HTTP ${res.statusCode}')),
        );
        return;
      }

      final data = _safeJsonDecode(res.body);
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Удаление: пустой ответ сервера')),
        );
        return;
      }

      final ok = data is Map && (data['success'] == true || data['status'] == 'ok');
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь удалён'), backgroundColor: Colors.orange),
        );
        await _loadMembers();
      } else {
        final err = data is Map ? (data['error'] ?? data['message'] ?? 'Ошибка') : 'Ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Удаление: $err'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ---------- UI ----------

  Widget _buildMembersBlock() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: const Color(0xFFF6F8FB),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.group, size: 20),
                const SizedBox(width: 8),
                const Text('Текущие участники', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (isLoadingMembers)
                  const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),

            if (members.isEmpty && !isLoadingMembers)
              const ListTile(
                leading: Icon(Icons.group_outlined),
                title: Text('Пока никого нет'),
                subtitle: Text('Добавьте участников через поиск ниже'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  itemCount: members.length,
                  shrinkWrap: true,
                  itemBuilder: (context, i) {
                    final data = _u(members[i]);
                    final initials = (data.first.isNotEmpty ? data.first[0] : '?');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: data.avatar.isNotEmpty ? NetworkImage(data.avatar) : null,
                        child: data.avatar.isEmpty ? Text(initials) : null,
                      ),
                      title: Text(
                        '${data.first.isEmpty ? "Без имени" : data.first} ${data.last}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: (data.id == null)
                            ? null
                            : () => _confirmAndRemoveUserFromChat(data.id!, '${data.first} ${data.last}'),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                ),
              ),

            if (lastError != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  lastError!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBlock() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Поиск пользователя',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: const Color(0xFFF6F8FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: _searchUsers,
    );
  }

  Widget _buildSearchResults() {
    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (searchResults.isEmpty) {
      return const Center(
        child: Text('Введите имя/фамилию/почту для поиска', style: TextStyle(color: Colors.black54)),
      );
    }
    return ListView.separated(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final data = _u(searchResults[index]);
        final initials = (data.first.isNotEmpty ? data.first[0] : '?');
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: data.avatar.isNotEmpty ? NetworkImage(data.avatar) : null,
            child: data.avatar.isEmpty ? Text(initials) : null,
          ),
          title: Text(
            '${data.first.isNotEmpty ? data.first : 'Без имени'} ${data.last}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: data.email.isEmpty ? null : Text(data.email),
          trailing: IconButton(
            icon: const Icon(Icons.person_add, color: Color(0xFF1E74C4)),
            onPressed: data.id == null ? null : () => _addUserToChat(data.id!),
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Участники: ${widget.chatName}'),
        backgroundColor: const Color(0xFF1E74C4),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMembersBlock(),
            const SizedBox(height: 12),
            _buildSearchBlock(),
            const SizedBox(height: 12),
            Expanded(child: _buildSearchResults()),
          ],
        ),
      ),
    );
  }
}
