import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

import '../models/action_tracker_protocol.dart';
import '../models/tracker_pro_models.dart';
import '../services/tracker_pro_api.dart';
import '../services/tracker_readiness_api.dart';

class TrackerReadinessPanel extends StatefulWidget {
  const TrackerReadinessPanel({
    super.key,
    required this.api,
    required this.clubId,
    required this.userId,
    required this.teamId,
    required this.teamName,
    required this.players,
    required this.selectedPlayer,
    required this.selectedSession,
    required this.localPoints,
    required this.defaultHsrThresholdKmh,
    required this.defaultSprintThresholdKmh,
    required this.onSelectPlayer,
    required this.onThresholdsChanged,
    required this.onDebug,
    this.personalMode = false,
  });

  final TrackerProApi api;
  final int clubId;
  final int userId;
  final int teamId;
  final String teamName;
  final List<TrackerPlayerOption> players;
  final TrackerPlayerOption? selectedPlayer;
  final TrackerSessionModel? selectedSession;
  final List<ActionTrackerGpsPoint> localPoints;
  final double defaultHsrThresholdKmh;
  final double defaultSprintThresholdKmh;
  final ValueChanged<int> onSelectPlayer;
  final void Function(double hsrKmh, double sprintKmh) onThresholdsChanged;
  final void Function(String message, Map<String, dynamic> context) onDebug;
  final bool personalMode;

  @override
  State<TrackerReadinessPanel> createState() =>
      _TrackerReadinessPanelState();
}

class _TrackerReadinessPanelState extends State<TrackerReadinessPanel> {
  late TrackerReadinessApi _readinessApi;
  final TextEditingController _noteController = TextEditingController();

