import 'dart:math' as math;

enum EsportsMatchOutcome { win, draw, loss, unknown }

String esportsText(dynamic value) => '${value ?? ''}'.trim();

String esportsFirst(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = esportsText(source[key]);
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

int esportsInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(esportsText(value).replaceAll(',', '.')) ?? 0;
}

double esportsDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(esportsText(value).replaceAll(',', '.')) ?? 0;
}

DateTime? esportsDate(dynamic value) {
  final raw = esportsText(value);
  if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
  return DateTime.tryParse(raw.replaceAll(' ', 'T'));
}

bool isEsportsPlayer(Map<String, dynamic> player) {
  final marker = esportsFirst(player, const [
    'athlete_type',
    'athleteType',
    'player_type',
    'playerType',
    'sport_type',
    'sportType',
    'profile_type',
    'profileType',
  ]).toLowerCase();

  if (marker.contains('esport') ||
      marker.contains('e-sport') ||
      marker.contains('cyber') ||
      marker.contains('кибер')) {
    return true;
  }

  return esportsFirst(player, const [
    'esports_game',
    'esport_game',
    'game_title',
    'gameTitle',
    'gamer_tag',
    'gamerTag',
    'esports_nickname',
    'esportsNickname',
  ]).isNotEmpty;
}

String esportsNickname(Map<String, dynamic> player) => esportsFirst(player, const [
      'gamer_tag',
      'gamerTag',
      'esports_nickname',
      'esportsNickname',
      'nickname',
      'nick',
    ]);

String esportsGame(Map<String, dynamic> player) {
  final raw = esportsFirst(player, const [
    'esports_game',
    'esport_game',
    'game_title',
    'gameTitle',
    'discipline',
    'esports_discipline',
  ]);
  final lower = raw.toLowerCase();
  if (lower == 'fc' || lower.contains('fifa') || lower.contains('ea fc')) {
    return 'EA Sports FC';
  }
  if (lower.contains('efootball') || lower == 'pes') return 'eFootball';
  return raw;
}

String esportsPlatform(Map<String, dynamic> player) => esportsFirst(player, const [
      'gaming_platform',
      'gamingPlatform',
      'platform',
      'console',
    ]);

String esportsMode(Map<String, dynamic> player) => esportsFirst(player, const [
      'game_mode',
      'gameMode',
      'esports_mode',
      'esportsMode',
      'mode',
    ]);

String esportsRating(Map<String, dynamic> player) => esportsFirst(player, const [
      'esports_rating',
      'esportsRating',
      'elo',
      'rank_points',
      'rating',
      'rank',
    ]);

String esportsRank(Map<String, dynamic> player) => esportsFirst(player, const [
      'esports_rank',
      'rank_name',
      'rankName',
      'division',
      'league_rank',
      'rank',
    ]);

String esportsRegion(Map<String, dynamic> player) => esportsFirst(player, const [
      'esports_region',
      'region',
      'server_region',
    ]);

String esportsTeam(Map<String, dynamic> player) => esportsFirst(player, const [
      'esports_team_name',
      'esportsTeamName',
      'team_name',
      'teamName',
      'club_name',
    ]);

String esportsRealName(Map<String, dynamic> player) {
  final full = esportsFirst(player, const ['full_name', 'fullName', 'name', 'fio']);
  if (full.isNotEmpty) return full;
  final first = esportsFirst(player, const ['first_name', 'firstName']);
  final last = esportsFirst(player, const ['last_name', 'lastName']);
  return '$first $last'.trim();
}

String esportsCompetition(Map<String, dynamic> match) => esportsFirst(match, const [
      'competition_name',
      'competition',
      'tournament_name',
      'tournament',
      'league_name',
      'league',
      'event_name',
      'event_type',
    ]);

String esportsOpponent(Map<String, dynamic> match) => esportsFirst(match, const [
      'opponent_nickname',
      'opponent_name',
      'opponent',
      'rival_name',
      'rival',
      'away_team_name',
      'away_team',
      'title',
    ]);

DateTime? esportsMatchDate(Map<String, dynamic> match) => esportsDate(
      match['match_date'] ??
          match['date'] ??
          match['event_date'] ??
          match['start_at'] ??
          match['created_at'],
    );

List<int>? esportsScoreParts(Map<String, dynamic> match) {
  final ours = esportsFirst(match, const [
    'our_score',
    'player_score',
    'team_score',
    'home_score',
    'goals_for',
    'score_for',
  ]);
  final theirs = esportsFirst(match, const [
    'opponent_score',
    'rival_score',
    'away_score',
    'goals_against',
    'score_against',
  ]);
  if (ours.isNotEmpty || theirs.isNotEmpty) {
    return <int>[esportsDouble(ours).round(), esportsDouble(theirs).round()];
  }

  final direct = esportsFirst(match, const ['score', 'result', 'match_score']);
  final parsed = RegExp(r'(\d+)\s*[:\-]\s*(\d+)').firstMatch(direct);
  if (parsed == null) return null;
  return <int>[
    int.tryParse(parsed.group(1) ?? '') ?? 0,
    int.tryParse(parsed.group(2) ?? '') ?? 0,
  ];
}

