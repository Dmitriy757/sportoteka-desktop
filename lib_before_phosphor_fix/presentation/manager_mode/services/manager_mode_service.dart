import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/manager_lineup_model.dart';
import '../models/manager_live_match_event_model.dart';
import '../models/manager_live_match_lineup_model.dart';
import '../models/manager_live_match_model.dart';
import '../models/manager_match_list_model.dart';
import '../models/manager_match_report_model.dart';
import '../models/manager_player_state_model.dart';
import '../models/manager_season_overview_model.dart';
import '../models/manager_team_overview_model.dart';

class ManagerLiveMatchStateResponse {
  final ManagerLiveMatchModel match;
  final List<ManagerLiveMatchEventModel> events;
  final List<ManagerLiveMatchLineupModel> lineup;

  ManagerLiveMatchStateResponse({
    required this.match,
    required this.events,
    required this.lineup,
  });

  factory ManagerLiveMatchStateResponse.fromJson(Map<String, dynamic> json) {
    return ManagerLiveMatchStateResponse(
      match: ManagerLiveMatchModel.fromJson(
        Map<String, dynamic>.from(json['match'] ?? {}),
      ),
      events: (json['events'] as List? ?? [])
          .map(
            (e) => ManagerLiveMatchEventModel.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
      lineup: (json['lineup'] as List? ?? [])
          .map(
            (e) => ManagerLiveMatchLineupModel.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}

class ManagerModeService {
  static const String _base = 'https://sportotekaapp.ru/api/manager';

  static dynamic _safeDecode(http.Response response) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();

    if (body.isEmpty) {
      throw Exception('Пустой ответ сервера');
    }

    if (body.startsWith('<!DOCTYPE') ||
        body.startsWith('<html') ||
        body.startsWith('<br')) {
      throw Exception('Сервер вернул HTML/PHP error вместо JSON: $body');
    }

    try {
      return jsonDecode(body);
    } catch (e) {
      throw Exception('Некорректный JSON: $body');
    }
  }

  static Future<ManagerTeamOverviewModel> getTeamOverview({
    required int teamId,
    required int userId,
  }) async {
    final uri = Uri.parse(
      '$_base/get_manager_team_overview.php?team_id=$teamId&user_id=$userId',
    );

    final response = await http.get(uri);
    final data = _safeDecode(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return ManagerTeamOverviewModel.fromJson(data);
    }

    throw Exception(data['message'] ?? 'Ошибка загрузки overview');
  }

  static Future<List<ManagerPlayerStateModel>> getPlayersState({
    required int teamId,
  }) async {
    final uri = Uri.parse(
      '$_base/get_manager_players_state.php?team_id=$teamId',
    );

    final response = await http.get(uri);
    final data = _safeDecode(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return (data['players'] as List? ?? [])
          .map(
            (e) => ManagerPlayerStateModel.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    }

    throw Exception(data['message'] ?? 'Ошибка загрузки игроков');
  }

  static Future<void> saveTactics({
    required int teamId,
    required int userId,
    required String formation,
    required String playStyle,
    required String pressingLevel,
    required String tempo,
    required String defensiveLine,
    required String intensity,
  }) async {
    final uri = Uri.parse('$_base/save_manager_tactics.php');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'team_id': teamId,
        'user_id': userId,
        'formation': formation,
        'play_style': playStyle,
        'pressing_level': pressingLevel,
        'tempo': tempo,
        'defensive_line': defensiveLine,
        'intensity': intensity,
      }),
    );

    final data = _safeDecode(response);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Ошибка сохранения тактики');
    }
  }

  static Future<ManagerLineupResponse> getLineup({
    required int teamId,
    required int userId,
  }) async {
    final uri = Uri.parse(
      '$_base/get_manager_lineup.php?team_id=$teamId&user_id=$userId',
    );

    final response = await http.get(uri);
    final data = _safeDecode(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return ManagerLineupResponse.fromJson(data);
    }

    throw Exception(data['message'] ?? 'Ошибка загрузки состава');
  }

