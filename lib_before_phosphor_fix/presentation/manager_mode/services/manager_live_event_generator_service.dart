import 'dart:math' as math;

import '../models/manager_player_ttd_profile_model.dart';
import 'manager_match_engine_service.dart';

class ManagerLiveEventPlayerInput {
  final int playerId;
  final String playerName;
  final String position;
  final bool isOnField;
  final bool isGoalkeeper;
  final int formValue;
  final int morale;
  final int fatigue;
  final int readiness;
  final int tacticalFit;

  const ManagerLiveEventPlayerInput({
    required this.playerId,
    required this.playerName,
    required this.position,
    required this.isOnField,
    required this.isGoalkeeper,
    required this.formValue,
    required this.morale,
    required this.fatigue,
    required this.readiness,
    required this.tacticalFit,
  });
}

class ManagerGeneratedMatchEvent {
  final int minute;
  final String eventType;
  final String teamSide;
  final int? playerId;
  final String? playerName;
  final int? secondaryPlayerId;
  final String? secondaryPlayerName;
  final String description;
  final bool changesScore;
  final int homeScoreDelta;
  final int awayScoreDelta;
  final bool isShot;
  final bool isShotOnTarget;
  final bool isDangerous;

  const ManagerGeneratedMatchEvent({
    required this.minute,
    required this.eventType,
    required this.teamSide,
    required this.playerId,
    required this.playerName,
    required this.secondaryPlayerId,
    required this.secondaryPlayerName,
    required this.description,
    required this.changesScore,
    required this.homeScoreDelta,
    required this.awayScoreDelta,
    required this.isShot,
    required this.isShotOnTarget,
    required this.isDangerous,
  });

  Map<String, dynamic> toJson() {
    return {
      'minute': minute,
      'event_type': eventType,
      'team_side': teamSide,
      'player_id': playerId,
      'player_name': playerName,
      'secondary_player_id': secondaryPlayerId,
      'secondary_player_name': secondaryPlayerName,
      'description': description,
      'changes_score': changesScore,
      'home_score_delta': homeScoreDelta,
      'away_score_delta': awayScoreDelta,
      'is_shot': isShot,
      'is_shot_on_target': isShotOnTarget,
      'is_dangerous': isDangerous,
    };
  }
}

class ManagerEventGenerationResult {
  final List<ManagerGeneratedMatchEvent> events;
  final int homeScoreDelta;
  final int awayScoreDelta;
  final int homeShotsDelta;
  final int awayShotsDelta;
  final int homeShotsOnTargetDelta;
  final int awayShotsOnTargetDelta;

  const ManagerEventGenerationResult({
    required this.events,
    required this.homeScoreDelta,
    required this.awayScoreDelta,
    required this.homeShotsDelta,
    required this.awayShotsDelta,
    required this.homeShotsOnTargetDelta,
    required this.awayShotsOnTargetDelta,
  });
}

class ManagerLiveEventGeneratorService {
  static final math.Random _random = math.Random();

  static double _clamp(double value, double min, double max) {
    if (value.isNaN || value.isInfinite) return min;
    return value.clamp(min, max).toDouble();
  }

  static String _normalize(String value) => value.trim().toLowerCase();

  static bool _roll(double probability) {
    final p = _clamp(probability, 0, 1);
    return _random.nextDouble() <= p;
  }

  static T _pickWeighted<T>(
    List<T> items,
    double Function(T item) weightBuilder,
  ) {
    if (items.isEmpty) {
      throw Exception('Weighted pick called with empty list');
    }

    final weights = items.map(weightBuilder).map((e) => e <= 0 ? 0.01 : e).toList();
    final total = weights.fold<double>(0, (a, b) => a + b);

    double roll = _random.nextDouble() * total;

    for (int i = 0; i < items.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return items[i];
    }

    return items.last;
  }

