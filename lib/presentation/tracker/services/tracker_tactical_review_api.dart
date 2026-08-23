import 'dart:convert';

import 'package:http/http.dart' as http;

class TrackerTacticalReviewDocument {
  const TrackerTacticalReviewDocument({
    required this.scopeKey,
    required this.annotations,
    this.updatedAt = '',
  });

  final String scopeKey;
  final List<Map<String, dynamic>> annotations;
  final String updatedAt;

  factory TrackerTacticalReviewDocument.fromJson(Map<String, dynamic> json) {
    dynamic raw = json['annotations'] ?? json['annotations_json'] ?? const [];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        raw = const [];
      }
    }
    final annotations = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          annotations.add(Map<String, dynamic>.from(item));
        }
      }
    }
    return TrackerTacticalReviewDocument(
      scopeKey: '${json['scope_key'] ?? ''}',
      annotations: annotations,
      updatedAt: '${json['updated_at'] ?? ''}',
    );
  }
}

class TrackerTacticalReviewApi {
  TrackerTacticalReviewApi({
    this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker',
    this.timeout = const Duration(seconds: 12),
  });

  final String apiBaseUrl;
  final Duration timeout;

  Future<TrackerTacticalReviewDocument?> load({
    required String scopeKey,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/get_tracker_tactical_review.php').replace(
      queryParameters: <String, String>{'scope_key': scopeKey},
    );
    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(timeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(
        'TACTICAL_REVIEW GET HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final root = Map<String, dynamic>.from(decoded);
    final review = root['review'];
    if (review == null) return null;
    if (review is! Map) return null;
    return TrackerTacticalReviewDocument.fromJson(
      Map<String, dynamic>.from(review),
    );
  }

  Future<TrackerTacticalReviewDocument> save({
    required String scopeKey,
    required int clubId,
    required int teamId,
    required int sessionId,
    required int createdBy,
    required int startMs,
    required int endMs,
    int? playerId,
    String title = '',
    required List<Map<String, dynamic>> annotations,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/save_tracker_tactical_review.php');
    final response = await http
        .put(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(<String, dynamic>{
            'scope_key': scopeKey,
            'club_id': clubId,
            'team_id': teamId,
            'session_id': sessionId > 0 ? sessionId : null,
            'player_id': playerId != null && playerId > 0 ? playerId : null,
            'created_by': createdBy,
            'title': title,
            'start_ms': startMs > 0 ? startMs : null,
            'end_ms': endMs > 0 ? endMs : null,
            'annotations': annotations,
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(
        'TACTICAL_REVIEW PUT HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['review'] is! Map) {
      throw const FormatException('Invalid tactical review response');
    }
    return TrackerTacticalReviewDocument.fromJson(
      Map<String, dynamic>.from(decoded['review'] as Map),
    );
  }
}
