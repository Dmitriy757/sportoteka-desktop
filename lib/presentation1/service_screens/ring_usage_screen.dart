// lib/presentation/service_screens/ring_usage_screen.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/core/constants/app_colors.dart';

/// ✅ FC Gomel styled: Trackers / Heatmap / Reports (DEMO)
/// - Витрина: 2 баннера сверху (как в дашборде, но зелёные)
/// - Карточки как AppColors.card + AppColors.cardShadow
/// - Секции как в TeamDashboardScreen
/// - Псевдо-live поле (CustomPaint) + треки + теплокарта
/// - Командная сводка и карточка устройства
class RingUsageScreen extends StatefulWidget {
  const RingUsageScreen({super.key});

  @override
  State<RingUsageScreen> createState() => _RingUsageScreenState();
}

class _RingUsageScreenState extends State<RingUsageScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;
  final _rng = Random(9);

  int selectedPlayer = 0;
  bool heatmapOn = true;
  bool trailsOn = true;

  late List<_SimPlayer> players;

  @override
  void initState() {
    super.initState();
    players = List.generate(3, (i) => _SimPlayer.seed(i + 1));
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )
      ..addListener(_onFrame)
      ..repeat();
  }

  void _onFrame() {
    for (final p in players) {
      p.step(_rng);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = players[selectedPlayer];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          title: const Text(
            "Трекеры ФК «Гомель»",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              tooltip: "Тепловая карта",
              onPressed: () => setState(() => heatmapOn = !heatmapOn),
              icon: Icon(
                heatmapOn
                    ? Icons.local_fire_department
                    : Icons.local_fire_department_outlined,
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              tooltip: "Треки",
              onPressed: () => setState(() => trailsOn = !trailsOn),
              icon: Icon(
                trailsOn ? Icons.route : Icons.route_outlined,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelStyle: TextStyle(fontWeight: FontWeight.w900),
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.primaryGreen,
            tabs: [
              Tab(text: "Live поле"),
              Tab(text: "Сессия"),
              Tab(text: "Аналитика"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LiveTab(
              players: players,
              selectedIndex: selectedPlayer,
              heatmapOn: heatmapOn,
              trailsOn: trailsOn,
              onSelect: (i) => setState(() => selectedPlayer = i),
            ),
            _SessionTab(player: p),
            _AnalyticsTab(player: p),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// LIVE TAB
/// =======================
class _LiveTab extends StatelessWidget {
  final List<_SimPlayer> players;
  final int selectedIndex;
  final bool heatmapOn;
  final bool trailsOn;
  final ValueChanged<int> onSelect;

  const _LiveTab({
    required this.players,
    required this.selectedIndex,
    required this.heatmapOn,
    required this.trailsOn,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final selected = players[selectedIndex];
    final team = _TeamAgg.from(players);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: _GomelHeroBanner(
            title: "Система трекинга игроков",
            subtitle:
                "GPS • теплокарта • скорость • пульс • отчёты\n(демонстрационный режим)",
            rightIcon: Icons.sports_soccer_rounded,
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: _MiniActionBanner(
                  title: "Отчёт",
                  subtitle: "PDF / Excel (демо)",
                  icon: Icons.assignment_outlined,
                  onTap: () => _snack("Отчёт (демо)"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniActionBanner(
                  title: "Экспорт",
                  subtitle: "CSV / GPX (демо)",
                  icon: Icons.file_download_outlined,
                  onTap: () => _snack("Экспорт (демо)"),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(title: "Live поле", right: "демо"),
              const SizedBox(height: 8),
              _PitchCard(
                players: players,
                selectedIndex: selectedIndex,
                heatmapOn: heatmapOn,
                trailsOn: trailsOn,
              ),
              const SizedBox(height: 16),

              _SectionTitle(
                title: "Игроки (Live)",
                right: "всего: ${players.length}",
              ),
              const SizedBox(height: 8),
              _GomelCard(
                child: Column(
                  children: [
                    for (int i = 0; i < players.length; i++) ...[
                      _PlayerTile(
                        isSelected: i == selectedIndex,
                        name: players[i].name,
                        pos: players[i].position,
                        number: players[i].number,
                        hr: players[i].hr,
                        speed: players[i].speedKmh,
                        distanceKm: players[i].distanceMeters / 1000.0,
                        load: players[i].loadScore,
                        onTap: () => onSelect(i),
                      ),
                      if (i != players.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const _SectionTitle(title: "Командная сводка", right: "демо"),
              const SizedBox(height: 8),
              _GomelCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatPill(
                            title: "Средний пульс",
                            value: "${team.avgHr} bpm",
                            icon: Icons.favorite_border,
                            accent: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatPill(
                            title: "Сумма дистанции",
                            value:
                                "${team.sumDistanceKm.toStringAsFixed(2)} км",
                            icon: Icons.route_outlined,
                            accent: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatPill(
                            title: "Спринты",
                            value: "${team.sumSprints}",
                            icon: Icons.flash_on_outlined,
                            accent: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatPill(
                            title: "Топ скорость",
                            value:
                                "${team.topSpeed.toStringAsFixed(1)} км/ч",
                            icon: Icons.speed_rounded,
                            accent: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _CoachActionChip(
                            icon: Icons.play_circle_outline,
                            text: "Видео-анализ",
                            onTap: () => _snack("Видео-анализ (демо)"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CoachActionChip(
                            icon: Icons.assignment_outlined,
                            text: "Протокол",
                            onTap: () => _snack("Протокол (демо)"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CoachActionChip(
                            icon: Icons.ios_share_outlined,
                            text: "Поделиться",
                            onTap: () => _snack("Поделиться (демо)"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const _SectionTitle(title: "Зоны активности", right: "демо"),
              const SizedBox(height: 8),
              _GomelCard(
                child: Column(
                  children: [
                    _ZonesMiniMap(
                      l: selected.zoneL,
                      c: selected.zoneC,
                      r: selected.zoneR,
                      defThird: selected.zoneDefThird,
                      midThird: selected.zoneMidThird,
                      attThird: selected.zoneAttThird,
                    ),
                    const SizedBox(height: 12),
                    _MiniLine(
                      icon: Icons.view_week_outlined,
                      title: "Левый фланг",
                      value: "${(selected.zoneL * 100).round()}%",
                      progress: selected.zoneL,
                      accent: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const _SectionTitle(title: "Трекер: характеристики", right: "демо"),
              const SizedBox(height: 8),
              const _DeviceSpecsCard(),
            ],
          ),
        ),
      ],
    );
  }
}

/// =======================
/// SESSION TAB
/// =======================
class _SessionTab extends StatelessWidget {
  final _SimPlayer player;
  const _SessionTab({required this.player});

  @override
  Widget build(BuildContext context) {
    final distanceKm = player.distanceMeters / 1000.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _GomelHeroBanner(
          title: "Сводка сессии",
          subtitle: "Нагрузка • ускорения • пульс • спринты (демо)",
          rightIcon: Icons.analytics_outlined,
        ),
        const SizedBox(height: 12),

        const _SectionTitle(title: "Показатели", right: "демо"),
        const SizedBox(height: 8),
        _GomelCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatPill(
                      title: "Дистанция",
                      value: "${distanceKm.toStringAsFixed(2)} км",
                      icon: Icons.route_outlined,
                      accent: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatPill(
                      title: "Топ скорость",
                      value: "${player.maxSpeedKmh.toStringAsFixed(1)} км/ч",
                      icon: Icons.speed_rounded,
                      accent: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatPill(
                      title: "Спринты",
                      value: "${player.sprints}",
                      icon: Icons.flash_on_outlined,
                      accent: const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatPill(
                      title: "Нагрузка",
                      value: "${player.loadScore}",
                      icon: Icons.stacked_line_chart_outlined,
                      accent: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const _SectionTitle(title: "Интенсивность", right: "демо"),
        const SizedBox(height: 8),
        _GomelCard(
          child: Column(
            children: [
              _MiniLine(
                icon: Icons.trending_up_rounded,
                title: "Ускорения",
                value: "${player.accelerations}",
                progress: (player.accelerations / 30).clamp(0.0, 1.0),
                accent: AppColors.primaryGreen,
              ),
              const SizedBox(height: 10),
              _MiniLine(
                icon: Icons.trending_down_rounded,
                title: "Торможения",
                value: "${player.decelerations}",
                progress: (player.decelerations / 30).clamp(0.0, 1.0),
                accent: AppColors.error,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const _SectionTitle(title: "Пульс: зоны", right: "демо"),
        const SizedBox(height: 8),
        _GomelCard(child: _HeartZonesDemo(hrAvg: player.hr, hrMax: player.hrMax)),

        const SizedBox(height: 12),
        const _SectionTitle(title: "Скорость по отрезкам", right: "демо"),
        const SizedBox(height: 8),
        const _GomelCard(
          child: SizedBox(height: 140, child: _BarsMock()),
        ),
      ],
    );
  }
}

/// =======================
/// ANALYTICS TAB
/// =======================
class _AnalyticsTab extends StatelessWidget {
  final _SimPlayer player;
  const _AnalyticsTab({required this.player});

  @override
  Widget build(BuildContext context) {
    final acute = (player.loadScore * 7).clamp(200, 900);
    final chronic = (player.loadScore * 6).clamp(240, 950);
    final acwr = acute / chronic;

    String risk;
    Color riskColor;
    if (acwr < 0.80) {
      risk = "Недонагрузка";
      riskColor = const Color(0xFF60A5FA);
    } else if (acwr <= 1.30) {
      risk = "Оптимально";
      riskColor = const Color(0xFF10B981);
    } else if (acwr <= 1.50) {
      risk = "Повышенный риск";
      riskColor = const Color(0xFFF59E0B);
    } else {
      risk = "Перегруз";
      riskColor = const Color(0xFFFF6B6B);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _GomelHeroBanner(
          title: "Аналитика нагрузки",
          subtitle: "ACWR • риск перегруза • рекомендации (демо)",
          rightIcon: Icons.shield_outlined,
        ),
        const SizedBox(height: 12),

        const _SectionTitle(title: "Риск и статус", right: "демо"),
        const SizedBox(height: 8),
        _GomelCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatPill(
                      title: "ACWR",
                      value: acwr.toStringAsFixed(2),
                      icon: Icons.timeline_outlined,
                      accent: riskColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatPill(
                      title: "Статус",
                      value: risk,
                      icon: Icons.gpp_good_outlined,
                      accent: riskColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RiskBar(acwr: acwr),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const _SectionTitle(title: "AI-рекомендации тренеру", right: "демо"),
        const SizedBox(height: 8),
        const _GomelCard(
          child: Column(
            children: [
              _InsightTile(
                icon: Icons.sports_soccer_outlined,
                title: "Интенсивность",
                text:
                    "Сегодня много ускорений. В конце сессии лучше техника/координация без добивания объёма.",
              ),
              SizedBox(height: 10),
              _InsightTile(
                icon: Icons.shield_outlined,
                title: "Риск перегруза",
                text:
                    "Если завтра матч/двусторонка — сократи объём, оставь реакцию и первые шаги.",
              ),
              SizedBox(height: 10),
              _InsightTile(
                icon: Icons.bedtime_outlined,
                title: "Восстановление",
                text:
                    "Сон +30 минут и лёгкое кардио 12–15 минут улучшит готовность.",
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// =======================
/// HERO / BANNERS (Gomel style)
/// =======================
class _GomelHeroBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData rightIcon;

  const _GomelHeroBanner({
    required this.title,
    required this.subtitle,
    required this.rightIcon,
  });

  @override
  Widget build(BuildContext context) {
    final g = AppColors.primaryGreen;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.card,
        boxShadow: [AppColors.cardShadow],
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              g.withOpacity(0.98),
              g.withOpacity(0.80),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              bottom: -26,
              child: _GlowCircle(color: Colors.white.withOpacity(0.16), size: 130),
            ),
            Positioned(
              left: -30,
              top: -30,
              child: _GlowCircle(color: Colors.white.withOpacity(0.10), size: 120),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFE9F7EF),
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          _HeroPill(icon: Icons.lock_outline, text: "Secure"),
                          SizedBox(width: 8),
                          _HeroPill(icon: Icons.wifi_tethering_outlined, text: "Live"),
                          SizedBox(width: 8),
                          _HeroPill(icon: Icons.file_present_outlined, text: "Reports"),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.22)),
                  ),
                  child: Icon(rightIcon, color: Colors.white, size: 34),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniActionBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MiniActionBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [AppColors.cardShadow],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// Section title (как в дашборде)
/// =======================
class _SectionTitle extends StatelessWidget {
  final String title;
  final String right;

  const _SectionTitle({required this.title, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Text(
          right,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// =======================
/// Card shell (как AppColors.card)
/// =======================
class _GomelCard extends StatelessWidget {
  final Widget child;
  const _GomelCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.card,
        boxShadow: [AppColors.cardShadow],
      ),
      child: child,
    );
  }
}

/// =======================
/// PITCH CARD (green FC Gomel field)
/// =======================
class _PitchCard extends StatelessWidget {
  final List<_SimPlayer> players;
  final int selectedIndex;
  final bool heatmapOn;
  final bool trailsOn;

  const _PitchCard({
    required this.players,
    required this.selectedIndex,
    required this.heatmapOn,
    required this.trailsOn,
  });

  @override
  Widget build(BuildContext context) {
    final selected = players[selectedIndex];

    return Container(
      height: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.card,
        boxShadow: [AppColors.cardShadow],
      ),
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
            if (heatmapOn)
              Positioned.fill(
                child: CustomPaint(
                  painter: _HeatPainter(
                    points: selected.heatPoints,
                    intensity: selected.intensity,
                    gomel: true,
                  ),
                ),
              ),
            if (trailsOn)
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrailPainter(
                    trails: players.map((e) => e.trail).toList(),
                    selected: selectedIndex,
                    gomel: true,
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: _PlayersPainter(
                  players: players,
                  selected: selectedIndex,
                  gomel: true,
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 10,
              child: Row(
                children: [
                  _GlassBadge(
                    icon: Icons.sensors_rounded,
                    text: "Live",
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GlassBadge(
                      icon: Icons.gps_fixed,
                      text:
                          "GPS ${(selected.gpsQuality * 100).round()}% • HR ${selected.hr}",
                    ),
                  ),
                  const SizedBox(width: 8),
                  _GlassBadge(
                    icon: Icons.speed_rounded,
                    text: "${selected.speedKmh.toStringAsFixed(1)} км/ч",
                  ),
                ],
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                children: const [
                  _LegendDot(text: "Выбран", color: AppColors.primaryGreen),
                  SizedBox(width: 8),
                  _LegendDot(text: "Игрок", color: Color(0xFF22C55E)),
                  SizedBox(width: 8),
                  _LegendDot(text: "Интенсивно", color: Color(0xFFF59E0B)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GlassBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String text;
  final Color color;

  const _LegendDot({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 7),
              Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// Player tile (gomel card style)
/// =======================
class _PlayerTile extends StatelessWidget {
  final bool isSelected;
  final String name;
  final String pos;
  final int number;
  final int hr;
  final double speed;
  final double distanceKm;
  final int load;
  final VoidCallback onTap;

  const _PlayerTile({
    required this.isSelected,
    required this.name,
    required this.pos,
    required this.number,
    required this.hr,
    required this.speed,
    required this.distanceKm,
    required this.load,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = isSelected
        ? AppColors.primaryGreen.withOpacity(0.35)
        : Colors.black.withOpacity(0.06);

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: isSelected ? 1.4 : 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    "$number",
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(pos, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _TinyPill(icon: Icons.favorite_border, text: "$hr bpm"),
                        _TinyPill(icon: Icons.speed_rounded, text: "${speed.toStringAsFixed(1)} км/ч"),
                        _TinyPill(icon: Icons.route_outlined, text: "${distanceKm.toStringAsFixed(2)} км"),
                        _TinyPill(icon: Icons.stacked_line_chart_outlined, text: "Load $load"),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppColors.primaryGreen : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TinyPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

/// =======================
/// Stats / Lines / Chips
/// =======================
class _StatPill extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _StatPill({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 3),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final double progress;
  final Color accent;

  const _MiniLine({
    required this.icon,
    required this.title,
    required this.value,
    required this.progress,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: p,
                    minHeight: 8,
                    backgroundColor: Colors.black.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _CoachActionChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _CoachActionChip({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Icon(icon, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.textPrimary),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// Zones Mini Map
/// =======================
class _ZonesMiniMap extends StatelessWidget {
  final double l, c, r;
  final double defThird, midThird, attThird;

  const _ZonesMiniMap({
    required this.l,
    required this.c,
    required this.r,
    required this.defThird,
    required this.midThird,
    required this.attThird,
  });

  Color _heat(double v) {
    if (v < 0.22) return const Color(0xFF93C5FD);
    if (v < 0.45) return const Color(0xFF60A5FA);
    if (v < 0.68) return const Color(0xFFF59E0B);
    return const Color(0xFFFF6B6B);
  }

  Widget _cell(String label, double v) {
    return Expanded(
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _heat(v).withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            "$label\n${(v * 100).round()}%",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
              height: 1.05,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          _cell("Left", l),
          const SizedBox(width: 8),
          _cell("Center", c),
          const SizedBox(width: 8),
          _cell("Right", r),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _cell("Def", defThird),
          const SizedBox(width: 8),
          _cell("Mid", midThird),
          const SizedBox(width: 8),
          _cell("Att", attThird),
        ]),
      ],
    );
  }
}

/// =======================
/// Device Specs card
/// =======================
class _DeviceSpecsCard extends StatelessWidget {
  const _DeviceSpecsCard();

  @override
  Widget build(BuildContext context) {
    return _GomelCard(
      child: Column(
        children: const [
          _SpecRow(icon: Icons.gps_fixed, title: "GPS частота", value: "10 Hz"),
          SizedBox(height: 10),
          _SpecRow(icon: Icons.sensors_outlined, title: "IMU (ACC/Gyro)", value: "100 Hz"),
          SizedBox(height: 10),
          _SpecRow(icon: Icons.favorite_border, title: "HR sampling", value: "1 sec"),
          SizedBox(height: 10),
          _SpecRow(icon: Icons.bluetooth, title: "Связь", value: "BLE + Wi-Fi Sync"),
          SizedBox(height: 10),
          _SpecRow(icon: Icons.battery_full, title: "Батарея", value: "до 14 часов"),
          SizedBox(height: 10),
          _SpecRow(icon: Icons.lock_outline, title: "Шифрование", value: "TLS + Device Token"),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SpecRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
          Text(value, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/// =======================
/// Heart zones / Bars / Risk / Insight
/// =======================
class _HeartZonesDemo extends StatelessWidget {
  final int hrAvg;
  final int hrMax;
  const _HeartZonesDemo({required this.hrAvg, required this.hrMax});

  @override
  Widget build(BuildContext context) {
    final zones = const [
      ("Z1", 10, Color(0xFF93C5FD)),
      ("Z2", 18, Color(0xFF60A5FA)),
      ("Z3", 16, Color(0xFF2563EB)),
      ("Z4", 9, Color(0xFF1D4ED8)),
      ("Z5", 5, Color(0xFF0B3AA7)),
    ];
    final total = zones.fold<int>(0, (a, b) => a + b.$2);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatPill(
                title: "Средний пульс",
                value: "$hrAvg bpm",
                icon: Icons.favorite_border,
                accent: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatPill(
                title: "Макс пульс",
                value: "$hrMax bpm",
                icon: Icons.favorite,
                accent: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 118,
              height: 118,
              child: CustomPaint(
                painter: _PiePainter(
                  items: zones.map((e) => _PieItem(e.$2.toDouble(), e.$3)).toList(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  for (final z in zones) ...[
                    _ZoneRow(name: z.$1, minutes: z.$2, color: z.$3, total: total),
                    const SizedBox(height: 8),
                  ]
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final String name;
  final int minutes;
  final Color color;
  final int total;

  const _ZoneRow({required this.name, required this.minutes, required this.color, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = total == 0 ? 0.0 : minutes / total;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        SizedBox(width: 28, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 8,
              backgroundColor: Colors.black.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text("${minutes}м", style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _PieItem {
  final double value;
  final Color color;
  _PieItem(this.value, this.color);
}

class _PiePainter extends CustomPainter {
  final List<_PieItem> items;
  _PiePainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold<double>(0, (a, b) => a + b.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    var start = -pi / 2;
    for (final it in items) {
      final sweep = (it.value / total) * 2 * pi;
      final paint = Paint()..color = it.color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, true, paint);
      start += sweep;
    }

    final hole = Paint()..color = AppColors.white;
    canvas.drawCircle(center, radius * 0.58, hole);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withOpacity(0.06);
    canvas.drawCircle(center, radius * 0.58, stroke);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) => oldDelegate.items != items;
}

class _BarsMock extends StatelessWidget {
  const _BarsMock();

  @override
  Widget build(BuildContext context) {
    final bars = [4, 10, 6, 14, 8, 18, 7, 12, 5, 16, 9, 20];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final v in bars)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                height: (v * 5).toDouble(),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RiskBar extends StatelessWidget {
  final double acwr;
  const _RiskBar({required this.acwr});

  @override
  Widget build(BuildContext context) {
    final v = ((acwr - 0.5) / (2.0 - 0.5)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Шкала риска", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final knob = 10.0;
              final left = (v * (w - knob)).clamp(0.0, w - knob);

              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFFF6B6B)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: left,
                      top: 0,
                      child: Container(
                        width: knob,
                        height: knob,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.black.withOpacity(0.18)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Text("0.8–1.3 — оптимально. >1.3 — риск перегруза.", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InsightTile({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(color: AppColors.textSecondary, height: 1.25, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// PITCH PAINTERS (Gomel field)
/// =======================
class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B6B3A), Color(0xFF0A5E34)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final stripe = Paint()..color = Colors.white.withOpacity(0.04);
    final stripeW = size.width / 8;
    for (int i = 0; i < 8; i++) {
      if (i.isOdd) canvas.drawRect(Rect.fromLTWH(i * stripeW, 0, stripeW, size.height), stripe);
    }

    final line = Paint()
      ..color = Colors.white.withOpacity(0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final pad = 18.0;
    final rect = Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);
    canvas.drawRRect(RRect.fromRectXY(rect, 18, 18), line);

    canvas.drawLine(Offset(rect.center.dx, rect.top), Offset(rect.center.dx, rect.bottom), line);
    canvas.drawCircle(rect.center, min(rect.width, rect.height) * 0.12, line);

    final boxW = rect.width * 0.18;
    final boxH = rect.height * 0.46;
    final smallW = rect.width * 0.08;
    final smallH = rect.height * 0.24;

    canvas.drawRect(Rect.fromLTWH(rect.left, rect.center.dy - boxH / 2, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.center.dy - smallH / 2, smallW, smallH), line);

    canvas.drawRect(Rect.fromLTWH(rect.right - boxW, rect.center.dy - boxH / 2, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH(rect.right - smallW, rect.center.dy - smallH / 2, smallW, smallH), line);

    final dot = Paint()..color = Colors.white.withOpacity(0.60);
    canvas.drawCircle(Offset(rect.left + boxW * 0.62, rect.center.dy), 2.6, dot);
    canvas.drawCircle(Offset(rect.right - boxW * 0.62, rect.center.dy), 2.6, dot);

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withOpacity(0.22)],
      ).createShader(Rect.fromCircle(center: rect.center, radius: rect.longestSide * 0.7));
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) => false;
}

class _PlayersPainter extends CustomPainter {
  final List<_SimPlayer> players;
  final int selected;
  final bool gomel;

  _PlayersPainter({required this.players, required this.selected, required this.gomel});

  @override
  void paint(Canvas canvas, Size size) {
    final pad = 18.0;
    final field = Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);

    Offset map(Offset u) => Offset(field.left + u.dx * field.width, field.top + u.dy * field.height);

    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      final pos = map(p.pos);
      final isSel = i == selected;

      final baseColor = isSel ? AppColors.primaryGreen : const Color(0xFF22C55E);

      final glow = Paint()
        ..color = baseColor.withOpacity(isSel ? 0.45 : 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(pos, isSel ? 14 : 11, glow);

      final dot = Paint()..color = baseColor;
      canvas.drawCircle(pos, isSel ? 7.5 : 6.2, dot);

      final stroke = Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(pos, isSel ? 7.5 : 6.2, stroke);

      final tp = TextPainter(
        text: TextSpan(
          text: "${p.number}",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isSel ? 12 : 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _PlayersPainter oldDelegate) =>
      oldDelegate.players != players || oldDelegate.selected != selected;
}

class _TrailPainter extends CustomPainter {
  final List<List<Offset>> trails;
  final int selected;
  final bool gomel;

  _TrailPainter({required this.trails, required this.selected, required this.gomel});

  @override
  void paint(Canvas canvas, Size size) {
    final pad = 18.0;
    final field = Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);

    Offset map(Offset u) => Offset(field.left + u.dx * field.width, field.top + u.dy * field.height);

    for (int i = 0; i < trails.length; i++) {
      final t = trails[i];
      if (t.length < 2) continue;

      final isSel = i == selected;
      final c = isSel ? AppColors.primaryGreen : Colors.white.withOpacity(0.55);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? 3.0 : 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = c.withOpacity(isSel ? 0.90 : 0.28);

      final path = Path();
      final first = map(t.first);
      path.moveTo(first.dx, first.dy);
      for (int k = 1; k < t.length; k++) {
        final m = map(t[k]);
        path.lineTo(m.dx, m.dy);
      }

      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? 10.0 : 7.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = c.withOpacity(isSel ? 0.18 : 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      canvas.drawPath(path, glow);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter oldDelegate) =>
      oldDelegate.trails != trails || oldDelegate.selected != selected;
}

class _HeatPainter extends CustomPainter {
  final List<Offset> points;
  final double intensity;
  final bool gomel;

  _HeatPainter({required this.points, required this.intensity, required this.gomel});

  @override
  void paint(Canvas canvas, Size size) {
    final pad = 18.0;
    final field = Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);

    Offset map(Offset u) => Offset(field.left + u.dx * field.width, field.top + u.dy * field.height);

    final base = (0.10 + intensity * 0.18).clamp(0.10, 0.30);

    for (final p in points) {
      final center = map(p);
      final r = 34 + 24 * intensity;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(base),
            const Color(0xFFFF6B6B).withOpacity(base * 0.85),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));

      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.intensity != intensity;
}

/// =======================
/// TEAM AGG
/// =======================
class _TeamAgg {
  final int avgHr;
  final double sumDistanceKm;
  final int sumSprints;
  final double topSpeed;

  _TeamAgg({
    required this.avgHr,
    required this.sumDistanceKm,
    required this.sumSprints,
    required this.topSpeed,
  });

  static _TeamAgg from(List<_SimPlayer> ps) {
    if (ps.isEmpty) {
      return _TeamAgg(avgHr: 0, sumDistanceKm: 0, sumSprints: 0, topSpeed: 0);
    }
    final avg = (ps.map((e) => e.hr).reduce((a, b) => a + b) / ps.length).round();
    final sumKm = ps.map((e) => e.distanceMeters).reduce((a, b) => a + b) / 1000.0;
    final sprints = ps.map((e) => e.sprints).reduce((a, b) => a + b);
    final top = ps.map((e) => e.maxSpeedKmh).reduce(max);
    return _TeamAgg(avgHr: avg, sumDistanceKm: sumKm, sumSprints: sprints, topSpeed: top);
  }
}

/// =======================
/// SIM PLAYER
/// =======================
class _SimPlayer {
  final int id;
  final String name;
  final String position;
  final int number;

  Offset pos = const Offset(0.5, 0.5);
  Offset vel = const Offset(0.0012, 0.0009);

  final List<Offset> trail = [];
  final List<Offset> heatPoints = [];

  int hr = 138;
  int hrMax = 176;
  double speedKmh = 12.4;
  double maxSpeedKmh = 27.8;
  int sprints = 6;
  int accelerations = 14;
  int decelerations = 12;
  int loadScore = 62;
  double distanceMeters = 2860.0;
  double gpsQuality = 0.93;
  double intensity = 0.62;

  double zoneL = 0.33, zoneC = 0.34, zoneR = 0.33;
  double zoneDefThird = 0.30, zoneMidThird = 0.45, zoneAttThird = 0.25;

  _SimPlayer._(this.id, this.name, this.position, this.number);

  static _SimPlayer seed(int id) {
    if (id == 1) return _SimPlayer._(1, "Иванов А.", "ЦП • Box-to-box", 8);
    if (id == 2) return _SimPlayer._(2, "Петров Д.", "ЛВ • Фланг", 11);
    return _SimPlayer._(3, "Сидоров М.", "ЦЗ • Оборона", 4);
    // можешь заменить на реальных игроков
  }

  void step(Random rng) {
    final jitter = Offset((rng.nextDouble() - 0.5) * 0.0014, (rng.nextDouble() - 0.5) * 0.0011);
    vel = Offset(
      (vel.dx + jitter.dx).clamp(-0.0042, 0.0042),
      (vel.dy + jitter.dy).clamp(-0.0036, 0.0036),
    );

    pos = Offset(pos.dx + vel.dx, pos.dy + vel.dy);

    if (pos.dx < 0.06 || pos.dx > 0.94) {
      vel = Offset(-vel.dx, vel.dy);
      pos = Offset(pos.dx.clamp(0.06, 0.94), pos.dy);
    }
    if (pos.dy < 0.08 || pos.dy > 0.92) {
      vel = Offset(vel.dx, -vel.dy);
      pos = Offset(pos.dx, pos.dy.clamp(0.08, 0.92));
    }

    trail.add(pos);
    if (trail.length > 80) trail.removeAt(0);

    if (rng.nextDouble() < 0.35) {
      heatPoints.add(pos);
      if (heatPoints.length > 36) heatPoints.removeAt(0);
    }

    final sp = sqrt(vel.dx * vel.dx + vel.dy * vel.dy);
    speedKmh = (sp * 5200).clamp(4.0, 33.0);
    maxSpeedKmh = max(maxSpeedKmh, speedKmh);

    intensity = ((speedKmh - 4) / (33 - 4)).clamp(0.0, 1.0);

    hr = (120 + intensity * 58 + (rng.nextDouble() - 0.5) * 3).round();
    hrMax = max(hrMax, hr);

    gpsQuality = (0.86 + rng.nextDouble() * 0.14).clamp(0.0, 1.0);

    distanceMeters += (speedKmh / 3.6) * 0.016;
    loadScore = (40 + intensity * 60 + (rng.nextDouble() * 2)).round();

    if (speedKmh > 25.0 && rng.nextDouble() < 0.02) sprints++;
    if (rng.nextDouble() < intensity * 0.05) accelerations++;
    if (rng.nextDouble() < (1 - intensity) * 0.03) decelerations++;

    // zones (сглаживание)
    final left = (1.0 - pos.dx).clamp(0.0, 1.0);
    final right = pos.dx.clamp(0.0, 1.0);
    final center = (1.0 - (pos.dx - 0.5).abs() * 2).clamp(0.0, 1.0);

    final sum1 = left + center + right + 1e-9;
    final lNow = left / sum1;
    final cNow = center / sum1;
    final rNow = right / sum1;

    zoneL = _lerp(zoneL, lNow, 0.05);
    zoneC = _lerp(zoneC, cNow, 0.05);
    zoneR = _lerp(zoneR, rNow, 0.05);

    final defT = (1.0 - pos.dy).clamp(0.0, 1.0);
    final attT = pos.dy.clamp(0.0, 1.0);
    final midT = (1.0 - (pos.dy - 0.5).abs() * 2).clamp(0.0, 1.0);

    final sum2 = defT + midT + attT + 1e-9;
    final dNow = defT / sum2;
    final mNow = midT / sum2;
    final aNow = attT / sum2;

    zoneDefThird = _lerp(zoneDefThird, dNow, 0.05);
    zoneMidThird = _lerp(zoneMidThird, mNow, 0.05);
    zoneAttThird = _lerp(zoneAttThird, aNow, 0.05);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// =======================
/// UTIL
/// =======================
void _snack(String text) {
  Get.snackbar("Спортотека", text, snackPosition: SnackPosition.BOTTOM);
}
