import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';

/// Stable identity for a real Sportoteka entity.
///
/// The same match/training/plan/test must resolve to the same document key
/// regardless of whether it was opened from Finder, Team, Trainer or Player.
class WorkspaceEntityIdentity {
  const WorkspaceEntityIdentity({
    required this.type,
    required this.id,
    required this.key,
  });

  final String type;
  final String id;
  final String key;

  bool get isValid => type.isNotEmpty && id.isNotEmpty;

  static WorkspaceEntityIdentity resolve({
    required int clubId,
    required Map<String, dynamic> record,
    String sectionHint = '',
    WorkspaceFinderNodeKind? kind,
    String fallbackType = '',
    String fallbackId = '',
  }) {
    final explicitType = _text(record['_workspace_entity_type']);
    final explicitId = _text(record['_workspace_entity_id']);
    if (explicitType.isNotEmpty && explicitId.isNotEmpty) {
      return _build(clubId, explicitType, explicitId);
    }

    final hint = sectionHint.trim().toLowerCase();
    final type = explicitType.isNotEmpty
        ? explicitType
        : _typeFor(kind: kind, hint: hint, record: record, fallback: fallbackType);
    final id = explicitId.isNotEmpty
        ? explicitId
        : _idFor(type: type, hint: hint, record: record, fallback: fallbackId);

    if (type.isEmpty || id.isEmpty) {
      final stable = _stableFallback(record, hint: hint, fallbackId: fallbackId);
      final safeType = type.isEmpty ? (fallbackType.isEmpty ? 'record' : fallbackType) : type;
      return _build(clubId, safeType, stable);
    }
    return _build(clubId, type, id);
  }

  static WorkspaceEntityIdentity _build(int clubId, String type, String id) {
    final safeType = _safe(type);
    final safeId = _safe(id);
    return WorkspaceEntityIdentity(
      type: safeType,
      id: safeId,
      key: 'sportoteka_entity_${clubId}_${safeType}_$safeId',
    );
  }

  static String _typeFor({
    WorkspaceFinderNodeKind? kind,
    required String hint,
    required Map<String, dynamic> record,
    required String fallback,
  }) {
    switch (kind) {
      case WorkspaceFinderNodeKind.match:
        return 'match';
      case WorkspaceFinderNodeKind.training:
      case WorkspaceFinderNodeKind.calendar:
        return 'training';
      case WorkspaceFinderNodeKind.plan:
        return 'plan';
      case WorkspaceFinderNodeKind.testing:
        return 'testing';
      case WorkspaceFinderNodeKind.tracker:
        return 'tracker';
      case WorkspaceFinderNodeKind.medical:
        return 'medical_record';
      case WorkspaceFinderNodeKind.document:
        return 'document';
      case WorkspaceFinderNodeKind.player:
        return 'player';
      case WorkspaceFinderNodeKind.trainer:
        return 'trainer';
      case WorkspaceFinderNodeKind.team:
        return 'team';
      case WorkspaceFinderNodeKind.video:
        return 'video';
      default:
        break;
    }

    if (hint.contains('match') || hint.contains('матч')) return 'match';
    if (hint.contains('training') || hint.contains('трен') || hint.contains('calendar')) return 'training';
    if (hint.contains('plan') || hint.contains('план')) return 'plan';
    if (hint.contains('test') || hint.contains('тест')) return 'testing';
    if (hint.contains('tracker') || hint.contains('трек')) return 'tracker';
    if (hint.contains('health') || hint.contains('medical') || hint.contains('здоров')) return 'medical_record';
    if (hint.contains('document') || hint.contains('документ')) return 'document';

    if (_first(record, const <String>['match_id']).isNotEmpty) return 'match';
    if (_first(record, const <String>['plan_id']).isNotEmpty) return 'plan';
    if (_first(record, const <String>['event_id', 'training_id', 'calendar_event_id']).isNotEmpty) return 'training';
    if (_first(record, const <String>['test_id', 'testing_id']).isNotEmpty) return 'testing';
    if (_first(record, const <String>['tracker_session_id']).isNotEmpty) return 'tracker';
    return fallback.trim().toLowerCase();
  }

  static String _idFor({
    required String type,
    required String hint,
    required Map<String, dynamic> record,
    required String fallback,
  }) {
    switch (type) {
      case 'match':
        return _first(record, const <String>['match_id', 'id']);
      case 'training':
        return _first(record, const <String>['event_id', 'training_id', 'calendar_event_id', 'id']);
      case 'plan':
        return _first(record, const <String>['plan_id', 'id']);
      case 'testing':
        return _first(record, const <String>['test_id', 'testing_id', 'session_id', 'id']);
      case 'tracker':
        return _first(record, const <String>['tracker_session_id', 'session_id', 'id']);
      case 'medical_record':
      case 'document':
        return _first(record, const <String>['record_id', 'document_id', 'id']);
      case 'player':
        return _first(record, const <String>['player_id', 'id', 'user_id']);
      case 'trainer':
        return _first(record, const <String>['trainer_id', 'id', 'user_id']);
      case 'team':
        return _first(record, const <String>['team_id', 'id']);
      case 'video':
        return _first(record, const <String>['video_id', 'media_id', 'id']);
      default:
        return _first(record, const <String>[
          'id', 'record_id', 'document_id', 'match_id', 'event_id', 'plan_id',
          'test_id', 'session_id', 'player_id', 'trainer_id', 'team_id',
        ], fallback: fallback);
    }
  }

  static String _stableFallback(Map<String, dynamic> record, {required String hint, required String fallbackId}) {
    final supplied = fallbackId.trim();
    if (supplied.isNotEmpty) return _safe(supplied);
    final seed = <String>[
      hint,
      _first(record, const <String>['date', 'match_date', 'event_date', 'start_at', 'test_date', 'record_date', 'created_at']),
      _first(record, const <String>['title', 'name', 'opponent', 'opponent_name', 'file_name']),
      _first(record, const <String>['team_id']),
    ].where((e) => e.isNotEmpty).join('|');
    var hash = 0x811C9DC5;
    for (final code in seed.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'h${hash.toRadixString(16)}';
  }

  static String _first(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = _text(map[key]);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  static String _text(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  static String _safe(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
}
