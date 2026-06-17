import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'models/tracker_pro_models.dart';
import 'services/tracker_pro_api.dart';

class TrackerPlayerActivityScreen extends StatefulWidget {
  const TrackerPlayerActivityScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.rosterPlayers,
    required this.selectedPlayer,
    this.fieldId,
  });

  final int teamId;
  final String teamName;
  final List<TrackerPlayerOption> rosterPlayers;
  final TrackerPlayerOption? selectedPlayer;
  final int? fieldId;

  @override
  State<TrackerPlayerActivityScreen> createState() => _TrackerPlayerActivityScreenState();
}

class _TrackerPlayerActivityScreenState extends State<TrackerPlayerActivityScreen> {
  late final TrackerProApi _api;
  late Future<_SessionActivityBundle> _future;
  TrackerPlayerOption? _selectedPlayer;
  TrackerSessionModel? _selectedSession;
  _ChartMetric _chartMetric = _ChartMetric.speed;

  @override
  void initState() {
    super.initState();
    _api = TrackerProApi();
    _selectedPlayer = widget.selectedPlayer;
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant TrackerPlayerActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId || oldWidget.fieldId != widget.fieldId || oldWidget.rosterPlayers.length != widget.rosterPlayers.length) {
      _selectedSession = null;
      _future = _load();
    }
  }

  Future<_SessionActivityBundle> _load() async {
    final dashboard = await _api.loadDashboard(teamId: widget.teamId);
    final sessions = await _api.loadSessions(teamId: widget.teamId, playerId: null);

    TrackerSessionModel? effectiveSession = _selectedSession;
    if (effectiveSession == null || !sessions.any((s) => s.id == effectiveSession!.id)) {
      effectiveSession = sessions.isNotEmpty ? sessions.first : null;
      _selectedSession = effectiveSession;
    }

    final players = _playersForSelector(dashboard);
    if (_selectedPlayer != null && !players.any((p) => p.id == _selectedPlayer!.id)) {
      _selectedPlayer = null;
    }

    if (effectiveSession == null) {
      return _SessionActivityBundle(
        dashboard: dashboard,
        sessions: sessions,
        selectedSession: null,
        points: const <TrackerSessionPointModel>[],
        summary: const TrackerSessionSummaryModel(),
        heatmap: const <TrackerHeatPoint>[],
      );
    }

    final result = await Future.wait<dynamic>([
      _api.loadSessionPoints(sessionId: effectiveSession.id, playerId: _selectedPlayer?.id),
      _api.loadSessionSummary(sessionId: effectiveSession.id, playerId: _selectedPlayer?.id),
      _api.loadHeatmap(teamId: widget.teamId, playerId: _selectedPlayer?.id, sessionId: effectiveSession.id, fieldId: widget.fieldId),
    ]);

    return _SessionActivityBundle(
      dashboard: dashboard,
      sessions: sessions,
      selectedSession: effectiveSession,
      points: result[0] as List<TrackerSessionPointModel>,
      summary: result[1] as TrackerSessionSummaryModel,
      heatmap: result[2] as List<TrackerHeatPoint>,
    );
  }

  void _refresh() => setState(() => _future = _load());

  void _selectSession(TrackerSessionModel? session) {
    setState(() {
      _selectedSession = session;
      _future = _load();
    });
  }

  void _selectPlayer(TrackerPlayerOption? player) {
    setState(() {
      _selectedPlayer = player;
      _future = _load();
    });
  }

  void _selectMetric(_ChartMetric metric) {
    setState(() => _chartMetric = metric);
  }

  List<TrackerPlayerOption> _playersForSelector(TrackerDashboardModel dashboard) {
    final byId = <int, TrackerPlayerOption>{};
    for (final p in widget.rosterPlayers) {
      if (p.id > 0) byId[p.id] = p;
    }
    for (final row in dashboard.players) {
      final id = row.playerId;
      if (id != null && id > 0 && !byId.containsKey(id)) {
        byId[id] = TrackerPlayerOption(id: id, name: row.playerName, avatar: row.avatar);
      }
    }
    final list = byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SessionActivityBundle>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ActivityError(error: '${snapshot.error}', onRetry: _refresh);
        }

        final bundle = snapshot.data ?? const _SessionActivityBundle.empty();
        final players = _playersForSelector(bundle.dashboard);
        final stats = _resolveStats(bundle.summary, bundle.points, bundle.dashboard);
        final chartPoints = _buildChartPoints(bundle.points, stats);
        final radar = _buildRadar(stats);

        return Padding(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 980;
              if (compact) {
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _MobileSessionPlayerSelector(
                      teamName: widget.teamName,
                      sessions: bundle.sessions,
                      selectedSession: bundle.selectedSession,
                      players: players,
                      selectedPlayer: _selectedPlayer,
                      onSessionChanged: _selectSession,
                      onPlayerChanged: _selectPlayer,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(height: 270, child: _ProfileActivityCard(radar: radar, heatmap: bundle.heatmap)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 248,
                      child: _ActivityChartCard(
                        metric: _chartMetric,
                        points: chartPoints,
                        onMetricChanged: _selectMetric,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(height: 102, child: _StatsStrip(stats: stats, onReport: () => _showReport(bundle.selectedSession))),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: constraints.maxWidth >= 1320 ? 336 : 304,
                    child: _ActivitySidebar(
                      teamName: widget.teamName,
                      sessions: bundle.sessions,
                      selectedSession: bundle.selectedSession,
                      players: players,
                      dashboard: bundle.dashboard,
                      selectedPlayer: _selectedPlayer,
                      onSessionChanged: _selectSession,
                      onPlayerChanged: _selectPlayer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(flex: 8, child: _ProfileActivityCard(radar: radar, heatmap: bundle.heatmap)),
                        const SizedBox(height: 8),
                        Expanded(
                          flex: 5,
                          child: _ActivityChartCard(
                            metric: _chartMetric,
                            points: chartPoints,
                            onMetricChanged: _selectMetric,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(height: 94, child: _StatsStrip(stats: stats, onReport: () => _showReport(bundle.selectedSession))),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  _ActivityStats _resolveStats(TrackerSessionSummaryModel summary, List<TrackerSessionPointModel> points, TrackerDashboardModel dashboard) {
    final playerName = _selectedPlayer?.name ?? 'Вся команда';
    if (summary.hasData) {
      return _ActivityStats(
        playerName: playerName,
        distanceM: summary.distanceM,
        sprintDistanceM: summary.sprintDistanceM,
        hirDistanceM: summary.hirDistanceM,
        vhirDistanceM: summary.vhirDistanceM,
        avgSpeedKmh: summary.avgSpeedKmh,
        maxSpeedKmh: summary.maxSpeedKmh,
        sprintCount: summary.sprintCount,
        accelerationCount: summary.accelerationCount,
        decelerationCount: summary.decelerationCount,
        loadScore: summary.loadScore,
        durationSec: summary.durationSec,
      );
    }

    if (points.isNotEmpty) {
      double distance = 0;
      double maxSpeed = 0;
      double speedSum = 0;
      int speedCount = 0;
      double sprintM = 0;
      double hirM = 0;
      double vhirM = 0;
      int sprintCount = 0;
      int acc = 0;
      int dec = 0;
      var wasSprint = false;
      for (final p in points) {
        distance += p.distanceDeltaM;
        maxSpeed = math.max(maxSpeed, p.speedKmh);
        if (p.speedKmh > 0) {
          speedSum += p.speedKmh;
          speedCount++;
        }
        final zone = p.intensityZone.toLowerCase();
        if (zone.contains('sprint') || p.speedKmh >= 25.2) {
          sprintM += p.distanceDeltaM;
          if (!wasSprint) sprintCount++;
          wasSprint = true;
        } else {
          wasSprint = false;
        }
        if (zone.contains('vhir') || (p.speedKmh >= 19.8 && p.speedKmh < 25.2)) vhirM += p.distanceDeltaM;
        if (zone.contains('hir') || (p.speedKmh >= 14.4 && p.speedKmh < 19.8)) hirM += p.distanceDeltaM;
        if (p.accelerationMps2 >= 1.2) acc++;
        if (p.accelerationMps2 <= -1.2) dec++;
      }
      final duration = points.isEmpty ? 0 : points.map((e) => e.elapsedSec).fold<double>(0, math.max).round();
      return _ActivityStats(
        playerName: playerName,
        distanceM: distance > 0 ? distance : points.last.cumulativeDistanceM,
        sprintDistanceM: sprintM,
        hirDistanceM: hirM,
        vhirDistanceM: vhirM,
        avgSpeedKmh: speedCount == 0 ? 0 : speedSum / speedCount,
        maxSpeedKmh: maxSpeed,
        sprintCount: sprintCount,
        accelerationCount: acc,
        decelerationCount: dec,
        loadScore: (distance / 100) + sprintCount * 6 + acc * 1.5 + dec * 1.2,
        durationSec: duration,
      );
    }

    final selectedId = _selectedPlayer?.id;
    if (selectedId != null) {
      final rows = dashboard.players.where((p) => p.playerId == selectedId).toList(growable: false);
      if (rows.isNotEmpty) {
        final row = rows.first;
        return _ActivityStats(
          playerName: row.playerName,
          distanceM: row.distanceM,
          sprintDistanceM: row.sprintDistanceM,
          hirDistanceM: math.max(0, row.highSpeedDistanceM - row.sprintDistanceM),
          vhirDistanceM: 0,
          avgSpeedKmh: row.avgSpeedKmh,
          maxSpeedKmh: row.maxSpeedKmh,
          sprintCount: row.sprintCount,
          accelerationCount: row.accelerationCount,
          decelerationCount: row.decelerationCount,
          loadScore: row.loadScore,
          durationSec: 0,
        );
      }
    }

    return _ActivityStats.empty(playerName);
  }

  List<_ChartPoint> _buildChartPoints(List<TrackerSessionPointModel> points, _ActivityStats stats) {
    if (points.isNotEmpty) {
      double cumulative = 0;
      return points.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        cumulative += p.distanceDeltaM;
        final sec = p.elapsedSec > 0 ? p.elapsedSec : i * 2.0;
        return _ChartPoint(
          x: sec,
          speed: p.speedKmh,
          acceleration: p.accelerationMps2,
          distance: p.cumulativeDistanceM > 0 ? p.cumulativeDistanceM : cumulative,
          load: math.max(0, p.speedKmh * 1.8 + p.accelerationMps2.abs() * 8),
          zoneValue: _zoneValue(p.intensityZone, p.speedKmh),
          zoneName: _zoneName(p.intensityZone, p.speedKmh),
        );
      }).toList();
    }

    final maxSpeed = math.max(1, stats.maxSpeedKmh);
    return List.generate(18, (i) {
      final t = i / 17;
      final speed = math.max(0, maxSpeed * (.25 + math.sin(t * math.pi) * .55 + math.sin(t * math.pi * 5) * .10));
      return _ChartPoint(
        x: i * 10,
        speed: speed,
        acceleration: i == 0 ? 0 : math.sin(t * math.pi * 4) * 1.8,
        distance: stats.distanceM * t,
        load: stats.loadScore * t,
        zoneValue: _zoneValue('', speed),
        zoneName: _zoneName('', speed),
      );
    });
  }

  List<_RadarAxis> _buildRadar(_ActivityStats s) {
    double n(double value, double target) => target <= 0 ? 0 : (value / target).clamp(0.05, 1.0).toDouble();
    return [
      _RadarAxis('Скорость', n(s.maxSpeedKmh, 32)),
      _RadarAxis('Выносливость', n(s.distanceM, 9000)),
      _RadarAxis('HIR', n(s.hirDistanceM + s.vhirDistanceM, 1200)),
      _RadarAxis('Спринт', n(s.sprintDistanceM, 450)),
      _RadarAxis('Манёвры', n((s.accelerationCount + s.decelerationCount).toDouble(), 80)),
      _RadarAxis('Нагрузка', n(s.loadScore, 550)),
    ];
  }

  void _showReport(TrackerSessionModel? session) {
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала выберите сессию.')));
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.28),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: FutureBuilder<TrackerSessionReportModel>(
          future: _api.loadSessionReport(sessionId: session.id, playerId: _selectedPlayer?.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
              return const SizedBox(width: 420, height: 260, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return _ReportDialogShell(
                title: 'Отчёт по сессии',
                child: _ActivityError(error: '${snapshot.error}', onRetry: () => Navigator.of(context).pop()),
              );
            }
            final report = snapshot.data;
            final summary = report?.summary ?? const TrackerSessionSummaryModel();
            return _ReportDialogShell(
              title: 'Отчёт по сессии',
              child: _SessionReportView(session: session, player: _selectedPlayer, summary: summary, pointsCount: report?.points.length ?? 0),
            );
          },
        ),
      ),
    );
  }

  static double _zoneValue(String zone, double speed) {
    final z = zone.toLowerCase();
    if (z.contains('sprint') || speed >= 25.2) return 5;
    if (z.contains('vhir') || speed >= 19.8) return 4;
    if (z.contains('hir') || speed >= 14.4) return 3;
    if (z.contains('run') || z.contains('бег') || speed >= 3.6) return 2;
    return 1;
  }

  static String _zoneName(String zone, double speed) {
    final v = _zoneValue(zone, speed);
    if (v >= 5) return 'Спринт';
    if (v >= 4) return 'VHIR';
    if (v >= 3) return 'HIR';
    if (v >= 2) return 'Бег';
    return 'Ходьба';
  }
}

enum _ChartMetric { speed, acceleration, distance, zones, load }

extension _ChartMetricTitle on _ChartMetric {
  String get title {
    switch (this) {
      case _ChartMetric.speed:
        return 'Скорость';
      case _ChartMetric.acceleration:
        return 'Ускорение';
      case _ChartMetric.distance:
        return 'Дистанция';
      case _ChartMetric.zones:
        return 'Зоны';
      case _ChartMetric.load:
        return 'Нагрузка';
    }
  }

  String get unit {
    switch (this) {
      case _ChartMetric.speed:
        return 'км/ч';
      case _ChartMetric.acceleration:
        return 'м/с²';
      case _ChartMetric.distance:
        return 'м';
      case _ChartMetric.zones:
        return 'зона';
      case _ChartMetric.load:
        return 'баллы';
    }
  }
}

class _SessionActivityBundle {
  final TrackerDashboardModel dashboard;
  final List<TrackerSessionModel> sessions;
  final TrackerSessionModel? selectedSession;
  final List<TrackerSessionPointModel> points;
  final TrackerSessionSummaryModel summary;
  final List<TrackerHeatPoint> heatmap;

  const _SessionActivityBundle({
    required this.dashboard,
    required this.sessions,
    required this.selectedSession,
    required this.points,
    required this.summary,
    required this.heatmap,
  });

  const _SessionActivityBundle.empty()
      : dashboard = const TrackerDashboardModel(summary: <String, dynamic>{}, players: <TrackerPlayerLoadRow>[], alerts: <Map<String, dynamic>>[]),
        sessions = const <TrackerSessionModel>[],
        selectedSession = null,
        points = const <TrackerSessionPointModel>[],
        summary = const TrackerSessionSummaryModel(),
        heatmap = const <TrackerHeatPoint>[];
}

class _ActivityStats {
  final String playerName;
  final double distanceM;
  final double sprintDistanceM;
  final double hirDistanceM;
  final double vhirDistanceM;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final int sprintCount;
  final int accelerationCount;
  final int decelerationCount;
  final double loadScore;
  final int durationSec;

  const _ActivityStats({
    required this.playerName,
    required this.distanceM,
    required this.sprintDistanceM,
    required this.hirDistanceM,
    required this.vhirDistanceM,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.sprintCount,
    required this.accelerationCount,
    required this.decelerationCount,
    required this.loadScore,
    required this.durationSec,
  });

  factory _ActivityStats.empty(String name) => _ActivityStats(
        playerName: name,
        distanceM: 0,
        sprintDistanceM: 0,
        hirDistanceM: 0,
        vhirDistanceM: 0,
        avgSpeedKmh: 0,
        maxSpeedKmh: 0,
        sprintCount: 0,
        accelerationCount: 0,
        decelerationCount: 0,
        loadScore: 0,
        durationSec: 0,
      );
}

class _ChartPoint {
  final double x;
  final double speed;
  final double acceleration;
  final double distance;
  final double zoneValue;
  final String zoneName;
  final double load;

  const _ChartPoint({
    required this.x,
    required this.speed,
    required this.acceleration,
    required this.distance,
    required this.zoneValue,
    required this.zoneName,
    required this.load,
  });

  double valueFor(_ChartMetric metric) {
    switch (metric) {
      case _ChartMetric.speed:
        return speed;
      case _ChartMetric.acceleration:
        return acceleration;
      case _ChartMetric.distance:
        return distance;
      case _ChartMetric.zones:
        return zoneValue;
      case _ChartMetric.load:
        return load;
    }
  }
}

class _RadarAxis {
  const _RadarAxis(this.label, this.value);
  final String label;
  final double value;
}

class _AA {
  static const Color bg = Color(0xFFF6F8FB);
  static const Color card = Colors.white;
  static const Color card2 = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color green = Color(0xFF00B957);
  static const Color blue = Color(0xFF2563EB);
  static const Color orange = Color(0xFFF97316);
  static const Color red = Color(0xFFE11D48);
}

class _ActivitySidebar extends StatelessWidget {
  const _ActivitySidebar({
    required this.teamName,
    required this.sessions,
    required this.selectedSession,
    required this.players,
    required this.dashboard,
    required this.selectedPlayer,
    required this.onSessionChanged,
    required this.onPlayerChanged,
  });

  final String teamName;
  final List<TrackerSessionModel> sessions;
  final TrackerSessionModel? selectedSession;
  final List<TrackerPlayerOption> players;
  final TrackerDashboardModel dashboard;
  final TrackerPlayerOption? selectedPlayer;
  final ValueChanged<TrackerSessionModel?> onSessionChanged;
  final ValueChanged<TrackerPlayerOption?> onPlayerChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TeamBadge(teamName: teamName),
          const SizedBox(height: 8),
          _SectionLabel(title: 'Сессии', subtitle: '${sessions.length} записей'),
          const SizedBox(height: 6),
          SizedBox(
            height: 178,
            child: sessions.isEmpty
                ? const _EmptyMini(text: 'Сессий пока нет')
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final s = sessions[index];
                      return _SessionTile(session: s, selected: selectedSession?.id == s.id, onTap: () => onSessionChanged(s));
                    },
                  ),
          ),
          const SizedBox(height: 10),
          _SectionLabel(title: 'Игроки', subtitle: selectedPlayer?.name ?? 'Вся команда'),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: players.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _PlayerTile(
                    title: 'Вся команда',
                    subtitle: 'общий отчёт по сессии',
                    avatar: null,
                    selected: selectedPlayer == null,
                    onTap: () => onPlayerChanged(null),
                  );
                }
                final player = players[index - 1];
                final row = dashboard.players.where((p) => p.playerId == player.id).toList(growable: false);
                final subtitle = row.isEmpty
                    ? [if (player.number != null) '#${player.number}', if (player.position != null) player.position].join(' · ')
                    : '${_meters(row.first.distanceM)} · макс. ${row.first.maxSpeedKmh.toStringAsFixed(1)} км/ч';
                return _PlayerTile(
                  title: player.name,
                  subtitle: subtitle.isEmpty ? 'игрок команды' : subtitle,
                  avatar: player.avatar,
                  selected: selectedPlayer?.id == player.id,
                  onTap: () => onPlayerChanged(player),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSessionPlayerSelector extends StatelessWidget {
  const _MobileSessionPlayerSelector({
    required this.teamName,
    required this.sessions,
    required this.selectedSession,
    required this.players,
    required this.selectedPlayer,
    required this.onSessionChanged,
    required this.onPlayerChanged,
  });

  final String teamName;
  final List<TrackerSessionModel> sessions;
  final TrackerSessionModel? selectedSession;
  final List<TrackerPlayerOption> players;
  final TrackerPlayerOption? selectedPlayer;
  final ValueChanged<TrackerSessionModel?> onSessionChanged;
  final ValueChanged<TrackerPlayerOption?> onPlayerChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TeamBadge(teamName: teamName),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedSession?.id,
                  isExpanded: true,
                  decoration: _dropdownDecoration('Сессия'),
                  items: sessions.map((s) => DropdownMenuItem<int>(value: s.id, child: Text(s.title, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (id) {
                    final list = sessions.where((s) => s.id == id).toList(growable: false);
                    onSessionChanged(list.isEmpty ? null : list.first);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedPlayer?.id,
                  isExpanded: true,
                  decoration: _dropdownDecoration('Игрок'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Вся команда')),
                    ...players.map((p) => DropdownMenuItem<int>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (id) {
                    final list = players.where((p) => p.id == id).toList(growable: false);
                    onPlayerChanged(list.isEmpty ? null : list.first);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: _AA.card2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AA.border)),
      );
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.teamName});
  final String teamName;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFEFFDF5), borderRadius: BorderRadius.circular(14), border: Border.all(color: _AA.green.withOpacity(.20))),
      child: Row(
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: _AA.green, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.groups_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Активная команда', style: TextStyle(color: _AA.muted, fontSize: 10.5, fontWeight: FontWeight.w800)),
              Text(teamName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 14, fontWeight: FontWeight.w900)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(title, style: const TextStyle(color: _AA.text, fontSize: 13, fontWeight: FontWeight.w900))),
      Text(subtitle, style: const TextStyle(color: _AA.muted, fontSize: 10.5, fontWeight: FontWeight.w800)),
    ]);
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.selected, required this.onTap});
  final TrackerSessionModel session;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFFDF5) : _AA.card2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _AA.green.withOpacity(.35) : _AA.border),
        ),
        child: Row(children: [
          Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? _AA.green : _AA.muted, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 12.2, fontWeight: FontWeight.w900)),
            Text('${_meters(session.distanceM)} · ${session.maxSpeedKmh.toStringAsFixed(1)} км/ч · ${session.createdAt}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.2, fontWeight: FontWeight.w800)),
          ])),
        ]),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.title, required this.subtitle, required this.avatar, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final String? avatar;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFFDF5) : _AA.card2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _AA.green.withOpacity(.35) : _AA.border),
        ),
        child: Row(children: [
          _Avatar(url: avatar, text: title, size: 36),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 12.2, fontWeight: FontWeight.w900)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.2, fontWeight: FontWeight.w800)),
          ])),
        ]),
      ),
    );
  }
}