  static Future<void> saveLineup({
    required int teamId,
    required int userId,
    required String title,
    required String formation,
    required List<ManagerLineupPlayer> players,
  }) async {
    final uri = Uri.parse('$_base/save_manager_lineup.php');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'team_id': teamId,
        'user_id': userId,
        'title': title,
        'formation': formation,
        'players': players.map((e) => e.toJsonForSave()).toList(),
      }),
    );

    final data = _safeDecode(response);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Ошибка сохранения состава');
    }
  }

  static Future<ManagerSimulateMatchResponse> simulateMatch({
    required int teamId,
    required int userId,
    required String opponentName,
    int? opponentStrength,
    String? matchDate,
  }) async {
    final uri = Uri.parse('$_base/simulate_manager_match.php');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'team_id': teamId,
        'user_id': userId,
        'opponent_name': opponentName,
        'opponent_strength': opponentStrength,
        'match_date': matchDate,
      }),
    );

    final data = _safeDecode(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return ManagerSimulateMatchResponse.fromJson(data);
    }

    throw Exception(data['message'] ?? 'Ошибка симуляции матча');
  }

  static Future<ManagerMatchReportModel> getMatchReport({
    required int matchId,
  }) async {
    final uri = Uri.parse(
      '$_base/get_manager_match_report.php?match_id=$matchId',
    );

    final response = await http.get(uri);
    final data = _safeDecode(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return ManagerMatchReportModel.fromJson(data);
    }

    throw Exception(data['message'] ?? 'Ошибка загрузки отчёта');
  }

  static Future<List<ManagerMatchListItem>> getMatches({
    required int teamId,
    String filter = 'all',
  }) async {
    final uri = Uri.parse(
      '$_base/get_manager_matches.php?team_id=$teamId&filter=$filter',
    );

    final response = await http.get(uri);
    final data = _safeDecode(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return (data['matches'] as List? ?? [])
          .map(
            (e) => ManagerMatchListItem.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    }

    throw Exception(data['message'] ?? 'Ошибка загрузки матчей');
  }

  static Future<ManagerSeasonOverviewModel> getSeasonOverview({
    required int teamId,
  }) async {
    final uri = Uri.parse(
      '$_base/get_manager_season_overview.php?team_id=$teamId',
    );

    final response = await http.get(uri);
    final data = _safeDecode(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return ManagerSeasonOverviewModel.fromJson(data);
    }

    throw Exception(data['message'] ?? 'Ошибка загрузки сезона');
  }

  static Future<int> startLiveMatch({
    required int teamId,
    required int userId,
    required String opponentName,
    required int opponentStrength,
  }) async {
    final uri = Uri.parse('$_base/start_live_manager_match.php');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'team_id': teamId,
        'user_id': userId,
        'opponent_name': opponentName,
        'opponent_strength': opponentStrength,
      }),
    );

    final data = _safeDecode(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return int.tryParse(data['live_match_id'].toString()) ?? 0;
    }

    throw Exception(data['message'] ?? 'Ошибка старта live матча');
  }

  static Future<ManagerLiveMatchStateResponse> getLiveMatchState({
    required int liveMatchId,
  }) async {
    final uri = Uri.parse(
      '$_base/get_live_manager_match_state.php?live_match_id=$liveMatchId',
    );

    final response = await http.get(uri);
    final data = _safeDecode(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return ManagerLiveMatchStateResponse.fromJson(data);
    }

    throw Exception(data['message'] ?? 'Ошибка загрузки live матча');
  }

  static Future<void> advanceLiveMatch({
    required int liveMatchId,
    int minutesStep = 5,
  }) async {
    final uri = Uri.parse('$_base/advance_live_manager_match.php');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'live_match_id': liveMatchId,
        'minutes_step': minutesStep,
      }),
    );

    final data = _safeDecode(response);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Ошибка продвижения live матча');
    }
  }
}