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
  late Future<_ActivityBundle> _future;
  TrackerPlayerOption? _selectedPlayer;

  @override
  void initState() {
    super.initState();
    _api = TrackerProApi();
    _selectedPlayer = widget.selectedPlayer ?? (widget.rosterPlayers.isNotEmpty ? widget.rosterPlayers.first : null);
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant TrackerPlayerActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPlayer?.id != widget.selectedPlayer?.id) {
      _selectedPlayer = widget.selectedPlayer ?? (widget.rosterPlayers.isNotEmpty ? widget.rosterPlayers.first : null);
    }
    if (oldWidget.teamId != widget.teamId ||
        oldWidget.selectedPlayer?.id != widget.selectedPlayer?.id ||
        oldWidget.fieldId != widget.fieldId ||
        oldWidget.rosterPlayers.length != widget.rosterPlayers.length) {
      _future = _load();
    }
  }

  Future<_ActivityBundle> _load() async {
    final result = await Future.wait<dynamic>([
      _api.loadDashboard(teamId: widget.teamId),
      _api.loadSessions(teamId: widget.teamId, playerId: _selectedPlayer?.id),
      _api.loadHeatmap(teamId: widget.teamId, playerId: _selectedPlayer?.id, sessionId: null, fieldId: widget.fieldId),
    ]);

    return _ActivityBundle(
      dashboard: result[0] as TrackerDashboardModel,
      sessions: result[1] as List<TrackerSessionModel>,
      heatmap: result[2] as List<TrackerHeatPoint>,
    );
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  void _selectPlayer(TrackerPlayerOption? player) {
    setState(() {
      _selectedPlayer = player;
      _future = _load();
    });
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
    final selected = _selectedPlayer;
    if (selected != null && selected.id > 0 && !byId.containsKey(selected.id)) {
      byId[selected.id] = selected;
    }
    final result = byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ActivityBundle>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ActivityError(error: '${snapshot.error}', onRetry: _refresh);
        }

        final bundle = snapshot.data ?? const _ActivityBundle.empty();
        final stats = _resolveStats(bundle.dashboard, bundle.sessions);
        final speedPoints = _buildSpeedPoints(stats, bundle.sessions);
        final radar = _buildRadar(stats);

        return _ActivityPage(
          title: 'Активность игрока',
          subtitle: '${stats.playerName} · ${widget.teamName}',
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final players = _playersForSelector(bundle.dashboard);
              final compact = constraints.maxWidth < 920;

              if (!compact) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth >= 1280 ? 318 : 286,
                      child: _PlayerActivitySidebar(
                        players: players,
                        dashboard: bundle.dashboard,
                        selectedPlayer: _selectedPlayer,
                        stats: stats,
                        onChanged: _selectPlayer,
                      ),
                    ),
                    Container(width: 1, color: _AA.border.withOpacity(.75)),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, right) {
                          final speedHeight = right.maxHeight < 620 ? 176.0 : 218.0;
                          final kpiHeight = 92.0;
                          final profileMinHeight = right.maxHeight - speedHeight - kpiHeight - 16;

                          if (profileMinHeight < 170) {
                            return ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                SizedBox(height: 250, child: _RadarAndFieldCard(radar: radar, heatmap: bundle.heatmap)),
                                const SizedBox(height: 8),
                                SizedBox(height: 190, child: _SpeedChartCard(points: speedPoints, maxSpeed: stats.maxSpeedKmh)),
                                const SizedBox(height: 8),
                                SizedBox(height: kpiHeight, child: _StatsGrid(stats: stats, compact: false)),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Expanded(
                                child: _RadarAndFieldCard(radar: radar, heatmap: bundle.heatmap),
                              ),
                              Container(height: 1, color: _AA.border.withOpacity(.75)),
                              SizedBox(
                                height: speedHeight,
                                child: _SpeedChartCard(points: speedPoints, maxSpeed: stats.maxSpeedKmh),
                              ),
                              Container(height: 1, color: _AA.border.withOpacity(.75)),
                              SizedBox(
                                height: kpiHeight,
                                child: _StatsGrid(stats: stats, compact: false),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              }

              final selector = _PlayerSelectorBar(
                players: players,
                selectedPlayer: _selectedPlayer,
                onChanged: _selectPlayer,
              );

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  selector,
                  Container(height: 1, color: _AA.border.withOpacity(.75)),
                  SizedBox(height: 286, child: _RadarAndFieldCard(radar: radar, heatmap: bundle.heatmap)),
                  Container(height: 1, color: _AA.border.withOpacity(.75)),
                  SizedBox(height: 208, child: _SpeedChartCard(points: speedPoints, maxSpeed: stats.maxSpeedKmh)),
                  Container(height: 1, color: _AA.border.withOpacity(.75)),
                  SizedBox(height: 92, child: _StatsGrid(stats: stats, compact: true)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  _ActivityStats _resolveStats(TrackerDashboardModel dashboard, List<TrackerSessionModel> sessions) {
    final selectedId = _selectedPlayer?.id;
    TrackerPlayerLoadRow? row;
    if (selectedId != null) {
      final matches = dashboard.players.where((p) => p.playerId == selectedId).toList(growable: false);
      if (matches.isNotEmpty) row = matches.first;
    }
    if (row != null) {
      final hir = row.highSpeedDistanceM;
      final sprint = row.sprintDistanceM;
      return _ActivityStats(
        playerName: row.playerName,
        distanceM: row.distanceM,
        sprintDistanceM: sprint,
        hirDistanceM: math.max(0, hir - sprint),
        vhirDistanceM: 0,
        avgSpeedKmh: row.avgSpeedKmh,
        maxSpeedKmh: row.maxSpeedKmh,
        sprintCount: row.sprintCount,
        accelerationCount: row.accelerationCount,
        decelerationCount: row.decelerationCount,
        loadScore: row.loadScore,
      );
    }

    final selectedIdForSessions = _selectedPlayer?.id;
    final selectedSessions = sessions.where((s) => selectedIdForSessions == null || s.playerId == null || s.playerId == selectedIdForSessions).toList(growable: false);
    if (selectedSessions.isNotEmpty) {
      final distance = selectedSessions.fold<double>(0, (sum, s) => sum + s.distanceM);
      final maxSpeed = selectedSessions.fold<double>(0, (m, s) => math.max(m, s.maxSpeedKmh));
      final sprintCount = selectedSessions.fold<int>(0, (sum, s) => sum + s.sprintCount);
      final load = selectedSessions.fold<double>(0, (sum, s) => sum + s.loadScore);
      final avgSpeed = selectedSessions.where((s) => s.maxSpeedKmh > 0).isEmpty
          ? 0.0
          : selectedSessions.where((s) => s.maxSpeedKmh > 0).fold<double>(0, (sum, s) => sum + s.maxSpeedKmh) / selectedSessions.where((s) => s.maxSpeedKmh > 0).length;
      return _ActivityStats(
        playerName: _selectedPlayer?.name ?? selectedSessions.first.playerName ?? 'Игрок',
        distanceM: distance,
        sprintDistanceM: distance * .08,
        hirDistanceM: distance * .14,
        vhirDistanceM: distance * .04,
        avgSpeedKmh: avgSpeed,
        maxSpeedKmh: maxSpeed,
        sprintCount: sprintCount,
        accelerationCount: sprintCount * 3,
        decelerationCount: sprintCount * 3,
        loadScore: load,
      );
    }

    final s = dashboard.summary;
    final playerName = _selectedPlayer?.name ?? 'Команда';
    return _ActivityStats(
      playerName: playerName,
      distanceM: _d(s['distance_m'] ?? s['total_distance_m']),
      sprintDistanceM: _d(s['sprint_distance_m']),
      hirDistanceM: _d(s['hir_distance_m'] ?? s['hsr_distance_m'] ?? s['high_speed_distance_m']),
      vhirDistanceM: _d(s['vhir_distance_m'] ?? s['very_high_speed_distance_m']),
      avgSpeedKmh: _d(s['avg_speed_kmh'] ?? s['average_speed_kmh']),
      maxSpeedKmh: _d(s['max_speed_kmh']),
      sprintCount: _i(s['sprint_count']),
      accelerationCount: _i(s['acceleration_count'] ?? s['accel_count']),
      decelerationCount: _i(s['deceleration_count'] ?? s['decel_count']),
      loadScore: _d(s['load_score']),
    );
  }

  List<_SpeedPoint> _buildSpeedPoints(_ActivityStats stats, List<TrackerSessionModel> sessions) {
    final selectedId = _selectedPlayer?.id;
    final filtered = sessions.where((s) => selectedId == null || s.playerId == null || s.playerId == selectedId).toList(growable: false);

    if (filtered.length >= 2) {
      return List<_SpeedPoint>.generate(
        filtered.length,
        (i) => _SpeedPoint(i.toDouble(), filtered[i].maxSpeedKmh.clamp(0, 44).toDouble()),
      );
    }

    final avg = stats.avgSpeedKmh <= 0 ? math.min(stats.maxSpeedKmh * .36, 8.0) : stats.avgSpeedKmh;
    final max = stats.maxSpeedKmh <= 0 ? math.max(avg, 4.0) : stats.maxSpeedKmh;
    final count = math.max(18, math.min(56, stats.sprintCount + 18));
    return List<_SpeedPoint>.generate(count, (i) {
      final t = i.toDouble();
      final wave = math.sin(i * .72).abs() * 1.4;
      final spikeEvery = math.max(6, count ~/ math.max(1, stats.sprintCount == 0 ? 2 : stats.sprintCount));
      final spike = (stats.sprintCount > 0 && i % spikeEvery == 0) ? max * .54 : 0.0;
      final value = (avg * .78 + wave + spike).clamp(0.0, max.clamp(4.0, 44.0).toDouble());
      return _SpeedPoint(t, value);
    });
  }

  List<_RadarAxis> _buildRadar(_ActivityStats stats) {
    double clamp(double v) => v.clamp(.05, 1.0).toDouble();
    return [
      _RadarAxis('Скорость', clamp(stats.maxSpeedKmh / 34.0)),
      _RadarAxis('Выносливость', clamp(stats.distanceM / 11000.0)),
      _RadarAxis('Атака', clamp((stats.sprintDistanceM / 700.0 + stats.sprintCount / 38.0) / 2.0)),
      _RadarAxis('Оборона', clamp(stats.decelerationCount / 90.0)),
      _RadarAxis('Манёвренность', clamp((stats.accelerationCount + stats.decelerationCount) / 160.0)),
      _RadarAxis('Активность', clamp((stats.hirDistanceM + stats.vhirDistanceM + stats.sprintDistanceM) / 1800.0)),
    ];
  }

  static double _d(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static int _i(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }
}

class _ActivityBundle {
  const _ActivityBundle({required this.dashboard, required this.sessions, required this.heatmap});
  const _ActivityBundle.empty()
      : dashboard = const TrackerDashboardModel(summary: <String, dynamic>{}, players: <TrackerPlayerLoadRow>[], alerts: <Map<String, dynamic>>[]),
        sessions = const <TrackerSessionModel>[],
        heatmap = const <TrackerHeatPoint>[];

  final TrackerDashboardModel dashboard;
  final List<TrackerSessionModel> sessions;
  final List<TrackerHeatPoint> heatmap;
}

class _ActivityStats {
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
  });

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
}

class _SpeedPoint {
  const _SpeedPoint(this.x, this.speedKmh);
  final double x;
  final double speedKmh;
}

class _RadarAxis {
  const _RadarAxis(this.label, this.value);
  final String label;
  final double value;
}

class _AA {
  static const bg = Color(0xFFF4F5F6);
  static const card = Color(0xFFFFFFFF);
  static const card2 = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF475467);
  static const dim = Color(0xFF667085);
  static const green = Color(0xFF00A750);
  static const yellow = Color(0xFFFACC15);
  static const orange = Color(0xFFF97316);
  static const red = Color(0xFFE11D48);
}

