import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/action_tracker_protocol.dart';
import '../models/tracker_pro_models.dart';
import '../models/tracker_pitch_projection.dart';
import '../services/tracker_pro_api.dart';
import '../reports/tracker_training_report_screen.dart';
import 'player_training_calendar_panel.dart';


DateTime? _trackerParseServerInstant(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty || raw == 'null') return null;
  final normalized = raw.replaceFirst(' ', 'T');
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
      .hasMatch(normalized);
  if (hasZone) return DateTime.tryParse(normalized)?.toUtc();

  final naive = DateTime.tryParse(normalized);
  if (naive == null) return null;
  // Серверные MySQL-строки без timezone считаем UTC.
  return DateTime.utc(
    naive.year,
    naive.month,
    naive.day,
    naive.hour,
    naive.minute,
    naive.second,
    naive.millisecond,
    naive.microsecond,
  );
}

DateTime? _trackerMoscowDateTime(dynamic value) {
  final instant = _trackerParseServerInstant(value);
  if (instant == null) return null;
  final moscow = instant.add(const Duration(hours: 3));
  // Возвращаем wall-clock Moscow без зависимости от timezone устройства.
  return DateTime(
    moscow.year,
    moscow.month,
    moscow.day,
    moscow.hour,
    moscow.minute,
    moscow.second,
    moscow.millisecond,
    moscow.microsecond,
  );
}

DateTime _trackerMoscowFromEpochMs(int millisecondsSinceEpoch) {
  final moscow = DateTime.fromMillisecondsSinceEpoch(
    millisecondsSinceEpoch,
    isUtc: true,
  ).add(const Duration(hours: 3));
  return DateTime(
    moscow.year,
    moscow.month,
    moscow.day,
    moscow.hour,
    moscow.minute,
    moscow.second,
    moscow.millisecond,
    moscow.microsecond,
  );
}


class TrackerActionAnalyticsSuite extends StatefulWidget {
  const TrackerActionAnalyticsSuite({
    super.key,
    required this.api,
    required this.teamId,
    required this.teamName,
    this.clubName = 'Футбольный клуб «Гомель»',
    required this.players,
    required this.selectedPlayer,
    this.playerFilterLabel = 'команда',
    required this.selectedField,
    required this.localPoints,
    required this.selectedSession,
    required this.onRefresh,
    required this.onSelectPlayer,
    required this.onSelectSession,
    required this.onOpenCalibration,
    this.onClearField,
    required this.onOpenSessions,
    required this.onOpenLive,
    required this.onRequestOfflineRecords,
    required this.onSaveOfflineSession,
    required this.liveRunning,
    required this.commandChannelReady,
    required this.offlineRecordsCount,
    required this.localPointsCount,
    required this.onDebug,
    this.initialTab = 0,
    this.initialTabSignal = 0,
    this.initialCalendarMode = PlayerTrainingCalendarMode.team,
    this.initialCalendarModeSignal = 0,
    this.onOpenAiLoadPoint,
    this.onOpenAiAnalysis,
  });

  final TrackerProApi api;
  final int teamId;
  final String teamName;
  final String clubName;
  final List<TrackerPlayerOption> players;
  final TrackerPlayerOption? selectedPlayer;
  final String playerFilterLabel;
  final TrackerFieldModel? selectedField;
  final List<ActionTrackerGpsPoint> localPoints;
  final TrackerSessionModel? selectedSession;
  final VoidCallback onRefresh;
  final ValueChanged<int> onSelectPlayer;
  final ValueChanged<TrackerSessionModel> onSelectSession;
  final VoidCallback onOpenCalibration;
  final VoidCallback? onClearField;
  final VoidCallback onOpenSessions;
  final VoidCallback onOpenLive;
  final VoidCallback onRequestOfflineRecords;
  final VoidCallback onSaveOfflineSession;
  final bool liveRunning;
  final bool commandChannelReady;
  final int offlineRecordsCount;
  final int localPointsCount;
  final void Function(String message, Map<String, dynamic> context) onDebug;
  final int initialTab;
  final int initialTabSignal;
  final PlayerTrainingCalendarMode initialCalendarMode;
  final int initialCalendarModeSignal;
  final ValueChanged<Map<String, dynamic>>? onOpenAiLoadPoint;
  final ValueChanged<Map<String, dynamic>>? onOpenAiAnalysis;

  @override
  State<TrackerActionAnalyticsSuite> createState() => _TrackerActionAnalyticsSuiteState();
}

class _TrackerActionAnalyticsSuiteState extends State<TrackerActionAnalyticsSuite> {
  int _tab = 0;
  int _reload = 0;
  bool _gpsOffsetFix = true;
  String _gpsOffsetMode = 'auto';
  double _linearDepth = 3.0;
  double _mapRotationDeg = 0.0;
  double _sprintThresholdKmh = 18.0;
  double _hsrThresholdKmh = 14.0;
  bool _offlineGpsMode = true;
  bool _showSprintArrows = true;
  bool _showHeatMapMode = false;
  DateTime _selectedDate = DateTime.now();
  bool _onlySelectedDate = true;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final Set<int> _selectedSessionIds = <int>{};
  final Set<int> _selectedPlayerIds = <int>{};
  bool _useAllSessionsForPeriod = true;
  PlayerTrainingCalendarMode _sessionKindFilter = PlayerTrainingCalendarMode.team;
  bool _trackerCalendarExpanded = false;
  bool _trackerCalendarLoading = false;
  int _trackerCalendarRequest = 0;
  List<TrackerSessionModel> _trackerCalendarSessions = const <TrackerSessionModel>[];
  _CoachInsight? _coachInsight;
  String? _inlineAnalyticsPicker; // calendar / players / type — встроенный выбор без модальных окон
  String _reportPlayerSelectionKey() {
    final ids = _selectedPlayerIds.toList()..sort();
    return ids.isEmpty ? 'all' : ids.join('-');
  }

  Future<void> _openReportSelectorModal(TrackerSessionModel session) async {
    const routeName = 'tracker_report_workspace';
    var closing = false;

    Future<void> closeReportWorkspace() async {
      if (closing) return;
      closing = true;

      // Сначала возвращаем аналитику в «Обзор». Затем закрываем ровно один
      // внешний route отчёта. popUntil здесь не используется: при изменении
      // размера окна или во время анимации он мог остановиться на уже
      // закрывающемся внутреннем Dialog и оставлять белый экран.
      if (mounted) {
        setState(() {
          _tab = 0;
          _coachInsight = null;
          _inlineAnalyticsPicker = null;
        });
      }

      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;

      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();
    }

    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      routeSettings: const RouteSettings(name: routeName),
      barrierDismissible: false,
      barrierLabel: 'Выбор отчёта',
      barrierColor: Colors.black12,
      transitionDuration: const Duration(milliseconds: 140),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: child,
        );
      },
      pageBuilder: (_, __, ___) => Material(
        color: Colors.transparent,
        child: SafeArea(
          minimum: const EdgeInsets.all(6),
          child: TrackerTrainingReportScreen(
            key: ValueKey('analytics_report_modal_${session.id}_${_reportPlayerSelectionKey()}'),
            sessionId: session.id,
            teamId: widget.teamId,
            teamName: widget.teamName,
            embedded: true,
            selectionOnly: true,
            autoOpenSelection: true,
            initialSelectedPlayerIds: Set<int>.from(_selectedPlayerIds),
            onSelectionClosed: closeReportWorkspace,
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (_tab != 0 || _coachInsight != null || _inlineAnalyticsPicker != null) {
      setState(() {
        _tab = 0;
        _coachInsight = null;
        _inlineAnalyticsPicker = null;
      });
    }
    widget.onDebug('Закрыт выбор отчёта — возврат в обзор', {
      'session_id': session.id,
    });
  }


  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, _tabs.length - 1).toInt();
    _sessionKindFilter = widget.initialCalendarMode;
    final speedProfile = _YouthSpeedProfile.fromLabel(widget.teamName);
    _hsrThresholdKmh = speedProfile.hsrKmh;
    _sprintThresholdKmh = speedProfile.sprintKmh;
    _syncSelectedSessionFromWidget();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDebug('GPS-аналитика открыта', {
        'team_id': widget.teamId,
        'player_id': widget.selectedPlayer?.id,
        'field_id': widget.selectedField?.id,
        'local_points': widget.localPoints.length,
      });
    });
  }


  @override
  void didUpdateWidget(covariant TrackerActionAnalyticsSuite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabSignal != widget.initialTabSignal) {
      final nextTab = widget.initialTab.clamp(0, _tabs.length - 1).toInt();
      if (_tab != nextTab) {
        _tab = nextTab;
        _coachInsight = null;
      }
    }
    if (oldWidget.initialCalendarModeSignal != widget.initialCalendarModeSignal) {
      _sessionKindFilter = widget.initialCalendarMode;
      _trackerCalendarSessions = const <TrackerSessionModel>[];
      _trackerCalendarRequest++;
      _reload++;
    }
    if (oldWidget.selectedSession?.id != widget.selectedSession?.id) {
      // didUpdateWidget и так вызывает последующий build. setState/addPostFrame здесь
      // провоцировали rebuild календаря во время desktop mouse update.
      _syncSelectedSessionFromWidget(force: true);
      _reload++;
    }
  }

  void _syncSelectedSessionFromWidget({bool force = false}) {
    final session = widget.selectedSession;
    if (session == null || session.id <= 0) return;
    final dt = _sessionDateTime(session);
    if (dt != null) _selectedDate = DateTime(dt.year, dt.month, dt.day);
    if (force || _selectedSessionIds.isEmpty) {
      _useAllSessionsForPeriod = false;
      _selectedSessionIds
        ..clear()
        ..add(session.id);
    }
  }

  void _openCoachInsight(_CoachInsight insight) {
    if (!mounted) return;
    setState(() => _coachInsight = insight);
  }

  void _closeCoachInsight() {
    if (!mounted) return;
    setState(() => _coachInsight = null);
  }

  void _refresh() {
    setState(() => _reload++);
    widget.onRefresh();
    widget.onDebug('GPS-аналитика обновлена', {
      'tab': _tab,
      'team_id': widget.teamId,
      'player_id': widget.selectedPlayer?.id,
      'field_id': widget.selectedField?.id,
    });
  }


  void _toggleInlineAnalyticsPicker(String mode) {
    _deferMouseSafe(() {
      if (!mounted) return;
      setState(() {
        _inlineAnalyticsPicker = _inlineAnalyticsPicker == mode ? null : mode;
      });
      if ((mode == 'calendar' || mode == 'players') && _inlineAnalyticsPicker == mode) {
        _ensureTrackerCalendarSessions();
      }
    }, milliseconds: 80);
  }

  void _showInlineAnalyticsPicker(String mode) {
    _deferMouseSafe(() {
      if (!mounted) return;
      setState(() => _inlineAnalyticsPicker = mode);
      if (mode == 'calendar' || mode == 'players') {
        _ensureTrackerCalendarSessions();
      }
    }, milliseconds: 80);
  }

  void _closeInlineAnalyticsPicker() {
    _deferMouseSafe(() {
      if (!mounted) return;
      setState(() => _inlineAnalyticsPicker = null);
    }, milliseconds: 80);
  }

  void _applyInlinePlayerFilter(Set<int> ids) {
    _deferMouseSafe(() {
      if (!mounted) return;
      final chosenIds = Set<int>.from(ids);
      setState(() {
        _selectedPlayerIds
          ..clear()
          ..addAll(chosenIds);
        _useAllSessionsForPeriod = true;
        _selectedSessionIds.clear();
        // Не очищаем _trackerCalendarSessions при выборе игрока: этот список
        // используется для визуальной подписи в карточках игроков внутри панели
        // «Выбор». Иначе сразу после тапа карточка становится активной, но
        // подпись временно меняется на «сессии на дату нет», хотя сессия есть.
        _reload++;
      });
      if (chosenIds.length == 1) {
        final id = chosenIds.first;
        if (widget.selectedPlayer?.id != id) widget.onSelectPlayer(id);
      } else if (chosenIds.length > 1 && (widget.selectedPlayer == null || !chosenIds.contains(widget.selectedPlayer!.id))) {
        widget.onSelectPlayer(chosenIds.first);
      }
      widget.onDebug('Игроки аналитики выбраны inline', {
        'player_ids': chosenIds.toList(),
        'comparison_mode': chosenIds.length > 1,
        'date': _dateIso(_selectedDate),
      });
    }, milliseconds: 80);
  }

  void _applyInlineSessionKind(PlayerTrainingCalendarMode mode) {
    _deferMouseSafe(() {
      if (!mounted) return;
      setState(() {
        _sessionKindFilter = mode;
        _useAllSessionsForPeriod = true;
        _selectedSessionIds.clear();
        _selectedPlayerIds.clear();
        _trackerCalendarSessions = const <TrackerSessionModel>[];
        _trackerCalendarRequest++;
        _reload++;
      });
      _ensureTrackerCalendarSessions(force: true);
      widget.onDebug('Тип сессий аналитики выбран inline', {'kind': _sessionKindApiValue(mode)});
    }, milliseconds: 80);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1100;
    final mobile = width < 720;

    Widget filters() => _DateFilterBar(
          selectedDate: _selectedDate,
          onlySelectedDate: _onlySelectedDate,
          startTime: _startTime,
          endTime: _endTime,
          selectedPlayer: widget.selectedPlayer,
          playerFilterLabel: _playerFilterLabel(),
          selectedField: widget.selectedField,
          selectedSession: widget.selectedSession,
          sessionFilterLabel: _sessionFilterLabel(),
          liveRunning: widget.liveRunning,
          localPointsCount: _visibleLocalPoints().length,
          sessionKindLabel: _sessionKindLabel(_sessionKindFilter),
          onOpenSessionKindPicker: () => _toggleInlineAnalyticsPicker('type'),
          onOpenPlayerPicker: () => _toggleInlineAnalyticsPicker('players'),
          onOpenSessionPicker: () => _toggleInlineAnalyticsPicker('calendar'),
          onOpenCalibration: widget.onOpenCalibration,
          onClearField: widget.onClearField,
          onRefresh: _refresh,
          onPrev: () => _shiftDate(-1),
          onNext: () => _shiftDate(1),
          onToday: () => _setDate(DateTime.now()),
          onPick: () => _toggleInlineAnalyticsPicker('calendar'),
          onPickStart: () => _pickTime(isStart: true),
          onPickEnd: () => _pickTime(isStart: false),
          onClearTime: _clearTimeFilter,
          onToggleMode: (v) {
            _deferMouseSafe(() {
              setState(() {
                _onlySelectedDate = v;
                _reload++;
              });
              widget.onDebug('Фильтр сессий изменён', {
                'date': _dateIso(_selectedDate),
                'only_date': v,
                'from_time': _timeParam(_startTime),
                'to_time': _timeParam(_endTime),
              });
            });
          },
        );

    Widget tabs() => _TabStrip(
          selected: _tab,
          filterActive: _inlineAnalyticsPicker != null || _hasActiveAnalyticsFilters(),
          filterLabel: _analyticsFilterButtonLabel(),
          onFilterTap: () => _toggleInlineAnalyticsPicker('calendar'),
          onSelect: (i) {
            final selected = _effectiveSelectedSession(_trackerCalendarSessions);
            final label = _tabs[i].label;
            if ((label == 'Отчёты' || label == 'ИИ-анализ') && selected == null) {
              _toggleInlineAnalyticsPicker('calendar');
              return;
            }
            if (label == 'ИИ-анализ') {
              final session = selected!;
              widget.onOpenAiAnalysis?.call(<String, dynamic>{
                'source': 'tracker_analytics_report',
                'team_id': widget.teamId,
                'team_name': widget.teamName,
                'club_name': widget.clubName,
                'session_id': session.id,
                'session_title': session.title,
                'selected_date': _dateIso(_selectedDate),
                'player_ids': _selectedPlayerIds.toList(growable: false),
                'player_names': _selectedPlayerIds
                    .map((id) => _playerById(id)?.name)
                    .whereType<String>()
                    .where((name) => name.trim().isNotEmpty)
                    .toList(growable: false),
                'player_filter': _playerFilterLabel(),
                'report_section': 'full_report',
              });
              widget.onDebug('Открыт ИИ Beta из аналитики', {
                'session_id': session.id,
                'date': _dateIso(_selectedDate),
                'player_ids': _selectedPlayerIds.toList(growable: false),
              });
              return;
            }
            _deferMouseSafe(() {
              setState(() {
                _tab = i;
                _coachInsight = null;
                _inlineAnalyticsPicker = null;
              });
              widget.onDebug('GPS-аналитика вкладка', {'tab': i, 'label': label});
            });
          },
        );

    Widget loadedContent(_AnalyticsBundle bundle) {
      final visibleLocalPoints = _visibleLocalPoints();
      final analysisPoints = widget.liveRunning ? visibleLocalPoints : (bundle.sessionPoints.isNotEmpty ? bundle.sessionPoints : visibleLocalPoints);
      final effectiveSelectedSession = _effectiveSelectedSession(bundle.sessions);
      final local = _LocalTrackAnalysis.fromPoints(analysisPoints, sprintThresholdKmh: _sprintThresholdKmh, hsrThresholdKmh: _hsrThresholdKmh);
      Widget content;
      switch (_tab) {
        case 0:
          content = _OverviewTab(
            compact: compact,
            teamName: widget.teamName,
            clubName: widget.clubName,
            bundle: bundle,
            local: local,
            selectedPlayer: widget.selectedPlayer,
            playerFilterLabel: _playerFilterLabel(),
            selectedField: widget.selectedField,
            selectedSession: effectiveSelectedSession,
            heatmap: bundle.heatmap,
            usingLatestFallback: bundle.usingLatestFallback,
            fallbackMessage: bundle.fallbackMessage,
            onOpenCalibration: widget.onOpenCalibration,
            onOpenSessions: widget.onOpenSessions,
            onOpenInsight: _openCoachInsight,
          );
          break;
        case 1:
          content = mobile
              ? _MobileMapDashboard(
                  points: bundle.heatmap,
                  localPoints: analysisPoints,
                  field: widget.selectedField,
                  selectedPlayer: widget.selectedPlayer,
                  selectedSession: effectiveSelectedSession,
                  heatMode: _showHeatMapMode,
                  onHeatModeChanged: (v) => setState(() => _showHeatMapMode = v),
                  sprintThresholdKmh: _sprintThresholdKmh,
                  hsrThresholdKmh: _hsrThresholdKmh,
                  showSprintArrows: _showSprintArrows,
                  mapRotationDeg: _mapRotationDeg,
                  onOpenCalibration: widget.onOpenCalibration,
                )
              : _MapTab(
                  points: bundle.heatmap,
                  localPoints: analysisPoints,
                  field: widget.selectedField,
                  selectedPlayer: widget.selectedPlayer,
                  selectedSession: effectiveSelectedSession,
                  comparisonRows: _filterRowsByPlayerIds(_rowsForAnalytics(bundle, effectiveSelectedSession, local, widget.selectedPlayer), _selectedPlayerIds),
                  selectedPlayerIds: Set<int>.from(_selectedPlayerIds),
                  heatMode: _showHeatMapMode,
                  onHeatModeChanged: (v) => setState(() => _showHeatMapMode = v),
                  sprintThresholdKmh: _sprintThresholdKmh,
                  hsrThresholdKmh: _hsrThresholdKmh,
                  showSprintArrows: _showSprintArrows,
                  mapRotationDeg: _mapRotationDeg,
                  onOpenCalibration: widget.onOpenCalibration,
                );
          break;
        case 2:
          content = mobile
              ? _MobileSpeedDashboard(
                  bundle: bundle,
                  local: local,
                  selectedSession: effectiveSelectedSession,
                  hsrThresholdKmh: _hsrThresholdKmh,
                  sprintThresholdKmh: _sprintThresholdKmh,
                )
              : _SpeedTab(
                  bundle: bundle,
                  local: local,
                  selectedSession: effectiveSelectedSession,
                  hsrThresholdKmh: _hsrThresholdKmh,
                  sprintThresholdKmh: _sprintThresholdKmh,
                  onOpenInsight: _openCoachInsight,
                );
          break;
        case 3:
          content = mobile
              ? _MobileHeartDashboard(heartRate: bundle.heartRate, selectedPlayer: widget.selectedPlayer)
              : _HeartRateAnalyticsTab(
                  heartRate: bundle.heartRate,
                  selectedPlayer: widget.selectedPlayer,
                  rosterPlayers: widget.players,
        onOpenAiLoadPoint: widget.onOpenAiLoadPoint == null ? null : (point) => widget.onOpenAiLoadPoint!(<String, dynamic>{'player_id': point.playerId, 'player_name': point.playerName, 'bpm': point.bpm, 'zone': point.zone, 'time_ms': point.timeMs, 'minute': point.minute, 'activity_type': point.activityType, 'hr_load': point.hrLoad}),
                );
          break;
        case 4:
          content = mobile
              ? _MobileTeamDashboard(
                  bundle: bundle,
                  selectedSession: effectiveSelectedSession,
                  local: local,
                  players: widget.players,
                  selectedPlayer: widget.selectedPlayer,
                  onSelectPlayer: widget.onSelectPlayer,
                )
              : _TeamTab(
                  bundle: bundle,
                  selectedSession: effectiveSelectedSession,
                  local: local,
                  players: widget.players,
                  selectedPlayer: widget.selectedPlayer,
                  onSelectPlayer: widget.onSelectPlayer,
                );
          break;
        case 5:
          content = mobile
              ? _MobileRatingsDashboard(
                  bundle: bundle,
                  local: local,
                  teamName: widget.teamName,
                  selectedPlayer: widget.selectedPlayer,
                  selectedSession: effectiveSelectedSession,
                )
              : _RatingsTab(
                  bundle: bundle,
                  local: local,
                  teamName: widget.teamName,
                  selectedPlayer: widget.selectedPlayer,
                  selectedSession: effectiveSelectedSession,
                );
          break;
        case 6:
        case 7:
        case 8:
          final reportSession = effectiveSelectedSession;
          final section = switch (_tab) {
            6 => 'locomotor',
            7 => 'mechanics',
            _ => 'microcycle',
          };
          content = reportSession == null
              ? _AnalyticsReportEmptyState(
                  onOpenSelection: () => _toggleInlineAnalyticsPicker('calendar'),
                )
              : TrackerTrainingReportScreen(
                  key: ValueKey('analytics_${section}_${reportSession.id}_${_reportPlayerSelectionKey()}'),
                  sessionId: reportSession.id,
                  teamId: widget.teamId,
                  teamName: widget.teamName,
                  embedded: true,
                  analyticsSection: section,
                  initialSelectedPlayerIds: Set<int>.from(_selectedPlayerIds),
                  rosterPlayers: widget.players,
                );
          break;
        case 9:
          // «ИИ-анализ» открывается напрямую как окно ИИ Beta в обработчике вкладок.
          content = const SizedBox.shrink();
          break;
        case 10:
          final reportSession = effectiveSelectedSession;
          content = reportSession == null
              ? _AnalyticsReportEmptyState(
                  onOpenSelection: () => _toggleInlineAnalyticsPicker('calendar'),
                )
              : TrackerTrainingReportScreen(
                  key: ValueKey('analytics_report_${reportSession.id}_${_reportPlayerSelectionKey()}'),
                  sessionId: reportSession.id,
                  teamId: widget.teamId,
                  teamName: widget.teamName,
                  embedded: true,
                  selectionOnly: true,
                  inlineAnalyticsReport: true,
                  initialSelectedPlayerIds: Set<int>.from(_selectedPlayerIds),
                  rosterPlayers: widget.players,
                );
          break;
        case 11:
          content = _OfflineTab(
            liveRunning: widget.liveRunning,
            commandChannelReady: widget.commandChannelReady,
            offlineRecordsCount: widget.offlineRecordsCount,
            localPointsCount: widget.localPointsCount,
            offlineGpsMode: _offlineGpsMode,
            onToggleOfflineGpsMode: (v) {
              setState(() => _offlineGpsMode = v);
              widget.onDebug('Офлайн GPS режим изменён', {'enabled': v});
            },
            onRequestOfflineRecords: widget.onRequestOfflineRecords,
            onSaveOfflineSession: widget.onSaveOfflineSession,
            onOpenSessions: widget.onOpenSessions,
          );
          break;
        default:
          final reportSession = effectiveSelectedSession;
          content = reportSession == null
              ? _AnalyticsReportEmptyState(
                  onOpenSelection: () => _toggleInlineAnalyticsPicker('calendar'),
                )
              : TrackerTrainingReportScreen(
                  key: ValueKey('analytics_report_${reportSession.id}_${_reportPlayerSelectionKey()}'),
                  sessionId: reportSession.id,
                  teamId: widget.teamId,
                  teamName: widget.teamName,
                  embedded: true,
                  selectionOnly: true,
                  inlineAnalyticsReport: true,
                  initialSelectedPlayerIds: Set<int>.from(_selectedPlayerIds),
                  rosterPlayers: widget.players,
                );
          break;
      }
      if (mobile) return content;
      // Важно: планшетные вкладки нельзя оборачивать во внешний SingleChildScrollView:
      // внутри них уже есть Row/Expanded/ListView с жёсткими ограничениями высоты.
      // Иначе Flutter получает RenderSingleChildViewport без размера и падает на hit test.
      return _CoachInsightScaffold(
        insight: _coachInsight,
        onClose: _closeCoachInsight,
        child: content,
      );
    }

    Widget inlineSelector() {
      final mode = _inlineAnalyticsPicker;
      if (mode == null) return const SizedBox.shrink();
      return _TrackerInlineAnalyticsOverlay(
        mode: mode,
        selectedDate: _selectedDate,
        sessions: _trackerCalendarSessions,
        players: widget.players,
        selectedPlayerIds: Set<int>.from(_selectedPlayerIds),
        selectedKind: _sessionKindFilter,
        selectedKindLabel: _sessionKindLabel(_sessionKindFilter),
        loading: _trackerCalendarLoading,
        summary: _analyticsFilterButtonLabel(),
        onClose: _closeInlineAnalyticsPicker,
        onShowCalendar: () => _showInlineAnalyticsPicker('calendar'),
        onShowPlayers: () => _showInlineAnalyticsPicker('players'),
        onShowKind: () => _showInlineAnalyticsPicker('type'),
        onSelectDate: (date) {
          _setDate(date);
          _ensureTrackerCalendarSessions();
        },
        onSelectSession: _applyCalendarSession,
        onSelectPlayers: _applyInlinePlayerFilter,
        onSelectKind: _applyInlineSessionKind,
      );
    }

    Widget bodyFuture() => FutureBuilder<_AnalyticsBundle>(
          key: ValueKey('gps_analytics_${widget.teamId}_${widget.selectedPlayer?.id ?? 0}_${widget.selectedField?.id ?? 0}_${_dateIso(_selectedDate)}_${_timeParam(_startTime) ?? 'all'}_${_timeParam(_endTime) ?? 'all'}_${widget.selectedSession?.id ?? 0}_${_useAllSessionsForPeriod ? 'all' : _selectedSessionIds.join('-')}_${_selectedPlayerIds.isEmpty ? 'team' : _selectedPlayerIds.join('-')}_${_sessionKindApiValue()}_$_reload'),
          future: _loadBundle(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorBox(error: '${snapshot.error}', onRetry: _refresh);
            }
            return loadedContent(snapshot.data ?? _AnalyticsBundle.empty());
          },
        );

    Widget stackedBody() {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: bodyFuture()),
          if (_inlineAnalyticsPicker != null)
            Positioned.fill(
              top: mobile ? 4 : 6,
              left: mobile ? 2 : 6,
              right: mobile ? 2 : 6,
              bottom: mobile ? 4 : 6,
              child: inlineSelector(),
            ),
        ],
      );
    }

    if (mobile) {
      return ScrollConfiguration(
        behavior: const _TrackerNoDesktopScrollbarBehavior(),
        child: Container(
          color: Colors.transparent,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            tabs(),
            Expanded(child: stackedBody()),
          ]),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: const _TrackerNoDesktopScrollbarBehavior(),
      child: Container(
        color: _AA.bg,
        child: Column(
          children: [
            tabs(),
            Expanded(child: stackedBody()),
          ],
        ),
      ),
    );
  }


  String _sessionKindLabel(PlayerTrainingCalendarMode mode) {
    switch (mode) {
      case PlayerTrainingCalendarMode.team:
        return 'Командные';
      case PlayerTrainingCalendarMode.personal:
        return 'Личные';
      case PlayerTrainingCalendarMode.all:
        return 'Все';
    }
  }

  IconData _sessionKindIcon(PlayerTrainingCalendarMode mode) {
    switch (mode) {
      case PlayerTrainingCalendarMode.team:
        return Icons.groups_rounded;
      case PlayerTrainingCalendarMode.personal:
        return Icons.person_pin_circle_rounded;
      case PlayerTrainingCalendarMode.all:
        return Icons.layers_rounded;
    }
  }

  String _sessionKindApiValue([PlayerTrainingCalendarMode? mode]) {
    switch (mode ?? _sessionKindFilter) {
      case PlayerTrainingCalendarMode.team:
        return 'team';
      case PlayerTrainingCalendarMode.personal:
        return 'personal';
      case PlayerTrainingCalendarMode.all:
        return 'all';
    }
  }

  bool _sessionMatchesKind(TrackerSessionModel session) {
    switch (_sessionKindFilter) {
      case PlayerTrainingCalendarMode.team:
        return !session.personalSession;
      case PlayerTrainingCalendarMode.personal:
        return session.personalSession;
      case PlayerTrainingCalendarMode.all:
        return true;
    }
  }

  void _openSessionKindPicker() {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 1200;
    final options = <PlayerTrainingCalendarMode>[
      PlayerTrainingCalendarMode.team,
      PlayerTrainingCalendarMode.personal,
      PlayerTrainingCalendarMode.all,
    ];

    void apply(PlayerTrainingCalendarMode mode) {
      if (!mounted) return;
      setState(() {
        _sessionKindFilter = mode;
        _trackerCalendarSessions = const <TrackerSessionModel>[];
        _trackerCalendarRequest++;
        _selectedSessionIds.clear();
        _useAllSessionsForPeriod = true;
        _reload++;
      });
      widget.onDebug('Тип тренировок в аналитике изменён', {'mode': mode.name});
    }

    if (width < 720) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(.22),
        builder: (sheetContext) {
          final bottom = MediaQuery.of(sheetContext).padding.bottom;
          return SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottom),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_AA.sheetRadius)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Тип тренировок', style: TextStyle(color: _AA.text, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  for (final mode in options) ...[
                    _SessionKindOptionTile(
                      icon: _sessionKindIcon(mode),
                      title: _sessionKindLabel(mode),
                      subtitle: mode == PlayerTrainingCalendarMode.team
                          ? 'сессии, запущенные тренером'
                          : mode == PlayerTrainingCalendarMode.personal
                              ? 'игроки сами запустили «Мои тренировки»'
                              : 'командные и личные вместе',
                      active: _sessionKindFilter == mode,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        apply(mode);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Тип тренировок в аналитике', style: TextStyle(color: _AA.text, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in options) ...[
                _SessionKindOptionTile(
                  icon: _sessionKindIcon(mode),
                  title: _sessionKindLabel(mode),
                  subtitle: mode == PlayerTrainingCalendarMode.team
                      ? 'сессии, запущенные тренером в командном Live'
                      : mode == PlayerTrainingCalendarMode.personal
                          ? 'игроки сами запустили тренировку в личном кабинете'
                          : 'смешанный архив команды и личных сессий',
                  active: _sessionKindFilter == mode,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    apply(mode);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openMobileAnalyticsMenu() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.24),
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottom = MediaQuery.of(sheetContext).padding.bottom;

        void closeThen(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          Future<void>.delayed(const Duration(milliseconds: 120), () {
            if (!mounted) return;
            action();
          });
        }

        Widget closeButton() {
          return _NoHoverTap(
            onTap: () => Navigator.of(sheetContext).pop(),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: _AA.muted, size: 18),
            ),
          );
        }

        Widget item({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
          bool primary = false,
          bool danger = false,
        }) {
          final color = danger ? _AA.red : (primary ? _AA.green : _AA.muted);
          return _NoHoverTap(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
              decoration: BoxDecoration(
                color: primary ? _AA.greenSoft : Colors.white,
                borderRadius: BorderRadius.circular(_AA.mobileInnerRadius),
                border: Border.all(color: primary ? _AA.greenLine : _AA.line.withOpacity(.92)),
              ),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: color.withOpacity(.09), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 7),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: danger ? _AA.red : _AA.text, fontSize: 12.6, fontWeight: FontWeight.w700, letterSpacing: -.08),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w600),
                  ),
                ])),
                Icon(Icons.chevron_right_rounded, color: primary ? _AA.green : _AA.muted, size: 20),
              ]),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottom),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_AA.sheetRadius),
              child: Material(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: _AA.line, borderRadius: BorderRadius.circular(999)))),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: _AA.greenSoft, shape: BoxShape.circle),
                        child: const Icon(Icons.more_horiz_rounded, color: _AA.green, size: 19),
                      ),
                      const SizedBox(width: 7),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text(
                          'Меню аналитики',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _AA.text, fontSize: 14.0, fontWeight: FontWeight.w700, letterSpacing: -.12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.teamName} · быстрые действия',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w600),
                        ),
                      ])),
                      closeButton(),
                    ]),
                    const SizedBox(height: 8),
                    item(
                      icon: Icons.play_arrow_rounded,
                      title: 'Live',
                      subtitle: widget.liveRunning ? 'Live уже идёт' : 'открыть запуск записи',
                      primary: true,
                      onTap: () => closeThen(widget.onOpenLive),
                    ),
                    const SizedBox(height: 8),
                    item(
                      icon: Icons.event_note_rounded,
                      title: 'Выбор сессии',
                      subtitle: 'календарь и список тренировок',
                      onTap: () => closeThen(widget.onOpenSessions),
                    ),
                    const SizedBox(height: 8),
                    item(
                      icon: Icons.map_rounded,
                      title: 'Поле',
                      subtitle: widget.selectedField?.title ?? 'выбрать поле',
                      onTap: () => closeThen(widget.onOpenCalibration),
                    ),
                    const SizedBox(height: 8),
                    item(
                      icon: Icons.refresh_rounded,
                      title: 'Обновить',
                      subtitle: 'перезагрузить аналитику',
                      onTap: () => closeThen(_refresh),
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

  String _sessionFilterLabel() {
    if (_useAllSessionsForPeriod || _selectedSessionIds.isEmpty) return 'все за период';
    if (_selectedSessionIds.length == 1) {
      final id = _selectedSessionIds.first;
      return '#$id';
    }
    return '${_selectedSessionIds.length} выбрано';
  }

  String _playerFilterLabel() {
    // В шапке аналитики не показываем фамилию одного фокус-игрока, если сверху
    // реально не включён фильтр по игрокам. Иначе при сравнении нескольких
    // игроков (например во вкладке пульса) шапка выглядит как будто выбран
    // только один футболист.
    if (_selectedPlayerIds.isEmpty) return 'все игроки';
    if (_selectedPlayerIds.length == 1) {
      final id = _selectedPlayerIds.first;
      return _playerById(id)?.name ?? 'Игрок $id';
    }
    return '${_selectedPlayerIds.length} игроков';
  }

  String _analyticsFilterButtonLabel() {
    final player = _selectedPlayerIds.isEmpty
        ? 'Команда'
        : (_selectedPlayerIds.length == 1
            ? _shortPlayerName(_playerById(_selectedPlayerIds.first)?.name ?? 'Игрок')
            : '${_selectedPlayerIds.length} игрока');
    final sessions = _selectedSessionIds.isEmpty
        ? (_onlySelectedDate ? _dateIso(_selectedDate).substring(5).replaceFirst('-', '.') : 'период')
        : '${_selectedSessionIds.length} сесс.';
    return '$player · ${_sessionKindLabel(_sessionKindFilter)} · $sessions';
  }

  bool _hasActiveAnalyticsFilters() {
    return _selectedPlayerIds.isNotEmpty ||
        _selectedSessionIds.isNotEmpty ||
        !_onlySelectedDate ||
        _startTime != null ||
        _endTime != null ||
        _sessionKindFilter != widget.initialCalendarMode;
  }

  Set<int> _activePlayerFilterIds() {
    if (_selectedPlayerIds.isNotEmpty) return Set<int>.from(_selectedPlayerIds);
    return const <int>{};
  }

  bool _sessionMatchesPlayerIds(TrackerSessionModel session, Set<int> ids) {
    if (ids.isEmpty) return true;
    final directId = session.playerId;
    if (directId != null && ids.contains(directId)) return true;

    // Бывает, что серверная сессия уже есть за дату, но в ней не заполнен
    // player_id, а игрок записан только по имени. Карточка игрока тогда честно
    // показывает «есть сессия», но фильтр по player_id отрезает эту же сессию.
    // Поэтому для аналитики используем тот же fallback, что и в подписи карточек:
    // player_id -> имя игрока.
    final sessionName = _trackerInlineNormalizeName(session.playerName ?? '');
    if (sessionName.isEmpty) return false;
    for (final id in ids) {
      final player = _playerById(id);
      if (player == null) continue;
      if (_trackerInlineNormalizeName(player.name) == sessionName) return true;
    }
    return false;
  }

  bool _pointMatchesSelectedPlayers(ActionTrackerGpsPoint point) {
    final ids = _activePlayerFilterIds();
    if (ids.isEmpty) return true;
    final playerId = point.playerId;
    return playerId == null || ids.contains(playerId);
  }

  List<TrackerSessionModel> _activeSessions(List<TrackerSessionModel> sessions) {
    // Даже в режиме «все за период» мы храним конкретный набор id, который
    // получился после фильтра по дате/игрокам. Иначе аналитика снова берёт
    // чужие/последние сессии и рейтинг выглядит одинаковым.
    if (_selectedSessionIds.isNotEmpty) {
      final selected = sessions.where((s) => _selectedSessionIds.contains(s.id)).toList(growable: false);
      if (selected.isNotEmpty) return selected;
    }
    return sessions;
  }

  int? _singleSelectedSessionId(List<TrackerSessionModel> sessions) {
    final active = _activeSessions(sessions);
    if (active.length == 1) return active.first.id;
    return null;
  }

  String _dateIso(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  void _deferMouseSafe(FutureOr<void> Function() action, {int milliseconds = 220}) {
    // В Flutter web/tablet нельзя удалять/перестраивать виджеты под курсором
    // прямо во время обработки pointer/mouse события. Даже unfocus() переносим
    // внутрь отложенного кадра, иначе TextField/Dropdown могут пересобрать
    // MouseRegion в середине MouseTracker.updateAllDevices.
    Timer(Duration(milliseconds: milliseconds), () async {
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await action();
    });
  }

  void _setDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    if (!mounted) return;
    setState(() {
      _selectedDate = normalized;
      _useAllSessionsForPeriod = true;
      _selectedSessionIds.clear();
      // Дата применяется сразу по тапу. Само закрытие календаря выполняется
      // отложенно через _deferMouseSafe/_popAfterMouseSettled, чтобы не ловить
      // desktop MouseTracker assertion при удалении виджета из-под курсора.
    });
    widget.onDebug('Календарь сессий: дата выбрана', {
      'date': _dateIso(normalized),
      'only_date': _onlySelectedDate,
      'session_filter_reset': true,
      'calendar_auto_applied': true,
    });
  }

  void _shiftDate(int days) => _setDate(_selectedDate.add(Duration(days: days)));

  Future<List<TrackerSessionModel>> _ensureTrackerCalendarSessions({bool force = false}) async {
    if (!force && _trackerCalendarSessions.isNotEmpty) return _trackerCalendarSessions;
    if (_trackerCalendarLoading) return _trackerCalendarSessions;

    final request = ++_trackerCalendarRequest;
    if (mounted) setState(() => _trackerCalendarLoading = true);
    try {
      final playerIds = _activePlayerFilterIds();
      final sessions = await widget.api.loadSessions(
        teamId: widget.teamId,
        // Загружаем календарь без серверного player_id-фильтра: часть старых
        // сессий приходит без player_id, но с playerName. Ниже отфильтруем
        // локально по id или имени, чтобы подписи игроков и сама аналитика совпадали.
        playerId: null,
        date: null,
        limit: 900,
        sessionKind: _sessionKindApiValue(),
      );
      final visibleSessions = playerIds.isEmpty
          ? sessions
          : sessions.where((s) => _sessionMatchesPlayerIds(s, playerIds)).toList(growable: false);
      if (!mounted || request != _trackerCalendarRequest) return _trackerCalendarSessions;
      setState(() {
        _trackerCalendarSessions = visibleSessions;
        _trackerCalendarLoading = false;
      });
      return visibleSessions;
    } catch (e) {
      if (!mounted || request != _trackerCalendarRequest) return _trackerCalendarSessions;
      setState(() => _trackerCalendarLoading = false);
      widget.onDebug('Календарь сессий: не удалось загрузить метки', {'error': '$e'});
      return _trackerCalendarSessions;
    }
  }

  Future<void> _pickDate() async {
    // Один и тот же календарь на ПК, планшете и телефоне: большой, чистый
    // выбор месяца как в разделе календаря, без встраивания в поток аналитики.
    _deferMouseSafe(() async {
      final sessions = await _ensureTrackerCalendarSessions();
      if (!mounted) return;
      if (_trackerCalendarExpanded) {
        setState(() => _trackerCalendarExpanded = false);
      }
      final picked = await showModalBottomSheet<_TrackerCalendarPickResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(.26),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        builder: (context) => _TrackerSessionCalendarPicker(
          initialDate: _selectedDate,
          sessions: sessions,
          players: widget.players,
          sessionKindLabel: _sessionKindLabel(_sessionKindFilter),
        ),
      );
      if (!mounted || picked == null) return;
      if (picked.session != null) {
        _applyCalendarSession(picked.session!);
      } else {
        _setDate(picked.date);
      }
    });
  }

  void _applyCalendarSession(TrackerSessionModel session) {
    final dt = _trackerSessionDate(session);
    if (!mounted) return;
    setState(() {
      if (dt != null) _selectedDate = DateTime(dt.year, dt.month, dt.day);
      _onlySelectedDate = true;
      _useAllSessionsForPeriod = false;
      _selectedSessionIds
        ..clear()
        ..add(session.id);
      if (session.playerId != null && session.playerId! > 0) {
        _selectedPlayerIds
          ..clear()
          ..add(session.playerId!);
      }
      _reload++;
    });
    widget.onSelectSession(session);
    widget.onDebug('Календарь сессий: выбрана конкретная сессия', {
      'session_id': session.id,
      'player_id': session.playerId,
      'personal': session.personalSession,
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? (_startTime ?? const TimeOfDay(hour: 0, minute: 0)) : (_endTime ?? const TimeOfDay(hour: 23, minute: 59));
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (context) => _TrackerTimePickerSheet(
        initial: initial,
        title: isStart ? 'Начало периода' : 'Конец периода',
      ),
    );
    if (picked == null) return;
    _deferMouseSafe(() {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _reload++;
      });
      widget.onDebug('Фильтр времени изменён', {
        'date': _dateIso(_selectedDate),
        'from_time': _timeParam(_startTime),
        'to_time': _timeParam(_endTime),
      });
    });
  }

  void _clearTimeFilter() {
    _deferMouseSafe(() {
      setState(() {
        _startTime = null;
        _endTime = null;
        _reload++;
      });
      widget.onDebug('Фильтр времени очищен', {'date': _dateIso(_selectedDate)});
    });
  }

  String? _timeParam(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  DateTime? _sessionDateTime(TrackerSessionModel session) => _parseServerDateTime(session.createdAt);

  DateTime? _parseServerDateTime(String rawValue) =>
      _trackerMoscowDateTime(rawValue);

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<ActionTrackerGpsPoint> _visibleLocalPoints() {
    // Live-точки показываем только если они относятся к выбранному периоду.
    // После остановки Live данные сессии грузятся с сервера через get_tracker_session_points.php,
    // чтобы карта/спринты/теплокарта не зависели от временного локального списка.
    if (widget.liveRunning) return widget.localPoints.where(_pointMatchesDateRange).where(_pointMatchesSelectedPlayers).toList(growable: false);
    if (widget.selectedSession != null) return const <ActionTrackerGpsPoint>[];
    return widget.localPoints.where(_pointMatchesDateRange).where(_pointMatchesSelectedPlayers).toList(growable: false);
  }

  bool _pointMatchesDateRange(ActionTrackerGpsPoint point) {
    if (point.timeMs <= 0) return widget.liveRunning;
    final dt = DateTime.fromMillisecondsSinceEpoch(point.timeMs);
    if (_onlySelectedDate && !_isSameDay(dt, _selectedDate)) return false;
    final start = _startTime;
    final end = _endTime;
    final minutes = dt.hour * 60 + dt.minute;
    if (start != null && minutes < start.hour * 60 + start.minute) return false;
    if (end != null && minutes > end.hour * 60 + end.minute) return false;
    return true;
  }

  bool _sessionMatchesDateRange(TrackerSessionModel session, String dateIso) {
    final raw = session.createdAt.trim();
    if (raw.isEmpty) return false;
    final dt = _sessionDateTime(session);
    if (dt == null) return raw.startsWith(dateIso) || raw.contains(dateIso);
    if (_onlySelectedDate && !_isSameDay(dt, _selectedDate)) return false;
    final start = _startTime;
    final end = _endTime;
    if (start != null) {
      final startMinutes = start.hour * 60 + start.minute;
      final current = dt.hour * 60 + dt.minute;
      if (current < startMinutes) return false;
    }
    if (end != null) {
      final endMinutes = end.hour * 60 + end.minute;
      final current = dt.hour * 60 + dt.minute;
      if (current > endMinutes) return false;
    }
    return true;
  }

  TrackerSessionModel? _effectiveSelectedSession(List<TrackerSessionModel> sessions) {
    final active = _activeSessions(sessions);
    // В режиме «все сессии периода» не подставляем одну сессию в радар/рейтинг.
    // Иначе обзор дня, карта и рейтинг выглядят как одна и та же запись.
    if (_useAllSessionsForPeriod) return null;
    if (active.length == 1) return active.first;
    final current = widget.selectedSession;
    if (current != null) {
      for (final s in active) {
        if (s.id == current.id) return s;
      }
    }
    return active.isNotEmpty ? active.first : (sessions.isNotEmpty ? sessions.first : null);
  }


  bool _sessionHasAnalyticsData(TrackerSessionModel s) {
    return s.distanceM > 0 ||
        s.maxSpeedKmh > 0 ||
        s.sprintCount > 0 ||
        s.accelCount > 0 ||
        s.decelCount > 0 ||
        s.durationSec > 0;
  }

  TrackerSessionModel? _firstExportSession(List<TrackerSessionModel> sessions) {
    final current = widget.selectedSession;
    if (current != null && current.id > 0) return current;
    final active = _activeSessions(sessions);
    final withData = active.where(_sessionHasAnalyticsData).toList(growable: false);
    if (withData.isNotEmpty) return withData.first;
    if (active.isNotEmpty) return active.first;
    final anyWithData = sessions.where(_sessionHasAnalyticsData).toList(growable: false);
    if (anyWithData.isNotEmpty) return anyWithData.first;
    return sessions.isNotEmpty ? sessions.first : null;
  }


  TrackerPlayerOption? _playerById(int? id) {
    if (id == null || id <= 0) return null;
    for (final p in widget.players) {
      if (p.id == id || p.identityIds.contains(id)) return p;
    }
    return null;
  }

  String _shortPlayerName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'Игрок';
    if (parts.length == 1) return parts.first;
    final last = parts.first;
    final initial = parts.length > 1 && parts[1].isNotEmpty ? '${parts[1][0]}.' : '';
    return '$last $initial'.trim();
  }

  String _sessionPlayerName(TrackerSessionModel s) {
    final fromPlayer = _playerById(s.playerId)?.name;
    final raw = (s.playerName ?? '').trim();
    final looksGeneric = _looksGenericPlayerName(raw);
    final full = looksGeneric ? (fromPlayer ?? raw) : raw;
    if (full.trim().isEmpty) return s.playerId == null ? 'Игрок' : 'Игрок ${s.playerId}';
    return _shortPlayerName(full);
  }

  String _sessionSearchText(TrackerSessionModel s) {
    final player = _playerById(s.playerId);
    return [
      s.id,
      s.playerId,
      s.playerName,
      player?.name,
      player?.number,
      player?.position,
      s.createdAt,
      s.title,
    ].where((v) => v != null).join(' ').toLowerCase();
  }



  Future<void> _openPlayerPicker() async {
    var query = '';
    final tempPlayers = Set<int>.from(_selectedPlayerIds);
    if (tempPlayers.isEmpty && widget.selectedPlayer != null) tempPlayers.add(widget.selectedPlayer!.id);

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.08),
      builder: (sheetContext) {
        return StatefulBuilder(builder: (context, modalSetState) {
          final players = widget.players.where((p) {
            if (query.isEmpty) return true;
            final text = '${p.name} ${p.number ?? ''} ${p.position ?? ''} ${p.id}'.toLowerCase();
            return text.contains(query);
          }).toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name));

          final selectedLabel = tempPlayers.isEmpty
              ? 'команда'
              : (tempPlayers.length == 1 ? (_playerById(tempPlayers.first)?.name ?? '1 игрок') : '${tempPlayers.length} игрока');
          final screen = MediaQuery.sizeOf(context);
          final bottom = MediaQuery.paddingOf(context).bottom;
          final sheetHeight = math.min(screen.height * .86, 720.0);

          Widget actionChip({required IconData icon, required String label, required VoidCallback onTap, bool active = false}) {
            return _NoHoverTap(
              onTap: onTap,
              borderRadius: BorderRadius.circular(_AA.mobileInnerRadius),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: active ? _AA.greenSoft : _AA.card,
                  borderRadius: BorderRadius.circular(_AA.mobileInnerRadius),
                  border: Border.all(color: active ? _AA.greenLine : _AA.line.withOpacity(.90)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 16, color: active ? _AA.green : _AA.muted),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(color: active ? _AA.green : _AA.text, fontSize: 12.2, fontWeight: FontWeight.w700, letterSpacing: -.15)),
                ]),
              ),
            );
          }

          return SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: sheetHeight,
                margin: const EdgeInsets.only(top: 24),
                decoration: const BoxDecoration(
                  color: _AA.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(_AA.sheetRadius)),
                  boxShadow: [BoxShadow(color: Color(0x220F172A), blurRadius: 16, offset: Offset(0, -8))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.person_search_rounded, color: _AA.green, size: 21),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('Игроки', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _AA.text, fontSize: 18, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -.25)),
                          SizedBox(height: 3),
                          Text('карта, график и сравнение', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _AA.muted, fontSize: 12.2, fontWeight: FontWeight.w600, height: 1.05)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(selectedLabel, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(color: _AA.green, fontSize: 12.2, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      _NoHoverTap(
                        onTap: () => _deferMouseSafe(() { if (context.mounted) Navigator.pop(context); }),
                        borderRadius: BorderRadius.circular(_AA.tabletCardRadius),
                        child: Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(_AA.tabletCardRadius)), child: const Icon(Icons.close_rounded, size: 20, color: _AA.text)),
                      ),
                    ]),
                  ),
                  SizedBox(
                    height: 46,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      scrollDirection: Axis.horizontal,
                      children: [
                        actionChip(icon: Icons.groups_rounded, label: 'Команда', active: tempPlayers.isEmpty, onTap: () => modalSetState(() => tempPlayers.clear())),
                        const SizedBox(width: 8),
                        actionChip(icon: Icons.done_all_rounded, label: 'Все', active: tempPlayers.length == widget.players.length && widget.players.isNotEmpty, onTap: () => modalSetState(() { tempPlayers..clear()..addAll(widget.players.map((p) => p.id)); })),
                        const SizedBox(width: 8),
                        actionChip(icon: Icons.compare_arrows_rounded, label: 'Сравнение', active: tempPlayers.length > 1, onTap: () {}),
                        const SizedBox(width: 8),
                        actionChip(icon: Icons.cleaning_services_rounded, label: 'Очистить', onTap: () => modalSetState(() => tempPlayers.clear())),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                    child: Container(
                      decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(16)),
                      child: TextField(
                        onChanged: (value) => modalSetState(() => query = value.trim().toLowerCase()),
                        style: const TextStyle(color: _AA.text, fontSize: 13.2, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search_rounded, size: 20, color: _AA.muted),
                          hintText: 'Поиск игрока, номера или позиции',
                          hintStyle: TextStyle(color: _AA.muted, fontSize: 13.2, fontWeight: FontWeight.w500),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: players.isEmpty
                        ? const _Empty(icon: Icons.person_search_rounded, text: 'Игроки не найдены')
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                            itemCount: players.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 9),
                            itemBuilder: (context, i) {
                              final p = players[i];
                              final active = tempPlayers.contains(p.id);
                              return _NoHoverTap(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => modalSetState(() {
                                  if (active) {
                                    tempPlayers.remove(p.id);
                                  } else {
                                    tempPlayers.add(p.id);
                                  }
                                }),
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: 64),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: active ? _AA.greenSoft : _AA.card,
                                    borderRadius: BorderRadius.zero,
                                    border: Border.all(color: active ? _AA.green.withOpacity(.36) : _AA.line.withOpacity(.92)),
                                  ),
                                  child: Row(children: [
                                    _SessionAvatar(player: p),
                                    const SizedBox(width: 8),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Text(_shortPlayerName(p.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 14.4, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -.15)),
                                      const SizedBox(height: 4),
                                      Text('${p.number == null ? '' : '№${p.number} · '}${p.position ?? 'позиция не указана'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 12.2, fontWeight: FontWeight.w600, height: 1.05)),
                                    ])),
                                    const SizedBox(width: 7),
                                    Icon(active ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: active ? _AA.green : _AA.muted, size: 24),
                                  ]),
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(18, 10, 18, 12 + bottom),
                    decoration: BoxDecoration(color: _AA.card.withOpacity(.96), border: const Border(top: BorderSide(color: _AA.line))),
                    child: Row(children: [
                      Expanded(child: Text(tempPlayers.isEmpty ? 'Покажем всю команду.' : 'Отфильтруем карту, график и рейтинг.', style: const TextStyle(color: _AA.muted, fontSize: 12.2, fontWeight: FontWeight.w600, height: 1.15))),
                      const SizedBox(width: 8),
                      _NoHoverTap(
                        onTap: () {
                          final chosenIds = Set<int>.from(tempPlayers);
                          _deferMouseSafe(() { if (context.mounted) Navigator.pop(context); });
                          _deferMouseSafe(() {
                            setState(() {
                              _selectedPlayerIds
                                ..clear()
                                ..addAll(chosenIds);
                              _useAllSessionsForPeriod = true;
                              _selectedSessionIds.clear();
                              _trackerCalendarSessions = const <TrackerSessionModel>[];
                              _trackerCalendarRequest++;
                              _reload++;
                            });
                            if (chosenIds.length == 1) {
                              final id = chosenIds.first;
                              if (widget.selectedPlayer?.id != id) widget.onSelectPlayer(id);
                            } else if (chosenIds.length > 1 && (widget.selectedPlayer == null || !chosenIds.contains(widget.selectedPlayer!.id))) {
                              widget.onSelectPlayer(chosenIds.first);
                            }
                            widget.onDebug('Игроки аналитики выбраны', {
                              'player_ids': chosenIds.toList(),
                              'comparison_mode': chosenIds.length > 1,
                              'date': _dateIso(_selectedDate),
                            });
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(color: _AA.green, borderRadius: BorderRadius.circular(16)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 19),
                            SizedBox(width: 8),
                            Text('Применить', style: TextStyle(color: Colors.white, fontSize: 13.2, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        });
      },
    );
  }


  Future<void> _openSessionPicker() async {
    final date = _onlySelectedDate ? _dateIso(_selectedDate) : null;
    final fromTime = _timeParam(_startTime);
    final toTime = _timeParam(_endTime);
    var sessions = await widget.api.loadSessions(
      teamId: widget.teamId,
      playerId: null,
      date: date,
      fromTime: fromTime,
      toTime: toTime,
      limit: 500,
      sessionKind: 'all',
    );
    sessions = sessions
        .where((s) => _sessionMatchesDateRange(s, date ?? _dateIso(_selectedDate)))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;

    final tempSessions = Set<int>.from(_selectedSessionIds);
    final tempPlayers = Set<int>.from(_selectedPlayerIds);
    var tempAllSessions = _useAllSessionsForPeriod || tempSessions.isEmpty;
    var query = '';
    var onlyWithData = false;
    var tempSessionKind = _sessionKindFilter;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.24),
      builder: (sheetContext) {
        return StatefulBuilder(builder: (context, modalSetState) {
          bool sessionHasData(TrackerSessionModel s) =>
              s.distanceM > 0 || s.maxSpeedKmh > 0 || s.sprintCount > 0 || s.accelCount > 0 || s.decelCount > 0 || s.durationSec > 0;

          bool matchesTempKind(TrackerSessionModel session) {
            switch (tempSessionKind) {
              case PlayerTrainingCalendarMode.team:
                return !session.personalSession;
              case PlayerTrainingCalendarMode.personal:
                return session.personalSession;
              case PlayerTrainingCalendarMode.all:
                return true;
            }
          }

          final summaries = <int, _SessionPickerPlayerSummary>{};
          for (final session in sessions.where(matchesTempKind)) {
            final id = session.playerId;
            if (id == null || id <= 0) continue;
            final roster = _playerById(id);
            final fallbackName = _sessionPlayerName(session);
            final name = (roster?.name.trim().isNotEmpty ?? false) ? roster!.name.trim() : fallbackName;
            final summary = summaries[id] ?? _SessionPickerPlayerSummary(id: id, name: name, player: roster);
            summary.add(session);
            summaries[id] = summary;
          }
          final players = summaries.values.toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name));

          List<TrackerSessionModel> filteredSessions() {
            return sessions.where((s) {
              if (!matchesTempKind(s)) return false;
              if (tempPlayers.isNotEmpty && !_sessionMatchesPlayerIds(s, tempPlayers)) return false;
              if (onlyWithData && !sessionHasData(s)) return false;
              if (query.isNotEmpty && !_sessionSearchText(s).contains(query)) return false;
              return true;
            }).toList(growable: false);
          }

          List<_SessionPickerPlayerSummary> filteredPlayers() {
            return players.where((p) {
              if (onlyWithData && !p.hasData) return false;
              if (query.isEmpty) return true;
              final text = '${p.name} ${p.player?.number ?? ''} ${p.player?.position ?? ''} ${p.id}'.toLowerCase();
              return text.contains(query);
            }).toList(growable: false);
          }

          final filtered = filteredSessions();
          final selectedCount = tempAllSessions ? filtered.length : tempSessions.length;
          final screen = MediaQuery.sizeOf(context);
          final bottom = MediaQuery.paddingOf(context).bottom;
          final wide = screen.width >= 920;
          final sheetWidth = wide ? math.min(1240.0, screen.width - 44) : screen.width;
          final sheetHeight = wide ? math.min(820.0, screen.height * .88) : screen.height * .92;

          Widget modalButton({required IconData icon, required String label, required VoidCallback onTap, bool primary = false}) {
            return _NoHoverTap(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: primary ? _AA.green : (primary ? _AA.greenSoft : _AA.card),
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: primary ? _AA.green : _AA.line.withOpacity(.95)),
                  boxShadow: primary ? const [BoxShadow(color: Color(0x2200A651), blurRadius: 14, offset: Offset(0, 6))] : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 17, color: primary ? Colors.white : _AA.green),
                  const SizedBox(width: 8),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: primary ? Colors.white : _AA.text, fontSize: 12.2, fontWeight: FontWeight.w900, letterSpacing: -.12)),
                ]),
              ),
            );
          }

          Widget playerCard(_SessionPickerPlayerSummary p) {
            final active = tempPlayers.contains(p.id);
            return _NoHoverTap(
              onTap: () => modalSetState(() {
                if (active) {
                  tempPlayers.remove(p.id);
                } else {
                  tempPlayers.add(p.id);
                }
                tempAllSessions = true;
                tempSessions.clear();
              }),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: active ? _AA.greenSoft : _AA.card,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: active ? _AA.greenLine : _AA.line.withOpacity(.95)),
                ),
                child: Row(children: [
                  _SessionAvatar(player: p.player),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 13.4, fontWeight: FontWeight.w900, letterSpacing: -.15)),
                    const SizedBox(height: 7),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if ((p.player?.number ?? '').toString().isNotEmpty) _TrackerCalendarMetricPill(icon: Icons.tag_rounded, label: '№', value: '${p.player?.number ?? ''}'),
                      if ((p.player?.position ?? '').trim().isNotEmpty) _TrackerCalendarMetricPill(icon: Icons.sports_soccer_rounded, label: '', value: p.player!.position!),
                      _TrackerCalendarMetricPill(icon: Icons.event_available_rounded, label: '', value: '${p.count} сесс.'),
                      _TrackerCalendarMetricPill(icon: Icons.route_rounded, label: '', value: _meters(p.distanceM)),
                    ]),
                  ])),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: active ? _AA.green : Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? _AA.green : _AA.line)),
                    child: Icon(active ? Icons.check_rounded : Icons.add_rounded, color: active ? Colors.white : _AA.muted, size: 18),
                  ),
                ]),
              ),
            );
          }

          Widget playersPane() {
            final rows = filteredPlayers();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(children: [
                  Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.groups_rounded, color: _AA.green, size: 17)),
                  const SizedBox(width: 9),
                  const Expanded(child: Text('Игроки', style: TextStyle(color: _AA.text, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -.2))),
                  Text(tempPlayers.isEmpty ? 'вся команда' : '${tempPlayers.length} выбрано', style: const TextStyle(color: _AA.green, fontSize: 11.5, fontWeight: FontWeight.w900)),
                ]),
              ),
              Expanded(
                child: rows.isEmpty
                    ? const _Empty(icon: Icons.person_search_rounded, text: 'Игроки по фильтру не найдены')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 0, 14, 18),
                        itemCount: rows.length,
                        itemBuilder: (context, index) => playerCard(rows[index]),
                      ),
              ),
            ]);
          }

          Widget sessionsPane() {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(children: [
                  Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.fact_check_rounded, color: _AA.green, size: 17)),
                  const SizedBox(width: 9),
                  Expanded(child: Text('Сессии периода', style: const TextStyle(color: _AA.text, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -.2))),
                  Text('$selectedCount выбрано', style: const TextStyle(color: _AA.green, fontSize: 11.5, fontWeight: FontWeight.w900)),
                ]),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const _Empty(icon: Icons.event_busy_rounded, text: 'Сессии не найдены')
                    : LayoutBuilder(
                        builder: (context, grid) {
                          final columns = grid.maxWidth >= 1100 ? 3 : (grid.maxWidth >= 520 ? 2 : 1);
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                            itemCount: filtered.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: columns == 1 ? 2.75 : (columns == 2 ? 1.72 : 1.46),
                            ),
                            itemBuilder: (context, index) {
                              final session = filtered[index];
                              final player = _playerById(session.playerId);
                              final checked = tempAllSessions || tempSessions.contains(session.id);
                              return _SessionPickerSessionTile(
                                session: session,
                                player: player,
                                checked: checked,
                                playerName: _sessionPlayerName(session),
                                createdLabel: _formatSessionDateTime(session.createdAt),
                                onTap: () => modalSetState(() {
                                  if (tempAllSessions) {
                                    tempAllSessions = false;
                                    tempSessions
                                      ..clear()
                                      ..add(session.id);
                                    return;
                                  }
                                  if (tempSessions.contains(session.id)) {
                                    tempSessions.remove(session.id);
                                  } else {
                                    tempSessions.add(session.id);
                                  }
                                }),
                              );
                            },
                          );
                        },
                      ),
              ),
            ]);
          }

          final body = wide
              ? Row(children: [
                  Expanded(flex: 4, child: playersPane()),
                  Container(width: 1, color: _AA.line.withOpacity(.9)),
                  Expanded(flex: 7, child: sessionsPane()),
                ])
              : Column(children: [
                  SizedBox(height: math.min(250.0, sheetHeight * .32), child: playersPane()),
                  Container(height: 1, color: _AA.line.withOpacity(.9)),
                  Expanded(child: sessionsPane()),
                ]);

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + bottom),
              child: Align(
                alignment: wide ? Alignment.center : Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: sheetWidth),
                  child: Material(
                    color: _AA.card,
                    borderRadius: BorderRadius.circular(30),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: sheetHeight,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                          child: Row(children: [
                            Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.fact_check_rounded, color: _AA.green, size: 22)),
                            const SizedBox(width: 8),
                            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Выбор сессий и игроков', style: TextStyle(color: _AA.text, fontSize: 19, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -.35)),
                              SizedBox(height: 4),
                              Text('Выберите игрока и нужные сессии, затем нажмите «Применить»', style: TextStyle(color: _AA.muted, fontSize: 12.2, fontWeight: FontWeight.w700)),
                            ])),
                            const SizedBox(width: 6),
                            Text('$selectedCount выбрано', style: const TextStyle(color: _AA.green, fontSize: 13, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 6),
                            _NoHoverTap(
                              onTap: () => Navigator.of(sheetContext).pop(),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.close_rounded, color: _AA.text, size: 23)),
                            ),
                          ]),
                        ),
                        Container(height: 1, color: _AA.line.withOpacity(.9)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F6F8),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Row(
                              children: PlayerTrainingCalendarMode.values.map((mode) {
                                final active = tempSessionKind == mode;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => modalSetState(() {
                                          tempSessionKind = mode;
                                          tempAllSessions = true;
                                          tempSessions.clear();
                                          tempPlayers.clear();
                                        }),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 220),
                                          curve: Curves.easeOutCubic,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: active ? Colors.white : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: active ? _AA.green : Colors.transparent,
                                              width: active ? 1.5 : 1,
                                            ),
                                            boxShadow: active
                                                ? const [BoxShadow(color: Color(0x1600A651), blurRadius: 12, offset: Offset(0, 5))]
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _sessionKindIcon(mode),
                                                size: 17,
                                                color: active ? _AA.green : _AA.muted,
                                              ),
                                              const SizedBox(width: 7),
                                              Text(
                                                _sessionKindLabel(mode),
                                                style: TextStyle(
                                                  color: active ? _AA.green : _AA.muted,
                                                  fontSize: 12.2,
                                                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                                                ),
                                              ),
                                              if (active) ...[
                                                const SizedBox(width: 6),
                                                const Icon(Icons.check_circle_rounded, size: 15, color: _AA.green),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 13, 18, 10),
                          child: Wrap(spacing: 9, runSpacing: 9, children: [
                            modalButton(icon: Icons.done_all_rounded, label: 'Все сессии', primary: tempAllSessions && tempPlayers.isEmpty, onTap: () => modalSetState(() {
                              tempAllSessions = true;
                              tempSessions.clear();
                              tempPlayers.clear();
                            })),
                            modalButton(icon: Icons.person_rounded, label: 'Текущий игрок', primary: tempPlayers.length == 1 && widget.selectedPlayer != null && tempPlayers.contains(widget.selectedPlayer!.id), onTap: () => modalSetState(() {
                              tempPlayers
                                ..clear()
                                ..addAll(widget.selectedPlayer == null ? const <int>[] : <int>[widget.selectedPlayer!.id]);
                              tempAllSessions = true;
                              tempSessions.clear();
                            })),
                            modalButton(icon: Icons.filter_alt_rounded, label: 'Только с данными', primary: onlyWithData, onTap: () => modalSetState(() => onlyWithData = !onlyWithData)),
                            modalButton(icon: Icons.restart_alt_rounded, label: 'Сброс выбора', onTap: () => modalSetState(() {
                              tempAllSessions = true;
                              tempSessions.clear();
                              tempPlayers.clear();
                              query = '';
                              onlyWithData = false;
                              tempSessionKind = _sessionKindFilter;
                            })),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                            child: TextField(
                              onChanged: (value) => modalSetState(() => query = value.trim().toLowerCase()),
                              style: const TextStyle(color: _AA.text, fontSize: 13, fontWeight: FontWeight.w700),
                              decoration: const InputDecoration(
                                isDense: true,
                                prefixIcon: Icon(Icons.search_rounded, size: 22, color: _AA.muted),
                                hintText: 'Поиск по игроку, номеру, позиции или ID сессии',
                                hintStyle: TextStyle(color: _AA.muted, fontSize: 13, fontWeight: FontWeight.w700),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: body),
                        Container(
                          height: 68,
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                          decoration: const BoxDecoration(color: Color(0xFFFBFCFE), border: Border(top: BorderSide(color: _AA.line))),
                          child: Row(children: [
                            Expanded(child: Text(tempAllSessions ? 'Будут учтены все сессии выбранных игроков.' : 'Будут учтены только отмеченные сессии.', style: const TextStyle(color: _AA.muted, fontSize: 12, fontWeight: FontWeight.w800))),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 180,
                              child: modalButton(icon: Icons.check_rounded, label: 'Применить', primary: true, onTap: () {
                                final currentFiltered = filteredSessions();
                                final useAllSessions = tempAllSessions;
                                final nextSessionIds = <int>{}
                                  ..addAll(useAllSessions ? currentFiltered.map((s) => s.id) : tempSessions);
                                final chosen = sessions.where((s) => nextSessionIds.contains(s.id)).toList(growable: false);
                                _deferMouseSafe(() { if (context.mounted) Navigator.pop(sheetContext); });
                                _deferMouseSafe(() {
                                  setState(() {
                                    _sessionKindFilter = tempSessionKind;
                                    _useAllSessionsForPeriod = useAllSessions;
                                    _selectedSessionIds
                                      ..clear()
                                      ..addAll(nextSessionIds);
                                    _selectedPlayerIds
                                      ..clear()
                                      ..addAll(tempPlayers);
                                    _reload++;
                                  });
                                  final focusPlayerId = tempPlayers.length == 1
                                      ? tempPlayers.first
                                      : (chosen.length == 1 ? chosen.first.playerId : null);
                                  if (focusPlayerId != null && focusPlayerId > 0 && widget.selectedPlayer?.id != focusPlayerId) {
                                    widget.onSelectPlayer(focusPlayerId);
                                  }
                                  if (chosen.isNotEmpty) widget.onSelectSession(chosen.first);
                                  widget.onDebug('Выбраны сессии и игроки аналитики', {
                                    'all_period': useAllSessions,
                                    'session_ids': nextSessionIds.toList(),
                                    'player_ids': tempPlayers.toList(),
                                    'date': date,
                                    'from_time': fromTime,
                                    'to_time': toTime,
                                  });
                                });
                              }),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }



  List<TrackerHeatPoint> _heatmapFromGps(List<ActionTrackerGpsPoint> points, TrackerFieldModel? field) {
    return _heatmapFromGpsStatic(points, field);
  }


  Future<_AnalyticsBundle> _loadBundle() async {
    try {
      final date = _onlySelectedDate ? _dateIso(_selectedDate) : null;
      final fromTime = _timeParam(_startTime);
      final toTime = _timeParam(_endTime);

      var dashboard = _sessionKindFilter == PlayerTrainingCalendarMode.team
          ? await widget.api.loadDashboard(teamId: widget.teamId, date: date, fromTime: fromTime, toTime: toTime)
          : const TrackerDashboardModel(summary: <String, dynamic>{}, players: <TrackerPlayerLoadRow>[], alerts: <Map<String, dynamic>>[]);
      final rawSessions = await widget.api.loadSessions(
        teamId: widget.teamId,
        playerId: null,
        date: date,
        fromTime: fromTime,
        toTime: toTime,
        limit: _onlySelectedDate ? 300 : 700,
        sessionKind: _sessionKindApiValue(),
      );

      var sessions = date == null
          ? rawSessions.where(_sessionMatchesKind).where((s) => _sessionMatchesDateRange(s, _dateIso(_selectedDate))).toList(growable: false)
          : rawSessions.where(_sessionMatchesKind).where((s) => _sessionMatchesDateRange(s, date)).toList(growable: false);
      final selectedPlayerIds = _activePlayerFilterIds();
      if (selectedPlayerIds.isNotEmpty) {
        sessions = sessions.where((s) => _sessionMatchesPlayerIds(s, selectedPlayerIds)).toList(growable: false);
      }
      final widgetSession = widget.selectedSession;
      if (widgetSession != null && widgetSession.id > 0 && _selectedSessionIds.contains(widgetSession.id) && !sessions.any((s) => s.id == widgetSession.id)) {
        sessions = <TrackerSessionModel>[widgetSession, ...sessions];
      }

      const usingLatestFallback = false;
      const fallbackMessage = '';

      // Если за выбранную дату/время пусто — оставляем период пустым.
      // Не подставляем последнюю сессию, чтобы отчёт и карта не показывали чужой день.
      if (sessions.isEmpty && !widget.liveRunning && _onlySelectedDate) {
        dashboard = const TrackerDashboardModel(summary: <String, dynamic>{}, players: <TrackerPlayerLoadRow>[], alerts: <Map<String, dynamic>>[]);
      }

      final activeSessions = _activeSessions(sessions);
      final singleSessionId = _singleSelectedSessionId(sessions);
      final shouldLoadSessionPoints = !_useAllSessionsForPeriod || selectedPlayerIds.isNotEmpty;
      final selectedSessionIds = (shouldLoadSessionPoints && activeSessions.isNotEmpty)
          ? activeSessions.map((s) => s.id).where((id) => id > 0).toList(growable: false)
          : const <int>[];

      List<ActionTrackerGpsPoint> sessionPoints = const <ActionTrackerGpsPoint>[];
      if (!widget.liveRunning) {
        if (selectedSessionIds.length > 1) {
          final chunks = await Future.wait(selectedSessionIds.map((id) => widget.api.loadSessionPoints(
                teamId: widget.teamId,
                playerId: null,
                sessionId: id,
              )));
          sessionPoints = chunks.expand((e) => e).toList(growable: false)
            ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
        } else {
          sessionPoints = await widget.api.loadSessionPoints(
            teamId: widget.teamId,
            playerId: selectedSessionIds.length == 1 ? null : (selectedPlayerIds.length == 1 ? selectedPlayerIds.first : widget.selectedPlayer?.id),
            sessionId: singleSessionId,
            date: singleSessionId != null ? null : date,
            fromTime: singleSessionId != null ? null : fromTime,
            toTime: singleSessionId != null ? null : toTime,
          );
        }
      }

      final heat = sessionPoints.isNotEmpty
          ? const <TrackerHeatPoint>[]
          : (activeSessions.isEmpty && !widget.liveRunning
              ? const <TrackerHeatPoint>[]
              : await widget.api.loadHeatmap(
                  teamId: widget.teamId,
                  playerId: singleSessionId != null ? null : (selectedPlayerIds.length == 1 ? selectedPlayerIds.first : widget.selectedPlayer?.id),
                  sessionId: singleSessionId,
                  fieldId: null,
                  date: singleSessionId != null ? null : date,
                  fromTime: singleSessionId != null ? null : fromTime,
                  toTime: singleSessionId != null ? null : toTime,
                ));
      final gpsHeat = _heatmapFromGps(sessionPoints, widget.selectedField);
      final effectiveHeat = _isHeatCollapsed(heat) ? gpsHeat : (heat.isNotEmpty ? heat : gpsHeat);
      final hrSessionIds = singleSessionId == null
          ? activeSessions.map((s) => s.id).where((id) => id > 0).toList(growable: false)
          : const <int>[];
      final hrJson = await widget.api.loadHeartRateSummary(
        teamId: widget.teamId,
        // Пульс в аналитике грузим командой. Конкретного игрока выбираем уже
        // верхними чипами "Все / Игрок", иначе вкладка "Пульс" превращалась
        // в график только текущего фокус-игрока.
        playerId: null,
        sessionId: singleSessionId,
        sessionIds: hrSessionIds,
        date: (singleSessionId == null && hrSessionIds.isEmpty) ? date : null,
        fromTime: (singleSessionId == null && hrSessionIds.isEmpty) ? fromTime : null,
        toTime: (singleSessionId == null && hrSessionIds.isEmpty) ? toTime : null,
        sessionKind: _sessionKindApiValue(),
      );
      var heartRate = _AnalyticsHeartRate.fromJson(hrJson);

      // Если новый endpoint ЧСС ещё не отдаёт данные, но отчёт по этой же сессии
      // уже строит Polar-график, подтягиваем ЧСС из get_training_report.php.
      // Это убирает ситуацию: в отчёте пульс есть, а в аналитике пустой экран.
      if (heartRate.effectiveSamplesCount <= 0 && heartRate.timelineForChart.isEmpty) {
        final fallbackSessionId = singleSessionId ?? (activeSessions.isNotEmpty ? activeSessions.first.id : null);
        if (fallbackSessionId != null && fallbackSessionId > 0) {
          final reportHrJson = await widget.api.loadTrainingReportHeartRate(teamId: widget.teamId, sessionId: fallbackSessionId, playerId: null);
          final fallbackHeartRate = _AnalyticsHeartRate.fromJson(reportHrJson);
          if (fallbackHeartRate.effectiveSamplesCount > 0 || fallbackHeartRate.timelineForChart.isNotEmpty) {
            heartRate = fallbackHeartRate;
          }
        }
      }
      return _AnalyticsBundle(
        dashboard: dashboard,
        sessions: activeSessions.isNotEmpty ? activeSessions : sessions,
        players: widget.players,
        heatmap: effectiveHeat,
        sessionPoints: sessionPoints,
        heartRate: heartRate,
        usingLatestFallback: usingLatestFallback,
        fallbackMessage: fallbackMessage,
      );
    } catch (e) {
      // Аналитика не должна закрывать весь экран из-за одной ошибки API.
      // Серверная причина остаётся видна в debug/console, а UI показывает пустой период.
      // ignore: avoid_print
      print('[TRACKER_ANALYTICS_BUNDLE] fallback: $e');
      return _AnalyticsBundle.empty();
    }
  }

}



List<TrackerHeatPoint> _heatmapFromGpsStatic(List<ActionTrackerGpsPoint> points, TrackerFieldModel? field) {
  if (points.length < 2) return const <TrackerHeatPoint>[];

  List<TrackerHeatPoint> buildFromOffsets(List<Offset> offsets) {
    final buckets = <String, double>{};
    for (final o in offsets) {
      final x = (o.dx.clamp(0.0, 1.0) * 105.0).toDouble();
      final y = (o.dy.clamp(0.0, 1.0) * 68.0).toDouble();
      final key = '${x.toStringAsFixed(1)}:${y.toStringAsFixed(1)}';
      buckets[key] = (buckets[key] ?? 0) + 1;
    }
    return buckets.entries.map((e) {
      final parts = e.key.split(':');
      return TrackerHeatPoint(
        x: double.tryParse(parts[0]) ?? 0,
        y: double.tryParse(parts[1]) ?? 0,
        value: e.value,
      );
    }).toList(growable: false);
  }

  if (_shouldUseFieldProjection(points, field)) {
    final projected = <Offset>[];
    for (final p in points) {
      final q = TrackerPitchProjector.projectGps(field, latitude: p.latitude, longitude: p.longitude);
      if (q != null) projected.add(Offset(q.clampedNx, q.clampedNy));
    }
    if (projected.length >= 2) return buildFromOffsets(projected);
  }

  final bounds = _Bounds.fromGps(points);
  final offsets = points.map((p) {
    final x = ((p.longitude - bounds.minLng) / (bounds.maxLng - bounds.minLng)).clamp(0.0, 1.0).toDouble();
    final y = (1 - ((p.latitude - bounds.minLat) / (bounds.maxLat - bounds.minLat)).clamp(0.0, 1.0)).toDouble();
    return Offset(x, y);
  }).toList(growable: false);
  return buildFromOffsets(offsets);
}

bool _isHeatCollapsed(List<TrackerHeatPoint> points) {
  if (points.length < 2) return points.isNotEmpty;
  var minX = points.first.x, maxX = points.first.x, minY = points.first.y, maxY = points.first.y;
  var total = 0.0;
  for (final p in points) {
    minX = math.min(minX, p.x); maxX = math.max(maxX, p.x);
    minY = math.min(minY, p.y); maxY = math.max(maxY, p.y);
    total += p.value;
  }
  return total > 0 && ((maxX - minX).abs() < 1.0 && (maxY - minY).abs() < 1.0);
}


String _formatSessionDateTime(String raw) {
  final dt = _parseTrackerDateTime(raw);
  if (dt == null) return raw.isEmpty ? 'без времени' : raw;
  return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

DateTime? _parseTrackerDateTime(String rawValue) =>
    _trackerMoscowDateTime(rawValue);

class _AnalyticsBundle {
  const _AnalyticsBundle({
    required this.dashboard,
    required this.sessions,
    required this.players,
    required this.heatmap,
    required this.sessionPoints,
    required this.heartRate,
    this.usingLatestFallback = false,
    this.fallbackMessage = '',
  });

  final TrackerDashboardModel dashboard;
  final List<TrackerSessionModel> sessions;
  final List<TrackerPlayerOption> players;
  final List<TrackerHeatPoint> heatmap;
  final List<ActionTrackerGpsPoint> sessionPoints;
  final _AnalyticsHeartRate heartRate;
  final bool usingLatestFallback;
  final String fallbackMessage;

  factory _AnalyticsBundle.empty() => _AnalyticsBundle(
        dashboard: const TrackerDashboardModel(summary: <String, dynamic>{}, players: <TrackerPlayerLoadRow>[], alerts: <Map<String, dynamic>>[]),
        sessions: <TrackerSessionModel>[],
        players: <TrackerPlayerOption>[],
        heatmap: <TrackerHeatPoint>[],
        sessionPoints: <ActionTrackerGpsPoint>[],
        heartRate: _AnalyticsHeartRate.empty(),
      );
}


class _AnalyticsHeartRate {
  const _AnalyticsHeartRate({required this.players, required this.timeline, required this.avgBpm, required this.maxBpm, required this.samplesCount, required this.playersCount});
  final List<_AnalyticsHrPlayer> players;
  final List<_AnalyticsHrPoint> timeline;
  final double avgBpm;
  final int maxBpm;
  final int samplesCount;
  final int playersCount;

  factory _AnalyticsHeartRate.empty() => const _AnalyticsHeartRate(players: <_AnalyticsHrPlayer>[], timeline: <_AnalyticsHrPoint>[], avgBpm: 0, maxBpm: 0, samplesCount: 0, playersCount: 0);

  factory _AnalyticsHeartRate.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> mapValue(dynamic raw) => raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    List<dynamic> listValue(dynamic raw) {
      if (raw is List) return raw;
      if (raw is Map) {
        final nested = raw['items'] ?? raw['points'] ?? raw['timeline'] ?? raw['players'] ?? raw['data'];
        return nested is List ? nested : const <dynamic>[];
      }
      return const <dynamic>[];
    }

    final summary = <String, dynamic>{
      ...mapValue(json['summary']),
      // Старые/новые PHP могут отдавать эти поля на верхнем уровне.
      if (json.containsKey('avg_bpm')) 'avg_bpm': json['avg_bpm'],
      if (json.containsKey('heart_rate_avg_bpm')) 'avg_bpm': json['heart_rate_avg_bpm'],
      if (json.containsKey('max_bpm')) 'max_bpm': json['max_bpm'],
      if (json.containsKey('heart_rate_max_bpm')) 'max_bpm': json['heart_rate_max_bpm'],
      if (json.containsKey('samples_count')) 'samples_count': json['samples_count'],
      if (json.containsKey('heart_rate_samples_count')) 'samples_count': json['heart_rate_samples_count'],
      if (json.containsKey('players_count')) 'players_count': json['players_count'],
    };

    final rawPlayers = listValue(json['items']).isNotEmpty
        ? listValue(json['items'])
        : (listValue(json['players']).isNotEmpty
            ? listValue(json['players'])
            : (listValue(json['heart_rate_players']).isNotEmpty
                ? listValue(json['heart_rate_players'])
                : (listValue(json['player_summaries']).isNotEmpty ? listValue(json['player_summaries']) : listValue(json['data']))));
    final rawTimeline = listValue(json['timeline']).isNotEmpty
        ? listValue(json['timeline'])
        : (listValue(json['heart_rate_timeline']).isNotEmpty
            ? listValue(json['heart_rate_timeline'])
            : (listValue(json['hr_timeline']).isNotEmpty
                ? listValue(json['hr_timeline'])
                : (listValue(json['heartRateTimeline']).isNotEmpty ? listValue(json['heartRateTimeline']) : listValue(json['points']))));

    final players = rawPlayers.whereType<Map>().map((e) => _AnalyticsHrPlayer.fromJson(Map<String, dynamic>.from(e))).where((p) => p.samplesCount > 0 || p.avgBpm > 0 || p.maxBpm > 0).toList(growable: false);
    final timeline = rawTimeline.whereType<Map>().map((e) => _AnalyticsHrPoint.fromJson(Map<String, dynamic>.from(e))).where((p) => p.bpm > 0).toList(growable: false)
      ..sort((a, b) => (a.timeMs > 0 ? a.timeMs : a.minute * 60000).compareTo(b.timeMs > 0 ? b.timeMs : b.minute * 60000));
    final samplesFromPlayers = players.fold<int>(0, (sum, p) => sum + p.samplesCount);
    final weightedAvg = samplesFromPlayers <= 0
        ? (players.isEmpty ? 0.0 : players.fold<double>(0, (sum, p) => sum + p.avgBpm) / players.length)
        : players.fold<double>(0, (sum, p) => sum + p.avgBpm * (p.samplesCount > 0 ? p.samplesCount : 1)) / players.fold<int>(0, (sum, p) => sum + (p.samplesCount > 0 ? p.samplesCount : 1));
    return _AnalyticsHeartRate(
      players: players,
      timeline: timeline,
      avgBpm: _jsonDouble(summary['avg_bpm'], weightedAvg),
      maxBpm: _jsonInt(summary['max_bpm'], players.fold<int>(0, (maxV, p) => maxV > p.maxBpm ? maxV : p.maxBpm)),
      samplesCount: _jsonInt(summary['samples_count'], (samplesFromPlayers > timeline.length ? samplesFromPlayers : timeline.length)),
      playersCount: _jsonInt(summary['players_count'], players.length),
    );
  }

  List<_AnalyticsHrPoint> get timelineForChart => timeline.isNotEmpty ? timeline : _analyticsHrTimelineFromPlayers(players);
  int get effectiveSamplesCount {
    if (samplesCount > 0) return samplesCount;
    final fromPlayers = players.fold<int>(0, (sum, p) => sum + p.samplesCount);
    return timeline.length > fromPlayers ? timeline.length : fromPlayers;
  }
  int get effectivePlayersCount => playersCount > 0 ? playersCount : players.length;
  double get effectiveAvgBpm {
    if (avgBpm > 0) return avgBpm;
    final withAvg = players.where((p) => p.avgBpm > 0).toList(growable: false);
    if (withAvg.isEmpty) return 0;
    final totalSamples = withAvg.fold<int>(0, (sum, p) => sum + (p.samplesCount > 0 ? p.samplesCount : 1));
    return withAvg.fold<double>(0, (sum, p) => sum + p.avgBpm * (p.samplesCount > 0 ? p.samplesCount : 1)) / (totalSamples > 0 ? totalSamples : 1);
  }
  int get effectiveMaxBpm => maxBpm > 0 ? maxBpm : players.fold<int>(0, (maxV, p) => maxV > p.maxBpm ? maxV : p.maxBpm);
}

List<_AnalyticsHrPoint> _analyticsHrTimelineFromPlayers(List<_AnalyticsHrPlayer> players) {
  final list = players.where((p) => p.avgBpm > 0 || p.maxBpm > 0).take(12).toList(growable: false);
  if (list.isEmpty) return const <_AnalyticsHrPoint>[];
  final out = <_AnalyticsHrPoint>[];
  for (var i = 0; i < list.length; i++) {
    final p = list[i];
    final avg = p.avgBpm.round();
    final max = p.maxBpm > 0 ? p.maxBpm : avg;
    if (avg > 0) {
      out.add(_AnalyticsHrPoint(playerId: p.playerId, playerName: p.playerName, timeMs: 0, minute: i * 2, bpm: avg, zone: _analyticsZoneFromBpm(avg), hrLoad: p.highZoneSamples.toDouble()));
    }
    if (max > avg) {
      out.add(_AnalyticsHrPoint(playerId: p.playerId, playerName: p.playerName, timeMs: 0, minute: i * 2 + 1, bpm: max, zone: _analyticsZoneFromBpm(max), hrLoad: p.highZoneSamples.toDouble()));
    }
  }
  return out;
}

String _analyticsZoneFromBpm(int bpm) {
  if (bpm >= 180) return 'z5';
  if (bpm >= 160) return 'z4';
  if (bpm >= 140) return 'z3';
  if (bpm >= 120) return 'z2';
  return 'z1';
}

class _AnalyticsHrPlayer {
  const _AnalyticsHrPlayer({required this.playerId, required this.playerName, required this.avgBpm, required this.maxBpm, required this.samplesCount, required this.z1, required this.z2, required this.z3, required this.z4, required this.z5});
  final int? playerId;
  final String playerName;
  final double avgBpm;
  final int maxBpm;
  final int samplesCount;
  final int z1;
  final int z2;
  final int z3;
  final int z4;
  final int z5;
  int get highZoneSamples => z4 + z5;

  factory _AnalyticsHrPlayer.fromJson(Map<String, dynamic> json) => _AnalyticsHrPlayer(
        playerId: int.tryParse('${json['player_id'] ?? ''}'),
        playerName: '${json['player_name'] ?? json['name'] ?? 'Игрок'}',
        avgBpm: _jsonDouble(json['avg_bpm'] ?? json['heart_rate_avg_bpm']),
        maxBpm: _jsonInt(json['max_bpm'] ?? json['heart_rate_max_bpm']),
        samplesCount: _jsonInt(json['samples_count'] ?? json['heart_rate_samples_count']),
        z1: _jsonInt(json['z1'] ?? json['hr_z1_samples']),
        z2: _jsonInt(json['z2'] ?? json['hr_z2_samples']),
        z3: _jsonInt(json['z3'] ?? json['hr_z3_samples']),
        z4: _jsonInt(json['z4'] ?? json['hr_z4_samples']),
        z5: _jsonInt(json['z5'] ?? json['hr_z5_samples']),
      );
}

class _AnalyticsHrPoint {
  const _AnalyticsHrPoint({required this.playerId, required this.playerName, required this.timeMs, required this.minute, required this.bpm, required this.zone, required this.hrLoad, this.activityType = ''});
  final int? playerId;
  final String playerName;
  final int timeMs;
  final int minute;
  final int bpm;
  final String zone;
  final double hrLoad;
  final String activityType;

  factory _AnalyticsHrPoint.fromJson(Map<String, dynamic> json) {
    final measured = '${json['measured_at'] ?? json['created_at'] ?? json['time'] ?? ''}'.trim();
    final parsed = measured.isEmpty ? null : _parseTrackerDateTime(measured);
    final rawTimeMs = _jsonInt(json['time_ms'] ?? json['timestamp_ms'] ?? json['ts_ms']);
    final timeMs = rawTimeMs > 0 ? rawTimeMs : (parsed == null ? 0 : parsed.millisecondsSinceEpoch);
    final bpm = _jsonInt(json['bpm'] ?? json['hr'] ?? json['heart_rate']);
    final zone = '${json['hr_zone'] ?? json['zone'] ?? ''}'.trim().toLowerCase();
    return _AnalyticsHrPoint(
      playerId: int.tryParse('${json['player_id'] ?? ''}'),
      playerName: '${json['player_name'] ?? json['name'] ?? ''}',
      timeMs: timeMs,
      minute: _jsonInt(json['minute'] ?? json['minute_index'] ?? json['t_min']),
      bpm: bpm,
      zone: zone.isEmpty ? _analyticsZoneFromBpm(bpm) : zone,
      hrLoad: _jsonDouble(json['hr_load'] ?? json['load'] ?? json['hr_exertion']),
      activityType: '${json['activity_type'] ?? json['training_type'] ?? json['mode'] ?? json['activity'] ?? ''}'.trim().toLowerCase(),
    );
  }
}

int _jsonInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

double _jsonDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.')) ?? fallback;
}


class _HeartRateAnalyticsTab extends StatefulWidget {
  const _HeartRateAnalyticsTab({required this.heartRate, required this.selectedPlayer, required this.rosterPlayers, this.onOpenAiLoadPoint});
  final _AnalyticsHeartRate heartRate;
  final TrackerPlayerOption? selectedPlayer;
  final List<TrackerPlayerOption> rosterPlayers;
  final ValueChanged<_AnalyticsHrPoint>? onOpenAiLoadPoint;

  @override
  State<_HeartRateAnalyticsTab> createState() => _HeartRateAnalyticsTabState();
}

class _HeartRateAnalyticsTabState extends State<_HeartRateAnalyticsTab> {
  final Set<String> _selectedHrPlayerKeys = <String>{};
  _AnalyticsHrPoint? _focusedLoadPoint;
  String _activityFilter = 'all';
  bool _loadPointsExpanded = false;

  @override
  void didUpdateWidget(covariant _HeartRateAnalyticsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heartRate != widget.heartRate) {
      final available = _analyticsHrFilterOptions(widget.heartRate).map((e) => e.key).toSet();
      _selectedHrPlayerKeys.removeWhere((key) => !available.contains(key));
    }
  }

  void _togglePlayer(String key) {
    setState(() {
      if (_selectedHrPlayerKeys.isEmpty) {
        _selectedHrPlayerKeys.add(key);
      } else if (_selectedHrPlayerKeys.contains(key)) {
        _selectedHrPlayerKeys.remove(key);
      } else {
        _selectedHrPlayerKeys.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final raw = _resolveAnalyticsHeartRate(widget.heartRate, widget.rosterPlayers);
    final teamMode = _selectedHrPlayerKeys.isEmpty && raw.effectivePlayersCount > 1;
    const title = 'Polar H10';
    if (raw.effectiveSamplesCount <= 0 && raw.timelineForChart.isEmpty && raw.players.isEmpty) {
      return const _Empty(icon: Icons.favorite_border_rounded, text: 'По выбранному периоду нет данных Polar H10. Проверьте привязку датчика и время сессии.');
    }
    final playerFiltered = _selectedHrPlayerKeys.isEmpty ? raw : _analyticsHeartRateFiltered(raw, _selectedHrPlayerKeys);
    final heartRate = _activityFilter == 'all' ? playerFiltered : _analyticsHeartRateByActivity(playerFiltered, _activityFilter);
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 720;
      final filter = _AnalyticsHrPlayerFilterBar(
        heartRate: raw,
        rosterPlayers: widget.rosterPlayers,
        selectedKeys: _selectedHrPlayerKeys,
        onAll: () => setState(_selectedHrPlayerKeys.clear),
        onToggle: _togglePlayer,
      );
      final summary = _HeartRateSummaryPanel(heartRate: heartRate);
      final activityBar = _AnalyticsHrActivityBar(
        value: _activityFilter,
        onChanged: (value) => setState(() { _activityFilter = value; _focusedLoadPoint = null; }),
      );
      final chart = _Panel(
        title: 'Пульс по времени',
        subtitle: 'нажмите точку графика или событие нагрузки справа — откроется точное время и оценка',
        child: _AnalyticsHrLineChart(heartRate: heartRate, focusedPoint: _focusedLoadPoint),
      );
      final playerChart = _Panel(title: 'Средний / максимальный пульс', subtitle: 'зелёная точка — средний bpm, красная — максимум', child: _AnalyticsHrPlayerSummaryChart(heartRate: heartRate));
      final zones = _Panel(title: 'Зоны ЧСС', subtitle: 'распределение по Z1–Z5 по выбранным игрокам', child: _AnalyticsHrZonesPanel(heartRate: heartRate));
      final players = _Panel(title: title, subtitle: 'игроки Polar H10 и внутренняя нагрузка', child: _AnalyticsHrPlayersList(heartRate: heartRate, rosterPlayers: widget.rosterPlayers));
      final loadEvents = _Panel(
        title: 'Точки нагрузки · ИИ',
        subtitle: 'красные интервалы Z4–Z5; нажмите, чтобы перейти к моменту на графике',
        trailing: IconButton(
          tooltip: _loadPointsExpanded ? 'Свернуть' : 'Развернуть',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          onPressed: () => setState(() => _loadPointsExpanded = !_loadPointsExpanded),
          icon: Icon(_loadPointsExpanded ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded, size: 15, color: _AA.green),
        ),
        child: _AnalyticsHrLoadEventsPanel(
          heartRate: heartRate,
          rosterPlayers: widget.rosterPlayers,
          selected: _focusedLoadPoint,
          onSelect: (point) => setState(() => _focusedLoadPoint = point),
          onOpenAi: widget.onOpenAiLoadPoint,
        ),
      );
      final aiPassport = _Panel(
        title: 'ИИ-паспорт нагрузки',
        subtitle: 'интервалы Z4–Z5, восстановление, риск и рекомендации тренеру',
        child: _HrAiPassportPanel(
          heartRate: heartRate,
          rosterPlayers: widget.rosterPlayers,
          focusedPoint: _focusedLoadPoint,
          onFocus: (point) => setState(() => _focusedLoadPoint = point),
        ),
      );
      if (compact) {
        return ListView(padding: const EdgeInsets.all(8), children: [
          SizedBox(height: 54, child: filter),
          const SizedBox(height: 8),
          SizedBox(height: 46, child: activityBar),
          const SizedBox(height: 8),
          SizedBox(height: 96, child: summary),
          const SizedBox(height: 8),
          SizedBox(height: 520, child: chart),
          const SizedBox(height: 8),
          SizedBox(height: 250, child: playerChart),
          const SizedBox(height: 8),
          SizedBox(height: 190, child: zones),
          const SizedBox(height: 8),
          SizedBox(height: _loadPointsExpanded ? 540 : 320, child: loadEvents),
          if (!_loadPointsExpanded) ...[
            const SizedBox(height: 8),
            SizedBox(height: 430, child: aiPassport),
            const SizedBox(height: 8),
            SizedBox(height: 260, child: players),
          ],
        ]);
      }
      final highPoints = heartRate.timelineForChart.where((p) => p.bpm >= 160 || p.zone == 'z4' || p.zone == 'z5').length;
      final highPct = heartRate.timelineForChart.isEmpty ? 0 : (highPoints / heartRate.timelineForChart.length * 100).round();
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
            flex: 7,
            child: Column(children: [
              SizedBox(height: 54, child: filter),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: _HeartRateControlStrip(
                  activityBar: activityBar,
                  summary: _HeartRateSummaryStrip(heartRate: heartRate),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(height: 520, child: chart),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: math.min(330.0, c.maxWidth * .31),
            child: Column(children: [
              Expanded(
                child: _Panel(
                  title: 'Точки нагрузки · $highPoints',
                  subtitle: _loadPointsExpanded
                      ? 'Расширенный просмотр · Z4–Z5 · $highPct% времени'
                      : 'Z4–Z5 · $highPct% времени · нажмите точку для перехода на график',
                  trailing: IconButton(
                    tooltip: _loadPointsExpanded ? 'Свернуть точки нагрузки' : 'Развернуть точки нагрузки',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                    onPressed: () => setState(() => _loadPointsExpanded = !_loadPointsExpanded),
                    icon: Icon(_loadPointsExpanded ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded, size: 15, color: _AA.green),
                  ),
                  child: _AnalyticsHrLoadEventsPanel(
                    heartRate: heartRate,
                    rosterPlayers: widget.rosterPlayers,
                    selected: _focusedLoadPoint,
                    onSelect: (point) => setState(() => _focusedLoadPoint = point),
                  ),
                ),
              ),
              if (!_loadPointsExpanded) ...[
              const SizedBox(height: 7),
              _HrDetailLauncher(
                icon: Icons.auto_awesome_rounded,
                title: 'ИИ-паспорт',
                value: 'Открыть',
                note: 'риски, интервалы, восстановление',
                tone: _AA.green,
                builder: (_) => aiPassport,
              ),
              const SizedBox(height: 7),
              _HrDetailLauncher(
                icon: Icons.monitor_heart_rounded,
                title: 'Средний / максимум',
                value: '${heartRate.effectiveAvgBpm.toStringAsFixed(0)} / ${heartRate.effectiveMaxBpm}',
                note: 'bpm по выбранным игрокам',
                tone: _AA.green,
                builder: (_) => playerChart,
              ),
              const SizedBox(height: 7),
              _HrDetailLauncher(
                icon: Icons.donut_large_rounded,
                title: 'Зоны ЧСС',
                value: 'Z1–Z5',
                note: 'распределение нагрузки',
                tone: const Color(0xFFF97316),
                builder: (_) => zones,
              ),
              const SizedBox(height: 7),
              _HrDetailLauncher(
                icon: Icons.groups_rounded,
                title: 'Polar H10',
                value: '${heartRate.effectivePlayersCount}',
                note: 'игроков · нажмите для списка',
                tone: _AA.green,
                builder: (_) => players,
              ),
              ],
            ]),
          ),
        ]),
      );
    });
  }
}


_AnalyticsHeartRate _resolveAnalyticsHeartRate(_AnalyticsHeartRate source, List<TrackerPlayerOption> roster) {
  TrackerPlayerOption? byId(int? id) {
    if (id == null || id <= 0) return null;
    for (final p in roster) {
      if (p.id == id || p.identityIds.contains(id)) return p;
    }
    return null;
  }

  String resolvedName(int? id, String raw) {
    final rosterPlayer = byId(id);
    if (rosterPlayer != null && rosterPlayer.name.trim().isNotEmpty) return rosterPlayer.name.trim();
    final value = raw.trim();
    final technical = value.isEmpty || RegExp(r'^(игрок|player)(\s*\d+)?$', caseSensitive: false).hasMatch(value);
    return technical ? (id != null && id > 0 ? 'Игрок $id' : 'Игрок') : value;
  }

  final players = source.players.map((p) => _AnalyticsHrPlayer(
    playerId: p.playerId,
    playerName: resolvedName(p.playerId, p.playerName),
    avgBpm: p.avgBpm,
    maxBpm: p.maxBpm,
    samplesCount: p.samplesCount,
    z1: p.z1,
    z2: p.z2,
    z3: p.z3,
    z4: p.z4,
    z5: p.z5,
  )).toList(growable: false);

  final timeline = source.timeline.map((p) => _AnalyticsHrPoint(
    playerId: p.playerId,
    playerName: resolvedName(p.playerId, p.playerName),
    timeMs: p.timeMs,
    minute: p.minute,
    bpm: p.bpm,
    zone: p.zone,
    hrLoad: p.hrLoad,
    activityType: p.activityType,
  )).toList(growable: false);

  return _AnalyticsHeartRate(
    players: players,
    timeline: timeline,
    avgBpm: source.avgBpm,
    maxBpm: source.maxBpm,
    samplesCount: source.samplesCount,
    playersCount: source.playersCount,
  );
}

TrackerPlayerOption? _analyticsRosterPlayer(List<TrackerPlayerOption> roster, int? id) {
  if (id == null || id <= 0) return null;
  for (final player in roster) {
    if (player.id == id || player.identityIds.contains(id)) return player;
  }
  return null;
}

Widget _analyticsPlayerAvatar(TrackerPlayerOption? player, {double size = 28}) {
  final avatar = player?.avatar?.trim() ?? '';
  return ClipRRect(
    borderRadius: BorderRadius.circular(size * .34),
    child: Container(
      width: size,
      height: size,
      color: Colors.white,
      child: avatar.isEmpty
          ? const Icon(Icons.person_rounded, color: _AA.green, size: 17)
          : Image.network(
              avatar,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: _AA.green, size: 17),
            ),
    ),
  );
}

class _AnalyticsHrFilterOption {
  const _AnalyticsHrFilterOption({required this.key, required this.label, required this.samples, required this.avgBpm, this.playerId});
  final String key;
  final String label;
  final int samples;
  final double avgBpm;
  final int? playerId;
}

String _analyticsHrEntityKey({int? playerId, required String playerName}) {
  if (playerId != null && playerId > 0) return 'id:$playerId';
  final name = playerName.trim().toLowerCase();
  return 'name:${name.isEmpty ? 'team' : name}';
}

List<_AnalyticsHrFilterOption> _analyticsHrFilterOptions(_AnalyticsHeartRate heartRate) {
  final byKey = <String, _AnalyticsHrFilterOption>{};
  for (final p in heartRate.players) {
    final key = _analyticsHrEntityKey(playerId: p.playerId, playerName: p.playerName);
    byKey[key] = _AnalyticsHrFilterOption(key: key, label: p.playerName.trim().isEmpty ? 'Игрок' : p.playerName.trim(), samples: p.samplesCount, avgBpm: p.avgBpm, playerId: p.playerId);
  }
  final counts = <String, int>{};
  final sums = <String, int>{};
  final labels = <String, String>{};
  for (final p in heartRate.timelineForChart) {
    final key = _analyticsHrEntityKey(playerId: p.playerId, playerName: p.playerName);
    counts[key] = (counts[key] ?? 0) + 1;
    sums[key] = (sums[key] ?? 0) + p.bpm;
    final name = p.playerName.trim();
    if (name.isNotEmpty) labels[key] = name;
  }
  for (final entry in counts.entries) {
    final old = byKey[entry.key];
    final avg = entry.value <= 0 ? (old?.avgBpm ?? 0) : (sums[entry.key] ?? 0) / entry.value;
    byKey[entry.key] = _AnalyticsHrFilterOption(
      key: entry.key,
      label: old?.label ?? labels[entry.key] ?? 'Игрок',
      samples: math.max(old?.samples ?? 0, entry.value),
      avgBpm: avg.toDouble(),
      playerId: old?.playerId ?? (entry.key.startsWith('id:') ? int.tryParse(entry.key.substring(3)) : null),
    );
  }
  final list = byKey.values.toList();
  list.sort((a, b) => b.samples.compareTo(a.samples));
  return list;
}

_AnalyticsHeartRate _analyticsHeartRateFiltered(_AnalyticsHeartRate source, Set<String> keys) {
  if (keys.isEmpty) return source;
  final players = source.players.where((p) => keys.contains(_analyticsHrEntityKey(playerId: p.playerId, playerName: p.playerName))).toList(growable: false);
  final timeline = source.timelineForChart.where((p) => keys.contains(_analyticsHrEntityKey(playerId: p.playerId, playerName: p.playerName))).toList(growable: false);
  final samples = timeline.isNotEmpty ? timeline.length : players.fold<int>(0, (sum, p) => sum + p.samplesCount);
  final weighted = players.fold<int>(0, (sum, p) => sum + (p.samplesCount > 0 ? p.samplesCount : 1));
  final avg = timeline.isNotEmpty
      ? timeline.fold<int>(0, (sum, p) => sum + p.bpm) / timeline.length
      : (weighted <= 0 ? 0.0 : players.fold<double>(0, (sum, p) => sum + p.avgBpm * (p.samplesCount > 0 ? p.samplesCount : 1)) / weighted);
  final maxBpm = timeline.isNotEmpty
      ? timeline.fold<int>(0, (maxV, p) => maxV > p.bpm ? maxV : p.bpm)
      : players.fold<int>(0, (maxV, p) => maxV > p.maxBpm ? maxV : p.maxBpm);
  return _AnalyticsHeartRate(
    players: players,
    timeline: timeline,
    avgBpm: avg.isNaN || avg.isInfinite ? 0 : avg,
    maxBpm: maxBpm,
    samplesCount: samples,
    playersCount: players.length,
  );
}

class _AnalyticsHrPlayerFilterBar extends StatelessWidget {
  const _AnalyticsHrPlayerFilterBar({required this.heartRate, required this.rosterPlayers, required this.selectedKeys, required this.onAll, required this.onToggle});
  final _AnalyticsHeartRate heartRate;
  final List<TrackerPlayerOption> rosterPlayers;
  final Set<String> selectedKeys;
  final VoidCallback onAll;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final options = _analyticsHrFilterOptions(heartRate);
    if (options.isEmpty) {
      return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(8)),
        child: const Text('Фильтр игроков появится, когда сервер отдаст player_id/name для Polar H10.', style: TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
      );
    }
    return Container(
      decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(8)),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        children: [
          _AnalyticsHrFilterChip(label: 'Все', note: '${heartRate.effectiveSamplesCount} HR', active: selectedKeys.isEmpty, onTap: onAll),
          const SizedBox(width: 6),
          for (final option in options) ...[
            _AnalyticsHrFilterChip(
              label: option.label,
              note: option.avgBpm > 0 ? '${option.avgBpm.toStringAsFixed(0)} bpm · ${option.samples}' : '${option.samples} HR',
              active: selectedKeys.contains(option.key),
              avatar: _analyticsRosterPlayer(rosterPlayers, option.playerId),
              onTap: () => onToggle(option.key),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsHrFilterChip extends StatelessWidget {
  const _AnalyticsHrFilterChip({required this.label, required this.note, required this.active, required this.onTap, this.avatar});
  final String label;
  final String note;
  final bool active;
  final TrackerPlayerOption? avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: active ? _AA.soft : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: active ? _AA.greenLine : _AA.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          avatar == null
              ? Icon(active ? Icons.check_circle_rounded : Icons.favorite_border_rounded, size: 14, color: active ? _AA.green : _AA.muted)
              : _analyticsPlayerAvatar(avatar, size: 27),
          const SizedBox(width: 7),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 142), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _AA.green : _AA.text, fontSize: 11.2, fontWeight: FontWeight.w700))),
            Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}

class _HeartRateSummaryPanel extends StatelessWidget {
  const _HeartRateSummaryPanel({required this.heartRate});
  final _AnalyticsHeartRate heartRate;
  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Сводка ЧСС',
        subtitle: 'средний, максимум, записи, игроки',
        child: Row(children: [
          Expanded(child: _MiniNumber(title: 'Средний', value: heartRate.effectiveAvgBpm > 0 ? heartRate.effectiveAvgBpm.toStringAsFixed(0) : '—', note: 'bpm')),
          Expanded(child: _MiniNumber(title: 'Максимум', value: heartRate.effectiveMaxBpm > 0 ? '${heartRate.effectiveMaxBpm}' : '—', note: 'bpm')),
          Expanded(child: _MiniNumber(title: 'HR-записи', value: '${heartRate.effectiveSamplesCount}', note: 'точек')),
          Expanded(child: _MiniNumber(title: 'Игроки', value: '${heartRate.effectivePlayersCount}', note: 'Polar')),
        ]),
      );
}



class _HeartRateControlStrip extends StatelessWidget {
  const _HeartRateControlStrip({required this.activityBar, required this.summary});
  final Widget activityBar;
  final Widget summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 6, child: Center(child: activityBar)),
        Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: _AA.line),
        Expanded(flex: 6, child: Center(child: summary)),
      ]),
    );
  }
}

class _HeartRateSummaryStrip extends StatelessWidget {
  const _HeartRateSummaryStrip({required this.heartRate});
  final _AnalyticsHeartRate heartRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _HrStripMetric(label: 'СРЕД.', value: heartRate.effectiveAvgBpm > 0 ? heartRate.effectiveAvgBpm.toStringAsFixed(0) : '—', unit: 'bpm'),
        const _HrStripDivider(),
        _HrStripMetric(label: 'МАКС.', value: heartRate.effectiveMaxBpm > 0 ? '${heartRate.effectiveMaxBpm}' : '—', unit: 'bpm'),
        const _HrStripDivider(),
        _HrStripMetric(label: 'ТОЧКИ', value: '${heartRate.effectiveSamplesCount}', unit: 'HR'),
        const _HrStripDivider(),
        _HrStripMetric(label: 'ИГРОКИ', value: '${heartRate.effectivePlayersCount}', unit: 'Polar'),
      ]),
    );
  }
}

class _HrStripMetric extends StatelessWidget {
  const _HrStripMetric({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(value, style: const TextStyle(color: _AA.text, fontSize: 12, fontWeight: FontWeight.w900)),
      const SizedBox(width: 3),
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w800)),
        Text(unit, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
      ]),
    ]),
  );
}

class _HrStripDivider extends StatelessWidget {
  const _HrStripDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 26, color: _AA.line);
}

class _HrDetailLauncher extends StatelessWidget {
  const _HrDetailLauncher({
    required this.icon,
    required this.title,
    required this.value,
    required this.note,
    required this.tone,
    required this.builder,
  });
  final IconData icon;
  final String title;
  final String value;
  final String note;
  final Color tone;
  final WidgetBuilder builder;

  void _open(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.42),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
                child: Row(children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: tone.withOpacity(.10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: tone, size: 19)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(color: _AA.text, fontSize: 14, fontWeight: FontWeight.w900)),
                    Text(note, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w600)),
                  ])),
                  IconButton(onPressed: () => Navigator.of(dialogContext).pop(), icon: const Icon(Icons.close_rounded, color: _AA.text)),
                ]),
              ),
              const Divider(height: 1, color: _AA.line),
              Expanded(child: Padding(padding: const EdgeInsets.all(8), child: builder(dialogContext))),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => _open(context),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: tone.withOpacity(.09), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: tone, size: 18)),
        const SizedBox(width: 9),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 12.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
        ])),
        const SizedBox(width: 8),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value, style: TextStyle(color: tone, fontSize: 11, fontWeight: FontWeight.w900)),
          const Icon(Icons.chevron_right_rounded, color: _AA.muted, size: 16),
        ]),
      ]),
    ),
  );
}

class _AnalyticsHrLineChart extends StatefulWidget {
  const _AnalyticsHrLineChart({required this.heartRate, this.focusedPoint});
  final _AnalyticsHeartRate heartRate;
  final _AnalyticsHrPoint? focusedPoint;
  @override
  State<_AnalyticsHrLineChart> createState() => _AnalyticsHrLineChartState();
}

class _AnalyticsHrLineChartState extends State<_AnalyticsHrLineChart> {
  double _zoom = 1;
  double _windowStart = 0;
  _AnalyticsHrPoint? _selectedPoint;

  @override
  void didUpdateWidget(covariant _AnalyticsHrLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedPoint != null && widget.focusedPoint != oldWidget.focusedPoint) {
      _selectedPoint = widget.focusedPoint;
      _zoom = math.max(_zoom, 4);
      final all = widget.heartRate.timelineForChart;
      if (all.isNotEmpty) {
        final minX = all.map(_analyticsHrPointSortKey).reduce((a, b) => a < b ? a : b);
        final maxX = all.map(_analyticsHrPointSortKey).reduce((a, b) => a > b ? a : b);
        final full = math.max(60000, maxX - minX);
        final visible = math.max(60000, (full / _zoom).round());
        final maxStart = math.max(1, full - visible);
        final target = _analyticsHrPointSortKey(widget.focusedPoint!) - minX - visible ~/ 2;
        _windowStart = (target / maxStart).clamp(0.0, 1.0).toDouble();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.heartRate.timelineForChart;
    if (all.isEmpty) return const _Empty(icon: Icons.show_chart_rounded, text: 'Таймлайн ЧСС пока не получен. Нажмите Обновить после завершения Live или проверьте endpoint get_tracker_heart_rate_summary.php.');
    final sorted = [...all]..sort((a,b)=>_analyticsHrPointSortKey(a).compareTo(_analyticsHrPointSortKey(b)));
    final minX = _analyticsHrPointSortKey(sorted.first);
    final maxX = math.max(minX + 60000, _analyticsHrPointSortKey(sorted.last));
    final full = math.max(60000, maxX-minX);
    final visible = math.max(60000, (full / _zoom).round());
    final maxStart = math.max(0, full-visible);
    final start = minX + (maxStart * _windowStart).round();
    final end = start + visible;
    final points = sorted.where((p){ final x=_analyticsHrPointSortKey(p); return x>=start && x<=end; }).toList(growable:false);
    final redCount = points.where((p)=>p.bpm>=160 || p.zone=='z4' || p.zone=='z5').length;
    final redPct = points.isEmpty ? 0 : (redCount / points.length * 100).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _AnalyticsHrTimelineLegend(points: points, players: widget.heartRate.players),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFFFF7F7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFD5D5))),
        child: Row(children:[
          const Icon(Icons.warning_amber_rounded, color: _AA.red, size: 15), const SizedBox(width:6),
          Expanded(child: Text(redPct>0 ? 'Высокая нагрузка: $redPct% выбранного отрезка в Z4–Z5' : 'Красная зона нагрузки: Z4–Z5 (от 160 bpm)', style: const TextStyle(color:_AA.text,fontSize: 10.4,fontWeight:FontWeight.w800))),
          Text('Масштаб ${_zoom.toStringAsFixed(1)}×', style: const TextStyle(color:_AA.red,fontSize: 9.6,fontWeight:FontWeight.w900)),
        ]),
      ),
      Row(children:[
        const Icon(Icons.zoom_out_rounded,size:16,color:_AA.muted),
        Expanded(child: Slider(value:_zoom,min:1,max:8,divisions:14,label:'${_zoom.toStringAsFixed(1)}×',onChanged:(v)=>setState(()=>_zoom=v))),
        const Icon(Icons.zoom_in_rounded,size:16,color:_AA.muted),
      ]),
      if (_zoom > 1) SizedBox(height:24, child: Row(children:[
        const SizedBox(width:8), const Text('Положение',style:TextStyle(color:_AA.muted,fontSize: 9.6,fontWeight:FontWeight.w700)),
        Expanded(child: Slider(value:_windowStart,min:0,max:1,onChanged:(v)=>setState(()=>_windowStart=v))),
      ])),
      Container(
        height: 38,
        margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
        child: CustomPaint(painter: _AnalyticsHrLoadMiniMapPainter(points: sorted, selectedPoint: _selectedPoint, windowStart: start, windowEnd: end), child: const SizedBox.expand()),
      ),
      if (_selectedPoint != null)
        Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
          child: Row(children: [
            Icon(Icons.my_location_rounded, size: 14, color: _analyticsZoneColor(_selectedPoint!.zone)),
            const SizedBox(width: 6),
            Expanded(child: Text('${_selectedPoint!.playerName} · ${_analyticsHrTimeLabel(_selectedPoint!, sorted)} · ${_analyticsHrMinuteFromStart(_selectedPoint!, sorted)} мин от старта · ${_activityLabel(_selectedPoint!.activityType)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w800))),
            Text('${_selectedPoint!.bpm} bpm · ${_selectedPoint!.zone.toUpperCase()}', style: TextStyle(color: _analyticsZoneColor(_selectedPoint!.zone), fontSize: 10.4, fontWeight: FontWeight.w900)),
          ]),
        ),
      Expanded(child: LayoutBuilder(builder: (context, chartSize) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (points.isEmpty || chartSize.maxWidth <= 76) return;
            final dx = (details.localPosition.dx - 46).clamp(0.0, math.max(1.0, chartSize.maxWidth - 76));
            final target = start + (dx / math.max(1.0, chartSize.maxWidth - 76) * (end - start)).round();
            final nearest = points.reduce((a, b) => (_analyticsHrPointSortKey(a) - target).abs() <= (_analyticsHrPointSortKey(b) - target).abs() ? a : b);
            setState(() => _selectedPoint = nearest);
          },
          child: ClipRect(child: CustomPaint(painter: _AnalyticsHrLinePainter(points: points, selectedPoint: _selectedPoint), child: const SizedBox.expand())),
        );
      })),
    ]);
  }
}

class _AnalyticsHrTimelineLegend extends StatelessWidget {
  const _AnalyticsHrTimelineLegend({required this.points, required this.players});
  final List<_AnalyticsHrPoint> points;
  final List<_AnalyticsHrPlayer> players;

  @override
  Widget build(BuildContext context) {
    final names = <String>[];
    for (final p in points) {
      final name = p.playerName.trim();
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
    }
    if (names.isEmpty) {
      for (final p in players) {
        final name = p.playerName.trim();
        if (name.isNotEmpty && !names.contains(name)) names.add(name);
      }
    }
    final sorted = [...points]..sort((a, b) => _analyticsHrPointSortKey(a).compareTo(_analyticsHrPointSortKey(b)));
    final from = sorted.isEmpty ? 0 : _analyticsHrPointSortKey(sorted.first);
    final to = sorted.isEmpty ? 0 : _analyticsHrPointSortKey(sorted.last);
    final durationMin = math.max(1, ((to - from).abs() / 60000).round());
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.monitor_heart_rounded, color: _AA.red, size: 15),
        const SizedBox(width: 6),
        Expanded(child: Text(names.isEmpty ? 'Команда · Polar H10 · $durationMin мин' : '${names.take(4).join(', ')}${names.length > 4 ? ' +${names.length - 4}' : ''} · $durationMin мин', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700))),
        Text('${points.length} HR', style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}


String _normalizeActivity(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.contains('strength') || v.contains('сил')) return 'strength';
  if (v.contains('gym') || v.contains('зал') || v.contains('indoor')) return 'gym';
  if (v.contains('run') || v.contains('бег')) return 'run';
  if (v.contains('field') || v.contains('пол') || v.contains('football')) return 'field';
  return v.isEmpty ? 'unknown' : v;
}

String _activityLabel(String raw) {
  switch (_normalizeActivity(raw)) {
    case 'run': return 'Бег';
    case 'gym': return 'Зал';
    case 'strength': return 'Сила';
    case 'field': return 'Поле';
    default: return 'Режим не указан';
  }
}

_AnalyticsHeartRate _analyticsHeartRateByActivity(_AnalyticsHeartRate source, String activity) {
  final normalized = _normalizeActivity(activity);
  final timeline = source.timelineForChart.where((p) => _normalizeActivity(p.activityType) == normalized).toList(growable: false);
  if (timeline.isEmpty) return source;
  final ids = timeline.map((p) => _analyticsHrEntityKey(playerId: p.playerId, playerName: p.playerName)).toSet();
  final players = source.players.where((p) => ids.contains(_analyticsHrEntityKey(playerId: p.playerId, playerName: p.playerName))).toList(growable: false);
  final avg = timeline.fold<int>(0, (s, p) => s + p.bpm) / timeline.length;
  final maxBpm = timeline.fold<int>(0, (m, p) => math.max(m, p.bpm));
  return _AnalyticsHeartRate(players: players, timeline: timeline, avgBpm: avg, maxBpm: maxBpm, samplesCount: timeline.length, playersCount: ids.length);
}

class _AnalyticsHrActivityBar extends StatelessWidget {
  const _AnalyticsHrActivityBar({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    const values = <String, String>{'all': 'Все режимы', 'run': 'Бег', 'gym': 'Зал', 'strength': 'Сила', 'field': 'Поле'};
    return Container(
      height: 38,
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: values.entries.map((e) {
        final active = e.key == value;
        return Padding(
          padding: const EdgeInsets.only(right: 5),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => onChanged(e.key),
            child: Container(
              height: 34,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(color: active ? _AA.soft : Colors.transparent, borderRadius: BorderRadius.circular(9), border: Border.all(color: active ? _AA.green : Colors.transparent)),
              child: Text(e.value, style: TextStyle(color: active ? _AA.green : _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w800)),
            ),
          ),
        );
      }).toList(growable: false),
      ),
    );
  }
}

String _analyticsHrTimeLabel(_AnalyticsHrPoint point, List<_AnalyticsHrPoint> all) {
  if (point.timeMs > 0) {
    final dt = DateTime.fromMillisecondsSinceEpoch(point.timeMs);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
  return '${point.minute} мин';
}

int _analyticsHrMinuteFromStart(_AnalyticsHrPoint point, List<_AnalyticsHrPoint> all) {
  if (all.isEmpty) return math.max(0, point.minute);
  final same = all.where((p) => _analyticsHrGroupKey(p) == _analyticsHrGroupKey(point)).toList(growable: false);
  final source = same.isEmpty ? all : same;
  final minKey = source.map(_analyticsHrPointSortKey).reduce(math.min);
  return math.max(0, ((_analyticsHrPointSortKey(point) - minKey) / 60000).floor());
}

String _hrAiAssessment(_AnalyticsHrPoint p) {
  final zone = p.zone.isEmpty ? _analyticsZoneFromBpm(p.bpm) : p.zone;
  if (zone == 'z5' || p.bpm >= 180) return 'Пиковая внутренняя нагрузка. Для юношеского футболиста это короткий предельный отрезок: проверьте восстановление, технику движения и повторяемость пиков.';
  if (zone == 'z4' || p.bpm >= 160) return 'Высокая аэробно-анаэробная нагрузка. Подходит для интенсивных игровых серий, но важны длительность интервала и пауза восстановления.';
  if (zone == 'z3' || p.bpm >= 140) return 'Рабочая развивающая интенсивность. Оцените, соответствует ли она задаче упражнения и возрастной группе игрока.';
  return 'Умеренная нагрузка. Используйте вместе со скоростью, длительностью и субъективной оценкой самочувствия.';
}

class _AnalyticsHrLoadEventsPanel extends StatelessWidget {
  const _AnalyticsHrLoadEventsPanel({required this.heartRate, required this.rosterPlayers, required this.selected, required this.onSelect, this.onOpenAi});
  final _AnalyticsHeartRate heartRate;
  final List<TrackerPlayerOption> rosterPlayers;
  final _AnalyticsHrPoint? selected;
  final ValueChanged<_AnalyticsHrPoint> onSelect;
  final ValueChanged<_AnalyticsHrPoint>? onOpenAi;

  @override
  Widget build(BuildContext context) {
    final all = [...heartRate.timelineForChart]..sort((a, b) => _analyticsHrPointSortKey(a).compareTo(_analyticsHrPointSortKey(b)));
    final high = all.where((p) => p.bpm >= 160 || p.zone == 'z4' || p.zone == 'z5').toList(growable: false);
    final events = <_AnalyticsHrPoint>[];
    for (final p in high) {
      if (events.isEmpty || _analyticsHrGroupKey(events.last) != _analyticsHrGroupKey(p) || (_analyticsHrPointSortKey(p) - _analyticsHrPointSortKey(events.last)).abs() >= 60000) events.add(p);
    }
    if (events.isEmpty) return const _Empty(icon: Icons.health_and_safety_rounded, text: 'Точек Z4–Z5 нет. Нагрузка находится в контролируемом диапазоне.');
    return ListView.separated(
      padding: const EdgeInsets.all(7),
      itemCount: math.min(events.length, 40),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final p = events[i];
        final active = identical(selected, p) || (selected != null && _analyticsHrPointSortKey(selected!) == _analyticsHrPointSortKey(p) && _analyticsHrGroupKey(selected!) == _analyticsHrGroupKey(p));
        final roster = _analyticsRosterPlayer(rosterPlayers, p.playerId);
        return InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () { onSelect(p); onOpenAi?.call(p); },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: active ? const Color(0xFFFFF1F2) : Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: active ? _AA.red : _AA.line)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _analyticsPlayerAvatar(roster, size: 34),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(p.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 11.4, fontWeight: FontWeight.w700))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: _AA.red, borderRadius: BorderRadius.circular(99)), child: Text('${p.bpm} bpm', style: const TextStyle(color: Colors.white, fontSize: 10.4, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 3),
                Text('${_analyticsHrTimeLabel(p, all)} · ${_analyticsHrMinuteFromStart(p, all)} мин от старта · ${p.zone.toUpperCase()} · ${_activityLabel(p.activityType)}', style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_hrAiAssessment(p), maxLines: active ? 5 : 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 9.6, height: 1.25, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [const Icon(Icons.auto_awesome_rounded, size: 12, color: _AA.red), const SizedBox(width: 4), Expanded(child: Text(onOpenAi == null ? 'Перейти к точке на графике' : 'Открыть точку в ИИ-чате', style: const TextStyle(color: _AA.red, fontSize: 10.4, fontWeight: FontWeight.w700))), if (onOpenAi != null) const Icon(Icons.arrow_forward_rounded, size: 12, color: _AA.red)]),
              ])),
            ]),
          ),
        );
      },
    );
  }
}


class _HrHighInterval {
  const _HrHighInterval({required this.playerId, required this.playerName, required this.start, required this.end, required this.peak, required this.points});
  final int? playerId;
  final String playerName;
  final _AnalyticsHrPoint start;
  final _AnalyticsHrPoint end;
  final _AnalyticsHrPoint peak;
  final int points;
  int get durationSec {
    final a = start.timeMs > 0 ? start.timeMs : start.minute * 60000;
    final b = end.timeMs > 0 ? end.timeMs : end.minute * 60000;
    return math.max(0, ((b - a) / 1000).round());
  }
}

List<_HrHighInterval> _hrHighIntervals(_AnalyticsHeartRate hr) {
  final grouped = <String, List<_AnalyticsHrPoint>>{};
  for (final p in hr.timelineForChart.where((e) => e.bpm >= 160 || e.zone == 'z4' || e.zone == 'z5')) {
    final key = _analyticsHrEntityKey(playerId: p.playerId, playerName: p.playerName);
    grouped.putIfAbsent(key, () => <_AnalyticsHrPoint>[]).add(p);
  }
  final out = <_HrHighInterval>[];
  for (final points in grouped.values) {
    points.sort((a,b) => (a.timeMs > 0 ? a.timeMs : a.minute*60000).compareTo(b.timeMs > 0 ? b.timeMs : b.minute*60000));
    if (points.isEmpty) continue;
    var chunk = <_AnalyticsHrPoint>[points.first];
    void flush() {
      if (chunk.isEmpty) return;
      final peak = chunk.reduce((a,b) => a.bpm >= b.bpm ? a : b);
      final interval = _HrHighInterval(playerId: chunk.first.playerId, playerName: chunk.first.playerName, start: chunk.first, end: chunk.last, peak: peak, points: chunk.length);
      if (interval.durationSec >= 30 || chunk.length >= 3) out.add(interval);
    }
    for (var i=1;i<points.length;i++) {
      final prev = points[i-1].timeMs > 0 ? points[i-1].timeMs : points[i-1].minute*60000;
      final now = points[i].timeMs > 0 ? points[i].timeMs : points[i].minute*60000;
      if ((now-prev).abs() <= 90000) {
        chunk.add(points[i]);
      } else {
        flush();
        chunk = <_AnalyticsHrPoint>[points[i]];
      }
    }
    flush();
  }
  out.sort((a,b) => b.peak.bpm.compareTo(a.peak.bpm));
  return out;
}

int? _hrRecoveryDrop(_AnalyticsHeartRate hr, _AnalyticsHrPoint peak, int seconds) {
  final key = _analyticsHrEntityKey(playerId: peak.playerId, playerName: peak.playerName);
  final base = peak.timeMs > 0 ? peak.timeMs : peak.minute*60000;
  _AnalyticsHrPoint? best;
  var bestDelta = 1<<62;
  for (final p in hr.timelineForChart) {
    if (_analyticsHrEntityKey(playerId: p.playerId, playerName: p.playerName) != key) continue;
    final t = p.timeMs > 0 ? p.timeMs : p.minute*60000;
    final d = (t - (base + seconds*1000)).abs();
    if (d < bestDelta && d <= 20000) { bestDelta=d; best=p; }
  }
  if (best == null) return null;
  return peak.bpm - best.bpm;
}

class _HrAiPassportPanel extends StatelessWidget {
  const _HrAiPassportPanel({required this.heartRate, required this.rosterPlayers, required this.focusedPoint, required this.onFocus});
  final _AnalyticsHeartRate heartRate;
  final List<TrackerPlayerOption> rosterPlayers;
  final _AnalyticsHrPoint? focusedPoint;
  final ValueChanged<_AnalyticsHrPoint> onFocus;

  @override
  Widget build(BuildContext context) {
    final intervals = _hrHighIntervals(heartRate);
    final points = heartRate.timelineForChart;
    final high = points.where((p) => p.bpm >= 160 || p.zone == 'z4' || p.zone == 'z5').length;
    final highPct = points.isEmpty ? 0.0 : high / points.length * 100;
    final peak = focusedPoint ?? (points.isEmpty ? null : points.reduce((a,b)=>a.bpm>=b.bpm?a:b));
    final r30 = peak == null ? null : _hrRecoveryDrop(heartRate, peak, 30);
    final r60 = peak == null ? null : _hrRecoveryDrop(heartRate, peak, 60);
    final r120 = peak == null ? null : _hrRecoveryDrop(heartRate, peak, 120);
    final recovery = r60 ?? r30 ?? r120;
    var readiness = 82;
    if (highPct > 35) readiness -= 18; else if (highPct > 20) readiness -= 9;
    if (recovery != null && recovery < 12) readiness -= 16;
    if ((peak?.bpm ?? 0) >= 195) readiness -= 12;
    readiness = readiness.clamp(0,100);
    final risk = (peak?.bpm ?? 0) >= 200 || (intervals.isNotEmpty && intervals.first.durationSec >= 300) || (recovery != null && recovery < 10);
    final assessment = risk
      ? 'Нетипичная реакция: высокий пик или слабое снижение ЧСС. Проверьте самочувствие, гидратацию и восстановление; не увеличивайте интенсивность без оценки тренера.'
      : highPct >= 20
        ? 'Выраженная нагрузка Z4–Z5. Для футбольной работы это допустимо в интервальных сериях, но объём следующего интенсивного блока стоит уменьшить и проконтролировать восстановление.'
        : 'Нагрузка контролируемая. Можно продолжать план, сохранив разминку, паузы и наблюдение за восстановлением после пиков.';
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Row(children:[
          Expanded(child:_HrPassportScore(label:'Готовность', value:'$readiness', suffix:'/100', color: readiness>=75?_AA.green:(readiness>=55?const Color(0xFFF59E0B):_AA.red))),
          const SizedBox(width:6),
          Expanded(child:_HrPassportScore(label:'Z4–Z5', value:highPct.toStringAsFixed(0), suffix:'%', color:highPct>=25?_AA.red:const Color(0xFFF59E0B))),
          const SizedBox(width:6),
          Expanded(child:_HrPassportScore(label:'Интервалы', value:'${intervals.length}', suffix:'', color:_AA.text)),
        ]),
        const SizedBox(height:8),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: risk?const Color(0xFFFFF1F2):const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: risk?const Color(0xFFFDA4AF):const Color(0xFFBBF7D0))),
          child: Row(crossAxisAlignment:CrossAxisAlignment.start, children:[
            Icon(risk?Icons.warning_amber_rounded:Icons.auto_awesome_rounded, color:risk?_AA.red:_AA.green, size:18),
            const SizedBox(width:8),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text(risk?'Внимание тренера':'ИИ-оценка нагрузки', style:TextStyle(color:risk?_AA.red:_AA.green,fontSize: 10.4,fontWeight:FontWeight.w900)),
              const SizedBox(height:3),
              Text(assessment, style:const TextStyle(color:_AA.text,fontSize: 9.6,height:1.3,fontWeight:FontWeight.w600)),
            ])),
          ]),
        ),
        const SizedBox(height:8),
        const Text('Восстановление после выбранного пика', style:TextStyle(color:_AA.text,fontSize: 10.4,fontWeight:FontWeight.w900)),
        const SizedBox(height:5),
        Row(children:[
          Expanded(child:_HrRecoveryCell(label:'30 сек', value:r30)),
          const SizedBox(width:5),
          Expanded(child:_HrRecoveryCell(label:'60 сек', value:r60)),
          const SizedBox(width:5),
          Expanded(child:_HrRecoveryCell(label:'120 сек', value:r120)),
        ]),
        const SizedBox(height:8),
        Row(children:[
          const Expanded(child:Text('Продолжительные интервалы Z4–Z5', style:TextStyle(color:_AA.text,fontSize: 10.4,fontWeight:FontWeight.w900))),
          Text('${intervals.length}', style:const TextStyle(color:_AA.red,fontSize: 11.2,fontWeight:FontWeight.w900)),
        ]),
        const SizedBox(height:5),
        if (intervals.isEmpty)
          const Text('Интервалы высокой нагрузки не обнаружены.', style:TextStyle(color:_AA.muted,fontSize: 9.6,fontWeight:FontWeight.w600))
        else
          for (final i in intervals.take(5))
            InkWell(
              onTap:()=>onFocus(i.peak),
              borderRadius:BorderRadius.circular(9),
              child:Container(
                margin:const EdgeInsets.only(bottom:5),
                padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),
                decoration:BoxDecoration(color:focusedPoint==i.peak?const Color(0xFFFFE4E6):Colors.white,borderRadius:BorderRadius.circular(9),border:Border.all(color:focusedPoint==i.peak?_AA.red:_AA.line)),
                child:Row(children:[
                  _analyticsPlayerAvatar(_analyticsRosterPlayer(rosterPlayers,i.playerId),size:27),
                  const SizedBox(width:7),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(i.playerName,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_AA.text,fontSize: 9.6,fontWeight:FontWeight.w900)),
                    Text('${_analyticsHrTimeLabel(i.start, heartRate.timelineForChart)}–${_analyticsHrTimeLabel(i.end, heartRate.timelineForChart)} · ${math.max(1,(i.durationSec/60).ceil())} мин · ${_activityLabel(i.peak.activityType)}',style:const TextStyle(color:_AA.muted,fontSize: 9.6,fontWeight:FontWeight.w700)),
                  ])),
                  Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:4),decoration:BoxDecoration(color:_AA.red,borderRadius:BorderRadius.circular(99)),child:Text('${i.peak.bpm}',style:const TextStyle(color:Colors.white,fontSize: 9.6,fontWeight:FontWeight.w900))),
                ]),
              ),
            ),
      ],
    );
  }
}

class _HrPassportScore extends StatelessWidget {
  const _HrPassportScore({required this.label,required this.value,required this.suffix,required this.color});
  final String label,value,suffix; final Color color;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:color.withOpacity(.07),borderRadius:BorderRadius.circular(9)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:_AA.muted,fontSize: 9.6,fontWeight:FontWeight.w700)),const SizedBox(height:2),Text('$value$suffix',style:TextStyle(color:color,fontSize:13,fontWeight:FontWeight.w900))]));
}

class _HrRecoveryCell extends StatelessWidget {
  const _HrRecoveryCell({required this.label,required this.value});
  final String label; final int? value;
  @override Widget build(BuildContext context){final good=value!=null&&value!>=18;final poor=value!=null&&value!<12;return Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:poor?const Color(0xFFFFF1F2):(good?const Color(0xFFF0FDF4):_AA.soft),borderRadius:BorderRadius.circular(8)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:_AA.muted,fontSize: 9.6,fontWeight:FontWeight.w700)),const SizedBox(height:2),Text(value==null?'нет данных':'−$value bpm',style:TextStyle(color:poor?_AA.red:(good?_AA.green:_AA.text),fontSize: 10.4,fontWeight:FontWeight.w900))]));}
}

class _AnalyticsHrZonesPanel extends StatelessWidget {
  const _AnalyticsHrZonesPanel({required this.heartRate});
  final _AnalyticsHeartRate heartRate;
  @override
  Widget build(BuildContext context) {
    var z = <int>[
      heartRate.players.fold<int>(0, (a, p) => a + p.z1),
      heartRate.players.fold<int>(0, (a, p) => a + p.z2),
      heartRate.players.fold<int>(0, (a, p) => a + p.z3),
      heartRate.players.fold<int>(0, (a, p) => a + p.z4),
      heartRate.players.fold<int>(0, (a, p) => a + p.z5),
    ];
    var total = z.fold<int>(0, (a, b) => a + b);
    if (total <= 0) {
      final points = heartRate.timelineForChart;
      z = <int>[
        points.where((p) => (p.zone.isEmpty ? _analyticsZoneFromBpm(p.bpm) : p.zone) == 'z1').length,
        points.where((p) => (p.zone.isEmpty ? _analyticsZoneFromBpm(p.bpm) : p.zone) == 'z2').length,
        points.where((p) => (p.zone.isEmpty ? _analyticsZoneFromBpm(p.bpm) : p.zone) == 'z3').length,
        points.where((p) => (p.zone.isEmpty ? _analyticsZoneFromBpm(p.bpm) : p.zone) == 'z4').length,
        points.where((p) => (p.zone.isEmpty ? _analyticsZoneFromBpm(p.bpm) : p.zone) == 'z5').length,
      ];
      total = z.fold<int>(0, (a, b) => a + b);
    }
    if (total <= 0) return const _Empty(icon: Icons.favorite_border_rounded, text: 'Зоны ЧСС пока не рассчитаны.');
    const labels = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
    return SingleChildScrollView(
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < z.length; i++) ...[
          Row(children: [
            SizedBox(width: 28, child: Text(labels[i], style: const TextStyle(color: _AA.text, fontSize: 11.2, fontWeight: FontWeight.w700))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: Stack(children: [Container(height: 12, color: const Color(0xFFF3F4F6)), FractionallySizedBox(widthFactor: (z[i] / total).clamp(0.0, 1.0).toDouble(), child: Container(height: 12, color: _analyticsZoneColor(labels[i].toLowerCase())))]))),
            const SizedBox(width: 8),
            SizedBox(width: 52, child: Text('${(z[i] / total * 100).toStringAsFixed(0)}%', textAlign: TextAlign.right, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700))),
          ]),
          if (i != z.length - 1) const SizedBox(height: 9),
        ],
      ]),
    );
  }
}

class _AnalyticsHrPlayersList extends StatelessWidget {
  const _AnalyticsHrPlayersList({required this.heartRate, required this.rosterPlayers});
  final _AnalyticsHeartRate heartRate;
  final List<TrackerPlayerOption> rosterPlayers;

  List<_AnalyticsHrPoint> _pointsFor(_AnalyticsHrPlayer player) {
    final points = heartRate.timelineForChart.where((point) {
      if (player.playerId != null && point.playerId != null) return point.playerId == player.playerId;
      return point.playerName.trim().toLowerCase() == player.playerName.trim().toLowerCase();
    }).toList(growable: false)
      ..sort((a, b) {
        final at = a.timeMs > 0 ? a.timeMs : a.minute * 60000;
        final bt = b.timeMs > 0 ? b.timeMs : b.minute * 60000;
        return at.compareTo(bt);
      });
    return points;
  }

  String _durationLabel(_AnalyticsHrPlayer player) {
    final points = _pointsFor(player);
    if (points.length < 2) return 'Нет длительности';
    final first = points.first.timeMs > 0 ? points.first.timeMs : points.first.minute * 60000;
    final last = points.last.timeMs > 0 ? points.last.timeMs : points.last.minute * 60000;
    final totalSeconds = math.max(0, ((last - first) / 1000).round());
    if (totalSeconds <= 0) return 'Менее 1 мин';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours} ч ${minutes.toString().padLeft(2, '0')} мин';
    return '${math.max(1, minutes)} мин';
  }

  String _signalRange(_AnalyticsHrPlayer player) {
    final points = _pointsFor(player).where((p) => p.timeMs > 0).toList(growable: false);
    if (points.length < 2) return '${player.samplesCount} HR-точек';
    String clock(int ms) {
      final dt = _trackerMoscowFromEpochMs(ms);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${clock(points.first.timeMs)}–${clock(points.last.timeMs)} · ${player.samplesCount} HR';
  }

  @override
  Widget build(BuildContext context) {
    if (heartRate.players.isEmpty) return const _Empty(icon: Icons.groups_rounded, text: 'Нет игроков с Polar H10.');
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 1120 ? 4 : (width >= 600 ? 3 : 1);
      final ratio = columns == 1 ? 3.55 : (columns == 3 ? 2.75 : 2.55);
      return GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: ratio,
        ),
        itemCount: heartRate.players.length,
        itemBuilder: (context, i) {
          final player = heartRate.players[i];
          final high = player.z4 + player.z5;
          final highPct = player.samplesCount <= 0 ? 0.0 : high / player.samplesCount * 100;
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _analyticsPlayerAvatar(_analyticsRosterPlayer(rosterPlayers, player.playerId), size: 36),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(player.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 11.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Средний ${player.avgBpm.toStringAsFixed(0)} · максимум ${player.maxBpm} bpm', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
                const Spacer(),
                Row(children: [
                  const Icon(Icons.bluetooth_connected_rounded, size: 13, color: _AA.green),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Подключение ${_durationLabel(player)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 9.6, fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 3),
                Text(_signalRange(player), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: (highPct / 100).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(highPct >= 20 ? _AA.red : _AA.green),
                  ),
                ),
                const SizedBox(height: 3),
                Text('Z4–Z5 ${highPct.toStringAsFixed(0)}%', style: TextStyle(color: highPct >= 20 ? _AA.red : _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w800)),
              ])),
            ]),
          );
        },
      );
    });
  }
}

Color _analyticsZoneColor(String zone) {
  switch (zone) {
    case 'z5': return const Color(0xFFE11D48);
    case 'z4': return const Color(0xFFF97316);
    case 'z3': return const Color(0xFFFACC15);
    case 'z2': return const Color(0xFF84CC16);
    default: return const Color(0xFFA3E635);
  }
}

abstract class _BaseChartPainter extends CustomPainter {
  void drawGrid(Canvas canvas, Rect rect, {int lines = 5}) {
    final paint = Paint()
      ..color = _AA.line
      ..strokeWidth = 1;
    for (var i = 0; i <= lines; i++) {
      final y = rect.bottom - rect.height * i / lines;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  void text(
    Canvas canvas,
    String value,
    Offset offset, {
    double size = 10,
    Color color = _AA.text,
    FontWeight weight = FontWeight.w700,
    TextAlign align = TextAlign.left,
    double maxWidth = 120,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: value, style: TextStyle(fontFamily: 'Inter', color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 2,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }
}

class _AnalyticsHrPlayerSummaryChart extends StatelessWidget {
  const _AnalyticsHrPlayerSummaryChart({required this.heartRate});
  final _AnalyticsHeartRate heartRate;

  @override
  Widget build(BuildContext context) {
    final list = heartRate.players.where((p) => p.samplesCount > 0 || p.avgBpm > 0 || p.maxBpm > 0).take(20).toList(growable: false);
    if (list.isEmpty) return const _Empty(icon: Icons.monitor_heart_rounded, text: 'По выбранным игрокам нет данных ЧСС.');
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (context, i) {
        final p = list[i];
        final high = p.z4 + p.z5;
        final highPct = p.samplesCount <= 0 ? 0.0 : high / p.samplesCount * 100;
        final delta = math.max(0, p.maxBpm - p.avgBpm.round());
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(p.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 12.2, fontWeight: FontWeight.w700))),
              if (highPct >= 20)
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(99)), child: Text('Z4–Z5 ${highPct.toStringAsFixed(0)}%', style: const TextStyle(color: _AA.red, fontSize: 10.4, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 7),
            Row(children: [
              Expanded(child: _HrCompareValue(label: 'Средний', value: p.avgBpm > 0 ? p.avgBpm.toStringAsFixed(0) : '—', color: _AA.green)),
              const SizedBox(width: 6),
              Expanded(child: _HrCompareValue(label: 'Максимум', value: p.maxBpm > 0 ? '${p.maxBpm}' : '—', color: _AA.red)),
              const SizedBox(width: 6),
              Expanded(child: _HrCompareValue(label: 'Разница', value: delta > 0 ? '+$delta' : '—', color: _AA.text)),
            ]),
          ]),
        );
      },
    );
  }
}

class _HrCompareValue extends StatelessWidget {
  const _HrCompareValue({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(.07), borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text('$value bpm', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11.4, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _AnalyticsHrPlayerSummaryPainter extends _BaseChartPainter {
  _AnalyticsHrPlayerSummaryPainter({required this.players});
  final List<_AnalyticsHrPlayer> players;

  @override
  void paint(Canvas canvas, Size size) {
    if (players.isEmpty) return;
    final rect = Rect.fromLTWH(48, 26, math.max(10.0, size.width - 70), math.max(10.0, size.height - 86));
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    drawGrid(canvas, rect);
    final maxValue = math.max(130.0, players.map((p) => p.maxBpm > 0 ? p.maxBpm.toDouble() : p.avgBpm).fold<double>(1, (a, b) => a > b ? a : b) + 12);
    final minValue = math.max(40.0, players.map((p) => p.avgBpm > 0 ? p.avgBpm : p.maxBpm.toDouble()).fold<double>(999, (a, b) => a < b ? a : b) - 8);
    final gap = rect.width / players.length;
    for (var i = 0; i < players.length; i++) {
      final p = players[i];
      final avg = p.avgBpm > 0 ? p.avgBpm : p.maxBpm.toDouble();
      final max = p.maxBpm > 0 ? p.maxBpm.toDouble() : avg;
      final x = rect.left + gap * i + gap / 2;
      final avgY = rect.bottom - rect.height * ((avg - minValue) / (maxValue - minValue)).clamp(0.0, 1.0).toDouble();
      final maxY = rect.bottom - rect.height * ((max - minValue) / (maxValue - minValue)).clamp(0.0, 1.0).toDouble();
      canvas.drawLine(Offset(x, avgY), Offset(x, maxY), Paint()..color = _AA.red.withOpacity(.45)..strokeWidth = 5..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(x, avgY), 5, Paint()..color = _AA.green);
      canvas.drawCircle(Offset(x, maxY), 5, Paint()..color = _AA.red);
      text(canvas, avg.toStringAsFixed(0), Offset(x - 14, avgY + 8), size: 8.5, color: _AA.green, weight: FontWeight.w700, maxWidth: 32, align: TextAlign.center);
      text(canvas, _shortAnalyticsName(p.playerName), Offset(x - gap * .42, rect.bottom + 8), size: 8, color: _AA.muted, maxWidth: gap * .86, align: TextAlign.center);
    }
    text(canvas, 'зелёная точка — средний bpm · красная — максимум', Offset(rect.left, 0), size: 10.2, color: _AA.text, weight: FontWeight.w700, maxWidth: rect.width);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnalyticsHrPlayerSummaryPainter oldDelegate) => oldDelegate.players != players;
}

String _shortAnalyticsName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList(growable: false);
  if (parts.isEmpty) return 'Игрок';
  if (parts.length == 1) return parts.first.length <= 10 ? parts.first : '${parts.first.substring(0, 10)}…';
  return '${parts.first} ${parts[1].substring(0, 1)}.';
}

int _analyticsHrPointSortKey(_AnalyticsHrPoint p) => p.timeMs > 0 ? p.timeMs : p.minute * 60000;

String _analyticsHrGroupKey(_AnalyticsHrPoint p) {
  final name = p.playerName.trim();
  final id = p.playerId;
  if (id != null && id > 0) return 'id:$id';
  return 'name:${name.isEmpty ? 'team' : name}';
}

List<List<_AnalyticsHrPoint>> _analyticsHrPointGroups(List<_AnalyticsHrPoint> points) {
  final map = <String, List<_AnalyticsHrPoint>>{};
  for (final p in points.where((p) => p.bpm > 0)) {
    map.putIfAbsent(_analyticsHrGroupKey(p), () => <_AnalyticsHrPoint>[]).add(p);
  }
  final groups = map.values.toList(growable: false);
  for (final g in groups) {
    g.sort((a, b) => _analyticsHrPointSortKey(a).compareTo(_analyticsHrPointSortKey(b)));
  }
  groups.sort((a, b) => (a.first.playerName).compareTo(b.first.playerName));
  return groups;
}

Color _analyticsSeriesColor(int index) {
  const colors = <Color>[
    _AA.red,
    _AA.green,
    Color(0xFFF59E0B),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF0F766E),
  ];
  return colors[index % colors.length];
}

class _AnalyticsHrLoadMiniMapPainter extends CustomPainter {
  _AnalyticsHrLoadMiniMapPainter({required this.points, required this.selectedPoint, required this.windowStart, required this.windowEnd});
  final List<_AnalyticsHrPoint> points;
  final _AnalyticsHrPoint? selectedPoint;
  final int windowStart;
  final int windowEnd;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final left = 8.0, right = math.max(9.0, size.width - 8), top = 8.0, bottom = math.max(9.0, size.height - 9);
    final minX = points.map(_analyticsHrPointSortKey).reduce(math.min);
    final maxX = math.max(minX + 60000, points.map(_analyticsHrPointSortKey).reduce(math.max));
    double xFor(int x) => left + (right-left) * ((x-minX)/(maxX-minX)).clamp(0.0, 1.0);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(left, top, right, bottom), const Radius.circular(7)), Paint()..color=const Color(0xFFEFF3F6));
    for (final p in points.where((p) => p.bpm >= 140)) {
      final x=xFor(_analyticsHrPointSortKey(p));
      final h=p.bpm>=180 ? bottom-top : p.bpm>=160 ? (bottom-top)*.75 : (bottom-top)*.45;
      canvas.drawLine(Offset(x,bottom),Offset(x,bottom-h),Paint()
        ..color = _analyticsZoneColor(p.zone).withOpacity(p.bpm >= 160 ? 0.85 : 0.45)
        ..strokeWidth = p.bpm >= 160 ? 2.2 : 1.2
        ..strokeCap = StrokeCap.round);
    }
    final w1=xFor(windowStart), w2=xFor(windowEnd);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w1,top,w2,bottom), const Radius.circular(6)), Paint()..color=_AA.green.withOpacity(.08));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w1,top,w2,bottom), const Radius.circular(6)), Paint()..color=_AA.green..style=PaintingStyle.stroke..strokeWidth=1.4);
    if (selectedPoint != null) {
      final x=xFor(_analyticsHrPointSortKey(selectedPoint!));
      canvas.drawLine(Offset(x,top-2),Offset(x,bottom+2),Paint()..color=_AA.red..strokeWidth=2.5);
      canvas.drawCircle(Offset(x,top+2),4,Paint()..color=_AA.red);
    }
  }
  @override
  bool shouldRepaint(covariant _AnalyticsHrLoadMiniMapPainter old) => old.points != points || old.selectedPoint != selectedPoint || old.windowStart != windowStart || old.windowEnd != windowEnd;
}

class _AnalyticsHrLinePainter extends _BaseChartPainter {
  _AnalyticsHrLinePainter({required this.points, this.selectedPoint});
  final List<_AnalyticsHrPoint> points;
  final _AnalyticsHrPoint? selectedPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final list = points.where((p) => p.bpm > 0).toList(growable: false);
    if (list.isEmpty) return;
    final rect = Rect.fromLTWH(46, 28, math.max(10.0, size.width - 76), math.max(10.0, size.height - 74));
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    drawGrid(canvas, rect);
    final minX = list.map(_analyticsHrPointSortKey).fold<int>(_analyticsHrPointSortKey(list.first), (a, b) => a < b ? a : b).toDouble();
    var maxX = list.map(_analyticsHrPointSortKey).fold<int>(_analyticsHrPointSortKey(list.first), (a, b) => a > b ? a : b).toDouble();
    if ((maxX - minX).abs() < 1) maxX = minX + 60000;
    final minBpm = math.max(40.0, list.map((p) => p.bpm).fold<int>(list.first.bpm, (a, b) => a < b ? a : b).toDouble() - 10);
    final maxBpm = math.max(130.0, list.map((p) => p.bpm).fold<int>(list.first.bpm, (a, b) => a > b ? a : b).toDouble() + 12);
    Offset map(_AnalyticsHrPoint p, double value) => Offset(
      rect.left + rect.width * ((_analyticsHrPointSortKey(p) - minX) / (maxX - minX)).clamp(0.0, 1.0).toDouble(),
      rect.bottom - rect.height * ((value - minBpm) / (maxBpm - minBpm)).clamp(0.0, 1.0).toDouble(),
    );
    if (maxBpm > 160) {
      final redTop = rect.top;
      final redBottom = rect.bottom - rect.height * ((160 - minBpm) / (maxBpm - minBpm)).clamp(0.0, 1.0).toDouble();
      canvas.drawRect(Rect.fromLTRB(rect.left, redTop, rect.right, redBottom), Paint()..color = const Color(0xFFE11D48).withOpacity(.075));
      text(canvas, 'ВЫСОКАЯ НАГРУЗКА', Offset(rect.left + 8, rect.top + 7), size: 9.6, color: const Color(0xFFE11D48), weight: FontWeight.w900, maxWidth: 120);
    }
    for (final z in [120, 140, 160, 180]) {
      if (z < minBpm || z > maxBpm) continue;
      final y = rect.bottom - rect.height * ((z - minBpm) / (maxBpm - minBpm)).clamp(0.0, 1.0).toDouble();
      final color = z >= 180 ? const Color(0xFFE11D48) : (z >= 160 ? const Color(0xFFF97316) : (z >= 140 ? const Color(0xFFFACC15) : const Color(0xFF84CC16)));
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), Paint()..color = color.withOpacity(.45)..strokeWidth = 1.1);
      text(canvas, 'Z${z == 120 ? 2 : z == 140 ? 3 : z == 160 ? 4 : 5}', Offset(rect.right - 24, y - 14), size: 9.8, color: color, weight: FontWeight.w700, maxWidth: 24);
    }

    Path smoothPath(List<Offset> values) {
      final path = Path();
      if (values.isEmpty) return path;
      path.moveTo(values.first.dx, values.first.dy);
      for (var i = 1; i < values.length; i++) {
        final prev = values[i - 1];
        final current = values[i];
        final midX = (prev.dx + current.dx) / 2;
        path.cubicTo(midX, prev.dy, midX, current.dy, current.dx, current.dy);
      }
      return path;
    }

    final groups = _analyticsHrPointGroups(list);
    for (var gi = 0; gi < groups.length; gi++) {
      final group = groups[gi];
      if (group.isEmpty) continue;
      final lineColor = groups.length == 1 ? _AA.red : _analyticsSeriesColor(gi);
      final bpmOffsets = <Offset>[];
      final loadOffsets = <Offset>[];
      for (final p in group) {
        bpmOffsets.add(map(p, p.bpm.toDouble()));
        loadOffsets.add(map(p, minBpm + (maxBpm - minBpm) * (p.hrLoad.clamp(0, 200).toDouble() / 200.0)));
      }
      final bpm = smoothPath(bpmOffsets);
      final load = smoothPath(loadOffsets);

      if (groups.length == 1 && bpmOffsets.length > 1) {
        final fill = Path.from(bpm)
          ..lineTo(bpmOffsets.last.dx, rect.bottom)
          ..lineTo(bpmOffsets.first.dx, rect.bottom)
          ..close();
        canvas.drawPath(
          fill,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0x2EDC2626), Color(0x00DC2626)],
            ).createShader(rect),
        );
      }

      canvas.drawPath(load, Paint()..color = const Color(0xFF7F1D1D).withOpacity(groups.length == 1 ? .28 : .13)..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round);
      canvas.drawPath(bpm, Paint()..color = lineColor.withOpacity(.12)..style = PaintingStyle.stroke..strokeWidth = groups.length == 1 ? 9 : 6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      canvas.drawPath(bpm, Paint()..color = lineColor..style = PaintingStyle.stroke..strokeWidth = groups.length == 1 ? 3.2 : 2.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

      final every = math.max(1, (group.length / (groups.length == 1 ? 8 : 4)).ceil());
      for (var i = 0; i < group.length; i += every) {
        final p = group[i];
        final o = map(p, p.bpm.toDouble());
        canvas.drawCircle(o, groups.length == 1 ? 4 : 3.2, Paint()..color = _analyticsZoneColor(p.zone));
        text(canvas, '${p.bpm}', o + const Offset(-9, -19), size: 9.4, color: lineColor, weight: FontWeight.w700, maxWidth: 30);
      }
      if (groups.length > 1) {
        final p = group.first;
        final o = map(p, p.bpm.toDouble());
        final name = _shortAnalyticsName(p.playerName.isEmpty ? 'Игрок' : p.playerName);
        text(canvas, name, o + const Offset(5, 7), size: 9.0, color: lineColor, weight: FontWeight.w700, maxWidth: 72);
      }
    }

    const timeTicks = 6;
    final durationMs = math.max(60000.0, maxX - minX);
    for (var i = 0; i <= timeTicks; i++) {
      final ratio = i / timeTicks;
      final x = rect.left + rect.width * ratio;
      final elapsedSec = durationMs * ratio / 1000.0;
      final elapsedMin = elapsedSec / 60.0;
      final label = durationMs < 300000
          ? '${elapsedSec.round()} с'
          : (elapsedMin >= 60
              ? '${(elapsedMin / 60).floor()}:${(elapsedMin % 60).round().toString().padLeft(2, '0')}'
              : '${elapsedMin.round()} мин');
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        Paint()..color = _AA.line.withOpacity(i == 0 || i == timeTicks ? .75 : .42)..strokeWidth = 1,
      );
      final labelWidth = i == 0 || i == timeTicks ? 58.0 : 52.0;
      text(
        canvas,
        label,
        Offset((x - labelWidth / 2).clamp(0.0, size.width - labelWidth), rect.bottom + 9),
        size: 11.2,
        color: _AA.muted,
        weight: FontWeight.w800,
        maxWidth: labelWidth,
        align: TextAlign.center,
      );
    }

    if (selectedPoint != null) {
      final selectedKey = _analyticsHrPointSortKey(selectedPoint!);
      final visibleSelected = list.where((p) =>
        _analyticsHrPointSortKey(p) == selectedKey &&
        _analyticsHrGroupKey(p) == _analyticsHrGroupKey(selectedPoint!)
      ).toList();
      if (visibleSelected.isNotEmpty) {
        final point = visibleSelected.first;
        final o = map(point, point.bpm.toDouble());
        final tone = _analyticsZoneColor(point.zone);
        canvas.drawRect(
          Rect.fromLTRB(math.max(rect.left, o.dx - 8), rect.top, math.min(rect.right, o.dx + 8), rect.bottom),
          Paint()..color = tone.withOpacity(.08),
        );
        canvas.drawLine(Offset(o.dx, rect.top), Offset(o.dx, rect.bottom), Paint()..color = tone..strokeWidth = 2.4);
        canvas.drawCircle(o, 18, Paint()..color = tone.withOpacity(.07));
        canvas.drawCircle(o, 11, Paint()..color = Colors.white);
        canvas.drawCircle(o, 7, Paint()..color = tone);
        canvas.drawCircle(o, 11, Paint()..color = tone..style = PaintingStyle.stroke..strokeWidth = 2.4);
        final elapsed = math.max(0, ((selectedKey - minX) / 60000).round());
        final elapsedLabel = elapsed >= 60
            ? '${elapsed ~/ 60}:${(elapsed % 60).toString().padLeft(2, '0')}'
            : '$elapsed мин';
        final bubbleLeft = (o.dx + 12).clamp(rect.left, math.max(rect.left, rect.right - 112)).toDouble();
        final bubbleTop = (o.dy - 38).clamp(rect.top + 3, rect.bottom - 43).toDouble();
        final bubbleRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(bubbleLeft, bubbleTop, 108, 36),
          const Radius.circular(9),
        );
        canvas.drawRRect(bubbleRect, Paint()..color = Colors.white);
        canvas.drawRRect(bubbleRect, Paint()..color = tone..style = PaintingStyle.stroke..strokeWidth = 1.5);
        text(canvas, '${point.bpm} bpm · ${point.zone.toUpperCase()}', Offset(bubbleLeft + 8, bubbleTop + 5), size: 10.5, color: tone, weight: FontWeight.w900, maxWidth: 94);
        text(canvas, elapsedLabel, Offset(bubbleLeft + 8, bubbleTop + 19), size: 9.4, color: _AA.text, weight: FontWeight.w800, maxWidth: 94);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnalyticsHrLinePainter oldDelegate) => oldDelegate.points != points || oldDelegate.selectedPoint != selectedPoint;
}

class _LocalTrackAnalysis {
  const _LocalTrackAnalysis({
    required this.distanceM,
    required this.durationSec,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.sprintCount,
    required this.sprintDistanceM,
    required this.hsrDistanceM,
    required this.accelCount,
    required this.decelCount,
    required this.speedSamples,
  });

  final double distanceM;
  final int durationSec;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final int sprintCount;
  final double sprintDistanceM;
  final double hsrDistanceM;
  final int accelCount;
  final int decelCount;
  final List<double> speedSamples;

  static _LocalTrackAnalysis fromPoints(List<ActionTrackerGpsPoint> points, {double sprintThresholdKmh = 18.0, double hsrThresholdKmh = 14.0}) {
    if (points.length < 2) {
      return const _LocalTrackAnalysis(
        distanceM: 0,
        durationSec: 0,
        maxSpeedKmh: 0,
        avgSpeedKmh: 0,
        sprintCount: 0,
        sprintDistanceM: 0,
        hsrDistanceM: 0,
        accelCount: 0,
        decelCount: 0,
        speedSamples: <double>[],
      );
    }
    double distance = 0;
    double maxSpeed = 0;
    double sprintDistance = 0;
    double hsrDistance = 0;
    int sprintCount = 0;
    int accelCount = 0;
    int decelCount = 0;
    double? prevSpeed;
    bool inSprint = false;
    int activeMs = 0;
    final samples = <double>[];

    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (_segmentBreaks(a, b)) {
        prevSpeed = null;
        inSprint = false;
        continue;
      }
      final rawDtMs = (b.timeMs - a.timeMs).abs();
      final dtMs = rawDtMs <= 0 ? 1000 : rawDtMs;
      if (dtMs > 60000) {
        prevSpeed = null;
        inSprint = false;
        continue;
      }
      final d = (b.distanceDeltaM != null && b.distanceDeltaM!.isFinite && b.distanceDeltaM! > 0 && b.distanceDeltaM! <= 80)
          ? b.distanceDeltaM!
          : _distanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);
      if (d <= 0 || d > 80) continue;
      final storedSpeed = b.speedKmh;
      final speed = storedSpeed != null && storedSpeed.isFinite && storedSpeed > 0 && storedSpeed <= 45
          ? storedSpeed
          : (d / (dtMs / 1000.0)) * 3.6;
      if (speed.isNaN || speed.isInfinite || speed > 45) continue;
      activeMs += dtMs;
      distance += d;
      maxSpeed = math.max(maxSpeed, speed);
      samples.add(speed);
      if (speed >= hsrThresholdKmh) hsrDistance += d;
      if (speed >= sprintThresholdKmh) {
        sprintDistance += d;
        if (!inSprint) sprintCount++;
        inSprint = true;
      } else if (speed < sprintThresholdKmh * .88) {
        inSprint = false;
      }
      if (prevSpeed != null) {
        final accMps2 = ((speed - prevSpeed!) / 3.6) / (dtMs / 1000.0);
        if (accMps2 >= 1.0) accelCount++;
        if (accMps2 <= -1.0) decelCount++;
      }
      prevSpeed = speed;
    }

    final rawDurationSec = ((points.last.timeMs - points.first.timeMs).abs() / 1000).round();
    final activeDurationSec = (activeMs / 1000).round();
    final durationSec = activeDurationSec > 0 ? activeDurationSec : (rawDurationSec <= 0 ? math.max(1, points.length - 1) : rawDurationSec);
    final avg = durationSec <= 0 ? 0.0 : (distance / durationSec) * 3.6;
    return _LocalTrackAnalysis(
      distanceM: distance,
      durationSec: durationSec,
      maxSpeedKmh: maxSpeed,
      avgSpeedKmh: avg,
      sprintCount: sprintCount,
      sprintDistanceM: sprintDistance,
      hsrDistanceM: hsrDistance,
      accelCount: accelCount,
      decelCount: decelCount,
      speedSamples: samples,
    );
  }

  static double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class _AnalyticsReportEmptyState extends StatelessWidget {
  const _AnalyticsReportEmptyState({required this.onOpenSelection});

  final VoidCallback onOpenSelection;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _AA.line),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _AA.greenSoft, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.assignment_rounded, color: _AA.green, size: 25),
            ),
            const SizedBox(height: 14),
            const Text('Сначала выберите сессию', style: TextStyle(color: _AA.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text(
              'Отчёт формируется по текущему выбору аналитики. Выберите дату, сессию и игроков — повторный календарь в отчётах не нужен.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _AA.muted, fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 17),
            FilledButton.icon(
              onPressed: onOpenSelection,
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text('Открыть выбор аналитики'),
              style: FilledButton.styleFrom(backgroundColor: _AA.green, foregroundColor: Colors.white),
            ),
          ]),
        ),
      ),
    );
  }
}

const _tabs = <_AnalyticsTab>[
  _AnalyticsTab('Обзор', Icons.dashboard_rounded),
  _AnalyticsTab('Карта', Icons.map_rounded),
  _AnalyticsTab('Скорость', Icons.speed_rounded),
  _AnalyticsTab('Пульс', Icons.favorite_rounded),
  _AnalyticsTab('Команда', Icons.groups_rounded),
  _AnalyticsTab('Рейтинг', Icons.leaderboard_rounded),
  _AnalyticsTab('Локомоторика', Icons.directions_run_rounded),
  _AnalyticsTab('Механика', Icons.compare_arrows_rounded),
  _AnalyticsTab('Микроцикл', Icons.calendar_view_week_rounded),
  _AnalyticsTab('ИИ-анализ', Icons.auto_awesome_rounded),
  _AnalyticsTab('Отчёты', Icons.assignment_rounded),
  _AnalyticsTab('Офлайн GPS', Icons.cloud_download_rounded),
];

class _AnalyticsTab {
  const _AnalyticsTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _AA {
  static const bg = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const soft = Color(0xFFFFFFFF);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenLine = Color(0xFFD2EBDD);
  static const line = Color(0xFFE9ECEA);
  static const text = Color(0xFF111512);
  static const muted = Color(0xFF6B746E);
  static const green = Color(0xFF00A750);
  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFDC2626);

  // Единая геометрия для мобильной и планшетной аналитики трекера.
  static const double mobileCardRadius = 18.0;
  static const double mobileInnerRadius = 12.0;
  static const double mobileChipRadius = 10.0;
  static const double tabletCardRadius = 16.0;
  static const double tabletInnerRadius = 12.0;
  static const double sheetRadius = 16.0;
}


class _CoachInsightMetric {
  const _CoachInsightMetric(this.title, this.value, [this.note = '']);
  final String title;
  final String value;
  final String note;
}

class _CoachInsight {
  const _CoachInsight({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.metrics,
    required this.bullets,
    this.footer,
    this.accent = _AA.green,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<_CoachInsightMetric> metrics;
  final List<String> bullets;
  final String? footer;
  final Color accent;
}

class _CoachInsightScaffold extends StatelessWidget {
  const _CoachInsightScaffold({required this.child, required this.insight, required this.onClose});
  final Widget child;
  final _CoachInsight? insight;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final current = insight;
      final phone = c.maxWidth < 720;
      if (phone) {
        return Stack(children: [
          Positioned.fill(child: child),
          if (current != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: math.min(math.max(320.0, c.maxHeight * .64), c.maxHeight - 12),
              child: _CoachInsightPanel(insight: current, onClose: onClose, mobile: true),
            ),
        ]);
      }
      final panelWidth = current == null ? 0.0 : math.min(390.0, math.max(330.0, c.maxWidth * .31));
      return Row(children: [
        Expanded(child: child),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: panelWidth,
          child: current == null ? const SizedBox.shrink() : _CoachInsightPanel(insight: current, onClose: onClose),
        ),
      ]);
    });
  }
}

class _CoachInsightPanel extends StatelessWidget {
  const _CoachInsightPanel({required this.insight, required this.onClose, this.mobile = false});
  final _CoachInsight insight;
  final VoidCallback onClose;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _AA.card,
        border: Border(left: mobile ? BorderSide.none : const BorderSide(color: _AA.line), top: mobile ? const BorderSide(color: _AA.line) : BorderSide.none),
        boxShadow: mobile ? [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 20, offset: const Offset(0, -8))] : const <BoxShadow>[],
      ),
      child: SafeArea(
        top: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _AA.line))),
            child: Row(children: [
              Container(width: 26, height: 26, decoration: BoxDecoration(color: insight.accent.withOpacity(.10), borderRadius: BorderRadius.circular(6)), child: Icon(insight.icon, size: 17, color: insight.accent)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(insight.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700)),
                Text(insight.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
              ])),
              _NoHoverTap(onTap: onClose, child: const SizedBox(width: 34, height: 34, child: Icon(Icons.close_rounded, size: 18, color: _AA.muted))),
            ]),
          ),
          Expanded(
            child: ListView(
              primary: false,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.22,
                  children: [for (final m in insight.metrics) _CoachMetricCell(metric: m, accent: insight.accent)],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _AA.greenSoft, borderRadius: BorderRadius.circular(6)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Что важно тренеру', style: TextStyle(color: _AA.text, fontSize: 11.2, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    for (final b in insight.bullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: insight.accent, borderRadius: BorderRadius.circular(99))),
                          const SizedBox(width: 7),
                          Expanded(child: Text(b, style: const TextStyle(color: _AA.text, fontSize: 10.4, height: 1.25, fontWeight: FontWeight.w700))),
                        ]),
                      ),
                  ]),
                ),
                if ((insight.footer ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _Hint(text: insight.footer!),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _CoachMetricCell extends StatelessWidget {
  const _CoachMetricCell({required this.metric, required this.accent});
  final _CoachInsightMetric metric;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(metric.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 12.4, fontWeight: FontWeight.w700)),
        if (metric.note.isNotEmpty) Text(metric.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _YouthSpeedProfile {
  const _YouthSpeedProfile({required this.label, required this.hsrKmh, required this.sprintKmh});

  final String label;
  final double hsrKmh;
  final double sprintKmh;

  static _YouthSpeedProfile fromLabel(String value) {
    final raw = value.toUpperCase();
    final age = int.tryParse(RegExp(r'U\s*([0-9]{1,2})').firstMatch(raw)?.group(1) ?? '');
    if (age == null || age <= 0) {
      return const _YouthSpeedProfile(label: 'ДЮФ', hsrKmh: 14.0, sprintKmh: 18.0);
    }
    if (age <= 8) return const _YouthSpeedProfile(label: 'U6–U8', hsrKmh: 11.5, sprintKmh: 14.5);
    if (age <= 10) return const _YouthSpeedProfile(label: 'U9–U10', hsrKmh: 12.5, sprintKmh: 15.5);
    if (age <= 12) return const _YouthSpeedProfile(label: 'U11–U12', hsrKmh: 13.5, sprintKmh: 17.0);
    if (age <= 13) return const _YouthSpeedProfile(label: 'U13', hsrKmh: 14.0, sprintKmh: 18.0);
    if (age <= 15) return const _YouthSpeedProfile(label: 'U14–U15', hsrKmh: 16.0, sprintKmh: 20.0);
    if (age <= 17) return const _YouthSpeedProfile(label: 'U16–U17', hsrKmh: 18.0, sprintKmh: 22.0);
    return const _YouthSpeedProfile(label: 'Профи', hsrKmh: 19.8, sprintKmh: 25.2);
  }
}





class _SessionPickerPlayerSummary {
  _SessionPickerPlayerSummary({required this.id, required this.name, required this.player});
  final int id;
  final String name;
  final TrackerPlayerOption? player;
  int count = 0;
  double distanceM = 0;
  double maxSpeedKmh = 0;
  int sprints = 0;
  int accel = 0;
  int decel = 0;
  bool hasData = false;

  void add(TrackerSessionModel session) {
    count += 1;
    distanceM += session.distanceM;
    maxSpeedKmh = math.max<double>(maxSpeedKmh, _jsonDouble(session.maxSpeedKmh));
    sprints += session.sprintCount;
    accel += session.accelCount;
    decel += session.decelCount;
    hasData = hasData || distanceM > 0 || maxSpeedKmh > 0 || sprints > 0 || accel > 0 || decel > 0 || session.durationSec > 0;
  }
}

class _SessionPickerSessionTile extends StatelessWidget {
  const _SessionPickerSessionTile({
    required this.session,
    required this.player,
    required this.checked,
    required this.playerName,
    required this.createdLabel,
    required this.onTap,
  });

  final TrackerSessionModel session;
  final TrackerPlayerOption? player;
  final bool checked;
  final String playerName;
  final String createdLabel;
  final VoidCallback onTap;

  bool get _hasPolar => _trackerSessionHasPolar(session);

  bool get _hasTracker => _trackerSessionHasGps(session);

  @override
  Widget build(BuildContext context) {
    final kindColor = session.personalSession ? _AA.green : const Color(0xFF2563EB);
    final kindLabel = session.personalSession ? 'Личная' : 'Командная';
    final hasPolar = _hasPolar;
    final hasTracker = _hasTracker;
    final equipmentLabel = hasPolar && hasTracker
        ? 'Polar + трекер'
        : hasPolar
            ? 'Polar H10'
            : hasTracker
                ? 'GPS-трекер'
                : 'Без устройства';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: checked ? 1 : 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, selectedT, child) {
        return Transform.scale(
          scale: 1 + selectedT * .018,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              splashColor: _AA.green.withOpacity(.13),
              highlightColor: _AA.green.withOpacity(.06),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: checked ? _AA.greenSoft.withOpacity(.72) : _AA.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: checked
                        ? _AA.green.withOpacity(.24)
                        : _AA.line.withOpacity(.52),
                    width: checked ? .85 : .65,
                  ),
                  boxShadow: checked
                      ? [
                          BoxShadow(
                            color: _AA.green.withOpacity(.045),
                            blurRadius: 16,
                            spreadRadius: -10,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Stack(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      _SessionAvatar(player: player),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            playerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _AA.text,
                              fontSize: 13.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '#${session.id} · $createdLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _AA.muted,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 34),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _TrackerSessionTinyBadge(label: kindLabel, color: kindColor),
                      _TrackerSessionTinyBadge(
                        label: equipmentLabel,
                        color: hasPolar ? const Color(0xFFDC2626) : _AA.green,
                      ),
                      if (hasPolar)
                        _TrackerSessionTinyBadge(
                          label: 'Polar · ${_trackerSensorDuration(session.polarDurationSec, session.durationSec)}',
                          color: const Color(0xFFDC2626),
                        ),
                      if (hasTracker)
                        _TrackerSessionTinyBadge(
                          label: 'GPS · ${_trackerSensorDuration(session.gpsDurationSec, session.durationSec)}',
                          color: _AA.green,
                        ),
                      if (hasPolar && session.heartRateSamplesCount > 0)
                        _TrackerSessionTinyBadge(
                          label: '${session.heartRateSamplesCount} HR',
                          color: const Color(0xFFDC2626),
                        ),
                    ]),
                    const Spacer(),
                    Row(children: [
                      if (hasPolar) ...[
                        const Icon(Icons.favorite_rounded, color: Color(0xFFDC2626), size: 15),
                        const SizedBox(width: 4),
                        const Text('Polar', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11.2, fontWeight: FontWeight.w900)),
                      ],
                      if (hasPolar && hasTracker) const SizedBox(width: 10),
                      if (hasTracker) ...[
                        const Icon(Icons.sensors_rounded, color: _AA.green, size: 15),
                        const SizedBox(width: 4),
                        const Text('Трекер', style: TextStyle(color: _AA.green, fontSize: 11.2, fontWeight: FontWeight.w900)),
                      ],
                      const Spacer(),
                      Text(
                        checked ? 'ВЫБРАНО' : 'Выбрать',
                        style: TextStyle(
                          color: checked ? _AA.green : _AA.muted,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ]),
                  ]),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 29,
                      height: 29,
                      decoration: BoxDecoration(
                        color: checked ? _AA.green : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: checked ? _AA.green : _AA.line),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          checked ? Icons.check_rounded : Icons.add_rounded,
                          key: ValueKey(checked),
                          color: checked ? Colors.white : _AA.muted,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackerNoDesktopScrollbarBehavior extends MaterialScrollBehavior {
  const _TrackerNoDesktopScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

class _TrackerInlineCalendarPane extends StatefulWidget {
  const _TrackerInlineCalendarPane({
    required this.initialDate,
    required this.sessions,
    required this.players,
    required this.loading,
    required this.onSelected,
    required this.onOpenSession,
    required this.onClose,
  });

  final DateTime initialDate;
  final List<TrackerSessionModel> sessions;
  final List<TrackerPlayerOption> players;
  final bool loading;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<TrackerSessionModel> onOpenSession;
  final VoidCallback onClose;

  @override
  State<_TrackerInlineCalendarPane> createState() => _TrackerInlineCalendarPaneState();
}

class _TrackerInlineCalendarPaneState extends State<_TrackerInlineCalendarPane> {
  late DateTime _cursor;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _cursor = DateTime(_selected.year, _selected.month, 1);
  }

  @override
  void didUpdateWidget(covariant _TrackerInlineCalendarPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_trackerSameDay(oldWidget.initialDate, widget.initialDate)) {
      _selected = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
      _cursor = DateTime(_selected.year, _selected.month, 1);
    }
  }

  Map<String, _TrackerCalendarDayMark> get _marks {
    final map = <String, _TrackerCalendarDayMark>{};
    for (final session in widget.sessions) {
      final dt = _trackerSessionDate(session);
      if (dt == null) continue;
      final key = _trackerCalendarKey(dt);
      final mark = map[key] ?? _TrackerCalendarDayMark(day: DateTime(dt.year, dt.month, dt.day));
      mark.add(session);
      map[key] = mark;
    }
    return map;
  }

  List<TrackerSessionModel> _sessionsFor(DateTime day) {
    final key = _trackerCalendarKey(day);
    final rows = widget.sessions.where((s) {
      final dt = _trackerSessionDate(s);
      return dt != null && _trackerCalendarKey(dt) == key;
    }).toList(growable: false);
    final sorted = [...rows]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  String _playerName(TrackerSessionModel session) {
    TrackerPlayerOption? player;
    final id = session.playerId;
    if (id != null) {
      for (final p in widget.players) {
        if (p.id == id) {
          player = p;
          break;
        }
      }
    }
    final raw = (session.playerName ?? '').trim();
    final fromRoster = player?.name.trim() ?? '';
    final name = raw.isNotEmpty && !_looksGenericPlayerName(raw) ? raw : fromRoster;
    return name.isEmpty ? 'Игрок ${session.playerId ?? ''}'.trim() : name;
  }

  void _setLocal(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _selectDate(DateTime d) {
    final normalized = DateTime(d.year, d.month, d.day);
    _setLocal(() {
      _selected = normalized;
      if (normalized.month != _cursor.month || normalized.year != _cursor.year) {
        _cursor = DateTime(normalized.year, normalized.month, 1);
      }
    });
    widget.onSelected(normalized);
  }

  void _shiftMonth(int delta) {
    _setLocal(() => _cursor = DateTime(_cursor.year, _cursor.month + delta, 1));
  }

  void _today() {
    final now = DateTime.now();
    _selectDate(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 720;
    final selectedRows = _sessionsFor(_selected);
    final selectedMark = _marks[_trackerCalendarKey(_selected)];

    Widget calendarWindow({required bool phone}) {
      return Container(
        decoration: BoxDecoration(
          color: _AA.card,
          borderRadius: BorderRadius.circular(phone ? 20 : 22),
          boxShadow: const [BoxShadow(color: Color(0x07111827), blurRadius: 14, offset: Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: phone ? 58 : 60,
            padding: EdgeInsets.fromLTRB(phone ? 12 : 14, 8, phone ? 10 : 12, 8),
            decoration: const BoxDecoration(color: _AA.card),
            child: Row(children: [
              Container(
                width: phone ? 38 : 40,
                height: phone ? 38 : 40,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.calendar_month_rounded, color: _AA.green, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_trackerMonthTitle(_cursor), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 15.0, fontWeight: FontWeight.w600, height: 1.05, letterSpacing: -.12)),
                const SizedBox(height: 4),
                Text('${_trackerCalendarDateLabel(_selected)} · ${selectedRows.length} ${_trackerSessionWord(selectedRows.length)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11.0, fontWeight: FontWeight.w500, height: 1.0)),
              ])),
              if (widget.loading) ...[
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _AA.green)),
                const SizedBox(width: 8),
              ],
              _ProfileLikeIconButton(icon: Icons.chevron_left_rounded, onTap: () => _shiftMonth(-1)),
              const SizedBox(width: 6),
              _ProfileLikeIconButton(icon: Icons.chevron_right_rounded, onTap: () => _shiftMonth(1)),
              const SizedBox(width: 6),
              _ProfileLikeIconButton(icon: Icons.today_rounded, onTap: _today),
              const SizedBox(width: 6),
              _ProfileLikeIconButton(icon: Icons.close_rounded, onTap: widget.onClose),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(phone ? 12 : 14, phone ? 12 : 14, phone ? 12 : 14, phone ? 14 : 16),
              child: _TrackerInlineMonthCalendar(
                cursor: _cursor,
                selected: _selected,
                marks: _marks,
                roomy: true,
                onSelect: _selectDate,
              ),
            ),
          ),
        ]),
      );
    }

    Widget selectedWindow({required bool phone}) {
      return _TrackerSelectedDayPanel(
        selected: _selected,
        mark: selectedMark,
        sessions: selectedRows,
        playerName: _playerName,
        onSelectSession: widget.onOpenSession,
        compact: phone,
      );
    }

    return LayoutBuilder(builder: (context, c) {
      if (mobile) {
        final h = c.maxHeight.isFinite ? c.maxHeight : 638.0;
        final first = DateTime(_cursor.year, _cursor.month, 1);
        final daysInMonth = DateTime(_cursor.year, _cursor.month + 1, 0).day;
        final rowsCount = ((first.weekday - 1 + daysInMonth + 6) ~/ 7);
        final roomyPhone = c.maxWidth >= 560;
        final calendarHeight = roomyPhone
            ? (rowsCount >= 6 ? 520.0 : 470.0)
            : (rowsCount >= 6 ? 452.0 : 416.0);
        final sessionsHeight = selectedRows.isEmpty
            ? 238.0
            : math.max(284.0, math.min(430.0, 178.0 + selectedRows.length * 116.0));
        final bottomSafe = MediaQuery.paddingOf(context).bottom;

        return ScrollConfiguration(
          behavior: const _TrackerNoDesktopScrollbarBehavior(),
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(0, 0, 0, bottomSafe + 112),
            children: [
              SizedBox(height: calendarHeight, child: calendarWindow(phone: true)),
              const SizedBox(height: 10),
              SizedBox(height: sessionsHeight, child: selectedWindow(phone: true)),
            ],
          ),
        );
      }

      final h = c.maxHeight.isFinite ? c.maxHeight : 520.0;
      final calendarWidth = math.min(480.0, math.max(360.0, c.maxWidth * .42));
      return SizedBox(
        height: h,
        child: Container(
          decoration: BoxDecoration(
            color: _AA.bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: calendarWidth, child: calendarWindow(phone: false)),
            const SizedBox(width: 10),
            Expanded(child: selectedWindow(phone: false)),
          ]),
        ),
      );
    });
  }
}

class _ProfileLikeIconButton extends StatelessWidget {
  const _ProfileLikeIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _AA.text, size: 18),
      ),
    );
  }
}

class _TrackerCalendarPickResult {
  const _TrackerCalendarPickResult({required this.date, this.session});
  final DateTime date;
  final TrackerSessionModel? session;
}

class _TrackerSessionCalendarPicker extends StatefulWidget {
  const _TrackerSessionCalendarPicker({
    required this.initialDate,
    required this.sessions,
    required this.players,
    required this.sessionKindLabel,
  });

  final DateTime initialDate;
  final List<TrackerSessionModel> sessions;
  final List<TrackerPlayerOption> players;
  final String sessionKindLabel;

  @override
  State<_TrackerSessionCalendarPicker> createState() => _TrackerSessionCalendarPickerState();
}

class _TrackerSessionCalendarPickerState extends State<_TrackerSessionCalendarPicker> {
  late DateTime _cursor;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _cursor = DateTime(_selected.year, _selected.month, 1);
  }

  void _setLocal(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Map<String, _TrackerCalendarDayMark> get _marks {
    final map = <String, _TrackerCalendarDayMark>{};
    for (final session in widget.sessions) {
      final dt = _trackerSessionDate(session);
      if (dt == null) continue;
      final key = _trackerCalendarKey(dt);
      final mark = map[key] ?? _TrackerCalendarDayMark(day: DateTime(dt.year, dt.month, dt.day));
      mark.add(session);
      map[key] = mark;
    }
    return map;
  }

  List<TrackerSessionModel> _sessionsFor(DateTime day) {
    final key = _trackerCalendarKey(day);
    final rows = widget.sessions.where((s) {
      final dt = _trackerSessionDate(s);
      return dt != null && _trackerCalendarKey(dt) == key;
    }).toList(growable: false);
    final sorted = [...rows]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  void _shiftMonth(int delta) => _setLocal(() => _cursor = DateTime(_cursor.year, _cursor.month + delta, 1));

  void _today() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _setLocal(() {
      _selected = today;
      _cursor = DateTime(today.year, today.month, 1);
    });
  }

  void _popAfterMouseSettled<T>(BuildContext context, [T? result]) {
    Timer(const Duration(milliseconds: 140), () async {
      if (!context.mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      await Future<void>.delayed(Duration.zero);
      if (!context.mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      Navigator.pop<T>(context, result);
    });
  }

  String _playerName(TrackerSessionModel session) {
    TrackerPlayerOption? player;
    final id = session.playerId;
    if (id != null) {
      for (final p in widget.players) {
        if (p.id == id) {
          player = p;
          break;
        }
      }
    }
    final raw = (session.playerName ?? '').trim();
    final fromRoster = player?.name.trim() ?? '';
    final name = raw.isNotEmpty && !_looksGenericPlayerName(raw) ? raw : fromRoster;
    return name.isEmpty ? 'Игрок ${session.playerId ?? ''}'.trim() : name;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 720;
    final selectedRows = _sessionsFor(_selected);
    final selectedMark = _marks[_trackerCalendarKey(_selected)];
    final sheetHeight = math.min(size.height * .94, mobile ? 760.0 : 850.0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: mobile ? 0 : 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(mobile ? 28 : 34),
          child: Material(
            color: _AA.card,
            child: SizedBox(
              height: sheetHeight,
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(color: _AA.card, border: Border(bottom: BorderSide(color: _AA.line))),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.calendar_month_rounded, color: _AA.green, size: 20),
                ),
                const SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Календарь сессий · ${widget.sessionKindLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 17.2, fontWeight: FontWeight.w900, letterSpacing: -.25)),
                  Text('${_trackerCalendarDateLabel(_selected)} · ${selectedRows.length} ${_trackerSessionWord(selectedRows.length)} · нажмите сессию для отчёта', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 12, fontWeight: FontWeight.w800)),
                ])),
                _IconOnlyButton(icon: Icons.today_rounded, onTap: _today),
                const SizedBox(width: 5),
                _IconOnlyButton(icon: Icons.close_rounded, onTap: () => _popAfterMouseSettled<void>(context)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
              child: Row(children: [
                _IconOnlyButton(icon: Icons.chevron_left_rounded, onTap: () => _shiftMonth(-1)),
                Expanded(
                  child: Center(
                    child: Text(_trackerMonthTitle(_cursor), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 11.8, fontWeight: FontWeight.w700)),
                  ),
                ),
                _IconOnlyButton(icon: Icons.chevron_right_rounded, onTap: () => _shiftMonth(1)),
              ]),
            ),
            Expanded(
              child: mobile
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      children: [
                        _TrackerInlineMonthCalendar(
                          cursor: _cursor,
                          selected: _selected,
                          marks: _marks,
                          roomy: true,
                          onSelect: (d) {
                            _setLocal(() {
                              _selected = d;
                              if (d.month != _cursor.month || d.year != _cursor.year) {
                                _cursor = DateTime(d.year, d.month, 1);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 330,
                          child: _TrackerSelectedDayPanel(
                            selected: _selected,
                            mark: selectedMark,
                            sessions: selectedRows,
                            playerName: _playerName,
                            onSelectSession: (session) => _popAfterMouseSettled<_TrackerCalendarPickResult>(context, _TrackerCalendarPickResult(date: _selected, session: session)),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: Row(children: [
                        Expanded(
                          flex: 7,
                          child: _TrackerInlineMonthCalendar(
                            cursor: _cursor,
                            selected: _selected,
                            marks: _marks,
                            roomy: true,
                            onSelect: (d) {
                            _setLocal(() {
                              _selected = d;
                              if (d.month != _cursor.month || d.year != _cursor.year) {
                                _cursor = DateTime(d.year, d.month, 1);
                              }
                            });
                          },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: _TrackerSelectedDayPanel(
                            selected: _selected,
                            mark: selectedMark,
                            sessions: selectedRows,
                            playerName: _playerName,
                            onSelectSession: (session) => _popAfterMouseSettled<_TrackerCalendarPickResult>(context, _TrackerCalendarPickResult(date: _selected, session: session)),
                          ),
                        ),
                      ]),
                    ),
            ),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: const BoxDecoration(color: _AA.card, border: Border(top: BorderSide(color: _AA.line))),
              child: Row(children: [
                Expanded(child: Text(selectedMark == null ? 'На выбранный день нет сохранённых сессий' : '${selectedMark.sessionsCount} ${_trackerSessionWord(selectedMark.sessionsCount)} · ${selectedMark.playersCount} игроков · ${_meters(selectedMark.distanceM)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w700))),
                _SmallButton(icon: Icons.check_rounded, label: 'Выбрать день', primary: true, onTap: () => _popAfterMouseSettled<_TrackerCalendarPickResult>(context, _TrackerCalendarPickResult(date: _selected))),
              ]),
            ),
          ],
        ),
      ),
            ),
          ),
        ),
    );
  }
}

class _TrackerCalendarDayMark {
  _TrackerCalendarDayMark({required this.day});
  final DateTime day;
  int sessionsCount = 0;
  final Set<int> playerIds = <int>{};
  double distanceM = 0;
  double loadScore = 0;
  double maxSpeedKmh = 0;
  int sprintCount = 0;
  int declaredPlayersCount = 0;

  int get playersCount => math.max(playerIds.length, declaredPlayersCount);

  void add(TrackerSessionModel session) {
    sessionsCount++;
    if (session.participantIds.isNotEmpty) {
      playerIds.addAll(session.participantIds.where((id) => id > 0));
    } else if ((session.playerId ?? 0) > 0) {
      playerIds.add(session.playerId!);
    }
    if (session.participantsCount > declaredPlayersCount) declaredPlayersCount = session.participantsCount;
    distanceM += session.distanceM;
    loadScore += session.loadScore;
    sprintCount += session.sprintCount;
    if (session.maxSpeedKmh > maxSpeedKmh) maxSpeedKmh = session.maxSpeedKmh;
  }
}

class _TrackerInlineMonthCalendar extends StatelessWidget {
  const _TrackerInlineMonthCalendar({
    required this.cursor,
    required this.selected,
    required this.marks,
    required this.onSelect,
    this.roomy = false,
  });

  final DateTime cursor;
  final DateTime selected;
  final Map<String, _TrackerCalendarDayMark> marks;
  final ValueChanged<DateTime> onSelect;
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final first = DateTime(cursor.year, cursor.month, 1);
    final daysInMonth = DateTime(cursor.year, cursor.month + 1, 0).day;
    final prevMonthDays = DateTime(cursor.year, cursor.month, 0).day;
    final leading = first.weekday - 1;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final rowsCount = total ~/ 7;

    Widget grid(double maxHeight, double maxWidth) {
      final gap = roomy ? 7.0 : 6.0;
      final cellWidth = (maxWidth - gap * 6) / 7;
      final availableHeight = maxHeight.isFinite && maxHeight > 0 ? (maxHeight - gap * (rowsCount - 1)) / rowsCount : cellWidth / 1.18;
      final targetHeight = cellWidth / 1.18;
      final cellHeight = roomy
          ? math.max(42.0, math.min(58.0, math.min(targetHeight, availableHeight)))
          : math.max(34.0, math.min(44.0, math.min(targetHeight, availableHeight)));
      final children = <Widget>[];
      for (var row = 0; row < rowsCount; row++) {
        final rowCells = <Widget>[];
        for (var col = 0; col < 7; col++) {
          final index = row * 7 + col;
          final dayNumber = index - leading + 1;
          late DateTime day;
          var inMonth = true;
          if (dayNumber < 1) {
            day = DateTime(cursor.year, cursor.month - 1, prevMonthDays + dayNumber);
            inMonth = false;
          } else if (dayNumber > daysInMonth) {
            day = DateTime(cursor.year, cursor.month + 1, dayNumber - daysInMonth);
            inMonth = false;
          } else {
            day = DateTime(cursor.year, cursor.month, dayNumber);
          }
          final mark = marks[_trackerCalendarKey(day)];
          final has = mark != null && mark.sessionsCount > 0;
          rowCells.add(Expanded(
            child: SizedBox(
              height: cellHeight,
              child: _TrackerCalendarDayCell(
                day: day,
                inMonth: inMonth,
                selected: _trackerSameDay(day, selected),
                today: _trackerSameDay(day, DateTime.now()),
                mark: mark,
                onTap: () => onSelect(DateTime(day.year, day.month, day.day)),
                dense: rowsCount > 5,
                has: has,
                roomy: roomy,
              ),
            ),
          ));
          if (col != 6) rowCells.add(SizedBox(width: gap));
        }
        children.add(Row(children: rowCells));
        if (row != rowsCount - 1) children.add(SizedBox(height: gap));
      }
      return Column(mainAxisSize: MainAxisSize.min, children: children);
    }

    return Container(
      decoration: BoxDecoration(
        color: _AA.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent, width: 0),
      ),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: LayoutBuilder(builder: (context, outer) {
        final header = Row(
          children: weekdays
              .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w600, height: 1.0)))))
              .toList(),
        );
        final gridWidget = LayoutBuilder(builder: (context, gridBox) => grid(gridBox.maxHeight, gridBox.maxWidth));
        return Column(children: [
          header,
          const SizedBox(height: 8),
          if (outer.maxHeight.isFinite)
            Expanded(child: gridWidget)
          else
            gridWidget,
        ]);
      }),
    );
  }
}

class _TrackerCalendarDayCell extends StatelessWidget {
  const _TrackerCalendarDayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.mark,
    required this.onTap,
    required this.dense,
    required this.has,
    this.roomy = false,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final _TrackerCalendarDayMark? mark;
  final VoidCallback onTap;
  final bool dense;
  final bool has;
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    final safeMark = mark;
    final safeHas = has && safeMark != null && safeMark.sessionsCount > 0;
    final bg = selected
        ? _AA.greenSoft
        : safeHas
            ? Colors.white
            : (inMonth ? _AA.bg : Colors.white);
    final textColor = selected
        ? const Color(0xFF067A46)
        : inMonth
            ? (today ? _AA.green : _AA.text)
            : _AA.muted.withOpacity(.72);
    final radius = roomy ? 12.0 : 11.0;
    final dayFont = roomy ? 12.0 : 11.0;
    final count = safeMark?.sessionsCount ?? 0;
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: selected ? Border.all(color: _AA.greenLine, width: 1) : null,
          boxShadow: selected ? const [BoxShadow(color: Color(0x07111827), blurRadius: 12, offset: Offset(0, 5))] : null,
        ),
        child: Stack(children: [
          Center(
            child: Text(
              '${day.day}',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(color: textColor, fontSize: dayFont, fontWeight: FontWeight.w600, height: 1.0),
            ),
          ),
          if (safeHas)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                constraints: const BoxConstraints(minWidth: 14),
                height: 14,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: _AA.green, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white, width: 1.1)),
                child: Center(child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9.6, fontWeight: FontWeight.w700, height: 1.0))),
              ),
            ),
          if (selected)
            Positioned(
              left: 0,
              right: 0,
              bottom: safeHas ? 4 : 5,
              child: Center(
                child: SizedBox(
                  width: safeHas ? 4 : 6,
                  height: safeHas ? 4 : 6,
                  child: const DecoratedBox(decoration: BoxDecoration(color: _AA.green, shape: BoxShape.circle)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _TrackerSelectedDayPanel extends StatefulWidget {
  const _TrackerSelectedDayPanel({
    required this.selected,
    required this.mark,
    required this.sessions,
    required this.playerName,
    this.onSelectSession,
    this.compact = false,
  });

  final DateTime selected;
  final _TrackerCalendarDayMark? mark;
  final List<TrackerSessionModel> sessions;
  final String Function(TrackerSessionModel session) playerName;
  final ValueChanged<TrackerSessionModel>? onSelectSession;
  final bool compact;

  @override
  State<_TrackerSelectedDayPanel> createState() => _TrackerSelectedDayPanelState();
}

class _TrackerSelectedDayPanelState extends State<_TrackerSelectedDayPanel> {
  int? _selectedSessionId;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final mark = widget.mark;
    final sessions = widget.sessions;
    final playerName = widget.playerName;
    final onSelectSession = widget.onSelectSession;
    final compact = widget.compact;
    final safeMark = mark;
    return Container(
      decoration: BoxDecoration(
        color: _AA.card,
        borderRadius: BorderRadius.circular(compact ? 20 : 22),
        boxShadow: const [BoxShadow(color: Color(0x07111827), blurRadius: 14, offset: Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: compact ? 52 : 54,
          padding: EdgeInsets.fromLTRB(compact ? 10 : 12, 7, compact ? 9 : 10, 7),
          decoration: const BoxDecoration(color: _AA.card, border: Border(bottom: BorderSide(color: _AA.line))),
          child: Row(children: [
            Container(
              width: compact ? 32 : 34,
              height: compact ? 32 : 34,
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.view_list_rounded, color: Color(0xFF2563EB), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Сессии дня', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 14.2, fontWeight: FontWeight.w600, height: 1.05, letterSpacing: -.10)),
              const SizedBox(height: 4),
              Text('${_trackerCalendarDateLabel(selected)} · ${sessions.length} ${_trackerSessionWord(sessions.length)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w500, height: 1.0)),
            ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Row(children: [
            Expanded(child: _TrackerCalendarKpi(icon: Icons.route_rounded, label: 'Дист.', value: _meters(safeMark?.distanceM ?? 0))),
            const SizedBox(width: 6),
            Expanded(child: _TrackerCalendarKpi(icon: Icons.group_rounded, label: 'Игроков', value: '${safeMark?.playersCount ?? 0}')),
            const SizedBox(width: 6),
            Expanded(child: _TrackerCalendarKpi(icon: Icons.local_fire_department_rounded, label: 'Нагрузка', value: (safeMark?.loadScore ?? 0).toStringAsFixed(0))),
          ]),
        ),
        Expanded(
          child: sessions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text('На выбранный день сессий нет', textAlign: TextAlign.center, style: TextStyle(color: _AA.muted, fontSize: 12.2, fontWeight: FontWeight.w600)),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, grid) {
                    final columns = grid.maxWidth >= 500 ? 2 : 1;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      itemCount: sessions.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: columns == 2 ? 1.55 : 2.45,
                      ),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final selectedCard = _selectedSessionId == session.id;
                        return _TrackerCalendarSessionCard(
                          session: session,
                          playerName: playerName(session),
                          selected: selectedCard,
                          onTap: onSelectSession == null
                              ? null
                              : () async {
                                  setState(() => _selectedSessionId = session.id);
                                  await Future<void>.delayed(const Duration(milliseconds: 180));
                                  if (mounted) onSelectSession.call(session);
                                },
                        );
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _TrackerCalendarSessionCard extends StatelessWidget {
  const _TrackerCalendarSessionCard({
    required this.session,
    required this.playerName,
    this.onTap,
    this.selected = false,
  });

  final TrackerSessionModel session;
  final String playerName;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final kindColor = session.personalSession ? _AA.green : const Color(0xFF2563EB);
    final kindLabel = session.personalSession ? 'Личная' : 'Командная';
    final sourceLabel = _trackerSessionSourceLabel(session);
    final participantsCount = session.participantsCount > 0
        ? session.participantsCount
        : session.participantIds.isNotEmpty
            ? session.participantIds.length
            : (session.playerId ?? 0) > 0
                ? 1
                : 0;
    final sessionTitle = session.personalSession
        ? playerName
        : (session.title.trim().isNotEmpty && session.title.trim().toLowerCase() != 'сессия'
            ? session.title.trim()
            : 'Командная тренировка');
    final namesPreview = session.participantNames.where((name) => name.trim().isNotEmpty).take(3).toList(growable: false);
    final teamSubtitle = namesPreview.isEmpty
        ? (participantsCount > 0 ? '$participantsCount ${_trackerPlayerWord(participantsCount)}' : 'Состав сессии')
        : '${namesPreview.join(', ')}${participantsCount > namesPreview.length ? ' +${participantsCount - namesPreview.length}' : ''}';
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? _AA.greenSoft : _AA.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? _AA.green : _AA.greenLine.withOpacity(.55),
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? const [BoxShadow(color: Color(0x2200A651), blurRadius: 16, offset: Offset(0, 7))]
            : const [BoxShadow(color: Color(0x07101828), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, decoration: BoxDecoration(color: kindColor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white.withOpacity(.78), borderRadius: BorderRadius.circular(12)), child: Icon(session.personalSession ? Icons.person_pin_circle_rounded : Icons.groups_rounded, color: kindColor, size: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sessionTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 11.8, fontWeight: FontWeight.w600, letterSpacing: -.04, height: 1.0)),
                    if (!session.personalSession) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.groups_rounded, size: 11.5, color: kindColor),
                        const SizedBox(width: 4),
                        Expanded(child: Text(teamSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.8, fontWeight: FontWeight.w500, height: 1.0))),
                      ]),
                    ],
                    const SizedBox(height: 4),
                    Wrap(spacing: 5, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      _TrackerSessionTinyBadge(label: session.personalSession ? kindLabel : (participantsCount > 0 ? '$participantsCount ${_trackerPlayerWord(participantsCount)}' : kindLabel), color: kindColor),
                      _TrackerSessionTinyBadge(label: sourceLabel, color: _AA.muted),
                      if (_trackerSessionHasPolar(session))
                        _TrackerSessionTinyBadge(
                          label: 'Polar · ${_trackerSensorDuration(session.polarDurationSec, session.durationSec)}',
                          color: const Color(0xFFDC2626),
                        ),
                      if (_trackerSessionHasGps(session))
                        _TrackerSessionTinyBadge(
                          label: 'GPS · ${_trackerSensorDuration(session.gpsDurationSec, session.durationSec)}',
                          color: _AA.green,
                        ),
                      Text(_trackerSessionTime(session), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w500)),
                    ]),
                  ])),
                  if (onTap != null)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 170),
                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                      child: selected
                          ? const Icon(Icons.check_circle_rounded, key: ValueKey('selected'), color: _AA.green, size: 22)
                          : const Icon(Icons.chevron_right_rounded, key: ValueKey('open'), color: _AA.green, size: 20),
                    ),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 5, runSpacing: 5, children: [
                  _TrackerCalendarMetricPill(icon: Icons.route_rounded, label: 'Дист.', value: _meters(session.distanceM)),
                  _TrackerCalendarMetricPill(icon: Icons.speed_rounded, label: 'Макс.', value: '${session.maxSpeedKmh.toStringAsFixed(1)} км/ч'),
                  _TrackerCalendarMetricPill(icon: Icons.directions_run_rounded, label: 'SPR', value: '${session.sprintCount}'),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
    if (onTap == null) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: 1 + value * .018,
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: _AA.green.withOpacity(.08),
          highlightColor: _AA.green.withOpacity(.07),
          child: card,
        ),
      ),
    );
  }
}


class _TrackerCalendarMetricPill extends StatelessWidget {
  const _TrackerCalendarMetricPill({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final hasLabel = label.trim().isNotEmpty;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.74),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _AA.green, size: 12.5),
        const SizedBox(width: 4),
        if (hasLabel) ...[
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600, height: 1.0)),
          const SizedBox(width: 3),
        ],
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700, height: 1.0)),
      ]),
    );
  }
}

class _TrackerSessionTinyBadge extends StatelessWidget {
  const _TrackerSessionTinyBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.08))),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 9.6, fontWeight: FontWeight.w700)),
    );
  }
}

bool _trackerSessionHasPolar(TrackerSessionModel session) {
  final raw = '${session.source} ${session.deviceName} ${session.title}'.toLowerCase();
  return session.heartRateSamplesCount > 0 ||
      session.polarDurationSec > 0 ||
      raw.contains('polar') ||
      raw.contains('h10') ||
      raw.contains('heart') ||
      raw.contains('пульс') ||
      RegExp(r'(^|[^a-z])hr([^a-z]|$)').hasMatch(raw);
}

bool _trackerSessionHasGps(TrackerSessionModel session) {
  final raw = '${session.source} ${session.deviceName} ${session.title}'.toLowerCase();
  return session.gpsDurationSec > 0 ||
      session.distanceM > 0 ||
      raw.contains('gps') ||
      raw.contains('трек') ||
      raw.contains('tracker') ||
      raw.contains(r'$atp');
}

String _trackerSensorDuration(int seconds, int fallback) {
  final value = seconds > 0 ? seconds : fallback;
  if (value <= 0) return 'время не записано';
  final h = value ~/ 3600;
  final m = (value % 3600) ~/ 60;
  final sec = value % 60;
  if (h > 0) return '${h} ч ${m.toString().padLeft(2, '0')} мин';
  if (m > 0) return '${m} мин ${sec.toString().padLeft(2, '0')} с';
  return '$sec с';
}

String _trackerSessionSourceLabel(TrackerSessionModel session) {
  final hasPolar = _trackerSessionHasPolar(session);
  final hasGps = _trackerSessionHasGps(session);
  if (hasPolar && hasGps) return 'Polar + GPS';
  if (hasPolar) return 'Polar';
  if (hasGps) return 'GPS';
  return session.personalSession ? 'личная' : 'командная';
}

class _TrackerCalendarKpi extends StatelessWidget {
  const _TrackerCalendarKpi({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: _AA.green, size: 12),
        const SizedBox(width: 4),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w700)),
          const SizedBox(height: 1),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

DateTime? _trackerSessionDate(TrackerSessionModel session) {
  final raw = session.createdAt.trim();
  if (raw.isEmpty) return null;
  final normalized = raw.replaceFirst(' ', 'T');
  final hasZone = normalized.endsWith('Z') || RegExp(r'[+\-]\d{2}:?\d{2}$').hasMatch(normalized);
  final parsed = _trackerMoscowDateTime(raw);
  return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute);
}

String _trackerCalendarKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool _trackerSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _trackerMonthTitle(DateTime d) {
  const names = ['январь', 'февраль', 'март', 'апрель', 'май', 'июнь', 'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'];
  return '${names[d.month - 1]} ${d.year}';
}

String _trackerCalendarDateLabel(DateTime d) {
  const names = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
  return '${d.day} ${names[d.month - 1]} ${d.year}';
}

String _trackerCalendarLongDateLabel(DateTime d) {
  const weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
  const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
  return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

String _trackerSessionWord(int count) {
  final n = count.abs() % 100;
  final n1 = count.abs() % 10;
  if (n >= 11 && n <= 14) return 'сессий';
  if (n1 == 1) return 'сессия';
  if (n1 >= 2 && n1 <= 4) return 'сессии';
  return 'сессий';
}

String _trackerPlayerWord(int count) {
  final mod100 = count % 100;
  final mod10 = count % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'игроков';
  if (mod10 == 1) return 'игрок';
  if (mod10 >= 2 && mod10 <= 4) return 'игрока';
  return 'игроков';
}


String _trackerSessionTime(TrackerSessionModel session) {
  final dt = _trackerSessionDate(session);
  if (dt == null) return session.createdAt.isEmpty ? 'без времени' : session.createdAt;
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}


class _SessionKindOptionTile extends StatelessWidget {
  const _SessionKindOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? _AA.greenSoft : Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: active ? _AA.greenLine : _AA.line),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? _AA.greenLine : _AA.line)),
            child: Icon(icon, color: active ? _AA.green : _AA.muted, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _AA.green : _AA.text, fontWeight: FontWeight.w900, fontSize: 12.5)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontWeight: FontWeight.w700, fontSize: 11.2, height: 1.15)),
          ])),
          if (active) const Icon(Icons.check_circle_rounded, color: _AA.green, size: 18),
        ]),
      ),
    );
  }
}

class _DateFilterBar extends StatelessWidget {
  const _DateFilterBar({
    required this.selectedDate,
    required this.onlySelectedDate,
    required this.startTime,
    required this.endTime,
    required this.selectedPlayer,
    required this.playerFilterLabel,
    required this.selectedField,
    required this.selectedSession,
    required this.sessionFilterLabel,
    required this.liveRunning,
    required this.localPointsCount,
    required this.sessionKindLabel,
    required this.onOpenSessionKindPicker,
    required this.onOpenPlayerPicker,
    required this.onOpenSessionPicker,
    required this.onOpenCalibration,
    this.onClearField,
    required this.onRefresh,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onPick,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClearTime,
    required this.onToggleMode,
  });

  final DateTime selectedDate;
  final bool onlySelectedDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final TrackerPlayerOption? selectedPlayer;
  final String playerFilterLabel;
  final TrackerFieldModel? selectedField;
  final TrackerSessionModel? selectedSession;
  final String sessionFilterLabel;
  final bool liveRunning;
  final int localPointsCount;
  final String sessionKindLabel;
  final VoidCallback onOpenSessionKindPicker;
  final VoidCallback onOpenPlayerPicker;
  final VoidCallback onOpenSessionPicker;
  final VoidCallback onOpenCalibration;
  final VoidCallback? onClearField;
  final VoidCallback onRefresh;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onPick;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClearTime;
  final ValueChanged<bool> onToggleMode;

  String get _date => '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}';
  String _time(TimeOfDay? t, String fallback) => t == null ? fallback : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  String _periodLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'все за период';
    if (value == _date) return 'все за период';
    return value;
  }

  String _mobilePlayerValue(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty || value == 'команда' || value == 'все игроки') return 'Все игроки';
    return raw.trim();
  }

  String _mobilePeriodValue(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty || value == 'все за период' || value == 'все даты') return 'Весь период';
    return raw.trim();
  }

  String _mobileFieldValue(String raw) {
    final value = raw.trim();
    if (value.startsWith('Поле ')) return value.replaceFirst('Поле ', '№');
    return value.isEmpty ? '—' : value;
  }

  String get _filtersSummary {
    final player = _mobilePlayerValue(playerFilterLabel);
    final period = onlySelectedDate ? _date : _mobilePeriodValue(_periodLabel(sessionFilterLabel));
    final field = _mobileFieldValue(selectedField?.title ?? 'Поле 7');
    final time = (startTime != null || endTime != null)
        ? ' · ${_time(startTime, 'с начала')}–${_time(endTime, 'до конца')}'
        : '';
    return '$player · $sessionKindLabel · $period · $field$time';
  }

  void _runInsideFilterHub(BuildContext hubContext, VoidCallback action, StateSetter modalSetState) {
    // Дочерние модалки выбора типа/игрока/даты закрываются отдельно,
    // а это окно остаётся открытым. Поэтому обновляем сводку несколько секунд,
    // чтобы тренер сразу видел новый выбор без ручного закрытия окна.
    action();
    var ticks = 0;
    Timer.periodic(const Duration(milliseconds: 180), (timer) {
      ticks += 1;
      if (!hubContext.mounted || ticks > 34) {
        timer.cancel();
        return;
      }
      modalSetState(() {});
    });
  }

  void _openFilterHub(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.24),
      builder: (sheetContext) {
        final size = MediaQuery.sizeOf(sheetContext);
        final maxWidth = math.min(size.width - 18, 980.0);
        final bottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + bottom),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: StatefulBuilder(
                  builder: (context, modalSetState) {
                    Widget actionCard({required IconData icon, required String title, required String value, required VoidCallback onTap}) {
                      return _FilterHubAction(
                        icon: icon,
                        title: title,
                        value: value,
                        onTap: () => _runInsideFilterHub(context, onTap, modalSetState),
                      );
                    }

                    Widget smallButton({required IconData icon, required String label, required VoidCallback onTap, bool primary = false}) {
                      return _FilterHubSmallButton(
                        icon: icon,
                        label: label,
                        primary: primary,
                        onTap: () => _runInsideFilterHub(context, onTap, modalSetState),
                      );
                    }

                    return Material(
                      color: _AA.card,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                                child: const Icon(Icons.tune_rounded, color: _AA.green, size: 21),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Выбор аналитики', style: TextStyle(color: _AA.text, fontWeight: FontWeight.w900, fontSize: 17, height: 1.05)),
                                  SizedBox(height: 3),
                                  Text('Выберите всё, затем нажмите «Применить»', style: TextStyle(color: _AA.muted, fontWeight: FontWeight.w700, fontSize: 11.2)),
                                ]),
                              ),
                              _NoHoverTap(
                                onTap: () => Navigator.of(sheetContext).pop(),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                                  child: const Icon(Icons.close_rounded, color: _AA.text, size: 22),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)),
                              child: Text(_filtersSummary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontWeight: FontWeight.w800, fontSize: 12.6, height: 1.18)),
                            ),
                            const SizedBox(height: 8),
                            LayoutBuilder(builder: (context, constraints) {
                              final compact = constraints.maxWidth < 560;
                              final itemWidth = compact ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;
                              final items = <Widget>[
                                actionCard(icon: Icons.layers_rounded, title: 'Тип тренировок', value: sessionKindLabel, onTap: onOpenSessionKindPicker),
                                actionCard(icon: Icons.person_rounded, title: 'Игрок', value: _mobilePlayerValue(playerFilterLabel), onTap: onOpenPlayerPicker),
                                actionCard(icon: Icons.event_note_rounded, title: 'Сессии', value: _mobilePeriodValue(sessionFilterLabel), onTap: onOpenSessionPicker),
                                actionCard(icon: Icons.calendar_month_rounded, title: 'Дата', value: onlySelectedDate ? _date : 'все даты', onTap: onPick),
                                actionCard(icon: Icons.map_rounded, title: 'Поле', value: selectedField?.title ?? 'не выбрано', onTap: onOpenCalibration),
                                actionCard(icon: Icons.access_time_rounded, title: 'Время', value: '${_time(startTime, 'с начала')} – ${_time(endTime, 'до конца')}', onTap: onPickStart),
                              ];
                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [for (final item in items) SizedBox(width: itemWidth, child: item)],
                              );
                            }),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(.55), borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [
                                const Icon(Icons.check_circle_rounded, color: _AA.green, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Сейчас выбрано: $_filtersSummary',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: _AA.text, fontSize: 12.4, fontWeight: FontWeight.w900, height: 1.18),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: _FilterHubSmallButton(
                                  icon: Icons.refresh_rounded,
                                  label: 'Обновить данные',
                                  onTap: () => _runInsideFilterHub(context, onRefresh, modalSetState),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: _FilterHubSmallButton(
                                  icon: Icons.check_rounded,
                                  label: 'Применить выбор',
                                  primary: true,
                                  onTap: () => Navigator.of(sheetContext).pop(),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = startTime != null || endTime != null;
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 720;
    final tablet = width >= 720 && width < 1280;
    if (width < 10000) {
      final inlineCards = <Widget>[
        _InlineAnalyticsFilterCard(icon: Icons.calendar_month_rounded, title: 'Дата', value: onlySelectedDate ? _date : 'все даты', active: true, onTap: onOpenSessionPicker),
        _InlineAnalyticsFilterCard(icon: Icons.event_note_rounded, title: 'Сессии', value: _mobilePeriodValue(_periodLabel(sessionFilterLabel)), active: sessionFilterLabel != 'все за период', onTap: onOpenSessionPicker),
        _InlineAnalyticsFilterCard(icon: Icons.person_rounded, title: 'Игроки', value: _mobilePlayerValue(playerFilterLabel), active: _mobilePlayerValue(playerFilterLabel) != 'Все игроки', onTap: onOpenPlayerPicker),
        _InlineAnalyticsFilterCard(icon: Icons.layers_rounded, title: 'Тип', value: sessionKindLabel, active: sessionKindLabel != 'Все', onTap: onOpenSessionKindPicker),
        _InlineAnalyticsFilterCard(icon: Icons.access_time_rounded, title: 'Время', value: hasTime ? '${_time(startTime, 'с начала')}–${_time(endTime, 'до конца')}' : 'весь день', active: hasTime, onTap: onPickStart),
      ];
      return Container(
        padding: EdgeInsets.fromLTRB(mobile ? 6 : 10, mobile ? 6 : 7, mobile ? 6 : 10, mobile ? 5 : 7),
        decoration: const BoxDecoration(color: _AA.bg),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: mobile ? 54 : 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: inlineCards.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => SizedBox(width: mobile ? 132 : 168, child: inlineCards[index]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _FilterHubIconButton(icon: Icons.refresh_rounded, onTap: onRefresh),
          if (liveRunning) ...[
            const SizedBox(width: 8),
            Container(
              height: mobile ? 42 : 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.radio_button_checked_rounded, color: _AA.green, size: 16),
                const SizedBox(width: 5),
                Text('$localPointsCount', style: const TextStyle(color: _AA.green, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
          ],
        ]),
      );
    }
    if (mobile) {
      return LayoutBuilder(builder: (context, constraints) {
        final cards = <Widget>[
          _MobileFilterCard(icon: Icons.person_rounded, label: 'Игрок', value: _mobilePlayerValue(playerFilterLabel), onTap: onOpenPlayerPicker),
          _MobileFilterCard(icon: Icons.calendar_month_rounded, label: 'Период', value: _mobilePeriodValue(_periodLabel(onlySelectedDate ? _date : sessionFilterLabel)), onTap: onOpenSessionPicker),
          _MobileFilterCard(icon: Icons.map_rounded, label: 'Поле', value: _mobileFieldValue(selectedField?.title ?? 'Поле 7'), onTap: onOpenCalibration),
          _MobileFilterCard(icon: Icons.layers_rounded, label: 'Тип', value: sessionKindLabel, onTap: onOpenSessionKindPicker),
          _MobileFilterCard(icon: Icons.tune_rounded, label: 'Фильтры', value: hasTime ? 'Время' : 'Дата', onTap: onPick),
        ];
        final cardWidths = <double>[132, 132, 116, 122, 118];
        return SizedBox(
          height: 56,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) => SizedBox(width: cardWidths[index], child: cards[index]),
          ),
        );
      });
    }
    if (tablet) {
      final cards = <Widget>[
        _TabletFilterCard(icon: Icons.person_rounded, label: 'Игрок', value: playerFilterLabel, onTap: onOpenPlayerPicker),
        _TabletFilterCard(icon: Icons.calendar_month_rounded, label: 'Период', value: _periodLabel(onlySelectedDate ? _date : sessionFilterLabel), onTap: onOpenSessionPicker),
        _TabletFilterCard(icon: Icons.map_rounded, label: 'Поле', value: selectedField?.title ?? 'не выбрано', onTap: onOpenCalibration),
        _TabletFilterCard(icon: Icons.layers_rounded, label: 'Тип', value: sessionKindLabel, onTap: onOpenSessionKindPicker),
        _TabletFilterCard(icon: Icons.tune_rounded, label: 'Фильтры', value: hasTime ? 'время' : (onlySelectedDate ? 'дата' : 'все даты'), onTap: onPick),
      ];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        color: Colors.transparent,
        child: Row(children: [
          for (var i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i != cards.length - 1) const SizedBox(width: 7),
          ],
        ]),
      );
    }

    final chips = <Widget>[
      _FilterPill(icon: Icons.person_rounded, label: 'Игрок', value: playerFilterLabel, onTap: onOpenPlayerPicker, primary: true),
      _FilterPill(icon: Icons.layers_rounded, label: 'Тип', value: sessionKindLabel, onTap: onOpenSessionKindPicker, primary: true),
      _FilterPill(icon: Icons.event_note_rounded, label: 'Сессии', value: sessionFilterLabel, onTap: onOpenSessionPicker, primary: true),
      _FilterPill(icon: Icons.map_rounded, label: 'Поле', value: selectedField?.title ?? 'не выбрано', onTap: onOpenCalibration, primary: true),
      _FilterPill(icon: Icons.calendar_month_rounded, label: 'Дата', value: onlySelectedDate ? _date : 'все даты', onTap: onPick, primary: true),
      _IconOnlyButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
      _IconOnlyButton(icon: Icons.chevron_right_rounded, onTap: onNext),
      _SmallButton(icon: Icons.today_rounded, label: 'Сегодня', onTap: onToday),
      _FilterPill(icon: Icons.access_time_rounded, label: 'Начало', value: _time(startTime, 'с начала'), onTap: onPickStart),
      _FilterPill(icon: Icons.schedule_rounded, label: 'Конец', value: _time(endTime, 'до конца'), onTap: onPickEnd),
      if (hasTime) _SmallButton(icon: Icons.close_rounded, label: 'Сброс времени', onTap: onClearTime),
      _TogglePill(label: onlySelectedDate ? 'Только дата' : 'Все даты', value: onlySelectedDate, onChanged: onToggleMode),
      _SmallButton(icon: Icons.refresh_rounded, label: 'Обновить', onTap: onRefresh),
      if (liveRunning) _FilterPill(icon: Icons.radio_button_checked_rounded, label: 'Live', value: 'точек $localPointsCount', onTap: null, primary: true),
    ];
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: const BoxDecoration(color: _AA.card, border: Border(bottom: BorderSide(color: _AA.line))),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }
}


class _InlineAnalyticsFilterCard extends StatelessWidget {
  const _InlineAnalyticsFilterCard({required this.icon, required this.title, required this.value, required this.active, required this.onTap});
  final IconData icon;
  final String title;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _AA.greenSoft : _AA.card,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: active ? _AA.green.withOpacity(.38) : _AA.line),
          boxShadow: const [BoxShadow(color: Color(0x05101828), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: active ? Colors.white.withOpacity(.82) : Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: active ? _AA.green : _AA.muted, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w600, height: 1.0)),
            const SizedBox(height: 4),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _AA.green : _AA.text, fontSize: 12.0, fontWeight: FontWeight.w700, height: 1.0)),
          ])),
        ]),
      ),
    );
  }
}


class _TrackerInlineAnalyticsOverlay extends StatelessWidget {
  const _TrackerInlineAnalyticsOverlay({
    required this.mode,
    required this.selectedDate,
    required this.sessions,
    required this.players,
    required this.selectedPlayerIds,
    required this.selectedKind,
    required this.selectedKindLabel,
    required this.loading,
    required this.summary,
    required this.onClose,
    required this.onShowCalendar,
    required this.onShowPlayers,
    required this.onShowKind,
    required this.onSelectDate,
    required this.onSelectSession,
    required this.onSelectPlayers,
    required this.onSelectKind,
  });

  final String mode;
  final DateTime selectedDate;
  final List<TrackerSessionModel> sessions;
  final List<TrackerPlayerOption> players;
  final Set<int> selectedPlayerIds;
  final PlayerTrainingCalendarMode selectedKind;
  final String selectedKindLabel;
  final bool loading;
  final String summary;
  final VoidCallback onClose;
  final VoidCallback onShowCalendar;
  final VoidCallback onShowPlayers;
  final VoidCallback onShowKind;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<TrackerSessionModel> onSelectSession;
  final ValueChanged<Set<int>> onSelectPlayers;
  final ValueChanged<PlayerTrainingCalendarMode> onSelectKind;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 720;
    final radius = 0.0;

    Widget modeButton({required String key, required IconData icon, required String label, required VoidCallback onTap}) {
      final active = mode == key;
      return _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: mobile ? 36 : 34,
          padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12),
          decoration: BoxDecoration(
            color: active ? _AA.greenSoft : _AA.card,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.transparent, width: 0),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: mobile ? 15 : 14, color: active ? _AA.green : _AA.muted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? _AA.green : _AA.text, fontSize: mobile ? 11.4 : 11.0, fontWeight: FontWeight.w700, letterSpacing: -.06)),
          ]),
        ),
      );
    }

    final Widget body = switch (mode) {
      'players' => _InlinePlayerFilterPanel(players: players, sessions: sessions, selectedDate: selectedDate, selectedIds: selectedPlayerIds, sessionKind: selectedKind, onChanged: onSelectPlayers),
      'type' => _InlineKindFilterPanel(selected: selectedKind, onChanged: onSelectKind),
      _ => _TrackerInlineCalendarPane(
          initialDate: selectedDate,
          sessions: sessions,
          players: players,
          loading: loading,
          onSelected: onSelectDate,
          onOpenSession: onSelectSession,
          onClose: onClose,
        ),
    };

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: _AA.bg,
          borderRadius: BorderRadius.circular(radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: mobile ? 52 : 50,
            padding: EdgeInsets.fromLTRB(mobile ? 8 : 10, 5, mobile ? 6 : 8, 5),
            decoration: const BoxDecoration(color: _AA.card, border: Border(bottom: BorderSide(color: _AA.line))),
            child: Row(children: [
              Container(
                width: mobile ? 36 : 34,
                height: mobile ? 36 : 34,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.tune_rounded, color: _AA.green, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Выбор аналитики', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _AA.text, fontSize: 13.2, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -.10)),
                const SizedBox(height: 4),
                Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w500, height: 1.0)),
              ])),
              _NoHoverTap(
                onTap: onClose,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: mobile ? 36 : 34,
                  height: mobile ? 36 : 34,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.close_rounded, color: _AA.muted, size: 19),
                ),
              ),
            ]),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(mobile ? 6 : 8, 6, mobile ? 6 : 8, 6),
            decoration: const BoxDecoration(color: _AA.bg, border: Border(bottom: BorderSide(color: _AA.line))),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(children: [
                modeButton(key: 'calendar', icon: Icons.calendar_month_rounded, label: 'Дата и сессии', onTap: onShowCalendar),
                const SizedBox(width: 8),
                modeButton(key: 'players', icon: Icons.groups_rounded, label: selectedPlayerIds.isEmpty ? 'Игроки' : 'Игроки · ${selectedPlayerIds.length}', onTap: onShowPlayers),
                const SizedBox(width: 8),
                modeButton(key: 'type', icon: Icons.layers_rounded, label: selectedKindLabel, onTap: onShowKind),
              ]),
            ),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

class _TrackerInlineAnalyticsSelector extends StatelessWidget {
  const _TrackerInlineAnalyticsSelector({
    required this.mode,
    required this.selectedDate,
    required this.sessions,
    required this.players,
    required this.selectedPlayerIds,
    required this.selectedKind,
    required this.selectedKindLabel,
    required this.loading,
    required this.onClose,
    required this.onSelectDate,
    required this.onSelectSession,
    required this.onSelectPlayers,
    required this.onSelectKind,
  });

  final String mode;
  final DateTime selectedDate;
  final List<TrackerSessionModel> sessions;
  final List<TrackerPlayerOption> players;
  final Set<int> selectedPlayerIds;
  final PlayerTrainingCalendarMode selectedKind;
  final String selectedKindLabel;
  final bool loading;
  final VoidCallback onClose;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<TrackerSessionModel> onSelectSession;
  final ValueChanged<Set<int>> onSelectPlayers;
  final ValueChanged<PlayerTrainingCalendarMode> onSelectKind;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 720;

    if (mode == 'calendar') {
      return Container(
        padding: EdgeInsets.fromLTRB(mobile ? 6 : 10, 0, mobile ? 6 : 10, 8),
        decoration: const BoxDecoration(
          color: _AA.bg,
          border: Border(bottom: BorderSide(color: _AA.line)),
        ),
        child: _TrackerInlineCalendarPane(
          initialDate: selectedDate,
          sessions: sessions,
          players: players,
          loading: loading,
          onSelected: onSelectDate,
          onOpenSession: onSelectSession,
          onClose: onClose,
        ),
      );
    }

    final title = switch (mode) {
      'players' => 'Игроки аналитики',
      'type' => 'Тип сессий',
      _ => 'Фильтр аналитики',
    };
    final subtitle = switch (mode) {
      'players' => selectedPlayerIds.isEmpty ? 'показывается вся команда' : '${selectedPlayerIds.length} выбрано',
      'type' => selectedKindLabel,
      _ => '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year} · ${sessions.length} сессий',
    };
    final Widget body = mode == 'players'
        ? _InlinePlayerFilterPanel(players: players, sessions: sessions, selectedDate: selectedDate, selectedIds: selectedPlayerIds, sessionKind: selectedKind, onChanged: onSelectPlayers)
        : _InlineKindFilterPanel(selected: selectedKind, onChanged: onSelectKind);

    return Container(
      padding: EdgeInsets.fromLTRB(mobile ? 6 : 10, 0, mobile ? 6 : 10, 8),
      decoration: const BoxDecoration(color: _AA.bg, border: Border(bottom: BorderSide(color: _AA.line))),
      child: Container(
        decoration: BoxDecoration(
          color: _AA.card,
          borderRadius: BorderRadius.circular(mobile ? 20 : 18),
          boxShadow: const [BoxShadow(color: Color(0x07111827), blurRadius: 12, offset: Offset(0, 5))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: mobile ? 50 : 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(color: _AA.card, border: Border(bottom: BorderSide(color: _AA.line))),
            child: Row(children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.tune_rounded, color: _AA.green, size: 18)),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 13.4, fontWeight: FontWeight.w600, height: 1.0, letterSpacing: -.08)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w500, height: 1.0)),
              ])),
              _NoHoverTap(
                onTap: onClose,
                borderRadius: BorderRadius.circular(13),
                child: Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.close_rounded, color: _AA.muted, size: 19)),
              ),
            ]),
          ),
          body,
        ]),
      ),
    );
  }
}

String _shortPlayerName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'Игрок';
  if (parts.length == 1) return parts.first;
  final last = parts.first;
  final initial = parts.length > 1 && parts[1].isNotEmpty ? '${parts[1][0]}.' : '';
  return '$last $initial'.trim();
}

DateTime? _trackerInlineSessionDateTime(TrackerSessionModel session) =>
    _trackerMoscowDateTime(session.createdAt);

bool _trackerInlineSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _trackerInlineNormalizeName(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

List<TrackerSessionModel> _trackerInlinePlayerDaySessions(TrackerPlayerOption player, List<TrackerSessionModel> daySessions) {
  final id = player.id;
  final name = _trackerInlineNormalizeName(player.name);
  return daySessions.where((session) {
    if (session.playerId != null && session.playerId == id) return true;
    final sessionName = _trackerInlineNormalizeName(session.playerName ?? '');
    return sessionName.isNotEmpty && name.isNotEmpty && sessionName == name;
  }).toList(growable: false);
}

String _trackerInlineSessionWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final word = mod10 == 1 && mod100 != 11 ? 'сессия' : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14) ? 'сессии' : 'сессий');
  return '$count $word';
}

class _InlinePlayerFilterPanel extends StatelessWidget {
  const _InlinePlayerFilterPanel({required this.players, required this.sessions, required this.selectedDate, required this.selectedIds, required this.sessionKind, required this.onChanged});
  final List<TrackerPlayerOption> players;
  final List<TrackerSessionModel> sessions;
  final DateTime selectedDate;
  final Set<int> selectedIds;
  final PlayerTrainingCalendarMode sessionKind;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 720;

    return Container(
      color: _AA.bg,
      padding: EdgeInsets.fromLTRB(mobile ? 8 : 12, mobile ? 8 : 10, mobile ? 8 : 12, mobile ? 12 : 14),
      child: LayoutBuilder(builder: (context, c) {
        final columns = mobile
            ? 2
            : (c.maxWidth >= 1320
                ? 5
                : (c.maxWidth >= 980 ? 4 : 3));
        final gap = mobile ? 8.0 : 10.0;
        final itemWidth = math.max(mobile ? 132.0 : 138.0, (c.maxWidth - gap * (columns - 1)) / columns);
        final daySessions = sessions.where((s) {
          final dt = _trackerInlineSessionDateTime(s);
          return dt != null && _trackerInlineSameDay(dt, selectedDate);
        }).toList(growable: false);
        // Для личных тренировок показываем только тех игроков, у которых
        // действительно есть личная сессия на выбранную дату. Иначе список
        // выглядел как полный командный состав, хотя найдено всего 1–2 сессии.
        final visible = (sessionKind == PlayerTrainingCalendarMode.personal
                ? players.where((p) => _trackerInlinePlayerDaySessions(p, daySessions).isNotEmpty)
                : players)
            .take(72)
            .toList(growable: false);
        final cards = <Widget>[
          SizedBox(
            width: itemWidth,
            child: _InlinePlayerPickCard.team(
              active: selectedIds.isEmpty,
              daySessionCount: daySessions.length,
              dayDistanceM: daySessions.fold<double>(0, (sum, s) => sum + s.distanceM),
              personalMode: sessionKind == PlayerTrainingCalendarMode.personal,
              onTap: () => onChanged(<int>{}),
              mobile: mobile,
            ),
          ),
          for (final p in visible)
            SizedBox(
              width: itemWidth,
              child: _InlinePlayerPickCard(
                player: p,
                active: selectedIds.contains(p.id),
                mobile: mobile,
                daySessionCount: _trackerInlinePlayerDaySessions(p, daySessions).length,
                dayDistanceM: _trackerInlinePlayerDaySessions(p, daySessions).fold<double>(0, (sum, s) => sum + s.distanceM),
                onTap: () {
                  final next = Set<int>.from(selectedIds);
                  if (next.contains(p.id)) {
                    next.remove(p.id);
                  } else {
                    next.add(p.id);
                  }
                  onChanged(next);
                },
              ),
            ),
        ];
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Wrap(spacing: gap, runSpacing: gap, children: cards),
        );
      }),
    );
  }
}

class _InlinePlayerPickCard extends StatelessWidget {
  const _InlinePlayerPickCard({required this.player, required this.active, required this.onTap, required this.mobile, required this.daySessionCount, required this.dayDistanceM}) : team = false, personalMode = false;
  const _InlinePlayerPickCard.team({required this.active, required this.onTap, required this.mobile, required this.daySessionCount, required this.dayDistanceM, this.personalMode = false})
      : player = null,
        team = true;

  final TrackerPlayerOption? player;
  final bool team;
  final bool active;
  final bool mobile;
  final bool personalMode;
  final int daySessionCount;
  final double dayDistanceM;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = team ? (personalMode ? 'Все личные' : 'Вся команда') : _shortPlayerName(player?.name ?? 'Игрок');
    final fullName = team ? (personalMode ? 'игроки с личными сессиями' : 'все игроки') : (player?.name ?? 'Игрок');
    final numberRaw = player?.number?.toString().trim() ?? '';
    final positionRaw = player?.position?.toString().trim() ?? '';
    final meta = team
        ? (personalMode ? 'личные тренировки' : 'командная аналитика')
        : [
            if (numberRaw.isNotEmpty) '№ $numberRaw',
            if (positionRaw.isNotEmpty) positionRaw,
          ].join(' · ');
    final sub = meta.isEmpty ? fullName : meta;
    final hasDaySession = daySessionCount > 0;
    final compactSessionValue = daySessionCount.toString();
    final compactDistanceValue = dayDistanceM > 0 ? _meters(dayDistanceM) : null;

    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(mobile ? 16 : 18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: mobile ? 92 : 86,
        padding: EdgeInsets.fromLTRB(mobile ? 8 : 10, mobile ? 8 : 8, mobile ? 8 : 10, mobile ? 8 : 8),
        decoration: BoxDecoration(
          color: active ? _AA.greenSoft : _AA.card,
          borderRadius: BorderRadius.circular(mobile ? 16 : 18),
          border: Border.all(color: active ? _AA.green.withOpacity(.44) : _AA.line, width: active ? 1.05 : .9),
          boxShadow: active ? const [BoxShadow(color: Color(0x07111827), blurRadius: 12, offset: Offset(0, 5))] : null,
        ),
        child: Row(children: [
          _InlinePlayerAvatar(player: player, team: team, active: active, size: mobile ? 36 : 46),
          SizedBox(width: mobile ? 8 : 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _AA.green : _AA.text, fontSize: mobile ? 11.6 : 12.2, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -.08)),
            const SizedBox(height: 4),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _AA.muted, fontSize: mobile ? 9.2 : 9.2, fontWeight: FontWeight.w500, height: 1.0)),
            const SizedBox(height: 5),
            Wrap(spacing: 4, runSpacing: 4, children: [
              _InlinePlayerSessionPill(
                icon: hasDaySession ? Icons.event_available_rounded : Icons.event_busy_rounded,
                value: compactSessionValue,
                active: active,
                enabled: hasDaySession,
                mobile: mobile,
              ),
              if (compactDistanceValue != null)
                _InlinePlayerSessionPill(
                  icon: Icons.route_rounded,
                  value: compactDistanceValue,
                  active: active,
                  enabled: true,
                  mobile: mobile,
                ),
            ]),
          ])),
          const SizedBox(width: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: mobile ? 22 : 22,
            height: mobile ? 22 : 22,
            decoration: BoxDecoration(
              color: active ? _AA.green : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: active ? _AA.green : _AA.line),
            ),
            child: Icon(active ? Icons.check_rounded : Icons.add_rounded, color: active ? Colors.white : _AA.muted, size: mobile ? 16 : 15),
          ),
        ]),
      ),
    );
  }
}


class _InlinePlayerSessionPill extends StatelessWidget {
  const _InlinePlayerSessionPill({required this.icon, required this.value, required this.active, required this.enabled, required this.mobile});

  final IconData icon;
  final String value;
  final bool active;
  final bool enabled;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? _AA.green : _AA.muted;
    return Container(
      height: mobile ? 20 : 22,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 8),
      decoration: BoxDecoration(
        color: enabled ? _AA.greenSoft : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: enabled ? _AA.green.withOpacity(active ? .38 : .24) : _AA.line, width: .8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: mobile ? 11 : 12, color: fg),
        const SizedBox(width: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: mobile ? 9.0 : 9.3, fontWeight: FontWeight.w700, height: 1.0)),
      ]),
    );
  }
}

class _InlinePlayerAvatar extends StatelessWidget {
  const _InlinePlayerAvatar({required this.player, required this.team, required this.active, required this.size});

  final TrackerPlayerOption? player;
  final bool team;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatar = player?.avatar;
    final initials = (player?.name ?? 'И').trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2).map((e) => e.substring(0, 1)).join().toUpperCase();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(.86) : _AA.soft,
        borderRadius: BorderRadius.circular(size * .36),
        border: Border.all(color: active ? _AA.greenLine : _AA.line, width: .9),
      ),
      child: team
          ? Icon(Icons.groups_rounded, color: active ? _AA.green : _AA.muted, size: size * .48)
          : (avatar != null && avatar.isNotEmpty
              ? Image.network(avatar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(initials.isEmpty ? 'И' : initials, style: TextStyle(color: _AA.text, fontSize: size * .26, fontWeight: FontWeight.w700))))
              : Center(child: Text(initials.isEmpty ? 'И' : initials, style: TextStyle(color: _AA.text, fontSize: size * .26, fontWeight: FontWeight.w700)))),
    );
  }
}

class _InlineKindFilterPanel extends StatelessWidget {
  const _InlineKindFilterPanel({required this.selected, required this.onChanged});
  final PlayerTrainingCalendarMode selected;
  final ValueChanged<PlayerTrainingCalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(PlayerTrainingCalendarMode, IconData, String, String)>[
      (PlayerTrainingCalendarMode.team, Icons.groups_rounded, 'Командные', 'тренировки команды'),
      (PlayerTrainingCalendarMode.personal, Icons.person_pin_circle_rounded, 'Личные', 'индивидуальные сессии'),
      (PlayerTrainingCalendarMode.all, Icons.layers_rounded, 'Все', 'команда + личные'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: _AA.bg,
      child: LayoutBuilder(builder: (context, c) {
        final mobile = c.maxWidth < 620;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in options)
              SizedBox(
                width: mobile ? c.maxWidth : (c.maxWidth - 16) / 3,
                child: _NoHoverTap(
                  onTap: () => onChanged(item.$1),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: selected == item.$1 ? _AA.greenSoft : _AA.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected == item.$1 ? _AA.green.withOpacity(.42) : _AA.line)),
                    child: Row(children: [
                      Container(width: 38, height: 38, decoration: BoxDecoration(color: selected == item.$1 ? Colors.white.withOpacity(.86) : Colors.white, borderRadius: BorderRadius.circular(14)), child: Icon(item.$2, color: selected == item.$1 ? _AA.green : _AA.muted, size: 19)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(item.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected == item.$1 ? _AA.green : _AA.text, fontSize: 13.0, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(item.$4, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11.0, fontWeight: FontWeight.w600)),
                      ])),
                    ]),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _AnalyticsFilterHubButton extends StatelessWidget {
  const _AnalyticsFilterHubButton({required this.title, required this.summary, required this.onTap});
  final String title;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x06101828), blurRadius: 12, offset: Offset(0, 5))]),
        child: Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.tune_rounded, color: _AA.green, size: 17)),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 12.2, fontWeight: FontWeight.w900, height: 1.0)),
            const SizedBox(height: 3),
            Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700, height: 1.0)),
          ])),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down_rounded, color: _AA.text, size: 22),
        ]),
      ),
    );
  }
}

class _FilterHubIconButton extends StatelessWidget {
  const _FilterHubIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 44,
        height: 42,
        decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: _AA.green, size: 20),
      ),
    );
  }
}

class _FilterHubAction extends StatelessWidget {
  const _FilterHubAction({required this.icon, required this.title, required this.value, required this.onTap});
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: _AA.green, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 12.8, fontWeight: FontWeight.w900)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: _AA.muted, size: 20),
        ]),
      ),
    );
  }
}

class _FilterHubSmallButton extends StatelessWidget {
  const _FilterHubSmallButton({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: primary ? _AA.green : _AA.card, borderRadius: BorderRadius.circular(9), border: Border.all(color: primary ? _AA.green : _AA.line)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: primary ? Colors.white : _AA.green, size: 18),
          const SizedBox(width: 6),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: primary ? Colors.white : _AA.text, fontSize: 11.2, fontWeight: FontWeight.w900))),
        ]),
      ),
    );
  }
}

class _TabletFilterCard extends StatelessWidget {
  const _TabletFilterCard({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_AA.tabletInnerRadius),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _AA.card,
          borderRadius: BorderRadius.circular(_AA.tabletInnerRadius),
        ),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 12, color: _AA.green),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600, height: 1)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w800, height: 1)),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: _AA.text, size: 13),
        ]),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.icon, required this.label, required this.value, this.onTap, this.primary = false, this.compact = false});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool primary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: compact ? 30 : 27,
        constraints: compact ? const BoxConstraints() : const BoxConstraints(maxWidth: 218),
        padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7),
        decoration: BoxDecoration(
          color: primary ? _AA.soft : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: primary ? _AA.green.withOpacity(.28) : _AA.line),
        ),
        child: Row(mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: compact ? 13 : 14, color: _AA.green),
          SizedBox(width: compact ? 3 : 4),
          if (!compact) Text('$label: ', style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
          Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _AA.text, fontSize: compact ? 8.8 : 9.4, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}




class _MobileFilterCard extends StatelessWidget {
  const _MobileFilterCard({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_AA.mobileInnerRadius),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _AA.card,
          borderRadius: BorderRadius.circular(_AA.mobileInnerRadius),
          boxShadow: const [BoxShadow(color: Color(0x05101828), blurRadius: 12, offset: Offset(0, 5))],
        ),
        child: Row(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _AA.green, size: 14),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600, height: 1.0, letterSpacing: -.12)),
              const SizedBox(height: 3),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 11.2, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -.15)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      borderRadius: BorderRadius.circular(4),
      onTap: () => onChanged(!value),
      child: Container(
        height: 27,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(color: value ? _AA.green : _AA.card, borderRadius: BorderRadius.circular(4), border: Border.all(color: value ? _AA.green : _AA.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(value ? Icons.check_circle_rounded : Icons.calendar_view_month_rounded, size: 14, color: value ? Colors.white : _AA.green),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: value ? Colors.white : _AA.text, fontSize: 9.6, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _IconOnlyButton extends StatelessWidget {
  const _IconOnlyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, size: 16, color: _AA.green),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.liveRunning,
    required this.commandChannelReady,
    required this.onRefresh,
    required this.onLive,
  });
  final String title;
  final String subtitle;
  final bool liveRunning;
  final bool commandChannelReady;
  final VoidCallback onRefresh;
  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(color: _AA.card, border: Border(bottom: BorderSide(color: _AA.line))),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.analytics_rounded, color: _AA.green, size: 16)),
        const SizedBox.shrink(),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w600)),
        ])),
        if (liveRunning) ...[
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.radio_button_checked_rounded, size: 14, color: _AA.green),
              SizedBox(width: 5),
              Text('Live идёт', style: TextStyle(color: _AA.green, fontSize: 10.4, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 4),
        ],
        _SmallButton(icon: Icons.refresh_rounded, label: 'Обновить', onTap: onRefresh),
      ]),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.selected,
    required this.onSelect,
    required this.filterActive,
    required this.filterLabel,
    required this.onFilterTap,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final bool filterActive;
  final String filterLabel;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 720;
    final tablet = width >= 720 && width < 1280;

    Widget filterChip({required bool mobileMode, required bool tabletMode, required bool desktopMode}) {
      final label = desktopMode ? 'Выбор · $filterLabel' : 'Выбор';
      final height = mobileMode ? 34.0 : 36.0;
      return _NoHoverTap(
        borderRadius: BorderRadius.circular(9),
        onTap: onFilterTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: height,
          padding: EdgeInsets.symmetric(
            horizontal: mobileMode ? 9 : 11,
            vertical: mobileMode ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: filterActive ? _AA.greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: filterActive ? _AA.greenLine : Colors.transparent,
              width: .9,
            ),
            boxShadow: filterActive
                ? [
                    BoxShadow(
                      color: _AA.green.withOpacity(.055),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              Icons.tune_rounded,
              size: mobileMode ? 13.5 : 14,
              color: filterActive ? _AA.green : _AA.muted,
            ),
            SizedBox(width: mobileMode ? 5 : 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: mobileMode ? 90 : 220),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: filterActive ? _AA.green : _AA.muted,
                  fontSize: mobileMode ? 11.0 : 11.4,
                  fontWeight: filterActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (filterActive) ...[
              const SizedBox(width: 6),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: _AA.green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ]),
        ),
      );
    }

    Widget tabItem(int tabIndex, {required bool mobileMode, required bool tabletMode, required bool desktopMode}) {
      final tab = _tabs[tabIndex];
      final active = selected == tabIndex;
      final height = mobileMode ? 34.0 : 36.0;

      return _NoHoverTap(
        borderRadius: BorderRadius.circular(9),
        onTap: () => onSelect(tabIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: height,
          padding: EdgeInsets.symmetric(
            horizontal: mobileMode ? 9 : 11,
            vertical: mobileMode ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: active ? _AA.greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? _AA.greenLine : Colors.transparent,
              width: .9,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _AA.green.withOpacity(.055),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              tab.icon,
              size: mobileMode ? 13.5 : 14,
              color: active ? _AA.green : _AA.muted,
            ),
            SizedBox(width: mobileMode ? 5 : 6),
            Text(
              tab.label,
              style: TextStyle(
                fontFamily: 'Inter',
                color: active ? _AA.green : _AA.muted,
                fontSize: mobileMode ? 11.0 : 11.4,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: _AA.green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ]),
        ),
      );
    }

    Widget itemAt(int index, {required bool mobileMode, required bool tabletMode, required bool desktopMode}) {
      if (index == 1) return filterChip(mobileMode: mobileMode, tabletMode: tabletMode, desktopMode: desktopMode);
      final tabIndex = index > 1 ? index - 1 : index;
      return tabItem(tabIndex, mobileMode: mobileMode, tabletMode: tabletMode, desktopMode: desktopMode);
    }

    if (mobile) {
      return Container(
        height: 44,
        color: _AA.bg,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _AA.card,
            borderRadius: BorderRadius.circular(_AA.mobileInnerRadius),
            boxShadow: const [BoxShadow(color: Color(0x0A101828), blurRadius: 16, offset: Offset(0, 7))],
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            scrollDirection: Axis.horizontal,
            itemCount: _tabs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, i) => itemAt(i, mobileMode: true, tabletMode: false, desktopMode: false),
          ),
        ),
      );
    }

    if (tablet) {
      return Container(
        height: 46,
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _AA.card,
            borderRadius: BorderRadius.circular(_AA.tabletInnerRadius),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            scrollDirection: Axis.horizontal,
            itemCount: _tabs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => itemAt(i, mobileMode: false, tabletMode: true, desktopMode: false),
          ),
        ),
      );
    }

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: const BoxDecoration(
        color: _AA.card,
        border: Border(bottom: BorderSide(color: _AA.line)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => itemAt(i, mobileMode: false, tabletMode: false, desktopMode: true),
      ),
    );
  }
}



class _OverviewMetricsStrip extends StatelessWidget {
  const _OverviewMetricsStrip({required this.compact, required this.cards});
  final bool compact;
  final List<_Metric> cards;

  @override
  Widget build(BuildContext context) {
    final visible = compact ? cards.take(3).toList(growable: false) : cards;
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 10, 8, compact ? 8 : 10, 8),
      color: const Color(0xFFF6F7F6),
      child: Row(children: [
        for (var i = 0; i < visible.length; i++) ...[
          Expanded(child: visible[i]),
          if (i != visible.length - 1) const SizedBox(width: 8),
        ],
      ]),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.compact,
    required this.teamName,
    required this.clubName,
    required this.bundle,
    required this.local,
    required this.selectedPlayer,
    required this.playerFilterLabel,
    required this.selectedField,
    required this.selectedSession,
    required this.heatmap,
    required this.usingLatestFallback,
    required this.fallbackMessage,
    required this.onOpenCalibration,
    required this.onOpenSessions,
    required this.onOpenInsight,
  });

  final bool compact;
  final String teamName;
  final String clubName;
  final _AnalyticsBundle bundle;
  final _LocalTrackAnalysis local;
  final TrackerPlayerOption? selectedPlayer;
  final String playerFilterLabel;
  final TrackerFieldModel? selectedField;
  final TrackerSessionModel? selectedSession;
  final List<TrackerHeatPoint> heatmap;
  final bool usingLatestFallback;
  final String fallbackMessage;
  final VoidCallback onOpenCalibration;
  final VoidCallback onOpenSessions;
  final ValueChanged<_CoachInsight> onOpenInsight;

  @override
  Widget build(BuildContext context) {
    final rows = _rowsForAnalytics(bundle, selectedSession, local, selectedPlayer);
    final total = _DayTotal.fromRows(rows, sessionsCount: bundle.sessions.length, fallbackSession: selectedSession, local: local);
    _CoachInsight overviewInsight(String title, IconData icon, List<_CoachInsightMetric> metrics, List<String> bullets, {Color accent = _AA.green}) {
      return _CoachInsight(
        title: title,
        subtitle: '${selectedPlayer?.name ?? selectedSession?.playerName ?? 'Команда'} · ${total.sessionsCount} сессий',
        icon: icon,
        accent: accent,
        metrics: metrics,
        bullets: bullets,
        footer: 'Карточки сверху теперь кликабельные: тренер нажимает на нужный показатель и сразу получает расшифровку справа без отдельного модального окна.',
      );
    }

    final cards = <_Metric>[
      _Metric(icon: Icons.route_rounded, title: 'Объём дня', value: _meters(total.distanceM), note: '${total.sessionsCount} сессий', onTap: () => onOpenInsight(overviewInsight('Объём работы', Icons.route_rounded, [
        _CoachInsightMetric('Дистанция', _meters(total.distanceM), 'за период'),
        _CoachInsightMetric('Сессии', '${total.sessionsCount}', 'выбрано'),
        _CoachInsightMetric('Игроки', '${total.playersCount}', 'с данными'),
        _CoachInsightMetric('м/мин', total.sessionsCount <= 0 ? '—' : (total.distanceM / math.max(1, total.sessionsCount)).toStringAsFixed(0), 'на сессию'),
      ], ['Смотрите, кто дал основной объём, а кто выпал по дистанции.', 'Если выбран период, рейтинг ниже агрегирует игроков по всем сессиям.', 'Для детских команд объём важнее оценивать вместе со скоростными зонами, а не отдельно.']))),
      _Metric(icon: Icons.groups_rounded, title: 'Игроков', value: '${total.playersCount}', note: 'с данными', onTap: () => onOpenInsight(overviewInsight('Игроки с данными', Icons.groups_rounded, [
        _CoachInsightMetric('Игроки', '${total.playersCount}', 'активные'),
        _CoachInsightMetric('Сессии', '${total.sessionsCount}', 'в фильтре'),
        _CoachInsightMetric('Фокус', selectedPlayer?.name ?? 'команда', 'выбор'),
        _CoachInsightMetric('Поле', selectedField?.title ?? '—', 'калибровка'),
      ], ['Если игроков меньше состава, проверьте выбранную дату, сессии и привязку устройств.', 'По клику на игрока в командной таблице можно открыть персональный фокус.', 'Пульсометрные данные также добавляются в общую картину нагрузки.']))),
      _Metric(icon: Icons.speed_rounded, title: 'Макс. скорость', value: '${total.maxSpeedKmh.toStringAsFixed(1)}', note: 'км/ч', onTap: () => onOpenInsight(overviewInsight('Максимальная скорость', Icons.speed_rounded, [
        _CoachInsightMetric('Пик', '${total.maxSpeedKmh.toStringAsFixed(1)}', 'км/ч'),
        _CoachInsightMetric('SPR', '${local.sprintCount}', 'локально'),
        _CoachInsightMetric('HIR/VHIR', _meters(total.hirDistanceM), 'интенсивность'),
        _CoachInsightMetric('Игроки', '${total.playersCount}', 'сравнение'),
      ], ['Пик нужно смотреть вместе с графиком скорости: одиночный выброс GPS не должен ломать вывод.', 'Вкладка «Скорость» показывает линию по времени и пороги HIR/SPR.', 'Для U-команд пороги берутся из возрастного профиля команды.'], accent: _AA.blue))),
      _Metric(icon: Icons.flash_on_rounded, title: 'Спринты', value: '${total.sprintCount}', note: _meters(total.sprintDistanceM), onTap: () => onOpenInsight(overviewInsight('Спринты', Icons.flash_on_rounded, [
        _CoachInsightMetric('Спринты', '${total.sprintCount}', 'кол-во'),
        _CoachInsightMetric('SPR дистанция', _meters(total.sprintDistanceM), 'суммарно'),
        _CoachInsightMetric('HIR/VHIR', _meters(total.hirDistanceM), 'подводка'),
        _CoachInsightMetric('Пик', '${total.maxSpeedKmh.toStringAsFixed(1)}', 'км/ч'),
      ], ['На карте включите фильтр «Спринт» — красным останутся участки выше порога.', 'График масштабируется по устойчивым точкам, чтобы скорость около порога не выглядела слишком низко.', 'Лидеры спринтов открываются справа по клику на игрока.'], accent: _AA.red))),
      _Metric(icon: Icons.local_fire_department_rounded, title: 'HIR/VHIR', value: _meters(total.hirDistanceM), note: 'интенсивность', onTap: () => onOpenInsight(overviewInsight('Высокая интенсивность', Icons.local_fire_department_rounded, [
        _CoachInsightMetric('HIR/VHIR', _meters(total.hirDistanceM), 'метры'),
        _CoachInsightMetric('Спринты', '${total.sprintCount}', 'выше SPR'),
        _CoachInsightMetric('SPR dist.', _meters(total.sprintDistanceM), 'метры'),
        _CoachInsightMetric('Пик', '${total.maxSpeedKmh.toStringAsFixed(1)}', 'км/ч'),
      ], ['HIR показывает подготовительную высокую интенсивность до чистого спринта.', 'Если HIR много, а спринтов мало — команда работала интенсивно, но без максимальных рывков.', 'Сравнивайте с пульсом, чтобы увидеть цену этой работы.'], accent: _AA.orange))),
      _Metric(icon: Icons.compare_arrows_rounded, title: 'Уск./торм.', value: '${total.accelCount}/${total.decelCount}', note: 'механика', onTap: () => onOpenInsight(overviewInsight('Локомоторная механика', Icons.compare_arrows_rounded, [
        _CoachInsightMetric('Ускорения', '${total.accelCount}', 'кол-во'),
        _CoachInsightMetric('Торможения', '${total.decelCount}', 'кол-во'),
        _CoachInsightMetric('Баланс', '${total.accelCount - total.decelCount}', 'разница'),
        _CoachInsightMetric('Load', total.loadScore.toStringAsFixed(0), 'вклад'),
      ], ['Частые торможения повышают нагрузку даже при небольшой дистанции.', 'Для тренера это подсказка по манёвренности, сменам направления и усталости.', 'Смотрите вместе с картой: где именно игроки разгонялись и тормозили.'], accent: _AA.blue))),
      _Metric(icon: Icons.bolt_rounded, title: 'Нагрузка', value: total.loadScore.toStringAsFixed(0), note: 'суммарная', onTap: () => onOpenInsight(overviewInsight('Нагрузка команды', Icons.bolt_rounded, [
        _CoachInsightMetric('Load', total.loadScore.toStringAsFixed(0), 'сумма'),
        _CoachInsightMetric('Дистанция', _meters(total.distanceM), 'объём'),
        _CoachInsightMetric('HIR/VHIR', _meters(total.hirDistanceM), 'интенсивность'),
        _CoachInsightMetric('Уск/торм', '${total.accelCount}/${total.decelCount}', 'механика'),
      ], ['Нагрузка собирается из объёма, интенсивности, спринтов и механики.', 'Если подключён пульсометр, вкладка «Пульс» помогает понять внутреннюю нагрузку.', 'Рейтинг нагрузки показывает, кого стоит разгрузить или проверить после тренировки.'], accent: _AA.orange))),
    ];

    final phone = MediaQuery.sizeOf(context).width < 720;
    if (phone) {
      return _MobileOverviewDashboard(
        teamName: teamName,
        clubName: clubName,
        total: total,
        cards: cards,
        rows: rows,
        selectedPlayer: selectedPlayer,
        selectedField: selectedField,
        selectedSession: selectedSession,
        local: local,
        heatmap: heatmap,
        usingLatestFallback: usingLatestFallback,
        fallbackMessage: fallbackMessage,
        onOpenSessions: onOpenSessions,
      );
    }

    return Column(children: [
      if (usingLatestFallback) _InlineNotice(text: fallbackMessage),
      _OverviewMetricsStrip(compact: compact, cards: cards),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(flex: 5, child: _DaySummaryPanel(total: total, selectedField: selectedField, selectedPlayer: selectedPlayer, onOpenSessions: onOpenSessions)),
            const SizedBox(width: 8),
            Expanded(flex: 5, child: _PlayerActivityProfilePanel(selectedPlayer: selectedPlayer, selectedSession: selectedSession, local: local, heatmap: heatmap, rows: rows, title: 'Радар выбранной сессии')),
            const SizedBox(width: 8),
            Expanded(flex: 8, child: _DayRankingsPanel(rows: rows)),
          ]),
        ),
      ),
    ]);
  }
}





class _MobileOverviewDashboard extends StatelessWidget {
  const _MobileOverviewDashboard({
    required this.teamName,
    required this.clubName,
    required this.total,
    required this.cards,
    required this.rows,
    required this.selectedPlayer,
    required this.selectedField,
    required this.selectedSession,
    required this.local,
    required this.heatmap,
    required this.usingLatestFallback,
    required this.fallbackMessage,
    required this.onOpenSessions,
  });

  final String teamName;
  final String clubName;
  final _DayTotal total;
  final List<_Metric> cards;
  final List<TrackerPlayerLoadRow> rows;
  final TrackerPlayerOption? selectedPlayer;
  final TrackerFieldModel? selectedField;
  final TrackerSessionModel? selectedSession;
  final _LocalTrackAnalysis local;
  final List<TrackerHeatPoint> heatmap;
  final bool usingLatestFallback;
  final String fallbackMessage;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final twoColumns = width >= 560;
    final kpiColumns = width >= 620 ? 3 : 2;
    final visibleKpis = cards.take(6).toList(growable: false);
    final leaderRows = _mobileLeaderRows(rows);
    final content = <Widget>[
      if (usingLatestFallback) _MobileNoticeCard(text: fallbackMessage),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: kpiColumns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: kpiColumns == 3 ? 1.52 : 1.46,
        children: [for (final metric in visibleKpis) _MobileKpiCard(metric: metric)],
      ),
      const SizedBox(height: 8),
      _MobileTeamSummaryCard(total: total, selectedField: selectedField, selectedPlayer: selectedPlayer, onOpenSessions: onOpenSessions),
      const SizedBox(height: 8),
      _MobileLeadersCard(rows: leaderRows),
      const SizedBox(height: 8),
      twoColumns
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _MobileRadarCard(selectedPlayer: selectedPlayer, selectedSession: selectedSession, local: local, rows: rows)),
              const SizedBox(width: 8),
              Expanded(child: _MobileHeatmapCard(heatmap: heatmap, selectedField: selectedField)),
            ])
          : Column(children: [
              _MobileRadarCard(selectedPlayer: selectedPlayer, selectedSession: selectedSession, local: local, rows: rows),
              const SizedBox(height: 8),
              _MobileHeatmapCard(heatmap: heatmap, selectedField: selectedField),
            ]),
      const SizedBox(height: 8),
      _MobileLastSessionCard(selectedSession: selectedSession, selectedField: selectedField, sessionsCount: total.sessionsCount, onOpenSessions: onOpenSessions),
    ];

    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(8, 8, 8, 132 + bottomSafe),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
    );
  }

  List<TrackerPlayerLoadRow> _mobileLeaderRows(List<TrackerPlayerLoadRow> source) {
    if (source.isEmpty) return const <TrackerPlayerLoadRow>[];
    final map = <int, TrackerPlayerLoadRow>{};
    void put(int key, TrackerPlayerLoadRow? row) {
      if (row == null) return;
      map.putIfAbsent(key, () => row);
    }
    final bySpeed = [...source]..sort((a, b) => b.maxSpeedKmh.compareTo(a.maxSpeedKmh));
    final bySprint = [...source]..sort((a, b) => b.sprintCount.compareTo(a.sprintCount));
    final byLoad = [...source]..sort((a, b) => b.loadScore.compareTo(a.loadScore));
    final byDistance = [...source]..sort((a, b) => b.distanceM.compareTo(a.distanceM));
    put(bySpeed.isNotEmpty ? 1 : 0, bySpeed.isNotEmpty ? bySpeed.first : null);
    put(bySprint.isNotEmpty ? 2 : 0, bySprint.isNotEmpty ? bySprint.first : null);
    put(byLoad.isNotEmpty ? 3 : 0, byLoad.isNotEmpty ? byLoad.first : null);
    put(byDistance.isNotEmpty ? 4 : 0, byDistance.isNotEmpty ? byDistance.first : null);
    return map.values.take(4).toList(growable: false);
  }
}


class _MobileAnalyticsHeaderCard extends StatelessWidget {
  const _MobileAnalyticsHeaderCard({required this.teamName, required this.clubName, required this.onMenu});
  final String teamName;
  final String clubName;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _AA.card,
            shape: BoxShape.circle,
            border: Border.all(color: _AA.green.withOpacity(.28)),
            boxShadow: const [BoxShadow(color: Color(0x06101828), blurRadius: 12, offset: Offset(0, 5))],
          ),
          child: Stack(alignment: Alignment.center, children: [
            Icon(Icons.shield_rounded, color: _AA.green.withOpacity(.07), size: 30),
            const Icon(Icons.sports_soccer_rounded, color: _AA.green, size: 18),
          ]),
        ),
        const SizedBox(width: 7),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(teamName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 15.2, fontWeight: FontWeight.w700, height: 1.03, letterSpacing: -.22)),
          const SizedBox(height: 3),
          Text('Аналитика · $clubName', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w600, height: 1.0)),
        ])),
        const SizedBox(width: 8),
        _NoHoverTap(
          onTap: onMenu,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _AA.card,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x07101828), blurRadius: 14, offset: Offset(0, 6))],
            ),
            child: const Icon(Icons.more_horiz_rounded, color: _AA.text, size: 20),
          ),
        ),
      ]),
    );
  }
}

class _MobileNoticeCard extends StatelessWidget {
  const _MobileNoticeCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(_AA.tabletCardRadius), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: _AA.orange, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: _AA.text, fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}


class _MobileCardShell extends StatelessWidget {
  const _MobileCardShell({required this.child, this.padding = const EdgeInsets.all(10), this.accent = false, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_AA.mobileCardRadius);
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: accent ? _AA.greenSoft : _AA.card,
        borderRadius: radius,
        boxShadow: const [BoxShadow(color: Color(0x06101828), blurRadius: 16, spreadRadius: -10, offset: Offset(0, 8))],
      ),
      child: child,
    );
    return onTap == null ? body : _NoHoverTap(onTap: onTap, borderRadius: radius, child: body);
  }
}

class _MobileKpiCard extends StatelessWidget {
  const _MobileKpiCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return _MobileCardShell(
      onTap: metric.onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Icon(metric.icon, color: _AA.green, size: 16),
        ),
        const Spacer(),
        Text(metric.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700, height: 1.05)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(child: Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 14.2, fontWeight: FontWeight.w700, height: .95))),
          if (metric.note.isNotEmpty) ...[
            const SizedBox(width: 4),
            Flexible(child: Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(metric.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w700)),
            )),
          ],
        ]),
      ]),
    );
  }
}

class _MobileTeamSummaryCard extends StatelessWidget {
  const _MobileTeamSummaryCard({required this.total, required this.selectedField, required this.selectedPlayer, required this.onOpenSessions});
  final _DayTotal total;
  final TrackerFieldModel? selectedField;
  final TrackerPlayerOption? selectedPlayer;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context) {
    return _MobileCardShell(
      onTap: onOpenSessions,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Expanded(child: Text('Командная сводка', style: TextStyle(color: _AA.text, fontSize: 13.2, fontWeight: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: _AA.text, size: 24),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _MobileSummaryStat(icon: Icons.event_note_rounded, title: 'Сессии', value: '${total.sessionsCount}', note: 'выбрано')),
          const SizedBox(width: 8),
          Expanded(child: _MobileSummaryStat(icon: Icons.groups_rounded, title: 'Игроки', value: '${total.playersCount}', note: 'с данными')),
          const SizedBox(width: 8),
          Expanded(child: _MobileSummaryStat(icon: Icons.directions_run_rounded, title: 'Дистанция', value: _meters(total.distanceM), note: 'команда')),
          const SizedBox(width: 8),
          Expanded(child: _MobileSummaryStat(icon: Icons.speed_rounded, title: 'Макс. скорость', value: '${total.maxSpeedKmh.toStringAsFixed(1)}', note: 'км/ч')),
        ]),
        const SizedBox(height: 10),
        Text('${selectedPlayer?.name ?? 'Вся команда'} · ${selectedField?.title ?? 'поле не выбрано'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _MobileSummaryStat extends StatelessWidget {
  const _MobileSummaryStat({required this.icon, required this.title, required this.value, required this.note});
  final IconData icon;
  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 26, height: 26, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: _AA.green, size: 14)),
      const SizedBox(width: 7),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w700)),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 11.8, fontWeight: FontWeight.w700, height: 1.05)),
        Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
      ])),
    ]);
  }
}

class _MobileRadarCard extends StatelessWidget {
  const _MobileRadarCard({required this.selectedPlayer, required this.selectedSession, required this.local, required this.rows});
  final TrackerPlayerOption? selectedPlayer;
  final TrackerSessionModel? selectedSession;
  final _LocalTrackAnalysis local;
  final List<TrackerPlayerLoadRow> rows;

  @override
  Widget build(BuildContext context) {
    final axes = _activityAxes(local: local, session: selectedSession, rows: rows);
    return _MobileCardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Expanded(child: Text('Радар сессии', style: TextStyle(color: _AA.text, fontSize: 13.0, fontWeight: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: _AA.text, size: 22),
        ]),
        const SizedBox(height: 6),
        Text(selectedPlayer?.name ?? selectedSession?.playerName ?? 'Команда', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 1.78,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAF7),
              borderRadius: BorderRadius.circular(_AA.mobileInnerRadius),
            ),
            child: Center(
              child: SizedBox(
                width: 210,
                height: 210,
                child: CustomPaint(painter: _ActivityRadarPainter(axes: axes), child: const SizedBox.expand()),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: const [
          Text('Интенсивность', style: TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
          Spacer(),
          _MobileDot(active: true),
          SizedBox(width: 8),
          _MobileDot(active: false),
          SizedBox(width: 8),
          _MobileDot(active: false),
        ]),
      ]),
    );
  }
}

class _MobileHeatmapCard extends StatelessWidget {
  const _MobileHeatmapCard({required this.heatmap, required this.selectedField});
  final List<TrackerHeatPoint> heatmap;
  final TrackerFieldModel? selectedField;

  @override
  Widget build(BuildContext context) {
    return _MobileCardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Expanded(child: Text('Мини-теплокарта', style: TextStyle(color: _AA.text, fontSize: 13.0, fontWeight: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: _AA.text, size: 22),
        ]),
        const SizedBox(height: 6),
        Text(selectedField?.title ?? 'поле не выбрано', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        AspectRatio(aspectRatio: 1.78, child: CustomPaint(painter: _MiniHeatmapPainter(points: heatmap), child: const SizedBox.expand())),
        const SizedBox(height: 8),
        Row(children: const [
          Text('Интенсивность', style: TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
          SizedBox(width: 10),
          Expanded(child: _MobileHeatGradient()),
        ]),
        const SizedBox(height: 6),
        Row(children: const [
          Expanded(child: Text('Низкая', style: TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w600))),
          Text('Высокая', style: TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

class _MobileHeatGradient extends StatelessWidget {
  const _MobileHeatGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(colors: [Color(0xFFBBF7D0), Color(0xFFFDE68A), Color(0xFFF97316), Color(0xFFEF4444)]),
      ),
    );
  }
}

class _MobileLeadersCard extends StatelessWidget {
  const _MobileLeadersCard({required this.rows});
  final List<TrackerPlayerLoadRow> rows;

  @override
  Widget build(BuildContext context) {
    return _MobileCardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Expanded(child: Text('Лидеры дня', style: TextStyle(color: _AA.text, fontSize: 13.2, fontWeight: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: _AA.text, size: 24),
        ]),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const _Empty(icon: Icons.leaderboard_rounded, text: 'После сохранения сессий здесь появятся лидеры по дистанции, скорости, спринтам и нагрузке.')
        else
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, i) {
                final r = rows[i];
                final metric = i == 0 ? 'Макс. скорость' : (i == 1 ? 'Спринты' : (i == 2 ? 'Нагрузка' : 'Дистанция'));
                final value = i == 0 ? '${r.maxSpeedKmh.toStringAsFixed(1)} км/ч' : (i == 1 ? '${r.sprintCount} шт.' : (i == 2 ? r.loadScore.toStringAsFixed(0) : _meters(r.distanceM)));
                return _MobileLeaderTile(row: r, metric: metric, value: value);
              },
            ),
          ),
      ]),
    );
  }
}

class _MobileLeaderTile extends StatelessWidget {
  const _MobileLeaderTile({required this.row, required this.metric, required this.value});
  final TrackerPlayerLoadRow row;
  final String metric;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _MobileLeaderAvatar(row: row),
        const SizedBox(height: 6),
        Text(_leaderShortName(row.playerName), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(metric, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.green, fontSize: 12.6, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _MobileLeaderAvatar extends StatelessWidget {
  const _MobileLeaderAvatar({required this.row});
  final TrackerPlayerLoadRow row;

  @override
  Widget build(BuildContext context) {
    final avatar = row.avatar;
    final initials = row.playerName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2).map((e) => e.substring(0, 1)).join().toUpperCase();
    return Container(
      width: 36,
      height: 36,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_AA.mobileCardRadius)),
      child: avatar != null && avatar.isNotEmpty
          ? Image.network(avatar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(initials.isEmpty ? 'И' : initials, style: const TextStyle(color: _AA.text, fontSize: 12, fontWeight: FontWeight.w700))))
          : Center(child: Text(initials.isEmpty ? 'И' : initials, style: const TextStyle(color: _AA.text, fontSize: 12, fontWeight: FontWeight.w700))),
    );
  }
}

class _MobileLastSessionCard extends StatelessWidget {
  const _MobileLastSessionCard({required this.selectedSession, required this.selectedField, required this.sessionsCount, required this.onOpenSessions});
  final TrackerSessionModel? selectedSession;
  final TrackerFieldModel? selectedField;
  final int sessionsCount;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context) {
    final date = selectedSession == null ? 'Нет выбранной сессии' : _formatSessionDateTime(selectedSession!.createdAt);
    return _MobileCardShell(
      onTap: onOpenSessions,
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_AA.mobileInnerRadius)), child: const Icon(Icons.calendar_month_rounded, color: _AA.green, size: 21)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Последняя сессия', style: TextStyle(color: _AA.muted, fontSize: 11.4, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 12.2, fontWeight: FontWeight.w700)),
          Text('${selectedField?.title ?? 'Поле не выбрано'} · $sessionsCount сессий', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w600)),
        ])),
        const SizedBox(width: 7),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_AA.mobileInnerRadius)),
          child: const Text('Открыть сессию', style: TextStyle(color: _AA.green, fontSize: 10.4, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _MobileDot extends StatelessWidget {
  const _MobileDot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(width: 8, height: 8, decoration: BoxDecoration(color: active ? _AA.green : _AA.line, borderRadius: BorderRadius.circular(4)));
  }
}

class _MobileMapDashboard extends StatefulWidget {
  const _MobileMapDashboard({
    required this.points,
    required this.localPoints,
    required this.field,
    required this.selectedPlayer,
    required this.selectedSession,
    required this.heatMode,
    required this.onHeatModeChanged,
    required this.sprintThresholdKmh,
    required this.hsrThresholdKmh,
    required this.showSprintArrows,
    required this.mapRotationDeg,
    required this.onOpenCalibration,
  });

  final List<TrackerHeatPoint> points;
  final List<ActionTrackerGpsPoint> localPoints;
  final TrackerFieldModel? field;
  final TrackerPlayerOption? selectedPlayer;
  final TrackerSessionModel? selectedSession;
  final bool heatMode;
  final ValueChanged<bool> onHeatModeChanged;
  final double sprintThresholdKmh;
  final double hsrThresholdKmh;
  final bool showSprintArrows;
  final double mapRotationDeg;
  final VoidCallback onOpenCalibration;

  @override
  State<_MobileMapDashboard> createState() => _MobileMapDashboardState();
}

class _MobileMapDashboardState extends State<_MobileMapDashboard> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final local = _LocalTrackAnalysis.fromPoints(widget.localPoints, sprintThresholdKmh: widget.sprintThresholdKmh, hsrThresholdKmh: widget.hsrThresholdKmh);
    final heatPoints = widget.points.isNotEmpty ? widget.points : _heatmapFromGpsStatic(widget.localPoints, widget.field);
    final filteredSamples = _filter == 'all'
        ? local.speedSamples
        : _activitySpeedSamples(widget.localPoints, _filter, widget.sprintThresholdKmh, hsrThresholdKmh: widget.hsrThresholdKmh);
    final maxSpeed = filteredSamples.fold<double>(0.0, (a, b) => math.max(a, b).toDouble());
    final timeRange = _pointsTimeRange(widget.localPoints);
    final activityLabel = _activityFilterLabel(_filter);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 132 + bottomSafe),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _MobileCardShell(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _MobileIconBox(icon: widget.heatMode ? Icons.local_fire_department_rounded : Icons.timeline_rounded, color: widget.heatMode ? _AA.orange : _AA.green),
              const SizedBox(width: 7),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.heatMode ? 'Тепловая карта' : 'Карта активности', style: const TextStyle(color: _AA.text, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(widget.localPoints.isEmpty ? 'нет точек выбранной сессии' : '${widget.localPoints.length} GPS · $activityLabel · $timeRange', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w600)),
              ])),
              _NoHoverTap(
                onTap: widget.onOpenCalibration,
                borderRadius: BorderRadius.circular(_AA.mobileInnerRadius),
                child: Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(_AA.mobileInnerRadius)), child: const Icon(Icons.open_in_full_rounded, color: _AA.text, size: 17)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _MobileModeChip(label: 'Активность', icon: Icons.timeline_rounded, active: !widget.heatMode, onTap: () => widget.onHeatModeChanged(false))),
              const SizedBox(width: 8),
              Expanded(child: _MobileModeChip(label: 'Тепло', icon: Icons.local_fire_department_rounded, active: widget.heatMode, onTap: () => widget.onHeatModeChanged(true))),
            ]),
            if (!widget.heatMode) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _MobileFilterPill(label: 'Все', value: 'all', current: _filter, onTap: _setFilter),
                  _MobileFilterPill(label: 'Ходьба', value: 'walk', current: _filter, onTap: _setFilter),
                  _MobileFilterPill(label: 'Бег', value: 'run', current: _filter, onTap: _setFilter),
                  _MobileFilterPill(label: 'Высокая', value: 'hir', current: _filter, onTap: _setFilter),
                  _MobileFilterPill(label: 'Спринт', value: 'sprint', current: _filter, onTap: _setFilter),
                  _MobileFilterPill(label: 'Повороты', value: 'turn', current: _filter, onTap: _setFilter),
                ]),
              ),
            ],
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(_AA.mobileCardRadius),
              child: AspectRatio(
                aspectRatio: 1.72,
                child: CustomPaint(
                  painter: _ActionPitchPainter(
                    heat: widget.heatMode ? heatPoints : const <TrackerHeatPoint>[],
                    local: widget.heatMode ? const <ActionTrackerGpsPoint>[] : widget.localPoints,
                    field: widget.field,
                    sprintThresholdKmh: widget.sprintThresholdKmh,
                    hsrThresholdKmh: widget.hsrThresholdKmh,
                    activityFilter: _filter,
                    showSprintArrows: widget.showSprintArrows,
                    mapRotationDeg: widget.mapRotationDeg,
                  ),
                  child: Center(child: widget.localPoints.isEmpty && !widget.heatMode ? const Text('Ждём GPS-точки', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)) : null),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        _MobileCardShell(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const _MobileIconBox(icon: Icons.speed_rounded, color: _AA.green),
              const SizedBox(width: 7),
              Expanded(child: Text('Скорость по фильтру', style: const TextStyle(color: _AA.text, fontSize: 14, fontWeight: FontWeight.w700))),
              Text(maxSpeed > 0 ? 'max ${maxSpeed.toStringAsFixed(1)}' : 'нет скорости', style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            SizedBox(height: 210, child: CustomPaint(painter: _SpeedPainter(samples: filteredSamples, hsrThresholdKmh: widget.hsrThresholdKmh, sprintThresholdKmh: widget.sprintThresholdKmh, maxSpeedKmh: maxSpeed), child: const SizedBox.expand())),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _MobileTinyStat(title: 'Дистанция', value: _meters(local.distanceM), note: 'выбранный фильтр')),
              const SizedBox(width: 8),
              Expanded(child: _MobileTinyStat(title: 'GPS', value: '${widget.localPoints.length}', note: 'точек')),
              const SizedBox(width: 8),
              Expanded(child: _MobileTinyStat(title: 'Спринты', value: '${local.sprintCount}', note: 'рывки')),
            ]),
          ]),
        ),
      ]),
    );
  }

  void _setFilter(String value) => setState(() => _filter = value);
}

class _MobileSpeedDashboard extends StatelessWidget {
  const _MobileSpeedDashboard({required this.bundle, required this.local, required this.selectedSession, required this.hsrThresholdKmh, required this.sprintThresholdKmh});
  final _AnalyticsBundle bundle;
  final _LocalTrackAnalysis local;
  final TrackerSessionModel? selectedSession;
  final double hsrThresholdKmh;
  final double sprintThresholdKmh;

  @override
  Widget build(BuildContext context) {
    final maxSpeed = local.maxSpeedKmh > 0 ? local.maxSpeedKmh : (selectedSession?.maxSpeedKmh ?? 0);
    final avgSpeed = local.avgSpeedKmh > 0 ? local.avgSpeedKmh : (selectedSession?.avgSpeedKmh ?? 0);
    final duration = local.durationSec > 0 ? local.durationSec : (selectedSession?.durationSec ?? 0);
    final metersPerMin = selectedSession?.metersPerMinute ?? (duration <= 0 ? 0 : local.distanceM / (duration / 60.0));
    final rows = [..._rowsForAnalytics(bundle, selectedSession, local, null)]..sort((a, b) => b.maxSpeedKmh.compareTo(a.maxSpeedKmh));
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 132 + bottomSafe),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.95,
          children: [
            _MobileSimpleKpi(icon: Icons.speed_rounded, title: 'Средняя', value: avgSpeed.toStringAsFixed(1), note: 'км/ч'),
            _MobileSimpleKpi(icon: Icons.trending_up_rounded, title: 'Максимум', value: maxSpeed.toStringAsFixed(1), note: 'км/ч'),
            _MobileSimpleKpi(icon: Icons.timer_rounded, title: 'Темп', value: metersPerMin.toStringAsFixed(1), note: 'м/мин'),
            _MobileSimpleKpi(icon: Icons.gps_fixed_rounded, title: 'Точек', value: '${local.speedSamples.length}', note: 'GPS скорость'),
          ],
        ),
        const SizedBox(height: 8),
        _MobileCardShell(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('График скорости', style: TextStyle(color: _AA.text, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('пороги HIR ${hsrThresholdKmh.toStringAsFixed(1)} / SPR ${sprintThresholdKmh.toStringAsFixed(1)} км/ч', style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SizedBox(height: 280, child: CustomPaint(painter: _SpeedPainter(samples: local.speedSamples, hsrThresholdKmh: hsrThresholdKmh, sprintThresholdKmh: sprintThresholdKmh, maxSpeedKmh: maxSpeed), child: const SizedBox.expand())),
          ]),
        ),
        const SizedBox(height: 8),
        _MobileCardShell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Лидеры скорости', style: TextStyle(color: _AA.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const _Empty(icon: Icons.speed_rounded, text: 'После сохранения сессии появятся игроки с максимальной скоростью.')
          else
            for (final r in rows.take(6)) _MobilePlayerRow(row: r, metric: 'Макс. скорость', value: '${r.maxSpeedKmh.toStringAsFixed(1)} км/ч'),
        ])),
      ]),
    );
  }
}

class _MobileHeartDashboard extends StatelessWidget {
  const _MobileHeartDashboard({required this.heartRate, required this.selectedPlayer});
  final _AnalyticsHeartRate heartRate;
  final TrackerPlayerOption? selectedPlayer;

  @override
  Widget build(BuildContext context) {
    if (heartRate.effectiveSamplesCount <= 0 && heartRate.timelineForChart.isEmpty && heartRate.players.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: _MobileCardShell(child: _Empty(icon: Icons.favorite_border_rounded, text: 'По выбранному периоду нет данных Polar H10. Проверьте привязку датчика и время сессии.')),
      );
    }
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 132 + bottomSafe),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _MobileHrChip(label: 'Все', note: '${heartRate.effectiveSamplesCount} HR', active: true),
            for (final p in heartRate.players.take(8)) _MobileHrChip(label: p.playerName, note: '${p.avgBpm.toStringAsFixed(0)} bpm · ${p.samplesCount}', active: false),
          ]),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.95,
          children: [
            _MobileSimpleKpi(icon: Icons.favorite_rounded, title: 'Средний', value: heartRate.effectiveAvgBpm > 0 ? heartRate.effectiveAvgBpm.toStringAsFixed(0) : '—', note: 'bpm'),
            _MobileSimpleKpi(icon: Icons.local_fire_department_rounded, title: 'Максимум', value: heartRate.effectiveMaxBpm > 0 ? '${heartRate.effectiveMaxBpm}' : '—', note: 'bpm'),
            _MobileSimpleKpi(icon: Icons.monitor_heart_rounded, title: 'HR-записи', value: '${heartRate.effectiveSamplesCount}', note: 'точек'),
            _MobileSimpleKpi(icon: Icons.groups_rounded, title: 'Игроки', value: '${heartRate.effectivePlayersCount}', note: 'Polar'),
          ],
        ),
        const SizedBox(height: 8),
        _MobileCardShell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Пульс по времени', style: TextStyle(color: _AA.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          const Text('командные линии Polar H10', style: TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SizedBox(height: 500, child: _AnalyticsHrLineChart(heartRate: heartRate)),
        ])),
        const SizedBox(height: 8),
        _MobileCardShell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Зоны ЧСС', style: TextStyle(color: _AA.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(height: 180, child: _AnalyticsHrZonesPanel(heartRate: heartRate)),
        ])),
      ]),
    );
  }
}

class _MobileTeamDashboard extends StatelessWidget {
  const _MobileTeamDashboard({required this.bundle, required this.selectedSession, required this.local, required this.players, required this.selectedPlayer, required this.onSelectPlayer});
  final _AnalyticsBundle bundle;
  final TrackerSessionModel? selectedSession;
  final _LocalTrackAnalysis local;
  final List<TrackerPlayerOption> players;
  final TrackerPlayerOption? selectedPlayer;
  final ValueChanged<int> onSelectPlayer;

  @override
  Widget build(BuildContext context) {
    final rows = _rowsForAnalytics(bundle, selectedSession, local, selectedPlayer);
    final total = _DayTotal.fromRows(rows, sessionsCount: bundle.sessions.length, fallbackSession: selectedSession, local: local);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 132 + bottomSafe),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _MobileTeamSummaryCard(total: total, selectedField: null, selectedPlayer: selectedPlayer, onOpenSessions: () {}),
        const SizedBox(height: 8),
        _MobileCardShell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Игроки команды', style: TextStyle(color: _AA.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const _Empty(icon: Icons.groups_rounded, text: 'По выбранному периоду нет игроков с данными.')
          else
            for (final r in rows.take(12)) _NoHoverTap(onTap: r.playerId == null ? null : () => onSelectPlayer(r.playerId!), child: _MobilePlayerRow(row: r, metric: 'дистанция ${_dashIfZero(r.distanceM, suffix: ' м')}', value: 'Load ${r.loadScore.toStringAsFixed(0)}')),
        ])),
      ]),
    );
  }
}

class _MobileRatingsDashboard extends StatelessWidget {
  const _MobileRatingsDashboard({required this.bundle, required this.local, required this.teamName, required this.selectedPlayer, required this.selectedSession});
  final _AnalyticsBundle bundle;
  final _LocalTrackAnalysis local;
  final String teamName;
  final TrackerPlayerOption? selectedPlayer;
  final TrackerSessionModel? selectedSession;

  @override
  Widget build(BuildContext context) {
    final rows = _rowsForAnalytics(bundle, selectedSession, local, selectedPlayer);
    final bySpeed = [...rows]..sort((a, b) => b.maxSpeedKmh.compareTo(a.maxSpeedKmh));
    final byLoad = [...rows]..sort((a, b) => b.loadScore.compareTo(a.loadScore));
    final byDistance = [...rows]..sort((a, b) => b.distanceM.compareTo(a.distanceM));
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 132 + bottomSafe),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _MobileRatingBlock(
          title: 'Скорость',
          icon: Icons.speed_rounded,
          rows: bySpeed,
          valueBuilder: (r) => '${r.maxSpeedKmh.toStringAsFixed(1)} км/ч',
          numericBuilder: (r) => r.maxSpeedKmh,
          detailNote: 'максимальная скорость по выбранным сессиям',
        ),
        const SizedBox(height: 8),
        _MobileRatingBlock(
          title: 'Нагрузка',
          icon: Icons.bolt_rounded,
          rows: byLoad,
          valueBuilder: (r) => r.loadScore.toStringAsFixed(0),
          numericBuilder: (r) => r.loadScore,
          detailNote: 'суммарная нагрузка игроков',
        ),
        const SizedBox(height: 8),
        _MobileRatingBlock(
          title: 'Дистанция',
          icon: Icons.route_rounded,
          rows: byDistance,
          valueBuilder: (r) => _meters(r.distanceM),
          numericBuilder: (r) => r.distanceM,
          detailNote: 'общий объём перемещений',
        ),
      ]),
    );
  }
}

class _MobileRatingBlock extends StatelessWidget {
  const _MobileRatingBlock({
    required this.title,
    required this.icon,
    required this.rows,
    required this.valueBuilder,
    required this.numericBuilder,
    required this.detailNote,
  });

  final String title;
  final IconData icon;
  final List<TrackerPlayerLoadRow> rows;
  final String Function(TrackerPlayerLoadRow row) valueBuilder;
  final double Function(TrackerPlayerLoadRow row) numericBuilder;
  final String detailNote;

  void _openDetails(BuildContext context) {
    if (rows.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MobileRatingDetailSheet(
        title: title,
        icon: icon,
        rows: rows,
        valueBuilder: valueBuilder,
        numericBuilder: numericBuilder,
        detailNote: detailNote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _MobileCardShell(
      onTap: rows.isEmpty ? null : () => _openDetails(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _MobileIconBox(icon: icon),
          const SizedBox(width: 6),
          Expanded(child: Text(title, style: const TextStyle(color: _AA.text, fontSize: 14, fontWeight: FontWeight.w700))),
          if (rows.isNotEmpty) const Icon(Icons.chevron_right_rounded, color: _AA.text, size: 22),
        ]),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const _Empty(icon: Icons.leaderboard_rounded, text: 'После сохранения сессии здесь появятся лидеры.')
        else
          for (final r in rows.take(5)) _MobilePlayerRow(row: r, metric: title, value: valueBuilder(r)),
      ]),
    );
  }
}

class _MobileRatingDetailSheet extends StatelessWidget {
  const _MobileRatingDetailSheet({
    required this.title,
    required this.icon,
    required this.rows,
    required this.valueBuilder,
    required this.numericBuilder,
    required this.detailNote,
  });

  final String title;
  final IconData icon;
  final List<TrackerPlayerLoadRow> rows;
  final String Function(TrackerPlayerLoadRow row) valueBuilder;
  final double Function(TrackerPlayerLoadRow row) numericBuilder;
  final String detailNote;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final visibleRows = rows.where((r) => numericBuilder(r) > 0).take(12).toList(growable: false);
    final sourceRows = visibleRows.isNotEmpty ? visibleRows : rows.take(12).toList(growable: false);
    final maxValue = sourceRows.fold<double>(0, (m, r) => math.max(m, numericBuilder(r)));
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(maxHeight: math.min(height * .82, 680)),
          decoration: const BoxDecoration(
            color: _AA.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_AA.sheetRadius)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Row(children: [
                _MobileIconBox(icon: icon),
                const SizedBox(width: 7),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(detailNote, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                ])),
                _NoHoverTap(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(_AA.mobileInnerRadius),
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(_AA.mobileInnerRadius)),
                    child: const Icon(Icons.close_rounded, color: _AA.text, size: 22),
                  ),
                ),
              ]),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  _MobileCardShell(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('График лидеров', style: TextStyle(color: _AA.text, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      if (sourceRows.isEmpty)
                        const _Empty(icon: Icons.leaderboard_rounded, text: 'Нет данных для графика.')
                      else
                        for (final r in sourceRows) ...[
                          _MobileRatingBarRow(
                            row: r,
                            valueText: valueBuilder(r),
                            value: numericBuilder(r),
                            maxValue: maxValue,
                          ),
                          if (r != sourceRows.last) const SizedBox(height: 10),
                        ],
                    ]),
                  ),
                  const SizedBox(height: 8),
                  _MobileCardShell(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Список игроков', style: TextStyle(color: _AA.text, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (rows.isEmpty)
                        const _Empty(icon: Icons.groups_rounded, text: 'Нет игроков с данными.')
                      else
                        for (final r in rows.take(20)) _MobilePlayerRow(row: r, metric: title, value: valueBuilder(r)),
                    ]),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MobileRatingBarRow extends StatelessWidget {
  const _MobileRatingBarRow({required this.row, required this.valueText, required this.value, required this.maxValue});

  final TrackerPlayerLoadRow row;
  final String valueText;
  final double value;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _MobileLeaderAvatar(row: row),
        const SizedBox(width: 7),
        Expanded(child: Text(_leaderShortName(row.playerName), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 11.6, fontWeight: FontWeight.w700))),
        Text(valueText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.green, fontSize: 11.8, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 8,
          color: _AA.line.withOpacity(.72),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: ratio <= 0 ? 0.02 : math.max(.06, ratio),
            child: Container(decoration: BoxDecoration(color: _AA.green, borderRadius: BorderRadius.circular(999))),
          ),
        ),
      ),
    ]);
  }
}

class _MobileIconBox extends StatelessWidget {
  const _MobileIconBox({required this.icon, this.color = _AA.green});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_AA.mobileInnerRadius)), child: Icon(icon, color: color, size: 20));
}

class _MobileModeChip extends StatelessWidget {
  const _MobileModeChip({required this.label, required this.icon, required this.active, required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_AA.mobileInnerRadius),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: active ? _AA.soft : _AA.card, borderRadius: BorderRadius.circular(_AA.mobileInnerRadius), border: Border.all(color: active ? _AA.greenLine : _AA.line)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? _AA.green : _AA.muted, size: 18),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: active ? _AA.green : _AA.text, fontSize: 10.4, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _MobileFilterPill extends StatelessWidget {
  const _MobileFilterPill({required this.label, required this.value, required this.current, required this.onTap});
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: _NoHoverTap(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(_AA.mobileChipRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: active ? _AA.green : _AA.card, borderRadius: BorderRadius.circular(_AA.mobileChipRadius), border: Border.all(color: active ? _AA.green : _AA.line)),
          child: Text(label, style: TextStyle(color: active ? Colors.white : _AA.text, fontSize: 11.2, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _MobileTinyStat extends StatelessWidget {
  const _MobileTinyStat({required this.title, required this.value, required this.note});
  final String title;
  final String value;
  final String note;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _AA.greenSoft, borderRadius: BorderRadius.circular(_AA.mobileInnerRadius)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 13.2, fontWeight: FontWeight.w700)),
      Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _MobileSimpleKpi extends StatelessWidget {
  const _MobileSimpleKpi({required this.icon, required this.title, required this.value, required this.note});
  final IconData icon;
  final String title;
  final String value;
  final String note;
  @override
  Widget build(BuildContext context) => _MobileCardShell(
    padding: const EdgeInsets.all(11),
    child: Row(children: [
      _MobileIconBox(icon: icon),
      const SizedBox(width: 7),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        RichText(maxLines: 1, overflow: TextOverflow.ellipsis, text: TextSpan(children: [
          TextSpan(text: value, style: const TextStyle(color: _AA.text, fontSize: 16, fontWeight: FontWeight.w700)),
          TextSpan(text: ' $note', style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
        ])),
      ])),
    ]),
  );
}

class _MobileHrChip extends StatelessWidget {
  const _MobileHrChip({required this.label, required this.note, required this.active});
  final String label;
  final String note;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(color: active ? _AA.soft : _AA.card, borderRadius: BorderRadius.circular(_AA.mobileInnerRadius), border: Border.all(color: active ? _AA.greenLine : _AA.line)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(active ? Icons.check_circle_rounded : Icons.favorite_border_rounded, size: 16, color: active ? _AA.green : _AA.muted),
      const SizedBox(width: 7),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 130), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _AA.green : _AA.text, fontSize: 11, fontWeight: FontWeight.w700))),
        Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w600)),
      ]),
    ]),
  );
}

class _MobilePlayerRow extends StatelessWidget {
  const _MobilePlayerRow({required this.row, required this.metric, required this.value});
  final TrackerPlayerLoadRow row;
  final String metric;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x0FE6EAF0)))),
    child: Row(children: [
      _MobileLeaderAvatar(row: row),
      const SizedBox(width: 7),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(row.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 11.6, fontWeight: FontWeight.w700)),
        Text(metric, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w600)),
      ])),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.green, fontSize: 12.2, fontWeight: FontWeight.w700)),
    ]),
  );
}

String _dashIfZero(double value, {String suffix = ''}) => value <= 0 ? '—' : '${value.toStringAsFixed(0)}$suffix';


String _leaderShortName(String raw) {
  final parts = raw.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList(growable: false);
  if (parts.isEmpty) return 'Игрок';
  if (parts.length == 1) return parts.first;
  // Если имя уже пришло сокращенным вида «Арсений Б.», оставляем как есть,
  // потому что фамилии в данных уже нет.
  if (parts[1].endsWith('.') && parts[1].length <= 3) return '${parts.first} ${parts[1]}'.trim();
  final first = parts.first;
  final last = parts.last;
  final initial = first.isNotEmpty ? '${first.substring(0, 1)}.' : '';
  return '$last $initial'.trim();
}


class _DaySummaryPanel extends StatelessWidget {
  const _DaySummaryPanel({required this.total, required this.selectedField, required this.selectedPlayer, required this.onOpenSessions});
  final _DayTotal total;
  final TrackerFieldModel? selectedField;
  final TrackerPlayerOption? selectedPlayer;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context) {
    Widget metric(String title, String value, String note, IconData icon) {
      return Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: _AA.soft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AA.line.withOpacity(.58), width: .7),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: _AA.greenSoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _AA.green, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', color: _AA.muted, fontSize: 10.8, fontWeight: FontWeight.w500, height: 1.1)),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', color: _AA.text, fontSize: 16.0, fontWeight: FontWeight.w600, height: 1.05)),
            Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', color: _AA.muted, fontSize: 10.2, fontWeight: FontWeight.w400, height: 1.1)),
          ])),
        ]),
      );
    }

    return _Panel(
      title: 'Командная сводка',
      subtitle: 'итог по выбранным сессиям и дате',
      child: LayoutBuilder(builder: (context, c) {
        final oneColumn = c.maxWidth < 290;
        final tileWidth = oneColumn ? c.maxWidth : (c.maxWidth - 8) / 2;
        final metrics = <Widget>[
          metric('Сессии', '${total.sessionsCount}', 'выбрано', Icons.event_note_rounded),
          metric('Игроки', '${total.playersCount}', 'с данными', Icons.groups_rounded),
          metric('Дистанция', _meters(total.distanceM), 'команда', Icons.route_rounded),
          metric('Макс. скорость', '${total.maxSpeedKmh.toStringAsFixed(1)}', 'км/ч', Icons.speed_rounded),
          metric('Спринты', '${total.sprintCount}', _meters(total.sprintDistanceM), Icons.flash_on_rounded),
          metric('Нагрузка', total.loadScore <= 0 ? '—' : total.loadScore.toStringAsFixed(0), 'суммарная', Icons.bolt_rounded),
        ];
        return SingleChildScrollView(
          primary: false,
          physics: const ClampingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final item in metrics) SizedBox(width: tileWidth, child: item)],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _AA.soft, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                _InfoLine(title: 'Поле', value: selectedField?.title ?? 'не выбрано'),
                _InfoLine(title: 'Фокус игрока', value: selectedPlayer?.name ?? 'вся команда'),
                _InfoLine(title: 'HIR/VHIR', value: _meters(total.hirDistanceM)),
                _InfoLine(title: 'Ускорения / торможения', value: '${total.accelCount} / ${total.decelCount}'),
              ]),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _SmallButton(icon: Icons.assignment_rounded, label: 'Открыть сессии', primary: true, onTap: onOpenSessions),
            ),
          ]),
        );
      }),
    );
  }
}

class _DayRankingsPanel extends StatelessWidget {
  const _DayRankingsPanel({required this.rows});
  final List<TrackerPlayerLoadRow> rows;

  @override
  Widget build(BuildContext context) {
    final distance = [...rows]..sort((a, b) => b.distanceM.compareTo(a.distanceM));
    final speed = [...rows]..sort((a, b) => b.maxSpeedKmh.compareTo(a.maxSpeedKmh));
    final sprint = [...rows]..sort((a, b) => b.sprintCount.compareTo(a.sprintCount));
    final load = [...rows]..sort((a, b) => b.loadScore.compareTo(a.loadScore));
    if (rows.isEmpty) return const _Panel(title: 'Рейтинги дня', subtitle: 'нет обработанных сессий', child: _Empty(icon: Icons.leaderboard_rounded, text: 'После сохранения сессий здесь появятся лидеры по дистанции, скорости, спринтам и нагрузке.'));
    return _Panel(
      title: 'Рейтинги дня',
      subtitle: 'по всем ключевым элементам',
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.35,
        children: [
          _RankingMini(title: 'Дистанция', rows: distance, value: (r) => _meters(r.distanceM), icon: Icons.route_rounded),
          _RankingMini(title: 'Макс. скорость', rows: speed, value: (r) => '${r.maxSpeedKmh.toStringAsFixed(1)} км/ч', icon: Icons.speed_rounded),
          _RankingMini(title: 'Спринты', rows: sprint, value: (r) => '${r.sprintCount} / ${_meters(r.sprintDistanceM)}', icon: Icons.flash_on_rounded),
          _RankingMini(title: 'Нагрузка', rows: load, value: (r) => r.loadScore.toStringAsFixed(0), icon: Icons.bolt_rounded),
        ],
      ),
    );
  }
}

class _RankingMini extends StatelessWidget {
  const _RankingMini({required this.title, required this.rows, required this.value, required this.icon});
  final String title;
  final List<TrackerPlayerLoadRow> rows;
  final String Function(TrackerPlayerLoadRow row) value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AA.line.withOpacity(.62), width: .7),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(color: _AA.soft, border: Border(bottom: BorderSide(color: _AA.line.withOpacity(.65), width: .7))),
          child: Row(children: [
            Container(width: 26, height: 26, decoration: BoxDecoration(color: _AA.greenSoft, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: _AA.green)),
            const SizedBox(width: 7),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', color: _AA.text, fontSize: 12.2, fontWeight: FontWeight.w600))),
          ]),
        ),
        Expanded(child: ListView.builder(
          itemCount: math.min(5, rows.length),
          itemBuilder: (context, i) {
            final r = rows[i];
            return Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _AA.line.withOpacity(.52), width: .6))),
              child: Row(children: [
                SizedBox(width: 18, child: Text('${i + 1}', style: const TextStyle(fontFamily: 'Inter', color: _AA.muted, fontSize: 10.8, fontWeight: FontWeight.w600))),
                const SizedBox(width: 6),
                Expanded(child: Text(r.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', color: _AA.text, fontSize: 11.2, fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Text(value(r), style: const TextStyle(fontFamily: 'Inter', color: _AA.green, fontSize: 11.2, fontWeight: FontWeight.w600)),
              ]),
            );
          },
        )),
      ]),
    );
  }
}


class _MapTab extends StatefulWidget {
  const _MapTab({
    required this.points,
    required this.localPoints,
    required this.field,
    required this.selectedPlayer,
    required this.selectedSession,
    required this.comparisonRows,
    required this.selectedPlayerIds,
    required this.heatMode,
    required this.onHeatModeChanged,
    required this.sprintThresholdKmh,
    required this.hsrThresholdKmh,
    required this.showSprintArrows,
    required this.mapRotationDeg,
    required this.onOpenCalibration,
  });

  final List<TrackerHeatPoint> points;
  final List<ActionTrackerGpsPoint> localPoints;
  final TrackerFieldModel? field;
  final TrackerPlayerOption? selectedPlayer;
  final TrackerSessionModel? selectedSession;
  final List<TrackerPlayerLoadRow> comparisonRows;
  final Set<int> selectedPlayerIds;
  final bool heatMode;
  final ValueChanged<bool> onHeatModeChanged;
  final double sprintThresholdKmh;
  final double hsrThresholdKmh;
  final bool showSprintArrows;
  final double mapRotationDeg;
  final VoidCallback onOpenCalibration;

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  String _activityFilter = 'all';
  String _detailPanelMode = 'chart';
  _MapPointInfo? _selectedPoint;

  void _deferMouseSafe(FutureOr<void> Function() action, {int milliseconds = 160}) {
    Timer(Duration(milliseconds: milliseconds), () async {
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await action();
    });
  }

  List<ActionTrackerGpsPoint> get _visiblePoints {
    if (widget.heatMode) return const <ActionTrackerGpsPoint>[];
    return widget.localPoints;
  }

  @override
  Widget build(BuildContext context) {
    final visiblePoints = _visiblePoints;
    final local = _LocalTrackAnalysis.fromPoints(widget.localPoints, sprintThresholdKmh: widget.sprintThresholdKmh, hsrThresholdKmh: widget.hsrThresholdKmh);
    final sprintSegments = _SprintSegment.fromPoints(widget.localPoints, thresholdKmh: widget.sprintThresholdKmh);
    final heatPoints = widget.points.isNotEmpty ? widget.points : _heatmapFromGpsStatic(widget.localPoints, widget.field);
    final activityLabel = _activityFilterLabel(_activityFilter);
    final chartSpeedSamples = _activityFilter == 'all'
        ? local.speedSamples
        : _activitySpeedSamples(widget.localPoints, _activityFilter, widget.sprintThresholdKmh, hsrThresholdKmh: widget.hsrThresholdKmh);
    final chartMaxSpeed = chartSpeedSamples.fold<double>(0.0, (value, sample) => math.max(value, sample).toDouble());
    final timeRange = _pointsTimeRange(widget.localPoints);
    final comparisonMode = widget.selectedPlayerIds.length > 1 && widget.comparisonRows.length > 1;

    final mapPanel = _Panel(
      title: widget.heatMode ? 'Тепловая карта' : 'Карта активности',
      subtitle: widget.points.isEmpty && widget.localPoints.isEmpty
          ? 'нет точек выбранной сессии'
          : '${widget.localPoints.length} GPS · $activityLabel · $timeRange · ${sprintSegments.length} спринтов',
      child: Column(children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(color: Colors.white),
          child: Row(children: [
            _MapModeButton(label: 'Карта активности', icon: Icons.timeline_rounded, active: !widget.heatMode, onTap: () => widget.onHeatModeChanged(false)),
            _MapModeButton(label: 'Тепловая карта', icon: Icons.local_fire_department_rounded, active: widget.heatMode, onTap: () => widget.onHeatModeChanged(true)),
            const Spacer(),
            _SmallButton(icon: Icons.open_in_full_rounded, label: 'Расширить', onTap: _openExpandedMap),
          ]),
        ),
        if (!widget.heatMode)
          Container(
            height: 46,
            decoration: const BoxDecoration(color: Colors.white),
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5), children: [
              _ActivityFilterChip(label: 'Все', value: 'all', current: _activityFilter, onTap: _setFilter),
              _ActivityFilterChip(label: 'Ходьба', value: 'walk', current: _activityFilter, onTap: _setFilter),
              _ActivityFilterChip(label: 'Бег', value: 'run', current: _activityFilter, onTap: _setFilter),
              _ActivityFilterChip(label: 'Высокая', value: 'hir', current: _activityFilter, onTap: _setFilter),
              _ActivityFilterChip(label: 'Спринт', value: 'sprint', current: _activityFilter, onTap: _setFilter),
              _ActivityFilterChip(label: 'Повороты', value: 'turn', current: _activityFilter, onTap: _setFilter),
            ]),
          ),
        Expanded(
          child: _PitchViewport(
            painter: _ActionPitchPainter(
              heat: widget.heatMode ? heatPoints : const <TrackerHeatPoint>[],
              local: widget.heatMode ? const <ActionTrackerGpsPoint>[] : visiblePoints,
              field: widget.field,
              sprintThresholdKmh: widget.sprintThresholdKmh,
              hsrThresholdKmh: widget.hsrThresholdKmh,
              activityFilter: _activityFilter,
              showSprintArrows: widget.showSprintArrows,
              mapRotationDeg: widget.mapRotationDeg,
            ),
            onTapDown: widget.heatMode
                ? null
                : (localPosition, mapSize) {
                    final tappablePoints = _filterActivityPoints(visiblePoints, _activityFilter, widget.sprintThresholdKmh, hsrThresholdKmh: widget.hsrThresholdKmh);
                    final info = _nearestPointInfo(localPosition, mapSize, tappablePoints, widget.field, widget.hsrThresholdKmh, widget.sprintThresholdKmh);
                    if (info != null) {
                      _deferMouseSafe(() {
                        if (mounted) setState(() => _selectedPoint = info);
                      }, milliseconds: 70);
                    }
                  },
          ),
        ),
      ]),
    );

    Widget chartContent() => Column(children: [
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _AA.line))),
            child: Row(children: [
              Icon(_activityFilterIcon(_activityFilter), color: _AA.green, size: 15),
              const SizedBox(width: 6),
              Expanded(child: Text('Фильтр: $activityLabel · ${chartSpeedSamples.length} точ. · $timeRange', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700))),
              Text(chartMaxSpeed > 0 ? 'max ${chartMaxSpeed.toStringAsFixed(1)} км/ч' : 'нет скорости', style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
            ]),
          ),
          Expanded(
            flex: 7,
            child: CustomPaint(
              painter: _SpeedPainter(
                samples: chartSpeedSamples,
                hsrThresholdKmh: widget.hsrThresholdKmh,
                sprintThresholdKmh: widget.sprintThresholdKmh,
                maxSpeedKmh: chartMaxSpeed,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Container(height: 1, color: _AA.line),
          Expanded(
            flex: comparisonMode ? 5 : 4,
            child: comparisonMode
                ? _PlayerComparisonPanel(rows: widget.comparisonRows)
                : _SpeedZonesPanel(
                    hsrThresholdKmh: widget.hsrThresholdKmh,
                    sprintThresholdKmh: widget.sprintThresholdKmh,
                    maxSpeedKmh: chartMaxSpeed,
                    speedSamples: chartSpeedSamples,
                  ),
          ),
        ]);

    Widget infoContent() => _selectedPoint == null
        ? Column(children: [
            _InfoLine(title: 'Игроки', value: widget.selectedPlayerIds.length > 1 ? '${widget.selectedPlayerIds.length} игрока для сравнения' : (widget.selectedPlayer?.name ?? widget.selectedSession?.playerName ?? 'Команда')),
            _InfoLine(title: 'Сессия', value: widget.selectedSession == null ? 'период / Live' : '#${widget.selectedSession!.id}'),
            _InfoLine(title: 'Время', value: timeRange),
            _InfoLine(title: 'Фильтр карты', value: activityLabel),
            _InfoLine(title: 'Поле', value: widget.field?.title ?? 'Не выбрано'),
            _InfoLine(title: 'Размер', value: widget.field == null ? '105×68 м' : '${widget.field!.lengthM.toStringAsFixed(0)}×${widget.field!.widthM.toStringAsFixed(0)} м'),
            _InfoLine(title: 'GPS-точек', value: '${widget.localPoints.length}'),
            _InfoLine(title: 'Поворотов', value: '${_turnPoints(widget.localPoints).length}'),
            _InfoLine(title: 'Уск./торм.', value: '${local.accelCount}/${local.decelCount}'),
            _InfoLine(title: 'Дистанция', value: _meters(local.distanceM)),
            _InfoLine(title: 'Max скорость', value: '${local.maxSpeedKmh.toStringAsFixed(1)} км/ч'),
            const Spacer(),
            _SmallButton(icon: Icons.map_rounded, label: 'Открыть калибровку', onTap: widget.onOpenCalibration),
          ])
        : _SelectedMapPointCard(info: _selectedPoint!, onClear: () => setState(() => _selectedPoint = null));

    final chartPanel = _Panel(
      title: widget.heatMode ? 'Плотность и зоны' : 'График скорости · $activityLabel',
      subtitle: widget.heatMode ? 'точки тепловой карты и распределение' : '$timeRange · график меняется вместе с фильтром карты',
      child: chartContent(),
    );

    final infoPanel = _Panel(
      title: _selectedPoint == null ? 'Поле, сессия и точка' : 'Выбранный отрезок',
      subtitle: widget.field?.title ?? 'поле не выбрано',
      child: infoContent(),
    );

    final detailPanel = _Panel(
      title: _detailPanelMode == 'chart'
          ? (widget.heatMode ? 'Плотность и зоны' : 'График скорости · $activityLabel')
          : (_selectedPoint == null ? 'Поле, сессия и точка' : 'Выбранный отрезок'),
      subtitle: _detailPanelMode == 'chart'
          ? (widget.heatMode ? 'тепловая плотность и зоны' : '$timeRange · выбранный фильтр карты')
          : (widget.field?.title ?? 'поле не выбрано'),
      child: Column(children: [
        Container(
          height: 32,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _MapModeButton(label: 'График', icon: Icons.show_chart_rounded, active: _detailPanelMode == 'chart', onTap: () => setState(() => _detailPanelMode = 'chart')),
            _MapModeButton(label: _selectedPoint == null ? 'Сессия' : 'Точка', icon: Icons.info_outline_rounded, active: _detailPanelMode == 'info', onTap: () => setState(() => _detailPanelMode = 'info')),
          ]),
        ),
        Expanded(child: _detailPanelMode == 'chart' ? chartContent() : infoContent()),
      ]),
    );

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;

      if (width >= 1040) {
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 7, child: mapPanel),
            const SizedBox(width: 7),
            Expanded(flex: 4, child: detailPanel),
          ]),
        );
      }

      if (width >= 720) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 6, child: mapPanel),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: detailPanel),
          ]),
        );
      }

      return ListView(primary: false, padding: const EdgeInsets.all(10), children: [
        SizedBox(height: 280, child: mapPanel),
        const SizedBox(height: 10),
        SizedBox(height: 235, child: chartPanel),
        const SizedBox(height: 10),
        SizedBox(height: 245, child: infoPanel),
      ]);
    });
  }

  void _setFilter(String value) {
    setState(() {
      _activityFilter = value;
      _selectedPoint = null;
    });
  }

  void _openExpandedMap() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        backgroundColor: Colors.white,
        child: SizedBox(
          width: 1100,
          height: 760,
          child: Column(children: [
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _AA.line))),
              child: Row(children: [
                Icon(widget.heatMode ? Icons.local_fire_department_rounded : Icons.timeline_rounded, color: _AA.green, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.heatMode ? 'Тепловая карта — полный экран' : 'Карта активности — полный экран', style: const TextStyle(color: _AA.text, fontSize: 12, fontWeight: FontWeight.w700))),
                _NoHoverTap(onTap: () => _deferMouseSafe(() { if (context.mounted) Navigator.pop(context); }), child: const SizedBox(width: 32, height: 32, child: Icon(Icons.close_rounded, size: 18))),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _PitchViewport(
                  painter: _ActionPitchPainter(
                    heat: widget.heatMode ? (widget.points.isNotEmpty ? widget.points : _heatmapFromGpsStatic(widget.localPoints, widget.field)) : const <TrackerHeatPoint>[],
                    local: widget.heatMode ? const <ActionTrackerGpsPoint>[] : _visiblePoints,
                    field: widget.field,
                    sprintThresholdKmh: widget.sprintThresholdKmh,
                    hsrThresholdKmh: widget.hsrThresholdKmh,
                    activityFilter: _activityFilter,
                    showSprintArrows: widget.showSprintArrows,
                    mapRotationDeg: widget.mapRotationDeg,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ActivityFilterChip extends StatelessWidget {
  const _ActivityFilterChip({required this.label, required this.value, required this.current, required this.onTap});
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
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _AA.greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? _AA.greenLine : _AA.line.withOpacity(.65),
              width: .8,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              label,
              style: TextStyle(
                color: active ? _AA.text : _AA.muted,
                fontSize: 11.2,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: _AA.green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _MapPointInfo {
  const _MapPointInfo({required this.index, required this.speedKmh, required this.distanceM, required this.accelMps2, required this.activity, required this.position, required this.timeLabel});
  final int index;
  final double speedKmh;
  final double distanceM;
  final double accelMps2;
  final String activity;
  final Offset position;
  final String timeLabel;
}

class _SelectedMapPointCard extends StatelessWidget {
  const _SelectedMapPointCard({required this.info, required this.onClear});
  final _MapPointInfo info;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _InfoLine(title: 'Отрезок', value: '#${info.index}'),
      _InfoLine(title: 'Тип', value: info.activity),
      _InfoLine(title: 'Время', value: info.timeLabel),
      _InfoLine(title: 'Скорость', value: '${info.speedKmh.toStringAsFixed(1)} км/ч'),
      _InfoLine(title: 'Дистанция', value: '${info.distanceM.toStringAsFixed(1)} м'),
      _InfoLine(title: 'Ускорение', value: '${info.accelMps2.toStringAsFixed(2)} м/с²'),
      _InfoLine(title: 'Позиция', value: '${info.position.dx.toStringAsFixed(1)} / ${info.position.dy.toStringAsFixed(1)}'),
      const Spacer(),
      _SmallButton(icon: Icons.close_rounded, label: 'Снять выбор', onTap: onClear),
    ]);
  }
}

bool _segmentBreaks(ActionTrackerGpsPoint a, ActionTrackerGpsPoint b) {
  if (b.breakBefore) return true;
  if (a.playerId != null && b.playerId != null && a.playerId != b.playerId) return true;
  if (a.liveSessionId != null && b.liveSessionId != null && a.liveSessionId != b.liveSessionId) return true;
  if (a.sessionId != null && b.sessionId != null && a.sessionId != b.sessionId) return true;
  return false;
}

bool _segmentMatchesActivity(double speed, String filter, {double hsrThresholdKmh = 14.0, double sprintThresholdKmh = 18.0}) {
  if (filter == 'all') return true;
  if (speed <= 0) return false;
  if (filter == 'walk') return speed < 7.0;
  if (filter == 'run') return speed >= 7.0 && speed < hsrThresholdKmh;
  if (filter == 'hir') return speed >= hsrThresholdKmh && speed < sprintThresholdKmh;
  if (filter == 'sprint') return speed >= sprintThresholdKmh;
  if (filter == 'turn') return false;
  return true;
}

List<ActionTrackerGpsPoint> _filterActivityPoints(List<ActionTrackerGpsPoint> points, String filter, double sprintThresholdKmh, {double hsrThresholdKmh = 14.0}) {
  if (filter == 'all' || points.length < 2) return points;
  final turns = _turnPoints(points).toSet();
  final out = <ActionTrackerGpsPoint>[];
  double? prevSpeed;
  void addPoint(ActionTrackerGpsPoint p) {
    if (out.isEmpty || !identical(out.last, p)) out.add(p);
  }
  for (var i = 1; i < points.length; i++) {
    if (_segmentBreaks(points[i - 1], points[i])) { prevSpeed = null; continue; }
    final speed = _segmentSpeed(points, i);
    final acc = prevSpeed == null ? 0.0 : ((speed - prevSpeed) / 3.6);
    prevSpeed = speed <= 0 ? null : speed;
    var keep = false;
    if (filter == 'walk') keep = speed > 0 && speed < 7;
    if (filter == 'run') keep = speed >= 7 && speed < hsrThresholdKmh;
    if (filter == 'hir') keep = speed >= hsrThresholdKmh && speed < sprintThresholdKmh;
    if (filter == 'sprint') keep = speed >= sprintThresholdKmh;
    if (filter == 'turn') keep = turns.contains(i);
    if (filter == 'accel') keep = acc >= 1.0;
    if (keep) {
      // Важно: рисуем именно подходящий отрезок prev->current, а не соединяем
      // все выбранные точки одной длинной диагональю.
      addPoint(points[i - 1]);
      addPoint(points[i]);
    }
  }
  return out.isEmpty ? <ActionTrackerGpsPoint>[] : out;
}

String _activityFilterLabel(String filter) {
  switch (filter) {
    case 'walk':
      return 'Ходьба';
    case 'run':
      return 'Бег';
    case 'hir':
      return 'Высокая';
    case 'sprint':
      return 'Спринт';
    case 'turn':
      return 'Повороты';
    default:
      return 'Все';
  }
}

IconData _activityFilterIcon(String filter) {
  switch (filter) {
    case 'walk':
      return Icons.directions_walk_rounded;
    case 'run':
      return Icons.directions_run_rounded;
    case 'hir':
      return Icons.local_fire_department_rounded;
    case 'sprint':
      return Icons.flash_on_rounded;
    case 'turn':
      return Icons.change_circle_rounded;
    default:
      return Icons.timeline_rounded;
  }
}

List<double> _activitySpeedSamples(List<ActionTrackerGpsPoint> points, String filter, double sprintThresholdKmh, {double hsrThresholdKmh = 14.0}) {
  if (points.length < 2) return const <double>[];
  final turns = _turnPoints(points).toSet();
  final out = <double>[];
  for (var i = 1; i < points.length; i++) {
    if (_segmentBreaks(points[i - 1], points[i])) continue;
    final speed = _segmentSpeed(points, i);
    if (!speed.isFinite || speed <= 0) continue;
    final keep = filter == 'turn'
        ? turns.contains(i)
        : _segmentMatchesActivity(speed, filter, hsrThresholdKmh: hsrThresholdKmh, sprintThresholdKmh: sprintThresholdKmh);
    if (keep) out.add(speed);
  }
  return out;
}

String _formatPointTime(int timeMs) {
  if (timeMs <= 0) return 'без времени';
  final dt = DateTime.fromMillisecondsSinceEpoch(timeMs);
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}

String _pointsTimeRange(List<ActionTrackerGpsPoint> points) {
  final times = points.map((p) => p.timeMs).where((v) => v > 0).toList(growable: false)..sort();
  if (times.isEmpty) return 'время не записано';
  final first = _formatPointTime(times.first);
  final last = _formatPointTime(times.last);
  return first == last ? first : '$first–$last';
}

double _segmentSpeed(List<ActionTrackerGpsPoint> points, int i) {
  if (i <= 0 || i >= points.length) return 0.0;
  final a = points[i - 1];
  final b = points[i];
  if (_segmentBreaks(a, b)) return 0.0;
  final stored = b.speedKmh;
  if (stored != null && stored.isFinite && stored > 0 && stored <= 45) return stored;
  final rawDtMs = (b.timeMs - a.timeMs).abs();
  final dtMs = rawDtMs <= 0 ? 1000 : rawDtMs;
  if (dtMs > 60000) return 0.0;
  final d = (b.distanceDeltaM != null && b.distanceDeltaM!.isFinite && b.distanceDeltaM! > 0 && b.distanceDeltaM! <= 80)
      ? b.distanceDeltaM!
      : _LocalTrackAnalysis._distanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);
  if (d <= 0 || d > 80) return 0.0;
  final speed = (d / (dtMs / 1000.0)) * 3.6;
  return speed.isFinite && speed > 0 ? math.min(44.0, speed) : 0.0;
}

_MapPointInfo? _nearestPointInfo(Offset tap, Size size, List<ActionTrackerGpsPoint> points, TrackerFieldModel? field, double hsrThresholdKmh, double sprintThresholdKmh) {
  if (points.isEmpty) return null;
  final bounds = points.length > 1 ? _Bounds.fromGps(points) : null;
  final useFieldProjection = _shouldUseFieldProjection(points, field);
  var bestIndex = -1;
  var bestDistance = double.infinity;
  Offset? bestOffset;
  for (var i = 0; i < points.length; i++) {
    final offset = _projectGpsForSize(points[i], size, field, bounds, useFieldProjection: useFieldProjection);
    final d = (offset - tap).distance;
    if (d < bestDistance) {
      bestDistance = d;
      bestIndex = i;
      bestOffset = offset;
    }
  }
  if (bestIndex < 0 || bestOffset == null || bestDistance > 28) return null;
  final speed = _segmentSpeed(points, bestIndex);
  final dist = bestIndex <= 0 ? 0.0 : _LocalTrackAnalysis._distanceMeters(points[bestIndex - 1].latitude, points[bestIndex - 1].longitude, points[bestIndex].latitude, points[bestIndex].longitude);
  final prevSpeed = bestIndex <= 1 ? speed : _segmentSpeed(points, bestIndex - 1);
  final dtMs = bestIndex <= 0 ? 1000 : (points[bestIndex].timeMs - points[bestIndex - 1].timeMs).abs();
  final accel = ((speed - prevSpeed) / 3.6) / ((dtMs <= 0 ? 1000 : dtMs) / 1000.0);
  final activity = speed >= sprintThresholdKmh ? 'спринт' : (speed >= hsrThresholdKmh ? 'высокая интенсивность' : (speed >= 7 ? 'бег' : 'ходьба'));
  return _MapPointInfo(index: bestIndex, speedKmh: speed, distanceM: dist, accelMps2: accel.isFinite ? accel : 0.0, activity: activity, position: bestOffset, timeLabel: _formatPointTime(points[bestIndex].timeMs));
}

Offset _projectGpsForSize(
  ActionTrackerGpsPoint p,
  Size size,
  TrackerFieldModel? field,
  _Bounds? bounds, {
  bool useFieldProjection = true,
}) {
  if (useFieldProjection) {
    final raw = TrackerPitchProjector.projectGps(field, latitude: p.latitude, longitude: p.longitude);
    if (raw != null) {
      return _fitPointToPitch(Offset(raw.clampedNx * size.width, raw.clampedNy * size.height), size);
    }
  }
  if (bounds != null) return _fitPointToPitch(bounds.project(p, size), size);
  return Offset(size.width / 2, size.height / 2);
}

bool _shouldUseFieldProjection(List<ActionTrackerGpsPoint> points, TrackerFieldModel? field) {
  if (field == null || !field.hasCalibration || points.length < 2) return false;
  final xs = <double>[];
  final ys = <double>[];
  var inside = 0;
  var clipped = 0;
  for (final p in points) {
    final q = TrackerPitchProjector.projectGps(field, latitude: p.latitude, longitude: p.longitude);
    if (q == null) continue;
    xs.add(q.nx);
    ys.add(q.ny);
    if (q.isInside) inside++;
    if (q.nx < 0 || q.nx > 1 || q.ny < 0 || q.ny > 1) clipped++;
  }
  if (xs.length < 2) return false;
  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  final spreadX = (maxX - minX).abs();
  final spreadY = (maxY - minY).abs();
  final insideRatio = inside / xs.length;
  final clippedRatio = clipped / xs.length;
  // Если калибровка отправляет все GPS-точки в один угол/за границу,
  // используем GPS-bounds. Так карта не схлопывается справа/слева.
  if (spreadX < .018 && spreadY < .018) return false;
  if (insideRatio < .35 && clippedRatio > .45) return false;
  return true;
}

Offset _fitPointToPitch(Offset raw, Size size) {
  final inner = _pitchInnerRect(size);
  final nx = size.width <= 0 ? .5 : (raw.dx / size.width).clamp(0.0, 1.0);
  final ny = size.height <= 0 ? .5 : (raw.dy / size.height).clamp(0.0, 1.0);
  return Offset(inner.left + nx * inner.width, inner.top + ny * inner.height);
}

Rect _pitchInnerRect(Size size) => Rect.fromLTWH(10, 10, math.max(1.0, size.width - 20), math.max(1.0, size.height - 20));

Rect _analyticsPitchFrame(Size size) {
  const aspect = 105.0 / 68.0;
  final maxWidth = math.max(1.0, size.width);
  final maxHeight = math.max(1.0, size.height);
  var width = maxWidth;
  var height = width / aspect;
  if (height > maxHeight) {
    height = maxHeight;
    width = height * aspect;
  }
  return Rect.fromLTWH((maxWidth - width) / 2, (maxHeight - height) / 2, width, height);
}

class _PitchViewport extends StatelessWidget {
  const _PitchViewport({required this.painter, this.onTapDown});
  final CustomPainter painter;
  final void Function(Offset localPosition, Size paintSize)? onTapDown;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final frame = _analyticsPitchFrame(Size(constraints.maxWidth, constraints.maxHeight));
      final pitch = Positioned(
        left: frame.left,
        top: frame.top,
        width: frame.width,
        height: frame.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_AA.tabletInnerRadius),
          child: CustomPaint(painter: painter, child: const SizedBox.expand()),
        ),
      );
      final content = Stack(children: [pitch]);
      if (onTapDown == null) return content;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final p = details.localPosition - frame.topLeft;
          if (p.dx < 0 || p.dy < 0 || p.dx > frame.width || p.dy > frame.height) return;
          onTapDown!(p, frame.size);
        },
        child: content,
      );
    });
  }
}

class _SprintsTab extends StatelessWidget {
  const _SprintsTab({
    required this.bundle,
    required this.local,
    required this.localPoints,
    required this.selectedSession,
    required this.sprintThresholdKmh,
    required this.hsrThresholdKmh,
    required this.showSprintArrows,
    required this.mapRotationDeg,
    required this.onOpenInsight,
  });

  final _AnalyticsBundle bundle;
  final _LocalTrackAnalysis local;
  final List<ActionTrackerGpsPoint> localPoints;
  final TrackerSessionModel? selectedSession;
  final double sprintThresholdKmh;
  final double hsrThresholdKmh;
  final bool showSprintArrows;
  final double mapRotationDeg;
  final ValueChanged<_CoachInsight> onOpenInsight;

  @override
  Widget build(BuildContext context) {
    final players = [..._rowsForAnalytics(bundle, selectedSession, local, null)]..sort((a, b) => b.sprintCount.compareTo(a.sprintCount));
    final sprintCount = local.sprintCount > 0 ? local.sprintCount : (selectedSession?.sprintCount ?? 0);
    final sprintDistance = local.sprintDistanceM > 0 ? local.sprintDistanceM : (selectedSession?.sprintDistanceM ?? 0);
    final hirDistance = local.hsrDistanceM > 0 ? local.hsrDistanceM : ((selectedSession?.hirDistanceM ?? 0) + (selectedSession?.vhirDistanceM ?? 0));
    final maxSpeed = local.maxSpeedKmh > 0 ? local.maxSpeedKmh : (selectedSession?.maxSpeedKmh ?? 0);
    final segments = _SprintSegment.fromPoints(localPoints, thresholdKmh: sprintThresholdKmh);

    _CoachInsight sprintInsight(String title, IconData icon, List<_CoachInsightMetric> metrics, List<String> bullets, {Color accent = _AA.red}) {
      return _CoachInsight(
        title: title,
        subtitle: '${selectedSession?.playerName ?? 'Команда'} · порог ${sprintThresholdKmh.toStringAsFixed(1)} км/ч',
        icon: icon,
        accent: accent,
        metrics: metrics,
        bullets: bullets,
        footer: 'Правая панель работает как тренерский инспектор: нажмите карту, KPI или игрока — детали откроются здесь, без отдельного окна и без потери контекста графика.',
      );
    }

    void openPlayer(TrackerPlayerLoadRow p) {
      onOpenInsight(_CoachInsight(
        title: p.playerName,
        subtitle: 'личный вклад в спринты и интенсивность',
        icon: Icons.person_rounded,
        accent: _AA.red,
        metrics: [
          _CoachInsightMetric('Спринты', '${p.sprintCount}', 'рывки'),
          _CoachInsightMetric('SPR dist.', _meters(p.sprintDistanceM), 'дистанция'),
          _CoachInsightMetric('Max', '${p.maxSpeedKmh.toStringAsFixed(1)}', 'км/ч'),
          _CoachInsightMetric('Load', p.loadScore.toStringAsFixed(0), 'нагрузка'),
        ],
        bullets: [
          'Если спринтов много, а максимальная скорость низкая — игрок часто входит в порог, но не разгоняется до пика.',
          'Если скорость высокая, а спринтов мало — был один-два коротких рывка, стоит проверить карту.',
          'Сравнивайте с HIR/VHIR: это показывает, была ли интенсивная работа до самих спринтов.',
        ],
      ));
    }

    final mapPanel = _Panel(
      title: 'Спринты на карте',
      subtitle: '${segments.length} отрезков · нажмите для расшифровки',
      child: _NoHoverTap(
        onTap: () => onOpenInsight(sprintInsight('Спринты на карте', Icons.map_rounded, [
          _CoachInsightMetric('Отрезки', '${segments.length}', 'на поле'),
          _CoachInsightMetric('Порог SPR', '${sprintThresholdKmh.toStringAsFixed(1)}', 'км/ч'),
          _CoachInsightMetric('Дистанция', _meters(sprintDistance), 'SPR'),
          _CoachInsightMetric('Пик', maxSpeed.toStringAsFixed(1), 'км/ч'),
        ], [
          'На карте остаются только отрезки, где скорость выше спринтового порога.',
          'Стрелки показывают направление рывка, чтобы тренер видел, куда именно игрок ускорялся.',
          'Если точки собрались в угол, нужна калибровка поля или проверка GPS-bounds.',
        ])),
        child: CustomPaint(
          painter: _ActionPitchPainter(
            heat: const <TrackerHeatPoint>[],
            local: localPoints,
            field: null,
            sprintThresholdKmh: sprintThresholdKmh,
            hsrThresholdKmh: hsrThresholdKmh,
            activityFilter: 'sprint',
            showSprintArrows: showSprintArrows,
            mapRotationDeg: mapRotationDeg,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    final intensityPanel = _Panel(
      title: 'Спринты и интенсивная работа',
      subtitle: 'линия скорости + реальные пороги HIR/SPR',
      child: Column(children: [
        SizedBox(height: 58, child: Row(children: [
          Expanded(child: _MiniNumber(title: 'Спринты', value: '$sprintCount', note: _meters(sprintDistance), onTap: () => onOpenInsight(sprintInsight('Количество спринтов', Icons.flash_on_rounded, [
            _CoachInsightMetric('Спринты', '$sprintCount', 'выше порога'),
            _CoachInsightMetric('SPR dist.', _meters(sprintDistance), 'сумма'),
            _CoachInsightMetric('Отрезки', '${segments.length}', 'на карте'),
            _CoachInsightMetric('Порог', '${sprintThresholdKmh.toStringAsFixed(1)}', 'км/ч'),
          ], ['Один спринт считается как вход в зону выше порога с гистерезисом, чтобы не дробить один рывок на несколько.', 'Красная линия на графике — именно этот порог.', 'Если спринтов 0, но HIR высокий — игрок работал интенсивно, но не достиг спринта.'])))),
          Expanded(child: _MiniNumber(title: 'HIR/VHIR', value: _meters(hirDistance), note: '>${hsrThresholdKmh.toStringAsFixed(1)} км/ч', onTap: () => onOpenInsight(sprintInsight('HIR/VHIR до спринта', Icons.local_fire_department_rounded, [
            _CoachInsightMetric('HIR/VHIR', _meters(hirDistance), 'метры'),
            _CoachInsightMetric('HIR порог', '${hsrThresholdKmh.toStringAsFixed(1)}', 'км/ч'),
            _CoachInsightMetric('SPR порог', '${sprintThresholdKmh.toStringAsFixed(1)}', 'км/ч'),
            _CoachInsightMetric('Спринты', '$sprintCount', 'рывки'),
          ], ['Оранжевая зона показывает интенсивную работу до спринта.', 'Для тренера это важно: игрок может давать нагрузку без выхода на максимум.', 'Сравните HIR с пульсом — так видно внутреннюю цену интенсивности.'], accent: _AA.orange)))),
          Expanded(child: _MiniNumber(title: 'Макс.', value: maxSpeed.toStringAsFixed(1), note: 'км/ч', onTap: () => onOpenInsight(sprintInsight('Пиковая скорость', Icons.speed_rounded, [
            _CoachInsightMetric('Max', maxSpeed.toStringAsFixed(1), 'км/ч'),
            _CoachInsightMetric('SPR', '${sprintThresholdKmh.toStringAsFixed(1)}', 'порог'),
            _CoachInsightMetric('Разница', (maxSpeed - sprintThresholdKmh).toStringAsFixed(1), 'км/ч'),
            _CoachInsightMetric('Точек', '${local.speedSamples.length}', 'GPS'),
          ], ['График теперь не растягивается из-за одиночных GPS-выбросов.', 'Если пик близко к 18 км/ч, линия будет возле красного порога, а не визуально внизу.', 'Проверяйте повторяемость пиков, а не только одно максимальное значение.'], accent: _AA.blue)))),
          Expanded(child: _MiniNumber(title: 'Уск/торм', value: '${local.accelCount}/${local.decelCount}', note: 'механика', onTap: () => onOpenInsight(sprintInsight('Механика рывков', Icons.compare_arrows_rounded, [
            _CoachInsightMetric('Ускорения', '${local.accelCount}', 'кол-во'),
            _CoachInsightMetric('Торможения', '${local.decelCount}', 'кол-во'),
            _CoachInsightMetric('SPR dist.', _meters(sprintDistance), 'метры'),
            _CoachInsightMetric('Load', (sprintDistance * .35 + hirDistance * .18 + (local.accelCount + local.decelCount) * 2.5).toStringAsFixed(0), 'оценка'),
          ], ['Ускорения и торможения объясняют нагрузку при малой дистанции.', 'Для игровых упражнений этот блок часто важнее общего пробега.', 'Если торможений сильно больше — проверьте усталость и качество смен направления.'], accent: _AA.blue)))),
        ])),
        Expanded(child: _NoHoverTap(
          onTap: () => onOpenInsight(sprintInsight('График спринтов', Icons.show_chart_rounded, [
            _CoachInsightMetric('Точек', '${local.speedSamples.length}', 'скорость'),
            _CoachInsightMetric('SPR порог', '${sprintThresholdKmh.toStringAsFixed(1)}', 'км/ч'),
            _CoachInsightMetric('HIR порог', '${hsrThresholdKmh.toStringAsFixed(1)}', 'км/ч'),
            _CoachInsightMetric('Max', maxSpeed.toStringAsFixed(1), 'км/ч'),
          ], ['Красная линия — спринт, оранжевая — высокая интенсивность.', 'Красные участки линии — реальные интервалы выше спринтового порога.', 'Изолированные выбросы скорости сглаживаются только для масштаба графика, чтобы тренер видел реальные 16–20 км/ч.'])),
          child: CustomPaint(painter: _SprintPainter(samples: local.speedSamples, hsrThresholdKmh: hsrThresholdKmh, sprintThresholdKmh: sprintThresholdKmh, maxSpeedKmh: maxSpeed), child: const SizedBox.expand()),
        )),
      ]),
    );
    final rankingPanel = _Panel(title: 'Лидеры спринтов', subtitle: '${players.length} игроков · нажмите игрока', child: _PlayerRanking(players: players, mode: _RankingMode.sprints, onTap: openPlayer));

    return LayoutBuilder(builder: (context, c) {
      final stacked = c.maxWidth < 1040;
      final phone = c.maxWidth < 720;
      if (stacked) {
        return ListView(
          primary: false,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            SizedBox(height: phone ? 520 : 560, child: mapPanel),
            SizedBox(height: phone ? 315 : 340, child: intensityPanel),
            SizedBox(height: phone ? 285 : 320, child: rankingPanel),
          ],
        );
      }
      return Row(children: [
        Expanded(flex: 7, child: mapPanel),
        Expanded(flex: 4, child: intensityPanel),
        Expanded(flex: 3, child: rankingPanel),
      ]);
    });
  }
}

class _SpeedTab extends StatelessWidget {
  const _SpeedTab({required this.bundle, required this.local, required this.selectedSession, required this.hsrThresholdKmh, required this.sprintThresholdKmh, required this.onOpenInsight});
  final _AnalyticsBundle bundle;
  final _LocalTrackAnalysis local;
  final TrackerSessionModel? selectedSession;
  final double hsrThresholdKmh;
  final double sprintThresholdKmh;
  final ValueChanged<_CoachInsight> onOpenInsight;

  @override
  Widget build(BuildContext context) {
    final maxSpeed = local.maxSpeedKmh > 0 ? local.maxSpeedKmh : (selectedSession?.maxSpeedKmh ?? 0);
    final avgSpeed = local.avgSpeedKmh > 0 ? local.avgSpeedKmh : (selectedSession?.avgSpeedKmh ?? 0);
    final metersPerMin = selectedSession?.metersPerMinute ?? (local.durationSec <= 0 ? 0 : local.distanceM / (local.durationSec / 60.0));
    final duration = local.durationSec > 0 ? local.durationSec : (selectedSession?.durationSec ?? 0);
    final rows = [..._rowsForAnalytics(bundle, selectedSession, local, null)]..sort((a, b) => b.maxSpeedKmh.compareTo(a.maxSpeedKmh));

    _CoachInsight speedInsight(String title, IconData icon, List<_CoachInsightMetric> metrics, List<String> bullets, {Color accent = _AA.blue}) {
      return _CoachInsight(
        title: title,
        subtitle: '${selectedSession?.playerName ?? 'Команда'} · скорость и зоны',
        icon: icon,
        accent: accent,
        metrics: metrics,
        bullets: bullets,
        footer: 'Нажатие на KPI, график или игрока открывает расшифровку справа. На телефоне эта же информация выезжает снизу.',
      );
    }

    void openSpeedPlayer(TrackerPlayerLoadRow p) {
      onOpenInsight(_CoachInsight(
        title: p.playerName,
        subtitle: 'скоростной профиль игрока',
        icon: Icons.person_rounded,
        accent: _AA.blue,
        metrics: [
          _CoachInsightMetric('Max', '${p.maxSpeedKmh.toStringAsFixed(1)}', 'км/ч'),
          _CoachInsightMetric('Дистанция', _meters(p.distanceM), 'объём'),
          _CoachInsightMetric('SPR', '${p.sprintCount}', 'рывки'),
          _CoachInsightMetric('Load', p.loadScore.toStringAsFixed(0), 'нагрузка'),
        ],
        bullets: [
          'Высокая максимальная скорость без объёма спринтов часто означает один короткий пик.',
          'Если дистанция высокая, а пик низкий — игрок работал объёмно, но не скоростно.',
          'Сравните с вкладкой спринтов, чтобы увидеть, где на поле возникали ускорения.',
        ],
      ));
    }

    final chartPanel = _Panel(
      title: 'График скорости',
      subtitle: 'линия скорости + пороги HIR/SPR',
      child: Column(children: [
        SizedBox(height: 58, child: Row(children: [
          Expanded(child: _MiniNumber(title: 'Средняя', value: avgSpeed.toStringAsFixed(1), note: 'км/ч', onTap: () => onOpenInsight(speedInsight('Средняя скорость', Icons.speed_rounded, [
            _CoachInsightMetric('Средняя', avgSpeed.toStringAsFixed(1), 'км/ч'),
            _CoachInsightMetric('м/мин', metersPerMin.toStringAsFixed(1), 'темп'),
            _CoachInsightMetric('Время', _time(duration), 'сессия'),
            _CoachInsightMetric('Дистанция', _meters(local.distanceM > 0 ? local.distanceM : (selectedSession?.distanceM ?? 0)), 'объём'),
          ], ['Средняя скорость полезна только вместе с длительностью и дистанцией.', 'Для игровых упражнений она может быть низкой, даже если было много ускорений.', 'Смотрите рядом с механикой и зонами, чтобы не ошибиться в выводе.'])))),
          Expanded(child: _MiniNumber(title: 'Максимальная', value: maxSpeed.toStringAsFixed(1), note: 'км/ч', onTap: () => onOpenInsight(speedInsight('Максимальная скорость', Icons.trending_up_rounded, [
            _CoachInsightMetric('Max', maxSpeed.toStringAsFixed(1), 'км/ч'),
            _CoachInsightMetric('SPR', '${sprintThresholdKmh.toStringAsFixed(1)}', 'порог'),
            _CoachInsightMetric('Запас', (maxSpeed - sprintThresholdKmh).toStringAsFixed(1), 'км/ч'),
            _CoachInsightMetric('Точек', '${local.speedSamples.length}', 'GPS'),
          ], ['График использует устойчивый масштаб, поэтому скорость около 18 км/ч показывается рядом с порогом.', 'Одиночные GPS-скачки не должны визуально “прижимать” всю линию вниз.', 'Проверяйте не только max, но и сколько времени игрок держался выше HIR/SPR.'])))),
          Expanded(child: _MiniNumber(title: 'м/мин', value: metersPerMin.toStringAsFixed(1), note: _time(duration), onTap: () => onOpenInsight(speedInsight('Темп работы', Icons.timer_rounded, [
            _CoachInsightMetric('м/мин', metersPerMin.toStringAsFixed(1), 'темп'),
            _CoachInsightMetric('Время', _time(duration), 'длительность'),
            _CoachInsightMetric('Средняя', avgSpeed.toStringAsFixed(1), 'км/ч'),
            _CoachInsightMetric('Max', maxSpeed.toStringAsFixed(1), 'км/ч'),
          ], ['м/мин удобен для сравнения тренировочных блоков разной длины.', 'Высокий м/мин при низком max — ровная интенсивная работа.', 'Низкий м/мин при высоком max — короткие рывки или большие паузы.'], accent: _AA.orange)))),
          Expanded(child: _MiniNumber(title: 'Точек', value: '${local.speedSamples.length}', note: 'GPS скорость', onTap: () => onOpenInsight(speedInsight('Качество GPS-графика', Icons.gps_fixed_rounded, [
            _CoachInsightMetric('Точек', '${local.speedSamples.length}', 'скорость'),
            _CoachInsightMetric('Max', maxSpeed.toStringAsFixed(1), 'км/ч'),
            _CoachInsightMetric('HIR', '${hsrThresholdKmh.toStringAsFixed(1)}', 'км/ч'),
            _CoachInsightMetric('SPR', '${sprintThresholdKmh.toStringAsFixed(1)}', 'км/ч'),
          ], ['Чем больше точек, тем точнее линия по времени.', 'Если точек мало, выводы по спринтам лучше проверять по карте и сессии.', 'Изолированные скачки сглаживаются для визуального масштаба, а не для подмены данных.'], accent: _AA.green)))),
        ])),
        Expanded(child: _NoHoverTap(
          onTap: () => onOpenInsight(speedInsight('Линия скорости', Icons.show_chart_rounded, [
            _CoachInsightMetric('Средняя', avgSpeed.toStringAsFixed(1), 'км/ч'),
            _CoachInsightMetric('Max', maxSpeed.toStringAsFixed(1), 'км/ч'),
            _CoachInsightMetric('HIR', '${hsrThresholdKmh.toStringAsFixed(1)}', 'порог'),
            _CoachInsightMetric('SPR', '${sprintThresholdKmh.toStringAsFixed(1)}', 'порог'),
          ], ['Зелёная линия — скорость по ходу сессии.', 'Оранжевая горизонталь — HIR, красная — спринт.', 'Подписи на точках помогают быстро увидеть, где игрок приблизился к 18 км/ч или превысил порог.'])),
          child: CustomPaint(painter: _SpeedPainter(samples: local.speedSamples, hsrThresholdKmh: hsrThresholdKmh, sprintThresholdKmh: sprintThresholdKmh, maxSpeedKmh: maxSpeed), child: const SizedBox.expand()),
        )),
      ]),
    );
    final zonesPanel = _Panel(
      title: 'Пороговые зоны',
      subtitle: 'скорость, HIR, спринт',
      child: _NoHoverTap(
        onTap: () => onOpenInsight(speedInsight('Пороговые зоны', Icons.stacked_bar_chart_rounded, [
          _CoachInsightMetric('HIR', '${hsrThresholdKmh.toStringAsFixed(1)}', 'км/ч'),
          _CoachInsightMetric('SPR', '${sprintThresholdKmh.toStringAsFixed(1)}', 'км/ч'),
          _CoachInsightMetric('Max', maxSpeed.toStringAsFixed(1), 'км/ч'),
          _CoachInsightMetric('Точек', '${local.speedSamples.length}', 'GPS'),
        ], ['Зоны показывают долю точек в ходьбе, беге, HIR и спринте.', 'Для тренера это быстрый ответ: была тренировка объёмной, интенсивной или скоростной.', 'Пороги автоматически подстраиваются под возрастную команду через профиль U-группы.'], accent: _AA.orange)),
        child: _SpeedZonesPanel(hsrThresholdKmh: hsrThresholdKmh, sprintThresholdKmh: sprintThresholdKmh, maxSpeedKmh: maxSpeed, speedSamples: local.speedSamples),
      ),
    );
    final rankingPanel = _Panel(title: 'Рейтинг скорости', subtitle: '${rows.length} игроков · нажмите игрока', child: _PlayerRanking(players: rows, mode: _RankingMode.speed, onTap: openSpeedPlayer));

    return LayoutBuilder(builder: (context, c) {
      final phone = c.maxWidth < 720;
      if (phone) {
        return ListView(
          primary: false,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            SizedBox(height: 430, child: chartPanel),
            const SizedBox(height: 10),
            SizedBox(height: 300, child: zonesPanel),
            const SizedBox(height: 10),
            SizedBox(height: 285, child: rankingPanel),
          ],
        );
      }
      if (c.maxWidth < 1180) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(flex: 6, child: SizedBox.expand(child: chartPanel)),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Column(children: [
                Expanded(child: zonesPanel),
                const SizedBox(height: 8),
                Expanded(child: rankingPanel),
              ]),
            ),
          ]),
        );
      }
      return Row(children: [
        Expanded(flex: 7, child: chartPanel),
        const SizedBox(width: 7),
        Expanded(flex: 4, child: zonesPanel),
        const SizedBox(width: 7),
        Expanded(flex: 3, child: rankingPanel),
      ]);
    });
  }
}


bool _looksGenericPlayerName(String? value) {
  final name = (value ?? '').trim().toLowerCase();
  if (name.isEmpty || name == 'null') return true;
  if (RegExp(r'^(игрок|player|athlete|спортсмен|команда|team)\s*#?\s*\d*$', caseSensitive: false).hasMatch(name)) return true;
  if (RegExp(r'^(№|#)?\s*\d+$').hasMatch(name)) return true;
  return false;
}

TrackerPlayerOption? _rosterPlayerById(int? id, List<TrackerPlayerOption> players) {
  if (id == null || id <= 0) return null;
  for (final p in players) {
    if (p.id == id || p.identityIds.contains(id)) return p;
  }
  return null;
}

String _rosterNameForPlayer(int? id, List<TrackerPlayerOption> players, {String? fallback}) {
  final player = _rosterPlayerById(id, players);
  final rosterName = player?.name.trim() ?? '';
  final fb = (fallback ?? '').trim();
  if (rosterName.isNotEmpty && !_looksGenericPlayerName(rosterName)) return rosterName;
  if (fb.isNotEmpty && !_looksGenericPlayerName(fb)) return fb;
  return id == null || id <= 0 ? 'Команда' : 'Игрок $id';
}

List<TrackerPlayerLoadRow> _periodRowsFromSessions(List<TrackerSessionModel> sessions, {List<TrackerPlayerOption> players = const <TrackerPlayerOption>[]}) {
  final byPlayer = <int, _SessionAccumulator>{};
  for (final s in sessions) {
    final id = s.playerId ?? -1;
    final name = _rosterNameForPlayer(id, players, fallback: s.playerName ?? 'Команда');
    final acc = byPlayer.putIfAbsent(id, () => _SessionAccumulator(id, name));
    acc.sessions++;
    acc.distance += s.distanceM;
    acc.maxSpeed = math.max(acc.maxSpeed, s.maxSpeedKmh);
    acc.sprints += s.sprintCount;
    acc.sprintDistance += s.sprintDistanceM;
    acc.hsr += s.hsrDistanceM + s.hirDistanceM + s.vhirDistanceM;
    acc.accel += s.accelCount;
    acc.decel += s.decelCount;
    acc.load += s.loadScore;
  }
  return byPlayer.values.map((a) => TrackerPlayerLoadRow(
    playerId: a.playerId > 0 ? a.playerId : null,
    playerName: _rosterNameForPlayer(a.playerId, players, fallback: a.playerName),
    sessionsCount: a.sessions,
    distanceM: a.distance,
    avgSpeedKmh: 0,
    maxSpeedKmh: a.maxSpeed,
    highSpeedDistanceM: a.hsr,
    sprintDistanceM: a.sprintDistance,
    sprintCount: a.sprints,
    accelerationCount: a.accel,
    decelerationCount: a.decel,
    loadScore: a.sessions <= 0 ? 0 : a.load / a.sessions,
  )).toList()
    ..sort((a, b) => b.distanceM.compareTo(a.distanceM));
}

TrackerPlayerLoadRow _rowWithRosterName(TrackerPlayerLoadRow row, List<TrackerPlayerOption> players) {
  final player = _rosterPlayerById(row.playerId, players);
  final resolvedName = _rosterNameForPlayer(row.playerId, players, fallback: row.playerName);
  if (resolvedName == row.playerName && (player?.avatar ?? row.avatar) == row.avatar) return row;
  return TrackerPlayerLoadRow(
    playerId: row.playerId,
    playerName: resolvedName,
    avatar: player?.avatar ?? row.avatar,
    sessionsCount: row.sessionsCount,
    distanceM: row.distanceM,
    avgSpeedKmh: row.avgSpeedKmh,
    maxSpeedKmh: row.maxSpeedKmh,
    highSpeedDistanceM: row.highSpeedDistanceM,
    sprintDistanceM: row.sprintDistanceM,
    sprintCount: row.sprintCount,
    accelerationCount: row.accelerationCount,
    decelerationCount: row.decelerationCount,
    loadScore: row.loadScore,
  );
}

List<TrackerPlayerLoadRow> _rowsWithRosterNames(List<TrackerPlayerLoadRow> rows, List<TrackerPlayerOption> players) => rows.map((r) => _rowWithRosterName(r, players)).toList(growable: false);

List<TrackerPlayerLoadRow> _heartRateRows(_AnalyticsHeartRate heartRate, List<TrackerPlayerOption> players) {
  return heartRate.players.where((p) => p.samplesCount > 0 || p.avgBpm > 0 || p.maxBpm > 0).map((p) {
    final name = _rosterNameForPlayer(p.playerId, players, fallback: p.playerName);
    final hrLoad = math.max(0.0, p.avgBpm.toDouble() * 1.6 + p.maxBpm.toDouble() * .45 + p.highZoneSamples.toDouble() * 2.5);
    return TrackerPlayerLoadRow(
      playerId: p.playerId,
      playerName: name,
      avatar: _rosterPlayerById(p.playerId, players)?.avatar,
      sessionsCount: 0,
      distanceM: 0,
      avgSpeedKmh: 0,
      maxSpeedKmh: 0,
      highSpeedDistanceM: 0,
      sprintDistanceM: 0,
      sprintCount: 0,
      accelerationCount: 0,
      decelerationCount: 0,
      loadScore: hrLoad,
    );
  }).toList(growable: false);
}

List<TrackerPlayerLoadRow> _mergeHeartRateRows(List<TrackerPlayerLoadRow> rows, List<TrackerPlayerLoadRow> hrRows) {
  if (hrRows.isEmpty) return rows;
  if (rows.isEmpty) return hrRows;
  final byKey = <String, TrackerPlayerLoadRow>{};
  String keyOf(TrackerPlayerLoadRow r) => (r.playerId ?? 0) > 0 ? 'id:${r.playerId}' : 'name:${r.playerName.trim().toLowerCase()}';
  for (final row in rows) {
    byKey[keyOf(row)] = row;
  }
  for (final hr in hrRows) {
    final key = keyOf(hr);
    final base = byKey[key];
    if (base == null) {
      byKey[key] = hr;
    } else {
      final load = base.loadScore > 0 ? math.max(base.loadScore, hr.loadScore) : hr.loadScore;
      byKey[key] = TrackerPlayerLoadRow(
        playerId: base.playerId ?? hr.playerId,
        playerName: !_looksGenericPlayerName(base.playerName) ? base.playerName : hr.playerName,
        avatar: base.avatar ?? hr.avatar,
        sessionsCount: base.sessionsCount,
        distanceM: base.distanceM,
        avgSpeedKmh: base.avgSpeedKmh,
        maxSpeedKmh: base.maxSpeedKmh,
        highSpeedDistanceM: base.highSpeedDistanceM,
        sprintDistanceM: base.sprintDistanceM,
        sprintCount: base.sprintCount,
        accelerationCount: base.accelerationCount,
        decelerationCount: base.decelerationCount,
        loadScore: load,
      );
    }
  }
  return byKey.values.toList(growable: false);
}

TrackerPlayerLoadRow? _rowFromSession(TrackerSessionModel? session, _LocalTrackAnalysis local, TrackerPlayerOption? selectedPlayer, {List<TrackerPlayerOption> players = const <TrackerPlayerOption>[]}) {
  if (session == null && local.distanceM <= 0 && local.speedSamples.isEmpty) return null;
  final distance = local.distanceM > 0 ? local.distanceM : (session?.distanceM ?? 0);
  final maxSpeed = local.maxSpeedKmh > 0 ? local.maxSpeedKmh : (session?.maxSpeedKmh ?? 0);
  final avgSpeed = local.avgSpeedKmh > 0 ? local.avgSpeedKmh : (session?.avgSpeedKmh ?? 0);
  final sprintDistance = local.sprintDistanceM > 0 ? local.sprintDistanceM : (session?.sprintDistanceM ?? 0);
  final sprintCount = local.sprintCount > 0 ? local.sprintCount : (session?.sprintCount ?? 0);
  final hir = local.hsrDistanceM > 0 ? local.hsrDistanceM : ((session?.hirDistanceM ?? 0) + (session?.vhirDistanceM ?? 0) + (session?.hsrDistanceM ?? 0));
  final accel = local.accelCount > 0 ? local.accelCount : (session?.accelCount ?? 0);
  final decel = local.decelCount > 0 ? local.decelCount : (session?.decelCount ?? 0);
  final load = (session?.loadScore ?? 0) > 0 ? session!.loadScore : (distance / 10.0 + sprintDistance * .35 + hir * .18 + (accel + decel) * 2.5);
  final playerId = session?.playerId ?? selectedPlayer?.id;
  final playerName = selectedPlayer?.name ?? _rosterNameForPlayer(playerId, players, fallback: session?.playerName ?? 'Игрок');
  return TrackerPlayerLoadRow(
    playerId: playerId,
    playerName: playerName,
    avatar: selectedPlayer?.avatar ?? _rosterPlayerById(playerId, players)?.avatar,
    sessionsCount: session == null ? 0 : 1,
    distanceM: distance,
    avgSpeedKmh: avgSpeed,
    maxSpeedKmh: maxSpeed,
    highSpeedDistanceM: hir,
    sprintDistanceM: sprintDistance,
    sprintCount: sprintCount,
    accelerationCount: accel,
    decelerationCount: decel,
    loadScore: load,
  );
}

List<TrackerPlayerLoadRow> _rowsForAnalytics(_AnalyticsBundle bundle, TrackerSessionModel? selectedSession, _LocalTrackAnalysis local, TrackerPlayerOption? selectedPlayer) {
  final periodRows = _periodRowsFromSessions(bundle.sessions, players: bundle.players);
  var rows = periodRows.isNotEmpty ? periodRows : _rowsWithRosterNames(bundle.dashboard.players, bundle.players);
  final sessionRow = _rowFromSession(selectedSession, local, selectedPlayer, players: bundle.players);
  if (sessionRow != null) {
    final exists = rows.any((r) => r.playerId == sessionRow.playerId && sessionRow.playerId != null);
    rows = exists ? rows.map((r) => r.playerId == sessionRow.playerId ? sessionRow : r).toList(growable: false) : <TrackerPlayerLoadRow>[sessionRow, ...rows];
  }
  rows = _mergeHeartRateRows(_rowsWithRosterNames(rows, bundle.players), _heartRateRows(bundle.heartRate, bundle.players));
  return rows;
}

List<TrackerPlayerLoadRow> _filterRowsByPlayerIds(List<TrackerPlayerLoadRow> rows, Set<int> ids) {
  if (ids.isEmpty) return rows;
  return rows.where((r) => r.playerId != null && ids.contains(r.playerId)).toList(growable: false);
}

class _DayTotal {
  const _DayTotal({
    required this.sessionsCount,
    required this.playersCount,
    required this.distanceM,
    required this.maxSpeedKmh,
    required this.sprintCount,
    required this.sprintDistanceM,
    required this.hirDistanceM,
    required this.accelCount,
    required this.decelCount,
    required this.loadScore,
  });

  final int sessionsCount;
  final int playersCount;
  final double distanceM;
  final double maxSpeedKmh;
  final int sprintCount;
  final double sprintDistanceM;
  final double hirDistanceM;
  final int accelCount;
  final int decelCount;
  final double loadScore;

  factory _DayTotal.fromRows(List<TrackerPlayerLoadRow> rows, {required int sessionsCount, TrackerSessionModel? fallbackSession, required _LocalTrackAnalysis local}) {
    if (rows.isEmpty) {
      final r = _rowFromSession(fallbackSession, local, null);
      if (r == null) {
        return const _DayTotal(sessionsCount: 0, playersCount: 0, distanceM: 0, maxSpeedKmh: 0, sprintCount: 0, sprintDistanceM: 0, hirDistanceM: 0, accelCount: 0, decelCount: 0, loadScore: 0);
      }
      return _DayTotal.fromRows(<TrackerPlayerLoadRow>[r], sessionsCount: sessionsCount <= 0 ? 1 : sessionsCount, fallbackSession: null, local: const _LocalTrackAnalysis(distanceM: 0, durationSec: 0, maxSpeedKmh: 0, avgSpeedKmh: 0, sprintCount: 0, sprintDistanceM: 0, hsrDistanceM: 0, accelCount: 0, decelCount: 0, speedSamples: <double>[]));
    }
    final ids = rows.where((r) => (r.playerId ?? 0) > 0).map((r) => r.playerId).toSet();
    final names = rows
        .where((r) => (r.playerId ?? 0) <= 0 && (r.distanceM > 0 || r.maxSpeedKmh > 0 || r.loadScore > 0 || r.sprintCount > 0))
        .map((r) => r.playerName.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    return _DayTotal(
      sessionsCount: sessionsCount <= 0 ? rows.fold<int>(0, (s, r) => s + math.max(1, r.sessionsCount)) : sessionsCount,
      playersCount: ids.isNotEmpty ? ids.length : names.length,
      distanceM: rows.fold<double>(0, (s, r) => s + r.distanceM),
      maxSpeedKmh: rows.fold<double>(0, (s, r) => math.max(s, r.maxSpeedKmh)),
      sprintCount: rows.fold<int>(0, (s, r) => s + r.sprintCount),
      sprintDistanceM: rows.fold<double>(0, (s, r) => s + r.sprintDistanceM),
      hirDistanceM: rows.fold<double>(0, (s, r) => s + r.highSpeedDistanceM),
      accelCount: rows.fold<int>(0, (s, r) => s + r.accelerationCount),
      decelCount: rows.fold<int>(0, (s, r) => s + r.decelerationCount),
      loadScore: rows.fold<double>(0, (s, r) => s + r.loadScore),
    );
  }
}

class _SessionAccumulator {
  _SessionAccumulator(this.playerId, this.playerName);
  final int playerId;
  final String playerName;
  int sessions = 0;
  double distance = 0;
  double maxSpeed = 0;
  int sprints = 0;
  double sprintDistance = 0;
  double hsr = 0;
  int accel = 0;
  int decel = 0;
  double load = 0;
}

class _TeamTab extends StatelessWidget {
  const _TeamTab({required this.bundle, required this.selectedSession, required this.local, required this.players, required this.selectedPlayer, required this.onSelectPlayer});
  final _AnalyticsBundle bundle;
  final TrackerSessionModel? selectedSession;
  final _LocalTrackAnalysis local;
  final List<TrackerPlayerOption> players;
  final TrackerPlayerOption? selectedPlayer;
  final ValueChanged<int> onSelectPlayer;

  @override
  Widget build(BuildContext context) {
    var rows = _rowsForAnalytics(bundle, selectedSession, local, selectedPlayer);
    final teamRows = rows;
    final selectedRows = selectedPlayer?.id == null ? rows : rows.where((r) => r.playerId == selectedPlayer!.id).toList(growable: false);
    final radarPlayerRows = selectedRows.isNotEmpty ? selectedRows : rows;
    final teamPanel = _Panel(title: 'Командная статистика', subtitle: '${rows.length} игроков · выбранный период/сессия', child: _TeamTable(rows: rows, selectedPlayer: selectedPlayer, onSelectPlayer: onSelectPlayer));
    final teamRadarPanel = _Panel(title: 'Радар команды', subtitle: 'средний профиль всех игроков', child: CustomPaint(painter: _RadarPainter(rows: teamRows), child: const SizedBox.expand()));
    final playerRadarPanel = _Panel(title: selectedPlayer == null ? 'Радар игрока' : 'Радар игрока: ${selectedPlayer!.name}', subtitle: selectedSession == null ? 'период / live' : 'сессия #${selectedSession!.id}', child: CustomPaint(painter: _RadarPainter(rows: radarPlayerRows, baselineRows: teamRows), child: const SizedBox.expand()));
    final summaryPanel = _Panel(title: 'Расшифровка сессии', subtitle: selectedSession?.title ?? 'выберите запись', child: selectedSession == null ? const _Empty(icon: Icons.radar_rounded, text: 'Выберите дату или сессию, чтобы увидеть профиль игрока и команды.') : _SessionSummary(session: selectedSession!, local: local));

    return LayoutBuilder(builder: (context, c) {
      final phone = c.maxWidth < 720;
      if (phone) {
        return ListView(
          primary: false,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            SizedBox(height: 310, child: teamPanel),
            const SizedBox(height: 8),
            SizedBox(height: 300, child: teamRadarPanel),
            const SizedBox(height: 8),
            SizedBox(height: 300, child: playerRadarPanel),
            const SizedBox(height: 8),
            SizedBox(height: 275, child: summaryPanel),
          ],
        );
      }
      if (c.maxWidth < 1180) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(flex: 6, child: teamPanel),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Column(children: [
                Expanded(child: teamRadarPanel),
                const SizedBox(height: 8),
                Expanded(child: playerRadarPanel),
                const SizedBox(height: 8),
                Expanded(child: summaryPanel),
              ]),
            ),
          ]),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(flex: 6, child: teamPanel),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: teamRadarPanel),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: playerRadarPanel),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: summaryPanel),
        ]),
      );
    });
  }
}


class _RatingsTab extends StatefulWidget {
  const _RatingsTab({required this.bundle, required this.local, required this.teamName, required this.selectedPlayer, required this.selectedSession});
  final _AnalyticsBundle bundle;
  final _LocalTrackAnalysis local;
  final String teamName;
  final TrackerPlayerOption? selectedPlayer;
  final TrackerSessionModel? selectedSession;

  @override
  State<_RatingsTab> createState() => _RatingsTabState();
}

class _RatingsTabState extends State<_RatingsTab> {
  _RankingMode _mode = _RankingMode.distance;

  @override
  Widget build(BuildContext context) {
    final rows = _rowsForAnalytics(widget.bundle, widget.selectedSession, widget.local, widget.selectedPlayer);
    final allRows = _rowsForAnalytics(widget.bundle, widget.selectedSession, widget.local, null);
    final selectedRows = widget.selectedPlayer?.id == null ? <TrackerPlayerLoadRow>[] : allRows.where((r) => r.playerId == widget.selectedPlayer!.id).toList(growable: false);
    final sorted = [...rows]..sort((a, b) => _value(b).compareTo(_value(a)));
    final total = _DayTotal.fromRows(allRows, sessionsCount: widget.bundle.sessions.length, fallbackSession: widget.selectedSession, local: widget.local);
    final playersPanel = _Panel(
      title: 'Рейтинг игроков',
      subtitle: 'по выбранным сессиям',
      child: Column(children: [
        SizedBox(
          height: 34,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _RankModeChip(label: 'Дистанция', mode: _RankingMode.distance, value: _mode, onChanged: _setMode),
            _RankModeChip(label: 'Скорость', mode: _RankingMode.speed, value: _mode, onChanged: _setMode),
            _RankModeChip(label: 'Спринты', mode: _RankingMode.sprints, value: _mode, onChanged: _setMode),
            _RankModeChip(label: 'Нагрузка', mode: _RankingMode.load, value: _mode, onChanged: _setMode),
          ]),
        ),
        Expanded(child: _PlayerRanking(players: sorted, mode: _mode)),
      ]),
    );
    final teamPanel = _Panel(
      title: 'Рейтинг команды',
      subtitle: 'сравнение доступных команд / групп',
      child: Column(children: [
        _TeamCompareRow(name: widget.teamName, value: _meters(total.distanceM), note: '${total.playersCount} игроков · ${total.sessionsCount} сессий', rank: 1),
        const _InlineNotice(text: 'Когда появятся данные других команд, они будут показаны здесь для сравнения по тем же выбранным сессиям.'),
        Expanded(child: CustomPaint(painter: _RadarPainter(rows: allRows), child: const SizedBox.expand())),
      ]),
    );
    final comparePanel = _Panel(
      title: 'Сравнение игрока',
      subtitle: 'игрок против среднего команды',
      child: CustomPaint(painter: _RadarPainter(rows: selectedRows.isNotEmpty ? selectedRows : rows, baselineRows: allRows), child: const SizedBox.expand()),
    );

    return LayoutBuilder(builder: (context, c) {
      final stacked = c.maxWidth < 1040;
      final phone = c.maxWidth < 720;
      if (stacked) {
        return ListView(
          primary: false,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            SizedBox(height: phone ? 340 : 380, child: playersPanel),
            SizedBox(height: phone ? 305 : 340, child: teamPanel),
            SizedBox(height: phone ? 300 : 330, child: comparePanel),
          ],
        );
      }
      return Row(children: [
        Expanded(flex: 5, child: playersPanel),
        Expanded(flex: 4, child: teamPanel),
        Expanded(flex: 4, child: comparePanel),
      ]);
    });
  }

  void _setMode(_RankingMode mode) => setState(() => _mode = mode);

  double _value(TrackerPlayerLoadRow row) {
    switch (_mode) {
      case _RankingMode.speed:
        return row.maxSpeedKmh;
      case _RankingMode.sprints:
        return row.sprintCount.toDouble() * 1000 + row.sprintDistanceM;
      case _RankingMode.load:
        return row.loadScore;
      case _RankingMode.distance:
      default:
        return row.distanceM;
    }
  }
}

class _RankModeChip extends StatelessWidget {
  const _RankModeChip({required this.label, required this.mode, required this.value, required this.onChanged});
  final String label;
  final _RankingMode mode;
  final _RankingMode value;
  final ValueChanged<_RankingMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = mode == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: _SmallButton(icon: Icons.leaderboard_rounded, label: label, primary: active, onTap: () => onChanged(mode)),
    );
  }
}

class _TeamCompareRow extends StatelessWidget {
  const _TeamCompareRow({required this.name, required this.value, required this.note, required this.rank});
  final String name;
  final String value;
  final String note;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _AA.line))),
      child: Row(children: [
        Text('$rank', style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 11.2, fontWeight: FontWeight.w700)),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
        ])),
        Text(value, style: const TextStyle(color: _AA.green, fontSize: 11.2, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SessionsTab extends StatelessWidget {
  const _SessionsTab({
    required this.sessions,
    required this.selectedSession,
    required this.selectedDate,
    required this.onlySelectedDate,
    required this.onPrevDate,
    required this.onNextDate,
    required this.onToday,
    required this.onPickDate,
    required this.onSelectSession,
    required this.onOpenSessions,
    this.usingLatestFallback = false,
    this.fallbackMessage = '',
  });

  final List<TrackerSessionModel> sessions;
  final TrackerSessionModel? selectedSession;
  final DateTime selectedDate;
  final bool onlySelectedDate;
  final VoidCallback onPrevDate;
  final VoidCallback onNextDate;
  final VoidCallback onToday;
  final VoidCallback onPickDate;
  final ValueChanged<TrackerSessionModel> onSelectSession;
  final VoidCallback onOpenSessions;
  final bool usingLatestFallback;
  final String fallbackMessage;

  String get _dateLabel => '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}';

  @override
  Widget build(BuildContext context) {
    final byPlayer = <int, int>{};
    for (final s in sessions) {
      final id = s.playerId ?? -1;
      byPlayer[id] = (byPlayer[id] ?? 0) + 1;
    }

    return Row(children: [
      Expanded(flex: 4, child: _Panel(title: 'Календарь сессий', subtitle: onlySelectedDate ? 'выбран день $_dateLabel' : 'все даты', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _IconOnlyButton(icon: Icons.chevron_left_rounded, onTap: onPrevDate),
          Expanded(child: _NoHoverTap(onTap: onPickDate, borderRadius: BorderRadius.circular(4), child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _AA.green.withOpacity(.25))),
            child: Text(_dateLabel, style: const TextStyle(color: _AA.text, fontWeight: FontWeight.w700)),
          ))),
          _IconOnlyButton(icon: Icons.chevron_right_rounded, onTap: onNextDate),
        ]),
        const SizedBox(height: 0),
        _SmallButton(icon: Icons.today_rounded, label: 'Сегодня', onTap: onToday),
        const SizedBox(height: 0),
        _InfoLine(title: usingLatestFallback ? 'Показано' : 'Сессий за период', value: usingLatestFallback ? 'последняя сессия' : '${sessions.length}'),
        _InfoLine(title: 'Игроков с данными', value: '${byPlayer.keys.where((e) => e > 0).length}'),
        if (usingLatestFallback) _Hint(text: fallbackMessage),
        const SizedBox(height: 0),
        const _Hint(text: 'Данные больше не смешиваются бесконечно: выбирайте дату или конкретную сессию. Live-точки остаются на экране отдельно, пока сессия идёт.'),
      ]))),
      const SizedBox.shrink(),
      Expanded(flex: 6, child: _Panel(title: 'История сессий', subtitle: '${sessions.length} записей', child: sessions.isEmpty
          ? const _Empty(icon: Icons.event_note_rounded, text: 'Сессии появятся после Live, стопа с сохранением или выгрузки офлайн GPS.')
          : ListView(children: sessions.map((s) {
              final active = selectedSession?.id == s.id;
              return _ListRow(
                icon: Icons.assignment_rounded,
                title: s.title,
                subtitle: '${s.playerName ?? 'Команда'} · ${s.createdAt} · ${_meters(s.distanceM)} · ${s.sprintCount} спринтов',
                trailing: s.processingStatus == 'done' ? 'готово' : s.processingStatus,
                active: active,
                onTap: () => onSelectSession(s),
              );
            }).toList()))),
      const SizedBox.shrink(),
      Expanded(flex: 5, child: _Panel(title: 'Расшифровка', subtitle: selectedSession?.title ?? 'выберите сессию', child: selectedSession == null
          ? const _Empty(icon: Icons.analytics_rounded, text: 'Выберите сессию слева: карта, спринты, скорость и команда будут строиться по выбранной записи.')
          : _SessionSummary(session: selectedSession!))),
      const SizedBox.shrink(),
      Expanded(flex: 3, child: _Panel(title: 'Действия', subtitle: 'GPS-записи', child: Column(children: [
        _SmallButton(icon: Icons.table_chart_rounded, label: 'Открыть сессии', primary: true, onTap: onOpenSessions),
        const SizedBox(height: 0),
        const _Hint(text: 'Для командной аналитики передавайте датчик другому игроку после остановки и сохранения текущей сессии. У каждого игрока будет своя запись в календаре.'),
      ]))),
    ]);
  }
}


class _OfflineTab extends StatelessWidget {
  const _OfflineTab({
    required this.liveRunning,
    required this.commandChannelReady,
    required this.offlineRecordsCount,
    required this.localPointsCount,
    required this.offlineGpsMode,
    required this.onToggleOfflineGpsMode,
    required this.onRequestOfflineRecords,
    required this.onSaveOfflineSession,
    required this.onOpenSessions,
  });

  final bool liveRunning;
  final bool commandChannelReady;
  final int offlineRecordsCount;
  final int localPointsCount;
  final bool offlineGpsMode;
  final ValueChanged<bool> onToggleOfflineGpsMode;
  final VoidCallback onRequestOfflineRecords;
  final VoidCallback onSaveOfflineSession;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context) {
    final devicePanel = _Panel(title: 'Офлайн GPS с датчика', subtitle: commandChannelReady ? 'BLE TX/RX готов' : 'нужен реальный BLE-канал', child: Column(children: [
      SwitchListTile.adaptive(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: offlineGpsMode,
        onChanged: onToggleOfflineGpsMode,
        title: const Text('Режим офлайн-выгрузки', style: TextStyle(fontWeight: FontWeight.w700, color: _AA.text)),
        subtitle: const Text('Сначала читаем список записей с датчика, затем загружаем GPS-точки и сохраняем как сессию.', style: TextStyle(color: _AA.muted, fontSize: 11.2)),
      ),
      _InfoLine(title: 'BLE канал', value: commandChannelReady ? 'TX/RX готов' : 'нет TX/RX'),
      _InfoLine(title: 'Live', value: liveRunning ? 'идёт' : 'не запущен'),
      _InfoLine(title: 'Записей в датчике', value: '$offlineRecordsCount'),
      _InfoLine(title: 'Загружено точек', value: '$localPointsCount'),
      const Spacer(),
      _SmallButton(icon: Icons.download_rounded, label: 'Прочитать записи', primary: true, onTap: onRequestOfflineRecords),
      const SizedBox(height: 0),
      _SmallButton(icon: Icons.cloud_upload_rounded, label: 'Сохранить как сессию', onTap: onSaveOfflineSession),
    ]));
    final howPanel = _Panel(title: 'Как работает офлайн', subtitle: 'без постоянного Live', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
      _Hint(text: '1. Датчик записывает GPS внутри себя.\n2. После тренировки подключаем датчик.\n3. Нажимаем «Прочитать записи».\n4. Выбираем запись в «Сессиях».\n5. Загружаем GPS-точки и сохраняем тренировку.'),
      SizedBox(height: 10),
      _Hint(text: 'Кнопка чтения использует реальную команду списка записей датчика, а сохранение отправляет загруженные GPS-точки в API сессий.'),
    ]));
    final sessionsPanel = _Panel(title: 'Сессии', subtitle: 'открыть полный список', child: Column(children: [
      const _Empty(icon: Icons.event_note_rounded, text: 'В полном разделе видны записи датчика и серверные GPS-сессии. Экспорт доступен в разделе «Отчёт».'),
      const SizedBox(height: 0),
      _SmallButton(icon: Icons.event_note_rounded, label: 'Открыть сессии', onTap: onOpenSessions),
    ]));

    return LayoutBuilder(builder: (context, c) {
      final stacked = c.maxWidth < 1040;
      final phone = c.maxWidth < 720;
      if (stacked) {
        return ListView(
          primary: false,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            SizedBox(height: phone ? 330 : 360, child: devicePanel),
            SizedBox(height: phone ? 260 : 290, child: howPanel),
            SizedBox(height: phone ? 220 : 250, child: sessionsPanel),
          ],
        );
      }
      return Row(children: [
        Expanded(flex: 5, child: devicePanel),
        Expanded(flex: 5, child: howPanel),
        Expanded(flex: 4, child: sessionsPanel),
      ]);
    });
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.field,
    required this.gpsOffsetFix,
    required this.gpsOffsetMode,
    required this.linearDepth,
    required this.mapRotationDeg,
    required this.sprintThresholdKmh,
    required this.hsrThresholdKmh,
    required this.showSprintArrows,
    required this.onOpenCalibration,
    required this.onSettingsChanged,
    required this.onDebug,
  });

  final TrackerFieldModel? field;
  final bool gpsOffsetFix;
  final String gpsOffsetMode;
  final double linearDepth;
  final double mapRotationDeg;
  final double sprintThresholdKmh;
  final double hsrThresholdKmh;
  final bool showSprintArrows;
  final VoidCallback onOpenCalibration;
  final void Function({bool? gpsOffsetFix, String? gpsOffsetMode, double? linearDepth, double? mapRotationDeg, double? sprintThresholdKmh, double? hsrThresholdKmh, bool? showSprintArrows}) onSettingsChanged;
  final void Function(String message, Map<String, dynamic> context) onDebug;

  @override
  Widget build(BuildContext context) {
    final calibrationPanel = _Panel(title: 'Калибровка поля', subtitle: field?.title ?? 'нет поля', child: Column(children: [
      _CalibrationMini(field: field),
      const SizedBox(height: 0),
      _InfoLine(title: 'A/B/C/D', value: field?.hasCalibration == true ? 'сохранены' : 'не готовы'),
      _InfoLine(title: 'Поворот карты', value: '${mapRotationDeg.toStringAsFixed(0)}°'),
      _SmallButton(icon: Icons.map_rounded, label: 'Калибровать A/B/C/D', primary: true, onTap: onOpenCalibration),
    ]));
    final mapSettingsPanel = _Panel(title: 'Настройки карты и GPS', subtitle: 'смещение, глубина, поворот', child: ListView(children: [
      SwitchListTile.adaptive(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: gpsOffsetFix,
        onChanged: (v) => onSettingsChanged(gpsOffsetFix: v),
        title: const Text('Коррекция GPS-смещения', style: TextStyle(fontWeight: FontWeight.w700, color: _AA.text)),
        subtitle: const Text('Коррекция смещения GPS перед построением карты.', style: TextStyle(color: _AA.muted, fontSize: 11.2)),
      ),
      _ChoiceLine(
        label: 'Режим коррекции',
        value: gpsOffsetMode,
        values: const {'auto': 'Авто', 'soft': 'Мягко', 'hard': 'Жёстко'},
        onChanged: (v) => onSettingsChanged(gpsOffsetMode: v),
      ),
      _SliderLine(label: 'Глубина сглаживания', value: linearDepth, min: 1, max: 8, divisions: 7, suffix: 'x', onChanged: (v) => onSettingsChanged(linearDepth: v)),
      _SliderLine(label: 'Поворот карты', value: mapRotationDeg, min: -180, max: 180, divisions: 12, suffix: '°', onChanged: (v) => onSettingsChanged(mapRotationDeg: v)),
      SwitchListTile.adaptive(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: showSprintArrows,
        onChanged: (v) => onSettingsChanged(showSprintArrows: v),
        title: const Text('Спринты стрелками', style: TextStyle(fontWeight: FontWeight.w700, color: _AA.text)),
        subtitle: const Text('На карте спринты показываются направленными стрелками.', style: TextStyle(color: _AA.muted, fontSize: 11.2)),
      ),
    ]));
    final thresholdsPanel = _Panel(title: 'Пороги и отладка', subtitle: 'скорость / спринты / высокая интенсивность', child: ListView(children: [
      _SliderLine(label: 'Высокая интенсивность', value: hsrThresholdKmh, min: 10, max: 24, divisions: 14, suffix: 'км/ч', onChanged: (v) => onSettingsChanged(hsrThresholdKmh: v)),
      _SliderLine(label: 'Спринт', value: sprintThresholdKmh, min: 14, max: 30, divisions: 16, suffix: 'км/ч', onChanged: (v) => onSettingsChanged(sprintThresholdKmh: v)),
      const _ZoneLine(label: 'Профиль', value: 'ДЮФ: пороги ниже взрослой методики'),
      const _ZoneLine(label: 'Фильтр стояния', value: 'GPS прыжки режутся'),
      const SizedBox(height: 0),
      _SmallButton(icon: Icons.bug_report_rounded, label: 'Отправить отладку', onTap: () => onDebug('Отладка настроек аналитики', {
        'field_ready': field?.hasCalibration == true,
        'field_id': field?.id,
        'gps_offset_fix': gpsOffsetFix,
        'gps_offset_mode': gpsOffsetMode,
        'linear_depth': linearDepth,
        'map_rotation_deg': mapRotationDeg,
        'sprint_threshold_kmh': sprintThresholdKmh,
        'hsr_threshold_kmh': hsrThresholdKmh,
        'show_sprint_arrows': showSprintArrows,
      })),
    ]));

    return LayoutBuilder(builder: (context, c) {
      final phone = c.maxWidth < 720;
      if (phone) {
        return ListView(
          primary: false,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            SizedBox(height: 250, child: calibrationPanel),
            SizedBox(height: 350, child: mapSettingsPanel),
            SizedBox(height: 300, child: thresholdsPanel),
          ],
        );
      }
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(flex: 5, child: calibrationPanel),
          const SizedBox(width: 8),
          Expanded(flex: 6, child: mapSettingsPanel),
          const SizedBox(width: 8),
          Expanded(flex: 5, child: thresholdsPanel),
        ]),
      );
    });
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child, this.trailing});
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _AA.card,
        borderRadius: BorderRadius.circular(_AA.tabletCardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07111827),
            blurRadius: 18,
            spreadRadius: -12,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: const BoxDecoration(color: Colors.white),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', color: _AA.text, fontSize: 14.0, fontWeight: FontWeight.w600, height: 1.15)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w400, height: 1.18)),
            ])),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ]),
        ),
        Expanded(child: Padding(padding: const EdgeInsets.all(10), child: child)),
      ]),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(color: Color(0xFFFFFBEB), border: Border(bottom: BorderSide(color: _AA.line))),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: _AA.orange, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _MiniNumber extends StatelessWidget {
  const _MiniNumber({required this.title, required this.value, required this.note, this.onTap});
  final String title;
  final String value;
  final String note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: onTap == null ? _AA.card : _AA.greenSoft.withOpacity(.55),
        border: const Border(right: BorderSide(color: _AA.line), bottom: BorderSide(color: _AA.line)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w700)),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700)),
        Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
      ]),
    );
    return onTap == null ? tile : _NoHoverTap(onTap: onTap, child: tile);
  }
}

class _PlayerActivityProfilePanel extends StatelessWidget {
  const _PlayerActivityProfilePanel({required this.selectedPlayer, required this.selectedSession, required this.local, required this.heatmap, required this.rows, required this.title});
  final TrackerPlayerOption? selectedPlayer;
  final TrackerSessionModel? selectedSession;
  final _LocalTrackAnalysis local;
  final List<TrackerHeatPoint> heatmap;
  final List<TrackerPlayerLoadRow> rows;
  final String title;

  @override
  Widget build(BuildContext context) {
    final axes = _activityAxes(local: local, session: selectedSession, rows: rows);
    final rowAccel = rows.fold<int>(0, (a, r) => a + r.accelerationCount);
    final rowDecel = rows.fold<int>(0, (a, r) => a + r.decelerationCount);
    final rowLoad = rows.fold<double>(0, (a, r) => a + r.loadScore);
    final accel = local.accelCount > 0 ? local.accelCount : ((selectedSession?.accelCount ?? 0) > 0 ? selectedSession!.accelCount : rowAccel);
    final decel = local.decelCount > 0 ? local.decelCount : ((selectedSession?.decelCount ?? 0) > 0 ? selectedSession!.decelCount : rowDecel);
    final load = (selectedSession?.loadScore ?? 0) > 0 ? selectedSession!.loadScore : rowLoad;
    return _Panel(
      title: title,
      subtitle: '${selectedPlayer?.name ?? selectedSession?.playerName ?? 'Команда'} · радар + мини-теплокарта',
      child: Column(children: [
        Expanded(flex: 7, child: CustomPaint(painter: _ActivityRadarPainter(axes: axes), child: const SizedBox.expand())),
        Container(height: 1, color: _AA.line),
        Expanded(
          flex: 5,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.72,
              child: CustomPaint(painter: _MiniHeatmapPainter(points: heatmap), child: const SizedBox.expand()),
            ),
          ),
        ),
        Container(height: 1, color: _AA.line),
        SizedBox(height: 52, child: Row(children: [
          Expanded(child: _MiniNumber(title: 'Уск/торм', value: '$accel/$decel', note: 'механика')),
          Expanded(child: _MiniNumber(title: 'Нагрузка', value: load.toStringAsFixed(0), note: selectedSession == null ? 'период/пульс' : 'сессия')),
          Expanded(child: _MiniNumber(title: 'Теплокарта', value: '${heatmap.length}', note: 'точек')),
        ])),
      ]),
    );
  }
}

class _ActivityAxisValue {
  const _ActivityAxisValue(this.label, this.value);
  final String label;
  final double value;
}

List<_ActivityAxisValue> _activityAxes({required _LocalTrackAnalysis local, required TrackerSessionModel? session, List<TrackerPlayerLoadRow> rows = const <TrackerPlayerLoadRow>[]}) {
  double clamp(double v) => v.isNaN || v.isInfinite ? 0 : v.clamp(0.0, 1.0).toDouble();
  double sum(double Function(TrackerPlayerLoadRow r) pick) => rows.fold<double>(0, (a, r) => a + pick(r));
  double maxRow(double Function(TrackerPlayerLoadRow r) pick) => rows.fold<double>(0, (a, r) => math.max(a, pick(r)));
  final rowDistance = sum((r) => r.distanceM);
  final rowMaxSpeed = maxRow((r) => r.maxSpeedKmh);
  final rowSprintDistance = sum((r) => r.sprintDistanceM);
  final rowSprintCount = rows.fold<int>(0, (a, r) => a + r.sprintCount);
  final rowHir = sum((r) => r.highSpeedDistanceM);
  final rowAccel = rows.fold<int>(0, (a, r) => a + r.accelerationCount);
  final rowDecel = rows.fold<int>(0, (a, r) => a + r.decelerationCount);
  final rowLoad = sum((r) => r.loadScore);
  final distance = local.distanceM > 0 ? local.distanceM : ((session?.distanceM ?? 0) > 0 ? session!.distanceM : rowDistance);
  final maxSpeed = local.maxSpeedKmh > 0 ? local.maxSpeedKmh : ((session?.maxSpeedKmh ?? 0) > 0 ? session!.maxSpeedKmh : rowMaxSpeed);
  final sprintDistance = local.sprintDistanceM > 0 ? local.sprintDistanceM : ((session?.sprintDistanceM ?? 0) > 0 ? session!.sprintDistanceM : rowSprintDistance);
  final sprintCount = local.sprintCount > 0 ? local.sprintCount : ((session?.sprintCount ?? 0) > 0 ? session!.sprintCount : rowSprintCount);
  final hir = local.hsrDistanceM > 0 ? local.hsrDistanceM : (((session?.hirDistanceM ?? 0) + (session?.vhirDistanceM ?? 0) + (session?.hsrDistanceM ?? 0)) > 0 ? ((session?.hirDistanceM ?? 0) + (session?.vhirDistanceM ?? 0) + (session?.hsrDistanceM ?? 0)) : rowHir);
  final accel = local.accelCount > 0 ? local.accelCount : ((session?.accelCount ?? 0) > 0 ? session!.accelCount : rowAccel);
  final decel = local.decelCount > 0 ? local.decelCount : ((session?.decelCount ?? 0) > 0 ? session!.decelCount : rowDecel);
  final fallbackLoad = distance / 10.0 + sprintDistance * .35 + hir * .18 + (accel + decel) * 2.5;
  final load = (session?.loadScore ?? 0) > 0 ? session!.loadScore : (rowLoad > 0 ? rowLoad : fallbackLoad);
  return <_ActivityAxisValue>[
    _ActivityAxisValue('Объём', clamp(distance / 9000.0)),
    _ActivityAxisValue('Скорость', clamp(maxSpeed / 34.0)),
    _ActivityAxisValue('Спринт', clamp((sprintDistance / 650.0 + sprintCount / 35.0) / 2.0)),
    _ActivityAxisValue('Интенс.', clamp(hir / 1800.0)),
    _ActivityAxisValue('Манёвр', clamp((accel + decel) / 140.0)),
    _ActivityAxisValue('Load', clamp(load / 1000.0)),
  ];
}

class _SpeedZonesPanel extends StatelessWidget {
  const _SpeedZonesPanel({required this.hsrThresholdKmh, required this.sprintThresholdKmh, required this.maxSpeedKmh, this.speedSamples = const <double>[]});
  final double hsrThresholdKmh;
  final double sprintThresholdKmh;
  final double maxSpeedKmh;
  final List<double> speedSamples;

  @override
  Widget build(BuildContext context) {
    final samples = speedSamples.where((v) => v.isFinite && v >= 0).toList(growable: false);
    final total = samples.length;
    double share(bool Function(double v) test) {
      if (total <= 0) return 0;
      return samples.where(test).length / total;
    }
    String note(bool Function(double v) test, String range) {
      if (total <= 0) return range;
      final count = samples.where(test).length;
      final percent = (count * 100 / total).round();
      return '$range · $percent% · $count точ.';
    }

    return ListView(children: [
      _ZoneProgress(label: 'Ходьба / лёгкая работа', range: note((v) => v < 7, '< 7 км/ч'), value: share((v) => v < 7), color: _AA.green.withOpacity(.50)),
      _ZoneProgress(label: 'Бег', range: note((v) => v >= 7 && v < hsrThresholdKmh, '7–${hsrThresholdKmh.toStringAsFixed(1)} км/ч'), value: share((v) => v >= 7 && v < hsrThresholdKmh), color: _AA.green),
      _ZoneProgress(label: 'Высокая интенсивность', range: note((v) => v >= hsrThresholdKmh && v < sprintThresholdKmh, '${hsrThresholdKmh.toStringAsFixed(1)}–${sprintThresholdKmh.toStringAsFixed(1)} км/ч'), value: share((v) => v >= hsrThresholdKmh && v < sprintThresholdKmh), color: _AA.orange),
      _ZoneProgress(label: 'Спринт', range: note((v) => v >= sprintThresholdKmh, '> ${sprintThresholdKmh.toStringAsFixed(1)} км/ч'), value: share((v) => v >= sprintThresholdKmh), color: _AA.red),
      const SizedBox(height: 6),
      _Hint(text: total > 0
          ? 'Полосы показывают долю GPS-точек в зоне, а не просто факт достижения максимальной скорости.'
          : 'Нет GPS-точек speed_kmh для расчёта долей зон. Максимальная скорость: ${maxSpeedKmh.toStringAsFixed(1)} км/ч.'),
    ]);
  }
}

class _PlayerComparisonPanel extends StatelessWidget {
  const _PlayerComparisonPanel({required this.rows});
  final List<TrackerPlayerLoadRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty(icon: Icons.compare_arrows_rounded, text: 'Выберите двух или больше игроков для сравнения.');
    final sorted = [...rows]..sort((a, b) => b.distanceM.compareTo(a.distanceM));
    final maxDistance = math.max(1.0, sorted.fold<double>(0, (v, r) => math.max(v, r.distanceM)));
    final maxSpeed = math.max(1.0, sorted.fold<double>(0, (v, r) => math.max(v, r.maxSpeedKmh)));
    final maxSprints = math.max(1, sorted.fold<int>(0, (v, r) => math.max(v, r.sprintCount)));
    final visible = sorted.take(6).toList(growable: false);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        Row(children: [
          const Icon(Icons.compare_arrows_rounded, color: _AA.green, size: 15),
          const SizedBox(width: 6),
          Expanded(child: Text('Сравнение игроков · ${rows.length}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700))),
          const Text('дист. / max / SPR', style: TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        for (final r in visible)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _AA.line))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700))),
                Text('${_meters(r.distanceM)} · ${r.maxSpeedKmh.toStringAsFixed(1)} · ${r.sprintCount}', style: const TextStyle(color: _AA.green, fontSize: 10.4, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              _TinyCompareBar(label: 'Дистанция', value: r.distanceM / maxDistance),
              _TinyCompareBar(label: 'Скорость', value: r.maxSpeedKmh / maxSpeed),
              _TinyCompareBar(label: 'SPR', value: r.sprintCount / maxSprints),
            ]),
          ),
      ],
    );
  }
}

class _TinyCompareBar extends StatelessWidget {
  const _TinyCompareBar({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: [
        SizedBox(width: 52, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w700))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: value.clamp(0.0, 1.0).toDouble(), minHeight: 4, backgroundColor: const Color(0xFFE1E5E2), valueColor: const AlwaysStoppedAnimation<Color>(_AA.green)),
          ),
        ),
      ]),
    );
  }
}

class _ZoneProgress extends StatelessWidget {
  const _ZoneProgress({required this.label, required this.range, required this.value, required this.color});
  final String label;
  final String range;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 270;
      final header = narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(range, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
            ])
          : Row(children: [
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Flexible(child: Text(range, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600))),
            ]);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _AA.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          header,
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: value.clamp(0.0, 1.0).toDouble(), minHeight: 5, backgroundColor: const Color(0xFFE1E5E2), valueColor: AlwaysStoppedAnimation<Color>(color)),
          ),
        ]),
      );
    });
  }
}


class _MapModeButton extends StatelessWidget {
  const _MapModeButton({required this.label, required this.icon, required this.active, required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? _AA.greenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? _AA.green : _AA.muted),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: active ? _AA.green : _AA.text, fontSize: 11.2, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.title, required this.value, required this.note, this.onTap});
  final IconData icon;
  final String title;
  final String value;
  final String note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: onTap == null ? _AA.card : _AA.greenSoft.withOpacity(.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onTap == null ? _AA.line.withOpacity(.58) : _AA.greenLine, width: .7),
      ),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _AA.green, size: 17)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', color: _AA.muted, fontSize: 10.8, fontWeight: FontWeight.w500, height: 1.05)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', color: _AA.text, fontSize: 15.2, fontWeight: FontWeight.w600, height: 1.05)),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', color: _AA.muted, fontSize: 10.2, fontWeight: FontWeight.w400, height: 1.05)),
        ])),
      ]),
    );
    final radius = BorderRadius.circular(12);
    return onTap == null ? tile : _NoHoverTap(onTap: onTap, borderRadius: radius, child: tile);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.selectedPlayer, this.playerFilterLabel = 'Команда', required this.selectedField, required this.onOpenCalibration});
  final TrackerPlayerOption? selectedPlayer;
  final String playerFilterLabel;
  final TrackerFieldModel? selectedField;
  final VoidCallback onOpenCalibration;

  @override
  Widget build(BuildContext context) {
    return _Panel(title: 'Готовность аналитики', subtitle: 'игрок, поле, карта', child: Column(children: [
      _InfoLine(title: 'Игрок', value: selectedPlayer?.name ?? playerFilterLabel),
      _InfoLine(title: 'Поле', value: selectedField?.title ?? 'не выбрано'),
      _InfoLine(title: 'Калибровка', value: selectedField?.hasCalibration == true ? 'A/B/C/D сохранены' : 'нужно настроить'),
      const SizedBox(height: 0),
      _SmallButton(icon: Icons.map_rounded, label: 'Калибровка поля', primary: selectedField?.hasCalibration != true, onTap: onOpenCalibration),
    ]));
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({required this.onOpenCalibration, required this.onOpenSessions});
  final VoidCallback onOpenCalibration;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context) {
    return _Panel(title: 'Рабочий процесс', subtitle: 'логика модулей', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Hint(text: '1. Подключить датчики.\n2. Калибровать поле A/B/C/D.\n3. Запустить Live или выгрузить GPS.\n4. Открыть теплокарту, спринты, скорость, команду и выгрузку.'),
      const Spacer(),
      _SmallButton(icon: Icons.map_rounded, label: 'Поле', onTap: onOpenCalibration),
      const SizedBox(height: 0),
      _SmallButton(icon: Icons.event_note_rounded, label: 'Сессии', onTap: onOpenSessions),
    ]));
  }
}

class _TeamLeadersCard extends StatelessWidget {
  const _TeamLeadersCard({required this.bundle});
  final _AnalyticsBundle bundle;

  @override
  Widget build(BuildContext context) {
    final rows = [..._rowsForAnalytics(bundle, null, const _LocalTrackAnalysis(distanceM: 0, durationSec: 0, maxSpeedKmh: 0, avgSpeedKmh: 0, sprintCount: 0, sprintDistanceM: 0, hsrDistanceM: 0, accelCount: 0, decelCount: 0, speedSamples: <double>[]), null)]..sort((a, b) => (b.distanceM > 0 || a.distanceM > 0) ? b.distanceM.compareTo(a.distanceM) : b.loadScore.compareTo(a.loadScore));
    final visible = rows.take(12).toList(growable: false);
    return _Panel(title: 'Лидеры команды', subtitle: '${rows.length} игроков', child: rows.isEmpty
        ? const _Empty(icon: Icons.groups_rounded, text: 'Командная статистика появится после обработки сессий.')
        : ListView(children: [
            for (var i = 0; i < visible.length; i++)
              _ListRow(
                icon: Icons.person_rounded,
                title: '${i + 1}. ${visible[i].playerName}',
                subtitle: '${_meters(visible[i].distanceM)} · ${visible[i].maxSpeedKmh.toStringAsFixed(1)} км/ч · ${visible[i].sprintCount} спринтов',
              ),
          ]));
  }
}

class _PlayerRanking extends StatelessWidget {
  const _PlayerRanking({required this.players, required this.mode, this.onTap});
  final List<TrackerPlayerLoadRow> players;
  final _RankingMode mode;
  final ValueChanged<TrackerPlayerLoadRow>? onTap;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const _Empty(icon: Icons.leaderboard_rounded, text: 'Нет обработанных данных для рейтинга.');
    final visible = players.take(14).toList(growable: false);
    return ListView(children: [
      for (var i = 0; i < visible.length; i++)
        _ListRow(
          icon: mode == _RankingMode.sprints ? Icons.flash_on_rounded : (mode == _RankingMode.speed ? Icons.speed_rounded : (mode == _RankingMode.load ? Icons.bolt_rounded : Icons.route_rounded)),
          title: '${i + 1}. ${visible[i].playerName}',
          subtitle: '${_meters(visible[i].distanceM)} · max ${visible[i].maxSpeedKmh.toStringAsFixed(1)} км/ч · SPR ${visible[i].sprintCount} · Load ${visible[i].loadScore.toStringAsFixed(0)}',
          trailing: _valueText(visible[i]),
          onTap: onTap == null ? null : () => onTap!(visible[i]),
        ),
    ]);
  }

  String _valueText(TrackerPlayerLoadRow p) {
    switch (mode) {
      case _RankingMode.speed:
        return '${p.maxSpeedKmh.toStringAsFixed(1)} км/ч';
      case _RankingMode.sprints:
        return '${p.sprintCount}';
      case _RankingMode.load:
        return p.loadScore.toStringAsFixed(0);
      case _RankingMode.distance:
      default:
        return _meters(p.distanceM);
    }
  }
}

enum _RankingMode { distance, sprints, speed, load }

class _TeamTable extends StatelessWidget {
  const _TeamTable({required this.rows, required this.selectedPlayer, required this.onSelectPlayer});
  final List<TrackerPlayerLoadRow> rows;
  final TrackerPlayerOption? selectedPlayer;
  final ValueChanged<int> onSelectPlayer;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty(icon: Icons.table_chart_rounded, text: 'Нет командных данных.');
    return ListView(children: [
      for (var i = 0; i < rows.length; i++)
        _ListRow(
          icon: Icons.person_rounded,
          title: '${i + 1}. ${rows[i].playerName}',
          subtitle: '${_meters(rows[i].distanceM)} · HIR ${_meters(rows[i].highSpeedDistanceM)} · Уск/торм ${rows[i].accelerationCount}/${rows[i].decelerationCount} · Load ${rows[i].loadScore.toStringAsFixed(0)}',
          trailing: '${rows[i].maxSpeedKmh.toStringAsFixed(1)} км/ч',
          active: selectedPlayer?.id == rows[i].playerId,
          onTap: rows[i].playerId == null ? null : () => onSelectPlayer(rows[i].playerId!),
        ),
    ]);
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session, this.local});
  final TrackerSessionModel session;
  final _LocalTrackAnalysis? local;

  @override
  Widget build(BuildContext context) {
    final l = local;
    final distance = (l?.distanceM ?? 0) > 0 ? l!.distanceM : session.distanceM;
    final maxSpeed = (l?.maxSpeedKmh ?? 0) > 0 ? l!.maxSpeedKmh : session.maxSpeedKmh;
    final sprintCount = (l?.sprintCount ?? 0) > 0 ? l!.sprintCount : session.sprintCount;
    final sprintDistance = (l?.sprintDistanceM ?? 0) > 0 ? l!.sprintDistanceM : session.sprintDistanceM;
    final accel = (l?.accelCount ?? 0) > 0 ? l!.accelCount : session.accelCount;
    final decel = (l?.decelCount ?? 0) > 0 ? l!.decelCount : session.decelCount;
    final load = session.loadScore > 0 ? session.loadScore : (distance / 10.0 + sprintDistance * .35 + (accel + decel) * 2.5);
    return Column(children: [
      _InfoLine(title: 'Игрок', value: session.playerName ?? 'Команда'),
      _InfoLine(title: 'Дата', value: _formatSessionDateTime(session.createdAt)),
      _InfoLine(title: 'Дистанция', value: _meters(distance)),
      _InfoLine(title: 'Макс. скорость', value: '${maxSpeed.toStringAsFixed(1)} км/ч'),
      _InfoLine(title: 'Спринты', value: '$sprintCount · ${_meters(sprintDistance)}'),
      _InfoLine(title: 'Ускорения / торможения', value: '$accel / $decel'),
      _InfoLine(title: 'Нагрузка', value: '${load.toStringAsFixed(0)} · ${session.loadPerMinute.toStringAsFixed(1)}/мин'),
      const SizedBox(height: 0),
      const _Hint(text: 'Выгрузка находится в разделе «Отчёт»: там выбираются игроки, таблицы, пульс, сравнение и нужные графики для PDF / Excel.'),
    ]);
  }
}

class _CalibrationMini extends StatelessWidget {
  const _CalibrationMini({required this.field});
  final TrackerFieldModel? field;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CalibrationMiniPainter(field: field), child: const SizedBox.expand());
  }
}

class _SessionAvatar extends StatelessWidget {
  const _SessionAvatar({required this.player});
  final TrackerPlayerOption? player;

  @override
  Widget build(BuildContext context) {
    final avatar = player?.avatar;
    final initials = (player?.name ?? 'И').trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2).map((e) => e.substring(0, 1)).join().toUpperCase();
    return Container(
      width: 28,
      height: 28,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_AA.mobileInnerRadius)),
      child: avatar != null && avatar.isNotEmpty
          ? Image.network(avatar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(initials.isEmpty ? 'И' : initials, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700))))
          : Center(child: Text(initials.isEmpty ? 'И' : initials, style: const TextStyle(color: _AA.text, fontSize: 10.4, fontWeight: FontWeight.w700))),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.icon, required this.title, required this.subtitle, this.trailing, this.active = false, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: active ? _AA.soft : _AA.card,
          border: const Border(bottom: BorderSide(color: _AA.line)),
        ),
        child: Row(children: [
          Container(width: 24, height: 24, alignment: Alignment.center, decoration: BoxDecoration(color: active ? _AA.green.withOpacity(.10) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: active ? _AA.green : _AA.muted, size: 15)),
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 11.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 1),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.muted, fontSize: 9.6, fontWeight: FontWeight.w600)),
          ])),
          if (trailing != null)
            Flexible(
              fit: FlexFit.loose,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(trailing!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(color: _AA.green, fontSize: 9.6, fontWeight: FontWeight.w700)),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: _AA.muted, size: 18),
        ]),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(color: _AA.muted, fontSize: 10.4, fontWeight: FontWeight.w700))),
        Flexible(child: Text(value, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AA.text, fontSize: 9.6, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _ZoneLine extends StatelessWidget {
  const _ZoneLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => _InfoLine(title: label, value: value);
}


class _SliderLine extends StatelessWidget {
  const _SliderLine({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: _AA.text, fontSize: 9.6, fontWeight: FontWeight.w700))),
          Text('${value.toStringAsFixed(suffix == '°' ? 0 : 1)} $suffix', style: const TextStyle(color: _AA.green, fontSize: 9.6, fontWeight: FontWeight.w700)),
        ]),
        Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, divisions: divisions, label: value.toStringAsFixed(1), onChanged: onChanged),
      ]),
    );
  }
}

class _ChoiceLine extends StatelessWidget {
  const _ChoiceLine({required this.label, required this.value, required this.values, required this.onChanged});

  final String label;
  final String value;
  final Map<String, String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: _AA.text, fontSize: 9.6, fontWeight: FontWeight.w700))),
        DropdownButton<String>(
          value: values.containsKey(value) ? value : values.keys.first,
          underline: const SizedBox.shrink(),
          items: values.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ]),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: primary ? _AA.green : _AA.card, borderRadius: BorderRadius.circular(4), border: Border.all(color: primary ? _AA.green : _AA.line)),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: primary ? Colors.white : _AA.green),
          const SizedBox(width: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: primary ? Colors.white : _AA.text, fontSize: 9.6, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _AA.green.withOpacity(.08))),
      child: Text(text, style: const TextStyle(color: _AA.muted, fontSize: 10.4, height: 1.25, fontWeight: FontWeight.w600)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: _AA.muted, size: 28),
      const SizedBox(height: 0),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _AA.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
    ]));
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Panel(title: 'Ошибка аналитики', subtitle: 'сервер или данные', child: Column(children: [
      Expanded(child: _Empty(icon: Icons.error_outline_rounded, text: error)),
      _SmallButton(icon: Icons.refresh_rounded, label: 'Повторить', onTap: onRetry),
    ]));
  }
}


class _SprintSegment {
  const _SprintSegment(this.from, this.to, this.speedKmh);
  final ActionTrackerGpsPoint from;
  final ActionTrackerGpsPoint to;
  final double speedKmh;

  static List<_SprintSegment> fromPoints(List<ActionTrackerGpsPoint> points, {required double thresholdKmh}) {
    if (points.length < 2) return const <_SprintSegment>[];
    final out = <_SprintSegment>[];
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (_segmentBreaks(a, b)) continue;
      final speed = _segmentSpeed(points, i);
      if (!speed.isFinite || speed <= 0 || speed > 45) continue;
      if (speed >= thresholdKmh) out.add(_SprintSegment(a, b, speed));
    }
    return out;
  }
}


List<int> _turnPoints(List<ActionTrackerGpsPoint> points) {
  if (points.length < 3) return const <int>[];
  final out = <int>[];
  final bounds = _Bounds.fromGps(points);
  const size = Size(105, 68);
  for (var i = 2; i < points.length; i++) {
    if (_segmentBreaks(points[i - 2], points[i - 1]) || _segmentBreaks(points[i - 1], points[i])) continue;
    final prev = bounds.project(points[i - 2], size);
    final a = bounds.project(points[i - 1], size);
    final b = bounds.project(points[i], size);
    final v1 = a - prev;
    final v2 = b - a;
    if (v1.distance < .2 || v2.distance < .2) continue;
    final dot = ((v1.dx * v2.dx + v1.dy * v2.dy) / (v1.distance * v2.distance)).clamp(-1.0, 1.0);
    if (math.acos(dot) > .75) out.add(i - 1);
  }
  return out;
}

class _ActionPitchPainter extends CustomPainter {
  _ActionPitchPainter({
    required this.heat,
    required this.local,
    required this.field,
    this.sprintThresholdKmh = 18.0,
    this.hsrThresholdKmh = 14.0,
    this.activityFilter = 'all',
    this.showSprintArrows = true,
    this.mapRotationDeg = 0,
  });

  final List<TrackerHeatPoint> heat;
  final List<ActionTrackerGpsPoint> local;
  final TrackerFieldModel? field;
  final double sprintThresholdKmh;
  final double hsrThresholdKmh;
  final String activityFilter;
  final bool showSprintArrows;
  final double mapRotationDeg;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (mapRotationDeg.abs() > .1) {
      final center = Offset(size.width / 2, size.height / 2);
      canvas.translate(center.dx, center.dy);
      canvas.rotate(mapRotationDeg * math.pi / 180.0);
      canvas.translate(-center.dx, -center.dy);
    }

    _drawPitch(canvas, size);
    if (heat.isNotEmpty) {
      final inner = _pitchInnerRect(size);
      final maxHeat = heat.map((p) => p.value).fold<double>(1.0, math.max);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(inner, const Radius.circular(12)));
      for (final p in heat.take(1600)) {
        final nx = (p.x.abs() <= 1.2 ? p.x : p.x / 105.0).clamp(0.0, 1.0).toDouble();
        final ny = (p.y.abs() <= 1.2 ? p.y : p.y / 68.0).clamp(0.0, 1.0).toDouble();
        final ratio = (p.value / maxHeat).clamp(0.0, 1.0).toDouble();
        final center = Offset(inner.left + nx * inner.width, inner.top + ny * inner.height);
        final r = heat.length <= 2 ? 18.0 : (12.0 + ratio * 26.0);
        final color = Color.lerp(const Color(0xFF22C55E), const Color(0xFFDC2626), ratio) ?? _AA.green;
        final paint = Paint()
          ..shader = RadialGradient(colors: [color.withOpacity(.55), color.withOpacity(.24), color.withOpacity(0.0)], stops: const [0.0, .50, 1.0]).createShader(Rect.fromCircle(center: center, radius: r));
        canvas.drawCircle(center, r, paint);
      }
      canvas.restore();
    }

    if (local.length > 1) {
      final bounds = _Bounds.fromGps(local);
      final useFieldProjection = _shouldUseFieldProjection(local, field);
      final turnIndexes = activityFilter == 'turn' ? _turnPoints(local).toSet() : const <int>{};
      for (var i = 1; i < local.length; i++) {
        final aPoint = local[i - 1];
        final bPoint = local[i];
        final a = _project(aPoint, size, bounds, useFieldProjection);
        final b = _project(bPoint, size, bounds, useFieldProjection);
        if (_segmentBreaks(aPoint, bPoint)) continue;
        final speed = _segmentSpeed(local, i);
        if (!speed.isFinite || speed <= 0) continue;
        final matchesActivity = activityFilter == 'turn'
            ? turnIndexes.contains(i)
            : _segmentMatchesActivity(speed, activityFilter, hsrThresholdKmh: hsrThresholdKmh, sprintThresholdKmh: sprintThresholdKmh);
        if (!matchesActivity) continue;
        final color = speed >= sprintThresholdKmh
            ? _AA.red
            : (speed >= hsrThresholdKmh ? _AA.orange : (speed >= 7 ? _AA.green : _AA.blue));
        final glowPaint = Paint()
          ..color = color.withOpacity(speed >= sprintThresholdKmh ? .18 : .08)
          ..strokeWidth = speed >= sprintThresholdKmh ? 8.0 : 5.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(a, b, glowPaint);

        final segmentPaint = Paint()
          ..color = color.withOpacity(speed >= sprintThresholdKmh ? .97 : .84)
          ..strokeWidth = speed >= sprintThresholdKmh
              ? 3.2
              : (speed >= hsrThresholdKmh ? 2.7 : 1.9)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(a, b, segmentPaint);
        if (showSprintArrows && (i % 14 == 0 || speed >= sprintThresholdKmh)) {
          _drawArrowHead(canvas, a, b, Paint()..color = color.withOpacity(.92)..style = PaintingStyle.fill);
        }
        if (i > 1) {
          final prev = _project(local[i - 2], size, bounds, useFieldProjection);
          final v1 = a - prev;
          final v2 = b - a;
          final l1 = v1.distance;
          final l2 = v2.distance;
          if (l1 > 5 && l2 > 5) {
            final dot = ((v1.dx * v2.dx + v1.dy * v2.dy) / (l1 * l2)).clamp(-1.0, 1.0);
            final angle = math.acos(dot);
            if (angle > .75) {
              canvas.drawCircle(a, 3.3, Paint()..color = _AA.orange.withOpacity(.95));
              canvas.drawCircle(a, 5.2, Paint()..color = _AA.orange.withOpacity(.08));
            }
          }
        }
      }

      // Отдельный слой GPS-точек: в фильтре точка получает скорость именно
      // выбранного отрезка. Иначе начало отрезка могло подсвечиваться цветом
      // предыдущего сегмента, и карта отчёта визуально расходилась с аналитикой.
      final visiblePointSpeeds = <int, double>{};
      if (activityFilter != 'all') {
        for (var i = 1; i < local.length; i++) {
          final aPoint = local[i - 1];
          final bPoint = local[i];
          if (_segmentBreaks(aPoint, bPoint)) continue;
          final speed = _segmentSpeed(local, i);
          final matchesActivity = activityFilter == 'turn'
              ? turnIndexes.contains(i)
              : _segmentMatchesActivity(speed, activityFilter, hsrThresholdKmh: hsrThresholdKmh, sprintThresholdKmh: sprintThresholdKmh);
          if (matchesActivity) {
            visiblePointSpeeds[i - 1] = speed;
            visiblePointSpeeds[i] = speed;
          }
        }
      }
      for (var i = 0; i < local.length; i++) {
        if (activityFilter != 'all' && !visiblePointSpeeds.containsKey(i)) continue;
        final current = local[i];
        final o = _project(current, size, bounds, useFieldProjection);
        double speed = visiblePointSpeeds[i] ?? 0.0;
        if (activityFilter == 'all' && i > 0 && !_segmentBreaks(local[i - 1], current)) {
          speed = _segmentSpeed(local, i);
        }
        final c = speed >= sprintThresholdKmh ? _AA.red : (speed >= hsrThresholdKmh ? _AA.orange : (speed >= 7 ? _AA.green : _AA.blue));
        final r = speed >= sprintThresholdKmh ? 4.8 : (speed >= 7 ? 3.8 : 3.0);
        canvas.drawCircle(o, r + 2.8, Paint()..color = c.withOpacity(.08));
        canvas.drawCircle(o, r, Paint()..color = c.withOpacity(.95));
        if (i == 0 || i == local.length - 1 || speed >= sprintThresholdKmh || i % 8 == 0) {
          _paintChartText(canvas, speed.toStringAsFixed(1), o + const Offset(6, -10), 8.0, c);
        }
      }

      double? prevSpeed;
      for (var i = 1; i < local.length; i++) {
        final aPoint = local[i - 1];
        final bPoint = local[i];
        if (_segmentBreaks(aPoint, bPoint)) { prevSpeed = null; continue; }
        final rawDtMs = (bPoint.timeMs - aPoint.timeMs).abs();
        final dtMs = rawDtMs <= 0 ? 1000 : rawDtMs;
        final speed = _segmentSpeed(local, i);
        if (speed <= 0) continue;
        if (prevSpeed != null) {
          final acc = ((speed - prevSpeed!) / 3.6) / (dtMs / 1000.0);
          if (acc.abs() >= 1.0) {
            final o = _project(bPoint, size, bounds, useFieldProjection);
            final c = acc > 0 ? _AA.green : _AA.red;
            canvas.drawCircle(o, 4.0, Paint()..color = c.withOpacity(.92));
            canvas.drawCircle(o, 7.0, Paint()..color = c.withOpacity(.08));
          }
        }
        prevSpeed = speed;
      }
    }    canvas.restore();
  }


  Offset _project(ActionTrackerGpsPoint p, Size size, _Bounds bounds, bool useFieldProjection) {
    if (useFieldProjection) {
      final projected = TrackerPitchProjector.projectGps(field, latitude: p.latitude, longitude: p.longitude);
      if (projected != null) {
        return _fitPointToPitch(Offset(projected.clampedNx * size.width, projected.clampedNy * size.height), size);
      }
    }
    return _fitPointToPitch(bounds.project(p, size), size);
  }

  void _drawArrowHead(Canvas canvas, Offset a, Offset b, Paint paint) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 7) return;
    final ux = dx / len;
    final uy = dy / len;
    final tip = b;
    final left = Offset(tip.dx - ux * 10 - uy * 5, tip.dy - uy * 10 + ux * 5);
    final right = Offset(tip.dx - ux * 10 + uy * 5, tip.dy - uy * 10 - ux * 5);
    final path = Path()..moveTo(tip.dx, tip.dy)..lineTo(left.dx, left.dy)..lineTo(right.dx, right.dy)..close();
    canvas.drawPath(path, paint);
  }

  void _drawPitch(Canvas canvas, Size size) {
    final border = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.drawRRect(border, Paint()..color = const Color(0xFF76947B));
    final clip = Path()..addRRect(border.deflate(8));
    canvas.save();
    canvas.clipPath(clip);
    final stripeW = math.max(36.0, size.width / 12);
    for (var i = 0; i < 14; i++) {
      final color = i.isEven ? const Color(0xFF719078) : const Color(0xFF819E86);
      canvas.drawRect(Rect.fromLTWH(8 + i * stripeW, 8, stripeW, size.height - 16), Paint()..color = color);
    }
    canvas.restore();
    final line = Paint()..color = Colors.white.withOpacity(.78)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final inner = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    canvas.drawRRect(RRect.fromRectAndRadius(inner, const Radius.circular(12)), line);
    canvas.drawLine(Offset(size.width / 2, 10), Offset(size.width / 2, size.height - 10), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), math.min(size.width, size.height) * .12, line);
    canvas.drawRect(Rect.fromLTWH(10, size.height * .28, size.width * .17, size.height * .44), line);
    canvas.drawRect(Rect.fromLTWH(10, size.height * .38, size.width * .08, size.height * .24), line);
    canvas.drawRect(Rect.fromLTWH(size.width - 10 - size.width * .17, size.height * .28, size.width * .17, size.height * .44), line);
    canvas.drawRect(Rect.fromLTWH(size.width - 10 - size.width * .08, size.height * .38, size.width * .08, size.height * .24), line);
    canvas.drawCircle(Offset(size.width * .13, size.height / 2), 3, Paint()..color = Colors.white.withOpacity(.75));
    canvas.drawCircle(Offset(size.width * .87, size.height / 2), 3, Paint()..color = Colors.white.withOpacity(.75));
  }

  @override
  bool shouldRepaint(covariant _ActionPitchPainter oldDelegate) =>
      oldDelegate.heat != heat ||
      oldDelegate.local != local ||
      oldDelegate.field != field ||
      oldDelegate.sprintThresholdKmh != sprintThresholdKmh ||
      oldDelegate.hsrThresholdKmh != hsrThresholdKmh ||
      oldDelegate.activityFilter != activityFilter ||
      oldDelegate.showSprintArrows != showSprintArrows ||
      oldDelegate.mapRotationDeg != mapRotationDeg;
}

class _Bounds {
  const _Bounds(this.minLat, this.maxLat, this.minLng, this.maxLng);
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  factory _Bounds.fromGps(List<ActionTrackerGpsPoint> points) {
    var minLat = points.first.latitude, maxLat = points.first.latitude, minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude); maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude); maxLng = math.max(maxLng, p.longitude);
    }
    if ((maxLat - minLat).abs() < .00001) maxLat += .00001;
    if ((maxLng - minLng).abs() < .00001) maxLng += .00001;
    return _Bounds(minLat, maxLat, minLng, maxLng);
  }

  Offset project(ActionTrackerGpsPoint p, Size size) {
    final x = ((p.longitude - minLng) / (maxLng - minLng)).clamp(0.0, 1.0) * size.width;
    final y = (1 - ((p.latitude - minLat) / (maxLat - minLat)).clamp(0.0, 1.0)) * size.height;
    return Offset(x, y);
  }
}


List<double> _stableChartSpeedSamples(List<double> samples) {
  final clean = samples.where((v) => v.isFinite && v >= 0 && v <= 45).toList(growable: false);
  if (clean.length < 3) return clean;
  final out = <double>[];
  for (var i = 0; i < clean.length; i++) {
    final v = clean[i];
    if (i > 0 && i < clean.length - 1) {
      final prev = clean[i - 1];
      final next = clean[i + 1];
      final neighborMax = math.max(prev, next);
      if (v > 24 && v - neighborMax > 12) {
        out.add((prev + next) / 2.0);
        continue;
      }
    }
    out.add(v);
  }
  return out;
}

double _speedChartMax(List<double> samples, double maxSpeedKmh, double hsrThresholdKmh, double sprintThresholdKmh) {
  final stable = _stableChartSpeedSamples(samples);
  final sampleMax = stable.isEmpty ? 0.0 : stable.reduce(math.max);
  final dataMax = math.max(sampleMax, maxSpeedKmh > 0 && maxSpeedKmh <= 42 ? maxSpeedKmh : 0.0);
  final thresholdMax = math.max(sprintThresholdKmh * 1.18, hsrThresholdKmh * 1.34);
  final wanted = math.max(thresholdMax, dataMax * 1.10);
  return math.max(10.0, math.min(38.0, wanted)).toDouble();
}

class _SpeedPainter extends CustomPainter {
  _SpeedPainter({
    required this.samples,
    required this.hsrThresholdKmh,
    required this.sprintThresholdKmh,
    required this.maxSpeedKmh,
  });

  final List<double> samples;
  final double hsrThresholdKmh;
  final double sprintThresholdKmh;
  final double maxSpeedKmh;

  @override
  void paint(Canvas canvas, Size size) {
    final chartSamples = _stableChartSpeedSamples(samples);
    final maxV = _speedChartMax(chartSamples, maxSpeedKmh, hsrThresholdKmh, sprintThresholdKmh);
    final rect = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)), Paint()..color = Colors.white);

    void drawZone(double from, double to, Color color) {
      final top = size.height - (to / maxV).clamp(0.0, 1.0) * size.height;
      final bottom = size.height - (from / maxV).clamp(0.0, 1.0) * size.height;
      canvas.drawRect(Rect.fromLTRB(0, top, size.width, bottom), Paint()..color = color.withOpacity(.05));
    }

    drawZone(hsrThresholdKmh, sprintThresholdKmh, _AA.orange);
    drawZone(sprintThresholdKmh, maxV, _AA.red);

    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = _AA.line.withOpacity(.50)..strokeWidth = .7);
      final value = maxV * (4 - i) / 4;
      _paintChartText(canvas, value.toStringAsFixed(0), Offset(5, y + 2), 8.4, _AA.muted, alignLeft: true);
    }

    _drawThreshold(canvas, size, maxV, hsrThresholdKmh, _AA.orange, 'HIR ${hsrThresholdKmh.toStringAsFixed(1)}');
    _drawThreshold(canvas, size, maxV, sprintThresholdKmh, _AA.red, 'SPR ${sprintThresholdKmh.toStringAsFixed(1)}');

    if (chartSamples.length < 2) {
      _paintChartText(canvas, 'Нет GPS-точек скорости', Offset(size.width / 2, size.height / 2), 11, _AA.muted);
      return;
    }

    final points = <Offset>[];
    for (var i = 0; i < chartSamples.length; i++) {
      final x = i / (chartSamples.length - 1) * size.width;
      final y = size.height - (chartSamples[i] / maxV).clamp(0.0, 1.0) * size.height;
      points.add(Offset(x, y));
    }

    Path smoothPath(List<Offset> values) {
      final path = Path()..moveTo(values.first.dx, values.first.dy);
      for (var i = 1; i < values.length; i++) {
        final previous = values[i - 1];
        final current = values[i];
        final middleX = (previous.dx + current.dx) / 2;
        path.cubicTo(middleX, previous.dy, middleX, current.dy, current.dx, current.dy);
      }
      return path;
    }

    final linePath = smoothPath(points);
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_AA.green.withOpacity(.18), _AA.green.withOpacity(.02)]).createShader(rect));
    canvas.drawPath(linePath, Paint()..color = _AA.green.withOpacity(.14)..strokeWidth = 7..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawPath(linePath, Paint()..color = _AA.green..strokeWidth = 2.4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    final keyIndexes = <int>{0, chartSamples.length - 1};
    var maxIndex = 0;
    for (var i = 1; i < chartSamples.length; i++) {
      if (chartSamples[i] > chartSamples[maxIndex]) maxIndex = i;
      final localPeak = i < chartSamples.length - 1 && chartSamples[i] > chartSamples[i - 1] && chartSamples[i] > chartSamples[i + 1];
      if (localPeak && chartSamples[i] >= hsrThresholdKmh) keyIndexes.add(i);
    }
    keyIndexes.add(maxIndex);

    for (final index in keyIndexes) {
      final value = chartSamples[index];
      final color = value >= sprintThresholdKmh ? _AA.red : value >= hsrThresholdKmh ? _AA.orange : _AA.green;
      canvas.drawCircle(points[index], 7, Paint()..color = color.withOpacity(.11));
      canvas.drawCircle(points[index], 3.8, Paint()..color = Colors.white);
      canvas.drawCircle(points[index], 2.8, Paint()..color = color);
      _paintChartText(canvas, value.toStringAsFixed(1), points[index] + const Offset(0, -14), index == maxIndex ? 9.5 : 8.5, color);
    }

    final displayedMax = maxSpeedKmh > 0 ? maxSpeedKmh : chartSamples.reduce(math.max);
    _paintChartText(canvas, 'МАКС. ${displayedMax.toStringAsFixed(1)} КМ/Ч', const Offset(10, 12), 9.8, _AA.text, alignLeft: true);
  }

  void _drawThreshold(Canvas canvas, Size size, double maxV, double value, Color color, String label) {
    if (value <= 0 || maxV <= 0) return;
    final y = size.height - (value / maxV).clamp(0.0, 1.0) * size.height;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = color.withOpacity(.46)..strokeWidth = .9);
    _paintChartText(canvas, label, Offset(size.width - 7, math.max(9.0, y - 8).toDouble()), 8.8, color, alignLeft: false);
  }

  @override
  bool shouldRepaint(covariant _SpeedPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.hsrThresholdKmh != hsrThresholdKmh ||
        oldDelegate.sprintThresholdKmh != sprintThresholdKmh ||
        oldDelegate.maxSpeedKmh != maxSpeedKmh;
  }
}

class _SprintPainter extends CustomPainter {
  _SprintPainter({required this.samples, required this.hsrThresholdKmh, required this.sprintThresholdKmh, required this.maxSpeedKmh});
  final List<double> samples;
  final double hsrThresholdKmh;
  final double sprintThresholdKmh;
  final double maxSpeedKmh;

  @override
  void paint(Canvas canvas, Size size) {
    _chartBg(canvas, size);
    final chartSamples = _stableChartSpeedSamples(samples);
    if (chartSamples.length < 2) {
      _paintChartText(canvas, 'Нет сохранённых точек скорости', Offset(size.width / 2, size.height / 2), 10.5, _AA.muted);
      return;
    }
    final double maxV = _speedChartMax(chartSamples, maxSpeedKmh, hsrThresholdKmh, sprintThresholdKmh);
    void threshold(double value, Color color, String label) {
      final y = size.height - (value / maxV).clamp(0.0, 1.0) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = color.withOpacity(.52)..strokeWidth = 1);
      _paintChartText(canvas, label, Offset(6, math.max(9.0, y - 9).toDouble()), 8.2, color, alignLeft: true);
    }

    threshold(hsrThresholdKmh, _AA.orange, 'HIR ${hsrThresholdKmh.toStringAsFixed(1)}');
    threshold(sprintThresholdKmh, _AA.red, 'SPR ${sprintThresholdKmh.toStringAsFixed(1)}');

    for (var i = 0; i <= 4; i++) {
      final value = maxV * (4 - i) / 4;
      final y = i / 4 * size.height;
      _paintChartText(canvas, value.toStringAsFixed(0), Offset(size.width - 5, y + 2), 7.5, _AA.muted, alignLeft: false);
    }

    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < chartSamples.length; i++) {
      final x = i / (chartSamples.length - 1) * size.width;
      final y = size.height - (chartSamples[i] / maxV).clamp(0.0, 1.0) * size.height;
      final o = Offset(x, y);
      points.add(o);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(path, Paint()..color = _AA.green..strokeWidth = 1.8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    final sprintPaint = Paint()..color = _AA.red..strokeWidth = 3.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final hirPaint = Paint()..color = _AA.orange.withOpacity(.70)..strokeWidth = 2.4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    var sprintPoints = 0;
    var hsrPoints = 0;
    for (var i = 1; i < points.length; i++) {
      final a = chartSamples[i - 1];
      final b = chartSamples[i];
      if (a >= sprintThresholdKmh || b >= sprintThresholdKmh) {
        sprintPoints++;
        canvas.drawLine(points[i - 1], points[i], sprintPaint);
      } else if (a >= hsrThresholdKmh || b >= hsrThresholdKmh) {
        hsrPoints++;
        canvas.drawLine(points[i - 1], points[i], hirPaint);
      }
    }

    final every = math.max(1, chartSamples.length ~/ 7);
    for (var i = 0; i < points.length; i += every) {
      final v = chartSamples[i];
      final c = v >= sprintThresholdKmh ? _AA.red : (v >= hsrThresholdKmh ? _AA.orange : _AA.green);
      canvas.drawCircle(points[i], 3.3, Paint()..color = c);
      canvas.drawCircle(points[i], 6.0, Paint()..color = c.withOpacity(.06));
      _paintChartText(canvas, v.toStringAsFixed(1), points[i] + const Offset(0, -13), 7.7, c);
    }

    final displayMax = maxSpeedKmh > 0 ? maxSpeedKmh : chartSamples.reduce(math.max);
    _paintChartText(canvas, 'max ${displayMax.toStringAsFixed(1)} км/ч', Offset(size.width - 8, 8), 8.4, _AA.text);
    _paintChartText(canvas, 'SPR участков $sprintPoints · HIR $hsrPoints', const Offset(6, 8), 8.4, _AA.muted, alignLeft: true);
  }

  @override
  bool shouldRepaint(covariant _SprintPainter oldDelegate) => oldDelegate.samples != samples || oldDelegate.hsrThresholdKmh != hsrThresholdKmh || oldDelegate.sprintThresholdKmh != sprintThresholdKmh || oldDelegate.maxSpeedKmh != maxSpeedKmh;
}

class _ActivityRadarPainter extends CustomPainter {
  const _ActivityRadarPainter({required this.axes});
  final List<_ActivityAxisValue> axes;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * .34;
    final grid = Paint()..color = _AA.line..style = PaintingStyle.stroke..strokeWidth = 1;
    for (var ring = 1; ring <= 4; ring++) {
      canvas.drawCircle(c, r * ring / 4, grid);
    }
    if (axes.isEmpty) return;
    final path = Path();
    for (var i = 0; i < axes.length; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / axes.length;
      final end = c + Offset(math.cos(a) * r, math.sin(a) * r);
      canvas.drawLine(c, end, grid);
      final labelPos = c + Offset(math.cos(a) * (r + 18), math.sin(a) * (r + 18));
      _paintChartText(canvas, axes[i].label, labelPos, 8.6, _AA.muted);
      final p = c + Offset(math.cos(a) * r * axes[i].value.clamp(0.0, 1.0), math.sin(a) * r * axes[i].value.clamp(0.0, 1.0));
      if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = _AA.green.withOpacity(.08)..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = _AA.green..style = PaintingStyle.stroke..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(covariant _ActivityRadarPainter oldDelegate) => oldDelegate.axes != axes;
}

class _MiniHeatmapPainter extends CustomPainter {
  const _MiniHeatmapPainter({required this.points});
  final List<TrackerHeatPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFEFFAF3);
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4));
    canvas.drawRRect(rect, bg);
    final line = Paint()..color = _AA.green.withOpacity(.40)..style = PaintingStyle.stroke..strokeWidth = 1;
    final inner = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRect(inner, line);
    canvas.drawLine(Offset(size.width / 2, 8), Offset(size.width / 2, size.height - 8), line);
    if (points.isEmpty) {
      _paintChartText(canvas, 'Нет теплокарты сессии', Offset(size.width / 2, size.height / 2), 9.2, _AA.muted);
      return;
    }
    final maxValue = points.map((p) => p.value).fold<double>(1, math.max);
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in points.take(350)) {
      final x = inner.left + (p.x / 105.0).clamp(0.0, 1.0) * inner.width;
      final y = inner.top + (p.y / 68.0).clamp(0.0, 1.0) * inner.height;
      final ratio = (p.value / maxValue).clamp(0.0, 1.0).toDouble();
      paint.color = Color.lerp(_AA.green.withOpacity(.07), _AA.red.withOpacity(.48), ratio) ?? _AA.green.withOpacity(.2);
      canvas.drawCircle(Offset(x, y), 2.5 + ratio * 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniHeatmapPainter oldDelegate) => oldDelegate.points != points;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.rows, this.baselineRows = const <TrackerPlayerLoadRow>[]});
  final List<TrackerPlayerLoadRow> rows;
  final List<TrackerPlayerLoadRow> baselineRows;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * .36;
    final grid = Paint()..color = _AA.line..style = PaintingStyle.stroke..strokeWidth = 1;
    for (var ring = 1; ring <= 4; ring++) {
      canvas.drawCircle(c, r * ring / 4, grid);
    }
    final axes = 5;
    final labels = ['объём', 'скорость', 'спринты', 'HIR', 'нагрузка'];
    for (var i = 0; i < axes; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / axes;
      final end = c + Offset(math.cos(a) * r, math.sin(a) * r);
      canvas.drawLine(c, end, grid);
      final tp = c + Offset(math.cos(a) * (r + 18), math.sin(a) * (r + 18));
      _paintText(canvas, labels[i], tp, 10);
    }
    if (rows.isEmpty && baselineRows.isEmpty) return;

    final baseline = baselineRows.isNotEmpty ? _radarValues(baselineRows) : const <double>[];
    final values = _radarValues(rows);
    if (baseline.isNotEmpty) {
      _drawRadarPath(canvas, c, r, baseline, fill: _AA.muted.withOpacity(.08), stroke: _AA.muted.withOpacity(.55), strokeWidth: 1.35);
    }
    if (values.isNotEmpty) {
      _drawRadarPath(canvas, c, r, values, fill: _AA.green.withOpacity(.08), stroke: _AA.green, strokeWidth: 2.1);
    }
  }

  List<double> _radarValues(List<TrackerPlayerLoadRow> src) {
    if (src.isEmpty) return const <double>[];
    double avg(double Function(TrackerPlayerLoadRow r) pick) => src.map(pick).fold<double>(0, (a, b) => a + b) / src.length;
    double clamp(double v) => v.isNaN || v.isInfinite ? 0 : v.clamp(0.0, 1.0).toDouble();

    // Не нормируем по максимуму текущего списка: при одном игроке это всегда полный одинаковый пятиугольник.
    return <double>[
      clamp(avg((r) => r.distanceM) / 6000.0),
      clamp(avg((r) => r.maxSpeedKmh) / 34.0),
      clamp(avg((r) => r.sprintCount.toDouble()) / 25.0),
      clamp(avg((r) => r.highSpeedDistanceM) / 1200.0),
      clamp(avg((r) => r.loadScore) / 1000.0),
    ];
  }

  void _drawRadarPath(Canvas canvas, Offset c, double r, List<double> values, {required Color fill, required Color stroke, required double strokeWidth}) {
    if (values.isEmpty) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / values.length;
      final level = values[i].clamp(0.0, 1.0).toDouble();
      final p = c + Offset(math.cos(a) * r * level, math.sin(a) * r * level);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = strokeWidth);
  }

  void _paintText(Canvas canvas, String text, Offset center, double size) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(color: _AA.muted, fontSize: size, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.rows != rows || oldDelegate.baselineRows != baselineRows;
}

class _CalibrationMiniPainter extends CustomPainter {
  _CalibrationMiniPainter({required this.field});
  final TrackerFieldModel? field;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFEFFAF3);
    final line = Paint()..color = _AA.green.withOpacity(.45)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(rect, bg);
    canvas.drawRRect(rect.deflate(10), line);
    final ready = field?.hasCalibration == true;
    final points = [
      Offset(16, 16),
      Offset(size.width - 16, 16),
      Offset(size.width - 16, size.height - 16),
      Offset(16, size.height - 16),
    ];
    final labels = ['A', 'B', 'C', 'D'];
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(points[i], 10, Paint()..color = ready ? _AA.green : _AA.orange);
      final tp = TextPainter(text: TextSpan(text: labels[i], style: const TextStyle(color: Colors.white, fontSize: 10.4, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, points[i] - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CalibrationMiniPainter oldDelegate) => oldDelegate.field != field;
}

void _chartBg(Canvas canvas, Size size) {
  final line = Paint()..color = _AA.line..strokeWidth = 1;
  for (var i = 0; i <= 4; i++) {
    final y = i / 4 * size.height;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
  }
}

void _paintChartText(Canvas canvas, String text, Offset center, double size, Color color, {bool alignLeft = false}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final offset = alignLeft ? center : center - Offset(tp.width / 2, tp.height / 2);
  tp.paint(canvas, offset);
}


String _meters(double value) {
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)} км';
  return '${value.toStringAsFixed(0)} м';
}

String _time(int sec) {
  if (sec <= 0) return '0:00';
  final m = sec ~/ 60;
  final s = sec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

double _num(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

int _int(dynamic value, int fallback) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}


class _TrackerTimePickerSheet extends StatefulWidget {
  const _TrackerTimePickerSheet({required this.initial, required this.title});
  final TimeOfDay initial;
  final String title;

  @override
  State<_TrackerTimePickerSheet> createState() => _TrackerTimePickerSheetState();
}

class _TrackerTimePickerSheetState extends State<_TrackerTimePickerSheet> {
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour.clamp(0, 23).toInt();
    _minute = widget.initial.minute.clamp(0, 59).toInt();
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _popAfterMouseSettled<T>(BuildContext context, [T? result]) {
    Timer(const Duration(milliseconds: 140), () async {
      if (!context.mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      await Future<void>.delayed(Duration.zero);
      if (!context.mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      Navigator.pop<T>(context, result);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget wheel({required FixedExtentScrollController controller, required int count, required ValueChanged<int> onChanged}) {
      return Expanded(
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 38,
          diameterRatio: 1.4,
          perspective: .004,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (context, index) => Center(
              child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(color: _AA.text, fontSize: 21, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: SizedBox(
        height: 300,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _AA.line))),
            child: Row(children: [
              const Icon(Icons.schedule_rounded, color: _AA.green, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.title, style: const TextStyle(color: _AA.text, fontSize: 12.4, fontWeight: FontWeight.w700))),
              _NoHoverTap(onTap: () => _popAfterMouseSettled<void>(context), child: const SizedBox(width: 34, height: 34, child: Icon(Icons.close_rounded, color: _AA.muted, size: 18))),
            ]),
          ),
          Expanded(
            child: Row(children: [
              wheel(controller: _hourController, count: 24, onChanged: (v) => setState(() => _hour = v)),
              const Text(':', style: TextStyle(color: _AA.text, fontSize: 24, fontWeight: FontWeight.w700)),
              wheel(controller: _minuteController, count: 60, onChanged: (v) => setState(() => _minute = v)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(child: _NoHoverTap(onTap: () => _popAfterMouseSettled<void>(context), child: Container(height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: _AA.card, borderRadius: BorderRadius.circular(4)), child: const Text('Отмена', style: TextStyle(color: _AA.muted, fontWeight: FontWeight.w700))))),
              const SizedBox(width: 8),
              Expanded(child: _NoHoverTap(onTap: () => _popAfterMouseSettled<TimeOfDay>(context, TimeOfDay(hour: _hour, minute: _minute)), child: Container(height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: _AA.green, borderRadius: BorderRadius.circular(4)), child: const Text('Выбрать', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))),
            ]),
          ),
        ]),
      ),
    );
  }
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

  void _runAfterMouseUpdate(BuildContext context, VoidCallback? callback) {
    if (callback == null) return;
    Timer(const Duration(milliseconds: 90), () async {
      if (!context.mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      await Future<void>.delayed(Duration.zero);
      if (!context.mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      callback();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => _runAfterMouseUpdate(context, onTap),
      onLongPress: onLongPress == null ? null : () => _runAfterMouseUpdate(context, onLongPress),
      child: child,
    );
  }
}
