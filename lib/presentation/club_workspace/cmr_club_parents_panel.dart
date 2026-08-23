import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_player_parent_access_panel.dart';

class CmrClubParentsPanel extends StatefulWidget {
  final int clubId;
  final String clubName;
  final int? selectedTeamId;
  final String selectedTeamName;
  final List<Map<String, dynamic>> players;
  final int currentUserId;
  final int? maxParents;
  final ValueChanged<Map<String, dynamic>>? onOpenPlayer;

  const CmrClubParentsPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.selectedTeamId,
    required this.selectedTeamName,
    required this.players,
    required this.currentUserId,
    this.maxParents,
    this.onOpenPlayer,
  });

  @override
  State<CmrClubParentsPanel> createState() => _CmrClubParentsPanelState();
}

enum _ParentFilter { all, linked, pending }

class _CmrClubParentsPanelState extends State<CmrClubParentsPanel> {
  static const _apiBase = 'https://sportotekaapp.ru/api';
  static const _listUrl = '$_apiBase/get_team_parents.php';
  static const _createInviteUrl = '$_apiBase/create_parent_invite.php';
  static const _revokeAccessUrl = '$_apiBase/revoke_parent_access.php';
  static const _revokeInviteUrl = '$_apiBase/revoke_parent_invite.php';

