import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sportoteka/presentation/workspace_os/workspace_entity_data_bridge.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_player_data_bridge.dart';

/// Turns the ordinary Sportoteka backend data into Finder records.
///
/// Important: this class does not create a second data store. Every row returned
/// here comes from the same APIs that the normal club/player screens use.
class WorkspaceRootDataBridge {
  WorkspaceRootDataBridge({
    required this.clubId,
    required this.teams,
    required this.players,
    required this.trainers,
    this.selectedTeamId,
    this.selectedTeamName = '',
  });

  final int clubId;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> trainers;
  final int? selectedTeamId;
  final String selectedTeamName;

  final WorkspaceEntityDataBridge _entity = WorkspaceEntityDataBridge();
  final WorkspacePlayerDataBridge _player = WorkspacePlayerDataBridge();

  Future<List<WorkspaceFinderNode>> loadFolder(String key) async {
    switch (key) {
      case 'matches':
        return _loadTeamCollection(
          kind: WorkspaceFinderNodeKind.match,
          moduleKey: 'matches',
          loader: (team) => _entity.loadTeamMatches(_teamId(team)),
          title: _matchTitle,
          subtitle: _matchSubtitle,
        );
      case 'trainings':
        return _loadTeamCollection(
          kind: WorkspaceFinderNodeKind.training,
          moduleKey: 'calendar',
          loader: (team) async {
            final rows = await _entity.loadTeamEvents(_teamId(team));
            return rows.where(_isTraining).toList(growable: false);
          },
          title: _eventTitle,
          subtitle: _eventSubtitle,
        );
      case 'calendar':
        return _loadTeamCollection(
          kind: WorkspaceFinderNodeKind.calendar,
          moduleKey: 'calendar',
          loader: (team) => _entity.loadTeamEvents(_teamId(team)),
          title: _eventTitle,
          subtitle: _eventSubtitle,
        );
      case 'plans':
        return _loadTeamCollection(
          kind: WorkspaceFinderNodeKind.plan,
          moduleKey: 'plans',
          loader: (team) => _entity.loadTeamPlans(teamId: _teamId(team), clubId: clubId),
          title: _planTitle,
          subtitle: _planSubtitle,
        );
      case 'testing':
        return _loadTeamCollection(
          kind: WorkspaceFinderNodeKind.testing,
          moduleKey: 'testing',
          loader: (team) => _entity.loadTeamTesting(teamId: _teamId(team), clubId: clubId),
          title: _testingTitle,
          subtitle: _testingSubtitle,
        );
      case 'medical':
        return _loadPlayerMedical(documentsOnly: false);
      case 'documents':
        return _loadDocuments();
      case 'reports':
        return _reportLinks();
      case 'video':
        return _videoLinks();
      case 'tracker':
        return _loadTrackerSessions();
      case 'chat':
        return _singleModuleLink('chat', 'Открыть чаты', 'Сообщения клуба и команды', WorkspaceFinderNodeKind.chat);
      case 'parents':
        return _singleModuleLink('parents', 'Родители и доступы', 'Родители, ключи доступа и уведомления', WorkspaceFinderNodeKind.parent);
      default:
        return const <WorkspaceFinderNode>[];
    }
  }

  List<Map<String, dynamic>> get _effectiveTeams {
    final selected = selectedTeamId ?? 0;
    if (selected > 0) {
      final rows = teams.where((team) => _teamId(team) == selected).toList(growable: false);
      if (rows.isNotEmpty) return rows;
      return <Map<String, dynamic>>[
        <String, dynamic>{'id': selected, 'team_id': selected, 'name': selectedTeamName},
      ];
    }
    return teams;
  }

