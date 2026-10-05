import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

/// Clean AI-first match report used by Video Analytics.
///
/// The screen deliberately does not query the legacy PHP report endpoint.
/// Every value is supplied by the video-analysis workspace from the current
/// AI job: match stats, AI TTD, player stats, identity bindings and AI events.
class AiMatchReportScreen extends StatefulWidget {
  const AiMatchReportScreen({
    super.key,
    required this.data,
    required this.videoPreview,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onExportMore,
    required this.onJumpToTime,
  });

  final AiMatchReportData data;
  final Widget videoPreview;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onExportMore;
  final ValueChanged<int> onJumpToTime;

  @override
  State<AiMatchReportScreen> createState() => _AiMatchReportScreenState();
}

enum AiMatchReportSection {
  summary,
  ttd,
  passes,
  goalkeepers,
  events,
  players,
}

class AiMatchReportData {
  const AiMatchReportData({
    required this.matchTitle,
    required this.teamName,
    required this.opponentName,
    required this.teamScore,
    required this.opponentScore,
    required this.rosterCount,
    required this.resolvedPlayers,
    required this.episodesCount,
    required this.confidencePct,
    required this.team,
    required this.opponent,
    required this.players,
    required this.events,
    required this.summaryText,
  });

  final String matchTitle;
  final String teamName;
  final String opponentName;
  final int teamScore;
  final int opponentScore;
  final int rosterCount;
  final int resolvedPlayers;
  final int episodesCount;
  final double confidencePct;
  final AiMatchReportTeamData team;
  final AiMatchReportTeamData opponent;
  final List<AiMatchReportPlayerData> players;
  final List<AiMatchReportEventData> events;
  final String summaryText;
}

class AiMatchReportTeamData {
  const AiMatchReportTeamData({
    required this.goals,
    required this.shots,
    required this.shotsOnTarget,
    required this.passes,
    required this.successfulPasses,
    required this.ttd,
    required this.successfulTtd,
    required this.possessionPct,
    required this.interceptions,
    required this.recoveries,
  });

  final int goals;
  final int shots;
  final int shotsOnTarget;
  final int passes;
  final int successfulPasses;
  final int ttd;
  final int successfulTtd;
  final double possessionPct;
  final int interceptions;
  final int recoveries;

  int get passAccuracy => passes <= 0 ? 0 : (successfulPasses / passes * 100).round();
  int get ttdEfficiency => ttd <= 0 ? 0 : (successfulTtd / ttd * 100).round();
}

class AiMatchReportPlayerData {
  const AiMatchReportPlayerData({
    required this.playerId,
    required this.trackId,
    required this.number,
    required this.name,
    required this.position,
    required this.dribbles,
    required this.shots,
    required this.tackles,
    required this.interceptions,
    required this.recoveries,
    required this.headers,
    required this.throws,
    required this.passes,
    required this.successfulPasses,
    required this.totalTtd,
    required this.successfulTtd,
    required this.distanceM,
    required this.maxSpeedKmh,
    required this.rating,
  });

  final int playerId;
  final String trackId;
  final int? number;
  final String name;
  final String position;
  final int dribbles;
  final int shots;
  final int tackles;
  final int interceptions;
  final int recoveries;
  final int headers;
  final int throws;
  final int passes;
  final int successfulPasses;
  final int totalTtd;
  final int successfulTtd;
  final double distanceM;
  final double maxSpeedKmh;
  final double rating;

  int get efficiency => totalTtd <= 0 ? 0 : (successfulTtd / totalTtd * 100).round();
  int get passAccuracy => passes <= 0 ? 0 : (successfulPasses / passes * 100).round();
}

class AiMatchReportEventData {
  const AiMatchReportEventData({
    required this.type,
    required this.title,
    required this.player,
    required this.team,
    required this.timeMs,
    required this.confidence,
    required this.success,
  });

  final String type;
  final String title;
  final String player;
  final String team;
  final int timeMs;
  final double confidence;
  final bool success;
}

class _AiMatchReportScreenState extends State<AiMatchReportScreen> {
  AiMatchReportSection _section = AiMatchReportSection.summary;

