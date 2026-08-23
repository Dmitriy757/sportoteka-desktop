import '../models/manager_player_ttd_profile_model.dart';

class ManagerTtdProfileService {
  static Map<String, int> parsePair(dynamic raw) {
    final text = (raw ?? '0/0').toString().trim();
    final parts = text.split('/');

    final success = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final fail = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return {
      'success': success,
      'fail': fail,
      'total': success + fail,
    };
  }

  static double _safePercent(int success, int total) {
    if (total <= 0) return 0;
    return (success / total) * 100.0;
  }

  static double _clamp100(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    return value.clamp(0, 100).toDouble();
  }

  static double _volumeBonus(int total, {double divisor = 20}) {
    return (total / divisor).clamp(0, 1.5);
  }

  static double _scoreFromPair(
    dynamic raw, {
    double weightAccuracy = 0.7,
    double weightVolume = 0.3,
    double maxVolumeForScale = 20,
  }) {
    final pair = parsePair(raw);
    final success = pair['success']!;
    final total = pair['total']!;

    if (total == 0) return 0;

    final accuracy = _safePercent(success, total);
    final volumeScore = (total / maxVolumeForScale * 100).clamp(0, 100);

    return _clamp100(
      (accuracy * weightAccuracy) + (volumeScore * weightVolume),
    );
  }

  static String _normalizeGroupKey(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    if (key.isEmpty) return 'no_role';

    switch (key) {
      case 'def':
      case 'defender':
      case 'defenders':
        return 'def';
      case 'mid':
      case 'mf':
      case 'midfielder':
      case 'midfielders':
        return 'mid';
      case 'fwd':
      case 'fw':
      case 'att':
      case 'forward':
      case 'forwards':
      case 'striker':
        return 'fwd';
      case 'gk':
      case 'goalkeeper':
      case 'keeper':
        return 'gk';
      case 'sub':
      case 'subs':
      case 'bench':
      case 'reserve':
      case 'res':
        return 'bench';
      default:
        return key;
    }
  }

  static int _resolvePlayerId(Map<String, dynamic> row) {
    final keys = [
      'player_id',
      'id',
      'user_id',
    ];

    for (final key in keys) {
      final value = row[key];
      if (value != null) {
        final parsed = int.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
    }

    return 0;
  }

  static String _resolvePlayerName(Map<String, dynamic> row) {
    final keys = [
      'player_name',
      'full_name',
      'name',
    ];

    for (final key in keys) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return 'Игрок';
  }

  static Map<int, Map<String, dynamic>> _indexByPlayerId(
    List<Map<String, dynamic>> rows,
  ) {
    final map = <int, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = _resolvePlayerId(row);
      if (id > 0) {
        map[id] = row;
      }
    }
    return map;
  }

  static double _biasPercent(int part, int total) {
    if (total <= 0) return 0;
    return ((part / total) * 100).clamp(0, 100).toDouble();
  }

