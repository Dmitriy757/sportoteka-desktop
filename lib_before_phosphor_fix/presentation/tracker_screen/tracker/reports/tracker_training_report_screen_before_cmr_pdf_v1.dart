import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tracker_training_report_api.dart';
import 'tracker_training_report_models.dart';

class TrackerTrainingReportScreen extends StatefulWidget {
  const TrackerTrainingReportScreen({
    super.key,
    required this.sessionId,
    required this.teamId,
    required this.teamName,
    this.api,
  });

  final int sessionId;
  final int teamId;
  final String teamName;
  final TrackerTrainingReportApi? api;

  @override
  State<TrackerTrainingReportScreen> createState() => _TrackerTrainingReportScreenState();
}

class _TrackerTrainingReportScreenState extends State<TrackerTrainingReportScreen> {
  late final TrackerTrainingReportApi _api;
  late Future<TrackerTrainingReport> _future;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? TrackerTrainingReportApi();
    _future = _api.loadTrainingReport(sessionId: widget.sessionId, teamId: widget.teamId);
  }

  void _reload() {
    setState(() {
      _future = _api.loadTrainingReport(sessionId: widget.sessionId, teamId: widget.teamId);
    });
  }

  Future<void> _openExport(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть экспорт: $uri')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.bg,
      body: SafeArea(
        child: FutureBuilder<TrackerTrainingReport>(
          future: _future,
          builder: (context, snapshot) {
            final report = snapshot.data ?? TrackerTrainingReport.empty(sessionId: widget.sessionId, teamName: widget.teamName);
            return Column(
              children: [
                _Header(
                  report: report,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                  onBack: () => Navigator.of(context).maybePop(),
                  onRefresh: _reload,
                  onPdf: () => _openExport(_api.pdfExportUri(sessionId: widget.sessionId, teamId: widget.teamId)),
                  onExcel: () => _openExport(_api.csvExportUri(sessionId: widget.sessionId, teamId: widget.teamId)),
                ),
                _Tabs(
                  selected: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
                if (snapshot.hasError)
                  Expanded(child: _ErrorView(error: '${snapshot.error}', onRetry: _reload))
                else
                  Expanded(child: _buildTab(report)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTab(TrackerTrainingReport report) {
    switch (_tab) {
      case 0:
        return _SummaryTab(report: report);
      case 1:
        return _LocomotorTab(report: report);
      case 2:
        return _MechanicalTab(report: report);
      case 3:
        return _InternalLoadTab(report: report);
      case 4:
        return _MicrocycleTab(report: report);
      default:
        return _SummaryTab(report: report);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.report,
    required this.loading,
    required this.onBack,
    required this.onRefresh,
    required this.onPdf,
    required this.onExcel,
  });

  final TrackerTrainingReport report;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onPdf;
  final VoidCallback onExcel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _R.border)),
        boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: _R.text)),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _R.lightGreen, borderRadius: BorderRadius.circular(10), border: Border.all(color: _R.border)),
            child: const Text('S', style: TextStyle(color: _R.darkGreen, fontWeight: FontWeight.w900, fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SPORTOTEKA TRACKER PRO', style: TextStyle(color: _R.darkGreen, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: .3)),
                const SizedBox(height: 3),
                Text(
                  'Отчёт по тренировке · ${report.dateLabel.isEmpty ? 'дата не указана' : report.dateLabel} · ${report.teamName} · ${report.durationLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _R.muted, fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: _R.darkGreen, strokeWidth: 2)),
            ),
          _HeaderButton(icon: Icons.refresh_rounded, label: 'Обновить', onTap: onRefresh),
          const SizedBox(width: 8),
          _HeaderButton(icon: Icons.picture_as_pdf_rounded, label: 'PDF', onTap: onPdf),
          const SizedBox(width: 8),
          _HeaderButton(icon: Icons.table_chart_rounded, label: 'Excel', onTap: onExcel),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _R.lightGreen,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: _R.border), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: _R.darkGreen, size: 18),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(color: _R.darkGreen, fontWeight: FontWeight.w900, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  static const items = ['Сводка', 'Локомоторика', 'Механика', 'Внутренняя', 'Микроцикл'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = i == selected;
          return InkWell(
            onTap: () => onSelect(i),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? _R.lightGreen : _R.panel,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: active ? _R.green : _R.border),
              ),
              child: Text(items[i], style: TextStyle(color: active ? _R.darkGreen : _R.text, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final md = _mdComparison(report);
    return _ScrollPage(
      children: [
        _SectionTitle('ОБЩАЯ СВОДКА ПО ТРЕНИРОВКЕ'),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 1000;
          return Flex(
            direction: wide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: wide ? 5 : 0,
                child: Column(children: [
                  _Card(
                    title: 'ОБЩАЯ ИНФОРМАЦИЯ',
                    child: _SummaryGrid(report: report),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: 'ПЕРИОДЫ / УПРАЖНЕНИЯ',
                    child: _PeriodsTable(periods: report.periods),
                  ),
                ]),
              ),
              SizedBox(width: wide ? 12 : 0, height: wide ? 0 : 12),
              Expanded(
                flex: wide ? 7 : 0,
                child: Column(children: [
                  _Card(
                    title: 'ДИНАМИКА МИКРОЦИКЛА',
                    child: SizedBox(height: 300, child: _MicrocycleChart(points: report.microcycle)),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: '% ОТ СРЕДНИХ ЗНАЧЕНИЙ МАТЧА',
                    child: SizedBox(height: 300, child: _PercentBarChart(values: md)),
                  ),
                ]),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final s = report.summary;
    final tiles = [
      _Metric('Время тренировки', report.durationLabel, 'длительность'),
      _Metric('Средняя дистанция', s.averageDistanceM.toStringAsFixed(0), 'м'),
      _Metric('Количество игроков', '${report.playersCount}', 'игроков'),
      _Metric('Высокоскоростная дистанция', s.highSpeedDistanceM.toStringAsFixed(0), 'м'),
      _Metric('Нагрузка игрока', s.playerLoad.toStringAsFixed(0), 'усл. ед.'),
      _Metric('Ускор./торм.', s.accDecPerMin.toStringAsFixed(1), 'в мин'),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 210, mainAxisExtent: 86, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemBuilder: (_, i) => _MetricTile(metric: tiles[i]),
    );
  }
}

class _LocomotorTab extends StatelessWidget {
  const _LocomotorTab({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return _ScrollPage(children: [
      _SectionTitle('ЛОКОМОТОРНАЯ РАБОТА'),
      _Card(
        title: report.title,
        child: _LocomotorTable(players: report.players),
      ),
    ]);
  }
}

class _MechanicalTab extends StatelessWidget {
  const _MechanicalTab({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return _ScrollPage(children: [
      _SectionTitle('МЕХАНИЧЕСКАЯ РАБОТА'),
      _TwoByTwo(
        a: _ChartCard(title: 'УСКОРЕНИЯ/ТОРМОЖЕНИЯ (ОБЩЕЕ КОЛ-ВО)', child: _DualBarChart(players: report.players, first: (p) => p.accelerations.toDouble(), second: (p) => p.decelerations.toDouble(), firstLabel: 'Ускорения', secondLabel: 'Торможения')),
        b: _ChartCard(title: 'УСКОРЕНИЯ/ТОРМОЖЕНИЯ (МАКС ИНТ)', child: _BarChart(players: report.players, value: (p) => p.accDecPerMin, label: 'УСК+ТОР/мин')),
        c: _ChartCard(title: 'ИЗМЕНЕНИЕ НАПРАВЛЕНИЯ ДВИЖЕНИЯ', child: _BarChart(players: report.players, value: (p) => p.highSpeedActions.toDouble(), label: 'Кол-во')),
        d: _ChartCard(title: 'ВЗРЫВНЫЕ ДЕЙСТВИЯ', child: _BarChart(players: report.players, value: (p) => p.explosiveActions.toDouble(), label: 'Действия')),
      ),
    ]);
  }
}

class _InternalLoadTab extends StatelessWidget {
  const _InternalLoadTab({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return _ScrollPage(children: [
      _SectionTitle('ВНУТРЕННЯЯ НАГРУЗКА'),
      _TwoByTwo(
        a: _ChartCard(title: 'ВРЕМЯ В ЗОНАХ ЧСС', child: _StackedHrChart(players: report.players, distanceMode: false)),
        b: _ChartCard(title: 'ДИСТАНЦИЯ В РАЗЛИЧНЫХ ЗОНАХ ЧСС', child: _StackedHrChart(players: report.players, distanceMode: true)),
        c: _ChartCard(title: 'СРЕДНИЙ % ОТ ЧСС МАКС', child: _BarChart(players: report.players, value: (p) => p.heartRateMaxPercent, label: '% ЧСС')),
        d: _ChartCard(title: 'НАПРЯЖЕНИЕ ПО ЧСС + НАГРУЗКА ИГРОКА', child: _DualBarChart(players: report.players, first: (p) => p.hrExertion, second: (p) => p.playerLoad, firstLabel: 'Напряжение по ЧСС', secondLabel: 'Нагрузка игрока')),
      ),
    ]);
  }
}

class _MicrocycleTab extends StatelessWidget {
  const _MicrocycleTab({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return _ScrollPage(children: [
      _SectionTitle('ДИНАМИКА МИКРОЦИКЛА'),
      _Card(title: 'Дистанция / высокоинтенсивный бег / ускорения-торможения', child: SizedBox(height: 440, child: _MicrocycleChart(points: report.microcycle))),
      const SizedBox(height: 12),
      _Card(title: 'СРАВНЕНИЕ MD-5', child: SizedBox(height: 360, child: _PercentBarChart(values: _mdComparison(report)))),
    ]);
  }
}

class _ScrollPage extends StatelessWidget {
  const _ScrollPage({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: children,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: _R.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(color: Color(0xFFF1F5F2), border: Border(bottom: BorderSide(color: _R.border))),
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _R.darkGreen, fontWeight: FontWeight.w900, fontSize: 15)),
        ),
        Padding(padding: const EdgeInsets.all(10), child: child),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(child: Text(text, style: const TextStyle(color: _R.darkGreen, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: .4))),
    );
  }
}

class _Metric {
  const _Metric(this.title, this.value, this.subtitle);
  final String title;
  final String value;
  final String subtitle;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8FAF8), border: Border.all(color: _R.border), borderRadius: BorderRadius.circular(5)),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(metric.title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _R.muted, fontSize: 9, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _R.text, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(metric.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _R.muted, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _PeriodsTable extends StatelessWidget {
  const _PeriodsTable({required this.periods});
  final List<TrackerExercisePeriod> periods;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) return const _EmptyBlock('Периоды пока не сохранены. Используйте + Период в Live.');
    return Table(
      border: TableBorder.all(color: _R.border),
      columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
      children: [
        _tableRow(['Упражнение', 'Начало', 'Конец'], header: true),
        ...periods.map((p) => _tableRow([p.title, p.startLabel, p.endLabel])),
      ],
    );
  }
}

class _LocomotorTable extends StatelessWidget {
  const _LocomotorTable({required this.players});
  final List<TrackerTrainingPlayerRow> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const _EmptyBlock('Нет игроков в отчёте.');
    final avg = _avgRow(players);
    final rows = [...players, avg];
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1420,
          child: Table(
            border: TableBorder.all(color: const Color(0xFFD0D5DD)),
            columnWidths: const {
              0: FlexColumnWidth(2.4),
              1: FlexColumnWidth(1.1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
              5: FlexColumnWidth(.8),
              6: FlexColumnWidth(.8),
              7: FlexColumnWidth(.9),
              8: FlexColumnWidth(.9),
              9: FlexColumnWidth(1),
              10: FlexColumnWidth(1),
              11: FlexColumnWidth(1),
              12: FlexColumnWidth(.8),
              13: FlexColumnWidth(1),
              14: FlexColumnWidth(.8),
            },
            children: [
              _tableRow(['Фамилия', 'Время', 'Дист. м', 'м/мин', 'Макс.', 'Уск.', 'Торм.', 'УСК+ТОР', 'Взрыв.', 'V3 бег', 'V4 ВСБ', 'V5 спринт', 'Спр.', 'V4+V5', 'Действ.'], header: true),
              ...rows.map((p) => _playerRow(p, p.name == 'СРЕДНЕЕ')),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _playerRow(TrackerTrainingPlayerRow p, bool avg) {
    return TableRow(
      decoration: BoxDecoration(color: avg ? const Color(0xFFE5E7EB) : Colors.white),
      children: [
        _cell(p.name, bold: true, align: TextAlign.left),
        _cell(p.duration),
        _heatCell(p.distanceM.toStringAsFixed(0), p.distanceM, 4500),
        _heatCell(p.metersPerMin.toStringAsFixed(1), p.metersPerMin, 130),
        _heatCell(p.maxSpeedKmh.toStringAsFixed(1), p.maxSpeedKmh, 30),
        _barCell('${p.accelerations}', p.accelerations.toDouble(), 24, _R.green),
        _barCell('${p.decelerations}', p.decelerations.toDouble(), 28, _R.red),
        _heatCell(p.accDecPerMin.toStringAsFixed(1), p.accDecPerMin, 3),
        _barCell('${p.explosiveActions}', p.explosiveActions.toDouble(), 30, _R.red),
        _heatCell(p.v3RunM.toStringAsFixed(0), p.v3RunM, 1300),
        _heatCell(p.v4HsrM.toStringAsFixed(0), p.v4HsrM, 450),
        _heatCell(p.v5SprintM.toStringAsFixed(0), p.v5SprintM, 110),
        _cell('${p.sprintCount}'),
        _heatCell(p.highSpeedWorkM.toStringAsFixed(0), p.highSpeedWorkM, 550),
        _cell('${p.highSpeedActions}'),
      ],
    );
  }
}

class _TwoByTwo extends StatelessWidget {
  const _TwoByTwo({required this.a, required this.b, required this.c, required this.d});
  final Widget a;
  final Widget b;
  final Widget c;
  final Widget d;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      if (!wide) {
        return Column(children: [a, const SizedBox(height: 12), b, const SizedBox(height: 12), c, const SizedBox(height: 12), d]);
      }
      return Column(children: [
        Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: c), const SizedBox(width: 12), Expanded(child: d)]),
      ]);
    });
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => _Card(title: title, child: SizedBox(height: 320, child: child));
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.players, required this.value, required this.label});
  final List<TrackerTrainingPlayerRow> players;
  final double Function(TrackerTrainingPlayerRow) value;
  final String label;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BarChartPainter(players: players, value: value, label: label), child: const SizedBox.expand());
}

class _DualBarChart extends StatelessWidget {
  const _DualBarChart({required this.players, required this.first, required this.second, required this.firstLabel, required this.secondLabel});
  final List<TrackerTrainingPlayerRow> players;
  final double Function(TrackerTrainingPlayerRow) first;
  final double Function(TrackerTrainingPlayerRow) second;
  final String firstLabel;
  final String secondLabel;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DualBarChartPainter(players: players, first: first, second: second, firstLabel: firstLabel, secondLabel: secondLabel), child: const SizedBox.expand());
}

class _StackedHrChart extends StatelessWidget {
  const _StackedHrChart({required this.players, required this.distanceMode});
  final List<TrackerTrainingPlayerRow> players;
  final bool distanceMode;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _StackedHrPainter(players: players, distanceMode: distanceMode), child: const SizedBox.expand());
}