class _ActivityPage extends StatelessWidget {
  const _ActivityPage({required this.title, required this.subtitle, required this.child, required this.onRefresh});

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: child,
    );
  }
}


class _PlayerActivitySidebar extends StatelessWidget {
  const _PlayerActivitySidebar({
    required this.players,
    required this.dashboard,
    required this.selectedPlayer,
    required this.stats,
    required this.onChanged,
  });

  final List<TrackerPlayerOption> players;
  final TrackerDashboardModel dashboard;
  final TrackerPlayerOption? selectedPlayer;
  final _ActivityStats stats;
  final ValueChanged<TrackerPlayerOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedId = selectedPlayer?.id;

    return _ActivityCard(
      title: 'Игроки',
      subtitle: players.isEmpty ? 'состав не загружен' : '${players.length} в составе',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: _PlayerListTile(
              title: 'Вся команда',
              subtitle: 'суммарная активность',
              avatarUrl: null,
              initials: 'К',
              icon: Icons.groups_rounded,
              active: selectedId == null,
              value: _formatMeters(stats.distanceM),
              onTap: () => onChanged(null),
            ),
          ),
          Container(height: 1, color: _AA.border.withOpacity(.75)),
          Expanded(
            child: players.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Игроки появятся здесь после загрузки состава команды.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _AA.muted, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: players.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final p = players[index];
                      final row = _rowForPlayer(p.id);
                      final distance = row == null ? '—' : _formatMeters(row.distanceM);
                      final speed = row == null || row.maxSpeedKmh <= 0 ? 'нет сессий' : '${row.maxSpeedKmh.toStringAsFixed(1)} км/ч макс.';
                      return _PlayerListTile(
                        title: p.name,
                        subtitle: [if (p.number != null) '#${p.number}', if (p.position != null) p.position, speed].join(' · '),
                        avatarUrl: p.avatar ?? row?.avatar,
                        initials: _activityInitials(p.name),
                        active: selectedId == p.id,
                        value: distance,
                        onTap: () => onChanged(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  TrackerPlayerLoadRow? _rowForPlayer(int id) {
    final matches = dashboard.players.where((r) => r.playerId == id).toList(growable: false);
    return matches.isEmpty ? null : matches.first;
  }

  static String _formatMeters(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} км';
    if (value <= 0) return '—';
    return '${value.toStringAsFixed(0)} м';
  }
}

class _PlayerListTile extends StatelessWidget {
  const _PlayerListTile({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.initials,
    required this.active,
    required this.value,
    required this.onTap,
    this.icon,
  });

  final String title;
  final String subtitle;
  final String? avatarUrl;
  final String initials;
  final bool active;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _AA.green.withOpacity(.10) : _AA.card2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? _AA.green.withOpacity(.55) : _AA.border.withOpacity(.85)),
          ),
          child: Row(
            children: [
              _ActivityAvatar(
                url: avatarUrl,
                initials: initials,
                icon: icon,
                size: 42,
                active: active,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _AA.text, fontSize: 12.6, fontWeight: FontWeight.w500, letterSpacing: -.15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle.isEmpty ? 'активность игрока' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? _AA.green : _AA.text,
                      fontSize: 12.4,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Icon(Icons.chevron_right_rounded, color: active ? _AA.green : _AA.dim, size: 17),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityAvatar extends StatelessWidget {
  const _ActivityAvatar({
    required this.url,
    required this.initials,
    required this.size,
    required this.active,
    this.icon,
  });

  final String? url;
  final String initials;
  final double size;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _normalizeActivityAvatarUrl(url);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: active ? _AA.green : _AA.border, width: active ? 2 : 1),
      ),
      child: ClipOval(
        child: imageUrl == null
            ? _ActivityAvatarFallback(initials: initials, size: size, icon: icon)
            : Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ActivityAvatarFallback(initials: initials, size: size, icon: icon),
              ),
      ),
    );
  }
}

