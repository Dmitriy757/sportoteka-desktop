import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/tracker_pro_models.dart';

class TrackerProAnalyticsPanel extends StatelessWidget {
  const TrackerProAnalyticsPanel({
    super.key,
    required this.loading,
    required this.error,
    required this.dashboard,
    this.rosterPlayers = const [],
    required this.selectedPlayer,
    required this.onRetry,
    required this.onSelectPlayer,
  });

  final bool loading;
  final String? error;
  final TrackerDashboardModel? dashboard;
  final List<TrackerPlayerOption> rosterPlayers;
  final TrackerPlayerOption? selectedPlayer;
  final VoidCallback onRetry;
  final ValueChanged<int> onSelectPlayer;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return _DarkError(error: error!, onRetry: onRetry);

    final data = dashboard ?? const TrackerDashboardModel(summary: <String, dynamic>{}, players: <TrackerPlayerLoadRow>[], alerts: <Map<String, dynamic>>[]);
    final players = data.players;
    final summary = data.summary;
    final alerts = data.alerts;

    return _DarkPage(
      title: 'Расширенная аналитика трекинга',
      subtitle: 'Общая дистанция, нагрузка игрока, HIR/VHIR, метаболическая мощность, профиль футбольных движений',
      icon: Icons.analytics_rounded,
      trailing: _DarkActionButton(icon: Icons.refresh_rounded, label: 'Обновить', onTap: onRetry),
      child: Column(
        children: [
          SizedBox(
            height: 132,
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.62,
              children: [
                _GaugeCard(title: 'Игроки', value: '${players.length}', subtitle: 'состав', icon: Icons.groups_rounded, progress: players.isEmpty ? 0 : .78),
                _GaugeCard(title: 'Дистанция', value: _meters(summary['distance_m']), subtitle: 'общий объём', icon: Icons.route_rounded, progress: .55),
                _GaugeCard(title: 'Нагрузка', value: '${summary['load_score'] ?? 0}', subtitle: 'Оценка нагрузки', icon: Icons.bolt_rounded, progress: .62),
                _GaugeCard(title: 'Макс. скорость', value: '${summary['max_speed_kmh'] ?? 0}', subtitle: 'km/h', icon: Icons.speed_rounded, progress: .74),
                _GaugeCard(title: 'HIR/VHIR', value: _meters(summary['hir_distance_m'] ?? summary['hsr_distance_m']), subtitle: 'высокая интенсивность', icon: Icons.local_fire_department_rounded, progress: .48),
                _GaugeCard(title: 'Спринты', value: '${summary['sprint_count'] ?? 0}', subtitle: 'действия', icon: Icons.flash_on_rounded, progress: .36),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 8,
                  child: _DarkCard(
                    title: 'Матрица показателей команды',
                    subtitle: 'таблица показателей',
                    child: players.isEmpty
                        ? const _Empty(icon: Icons.table_chart_rounded, text: 'Пока нет обработанных данных по игрокам.')
                        : _PerformanceMatrix(
                            players: players,
                            rosterPlayers: rosterPlayers,
                            selectedPlayerId: selectedPlayer?.id,
                            onSelectPlayer: onSelectPlayer,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(child: _DarkCard(title: 'Профиль футбольных движений', subtitle: 'двигательная нагрузка', child: _FmpSummary(players: players))),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _DarkCard(
                          title: 'Оповещения / риск',
                          subtitle: '${alerts.length} событий',
                          child: alerts.isEmpty
                              ? const _Empty(icon: Icons.verified_rounded, text: 'Критичных событий пока нет.')
                              : ListView(children: alerts.map((a) => _AlertRow(title: '${a['title'] ?? a['message'] ?? 'Alert'}', subtitle: '${a['player_name'] ?? a['created_at'] ?? ''}')).toList()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _meters(dynamic value) {
    final m = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(2)} km';
    return '${m.toStringAsFixed(0)} m';
  }
}

class _AD {
  static const bg = Color(0xFFFFFFFF);
  static const panel = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const card2 = Color(0xFFFFFFFF);
  static const border = Color(0xFFE9ECEA);
  static const grid = Color(0xFFDDE2DF);
  static const text = Color(0xFF111512);
  static const muted = Color(0xFF4F5B54);
  static const dim = Color(0xFF737B76);
  static const green = Color(0xFF00A750);
  static const yellow = Color(0xFFB7791F);
  static const orange = Color(0xFFB7791F);
  static const red = Color(0xFFD92D20);
}

class _DarkPage extends StatelessWidget {
  const _DarkPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _AD.bg,
      child: Column(
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: _AD.card,
              border: const Border(bottom: BorderSide(color: _AD.border, width: .7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _AD.card2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _AD.green, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _AD.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.25,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _AD.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _DarkCard extends StatelessWidget {
  const _DarkCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title.trim().isNotEmpty || subtitle.trim().isNotEmpty;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _AD.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x07111827), blurRadius: 18, spreadRadius: -12, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          if (hasHeader)
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(color: _AD.card),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AD.text,
                        fontSize: 12.6,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.08,
                      ),
                    ),
                  ),
                  if (subtitle.trim().isNotEmpty)
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _AD.muted,
                          fontSize: 9.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkActionButton extends StatelessWidget {
  const _DarkActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _AD.card,
      borderRadius: BorderRadius.circular(9),
      child: _NoHoverTap(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: _AD.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: _AD.text, size: 17),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: _AD.text, fontSize: 11, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.progress});
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final double progress;
  @override
  Widget build(BuildContext context) {
    final color = progress > .72 ? _AD.red : progress > .52 ? _AD.yellow : _AD.green;
    return Container(
      decoration: BoxDecoration(
        color: _AD.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x06111827), blurRadius: 16, spreadRadius: -11, offset: Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(9),
      child: Row(children: [
        SizedBox(width: 48, height: 48, child: CustomPaint(painter: _GaugePainter(progress: progress, color: color), child: Center(child: Icon(icon, color: color, size: 18)))),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AD.muted, fontSize: 9.5, fontWeight: FontWeight.w900)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AD.text, fontSize: 17, fontWeight: FontWeight.w900)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AD.dim, fontSize: 8.7, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.progress, required this.color});
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    stroke.color = _AD.grid;
    canvas.drawArc(rect.deflate(5), math.pi * .75, math.pi * 1.5, false, stroke);
    stroke.color = color;
    canvas.drawArc(rect.deflate(5), math.pi * .75, math.pi * 1.5 * progress.clamp(0, 1), false, stroke);
  }
  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => true;
}

class _PerformanceMatrix extends StatelessWidget {
  const _PerformanceMatrix({
    required this.players,
    required this.rosterPlayers,
    required this.selectedPlayerId,
    required this.onSelectPlayer,
  });

  final List<TrackerPlayerLoadRow> players;
  final List<TrackerPlayerOption> rosterPlayers;
  final int? selectedPlayerId;
  final ValueChanged<int> onSelectPlayer;

  @override
  Widget build(BuildContext context) {
    final columns = ['Общая дистанция', 'Дист./мин', 'HIR', 'VHIR', 'Acc', 'Dec', 'Макс. скорость', 'Нагрузка', 'Усталость'];
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {0: FixedColumnWidth(140)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(decoration: const BoxDecoration(color: _AD.card2), children: [_cell('Игрок', header: true), ...columns.map((c) => _cell(c, header: true))]),
          ...players.map((p) {
            final distanceKm = p.distanceM / 1000;
            final distMin = p.distanceM > 0 ? (p.distanceM / 60).clamp(0, 999) : 0;
            final selected = selectedPlayerId == p.playerId;
            return TableRow(decoration: BoxDecoration(color: selected ? _AD.green.withOpacity(.06) : Colors.transparent), children: [
              _NoHoverTap(
                onTap: p.playerId == null
                    ? null
                    : () {
                        onSelectPlayer(p.playerId!);
                      },
                child: _playerCell(p),
              ),
              _colorCell(distanceKm.toStringAsFixed(2), distanceKm / 8),
              _colorCell(distMin.toStringAsFixed(0), distMin / 110),
              _colorCell((p.highSpeedDistanceM / 1000).toStringAsFixed(2), p.highSpeedDistanceM / 600),
              _colorCell((p.sprintDistanceM / 1000).toStringAsFixed(2), p.sprintDistanceM / 400),
              _colorCell('${p.accelerationCount}', p.accelerationCount / 40),
              _colorCell('${p.decelerationCount}', p.decelerationCount / 40),
              _colorCell(p.maxSpeedKmh.toStringAsFixed(1), p.maxSpeedKmh / 32),
              _colorCell(p.loadScore.toStringAsFixed(0), p.loadScore / 500),
              _colorCell('${_fatigueIndex(p).toStringAsFixed(0)}%', _fatigueIndex(p) / 100),
            ]);
          }),
        ],
      ),
    );
  }


  Widget _playerCell(TrackerPlayerLoadRow p) {
    final avatar = _avatarFor(p);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border.all(color: _AD.border.withOpacity(.65), width: .5)),
      child: Row(
        children: [
          _PlayerAvatarDark(photo: avatar, name: p.playerName, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              p.playerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _AD.text, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  String? _avatarFor(TrackerPlayerLoadRow p) {
    if (p.avatar != null && p.avatar!.trim().isNotEmpty) return p.avatar;
    for (final item in rosterPlayers) {
      if (p.playerId != null && item.id == p.playerId) return item.avatar;
      if (item.name.trim().toLowerCase() == p.playerName.trim().toLowerCase()) return item.avatar;
    }
    return null;
  }

  double _fatigueIndex(TrackerPlayerLoadRow p) {
    final highIntensity = p.highSpeedDistanceM + p.sprintDistanceM;
    final distanceBase = p.distanceM <= 1 ? 1.0 : p.distanceM;
    final hiShare = (highIntensity / distanceBase).clamp(0.0, 1.0);
    final loadPart = (p.loadScore / 500.0).clamp(0.0, 1.0);
    final accelPart = ((p.accelerationCount + p.decelerationCount) / 80.0).clamp(0.0, 1.0);
    final speedPart = (p.maxSpeedKmh / 34.0).clamp(0.0, 1.0);
    return ((hiShare * 38) + (loadPart * 30) + (accelPart * 22) + (speedPart * 10)).clamp(0.0, 100.0).toDouble();
  }


  Widget _cell(String text, {bool header = false}) => Container(
        height: header ? 34 : 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(border: Border.all(color: _AD.border.withOpacity(.65), width: .5)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: header ? _AD.text : _AD.muted, fontSize: header ? 10 : 11, fontWeight: header ? FontWeight.w900 : FontWeight.w800)),
      );

  Widget _colorCell(String text, double ratio) {
    final r = ratio.clamp(0, 1).toDouble();
    final color = r > .72 ? _AD.red : r > .48 ? _AD.orange : _AD.green;
    return Container(
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withOpacity(.16 + r * .18), border: Border.all(color: _AD.border.withOpacity(.65), width: .5)),
      child: Text(text, style: const TextStyle(color: _AD.text, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _FmpSummary extends StatelessWidget {
  const _FmpSummary({required this.players});
  final List<TrackerPlayerLoadRow> players;
  @override
  Widget build(BuildContext context) {
    final acc = players.fold<int>(0, (s, p) => s + p.accelerationCount);
    final dec = players.fold<int>(0, (s, p) => s + p.decelerationCount);
    final sprint = players.fold<int>(0, (s, p) => s + p.sprintCount);
    final load = players.fold<double>(0, (s, p) => s + p.loadScore);
    return GridView.count(physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.1, children: [
      _MiniMetric(label: 'Ускор.', value: '$acc'),
      _MiniMetric(label: 'Торм.', value: '$dec'),
      _MiniMetric(label: 'Спринт', value: '$sprint'),
      _MiniMetric(label: 'Нагрузка', value: load.toStringAsFixed(0)),
      const _MiniMetric(label: 'Смена напр.', value: '—'),
      const _MiniMetric(label: 'Низк. ск./выс. нагр.', value: '—'),
    ]);
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: _AD.card2, borderRadius: BorderRadius.circular(9), border: Border.all(color: _AD.border)),
    padding: const EdgeInsets.all(8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: const TextStyle(color: _AD.muted, fontSize: 10, fontWeight: FontWeight.w900)),
      Text(value, style: const TextStyle(color: _AD.text, fontSize: 18, fontWeight: FontWeight.w900)),
    ]),
  );
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(9), border: Border.all(color: Color(0xFFF7C8C4))),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: _AD.red),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AD.text, fontWeight: FontWeight.w900)),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AD.muted, fontSize: 10, fontWeight: FontWeight.w800)),
      ])),
    ]),
  );
}