class _MicrocycleChart extends StatelessWidget {
  const _MicrocycleChart({required this.points});
  final List<TrackerMicrocyclePoint> points;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _MicrocyclePainter(points: points), child: const SizedBox.expand());
}

class _PercentBarChart extends StatelessWidget {
  const _PercentBarChart({required this.values});
  final List<_NamedValue> values;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PercentPainter(values: values), child: const SizedBox.expand());
}

abstract class _BaseChartPainter extends CustomPainter {
  void drawGrid(Canvas canvas, Rect rect, {int lines = 5}) {
    final paint = Paint()..color = const Color(0xFFE5E7EB)..strokeWidth = 1;
    for (var i = 0; i <= lines; i++) {
      final y = rect.bottom - rect.height * i / lines;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  void text(Canvas canvas, String value, Offset offset, {double size = 10, Color color = _R.text, FontWeight weight = FontWeight.w700, TextAlign align = TextAlign.left, double maxWidth = 120}) {
    final tp = TextPainter(text: TextSpan(text: value, style: TextStyle(color: color, fontSize: size, fontWeight: weight)), textDirection: TextDirection.ltr, textAlign: align, maxLines: 2)..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  String shortName(String name) {
    final parts = name.split(RegExp(r'\s+')).where((e) => e.trim().isNotEmpty).toList();
    if (parts.length <= 1) return name.length > 8 ? name.substring(0, 8) : name;
    return '${parts.first}\n${parts.last.length > 7 ? parts.last.substring(0, 7) : parts.last}';
  }
}

class _BarChartPainter extends _BaseChartPainter {
  _BarChartPainter({required this.players, required this.value, required this.label});
  final List<TrackerTrainingPlayerRow> players;
  final double Function(TrackerTrainingPlayerRow) value;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final list = players.take(12).toList();
    if (list.isEmpty) return;
    final rect = Rect.fromLTWH(48, 20, size.width - 70, size.height - 78);
    drawGrid(canvas, rect);
    final maxValue = list.map(value).fold<double>(1, math.max);
    final gap = rect.width / list.length;
    final barW = math.min(34.0, gap * .48);
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final v = value(p).clamp(0, maxValue);
      final h = rect.height * v / maxValue;
      final x = rect.left + gap * i + (gap - barW) / 2;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, rect.bottom - h, barW, h), const Radius.circular(4));
      canvas.drawRRect(r, Paint()..color = _R.lime);
      text(canvas, v.toStringAsFixed(v >= 10 ? 0 : 1), Offset(x - 2, rect.bottom - h - 16), size: 9, maxWidth: 44, align: TextAlign.center);
      text(canvas, shortName(p.name), Offset(x - gap * .25, rect.bottom + 8), size: 8, color: _R.muted, maxWidth: gap * .9, align: TextAlign.center);
    }
    text(canvas, label, Offset(rect.left, 0), size: 11, color: _R.darkGreen, weight: FontWeight.w900);
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

class _DualBarChartPainter extends _BaseChartPainter {
  _DualBarChartPainter({required this.players, required this.first, required this.second, required this.firstLabel, required this.secondLabel});
  final List<TrackerTrainingPlayerRow> players;
  final double Function(TrackerTrainingPlayerRow) first;
  final double Function(TrackerTrainingPlayerRow) second;
  final String firstLabel;
  final String secondLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final list = players.take(12).toList();
    if (list.isEmpty) return;
    final rect = Rect.fromLTWH(48, 26, size.width - 70, size.height - 86);
    drawGrid(canvas, rect);
    final maxValue = list.expand((p) => [first(p), second(p)]).fold<double>(1, math.max);
    final gap = rect.width / list.length;
    final barW = math.min(16.0, gap * .22);
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final x = rect.left + gap * i + (gap - barW * 2 - 4) / 2;
      final h1 = rect.height * first(p) / maxValue;
      final h2 = rect.height * second(p) / maxValue;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, rect.bottom - h1, barW, h1), const Radius.circular(3)), Paint()..color = _R.green);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + barW + 4, rect.bottom - h2, barW, h2), const Radius.circular(3)), Paint()..color = _R.red);
      text(canvas, shortName(p.name), Offset(x - gap * .2, rect.bottom + 8), size: 8, color: _R.muted, maxWidth: gap * .9, align: TextAlign.center);
    }
    text(canvas, '$firstLabel / $secondLabel', Offset(rect.left, 0), size: 11, color: _R.darkGreen, weight: FontWeight.w900);
  }

  @override
  bool shouldRepaint(covariant _DualBarChartPainter oldDelegate) => true;
}

