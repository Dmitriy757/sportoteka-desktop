import 'package:flutter/material.dart';

import 'package:sportoteka/core/staff_access/staff_access_service.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class CmrStaffAddRightPanel extends StatefulWidget {
  final int clubId;
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final VoidCallback onClose;
  final Future<void> Function()? onSaved;

  const CmrStaffAddRightPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teams,
    required this.onClose,
    this.onSaved,
  });

  @override
  State<CmrStaffAddRightPanel> createState() => _CmrStaffAddRightPanelState();
}

class _CmrStaffAddRightPanelState extends State<CmrStaffAddRightPanel> {
  static const Color _green = Color(0xFF00A750);
  static const Color _greenDark = Color(0xFF067A46);
  static const Color _greenSoft = Color(0xFFF3FAF6);
  static const Color _greenBorder = Color(0xFFD7F0E2);
  static const Color _soft = Color(0xFFF7F8F7);
  static const Color _line = Color(0xFFE9ECEA);
  static const Color _text = Color(0xFF0B0F14);
  static const Color _muted = Color(0xFF667085);
  static const Color _red = Color(0xFFD92D20);
  static const Color _amber = Color(0xFFF59E0B);

  final TextEditingController _emailC = TextEditingController();
  final TextEditingController _firstNameC = TextEditingController();
  final TextEditingController _lastNameC = TextEditingController();
  final TextEditingController _passwordC = TextEditingController();

  bool _checking = false;
  bool _saving = false;
  bool _passwordVisible = false;

  bool? _userExists;
  bool _canSetTemporaryPassword = false;
  Map<String, dynamic>? _existingUser;
  String _profile = 'extra';
  String _message = '';
  bool _messageError = false;
  String _checkedEmail = '';

  final Set<int> _selectedTeamIds = <int>{};

  static const Map<String, String> _roles = <String, String>{
    'main': 'Главный тренер',
    'extra': 'Тренер',
    'assistant': 'Ассистент',
    'doctor': 'Медик',
    'press_assistant': 'Пресс-служба',
    'manager': 'Администратор',
  };

  @override
  void initState() {
    super.initState();

    // Если открыт конкретный team workspace, всё равно не выбираем команды
    // автоматически: клуб сам явно отмечает все необходимые команды.
  }

  @override
  void dispose() {
    _emailC.dispose();
    _firstNameC.dispose();
    _lastNameC.dispose();
    _passwordC.dispose();
    super.dispose();
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

  bool _emailLooksValid(String raw) {
    final email = raw.trim();
    if (email.isEmpty) return false;

    // Клиентская проверка только формата. Существование ящика подтверждает
    // уже фактическая доставка письма.
    return RegExp(
      r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$',
    ).hasMatch(email);
  }

  void _emailChanged(String value) {
    final normalized = value.trim().toLowerCase();

    if (_checkedEmail.isNotEmpty && normalized != _checkedEmail) {
      setState(() {
        _checkedEmail = '';
        _userExists = null;
        _canSetTemporaryPassword = false;
        _existingUser = null;
        _message = '';
        _messageError = false;
        _firstNameC.clear();
        _lastNameC.clear();
        _passwordC.clear();
      });
    }
  }

  Future<void> _checkEmail() async {
    if (_checking || _saving) return;

    final email = _emailC.text.trim().toLowerCase();

    if (!_emailLooksValid(email)) {
      setState(() {
        _userExists = null;
        _canSetTemporaryPassword = false;
        _existingUser = null;
        _checkedEmail = '';
        _message = 'Укажите действительный адрес электронной почты.';
        _messageError = true;
      });
      return;
    }

    final actorUserId = await PrefUtils.getUserId() ?? 0;

    if (actorUserId <= 0) {
      if (!mounted) return;
      setState(() {
        _message = 'Не найден аккаунт владельца клуба.';
        _messageError = true;
      });
      return;
    }

    setState(() {
      _checking = true;
      _message = '';
      _messageError = false;
    });

    final result = await StaffAccessService.lookup(
      clubId: widget.clubId,
      actorUserId: actorUserId,
      email: email,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _checking = false;
        _checkedEmail = '';
        _userExists = null;
        _canSetTemporaryPassword = false;
        _existingUser = null;
        _message =
            '${result['message'] ?? 'Не удалось проверить адрес электронной почты.'}';
        _messageError = true;
      });
      return;
    }

    final exists = result['exists'] == true && result['user'] is Map;