  static const _green = Color(0xFF00A750);
  static const _greenDark = Color(0xFF067A46);
  static const _blue = Color(0xFF2563EB);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF667085);
  static const _border = Color(0xFFE8ECEA);
  static const _surface = Color(0xFFF8FAF9);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1120;

    return ColoredBox(
      color: const Color(0xFFFBFCFB),
      child: Column(
        children: [
          _header(),
          const Divider(height: 1, color: _border),
          Expanded(
            child: desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: width >= 1450 ? 310 : 272, child: _leftRail()),
                      const VerticalDivider(width: 1, color: _border),
                      Expanded(child: _mainContent()),
                    ],
                  )
                : Column(
                    children: [
                      _compactNav(),
                      const Divider(height: 1, color: _border),
                      Expanded(child: _mainContent()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final d = widget.data;
    final compact = MediaQuery.sizeOf(context).width < 1080;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: Row(
        children: [
          _iconBox(Icons.analytics_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Матч-отчёт',
                  style: AppTypography.sectionTitle(color: _text).copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${d.teamName} ${d.teamScore}:${d.opponentScore} ${d.opponentName}  •  AI-отчёт по видео',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(color: _muted).copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            _headerStatus('${d.resolvedPlayers}/${d.rosterCount} игроков', Icons.groups_2_outlined),
            const SizedBox(width: 7),
            _headerStatus('${d.events.length} событий', Icons.view_timeline_outlined),
            const SizedBox(width: 10),
          ],
          _actionButton(Icons.table_chart_outlined, compact ? '' : 'Excel', _greenDark, widget.onExportExcel),
          const SizedBox(width: 6),
          _actionButton(Icons.picture_as_pdf_outlined, compact ? '' : 'PDF', const Color(0xFFD92D20), widget.onExportPdf),
          const SizedBox(width: 3),
          IconButton(
            tooltip: 'Ещё',
            onPressed: widget.onExportMore,
            icon: const Icon(Icons.more_horiz_rounded, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _leftRail() {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: AspectRatio(aspectRatio: 16 / 9, child: widget.videoPreview),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _railItem(AiMatchReportSection.summary, Icons.bar_chart_rounded, 'Сводка матча'),
                  _railItem(AiMatchReportSection.ttd, Icons.groups_2_outlined, 'Технико-тактические действия'),
                  _railItem(AiMatchReportSection.passes, Icons.compare_arrows_rounded, 'Передачи'),
                  _railItem(AiMatchReportSection.goalkeepers, Icons.sports_handball_outlined, 'Вратарские действия'),
                  _railItem(AiMatchReportSection.events, Icons.view_timeline_outlined, 'Карта событий'),
                  _railItem(AiMatchReportSection.players, Icons.badge_outlined, 'Игроки'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactNav() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        children: [
          _compactItem(AiMatchReportSection.summary, 'Сводка'),
          _compactItem(AiMatchReportSection.ttd, 'ТТД'),
          _compactItem(AiMatchReportSection.passes, 'Передачи'),
          _compactItem(AiMatchReportSection.goalkeepers, 'Вратари'),
          _compactItem(AiMatchReportSection.events, 'События'),
          _compactItem(AiMatchReportSection.players, 'Игроки'),
        ],
      ),
    );
  }

  Widget _mainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 24),
      child: switch (_section) {
        AiMatchReportSection.summary => _summary(),
        AiMatchReportSection.ttd => _ttdTable(),
        AiMatchReportSection.passes => _passes(),
        AiMatchReportSection.goalkeepers => _goalkeepers(),
        AiMatchReportSection.events => _events(),
        AiMatchReportSection.players => _players(),
      },
    );
  }

  Widget _summary() {
    final d = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _kpi('Игроков', '${d.resolvedPlayers}/${d.rosterCount}', 'опознано AI', Icons.groups_2_outlined, _green),
            _kpi('Эпизодов', '${d.episodesCount}', 'в журнале', Icons.play_circle_outline_rounded, _green),
            _kpi('Точность передач', '${d.team.passAccuracy}%', '${d.team.successfulPasses}/${d.team.passes}', Icons.compare_arrows_rounded, _blue),
            _kpi('Эффективность ТТД', '${d.team.ttdEfficiency}%', '${d.team.successfulTtd}/${d.team.ttd}', Icons.bar_chart_rounded, _green),
            _kpi('Уверенность AI', d.confidencePct <= 0 ? '—' : '${d.confidencePct.round()}%', 'средняя', Icons.psychology_alt_outlined, _green),
          ],
        ),
        const SizedBox(height: 12),
        _teamComparison(),
        const SizedBox(height: 12),
        if (d.summaryText.trim().isNotEmpty) _aiSummaryCard(d.summaryText),
        const SizedBox(height: 12),
        _ttdTable(compact: true),
      ],
    );
  }

  Widget _teamComparison() {
    final d = widget.data;
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _teamTitle(d.teamName, _green, TextAlign.left)),
              SizedBox(
                width: 96,
                child: Text(
                  '${d.teamScore} : ${d.opponentScore}',
                  textAlign: TextAlign.center,
                  style: AppTypography.metricStrong(color: _text).copyWith(fontSize: 22),
                ),
              ),
              Expanded(child: _teamTitle(d.opponentName, _blue, TextAlign.right)),
            ],
          ),
          const SizedBox(height: 13),
          _compareRow('Удары', d.team.shots, d.opponent.shots),
          _compareRow('Удары в створ', d.team.shotsOnTarget, d.opponent.shotsOnTarget),
          _compareRow('Передачи', d.team.passes, d.opponent.passes),
          _compareRow('Перехваты', d.team.interceptions, d.opponent.interceptions),
          _compareRow('ТТД', d.team.ttd, d.opponent.ttd),
          _compareRow('Владение', d.team.possessionPct, d.opponent.possessionPct, percent: true),
        ],
      ),
    );
  }

  Widget _ttdTable({bool compact = false}) {
    final rows = widget.data.players
        .where((p) => !compact || p.totalTtd > 0 || p.trackId.trim().isNotEmpty)
        .toList();
    if (compact && rows.length > 8) rows.removeRange(8, rows.length);

    return _tableCard(
      title: 'Технико-тактические действия',
      subtitle: 'Данные сформированы из AI ТТД и player_stats текущего анализа',
      icon: Icons.sports_soccer_rounded,
      child: rows.isEmpty
          ? _empty('AI пока не сформировал ТТД по игрокам.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1020,
                child: Column(
                  children: [
                    _ttdHeader(),
                    for (final p in rows) _ttdRow(p),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _passes() {
    final rows = widget.data.players.where((p) => p.passes > 0).toList()
      ..sort((a, b) => b.passes.compareTo(a.passes));
    return _tableCard(
      title: 'Передачи',
      subtitle: 'AI-передачи по игрокам: успешность, объём и участие',
      icon: Icons.compare_arrows_rounded,
      child: rows.isEmpty
          ? _empty('AI пока не определил передачи.')
          : Column(
              children: [
                for (final p in rows) _passRow(p),
              ],
            ),
    );
  }

  Widget _goalkeepers() {
    final keepers = widget.data.players.where((p) {
      final pos = p.position.toLowerCase();
      return pos.contains('врат') || pos.contains('goalkeeper') || pos == 'gk';
    }).toList();
    return _tableCard(
      title: 'Вратарские действия',
      subtitle: 'Показатели вратаря из AI ТТД и player_stats',
      icon: Icons.sports_handball_outlined,
      child: keepers.isEmpty
          ? _empty('В составе или AI-данных вратарь пока не определён.')
          : Column(children: keepers.map(_goalkeeperRow).toList()),
    );
  }

  Widget _events() {
    final events = widget.data.events;
    return _tableCard(
      title: 'Карта событий',
      subtitle: '${events.length} AI-событий — клик переводит видео на момент',
      icon: Icons.view_timeline_outlined,
      child: events.isEmpty
          ? _empty('AI события пока не получены.')
          : Column(children: events.map(_eventRow).toList()),
    );
  }

  Widget _players() {
    final players = widget.data.players;
    return _tableCard(
      title: 'Игроки',
      subtitle: 'Сводка по идентичности, AI-треку и активности',
      icon: Icons.groups_2_outlined,
      child: players.isEmpty
          ? _empty('Состав для отчёта пока не получен.')
          : Column(children: players.map(_playerRow).toList()),
    );
  }

  Widget _ttdHeader() {
    const labels = [
      '#', 'Игрок', 'Финт/дриб.', 'Удары', 'Отбор', 'Перехват', 'Подбор', 'Голова', 'Ауты', 'Пасы', 'Всего ТТД', 'Эфф.'
    ];
    const widths = [42.0, 180.0, 78.0, 66.0, 66.0, 70.0, 66.0, 66.0, 60.0, 64.0, 76.0, 66.0];
    return Container(
      color: _surface,
      child: Row(
        children: List.generate(labels.length, (i) => SizedBox(
          width: widths[i],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
            child: Text(labels[i], textAlign: i == 1 ? TextAlign.left : TextAlign.center,
              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: _muted)),
          ),
        )),
      ),
    );
  }

  Widget _ttdRow(AiMatchReportPlayerData p) {
    const widths = [42.0, 180.0, 78.0, 66.0, 66.0, 70.0, 66.0, 66.0, 60.0, 64.0, 76.0, 66.0];
    final values = <dynamic>[
      p.number ?? '—', p.name, p.dribbles, p.shots, p.tackles, p.interceptions,
      p.recoveries, p.headers, p.throws, p.passes, p.totalTtd, '${p.efficiency}%'
    ];
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F2F1)))),
      child: Row(
        children: List.generate(values.length, (i) {
          if (i == 1) {
            return SizedBox(
              width: widths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${values[i]}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.8, fontWeight: FontWeight.w700, color: _text)),
                  if (p.position.trim().isNotEmpty)
                    Text(p.position, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 8.2, color: Color(0xFF98A2B3))),
                ]),
              ),
            );
          }
          if (i == values.length - 1) {
            return SizedBox(width: widths[i], child: Center(child: _percentPill(p.efficiency)));
          }
          return SizedBox(
            width: widths[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Text('${values[i]}', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF344054))),
            ),
          );
        }),
      ),
    );
  }

  Widget _passRow(AiMatchReportPlayerData p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F2F1)))),
      child: Row(children: [
        SizedBox(width: 42, child: Text(p.number == null ? '—' : '${p.number}', textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _greenDark))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _text)),
          if (p.position.isNotEmpty) Text(p.position, style: const TextStyle(fontSize: 8.5, color: _muted)),
        ])),
        _miniStat('Передачи', '${p.successfulPasses}/${p.passes}'),
        const SizedBox(width: 14),
        _miniStat('Точность', '${p.passAccuracy}%'),
        const SizedBox(width: 10),
        SizedBox(width: 118, child: LinearProgressIndicator(value: p.passAccuracy / 100.0, minHeight: 6,
          color: _blue, backgroundColor: const Color(0xFFE8EEF9), borderRadius: BorderRadius.circular(99))),
      ]),
    );
  }

  Widget _goalkeeperRow(AiMatchReportPlayerData p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F2F1)))),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: const Color(0xFFF3FAF6),
          child: Text(p.number == null ? 'GK' : '${p.number}', style: const TextStyle(color: _greenDark, fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _text)),
          Text(p.position.isEmpty ? 'Вратарь' : p.position, style: const TextStyle(fontSize: 9, color: _muted)),
        ])),
        _miniStat('ТТД', '${p.totalTtd}'),
        const SizedBox(width: 14),
        _miniStat('Перехваты', '${p.interceptions}'),
        const SizedBox(width: 14),
        _miniStat('Эфф.', '${p.efficiency}%'),
      ]),
    );
  }

  Widget _eventRow(AiMatchReportEventData e) {
    final color = _eventColor(e.type);
    return InkWell(
      onTap: () => widget.onJumpToTime(e.timeMs),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F2F1)))),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(9)),
            child: Icon(_eventIcon(e.type), size: 17, color: color)),
          const SizedBox(width: 9),
          SizedBox(width: 58, child: Text(_formatMs(e.timeMs), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _text))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _text)),
            Text([e.player, e.team].where((s) => s.trim().isNotEmpty).join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8.7, color: _muted)),
          ])),
          Text(e.confidence <= 0 ? '' : '${(e.confidence * (e.confidence <= 1 ? 100 : 1)).round()}%',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _muted)),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 18, color: _muted.withOpacity(.7)),
        ]),
      ),
    );
  }

  Widget _playerRow(AiMatchReportPlayerData p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F2F1)))),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: const Color(0xFFF3FAF6),
          child: Text(p.number == null ? 'И' : '${p.number}', style: const TextStyle(color: _greenDark, fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _text)),
          Text([p.position, p.trackId.isEmpty ? '' : 'AI-трек ${p.trackId}'].where((e) => e.isNotEmpty).join(' • '),
            style: const TextStyle(fontSize: 8.7, color: _muted)),
        ])),
        _miniStat('ТТД', '${p.totalTtd}'),
        const SizedBox(width: 14),
        _miniStat('Пасы', '${p.passes}'),
        const SizedBox(width: 14),
        _miniStat('Max км/ч', p.maxSpeedKmh <= 0 ? '—' : p.maxSpeedKmh.toStringAsFixed(1)),
        const SizedBox(width: 14),
        _miniStat('Рейтинг', p.rating <= 0 ? '—' : p.rating.toStringAsFixed(1)),
      ]),
    );
  }

  Widget _aiSummaryCard(String text) {
    return _card(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _iconBox(Icons.auto_awesome_rounded),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Краткое резюме AI', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _text)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 9.6, height: 1.45, color: _muted)),
        ])),
      ]),
    );
  }

  Widget _tableCard({required String title, required String subtitle, required IconData icon, required Widget child}) {
    return _card(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
          child: Row(children: [
            _iconBox(icon, size: 30),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12.2, fontWeight: FontWeight.w800, color: _text)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8.7, color: _muted)),
            ])),
          ]),
        ),
        const Divider(height: 1, color: _border),
        child,
      ]),
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(13)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _kpi(String label, String value, String subtitle, IconData icon, Color accent) {
    return Container(
      width: 178,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: _border)),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: accent.withOpacity(.07), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 18, color: accent)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5, color: _muted, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _text)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.8, color: Color(0xFF98A2B3))),
        ])),
      ]),
    );
  }

  Widget _teamTitle(String text, Color accent, TextAlign align) {
    return Column(crossAxisAlignment: align == TextAlign.left ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: align,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _text)),
      const SizedBox(height: 5),
      Container(height: 2, width: 90, color: accent),
    ]);
  }

  Widget _compareRow(String label, num left, num right, {bool percent = false}) {
    final l = left.toDouble();
    final r = right.toDouble();
    final maxValue = (l > r ? l : r).clamp(1.0, double.infinity).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 44, child: Text(percent ? '${l.round()}%' : '${l.round()}', textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _text))),
        const SizedBox(width: 8),
        Expanded(child: Align(alignment: Alignment.centerRight, child: FractionallySizedBox(widthFactor: (l / maxValue).clamp(0.0, 1.0).toDouble(),
          child: Container(height: 7, decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(99))))),
        ),
        SizedBox(width: 126, child: Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9.2, color: _muted, fontWeight: FontWeight.w600))),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: (r / maxValue).clamp(0.0, 1.0).toDouble(),
          child: Container(height: 7, decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(99))))),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 44, child: Text(percent ? '${r.round()}%' : '${r.round()}',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _text))),
      ]),
    );
  }

  Widget _railItem(AiMatchReportSection section, IconData icon, String label) {
    final active = _section == section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? const Color(0xFFF0FAF4) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => setState(() => _section = section),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 17, color: active ? _green : _muted),
              const SizedBox(width: 9),
              Expanded(child: Text(label, style: TextStyle(fontSize: 9.8, fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? _text : _muted))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _compactItem(AiMatchReportSection section, String label) {
    final active = _section == section;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        selected: active,
        label: Text(label),
        onSelected: (_) => setState(() => _section = section),
        selectedColor: const Color(0xFFF0FAF4),
        backgroundColor: Colors.white,
        side: const BorderSide(color: _border),
        labelStyle: TextStyle(fontSize: 9.2, fontWeight: FontWeight.w700, color: active ? _greenDark : _muted),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: label.isEmpty
          ? const SizedBox.shrink()
          : Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _text)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _headerStatus(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(99)),
      child: Row(children: [
        Icon(icon, size: 14, color: _muted),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 8.8, fontWeight: FontWeight.w700, color: _text)),
      ]),
    );
  }

  Widget _iconBox(IconData icon, {double size = 34}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: const Color(0xFFF3FAF6), borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, size: size * .52, color: _green),
    );
  }

  Widget _percentPill(int value) {
    final v = value.clamp(0, 100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF0FAF4), borderRadius: BorderRadius.circular(99)),
      child: Text('$v%', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _greenDark)),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _text)),
      Text(label, style: const TextStyle(fontSize: 7.8, color: _muted)),
    ]);
  }

  Widget _empty(String text) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Center(child: Text(text, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: _muted))),
    );
  }

  IconData _eventIcon(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('goal') || s.contains('гол')) return Icons.sports_soccer_rounded;
    if (s.contains('pass') || s.contains('пас') || s.contains('перед')) return Icons.compare_arrows_rounded;
    if (s.contains('shot') || s.contains('удар')) return Icons.adjust_rounded;
    if (s.contains('card') || s.contains('карт')) return Icons.style_rounded;
    if (s.contains('intercept') || s.contains('перех')) return Icons.shield_outlined;
    return Icons.auto_awesome_rounded;
  }

  Color _eventColor(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('goal') || s.contains('гол')) return const Color(0xFFDC2626);
    if (s.contains('pass') || s.contains('пас') || s.contains('перед')) return const Color(0xFF7C3AED);
    if (s.contains('shot') || s.contains('удар')) return const Color(0xFFEA580C);
    if (s.contains('card') || s.contains('карт')) return const Color(0xFFF59E0B);
    if (s.contains('intercept') || s.contains('перех')) return _green;
    return _blue;
  }

  String _formatMs(int ms) {
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
