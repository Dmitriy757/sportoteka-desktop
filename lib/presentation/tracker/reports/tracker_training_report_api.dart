import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import 'tracker_training_report_models.dart';
import '../models/tracker_pro_models.dart';
import '../models/action_tracker_protocol.dart';
import '../services/tracker_pro_api.dart';
import '../services/player_personal_tracker_api.dart';

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
      // Production safety net: charts are the most expensive part of the old
      // PHP report builder. If it still closes the socket, retry without them.
      Uri.parse(
        '$apiBaseUrl/get_training_report.php?session_id=$sessionId&team_id=$teamId'
        '&include_hr=1&include_players=1&hr_fallback=1',
      ),
      Uri.parse(
        '$apiBaseUrl/get_training_report.php?session_id=$sessionId&team_id=$teamId'
        '&include_players=1',
      ),
      Uri.parse(
        '$apiBaseUrl/get_training_report.php?session_id=$sessionId&team_id=$teamId',
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
    var report = TrackerTrainingReport.fromJson(
        Map<String, dynamic>.from(json['report'] as Map? ?? json));

    // V117: Reports раньше доверял max_speed_kmh из get_training_report.php,
    // а экран сессии пересчитывал скорость по GPS и отбрасывал скачки. Из-за
    // этого один и тот же игрок мог иметь 29.x в Аналитике и 33–42 в Отчётах.
    // Дочитываем те же GPS-точки сессии и применяем тот же фильтр скорости /
    // ускорения. Это НЕ визуальный clamp до 30 км/ч: ложный сегмент именно
    // исключается из максимума.
    List<ActionTrackerGpsPoint> validationGps =
        const <ActionTrackerGpsPoint>[];
    try {
      validationGps = await TrackerProApi(apiBaseUrl: apiBaseUrl)
          .loadSessionPoints(
            teamId: teamId,
            sessionId: sessionId,
            playerId: null,
            limit: 12000,
          )
          .timeout(const Duration(seconds: 18));
      if (validationGps.isNotEmpty) {
        report = _withValidatedGpsSpeeds(
          report,
          validationGps,
          rosterPlayers,
        );
      }
    } catch (_) {
      // Отчёт остаётся доступным при временной недоступности GPS endpoint.
    }

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
          if (validationGps.isNotEmpty) {
            report = _withValidatedGpsSpeeds(report, validationGps, roster);
          }
          return _withRosterIdentity(report, roster);
        }
      }
    } catch (_) {
      // The report remains usable when roster enrichment is temporarily offline.
    }
    return report;
  }


  /// Personal player sessions are stored/read through player_* endpoints.
  /// Do not force them through get_training_report.php: on production that
  /// endpoint may close the connection before headers for a personal session.
  /// Build the verified report from the same personal session/GPS/HR sources
  /// that already power «Мои тренировки».
  Future<TrackerTrainingReport> loadPersonalTrainingReport({
    required int sessionId,
    required int teamId,
    required int ownerUserId,
    int? playerId,
    String teamName = '',
    List<TrackerPlayerOption> rosterPlayers = const <TrackerPlayerOption>[],
  }) async {
    if (sessionId <= 0) {
      return TrackerTrainingReport.empty(sessionId: sessionId, teamName: teamName);
    }
    if (ownerUserId <= 0) {
      throw Exception('Не передан пользователь личной тренировки.');
    }

    int? effectivePlayerId = playerId != null && playerId > 0 ? playerId : null;
    if (effectivePlayerId == null && rosterPlayers.length == 1) {
      effectivePlayerId = rosterPlayers.first.id > 0 ? rosterPlayers.first.id : null;
    }
    effectivePlayerId ??= ownerUserId;

    final personal = PlayerPersonalTrackerApi(apiBaseUrl: apiBaseUrl);
    final rows = await personal.loadSessions(
      teamId: teamId,
      userId: ownerUserId,
      playerId: effectivePlayerId,
      limit: 500,
    );

    Map<String, dynamic>? rawSession;
    for (final row in rows) {
      final id = int.tryParse('${row['id'] ?? row['session_id'] ?? 0}') ?? 0;
      if (id == sessionId) {
        rawSession = row;
        break;
      }
    }
    if (rawSession == null) {
      throw Exception('Личная тренировка #$sessionId не найдена.');
    }

    final session = TrackerSessionModel.fromJson(rawSession);
    if (session.playerId != null && session.playerId! > 0) {
      effectivePlayerId = session.playerId;
    }

    List<ActionTrackerGpsPoint> gps = const <ActionTrackerGpsPoint>[];
    try {
      gps = await personal.loadSessionPoints(
        teamId: teamId,
        userId: ownerUserId,
        sessionId: sessionId,
        limit: 15000,
      );
    } catch (_) {
      // The session summary is still useful when GPS details are temporarily
      // unavailable; do not turn the whole personal AI/report into an error.
    }

    Map<String, dynamic> hrJson = const <String, dynamic>{};
    try {
      hrJson = await TrackerProApi(apiBaseUrl: apiBaseUrl).loadHeartRateSummary(
        teamId: teamId,
        playerId: effectivePlayerId,
        sessionId: sessionId,
        sessionKind: 'personal',
      );
    } catch (_) {
      // Polar is optional for a personal session.
    }

    Map<String, dynamic> mapValue(dynamic raw) =>
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    List<dynamic> listValue(dynamic raw) {
      if (raw is List) return raw;
      if (raw is Map) {
        final nested = raw['items'] ??
            raw['players'] ??
            raw['timeline'] ??
            raw['points'] ??
            raw['data'];
        return nested is List ? nested : const <dynamic>[];
      }
      return const <dynamic>[];
    }
    double d(dynamic value) => value is num
        ? value.toDouble()
        : (double.tryParse('${value ?? ''}') ?? 0.0);
    int i(dynamic value) => value is num
        ? value.toInt()
        : (int.tryParse('${value ?? ''}') ?? 0);
    dynamic first(Map<String, dynamic> map, List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value != null && '$value'.trim().isNotEmpty && '$value' != '0') {
          return value;
        }
      }
      return null;
    }

    final hrSummary = <String, dynamic>{
      ...mapValue(hrJson['summary']),
      if (hrJson.containsKey('avg_bpm')) 'avg_bpm': hrJson['avg_bpm'],
      if (hrJson.containsKey('heart_rate_avg_bpm'))
        'avg_bpm': hrJson['heart_rate_avg_bpm'],
      if (hrJson.containsKey('max_bpm')) 'max_bpm': hrJson['max_bpm'],
      if (hrJson.containsKey('heart_rate_max_bpm'))
        'max_bpm': hrJson['heart_rate_max_bpm'],
      if (hrJson.containsKey('samples_count'))
        'samples_count': hrJson['samples_count'],
      if (hrJson.containsKey('heart_rate_samples_count'))
        'samples_count': hrJson['heart_rate_samples_count'],
    };

    final hrPlayersRaw = listValue(hrJson['items']).isNotEmpty
        ? listValue(hrJson['items'])
        : (listValue(hrJson['players']).isNotEmpty
            ? listValue(hrJson['players'])
            : listValue(hrJson['player_summaries']));
    Map<String, dynamic> hrPlayer = const <String, dynamic>{};
    for (final raw in hrPlayersRaw.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final id = i(row['player_id'] ?? row['playerId'] ?? row['id']);
      if (id == effectivePlayerId || id == ownerUserId) {
        hrPlayer = row;
        break;
      }
      if (hrPlayer.isEmpty) hrPlayer = row;
    }

    final timeline = listValue(hrJson['timeline']).isNotEmpty
        ? listValue(hrJson['timeline'])
        : (listValue(hrJson['heart_rate_timeline']).isNotEmpty
            ? listValue(hrJson['heart_rate_timeline'])
            : (listValue(hrJson['hr_timeline']).isNotEmpty
                ? listValue(hrJson['hr_timeline'])
                : listValue(hrJson['points'])));

    TrackerPlayerOption? rosterPlayer;
    for (final candidate in rosterPlayers) {
      if (candidate.id == effectivePlayerId ||
          candidate.id == ownerUserId ||
          candidate.identityIds.contains(effectivePlayerId) ||
          candidate.identityIds.contains(ownerUserId)) {
        rosterPlayer = candidate;
        break;
      }
    }

    final gpsDistanceByTotal = gps.fold<double>(0, (maxValue, point) {
      final value = point.totalDistanceM ?? 0;
      return value > maxValue ? value : maxValue;
    });
    final gpsDistanceByDelta = gps.fold<double>(0, (sum, point) {
      final value = point.distanceDeltaM ?? 0;
      return value > 0 && value < 100 ? sum + value : sum;
    });
    final distanceM = session.distanceM > 0
        ? session.distanceM
        : (gpsDistanceByTotal > 0 ? gpsDistanceByTotal : gpsDistanceByDelta);

    final speedSamples = gps
        .map((p) => p.speedKmh ?? 0)
        .where((v) => v >= 0 && v <= 50)
        .toList(growable: false);
    final gpsMaxSpeed = speedSamples.isEmpty
        ? 0.0
        : speedSamples.reduce((a, b) => a > b ? a : b);
    final gpsAvgSpeed = speedSamples.isEmpty
        ? 0.0
        : speedSamples.fold<double>(0, (sum, v) => sum + v) /
            speedSamples.length;

    var durationSec = session.durationSec;
    if (durationSec <= 0 && gps.length > 1) {
      final minTime = gps.fold<int>(gps.first.timeMs,
          (value, p) => p.timeMs > 0 && p.timeMs < value ? p.timeMs : value);
      final maxTime = gps.fold<int>(gps.first.timeMs,
          (value, p) => p.timeMs > value ? p.timeMs : value);
      if (maxTime > minTime) durationSec = ((maxTime - minTime) / 1000).round();
    }
    final metersPerMin = session.metersPerMinute > 0
        ? session.metersPerMinute
        : (durationSec > 0 ? distanceM / (durationSec / 60.0) : 0.0);
    final avgSpeed = session.avgSpeedKmh > 0 ? session.avgSpeedKmh : gpsAvgSpeed;
    final maxSpeed = session.maxSpeedKmh > 0 ? session.maxSpeedKmh : gpsMaxSpeed;

    final avgBpm = d(first(hrPlayer, const <String>[
          'avg_bpm',
          'heart_rate_avg_bpm',
          'average_bpm',
        ]) ??
        first(hrSummary, const <String>['avg_bpm', 'heart_rate_avg_bpm']));
    final maxBpm = d(first(hrPlayer, const <String>[
          'max_bpm',
          'heart_rate_max_bpm',
        ]) ??
        first(hrSummary, const <String>['max_bpm', 'heart_rate_max_bpm']));
    final minBpm = d(first(hrPlayer, const <String>[
      'min_bpm',
      'heart_rate_min_bpm',
    ]));
    final hrSamples = i(first(hrPlayer, const <String>[
          'samples_count',
          'heart_rate_samples_count',
        ]) ??
        first(hrSummary, const <String>[
          'samples_count',
          'heart_rate_samples_count',
        ]) ??
        timeline.length);

    final playerName = (rosterPlayer?.name ?? session.playerName ?? '').trim();
    final reportPlayerId = rosterPlayer?.id ?? effectivePlayerId;
    final clubId = i(rawSession['club_id'] ?? rawSession['clubId']);

    final route = gps
        .map((p) => <String, dynamic>{
              'player_id': p.playerId ?? reportPlayerId,
              'player_name': playerName,
              // The report model needs generic x/y coordinates. Personal
              // report sections only need the verified point count/speed; the
              // dedicated Map tab continues to use the real lat/lng points.
              'x': p.longitude,
              'y': p.latitude,
              'speed_kmh': p.speedKmh ?? 0,
              'distance_m': p.totalDistanceM ?? 0,
              'time_ms': p.timeMs,
              'break_before': p.breakBefore,
            })
        .toList(growable: false);

    final player = <String, dynamic>{
      'player_id': reportPlayerId,
      'player_name': playerName.isEmpty ? 'Игрок' : playerName,
      'avatar_url': rosterPlayer?.avatar ?? '',
      'number': rosterPlayer?.number ?? '',
      'position': rosterPlayer?.position ?? '',
      'device_name': session.deviceName,
      'duration': _durationLabel(durationSec),
      'distance_m': distanceM,
      'meters_per_min': metersPerMin,
      'max_speed_kmh': maxSpeed,
      'avg_speed_kmh': avgSpeed,
      'accelerations': session.accelCount,
      'decelerations': session.decelCount,
      'acc_dec_per_min': durationSec > 0
          ? (session.accelCount + session.decelCount) / (durationSec / 60.0)
          : 0,
      'explosive_actions': session.accelCount + session.decelCount + session.sprintCount,
      'v3_run_m': session.hirDistanceM,
      'v4_hsr_m': session.hsrDistanceM > 0 ? session.hsrDistanceM : session.vhirDistanceM,
      'v5_sprint_m': session.sprintDistanceM,
      'sprint_count': session.sprintCount,
      'high_speed_work_m': session.hsrDistanceM > 0
          ? session.hsrDistanceM
          : (session.hirDistanceM + session.vhirDistanceM),
      'high_speed_actions': session.sprintCount,
      'player_load': session.loadScore,
      'heart_rate_avg_bpm': avgBpm,
      'heart_rate_max_bpm': maxBpm,
      'heart_rate_min_bpm': minBpm,
      'heart_rate_samples_count': hrSamples,
      'hr_zones': mapValue(hrPlayer['zones'] ?? hrPlayer['hr_zones']),
      'points_count': gps.length,
      'sessions_count': 1,
      'has_movement': distanceM > 0 || gps.isNotEmpty,
    };

    final reportJson = <String, dynamic>{
      'session_id': sessionId,
      'session_ids': <int>[sessionId],
      'team_id': teamId,
      'club_id': clubId,
      'team_name': teamName,
      'title': session.title.trim().isEmpty ? 'Личная тренировка' : session.title,
      'date_label': session.createdAt,
      'duration_label': _durationLabel(durationSec),
      'players_count': 1,
      'points_count': gps.length,
      'has_data': distanceM > 0 || gps.isNotEmpty || hrSamples > 0,
      'data_status': 'personal_verified',
      'summary': <String, dynamic>{
        'average_distance_m': distanceM,
        'total_distance_m': distanceM,
        'high_speed_distance_m': session.hsrDistanceM > 0
            ? session.hsrDistanceM
            : (session.hirDistanceM + session.vhirDistanceM),
        'player_load': session.loadScore,
        'acc_dec_per_min': durationSec > 0
            ? (session.accelCount + session.decelCount) / (durationSec / 60.0)
            : 0,
        'max_speed_kmh': maxSpeed,
        'avg_speed_kmh': avgSpeed,
        'distance_per_min_m': metersPerMin,
        'acceleration_count': session.accelCount,
        'deceleration_count': session.decelCount,
        'explosive_actions': session.accelCount + session.decelCount + session.sprintCount,
        'sprint_count': session.sprintCount,
        'sprint_distance_m': session.sprintDistanceM,
        'v3_run_m': session.hirDistanceM,
        'v4_hsr_m': session.hsrDistanceM > 0 ? session.hsrDistanceM : session.vhirDistanceM,
        'v5_sprint_m': session.sprintDistanceM,
        'heart_rate_avg_bpm': avgBpm,
        'heart_rate_max_bpm': maxBpm,
        'heart_rate_samples_count': hrSamples,
      },
      'players': <Map<String, dynamic>>[player],
      'route_points': route,
      'heart_rate_timeline': timeline,
    };

    var report = TrackerTrainingReport.fromJson(reportJson);
    if (gps.isNotEmpty) {
      report = _withValidatedGpsSpeeds(report, gps, rosterPlayers);
    }
    if (rosterPlayers.isNotEmpty) {
      report = _withRosterIdentity(report, rosterPlayers);
    }
    return report;
  }

  TrackerTrainingReport _withValidatedGpsSpeeds(
    TrackerTrainingReport report,
    List<ActionTrackerGpsPoint> gpsPoints,
    List<TrackerPlayerOption> roster,
  ) {
    final validation = _validateReportGpsSpeeds(gpsPoints);
    if (!validation.hasGps) return report;

    double? maxForRow(TrackerTrainingPlayerRow row) {
      final id = row.playerId;
      if (id != null && validation.maxByPlayer.containsKey(id)) {
        return validation.maxByPlayer[id] ?? 0.0;
      }
      if (id != null && roster.isNotEmpty) {
        for (final player in roster) {
          if (player.id != id && !player.identityIds.contains(id)) continue;
          final values = <double>[];
          for (final identity in <int>{player.id, ...player.identityIds}) {
            if (validation.maxByPlayer.containsKey(identity)) {
              values.add(validation.maxByPlayer[identity] ?? 0.0);
            }
          }
          if (values.isNotEmpty) return values.reduce(math.max);
        }
      }
      return null;
    }

    List<TrackerTrainingPlayerRow> fixRows(
            List<TrackerTrainingPlayerRow> rows) =>
        rows.map((row) {
          final validated = maxForRow(row);
          return validated == null
              ? row
              : row.copyWith(maxSpeedKmh: validated);
        }).toList(growable: false);

    final fixedPlayers = fixRows(report.players);
    final fixedDiagnosticPlayers = fixRows(report.diagnosticPlayers);

    double routeLimit(TrackerReportPoint point) {
      final id = point.playerId;
      if (id != null && validation.maxByPlayer.containsKey(id)) {
        return validation.maxByPlayer[id] ?? 0.0;
      }
      return validation.teamMaxKmh;
    }

    final fixedRoute = report.routePoints.map((point) {
      final limit = routeLimit(point);
      if (point.speedKmh <= 0) return point;
      if (limit <= 0) return point.copyWith(speedKmh: 0);
      // Report route speed может быть рассчитан другим PHP путём. Оставляем
      // близкие значения, но убираем точку, если она выше реально
      // подтверждённого GPS-максимума с небольшим допуском.
      if (point.speedKmh > limit + .75) {
        return point.copyWith(speedKmh: 0);
      }
      return point;
    }).toList(growable: false);

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
      playersCount: report.playersCount,
      pointsCount: report.pointsCount,
      hasData: report.hasData,
      dataStatus: report.dataStatus,
      summary: report.summary.copyWith(maxSpeedKmh: validation.teamMaxKmh),
      periods: report.periods,
      microcycle: report.microcycle,
      players: fixedPlayers,
      diagnosticPlayers: fixedDiagnosticPlayers,
      routePoints: fixedRoute,
      heatmapPoints: report.heatmapPoints,
      speedZones: report.speedZones,
      heartRateTimeline: report.heartRateTimeline,
      events: report.events,
    );
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

    final enrichedEvents = report.events.map((event) {
      TrackerPlayerOption? player;
      final id = event.playerId;
      if (id != null && id > 0) {
        for (final candidate in roster) {
          if (candidate.id == id || candidate.identityIds.contains(id)) {
            player = candidate;
            break;
          }
        }
      }
      if (player == null) {
        final raw = event.playerName.trim().toLowerCase();
        if (raw.isNotEmpty &&
            !RegExp(r'^игрок\s*\d*$', caseSensitive: false).hasMatch(raw)) {
          for (final candidate in roster) {
            if (candidate.name.trim().toLowerCase() == raw) {
              player = candidate;
              break;
            }
          }
        }
      }
      return player == null ? event : event.copyWith(playerName: player.name);
    }).toList(growable: false);

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
      events: enrichedEvents,
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
        ? 'summary,maps,heatmap,events,speed,internal,hr,players,performance_matrix,rating,locomotor,mechanics,microcycle,periods,player_pages,ai'
        : sections.map(Uri.encodeQueryComponent).join(',');
    final sessions = <int>[];
    for (final id in <int>[sessionId, ...?sessionIds]) {
      if (id > 0 && !sessions.contains(id)) sessions.add(id);
    }
    final query = StringBuffer('$apiBaseUrl/export_training_report_pdf.php?session_id=$sessionId&team_id=$teamId&template=cmr_v2&inline=1&print=1&full=1&report=analytics_export&format=pdf');
    if (sessions.length > 1) query.write('&session_ids=${Uri.encodeQueryComponent(sessions.join(','))}');
    query.write('&include_maps=${includeMaps ? 1 : 0}&include_heatmap=${includeHeatmap ? 1 : 0}&include_hr=1&include_players=1&include_charts=${includeCharts ? 1 : 0}');
    query.write('&include_player_pages=${includePlayerPages ? 1 : 0}&per_player_charts=${includePlayerPages ? 1 : 0}&timeline=${includeCharts ? 1 : 0}');
    query.write('&include_locomotor=1&include_mechanics=1&include_internal=1&include_microcycle=1&sections=$sectionList&ai_stub=1');
    query.write('&include_logo=${includeLogo ? 1 : 0}&include_photos=${includePhotos ? 1 : 0}');
    if (players.isNotEmpty) query.write('&player_ids=$players&player_id=$players');
    if (names.isNotEmpty) query.write('&player_names=$names');
    query.write('&v=122');
    return Uri.parse(query.toString());
  }

  Uri csvExportUri({required int sessionId, required int teamId, List<int>? sessionIds, List<int>? playerIds, List<String>? playerNames, List<String>? sections}) {
    final players = (playerIds ?? const <int>[]).where((id) => id > 0).join(',');
    final names = (playerNames ?? const <String>[]).where((name) => name.trim().isNotEmpty).map(Uri.encodeQueryComponent).join(',');
    final sectionList = (sections == null || sections.isEmpty) ? 'summary,maps,events,speed,internal,hr,players,performance_matrix,rating,locomotor,mechanics,microcycle,periods,player_pages,ai' : sections.map(Uri.encodeQueryComponent).join(',');
    final sessions = <int>[];
    for (final id in <int>[sessionId, ...?sessionIds]) {
      if (id > 0 && !sessions.contains(id)) sessions.add(id);
    }
    final query = StringBuffer('$apiBaseUrl/export_training_report_csv.php?session_id=$sessionId&team_id=$teamId&full=1&include_hr=1&include_players=1&sections=$sectionList');
    if (sessions.length > 1) query.write('&session_ids=${Uri.encodeQueryComponent(sessions.join(','))}');
    if (players.isNotEmpty) query.write('&player_ids=$players&player_id=$players');
    if (names.isNotEmpty) query.write('&player_names=$names');
    query.write('&v=121');
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
  final events = _mergeReportEvents(reports.expand((report) => report.events));
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
    clubId: primary.clubId > 0 ? primary.clubId : reports.fold<int>(0, (value, report) => value > 0 ? value : report.clubId),
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
    events: events,
  );
}

