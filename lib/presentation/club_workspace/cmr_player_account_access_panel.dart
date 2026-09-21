import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';

class CmrPlayerAccountAccessPanel extends StatefulWidget {
  final Map<String, dynamic> player;
  final int clubId;
  final int teamId;
  final int? currentUserId;
  final bool compact;

  const CmrPlayerAccountAccessPanel({
    super.key,
    required this.player,
    required this.clubId,
    required this.teamId,
    required this.currentUserId,
    this.compact = true,
  });

  @override
  State<CmrPlayerAccountAccessPanel> createState() =>
      _CmrPlayerAccountAccessPanelState();
}

class _CmrPlayerAccountAccessPanelState
    extends State<CmrPlayerAccountAccessPanel> {
  static const _base = 'https://sportotekaapp.ru/api/player_access';

  bool _loading = true;
  bool _authorized = false;
  bool _working = false;
  String _error = '';
  Map<String, dynamic>? _account;

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  String _text(dynamic value) {
    final s = '${value ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  int get _userId => _int(
        widget.player['user_id'] ??
            widget.player['userId'],
      );

  int get _playerId => _int(
        widget.player['player_id'] ??
            widget.player['playerId'] ??
            widget.player['id'],
      );

  Future<int> _actorUserId() async {
    final direct = widget.currentUserId ?? 0;
    if (direct > 0) return direct;
    return await PrefUtils.getUserId() ?? 0;
  }

  bool get _isChildAccount {
    final mode = _text(_account?['account_mode'] ?? widget.player['account_mode']);
    final login = _text(_account?['login'] ?? widget.player['login']);
    final email = _text(_account?['email'] ?? widget.player['email']);
    return mode == 'child' ||
        _account?['child_account'] == true ||
        (login.isNotEmpty && email.isEmpty);
  }

  Future<void> _copyValue(String value, String message) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CmrPlayerAccountAccessPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUser = _int(oldWidget.player['user_id'] ?? oldWidget.player['userId']);
    final newUser = _userId;
    final oldPlayer = _int(oldWidget.player['player_id'] ?? oldWidget.player['id']);
    if (oldWidget.clubId != widget.clubId ||
        oldWidget.currentUserId != widget.currentUserId ||
        oldUser != newUser ||
        oldPlayer != _playerId) {
      _load();
    }
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_base/$endpoint'),
          headers: const {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 18));

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      map['_http_status'] = response.statusCode;
      return map;
    }

    return {
      'success': false,
      'message': 'Некорректный ответ сервера',
      '_http_status': response.statusCode,
    };
  }

  Future<void> _load() async {
    final actor = await _actorUserId();
    if (widget.clubId <= 0 || actor <= 0 || (_userId <= 0 && _playerId <= 0)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _authorized = false;
          _account = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    try {
      final result = await _post('status.php', {
        'club_id': widget.clubId,
        'actor_user_id': actor,
        'user_id': _userId,
        'player_id': _playerId,
      });

      final status = _int(result['_http_status']);
      if (!mounted) return;

      if (status == 403) {
        setState(() {
          _loading = false;
          _authorized = false;
          _account = null;
          _error = '';
        });
        return;
      }

      if (result['success'] != true) {
        setState(() {
          _loading = false;
          _authorized = true;
          _account = null;
          _error = _text(result['message']);
        });
        return;
      }

      setState(() {
        _loading = false;
        _authorized = true;
        _account = result['player'] is Map
            ? Map<String, dynamic>.from(result['player'])
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _authorized = true;
        _error = 'Не удалось проверить аккаунт игрока: $e';
      });
    }
  }

  Future<void> _reissuePassword() async {
    if (_working) return;

    final email = _text(_account?['email'] ?? widget.player['email']);
    final login = _text(_account?['login'] ?? widget.player['login']);
    final childAccount = _isChildAccount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Перевыпустить пароль?'),
        content: Text(
          childAccount
              ? 'Будет создан новый временный пароль детского аккаунта. Старый пароль сразу перестанет работать. Новый пароль нужно скопировать и передать родителю или игроку.'
              : 'Будет создан новый временный пароль. Старый пароль сразу перестанет работать.${email.isNotEmpty ? ' Новый пароль будет отправлен игроку на email.' : ' Новый пароль нужно будет передать игроку вручную.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Создать новый пароль'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      final actor = await _actorUserId();
      final result = await _post('password.php', {
        'club_id': widget.clubId,
        'actor_user_id': actor,
        'user_id': _userId,
        'player_id': _playerId,
      });

      if (!mounted) return;
      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_text(result['message']).isEmpty
              ? 'Не удалось перевыпустить пароль'
              : _text(result['message']))),
        );
        return;
      }

      final password = _text(result['temporary_password']);
      final resultEmail = _text(result['email'] ?? email);
      final resultLogin = _text(result['login'] ?? login);
      final resultChild = result['child_account'] == true ||
          _text(result['account_mode']) == 'child' ||
          (resultLogin.isNotEmpty && resultEmail.isEmpty);
      final mailSent = result['mail_sent'] == true;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(resultChild ? 'Новый пароль ребёнка' : 'Новый пароль игрока'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (resultLogin.isNotEmpty) ...[
                const Text('Логин:'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        resultLogin,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Копировать логин',
                      onPressed: () => Clipboard.setData(ClipboardData(text: resultLogin)),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ] else if (resultEmail.isNotEmpty) ...[
                Text(resultEmail),
                const SizedBox(height: 10),
              ],
              const Text('Временный пароль:'),
              const SizedBox(height: 6),
              SelectableText(
                password,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                resultChild
                    ? 'Письмо не требуется. Скопируйте логин и новый пароль и передайте их родителю или игроку.'
                    : mailSent
                        ? 'Пароль отправлен игроку на email.'
                        : 'Письмо не отправлено. Скопируйте пароль и передайте игроку вручную.',
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: password.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: password));
                    },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Копировать пароль'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Готово'),
            ),
          ],
        ),
      );

      await _load();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && !_authorized) return const SizedBox.shrink();

    final email = _text(_account?['email'] ?? widget.player['email']);
    final login = _text(_account?['login'] ?? widget.player['login']);
    final team = _text(_account?['team_name']);
    final childAccount = _isChildAccount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6ECE8)),
      ),
      child: _loading
          ? const SizedBox(
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_person_outlined, size: 19, color: Color(0xFF067A46)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Аккаунт игрока',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                if (_error.isNotEmpty)
                  Text(
                    _error,
                    style: const TextStyle(color: Color(0xFFD92D20), fontSize: 11.5),
                  )
                else ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3FAF6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          childAccount ? 'Детский аккаунт' : 'Аккаунт по email',
                          style: const TextStyle(
                            fontSize: 10.3,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF067A46),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (login.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.alternate_email_rounded, size: 15, color: Color(0xFF667085)),
                        const SizedBox(width: 7),
                        Expanded(
                          child: SelectableText(
                            login,
                            style: const TextStyle(fontSize: 11.8, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Копировать логин',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _copyValue(login, 'Логин скопирован'),
                          icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF067A46)),
                        ),
                      ],
                    )
                  else if (email.isNotEmpty)
                    Text(email, style: const TextStyle(fontSize: 11.5)),
                  if (team.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(team, style: const TextStyle(fontSize: 10.5, color: Color(0xFF667085))),
                  ],
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(Icons.password_rounded, size: 16, color: Color(0xFF667085)),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Текущий пароль защищён',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 210,
                        maxWidth: 280,
                      ),
                      child: _PlayerAccountActionButton(
                        icon: Icons.lock_reset_rounded,
                        label: _working
                            ? 'Создание...'
                            : 'Перевыпустить пароль',
                        onTap: _working ? null : _reissuePassword,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}


class _PlayerAccountActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _PlayerAccountActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const greenDark = Color(0xFF067A46);
    const greenSoft = Color(0xFFF3FAF6);
    const greenBorder = Color(0xFFD7F0E2);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        decoration: BoxDecoration(
          color: greenSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: greenBorder, width: .8),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Opacity(
            opacity: onTap == null ? .5 : 1,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: greenDark),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: greenDark,
                        fontSize: 12.3,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