  List<TrackerSessionModel> _history = const <TrackerSessionModel>[];
  Map<int, TrackerReadinessRemoteSnapshot> _teamRemote =
      const <int, TrackerReadinessRemoteSnapshot>{};
  TrackerPerformanceProfile? _profile;
  TrackerReadinessCheckin? _checkin;
  int? _activePlayerId;
  bool _loading = true;
  bool _savingProfile = false;
  bool _savingCheckin = false;
  bool _editingProfile = false;
  bool _editingCheckin = false;
  bool _showTeamOverview = false;
  String _teamFilter = 'all';
  String _error = '';
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _readinessApi = TrackerReadinessApi(apiBaseUrl: widget.api.apiBaseUrl);
    _activePlayerId = _initialPlayerId();
    _showTeamOverview = !widget.personalMode;
    _reload();
  }

  @override
  void didUpdateWidget(covariant TrackerReadinessPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api.apiBaseUrl != widget.api.apiBaseUrl) {
      _readinessApi = TrackerReadinessApi(apiBaseUrl: widget.api.apiBaseUrl);
    }
    final externalPlayerId = widget.selectedPlayer?.id;
    final playerChanged = externalPlayerId != null &&
        externalPlayerId > 0 &&
        externalPlayerId != _activePlayerId;
    final scopeChanged = oldWidget.teamId != widget.teamId ||
        oldWidget.selectedSession?.id != widget.selectedSession?.id;
    if (oldWidget.personalMode != widget.personalMode) {
      _showTeamOverview = !widget.personalMode;
    }
    if (playerChanged) _activePlayerId = externalPlayerId;
    if (playerChanged || scopeChanged) _reload();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int? _initialPlayerId() {
    final selected = widget.selectedPlayer?.id;
    if (selected != null && selected > 0) return selected;
    for (final player in widget.players) {
      if (player.id > 0) return player.id;
    }
    return null;
  }

  TrackerPlayerOption? get _activePlayer {
    final id = _activePlayerId;
    if (id == null) return widget.selectedPlayer;
    for (final player in widget.players) {
      if (player.id == id || player.identityIds.contains(id)) return player;
    }
    return widget.selectedPlayer?.id == id ? widget.selectedPlayer : null;
  }

  DateTime get _referenceDate {
    final sessionDate = _parseSessionDate(widget.selectedSession?.createdAt);
    final source = sessionDate ?? DateTime.now();
    return DateTime(source.year, source.month, source.day);
  }

  String get _referenceDateIso => _isoDate(_referenceDate);

  Future<void> _reload() async {
    final playerId = _activePlayerId;
    final token = ++_loadToken;
    if (playerId == null || playerId <= 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'В составе нет игрока для расчёта готовности.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
      _editingCheckin = false;
      _editingProfile = false;
    });

    List<TrackerSessionModel> history = const <TrackerSessionModel>[];
    try {
      history = await widget.api.loadSessions(
        teamId: widget.teamId,
        playerId: null,
        date: null,
        limit: 700,
        sessionKind: 'all',
      );
    } catch (error) {
      widget.onDebug('Готовность: история сессий недоступна', {
        'team_id': widget.teamId,
        'player_id': playerId,
        'error': '$error',
      });
    }
    if (!mounted || token != _loadToken) return;
    final playerHistory = _sessionsForPlayer(history, _activePlayer);
    final referenceMax = _referenceMaxSpeed(playerHistory);
    TrackerPerformanceProfile profile = TrackerPerformanceProfile(
      playerId: playerId,
      referenceMaxSpeedKmh: referenceMax > 0 ? referenceMax : null,
    );
    TrackerReadinessCheckin checkin = TrackerReadinessCheckin(
      playerId: playerId,
      date: _referenceDateIso,
    );
    var teamRemote = <int, TrackerReadinessRemoteSnapshot>{};
    if (!widget.personalMode) {
      try {
        teamRemote = await _readinessApi.loadTeam(
          clubId: widget.clubId,
          teamId: widget.teamId,
          referenceDate: _referenceDateIso,
        );
      } on TrackerReadinessApiUnavailable {
        // Старый сервер продолжает работать в режиме одного игрока.
      } catch (error) {
        widget.onDebug('Готовность: командная сводка недоступна', {
          'team_id': widget.teamId,
          'error': '$error',
        });
      }
    }
    try {
      final remote = await _readinessApi.load(
        clubId: widget.clubId,
        teamId: widget.teamId,
        playerId: playerId,
        referenceDate: _referenceDateIso,
      );
      teamRemote[playerId] = remote;
      profile = remote.profile.copyWith(
        referenceMaxSpeedKmh:
            remote.profile.referenceMaxSpeedKmh ??
                (referenceMax > 0 ? referenceMax : null),
      );
      checkin = remote.checkin;
    } on TrackerReadinessApiUnavailable {
      // Локальные расчёты остаются доступны без служебного баннера.
    } catch (error) {
      widget.onDebug('Готовность: серверное состояние недоступно', {
        'team_id': widget.teamId,
        'player_id': playerId,
        'error': '$error',
      });
    }
    if (!mounted || token != _loadToken) return;
    _noteController.text = checkin.note;
    setState(() {
      _history = history;
      _teamRemote = teamRemote;
      _profile = profile;
      _checkin = checkin;
      _loading = false;
    });
    _publishEffectiveThresholds(profile);
  }

  void _publishEffectiveThresholds(TrackerPerformanceProfile profile) {
    final thresholds = _effectiveThresholds(profile);
    widget.onThresholdsChanged(thresholds.hsr, thresholds.sprint);
  }

  _EffectiveThresholds _effectiveThresholds(
      TrackerPerformanceProfile profile) {
    if (profile.thresholdMode == 'manual') {
      final hsr = profile.hsrThresholdKmh ?? widget.defaultHsrThresholdKmh;
      final sprint =
          profile.sprintThresholdKmh ?? widget.defaultSprintThresholdKmh;
      return _EffectiveThresholds(
        hsr.clamp(7.0, 30.0).toDouble(),
        math.max(hsr + 1, sprint).clamp(8.0, 38.0).toDouble(),
      );
    }
    if (profile.thresholdMode == 'history') {
      final reference = profile.referenceMaxSpeedKmh ??
          _referenceMaxSpeed(_playerSessions);
      if (reference > 0) {
        final hsr = math.max(7.0, reference * .75).toDouble();
        final sprint = math.max(hsr + 1, reference * .90).toDouble();
        return _EffectiveThresholds(hsr, sprint);
      }
    }
    return _EffectiveThresholds(
      widget.defaultHsrThresholdKmh,
      widget.defaultSprintThresholdKmh,
    );
  }

  List<TrackerSessionModel> get _playerSessions =>
      _sessionsForPlayer(_history, _activePlayer);

  Future<void> _selectPlayer(int playerId) async {
    if (_loading) return;
    if (playerId == _activePlayerId && !_showTeamOverview) return;
    final changed = playerId != _activePlayerId;
    TrackerPlayerOption? player;
    for (final item in widget.players) {
      if (item.id == playerId || item.identityIds.contains(playerId)) {
        player = item;
        break;
      }
    }
    final remote = player == null ? null : _teamRemoteForPlayer(player);
    if (remote != null) {
      final referenceMax =
          _referenceMaxSpeed(_sessionsForPlayer(_history, player));
      final profile = remote.profile.copyWith(
        referenceMaxSpeedKmh: remote.profile.referenceMaxSpeedKmh ??
            (referenceMax > 0 ? referenceMax : null),
      );
      _noteController.text = remote.checkin.note;
      setState(() {
        _activePlayerId = playerId;
        _showTeamOverview = false;
        _profile = profile;
        _checkin = remote.checkin;
        _editingCheckin = false;
        _editingProfile = false;
      });
      if (changed) widget.onSelectPlayer(playerId);
      _publishEffectiveThresholds(profile);
      return;
    }
    setState(() {
      _activePlayerId = playerId;
      _showTeamOverview = false;
    });
    if (changed) widget.onSelectPlayer(playerId);
    await _reload();
  }

  TrackerReadinessRemoteSnapshot? _teamRemoteForPlayer(
      TrackerPlayerOption player) {
    for (final id in <int>{player.id, ...player.identityIds}) {
      final remote = _teamRemote[id];
      if (remote != null) return remote;
    }
    return null;
  }

  Future<void> _saveProfile({List<int>? matchSessionIds}) async {
    final current = _profile;
    if (current == null || _savingProfile) return;
    final local = current.copyWith(matchSessionIds: matchSessionIds);
    setState(() {
      _profile = local;
      _savingProfile = true;
      _error = '';
    });
    try {
      final saved = await _readinessApi.saveProfile(
        clubId: widget.clubId,
        teamId: widget.teamId,
        userId: widget.userId,
        profile: local,
      );
      if (!mounted) return;
      setState(() {
        _profile = saved.copyWith(
          referenceMaxSpeedKmh:
              saved.referenceMaxSpeedKmh ?? local.referenceMaxSpeedKmh,
        );
        final currentCheckin = _checkin;
        if (currentCheckin != null) {
          _teamRemote = <int, TrackerReadinessRemoteSnapshot>{
            ..._teamRemote,
            local.playerId: TrackerReadinessRemoteSnapshot(
              profile: _profile!,
              checkin: currentCheckin,
            ),
          };
        }
        _editingProfile = false;
      });
      _publishEffectiveThresholds(_profile!);
      widget.onDebug('Персональные пороги сохранены', {
        'player_id': local.playerId,
        'mode': local.thresholdMode,
        'hsr_kmh': _effectiveThresholds(local).hsr,
        'sprint_kmh': _effectiveThresholds(local).sprint,
        'match_session_ids': local.matchSessionIds,
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            'Изменения применены на этом экране, но сервер их не сохранил: $error';
      });
      _publishEffectiveThresholds(local);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveCheckin() async {
    final current = _checkin;
    if (current == null || _savingCheckin) return;
    final local = current.copyWith(
      hasEntry: true,
      note: _noteController.text.trim(),
      rpeSessionId: current.rpe > 0 ? widget.selectedSession?.id : null,
      clearRpeSessionId: current.rpe <= 0,
    );
    setState(() {
      _checkin = local;
      _savingCheckin = true;
      _error = '';
    });
    try {
      final saved = await _readinessApi.saveCheckin(
        clubId: widget.clubId,
        teamId: widget.teamId,
        userId: widget.userId,
        checkin: local,
      );
      if (!mounted) return;
      _noteController.text = saved.note;
      setState(() {
        _checkin = saved.copyWith(hasEntry: true);
        final currentProfile = _profile;
        if (currentProfile != null) {
          _teamRemote = <int, TrackerReadinessRemoteSnapshot>{
            ..._teamRemote,
            currentProfile.playerId: TrackerReadinessRemoteSnapshot(
              profile: currentProfile,
              checkin: _checkin!,
            ),
          };
        }
        _editingCheckin = false;
      });
      widget.onDebug('Анкета готовности сохранена', {
        'player_id': local.playerId,
        'date': local.date,
        'rpe': local.rpe,
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            'Анкета учтена в текущем расчёте, но сервер её не сохранил: $error';
      });
    } finally {
      if (mounted) setState(() => _savingCheckin = false);
    }
  }

  Future<void> _toggleSelectedSessionAsMatch() async {
    final session = widget.selectedSession;
    final current = _profile;
    if (session == null || session.id <= 0 || current == null) return;
    final ids = current.matchSessionIds.toSet();
    final linkedIds = _linkedPlayerSessionIds(session);
    final alreadyMarked = linkedIds.any(ids.contains);
    if (alreadyMarked) {
      ids.removeAll(linkedIds);
    } else {
      ids.addAll(linkedIds);
    }
    await _saveProfile(matchSessionIds: ids.toList(growable: false)..sort());
  }

  Set<int> _linkedPlayerSessionIds(TrackerSessionModel selected) {
    final playerSessions = _playerSessions;
    if (playerSessions.any((session) => session.id == selected.id)) {
      return <int>{selected.id};
    }
    final groupKey = selected.sessionGroupKey.trim();
    if (groupKey.isNotEmpty) {
      final grouped = playerSessions
          .where((session) => session.sessionGroupKey.trim() == groupKey)
          .map((session) => session.id)
          .where((id) => id > 0)
          .toSet();
      if (grouped.isNotEmpty) return grouped;
    }
    final selectedDate = _parseSessionDate(selected.createdAt);
    if (selectedDate != null) {
      final nearby = playerSessions.where((session) {
        final date = _parseSessionDate(session.createdAt);
        if (date == null) return false;
        return date.difference(selectedDate).inSeconds.abs() <= 180;
      }).map((session) => session.id).where((id) => id > 0).toSet();
      if (nearby.isNotEmpty) return nearby;
    }
    return <int>{selected.id};
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    final player = _activePlayer;
    final profile = _profile;
    final checkin = _checkin;
    if (player == null || profile == null || checkin == null) {
      return _ReadinessEmpty(
        title: 'Нет игрока для расчёта',
        message: _error.isEmpty
            ? 'Добавьте игрока в состав или выберите его в аналитике.'
            : _error,
      );
    }

    if (!widget.personalMode && _showTeamOverview) {
      final wide = MediaQuery.sizeOf(context).width >= 820;
      return ColoredBox(
        color: Colors.white,
        child: ListView(
          primary: false,
          padding: EdgeInsets.fromLTRB(wide ? 10 : 8, 8, wide ? 10 : 8, 18),
          children: [
            _playerSelector(player),
            const SizedBox(height: 8),
            if (_error.isNotEmpty) ...[
              _ReadinessNotice(text: _error, warning: true),
              const SizedBox(height: 8),
            ],
            _teamDashboard(),
          ],
        ),
      );
    }

    final sessions = _playerSessions;
    final load = _ReadinessLoadSummary.calculate(
      sessions,
      referenceDate: _referenceDate,
    );
    final readiness = _ReadinessScore.calculate(load, checkin);
    final thresholds = _effectiveThresholds(profile);
    final peakWindows = _calculatePeakWindows(
      widget.localPoints,
      player: player,
      hsrThresholdKmh: thresholds.hsr,
      sprintThresholdKmh: thresholds.sprint,
    );
    final matchBaseline = _MatchBaseline.calculate(
      sessions,
      current: widget.selectedSession,
      markedSessionIds: profile.matchSessionIds.toSet(),
    );
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final medium = MediaQuery.sizeOf(context).width >= 640;

    return ColoredBox(
      color: Colors.white,
      child: ListView(
        primary: false,
        padding: EdgeInsets.fromLTRB(wide ? 10 : 8, 8, wide ? 10 : 8, 18),
        children: [
          _playerSelector(player),
          const SizedBox(height: 8),
          if (_error.isNotEmpty) ...[
            _ReadinessNotice(text: _error, warning: true),
            const SizedBox(height: 8),
          ],
          _readinessHero(player, readiness, load, checkin),
          const SizedBox(height: 8),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _loadCard(load)),
              const SizedBox(width: 8),
              Expanded(child: _peakCard(peakWindows)),
              const SizedBox(width: 8),
              Expanded(child: _wellnessCard(checkin, readiness)),
            ])
          else ...[
            _loadCard(load),
            const SizedBox(height: 8),
            _peakCard(peakWindows),
            const SizedBox(height: 8),
            _wellnessCard(checkin, readiness),
          ],
          const SizedBox(height: 8),
          if (medium)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _matchCard(matchBaseline, profile)),
              const SizedBox(width: 8),
              Expanded(child: _thresholdCard(profile, thresholds)),
            ])
          else ...[
            _matchCard(matchBaseline, profile),
            const SizedBox(height: 8),
            _thresholdCard(profile, thresholds),
          ],
        ],
      ),
    );
  }

  List<_TeamReadinessRowData> _teamRows() {
    final rows = <_TeamReadinessRowData>[];
    for (final player in widget.players.where((item) => item.id > 0)) {
      final load = _ReadinessLoadSummary.calculate(
        _sessionsForPlayer(_history, player),
        referenceDate: _referenceDate,
      );
      final remote = _teamRemoteForPlayer(player);
      final checkin = remote?.checkin ??
          TrackerReadinessCheckin(
            playerId: player.id,
            date: _referenceDateIso,
          );
      rows.add(_TeamReadinessRowData(
        player: player,
        load: load,
        checkin: checkin,
        readiness: _ReadinessScore.calculate(load, checkin),
      ));
    }
    int priority(_TeamReadinessRowData row) {
      if (row.checkin.pain >= 5 || row.readiness.score < 60) return 0;
      if (!row.checkin.hasEntry) return 1;
      if (row.readiness.score < 80 || row.checkin.fatigue >= 4) return 2;
      return 3;
    }

    rows.sort((a, b) {
      final byPriority = priority(a).compareTo(priority(b));
      if (byPriority != 0) return byPriority;
      final byScore = a.readiness.score.compareTo(b.readiness.score);
      if (byScore != 0) return byScore;
      return a.player.name.compareTo(b.player.name);
    });
    return rows;
  }

  Widget _teamDashboard() {
    final rows = _teamRows();
    final checked = rows.where((row) => row.checkin.hasEntry).length;
    final ready = rows.where((row) => row.readiness.score >= 80).length;
    final control = rows
        .where((row) =>
            row.readiness.score >= 60 && row.readiness.score < 80)
        .length;
    final reduce = rows.where((row) => row.readiness.score < 60).length;
    final average = rows.isEmpty
        ? 0
        : (rows.fold<double>(
                    0, (sum, row) => sum + row.readiness.score) /
                rows.length)
            .round();
    final visible = rows.where((row) {
      if (_teamFilter == 'attention') {
        return !row.checkin.hasEntry ||
            row.readiness.score < 80 ||
            row.checkin.pain >= 5 ||
            row.checkin.fatigue >= 4;
      }
      if (_teamFilter == 'no_checkin') return !row.checkin.hasEntry;
      if (_teamFilter == 'ready') return row.readiness.score >= 80;
      return true;
    }).toList(growable: false);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _TeamReadinessHeader(
        teamName: widget.teamName,
        referenceDate: _referenceDate,
        average: average,
        ready: ready,
        control: control,
        reduce: reduce,
        checked: checked,
        total: rows.length,
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _ReadinessColors.soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Состав по приоритету',
                        style: TextStyle(
                            color: _ReadinessColors.text,
                            fontSize: AppTypography.bodySize,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('сначала игроки, которым нужно внимание',
                        style: TextStyle(
                            color: _ReadinessColors.muted,
                            fontSize: AppTypography.menuGroupSize,
                            fontWeight: FontWeight.w500)),
                  ]),
            ),
            Text('${visible.length} из ${rows.length}',
                style: const TextStyle(
                    color: _ReadinessColors.muted,
                    fontSize: AppTypography.menuGroupSize,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 9),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _ModeChip(
              label: 'Все',
              selected: _teamFilter == 'all',
              onTap: () => setState(() => _teamFilter = 'all'),
            ),
            _ModeChip(
              label: 'Нужно внимание',
              selected: _teamFilter == 'attention',
              onTap: () => setState(() => _teamFilter = 'attention'),
            ),
            _ModeChip(
              label: 'Без анкеты',
              selected: _teamFilter == 'no_checkin',
              onTap: () => setState(() => _teamFilter = 'no_checkin'),
            ),
            _ModeChip(
              label: 'Готовы',
              selected: _teamFilter == 'ready',
              onTap: () => setState(() => _teamFilter = 'ready'),
            ),
          ]),
          const SizedBox(height: 9),
          if (visible.isEmpty)
            const _ReadinessSmallEmpty(
                text: 'В выбранном фильтре игроков нет.')
          else
            for (var index = 0; index < visible.length; index++) ...[
              _TeamReadinessPlayerRow(
                data: visible[index],
                onTap: () => _selectPlayer(visible[index].player.id),
              ),
              if (index + 1 < visible.length) const SizedBox(height: 6),
            ],
        ]),
      ),
    ]);
  }

  Widget _playerSelector(TrackerPlayerOption active) {
    final players = widget.personalMode
        ? <TrackerPlayerOption>[active]
        : widget.players.where((player) => player.id > 0).toList();
    return SizedBox(
      height: 42,
      child: Row(children: [
        const Icon(Icons.person_search_rounded,
            size: 17, color: _ReadinessColors.green),
        const SizedBox(width: 7),
        Text(widget.personalMode ? 'Игрок' : 'Состав',
            style: const TextStyle(
                color: _ReadinessColors.muted,
                fontSize: AppTypography.captionSize,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 9),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: players.length + (widget.personalMode ? 0 : 1),
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, index) {
              if (!widget.personalMode && index == 0) {
                return _ReadinessTap(
                  onTap: () => setState(() => _showTeamOverview = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _showTeamOverview
                          ? _ReadinessColors.greenSoft
                          : _ReadinessColors.soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 27,
                        height: 27,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          size: 15,
                          color: _showTeamOverview
                              ? _ReadinessColors.green
                              : _ReadinessColors.muted,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text('Команда',
                          style: TextStyle(
                              color: _showTeamOverview
                                  ? _ReadinessColors.greenDark
                                  : _ReadinessColors.text,
                              fontSize: AppTypography.captionSize,
                              fontWeight: _showTeamOverview
                                  ? FontWeight.w800
                                  : FontWeight.w600)),
                    ]),
                  ),
                );
              }
              final player =
                  players[index - (widget.personalMode ? 0 : 1)];
              final selected = !_showTeamOverview && player.id == active.id;
              return _ReadinessTap(
                onTap: () => _selectPlayer(player.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? _ReadinessColors.greenSoft
                        : _ReadinessColors.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _ReadinessPlayerAvatar(
                      player: player,
                      selected: selected,
                      size: 27,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      player.name,
                      style: TextStyle(
                        color: selected
                            ? _ReadinessColors.greenDark
                            : _ReadinessColors.text,
                        fontSize: AppTypography.captionSize,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        _ReadinessTap(
          onTap: _reload,
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.refresh_rounded,
                size: 17, color: _ReadinessColors.muted),
          ),
        ),
      ]),
    );
  }

  Widget _readinessHero(
    TrackerPlayerOption player,
    _ReadinessScore readiness,
    _ReadinessLoadSummary load,
    TrackerReadinessCheckin checkin,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: readiness.color.withOpacity(.075),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final score = Container(
          width: compact ? 68 : 78,
          height: compact ? 68 : 78,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0B111827), blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${readiness.score.round()}',
                style: TextStyle(
                    color: readiness.color,
                    fontSize: compact ? 21 : 24,
                    fontWeight: FontWeight.w900)),
            const Text('из 100',
                style: TextStyle(
                    color: _ReadinessColors.muted,
                    fontSize: AppTypography.badgeSize,
                    fontWeight: FontWeight.w600)),
          ]),
        );
        final details = Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  readiness.label,
                  style: const TextStyle(
                    color: _ReadinessColors.text,
                    fontSize: AppTypography.screenTitleSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ReadinessStatusPill(
                  text: readiness.confidenceLabel,
                  color: _ReadinessColors.muted),
            ]),
            const SizedBox(height: 3),
            Text(
              '${player.name} · расчёт на ${_displayDate(_referenceDate)}',
              style: const TextStyle(
                  color: _ReadinessColors.muted,
                  fontSize: AppTypography.captionSize,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 9),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _ReadinessMetricPill(
                  label: '7 дней', value: load.acute7.toStringAsFixed(0)),
              _ReadinessMetricPill(
                  label: '7/28',
                  value: load.ratio == null
                      ? '—'
                      : load.ratio!.toStringAsFixed(2)),
              _ReadinessMetricPill(
                  label: 'Самочувствие',
                  value: checkin.hasEntry
                      ? '${readiness.subjectiveScore.round()}%'
                      : 'не заполнено'),
              _ReadinessMetricPill(
                  label: 'Сессии 28д', value: '${load.sessions28}'),
            ]),
            const SizedBox(height: 9),
            for (final message in readiness.recommendations.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                        color: readiness.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(message,
                        style: const TextStyle(
                            color: _ReadinessColors.text,
                            fontSize: AppTypography.captionSize,
                            height: 1.25,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
          ]),
        );
        if (compact) {
          return Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              score,
              const SizedBox(width: 12),
              details,
            ]),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          score,
          const SizedBox(width: 14),
          details,
        ]);
      }),
    );
  }

  Widget _loadCard(_ReadinessLoadSummary load) {
    final ratioColor = load.ratio == null
        ? _ReadinessColors.muted
        : load.ratio! > 1.5
            ? _ReadinessColors.red
            : load.ratio! > 1.3
                ? _ReadinessColors.orange
                : _ReadinessColors.green;
    return _ReadinessCard(
      title: 'Нагрузка 7/28 дней',
      subtitle: 'история GPS-нагрузки игрока',
      icon: Icons.stacked_line_chart_rounded,
      child: Column(children: [
        Row(children: [
          Expanded(
              child: _ReadinessBigMetric(
                  label: 'Последние 7 дней',
                  value: load.acute7.toStringAsFixed(0),
                  note: '${load.sessions7} сесс.',
                  color: _ReadinessColors.text)),
          const SizedBox(width: 6),
          Expanded(
              child: _ReadinessBigMetric(
                  label: 'Средняя неделя 28д',
                  value: load.chronicWeek.toStringAsFixed(0),
                  note: '${load.sessions28} сесс.',
                  color: _ReadinessColors.text)),
          const SizedBox(width: 6),
          Expanded(
              child: _ReadinessBigMetric(
                  label: 'Тенденция 7/28',
                  value:
                      load.ratio == null ? '—' : load.ratio!.toStringAsFixed(2),
                  note: load.ratioLabel,
                  color: ratioColor)),
        ]),
        const SizedBox(height: 10),
        _SevenDayLoadBars(values: load.daily7),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _ReadinessInfoLine(
                  label: 'К предыдущей неделе',
                  value: load.weekChangeLabel)),
          Expanded(
              child: _ReadinessInfoLine(
                  label: 'Монотонность',
                  value: load.monotony > 0
                      ? load.monotony.toStringAsFixed(2)
                      : '—')),
          Expanded(
              child: _ReadinessInfoLine(
                  label: 'Strain',
                  value: load.strain > 0
                      ? load.strain.toStringAsFixed(0)
                      : '—')),
        ]),
        const SizedBox(height: 7),
        const Text(
          'Тенденция нагрузки — тренерский сигнал, а не медицинский прогноз травмы.',
          style: TextStyle(
              color: _ReadinessColors.muted,
              fontSize: AppTypography.menuGroupSize,
              height: 1.25,
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  Widget _peakCard(List<_PeakWindowMetric> peaks) {
    return _ReadinessCard(
      title: 'Пиковые отрезки',
      subtitle: 'лучшие окна выбранной GPS-сессии',
      icon: Icons.speed_rounded,
      child: peaks.isEmpty
          ? const _ReadinessSmallEmpty(
              text: 'Выберите сессию с GPS-точками для расчёта пиков.')
          : Column(children: [
              for (var i = 0; i < peaks.length; i++) ...[
                _PeakWindowRow(metric: peaks[i]),
                if (i + 1 < peaks.length) const SizedBox(height: 6),
              ],
              const SizedBox(height: 8),
              const Text(
                'Окно ищется скользящим расчётом по реальным GPS-сегментам; разрывы более 15 секунд не склеиваются.',
                style: TextStyle(
                    color: _ReadinessColors.muted,
                    fontSize: AppTypography.menuGroupSize,
                    height: 1.25,
                    fontWeight: FontWeight.w500),
              ),
            ]),
    );
  }

  Widget _wellnessCard(
      TrackerReadinessCheckin checkin, _ReadinessScore readiness) {
    return _ReadinessCard(
      title: 'Самочувствие и RPE',
      subtitle: checkin.hasEntry
          ? 'анкета на ${_displayDate(_referenceDate)}'
          : 'анкета ещё не заполнена',
      icon: Icons.favorite_outline_rounded,
      action: _ReadinessTextButton(
        label: _editingCheckin ? 'Свернуть' : 'Заполнить',
        onTap: () => setState(() => _editingCheckin = !_editingCheckin),
      ),
      child: _editingCheckin
          ? _checkinEditor(checkin)
          : Column(children: [
              Row(children: [
                Expanded(
                    child: _ReadinessBigMetric(
                        label: 'Сон',
                        value: checkin.hasEntry
                            ? '${checkin.sleepHours.toStringAsFixed(1)} ч'
                            : '—',
                        note: checkin.hasEntry
                            ? 'качество ${checkin.sleepQuality}/5'
                            : 'нет данных',
                        color: _ReadinessColors.text)),
                const SizedBox(width: 6),
                Expanded(
                    child: _ReadinessBigMetric(
                        label: 'Усталость',
                        value: checkin.hasEntry ? '${checkin.fatigue}/5' : '—',
                        note: checkin.hasEntry
                            ? 'боль ${checkin.pain}/10'
                            : 'нет данных',
                        color: checkin.fatigue >= 4 || checkin.pain >= 5
                            ? _ReadinessColors.red
                            : _ReadinessColors.text)),
                const SizedBox(width: 6),
                Expanded(
                    child: _ReadinessBigMetric(
                        label: 'RPE',
                        value: checkin.hasEntry && checkin.rpe > 0
                            ? '${checkin.rpe}/10'
                            : '—',
                        note: 'после сессии',
                        color: _ReadinessColors.text)),
              ]),
              const SizedBox(height: 10),
              _ReadinessInfoLine(
                  label: 'Субъективная готовность',
                  value: checkin.hasEntry
                      ? '${readiness.subjectiveScore.round()}%'
                      : 'нужна анкета'),
              if (checkin.note.trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(checkin.note.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _ReadinessColors.text,
                          fontSize: AppTypography.captionSize,
                          height: 1.3,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
    );
  }

  Widget _checkinEditor(TrackerReadinessCheckin checkin) {
    void update(TrackerReadinessCheckin next) => setState(() => _checkin = next);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ReadinessSlider(
        label: 'Сон',
        valueLabel: '${checkin.sleepHours.toStringAsFixed(1)} ч',
        value: checkin.sleepHours,
        min: 4,
        max: 12,
        divisions: 16,
        onChanged: (value) => update(checkin.copyWith(sleepHours: value)),
      ),
      _ScaleEditor(
        label: 'Качество сна',
        value: checkin.sleepQuality,
        goodHigh: true,
        onChanged: (value) => update(checkin.copyWith(sleepQuality: value)),
      ),
      _ScaleEditor(
        label: 'Усталость',
        value: checkin.fatigue,
        onChanged: (value) => update(checkin.copyWith(fatigue: value)),
      ),
      _ScaleEditor(
        label: 'Мышечная болезненность',
        value: checkin.muscleSoreness,
        onChanged: (value) =>
            update(checkin.copyWith(muscleSoreness: value)),
      ),
      _ScaleEditor(
        label: 'Стресс',
        value: checkin.stress,
        onChanged: (value) => update(checkin.copyWith(stress: value)),
      ),
      _ScaleEditor(
        label: 'Настроение',
        value: checkin.mood,
        goodHigh: true,
        onChanged: (value) => update(checkin.copyWith(mood: value)),
      ),
      _ReadinessSlider(
        label: 'Боль',
        valueLabel: '${checkin.pain}/10',
        value: checkin.pain.toDouble(),
        min: 0,
        max: 10,
        divisions: 10,
        danger: checkin.pain >= 5,
        onChanged: (value) => update(checkin.copyWith(pain: value.round())),
      ),
      _ReadinessSlider(
        label: 'RPE после тренировки',
        valueLabel: checkin.rpe == 0 ? 'не указано' : '${checkin.rpe}/10',
        value: checkin.rpe.toDouble(),
        min: 0,
        max: 10,
        divisions: 10,
        onChanged: (value) => update(checkin.copyWith(rpe: value.round())),
      ),
      const SizedBox(height: 5),
      TextField(
        controller: _noteController,
        minLines: 2,
        maxLines: 4,
        maxLength: 500,
        decoration: InputDecoration(
          counterText: '',
          hintText: 'Комментарий игрока: самочувствие, дискомфорт, восстановление',
          filled: true,
          fillColor: _ReadinessColors.soft,
          border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        ),
        style: const TextStyle(
            color: _ReadinessColors.text,
            fontSize: AppTypography.captionSize,
            fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: _ReadinessPrimaryButton(
          label: _savingCheckin ? 'Сохраняю…' : 'Сохранить анкету',
          onTap: _savingCheckin ? null : _saveCheckin,
        ),
      ),
    ]);
  }

  Widget _matchCard(
      _MatchBaseline baseline, TrackerPerformanceProfile profile) {
    final selectedSession = widget.selectedSession;
    final selectedMarked = selectedSession != null &&
        _linkedPlayerSessionIds(selectedSession)
            .any(profile.matchSessionIds.contains);
    return _ReadinessCard(
      title: 'Собственный эталон матча',
      subtitle: baseline.matches.isEmpty
          ? 'отметьте реальные матчи игрока'
          : '${baseline.matches.length} матч. в эталоне',
      icon: Icons.sports_soccer_rounded,
      action: selectedSession == null
          ? null
          : _ReadinessTextButton(
              label: selectedMarked ? 'Убрать матч' : 'Это матч',
              onTap: _savingProfile ? null : _toggleSelectedSessionAsMatch,
            ),
      child: baseline.matches.isEmpty
          ? const _ReadinessSmallEmpty(
              text:
                  'Откройте завершённый матч и нажмите «Это матч». Проценты будут считаться по реальной истории, без фиксированных нормативов.')
          : Column(children: [
              if (baseline.current == null)
                const _ReadinessNotice(
                    text: 'Выберите сессию, чтобы сравнить её с эталоном.')
              else
                for (var i = 0; i < baseline.comparisons.length; i++) ...[
                  _MatchComparisonRow(item: baseline.comparisons[i]),
                  if (i + 1 < baseline.comparisons.length)
                    const SizedBox(height: 6),
                ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  baseline.matches
                      .take(4)
                      .map((session) =>
                          '${_displayDate(_parseSessionDate(session.createdAt) ?? _referenceDate)} · ${session.title}')
                      .join('\n'),
                  style: const TextStyle(
                      color: _ReadinessColors.muted,
                      fontSize: AppTypography.menuGroupSize,
                      height: 1.35,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ]),
    );
  }

  Widget _thresholdCard(
    TrackerPerformanceProfile profile,
    _EffectiveThresholds thresholds,
  ) {
    return _ReadinessCard(
      title: 'Персональные нормы',
      subtitle: _thresholdModeLabel(profile.thresholdMode),
      icon: Icons.tune_rounded,
      action: _ReadinessTextButton(
        label: _editingProfile ? 'Свернуть' : 'Настроить',
        onTap: () => setState(() => _editingProfile = !_editingProfile),
      ),
      child: _editingProfile
          ? _profileEditor(profile)
          : Column(children: [
              Row(children: [
                Expanded(
                    child: _ReadinessBigMetric(
                        label: 'HIR',
                        value: thresholds.hsr.toStringAsFixed(1),
                        note: 'км/ч',
                        color: _ReadinessColors.orange)),
                const SizedBox(width: 6),
                Expanded(
                    child: _ReadinessBigMetric(
                        label: 'Спринт',
                        value: thresholds.sprint.toStringAsFixed(1),
                        note: 'км/ч',
                        color: _ReadinessColors.red)),
                const SizedBox(width: 6),
                Expanded(
                    child: _ReadinessBigMetric(
                        label: 'Личный максимум',
                        value: (profile.referenceMaxSpeedKmh ?? 0.0) > 0
                            ? profile.referenceMaxSpeedKmh!.toStringAsFixed(1)
                            : '—',
                        note: 'км/ч',
                        color: _ReadinessColors.text)),
              ]),
              const SizedBox(height: 9),
              _ReadinessInfoLine(
                  label: 'Ускорение',
                  value:
                      '≥ ${profile.accelerationThresholdMps2.toStringAsFixed(1)} м/с²'),
              const SizedBox(height: 4),
              _ReadinessInfoLine(
                  label: 'Торможение',
                  value:
                      '≤ −${profile.decelerationThresholdMps2.toStringAsFixed(1)} м/с²'),
              const SizedBox(height: 8),
              const Text(
                'После сохранения пороги сразу применяются к карте, графику скорости и пиковым отрезкам в текущей аналитике.',
                style: TextStyle(
                    color: _ReadinessColors.muted,
                    fontSize: AppTypography.menuGroupSize,
                    height: 1.25,
                    fontWeight: FontWeight.w500),
              ),
            ]),
    );
  }

  Widget _profileEditor(TrackerPerformanceProfile profile) {
    void update(TrackerPerformanceProfile next) {
      setState(() => _profile = next);
      _publishEffectiveThresholds(next);
    }

    final thresholds = _effectiveThresholds(profile);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        _ModeChip(
          label: 'Команда / возраст',
          selected: profile.thresholdMode == 'team',
          onTap: () => update(profile.copyWith(thresholdMode: 'team')),
        ),
        _ModeChip(
          label: 'От личного максимума',
          selected: profile.thresholdMode == 'history',
          onTap: () => update(profile.copyWith(thresholdMode: 'history')),
        ),
        _ModeChip(
          label: 'Вручную',
          selected: profile.thresholdMode == 'manual',
          onTap: () => update(profile.copyWith(thresholdMode: 'manual')),
        ),
      ]),
      const SizedBox(height: 9),
      if (profile.thresholdMode == 'manual') ...[
        _ReadinessSlider(
          label: 'HIR',
          valueLabel: '${thresholds.hsr.toStringAsFixed(1)} км/ч',
          value: thresholds.hsr,
          min: 8,
          max: 28,
          divisions: 40,
          onChanged: (value) => update(profile.copyWith(
              hsrThresholdKmh: value,
              sprintThresholdKmh:
                  math.max(value + 1, thresholds.sprint).toDouble())),
        ),
        _ReadinessSlider(
          label: 'Спринт',
          valueLabel: '${thresholds.sprint.toStringAsFixed(1)} км/ч',
          value: thresholds.sprint,
          min: math.max(9, thresholds.hsr + 1).toDouble(),
          max: 36,
          divisions: 54,
          danger: true,
          onChanged: (value) =>
              update(profile.copyWith(sprintThresholdKmh: value)),
        ),
      ] else
        _ReadinessNotice(
          text: profile.thresholdMode == 'history'
              ? 'HIR = 75%, спринт = 90% от подтверждённого личного максимума ${profile.referenceMaxSpeedKmh?.toStringAsFixed(1) ?? '—'} км/ч.'
              : 'Используется профиль ${widget.teamName}: HIR ${widget.defaultHsrThresholdKmh.toStringAsFixed(1)}, спринт ${widget.defaultSprintThresholdKmh.toStringAsFixed(1)} км/ч.',
        ),
      const SizedBox(height: 7),
      _ReadinessSlider(
        label: 'Порог ускорения',
        valueLabel:
            '${profile.accelerationThresholdMps2.toStringAsFixed(1)} м/с²',
        value: profile.accelerationThresholdMps2,
        min: .5,
        max: 4.0,
        divisions: 35,
        onChanged: (value) =>
            update(profile.copyWith(accelerationThresholdMps2: value)),
      ),
      _ReadinessSlider(
        label: 'Порог торможения',
        valueLabel:
            '−${profile.decelerationThresholdMps2.toStringAsFixed(1)} м/с²',
        value: profile.decelerationThresholdMps2,
        min: .5,
        max: 4.0,
        divisions: 35,
        onChanged: (value) =>
            update(profile.copyWith(decelerationThresholdMps2: value)),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: _ReadinessPrimaryButton(
          label: _savingProfile ? 'Сохраняю…' : 'Сохранить нормы',
          onTap: _savingProfile ? null : () => _saveProfile(),
        ),
      ),
    ]);
  }
}

class _TeamReadinessRowData {
  const _TeamReadinessRowData({
    required this.player,
    required this.load,
    required this.checkin,
    required this.readiness,
  });

  final TrackerPlayerOption player;
  final _ReadinessLoadSummary load;
  final TrackerReadinessCheckin checkin;
  final _ReadinessScore readiness;
}

class _TeamReadinessHeader extends StatelessWidget {
  const _TeamReadinessHeader({
    required this.teamName,
    required this.referenceDate,
    required this.average,
    required this.ready,
    required this.control,
    required this.reduce,
    required this.checked,
    required this.total,
  });

  final String teamName;
  final DateTime referenceDate;
  final int average;
  final int ready;
  final int control;
  final int reduce;
  final int checked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final averageColor = average >= 80
        ? _ReadinessColors.green
        : average >= 60
            ? _ReadinessColors.orange
            : _ReadinessColors.red;
    Widget metric(String label, String value, Color color) => Container(
          constraints: const BoxConstraints(minWidth: 104),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: _ReadinessColors.muted,
                    fontSize: AppTypography.badgeSize,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 5,
                  height: 5,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(value,
                  style: const TextStyle(
                      color: _ReadinessColors.text,
                      fontSize: AppTypography.itemTitleSize,
                      fontWeight: FontWeight.w900)),
            ]),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _ReadinessColors.greenSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.monitor_heart_rounded,
                size: 19, color: _ReadinessColors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Командный центр готовности',
                  style: TextStyle(
                      color: _ReadinessColors.text,
                      fontSize: AppTypography.screenTitleSize,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('$teamName · ${_displayDate(referenceDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _ReadinessColors.muted,
                      fontSize: AppTypography.captionSize,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text('$average/100',
                style: TextStyle(
                    color: averageColor,
                    fontSize: AppTypography.sectionTitleSize,
                    fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 11),
        Wrap(spacing: 7, runSpacing: 7, children: [
          metric('Готовы', '$ready', _ReadinessColors.green),
          metric('Контроль', '$control', _ReadinessColors.orange),
          metric('Снизить', '$reduce', _ReadinessColors.red),
          metric('Анкеты', '$checked / $total', _ReadinessColors.greenDark),
        ]),
      ]),
    );
  }
}

class _TeamReadinessPlayerRow extends StatelessWidget {
  const _TeamReadinessPlayerRow({required this.data, required this.onTap});

  final _TeamReadinessRowData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = data.readiness.score.round();
    final scoreColor = data.readiness.color;
    Widget metric(String label, String value, {Color? color}) => Container(
          width: 82,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
              color: _ReadinessColors.soft,
              borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _ReadinessColors.muted,
                    fontSize: 7.8,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color ?? _ReadinessColors.text,
                    fontSize: AppTypography.menuGroupSize,
                    fontWeight: FontWeight.w800)),
          ]),
        );

    final metrics = <Widget>[
      metric('7 дней', data.load.acute7.toStringAsFixed(0)),
      metric('7/28',
          data.load.ratio == null ? '—' : data.load.ratio!.toStringAsFixed(2),
          color: (data.load.ratio ?? 0) > 1.3
              ? _ReadinessColors.orange
              : null),
      metric('Сон', data.checkin.hasEntry
          ? '${data.checkin.sleepHours.toStringAsFixed(1)} ч'
          : 'нет анкеты'),
      metric('Боль',
          data.checkin.hasEntry ? '${data.checkin.pain}/10' : '—',
          color: data.checkin.pain >= 5 ? _ReadinessColors.red : null),
    ];

    Widget identity() => Row(children: [
          _ReadinessPlayerAvatar(
              player: data.player, selected: true, size: 38),
          const SizedBox(width: 9),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data.player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _ReadinessColors.text,
                      fontSize: AppTypography.secondarySize,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                data.checkin.hasEntry
                    ? data.readiness.label
                    : 'Анкета не заполнена · расчёт по GPS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: data.checkin.hasEntry
                        ? scoreColor
                        : _ReadinessColors.muted,
                    fontSize: AppTypography.badgeSize,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          Container(
            width: 48,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text('$score',
                style: TextStyle(
                    color: scoreColor,
                    fontSize: AppTypography.itemTitleSize,
                    fontWeight: FontWeight.w900)),
          ),
        ]);

    return _ReadinessTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth >= 760) {
            return Row(children: [
              SizedBox(width: 300, child: identity()),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 6,
                    children: metrics),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 17, color: _ReadinessColors.muted),
            ]);
          }
          return Column(children: [
            identity(),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 5, runSpacing: 5, children: metrics),
            ),
          ]);
        }),
      ),
    );
  }
}

