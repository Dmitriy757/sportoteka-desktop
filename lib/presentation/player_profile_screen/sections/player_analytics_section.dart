import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../tracker/models/action_tracker_protocol.dart';
import '../../tracker/models/tracker_pro_models.dart';
import '../../tracker/services/player_personal_analytics_api.dart';
import '../../tracker/services/tracker_pro_api.dart';
import '../../tracker/widgets/player_training_calendar_panel.dart';
import '../../tracker/widgets/tracker_action_analytics_suite.dart';
import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

enum _ProfileTrackerMode { team, personal }

class PlayerAnalyticsSection extends StatefulWidget {
  final PlayerProfileSnapshot data;
  final PlayerProfileSession? session;

  const PlayerAnalyticsSection({
    super.key,
    required this.data,
    this.session,
  });

  @override
  State<PlayerAnalyticsSection> createState() =>
      _PlayerAnalyticsSectionState();
}

class _PlayerAnalyticsSectionState
    extends State<PlayerAnalyticsSection> {
  _ProfileTrackerMode _mode = _ProfileTrackerMode.team;
  bool _loading = true;
  bool _loadingHr = false;
  String? _error;

  late TrackerProApi _teamApi;
  PlayerPersonalAnalyticsApi? _personalApi;

  List<TrackerPlayerOption> _players =
      const <TrackerPlayerOption>[];
  TrackerPlayerOption? _selectedPlayer;
  List<TrackerSessionModel> _sessions =
      const <TrackerSessionModel>[];
  TrackerSessionModel? _selectedSession;
  Map<String, dynamic> _heartRate = const <String, dynamic>{};

  int _detailSignal = 0;

  int _i(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  String _s(dynamic value) => '${value ?? ''}'.trim();

  int get _playerId => _i(
        widget.data.player['player_id'] ??
            widget.data.player['id'] ??
            widget.data.player['user_id'],
      );

  int get _ownerUserId {
    final userId = _i(
      widget.data.player['user_id'] ??
          widget.data.player['userId'],
    );
    return userId > 0 ? userId : _playerId;
  }

  int get _teamId => _i(
        widget.data.player['team_id'] ??
            widget.data.player['teamId'],
      );

  int get _clubId => _i(
        widget.data.player['club_id'] ??
            widget.data.player['clubId'],
      );

  String get _teamName {
    final value = _s(
      widget.data.player['team_name'] ??
          widget.data.player['teamName'],
    );
    return value.isEmpty ? 'Команда' : value;
  }

  String get _clubName {
    final value = _s(
      widget.data.player['club_name'] ??
          widget.data.player['clubName'] ??
          widget.data.player['school_name'],
    );
    return value.isEmpty ? 'Sportoteka' : value;
  }

  String get _playerName {
    final full = _s(
      widget.data.player['full_name'] ??
          widget.data.player['fullName'] ??
          widget.data.player['name'],
    );
    if (full.isNotEmpty) return full;
    final last = _s(
      widget.data.player['last_name'] ??
          widget.data.player['lastName'],
    );
    final first = _s(
      widget.data.player['first_name'] ??
          widget.data.player['firstName'],
    );
    final value = '$last $first'.trim();
    return value.isEmpty ? 'Игрок' : value;
  }

  String? get _avatar {
    final value = _s(
      widget.data.player['photo'] ??
          widget.data.player['photo_url'] ??
          widget.data.player['avatar'] ??
          widget.data.player['avatar_url'],
    );
    return value.isEmpty ? null : value;
  }

  TrackerProApi get _api =>
      _mode == _ProfileTrackerMode.personal
          ? _personalApi!
          : _teamApi;

  PlayerTrainingCalendarMode get _calendarMode =>
      _mode == _ProfileTrackerMode.personal
          ? PlayerTrainingCalendarMode.personal
          : PlayerTrainingCalendarMode.team;

  @override
  void initState() {
    super.initState();
    _teamApi = TrackerProApi();
    _personalApi = PlayerPersonalAnalyticsApi(
      ownerUserId: _ownerUserId,
      playerId: _playerId,
    );
    unawaited(_loadAll());
  }

  @override
  void didUpdateWidget(covariant PlayerAnalyticsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = _i(
      oldWidget.data.player['player_id'] ??
          oldWidget.data.player['id'] ??
          oldWidget.data.player['user_id'],
    );
    if (oldId != _playerId) {
      _personalApi = PlayerPersonalAnalyticsApi(
        ownerUserId: _ownerUserId,
        playerId: _playerId,
      );
      _selectedSession = null;
      _sessions = const <TrackerSessionModel>[];
      unawaited(_loadAll());
    }
  }

  TrackerPlayerOption _fallbackPlayer() {
    return TrackerPlayerOption(
      id: _playerId,
      name: _playerName,
      avatar: _avatar,
      number: _s(
        widget.data.player['number'] ??
            widget.data.player['shirt_number'],
      ).isEmpty
          ? null
          : _s(
              widget.data.player['number'] ??
                  widget.data.player['shirt_number'],
            ),
      position: _s(widget.data.player['position']).isEmpty
          ? null
          : _s(widget.data.player['position']),
      identityIds: <int>{
        if (_playerId > 0) _playerId,
        if (_ownerUserId > 0) _ownerUserId,
      },
    );
  }

  bool _matchesPlayer(TrackerPlayerOption player) {
    if (player.id == _playerId || player.id == _ownerUserId) {
      return true;
    }
    return player.identityIds.contains(_playerId) ||
        player.identityIds.contains(_ownerUserId);
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_teamId <= 0 || _playerId <= 0) {
        throw Exception(
          'Для аналитики нужны team_id и player_id.',
        );
      }

      final loadedPlayers =
          await _api.loadPlayers(teamId: _teamId);
      final matched =
          loadedPlayers.where(_matchesPlayer).toList(growable: false);
      final player =
          matched.isNotEmpty ? matched.first : _fallbackPlayer();

      final sessions = await _api.loadSessions(
        teamId: _teamId,
        playerId: player.id > 0 ? player.id : _playerId,
        limit: 40,
        sessionKind:
            _mode == _ProfileTrackerMode.personal
                ? 'personal'
                : 'team',
      );

      TrackerSessionModel? selected;
      if (_selectedSession != null) {
        for (final session in sessions) {
          if (session.id == _selectedSession!.id) {
            selected = session;
            break;
          }
        }
      }

      selected ??=
          sessions.isNotEmpty ? sessions.first : null;

      if (!mounted) return;
      setState(() {
        _players = <TrackerPlayerOption>[player];
        _selectedPlayer = player;
        _sessions = sessions;
        _selectedSession = selected;
        _loading = false;
      });

      await _loadHeartRate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _players = <TrackerPlayerOption>[_fallbackPlayer()];
        _selectedPlayer = _fallbackPlayer();
        _sessions = const <TrackerSessionModel>[];
        _selectedSession = null;
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadHeartRate() async {
    final session = _selectedSession;
    final player = _selectedPlayer;
    if (!mounted || session == null || player == null) {
      setState(() => _heartRate = const <String, dynamic>{});
      return;
    }

    setState(() => _loadingHr = true);
    try {
      final json = await _api.loadHeartRateSummary(
        teamId: _teamId,
        playerId: player.id > 0 ? player.id : _playerId,
        sessionId: session.id,
        sessionKind:
            _mode == _ProfileTrackerMode.personal
                ? 'personal'
                : 'team',
      );
      if (!mounted) return;
      setState(() {
        _heartRate = Map<String, dynamic>.from(json);
        _loadingHr = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _heartRate = const <String, dynamic>{};
        _loadingHr = false;
      });
    }
  }

  void _switchMode(_ProfileTrackerMode value) {
    if (_mode == value) return;
    setState(() {
      _mode = value;
      _selectedSession = null;
      _sessions = const <TrackerSessionModel>[];
      _heartRate = const <String, dynamic>{};
    });
    unawaited(_loadAll());
  }

  void _selectSession(TrackerSessionModel session) {
    if (_selectedSession?.id == session.id) return;
    setState(() {
      _selectedSession = session;
      _heartRate = const <String, dynamic>{};
    });
    unawaited(_loadHeartRate());
  }

  void _openDetails([TrackerSessionModel? target]) {
    final player = _selectedPlayer;
    final session = target ?? _selectedSession;
    if (player == null || session == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PlayerAnalyticsDetailPage(
          signal: ++_detailSignal,
          api: _api,
          mode: _mode,
          teamId: _teamId,
          clubId: _clubId,
          ownerUserId: _ownerUserId,
          teamName: _teamName,
          clubName:
              _mode == _ProfileTrackerMode.personal
                  ? 'Личные тренировки'
                  : _clubName,
          players: _players,
          selectedPlayer: player,
          session: session,
        ),
      ),
    );
  }

  double _avgHr() {
    final summary =
        _heartRate['summary'] is Map
            ? Map<String, dynamic>.from(
                _heartRate['summary'] as Map,
              )
            : const <String, dynamic>{};
    for (final key in const [
      'effective_avg_bpm',
      'avg_bpm',
      'average_bpm',
      'avg_hr',
    ]) {
      final value = summary[key];
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse('${value ?? ''}');
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  int _maxHr() {
    final summary =
        _heartRate['summary'] is Map
            ? Map<String, dynamic>.from(
                _heartRate['summary'] as Map,
              )
            : const <String, dynamic>{};
    for (final key in const [
      'effective_max_bpm',
      'max_bpm',
      'peak_bpm',
      'max_hr',
    ]) {
      final value = summary[key];
      final parsed = value is num
          ? value.toInt()
          : int.tryParse('${value ?? ''}');
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  int _hrSamples() {
    final summary =
        _heartRate['summary'] is Map
            ? Map<String, dynamic>.from(
                _heartRate['summary'] as Map,
              )
            : const <String, dynamic>{};
    for (final key in const [
      'effective_samples_count',
      'samples_count',
      'total_samples',
      'samples',
    ]) {
      final value = summary[key];
      final parsed = value is num
          ? value.toInt()
          : int.tryParse('${value ?? ''}');
      if (parsed != null && parsed > 0) return parsed;
    }
    return _selectedSession?.heartRateSamplesCount ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _selectedPlayer == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: PpColors.green,
        ),
      );
    }

    final session = _selectedSession;

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: [
          _AnalyticsHeader(
            mode: _mode,
            playerName: _playerName,
            subtitle:
                _mode == _ProfileTrackerMode.personal
                    ? 'Личная аналитика игрока'
                    : 'Командная аналитика игрока',
            onModeChanged: _switchMode,
            onRefresh: _loadAll,
            hasSession: session != null,
            onOpenDetails: session == null
                ? null
                : () => _openDetails(session),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            PpSurface(
              color: PpColors.amberSoft,
              bordered: false,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Text(
                'Часть данных загружена через резервный профиль игрока. $_error',
                style: PpText.body(
                  10.2,
                  color: PpColors.text,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (_sessions.isEmpty)
            const SizedBox(
              height: 240,
              child: PpSurface(
                bordered: false,
                child: PpEmpty(
                  title: 'Сессий пока нет',
                  text:
                      'Аналитика появится после загрузки данных трекера.',
                ),
              ),
            )
          else ...[
            _SelectedSessionHero(
              session: session!,
              onOpenDetails: () => _openDetails(session),
            ),
            const SizedBox(height: 10),
            _SessionChooser(
              sessions: _sessions,
              selectedSession: session,
              onSelect: _selectSession,
            ),
            const SizedBox(height: 10),
            const PpThinDivider(margin: EdgeInsets.only(bottom: 10)),
            _MetricGrid(
              session: session,
              avgHr: _avgHr(),
              maxHr: _maxHr(),
              hrSamples: _hrSamples(),
              loadingHr: _loadingHr,
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final intensity = _IntensityPanel(
                  session: session,
                  avgHr: _avgHr(),
                  maxHr: _maxHr(),
                  hrSamples: _hrSamples(),
                  loadingHr: _loadingHr,
                );
                final load = _LoadPanel(session: session);

                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: intensity),
                      const SizedBox(width: 10),
                      Expanded(child: load),
                    ],
                  );
                }

                return Column(
                  children: [
                    intensity,
                    const SizedBox(height: 10),
                    load,
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            const PpThinDivider(margin: EdgeInsets.only(bottom: 10)),
            _RecentSessionsList(
              sessions: _sessions,
              selectedSession: session,
              onSelect: _selectSession,
              onOpenDetails: _openDetails,
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  final _ProfileTrackerMode mode;
  final String playerName;
  final String subtitle;
  final ValueChanged<_ProfileTrackerMode> onModeChanged;
  final Future<void> Function() onRefresh;
  final bool hasSession;
  final VoidCallback? onOpenDetails;

  const _AnalyticsHeader({
    required this.mode,
    required this.playerName,
    required this.subtitle,
    required this.onModeChanged,
    required this.onRefresh,
    required this.hasSession,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return PpSurface(
      bordered: false,
      elevated: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Аналитика', style: PpText.title(18)),
          const SizedBox(height: 4),
          Text(
            '$playerName · $subtitle',
            style: PpText.body(10.8),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ModeSwitch(
                  value: mode,
                  onChanged: onModeChanged,
                ),
              ),
              const SizedBox(width: 8),
              _MiniButton(
                label: 'Обновить',
                onTap: () {
                  unawaited(onRefresh());
                },
              ),
              if (hasSession && onOpenDetails != null) ...[
                const SizedBox(width: 8),
                _MiniButton(
                  label: 'Подробнее',
                  emphasized: true,
                  onTap: onOpenDetails!,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  final _ProfileTrackerMode value;
  final ValueChanged<_ProfileTrackerMode> onChanged;

  const _ModeSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget item(
      String label,
      _ProfileTrackerMode mode,
    ) {
      final selected = value == mode;

      return Expanded(
        child: Material(
          color: selected
              ? PpColors.greenSoft
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => onChanged(mode),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: PpText.body(
                  10.6,
                  color: selected
                      ? PpColors.greenDark
                      : PpColors.muted,
                  weight: selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          item('Командные', _ProfileTrackerMode.team),
          const SizedBox(width: 3),
          item('Личные', _ProfileTrackerMode.personal),
        ],
      ),
    );
  }
}

class _SelectedSessionHero extends StatelessWidget {
  final TrackerSessionModel session;
  final VoidCallback onOpenDetails;

  const _SelectedSessionHero({
    required this.session,
    required this.onOpenDetails,
  });

  String _when() {
    final dt = DateTime.tryParse(
      session.createdAt.replaceFirst(' ', 'T'),
    );
    if (dt == null) return session.createdAt;
    return DateFormat('dd.MM.yyyy · HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return PpSurface(
      bordered: false,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title.trim().isEmpty
                      ? 'Сессия трекера'
                      : session.title,
                  style: PpText.title(15),
                ),
                const SizedBox(height: 4),
                Text(
                  _when(),
                  style: PpText.body(10.4),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _HeroTag(
                      label: 'Дистанция',
                      value: _fmtDistance(session.distanceM),
                    ),
                    _HeroTag(
                      label: 'Макс. скорость',
                      value: _fmtSpeed(session.maxSpeedKmh),
                    ),
                    _HeroTag(
                      label: 'Спринты',
                      value: '${session.sprintCount}',
                    ),
                    _HeroTag(
                      label: 'Нагрузка',
                      value: _fmtNumber(session.loadScore),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MiniButton(
            label: 'Подробнее',
            emphasized: true,
            onTap: onOpenDetails,
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  final String label;
  final String value;

  const _HeroTag({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: PpColors.soft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: PpText.caption(size: 9.2),
            ),
            TextSpan(
              text: value,
              style: PpText.body(
                9.8,
                color: PpColors.greenDark,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionChooser extends StatelessWidget {
  final List<TrackerSessionModel> sessions;
  final TrackerSessionModel selectedSession;
  final ValueChanged<TrackerSessionModel> onSelect;

  const _SessionChooser({
    required this.sessions,
    required this.selectedSession,
    required this.onSelect,
  });

  String _label(TrackerSessionModel session) {
    final dt = DateTime.tryParse(
      session.createdAt.replaceFirst(' ', 'T'),
    );
    final date =
        dt == null
            ? session.createdAt
            : DateFormat('dd.MM HH:mm').format(dt);
    return '${session.title.trim().isEmpty ? 'Сессия' : session.title} · $date';
  }

  @override
  Widget build(BuildContext context) {
    return PpSurface(
      bordered: false,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: sessions.length.clamp(0, 18),
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final session = sessions[index];
            final active = session.id == selectedSession.id;

            return Material(
              color: active
                  ? PpColors.greenSoft
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onSelect(session),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _label(session),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PpText.body(
                      10.0,
                      color: active
                          ? PpColors.greenDark
                          : PpColors.text,
                      weight:
                          active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final TrackerSessionModel session;
  final double avgHr;
  final int maxHr;
  final int hrSamples;
  final bool loadingHr;

  const _MetricGrid({
    required this.session,
    required this.avgHr,
    required this.maxHr,
    required this.hrSamples,
    required this.loadingHr,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_MetricItem>[
      _MetricItem('Дистанция', _fmtDistance(session.distanceM)),
      _MetricItem('Средняя скорость', _fmtSpeed(session.avgSpeedKmh)),
      _MetricItem('Макс. скорость', _fmtSpeed(session.maxSpeedKmh)),
      _MetricItem('м/мин', _fmtNumber(session.metersPerMinute)),
      _MetricItem('Спринты', '${session.sprintCount}'),
      _MetricItem('Ускорения', '${session.accelCount}'),
      _MetricItem('Торможения', '${session.decelCount}'),
      _MetricItem('Нагрузка', _fmtNumber(session.loadScore)),
      _MetricItem('Load/min', _fmtNumber(session.loadPerMinute)),
      _MetricItem('Fatigue', _fmtNumber(session.fatigueIndex)),
      _MetricItem('HSR', _fmtDistance(session.hsrDistanceM)),
      _MetricItem('Sprint Dist', _fmtDistance(session.sprintDistanceM)),
      _MetricItem('Polar AVG', loadingHr
          ? '...'
          : (avgHr > 0 ? avgHr.toStringAsFixed(0) : '—')),
      _MetricItem('Polar MAX', loadingHr
          ? '...'
          : (maxHr > 0 ? '$maxHr' : '—')),
      _MetricItem('HR samples', loadingHr
          ? '...'
          : (hrSamples > 0 ? '$hrSamples' : '—')),
      _MetricItem('Длительность', _fmtDuration(session.durationSec)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns =
            width >= 1180
                ? 4
                : width >= 760
                ? 3
                : 2;
        final itemWidth =
            (width - (columns - 1) * 8) / columns;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: PpMetric(
                    label: item.label,
                    value: item.value,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricItem {
  final String label;
  final String value;

  _MetricItem(this.label, this.value);
}

class _IntensityPanel extends StatelessWidget {
  final TrackerSessionModel session;
  final double avgHr;
  final int maxHr;
  final int hrSamples;
  final bool loadingHr;

  const _IntensityPanel({
    required this.session,
    required this.avgHr,
    required this.maxHr,
    required this.hrSamples,
    required this.loadingHr,
  });

  @override
  Widget build(BuildContext context) {
    return PpSurface(
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PpSectionTitle(
            title: 'Интенсивность',
            subtitle:
                'Скоростные и пульсовые показатели выбранной сессии',
          ),
          const SizedBox(height: 12),
          _RowMetric(
            label: 'Средняя скорость',
            value: _fmtSpeed(session.avgSpeedKmh),
          ),
          _RowMetric(
            label: 'Максимальная скорость',
            value: _fmtSpeed(session.maxSpeedKmh),
          ),
          _RowMetric(
            label: 'HSR дистанция',
            value: _fmtDistance(session.hsrDistanceM),
          ),
          _RowMetric(
            label: 'HIR дистанция',
            value: _fmtDistance(session.hirDistanceM),
          ),
          _RowMetric(
            label: 'VHIR дистанция',
            value: _fmtDistance(session.vhirDistanceM),
          ),
          _RowMetric(
            label: 'Спринт-дистанция',
            value: _fmtDistance(session.sprintDistanceM),
          ),
          _RowMetric(
            label: 'Пульс средний',
            value: loadingHr
                ? '...'
                : (avgHr > 0 ? '${avgHr.toStringAsFixed(0)} bpm' : '—'),
          ),
          _RowMetric(
            label: 'Пульс максимальный',
            value: loadingHr
                ? '...'
                : (maxHr > 0 ? '$maxHr bpm' : '—'),
          ),
          _RowMetric(
            label: 'Сэмплы Polar',
            value: loadingHr
                ? '...'
                : (hrSamples > 0 ? '$hrSamples' : '—'),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _LoadPanel extends StatelessWidget {
  final TrackerSessionModel session;

  const _LoadPanel({required this.session});

  @override
  Widget build(BuildContext context) {
    return PpSurface(
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PpSectionTitle(
            title: 'Нагрузка и объём',
            subtitle:
                'Ключевые объёмные метрики выбранной сессии',
          ),
          const SizedBox(height: 12),
          _RowMetric(
            label: 'Дистанция',
            value: _fmtDistance(session.distanceM),
          ),
          _RowMetric(
            label: 'м/мин',
            value: _fmtNumber(session.metersPerMinute),
          ),
          _RowMetric(
            label: 'Длительность',
            value: _fmtDuration(session.durationSec),
          ),
          _RowMetric(
            label: 'Спринты',
            value: '${session.sprintCount}',
          ),
          _RowMetric(
            label: 'Ускорения',
            value: '${session.accelCount}',
          ),
          _RowMetric(
            label: 'Торможения',
            value: '${session.decelCount}',
          ),
          _RowMetric(
            label: 'Load score',
            value: _fmtNumber(session.loadScore),
          ),
          _RowMetric(
            label: 'Load / min',
            value: _fmtNumber(session.loadPerMinute),
          ),
          _RowMetric(
            label: 'Fatigue index',
            value: _fmtNumber(session.fatigueIndex),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _RowMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _RowMetric({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  Color _colorForLabel() {
    final key = label.toLowerCase();
    if (key.contains('макс') || key.contains('vhir')) return PpColors.red;
    if (key.contains('спринт') || key.contains('hir')) return PpColors.amber;
    if (key.contains('пульс')) return PpColors.greenDark;
    return PpColors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          child: Row(
            children: [
              PpDot(color: _colorForLabel(), size: 5),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: PpText.body(10.6)),
              ),
              Text(
                value,
                style: PpText.body(
                  10.6,
                  color: PpColors.text,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const PpThinDivider(margin: EdgeInsets.only(top: 1, bottom: 1)),
      ],
    );
  }
}

class _RecentSessionsList extends StatelessWidget {
  final List<TrackerSessionModel> sessions;
  final TrackerSessionModel selectedSession;
  final ValueChanged<TrackerSessionModel> onSelect;
  final ValueChanged<TrackerSessionModel> onOpenDetails;

  const _RecentSessionsList({
    required this.sessions,
    required this.selectedSession,
    required this.onSelect,
    required this.onOpenDetails,
  });

  String _date(TrackerSessionModel session) {
    final dt = DateTime.tryParse(
      session.createdAt.replaceFirst(' ', 'T'),
    );
    if (dt == null) return session.createdAt;
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return PpSurface(
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PpSectionTitle(
            title: 'Последние сессии',
            subtitle:
                'Быстрый выбор сессии и переход в детальный просмотр',
          ),
          const SizedBox(height: 8),
          ...sessions.take(12).map((session) {
            final active = session.id == selectedSession.id;

            return Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: BoxDecoration(
                color: active
                    ? PpColors.greenSoft2
                    : PpColors.soft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title.trim().isEmpty
                              ? 'Сессия'
                              : session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PpText.body(
                            11.1,
                            color: PpColors.text,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_date(session)} · ${_fmtDistance(session.distanceM)} · ${_fmtSpeed(session.maxSpeedKmh)}',
                          style: PpText.body(9.9),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MiniButton(
                    label: active ? 'Выбрано' : 'Выбрать',
                    onTap: active ? null : () => onSelect(session),
                  ),
                  const SizedBox(width: 6),
                  _MiniButton(
                    label: 'Подробнее',
                    emphasized: true,
                    onTap: () => onOpenDetails(session),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool emphasized;

  const _MiniButton({
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return Material(
      color: emphasized
          ? PpColors.greenSoft
          : PpColors.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: active ? 1 : .55,
          child: Container(
            height: 34,
            padding:
                const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Text(
              label,
              style: PpText.body(
                10.2,
                color: emphasized
                    ? PpColors.greenDark
                    : PpColors.text,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerAnalyticsDetailPage extends StatelessWidget {
  final int signal;
  final TrackerProApi api;
  final _ProfileTrackerMode mode;
  final int teamId;
  final int clubId;
  final int ownerUserId;
  final String teamName;
  final String clubName;
  final List<TrackerPlayerOption> players;
  final TrackerPlayerOption selectedPlayer;
  final TrackerSessionModel session;

  const _PlayerAnalyticsDetailPage({
    required this.signal,
    required this.api,
    required this.mode,
    required this.teamId,
    required this.clubId,
    required this.ownerUserId,
    required this.teamName,
    required this.clubName,
    required this.players,
    required this.selectedPlayer,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final calendarMode =
        mode == _ProfileTrackerMode.personal
            ? PlayerTrainingCalendarMode.personal
            : PlayerTrainingCalendarMode.team;

    return Scaffold(
      backgroundColor: PpColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: PpColors.text,
        elevation: 0,
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Подробная аналитика',
              style: PpText.title(15),
            ),
            const SizedBox(height: 2),
            Text(
              selectedPlayer.name,
              style: PpText.body(10.2),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: TrackerActionAnalyticsSuite(
            key: ValueKey<String>(
              'profile-detail-${mode.name}-${session.id}-$signal',
            ),
            api: api,
            clubId: clubId,
            userId: ownerUserId,
            teamId: teamId,
            teamName: teamName,
            clubName: clubName,
            players: players,
            selectedPlayer: selectedPlayer,
            playerFilterLabel: selectedPlayer.name,
            fixedPlayerId: selectedPlayer.id,
            lockedSessionKind: calendarMode,
            personalMode: mode == _ProfileTrackerMode.personal,
            selectedField: null,
            localPoints: const <ActionTrackerGpsPoint>[],
            selectedSession: session,
            onRefresh: () {},
            onSelectPlayer: (_) {},
            onSelectSession: (_) {},
            onOpenCalibration: () {},
            onOpenSessions: () {},
            onOpenLive: () {},
            onRequestOfflineRecords: () {},
            onSaveOfflineSession: () {},
            liveRunning: false,
            commandChannelReady: false,
            offlineRecordsCount: 0,
            localPointsCount: 0,
            onDebug: (_, __) {},
            initialTab: 0,
            initialTabSignal: signal,
            initialCalendarMode: calendarMode,
            initialCalendarModeSignal: signal,
          ),
        ),
      ),
    );
  }
}

String _fmtDistance(double value) {
  if (value <= 0) return '—';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)} км';
  return '${value.toStringAsFixed(0)} м';
}

String _fmtSpeed(double value) {
  if (value <= 0) return '—';
  return '${value.toStringAsFixed(1)} км/ч';
}

String _fmtNumber(double value) {
  if (value <= 0) return '—';
  return value.toStringAsFixed(value >= 100 ? 0 : 1);
}

String _fmtDuration(int sec) {
  if (sec <= 0) return '—';
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}
