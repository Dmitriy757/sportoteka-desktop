
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tracker_pro_models.dart';
import 'tracker_training_report_api.dart';
import 'tracker_training_report_models.dart';

class TrackerTrainingReportPreviewDialog extends StatefulWidget {
  const TrackerTrainingReportPreviewDialog({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.session,
    required this.rosterPlayers,
  });

  final int teamId;
  final String teamName;
  final TrackerSessionModel session;
  final List<TrackerPlayerOption> rosterPlayers;

  @override
  State<TrackerTrainingReportPreviewDialog> createState() => _TrackerTrainingReportPreviewDialogState();
}

class _TrackerTrainingReportPreviewDialogState extends State<TrackerTrainingReportPreviewDialog> {
  late final TrackerTrainingReportApi _api;
  late final Future<TrackerTrainingReport> _future;

  @override
  void initState() {
    super.initState();
    _api = TrackerTrainingReportApi();
    _future = _api.loadTrainingReport(
      sessionId: widget.session.id,
      teamId: widget.teamId,
      fallbackSession: widget.session,
      rosterPlayers: widget.rosterPlayers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: width < 780 ? 8 : 28,
        vertical: width < 780 ? 8 : 22,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1280,
          maxHeight: height - 24,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: const Color(0xFFF4F5F6),
            child: FutureBuilder<TrackerTrainingReport>(
              future: _future,
              builder: (context, snapshot) {
                final loading = snapshot.connectionState == ConnectionState.waiting && snapshot.data == null;
                final report = snapshot.data;

                return DefaultTabController(
                  length: 5,
                  child: Column(
                    children: [
                      _ReportTopBar(
                        title: 'Отчёт по тренировке',
                        subtitle: '${widget.teamName} · ${widget.session.title}',
                        loading: loading,
                        onClose: () => Navigator.of(context).pop(),
                        onPdf: () => _copyExportUrl(_api.pdfUrl(sessionId: widget.session.id), 'PDF'),
                        onExcel: () => _copyExportUrl(_api.excelUrl(sessionId: widget.session.id), 'Excel/CSV'),
                      ),
                      const _ReportTabs(),
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : report == null
                                ? _ReportError(error: '${snapshot.error ?? 'Отчёт пока недоступен'}')
                                : TabBarView(
                                    children: [
                                      _SummaryView(report: report),
                                      _LocomotorView(report: report),
                                      _MechanicalView(report: report),
                                      _InternalLoadView(report: report),
                                      _MicrocycleView(report: report),
                                    ],
                                  ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyExportUrl(String url, String label) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label ссылка скопирована. Откройте её в браузере или подключите url_launcher.')),
    );
  }
}

class _ReportTopBar extends StatelessWidget {
  const _ReportTopBar({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onClose,
    required this.onPdf,
    required this.onExcel,
  });

  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onClose;
  final VoidCallback onPdf;
  final VoidCallback onExcel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F14),
        border: Border(bottom: BorderSide(color: Color(0xFFFF7A00), width: 3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'ST',
              style: TextStyle(
                color: Color(0xFF0B0F14),
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
          _TopButton(label: 'PDF', icon: Icons.picture_as_pdf_rounded, onTap: onPdf),
          const SizedBox(width: 8),
          _TopButton(label: 'Excel', icon: Icons.table_chart_rounded, onTap: onExcel),
          const SizedBox(width: 8),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: Colors.white)),
        ],
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportTabs extends StatelessWidget {
  const _ReportTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      color: Colors.white,
      child: const TabBar(
        isScrollable: true,
        labelColor: Color(0xFF0B0F14),
        unselectedLabelColor: Color(0xFF64748B),
        indicatorColor: Color(0xFFFF7A00),
        indicatorWeight: 3,
        labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        tabs: [
          Tab(text: 'Сводка'),
          Tab(text: 'Локомоторная'),
          Tab(text: 'Механическая'),
          Tab(text: 'Внутренняя'),
          Tab(text: 'Микроцикл'),
        ],
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final s = report.summary;
    return _ReportScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Общая сводка по тренировке'),
          _ResponsiveGrid(
            minTileWidth: 160,
            children: [
              _MetricCard(title: 'Время тренировки', value: s.trainingTime, subtitle: 'длительность'),
              _MetricCard(title: 'Средняя дистанция', value: s.averageDistanceM.toStringAsFixed(0), subtitle: 'м на игрока'),
              _MetricCard(title: 'Игроков', value: '${s.playersCount}', subtitle: 'участников'),
              _MetricCard(title: 'Player Load', value: s.playerLoad.toStringAsFixed(0), subtitle: 'нагрузка'),
              _MetricCard(title: 'High Speed Distance', value: s.highSpeedDistanceM.toStringAsFixed(0), subtitle: 'м'),
              _MetricCard(title: 'ACC/DEC', value: s.accDec.toStringAsFixed(1), subtitle: 'интенсивность'),
            ],
          ),
          const SizedBox(height: 16),
          _TwoColumn(
            left: _ChartCard(
              title: 'Динамика микроцикла',
              child: _MicrocycleChart(points: report.microcycle),
            ),
            right: _ChartCard(
              title: '% от средних значений матча',
              child: _SimpleBarChart(
                bars: report.mdComparison.isEmpty
                    ? const [
                        TrackerReportChartBar(label: 'Дистанция', value: 47),
                        TrackerReportChartBar(label: 'Метры/мин', value: 80),
                        TrackerReportChartBar(label: 'Макс. скорость', value: 71),
                        TrackerReportChartBar(label: 'Ускорения', value: 22),
                        TrackerReportChartBar(label: 'Торможения', value: 21),
                        TrackerReportChartBar(label: 'Спринты', value: 0),
                      ]
                    : report.mdComparison,
                suffix: '%',
                maxValue: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocomotorView extends StatelessWidget {
  const _LocomotorView({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return _ReportScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Локомоторная работа'),
          _LocomotorTable(rows: report.players),
        ],
      ),
    );
  }
}

class _MechanicalView extends StatelessWidget {
  const _MechanicalView({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return _ReportScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Механическая работа'),
          _TwoColumn(
            left: _ChartCard(title: 'Ускорения', child: _SimpleBarChart(bars: report.accelerations)),
            right: _ChartCard(title: 'Торможения', child: _SimpleBarChart(bars: report.decelerations)),
          ),
          const SizedBox(height: 14),
          _TwoColumn(
            left: _ChartCard(title: 'Ускорения / торможения — макс. инт.', child: _SimpleBarChart(bars: report.decelerations)),
            right: _ChartCard(title: 'Взрывные действия', child: _SimpleBarChart(bars: report.explosiveActions)),
          ),
        ],
      ),
    );
  }
}

class _InternalLoadView extends StatelessWidget {
  const _InternalLoadView({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return _ReportScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Внутренняя нагрузка'),
          _TwoColumn(
            left: _ChartCard(title: 'Время в зонах ЧСС', child: _StackedBars(rows: report.heartRateZones)),
            right: _ChartCard(title: 'Дистанция в зонах ЧСС', child: _StackedBars(rows: report.heartRateDistanceZones)),
          ),
          const SizedBox(height: 14),
          _TwoColumn(
            left: _ChartCard(title: 'Средний % от ЧСС макс', child: _SimpleBarChart(bars: report.players.map((e) => TrackerReportChartBar(label: e.shortName, value: 0)).toList())),
            right: _ChartCard(title: 'HR Exertion + Player Load', child: _SimpleBarChart(bars: report.players.map((e) => TrackerReportChartBar(label: e.shortName, value: 0)).toList())),
          ),
        ],
      ),
    );
  }
}

class _MicrocycleView extends StatelessWidget {
  const _MicrocycleView({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return _ReportScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Динамика микроцикла'),
          _ChartCard(
            title: 'Дистанция / HSR / ACC+DEC',
            child: _MicrocycleChart(points: report.microcycle),
          ),
          const SizedBox(height: 14),
          _ChartCard(
            title: 'Сравнение с матчевыми средними',
            child: _SimpleBarChart(bars: report.mdComparison, suffix: '%', maxValue: 100),
          ),
        ],
      ),
    );
  }
}

class _ReportScroll extends StatelessWidget {
  const _ReportScroll({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF0F5132),
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.subtitle});
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w900)),
        const Spacer(),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 26, fontWeight: FontWeight.w900)),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children, this.minTileWidth = 180});
  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final count = (c.maxWidth / minTileWidth).floor().clamp(1, 6);
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: count,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.75,
        children: children,
      );
    });
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 860) {
        return Column(children: [left, const SizedBox(height: 14), right]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ]);
    });
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFF0F5132), fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Expanded(child: child),
      ]),
    );
  }
}

