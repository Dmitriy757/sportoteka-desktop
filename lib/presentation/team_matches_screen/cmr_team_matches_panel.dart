// lib/presentation/team_matches_screen/cmr_team_matches_panel.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_matches_screen/team_match_detail_screen.dart';

enum CmrMatchesFilter { all, upcoming, past }

class CmrTeamMatchesPanel extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;

  const CmrTeamMatchesPanel({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<CmrTeamMatchesPanel> createState() => _CmrTeamMatchesPanelState();
}

class _CmrTeamMatchesPanelState extends State<CmrTeamMatchesPanel> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getUrl = '$apiBase/get_team_matches.php';
  static const String addUrl = '$apiBase/add_team_match.php';
  static const String deleteUrl = '$apiBase/delete_team_match.php';
  static const String getUserUrl = '$apiBase/get_user.php';

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  bool loading = true;
  bool refreshing = false;
  String? error;

  int userId = 0;
  String role = '';
  CmrMatchesFilter filter = CmrMatchesFilter.upcoming;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  List<Map<String, dynamic>> matches = [];

  bool get canEdit => role.toLowerCase().trim() != 'player';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    userId = await PrefUtils.getUserId() ?? 0;
    role = userId > 0 ? await _fetchRoleByUser(userId) : '';
    await _fetch(initial: true);
  }

  Future<String> _fetchRoleByUser(int uid) async {
    try {
      final res = await http.get(Uri.parse('$getUserUrl?user_id=$uid')).timeout(const Duration(seconds: 15));
      final data = _decodeJsonMap(res.body);
      final ok = data['success'] == true || data['status'] == 'success';
      if (!ok) return '';
      final user = data['user'];
      if (user is Map) return (user['role'] ?? '').toString().trim().toLowerCase();
    } catch (_) {}
    return '';
  }

  Future<void> _fetch({bool initial = false}) async {
    if (!mounted) return;
    setState(() {
      if (initial) {
        loading = true;
      } else {
        refreshing = true;
      }
      error = null;
    });

    try {
      final res = await http.post(
        Uri.parse(getUrl),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'team_id': widget.teamId}),
      ).timeout(const Duration(seconds: 20));

      final data = _decodeJsonMap(res.body);
      final ok = data['status'] == 'success' || data['success'] == true;
      if (!ok) throw Exception(data['message']?.toString() ?? 'Не удалось загрузить матчи');

      final list = (data['matches'] as List?) ?? [];
      final parsed = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      parsed.sort((a, b) => _parseDate(_s(a['match_date'])).compareTo(_parseDate(_s(b['match_date']))));

      if (!mounted) return;
      setState(() {
        matches = parsed;
        loading = false;
        refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        refreshing = false;
        error = e.toString();
      });
    }
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    final raw = body.trim();
    final start = raw.indexOf('{');
    if (start < 0) throw Exception('Сервер вернул некорректный ответ');
    final decoded = jsonDecode(raw.substring(start));
    if (decoded is! Map) throw Exception('Некорректный формат ответа API');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _openCreate() async {
    if (!canEdit) return;
    if (widget.teamId <= 0) {
      Get.snackbar('Ошибка', 'Не удалось определить team_id');
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CmrAddMatchSheet(
        onSubmit: _addMatch,
      ),
    );

    if (created == true) {
      await _fetch();
      Get.snackbar('Готово', 'Матч добавлен');
    }
  }

  Future<bool> _addMatch({
    required String eventType,
    required String opponent,
    required String ourScore,
    required String opponentScore,
    required String matchDate,
    required String competitionName,
    required String tourLabel,
    required String stadium,
    required String referees,
    required String notes,
  }) async {
    if (!canEdit) return false;
    if (opponent.trim().isEmpty || matchDate.trim().isEmpty) {
      Get.snackbar('Ошибка', 'Укажите соперника и дату матча');
      return false;
    }

    try {
      final res = await http.post(
        Uri.parse(addUrl),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'team_id': widget.teamId,
          'team_name': widget.teamName.trim().isEmpty ? 'Команда #${widget.teamId}' : widget.teamName,
          'event_type': eventType,
          'opponent': opponent.trim(),
          'our_score': int.tryParse(ourScore.trim()) ?? 0,
          'opponent_score': int.tryParse(opponentScore.trim()) ?? 0,
          'match_date': matchDate,
          'competition_name': competitionName.trim(),
          'tour_label': tourLabel.trim(),
          'stadium': stadium.trim(),
          'referees': referees.trim(),
          'notes': notes.trim(),
        }),
      ).timeout(const Duration(seconds: 20));

      final data = _decodeJsonMap(res.body);
      final ok = data['status'] == 'success' || data['success'] == true;
      if (!ok) {
        Get.snackbar('Ошибка', data['message']?.toString() ?? 'Не удалось добавить матч');
        return false;
      }
      return true;
    } catch (e) {
      Get.snackbar('Ошибка', 'Проверь API add_team_match.php');
      return false;
    }
  }

  Future<void> _deleteMatch(Map<String, dynamic> match) async {
    if (!canEdit) return;
    final id = _i(match['id']);
    if (id <= 0) return;

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Удалить матч?'),
        content: Text('Матч с ${_s(match['opponent']).isEmpty ? 'соперником' : _s(match['opponent'])} будет удалён.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: _C.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final res = await http.post(Uri.parse(deleteUrl), body: {
        'id': id.toString(),
        'team_id': widget.teamId.toString(),
      }).timeout(const Duration(seconds: 20));

      final data = _decodeJsonMap(res.body);
      final success = data['status'] == 'success' || data['success'] == true;
      if (!success) throw Exception(data['message']?.toString() ?? 'Не удалось удалить матч');
      await _fetch();
      Get.snackbar('Готово', 'Матч удалён');
    } catch (e) {
      Get.snackbar('Ошибка', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _openDetails(Map<String, dynamic> match) {
    Get.to(
      () => const TeamMatchDetailScreen(),
      arguments: {
        'match': match,
        'match_id': _i(match['id']),
        'team_id': widget.teamId,
      },
    );
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() {});
    });
  }

  String _s(dynamic v) => (v ?? '').toString().trim();
  int _i(dynamic v) => int.tryParse((v ?? '').toString()) ?? 0;

  DateTime _parseDate(String s) {
    try {
      final t = s.trim();
      if (t.contains('.')) {
        final p = t.split('.');
        if (p.length == 3) return DateTime(int.tryParse(p[2]) ?? 2000, int.tryParse(p[1]) ?? 1, int.tryParse(p[0]) ?? 1);
      }
      final d = DateTime.tryParse(t);
      if (d != null) return DateTime(d.year, d.month, d.day);
    } catch (_) {}
    return DateTime(2000, 1, 1);
  }

  String _dateRu(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  bool _isUpcoming(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !d.isBefore(today);
  }

  String _eventTypeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'championship':
        return 'Чемпионат';
      case 'friendly':
        return 'Товарищеский';
      case 'tournament':
        return 'Турнир';
      default:
        return raw.isEmpty ? 'Матч' : raw;
    }
  }

  List<Map<String, dynamic>> _visibleMatches() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final first = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    Iterable<Map<String, dynamic>> list = matches.where((m) {
      final d = _parseDate(_s(m['match_date']));
      return !d.isBefore(first) && d.isBefore(next);
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (filter == CmrMatchesFilter.upcoming) {
      list = list.where((m) => !_parseDate(_s(m['match_date'])).isBefore(today));
    } else if (filter == CmrMatchesFilter.past) {
      list = list.where((m) => _parseDate(_s(m['match_date'])).isBefore(today));
    }

    if (q.isNotEmpty) {
      list = list.where((m) {
        final text = '${_s(m['opponent'])} ${_s(m['match_date'])} ${_s(m['event_type'])} ${_s(m['competition_name'])} ${_s(m['stadium'])}'.toLowerCase();
        return text.contains(q);
      });
    }

    final out = list.toList();
    out.sort((a, b) => _parseDate(_s(a['match_date'])).compareTo(_parseDate(_s(b['match_date']))));
    return out;
  }

  List<Map<String, dynamic>> _monthMatches() {
    final first = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    return matches.where((m) {
      final d = _parseDate(_s(m['match_date']));
      return !d.isBefore(first) && d.isBefore(next);
    }).toList();
  }

  Map<DateTime, List<Map<String, dynamic>>> _monthMap() {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final m in _monthMatches()) {
      final d = _parseDate(_s(m['match_date']));
      final key = DateTime(d.year, d.month, d.day);
      (map[key] ??= []).add(m);
    }
    return map;
  }

  int _wins(Iterable<Map<String, dynamic>> list) => list.where((m) => _i(m['our_score']) > _i(m['opponent_score'])).length;
  int _draws(Iterable<Map<String, dynamic>> list) => list.where((m) => _i(m['our_score']) == _i(m['opponent_score'])).length;
  int _losses(Iterable<Map<String, dynamic>> list) => list.where((m) => _i(m['our_score']) < _i(m['opponent_score'])).length;

  void _prevMonth() {
    setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1));
  }

  void _nextMonth() {
    setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1));
  }

  void _thisMonth() {
    final now = DateTime.now();
    setState(() => selectedMonth = DateTime(now.year, now.month, 1));
  }


  List<Map<String, dynamic>> _pastMatchesAll() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final list = matches.where((m) {
      final d = _parseDate(_s(m['match_date']));
      return d.isBefore(today);
    }).toList();

    list.sort((a, b) => _parseDate(_s(b['match_date'])).compareTo(_parseDate(_s(a['match_date']))));
    return list;
  }

  List<DateTime> _archiveMonths(List<Map<String, dynamic>> archive) {
    final seen = <String>{};
    final out = <DateTime>[];

    for (final m in archive) {
      final d = _parseDate(_s(m['match_date']));
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      if (seen.add(key)) {
        out.add(DateTime(d.year, d.month, 1));
      }
    }

    out.sort((a, b) => b.compareTo(a));
    return out;
  }

  void _openArchiveSheet() {
    final archive = _pastMatchesAll();

    setState(() {
      filter = CmrMatchesFilter.past;
    });

    if (archive.isEmpty) {
      Get.snackbar('Архив матчей', 'Прошедших матчей пока нет');
      return;
    }

    final months = _archiveMonths(archive);
    DateTime activeMonth = months.firstWhere(
      (m) => m.year == selectedMonth.year && m.month == selectedMonth.month,
      orElse: () => months.first,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final activeList = archive.where((m) {
              final d = _parseDate(_s(m['match_date']));
              return d.year == activeMonth.year && d.month == activeMonth.month;
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.55,
              maxChildSize: 0.96,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 28,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: _C.border),
                                ),
                                child: const Icon(Icons.history_rounded, color: _C.text, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Архив матчей',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _C.title.copyWith(fontSize: 20),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${archive.length} прошедших • ${_monthTitle(activeMonth)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _C.muted,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 46,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: months.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, index) {
                              final m = months[index];
                              final active = m.year == activeMonth.year && m.month == activeMonth.month;
                              final count = archive.where((x) {
                                final d = _parseDate(_s(x['match_date']));
                                return d.year == m.year && d.month == m.month;
                              }).length;

                              return _ArchiveMonthChip(
                                title: _monthTitle(m),
                                count: count,
                                active: active,
                                onTap: () {
                                  setSheetState(() => activeMonth = m);
                                  setState(() => selectedMonth = m);
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ArchiveMiniStat(
                                  title: 'Матчи',
                                  value: '${activeList.length}',
                                  icon: Icons.sports_soccer_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ArchiveMiniStat(
                                  title: 'Победы',
                                  value: '${_wins(activeList)}',
                                  icon: Icons.emoji_events_outlined,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ArchiveMiniStat(
                                  title: 'Баланс',
                                  value: '${_wins(activeList)}-${_draws(activeList)}-${_losses(activeList)}',
                                  icon: Icons.timeline_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: activeList.isEmpty
                              ? const _MiniEmpty(text: 'В этом месяце архивных матчей нет')
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                                  itemCount: activeList.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                                  itemBuilder: (_, index) {
                                    final m = activeList[index];
                                    return _CmrMatchTile(
                                      eventType: _eventTypeLabel(_s(m['event_type'])),
                                      opponent: _s(m['opponent']),
                                      date: _dateRu(_parseDate(_s(m['match_date']))),
                                      competition: _s(m['competition_name']),
                                      stadium: _s(m['stadium']),
                                      score: '${_i(m['our_score'])}:${_i(m['opponent_score'])}',
                                      upcoming: false,
                                      canEdit: canEdit,
                                      compact: true,
                                      onTap: () {
                                        Navigator.pop(context);
                                        setState(() {
                                          selectedMonth = activeMonth;
                                          filter = CmrMatchesFilter.past;
                                        });
                                        _openDetails(m);
                                      },
                                      onDelete: () => _deleteMatch(m),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _monthTitle(DateTime d) {
    const months = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: _C.green));
    if (error != null) {
      return _CmrEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Не удалось загрузить матчи',
        text: error!,
        actionText: 'Повторить',
        onAction: () => _fetch(initial: true),
      );
    }

    final visible = _visibleMatches();
    final monthList = _monthMatches();
    final map = _monthMap();

    return LayoutBuilder(
      builder: (context, c) {
        final isPhone = c.maxWidth < 600;
        final compact = c.maxWidth < 860;
        final left = _buildLeftColumn(visible, monthList, isPhone: isPhone);
        final right = _buildCalendarArea(map, monthList, isPhone: isPhone);

        if (compact) {
          return RefreshIndicator(
            color: _C.green,
            onRefresh: () => _fetch(),
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: isPhone ? 328 : 360, child: left),
                const SizedBox(height: 12),
                SizedBox(height: isPhone ? 560 : 640, child: right),
              ],
            ),
          );
        }

        return Row(
          children: [
            SizedBox(width: 390, child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildLeftColumn(
    List<Map<String, dynamic>> visible,
    List<Map<String, dynamic>> monthList, {
    bool isPhone = false,
  }) {
    final upcomingCount = matches.where((m) => _isUpcoming(_parseDate(_s(m['match_date'])))).length;

    return Container(
      decoration: _C.cardDecoration,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(isPhone ? 14 : 18, isPhone ? 14 : 18, isPhone ? 14 : 18, isPhone ? 12 : 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(bottom: BorderSide(color: _C.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CmrIconBox(icon: Icons.sports_soccer_rounded, size: isPhone ? 40 : 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.teamName.trim().isEmpty ? 'Команда' : widget.teamName,
                            maxLines: isPhone ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: _C.title.copyWith(fontSize: isPhone ? 16.5 : 19, height: 1.12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Матчи и календарь команды',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _C.muted, fontWeight: FontWeight.w700, fontSize: isPhone ? 11.5 : 12),
                          ),
                        ],
                      ),
                    ),
                    if (!isPhone) _HeaderIconButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
                  ],
                ),
                SizedBox(height: isPhone ? 12 : 16),
                Row(
                  children: [
                    Expanded(child: _HeroStat(value: '${matches.length}', title: 'всего', compact: isPhone)),
                    const SizedBox(width: 8),
                    Expanded(child: _HeroStat(value: '$upcomingCount', title: 'впереди', compact: isPhone)),
                    const SizedBox(width: 8),
                    Expanded(child: _HeroStat(value: canEdit ? 'Да' : 'Нет', title: 'редакт.', compact: isPhone)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isPhone ? 12 : 14, isPhone ? 12 : 14, isPhone ? 12 : 14, 10),
            child: _CmrSearch(
              controller: _searchCtrl,
              hint: isPhone ? 'Поиск матча' : 'Поиск по сопернику, турниру, стадиону',
              compact: isPhone,
              onClear: () {
                _searchCtrl.clear();
                setState(() {});
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isPhone ? 12 : 14, 0, isPhone ? 12 : 14, 10),
            child: Row(
              children: [
                Expanded(child: _FilterButton(text: 'Все', active: filter == CmrMatchesFilter.all, compact: isPhone, onTap: () => setState(() => filter = CmrMatchesFilter.all))),
                const SizedBox(width: 8),
                Expanded(child: _FilterButton(text: 'Впереди', active: filter == CmrMatchesFilter.upcoming, compact: isPhone, onTap: () => setState(() => filter = CmrMatchesFilter.upcoming))),
                const SizedBox(width: 8),
                Expanded(child: _FilterButton(text: 'Архив', active: filter == CmrMatchesFilter.past, compact: isPhone, onTap: _openArchiveSheet)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isPhone ? 12 : 14, 0, isPhone ? 12 : 14, 10),
            child: _SelectedMatchesHeader(
              title: _monthTitle(selectedMonth),
              canEdit: canEdit,
              compact: isPhone,
              onAdd: _openCreate,
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const _MiniEmpty(text: 'Матчей по выбранным условиям нет')
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(isPhone ? 12 : 14, 0, isPhone ? 12 : 14, 14),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => SizedBox(height: isPhone ? 8 : 10),
                    itemBuilder: (_, i) {
                      final m = visible[i];
                      return _CmrMatchTile(
                        eventType: _eventTypeLabel(_s(m['event_type'])),
                        opponent: _s(m['opponent']),
                        date: _dateRu(_parseDate(_s(m['match_date']))),
                        competition: _s(m['competition_name']),
                        stadium: _s(m['stadium']),
                        score: '${_i(m['our_score'])}:${_i(m['opponent_score'])}',
                        upcoming: _isUpcoming(_parseDate(_s(m['match_date']))),
                        canEdit: canEdit,
                        compact: isPhone,
                        onTap: () => _openDetails(m),
                        onDelete: () => _deleteMatch(m),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarArea(
    Map<DateTime, List<Map<String, dynamic>>> monthMap,
    List<Map<String, dynamic>> monthList, {
    bool isPhone = false,
  }) {
    return Container(
      decoration: _C.cardDecoration,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isPhone ? 14 : 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: isPhone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CmrIconBox(icon: Icons.event_available_rounded, size: 40),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_monthTitle(selectedMonth), maxLines: 2, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: 18, height: 1.12)),
                                const SizedBox(height: 4),
                                Text('П ${_wins(monthList)} • Н ${_draws(monthList)} • Пор ${_losses(monthList)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontWeight: FontWeight.w700, fontSize: 11.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _TopActionButton(icon: Icons.today_rounded, text: 'Текущий месяц', compact: true, onTap: _thisMonth)),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_left_rounded, compact: true, onTap: _prevMonth),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_right_rounded, compact: true, onTap: _nextMonth),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const _CmrIconBox(icon: Icons.event_available_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_monthTitle(selectedMonth), maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text('Победы ${_wins(monthList)} • Ничьи ${_draws(monthList)} • Поражения ${_losses(monthList)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      _TopActionButton(icon: Icons.today_rounded, text: 'Этот месяц', onTap: _thisMonth),
                      const SizedBox(width: 8),
                      _SquareButton(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
                      const SizedBox(width: 8),
                      _SquareButton(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
                    ],
                  ),
          ),
          const Divider(height: 1, color: _C.border),
          Padding(
            padding: EdgeInsets.all(isPhone ? 12 : 14),
            child: _buildStatsRow(monthList, isPhone: isPhone),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(isPhone ? 10 : 14, 0, isPhone ? 10 : 14, isPhone ? 10 : 14),
              child: _MonthMatchesGrid(
                month: selectedMonth,
                matchesByDay: monthMap,
                dateText: _dateRu,
                compact: isPhone,
                onDayTap: (day, list) {
                  if (list.isEmpty) return;
                  _showDayMatches(day, list);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<Map<String, dynamic>> monthList, {bool isPhone = false}) {
    final goalsFor = monthList.fold<int>(0, (v, m) => v + _i(m['our_score']));
    final goalsAgainst = monthList.fold<int>(0, (v, m) => v + _i(m['opponent_score']));
    final cards = [
      _MetricCard(icon: Icons.sports_soccer_rounded, title: 'Матчи', value: '${monthList.length}', compact: isPhone),
      _MetricCard(icon: Icons.trending_up_rounded, title: 'Голы', value: '$goalsFor:$goalsAgainst', compact: isPhone),
      _MetricCard(icon: Icons.emoji_events_outlined, title: 'Победы', value: '${_wins(monthList)}', compact: isPhone),
      _MetricCard(icon: Icons.timeline_rounded, title: 'Баланс', value: '${_wins(monthList)}-${_draws(monthList)}-${_losses(monthList)}', compact: isPhone),
    ];

    if (isPhone) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.65,
        children: cards,
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 10),
        Expanded(child: cards[1]),
        const SizedBox(width: 10),
        Expanded(child: cards[2]),
        const SizedBox(width: 10),
        Expanded(child: cards[3]),
      ],
    );
  }

  void _showDayMatches(DateTime day, List<Map<String, dynamic>> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 30, offset: Offset(0, 12))]),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _CmrIconBox(icon: Icons.sports_soccer_rounded),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Матчи • ${_dateRu(day)}', style: _C.title.copyWith(fontSize: 18))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              ...list.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CmrMatchTile(
                      eventType: _eventTypeLabel(_s(m['event_type'])),
                      opponent: _s(m['opponent']),
                      date: _dateRu(_parseDate(_s(m['match_date']))),
                      competition: _s(m['competition_name']),
                      stadium: _s(m['stadium']),
                      score: '${_i(m['our_score'])}:${_i(m['opponent_score'])}',
                      upcoming: _isUpcoming(_parseDate(_s(m['match_date']))),
                      canEdit: canEdit,
                      onTap: () {
                        Navigator.pop(context);
                        _openDetails(m);
                      },
                      onDelete: () => _deleteMatch(m),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthMatchesGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, List<Map<String, dynamic>>> matchesByDay;
  final String Function(DateTime) dateText;
  final void Function(DateTime day, List<Map<String, dynamic>> matches) onDayTap;
  final bool compact;

  const _MonthMatchesGrid({
    required this.month,
    required this.matchesByDay,
    required this.dateText,
    required this.onDayTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    final total = offset + daysInMonth;
    final cells = ((total / 7).ceil()) * 7;

    return Column(
      children: [
        Row(
          children: weekdays
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        color: _C.muted,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 10.5 : 12,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(height: compact ? 6 : 8),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: compact ? 5 : 8,
              crossAxisSpacing: compact ? 5 : 8,
              childAspectRatio: compact ? .82 : 1.05,
            ),
            itemCount: cells,
            itemBuilder: (_, index) {
              final dayNumber = index - offset + 1;
              final inMonth = dayNumber >= 1 && dayNumber <= daysInMonth;
              if (!inMonth) return const SizedBox.shrink();

              final day = DateTime(month.year, month.month, dayNumber);
              final list = matchesByDay[day] ?? const <Map<String, dynamic>>[];
              final today = DateTime.now();
              final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
              final hasMatches = list.isNotEmpty;

              return InkWell(
                borderRadius: BorderRadius.circular(compact ? 13 : 18),
                onTap: () => onDayTap(day, list),
                child: Container(
                  padding: EdgeInsets.all(compact ? 6 : 9),
                  decoration: BoxDecoration(
                    color: hasMatches ? _C.accentSoft : Colors.white,
                    borderRadius: BorderRadius.circular(compact ? 13 : 18),
                    border: Border.all(
                      color: isToday ? _C.green : (hasMatches ? _C.accentBorder : _C.border),
                      width: isToday ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isToday ? _C.green : _C.text,
                              fontSize: compact ? 11.5 : 13,
                            ),
                          ),
                          const Spacer(),
                          if (hasMatches)
                            Container(
                              width: compact ? 18 : null,
                              height: compact ? 18 : null,
                              alignment: Alignment.center,
                              padding: compact ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _C.green,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${list.length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: compact ? 9 : 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      if (hasMatches && compact)
                        Wrap(
                          spacing: 3,
                          runSpacing: 3,
                          children: List.generate(
                            list.length.clamp(1, 3).toInt(),
                            (_) => Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: _C.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        )
                      else if (hasMatches)
                        ...list.take(2).map(
                              (m) => Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(
                                  children: [
                                    const Icon(Icons.sports_soccer_rounded, size: 11, color: _C.green),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        (m['opponent'] ?? 'Соперник').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10.5,
                                          color: _C.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CmrAddMatchSheet extends StatefulWidget {
  final Future<bool> Function({
    required String eventType,
    required String opponent,
    required String ourScore,
    required String opponentScore,
    required String matchDate,
    required String competitionName,
    required String tourLabel,
    required String stadium,
    required String referees,
    required String notes,
  }) onSubmit;

  const _CmrAddMatchSheet({required this.onSubmit});

  @override
  State<_CmrAddMatchSheet> createState() => _CmrAddMatchSheetState();
}

class _CmrAddMatchSheetState extends State<_CmrAddMatchSheet> {
  final opponent = TextEditingController();
  final ourScore = TextEditingController(text: '0');
  final opponentScore = TextEditingController(text: '0');
  final competition = TextEditingController();
  final tour = TextEditingController();
  final stadium = TextEditingController();
  final referees = TextEditingController();
  final notes = TextEditingController();

  DateTime? picked;
  bool saving = false;
  String eventType = 'championship';

  @override
  void dispose() {
    opponent.dispose();
    ourScore.dispose();
    opponentScore.dispose();
    competition.dispose();
    tour.dispose();
    stadium.dispose();
    referees.dispose();
    notes.dispose();
    super.dispose();
  }

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _ru(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(context: context, initialDate: picked ?? now, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 3, 12, 31), helpText: 'Выберите дату матча');
    if (res != null) setState(() => picked = DateTime(res.year, res.month, res.day));
  }

  Future<void> _submit() async {
    if (opponent.text.trim().isEmpty || picked == null) {
      Get.snackbar('Ошибка', 'Заполните соперника и дату матча');
      return;
    }
    setState(() => saving = true);
    try {
      final ok = await widget.onSubmit(
        eventType: eventType,
        opponent: opponent.text,
        ourScore: ourScore.text,
        opponentScore: opponentScore.text,
        matchDate: _iso(picked!),
        competitionName: competition.text,
        tourLabel: tour.text,
        stadium: stadium.text,
        referees: referees.text,
        notes: notes.text,
      );
      if (ok && mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          margin: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 720),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 30, offset: Offset(0, 12))]),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const _CmrIconBox(icon: Icons.add_rounded),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Добавить матч', style: _C.title.copyWith(fontSize: 19))),
                    IconButton(onPressed: saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                _CmrFieldShell(
                  child: DropdownButtonFormField<String>(
                    value: eventType,
                    decoration: const InputDecoration(border: InputBorder.none, labelText: 'Тип матча'),
                    items: const [
                      DropdownMenuItem(value: 'championship', child: Text('Чемпионат')),
                      DropdownMenuItem(value: 'friendly', child: Text('Товарищеский')),
                      DropdownMenuItem(value: 'tournament', child: Text('Турнир')),
                    ],
                    onChanged: saving ? null : (v) => setState(() => eventType = v ?? 'championship'),
                  ),
                ),
                const SizedBox(height: 10),
                _CmrTextField(controller: opponent, icon: Icons.shield_outlined, hint: 'Соперник', onChanged: (_) => setState(() {})),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _CmrTextField(controller: ourScore, icon: Icons.looks_one_rounded, hint: 'Наш счёт', keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _CmrTextField(controller: opponentScore, icon: Icons.looks_two_rounded, hint: 'Счёт соперника', keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                _CmrFieldShell(onTap: saving ? null : _pickDate, child: Row(children: [
                  const Icon(Icons.calendar_month_rounded, size: 20, color: _C.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(picked == null ? 'Выбрать дату матча' : _ru(picked!), style: TextStyle(fontWeight: FontWeight.w900, color: picked == null ? _C.muted : _C.text))),
                  const Icon(Icons.chevron_right_rounded, color: _C.muted),
                ])),
                const SizedBox(height: 10),
                _CmrTextField(controller: competition, icon: Icons.emoji_events_outlined, hint: 'Турнир / соревнование'),
                const SizedBox(height: 10),
                _CmrTextField(controller: tour, icon: Icons.format_list_numbered_rounded, hint: 'Тур / этап'),
                const SizedBox(height: 10),
                _CmrTextField(controller: stadium, icon: Icons.location_on_outlined, hint: 'Стадион'),
                const SizedBox(height: 10),
                _CmrTextField(controller: referees, icon: Icons.gavel_rounded, hint: 'Судьи'),
                const SizedBox(height: 10),
                _CmrTextField(controller: notes, icon: Icons.notes_rounded, hint: 'Примечания', maxLines: 3),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: !saving && opponent.text.trim().isNotEmpty && picked != null ? _submit : null,
                    icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                    label: Text(saving ? 'Сохранение...' : 'Сохранить матч'),
                    style: ElevatedButton.styleFrom(backgroundColor: _C.green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CmrMatchTile extends StatelessWidget {
  final String eventType;
  final String opponent;
  final String date;
  final String competition;
  final String stadium;
  final String score;
  final bool upcoming;
  final bool canEdit;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CmrMatchTile({
    required this.eventType,
    required this.opponent,
    required this.date,
    required this.competition,
    required this.stadium,
    required this.score,
    required this.upcoming,
    required this.canEdit,
    required this.onTap,
    required this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [competition, stadium].where((e) => e.trim().isNotEmpty).join(' • ');
    final radius = BorderRadius.circular(compact ? 18 : 22);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            color: upcoming ? _C.accentSoft : Colors.white,
            borderRadius: radius,
            border: Border.all(color: upcoming ? _C.green.withOpacity(.30) : _C.border, width: upcoming ? 1.2 : 1),
            boxShadow: upcoming
                ? const [BoxShadow(color: Color(0x1200A750), blurRadius: 16, offset: Offset(0, 8))]
                : const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 6))],
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 44 : 52,
                height: compact ? 44 : 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(compact ? 15 : 17),
                  border: Border.all(color: upcoming ? _C.accentBorder : _C.border),
                ),
                child: Icon(
                  upcoming ? Icons.sports_soccer_rounded : Icons.history_rounded,
                  color: upcoming ? _C.green : _C.muted,
                  size: compact ? 20 : 23,
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            opponent.isEmpty ? 'Соперник' : opponent,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w900, color: _C.text, fontSize: compact ? 13.8 : 15, height: 1.12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 5 : 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: upcoming ? _C.accentBorder : _C.border),
                          ),
                          child: Text(score, style: TextStyle(fontWeight: FontWeight.w900, color: _C.green, fontSize: compact ? 13 : 14.5)),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 6 : 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _MiniBadge(text: eventType, icon: Icons.flag_rounded, active: upcoming, compact: compact),
                        _MiniBadge(text: date, icon: Icons.calendar_month_rounded, active: upcoming, compact: compact),
                      ],
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _C.muted, fontWeight: FontWeight.w700, fontSize: compact ? 11.2 : 12, height: 1.15),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              if (canEdit)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, color: _C.muted),
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Удалить'))],
                )
              else
                const Icon(Icons.chevron_right_rounded, color: _C.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool active;
  final bool compact;

  const _MiniBadge({required this.text, required this.icon, required this.active, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 8, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? _C.accentBorder : _C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 13, color: active ? _C.green : _C.muted),
          const SizedBox(width: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: active ? _C.green : _C.muted, fontWeight: FontWeight.w900, fontSize: compact ? 10.2 : 10.8),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool compact;

  const _MetricCard({required this.icon, required this.title, required this.value, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 9 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _C.green, size: compact ? 17 : 20),
          SizedBox(width: compact ? 7 : 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: _C.text, fontSize: compact ? 14 : 16)),
                const SizedBox(height: 1),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: _C.muted, fontSize: compact ? 10.5 : 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedMatchesHeader extends StatelessWidget {
  final String title;
  final bool canEdit;
  final bool compact;
  final VoidCallback onAdd;

  const _SelectedMatchesHeader({required this.title, required this.canEdit, required this.onAdd, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: compact ? 14 : 15))),
        if (canEdit) _TopActionButton(icon: Icons.add_rounded, text: compact ? 'Добавить' : 'Матч', compact: compact, onTap: onAdd),
      ],
    );
  }
}

class _CmrSearch extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onClear;
  final bool compact;

  const _CmrSearch({required this.controller, required this.hint, required this.onClear, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return _CmrFieldShell(
      compact: compact,
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: compact ? 19 : 22, color: _C.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: compact ? 13 : 14),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(color: _C.muted, fontSize: compact ? 12.5 : 14),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (controller.text.isNotEmpty) IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.close_rounded, size: 20), onPressed: onClear),
        ],
      ),
    );
  }
}

class _CmrTextField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  const _CmrTextField({required this.controller, required this.icon, required this.hint, this.keyboardType, this.maxLines = 1, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _CmrFieldShell(child: Row(crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
      Padding(padding: EdgeInsets.only(top: maxLines > 1 ? 10 : 0), child: Icon(icon, size: 20, color: _C.muted)),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: controller, keyboardType: keyboardType, maxLines: maxLines, onChanged: onChanged, decoration: InputDecoration(hintText: hint, border: InputBorder.none, isDense: true, hintStyle: const TextStyle(color: _C.muted)))),
    ]));
  }
}

class _CmrFieldShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool compact;

  const _CmrFieldShell({required this.child, this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 6 : 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: _C.border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(compact ? 14 : 16), onTap: onTap, child: box),
    );
  }
}


class _ArchiveMonthChip extends StatelessWidget {
  final String title;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _ArchiveMonthChip({
    required this.title,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? _C.accentSoft : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? _C.green : _C.border, width: active ? 1.2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: active ? _C.green : _C.text,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: active ? Colors.white.withOpacity(.12) : _C.border),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: active ? _C.green : _C.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveMiniStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ArchiveMiniStat({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _C.text, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  final bool compact;

  const _FilterButton({required this.text, required this.active, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
      onTap: onTap,
      child: Container(
        height: compact ? 36 : 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _C.accentSoft : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          border: Border.all(color: active ? _C.green : _C.border, width: active ? 1.2 : 1),
        ),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _C.green : _C.text, fontWeight: FontWeight.w900, fontSize: compact ? 11.2 : 12)),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool compact;

  const _TopActionButton({required this.icon, required this.text, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
      onTap: onTap,
      child: Container(
        height: compact ? 38 : 42,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
        decoration: BoxDecoration(
          color: _C.accentSoft,
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          border: Border.all(color: _C.accentBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 16 : 18, color: _C.green),
            const SizedBox(width: 6),
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _C.green, fontWeight: FontWeight.w900, fontSize: compact ? 11.2 : 12))),
          ],
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const _SquareButton({required this.icon, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 38.0 : 42.0;
    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 14 : 15),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(compact ? 14 : 15), border: Border.all(color: _C.border)),
        child: Icon(icon, color: _C.text, size: compact ? 20 : 24),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _C.accentSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.accentBorder),
        ),
        child: Icon(icon, color: _C.green, size: 21),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String title;
  final bool compact;

  const _HeroStat({required this.value, required this.title, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 10, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: _C.accentSoft,
        borderRadius: BorderRadius.circular(compact ? 15 : 18),
        border: Border.all(color: _C.accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _C.green, fontWeight: FontWeight.w900, fontSize: compact ? 14.5 : 17)),
          const SizedBox(height: 1),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _C.muted, fontWeight: FontWeight.w700, fontSize: compact ? 10 : 11)),
        ],
      ),
    );
  }
}

class _CmrIconBox extends StatelessWidget {
  final IconData icon;
  final bool dark;
  final double size;

  const _CmrIconBox({required this.icon, this.dark = false, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(.12) : _C.accentSoft,
        borderRadius: BorderRadius.circular(size * .35),
        border: Border.all(color: dark ? Colors.white.withOpacity(.12) : _C.accentBorder),
      ),
      child: Icon(icon, color: dark ? Colors.white : _C.green, size: size * .48),
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  final String text;
  const _MiniEmpty({required this.text});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _C.muted, fontWeight: FontWeight.w700))));
}

class _CmrEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String actionText;
  final VoidCallback onAction;
  const _CmrEmptyState({required this.icon, required this.title, required this.text, required this.actionText, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(22),
        decoration: _C.cardDecoration,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _C.green, size: 42),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: _C.title.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _C.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _TopActionButton(icon: Icons.refresh_rounded, text: actionText, onTap: onAction),
        ]),
      ),
    );
  }
}

class _C {
  static const Color bg = Color(0xFFF3F5F8);
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE5E7EB);

  // Спокойнее, чем яркий салатовый: зелёный остаётся акцентом, но не перегружает мобильный экран.
  static const Color green = Color(0xFF1F7A4D);
  static const Color darkGreen = Color(0xFF10251C);
  static const Color accentSoft = Color(0xFFF2F7F4);
  static const Color accentBorder = Color(0xFFD7E8DE);
  static const Color red = Color(0xFFEF4444);

  static const TextStyle title = TextStyle(color: text, fontWeight: FontWeight.w900, letterSpacing: -.2);
  static const TextStyle darkTitle = TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -.2);

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 22, offset: Offset(0, 10))],
      );
}
