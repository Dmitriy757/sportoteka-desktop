import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_api_service.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsStaffAccessPanel extends StatefulWidget {
  final int clubId;
  final int actorUserId;
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> athletes;

  const EsportsStaffAccessPanel({
    super.key,
    required this.clubId,
    required this.actorUserId,
    required this.clubName,
    required this.teams,
    required this.athletes,
  });

  @override
  State<EsportsStaffAccessPanel> createState() => _EsportsStaffAccessPanelState();
}

class _EsportsStaffAccessPanelState extends State<EsportsStaffAccessPanel> {
  List<Map<String, dynamic>> _staff = const [];
  bool _loading = true;
  bool _inviteMode = false;
  String? _error;
  Map<String, dynamic>? _issued;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final rows = await EsportsApiService.staffList(
      clubId: widget.clubId,
      actorUserId: widget.actorUserId,
    );
    if (!mounted) return;
    setState(() {
      _staff = rows;
      _loading = false;
    });
  }

  int _userId(Map<String, dynamic> m) => esportsInt(m['user_id'] ?? m['id']);
  String _name(Map<String, dynamic> m) {
    final full = esportsText(m['full_name'] ?? m['name']);
    if (full.isNotEmpty) return full;
    return '${esportsText(m['first_name'])} ${esportsText(m['last_name'])}'.trim();
  }

  String _role(Map<String, dynamic> m) {
    final server = esportsText(m['role_title']);
    if (server.isNotEmpty) return server;
    switch (esportsText(m['role_code'] ?? m['profile']).toLowerCase()) {
      case 'esports_head_coach': return 'Главный тренер Esports';
      case 'esports_coach': return 'Тренер Esports';
      case 'esports_analyst': return 'Аналитик';
      case 'esports_streamer': return 'Видео / стрим';
      case 'esports_manager': return 'Менеджер';
      case 'esports_admin': return 'Администратор';
      default: return 'Сотрудник Esports';
    }
  }

  Future<void> _reissue(Map<String, dynamic> staff) async {
    final result = await EsportsApiService.staffReissue(
      clubId: widget.clubId,
      actorUserId: widget.actorUserId,
      staffUserId: _userId(staff),
    );
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(esportsText(result['message']).isEmpty ? 'Не удалось перевыпустить ключ' : esportsText(result['message']))),
      );
      return;
    }
    final key = esportsText(result['staff_key']);
    setState(() => _issued = result);
    if (key.isNotEmpty) await Clipboard.setData(ClipboardData(text: key));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.isEmpty ? 'Staff Key перевыпущен' : 'Новый Staff Key скопирован')));
    await _load();
  }

  Future<void> _revoke(Map<String, dynamic> staff) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Отозвать доступ?'),
            content: Text('Staff-доступ для ${_name(staff)} будет закрыт только в Sportoteka Esports.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Отмена')),
              FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Отозвать')),
            ],
          ),
        ) ?? false;
    if (!ok) return;
    await EsportsApiService.staffRevoke(
      clubId: widget.clubId,
      actorUserId: widget.actorUserId,
      staffUserId: _userId(staff),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_inviteMode) {
      return _EsportsStaffInvitePanel(
        clubId: widget.clubId,
        actorUserId: widget.actorUserId,
        clubName: widget.clubName,
        teams: widget.teams,
        athletes: widget.athletes,
        onClose: () => setState(() => _inviteMode = false),
        onSaved: (result) async {
          setState(() {
            _inviteMode = false;
            _issued = result;
          });
          await _load();
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
      children: [
        EsportsPanelHeader(
          title: 'Staff Access · Esports',
          subtitle: 'Ключи, роли и доступ к конкретным киберкомандам и киберспортсменам',
          trailing: EsportsActionButton(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Выдать доступ',
            onTap: () => setState(() => _inviteMode = true),
          ),
        ),
        const SizedBox(height: 14),
        if (_issued != null) ...[
          _issuedCard(_issued!),
          const SizedBox(height: 12),
        ],
        if (_loading)
          const SizedBox(height: 260, child: Center(child: CircularProgressIndicator(color: EsportsColors.green)))
        else if (_staff.isEmpty)
          EsportsEmptyState(
            icon: Icons.badge_outlined,
            title: 'Staff-доступы ещё не выданы',
            text: 'Можно выдать один Staff Key сотруднику и ограничить его выбранными киберкомандами и отдельными киберспортсменами.',
            action: EsportsActionButton(icon: Icons.person_add_alt_1_rounded, label: 'Добавить сотрудника', onTap: () => setState(() => _inviteMode = true)),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: esportsCardDecoration(),
            child: Column(children: [
              for (var i = 0; i < _staff.length; i++) ...[
                _staffRow(_staff[i]),
                if (i != _staff.length - 1) const Divider(height: 20, color: EsportsColors.line),
              ],
            ]),
          ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppTypography.custom(size: 11, weight: FontWeight.w500, color: EsportsColors.red)),
        ],
      ],
    );
  }

  Widget _issuedCard(Map<String, dynamic> result) {
    final key = esportsText(result['staff_key']);
    final password = esportsText(result['temporary_password']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: EsportsColors.greenSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: EsportsColors.green.withOpacity(.18))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Доступ выпущен', style: AppTypography.action(color: EsportsColors.greenDark)),
        if (key.isNotEmpty) ...[
          const SizedBox(height: 7),
          SelectableText('Staff Key: $key', style: AppTypography.action(color: EsportsColors.text)),
        ],
        if (password.isNotEmpty) ...[
          const SizedBox(height: 4),
          SelectableText('Временный пароль: $password', style: AppTypography.captionMedium(color: EsportsColors.text)),
        ],
        const SizedBox(height: 6),
        Text('Этот ключ должен активироваться через обычный экран Staff Key. Сервер возвращает workspace_type=esports, поэтому HUB откроет именно Esports Workspace.', style: AppTypography.custom(size: 10.5, weight: FontWeight.w400, color: EsportsColors.muted, height: 1.35)),
      ]),
    );
  }

  Widget _staffRow(Map<String, dynamic> staff) {
    final teams = staff['teams'] is List ? (staff['teams'] as List).length : esportsInt(staff['teams_count']);
    final players = staff['players'] is List ? (staff['players'] as List).length : esportsInt(staff['players_count']);
    final status = esportsText(staff['status']);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 46, height: 46, decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.badge_outlined, color: EsportsColors.greenDark)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_name(staff).isEmpty ? esportsText(staff['email']) : _name(staff), style: AppTypography.action(color: EsportsColors.text)),
        const SizedBox(height: 3),
        Text('${_role(staff)} · $teams команд · $players игроков', style: AppTypography.captionMedium(color: EsportsColors.muted)),
        const SizedBox(height: 4),
        EsportsStatusPill(label: status.isEmpty ? 'pending' : status, active: status == 'active'),
      ])),
      PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'reissue') _reissue(staff);
          if (value == 'revoke') _revoke(staff);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'reissue', child: Text('Перевыпустить Staff Key')),
          PopupMenuItem(value: 'revoke', child: Text('Отозвать доступ')),
        ],
      ),
    ]);
  }
}

