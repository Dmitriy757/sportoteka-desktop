import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PlayerTrainingCalendarPlayer {
  const PlayerTrainingCalendarPlayer({
    required this.id,
    required this.name,
    this.number,
    this.position,
    this.avatar,
  });

  final int id;
  final String name;
  final String? number;
  final String? position;
  final String? avatar;
}

enum PlayerTrainingCalendarMode { team, personal, all }

class PlayerTrainingCalendarPanel extends StatefulWidget {
  const PlayerTrainingCalendarPanel({
    super.key,
    required this.teamId,
    required this.players,
    this.initialPlayerId,
    this.ownerUserId,
    this.initialDate,
    this.allowAllPlayers = false,
    this.initialMode = PlayerTrainingCalendarMode.personal,
    this.showHeader = true,
    this.showPlayerPicker = true,
    this.showModeControls = true,
    this.compactInAnalytics = false,
    this.splitWideLayout = false,
    this.cleanPersonalStyle = false,
    this.onSessionTap,
    this.onClose,
    this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker',
  });

  final int teamId;
  final List<PlayerTrainingCalendarPlayer> players;
  final int? initialPlayerId;
  /// Required by the player's personal cabinet so personal archive requests
  /// are scoped to the authenticated owner as well as player_id.
  final int? ownerUserId;
  final DateTime? initialDate;
  final bool allowAllPlayers;
  final PlayerTrainingCalendarMode initialMode;
  final bool showHeader;
  final bool showPlayerPicker;
  final bool showModeControls;
  final bool compactInAnalytics;
  /// Wide coach layout: calendar on the left, sessions for the selected day on the right.
  final bool splitWideLayout;
  /// Borderless personal-training visual language used by the coach personal section.
  final bool cleanPersonalStyle;
  final ValueChanged<Map<String, dynamic>>? onSessionTap;
  final VoidCallback? onClose;
  final String apiBaseUrl;

  @override
  State<PlayerTrainingCalendarPanel> createState() => _PlayerTrainingCalendarPanelState();
}

class _PlayerTrainingCalendarPanelState extends State<PlayerTrainingCalendarPanel> {
  static const _green = Color(0xFF12B85A);
  static const _greenSoft = Color(0xFFEEF9F2);
  static const _text = Color(0xFF171B18);
  static const _muted = Color(0xFF66716A);
  static const _line = Color(0xFFE6EAE7);
  static const _soft = Color(0xFFF7F9F8);