class _EffectiveThresholds {
  const _EffectiveThresholds(this.hsr, this.sprint);
  final double hsr;
  final double sprint;
}

class _ReadinessLoadSummary {
  const _ReadinessLoadSummary({
    required this.acute7,
    required this.previous7,
    required this.chronicWeek,
    required this.ratio,
    required this.sessions7,
    required this.sessions28,
    required this.activeDays28,
    required this.daily7,
    required this.monotony,
    required this.strain,
    required this.historySpanDays,
  });

  final double acute7;
  final double previous7;
  final double chronicWeek;
  final double? ratio;
  final int sessions7;
  final int sessions28;
  final int activeDays28;
  final List<double> daily7;
  final double monotony;
  final double strain;
  final int historySpanDays;

  double? get weekChangePct => previous7 <= 0
      ? null
      : ((acute7 - previous7) / previous7 * 100).toDouble();

  String get weekChangeLabel => weekChangePct == null
      ? '—'
      : '${weekChangePct! >= 0 ? '+' : ''}${weekChangePct!.toStringAsFixed(0)}%';

  String get ratioLabel {
    final value = ratio;
    if (value == null) return 'мало данных';
    if (value > 1.5) return 'резкий рост';
    if (value > 1.3) return 'повышено';
    if (value < .65) return 'низкий объём';
    return 'стабильно';
  }