class _EsportsStaffInvitePanel extends StatefulWidget {
  final int clubId;
  final int actorUserId;
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> athletes;
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onSaved;

  const _EsportsStaffInvitePanel({
    required this.clubId,
    required this.actorUserId,
    required this.clubName,
    required this.teams,
    required this.athletes,
    required this.onClose,
    required this.onSaved,
  });

  @override
  State<_EsportsStaffInvitePanel> createState() => _EsportsStaffInvitePanelState();
}

class _EsportsStaffInvitePanelState extends State<_EsportsStaffInvitePanel> {
  final _email = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _password = TextEditingController();
  final Set<int> _teamIds = <int>{};
  final Set<int> _athleteIds = <int>{};
  String _role = 'esports_coach';
  bool _saving = false;
  bool _checking = false;
  bool? _exists;
  String? _error;

  static const roles = <String, String>{
    'esports_head_coach': 'Главный тренер Esports',
    'esports_coach': 'Тренер Esports',
    'esports_analyst': 'Аналитик',
    'esports_streamer': 'Видео / стрим',
    'esports_manager': 'Менеджер',
    'esports_admin': 'Администратор',
  };

  @override
  void dispose() {
    _email.dispose(); _first.dispose(); _last.dispose(); _password.dispose();
    super.dispose();
  }

  int _teamId(Map<String, dynamic> m) => esportsInt(m['id'] ?? m['team_id']);
  int _athleteId(Map<String, dynamic> m) => esportsInt(m['id'] ?? m['player_id']);

  String _generatedPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%';
    final r = math.Random.secure();
    return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _lookup() async {
    final email = _email.text.trim().toLowerCase();
    if (!email.contains('@')) {
      setState(() => _error = 'Введите корректный email.');
      return;
    }
    setState(() { _checking = true; _error = null; });
    final result = await EsportsApiService.staffLookup(clubId: widget.clubId, actorUserId: widget.actorUserId, email: email);
    if (!mounted) return;
    final exists = result['success'] == true && result['exists'] == true;
    if (exists && result['user'] is Map) {
      final user = Map<String, dynamic>.from(result['user'] as Map);
      _first.text = esportsText(user['first_name']);
      _last.text = esportsText(user['last_name']);
    } else if (!exists && _password.text.isEmpty) {
      _password.text = _generatedPassword();
    }
    setState(() { _exists = exists; _checking = false; if (result['success'] != true) _error = esportsText(result['message']); });
  }