  final _searchC = TextEditingController();
  final _scrollC = ScrollController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  _ParentFilter _filter = _ParentFilter.all;
  List<Map<String, dynamic>> _parents = [];
  List<Map<String, dynamic>> _invites = [];
  String _selectedKey = '';
  bool _issueMode = false;
  int _issuePlayerId = 0;

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_refreshUi);
    _load();
  }

  @override
  void didUpdateWidget(covariant CmrClubParentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clubId != widget.clubId || oldWidget.selectedTeamId != widget.selectedTeamId) {
      _selectedKey = '';
      _issueMode = false;
      _issuePlayerId = 0;
      _load();
    }
  }

  @override
  void dispose() {
    _searchC.removeListener(_refreshUi);
    _searchC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  void _refreshUi() {
    if (mounted) setState(() {});
  }

  int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}'.trim()) ?? 0;
  String _s(dynamic v) {
    final text = '${v ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  String _parentName(Map<String, dynamic> item) {
    final full = _s(item['full_name'] ?? item['name']);
    if (full.isNotEmpty) return full;
    final first = _s(item['first_name']);
    final last = _s(item['last_name']);
    final value = '$last $first'.trim();
    return value.isEmpty ? 'Родитель' : value;
  }

  String _playerName(Map<String, dynamic> p) {
    final full = _s(p['full_name'] ?? p['fullName'] ?? p['name']);
    if (full.isNotEmpty) return full;
    final first = _s(p['first_name']);
    final last = _s(p['last_name']);
    final value = '$last $first'.trim();
    return value.isEmpty ? 'Игрок' : value;
  }

  String _photo(Map<String, dynamic> item) {
    var raw = _s(item['photo'] ?? item['photo_url'] ?? item['avatar'] ?? item['avatar_url']);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/$raw';
  }

  dynamic _decode(String body) {
    try {
      final brace = body.indexOf('{');
      final bracket = body.indexOf('[');
      final start = brace >= 0 && (bracket < 0 || brace < bracket) ? brace : bracket;
      return jsonDecode(start >= 0 ? body.substring(start) : body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 18));
    final decoded = _decode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'success': false, 'message': 'Некорректный ответ сервера'};
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _load() async {
    final teamId = widget.selectedTeamId ?? 0;
    if (teamId <= 0) {
      if (mounted) {
        setState(() {
          _loading = false;
          _parents = [];
          _invites = [];
          _error = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _post(_listUrl, {
        'club_id': widget.clubId,
        'team_id': teamId,
      });
      if (data['success'] != true) {
        throw Exception(_s(data['message'] ?? data['error']).isEmpty ? 'Не удалось загрузить родителей' : _s(data['message'] ?? data['error']));
      }
      final parents = _list(data['parents']);
      final invites = _list(data['invites']);
      if (!mounted) return;
      setState(() {
        _parents = parents;
        _invites = invites;
        _loading = false;
        if (_selectedKey.isEmpty) {
          if (parents.isNotEmpty) {
            _selectedKey = 'parent:${_i(parents.first['parent_user_id'] ?? parents.first['id'])}';
          } else if (invites.isNotEmpty) {
            _selectedKey = 'invite:${_i(invites.first['id'])}';
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _visibleRows {
    final q = _searchC.text.trim().toLowerCase();
    final out = <Map<String, dynamic>>[];

    if (_filter != _ParentFilter.pending) {
      for (final parent in _parents) {
        final children = _list(parent['children']);
        final haystack = [
          _parentName(parent),
          _s(parent['email']),
          _s(parent['phone']),
          ...children.map(_playerName),
        ].join(' ').toLowerCase();
        if (q.isEmpty || haystack.contains(q)) {
          out.add({...parent, '_row_type': 'parent'});
        }
      }
    }

    if (_filter != _ParentFilter.linked) {
      for (final invite in _invites) {
        final haystack = [
          _s(invite['code_hint']),
          _s(invite['player_name']),
          _s(invite['player_first_name']),
          _s(invite['player_last_name']),
        ].join(' ').toLowerCase();
        if (q.isEmpty || haystack.contains(q)) {
          out.add({...invite, '_row_type': 'invite'});
        }
      }
    }

    return out;
  }

  Map<String, dynamic>? get _selectedRow {
    for (final parent in _parents) {
      final key = 'parent:${_i(parent['parent_user_id'] ?? parent['id'])}';
      if (key == _selectedKey) return {...parent, '_row_type': 'parent'};
    }
    for (final invite in _invites) {
      final key = 'invite:${_i(invite['id'])}';
      if (key == _selectedKey) return {...invite, '_row_type': 'invite'};
    }
    return null;
  }

  Future<void> _issueKey() async {
    final teamId = widget.selectedTeamId ?? 0;
    if (teamId <= 0) {
      Get.snackbar('Родители', 'Сначала выберите команду');
      return;
    }
    if (widget.players.isEmpty) {
      Get.snackbar('Родители', 'В выбранной команде пока нет игроков');
      return;
    }

    setState(() {
      _issueMode = true;
      if (_issuePlayerId <= 0 ||
          !widget.players.any(
            (p) => _i(p['player_id'] ?? p['id']) == _issuePlayerId,
          )) {
        _issuePlayerId =
            _i(widget.players.first['player_id'] ?? widget.players.first['id']);
      }
    });
  }

  Future<void> _revokeAccess(Map<String, dynamic> parent, Map<String, dynamic> child) async {
    final ok = await _confirm(
      title: 'Отозвать доступ?',
      text: '${_parentName(parent)} больше не сможет видеть данные игрока ${_playerName(child)}.',
      confirm: 'Отозвать',
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final data = await _post(_revokeAccessUrl, {
        'team_id': widget.selectedTeamId,
        'parent_user_id': _i(parent['parent_user_id'] ?? parent['id']),
        'player_id': _i(child['player_id'] ?? child['id']),
        'requested_by': widget.currentUserId,
      });
      if (data['success'] != true) throw Exception(_s(data['message'] ?? data['error']));
      _selectedKey = '';
      await _load();
    } catch (e) {
      Get.snackbar('Родители', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revokeInvite(Map<String, dynamic> invite) async {
    final ok = await _confirm(
      title: 'Отменить ключ?',
      text: 'Ключ для ${_s(invite['player_name']).isEmpty ? 'игрока' : _s(invite['player_name'])} перестанет работать.',
      confirm: 'Отменить ключ',
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final data = await _post(_revokeInviteUrl, {
        'invite_id': _i(invite['id']),
        'requested_by': widget.currentUserId,
      });
      if (data['success'] != true) throw Exception(_s(data['message'] ?? data['error']));
      _selectedKey = '';
      await _load();
    } catch (e) {
      Get.snackbar('Родители', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirm({required String title, required String text, required String confirm}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: _ParentsText.title(18)),
        content: Text(text, style: _ParentsText.muted(12.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Назад')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(confirm, style: const TextStyle(color: _ParentsColors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamId = widget.selectedTeamId ?? 0;
    if (teamId <= 0) {
      return const _ParentsEmpty(
        icon: Icons.groups_2_outlined,
        title: 'Выберите команду',
        text: 'Родители и ключи доступа привязаны к конкретной команде и игрокам.',
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator(color: _ParentsColors.green));
    if (_error != null) {
      return _ParentsError(text: _error!, onRetry: _load);
    }

    final rows = _visibleRows;
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        final compact = constraints.maxWidth < 1040;
        final listWidth = math.min(compact ? 430.0 : 480.0, constraints.maxWidth * .45);
        final list = _buildList(rows, mobile);

        if (mobile) {
          return Container(
            color: _ParentsColors.workspace,
            padding: const EdgeInsets.all(6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: Colors.white,
                child: _issueMode ? _buildIssueWorkspace() : list,
              ),
            ),
          );
        }

        return Container(
          color: _ParentsColors.workspace,
          padding: EdgeInsets.all(compact ? 8 : 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 18 : 20),
            child: Container(
              color: Colors.white,
              child: Row(children: [
                SizedBox(width: listWidth, child: list),
                Container(width: 1, color: _ParentsColors.line),
                Expanded(
                  child: _issueMode
                      ? _buildIssueWorkspace()
                      : _ParentDetail(
                          row: _selectedRow,
                          onOpenPlayer: widget.onOpenPlayer,
                          onRevokeAccess: _revokeAccess,
                          onRevokeInvite: _revokeInvite,
                        ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIssueWorkspace() {
    Map<String, dynamic>? selected;
    for (final player in widget.players) {
      if (_i(player['player_id'] ?? player['id']) == _issuePlayerId) {
        selected = Map<String, dynamic>.from(player);
        break;
      }
    }

    if (selected == null && widget.players.isNotEmpty) {
      selected = Map<String, dynamic>.from(widget.players.first);
      _issuePlayerId = _i(selected['player_id'] ?? selected['id']);
    }

    if (selected == null) {
      return const _ParentsEmpty(
        icon: Icons.person_search_rounded,
        title: 'Нет игроков',
        text: 'Сначала добавьте игрока в выбранную команду.',
      );
    }

    return Column(
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _ParentsColors.line, width: .6),
            ),
          ),
          child: Row(
            children: [
              const _SquareIcon(
                icon: Icons.key_rounded,
                color: _ParentsColors.green,
                size: 34,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Доступ родителя', style: _ParentsText.title(13)),
                    const SizedBox(height: 2),
                    Text('Выберите игрока', style: _ParentsText.muted(10)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: () => setState(() => _issueMode = false),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: _ParentsColors.text,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            itemCount: widget.players.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, index) {
              final player = widget.players[index];
              final id = _i(player['player_id'] ?? player['id']);
              final active = id == _issuePlayerId;
              return InkWell(
                onTap: () => setState(() => _issuePlayerId = id),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 154,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? _ParentsColors.greenSoft2
                        : _ParentsColors.soft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active
                          ? _ParentsColors.greenBorder
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      _Avatar(
                        photo: _photo(player),
                        name: _playerName(player),
                        size: 36,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _playerName(player),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _ParentsText.value(10.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(height: 1, color: _ParentsColors.line),
        Expanded(
          child: CmrPlayerParentAccessPanel(
            key: ValueKey('parent-issue-$_issuePlayerId'),
            player: selected,
            clubId: widget.clubId,
            teamId: widget.selectedTeamId ?? 0,
            currentUserId: widget.currentUserId,
            onChanged: _load,
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Map<String, dynamic>> rows, bool mobile) {
    final max = widget.maxParents;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _ParentsColors.line, width: .6))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Родители', style: _ParentsText.title(mobile ? 15.5 : 16.5)),
              const SizedBox(height: 3),
              Text(
                max == null ? '${widget.selectedTeamName} · ${_parents.length} подключено' : '${widget.selectedTeamName} · ${_parents.length}/$max',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ParentsText.muted(11),
              ),
            ])),
            if (!mobile)
              _IconButton(icon: Icons.refresh_rounded, tooltip: 'Обновить', onTap: _saving ? null : _load),
            const SizedBox(width: 6),
            _IconButton(icon: Icons.key_rounded, tooltip: 'Выдать ключ родителю', emphasized: true, onTap: _saving ? null : _issueKey),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(color: _ParentsColors.soft, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.search_rounded, size: 16, color: _ParentsColors.muted),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _searchC,
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Родитель, email или игрок', isDense: true),
                style: _ParentsText.value(12.5),
              )),
              if (_searchC.text.trim().isNotEmpty)
                InkWell(onTap: _searchC.clear, child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 17))),
            ]),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            children: [
              _FilterPill(label: 'Все', active: _filter == _ParentFilter.all, onTap: () => setState(() => _filter = _ParentFilter.all)),
              const SizedBox(width: 6),
              _FilterPill(label: 'Подключены', active: _filter == _ParentFilter.linked, onTap: () => setState(() => _filter = _ParentFilter.linked)),
              const SizedBox(width: 6),
              _FilterPill(label: 'Ожидают ключ', active: _filter == _ParentFilter.pending, onTap: () => setState(() => _filter = _ParentFilter.pending)),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? _ParentsEmpty(
                  icon: Icons.family_restroom_rounded,
                  title: 'Пока никого нет',
                  text: _filter == _ParentFilter.pending ? 'Нет активных ключей приглашения.' : 'Выдайте ключ родителю для конкретного игрока.',
                  action: _filter == _ParentFilter.pending ? null : _issueKey,
                )
              : RefreshIndicator(
                  color: _ParentsColors.green,
                  onRefresh: _load,
                  child: ListView.builder(
                    controller: _scrollC,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(bottom: mobile ? 132 : 16),
                    itemCount: rows.length,
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final isInvite = _s(row['_row_type']) == 'invite';
                      final key = isInvite ? 'invite:${_i(row['id'])}' : 'parent:${_i(row['parent_user_id'] ?? row['id'])}';
                      return _ParentRow(
                        row: row,
                        active: key == _selectedKey,
                        mobile: mobile,
                        onTap: () {
                          setState(() {
                            _selectedKey = key;
                            _issueMode = false;
                          });
                          if (mobile) _openMobileDetail(row);
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _openMobileDetail(Map<String, dynamic> row) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .88,
        minChildSize: .5,
        maxChildSize: .96,
        expand: false,
        builder: (_, controller) => _ParentSheet(
          child: _ParentDetail(
            row: row,
            scrollController: controller,
            onOpenPlayer: widget.onOpenPlayer,
            onRevokeAccess: _revokeAccess,
            onRevokeInvite: _revokeInvite,
          ),
        ),
      ),
    );
  }
}

class _ParentDetail extends StatelessWidget {
  final Map<String, dynamic>? row;
  final ScrollController? scrollController;
  final ValueChanged<Map<String, dynamic>>? onOpenPlayer;
  final Future<void> Function(Map<String, dynamic> parent, Map<String, dynamic> child) onRevokeAccess;
  final Future<void> Function(Map<String, dynamic> invite) onRevokeInvite;

  const _ParentDetail({
    required this.row,
    this.scrollController,
    required this.onOpenPlayer,
    required this.onRevokeAccess,
    required this.onRevokeInvite,
  });

  String _s(dynamic v) => '${v ?? ''}'.trim();
  int _i(dynamic v) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? 0;
  List<Map<String, dynamic>> _list(dynamic raw) => raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  String _parentName(Map<String, dynamic> item) {
    final full = _s(item['full_name'] ?? item['name']);
    if (full.isNotEmpty) return full;
    return '${_s(item['last_name'])} ${_s(item['first_name'])}'.trim();
  }
  String _playerName(Map<String, dynamic> item) {
    final full = _s(item['full_name'] ?? item['player_name'] ?? item['name']);
    if (full.isNotEmpty) return full;
    return '${_s(item['last_name'] ?? item['player_last_name'])} ${_s(item['first_name'] ?? item['player_first_name'])}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final item = row;
    if (item == null) {
      return const _ParentsEmpty(icon: Icons.family_restroom_rounded, title: 'Выберите родителя', text: 'Справа появятся связанные дети, права и управление доступом.');
    }
    final invite = _s(item['_row_type']) == 'invite';
    if (invite) return _inviteDetail(item);
    return _linkedDetail(item);
  }

  Widget _linkedDetail(Map<String, dynamic> parent) {
    final children = _list(parent['children']);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const _SquareIcon(icon: Icons.family_restroom_rounded, color: _ParentsColors.green),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_parentName(parent).isEmpty ? 'Родитель' : _parentName(parent), style: _ParentsText.title(21)),
            const SizedBox(height: 4),
            Text(_s(parent['email']).isEmpty ? 'Аккаунт подключён' : _s(parent['email']), style: _ParentsText.muted(11.5)),
          ])),
        ]),
        const SizedBox(height: 18),
        _InfoBanner(
          icon: Icons.verified_user_outlined,
          title: 'Доступ подтверждён',
          text: 'Этот аккаунт связан только с перечисленными ниже игроками. Доступ к другому игроку требует отдельного ключа.',
        ),
        const SizedBox(height: 18),
        Text('Дети', style: _ParentsText.section()),
        const SizedBox(height: 8),
        if (children.isEmpty)
          const _ParentsEmpty(icon: Icons.person_off_outlined, title: 'Нет активных связей', text: 'Все доступы этого родителя были отозваны.')
        else
          ...children.map((child) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _ParentsColors.soft, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_playerName(child), style: _ParentsText.value(13.3)),
                      const SizedBox(height: 3),
                      Text(_s(child['team_name']), style: _ParentsText.muted(10.5)),
                    ])),
                    if (onOpenPlayer != null)
                      IconButton(
                        tooltip: 'Открыть игрока',
                        onPressed: () => onOpenPlayer!(Map<String, dynamic>.from(child)),
                        icon: const Icon(Icons.open_in_new_rounded, color: _ParentsColors.green, size: 19),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: const [
                    _AccessChip('Дневник'),
                    _AccessChip('Посещаемость'),
                    _AccessChip('Тестирование'),
                    _AccessChip('Матчи'),
                    _AccessChip('Чат с тренером'),
                  ]),
                  const SizedBox(height: 9),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => onRevokeAccess(parent, child),
                      icon: const Icon(Icons.link_off_rounded, size: 16, color: _ParentsColors.red),
                      label: const Text('Отозвать доступ', style: TextStyle(color: _ParentsColors.red, fontSize: 11.2)),
                    ),
                  ),
                ]),
              )),
      ],
    );
  }

  Widget _inviteDetail(Map<String, dynamic> invite) {
    final hint = _s(invite['code_hint']);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const _SquareIcon(icon: Icons.key_rounded, color: _ParentsColors.amber),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ожидает родителя', style: _ParentsText.title(20)),
            const SizedBox(height: 4),
            Text(_playerName(invite).isEmpty ? 'Игрок' : _playerName(invite), style: _ParentsText.muted(11.5)),
          ])),
        ]),
        const SizedBox(height: 18),
        _InfoBanner(
          icon: Icons.lock_clock_outlined,
          title: hint.isEmpty ? 'Активный одноразовый ключ' : 'Ключ $hint••••',
          text: 'Полный ключ показывается только в момент создания. После активации родитель появится в списке подключённых.',
          amber: true,
        ),
        const SizedBox(height: 12),
        if (_s(invite['expires_at']).isNotEmpty)
          _DetailRow(label: 'Действует до', value: _s(invite['expires_at'])),
        _DetailRow(label: 'Игрок', value: _playerName(invite).isEmpty ? '—' : _playerName(invite)),
        _DetailRow(label: 'Статус', value: 'Не активирован'),
        const SizedBox(height: 18),
        _SoftButton(
          title: 'Отменить ключ',
          icon: Icons.block_rounded,
          danger: true,
          onTap: () => onRevokeInvite(invite),
        ),
      ],
    );
  }
}

