import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sportoteka/core/staff_access/staff_access_service.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class CmrStaffAccessPanel extends StatefulWidget {
  final int clubId;
  final int staffUserId;
  final List<Map<String, dynamic>> allTeams;
  final Future<void> Function()? onChanged;
  final bool initiallyExpanded;
  final bool adminMode;

  const CmrStaffAccessPanel({
    super.key,
    required this.clubId,
    required this.staffUserId,
    required this.allTeams,
    this.onChanged,
    this.initiallyExpanded = false,
    this.adminMode = false,
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
  bool _confirmPasswordReissue = false;
  bool _confirmRevoke = false;
  bool _passwordVisible = true;
  String _temporaryPassword = '';

  String? _error;
  Map<String, dynamic>? _access;
  int _actorUserId = 0;

  String _draftRole = 'extra';
  final Set<int> _draftTeamIds = <int>{};

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _load();
  }

  @override
  void didUpdateWidget(covariant CmrStaffAccessPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clubId != widget.clubId ||
        oldWidget.staffUserId != widget.staffUserId) {
      _expanded = widget.initiallyExpanded;
      _editingScope = false;
      _confirmReissue = false;
      _confirmPasswordReissue = false;
      _confirmRevoke = false;
      _temporaryPassword = '';
      _passwordVisible = true;
      _access = null;
      _error = null;
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
    if (_error != null && _access == null) return 'Ошибка доступа';
    return switch (_status) {
      'pending' => 'Ожидает ключ',
      'active' => 'Активен',
      'revoked' => 'Отозван',
      _ => 'Ключ не выпущен',
    };
  }

  Color get _statusColor {
    if (_error != null && _access == null) return _red;
    return switch (_status) {
      'pending' => _amber,
      'active' => _green,
      'revoked' => _red,
      _ => _subtle,
    };
  }

  Color get _statusSoft {
    if (_error != null && _access == null) return _redSoft;
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
        _access = null;
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

  Future<void> _manage(
    String action, {
    String? profile,
    List<int>? teamIds,
  }) async {
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
      profile: profile ?? _roleCode,
      teamIds: teamIds,
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

  Future<void> _issueWithScope() async {
    if (_saving) return;

    final validTeamIds = _draftTeamIds.where((id) => id > 0).toList();
    if (widget.allTeams.isNotEmpty && validTeamIds.isEmpty) {
      setState(() {
        _error = 'Выберите хотя бы одну команду для рабочего доступа.';
      });
      return;
    }

    await _manage(
      'issue',
      profile: _draftRole,
      teamIds: validTeamIds,
    );
  }

  String _roleAccessHint(String role) {
    switch (role) {
      case 'press_assistant':
        return 'Пресс-служба получит доступ только к выбранным командам: новости, публикации и пресс-функции.';
      case 'doctor':
        return 'Медик будет видеть рабочие разделы только выбранных команд в пределах своей роли.';
      case 'assistant':
        return 'Ассистент получит рабочий доступ только к выбранным командам.';
      case 'main':
        return 'Главный тренер получит рабочий доступ к выбранным командам.';
      case 'manager':
        return 'Администратор получит рабочий доступ к выбранным командам. Клубные полномочия определяются отдельно.';
      default:
        return 'Тренер получит рабочий доступ только к выбранным командам.';
    }
  }

  Future<void> _reissuePassword() async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await StaffAccessService.reissuePassword(
      clubId: widget.clubId,
      staffUserId: widget.staffUserId,
      actorUserId: _actorUserId,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _saving = false;
        _error = '${result['message'] ?? 'Не удалось перевыпустить пароль.'}';
      });
      return;
    }

    final password = '${result['temporary_password'] ?? ''}'.trim();
    final mailSent = result['mail_sent'] == true;

    if (password.isEmpty) {
      setState(() {
        _saving = false;
        _confirmPasswordReissue = false;
        _error = 'Сервер перевыпустил пароль, но не вернул его для показа администратору.';
      });
      return;
    }

    setState(() {
      _saving = false;
      _confirmPasswordReissue = false;
      _temporaryPassword = password;
      _passwordVisible = true;
    });

    // ВАЖНО: здесь НЕ вызываем widget.onChanged. Родительский _load()
    // пересобирает карточку сотрудника и уничтожает локальное состояние,
    // из-за чего новый пароль исчезал раньше, чем администратор успевал его увидеть.
    await _showTemporaryPasswordDialog(
      password: password,
      mailSent: mailSent,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mailSent
              ? 'Новый пароль сохранён и отправлен сотруднику на почту.'
              : 'Новый пароль сохранён. Письмо отправить не удалось — скопируйте пароль вручную.',
        ),
      ),
    );
  }

  Future<void> _showTemporaryPasswordDialog({
    required String password,
    required bool mailSent,
  }) async {
    var visible = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.password_rounded, color: _greenDark),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Новый пароль сотрудника',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      mailSent
                          ? 'Пароль уже отправлен сотруднику на почту. Скопируйте его сейчас при необходимости.'
                          : 'Письмо отправить не удалось. Скопируйте пароль и передайте сотруднику вручную.',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _greenSoft,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: _greenBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              visible ? password : '••••••••••••••',
                              style: const TextStyle(
                                color: _text,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .6,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: visible ? 'Скрыть пароль' : 'Показать пароль',
                            onPressed: () => setDialogState(() => visible = !visible),
                            icon: Icon(
                              visible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: _greenDark,
                              size: 19,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Копировать пароль',
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: password));
                              if (!dialogContext.mounted) return;
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Новый пароль скопирован'),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: _greenDark,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'После закрытия карточки SPORTOTEKA не сможет снова показать этот пароль. В базе хранится только его защищённый хэш.',
                      style: TextStyle(
                        color: _subtle,
                        fontSize: 10.3,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: password));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text('Копировать'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Готово'),
                ),
              ],
            );
          },
        );
      },
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

  Widget _issueSetupEditor() {
    final allIds = widget.allTeams
        .map(_teamId)
        .where((id) => id > 0)
        .toSet();
    final allSelected = allIds.isNotEmpty &&
        _draftTeamIds.length == allIds.length &&
        _draftTeamIds.containsAll(allIds);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            'Настроить рабочий доступ',
            subtitle:
                'Выберите роль и команды до выпуска Staff Key. Один ключ действует на весь клуб, а этот список определяет видимые команды.',
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
          const SizedBox(height: 7),
          Text(
            _roleAccessHint(_draftRole),
            style: const TextStyle(
              color: _muted,
              fontSize: 10.1,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Видимые команды',
                  style: TextStyle(
                    color: _text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _saving || allIds.isEmpty
                    ? null
                    : () {
                        setState(() {
                          if (allSelected) {
                            _draftTeamIds.clear();
                          } else {
                            _draftTeamIds
                              ..clear()
                              ..addAll(allIds);
                          }
                        });
                      },
                icon: Icon(
                  allSelected
                      ? Icons.check_box_rounded
                      : Icons.select_all_rounded,
                  size: 16,
                ),
                label: Text(allSelected ? 'Снять все' : 'Все команды'),
              ),
            ],
          ),
          if (widget.allTeams.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'У клуба пока нет команд. Staff Key можно выпустить после создания команды.',
                style: TextStyle(color: _muted, fontSize: 10.5),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.allTeams.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: _line),
                itemBuilder: (context, index) {
                  final team = widget.allTeams[index];
                  final id = _teamId(team);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    activeColor: _green,
                    value: id > 0 && _draftTeamIds.contains(id),
                    title: Text(
                      _teamName(team),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 10.7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onChanged: _saving || id <= 0
                        ? null
                        : (checked) {
                            setState(() {
                              if (checked == true) {
                                _draftTeamIds.add(id);
                              } else {
                                _draftTeamIds.remove(id);
                              }
                            });
                          },
                  );
                },
              ),
            ),
          const SizedBox(height: 11),
          FilledButton.icon(
            onPressed: _saving ||
                    widget.allTeams.isEmpty ||
                    _draftTeamIds.isEmpty
                ? null
                : _issueWithScope,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(42),
            ),
            icon: const Icon(Icons.key_rounded, size: 17),
            label: Text(
              _saving
                  ? 'Выпуск доступа...'
                  : 'Выпустить Staff Key и отправить на почту',
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _saving
                ? null
                : () {
                    setState(() {
                      _confirmPasswordReissue = true;
                      _confirmReissue = false;
                      _confirmRevoke = false;
                    });
                  },
            icon: const Icon(Icons.password_rounded, size: 17),
            label: const Text('Сменить / перевыпустить пароль'),
            style: TextButton.styleFrom(
              foregroundColor: _greenDark,
            ),
          ),
          if (_confirmPasswordReissue)
            _dangerConfirmation(
              text: 'Будет создан новый временный пароль. Текущий пароль сразу перестанет работать. Новый пароль будет показан администратору один раз и отправлен сотруднику на email.',
              actionTitle: 'Создать новый пароль',
              onConfirm: _reissuePassword,
              onCancel: () =>
                  setState(() => _confirmPasswordReissue = false),
            ),
        ],
      ),
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
          const SizedBox(height: 7),
          Text(
            _roleAccessHint(_draftRole),
            style: const TextStyle(
              color: _muted,
              fontSize: 10.1,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Видимые команды',
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
                            ? (_error != null
                                ? 'Не удалось проверить Staff Access'
                                : 'Staff Key ещё не выпущен')
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
            if (_error == null) ...[
              if (widget.adminMode)
                _issueSetupEditor()
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Рабочий доступ ещё не выпущен. Управление Staff Key, ролями, командами и паролем доступно в клубном окне «Доступы сотрудников».',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10.8,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ] else if (!widget.adminMode) ...[
            _infoRow(
              icon: Icons.badge_outlined,
              label: 'Роль',
              value: _roleTitle,
            ),
            const SizedBox(height: 10),
            _sectionTitle(
              'Доступ к командам',
              subtitle:
                  'Для управления ключом, паролем и назначениями используйте клубное окно «Доступы сотрудников».',
            ),
            const SizedBox(height: 8),
            _teamPills(teams),
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
              icon: Icons.password_rounded,
              label: _temporaryPassword.isEmpty ? 'Пароль' : 'Новый пароль',
              value: _temporaryPassword.isEmpty
                  ? 'Текущий пароль защищён'
                  : (_passwordVisible
                      ? _temporaryPassword
                      : '••••••••••••'),
              trailing: _temporaryPassword.isEmpty
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: _passwordVisible
                              ? 'Скрыть временный пароль'
                              : 'Показать временный пароль',
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 17,
                            color: _greenDark,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Копировать временный пароль',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: _temporaryPassword),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Временный пароль скопирован'),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 17,
                            color: _greenDark,
                          ),
                        ),
                      ],
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
            if (!_editingScope &&
                !_confirmReissue &&
                !_confirmPasswordReissue &&
                !_confirmRevoke) ...[
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
                          _confirmPasswordReissue = false;
                          _confirmRevoke = false;
                        });
                      },
              ),
              const Divider(height: 1, color: _line),
              _plainActionRow(
                icon: Icons.password_rounded,
                title: 'Сменить / перевыпустить пароль',
                subtitle:
                    'Создать новый временный пароль, показать администратору и отправить сотруднику',
                onTap: _saving || _status == 'revoked'
                    ? null
                    : () {
                        setState(() {
                          _confirmPasswordReissue = true;
                          _confirmReissue = false;
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
                            _confirmPasswordReissue = false;
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
            if (_confirmPasswordReissue)
              _dangerConfirmation(
                text: 'Будет создан новый временный пароль. '
                    'Текущий пароль сотрудника сразу перестанет работать. '
                    'Новый пароль будет показан здесь один раз и отправлен на email.',
                actionTitle: 'Создать новый пароль',
                onConfirm: _reissuePassword,
                onCancel: () =>
                    setState(() => _confirmPasswordReissue = false),
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
