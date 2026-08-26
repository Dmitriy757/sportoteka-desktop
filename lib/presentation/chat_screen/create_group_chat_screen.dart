import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';

class _GroupChatUi {
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

class CreateGroupChatScreen extends StatefulWidget {
  final int userId;
  const CreateGroupChatScreen({super.key, required this.userId});

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

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
      final res = await http.get(Uri.parse('$_apiBase/search_users.php?q=$q&exclude=${widget.userId}'));
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
      _toast('Введите название группы');
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final uri = Uri.parse('$_apiBase/create_group_chat.php');
      final members = <int>{widget.userId};
      if (isClosedGroup) members.addAll(selectedUserIds);

      final res = await http.post(uri, body: {
        'user_id': widget.userId.toString(),
        'name': name,
        'is_public': isClosedGroup ? '0' : '1',
        'members': jsonEncode(members.toList()),
      });

      final data = jsonDecode(res.body);
      final ok = res.statusCode == 200 && data is Map && data['success'] == true;

      if (ok) {
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      final err = (data is Map && data['error'] != null) ? data['error'].toString() : res.body;
      _toast('Не удалось создать группу: $err');
    } catch (e) {
      _toast('Сеть/ошибка: $e');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  String _photo(Map user) {
    final raw = (user['photo'] ?? user['avatar'] ?? '').toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    if (raw.startsWith('http')) return raw;
    return 'https://sportotekaapp.ru/uploads/$raw';
  }

  Widget _field({required TextEditingController controller, required String hint, IconData? icon, ValueChanged<String>? onChanged}) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _GroupChatUi.border)),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(border: InputBorder.none, hintText: hint, isDense: true, prefixIcon: icon == null ? null : Icon(icon, size: 18, color: _GroupChatUi.muted)),
        style: AppTypography.formText(color: _GroupChatUi.text)
            .copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(backgroundColor: Colors.white, fixedSize: const Size(40, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
        ),
        const SizedBox(width: 8),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: _GroupChatUi.greenSoft, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.groups_2_rounded, color: _GroupChatUi.greenDark, size: 19)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Новая группа', style: _GroupChatUi.title(17.0), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(isClosedGroup ? 'Закрытая группа · приглашения' : 'Открытая группа · вступают сами', style: _GroupChatUi.mutedText(11.2), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _typeCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: _GroupChatUi.greenSoft, borderRadius: BorderRadius.circular(12)), child: Icon(isClosedGroup ? Icons.lock_outline_rounded : Icons.public_rounded, color: _GroupChatUi.greenDark, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Сделать группу закрытой', style: _GroupChatUi.title(13.4)),
          const SizedBox(height: 3),
          Text('Закрытая — только по приглашению, открытая — видна всем', style: _GroupChatUi.mutedText(10.8)),
        ])),
        Switch(value: isClosedGroup, activeColor: _GroupChatUi.green, onChanged: (val) => setState(() { isClosedGroup = val; users = []; selectedUserIds.clear(); _searchController.clear(); })),
      ]),
    );
  }

  Widget _userRow(Map user) {
    final id = int.tryParse(user['id'].toString()) ?? 0;
    final fn = (user['first_name'] ?? '').toString();
    final ln = (user['last_name'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final title = ('$fn $ln').trim().isEmpty ? 'Пользователь' : ('$fn $ln').trim();
    final checked = selectedUserIds.contains(id);
    final photo = _photo(user);
    return Material(
      color: checked ? _GroupChatUi.greenSoft : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() { checked ? selectedUserIds.remove(id) : selectedUserIds.add(id); }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(children: [
            Container(width: 38, height: 38, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: _GroupChatUi.greenSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: _GroupChatUi.border)), child: photo.isNotEmpty ? Image.network(photo, fit: BoxFit.cover) : const Icon(Icons.person_rounded, color: _GroupChatUi.greenDark, size: 18)),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _GroupChatUi.title(13.0)),
              const SizedBox(height: 3),
              Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: _GroupChatUi.mutedText(10.8)),
            ])),
            Checkbox(value: checked, activeColor: _GroupChatUi.green, onChanged: (val) => setState(() { val == true ? selectedUserIds.add(id) : selectedUserIds.remove(id); })),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPicker = isClosedGroup;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: const TextScaler.linear(1.08)),
      child: Scaffold(
      backgroundColor: _GroupChatUi.bg,
      body: SafeArea(
        child: Column(children: [
          _header(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.paddingOf(context).bottom + 16),
              children: [
                _field(controller: _nameController, hint: 'Название группы', icon: Icons.edit_rounded),
                const SizedBox(height: 9),
                _typeCard(),
                const SizedBox(height: 9),
                if (showPicker) ...[
                  _field(controller: _searchController, hint: 'Поиск участников', icon: Icons.search_rounded, onChanged: _searchUsers),
                  const SizedBox(height: 9),
                  if (isLoading)
                    const Padding(padding: EdgeInsets.all(22), child: Center(child: CircularProgressIndicator(color: _GroupChatUi.green)))
                  else if (users.isEmpty)
                    Padding(padding: const EdgeInsets.all(18), child: Center(child: Text('Нет результатов', style: _GroupChatUi.mutedText(12))))
                  else
                    ...users.whereType<Map>().map((user) => Padding(padding: const EdgeInsets.only(bottom: 7), child: _userRow(user))),
                ] else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Text('Открытая группа будет видна в списке групп. Пользователи смогут вступить сами.', style: _GroupChatUi.mutedText(12)),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : _createGroup,
                  style: ElevatedButton.styleFrom(backgroundColor: _GroupChatUi.green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  icon: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    isSubmitting ? 'Создаём...' : 'Создать группу',
                    style: AppTypography.actionStrong(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    ),
    );
  }
}