  static String _role(String position) {
    final p = _normalize(position);

    if (p.contains('gk') ||
        p.contains('goal') ||
        p.contains('keeper') ||
        p.contains('врат')) {
      return 'gk';
    }

    if (p.contains('def') ||
        p.contains('cb') ||
        p.contains('lb') ||
        p.contains('rb') ||
        p.contains('back') ||
        p.contains('защ')) {
      return 'def';
    }

    if (p.contains('mid') ||
        p.contains('cm') ||
        p.contains('dm') ||
        p.contains('am') ||
        p.contains('wing') ||
        p.contains('пол')) {
      return 'mid';
    }

    if (p.contains('fwd') ||
        p.contains('fw') ||
        p.contains('st') ||
        p.contains('forward') ||
        p.contains('striker') ||
        p.contains('нап')) {
      return 'fwd';
    }

    return 'unknown';
  }

  static ManagerPlayerTtdProfileModel? _findProfile(
    List<ManagerPlayerTtdProfileModel> profiles,
    int playerId,
  ) {
    for (final p in profiles) {
      if (p.playerId == playerId) return p;
    }
    return null;
  }

  static List<ManagerLiveEventPlayerInput> _activeNonKeepers(
    List<ManagerLiveEventPlayerInput> players,
  ) {
    return players.where((p) => p.isOnField && !p.isGoalkeeper).toList();
  }

  static ManagerLiveEventPlayerInput? _goalkeeper(
    List<ManagerLiveEventPlayerInput> players,
  ) {
    for (final p in players) {
      if (p.isOnField && p.isGoalkeeper) return p;
    }
    return null;
  }

  static ManagerLiveEventPlayerInput _pickShooter({
    required List<ManagerLiveEventPlayerInput> players,
    required List<ManagerPlayerTtdProfileModel> profiles,
  }) {
    final active = _activeNonKeepers(players);
    return _pickWeighted(active, (player) {
      final profile = _findProfile(profiles, player.playerId);
      final role = _role(player.position);
      final attack = profile?.attackRating ?? 40;
      final aerial = profile?.aerialRating ?? 30;
      final activity = profile?.activityRating ?? 40;
      final freshness = 100 - player.fatigue;

      double roleBoost = 1.0;
      if (role == 'fwd') roleBoost = 1.55;
      if (role == 'mid') roleBoost = 1.20;
      if (role == 'def') roleBoost = 0.80;

      return ((attack * 0.55) +
              (aerial * 0.10) +
              (activity * 0.20) +
              (freshness * 0.15)) *
          roleBoost;
    });
  }

  static ManagerLiveEventPlayerInput _pickCreator({
    required List<ManagerLiveEventPlayerInput> players,
    required List<ManagerPlayerTtdProfileModel> profiles,
    int? excludePlayerId,
  }) {
    final active = _activeNonKeepers(players)
        .where((p) => p.playerId != excludePlayerId)
        .toList();

    return _pickWeighted(active, (player) {
      final profile = _findProfile(profiles, player.playerId);
      final role = _role(player.position);
      final passing = profile?.passingRating ?? 40;
      final creationBias = profile?.forwardPassBias ?? 30;
      final activity = profile?.activityRating ?? 40;
      final freshness = 100 - player.fatigue;

      double roleBoost = 1.0;
      if (role == 'mid') roleBoost = 1.45;
      if (role == 'fwd') roleBoost = 1.10;
      if (role == 'def') roleBoost = 0.90;

      return ((passing * 0.55) +
              (creationBias * 0.15) +
              (activity * 0.15) +
              (freshness * 0.15)) *
          roleBoost;
    });
  }

  static ManagerLiveEventPlayerInput _pickDefenderActionPlayer({
    required List<ManagerLiveEventPlayerInput> players,
    required List<ManagerPlayerTtdProfileModel> profiles,
  }) {
    final active = _activeNonKeepers(players);
    return _pickWeighted(active, (player) {
      final profile = _findProfile(profiles, player.playerId);
      final role = _role(player.position);
      final defense = profile?.defenseRating ?? 40;
      final activity = profile?.activityRating ?? 40;
      final aerial = profile?.aerialRating ?? 30;
      final freshness = 100 - player.fatigue;

      double roleBoost = 1.0;
      if (role == 'def') roleBoost = 1.55;
      if (role == 'mid') roleBoost = 1.15;
      if (role == 'fwd') roleBoost = 0.70;

      return ((defense * 0.55) +
              (activity * 0.20) +
              (aerial * 0.10) +
              (freshness * 0.15)) *
          roleBoost;
    });
  }

