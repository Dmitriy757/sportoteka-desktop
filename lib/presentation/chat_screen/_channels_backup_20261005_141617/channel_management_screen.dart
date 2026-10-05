import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/theme/app_typography.dart';

class _ChannelManageUi {
  static const Color bg = Color(0xFFF6F7F9);
  static const Color card = Colors.white;
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color border = Color(0xFFE8ECEA);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF667085);
  static const Color red = Color(0xFFD92D20);
  static const Color amber = Color(0xFFF59E0B);

  static TextStyle title(double size) {
    final base = size >= 16
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

class ChannelManagementScreen extends StatefulWidget {
  final int chatId;
  final int currentUserId;

  const ChannelManagementScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
  });

  @override
  State<ChannelManagementScreen> createState() => _ChannelManagementScreenState();
}

class _ChannelManagementScreenState extends State<ChannelManagementScreen> {
  static const _apiBase = 'https://sportotekaapp.ru/api';

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _usernameController = TextEditingController();
  final _searchController = TextEditingController();
  final _picker = ImagePicker();

  Map<String, dynamic> _channel = <String, dynamic>{};
  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _members = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _searchResults = <Map<String, dynamic>>[];

  bool _loading = true;
  bool _saving = false;
  bool _searching = false;
  bool _closing = false;
  bool _isPublic = true;
  XFile? _avatar;

