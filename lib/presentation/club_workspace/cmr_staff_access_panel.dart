import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sportoteka/core/staff_access/staff_access_service.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class CmrStaffAccessPanel extends StatefulWidget {
  final int clubId;
  final int staffUserId;
  final List<Map<String, dynamic>> allTeams;
  final Future<void> Function()? onChanged;

  const CmrStaffAccessPanel({
    super.key,
    required this.clubId,
    required this.staffUserId,
    required this.allTeams,
    this.onChanged,
  });

  @override
  State<CmrStaffAccessPanel> createState() => _CmrStaffAccessPanelState();
}

class _CmrStaffAccessPanelState extends State<CmrStaffAccessPanel> {
  static const Color _green = Color(0xFF00A750);
  static const Color _greenDark = Color(0xFF067A46);
  static const Color _greenSoft = Color(0xFFF3FAF6);
  static const Color _greenBorder = Color(0xFFD7F0E2);
  static const Color _text = Color(0xFF0B0F14);
  static const Color _muted = Color(0xFF5F6670);
  static const Color _subtle = Color(0xFF8A9099);
  static const Color _line = Color(0xFFE9ECEA);
  static const Color _soft = Color(0xFFF7F8F7);
  static const Color _red = Color(0xFFD92D20);
  static const Color _redSoft = Color(0xFFFFF1F1);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _amberSoft = Color(0xFFFFF7E8);

  static const Map<String, String> _roles = <String, String>{
    'main': 'Главный тренер',
    'extra': 'Тренер',
    'assistant': 'Ассистент',
    'doctor': 'Медик',
    'press_assistant': 'Пресс-служба',
    'manager': 'Администратор',
  };

  bool _loading = true;
  bool _saving = false;
  bool _expanded = false;
  bool _editingScope = false;
  bool _confirmReissue = false;
  bool _confirmRevoke = false;

  String? _error;
  Map<String, dynamic>? _access;
  int _actorUserId = 0;