  int? _selectedPlayerId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  late PlayerTrainingCalendarMode _mode;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _sessions = const [];
  String _analyticsPickerMode = 'calendar';

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    final initialDate = widget.initialDate;
    if (initialDate != null) {
      _month = DateTime(initialDate.year, initialDate.month);
      _selectedDay = DateTime(initialDate.year, initialDate.month, initialDate.day);
    }
    _selectedPlayerId = _resolveInitialPlayerId();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlayerTrainingCalendarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    var needsLoad = false;
    if (oldWidget.initialMode != widget.initialMode) {
      _mode = widget.initialMode;
      needsLoad = true;
    }
    if (oldWidget.initialDate != widget.initialDate && widget.initialDate != null) {
      final d = widget.initialDate!;
      _month = DateTime(d.year, d.month);
      _selectedDay = DateTime(d.year, d.month, d.day);
      needsLoad = true;
    }
    if (oldWidget.teamId != widget.teamId || oldWidget.ownerUserId != widget.ownerUserId || oldWidget.players.length != widget.players.length || oldWidget.initialPlayerId != widget.initialPlayerId || oldWidget.allowAllPlayers != widget.allowAllPlayers) {
      final next = _selectedPlayerId != null && widget.players.any((p) => p.id == _selectedPlayerId)
          ? _selectedPlayerId
          : _resolveInitialPlayerId();
      if (next != _selectedPlayerId || oldWidget.teamId != widget.teamId || oldWidget.ownerUserId != widget.ownerUserId) {
        _selectedPlayerId = next;
        needsLoad = true;
      }
    }
    if (needsLoad) _load();
  }

  int? _resolveInitialPlayerId() {
    final initial = widget.initialPlayerId;
    if (initial != null && initial > 0 && widget.players.any((p) => p.id == initial)) return initial;
    if (widget.allowAllPlayers) return null;
    if (widget.players.isNotEmpty) return widget.players.first.id;
    return null;
  }

  PlayerTrainingCalendarPlayer? get _selectedPlayer {
    final id = _selectedPlayerId;
    if (id == null) return null;
    for (final p in widget.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _load() async {
    if (!mounted || widget.teamId <= 0) return;
    if (!widget.allowAllPlayers && (_selectedPlayerId == null || _selectedPlayerId! <= 0)) return;
    setState(() { _loading = true; _error = null; });
    try {
      final start = DateTime(_month.year, _month.month, 1);
      final end = DateTime(_month.year, _month.month + 1, 0);
      final endpoint = _mode == PlayerTrainingCalendarMode.personal ? 'player_get_sessions.php' : 'get_tracker_sessions.php';
      final query = <String, String>{
        'team_id': '${widget.teamId}',
        'date_from': _dateKey(start),
        'date_to': _dateKey(end),
        'limit': '300',
      };
      final selectedId = _selectedPlayerId;
      if (selectedId != null && selectedId > 0) query['player_id'] = '$selectedId';
      if (_mode == PlayerTrainingCalendarMode.personal) {
        final ownerUserId = widget.ownerUserId;
        if (ownerUserId != null && ownerUserId > 0) {
          query['owner_user_id'] = '$ownerUserId';
        }
        query['session_kind'] = 'personal';
        query['personal_session'] = '1';
        query['include_personal'] = '1';
      } else if (_mode == PlayerTrainingCalendarMode.all) {
        query['session_kind'] = 'all';
        query['include_personal'] = '1';
        query['include_player_sessions'] = '1';
      } else {
        query['session_kind'] = 'team';
        query['exclude_personal'] = '1';
      }
      final uri = Uri.parse('${widget.apiBaseUrl}/$endpoint').replace(queryParameters: query);
      final res = await http.get(uri).timeout(const Duration(seconds: 18));
      final data = _decode(res.body);
      final raw = data['sessions'] as List? ?? data['items'] as List? ?? const [];
      var rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
      if (_mode == PlayerTrainingCalendarMode.team) {
        rows = rows.where((s) => !_isPersonalSession(s)).toList(growable: false);
      } else if (_mode == PlayerTrainingCalendarMode.personal) {
        rows = rows.where(_isPersonalSession).map((s) => <String, dynamic>{...s, 'session_kind': s['session_kind'] ?? 'personal'}).toList(growable: false);
      }
      rows.sort((a, b) => _sessionDate(b).compareTo(_sessionDate(a)));
      if (!mounted) return;
      setState(() { _sessions = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Map<String, dynamic> _decode(String body) {
    final text = body.trim();
    if (text.isEmpty) throw Exception('Сервер вернул пустой ответ');
    final start = text.indexOf('{');
    if (start < 0) throw Exception('Сервер вернул не JSON');
    final decoded = jsonDecode(text.substring(start));
    if (decoded is! Map) throw Exception('Некорректный JSON от сервера');
    final map = Map<String, dynamic>.from(decoded);
    if (map['success'] == false || map['status'] == 'error') {
      final message = '${map['message'] ?? 'Ошибка API'}';
      final error = '${map['error'] ?? ''}'.trim();
      throw Exception(error.isEmpty ? message : '$message: $error');
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final player = _selectedPlayer;
    final days = _sessionsByDay();
    final selectedKey = _dateKey(_selectedDay);
    final selectedSessions = days[selectedKey] ?? const <Map<String, dynamic>>[];

    if (widget.cleanPersonalStyle && widget.splitWideLayout) {
      return _analyticsReplicaWorkspace(
        player: player,
        days: days,
        selectedSessions: selectedSessions,
      );
    }

    return Container(
      padding: EdgeInsets.all(widget.cleanPersonalStyle ? 6 : (widget.compactInAnalytics ? 8 : 10)),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader) ...[
            _header(player),
            const SizedBox(height: 6),
          ],
          if (widget.players.isEmpty && !widget.allowAllPlayers)
            _empty('В этой команде пока нет списка игроков для календаря.')
          else ...[
            if (widget.showPlayerPicker || widget.showModeControls) ...[
              _controls(),
              const SizedBox(height: 6),
            ] else ...[
              _compactMonthControls(),
              const SizedBox(height: 6),
            ],
            if (_loading) const LinearProgressIndicator(color: _green, minHeight: 2),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: _errorBox(_error!)),
            const SizedBox(height: 6),
            Expanded(
              child: _calendarWorkspace(days, selectedSessions),
            ),
          ],
        ],
      ),
    );
  }


  Widget _analyticsReplicaWorkspace({
    required PlayerTrainingCalendarPlayer? player,
    required Map<String, List<Map<String, dynamic>>> days,
    required List<Map<String, dynamic>> selectedSessions,
  }) {
    final summary = player == null
        ? 'Команда · Личные · весь день'
        : '${player.name} · Личные · весь день';

    Widget modeButton({
      required String key,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool forceActive = false,
    }) {
      final active = forceActive || _analyticsPickerMode == key;
      return InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? _greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: active ? _green : _muted),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: active ? _green : _text,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.05,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFFAFBFA),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 54,
              padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _line)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.tune_rounded, color: _green, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Выбор тренировок',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _text,
                            fontSize: 13.4,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            letterSpacing: -.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11.1,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loading) ...[
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                    ),
                    const SizedBox(width: 10),
                  ],
                  InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: widget.onClose,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.close_rounded, color: _muted, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFBFA),
                border: Border(bottom: BorderSide(color: _line)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    modeButton(
                      key: 'calendar',
                      icon: Icons.calendar_month_rounded,
                      label: 'Дата и тренировки',
                      onTap: () => setState(() => _analyticsPickerMode = 'calendar'),
                    ),
                    const SizedBox(width: 8),
                    modeButton(
                      key: 'players',
                      icon: Icons.groups_rounded,
                      label: _selectedPlayerId == null ? 'Игроки' : 'Игроки · 1',
                      onTap: () => setState(() => _analyticsPickerMode = 'players'),
                    ),
                    const SizedBox(width: 8),
                    modeButton(
                      key: 'personal',
                      icon: Icons.layers_rounded,
                      label: 'Личные',
                      forceActive: false,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 0),
                child: _errorBox(_error!),
              ),
            Expanded(
              child: _analyticsPickerMode == 'players'
                  ? _analyticsPlayersPane(days)
                  : _analyticsCalendarSplit(days, selectedSessions),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analyticsPlayersPane(Map<String, List<Map<String, dynamic>>> days) {
    final selectedDayRows = days[_dateKey(_selectedDay)] ?? const <Map<String, dynamic>>[];
    final visiblePlayers = widget.players.where((p) {
      if (!widget.allowAllPlayers) return true;
      return selectedDayRows.any((s) => _sessionMatchesPlayer(s, p));
    }).toList(growable: false);

    Widget playerCard(PlayerTrainingCalendarPlayer? p) {
      final all = p == null;
      final active = all ? _selectedPlayerId == null : _selectedPlayerId == p.id;
      final count = all
          ? selectedDayRows.length
          : selectedDayRows.where((s) => _sessionMatchesPlayer(s, p!)).length;
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _selectedPlayerId = all ? null : p!.id);
          _load();
        },
        child: Container(
          width: 196,
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: active ? _greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              if (all)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups_rounded, color: _green, size: 20),
                )
              else
                _avatar(p!, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      all ? 'Вся команда' : p!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 11.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count сесс.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? _green : _muted,
                        fontSize: 9.7,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFFAFBFA),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (widget.allowAllPlayers) playerCard(null),
            for (final p in visiblePlayers) playerCard(p),
          ],
        ),
      ),
    );
  }

  bool _sessionMatchesPlayer(
      Map<String, dynamic> session, PlayerTrainingCalendarPlayer player) {
    final id = _intAny(session, const [
      'player_id',
      'playerId',
      'user_id',
      'userId',
      'athlete_id',
    ]);
    if (id > 0 && id == player.id) return true;
    final name = _playerNameForSession(session).toLowerCase().trim();
    final target = _compactPlayerName(player.name).toLowerCase().trim();
    return name.isNotEmpty && target.isNotEmpty && name == target;
  }

  Widget _analyticsCalendarSplit(
    Map<String, List<Map<String, dynamic>>> days,
    List<Map<String, dynamic>> selectedSessions,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
            children: [
              SizedBox(height: 430, child: _analyticsCalendarWindow(days)),
              const SizedBox(height: 10),
              SizedBox(
                height: math.max(300.0, math.min(520.0, 230.0 + selectedSessions.length * 88.0)),
                child: _analyticsSelectedDayWindow(selectedSessions),
              ),
            ],
          );
        }

        final calendarWidth = math.min(560.0, math.max(430.0, constraints.maxWidth * .425));
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: calendarWidth, child: _analyticsCalendarWindow(days)),
              const SizedBox(width: 10),
              Expanded(child: _analyticsSelectedDayWindow(selectedSessions)),
            ],
          ),
        );
      },
    );
  }

  Widget _analyticsCalendarWindow(Map<String, List<Map<String, dynamic>>> days) {
    final count = days[_dateKey(_selectedDay)]?.length ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x07111827), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: _green, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _monthTitle(_month),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 15.2,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          letterSpacing: -.12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_shortDate(_selectedDay)} · $count тренировок',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                _analyticsSmallIcon(Icons.chevron_left_rounded,
                    () => _setMonth(DateTime(_month.year, _month.month - 1))),
                const SizedBox(width: 6),
                _analyticsSmallIcon(Icons.chevron_right_rounded,
                    () => _setMonth(DateTime(_month.year, _month.month + 1))),
                const SizedBox(width: 6),
                _analyticsSmallIcon(Icons.today_rounded, _goToday),
                const SizedBox(width: 6),
                _analyticsSmallIcon(Icons.refresh_rounded, _load),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: _analyticsMonthGrid(days),
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsSmallIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, size: 20, color: _text),
      ),
    );
  }

  void _goToday() {
    final now = DateTime.now();
    final newMonth = now.year != _month.year || now.month != _month.month;
    setState(() {
      _month = DateTime(now.year, now.month);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
    if (newMonth) _load();
  }

  Widget _analyticsMonthGrid(Map<String, List<Map<String, dynamic>>> days) {
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final rowsCount = ((leading + daysInMonth + 6) ~/ 7);
    final totalCells = rowsCount * 7;
    final gridStart = first.subtract(Duration(days: leading));

    return Column(
      children: [
        Row(
          children: [
            for (final d in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              const gap = 6.0;
              final cellW = (c.maxWidth - gap * 6) / 7;
              final cellH = (c.maxHeight - gap * (rowsCount - 1)) / rowsCount;
              return Column(
                children: [
                  for (var row = 0; row < rowsCount; row++) ...[
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++) ...[
                          SizedBox(
                            width: cellW,
                            height: cellH,
                            child: _analyticsDayCell(
                              gridStart.add(Duration(days: row * 7 + col)),
                              days,
                            ),
                          ),
                          if (col != 6) const SizedBox(width: gap),
                        ],
                      ],
                    ),
                    if (row != rowsCount - 1) const SizedBox(height: gap),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _analyticsDayCell(
    DateTime day,
    Map<String, List<Map<String, dynamic>>> days,
  ) {
    final key = _dateKey(day);
    final count = days[key]?.length ?? 0;
    final selected = key == _dateKey(_selectedDay);
    final inMonth = day.month == _month.month && day.year == _month.year;
    final today = key == _dateKey(DateTime.now());
    final bg = selected
        ? _greenSoft
        : count > 0
            ? Colors.white
            : (inMonth ? const Color(0xFFFAFBFA) : Colors.white);
    final color = selected
        ? const Color(0xFF067A46)
        : inMonth
            ? (today ? _green : _text)
            : _muted.withOpacity(.7);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        final moveMonth = day.month != _month.month || day.year != _month.year;
        setState(() {
          _selectedDay = DateTime(day.year, day.month, day.day);
          if (moveMonth) _month = DateTime(day.year, day.month);
        });
        if (moveMonth) _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: const Color(0xFFBCECD0), width: 1) : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: color,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 1.1),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            if (selected)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 5,
                child: Center(
                  child: SizedBox(
                    width: 6,
                    height: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: _green, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _analyticsSelectedDayWindow(List<Map<String, dynamic>> sessions) {
    final distance = sessions.fold<double>(0, (sum, s) =>
        sum + _doubleAny(s, const ['distance_m', 'total_distance_m']));
    final load = sessions.fold<double>(0, (sum, s) =>
        sum + _doubleAny(s, const ['load_score', 'training_load', 'load', 'load_value']));
    final playerIds = <int>{};
    final playerNames = <String>{};
    for (final s in sessions) {
      final id = _intAny(s, const ['player_id', 'playerId', 'user_id', 'userId', 'athlete_id']);
      if (id > 0) playerIds.add(id);
      final name = _playerNameForSession(s);
      if (name.isNotEmpty) playerNames.add(name);
    }
    final playersCount = playerIds.isNotEmpty ? playerIds.length : playerNames.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x07111827), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 62,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.view_list_rounded, color: _green, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Тренировки дня',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _text,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_shortDate(_selectedDay)} · ${sessions.length} тренировок · $playersCount записей игроков',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Row(
              children: [
                Expanded(child: _analyticsSummaryTile(Icons.route_rounded, 'Дист.', _distance(distance))),
                const SizedBox(width: 8),
                Expanded(child: _analyticsSummaryTile(Icons.group_rounded, 'Игроков', '$playersCount')),
                const SizedBox(width: 8),
                Expanded(child: _analyticsSummaryTile(Icons.local_fire_department_rounded, 'Нагрузка', load > 0 ? load.toStringAsFixed(0) : '0')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _green, strokeWidth: 2))
                : sessions.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            'На выбранный день завершённых личных тренировок нет',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _analyticsSessionCard(sessions[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsSummaryTile(IconData icon, String label, String value) {
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _muted),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 9.7,
                      fontWeight: FontWeight.w700,
                    )),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsSessionCard(Map<String, dynamic> s) {
    final date = _sessionDate(s);
    final rosterPlayer = _playerForSession(s);
    final player = _playerNameForSession(s);
    final distance = _doubleAny(s, const ['distance_m', 'total_distance_m']);
    final duration = _intAny(s, const ['duration_sec', 'duration']);
    final avgBpm = _doubleAny(s, const ['heart_rate_avg_bpm', 'avg_heart_rate_bpm', 'avg_bpm']);
    final maxSpeed = _doubleAny(s, const ['max_speed_kmh', 'speed_max_kmh']);
    final load = _doubleAny(s, const ['load_score', 'training_load', 'load', 'load_value']);
    final source = _sourceLabel(s);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: widget.onSessionTap == null ? null : () => widget.onSessionTap!(s),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            if (rosterPlayer != null)
              _avatar(rosterPlayer, size: 38)
            else
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded, color: _green, size: 19),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.isEmpty ? 'Личная тренировка' : player,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_time(date)} · ${_distance(distance)} · ${_duration(duration)} · $source',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 9.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (maxSpeed > 0) 'макс ${maxSpeed.toStringAsFixed(1)} км/ч',
                      if (avgBpm > 0) 'ЧСС ${avgBpm.toStringAsFixed(0)}',
                      if (load > 0) 'нагрузка ${load.toStringAsFixed(0)}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 9.1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime d) =>
      '${d.day} ${_monthName(d.month).substring(0, 3)}. ${d.year}';

  Widget _calendarWorkspace(
    Map<String, List<Map<String, dynamic>>> days,
    List<Map<String, dynamic>> selectedSessions,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = widget.splitWideLayout && constraints.maxWidth >= 720;
        if (!split) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.cleanPersonalStyle ? const Color(0xFFF8FAF9) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _calendar(days),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.cleanPersonalStyle ? const Color(0xFFF8FAF9) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _selectedDayHeader(selectedSessions),
                      const SizedBox(height: 5),
                      _summary(selectedSessions),
                      const SizedBox(height: 5),
                      Expanded(child: _sessionsList(selectedSessions)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final calendarWidth = math.min(
          530.0,
          math.max(390.0, constraints.maxWidth * .42),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: calendarWidth,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAF9),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 16, color: _green),
                        SizedBox(width: 7),
                        Text(
                          'Дата',
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _calendar(days),
                      ),
                    ),
                    const SizedBox(height: 7),
                    _summary(selectedSessions),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAF9),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _selectedDayHeader(selectedSessions),
                    const SizedBox(height: 7),
                    Expanded(child: _sessionsList(selectedSessions)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _selectedDayHeader(List<Map<String, dynamic>> sessions) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.event_note_rounded, color: _green, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Сессии · ${_selectedDay.day} ${_monthName(_selectedDay.month)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  sessions.isEmpty
                      ? 'На выбранную дату личных тренировок нет'
                      : '${sessions.length} ${sessions.length == 1 ? 'тренировка' : 'тренировки'} · нажмите для анализа',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w500,
                    fontSize: 9.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(PlayerTrainingCalendarPlayer? player) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.allowAllPlayers
                    ? 'Календарь тренировок'
                    : 'Календарь сессий игрока',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                player == null
                    ? (widget.allowAllPlayers ? 'все игроки' : 'выберите игрока')
                    : player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w500,
                  fontSize: 10.6,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 18, color: _muted),
        ),
      ],
    );
  }

  Widget _controls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (widget.showPlayerPicker) ...[
              Expanded(child: _playerPicker()),
              const SizedBox(width: 8),
            ] else
              Expanded(child: _monthTitleBox()),
            _monthButton(Icons.chevron_left_rounded, () => _setMonth(DateTime(_month.year, _month.month - 1))),
            const SizedBox(width: 4),
            _monthButton(Icons.chevron_right_rounded, () => _setMonth(DateTime(_month.year, _month.month + 1))),
          ],
        ),
        if (widget.showModeControls) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _modeChip(PlayerTrainingCalendarMode.team, 'Командные')),
              const SizedBox(width: 7),
              Expanded(child: _modeChip(PlayerTrainingCalendarMode.personal, 'Личные')),
              const SizedBox(width: 7),
              Expanded(child: _modeChip(PlayerTrainingCalendarMode.all, 'Все')),
            ],
          ),
        ],
      ],
    );
  }

  Widget _compactMonthControls() {
    return Row(
      children: [
        Expanded(child: _monthTitleBox()),
        const SizedBox(width: 8),
        _monthButton(Icons.chevron_left_rounded, () => _setMonth(DateTime(_month.year, _month.month - 1))),
        const SizedBox(width: 4),
        _monthButton(Icons.chevron_right_rounded, () => _setMonth(DateTime(_month.year, _month.month + 1))),
        const SizedBox(width: 4),
        _monthButton(Icons.refresh_rounded, _load),
      ],
    );
  }

  Widget _monthTitleBox() {
    final mode = _mode == PlayerTrainingCalendarMode.team
        ? 'Командные'
        : (_mode == PlayerTrainingCalendarMode.personal ? 'Личные' : 'Все');
    final player =
        _selectedPlayer?.name ?? (widget.allowAllPlayers ? 'все игроки' : 'игрок');
    return SizedBox(
      height: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _monthTitle(_month),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$mode · $player',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w500,
              fontSize: 9.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerPicker() {
    final player = _selectedPlayer;
    return PopupMenuButton<int>(
      tooltip: 'Выбрать игрока',
      onSelected: (id) {
        setState(() { _selectedPlayerId = id <= 0 ? null : id; });
        _load();
      },
      itemBuilder: (context) => <PopupMenuEntry<int>>[
        if (widget.allowAllPlayers)
          const PopupMenuItem<int>(
            value: 0,
            child: Row(
              children: [
                Icon(Icons.groups_rounded, color: _green, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Все игроки', maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ...widget.players.map((p) => PopupMenuItem<int>(
              value: p.id,
              child: Row(
                children: [
                  _avatar(p, size: 24),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if ((p.number ?? '').trim().isNotEmpty) Text('#${p.number}', style: const TextStyle(color: _muted, fontWeight: FontWeight.w800)),
                ],
              ),
            )),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: widget.cleanPersonalStyle ? _soft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: widget.cleanPersonalStyle
              ? null
              : const Border(bottom: BorderSide(color: _line, width: .8)),
        ),
        child: Row(
          children: [
            if (player != null) _avatar(player, size: 26) else Icon(widget.allowAllPlayers ? Icons.groups_rounded : Icons.person_search_rounded, color: _green, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(player?.name ?? (widget.allowAllPlayers ? 'Все игроки' : 'Выбрать игрока'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 12))),
            const Icon(Icons.expand_more_rounded, color: _muted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(PlayerTrainingCalendarMode mode, String label) {
    final active = _mode == mode;
    return InkWell(
      onTap: () {
        if (_mode == mode) return;
        setState(() => _mode = mode);
        _load();
      },
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? _green : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? _text : _muted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 10.8,
          ),
        ),
      ),
    );
  }

  Widget _monthButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 40,
        child: Icon(icon, color: _muted, size: 20),
      ),
    );
  }

  void _setMonth(DateTime next) {
    setState(() {
      _month = DateTime(next.year, next.month);
      _selectedDay = DateTime(next.year, next.month, 1);
    });
    _load();
  }

  Widget _calendar(Map<String, List<Map<String, dynamic>>> days) {
    final first = DateTime(_month.year, _month.month, 1);
    final last = DateTime(_month.year, _month.month + 1, 0);
    final startOffset = first.weekday - 1;
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(startOffset, null),
      ...List<DateTime?>.generate(last.day, (i) => DateTime(_month.year, _month.month, i + 1)),
    ];
    while (cells.length % 7 != 0) cells.add(null);

    return Container(
      padding: EdgeInsets.all(widget.compactInAnalytics ? 4 : 6),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(_monthTitle(_month), style: TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: widget.compactInAnalytics ? 12 : 13))),
              Text('${_sessions.length} сесс.', style: TextStyle(color: _muted, fontWeight: FontWeight.w800, fontSize: widget.compactInAnalytics ? 10 : 11)),
            ],
          ),
          SizedBox(height: widget.compactInAnalytics ? 5 : 8),
          Row(children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(color: _muted, fontWeight: FontWeight.w900, fontSize: widget.compactInAnalytics ? 8.8 : 10))))).toList()),
          SizedBox(height: widget.compactInAnalytics ? 4 : 6),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 560;
            final aspect = widget.compactInAnalytics
                ? (wide ? 4.6 : 2.7)
                : (wide ? 1.75 : 1.0);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: widget.compactInAnalytics ? 3 : 5, crossAxisSpacing: widget.compactInAnalytics ? 3 : 5, childAspectRatio: aspect),
              itemBuilder: (context, index) {
                final day = cells[index];
                if (day == null) return const SizedBox.shrink();
                final key = _dateKey(day);
                final count = days[key]?.length ?? 0;
                final selected = key == _dateKey(_selectedDay);
                final today = key == _dateKey(DateTime.now());
                return InkWell(
                  borderRadius: BorderRadius.circular(widget.compactInAnalytics ? 9 : 12),
                  onTap: () => setState(() { _selectedDay = day; }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? _greenSoft : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: selected
                              ? _green
                              : (today ? _green.withOpacity(.35) : Colors.transparent),
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('${day.day}', style: TextStyle(color: selected ? _green : _text, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: widget.compactInAnalytics ? 10 : 12)),
                        if (count > 0)
                          Positioned(
                            right: widget.compactInAnalytics ? 2 : 4,
                            bottom: widget.compactInAnalytics ? 2 : 3,
                            child: Container(
                              width: widget.compactInAnalytics ? 10 : 13,
                              height: widget.compactInAnalytics ? 10 : 13,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: selected ? Colors.white : _green, shape: BoxShape.circle),
                              child: Text('$count', style: TextStyle(color: selected ? _green : Colors.white, fontWeight: FontWeight.w900, fontSize: widget.compactInAnalytics ? 6 : 7)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _summary(List<Map<String, dynamic>> sessions) {
    final distance = sessions.fold<double>(0, (sum, s) => sum + _doubleAny(s, const ['distance_m', 'total_distance_m']));
    final duration = sessions.fold<int>(0, (sum, s) => sum + _intAny(s, const ['duration_sec', 'duration']));
    final maxSpeed = sessions.fold<double>(0, (max, s) => mathMax(max, _doubleAny(s, const ['max_speed_kmh', 'speed_max_kmh'])));
    return Row(
      children: [
        Expanded(child: _metric('Сессии', '${sessions.length}')),
        const SizedBox(width: 7),
        Expanded(child: _metric('Дистанция', distance > 999 ? '${(distance / 1000).toStringAsFixed(2)} км' : '${distance.toStringAsFixed(0)} м')),
        const SizedBox(width: 7),
        Expanded(child: _metric('Время', _duration(duration))),
        const SizedBox(width: 7),
        Expanded(child: _metric('Макс.', maxSpeed > 0 ? '${maxSpeed.toStringAsFixed(1)}' : '—')),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: widget.compactInAnalytics ? 4 : 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w700,
              fontSize: 11.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w500,
              fontSize: 8.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionsList(List<Map<String, dynamic>> sessions) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _green, strokeWidth: 2));
    if (sessions.isEmpty) return _empty(_emptyMessageForMode());
    return ListView.separated(
      itemCount: sessions.length,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: .6, color: widget.cleanPersonalStyle ? const Color(0xFFF0F3F1) : _line),
      itemBuilder: (context, index) => _sessionTile(sessions[index]),
    );
  }

  Widget _sessionTile(Map<String, dynamic> s) {
    final personal = _isPersonalSession(s);
    final title = '${s['title'] ?? (personal ? 'Личная тренировка' : 'Тренировка')}';
    final playerName = _playerNameForSession(s);
    final sourceLabel = _sourceLabel(s);
    final playerPrefix = playerName.isEmpty ? '' : '$playerName · ';
    final date = _sessionDate(s);
    final distance = _doubleAny(s, const ['distance_m', 'total_distance_m']);
    final duration = _intAny(s, const ['duration_sec', 'duration']);
    final avgBpm = _doubleAny(s, const ['heart_rate_avg_bpm', 'avg_heart_rate_bpm', 'avg_bpm']);
    final maxSpeed = _doubleAny(s, const ['max_speed_kmh', 'speed_max_kmh']);
    final distanceLabel = distance > 0 ? _distance(distance) : 'дистанция —';
    final durationLabel = duration > 0 ? _duration(duration) : 'время —';
    return InkWell(
      onTap: widget.onSessionTap == null ? null : () => widget.onSessionTap!(s),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: personal ? _green : _muted,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 12))),

              ]),
              const SizedBox(height: 3),
              Text('$playerPrefix${_time(date)} · $distanceLabel · $durationLabel', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 10)),
              const SizedBox(height: 4),
              Text(
                [
                  sourceLabel,
                  if (avgBpm > 0) 'ЧСС ${avgBpm.toStringAsFixed(0)}',
                  if (maxSpeed > 0) '${maxSpeed.toStringAsFixed(1)} км/ч',
                  if (_intAny(s, const ['points_count']) > 0)
                    '${_intAny(s, const ['points_count'])} точек',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w500,
                  fontSize: 8.9,
                ),
              ),
            ]),
          ),
        ],
        ),
      ),
    );
  }

  Widget _miniPill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(color: _muted, fontWeight: FontWeight.w800, fontSize: 9)),
      );

  String _emptyMessageForMode() {
    switch (_mode) {
      case PlayerTrainingCalendarMode.team:
        return 'В этот день командных сессий нет.';
      case PlayerTrainingCalendarMode.personal:
        return 'В этот день личных сессий нет.';
      case PlayerTrainingCalendarMode.all:
        return 'В этот день сессий нет.';
    }
  }

  bool _isPersonalSession(Map<String, dynamic> s) {
    final personalRaw = '${s['personal_session'] ?? s['is_personal'] ?? ''}'.toLowerCase().trim();
    final kind = '${s['session_kind'] ?? s['source'] ?? s['activity_source'] ?? ''}'.toLowerCase();
    return personalRaw == '1' || personalRaw == 'true' || kind.contains('personal') || kind.contains('player_tracker');
  }

  PlayerTrainingCalendarPlayer? _playerForSession(Map<String, dynamic> s) {
    final id = _intAny(s, const ['player_id', 'playerId', 'user_id', 'userId', 'athlete_id']);
    if (id > 0) {
      for (final p in widget.players) {
        if (p.id == id) return p;
      }
    }

    String direct = '';
    for (final key in const ['player_short_name', 'short_name', 'player_name', 'full_name', 'fullName', 'name', 'fio']) {
      final value = '${s[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') {
        direct = value;
        break;
      }
    }
    final technical = RegExp(
      r'^(?:Игрок|Player)\s*#?\s*(\d+)$',
      caseSensitive: false,
    ).firstMatch(direct);
    if (technical != null) {
      final technicalId = int.tryParse(technical.group(1) ?? '');
      if (technicalId != null) {
        for (final p in widget.players) {
          if (p.id == technicalId) return p;
        }
      }
    }

    // Старые личные сессии иногда приходят с user_id вместо player_id.
    // В таком случае связываем запись с составом по ФИО, чтобы вернуть фото.
    if (direct.isNotEmpty && technical == null) {
      final directKey = _nameMatchKey(direct);
      if (directKey.isNotEmpty) {
        for (final p in widget.players) {
          if (_nameMatchKey(p.name) == directKey) return p;
        }
      }
    }
    return null;
  }

  String _playerNameForSession(Map<String, dynamic> s) {
    final rosterPlayer = _playerForSession(s);
    if (rosterPlayer != null && rosterPlayer.name.trim().isNotEmpty) {
      // В списке тренировок показываем читаемо: «Фамилия Имя».
      return rosterPlayer.name.trim();
    }

    String direct = '';
    for (final key in const ['player_short_name', 'short_name', 'player_name', 'full_name', 'fullName', 'name', 'fio']) {
      final value = '${s[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') {
        direct = value;
        break;
      }
    }
    final technical = RegExp(
      r'^(?:Игрок|Player)\s*#?\s*\d+$',
      caseSensitive: false,
    ).hasMatch(direct);
    if (technical) return '';
    return _fullSurnameFirstName(direct, assumeFirstNameFirst: true);
  }

  String _nameMatchKey(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^а-яa-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
    return normalized.join('|');
  }

  String _fullSurnameFirstName(
    String value, {
    bool assumeFirstNameFirst = false,
  }) {
    final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) return value.trim();
    if (parts[1].endsWith('.') && parts[1].length <= 3) return value.trim();
    if (!assumeFirstNameFirst) return value.trim();
    final first = parts.first;
    final surname = parts.last;
    final middle = parts.length > 2 ? parts.sublist(1, parts.length - 1).join(' ') : '';
    return '$surname $first${middle.isEmpty ? '' : ' $middle'}';
  }

  String _compactPlayerName(
    String value, {
    bool assumeFirstNameFirst = false,
    bool alreadySurnameFirst = false,
  }) {
    final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;

    // Уже компактный формат «Фамилия И.» не меняем.
    if (parts[1].endsWith('.') && parts[1].length <= 3) {
      return '${parts.first} ${parts[1].substring(0, 1).toUpperCase()}.';
    }

    if (alreadySurnameFirst) {
      return '${parts.first} ${parts[1].substring(0, 1).toUpperCase()}.';
    }
    final surname = assumeFirstNameFirst ? parts.last : parts.first;
    final firstName = assumeFirstNameFirst ? parts.first : parts[1];
    return '$surname ${firstName.substring(0, 1).toUpperCase()}.';
  }

  String _sourceLabel(Map<String, dynamic> s) {
    final hr = _doubleAny(s, const ['heart_rate_avg_bpm', 'avg_heart_rate_bpm', 'avg_bpm']) > 0 || _intAny(s, const ['heart_rate_samples_count', 'hr_samples_count']) > 0;
    final gps = _intAny(s, const ['points_count', 'samples_count']) > 0 || _doubleAny(s, const ['distance_m', 'total_distance_m']) > 0;
    final source = '${s['source'] ?? s['device_name'] ?? s['activity_type'] ?? ''}'.toLowerCase();
    final hasPolar = hr || source.contains('polar') || source.contains('heart');
    final hasGps = gps || source.contains('gps') || source.contains('tracker');
    if (hasPolar && hasGps) return 'Polar + GPS';
    if (hasPolar) return 'Polar';
    if (hasGps) return 'GPS';
    return 'данные';
  }

  Widget _empty(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      );

  Widget _errorBox(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFDC2626),
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      );

  Widget _avatar(PlayerTrainingCalendarPlayer p, {double size = 26}) {
    final avatar = (p.avatar ?? '').trim();
    if (avatar.isNotEmpty && (avatar.startsWith('http://') || avatar.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2.6),
        child: Image.network(avatar, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarFallback(p, size)),
      );
    }
    return _avatarFallback(p, size);
  }

  Widget _avatarFallback(PlayerTrainingCalendarPlayer p, double size) {
    final initials = p.name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2).map((e) => e.substring(0, 1).toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(size / 2.6)),
      child: Text(initials.isEmpty ? 'И' : initials, style: TextStyle(color: _green, fontWeight: FontWeight.w900, fontSize: size * .34)),
    );
  }

  Map<String, List<Map<String, dynamic>>> _sessionsByDay() {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final session in _sessions) {
      final key = _dateKey(_sessionDate(session));
      out.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(session);
    }
    return out;
  }

  DateTime _sessionDate(Map<String, dynamic> s) {
    for (final key in const ['started_at', 'created_at', 'start_time', 'stopped_at', 'finished_at']) {
      final raw = '${s[key] ?? ''}'.trim();
      if (raw.isEmpty || raw == 'null') continue;
      final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) return parsed;
      if (raw.length >= 10) {
        final d = DateTime.tryParse(raw.substring(0, 10));
        if (d != null) return d;
      }
    }
    return DateTime(_month.year, _month.month, 1);
  }

  int _intAny(Map<String, dynamic> s, List<String> keys) {
    for (final key in keys) {
      final value = s[key];
      if (value == null) continue;
      if (value is num) return value.toInt();
      final parsed = int.tryParse('$value');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  double _doubleAny(Map<String, dynamic> s, List<String> keys) {
    for (final key in keys) {
      final value = s[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse('$value'.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
    return 0;
  }

  String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _monthTitle(DateTime d) => '${_monthName(d.month)} ${d.year}';
  String _monthName(int month) {
    final safeMonth = month < 1 ? 1 : (month > 12 ? 12 : month);
    return const ['январь','февраль','март','апрель','май','июнь','июль','август','сентябрь','октябрь','ноябрь','декабрь'][safeMonth - 1];
  }
  String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _duration(int sec) {
    if (sec <= 0) return '—';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '${h}ч ${m}м';
    return '${m}м';
  }
  String _distance(double meters) => meters >= 1000 ? '${(meters / 1000).toStringAsFixed(2)} км' : '${meters.toStringAsFixed(0)} м';
  double mathMax(double a, double b) => a >= b ? a : b;
}
