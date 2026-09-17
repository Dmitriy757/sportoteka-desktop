import 'package:flutter/material.dart';

import 'package:sportoteka/core/staff_access/staff_access_service.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_staff_access_panel.dart';

/// Клубное окно администрирования Staff Access.
///
/// Один Staff Key существует на уровне club_id + user_id.
/// Команды являются scope одного клубного доступа.
class CmrStaffAccessAdminPanel extends StatefulWidget {
  final int clubId;
  final String clubName;
  final List<Map<String, dynamic>> staff;
  final List<Map<String, dynamic>> allTeams;
  final VoidCallback onClose;
  final Future<void> Function()? onChanged;

  const CmrStaffAccessAdminPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.staff,
    required this.allTeams,
    required this.onClose,
    this.onChanged,
  });

  @override
  State<CmrStaffAccessAdminPanel> createState() =>
      _CmrStaffAccessAdminPanelState();
}

enum _AccessFilter { all, active, pending, none, revoked }

class _CmrStaffAccessAdminPanelState
    extends State<CmrStaffAccessAdminPanel> {
  static const _green = Color(0xFF00A750);
  static const _greenDark = Color(0xFF067A46);
  static const _greenSoft = Color(0xFFF3FAF6);
  static const _line = Color(0xFFE9ECEA);
  static const _soft = Color(0xFFF7F8F7);
  static const _text = Color(0xFF0B0F14);
  static const _muted = Color(0xFF667085);
  static const _subtle = Color(0xFF8A9099);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFD92D20);

  final TextEditingController _searchC = TextEditingController();

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _actorUserId = 0;
  int _selectedUserId = 0;
  bool _showNarrowDetails = false;
  _AccessFilter _filter = _AccessFilter.all;

  /// user_id -> ответ status.php. Ошибки тоже сохраняем отдельно, чтобы
  /// никогда не выдавать ошибку API за «ключ не выпущен».
  final Map<int, Map<String, dynamic>> _states =
      <int, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_onSearchChanged);
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant CmrStaffAccessAdminPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clubId != widget.clubId ||
        oldWidget.staff.length != widget.staff.length) {
      _loadAll();
    }
  }

  @override
  void dispose() {
    _searchC.removeListener(_onSearchChanged);
    _searchC.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  int _userId(Map<String, dynamic> item) => _int(
        item['user_id'] ??
            item['userId'] ??
            item['trainer_id'] ??
            item['trainerId'] ??
            item['coach_id'] ??
            item['id'],
      );

  int _teamId(Map<String, dynamic> item) =>
      _int(item['team_id'] ?? item['teamId'] ?? item['id']);

  String _string(dynamic value) {
    final v = '${value ?? ''}'.trim();
    return v == 'null' ? '' : v;
  }

  String _name(Map<String, dynamic> item) {
    final full = _string(item['full_name'] ?? item['fullName'] ?? item['name']);
    if (full.isNotEmpty) return full;
    final result =
        '${_string(item['first_name'])} ${_string(item['last_name'])}'.trim();
    return result.isEmpty ? 'Сотрудник' : result;
  }

  String _email(Map<String, dynamic> item) => _string(item['email']);

  String _fallbackRole(Map<String, dynamic> item) {
    final raw = _string(item['profile'] ??
            item['link_profile'] ??
            item['staff_role'] ??
            item['role_code'] ??
            item['position'] ??
            item['role'])
        .toLowerCase();
    if (raw.contains('press') || raw.contains('пресс')) return 'Пресс-служба';
    if (raw == 'main' || raw.contains('глав')) return 'Главный тренер';
    if (raw.contains('assistant') || raw.contains('ассист')) return 'Ассистент';
    if (raw.contains('doctor') || raw.contains('med') || raw.contains('мед')) {
      return 'Медик';
    }
    if (raw.contains('manager') || raw.contains('admin')) {
      return 'Администратор';
    }
    return 'Тренер';
  }

  List<Map<String, dynamic>> _fallbackTeams(Map<String, dynamic> item) {
    final raw = item['teams'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final teamId = _int(item['team_id'] ?? item['teamId']);
    if (teamId <= 0) return const <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'team_id': teamId,
        'team_name':
            item['team_name'] ?? item['teamName'] ?? 'Команда #$teamId',
      },
    ];
  }

  Map<String, dynamic>? _accessFor(int userId) {
    final state = _states[userId];
    if (state == null || state['success'] != true) return null;
    final raw = state['access'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  String _statusFor(int userId) {
    final state = _states[userId];
    if (state == null) return 'loading';
    if (state['success'] != true) return 'error';
    final access = _accessFor(userId);
    if (access == null) return 'none';
    return _string(access['status']).toLowerCase();
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'active':
        return 'Активен';
      case 'pending':
        return 'Ожидает активации';
      case 'revoked':
        return 'Отозван';
      case 'error':
        return 'Ошибка';
      case 'loading':
        return 'Проверка';
      default:
        return 'Без ключа';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return _green;
      case 'pending':
        return _amber;
      case 'revoked':
      case 'error':
        return _red;
      default:
        return _subtle;
    }
  }

  String _roleFor(Map<String, dynamic> item) {
    final access = _accessFor(_userId(item));
    final server = _string(access?['role_title']);
    if (server.isNotEmpty) return server;
    final code = _string(access?['role_code']).toLowerCase();
    const titles = <String, String>{
      'main': 'Главный тренер',
      'extra': 'Тренер',
      'assistant': 'Ассистент',
      'doctor': 'Медик',
      'press_assistant': 'Пресс-служба',
      'manager': 'Администратор',
    };
    return titles[code] ?? _fallbackRole(item);
  }

  List<Map<String, dynamic>> _teamsFor(Map<String, dynamic> item) {
    final access = _accessFor(_userId(item));
    final raw = access?['teams'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return _fallbackTeams(item);
  }

  String _teamName(Map<String, dynamic> team) {
    final name = _string(team['team_name'] ?? team['name'] ?? team['teamName']);
    return name.isEmpty ? 'Команда #${_teamId(team)}' : name;
  }

  List<Map<String, dynamic>> get _uniqueStaff {
    final seen = <int>{};
    final result = <Map<String, dynamic>>[];
    for (final item in widget.staff) {
      final id = _userId(item);
      if (id <= 0 || !seen.add(id)) continue;
      result.add(item);
    }
    result.sort(
      (a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()),
    );
    return result;
  }

  List<Map<String, dynamic>> get _visibleStaff {
    final q = _searchC.text.trim().toLowerCase();
    return _uniqueStaff.where((item) {
      final id = _userId(item);
      final status = _statusFor(id);
      final filterOk = switch (_filter) {
        _AccessFilter.all => true,
        _AccessFilter.active => status == 'active',
        _AccessFilter.pending => status == 'pending',
        _AccessFilter.none => status == 'none',
        _AccessFilter.revoked => status == 'revoked',
      };
      if (!filterOk) return false;
      if (q.isEmpty) return true;
      final haystack = <String>[
        _name(item),
        _email(item),
        _roleFor(item),
        ..._teamsFor(item).map(_teamName),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  int _countStatus(String status) =>
      _uniqueStaff.where((e) => _statusFor(_userId(e)) == status).length;

  Map<String, dynamic>? get _selectedStaff {
    for (final item in _uniqueStaff) {
      if (_userId(item) == _selectedUserId) return item;
    }
    final visible = _visibleStaff;
    return visible.isEmpty ? null : visible.first;
  }

  Future<void> _loadAll() async {
    if (!mounted || widget.clubId <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    _actorUserId = await PrefUtils.getUserId() ?? 0;
    if (_actorUserId <= 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не найден клубный аккаунт.';
      });
      return;
    }

    final rows = _uniqueStaff;
    final results = await Future.wait(
      rows.map((item) async {
        final id = _userId(item);
        final state = await StaffAccessService.loadManagedStatus(
          clubId: widget.clubId,
          staffUserId: id,
          actorUserId: _actorUserId,
        );
        return MapEntry<int, Map<String, dynamic>>(id, state);
      }),
    );

    if (!mounted) return;
    setState(() {
      _states
        ..clear()
        ..addEntries(results);
      _loading = false;
      if (_selectedUserId <= 0 && rows.isNotEmpty) {
        _selectedUserId = _userId(rows.first);
      }
    });
  }

  Future<void> _refreshOne(int userId) async {
    if (userId <= 0 || _actorUserId <= 0) return;
    final result = await StaffAccessService.loadManagedStatus(
      clubId: widget.clubId,
      staffUserId: userId,
      actorUserId: _actorUserId,
    );
    if (!mounted) return;
    setState(() => _states[userId] = result);
    await widget.onChanged?.call();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _loadAll();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 9.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(_AccessFilter value, String title) {
    final active = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _greenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? _green.withOpacity(.18) : _line,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? _greenDark : _muted,
            fontSize: 10.2,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _staffList() {
    final rows = _visibleStaff;
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Сотрудники не найдены',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _line),
      itemBuilder: (context, index) {
        final item = rows[index];
        final id = _userId(item);
        final selected = id == _selectedUserId;
        final status = _statusFor(id);
        final teams = _teamsFor(item);
        return Material(
          color: selected ? _greenSoft : Colors.white,
          child: InkWell(
            onTap: () => setState(() {
              _selectedUserId = id;
              _showNarrowDetails = true;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : _soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _initials(_name(item)),
                      style: TextStyle(
                        color: selected ? _greenDark : _text,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_roleFor(item)} · ${teams.isEmpty ? 'без команды' : '${teams.length} команд(ы)'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 9.8),
                        ),
                        if (_email(item).isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _email(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(color: _subtle, fontSize: 9.2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(.08),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _statusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _statusTitle(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontSize: 8.9,
                            fontWeight: FontWeight.w700,
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
      },
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'С';
    String first(String s) => s.isEmpty ? '' : s.substring(0, 1);
    if (parts.length == 1) return first(parts.first).toUpperCase();
    return '${first(parts.first)}${first(parts.last)}'.toUpperCase();
  }

  Widget _details({bool showBack = false}) {
    final staff = _selectedStaff;
    if (staff == null) {
      return const Center(
        child: Text(
          'Выберите сотрудника',
          style: TextStyle(color: _muted, fontSize: 11),
        ),
      );
    }

    final userId = _userId(staff);
    final state = _states[userId];
    final stateError = state != null && state['success'] != true
        ? _string(state['message'])
        : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
      children: [
        if (showBack) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showNarrowDetails = false),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('К списку сотрудников'),
              style: TextButton.styleFrom(
                foregroundColor: _greenDark,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              ),
            ),
          ),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _greenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _initials(_name(staff)),
                style: const TextStyle(
                  color: _greenDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name(staff),
                    style: const TextStyle(
                      color: _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_roleFor(staff)} · ${_email(staff)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 10.2),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (stateError.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              stateError,
              style: const TextStyle(color: _red, fontSize: 10.4),
            ),
          ),
        ],
        CmrStaffAccessPanel(
          key: ValueKey<String>('club-admin-access-${widget.clubId}-$userId'),
          clubId: widget.clubId,
          staffUserId: userId,
          allTeams: widget.allTeams,
          initiallyExpanded: true,
          adminMode: true,
          onChanged: () => _refreshOne(userId),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _green),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // На узкой правой панели не делим высоту пополам: сначала
        // показываем полноценный список, а карточку сотрудника открываем
        // отдельным экраном внутри панели с кнопкой «Назад».
        final split = constraints.maxWidth >= 640;
        final listPane = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      _stat('${_uniqueStaff.length}', 'Всего'),
                      const SizedBox(width: 6),
                      _stat('${_countStatus('active')}', 'Активны'),
                      const SizedBox(width: 6),
                      _stat('${_countStatus('pending')}', 'Ожидают'),
                      const SizedBox(width: 6),
                      _stat('${_countStatus('none')}', 'Без ключа'),
                    ],
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _searchC,
                    decoration: InputDecoration(
                      hintText: 'Сотрудник, email, роль или команда',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _searchC.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _searchC.clear,
                              icon: const Icon(Icons.close_rounded, size: 17),
                            ),
                      filled: true,
                      fillColor: _soft,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(_AccessFilter.all, 'Все'),
                        const SizedBox(width: 5),
                        _filterChip(_AccessFilter.active, 'Активные'),
                        const SizedBox(width: 5),
                        _filterChip(_AccessFilter.pending, 'Ожидают'),
                        const SizedBox(width: 5),
                        _filterChip(_AccessFilter.none, 'Без ключа'),
                        const SizedBox(width: 5),
                        _filterChip(_AccessFilter.revoked, 'Отозваны'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),
            Expanded(child: _staffList()),
          ],
        );

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _line, width: .7)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _greenSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: _greenDark,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Администрирование сотрудников',
                            style: TextStyle(
                              color: _text,
                              fontSize: 13.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.clubName.isEmpty
                                ? 'Все команды клуба'
                                : '${widget.clubName} · все команды',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(color: _muted, fontSize: 9.6),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Обновить',
                      onPressed: _refreshing ? null : _refresh,
                      icon: _refreshing
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _green,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 19),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: _red, fontSize: 10.4),
                  ),
                ),
              Expanded(
                child: split
                    ? Row(
                        children: [
                          SizedBox(
                            width: (constraints.maxWidth * .40)
                                .clamp(300.0, 400.0)
                                .toDouble(),
                            child: listPane,
                          ),
                          const VerticalDivider(width: 1, color: _line),
                          Expanded(child: _details()),
                        ],
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: _showNarrowDetails
                            ? KeyedSubtree(
                                key: const ValueKey<String>('staff-details'),
                                child: _details(showBack: true),
                              )
                            : KeyedSubtree(
                                key: const ValueKey<String>('staff-list'),
                                child: listPane,
                              ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