class _PlayerAvatarDark extends StatelessWidget {
  const _PlayerAvatarDark({required this.photo, required this.name, required this.size});

  final String? photo;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = _absolutePhotoUrl(photo);
    final initials = _initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _AD.green.withOpacity(.11),
        shape: BoxShape.circle,
        border: Border.all(color: _AD.green.withOpacity(.36), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Center(
              child: Text(
                initials,
                style: TextStyle(color: _AD.green, fontSize: size * .29, fontWeight: FontWeight.w900),
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initials,
                  style: TextStyle(color: _AD.green, fontSize: size * .29, fontWeight: FontWeight.w900),
                ),
              ),
            ),
    );
  }
}

String _absolutePhotoUrl(String? raw) {
  final value = '${raw ?? ''}'.trim();
  if (value.isEmpty || value == 'null') return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final cleaned = value.startsWith('/') ? value.substring(1) : value;
  return 'https://sportotekaapp.ru/$cleaned';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'И';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, color: _AD.dim, size: 40),
    const SizedBox(height: 10),
    Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _AD.muted, fontWeight: FontWeight.w800)),
  ]));
}

class _DarkError extends StatelessWidget {
  const _DarkError({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Container(
    constraints: const BoxConstraints(maxWidth: 560),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(color: Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Color(0xFFF7C8C4))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.warning_amber_rounded, color: _AD.red),
      const SizedBox(height: 8),
      Text(error, textAlign: TextAlign.center, style: const TextStyle(color: _AD.red, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      _DarkActionButton(icon: Icons.refresh_rounded, label: 'Повторить', onTap: onRetry),
    ]),
  ));
}

class _NoHoverTap extends StatelessWidget {
  const _NoHoverTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.hoverColor,
    this.splashColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadiusGeometry? borderRadius;
  final Color? hoverColor;
  final Color? splashColor;

  void _runAfterPointerSettled(BuildContext context, VoidCallback? callback) {
    if (callback == null) return;
    Future<void>.delayed(const Duration(milliseconds: 70), () async {
      if (!context.mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      callback();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => _runAfterPointerSettled(context, onTap),
      onLongPress: onLongPress == null ? null : () => _runAfterPointerSettled(context, onLongPress),
      child: child,
    );
  }
}