class _ProfileActivityCard extends StatelessWidget {
  const _ProfileActivityCard({required this.radar, required this.heatmap});
  final List<_RadarAxis> radar;
  final List<TrackerHeatPoint> heatmap;
  @override
  Widget build(BuildContext context) {
    return _ActivityCard(
      title: 'Профиль активности',
      subtitle: 'радар игрока и теплокарта выбранной сессии',
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 540) {
          return Column(children: [
            Expanded(child: CustomPaint(painter: _RadarActivityPainter(axes: radar), child: const SizedBox.expand())),
            SizedBox(height: 145, child: CustomPaint(painter: _MiniPitchActivityPainter(points: heatmap), child: const SizedBox.expand())),
          ]);
        }
        return Row(children: [
          Expanded(flex: 6, child: CustomPaint(painter: _RadarActivityPainter(axes: radar), child: const SizedBox.expand())),
          Container(width: 1, color: _AA.border),
          Expanded(flex: 5, child: CustomPaint(painter: _MiniPitchActivityPainter(points: heatmap), child: const SizedBox.expand())),
        ]);
      }),
    );
  }
}

class _ActivityChartCard extends StatelessWidget {
  const _ActivityChartCard({required this.metric, required this.points, required this.onMetricChanged});
  final _ChartMetric metric;
  final List<_ChartPoint> points;
  final ValueChanged<_ChartMetric> onMetricChanged;
  @override
  Widget build(BuildContext context) {
    return _ActivityCard(
      title: 'График активности',
      subtitle: 'выберите показатель: скорость, ускорение, дистанция, зоны или нагрузка',
      trailing: Text(metric.unit, style: const TextStyle(color: _AA.green, fontSize: 11, fontWeight: FontWeight.w900)),
      child: Column(children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
            children: _ChartMetric.values.map((m) {
              final active = m == metric;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  selected: active,
                  label: Text(m.title),
                  selectedColor: const Color(0xFFEFFDF5),
                  backgroundColor: _AA.card2,
                  side: BorderSide(color: active ? _AA.green.withOpacity(.4) : _AA.border),
                  labelStyle: TextStyle(color: active ? _AA.green : _AA.muted, fontSize: 10.5, fontWeight: FontWeight.w900),
                  onSelected: (_) => onMetricChanged(m),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(child: CustomPaint(painter: _ActivityLinePainter(points: points, metric: metric), child: const SizedBox.expand())),
      ]),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats, required this.onReport});
  final _ActivityStats stats;
  final VoidCallback onReport;
  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(Icons.route_rounded, 'Дистанция', _meters(stats.distanceM)),
      _MetricData(Icons.flash_on_rounded, 'Спринт', _meters(stats.sprintDistanceM)),
      _MetricData(Icons.local_fire_department_rounded, 'HIR/VHIR', _meters(stats.hirDistanceM + stats.vhirDistanceM)),
      _MetricData(Icons.speed_rounded, 'Средняя', '${stats.avgSpeedKmh.toStringAsFixed(1)} км/ч'),
      _MetricData(Icons.trending_up_rounded, 'Макс.', '${stats.maxSpeedKmh.toStringAsFixed(1)} км/ч'),
      _MetricData(Icons.directions_run_rounded, 'Спринты', '${stats.sprintCount}'),
      _MetricData(Icons.keyboard_double_arrow_up_rounded, 'Ускорения', '${stats.accelerationCount}'),
      _MetricData(Icons.keyboard_double_arrow_down_rounded, 'Торможения', '${stats.decelerationCount}'),
      _MetricData(Icons.bolt_rounded, 'Нагрузка', stats.loadScore.toStringAsFixed(0)),
    ];
    return _ActivityCard(
      title: 'Онлайн обзор KPI',
      subtitle: 'итог выбранной сессии и игрока',
      trailing: TextButton.icon(
        onPressed: onReport,
        icon: const Icon(Icons.description_rounded, size: 15),
        label: const Text('Отчёт'),
        style: TextButton.styleFrom(foregroundColor: _AA.green, textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        child: Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            SizedBox(width: 148, height: 48, child: _MetricTile(data: items[i])),
            if (i != items.length - 1) const SizedBox(width: 7),
          ],
        ]),
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.icon, this.title, this.value);
  final IconData icon;
  final String title;
  final String value;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});
  final _MetricData data;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: _AA.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: _AA.border)),
      child: Row(children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: const Color(0xFFDDFBEA), borderRadius: BorderRadius.circular(10)), child: Icon(data.icon, color: _AA.green, size: 17)),
        const SizedBox(width: 8),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 14.2, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()])),
          Text(data.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.7, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.title, required this.subtitle, required this.child, this.trailing});
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _AA.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 14, offset: const Offset(0, 8))]),
      child: Column(children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(color: _AA.card2, border: Border(bottom: BorderSide(color: _AA.border))),
          child: Row(children: [
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 13, fontWeight: FontWeight.w900)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.3, fontWeight: FontWeight.w800)),
            ])),
            if (trailing != null) trailing!,
          ]),
        ),
        Expanded(child: child),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _AA.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 14, offset: const Offset(0, 8))]),
      child: child,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.text, required this.size});
  final String? url;
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeActivityAvatarUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2.8),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFEFFDF5),
        child: normalized == null
            ? Center(child: Text(_initials(text), style: const TextStyle(color: _AA.green, fontWeight: FontWeight.w900)))
            : Image.network(normalized, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(_initials(text), style: const TextStyle(color: _AA.green, fontWeight: FontWeight.w900)))),
      ),
    );
  }
}