class _ParentRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool active;
  final bool mobile;
  final VoidCallback onTap;
  const _ParentRow({required this.row, required this.active, required this.mobile, required this.onTap});

  String _s(dynamic v) => '${v ?? ''}'.trim();
  List<Map<String, dynamic>> _list(dynamic raw) => raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  String _parentName() {
    final full = _s(row['full_name'] ?? row['name']);
    if (full.isNotEmpty) return full;
    final value = '${_s(row['last_name'])} ${_s(row['first_name'])}'.trim();
    return value.isEmpty ? 'Родитель' : value;
  }

  @override
  Widget build(BuildContext context) {
    final invite = _s(row['_row_type']) == 'invite';
    final children = _list(row['children']);
    final title = invite ? (_s(row['player_name']).isEmpty ? 'Ключ родителя' : _s(row['player_name'])) : _parentName();
    final subtitle = invite
        ? 'Ожидает активации · ${_s(row['code_hint']).isEmpty ? 'одноразовый ключ' : '${_s(row['code_hint'])}••••'}'
        : '${_s(row['email']).isEmpty ? 'Родитель' : _s(row['email'])}${children.isEmpty ? '' : ' · ${children.length} ${children.length == 1 ? 'ребёнок' : 'детей'}'}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: BoxConstraints(minHeight: mobile ? 76 : 72),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: active ? _ParentsColors.greenSoft2 : Colors.white,
            border: const Border(bottom: BorderSide(color: _ParentsColors.line, width: .65)),
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 3,
              height: 46,
              decoration: BoxDecoration(color: active ? _ParentsColors.green : Colors.transparent, borderRadius: BorderRadius.circular(99)),
            ),
            const SizedBox(width: 9),
            _SquareIcon(icon: invite ? Icons.key_rounded : Icons.family_restroom_rounded, color: invite ? _ParentsColors.amber : _ParentsColors.green, size: 46),
            const SizedBox(width: 11),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ParentsText.value(13.5)),
              const SizedBox(height: 5),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ParentsText.muted(10.6)),
            ])),
            const Icon(Icons.chevron_right_rounded, size: 18, color: _ParentsColors.muted),
          ]),
        ),
      ),
    );
  }
}