class _ActivityAvatarFallback extends StatelessWidget {
  const _ActivityAvatarFallback({required this.initials, required this.size, this.icon});

  final String initials;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: _AA.green.withOpacity(.10),
      child: icon != null
          ? Icon(icon, color: _AA.green, size: size * .45)
          : Text(
              initials,
              style: TextStyle(color: _AA.text, fontSize: size * .30, fontWeight: FontWeight.w500),
            ),
    );
  }
}

class _PlayerSelectorBar extends StatelessWidget {
  const _PlayerSelectorBar({
    required this.players,
    required this.selectedPlayer,
    required this.onChanged,
  });

  final List<TrackerPlayerOption> players;
  final TrackerPlayerOption? selectedPlayer;
  final ValueChanged<TrackerPlayerOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedId = selectedPlayer?.id;
    final hasSelected = selectedId != null && players.any((p) => p.id == selectedId);

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _AA.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _AA.border.withOpacity(.95)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: _AA.green.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person_search_rounded, color: _AA.green, size: 19),
          ),
          Container(width: 1, color: _AA.border.withOpacity(.75)),
          const Text('Игрок', style: TextStyle(color: _AA.text, fontSize: 12.5, fontWeight: FontWeight.w500)),
          Container(width: 1, color: _AA.border.withOpacity(.75)),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: hasSelected ? selectedId : null,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _AA.green),
                dropdownColor: _AA.card,
                style: const TextStyle(color: _AA.text, fontSize: 12.2, fontWeight: FontWeight.w500),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Вся команда')),
                  ...players.map((p) => DropdownMenuItem<int?>(
                        value: p.id,
                        child: Text(
                          [if (p.number != null) '#${p.number}', p.name, if (p.position != null) '· ${p.position}'].join(' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (id) {
                  if (id == null) {
                    onChanged(null);
                    return;
                  }
                  final matches = players.where((p) => p.id == id).toList(growable: false);
                  onChanged(matches.isEmpty ? null : matches.first);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _activityInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'И';
  if (parts.length == 1) {
    final s = parts.first;
    return s.length <= 2 ? s.toUpperCase() : s.substring(0, 2).toUpperCase();
  }
  return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}

String? _normalizeActivityAvatarUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty || value == 'null') return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final cleaned = value.startsWith('/') ? value.substring(1) : value;
  return 'https://sportotekaapp.ru/$cleaned';
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
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: Colors.transparent, border: Border(bottom: BorderSide(color: _AA.border.withOpacity(.85)))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 12.8, fontWeight: FontWeight.w500)),
                      if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.5, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SpeedChartCard extends StatelessWidget {
  const _SpeedChartCard({required this.points, required this.maxSpeed});

  final List<_SpeedPoint> points;
  final double maxSpeed;

  @override
  Widget build(BuildContext context) {
    return _ActivityCard(
      title: 'График скорости',
      subtitle: 'скорость по сессиям / онлайн-профиль',
      trailing: Text('${maxSpeed.toStringAsFixed(1)} км/ч макс.', style: const TextStyle(color: _AA.green, fontSize: 11, fontWeight: FontWeight.w500)),
      child: CustomPaint(
        painter: _SpeedDiagramPainter(points: points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RadarAndFieldCard extends StatelessWidget {
  const _RadarAndFieldCard({required this.radar, required this.heatmap});

  final List<_RadarAxis> radar;
  final List<TrackerHeatPoint> heatmap;

  @override
  Widget build(BuildContext context) {
    return _ActivityCard(
      title: 'Профиль активности',
      subtitle: 'радар активности + мини-теплокарта',
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 420;
          if (narrow) {
            return Column(
              children: [
                Expanded(child: CustomPaint(painter: _RadarActivityPainter(axes: radar), child: const SizedBox.expand())),
                SizedBox(height: 132, child: CustomPaint(painter: _MiniPitchActivityPainter(points: heatmap), child: const SizedBox.expand())),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 6, child: CustomPaint(painter: _RadarActivityPainter(axes: radar), child: const SizedBox.expand())),
              Container(width: 1, color: _AA.border.withOpacity(.7)),
              Expanded(flex: 5, child: CustomPaint(painter: _MiniPitchActivityPainter(points: heatmap), child: const SizedBox.expand())),
            ],
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.compact});

  final _ActivityStats stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricData(Icons.route_rounded, 'Дистанция', _meters(stats.distanceM), 'общая дистанция'),
      _MetricData(Icons.flash_on_rounded, 'Дист. спринта', _meters(stats.sprintDistanceM), 'дистанция спринта'),
      _MetricData(Icons.local_fire_department_rounded, 'HIR/VHIR', _meters(stats.hirDistanceM + stats.vhirDistanceM), 'высокая интенсивность'),
      _MetricData(Icons.speed_rounded, 'Средняя скорость', '${stats.avgSpeedKmh.toStringAsFixed(1)} км/ч', 'средняя скорость'),
      _MetricData(Icons.trending_up_rounded, 'Макс. скорость', '${stats.maxSpeedKmh.toStringAsFixed(1)} км/ч', 'максимум'),
      _MetricData(Icons.directions_run_rounded, 'Спринты', '${stats.sprintCount}', 'кол-во спринтов'),
      _MetricData(Icons.keyboard_double_arrow_up_rounded, 'Ускорения', '${stats.accelerationCount}', 'ускорения'),
      _MetricData(Icons.keyboard_double_arrow_down_rounded, 'Торможения', '${stats.decelerationCount}', 'торможения'),
      _MetricData(Icons.bolt_rounded, 'Нагрузка', stats.loadScore.toStringAsFixed(0), 'нагрузка'),
    ];

    return _ActivityCard(
      title: 'Онлайн обзор KPI',
      subtitle: 'маленькие показатели по выбранному игроку',
      trailing: TextButton.icon(
        onPressed: () => _showExpandedKpi(context, cards),
        style: TextButton.styleFrom(
          foregroundColor: _AA.green,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 30),
        ),
        icon: const Icon(Icons.open_in_full_rounded, size: 14),
        label: const Text('Развернуть', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            child: Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  SizedBox(width: compact ? 154 : 166, height: compact ? 54 : 50, child: _MetricTile(data: cards[i])),
                  if (i != cards.length - 1) const SizedBox(width: 7),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static void _showExpandedKpi(BuildContext context, List<_MetricData> cards) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.28),
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final narrow = size.width < 720;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: narrow ? 10 : 36, vertical: narrow ? 16 : 36),
          child: Container(
            constraints: BoxConstraints(maxWidth: narrow ? size.width : 760, maxHeight: size.height * .82),
            decoration: BoxDecoration(
              color: _AA.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _AA.border.withOpacity(.95)),
            ),
            child: Column(
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: _AA.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), border: Border(bottom: BorderSide(color: _AA.border.withOpacity(.9)))),
                  child: Row(
                    children: [
                      const Icon(Icons.dashboard_rounded, color: _AA.green, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Онлайн обзор KPI', style: TextStyle(color: _AA.text, fontSize: 15, fontWeight: FontWeight.w500))),
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: _AA.text)),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: cards.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: narrow ? 210 : 240,
                      mainAxisExtent: 82,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (context, i) => _MetricTile(data: cards[i], expanded: true),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _meters(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)} км';
    return '${value.toStringAsFixed(0)} м';
  }
}

class _MetricData {
  const _MetricData(this.icon, this.title, this.value, this.subtitle);
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data, this.expanded = false});

  final _MetricData data;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final iconSize = expanded ? 34.0 : 28.0;
    final valueSize = expanded ? 18.0 : 14.0;
    final titleSize = expanded ? 11.2 : 9.3;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 7, vertical: expanded ? 9 : 5),
      decoration: BoxDecoration(
        color: _AA.card2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _AA.border.withOpacity(.9)),
      ),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: _AA.green.withOpacity(.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(data.icon, color: _AA.green, size: expanded ? 18 : 16),
          ),
          SizedBox(width: expanded ? 10 : 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AA.text,
                    fontSize: valueSize,
                    height: 1.0,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -.25,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AA.muted,
                    fontSize: titleSize,
                    height: 1.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _AA.dim,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniPitchActivityPainter extends CustomPainter {
  const _MiniPitchActivityPainter({required this.points});

  final List<TrackerHeatPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(14);
    final pitch = _fitPitch(rect);
    _drawPitch(canvas, pitch);

    if (points.isEmpty) {
      _drawCentered(canvas, pitch.center, 'Нет теплокарты', const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500, shadows: [Shadow(color: Colors.black45, blurRadius: 6)]));
      return;
    }

    final maxValue = points.fold<double>(1, (m, p) => math.max(m, p.value));
    for (final p in points) {
      final nx = _normalX(p);
      final ny = _normalY(p);
      final pos = Offset(pitch.left + nx * pitch.width, pitch.top + ny * pitch.height);
      final ratio = (p.value / maxValue).clamp(.08, 1.0).toDouble();
      final color = _heatColor(ratio);
      final radius = 10 + 24 * ratio;
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withOpacity(.24), color.withOpacity(.10), Colors.transparent],
            stops: const [0, .48, 1],
          ).createShader(Rect.fromCircle(center: pos, radius: radius)),
      );
    }
  }

  Rect _fitPitch(Rect area) {
    const aspect = 105 / 68;
    var w = area.width;
    var h = w / aspect;
    if (h > area.height) {
      h = area.height;
      w = h * aspect;
    }
    return Rect.fromCenter(center: area.center, width: w, height: h);
  }

  void _drawPitch(Canvas canvas, Rect pitch) {
    final r = RRect.fromRectAndRadius(pitch, const Radius.circular(10));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF0B7A38));
    for (var i = 0; i < 10; i++) {
      canvas.drawRect(
        Rect.fromLTWH(pitch.left + pitch.width * i / 10, pitch.top, pitch.width / 10, pitch.height),
        Paint()..color = i.isEven ? Colors.white.withOpacity(.035) : Colors.black.withOpacity(.035),
      );
    }
    final inner = pitch.deflate(10);
    final line = Paint()
      ..color = Colors.white.withOpacity(.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(inner, line);
    canvas.drawLine(Offset(inner.center.dx, inner.top), Offset(inner.center.dx, inner.bottom), line);
    canvas.drawCircle(inner.center, inner.width * .085, line);
    canvas.drawRect(Rect.fromLTWH(inner.left, inner.center.dy - inner.height * .22, inner.width * .16, inner.height * .44), line);
    canvas.drawRect(Rect.fromLTWH(inner.right - inner.width * .16, inner.center.dy - inner.height * .22, inner.width * .16, inner.height * .44), line);
  }

  double _normalX(TrackerHeatPoint p) {
    if (p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1) return p.x.clamp(0.0, 1.0).toDouble();
    return (p.x / 105.0).clamp(0.0, 1.0).toDouble();
  }

  double _normalY(TrackerHeatPoint p) {
    if (p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1) return p.y.clamp(0.0, 1.0).toDouble();
    return (p.y / 68.0).clamp(0.0, 1.0).toDouble();
  }

  Color _heatColor(double ratio) {
    if (ratio > .80) return _AA.red;
    if (ratio > .55) return _AA.orange;
    if (ratio > .30) return _AA.yellow;
    return _AA.green;
  }

  void _drawCentered(Canvas canvas, Offset center, String text, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout(maxWidth: 140);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MiniPitchActivityPainter oldDelegate) => oldDelegate.points != points;
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _AA.green,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _AA.border)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _AA.red, size: 36),
            const SizedBox(height: 10),
            const Text('Не удалось загрузить активность', style: TextStyle(color: _AA.text, fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: _AA.muted, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            _MiniButton(icon: Icons.refresh_rounded, label: 'Повторить', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _SpeedDiagramPainter extends CustomPainter {
  const _SpeedDiagramPainter({required this.points});

  final List<_SpeedPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final area = (Offset.zero & size).deflate(18);
    final labelStyle = const TextStyle(color: _AA.dim, fontSize: 10, fontWeight: FontWeight.w500);
    final grid = Paint()
      ..color = _AA.border.withOpacity(.9)
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = _AA.dim.withOpacity(.45)
      ..strokeWidth = 1.2;

    final chart = Rect.fromLTWH(area.left + 30, area.top + 8, area.width - 38, area.height - 34);
    for (var i = 0; i <= 5; i++) {
      final y = chart.bottom - chart.height * i / 5;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _drawText(canvas, '${(i * 8)}', Offset(area.left, y - 7), labelStyle);
    }

    canvas.drawLine(Offset(chart.left, chart.top), Offset(chart.left, chart.bottom), axis);
    canvas.drawLine(Offset(chart.left, chart.bottom), Offset(chart.right, chart.bottom), axis);
    _drawText(canvas, 'км/ч', Offset(area.left + 2, area.top), labelStyle);

    if (points.isEmpty) {
      _drawText(canvas, 'Нет данных скорости', chart.center - const Offset(58, 8), const TextStyle(color: _AA.muted, fontSize: 12.5, fontWeight: FontWeight.w500));
      return;
    }

    final maxX = math.max(1.0, points.last.x - points.first.x);
    final maxY = math.max(40.0, points.map((p) => p.speedKmh).fold<double>(0, (a, b) => math.max(a, b)) * 1.15);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = chart.left + ((p.x - points.first.x) / maxX).clamp(0.0, 1.0) * chart.width;
      final y = chart.bottom - (p.speedKmh / maxY).clamp(0.0, 1.0) * chart.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_AA.green.withOpacity(.20), _AA.green.withOpacity(.02)],
        ).createShader(chart),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _AA.green
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SpeedDiagramPainter oldDelegate) => oldDelegate.points != points;
}

