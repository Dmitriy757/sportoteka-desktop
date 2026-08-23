import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/add_personal_training_screen/add_personal_training_screen.dart';
import 'training_detail_screen.dart';

class FeedPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);

  static const lightGreen = Color(0xFFE8F5E9);
  static const superLightGreen = Color(0xFFF2FFF5);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);

  static const background = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);
  static const gold = Color(0xFFFFC83D);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class MyTrainingsScreen extends StatefulWidget {
  const MyTrainingsScreen({super.key});

  @override
  State<MyTrainingsScreen> createState() => _MyTrainingsScreenState();
}

class _MyTrainingsScreenState extends State<MyTrainingsScreen> {
  List<dynamic> trainings = [];
  bool isLoading = false;
  bool isRefreshing = false;

  double avgRating = 0;
  int weekCount = 0;
  int streakDays = 0;
  int myScore = 0;
  double weekProgress = 0;

  @override
  void initState() {
    super.initState();
    _fetchTrainings();
  }

  Future<void> _fetchTrainings() async {
    if (!mounted) return;

    setState(() {
      if (trainings.isEmpty) isLoading = true;
      isRefreshing = true;
    });

    try {
      final userId = await PrefUtils.getUserId();
      final response = await http.get(
        Uri.parse(
          'https://sportotekaapp.ru/api/get_personal_trainings.php?user_id=$userId',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        trainings = data is List ? data : [];
      } else {
        trainings = [];
      }
    } catch (_) {
      trainings = [];
    }

    _recalcAggregates();

    if (!mounted) return;
    setState(() {
      isLoading = false;
      isRefreshing = false;
    });
  }

  void _recalcAggregates() {
    if (trainings.isEmpty) {
      avgRating = 0;
      weekCount = 0;
      streakDays = 0;
      myScore = 0;
      weekProgress = 0;
      return;
    }

    final ratings = trainings
        .map((e) => double.tryParse((e['rating'] ?? '0').toString()))
        .whereType<double>()
        .toList();

    avgRating = ratings.isEmpty
        ? 0
        : ratings.reduce((a, b) => a + b) / ratings.length;
    avgRating = avgRating.clamp(0, 5);

    final now = DateTime.now();
    final start7 = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));

    weekCount = trainings.where((e) {
      final d = _parseDate(e['date']);
      return d != null && !d.isBefore(start7) && !d.isAfter(now);
    }).length;

    weekProgress = (weekCount / 7).clamp(0, 1);

    streakDays = _calcStreakDays(trainings);

    final score = (avgRating / 5.0) * 60 +
        (min(weekCount, 7) / 7.0) * 25 +
        (min(streakDays, 14) / 14.0) * 15;

    myScore = score.round().clamp(0, 100);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  int _calcStreakDays(List list) {
    if (list.isEmpty) return 0;

    final days = <String>{};
    for (final e in list) {
      final d = _parseDate(e['date']);
      if (d != null) {
        days.add(DateFormat('yyyy-MM-dd').format(d));
      }
    }

    if (days.isEmpty) return 0;

    int streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);

    while (true) {
      final key = DateFormat('yyyy-MM-dd').format(cursor);
      if (days.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  Future<void> _openAddTraining() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPersonalTrainingScreen()),
    );

