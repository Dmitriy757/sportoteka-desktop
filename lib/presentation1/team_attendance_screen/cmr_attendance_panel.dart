// lib/presentation/attendance/cmr_attendance_panel.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';

class CmrAttendancePanel extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;
  final String teamLogoUrl;
  final bool fullScreen;

  const CmrAttendancePanel({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
    this.teamLogoUrl = '',
    this.fullScreen = false,
  });

  @override
  State<CmrAttendancePanel> createState() => _CmrAttendancePanelState();
}

class _CmrAttendancePanelState extends State<CmrAttendancePanel> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String playersUrl = '$apiBase/get_players_by_team.php';
  static const String getTeamEventsUrl = '$apiBase/get_team_events.php';
  static const String getAttendanceUrl = '$apiBase/get_team_attendance.php';
  static const String setAttendanceUrl = '$apiBase/set_team_attendance.php';
  static const String getTeamProfileUrl = '$apiBase/get_team_profile.php';

  static const String kStatusUnset = 'unset';

  static const double _leftWidth = 238;
  static const double _cellWidth = 58;
  static const double _headerHeight = 48;
  static const double _rowHeight = 60;

  bool loading = true;
  bool saving = false;
  String? error;
  String? teamLogoUrl;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int? selectedEventId;
  String selectedEventTitle = 'Все мероприятия';

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> players = [];
  final Map<int, Map<String, Map<String, dynamic>>> attendanceByEvent = {};

  final TextEditingController searchC = TextEditingController();
  String filter = 'all';

  Map<String, int> stats = const {
    'unset': 0,
    'present': 0,
    'absent': 0,
    'late': 0,
    'injured': 0,
    'individual': 0,
    'dayoff': 0,
    'total': 0,
  };

  @override
  void initState() {
    super.initState();
    teamLogoUrl = _cacheBust(_normalizeTeamLogo(widget.teamLogoUrl));
    searchC.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  dynamic _decode(String body) {
    final clear = body.trim();
    final obj = clear.indexOf('{');
    final arr = clear.indexOf('[');
    final starts = [obj, arr].where((e) => e >= 0).toList();
    if (starts.isEmpty) return {};
    final start = starts.reduce((a, b) => a < b ? a : b);
    return jsonDecode(clear.substring(start));
  }


  String? _normalizeTeamLogo(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty || value == 'null') return null;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('sportotekaapp.ru/')) return 'https://$value';
    if (value.startsWith('www.sportotekaapp.ru/')) return 'https://$value';
    if (value.startsWith('/')) return 'https://sportotekaapp.ru$value';
    if (value.startsWith('uploads/')) return 'https://sportotekaapp.ru/$value';
    return 'https://sportotekaapp.ru/$value';
  }

  String? _cacheBust(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _loadTeamProfileSilent() async {
    try {
      final res = await http
          .post(
            Uri.parse(getTeamProfileUrl),
            body: {'team_id': widget.teamId.toString()},
          )
          .timeout(const Duration(seconds: 10));

      final data = _decode(res.body);
      if (data is! Map) return;

      final ok = data['success'] == true || data['status'] == 'success';
      final team = data['team'];
      if (!ok || team is! Map) return;

      final rawLogo = team['logo'] ?? team['logo_url'] ?? team['photo'] ?? team['image'];
      final logo = _cacheBust(_normalizeTeamLogo(rawLogo));
      if (logo == null || logo.trim().isEmpty) return;

      teamLogoUrl = logo;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  int _daysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 1)
        .subtract(const Duration(days: 1))
        .day;
  }

  String _monthTitle() {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];
    return '${months[selectedMonth.month - 1]} ${selectedMonth.year}';
  }

  String _eventTitle(Map<String, dynamic> e) {
    final title = '${e['title'] ?? ''}'.trim();
    final name = '${e['name'] ?? ''}'.trim();
    return title.isNotEmpty ? title : (name.isNotEmpty ? name : 'Мероприятие');
  }

  String _prettyDate(String iso) {
    if (iso.length < 10) return iso;
    return '${iso.substring(8, 10)}.${iso.substring(5, 7)}';
  }

  String _prettyTime(Map<String, dynamic> e) {
    final value = '${e['start_at'] ?? e['event_date'] ?? ''}'.trim();
    if (value.length >= 16) return value.substring(11, 16);
    return '';
  }

  String _eventDateLabel(Map<String, dynamic> e) {
    final iso = '${e['start_at'] ?? e['event_date'] ?? ''}';
    final date = _prettyDate(iso);
    final time = _prettyTime(e);
    return time.isEmpty ? date : '$date\n$time';
  }

  String _playerName(Map<String, dynamic> p) {
    final full = '${p['fullName'] ?? p['full_name'] ?? ''}'.trim();
    if (full.isNotEmpty && full != 'null') return full;
    final first = '${p['first_name'] ?? ''}'.trim();
    final last = '${p['last_name'] ?? ''}'.trim();
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Игрок' : name;
  }

  String _playerSub(Map<String, dynamic> p) {
    final parts = <String>[];
    final number = '${p['number'] ?? p['player_number'] ?? ''}'.trim();
    final pos = '${p['position'] ?? ''}'.trim();
    if (number.isNotEmpty && number != 'null') parts.add('№$number');
    if (pos.isNotEmpty && pos != 'null') parts.add(pos);
    return parts.isEmpty ? 'Игрок команды' : parts.join(' · ');
  }

  String? _photo(Map<String, dynamic> p) {
    final raw = '${p['photo'] ?? p['photo_url'] ?? p['avatar'] ?? ''}'.trim();
    if (raw.isEmpty || raw == 'null') return null;
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/uploads/$raw';
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
      events = [];
      players = [];
      attendanceByEvent.clear();
      selectedEventId = null;
      selectedEventTitle = 'Все мероприятия';
    });

    try {
      await Future.wait([_loadTeamProfileSilent(), _fetchPlayers(), _fetchEventsForMonth()]);
      await _fetchAttendanceForEvents();
      _calculateStats();
    } catch (e) {
      if (mounted) error = '$e';
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _fetchPlayers() async {
    final uri = Uri.parse(playersUrl).replace(queryParameters: {
      'team_id': widget.teamId.toString(),
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 16));
    final data = _decode(res.body);
    if (data is! Map) throw Exception('Некорректный ответ игроков');
    if (data['status'] != 'success' && data['success'] != true) {
      throw Exception('${data['message'] ?? 'Не удалось загрузить игроков'}');
    }
    final raw = (data['players'] as List?) ?? (data['data'] as List?) ?? const [];
    players = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    players.sort((a, b) => _playerName(a).toLowerCase().compareTo(_playerName(b).toLowerCase()));
  }

  Future<void> _fetchEventsForMonth() async {
    final from = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-01';
    final to = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-${_daysInMonth(selectedMonth).toString().padLeft(2, '0')}';
    final uri = Uri.parse(getTeamEventsUrl).replace(queryParameters: {
      'team_id': widget.teamId.toString(),
      'from': from,
      'to': to,
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 16));
    final data = _decode(res.body);
    if (data is! Map) throw Exception('Некорректный ответ мероприятий');
    if (data['success'] != true && data['status'] != 'success') {
      throw Exception('${data['message'] ?? 'Не удалось загрузить мероприятия'}');
    }
    final raw = (data['items'] as List?) ?? (data['events'] as List?) ?? (data['data'] as List?) ?? const [];
    events = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    events.sort((a, b) => '${a['start_at'] ?? a['event_date'] ?? ''}'.compareTo('${b['start_at'] ?? b['event_date'] ?? ''}'));
  }

  Future<void> _fetchAttendanceForEvents() async {
    if (events.isEmpty) return;
    const batchSize = 5;
    for (int i = 0; i < events.length; i += batchSize) {
      final batch = events.skip(i).take(batchSize).toList();
      await Future.wait(batch.map((event) async {
        final eventId = _asInt(event['id']);
        if (eventId <= 0) return;
        try {
          final uri = Uri.parse(getAttendanceUrl).replace(queryParameters: {
            'event_id': eventId.toString(),
          });
          final res = await http.get(uri).timeout(const Duration(seconds: 12));
          final data = _decode(res.body);
          if (data is Map && data['success'] == true) {
            final items = (data['items'] as Map?) ?? const {};
            attendanceByEvent[eventId] = items.map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from((v as Map?) ?? const {})));
          }
        } catch (_) {}
      }));
    }
  }

  Future<void> _reloadAttendanceForEvent(int eventId) async {
    try {
      final uri = Uri.parse(getAttendanceUrl).replace(queryParameters: {'event_id': '$eventId'});
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      final data = _decode(res.body);
      if (data is Map && data['success'] == true) {
        final items = (data['items'] as Map?) ?? const {};
        if (!mounted) return;
        setState(() {
          attendanceByEvent[eventId] = items.map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from((v as Map?) ?? const {})));
        });
      }
    } catch (_) {}
  }

  String _getStatusForEvent(int playerId, int eventId) {
    final row = attendanceByEvent[eventId]?[playerId.toString()];
    final status = '${row?['status'] ?? ''}'.trim();
    return status.isEmpty || status == 'null' ? kStatusUnset : status;
  }

  String _getAggregatedStatus(int playerId) {
    bool hasAny = false;
    bool hasPresent = false;
    bool hasLate = false;
    bool hasInjured = false;
    bool hasIndividual = false;
    bool hasDayOff = false;
    for (final event in events) {
      final eventId = _asInt(event['id']);
      final s = _getStatusForEvent(playerId, eventId);
      if (s == kStatusUnset) continue;
      hasAny = true;
      if (s == 'absent') return 'absent';
      if (s == 'late') hasLate = true;
      if (s == 'injured') hasInjured = true;
      if (s == 'individual') hasIndividual = true;
      if (s == 'dayoff') hasDayOff = true;
      if (s == 'present') hasPresent = true;
    }
    if (!hasAny) return kStatusUnset;
    if (hasLate) return 'late';
    if (hasInjured) return 'injured';
    if (hasIndividual) return 'individual';
    if (hasDayOff) return 'dayoff';
    if (hasPresent) return 'present';
    return kStatusUnset;
  }

  String _symbol(String status) {
    switch (status) {
      case 'present': return 'П';
      case 'absent': return 'Н';
      case 'late': return 'Б';
      case 'injured': return 'Т';
      case 'individual': return 'И';
      case 'dayoff': return 'В';
      default: return '';
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'present': return 'Присутствует';
      case 'absent': return 'Отсутствует';
      case 'late': return 'Болен';
      case 'injured': return 'Травма';
      case 'individual': return 'Индивидуально';
      case 'dayoff': return 'Выходной';
      default: return 'Не отмечено';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present': return const Color(0xFF22C55E);
      case 'absent': return const Color(0xFFEF4444);
      case 'late': return const Color(0xFFF59E0B);
      case 'injured': return const Color(0xFF8B5CF6);
      case 'individual': return const Color(0xFF0EA5E9);
      case 'dayoff': return const Color(0xFF94A3B8);
      default: return const Color(0xFFCBD5E1);
    }
  }

  void _calculateStats() {
    final next = {
      'unset': 0,
      'present': 0,
      'absent': 0,
      'late': 0,
      'injured': 0,
      'individual': 0,
      'dayoff': 0,
      'total': players.length,
    };
    for (final p in players) {
      final id = _asInt(p['id']);
      final status = selectedEventId == null ? _getAggregatedStatus(id) : _getStatusForEvent(id, selectedEventId!);
      next[status] = (next[status] ?? 0) + 1;
    }
    if (mounted) setState(() => stats = next);
  }

  List<Map<String, dynamic>> get _filteredPlayers {
    final query = searchC.text.trim().toLowerCase();
    return players.where((p) {
      final id = _asInt(p['id']);
      final status = selectedEventId == null ? _getAggregatedStatus(id) : _getStatusForEvent(id, selectedEventId!);
      if (filter != 'all' && status != filter) return false;
      if (query.isEmpty) return true;
      return _playerName(p).toLowerCase().contains(query) || _playerSub(p).toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _setStatusForEvent(int eventId, int playerId, String status) async {
    final markedBy = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;
    setState(() => saving = true);

    attendanceByEvent.putIfAbsent(eventId, () => {});
    setState(() {
      if (status == kStatusUnset) {
        attendanceByEvent[eventId]!.remove(playerId.toString());
      } else {
        attendanceByEvent[eventId]![playerId.toString()] = {'status': status, 'note': ''};
      }
    });

    try {
      final res = await http.post(Uri.parse(setAttendanceUrl), body: {
        'team_id': widget.teamId.toString(),
        'event_id': eventId.toString(),
        'player_id': playerId.toString(),
        'status': status == kStatusUnset ? '' : status,
        'note': '',
        'marked_by': markedBy.toString(),
      }).timeout(const Duration(seconds: 14));
      final data = _decode(res.body);
      if (data is Map && data['success'] != true) {
        Get.snackbar('Ошибка', '${data['message'] ?? 'Не удалось сохранить отметку'}');
      }
      await _reloadAttendanceForEvent(eventId);
      _calculateStats();
    } catch (_) {
      Get.snackbar('Ошибка сети', 'Не удалось сохранить посещаемость');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _showStatusSelector(int eventId, int playerId, String currentStatus) async {
    final items = [
      [kStatusUnset, 'Очистить', '—'],
      ['present', 'Присутствует', 'П'],
      ['absent', 'Отсутствует', 'Н'],
      ['late', 'Болен', 'Б'],
      ['injured', 'Травма', 'Т'],
      ['individual', 'Индивидуально', 'И'],
      ['dayoff', 'Выходной', 'В'],
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        final width = MediaQuery.of(sheetContext).size.width;
        final crossAxisCount = width < 420 ? 2 : 3;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: width < 420 ? .78 : .64,
          minChildSize: .42,
          maxChildSize: .92,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _C.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Отметка посещаемости',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.text),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Выберите статус игрока для выбранной тренировки или мероприятия.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _C.muted, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: width < 420 ? 1.72 : 1.55,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final code = items[index][0];
                      final label = items[index][1];
                      final symbol = items[index][2];
                      final color = _statusColor(code);
                      final active = code == currentStatus;
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _setStatusForEvent(eventId, playerId, code);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: active ? color.withOpacity(.12) : _C.soft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              _StatusCircle(status: code, symbol: symbol, size: 34),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, height: 1.15, fontWeight: FontWeight.w900, color: active ? color : _C.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openFullScreenJournal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CmrAttendancePanel(
          teamId: widget.teamId,
          teamName: widget.teamName,
          clubId: widget.clubId,
          clubName: widget.clubName,
          teamLogoUrl: teamLogoUrl ?? widget.teamLogoUrl,
          fullScreen: true,
        ),
      ),
    );
  }


  void _changeMonth(int delta) {
    setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + delta, 1));
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _LoadingPanel(
        teamName: widget.teamName,
        teamLogoUrl: teamLogoUrl ?? widget.teamLogoUrl,
      );
    }
    if (error != null) return _ErrorPanel(text: error!, onRetry: _loadAll);

    final content = Container(
      color: widget.fullScreen ? Colors.white : _C.bg,
      padding: EdgeInsets.all(widget.fullScreen ? 10 : 14),
      child: Column(
        children: [
          _toolbar(),
          const SizedBox(height: 8),
          _compactControlStrip(),
          const SizedBox(height: 8),
          Expanded(child: _journalTable()),
        ],
      ),
    );

    if (!widget.fullScreen) return content;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _C.text,
        titleSpacing: 0,
        title: Text(
          'Журнал посещаемости · ${widget.teamName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
      body: content,
    );
  }


  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _C.cardCompact,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final compact = constraints.maxWidth < 760;
          final title = Row(
            children: [
              _TeamLogoMark(
                logoUrl: teamLogoUrl ?? widget.teamLogoUrl,
                teamName: widget.teamName,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: _C.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.clubName} · ${_monthTitle()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.muted),
                    ),
                  ],
                ),
              ),
            ],
          );

          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _MonthButton(icon: Icons.chevron_left_rounded, onTap: () => _changeMonth(-1), compact: true),
              Container(
                constraints: const BoxConstraints(minWidth: 118),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(12)),
                child: Text(_monthTitle(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: _C.text, fontSize: 11.5)),
              ),
              _MonthButton(icon: Icons.chevron_right_rounded, onTap: () => _changeMonth(1), compact: true),
              _GhostButton(icon: Icons.refresh_rounded, text: 'Обновить', onTap: _loadAll, compact: true),
              if (!widget.fullScreen)
                _AccentButton(icon: Icons.open_in_full_rounded, text: 'На весь экран', onTap: _openFullScreenJournal, compact: true),
              if (saving)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _C.green)),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 8), controls],
            );
          }

          return Row(children: [Expanded(child: title), const SizedBox(width: 12), controls]);
        },
      ),
    );
  }


  Widget _compactControlStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _C.cardCompact,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final compact = constraints.maxWidth < 880;
          final legend = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TinyStat(title: 'Игроки', value: '${stats['total'] ?? 0}', color: _C.green),
                const SizedBox(width: 6),
                _TinyStat(title: 'П', value: '${stats['present'] ?? 0}', color: const Color(0xFF22C55E)),
                const SizedBox(width: 6),
                _TinyStat(title: 'Нет', value: '${stats['absent'] ?? 0}', color: const Color(0xFFEF4444)),
                const SizedBox(width: 6),
                _TinyStat(title: 'Болен', value: '${stats['late'] ?? 0}', color: const Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                _TinyStat(title: 'Травма', value: '${stats['injured'] ?? 0}', color: const Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                _TinyStat(title: 'Инд.', value: '${stats['individual'] ?? 0}', color: const Color(0xFF0EA5E9)),
                const SizedBox(width: 6),
                _TinyStat(title: 'Вых.', value: '${stats['dayoff'] ?? 0}', color: const Color(0xFF94A3B8)),
              ],
            ),
          );

          final search = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: compact ? math.min(constraints.maxWidth - 54.0, 280.0) : 280,
                height: 38,
                child: TextField(
                  controller: searchC,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Поиск игрока',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: _C.soft,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _filterMenu(),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [legend, const SizedBox(height: 8), search],
            );
          }

          return Row(
            children: [
              Expanded(child: legend),
              const SizedBox(width: 10),
              search,
            ],
          );
        },
      ),
    );
  }


  Widget _filterMenu() {
    return PopupMenuButton<String>(
      initialValue: filter,
      tooltip: 'Фильтр',
      onSelected: (v) => setState(() => filter = v),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'all', child: Text('Все игроки')),
        PopupMenuItem(value: 'present', child: Text('Присутствуют')),
        PopupMenuItem(value: 'absent', child: Text('Отсутствуют')),
        PopupMenuItem(value: 'late', child: Text('Болеют')),
        PopupMenuItem(value: 'injured', child: Text('Травмы')),
        PopupMenuItem(value: 'unset', child: Text('Не отмечено')),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(12)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.tune_rounded, size: 17, color: _C.green), SizedBox(width: 6), Text('Фильтр', style: TextStyle(fontWeight: FontWeight.w900, color: _C.text, fontSize: 11.5))]),
      ),
    );
  }

  Widget _journalTable() {
    final filtered = _filteredPlayers;
    if (players.isEmpty) return const _EmptyPanel(text: 'В команде пока нет игроков');
    if (events.isEmpty) return const _EmptyPanel(text: 'В выбранном месяце нет тренировок или мероприятий');
    if (filtered.isEmpty) return const _EmptyPanel(text: 'По фильтру игроки не найдены');

    final tableWidth = _leftWidth + events.length * _cellWidth;

    return Container(
      decoration: _C.card,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: Column(
            children: [
              Row(
                children: [
                  _leftHeader(),
                  _rightHeader(),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, index) {
                    final player = filtered[index];
                    return Row(
                      children: [
                        _leftPlayerCell(player, index),
                        _rightStatusRow(player, index),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leftHeader() {
    return Container(
      width: _leftWidth,
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: _C.header),
      alignment: Alignment.centerLeft,
      child: Text('Игроки (${_filteredPlayers.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _C.text)),
    );
  }

  Widget _rightHeader() {
    return Container(
      width: events.length * _cellWidth,
      height: _headerHeight,
      decoration: const BoxDecoration(color: _C.header),
      child: Row(
        children: events.map((event) {
          return SizedBox(
            width: _cellWidth,
            child: Tooltip(
              message: _eventTitle(event),
              child: Center(
                child: Text(_eventDateLabel(event), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, height: 1.1, fontWeight: FontWeight.w900, color: _C.text)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _leftPlayerCell(Map<String, dynamic> player, int index) {
    final photo = _photo(player);
    return Container(
      width: _leftWidth,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : _C.soft.withOpacity(.42),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _C.softGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo != null
                ? Image.network(photo, fit: BoxFit.cover)
                : Icon(Icons.shield_outlined, color: _C.green, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_playerName(player), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.6, fontWeight: FontWeight.w900, color: _C.text)),
                const SizedBox(height: 3),
                Text(_playerSub(player), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.6, fontWeight: FontWeight.w700, color: _C.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rightStatusRow(Map<String, dynamic> player, int index) {
    final playerId = _asInt(player['id']);
    return Container(
      width: events.length * _cellWidth,
      height: _rowHeight,
      decoration: BoxDecoration(color: index.isEven ? Colors.white : _C.soft.withOpacity(.42)),
      child: Row(
        children: events.map((event) {
          final eventId = _asInt(event['id']);
          final status = _getStatusForEvent(playerId, eventId);
          return InkWell(
            onTap: () => _showStatusSelector(eventId, playerId, status),
            child: SizedBox(
              width: _cellWidth,
              child: Center(child: _StatusCircle(status: status, symbol: _symbol(status), size: 28)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _C {
  static const Color bg = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color header = Color(0xFFF3F7F5);
  static const Color soft = Color(0xFFF2F6F4);
  static const Color softGreen = Color(0xFFEAF7EF);
  static const Color green = Color(0xFF18864B);
  static const Color greenDark = Color(0xFF0F5F36);
  static const Color text = Color(0xFF17211B);
  static const Color muted = Color(0xFF66736C);
  static const Color border = Color(0xFFE5ECE8);

  static BoxDecoration get card => BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      );

  static BoxDecoration get cardCompact => BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      );
}


class _TeamLogoMark extends StatelessWidget {
  final String? logoUrl;
  final String teamName;
  final double size;

  const _TeamLogoMark({
    required this.logoUrl,
    required this.teamName,
    this.size = 36,
  });

  String? _normalizeImage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var url = raw.trim();
    if (url == 'null') return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('www.sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('/')) return 'https://sportotekaapp.ru$url';
    if (url.startsWith('uploads/')) return 'https://sportotekaapp.ru/$url';
    return 'https://sportotekaapp.ru/$url';
  }

  Widget _fallback(String letter) {
    return Container(
      color: _C.softGreen,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: _C.green,
          fontSize: size * .42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _normalizeImage(logoUrl);
    final cleanName = teamName.trim();
    final letter = cleanName.isNotEmpty ? cleanName.characters.first.toUpperCase() : 'К';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _C.softGreen,
        borderRadius: BorderRadius.circular(size * .33),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? _fallback(letter)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => _fallback(letter),
              errorWidget: (_, __, ___) => _fallback(letter),
            ),
    );
  }
}

class _StatusCircle extends StatelessWidget {
  final String status;
  final String symbol;
  final double size;

  const _StatusCircle({required this.status, required this.symbol, required this.size});

  Color get color {
    switch (status) {
      case 'present': return const Color(0xFF22C55E);
      case 'absent': return const Color(0xFFEF4444);
      case 'late': return const Color(0xFFF59E0B);
      case 'injured': return const Color(0xFF8B5CF6);
      case 'individual': return const Color(0xFF0EA5E9);
      case 'dayoff': return const Color(0xFF94A3B8);
      default: return const Color(0xFFCBD5E1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = status == _CmrAttendancePanelState.kStatusUnset;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: empty ? const Color(0xFFF1F5F9) : color.withOpacity(.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: empty ? null : Text(symbol, style: TextStyle(fontSize: size * .43, fontWeight: FontWeight.w900, color: color)),
    );
  }
}


class _TinyStat extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _TinyStat({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(color: color.withOpacity(.075), borderRadius: BorderRadius.circular(11)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 12.5)),
          const SizedBox(width: 4),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatPill({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14)),
          const SizedBox(width: 5),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String status;
  final String label;

  const _LegendItem({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusCircle(status: status, symbol: _symbolStatic(status), size: 18),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700, color: _C.muted)),
        ],
      ),
    );
  }

  static String _symbolStatic(String status) {
    switch (status) {
      case 'present': return 'П';
      case 'absent': return 'Н';
      case 'late': return 'Б';
      case 'injured': return 'Т';
      case 'individual': return 'И';
      case 'dayoff': return 'В';
      default: return '';
    }
  }
}

class _MonthButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const _MonthButton({required this.icon, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final side = compact ? 36.0 : 40.0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(width: side, height: side, decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _C.green, size: compact ? 20 : 24)),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool compact;

  const _GhostButton({required this.icon, required this.text, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: compact ? 36 : 40,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13),
        decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: _C.green, size: compact ? 16 : 18), const SizedBox(width: 6), Text(text, style: TextStyle(color: _C.text, fontWeight: FontWeight.w900, fontSize: compact ? 11.5 : 12.5))]),
      ),
    );
  }
}

class _AccentButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool compact;

  const _AccentButton({required this.icon, required this.text, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: compact ? 36 : 40,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13),
        decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: compact ? 16 : 18), const SizedBox(width: 6), Text(text, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: compact ? 11.5 : 12.5))]),
      ),
    );
  }
}

class _LoadingPanel extends StatefulWidget {
  final String teamName;
  final String teamLogoUrl;

  const _LoadingPanel({
    this.teamName = '',
    this.teamLogoUrl = '',
  });

  @override
  State<_LoadingPanel> createState() => _LoadingPanelState();
}

class _LoadingPanelState extends State<_LoadingPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bg,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: _C.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _controller,
                child: _TeamLogoMark(
                  logoUrl: widget.teamLogoUrl,
                  teamName: widget.teamName,
                  size: 78,
                ),
              ),
              const SizedBox(height: 14),
              const Text('Загружаем журнал посещаемости', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _C.text)),
              const SizedBox(height: 6),
              const Text('Подгружаем игроков, мероприятия и отметки', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.muted)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(minHeight: 5, color: _C.green, backgroundColor: _C.softGreen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ErrorPanel({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bg,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: _C.card,
          child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 42), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: _C.muted)), const SizedBox(height: 16), _AccentButton(icon: Icons.refresh_rounded, text: 'Повторить', onTap: onRetry)]),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String text;

  const _EmptyPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _C.card,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _C.softGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.groups_rounded, color: _C.green, size: 28),
                ),
                const SizedBox(height: 14), Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.text)), const SizedBox(height: 6), const Text('Проверьте выбранный месяц или состав команды', style: TextStyle(fontWeight: FontWeight.w700, color: _C.muted))]),
      ),
    );
  }
}