class _RadarActivityPainter extends CustomPainter {
  const _RadarActivityPainter({required this.axes});

  final List<_RadarAxis> axes;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 4);
    final radius = math.min(size.width, size.height) * .34;
    if (axes.isEmpty || radius <= 0) return;

    final gridPaint = Paint()
      ..color = _AA.border.withOpacity(.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = _AA.dim.withOpacity(.30)
      ..strokeWidth = 1;

    for (var r = 1; r <= 4; r++) {
      final path = Path();
      final rr = radius * r / 4;
      for (var i = 0; i < axes.length; i++) {
        final a = -math.pi / 2 + 2 * math.pi * i / axes.length;
        final p = center + Offset(math.cos(a), math.sin(a)) * rr;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    final valuePath = Path();
    for (var i = 0; i < axes.length; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / axes.length;
      final edge = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawLine(center, edge, axisPaint);

      final value = axes[i].value.clamp(0.0, 1.0).toDouble();
      final p = center + Offset(math.cos(a), math.sin(a)) * radius * value;
      if (i == 0) {
        valuePath.moveTo(p.dx, p.dy);
      } else {
        valuePath.lineTo(p.dx, p.dy);
      }

      final labelPos = center + Offset(math.cos(a), math.sin(a)) * (radius + 24);
      _drawCenteredText(canvas, axes[i].label, labelPos, const TextStyle(color: _AA.muted, fontSize: 10, fontWeight: FontWeight.w500));
    }
    valuePath.close();

    canvas.drawPath(
      valuePath,
      Paint()
        ..color = _AA.green.withOpacity(.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      valuePath,
      Paint()
        ..color = _AA.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawCircle(center, 4, Paint()..color = _AA.green);
  }

  void _drawCenteredText(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(maxWidth: 70);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RadarActivityPainter oldDelegate) => oldDelegate.axes != axes;
}

