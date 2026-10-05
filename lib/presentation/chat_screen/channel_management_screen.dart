import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';

class _ChannelManageUi {
  static const Color bg = Colors.white;
  static const Color surface = Color(0xFFF8FAF9);
  static const Color card = Colors.white;
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF0FAF5);
  static const Color mint = Color(0xFFE2F7EA);
  static const Color border = Color(0xFFE3E9E6);
  static const Color line = Color(0xFFEDF1EF);
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

  /// На планшете и desktop управление открывается в правой области чата.
  final bool embedded;
  final bool showTabs;
  final int initialTab;
  final VoidCallback? onRemoved;
  final VoidCallback? onUpdated;

  const ChannelManagementScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    this.embedded = false,
    this.showTabs = true,
    this.initialTab = 0,
    this.onRemoved,
    this.onUpdated,
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
  int _tab = 0;
  XFile? _avatar;

  String get _myRole => (_channel['my_role'] ?? '').toString().toLowerCase();
  bool get _isOwner => _myRole == 'owner';
  bool get _isAdmin => _myRole == 'admin' || _isOwner;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab == 1 ? 1 : 0;
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
    var raw = (rawValue ?? '').toString().trim().replaceAll('\\', '/');
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    while (raw.contains('/uploads/uploads/')) {
      raw = raw.replaceAll('/uploads/uploads/', '/uploads/');
    }
    while (raw.startsWith('uploads/uploads/')) {
      raw = raw.substring('uploads/'.length);
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    if (raw.startsWith('uploads/') || raw.startsWith('api/')) return 'https://sportotekaapp.ru/$raw';
    return 'https://sportotekaapp.ru/uploads/$raw';
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
      widget.onUpdated?.call();
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
      if (widget.embedded) {
        widget.onRemoved?.call();
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      _toast(owner ? 'Не удалось удалить канал: $e' : 'Не удалось покинуть канал: $e');
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _openUserProfile(Map<String, dynamic> user) async {
    final userId = int.tryParse('${user['user_id'] ?? user['id'] ?? 0}') ?? 0;
    if (userId <= 0 || userId == widget.currentUserId) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyProfileScreen(userId: userId, publicView: true),
      ),
    );
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

  Widget _userAvatar(Map<String, dynamic> user, {double size = 42}) {
    final raw = user['photo'] ??
        user['photo_url'] ??
        user['avatar'] ??
        user['avatar_url'] ??
        user['user_photo'] ??
        user['user_avatar'];
    final url = _photo(raw);
    final name = _displayName(user);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _ChannelManageUi.greenSoft,
        borderRadius: BorderRadius.circular(size * .28),
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

  Widget _brandDots({Color color = _ChannelManageUi.green, bool compact = false}) {
    final scale = compact ? .78 : 1.0;
    Widget dot(double size, double opacity) => Container(
          width: size * scale,
          height: size * scale,
          decoration: BoxDecoration(
            color: color.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        dot(3.4, .32),
        SizedBox(width: 3 * scale),
        dot(4.4, .55),
        SizedBox(width: 3 * scale),
        dot(5.4, .78),
        SizedBox(width: 3 * scale),
        dot(6.4, 1),
      ],
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: _ChannelManageUi.surface,
      borderRadius: BorderRadius.circular(16),
    );
  }

  Widget _channelAvatar({double size = 44}) {
    final avatarUrl = _photo(_channel['avatar_url']);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _ChannelManageUi.greenSoft,
        borderRadius: BorderRadius.circular(size * .30),
      ),
      child: _avatar != null
          ? Image.file(
              File(_avatar!.path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.campaign_rounded,
                color: _ChannelManageUi.greenDark,
              ),
            )
          : avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.campaign_rounded,
                    color: _ChannelManageUi.greenDark,
                  ),
                )
              : const Icon(
                  Icons.campaign_rounded,
                  color: _ChannelManageUi.greenDark,
                  size: 21,
                ),
    );
  }

  Widget _topHeader() {
    final channelName = (_channel['name'] ?? 'Канал').toString().trim();
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: <Widget>[
          Material(
            color: _ChannelManageUi.surface,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 21,
                  color: _ChannelManageUi.text,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          _channelAvatar(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  channelName.isEmpty ? 'Канал' : channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ChannelManageUi.title(15.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_members.length} подписчиков · ${_isPublic ? 'открытый канал' : 'закрытый канал'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ChannelManageUi.mutedText(10.6),
                ),
              ],
            ),
          ),
          Material(
            color: _ChannelManageUi.surface,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _loading ? null : _load,
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: _ChannelManageUi.greenDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 9),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _tabButton(
              selected: _tab == 0,
              icon: Icons.groups_2_rounded,
              title: 'Подписчики',
              badge: '${_members.length}',
              onTap: () => setState(() => _tab = 0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _tabButton(
              selected: _tab == 1,
              icon: Icons.tune_rounded,
              title: 'Настройки',
              badge: _requests.isNotEmpty && _isAdmin ? '${_requests.length}' : null,
              onTap: () => setState(() => _tab = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required bool selected,
    required IconData icon,
    required String title,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? _ChannelManageUi.greenSoft : _ChannelManageUi.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: selected
                    ? _ChannelManageUi.greenDark
                    : _ChannelManageUi.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(
                    color: selected
                        ? _ChannelManageUi.greenDark
                        : _ChannelManageUi.text,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (badge != null) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: AppTypography.caption(
                      color: _ChannelManageUi.greenDark,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _manageField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: _ChannelManageUi.title(11.6)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _ChannelManageUi.mutedText(10.5),
            counterText: '',
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 17, color: _ChannelManageUi.greenDark),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
          ),
          style: AppTypography.formText(color: _ChannelManageUi.text),
        ),
      ],
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
              Row(
                children: <Widget>[
                  Flexible(child: Text(title, style: _ChannelManageUi.title(13.6))),
                  const SizedBox(width: 7),
                  _brandDots(compact: true),
                ],
              ),
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
    final channelName = (_channel['name'] ?? 'Канал').toString();
    final username = (_channel['username'] ?? '').toString().trim();
    final roleLabel = _isOwner
        ? 'Владелец'
        : _myRole == 'admin'
            ? 'Администратор'
            : 'Подписчик';

    return Container(
      decoration: _panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF087A49),
                  Color(0xFF00A750),
                ],
              ),
            ),
            child: Row(
              children: <Widget>[
                InkWell(
                  onTap: _isAdmin ? _pickAvatar : null,
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Container(
                        width: 68,
                        height: 68,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0x40FFFFFF)),
                        ),
                        child: _avatar != null
                            ? Image.file(File(_avatar!.path), fit: BoxFit.cover)
                            : avatarUrl.isNotEmpty
                                ? Image.network(avatarUrl, fit: BoxFit.cover)
                                : const Icon(Icons.campaign_rounded,
                                    color: Colors.white, size: 27),
                      ),
                      if (_isAdmin)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0x24000000)),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 13,
                              color: _ChannelManageUi.greenDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _brandDots(color: Colors.white, compact: true),
                          const SizedBox(width: 7),
                          Text(
                            'CHANNEL',
                            style: AppTypography.caption(color: Colors.white)
                                .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        channelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.screenTitle(color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_members.length} подписчиков · ${_isPublic ? 'открытый' : 'закрытый'}',
                        style: AppTypography.caption(color: const Color(0xE8FFFFFF))
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x1FFFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x28FFFFFF)),
                  ),
                  child: Text(
                    roleLabel,
                    style: AppTypography.caption(color: Colors.white)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Material(
                        color: _ChannelManageUi.greenSoft,
                        borderRadius: BorderRadius.circular(11),
                        child: InkWell(
                          onTap: _copyChannelAddress,
                          borderRadius: BorderRadius.circular(11),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(Icons.link_rounded,
                                    size: 15, color: _ChannelManageUi.greenDark),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    username.isNotEmpty ? '@$username' : 'Скопировать ID',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption(color: _ChannelManageUi.greenDark)
                                        .copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_isAdmin) ...<Widget>[
                      const SizedBox(width: 8),
                      Material(
                        color: _ChannelManageUi.greenSoft,
                        borderRadius: BorderRadius.circular(11),
                        child: InkWell(
                          onTap: _pickAvatar,
                          borderRadius: BorderRadius.circular(11),
                          child: const SizedBox(
                            width: 39,
                            height: 35,
                            child: Icon(Icons.photo_camera_outlined,
                                size: 16, color: _ChannelManageUi.greenDark),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_isAdmin) ...<Widget>[
                  const SizedBox(height: 13),
                  _manageField(
                    controller: _nameController,
                    label: 'Название',
                    hint: 'Название канала',
                    icon: Icons.edit_rounded,
                    maxLength: 80,
                  ),
                  const SizedBox(height: 10),
                  _manageField(
                    controller: _descriptionController,
                    label: 'Описание',
                    hint: 'О чём ваш канал',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 10),
                  _manageField(
                    controller: _usernameController,
                    label: 'Публичный адрес',
                    hint: '@адрес_канала',
                    icon: Icons.alternate_email_rounded,
                    maxLength: 32,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _ChannelManageUi.greenSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                            size: 16,
                            color: _ChannelManageUi.greenDark,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _isPublic ? 'Открытый канал' : 'Закрытый канал',
                                style: _ChannelManageUi.title(11.8),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isPublic
                                    ? 'Подписка без подтверждения'
                                    : 'Новые пользователи отправляют заявки',
                                style: _ChannelManageUi.mutedText(9.7),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isPublic,
                          activeColor: _ChannelManageUi.green,
                          onChanged: (value) => setState(() => _isPublic = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ChannelManageUi.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 17),
                      label: Text(
                        _saving ? 'Сохраняем...' : 'Сохранить настройки',
                        style: AppTypography.actionStrong(color: Colors.white),
                      ),
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
          ),
        ],
      ),
    );
  }

  Widget _requestsCard() {
    if (!_isAdmin) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
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
                    color: _ChannelManageUi.surface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: InkWell(
                          onTap: () => _openUserProfile(request),
                          borderRadius: BorderRadius.circular(11),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: <Widget>[
                                _userAvatar(request),
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
                              ],
                            ),
                          ),
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
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle('Добавить подписчика', 'Пригласить пользователя напрямую', Icons.person_add_alt_1_rounded),
          const SizedBox(height: 10),
          _manageField(
            controller: _searchController,
            label: 'Поиск',
            hint: _searching ? 'Ищем...' : 'Имя или email пользователя',
            icon: Icons.search_rounded,
            onChanged: _searchUsers,
          ),
          if (_searchResults.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ..._searchResults.take(6).map((user) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _openUserProfile(user),
                  leading: _userAvatar(user),
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
      decoration: _panelDecoration(),
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
                  decoration: BoxDecoration(color: _ChannelManageUi.surface, borderRadius: BorderRadius.circular(13)),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: InkWell(
                          onTap: () => _openUserProfile(member),
                          borderRadius: BorderRadius.circular(11),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: <Widget>[
                                _userAvatar(member),
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
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_isOwner && role != 'owner') ...<Widget>[
                        PopupMenuButton<String>(
                          tooltip: 'Права подписчика',
                          icon: const Icon(Icons.admin_panel_settings_outlined, size: 19, color: _ChannelManageUi.greenDark),
                          onSelected: (value) {
                            if (value == 'admin' || value == 'subscriber') {
                              _setRole(member, value);
                            }
                          },
                          itemBuilder: (_) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: role == 'admin' ? 'subscriber' : 'admin',
                              child: Text(role == 'admin' ? 'Снять администратора' : 'Сделать администратором'),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Удалить подписчика',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _removeMember(member),
                          icon: const Icon(Icons.person_remove_alt_1_rounded, color: _ChannelManageUi.red, size: 19),
                        ),
                      ]
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

  Widget _subscribersTab() {
    return RefreshIndicator(
      color: _ChannelManageUi.green,
      onRefresh: _load,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          MediaQuery.paddingOf(context).bottom + 20,
        ),
        children: <Widget>[
          if (_isAdmin) _requestsCard(),
          if (_isAdmin) const SizedBox(height: 10),
          if (_isAdmin) _addMemberCard(),
          if (_isAdmin) const SizedBox(height: 10),
          _membersCard(),
        ],
      ),
    );
  }

  Widget _settingsSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _brandDots(compact: true),
          const SizedBox(width: 8),
          Text(title, style: _ChannelManageUi.title(12.2)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _ChannelManageUi.mutedText(9.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelSettingsCard() {
    final username = (_channel['username'] ?? '').toString().trim();
    final description = (_channel['description'] ?? '').toString().trim();
    final roleLabel = _isOwner
        ? 'Владелец'
        : _myRole == 'admin'
            ? 'Администратор'
            : 'Подписчик';

    return Container(
      decoration: _panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                _channelAvatar(size: 46),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Логотип канала', style: _ChannelManageUi.title(11.8)),
                      const SizedBox(height: 2),
                      Text(
                        roleLabel,
                        style: _ChannelManageUi.mutedText(9.8),
                      ),
                    ],
                  ),
                ),
                if (_isAdmin)
                  Material(
                    color: _ChannelManageUi.greenSoft,
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(
                      onTap: _pickAvatar,
                      borderRadius: BorderRadius.circular(11),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.photo_camera_outlined,
                              size: 16,
                              color: _ChannelManageUi.greenDark,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Изменить',
                              style: AppTypography.caption(
                                color: _ChannelManageUi.greenDark,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  _manageField(
                    controller: _nameController,
                    label: 'Название',
                    hint: 'Название канала',
                    icon: Icons.edit_rounded,
                    maxLength: 80,
                  ),
                  const SizedBox(height: 10),
                  _manageField(
                    controller: _descriptionController,
                    label: 'Описание',
                    hint: 'О чём ваш канал',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 10),
                  _manageField(
                    controller: _usernameController,
                    label: 'Публичный адрес',
                    hint: '@адрес_канала',
                    icon: Icons.alternate_email_rounded,
                    maxLength: 32,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _ChannelManageUi.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _ChannelManageUi.border),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _ChannelManageUi.greenSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _isPublic
                                ? Icons.public_rounded
                                : Icons.lock_outline_rounded,
                            size: 16,
                            color: _ChannelManageUi.greenDark,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _isPublic ? 'Открытый канал' : 'Закрытый канал',
                                style: _ChannelManageUi.title(11.8),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isPublic
                                    ? 'Подписка без подтверждения'
                                    : 'Новые пользователи отправляют заявки',
                                style: _ChannelManageUi.mutedText(9.7),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _isPublic,
                          activeColor: _ChannelManageUi.green,
                          onChanged: (value) => setState(() => _isPublic = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: _ChannelManageUi.greenSoft,
                      borderRadius: BorderRadius.circular(11),
                      child: InkWell(
                        onTap: _saving ? null : _save,
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (_saving)
                                const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _ChannelManageUi.greenDark,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: _ChannelManageUi.greenDark,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                _saving ? 'Сохраняем...' : 'Сохранить',
                                style: AppTypography.caption(
                                  color: _ChannelManageUi.greenDark,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  InkWell(
                    onTap: _copyChannelAddress,
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.link_rounded,
                            size: 16,
                            color: _ChannelManageUi.greenDark,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              username.isNotEmpty ? '@$username' : 'ID канала ${widget.chatId}',
                              style: AppTypography.caption(
                                color: _ChannelManageUi.greenDark,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        description,
                        style: AppTypography.body(color: _ChannelManageUi.text),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _channelSettingsTab() {
    return RefreshIndicator(
      color: _ChannelManageUi.green,
      onRefresh: _load,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          MediaQuery.paddingOf(context).bottom + 20,
        ),
        children: <Widget>[
          _settingsSectionTitle('Канал', 'Оформление и доступ'),
          const SizedBox(height: 7),
          _channelSettingsCard(),
          const SizedBox(height: 14),
          _settingsSectionTitle(
            'Действия',
            _isOwner ? 'Управление каналом' : 'Ваша подписка на канал',
          ),
          const SizedBox(height: 7),
          _dangerCard(),
        ],
      ),
    );
  }

  Widget _dangerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
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

  Widget _content({required bool includeHeader}) {
    return Container(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          if (includeHeader) _topHeader(),
          if (widget.showTabs) _tabs(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _ChannelManageUi.green,
                    ),
                  )
                : _tab == 0
                    ? _subscribersTab()
                    : _channelSettingsTab(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _content(includeHeader: false);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _content(includeHeader: true)),
    );
  }

}
