import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/player_profile_screen/cmr_player_profile_screen.dart';
import 'package:sportoteka/presentation/player_profile_screen/models/player_profile_models.dart';

/// Рабочий экран родителя.
///
/// Родитель не выбирает игрока по ID вручную: список детей всегда приходит
/// только из parent_player_access после активации одноразового Parent Key.
class ParentFamilyScreen extends StatefulWidget {
  const ParentFamilyScreen({super.key});

  @override
  State<ParentFamilyScreen> createState() => _ParentFamilyScreenState();
}

class _ParentFamilyScreenState extends State<ParentFamilyScreen> with WidgetsBindingObserver {
  static const _apiBase = 'https://sportotekaapp.ru/api';
  static const _childrenUrl = '$_apiBase/get_parent_children.php';
  static const _redeemUrl = '$_apiBase/redeem_parent_invite.php';

  final _keyC = TextEditingController();
  bool _loading = true;
  bool _redeeming = false;
  String? _error;
  int _parentUserId = 0;
  List<Map<String, dynamic>> _children = [];
  int _selectedPlayerId = 0;
  Timer? _accessRefreshTimer;

  static const _parentSections = <PlayerProfileSection>{
    PlayerProfileSection.overview,
    PlayerProfileSection.diary,
    PlayerProfileSection.activity,
    PlayerProfileSection.matches,
    PlayerProfileSection.testing,
    PlayerProfileSection.card,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _accessRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (mounted) _load(silent: true);
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accessRefreshTimer?.cancel();
    _keyC.dispose();
    super.dispose();
  }

