import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sportoteka/core/staff_access/staff_access_service.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class CmrStaffAddRightPanel extends StatefulWidget {
  final int clubId;
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final bool pressMode;
  final String initialProfile;
  final bool lockProfile;
  final VoidCallback onClose;
  final Future<void> Function()? onSaved;
  final Future<bool> Function({
    required int userId,
    required List<int> teamIds,
    required bool allTeams,
  })? onAssignExistingPress;

  const CmrStaffAddRightPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teams,
    this.pressMode = false,
    this.initialProfile = 'extra',
    this.lockProfile = false,
    required this.onClose,
    this.onSaved,
    this.onAssignExistingPress,
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
  bool _issuedPasswordVisible = true;
  bool _issuedKeyVisible = true;
  Map<String, dynamic>? _issuedCredentials;

  bool? _userExists;
  Map<String, dynamic>? _existingUser;
  Map<String, dynamic>? _existingStaffAccess;
  String _profile = 'extra';
  String _message = '';
  bool _messageError = false;
  String _checkedEmail = '';

  final Set<int> _selectedTeamIds = <int>{};

  static const Map<String, String> _roles = <String, String>{
    'main': 'Главный тренер',
    'extra': 'Тренер',
    'goalkeeper': 'Тренер по вратарям',
    'assistant': 'Ассистент',
    'doctor': 'Врач спортивной медицины',
    'press_assistant': 'Пресс-служба',
    'manager': 'Администратор',
  };

  @override
  void initState() {
    super.initState();

    final requested = widget.pressMode
        ? 'press_assistant'
        : widget.initialProfile.trim().toLowerCase();
    _profile = _roles.containsKey(requested) ? requested : 'extra';

    // Если открыт конкретный team workspace, всё равно не выбираем команды
    // автоматически: клуб сам явно отмечает все необходимые команды.
  }

  @override
  void didUpdateWidget(covariant CmrStaffAddRightPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pressMode != widget.pressMode ||
        oldWidget.initialProfile != widget.initialProfile ||
        oldWidget.lockProfile != widget.lockProfile) {
      setState(() {
        final requested = widget.pressMode
            ? 'press_assistant'
            : widget.initialProfile.trim().toLowerCase();
        _profile = _roles.containsKey(requested) ? requested : 'extra';
        _message = '';
        _messageError = false;
        _issuedCredentials = null;
      });
    }
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

  int _userId(Map<String, dynamic> user) =>
      _int(user['id'] ?? user['user_id'] ?? user['userId']);

  List<int> get _validTeamIds =>
      widget.teams.map(_teamId).where((id) => id > 0).toSet().toList();

  bool get _allTeamsSelected =>
      _validTeamIds.isNotEmpty &&
      _selectedTeamIds.length == _validTeamIds.length &&
      _selectedTeamIds.containsAll(_validTeamIds);

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
        _existingUser = null;
        _existingStaffAccess = null;
        _message = '';
        _messageError = false;
        _issuedCredentials = null;
        _firstNameC.clear();
        _lastNameC.clear();
        _passwordC.clear();
      });
    }
  }

  String _generateTemporaryPassword({int length = 12}) {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%';
    final random = math.Random.secure();
    return List<String>.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  void _regenerateTemporaryPassword() {
    if (_saving || _userExists == true) return;

    setState(() {
      _passwordC.text = _generateTemporaryPassword();
      _passwordVisible = true;
    });
  }

  Future<void> _checkEmail() async {
    if (_checking || _saving) return;

    final email = _emailC.text.trim().toLowerCase();

    if (!_emailLooksValid(email)) {
      setState(() {
        _userExists = null;
        _existingUser = null;
        _existingStaffAccess = null;
        _checkedEmail = '';
        _message = 'Укажите действительный адрес электронной почты.';
        _messageError = true;
      });
      return;
    }

    if (widget.pressMode &&
        widget.teams.isNotEmpty &&
        _selectedTeamIds.isEmpty) {
      setState(() {
        _message = 'Выберите хотя бы одну команду для доступа пресс-службы.';
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
        _existingUser = null;
        _existingStaffAccess = null;
        _message =
            '${result['message'] ?? 'Не удалось проверить адрес электронной почты.'}';
        _messageError = true;
      });
      return;
    }

    final exists = result['exists'] == true && result['user'] is Map;

    if (exists) {
      final user = Map<String, dynamic>.from(result['user'] as Map);
      final rawAccess = result['staff_access'];
      final existingAccess = rawAccess is Map
          ? Map<String, dynamic>.from(rawAccess)
          : null;

      _firstNameC.text = '${user['first_name'] ?? ''}'.trim();
      _lastNameC.text = '${user['last_name'] ?? ''}'.trim();
      _passwordC.clear();

      setState(() {
        _checking = false;
        _checkedEmail = email;
        _userExists = true;
        _existingUser = user;
        _existingStaffAccess = existingAccess;

        if (widget.pressMode) {
          _profile = 'press_assistant';
          _message = existingAccess != null
              ? 'Пользователь уже является сотрудником клуба. Основная роль, '
                  'пароль и текущий Staff Key сохранятся — будет добавлен '
                  'или обновлён только доступ пресс-службы к выбранным командам.'
              : 'Пользователь SPORTOTEKA найден. Выберите команды для пресс-службы. '
                  'Его пароль изменён не будет; будет выпущен Staff Key.';
        } else {
          _message =
              'Пользователь SPORTOTEKA найден и выбран. Выберите роль и команды. '
              'Его действующий пароль изменён не будет.';
        }

        _messageError = false;
      });
      return;
    }

    _firstNameC.clear();
    _lastNameC.clear();
    _passwordC.text = _generateTemporaryPassword();

    setState(() {
      _checking = false;
      _checkedEmail = email;
      _userExists = false;
      _existingUser = null;
      _existingStaffAccess = null;
      _passwordVisible = true;

      if (widget.pressMode) {
        _profile = 'press_assistant';
        _message =
            'Пользователь не зарегистрирован. SPORTOTEKA создаст новый аккаунт, '
            'добавит его в пресс-службу и отправит временный пароль и Staff Key на почту.';
      } else {
        _message =
            'Пользователь не зарегистрирован. SPORTOTEKA создаст новый аккаунт, '
            'назначит сотрудника и отправит ему временный пароль и Staff Key на почту.';
      }

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
      if (widget.pressMode) {
        if (_userExists == true) {
          return 'Пресс-доступ сохранён. Staff Key отправлен сотруднику на почту.';
        }
        return 'Аккаунт создан. Временный пароль, Staff Key и пресс-доступ отправлены сотруднику.';
      }

      if (_userExists == true) {
        return 'Сотрудник добавлен. Staff Key отправлен ему на почту.';
      }
      return 'Аккаунт создан. Временный пароль и Staff Key отправлены сотруднику на почту.';
    }

    return _userExists == true
        ? 'Сотрудник добавлен и Staff Key выпущен, но письмо не удалось доставить.'
        : 'Аккаунт создан и Staff Key выпущен, но письмо не удалось доставить. '
            'Проверьте адрес электронной почты.';
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

      if (_lastNameC.text.trim().isEmpty) {
        setState(() {
          _message = 'Укажите фамилию нового сотрудника.';
          _messageError = true;
        });
        return;
      }

      if (_passwordC.text.length < 8) {
        setState(() {
          _message =
              'Временный пароль должен содержать не менее 8 символов.';
          _messageError = true;
        });
        return;
      }
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

    // Если человек уже является сотрудником клуба, пресс-служба должна
    // добавляться как дополнительный доступ. Не перевыпускаем Staff Key,
    // не меняем основную роль и не перезаписываем существующие team scopes.
    if (widget.pressMode &&
        _userExists == true &&
        _existingStaffAccess != null) {
      final user = _existingUser;
      final userId = user == null ? 0 : _userId(user);
      final assignPress = widget.onAssignExistingPress;

      if (userId <= 0 || assignPress == null) {
        setState(() {
          _saving = false;
          _message =
              'Не удалось добавить пресс-доступ существующему сотруднику.';
          _messageError = true;
        });
        return;
      }

      final ok = await assignPress(
        userId: userId,
        teamIds: _selectedTeamIds.toList(),
        allTeams: _allTeamsSelected,
      );

      if (!mounted) return;

      if (!ok) {
        setState(() {
          _saving = false;
          _message = 'Не удалось сохранить доступ пресс-службы.';
          _messageError = true;
        });
        return;
      }

      setState(() {
        _saving = false;
        _message =
            'Пресс-доступ сохранён. Основная роль сотрудника и Staff Key не изменены.';
        _messageError = false;
      });

      await widget.onSaved?.call();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сотрудник добавлен в пресс-службу.'),
        ),
      );

      widget.onClose();
      return;
    }

    final result = await StaffAccessService.invite(
      clubId: widget.clubId,
      actorUserId: actorUserId,
      email: email,
      firstName: _firstNameC.text.trim(),
      lastName: _lastNameC.text.trim(),
      password: _userExists == true ? '' : _passwordC.text,
      profile: widget.pressMode ? 'press_assistant' : _profile,
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
    final temporaryPassword =
        '${result['temporary_password'] ?? (_userExists == true ? '' : _passwordC.text)}'
            .trim();
    final staffKey = '${result['staff_key'] ?? ''}'.trim();

    setState(() {
      _saving = false;
      _message = friendly;
      _messageError = !mailSent;
      _issuedPasswordVisible = true;
      _issuedKeyVisible = true;
      _issuedCredentials = <String, dynamic>{
        'email': email,
        'temporary_password': temporaryPassword,
        'staff_key': staffKey,
        'mail_sent': mailSent,
        'existing_user': _userExists == true,
      };
    });

    await widget.onSaved?.call();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mailSent
              ? (widget.pressMode
                  ? 'Пресс-доступ сохранён. Данные отправлены на почту.'
                  : 'Доступ сотрудника сохранён. Данные отправлены на почту.')
              : 'Доступ сохранён. Проверьте данные и передайте их сотруднику вручную.',
        ),
      ),
    );
  }

  String get _contextRoleTitle => _roles[_profile] ?? 'Тренер';

  String get _panelTitle {
    if (widget.pressMode) return 'Добавить в пресс-службу';
    if (!widget.lockProfile) return 'Добавить сотрудника';
    switch (_profile) {
      case 'main':
        return 'Добавить главного тренера';
      case 'goalkeeper':
        return 'Добавить тренера по вратарям';
      case 'assistant':
        return 'Добавить ассистента';
      case 'doctor':
        return 'Добавить врача спортивной медицины';
      case 'manager':
        return 'Добавить администратора';
      default:
        return 'Добавить тренера';
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

  Widget _credentialLine({
    required IconData icon,
    required String label,
    required String value,
    required bool visible,
    VoidCallback? onToggle,
  }) {
    final shown = visible ? value : '••••••••••••';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _greenDark),
          const SizedBox(width: 9),
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              shown,
              style: const TextStyle(
                color: _text,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onToggle != null)
            IconButton(
              tooltip: visible ? 'Скрыть' : 'Показать',
              onPressed: onToggle,
              icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: _greenDark,
              ),
            ),
          IconButton(
            tooltip: 'Копировать',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label скопирован')),
              );
            },
            icon: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: _greenDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _issuedCredentialsView() {
    final data = _issuedCredentials!;
    final email = '${data['email'] ?? ''}'.trim();
    final password = '${data['temporary_password'] ?? ''}'.trim();
    final staffKey = '${data['staff_key'] ?? ''}'.trim();
    final mailSent = data['mail_sent'] == true;
    final existingUser = data['existing_user'] == true;

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
                const Icon(
                  Icons.check_circle_rounded,
                  color: _green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Доступ сотрудника создан',
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
                  onPressed: widget.onClose,
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
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: mailSent ? _greenSoft : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: mailSent ? _greenBorder : const Color(0xFFFDE7B0),
                    ),
                  ),
                  child: Text(
                    mailSent
                        ? 'Данные отправлены сотруднику на email. Скопировать их можно и здесь.'
                        : 'Письмо не отправлено. Скопируйте данные ниже и передайте сотруднику вручную.',
                    style: const TextStyle(
                      color: _text,
                      fontSize: 10.8,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _credentialLine(
                  icon: Icons.alternate_email_rounded,
                  label: 'Email',
                  value: email,
                  visible: true,
                ),
                const SizedBox(height: 8),
                if (password.isNotEmpty)
                  _credentialLine(
                    icon: Icons.password_rounded,
                    label: 'Временный пароль',
                    value: password,
                    visible: _issuedPasswordVisible,
                    onToggle: () {
                      setState(() {
                        _issuedPasswordVisible = !_issuedPasswordVisible;
                      });
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      existingUser
                          ? 'Пароль существующего аккаунта не изменялся.'
                          : 'Временный пароль не был возвращён сервером.',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10.8,
                      ),
                    ),
                  ),
                if (password.isNotEmpty) const SizedBox(height: 8),
                if (staffKey.isNotEmpty)
                  _credentialLine(
                    icon: Icons.key_rounded,
                    label: 'Staff Key',
                    value: staffKey,
                    visible: _issuedKeyVisible,
                    onToggle: () {
                      setState(() {
                        _issuedKeyVisible = !_issuedKeyVisible;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Временный пароль показывается только сейчас. После закрытия окна текущий пароль нельзя получить из базы — при необходимости используйте «Перевыпустить пароль» в рабочем профиле сотрудника.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10.3,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: widget.onClose,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_issuedCredentials != null) {
      return _issuedCredentialsView();
    }

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
                      Text(
                        _panelTitle,
                        style: const TextStyle(
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
                if (existing)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _line),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: _muted,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Пароль существующего аккаунта не изменяется',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _field(
                    controller: _passwordC,
                    label: 'Временный пароль',
                    hint: 'Минимум 8 символов · придёт сотруднику на почту',
                    enabled: !notChecked,
                    obscureText: !_passwordVisible,
                    suffix: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Сгенерировать новый пароль',
                          onPressed:
                              newUser && !_saving ? _regenerateTemporaryPassword : null,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 18,
                          ),
                        ),
                        IconButton(
                          tooltip: _passwordVisible
                              ? 'Скрыть пароль'
                              : 'Показать пароль',
                          onPressed: newUser
                              ? () {
                                  setState(() {
                                    _passwordVisible = !_passwordVisible;
                                  });
                                }
                              : null,
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                if (widget.pressMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _greenSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _greenBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 18,
                          color: _greenDark,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Пресс-служба',
                                style: TextStyle(
                                  color: _text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Дополнительный пресс-доступ. Основная должность сотрудника сохраняется.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 10.2,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  if (widget.lockProfile || widget.pressMode)
                  Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _greenSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _greenBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: _greenDark,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Роль сотрудника',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 9.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _contextRoleTitle,
                                style: const TextStyle(
                                  color: _text,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 17,
                          color: _greenDark,
                        ),
                      ],
                    ),
                  )
                else
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
                    Expanded(
                      child: Text(
                        widget.pressMode
                            ? 'Доступ пресс-службы к командам'
                            : 'Доступ к командам',
                        style: const TextStyle(
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
                Text(
                  widget.pressMode
                      ? 'Можно выбрать одну, несколько или все команды. '
                          'У существующего сотрудника Staff Key и основная роль не изменятся.'
                      : 'Можно выбрать несколько команд. Staff Key будет один на весь клуб.',
                  style: const TextStyle(
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
                            widget.pressMode
                                ? (existing
                                    ? (_existingStaffAccess != null
                                        ? 'Сохранить пресс-доступ'
                                        : 'Выдать Staff Key и пресс-доступ')
                                    : 'Создать аккаунт и выдать пресс-доступ')
                                : (existing
                                    ? 'Добавить сотрудника и выпустить Staff Key'
                                    : 'Создать аккаунт и отправить доступ'),
                          ),
                  ),
                ),
                if (notChecked) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.pressMode
                        ? 'Сначала проверьте email. Если человек уже сотрудник клуба, '
                            'мы добавим только пресс-доступ и сохраним его основную роль. '
                            'Если аккаунта нет — SPORTOTEKA создаст его и отправит временный пароль и Staff Key.'
                        : 'Сначала проверьте email. Если аккаунт существует, SPORTOTEKA выберет его '
                            'и не изменит пароль. Если аккаунта нет — будет создан новый сотрудник, '
                            'а временный пароль и Staff Key придут ему на почту.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
