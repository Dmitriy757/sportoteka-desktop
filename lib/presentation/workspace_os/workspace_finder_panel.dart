import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_document_editor.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_player_project_screen.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_team_project_screen.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_trainer_project_screen.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_server_storage.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_entity_move_bridge.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_entity_records.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_entity_identity.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_root_data_bridge.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_live_blocks.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_window_manager.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_video_center.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SportotekaWorkspaceFinderPanel extends StatefulWidget {
  const SportotekaWorkspaceFinderPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teams,
    required this.players,
    required this.trainers,
    required this.onOpenModule,
    required this.onOpenPlayer,
    required this.onOpenTeam,
    required this.onOpenTrainer,
    this.selectedTeamId,
    this.selectedTeamName = '',
    this.onRefresh,
    this.onMoveEntity,
    this.currentUserId = 0,
  });

  final int clubId;
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> trainers;
  final int? selectedTeamId;
  final String selectedTeamName;
  final ValueChanged<String> onOpenModule;
  final ValueChanged<Map<String, dynamic>> onOpenPlayer;
  final ValueChanged<Map<String, dynamic>> onOpenTeam;
  final ValueChanged<Map<String, dynamic>> onOpenTrainer;
  final Future<void> Function()? onRefresh;
  final int currentUserId;
  final Future<bool> Function(
    WorkspaceFinderNode source,
    WorkspaceFinderNode target,
  )? onMoveEntity;

  @override
  State<SportotekaWorkspaceFinderPanel> createState() =>
      _SportotekaWorkspaceFinderPanelState();
}