class _SimpleBarChart extends StatelessWidget {
  const _SimpleBarChart({required this.bars, this.suffix = '', this.maxValue});
  final List<TrackerReportChartBar> bars;
  final String suffix;
  final double? maxValue;

  @override
  Widget build(BuildContext context) {
    final source = bars.isEmpty
        ? const [TrackerReportChartBar(label: 'Нет данных', value: 0)]
        : bars;
    final max = maxValue ?? source.map((e) => e.value).fold<double>(1, (a, b) => b > a ? b : a);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: source.map((bar) {
        final ratio = max <= 0 ? 0.0 : (bar.value / max).clamp(0.0, 1.0).toDouble();
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${bar.value.toStringAsFixed(bar.value % 1 == 0 ? 0 : 1)}$suffix', style: const TextStyle(color: Color(0xFF334155), fontSize: 9, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: ratio,
                      widthFactor: .7,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA3E635),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 42,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(bar.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Color(0xFF475569), fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MicrocycleChart extends StatelessWidget {
  const _MicrocycleChart({required this.points});
  final List<TrackerMicrocyclePoint> points;

  @override
  Widget build(BuildContext context) {
    final bars = points.isEmpty
        ? const [
            TrackerMicrocyclePoint(label: 'Тр-4', distanceM: 0, hsrM: 0, accDec: 0),
            TrackerMicrocyclePoint(label: 'Тр-3', distanceM: 0, hsrM: 0, accDec: 0),
            TrackerMicrocyclePoint(label: 'Тр-2', distanceM: 0, hsrM: 0, accDec: 0),
            TrackerMicrocyclePoint(label: 'Текущая', distanceM: 0, hsrM: 0, accDec: 0),
          ]
        : points;

    return _SimpleBarChart(
      bars: bars.map((e) => TrackerReportChartBar(label: e.label, value: e.distanceM)).toList(),
    );
  }
}

class _StackedBars extends StatelessWidget {
  const _StackedBars({required this.rows});
  final List<TrackerReportStackedBar> rows;

  @override
  Widget build(BuildContext context) {
    final source = rows.isEmpty ? const [TrackerReportStackedBar(label: 'Нет данных', low: 0, mid: 0, high: 0)] : rows;
    final max = source.map((e) => e.low + e.mid + e.high).fold<double>(1, (a, b) => b > a ? b : a);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: source.map((row) {
        final total = row.low + row.mid + row.high;
        final ratio = max <= 0 ? 0.0 : (total / max).clamp(0.0, 1.0).toDouble();
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: ratio,
                      widthFactor: .7,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(flex: row.high.round().clamp(1, 1000), child: Container(color: const Color(0xFFF87171))),
                          Expanded(flex: row.mid.round().clamp(1, 1000), child: Container(color: const Color(0xFFFBBF24))),
                          Expanded(flex: row.low.round().clamp(1, 1000), child: Container(color: const Color(0xFFA3E635))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 42,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Color(0xFF475569), fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LocomotorTable extends StatelessWidget {
  const _LocomotorTable({required this.rows});
  final List<TrackerTrainingPlayerRow> rows;

  @override
  Widget build(BuildContext context) {
    final data = rows.isEmpty
        ? const <TrackerTrainingPlayerRow>[]
        : rows;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(const Color(0xFFE5E7EB)),
          dataRowMinHeight: 42,
          dataRowMaxHeight: 46,
          headingTextStyle: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w900),
          dataTextStyle: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w700),
          columns: const [
            DataColumn(label: Text('№')),
            DataColumn(label: Text('Фамилия')),
            DataColumn(label: Text('Время')),
            DataColumn(label: Text('Дистанция')),
            DataColumn(label: Text('М/мин')),
            DataColumn(label: Text('Макс')),
            DataColumn(label: Text('Ускор.')),
            DataColumn(label: Text('Торм.')),
            DataColumn(label: Text('УСК+ТОР')),
            DataColumn(label: Text('Взрывн.')),
            DataColumn(label: Text('V3 Бег')),
            DataColumn(label: Text('V4 ВСБ')),
            DataColumn(label: Text('V5 Спринт')),
            DataColumn(label: Text('Спринты')),
            DataColumn(label: Text('V4+V5')),
            DataColumn(label: Text('ВС действия')),
          ],
          rows: [
            ...data.map((r) => DataRow(cells: [
                  DataCell(Text(r.number)),
                  DataCell(Text(r.name)),
                  DataCell(Text(r.duration)),
                  DataCell(_HeatCell(value: r.distanceM.toStringAsFixed(0), level: r.distanceM)),
                  DataCell(_HeatCell(value: r.metersPerMin.toStringAsFixed(1), level: r.metersPerMin)),
                  DataCell(_HeatCell(value: r.maxSpeedKmh.toStringAsFixed(1), level: r.maxSpeedKmh)),
                  DataCell(_HeatCell(value: '${r.accelerations}', level: r.accelerations.toDouble())),
                  DataCell(_HeatCell(value: '${r.decelerations}', level: r.decelerations.toDouble(), danger: true)),
                  DataCell(_HeatCell(value: r.accDecPerMin.toStringAsFixed(1), level: r.accDecPerMin)),
                  DataCell(_HeatCell(value: '${r.explosiveActions}', level: r.explosiveActions.toDouble(), danger: true)),
                  DataCell(Text(r.runV3M.toStringAsFixed(0))),
                  DataCell(Text(r.hsrV4M.toStringAsFixed(0))),
                  DataCell(Text(r.sprintV5M.toStringAsFixed(0))),
                  DataCell(Text('${r.sprintCount}')),
                  DataCell(_HeatCell(value: r.highSpeedWorkM.toStringAsFixed(0), level: r.highSpeedWorkM)),
                  DataCell(Text('${r.highSpeedActions}')),
                ])),
            if (data.isNotEmpty) _averageRow(data),
          ],
        ),
      ),
    );
  }

  DataRow _averageRow(List<TrackerTrainingPlayerRow> rows) {
    double avg(double Function(TrackerTrainingPlayerRow) getter) => rows.map(getter).fold<double>(0, (a,b)=>a+b) / rows.length;
    int sumInt(int Function(TrackerTrainingPlayerRow) getter) => rows.map(getter).fold<int>(0, (a,b)=>a+b);

    return DataRow(
      color: MaterialStateProperty.all(const Color(0xFFE5E7EB)),
      cells: [
        const DataCell(Text('')),
        const DataCell(Text('СРЕДНЕЕ', style: TextStyle(fontWeight: FontWeight.w900))),
        const DataCell(Text('')),
        DataCell(Text(avg((e) => e.distanceM).toStringAsFixed(0))),
        DataCell(Text(avg((e) => e.metersPerMin).toStringAsFixed(0))),
        DataCell(Text(avg((e) => e.maxSpeedKmh).toStringAsFixed(0))),
        DataCell(Text(avg((e) => e.accelerations.toDouble()).toStringAsFixed(0))),
        DataCell(Text(avg((e) => e.decelerations.toDouble()).toStringAsFixed(0))),
        DataCell(Text(avg((e) => e.accDecPerMin).toStringAsFixed(1))),
        DataCell(Text(avg((e) => e.explosiveActions.toDouble()).toStringAsFixed(0))),
        DataCell(Text(avg((e) => e.runV3M).toStringAsFixed(0))),
        DataCell(Text(avg((e) => e.hsrV4M).toStringAsFixed(0))),
        DataCell(Text(avg((e) => e.sprintV5M).toStringAsFixed(0))),
        DataCell(Text('${sumInt((e) => e.sprintCount)}')),
        DataCell(Text(avg((e) => e.highSpeedWorkM).toStringAsFixed(0))),
        DataCell(Text('${sumInt((e) => e.highSpeedActions)}')),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.value, required this.level, this.danger = false});
  final String value;
  final double level;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final opacity = (level.abs() / 100).clamp(.12, .65).toDouble();
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: danger ? Colors.red.withOpacity(opacity) : Colors.green.withOpacity(opacity),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
    );
  }
}