    if (exists) {
      final user = Map<String, dynamic>.from(result['user'] as Map);

      _firstNameC.text = '${user['first_name'] ?? ''}'.trim();
      _lastNameC.text = '${user['last_name'] ?? ''}'.trim();
      _passwordC.clear();

      final canSetTemporaryPassword =
          result['can_set_temporary_password'] == true;

      setState(() {
        _checking = false;
        _checkedEmail = email;
        _userExists = true;
        _canSetTemporaryPassword = canSetTemporaryPassword;
        _existingUser = user;
        _message = canSetTemporaryPassword
            ? 'Сотрудник найден. Доступ ещё не активирован — задайте ему новый временный пароль.'
            : 'Сотрудник найден в SPORTOTEKA. Его действующий пароль изменён не будет.';
        _messageError = false;
      });
      return;
    }

    _firstNameC.clear();
    _lastNameC.clear();
    _passwordC.clear();

    setState(() {
      _checking = false;
      _checkedEmail = email;
      _userExists = false;
      _canSetTemporaryPassword = false;
      _existingUser = null;
      _message =
          'Пользователь с такой почтой не найден. Заполните данные нового сотрудника.';
      _messageError = false;
    });
  }

  Future<bool> _ensureEmailChecked() async {
    final email = _emailC.text.trim().toLowerCase();

    if (!_emailLooksValid(email)) {
      setState(() {
        _message = 'Укажите действительный адрес электронной почты.';
        _messageError = true;
      });
      return false;
    }

    if (_checkedEmail == email && _userExists != null) {
      return true;
    }

    await _checkEmail();

    return mounted && _checkedEmail == email && _userExists != null;
  }

  String _friendlyMailMessage(Map<String, dynamic> result) {
    final sent = result['mail_sent'] == true;

    if (sent) {
      if (_userExists != true || _canSetTemporaryPassword) {
        return 'Email, временный пароль и Staff Key отправлены сотруднику на почту.';
      }
      return 'Staff Key выпущен и отправлен сотруднику на почту.';
    }

    return 'Staff Key выпущен, но письмо не удалось доставить. '
        'Проверьте, правильно ли указан адрес электронной почты.';
  }

  Future<void> _submit() async {
    if (_saving) return;

    final checked = await _ensureEmailChecked();
    if (!checked || !mounted) return;

    final email = _emailC.text.trim().toLowerCase();

    if (_userExists != true) {
      if (_firstNameC.text.trim().isEmpty) {
        setState(() {
          _message = 'Укажите имя нового сотрудника.';
          _messageError = true;
        });
        return;
      }

      if (_passwordC.text.length < 8) {
        setState(() {
          _message =
              'Пароль нового сотрудника должен содержать не менее 8 символов.';
          _messageError = true;
        });
        return;
      }
    } else if (_canSetTemporaryPassword && _passwordC.text.length < 8) {
      setState(() {
        _message =
            'Задайте новый временный пароль не короче 8 символов. Он будет отправлен сотруднику вместе со Staff Key.';
        _messageError = true;
      });
      return;
    }

    final actorUserId = await PrefUtils.getUserId() ?? 0;

    if (actorUserId <= 0) {
      if (!mounted) return;
      setState(() {
        _message = 'Не найден аккаунт владельца клуба.';
        _messageError = true;
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = '';
      _messageError = false;
    });

    final result = await StaffAccessService.invite(
      clubId: widget.clubId,
      actorUserId: actorUserId,
      email: email,
      firstName: _firstNameC.text.trim(),
      lastName: _lastNameC.text.trim(),
      password: _userExists == true && !_canSetTemporaryPassword
          ? ''
          : _passwordC.text,
      profile: _profile,
      teamIds: _selectedTeamIds.toList(),
    );

    if (!mounted) return;

    if (result['success'] != true) {
      final raw = '${result['message'] ?? 'Не удалось добавить сотрудника.'}';

      final friendly = raw.toLowerCase().contains('smtp') ||
              raw.toLowerCase().contains('recipient') ||
              raw.toLowerCase().contains('mail server')
          ? 'Не удалось доставить письмо. Проверьте адрес электронной почты.'
          : raw;

      setState(() {
        _saving = false;
        _message = friendly;
        _messageError = true;
      });
      return;
    }

    final friendly = _friendlyMailMessage(result);
    final mailSent = result['mail_sent'] == true;

    setState(() {
      _saving = false;
      _message = friendly;
      _messageError = !mailSent;
    });

    await widget.onSaved?.call();

    if (!mounted) return;

    if (mailSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сотрудник добавлен. Staff Key отправлен на почту.',
          ),
        ),
      );

      widget.onClose();
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool enabled = true,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: _text,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: enabled ? _soft : const Color(0xFFF1F3F2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: _green,
            width: 1.2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
      ),
    );
  }

  Widget _existingUserCard() {
    final user = _existingUser;
    if (user == null) return const SizedBox.shrink();

    final first = '${user['first_name'] ?? ''}'.trim();
    final last = '${user['last_name'] ?? ''}'.trim();
    final fullName = '$last $first'.trim();
    final email = '${user['email'] ?? _emailC.text}'.trim();
    final role = '${user['role'] ?? ''}'.trim();
    final status = '${user['status'] ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _greenSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _greenBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: _greenDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Сотрудник SPORTOTEKA' : fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    email,
                    if (role.isNotEmpty) role,
                    if (status.isNotEmpty) status,
                  ].join(' · '),
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
          const SizedBox(width: 8),
          const Icon(
            Icons.check_circle_rounded,
            color: _green,
            size: 19,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = _userExists == true;
    final newUser = _userExists == false;
    final notChecked = _userExists == null;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 11),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _line, width: .7),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 7,
                  height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Добавить сотрудника',
                        style: TextStyle(
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.clubName,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: _saving ? null : widget.onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        controller: _emailC,
                        label: 'Email сотрудника',
                        hint: 'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                        onChanged: _emailChanged,
                        onSubmitted: (_) => _checkEmail(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _checking || _saving ? null : _checkEmail,
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                        ),
                        child: _checking
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Проверить'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (existing) _existingUserCard(),
                if (_message.isNotEmpty) ...[
                  if (existing) const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _messageError
                          ? const Color(0xFFFFF1F1)
                          : (newUser ? const Color(0xFFFFFBEB) : _greenSoft),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _messageError
                              ? Icons.error_outline_rounded
                              : (newUser
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.check_circle_outline_rounded),
                          size: 17,
                          color: _messageError
                              ? _red
                              : (newUser ? _amber : _greenDark),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _message,
                            style: TextStyle(
                              color: _messageError ? _red : _text,
                              fontSize: 10.8,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        controller: _firstNameC,
                        label: 'Имя',
                        enabled: !existing,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _field(
                        controller: _lastNameC,
                        label: 'Фамилия',
                        enabled: !existing,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _field(
                  controller: _passwordC,
                  label: existing && !_canSetTemporaryPassword
                      ? 'Пароль существующего аккаунта не меняется'
                      : 'Временный пароль',
                  hint: existing && !_canSetTemporaryPassword
                      ? 'Используется текущий пароль сотрудника'
                      : 'Минимум 8 символов · придёт сотруднику на почту',
                  enabled: !existing || _canSetTemporaryPassword,
                  obscureText: !_passwordVisible,
                  suffix: existing && !_canSetTemporaryPassword
                      ? const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: _muted,
                        )
                      : IconButton(
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _profile,
                  decoration: InputDecoration(
                    labelText: 'Роль сотрудника',
                    filled: true,
                    fillColor: _soft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _line),
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
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Доступ к командам',
                        style: TextStyle(
                          color: _text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.teams.isEmpty || _saving
                          ? null
                          : () {
                              setState(() {
                                if (_selectedTeamIds.length ==
                                    widget.teams
                                        .map(_teamId)
                                        .where((id) => id > 0)
                                        .length) {
                                  _selectedTeamIds.clear();
                                } else {
                                  _selectedTeamIds
                                    ..clear()
                                    ..addAll(
                                      widget.teams
                                          .map(_teamId)
                                          .where((id) => id > 0),
                                    );
                                }
                              });
                            },
                      child: const Text('Все команды'),
                    ),
                  ],
                ),
                const Text(
                  'Можно выбрать несколько команд. Staff Key будет один на весь клуб.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 7),
                if (widget.teams.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'У клуба пока нет команд. Доступ будет создан на уровне клуба.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10.8,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        for (var index = 0;
                            index < widget.teams.length;
                            index++) ...[
                          Builder(
                            builder: (context) {
                              final team = widget.teams[index];
                              final id = _teamId(team);
                              final selected = _selectedTeamIds.contains(id);

                              return CheckboxListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                ),
                                activeColor: _green,
                                value: selected,
                                onChanged: id <= 0 || _saving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedTeamIds.add(id);
                                          } else {
                                            _selectedTeamIds.remove(id);
                                          }
                                        });
                                      },
                                title: Text(
                                  _teamName(team),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _text,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (index != widget.teams.length - 1)
                            const Divider(
                              height: 1,
                              indent: 10,
                              endIndent: 10,
                              color: _line,
                            ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
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
                        : Text(
                            existing
                                ? (_canSetTemporaryPassword
                                    ? 'Обновить пароль и Staff Key'
                                    : 'Выпустить Staff Key сотруднику')
                                : 'Создать сотрудника и Staff Key',
                          ),
                  ),
                ),
                if (notChecked) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Сначала проверьте email. Если аккаунт существует, он появится выше. '
                    'Если нет — SPORTOTEKA создаст нового сотрудника с указанным паролем.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9.9,
                      height: 1.35,
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
}
