import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';

class _GroupInfoUi {
  static const Color bg = Color(0xFFF7F9F8);
  static const Color card = Colors.white;
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color border = Color(0xFFEDF0EE);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF667085);
  static const Color muted2 = Color(0xFF98A2B3);
  static const Color red = Color(0xFFD92D20);
  static const Color amber = Color(0xFFF59E0B);

  static TextStyle title(double size) {
    final base = size >= 15
        ? AppTypography.screenTitle(color: text)
        : size >= 13.2
            ? AppTypography.sectionTitle(color: text)
            : AppTypography.itemTitle(color: text);
    return base.copyWith(fontWeight: FontWeight.w700);
  }

  static TextStyle body(double size, {Color color = muted, FontWeight weight = FontWeight.w500}) {
    final base = size >= 11.3
        ? AppTypography.secondary(color: color)
        : AppTypography.caption(color: color);
    return base.copyWith(fontWeight: weight);
  }
}

class EditGroupChatScreen extends StatefulWidget {
  final int chatId;
  final int currentUserId;
  final String chatName;
  final String groupAvatarUrl;

  const EditGroupChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.chatName,
    this.groupAvatarUrl = '',
  });

  @override
  State<EditGroupChatScreen> createState() => _EditGroupChatScreenState();
}

class _EditGroupChatScreenState extends State<EditGroupChatScreen> {
  static const _apiBase = 'https://sportotekaapp.ru/api';

  final TextEditingController _searchController = TextEditingController();
  late final TextEditingController _nameController;
  Timer? _searchDebounce;

  List<Map<String, dynamic>> members = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[];

  bool isSearching = false;
  bool isLoadingMembers = false;
  bool isLoadingInfo = false;
  bool isSavingName = false;
  bool isSavingVisibility = false;
  bool _isOwner = false;
  bool _isPublic = true;
  int _ownerId = 0;
  int _memberCount = 0;
  int _tab = 0;
  String _groupName = '';
  String? lastError;