    if (result == true) {
      await _fetchTrainings();
    }
  }

  Future<void> _openTrainingDetail(dynamic training) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingDetailScreen(training: training),
      ),
    );

    if (result == true) {
      await _fetchTrainings();
    }
  }

  String _formatTrainingDate(dynamic value) {
    final d = _parseDate(value);
    if (d == null) return 'Без даты';
    return DateFormat('dd.MM.yyyy').format(d);
  }

  double _ratingOf(dynamic training) {
    return double.tryParse((training['rating'] ?? '0').toString()) ?? 0;
  }

  Widget _whiteCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FeedPalette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FeedPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, {String? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: FeedPalette.text,
            ),
          ),
        ),
        if (action != null)
          Text(
            action,
            style: const TextStyle(
              color: FeedPalette.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _metricChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FeedPalette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FeedPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FeedPalette.primaryGreen),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: FeedPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final totalCount = trainings.length;
    final bestRating = trainings
        .map((e) => double.tryParse((e['rating'] ?? '0').toString()) ?? 0)
        .fold<double>(0, (p, c) => max(p, c));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FeedPalette.primaryGreen.withOpacity(0.12),
            FeedPalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FeedPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: FeedPalette.greenGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мои тренировки',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: FeedPalette.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Прогресс, статистика и история занятий',
                      style: TextStyle(
                        color: FeedPalette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: FeedPalette.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: FeedPalette.border),
                ),
                child: Text(
                  '$totalCount тренировок',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: FeedPalette.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(Icons.emoji_events_rounded, 'Рейтинг $myScore'),
              _metricChip(Icons.local_fire_department_rounded, 'Стрик $streakDays'),
              _metricChip(Icons.star_rounded, avgRating.toStringAsFixed(1)),
              _metricChip(Icons.workspace_premium_rounded, 'Лучший ${bestRating.toStringAsFixed(1)}'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FeedPalette.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FeedPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Активность за 7 дней',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: FeedPalette.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$weekCount тренировок из 7',
                  style: const TextStyle(
                    color: FeedPalette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: weekProgress,
                    minHeight: 8,
                    backgroundColor: FeedPalette.lightGreen,
                    color: FeedPalette.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard() {
    return InkWell(
      onTap: _openAddTraining,
      borderRadius: BorderRadius.circular(18),
      child: _whiteCard(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: FeedPalette.greenGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Добавить новую тренировку',
                style: TextStyle(
                  color: FeedPalette.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: FeedPalette.superLightGreen,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: FeedPalette.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: const Text(
                'Создать',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: FeedPalette.primaryGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final sorted = [...trainings];
    sorted.sort((a, b) {
      final ad = _parseDate(a['date']) ?? DateTime(1970);
      final bd = _parseDate(b['date']) ?? DateTime(1970);
      return ad.compareTo(bd);
    });

    final slice = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;
    final values = slice
        .map((e) => double.tryParse((e['rating'] ?? '0').toString()) ?? 0)
        .toList();

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Динамика оценок', action: '7 последних'),
          const SizedBox(height: 6),
          const Text(
            'График показывает оценки последних тренировок',
            style: TextStyle(
              color: FeedPalette.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: values.isEmpty
                ? const Center(
                    child: Text(
                      'Нет данных для графика',
                      style: TextStyle(
                        color: FeedPalette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 5,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: FeedPalette.border,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: FeedPalette.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: FeedPalette.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            values.length,
                            (i) => FlSpot((i + 1).toDouble(), values[i]),
                          ),
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: FeedPalette.primaryGreen,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: FeedPalette.white,
                                strokeWidth: 2,
                                strokeColor: FeedPalette.primaryGreen,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                FeedPalette.primaryGreen.withOpacity(0.18),
                                FeedPalette.primaryGreen.withOpacity(0.02),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingCard(dynamic training) {
    final type = (training['type'] ?? 'Тренировка').toString();
    final sport = (training['sport'] ?? 'Спорт').toString();
    final dateText = _formatTrainingDate(training['date']);
    final duration = (training['duration'] ?? '').toString();
    final comment = (training['comment'] ?? '').toString();
    final rating = _ratingOf(training);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openTrainingDetail(training),
        child: _whiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: FeedPalette.greenGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(
                      Icons.directions_run_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: FeedPalette.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sport,
                          style: const TextStyle(
                            color: FeedPalette.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: FeedPalette.superLightGreen,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: FeedPalette.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: FeedPalette.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: FeedPalette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metricChip(Icons.calendar_today_rounded, dateText),
                  if (duration.isNotEmpty)
                    _metricChip(Icons.schedule_rounded, '$duration мин'),
                ],
              ),
              if (comment.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  comment,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: FeedPalette.text,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _openTrainingDetail(training),
                  style: TextButton.styleFrom(
                    foregroundColor: FeedPalette.primaryGreen,
                  ),
                  child: const Text(
                    'Подробнее',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    Widget bar({double w = 120, double h = 10}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(999),
          ),
        );

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(w: 150),
                  const SizedBox(height: 8),
                  bar(w: 90, h: 9),
                ],
              ),
              const Spacer(),
              bar(w: 60, h: 26),
            ],
          ),
          const SizedBox(height: 12),
          bar(w: 100, h: 28),
          const SizedBox(height: 8),
          bar(w: 90, h: 28),
          const SizedBox(height: 12),
          bar(w: double.infinity, h: 10),
          const SizedBox(height: 8),
          bar(w: 220, h: 10),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return _whiteCard(
      child: Column(
        children: [
          const Icon(
            Icons.fitness_center_rounded,
            size: 34,
            color: FeedPalette.textMuted,
          ),
          const SizedBox(height: 10),
          const Text(
            'Пока нет тренировок',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: FeedPalette.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Создайте первую тренировку — она появится в списке.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FeedPalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              gradient: FeedPalette.greenGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextButton.icon(
              onPressed: _openAddTraining,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Создать тренировку',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FeedPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: FeedPalette.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Мои тренировки',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: FeedPalette.text,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Новая тренировка',
            onPressed: _openAddTraining,
            icon: Container(
              decoration: BoxDecoration(
                gradient: FeedPalette.greenGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTrainings,
        color: FeedPalette.primaryGreen,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 12),
            _buildQuickActionCard(),
            const SizedBox(height: 12),
            _buildProgressCard(),
            const SizedBox(height: 12),
            _buildSectionTitle(
              'История тренировок',
              action: '${trainings.length}',
            ),
            const SizedBox(height: 8),
            if (isLoading && trainings.isEmpty) ...[
              _buildSkeletonCard(),
              const SizedBox(height: 10),
              _buildSkeletonCard(),
              const SizedBox(height: 10),
              _buildSkeletonCard(),
            ] else if (trainings.isEmpty) ...[
              _buildEmptyState(),
            ] else ...[
              ...List.generate(
                trainings.length,
                (i) => _buildTrainingCard(trainings[i]),
              ),
              const SizedBox(height: 8),
              if (isRefreshing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: CircularProgressIndicator(
                      color: FeedPalette.primaryGreen,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}