  static String _shotMissDescription(String teamSide, String shooter) {
    final home = teamSide == 'home';
    final variants = [
      "$shooter пробил мимо",
      "Неточный удар — $shooter",
      "$shooter завершил атаку ударом выше ворот",
    ];
    return home ? variants[_random.nextInt(variants.length)] : "Соперник: ${variants[_random.nextInt(variants.length)]}";
  }

  static String _shotOnTargetDescription(
    String teamSide,
    String shooter,
    String goalkeeper,
  ) {
    final base = [
      "$shooter пробил в створ — сейв $goalkeeper",
      "Опасный удар $shooter, но $goalkeeper выручил",
      "$goalkeeper справился с ударом игрока $shooter",
    ];
    return teamSide == 'home'
        ? base[_random.nextInt(base.length)]
        : "Соперник бьёт в створ — $goalkeeper спасает";
  }

  static String _goalDescription({
    required String teamSide,
    required String scorer,
    String? creator,
  }) {
    if (teamSide == 'home') {
      if (creator != null && creator.isNotEmpty) {
        return "Гол! $scorer после передачи $creator";
      }
      return "Гол! Отличился $scorer";
    }

    return "Гол соперника";
  }

  static ManagerGeneratedMatchEvent _buildShotMiss({
    required int minute,
    required String teamSide,
    required ManagerLiveEventPlayerInput shooter,
  }) {
    return ManagerGeneratedMatchEvent(
      minute: minute,
      eventType: 'shot',
      teamSide: teamSide,
      playerId: shooter.playerId,
      playerName: shooter.playerName,
      secondaryPlayerId: null,
      secondaryPlayerName: null,
      description: "${minute}' ${_shotMissDescription(teamSide, shooter.playerName)}",
      changesScore: false,
      homeScoreDelta: 0,
      awayScoreDelta: 0,
      isShot: true,
      isShotOnTarget: false,
      isDangerous: false,
    );
  }

  static ManagerGeneratedMatchEvent _buildShotOnTarget({
    required int minute,
    required String teamSide,
    required ManagerLiveEventPlayerInput shooter,
    required String goalkeeperName,
  }) {
    return ManagerGeneratedMatchEvent(
      minute: minute,
      eventType: 'shot_on_target',
      teamSide: teamSide,
      playerId: shooter.playerId,
      playerName: shooter.playerName,
      secondaryPlayerId: null,
      secondaryPlayerName: null,
      description:
          "${minute}' ${_shotOnTargetDescription(teamSide, shooter.playerName, goalkeeperName)}",
      changesScore: false,
      homeScoreDelta: 0,
      awayScoreDelta: 0,
      isShot: true,
      isShotOnTarget: true,
      isDangerous: true,
    );
  }