class _EmptyMini extends StatelessWidget {
  const _EmptyMini({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _AA.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: _AA.border)),
      child: Text(text, style: const TextStyle(color: _AA.muted, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _ActivityError extends StatelessWidget {
  const _ActivityError({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _AA.border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: _AA.red, size: 34),
          const SizedBox(height: 8),
          const Text('Не удалось загрузить активность', style: TextStyle(color: _AA.text, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(error, textAlign: TextAlign.center, style: const TextStyle(color: _AA.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Повторить')),
        ]),
      ),
    );
  }
}

class _ActivityLinePainter extends CustomPainter {
  const _ActivityLinePainter({required this.points, required this.metric});
  final List<_ChartPoint> points;
  final _ChartMetric metric;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = _AA.card);
    final chart = Rect.fromLTWH(42, 12, math.max(10, size.width - 58), math.max(10, size.height - 34));
    final grid = Paint()..color = _AA.border.withOpacity(.85)..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }

    if (points.isEmpty) {
      _drawText(canvas, size, 'Нет точек сессии');
      return;
    }

    final values = points.map((p) => p.valueFor(metric)).toList();
    final minV = metric == _ChartMetric.acceleration ? values.fold<double>(0, math.min) : 0.0;
    final maxV = math.max(1, values.fold<double>(0, math.max));
    final range = math.max(1, maxV - minV);
    final minX = points.first.x;
    final maxX = math.max(minX + 1, points.last.x);

    Offset map(_ChartPoint p) {
      final x = chart.left + ((p.x - minX) / (maxX - minX)).clamp(0, 1) * chart.width;
      final y = chart.bottom - ((p.valueFor(metric) - minV) / range).clamp(0, 1) * chart.height;
      return Offset(x.toDouble(), y.toDouble());
    }

    if (metric == _ChartMetric.zones) {
      for (var i = 0; i < points.length - 1; i++) {
        final a = map(points[i]);
        final b = map(points[i + 1]);
        final paint = Paint()..color = _zoneColor(points[i].zoneValue).withOpacity(.20)..strokeWidth = math.max(4, chart.height / 12)..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(a.dx, chart.center.dy), Offset(b.dx, chart.center.dy), paint);
      }
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = map(points[i]);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    final line = Paint()
      ..color = metric == _ChartMetric.acceleration ? _AA.orange : _AA.green
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);
    for (var i = 0; i < points.length; i += math.max(1, points.length ~/ 32)) {
      final o = map(points[i]);
      canvas.drawCircle(o, 3.2, Paint()..color = metric == _ChartMetric.zones ? _zoneColor(points[i].zoneValue) : _AA.green);
      canvas.drawCircle(o, 5.2, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white);
    }