class _ParentsColors {
  static const workspace = Color(0xFFF6F7F6);
  static const soft = Color(0xFFFAFBFA);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenSoft2 = Color(0xFFF8FEFA);
  static const greenBorder = Color(0xFFD7F0E2);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF667085);
  static const line = Color(0xFFE9ECEA);
  static const red = Color(0xFFD92D20);
  static const amber = Color(0xFFF59E0B);
}

class _ParentsText {
  static TextStyle title(double size) => AppTypography.custom(size: size, weight: FontWeight.w600, color: _ParentsColors.text, height: 1.18);
  static TextStyle value(double size) => AppTypography.custom(size: size, weight: FontWeight.w600, color: _ParentsColors.text, height: 1.18);
  static TextStyle muted(double size) => AppTypography.custom(size: size, weight: FontWeight.w400, color: _ParentsColors.muted, height: 1.32);
  static TextStyle section() => AppTypography.custom(size: 12.2, weight: FontWeight.w600, color: _ParentsColors.text, height: 1.2);
}

class _Avatar extends StatelessWidget {
  final String photo;
  final String name;
  final double size;
  const _Avatar({required this.photo, required this.name, required this.size});
  @override
  Widget build(BuildContext context) {
    final parts = name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final initials = parts.isEmpty ? 'И' : parts.take(2).map((e) => e.substring(0, 1).toUpperCase()).join();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: _ParentsColors.soft,
        child: photo.isEmpty
            ? Center(child: Text(initials, style: _ParentsText.title(size * .3)))
            : Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(initials, style: _ParentsText.title(size * .3)))),
      ),
    );
  }
}