List<TrackerReportEvent> _mergeReportEvents(Iterable<TrackerReportEvent> source) {
  final byKey = <String, TrackerReportEvent>{};
  for (final event in source) {
    final key = event.id.trim().isNotEmpty
        ? event.id.trim()
        : '${event.playerId ?? 0}|${event.kind}|${event.timeMs}|${event.elapsedMs}';
    final existing = byKey[key];
    if (existing == null || (!existing.hasPoint && event.hasPoint)) {
      byKey[key] = event;
    }
  }
  final out = byKey.values.toList(growable: false)
    ..sort((a, b) => b.timeMs.compareTo(a.timeMs));
  return out.take(420).toList(growable: false);
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


class _ReportGpsSpeedValidation {
  const _ReportGpsSpeedValidation({
    required this.hasGps,
    required this.teamMaxKmh,
    required this.maxByPlayer,
  });

  final bool hasGps;
  final double teamMaxKmh;
  final Map<int, double> maxByPlayer;
}

_ReportGpsSpeedValidation _validateReportGpsSpeeds(
    List<ActionTrackerGpsPoint> points) {
  final groups = <int, List<ActionTrackerGpsPoint>>{};
  for (final point in points) {
    final playerId = point.playerId ?? 0;
    if (point.timeMs <= 0 ||
        point.latitude == 0 ||
        point.longitude == 0) {
      continue;
    }
    groups.putIfAbsent(playerId, () => <ActionTrackerGpsPoint>[]).add(point);
  }

  final maxByPlayer = <int, double>{};
  var teamMax = 0.0;
  for (final entry in groups.entries) {
    final series = entry.value..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    var maxSpeed = 0.0;
    var anchorIndex = 0;
    var prevSpeed = 0.0;

    for (var i = 1; i < series.length; i++) {
      final anchor = series[anchorIndex];
      final next = series[i];

      final sessionBreak = next.breakBefore ||
          (anchor.liveSessionId != null &&
              next.liveSessionId != null &&
              anchor.liveSessionId != next.liveSessionId) ||
          (anchor.sessionId != null &&
              next.sessionId != null &&
              anchor.sessionId != next.sessionId);
      if (sessionBreak) {
        anchorIndex = i;
        prevSpeed = 0.0;
        continue;
      }

      final dtMs = next.timeMs - anchor.timeMs;
      if (dtMs <= 0) continue;
      if (dtMs > 10000) {
        anchorIndex = i;
        prevSpeed = 0.0;
        continue;
      }

      final distanceM = _reportGpsDistanceMeters(
        anchor.latitude,
        anchor.longitude,
        next.latitude,
        next.longitude,
      );
      final speedKmh = (distanceM / (dtMs / 1000.0)) * 3.6;
      if (!speedKmh.isFinite) continue;

      if (distanceM <= .35 || speedKmh < 1.5) {
        anchorIndex = i;
        prevSpeed = 0.0;
        continue;
      }

      final accelMps2 =
          (((speedKmh - prevSpeed) / 3.6) / (dtMs / 1000.0)).abs();
      final rejected = distanceM > 80.0 ||
          speedKmh > 36.0 ||
          (speedKmh >= 28.0 && accelMps2 > 4.5) ||
          (speedKmh >= 16.0 && accelMps2 > 7.0);
      if (rejected) {
        // Как и в Analytics V85/V87, отброшенная GPS-точка не становится
        // anchor: иначе возврат после скачка породит второй ложный пик.
        continue;
      }

      maxSpeed = math.max(maxSpeed, speedKmh);
      anchorIndex = i;
      prevSpeed = speedKmh;
    }

    maxByPlayer[entry.key] = maxSpeed;
    teamMax = math.max(teamMax, maxSpeed);
  }

  return _ReportGpsSpeedValidation(
    hasGps: groups.isNotEmpty,
    teamMaxKmh: teamMax,
    maxByPlayer: Map<int, double>.unmodifiable(maxByPlayer),
  );
}

double _reportGpsDistanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusM = 6371000.0;
  final p1 = lat1 * math.pi / 180.0;
  final p2 = lat2 * math.pi / 180.0;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLon = (lon2 - lon1) * math.pi / 180.0;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(p1) *
          math.cos(p2) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadiusM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