  static ManagerPlayerTtdProfileModel buildProfile({
    required Map<String, dynamic> mainRow,
    Map<String, dynamic>? passRow,
    Map<String, dynamic>? goalkeeperRow,
  }) {
    final playerId = _resolvePlayerId(mainRow);
    final playerName = _resolvePlayerName(mainRow);
    final groupKey = _normalizeGroupKey(
      mainRow['group_key']?.toString() ?? goalkeeperRow?['group_key']?.toString(),
    );

    final effectPercent =
        double.tryParse((mainRow['effect_percent'] ?? 0).toString()) ?? 0;

    final feintScore = _scoreFromPair(mainRow['feint_dribble']);
    final shotScore = _scoreFromPair(mainRow['shot_on_goal']);
    final tackleScore = _scoreFromPair(mainRow['tackle_duel']);
    final interceptionScore = _scoreFromPair(mainRow['interception']);
    final recoveryScore = _scoreFromPair(mainRow['recovery']);
    final headerScore = _scoreFromPair(mainRow['header_play']);
    final passAvpScore = _scoreFromPair(mainRow['pass_avp']);

    final totalPair = parsePair(mainRow['ttd_total']);
    final ttdTotal = totalPair['total']!;
    final activityRating = _clamp100((ttdTotal / 25) * 100);

    double shortPassRating = 0;
    double mediumPassRating = 0;
    double longPassRating = 0;
    double forwardPassBias = 0;
    double sidePassBias = 0;
    double backPassBias = 0;
    double passingRating = passAvpScore;

    if (passRow != null) {
      final fs = parsePair(passRow['forward_short']);
      final fm = parsePair(passRow['forward_medium']);
      final fl = parsePair(passRow['forward_long']);
      final ss = parsePair(passRow['side_short']);
      final sm = parsePair(passRow['side_medium']);
      final sl = parsePair(passRow['side_long']);
      final bs = parsePair(passRow['back_short']);
      final bm = parsePair(passRow['back_medium']);
      final bl = parsePair(passRow['back_long']);

      final shortSuccess = fs['success']! + ss['success']! + bs['success']!;
      final shortTotal = fs['total']! + ss['total']! + bs['total']!;

      final mediumSuccess = fm['success']! + sm['success']! + bm['success']!;
      final mediumTotal = fm['total']! + sm['total']! + bm['total']!;

      final longSuccess = fl['success']! + sl['success']! + bl['success']!;
      final longTotal = fl['total']! + sl['total']! + bl['total']!;

      shortPassRating = _clamp100(
        (_safePercent(shortSuccess, shortTotal) * 0.75) +
            ((shortTotal / 20) * 100 * 0.25),
      );

      mediumPassRating = _clamp100(
        (_safePercent(mediumSuccess, mediumTotal) * 0.75) +
            ((mediumTotal / 18) * 100 * 0.25),
      );

      longPassRating = _clamp100(
        (_safePercent(longSuccess, longTotal) * 0.75) +
            ((longTotal / 14) * 100 * 0.25),
      );

      final forwardTotal = fs['total']! + fm['total']! + fl['total']!;
      final sideTotal = ss['total']! + sm['total']! + sl['total']!;
      final backTotal = bs['total']! + bm['total']! + bl['total']!;
      final allPassTotal = forwardTotal + sideTotal + backTotal;

      forwardPassBias = _biasPercent(forwardTotal, allPassTotal);
      sidePassBias = _biasPercent(sideTotal, allPassTotal);
      backPassBias = _biasPercent(backTotal, allPassTotal);

      final passEffect =
          double.tryParse((passRow['effect_percent'] ?? 0).toString()) ?? 0;

      passingRating = _clamp100(
        (passAvpScore * 0.25) +
            (shortPassRating * 0.20) +
            (mediumPassRating * 0.25) +
            (longPassRating * 0.20) +
            (passEffect * 0.10),
      );
    }

    final attackRating = _clamp100(
      (shotScore * 0.45) +
          (feintScore * 0.30) +
          (headerScore * 0.15) +
          (effectPercent * 0.10),
    );

    final defenseRating = _clamp100(
      (tackleScore * 0.35) +
          (interceptionScore * 0.30) +
          (recoveryScore * 0.25) +
          (headerScore * 0.10),
    );

    final aerialRating = _clamp100(
      (headerScore * 0.8) + (activityRating * 0.2),
    );

    double goalkeeperShotStopping = 0;
    double goalkeeperDistribution = 0;
    double goalkeeperSweeper = 0;

    if (goalkeeperRow != null) {
      final saves = int.tryParse((goalkeeperRow['saves'] ?? 0).toString()) ?? 0;
      final conceded =
          int.tryParse((goalkeeperRow['conceded'] ?? 0).toString()) ?? 0;

      final handDistribution = _scoreFromPair(goalkeeperRow['hand_distribution']);
      final comingOut = _scoreFromPair(goalkeeperRow['coming_out']);
      final closeCombat = _scoreFromPair(goalkeeperRow['close_combat']);
      final interceptions = _scoreFromPair(goalkeeperRow['interceptions']);
      final outsideBox = _scoreFromPair(goalkeeperRow['outside_box']);
      final gkPassShort = _scoreFromPair(goalkeeperRow['pass_short']);
      final gkPassMedium = _scoreFromPair(goalkeeperRow['pass_medium']);
      final gkPassLong = _scoreFromPair(goalkeeperRow['pass_long']);
      final gkEffect =
          double.tryParse((goalkeeperRow['effect_percent'] ?? 0).toString()) ?? 0;

      final saveTotal = saves + conceded;
      final savePercent = saveTotal > 0 ? (saves / saveTotal) * 100 : 0;

      goalkeeperShotStopping = _clamp100(
        (savePercent * 0.55) +
            (closeCombat * 0.20) +
            (comingOut * 0.10) +
            (gkEffect * 0.15),
      );

      goalkeeperDistribution = _clamp100(
        (handDistribution * 0.20) +
            (gkPassShort * 0.25) +
            (gkPassMedium * 0.30) +
            (gkPassLong * 0.25),
      );

      goalkeeperSweeper = _clamp100(
        (interceptions * 0.45) +
            (outsideBox * 0.35) +
            (comingOut * 0.20),
      );
    }

    return ManagerPlayerTtdProfileModel(
      playerId: playerId,
      playerName: playerName,
      groupKey: groupKey,
      attackRating: attackRating,
      passingRating: passingRating,
      defenseRating: defenseRating,
      aerialRating: aerialRating,
      activityRating: activityRating,
      efficiencyRating: _clamp100(effectPercent),
      shortPassRating: shortPassRating,
      mediumPassRating: mediumPassRating,
      longPassRating: longPassRating,
      forwardPassBias: forwardPassBias,
      sidePassBias: sidePassBias,
      backPassBias: backPassBias,
      goalkeeperShotStopping: goalkeeperShotStopping,
      goalkeeperDistribution: goalkeeperDistribution,
      goalkeeperSweeper: goalkeeperSweeper,
    );
  }

