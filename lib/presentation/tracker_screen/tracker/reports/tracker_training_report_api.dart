import 'dart:convert';
import 'package:http/http.dart' as http;

import 'tracker_training_report_models.dart';
import '../models/tracker_pro_models.dart';

class TrackerTrainingReportApi {
  TrackerTrainingReportApi({this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker'});

  final String apiBaseUrl;

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
    final query = StringBuffer('$apiBaseUrl/export_training_report_pdf.php?session_id=$sessionId&team_id=$teamId&template=analytics_ru&inline=1&print=1&full=1&report=analytics_export');
    query.write('&include_maps=${includeMaps ? 1 : 0}&include_heatmap=${includeHeatmap ? 1 : 0}&include_hr=1&include_players=1&include_charts=${includeCharts ? 1 : 0}');
    query.write('&include_player_pages=${includePlayerPages ? 1 : 0}&per_player_charts=${includePlayerPages ? 1 : 0}&timeline=${includeCharts ? 1 : 0}');
    query.write('&include_locomotor=1&include_mechanics=1&include_internal=1&include_microcycle=1&sections=$sectionList&ai_stub=1');
    query.write('&include_logo=${includeLogo ? 1 : 0}&include_photos=${includePhotos ? 1 : 0}');
    if (players.isNotEmpty) query.write('&player_ids=$players&player_id=$players');
    if (names.isNotEmpty) query.write('&player_names=$names');
    query.write('&v=120');
    return Uri.parse(query.toString());
  }

  Uri csvExportUri({required int sessionId, required int teamId, List<int>? playerIds, List<String>? playerNames, List<String>? sections}) {
    final players = (playerIds ?? const <int>[]).where((id) => id > 0).join(',');
    final names = (playerNames ?? const <String>[]).where((name) => name.trim().isNotEmpty).map(Uri.encodeQueryComponent).join(',');
    final sectionList = (sections == null || sections.isEmpty) ? 'summary,performance_matrix,players,locomotor,mechanics,hr,comparison,zones' : sections.map(Uri.encodeQueryComponent).join(',');
    final query = StringBuffer('$apiBaseUrl/export_training_report_csv.php?session_id=$sessionId&team_id=$teamId&full=1&include_hr=1&include_players=1&sections=$sectionList');
    if (players.isNotEmpty) query.write('&player_ids=$players&player_id=$players');
    if (names.isNotEmpty) query.write('&player_names=$names');
    query.write('&v=120');
    return Uri.parse(query.toString());
  }
}
