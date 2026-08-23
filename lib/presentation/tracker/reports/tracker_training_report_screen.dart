import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_club_ai_assistant_panel.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'tracker_export_viewer.dart';

import 'tracker_training_report_api.dart';
import 'tracker_training_report_models.dart';
import '../models/tracker_pro_models.dart';
import '../widgets/tracker_coach_review_card.dart';

class _ReportExportSection {
  const _ReportExportSection(
      {required this.id,
      required this.title,
      required this.note,
      required this.icon});
  final String id;
  final String title;
  final String note;
  final IconData icon;
}

const List<_ReportExportSection> _reportExportSections = [
  // Порядок повторяет основную аналитику: отчёт собирается из тех же блоков,
  // а не живёт отдельным набором экранов со своей терминологией.
  _ReportExportSection(
      id: 'summary',
      title: 'Обзор',
      note: 'KPI, длительность и нагрузка сессии',
      icon: Icons.dashboard_rounded),
  _ReportExportSection(
      id: 'maps',
      title: 'Карта',
      note: 'маршрут, события и тепловая карта',
      icon: Icons.map_rounded),
  _ReportExportSection(
      id: 'events',
      title: 'Журнал',
      note: 'ключевые моменты, время и точки на поле',
      icon: Icons.view_timeline_rounded),
  _ReportExportSection(
      id: 'speed',
      title: 'Скорость',
      note: 'график, зоны, HIR и спринты',
      icon: Icons.speed_rounded),
  _ReportExportSection(
      id: 'internal',
      title: 'Пульс',
      note: 'Кардиодатчик, зоны ЧСС и нагрузка',
      icon: Icons.favorite_rounded),
  _ReportExportSection(
      id: 'players',
      title: 'Команда',
      note: 'состав, карточки и Performance Matrix',
      icon: Icons.groups_rounded),
  _ReportExportSection(
      id: 'rating',
      title: 'Рейтинг',
      note: 'радар и сравнение игроков',
      icon: Icons.leaderboard_rounded),
  _ReportExportSection(
      id: 'locomotor',
      title: 'Локомоторика',
      note: 'дистанция, V3/V4/V5 и интенсивность',
      icon: Icons.directions_run_rounded),
  _ReportExportSection(
      id: 'mechanics',
      title: 'Механика',
      note: 'ускорения, торможения и взрывные действия',
      icon: Icons.compare_arrows_rounded),
  _ReportExportSection(
      id: 'microcycle',
      title: 'Микроцикл',
      note: 'динамика нагрузки и сравнение дней',
      icon: Icons.calendar_view_week_rounded),
  _ReportExportSection(
      id: 'periods',
      title: 'Периоды',
      note: 'таймы, упражнения и интервалы сессии',
      icon: Icons.segment_rounded),
  _ReportExportSection(
      id: 'player_pages',
      title: 'Листы игроков',
      note: 'карта, скорость и ЧСС по каждому игроку',
      icon: Icons.badge_rounded),
  _ReportExportSection(
      id: 'ai',
      title: 'ИИ-анализ',
      note: 'выводы и акценты для тренера',
      icon: Icons.auto_awesome_rounded),
];

Set<String> _defaultReportExportSectionIds() =>
    _reportExportSections.map((e) => e.id).toSet();
List<String> _normalizeReportExportSections(Set<String> selected) {
  final ids = selected.isEmpty
      ? _defaultReportExportSectionIds()
      : Set<String>.from(selected);
  if (ids.contains('internal')) ids.add('hr');
  if (ids.contains('maps')) ids.add('heatmap');
  return ids.toList(growable: false);
}

String _exportSectionsLabel(Set<String> selected) {
  final count =
      selected.isEmpty ? _reportExportSections.length : selected.length;
  if (count >= _reportExportSections.length) return 'Все разделы';
  if (count == 1) {
    final id = selected.first;
    return _reportExportSections
        .firstWhere((s) => s.id == id,
            orElse: () => _reportExportSections.first)
        .title;
  }
  return '$count раздел(ов)';
}

class TrackerTrainingReportScreen extends StatefulWidget {
  const TrackerTrainingReportScreen({
    super.key,
    required this.sessionId,
    this.sessionIds = const <int>[],
    required this.teamId,
    required this.teamName,
    this.clubId = 0,
    this.userId = 0,
    this.api,
    this.embedded = false,
    this.initialSelectedPlayerIds = const <int>{},
    this.analyticsSection,
    this.selectionOnly = false,
    this.autoOpenSelection = false,
    this.inlineAnalyticsReport = false,
    this.onSelectionClosed,
    this.rosterPlayers = const <TrackerPlayerOption>[],
    this.expectedParticipantIds = const <int>[],
    this.expectedParticipantNames = const <String>[],
    this.personalSessionMode = false,
  });

  final int sessionId;

  /// Все технические session_id одной выбранной командной тренировки.
  /// sessionId остаётся основной записью для совместимости со старым API.
  final List<int> sessionIds;
  final int teamId;
  final String teamName;
  final int clubId;
  final int userId;
  final TrackerTrainingReportApi? api;
  final bool embedded;
  final Set<int> initialSelectedPlayerIds;

  /// When set, the screen is used as a single analytics tab and renders only
  /// the requested analytical block without report controls.
  final String? analyticsSection;

  /// Report workspace mode: player/section selection + preview/export only,
  /// without the duplicated locomotor/mechanics/microcycle/AI inner tabs.
  final bool selectionOnly;

  /// Opens the large report selector as soon as report data is loaded.
  final bool autoOpenSelection;

  /// Inline report shown inside Analytics. Uses the selected analytics session
  /// and exposes only player selection plus PDF/Excel actions.
  final bool inlineAnalyticsReport;

  /// Called after the selector is closed when autoOpenSelection is enabled.
  final VoidCallback? onSelectionClosed;

  /// Канонический состав команды из аналитики. Нужен для замены технических
  /// подписей API вида «Игрок 175» на реальные ФИО и фотографии.
  final List<TrackerPlayerOption> rosterPlayers;

  /// Фактический состав выбранной групповой тренировки из карточки календаря.
  /// Нужен, чтобы игрок без GPS/кардиодатчика не исчезал из списка отчёта.
  final List<int> expectedParticipantIds;
  final List<String> expectedParticipantNames;

  /// Личная тренировка игрока: ИИ работает в player-only режиме и не
  /// показывает тренерский журнал/оценку, которые относятся только к
  /// командному кабинету тренера.
  final bool personalSessionMode;

  @override
  State<TrackerTrainingReportScreen> createState() =>
      _TrackerTrainingReportScreenState();
}

class _TrackerTrainingReportScreenState
    extends State<TrackerTrainingReportScreen> {
  late final TrackerTrainingReportApi _api;
  late Future<TrackerTrainingReport> _future;
  int _tab = 0;
  Uri? _exportPreviewUri;
  String _exportPreviewTitle = 'Экспорт';
  final Set<int> _selectedReportPlayerIds = <int>{};
  final Set<String> _selectedExportSectionIds =
      _defaultReportExportSectionIds();
  bool _autoSelectionOpened = false;

  List<int> _requestedSessionIds() {
    final result = <int>[];
    for (final id in <int>[widget.sessionId, ...widget.sessionIds]) {
      if (id > 0 && !result.contains(id)) result.add(id);
    }
    return result;
  }

  int? _personalReportPlayerId() {
    for (final id in widget.initialSelectedPlayerIds) {
      if (id > 0) return id;
    }
    for (final id in widget.expectedParticipantIds) {
      if (id > 0) return id;
    }
    if (widget.rosterPlayers.length == 1 && widget.rosterPlayers.first.id > 0) {
      return widget.rosterPlayers.first.id;
    }
    return null;
  }

  Future<TrackerTrainingReport> _loadReport() async {
    TrackerTrainingReport report;
    if (widget.personalSessionMode) {
      // Personal sessions live behind player_* endpoints. Using the team
      // get_training_report.php endpoint here caused the production server to
      // close the socket before headers (the error visible in «Мои тренировки»).
      report = await _api.loadPersonalTrainingReport(
        sessionId: widget.sessionId,
        teamId: widget.teamId,
        ownerUserId: widget.userId,
        playerId: _personalReportPlayerId(),
        teamName: widget.teamName,
        rosterPlayers: widget.rosterPlayers,
      );
    } else {
      report = await _api.loadTrainingReports(
        sessionId: widget.sessionId,
        sessionIds: _requestedSessionIds(),
        teamId: widget.teamId,
        rosterPlayers: widget.rosterPlayers,
      );
    }
    return _withExpectedParticipants(report);
  }

  bool _sameRequestedSessions(TrackerTrainingReportScreen other) {
    final current = _requestedSessionIds().toSet();
    final previous = <int>{
      other.sessionId,
      ...other.sessionIds.where((id) => id > 0)
    };
    return current.length == previous.length && current.containsAll(previous);
  }

  TrackerTrainingReport _withExpectedParticipants(
      TrackerTrainingReport report) {
    final expectedIds =
        widget.expectedParticipantIds.where((id) => id > 0).toSet();
    final expectedNames = widget.expectedParticipantNames
        .map(_normalizeParticipantName)
        .where((name) => name.isNotEmpty)
        .toSet();
    if (expectedIds.isEmpty && expectedNames.isEmpty) return report;

    TrackerPlayerOption? rosterByExpected(int? id, String normalizedName) {
      for (final player in widget.rosterPlayers) {
        if (id != null &&
            (player.id == id || player.identityIds.contains(id))) {
          return player;
        }
        if (normalizedName.isNotEmpty &&
            _normalizeParticipantName(player.name) == normalizedName) {
          return player;
        }
      }
      return null;
    }

    bool rowMatches(
      TrackerTrainingPlayerRow row,
      int? id,
      String normalizedName,
      TrackerPlayerOption? roster,
    ) {
      final rowId = row.playerId;
      if (id != null && rowId != null) {
        if (rowId == id) return true;
        if (roster != null && roster.identityIds.contains(rowId)) return true;
      }
      final rowName = _normalizeParticipantName(row.name);
      return normalizedName.isNotEmpty && rowName == normalizedName;
    }

    final source = <TrackerTrainingPlayerRow>[
      ...report.players,
      ...report.diagnosticPlayers,
    ];
    final participants = <TrackerTrainingPlayerRow>[];
    final seen = <String>{};

    void addParticipant(int? id, String rawName) {
      final normalizedName = _normalizeParticipantName(rawName);
      final roster = rosterByExpected(id, normalizedName);
      final effectiveId = roster?.id ?? id;
      final effectiveName = (roster?.name ?? rawName).trim();
      final key = effectiveId != null && effectiveId > 0
          ? 'id:$effectiveId'
          : 'name:${_normalizeParticipantName(effectiveName)}';
      if (key == 'name:' || !seen.add(key)) return;

      TrackerTrainingPlayerRow? matched;
      for (final row in source) {
        if (rowMatches(row, id, normalizedName, roster)) {
          matched = row;
          break;
        }
      }
      if (matched != null) {
        participants.add(matched.copyWith(
          playerId: effectiveId,
          name: effectiveName.isNotEmpty ? effectiveName : matched.name,
          avatarUrl: (roster?.avatar ?? '').trim().isNotEmpty
              ? roster!.avatar
              : matched.avatarUrl,
          number: (roster?.number ?? '').trim().isNotEmpty
              ? roster!.number
              : matched.number,
          position: (roster?.position ?? '').trim().isNotEmpty
              ? roster!.position
              : matched.position,
          sessionsCount: math.max(1, matched.sessionsCount),
        ));
        return;
      }

      participants.add(TrackerTrainingPlayerRow(
        playerId: effectiveId,
        name: effectiveName.isNotEmpty
            ? effectiveName
            : (effectiveId == null ? 'Игрок' : 'Игрок $effectiveId'),
        avatarUrl: roster?.avatar ?? '',
        number: roster?.number ?? '',
        position: roster?.position ?? '',
        duration: '00:00:00',
        distanceM: 0,
        metersPerMin: 0,
        maxSpeedKmh: 0,
        accelerations: 0,
        decelerations: 0,
        accDecPerMin: 0,
        explosiveActions: 0,
        v3RunM: 0,
        v4HsrM: 0,
        v5SprintM: 0,
        sprintCount: 0,
        highSpeedWorkM: 0,
        highSpeedActions: 0,
        playerLoad: 0,
        heartRateMaxPercent: 0,
        hrExertion: 0,
        sessionsCount: 1,
      ));
    }

    for (final id in expectedIds) {
      final roster = rosterByExpected(id, '');
      addParticipant(id, roster?.name ?? '');
    }
    for (final name in widget.expectedParticipantNames) {
      final normalizedName = _normalizeParticipantName(name);
      final roster = rosterByExpected(null, normalizedName);
      addParticipant(roster?.id, roster?.name ?? name);
    }
    if (participants.isEmpty) return report;

    return TrackerTrainingReport(
      sessionId: report.sessionId,
      sessionIds: report.sessionIds,
      title: report.title,
      dateLabel: report.dateLabel,
      teamId: report.teamId,
      clubId: report.clubId,
      teamName: report.teamName,
      teamLogoUrl: report.teamLogoUrl,
      opponent: report.opponent,
      durationLabel: report.durationLabel,
      playersCount: participants.length,
      pointsCount: report.pointsCount,
      hasData: report.hasData,
      dataStatus: report.dataStatus,
      summary: report.summary,
      periods: report.periods,
      microcycle: report.microcycle,
      players: participants,
      diagnosticPlayers: report.diagnosticPlayers,
      routePoints: report.routePoints,
      heatmapPoints: report.heatmapPoints,
      speedZones: report.speedZones,
      heartRateTimeline: report.heartRateTimeline,
      events: report.events,
    );
  }

  String _normalizeParticipantName(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'\s+'), ' ');

  List<String> _activeExportSections() =>
      _normalizeReportExportSections(_selectedExportSectionIds);

  String _activeExportSectionsLabel() =>
      _exportSectionsLabel(_selectedExportSectionIds);

  int _playerSelectionKey(TrackerTrainingPlayerRow player, int index) {
    final id = player.playerId;
    if (id != null && id > 0) return id;
    // fallback for rows that come from diagnostic/report API without player_id
    return -100000 - index;
  }

  List<TrackerTrainingPlayerRow> _filterPlayerRows(
      List<TrackerTrainingPlayerRow> rows) {
    if (_selectedReportPlayerIds.isEmpty) return rows;
    final result = <TrackerTrainingPlayerRow>[];
    for (var i = 0; i < rows.length; i++) {
      if (_selectedReportPlayerIds.contains(_playerSelectionKey(rows[i], i))) {
        result.add(rows[i]);
      }
    }
    return result;
  }

  List<int> _selectedRealPlayerIds() =>
      _selectedReportPlayerIds.where((id) => id > 0).toList(growable: false);

  List<TrackerTrainingPlayerRow> _reportFilterSourcePlayers(
      TrackerTrainingReport report) {
    final base =
        report.players.isNotEmpty ? report.players : report.diagnosticPlayers;
    final sessionPlayers =
        base.where(_isReportSessionPlayer).toList(growable: false);
    return sessionPlayers.isNotEmpty
        ? sessionPlayers
        : base.toList(growable: false);
  }

  void _toggleReportPlayerKey(int key, List<int> allKeys) {
    setState(() {
      if (_selectedReportPlayerIds.isEmpty) {
        _selectedReportPlayerIds.add(key);
      } else if (_selectedReportPlayerIds.contains(key)) {
        _selectedReportPlayerIds.remove(key);
      } else {
        _selectedReportPlayerIds.add(key);
      }
      if (_selectedReportPlayerIds.length >= allKeys.length)
        _selectedReportPlayerIds.clear();
    });
  }

  Set<String> _selectedReportPlayerNames(TrackerTrainingReport report) {
    final names = <String>{};
    void collect(List<TrackerTrainingPlayerRow> rows) {
      for (var i = 0; i < rows.length; i++) {
        if (_selectedReportPlayerIds
            .contains(_playerSelectionKey(rows[i], i))) {
          final name = rows[i].name.trim().toLowerCase();
          if (name.isNotEmpty) names.add(name);
        }
      }
    }

    collect(report.players);
    if (names.isEmpty) collect(report.diagnosticPlayers);
    return names;
  }

  TrackerReportSummary _summaryFromFilteredPlayers(
      List<TrackerTrainingPlayerRow> rows, TrackerReportSummary fallback) {
    if (rows.isEmpty) return fallback;
    final moving = rows
        .where((p) =>
            p.distanceM > 0 ||
            p.maxSpeedKmh > 0 ||
            p.pointsCount > 0 ||
            p.heartRateSamplesCount > 0)
        .toList(growable: false);
    final src = moving.isEmpty ? rows : moving;
    double sum(double Function(TrackerTrainingPlayerRow p) pick) =>
        src.fold<double>(0, (a, p) => a + pick(p));
    double avg(double Function(TrackerTrainingPlayerRow p) pick) =>
        src.isEmpty ? 0 : sum(pick) / src.length;
    int isum(int Function(TrackerTrainingPlayerRow p) pick) =>
        src.fold<int>(0, (a, p) => a + pick(p));
    final hrPlayers = src
        .where((p) => p.heartRateSamplesCount > 0 || p.heartRateAvgBpm > 0)
        .toList(growable: false);
    final hrWeight = hrPlayers.fold<int>(
        0,
        (a, p) =>
            a + (p.heartRateSamplesCount > 0 ? p.heartRateSamplesCount : 1));
    final hrAvg = hrWeight <= 0
        ? 0.0
        : hrPlayers.fold<double>(
                0,
                (a, p) =>
                    a +
                    p.heartRateAvgBpm *
                        (p.heartRateSamplesCount > 0
                            ? p.heartRateSamplesCount
                            : 1)) /
            hrWeight;
    return TrackerReportSummary(
      averageDistanceM: avg((p) => p.distanceM),
      totalDistanceM: sum((p) => p.distanceM),
      highSpeedDistanceM: sum((p) => p.highSpeedWorkM),
      playerLoad: sum((p) => p.playerLoad),
      accDecPerMin: avg((p) => p.accDecPerMin),
      maxSpeedKmh: src.fold<double>(0, (m, p) => math.max(m, p.maxSpeedKmh)),
      avgSpeedKmh: avg((p) => p.avgSpeedKmh),
      distancePerMin: avg((p) => p.metersPerMin),
      accelerationCount: isum((p) => p.accelerations),
      decelerationCount: isum((p) => p.decelerations),
      explosiveActions: isum((p) => p.explosiveActions),
      sprintCount: isum((p) => p.sprintCount),
      sprintDistanceM: sum((p) => p.v5SprintM),
      v3RunM: sum((p) => p.v3RunM),
      v4HsrM: sum((p) => p.v4HsrM),
      v5SprintM: sum((p) => p.v5SprintM),
      heartRateAvgBpm: hrAvg,
      heartRateMaxBpm:
          hrPlayers.fold<double>(0, (m, p) => math.max(m, p.heartRateMaxBpm)),
      heartRateSamplesCount:
          hrPlayers.fold<int>(0, (a, p) => a + p.heartRateSamplesCount),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedReportPlayerIds
        .addAll(widget.initialSelectedPlayerIds.where((id) => id > 0));
    _api = widget.api ?? TrackerTrainingReportApi();
    _future = _loadReport();
  }

  @override
  void didUpdateWidget(covariant TrackerTrainingReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectionChanged = oldWidget.initialSelectedPlayerIds.length !=
            widget.initialSelectedPlayerIds.length ||
        !oldWidget.initialSelectedPlayerIds
            .containsAll(widget.initialSelectedPlayerIds);
    final oldParticipantIds =
        oldWidget.expectedParticipantIds.where((id) => id > 0).toSet();
    final nextParticipantIds =
        widget.expectedParticipantIds.where((id) => id > 0).toSet();
    final oldParticipantNames = oldWidget.expectedParticipantNames
        .map(_normalizeParticipantName)
        .where((name) => name.isNotEmpty)
        .toSet();
    final nextParticipantNames = widget.expectedParticipantNames
        .map(_normalizeParticipantName)
        .where((name) => name.isNotEmpty)
        .toSet();
    final participantsChanged =
        oldParticipantIds.length != nextParticipantIds.length ||
            !oldParticipantIds.containsAll(nextParticipantIds) ||
            oldParticipantNames.length != nextParticipantNames.length ||
            !oldParticipantNames.containsAll(nextParticipantNames);
    final sessionsChanged = !_sameRequestedSessions(oldWidget);
    if (sessionsChanged || participantsChanged || selectionChanged) {
      _selectedReportPlayerIds
        ..clear()
        ..addAll(widget.initialSelectedPlayerIds.where((id) => id > 0));
      if (sessionsChanged || participantsChanged) _future = _loadReport();
    }
  }

  void _reload() {
    setState(() {
      _future = _loadReport();
    });
  }

  void _openExport(Uri uri, {required String title}) {
    setState(() {
      _exportPreviewUri = uri;
      _exportPreviewTitle = title;
    });
  }

  Uri _pdfUriForReport(TrackerTrainingReport report, {List<String>? sections}) {
    final selectedSections = sections ?? _activeExportSections();
    // На Web строим печатный HTML прямо из тех же данных, которые видит экран отчёта:
    // так PDF/печать больше не зависит от урезанного серверного шаблона и получает
    // выбранных игроков, выбранные разделы, карты, теплокарту, графики, ЧСС и карточки игроков.
    // На native оставляем серверный PDF-эндпоинт с теми же параметрами фильтра.
    if (kIsWeb)
      return _PrintableTrainingReportHtml.buildUri(report,
          sections: selectedSections);
    return _api.pdfExportUri(
      sessionId: widget.sessionId,
      sessionIds: _requestedSessionIds(),
      teamId: widget.teamId,
      playerIds: _selectedRealPlayerIds(),
      playerNames: _selectedReportPlayerNames(report).toList(growable: false),
      sections: selectedSections,
      includeMaps: selectedSections.contains('maps'),
      includeHeatmap: selectedSections.contains('heatmap') ||
          selectedSections.contains('maps'),
      includeCharts: selectedSections.any((s) =>
          s == 'speed' ||
          s == 'internal' ||
          s == 'hr' ||
          s == 'rating' ||
          s == 'mechanics' ||
          s == 'microcycle' ||
          s == 'player_pages'),
      includePlayerPages: selectedSections.contains('player_pages'),
    );
  }

  Uri _csvUriForReport(TrackerTrainingReport report, {List<String>? sections}) {
    final selectedSections = sections ?? _activeExportSections();
    return _api.csvExportUri(
      sessionId: widget.sessionId,
      sessionIds: _requestedSessionIds(),
      teamId: widget.teamId,
      playerIds: _selectedRealPlayerIds(),
      playerNames: _selectedReportPlayerNames(report).toList(growable: false),
      sections: selectedSections,
    );
  }

  void _closeExportPreview() {
    setState(() => _exportPreviewUri = null);
  }

  TrackerTrainingReport _filteredReport(TrackerTrainingReport report) {
    if (_selectedReportPlayerIds.isEmpty) return report;

    final players = _filterPlayerRows(report.players);
    final diagnostic = _filterPlayerRows(report.diagnosticPlayers);

    // GPS / ЧСС можно точно отфильтровать только когда сервер прислал player_id.
    // Если строка игрока пришла без id, оставляем точки на карте, чтобы отчёт не становился пустым.
    final positiveIds = _selectedReportPlayerIds.where((id) => id > 0).toSet();
    final selectedNames = _selectedReportPlayerNames(report);
    bool sameName(String value) =>
        selectedNames.isNotEmpty &&
        selectedNames.contains(value.trim().toLowerCase());
    bool keepPoint(TrackerReportPoint p) {
      if (_selectedReportPlayerIds.isEmpty) return true;
      if (p.playerId != null && positiveIds.contains(p.playerId)) return true;
      return sameName(p.playerName);
    }

    bool keepHr(TrackerHeartRatePoint p) {
      if (_selectedReportPlayerIds.isEmpty) return true;
      if (p.playerId != null && positiveIds.contains(p.playerId)) return true;
      return sameName(p.playerName);
    }

    bool keepEvent(TrackerReportEvent event) {
      if (_selectedReportPlayerIds.isEmpty) return true;
      if (event.playerId != null && positiveIds.contains(event.playerId)) {
        return true;
      }
      return sameName(event.playerName);
    }

    final routePoints =
        report.routePoints.where(keepPoint).toList(growable: false);
    final heatmapPoints =
        report.heatmapPoints.where(keepPoint).toList(growable: false);

    return TrackerTrainingReport(
      sessionId: report.sessionId,
      sessionIds: report.sessionIds,
      title: report.title,
      dateLabel: report.dateLabel,
      teamId: report.teamId,
      clubId: report.clubId,
      teamName: report.teamName,
      teamLogoUrl: report.teamLogoUrl,
      opponent: report.opponent,
      durationLabel: report.durationLabel,
      playersCount: players.isNotEmpty ? players.length : diagnostic.length,
      pointsCount: routePoints.length,
      hasData: players.isNotEmpty || diagnostic.isNotEmpty,
      dataStatus: report.dataStatus,
      summary: _summaryFromFilteredPlayers(
          players.isNotEmpty ? players : diagnostic, report.summary),
      periods: report.periods,
      microcycle: report.microcycle,
      players: players,
      diagnosticPlayers: diagnostic,
      routePoints: routePoints,
      heatmapPoints: heatmapPoints,
      speedZones: report.speedZones,
      heartRateTimeline:
          report.heartRateTimeline.where(keepHr).toList(growable: false),
      events: report.events.where(keepEvent).toList(growable: false),
    );
  }

  Future<void> _openPlayerFilter(TrackerTrainingReport sourceReport) async {
    final basePlayers = sourceReport.players.isNotEmpty
        ? sourceReport.players
        : sourceReport.diagnosticPlayers;
    final players = basePlayers.toList(growable: false);
    if (players.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('В этой сессии пока нет игроков для выбора.')));
      return;
    }
    final playerKeys = <int>[
      for (var i = 0; i < players.length; i++)
        _playerSelectionKey(players[i], i)
    ];
    final temp = Set<int>.from(_selectedReportPlayerIds);

    Widget pickerBody(BuildContext modalContext, StateSetter modalSetState,
        {required bool desktop}) {
      return SafeArea(
        child: SizedBox(
          width: desktop ? 390 : double.infinity,
          height: desktop
              ? double.infinity
              : MediaQuery.sizeOf(modalContext).height * .78,
          child: Material(
            color: Colors.white,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 68),
                    padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
                    child: Row(children: [
                      const Icon(Icons.groups_rounded,
                          color: _R.green, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Text('Выбор игроков', style: _ReportType.title(16)),
                            const SizedBox(height: 3),
                            Text(
                                temp.isEmpty
                                    ? 'В отчёт включены все игроки'
                                    : 'Выбрано игроков: ${temp.length}',
                                style: const TextStyle(
                                    color: _R.muted,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700)),
                          ])),
                      TextButton(
                          onPressed: () => modalSetState(() => temp.clear()),
                          child: const Text('Все')),
                      IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: const Icon(Icons.close_rounded)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          color: _R.soft,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Row(children: [
                        Icon(Icons.search_rounded, color: _R.muted, size: 15),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                'Выберите одного или нескольких игроков',
                                style: TextStyle(
                                    color: _R.muted,
                                    fontSize: 11.2,
                                    fontWeight: FontWeight.w700))),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: players.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, i) {
                        final player = players[i];
                        final id = playerKeys[i];
                        final selected = temp.isEmpty || temp.contains(id);
                        return _NoHoverTap(
                          onTap: () => modalSetState(() {
                            if (temp.isEmpty) {
                              temp.add(id);
                            } else if (temp.contains(id)) {
                              temp.remove(id);
                            } else {
                              temp.add(id);
                            }
                            if (temp.length == players.length || temp.isEmpty)
                              temp.clear();
                          }),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 62),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                                color: selected ? _R.softGreen : Colors.white,
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              _PlayerAvatar(player: player, size: 38),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                    Text(player.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: _R.text,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 3),
                                    Text(
                                        'GPS ${player.pointsCount} · ЧСС ${player.heartRateSamplesCount} · ${player.distanceM.toStringAsFixed(0)} м',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: _R.muted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ])),
                              const SizedBox(width: 8),
                              Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: selected ? _R.green : _R.muted),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedReportPlayerIds
                              ..clear()
                              ..addAll(temp);
                          });
                          Navigator.pop(modalContext);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _R.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Применить',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ]),
          ),
        ),
      );
    }

    final desktop = MediaQuery.sizeOf(context).width >= 760;
    if (desktop) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Выбор игроков',
        barrierColor: Colors.black.withOpacity(.16),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            StatefulBuilder(
          builder: (context, modalSetState) => Align(
            alignment: Alignment.centerRight,
            child: pickerBody(context, modalSetState, desktop: true),
          ),
        ),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final offset =
              Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic));
          return SlideTransition(position: offset, child: child);
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: pickerBody(context, modalSetState, desktop: false),
        ),
      ),
    );
  }

  Future<void> _openExportOptions(TrackerTrainingReport sourceReport,
      TrackerTrainingReport visibleReport) async {
    final tempSections = Set<String>.from(_selectedExportSectionIds);

    Widget buildSelector(BuildContext modalContext, StateSetter modalSetState,
        {required bool desktop}) {
      final sectionsLabel = _exportSectionsLabel(tempSections);
      final playersLabel = _selectedReportPlayerIds.isEmpty
          ? 'все игроки'
          : '${_selectedReportPlayerIds.length} игрок(ов)';

      void toggleSection(String id) {
        modalSetState(() {
          if (tempSections.contains(id) && tempSections.length > 1) {
            tempSections.remove(id);
          } else {
            tempSections.add(id);
          }
        });
      }

      void saveSelection() {
        setState(() {
          _selectedExportSectionIds
            ..clear()
            ..addAll(tempSections);
        });
      }

      Future<void> openExportInModal(Uri uri, String title) async {
        saveSelection();
        await showDialog<void>(
          context: modalContext,
          barrierColor: Colors.black.withOpacity(.28),
          builder: (exportContext) => Dialog(
            insetPadding: const EdgeInsets.all(22),
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 820),
              child: Column(children: [
                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(),
                  child: Row(children: [
                    const Icon(Icons.description_rounded,
                        color: _R.green, size: 19),
                    const SizedBox(width: 7),
                    Expanded(child: Text(title, style: _ReportType.title(14))),
                    _RoundIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(exportContext).pop()),
                  ]),
                ),
                Expanded(child: TrackerExportViewer(uri: uri)),
              ]),
            ),
          ),
        );
      }

      Widget controls() => Column(
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 58),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: _R.border))),
                child: Row(children: [
                  Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: _R.softGreen,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: _R.greenLine)),
                      child: const Icon(Icons.calendar_month_rounded,
                          color: _R.green, size: 15)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Text('Выбор отчёта',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _ReportType.title(13.4)
                                .copyWith(color: _R.text)),
                        const SizedBox(height: 2),
                        Text(
                            '${visibleReport.dateLabel} · $sectionsLabel · $playersLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _ReportType.caption(10.4)
                                .copyWith(color: _R.muted)),
                      ])),
                  _RoundIconButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(modalContext).pop()),
                ]),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 50),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: _R.border))),
                child: Row(children: [
                  const Expanded(
                      child: _ReportSelectorTab(
                          icon: Icons.calendar_month_rounded,
                          label: 'Дата и сессия',
                          selected: true)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _ReportSelectorTab(
                          icon: Icons.groups_rounded,
                          label: 'Игроки',
                          selected: false,
                          onTap: () async {
                            Navigator.of(modalContext).pop();
                            await _openPlayerFilter(sourceReport);
                            if (mounted)
                              _openExportOptions(
                                  sourceReport, _filteredReport(sourceReport));
                          })),
                  const SizedBox(width: 6),
                  const Expanded(
                      child: _ReportSelectorTab(
                          icon: Icons.layers_rounded,
                          label: 'Блоки отчёта',
                          selected: false)),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  children: [
                    _ReportSessionHero(report: visibleReport),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Expanded(
                          child: Text('Что показать в предпросмотре',
                              style: TextStyle(
                                  color: _R.text,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900))),
                      TextButton(
                          onPressed: () => modalSetState(() => tempSections
                            ..clear()
                            ..addAll(_defaultReportExportSectionIds())),
                          child: const Text('Выбрать всё')),
                    ]),
                    for (final section in _reportExportSections) ...[
                      _ReportExportOptionTile(
                          section: section,
                          selected: tempSections.contains(section.id),
                          onTap: () => toggleSection(section.id)),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: _R.border))),
                child: Row(children: [
                  Expanded(
                      child: _ReportExportActionButton(
                          icon: Icons.picture_as_pdf_rounded,
                          label: 'PDF',
                          primary: false,
                          onTap: () {
                            openExportInModal(
                              _pdfUriForReport(_filteredReport(sourceReport),
                                  sections: _normalizeReportExportSections(
                                      tempSections)),
                              'PDF / печать',
                            );
                          })),
                  const SizedBox(width: 7),
                  Expanded(
                      child: _ReportExportActionButton(
                          icon: Icons.table_chart_rounded,
                          label: 'Excel',
                          primary: false,
                          onTap: () {
                            openExportInModal(
                              _csvUriForReport(_filteredReport(sourceReport),
                                  sections: _normalizeReportExportSections(
                                      tempSections)),
                              'Excel / CSV отчёт',
                            );
                          })),
                  const SizedBox(width: 7),
                  Expanded(
                      flex: 2,
                      child: _ReportExportActionButton(
                          icon: Icons.check_rounded,
                          label: 'Применить',
                          primary: true,
                          onTap: () {
                            saveSelection();
                            ScaffoldMessenger.maybeOf(modalContext)
                                ?.showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Состав отчёта применён. Можно открыть PDF или Excel.')),
                            );
                          })),
                ]),
              ),
            ],
          );

      if (!desktop) {
        return SafeArea(
            top: false,
            child: Container(
                decoration: const BoxDecoration(
                    color: _R.bg,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(18))),
                child: controls()));
      }
      final viewport = MediaQuery.sizeOf(modalContext);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(6),
        child: SizedBox(
          width: math.max(320.0, viewport.width - 12),
          height: math.max(420.0, viewport.height - 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: _R.bg,
              child: Row(children: [
                SizedBox(
                    width:
                        math.min(390.0, math.max(320.0, viewport.width * .34)),
                    child: controls()),
                const VerticalDivider(width: 1, thickness: 1, color: _R.border),
                Expanded(
                  child: Column(children: [
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: _R.border))),
                      child: Row(children: [
                        Container(
                            width: 3,
                            height: 20,
                            decoration: BoxDecoration(
                                color: _R.green,
                                borderRadius: BorderRadius.circular(99))),
                        const SizedBox(width: 9),
                        Text('Предпросмотр отчёта',
                            style: _ReportType.section()),
                        const Spacer(),
                        Text('Изменения применяются сразу',
                            style: _ReportType.caption()),
                      ]),
                    ),
                    Expanded(
                        child: _ReportModalLivePreview(
                            report: _filteredReport(sourceReport),
                            sections: tempSections)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    final desktop = MediaQuery.sizeOf(context).width >= 900;
    if (desktop) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withOpacity(.22),
        builder: (modalContext) => StatefulBuilder(
            builder: (context, modalSetState) =>
                buildSelector(modalContext, modalSetState, desktop: true)),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (modalContext) => StatefulBuilder(
            builder: (context, modalSetState) => SizedBox(
                height: MediaQuery.sizeOf(context).height * .94,
                child: buildSelector(modalContext, modalSetState,
                    desktop: false))),
      );
    }
  }

  Future<void> _openReportDetail(String title, Widget child,
      {double initialChildSize = .88}) async {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 700) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: initialChildSize.clamp(.54, .96).toDouble(),
          minChildSize: .46,
          maxChildSize: .96,
          builder: (context, controller) => _ReportAdaptiveSheet(
            title: title,
            controller: controller,
            child: child,
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 820),
          child: _ReportAdaptiveSheet(title: title, child: child),
        ),
      ),
    );
  }

  Widget _buildAiAnalysis(TrackerTrainingReport report) {
    return _AiAnalysisTab(
      report: report,
      clubId: widget.clubId,
      userId: widget.userId,
      teamId: widget.teamId,
      teamName: widget.teamName,
      personalSessionMode: widget.personalSessionMode,
    );
  }

  String _reportLoadingLabel() {
    if (widget.analyticsSection == 'locomotor') return 'Локомоторика';
    if (widget.analyticsSection == 'mechanics') return 'Механика';
    if (widget.analyticsSection == 'microcycle') return 'Микроцикл';
    switch (_tab) {
      case 1:
        return 'Локомоторика';
      case 2:
        return 'Механика';
      case 4:
        return 'Микроцикл';
      default:
        return 'Отчёт';
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: FutureBuilder<TrackerTrainingReport>(
        future: _future,
        builder: (context, snapshot) {
          final sourceReport = snapshot.data ??
              TrackerTrainingReport.empty(
                  sessionId: widget.sessionId, teamName: widget.teamName);
          final report = _filteredReport(sourceReport);

          if (widget.autoOpenSelection &&
              snapshot.hasData &&
              !_autoSelectionOpened) {
            _autoSelectionOpened = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              try {
                await _openExportOptions(sourceReport, report);
              } finally {
                // Ждём завершения анимации закрытия внутреннего Dialog. Иначе
                // callback мог увидеть его как верхний route и внешний экран
                // отчёта оставался белым.
                await Future<void>.delayed(const Duration(milliseconds: 180));
                if (mounted) widget.onSelectionClosed?.call();
              }
            });
          }

          if (widget.autoOpenSelection) {
            // Внешний route служит только контейнером модального workspace.
            // Не показываем второй полноэкранный loader при закрытии окна.
            return const SizedBox.expand();
          }

          return LayoutBuilder(builder: (context, constraints) {
            final mobile = constraints.maxWidth < 620;
            final mobileTab = _tab >= 0 && _tab <= 2 ? _tab : 0;
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final playerFilter = _ReportPlayerFilterStrip(
              players: _reportFilterSourcePlayers(sourceReport),
              selectedKeys: _selectedReportPlayerIds,
              keyForPlayer: _playerSelectionKey,
              onToggle: _toggleReportPlayerKey,
              onAll: () => setState(_selectedReportPlayerIds.clear),
              onOpenFull: () => _openPlayerFilter(sourceReport),
            );
            if (widget.analyticsSection != null) {
              Widget section;
              switch (widget.analyticsSection) {
                case 'locomotor':
                  section = _LocomotorTab(report: report);
                  break;
                case 'mechanics':
                  section = _MechanicalTab(report: report);
                  break;
                case 'microcycle':
                  section = _MicrocycleTab(report: report);
                  break;
                case 'ai':
                  section = _buildAiAnalysis(report);
                  break;
                default:
                  section = _SummaryTab(
                      report: report, sections: _selectedExportSectionIds);
              }
              if (snapshot.hasError)
                return _ErrorView(error: '${snapshot.error}', onRetry: _reload);
              if (loading && snapshot.data == null)
                return _ReportLoadingProgress(label: _reportLoadingLabel());
              return ColoredBox(
                color: _R.bg,
                child: Padding(
                  padding: EdgeInsets.all(mobile ? 6 : 7),
                  child: section,
                ),
              );
            }

            if (widget.selectionOnly && widget.inlineAnalyticsReport) {
              if (snapshot.hasError) {
                return _ErrorView(error: '${snapshot.error}', onRetry: _reload);
              }
              if (loading && snapshot.data == null) {
                return _ReportLoadingProgress(label: _reportLoadingLabel());
              }
              return Stack(
                children: [
                  _InlineAnalyticsReportWorkspace(
                    report: report,
                    sourceReport: sourceReport,
                    selectedSections: _selectedExportSectionIds,
                    selectedPlayerIds: _selectedReportPlayerIds,
                    playerFilter: playerFilter,
                    onToggleSection: (id) {
                      setState(() {
                        if (_selectedExportSectionIds.contains(id) &&
                            _selectedExportSectionIds.length > 1) {
                          _selectedExportSectionIds.remove(id);
                        } else {
                          _selectedExportSectionIds.add(id);
                        }
                      });
                    },
                    onSelectAllSections: () {
                      setState(() {
                        _selectedExportSectionIds
                          ..clear()
                          ..addAll(_defaultReportExportSectionIds());
                      });
                    },
                    onPlayers: () => _openPlayerFilter(sourceReport),
                    onPdf: () => _openExport(
                      _pdfUriForReport(
                        _filteredReport(sourceReport),
                        sections: _normalizeReportExportSections(
                            _selectedExportSectionIds),
                      ),
                      title: 'PDF / печать',
                    ),
                    onExcel: () => _openExport(
                      _csvUriForReport(
                        _filteredReport(sourceReport),
                        sections: _normalizeReportExportSections(
                            _selectedExportSectionIds),
                      ),
                      title: 'Excel / CSV отчёт',
                    ),
                  ),
                  if (loading)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _ReportLoadingProgress(
                        label: _reportLoadingLabel(),
                        compact: true,
                      ),
                    ),
                  if (_exportPreviewUri != null)
                    Positioned.fill(
                      child: _ExportPreviewWindow(
                        title: _exportPreviewTitle,
                        uri: _exportPreviewUri!,
                        onClose: _closeExportPreview,
                      ),
                    ),
                ],
              );
            }

            if (widget.selectionOnly) {
              return Stack(
                children: [
                  Column(
                    children: [
                      if (widget.inlineAnalyticsReport)
                        Container(
                          constraints: const BoxConstraints(minHeight: 54),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                                bottom:
                                    BorderSide(color: _R.border, width: .7)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Отчёт', style: _ReportType.title(15)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedReportPlayerIds.isEmpty
                                          ? 'Все игроки выбранной сессии'
                                          : 'Выбрано игроков: ${_selectedReportPlayerIds.length}',
                                      style: _ReportType.caption(10.5),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _openPlayerFilter(sourceReport),
                                child: const Text('Игроки'),
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton(
                                onPressed: () => _openExport(
                                    _csvUriForReport(report),
                                    title: 'Excel / CSV отчёт'),
                                child: const Text('Excel'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton(
                                onPressed: () => _openExport(
                                    _pdfUriForReport(report),
                                    title: 'PDF / печать'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: _R.green,
                                    foregroundColor: Colors.white),
                                child: const Text('PDF'),
                              ),
                            ],
                          ),
                        )
                      else
                        _Header(
                          report: report,
                          loading: loading,
                          showBack: !widget.embedded,
                          onBack: () => Navigator.of(context).maybePop(),
                          onRefresh: _reload,
                          onPdf: () => _openExport(_pdfUriForReport(report),
                              title: 'PDF / печать'),
                          onExcel: () => _openExport(_csvUriForReport(report),
                              title: 'Excel / CSV отчёт'),
                          onPlayers: () => _openPlayerFilter(sourceReport),
                          onSettings: () =>
                              _openExportOptions(sourceReport, report),
                          selectedPlayersCount: _selectedReportPlayerIds.length,
                        ),
                      playerFilter,
                      if (snapshot.hasError)
                        Expanded(
                            child: _ErrorView(
                                error: '${snapshot.error}', onRetry: _reload))
                      else
                        Expanded(
                            child: _SummaryTab(
                                report: report,
                                sections: _selectedExportSectionIds)),
                    ],
                  ),
                  if (loading)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _ReportLoadingProgress(
                        label: _reportLoadingLabel(),
                        compact: true,
                      ),
                    ),
                  if (_exportPreviewUri != null)
                    Positioned.fill(
                      child: _ExportPreviewWindow(
                        title: _exportPreviewTitle,
                        uri: _exportPreviewUri!,
                        onClose: _closeExportPreview,
                      ),
                    ),
                ],
              );
            }

            return Stack(
              children: [
                if (mobile)
                  _MobileReportShell(
                    report: report,
                    clubId: widget.clubId,
                    userId: widget.userId,
                    teamId: widget.teamId,
                    teamName: widget.teamName,
                    loading: loading,
                    selectedTab: mobileTab,
                    showBack: !widget.embedded,
                    onBack: () => Navigator.of(context).maybePop(),
                    onRefresh: _reload,
                    onPdf: () => _openExport(_pdfUriForReport(report),
                        title: 'PDF / печать'),
                    onExcel: () => _openExport(_csvUriForReport(report),
                        title: 'Excel / CSV отчёт'),
                    onExportSettings: () =>
                        _openExportOptions(sourceReport, report),
                    exportSectionsLabel: _activeExportSectionsLabel(),
                    onPlayers: () => _openPlayerFilter(sourceReport),
                    onSelectTab: (i) => setState(() => _tab = i),
                    onOpenDetail: (title, child) {
                      _openReportDetail(title, child);
                    },
                    selectedPlayersCount: _selectedReportPlayerIds.length,
                    playerFilter: playerFilter,
                    error: snapshot.hasError ? '${snapshot.error}' : null,
                  )
                else
                  Column(
                    children: [
                      _Header(
                        report: report,
                        loading: loading,
                        showBack: !widget.embedded,
                        onBack: () => Navigator.of(context).maybePop(),
                        onRefresh: _reload,
                        onPdf: () => _openExport(_pdfUriForReport(report),
                            title: 'PDF / печать'),
                        onExcel: () => _openExport(_csvUriForReport(report),
                            title: 'Excel / CSV отчёт'),
                        onPlayers: () => _openPlayerFilter(sourceReport),
                        onSettings: () =>
                            _openExportOptions(sourceReport, report),
                        selectedPlayersCount: _selectedReportPlayerIds.length,
                      ),
                      _Tabs(
                        selected: _tab,
                        onSelect: (i) => setState(() => _tab = i),
                      ),
                      playerFilter,
                      if (snapshot.hasError)
                        Expanded(
                            child: _ErrorView(
                                error: '${snapshot.error}', onRetry: _reload))
                      else
                        Expanded(child: _buildTab(report)),
                    ],
                  ),
                if (loading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _ReportLoadingProgress(
                      label: _reportLoadingLabel(),
                      compact: true,
                    ),
                  ),
                if (_exportPreviewUri != null)
                  Positioned.fill(
                    child: _ExportPreviewWindow(
                      title: _exportPreviewTitle,
                      uri: _exportPreviewUri!,
                      onClose: _closeExportPreview,
                    ),
                  ),
              ],
            );
          });
        },
      ),
    );

    final reportBaseStyle = AppTypography.custom(
      size: 11.4,
      weight: FontWeight.w500,
      color: _R.graphite,
      height: 1.28,
      letterSpacing: 0,
    );
    final inheritedTextTheme = reportBaseStyle.fontFamily == null
        ? Theme.of(context).textTheme
        : Theme.of(context)
            .textTheme
            .apply(fontFamily: reportBaseStyle.fontFamily);
    final scaled = Theme(
      data: Theme.of(context).copyWith(textTheme: inheritedTextTheme),
      child: DefaultTextStyle.merge(
        style: reportBaseStyle,
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(.88)),
          child: content,
        ),
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: _R.bg, child: scaled);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: scaled),
    );
  }

  Widget _buildTab(TrackerTrainingReport report) {
    switch (_tab) {
      case 0:
        return _SummaryTab(report: report, sections: _selectedExportSectionIds);
      case 1:
        return _LocomotorTab(report: report);
      case 2:
        return _MechanicalTab(report: report);
      case 3:
        return _InternalLoadTab(report: report);
      case 4:
        return _MicrocycleTab(report: report);
      case 5:
        return _buildAiAnalysis(report);
      default:
        return _SummaryTab(report: report, sections: _selectedExportSectionIds);
    }
  }
}

class _ReportLoadingProgress extends StatefulWidget {
  const _ReportLoadingProgress({
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  State<_ReportLoadingProgress> createState() => _ReportLoadingProgressState();
}

class _ReportLoadingProgressState extends State<_ReportLoadingProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..forward();
    _progress = Tween<double>(begin: .08, end: .92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final value = _progress.value.clamp(.08, .92);
        final percent = (value * 100).round();
        return Material(
          color: Colors.white.withOpacity(.98),
          child: Container(
            height: widget.compact ? 30 : 44,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 10 : 16,
              vertical: widget.compact ? 5 : 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: widget.compact ? 5 : 6,
                      backgroundColor: const Color(0xFFF0F3F1),
                      color: _R.green,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${widget.label} · $percent%',
                  style: const TextStyle(
                    color: _R.text,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InlineAnalyticsReportWorkspace extends StatelessWidget {
  const _InlineAnalyticsReportWorkspace({
    required this.report,
    required this.sourceReport,
    required this.selectedSections,
    required this.selectedPlayerIds,
    required this.playerFilter,
    required this.onToggleSection,
    required this.onSelectAllSections,
    required this.onPlayers,
    required this.onPdf,
    required this.onExcel,
  });

  final TrackerTrainingReport report;
  final TrackerTrainingReport sourceReport;
  final Set<String> selectedSections;
  final Set<int> selectedPlayerIds;
  final Widget playerFilter;
  final ValueChanged<String> onToggleSection;
  final VoidCallback onSelectAllSections;
  final VoidCallback onPlayers;
  final VoidCallback onPdf;
  final VoidCallback onExcel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final mobile = constraints.maxWidth < 680;
        final sidebarWidth =
            math.min(390.0, math.max(310.0, constraints.maxWidth * .34));

        final selector = _InlineReportSelectorPane(
          report: report,
          selectedSections: selectedSections,
          selectedPlayerIds: selectedPlayerIds,
          playerFilter: playerFilter,
          onToggleSection: onToggleSection,
          onSelectAllSections: onSelectAllSections,
          onPlayers: onPlayers,
          onPdf: onPdf,
          onExcel: onExcel,
        );

        final preview = Column(
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(color: Colors.white),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _R.green,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Отчёт · предпросмотр',
                      style: _ReportType.section()
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    'те же данные, что в аналитике',
                    style: _ReportType.caption(10.3),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _ReportModalLivePreview(
                report: report,
                sections: selectedSections,
              ),
            ),
          ],
        );

        return ColoredBox(
          color: Colors.white,
          child: mobile
              ? Column(
                  children: [
                    SizedBox(
                        height: math.min(420, constraints.maxHeight * .48),
                        child: selector),
                    Expanded(child: preview),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                        width: compact
                            ? math.min(340, sidebarWidth)
                            : sidebarWidth,
                        child: selector),
                    Expanded(child: preview),
                  ],
                ),
        );
      },
    );
  }
}

class _InlineReportSelectorPane extends StatelessWidget {
  const _InlineReportSelectorPane({
    required this.report,
    required this.selectedSections,
    required this.selectedPlayerIds,
    required this.playerFilter,
    required this.onToggleSection,
    required this.onSelectAllSections,
    required this.onPlayers,
    required this.onPdf,
    required this.onExcel,
  });

  final TrackerTrainingReport report;
  final Set<String> selectedSections;
  final Set<int> selectedPlayerIds;
  final Widget playerFilter;
  final ValueChanged<String> onToggleSection;
  final VoidCallback onSelectAllSections;
  final VoidCallback onPlayers;
  final VoidCallback onPdf;
  final VoidCallback onExcel;

  @override
  Widget build(BuildContext context) {
    final playersLabel = selectedPlayerIds.isEmpty
        ? 'Все игроки выбранной сессии'
        : 'Выбрано игроков: ${selectedPlayerIds.length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Отчёты',
                style:
                    _ReportType.title(15).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                '${report.teamName} · ${report.dateLabel.isEmpty ? 'сессия' : report.dateLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ReportType.caption(9.8),
              ),
              const SizedBox(height: 2),
              Text(
                playersLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ReportType.caption(10.5),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Игроки',
                      style: _ReportType.section()
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                      onPressed: onPlayers, child: const Text('Выбрать')),
                ],
              ),
              playerFilter,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Разделы аналитики',
                      style: _ReportType.section()
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                      onPressed: onSelectAllSections, child: const Text('Все')),
                ],
              ),
              const SizedBox(height: 4),
              for (final section in _reportExportSections) ...[
                _ReportExportOptionTile(
                  section: section,
                  selected: selectedSections.contains(section.id),
                  onTap: () => onToggleSection(section.id),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Colors.white),
          child: Row(
            children: [
              Expanded(
                child: _ReportExportActionButton(
                  icon: Icons.table_chart_outlined,
                  label: 'Excel',
                  primary: false,
                  onTap: onExcel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReportExportActionButton(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF',
                  primary: true,
                  onTap: onPdf,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportSelectorTab extends StatelessWidget {
  const _ReportSelectorTab(
      {required this.icon,
      required this.label,
      required this.selected,
      this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _R.softGreen : Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: selected ? _R.greenLine : _R.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: selected ? _R.greenDark : _R.graphite),
            const SizedBox(width: 6),
            Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ReportType.action().copyWith(
                        color: selected ? _R.greenDark : _R.text,
                        fontSize: 10.6))),
          ]),
        ),
      ),
    );
  }
}

class _ReportSessionHero extends StatelessWidget {
  const _ReportSessionHero({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                  color: _R.green, borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: 8),
          Text('Выбранная тренировка', style: _ReportType.section())
        ]),
        const SizedBox(height: 9),
        Text(report.title.isEmpty ? 'Тренировка' : report.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _ReportType.title(14)),
        const SizedBox(height: 4),
        Text(
            '${report.dateLabel} · ${report.durationLabel} · ${report.teamName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _ReportType.caption(10.5)),
        const SizedBox(height: 9),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _ReportMiniPill(
              icon: Icons.groups_rounded,
              text: '${report.playersCount} игроков'),
          _ReportMiniPill(
              icon: Icons.gps_fixed_rounded, text: '${report.pointsCount} GPS'),
          _ReportMiniPill(
              icon: Icons.favorite_rounded,
              text: '${report.summary.heartRateSamplesCount} HR'),
        ]),
      ]),
    );
  }
}

class _ReportMiniPill extends StatelessWidget {
  const _ReportMiniPill({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
            color: _R.softGreen,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _R.greenLine)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: _R.greenDark),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: _R.greenDark,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w500))
        ]),
      );
}

class _ExportPreviewWindow extends StatelessWidget {
  const _ExportPreviewWindow(
      {required this.title, required this.uri, required this.onClose});

  final String title;
  final Uri uri;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final tablet = c.maxWidth < 1180;
        final margin = tablet ? 8.0 : 18.0;
        final width = tablet
            ? c.maxWidth - margin * 2
            : math.min(1220.0, c.maxWidth - margin * 2);
        final height = tablet
            ? c.maxHeight - margin * 2
            : math.min(760.0, c.maxHeight - margin * 2);

        return Container(
          color: Colors.white.withOpacity(.92),
          alignment: Alignment.center,
          padding: EdgeInsets.all(margin),
          child: SizedBox(
            width: width,
            height: height,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(tablet ? 14 : 18),
                border: Border.all(color: _R.border),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x16000000),
                      blurRadius: 18,
                      offset: Offset(0, 18))
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    height: tablet ? 42 : 46,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: _R.border))),
                    child: Row(
                      children: [
                        _RoundIconButton(
                            icon: Icons.close_rounded, onTap: onClose),
                        const SizedBox(width: 7),
                        Container(
                          width: tablet ? 28 : 32,
                          height: tablet ? 28 : 32,
                          decoration: BoxDecoration(
                              color: _R.soft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _R.border)),
                          child: const Icon(Icons.picture_as_pdf_rounded,
                              color: _R.graphite, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _ReportType.section(12)),
                              Text(
                                  'Документ открыт внутри Спортотеки · без перехода на сайт',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _ReportType.caption(10.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: TrackerExportViewer(uri: uri)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _R.soft,
      borderRadius: BorderRadius.circular(15),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 17, color: _R.graphite),
        ),
      ),
    );
  }
}

class _ReportAdaptiveSheet extends StatelessWidget {
  const _ReportAdaptiveSheet(
      {required this.title, required this.child, this.controller});

  final String title;
  final Widget child;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _R.bg,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(_R.sheetRadius),
              bottom: Radius.circular(18)),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                  color: _R.border, borderRadius: BorderRadius.circular(99)),
            ),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: _R.border))),
              child: Row(children: [
                Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _ReportType.title(14))),
                const SizedBox(width: 7),
                _RoundIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop()),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(8),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileReportShell extends StatelessWidget {
  const _MobileReportShell({
    required this.report,
    required this.clubId,
    required this.userId,
    required this.teamId,
    required this.teamName,
    required this.loading,
    required this.selectedTab,
    required this.onBack,
    required this.onRefresh,
    required this.onPdf,
    required this.onExcel,
    required this.onExportSettings,
    required this.exportSectionsLabel,
    required this.onPlayers,
    required this.onSelectTab,
    required this.onOpenDetail,
    this.selectedPlayersCount = 0,
    this.playerFilter,
    this.showBack = true,
    this.error,
  });

  final TrackerTrainingReport report;
  final int clubId;
  final int userId;
  final int teamId;
  final String teamName;
  final bool loading;
  final int selectedTab;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onPdf;
  final VoidCallback onExcel;
  final VoidCallback onExportSettings;
  final String exportSectionsLabel;
  final VoidCallback onPlayers;
  final ValueChanged<int> onSelectTab;
  final void Function(String title, Widget child) onOpenDetail;
  final int selectedPlayersCount;
  final Widget? playerFilter;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        color: _R.bg,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              _R.mobilePagePadding, 8, _R.mobilePagePadding, 22),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _DzenReportTopHeader(
              report: report,
              loading: loading,
              showBack: showBack,
              onBack: onBack,
              onRefresh: onRefresh,
              onPdf: onPdf,
              onExcel: onExcel,
              onExportSettings: onExportSettings,
              onPlayers: onPlayers,
            ),
            const SizedBox(height: 8),
            _ErrorView(error: error!, onRetry: onRefresh),
          ],
        ),
      );
    }

    return Container(
      color: _R.bg,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            _R.mobilePagePadding, 8, _R.mobilePagePadding, 22),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _DzenReportTopHeader(
            report: report,
            loading: loading,
            showBack: showBack,
            onBack: onBack,
            onRefresh: onRefresh,
            onPdf: onPdf,
            onExcel: onExcel,
            onExportSettings: onExportSettings,
            onPlayers: onPlayers,
          ),
          const SizedBox(height: 8),
          _DzenReportHeroCard(report: report, onPdf: onExportSettings),
          const SizedBox(height: 8),
          _DzenCoachBriefCard(report: report),
          const SizedBox(height: 8),
          _DzenReportSummaryCard(
            report: report,
            onOpenMap: () => onOpenDetail('Карта активности / тепловая карта',
                _ActivityMapPanel(report: report)),
            onOpenHr: () => onOpenDetail(
                'Пульс команды',
                SizedBox(
                    height: 460,
                    child: _HeartRateTimelineChart(report: report))),
            onOpenPlayers: () => onOpenDetail(
                'Игроки и локомоторика', _MobilePlayersDetails(report: report)),
          ),
          const SizedBox(height: 8),
          _DzenReportJournalCard(
            report: report,
            onOpen: () => onOpenDetail(
                'Журнал событий', _ReportEventsPanel(report: report)),
          ),
          const SizedBox(height: 8),
          _DzenReportPlayersCard(
              report: report,
              selectedPlayersCount: selectedPlayersCount,
              onPlayers: onPlayers),
          const SizedBox(height: 8),
          _DzenReportModulesCard(
            report: report,
            clubId: clubId,
            userId: userId,
            teamId: teamId,
            teamName: teamName,
            onOpenDetail: onOpenDetail,
          ),
          const SizedBox(height: 8),
          _DzenReportExportCard(
            selectedPlayersCount: selectedPlayersCount,
            sectionsLabel: exportSectionsLabel,
            onSettings: onExportSettings,
            onPlayers: onPlayers,
            onPdf: onPdf,
            onExcel: onExcel,
          ),
          const SizedBox(height: 8),
          _DzenSprintCard(report: report),
          const SizedBox(height: 8),
          _DzenRecentSessionsCard(report: report, onRefresh: onRefresh),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DzenReportTopHeader extends StatelessWidget {
  const _DzenReportTopHeader({
    required this.report,
    required this.loading,
    required this.showBack,
    required this.onBack,
    required this.onRefresh,
    required this.onPdf,
    required this.onExcel,
    required this.onExportSettings,
    required this.onPlayers,
  });

  final TrackerTrainingReport report;
  final bool loading;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onPdf;
  final VoidCallback onExcel;
  final VoidCallback onExportSettings;
  final VoidCallback onPlayers;

  @override
  Widget build(BuildContext context) {
    final team = _mobileReportTeamName(report);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 4, 4),
      child: Row(
        children: [
          if (showBack) ...[
            _DzenCircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
            const SizedBox(width: 7),
          ],
          _TeamLogo(url: report.teamLogoUrl, title: team, size: 44),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Отчёты',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _R.text,
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.1)),
                const SizedBox(height: 2),
                Text('$team · ${_mobileReportSessionLine(report)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (loading) ...[
            const SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(color: _R.green, strokeWidth: 2)),
            const SizedBox(width: 7),
          ],
          _NoHoverTap(
            onTap: () => _openMenu(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _R.border),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.menu_rounded, color: _R.graphite, size: 17),
                SizedBox(width: 6),
                Text('Меню',
                    style: TextStyle(
                        color: _R.text,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.36),
      builder: (sheetContext) {
        Widget action({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
          bool primary = false,
        }) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _NoHoverTap(
              onTap: () {
                Navigator.of(sheetContext).pop();
                Future<void>.microtask(onTap);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 58),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: primary ? _R.softGreen : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: primary ? _R.greenLine : _R.border, width: .8),
                ),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primary ? Colors.white : _R.soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        color: primary ? _R.green : _R.graphite, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: _R.text,
                                fontSize: 12.4,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                color: _R.muted,
                                fontSize: 10.2,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: _R.muted, size: 19),
                ]),
              ),
            ),
          );
        }

        final bottom = MediaQuery.of(sheetContext).padding.bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottom),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_R.sheetRadius),
                  bottom: Radius.circular(_R.sheetRadius)),
              child: Material(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                              color: _R.border,
                              borderRadius: BorderRadius.circular(99)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Меню отчёта',
                          style: TextStyle(
                              color: _R.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(_mobileReportSessionLine(report),
                          style: const TextStyle(
                              color: _R.muted,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      action(
                          icon: Icons.groups_rounded,
                          title: 'Игроки отчёта',
                          subtitle: 'вся команда или выбранные игроки',
                          onTap: onPlayers),
                      action(
                          icon: Icons.tune_rounded,
                          title: 'Состав отчёта',
                          subtitle: 'карты, графики, пульс и дополнительные блоки',
                          onTap: onExportSettings),
                      action(
                          icon: Icons.picture_as_pdf_rounded,
                          title: 'Сформировать PDF',
                          subtitle: 'предпросмотр, печать и сохранение',
                          onTap: onPdf,
                          primary: true),
                      action(
                          icon: Icons.table_chart_rounded,
                          title: 'Выгрузить Excel / CSV',
                          subtitle: 'табличные показатели по игрокам',
                          onTap: onExcel),
                      action(
                          icon: Icons.refresh_rounded,
                          title: 'Обновить данные',
                          subtitle: 'повторно загрузить GPS и данные кардиодатчика',
                          onTap: onRefresh),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DzenReportHeroCard extends StatelessWidget {
  const _DzenReportHeroCard({required this.report, required this.onPdf});
  final TrackerTrainingReport report;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report);
    final gpsCount = players
        .where((p) => p.distanceM > 0 || p.pointsCount > 0 || p.hasMovement)
        .length;
    final polarCount = players
        .where((p) =>
            p.heartRateSamplesCount > 0 || p.heartRateAvgBpm > 0)
        .length;

    Widget metric(IconData icon, String value, String label) {
      return Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.88),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: _R.green, size: 17),
            const SizedBox(height: 8),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.text,
                    fontSize: 15.2,
                    fontWeight: FontWeight.w900,
                    height: 1)),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.muted,
                    fontSize: 9.4,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }

    Widget sourcePill(IconData icon, String label, int count) {
      final active = count > 0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? _R.green : _R.muted, size: 13),
          const SizedBox(width: 5),
          Text('$label $count/${math.max(1, players.length)}',
              style: TextStyle(
                  color: active ? _R.greenDark : _R.muted,
                  fontSize: 9.8,
                  fontWeight: FontWeight.w800)),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FAF4), Color(0xFFE3F5EA)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _R.greenLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _R.green,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.assignment_rounded,
                color: Colors.white, size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.title.trim().isEmpty
                    ? 'Отчёт по тренировке'
                    : report.title.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.text,
                        fontSize: 17.2,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                        letterSpacing: -.25)),
                const SizedBox(height: 5),
                Text(_mobileReportSessionLine(report),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.graphite,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: report.hasData ? _R.green : _R.muted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(report.hasData ? 'ГОТОВО' : 'ОЖИДАНИЕ',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.8,
                    fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 13),
        Row(children: [
          metric(Icons.route_rounded,
              _mobileReportMeters(_mobileReportDistance(report)), 'Дистанция'),
          const SizedBox(width: 7),
          metric(Icons.speed_rounded, _mobileReportSpeed(report), 'Макс. скорость'),
        ]),
        const SizedBox(height: 7),
        Row(children: [
          metric(Icons.favorite_rounded, _mobileReportHr(report), 'Средний пульс'),
          const SizedBox(width: 7),
          metric(Icons.groups_rounded, '${report.playersCount}', 'Игроков'),
        ]),
        const SizedBox(height: 11),
        Row(children: [
          sourcePill(Icons.sensors_rounded, 'GPS', gpsCount),
          const SizedBox(width: 7),
          sourcePill(Icons.favorite_rounded, 'Кардиодатчик', polarCount),
          const Spacer(),
          TextButton.icon(
            onPressed: onPdf,
            icon: const Icon(Icons.tune_rounded, size: 15),
            label: const Text('Настроить'),
            style: TextButton.styleFrom(
              foregroundColor: _R.greenDark,
              textStyle:
                  const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _DzenCoachBriefCard extends StatelessWidget {
  const _DzenCoachBriefCard({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report);
    final gpsCount = players
        .where((p) => p.distanceM > 0 || p.pointsCount > 0 || p.hasMovement)
        .length;
    final polarCount = players
        .where((p) =>
            p.heartRateSamplesCount > 0 || p.heartRateAvgBpm > 0)
        .length;
    final summary = report.summary;

    Widget line({
      required IconData icon,
      required String title,
      required String value,
      required String note,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _R.softGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _R.green, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: _R.text,
                          fontSize: 11.4,
                          fontWeight: FontWeight.w800)),
                ),
                Text(value,
                    style: const TextStyle(
                        color: _R.greenDark,
                        fontSize: 11.4,
                        fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 3),
              Text(note,
                  style: const TextStyle(
                      color: _R.muted,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w600,
                      height: 1.25)),
            ]),
          ),
        ]),
      );
    }

    final cardioValue = summary.heartRateAvgBpm > 0
        ? '${summary.heartRateAvgBpm.toStringAsFixed(0)} / ${summary.heartRateMaxBpm.toStringAsFixed(0)}'
        : 'нет данных';
    final coverageComplete = players.isNotEmpty &&
        gpsCount == players.length &&
        polarCount == players.length;

    return _DzenEdgeCard(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Text('Главное для тренера',
                style: TextStyle(
                    color: _R.text,
                    fontSize: 15.4,
                    fontWeight: FontWeight.w900)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: coverageComplete ? _R.softGreen : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(coverageComplete ? 'ПОЛНЫЕ ДАННЫЕ' : 'ЕСТЬ ПРОПУСКИ',
                style: TextStyle(
                    color: coverageComplete
                        ? _R.greenDark
                        : const Color(0xFFF59E0B),
                    fontSize: 8.8,
                    fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 4),
        line(
          icon: Icons.route_rounded,
          title: 'Объём работы',
          value: _mobileReportMeters(_mobileReportDistance(report)),
          note:
              '${report.playersCount} игрок(ов) · ${_mobileReportShortDuration(report.durationLabel)}',
        ),
        const Divider(height: 1, color: _R.border),
        line(
          icon: Icons.bolt_rounded,
          title: 'Скоростная работа',
          value: '${summary.sprintCount} спринт.',
          note:
              'максимум ${_mobileReportSpeed(report)} · HSR ${_mobileReportMeters(summary.highSpeedDistanceM)}',
        ),
        const Divider(height: 1, color: _R.border),
        line(
          icon: Icons.favorite_rounded,
          title: 'Кардио',
          value: cardioValue,
          note: summary.heartRateAvgBpm > 0
              ? 'средняя / максимальная ЧСС · кардиодатчик $polarCount/${math.max(1, players.length)}'
              : 'Кардиодатчик не передал достаточно данных для оценки внутренней нагрузки',
        ),
        if (!coverageComplete) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              'Покрытие данных: GPS $gpsCount/${math.max(1, players.length)}, кардиодатчик $polarCount/${math.max(1, players.length)}. Итоги считаются только по доступным датчикам.',
              style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 9.8,
                  fontWeight: FontWeight.w700,
                  height: 1.3),
            ),
          ),
        ],
      ]),
    );
  }
}

class _DzenSelectedSessionCard extends StatelessWidget {
  const _DzenSelectedSessionCard({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _DzenMetric(Icons.route_rounded,
          _mobileReportMeters(_mobileReportDistance(report)), 'Дистанция'),
      _DzenMetric(
          Icons.speed_rounded, _mobileReportSpeed(report), 'Макс. скорость'),
      _DzenMetric(Icons.favorite_rounded, _mobileReportHr(report), 'Ср. пульс'),
      _DzenMetric(Icons.groups_rounded, '${report.playersCount}', 'Игрока'),
    ];
    return _DzenEdgeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DzenCardTitle(
              icon: Icons.calendar_month_rounded, title: 'Выбранная сессия'),
          const SizedBox(height: 4),
          SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  Expanded(child: _DzenMetricView(metric: metrics[i])),
                  if (i != metrics.length - 1)
                    Container(width: 1, height: 34, color: _R.border),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DzenReportJournalCard extends StatelessWidget {
  const _DzenReportJournalCard({required this.report, required this.onOpen});
  final TrackerTrainingReport report;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final events = report.events.take(5).toList(growable: false);
    return _DzenEdgeCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: _DzenCardTitle(
                icon: Icons.view_timeline_rounded, title: 'Журнал событий'),
          ),
          _NoHoverTap(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                  color: _R.softGreen,
                  borderRadius: BorderRadius.circular(9)),
              child: Text('${report.events.length} · открыть',
                  style: const TextStyle(
                      color: _R.greenDark,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text('События появятся после GPS-движения.',
              style: TextStyle(
                  color: _R.muted, fontSize: 10, fontWeight: FontWeight.w600))
        else
          for (var i = 0; i < events.length; i++) ...[
            _DzenReportJournalMiniRow(event: events[i]),
            if (i != events.length - 1)
              const Divider(height: 1, color: Color(0xFFE9ECEA)),
          ],
      ]),
    );
  }
}

class _DzenReportJournalMiniRow extends StatelessWidget {
  const _DzenReportJournalMiniRow({required this.event});
  final TrackerReportEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _reportEventColor(event);
    final title = event.title.trim().isNotEmpty
        ? event.title.trim()
        : _reportEventKindLabel(event.kind);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(8)),
          child: Text(_reportEventGlyph(event),
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(_reportElapsedLabel(event.elapsedMs),
              style: const TextStyle(
                  color: _R.muted, fontSize: 9.3, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: Text('${_reportEventPlayerShortName(event.playerName)} · $title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _R.text, fontSize: 10.2, fontWeight: FontWeight.w700)),
        ),
        if (event.hasPoint)
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Icon(Icons.location_on_rounded, size: 13, color: color),
          ),
      ]),
    );
  }
}

class _DzenReportPlayersCard extends StatelessWidget {
  const _DzenReportPlayersCard(
      {required this.report,
      required this.selectedPlayersCount,
      required this.onPlayers});
  final TrackerTrainingReport report;
  final int selectedPlayersCount;
  final VoidCallback onPlayers;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report);
    final visible = players.take(3).toList(growable: false);
    final label = selectedPlayersCount > 0
        ? 'Выбрано $selectedPlayersCount'
        : 'Все игроки';
    return _DzenEdgeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DzenIconBox(icon: Icons.groups_rounded, size: 34),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Игроки для выгрузки',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _R.text,
                              fontSize: 15.2,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(label,
                          style: TextStyle(
                              color: _R.muted,
                              fontSize: 10.4,
                              fontWeight: FontWeight.w800)),
                    ]),
              ),
              _DzenOutlineButton(label: 'Изменить', onTap: onPlayers),
            ],
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            const Text('Игроки появятся после загрузки сессии.',
                style: TextStyle(
                    color: _R.muted,
                    fontSize: 10.2,
                    fontWeight: FontWeight.w500))
          else
            Row(
              children: [
                for (final player in visible) ...[
                  _DzenPlayerPreview(player: player),
                  const SizedBox(width: 7),
                ],
                if (players.length > visible.length)
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: _R.soft,
                        shape: BoxShape.circle,
                        border: Border.all(color: _R.border)),
                    child: Text('+${players.length - visible.length}',
                        style: const TextStyle(
                            color: _R.graphite,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DzenReportExportCard extends StatelessWidget {
  const _DzenReportExportCard({
    required this.selectedPlayersCount,
    required this.sectionsLabel,
    required this.onSettings,
    required this.onPlayers,
    required this.onPdf,
    required this.onExcel,
  });

  final int selectedPlayersCount;
  final String sectionsLabel;
  final VoidCallback onSettings;
  final VoidCallback onPlayers;
  final VoidCallback onPdf;
  final VoidCallback onExcel;

  @override
  Widget build(BuildContext context) {
    final playerLabel = selectedPlayersCount > 0
        ? '$selectedPlayersCount игрок(ов)'
        : 'вся команда';
    return _DzenEdgeCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const _DzenIconBox(icon: Icons.tune_rounded, size: 34),
            const SizedBox(width: 7),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Выбор отчёта',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _R.text,
                          fontSize: 15.2,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('$sectionsLabel · $playerLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _R.muted,
                          fontSize: 10.4,
                          fontWeight: FontWeight.w800)),
                ])),
            _DzenOutlineButton(label: 'Настроить', onTap: onSettings),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _ReportExportActionButton(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF',
                    primary: true,
                    onTap: onPdf)),
            const SizedBox(width: 7),
            Expanded(
                child: _ReportExportActionButton(
                    icon: Icons.table_chart_rounded,
                    label: 'Excel',
                    primary: false,
                    onTap: onExcel)),
            const SizedBox(width: 7),
            Expanded(
                child: _ReportExportActionButton(
                    icon: Icons.groups_rounded,
                    label: 'Игроки',
                    primary: false,
                    onTap: onPlayers)),
          ]),
        ],
      ),
    );
  }
}

class _ReportExportActionButton extends StatelessWidget {
  const _ReportExportActionButton(
      {required this.icon,
      required this.label,
      required this.primary,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? _R.green : _R.softGreen,
          borderRadius: BorderRadius.circular(_R.mobileButtonRadius),
          border: Border.all(
              color: primary ? _R.green : _R.greenLine, width: .8),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!primary) ...[
                Icon(icon, color: _R.greenDark, size: 14),
                const SizedBox(width: 6),
              ],
              Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ReportType.action(primary: primary))),
            ]),
      ),
    );
  }
}

class _ReportExportOptionTile extends StatelessWidget {
  const _ReportExportOptionTile(
      {required this.section, required this.selected, required this.onTap});
  final _ReportExportSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _R.softGreen : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? _R.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : _R.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  section.icon,
                  size: 16,
                  color: selected ? _R.greenDark : _R.graphite,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _R.text,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      section.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _R.muted,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? _R.green : Colors.transparent,
                  shape: BoxShape.circle,
                  border:
                      selected ? null : Border.all(color: _R.border, width: .8),
                ),
                alignment: Alignment.center,
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 13)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DzenReportModulesCard extends StatelessWidget {
  const _DzenReportModulesCard({
    required this.report,
    required this.clubId,
    required this.userId,
    required this.teamId,
    required this.teamName,
    required this.onOpenDetail,
  });
  final TrackerTrainingReport report;
  final int clubId;
  final int userId;
  final int teamId;
  final String teamName;
  final void Function(String title, Widget child) onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final modules = [
      _DzenReportModule(
          Icons.dashboard_rounded,
          'Сводка',
          'KPI, карты, игроки',
          () => onOpenDetail(
              'Сводка отчёта', _MobileSummaryDetails(report: report))),
      _DzenReportModule(
          Icons.view_timeline_rounded,
          'Журнал',
          '${report.events.length} событий',
          () => onOpenDetail(
              'Журнал событий', _ReportEventsPanel(report: report))),
      _DzenReportModule(
          Icons.directions_run_rounded,
          'Локомоторика',
          'таблица как на ПК',
          () => onOpenDetail(
              'Локомоторика игроков', _MobilePlayersDetails(report: report))),
      _DzenReportModule(
          Icons.compare_arrows_rounded,
          'Механика',
          'ускорения / торможения',
          () => onOpenDetail(
              'Механика', _MobileMechanicsDetails(report: report))),
      _DzenReportModule(
          Icons.favorite_rounded,
          'Пульс',
          'HR и зоны',
          () => onOpenDetail('Пульс и внутренняя нагрузка',
              _MobileInternalLoadDetails(report: report))),
      _DzenReportModule(
          Icons.calendar_month_rounded,
          'Микроцикл',
          'динамика нагрузки',
          () => onOpenDetail(
              'Микроцикл', _MobileMicrocycleDetails(report: report))),
      _DzenReportModule(
        Icons.auto_awesome_rounded,
        'ИИ анализ',
        'выводы и заметки',
        () => onOpenDetail(
          'ИИ анализ',
          _MobileAiDetails(
            report: report,
            clubId: clubId,
            userId: userId,
            teamId: teamId,
            teamName: teamName,
          ),
        ),
      ),
    ];
    return _DzenEdgeCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _DzenCardTitle(
            icon: Icons.apps_rounded, title: 'Все разделы как на ПК'),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 84,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8),
          itemBuilder: (context, i) =>
              _DzenReportModuleTile(module: modules[i]),
        ),
      ]),
    );
  }
}

class _DzenReportModule {
  const _DzenReportModule(this.icon, this.title, this.note, this.onTap);
  final IconData icon;
  final String title;
  final String note;
  final VoidCallback onTap;
}

class _DzenReportModuleTile extends StatelessWidget {
  const _DzenReportModuleTile({required this.module});
  final _DzenReportModule module;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: module.onTap,
      borderRadius: BorderRadius.circular(_R.mobileButtonRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
            color: _R.soft,
            borderRadius: BorderRadius.circular(_R.mobileButtonRadius),
            border: Border.all(color: _R.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: _R.softGreen,
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(module.icon, color: _R.green, size: 16)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: _R.muted, size: 20),
          ]),
          const Spacer(),
          Text(module.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _R.text, fontSize: 12.2, fontWeight: FontWeight.w900)),
          const SizedBox(height: 1),
          Text(module.note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _R.muted, fontSize: 9.3, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _MobileSummaryDetails extends StatelessWidget {
  const _MobileSummaryDetails({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(title: 'ОБЩАЯ ИНФОРМАЦИЯ', child: _SummaryGrid(report: report)),
      const SizedBox(height: 8),
      _Card(
          title: 'КАРТА АКТИВНОСТИ / ТЕПЛОВАЯ КАРТА',
          child: _ActivityMapPanel(report: report)),
      const SizedBox(height: 8),
      _Card(
          title: 'ГРАФИК СКОРОСТИ',
          child: SizedBox(
              height: 420, child: _ReportSpeedGraphPanel(report: report))),
      const SizedBox(height: 8),
      _Card(title: 'ИГРОКИ И ТРЕКЕРЫ', child: _PlayersOverview(report: report)),
    ]);
  }
}

class _MobileMechanicsDetails extends StatelessWidget {
  const _MobileMechanicsDetails({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(
          title: 'УСКОРЕНИЯ И ТОРМОЖЕНИЯ',
          child: SizedBox(
              height: 420,
              child: _DualBarChart(
                  players: players,
                  first: (p) => p.accelerations.toDouble(),
                  second: (p) => p.decelerations.toDouble(),
                  firstLabel: 'Ускорения',
                  secondLabel: 'Торможения'))),
      const SizedBox(height: 8),
      _Card(
          title: 'ВЗРЫВНЫЕ ДЕЙСТВИЯ / ПОВОРОТЫ',
          child: SizedBox(
              height: 420,
              child: _DualBarChart(
                  players: players,
                  first: (p) => p.explosiveActions.toDouble(),
                  second: (p) => p.highSpeedActions.toDouble(),
                  firstLabel: 'Взрывные',
                  secondLabel: 'Повороты'))),
    ]);
  }
}

class _MobileMicrocycleDetails extends StatelessWidget {
  const _MobileMicrocycleDetails({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(
          title: 'ДИНАМИКА МИКРОЦИКЛА',
          child: SizedBox(
              height: 440, child: _MicrocycleChart(points: report.microcycle))),
      const SizedBox(height: 8),
      _Card(
          title: 'ПЕРИОДЫ / УПРАЖНЕНИЯ',
          child: _PeriodsTable(periods: report.periods)),
    ]);
  }
}

class _MobileAiDetails extends StatelessWidget {
  const _MobileAiDetails({
    required this.report,
    required this.clubId,
    required this.userId,
    required this.teamId,
    required this.teamName,
  });
  final TrackerTrainingReport report;
  final int clubId;
  final int userId;
  final int teamId;
  final String teamName;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 720,
        child: _AiAnalysisTab(
          report: report,
          clubId: clubId,
          userId: userId,
          teamId: teamId,
          teamName: teamName,
        ),
      ),
      const SizedBox(height: 8),
      _Card(
          title: 'РЕЙТИНГ И СРАВНЕНИЕ ИГРОКА',
          child: SizedBox(
              height: 500, child: _RadarComparisonPanel(report: report))),
    ]);
  }
}

class _DzenReportSummaryCard extends StatelessWidget {
  const _DzenReportSummaryCard(
      {required this.report,
      required this.onOpenMap,
      required this.onOpenHr,
      required this.onOpenPlayers});
  final TrackerTrainingReport report;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenHr;
  final VoidCallback onOpenPlayers;

  @override
  Widget build(BuildContext context) {
    return _DzenEdgeCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _DzenCardTitle(
                icon: Icons.insights_rounded, title: 'Сводка отчёта'),
          ),
          SizedBox(
            height: 244,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                SizedBox(
                    width: 166,
                    child: _DzenTeamSummaryPanel(
                        report: report, onTap: onOpenPlayers)),
                const SizedBox(width: 7),
                SizedBox(
                    width: 278,
                    child:
                        _DzenMapSummaryPanel(report: report, onTap: onOpenMap)),
                const SizedBox(width: 7),
                SizedBox(
                    width: 214,
                    child:
                        _DzenHrSummaryPanel(report: report, onTap: onOpenHr)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DzenSprintCard extends StatelessWidget {
  const _DzenSprintCard({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final s = report.summary;
    final items = [
      _DzenPlainStat(value: '${s.sprintCount}', label: 'Спринта'),
      _DzenPlainStat(
          value: _mobileReportMeters(s.sprintDistanceM),
          label: 'Общая дистанция'),
      _DzenPlainStat(
          value: _mobileReportShortDuration(report.durationLabel),
          label: 'Общая длительность'),
    ];
    return _DzenEdgeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DzenCardTitle(
              icon: Icons.directions_run_rounded, title: 'Спринты'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i != items.length - 1)
                  Container(width: 1, height: 34, color: _R.border),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DzenRecentSessionsCard extends StatelessWidget {
  const _DzenRecentSessionsCard(
      {required this.report, required this.onRefresh});
  final TrackerTrainingReport report;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final ids = _mobileReportSessionIds(report);
    return _DzenEdgeCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DzenCardTitle(
              icon: Icons.article_rounded, title: 'Последние сессии'),
          const SizedBox(height: 8),
          for (var i = 0; i < ids.length; i++)
            _DzenSessionRow(
              sessionId: ids[i],
              selected: ids[i] == report.sessionId,
              subtitle: i == 0
                  ? _mobileReportSessionRowSubtitle(report)
                  : _mobileReportPreviousRowSubtitle(report, i),
              onTap: onRefresh,
            ),
        ],
      ),
    );
  }
}

class _DzenEdgeCard extends StatelessWidget {
  const _DzenEdgeCard(
      {required this.child, this.padding = const EdgeInsets.all(10)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_R.mobileCardRadius),
        border: Border.all(color: _R.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000), blurRadius: 20, offset: Offset(0, 10))
        ],
      ),
      child: child,
    );
  }
}

class _DzenCardTitle extends StatelessWidget {
  const _DzenCardTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DzenIconBox(icon: icon, size: 34),
        const SizedBox(width: 7),
        Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.text,
                    fontSize: 14.8,
                    fontWeight: FontWeight.w900))),
      ],
    );
  }
}

class _DzenIconBox extends StatelessWidget {
  const _DzenIconBox({required this.icon, this.size = 42});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: _R.softGreen,
          borderRadius: BorderRadius.circular(size * .28),
          border: Border.all(color: _R.greenLine)),
      child: Icon(icon, color: _R.green, size: size * .42),
    );
  }
}

class _DzenPdfButton extends StatelessWidget {
  const _DzenPdfButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_R.mobileButtonRadius),
      child: Container(
        height: 48,
        constraints: const BoxConstraints(minWidth: 148, maxWidth: 206),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
            color: _R.green,
            borderRadius: BorderRadius.circular(_R.mobileButtonRadius),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1800A750),
                  blurRadius: 18,
                  offset: Offset(0, 8))
            ]),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 19),
            SizedBox(width: 8),
            Text('Выгрузить',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _DzenOutlineButton extends StatelessWidget {
  const _DzenOutlineButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _R.greenLine)),
        child: Text(label,
            style: const TextStyle(
                color: _R.greenDark,
                fontSize: 12.2,
                fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _DzenCircleButton extends StatelessWidget {
  const _DzenCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 18,
                  offset: Offset(0, 8))
            ]),
        child: Icon(icon, color: _R.graphite, size: 20),
      ),
    );
  }
}

class _DzenMetric {
  const _DzenMetric(this.icon, this.value, this.label);
  final IconData icon;
  final String value;
  final String label;
}

class _DzenMetricView extends StatelessWidget {
  const _DzenMetricView({required this.metric});
  final _DzenMetric metric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(metric.icon, color: _R.green, size: 19),
          const SizedBox(height: 5),
          Text(metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _R.text, fontSize: 12.8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 1),
          Text(metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _R.graphite,
                  fontSize: 9.3,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DzenPlayerPreview extends StatelessWidget {
  const _DzenPlayerPreview({required this.player});
  final TrackerTrainingPlayerRow player;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          _PlayerAvatar(player: player, size: 48),
          const SizedBox(height: 5),
          Text(_shortReportPlayerName(player.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _R.graphite,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DzenMiniPanel extends StatelessWidget {
  const _DzenMiniPanel({required this.title, required this.child, this.onTap});
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(_R.mobileButtonRadius),
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_R.mobileButtonRadius),
            border: Border.all(color: _R.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _R.text,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _DzenTeamSummaryPanel extends StatelessWidget {
  const _DzenTeamSummaryPanel({required this.report, this.onTap});
  final TrackerTrainingReport report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _DzenMiniPanel(
      title: 'Сводка команды',
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _DzenSmallKpi(
              icon: Icons.route_rounded,
              value: _mobileReportMeters(_mobileReportDistance(report)),
              label: 'Дистанция'),
          _DzenSmallKpi(
              icon: Icons.speed_rounded,
              value: _mobileReportSpeed(report),
              label: 'Макс. скорость'),
          _DzenSmallKpi(
              icon: Icons.favorite_rounded,
              value: _mobileReportHr(report),
              label: 'Ср. пульс'),
          _DzenSmallKpi(
              icon: Icons.timer_rounded,
              value: _mobileReportShortDuration(report.durationLabel),
              label: 'Длительность'),
        ],
      ),
    );
  }
}

class _DzenMapSummaryPanel extends StatelessWidget {
  const _DzenMapSummaryPanel({required this.report, this.onTap});
  final TrackerTrainingReport report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _DzenMiniPanel(
      title: 'Карта перемещений',
      onTap: onTap,
      child: Column(
        children: [
          Expanded(child: _MobileMapPreview(report: report)),
          const SizedBox(height: 7),
          Row(children: [
            const Text('Низкая',
                style: TextStyle(
                    color: _R.muted,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 7),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(colors: [
                    Color(0xFF00A750),
                    Color(0xFFF6D84B),
                    Color(0xFFFF7A1A),
                    Color(0xFFEF4444)
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Text('Высокая',
                style: TextStyle(
                    color: _R.muted,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w800)),
          ]),
        ],
      ),
    );
  }
}

class _DzenHrSummaryPanel extends StatelessWidget {
  const _DzenHrSummaryPanel({required this.report, this.onTap});
  final TrackerTrainingReport report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _DzenMiniPanel(
      title: 'Пульс команды',
      onTap: onTap,
      child: _DzenHrMiniChart(report: report),
    );
  }
}

class _DzenSmallKpi extends StatelessWidget {
  const _DzenSmallKpi(
      {required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: _R.green, size: 17),
      const SizedBox(width: 7),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _R.text, fontSize: 12.5, fontWeight: FontWeight.w900)),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _R.graphite,
                fontSize: 9.4,
                fontWeight: FontWeight.w700)),
      ])),
    ]);
  }
}

class _DzenPlainStat extends StatelessWidget {
  const _DzenPlainStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _R.text, fontSize: 13.2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _R.graphite, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _DzenSessionRow extends StatelessWidget {
  const _DzenSessionRow(
      {required this.sessionId,
      required this.subtitle,
      required this.selected,
      required this.onTap});
  final int sessionId;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? _R.softGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _R.greenLine : _R.border),
        ),
        child: Row(
          children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: selected ? _R.softGreen : _R.soft,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: selected ? _R.greenLine : _R.border)),
                child: Icon(Icons.assignment_rounded,
                    color: selected ? _R.green : _R.muted, size: 15)),
            const SizedBox(width: 7),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text('Сессия #$sessionId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _R.text,
                          fontSize: 12.4,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _R.graphite,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ])),
            Icon(Icons.chevron_right_rounded,
                color: selected ? _R.green : _R.muted, size: 24),
          ],
        ),
      ),
    );
  }
}

class _DzenHrMiniChart extends StatelessWidget {
  const _DzenHrMiniChart({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final points = _reportHrTimeline(report)
        .where((p) => p.bpm > 0)
        .toList(growable: false);
    if (points.isEmpty) {
      return const Center(
          child: Text('Нет HR-данных',
              style: TextStyle(
                  color: _R.muted,
                  fontSize: 10.4,
                  fontWeight: FontWeight.w500)));
    }
    return CustomPaint(
        painter: _DzenHrMiniPainter(points: points),
        child: const SizedBox.expand());
  }
}

class _DzenHrMiniPainter extends CustomPainter {
  const _DzenHrMiniPainter({required this.points});
  final List<TrackerHeartRatePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = _R.border
      ..strokeWidth = 1;
    final textPainter =
        TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
    const labels = [160, 120, 80, 40];
    final left = 28.0;
    final right = size.width - 4;
    final top = 10.0;
    final bottom = size.height - 20;
    for (final label in labels) {
      final y =
          bottom - ((label - 40) / 120.0).clamp(0.0, 1.0) * (bottom - top);
      canvas.drawLine(Offset(left, y), Offset(right, y), axis);
      textPainter.text = TextSpan(
          text: '$label',
          style: const TextStyle(
              color: _R.muted, fontSize: 8, fontWeight: FontWeight.w700));
      textPainter.layout();
      textPainter.paint(canvas, Offset(2, y - 5));
    }
    final sampled = _sampleHr(points, 80);
    if (sampled.length < 2) return;
    final minBpm =
        math.max(35, sampled.map((p) => p.bpm).reduce(math.min) - 8).toDouble();
    final maxBpm = math
        .max(minBpm + 25, sampled.map((p) => p.bpm).reduce(math.max) + 8)
        .toDouble();
    final path = Path();
    for (var i = 0; i < sampled.length; i++) {
      final x = left +
          (sampled.length == 1 ? 0 : i / (sampled.length - 1)) * (right - left);
      final y = bottom -
          ((sampled[i].bpm - minBpm) / (maxBpm - minBpm)).clamp(0.0, 1.0) *
              (bottom - top);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = _R.green
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
    textPainter.text = const TextSpan(
        text: 'мин',
        style: TextStyle(
            color: _R.muted, fontSize: 8, fontWeight: FontWeight.w800));
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(right - textPainter.width, size.height - 12));
  }

  @override
  bool shouldRepaint(covariant _DzenHrMiniPainter oldDelegate) =>
      oldDelegate.points != points;
}

List<TrackerHeartRatePoint> _sampleHr(
    List<TrackerHeartRatePoint> points, int maxCount) {
  if (points.length <= maxCount) return points;
  final step = (points.length / maxCount).ceil();
  final out = <TrackerHeartRatePoint>[];
  for (var i = 0; i < points.length; i += step) {
    out.add(points[i]);
  }
  if (out.last != points.last) out.add(points.last);
  return out;
}

String _mobileReportTeamName(TrackerTrainingReport report) {
  final team = report.teamName.trim();
  if (team.isNotEmpty) return team;
  return 'ФК «Гомель» U13';
}

String _mobileReportSessionLine(TrackerTrainingReport report) {
  final parts = <String>['Сессия #${report.sessionId}'];
  final date = _mobileReportDateOnly(report.dateLabel);
  if (date.isNotEmpty) parts.add(date);
  if (report.opponent.trim().isNotEmpty) parts.add(report.opponent.trim());
  return parts.join(' · ');
}

double _mobileReportDistance(TrackerTrainingReport report) {
  final s = report.summary;
  if (s.totalDistanceM > 0) return s.totalDistanceM;
  if (s.averageDistanceM > 0) return s.averageDistanceM;
  if (report.routePoints.isNotEmpty) {
    return report.routePoints
        .fold<double>(0, (a, p) => math.max(a, p.distanceM));
  }
  return 0;
}

String _mobileReportMeters(double value) {
  if (!value.isFinite || value <= 0) return '0 м';
  if (value >= 1000)
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 1 : 2)} км';
  return '${value.toStringAsFixed(0)} м';
}

String _mobileReportSpeed(TrackerTrainingReport report) {
  final speed = report.summary.maxSpeedKmh;
  return speed > 0 ? '${speed.toStringAsFixed(1)} км/ч' : '0 км/ч';
}

String _mobileReportHr(TrackerTrainingReport report) {
  final hr = report.summary.heartRateAvgBpm;
  return hr > 0 ? '${hr.toStringAsFixed(0)} уд/мин' : '—';
}

String _mobileReportShortDuration(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == '00:00:00') return '0 мин.';
  final parts = value.split(':');
  if (parts.length == 3) {
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final sec = int.tryParse(parts[2].split('.').first) ?? 0;
    final total = h * 60 + m + (sec >= 30 ? 1 : 0);
    return total > 0 ? '$total мин.' : '$sec сек.';
  }
  if (parts.length == 2) {
    final m = int.tryParse(parts[0]) ?? 0;
    final sec = int.tryParse(parts[1].split('.').first) ?? 0;
    final total = m + (sec >= 30 ? 1 : 0);
    return total > 0 ? '$total мин.' : '$sec сек.';
  }
  return value.length > 12 ? '${value.substring(0, 12)}…' : value;
}

String _mobileReportDateOnly(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length >= 10) return trimmed.substring(0, 10);
  return trimmed;
}

String _mobileReportTimeOnly(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'(\d{2}:\d{2})').firstMatch(trimmed);
  if (match != null) return match.group(1)!;
  return '';
}

String _mobileReportSessionRowSubtitle(TrackerTrainingReport report) {
  final date = _mobileReportDateOnly(report.dateLabel);
  final time = _mobileReportTimeOnly(report.dateLabel);
  final parts = <String>[];
  if (date.isNotEmpty) parts.add(date);
  if (time.isNotEmpty) parts.add(time);
  parts.add('${report.playersCount} игрока');
  parts.add(_mobileReportMeters(_mobileReportDistance(report)));
  return parts.join(' · ');
}

String _mobileReportPreviousRowSubtitle(
    TrackerTrainingReport report, int index) {
  final date = _mobileReportDateOnly(report.dateLabel);
  final player = report.playersCount > 0
      ? '${math.max(1, report.playersCount - index)} игрока'
      : 'игроки не выбраны';
  return [if (date.isNotEmpty) date, player, 'нажмите для отчёта'].join(' · ');
}

List<int> _mobileReportSessionIds(TrackerTrainingReport report) {
  final ids = <int>[];
  for (final id in report.sessionIds) {
    if (id > 0 && !ids.contains(id)) ids.add(id);
    if (ids.length >= 3) break;
  }
  if (report.sessionId > 0 && !ids.contains(report.sessionId))
    ids.insert(0, report.sessionId);
  var next = report.sessionId - 1;
  while (ids.length < 3 && next > 0) {
    if (!ids.contains(next)) ids.add(next);
    next--;
  }
  if (ids.isEmpty) ids.add(0);
  return ids.take(3).toList(growable: false);
}

class _MobileReportHeader extends StatelessWidget {
  const _MobileReportHeader({
    required this.report,
    required this.loading,
    required this.onBack,
    required this.onRefresh,
    required this.onPdf,
    required this.onExcel,
    required this.onPlayers,
    required this.selectedPlayersCount,
    required this.showBack,
  });

  final TrackerTrainingReport report;
  final bool loading;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onPdf;
  final VoidCallback onExcel;
  final VoidCallback onPlayers;
  final int selectedPlayersCount;

  @override
  Widget build(BuildContext context) {
    final title = report.title.trim().isNotEmpty
        ? report.title.trim()
        : 'Сессия #${report.sessionId}';
    final subtitle = [
      if (report.teamName.trim().isNotEmpty) report.teamName.trim(),
      if (report.dateLabel.trim().isNotEmpty) report.dateLabel.trim(),
      if (report.durationLabel.trim().isNotEmpty) report.durationLabel.trim(),
      '${report.playersCount} игрок(ов)',
    ].join(' · ');
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _R.border))),
      child: Row(children: [
        if (showBack) ...[
          _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 7),
        ],
        _TeamLogo(url: report.teamLogoUrl, title: report.teamName, size: 34),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ReportType.title(14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ]),
        ),
        if (loading)
          const SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(color: _R.green, strokeWidth: 2)),
        const SizedBox(width: 4),
        _MobilePlayerFilterButton(
            count: selectedPlayersCount, onTap: onPlayers),
        const SizedBox(width: 5),
        _NoHoverTap(
          onTap: () => _openActions(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 36,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _R.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _R.border),
            ),
            child: const Icon(Icons.menu_rounded,
                color: _R.graphite, size: 18),
          ),
        ),
      ]),
    );
  }

  Future<void> _openActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.34),
      builder: (sheetContext) {
        Widget tile({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback action,
          bool primary = false,
        }) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _NoHoverTap(
              onTap: () {
                Navigator.of(sheetContext).pop();
                Future<void>.microtask(action);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                decoration: BoxDecoration(
                  color: primary ? _R.softGreen : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primary ? _R.greenLine : _R.border,
                    width: .8,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primary ? Colors.white : _R.soft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        color: primary ? _R.green : _R.graphite, size: 20),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: _R.text,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _R.muted,
                                fontSize: 10.8,
                                height: 1.25,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: _R.muted, size: 20),
                ]),
              ),
            ),
          );
        }

        return FractionallySizedBox(
          heightFactor: .92,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Material(
                color: _R.bg,
                child: SafeArea(
                  top: false,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      child: Row(children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _R.softGreen,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _R.greenLine),
                          ),
                          child: const Icon(Icons.assignment_rounded,
                              color: _R.green, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Управление отчётом',
                                  style: TextStyle(
                                      color: _R.text,
                                      fontSize: 15.2,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                selectedPlayersCount > 0
                                    ? 'Выбрано игроков: $selectedPlayersCount'
                                    : 'Сейчас показана вся команда',
                                style: const TextStyle(
                                    color: _R.muted,
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        _RoundIconButton(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.of(sheetContext).pop(),
                        ),
                      ]),
                    ),
                    const Divider(height: 1, color: _R.border),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                        children: [
                          tile(
                            icon: Icons.groups_rounded,
                            title: selectedPlayersCount > 0
                                ? 'Игроки · выбрано $selectedPlayersCount'
                                : 'Игроки · вся команда',
                            subtitle:
                                'Выберите одного, нескольких игроков или верните общий командный отчёт.',
                            action: onPlayers,
                            primary: true,
                          ),
                          tile(
                            icon: Icons.picture_as_pdf_rounded,
                            title: 'PDF и печать',
                            subtitle:
                                'Откройте готовую версию для просмотра, сохранения или печати.',
                            action: onPdf,
                          ),
                          tile(
                            icon: Icons.table_chart_rounded,
                            title: 'Excel / CSV',
                            subtitle:
                                'Выгрузите показатели игроков для таблиц и дальнейшего анализа.',
                            action: onExcel,
                          ),
                          tile(
                            icon: Icons.refresh_rounded,
                            title: 'Обновить данные',
                            subtitle:
                                'Повторно загрузите GPS, данные кардиодатчика и рассчитанные показатели сессии.',
                            action: onRefresh,
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobilePlayerFilterButton extends StatelessWidget {
  const _MobilePlayerFilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Material(
      color: active ? _R.softGreen : _R.soft,
      borderRadius: BorderRadius.circular(13),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: active ? _R.greenLine : _R.border),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.groups_rounded,
                  color: active ? _R.green : _R.graphite, size: 17),
              if (active)
                Positioned(
                  right: -7,
                  top: -7,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: _R.green,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 1.2)),
                    child: Text('$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportPlayerFilterStrip extends StatelessWidget {
  const _ReportPlayerFilterStrip({
    required this.players,
    required this.selectedKeys,
    required this.keyForPlayer,
    required this.onToggle,
    required this.onAll,
    required this.onOpenFull,
  });

  final List<TrackerTrainingPlayerRow> players;
  final Set<int> selectedKeys;
  final int Function(TrackerTrainingPlayerRow player, int index) keyForPlayer;
  final void Function(int key, List<int> allKeys) onToggle;
  final VoidCallback onAll;
  final VoidCallback onOpenFull;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();
    final keys = <int>[
      for (var i = 0; i < players.length; i++) keyForPlayer(players[i], i)
    ];
    return Container(
      height: 58,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ReportPlayerQuickChip(
            label: 'Все игроки',
            note: '${players.length} в отчёте',
            active: selectedKeys.isEmpty,
            leading:
                const Icon(Icons.groups_rounded, color: _R.green, size: 15),
            onTap: onAll,
          ),
          const SizedBox(width: 5),
          for (var i = 0; i < math.min(players.length, 3); i++) ...[
            _ReportPlayerQuickChip(
              label: players[i].name,
              note:
                  '${players[i].distanceM.toStringAsFixed(0)} м · HR ${players[i].heartRateSamplesCount}',
              active: selectedKeys.contains(keys[i]),
              leading: _PlayerAvatar(player: players[i], size: 20),
              onTap: () => onToggle(keys[i], keys),
            ),
            const SizedBox(width: 7),
          ],
          _ReportPlayerQuickChip(
            label: 'Расширенный выбор',
            note: 'поиск / отметить несколько',
            active: selectedKeys.isNotEmpty,
            leading:
                const Icon(Icons.tune_rounded, color: _R.graphite, size: 15),
            onTap: onOpenFull,
          ),
        ],
      ),
    );
  }
}

class _ReportPlayerQuickChip extends StatelessWidget {
  const _ReportPlayerQuickChip(
      {required this.label,
      required this.note,
      required this.active,
      required this.leading,
      required this.onTap});
  final String label;
  final String note;
  final bool active;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
            color: active ? _R.softGreen : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? _R.greenLine : _R.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          leading,
          const SizedBox(width: 4),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: active ? _R.greenDark : _R.text,
                            fontSize: 11.2,
                            fontWeight: FontWeight.w900))),
                const SizedBox(height: 2),
                ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _R.muted,
                            fontSize: 9.2,
                            fontWeight: FontWeight.w700))),
              ]),
        ]),
      ),
    );
  }
}

class _MobileReportTabs extends StatelessWidget {
  const _MobileReportTabs({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  static const icons = [
    Icons.dashboard_rounded,
    Icons.groups_rounded,
    Icons.insert_chart_rounded
  ];
  static const labels = ['Обзор', 'Игроки', 'Графики'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      color: Colors.white,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
              child: _MobileTabButton(
                  icon: icons[i],
                  label: labels[i],
                  active: selected == i,
                  onTap: () => onSelect(i))),
          if (i != labels.length - 1) const SizedBox(width: 7),
        ],
      ]),
    );
  }
}

class _MobileTabButton extends StatelessWidget {
  const _MobileTabButton(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _R.softGreen : _R.soft,
      borderRadius: BorderRadius.circular(14),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: active ? _R.greenLine : _R.border)),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: active ? _R.green : _R.graphite),
                const SizedBox(width: 5),
                Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: active ? _R.greenDark : _R.graphite,
                            fontSize: 14.0,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w600))),
              ]),
        ),
      ),
    );
  }
}

class _MobileReportOverview extends StatelessWidget {
  const _MobileReportOverview(
      {required this.report, required this.onOpenDetail});
  final TrackerTrainingReport report;
  final void Function(String title, Widget child) onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final hasData = _hasMeaningfulTrainingData(report);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _MobileHeroCard(report: report),
        const SizedBox(height: 8),
        if (!hasData) ...[
          _NoMovementNotice(report: report),
          const SizedBox(height: 8),
        ],
        _MobileCoachCard(report: report),
        const SizedBox(height: 8),
        _MobilePreviewCard(
          title: 'Карта активности',
          subtitle: 'маршрут, тепловая карта и спринты',
          icon: Icons.map_rounded,
          previewHeight: 190,
          preview: _MobileMapPreview(report: report),
          onOpen: () => onOpenDetail('Карта активности / тепловая карта',
              _ActivityMapPanel(report: report)),
        ),
        const SizedBox(height: 8),
        _MobilePreviewCard(
          title: 'Скорость и зоны',
          subtitle: 'линия скорости, HIR и спринты',
          icon: Icons.speed_rounded,
          previewHeight: 168,
          preview: _MobileSpeedPreview(report: report),
          onOpen: () => onOpenDetail(
              'График скорости и зоны',
              SizedBox(
                  height: 560, child: _ReportSpeedGraphPanel(report: report))),
        ),
        const SizedBox(height: 8),
        _MobilePreviewCard(
          title: 'Внутренняя нагрузка',
          subtitle: 'ЧСС, зоны и нагрузка игрока',
          icon: Icons.favorite_rounded,
          previewHeight: 190,
          preview: _HrPlayerSummaryChart(players: _reportPlayers(report)),
          onOpen: () => onOpenDetail('Пульс и внутренняя нагрузка',
              _MobileInternalLoadDetails(report: report)),
        ),
        const SizedBox(height: 8),
        _MobilePreviewCard(
          title: 'Лидеры по объёму',
          subtitle: 'быстрое сравнение игроков',
          icon: Icons.leaderboard_rounded,
          previewHeight: 190,
          preview: _MobileTopPlayersBars(report: report),
          onOpen: () => onOpenDetail(
              'Игроки и локомоторика', _MobilePlayersDetails(report: report)),
        ),
      ]),
    );
  }
}

class _MobileReportPlayers extends StatelessWidget {
  const _MobileReportPlayers(
      {required this.report, required this.onOpenDetail});
  final TrackerTrainingReport report;
  final void Function(String title, Widget child) onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _MobileSectionHeader(
          title: 'Игроки в отчёте',
          subtitle: players.isEmpty
              ? 'нет игроков'
              : '${players.length} игрок(ов) · карточки без широкой таблицы',
          actionLabel: 'Таблица',
          onAction: () => onOpenDetail(
              'Полная таблица игроков', _MobilePlayersDetails(report: report)),
        ),
        const SizedBox(height: 8),
        if (players.isEmpty)
          const _EmptyBlock('В отчёте пока нет игроков.')
        else
          for (var i = 0; i < players.length; i++) ...[
            _PlayerReportCompactCard(player: players[i]),
            if (i != players.length - 1) const SizedBox(height: 8),
          ],
      ]),
    );
  }
}

class _MobileReportCharts extends StatelessWidget {
  const _MobileReportCharts({required this.report, required this.onOpenDetail});
  final TrackerTrainingReport report;
  final void Function(String title, Widget child) onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _MobileSectionHeader(
            title: 'Графики тренировки',
            subtitle: 'нажмите карточку, чтобы открыть большое окно'),
        const SizedBox(height: 8),
        _MobilePreviewCard(
          title: 'Средний / максимальный пульс',
          subtitle: 'зелёная точка — средний bpm, красная — максимум',
          icon: Icons.favorite_rounded,
          previewHeight: 210,
          preview: _HrPlayerSummaryChart(players: _reportPlayers(report)),
          onOpen: () => onOpenDetail(
              'Средний / максимальный пульс',
              SizedBox(
                  height: 430,
                  child:
                      _HrPlayerSummaryChart(players: _reportPlayers(report)))),
        ),
        const SizedBox(height: 8),
        _MobilePreviewCard(
          title: 'Пульс по времени',
          subtitle: 'красная линия и зоны ЧСС',
          icon: Icons.monitor_heart_rounded,
          previewHeight: 210,
          preview: _HeartRateTimelineChart(report: report),
          onOpen: () => onOpenDetail(
              'Пульс по времени / красная нагрузка',
              SizedBox(
                  height: 460, child: _HeartRateTimelineChart(report: report))),
        ),
        const SizedBox(height: 8),
        _MobilePreviewCard(
          title: 'Ускорения / торможения',
          subtitle: 'механика игрока',
          icon: Icons.compare_arrows_rounded,
          previewHeight: 220,
          preview: _DualBarChart(
              players: _reportPlayers(report),
              first: (p) => p.accelerations.toDouble(),
              second: (p) => p.decelerations.toDouble(),
              firstLabel: 'Ускорения',
              secondLabel: 'Торможения'),
          onOpen: () => onOpenDetail(
              'Механика: ускорения и торможения',
              SizedBox(
                  height: 430,
                  child: _DualBarChart(
                      players: _reportPlayers(report),
                      first: (p) => p.accelerations.toDouble(),
                      second: (p) => p.decelerations.toDouble(),
                      firstLabel: 'Ускорения',
                      secondLabel: 'Торможения'))),
        ),
        const SizedBox(height: 8),
        _MobilePreviewCard(
          title: 'Микроцикл',
          subtitle: 'динамика дистанции и интенсивности',
          icon: Icons.calendar_month_rounded,
          previewHeight: 230,
          preview: _MicrocycleChart(points: report.microcycle),
          onOpen: () => onOpenDetail(
              'Динамика микроцикла',
              SizedBox(
                  height: 460,
                  child: _MicrocycleChart(points: report.microcycle))),
        ),
      ]),
    );
  }
}

class _MobileHeroCard extends StatelessWidget {
  const _MobileHeroCard({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final metrics = _mobileCoreMetrics(report);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_R.mobileCardRadius),
          border: Border.all(color: _R.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x07000000), blurRadius: 18, offset: Offset(0, 8))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _TeamLogo(url: report.teamLogoUrl, title: report.teamName, size: 46),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Сессия #${report.sessionId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                    [report.teamName, report.dateLabel, report.durationLabel]
                        .where((v) => v.trim().isNotEmpty)
                        .join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.muted,
                        fontSize: 11.2,
                        height: 1.2,
                        fontWeight: FontWeight.w800)),
              ])),
          _ReportStatusPill(report: report),
        ]),
        const SizedBox(height: 8),
        _MobileKpiGrid(metrics: metrics),
      ]),
    );
  }
}

class _MobileKpiGrid extends StatelessWidget {
  const _MobileKpiGrid({required this.metrics});
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 66,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, i) => _MetricTile(metric: metrics[i]),
    );
  }
}

class _MobileCoachCard extends StatelessWidget {
  const _MobileCoachCard({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final messages =
        _reportCoachMessages(report).take(2).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_R.tabletCardRadius),
          border: Border.all(color: _R.greenLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.tips_and_updates_rounded, color: _R.green, size: 15),
          SizedBox(width: 8),
          Text('Итог тренера',
              style: TextStyle(
                  color: _R.text, fontSize: 11.8, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        for (final message in messages) ...[
          Text(message,
              style: const TextStyle(
                  color: _R.graphite,
                  fontSize: 11.2,
                  height: 1.32,
                  fontWeight: FontWeight.w700)),
          if (message != messages.last) const SizedBox(height: 6),
        ],
      ]),
    );
  }
}

class _MobilePreviewCard extends StatelessWidget {
  const _MobilePreviewCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.preview,
      required this.previewHeight,
      required this.onOpen});
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget preview;
  final double previewHeight;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_R.mobileCardRadius),
      child: _NoHoverTap(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(_R.mobileCardRadius),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_R.mobileCardRadius),
              border: Border.all(color: _R.border),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 14,
                    offset: Offset(0, 7))
              ]),
          clipBehavior: Clip.antiAlias,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(children: [
                Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: _R.softGreen,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _R.greenLine)),
                    child: Icon(icon, color: _R.green, size: 15)),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _R.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _R.muted,
                              fontSize: 9.8,
                              fontWeight: FontWeight.w800)),
                    ])),
                const SizedBox(width: 6),
                Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: _R.soft,
                        borderRadius:
                            BorderRadius.circular(_R.mobileInnerRadius),
                        border: Border.all(color: _R.border)),
                    child: const Icon(Icons.open_in_full_rounded,
                        color: _R.graphite, size: 16)),
              ]),
            ),
            SizedBox(
                height: previewHeight,
                child:
                    Padding(padding: const EdgeInsets.all(8), child: preview)),
          ]),
        ),
      ),
    );
  }
}

class _MobileMapPreview extends StatelessWidget {
  const _MobileMapPreview({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final points = report.heatmapPoints.isNotEmpty
        ? report.heatmapPoints
        : report.routePoints;
    return Center(
      child: AspectRatio(
        aspectRatio: 1.72,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CustomPaint(
            painter: _ReportPitchPainter(
                points: points,
                heatMode: report.heatmapPoints.isNotEmpty,
                hsrKmh: _reportHsrThreshold(report),
                sprintKmh: _reportSprintThreshold(report)),
            child: points.isEmpty
                ? const Center(
                    child: Text('Нет GPS-точек',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900)))
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _MobileSpeedPreview extends StatelessWidget {
  const _MobileSpeedPreview({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final samples = report.routePoints
        .map((p) => p.speedKmh)
        .where((v) => v.isFinite && v >= 0)
        .toList();
    final maxSpeed = samples.isEmpty
        ? report.summary.maxSpeedKmh
        : samples.fold<double>(report.summary.maxSpeedKmh, math.max);
    if (samples.isEmpty && maxSpeed <= 0)
      return const _EmptyBlock('Скорость появится после GPS-точек.');
    return CustomPaint(
      painter: _ReportSpeedPainter(
          samples: samples,
          maxSpeedKmh: maxSpeed,
          durationMs: _reportTimelineDurationMs(report),
          hsrKmh: _reportHsrThreshold(report),
          sprintKmh: _reportSprintThreshold(report)),
      child: const SizedBox.expand(),
    );
  }
}

class _MobileTopPlayersBars extends StatelessWidget {
  const _MobileTopPlayersBars({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report)
        .where((p) =>
            p.distanceM > 0 || p.playerLoad > 0 || p.heartRateSamplesCount > 0)
        .take(8)
        .toList(growable: false);
    if (players.isEmpty)
      return const _EmptyBlock('Нет данных игроков для сравнения.');
    return CustomPaint(
      painter: _BarChartPainter(
          players: players,
          value: (p) => math.max(p.distanceM, p.playerLoad),
          label: 'объём'),
      child: const SizedBox.expand(),
    );
  }
}

class _MobileSectionHeader extends StatelessWidget {
  const _MobileSectionHeader(
      {required this.title,
      required this.subtitle,
      this.actionLabel,
      this.onAction});
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: _R.text, fontSize: 13.2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(
                color: _R.muted, fontSize: 10.4, fontWeight: FontWeight.w800)),
      ])),
      if (actionLabel != null && onAction != null)
        TextButton(
            onPressed: onAction,
            child: Text(actionLabel!,
                style: const TextStyle(
                    color: _R.greenDark, fontWeight: FontWeight.w900))),
    ]);
  }
}

class _MobileInternalLoadDetails extends StatelessWidget {
  const _MobileInternalLoadDetails({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(
          title: 'РЕКОМЕНДАЦИИ ПО ЧСС',
          child: _HrRecommendations(report: report)),
      const SizedBox(height: 8),
      _Card(
          title: 'ПУЛЬС ПО ВРЕМЕНИ',
          child: SizedBox(
              height: 420, child: _HeartRateTimelineChart(report: report))),
      const SizedBox(height: 8),
      _Card(
          title: 'ЗОНЫ ЧСС',
          child:
              SizedBox(height: 126, child: _HrZoneTimeStrip(report: report))),
      const SizedBox(height: 8),
      _Card(
          title: 'СРЕДНИЙ / МАКСИМАЛЬНЫЙ ПУЛЬС',
          child: SizedBox(
              height: 360,
              child: _HrPlayerSummaryChart(players: _reportPlayers(report)))),
    ]);
  }
}

class _MobilePlayersDetails extends StatelessWidget {
  const _MobilePlayersDetails({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(title: 'ИГРОКИ И ТРЕКЕРЫ', child: _PlayersOverview(report: report)),
      const SizedBox(height: 8),
      _Card(
          title: 'ЛОКОМОТОРИКА ПО ИГРОКАМ',
          child: _LocomotorCards(players: players)),
    ]);
  }
}

List<_Metric> _mobileCoreMetrics(TrackerTrainingReport report) {
  final s = report.summary;
  return [
    _Metric(
        'Время',
        report.durationLabel.trim().isEmpty ? '—' : report.durationLabel,
        'длительность'),
    _Metric(
        'Дистанция', '${s.averageDistanceM.toStringAsFixed(0)} м', 'средняя'),
    _Metric('Макс. скорость',
        s.maxSpeedKmh > 0 ? s.maxSpeedKmh.toStringAsFixed(1) : '—', 'км/ч'),
    _Metric('Игроки', '${report.playersCount}', 'в отчёте'),
    _Metric(
        'Пульс',
        s.heartRateAvgBpm > 0 ? s.heartRateAvgBpm.toStringAsFixed(0) : '—',
        'средний bpm'),
  ];
}

class _Header extends StatelessWidget {
  const _Header({
    required this.report,
    required this.loading,
    required this.onBack,
    required this.onRefresh,
    required this.onPdf,
    required this.onExcel,
    required this.onPlayers,
    required this.onSettings,
    this.selectedPlayersCount = 0,
    this.showBack = true,
  });

  final TrackerTrainingReport report;
  final bool loading;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onPdf;
  final VoidCallback onExcel;
  final VoidCallback onPlayers;
  final VoidCallback onSettings;
  final int selectedPlayersCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 980;
      final hideLabels = c.maxWidth < 760;
      final subtitle = [
        report.teamName.trim().isEmpty ? 'команда не указана' : report.teamName,
        report.dateLabel.trim().isEmpty ? 'дата не указана' : report.dateLabel,
        report.durationLabel,
        '${report.playersCount} игрок(ов)',
        'GPS + кардиодатчик',
      ].where((e) => e.trim().isNotEmpty).join(' · ');
      return Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _R.border)),
        ),
        child: Row(
          children: [
            if (showBack) ...[
              _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
              const SizedBox(width: 7),
            ],
            _TeamLogo(
                url: report.teamLogoUrl,
                title: report.teamName,
                size: compact ? 28 : 32),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Отчёты',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _R.text,
                        fontSize: compact ? 15.0 : 16.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _R.muted,
                        fontSize: compact ? 11.0 : 11.5,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: _R.green, strokeWidth: 2)),
              ),
            if (!compact)
              _HeaderButton(
                  icon: Icons.refresh_rounded,
                  label: 'Обновить',
                  onTap: onRefresh),
            if (!compact) const SizedBox(width: 7),
            _HeaderButton(
                icon: Icons.tune_rounded,
                label: hideLabels ? 'Выбор' : 'Выбор отчёта',
                onTap: onSettings),
            const SizedBox(width: 7),
            _HeaderButton(
                icon: Icons.picture_as_pdf_rounded,
                label: hideLabels ? 'PDF' : 'PDF / печать',
                onTap: onPdf),
            const SizedBox(width: 7),
            _HeaderButton(
                icon: Icons.table_chart_rounded,
                label: hideLabels ? 'XLS' : 'Excel',
                onTap: onExcel),
          ],
        ),
      );
    });
  }
}

String _absoluteReportImageUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('data:') || value.startsWith('blob:')) return value;
  final parsed = Uri.tryParse(value);
  if (parsed != null && parsed.hasScheme) return value;
  final normalized = value.startsWith('/') ? value : '/$value';
  return 'https://sportotekaapp.ru$normalized';
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.url, required this.title, this.size = 46});
  final String url;
  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = title.trim().isNotEmpty
        ? title.trim().substring(0, 1).toUpperCase()
        : 'S';
    final imageUrl = _absoluteReportImageUrl(url);
    final child = imageUrl.isEmpty
        ? Text(letter,
            style: TextStyle(
                color: _R.greenDark,
                fontWeight: FontWeight.w900,
                fontSize: size * .42))
        : ClipRRect(
            borderRadius: BorderRadius.circular(size * .26),
            child: Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                  child: Text(letter,
                      style: TextStyle(
                          color: _R.greenDark,
                          fontWeight: FontWeight.w900,
                          fontSize: size * .42))),
            ),
          );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: _R.softGreen,
          borderRadius: BorderRadius.circular(size * .28),
          border: Border.all(color: _R.greenLine)),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: Colors.transparent, width: .8),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: _R.graphite, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _R.graphite,
                fontWeight: FontWeight.w600,
                fontSize: 11.4,
              ),
            ),
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

  static const items = [
    'Сводка',
    'Локомоторика',
    'Механика',
    'Пульс',
    'Микроцикл',
    'ИИ анализ'
  ];
  static const icons = [
    Icons.dashboard_rounded,
    Icons.directions_run_rounded,
    Icons.compare_arrows_rounded,
    Icons.favorite_rounded,
    Icons.calendar_month_rounded,
    Icons.auto_awesome_rounded
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final active = i == selected;
          return _NoHoverTap(
            onTap: () => onSelect(i),
            borderRadius: BorderRadius.circular(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? _R.softGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: active ? _R.greenLine : Colors.transparent,
                  width: .8,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icons[i],
                    color: active ? _R.green : _R.graphite, size: 15),
                const SizedBox(width: 6),
                Text(
                  items[i],
                  style: TextStyle(
                    color: active ? _R.greenDark : _R.graphite,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 11.4,
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: _R.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _ReportModalLivePreview extends StatelessWidget {
  const _ReportModalLivePreview({required this.report, required this.sections});

  final TrackerTrainingReport report;
  final Set<String> sections;

  bool _show(String id) => sections.isEmpty || sections.contains(id);

  @override
  Widget build(BuildContext context) {
    final summary = report.summary;
    final players = _reportPlayers(report);
    final withHr = players
        .where((p) => p.heartRateSamplesCount > 0 || p.heartRateAvgBpm > 0)
        .length;

    Widget metric(IconData icon, String label, String value, String note) {
      return Container(
        width: 142,
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _R.softGreen, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: _R.greenDark, size: 15),
          ),
          const SizedBox(width: 7),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.muted,
                        fontSize: 9.0,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.text,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w600)),
                Text(note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.muted,
                        fontSize: 8.2,
                        fontWeight: FontWeight.w500)),
              ])),
        ]),
      );
    }

    Widget sectionCard(
        {required String title,
        required IconData icon,
        required Widget child}) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [
            BoxShadow(
                color: Color(0x07111827), blurRadius: 14, offset: Offset(0, 3)),
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: _R.softGreen, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: _R.green),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.text,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          child,
        ]),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final gap = 8.0;
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _ReportBrandStrip(report: report),
          const SizedBox(height: 8),
          if (_show('summary'))
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                metric(
                    Icons.route_rounded,
                    'Дистанция',
                    '${summary.totalDistanceM.toStringAsFixed(0)} м',
                    'общий объём'),
                metric(Icons.groups_rounded, 'Игроки', '${report.playersCount}',
                    'в отчёте'),
                metric(
                    Icons.speed_rounded,
                    'Макс. скорость',
                    '${summary.maxSpeedKmh.toStringAsFixed(1)} км/ч',
                    'пиковое значение'),
                metric(
                    Icons.favorite_rounded,
                    'Пульс',
                    '${summary.heartRateAvgBpm.toStringAsFixed(0)} уд/мин',
                    '$withHr с ЧСС'),
                metric(Icons.bolt_rounded, 'Спринты', '${summary.sprintCount}',
                    'за сессию'),
                metric(Icons.monitor_heart_rounded, 'Нагрузка',
                    summary.playerLoad.toStringAsFixed(0), 'нагрузка'),
              ],
            ),
          if (_show('summary')) const SizedBox(height: 8),
          if (_show('maps'))
            sectionCard(
              title: 'Карта активности и тепловая карта',
              icon: Icons.map_rounded,
              child: _ActivityMapPanel(report: report, expandedTablet: false),
            ),
          if (_show('maps')) SizedBox(height: gap),
          if (_show('events'))
            sectionCard(
              title: 'Журнал событий',
              icon: Icons.view_timeline_rounded,
              child: _ReportEventsPanel(report: report),
            ),
          if (_show('events')) SizedBox(height: gap),
          if (wide && (_show('speed') || _show('internal')))
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_show('speed'))
                Expanded(
                    child: sectionCard(
                  title: 'Скорость и зоны',
                  icon: Icons.speed_rounded,
                  child: _ReportSpeedGraphPanel(
                      report: report, constrainedHeight: true),
                )),
              if (_show('speed') && _show('internal')) SizedBox(width: gap),
              if (_show('internal'))
                Expanded(
                    child: sectionCard(
                        title: 'Пульс и нагрузка',
                        icon: Icons.favorite_rounded,
                        child: SizedBox(
                            height: 300,
                            child: _HrZoneSummaryBars(players: players)))),
            ])
          else ...[
            if (_show('speed'))
              sectionCard(
                title: 'Скорость и зоны',
                icon: Icons.speed_rounded,
                child: _ReportSpeedGraphPanel(
                    report: report, constrainedHeight: true),
              ),
            if (_show('speed') && _show('internal')) SizedBox(height: gap),
            if (_show('internal'))
              sectionCard(
                  title: 'Пульс и нагрузка',
                  icon: Icons.favorite_rounded,
                  child: SizedBox(
                      height: 210,
                      child: _HrZoneSummaryBars(players: players))),
          ],
          if (_show('speed') || _show('internal')) SizedBox(height: gap),
          if (_show('players'))
            sectionCard(
                title: 'Команда · игроки и показатели',
                icon: Icons.groups_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 6),
                      child: _PlayersOverview(report: report),
                    ),
                    const SizedBox(height: 8),
                    _PerformanceMatrix(players: players),
                  ],
                )),
          if (_show('players')) SizedBox(height: gap),
          if (_show('rating'))
            sectionCard(
                title: 'Рейтинг и сравнение игроков',
                icon: Icons.leaderboard_rounded,
                child: SizedBox(
                    height: 410,
                    child: _RadarComparisonPanel(report: report))),
          if (_show('rating')) SizedBox(height: gap),
          if (_show('locomotor'))
            sectionCard(
                title: 'Локомоторика',
                icon: Icons.directions_run_rounded,
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _LocomotorCards(players: players))),
          if (_show('locomotor')) SizedBox(height: gap),
          if (_show('mechanics'))
            sectionCard(
                title: 'Механика',
                icon: Icons.compare_arrows_rounded,
                child: SizedBox(
                    height: 260,
                    child: _DualBarChart(
                        players: players,
                        first: (p) => p.accelerations.toDouble(),
                        second: (p) => p.decelerations.toDouble(),
                        firstLabel: 'Ускорения',
                        secondLabel: 'Торможения'))),
          if (_show('mechanics')) SizedBox(height: gap),
          if (_show('microcycle'))
            sectionCard(
                title: 'Микроцикл',
                icon: Icons.calendar_view_week_rounded,
                child: SizedBox(
                    height: 210,
                    child: _MicrocycleChart(points: report.microcycle))),
          if (_show('microcycle')) SizedBox(height: gap),
          if (_show('periods'))
            sectionCard(
                title: 'Периоды / упражнения',
                icon: Icons.segment_rounded,
                child: _PeriodsTable(periods: report.periods)),
          if (_show('periods')) SizedBox(height: gap),
          if (_show('player_pages'))
            sectionCard(
                title: 'Индивидуальные листы игроков',
                icon: Icons.badge_rounded,
                child: _PlayerDeepDiveCards(report: report)),
          if (_show('player_pages')) SizedBox(height: gap),
          if (_show('ai'))
            sectionCard(
                title: 'ИИ-анализ',
                icon: Icons.auto_awesome_rounded,
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                    child:
                        _ReportAiPlaceholder(report: report, compact: false))),
          const SizedBox(height: 4),
        ]),
      );
    });
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.report, this.sections});
  final TrackerTrainingReport report;
  final Set<String>? sections;

  bool _show(String id) =>
      sections == null || sections!.isEmpty || sections!.contains(id);

  @override
  Widget build(BuildContext context) {
    return _ScrollPage(
      children: [
        _ReportBrandStrip(report: report),
        const SizedBox(height: 6),
        _SectionTitle('ПОЛНЫЙ ОТЧЁТ ПО ТРЕНИРОВКЕ'),
        LayoutBuilder(builder: (context, c) {
          final desktop = c.maxWidth >= 1180;
          final tablet = c.maxWidth >= 540 && c.maxWidth < 1180;
          final twoColumns = desktop;
          final gap = tablet || desktop ? 8.0 : 8.0;
          final hasData = _hasMeaningfulTrainingData(report);
          final mapCard = _Card(
              title: 'КАРТА АКТИВНОСТИ / ТЕПЛОВАЯ КАРТА',
              child: _ActivityMapPanel(report: report, expandedTablet: tablet));
          final left =
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_show('summary'))
              _Card(
                  title: 'ОБЩАЯ ИНФОРМАЦИЯ',
                  child: _SummaryGrid(report: report)),
            SizedBox(height: gap),
            if (!hasData) ...[
              _NoMovementNotice(report: report),
              SizedBox(height: gap),
            ],
            if (_show('players'))
              _Card(
                  title: 'ИГРОКИ И ТРЕКЕРЫ',
                  child: _PlayersOverview(report: report)),
            SizedBox(height: gap),
            if (_show('players'))
              _Card(
                  title: 'SPORTOTEKA PERFORMANCE MATRIX',
                  child: _PerformanceMatrix(players: _reportPlayers(report))),
            SizedBox(height: gap),
            if (_show('player_pages'))
              _Card(
                  title: 'ПО КАЖДОМУ ИГРОКУ: КАРТА + ГРАФИК ПО ВРЕМЕНИ',
                  child: _PlayerDeepDiveCards(report: report)),
            SizedBox(height: gap),
            if (_show('locomotor'))
              _Card(
                  title: 'ЛОКОМОТОРНЫЙ ПРОФИЛЬ ИГРОКОВ',
                  child: _LocomotorCards(players: _reportPlayers(report))),
            SizedBox(height: gap),
            if (_show('periods'))
              _Card(
                  title: 'ПЕРИОДЫ / УПРАЖНЕНИЯ',
                  child: _PeriodsTable(periods: report.periods)),
          ]);
          final right =
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_show('speed'))
              _Card(
                  title: 'ГРАФИК СКОРОСТИ',
                  child: SizedBox(
                      height: desktop ? 370 : 320,
                      child: _ReportSpeedGraphPanel(report: report))),
            SizedBox(height: gap),
            if (!tablet) ...[
              if (_show('maps')) mapCard,
              if (_show('events')) ...[
                SizedBox(height: gap),
                _Card(
                    title: 'ЖУРНАЛ СОБЫТИЙ',
                    child: _ReportEventsPanel(report: report)),
              ],
              SizedBox(height: gap),
            ],
            if (_show('rating'))
              _Card(
                  title: 'РЕЙТИНГ И СРАВНЕНИЕ ИГРОКА',
                  child: SizedBox(
                      height: desktop ? 470 : 420,
                      child: _RadarComparisonPanel(report: report))),
            if (_show('rating')) SizedBox(height: gap),
            if (_show('mechanics'))
              _Card(
                  title: 'МЕХАНИКА: УСКОРЕНИЯ И ТОРМОЖЕНИЯ',
                  child: SizedBox(
                      height: desktop ? 280 : 240,
                      child: _DualBarChart(
                          players: _reportPlayers(report),
                          first: (p) => p.accelerations.toDouble(),
                          second: (p) => p.decelerations.toDouble(),
                          firstLabel: 'Ускорения',
                          secondLabel: 'Торможения'))),
            SizedBox(height: gap),
            if (_show('microcycle'))
              _Card(
                  title: 'ДИНАМИКА МИКРОЦИКЛА',
                  child: SizedBox(
                      height: desktop ? 260 : 230,
                      child: _MicrocycleChart(points: report.microcycle))),
            SizedBox(height: gap),
            if (_show('ai'))
              _Card(
                  title: 'ИИ АНАЛИЗ',
                  child: _ReportAiPlaceholder(report: report, compact: true)),
            SizedBox(height: gap),
            if (_show('rating'))
              _Card(
                  title: '% ОТ СРЕДНИХ ЗНАЧЕНИЙ МАТЧА',
                  child: SizedBox(
                      height: desktop ? 250 : 300,
                      child: _PercentBarChart(values: _mdComparison(report)))),
          ]);
          if (tablet) {
            final screenH = MediaQuery.maybeOf(context)?.size.height ?? 760.0;
            final tabletHeight =
                math.max(430.0, math.min(620.0, screenH - 118.0));
            final tabletMap = _Card(
              title: 'КАРТА / ТЕПЛОВАЯ КАРТА',
              child: _ActivityMapPanel(report: report, expandedTablet: true),
            );
            final tabletReportBlocks = _Card(
              title: 'БЛОКИ ОТЧЁТА',
              child: _TabletReportQuickBlocks(report: report),
            );
            return SizedBox(
              height: tabletHeight,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 6, child: tabletMap),
                    SizedBox(width: gap),
                    Expanded(flex: 5, child: tabletReportBlocks),
                  ]),
            );
          }
          if (!twoColumns) {
            return Column(children: [left, SizedBox(height: gap), right]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: desktop ? 6 : 1, child: left),
            SizedBox(width: gap),
            Expanded(flex: desktop ? 7 : 1, child: right),
          ]);
        }),
      ],
    );
  }
}

class _TabletReportQuickBlocks extends StatelessWidget {
  const _TabletReportQuickBlocks({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final s = report.summary;
    final players = _reportPlayers(report);
    final withHr = players.where((p) => p.heartRateSamplesCount > 0).length;
    final metrics = <_Metric>[
      _Metric(
          'Дистанция', '${s.averageDistanceM.toStringAsFixed(0)} м', 'объём'),
      _Metric('Игроки', '${report.playersCount}', 'в отчёте'),
      _Metric('Max', '${s.maxSpeedKmh.toStringAsFixed(1)} км/ч', 'скорость'),
      _Metric('Спринты', '${s.sprintCount}', 'кол-во'),
      _Metric('Нагрузка', s.playerLoad.toStringAsFixed(0), 'нагрузка'),
      _Metric('Кардиодатчик', '$withHr', 'игроков'),
    ];

    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 420;
      final blockHeight = compact ? 108.0 : 116.0;
      final metricExtent = compact ? 46.0 : 50.0;
      return SingleChildScrollView(
        primary: false,
        physics: const ClampingScrollPhysics(),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: compact ? 2 : 3,
              mainAxisExtent: metricExtent,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemBuilder: (_, i) => _MetricTile(metric: metrics[i]),
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: compact ? 1.52 : 1.70,
            children: [
              _TabletReportQuickBlock(
                icon: Icons.speed_rounded,
                title: 'Скорость',
                subtitle:
                    '${report.pointsCount} GPS · max ${s.maxSpeedKmh.toStringAsFixed(1)} км/ч',
                height: blockHeight,
                child: _ReportSpeedGraphPanel(report: report),
              ),
              _TabletReportQuickBlock(
                icon: Icons.radar_rounded,
                title: 'Радар / рейтинг',
                subtitle: 'сравнение игроков',
                height: blockHeight,
                child: _RadarComparisonPanel(report: report),
              ),
              _TabletReportQuickBlock(
                icon: Icons.favorite_rounded,
                title: 'Пульс / нагрузка',
                subtitle: withHr > 0
                    ? '$withHr с кардиодатчиком · зоны ЧСС'
                    : 'ожидаем кардиодатчик',
                height: blockHeight,
                child: _HrZoneSummaryBars(players: players),
              ),
              _TabletReportCoachNotes(report: report),
            ],
          ),
        ]),
      );
    });
  }
}

class _TabletReportQuickBlock extends StatelessWidget {
  const _TabletReportQuickBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.height,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(_R.mobileInnerRadius),
        border: Border.all(color: _R.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _R.border))),
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: _R.softGreen,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _R.greenLine)),
              child: Icon(icon, size: 14, color: _R.greenDark),
            ),
            const SizedBox(width: 7),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _R.text,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w900)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _R.muted,
                          fontSize: 8.7,
                          fontWeight: FontWeight.w700)),
                ])),
          ]),
        ),
        Expanded(
            child: Padding(padding: const EdgeInsets.all(6), child: child)),
      ]),
    );
  }
}

class _TabletReportCoachNotes extends StatelessWidget {
  const _TabletReportCoachNotes({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final s = report.summary;
    final players = _reportPlayers(report);
    final maxPlayer = [...players]
      ..sort((a, b) => b.maxSpeedKmh.compareTo(a.maxSpeedKmh));
    final topDistance = [...players]
      ..sort((a, b) => b.distanceM.compareTo(a.distanceM));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
          color: _R.softGreen.withOpacity(.62),
          borderRadius: BorderRadius.circular(_R.mobileInnerRadius),
          border: Border.all(color: _R.greenLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Кратко для тренера',
            style: TextStyle(
                color: _R.text, fontSize: 9.8, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        _TabletReportNoteLine(
            icon: Icons.route_rounded,
            text: topDistance.isEmpty
                ? 'Нет данных по дистанции.'
                : 'Лидер объёма: ${topDistance.first.name} · ${topDistance.first.distanceM.toStringAsFixed(0)} м.'),
        const SizedBox(height: 5),
        _TabletReportNoteLine(
            icon: Icons.speed_rounded,
            text: maxPlayer.isEmpty
                ? 'Нет данных по скорости.'
                : 'Пик скорости: ${maxPlayer.first.name} · ${maxPlayer.first.maxSpeedKmh.toStringAsFixed(1)} км/ч.'),
        const SizedBox(height: 5),
        _TabletReportNoteLine(
            icon: Icons.local_fire_department_rounded,
            text:
                'Командная нагрузка ${s.playerLoad.toStringAsFixed(0)} · HIR ${s.highSpeedDistanceM.toStringAsFixed(0)} м.'),
      ]),
    );
  }
}

class _TabletReportNoteLine extends StatelessWidget {
  const _TabletReportNoteLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 13, color: _R.greenDark),
      const SizedBox(width: 6),
      Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: _R.graphite,
                  fontSize: 8.1,
                  fontWeight: FontWeight.w800,
                  height: 1.08))),
    ]);
  }
}

bool _isReportSessionPlayer(TrackerTrainingPlayerRow p) {
  return p.pointsCount > 0 ||
      p.sessionsCount > 0 ||
      p.distanceM > 0 ||
      p.maxSpeedKmh > 0 ||
      p.heartRateSamplesCount > 0 ||
      p.heartRateAvgBpm > 0 ||
      p.playerLoad > 0;
}

List<TrackerTrainingPlayerRow> _reportPlayers(TrackerTrainingReport report) {
  final base =
      report.players.isNotEmpty ? report.players : report.diagnosticPlayers;
  final sessionPlayers =
      base.where(_isReportSessionPlayer).toList(growable: false);
  return sessionPlayers.isNotEmpty ? sessionPlayers : base;
}

String _shortReportPlayerName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return 'Игрок';
  if (parts.length == 1)
    return parts.first.length <= 10
        ? parts.first
        : '${parts.first.substring(0, 10)}…';
  return '${parts.first} ${parts[1].substring(0, 1)}.';
}

class _ReportBrandStrip extends StatelessWidget {
  const _ReportBrandStrip({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_R.mobileInnerRadius),
        border: Border.all(color: _R.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 8))
        ],
      ),
      child: Row(children: [
        _TeamLogo(url: report.teamLogoUrl, title: report.teamName, size: 38),
        const SizedBox(width: 7),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Спортотека. Отчёт',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: _R.text,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(
              '${report.teamName.isEmpty ? 'Команда' : report.teamName} · ${report.dateLabel.isEmpty ? 'дата не указана' : report.dateLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _R.muted, fontSize: 10.2, fontWeight: FontWeight.w500),
            ),
          ]),
        ),
        const SizedBox(width: 7),
        _ReportStatusPill(report: report),
      ]),
    );
  }
}

class _ReportStatusPill extends StatelessWidget {
  const _ReportStatusPill({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final ok = _hasMeaningfulTrainingData(report);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ok ? _R.softGreen : const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ok ? _R.greenLine : const Color(0xFFFEDC7A)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 15, color: ok ? _R.greenDark : const Color(0xFFB7791F)),
        const SizedBox(width: 6),
        Text(ok ? 'данные готовы' : 'нет движения',
            style: TextStyle(
                color: ok ? _R.greenDark : const Color(0xFF92400E),
                fontSize: 10,
                fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _PlayersOverview extends StatelessWidget {
  const _PlayersOverview({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report);
    if (players.isEmpty)
      return const _EmptyBlock(
          'В отчёте пока нет игроков. Проверьте выбранную сессию и привязку датчиков.');
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 460) {
        return Column(children: [
          for (var i = 0; i < players.length; i++) ...[
            _PlayerReportCompactCard(player: players[i]),
            if (i != players.length - 1) const SizedBox(height: 8),
          ],
        ]);
      }
      final columns = c.maxWidth >= 720 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: players.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 116,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (_, i) => _PlayerReportCard(player: players[i]),
      );
    });
  }
}

class _PlayerDeepDiveCards extends StatelessWidget {
  const _PlayerDeepDiveCards({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report)
        .where((p) =>
            p.distanceM > 0 || p.pointsCount > 0 || p.heartRateSamplesCount > 0)
        .toList(growable: false);
    if (players.isEmpty)
      return const _EmptyBlock(
          'Нет данных по игрокам для индивидуальных карт и графиков.');
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 980 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: math.min(players.length, 12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: c.maxWidth < 520 ? 260 : 218,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) =>
            _PlayerDeepDiveCard(report: report, player: players[index]),
      );
    });
  }
}

class _PlayerDeepDiveCard extends StatelessWidget {
  const _PlayerDeepDiveCard({required this.report, required this.player});
  final TrackerTrainingReport report;
  final TrackerTrainingPlayerRow player;

  bool _samePoint(TrackerReportPoint p) {
    if (player.playerId != null && p.playerId == player.playerId) return true;
    return p.playerName.trim().isNotEmpty &&
        p.playerName.trim().toLowerCase() == player.name.trim().toLowerCase();
  }

  bool _sameHr(TrackerHeartRatePoint p) {
    if (player.playerId != null && p.playerId == player.playerId) return true;
    return p.playerName.trim().isNotEmpty &&
        p.playerName.trim().toLowerCase() == player.name.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final points = report.routePoints.where(_samePoint).toList(growable: false);
    final hr = _reportHrTimeline(report).where(_sameHr).toList(growable: false);
    final hsrKmh = _reportHsrThreshold(report);
    final sprintKmh = _reportSprintThreshold(report);
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _R.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _PlayerAvatar(player: player, size: 36),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
                Text(
                    '${player.duration} · ${player.distanceM.toStringAsFixed(0)} м · max ${player.maxSpeedKmh.toStringAsFixed(1)} · HR ${player.heartRateSamplesCount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ])),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final vertical = c.maxWidth < 390;
            final pitch = ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(
                painter: _ReportPitchPainter(
                    points: points, hsrKmh: hsrKmh, sprintKmh: sprintKmh),
                child: points.isEmpty
                    ? const Center(
                        child: Text('нет GPS',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w900)))
                    : const SizedBox.expand(),
              ),
            );
            final map = Center(
              child: AspectRatio(
                aspectRatio: 1.72,
                child: pitch,
              ),
            );
            final timeline = Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _R.border)),
              child: ClipRect(
                  child: CustomPaint(
                      painter: _PlayerMiniTimelinePainter(
                          points: points, heartRate: hr),
                      child: const SizedBox.expand())),
            );
            if (vertical)
              return Column(children: [
                Expanded(child: map),
                const SizedBox(height: 7),
                Expanded(child: timeline)
              ]);
            return Row(children: [
              Expanded(child: map),
              const SizedBox(width: 7),
              Expanded(child: timeline)
            ]);
          }),
        ),
      ]),
    );
  }
}

class _PlayerMiniTimelinePainter extends _BaseChartPainter {
  _PlayerMiniTimelinePainter({required this.points, required this.heartRate});
  final List<TrackerReportPoint> points;
  final List<TrackerHeartRatePoint> heartRate;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(28, 20, math.max(10.0, size.width - 42),
        math.max(10.0, size.height - 44));
    drawGrid(canvas, rect, lines: 3);
    text(canvas, 'скорость / ЧСС', Offset(rect.left, 3),
        size: 8.4,
        color: _R.text,
        weight: FontWeight.w900,
        maxWidth: rect.width);
    final speed = points.where((p) => p.speedKmh > 0).toList(growable: false)
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    if (speed.isEmpty && heartRate.isEmpty) {
      text(canvas, 'нет таймлайна', Offset(rect.left + 12, rect.center.dy - 6),
          size: 9,
          color: _R.muted,
          weight: FontWeight.w900,
          maxWidth: rect.width - 24);
      return;
    }
    void drawLine<T>(List<T> list, int Function(T) key,
        double Function(T) value, double maxY, Color color) {
      if (list.isEmpty) return;
      final minX = list
          .map(key)
          .fold<int>(key(list.first), (a, b) => a < b ? a : b)
          .toDouble();
      var maxX = list
          .map(key)
          .fold<int>(key(list.first), (a, b) => a > b ? a : b)
          .toDouble();
      if ((maxX - minX).abs() < 1) maxX = minX + 60000;
      final path = Path();
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        final x = rect.left +
            rect.width *
                ((key(item) - minX) / (maxX - minX)).clamp(0.0, 1.0).toDouble();
        final y = rect.bottom -
            rect.height * (value(item).clamp(0.0, maxY) / maxY).toDouble();
        if (i == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }

    final maxSpeed = math.max(
        12.0, speed.fold<double>(0, (m, p) => math.max(m, p.speedKmh)) + 2);
    drawLine<TrackerReportPoint>(
        speed, (p) => p.timeMs, (p) => p.speedKmh, maxSpeed, _R.green);
    drawLine<TrackerHeartRatePoint>(
        heartRate, _hrPointSortKey, (p) => p.bpm.toDouble(), 210, _R.red);
    text(canvas, '0 мин', Offset(rect.left, rect.bottom + 7),
        size: 8, color: _R.muted, weight: FontWeight.w900, maxWidth: 40);
  }

  @override
  bool shouldRepaint(covariant _PlayerMiniTimelinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.heartRate != heartRate;
}

class _PlayerReportCard extends StatelessWidget {
  const _PlayerReportCard({required this.player});
  final TrackerTrainingPlayerRow player;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _R.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _PlayerAvatar(player: player, size: 38),
          const SizedBox(width: 7),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                    [
                      if (player.number.isNotEmpty) '#${player.number}',
                      if (player.position.isNotEmpty) player.position,
                      if (player.deviceName.isNotEmpty) _displayReportDeviceName(player.deviceName)
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.muted,
                        fontSize: 9.2,
                        fontWeight: FontWeight.w800)),
              ])),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: Row(children: [
            Expanded(
                child: _MiniMetric(
                    label: 'Дист.',
                    value: '${player.distanceM.toStringAsFixed(0)} м')),
            const SizedBox(width: 6),
            Expanded(
                child: _MiniMetric(
                    label: 'Макс.',
                    value: '${player.maxSpeedKmh.toStringAsFixed(1)}')),
            const SizedBox(width: 6),
            Expanded(
                child:
                    _MiniMetric(label: 'GPS', value: '${player.pointsCount}')),
          ]),
        ),
      ]),
    );
  }
}

class _PlayerReportCompactCard extends StatelessWidget {
  const _PlayerReportCompactCard({required this.player});
  final TrackerTrainingPlayerRow player;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _R.border)),
      child: Row(children: [
        _PlayerAvatar(player: player, size: 36),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.text, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Wrap(spacing: 5, runSpacing: 5, children: [
              _TinyPill(
                  label: 'Дист.',
                  value: '${player.distanceM.toStringAsFixed(0)} м'),
              _TinyPill(
                  label: 'Макс.', value: player.maxSpeedKmh.toStringAsFixed(1)),
              _TinyPill(label: 'GPS', value: '${player.pointsCount}'),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: _R.soft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _R.border)),
      child: Text('$label $value',
          style: const TextStyle(
              color: _R.graphite, fontSize: 8.2, fontWeight: FontWeight.w900)),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.player, this.size = 34});
  final TrackerTrainingPlayerRow player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = player.name.trim().isNotEmpty
        ? player.name.trim().substring(0, 1).toUpperCase()
        : '?';
    final fallback = Center(
        child: Text(letter,
            style: TextStyle(
                color: _R.greenDark,
                fontSize: size * .38,
                fontWeight: FontWeight.w900)));
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: _R.softGreen,
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: _R.greenLine)),
      child: player.avatarUrl.trim().isEmpty
          ? fallback
          : Image.network(player.avatarUrl,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

class _ActivityMapPanel extends StatefulWidget {
  const _ActivityMapPanel({required this.report, this.expandedTablet = false});
  final TrackerTrainingReport report;
  final bool expandedTablet;

  @override
  State<_ActivityMapPanel> createState() => _ActivityMapPanelState();
}

class _ActivityMapPanelState extends State<_ActivityMapPanel> {
  bool _heatMode = false;
  bool _showEvents = true;
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final rawRoute = report.routePoints;
    final hsrKmh = _reportHsrThreshold(report);
    final sprintKmh = _reportSprintThreshold(report);
    final route = _filteredReportPoints(rawRoute, _filter,
        hsrKmh: hsrKmh, sprintKmh: sprintKmh);
    final heat =
        report.heatmapPoints.isNotEmpty ? report.heatmapPoints : rawRoute;
    final hasPoints = rawRoute.isNotEmpty || heat.isNotEmpty;
    final sprintCount = rawRoute.where((p) => p.speedKmh >= sprintKmh).length;
    final eventCount = report.events.where((event) => event.hasPoint).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < 430;
        final stats =
            '${rawRoute.length} GPS · $sprintCount спринтов · $eventCount событий';
        if (compact) {
          return Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
            decoration: const BoxDecoration(),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: _MapModeButton(
                            label: 'Карта',
                            icon: Icons.timeline_rounded,
                            active: !_heatMode,
                            onTap: () => setState(() => _heatMode = false))),
                    const SizedBox(width: 6),
                    Expanded(
                        child: _MapModeButton(
                            label: 'Тепловая',
                            icon: Icons.local_fire_department_rounded,
                            active: _heatMode,
                            onTap: () => setState(() => _heatMode = true))),
                  ]),
                  const SizedBox(height: 5),
                  Text(stats,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: _R.muted,
                          fontSize: 10.4,
                          fontWeight: FontWeight.w800)),
                ]),
          );
        }
        return Container(
          height: 30,
          decoration: const BoxDecoration(),
          child: Row(children: [
            _MapModeButton(
                label: 'Карта активности',
                icon: Icons.timeline_rounded,
                active: !_heatMode,
                onTap: () => setState(() => _heatMode = false)),
            _MapModeButton(
                label: 'Тепловая карта',
                icon: Icons.local_fire_department_rounded,
                active: _heatMode,
                onTap: () => setState(() => _heatMode = true)),
            const Spacer(),
            Text(stats,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.muted,
                    fontSize: 9.7,
                    fontWeight: FontWeight.w800)),
          ]),
        );
      }),
      if (!_heatMode)
        Container(
          height: 30,
          decoration: const BoxDecoration(),
          child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              children: [
                _ActivityFilterChip(
                    label: 'Все',
                    value: 'all',
                    current: _filter,
                    onTap: _setFilter),
                _ActivityFilterChip(
                    label: 'Ходьба',
                    value: 'walk',
                    current: _filter,
                    onTap: _setFilter),
                _ActivityFilterChip(
                    label: 'Бег',
                    value: 'run',
                    current: _filter,
                    onTap: _setFilter),
                _ActivityFilterChip(
                    label: 'Высокая',
                    value: 'hir',
                    current: _filter,
                    onTap: _setFilter),
                _ActivityFilterChip(
                    label: 'Спринт',
                    value: 'sprint',
                    current: _filter,
                    onTap: _setFilter),
                _ActivityFilterChip(
                    label: 'Повороты',
                    value: 'turn',
                    current: _filter,
                    onTap: _setFilter),
                if (eventCount > 0)
                  _ActivityEventsToggleChip(
                    label: 'События $eventCount',
                    active: _showEvents,
                    onTap: () => setState(() => _showEvents = !_showEvents),
                  ),
              ]),
        ),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, c) {
        final mapHeight = widget.expandedTablet
            ? math.min(390.0, math.max(260.0, c.maxWidth / 2.05))
            : null;
        final map = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: hasPoints
              ? CustomPaint(
                  painter: _ReportPitchPainter(
                      points: _heatMode ? heat : route,
                      heatMode: _heatMode,
                      hsrKmh: hsrKmh,
                      sprintKmh: sprintKmh,
                      events: (!_heatMode && _showEvents)
                          ? report.events
                          : const <TrackerReportEvent>[]),
                  child: const SizedBox.expand(),
                )
              : CustomPaint(
                  painter: _ReportPitchPainter(points: const []),
                  child: const Center(
                      child: Text('Нет GPS-точек для карты выбранной сессии',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10.2,
                              fontWeight: FontWeight.w500))),
                ),
        );
        if (!hasPoints) {
          return Container(
            height: 82,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFFF5F8F6),
                borderRadius: BorderRadius.circular(14)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_off_rounded, size: 15, color: _R.muted),
              SizedBox(width: 8),
              Text('Нет GPS-точек для выбранной сессии',
                  style: TextStyle(
                      color: _R.muted,
                      fontSize: 10.4,
                      fontWeight: FontWeight.w500)),
            ]),
          );
        }
        if (mapHeight != null) {
          return SizedBox(
              width: double.infinity, height: mapHeight, child: map);
        }
        return AspectRatio(aspectRatio: 1.72, child: map);
      }),
    ]);
  }

  void _setFilter(String value) => setState(() => _filter = value);
}

class _MapModeButton extends StatelessWidget {
  const _MapModeButton(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(0),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
            color: active ? _R.softGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: active ? _R.green : _R.muted),
          const SizedBox(width: 7),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: active ? _R.green : _R.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 11))),
        ]),
      ),
    );
  }
}

class _ActivityFilterChip extends StatelessWidget {
  const _ActivityFilterChip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: _NoHoverTap(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: active ? _R.green : const Color(0xFFF2F5F3),
              borderRadius: BorderRadius.circular(8)),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : _R.text,
                  fontSize: 7.8,
                  fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _ActivityEventsToggleChip extends StatelessWidget {
  const _ActivityEventsToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE9F7EF) : const Color(0xFFF2F5F3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on_rounded,
                size: 11, color: active ? _R.green : _R.muted),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: active ? _R.greenDark : _R.text,
                    fontSize: 7.8,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

double _reportSprintThreshold(TrackerTrainingReport report) {
  for (final z in report.speedZones) {
    if (z.label.toLowerCase().contains('спринт')) return z.fromKmh;
  }
  return report.teamName.toUpperCase().contains('U13') ? 18.0 : 18.0;
}

double _reportHsrThreshold(TrackerTrainingReport report) {
  for (final z in report.speedZones) {
    if (z.label.toLowerCase().contains('высок')) return z.fromKmh;
  }
  return report.teamName.toUpperCase().contains('U13') ? 14.0 : 14.0;
}

List<TrackerReportPoint> _filteredReportPoints(
    List<TrackerReportPoint> points, String filter,
    {required double hsrKmh, required double sprintKmh}) {
  if (filter == 'all' || points.length < 2) return points;
  final out = <TrackerReportPoint>[];
  TrackerReportPoint clonePoint(TrackerReportPoint p,
          {required bool breakBefore, double? displaySpeed}) =>
      TrackerReportPoint(
        playerId: p.playerId,
        playerName: p.playerName,
        x: p.x,
        y: p.y,
        speedKmh: displaySpeed ?? p.speedKmh,
        value: p.value,
        distanceM: p.distanceM,
        timeMs: p.timeMs,
        breakBefore: breakBefore,
      );
  for (var i = 1; i < points.length; i++) {
    final p = points[i];
    final prev = points[i - 1];
    if (p.breakBefore) continue;
    final dt = (p.timeMs - prev.timeMs).abs();
    if (dt > 60000) continue;
    var keep = false;
    if (filter == 'walk') keep = p.speedKmh > 0 && p.speedKmh < 7;
    if (filter == 'run') keep = p.speedKmh >= 7 && p.speedKmh < hsrKmh;
    if (filter == 'hir') keep = p.speedKmh >= hsrKmh && p.speedKmh < sprintKmh;
    if (filter == 'sprint') keep = p.speedKmh >= sprintKmh;
    if (filter == 'turn' && i < points.length - 1) {
      final a = points[i - 1], b = points[i], c = points[i + 1];
      final v1 = Offset(b.x - a.x, b.y - a.y);
      final v2 = Offset(c.x - b.x, c.y - b.y);
      if (v1.distance >= .01 && v2.distance >= .01) {
        final dot =
            ((v1.dx * v2.dx + v1.dy * v2.dy) / (v1.distance * v2.distance))
                .clamp(-1.0, 1.0);
        keep = math.acos(dot) > .7;
      }
    }
    if (keep) {
      // Добавляем пару prev->current, чтобы фильтр не соединял далекие точки
      // одной неправильной диагональю. Обе точки получают скорость выбранного
      // сегмента — тогда цвет/подпись фильтра совпадают с линией аналитики.
      out.add(clonePoint(points[i - 1],
          breakBefore: true, displaySpeed: p.speedKmh));
      out.add(clonePoint(p, breakBefore: false, displaySpeed: p.speedKmh));
    }
  }
  return out;
}

Color _reportEventColor(TrackerReportEvent event) {
  if (event.severity.toLowerCase() == 'red' || event.kind == 'sprint') {
    return const Color(0xFFDC2626);
  }
  switch (event.kind) {
    case 'hir':
      return const Color(0xFFF59E0B);
    case 'accel':
      return const Color(0xFF00A750);
    case 'decel':
      return const Color(0xFFF97316);
    case 'turn':
      return const Color(0xFF2563EB);
    case 'gps_gap':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF667085);
  }
}

String _reportEventGlyph(TrackerReportEvent event) {
  switch (event.kind) {
    case 'sprint':
      return 'S';
    case 'hir':
      return 'H';
    case 'accel':
      return '↑';
    case 'decel':
      return '↓';
    case 'turn':
      return '↻';
    case 'gps_gap':
      return '!';
    default:
      return '•';
  }
}

String _reportEventKindLabel(String kind) {
  switch (kind) {
    case 'sprint':
      return 'Спринт';
    case 'hir':
      return 'Высокая скорость';
    case 'accel':
      return 'Ускорение';
    case 'decel':
      return 'Торможение';
    case 'turn':
      return 'Смена направления';
    case 'gps_gap':
      return 'Разрыв GPS';
    default:
      return 'Событие';
  }
}

String _reportEventPlayerShortName(String raw) {
  final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty) return 'Игрок';
  final parts = value.split(' ');
  if (parts.length < 2) return value;
  if (parts[1].endsWith('.')) return '${parts[0]} ${parts[1]}';
  return '${parts[0]} ${parts[1].substring(0, 1).toUpperCase()}.';
}

String _reportEventMetricLabel(TrackerReportEvent event) {
  final parts = <String>[];
  if (event.speedKmh > 0) parts.add('${event.speedKmh.toStringAsFixed(1)} км/ч');
  if (event.bpm > 0) parts.add('${event.bpm} уд/мин');
  if (event.accelerationMps2.abs() >= .5 &&
      (event.kind == 'accel' || event.kind == 'decel')) {
    parts.add('${event.accelerationMps2.toStringAsFixed(2)} м/с²');
  }
  return parts.join(' · ');
}

class _ReportEventsPanel extends StatefulWidget {
  const _ReportEventsPanel({required this.report});
  final TrackerTrainingReport report;

  @override
  State<_ReportEventsPanel> createState() => _ReportEventsPanelState();
}

class _ReportEventsPanelState extends State<_ReportEventsPanel> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final all = widget.report.events;
    if (all.isEmpty) {
      return const _EmptyBlock(
          'Журнал появится после GPS-движения: спринты, ускорения, торможения, смены направления и разрывы связи.');
    }
    final filtered = _filter == 'all'
        ? all
        : all.where((event) => event.kind == _filter).toList(growable: false);
    final visible = filtered.take(48).toList(growable: false);
    int count(String kind) => all.where((event) => event.kind == kind).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _ReportEventFilterChip(
              label: 'Все ${all.length}',
              active: _filter == 'all',
              onTap: () => setState(() => _filter = 'all')),
          _ReportEventFilterChip(
              label: 'Спринты ${count('sprint')}',
              active: _filter == 'sprint',
              onTap: () => setState(() => _filter = 'sprint')),
          _ReportEventFilterChip(
              label: 'Ускорения ${count('accel')}',
              active: _filter == 'accel',
              onTap: () => setState(() => _filter = 'accel')),
          _ReportEventFilterChip(
              label: 'Торможения ${count('decel')}',
              active: _filter == 'decel',
              onTap: () => setState(() => _filter = 'decel')),
          _ReportEventFilterChip(
              label: 'Повороты ${count('turn')}',
              active: _filter == 'turn',
              onTap: () => setState(() => _filter = 'turn')),
          if (count('gps_gap') > 0)
            _ReportEventFilterChip(
                label: 'GPS ${count('gps_gap')}',
                active: _filter == 'gps_gap',
                onTap: () => setState(() => _filter = 'gps_gap')),
        ]),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < visible.length; i++) ...[
        _ReportEventRow(event: visible[i]),
        if (i != visible.length - 1)
          const Divider(height: 1, thickness: .5, color: Color(0xFFE9ECEA)),
      ],
      if (filtered.length > visible.length) ...[
        const SizedBox(height: 7),
        Text('Показано ${visible.length} из ${filtered.length} событий',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _R.muted, fontSize: 9.5, fontWeight: FontWeight.w700)),
      ],
    ]);
  }
}

class _ReportEventFilterChip extends StatelessWidget {
  const _ReportEventFilterChip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: _NoHoverTap(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: active ? _R.green : const Color(0xFFF4F6F5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(label,
                style: TextStyle(
                    color: active ? Colors.white : _R.graphite,
                    fontSize: 9.4,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

class _ReportEventRow extends StatelessWidget {
  const _ReportEventRow({required this.event});
  final TrackerReportEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _reportEventColor(event);
    final title = event.title.trim().isNotEmpty
        ? event.title.trim()
        : _reportEventKindLabel(event.kind);
    final metric = _reportEventMetricLabel(event);
    final elapsed = event.elapsedMs > 0
        ? _reportElapsedLabel(event.elapsedMs)
        : (event.timeMs > 0 ? 'момент' : '—');
    final player = _reportEventPlayerShortName(event.playerName);
    final badge = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: color.withOpacity(.10), borderRadius: BorderRadius.circular(9)),
      child: Text(_reportEventGlyph(event),
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 520) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            badge,
            const SizedBox(width: 9),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(elapsed,
                      style: const TextStyle(
                          color: _R.graphite,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(player,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _R.text,
                            fontSize: 10.2,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (event.hasPoint)
                    Icon(Icons.location_on_rounded, size: 13, color: color),
                ]),
                const SizedBox(height: 2),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.text,
                        fontSize: 10.4,
                        fontWeight: FontWeight.w800)),
                if (event.detail.trim().isNotEmpty || metric.isNotEmpty)
                  Text(
                    [event.detail.trim(), metric].where((v) => v.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.muted,
                        fontSize: 9.1,
                        fontWeight: FontWeight.w500),
                  ),
              ]),
            ),
          ]),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          badge,
          const SizedBox(width: 9),
          SizedBox(
            width: 82,
            child: Text(elapsed,
                style: const TextStyle(
                    color: _R.graphite,
                    fontSize: 10.3,
                    fontWeight: FontWeight.w900)),
          ),
          SizedBox(
            width: 126,
            child: Text(player,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.text,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _R.text,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800)),
              if (event.detail.trim().isNotEmpty)
                Text(event.detail.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.muted,
                        fontSize: 9.2,
                        fontWeight: FontWeight.w500)),
            ]),
          ),
          if (metric.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(metric,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: _R.graphite,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800)),
          ],
          if (event.hasPoint) ...[
            const SizedBox(width: 7),
            Icon(Icons.location_on_rounded, size: 14, color: color),
          ],
        ]),
      );
    });
  }
}

class _SpeedZonesPanel extends StatelessWidget {
  const _SpeedZonesPanel({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final zones = report.speedZones;
    if (zones.isEmpty)
      return const _EmptyBlock(
          'Скоростные зоны появятся после получения точек со speed_kmh.');
    final totalDistance =
        zones.fold<double>(0, (m, z) => m + math.max(0.0, z.distanceM));
    final totalPoints =
        zones.fold<int>(0, (m, z) => m + math.max(0, z.pointsCount));
    return Column(children: [
      for (final z in zones) ...[
        Builder(builder: (context) {
          final useDistance = totalDistance > 0;
          final raw = useDistance
              ? math.max(0.0, z.distanceM)
              : math.max(0, z.pointsCount).toDouble();
          final total =
              useDistance ? totalDistance : math.max(1, totalPoints).toDouble();
          final percent = total > 0 ? (raw * 100 / total).round() : 0;
          final label = useDistance
              ? '${z.distanceM.toStringAsFixed(0)} м · $percent%'
              : '${z.pointsCount} точ. · $percent%';
          return Row(children: [
            SizedBox(
                width: 126,
                child: Text(z.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.text,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w900))),
            Expanded(
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                        value: (raw / total).clamp(0, 1).toDouble(),
                        minHeight: 9,
                        backgroundColor: _R.soft,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _zoneColor(z.fromKmh))))),
            const SizedBox(width: 7),
            SizedBox(
                width: 92,
                child: Text(label,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: _R.graphite,
                        fontSize: 10,
                        fontWeight: FontWeight.w900))),
          ]);
        }),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

Color _zoneColor(double fromKmh) {
  if (fromKmh >= 18.0) return _R.red;
  if (fromKmh >= 14.0) return const Color(0xFFF59E0B);
  if (fromKmh >= 14) return const Color(0xFFFACC15);
  if (fromKmh >= 7) return _R.green;
  return const Color(0xFF6CCB91);
}

class _ReportPitchPainter extends CustomPainter {
  _ReportPitchPainter(
      {required this.points,
      this.heatMode = false,
      this.speedMode = false,
      this.hsrKmh = 14.0,
      this.sprintKmh = 18.0,
      this.events = const <TrackerReportEvent>[]});
  final List<TrackerReportPoint> points;
  final List<TrackerReportEvent> events;
  final bool heatMode;
  final bool speedMode;
  final double hsrKmh;
  final double sprintKmh;

  @override
  void paint(Canvas canvas, Size size) {
    // Точная геометрия/палитра из Analytics _ActionPitchPainter._drawPitch.
    final border =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.drawRRect(border, Paint()..color = const Color(0xFF76947B));
    final stripeClip = Path()..addRRect(border.deflate(8));
    canvas.save();
    canvas.clipPath(stripeClip);
    final stripeW = math.max(36.0, size.width / 12);
    for (var i = 0; i < 14; i++) {
      final color =
          i.isEven ? const Color(0xFF719078) : const Color(0xFF819E86);
      canvas.drawRect(
          Rect.fromLTWH(8 + i * stripeW, 8, stripeW, size.height - 16),
          Paint()..color = color);
    }
    canvas.restore();
    final pitch = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final clip = RRect.fromRectAndRadius(pitch, const Radius.circular(12));
    _drawPitchLines(canvas, size, pitch, clip);
    if (points.isEmpty) return;

    if (heatMode) {
      final maxValue = points.fold<double>(
          1.0, (m, p) => math.max(m, p.value <= 0 ? 1.0 : p.value));
      canvas.save();
      canvas.clipRRect(clip);
      final visible = points.take(1600).toList(growable: false);
      for (final p in visible) {
        final o = _point(pitch, p);
        final ratio = ((p.value <= 0 ? 1.0 : p.value) / maxValue)
            .clamp(0.0, 1.0)
            .toDouble();
        final c = Color.lerp(
                const Color(0xFF22C55E), const Color(0xFFDC2626), ratio) ??
            _R.green;
        final r = visible.length <= 2 ? 18.0 : (12.0 + ratio * 26.0);
        canvas.drawCircle(
            o,
            r,
            Paint()
              ..shader = RadialGradient(colors: [
                c.withOpacity(.55),
                c.withOpacity(.24),
                c.withOpacity(0.0)
              ], stops: const [
                0.0,
                .50,
                1.0
              ]).createShader(Rect.fromCircle(center: o, radius: r)));
      }
      canvas.restore();
      return;
    }

    final local = points.take(1400).toList();
    if (local.length > 1) {
      for (var i = 1; i < local.length; i++) {
        final a = _point(pitch, local[i - 1]);
        final b = _point(pitch, local[i]);
        final p = local[i];
        if (p.breakBefore) continue;
        final dt = (p.timeMs - local[i - 1].timeMs).abs();
        if (dt > 60000) continue;
        final speed = p.speedKmh;
        final color =
            _reportSpeedColor(speed, hsrKmh: hsrKmh, sprintKmh: sprintKmh);
        canvas.drawLine(
            a,
            b,
            Paint()
              ..color = color.withOpacity(speed >= sprintKmh ? .18 : .08)
              ..strokeWidth = speed >= sprintKmh ? 8.0 : 5.0
              ..strokeCap = StrokeCap.round);
        canvas.drawLine(
            a,
            b,
            Paint()
              ..color = color.withOpacity(speed >= sprintKmh ? .97 : .84)
              ..strokeWidth =
                  speed >= sprintKmh ? 3.2 : (speed >= hsrKmh ? 2.7 : 1.9)
              ..strokeCap = StrokeCap.round);
        if (i % 14 == 0 || speed >= sprintKmh) {
          _drawArrow(canvas, a, b, Paint()..color = color.withOpacity(.92));
        }
      }
    }
    Offset? lastLabel;
    for (var i = 0; i < local.length; i++) {
      final p = local[i];
      final o = _point(pitch, p);
      final color =
          _reportSpeedColor(p.speedKmh, hsrKmh: hsrKmh, sprintKmh: sprintKmh);
      final r = p.speedKmh >= sprintKmh ? 4.8 : (p.speedKmh >= 7 ? 3.8 : 3.0);
      canvas.drawCircle(o, r + 2.8, Paint()..color = color.withOpacity(.08));
      canvas.drawCircle(o, r, Paint()..color = color.withOpacity(.95));
      if (p.speedKmh > 0 &&
          (i == 0 ||
              i == local.length - 1 ||
              p.speedKmh >= sprintKmh ||
              lastLabel == null ||
              (o - lastLabel).distance > 42)) {
        _paintSmallText(canvas, p.speedKmh.toStringAsFixed(1),
            o + const Offset(6, -10), color);
        lastLabel = o;
      }
    }
    _drawEventMarkers(canvas, pitch);
  }

  void _drawEventMarkers(Canvas canvas, Rect pitch) {
    final markers = events.where((event) => event.hasPoint).toList(growable: false);
    if (markers.isEmpty) return;
    final sorted = markers.toList()
      ..sort((a, b) {
        int priority(TrackerReportEvent event) {
          if (event.kind == 'gps_gap') return 0;
          if (event.kind == 'sprint' || event.severity == 'red') return 1;
          if (event.kind == 'accel' || event.kind == 'decel') return 2;
          return 3;
        }
        final byPriority = priority(a).compareTo(priority(b));
        return byPriority != 0 ? byPriority : b.timeMs.compareTo(a.timeMs);
      });
    for (final event in sorted.take(90)) {
      final o = Offset(
        pitch.left + event.x.clamp(0.0, 1.0).toDouble() * pitch.width,
        pitch.top + event.y.clamp(0.0, 1.0).toDouble() * pitch.height,
      );
      final color = _reportEventColor(event);
      canvas.drawCircle(o, 8.2, Paint()..color = Colors.white.withOpacity(.98));
      canvas.drawCircle(o, 6.3, Paint()..color = color.withOpacity(.98));
      final text = TextPainter(
        text: TextSpan(
          text: _reportEventGlyph(event),
          style: const TextStyle(
              color: Colors.white, fontSize: 7.2, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, o - Offset(text.width / 2, text.height / 2));
    }
  }

  Offset _point(Rect pitch, TrackerReportPoint p) => Offset(
      pitch.left + p.x.clamp(0, 1).toDouble() * pitch.width,
      pitch.top + p.y.clamp(0, 1).toDouble() * pitch.height);

  void _drawPitchLines(Canvas canvas, Size size, Rect pitch, RRect clip) {
    final line = Paint()
      ..color = Colors.white.withOpacity(.78)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(clip, line);
    canvas.drawLine(Offset(size.width / 2, 10),
        Offset(size.width / 2, size.height - 10), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2),
        math.min(size.width, size.height) * .12, line);
    canvas.drawRect(
        Rect.fromLTWH(
            10, size.height * .28, size.width * .17, size.height * .44),
        line);
    canvas.drawRect(
        Rect.fromLTWH(
            10, size.height * .38, size.width * .08, size.height * .24),
        line);
    canvas.drawRect(
        Rect.fromLTWH(size.width - 10 - size.width * .17, size.height * .28,
            size.width * .17, size.height * .44),
        line);
    canvas.drawRect(
        Rect.fromLTWH(size.width - 10 - size.width * .08, size.height * .38,
            size.width * .08, size.height * .24),
        line);
    canvas.drawCircle(Offset(size.width * .13, size.height / 2), 3,
        Paint()..color = Colors.white.withOpacity(.75));
    canvas.drawCircle(Offset(size.width * .87, size.height / 2), 3,
        Paint()..color = Colors.white.withOpacity(.75));
  }

  void _drawArrow(Canvas canvas, Offset a, Offset b, Paint paint) {
    final d = b - a;
    if (d.distance < 4) return;
    final u = d / d.distance;
    final p = Offset(-u.dy, u.dx);
    final tip = b;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - u * 10 + p * 5).dx, (tip - u * 10 + p * 5).dy)
      ..lineTo((tip - u * 10 - p * 5).dx, (tip - u * 10 - p * 5).dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintSmallText(Canvas canvas, String text, Offset offset, Color color) {
    final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                color: color, fontSize: 9.6, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: 42);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ReportPitchPainter oldDelegate) => true;
}

String _displayReportDeviceName(String raw) {
  final value = raw.trim();
  final lower = value.toLowerCase();
  if (lower.contains('polar') || lower.contains('h10')) return 'Кардиодатчик';
  return value;
}

Color _reportSpeedColor(double speed,
    {double hsrKmh = 14.0, double sprintKmh = 18.0}) {
  if (speed >= sprintKmh) return const Color(0xFFDC2626);
  if (speed >= hsrKmh) return const Color(0xFFF59E0B);
  if (speed >= 7) return _R.green;
  return const Color(0xFF2563EB);
}

class _ReportSpeedGraphPanel extends StatelessWidget {
  const _ReportSpeedGraphPanel(
      {required this.report, this.constrainedHeight = false});
  final TrackerTrainingReport report;
  final bool constrainedHeight;

  @override
  Widget build(BuildContext context) {
    final samples = report.routePoints
        .map((p) => p.speedKmh)
        .where((v) => v.isFinite && v >= 0)
        .toList();
    final maxSpeed = samples.isEmpty
        ? report.summary.maxSpeedKmh
        : samples.fold<double>(report.summary.maxSpeedKmh, math.max);
    if (samples.isEmpty && maxSpeed <= 0) {
      return const _EmptyBlock('Нет GPS-данных скорости для выбранной сессии.');
    }
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 58,
        child: Row(children: [
          Expanded(
              child: _MiniMetric(
                  label: 'Средняя',
                  value:
                      '${report.summary.avgSpeedKmh.toStringAsFixed(1)} км/ч')),
          const SizedBox(width: 6),
          Expanded(
              child: _MiniMetric(
                  label: 'Макс.',
                  value: '${maxSpeed.toStringAsFixed(1)} км/ч')),
          const SizedBox(width: 6),
          Expanded(
              child: _MiniMetric(
                  label: 'GPS', value: '${report.routePoints.length}')),
          const SizedBox(width: 6),
          Expanded(
              child: _MiniMetric(
                  label: 'Спринты', value: '${report.summary.sprintCount}')),
        ]),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 170,
        child: CustomPaint(
          painter: _ReportSpeedPainter(
              samples: samples,
              maxSpeedKmh: maxSpeed,
              durationMs: _reportTimelineDurationMs(report),
              hsrKmh: _reportHsrThreshold(report),
              sprintKmh: _reportSprintThreshold(report)),
          child: const SizedBox.expand(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _SpeedZonesPanel(report: report),
      ),
    ]);
    if (!constrainedHeight) return content;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: content);
  }
}

int _reportTimelineDurationMs(TrackerTrainingReport report) {
  final times = report.routePoints
      .map((p) => p.timeMs)
      .where((t) => t > 0)
      .toList(growable: false);
  if (times.length > 1) {
    final minT = times.reduce((a, b) => a < b ? a : b);
    final maxT = times.reduce((a, b) => a > b ? a : b);
    final delta = maxT - minT;
    if (delta > 0 && delta <= const Duration(hours: 12).inMilliseconds) {
      return delta;
    }
  }
  final parts = report.durationLabel.split(':').map(int.tryParse).toList();
  if (parts.length == 3 && parts.every((v) => v != null)) {
    return (((parts[0] ?? 0) * 3600 + (parts[1] ?? 0) * 60 + (parts[2] ?? 0)) *
            1000)
        .clamp(0, const Duration(hours: 12).inMilliseconds)
        .toInt();
  }
  if (parts.length == 2 && parts.every((v) => v != null)) {
    return (((parts[0] ?? 0) * 60 + (parts[1] ?? 0)) * 1000)
        .clamp(0, const Duration(hours: 12).inMilliseconds)
        .toInt();
  }
  return 0;
}

String _reportElapsedLabel(int milliseconds) {
  final seconds = math.max(0, (milliseconds / 1000).round());
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}';
  return '$m:${s.toString().padLeft(2, '0')}';
}

class _ReportSpeedPainter extends CustomPainter {
  const _ReportSpeedPainter(
      {required this.samples,
      required this.maxSpeedKmh,
      required this.durationMs,
      this.hsrKmh = 14.0,
      this.sprintKmh = 18.0});
  final List<double> samples;
  final double maxSpeedKmh;
  final int durationMs;
  final double hsrKmh;
  final double sprintKmh;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(48, 26, math.max(20.0, size.width - 60),
        math.max(20.0, size.height - 66));
    final grid = Paint()
      ..color = _R.border
      ..strokeWidth = 1;
    final maxY = math.max(
        34.0, math.max(maxSpeedKmh, samples.fold<double>(0, math.max)) + 3);
    for (var i = 0; i <= 4; i++) {
      final y = rect.bottom - rect.height * i / 4;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
      _chartText(canvas, (maxY * i / 4).round().toString(), Offset(8, y - 8),
          _R.muted, 9, FontWeight.w800);
    }
    _chartText(canvas, 'Скорость, км/ч', Offset(rect.left, 2), _R.text, 10,
        FontWeight.w900);
    final effectiveDuration = durationMs > 0 ? durationMs : 60000;
    for (var i = 0; i <= 4; i++) {
      final x = rect.left + rect.width * i / 4;
      final label = _reportElapsedLabel((effectiveDuration * i / 4).round());
      _chartText(canvas, label, Offset(x - (i == 0 ? 0 : 18), rect.bottom + 8),
          _R.muted, 8.6, FontWeight.w800);
    }
    _chartText(canvas, 'время', Offset(rect.right - 32, size.height - 14),
        _R.muted, 8.6, FontWeight.w800);
    void threshold(double value, Color color, String label) {
      if (value <= 0 || value > maxY) return;
      final y = rect.bottom - rect.height * value / maxY;
      canvas.drawLine(
          Offset(rect.left, y),
          Offset(rect.right, y),
          Paint()
            ..color = color.withOpacity(.72)
            ..strokeWidth = 1.4);
      _chartText(canvas, label, Offset(rect.right - 58, y - 16), color, 10,
          FontWeight.w900);
    }

    threshold(
        hsrKmh, const Color(0xFFF59E0B), 'HIR ${hsrKmh.toStringAsFixed(1)}');
    threshold(sprintKmh, _R.red, 'SPR ${sprintKmh.toStringAsFixed(1)}');
    if (samples.isEmpty) return;
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = rect.left +
          rect.width * (samples.length == 1 ? 0 : i / (samples.length - 1));
      final y = rect.bottom -
          rect.height * samples[i].clamp(0, maxY).toDouble() / maxY;
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = _R.green
          ..strokeWidth = 2.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    final step = math.max(1, (samples.length / 8).ceil());
    for (var i = 0; i < samples.length; i += step) {
      final x = rect.left +
          rect.width * (samples.length == 1 ? 0 : i / (samples.length - 1));
      final y = rect.bottom -
          rect.height * samples[i].clamp(0, maxY).toDouble() / maxY;
      final c =
          _reportSpeedColor(samples[i], hsrKmh: hsrKmh, sprintKmh: sprintKmh);
      canvas.drawCircle(Offset(x, y), 7, Paint()..color = c.withOpacity(.15));
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = c);
      _chartText(canvas, samples[i].toStringAsFixed(1), Offset(x - 10, y - 24),
          c, 9, FontWeight.w900);
    }
  }

  void _chartText(Canvas canvas, String text, Offset offset, Color color,
      double size, FontWeight weight) {
    final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: 80);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ReportSpeedPainter oldDelegate) => true;
}

class _RadarComparisonPanel extends StatelessWidget {
  const _RadarComparisonPanel({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report);
    return LayoutBuilder(builder: (context, c) {
      final two = c.maxWidth >= 560;
      final left = _RadarMiniCard(
        title: 'Рейтинг команды',
        subtitle:
            '${report.teamName.isEmpty ? 'Команда' : report.teamName} · ${players.length} игроков',
        child: _ReportRadarPainter(players: players),
      );
      final right = _RadarMiniCard(
        title: 'Сравнение игрока',
        subtitle: players.isEmpty
            ? 'игрок против среднего команды'
            : '${players.first.name} против среднего команды',
        child: _ReportRadarPainter(
            players: players.isEmpty ? players : [players.first],
            baselinePlayers: players),
      );
      if (!two)
        return Column(children: [
          Expanded(child: left),
          const SizedBox(height: 8),
          Expanded(child: right)
        ]);
      return Row(children: [
        Expanded(child: left),
        const SizedBox(width: 7),
        Expanded(child: right)
      ]);
    });
  }
}

class _RadarMiniCard extends StatelessWidget {
  const _RadarMiniCard(
      {required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final CustomPainter child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _R.border),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.muted,
                    fontSize: 9.6,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
        Expanded(
            child: CustomPaint(painter: child, child: const SizedBox.expand())),
      ]),
    );
  }
}

class _ReportRadarPainter extends CustomPainter {
  _ReportRadarPainter(
      {required this.players,
      this.baselinePlayers = const <TrackerTrainingPlayerRow>[]});
  final List<TrackerTrainingPlayerRow> players;
  final List<TrackerTrainingPlayerRow> baselinePlayers;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 2);
    final r = math.min(size.width, size.height) * .42;
    final grid = Paint()
      ..color = _R.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var ring = 1; ring <= 4; ring++)
      canvas.drawCircle(c, r * ring / 4, grid);
    final labels = ['объём', 'скорость', 'спринты', 'HIR', 'нагрузка'];
    for (var i = 0; i < labels.length; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / labels.length;
      final end = c + Offset(math.cos(a) * r, math.sin(a) * r);
      canvas.drawLine(c, end, grid);
      _radarText(canvas, labels[i],
          c + Offset(math.cos(a) * (r + 27), math.sin(a) * (r + 27)), 10.5);
    }
    if (players.isEmpty && baselinePlayers.isEmpty) return;
    // Нормировки должны совпадать с аналитикой (_RadarPainter), иначе отчёт рисует другой профиль.
    List<double> radarValues(List<TrackerTrainingPlayerRow> src) {
      if (src.isEmpty) return const <double>[];
      double avg(double Function(TrackerTrainingPlayerRow p) pick) =>
          src.map(pick).fold<double>(0, (a, b) => a + b) / src.length;
      double clamp(double v) =>
          v.isNaN || v.isInfinite ? 0 : v.clamp(0.0, 1.0).toDouble();
      return <double>[
        clamp(avg((p) => p.distanceM) / 6000.0),
        clamp(avg((p) => p.maxSpeedKmh) / 34.0),
        clamp(avg((p) => p.sprintCount.toDouble()) / 25.0),
        clamp(avg((p) => p.highSpeedWorkM) / 1200.0),
        clamp(avg((p) => p.playerLoad) / 1000.0),
      ];
    }

    void drawPath(List<double> values,
        {required Color fill,
        required Color stroke,
        required double strokeWidth}) {
      if (values.isEmpty) return;
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final a = -math.pi / 2 + i * math.pi * 2 / values.length;
        final level = values[i].clamp(0.0, 1.0).toDouble();
        final p = c + Offset(math.cos(a) * r * level, math.sin(a) * r * level);
        if (i == 0)
          path.moveTo(p.dx, p.dy);
        else
          path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..color = fill
            ..style = PaintingStyle.fill);
      canvas.drawPath(
          path,
          Paint()
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth);
    }

    final baseline = radarValues(baselinePlayers);
    final values = radarValues(players);
    if (baseline.isNotEmpty) {
      drawPath(baseline,
          fill: _R.muted.withOpacity(.08),
          stroke: _R.muted.withOpacity(.50),
          strokeWidth: 1.4);
    }
    if (values.isNotEmpty) {
      drawPath(values,
          fill: _R.green.withOpacity(.17), stroke: _R.green, strokeWidth: 2.4);
    }
  }

  void _radarText(Canvas canvas, String text, Offset center, double size) {
    final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                color: _R.muted, fontSize: size, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: 72);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ReportRadarPainter oldDelegate) =>
      oldDelegate.players != players ||
      oldDelegate.baselinePlayers != baselinePlayers;
}

bool _hasMeaningfulTrainingData(TrackerTrainingReport report) {
  if (report.summary.averageDistanceM > 1 ||
      report.summary.maxSpeedKmh > .5 ||
      report.summary.highSpeedDistanceM > 1 ||
      report.summary.playerLoad > 1 ||
      report.summary.heartRateSamplesCount > 0 ||
      report.summary.accelerationCount > 0 ||
      report.summary.decelerationCount > 0) {
    return true;
  }
  return report.players.any((p) =>
      p.distanceM > 1 ||
      p.maxSpeedKmh > .5 ||
      p.highSpeedWorkM > 1 ||
      p.playerLoad > 1 ||
      p.heartRateSamplesCount > 0 ||
      p.accelerations > 0 ||
      p.decelerations > 0 ||
      p.sprintCount > 0);
}

class _NoMovementNotice extends StatelessWidget {
  const _NoMovementNotice({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final players = report.players.isEmpty
        ? 'игроки не найдены'
        : '${report.players.length} игрок(ов)';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEDC7A)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFEDC7A))),
          child: const Icon(Icons.info_outline_rounded,
              color: Color(0xFFB7791F), size: 15),
        ),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('В этой сессии нет подтверждённого движения',
                style: TextStyle(
                    color: _R.text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              '$players · дистанция и скорость равны нулю. Карты и рейтинги не должны строиться как полноценная тренировка, пока датчик не отдаст реальные GPS-точки.',
              style: const TextStyle(
                  color: _R.muted,
                  fontSize: 10.2,
                  height: 1.3,
                  fontWeight: FontWeight.w700),
            ),
          ]),
        ),
      ]),
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
      _Metric('Дистанция', s.averageDistanceM.toStringAsFixed(0), 'м'),
      _Metric('Игроки', '${report.playersCount}', 'с движением'),
      _Metric('Средняя скорость', s.avgSpeedKmh.toStringAsFixed(1), 'км/ч'),
      _Metric('Макс. скорость', s.maxSpeedKmh.toStringAsFixed(1), 'км/ч'),
      _Metric(
          'Скоростная работа', s.highSpeedDistanceM.toStringAsFixed(0), 'м'),
      _Metric('V3 бег', s.v3RunM.toStringAsFixed(0), 'м'),
      _Metric('V4 ВСБ', s.v4HsrM.toStringAsFixed(0), 'м'),
      _Metric('V5 спринт', s.v5SprintM.toStringAsFixed(0), 'м'),
      _Metric('Спринты', '${s.sprintCount}', 'кол-во'),
      _Metric('Ускор./торм.', s.accDecPerMin.toStringAsFixed(1), 'в мин'),
      _Metric('Ускорения', '${s.accelerationCount}', 'кол-во'),
      _Metric('Торможения', '${s.decelerationCount}', 'кол-во'),
      _Metric('Взрывные', '${s.explosiveActions}', 'действия'),
      _Metric('Нагрузка', s.playerLoad.toStringAsFixed(0), 'усл. ед.'),
      _Metric(
          'Средний пульс',
          s.heartRateAvgBpm > 0 ? s.heartRateAvgBpm.toStringAsFixed(0) : '—',
          'bpm'),
      _Metric(
          'Макс. пульс',
          s.heartRateMaxBpm > 0 ? s.heartRateMaxBpm.toStringAsFixed(0) : '—',
          'bpm'),
      _Metric('HR-записи', '${s.heartRateSamplesCount}', 'точек'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 460;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tiles.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: compact ? 176 : 190,
          mainAxisExtent: compact ? 62 : 72,
          crossAxisSpacing: compact ? 7 : 8,
          mainAxisSpacing: compact ? 7 : 8,
        ),
        itemBuilder: (_, i) => _MetricTile(metric: tiles[i]),
      );
    });
  }
}

class _ReportCmrDots extends StatelessWidget {
  const _ReportCmrDots({this.count = 4});
  final int count;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(
          count,
          (i) => Container(
            width: 4,
            height: 4,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
            decoration: BoxDecoration(
              color: _R.green.withOpacity(i == 0 ? .36 : .92),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}

class _ReportCmrSection extends StatelessWidget {
  const _ReportCmrSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.tint = const Color(0xFFF7FAF8),
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: _R.green, size: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _RText.title(14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _ReportCmrDots(),
                ]),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _RText.body(9.5),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

class _ReportCmrHero extends StatelessWidget {
  const _ReportCmrHero({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.note,
    required this.icon,
    this.tint = const Color(0xFFF1FAF5),
  });
  final String title;
  final String subtitle;
  final String value;
  final String note;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: _R.green, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _RText.title(14),
                  ),
                ),
                const SizedBox(width: 8),
                const _ReportCmrDots(),
              ]),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _RText.body(10.2),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(minWidth: 92),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.9),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value, style: _RText.value(15)),
              Text(note, style: _RText.body(9.5)),
            ]),
          ),
        ]),
      );
}

class _LocomotorTab extends StatelessWidget {
  const _LocomotorTab({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final players = report.players;
    final summary = report.summary;
    final metrics = <_Metric>[
      _Metric('Дистанция', summary.averageDistanceM.toStringAsFixed(0), 'м в среднем'),
      _Metric('Средняя скорость', summary.avgSpeedKmh.toStringAsFixed(1), 'км/ч'),
      _Metric('Максимальная скорость', summary.maxSpeedKmh.toStringAsFixed(1), 'км/ч'),
      _Metric('Скоростная работа', (summary.v4HsrM + summary.v5SprintM).toStringAsFixed(0), 'м V4 + V5'),
      _Metric('V3 — бег', summary.v3RunM.toStringAsFixed(0), 'метров'),
      _Metric('V4 — высокая скорость', summary.v4HsrM.toStringAsFixed(0), 'метров'),
      _Metric('V5 — спринт', summary.v5SprintM.toStringAsFixed(0), 'метров'),
      _Metric('Спринты', '${summary.sprintCount}', 'за тренировку'),
    ];

    return _ScrollPage(children: [
      _ReportCmrHero(
        title: 'Локомоторная нагрузка',
        subtitle: report.title,
        value: summary.averageDistanceM <= 0
            ? '—'
            : '${(summary.averageDistanceM / 1000).toStringAsFixed(2)} км',
        note: '${players.length} игроков',
        icon: Icons.directions_run_rounded,
        tint: const Color(0xFFFFF7EF),
      ),
      const SizedBox(height: 7),
      _ReportCmrSection(
        title: 'Беговая работа',
        subtitle: 'объём, зоны и скоростные действия',
        icon: Icons.route_rounded,
        tint: const Color(0xFFFFF9F3),
        child: LayoutBuilder(builder: (context, c) {
          final compact = c.maxWidth < 620;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: compact ? 2 : (c.maxWidth >= 1180 ? 4 : 3),
              mainAxisExtent: compact ? 66 : 72,
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
            ),
            itemBuilder: (_, i) => _LocomotorSummaryTile(metric: metrics[i], index: i),
          );
        }),
      ),
      const SizedBox(height: 7),
      _ReportCmrSection(
        title: 'Игроки',
        subtitle: '${players.length} в выбранной тренировке',
        icon: Icons.groups_rounded,
        tint: const Color(0xFFF7FAF8),
        child: _LocomotorCards(players: players),
      ),
    ]);
  }
}

class _LocomotorSummaryTile extends StatelessWidget {
  const _LocomotorSummaryTile({required this.metric, required this.index});
  final _Metric metric;
  final int index;

  @override
  Widget build(BuildContext context) {
    final icons = <IconData>[
      Icons.route_rounded,
      Icons.speed_rounded,
      Icons.bolt_rounded,
      Icons.trending_up_rounded,
      Icons.directions_run_rounded,
      Icons.double_arrow_rounded,
      Icons.flash_on_rounded,
      Icons.sports_score_rounded,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(index == 0 || index == 3 ? .98 : .90),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: const Color(0xFFEAF8F0),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(icons[index % icons.length], color: _R.green, size: 13),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Text(metric.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _RText.caption(size: 9.5)),
              const SizedBox(height: 5),
              Text(metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _RText.value(15)),
              const SizedBox(height: 4),
              Text(metric.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _RText.body(9.5)),
            ])),
      ]),
    );
  }
}

class _MechanicalTab extends StatelessWidget {
  const _MechanicalTab({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report);
    final totalAcc = players.fold<int>(0, (s, p) => s + p.accelerations);
    final totalDec = players.fold<int>(0, (s, p) => s + p.decelerations);
    final totalExplosive = players.fold<int>(0, (s, p) => s + p.explosiveActions);
    final totalTurns = players.fold<int>(0, (s, p) => s + p.highSpeedActions);
    final metrics = <_Metric>[
      _Metric('Ускорения', '$totalAcc', 'за тренировку'),
      _Metric('Торможения', '$totalDec', 'за тренировку'),
      _Metric('Взрывные действия', '$totalExplosive', 'высокая интенсивность'),
      _Metric('Смены направления', '$totalTurns', 'за тренировку'),
    ];

    return _ScrollPage(children: [
      _ReportCmrHero(
        title: 'Механическая нагрузка',
        subtitle: 'ускорения, торможения и взрывные действия игроков',
        value: '${totalAcc + totalDec}',
        note: 'уск./торм.',
        icon: Icons.compare_arrows_rounded,
        tint: const Color(0xFFF1F6FF),
      ),
      const SizedBox(height: 7),
      _ReportCmrSection(
        title: 'Сводка механики',
        subtitle: 'ключевые действия выбранной тренировки',
        icon: Icons.speed_rounded,
        tint: const Color(0xFFF4F7FC),
        child: _CleanMetricGrid(metrics: metrics, icons: const [
          Icons.trending_up_rounded,
          Icons.trending_down_rounded,
          Icons.bolt_rounded,
          Icons.compare_arrows_rounded,
        ]),
      ),
      const SizedBox(height: 7),
      _ReportCmrSection(
        title: 'Игроки',
        subtitle: 'персональная механическая работа',
        icon: Icons.groups_rounded,
        tint: const Color(0xFFF7FAF8),
        child: _MechanicalPlayerCards(players: players),
      ),
      const SizedBox(height: 7),
      _ReportCmrSection(
        title: 'Сравнение механической работы',
        subtitle: 'ускорения и торможения по игрокам',
        icon: Icons.bar_chart_rounded,
        tint: const Color(0xFFF5F7FC),
        child: SizedBox(
          height: 220,
          child: _DualBarChart(
            players: players,
            first: (p) => p.accelerations.toDouble(),
            second: (p) => p.decelerations.toDouble(),
            firstLabel: 'Ускорения',
            secondLabel: 'Торможения',
          ),
        ),
      ),
    ]);
  }
}

class _MechanicalPlayerCards extends StatelessWidget {
  const _MechanicalPlayerCards({required this.players});
  final List<TrackerTrainingPlayerRow> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty)
      return const _EmptyBlock('Нет данных механической работы по игрокам.');
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 1050 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: players.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 126,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (_, i) => _MechanicalPlayerCard(player: players[i]),
      );
    });
  }
}

class _MechanicalPlayerCard extends StatelessWidget {
  const _MechanicalPlayerCard({required this.player});
  final TrackerTrainingPlayerRow player;

  @override
  Widget build(BuildContext context) {
    final values = <_Metric>[
      _Metric('Ускорения', '${player.accelerations}', 'действий'),
      _Metric('Торможения', '${player.decelerations}', 'действий'),
      _Metric('Взрывные', '${player.explosiveActions}', 'действий'),
      _Metric('Смена направления', '${player.highSpeedActions}', 'действий'),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _PlayerAvatar(player: player, size: 30),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _RText.body(11, color: _R.text, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                    [
                      if (player.number.isNotEmpty) '#${player.number}',
                      if (player.position.isNotEmpty) player.position
                    ].join(' · '),
                    style: _RText.body(9.5)),
              ])),
        ]),
        const SizedBox(height: 8),
        Expanded(
            child: Row(children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(child: _CleanMiniValue(metric: values[i])),
            if (i != values.length - 1) const SizedBox(width: 8),
          ],
        ])),
      ]),
    );
  }
}

class _InternalLoadTab extends StatelessWidget {
  const _InternalLoadTab({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    return _ScrollPage(children: [
      _SectionTitle('ВНУТРЕННЯЯ НАГРУЗКА'),
      _Card(
          title: 'АНАЛИЗ ПО ПУЛЬСУ И GPS',
          child: _HrRecommendations(report: report)),
      const SizedBox(height: 8),
      _ChartCard(
          title: 'ПУЛЬС ПО ВРЕМЕНИ / КРАСНАЯ НАГРУЗКА',
          child: _HeartRateTimelineChart(report: report)),
      const SizedBox(height: 8),
      _Card(
          title: 'ЗОНЫ ЧСС ПО ВРЕМЕНИ',
          child: SizedBox(height: 96, child: _HrZoneTimeStrip(report: report))),
      const SizedBox(height: 8),
      _TwoByTwo(
        a: _ChartCard(
            title: 'ИТОГ ПО ЗОНАМ ЧСС',
            child: _HrZoneSummaryBars(players: report.players)),
        b: _ChartCard(
            title: 'СРЕДНИЙ / МАКСИМАЛЬНЫЙ ПУЛЬС',
            child: _HrPlayerSummaryChart(players: report.players)),
        c: _ChartCard(
            title: 'СРЕДНИЙ % ОТ ЧСС МАКС',
            child: _BarChart(
                players: report.players,
                value: (p) => p.heartRateMaxPercent,
                label: '% ЧСС')),
        d: _ChartCard(
            title: 'НАПРЯЖЕНИЕ ПО ЧСС + НАГРУЗКА ИГРОКА',
            child: _DualBarChart(
                players: report.players,
                first: (p) => p.hrExertion,
                second: (p) => p.playerLoad,
                firstLabel: 'Напряжение по ЧСС',
                secondLabel: 'Нагрузка игрока')),
      ),
    ]);
  }
}

List<String> _reportCoachMessages(TrackerTrainingReport report) {
  final withHr =
      report.players.where((p) => p.heartRateSamplesCount > 0).toList();
  final messages = <String>[];
  if (withHr.isEmpty) {
    messages.add(
        'Нет данных кардиодатчика: подключите кардиодатчики, назначьте их игрокам и запустите Live-сессию — тогда отчёт совместит ЧСС с GPS-нагрузкой.');
  } else {
    final avgHr =
        withHr.map((p) => p.heartRateAvgBpm).fold<double>(0, (a, b) => a + b) /
            withHr.length;
    final maxHr =
        withHr.map((p) => p.heartRateMaxBpm).fold<double>(0, math.max);
    final highZone = withHr
        .where((p) =>
            (p.hrZ4Samples + p.hrZ5Samples) > (p.heartRateSamplesCount * .35))
        .toList();
    final highGpsLowHr = withHr
        .where((p) =>
            p.highSpeedWorkM > 250 &&
            p.heartRateAvgBpm > 0 &&
            p.heartRateAvgBpm < 135)
        .toList();
    final highHrLowGps = withHr
        .where((p) => p.heartRateAvgBpm >= 165 && p.distanceM < 500)
        .toList();
    messages.add(
        'Пульс есть у ${withHr.length} игрок(ов): средний ${avgHr.toStringAsFixed(0)} bpm, максимум ${maxHr.toStringAsFixed(0)} bpm.');
    if (highZone.isNotEmpty) {
      messages.add(
          'Контроль восстановления: ${highZone.map((p) => p.name).take(4).join(', ')} провели много времени в Z4/Z5 — после тренировки стоит проверить самочувствие и снизить повторную высокую нагрузку.');
    }
    if (highGpsLowHr.isNotEmpty) {
      messages.add(
          'Хорошая готовность: ${highGpsLowHr.map((p) => p.name).take(4).join(', ')} дали скоростную работу при умеренной ЧСС. Можно оставить их в основной группе.');
    }
    if (highHrLowGps.isNotEmpty) {
      messages.add(
          'Возможная усталость/стресс: ${highHrLowGps.map((p) => p.name).take(4).join(', ')} показывают высокую ЧСС при небольшой дистанции. Нужна проверка кардиодатчика, самочувствия и восстановления.');
    }
    if (messages.length == 1) {
      messages.add(
          'Критичных перекосов по ЧСС и GPS не видно: нагрузку можно оценивать по обычным метрикам дистанции, скорости, ускорений и зонам пульса.');
    }
  }
  return messages;
}

class _HrRecommendations extends StatelessWidget {
  const _HrRecommendations({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final messages = _reportCoachMessages(report);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages
            .map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.favorite_rounded,
                            color: _R.red, size: 15),
                        const SizedBox(width: 7),
                        Expanded(
                            child: Text(m,
                                style: const TextStyle(
                                    color: _R.text,
                                    fontSize: 11.2,
                                    height: 1.35,
                                    fontWeight: FontWeight.w700))),
                      ]),
                ))
            .toList());
  }
}

class _AiAnalysisTab extends StatelessWidget {
  const _AiAnalysisTab({
    required this.report,
    required this.clubId,
    required this.userId,
    required this.teamId,
    required this.teamName,
    this.personalSessionMode = false,
  });

  final TrackerTrainingReport report;
  final int clubId;
  final int userId;
  final int teamId;
  final String teamName;
  final bool personalSessionMode;

  List<TrackerTrainingPlayerRow> get _players =>
      _reportPlayers(report).toList(growable: false);

  int get _effectiveClubId => clubId > 0 ? clubId : report.clubId;
  int get _effectiveTeamId => teamId > 0 ? teamId : report.teamId;

  List<int> get _sessionIds {
    final result = <int>[];
    for (final id in <int>[report.sessionId, ...report.sessionIds]) {
      if (id > 0 && !result.contains(id)) result.add(id);
    }
    return result;
  }

  String _prompt() {
    final names = _players
        .map((p) => p.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final scope = names.isEmpty
        ? 'всей команды'
        : names.length == 1
            ? 'игрока ${names.first}'
            : '${names.length} выбранных игроков';
    if (personalSessionMode) {
      final playerLabel = names.isEmpty ? 'игрока' : 'игрока ${names.first}';
      return 'Проанализируй выбранную личную тренировку $playerLabel. '
          'Используй все session_ids из контекста как одну личную тренировку и только проверенные данные отчёта. '
          'Дай три коротких блока: «Что происходит», «Почему» и «Что делать игроку». '
          'Оцени GPS, скорость, спринты, ускорения/торможения и данные кардиодатчика, если они есть. '
          'Сформулируй понятные рекомендации игроку по нагрузке, восстановлению и следующей личной тренировке. '
          'Не добавляй тренерские заметки, оценки тренера или командные рекомендации.';
    }
    return 'Проанализируй выбранную групповую тренировку $scope. '
        'Используй все session_ids из контекста как одну тренировку и только проверенные данные отчёта. '
        'Дай три коротких блока: «Что происходит», «Почему» и «Что делать тренеру». '
        'Выдели отклонения по GPS, скорости, спринтам, ускорениям/торможениям и данным кардиодатчика, '
        'назови конкретных игроков, риски восстановления и рекомендации на следующую тренировку.';
  }

  Map<String, dynamic> _payload() {
    final players = _players;
    return <String, dynamic>{
      'source': 'tracker_analytics_inline',
      'scope': personalSessionMode
          ? 'personal_training_report'
          : (players.length == 1 ? 'player_report' : 'team_training_report'),
      'personal_session': personalSessionMode,
      'session_id': report.sessionId,
      'session_ids': _sessionIds,
      'team_id': _effectiveTeamId,
      if (_effectiveClubId > 0) 'club_id': _effectiveClubId,
      'team_name': teamName,
      'report_title': report.title,
      'report_date': report.dateLabel,
      'player_ids': players
          .map((p) => p.playerId)
          .whereType<int>()
          .where((id) => id > 0)
          .toList(growable: false),
      'player_names': players
          .map((p) => p.name.trim())
          .where((name) => name.isNotEmpty)
          .toList(growable: false),
      'verified_report_summary': <String, dynamic>{
        'players_count': players.length,
        'gps_points_count': report.routePoints.length,
        'heart_rate_samples_count': report.summary.heartRateSamplesCount,
        'total_distance_m': report.summary.totalDistanceM,
        'max_speed_kmh': report.summary.maxSpeedKmh,
        'sprint_count': report.summary.sprintCount,
        'acceleration_count': report.summary.accelerationCount,
        'deceleration_count': report.summary.decelerationCount,
        'heart_rate_avg_bpm': report.summary.heartRateAvgBpm,
        'heart_rate_max_bpm': report.summary.heartRateMaxBpm,
        'player_load': report.summary.playerLoad,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final players = _players;
    final singlePlayer = players.length == 1 ? players.first : null;
    final effectiveClubId = _effectiveClubId;
    final effectiveTeamId = _effectiveTeamId;
    // Club AI уже умеет открываться с clubId=0 и восстанавливать контекст
    // по пользователю/команде. Не блокируем личную тренировку старым маршрутом,
    // где clubId не был передан, если userId и teamId валидны.
    final contextReady = userId > 0 && effectiveTeamId > 0;

    if (!contextReady) {
      return _ScrollPage(children: [
        _SectionTitle('ИИ АНАЛИЗ ТРЕНИРОВКИ'),
        _Card(
          title: 'ПРОВЕРЕННАЯ СВОДКА',
          child: _ReportAiPlaceholder(report: report),
        ),
        const SizedBox(height: 8),
        _Card(
          title: 'КОНТЕКСТ НЕ ПЕРЕДАН',
          child: const _EmptyBlock(
            'Для серверного анализа нужны userId и teamId. Перезапустите раздел «Мои тренировки», чтобы восстановить контекст команды.',
          ),
        ),
      ]);
    }

    final assistant = CmrClubAiAssistantPanel(
      key: ValueKey(
        'inline_report_ai_${effectiveClubId}_${effectiveTeamId}_${_sessionIds.join('-')}_${players.map((p) => p.playerId ?? 0).join('-')}',
      ),
      clubId: effectiveClubId,
      userId: userId,
      teamId: effectiveTeamId,
      clubName: 'СПОРТОТЕКА',
      teamName: teamName,
      playerOnlyMode: personalSessionMode || singlePlayer != null,
      playerId: singlePlayer?.playerId,
      playerName: singlePlayer?.name,
      initialPrompt: _prompt(),
      initialPayload: _payload(),
      autoSendInitialPrompt: true,
    );
    final notes = personalSessionMode
        ? null
        : _AiCoachNotesPanel(
            report: report,
            clubId: effectiveClubId,
            teamId: effectiveTeamId,
            coachId: userId,
          );

    return ColoredBox(
      color: _R.bg,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (notes == null) {
              // В «Мои тренировки» это сессия самого игрока. Тренерский
              // журнал не показываем и отдаём всё доступное место диалогу ИИ.
              return assistant;
            }
            final wide = constraints.maxWidth >= 980;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 7, child: assistant),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: math.min(360.0, constraints.maxWidth * .31),
                    child: SingleChildScrollView(child: notes),
                  ),
                ],
              );
            }
            final notesHeight = math.min(300.0, constraints.maxHeight * .36);
            return Column(
              children: [
                Expanded(child: assistant),
                const SizedBox(height: 8),
                SizedBox(
                  height: notesHeight,
                  child: SingleChildScrollView(child: notes),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AiCoachNotesPanel extends StatefulWidget {
  const _AiCoachNotesPanel({
    required this.report,
    required this.clubId,
    required this.teamId,
    required this.coachId,
  });

  final TrackerTrainingReport report;
  final int clubId;
  final int teamId;
  final int coachId;

  @override
  State<_AiCoachNotesPanel> createState() => _AiCoachNotesPanelState();
}

class _AiCoachNotesPanelState extends State<_AiCoachNotesPanel> {
  int? _selectedPlayerId;

  List<TrackerTrainingPlayerRow> get _players => _reportPlayers(widget.report)
      .where((player) => (player.playerId ?? 0) > 0)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    if (_players.isNotEmpty) _selectedPlayerId = _players.first.playerId;
  }

  @override
  void didUpdateWidget(covariant _AiCoachNotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = _players.map((player) => player.playerId).toSet();
    if (!ids.contains(_selectedPlayerId)) {
      _selectedPlayerId = _players.isEmpty ? null : _players.first.playerId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = _players;
    final selectedId = _selectedPlayerId;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08111827),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.rate_review_rounded, color: _R.green, size: 18),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Журнал решений тренера',
                  style: TextStyle(
                    color: _R.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Оценка и заметка сохраняются для выбранной тренировки и игрока.',
            style: TextStyle(
              color: _R.muted,
              fontSize: 10.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (players.isEmpty)
            const _EmptyBlock('В отчёте нет игрока с подтверждённым player_id.')
          else ...[
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: players.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final player = players[index];
                  final active = player.playerId == selectedId;
                  return ChoiceChip(
                    selected: active,
                    onSelected: (_) =>
                        setState(() => _selectedPlayerId = player.playerId),
                    label: Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selectedColor: _R.softGreen,
                    side: BorderSide(
                      color: active ? _R.greenLine : _R.border,
                    ),
                    labelStyle: TextStyle(
                      color: active ? _R.greenDark : _R.graphite,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
            const SizedBox(height: 9),
            if (selectedId != null)
              TrackerCoachReviewCard(
                key: ValueKey(
                  'coach_review_${widget.report.sessionId}_$selectedId',
                ),
                clubId: widget.clubId,
                teamId: widget.teamId,
                sessionId: widget.report.sessionId,
                playerId: selectedId,
                coachId: widget.coachId,
              ),
          ],
        ],
      ),
    );
  }
}

class _ReportAiPlaceholder extends StatelessWidget {
  const _ReportAiPlaceholder({required this.report, this.compact = false});
  final TrackerTrainingReport report;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report);
    final withHr = players.where((p) => p.heartRateSamplesCount > 0).length;
    final withGps =
        players.where((p) => p.pointsCount > 0 || p.distanceM > 0).length;
    final localCoachMessages = _reportCoachMessages(report);
    final messages = <String>[
      'Проверено: ${players.length} игрок(ов), $withGps с GPS-данными, $withHr с кардиодатчиком, ${report.routePoints.length} точек маршрута.',
      ...localCoachMessages,
    ];
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
          color: const Color(0xFFFAFFFC),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _R.greenLine)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                  width: compact ? 30 : 38,
                  height: compact ? 30 : 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: _R.softGreen,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _R.greenLine)),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: _R.green, size: 15)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('СПОРТОТЕКА ИИ · локальная сводка',
                      style: TextStyle(
                          color: _R.text,
                          fontSize: compact ? 11.5 : 14,
                          fontWeight: FontWeight.w900))),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                      color: _R.softGreen,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _R.greenLine)),
                  child: const Text('ПРОВЕРЕННЫЕ МЕТРИКИ',
                      style: TextStyle(
                          color: _R.greenDark,
                          fontSize: 8.6,
                          fontWeight: FontWeight.w900))),
            ]),
            SizedBox(height: compact ? 8 : 12),
            for (final m in messages.take(compact ? 2 : 3)) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_rounded,
                    color: _R.green, size: 15),
                const SizedBox(width: 7),
                Expanded(
                    child: Text(m,
                        style: TextStyle(
                            color: _R.graphite,
                            fontSize: compact ? 9.5 : 10.8,
                            height: 1.32,
                            fontWeight: FontWeight.w800))),
              ]),
              if (m != messages.take(compact ? 2 : 3).last)
                SizedBox(height: compact ? 5 : 8),
            ],
          ]),
    );
  }
}

class _AiInputMatrix extends StatelessWidget {
  const _AiInputMatrix({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final rows = <_Metric>[
      _Metric(
          'Кардиодатчик', '${report.summary.heartRateSamplesCount}', 'HR-точек'),
      _Metric(
          'Игроки', '${_reportPlayers(report).length}', 'персональные блоки'),
      _Metric(
          'Спринты', '${report.summary.sprintCount}', 'скоростные действия'),
      _Metric(
          'Уск/торм',
          '${report.summary.accelerationCount}/${report.summary.decelerationCount}',
          'механика'),
    ];
    return _MetricsWrap(metrics: rows);
  }
}

class _AiPlayerSignals extends StatelessWidget {
  const _AiPlayerSignals({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final players = _reportPlayers(report).toList(growable: false)
      ..sort((a, b) => (b.playerLoad + b.distanceM / 10 + b.heartRateAvgBpm)
          .compareTo(a.playerLoad + a.distanceM / 10 + a.heartRateAvgBpm));
    if (players.isEmpty)
      return const _EmptyBlock(
          'ИИ-сигналы появятся после появления игроков в отчёте.');
    return Column(children: [
      for (final p in players.take(8)) ...[
        Row(children: [
          _PlayerAvatar(player: p, size: 30),
          const SizedBox(width: 7),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.text,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900)),
                Text(_aiSignalText(p),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _R.muted,
                        fontSize: 9.2,
                        height: 1.25,
                        fontWeight: FontWeight.w800)),
              ])),
        ]),
        if (p != players.take(8).last)
          const Divider(height: 14, color: _R.border),
      ],
    ]);
  }

  String _aiSignalText(TrackerTrainingPlayerRow p) {
    if (p.heartRateAvgBpm >= 165 && p.distanceM < 500)
      return 'высокая ЧСС при небольшом объёме — проверить восстановление и посадку кардиодатчика';
    if (p.maxSpeedKmh >= 18 || p.sprintCount > 0)
      return 'есть скоростная работа: ${p.sprintCount} спринт(ов), max ${p.maxSpeedKmh.toStringAsFixed(1)} км/ч';
    if (p.distanceM <= 1 && p.pointsCount <= 0)
      return 'нет подтверждённого GPS-движения — не использовать для итоговой оценки нагрузки';
    if (p.heartRateSamplesCount > 0)
      return 'Кардиодатчик активен: средняя ${p.heartRateAvgBpm.toStringAsFixed(0)} уд/мин, максимум ${p.heartRateMaxBpm.toStringAsFixed(0)} уд/мин';
    return 'базовая GPS-нагрузка: ${p.distanceM.toStringAsFixed(0)} м, load ${p.playerLoad.toStringAsFixed(0)}';
  }
}

class _MicrocycleTab extends StatelessWidget {
  const _MicrocycleTab({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final points = report.microcycle;
    final avgDistance = points.isEmpty
        ? 0.0
        : points.fold<double>(0, (s, p) => s + p.distanceM) / points.length;
    final avgHsr = points.isEmpty
        ? 0.0
        : points.fold<double>(0, (s, p) => s + p.highSpeedRunningM) /
            points.length;
    final avgAccDec = points.isEmpty
        ? 0.0
        : points.fold<double>(0, (s, p) => s + p.accDec) / points.length;
    final maxDistance =
        points.isEmpty ? 0.0 : points.map((p) => p.distanceM).reduce(math.max);
    final metrics = <_Metric>[
      _Metric('Дней в микроцикле', '${points.length}', 'в выбранном периоде'),
      _Metric('Средняя дистанция', avgDistance.toStringAsFixed(0), 'м за день'),
      _Metric('Средний HSR', avgHsr.toStringAsFixed(0), 'м за день'),
      _Metric('Уск. + торм.', avgAccDec.toStringAsFixed(0), 'в среднем'),
      _Metric('Пиковая дистанция', maxDistance.toStringAsFixed(0), 'м за день'),
    ];

    return _ScrollPage(children: [
      _CleanReportHeader(
        title: 'Микроцикл',
        subtitle: 'Динамика нагрузки по дням тренировочного цикла',
      ),
      _CleanMetricGrid(metrics: metrics, icons: const [
        Icons.calendar_view_week_rounded,
        Icons.route_rounded,
        Icons.directions_run_rounded,
        Icons.compare_arrows_rounded,
        Icons.workspace_premium_rounded,
      ]),
      const SizedBox(height: 8),
      _CleanChartPanel(
        title: 'Динамика нагрузки',
        subtitle: 'Дистанция, высокоинтенсивный бег и механическая работа',
        child: SizedBox(height: 220, child: _MicrocycleChart(points: points)),
      ),
      const SizedBox(height: 10),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('Дни микроцикла',
            style: TextStyle(
                color: _R.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: -.3)),
      ),
      const SizedBox(height: 8),
      _MicrocycleDayCards(points: points),
    ]);
  }
}

class _MicrocycleDayCards extends StatelessWidget {
  const _MicrocycleDayCards({required this.points});
  final List<TrackerMicrocyclePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty)
      return const _EmptyBlock(
          'Микроцикл появится после нескольких реальных сессий команды.');
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 680 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: points.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 112,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (_, i) => _MicrocycleDayCard(point: points[i], index: i),
      );
    });
  }
}

class _MicrocycleDayCard extends StatelessWidget {
  const _MicrocycleDayCard({required this.point, required this.index});
  final TrackerMicrocyclePoint point;
  final int index;

  @override
  Widget build(BuildContext context) {
    final metrics = <_Metric>[
      _Metric('Дистанция', point.distanceM.toStringAsFixed(0), 'м'),
      _Metric('HSR', point.highSpeedRunningM.toStringAsFixed(0), 'м'),
      _Metric('Уск. + торм.', point.accDec.toStringAsFixed(0), 'действий'),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: index == 0 ? const Color(0xFFF1FBF5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: _R.softGreen, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.calendar_today_rounded,
                  color: _R.green, size: 15)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  point.label.isEmpty ? 'День ${index + 1}' : point.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _R.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 8),
        Expanded(
            child: Row(children: [
          for (var i = 0; i < metrics.length; i++) ...[
            Expanded(child: _CleanMiniValue(metric: metrics[i])),
            if (i != metrics.length - 1) const SizedBox(width: 8),
          ],
        ])),
      ]),
    );
  }
}

class _CleanReportHeader extends StatelessWidget {
  const _CleanReportHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _RText.title(14)),
          const SizedBox(height: 5),
          Text(subtitle, style: _RText.body(9.5)),
        ]),
      );
}

class _CleanMetricGrid extends StatelessWidget {
  const _CleanMetricGrid({required this.metrics, required this.icons});
  final List<_Metric> metrics;
  final List<IconData> icons;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final columns = c.maxWidth >= 1120 ? 4 : (c.maxWidth >= 700 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 72,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
          ),
          itemBuilder: (_, i) =>
              _LocomotorSummaryTile(metric: metrics[i], index: i),
        );
      });
}

class _CleanChartPanel extends StatelessWidget {
  const _CleanChartPanel(
      {required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _RText.title(14)),
          const SizedBox(height: 4),
          Text(subtitle, style: _RText.body(9.5)),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

class _CleanMiniValue extends StatelessWidget {
  const _CleanMiniValue({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
            color: const Color(0xFFF7F9F8),
            borderRadius: BorderRadius.circular(9)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(metric.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _RText.caption(size: 9.5)),
              const SizedBox(height: 5),
              Text(metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _RText.value(14)),
              const SizedBox(height: 2),
              Text(metric.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _RText.body(9.5)),
            ]),
      );
}

class _ScrollPage extends StatelessWidget {
  const _ScrollPage({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(6),
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
    return LayoutBuilder(builder: (context, constraints) {
      final boundedHeight = constraints.maxHeight.isFinite;
      final body = Padding(padding: const EdgeInsets.all(8), child: child);
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_R.mobileInnerRadius),
            border: Border.all(color: _R.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
                color: _R.soft,
                border: Border(bottom: BorderSide(color: _R.border))),
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5)),
          ),
          if (boundedHeight) Expanded(child: body) else body,
        ]),
      );
    });
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
          child: Text(text,
              style: const TextStyle(
                  color: _R.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .1))),
    );
  }
}

class _MetricsWrap extends StatelessWidget {
  const _MetricsWrap({required this.metrics});
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 460;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: metrics.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: compact ? 176 : 190,
          mainAxisExtent: compact ? 62 : 72,
          crossAxisSpacing: compact ? 7 : 8,
          mainAxisSpacing: compact ? 7 : 8,
        ),
        itemBuilder: (_, i) => _MetricTile(metric: metrics[i]),
      );
    });
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
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 150;
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _R.border),
          borderRadius: BorderRadius.circular(_R.mobileInnerRadius),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 7, vertical: compact ? 4 : 5),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(metric.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: _R.muted,
                      fontSize: compact ? 6.8 : 7.4,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .15)),
              SizedBox(height: compact ? 1 : 2),
              FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(metric.value,
                      maxLines: 1,
                      style: TextStyle(
                          color: _R.text,
                          fontSize: compact ? 12.5 : 14.0,
                          fontWeight: FontWeight.w900))),
              Text(metric.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: _R.muted,
                      fontSize: compact ? 7.0 : 7.6,
                      fontWeight: FontWeight.w800)),
            ]),
      );
    });
  }
}

class _PeriodsTable extends StatelessWidget {
  const _PeriodsTable({required this.periods});
  final List<TrackerExercisePeriod> periods;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty)
      return const _EmptyBlock(
          'Периоды пока не сохранены. Используйте + Период в Live.');
    return Table(
      border: TableBorder.all(color: _R.border),
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(.9),
        4: FlexColumnWidth(.9)
      },
      children: [
        _tableRow(['Упражнение', 'Начало', 'Конец', 'Дист.', 'Уск/торм'],
            header: true),
        ...periods.map((p) => _tableRow([
              p.title,
              p.startLabel,
              p.endLabel,
              '${p.distanceM.toStringAsFixed(0)} м',
              '${p.accDecCount}'
            ])),
      ],
    );
  }
}

class _LocomotorCards extends StatelessWidget {
  const _LocomotorCards({required this.players});
  final List<TrackerTrainingPlayerRow> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const _EmptyBlock('Нет игроков в отчёте.');
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 560;
      final twoColumns = c.maxWidth >= 820;
      final cards = [...players, _avgRow(players)];
      if (compact || !twoColumns) {
        return Column(children: [
          for (var i = 0; i < cards.length; i++) ...[
            _LocomotorPlayerCard(
                player: cards[i],
                average: cards[i].name == 'СРЕДНЕЕ',
                compact: compact),
            if (i != cards.length - 1) const SizedBox(height: 8),
          ],
        ]);
      }
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 154,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (_, i) => _LocomotorPlayerCard(
            player: cards[i], average: cards[i].name == 'СРЕДНЕЕ'),
      );
    });
  }
}

class _LocomotorPlayerCard extends StatelessWidget {
  const _LocomotorPlayerCard(
      {required this.player, required this.average, this.compact = false});
  final TrackerTrainingPlayerRow player;
  final bool average;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final metrics = <_MiniMetricData>[
      _MiniMetricData('Дистанция', '${player.distanceM.toStringAsFixed(0)} м'),
      _MiniMetricData(
          'Интенсивность', '${player.metersPerMin.toStringAsFixed(1)} м/мин'),
      _MiniMetricData(
          'Средняя скорость', '${player.avgSpeedKmh.toStringAsFixed(1)} км/ч'),
      _MiniMetricData(
          'Макс. скорость', '${player.maxSpeedKmh.toStringAsFixed(1)} км/ч'),
      _MiniMetricData('Ускорения', '${player.accelerations}'),
      _MiniMetricData('Торможения', '${player.decelerations}'),
      _MiniMetricData('Спринты', '${player.sprintCount}'),
      _MiniMetricData('GPS-точки', '${player.pointsCount}'),
    ];
    return Container(
      height: compact ? null : 154,
      padding: EdgeInsets.all(compact ? 10 : 11),
      decoration: BoxDecoration(
        color: average ? const Color(0xFFF1FBF5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (!average) ...[
            _PlayerAvatar(player: player, size: compact ? 38 : 40),
            const SizedBox(width: 11)
          ],
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(average ? 'Средние показатели' : player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _RText.body(11, color: _R.text, weight: FontWeight.w600)),
                if (!average) ...[
                  const SizedBox(height: 3),
                  Text(
                      [
                        if (player.number.isNotEmpty) '#${player.number}',
                        if (player.position.isNotEmpty) player.position
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _RText.body(9.5)),
                ],
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFF3F6F4),
                borderRadius: BorderRadius.circular(999)),
            child: Text(player.duration,
                style: _RText.body(9.5, color: _R.graphite, weight: FontWeight.w600)),
          ),
        ]),
        SizedBox(height: compact ? 11 : 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: compact ? 2 : 4,
            mainAxisExtent: compact ? 48 : 42,
            crossAxisSpacing: 7,
            mainAxisSpacing: 7,
          ),
          itemBuilder: (_, i) => _MiniMetric(data: metrics[i]),
        ),
      ]),
    );
  }
}

class _MiniMetricData {
  const _MiniMetricData(this.label, this.value);
  final String label;
  final String value;
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({this.data, this.label, this.value})
      : assert(data != null || (label != null && value != null));

  final _MiniMetricData? data;
  final String? label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final metricLabel = data?.label ?? label ?? '';
    final metricValue = data?.value ?? value ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F8F6),
          borderRadius: BorderRadius.circular(9)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(metricLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.muted,
                    fontSize: 7.8,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(metricValue,
                    maxLines: 1,
                    style: const TextStyle(
                        color: _R.text,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w900))),
          ]),
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
    return SingleChildScrollView(
      primary: false,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1680,
        child: Table(
          border: TableBorder.all(color: const Color(0xFFD0D5DD)),
          columnWidths: const {
            0: FlexColumnWidth(2.8),
            1: FlexColumnWidth(1.1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
            4: FlexColumnWidth(1),
            5: FlexColumnWidth(1),
            6: FlexColumnWidth(.8),
            7: FlexColumnWidth(.8),
            8: FlexColumnWidth(.9),
            9: FlexColumnWidth(.9),
            10: FlexColumnWidth(1),
            11: FlexColumnWidth(1),
            12: FlexColumnWidth(1),
            13: FlexColumnWidth(.8),
            14: FlexColumnWidth(1),
            15: FlexColumnWidth(.8),
            16: FlexColumnWidth(.8),
          },
          children: [
            _tableRow([
              'Игрок',
              'Время',
              'Дист. м',
              'м/мин',
              'Ср. км/ч',
              'Макс.',
              'Уск.',
              'Торм.',
              'УСК+ТОР',
              'Взрыв.',
              'V3 бег',
              'V4 ВСБ',
              'V5 спринт',
              'Спр.',
              'V4+V5',
              'Действ.',
              'GPS'
            ], header: true),
            ...rows.map((p) => _playerRow(p, p.name == 'СРЕДНЕЕ')),
          ],
        ),
      ),
    );
  }

  TableRow _playerRow(TrackerTrainingPlayerRow p, bool avg) {
    return TableRow(
      decoration:
          BoxDecoration(color: avg ? const Color(0xFFE1E5E2) : Colors.white),
      children: [
        _playerCell(p, avg),
        _cell(p.duration),
        _heatCell(p.distanceM.toStringAsFixed(0), p.distanceM, 4500),
        _heatCell(p.metersPerMin.toStringAsFixed(1), p.metersPerMin, 130),
        _heatCell(p.avgSpeedKmh.toStringAsFixed(1), p.avgSpeedKmh, 16),
        _heatCell(p.maxSpeedKmh.toStringAsFixed(1), p.maxSpeedKmh, 30),
        _barCell(
            '${p.accelerations}', p.accelerations.toDouble(), 24, _R.green),
        _barCell('${p.decelerations}', p.decelerations.toDouble(), 28, _R.red),
        _heatCell(p.accDecPerMin.toStringAsFixed(1), p.accDecPerMin, 3),
        _barCell(
            '${p.explosiveActions}', p.explosiveActions.toDouble(), 30, _R.red),
        _heatCell(p.v3RunM.toStringAsFixed(0), p.v3RunM, 1300),
        _heatCell(p.v4HsrM.toStringAsFixed(0), p.v4HsrM, 450),
        _heatCell(p.v5SprintM.toStringAsFixed(0), p.v5SprintM, 110),
        _cell('${p.sprintCount}'),
        _heatCell(p.highSpeedWorkM.toStringAsFixed(0), p.highSpeedWorkM, 550),
        _cell('${p.highSpeedActions}'),
        _cell('${p.pointsCount}'),
      ],
    );
  }
}

class _TwoByTwo extends StatelessWidget {
  const _TwoByTwo(
      {required this.a, required this.b, required this.c, required this.d});
  final Widget a;
  final Widget b;
  final Widget c;
  final Widget d;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 640;
      if (!wide) {
        return Column(children: [
          a,
          const SizedBox(height: 8),
          b,
          const SizedBox(height: 8),
          c,
          const SizedBox(height: 8),
          d
        ]);
      }
      return Column(children: [
        Row(children: [
          Expanded(child: a),
          const SizedBox(width: 7),
          Expanded(child: b)
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: c),
          const SizedBox(width: 7),
          Expanded(child: d)
        ]),
      ]);
    });
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      _Card(title: title, child: SizedBox(height: 320, child: child));
}

class _BarChart extends StatelessWidget {
  const _BarChart(
      {required this.players, required this.value, required this.label});
  final List<TrackerTrainingPlayerRow> players;
  final double Function(TrackerTrainingPlayerRow) value;
  final String label;
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _BarChartPainter(players: players, value: value, label: label),
      child: const SizedBox.expand());
}

class _DualBarChart extends StatelessWidget {
  const _DualBarChart(
      {required this.players,
      required this.first,
      required this.second,
      required this.firstLabel,
      required this.secondLabel});
  final List<TrackerTrainingPlayerRow> players;
  final double Function(TrackerTrainingPlayerRow) first;
  final double Function(TrackerTrainingPlayerRow) second;
  final String firstLabel;
  final String secondLabel;
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _DualBarChartPainter(
          players: players,
          first: first,
          second: second,
          firstLabel: firstLabel,
          secondLabel: secondLabel),
      child: const SizedBox.expand());
}

class _HeartRateTimelineChart extends StatelessWidget {
  const _HeartRateTimelineChart({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final points = _reportHrTimeline(report);
    if (points.isEmpty)
      return const _EmptyBlock(
          'ЧСС по времени не найдена. Проверьте, что кардиодатчик был привязан к игроку и сессия завершена.');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ReportHrTimelineLegend(report: report, points: points),
      const SizedBox(height: 6),
      Expanded(
        child: ClipRect(
          child: CustomPaint(
            painter: _HeartRateTimelinePainter(points: points),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ]);
  }
}

class _ReportHrTimelineLegend extends StatelessWidget {
  const _ReportHrTimelineLegend({required this.report, required this.points});
  final TrackerTrainingReport report;
  final List<TrackerHeartRatePoint> points;

  @override
  Widget build(BuildContext context) {
    final names = <String>[];
    for (final p in points) {
      final name = p.playerName.trim();
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
    }
    final sorted = [...points]
      ..sort((a, b) => _hrPointSortKey(a).compareTo(_hrPointSortKey(b)));
    final from = sorted.isEmpty ? 0 : _hrPointSortKey(sorted.first);
    final to = sorted.isEmpty ? 0 : _hrPointSortKey(sorted.last);
    final durationMin = math.max(1, ((to - from).abs() / 60000).round());
    final sessionLabel = report.sessionIds.isNotEmpty
        ? report.sessionIds.map((id) => '#$id').join(', ')
        : '#${report.sessionId}';
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
          color: _R.soft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _R.border)),
      child: Row(children: [
        const Icon(Icons.monitor_heart_rounded, color: _R.red, size: 16),
        const SizedBox(width: 7),
        Expanded(
            child: Text(
                '$sessionLabel · ${names.isEmpty ? 'команда' : names.take(5).join(', ')}${names.length > 5 ? ' +${names.length - 5}' : ''} · $durationMin мин',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w900))),
        Text('${points.length} HR',
            style: const TextStyle(
                color: _R.muted, fontSize: 9.4, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _HrZoneTimeStrip extends StatelessWidget {
  const _HrZoneTimeStrip({required this.report});
  final TrackerTrainingReport report;

  @override
  Widget build(BuildContext context) {
    final points = _reportHrTimeline(report);
    if (points.isEmpty)
      return const _EmptyBlock('Зоны ЧСС по времени пока не найдены.');
    return ClipRect(
      child: CustomPaint(
        painter: _HrZoneTimeStripPainter(points: points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HrZoneSummaryBars extends StatelessWidget {
  const _HrZoneSummaryBars({required this.players});
  final List<TrackerTrainingPlayerRow> players;

  @override
  Widget build(BuildContext context) {
    final withHr = players
        .where((p) => p.heartRateSamplesCount > 0)
        .toList(growable: false);
    if (withHr.isEmpty)
      return const _EmptyBlock('Нет записей кардиодатчика для выбранных игроков.');
    final totals = <int>[
      withHr.fold<int>(0, (a, p) => a + p.hrZ1Samples),
      withHr.fold<int>(0, (a, p) => a + p.hrZ2Samples),
      withHr.fold<int>(0, (a, p) => a + p.hrZ3Samples),
      withHr.fold<int>(0, (a, p) => a + p.hrZ4Samples),
      withHr.fold<int>(0, (a, p) => a + p.hrZ5Samples),
    ];
    final total = totals.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return const _EmptyBlock('Зоны ЧСС не рассчитаны.');
    const names = [
      'Z1 восстановление',
      'Z2 лёгкая',
      'Z3 рабочая',
      'Z4 высокая',
      'Z5 пик'
    ];
    const colors = [
      Color(0xFFA3E635),
      Color(0xFF84CC16),
      Color(0xFFFACC15),
      Color(0xFFF97316),
      Color(0xFFE11D48)
    ];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < totals.length; i++) ...[
            _HrZoneSummaryRow(
                label: names[i],
                color: colors[i],
                value: totals[i],
                total: total),
            if (i != totals.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _HrZoneSummaryRow extends StatelessWidget {
  const _HrZoneSummaryRow(
      {required this.label,
      required this.color,
      required this.value,
      required this.total});
  final String label;
  final Color color;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0).toDouble();
    final seconds =
        value; // Кардиодатчик обычно сохраняет одну HR-точку в секунду; при другой частоте процент остаётся корректным.
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return Row(children: [
      SizedBox(
          width: 118,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _R.text, fontSize: 10, fontWeight: FontWeight.w900))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(children: [
            Container(height: 13, color: const Color(0xFFF3F4F6)),
            FractionallySizedBox(
                widthFactor: ratio, child: Container(height: 13, color: color)),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
          width: 74,
          child: Text(
              '${min}:${sec.toString().padLeft(2, '0')} · ${(ratio * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: _R.muted,
                  fontSize: 10.4,
                  fontWeight: FontWeight.w900))),
    ]);
  }
}

class _HrPlayerSummaryChart extends StatelessWidget {
  const _HrPlayerSummaryChart({required this.players});
  final List<TrackerTrainingPlayerRow> players;

  @override
  Widget build(BuildContext context) {
    final list = players
        .where((p) => p.heartRateSamplesCount > 0)
        .take(12)
        .toList(growable: false);
    if (list.isEmpty)
      return const _EmptyBlock('По выбранным игрокам нет данных ЧСС.');
    return ClipRect(
        child: CustomPaint(
            painter: _HrPlayerSummaryPainter(players: list),
            child: const SizedBox.expand()));
  }
}

List<TrackerHeartRatePoint> _reportHrTimeline(TrackerTrainingReport report) {
  if (report.heartRateTimeline.isNotEmpty) return report.heartRateTimeline;
  final players = report.players
      .where((p) => p.heartRateSamplesCount > 0 && p.heartRateAvgBpm > 0)
      .take(12)
      .toList(growable: false);
  if (players.isEmpty) return const <TrackerHeartRatePoint>[];
  final out = <TrackerHeartRatePoint>[];
  for (var i = 0; i < players.length; i++) {
    final p = players[i];
    out.add(TrackerHeartRatePoint(
        playerId: p.playerId,
        playerName: p.name,
        timeMs: 0,
        minute: i,
        bpm: p.heartRateAvgBpm.round(),
        hrLoad: p.hrExertion,
        zone: _zoneFromBpm(p.heartRateAvgBpm.round())));
    if (p.heartRateMaxBpm > p.heartRateAvgBpm) {
      out.add(TrackerHeartRatePoint(
          playerId: p.playerId,
          playerName: p.name,
          timeMs: 0,
          minute: i + 1,
          bpm: p.heartRateMaxBpm.round(),
          hrLoad: p.hrExertion,
          zone: _zoneFromBpm(p.heartRateMaxBpm.round())));
    }
  }
  return out;
}

String _zoneFromBpm(int bpm) {
  if (bpm >= 180) return 'z5';
  if (bpm >= 160) return 'z4';
  if (bpm >= 140) return 'z3';
  if (bpm >= 120) return 'z2';
  return 'z1';
}

Color _hrZoneColor(String zone) {
  switch (zone.toLowerCase()) {
    case 'z5':
      return const Color(0xFFE11D48);
    case 'z4':
      return const Color(0xFFF97316);
    case 'z3':
      return const Color(0xFFFACC15);
    case 'z2':
      return const Color(0xFF84CC16);
    default:
      return const Color(0xFFA3E635);
  }
}

int _hrPointSortKey(TrackerHeartRatePoint p) =>
    p.timeMs > 0 ? p.timeMs : p.minute * 60000;

String _hrPointGroupKey(TrackerHeartRatePoint p) {
  final name = p.playerName.trim();
  final id = p.playerId;
  if (id != null && id > 0) return 'id:$id';
  return 'name:${name.isEmpty ? 'team' : name}';
}

List<List<TrackerHeartRatePoint>> _hrPointGroups(
    List<TrackerHeartRatePoint> points) {
  final map = <String, List<TrackerHeartRatePoint>>{};
  for (final p in points.where((p) => p.bpm > 0)) {
    map
        .putIfAbsent(_hrPointGroupKey(p), () => <TrackerHeartRatePoint>[])
        .add(p);
  }
  final groups = map.values.toList(growable: false);
  for (final g in groups) {
    g.sort((a, b) => _hrPointSortKey(a).compareTo(_hrPointSortKey(b)));
  }
  groups.sort((a, b) => (a.first.playerName).compareTo(b.first.playerName));
  return groups;
}

Color _reportSeriesColor(int index) {
  const colors = <Color>[
    _R.red,
    _R.green,
    Color(0xFFF59E0B),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF0F766E),
  ];
  return colors[index % colors.length];
}

class _HeartRateTimelinePainter extends _BaseChartPainter {
  _HeartRateTimelinePainter({required this.points});
  final List<TrackerHeartRatePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final list = points.where((p) => p.bpm > 0).toList(growable: false);
    if (list.isEmpty) return;
    final rect = Rect.fromLTWH(52, 30, math.max(10.0, size.width - 86),
        math.max(10.0, size.height - 86));
    final clip = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.save();
    canvas.clipPath(clip);
    drawGrid(canvas, rect);

    final minX = list
        .map(_hrPointSortKey)
        .fold<int>(_hrPointSortKey(list.first), (a, b) => a < b ? a : b)
        .toDouble();
    var maxX = list
        .map(_hrPointSortKey)
        .fold<int>(_hrPointSortKey(list.first), (a, b) => a > b ? a : b)
        .toDouble();
    if ((maxX - minX).abs() < 1) maxX = minX + 60000;
    final minBpm = math.max(
        40.0,
        list
                .map((p) => p.bpm)
                .fold<int>(list.first.bpm, (a, b) => a < b ? a : b)
                .toDouble() -
            10);
    final maxBpm = math.max(
        130.0,
        list
                .map((p) => p.bpm)
                .fold<int>(list.first.bpm, (a, b) => a > b ? a : b)
                .toDouble() +
            14);
    for (var i = 0; i <= 4; i++) {
      final y = rect.bottom - rect.height * i / 4;
      final bpm = minBpm + (maxBpm - minBpm) * i / 4;
      text(canvas, bpm.round().toString(), Offset(8, y - 7),
          size: 9, color: _R.muted, weight: FontWeight.w800, maxWidth: 36);
    }
    final timelineMs = math.max(60000.0, maxX - minX);
    for (var i = 0; i <= 4; i++) {
      final x = rect.left + rect.width * i / 4;
      text(canvas, _reportElapsedLabel((timelineMs * i / 4).round()),
          Offset(x - (i == 0 ? 0 : 18), rect.bottom + 10),
          size: 9, color: _R.muted, weight: FontWeight.w800, maxWidth: 48);
    }
    text(canvas, 'ЧСС, уд/мин', Offset(rect.left, 0),
        size: 10.5, color: _R.text, weight: FontWeight.w900, maxWidth: 120);
    text(canvas, 'время', Offset(rect.right - 34, size.height - 15),
        size: 9, color: _R.muted, weight: FontWeight.w800, maxWidth: 40);
    Offset mapPoint(TrackerHeartRatePoint p, double yValue) {
      final x = rect.left +
          rect.width *
              ((_hrPointSortKey(p) - minX) / (maxX - minX))
                  .clamp(0.0, 1.0)
                  .toDouble();
      final y = rect.bottom -
          rect.height *
              ((yValue - minBpm) / (maxBpm - minBpm))
                  .clamp(0.0, 1.0)
                  .toDouble();
      return Offset(x, y);
    }

    for (final z in [120, 140, 160, 180]) {
      if (z < minBpm || z > maxBpm) continue;
      final y = rect.bottom -
          rect.height *
              ((z - minBpm) / (maxBpm - minBpm)).clamp(0.0, 1.0).toDouble();
      final color = z >= 180
          ? const Color(0xFFE11D48)
          : (z >= 160
              ? const Color(0xFFF97316)
              : (z >= 140 ? const Color(0xFFFACC15) : const Color(0xFF84CC16)));
      canvas.drawLine(
          Offset(rect.left, y),
          Offset(rect.right, y),
          Paint()
            ..color = color.withOpacity(.55)
            ..strokeWidth = 1.2);
      text(
          canvas,
          'Z${z == 120 ? 2 : z == 140 ? 3 : z == 160 ? 4 : 5}',
          Offset(rect.right - 28, y - 16),
          size: 9.5,
          color: color,
          weight: FontWeight.w900,
          maxWidth: 28);
    }

    final groups = _hrPointGroups(list);
    for (var gi = 0; gi < groups.length; gi++) {
      final group = groups[gi];
      if (group.isEmpty) continue;
      final lineColor = groups.length == 1 ? _R.red : _reportSeriesColor(gi);
      final bpmPath = Path();
      final loadPath = Path();
      var first = true;
      for (final p in group) {
        final bp = mapPoint(p, p.bpm.toDouble());
        final lp = mapPoint(
            p,
            minBpm +
                (maxBpm - minBpm) *
                    (p.hrLoad.clamp(0, 200).toDouble() / 200.0));
        if (first) {
          bpmPath.moveTo(bp.dx, bp.dy);
          loadPath.moveTo(lp.dx, lp.dy);
          first = false;
        } else {
          bpmPath.lineTo(bp.dx, bp.dy);
          loadPath.lineTo(lp.dx, lp.dy);
        }
      }
      canvas.drawPath(
          loadPath,
          Paint()
            ..color = const Color(0xFF7F1D1D)
                .withOpacity(groups.length == 1 ? .38 : .16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round);
      canvas.drawPath(
          bpmPath,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = groups.length == 1 ? 3.0 : 2.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);

      final every =
          math.max(1, (group.length / (groups.length == 1 ? 8 : 4)).ceil());
      for (var i = 0; i < group.length; i += every) {
        final p = group[i];
        final o = mapPoint(p, p.bpm.toDouble());
        canvas.drawCircle(o, 4.6, Paint()..color = _hrZoneColor(p.zone));
        canvas.drawCircle(
            o, 7.8, Paint()..color = _hrZoneColor(p.zone).withOpacity(.08));
        text(canvas, '${p.bpm}', o + const Offset(-10, -22),
            size: 9, color: lineColor, weight: FontWeight.w900, maxWidth: 36);
      }
      if (groups.length > 1) {
        final p = group.first;
        final o = mapPoint(p, p.bpm.toDouble());
        text(
            canvas,
            _shortReportPlayerName(
                p.playerName.isEmpty ? 'Игрок' : p.playerName),
            o + const Offset(5, 7),
            size: 8,
            color: lineColor,
            weight: FontWeight.w900,
            maxWidth: 80);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeartRateTimelinePainter oldDelegate) =>
      oldDelegate.points != points;
}

class _HrZoneTimeStripPainter extends _BaseChartPainter {
  _HrZoneTimeStripPainter({required this.points});
  final List<TrackerHeartRatePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final list = points.where((p) => p.bpm > 0).toList(growable: false);
    if (list.isEmpty) return;
    final rect = Rect.fromLTWH(58, 30, math.max(20.0, size.width - 96), 22);
    int xKey(TrackerHeartRatePoint p) =>
        p.timeMs > 0 ? p.timeMs : p.minute * 60000;
    final minX = list
        .map(xKey)
        .fold<int>(xKey(list.first), (a, b) => a < b ? a : b)
        .toDouble();
    var maxX = list
        .map(xKey)
        .fold<int>(xKey(list.first), (a, b) => a > b ? a : b)
        .toDouble();
    if ((maxX - minX).abs() < 1) maxX = minX + 60000;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(999)),
        Paint()..color = const Color(0xFFF3F4F6));
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final x1 = rect.left +
          rect.width *
              ((xKey(p) - minX) / (maxX - minX)).clamp(0.0, 1.0).toDouble();
      final x2 = i + 1 < list.length
          ? rect.left +
              rect.width *
                  ((xKey(list[i + 1]) - minX) / (maxX - minX))
                      .clamp(0.0, 1.0)
                      .toDouble()
          : math.min(rect.right,
              x1 + math.max(8.0, rect.width / math.max(1, list.length)));
      canvas.drawRect(
          Rect.fromLTRB(x1, rect.top, math.max(x1 + 3, x2), rect.bottom),
          Paint()..color = _hrZoneColor(p.zone));
    }
    text(canvas, '0 мин', Offset(rect.left, rect.bottom + 10),
        size: 10, color: _R.muted, weight: FontWeight.w900, maxWidth: 60);
    text(canvas, '${math.max(1, ((maxX - minX) / 60000).round())} мин',
        Offset(rect.right - 54, rect.bottom + 10),
        size: 10, color: _R.muted, weight: FontWeight.w900, maxWidth: 64);
    const labels = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
    for (var i = 0; i < labels.length; i++) {
      final x = rect.left + i * 44.0;
      canvas.drawCircle(Offset(x, 12), 5,
          Paint()..color = _hrZoneColor(labels[i].toLowerCase()));
      text(canvas, labels[i], Offset(x + 8, 5),
          size: 9.5, color: _R.text, weight: FontWeight.w900, maxWidth: 32);
    }
  }

  @override
  bool shouldRepaint(covariant _HrZoneTimeStripPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _HrPlayerSummaryPainter extends _BaseChartPainter {
  _HrPlayerSummaryPainter({required this.players});
  final List<TrackerTrainingPlayerRow> players;

  @override
  void paint(Canvas canvas, Size size) {
    if (players.isEmpty) return;
    final rect = Rect.fromLTWH(48, 26, math.max(10.0, size.width - 70),
        math.max(10.0, size.height - 86));
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    drawGrid(canvas, rect);
    final maxValue = math.max(
        130.0,
        players
                .map((p) => p.heartRateMaxBpm)
                .fold<double>(1, (a, b) => a > b ? a : b) +
            12);
    final minValue = math.max(
        40.0,
        players
                .map((p) => p.heartRateMinBpm > 0
                    ? p.heartRateMinBpm
                    : p.heartRateAvgBpm)
                .fold<double>(999, (a, b) => a < b ? a : b) -
            8);
    final gap = rect.width / players.length;
    for (var i = 0; i < players.length; i++) {
      final p = players[i];
      final x = rect.left + gap * i + gap / 2;
      final avgY = rect.bottom -
          rect.height *
              ((p.heartRateAvgBpm - minValue) / (maxValue - minValue))
                  .clamp(0.0, 1.0)
                  .toDouble();
      final maxY = rect.bottom -
          rect.height *
              ((p.heartRateMaxBpm - minValue) / (maxValue - minValue))
                  .clamp(0.0, 1.0)
                  .toDouble();
      canvas.drawLine(
          Offset(x, avgY),
          Offset(x, maxY),
          Paint()
            ..color = _R.red.withOpacity(.45)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(x, avgY), 5, Paint()..color = _R.green);
      canvas.drawCircle(Offset(x, maxY), 5, Paint()..color = _R.red);
      text(canvas, '${p.heartRateAvgBpm.toStringAsFixed(0)}',
          Offset(x - 14, avgY + 8),
          size: 8.5,
          color: _R.green,
          weight: FontWeight.w900,
          maxWidth: 32,
          align: TextAlign.center);
      text(canvas, shortName(p.name), Offset(x - gap * .42, rect.bottom + 8),
          size: 8,
          color: _R.muted,
          maxWidth: gap * .86,
          align: TextAlign.center);
    }
    text(canvas, 'зелёная точка — средний bpm · красная — максимум',
        Offset(rect.left, 0),
        size: 10.5,
        color: _R.text,
        weight: FontWeight.w900,
        maxWidth: rect.width);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HrPlayerSummaryPainter oldDelegate) =>
      oldDelegate.players != players;
}

class _StackedHrChart extends StatelessWidget {
  const _StackedHrChart({required this.players, required this.distanceMode});
  final List<TrackerTrainingPlayerRow> players;
  final bool distanceMode;
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _StackedHrPainter(players: players, distanceMode: distanceMode),
      child: const SizedBox.expand());
}

class _MicrocycleChart extends StatelessWidget {
  const _MicrocycleChart({required this.points});
  final List<TrackerMicrocyclePoint> points;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty)
      return const _EmptyBlock(
          'Микроцикл появится после реальных сессий выбранной команды.');
    return CustomPaint(
        painter: _MicrocyclePainter(points: points),
        child: const SizedBox.expand());
  }
}

class _PercentBarChart extends StatelessWidget {
  const _PercentBarChart({required this.values});
  final List<_NamedValue> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // На планшетных окнах график с 12 вертикальными подписями выглядит тяжело.
      // Для узких блоков показываем аккуратные 2-колоночные карточки,
      // а полноценную диаграмму оставляем для широкого desktop-отчёта.
      if (constraints.maxWidth < 720) {
        return _PercentCards(values: values);
      }
      return CustomPaint(
          painter: _PercentPainter(values: values),
          child: const SizedBox.expand());
    });
  }
}

class _PercentCards extends StatelessWidget {
  const _PercentCards({required this.values});
  final List<_NamedValue> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 520 ? 2 : 1;
      return GridView.builder(
        padding: const EdgeInsets.all(2),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: values.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 38,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (_, i) {
          final item = values[i];
          final v = item.value.clamp(0, 100).toDouble();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFF5F8F6),
                borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              Expanded(
                  child: Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _R.text,
                          fontSize: 9.7,
                          fontWeight: FontWeight.w800))),
              const SizedBox(width: 7),
              Text('${v.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: _R.darkGreen,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 7),
              SizedBox(
                width: 54,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: v / 100,
                    minHeight: 6,
                    backgroundColor: Colors.white,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFFF9D976)),
                  ),
                ),
              ),
            ]),
          );
        },
      );
    });
  }
}

abstract class _BaseChartPainter extends CustomPainter {
  void drawGrid(Canvas canvas, Rect rect, {int lines = 5}) {
    final paint = Paint()
      ..color = const Color(0xFFE1E5E2)
      ..strokeWidth = 1;
    for (var i = 0; i <= lines; i++) {
      final y = rect.bottom - rect.height * i / lines;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  void text(Canvas canvas, String value, Offset offset,
      {double size = 10,
      Color color = _R.text,
      FontWeight weight = FontWeight.w700,
      TextAlign align = TextAlign.left,
      double maxWidth = 120}) {
    final tp = TextPainter(
        text: TextSpan(
            text: value,
            style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
        textDirection: TextDirection.ltr,
        textAlign: align,
        maxLines: 2)
      ..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  String shortName(String name) {
    final parts =
        name.split(RegExp(r'\s+')).where((e) => e.trim().isNotEmpty).toList();
    if (parts.length <= 1) return name.length > 8 ? name.substring(0, 8) : name;
    return '${parts.first}\n${parts.last.length > 7 ? parts.last.substring(0, 7) : parts.last}';
  }
}

class _BarChartPainter extends _BaseChartPainter {
  _BarChartPainter(
      {required this.players, required this.value, required this.label});
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
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, rect.bottom - h, barW, h), const Radius.circular(4));
      canvas.drawRRect(r, Paint()..color = _R.lime);
      text(canvas, v.toStringAsFixed(v >= 10 ? 0 : 1),
          Offset(x - 2, rect.bottom - h - 16),
          size: 9, maxWidth: 44, align: TextAlign.center);
      text(canvas, shortName(p.name), Offset(x - gap * .25, rect.bottom + 8),
          size: 8,
          color: _R.muted,
          maxWidth: gap * .9,
          align: TextAlign.center);
    }
    text(canvas, label, Offset(rect.left, 0),
        size: 11, color: _R.darkGreen, weight: FontWeight.w900);
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

class _DualBarChartPainter extends _BaseChartPainter {
  _DualBarChartPainter(
      {required this.players,
      required this.first,
      required this.second,
      required this.firstLabel,
      required this.secondLabel});
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
    final maxValue =
        list.expand((p) => [first(p), second(p)]).fold<double>(1, math.max);
    final gap = rect.width / list.length;
    final barW = math.min(16.0, gap * .22);
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final x = rect.left + gap * i + (gap - barW * 2 - 4) / 2;
      final h1 = rect.height * first(p) / maxValue;
      final h2 = rect.height * second(p) / maxValue;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, rect.bottom - h1, barW, h1),
              const Radius.circular(3)),
          Paint()..color = _R.green);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x + barW + 4, rect.bottom - h2, barW, h2),
              const Radius.circular(3)),
          Paint()..color = _R.red);
      text(canvas, shortName(p.name), Offset(x - gap * .2, rect.bottom + 8),
          size: 8,
          color: _R.muted,
          maxWidth: gap * .9,
          align: TextAlign.center);
    }
    text(canvas, '$firstLabel / $secondLabel', Offset(rect.left, 0),
        size: 11, color: _R.darkGreen, weight: FontWeight.w900);
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
        .fold<double>(
            1.0, (previous, value) => math.max(previous, value).toDouble());
    final gap = rect.width / list.length;
    final barW = math.min(34.0, gap * .48);
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final zoneSamples = <double>[
        p.hrZ1Samples.toDouble(),
        p.hrZ2Samples.toDouble(),
        p.hrZ3Samples.toDouble(),
        (p.hrZ4Samples + p.hrZ5Samples).toDouble(),
      ];
      final sampleTotal = zoneSamples.fold<double>(0, (a, b) => a + b);
      final total = distanceMode
          ? math.max(1.0, p.distanceM)
          : math.max(1.0, sampleTotal > 0 ? sampleTotal : 18.0);
      final zones = sampleTotal > 0
          ? (distanceMode
              ? zoneSamples.map((z) => total * z / sampleTotal).toList()
              : zoneSamples)
          : (distanceMode
              ? [total * .42, total * .36, total * .16, total * .06]
              : [total * .38, total * .34, total * .18, total * .10]);
      var y = rect.bottom;
      final x = rect.left + gap * i + (gap - barW) / 2;
      final colors = [
        _R.lime,
        const Color(0xFFFFC857),
        const Color(0xFFF97316),
        const Color(0xFFE11D48)
      ];
      for (var z = 0; z < zones.length; z++) {
        final h = rect.height * zones[z] / maxValue;
        y -= h;
        canvas.drawRect(
            Rect.fromLTWH(x, y, barW, h), Paint()..color = colors[z]);
      }
      text(canvas, shortName(p.name), Offset(x - gap * .25, rect.bottom + 8),
          size: 8,
          color: _R.muted,
          maxWidth: gap * .9,
          align: TextAlign.center);
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
    final list = points;
    if (list.isEmpty) return;
    final rect = Rect.fromLTWH(54, 20, size.width - 82, size.height - 78);
    drawGrid(canvas, rect);
    final maxDist = list.map((p) => p.distanceM).fold<double>(1, math.max);
    final maxLine = list
        .expand((p) => [p.highSpeedRunningM, p.accDec])
        .fold<double>(1, math.max);
    final gap = rect.width / list.length;
    final barW = math.min(54.0, gap * .42);
    final hsrPath = Path();
    final accPath = Path();
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final x = rect.left + gap * i + gap / 2;
      final barH = rect.height * p.distanceM / maxDist;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x - barW / 2, rect.bottom - barH, barW, barH),
              const Radius.circular(4)),
          Paint()..color = _R.lime);
      final y1 = rect.bottom - rect.height * p.highSpeedRunningM / maxLine;
      final y2 = rect.bottom - rect.height * p.accDec / maxLine;
      if (i == 0) {
        hsrPath.moveTo(x, y1);
        accPath.moveTo(x, y2);
      } else {
        hsrPath.lineTo(x, y1);
        accPath.lineTo(x, y2);
      }
      text(canvas, p.label, Offset(x - gap * .45, rect.bottom + 10),
          size: 9,
          color: _R.muted,
          maxWidth: gap * .9,
          align: TextAlign.center);
    }
    canvas.drawPath(
        hsrPath,
        Paint()
          ..color = const Color(0xFFE11D48)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    canvas.drawPath(
        accPath,
        Paint()
          ..color = const Color(0xFF3B82F6)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    text(canvas, 'Дистанция / высокоинтенсивный бег / ускорения-торможения',
        Offset(rect.left, 0),
        size: 11, color: _R.darkGreen, weight: FontWeight.w900);
  }

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
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, rect.bottom - h, barW, h),
              const Radius.circular(3)),
          Paint()..color = const Color(0xFFF9D976));
      text(canvas, '${v.toStringAsFixed(0)}%',
          Offset(x - 4, rect.bottom - h - 15),
          size: 9, maxWidth: 40, align: TextAlign.center);
      canvas.save();
      canvas.translate(x + barW / 2, rect.bottom + 8);
      canvas.rotate(-math.pi / 2);
      text(canvas, item.name, const Offset(0, -6),
          size: 8, color: _R.text, maxWidth: 92);
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
    _NamedValue(
        'V3 бег',
        _percent(
            report.players.fold<double>(0, (a, p) => a + p.v3RunM) /
                math.max(1, report.players.length),
            1228)),
    _NamedValue(
        'V4 ВСБ',
        _percent(
            report.players.fold<double>(0, (a, p) => a + p.v4HsrM) /
                math.max(1, report.players.length),
            426)),
    _NamedValue(
        'V5 спринт',
        _percent(
            report.players.fold<double>(0, (a, p) => a + p.v5SprintM) /
                math.max(1, report.players.length),
            100)),
    _NamedValue(
        'Спринты',
        _percent(
            report.players.fold<double>(0, (a, p) => a + p.sprintCount) /
                math.max(1, report.players.length),
            5)),
    _NamedValue('V4+V5', _percent(s.highSpeedDistanceM, 526)),
  ];
}

double _percent(double value, double benchmark) =>
    benchmark <= 0 ? 0 : (value / benchmark * 100).clamp(0, 140).toDouble();

TrackerTrainingPlayerRow _avgRow(List<TrackerTrainingPlayerRow> rows) {
  final n = rows.length.toDouble();
  double avg(double Function(TrackerTrainingPlayerRow p) get) =>
      rows.fold<double>(0, (a, p) => a + get(p)) / math.max(1, n);
  int avgi(int Function(TrackerTrainingPlayerRow p) get) =>
      (rows.fold<int>(0, (a, p) => a + get(p)) / math.max(1, n)).round();
  return TrackerTrainingPlayerRow(
    name: 'СРЕДНЕЕ',
    duration: rows.isEmpty ? '00:00:00' : rows.first.duration,
    distanceM: avg((p) => p.distanceM),
    metersPerMin: avg((p) => p.metersPerMin),
    maxSpeedKmh: avg((p) => p.maxSpeedKmh),
    avgSpeedKmh: avg((p) => p.avgSpeedKmh),
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
    pointsCount: avgi((p) => p.pointsCount),
    sessionsCount: avgi((p) => p.sessionsCount),
    hasMovement: rows.any((p) => p.hasMovement),
  );
}

TableRow _tableRow(List<String> values, {bool header = false}) {
  return TableRow(
    decoration:
        BoxDecoration(color: header ? const Color(0xFFE1E5E2) : Colors.white),
    children: values.map((v) => _cell(v, bold: header)).toList(),
  );
}

Widget _cell(String text,
    {bool bold = false, TextAlign align = TextAlign.center}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
    child: Text(text,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: _R.text,
            fontSize: 10.4,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
  );
}

Widget _playerCell(TrackerTrainingPlayerRow p, bool average) {
  if (average) return _cell(p.name, bold: true, align: TextAlign.left);
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: Row(children: [
      _PlayerAvatar(player: p, size: 28),
      const SizedBox(width: 7),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.text,
                    fontSize: 9.8,
                    fontWeight: FontWeight.w900)),
            Text(
                [
                  if (p.number.isNotEmpty) '#${p.number}',
                  if (p.position.isNotEmpty) p.position,
                  if (p.deviceName.isNotEmpty) _displayReportDeviceName(p.deviceName)
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _R.muted,
                    fontSize: 8.1,
                    fontWeight: FontWeight.w700)),
          ])),
    ]),
  );
}

Widget _heatCell(String text, double value, double max) {
  final ratio = (value / max).clamp(0, 1).toDouble();
  final color = ratio > .82
      ? const Color(0xFFEF4444).withOpacity(.34)
      : ratio > .58
          ? const Color(0xFFFACC15).withOpacity(.50)
          : const Color(0xFF22C55E).withOpacity(.20 + .25 * ratio);
  return Container(color: color, child: _cell(text, bold: ratio > .82));
}

Widget _barCell(String text, double value, double max, Color color) {
  final ratio = (value / max).clamp(0, 1).toDouble();
  return Stack(children: [
    Positioned.fill(
        child: FractionallySizedBox(
            widthFactor: ratio,
            alignment: Alignment.centerLeft,
            child: Container(color: color.withOpacity(.45)))),
    _cell(text),
  ]);
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: const Color(0xFFF5F8F6),
            borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _R.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
      );
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
            color: const Color(0xFFF7F9F8),
            borderRadius: BorderRadius.circular(_R.mobileInnerRadius),
            border: Border.all(color: _R.border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, color: _R.red, size: 44),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: _R.text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить')),
        ]),
      ),
    );
  }
}

class _PrintableTrainingReportHtml {
  const _PrintableTrainingReportHtml._();

  static Uri buildUri(TrackerTrainingReport report, {List<String>? sections}) {
    final html = _build(report, sections: sections);
    return Uri.dataFromString(html, mimeType: 'text/html', encoding: utf8);
  }

  static String _build(TrackerTrainingReport report, {List<String>? sections}) {
    final selectedSections = sections == null || sections.isEmpty
        ? _defaultReportExportSectionIds()
        : sections.toSet();
    bool show(String id) => selectedSections.contains(id);
    bool showAny(Iterable<String> ids) => ids.any(show);
    final players = _reportPlayers(report);
    final route = report.routePoints;
    final heat = report.heatmapPoints.isEmpty ? route : report.heatmapPoints;
    final hr = _reportHrTimeline(report);
    final s = report.summary;
    final title = 'Спортотека. Полный отчёт';
    final resolvedLogoUrl = _absoluteReportImageUrl(report.teamLogoUrl);
    final logo = resolvedLogoUrl.isNotEmpty
        ? '<img class="logo-img" src="${_h(resolvedLogoUrl)}" alt="logo" referrerpolicy="no-referrer">'
        : '<div class="logo-fallback">Ф</div>';

    final b = StringBuffer();
    b.write('''<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_h(title)}</title>
<style>
  :root{--green:#00A750;--green-dark:#067A46;--soft-green:#F3FAF6;--line:#E9ECEA;--text:#0B0F14;--muted:#5F6670;--bg:#FFFFFF;--soft:#F7F8F7;--red:#EF4444;--orange:#F59E0B;--blue:#2563EB;}
  *{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--text);font-family:Inter,-apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",Roboto,Arial,sans-serif;font-size:12px;line-height:1.34;font-weight:400;}
  .toolbar{position:sticky;top:0;z-index:20;display:flex;gap:10px;align-items:center;justify-content:space-between;padding:10px 18px;background:rgba(255,255,255,.98);border-bottom:1px solid var(--line)}
  .toolbar strong{font-size:15px;font-weight:600}.btn{border:0;background:var(--green);color:#fff;border-radius:12px;padding:10px 14px;font-weight:600;cursor:pointer}.hint{color:var(--muted);font-weight:400;font-size:10.5px}
  .page{max-width:1180px;margin:10px auto 24px;padding:16px;background:#fff;border:1px solid var(--line);border-radius:18px}
  .head{display:flex;gap:12px;align-items:center;margin-bottom:14px;padding:2px 0 12px;border-bottom:1px solid var(--line)}.logo{width:58px;height:58px;border-radius:14px;background:var(--soft-green);display:flex;align-items:center;justify-content:center;overflow:hidden;flex:0 0 auto}.logo-img{width:100%;height:100%;object-fit:cover}.logo-fallback{font-size:26px;font-weight:600;color:var(--green-dark)}
  h1{font-size:22px;line-height:1.1;margin:0 0 5px;font-weight:600;letter-spacing:0}.subtitle{color:var(--muted);font-size:12px;font-weight:400}.status{margin-left:auto;background:var(--soft-green);color:var(--green-dark);border-radius:12px;padding:8px 11px;font-weight:600;white-space:nowrap}
  h2{font-size:15px;margin:18px 0 8px;font-weight:600;letter-spacing:0}.section{break-inside:avoid;margin-top:10px}.card{border:1px solid var(--line);border-radius:16px;background:#fff;overflow:hidden;break-inside:avoid}.card-title{padding:10px 12px;background:var(--soft-green);border-bottom:1px solid var(--line);box-shadow:inset 3px 0 0 var(--green);font-size:12px;font-weight:600}.card-body{padding:12px}.grid{display:grid;gap:8px;align-items:start}.grid-2{grid-template-columns:repeat(2,minmax(0,1fr))}.grid-3{grid-template-columns:repeat(3,minmax(0,1fr))}.kpis{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:7px}.kpi{border:0;background:var(--soft);border-radius:12px;padding:9px;min-height:60px}.kpi .v{font-size:17px;font-weight:600}.kpi .l{color:var(--muted);font-size:9.5px;font-weight:400;margin-top:2px}
  table{width:100%;border-collapse:collapse;font-size:10.5px} th{background:var(--soft);color:#374151;text-align:left;font-weight:600} th,td{border:0;border-bottom:1px solid var(--line);padding:7px 8px;vertical-align:middle} td.num,th.num{text-align:right}.pill{display:inline-block;background:var(--soft-green);color:var(--green-dark);border-radius:9px;padding:3px 7px;font-size:9.5px;font-weight:600}.muted{color:var(--muted)}
  .svg-wrap svg{display:block;width:100%;height:auto;border-radius:12px}.radar-large{max-width:980px;margin:0 auto}.legend{display:flex;flex-wrap:wrap;gap:8px;margin-top:8px;color:var(--muted);font-size:9.5px;font-weight:400}.dot{width:9px;height:9px;border-radius:999px;display:inline-block;margin-right:5px}.player-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.player-card{border:1px solid var(--line);border-radius:12px;padding:10px;break-inside:avoid;background:#fff}.player-head{display:flex;gap:9px;align-items:center;margin-bottom:8px}.avatar{width:34px;height:34px;border-radius:50%;background:var(--soft-green);display:flex;align-items:center;justify-content:center;overflow:hidden;color:var(--green-dark);font-weight:600}.avatar img{width:100%;height:100%;object-fit:cover}.player-name{font-weight:600}.loco-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.loco-card{padding:11px;border-radius:12px;background:#fff;border:1px solid var(--line);break-inside:avoid}.loco-head{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:9px}.loco-name{font-size:12px;font-weight:600}.loco-duration{font-size:9.5px;color:var(--muted);font-weight:400}.loco-metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px}.loco-metric{padding:8px;border-radius:10px;background:var(--soft);min-height:50px}.loco-metric strong{display:block;font-size:13px;font-weight:600}.loco-metric span{font-size:9px;color:var(--muted);font-weight:400}.coach-list{margin:0;padding:0;list-style:none}.coach-list li{margin:0 0 7px;padding-left:20px;position:relative;font-weight:400}.coach-list li:before{content:'✓';position:absolute;left:0;top:0;color:var(--green);font-weight:600}.page-break{break-before:page;margin-top:20px}
  @media(max-width:1040px){.grid-2,.grid-3,.player-grid,.loco-grid{grid-template-columns:1fr}.kpis{grid-template-columns:repeat(2,minmax(0,1fr))}.status{display:none}.page{border-radius:18px;margin:8px 6px;padding:12px;border-left:1px solid var(--line);border-right:1px solid var(--line)}.toolbar{position:static;padding:8px 10px}.toolbar strong{font-size:14px}h1{font-size:22px}.subtitle{font-size:12px}.card-title{font-size:12px}.card-body{padding:10px}.svg-wrap svg{min-height:210px}.hint{display:none}}
  @media print{body{background:#fff}.toolbar{display:none}.page{max-width:none;margin:0;border:0;border-radius:0;box-shadow:none;padding:0}.section,.card,.player-card{break-inside:avoid}h2{break-after:avoid}.page-break{break-before:page}.kpis{grid-template-columns:repeat(4,minmax(0,1fr))}.grid-2{grid-template-columns:repeat(2,minmax(0,1fr))}.player-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
</style>
</head>
<body>
<div class="toolbar"><div><strong>Спортотека. Полный отчёт</strong><div class="hint">Печатная версия собирается из текущих данных экрана: карты, точки событий, журнал, графики, таблицы, ЧСС и игроки.</div></div><button class="btn" onclick="window.print()">PDF / печать</button></div>
<div class="page">
<header class="head"><div class="logo">$logo</div><div><h1>Спортотека. Отчёт</h1><div class="subtitle">${_h(report.teamName.isEmpty ? 'Команда' : report.teamName)} · ${_h(report.dateLabel.isEmpty ? 'дата не указана' : report.dateLabel)} · ${_h(report.durationLabel)} · ${players.length} игрок(ов)</div></div><div class="status">данные готовы</div></header>
''');

    if (show('summary'))
      b.write('<section class="section"><h2>Сводка тренировки</h2>${_kpis([
            _Kpi('Время', report.durationLabel, 'длительность'),
            _Kpi('Игроки', '${report.playersCount}', 'в отчёте'),
            _Kpi(
                'Дистанция',
                _m(s.totalDistanceM > 0
                    ? s.totalDistanceM
                    : s.averageDistanceM),
                'команда'),
            _Kpi('Средняя', '${s.avgSpeedKmh.toStringAsFixed(1)}', 'км/ч'),
            _Kpi('Макс.', '${s.maxSpeedKmh.toStringAsFixed(1)}', 'км/ч'),
            _Kpi('V3 бег', _m(s.v3RunM), 'метры'),
            _Kpi('V4 ВСБ', _m(s.v4HsrM), 'метры'),
            _Kpi('V5 спринт', _m(s.v5SprintM), 'метры'),
            _Kpi('Спринты', '${s.sprintCount}', 'кол-во'),
            _Kpi('Уск/торм', '${s.accelerationCount}/${s.decelerationCount}',
                'кол-во'),
            _Kpi('Нагрузка', s.playerLoad.toStringAsFixed(0), 'усл. ед.'),
            _Kpi(
                'Avg HR',
                s.heartRateAvgBpm > 0
                    ? s.heartRateAvgBpm.toStringAsFixed(0)
                    : '—',
                'bpm'),
            _Kpi(
                'Max HR',
                s.heartRateMaxBpm > 0
                    ? s.heartRateMaxBpm.toStringAsFixed(0)
                    : '—',
                'bpm'),
          ])}</section>');

    if (showAny(const ['maps', 'heatmap'])) {
      b.write(
          '<section class="section"><h2>Карты и тепловая карта</h2><div class="grid grid-2">');
      b.write(_card('Карта активности',
          '${_mapSvg(route, heatMode: false, report: report, events: report.events)}${_mapLegend(report, events: report.events)}'));
      b.write(_card('Тепловая карта',
          '${_mapSvg(heat, heatMode: true, report: report)}<div class="legend">Плотность перемещений игрока: зелёный — низкая, жёлтый — средняя, красный — высокая</div>'));
      b.write('</div></section>');
    }

    if (show('events')) {
      b.write('<section class="section"><h2>Журнал событий</h2>');
      b.write(_card('Ключевые моменты сессии', _eventJournalHtml(report.events)));
      b.write('</section>');
    }

    if (show('speed')) {
      b.write(
          '<section class="section"><h2>Скорость и зоны</h2><div class="grid grid-2">');
      b.write(_card('График скорости по времени',
          '${_speedSvg(report)}${_mapLegend(report)}'));
      b.write(_card('Скоростные зоны', _speedZonesTable(report)));
      b.write('</div></section>');
    }

    if (show('players')) {
      b.write('<section class="section"><h2>Команда</h2>');
      b.write(_card('Игроки и показатели', _playersTable(players)));
      b.write('</section>');
    }

    if (show('rating')) {
      b.write('<section class="section"><h2>Рейтинг и сравнение</h2>');
      b.write(_card('Радар команды', _radarSvg(players)));
      b.write('</section>');
    }

    if (show('locomotor')) {
      b.write('<section class="section"><h2>Локомоторика</h2>');
      b.write(
          _card('Локомоторный профиль игроков', _locomotorCardsHtml(players)));
      b.write('</section>');
    }

    if (show('mechanics')) {
      b.write(
          '<section class="section"><h2>Механика</h2><div class="grid grid-2">');
      b.write(_card(
          'Ускорения / торможения',
          _dualBarSvg(players, (p) => p.accelerations.toDouble(),
              (p) => p.decelerations.toDouble(), 'ACC', 'DEC')));
      b.write(_card(
          'Взрывные действия / смены направления',
          _dualBarSvg(players, (p) => p.explosiveActions.toDouble(),
              (p) => p.highSpeedActions.toDouble(), 'Взрывные', 'Повороты')));
      b.write('</div></section>');
    }

    if (showAny(const ['internal', 'hr'])) {
      b.write(
          '<section class="section"><h2>Внутренняя нагрузка / Кардиодатчик</h2><div class="grid grid-2">');
      b.write(_card('Пульс по времени', _hrSvg(report, hr)));
      b.write(_card('Зоны ЧСС и рекомендации',
          '${_hrZonesTable(players)}${_coachMessages(report)}'));
      b.write('</div></section>');
    }

    if (show('microcycle')) {
      b.write('<section class="section"><h2>Микроцикл</h2>');
      b.write(_card('Динамика микроцикла', _microcycleSvg(report)));
      b.write('</section>');
    }

    if (show('periods')) {
      b.write('<section class="section"><h2>Периоды / упражнения</h2>');
      b.write(_card('Структура сессии', _periodsTableHtml(report.periods)));
      b.write('</section>');
    }

    if (show('player_pages')) {
      b.write(
          '<section class="section page-break"><h2>Карточки игроков: карта + график</h2>');
      b.write(_playerCards(report, players));
      b.write('</section>');
    }

    if (show('ai')) {
      b.write('<section class="section"><h2>ИИ анализ</h2>');
      b.write(_card('Проверенная сводка и рекомендации', _aiBlock(report)));
      b.write('</section>');
    }

    b.write('</div></body></html>');
    return b.toString();
  }

  static String _h(String value) => htmlEscape.convert(value);
  static String _m(double value) => value >= 1000
      ? '${(value / 1000).toStringAsFixed(2)} км'
      : '${value.toStringAsFixed(0)} м';
  static String _f(double value, [int digits = 1]) =>
      value.isFinite ? value.toStringAsFixed(digits) : '0';

  static String _kpis(List<_Kpi> items) {
    final b = StringBuffer('<div class="kpis">');
    for (final item in items) {
      b.write(
          '<div class="kpi"><div class="v">${_h(item.value)}</div><div class="l">${_h(item.title)} · ${_h(item.note)}</div></div>');
    }
    b.write('</div>');
    return b.toString();
  }

  static String _card(String title, String body) =>
      '<div class="card"><div class="card-title">${_h(title)}</div><div class="card-body">$body</div></div>';

  static String _locomotorCardsHtml(List<TrackerTrainingPlayerRow> players) {
    if (players.isEmpty)
      return '<div class="muted">Нет игроков в выбранной сессии.</div>';
    final rows = [...players, _avgRow(players)];
    final b = StringBuffer('<div class="loco-grid">');
    for (final p in rows) {
      final average = p.name == 'СРЕДНЕЕ';
      b.write(
          '<article class="loco-card"${average ? ' style="background:#F0FDF4"' : ''}>');
      b.write(
          '<div class="loco-head"><div><div class="loco-name">${_h(p.name)}</div><div class="muted">${_h([
        if (p.number.isNotEmpty) '#${p.number}',
        if (p.position.isNotEmpty) p.position
      ].join(' · '))}</div></div><div class="loco-duration">${_h(p.duration)}</div></div>');
      final metrics = <List<String>>[
        ['${p.distanceM.toStringAsFixed(0)} м', 'Дистанция'],
        [p.metersPerMin.toStringAsFixed(1), 'Метров/мин'],
        ['${p.avgSpeedKmh.toStringAsFixed(1)} км/ч', 'Средняя'],
        ['${p.maxSpeedKmh.toStringAsFixed(1)} км/ч', 'Максимум'],
        ['${p.v3RunM.toStringAsFixed(0)} м', 'V3 бег'],
        ['${p.v4HsrM.toStringAsFixed(0)} м', 'V4 HSR'],
        ['${p.v5SprintM.toStringAsFixed(0)} м', 'V5 спринт'],
        ['${p.sprintCount}', 'Спринты'],
      ];
      b.write('<div class="loco-metrics">');
      for (final m in metrics)
        b.write(
            '<div class="loco-metric"><strong>${_h(m[0])}</strong><span>${_h(m[1])}</span></div>');
      b.write('</div></article>');
    }
    b.write('</div>');
    return b.toString();
  }

  static String _playersTable(List<TrackerTrainingPlayerRow> players) {
    if (players.isEmpty)
      return '<div class="muted">Нет игроков в выбранной сессии.</div>';
    final b = StringBuffer('<table><thead><tr>');
    const headers = [
      'Игрок',
      'Дист.',
      'м/мин',
      'Avg',
      'Max',
      'V3',
      'V4',
      'V5',
      'Спр.',
      'Уск.',
      'Торм.',
      'Нагрузка',
      'Avg HR',
      'Max HR',
      'GPS'
    ];
    for (final h in headers) {
      final cls = h == 'Игрок' ? '' : ' class="num"';
      b.write('<th$cls>${_h(h)}</th>');
    }
    b.write('</tr></thead><tbody>');
    for (final p in players) {
      b.write('<tr><td><strong>${_h(p.name)}</strong><div class="muted">${_h([
        if (p.number.isNotEmpty) '#${p.number}',
        if (p.position.isNotEmpty) p.position,
        if (p.deviceName.isNotEmpty) _displayReportDeviceName(p.deviceName)
      ].join(' · '))}</div></td>');
      final values = [
        _m(p.distanceM),
        _f(p.metersPerMin),
        _f(p.avgSpeedKmh),
        _f(p.maxSpeedKmh),
        _m(p.v3RunM),
        _m(p.v4HsrM),
        _m(p.v5SprintM),
        '${p.sprintCount}',
        '${p.accelerations}',
        '${p.decelerations}',
        _f(p.playerLoad, 0),
        p.heartRateAvgBpm > 0 ? _f(p.heartRateAvgBpm, 0) : '—',
        p.heartRateMaxBpm > 0 ? _f(p.heartRateMaxBpm, 0) : '—',
        '${p.pointsCount}'
      ];
      for (final v in values) b.write('<td class="num">${_h(v)}</td>');
      b.write('</tr>');
    }
    b.write('</tbody></table>');
    return b.toString();
  }

  static String _periodsTableHtml(List<TrackerExercisePeriod> periods) {
    if (periods.isEmpty) {
      return '<div class="muted">Периоды и упражнения для выбранной сессии не заданы.</div>';
    }
    final b = StringBuffer(
        '<table><thead><tr><th>Период</th><th class="num">Начало</th><th class="num">Конец</th><th class="num">Длительность</th><th class="num">Дистанция</th><th class="num">HSR</th><th class="num">Уск/торм</th></tr></thead><tbody>');
    for (final period in periods) {
      final minutes = period.durationSec ~/ 60;
      final seconds = (period.durationSec % 60).toString().padLeft(2, '0');
      b.write('<tr>');
      b.write('<td><strong>${_h(period.title)}</strong></td>');
      b.write('<td class="num">${_h(period.startLabel)}</td>');
      b.write('<td class="num">${_h(period.endLabel)}</td>');
      b.write('<td class="num">$minutes:$seconds</td>');
      b.write('<td class="num">${_m(period.distanceM)}</td>');
      b.write('<td class="num">${_m(period.highSpeedDistanceM)}</td>');
      b.write('<td class="num">${period.accDecCount}</td>');
      b.write('</tr>');
    }
    b.write('</tbody></table>');
    return b.toString();
  }

  static String _speedZonesTable(TrackerTrainingReport report) {
    final zones = report.speedZones;
    if (zones.isEmpty)
      return '<div class="muted">Скоростные зоны не пришли с сервера. Границы на графиках рассчитаны по методике U13: HIR ${_reportHsrThreshold(report).toStringAsFixed(1)}, Sprint ${_reportSprintThreshold(report).toStringAsFixed(1)} км/ч.</div>';
    final total =
        zones.fold<double>(0, (a, z) => a + math.max(0.0, z.distanceM));
    final b = StringBuffer(
        '<table><thead><tr><th>Зона</th><th class="num">Скорость</th><th class="num">Дистанция</th><th class="num">Доля</th></tr></thead><tbody>');
    for (final z in zones) {
      final double pct =
          total > 0 ? (z.distanceM.toDouble() * 100.0 / total) : 0.0;
      final toLabel = z.toKmh > 0 ? _f(z.toKmh) : '∞';
      b.write(
          '<tr><td><span class="pill">${_h(z.label)}</span></td><td class="num">${_f(z.fromKmh)}-$toLabel км/ч</td><td class="num">${_m(z.distanceM)}</td><td class="num">${_f(pct, 0)}%</td></tr>');
    }
    b.write('</tbody></table>');
    return b.toString();
  }

  static String _hrZonesTable(List<TrackerTrainingPlayerRow> players) {
    final withHr = players
        .where((p) => p.heartRateSamplesCount > 0)
        .toList(growable: false);
    if (withHr.isEmpty)
      return '<div class="muted">Нет записей кардиодатчика по выбранным игрокам.</div>';
    final totals = <int>[
      withHr.fold<int>(0, (a, p) => a + p.hrZ1Samples),
      withHr.fold<int>(0, (a, p) => a + p.hrZ2Samples),
      withHr.fold<int>(0, (a, p) => a + p.hrZ3Samples),
      withHr.fold<int>(0, (a, p) => a + p.hrZ4Samples),
      withHr.fold<int>(0, (a, p) => a + p.hrZ5Samples),
    ];
    final total = math.max(1, totals.fold<int>(0, (a, b) => a + b));
    const names = [
      'Z1 восстановление',
      'Z2 лёгкая',
      'Z3 рабочая',
      'Z4 высокая',
      'Z5 пик'
    ];
    final b = StringBuffer(
        '<table><thead><tr><th>Зона</th><th class="num">Время</th><th class="num">Доля</th></tr></thead><tbody>');
    for (var i = 0; i < totals.length; i++) {
      final seconds = totals[i];
      final min = seconds ~/ 60;
      final sec = seconds % 60;
      final secLabel = sec.toString().padLeft(2, '0');
      final pctLabel = (seconds * 100 / total).toStringAsFixed(0);
      b.write(
          '<tr><td>${_h(names[i])}</td><td class="num">$min:$secLabel</td><td class="num">$pctLabel%</td></tr>');
    }
    b.write('</tbody></table>');
    return b.toString();
  }

  static String _coachMessages(TrackerTrainingReport report) {
    final messages = _reportCoachMessages(report);
    final b = StringBuffer('<ul class="coach-list" style="margin-top:12px">');
    for (final m in messages) b.write('<li>${_h(m)}</li>');
    b.write('</ul>');
    return b.toString();
  }

  static String _mapLegend(TrackerTrainingReport report,
      {List<TrackerReportEvent> events = const <TrackerReportEvent>[]}) {
    final hsr = _reportHsrThreshold(report);
    final sprint = _reportSprintThreshold(report);
    final eventLegend = events.any((event) => event.hasPoint)
        ? '<span><i class="dot" style="background:#ffffff;border:3px solid #DC2626"></i>точки событий</span>'
        : '';
    return '<div class="legend"><span><i class="dot" style="background:#2563EB"></i>ходьба</span><span><i class="dot" style="background:#00A750"></i>бег</span><span><i class="dot" style="background:#F59E0B"></i>высокая ≥ ${hsr.toStringAsFixed(1)}</span><span><i class="dot" style="background:#DC2626"></i>спринт ≥ ${sprint.toStringAsFixed(1)}</span>$eventLegend</div>';
  }

  static String _mapSvg(List<TrackerReportPoint> source,
      {required bool heatMode,
      required TrackerTrainingReport report,
      List<TrackerReportEvent> events = const <TrackerReportEvent>[]}) {
    const w = 980.0, h = 570.0;
    const left = 10.0, top = 10.0;
    const pitchW = w - 20.0, pitchH = h - 20.0;
    final points = _sample(source, heatMode ? 900 : 1200);
    final hsr = _reportHsrThreshold(report);
    final sprint = _reportSprintThreshold(report);
    final clipId = 'reportPitch${source.hashCode.abs()}${heatMode ? 'h' : 'r'}';

    String px(TrackerReportPoint p) =>
        (left + p.x.clamp(0.0, 1.0) * pitchW).toStringAsFixed(1);
    String py(TrackerReportPoint p) =>
        (top + p.y.clamp(0.0, 1.0) * pitchH).toStringAsFixed(1);

    final b = StringBuffer(
        '<div class="svg-wrap"><svg viewBox="0 0 ${w.toInt()} ${h.toInt()}" xmlns="http://www.w3.org/2000/svg" role="img">');
    b.write('<defs><clipPath id="$clipId"><rect x="8" y="8" width="964" height="554" rx="8"/></clipPath></defs>');
    b.write('<rect x="0" y="0" width="$w" height="$h" rx="16" fill="#76947B"/>');
    final stripeW = math.max(36.0, w / 12.0);
    b.write('<g clip-path="url(#$clipId)">');
    for (var i = 0; i < 14; i++) {
      b.write('<rect x="${(8 + i * stripeW).toStringAsFixed(1)}" y="8" width="${stripeW.toStringAsFixed(1)}" height="554" fill="${i.isEven ? '#719078' : '#819E86'}"/>');
    }
    b.write('</g>');
    b.write('<rect x="10" y="10" width="960" height="550" rx="12" fill="none" stroke="#fff" stroke-opacity=".78" stroke-width="1.5"/>');
    b.write('<line x1="490" y1="10" x2="490" y2="560" stroke="#fff" stroke-opacity=".78" stroke-width="1.5"/>');
    b.write('<circle cx="490" cy="285" r="68.4" fill="none" stroke="#fff" stroke-opacity=".78" stroke-width="1.5"/>');
    b.write('<rect x="10" y="159.6" width="166.6" height="250.8" fill="none" stroke="#fff" stroke-opacity=".78" stroke-width="1.5"/>');
    b.write('<rect x="10" y="216.6" width="78.4" height="136.8" fill="none" stroke="#fff" stroke-opacity=".78" stroke-width="1.5"/>');
    b.write('<rect x="803.4" y="159.6" width="166.6" height="250.8" fill="none" stroke="#fff" stroke-opacity=".78" stroke-width="1.5"/>');
    b.write('<rect x="891.6" y="216.6" width="78.4" height="136.8" fill="none" stroke="#fff" stroke-opacity=".78" stroke-width="1.5"/>');
    b.write('<circle cx="127.4" cy="285" r="3" fill="#fff" fill-opacity=".75"/><circle cx="852.6" cy="285" r="3" fill="#fff" fill-opacity=".75"/>');

    if (points.isEmpty) {
      b.write('<text x="50%" y="50%" text-anchor="middle" fill="#ffffff" opacity=".78" font-size="20" font-weight="900">Нет GPS-точек</text></svg></div>');
      return b.toString();
    }

    if (heatMode) {
      final maxValue = points.fold<double>(
          1.0, (m, p) => math.max(m, p.value <= 0 ? 1.0 : p.value));
      String heatHex(double ratio) {
        int lerp(int a, int z) =>
            (a + (z - a) * ratio).round().clamp(0, 255).toInt();
        final rr = lerp(0x22, 0xDC).toRadixString(16).padLeft(2, '0');
        final gg = lerp(0xC5, 0x26).toRadixString(16).padLeft(2, '0');
        final bb = lerp(0x5E, 0x26).toRadixString(16).padLeft(2, '0');
        return '#$rr$gg$bb';
      }
      for (final p in points) {
        final ratio = ((p.value <= 0 ? 1.0 : p.value) / maxValue)
            .clamp(0.0, 1.0)
            .toDouble();
        final c = heatHex(ratio);
        final r = points.length <= 2 ? 18.0 : (12.0 + ratio * 26.0);
        b.write('<circle cx="${px(p)}" cy="${py(p)}" r="${r.toStringAsFixed(1)}" fill="$c" opacity=".08"/>');
        b.write('<circle cx="${px(p)}" cy="${py(p)}" r="${(r * .62).toStringAsFixed(1)}" fill="$c" opacity=".20"/>');
        b.write('<circle cx="${px(p)}" cy="${py(p)}" r="${(r * .30).toStringAsFixed(1)}" fill="$c" opacity=".46"/>');
      }
    } else {
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1];
        final p = points[i];
        if (p.breakBefore) continue;
        final dt = (p.timeMs - a.timeMs).abs();
        if (dt > 60000) continue;
        final c = _speedHex(p.speedKmh, hsr, sprint);
        final glow = p.speedKmh >= sprint ? 8.0 : 5.0;
        final sw = p.speedKmh >= sprint ? 3.2 : (p.speedKmh >= hsr ? 2.7 : 1.9);
        final glowOpacity = p.speedKmh >= sprint ? .18 : .08;
        final mainOpacity = p.speedKmh >= sprint ? .97 : .84;
        b.write('<line x1="${px(a)}" y1="${py(a)}" x2="${px(p)}" y2="${py(p)}" stroke="$c" stroke-opacity="$glowOpacity" stroke-width="$glow" stroke-linecap="round"/>');
        b.write('<line x1="${px(a)}" y1="${py(a)}" x2="${px(p)}" y2="${py(p)}" stroke="$c" stroke-opacity="$mainOpacity" stroke-width="$sw" stroke-linecap="round"/>');
        if (i % 14 == 0 || p.speedKmh >= sprint) {
          final x1 = left + a.x.clamp(0.0, 1.0) * pitchW;
          final y1 = top + a.y.clamp(0.0, 1.0) * pitchH;
          final x2 = left + p.x.clamp(0.0, 1.0) * pitchW;
          final y2 = top + p.y.clamp(0.0, 1.0) * pitchH;
          final dx = x2 - x1, dy = y2 - y1;
          final len = math.sqrt(dx * dx + dy * dy);
          if (len >= 4) {
            final ux = dx / len, uy = dy / len;
            final pxn = -uy, pyn = ux;
            final bx = x2 - ux * 7.0, by = y2 - uy * 7.0;
            final lpx = bx + pxn * 3.4, lpy = by + pyn * 3.4;
            final rpx = bx - pxn * 3.4, rpy = by - pyn * 3.4;
            b.write('<polygon points="${x2.toStringAsFixed(1)},${y2.toStringAsFixed(1)} ${lpx.toStringAsFixed(1)},${lpy.toStringAsFixed(1)} ${rpx.toStringAsFixed(1)},${rpy.toStringAsFixed(1)}" fill="$c" opacity=".92"/>');
          }
        }
      }
      final step = math.max(1, (points.length / 120).ceil());
      for (var i = 0; i < points.length; i += step) {
        final p = points[i];
        final c = _speedHex(p.speedKmh, hsr, sprint);
        final r = p.speedKmh >= sprint ? 4.8 : (p.speedKmh >= 7 ? 3.8 : 3.0);
        b.write('<circle cx="${px(p)}" cy="${py(p)}" r="${(r + 2.8).toStringAsFixed(1)}" fill="$c" opacity=".08"/><circle cx="${px(p)}" cy="${py(p)}" r="${r.toStringAsFixed(1)}" fill="$c" opacity=".95"/>');
      }
    }
    if (!heatMode && events.isNotEmpty) {
      final markers = events.where((event) => event.hasPoint).toList()
        ..sort((a, b) {
          int priority(TrackerReportEvent event) {
            if (event.kind == 'gps_gap') return 0;
            if (event.kind == 'sprint' || event.severity == 'red') return 1;
            if (event.kind == 'accel' || event.kind == 'decel') return 2;
            return 3;
          }
          final p = priority(a).compareTo(priority(b));
          return p != 0 ? p : b.timeMs.compareTo(a.timeMs);
        });
      for (final event in markers.take(90)) {
        final cx = left + event.x.clamp(0.0, 1.0) * pitchW;
        final cy = top + event.y.clamp(0.0, 1.0) * pitchH;
        final color = _eventHex(event);
        final glyph = _h(_reportEventGlyph(event));
        b.write('<circle cx="${cx.toStringAsFixed(1)}" cy="${cy.toStringAsFixed(1)}" r="10" fill="#fff" opacity=".98"/>');
        b.write('<circle cx="${cx.toStringAsFixed(1)}" cy="${cy.toStringAsFixed(1)}" r="7.2" fill="$color"/>');
        b.write('<text x="${cx.toStringAsFixed(1)}" y="${(cy + 2.6).toStringAsFixed(1)}" text-anchor="middle" fill="#fff" font-size="7" font-weight="900">$glyph</text>');
      }
    }
    b.write('</svg></div>');
    return b.toString();
  }

  static String _eventHex(TrackerReportEvent event) {
    if (event.severity.toLowerCase() == 'red' || event.kind == 'sprint') {
      return '#DC2626';
    }
    switch (event.kind) {
      case 'hir': return '#F59E0B';
      case 'accel': return '#00A750';
      case 'decel': return '#F97316';
      case 'turn': return '#2563EB';
      case 'gps_gap': return '#DC2626';
      default: return '#667085';
    }
  }

  static String _eventJournalHtml(List<TrackerReportEvent> events) {
    if (events.isEmpty) {
      return '<div class="muted">Нет событий для этой сессии.</div>';
    }
    final rows = events.take(90);
    final b = StringBuffer('<table><thead><tr><th>Время</th><th>Игрок</th><th>Событие</th><th>Детали</th><th class="num">Скорость</th><th class="num">ЧСС</th><th class="num">Карта</th></tr></thead><tbody>');
    for (final event in rows) {
      final title = event.title.trim().isNotEmpty
          ? event.title.trim()
          : _reportEventKindLabel(event.kind);
      final elapsed = event.elapsedMs > 0
          ? _reportElapsedLabel(event.elapsedMs)
          : '—';
      b.write('<tr>');
      b.write('<td><span class="pill">${_h(elapsed)}</span></td>');
      b.write('<td>${_h(_reportEventPlayerShortName(event.playerName))}</td>');
      b.write('<td><span style="font-weight:600;color:${_eventHex(event)}">${_h(title)}</span></td>');
      b.write('<td class="muted">${_h(event.detail)}</td>');
      b.write('<td class="num">${event.speedKmh > 0 ? '${event.speedKmh.toStringAsFixed(1)} км/ч' : '—'}</td>');
      b.write('<td class="num">${event.bpm > 0 ? '${event.bpm} уд/мин' : '—'}</td>');
      b.write('<td class="num">${event.hasPoint ? '●' : '—'}</td>');
      b.write('</tr>');
    }
    b.write('</tbody></table>');
    if (events.length > 90) {
      b.write('<div class="hint" style="margin-top:8px">Показано 90 из ${events.length} событий.</div>');
    }
    return b.toString();
  }

  static String _speedSvg(TrackerTrainingReport report) {
    final source = report.routePoints.where((p) => p.speedKmh.isFinite && p.speedKmh >= 0).toList(growable: false);
    final sampledPoints = _sample(source, 900);
    final samples = sampledPoints.map((p) => p.speedKmh).toList(growable: false);
    const w = 980.0, h = 360.0, left = 58.0, top = 38.0, right = 22.0, bottom = 54.0;
    final rw = w - left - right, rh = h - top - bottom;
    final maxSpeed = math.max(24.0, samples.fold<double>(report.summary.maxSpeedKmh, math.max) + 3);
    final hsr = _reportHsrThreshold(report), sprint = _reportSprintThreshold(report);
    final durationMs = math.max(60000, _reportTimelineDurationMs(report));
    final b = StringBuffer('<div class="svg-wrap"><svg viewBox="0 0 ${w.toInt()} ${h.toInt()}" xmlns="http://www.w3.org/2000/svg">');
    b.write('<rect width="$w" height="$h" rx="16" fill="#FAFBFC"/>');
    b.write('<text x="$left" y="21" fill="#111827" font-size="13" font-weight="900">Скорость, км/ч</text>');
    for (var i = 0; i <= 4; i++) {
      final y = top + rh - rh * i / 4;
      b.write('<line x1="$left" y1="$y" x2="${w - right}" y2="$y" stroke="#E5E7EB"/><text x="10" y="${y + 4}" fill="#667085" font-size="12" font-weight="800">${(maxSpeed * i / 4).round()}</text>');
      final x = left + rw * i / 4;
      b.write('<text x="$x" y="${h - 20}" text-anchor="middle" fill="#667085" font-size="11" font-weight="800">${_h(_reportElapsedLabel((durationMs * i / 4).round()))}</text>');
    }
    b.write('<text x="${w - right}" y="${h - 5}" text-anchor="end" fill="#667085" font-size="11" font-weight="800">время</text>');
    void threshold(double value, String color, String label) {
      if (value <= 0 || value > maxSpeed) return;
      final y = top + rh - rh * value / maxSpeed;
      b.write('<line x1="$left" y1="$y" x2="${w - right}" y2="$y" stroke="$color" stroke-width="2" stroke-opacity=".65"/><text x="${w - 145}" y="${y - 7}" fill="$color" font-size="13" font-weight="900">$label</text>');
    }
    threshold(hsr, '#F59E0B', 'HIR ${hsr.toStringAsFixed(1)} км/ч');
    threshold(sprint, '#DC2626', 'SPR ${sprint.toStringAsFixed(1)} км/ч');
    if (samples.isNotEmpty) {
      final path = StringBuffer();
      for (var i = 0; i < samples.length; i++) {
        final x = left + rw * (samples.length == 1 ? 0 : i / (samples.length - 1));
        final y = top + rh - rh * samples[i].clamp(0.0, maxSpeed) / maxSpeed;
        path.write('${i == 0 ? 'M' : 'L'}${x.toStringAsFixed(1)},${y.toStringAsFixed(1)} ');
      }
      b.write('<path d="$path" fill="none" stroke="#00A750" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>');
      final step = math.max(1, (samples.length / 12).ceil());
      for (var i = 0; i < samples.length; i += step) {
        final x = left + rw * (samples.length == 1 ? 0 : i / (samples.length - 1));
        final y = top + rh - rh * samples[i].clamp(0.0, maxSpeed) / maxSpeed;
        final c = _speedHex(samples[i], hsr, sprint);
        b.write('<circle cx="${x.toStringAsFixed(1)}" cy="${y.toStringAsFixed(1)}" r="5" fill="$c"/>');
      }
    } else {
      b.write('<text x="50%" y="50%" text-anchor="middle" fill="#667085" font-size="16" font-weight="900">Нет данных скорости</text>');
    }
    b.write('</svg></div>');
    return b.toString();
  }

  static String _radarSvg(List<TrackerTrainingPlayerRow> players) {
    final src = players
        .where((p) =>
            p.distanceM > 0 ||
            p.maxSpeedKmh > 0 ||
            p.playerLoad > 0 ||
            p.sprintCount > 0 ||
            p.highSpeedWorkM > 0)
        .toList(growable: false);
    const w = 980.0, h = 600.0, cx = 490.0, cy = 300.0, r = 215.0;
    const labels = ['Объём', 'Скорость', 'Спринты', 'HIR', 'Нагрузка'];
    double avg(double Function(TrackerTrainingPlayerRow p) pick) => src.isEmpty
        ? 0
        : src.fold<double>(0, (sum, p) => sum + pick(p)) / src.length;
    double normal(double v) =>
        v.isFinite ? v.clamp(0.0, 1.0).toDouble() : 0.0;
    final values = <double>[
      normal(avg((p) => p.distanceM) / 6000.0),
      normal(avg((p) => p.maxSpeedKmh) / 34.0),
      normal(avg((p) => p.sprintCount.toDouble()) / 25.0),
      normal(avg((p) => p.highSpeedWorkM) / 1200.0),
      normal(avg((p) => p.playerLoad) / 1000.0),
    ];
    final b = StringBuffer(
        '<div class="svg-wrap radar-large"><svg viewBox="0 0 ${w.toInt()} ${h.toInt()}" xmlns="http://www.w3.org/2000/svg" role="img">');
    b.write('<rect width="$w" height="$h" rx="16" fill="#FAFBFC"/>');
    for (var ring = 1; ring <= 4; ring++) {
      final pts = <String>[];
      for (var i = 0; i < labels.length; i++) {
        final a = -math.pi / 2 + i * math.pi * 2 / labels.length;
        final rr = r * ring / 4;
        pts.add('${(cx + math.cos(a) * rr).toStringAsFixed(1)},${(cy + math.sin(a) * rr).toStringAsFixed(1)}');
      }
      b.write('<polygon points="${pts.join(' ')}" fill="none" stroke="#E5E7EB" stroke-width="1.5"/>');
    }
    for (var i = 0; i < labels.length; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / labels.length;
      final ex = cx + math.cos(a) * r;
      final ey = cy + math.sin(a) * r;
      final lx = cx + math.cos(a) * (r + 58);
      final ly = cy + math.sin(a) * (r + 42);
      b.write('<line x1="$cx" y1="$cy" x2="${ex.toStringAsFixed(1)}" y2="${ey.toStringAsFixed(1)}" stroke="#E5E7EB" stroke-width="1.5"/>');
      b.write('<text x="${lx.toStringAsFixed(1)}" y="${ly.toStringAsFixed(1)}" text-anchor="middle" dominant-baseline="middle" fill="#5F6670" font-size="15" font-weight="850">${_h(labels[i])}</text>');
    }
    if (src.isNotEmpty) {
      final poly = <String>[];
      for (var i = 0; i < values.length; i++) {
        final a = -math.pi / 2 + i * math.pi * 2 / values.length;
        poly.add('${(cx + math.cos(a) * r * values[i]).toStringAsFixed(1)},${(cy + math.sin(a) * r * values[i]).toStringAsFixed(1)}');
      }
      b.write('<polygon points="${poly.join(' ')}" fill="#00A750" fill-opacity=".17" stroke="#00A750" stroke-width="4" stroke-linejoin="round"/>');
    } else {
      b.write('<text x="$cx" y="$cy" text-anchor="middle" fill="#667085" font-size="17" font-weight="850">Нет данных для радара</text>');
    }
    b.write('</svg></div>');
    return b.toString();
  }

  static String _dualBarSvg(
      List<TrackerTrainingPlayerRow> players,
      double Function(TrackerTrainingPlayerRow p) first,
      double Function(TrackerTrainingPlayerRow p) second,
      String firstLabel,
      String secondLabel) {
    final list = players.take(14).toList(growable: false);
    const w = 980.0,
        h = 360.0,
        left = 128.0,
        top = 24.0,
        right = 28.0,
        bottom = 26.0;
    final rh = h - top - bottom;
    final maxV = math.max(
            1.0,
            list.fold<double>(
                0, (m, p) => math.max(m, math.max(first(p), second(p))))) *
        1.10;
    final rowH = list.isEmpty ? 24.0 : rh / list.length;
    final b = StringBuffer(
        '<div class="svg-wrap"><svg viewBox="0 0 ${w.toInt()} ${h.toInt()}" xmlns="http://www.w3.org/2000/svg">');
    b.write(
        '<rect width="$w" height="$h" rx="16" fill="#FAFBFC"/><text x="$left" y="16" fill="#00A750" font-size="12" font-weight="950">${_h(firstLabel)}</text><text x="${left + 90}" y="16" fill="#F59E0B" font-size="12" font-weight="950">${_h(secondLabel)}</text>');
    if (list.isEmpty) {
      b.write(
          '<text x="50%" y="50%" text-anchor="middle" fill="#667085" font-size="16" font-weight="900">Нет игроков для графика</text></svg></div>');
      return b.toString();
    }
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final y = top + i * rowH + 4;
      final hBar = math.max(5.0, rowH * .32);
      final fw = (w - left - right) * (first(p).clamp(0.0, maxV) / maxV);
      final sw = (w - left - right) * (second(p).clamp(0.0, maxV) / maxV);
      b.write(
          '<text x="8" y="${y + hBar + 3}" fill="#374151" font-size="11" font-weight="900">${_h(_shortReportPlayerName(p.name))}</text>');
      b.write(
          '<rect x="$left" y="$y" width="$fw" height="$hBar" rx="5" fill="#00A750" opacity=".88"/>');
      b.write(
          '<rect x="$left" y="${y + hBar + 4}" width="$sw" height="$hBar" rx="5" fill="#F59E0B" opacity=".86"/>');
    }
    b.write('</svg></div>');
    return b.toString();
  }

  static String _hrSvg(
      TrackerTrainingReport report, List<TrackerHeartRatePoint> points) {
    final list = _sample(
        points.where((p) => p.bpm > 0).toList(growable: false)
          ..sort((a, b) => _hrPointSortKey(a).compareTo(_hrPointSortKey(b))),
        900);
    const w = 980.0, h = 360.0, left = 58.0, top = 38.0, right = 22.0, bottom = 54.0;
    final rw = w - left - right, rh = h - top - bottom;
    final b = StringBuffer('<div class="svg-wrap"><svg viewBox="0 0 ${w.toInt()} ${h.toInt()}" xmlns="http://www.w3.org/2000/svg">');
    b.write('<rect width="$w" height="$h" rx="16" fill="#FAFBFC"/>');
    b.write('<text x="$left" y="21" fill="#111827" font-size="13" font-weight="900">ЧСС, уд/мин · Кардиодатчик</text>');
    double minX = 0, maxX = 60000;
    if (list.isNotEmpty) {
      minX = _hrPointSortKey(list.first).toDouble();
      maxX = _hrPointSortKey(list.last).toDouble();
      if ((maxX - minX).abs() < 1) maxX = minX + 60000;
    }
    final minBpm = list.isEmpty ? 60.0 : math.max(40.0, list.map((p) => p.bpm).reduce((a, b) => a < b ? a : b).toDouble() - 10);
    final maxBpm = list.isEmpty ? 200.0 : math.max(130.0, list.map((p) => p.bpm).reduce((a, b) => a > b ? a : b).toDouble() + 14);
    for (var i = 0; i <= 4; i++) {
      final y = top + rh - rh * i / 4;
      final bpm = minBpm + (maxBpm - minBpm) * i / 4;
      b.write('<line x1="$left" y1="$y" x2="${w - right}" y2="$y" stroke="#E5E7EB"/><text x="10" y="${y + 4}" fill="#667085" font-size="12" font-weight="800">${bpm.round()}</text>');
      final x = left + rw * i / 4;
      b.write('<text x="$x" y="${h - 20}" text-anchor="middle" fill="#667085" font-size="11" font-weight="800">${_h(_reportElapsedLabel(((maxX - minX) * i / 4).round()))}</text>');
    }
    b.write('<text x="${w - right}" y="${h - 5}" text-anchor="end" fill="#667085" font-size="11" font-weight="800">время</text>');
    if (list.isNotEmpty) {
      final path = StringBuffer();
      for (var i = 0; i < list.length; i++) {
        final p = list[i];
        final x = left + rw * ((_hrPointSortKey(p) - minX) / (maxX - minX)).clamp(0.0, 1.0);
        final y = top + rh - rh * ((p.bpm - minBpm) / (maxBpm - minBpm)).clamp(0.0, 1.0);
        path.write('${i == 0 ? 'M' : 'L'}${x.toStringAsFixed(1)},${y.toStringAsFixed(1)} ');
      }
      b.write('<path d="$path" fill="none" stroke="#EF4444" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>');
      final step = math.max(1, (list.length / 12).ceil());
      for (var i = 0; i < list.length; i += step) {
        final p = list[i];
        final x = left + rw * ((_hrPointSortKey(p) - minX) / (maxX - minX)).clamp(0.0, 1.0);
        final y = top + rh - rh * ((p.bpm - minBpm) / (maxBpm - minBpm)).clamp(0.0, 1.0);
        b.write('<circle cx="${x.toStringAsFixed(1)}" cy="${y.toStringAsFixed(1)}" r="5" fill="#EF4444"/>');
      }
    } else {
      b.write('<text x="50%" y="50%" text-anchor="middle" fill="#667085" font-size="16" font-weight="900">Нет данных ЧСС</text>');
    }
    final avgHrLabel = report.summary.heartRateAvgBpm > 0 ? report.summary.heartRateAvgBpm.toStringAsFixed(0) : '—';
    final maxHrLabel = report.summary.heartRateMaxBpm > 0 ? report.summary.heartRateMaxBpm.toStringAsFixed(0) : '—';
    b.write('</svg></div><div class="legend">${points.length} точек ЧСС · средняя $avgHrLabel уд/мин · максимум $maxHrLabel уд/мин</div>');
    return b.toString();
  }

  static String _microcycleSvg(TrackerTrainingReport report) {
    final points = report.microcycle;
    if (points.isEmpty)
      return '<div class="muted">Микроцикл не пришёл с сервера.</div>';
    const w = 980.0,
        h = 340.0,
        left = 54.0,
        top = 22.0,
        right = 20.0,
        bottom = 46.0;
    final rw = w - left - right, rh = h - top - bottom;
    final maxV = math.max(
        1.0,
        points.fold<double>(
            0,
            (m, p) => math.max(
                m,
                math.max(p.distanceM,
                    math.max(p.highSpeedRunningM, p.accDec * 100)))));
    final b = StringBuffer(
        '<div class="svg-wrap"><svg viewBox="0 0 ${w.toInt()} ${h.toInt()}" xmlns="http://www.w3.org/2000/svg">');
    b.write('<rect width="$w" height="$h" rx="16" fill="#FAFBFC"/>');
    String poly(double Function(TrackerMicrocyclePoint p) value, String color) {
      final path = StringBuffer();
      for (var i = 0; i < points.length; i++) {
        final x =
            left + rw * (points.length == 1 ? 0 : i / (points.length - 1));
        final y = top + rh - rh * (value(points[i]).clamp(0.0, maxV) / maxV);
        final cmd = i == 0 ? 'M' : 'L';
        path.write('$cmd${x.toStringAsFixed(1)},${y.toStringAsFixed(1)} ');
      }
      return '<path d="$path" fill="none" stroke="$color" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>';
    }

    b.write(poly((p) => p.distanceM, '#00A750'));
    b.write(poly((p) => p.highSpeedRunningM, '#F59E0B'));
    b.write(poly((p) => p.accDec * 100, '#2563EB'));
    for (var i = 0; i < points.length; i++) {
      final x = left + rw * (points.length == 1 ? 0 : i / (points.length - 1));
      b.write(
          '<text x="$x" y="${h - 18}" text-anchor="middle" fill="#667085" font-size="11" font-weight="850">${_h(points[i].label)}</text>');
    }
    b.write(
        '</svg></div><div class="legend"><span><i class="dot" style="background:#00A750"></i>дистанция</span><span><i class="dot" style="background:#F59E0B"></i>ВСБ</span><span><i class="dot" style="background:#2563EB"></i>уск/торм</span></div>');
    return b.toString();
  }

  static String _playerCards(
      TrackerTrainingReport report, List<TrackerTrainingPlayerRow> players) {
    if (players.isEmpty)
      return '<div class="muted">Нет игроков для индивидуальных страниц.</div>';
    final b = StringBuffer('<div class="player-grid">');
    for (final p in players.take(24)) {
      final avatar = p.avatarUrl.trim().isEmpty
          ? _h(p.name.trim().isEmpty
              ? '?'
              : p.name.trim().substring(0, 1).toUpperCase())
          : '<img src="${_h(p.avatarUrl)}" alt="">';
      final pts = report.routePoints
          .where((pt) => _samePlayerPoint(pt, p))
          .toList(growable: false);
      final pReport = TrackerTrainingReport(
        sessionId: report.sessionId,
        sessionIds: report.sessionIds,
        title: report.title,
        dateLabel: report.dateLabel,
        teamId: report.teamId,
        clubId: report.clubId,
        teamName: report.teamName,
        teamLogoUrl: report.teamLogoUrl,
        opponent: report.opponent,
        durationLabel: p.duration,
        playersCount: 1,
        pointsCount: pts.length,
        hasData: report.hasData,
        dataStatus: report.dataStatus,
        summary: report.summary,
        periods: report.periods,
        microcycle: report.microcycle,
        players: [p],
        routePoints: pts,
        heatmapPoints: pts,
        speedZones: report.speedZones,
        heartRateTimeline: report.heartRateTimeline
            .where((hr) => _sameHrPoint(hr, p))
            .toList(growable: false),
        events: report.events
            .where((event) => _sameEventPlayer(event, p))
            .toList(growable: false),
      );
      b.write(
          '<div class="player-card"><div class="player-head"><div class="avatar">$avatar</div><div><div class="player-name">${_h(p.name)}</div><div class="muted">${_h(p.duration)} · ${_m(p.distanceM)} · max ${_f(p.maxSpeedKmh)} км/ч · HR ${p.heartRateSamplesCount}</div></div></div>');
      b.write(
          '<div class="grid grid-2"><div>${_mapSvg(pts, heatMode: false, report: pReport, events: pReport.events)}</div><div>${_speedSvg(pReport)}</div></div></div>');
    }
    b.write('</div>');
    return b.toString();
  }

  static String _aiBlock(TrackerTrainingReport report) {
    final players = _reportPlayers(report);
    final withHr = players.where((p) => p.heartRateSamplesCount > 0).length;
    final withGps =
        players.where((p) => p.pointsCount > 0 || p.distanceM > 0).length;
    final items = [
      'Проверено: ${players.length} игрок(ов), $withGps с GPS-данными и $withHr с кардиодатчиком.',
      ..._reportCoachMessages(report),
    ];
    final b = StringBuffer('<ul class="coach-list">');
    for (final item in items) b.write('<li>${_h(item)}</li>');
    b.write('</ul>');
    return b.toString();
  }

  static bool _samePlayerPoint(
      TrackerReportPoint point, TrackerTrainingPlayerRow player) {
    if (point.playerId != null &&
        player.playerId != null &&
        point.playerId == player.playerId) return true;
    return point.playerName.trim().isNotEmpty &&
        point.playerName.trim().toLowerCase() ==
            player.name.trim().toLowerCase();
  }

  static bool _sameHrPoint(
      TrackerHeartRatePoint point, TrackerTrainingPlayerRow player) {
    if (point.playerId != null &&
        player.playerId != null &&
        point.playerId == player.playerId) return true;
    return point.playerName.trim().isNotEmpty &&
        point.playerName.trim().toLowerCase() ==
            player.name.trim().toLowerCase();
  }

  static bool _sameEventPlayer(
      TrackerReportEvent event, TrackerTrainingPlayerRow player) {
    if (event.playerId != null &&
        player.playerId != null &&
        event.playerId == player.playerId) return true;
    return event.playerName.trim().isNotEmpty &&
        event.playerName.trim().toLowerCase() ==
            player.name.trim().toLowerCase();
  }

  static String _speedHex(double speed, double hsr, double sprint) {
    if (speed >= sprint) return '#DC2626';
    if (speed >= hsr) return '#F59E0B';
    if (speed >= 7) return '#00A750';
    return '#2563EB';
  }

  static List<T> _sample<T>(List<T> list, int max) {
    if (list.length <= max || max <= 0) return list;
    final out = <T>[];
    for (var i = 0; i < max; i++) {
      out.add(list[(i * (list.length - 1) / (max - 1)).round()]);
    }
    return out;
  }
}

class _Kpi {
  const _Kpi(this.title, this.value, this.note);
  final String title;
  final String value;
  final String note;
}

class _ReportType {
  static TextStyle title([double size = 16]) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _R.text,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle section([double size = 12.2]) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _R.text,
        height: 1.20,
        letterSpacing: 0,
      );

  static TextStyle body([double size = 11.4]) => AppTypography.custom(
        size: size,
        weight: FontWeight.w500,
        color: _R.graphite,
        height: 1.28,
        letterSpacing: 0,
      );

  static TextStyle caption([double size = 10.4]) => AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: _R.muted,
        height: 1.25,
        letterSpacing: 0,
      );

  static TextStyle action({bool primary = false}) => AppTypography.custom(
        size: 11.3,
        weight: FontWeight.w600,
        color: primary ? Colors.white : _R.greenDark,
        height: 1.0,
        letterSpacing: 0,
      );
}

class _R {
  static const bg = Color(0xFFFFFFFF);
  static const panel = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF7F8F7);
  static const border = Color(0xFFE9ECEA);
  static const text = Color(0xFF0B0F14);
  static const graphite = Color(0xFF111827);
  static const muted = Color(0xFF5F6670);
  static const muted2 = Color(0xFF8A9099);
  static const darkGreen = Color(0xFF067A46);
  static const greenDark = Color(0xFF067A46);
  static const green = Color(0xFF00A750);
  static const greenLine = Color(0xFFD7F0E2);
  static const softGreen = Color(0xFFF3FAF6);
  static const lightGreen = Color(0xFFF8FEFA);
  static const lime = Color(0xFFA3E635);
  static const red = Color(0xFFEF4444);

  // На телефоне отчёт читается как самостоятельный аналитический документ:
  // заметные поля, мягкие карточки и единая геометрия модальных действий.
  // Геометрия синхронизирована с основной Analytics/CMR оболочкой.
  static const double mobilePagePadding = 8.0;
  static const double mobileCardRadius = 18.0;
  static const double mobileInnerRadius = 12.0;
  static const double mobileButtonRadius = 12.0;
  static const double tabletCardRadius = 16.0;
  static const double tabletInnerRadius = 12.0;
  static const double sheetRadius = 18.0;
}

class _RText {
  // V182: та же визуальная шкала, что PpText в Player Profile.
  static double _titleSize(double requested) {
    if (requested >= 17) return 18;
    if (requested >= 15) return 16;
    return 14;
  }

  static double _bodySize(double requested) {
    if (requested < 9.4) return 9.5;
    if (requested < 10.6) return 10.2;
    if (requested < 11.7) return 11;
    if (requested < 12.7) return 12;
    return 13;
  }

  static double _valueSize(double requested) {
    if (requested >= 16.5) return 17;
    if (requested >= 14.5) return 15;
    return 14;
  }

  static TextStyle title(double size, {Color color = _R.text}) =>
      AppTypography.custom(
        size: _titleSize(size),
        weight: FontWeight.w600,
        color: color,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle body(
    double size, {
    Color color = _R.muted,
    FontWeight weight = FontWeight.w400,
  }) =>
      AppTypography.custom(
        size: _bodySize(size),
        weight: weight,
        color: color,
        height: 1.30,
        letterSpacing: 0,
      );

  static TextStyle value(double size, {Color color = _R.text}) =>
      AppTypography.custom(
        size: _valueSize(size),
        weight: FontWeight.w600,
        color: color,
        height: 1.12,
        letterSpacing: 0,
      );

  static TextStyle caption({double size = 10.2, Color color = _R.muted2}) =>
      AppTypography.custom(
        size: size < 10 ? 9.5 : 10.2,
        weight: FontWeight.w500,
        color: color,
        height: 1.18,
        letterSpacing: 0,
      );
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
    );
  }
}

// Sportoteka Performance Matrix 2.0.
// The matrix combines the Catapult-style general/mechanical/locomotor view
// с данными кардиодатчика и прозрачными производными показателями нагрузки.
class _PerformanceMatrix extends StatelessWidget {
  const _PerformanceMatrix({required this.players});
  final List<TrackerTrainingPlayerRow> players;

  @override
  Widget build(BuildContext context) {
    final rows =
        players.where((p) => p.name.trim().isNotEmpty).toList(growable: false);
    if (rows.isEmpty)
      return const _EmptyBlock('Нет игроков с данными для матрицы нагрузки.');
    final avgLoad =
        rows.fold<double>(0, (v, p) => v + p.playerLoad) / rows.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Wrap(spacing: 8, runSpacing: 8, children: const [
          _MatrixLegend(color: Color(0xFFDFF4E8), label: 'оптимально'),
          _MatrixLegend(color: Color(0xFFFFF1B8), label: 'повышено'),
          _MatrixLegend(color: Color(0xFFFFD8D8), label: 'высоко'),
          _MatrixLegend(color: Color(0xFFE9EEF3), label: 'нет данных'),
        ]),
      ),
      SingleChildScrollView(
        primary: false,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1880,
          child: Table(
            border: TableBorder.symmetric(inside: BorderSide(color: _R.border)),
            columnWidths: const {
              0: FixedColumnWidth(210),
              1: FixedColumnWidth(82),
              2: FixedColumnWidth(90),
              3: FixedColumnWidth(78),
              4: FixedColumnWidth(82),
              5: FixedColumnWidth(82),
              6: FixedColumnWidth(76),
              7: FixedColumnWidth(76),
              8: FixedColumnWidth(76),
              9: FixedColumnWidth(76),
              10: FixedColumnWidth(82),
              11: FixedColumnWidth(82),
              12: FixedColumnWidth(82),
              13: FixedColumnWidth(78),
              14: FixedColumnWidth(82),
              15: FixedColumnWidth(86),
              16: FixedColumnWidth(86),
              17: FixedColumnWidth(90),
              18: FixedColumnWidth(92),
              19: FixedColumnWidth(94),
            },
            children: [
              _matrixGroupRow(),
              _matrixHeaderRow(),
              ...rows.map((p) => _matrixPlayerRow(p, avgLoad)),
              _matrixAverageRow(rows, avgLoad),
            ],
          ),
        ),
      ),
    ]);
  }

  TableRow _matrixGroupRow() => TableRow(children: [
        _groupCell('ИГРОК', const Color(0xFFF4F6F7)),
        _groupCell('ОБЩАЯ ИНФОРМАЦИЯ', const Color(0xFFF4F6F7), spanHint: true),
        for (var i = 0; i < 4; i++) _groupCell('', const Color(0xFFF4F6F7)),
        _groupCell('МЕХАНИЧЕСКАЯ НАГРУЗКА', const Color(0xFFEAF6EC),
            spanHint: true),
        for (var i = 0; i < 3; i++) _groupCell('', const Color(0xFFEAF6EC)),
        _groupCell('ЛОКОМОТОРНАЯ НАГРУЗКА', const Color(0xFFFFEEEE),
            spanHint: true),
        for (var i = 0; i < 4; i++) _groupCell('', const Color(0xFFFFEEEE)),
        _groupCell('ВНУТРЕННЯЯ / КОНТРОЛЬ', const Color(0xFFF1EDFF),
            spanHint: true),
        for (var i = 0; i < 4; i++) _groupCell('', const Color(0xFFF1EDFF)),
      ]);

  TableRow _matrixHeaderRow() => _tableRow([
        'Игрок',
        'Время',
        'Дист. м',
        'м/мин',
        'Макс.',
        'Нагрузка',
        'Уск.',
        'Торм.',
        'УСК+ТОР/мин',
        'Взрыв.',
        'V3',
        'V4 HSR',
        'V5 спринт',
        'Спр.',
        'V4+V5',
        'HR ср.',
        'HR max',
        'Интенс.',
        'Баланс',
        'Статус'
      ], header: true);

  TableRow _matrixPlayerRow(TrackerTrainingPlayerRow p, double avgLoad) {
    final intensity = _intensity(p);
    final balance = _balance(p, avgLoad);
    final status = _status(p, intensity, balance);
    return TableRow(
        decoration: const BoxDecoration(color: Colors.white),
        children: [
          _playerCell(p, false),
          _cell(p.duration),
          _matrixValue(p.distanceM.toStringAsFixed(0), p.distanceM / 7000),
          _matrixValue(p.metersPerMin.toStringAsFixed(1), p.metersPerMin / 130),
          _matrixValue(p.maxSpeedKmh.toStringAsFixed(1), p.maxSpeedKmh / 30),
          _matrixValue(p.playerLoad.toStringAsFixed(0),
              avgLoad <= 0 ? 0 : p.playerLoad / avgLoad),
          _matrixValue('${p.accelerations}', p.accelerations / 24),
          _matrixValue('${p.decelerations}', p.decelerations / 24),
          _matrixValue(p.accDecPerMin.toStringAsFixed(1), p.accDecPerMin / 3),
          _matrixValue('${p.explosiveActions}', p.explosiveActions / 36),
          _matrixValue(p.v3RunM.toStringAsFixed(0), p.v3RunM / 1300),
          _matrixValue(p.v4HsrM.toStringAsFixed(0), p.v4HsrM / 500),
          _matrixValue(p.v5SprintM.toStringAsFixed(0), p.v5SprintM / 140),
          _matrixValue('${p.sprintCount}', p.sprintCount / 20),
          _matrixValue(
              p.highSpeedWorkM.toStringAsFixed(0), p.highSpeedWorkM / 650),
          _matrixValue(
              p.heartRateAvgBpm > 0
                  ? p.heartRateAvgBpm.toStringAsFixed(0)
                  : '—',
              p.heartRateAvgBpm / 170),
          _matrixValue(
              p.heartRateMaxBpm > 0
                  ? p.heartRateMaxBpm.toStringAsFixed(0)
                  : '—',
              p.heartRateMaxBpm / 195),
          _matrixValue('${(intensity * 100).round()}%', intensity),
          _matrixValue('${(balance * 100).round()}%', balance),
          _statusCell(status),
        ]);
  }

  TableRow _matrixAverageRow(
      List<TrackerTrainingPlayerRow> rows, double avgLoad) {
    double a(double Function(TrackerTrainingPlayerRow) f) =>
        rows.fold<double>(0, (v, p) => v + f(p)) / rows.length;
    int ai(int Function(TrackerTrainingPlayerRow) f) =>
        (rows.fold<int>(0, (v, p) => v + f(p)) / rows.length).round();
    return TableRow(
        decoration: const BoxDecoration(color: Color(0xFFE8ECE9)),
        children: [
          _cell('СРЕДНЕЕ', bold: true),
          _cell('—'),
          _cell(a((p) => p.distanceM).toStringAsFixed(0), bold: true),
          _cell(a((p) => p.metersPerMin).toStringAsFixed(1), bold: true),
          _cell(a((p) => p.maxSpeedKmh).toStringAsFixed(1), bold: true),
          _cell(avgLoad.toStringAsFixed(0), bold: true),
          _cell('${ai((p) => p.accelerations)}', bold: true),
          _cell('${ai((p) => p.decelerations)}', bold: true),
          _cell(a((p) => p.accDecPerMin).toStringAsFixed(1), bold: true),
          _cell('${ai((p) => p.explosiveActions)}', bold: true),
          _cell(a((p) => p.v3RunM).toStringAsFixed(0), bold: true),
          _cell(a((p) => p.v4HsrM).toStringAsFixed(0), bold: true),
          _cell(a((p) => p.v5SprintM).toStringAsFixed(0), bold: true),
          _cell('${ai((p) => p.sprintCount)}', bold: true),
          _cell(a((p) => p.highSpeedWorkM).toStringAsFixed(0), bold: true),
          _cell(a((p) => p.heartRateAvgBpm).toStringAsFixed(0), bold: true),
          _cell(a((p) => p.heartRateMaxBpm).toStringAsFixed(0), bold: true),
          _cell('${(a(_intensity) * 100).round()}%', bold: true),
          _cell('100%', bold: true),
          _cell('КОМАНДА', bold: true),
        ]);
  }

  double _intensity(TrackerTrainingPlayerRow p) {
    final external = ((p.metersPerMin / 130) * .34 +
        (p.highSpeedWorkM / 650) * .26 +
        (p.explosiveActions / 36) * .20 +
        (p.maxSpeedKmh / 30) * .20);
    final internal =
        p.heartRateAvgBpm > 0 ? (p.heartRateAvgBpm / 180) : external;
    return (external * .7 + internal * .3).clamp(0.0, 1.35).toDouble();
  }

  double _balance(TrackerTrainingPlayerRow p, double avgLoad) {
    if (avgLoad <= 0) return 0;
    final ratio = p.playerLoad / avgLoad;
    return (1 - (ratio - 1).abs()).clamp(0.0, 1.0).toDouble();
  }

  String _status(TrackerTrainingPlayerRow p, double intensity, double balance) {
    if (p.distanceM <= 0 && p.heartRateSamplesCount <= 0) return 'НЕТ ДАННЫХ';
    if (intensity >= 1.08 || balance < .62) return 'ВЫСОКО';
    if (intensity >= .88 || balance < .78) return 'ПОВЫШЕНО';
    return 'ОПТИМАЛЬНО';
  }

  Widget _matrixValue(String text, double ratio) {
    if (text == '—') return _cell(text);
    final r = ratio.isFinite ? ratio : 0.0;
    final color = r >= 1.08
        ? const Color(0xFFFFD8D8)
        : r >= .88
            ? const Color(0xFFFFF1B8)
            : r > 0
                ? const Color(0xFFDFF4E8)
                : const Color(0xFFE9EEF3);
    return Container(
        height: 38,
        alignment: Alignment.center,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text,
            maxLines: 1,
            style: const TextStyle(
                fontSize: 10.2, fontWeight: FontWeight.w800, color: _R.text)));
  }

  Widget _statusCell(String status) {
    final color = status == 'ВЫСОКО'
        ? const Color(0xFFFFD8D8)
        : status == 'ПОВЫШЕНО'
            ? const Color(0xFFFFF1B8)
            : status == 'ОПТИМАЛЬНО'
                ? const Color(0xFFDFF4E8)
                : const Color(0xFFE9EEF3);
    return Container(
        height: 38,
        alignment: Alignment.center,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(status,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 8.6, fontWeight: FontWeight.w900, color: _R.text)));
  }

  Widget _groupCell(String text, Color color,
          {bool spanHint = false}) =>
      Container(
          height: 32,
          alignment: Alignment.center,
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
              text,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: spanHint ? 9.2 : 8,
                  fontWeight: FontWeight.w900,
                  color: _R.text)));
}

class _MatrixLegend extends StatelessWidget {
  const _MatrixLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: _R.muted))
      ]);
}