  Future<List<WorkspaceFinderNode>> _loadTeamCollection({
    required WorkspaceFinderNodeKind kind,
    required String moduleKey,
    required Future<List<Map<String, dynamic>>> Function(Map<String, dynamic> team) loader,
    required String Function(Map<String, dynamic> row) title,
    required String Function(Map<String, dynamic> row) subtitle,
  }) async {
    final groups = await Future.wait(
      _effectiveTeams.map((team) async {
        final teamId = _teamId(team);
        if (teamId <= 0) return <WorkspaceFinderNode>[];
        final teamName = _teamName(team);
        List<Map<String, dynamic>> rows;
        try {
          rows = await loader(team);
        } catch (_) {
          rows = <Map<String, dynamic>>[];
        }
        return List<WorkspaceFinderNode>.generate(rows.length, (index) {
          final raw = Map<String, dynamic>.from(rows[index]);
          raw['team_id'] ??= teamId;
          raw['team_name'] ??= teamName;
          raw['_workspace_real_record'] = true;
          raw['_workspace_section'] = moduleKey;
          raw['_workspace_entity_type'] = _entityTypeForKind(kind);
          raw['_workspace_entity_id'] = _entityIdForKind(kind, raw, index);
          final date = _rowDate(raw);
          return WorkspaceFinderNode(
            id: 'real:$moduleKey:$teamId:${_recordId(raw, index)}',
            title: title(raw),
            subtitle: _join(<String>[subtitle(raw), if (_effectiveTeams.length > 1) teamName]),
            kind: kind,
            moduleKey: moduleKey,
            payload: raw,
            isSystem: true,
            createdAt: date,
            updatedAt: date,
          );
        });
      }),
    );
    final out = <WorkspaceFinderNode>[for (final group in groups) ...group];
    out.sort((a, b) {
      final ad = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  Future<List<WorkspaceFinderNode>> _loadPlayerMedical({required bool documentsOnly}) async {
    final groups = await Future.wait(players.map((player) async {
      try {
        final records = await _player.loadMedicalRecords(player);
        final playerName = _playerName(player);
        final playerId = _player.resolvePlayerId(player);
        final out = <WorkspaceFinderNode>[];
        for (var index = 0; index < records.length; index++) {
          final raw = Map<String, dynamic>.from(records[index]);
          final hasFile = _first(raw, const <String>['file_url', 'file', 'url']).isNotEmpty;
          final type = _first(raw, const <String>['type', 'record_type', 'document_type']).toLowerCase();
          final looksDocument = hasFile || type.contains('док') || type.contains('справ') || type.contains('document') || type.contains('file');
          if (documentsOnly && !looksDocument) continue;
          raw['_workspace_real_record'] = true;
          raw['_workspace_section'] = documentsOnly ? 'documents' : 'medical';
          raw['_workspace_entity_type'] = documentsOnly ? 'document' : 'medical_record';
          raw['_workspace_entity_id'] = _recordId(raw, index);
          raw['_workspace_owner'] = playerName;
          raw['_workspace_player'] = Map<String, dynamic>.from(player);
          final date = _rowDate(raw);
          out.add(
            WorkspaceFinderNode(
              id: 'real:${documentsOnly ? 'documents' : 'medical'}:player:$playerId:${_recordId(raw, index)}',
              title: _first(raw, const <String>['title', 'name', 'file_name'], fallback: documentsOnly ? 'Документ' : 'Запись медкарты'),
              subtitle: _join(<String>[
                playerName,
                _first(raw, const <String>['type', 'record_type', 'document_type']),
                _friendlyDate(date),
              ]),
              kind: documentsOnly ? WorkspaceFinderNodeKind.document : WorkspaceFinderNodeKind.medical,
              moduleKey: documentsOnly ? 'players' : 'medical',
              payload: raw,
              isSystem: true,
              createdAt: date,
              updatedAt: date,
            ),
          );
        }
        return out;
      } catch (_) {
        return <WorkspaceFinderNode>[];
      }
    }));
    return <WorkspaceFinderNode>[for (final group in groups) ...group]
      ..sort((a, b) => (b.updatedAt ?? DateTime(1970)).compareTo(a.updatedAt ?? DateTime(1970)));
  }

  Future<List<WorkspaceFinderNode>> _loadDocuments() async {
    final playerDocsFuture = _loadPlayerMedical(documentsOnly: true);
    final trainerDocsFuture = Future.wait(trainers.map((trainer) async {
      final trainerId = _entity.trainerId(trainer);
      if (trainerId <= 0) return <WorkspaceFinderNode>[];
      try {
        final rows = await _entity.loadTrainerDocuments(trainerId: trainerId, clubId: clubId);
        final trainerName = _trainerName(trainer);
        return List<WorkspaceFinderNode>.generate(rows.length, (index) {
          final raw = Map<String, dynamic>.from(rows[index]);
          raw['_workspace_real_record'] = true;
          raw['_workspace_section'] = 'documents';
          raw['_workspace_entity_type'] = 'document';
          raw['_workspace_entity_id'] = _recordId(raw, index);
          raw['_workspace_owner'] = trainerName;
          raw['_workspace_trainer'] = Map<String, dynamic>.from(trainer);
          final date = _rowDate(raw);
          return WorkspaceFinderNode(
            id: 'real:documents:trainer:$trainerId:${_recordId(raw, index)}',
            title: _first(raw, const <String>['title', 'name', 'document_type', 'file_name'], fallback: 'Документ тренера'),
            subtitle: _join(<String>[trainerName, _first(raw, const <String>['document_type', 'type']), _friendlyDate(date)]),
            kind: WorkspaceFinderNodeKind.document,
            moduleKey: 'trainers',
            payload: raw,
            isSystem: true,
            createdAt: date,
            updatedAt: date,
          );
        });
      } catch (_) {
        return <WorkspaceFinderNode>[];
      }
    }));

    final playerDocs = await playerDocsFuture;
    final trainerGroups = await trainerDocsFuture;
    final out = <WorkspaceFinderNode>[
      ...playerDocs,
      for (final group in trainerGroups) ...group,
    ];
    out.sort((a, b) => (b.updatedAt ?? DateTime(1970)).compareTo(a.updatedAt ?? DateTime(1970)));
    return out;
  }

  List<WorkspaceFinderNode> _reportLinks() => <WorkspaceFinderNode>[
        _link('reports', 'tracker', 'Tracker отчёты', 'GPS, ЧСС, нагрузка и карты', WorkspaceFinderNodeKind.report, 'tracker'),
        _link('reports', 'testing', 'Отчёты тестирования', 'Динамика и результаты тестов', WorkspaceFinderNodeKind.report, 'testing'),
        _link('reports', 'attendance', 'Посещаемость', 'Журнал и выгрузка', WorkspaceFinderNodeKind.report, 'attendance'),
      ];

  List<WorkspaceFinderNode> _videoLinks() => <WorkspaceFinderNode>[
        _link('video', 'analysis', 'Видеоанализ матчей', 'Разбор, эпизоды и AI', WorkspaceFinderNodeKind.video, 'videoAnalysis'),
        _link('video', 'lessons', 'Видеоуроки', 'Методическая видеотека клуба', WorkspaceFinderNodeKind.video, 'videoLessons'),
      ];

  Future<List<WorkspaceFinderNode>> _loadTrackerSessions() async {
    final groups = await Future.wait(_effectiveTeams.map((team) async {
      final teamId = _teamId(team);
      if (teamId <= 0) return <WorkspaceFinderNode>[];
      try {
        final uri = Uri.parse(
          'https://sportotekaapp.ru/api/tracker/get_tracker_sessions.php',
        ).replace(queryParameters: <String, String>{
          'team_id': '$teamId',
          'limit': '120',
          'include_personal': '1',
          'include_player_sessions': '1',
        });
        final response = await http.get(uri).timeout(const Duration(seconds: 18));
        final decoded = jsonDecode(response.body);
        dynamic raw = decoded;
        if (decoded is Map) {
          raw = decoded['sessions'] ?? decoded['items'] ?? decoded['data'] ?? decoded['rows'] ?? const [];
        }
        final rows = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        final teamName = _teamName(team);
        return List<WorkspaceFinderNode>.generate(rows.length, (index) {
          final record = rows[index];
          record['team_id'] ??= teamId;
          record['team_name'] ??= teamName;
          record['_workspace_real_record'] = true;
          record['_workspace_section'] = 'tracker';
          record['_workspace_entity_type'] = 'tracker';
          record['_workspace_entity_id'] = _entityIdForKind(WorkspaceFinderNodeKind.tracker, record, index);
          final date = _rowDate(record);
          final playerName = _first(record, const <String>['player_name', 'athlete_name', 'name']);
          final sessionTitle = _first(record, const <String>['title', 'session_title']);
          final distance = _double(record['distance_m'] ?? record['total_distance_m']);
          final maxSpeed = _double(record['max_speed_kmh']);
          return WorkspaceFinderNode(
            id: 'real:tracker:$teamId:${_recordId(record, index)}',
            title: sessionTitle.isNotEmpty
                ? sessionTitle
                : (playerName.isNotEmpty ? 'Сессия · $playerName' : 'Tracker сессия'),
            subtitle: _join(<String>[
              _friendlyDate(date),
              if (distance > 0) '${distance.round()} м',
              if (maxSpeed > 0) '${maxSpeed.toStringAsFixed(1)} км/ч',
              if (_effectiveTeams.length > 1) teamName,
            ]),
            kind: WorkspaceFinderNodeKind.tracker,
            moduleKey: 'tracker',
            payload: record,
            isSystem: true,
            createdAt: date,
            updatedAt: date,
          );
        });
      } catch (_) {
        return <WorkspaceFinderNode>[];
      }
    }));
    final out = <WorkspaceFinderNode>[
      for (final group in groups) ...group,
    ];
    out.sort((a, b) =>
        (b.updatedAt ?? DateTime(1970)).compareTo(a.updatedAt ?? DateTime(1970)));
    return out;
  }

  List<WorkspaceFinderNode> _singleModuleLink(String key, String title, String subtitle, WorkspaceFinderNodeKind kind) =>
      <WorkspaceFinderNode>[_link(key, 'open', title, subtitle, kind, key)];

  WorkspaceFinderNode _link(
    String parent,
    String id,
    String title,
    String subtitle,
    WorkspaceFinderNodeKind kind,
    String moduleKey,
  ) {
    return WorkspaceFinderNode(
      id: 'smart:$parent:$id',
      title: title,
      subtitle: subtitle,
      kind: kind,
      moduleKey: moduleKey,
      isSystem: true,
    );
  }

  String _matchTitle(Map<String, dynamic> row) {
    final opponent = _first(row, const <String>['opponent', 'opponent_name', 'rival', 'away_team', 'title']);
    return opponent.isEmpty ? 'Матч' : 'Матч · $opponent';
  }

  String _matchSubtitle(Map<String, dynamic> row) {
    final score = _first(row, const <String>['score', 'result', 'final_score']);
    return _join(<String>[_friendlyDate(_rowDate(row)), score]);
  }

  String _eventTitle(Map<String, dynamic> row) =>
      _first(row, const <String>['title', 'name', 'event_title', 'training_title'], fallback: _isTraining(row) ? 'Тренировка' : 'Событие');

  String _eventSubtitle(Map<String, dynamic> row) => _join(<String>[
        _friendlyDate(_rowDate(row)),
        _first(row, const <String>['location', 'venue', 'place']),
        _first(row, const <String>['type', 'event_type']),
      ]);

  String _planTitle(Map<String, dynamic> row) =>
      _first(row, const <String>['title', 'name', 'plan_title', 'topic'], fallback: 'План-конспект');

  String _planSubtitle(Map<String, dynamic> row) => _join(<String>[
        _friendlyDate(_rowDate(row)),
        _first(row, const <String>['trainer_name', 'coach_name', 'author_name']),
      ]);

  String _testingTitle(Map<String, dynamic> row) =>
      _first(row, const <String>['title', 'name', 'test_name', 'category'], fallback: 'Тестирование');

  String _testingSubtitle(Map<String, dynamic> row) => _join(<String>[
        _friendlyDate(_rowDate(row)),
        _first(row, const <String>['category', 'stage', 'type']),
      ]);

  bool _isTraining(Map<String, dynamic> row) {
    final type = _first(row, const <String>['type', 'event_type', 'kind', 'category']).toLowerCase();
    if (type.contains('training') || type.contains('трен')) return true;
    final title = _eventTitleRaw(row).toLowerCase();
    return title.contains('трениров');
  }

  String _eventTitleRaw(Map<String, dynamic> row) =>
      _first(row, const <String>['title', 'name', 'event_title', 'training_title']);

  int _teamId(Map<String, dynamic> team) => _entity.teamId(team);
  String _teamName(Map<String, dynamic> team) => _entity.teamName(team);

  String _playerName(Map<String, dynamic> player) {
    final last = _first(player, const <String>['last_name', 'lastname', 'surname']);
    final first = _first(player, const <String>['first_name', 'firstname', 'firstName']);
    final full = _first(player, const <String>['full_name', 'fullName', 'name']);
    final joined = _join(<String>[last, first], separator: ' ');
    return joined.isNotEmpty ? joined : (full.isNotEmpty ? full : 'Игрок');
  }

  String _trainerName(Map<String, dynamic> trainer) {
    final last = _first(trainer, const <String>['last_name', 'lastname', 'surname']);
    final first = _first(trainer, const <String>['first_name', 'firstname', 'firstName']);
    final full = _first(trainer, const <String>['full_name', 'fullName', 'name']);
    final joined = _join(<String>[last, first], separator: ' ');
    return joined.isNotEmpty ? joined : (full.isNotEmpty ? full : 'Тренер');
  }

  String _entityTypeForKind(WorkspaceFinderNodeKind kind) {
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
      case WorkspaceFinderNodeKind.document:
        return 'document';
      case WorkspaceFinderNodeKind.medical:
        return 'medical_record';
      case WorkspaceFinderNodeKind.video:
        return 'video';
      default:
        return kind.name;
    }
  }

  String _entityIdForKind(WorkspaceFinderNodeKind kind, Map<String, dynamic> row, int index) {
    List<String> keys;
    switch (kind) {
      case WorkspaceFinderNodeKind.match:
        keys = const <String>['match_id', 'id'];
        break;
      case WorkspaceFinderNodeKind.training:
      case WorkspaceFinderNodeKind.calendar:
        keys = const <String>['event_id', 'training_id', 'calendar_event_id', 'id'];
        break;
      case WorkspaceFinderNodeKind.plan:
        keys = const <String>['plan_id', 'id'];
        break;
      case WorkspaceFinderNodeKind.testing:
        keys = const <String>['test_id', 'testing_id', 'session_id', 'id'];
        break;
      case WorkspaceFinderNodeKind.tracker:
        keys = const <String>['tracker_session_id', 'session_id', 'id'];
        break;
      case WorkspaceFinderNodeKind.document:
      case WorkspaceFinderNodeKind.medical:
        keys = const <String>['record_id', 'document_id', 'id'];
        break;
      default:
        keys = const <String>['id'];
        break;
    }
    final id = _first(row, keys);
    return id.isNotEmpty ? id : _recordId(row, index);
  }

  String _recordId(Map<String, dynamic> row, int index) {
    final id = _first(row, const <String>['id', 'match_id', 'event_id', 'plan_id', 'session_id', 'record_id', 'document_id']);
    if (id.isNotEmpty) return id;
    final date = _first(row, const <String>['date', 'match_date', 'start_at', 'event_date', 'test_date', 'created_at']);
    return '${date.hashCode.abs()}:$index';
  }

  DateTime? _rowDate(Map<String, dynamic> row) {
    final raw = _first(row, const <String>[
      'start_at',
      'event_date',
      'training_date',
      'match_date',
      'test_date',
      'plan_date',
      'record_date',
      'date',
      'updated_at',
      'created_at',
    ]);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  String _friendlyDate(DateTime? date) {
    if (date == null) return '';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m.${date.year}';
  }

  String _first(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = '${map[key] ?? ''}'.trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return fallback;
  }

  double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0;

  String _join(List<String> values, {String separator = ' · '}) =>
      values.map((e) => e.trim()).where((e) => e.isNotEmpty).join(separator);
}
