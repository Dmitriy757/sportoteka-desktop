import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/parent_access/parent_family_screen.dart';

class WorkspaceParentAccessCard extends StatefulWidget {
  const WorkspaceParentAccessCard({
    super.key,
    required this.compact,
  });

  final bool compact;

  @override
  State<WorkspaceParentAccessCard> createState() =>
      _WorkspaceParentAccessCardState();
}

class _WorkspaceParentAccessCardState extends State<WorkspaceParentAccessCard> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const Color _green = Color(0xFF00A750);
  static const Color _greenDark = Color(0xFF067A46);
  static const Color _text = Color(0xFF0B0F14);
  static const Color _secondary = Color(0xFF5F6670);
  static const Color _subtle = Color(0xFF8A9099);
  static const Color _divider = Color(0xFFE9ECEA);
  static const Color _panel = Colors.white;
  static const Color _soft = Color(0xFFF7F8F7);

  final TextEditingController _keyC = TextEditingController();
  int _userId = 0;
  bool _loading = true;
  bool _redeeming = false;
  String? _error;
  List<Map<String, dynamic>> _children = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyC.dispose();
    super.dispose();
  }

  dynamic _decode(String body) {
    try {
      final raw = body.trim();
      final brace = raw.indexOf('{');
      final bracket = raw.indexOf('[');
      var start = 0;
      if (brace >= 0 && bracket >= 0) {
        start = brace < bracket ? brace : bracket;
      } else if (brace >= 0) {
        start = brace;
      } else if (bracket >= 0) {
        start = bracket;
      }
      return jsonDecode(raw.substring(start));
    } catch (_) {
      return null;
    }
  }

  String _message(dynamic data, String fallback) {
    if (data is Map) {
      final value = '${data['message'] ?? data['error'] ?? ''}'.trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return fallback;
  }

  List<Map<String, dynamic>> _extractChildren(dynamic data) {
    dynamic raw = data;
    if (data is Map) {
      raw = data['children'] ??
          data['players'] ??
          data['items'] ??
          data['data'] ??
          const <dynamic>[];
      if (raw is Map) {
        raw = raw['children'] ?? raw['items'] ?? const <dynamic>[];
      }
    }
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/$endpoint'),
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = _decode(utf8.decode(response.bodyBytes));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is List) {
        return <String, dynamic>{
          'success': response.statusCode == 200,
          'children': decoded,
        };
      }
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': 'Ошибка подключения: $e',
      };
    }
    return null;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    _userId = await PrefUtils.getUserId() ?? 0;
    if (_userId <= 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не найден пользователь';
      });
      return;
    }

    final data = await _post(
      'get_parent_children.php',
      <String, dynamic>{'parent_user_id': _userId},
    );

    if (!mounted) return;

    final success = data != null &&
        (data['success'] == true ||
            '${data['status'] ?? ''}'.toLowerCase() == 'success' ||
            data.containsKey('children') ||
            data.containsKey('players'));

    if (!success) {
      setState(() {
        _loading = false;
        _error = _message(data, 'Не удалось проверить родительский доступ');
      });
      return;
    }

    setState(() {
      _children = _extractChildren(data);
      _loading = false;
    });
  }

  Future<void> _redeem() async {
    if (_redeeming) return;
    final code = _keyC.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Введите Parent Key');
      return;
    }

    if (_userId <= 0) _userId = await PrefUtils.getUserId() ?? 0;
    if (_userId <= 0) return;

    setState(() {
      _redeeming = true;
      _error = null;
    });

    final data = await _post(
      'redeem_parent_invite.php',
      <String, dynamic>{
        'parent_user_id': _userId,
        'invite_code': code,
      },
    );

    if (!mounted) return;

    if (data == null || data['success'] != true) {
      setState(() {
        _redeeming = false;
        _error = _message(data, 'Parent Key не принят');
      });
      return;
    }

    _keyC.clear();
    setState(() => _redeeming = false);
    await _load();
  }

  Future<void> _openFamily() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ParentFamilyScreen(),
      ),
    );
    if (mounted) await _load();
  }

  String get _childrenLabel {
    final n = _children.length;
    if (n == 0) return 'Введите Parent Key, выданный клубом';
    if (n == 1) return '1 ребёнок подключён';
    if (n >= 2 && n <= 4) return '$n ребёнка подключено';
    return '$n детей подключено';
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final hasChildren = _children.isNotEmpty;
    final statusColor = hasChildren ? _green : const Color(0xFFF59E0B);

    return Container(
      decoration: BoxDecoration(
        color: compact ? _soft : _panel,
        borderRadius: BorderRadius.circular(compact ? 14 : 12),
        border: compact ? null : Border.all(color: _divider, width: .8),
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 13 : 16,
        compact ? 13 : 15,
        compact ? 12 : 15,
        compact ? 13 : 15,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!compact) ...[
                Container(
                  width: 3,
                  height: 64,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 15),
              ],
              Container(
                width: compact ? 50 : 56,
                height: compact ? 50 : 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3FAF6),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  color: _greenDark,
                  size: 24,
                ),
              ),
              SizedBox(width: compact ? 12 : 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Родительский кабинет',
                            style: AppTypography.custom(
                              size: compact ? 13.8 : 14.8,
                              weight: FontWeight.w600,
                              color: _text,
                              height: 1.18,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        if (!_loading) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              hasChildren ? 'Доступ активен' : 'Нужен ключ',
                              style: AppTypography.custom(
                                size: 9.2,
                                weight: FontWeight.w600,
                                color: statusColor,
                                height: 1,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loading ? 'Проверяем доступ…' : _childrenLabel,
                      style: AppTypography.custom(
                        size: compact ? 11 : 11.6,
                        weight: FontWeight.w400,
                        color: _secondary,
                        height: 1.38,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _green,
                  ),
                )
              else if (hasChildren)
                IconButton(
                  tooltip: 'Открыть',
                  onPressed: _openFamily,
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    color: _greenDark,
                  ),
                ),
            ],
          ),
          if (!_loading) ...[
            const SizedBox(height: 13),
            Container(height: 1, color: _divider),
            const SizedBox(height: 12),
            Text(
              hasChildren ? 'Добавить ещё по Parent Key' : 'Введите Parent Key',
              style: AppTypography.custom(
                size: 10.4,
                weight: FontWeight.w500,
                color: _secondary,
                height: 1.2,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keyC,
                    enabled: !_redeeming,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => _redeem(),
                    decoration: InputDecoration(
                      hintText: 'PARENT-…',
                      isDense: true,
                      filled: true,
                      fillColor: _panel,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: _divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: _divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: _green),
                      ),
                    ),
                    style: AppTypography.custom(
                      size: 11.4,
                      weight: FontWeight.w600,
                      color: _text,
                      height: 1.1,
                      letterSpacing: .2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 42,
                  child: FilledButton(
                    onPressed: _redeeming ? null : _redeem,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: _redeeming
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Активировать'),
                  ),
                ),
              ],
            ),
            if (_error != null && _error!.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                _error!,
                style: AppTypography.custom(
                  size: 10.2,
                  weight: FontWeight.w400,
                  color: const Color(0xFFD92D20),
                  height: 1.3,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