    _axisText(canvas, chart.left - 34, chart.top - 2, maxV.toStringAsFixed(metric == _ChartMetric.zones ? 0 : 1));
    _axisText(canvas, chart.left - 30, chart.bottom - 10, minV.toStringAsFixed(metric == _ChartMetric.zones ? 0 : 1));
  }

  void _drawText(Canvas canvas, Size size, String text) {
    final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: _AA.muted, fontSize: 13, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout(maxWidth: size.width - 30);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  void _axisText(Canvas canvas, double x, double y, String text) {
    final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: _AA.muted, fontSize: 9, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(x, y));
  }

  Color _zoneColor(double v) {
    if (v >= 5) return _AA.red;
    if (v >= 4) return _AA.orange;
    if (v >= 3) return const Color(0xFFFACC15);
    if (v >= 2) return _AA.blue;
    return _AA.green;
  }

  @override
  bool shouldRepaint(covariant _ActivityLinePainter oldDelegate) => oldDelegate.points != points || oldDelegate.metric != metric;
}

class _RadarActivityPainter extends CustomPainter {
  const _RadarActivityPainter({required this.axes});
  final List<_RadarAxis> axes;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .34;
    final grid = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _AA.border;
    for (var r = 1; r <= 4; r++) {
      canvas.drawCircle(center, radius * r / 4, grid);
    }
    if (axes.isEmpty) return;
    final points = <Offset>[];
    for (var i = 0; i < axes.length; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / axes.length;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(center, end, grid);
      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius * axes[i].value.clamp(0.0, 1.0);
      points.add(p);
      final label = axes[i].label;
      final tp = TextPainter(text: TextSpan(text: label, style: const TextStyle(color: _AA.muted, fontSize: 10, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout(maxWidth: 82);
      final labelPos = center + Offset(math.cos(angle), math.sin(angle)) * (radius + 20);
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = _AA.green.withOpacity(.18));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = _AA.green);
    for (final p in points) {
      canvas.drawCircle(p, 3.5, Paint()..color = _AA.green);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarActivityPainter oldDelegate) => oldDelegate.axes != axes;
}

class _MiniPitchActivityPainter extends CustomPainter {
  const _MiniPitchActivityPainter({required this.points});
  final List<TrackerHeatPoint> points;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(14);
    const aspect = 105 / 68;
    var w = rect.width;
    var h = w / aspect;
    if (h > rect.height) {
      h = rect.height;
      w = h * aspect;
    }
    final pitch = Rect.fromCenter(center: rect.center, width: w, height: h);
    canvas.drawRRect(RRect.fromRectAndRadius(pitch, const Radius.circular(10)), Paint()..color = const Color(0xFF087A3A));
    for (var i = 0; i < 10; i++) {
      canvas.drawRect(Rect.fromLTWH(pitch.left + pitch.width * i / 10, pitch.top, pitch.width / 10, pitch.height), Paint()..color = i.isEven ? Colors.white.withOpacity(.045) : Colors.black.withOpacity(.04));
    }
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = Colors.white.withOpacity(.85);
    final inner = pitch.deflate(8);
    canvas.drawRect(inner, line);
    canvas.drawLine(Offset(inner.center.dx, inner.top), Offset(inner.center.dx, inner.bottom), line);
    canvas.drawCircle(inner.center, inner.height * .18, line);
    canvas.drawRect(Rect.fromLTWH(inner.left, inner.center.dy - inner.height * .22, inner.width * .16, inner.height * .44), line);
    canvas.drawRect(Rect.fromLTWH(inner.right - inner.width * .16, inner.center.dy - inner.height * .22, inner.width * .16, inner.height * .44), line);

    final maxValue = points.fold<double>(1, (m, p) => math.max(m, p.value));
    for (final p in points) {
      final nx = p.x > 1 ? (p.x / 105).clamp(0.0, 1.0) : p.x.clamp(0.0, 1.0);
      final ny = p.y > 1 ? (p.y / 68).clamp(0.0, 1.0) : p.y.clamp(0.0, 1.0);
      final pos = Offset(pitch.left + nx * pitch.width, pitch.top + ny * pitch.height);
      final ratio = (p.value / maxValue).clamp(.08, 1.0).toDouble();
      final color = ratio > .7 ? _AA.red : ratio > .42 ? _AA.orange : const Color(0xFFFACC15);
      final radius = 12 + 24 * ratio;
      canvas.drawCircle(pos, radius, Paint()..shader = RadialGradient(colors: [color.withOpacity(.22), color.withOpacity(.08), Colors.transparent]).createShader(Rect.fromCircle(center: pos, radius: radius)));
    }
  }

  @override
  bool shouldRepaint(covariant _MiniPitchActivityPainter oldDelegate) => oldDelegate.points != points;
}

class _ReportDialogShell extends StatelessWidget {
  const _ReportDialogShell({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      constraints: BoxConstraints(maxWidth: 760, maxHeight: size.height * .84),
      decoration: BoxDecoration(color: _AA.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _AA.border)),
      child: Column(children: [
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(color: _AA.card, borderRadius: BorderRadius.vertical(top: Radius.circular(18)), border: Border(bottom: BorderSide(color: _AA.border))),
          child: Row(children: [
            const Icon(Icons.description_rounded, color: _AA.green),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(color: _AA.text, fontSize: 17, fontWeight: FontWeight.w900))),
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: _AA.text)),
          ]),
        ),
        Expanded(child: child),
      ]),
    );
  }
}

