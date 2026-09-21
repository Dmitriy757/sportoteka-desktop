import 'dart:convert';

/// Shared wire format for the Workspace OS training-plan document.
///
/// Keeping the codec outside WorkspaceDocumentEditor lets Plans, Workspace and
/// any future plan entry point open exactly the same document without creating
/// a second editor or a second storage format.
class WorkspaceTrainingPlanCodec {
  static const String tokenPrefix = '[[SPORTOTEKA_PLAN_V2:';
  static const String tokenSuffix = ']]';

  static Map<String, dynamic> newPlan({
    String clubName = '',
    String teamName = '',
    String trainerName = '',
    String cycle = '',
    String date = '',
    String theme = '',
    String location = '',
    dynamic playersCount = '',
    dynamic durationMin = '',
  }) {
    return <String, dynamic>{
      'version': 2,
      'cycle': cycle,
      'date': date,
      'club': clubName,
      'trainers': trainerName,
      'team': teamName,
      'duration_min': '$durationMin',
      'location': location,
      'players_count': '$playersCount',
      'theme': theme,
      'goal_tech': '',
      'goal_tact': '',
      'goal_fit': '',
      'goal_ment': '',
      'equipment': '',
      'signed_role': trainerName.trim().isEmpty ? '' : 'Тренер',
      'signed_by': trainerName,
      'team_logo_url': '',
      'team_logo_data': '',
      'team_logo_hidden': false,
      'exercises': <dynamic>[
        <String, dynamic>{
          'index': 1,
          'title': '',
          'duration_min': '',
          'intensity': '',
          'repetitions': '',
          'work_time': '',
          'pause_time': '',
          'organization': '',
          'coach_focus': '',
          'schemes': <dynamic>[],
        },
      ],
    };
  }

  static String encode(Map<String, dynamic> data) {
    final json = jsonEncode(data);
    final encoded = base64Url.encode(utf8.encode(json)).replaceAll('=', '');
    return '$tokenPrefix$encoded$tokenSuffix';
  }

  static Map<String, dynamic>? decode(String raw) {
    final value = raw.trim();
    if (!value.startsWith(tokenPrefix) || !value.endsWith(tokenSuffix)) {
      return null;
    }
    try {
      var encoded = value.substring(
        tokenPrefix.length,
        value.length - tokenSuffix.length,
      );
      while (encoded.length % 4 != 0) {
        encoded += '=';
      }
      final decoded = utf8.decode(base64Url.decode(encoded));
      final data = jsonDecode(decoded);
      if (data is! Map) return null;
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? decodeFirst(String body) {
    final start = body.indexOf(tokenPrefix);
    if (start < 0) return null;
    final end = body.indexOf(tokenSuffix, start + tokenPrefix.length);
    if (end < 0) return null;
    return decode(body.substring(start, end + tokenSuffix.length));
  }

  static bool containsPlan(String body) => decodeFirst(body) != null;
}