  factory _ReadinessLoadSummary.calculate(
    List<TrackerSessionModel> sessions, {
    required DateTime referenceDate,
  }) {
    final daily = <DateTime, double>{};
    var sessions7 = 0;
    var sessions28 = 0;
    DateTime? oldest;
    for (final session in sessions) {
      final date = _parseSessionDate(session.createdAt);
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (day.isAfter(referenceDate)) continue;
      final diff = referenceDate.difference(day).inDays;
      if (diff < 0 || diff > 27) continue;
      final load = _sessionLoad(session);
      if (load <= 0) continue;
      daily[day] = (daily[day] ?? 0.0) + load;
      sessions28++;
      if (diff <= 6) sessions7++;
      if (oldest == null || day.isBefore(oldest)) oldest = day;
    }
    final daily7 = List<double>.generate(7, (index) {
      final day = referenceDate.subtract(Duration(days: 6 - index));
      return daily[DateTime(day.year, day.month, day.day)] ?? 0.0;
    });
    double rangeSum(int from, int to) {
      var sum = 0.0;
      for (var diff = from; diff <= to; diff++) {
        final day = referenceDate.subtract(Duration(days: diff));
        sum += daily[DateTime(day.year, day.month, day.day)] ?? 0.0;
      }
      return sum;
    }

    final acute = rangeSum(0, 6);
    final previous = rangeSum(7, 13);
    final total28 = rangeSum(0, 27);
    final chronicWeek = total28 / 4;
    final mean = daily7.reduce((a, b) => a + b) / 7;
    final variance = daily7.fold<double>(
            0, (sum, value) => sum + math.pow(value - mean, 2).toDouble()) /
        7;
    final deviation = math.sqrt(variance);
    final monotony = acute <= 0
        ? 0.0
        : (mean / math.max(1.0, deviation)).clamp(0.0, 5.0).toDouble();
    return _ReadinessLoadSummary(
      acute7: acute,
      previous7: previous,
      chronicWeek: chronicWeek,
      ratio: chronicWeek <= 0 ? null : acute / chronicWeek,
      sessions7: sessions7,
      sessions28: sessions28,
      activeDays28: daily.length,
      daily7: daily7,
      monotony: monotony,
      strain: acute * monotony,
      historySpanDays:
          oldest == null ? 0 : referenceDate.difference(oldest).inDays + 1,
    );
  }
}