  String _s(dynamic v) {
    final text = '${v ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  int _i(dynamic v) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? 0;

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

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final userId = await PrefUtils.getUserId() ?? 0;
      if (userId <= 0) throw Exception('Не удалось определить аккаунт родителя');
      final data = await _post(_childrenUrl, {'parent_user_id': userId});
      if (data['success'] != true) {
        throw Exception(_s(data['message'] ?? data['error']).isEmpty ? 'Не удалось загрузить детей' : _s(data['message'] ?? data['error']));
      }
      final raw = data['children'];
      final children = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _parentUserId = userId;
        _children = children;
        if (_selectedPlayerId <= 0 || !children.any((e) => _i(e['player_id'] ?? e['id']) == _selectedPlayerId)) {
          _selectedPlayerId = children.isEmpty ? 0 : _i(children.first['player_id'] ?? children.first['id']);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Map<String, dynamic>? get _selectedChild {
    for (final child in _children) {
      if (_i(child['player_id'] ?? child['id']) == _selectedPlayerId) return child;
    }
    return _children.isEmpty ? null : _children.first;
  }

  String _playerName(Map<String, dynamic> child) {
    final full = _s(child['full_name'] ?? child['name']);
    if (full.isNotEmpty) return full;
    final value = '${_s(child['last_name'])} ${_s(child['first_name'])}'.trim();
    return value.isEmpty ? 'Игрок' : value;
  }

  String _photo(Map<String, dynamic> child) {
    var raw = _s(child['photo_url'] ?? child['photo'] ?? child['avatar']);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/$raw';
  }

  Future<void> _showRedeemDialog() async {
    _keyC.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            final code = _keyC.text.trim();
            if (code.isEmpty || _redeeming) return;
            setDialogState(() => _redeeming = true);
            try {
              final userId = _parentUserId > 0 ? _parentUserId : (await PrefUtils.getUserId() ?? 0);
              if (userId <= 0) throw Exception('Не удалось определить аккаунт');
              final data = await _post(_redeemUrl, {
                'parent_user_id': userId,
                'invite_code': code,
              });
              if (data['success'] != true) {
                throw Exception(_s(data['message'] ?? data['error']).isEmpty ? 'Ключ не принят' : _s(data['message'] ?? data['error']));
              }
              final childRaw = data['child'];
              final child = childRaw is Map ? Map<String, dynamic>.from(childRaw) : null;
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (child != null) _selectedPlayerId = _i(child['player_id'] ?? child['id']);
              await _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Игрок привязан к вашему аккаунту')));
              }
            } catch (e) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                );
              }
            } finally {
              _redeeming = false;
              if (dialogContext.mounted) setDialogState(() {});
            }
          }

          return AlertDialog(
            title: Text('Добавить ребёнка по ключу', style: _ParentText.title(18)),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Введите одноразовый ключ, который выдал клуб для конкретного игрока.', style: _ParentText.muted(11.8)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _keyC,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      hintText: 'SPT-ABCD-EFGH',
                      filled: true,
                      fillColor: _ParentColors.soft,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    style: _ParentText.title(16).copyWith(letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: _redeeming ? null : () => Navigator.of(dialogContext).pop(), child: const Text('Отмена')),
              FilledButton(
                onPressed: _redeeming ? null : submit,
                style: FilledButton.styleFrom(backgroundColor: _ParentColors.green),
                child: Text(_redeeming ? 'Проверка...' : 'Привязать'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openMobileChild(Map<String, dynamic> child) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CmrPlayerProfileScreen(
          player: Map<String, dynamic>.from(child),
          readOnly: true,
          allowedSections: _parentSections,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ParentColors.workspace,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Дневник ребёнка', style: _ParentText.title(17)),
          Text('Посещаемость, оценки, матчи и тестирование', style: _ParentText.muted(10.5)),
        ]),
        actions: [
          IconButton(tooltip: 'Обновить', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          IconButton(tooltip: 'Добавить по ключу', onPressed: _showRedeemDialog, icon: const Icon(Icons.key_rounded, color: _ParentColors.green)),
          const SizedBox(width: 6),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _ParentColors.green));
    if (_error != null) {
      return _ParentEmpty(
        icon: Icons.error_outline_rounded,
        title: 'Не удалось загрузить',
        text: _error!,
        actionTitle: 'Повторить',
        onAction: _load,
      );
    }
    if (_children.isEmpty) {
      return _ParentEmpty(
        icon: Icons.family_restroom_rounded,
        title: 'Ребёнок ещё не привязан',
        text: 'Получите ключ у тренера или руководителя клуба. Ключ выдаётся именно для вашего ребёнка и используется один раз.',
        actionTitle: 'Ввести ключ',
        onAction: _showRedeemDialog,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 760;
        if (mobile) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 120),
            itemCount: _children.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final child = _children[index];
              return _ChildCard(
                child: child,
                name: _playerName(child),
                photo: _photo(child),
                selected: _i(child['player_id'] ?? child['id']) == _selectedPlayerId,
                onTap: () => _openMobileChild(child),
              );
            },
          );
        }

        final listWidth = math.min(340.0, constraints.maxWidth * .30);
        final child = _selectedChild;
        return Padding(
          padding: const EdgeInsets.all(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: Colors.white,
              child: Row(children: [
                SizedBox(
                  width: listWidth,
                  child: Column(children: [
                    _FamilyHeader(count: _children.length, onAddKey: _showRedeemDialog),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _children.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (_, index) {
                          final c = _children[index];
                          final id = _i(c['player_id'] ?? c['id']);
                          return _ChildCard(
                            child: c,
                            name: _playerName(c),
                            photo: _photo(c),
                            selected: id == _selectedPlayerId,
                            onTap: () => setState(() => _selectedPlayerId = id),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
                Container(width: 1, color: _ParentColors.line),
                Expanded(
                  child: child == null
                      ? const _ParentEmpty(icon: Icons.person_search_rounded, title: 'Выберите ребёнка', text: 'Откроется его дневник и прогресс.')
                      : CmrPlayerProfileScreen(
                          key: ValueKey('parent-player-${_i(child['player_id'] ?? child['id'])}'),
                          player: Map<String, dynamic>.from(child),
                          embeddedInWorkspace: true,
                          readOnly: true,
                          allowedSections: _parentSections,
                        ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _ParentColors {
  static const workspace = Color(0xFFF6F7F6);
  static const soft = Color(0xFFFAFBFA);
  static const line = Color(0xFFE9ECEA);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF667085);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
}

class _ParentText {
  static TextStyle title(double size) => AppTypography.custom(size: size, weight: FontWeight.w600, color: _ParentColors.text, height: 1.18);
  static TextStyle muted(double size) => AppTypography.custom(size: size, weight: FontWeight.w400, color: _ParentColors.muted, height: 1.3);
}

class _FamilyHeader extends StatelessWidget {
  final int count;
  final VoidCallback onAddKey;
  const _FamilyHeader({required this.count, required this.onAddKey});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _ParentColors.line))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Мои дети', style: _ParentText.title(15.5)),
            const SizedBox(height: 3),
            Text('$count подключено', style: _ParentText.muted(10.5)),
          ])),
          IconButton(tooltip: 'Добавить по ключу', onPressed: onAddKey, icon: const Icon(Icons.key_rounded, color: _ParentColors.green)),
        ]),
      );
}

class _ChildCard extends StatelessWidget {
  final Map<String, dynamic> child;
  final String name;
  final String photo;
  final bool selected;
  final VoidCallback onTap;
  const _ChildCard({required this.child, required this.name, required this.photo, required this.selected, required this.onTap});

  String _s(dynamic v) => '${v ?? ''}'.trim();

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? _ParentColors.greenSoft : Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: selected ? const Color(0xFFD7F0E2) : _ParentColors.line, width: .8),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  width: 48,
                  height: 48,
                  color: _ParentColors.soft,
                  child: photo.isEmpty
                      ? const Icon(Icons.person_rounded, color: _ParentColors.muted)
                      : Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: _ParentColors.muted)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ParentText.title(13.3)),
                const SizedBox(height: 4),
                Text(
                  [_s(child['team_name']), _s(child['position'])].where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ParentText.muted(10.3),
                ),
              ])),
              Icon(Icons.chevron_right_rounded, color: selected ? _ParentColors.green : _ParentColors.muted, size: 18),
            ]),
          ),
        ),
      );
}

class _ParentEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String? actionTitle;
  final Future<void> Function()? onAction;
  const _ParentEmpty({required this.icon, required this.title, required this.text, this.actionTitle, this.onAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(color: _ParentColors.greenSoft, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: _ParentColors.green, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: _ParentText.title(18)),
            const SizedBox(height: 7),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Text(text, textAlign: TextAlign.center, style: _ParentText.muted(11.8))),
            if (actionTitle != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => onAction!(),
                style: FilledButton.styleFrom(backgroundColor: _ParentColors.green),
                icon: const Icon(Icons.key_rounded, size: 17),
                label: Text(actionTitle!),
              ),
            ],
          ]),
        ),
      );
}