class _StackedHrPainter extends _BaseChartPainter {
  _StackedHrPainter({required this.players, required this.distanceMode});
  final List<TrackerTrainingPlayerRow> players;
  final bool distanceMode;

  @override
  void paint(Canvas canvas, Size size) {
    final list = players.take(12).toList();
    if (list.isEmpty) return;
    final rect = Rect.fromLTWH(48, 20, size.width - 70, size.height - 78);
    drawGrid(canvas, rect);
    final double maxValue = list
        .map<double>((p) => distanceMode
            ? p.distanceM.toDouble()
            : math.max(1.0, p.duration == '00:00:00' ? 1.0 : 20.0).toDouble())
        .fold<double>(1.0, (previous, value) => math.max(previous, value).toDouble());
    final gap = rect.width / list.length;
    final barW = math.min(34.0, gap * .48);
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final total = distanceMode ? math.max(1.0, p.distanceM) : 18.0;
      final zones = distanceMode
          ? [total * .42, total * .36, total * .16, total * .06]
          : [total * .38, total * .34, total * .18, total * .10];
      var y = rect.bottom;
      final x = rect.left + gap * i + (gap - barW) / 2;
      final colors = [_R.lime, const Color(0xFFFFC857), const Color(0xFFF97316), const Color(0xFFE11D48)];
      for (var z = 0; z < zones.length; z++) {
        final h = rect.height * zones[z] / maxValue;
        y -= h;
        canvas.drawRect(Rect.fromLTWH(x, y, barW, h), Paint()..color = colors[z]);
      }
      text(canvas, shortName(p.name), Offset(x - gap * .25, rect.bottom + 8), size: 8, color: _R.muted, maxWidth: gap * .9, align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(covariant _StackedHrPainter oldDelegate) => true;
}

class _MicrocyclePainter extends _BaseChartPainter {
  _MicrocyclePainter({required this.points});
  final List<TrackerMicrocyclePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final list = points.isEmpty ? _demoMicrocycle() : points;
    final rect = Rect.fromLTWH(54, 20, size.width - 82, size.height - 78);
    drawGrid(canvas, rect);
    final maxDist = list.map((p) => p.distanceM).fold<double>(1, math.max);
    final maxLine = list.expand((p) => [p.highSpeedRunningM, p.accDec]).fold<double>(1, math.max);
    final gap = rect.width / list.length;
    final barW = math.min(54.0, gap * .42);
    final hsrPath = Path();
    final accPath = Path();
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final x = rect.left + gap * i + gap / 2;
      final barH = rect.height * p.distanceM / maxDist;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - barW / 2, rect.bottom - barH, barW, barH), const Radius.circular(4)), Paint()..color = _R.lime);
      final y1 = rect.bottom - rect.height * p.highSpeedRunningM / maxLine;
      final y2 = rect.bottom - rect.height * p.accDec / maxLine;
      if (i == 0) {
        hsrPath.moveTo(x, y1);
        accPath.moveTo(x, y2);
      } else {
        hsrPath.lineTo(x, y1);
        accPath.lineTo(x, y2);
      }
      text(canvas, p.label, Offset(x - gap * .45, rect.bottom + 10), size: 9, color: _R.muted, maxWidth: gap * .9, align: TextAlign.center);
    }
    canvas.drawPath(hsrPath, Paint()..color = const Color(0xFFE11D48)..strokeWidth = 2..style = PaintingStyle.stroke);
    canvas.drawPath(accPath, Paint()..color = const Color(0xFF3B82F6)..strokeWidth = 2..style = PaintingStyle.stroke);
    text(canvas, 'Дистанция / высокоинтенсивный бег / ускорения-торможения', Offset(rect.left, 0), size: 11, color: _R.darkGreen, weight: FontWeight.w900);
  }

  List<TrackerMicrocyclePoint> _demoMicrocycle() => const [
        TrackerMicrocyclePoint(label: 'Пн', distanceM: 52000, highSpeedRunningM: 3400, accDec: 105),
        TrackerMicrocyclePoint(label: 'Вт', distanceM: 26000, highSpeedRunningM: 820, accDec: 37),
        TrackerMicrocyclePoint(label: 'Ср', distanceM: 57000, highSpeedRunningM: 10080, accDec: 72),
        TrackerMicrocyclePoint(label: 'Чт', distanceM: 40000, highSpeedRunningM: 440, accDec: 5),
      ];

  @override
  bool shouldRepaint(covariant _MicrocyclePainter oldDelegate) => true;
}

