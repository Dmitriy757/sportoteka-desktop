import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


class _EditGroupUi {
  static const Color bg = Color(0xFFF6F7F9);
  static const Color card = Colors.white;
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color border = Color(0xFFEFF1F4);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF6B7280);
  static const Color red = Color(0xFFEF4444);
  static TextStyle title(double size) => TextStyle(color: text, fontSize: size, fontWeight: FontWeight.w700, height: 1.08, letterSpacing: -0.3);
  static TextStyle mutedText(double size) => TextStyle(color: muted, fontSize: size, fontWeight: FontWeight.w500, height: 1.24);
}

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

  Widget _avatar(({int? id, String first, String last, String email, String avatar}) data) {
    final initials = (data.first.isNotEmpty ? data.first[0] : '?').toUpperCase();
    return Container(
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: _EditGroupUi.greenSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: _EditGroupUi.border)),
      child: data.avatar.isNotEmpty ? Image.network(data.avatar, fit: BoxFit.cover) : Center(child: Text(initials, style: const TextStyle(color: _EditGroupUi.greenDark, fontWeight: FontWeight.w700))),
    );
  }

  Widget _buildMembersBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: _EditGroupUi.greenSoft, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.groups_rounded, color: _EditGroupUi.greenDark, size: 17)),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Текущие участники', style: _EditGroupUi.title(13.6)),
              const SizedBox(height: 2),
              Text('${members.length} участников', style: _EditGroupUi.mutedText(10.8)),
            ])),
            if (isLoadingMembers) const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _EditGroupUi.green)),
          ]),
          const SizedBox(height: 10),
          if (members.isEmpty && !isLoadingMembers)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(child: Text('Пока никого нет', style: _EditGroupUi.mutedText(12))),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                itemCount: members.length,
                shrinkWrap: true,
                itemBuilder: (context, i) {
                  final data = _u(members[i]);
                  final title = '${data.first.isEmpty ? "Без имени" : data.first} ${data.last}'.trim();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: _EditGroupUi.bg, borderRadius: BorderRadius.circular(13)),
                    child: Row(children: [
                      _avatar(data),
                      const SizedBox(width: 9),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _EditGroupUi.title(13.0)),
                        if (data.email.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(data.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: _EditGroupUi.mutedText(10.6)),
                        ],
                      ])),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_rounded, color: _EditGroupUi.red, size: 20),
                        onPressed: (data.id == null) ? null : () => _confirmAndRemoveUserFromChat(data.id!, title),
                      ),
                    ]),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 7),
              ),
            ),
          if (lastError != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _EditGroupUi.red.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
              child: Text(lastError!, style: const TextStyle(fontSize: 11.5, color: _EditGroupUi.red, fontWeight: FontWeight.w500)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBlock() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _EditGroupUi.border)),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(labelText: null, hintText: 'Поиск пользователя', prefixIcon: Icon(Icons.search_rounded, size: 18, color: _EditGroupUi.muted), border: InputBorder.none, isDense: true),
        style: const TextStyle(fontSize: 13.2, fontWeight: FontWeight.w500),
        onChanged: _searchUsers,
      ),
    );
  }

  Widget _buildSearchResults() {
    if (isSearching) return const Center(child: CircularProgressIndicator(color: _EditGroupUi.green));
    if (searchResults.isEmpty) {
      return Center(child: Text('Введите имя, фамилию или почту для поиска', style: _EditGroupUi.mutedText(12), textAlign: TextAlign.center));
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.paddingOf(context).bottom + 16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final data = _u(searchResults[index]);
        final title = '${data.first.isNotEmpty ? data.first : 'Без имени'} ${data.last}'.trim();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _avatar(data),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _EditGroupUi.title(13.0)),
              if (data.email.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(data.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: _EditGroupUi.mutedText(10.6)),
              ],
            ])),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.person_add_alt_1_rounded, color: _EditGroupUi.greenDark, size: 20), onPressed: data.id == null ? null : () => _addUserToChat(data.id!)),
          ]),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 7),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded), style: IconButton.styleFrom(backgroundColor: Colors.white, fixedSize: const Size(40, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)))),
        const SizedBox(width: 8),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: _EditGroupUi.greenSoft, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.manage_accounts_rounded, color: _EditGroupUi.greenDark, size: 19)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Участники', style: _EditGroupUi.title(17.0), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(widget.chatName, style: _EditGroupUi.mutedText(11.2), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: const TextScaler.linear(1.08)),
      child: Scaffold(
      backgroundColor: _EditGroupUi.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: Column(
                  children: [
                    _buildMembersBlock(),
                    const SizedBox(height: 9),
                    _buildSearchBlock(),
                    const SizedBox(height: 9),
                    Expanded(child: _buildSearchResults()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

}
