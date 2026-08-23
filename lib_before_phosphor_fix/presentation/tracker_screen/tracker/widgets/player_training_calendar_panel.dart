import 'dart:convert';

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
    this.initialDate,
    this.allowAllPlayers = false,
    this.initialMode = PlayerTrainingCalendarMode.personal,
    this.showHeader = true,
    this.showPlayerPicker = true,
    this.showModeControls = true,
    this.compactInAnalytics = false,
    this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker',
  });

  final int teamId;
  final List<PlayerTrainingCalendarPlayer> players;
  final int? initialPlayerId;
  final DateTime? initialDate;
  final bool allowAllPlayers;
  final PlayerTrainingCalendarMode initialMode;
  final bool showHeader;
  final bool showPlayerPicker;
  final bool showModeControls;
  final bool compactInAnalytics;
  final String apiBaseUrl;

  @override
  State<PlayerTrainingCalendarPanel> createState() => _PlayerTrainingCalendarPanelState();
}

class _PlayerTrainingCalendarPanelState extends State<PlayerTrainingCalendarPanel> {
  static const _green = Color(0xFF00A750);
  static const _greenSoft = Color(0xFFEAFBF1);
  static const _text = Color(0xFF111512);
  static const _muted = Color(0xFF6B746E);
  static const _line = Color(0xFFE1E5E2);
  static const _soft = Color(0xFFF8F9F8);

  int? _selectedPlayerId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  late PlayerTrainingCalendarMode _mode;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _sessions = const [];

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
    if (oldWidget.teamId != widget.teamId || oldWidget.players.length != widget.players.length || oldWidget.initialPlayerId != widget.initialPlayerId || oldWidget.allowAllPlayers != widget.allowAllPlayers) {
      final next = _selectedPlayerId != null && widget.players.any((p) => p.id == _selectedPlayerId)
          ? _selectedPlayerId
          : _resolveInitialPlayerId();
      if (next != _selectedPlayerId || oldWidget.teamId != widget.teamId) {
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

    return Container(
      padding: EdgeInsets.all(widget.compactInAnalytics ? 8 : 10),
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
            _calendar(days),
            const SizedBox(height: 6),
            _summary(selectedSessions),
            const SizedBox(height: 6),
            Expanded(child: _sessionsList(selectedSessions)),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _line, width: .8),
          ),
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
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: .7, color: _line),
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
    return Padding(
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
    );
  }

  Widget _miniPill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(999), border: Border.all(color: _line)),
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

  String _playerNameForSession(Map<String, dynamic> s) {
    final id = _intAny(s, const ['player_id', 'playerId', 'user_id', 'userId', 'athlete_id']);
    PlayerTrainingCalendarPlayer? rosterPlayer;
    if (id > 0) {
      for (final p in widget.players) {
        if (p.id == id) { rosterPlayer = p; break; }
      }
    }

    String direct = '';
    for (final key in const ['player_short_name', 'short_name', 'player_name', 'full_name', 'fullName', 'name', 'fio']) {
      final value = '${s[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') { direct = value; break; }
    }
    final technical = RegExp(r'^(?:Игрок|Player)\s*#?\s*(\d+)$', caseSensitive: false).firstMatch(direct);
    if (rosterPlayer == null && technical != null) {
      final technicalId = int.tryParse(technical.group(1) ?? '');
      if (technicalId != null) {
        for (final p in widget.players) {
          if (p.id == technicalId) { rosterPlayer = p; break; }
        }
      }
    }
    final resolved = rosterPlayer?.name.trim().isNotEmpty == true ? rosterPlayer!.name.trim() : (technical == null ? direct : '');
    return _compactPlayerName(resolved);
  }

  String _compactPlayerName(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts[1].substring(0, 1).toUpperCase()}.';
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