class _SportotekaWorkspaceFinderPanelState
    extends State<SportotekaWorkspaceFinderPanel> {
  static const _green = Color(0xFF0B8F55);
  static const _bg = Colors.white;
  static const _line = Color(0xFFE5E8E5);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);

  WorkspaceFinderViewMode _viewMode = WorkspaceFinderViewMode.list;
  String _folderKey = 'home';
  String _search = '';
  String? _selectedNodeId;
  WorkspaceFinderNode? _clipboardNode;
  bool _showSidebarOnCompact = false;
  late final WorkspaceServerStorage _serverStorage;
  bool _serverAvailable = false;
  bool _serverLoading = false;
  final WorkspaceEntityMoveBridge _entityMoveBridge = const WorkspaceEntityMoveBridge();
  final Map<String, List<WorkspaceFinderNode>> _realFolderNodes = <String, List<WorkspaceFinderNode>>{};
  final Set<String> _realFolderLoading = <String>{};
  final Map<String, String> _realFolderErrors = <String, String>{};

  final List<String> _recentIds = <String>[];
  final Set<String> _favoriteIds = <String>{};
  final Map<String, List<WorkspaceFinderNode>> _localChildren =
      <String, List<WorkspaceFinderNode>>{};
  final Map<String, String> _noteBodies = <String, String>{};
  final Set<String> _pendingSyncIds = <String>{};
  final List<WorkspaceWindowEntry> _windows = <WorkspaceWindowEntry>[];
  String? _activeWindowId;
  int _windowCascade = 0;

  static const Set<String> _projectedFolders = <String>{
    'matches',
    'trainings',
    'plans',
    'testing',
    'calendar',
    'documents',
    'medical',
    'tracker',
    'video',
    'reports',
    'chat',
    'parents',
  };

  static const Set<String> _listFolders = <String>{
    'teams',
    'players',
    'trainers',
    'matches',
    'trainings',
    'plans',
    'testing',
    'calendar',
    'documents',
    'medical',
    'tracker',
    'video',
    'reports',
    'chat',
    'parents',
    'recent',
    'favorites',
  };

  bool get _canCreateWorkspaceNode =>
      _folderKey == 'home' || _folderKey.startsWith('local-folder:');

  WorkspaceRootDataBridge get _rootDataBridge => WorkspaceRootDataBridge(
        clubId: widget.clubId,
        currentUserId: widget.currentUserId,
        teams: widget.teams,
        players: widget.players,
        trainers: widget.trainers,
        selectedTeamId: widget.selectedTeamId,
        selectedTeamName: widget.selectedTeamName,
      );

  String get _storageKey => 'sportoteka_finder_v1_${widget.clubId}';

  void _wsLog(String message) {
    debugPrint(
      '[WORKSPACE_SYNC][FINDER] club=${widget.clubId} user=${widget.currentUserId} '
      'folder=$_folderKey pending=${_pendingSyncIds.length} $message',
    );
  }

  @override
  void initState() {
    super.initState();
    _serverStorage = WorkspaceServerStorage(clubId: widget.clubId, userId: widget.currentUserId);
    _wsLog('INIT api=${_serverStorage.apiUrl}');
    if (widget.currentUserId <= 0) {
      _wsLog('WARNING currentUserId <= 0: server access may fail');
    }
    _loadWorkspace();
  }

  @override
  void didUpdateWidget(covariant SportotekaWorkspaceFinderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final teamChanged = oldWidget.selectedTeamId != widget.selectedTeamId ||
        oldWidget.selectedTeamName != widget.selectedTeamName;
    final dataChanged = oldWidget.teams.length != widget.teams.length ||
        oldWidget.players.length != widget.players.length ||
        oldWidget.trainers.length != widget.trainers.length;
    if (teamChanged || dataChanged) {
      _realFolderNodes.clear();
      _realFolderErrors.clear();
      if (_projectedFolders.contains(_folderKey)) {
        _loadRealFolder(_folderKey, force: true);
      }
    }
  }

  Future<void> _loadRealFolder(String key, {bool force = false}) async {
    if (!_projectedFolders.contains(key)) return;
    if (!force && (_realFolderNodes.containsKey(key) || _realFolderLoading.contains(key))) return;
    if (mounted) {
      setState(() {
        _realFolderLoading.add(key);
        _realFolderErrors.remove(key);
      });
    }
    try {
      final rows = await _rootDataBridge.loadFolder(key);
      if (!mounted) return;
      setState(() {
        _realFolderNodes[key] = rows;
        _realFolderLoading.remove(key);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _realFolderNodes[key] = const <WorkspaceFinderNode>[];
        _realFolderLoading.remove(key);
        _realFolderErrors[key] = '$e';
      });
    }
  }

  Future<void> _enterFolder(String key, {bool closeCompactSidebar = false}) async {
    if (!mounted) return;
    setState(() {
      _folderKey = key;
      _search = '';
      _selectedNodeId = null;
      if (closeCompactSidebar) _showSidebarOnCompact = false;
    });
    await _loadRealFolder(key);
  }

  Future<void> _loadWorkspace() async {
    _wsLog('LOAD_WORKSPACE begin');
    await _loadLocalWorkspace();
    _wsLog('LOAD_WORKSPACE local loaded nodes=${_localChildren.values.fold<int>(0, (sum, list) => sum + list.length)} notes=${_noteBodies.length} pending=${_pendingSyncIds.toList()}');
    await _loadServerWorkspace();
    _wsLog('LOAD_WORKSPACE end serverAvailable=$_serverAvailable pending=${_pendingSyncIds.toList()}');
  }

  Future<void> _loadServerWorkspace() async {
    if (_serverLoading) return;
    _serverLoading = true;
    _wsLog('SERVER_LOAD begin pending=${_pendingSyncIds.toList()}');
    try {
      var snapshot = await _serverStorage.load();
      _wsLog('SERVER_LOAD bootstrap OK nodes=${snapshot.nodes.length} docs=${snapshot.noteBodies.length}');
      final localNodes = <WorkspaceFinderNode>[
        for (final list in _localChildren.values) ...list,
      ];
      final localById = <String, WorkspaceFinderNode>{for (final node in localNodes) node.id: node};
      final serverById = <String, WorkspaceFinderNode>{for (final node in snapshot.nodes) node.id: node};
      final retryIds = <String>{..._pendingSyncIds};

      // New local nodes that never reached the server are always retried.
      for (final node in localNodes) {
        final wasServerMirror = node.payload?['_workspace_server'] == true;
        if (!serverById.containsKey(node.id) && (!wasServerMirror || _pendingSyncIds.contains(node.id))) {
          retryIds.add(node.id);
        }
      }

      // Migration for documents created by older app versions: if the same ID
      // exists on the server but the local body is newer, do not let bootstrap
      // overwrite it. Mark it as pending and push it first.
      for (final node in localNodes.where((n) => n.kind == WorkspaceFinderNodeKind.note)) {
        final serverNode = serverById[node.id];
        if (serverNode == null) continue;
        final localBody = _noteBodies[node.id] ?? '';
        final serverBody = snapshot.noteBodies[node.id] ?? '';
        if (localBody == serverBody) continue;
        final localUpdated = node.updatedAt;
        final serverUpdated = serverNode.updatedAt;
        final localLooksNewer = localUpdated != null &&
            (serverUpdated == null || !localUpdated.isBefore(serverUpdated.subtract(const Duration(seconds: 5))));
        if (localLooksNewer) retryIds.add(node.id);
      }

      var changedServer = false;
      for (final id in retryIds.toList()) {
        final node = localById[id];
        if (node == null) {
          _pendingSyncIds.remove(id);
          continue;
        }
        _wsLog('SERVER_RETRY uid=$id kind=${node.kind.name} bodyLen=${(_noteBodies[id] ?? '').length} existsOnServer=${serverById.containsKey(id)}');
        try {
          if (node.kind == WorkspaceFinderNodeKind.note) {
            await _serverStorage.syncNodeDocument(
              node: node,
              body: _noteBodies[id] ?? '',
              createHint: !serverById.containsKey(id),
            );
          } else if (serverById.containsKey(id)) {
            try {
              await _serverStorage.updateNode(node);
            } catch (_) {
              await _serverStorage.createNode(node);
            }
          } else {
            try {
              await _serverStorage.createNode(node);
            } catch (_) {
              await _serverStorage.updateNode(node);
            }
          }
          _pendingSyncIds.remove(id);
          changedServer = true;
          _wsLog('SERVER_RETRY OK uid=$id');
        } catch (e, st) {
          _pendingSyncIds.add(id);
          _wsLog('SERVER_RETRY FAILED uid=$id error=$e');
          _wsLog('SERVER_RETRY stack=${st.toString().split('\n').take(4).join(' | ')}');
        }
      }

      if (changedServer) snapshot = await _serverStorage.load();

      final grouped = <String, List<WorkspaceFinderNode>>{};
      for (final node in snapshot.nodes) {
        (grouped[node.parentId ?? 'home'] ??= <WorkspaceFinderNode>[]).add(node);
      }
      final mergedNotes = <String, String>{...snapshot.noteBodies};

      // Pending local edits stay visible and cannot be replaced by an older
      // server copy. They will be retried on the next refresh/save.
      for (final id in _pendingSyncIds) {
        final local = localById[id];
        if (local == null) continue;
        for (final list in grouped.values) {
          list.removeWhere((item) => item.id == id);
        }
        (grouped[local.parentId ?? 'home'] ??= <WorkspaceFinderNode>[]).add(local);
        if (local.kind == WorkspaceFinderNodeKind.note) {
          mergedNotes[id] = _noteBodies[id] ?? '';
        }
      }

      if (!mounted) return;
      setState(() {
        _serverAvailable = true;
        _localChildren
          ..clear()
          ..addAll(grouped);
        _noteBodies
          ..clear()
          ..addAll(mergedNotes);
        if (snapshot.favorites.isNotEmpty) {
          _favoriteIds
            ..clear()
            ..addAll(snapshot.favorites);
        }
        if (snapshot.recent.isNotEmpty) {
          _recentIds
            ..clear()
            ..addAll(snapshot.recent);
        }
      });
      await _persistLocalWorkspace();
    } catch (e, st) {
      _serverAvailable = false;
      _wsLog('SERVER_LOAD FAILED error=$e');
      _wsLog('SERVER_LOAD stack=${st.toString().split('\n').take(5).join(' | ')}');
      // Keep the local cache and pending queue intact. No local document is
      // replaced when the server is unavailable.
    } finally {
      _serverLoading = false;
    }
  }

  Future<void> _loadLocalWorkspace() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final foldersRaw = decoded['localChildren'];
      final loadedChildren = <String, List<WorkspaceFinderNode>>{};
      if (foldersRaw is Map) {
        for (final entry in foldersRaw.entries) {
          final value = entry.value;
          if (value is! List) continue;
          loadedChildren['${entry.key}'] = value
              .whereType<Map>()
              .map((item) => _nodeFromJson(Map<String, dynamic>.from(item)))
              .whereType<WorkspaceFinderNode>()
              .toList();
        }
      }

      final notesRaw = decoded['noteBodies'];
      final loadedNotes = <String, String>{};
      if (notesRaw is Map) {
        for (final entry in notesRaw.entries) {
          loadedNotes['${entry.key}'] = '${entry.value ?? ''}';
        }
      }

      final favoriteRaw = decoded['favorites'];
      final recentRaw = decoded['recent'];
      final pendingRaw = decoded['pendingSyncIds'];
      final viewRaw = '${decoded['viewMode'] ?? ''}';
      if (!mounted) return;
      setState(() {
        _localChildren
          ..clear()
          ..addAll(loadedChildren);
        _noteBodies
          ..clear()
          ..addAll(loadedNotes);
        _favoriteIds
          ..clear()
          ..addAll(favoriteRaw is List ? favoriteRaw.map((e) => '$e') : const <String>[]);
        _recentIds
          ..clear()
          ..addAll(recentRaw is List ? recentRaw.map((e) => '$e') : const <String>[]);
        _pendingSyncIds
          ..clear()
          ..addAll(pendingRaw is List ? pendingRaw.map((e) => '$e') : const <String>[]);
        _viewMode = WorkspaceFinderViewMode.list;
      });
    } catch (_) {
      // Повреждённое локальное состояние не должно ломать Спортотека OS.
    }
  }

  Map<String, dynamic> _nodeToJson(WorkspaceFinderNode node) => <String, dynamic>{
        'id': node.id,
        'title': node.title,
        'subtitle': node.subtitle,
        'kind': node.kind.name,
        'moduleKey': node.moduleKey,
        'payload': node.payload,
        'parentId': node.parentId,
        'isSystem': node.isSystem,
        'isFavorite': node.isFavorite,
        'isShortcut': node.isShortcut,
        'createdAt': node.createdAt?.toIso8601String(),
        'updatedAt': node.updatedAt?.toIso8601String(),
      };

  WorkspaceFinderNode? _nodeFromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}'.trim();
    final title = '${json['title'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty) return null;
    final kindName = '${json['kind'] ?? ''}';
    final kind = WorkspaceFinderNodeKind.values.firstWhere(
      (item) => item.name == kindName,
      orElse: () => WorkspaceFinderNodeKind.shortcut,
    );
    final payloadRaw = json['payload'];
    return WorkspaceFinderNode(
      id: id,
      title: title,
      subtitle: '${json['subtitle'] ?? ''}',
      kind: kind,
      moduleKey: json['moduleKey'] == null ? null : '${json['moduleKey']}',
      payload: payloadRaw is Map ? Map<String, dynamic>.from(payloadRaw) : null,
      parentId: json['parentId'] == null ? null : '${json['parentId']}',
      isSystem: json['isSystem'] == true,
      isFavorite: json['isFavorite'] == true,
      isShortcut: json['isShortcut'] == true,
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
    );
  }

  Future<void> _persistLocalWorkspace() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'localChildren': <String, dynamic>{
          for (final entry in _localChildren.entries)
            entry.key: entry.value.map(_nodeToJson).toList(),
        },
        'noteBodies': _noteBodies,
        'favorites': _favoriteIds.toList(),
        'recent': _recentIds,
        'pendingSyncIds': _pendingSyncIds.toList(),
        'viewMode': _viewMode.name,
      };
      await prefs.setString(_storageKey, jsonEncode(data));
      if (_serverAvailable) {
        try {
          await _serverStorage.saveState(favorites: _favoriteIds, recent: _recentIds);
        } catch (_) {
          _serverAvailable = false;
        }
      }
    } catch (_) {
      // Локальное сохранение не должно блокировать основные данные клуба.
    }
  }

  Future<void> _serverCreateNode(WorkspaceFinderNode node) async {
    try {
      await _serverStorage.createNode(node);
      _serverAvailable = true;
    } catch (_) {
      _serverAvailable = false;
    }
  }

  Future<void> _serverUpdateNode(WorkspaceFinderNode node) async {
    try {
      await _serverStorage.updateNode(node);
      _serverAvailable = true;
    } catch (_) {
      _serverAvailable = false;
    }
  }

  Future<void> _serverDeleteNode(String id) async {
    try {
      await _serverStorage.deleteNode(id);
      _serverAvailable = true;
    } catch (_) {
      _serverAvailable = false;
    }
  }

  String _nodeId(String prefix, Map<String, dynamic> payload, int index) {
    final raw = payload['id'] ??
        payload['player_id'] ??
        payload['trainer_id'] ??
        payload['team_id'] ??
        payload['user_id'] ??
        payload['email'] ??
        payload['name'] ??
        index;
    return '$prefix:$raw';
  }

  String _teamTitle(Map<String, dynamic> team) {
    return '${team['name'] ?? team['team_name'] ?? team['title'] ?? 'Команда'}'
        .trim();
  }

  String _playerTitle(Map<String, dynamic> player) {
    final last = '${player['last_name'] ?? player['lastname'] ?? ''}'.trim();
    final first = '${player['first_name'] ?? player['firstname'] ?? ''}'.trim();
    final full = '${player['full_name'] ?? player['fullName'] ?? player['name'] ?? ''}'
        .trim();
    final joined = [last, first].where((e) => e.isNotEmpty).join(' ').trim();
    return joined.isNotEmpty ? joined : (full.isNotEmpty ? full : 'Игрок');
  }

  String _trainerTitle(Map<String, dynamic> trainer) {
    final last = '${trainer['last_name'] ?? trainer['lastname'] ?? ''}'.trim();
    final first = '${trainer['first_name'] ?? trainer['firstname'] ?? ''}'.trim();
    final full = '${trainer['full_name'] ?? trainer['fullName'] ?? trainer['name'] ?? ''}'
        .trim();
    final joined = [last, first].where((e) => e.isNotEmpty).join(' ').trim();
    return joined.isNotEmpty ? joined : (full.isNotEmpty ? full : 'Тренер');
  }

  List<WorkspaceFinderNode> get _rootNodes {
    return kWorkspaceFinderModules
        .map(
          (module) => WorkspaceFinderNode(
            id: 'module:${module.key}',
            title: module.title,
            subtitle: module.subtitle,
            kind: WorkspaceFinderNodeKind.folder,
            moduleKey: module.key,
            isSystem: true,
          ),
        )
        .toList(growable: false);
  }

  List<WorkspaceFinderNode> _teamNodes() {
    return List<WorkspaceFinderNode>.generate(widget.teams.length, (index) {
      final team = widget.teams[index];
      final title = _teamTitle(team);
      final stage = '${team['age_group'] ?? team['stage'] ?? team['category'] ?? ''}'
          .trim();
      return WorkspaceFinderNode(
        id: _nodeId('team', team, index),
        title: title,
        subtitle: stage.isEmpty ? 'Команда клуба' : stage,
        kind: WorkspaceFinderNodeKind.team,
        moduleKey: 'teams',
        payload: Map<String, dynamic>.from(team),
        isSystem: true,
      );
    });
  }

  List<WorkspaceFinderNode> _playerNodes() {
    return List<WorkspaceFinderNode>.generate(widget.players.length, (index) {
      final player = widget.players[index];
      final number = '${player['number'] ?? player['shirt_number'] ?? ''}'.trim();
      final subtitleParts = <String>[
        if (widget.selectedTeamName.trim().isNotEmpty) widget.selectedTeamName.trim(),
        if (number.isNotEmpty) '№$number',
      ];
      return WorkspaceFinderNode(
        id: _nodeId('player', player, index),
        title: _playerTitle(player),
        subtitle: subtitleParts.isEmpty ? 'Игрок' : subtitleParts.join(' · '),
        kind: WorkspaceFinderNodeKind.player,
        moduleKey: 'players',
        payload: Map<String, dynamic>.from(player),
        isSystem: true,
      );
    });
  }

  List<WorkspaceFinderNode> _trainerNodes() {
    return List<WorkspaceFinderNode>.generate(widget.trainers.length, (index) {
      final trainer = widget.trainers[index];
      final role = '${trainer['role'] ?? trainer['position'] ?? trainer['specialization'] ?? ''}'
          .trim();
      return WorkspaceFinderNode(
        id: _nodeId('trainer', trainer, index),
        title: _trainerTitle(trainer),
        subtitle: role.isEmpty ? 'Тренер' : role,
        kind: WorkspaceFinderNodeKind.trainer,
        moduleKey: 'trainers',
        payload: Map<String, dynamic>.from(trainer),
        isSystem: true,
      );
    });
  }

  WorkspaceFinderModuleDefinition? _moduleFor(String key) {
    for (final module in kWorkspaceFinderModules) {
      if (module.key == key) return module;
    }
    return null;
  }

  List<WorkspaceFinderNode> _smartModuleNodes(String key) {
    WorkspaceFinderNode link(
      String id,
      String title,
      String subtitle,
      WorkspaceFinderNodeKind kind,
      String moduleKey,
    ) =>
        WorkspaceFinderNode(
          id: 'smart:$key:$id',
          title: title,
          subtitle: subtitle,
          kind: kind,
          moduleKey: moduleKey,
          isSystem: true,
        );

    switch (key) {
      case 'trainings':
        return <WorkspaceFinderNode>[
          link('calendar', 'Календарь тренировок', 'Расписание и события', WorkspaceFinderNodeKind.calendar, 'calendar'),
          link('plans', 'Планы-конспекты', 'Упражнения и методические материалы', WorkspaceFinderNodeKind.plan, 'plans'),
          link('attendance', 'Посещаемость', 'Журнал тренировок', WorkspaceFinderNodeKind.training, 'attendance'),
          link('tracker', 'Tracker Live', 'GPS и нагрузка на тренировке', WorkspaceFinderNodeKind.tracker, 'tracker'),
        ];
      case 'video':
        return <WorkspaceFinderNode>[
          link('analysis', 'Видеоанализ матчей', 'Разбор, эпизоды и AI', WorkspaceFinderNodeKind.video, 'videoAnalysis'),
          link('lessons', 'Видеоуроки', 'Методическая видеотека клуба', WorkspaceFinderNodeKind.video, 'videoLessons'),
        ];
      case 'reports':
        return <WorkspaceFinderNode>[
          link('tracker', 'Tracker отчёты', 'GPS, ЧСС, нагрузка и карты', WorkspaceFinderNodeKind.report, 'tracker'),
          link('testing', 'Отчёты тестирования', 'Динамика и результаты тестов', WorkspaceFinderNodeKind.testing, 'testing'),
          link('attendance', 'Посещаемость', 'Журнал и выгрузка', WorkspaceFinderNodeKind.report, 'attendance'),
        ];
      case 'documents':
        return <WorkspaceFinderNode>[
          link('players', 'Документы игроков', 'Карточки и личные документы', WorkspaceFinderNodeKind.document, 'players'),
          link('trainers', 'Документы тренеров', 'Профили и HR-документы', WorkspaceFinderNodeKind.document, 'trainers'),
          link('medical', 'Медицинские документы', 'Медкарта игроков', WorkspaceFinderNodeKind.medical, 'medical'),
        ];
      default:
        return const <WorkspaceFinderNode>[];
    }
  }

  List<WorkspaceFinderNode> _nodesForCurrentFolder() {
    List<WorkspaceFinderNode> nodes;
    switch (_folderKey) {
      case 'home':
        nodes = _rootNodes;
        break;
      case 'teams':
        nodes = _teamNodes();
        break;
      case 'players':
        nodes = _playerNodes();
        break;
      case 'trainers':
        nodes = _trainerNodes();
        break;
      case 'favorites':
        nodes = _allKnownNodes()
            .where((node) => _favoriteIds.contains(node.id))
            .toList();
        break;
      case 'recent':
        final all = <String, WorkspaceFinderNode>{
          for (final node in _allKnownNodes()) node.id: node,
        };
        nodes = _recentIds
            .map((id) => all[id])
            .whereType<WorkspaceFinderNode>()
            .toList();
        break;
      default:
        if (_projectedFolders.contains(_folderKey)) {
          nodes = <WorkspaceFinderNode>[...?_realFolderNodes[_folderKey]];
        } else {
          nodes = <WorkspaceFinderNode>[
            ..._smartModuleNodes(_folderKey),
            ...?_localChildren[_folderKey],
          ];
        }
        break;
    }

    final local = _localChildren[_folderKey];
    if (local != null && !_projectedFolders.contains(_folderKey) && _folderKey != 'home' && _folderKey != 'favorites' && _folderKey != 'recent') {
      final known = nodes.map((e) => e.id).toSet();
      nodes.addAll(local.where((node) => !known.contains(node.id)));
    }

    if (_folderKey != 'home' &&
        _folderKey != 'teams' &&
        _folderKey != 'players' &&
        _folderKey != 'trainers' &&
        _folderKey != 'favorites' &&
        _folderKey != 'recent' &&
        !_folderKey.startsWith('local-folder:') &&
        !_realFolderLoading.contains(_folderKey)) {
      final module = _moduleFor(_folderKey);
      if (module != null && _smartModuleNodes(_folderKey).isEmpty) {
        nodes = <WorkspaceFinderNode>[
          WorkspaceFinderNode(
            id: 'open-module:${module.key}',
            title: 'Открыть ${module.title}',
            subtitle: module.subtitle,
            kind: module.kind,
            moduleKey: module.key,
            isSystem: true,
          ),
          ...nodes,
        ];
      }
    }

    final query = _search.trim().toLowerCase();
    if (query.isNotEmpty) {
      nodes = nodes
          .where((node) =>
              node.title.toLowerCase().contains(query) ||
              node.subtitle.toLowerCase().contains(query))
          .toList();
    }

    // Real module collections are already returned by the backend bridge in
    // meaningful chronological order. Do not destroy that order by sorting
    // matches/trainings/plans alphabetically.
    if (!_projectedFolders.contains(_folderKey)) {
      nodes.sort((a, b) {
        if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }
    return nodes;
  }

  List<WorkspaceFinderNode> _allKnownNodes() {
    return <WorkspaceFinderNode>[
      ..._rootNodes,
      ..._teamNodes(),
      ..._playerNodes(),
      ..._trainerNodes(),
      for (final list in _realFolderNodes.values) ...list,
      for (final list in _localChildren.values) ...list,
    ];
  }

  Future<void> _refreshCurrentFolder() async {
    await widget.onRefresh?.call();
    if (_projectedFolders.contains(_folderKey)) {
      await _loadRealFolder(_folderKey, force: true);
    } else if (mounted) {
      setState(() {});
    }
  }

  void _rememberRecent(WorkspaceFinderNode node) {
    _recentIds.remove(node.id);
    _recentIds.insert(0, node.id);
    if (_recentIds.length > 24) _recentIds.removeLast();
    _persistLocalWorkspace();
  }

  Rect _nextWindowRect() {
    final offset = (_windowCascade % 7) * 24.0;
    _windowCascade += 1;
    return Rect.fromLTWH(246 + offset, 58 + offset, 920, 690);
  }

  void _closeWindow(String id) {
    if (!mounted) return;
    setState(() {
      _windows.removeWhere((entry) => entry.id == id);
      _activeWindowId = _windows.isEmpty ? null : _windows.last.id;
    });
  }

  void _activateWindow(String id) {
    final index = _windows.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    setState(() {
      final entry = _windows.removeAt(index);
      _windows.add(entry.copyWith(minimized: false));
      _activeWindowId = id;
    });
  }

  void _moveWindow(String id, Offset delta) {
    final index = _windows.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    final entry = _windows[index];
    setState(() => _windows[index] = entry.copyWith(rect: entry.rect.shift(delta), snap: WorkspaceWindowSnap.none));
  }

  void _resizeWindow(String id, Offset delta) {
    final index = _windows.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    final entry = _windows[index];
    final nextWidth = math.max(520.0, entry.rect.width + delta.dx);
    final nextHeight = math.max(420.0, entry.rect.height + delta.dy);
    setState(() => _windows[index] = entry.copyWith(rect: Rect.fromLTWH(entry.rect.left, entry.rect.top, nextWidth, nextHeight), snap: WorkspaceWindowSnap.none));
  }

  void _minimizeWindow(String id) {
    final index = _windows.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    setState(() {
      _windows[index] = _windows[index].copyWith(minimized: true);
      final visible = _windows.where((entry) => !entry.minimized && entry.id != id).toList();
      _activeWindowId = visible.isEmpty ? null : visible.last.id;
    });
  }

  void _restoreWindow(String id) {
    final index = _windows.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    setState(() {
      final entry = _windows.removeAt(index).copyWith(minimized: false);
      _windows.add(entry);
      _activeWindowId = id;
    });
  }

  void _snapWindow(String id, WorkspaceWindowSnap snap) {
    final index = _windows.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    setState(() {
      _windows[index] = _windows[index].copyWith(snap: snap, minimized: false);
      _activeWindowId = id;
    });
  }

  Future<void> _openDesktopWindow({
    required String id,
    required String title,
    required SportotekaWorkspaceIconKind iconKind,
    String subtitle = '',
    required Widget Function(VoidCallback closeWindow) builder,
  }) async {
    final existing = _windows.indexWhere((entry) => entry.id == id);
    if (existing >= 0) {
      _restoreWindow(id);
      return;
    }
    final close = () => _closeWindow(id);
    final child = builder(close);
    setState(() {
      _windows.add(WorkspaceWindowEntry(
        id: id,
        title: title,
        subtitle: subtitle,
        iconKind: iconKind,
        child: child,
        rect: _nextWindowRect(),
      ));
      _activeWindowId = id;
    });
  }

  Future<void> _openNode(WorkspaceFinderNode node) async {
    setState(() {
      _selectedNodeId = node.id;
      _rememberRecent(node);
    });

    if (node.isFolder && node.moduleKey != null) {
      await _enterFolder(node.moduleKey!);
      return;
    }

    if (node.isFolder && node.id.startsWith('local-folder:')) {
      setState(() {
        _folderKey = node.id;
        _search = '';
        _selectedNodeId = null;
      });
      return;
    }

    switch (node.kind) {
      case WorkspaceFinderNodeKind.player:
        if (node.payload != null) await _openPlayerProject(node.payload!);
        return;
      case WorkspaceFinderNodeKind.team:
        if (node.payload != null) await _openTeamProject(node.payload!);
        return;
      case WorkspaceFinderNodeKind.trainer:
        if (node.payload != null) await _openTrainerProject(node.payload!);
        return;
      case WorkspaceFinderNodeKind.note:
        _openNote(node);
        return;
      case WorkspaceFinderNodeKind.video:
        if (node.payload?['_workspace_real_record'] == true) {
          await _openRealRecord(node);
          return;
        }
        await _openVideoCenter(
          initialSection: node.moduleKey == 'videoLessons'
              ? WorkspaceVideoCenterSection.lessons
              : WorkspaceVideoCenterSection.matches,
        );
        return;
      default:
        if (node.payload?['_workspace_real_record'] == true) {
          await _openRealRecord(node);
          return;
        }
        if (node.moduleKey != null) widget.onOpenModule(node.moduleKey!);
    }
  }

  Future<void> _openVideoCenter({
    required WorkspaceVideoCenterSection initialSection,
  }) async {
    SportotekaWorkspaceVideoCenter buildCenter() => SportotekaWorkspaceVideoCenter(
          clubId: widget.clubId,
          clubName: widget.clubName,
          teams: widget.teams,
          players: widget.players,
          trainers: widget.trainers,
          currentUserId: widget.currentUserId,
          selectedTeamId: widget.selectedTeamId,
          selectedTeamName: widget.selectedTeamName,
          initialSection: initialSection,
        );

    final width = MediaQuery.sizeOf(context).width;
    if (width < 760) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(child: buildCenter()),
          ),
        ),
      );
      return;
    }

    final lessons = initialSection == WorkspaceVideoCenterSection.lessons;
    await _openDesktopWindow(
      id: lessons ? 'video-center:lessons' : 'video-center:matches',
      title: lessons ? 'Видеоуроки' : 'Видео матчей',
      subtitle: lessons ? 'Методическая видеотека клуба' : 'Матчи, видео, загрузка и AI-анализ',
      iconKind: SportotekaWorkspaceIconKind.video,
      builder: (_) => buildCenter(),
    );
  }

  Future<void> _openRealRecord(WorkspaceFinderNode node) async {
    final record = Map<String, dynamic>.from(node.payload ?? const <String, dynamic>{});
    final owner = '${record['_workspace_owner'] ?? record['team_name'] ?? widget.selectedTeamName}'.trim();
    final sectionTitle = _sectionTitleForNode(node);
    final fileUrl = _absoluteRecordFileUrl(record);

    final identity = WorkspaceEntityIdentity.resolve(
      clubId: widget.clubId,
      record: record,
      sectionHint: sectionTitle,
      kind: node.kind,
      fallbackId: node.id,
    );
    final legacyNoteKey = 'sportoteka_real_${widget.clubId}_${node.id}';

    WorkspaceEntityRecordDocument buildDocument({VoidCallback? onClose}) => WorkspaceEntityRecordDocument(
          ownerTitle: owner.isEmpty ? widget.clubName : owner,
          sectionTitle: sectionTitle,
          title: node.title,
          iconKind: _sportIconForNode(node),
          record: record,
          properties: _realRecordProperties(node),
          noteKey: identity.key,
          legacyNoteKeys: <String>[legacyNoteKey],
          entityType: identity.type,
          entityId: identity.id,
          fileUrl: fileUrl,
          clubId: widget.clubId,
          serverParentKey: 'entity:${identity.type}:${identity.id}',
          onClose: onClose,
          onEdit: node.moduleKey == null
              ? null
              : () async {
                  widget.onOpenModule(node.moduleKey!);
                },
          onRefresh: () async {
            await widget.onRefresh?.call();
            await _loadRealFolder(_folderKey, force: true);
          },
        );

    final width = MediaQuery.sizeOf(context).width;
    if (width < 760) {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => Scaffold(backgroundColor: Colors.white, body: SafeArea(child: buildDocument()))));
      return;
    }
    await _openDesktopWindow(
      id: 'record:${node.id}',
      title: node.title,
      subtitle: sectionTitle,
      iconKind: _sportIconForNode(node),
      builder: (closeWindow) => buildDocument(onClose: closeWindow),
    );
  }

  String _sectionTitleForNode(WorkspaceFinderNode node) {
    switch (node.kind) {
      case WorkspaceFinderNodeKind.match:
        return 'Матчи';
      case WorkspaceFinderNodeKind.training:
        return 'Тренировки';
      case WorkspaceFinderNodeKind.plan:
        return 'Планы-конспекты';
      case WorkspaceFinderNodeKind.testing:
        return 'Тестирование';
      case WorkspaceFinderNodeKind.calendar:
        return 'Календарь';
      case WorkspaceFinderNodeKind.document:
        return 'Документы';
      case WorkspaceFinderNodeKind.medical:
        return 'Медкарта';
      case WorkspaceFinderNodeKind.report:
        return 'Отчёты';
      case WorkspaceFinderNodeKind.video:
        return 'Видео';
      case WorkspaceFinderNodeKind.tracker:
        return 'Tracker';
      default:
        return _moduleFor(_folderKey)?.title ?? 'Рабочий файл';
    }
  }

  List<WorkspaceEntityProperty> _realRecordProperties(WorkspaceFinderNode node) {
    final row = node.payload ?? const <String, dynamic>{};
    final out = <WorkspaceEntityProperty>[];
    void add(String label, List<String> keys) {
      for (final key in keys) {
        final value = '${row[key] ?? ''}'.trim();
        if (value.isNotEmpty && value.toLowerCase() != 'null') {
          out.add(WorkspaceEntityProperty(label, value));
          return;
        }
      }
    }
    add('Команда', const <String>['team_name']);
    add('Дата', const <String>['start_at', 'event_date', 'training_date', 'match_date', 'test_date', 'plan_date', 'record_date', 'date']);
    add('Тип', const <String>['type', 'event_type', 'category', 'record_type', 'document_type']);
    add('Соперник', const <String>['opponent', 'opponent_name', 'rival']);
    add('Счёт', const <String>['score', 'result', 'final_score']);
    add('Место', const <String>['location', 'venue', 'stadium', 'place']);
    add('Тренер', const <String>['trainer_name', 'coach_name', 'author_name']);
    add('Владелец', const <String>['_workspace_owner']);
    add('Номер', const <String>['document_number', 'number']);
    add('Срок действия', const <String>['valid_until', 'expires_at', 'expiry_date']);
    add('Описание', const <String>['notes', 'note', 'comment', 'description', 'value']);
    add('Файл', const <String>['file_name', 'original_name']);
    return out;
  }

  String _absoluteRecordFileUrl(Map<String, dynamic> row) {
    var raw = '${row['file_url'] ?? row['url'] ?? row['file'] ?? ''}'.trim();
    if (raw.isEmpty || raw == 'null') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    while (raw.startsWith('../')) raw = raw.substring(3);
    while (raw.startsWith('./')) raw = raw.substring(2);
    while (raw.startsWith('/')) raw = raw.substring(1);
    return 'https://sportotekaapp.ru/$raw';
  }

  Future<void> _openPlayerProject(Map<String, dynamic> rawPlayer) async {
    final player = Map<String, dynamic>.from(rawPlayer);
    player['club_id'] ??= widget.clubId;
    player['clubId'] ??= widget.clubId;
    player['team_id'] ??= player['teamId'] ?? widget.selectedTeamId;
    player['teamId'] ??= player['team_id'] ?? widget.selectedTeamId;
    player['team_name'] ??= widget.selectedTeamName;
    player['teamName'] ??= widget.selectedTeamName;
    final last = '${player['last_name'] ?? player['lastname'] ?? ''}'.trim();
    final first = '${player['first_name'] ?? player['firstname'] ?? ''}'.trim();
    final fallback = '${player['full_name'] ?? player['name'] ?? 'Игрок'}'.trim();
    final title = <String>[last, first].where((e) => e.isNotEmpty).join(' ').trim();
    final id = '${player['player_id'] ?? player['id'] ?? title}';
    final width = MediaQuery.sizeOf(context).width;
    if (width < 760) {
      final project = SportotekaPlayerProjectScreen(
        player: player,
        clubId: widget.clubId,
        currentUserId: widget.currentUserId,
        teamId: widget.selectedTeamId,
        teamName: widget.selectedTeamName,
        onRefresh: widget.onRefresh,
      );
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => Scaffold(backgroundColor: Colors.white, body: SafeArea(child: project))));
      return;
    }
    await _openDesktopWindow(
      id: 'player:$id',
      title: title.isEmpty ? fallback : title,
      subtitle: widget.selectedTeamName,
      iconKind: SportotekaWorkspaceIconKind.players,
      builder: (closeWindow) => SportotekaPlayerProjectScreen(
        player: player,
        clubId: widget.clubId,
        currentUserId: widget.currentUserId,
        teamId: widget.selectedTeamId,
        teamName: widget.selectedTeamName,
        onRefresh: widget.onRefresh,
        onClose: closeWindow,
      ),
    );
  }

  Future<void> _openTeamProject(Map<String, dynamic> rawTeam) async {
    final team = Map<String, dynamic>.from(rawTeam);
    final id = '${team['team_id'] ?? team['id'] ?? team['name'] ?? 'team'}';
    final title = '${team['name'] ?? team['team_name'] ?? team['title'] ?? 'Команда'}'.trim();
    final width = MediaQuery.sizeOf(context).width;
    if (width < 760) {
      final project = SportotekaTeamProjectScreen(team: team, clubId: widget.clubId, currentUserId: widget.currentUserId, players: widget.players, onRefresh: widget.onRefresh, onOpenModule: widget.onOpenModule);
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => Scaffold(backgroundColor: Colors.white, body: SafeArea(child: project))));
      return;
    }
    await _openDesktopWindow(
      id: 'team:$id',
      title: title,
      iconKind: SportotekaWorkspaceIconKind.teams,
      builder: (closeWindow) => SportotekaTeamProjectScreen(
        team: team,
        clubId: widget.clubId,
        currentUserId: widget.currentUserId,
        players: widget.players,
        onRefresh: widget.onRefresh,
        onOpenModule: widget.onOpenModule,
        onClose: closeWindow,
      ),
    );
  }

  Future<void> _openTrainerProject(Map<String, dynamic> rawTrainer) async {
    final trainer = Map<String, dynamic>.from(rawTrainer);
    final id = '${trainer['trainer_id'] ?? trainer['id'] ?? trainer['name'] ?? 'trainer'}';
    final last = '${trainer['last_name'] ?? trainer['lastname'] ?? ''}'.trim();
    final first = '${trainer['first_name'] ?? trainer['firstname'] ?? ''}'.trim();
    final fallback = '${trainer['full_name'] ?? trainer['name'] ?? 'Тренер'}'.trim();
    final title = <String>[last, first].where((e) => e.isNotEmpty).join(' ').trim();
    final width = MediaQuery.sizeOf(context).width;
    if (width < 760) {
      final project = SportotekaTrainerProjectScreen(trainer: trainer, clubId: widget.clubId, currentUserId: widget.currentUserId, teams: widget.teams, players: widget.players, onRefresh: widget.onRefresh);
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => Scaffold(backgroundColor: Colors.white, body: SafeArea(child: project))));
      return;
    }
    await _openDesktopWindow(
      id: 'trainer:$id',
      title: title.isEmpty ? fallback : title,
      iconKind: SportotekaWorkspaceIconKind.trainers,
      builder: (closeWindow) => SportotekaTrainerProjectScreen(
        trainer: trainer,
        clubId: widget.clubId,
        currentUserId: widget.currentUserId,
        teams: widget.teams,
        players: widget.players,
        onRefresh: widget.onRefresh,
        onClose: closeWindow,
      ),
    );
  }

  Future<void> _openProjectSurface(
    Widget project, {
    required double maxWidth,
    required double maxHeight,
    String windowId = '',
    String windowTitle = 'Рабочий файл',
    String windowSubtitle = '',
    SportotekaWorkspaceIconKind iconKind = SportotekaWorkspaceIconKind.document,
  }) async {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 760) {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => Scaffold(backgroundColor: Colors.white, body: SafeArea(child: project))));
      return;
    }
    final id = windowId.trim().isEmpty ? 'surface:${DateTime.now().microsecondsSinceEpoch}' : windowId;
    await _openDesktopWindow(id: id, title: windowTitle, subtitle: windowSubtitle, iconKind: iconKind, builder: (_) => project);
  }

  void _goHome() {
    setState(() {
      _folderKey = 'home';
      _search = '';
      _selectedNodeId = null;
    });
  }

  String get _currentTitle {
    if (_folderKey == 'home') return widget.clubName.trim().isEmpty ? 'SPORTOTEKA' : widget.clubName;
    if (_folderKey == 'favorites') return 'Избранное';
    if (_folderKey == 'recent') return 'Недавние';
    final module = _moduleFor(_folderKey);
    if (module != null) return module.title;
    for (final node in _allKnownNodes()) {
      if (node.id == _folderKey) return node.title;
    }
    return 'Папка';
  }

  List<String> get _breadcrumbs {
    if (_folderKey == 'home') return <String>['Клуб'];
    return <String>['Клуб', _currentTitle];
  }

  Future<void> _createFolder() async {
    if (!_canCreateWorkspaceNode) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Новая папка', style: AppTypography.sectionTitle()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Название папки',
            hintStyle: AppTypography.formHint(),
          ),
          style: AppTypography.formText(),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Отмена', style: AppTypography.action()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('Создать', style: AppTypography.actionStrong(color: Colors.white)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;

    final id = 'local-folder:${DateTime.now().microsecondsSinceEpoch}';
    final node = WorkspaceFinderNode(
      id: id,
      title: name,
      subtitle: 'Папка Спортотека OS',
      kind: WorkspaceFinderNodeKind.folder,
      parentId: _folderKey,
      createdAt: DateTime.now(),
    );
    setState(() {
      (_localChildren[_folderKey] ??= <WorkspaceFinderNode>[]).add(node);
    });
    await _persistLocalWorkspace();
    await _serverCreateNode(node);
  }

  Future<void> _createNote() async {
    if (!_canCreateWorkspaceNode) return;
    final id = 'note:${DateTime.now().microsecondsSinceEpoch}';
    final node = WorkspaceFinderNode(
      id: id,
      title: 'Новый документ',
      subtitle: 'Заметка Спортотека OS',
      kind: WorkspaceFinderNodeKind.note,
      parentId: _folderKey,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    setState(() {
      (_localChildren[_folderKey] ??= <WorkspaceFinderNode>[]).add(node);
      _noteBodies[id] = '';
      _pendingSyncIds.add(id);
    });
    await _persistLocalWorkspace();
    _wsLog('CREATE_NOTE local uid=$id -> sync');
    try {
      await _serverStorage.syncNodeDocument(node: node, body: '', createHint: true);
      _serverAvailable = true;
      _pendingSyncIds.remove(id);
      await _persistLocalWorkspace();
      _wsLog('CREATE_NOTE sync OK uid=$id');
    } catch (e, st) {
      _serverAvailable = false;
      _wsLog('CREATE_NOTE sync FAILED uid=$id error=$e');
      _wsLog('CREATE_NOTE stack=${st.toString().split('\n').take(5).join(' | ')}');
      // Keep pending. The editor save / next refresh retries it.
    }
    await _openNote(node);
  }

  Future<void> _openNote(WorkspaceFinderNode node) async {
    _wsLog('OPEN_NOTE uid=${node.id} pending=${_pendingSyncIds.contains(node.id)} localBodyLen=${(_noteBodies[node.id] ?? '').length}');
    // Always ask the server for the latest saved copy before opening the
    // editor, unless this device has a known unsynced local edit. This makes
    // cross-device saves visible as soon as the document is opened.
    if (!_pendingSyncIds.contains(node.id)) {
      try {
        final remote = await _serverStorage.loadDocument(clientUid: node.id);
        final remoteBodyForLog = '${remote?['body'] ?? ''}';
        _wsLog(
          "OPEN_NOTE remote uid=${node.id} exists=${remote?['exists']} "
          "version=${remote?['version']} updated=${remote?['updated_at']} "
          'bodyLen=${remoteBodyForLog.length}',
        );
        if (remote != null && remote['exists'] == true) {
          final remoteBody = '${remote['body'] ?? ''}';
          final remoteTitle = '${remote['title'] ?? ''}'.trim();
          final remoteUpdated = DateTime.tryParse(
            '${remote['updated_at'] ?? ''}'.replaceFirst(' ', 'T'),
          );
          final localBefore = _findLocalNode(node.id) ?? node;
          final localBody = _noteBodies[node.id] ?? '';
          final localUpdated = localBefore.updatedAt;

          final localLooksNewer = localBody != remoteBody &&
              localUpdated != null &&
              (remoteUpdated == null ||
                  localUpdated.isAfter(remoteUpdated.add(const Duration(seconds: 5))));

          if (localLooksNewer) {
            _wsLog('OPEN_NOTE local newer -> pending uid=${node.id} localUpdated=$localUpdated remoteUpdated=$remoteUpdated localLen=${localBody.length} remoteLen=${remoteBody.length}');
            // Older application builds could leave a newer body only in the
            // local cache. Do not overwrite it; queue it for upload instead.
            _pendingSyncIds.add(node.id);
          } else {
            _wsLog("OPEN_NOTE applying remote uid=${node.id} version=${remote['version']} remoteLen=${remoteBody.length}");
            if (mounted) {
              setState(() {
                _noteBodies[node.id] = remoteBody;
                _replaceLocalNode(
                  node.id,
                  (old) => old.copyWith(
                    title: remoteTitle.isEmpty ? old.title : remoteTitle,
                    updatedAt: remoteUpdated ?? old.updatedAt,
                  ),
                );
              });
            } else {
              _noteBodies[node.id] = remoteBody;
            }
          }
        }
        _serverAvailable = true;
        await _persistLocalWorkspace();
      } catch (e, st) {
        // Offline: continue with the local cache. The pending-sync logic will
        // retry when connectivity returns.
        _serverAvailable = false;
        _wsLog('OPEN_NOTE remote load FAILED uid=${node.id} error=$e');
        _wsLog('OPEN_NOTE stack=${st.toString().split('\n').take(5).join(' | ')}');
      }
    }

    final currentBody = _noteBodies[node.id] ?? '';
    final localNode = _findLocalNode(node.id);
    final initialTitle = localNode?.title ?? node.title;

    Future<void> save(String title, String body) async {
      final saveTitleForLog = title.isEmpty ? 'Без названия' : title;
      _wsLog('SAVE begin uid=${node.id} title=$saveTitleForLog bodyLen=${body.length}');
      setState(() {
        _noteBodies[node.id] = body;
        _pendingSyncIds.add(node.id);
        _replaceLocalNode(
          node.id,
          (old) => old.copyWith(
            title: title.isEmpty ? 'Без названия' : title,
            updatedAt: DateTime.now(),
          ),
        );
      });
      await _persistLocalWorkspace();
      _wsLog('SAVE local persisted uid=${node.id} pending=${_pendingSyncIds.contains(node.id)}');
      final savedNode = _findLocalNode(node.id);
      if (savedNode == null) {
        _wsLog('SAVE ABORT uid=${node.id}: local node not found');
        return;
      }
      try {
        await _serverStorage.syncNodeDocument(node: savedNode, body: body);
        _serverAvailable = true;
        _pendingSyncIds.remove(node.id);
        await _persistLocalWorkspace();
        _wsLog('SAVE server sync OK uid=${node.id} bodyLen=${body.length}');
      } catch (e, st) {
        _serverAvailable = false;
        _wsLog('SAVE server sync FAILED uid=${node.id} bodyLen=${body.length} error=$e');
        _wsLog('SAVE stack=${st.toString().split('\n').take(6).join(' | ')}');
        throw Exception('Документ сохранён локально, но серверная синхронизация не выполнена: $e');
      }
    }

    final width = MediaQuery.sizeOf(context).width;
    if (width >= 760) {
      await _openDesktopWindow(
        id: 'note:${node.id}',
        title: initialTitle,
        subtitle: _editorContextName,
        iconKind: SportotekaWorkspaceIconKind.document,
        builder: (closeWindow) => WorkspaceDocumentEditor(
          initialTitle: initialTitle,
          initialBody: currentBody,
          contextLabel: _editorContextLabel,
          contextName: _editorContextName,
          documentType: 'Заметка',
          liveBlocksKey: node.id,
          onSave: save,
          onClose: closeWindow,
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (routeContext, animation, secondaryAnimation) => Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: WorkspaceDocumentEditor(
              initialTitle: initialTitle,
              initialBody: currentBody,
              contextLabel: _editorContextLabel,
              contextName: _editorContextName,
              documentType: 'Заметка',
              liveBlocksKey: node.id,
              onSave: save,
              onClose: () => Navigator.of(routeContext).pop(),
            ),
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  String get _editorContextLabel {
    switch (_folderKey) {
      case 'players':
        return 'Игрок';
      case 'trainers':
        return 'Тренер';
      case 'teams':
        return 'Команда';
      case 'trainings':
        return 'Тренировка';
      case 'matches':
        return 'Матч';
      default:
        return 'Пространство клуба';
    }
  }

  String get _editorContextName {
    if (_folderKey == 'home') return widget.clubName;
    return _currentTitle;
  }

  WorkspaceFinderNode? _findLocalNode(String id) {
    for (final list in _localChildren.values) {
      for (final node in list) {
        if (node.id == id) return node;
      }
    }
    return null;
  }

  void _replaceLocalNode(
    String id,
    WorkspaceFinderNode Function(WorkspaceFinderNode old) transform,
  ) {
    for (final entry in _localChildren.entries) {
      final index = entry.value.indexWhere((node) => node.id == id);
      if (index >= 0) {
        entry.value[index] = transform(entry.value[index]);
        return;
      }
    }
  }

  Future<void> _deleteLocalNode(WorkspaceFinderNode node) async {
    setState(() {
      for (final list in _localChildren.values) {
        list.removeWhere((item) => item.id == node.id);
      }
      _localChildren.remove(node.id);
      _noteBodies.remove(node.id);
      _favoriteIds.remove(node.id);
      _recentIds.remove(node.id);
      if (_selectedNodeId == node.id) _selectedNodeId = null;
    });
    await _persistLocalWorkspace();
    await _serverDeleteNode(node.id);
  }

  Future<void> _renameLocalNode(WorkspaceFinderNode node) async {
    if (node.isSystem) return;
    final controller = TextEditingController(text: node.title);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Переименовать', style: AppTypography.sectionTitle()),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.formText(),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Отмена', style: AppTypography.action()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('Готово', style: AppTypography.actionStrong(color: Colors.white)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    setState(() => _replaceLocalNode(node.id, (old) => old.copyWith(title: value, updatedAt: DateTime.now())));
    await _persistLocalWorkspace();
    final renamed = _findLocalNode(node.id);
    if (renamed != null) await _serverUpdateNode(renamed);
  }

  void _copyNode(WorkspaceFinderNode node) {
    setState(() => _clipboardNode = node);
    Clipboard.setData(ClipboardData(text: node.title));
    _showSnack('«${node.title}» скопирован. В Спортотека OS он вставляется как ярлык.');
  }

  Future<void> _pasteShortcut() async {
    final source = _clipboardNode;
    if (source == null) return;
    final now = DateTime.now();
    final shortcut = WorkspaceFinderNode(
      id: 'shortcut:${now.microsecondsSinceEpoch}',
      title: source.title,
      subtitle: source.subtitle.isEmpty ? 'Ярлык' : '${source.subtitle} · ярлык',
      kind: source.kind,
      moduleKey: source.moduleKey,
      payload: source.payload,
      parentId: _folderKey,
      isShortcut: true,
      createdAt: now,
    );
    setState(() {
      (_localChildren[_folderKey] ??= <WorkspaceFinderNode>[]).add(shortcut);
    });
    await _persistLocalWorkspace();
    await _serverCreateNode(shortcut);
  }

  Future<void> _dropNode(WorkspaceFinderNode source, WorkspaceFinderNode target) async {
    if (!(target.isFolder || target.kind == WorkspaceFinderNodeKind.team) || source.id == target.id) return;

    if (!target.isSystem && target.id.startsWith('local-folder:')) {
      final localSource = _findLocalNode(source.id);
      if (localSource != null && !source.isSystem && !source.isShortcut) {
        final moved = localSource.copyWith(parentId: target.id, updatedAt: DateTime.now());
        setState(() {
          for (final list in _localChildren.values) {
            list.removeWhere((item) => item.id == source.id);
          }
          (_localChildren[target.id] ??= <WorkspaceFinderNode>[]).add(moved);
          _selectedNodeId = moved.id;
        });
        await _persistLocalWorkspace();
        if (_serverAvailable) {
          try {
            await _serverStorage.moveNode(moved.id, target.id);
          } catch (_) {
            _serverAvailable = false;
          }
        }
        _showSnack('«${source.title}» перемещён в «${target.title}».');
        return;
      }

      final shortcut = WorkspaceFinderNode(
        id: 'shortcut:${DateTime.now().microsecondsSinceEpoch}',
        title: source.title,
        subtitle: source.subtitle.isEmpty ? 'Ярлык' : '${source.subtitle} · ярлык',
        kind: source.kind,
        moduleKey: source.moduleKey,
        payload: source.payload,
        parentId: target.id,
        isShortcut: true,
        createdAt: DateTime.now(),
      );
      setState(() {
        (_localChildren[target.id] ??= <WorkspaceFinderNode>[]).add(shortcut);
      });
      await _persistLocalWorkspace();
      await _serverCreateNode(shortcut);
      _showSnack('Создан ярлык в папке «${target.title}».');
      return;
    }

    if (widget.onMoveEntity != null) {
      final ok = await widget.onMoveEntity!(source, target);
      if (ok && mounted) {
        _showSnack('Изменение применено к данным клуба.');
        await widget.onRefresh?.call();
      }
      return;
    }

    try {
      final result = await _entityMoveBridge.move(source, target);
      if (result.handled) {
        if (result.success) {
          _showSnack(result.message.isEmpty ? 'Изменение применено к данным клуба.' : result.message);
          await widget.onRefresh?.call();
        } else {
          _showSnack(result.message.isEmpty ? 'Не удалось выполнить перенос.' : result.message);
        }
        return;
      }
    } catch (e) {
      _showSnack('Ошибка переноса: $e');
      return;
    }

    _showSnack('Для этого системного переноса нужен подтверждённый API раздела.');
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: AppTypography.body(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showNodeMenu(WorkspaceFinderNode node, Offset position) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem(value: 'open', child: Text('Открыть', style: AppTypography.menuTitle())),
        PopupMenuItem(value: 'copy', child: Text('Копировать', style: AppTypography.menuTitle())),
        PopupMenuItem(value: 'properties', child: Text('Свойства', style: AppTypography.menuTitle())),
        PopupMenuItem(
          value: 'favorite',
          child: Text(
            _favoriteIds.contains(node.id) ? 'Убрать из избранного' : 'В избранное',
            style: AppTypography.menuTitle(),
          ),
        ),
        if (!node.isSystem)
          PopupMenuItem(value: 'rename', child: Text('Переименовать', style: AppTypography.menuTitle())),
        if (!node.isSystem)
          PopupMenuItem(value: 'delete', child: Text('Удалить', style: AppTypography.menuTitle(color: const Color(0xFFB04444)))),
      ],
    );

    switch (action) {
      case 'open':
        await _openNode(node);
        break;
      case 'copy':
        _copyNode(node);
        break;
      case 'properties':
        await _showNodeProperties(node);
        break;
      case 'favorite':
        setState(() {
          if (!_favoriteIds.add(node.id)) _favoriteIds.remove(node.id);
        });
        await _persistLocalWorkspace();
        break;
      case 'rename':
        await _renameLocalNode(node);
        break;
      case 'delete':
        await _deleteLocalNode(node);
        break;
    }
  }


  WorkspaceFinderNode? get _selectedNode {
    final id = _selectedNodeId;
    if (id == null) return null;
    return _allKnownNodes().where((node) => node.id == id).firstOrNull;
  }

  String _nodeKindLabel(WorkspaceFinderNode node) {
    if (node.isShortcut) return 'Ярлык';
    switch (node.kind) {
      case WorkspaceFinderNodeKind.folder:
        return 'Папка';
      case WorkspaceFinderNodeKind.team:
        return 'Команда';
      case WorkspaceFinderNodeKind.player:
        return 'Игрок';
      case WorkspaceFinderNodeKind.trainer:
        return 'Тренер';
      case WorkspaceFinderNodeKind.match:
        return 'Матч';
      case WorkspaceFinderNodeKind.training:
        return 'Тренировка';
      case WorkspaceFinderNodeKind.plan:
        return 'План-конспект';
      case WorkspaceFinderNodeKind.tracker:
        return 'Tracker';
      case WorkspaceFinderNodeKind.testing:
        return 'Тестирование';
      case WorkspaceFinderNodeKind.calendar:
        return 'Календарь';
      case WorkspaceFinderNodeKind.document:
        return 'Документ';
      case WorkspaceFinderNodeKind.video:
        return 'Видео';
      case WorkspaceFinderNodeKind.report:
        return 'Отчёт';
      case WorkspaceFinderNodeKind.chat:
        return 'Чат';
      case WorkspaceFinderNodeKind.medical:
        return 'Медкарта';
      case WorkspaceFinderNodeKind.parent:
        return 'Родитель';
      case WorkspaceFinderNodeKind.shortcut:
        return 'Ярлык';
      case WorkspaceFinderNodeKind.note:
        return 'Документ Sportoteka';
    }
  }

  List<(String, String)> _nodeProperties(WorkspaceFinderNode node) {
    final p = node.payload ?? const <String, dynamic>{};
    String first(List<String> keys) {
      for (final key in keys) {
        final value = '${p[key] ?? ''}'.trim();
        if (value.isNotEmpty && value != 'null') return value;
      }
      return '';
    }
    final out = <(String, String)>[
      ('Тип', _nodeKindLabel(node)),
    ];
    if (node.kind == WorkspaceFinderNodeKind.player) {
      final team = first(const ['team_name', 'teamName']);
      final position = first(const ['position', 'role_on_field', 'amplua']);
      final birth = first(const ['birth_date', 'birthday']);
      if (team.isNotEmpty) out.add(('Команда', team));
      if (position.isNotEmpty) out.add(('Амплуа', position));
      if (birth.isNotEmpty) out.add(('Дата рождения', birth));
    } else if (node.kind == WorkspaceFinderNodeKind.team) {
      final category = first(const ['category', 'age_group', 'stage']);
      final sport = first(const ['sport']);
      if (category.isNotEmpty) out.add(('Категория', category));
      if (sport.isNotEmpty) out.add(('Вид спорта', sport));
    } else if (node.kind == WorkspaceFinderNodeKind.trainer) {
      final role = first(const ['role', 'position', 'trainer_role']);
      final email = first(const ['email']);
      if (role.isNotEmpty) out.add(('Роль', role));
      if (email.isNotEmpty) out.add(('E-mail', email));
    }
    final childCount = _localChildren[node.id]?.length ?? 0;
    if (node.isFolder && childCount > 0) out.add(('Содержимое', '$childCount объектов'));
    if (node.createdAt != null) out.add(('Создано', _formatNodeDate(node.createdAt!)));
    if (node.updatedAt != null) out.add(('Изменено', _formatNodeDate(node.updatedAt!)));
    return out;
  }

  String _formatNodeDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year} · ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _buildNodeInspector() {
    final node = _selectedNode;
    if (node == null) {
      return Center(child: Text('Выберите объект', style: AppTypography.secondary(color: _muted)));
    }
    final props = _nodeProperties(node);
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: SportotekaWorkspaceFolderIcon(
                size: 54,
                color: Color(0xFF6F7973),
                fillColor: Color(0xFFF0F5F2),
                showBrandDots: true,
              ),
            ),
            const SizedBox(height: 12),
            Text(node.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTypography.sectionTitle(color: _text)),
            if (node.subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(node.subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTypography.secondary(color: _muted)),
            ],
            const SizedBox(height: 18),
            for (final prop in props)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prop.$1, style: AppTypography.caption(color: _muted)),
                    const SizedBox(height: 2),
                    Text(prop.$2, style: AppTypography.secondaryMedium(color: _text)),
                  ],
                ),
              ),
            const Spacer(),
            FilledButton(
              onPressed: () => _openNode(node),
              style: FilledButton.styleFrom(backgroundColor: _green, elevation: 0),
              child: Text('Открыть', style: AppTypography.actionStrong(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNodeProperties(WorkspaceFinderNode node) async {
    setState(() => _selectedNodeId = node.id);
    final size = MediaQuery.sizeOf(context);
    if (size.width >= 1180) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) {
        final props = _nodeProperties(node);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const SportotekaWorkspaceFolderIcon(size: 42, color: Color(0xFF6F7973), fillColor: Color(0xFFF0F5F2), showBrandDots: true),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Свойства', style: AppTypography.sectionTitle(color: _text))),
                  ],
                ),
                const SizedBox(height: 14),
                Text(node.title, style: AppTypography.itemTitle(color: _text)),
                const SizedBox(height: 14),
                for (final prop in props)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 96, child: Text(prop.$1, style: AppTypography.caption(color: _muted))),
                        Expanded(child: Text(prop.$2, style: AppTypography.secondaryMedium(color: _text))),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _openNode(node);
                  },
                  style: FilledButton.styleFrom(backgroundColor: _green, elevation: 0),
                  child: Text('Открыть', style: AppTypography.actionStrong(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 700;
    final compact = size.width < 980;
    final showSidebar = !compact || _showSidebarOnCompact;
    WorkspaceLiveBlockRuntime.configure(
      clubIdValue: widget.clubId,
      teamsValue: widget.teams,
      playersValue: widget.players,
      trainersValue: widget.trainers,
      selectedTeamIdValue: widget.selectedTeamId,
      selectedTeamNameValue: widget.selectedTeamName,
      onOpenModuleValue: widget.onOpenModule,
      onOpenPlayerValue: _openPlayerProject,
    );

    return WorkspaceLiveBlockContext(
      clubId: widget.clubId,
      teams: widget.teams,
      players: widget.players,
      trainers: widget.trainers,
      selectedTeamId: widget.selectedTeamId,
      selectedTeamName: widget.selectedTeamName,
      onOpenModule: widget.onOpenModule,
      onOpenPlayer: _openPlayerProject,
      child: Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyC, meta: true): _CopyIntent(),
        SingleActivator(LogicalKeyboardKey.keyC, control: true): _CopyIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, meta: true): _PasteIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, control: true): _PasteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CopyIntent: CallbackAction<_CopyIntent>(onInvoke: (_) {
            final node = _nodesForCurrentFolder().where((n) => n.id == _selectedNodeId).firstOrNull;
            if (node != null) _copyNode(node);
            return null;
          }),
          _PasteIntent: CallbackAction<_PasteIntent>(onInvoke: (_) {
            _pasteShortcut();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: ColoredBox(
            color: _bg,
            child: Stack(
              children: [
                Row(
                  children: [
                    if (showSidebar)
                      SizedBox(
                        width: mobile ? math.min(280.0, size.width * .82) : 226.0,
                        child: _buildSidebar(compact: compact),
                      ),
                    Expanded(child: _buildMain(mobile: mobile, compact: compact)),
                    if (!compact && size.width >= 1180 && _selectedNodeId != null) ...[
                      const VerticalDivider(width: 1, color: _line),
                      SizedBox(width: 276, child: _buildNodeInspector()),
                    ],
                  ],
                ),
                if (compact && showSidebar)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: IconButton.filledTonal(
                      onPressed: () => setState(() => _showSidebarOnCompact = false),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Закрыть меню',
                    ),
                  ),
                if (!mobile && _windows.isNotEmpty)
                  Positioned.fill(
                    child: WorkspaceWindowLayer(
                      entries: _windows,
                      activeId: _activeWindowId,
                      onActivate: _activateWindow,
                      onClose: _closeWindow,
                      onMove: _moveWindow,
                      onResize: _resizeWindow,
                      onMinimize: _minimizeWindow,
                      onRestore: _restoreWindow,
                      onSnap: _snapWindow,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildSidebar({required bool compact}) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _line)),
      ),
      child: SafeArea(
        right: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 4, 9, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SPORTOTEKA OS', style: AppTypography.menuGroup(color: _green)),
                  const SizedBox(height: 4),
                  Text(
                    widget.clubName.trim().isEmpty ? 'Пространство клуба' : widget.clubName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.itemTitle(color: _text),
                  ),
                ],
              ),
            ),
            _SideItem(
              icon: Icons.home_rounded,
              title: 'Главная',
              selected: _folderKey == 'home',
              onTap: () {
                _goHome();
                if (compact) setState(() => _showSidebarOnCompact = false);
              },
            ),
            _SideItem(
              icon: Icons.schedule_rounded,
              title: 'Недавние',
              selected: _folderKey == 'recent',
              onTap: () {
                setState(() => _folderKey = 'recent');
                if (compact) setState(() => _showSidebarOnCompact = false);
              },
            ),
            _SideItem(
              icon: Icons.star_rounded,
              title: 'Избранное',
              selected: _folderKey == 'favorites',
              onTap: () {
                setState(() => _folderKey = 'favorites');
                if (compact) setState(() => _showSidebarOnCompact = false);
              },
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Text('КЛУБ', style: AppTypography.menuGroup(color: _muted)),
            ),
            const SizedBox(height: 5),
            for (final module in kWorkspaceFinderModules.take(9))
              _SideItem(
                icon: module.icon,
                title: module.title,
                selected: _folderKey == module.key,
                onTap: () => _enterFolder(
                  module.key,
                  closeCompactSidebar: compact,
                ),
              ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Text('ЕЩЁ', style: AppTypography.menuGroup(color: _muted)),
            ),
            const SizedBox(height: 5),
            for (final module in kWorkspaceFinderModules.skip(9))
              _SideItem(
                icon: module.icon,
                title: module.title,
                selected: _folderKey == module.key,
                onTap: () => _enterFolder(
                  module.key,
                  closeCompactSidebar: compact,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMain({required bool mobile, required bool compact}) {
    final nodes = _nodesForCurrentFolder();
    final loadingRealData = _realFolderLoading.contains(_folderKey);
    final forceList = _listFolders.contains(_folderKey);
    return Column(
      children: [
        _buildToolbar(mobile: mobile, compact: compact),
        _buildBreadcrumbs(mobile: mobile),
        Expanded(
          child: loadingRealData
              ? _buildRealFolderLoading()
              : nodes.isEmpty
                  ? _buildEmpty()
                  : forceList || _viewMode == WorkspaceFinderViewMode.list
                      ? _buildList(nodes, mobile: mobile)
                      : _buildGrid(nodes, mobile: mobile),
        ),
        _buildStatusBar(nodes.length),
      ],
    );
  }

  Widget _buildRealFolderLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: _green),
          ),
          const SizedBox(height: 10),
          Text('Загружаю реальные данные Спортотеки…', style: AppTypography.secondary(color: _muted)),
        ],
      ),
    );
  }

  Widget _buildToolbar({required bool mobile, required bool compact}) {
    return Container(
      height: mobile ? 58 : 62,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          if (compact)
            IconButton(
              onPressed: () => setState(() => _showSidebarOnCompact = true),
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Разделы',
            ),
          IconButton(
            onPressed: _folderKey == 'home' ? null : _goHome,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Назад',
          ),
          if (!mobile) ...[
            IconButton(
              onPressed: _refreshCurrentFolder,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Обновить',
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Container(
              height: 36,
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _search = value),
                style: AppTypography.formText(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: mobile ? 'Поиск' : 'Поиск в «$_currentTitle»',
                  hintStyle: AppTypography.formHint(),
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_canCreateWorkspaceNode)
            PopupMenuButton<String>(
              tooltip: 'Создать',
              onSelected: (value) {
                if (value == 'folder') _createFolder();
                if (value == 'note') _createNote();
                if (value == 'paste') _pasteShortcut();
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'folder', child: Text('Новая папка', style: AppTypography.menuTitle())),
                PopupMenuItem(value: 'note', child: Text('Новый документ', style: AppTypography.menuTitle())),
                if (_clipboardNode != null)
                  PopupMenuItem(value: 'paste', child: Text('Вставить ярлык', style: AppTypography.menuTitle())),
              ],
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    if (!mobile) ...[
                      const SizedBox(width: 5),
                      Text('Создать', style: AppTypography.actionStrong(color: Colors.white)),
                    ],
                  ],
                ),
              ),
            )
          else if (_clipboardNode != null && _folderKey.startsWith('local-folder:'))
            IconButton(
              tooltip: 'Вставить ярлык',
              onPressed: _pasteShortcut,
              icon: const Icon(Icons.content_paste_rounded, size: 19),
            ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == WorkspaceFinderViewMode.grid
                    ? WorkspaceFinderViewMode.list
                    : WorkspaceFinderViewMode.grid;
              });
              _persistLocalWorkspace();
            },
            icon: Icon(
              _viewMode == WorkspaceFinderViewMode.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
            tooltip: _viewMode == WorkspaceFinderViewMode.grid ? 'Список' : 'Иконки',
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs({required bool mobile}) {
    return Container(
      height: mobile ? 42 : 46,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 18),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          for (int i = 0; i < _breadcrumbs.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: _muted),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: i == 0 ? _goHome : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Text(
                  _breadcrumbs[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: i == _breadcrumbs.length - 1
                      ? AppTypography.menuTitle(color: _text)
                      : AppTypography.menuTitle(color: _muted),
                ),
              ),
            ),
          ],
          const Spacer(),
          if (!mobile && widget.selectedTeamName.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5EF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.selectedTeamName,
                style: AppTypography.captionMedium(color: _green),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<WorkspaceFinderNode> nodes, {required bool mobile}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = mobile ? 142.0 : 154.0;
        final count = math.max(2, (constraints.maxWidth / targetWidth).floor()).toInt();
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(mobile ? 10 : 18, 4, mobile ? 10 : 18, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisExtent: mobile ? 142 : 150,
            crossAxisSpacing: mobile ? 6 : 10,
            mainAxisSpacing: mobile ? 6 : 10,
          ),
          itemCount: nodes.length,
          itemBuilder: (_, index) => _buildGridNode(nodes[index], mobile: mobile),
        );
      },
    );
  }

  Widget _buildGridNode(WorkspaceFinderNode node, {required bool mobile}) {
    final selected = _selectedNodeId == node.id;
    final favorite = _favoriteIds.contains(node.id);
    final tile = DragTarget<WorkspaceFinderNode>(
      onWillAccept: (data) => data != null && (node.isFolder || node.kind == WorkspaceFinderNodeKind.team) && data.id != node.id,
      onAccept: (data) => _dropNode(data, node),
      builder: (context, candidate, rejected) {
        final accepting = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            color: accepting
                ? const Color(0xFFE6F4EC)
                : selected
                    ? const Color(0xFFEAF3EE)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _FinderFolderGlyph(
                      size: mobile ? 68 : 74,
                    ),
                    if (favorite)
                      const Positioned(
                        top: 1,
                        right: 12,
                        child: Icon(Icons.star_rounded, size: 15, color: Color(0xFFD39C18)),
                      ),
                    if (node.isShortcut)
                      const Positioned(
                        bottom: 5,
                        right: 14,
                        child: Icon(Icons.shortcut_rounded, size: 15, color: _muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      node.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.menuTitle(color: _text),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const _FinderBrandDots(),
                ],
              ),
              if (node.subtitle.isNotEmpty && !mobile) ...[
                const SizedBox(height: 2),
                Text(
                  node.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(color: _muted),
                ),
              ],
            ],
          ),
        );
      },
    );

    final interactive = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selectedNodeId = node.id);
        if (mobile || node.kind == WorkspaceFinderNodeKind.video) _openNode(node);
      },
      onDoubleTap: mobile ? null : () => _openNode(node),
      onSecondaryTapDown: (details) => _showNodeMenu(node, details.globalPosition),
      child: tile,
    );

    return LongPressDraggable<WorkspaceFinderNode>(
      data: node,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 138,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 18)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const _FinderFolderGlyph(size: 24),
                  const SizedBox(width: 7),
                  Expanded(child: Text(node.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.captionMedium())),
                ],
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: .35, child: interactive),
      child: interactive,
    );
  }

  Widget _buildList(List<WorkspaceFinderNode> nodes, {required bool mobile}) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(mobile ? 8 : 14, 2, mobile ? 8 : 14, 28),
      itemCount: nodes.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 52, color: _line),
      itemBuilder: (_, index) {
        final node = nodes[index];
        final selected = _selectedNodeId == node.id;
        return DragTarget<WorkspaceFinderNode>(
          onWillAccept: (data) => data != null && (node.isFolder || node.kind == WorkspaceFinderNodeKind.team) && data.id != node.id,
          onAccept: (data) => _dropNode(data, node),
          builder: (context, candidate, rejected) {
            final tile = Material(
              color: selected || candidate.isNotEmpty ? const Color(0xFFEAF3EE) : Colors.white,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () {
                  setState(() => _selectedNodeId = node.id);
                  if (mobile || node.kind == WorkspaceFinderNodeKind.video) _openNode(node);
                },
                onDoubleTap: mobile ? null : () => _openNode(node),
                onLongPress: () => _copyNode(node),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      _FinderListGlyph(kind: _sportIconForNode(node), size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(node.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.menuTitle(color: _text))),
                                const SizedBox(width: 6),
                                const _FinderBrandDots(compact: true),
                              ],
                            ),
                            if (node.subtitle.isNotEmpty)
                              Text(node.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _muted)),
                          ],
                        ),
                      ),
                      if (_favoriteIds.contains(node.id))
                        const Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(Icons.star_rounded, size: 15, color: Color(0xFFD39C18)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded, size: 19),
                        onPressed: () {
                          final box = context.findRenderObject() as RenderBox?;
                          final pos = box?.localToGlobal(const Offset(20, 20)) ?? const Offset(120, 120);
                          _showNodeMenu(node, pos);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: mobile ? null : () => _openNode(node),
              onSecondaryTapDown: (details) => _showNodeMenu(node, details.globalPosition),
              child: tile,
            );
          },
        );
      },
    );
  }

  SportotekaWorkspaceIconKind _sportIconForNode(WorkspaceFinderNode node) {
    if (node.moduleKey != null && node.moduleKey!.isNotEmpty) {
      return sportotekaWorkspaceIconForModuleKey(node.moduleKey!);
    }
    switch (node.kind) {
      case WorkspaceFinderNodeKind.team:
        return SportotekaWorkspaceIconKind.teams;
      case WorkspaceFinderNodeKind.player:
        return SportotekaWorkspaceIconKind.players;
      case WorkspaceFinderNodeKind.trainer:
        return SportotekaWorkspaceIconKind.trainers;
      case WorkspaceFinderNodeKind.match:
        return SportotekaWorkspaceIconKind.matches;
      case WorkspaceFinderNodeKind.training:
        return SportotekaWorkspaceIconKind.trainings;
      case WorkspaceFinderNodeKind.plan:
        return SportotekaWorkspaceIconKind.plans;
      case WorkspaceFinderNodeKind.tracker:
        return SportotekaWorkspaceIconKind.tracker;
      case WorkspaceFinderNodeKind.testing:
        return SportotekaWorkspaceIconKind.testing;
      case WorkspaceFinderNodeKind.calendar:
        return SportotekaWorkspaceIconKind.calendar;
      case WorkspaceFinderNodeKind.document:
        return SportotekaWorkspaceIconKind.document;
      case WorkspaceFinderNodeKind.video:
        return SportotekaWorkspaceIconKind.video;
      case WorkspaceFinderNodeKind.report:
        return SportotekaWorkspaceIconKind.reports;
      case WorkspaceFinderNodeKind.chat:
        return SportotekaWorkspaceIconKind.chat;
      case WorkspaceFinderNodeKind.medical:
        return SportotekaWorkspaceIconKind.medical;
      case WorkspaceFinderNodeKind.parent:
        return SportotekaWorkspaceIconKind.parents;
      case WorkspaceFinderNodeKind.shortcut:
        return SportotekaWorkspaceIconKind.shortcut;
      case WorkspaceFinderNodeKind.note:
        return SportotekaWorkspaceIconKind.note;
      case WorkspaceFinderNodeKind.folder:
        return SportotekaWorkspaceIconKind.folder;
    }
  }

  IconData _iconForNode(WorkspaceFinderNode node) {
    if (node.isFolder && node.moduleKey != null) {
      return _moduleFor(node.moduleKey!)?.icon ?? Icons.folder_rounded;
    }
    if (node.kind == WorkspaceFinderNodeKind.shortcut && node.moduleKey != null) {
      return _moduleFor(node.moduleKey!)?.icon ?? Icons.shortcut_rounded;
    }
    return workspaceFinderIconForKind(node.kind);
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SportotekaWorkspaceFolderIcon(
              size: 58,
              color: Color(0xFFAAB8B1),
              fillColor: Colors.white,
              showBrandDots: false,
            ),
            const SizedBox(height: 12),
            Text('Здесь пока пусто', style: AppTypography.sectionTitle(color: _text)),
            const SizedBox(height: 5),
            Text(
              _search.trim().isNotEmpty
                  ? 'По запросу ничего не найдено.'
                  : _projectedFolders.contains(_folderKey)
                      ? (_realFolderErrors[_folderKey]?.isNotEmpty == true
                          ? 'Не удалось получить данные раздела. Обновите список или откройте основной модуль.'
                          : 'В основном разделе Спортотеки пока нет записей.')
                      : 'Создайте папку или документ. Системные данные клуба появятся здесь автоматически.',
              textAlign: TextAlign.center,
              style: AppTypography.secondary(color: _muted),
            ),
            const SizedBox(height: 14),
            if (_projectedFolders.contains(_folderKey))
              OutlinedButton.icon(
                onPressed: () => _loadRealFolder(_folderKey, force: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Обновить данные', style: AppTypography.action()),
              )
            else if (_canCreateWorkspaceNode)
              OutlinedButton.icon(
                onPressed: _createNote,
                icon: const Icon(Icons.note_add_rounded, size: 18),
                label: Text('Новый документ', style: AppTypography.action()),
              )
            else
              OutlinedButton.icon(
                onPressed: _refreshCurrentFolder,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Обновить список', style: AppTypography.action()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(int count) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Text('$count объектов', style: AppTypography.caption(color: _muted)),
          const Spacer(),
          if (_clipboardNode != null)
            Text('Буфер: ${_clipboardNode!.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _muted)),
        ],
      ),
    );
  }
}


class _FinderListGlyph extends StatelessWidget {
  const _FinderListGlyph({required this.kind, required this.size});

  final SportotekaWorkspaceIconKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: SportotekaWorkspaceIcon(
        kind: kind,
        size: size * .58,
        color: const Color(0xFF3E4A43),
        accentColor: const Color(0xFF0B8F55),
      ),
    );
  }
}

class _FinderBrandDots extends StatelessWidget {
  const _FinderBrandDots({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dot = compact ? 5.0 : 6.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: index == 1 ? const Color(0xFF17A36A) : const Color(0xFFB8D9C6),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _FinderFolderGlyph extends StatelessWidget {
  const _FinderFolderGlyph({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SportotekaWorkspaceFolderIcon(
        size: size,
        color: const Color(0xFF8D9490),
        fillColor: const Color(0xFFF2F3F2),
        showBrandDots: false,
      );
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? const Color(0xFFF1F7F4) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? const Color(0xFF0B8F55) : const Color(0xFF667169)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.menuTitle(
                      color: selected ? const Color(0xFF101814) : const Color(0xFF4F5A53),
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CopyIntent extends Intent {
  const _CopyIntent();
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
