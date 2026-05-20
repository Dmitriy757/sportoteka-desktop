import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/team_video_analysis/ai_analytics_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/ai_tracking_controller.dart';
import 'package:sportoteka/presentation/team_video_analysis/tracking_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/formatters.dart';

class AiAnalyticsPanelWidget extends StatefulWidget {
  final AiTrackingController aiTracking;
  final bool showHeatmap;
  final String statusText;

  final bool isAiLoading;
  final double? aiProgress;

  final String myTeamName;
  final String opponentTeamName;
  final String myTeamTag;

  final VoidCallback onToggleAi;
  final ValueChanged<bool> onToggleHeatmap;
  final VoidCallback onBindTrack;
  final ValueChanged<int> onJumpToTime;
  final VoidCallback onExport;
  final ValueChanged<AiTtdSuggestion> onConfirmSuggestion;
  final VoidCallback? onConfirmTopAi;
  final VoidCallback? onOpenTeamSetup;

  const AiAnalyticsPanelWidget({
    super.key,
    required this.aiTracking,
    required this.showHeatmap,
    required this.statusText,
    this.isAiLoading = false,
    this.aiProgress,
    this.myTeamName = 'Моя команда',
    this.opponentTeamName = 'Соперник',
    this.myTeamTag = 'home',
    required this.onToggleAi,
    required this.onToggleHeatmap,
    required this.onBindTrack,
    required this.onJumpToTime,
    required this.onExport,
    required this.onConfirmSuggestion,
    this.onConfirmTopAi,
    this.onOpenTeamSetup,
  });

  @override
  State<AiAnalyticsPanelWidget> createState() => _AiAnalyticsPanelWidgetState();
}

class _AiPanelColors {
  static const background = Color(0xFFF3F4F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF8FAFC);

  static const text = Color(0xFF111827);
  static const textMuted = Color(0xFF667085);
  static const textSoft = Color(0xFF98A2B3);

  static const black = Color(0xFF111111);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF008C40);
  static const red = Color(0xFFDC2626);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF7C3AED);
  static const amber = Color(0xFFF59E0B);
  static const teal = Color(0xFF0F766E);
}