class _PercentPainter extends _BaseChartPainter {
  _PercentPainter({required this.values});
  final List<_NamedValue> values;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(44, 20, size.width - 70, size.height - 92);
    drawGrid(canvas, rect);
    final list = values;
    final gap = rect.width / list.length;
    final barW = math.min(28.0, gap * .58);
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      final v = item.value.clamp(0, 100).toDouble();
      final h = rect.height * v / 100;
      final x = rect.left + gap * i + (gap - barW) / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, rect.bottom - h, barW, h), const Radius.circular(3)), Paint()..color = const Color(0xFFF9D976));
      text(canvas, '${v.toStringAsFixed(0)}%', Offset(x - 4, rect.bottom - h - 15), size: 9, maxWidth: 40, align: TextAlign.center);
      canvas.save();
      canvas.translate(x + barW / 2, rect.bottom + 8);
      canvas.rotate(-math.pi / 2);
      text(canvas, item.name, const Offset(0, -6), size: 8, color: _R.text, maxWidth: 92);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PercentPainter oldDelegate) => true;
}

class _NamedValue {
  const _NamedValue(this.name, this.value);
  final String name;
  final double value;
}

List<_NamedValue> _mdComparison(TrackerTrainingReport report) {
  final s = report.summary;
  return [
    _NamedValue('Дистанция', _percent(s.averageDistanceM, 7792)),
    _NamedValue('Метры/мин', _percent(s.distancePerMin, 116)),
    _NamedValue('Макс скорость', _percent(s.maxSpeedKmh, 29)),
    _NamedValue('Ускорения', _percent(s.accelerationCount.toDouble(), 20)),
    _NamedValue('Торможения', _percent(s.decelerationCount.toDouble(), 27)),
    _NamedValue('УСК+ТОР', _percent(s.accDecPerMin, 3)),
    _NamedValue('Взрывные', _percent(s.explosiveActions.toDouble(), 25)),
    _NamedValue('V3 бег', _percent(report.players.fold<double>(0, (a, p) => a + p.v3RunM) / math.max(1, report.players.length), 1228)),
    _NamedValue('V4 ВСБ', _percent(report.players.fold<double>(0, (a, p) => a + p.v4HsrM) / math.max(1, report.players.length), 426)),
    _NamedValue('V5 спринт', _percent(report.players.fold<double>(0, (a, p) => a + p.v5SprintM) / math.max(1, report.players.length), 100)),
    _NamedValue('Спринты', _percent(report.players.fold<double>(0, (a, p) => a + p.sprintCount) / math.max(1, report.players.length), 5)),
    _NamedValue('V4+V5', _percent(s.highSpeedDistanceM, 526)),
  ];
}