class _ReadinessScore {
  const _ReadinessScore({
    required this.score,
    required this.objectiveScore,
    required this.subjectiveScore,
    required this.label,
    required this.color,
    required this.confidenceLabel,
    required this.recommendations,
  });

  final double score;
  final double objectiveScore;
  final double subjectiveScore;
  final String label;
  final Color color;
  final String confidenceLabel;
  final List<String> recommendations;

  factory _ReadinessScore.calculate(
    _ReadinessLoadSummary load,
    TrackerReadinessCheckin checkin,
  ) {
    var objective = load.sessions28 < 2 ? 68.0 : 92.0;
    final ratio = load.ratio;
    if (ratio != null) {
      if (ratio > 1.5) {
        objective -= 35;
      } else if (ratio > 1.3) {
        objective -= 20;
      } else if (ratio < .65) {
        objective -= 8;
      }
    }
    final weekChange = load.weekChangePct;
    if (weekChange != null && weekChange > 60) {
      objective -= 18;
    } else if (weekChange != null && weekChange > 35) {
      objective -= 10;
    }
    if (load.monotony > 2.2) objective -= 10;
    objective = objective.clamp(0.0, 100.0).toDouble();

    final sleepDuration =
        (100 - (8.5 - checkin.sleepHours).abs() * 22).clamp(0.0, 100.0);
    final subjective = (
      sleepDuration * .20 +
          (checkin.sleepQuality - 1) / 4 * 100 * .15 +
          (5 - checkin.fatigue) / 4 * 100 * .15 +
          (5 - checkin.muscleSoreness) / 4 * 100 * .15 +
          (5 - checkin.stress) / 4 * 100 * .10 +
          (checkin.mood - 1) / 4 * 100 * .10 +
          (10 - checkin.pain) / 10 * 100 * .15
    ).clamp(0.0, 100.0).toDouble();
    final score = checkin.hasEntry
        ? (objective * .45 + subjective * .55).clamp(0.0, 100.0).toDouble()
        : objective;
    final recommendations = <String>[];
    if (ratio != null && ratio > 1.5) {
      recommendations.add(
          'Нагрузка последних 7 дней заметно выше средней недели за 28 дней — проверьте объём следующей сессии.');
    } else if (ratio != null && ratio > 1.3) {
      recommendations.add(
          'Нагрузка растёт: оставьте дополнительный контроль пульса и восстановления.');
    }
    if (load.monotony > 2.2) {
      recommendations.add(
          'Последние дни похожи по нагрузке — добавьте более лёгкий восстановительный день.');
    }
    if (checkin.hasEntry && checkin.pain >= 5) {
      recommendations.add(
          'Игрок отметил боль ${checkin.pain}/10. До увеличения интенсивности нужна очная оценка специалиста.');
    }
    if (checkin.hasEntry && checkin.fatigue >= 4) {
      recommendations.add(
          'Высокая субъективная усталость — снизьте рывковую и тормозную работу.');
    }
    if (checkin.hasEntry && checkin.sleepHours < 7) {
      recommendations.add(
          'Сон менее 7 часов: не ориентируйтесь только на хорошие GPS-показатели.');
    }
    if (!checkin.hasEntry) {
      recommendations.add(
          'Заполните короткую анкету — сейчас статус рассчитан только по внешней нагрузке.');
    }
    if (recommendations.isEmpty) {
      recommendations.add(
          'Нагрузка и самочувствие без критичных отклонений; план можно продолжать с обычным контролем.');
    }
    final color = score >= 80
        ? _ReadinessColors.green
        : score >= 60
            ? _ReadinessColors.orange
            : _ReadinessColors.red;
    final label = score >= 80
        ? 'Готов к плановой работе'
        : score >= 60
            ? 'Нужен контроль нагрузки'
            : 'Рекомендуется снизить интенсивность';
    final strongHistory = load.sessions28 >= 6 && load.historySpanDays >= 21;
    final confidence = strongHistory && checkin.hasEntry
        ? 'высокая уверенность'
        : strongHistory || checkin.hasEntry
            ? 'средняя уверенность'
            : 'предварительно';
    return _ReadinessScore(
      score: score,
      objectiveScore: objective,
      subjectiveScore: subjective,
      label: label,
      color: color,
      confidenceLabel: confidence,
      recommendations: recommendations,
    );
  }
}