String esportsScore(Map<String, dynamic> match) {
  final parts = esportsScoreParts(match);
  if (parts == null) return '—';
  return '${parts[0]}:${parts[1]}';
}

EsportsMatchOutcome esportsOutcome(Map<String, dynamic> match) {
  final raw = esportsFirst(match, const [
    'result_type',
    'outcome',
    'match_outcome',
    'status',
  ]).toLowerCase();
  if (raw.contains('win') || raw.contains('поб')) return EsportsMatchOutcome.win;
  if (raw.contains('draw') || raw.contains('нич')) return EsportsMatchOutcome.draw;
  if (raw.contains('loss') || raw.contains('lose') || raw.contains('пор')) {
    return EsportsMatchOutcome.loss;
  }

  final parts = esportsScoreParts(match);
  if (parts == null) return EsportsMatchOutcome.unknown;
  if (parts[0] > parts[1]) return EsportsMatchOutcome.win;
  if (parts[0] < parts[1]) return EsportsMatchOutcome.loss;
  return EsportsMatchOutcome.draw;
}

String esportsOutcomeLetter(EsportsMatchOutcome outcome) {
  switch (outcome) {
    case EsportsMatchOutcome.win:
      return 'W';
    case EsportsMatchOutcome.draw:
      return 'D';
    case EsportsMatchOutcome.loss:
      return 'L';
    case EsportsMatchOutcome.unknown:
      return '—';
  }
}

String esportsPercent(dynamic value) {
  final number = esportsDouble(value);
  if (number <= 0) return '—';
  final normalized = number <= 1 ? number * 100 : number;
  final digits = (normalized - normalized.roundToDouble()).abs() < .01 ? 0 : 1;
  return '${normalized.toStringAsFixed(digits)}%';
}

String esportsMetric(Map<String, dynamic> source, List<String> keys) {
  final value = esportsFirst(source, keys);
  return value.isEmpty ? '—' : value;
}

class EsportsAggregate {
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final double avgPossession;
  final double avgShots;
  final double avgShotsOnTarget;
  final double avgXg;
  final double avgPassAccuracy;

  const EsportsAggregate({
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.avgPossession,
    required this.avgShots,
    required this.avgShotsOnTarget,
    required this.avgXg,
    required this.avgPassAccuracy,
  });

  double get winRate => played == 0 ? 0 : wins * 100 / played;
  double get goalsPerMatch => played == 0 ? 0 : goalsFor / played;
  double get concededPerMatch => played == 0 ? 0 : goalsAgainst / played;
  int get goalDifference => goalsFor - goalsAgainst;

  static EsportsAggregate fromMatches(List<Map<String, dynamic>> matches) {
    var wins = 0;
    var draws = 0;
    var losses = 0;
    var goalsFor = 0;
    var goalsAgainst = 0;
    final possession = <double>[];
    final shots = <double>[];
    final shotsOnTarget = <double>[];
    final xg = <double>[];
    final passAccuracy = <double>[];

    for (final match in matches) {
      switch (esportsOutcome(match)) {
        case EsportsMatchOutcome.win:
          wins++;
          break;
        case EsportsMatchOutcome.draw:
          draws++;
          break;
        case EsportsMatchOutcome.loss:
          losses++;
          break;
        case EsportsMatchOutcome.unknown:
          break;
      }

      final score = esportsScoreParts(match);
      if (score != null) {
        goalsFor += score[0];
        goalsAgainst += score[1];
      }

      _pushPositive(possession, match, const [
        'possession',
        'possession_percent',
        'ball_possession',
      ], percent: true);
      _pushPositive(shots, match, const ['shots', 'shots_total', 'total_shots']);
      _pushPositive(shotsOnTarget, match, const [
        'shots_on_target',
        'shots_target',
        'on_target',
      ]);
      _pushPositive(xg, match, const ['xg', 'expected_goals']);
      _pushPositive(passAccuracy, match, const [
        'pass_accuracy',
        'passes_accuracy',
        'pass_accuracy_percent',
      ], percent: true);
    }

    return EsportsAggregate(
      played: matches.length,
      wins: wins,
      draws: draws,
      losses: losses,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      avgPossession: _average(possession),
      avgShots: _average(shots),
      avgShotsOnTarget: _average(shotsOnTarget),
      avgXg: _average(xg),
      avgPassAccuracy: _average(passAccuracy),
    );
  }

  static void _pushPositive(
    List<double> target,
    Map<String, dynamic> source,
    List<String> keys, {
    bool percent = false,
  }) {
    for (final key in keys) {
      var value = esportsDouble(source[key]);
      if (value <= 0) continue;
      if (percent && value <= 1) value *= 100;
      target.add(value);
      return;
    }
  }

  static double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / math.max(1, values.length);
  }
}