double _percent(double value, double benchmark) => benchmark <= 0 ? 0 : (value / benchmark * 100).clamp(0, 140).toDouble();

TrackerTrainingPlayerRow _avgRow(List<TrackerTrainingPlayerRow> rows) {
  final n = rows.length.toDouble();
  double avg(double Function(TrackerTrainingPlayerRow p) get) => rows.fold<double>(0, (a, p) => a + get(p)) / math.max(1, n);
  int avgi(int Function(TrackerTrainingPlayerRow p) get) => (rows.fold<int>(0, (a, p) => a + get(p)) / math.max(1, n)).round();
  return TrackerTrainingPlayerRow(
    name: 'СРЕДНЕЕ',
    duration: rows.isEmpty ? '00:00:00' : rows.first.duration,
    distanceM: avg((p) => p.distanceM),
    metersPerMin: avg((p) => p.metersPerMin),
    maxSpeedKmh: avg((p) => p.maxSpeedKmh),
    accelerations: avgi((p) => p.accelerations),
    decelerations: avgi((p) => p.decelerations),
    accDecPerMin: avg((p) => p.accDecPerMin),
    explosiveActions: avgi((p) => p.explosiveActions),
    v3RunM: avg((p) => p.v3RunM),
    v4HsrM: avg((p) => p.v4HsrM),
    v5SprintM: avg((p) => p.v5SprintM),
    sprintCount: avgi((p) => p.sprintCount),
    highSpeedWorkM: avg((p) => p.highSpeedWorkM),
    highSpeedActions: avgi((p) => p.highSpeedActions),
    playerLoad: avg((p) => p.playerLoad),
    heartRateMaxPercent: avg((p) => p.heartRateMaxPercent),
    hrExertion: avg((p) => p.hrExertion),
  );
}