class _SquareIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _SquareIcon({required this.icon, required this.color, this.size = 50});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: size * .42, color: color),
      );
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active ? _ParentsColors.greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? _ParentsColors.greenBorder : Colors.transparent),
          ),
          child: Text(label, style: _ParentsText.muted(11).copyWith(color: active ? _ParentsColors.greenDark : _ParentsColors.muted, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ),
      );
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool emphasized;
  const _IconButton({required this.icon, required this.tooltip, required this.onTap, this.emphasized = false});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: emphasized ? _ParentsColors.greenSoft : _ParentsColors.soft,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Opacity(
              opacity: onTap == null ? .45 : 1,
              child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 16, color: emphasized ? _ParentsColors.green : _ParentsColors.text)),
            ),
          ),
        ),
      );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool amber;
  const _InfoBanner({required this.icon, required this.title, required this.text, this.amber = false});
  @override
  Widget build(BuildContext context) {
    final color = amber ? _ParentsColors.amber : _ParentsColors.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(.07), borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _ParentsText.value(12.2)),
          const SizedBox(height: 4),
          Text(text, style: _ParentsText.muted(10.8)),
        ])),
      ]),
    );
  }
}

class _AccessChip extends StatelessWidget {
  final String text;
  const _AccessChip(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: _ParentsColors.greenSoft, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: _ParentsText.muted(9.8).copyWith(color: _ParentsColors.greenDark, fontWeight: FontWeight.w600)),
      );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(width: 110, child: Text(label, style: _ParentsText.muted(10.5))),
          const SizedBox(width: 10),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: _ParentsText.value(11.5))),
        ]),
      );
}

