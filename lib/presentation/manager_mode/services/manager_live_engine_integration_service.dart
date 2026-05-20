import '../models/manager_live_match_event_model.dart';
import '../models/manager_live_match_lineup_model.dart';
import '../models/manager_live_match_model.dart';
import '../models/manager_live_substitution_model.dart';
import '../models/manager_player_state_model.dart';
import '../models/manager_player_ttd_profile_model.dart';
import '../models/manager_team_overview_model.dart';
import 'manager_instruction_impact_service.dart';
import 'manager_live_event_generator_service.dart';
import 'manager_match_engine_service.dart';

class ManagerLiveEngineAdvanceResult {
  final ManagerLiveMatchModel updatedMatch;
  final List<ManagerLiveMatchEventModel> appendedEvents;
  final List<ManagerLiveMatchLineupModel> updatedLineup;
  final String? appliedInstructionCode;

  const ManagerLiveEngineAdvanceResult({
    required this.updatedMatch,
    required this.appendedEvents,
    required this.updatedLineup,
    required this.appliedInstructionCode,
  });
}

class ManagerLiveEngineIntegrationService {
  static String _normalizeRole(String raw) {
    final value = raw.trim().toLowerCase();

    if (value.contains('gk') ||
        value.contains('goal') ||
        value.contains('keeper') ||
        value.contains('врат')) {
      return 'gk';
    }

    if (value.contains('def') ||
        value.contains('cb') ||
        value.contains('lb') ||
        value.contains('rb') ||
        value.contains('back') ||
        value.contains('защ')) {
      return 'def';
    }

    if (value.contains('mid') ||
        value.contains('cm') ||
        value.contains('dm') ||
        value.contains('am') ||
        value.contains('wing') ||
        value.contains('пол')) {
      return 'mid';
    }

    if (value.contains('fwd') ||
        value.contains('fw') ||
        value.contains('st') ||
        value.contains('forward') ||
        value.contains('striker') ||
        value.contains('нап')) {
      return 'fwd';
    }

    return 'mid';
  }

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double _clampDouble(double value, double min, double max) {
    if (value.isNaN || value.isInfinite) return min;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static Map<int, ManagerPlayerStateModel> _playersStateMap(
    List<ManagerPlayerStateModel> players,
  ) {
    return {for (final p in players) p.playerId: p};
  }

  static Map<int, ManagerPlayerTtdProfileModel> _profilesMap(
    List<ManagerPlayerTtdProfileModel> profiles,
  ) {
    return {for (final p in profiles) p.playerId: p};
  }

  static List<ManagerEnginePlayerInput> _buildHomeEnginePlayers({
    required List<ManagerLiveMatchLineupModel> lineup,
    required Map<int, ManagerPlayerStateModel> statesById,
  }) {
    return lineup
        .where((e) => e.isOnField)
        .map((live) {
          final state = statesById[live.playerId];

          final fallbackFatigue = 100 - live.energy;

          return ManagerEnginePlayerInput(
            playerId: live.playerId,
            playerName: live.playerName,
            position: live.positionCode,
            isGoalkeeper: _normalizeRole(live.positionCode) == 'gk',
            formValue: state?.formValue ?? 50,
            morale: state?.morale ?? 50,
            fatigue: _clampInt(
              state != null
                  ? ((state.fatigue + fallbackFatigue) / 2).round()
                  : fallbackFatigue,
              0,
              100,
            ),
            readiness: state?.readiness ?? 50,
            tacticalFit: state?.tacticalFit ?? 50,
            isOnField: live.isOnField,
          );
        })
        .toList();
  }

  static List<ManagerLiveEventPlayerInput> _buildHomeEventPlayers({
    required List<ManagerLiveMatchLineupModel> lineup,
    required Map<int, ManagerPlayerStateModel> statesById,
  }) {
    return lineup
        .where((e) => e.isOnField)
        .map((live) {
          final state = statesById[live.playerId];
          final fallbackFatigue = 100 - live.energy;

          return ManagerLiveEventPlayerInput(
            playerId: live.playerId,
            playerName: live.playerName,
            position: live.positionCode,
            isOnField: live.isOnField,
            isGoalkeeper: _normalizeRole(live.positionCode) == 'gk',
            formValue: state?.formValue ?? 50,
            morale: state?.morale ?? 50,
            fatigue: _clampInt(
              state != null
                  ? ((state.fatigue + fallbackFatigue) / 2).round()
                  : fallbackFatigue,
              0,
              100,
            ),
            readiness: state?.readiness ?? 50,
            tacticalFit: state?.tacticalFit ?? 50,
          );
        })
        .toList();
  }

  static ManagerEngineTacticsInput _buildHomeTactics(
    ManagerTeamOverviewModel overview,
  ) {
    final tactics = overview.tactics;

    return ManagerEngineTacticsInput(
      formation: tactics.formation,
      playStyle: tactics.playStyle,
      pressingLevel: tactics.pressingLevel,
      tempo: tactics.tempo,
      defensiveLine: tactics.defensiveLine,
      intensity: tactics.intensity,
    );
  }

  static ManagerEngineTeamStateInput _buildHomeState(
    ManagerTeamOverviewModel overview,
  ) {
    final state = overview.teamState;

    return ManagerEngineTeamStateInput(
      teamForm: state.teamForm,
      teamMorale: state.teamMorale,
      teamFitness: state.teamFitness,
      tacticalFamiliarity: state.tacticalFamiliarity,
    );
  }

  static List<ManagerPlayerTtdProfileModel> _buildSyntheticOpponentProfiles(
    int opponentStrength,
  ) {
    final strength = opponentStrength.toDouble();

    return List.generate(11, (index) {
      final isGk = index == 0;
      final role = isGk
          ? 'gk'
          : index <= 4
              ? 'def'
              : index <= 7
                  ? 'mid'
                  : 'fwd';

      final base = _clampDouble(strength + ((index % 3) - 1) * 3, 35, 95);

      return ManagerPlayerTtdProfileModel(
        playerId: -(index + 1),
        playerName: isGk ? 'Вратарь соперника' : 'Игрок соперника ${index + 1}',
        groupKey: role,
        attackRating: role == 'fwd'
            ? base + 8
            : role == 'mid'
                ? base + 2
                : base - 8,
        passingRating: role == 'mid'
            ? base + 8
            : role == 'def'
                ? base
                : base + 2,
        defenseRating: role == 'def'
            ? base + 10
            : role == 'mid'
                ? base + 1
                : base - 10,
        aerialRating: role == 'def'
            ? base + 4
            : role == 'fwd'
                ? base + 2
                : base,
        activityRating: base,
        efficiencyRating: _clampDouble(base - 5, 1, 100),
        shortPassRating: _clampDouble(base + 3, 1, 100),
        mediumPassRating: _clampDouble(base + 5, 1, 100),
        longPassRating: _clampDouble(base - 2, 1, 100),
        forwardPassBias: role == 'fwd'
            ? 58
            : role == 'mid'
                ? 46
                : 28,
        sidePassBias: role == 'def'
            ? 38
            : 30,
        backPassBias: role == 'def'
            ? 34
            : 18,
        goalkeeperShotStopping: isGk ? _clampDouble(base + 6, 1, 100) : 0,
        goalkeeperDistribution: isGk ? _clampDouble(base, 1, 100) : 0,
        goalkeeperSweeper: isGk ? _clampDouble(base - 3, 1, 100) : 0,
      );
    });
  }

  static List<ManagerEnginePlayerInput> _buildSyntheticOpponentPlayers(
    int opponentStrength,
  ) {
    return List.generate(11, (index) {
      final isGk = index == 0;
      final position = isGk
          ? 'gk'
          : index <= 4
              ? 'def'
              : index <= 7
                  ? 'mid'
                  : 'fwd';

      final base = _clampInt(opponentStrength, 35, 95);

      return ManagerEnginePlayerInput(
        playerId: -(index + 1),
        playerName: isGk ? 'Вратарь соперника' : 'Игрок соперника ${index + 1}',
        position: position,
        isGoalkeeper: isGk,
        formValue: _clampInt(base, 1, 100),
        morale: _clampInt(base - 2, 1, 100),
        fatigue: 18,
        readiness: _clampInt(base + 1, 1, 100),
        tacticalFit: _clampInt(base - 1, 1, 100),
        isOnField: true,
      );
    });
  }

  static List<ManagerLiveEventPlayerInput> _buildSyntheticOpponentEventPlayers(
    int opponentStrength,
  ) {
    return List.generate(11, (index) {
      final isGk = index == 0;
      final position = isGk
          ? 'gk'
          : index <= 4
              ? 'def'
              : index <= 7
                  ? 'mid'
                  : 'fwd';

      final base = _clampInt(opponentStrength, 35, 95);

      return ManagerLiveEventPlayerInput(
        playerId: -(index + 1),
        playerName: isGk ? 'Вратарь соперника' : 'Игрок соперника ${index + 1}',
        position: position,
        isOnField: true,
        isGoalkeeper: isGk,
        formValue: base,
        morale: _clampInt(base - 2, 1, 100),
        fatigue: 18,
        readiness: _clampInt(base + 1, 1, 100),
        tacticalFit: _clampInt(base - 1, 1, 100),
      );
    });
  }

  static ManagerEngineTacticsInput _buildSyntheticOpponentTactics(
    int opponentStrength,
  ) {
    if (opponentStrength >= 78) {
      return const ManagerEngineTacticsInput(
        formation: '4-3-3',
        playStyle: 'possession',
        pressingLevel: 'high',
        tempo: 'high',
        defensiveLine: 'high',
        intensity: 'high',
      );
    }

    if (opponentStrength >= 65) {
      return const ManagerEngineTacticsInput(
        formation: '4-2-3-1',
        playStyle: 'balanced',
        pressingLevel: 'medium',
        tempo: 'medium',
        defensiveLine: 'medium',
        intensity: 'medium',
      );
    }

    return const ManagerEngineTacticsInput(
      formation: '4-4-2',
      playStyle: 'counter_attack',
      pressingLevel: 'medium',
      tempo: 'medium',
      defensiveLine: 'low',
      intensity: 'medium',
    );
  }

  static ManagerEngineTeamStateInput _buildSyntheticOpponentState(
    int opponentStrength,
  ) {
    final base = _clampInt(opponentStrength, 35, 95);

    return ManagerEngineTeamStateInput(
      teamForm: base,
      teamMorale: _clampInt(base - 2, 1, 100),
      teamFitness: _clampInt(base - 4, 1, 100),
      tacticalFamiliarity: _clampInt(base - 1, 1, 100),
    );
  }

  static ManagerLiveMatchModel _copyMatch(
    ManagerLiveMatchModel match, {
    required int minuteCurrent,
    required String periodLabel,
    required int homeScore,
    required int awayScore,
    required int possessionHome,
    required int possessionAway,
    required int shotsHome,
    required int shotsAway,
    required int shotsOnTargetHome,
    required int shotsOnTargetAway,
    required int momentumHome,
    required int momentumAway,
    required int teamEnergy,
    required int opponentEnergy,
    required String status,
  }) {
    return ManagerLiveMatchModel(
      id: match.id,
      teamId: match.teamId,
      userId: match.userId,
      opponentName: match.opponentName,
      opponentStrength: match.opponentStrength,
      formationUsed: match.formationUsed,
      playStyle: match.playStyle,
      pressingLevel: match.pressingLevel,
      tempo: match.tempo,
      defensiveLine: match.defensiveLine,
      intensity: match.intensity,
      minuteCurrent: minuteCurrent,
      periodLabel: periodLabel,
      homeScore: homeScore,
      awayScore: awayScore,
      possessionHome: possessionHome,
      possessionAway: possessionAway,
      shotsHome: shotsHome,
      shotsAway: shotsAway,
      shotsOnTargetHome: shotsOnTargetHome,
      shotsOnTargetAway: shotsOnTargetAway,
      momentumHome: momentumHome,
      momentumAway: momentumAway,
      teamEnergy: teamEnergy,
      opponentEnergy: opponentEnergy,
      status: status,
    );
  }

  static List<ManagerLiveMatchLineupModel> _applyLineupFatigue(
    List<ManagerLiveMatchLineupModel> lineup,
    int minutesStep,
  ) {
    return lineup.map((p) {
      if (!p.isOnField) return p;

      final nextEnergy = _clampInt(p.energy - minutesStep, 10, 100);

      return ManagerLiveMatchLineupModel(
        id: p.id,
        playerId: p.playerId,
        playerName: p.playerName,
        positionCode: p.positionCode,
        isStarting: p.isStarting,
        isOnField: p.isOnField,
        minutesPlayed: p.minutesPlayed + minutesStep,
        energy: nextEnergy,
        rating: p.rating,
        goals: p.goals,
        assists: p.assists,
        yellowCards: p.yellowCards,
        redCards: p.redCards,
      );
    }).toList();
  }

  static List<ManagerLiveMatchLineupModel> _applyEventsToLineup(
    List<ManagerLiveMatchLineupModel> lineup,
    List<ManagerLiveMatchEventModel> appendedEvents,
  ) {
    final map = {for (final p in lineup) p.playerId: p};

    for (final event in appendedEvents) {
      final playerId = event.playerId;
      if (playerId == null || !map.containsKey(playerId)) continue;

      final p = map[playerId]!;

      if (event.eventType == 'goal') {
        map[playerId] = ManagerLiveMatchLineupModel(
          id: p.id,
          playerId: p.playerId,
          playerName: p.playerName,
          positionCode: p.positionCode,
          isStarting: p.isStarting,
          isOnField: p.isOnField,
          minutesPlayed: p.minutesPlayed,
          energy: p.energy,
          rating: (p.rating + 0.8).clamp(0, 10),
          goals: p.goals + 1,
          assists: p.assists,
          yellowCards: p.yellowCards,
          redCards: p.redCards,
        );
      } else if (event.eventType == 'yellow_card') {
        map[playerId] = ManagerLiveMatchLineupModel(
          id: p.id,
          playerId: p.playerId,
          playerName: p.playerName,
          positionCode: p.positionCode,
          isStarting: p.isStarting,
          isOnField: p.isOnField,
          minutesPlayed: p.minutesPlayed,
          energy: p.energy,
          rating: (p.rating - 0.2).clamp(0, 10),
          goals: p.goals,
          assists: p.assists,
          yellowCards: p.yellowCards + 1,
          redCards: p.redCards,
        );
      } else if (event.eventType == 'shot_on_target') {
        map[playerId] = ManagerLiveMatchLineupModel(
          id: p.id,
          playerId: p.playerId,
          playerName: p.playerName,
          positionCode: p.positionCode,
          isStarting: p.isStarting,
          isOnField: p.isOnField,
          minutesPlayed: p.minutesPlayed,
          energy: p.energy,
          rating: (p.rating + 0.2).clamp(0, 10),
          goals: p.goals,
          assists: p.assists,
          yellowCards: p.yellowCards,
          redCards: p.redCards,
        );
      }
    }

    return lineup.map((p) => map[p.playerId] ?? p).toList();
  }

  static List<ManagerLiveMatchEventModel> _toLiveModels(
    List<ManagerGeneratedMatchEvent> events,
    int startId,
  ) {
    var nextId = startId;

    return events.map((e) {
      final model = ManagerLiveMatchEventModel(
        id: nextId++,
        minute: e.minute,
        eventType: e.eventType,
        teamSide: e.teamSide,
        playerId: e.playerId,
        playerName: e.playerName ?? '',
        description: e.description,
      );
      return model;
    }).toList();
  }

  static ManagerLiveEngineAdvanceResult advance({
    required ManagerLiveMatchModel currentMatch,
    required List<ManagerLiveMatchLineupModel> currentLineup,
    required List<ManagerPlayerStateModel> playersState,
    required List<ManagerPlayerTtdProfileModel> profiles,
    required ManagerTeamOverviewModel overview,
    int minutesStep = 5,
    int nextEventStartId = 100000,
  }) {
    final statesById = _playersStateMap(playersState);
    final profilesById = _profilesMap(profiles);

    final homePlayers = _buildHomeEnginePlayers(
      lineup: currentLineup,
      statesById: statesById,
    );

    final homeEventPlayers = _buildHomeEventPlayers(
      lineup: currentLineup,
      statesById: statesById,
    );

    final homeProfiles = homePlayers
        .map((p) => profilesById[p.playerId])
        .whereType<ManagerPlayerTtdProfileModel>()
        .toList();

    final awayPlayers =
        _buildSyntheticOpponentPlayers(currentMatch.opponentStrength);
    final awayEventPlayers =
        _buildSyntheticOpponentEventPlayers(currentMatch.opponentStrength);
    final awayProfiles =
        _buildSyntheticOpponentProfiles(currentMatch.opponentStrength);

    final homeSnapshot = ManagerMatchEngineService.buildTeamSnapshot(
      players: homePlayers,
      profiles: homeProfiles,
      tactics: _buildHomeTactics(overview),
      teamState: _buildHomeState(overview),
    );

    final awaySnapshot = ManagerMatchEngineService.buildTeamSnapshot(
      players: awayPlayers,
      profiles: awayProfiles,
      tactics: _buildSyntheticOpponentTactics(currentMatch.opponentStrength),
      teamState: _buildSyntheticOpponentState(currentMatch.opponentStrength),
    );

    final nextMinute =
        _clampInt(currentMatch.minuteCurrent + minutesStep, 0, 90);

    final step = ManagerMatchEngineService.evaluateStep(
      home: homeSnapshot,
      away: awaySnapshot,
      currentMomentumHome: currentMatch.momentumHome,
      currentMomentumAway: currentMatch.momentumAway,
      currentPossessionHome: currentMatch.possessionHome,
      currentPossessionAway: currentMatch.possessionAway,
    );

    final generated = ManagerLiveEventGeneratorService.generateStepEvents(
      minute: nextMinute,
      step: step,
      homeSnapshot: homeSnapshot,
      awaySnapshot: awaySnapshot,
      homePlayers: homeEventPlayers,
      awayPlayers: awayEventPlayers,
      homeProfiles: homeProfiles,
      awayProfiles: awayProfiles,
    );

    final appendedEvents =
        _toLiveModels(generated.events, nextEventStartId);

    final periodLabel = nextMinute >= 90
        ? 'full_time'
        : nextMinute == 45
            ? 'half_time'
            : nextMinute > 45
                ? 'second_half'
                : 'first_half';

    final status = nextMinute >= 90 ? 'finished' : 'live';

    final updatedMatch = _copyMatch(
      currentMatch,
      minuteCurrent: nextMinute,
      periodLabel: periodLabel,
      homeScore: currentMatch.homeScore + generated.homeScoreDelta,
      awayScore: currentMatch.awayScore + generated.awayScoreDelta,
      possessionHome: step.predictedHomePossession,
      possessionAway: step.predictedAwayPossession,
      shotsHome: currentMatch.shotsHome + generated.homeShotsDelta,
      shotsAway: currentMatch.shotsAway + generated.awayShotsDelta,
      shotsOnTargetHome:
          currentMatch.shotsOnTargetHome + generated.homeShotsOnTargetDelta,
      shotsOnTargetAway:
          currentMatch.shotsOnTargetAway + generated.awayShotsOnTargetDelta,
      momentumHome: _clampInt(
        currentMatch.momentumHome + step.homeMomentumDelta,
        1,
        99,
      ),
      momentumAway: _clampInt(
        currentMatch.momentumAway + step.awayMomentumDelta,
        1,
        99,
      ),
      teamEnergy: _clampInt(currentMatch.teamEnergy - minutesStep, 10, 100),
      opponentEnergy:
          _clampInt(currentMatch.opponentEnergy - minutesStep, 10, 100),
      status: status,
    );

    final fatiguedLineup = _applyLineupFatigue(currentLineup, minutesStep);
    final updatedLineup = _applyEventsToLineup(fatiguedLineup, appendedEvents);

    return ManagerLiveEngineAdvanceResult(
    appliedInstructionCode: null,
      updatedMatch: updatedMatch,
      appendedEvents: appendedEvents,
      updatedLineup: updatedLineup,
    );
  }
}