TableRow _tableRow(List<String> values, {bool header = false}) {
  return TableRow(
    decoration: BoxDecoration(color: header ? const Color(0xFFE5E7EB) : Colors.white),
    children: values.map((v) => _cell(v, bold: header)).toList(),
  );
}

Widget _cell(String text, {bool bold = false, TextAlign align = TextAlign.center}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
    child: Text(text, textAlign: align, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: _R.text, fontSize: 11, fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
  );
}

Widget _heatCell(String text, double value, double max) {
  final ratio = (value / max).clamp(0, 1).toDouble();
  final color = ratio > .82 ? const Color(0xFFEF4444).withOpacity(.34) : ratio > .58 ? const Color(0xFFFACC15).withOpacity(.50) : const Color(0xFF22C55E).withOpacity(.20 + .25 * ratio);
  return Container(color: color, child: _cell(text, bold: ratio > .82));
}

Widget _barCell(String text, double value, double max, Color color) {
  final ratio = (value / max).clamp(0, 1).toDouble();
  return Stack(children: [
    Positioned.fill(child: FractionallySizedBox(widthFactor: ratio, alignment: Alignment.centerLeft, child: Container(color: color.withOpacity(.45)))),
    _cell(text),
  ]);
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(height: 120, alignment: Alignment.center, child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _R.muted, fontWeight: FontWeight.w800)));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _R.border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, color: _R.red, size: 44),
          const SizedBox(height: 10),
          Text(error, textAlign: TextAlign.center, style: const TextStyle(color: _R.text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Повторить')),
        ]),
      ),
    );
  }
}

class _R {
  static const bg = Color(0xFFF6F8FA);
  static const panel = Color(0xFFFFFFFF);
  static const border = Color(0xFFEEF2F5);
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF667085);
  static const darkGreen = Color(0xFF0B4F2D);
  static const green = Color(0xFF22C55E);
  static const lightGreen = Color(0xFFF1FBF6);
  static const lime = Color(0xFFA3E635);
  static const red = Color(0xFFEF4444);
}
