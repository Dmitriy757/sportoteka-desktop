import 'package:flutter/material.dart';

import '../models/manager_live_match_event_model.dart';
import '../models/manager_live_match_lineup_model.dart';
import '../models/manager_live_match_model.dart';
import '../models/manager_player_state_model.dart';
import '../models/manager_player_ttd_profile_model.dart';
import '../models/manager_team_overview_model.dart';
import '../services/manager_live_engine_integration_service.dart';
import '../services/manager_mode_service.dart';

class ManagerLiveMatchScreen extends StatefulWidget {
  final int liveMatchId;
  final int teamId;
  final int userId;
  final String teamName;
  final List<ManagerPlayerTtdProfileModel> profiles;

  const ManagerLiveMatchScreen({
    super.key,
    required this.liveMatchId,
    required this.teamId,
    required this.userId,
    required this.teamName,
    required this.profiles,
  });

  @override
  State<ManagerLiveMatchScreen> createState() => _ManagerLiveMatchScreenState();
}

class _ManagerLiveMatchScreenState extends State<ManagerLiveMatchScreen> {
  ManagerLiveMatchModel? _match;
  List<ManagerLiveMatchEventModel> _events = [];
  List<ManagerLiveMatchLineupModel> _lineup = [];

  List<ManagerPlayerStateModel> _playersState = [];
  ManagerTeamOverviewModel? _overview;

  bool _initialLoading = true;
  bool _advancing = false;
  String? _error;
  int _nextLocalEventId = 500000;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ManagerModeService.getLiveMatchState(
          liveMatchId: widget.liveMatchId,
        ),
        ManagerModeService.getPlayersState(
          teamId: widget.teamId,
        ),
        ManagerModeService.getTeamOverview(
          teamId: widget.teamId,
          userId: widget.userId,
        ),
      ]);

      final liveState = results[0] as ManagerLiveMatchStateResponse;
      final playersState = results[1] as List<ManagerPlayerStateModel>;
      final overview = results[2] as ManagerTeamOverviewModel;

      if (!mounted) return;

      setState(() {
        _match = liveState.match;
        _events = List<ManagerLiveMatchEventModel>.from(liveState.events);
        _lineup = List<ManagerLiveMatchLineupModel>.from(liveState.lineup);
        _playersState = playersState;
        _overview = overview;
        _nextLocalEventId = _events.isEmpty ? 500000 : (_events.last.id + 1);
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initialLoading = false;
      });
    }
  }

  Future<void> _reload() async {
    await _bootstrap();
  }

  Future<void> _advance() async {
    if (_match == null || _overview == null) return;

    setState(() => _advancing = true);

    try {
      final result = ManagerLiveEngineIntegrationService.advance(
        currentMatch: _match!,
        currentLineup: _lineup,
        playersState: _playersState,
        profiles: widget.profiles,
        overview: _overview!,
        minutesStep: 5,
        nextEventStartId: _nextLocalEventId,
      );

      if (!mounted) return;

      setState(() {
        _match = result.updatedMatch;
        _events = [..._events, ...result.appendedEvents];
        _lineup = result.updatedLineup;
        _nextLocalEventId += result.appendedEvents.length;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка движка: $e')),
      );
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  Color _momentumColor(int value) {
    if (value >= 65) return const Color(0xFF16A34A);
    if (value >= 45) return const Color(0xFF2563EB);
    return const Color(0xFFF59E0B);
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'goal':
        return const Color(0xFF16A34A);
      case 'shot_on_target':
        return const Color(0xFF2563EB);
      case 'shot':
        return const Color(0xFF64748B);
      case 'yellow_card':
        return const Color(0xFFF59E0B);
      case 'injury':
        return const Color(0xFFDC2626);
      case 'interception':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF334155);
    }
  }

  String _periodText(String period) {
    switch (period) {
      case 'pre_match':
        return 'Перед матчем';
      case 'first_half':
        return '1-й тайм';
      case 'half_time':
        return 'Перерыв';
      case 'second_half':
        return '2-й тайм';
      case 'full_time':
        return 'Финал';
      default:
        return period;
    }
  }

  Widget _scoreboard(ManagerLiveMatchModel match) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            _periodText(match.periodLabel),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            match.status == 'finished'
                ? 'FT'
                : "${match.minuteCurrent}'",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${match.homeScore} : ${match.awayScore}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.teamName} — ${match.opponentName}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF6B7280))),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(ManagerLiveMatchModel match) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: [
        _statCard('Владение', '${match.possessionHome}:${match.possessionAway}'),
        _statCard('Удары', '${match.shotsHome}:${match.shotsAway}'),
        _statCard(
          'В створ',
          '${match.shotsOnTargetHome}:${match.shotsOnTargetAway}',
        ),
        _statCard('Энергия', '${match.teamEnergy}%'),
      ],
    );
  }

  Widget _momentum(ManagerLiveMatchModel match) {
    final value = (match.momentumHome.clamp(0, 100)) / 100;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Momentum',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 12,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                _momentumColor(match.momentumHome),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Давление команды: ${match.momentumHome} / 100',
            style: const TextStyle(color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _actions(ManagerLiveMatchModel match) {
    final finished = match.status == 'finished';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: finished || _advancing ? null : _advance,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _advancing
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.fast_forward_rounded),
        label: Text(
          finished ? 'Матч завершён' : 'Следующие 5 минут',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _eventsWidget(List<ManagerLiveMatchEventModel> events) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Лента событий',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const Text('Событий пока нет')
          else
            ...events.reversed.take(12).map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      alignment: Alignment.center,
                      child: Text(
                        "${e.minute}'",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _eventColor(e.eventType).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          e.description,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                          ),
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

  Widget _lineupWidget(List<ManagerLiveMatchLineupModel> lineup) {
    final onField = lineup.where((e) => e.isOnField).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Игроки на поле',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...onField.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.playerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Text(
                    'Эн. ${p.energy}',
                    style: const TextStyle(color: Color(0xFF475569)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    p.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
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

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Live Match Center'),
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 0,
          foregroundColor: const Color(0xFF111827),
        ),
        body: ListView(
          children: const [
            SizedBox(height: 250),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Live Match Center'),
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 0,
          foregroundColor: const Color(0xFF111827),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 60),
            Center(child: Text('Ошибка: $_error')),
          ],
        ),
      );
    }

    final match = _match!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Live Match Center'),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _scoreboard(match),
            const SizedBox(height: 16),
            _stats(match),
            const SizedBox(height: 16),
            _momentum(match),
            const SizedBox(height: 16),
            _actions(match),
            const SizedBox(height: 16),
            _eventsWidget(_events),
            const SizedBox(height: 16),
            _lineupWidget(_lineup),
          ],
        ),
      ),
    );
  }
}