  String _draftRole = 'extra';
  final Set<int> _draftTeamIds = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CmrStaffAccessPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clubId != widget.clubId ||
        oldWidget.staffUserId != widget.staffUserId) {
      _expanded = false;
      _editingScope = false;
      _confirmReissue = false;
      _confirmRevoke = false;
      _load();
    }
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  int _teamId(Map<String, dynamic> team) =>
      _int(team['id'] ?? team['team_id'] ?? team['teamId']);

  String _teamName(Map<String, dynamic> team) {
    final value =
        '${team['name'] ?? team['team_name'] ?? team['teamName'] ?? ''}'.trim();
    return value.isEmpty ? 'Команда #${_teamId(team)}' : value;
  }

  List<Map<String, dynamic>> get _accessTeams {
    final raw = _access?['teams'];
    if (raw is! List) return <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String get _status {
    return '${_access?['status'] ?? ''}'.trim().toLowerCase();
  }

  String get _statusLabel {
    return switch (_status) {
      'pending' => 'Ожидает ключ',
      'active' => 'Активен',
      'revoked' => 'Отозван',
      _ => 'Ключ не выпущен',
    };
  }

  Color get _statusColor {
    return switch (_status) {
      'pending' => _amber,
      'active' => _green,
      'revoked' => _red,
      _ => _subtle,
    };
  }

  Color get _statusSoft {
    return switch (_status) {
      'pending' => _amberSoft,
      'active' => _greenSoft,
      'revoked' => _redSoft,
      _ => _soft,
    };
  }

  String get _roleCode => '${_access?['role_code'] ?? 'extra'}'.trim();

  String get _roleTitle {
    final fromServer = '${_access?['role_title'] ?? ''}'.trim();
    if (fromServer.isNotEmpty) return fromServer;
    return _roles[_roleCode] ?? 'Сотрудник';
  }

  Future<void> _load() async {
    if (!mounted || widget.staffUserId <= 0 || widget.clubId <= 0) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    _actorUserId = await PrefUtils.getUserId() ?? 0;

    if (_actorUserId <= 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не найден аккаунт владельца клуба.';
      });
      return;
    }

    final result = await StaffAccessService.loadManagedStatus(
      clubId: widget.clubId,
      staffUserId: widget.staffUserId,
      actorUserId: _actorUserId,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;

      if (result['success'] == true) {
        _access = result['access'] is Map
            ? Map<String, dynamic>.from(result['access'] as Map)
            : null;
        _syncDraft();
      } else {
        _error =
            '${result['message'] ?? 'Не удалось загрузить рабочий доступ.'}';
      }
    });
  }

  void _syncDraft() {
    _draftRole = _roleCode;
    _draftTeamIds.clear();

    for (final team in _accessTeams) {
      final id = _int(team['team_id'] ?? team['id']);
      if (id > 0) _draftTeamIds.add(id);
    }
  }

  Future<void> _manage(String action) async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await StaffAccessService.manage(
      action: action,
      clubId: widget.clubId,
      staffUserId: widget.staffUserId,
      actorUserId: _actorUserId,
      profile: _roleCode,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _saving = false;
        _error = '${result['message'] ?? 'Операция не выполнена.'}';
      });
      return;
    }

    setState(() {
      _saving = false;
      _confirmReissue = false;
      _confirmRevoke = false;
      if (result['access'] is Map) {
        _access = Map<String, dynamic>.from(result['access'] as Map);
      }
    });

    await _load();
    await widget.onChanged?.call();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${result['message'] ?? 'Готово'}'),
      ),
    );
  }

  Future<void> _saveScope() async {
    if (_saving || _access == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final response = await StaffAccessService.updateScope(
      clubId: widget.clubId,
      staffUserId: widget.staffUserId,
      actorUserId: _actorUserId,
      profile: _draftRole,
      teamIds: _draftTeamIds.toList(),
    );

    if (!mounted) return;

    if (response['success'] != true) {
      setState(() {
        _saving = false;
        _error =
            '${response['message'] ?? 'Не удалось сохранить рабочий профиль.'}';
      });
      return;
    }

    setState(() {
      _saving = false;
      _editingScope = false;
    });

    await _load();
    await widget.onChanged?.call();
  }

  Widget _statusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _statusSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _statusLabel,
            style: TextStyle(
              color: _statusColor,
              fontSize: 10.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _text,
            fontSize: 12.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: _muted,
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: _subtle),
          const SizedBox(width: 9),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: _subtle,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _text,
                fontSize: 11.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _teamPills(List<Map<String, dynamic>> teams) {
    if (teams.isEmpty) {
      return const Text(
        'Команды пока не назначены',
        style: TextStyle(
          color: _muted,
          fontSize: 10.8,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final team in teams)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${team['team_name'] ?? team['name'] ?? 'Команда'}',
              style: const TextStyle(
                color: _text,
                fontSize: 10.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _inlineScopeEditor() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            'Редактирование рабочего профиля',
            subtitle:
                'Роль и команды изменяются прямо здесь, без отдельного окна.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _draftRole,
            decoration: InputDecoration(
              labelText: 'Роль сотрудника',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            items: _roles.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _draftRole = value);
                    }
                  },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Команды',
                  style: TextStyle(
                    color: _text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _saving || widget.allTeams.isEmpty
                    ? null
                    : () {
                        final ids = widget.allTeams
                            .map(_teamId)
                            .where((id) => id > 0)
                            .toSet();

                        setState(() {
                          if (_draftTeamIds.length == ids.length) {
                            _draftTeamIds.clear();
                          } else {
                            _draftTeamIds
                              ..clear()
                              ..addAll(ids);
                          }
                        });
                      },
                child: const Text('Все команды'),
              ),
            ],
          ),
          if (widget.allTeams.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'У клуба пока нет команд.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10.8,
                ),
              ),
            )
          else
            for (final team in widget.allTeams)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                activeColor: _green,
                value: _draftTeamIds.contains(_teamId(team)),
                title: Text(
                  _teamName(team),
                  style: const TextStyle(
                    color: _text,
                    fontSize: 10.9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onChanged: _saving
                    ? null
                    : (checked) {
                        final id = _teamId(team);
                        if (id <= 0) return;

                        setState(() {
                          if (checked == true) {
                            _draftTeamIds.add(id);
                          } else {
                            _draftTeamIds.remove(id);
                          }
                        });
                      },
              ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          _editingScope = false;
                          _syncDraft();
                        });
                      },
                child: const Text('Отмена'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _saveScope,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Сохранить профиль'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _plainActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? _red : _text;
    final iconColor = danger ? _red : _greenDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .45 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Icon(
                    icon,
                    size: 17,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 9.9,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: danger ? _red : _subtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dangerConfirmation({
    required String text,
    required String actionTitle,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _redSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: _text,
              fontSize: 10.8,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : onCancel,
                child: const Text('Отмена'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _saving ? null : onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: Text(actionTitle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _green,
            ),
          ),
        ),
      );
    }

    final access = _access;
    final key = '${access?['staff_key'] ?? ''}'.trim();
    final teams = _accessTeams;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        const Divider(height: 1, color: _line),
        const SizedBox(height: 13),

        // Вместо большого цветного баннера — одна строка рабочего профиля.
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.work_outline_rounded,
                    size: 18,
                    color: _greenDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Рабочий профиль',
                        style: TextStyle(
                          color: _text,
                          fontSize: 12.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        access == null
                            ? 'Staff Key ещё не выпущен'
                            : '$_roleTitle · ${teams.isEmpty ? 'без команды' : '${teams.length} команд(ы)'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(),
                const SizedBox(width: 6),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _subtle,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        if (_expanded) ...[
          const SizedBox(height: 12),
          if (access == null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'У сотрудника ещё нет рабочего Staff Access. '
                'Выпустите ключ — после этого здесь появятся роль, команды и состояние активации.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10.8,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : () => _manage('issue'),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              icon: const Icon(Icons.key_rounded, size: 17),
              label: const Text('Выпустить Staff Key'),
            ),
          ] else ...[
            _infoRow(
              icon: Icons.badge_outlined,
              label: 'Роль',
              value: _roleTitle,
            ),
            const Divider(height: 1, color: _line),
            _infoRow(
              icon: Icons.key_rounded,
              label: 'Staff Key',
              value: key.isEmpty ? 'Ключ скрыт' : key,
              trailing: key.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Копировать Staff Key',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: key),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Staff Key скопирован'),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 17,
                        color: _greenDark,
                      ),
                    ),
            ),
            const Divider(height: 1, color: _line),
            _infoRow(
              icon: Icons.schedule_rounded,
              label: 'Выдан',
              value: '${access['issued_at'] ?? '—'}',
            ),
            const Divider(height: 1, color: _line),
            _infoRow(
              icon: Icons.event_available_rounded,
              label: 'Активирован',
              value: '${access['activated_at'] ?? '—'}',
            ),
            const Divider(height: 1, color: _line),
            _infoRow(
              icon: Icons.timelapse_rounded,
              label: 'Действует до',
              value: '${access['expires_at'] ?? '—'}',
            ),
            const SizedBox(height: 12),
            _sectionTitle(
              'Команды рабочего профиля',
              subtitle:
                  'Этот список определяет, к каким командам сотрудник получает рабочий доступ.',
            ),
            const SizedBox(height: 8),
            _teamPills(teams),
            const SizedBox(height: 12),
            if (!_editingScope) ...[
              _plainActionRow(
                icon: Icons.edit_outlined,
                title: 'Редактировать рабочий профиль',
                subtitle: 'Роль и команды сотрудника',
                onTap: _saving
                    ? null
                    : () {
                        setState(() {
                          _syncDraft();
                          _editingScope = true;
                        });
                      },
              ),
              if (_status != 'revoked') ...[
                const Divider(height: 1, color: _line),
                _plainActionRow(
                  icon: Icons.mail_outline_rounded,
                  title: 'Отправить Staff Key',
                  subtitle: 'Повторно отправить текущий ключ на почту',
                  onTap: _saving ? null : () => _manage('resend'),
                ),
              ],
            ],
            if (_editingScope) _inlineScopeEditor(),
            if (!_editingScope && !_confirmReissue && !_confirmRevoke) ...[
              const Divider(height: 1, color: _line),
              _plainActionRow(
                icon: Icons.key_rounded,
                title: 'Перевыпустить Staff Key',
                subtitle: 'Старый ключ станет недействительным',
                onTap: _saving
                    ? null
                    : () {
                        setState(() {
                          _confirmReissue = true;
                          _confirmRevoke = false;
                        });
                      },
              ),
              if (_status != 'revoked') ...[
                const Divider(height: 1, color: _line),
                _plainActionRow(
                  icon: Icons.block_rounded,
                  title: 'Отозвать доступ',
                  subtitle: 'Закрыть рабочий доступ сотруднику',
                  danger: true,
                  onTap: _saving
                      ? null
                      : () {
                          setState(() {
                            _confirmRevoke = true;
                            _confirmReissue = false;
                          });
                        },
                ),
              ],
            ],
            if (_confirmReissue)
              _dangerConfirmation(
                text: 'Старый Staff Key станет недействительным. '
                    'Если сотрудник уже активировал доступ, при следующем входе ему понадобится новый ключ.',
                actionTitle: 'Перевыпустить',
                onConfirm: () => _manage('reissue'),
                onCancel: () => setState(() => _confirmReissue = false),
              ),
            if (_confirmRevoke)
              _dangerConfirmation(
                text: 'Сотрудник потеряет рабочий доступ к этому клубу. '
                    'Его команды останутся сохранены для возможного перевыпуска.',
                actionTitle: 'Отозвать',
                onConfirm: () => _manage('revoke'),
                onCancel: () => setState(() => _confirmRevoke = false),
              ),
          ],
        ],

        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _redSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                color: _red,
                fontSize: 10.8,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
