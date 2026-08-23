import 'package:flutter/material.dart';

import '../models/action_tracker_protocol.dart';
import '../models/tracker_pro_models.dart';
import '../services/tracker_pro_api.dart';
import 'player_training_calendar_panel.dart';
import 'tracker_action_analytics_suite.dart';

/// Единая публичная оболочка полной аналитики трекера.
/// Используется и в основном трекере, и в профиле игрока — без копирования
/// painters, графиков и логики выбора точек.
class TrackerSharedAnalysisPanel extends StatefulWidget {
  const TrackerSharedAnalysisPanel({
    super.key,
    required this.teamId,
    required this.playerId,
    required this.sessionId,
    required this.playerName,
    this.teamName = 'Команда',
    this.clubName = '',
    this.initialTab = 1,
  });

  final int teamId;
  final int playerId;
  final int sessionId;
  final String playerName;
  final String teamName;
  final String clubName;
  final int initialTab;

  @override
  State<TrackerSharedAnalysisPanel> createState() =>
      _TrackerSharedAnalysisPanelState();
}

class _TrackerSharedAnalysisPanelState
    extends State<TrackerSharedAnalysisPanel> {
  final TrackerProApi _api = TrackerProApi();

  bool _loading = true;
  String? _error;
  List<TrackerPlayerOption> _players = const <TrackerPlayerOption>[];
  List<TrackerSessionModel> _sessions = const <TrackerSessionModel>[];
  List<ActionTrackerGpsPoint> _points = const <ActionTrackerGpsPoint>[];
  TrackerPlayerOption? _selectedPlayer;
  TrackerSessionModel? _selectedSession;
  int _tabSignal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TrackerSharedAnalysisPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId ||
        oldWidget.playerId != widget.playerId ||
        oldWidget.sessionId != widget.sessionId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _api.loadPlayers(teamId: widget.teamId),
        _api.loadSessions(
          teamId: widget.teamId,
          playerId: widget.playerId > 0 ? widget.playerId : null,
          limit: 100,
          sessionKind: 'all',
        ),
        _api.loadSessionPoints(
          teamId: widget.teamId,
          playerId: widget.playerId > 0 ? widget.playerId : null,
          sessionId: widget.sessionId > 0 ? widget.sessionId : null,
          limit: 10000,
        ),
      ]);

      final players = results[0] as List<TrackerPlayerOption>;
      final sessions = results[1] as List<TrackerSessionModel>;
      final points = results[2] as List<ActionTrackerGpsPoint>;

      TrackerPlayerOption? selectedPlayer;
      for (final player in players) {
        if (player.id == widget.playerId ||
            player.identityIds.contains(widget.playerId)) {
          selectedPlayer = player;
          break;
        }
      }
      selectedPlayer ??= TrackerPlayerOption(
        id: widget.playerId,
        name: widget.playerName.trim().isEmpty ? 'Игрок' : widget.playerName,
        identityIds: widget.playerId > 0 ? <int>{widget.playerId} : const <int>{},
      );

      TrackerSessionModel? selectedSession;
      for (final session in sessions) {
        if (session.id == widget.sessionId) {
          selectedSession = session;
          break;
        }
      }
      if (selectedSession == null && sessions.isNotEmpty) {
        selectedSession = sessions.first;
      }

      if (!mounted) return;
      setState(() {
        _players = players.isEmpty ? <TrackerPlayerOption>[selectedPlayer!] : players;
        if (!_players.any((p) => p.id == selectedPlayer!.id)) {
          _players = <TrackerPlayerOption>[selectedPlayer!, ..._players];
        }
        _sessions = sessions;
        _points = points;
        _selectedPlayer = selectedPlayer;
        _selectedSession = selectedSession;
        _loading = false;
        _tabSignal++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _selectSession(TrackerSessionModel session) async {
    setState(() => _selectedSession = session);
    try {
      final points = await _api.loadSessionPoints(
        teamId: widget.teamId,
        playerId: _selectedPlayer?.id,
        sessionId: session.id,
        limit: 10000,
      );
      if (mounted) setState(() => _points = points);
    } catch (_) {}
  }

  void _selectPlayer(int playerId) {
    TrackerPlayerOption? player;
    for (final item in _players) {
      if (item.id == playerId || item.identityIds.contains(playerId)) {
        player = item;
        break;
      }
    }
    if (player != null) setState(() => _selectedPlayer = player);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 34),
            const SizedBox(height: 10),
            const Text('Не удалось загрузить аналитику трекера'),
            const SizedBox(height: 6),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }

    return TrackerActionAnalyticsSuite(
      api: _api,
      teamId: widget.teamId,
      teamName: widget.teamName,
      clubName: widget.clubName,
      players: _players,
      selectedPlayer: _selectedPlayer,
      playerFilterLabel: widget.playerName,
      selectedField: null,
      localPoints: _points,
      selectedSession: _selectedSession,
      onRefresh: _load,
      onSelectPlayer: _selectPlayer,
      onSelectSession: _selectSession,
      onOpenCalibration: () {},
      onOpenSessions: () {},
      onOpenLive: () {},
      onRequestOfflineRecords: () {},
      onSaveOfflineSession: () {},
      liveRunning: false,
      commandChannelReady: false,
      offlineRecordsCount: 0,
      localPointsCount: _points.length,
      onDebug: (_, __) {},
      initialTab: widget.initialTab,
      initialTabSignal: _tabSignal,
      initialCalendarMode: PlayerTrainingCalendarMode.all,
    );
  }
}