  static ManagerGeneratedMatchEvent _buildGoal({
    required int minute,
    required String teamSide,
    required ManagerLiveEventPlayerInput shooter,
    ManagerLiveEventPlayerInput? creator,
  }) {
    return ManagerGeneratedMatchEvent(
      minute: minute,
      eventType: 'goal',
      teamSide: teamSide,
      playerId: shooter.playerId,
      playerName: shooter.playerName,
      secondaryPlayerId: creator?.playerId,
      secondaryPlayerName: creator?.playerName,
      description: "${minute}' ${_goalDescription(
        teamSide: teamSide,
        scorer: shooter.playerName,
        creator: creator?.playerName,
      )}",
      changesScore: true,
      homeScoreDelta: teamSide == 'home' ? 1 : 0,
      awayScoreDelta: teamSide == 'away' ? 1 : 0,
      isShot: true,
      isShotOnTarget: true,
      isDangerous: true,
    );
  }

  static ManagerGeneratedMatchEvent _buildInterception({
    required int minute,
    required String teamSide,
    required ManagerLiveEventPlayerInput player,
  }) {
    final descriptions = [
      "${minute}' ${player.playerName} перехватил передачу",
      "${minute}' Отличный перехват от ${player.playerName}",
      "${minute}' ${player.playerName} сорвал атаку соперника",
    ];

    return ManagerGeneratedMatchEvent(
      minute: minute,
      eventType: 'interception',
      teamSide: teamSide,
      playerId: player.playerId,
      playerName: player.playerName,
      secondaryPlayerId: null,
      secondaryPlayerName: null,
      description: descriptions[_random.nextInt(descriptions.length)],
      changesScore: false,
      homeScoreDelta: 0,
      awayScoreDelta: 0,
      isShot: false,
      isShotOnTarget: false,
      isDangerous: false,
    );
  }

  static ManagerGeneratedMatchEvent _buildYellowCard({
    required int minute,
    required String teamSide,
    required ManagerLiveEventPlayerInput player,
  }) {
    return ManagerGeneratedMatchEvent(
      minute: minute,
      eventType: 'yellow_card',
      teamSide: teamSide,
      playerId: player.playerId,
      playerName: player.playerName,
      secondaryPlayerId: null,
      secondaryPlayerName: null,
      description: "${minute}' Жёлтая карточка: ${player.playerName}",
      changesScore: false,
      homeScoreDelta: 0,
      awayScoreDelta: 0,
      isShot: false,
      isShotOnTarget: false,
      isDangerous: false,
    );
  }

  static ManagerGeneratedMatchEvent _buildInjury({
    required int minute,
    required String teamSide,
    required ManagerLiveEventPlayerInput player,
  }) {
    return ManagerGeneratedMatchEvent(
      minute: minute,
      eventType: 'injury',
      teamSide: teamSide,
      playerId: player.playerId,
      playerName: player.playerName,
      secondaryPlayerId: null,
      secondaryPlayerName: null,
      description: "${minute}' Повреждение у игрока ${player.playerName}",
      changesScore: false,
      homeScoreDelta: 0,
      awayScoreDelta: 0,
      isShot: false,
      isShotOnTarget: false,
      isDangerous: true,
    );
  }

  static ManagerEventGenerationResult generateStepEvents({
    required int minute,
    required ManagerEngineStepResult step,
    required ManagerEngineTeamSnapshot homeSnapshot,
    required ManagerEngineTeamSnapshot awaySnapshot,
    required List<ManagerLiveEventPlayerInput> homePlayers,
    required List<ManagerLiveEventPlayerInput> awayPlayers,
    required List<ManagerPlayerTtdProfileModel> homeProfiles,
    required List<ManagerPlayerTtdProfileModel> awayProfiles,
  }) {
    final events = <ManagerGeneratedMatchEvent>[];

    int homeScoreDelta = 0;
    int awayScoreDelta = 0;
    int homeShotsDelta = 0;
    int awayShotsDelta = 0;
    int homeShotsOnTargetDelta = 0;
    int awayShotsOnTargetDelta = 0;

    final homeAttacks = _roll(step.homeShotProbability);
    final awayAttacks = _roll(step.awayShotProbability);

    if (homeAttacks) {
      homeShotsDelta += 1;

      final shooter = _pickShooter(
        players: homePlayers,
        profiles: homeProfiles,
      );
      final creator = _pickCreator(
        players: homePlayers,
        profiles: homeProfiles,
        excludePlayerId: shooter.playerId,
      );
      final awayGk = _goalkeeper(awayPlayers);

      final onTarget = _roll(step.homeShotOnTargetProbability);
      if (onTarget) {
        homeShotsOnTargetDelta += 1;

        final goal = _roll(step.homeGoalProbability);
        if (goal) {
          final event = _buildGoal(
            minute: minute,
            teamSide: 'home',
            shooter: shooter,
            creator: creator.playerId == shooter.playerId ? null : creator,
          );
          events.add(event);
          homeScoreDelta += event.homeScoreDelta;
        } else {
          events.add(
            _buildShotOnTarget(
              minute: minute,
              teamSide: 'home',
              shooter: shooter,
              goalkeeperName: awayGk?.playerName ?? 'вратарь соперника',
            ),
          );
        }
      } else {
        events.add(
          _buildShotMiss(
            minute: minute,
            teamSide: 'home',
            shooter: shooter,
          ),
        );
      }
    }

    if (awayAttacks) {
      awayShotsDelta += 1;

      final shooter = _pickShooter(
        players: awayPlayers,
        profiles: awayProfiles,
      );
      final creator = _pickCreator(
        players: awayPlayers,
        profiles: awayProfiles,
        excludePlayerId: shooter.playerId,
      );
      final homeGk = _goalkeeper(homePlayers);

      final onTarget = _roll(step.awayShotOnTargetProbability);
      if (onTarget) {
        awayShotsOnTargetDelta += 1;

        final goal = _roll(step.awayGoalProbability);
        if (goal) {
          final event = _buildGoal(
            minute: minute,
            teamSide: 'away',
            shooter: shooter,
            creator: creator.playerId == shooter.playerId ? null : creator,
          );
          events.add(event);
          awayScoreDelta += event.awayScoreDelta;
        } else {
          events.add(
            _buildShotOnTarget(
              minute: minute,
              teamSide: 'away',
              shooter: shooter,
              goalkeeperName: homeGk?.playerName ?? 'вратарь',
            ),
          );
        }
      } else {
        events.add(
          _buildShotMiss(
            minute: minute,
            teamSide: 'away',
            shooter: shooter,
          ),
        );
      }
    }

    if (!homeAttacks && _roll(0.18 + (step.homeDangerIndex / 1000))) {
      final interceptor = _pickDefenderActionPlayer(
        players: homePlayers,
        profiles: homeProfiles,
      );
      events.add(
        _buildInterception(
          minute: minute,
          teamSide: 'home',
          player: interceptor,
        ),
      );
    }

    if (!awayAttacks && _roll(0.18 + (step.awayDangerIndex / 1000))) {
      final interceptor = _pickDefenderActionPlayer(
        players: awayPlayers,
        profiles: awayProfiles,
      );
      events.add(
        _buildInterception(
          minute: minute,
          teamSide: 'away',
          player: interceptor,
        ),
      );
    }

    if (_roll(0.08)) {
      final cardPlayer = _pickDefenderActionPlayer(
        players: homePlayers,
        profiles: homeProfiles,
      );
      events.add(
        _buildYellowCard(
          minute: minute,
          teamSide: 'home',
          player: cardPlayer,
        ),
      );
    }

    if (_roll(0.08)) {
      final cardPlayer = _pickDefenderActionPlayer(
        players: awayPlayers,
        profiles: awayProfiles,
      );
      events.add(
        _buildYellowCard(
          minute: minute,
          teamSide: 'away',
          player: cardPlayer,
        ),
      );
    }

    if (_roll(0.03)) {
      final injured = _pickDefenderActionPlayer(
        players: homePlayers,
        profiles: homeProfiles,
      );
      events.add(
        _buildInjury(
          minute: minute,
          teamSide: 'home',
          player: injured,
        ),
      );
    }

    if (_roll(0.03)) {
      final injured = _pickDefenderActionPlayer(
        players: awayPlayers,
        profiles: awayProfiles,
      );
      events.add(
        _buildInjury(
          minute: minute,
          teamSide: 'away',
          player: injured,
        ),
      );
    }

    events.sort((a, b) {
      if (a.isDangerous != b.isDangerous) {
        return a.isDangerous ? -1 : 1;
      }
      return a.eventType.compareTo(b.eventType);
    });

    return ManagerEventGenerationResult(
      events: events,
      homeScoreDelta: homeScoreDelta,
      awayScoreDelta: awayScoreDelta,
      homeShotsDelta: homeShotsDelta,
      awayShotsDelta: awayShotsDelta,
      homeShotsOnTargetDelta: homeShotsOnTargetDelta,
      awayShotsOnTargetDelta: awayShotsOnTargetDelta,
    );
  }
}