class _SoftButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  const _SoftButton({required this.title, required this.icon, required this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) => Material(
        color: danger ? const Color(0xFFFFF1F1) : _ParentsColors.soft,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: danger ? _ParentsColors.red : _ParentsColors.text),
              const SizedBox(width: 7),
              Text(title, style: _ParentsText.value(11.5).copyWith(color: danger ? _ParentsColors.red : _ParentsColors.text)),
            ]),
          ),
        ),
      );
}

class _GreenButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  const _GreenButton({required this.title, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: _ParentsColors.green,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 7),
              Text(title, style: _ParentsText.value(11.5).copyWith(color: Colors.white)),
            ]),
          ),
        ),
      );
}

class _ParentSheet extends StatelessWidget {
  final Widget child;
  const _ParentSheet({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: child,
      );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) => Center(child: Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: _ParentsColors.line, borderRadius: BorderRadius.circular(99))));
}

class _ParentsEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? action;
  const _ParentsEmpty({required this.icon, required this.title, required this.text, this.action});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _SquareIcon(icon: icon, color: _ParentsColors.green, size: 58),
            const SizedBox(height: 13),
            Text(title, textAlign: TextAlign.center, style: _ParentsText.title(17)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: _ParentsText.muted(11.5)),
            if (action != null) ...[
              const SizedBox(height: 14),
              SizedBox(width: 210, child: _GreenButton(title: 'Выдать ключ', icon: Icons.key_rounded, onTap: action)),
            ],
          ]),
        ),
      );
}

class _ParentsError extends StatelessWidget {
  final String text;
  final Future<void> Function() onRetry;
  const _ParentsError({required this.text, required this.onRetry});
  @override
  Widget build(BuildContext context) => _ParentsEmpty(icon: Icons.error_outline_rounded, title: 'Не удалось загрузить', text: text, action: () => onRetry());
}