class _SessionReportView extends StatelessWidget {
  const _SessionReportView({required this.session, required this.player, required this.summary, required this.pointsCount});
  final TrackerSessionModel session;
  final TrackerPlayerOption? player;
  final TrackerSessionSummaryModel summary;
  final int pointsCount;
  @override
  Widget build(BuildContext context) {
    final rows = [
      _MetricData(Icons.route_rounded, 'Дистанция', _meters(summary.distanceM)),
      _MetricData(Icons.speed_rounded, 'Средняя скорость', '${summary.avgSpeedKmh.toStringAsFixed(1)} км/ч'),
      _MetricData(Icons.trending_up_rounded, 'Макс. скорость', '${summary.maxSpeedKmh.toStringAsFixed(1)} км/ч'),
      _MetricData(Icons.flash_on_rounded, 'Дист. спринта', _meters(summary.sprintDistanceM)),
      _MetricData(Icons.local_fire_department_rounded, 'HIR/VHIR', _meters(summary.hirDistanceM + summary.vhirDistanceM)),
      _MetricData(Icons.directions_run_rounded, 'Спринты', '${summary.sprintCount}'),
      _MetricData(Icons.keyboard_double_arrow_up_rounded, 'Ускорения', '${summary.accelerationCount}'),
      _MetricData(Icons.keyboard_double_arrow_down_rounded, 'Торможения', '${summary.decelerationCount}'),
      _MetricData(Icons.bolt_rounded, 'Нагрузка', summary.loadScore.toStringAsFixed(0)),
    ];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(session.title, style: const TextStyle(color: _AA.text, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${player?.name ?? 'Вся команда'} · ${session.createdAt} · точек: $pointsCount', style: const TextStyle(color: _AA.muted, fontSize: 12, fontWeight: FontWeight.w800)),
        ])),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisExtent: 70, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemBuilder: (context, i) => _MetricTile(data: rows[i]),
        ),
      ],
    );
  }
}

String _meters(double value) {
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)} км';
  return '${value.toStringAsFixed(0)} м';
}

String _initials(String text) {
  final parts = text.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'ST';
  if (parts.length == 1) return parts.first.substring(0, math.min(2, parts.first.length)).toUpperCase();
  return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}

String? _normalizeActivityAvatarUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty || value == 'null') return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final cleaned = value.startsWith('/') ? value.substring(1) : value;
  return 'https://sportotekaapp.ru/$cleaned';
}
