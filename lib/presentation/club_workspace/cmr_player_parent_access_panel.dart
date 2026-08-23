import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

/// Inline CMR management for one player's parent access.
class CmrPlayerParentAccessPanel extends StatefulWidget {
  final Map<String, dynamic> player;
  final int clubId;
  final int teamId;
  final int? currentUserId;
  final bool compact;

  /// true when the panel is embedded into another vertical scroll view
  /// (for example, the CMR Roster inspector). In this mode the widget
  /// does not create its own ListView/Expanded and therefore does not
  /// fight the parent ScrollController.
  final bool inlineInParentScroll;

  final VoidCallback? onClose;
  final VoidCallback? onChanged;

  const CmrPlayerParentAccessPanel({
    super.key,
    required this.player,
    required this.clubId,
    required this.teamId,
    this.currentUserId,
    this.compact = false,
    this.inlineInParentScroll = false,
    this.onClose,
    this.onChanged,
  });

  @override
  State<CmrPlayerParentAccessPanel> createState() =>
      _CmrPlayerParentAccessPanelState();
}

class _CmrPlayerParentAccessPanelState
    extends State<CmrPlayerParentAccessPanel> {
  static const _base = 'https://sportotekaapp.ru/api';
  static const _listUrl = '$_base/get_team_parents.php';
  static const _createUrl = '$_base/create_parent_invite.php';
  static const _revokeAccessUrl = '$_base/revoke_parent_access.php';
  static const _revokeInviteUrl = '$_base/revoke_parent_invite.php';

  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _userId = 0;
  String _freshCode = '';
  String _freshExpires = '';
  String? _confirm;

  List<Map<String, dynamic>> _parents = [];
  List<Map<String, dynamic>> _invites = [];

  int _i(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}'.trim()) ?? 0;

  String _s(dynamic v) {
    final value = '${v ?? ''}'.trim();
    return value == 'null' ? '' : value;
  }

  int get _playerId =>
      _i(widget.player['player_id'] ?? widget.player['playerId'] ?? widget.player['id']);

  String get _playerName {
    final full =
        _s(widget.player['full_name'] ?? widget.player['fullName'] ?? widget.player['name']);
    if (full.isNotEmpty) return full;
    final last = _s(widget.player['last_name'] ?? widget.player['lastName']);
    final first = _s(widget.player['first_name'] ?? widget.player['firstName']);
    final value = '$last $first'.trim();
    return value.isEmpty ? 'Игрок' : value;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CmrPlayerParentAccessPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = _i(
      oldWidget.player['player_id'] ??
          oldWidget.player['playerId'] ??
          oldWidget.player['id'],
    );
    if (oldId != _playerId ||
        oldWidget.clubId != widget.clubId ||
        oldWidget.teamId != widget.teamId) {
      _freshCode = '';
      _freshExpires = '';
      _confirm = null;
      _load();
    }
  }

  dynamic _decode(String body) {
    final raw = body.trim();
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      final startObject = raw.indexOf('{');
      final startArray = raw.indexOf('[');
      final starts = <int>[
        if (startObject >= 0) startObject,
        if (startArray >= 0) startArray,
      ];
      if (starts.isEmpty) return null;
      starts.sort();
      final start = starts.first;
      final object = start == startObject;
      final end = object ? raw.lastIndexOf('}') : raw.lastIndexOf(']');
      if (end <= start) return null;
      try {
        return jsonDecode(raw.substring(start, end + 1));
      } catch (_) {
        return null;
      }
    }
  }

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 18));

    final decoded = _decode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {
      'success': false,
      'message': 'Некорректный ответ сервера (${response.statusCode})',
    };
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _load({bool silent = false}) async {
    if (_playerId <= 0 || widget.clubId <= 0 || widget.teamId <= 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не хватает ID игрока, команды или клуба';
      });
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      _userId = widget.currentUserId ?? await PrefUtils.getUserId() ?? 0;
      final data = await _post(_listUrl, {
        'club_id': widget.clubId,
        'team_id': widget.teamId,
      });
      if (data['success'] != true) {
        final message = _s(data['message'] ?? data['error']);
        throw Exception(
          message.isEmpty ? 'Не удалось загрузить доступ родителей' : message,
        );
      }

      final linked = <Map<String, dynamic>>[];
      for (final parent in _list(data['parents'])) {
        final children = _list(parent['children']);
        if (children.any(
          (child) => _i(child['player_id'] ?? child['id']) == _playerId,
        )) {
          linked.add(parent);
        }
      }

      final pending = _list(data['invites'])
          .where((invite) => _i(invite['player_id']) == _playerId)
          .toList();

      if (!mounted) return;
      setState(() {
        _parents = linked;
        _invites = pending;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _issue() async {
    if (_saving || _userId <= 0) return;
    setState(() {
      _saving = true;
      _error = null;
      _confirm = null;
    });
    try {
      final data = await _post(_createUrl, {
        'club_id': widget.clubId,
        'team_id': widget.teamId,
        'player_id': _playerId,
        'created_by': _userId,
      });
      if (data['success'] != true) {
        final message = _s(data['message'] ?? data['error']);
        throw Exception(message.isEmpty ? 'Не удалось создать Parent Key' : message);
      }

      final code = _s(data['invite_code'] ?? data['code'] ?? data['parent_key']);
      if (code.isEmpty) throw Exception('Сервер не вернул Parent Key');

      if (!mounted) return;
      setState(() {
        _freshCode = code;
        _freshExpires = _s(data['expires_at'] ?? data['expires']);
      });
      await _load(silent: true);
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revokeParent(Map<String, dynamic> parent) async {
    if (_saving) return;
    final parentId = _i(parent['parent_user_id'] ?? parent['id']);
    final key = 'parent:$parentId';

    if (_confirm != key) {
      setState(() => _confirm = key);
      return;
    }

    setState(() => _saving = true);
    try {
      final data = await _post(_revokeAccessUrl, {
        'team_id': widget.teamId,
        'parent_user_id': parentId,
        'player_id': _playerId,
        'requested_by': _userId,
      });
      if (data['success'] != true) {
        throw Exception(_s(data['message'] ?? data['error']));
      }
      _confirm = null;
      await _load(silent: true);
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revokeInvite(Map<String, dynamic> invite) async {
    if (_saving) return;
    final key = 'invite:${_i(invite['id'])}';

    if (_confirm != key) {
      setState(() => _confirm = key);
      return;
    }

    setState(() => _saving = true);
    try {
      final data = await _post(_revokeInviteUrl, {
        'invite_id': _i(invite['id']),
        'requested_by': _userId,
      });
      if (data['success'] != true) {
        throw Exception(_s(data['message'] ?? data['error']));
      }
      _confirm = null;
      _freshCode = '';
      _freshExpires = '';
      await _load(silent: true);
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _parentName(Map<String, dynamic> parent) {
    final full = _s(parent['full_name'] ?? parent['name']);
    if (full.isNotEmpty) return full;
    final value =
        '${_s(parent['last_name'])} ${_s(parent['first_name'])}'.trim();
    return value.isEmpty ? 'Родитель' : value;
  }

  String _photo(Map<String, dynamic> parent) {
    var raw = _s(parent['photo'] ?? parent['photo_url'] ?? parent['avatar']);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/$raw';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inlineInParentScroll) {
      return Container(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AccessHeader(
              playerName: _playerName,
              onClose: widget.onClose,
              onRefresh: _saving ? null : () => _load(),
              inline: true,
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: _Pc.green,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else
              _buildContent(scrollable: false),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _AccessHeader(
            playerName: _playerName,
            onClose: widget.onClose,
            onRefresh: _saving ? null : () => _load(),
          ),
          Container(height: 1, color: _Pc.line),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _Pc.green,
                      strokeWidth: 2,
                    ),
                  )
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({bool scrollable = true}) {
    final children = <Widget>[
        _AccessStatus(
          linked: _parents.isNotEmpty,
          pending: _invites.isNotEmpty,
        ),
        if (_error != null && _error!.isNotEmpty) ...[
          const SizedBox(height: 9),
          _MessageBox(text: _error!, danger: true),
        ],
        if (_freshCode.isNotEmpty) ...[
          const SizedBox(height: 10),
          _NewKeyBox(
            code: _freshCode,
            expires: _freshExpires,
          ),
        ],
        const SizedBox(height: 13),
        _LabelRow(
          title: 'Родитель',
          value: _parents.isEmpty ? 'не назначен' : '${_parents.length} активн.',
        ),
        const SizedBox(height: 7),
        if (_parents.isEmpty)
          const _EmptyBox(
            icon: Icons.family_restroom_outlined,
            title: 'Нет привязанного родителя',
            text: 'Создайте ключ и передайте его родителю.',
          )
        else
          ..._parents.map(
            (parent) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _ParentBox(
                name: _parentName(parent),
                email: _s(parent['email']),
                photo: _photo(parent),
                confirming:
                    _confirm ==
                    'parent:${_i(parent['parent_user_id'] ?? parent['id'])}',
                busy: _saving,
                onCancel: () => setState(() => _confirm = null),
                onRevoke: () => _revokeParent(parent),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _LabelRow(
          title: 'Ключи',
          value: _invites.isEmpty ? 'нет ожидающих' : '${_invites.length} ожидает',
        ),
        const SizedBox(height: 7),
        if (_invites.isEmpty)
          const _EmptyBox(
            icon: Icons.key_off_outlined,
            title: 'Активных ключей нет',
            text: 'Новый ключ создаётся для этого игрока.',
          )
        else
          ..._invites.map(
            (invite) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _InviteBox(
                hint: _s(invite['code_hint']),
                expires: _s(invite['expires_at']),
                confirming: _confirm == 'invite:${_i(invite['id'])}',
                busy: _saving,
                onCancel: () => setState(() => _confirm = null),
                onRevoke: () => _revokeInvite(invite),
              ),
            ),
          ),
        const SizedBox(height: 13),
        SizedBox(
          height: 44,
          child: FilledButton(
            onPressed: _saving ? null : _issue,
            style: FilledButton.styleFrom(
              backgroundColor: _Pc.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _saving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'Подождите...',
                        style: _Pt.value(12).copyWith(color: Colors.white),
                      ),
                    ],
                  )
                : Text(
                    'Выдать новый ключ',
                    style: _Pt.value(12).copyWith(color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'При отзыве связи игрок удаляется из кабинета этого родителя.',
          style: _Pt.muted(10),
        ),
      ];

    final padding = EdgeInsets.fromLTRB(
      widget.compact ? 2 : 15,
      widget.inlineInParentScroll ? 8 : (widget.compact ? 11 : 15),
      widget.compact ? 2 : 15,
      widget.inlineInParentScroll ? 4 : (widget.compact ? 11 : 15),
    );

    if (scrollable) {
      return ListView(
        padding: padding,
        children: children,
      );
    }

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Pc {
  static const soft = Color(0xFFF7F8F7);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenBorder = Color(0xFFD7F0E2);
  static const greenGlass = Color(0xFFF9FDFB);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF667085);
  static const subtle = Color(0xFF98A2B3);
  static const line = Color(0xFFE9ECEA);
  static const red = Color(0xFFD92D20);
  static const redSoft = Color(0xFFFFF4F2);
  static const amber = Color(0xFFF59E0B);
  static const amberSoft = Color(0xFFFFFAEB);
}

class _Pt {
  static TextStyle title(double s) => AppTypography.custom(
        size: s,
        weight: FontWeight.w600,
        color: _Pc.text,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle value(double s) => AppTypography.custom(
        size: s,
        weight: FontWeight.w600,
        color: _Pc.text,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle muted(double s) => AppTypography.custom(
        size: s,
        weight: FontWeight.w400,
        color: _Pc.muted,
        height: 1.35,
        letterSpacing: 0,
      );
}

class _ParentGlowDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  final bool halo;

  const _ParentGlowDot({
    required this.color,
    this.size = 6,
    this.opacity = 1,
    this.halo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: halo
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withOpacity(.18),
                    blurRadius: size * 1.9,
                    spreadRadius: .2,
                  ),
                  BoxShadow(
                    color: color.withOpacity(.07),
                    blurRadius: size * 3,
                    spreadRadius: .5,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _AccessHeader extends StatelessWidget {
  final String playerName;
  final VoidCallback? onClose;
  final VoidCallback? onRefresh;
  final bool inline;

  const _AccessHeader({
    required this.playerName,
    this.onClose,
    this.onRefresh,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (inline) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 7),
        child: Row(
          children: [
            const _ParentGlowDot(
              color: _Pc.green,
              size: 7,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Доступ родителя', style: _Pt.title(12.2)),
                  const SizedBox(height: 2),
                  Text(
                    'Ключи и привязанные родители',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _Pt.muted(9.8),
                  ),
                ],
              ),
            ),
            if (onRefresh != null)
              Material(
                color: _Pc.soft,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    child: Text(
                      'Обновить',
                      style: _Pt.value(9.8).copyWith(
                        color: _Pc.greenDark,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 33,
              height: 33,
              decoration: BoxDecoration(
                color: _Pc.greenSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Center(
                child: _ParentDotCluster(),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Доступ родителя', style: _Pt.title(13)),
                  const SizedBox(height: 2),
                  Text(
                    playerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _Pt.muted(10.2),
                  ),
                ],
              ),
            ),
            if (onRefresh != null)
              IconButton(
                tooltip: 'Обновить',
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 17,
                  color: _Pc.muted,
                ),
              ),
            if (onClose != null)
              IconButton(
                tooltip: 'Закрыть',
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: _Pc.text,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ParentDotCluster extends StatelessWidget {
  final Color color;
  final bool halo;

  const _ParentDotCluster({
    this.color = _Pc.green,
    this.halo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ParentGlowDot(
          color: color,
          size: 3.5,
          opacity: .24,
          halo: false,
        ),
        const SizedBox(width: 3),
        _ParentGlowDot(
          color: color,
          size: 4.5,
          opacity: .48,
          halo: false,
        ),
        const SizedBox(width: 3),
        _ParentGlowDot(
          color: color,
          size: 5.5,
          opacity: .72,
          halo: false,
        ),
        const SizedBox(width: 3),
        _ParentGlowDot(
          color: color,
          size: 6.5,
          halo: halo,
        ),
      ],
    );
  }
}

class _AccessStatus extends StatelessWidget {
  final bool linked;
  final bool pending;

  const _AccessStatus({
    required this.linked,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final color = linked
        ? _Pc.green
        : pending
            ? _Pc.amber
            : _Pc.muted;

    final title = linked
        ? 'Доступ активен'
        : pending
            ? 'Ожидает активации'
            : 'Родитель не подключён';

    final text = linked
        ? 'Ниже указан родитель, которому доступен этот игрок.'
        : pending
            ? 'Есть действующий одноразовый ключ.'
            : 'Создайте Parent Key для этого игрока.';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withOpacity(linked ? .075 : .045),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: linked
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withOpacity(.035),
                  blurRadius: 16,
                  spreadRadius: -9,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          _ParentGlowDot(
            color: color,
            size: 7,
            halo: linked || pending,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _Pt.value(11.2)),
                const SizedBox(height: 2),
                Text(text, style: _Pt.muted(9.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String title;
  final String value;

  const _LabelRow({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: _Pt.value(11.2))),
        Text(value, style: _Pt.muted(9.5)),
      ],
    );
  }
}

class _NewKeyBox extends StatelessWidget {
  final String code;
  final String expires;

  const _NewKeyBox({
    required this.code,
    required this.expires,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _Pc.greenSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Pc.greenBorder, width: .7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.key_rounded,
                color: _Pc.greenDark,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Новый Parent Key', style: _Pt.value(11.1)),
              ),
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ключ скопирован')),
                    );
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.copy_rounded,
                    color: _Pc.greenDark,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            code,
            style: _Pt.title(18).copyWith(
              color: _Pc.greenDark,
              letterSpacing: 1.5,
            ),
          ),
          if (expires.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('До $expires', style: _Pt.muted(9.5)),
          ],
        ],
      ),
    );
  }
}

class _ParentBox extends StatelessWidget {
  final String name;
  final String email;
  final String photo;
  final bool confirming;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onRevoke;

  const _ParentBox({
    required this.name,
    required this.email,
    required this.photo,
    required this.confirming,
    required this.busy,
    required this.onCancel,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: confirming ? _Pc.redSoft : _Pc.soft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: confirming
          ? Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: _Pc.red,
                  size: 16,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text('Отозвать доступ?', style: _Pt.value(10.4)),
                ),
                TextButton(
                  onPressed: busy ? null : onCancel,
                  child: const Text('Нет'),
                ),
                TextButton(
                  onPressed: busy ? null : onRevoke,
                  child: const Text('Да', style: TextStyle(color: _Pc.red)),
                ),
              ],
            )
          : Row(
              children: [
                _ParentAvatar(photo: photo, name: name),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _Pt.value(11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email.isEmpty ? 'Доступ активен' : email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _Pt.muted(9.5),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Отозвать доступ',
                  child: InkWell(
                    onTap: busy ? null : onRevoke,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.link_off_rounded,
                        color: _Pc.red,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InviteBox extends StatelessWidget {
  final String hint;
  final String expires;
  final bool confirming;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onRevoke;

  const _InviteBox({
    required this.hint,
    required this.expires,
    required this.confirming,
    required this.busy,
    required this.onCancel,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: confirming ? _Pc.redSoft : _Pc.amberSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: confirming
          ? Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: _Pc.red,
                  size: 16,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text('Отменить ключ?', style: _Pt.value(10.4)),
                ),
                TextButton(
                  onPressed: busy ? null : onCancel,
                  child: const Text('Нет'),
                ),
                TextButton(
                  onPressed: busy ? null : onRevoke,
                  child: const Text('Да', style: TextStyle(color: _Pc.red)),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.key_rounded,
                  color: _Pc.amber,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hint.isEmpty ? 'Одноразовый ключ' : '$hint••••',
                        style: _Pt.value(10.8),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        expires.isEmpty ? 'Ожидает активации' : 'До $expires',
                        style: _Pt.muted(9.4),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Отменить ключ',
                  child: InkWell(
                    onTap: busy ? null : onRevoke,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.block_rounded,
                        color: _Pc.red,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyBox({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _Pc.soft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(icon, color: _Pc.subtle, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _Pt.value(10.4)),
                const SizedBox(height: 2),
                Text(text, style: _Pt.muted(9.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final String text;
  final bool danger;

  const _MessageBox({
    required this.text,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? _Pc.red : _Pc.green;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(
            danger ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: _Pt.muted(9.8))),
        ],
      ),
    );
  }
}

class _ParentAvatar extends StatelessWidget {
  final String photo;
  final String name;

  const _ParentAvatar({
    required this.photo,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final parts =
        name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'Р'
        : parts.take(2).map((e) => e.substring(0, 1).toUpperCase()).join();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        color: Colors.white,
        child: photo.isEmpty
            ? Center(child: Text(initials, style: _Pt.value(10.6)))
            : Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Center(child: Text(initials, style: _Pt.value(10.6))),
              ),
      ),
    );
  }
}