class _AiAnalyticsPanelWidgetState extends State<AiAnalyticsPanelWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool get _isMyTeamHome => widget.myTeamTag == 'home';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    widget.aiTracking.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.aiTracking.removeListener(_refresh);
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.aiTracking.lockedTrack;
    final live = _buildLiveStats(track);
    final summary = _buildMatchSummary(track, live);
    final playerName = track?.boundPlayerName ?? 'Игрок не выбран';

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;

        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        final fallbackTabsHeight = width >= 1100
            ? 760.0
            : width >= 800
                ? 640.0
                : 560.0;

        final topArea = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopInfoStrip(
              playerName: playerName,
              live: live,
              summary: summary,
            ),
            const SizedBox(height: 8),
            _buildTabSelector(),
            const SizedBox(height: 8),
            _buildControlsStrip(),
            if (widget.isAiLoading) ...[
              const SizedBox(height: 8),
              _buildAiLoadingBar(),
            ],
            const SizedBox(height: 8),
          ],
        );

        final tabsBody = _buildTabsBody(summary, live, track);

        if (hasBoundedHeight) {
          return Container(
            color: _AiPanelColors.background,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                topArea,
                Expanded(child: tabsBody),
              ],
            ),
          );
        }

        return Container(
          color: _AiPanelColors.background,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              topArea,
              SizedBox(
                height: fallbackTabsHeight,
                child: tabsBody,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabsBody(
    _AiMatchSummary summary,
    _AiLiveStats live,
    PlayerTrack? track,
  ) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(summary, live, track),
        _buildEventsTab(summary),
        _buildTtdTab(summary),
        _buildMapTab(track, live),
        _buildTeamTab(summary),
        _buildPlayersTab(),
        _buildExportTab(summary),
      ],
    );
  }

  Widget _buildTopInfoStrip({
    required String playerName,
    required _AiLiveStats live,
    required _AiMatchSummary summary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _topBadge(
              icon: Icons.person_outline_rounded,
              label: playerName,
              color: _AiPanelColors.blue,
            ),
            _topBadge(
              icon: Icons.sensors_rounded,
              label: widget.statusText.isEmpty ? '—' : widget.statusText,
              color: _AiPanelColors.teal,
            ),
            _topBadge(
              icon: Icons.auto_graph_rounded,
              label: widget.aiTracking.isRunning ? 'AI активен' : 'AI выключен',
              color: widget.aiTracking.isRunning
                  ? _AiPanelColors.green
                  : _AiPanelColors.amber,
            ),
            _topBadge(
              icon: Icons.link_rounded,
              label: widget.aiTracking.isLocked ? 'Трек привязан' : 'Без привязки',
              color: widget.aiTracking.isLocked
                  ? _AiPanelColors.violet
                  : _AiPanelColors.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _responsiveWrap(
          minItemWidth: 115,
          spacing: 8,
          items: [
            _miniStat('События', '${summary.eventsCount}'),
            _miniStat('AI ТТД', '${summary.suggestionsCount}'),
            _miniStat('Скорость', '${live.currentSpeed.toStringAsFixed(1)}'),
            _miniStat('Рывки', '${live.sprints}'),
            _miniStat('Дистанция', '${live.totalDistance.toStringAsFixed(1)}'),
            _miniStat(
              widget.myTeamName,
              '${summary.myPossessionPct.toStringAsFixed(0)}%',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _AiPanelColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: _AiPanelColors.textMuted,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        indicator: BoxDecoration(
          color: _AiPanelColors.green,
          borderRadius: BorderRadius.circular(11),
        ),
        tabs: const [
          Tab(text: 'Обзор'),
          Tab(text: 'События'),
          Tab(text: 'ТТД'),
          Tab(text: 'Карта'),
          Tab(text: 'Команда'),
          Tab(text: 'Игроки'),
          Tab(text: 'Экспорт'),
        ],
      ),
    );
  }

  Widget _buildControlsStrip() {
    final controls = <Widget>[
      _actionPill(
        icon: widget.isAiLoading
            ? Icons.hourglass_top_rounded
            : widget.aiTracking.isRunning
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
        label: widget.isAiLoading
            ? (widget.aiProgress != null
                ? 'AI ${(widget.aiProgress! * 100).round()}%'
                : 'Запуск AI...')
            : widget.aiTracking.isRunning
                ? 'Остановить AI'
                : 'Запустить AI',
        color: _AiPanelColors.black,
        onTap: widget.isAiLoading ? null : widget.onToggleAi,
        filled: true,
      ),
      if (widget.onOpenTeamSetup != null)
        _actionPill(
          icon: Icons.palette_outlined,
          label: 'Команды',
          color: _AiPanelColors.teal,
          onTap: widget.onOpenTeamSetup!,
        ),
      _actionPill(
        icon: Icons.link_rounded,
        label: 'Игрок',
        color: _AiPanelColors.blue,
        onTap: widget.onBindTrack,
      ),
      _actionPill(
        icon: widget.showHeatmap
            ? Icons.local_fire_department_rounded
            : Icons.heat_pump_rounded,
        label: widget.showHeatmap ? 'Heatmap off' : 'Heatmap on',
        color: _AiPanelColors.red,
        onTap: () => widget.onToggleHeatmap(!widget.showHeatmap),
      ),
      if (widget.onConfirmTopAi != null)
        _actionPill(
          icon: Icons.fact_check_outlined,
          label: '> 75%',
          color: _AiPanelColors.green,
          onTap: widget.onConfirmTopAi!,
        ),
      _actionPill(
        icon: Icons.upload_file_rounded,
        label: 'Экспорт',
        color: _AiPanelColors.violet,
        onTap: widget.onExport,
      ),
    ];

    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < controls.length; i++) ...[
              controls[i],
              if (i != controls.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiLoadingBar() {
    final progress = widget.aiProgress;
    final percent = progress == null
        ? null
        : (progress.clamp(0.0, 1.0) * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _AiPanelColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: _AiPanelColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.statusText.isEmpty
                      ? 'AI анализ запускается...'
                      : widget.statusText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _AiPanelColors.text,
                  ),
                ),
              ),
              if (percent != null)
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _AiPanelColors.green,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: _AiPanelColors.surfaceSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(
                _AiPanelColors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    _AiMatchSummary summary,
    _AiLiveStats live,
    PlayerTrack? track,
  ) {
    final myPossession = summary.myPossessionPct;
    final oppPossession = summary.opponentPossessionPct;

    final myPasses = _isMyTeamHome ? summary.homePasses : summary.awayPasses;
    final oppPasses = _isMyTeamHome ? summary.awayPasses : summary.homePasses;

    final myShots = _isMyTeamHome ? summary.homeShots : summary.awayShots;
    final oppShots = _isMyTeamHome ? summary.awayShots : summary.homeShots;

    final myInterceptions =
        _isMyTeamHome ? summary.homeInterceptions : summary.awayInterceptions;
    final oppInterceptions =
        _isMyTeamHome ? summary.awayInterceptions : summary.homeInterceptions;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          _responsiveWrap(
            minItemWidth: 160,
            spacing: 8,
            items: [
              _metricCard(
                title: 'AI-события',
                value: '${summary.eventsCount}',
                subtitle: 'Найдено',
                icon: Icons.timeline_rounded,
                color: _AiPanelColors.blue,
              ),
              _metricCard(
                title: 'AI ТТД',
                value: '${summary.suggestionsCount}',
                subtitle: 'Подсказки',
                icon: Icons.fact_check_outlined,
                color: _AiPanelColors.green,
              ),
              _metricCard(
                title: 'Успешные',
                value: '${summary.positiveSuggestions}',
                subtitle: 'Плюс',
                icon: Icons.check_circle_outline_rounded,
                color: _AiPanelColors.green,
              ),
              _metricCard(
                title: 'Неуспешные',
                value: '${summary.negativeSuggestions}',
                subtitle: 'Минус',
                icon: Icons.cancel_outlined,
                color: _AiPanelColors.red,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _surfaceBlock(
            title: 'Матч',
            icon: Icons.analytics_outlined,
            color: _AiPanelColors.green,
            child: Column(
              children: [
                _infoRow('Владение ${widget.myTeamName}', '${myPossession.toStringAsFixed(0)}%'),
                _infoRow('Владение ${widget.opponentTeamName}', '${oppPossession.toStringAsFixed(0)}%'),
                _infoRow('Передачи ${widget.myTeamName}', '$myPasses'),
                _infoRow('Передачи ${widget.opponentTeamName}', '$oppPasses'),
                _infoRow('Удары ${widget.myTeamName}', '$myShots'),
                _infoRow('Удары ${widget.opponentTeamName}', '$oppShots'),
                _infoRow('Перехваты ${widget.myTeamName}', '$myInterceptions'),
                _infoRow('Перехваты ${widget.opponentTeamName}', '$oppInterceptions'),
                const SizedBox(height: 10),
                _infoRow('Текущая скорость', '${live.currentSpeed.toStringAsFixed(1)} км/ч'),
                _infoRow('Средняя скорость', '${live.avgSpeed.toStringAsFixed(1)} км/ч'),
                _infoRow('Макс. скорость', '${live.maxSpeed.toStringAsFixed(1)} км/ч'),
                _infoRow('Дистанция', '${live.totalDistance.toStringAsFixed(1)} м'),
                _infoRow('Рывки', '${live.sprints}'),
                _infoRow('Точек трека', '${track?.points.length ?? 0}'),
                _infoRow('Heatmap', widget.showHeatmap ? 'Включен' : 'Выключен'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _surfaceBlock(
            title: 'Подсказки',
            icon: Icons.lightbulb_outline_rounded,
            color: _AiPanelColors.amber,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hintLine(
                  summary.eventsCount > 0
                      ? 'AI уже нашёл эпизоды — можно быстро переходить по времени.'
                      : 'Запусти AI и выбери игрока для старта анализа.',
                ),
                _hintLine(
                  summary.suggestionsCount > 0
                      ? 'Подтверждай AI-подсказки, чтобы быстро заполнять ТТД.'
                      : 'После распознавания действия появятся в разделе ТТД.',
                ),
                _hintLine(
                  widget.showHeatmap
                      ? 'Heatmap активен — сверяй зоны активности с эпизодами.'
                      : 'Включи heatmap для зон активности игрока.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab(_AiMatchSummary summary) {
    final events = widget.aiTracking.autoEvents;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          _surfaceBlock(
            title: 'События',
            icon: Icons.timeline_rounded,
            color: _AiPanelColors.blue,
            child: events.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Пока нет событий. Запусти AI и выбери игрока.',
                      style: TextStyle(
                        color: _AiPanelColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Column(
                    children: events.map(_eventTile).toList(),
                  ),
          ),
          const SizedBox(height: 8),
          _surfaceBlock(
            title: 'Сводка',
            icon: Icons.summarize_outlined,
            color: _AiPanelColors.violet,
            child: Column(
              children: [
                _infoRow('Всего событий', '${summary.eventsCount}'),
                _infoRow(
                  'Первые 5',
                  events.take(5).map((e) => e.title).join(', ').isEmpty
                      ? '—'
                      : events.take(5).map((e) => e.title).join(', '),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTtdTab(_AiMatchSummary summary) {
    final suggestions = widget.aiTracking.ttdSuggestions;

    final main =
        suggestions.where((e) => e.section == 'Основные действия').toList();
    final passes = suggestions.where((e) => e.section == 'Передачи').toList();
    final gk =
        suggestions.where((e) => e.section == 'Вратарские действия').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          _responsiveWrap(
            minItemWidth: 160,
            spacing: 8,
            items: [
              _metricCard(
                title: 'Всего AI ТТД',
                value: '${summary.suggestionsCount}',
                subtitle: 'Подсказки',
                icon: Icons.fact_check_outlined,
                color: _AiPanelColors.green,
              ),
              _metricCard(
                title: 'Успешные',
                value: '${summary.positiveSuggestions}',
                subtitle: 'Плюс',
                icon: Icons.check_circle_outline_rounded,
                color: _AiPanelColors.green,
              ),
              _metricCard(
                title: 'Неуспешные',
                value: '${summary.negativeSuggestions}',
                subtitle: 'Минус',
                icon: Icons.cancel_outlined,
                color: _AiPanelColors.red,
              ),
              _metricCard(
                title: 'Уверенность',
                value: '${summary.avgSuggestionConfidence.toStringAsFixed(0)}%',
                subtitle: 'Средняя',
                icon: Icons.psychology_alt_outlined,
                color: _AiPanelColors.violet,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ttdSection(
            title: 'Основные действия',
            color: _AiPanelColors.blue,
            items: main,
            presets: const [
              'Финт / дриблинг',
              'Удары',
              'Отбор',
              'Перехват',
              'Подбор',
              'Игра головой',
              'Ауты',
              'Пас АВП',
            ],
          ),
          const SizedBox(height: 8),
          _ttdSection(
            title: 'Передачи',
            color: _AiPanelColors.violet,
            items: passes,
            presets: const [
              'Передача вперед короткая',
              'Передача вперед средняя',
              'Передача вперед длинная',
              'Передача поперек короткая',
              'Передача поперек средняя',
              'Передача поперек длинная',
              'Передача назад короткая',
              'Передача назад средняя',
              'Передача назад длинная',
            ],
          ),
          const SizedBox(height: 8),
          _ttdSection(
            title: 'Вратарские действия',
            color: _AiPanelColors.red,
            items: gk,
            presets: const [
              'Сейв',
              'Выход',
              'Ввод рукой',
              'Ближний бой',
              'Перехват',
              'За пределами штрафной',
              'Пас короткий',
              'Пас средний',
              'Пас длинный',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapTab(PlayerTrack? track, _AiLiveStats live) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          _surfaceBlock(
            title: 'Карта и оверлеи',
            icon: Icons.map_outlined,
            color: _AiPanelColors.green,
            child: Column(
              children: [
                _switchRow(
                  title: 'Траектория',
                  value: widget.aiTracking.showTrails,
                  onChanged: (_) {
                    widget.aiTracking.showTrails = !widget.aiTracking.showTrails;
                    widget.aiTracking.notifyListeners();
                  },
                ),
                _switchRow(
                  title: 'Подписи',
                  value: widget.aiTracking.showLabels,
                  onChanged: (_) {
                    widget.aiTracking.showLabels = !widget.aiTracking.showLabels;
                    widget.aiTracking.notifyListeners();
                  },
                ),
                _switchRow(
                  title: 'Скорость',
                  value: widget.aiTracking.showSpeed,
                  onChanged: (_) {
                    widget.aiTracking.showSpeed = !widget.aiTracking.showSpeed;
                    widget.aiTracking.notifyListeners();
                  },
                ),
                _switchRow(
                  title: 'Рамки',
                  value: widget.aiTracking.showBoundingBoxes,
                  onChanged: (_) {
                    widget.aiTracking.showBoundingBoxes =
                        !widget.aiTracking.showBoundingBoxes;
                    widget.aiTracking.notifyListeners();
                  },
                ),
                _switchRow(
                  title: 'Только выбранный',
                  value: widget.aiTracking.showOnlySelectedPlayer,
                  onChanged: (_) {
                    widget.aiTracking.showOnlySelectedPlayer =
                        !widget.aiTracking.showOnlySelectedPlayer;
                    widget.aiTracking.notifyListeners();
                  },
                ),
                _switchRow(
                  title: 'Heatmap',
                  value: widget.showHeatmap,
                  onChanged: widget.onToggleHeatmap,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _surfaceBlock(
            title: 'Подсказки',
            icon: Icons.local_fire_department_outlined,
            color: _AiPanelColors.amber,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hintLine(
                  widget.showHeatmap
                      ? 'Heatmap показывает зоны активности по треку.'
                      : 'Включи heatmap для анализа зон активности.',
                ),
                _hintLine(
                  track == null
                      ? 'Сначала привяжи трек к игроку.'
                      : 'Игрок привязан — можно сравнивать карту с эпизодами.',
                ),
                _hintLine(
                  'Скорость ${live.currentSpeed.toStringAsFixed(1)} км/ч и дистанция ${live.totalDistance.toStringAsFixed(1)} м — вспомогательные метрики.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTab(_AiMatchSummary summary) {
    final passNetwork = widget.aiTracking.aiPassNetwork;
    final avgPositions = widget.aiTracking.aiAveragePositions;
    final dangerMoments = widget.aiTracking.aiDangerMoments;

    final myTeamPasses = passNetwork
        .where((e) => e.team == widget.myTeamTag)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final myAvgPositions =
        avgPositions.where((e) => e.team == widget.myTeamTag).toList();

    final myDanger =
        dangerMoments.where((e) => e.team == widget.myTeamTag).toList();

    final myPasses = _isMyTeamHome ? summary.homePasses : summary.awayPasses;
    final myShots = _isMyTeamHome ? summary.homeShots : summary.awayShots;
    final myInterceptions =
        _isMyTeamHome ? summary.homeInterceptions : summary.awayInterceptions;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          _responsiveWrap(
            minItemWidth: 180,
            spacing: 8,
            items: [
              _metricCard(
                title: widget.myTeamName,
                value: '${summary.myPossessionPct.toStringAsFixed(0)}%',
                subtitle: 'Владение',
                icon: Icons.groups_rounded,
                color: _AiPanelColors.green,
              ),
              _metricCard(
                title: 'Передачи',
                value: '$myPasses',
                subtitle: 'Команда',
                icon: Icons.share_rounded,
                color: _AiPanelColors.blue,
              ),
              _metricCard(
                title: 'Удары',
                value: '$myShots',
                subtitle: 'Команда',
                icon: Icons.sports_soccer_rounded,
                color: _AiPanelColors.red,
              ),
              _metricCard(
                title: 'Перехваты',
                value: '$myInterceptions',
                subtitle: 'Команда',
                icon: Icons.shield_outlined,
                color: _AiPanelColors.teal,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _surfaceBlock(
            title: 'Топ связки передач',
            icon: Icons.share_rounded,
            color: _AiPanelColors.blue,
            child: myTeamPasses.isEmpty
                ? const Text(
                    'Пока нет сети передач',
                    style: TextStyle(
                      color: _AiPanelColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Column(
                    children: myTeamPasses.take(8).map((e) {
                      return _infoRow(
                        '${e.fromTrackId} → ${e.toTrackId}',
                        '${e.count} (${e.successful} усп.)',
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 8),
          _surfaceBlock(
            title: 'Средние позиции',
            icon: Icons.my_location_rounded,
            color: _AiPanelColors.green,
            child: myAvgPositions.isEmpty
                ? const Text(
                    'Пока нет средних позиций',
                    style: TextStyle(
                      color: _AiPanelColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Column(
                    children: myAvgPositions.take(12).map((e) {
                      return _infoRow(
                        e.playerName,
                        'x:${e.avgX.toStringAsFixed(1)}  y:${e.avgY.toStringAsFixed(1)}',
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 8),
          _surfaceBlock(
            title: 'Опасные моменты',
            icon: Icons.warning_amber_rounded,
            color: _AiPanelColors.amber,
            child: myDanger.isEmpty
                ? const Text(
                    'Опасные моменты не найдены',
                    style: TextStyle(
                      color: _AiPanelColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Column(
                    children: myDanger.take(8).map((e) {
                      return _infoRow(
                        e.title,
                        '${Formatters.formatDuration(Duration(milliseconds: e.timeMs))} • ${(e.dangerScore * 100).round()}%',
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersTab() {
    final stats = widget.aiTracking.aiPlayerStats
        .where((e) => e.team == widget.myTeamTag)
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 2),
      child: _surfaceBlock(
        title: 'Игроки',
        icon: Icons.person_search_rounded,
        color: _AiPanelColors.violet,
        child: stats.isEmpty
            ? const Text(
                'Пока нет статистики игроков',
                style: TextStyle(
                  color: _AiPanelColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              )
            : Column(
                children: stats.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _AiPanelColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.playerName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: _AiPanelColors.text,
                                ),
                              ),
                            ),
                            _pill(
                              'Рейтинг ${e.rating.toStringAsFixed(1)}',
                              _AiPanelColors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _responsiveWrap(
                          minItemWidth: 110,
                          spacing: 8,
                          items: [
                            _miniStat('Касания', '${e.touches}'),
                            _miniStat('Передачи', '${e.passes}'),
                            _miniStat('Усп.', '${e.successfulPasses}'),
                            _miniStat('Удары', '${e.shots}'),
                            _miniStat('Перехваты', '${e.interceptions}'),
                            _miniStat('Дист.', '${e.distanceM.toStringAsFixed(1)}'),
                            _miniStat('Макс. км/ч', '${e.maxSpeedKmh.toStringAsFixed(1)}'),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildExportTab(_AiMatchSummary summary) {
    final myPossession = summary.myPossessionPct;
    final oppPossession = summary.opponentPossessionPct;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          _surfaceBlock(
            title: 'Экспорт',
            icon: Icons.upload_file_rounded,
            color: _AiPanelColors.violet,
            child: Column(
              children: [
                _exportItem(
                  title: 'AI-анализ',
                  subtitle: 'События, подсказки и метрики',
                  icon: Icons.analytics_rounded,
                  onTap: widget.onExport,
                ),
                _exportItem(
                  title: 'Подтвержденные ТТД',
                  subtitle: 'Передать в итоговый отчет',
                  icon: Icons.fact_check_outlined,
                  onTap: widget.onExport,
                ),
                _exportItem(
                  title: 'Отчет по игроку',
                  subtitle: 'Аналитика выбранного игрока',
                  icon: Icons.person_search_rounded,
                  onTap: widget.onExport,
                ),
                _exportItem(
                  title: 'Отчет по матчу',
                  subtitle: 'Общая AI-сводка',
                  icon: Icons.summarize_outlined,
                  onTap: widget.onExport,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _surfaceBlock(
            title: 'Что выгружается',
            icon: Icons.inventory_2_outlined,
            color: _AiPanelColors.blue,
            child: Column(
              children: [
                _infoRow('AI-события', '${summary.eventsCount}'),
                _infoRow('AI ТТД', '${summary.suggestionsCount}'),
                _infoRow('Успешные', '${summary.positiveSuggestions}'),
                _infoRow('Неуспешные', '${summary.negativeSuggestions}'),
                _infoRow('Владение ${widget.myTeamName}', '${myPossession.toStringAsFixed(0)}%'),
                _infoRow('Владение ${widget.opponentTeamName}', '${oppPossession.toStringAsFixed(0)}%'),
                _infoRow('Передачи всего', '${summary.passesTotal}'),
                _infoRow('Удары всего', '${summary.shotsTotal}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ttdSection({
    required String title,
    required Color color,
    required List<AiTtdSuggestion> items,
    required List<String> presets,
  }) {
    return _surfaceBlock(
      title: title,
      icon: Icons.sports_soccer_rounded,
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'AI пока не предложил действий в этом разделе.',
                style: TextStyle(
                  fontSize: 12,
                  color: _AiPanelColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ...items.map((e) => _ttdSuggestionTile(e, color)),
          const SizedBox(height: 8),
          Text(
            'Быстрое подтверждение',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets
                .map((e) => _presetChip(label: e, color: color))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _ttdSuggestionTile(AiTtdSuggestion item, Color accent) {
    final timeText = Formatters.formatDuration(
      Duration(milliseconds: item.timeMs),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _AiPanelColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _AiPanelColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _AiPanelColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                item.success ? 'Успешно' : 'Неуспешно',
                item.success ? _AiPanelColors.green : _AiPanelColors.red,
              ),
              _pill(
                'Уверенность ${(item.confidence * 100).round()}%',
                accent,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniButton(
                  label: 'Перейти',
                  icon: Icons.play_arrow_rounded,
                  color: _AiPanelColors.black,
                  onTap: () => widget.onJumpToTime(item.timeMs),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniButton(
                  label: 'Подтвердить',
                  icon: Icons.check_circle_outline_rounded,
                  color: _AiPanelColors.green,
                  onTap: () => widget.onConfirmSuggestion(item),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventTile(AiDetectedEvent item) {
    final timeText = Formatters.formatDuration(
      Duration(milliseconds: item.timeMs),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _AiPanelColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _AiPanelColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _AiPanelColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Уверенность ${(item.confidence * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: item.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                timeText,
                style: const TextStyle(
                  fontSize: 11,
                  color: _AiPanelColors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              IconButton(
                onPressed: () => widget.onJumpToTime(item.timeMs),
                icon: const Icon(Icons.play_circle_outline_rounded),
                color: _AiPanelColors.black,
                tooltip: 'Перейти к моменту',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _surfaceBlock({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: _AiPanelColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _AiPanelColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AiPanelColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _AiPanelColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _AiPanelColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _AiPanelColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: _AiPanelColors.textMuted,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: _AiPanelColors.text,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _topBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    final disabled = onTap == null;

    return Opacity(
      opacity: disabled ? 0.65 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: filled ? _AiPanelColors.black : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: filled ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: filled ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isBlack = color == _AiPanelColors.black;

    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              isBlack ? _AiPanelColors.black : color.withOpacity(0.10),
          foregroundColor: isBlack ? Colors.white : color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _presetChip({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _AiPanelColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _AiPanelColors.text,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: _AiPanelColors.green,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _exportItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        tileColor: _AiPanelColors.surfaceSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _AiPanelColors.green,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: _AiPanelColors.text,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _AiPanelColors.textMuted,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: _AiPanelColors.textMuted,
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: _AiPanelColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                color: _AiPanelColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: _AiPanelColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsiveWrap({
    required List<Widget> items,
    double minItemWidth = 160,
    double spacing = 8,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        int columns = 1;
        if (width >= minItemWidth * 4 + spacing * 3) {
          columns = 4;
        } else if (width >= minItemWidth * 3 + spacing * 2) {
          columns = 3;
        } else if (width >= minItemWidth * 2 + spacing) {
          columns = 2;
        }

        final itemWidth = columns == 1
            ? width
            : (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map((e) => SizedBox(width: itemWidth, child: e))
              .toList(),
        );
      },
    );
  }

  _AiLiveStats _buildLiveStats(PlayerTrack? track) {
    if (track == null || track.points.isEmpty) {
      return const _AiLiveStats.empty();
    }

    final points = track.points;
    final currentSpeed = points.last.speed;

    double maxSpeed = 0;
    double sumSpeed = 0;
    double totalDistance = 0;
    int sprints = 0;
    bool sprintOpen = false;

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      maxSpeed = p.speed > maxSpeed ? p.speed : maxSpeed;
      sumSpeed += p.speed;

      if (p.speed >= 24.0 && !sprintOpen) {
        sprintOpen = true;
        sprints++;
      } else if (p.speed < 20.0) {
        sprintOpen = false;
      }

      if (i > 0) {
        final prev = points[i - 1].position;
        final dx = p.position.dx - prev.dx;
        final dy = p.position.dy - prev.dy;
        totalDistance += math.sqrt(dx * dx + dy * dy) * 0.12;
      }
    }

    final avgSpeed = points.isEmpty ? 0.0 : (sumSpeed / points.length);
    final last = points.last;
    final currentAcceleration =
        math.sqrt(last.ax * last.ax + last.ay * last.ay);

    return _AiLiveStats(
      currentSpeed: currentSpeed,
      avgSpeed: avgSpeed,
      maxSpeed: maxSpeed,
      totalDistance: totalDistance,
      sprints: sprints,
      currentAcceleration: currentAcceleration,
    );
  }

  _AiMatchSummary _buildMatchSummary(PlayerTrack? track, _AiLiveStats live) {
    final events = widget.aiTracking.autoEvents;
    final suggestions = widget.aiTracking.ttdSuggestions;

    final rawStats = widget.aiTracking.aiMatchStats ??
        (widget.aiTracking.aiSummary?['match_stats'] is Map
            ? Map<String, dynamic>.from(
                widget.aiTracking.aiSummary!['match_stats'] as Map,
              )
            : const <String, dynamic>{});

    final stats = rawStats['match_stats'] is Map
        ? Map<String, dynamic>.from(rawStats['match_stats'] as Map)
        : rawStats;

    final overview = stats['overview'] is Map
        ? Map<String, dynamic>.from(stats['overview'] as Map)
        : const <String, dynamic>{};

    final home = stats['home'] is Map
        ? Map<String, dynamic>.from(stats['home'] as Map)
        : const <String, dynamic>{};

    final away = stats['away'] is Map
        ? Map<String, dynamic>.from(stats['away'] as Map)
        : const <String, dynamic>{};

    final positive = suggestions.where((e) => e.success).length;
    final negative = suggestions.where((e) => !e.success).length;

    double avgConfidence = 0;
    if (suggestions.isNotEmpty) {
      avgConfidence =
          suggestions.map((e) => e.confidence).reduce((a, b) => a + b) /
              suggestions.length;
    }

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double asDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    final possessionHome = asDouble(overview['possession_home_pct']);
    final possessionAway = asDouble(overview['possession_away_pct']);

    return _AiMatchSummary(
      eventsCount: events.length,
      suggestionsCount: suggestions.length,
      positiveSuggestions: positive,
      negativeSuggestions: negative,
      avgSuggestionConfidence: avgConfidence * 100,
      currentSpeed: live.currentSpeed,
      distance: live.totalDistance,
      sprints: live.sprints,
      pointsCount: track?.points.length ?? 0,
      possessionHomePct: possessionHome,
      possessionAwayPct: possessionAway,
      myPossessionPct: _isMyTeamHome ? possessionHome : possessionAway,
      opponentPossessionPct: _isMyTeamHome ? possessionAway : possessionHome,
      passesTotal: asInt(overview['passes_total']),
      shotsTotal: asInt(overview['shots_total']),
      dribblesTotal: asInt(overview['dribbles_total']),
      homePasses: asInt(home['passes']),
      awayPasses: asInt(away['passes']),
      homeShots: asInt(home['shots']),
      awayShots: asInt(away['shots']),
      homeInterceptions: asInt(home['interceptions']),
      awayInterceptions: asInt(away['interceptions']),
      homeTurnoversWon: asInt(home['turnovers_won']),
      awayTurnoversWon: asInt(away['turnovers_won']),
      homeTurnoversLost: asInt(home['turnovers_lost']),
      awayTurnoversLost: asInt(away['turnovers_lost']),
    );
  }
}

class _AiLiveStats {
  final double currentSpeed;
  final double avgSpeed;
  final double maxSpeed;
  final double totalDistance;
  final int sprints;
  final double currentAcceleration;

  const _AiLiveStats({
    required this.currentSpeed,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.totalDistance,
    required this.sprints,
    required this.currentAcceleration,
  });

  const _AiLiveStats.empty()
      : currentSpeed = 0,
        avgSpeed = 0,
        maxSpeed = 0,
        totalDistance = 0,
        sprints = 0,
        currentAcceleration = 0;
}

class _AiMatchSummary {
  final int eventsCount;
  final int suggestionsCount;
  final int positiveSuggestions;
  final int negativeSuggestions;
  final double avgSuggestionConfidence;
  final double currentSpeed;
  final double distance;
  final int sprints;
  final int pointsCount;

  final double possessionHomePct;
  final double possessionAwayPct;
  final double myPossessionPct;
  final double opponentPossessionPct;

  final int passesTotal;
  final int shotsTotal;
  final int dribblesTotal;
  final int homePasses;
  final int awayPasses;
  final int homeShots;
  final int awayShots;
  final int homeInterceptions;
  final int awayInterceptions;
  final int homeTurnoversWon;
  final int awayTurnoversWon;
  final int homeTurnoversLost;
  final int awayTurnoversLost;

  const _AiMatchSummary({
    required this.eventsCount,
    required this.suggestionsCount,
    required this.positiveSuggestions,
    required this.negativeSuggestions,
    required this.avgSuggestionConfidence,
    required this.currentSpeed,
    required this.distance,
    required this.sprints,
    required this.pointsCount,
    required this.possessionHomePct,
    required this.possessionAwayPct,
    required this.myPossessionPct,
    required this.opponentPossessionPct,
    required this.passesTotal,
    required this.shotsTotal,
    required this.dribblesTotal,
    required this.homePasses,
    required this.awayPasses,
    required this.homeShots,
    required this.awayShots,
    required this.homeInterceptions,
    required this.awayInterceptions,
    required this.homeTurnoversWon,
    required this.awayTurnoversWon,
    required this.homeTurnoversLost,
    required this.awayTurnoversLost,
  });
}