class _PeakWindowMetric {
  const _PeakWindowMetric({
    required this.minutes,
    required this.distanceM,
    required this.metersPerMinute,
    required this.hsrDistanceM,
    required this.sprintDistanceM,
    required this.maxSpeedKmh,
    required this.startElapsedMs,
    required this.endElapsedMs,
    required this.observedSeconds,
  });
  final int minutes;
  final double distanceM;
  final double metersPerMinute;
  final double hsrDistanceM;
  final double sprintDistanceM;
  final double maxSpeedKmh;
  final int startElapsedMs;
  final int endElapsedMs;
  final int observedSeconds;
}

class _PeakSegment {
  const _PeakSegment({
    required this.timeMs,
    required this.distanceM,
    required this.speedKmh,
    required this.breakBefore,
  });
  final int timeMs;
  final double distanceM;
  final double speedKmh;
  final bool breakBefore;
}

List<_PeakWindowMetric> _calculatePeakWindows(
  List<ActionTrackerGpsPoint> source, {
  required TrackerPlayerOption player,
  required double hsrThresholdKmh,
  required double sprintThresholdKmh,
}) {
  if (source.length < 2) return const <_PeakWindowMetric>[];
  final ids = <int>{player.id, ...player.identityIds}..removeWhere((id) => id <= 0);
  var points = source
      .where((point) => point.playerId == null || ids.contains(point.playerId))
      .toList(growable: false);
  if (points.length < 2) {
    final hasForeignIds = source.any(
        (point) => point.playerId != null && !ids.contains(point.playerId));
    if (!hasForeignIds) points = source;
  }
  if (points.length < 2) return const <_PeakWindowMetric>[];
  points = [...points]..sort((a, b) => a.timeMs.compareTo(b.timeMs));
  final segments = <_PeakSegment>[];
  for (var i = 1; i < points.length; i++) {
    final previous = points[i - 1];
    final current = points[i];
    final dtMs = current.timeMs - previous.timeMs;
    if (dtMs <= 0) continue;
    final breakBefore = current.breakBefore || dtMs > 15000;
    var distance = current.distanceDeltaM ?? 0.0;
    if (!distance.isFinite || distance < 0 || distance > 100) {
      distance = 0.0;
    }
    if (distance <= 0 && !breakBefore) {
      distance = _haversineMeters(previous.latitude, previous.longitude,
          current.latitude, current.longitude);
    }
    var speed = current.speedKmh ?? 0.0;
    if (!speed.isFinite || speed < 0 || speed > 45) speed = 0.0;
    if (speed <= 0 && dtMs > 0) speed = distance / (dtMs / 1000) * 3.6;
    if (!speed.isFinite || speed > 45) continue;
    segments.add(_PeakSegment(
      timeMs: current.timeMs,
      distanceM: breakBefore ? 0.0 : distance,
      speedKmh: breakBefore ? 0.0 : speed,
      breakBefore: breakBefore,
    ));
  }
  if (segments.isEmpty) return const <_PeakWindowMetric>[];
  final baseTime = segments.first.timeMs;
  final out = <_PeakWindowMetric>[];
  for (final minutes in const <int>[1, 3, 5, 10]) {
    final windowMs = minutes * 60000;
    var left = 0;
    var sumDistance = 0.0;
    var sumHsr = 0.0;
    var sumSprint = 0.0;
    var bestDistance = -1.0;
    var bestHsr = 0.0;
    var bestSprint = 0.0;
    var bestMax = 0.0;
    var bestStart = segments.first.timeMs;
    var bestEnd = segments.first.timeMs;
    final maxQueue = <int>[];
    var maxHead = 0;
    for (var right = 0; right < segments.length; right++) {
      final segment = segments[right];
      if (segment.breakBefore) {
        left = right;
        sumDistance = 0;
        sumHsr = 0;
        sumSprint = 0;
        maxQueue.clear();
        maxHead = 0;
      }
      sumDistance += segment.distanceM;
      if (segment.speedKmh >= hsrThresholdKmh) sumHsr += segment.distanceM;
      if (segment.speedKmh >= sprintThresholdKmh) {
        sumSprint += segment.distanceM;
      }
      while (maxQueue.length > maxHead &&
          segments[maxQueue.last].speedKmh <= segment.speedKmh) {
        maxQueue.removeLast();
      }
      maxQueue.add(right);
      while (left < right &&
          segment.timeMs - segments[left].timeMs > windowMs) {
        final removed = segments[left];
        sumDistance -= removed.distanceM;
        if (removed.speedKmh >= hsrThresholdKmh) {
          sumHsr -= removed.distanceM;
        }
        if (removed.speedKmh >= sprintThresholdKmh) {
          sumSprint -= removed.distanceM;
        }
        left++;
        while (maxHead < maxQueue.length && maxQueue[maxHead] < left) {
          maxHead++;
        }
      }
      if (sumDistance > bestDistance) {
        bestDistance = sumDistance;
        bestHsr = math.max(0.0, sumHsr).toDouble();
        bestSprint = math.max(0.0, sumSprint).toDouble();
        bestMax = maxHead >= maxQueue.length
            ? 0.0
            : segments[maxQueue[maxHead]].speedKmh;
        bestStart = segments[left].timeMs;
        bestEnd = segment.timeMs;
      }
    }
    if (bestDistance <= 0) continue;
    final observedSeconds = math
        .max(1, math.min(windowMs, bestEnd - bestStart) ~/ 1000)
        .toInt();
    out.add(_PeakWindowMetric(
      minutes: minutes,
      distanceM: bestDistance,
      metersPerMinute: bestDistance / observedSeconds * 60,
      hsrDistanceM: bestHsr,
      sprintDistanceM: bestSprint,
      maxSpeedKmh: bestMax,
      startElapsedMs: math.max(0, bestStart - baseTime).toInt(),
      endElapsedMs: math.max(0, bestEnd - baseTime).toInt(),
      observedSeconds: observedSeconds,
    ));
  }
  return out;
}

