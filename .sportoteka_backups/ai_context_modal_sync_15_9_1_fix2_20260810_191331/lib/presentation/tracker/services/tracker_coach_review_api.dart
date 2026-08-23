import 'dart:convert';
import 'package:http/http.dart' as http;

class TrackerCoachReview {
  final int sessionId;
  final int playerId;
  final int teamId;
  final int coachId;
  final int rating;
  final String comment;
  final String updatedAt;

  const TrackerCoachReview({
    required this.sessionId,
    required this.playerId,
    required this.teamId,
    required this.coachId,
    required this.rating,
    required this.comment,
    required this.updatedAt,
  });

  factory TrackerCoachReview.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic value) =>
        value is int ? value : int.tryParse('${value ?? 0}') ?? 0;
    return TrackerCoachReview(
      sessionId: asInt(map['session_id']),
      playerId: asInt(map['player_id']),
      teamId: asInt(map['team_id']),
      coachId: asInt(map['coach_id']),
      rating: asInt(map['rating']),
      comment: '${map['comment'] ?? ''}',
      updatedAt: '${map['updated_at'] ?? ''}',
    );
  }
}

class TrackerCoachReviewApi {
  static const String base = 'https://sportotekaapp.ru/api/ai/v1';

  static Future<TrackerCoachReview?> getReview({
    required int sessionId,
    required int playerId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '$base/tracker/session/$sessionId/coach-review?player_id=$playerId'),
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['review'] is! Map) return null;
    return TrackerCoachReview.fromMap(
      Map<String, dynamic>.from(data['review'] as Map),
    );
  }

  static Future<TrackerCoachReview> saveReview({
    required int clubId,
    required int teamId,
    required int sessionId,
    required int playerId,
    required int coachId,
    required int rating,
    required String comment,
  }) async {
    final response = await http.put(
      Uri.parse('$base/tracker/session/$sessionId/coach-review'),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'club_id': clubId,
        'team_id': teamId,
        'player_id': playerId,
        'coach_id': coachId,
        'rating': rating,
        'comment': comment,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return TrackerCoachReview.fromMap(
      Map<String, dynamic>.from(data['review'] as Map),
    );
  }
}