  String get _myRole => (_channel['my_role'] ?? '').toString().toLowerCase();
  bool get _isOwner => _myRole == 'owner';
  bool get _isAdmin => _myRole == 'admin' || _isOwner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _usernameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _photo(dynamic rawValue) {
    final raw = (rawValue ?? '').toString().trim().replaceAll('\\', '/');
    if (raw.isEmpty || raw == 'null') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/${raw.startsWith('uploads/') ? raw : 'uploads/$raw'}';
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final uri = Uri.parse(
        '$_apiBase/channel_manage.php?chat_id=${widget.chatId}&user_id=${widget.currentUserId}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      final decoded = json.decode(res.body);
      if (res.statusCode != 200 || decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded is Map ? (decoded['error'] ?? 'Ошибка') : 'HTTP ${res.statusCode}');
      }

      final channel = Map<String, dynamic>.from(decoded['channel'] as Map? ?? const <String, dynamic>{});
      final requests = (decoded['requests'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final members = (decoded['members'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() {
        _channel = channel;
        _requests = requests;
        _members = members;
        _isPublic = channel['is_public'] == true ||
            channel['is_public'] == 1 ||
            channel['is_public'] == '1';
        _nameController.text = (channel['name'] ?? '').toString();
        _descriptionController.text = (channel['description'] ?? '').toString();
        _usernameController.text = (channel['username'] ?? '').toString();
      });
    } catch (e) {
      _toast('Не удалось загрузить канал: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (!_isAdmin) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1400,
      maxHeight: 1400,
    );
    if (picked == null || !mounted) return;
    setState(() => _avatar = picked);
  }

  String _normaliseUsername(String raw) {
    var value = raw.trim().toLowerCase();
    if (value.startsWith('@')) value = value.substring(1);
    return value.replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  Future<void> _save() async {
    if (!_isAdmin) return;
    final name = _nameController.text.trim();
    final username = _normaliseUsername(_usernameController.text);
    if (name.length < 2) {
      _toast('Введите название канала');
      return;
    }
    if (username.isNotEmpty && username.length < 4) {
      _toast('Адрес канала должен быть не короче 4 символов');
      return;
    }

    setState(() => _saving = true);
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$_apiBase/channel_update.php'))
        ..fields['chat_id'] = widget.chatId.toString()
        ..fields['actor_id'] = widget.currentUserId.toString()
        ..fields['name'] = name
        ..fields['description'] = _descriptionController.text.trim()
        ..fields['username'] = username
        ..fields['is_public'] = _isPublic ? '1' : '0';
      if (_avatar != null) {
        req.files.add(await http.MultipartFile.fromPath('avatar', _avatar!.path));
      }
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(streamed);
      final decoded = json.decode(res.body);
      if (res.statusCode != 200 || decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded is Map ? (decoded['error'] ?? 'Ошибка сохранения') : 'HTTP ${res.statusCode}');
      }
      _toast('Канал обновлён');
      _avatar = null;
      await _load();
    } catch (e) {
      _toast('Не удалось сохранить: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleRequest(int userId, bool approve) async {
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/channel_request_action.php'),
        body: <String, String>{
          'chat_id': widget.chatId.toString(),
          'actor_id': widget.currentUserId.toString(),
          'user_id': userId.toString(),
          'action': approve ? 'approve' : 'reject',
        },
      ).timeout(const Duration(seconds: 12));
      final decoded = json.decode(res.body);
      if (res.statusCode != 200 || decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded is Map ? (decoded['error'] ?? 'Ошибка') : 'HTTP ${res.statusCode}');
      }
      await _load();
      _toast(approve ? 'Заявка принята' : 'Заявка отклонена');
    } catch (e) {
      _toast('Не удалось обработать заявку: $e');
    }
  }

  Future<void> _setRole(Map<String, dynamic> member, String role) async {
    if (!_isOwner) return;
    final userId = int.tryParse('${member['user_id'] ?? member['id'] ?? 0}') ?? 0;
    if (userId <= 0) return;
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/channel_set_role.php'),
        body: <String, String>{
          'chat_id': widget.chatId.toString(),
          'actor_id': widget.currentUserId.toString(),
          'user_id': userId.toString(),
          'role': role,
        },
      );
      final decoded = json.decode(res.body);
      if (res.statusCode != 200 || decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded is Map ? (decoded['error'] ?? 'Ошибка') : 'HTTP ${res.statusCode}');
      }
      await _load();
    } catch (e) {
      _toast('Не удалось изменить роль: $e');
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    if (!_isAdmin) return;
    final userId = int.tryParse('${member['user_id'] ?? member['id'] ?? 0}') ?? 0;
    if (userId <= 0 || userId == widget.currentUserId) return;
    final name = _displayName(member);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить подписчика?'),
        content: Text('$name будет удалён из канала.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: _ChannelManageUi.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/channel_remove_member.php'),
        body: <String, String>{
          'chat_id': widget.chatId.toString(),
          'actor_id': widget.currentUserId.toString(),
          'user_id': userId.toString(),
        },
      );
      final decoded = json.decode(res.body);
      if (res.statusCode != 200 || decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded is Map ? (decoded['error'] ?? 'Ошибка') : 'HTTP ${res.statusCode}');
      }
      await _load();
    } catch (e) {
      _toast('Не удалось удалить подписчика: $e');
    }
  }

  Future<void> _searchUsers(String value) async {
    final q = value.trim();
    if (q.length < 2) {
      if (mounted) setState(() => _searchResults = <Map<String, dynamic>>[]);
      return;
    }
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        '$_apiBase/search_users.php?q=${Uri.encodeComponent(q)}&exclude=${widget.currentUserId}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final decoded = json.decode(res.body);
      final list = decoded is List
          ? decoded
          : decoded is Map
              ? (decoded['users'] ?? decoded['data'] ?? const <dynamic>[])
              : const <dynamic>[];
      if (!mounted) return;
      setState(() {
        _searchResults = (list as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _searchResults = <Map<String, dynamic>>[]);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addMember(Map<String, dynamic> user) async {
    final userId = int.tryParse('${user['id'] ?? user['user_id'] ?? 0}') ?? 0;
    if (userId <= 0) return;
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/channel_add_member.php'),
        body: <String, String>{
          'chat_id': widget.chatId.toString(),
          'actor_id': widget.currentUserId.toString(),
          'user_id': userId.toString(),
        },
      );
      final decoded = json.decode(res.body);
      if (res.statusCode != 200 || decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded is Map ? (decoded['error'] ?? 'Ошибка') : 'HTTP ${res.statusCode}');
      }
      _searchController.clear();
      setState(() => _searchResults = <Map<String, dynamic>>[]);
      await _load();
      _toast('Пользователь добавлен');
    } catch (e) {
      _toast('Не удалось добавить: $e');
    }
  }

  Future<void> _leaveOrDeleteChannel() async {
    if (_closing) return;
    final owner = _isOwner;
    final title = (_channel['name'] ?? 'канал').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(owner ? 'Удалить канал?' : 'Покинуть канал?'),
        content: Text(
          owner
              ? '«$title» будет удалён. Подписчики потеряют доступ к каналу.'
              : 'Вы отпишетесь от «$title». Для закрытого канала повторный вход снова потребует одобрения.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              owner ? 'Удалить' : 'Покинуть',
              style: const TextStyle(color: _ChannelManageUi.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _closing = true);
    try {
      final endpoint = owner ? 'delete_channel.php' : 'leave_channel.php';
      final res = await http.post(
        Uri.parse('$_apiBase/$endpoint'),
        body: <String, String>{
          'chat_id': widget.chatId.toString(),
          'user_id': widget.currentUserId.toString(),
        },
      ).timeout(const Duration(seconds: 12));
      final decoded = json.decode(res.body);
      if (res.statusCode != 200 || decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded is Map ? (decoded['error'] ?? 'Ошибка') : 'HTTP ${res.statusCode}');
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _toast(owner ? 'Не удалось удалить канал: $e' : 'Не удалось покинуть канал: $e');
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  String _displayName(Map<String, dynamic> user) {
    final first = (user['first_name'] ?? user['firstname'] ?? '').toString().trim();
    final last = (user['last_name'] ?? user['lastname'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final email = (user['email'] ?? '').toString().trim();
    return email.isNotEmpty ? email : 'Пользователь';
  }

  Future<void> _copyChannelAddress() async {
    final username = (_channel['username'] ?? '').toString().trim();
    final value = username.isNotEmpty ? '@$username' : 'channel:${widget.chatId}';
    await Clipboard.setData(ClipboardData(text: value));
    _toast(username.isNotEmpty ? 'Адрес @$username скопирован' : 'ID канала скопирован');
  }

  Widget _avatar(Map<String, dynamic> user, {double size = 42}) {
    final raw = user['photo'] ?? user['avatar'] ?? user['avatar_url'] ?? user['photo_url'];
    final url = _photo(raw);
    final name = _displayName(user);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _ChannelManageUi.greenSoft,
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: _ChannelManageUi.border),
      ),
      child: url.isNotEmpty
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initial(name))
          : _initial(name),
    );
  }

  Widget _initial(String name) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Center(
      child: Text(
        letter,
        style: AppTypography.itemTitle(color: _ChannelManageUi.greenDark)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _ChannelManageUi.greenSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _ChannelManageUi.greenDark, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: _ChannelManageUi.title(13.6)),
              const SizedBox(height: 2),
              Text(subtitle, style: _ChannelManageUi.mutedText(10.8)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCard() {
    final avatarUrl = _photo(_channel['avatar_url']);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              InkWell(
                onTap: _isAdmin ? _pickAvatar : null,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 70,
                  height: 70,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _ChannelManageUi.greenSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _ChannelManageUi.border),
                  ),
                  child: _avatar != null
                      ? Image.file(File(_avatar!.path), fit: BoxFit.cover)
                      : avatarUrl.isNotEmpty
                          ? Image.network(avatarUrl, fit: BoxFit.cover)
                          : const Icon(Icons.campaign_rounded, color: _ChannelManageUi.greenDark, size: 27),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      (_channel['name'] ?? 'Канал').toString(),
                      style: _ChannelManageUi.title(16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_members.length} подписчиков · ${_isPublic ? 'открытый' : 'закрытый'}',
                      style: _ChannelManageUi.mutedText(11),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        ActionChip(
                          avatar: const Icon(Icons.link_rounded, size: 16),
                          label: const Text('Адрес'),
                          onPressed: _copyChannelAddress,
                        ),
                        if (_isAdmin)
                          ActionChip(
                            avatar: const Icon(Icons.photo_camera_outlined, size: 16),
                            label: const Text('Логотип'),
                            onPressed: _pickAvatar,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isAdmin) ...<Widget>[
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Название', counterText: ''),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Описание', counterText: ''),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              maxLength: 32,
              decoration: const InputDecoration(labelText: '@адрес канала', counterText: ''),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isPublic,
              activeColor: _ChannelManageUi.green,
              title: Text(_isPublic ? 'Открытый канал' : 'Закрытый канал'),
              subtitle: Text(
                _isPublic
                    ? 'Подписка без подтверждения.'
                    : 'Новые пользователи отправляют заявки.',
              ),
              onChanged: (value) => setState(() => _isPublic = value),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ChannelManageUi.green,
                  foregroundColor: Colors.white,
                ),
                icon: _saving
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Сохранить настройки'),
              ),
            ),
          ] else if ((_channel['description'] ?? '').toString().trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                (_channel['description'] ?? '').toString(),
                style: AppTypography.body(color: _ChannelManageUi.text),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _requestsCard() {
    if (!_isAdmin) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle(
            'Заявки на вступление',
            _requests.isEmpty ? 'Новых заявок нет' : '${_requests.length} ожидают решения',
            Icons.how_to_reg_rounded,
          ),
          if (_requests.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ..._requests.map((request) {
              final userId = int.tryParse('${request['user_id'] ?? request['id'] ?? 0}') ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _ChannelManageUi.bg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: <Widget>[
                      _avatar(request),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(_displayName(request), style: _ChannelManageUi.title(12.8)),
                            const SizedBox(height: 2),
                            Text((request['email'] ?? '').toString(), style: _ChannelManageUi.mutedText(10.3)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Отклонить',
                        onPressed: () => _handleRequest(userId, false),
                        icon: const Icon(Icons.close_rounded, color: _ChannelManageUi.red),
                      ),
                      IconButton(
                        tooltip: 'Принять',
                        onPressed: () => _handleRequest(userId, true),
                        icon: const Icon(Icons.check_circle_rounded, color: _ChannelManageUi.green),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _addMemberCard() {
    if (!_isAdmin) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle('Добавить подписчика', 'Пригласить пользователя напрямую', Icons.person_add_alt_1_rounded),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: InputDecoration(
              hintText: 'Поиск пользователей',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
          if (_searchResults.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ..._searchResults.take(6).map((user) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _avatar(user),
                  title: Text(_displayName(user)),
                  subtitle: Text((user['email'] ?? '').toString()),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_rounded, color: _ChannelManageUi.green),
                    onPressed: () => _addMember(user),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _membersCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle('Подписчики', '${_members.length} в канале', Icons.groups_2_rounded),
          const SizedBox(height: 10),
          if (_members.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Center(child: Text('Подписчиков пока нет', style: _ChannelManageUi.mutedText(11))),
            )
          else
            ..._members.map((member) {
              final role = (member['role'] ?? 'subscriber').toString().toLowerCase();
              final userId = int.tryParse('${member['user_id'] ?? member['id'] ?? 0}') ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(color: _ChannelManageUi.bg, borderRadius: BorderRadius.circular(13)),
                  child: Row(
                    children: <Widget>[
                      _avatar(member),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(_displayName(member), style: _ChannelManageUi.title(12.8)),
                            const SizedBox(height: 2),
                            Text(
                              role == 'owner'
                                  ? 'Владелец'
                                  : role == 'admin'
                                      ? 'Администратор · может публиковать'
                                      : 'Подписчик',
                              style: _ChannelManageUi.mutedText(10.2),
                            ),
                          ],
                        ),
                      ),
                      if (_isOwner && role != 'owner')
                        PopupMenuButton<String>(
                          tooltip: 'Права',
                          onSelected: (value) {
                            if (value == 'admin' || value == 'subscriber') {
                              _setRole(member, value);
                            } else if (value == 'remove') {
                              _removeMember(member);
                            }
                          },
                          itemBuilder: (_) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: role == 'admin' ? 'subscriber' : 'admin',
                              child: Text(role == 'admin' ? 'Снять администратора' : 'Сделать администратором'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem<String>(
                              value: 'remove',
                              child: Text('Удалить из канала', style: TextStyle(color: _ChannelManageUi.red)),
                            ),
                          ],
                        )
                      else if (_isAdmin && role == 'subscriber' && userId != widget.currentUserId)
                        IconButton(
                          tooltip: 'Удалить из канала',
                          onPressed: () => _removeMember(member),
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: _ChannelManageUi.red),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _dangerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: _closing ? null : _leaveOrDeleteChannel,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isOwner ? Icons.delete_outline_rounded : Icons.logout_rounded,
                  color: _ChannelManageUi.red,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _isOwner ? 'Удалить канал' : 'Покинуть канал',
                      style: _ChannelManageUi.title(12.8).copyWith(
                        color: _ChannelManageUi.red,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isOwner
                          ? 'Удаление доступно только владельцу'
                          : 'Отписаться от канала',
                      style: _ChannelManageUi.mutedText(10.3),
                    ),
                  ],
                ),
              ),
              if (_closing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: _ChannelManageUi.muted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ChannelManageUi.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text('Канал', style: _ChannelManageUi.title(16)),
        actions: <Widget>[
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _ChannelManageUi.green))
          : RefreshIndicator(
              color: _ChannelManageUi.green,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(12, 12, 12, MediaQuery.paddingOf(context).bottom + 20),
                children: <Widget>[
                  _infoCard(),
                  const SizedBox(height: 9),
                  _requestsCard(),
                  if (_isAdmin) const SizedBox(height: 9),
                  _addMemberCard(),
                  if (_isAdmin) const SizedBox(height: 9),
                  _membersCard(),
                  const SizedBox(height: 9),
                  _dangerCard(),
                ],
              ),
            ),
    );
  }
}