  @override
  void initState() {
    super.initState();
    _groupName = widget.chatName.trim().isEmpty ? 'Группа' : widget.chatName.trim();
    _nameController = TextEditingController(text: _groupName);
    unawaited(_loadGroupInfo());
    unawaited(_loadMembers());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _sanitizeBody(String body) {
    var value = body;
    if (value.isNotEmpty && value.codeUnitAt(0) == 0xFEFF) {
      value = value.substring(1);
    }
    return value.trimLeft();
  }

  dynamic _decodeJson(String body) {
    final text = _sanitizeBody(body);
    if (text.isEmpty) return null;
    if (!(text.startsWith('{') || text.startsWith('['))) {
      final preview = text.substring(0, text.length > 180 ? 180 : text.length);
      throw FormatException('Ответ сервера не JSON: $preview');
    }
    return json.decode(text);
  }

  List<Map<String, dynamic>> _parseList(dynamic body) {
    final raw = body is List
        ? body
        : (body is Map
            ? (body['members'] ?? body['users'] ?? body['data'] ?? body['list'] ?? const [])
            : const []);
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _normalizeMediaUrl(dynamic rawValue) {
    var raw = (rawValue ?? '').toString().trim().replaceAll('\\', '/');
    if (raw.isEmpty || const {'null', 'undefined', 'false', '0'}.contains(raw.toLowerCase())) {
      return '';
    }

    // Некоторые старые API уже возвращают "uploads/...", а другой слой снова
    // добавляет uploads. Нормализуем и абсолютные, и относительные варианты.
    while (raw.contains('/uploads/uploads/')) {
      raw = raw.replaceAll('/uploads/uploads/', '/uploads/');
    }
    while (raw.startsWith('uploads/uploads/')) {
      raw = raw.substring('uploads/'.length);
    }

    if (raw.startsWith('https://') || raw.startsWith('http://')) return raw;
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    if (raw.startsWith('uploads/') || raw.startsWith('api/')) {
      return 'https://sportotekaapp.ru/$raw';
    }
    return 'https://sportotekaapp.ru/uploads/$raw';
  }

  ({int? id, String first, String last, String email, String avatar}) _u(
    Map<String, dynamic> source,
  ) {
    final rawId = source['id'] ?? source['user_id'];
    final id = rawId is int ? rawId : int.tryParse('${rawId ?? ''}');
    final first = (source['first_name'] ?? source['firstname'] ?? '').toString().trim();
    final last = (source['last_name'] ?? source['lastname'] ?? '').toString().trim();
    final email = (source['email'] ?? '').toString().trim();
    final rawAvatar = source['photo'] ??
        source['photo_url'] ??
        source['avatar'] ??
        source['avatar_url'] ??
        source['user_photo'] ??
        source['user_avatar'];
    return (
      id: id,
      first: first,
      last: last,
      email: email,
      avatar: _normalizeMediaUrl(rawAvatar),
    );
  }

  String _displayName(({int? id, String first, String last, String email, String avatar}) data) {
    final name = '${data.first} ${data.last}'.trim();
    if (name.isNotEmpty) return name;
    if (data.email.isNotEmpty) return data.email;
    return 'Пользователь';
  }

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? _GroupInfoUi.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadGroupInfo() async {
    if (!mounted) return;
    setState(() => isLoadingInfo = true);
    try {
      final uri = Uri.parse('$_apiBase/group_manage.php').replace(queryParameters: {
        'chat_id': widget.chatId.toString(),
        'user_id': widget.currentUserId.toString(),
      });
      final res = await http.get(uri, headers: const {'Accept': 'application/json'});
      final data = _decodeJson(res.body);
      if (res.statusCode != 200 || data is! Map || data['success'] != true) {
        throw Exception(data is Map ? (data['error'] ?? 'HTTP ${res.statusCode}') : 'HTTP ${res.statusCode}');
      }
      final chat = data['chat'] is Map ? Map<String, dynamic>.from(data['chat']) : <String, dynamic>{};
      final name = (chat['name'] ?? _groupName).toString().trim();
      if (!mounted) return;
      setState(() {
        _ownerId = int.tryParse('${chat['owner_id'] ?? 0}') ?? 0;
        _isOwner = data['is_owner'] == true || _ownerId == widget.currentUserId;
        _isPublic = '${chat['is_public'] ?? 1}' == '1' || chat['is_public'] == true;
        _memberCount = int.tryParse('${data['member_count'] ?? members.length}') ?? members.length;
        if (name.isNotEmpty) {
          _groupName = name;
          if (_nameController.text != name) _nameController.text = name;
        }
      });
    } catch (e) {
      // Старые серверы без group_manage.php не должны ломать просмотр участников.
      if (!mounted) return;
      setState(() {
        _memberCount = members.length;
        _isOwner = false;
      });
      debugPrint('group_manage info: $e');
    } finally {
      if (mounted) setState(() => isLoadingInfo = false);
    }
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() {
      isLoadingMembers = true;
      lastError = null;
    });
    try {
      final uri = Uri.parse('$_apiBase/get_chat_members.php').replace(queryParameters: {
        'chat_id': widget.chatId.toString(),
      });
      final res = await http.get(uri, headers: const {'Accept': 'application/json'});
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final list = _parseList(_decodeJson(res.body));
      if (!mounted) return;
      setState(() {
        members = list;
        _memberCount = list.length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => lastError = 'Не удалось загрузить участников');
      debugPrint('get_chat_members: $e');
    } finally {
      if (mounted) setState(() => isLoadingMembers = false);
    }
  }

  void _searchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_searchUsers(value));
    });
    if (value.trim().isEmpty && mounted) {
      setState(() => searchResults = <Map<String, dynamic>>[]);
    }
  }

  Future<void> _searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (mounted) setState(() => searchResults = <Map<String, dynamic>>[]);
      return;
    }
    if (!mounted) return;
    setState(() {
      isSearching = true;
      lastError = null;
    });
    try {
      final uri = Uri.parse('$_apiBase/search_users.php').replace(queryParameters: {
        'q': q,
        'exclude': widget.currentUserId.toString(),
      });
      final res = await http.get(uri, headers: const {'Accept': 'application/json'});
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final list = _parseList(_decodeJson(res.body));
      if (!mounted || _searchController.text.trim() != q) return;
      setState(() => searchResults = list);
    } catch (e) {
      if (mounted) setState(() => lastError = 'Ошибка поиска пользователя');
      debugPrint('search_users: $e');
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
  }

  bool _alreadyMember(int? userId) {
    if (userId == null) return false;
    return members.any((m) => _u(m).id == userId);
  }

  Future<void> _addUserToChat(int userIdToAdd) async {
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/add_user_to_chat.php'),
        headers: const {'Accept': 'application/json'},
        body: {
          'chat_id': widget.chatId.toString(),
          'user_id': userIdToAdd.toString(),
          'actor_id': widget.currentUserId.toString(),
        },
      );
      final data = _decodeJson(res.body);
      final ok = res.statusCode == 200 && data is Map && (data['success'] == true || data['status'] == 'ok');
      if (!ok) {
        final reason = data is Map ? (data['error'] ?? data['message'] ?? 'Ошибка') : 'HTTP ${res.statusCode}';
        _toast('Не удалось добавить: $reason', error: true);
        return;
      }
      _toast('Участник добавлен');
      _searchController.clear();
      if (mounted) setState(() => searchResults = <Map<String, dynamic>>[]);
      await _loadMembers();
      unawaited(_loadGroupInfo());
    } catch (e) {
      _toast('Ошибка добавления', error: true);
    }
  }

  Future<void> _confirmAndRemoveUserFromChat(int userId, String userName) async {
    if (!_isOwner || userId == widget.currentUserId) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить участника?'),
        content: Text('$userName больше не будет участником этой группы.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _GroupInfoUi.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (sure != true) return;

    try {
      final res = await http.post(
        Uri.parse('$_apiBase/remove_user_from_chat.php'),
        headers: const {'Accept': 'application/json'},
        body: {
          'chat_id': widget.chatId.toString(),
          'user_id': userId.toString(),
          'actor_id': widget.currentUserId.toString(),
        },
      );
      final data = _decodeJson(res.body);
      final ok = res.statusCode == 200 && data is Map && (data['success'] == true || data['status'] == 'ok');
      if (!ok) {
        final reason = data is Map ? (data['error'] ?? data['message'] ?? 'Ошибка') : 'HTTP ${res.statusCode}';
        _toast('Не удалось удалить: $reason', error: true);
        return;
      }
      _toast('Участник удалён');
      await _loadMembers();
      unawaited(_loadGroupInfo());
    } catch (_) {
      _toast('Ошибка удаления участника', error: true);
    }
  }

  Future<void> _saveName() async {
    if (!_isOwner || isSavingName) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _toast('Введите название группы', error: true);
      return;
    }
    setState(() => isSavingName = true);
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/group_manage.php'),
        headers: const {'Accept': 'application/json'},
        body: {
          'action': 'rename',
          'chat_id': widget.chatId.toString(),
          'user_id': widget.currentUserId.toString(),
          'name': name,
        },
      );
      final data = _decodeJson(res.body);
      if (res.statusCode != 200 || data is! Map || data['success'] != true) {
        throw Exception(data is Map ? (data['error'] ?? 'Ошибка') : 'HTTP ${res.statusCode}');
      }
      if (!mounted) return;
      setState(() => _groupName = name);
      _toast('Название сохранено');
    } catch (e) {
      _toast('Не удалось переименовать группу', error: true);
    } finally {
      if (mounted) setState(() => isSavingName = false);
    }
  }

  Future<void> _setVisibility(bool value) async {
    if (!_isOwner || isSavingVisibility || value == _isPublic) return;
    setState(() => isSavingVisibility = true);
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/group_manage.php'),
        headers: const {'Accept': 'application/json'},
        body: {
          'action': 'visibility',
          'chat_id': widget.chatId.toString(),
          'user_id': widget.currentUserId.toString(),
          'is_public': value ? '1' : '0',
        },
      );
      final data = _decodeJson(res.body);
      if (res.statusCode != 200 || data is! Map || data['success'] != true) {
        throw Exception(data is Map ? (data['error'] ?? 'Ошибка') : 'HTTP ${res.statusCode}');
      }
      if (mounted) setState(() => _isPublic = value);
    } catch (_) {
      _toast('Не удалось изменить доступ', error: true);
    } finally {
      if (mounted) setState(() => isSavingVisibility = false);
    }
  }

  Future<void> _leaveOrDeleteGroup({required bool delete}) async {
    final verb = delete ? 'Удалить группу?' : 'Выйти из группы?';
    final body = delete
        ? 'Группа «$_groupName» и её история будут удалены. Действие необратимо.'
        : 'Вы больше не будете участником «$_groupName».';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(verb),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _GroupInfoUi.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(delete ? 'Удалить' : 'Выйти'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final res = await http.post(
        Uri.parse('$_apiBase/${delete ? 'delete_group_force.php' : 'leave_group.php'}'),
        body: {
          'chat_id': widget.chatId.toString(),
          'user_id': widget.currentUserId.toString(),
        },
      );
      final data = _decodeJson(res.body);
      if (res.statusCode != 200 || data is! Map || data['success'] != true) {
        throw Exception(data is Map ? (data['error'] ?? 'Ошибка') : 'HTTP ${res.statusCode}');
      }
      if (!mounted) return;
      Navigator.pop(context, <String, dynamic>{
        'removed': true,
        'deleted': delete,
        'name': _groupName,
      });
    } catch (_) {
      _toast(delete ? 'Не удалось удалить группу' : 'Не удалось выйти из группы', error: true);
    }
  }

  Widget _avatar(
    ({int? id, String first, String last, String email, String avatar}) data, {
    double size = 40,
    bool circle = false,
  }) {
    final title = _displayName(data);
    final initial = title.isNotEmpty ? title.substring(0, 1).toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _GroupInfoUi.greenSoft,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * .30),
        border: Border.all(color: _GroupInfoUi.border),
      ),
      child: data.avatar.isNotEmpty
          ? Image.network(
              data.avatar,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initial,
                  style: _GroupInfoUi.title(size * .31).copyWith(color: _GroupInfoUi.greenDark),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: _GroupInfoUi.title(size * .31).copyWith(color: _GroupInfoUi.greenDark),
              ),
            ),
    );
  }

  Widget _memberStack() {
    final groupAvatar = _normalizeMediaUrl(widget.groupAvatarUrl);
    if (groupAvatar.isNotEmpty) {
      return Container(
        width: 44,
        height: 44,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _GroupInfoUi.greenSoft,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Image.network(
          groupAvatar,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.groups_2_rounded, color: _GroupInfoUi.greenDark),
        ),
      );
    }

    final visible = members.take(3).map(_u).toList();
    if (visible.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: _GroupInfoUi.greenSoft, borderRadius: BorderRadius.circular(13)),
        child: const Icon(Icons.groups_2_rounded, color: _GroupInfoUi.greenDark, size: 20),
      );
    }
    return SizedBox(
      width: 44 + (visible.length - 1) * 13,
      height: 44,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * 13,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: _avatar(visible[i], size: 42, circle: true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white,
      child: Row(
        children: [
          Material(
            color: _GroupInfoUi.bg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context, <String, dynamic>{'name': _groupName}),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(Icons.chevron_left_rounded, size: 21, color: _GroupInfoUi.text),
              ),
            ),
          ),
          const SizedBox(width: 9),
          _memberStack(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_groupName, maxLines: 1, overflow: TextOverflow.ellipsis, style: _GroupInfoUi.title(15.5)),
                const SizedBox(height: 2),
                Text(
                  '${_memberCount > 0 ? _memberCount : members.length} участников · ${_isPublic ? 'открытая группа' : 'закрытая группа'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _GroupInfoUi.body(10.6),
                ),
              ],
            ),
          ),
          if (isLoadingInfo || isLoadingMembers)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: _GroupInfoUi.green)),
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
        children: [
          Expanded(
            child: _tabButton(
              selected: _tab == 0,
              icon: Icons.groups_2_rounded,
              title: 'Участники',
              badge: '${_memberCount > 0 ? _memberCount : members.length}',
              onTap: () => setState(() => _tab = 0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _tabButton(
              selected: _tab == 1,
              icon: Icons.tune_rounded,
              title: 'Настройки',
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
      color: selected ? _GroupInfoUi.greenSoft : _GroupInfoUi.bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFFDDEFE5) : _GroupInfoUi.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? _GroupInfoUi.greenDark : _GroupInfoUi.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _GroupInfoUi.body(
                    10.8,
                    color: selected ? _GroupInfoUi.greenDark : _GroupInfoUi.text,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                  child: Text(badge, style: _GroupInfoUi.body(9.3, color: _GroupInfoUi.greenDark, weight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    final q = _searchController.text.trim();
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _GroupInfoUi.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {});
          _searchChanged(value);
        },
        decoration: InputDecoration(
          hintText: 'Найти и добавить пользователя',
          hintStyle: _GroupInfoUi.body(10.8, color: _GroupInfoUi.muted2),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _GroupInfoUi.muted),
          suffixIcon: q.isNotEmpty
              ? IconButton(
                  tooltip: 'Очистить',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchResults = <Map<String, dynamic>>[]);
                  },
                  icon: const Icon(Icons.close_rounded, size: 17, color: _GroupInfoUi.muted),
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
        style: AppTypography.formText(color: _GroupInfoUi.text).copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _participantsTab() {
    final searching = _searchController.text.trim().isNotEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: _searchBar(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 7),
          child: Row(
            children: [
              Text(
                searching ? 'Результаты поиска' : 'Все участники',
                style: _GroupInfoUi.title(12.4),
              ),
              const Spacer(),
              Text(
                searching ? '${searchResults.length}' : '${members.length}',
                style: _GroupInfoUi.body(10.2, color: _GroupInfoUi.greenDark, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Expanded(
          child: isSearching && searching
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _GroupInfoUi.green))
              : _peopleList(searching ? searchResults : members, searchMode: searching),
        ),
      ],
    );
  }

  Widget _peopleList(List<Map<String, dynamic>> source, {required bool searchMode}) {
    if (source.isEmpty) {
      final message = searchMode
          ? 'Никого не найдено\nПопробуйте имя, фамилию или e-mail'
          : (isLoadingMembers ? 'Загружаем участников…' : 'В группе пока нет участников');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center, style: _GroupInfoUi.body(11.3)),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(10, 0, 10, MediaQuery.paddingOf(context).bottom + 16),
      itemCount: source.length,
      separatorBuilder: (_, __) => const SizedBox(height: 3),
      itemBuilder: (context, index) {
        final data = _u(source[index]);
        final title = _displayName(data);
        final already = _alreadyMember(data.id);
        final isOwnerRow = data.id != null && data.id == _ownerId;
        final isMe = data.id == widget.currentUserId;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: searchMode && data.id != null && !already ? () => _addUserToChat(data.id!) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              child: Row(
                children: [
                  _avatar(data, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _GroupInfoUi.title(12.5),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 5),
                              Text('Вы', style: _GroupInfoUi.body(9.5, color: _GroupInfoUi.greenDark, weight: FontWeight.w700)),
                            ],
                          ],
                        ),
                        if (data.email.isNotEmpty || isOwnerRow) ...[
                          const SizedBox(height: 2),
                          Text(
                            isOwnerRow ? 'Владелец${data.email.isNotEmpty ? ' · ${data.email}' : ''}' : data.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _GroupInfoUi.body(9.8),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (searchMode)
                    already
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(color: _GroupInfoUi.bg, borderRadius: BorderRadius.circular(9)),
                            child: Text('В группе', style: _GroupInfoUi.body(9.4, weight: FontWeight.w600)),
                          )
                        : IconButton(
                            tooltip: 'Добавить',
                            visualDensity: VisualDensity.compact,
                            onPressed: data.id == null ? null : () => _addUserToChat(data.id!),
                            icon: const Icon(Icons.person_add_alt_1_rounded, color: _GroupInfoUi.greenDark, size: 19),
                          )
                  else if (_isOwner && !isMe)
                    IconButton(
                      tooltip: 'Удалить из группы',
                      visualDensity: VisualDensity.compact,
                      onPressed: data.id == null ? null : () => _confirmAndRemoveUserFromChat(data.id!, title),
                      icon: const Icon(Icons.remove_circle_rounded, color: _GroupInfoUi.red, size: 19),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _settingsTab() {
    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.paddingOf(context).bottom + 18),
      children: [
        _sectionTitle('Группа', 'Название и доступ'),
        const SizedBox(height: 7),
        _settingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: TextField(
                controller: _nameController,
                readOnly: !_isOwner,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveName(),
                decoration: InputDecoration(
                  labelText: 'Название группы',
                  labelStyle: _GroupInfoUi.body(10.6),
                  border: const OutlineInputBorder(borderSide: BorderSide(color: _GroupInfoUi.border)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(color: _GroupInfoUi.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(color: _GroupInfoUi.green, width: 1.1),
                  ),
                  isDense: true,
                ),
                style: AppTypography.formText(color: _GroupInfoUi.text).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (_isOwner)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: isSavingName ? null : _saveName,
                    style: FilledButton.styleFrom(
                      backgroundColor: _GroupInfoUi.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    icon: isSavingName
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 16),
                    label: const Text('Сохранить название'),
                  ),
                ),
              ),
            const Divider(height: 1, color: _GroupInfoUi.border),
            _visibilityRow(),
          ],
        ),
        const SizedBox(height: 14),
        _sectionTitle('Участники', '$_memberCount человек в группе'),
        const SizedBox(height: 7),
        _settingsCard(
          children: [
            _settingsAction(
              icon: Icons.groups_2_rounded,
              title: 'Список участников',
              subtitle: 'Просмотр, поиск, добавление${_isOwner ? ' и удаление' : ''}',
              onTap: () => setState(() => _tab = 0),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionTitle('Действия', _isOwner ? 'Управление группой' : 'Ваша подписка на группу'),
        const SizedBox(height: 7),
        _settingsCard(
          children: [
            if (!_isOwner)
              _settingsAction(
                icon: Icons.logout_rounded,
                title: 'Выйти из группы',
                subtitle: 'Группа исчезнет из вашего списка',
                danger: true,
                onTap: () => _leaveOrDeleteGroup(delete: false),
              ),
            if (_isOwner)
              _settingsAction(
                icon: Icons.delete_outline_rounded,
                title: 'Удалить группу',
                subtitle: 'Удалить группу и историю сообщений',
                danger: true,
                onTap: () => _leaveOrDeleteGroup(delete: true),
              ),
          ],
        ),
        if (lastError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _GroupInfoUi.red.withOpacity(.06), borderRadius: BorderRadius.circular(11)),
            child: Text(lastError!, style: _GroupInfoUi.body(10.2, color: _GroupInfoUi.red)),
          ),
        ],
      ],
    );
  }

  Widget _visibilityRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: _GroupInfoUi.greenSoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(_isPublic ? Icons.public_rounded : Icons.lock_rounded, size: 17, color: _GroupInfoUi.greenDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isPublic ? 'Открытая группа' : 'Закрытая группа', style: _GroupInfoUi.title(11.8)),
                const SizedBox(height: 2),
                Text(
                  _isPublic ? 'Пользователи могут вступать сами' : 'Добавление только через участников/владельца',
                  style: _GroupInfoUi.body(9.7),
                ),
              ],
            ),
          ),
          if (_isOwner)
            Switch.adaptive(
              value: _isPublic,
              activeColor: _GroupInfoUi.green,
              onChanged: isSavingVisibility ? null : _setVisibility,
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: _GroupInfoUi.title(12.2)),
          const SizedBox(width: 7),
          Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _GroupInfoUi.body(9.6))),
        ],
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _GroupInfoUi.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _settingsAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? _GroupInfoUi.red : _GroupInfoUi.greenDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: danger ? _GroupInfoUi.red.withOpacity(.07) : _GroupInfoUi.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _GroupInfoUi.title(11.7).copyWith(color: danger ? _GroupInfoUi.red : _GroupInfoUi.text)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: _GroupInfoUi.body(9.6)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: danger ? _GroupInfoUi.red : _GroupInfoUi.muted2),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _GroupInfoUi.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            const Divider(height: 1, thickness: .6, color: _GroupInfoUi.border),
            _tabs(),
            const Divider(height: 1, thickness: .6, color: _GroupInfoUi.border),
            Expanded(child: _tab == 0 ? _participantsTab() : _settingsTab()),
          ],
        ),
      ),
    );
  }
}