  Future<void> _save() async {
    if (_teamIds.isEmpty) {
      setState(() => _error = 'Выберите хотя бы одну киберкоманду.');
      return;
    }
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Укажите email сотрудника.');
      return;
    }
    if (_exists != true && (_first.text.trim().isEmpty || _password.text.length < 8)) {
      setState(() => _error = 'Для нового сотрудника укажите имя и временный пароль не короче 8 символов.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final result = await EsportsApiService.staffInvite(
      clubId: widget.clubId,
      actorUserId: widget.actorUserId,
      email: _email.text.trim(),
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      password: _password.text,
      profile: _role,
      teamIds: _teamIds.toList(),
      athleteIds: _athleteIds.toList(),
    );
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() { _saving = false; _error = esportsText(result['message']).isEmpty ? 'Не удалось выдать Staff Access.' : esportsText(result['message']); });
      return;
    }
    final key = esportsText(result['staff_key']);
    if (key.isNotEmpty) await Clipboard.setData(ClipboardData(text: key));
    widget.onSaved(result);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
      children: [
        EsportsPanelHeader(title: 'Новый Staff Access', subtitle: '${widget.clubName} · Esports', trailing: IconButton(onPressed: _saving ? null : widget.onClose, icon: const Icon(Icons.close_rounded))),
        const SizedBox(height: 14),
        TextField(controller: _email, style: esportsFieldTextStyle(), decoration: esportsInputDecoration('Email сотрудника', icon: Icons.mail_outline_rounded).copyWith(suffixIcon: IconButton(onPressed: _checking ? null : _lookup, icon: _checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search_rounded)))),
        const SizedBox(height: 12),
        if (_exists != null) Text(_exists! ? 'Аккаунт найден — пароль менять не будем.' : 'Новый сотрудник — создан временный пароль.', style: AppTypography.captionMedium(color: _exists! ? EsportsColors.greenDark : EsportsColors.muted)),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: TextField(controller: _first, style: esportsFieldTextStyle(), decoration: esportsInputDecoration('Имя'))), const SizedBox(width: 10), Expanded(child: TextField(controller: _last, style: esportsFieldTextStyle(), decoration: esportsInputDecoration('Фамилия')))]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(style: esportsFieldTextStyle(), value: _role, decoration: esportsInputDecoration('Роль'), items: roles.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: esportsFieldTextStyle()))).toList(), onChanged: (v) { if (v != null) setState(() => _role = v); }),
        if (_exists != true) ...[
          const SizedBox(height: 12),
          TextField(controller: _password, style: esportsFieldTextStyle(), decoration: esportsInputDecoration('Временный пароль', icon: Icons.key_rounded)),
        ],
        const SizedBox(height: 16),
        _scopeCard('Киберкоманды', widget.teams.map((team) {
          final id = _teamId(team);
          final name = esportsText(team['name'] ?? team['team_name']);
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _teamIds.contains(id),
            title: Text(name.isEmpty ? 'Команда #$id' : name, style: AppTypography.action(color: EsportsColors.text)),
            onChanged: (v) => setState(() { if (v == true) _teamIds.add(id); else _teamIds.remove(id); }),
          );
        }).toList()),
        const SizedBox(height: 12),
        _scopeCard('Отдельные киберспортсмены (необязательно)', widget.athletes.map((a) {
          final id = _athleteId(a);
          final tag = esportsText(a['gamer_tag'] ?? a['nickname']);
          final name = '${esportsText(a['first_name'])} ${esportsText(a['last_name'])}'.trim();
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _athleteIds.contains(id),
            title: Text(tag.isEmpty ? (name.isEmpty ? 'Игрок #$id' : name) : tag, style: AppTypography.action(color: EsportsColors.text)),
            subtitle: name.isEmpty || name == tag ? null : Text(name, style: AppTypography.captionMedium(color: EsportsColors.muted)),
            onChanged: (v) => setState(() { if (v == true) _athleteIds.add(id); else _athleteIds.remove(id); }),
          );
        }).toList()),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppTypography.custom(size: 11, weight: FontWeight.w500, color: EsportsColors.red)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: EsportsActionButton(icon: Icons.close_rounded, label: 'Отмена', onTap: _saving ? null : widget.onClose, primary: false)),
          const SizedBox(width: 9),
          Expanded(flex: 2, child: EsportsActionButton(icon: Icons.vpn_key_outlined, label: _saving ? 'Выпускаем…' : 'Выдать Staff Key', onTap: _saving ? null : _save)),
        ]),
      ],
    );
  }

  Widget _scopeCard(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: esportsCardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: AppTypography.action(color: EsportsColors.text)),
          const SizedBox(height: 6),
          if (children.isEmpty) Text('Нет доступных объектов', style: AppTypography.captionMedium(color: EsportsColors.muted)) else ...children,
        ]),
      );
}
