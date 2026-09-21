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
    this.currentUserId = 0,
    required this.teams,
    required this.players,
    required this.trainers,
    this.selectedTeamId,
    this.selectedTeamName = '',
  });

  final int clubId;
  final int currentUserId;
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
        return loadPlanLibraryFolder();
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

  /// Shared Plans / Training Graphics tree used by Workspace OS.
  ///
  /// `folderId == null` means the root of the plan library. The folders are
  /// loaded from the very same list_plan_folders.php endpoint as the ordinary
  /// Plans module and the scheme picker, so U6/U7/U8 never become copied
  /// Workspace-only folders.
  Future<List<WorkspaceFinderNode>> loadPlanLibraryFolder({int? folderId}) async {
    final currentFolderId = folderId ?? 0;
    final folderTree = await _loadPlanFolderTree();
    final directFolders = _directPlanFolders(folderTree, currentFolderId);

    final folderNodes = directFolders.map((folder) {
      final id = _int(folder['id']);
      final title = _first(folder, const <String>['title', 'name'], fallback: 'Папка');
      final count = _int(folder['plans_count'] ?? folder['plan_count'] ?? folder['items_count']);
      final schemes = _int(folder['graphics_count'] ?? folder['schemes_count']);
      final parts = <String>[
        if (count > 0) '$count план${count == 1 ? '' : 'ов'}',
        if (schemes > 0) '$schemes схем',
      ];
      final payload = Map<String, dynamic>.from(folder)
        ..['_workspace_plan_folder'] = true
        ..['_workspace_plan_folder_id'] = id;
      return WorkspaceFinderNode(
        id: 'plan-folder:$id',
        title: title,
        subtitle: parts.isEmpty ? 'Планы-конспекты и схемы' : parts.join(' · '),
        kind: WorkspaceFinderNodeKind.folder,
        payload: payload,
        isSystem: true,
      );
    }).toList(growable: true);

    final planNodes = await _loadTeamCollection(
      kind: WorkspaceFinderNodeKind.plan,
      moduleKey: 'plans',
      loader: (team) => _entity.loadTeamPlans(teamId: _teamId(team), clubId: clubId),
      title: _planTitle,
      subtitle: _planSubtitle,
    );
    final plansHere = planNodes.where((node) {
      final raw = node.payload ?? const <String, dynamic>{};
      return _int(raw['folder_id'] ?? raw['folderId']) == currentFolderId;
    }).toList(growable: true);

    final graphicsHere = await _loadTrainingGraphicsForFolder(currentFolderId);

    return <WorkspaceFinderNode>[
      ...folderNodes,
      ...plansHere,
      ...graphicsHere,
    ];
  }

  Future<List<dynamic>> _loadPlanFolderTree() async {
    if (clubId <= 0) return <dynamic>[];
    try {
      final response = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/list_plan_folders.php'),
        headers: const <String, String>{'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(<String, dynamic>{'club_id': clubId}),
      ).timeout(const Duration(seconds: 12));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['success'] != true) return <dynamic>[];
      final raw = decoded['tree'] ?? decoded['folders'] ?? decoded['items'] ?? decoded['data'];
      return raw is List ? List<dynamic>.from(raw) : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  List<Map<String, dynamic>> _directPlanFolders(List<dynamic> tree, int parentId) {
    final out = <Map<String, dynamic>>[];
    void walk(List<dynamic> nodes) {
      for (final item in nodes) {
        if (item is! Map) continue;
        final folder = Map<String, dynamic>.from(item);
        if (_int(folder['parent_id']) == parentId) out.add(folder);
        final children = folder['children'];
        if (children is List && children.isNotEmpty) walk(children);
      }
    }
    walk(tree);
    return out;
  }

  Future<List<WorkspaceFinderNode>> _loadTrainingGraphicsForFolder(int folderId) async {
    final groups = await Future.wait(_effectiveTeams.map((team) async {
      final teamId = _teamId(team);
      if (teamId <= 0) return <WorkspaceFinderNode>[];
      try {
        final response = await http.post(
          Uri.parse('https://sportotekaapp.ru/api/list_training_graphics.php'),
          headers: const <String, String>{'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(<String, dynamic>{
            'club_id': clubId,
            'clubId': clubId,
            'team_id': teamId,
            'teamId': teamId,
            'folder_id': folderId,
            'folderId': folderId,
          }),
        ).timeout(const Duration(seconds: 12));
        final decoded = jsonDecode(response.body);
        if (decoded is! Map || decoded['success'] != true) return <WorkspaceFinderNode>[];
        final rawItems = decoded['items'] ?? decoded['graphics'] ?? decoded['data'];
        if (rawItems is! List) return <WorkspaceFinderNode>[];
        final teamName = _teamName(team);
        final out = <WorkspaceFinderNode>[];
        for (var index = 0; index < rawItems.length; index++) {
          final item = rawItems[index];
          if (item is! Map) continue;
          final raw = Map<String, dynamic>.from(item);
          raw['team_id'] ??= teamId;
          raw['team_name'] ??= teamName;
          raw['_workspace_training_graphic'] = true;
          raw['_workspace_plan_folder_id'] = folderId;
          final id = _int(raw['id'] ?? raw['graphic_id']);
          final date = _rowDate(raw);
          out.add(WorkspaceFinderNode(
            id: 'training-graphic:$teamId:${id > 0 ? id : index}',
            title: _first(raw, const <String>['title', 'name'], fallback: 'Тактическая схема'),
            subtitle: _join(<String>['Схема', if (_effectiveTeams.length > 1) teamName, _friendlyDate(date)]),
            kind: WorkspaceFinderNodeKind.plan,
            payload: raw,
            isSystem: true,
            createdAt: date,
            updatedAt: date,
          ));
        }
        return out;
      } catch (_) {
        return <WorkspaceFinderNode>[];
      }
    }));
    return <WorkspaceFinderNode>[for (final group in groups) ...group];
  }

  int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('${value ?? ''}'.trim()) ?? 0;

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
