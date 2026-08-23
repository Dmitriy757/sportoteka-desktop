import 'dart:convert';
import 'package:http/http.dart' as http;

import 'tracker_training_report_models.dart';
import '../models/tracker_pro_models.dart';

class TrackerTrainingReportApi {
  TrackerTrainingReportApi({this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker'});

  final String apiBaseUrl;

  Future<TrackerTrainingReport> loadTrainingReports({
    required int sessionId,
    required int teamId,
    List<int> sessionIds = const <int>[],
    List<TrackerPlayerOption> rosterPlayers = const <TrackerPlayerOption>[],
  }) async {
    final ids = <int>[];
    void addId(int id) {
      if (id > 0 && !ids.contains(id)) ids.add(id);
    }

    addId(sessionId);
    for (final id in sessionIds) {
      addId(id);
    }
    if (ids.isEmpty) {
      return TrackerTrainingReport.empty(sessionId: sessionId, teamName: '');
    }
    if (ids.length == 1) {
      return loadTrainingReport(
        sessionId: ids.first,
        teamId: teamId,
        rosterPlayers: rosterPlayers,
      );
    }

    final loaded = await Future.wait(ids.map((id) async {
      try {
        return await loadTrainingReport(
          sessionId: id,
          teamId: teamId,
          rosterPlayers: rosterPlayers,
        );
      } catch (_) {
        // Одна повреждённая техническая запись не должна убирать остальных
        // участников общей командной тренировки из отчёта.
        return null;
      }
    }));
    final reports = loaded.whereType<TrackerTrainingReport>().toList(growable: false);
    if (reports.isEmpty) {
      throw Exception('Не удалось загрузить ни одну запись выбранной тренировки.');
    }
    return _mergeTrainingReports(reports, ids);
  }

  Future<TrackerTrainingReport> loadTrainingReport({
    required int sessionId,
    required int teamId,
    List<TrackerPlayerOption> rosterPlayers = const <TrackerPlayerOption>[],
  }) async {
    // Do not request every heavy report section in one call. On production the
    // PHP endpoint can close the connection before sending headers when maps,
    // per-player pages, timeline and microcycle are requested simultaneously.
    // Start with the normal analytics payload and gracefully fall back to a
    // lighter payload instead of leaving the Reports tab on an error screen.
    final requestUris = <Uri>[
      Uri.parse(
        '$apiBaseUrl/get_training_report.php?session_id=$sessionId&team_id=$teamId'
        '&include_maps=1&include_heatmap=1&include_hr=1&include_players=1'
        '&include_charts=1&include_locomotor=1&include_mechanics=1'
        '&include_internal=1&ai_stub=1',
      ),
      Uri.parse(
        '$apiBaseUrl/get_training_report.php?session_id=$sessionId&team_id=$teamId'
        '&include_maps=1&include_heatmap=1&include_hr=1&include_players=1'
        '&include_charts=1&hr_fallback=1',
      ),
      Uri.parse(
        '$apiBaseUrl/get_training_report.php?session_id=$sessionId&team_id=$teamId'
        '&include_hr=1&include_players=1&include_charts=1&hr_fallback=1',
      ),
    ];

    http.Response? response;
    Object? lastError;
    for (var index = 0; index < requestUris.length; index++) {
      try {
        final candidate = await http
            .get(requestUris[index])
            .timeout(const Duration(seconds: 25));
        if (candidate.statusCode >= 200 && candidate.statusCode < 300) {
          response = candidate;
          break;
        }
        lastError = Exception(
          'Ошибка API (${candidate.statusCode}): '
          '${utf8.decode(candidate.bodyBytes)}',
        );
      } catch (error) {
        lastError = error;
      }
      if (index + 1 < requestUris.length) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }

    if (response == null) {
      throw Exception(
        'Не удалось загрузить данные отчёта. '
        'Сервер закрыл соединение. Повторите попытку. '
        '${lastError ?? ''}',
      );
    }

    final body = utf8.decode(response.bodyBytes);
    final json = jsonDecode(body);
    if (json is! Map) throw Exception('Некорректный JSON отчёта');
    if (json['success'] == false) throw Exception('${json['message'] ?? 'API вернул ошибку'}');
    final report = TrackerTrainingReport.fromJson(Map<String, dynamic>.from(json['report'] as Map? ?? json));
    // В аналитике состав уже загружен. Используем его первым, чтобы технические
    // подписи «Игрок 175» не успевали попасть на экран даже при недоступном API состава.
    if (rosterPlayers.isNotEmpty) {
      return _withRosterIdentity(report, rosterPlayers);
    }
    // Report API sometimes returns only «Игрок 181». Always enrich rows from the
    // canonical team roster so the report, preview and export use real FIO/photos.
    try {
      final rosterUri = Uri.parse('$apiBaseUrl/get_tracker_players.php?team_id=$teamId');
      final rosterResponse = await http.get(rosterUri).timeout(const Duration(seconds: 10));
      if (rosterResponse.statusCode >= 200 && rosterResponse.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(rosterResponse.bodyBytes));
        if (decoded is Map) {
          final list = (decoded['players'] as List? ?? decoded['data'] as List? ?? const []);
          final roster = list
              .whereType<Map>()
              .map((e) => TrackerPlayerOption.fromJson(Map<String, dynamic>.from(e)))
              .where((p) => p.id > 0)
              .toList(growable: false);
          return _withRosterIdentity(report, roster);
        }
      }
    } catch (_) {
      // The report remains usable when roster enrichment is temporarily offline.
    }
    return report;
  }

  TrackerTrainingReport _withRosterIdentity(TrackerTrainingReport report, List<TrackerPlayerOption> roster) {
    TrackerPlayerOption? match(TrackerTrainingPlayerRow row) {
      final id = row.playerId;
      if (id != null && id > 0) {
        for (final player in roster) {
          if (player.identityIds.contains(id) || player.id == id) return player;
        }
      }
      final raw = row.name.trim().toLowerCase();
      if (raw.isNotEmpty && !RegExp(r'^игрок\s*\d*$', caseSensitive: false).hasMatch(raw)) {
        for (final player in roster) {
          if (player.name.trim().toLowerCase() == raw) return player;
        }
      }
      return null;
    }

    List<TrackerTrainingPlayerRow> enrich(List<TrackerTrainingPlayerRow> rows) => rows.map((row) {
      final player = match(row);
      if (player == null) return row;
      return row.copyWith(
        name: player.name,
        avatarUrl: (player.avatar ?? '').trim().isNotEmpty ? player.avatar : row.avatarUrl,
        number: (player.number ?? '').trim().isNotEmpty ? player.number : row.number,
        position: (player.position ?? '').trim().isNotEmpty ? player.position : row.position,
      );
    }).toList(growable: false);

    return TrackerTrainingReport(
      sessionId: report.sessionId,
      sessionIds: report.sessionIds,
      title: report.title,
      dateLabel: report.dateLabel,
      teamId: report.teamId,
      teamName: report.teamName,
      teamLogoUrl: report.teamLogoUrl,
      opponent: report.opponent,
      durationLabel: report.durationLabel,
      playersCount: report.playersCount,
      pointsCount: report.pointsCount,
      hasData: report.hasData,
      dataStatus: report.dataStatus,
      summary: report.summary,
      periods: report.periods,
      microcycle: report.microcycle,
      players: enrich(report.players),
      diagnosticPlayers: enrich(report.diagnosticPlayers),
      routePoints: report.routePoints,
      heatmapPoints: report.heatmapPoints,
      speedZones: report.speedZones,
      heartRateTimeline: report.heartRateTimeline,
    );
  }

  Uri pdfExportUri({
    required int sessionId,
    required int teamId,
    List<int>? sessionIds,
    List<int>? playerIds,
    List<String>? playerNames,
    List<String>? sections,
    bool includeMaps = true,
    bool includeHeatmap = true,
    bool includeCharts = true,
    bool includePlayerPages = true,
    bool includeLogo = true,
    bool includePhotos = true,
  }) {
    final players = (playerIds ?? const <int>[]).where((id) => id > 0).join(',');
    final names = (playerNames ?? const <String>[]).where((name) => name.trim().isNotEmpty).map(Uri.encodeQueryComponent).join(',');
    final sectionList = (sections == null || sections.isEmpty)
        ? 'summary,performance_matrix,locomotor,mechanics,internal,maps,heatmap,speed,hr,players,player_pages,microcycle,ai'
        : sections.map(Uri.encodeQueryComponent).join(',');
    final sessions = <int>[];
    for (final id in <int>[sessionId, ...?sessionIds]) {
      if (id > 0 && !sessions.contains(id)) sessions.add(id);
    }
    final query = StringBuffer('$apiBaseUrl/export_training_report_pdf.php?session_id=$sessionId&team_id=$teamId&template=analytics_ru&inline=1&print=1&full=1&report=analytics_export');
    if (sessions.length > 1) query.write('&session_ids=${Uri.encodeQueryComponent(sessions.join(','))}');
    query.write('&include_maps=${includeMaps ? 1 : 0}&include_heatmap=${includeHeatmap ? 1 : 0}&include_hr=1&include_players=1&include_charts=${includeCharts ? 1 : 0}');
    query.write('&include_player_pages=${includePlayerPages ? 1 : 0}&per_player_charts=${includePlayerPages ? 1 : 0}&timeline=${includeCharts ? 1 : 0}');
    query.write('&include_locomotor=1&include_mechanics=1&include_internal=1&include_microcycle=1&sections=$sectionList&ai_stub=1');
    query.write('&include_logo=${includeLogo ? 1 : 0}&include_photos=${includePhotos ? 1 : 0}');
    if (players.isNotEmpty) query.write('&player_ids=$players&player_id=$players');
    if (names.isNotEmpty) query.write('&player_names=$names');
    query.write('&v=120');
    return Uri.parse(query.toString());
  }

  Uri csvExportUri({required int sessionId, required int teamId, List<int>? sessionIds, List<int>? playerIds, List<String>? playerNames, List<String>? sections}) {
    final players = (playerIds ?? const <int>[]).where((id) => id > 0).join(',');
    final names = (playerNames ?? const <String>[]).where((name) => name.trim().isNotEmpty).map(Uri.encodeQueryComponent).join(',');
    final sectionList = (sections == null || sections.isEmpty) ? 'summary,performance_matrix,players,locomotor,mechanics,hr,comparison,zones' : sections.map(Uri.encodeQueryComponent).join(',');
    final sessions = <int>[];
    for (final id in <int>[sessionId, ...?sessionIds]) {
      if (id > 0 && !sessions.contains(id)) sessions.add(id);
    }
    final query = StringBuffer('$apiBaseUrl/export_training_report_csv.php?session_id=$sessionId&team_id=$teamId&full=1&include_hr=1&include_players=1&sections=$sectionList');
    if (sessions.length > 1) query.write('&session_ids=${Uri.encodeQueryComponent(sessions.join(','))}');
    if (players.isNotEmpty) query.write('&player_ids=$players&player_id=$players');
    if (names.isNotEmpty) query.write('&player_names=$names');
    query.write('&v=120');
    return Uri.parse(query.toString());
  }
}

TrackerTrainingReport _mergeTrainingReports(
  List<TrackerTrainingReport> reports,
  List<int> requestedSessionIds,
) {
  final primary = reports.first;
  final players = _mergeTrainingPlayerRows(reports.expand((report) => report.players));
  final diagnosticPlayers = _mergeTrainingPlayerRows(reports.expand((report) => report.diagnosticPlayers));
  final summaryPlayers = players.isNotEmpty ? players : diagnosticPlayers;
  final routePoints = _mergeReportPoints(reports.expand((report) => report.routePoints));
  final heatmapPoints = _mergeReportPoints(reports.expand((report) => report.heatmapPoints));
  final heartRateTimeline = _mergeHeartRatePoints(reports.expand((report) => report.heartRateTimeline));
  final speedZones = _mergeSpeedZones(reports.expand((report) => report.speedZones));
  final periods = _uniquePeriods(reports.expand((report) => report.periods));
  final microcycle = _uniqueMicrocycle(reports.expand((report) => report.microcycle));
  final summary = summaryPlayers.isNotEmpty
      ? _summaryFromPlayers(summaryPlayers)
      : primary.summary;

  String firstText(String Function(TrackerTrainingReport report) pick) {
    for (final report in reports) {
      final value = pick(report).trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  final playersCount = summaryPlayers.isNotEmpty
      ? summaryPlayers.length
      : reports.fold<int>(0, (value, report) => value > report.playersCount ? value : report.playersCount);
  return TrackerTrainingReport(
    sessionId: primary.sessionId > 0 ? primary.sessionId : requestedSessionIds.first,
    sessionIds: List<int>.unmodifiable(requestedSessionIds),
    title: firstText((report) => report.title),
    dateLabel: firstText((report) => report.dateLabel),
    teamId: primary.teamId > 0 ? primary.teamId : reports.fold<int>(0, (value, report) => value > 0 ? value : report.teamId),
    teamName: firstText((report) => report.teamName),
    teamLogoUrl: firstText((report) => report.teamLogoUrl),
    opponent: firstText((report) => report.opponent),
    durationLabel: _durationLabel(
      reports.fold<int>(0, (value, report) {
        final seconds = _durationSeconds(report.durationLabel);
        return value > seconds ? value : seconds;
      }),
    ),
    playersCount: playersCount,
    pointsCount: routePoints.length,
    hasData: reports.any((report) => report.hasData) ||
        summaryPlayers.isNotEmpty ||
        routePoints.isNotEmpty ||
        heartRateTimeline.isNotEmpty,
    dataStatus: firstText((report) => report.dataStatus),
    summary: summary,
    periods: periods,
    microcycle: microcycle,
    players: players,
    diagnosticPlayers: diagnosticPlayers,
    routePoints: routePoints,
    heatmapPoints: heatmapPoints,
    speedZones: speedZones,
    heartRateTimeline: heartRateTimeline,
  );
}

List<TrackerTrainingPlayerRow> _mergeTrainingPlayerRows(
  Iterable<TrackerTrainingPlayerRow> source,
) {
  final rows = <String, TrackerTrainingPlayerRow>{};
  for (final row in source) {
    final idFromName = RegExp(r'(?:игрок|player)\s*#?(\d+)', caseSensitive: false)
        .firstMatch(row.name)
        ?.group(1);
    final normalizedName = row.name
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s+'), ' ');
    final key = row.playerId != null && row.playerId! > 0
        ? 'id:${row.playerId}'
        : idFromName != null
            ? 'id:$idFromName'
            : 'name:$normalizedName';
    final existing = rows[key];
    rows[key] = existing == null ? row : _mergeTrainingPlayerRow(existing, row);
  }
  final result = rows.values.toList(growable: false);
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
}

TrackerTrainingPlayerRow _mergeTrainingPlayerRow(
  TrackerTrainingPlayerRow a,
  TrackerTrainingPlayerRow b,
) {
  String preferIdentity(String first, String second) {
    final aText = first.trim();
    final bText = second.trim();
    final aGeneric = aText.isEmpty || RegExp(r'^(?:игрок|player)\s*#?\d*$', caseSensitive: false).hasMatch(aText);
    final bGeneric = bText.isEmpty || RegExp(r'^(?:игрок|player)\s*#?\d*$', caseSensitive: false).hasMatch(bText);
    if (aGeneric && !bGeneric) return second;
    if (!aGeneric) return first;
    return bText.isNotEmpty ? second : first;
  }

  String preferText(String first, String second) =>
      first.trim().isNotEmpty ? first : second;
  double maxDouble(double first, double second) => first > second ? first : second;
  int maxInt(int first, int second) => first > second ? first : second;
  final aWeight = a.heartRateSamplesCount > 0 ? a.heartRateSamplesCount : 0;
  final bWeight = b.heartRateSamplesCount > 0 ? b.heartRateSamplesCount : 0;
  final hrWeight = aWeight + bWeight;
  final hrAvg = hrWeight > 0
      ? (a.heartRateAvgBpm * aWeight + b.heartRateAvgBpm * bWeight) / hrWeight
      : maxDouble(a.heartRateAvgBpm, b.heartRateAvgBpm);
  return TrackerTrainingPlayerRow(
    playerId: a.playerId ?? b.playerId,
    name: preferIdentity(a.name, b.name),
    avatarUrl: preferText(a.avatarUrl, b.avatarUrl),
    number: preferText(a.number, b.number),
    position: preferText(a.position, b.position),
    deviceName: preferText(a.deviceName, b.deviceName),
    trackerUid: preferText(a.trackerUid, b.trackerUid),
    duration: _durationLabel(maxInt(_durationSeconds(a.duration), _durationSeconds(b.duration))),
    distanceM: maxDouble(a.distanceM, b.distanceM),
    metersPerMin: maxDouble(a.metersPerMin, b.metersPerMin),
    maxSpeedKmh: maxDouble(a.maxSpeedKmh, b.maxSpeedKmh),
    avgSpeedKmh: maxDouble(a.avgSpeedKmh, b.avgSpeedKmh),
    accelerations: maxInt(a.accelerations, b.accelerations),
    decelerations: maxInt(a.decelerations, b.decelerations),
    accDecPerMin: maxDouble(a.accDecPerMin, b.accDecPerMin),
    explosiveActions: maxInt(a.explosiveActions, b.explosiveActions),
    v3RunM: maxDouble(a.v3RunM, b.v3RunM),
    v4HsrM: maxDouble(a.v4HsrM, b.v4HsrM),
    v5SprintM: maxDouble(a.v5SprintM, b.v5SprintM),
    sprintCount: maxInt(a.sprintCount, b.sprintCount),
    highSpeedWorkM: maxDouble(a.highSpeedWorkM, b.highSpeedWorkM),
    highSpeedActions: maxInt(a.highSpeedActions, b.highSpeedActions),
    playerLoad: maxDouble(a.playerLoad, b.playerLoad),
    heartRateMaxPercent: maxDouble(a.heartRateMaxPercent, b.heartRateMaxPercent),
    hrExertion: maxDouble(a.hrExertion, b.hrExertion),
    heartRateAvgBpm: hrAvg,
    heartRateMaxBpm: maxDouble(a.heartRateMaxBpm, b.heartRateMaxBpm),
    heartRateMinBpm: a.heartRateMinBpm > 0 && b.heartRateMinBpm > 0
        ? (a.heartRateMinBpm < b.heartRateMinBpm ? a.heartRateMinBpm : b.heartRateMinBpm)
        : maxDouble(a.heartRateMinBpm, b.heartRateMinBpm),
    // Один и тот же групповой отчёт иногда возвращается для нескольких id.
    // max не даёт умножить одинаковые Polar-точки на число записей.
    heartRateSamplesCount: maxInt(a.heartRateSamplesCount, b.heartRateSamplesCount),
    hrZ1Samples: maxInt(a.hrZ1Samples, b.hrZ1Samples),
    hrZ2Samples: maxInt(a.hrZ2Samples, b.hrZ2Samples),
    hrZ3Samples: maxInt(a.hrZ3Samples, b.hrZ3Samples),
    hrZ4Samples: maxInt(a.hrZ4Samples, b.hrZ4Samples),
    hrZ5Samples: maxInt(a.hrZ5Samples, b.hrZ5Samples),
    pointsCount: maxInt(a.pointsCount, b.pointsCount),
    sessionsCount: maxInt(a.sessionsCount, b.sessionsCount),
    hasMovement: a.hasMovement || b.hasMovement,
  );
}

TrackerReportSummary _summaryFromPlayers(List<TrackerTrainingPlayerRow> rows) {
  double sum(double Function(TrackerTrainingPlayerRow row) pick) =>
      rows.fold<double>(0, (value, row) => value + pick(row));
  double avg(double Function(TrackerTrainingPlayerRow row) pick) =>
      rows.isEmpty ? 0 : sum(pick) / rows.length;
  int intSum(int Function(TrackerTrainingPlayerRow row) pick) =>
      rows.fold<int>(0, (value, row) => value + pick(row));
  final hrPlayers = rows
      .where((row) => row.heartRateSamplesCount > 0 || row.heartRateAvgBpm > 0)
      .toList(growable: false);
  final hrWeight = hrPlayers.fold<int>(
    0,
    (value, row) => value + (row.heartRateSamplesCount > 0 ? row.heartRateSamplesCount : 1),
  );
  final hrAvg = hrWeight <= 0
      ? 0.0
      : hrPlayers.fold<double>(
            0,
            (value, row) =>
                value +
                row.heartRateAvgBpm *
                    (row.heartRateSamplesCount > 0 ? row.heartRateSamplesCount : 1),
          ) /
          hrWeight;
  return TrackerReportSummary(
    averageDistanceM: avg((row) => row.distanceM),
    totalDistanceM: sum((row) => row.distanceM),
    highSpeedDistanceM: sum((row) => row.highSpeedWorkM),
    playerLoad: sum((row) => row.playerLoad),
    accDecPerMin: avg((row) => row.accDecPerMin),
    maxSpeedKmh: rows.fold<double>(0, (value, row) => value > row.maxSpeedKmh ? value : row.maxSpeedKmh),
    avgSpeedKmh: avg((row) => row.avgSpeedKmh),
    distancePerMin: avg((row) => row.metersPerMin),
    accelerationCount: intSum((row) => row.accelerations),
    decelerationCount: intSum((row) => row.decelerations),
    explosiveActions: intSum((row) => row.explosiveActions),
    sprintCount: intSum((row) => row.sprintCount),
    sprintDistanceM: sum((row) => row.v5SprintM),
    v3RunM: sum((row) => row.v3RunM),
    v4HsrM: sum((row) => row.v4HsrM),
    v5SprintM: sum((row) => row.v5SprintM),
    heartRateAvgBpm: hrAvg,
    heartRateMaxBpm: hrPlayers.fold<double>(0, (value, row) => value > row.heartRateMaxBpm ? value : row.heartRateMaxBpm),
    heartRateSamplesCount: hrPlayers.fold<int>(0, (value, row) => value + row.heartRateSamplesCount),
  );
}

List<TrackerReportPoint> _mergeReportPoints(Iterable<TrackerReportPoint> source) {
  final seen = <String>{};
  final result = source.where((point) {
    final key = '${point.playerId}|${point.playerName}|${point.timeMs}|'
        '${point.x.toStringAsFixed(5)}|${point.y.toStringAsFixed(5)}|'
        '${point.speedKmh.toStringAsFixed(3)}';
    return seen.add(key);
  }).toList(growable: false);
  result.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return result;
}

List<TrackerHeartRatePoint> _mergeHeartRatePoints(
  Iterable<TrackerHeartRatePoint> source,
) {
  final seen = <String>{};
  final result = source.where((point) {
    final key = '${point.playerId}|${point.playerName}|${point.timeMs}|'
        '${point.minute}|${point.bpm}|${point.zone}';
    return seen.add(key);
  }).toList(growable: false);
  result.sort((a, b) {
    final aTime = a.timeMs > 0 ? a.timeMs : a.minute * 60000;
    final bTime = b.timeMs > 0 ? b.timeMs : b.minute * 60000;
    return aTime.compareTo(bTime);
  });
  return result;
}

List<TrackerSpeedZone> _mergeSpeedZones(Iterable<TrackerSpeedZone> source) {
  final zones = <String, TrackerSpeedZone>{};
  for (final zone in source) {
    final key = '${zone.label.trim().toLowerCase()}|${zone.fromKmh}|${zone.toKmh}';
    final existing = zones[key];
    if (existing == null) {
      zones[key] = zone;
    } else {
      zones[key] = TrackerSpeedZone(
        label: existing.label.isNotEmpty ? existing.label : zone.label,
        fromKmh: existing.fromKmh,
        toKmh: existing.toKmh,
        distanceM: existing.distanceM > zone.distanceM ? existing.distanceM : zone.distanceM,
        pointsCount: existing.pointsCount > zone.pointsCount ? existing.pointsCount : zone.pointsCount,
      );
    }
  }
  return zones.values.toList(growable: false);
}

List<TrackerExercisePeriod> _uniquePeriods(Iterable<TrackerExercisePeriod> source) {
  final seen = <String>{};
  return source.where((period) {
    final key = '${period.title}|${period.startLabel}|${period.endLabel}|${period.durationSec}';
    return seen.add(key);
  }).toList(growable: false);
}

List<TrackerMicrocyclePoint> _uniqueMicrocycle(Iterable<TrackerMicrocyclePoint> source) {
  final seen = <String>{};
  return source.where((point) {
    final key = '${point.label}|${point.distanceM}|${point.highSpeedRunningM}|${point.accDec}';
    return seen.add(key);
  }).toList(growable: false);
}

int _durationSeconds(String raw) {
  final parts = raw.trim().split(':');
  if (parts.length == 3) {
    return (int.tryParse(parts[0]) ?? 0) * 3600 +
        (int.tryParse(parts[1]) ?? 0) * 60 +
        (int.tryParse(parts[2]) ?? 0);
  }
  if (parts.length == 2) {
    return (int.tryParse(parts[0]) ?? 0) * 60 +
        (int.tryParse(parts[1]) ?? 0);
  }
  return int.tryParse(raw.trim()) ?? 0;
}

String _durationLabel(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  final secs = safe % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')}';
}