class _MatchBaseline {
  const _MatchBaseline({
    required this.matches,
    required this.current,
    required this.comparisons,
  });
  final List<TrackerSessionModel> matches;
  final TrackerSessionModel? current;
  final List<_MatchComparison> comparisons;

  factory _MatchBaseline.calculate(
    List<TrackerSessionModel> sessions, {
    required TrackerSessionModel? current,
    required Set<int> markedSessionIds,
  }) {
    final matches = sessions
        .where((session) => markedSessionIds.contains(session.id))
        .toList(growable: false)
      ..sort((a, b) =>
          (_parseSessionDate(b.createdAt) ?? DateTime(1970)).compareTo(
              _parseSessionDate(a.createdAt) ?? DateTime(1970)));
    if (matches.isEmpty || current == null) {
      return _MatchBaseline(
          matches: matches,
          current: current,
          comparisons: const <_MatchComparison>[]);
    }
    double average(double Function(TrackerSessionModel) value) =>
        matches.fold<double>(0, (sum, session) => sum + value(session)) /
        matches.length;
    final values = <_MatchComparison>[
      _MatchComparison('Дистанция', current.distanceM,
          average((session) => session.distanceM), 'м'),
      _MatchComparison('м/мин', _sessionMetersPerMinute(current),
          average(_sessionMetersPerMinute), 'м/мин'),
      _MatchComparison('Макс. скорость', current.maxSpeedKmh,
          average((session) => session.maxSpeedKmh), 'км/ч'),
      _MatchComparison('HIR/VHIR', _sessionHir(current),
          average(_sessionHir), 'м'),
      _MatchComparison('Спринты', current.sprintCount.toDouble(),
          average((session) => session.sprintCount.toDouble()), 'шт.'),
      _MatchComparison('Нагрузка', _sessionLoad(current),
          average(_sessionLoad), 'балл'),
    ];
    return _MatchBaseline(matches: matches, current: current, comparisons: values);
  }
}

class _MatchComparison {
  const _MatchComparison(
      this.label, this.current, this.baseline, this.unit);
  final String label;
  final double current;
  final double baseline;
  final String unit;
  double? get percent => baseline <= 0 ? null : current / baseline * 100;
}

class _ReadinessColors {
  static const text = Color(0xFF171B18);
  static const muted = Color(0xFF66716A);
  static const soft = Color(0xFFFAFBFA);
  static const softStrong = Color(0xFFF3F5F3);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF1FAF5);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFDC2626);
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.action,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _ReadinessColors.soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: _ReadinessColors.green, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(
                        color: _ReadinessColors.text,
                        fontSize: AppTypography.secondarySize,
                        fontWeight: FontWeight.w800)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _ReadinessColors.muted,
                        fontSize: AppTypography.menuGroupSize,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
            if (action != null) action!,
          ]),
          const SizedBox(height: 11),
          child,
        ]),
      );
}

class _ReadinessBigMetric extends StatelessWidget {
  const _ReadinessBigMetric({
    required this.label,
    required this.value,
    required this.note,
    required this.color,
  });
  final String label;
  final String value;
  final String note;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _ReadinessColors.muted,
                  fontSize: AppTypography.badgeSize,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color, fontSize: AppTypography.sectionTitleSize, fontWeight: FontWeight.w900)),
          Text(note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _ReadinessColors.muted,
                  fontSize: 8.4,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _ReadinessInfoLine extends StatelessWidget {
  const _ReadinessInfoLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: _ReadinessColors.muted,
                    fontSize: AppTypography.menuGroupSize,
                    fontWeight: FontWeight.w600))),
        const SizedBox(width: 5),
        Text(value,
            style: const TextStyle(
                color: _ReadinessColors.text,
                fontSize: AppTypography.menuGroupSize,
                fontWeight: FontWeight.w800)),
      ]);
}

class _ReadinessMetricPill extends StatelessWidget {
  const _ReadinessMetricPill({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(9)),
        child: Text('$label · $value',
            style: const TextStyle(
                color: _ReadinessColors.text,
                fontSize: AppTypography.menuGroupSize,
                fontWeight: FontWeight.w700)),
      );
}

class _ReadinessPlayerAvatar extends StatelessWidget {
  const _ReadinessPlayerAvatar({
    required this.player,
    required this.selected,
    required this.size,
  });

  final TrackerPlayerOption player;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final rawAvatar = (player.avatar ?? '').trim();
    final avatar = rawAvatar.isEmpty || rawAvatar == 'null'
        ? ''
        : rawAvatar.startsWith('https://') || rawAvatar.startsWith('http://')
            ? rawAvatar
            : 'https://sportotekaapp.ru/${rawAvatar.startsWith('/') ? rawAvatar.substring(1) : rawAvatar}';
    final canLoadAvatar = avatar.isNotEmpty;
    final initials = player.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();

    Widget fallback() => Container(
          color: selected ? Colors.white : _ReadinessColors.softStrong,
          alignment: Alignment.center,
          child: Text(
            initials.isEmpty ? 'И' : initials,
            style: TextStyle(
              color: selected
                  ? _ReadinessColors.greenDark
                  : _ReadinessColors.muted,
              fontSize: size * .31,
              fontWeight: FontWeight.w900,
            ),
          ),
        );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * .34),
      ),
      child: canLoadAvatar
          ? Image.network(
              avatar,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback(),
            )
          : fallback(),
    );
  }
}

class _ReadinessStatusPill extends StatelessWidget {
  const _ReadinessStatusPill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(9)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: AppTypography.badgeSize, fontWeight: FontWeight.w700)),
      );
}

class _ReadinessNotice extends StatelessWidget {
  const _ReadinessNotice({required this.text, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: warning
              ? _ReadinessColors.orange.withOpacity(.09)
              : Colors.white,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(text,
            style: TextStyle(
                color: warning
                    ? const Color(0xFF8A5600)
                    : _ReadinessColors.muted,
                fontSize: AppTypography.menuGroupSize,
                height: 1.28,
                fontWeight: FontWeight.w600)),
      );
}

class _ReadinessSmallEmpty extends StatelessWidget {
  const _ReadinessSmallEmpty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _ReadinessColors.muted,
                fontSize: AppTypography.captionSize,
                height: 1.35,
                fontWeight: FontWeight.w600)),
      );
}

