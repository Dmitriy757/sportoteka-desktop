import 'package:flutter/material.dart';

import 'package:sportoteka/core/staff_access/staff_access_service.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class CmrStaffInviteDialog extends StatefulWidget {
  final int clubId;
  final String clubName;
  final List<Map<String, dynamic>> teams;

  const CmrStaffInviteDialog({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teams,
  });

  @override
  State<CmrStaffInviteDialog> createState() => _CmrStaffInviteDialogState();
}

class _CmrStaffInviteDialogState extends State<CmrStaffInviteDialog> {
  static const _green = Color(0xFF00A750);
  static const _greenDark = Color(0xFF067A46);
  static const _greenSoft = Color(0xFFF3FAF6);
  static const _line = Color(0xFFE9ECEA);
  static const _text = Color(0xFF0B0F14);
  static const _muted = Color(0xFF667085);

  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _password = TextEditingController();

  String _profile = 'extra';
  final Set<int> _selectedTeamIds = <int>{};
  bool _saving = false;
  bool _lookingUp = false;
  bool? _existingUser;
  String? _error;

  static const _roles = <String, String>{
    'main': 'Главный тренер',
    'extra': 'Тренер',
    'assistant': 'Ассистент',
    'doctor': 'Медик',
    'manager': 'Администратор',
    'press_assistant': 'Пресс-служба',
  };

  @override
  void dispose() {
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _password.dispose();
    super.dispose();
  }

  int _teamId(Map<String, dynamic> team) {
    return int.tryParse(
          '${team['id'] ?? team['team_id'] ?? team['teamId'] ?? 0}',
        ) ??
        0;
  }

  String _teamName(Map<String, dynamic> team) {
    final value =
        '${team['name'] ?? team['team_name'] ?? team['teamName'] ?? ''}'.trim();
    return value.isEmpty ? 'Команда #${_teamId(team)}' : value;
  }

  Future<void> _lookup() async {
    final email = _email.text.trim();
    if (!email.contains('@') || widget.clubId <= 0) return;

    final actor = await PrefUtils.getUserId() ?? 0;
    if (actor <= 0) return;

    setState(() {
      _lookingUp = true;
      _error = null;
    });

    final result = await StaffAccessService.lookup(
      clubId: widget.clubId,
      actorUserId: actor,
      email: email,
    );

    if (!mounted) return;

    final exists = result['success'] == true &&
        result['exists'] == true &&
        result['user'] is Map;

    if (exists) {
      final user = Map<String, dynamic>.from(result['user'] as Map);
      _firstName.text = '${user['first_name'] ?? ''}'.trim();
      _lastName.text = '${user['last_name'] ?? ''}'.trim();
    }

    setState(() {
      _existingUser = exists;
      _lookingUp = false;
      if (result['success'] != true) {
        _error = '${result['message'] ?? 'Не удалось проверить email'}';
      }
    });
  }

  Future<void> _submit() async {
    if (_saving) return;

    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Введите корректный email');
      return;
    }

    if (_existingUser != true) {
      if (_firstName.text.trim().isEmpty) {
        setState(() => _error = 'Для нового сотрудника укажите имя');
        return;
      }
      if (_password.text.length < 8) {
        setState(
          () => _error =
              'Для нового сотрудника задайте пароль не короче 8 символов',
        );
        return;
      }
    }

    final actor = await PrefUtils.getUserId() ?? 0;
    if (actor <= 0) {
      setState(() => _error = 'Не найден аккаунт владельца клуба');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await StaffAccessService.invite(
      clubId: widget.clubId,
      actorUserId: actor,
      email: email,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      password: _password.text,
      profile: _profile,
      teamIds: _selectedTeamIds.toList(),
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _saving = false;
        _error = '${result['message'] ?? 'Не удалось добавить сотрудника'}';
      });
      return;
    }

    final mailSent = result['mail_sent'] == true;
    final key = '${result['staff_key'] ?? ''}';

    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mailSent
              ? 'Сотрудник добавлен. Staff Key $key отправлен на почту.'
              : 'Сотрудник добавлен. Staff Key: $key. Письмо не отправлено.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final newUser = _existingUser != true;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 680,
          maxHeight: 820,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _greenSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.badge_outlined,
                        color: _greenDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Добавить сотрудника',
                            style: TextStyle(
                              color: _text,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.clubName} · один Staff Key на клуб',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _line),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) {
                        if (_existingUser != null) {
                          setState(() => _existingUser = null);
                        }
                      },
                      onSubmitted: (_) => _lookup(),
                      decoration: InputDecoration(
                        labelText: 'Email сотрудника',
                        suffixIcon: _lookingUp
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                onPressed: _lookup,
                                icon: const Icon(Icons.search_rounded),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (_existingUser != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _existingUser!
                            ? 'Аккаунт найден. Его пароль изменён не будет.'
                            : 'Новый сотрудник — заполните имя и временный пароль.',
                        style: TextStyle(
                          color: _existingUser! ? _greenDark : _muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstName,
                            enabled: _existingUser != true,
                            decoration: InputDecoration(
                              labelText: 'Имя',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _lastName,
                            enabled: _existingUser != true,
                            decoration: InputDecoration(
                              labelText: 'Фамилия',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (newUser) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Временный пароль',
                          helperText:
                              'Только для нового аккаунта. Минимум 8 символов.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _profile,
                      decoration: InputDecoration(
                        labelText: 'Роль',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
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
                                setState(() => _profile = value);
                              }
                            },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Команды',
                      style: TextStyle(
                        color: _text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Можно выбрать несколько. Staff Key всё равно будет один.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.teams.isEmpty)
                      const Text(
                        'У клуба пока нет команд. Доступ будет создан на уровне клуба.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11.5,
                        ),
                      )
                    else
                      for (final team in widget.teams)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: _green,
                          title: Text(_teamName(team)),
                          value: _selectedTeamIds.contains(_teamId(team)),
                          onChanged: _saving
                              ? null
                              : (value) {
                                  final id = _teamId(team);
                                  if (id <= 0) return;
                                  setState(() {
                                    if (value == true) {
                                      _selectedTeamIds.add(id);
                                    } else {
                                      _selectedTeamIds.remove(id);
                                    }
                                  });
                                },
                        ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFD92D20),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: _line),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Выпустить Staff Key',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