  static List<ManagerPlayerTtdProfileModel> buildProfiles({
    required List<Map<String, dynamic>> mainReportRows,
    required List<Map<String, dynamic>> passReportRows,
    required List<Map<String, dynamic>> goalkeeperReportRows,
  }) {
    final passIndex = _indexByPlayerId(passReportRows);
    final gkIndex = _indexByPlayerId(goalkeeperReportRows);

    final profiles = <ManagerPlayerTtdProfileModel>[];

    for (final mainRow in mainReportRows) {
      final playerId = _resolvePlayerId(mainRow);
      profiles.add(
        buildProfile(
          mainRow: mainRow,
          passRow: passIndex[playerId],
          goalkeeperRow: gkIndex[playerId],
        ),
      );
    }

    for (final gkRow in goalkeeperReportRows) {
      final playerId = _resolvePlayerId(gkRow);
      final alreadyExists = profiles.any((e) => e.playerId == playerId);
      if (alreadyExists) continue;

      profiles.add(
        buildProfile(
          mainRow: {
            'player_id': playerId,
            'player_name': _resolvePlayerName(gkRow),
            'group_key': 'gk',
            'feint_dribble': '0/0',
            'shot_on_goal': '0/0',
            'tackle_duel': '0/0',
            'interception': gkRow['interceptions'] ?? '0/0',
            'recovery': '0/0',
            'header_play': '0/0',
            'pass_avp': '0/0',
            'ttd_total': gkRow['ttd_total'] ?? '0/0',
            'effect_percent': gkRow['effect_percent'] ?? 0,
          },
          passRow: null,
          goalkeeperRow: gkRow,
        ),
      );
    }

    return profiles;
  }
}