class _ReadinessEmpty extends StatelessWidget {
  const _ReadinessEmpty({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.monitor_heart_outlined,
                color: _ReadinessColors.green, size: 34),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    color: _ReadinessColors.text,
                    fontSize: AppTypography.sectionTitleSize,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _ReadinessColors.muted,
                    fontSize: AppTypography.captionSize,
                    height: 1.35,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _SevenDayLoadBars extends StatelessWidget {
  const _SevenDayLoadBars({required this.values});
  final List<double> values;
  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 1.0
        : math.max(
            1.0,
            values.reduce((a, b) => math.max(a, b).toDouble()),
          ).toDouble();
    const labels = <String>['−6', '−5', '−4', '−3', '−2', '−1', 'сегодня'];
    return SizedBox(
      height: 76,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(values[i] <= 0 ? '·' : values[i].toStringAsFixed(0),
                    style: const TextStyle(
                        color: _ReadinessColors.muted,
                        fontSize: 7.8,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Container(
                  height: math.max(3, values[i] / maxValue * 38).toDouble(),
                  decoration: BoxDecoration(
                    color: i == values.length - 1
                        ? _ReadinessColors.green
                        : _ReadinessColors.green.withOpacity(.24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 3),
                Text(labels[i],
                    maxLines: 1,
                    style: const TextStyle(
                        color: _ReadinessColors.muted,
                        fontSize: 7.2,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _PeakWindowRow extends StatelessWidget {
  const _PeakWindowRow({required this.metric});
  final _PeakWindowMetric metric;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(9)),
        child: Row(children: [
          Container(
            width: 42,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _ReadinessColors.greenSoft,
                borderRadius: BorderRadius.circular(9)),
            child: Text('${metric.minutes} мин',
                style: const TextStyle(
                    color: _ReadinessColors.greenDark,
                    fontSize: AppTypography.badgeSize,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${metric.distanceM.toStringAsFixed(0)} м · ${metric.metersPerMinute.toStringAsFixed(0)} м/мин · max ${metric.maxSpeedKmh.toStringAsFixed(1)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _ReadinessColors.text,
                      fontSize: AppTypography.menuGroupSize,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                  '${_clockMs(metric.startElapsedMs)}–${_clockMs(metric.endElapsedMs)} · HIR ${metric.hsrDistanceM.toStringAsFixed(0)} м · SPR ${metric.sprintDistanceM.toStringAsFixed(0)} м',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _ReadinessColors.muted,
                      fontSize: 8.4,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}

class _MatchComparisonRow extends StatelessWidget {
  const _MatchComparisonRow({required this.item});
  final _MatchComparison item;
  @override
  Widget build(BuildContext context) {
    final percent = item.percent;
    final color = percent == null
        ? _ReadinessColors.muted
        : percent > 120
            ? _ReadinessColors.orange
            : _ReadinessColors.green;
    final widthFactor =
        ((percent ?? 0.0) / 140).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(9)),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: Text(item.label,
                  style: const TextStyle(
                      color: _ReadinessColors.text,
                      fontSize: AppTypography.menuGroupSize,
                      fontWeight: FontWeight.w700))),
          Text(
              '${item.current.toStringAsFixed(item.unit == 'шт.' ? 0 : 1)} / ${item.baseline.toStringAsFixed(item.unit == 'шт.' ? 0 : 1)} ${item.unit}',
              style: const TextStyle(
                  color: _ReadinessColors.muted,
                  fontSize: AppTypography.badgeSize,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 7),
          SizedBox(
            width: 39,
            child: Text(percent == null ? '—' : '${percent.round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color, fontSize: AppTypography.menuGroupSize, fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(children: [
            Container(height: 4, color: _ReadinessColors.softStrong),
            FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(height: 4, color: color)),
          ]),
        ),
      ]),
    );
  }
}

class _ReadinessSlider extends StatelessWidget {
  const _ReadinessSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.danger = false,
  });
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final bool danger;
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: _ReadinessColors.text,
                      fontSize: AppTypography.menuGroupSize,
                      fontWeight: FontWeight.w700))),
          Text(valueLabel,
              style: TextStyle(
                  color: danger
                      ? _ReadinessColors.red
                      : _ReadinessColors.greenDark,
                  fontSize: AppTypography.menuGroupSize,
                  fontWeight: FontWeight.w900)),
        ]),
        SizedBox(
          height: 29,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: danger
                  ? _ReadinessColors.red
                  : _ReadinessColors.green,
              inactiveTrackColor: _ReadinessColors.softStrong,
              thumbColor: danger
                  ? _ReadinessColors.red
                  : _ReadinessColors.green,
              overlayColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
      ]);
}

class _ScaleEditor extends StatelessWidget {
  const _ScaleEditor({
    required this.label,
    required this.value,
    required this.onChanged,
    this.goodHigh = false,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool goodHigh;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: _ReadinessColors.text,
                      fontSize: AppTypography.menuGroupSize,
                      fontWeight: FontWeight.w700))),
          for (var i = 1; i <= 5; i++) ...[
            _ReadinessTap(
              onTap: () => onChanged(i),
              child: Container(
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == value
                      ? ((goodHigh ? i >= 4 : i <= 2)
                          ? _ReadinessColors.greenSoft
                          : i >= 4
                              ? _ReadinessColors.red.withOpacity(.09)
                              : _ReadinessColors.softStrong)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$i',
                    style: TextStyle(
                        color: i == value
                            ? _ReadinessColors.text
                            : _ReadinessColors.muted,
                        fontSize: AppTypography.menuGroupSize,
                        fontWeight:
                            i == value ? FontWeight.w900 : FontWeight.w600)),
              ),
            ),
            if (i < 5) const SizedBox(width: 3),
          ],
        ]),
      );
}

class _ModeChip extends StatelessWidget {
  const _ModeChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _ReadinessTap(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
              color: selected
                  ? _ReadinessColors.greenSoft
                  : Colors.white,
              borderRadius: BorderRadius.circular(9)),
          child: Text(label,
              style: TextStyle(
                  color: selected
                      ? _ReadinessColors.greenDark
                      : _ReadinessColors.muted,
                  fontSize: AppTypography.badgeSize,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        ),
      );
}

class _ReadinessTextButton extends StatelessWidget {
  const _ReadinessTextButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .45 : 1,
        child: _ReadinessTap(
          onTap: onTap,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(9)),
            child: Text(label,
                style: const TextStyle(
                    color: _ReadinessColors.greenDark,
                    fontSize: AppTypography.badgeSize,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

class _ReadinessPrimaryButton extends StatelessWidget {
  const _ReadinessPrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .55 : 1,
        child: _ReadinessTap(
          onTap: onTap,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _ReadinessColors.green,
                borderRadius: BorderRadius.circular(10)),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTypography.menuGroupSize,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

class _ReadinessTap extends StatelessWidget {
  const _ReadinessTap({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
}

List<TrackerSessionModel> _sessionsForPlayer(
  List<TrackerSessionModel> sessions,
  TrackerPlayerOption? player,
) {
  if (player == null) return const <TrackerSessionModel>[];
  final ids = <int>{player.id, ...player.identityIds}
    ..removeWhere((id) => id <= 0);
  final name = player.name.trim().toLowerCase();
  return sessions.where((session) {
    final direct = session.playerId;
    if (direct != null && direct > 0) return ids.contains(direct);
    if (session.participantIds.length == 1 &&
        session.participantIds.any(ids.contains)) return true;
    final sessionName = (session.playerName ?? '').trim().toLowerCase();
    return sessionName.isNotEmpty && name.isNotEmpty && sessionName == name;
  }).toList(growable: false);
}

double _referenceMaxSpeed(List<TrackerSessionModel> sessions) {
  var maxSpeed = 0.0;
  for (final session in sessions) {
    if (session.maxSpeedKmh.isFinite &&
        session.maxSpeedKmh > maxSpeed &&
        session.maxSpeedKmh <= 38) {
      maxSpeed = session.maxSpeedKmh;
    }
  }
  return maxSpeed;
}

double _sessionLoad(TrackerSessionModel session) {
  if (session.loadScore.isFinite && session.loadScore > 0) {
    return session.loadScore;
  }
  final high = _sessionHir(session);
  return (session.distanceM * .018 +
          high * .10 +
          session.sprintDistanceM * .22 +
          session.accelCount * 3.0 +
          session.decelCount * 2.4 +
          session.maxSpeedKmh * .65)
      .clamp(0.0, 999.0)
      .toDouble();
}

double _sessionHir(TrackerSessionModel session) => math
    .max(
      session.hsrDistanceM,
      math.max(session.hirDistanceM, session.vhirDistanceM),
    )
    .toDouble();

double _sessionMetersPerMinute(TrackerSessionModel session) {
  if (session.metersPerMinute > 0) return session.metersPerMinute;
  if (session.durationSec <= 0) return 0.0;
  return session.distanceM / (session.durationSec / 60);
}

DateTime? _parseSessionDate(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty || raw == 'null') return null;
  return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String _clockMs(int value) {
  final sec = math.max(0, value ~/ 1000).toInt();
  return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
}

String _thresholdModeLabel(String mode) {
  if (mode == 'manual') return 'ручные индивидуальные пороги';
  if (mode == 'history') return 'от подтверждённого личного максимума';
  return 'профиль команды и возраста';
}

double _haversineMeters(
    double lat1, double lon1, double lat2, double lon2) {
  if (![lat1, lon1, lat2, lon2].every((value) => value.isFinite)) return 0.0;
  const radius = 6371000.0;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dp = (lat2 - lat1) * math.pi / 180;
  final dl = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
