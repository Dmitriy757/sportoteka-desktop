import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_document_editor.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_player_data_bridge.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_player_section_document.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_server_storage.dart';

class WorkspacePlayerSectionBrowser extends StatefulWidget {
  const WorkspacePlayerSectionBrowser({
    super.key,
    required this.player,
    required this.clubId,
    required this.section,
    this.teamId,
    this.teamName = '',
    this.createOnOpen = false,
    this.onRefresh,
  });

  final Map<String, dynamic> player;
  final int clubId;
  final int? teamId;
  final String teamName;
  final bool createOnOpen;
  final WorkspacePlayerSection section;
  final Future<void> Function()? onRefresh;

  @override
  State<WorkspacePlayerSectionBrowser> createState() => _WorkspacePlayerSectionBrowserState();
}

class _WorkspacePlayerSectionBrowserState extends State<WorkspacePlayerSectionBrowser> {
  static const _green = Color(0xFF0B8F55);
  static const _greenSoft = Color(0xFFF2F8F5);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);
  static const _soft = Color(0xFFF7F8F7);
  static const _danger = Color(0xFFB42318);

  final _bridge = WorkspacePlayerDataBridge();
  late final WorkspaceServerStorage _serverStorage;
  bool _serverAvailable = false;
  final _search = TextEditingController();
  bool _loading = true;
  bool _dragging = false;
  bool _uploading = false;
  String? _error;
  List<Map<String, dynamic>> _records = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _localRecords = <Map<String, dynamic>>[];
  Map<String, dynamic>? _selected;
  _SortMode _sort = _SortMode.newest;

  String get _playerName {
    final last = '${widget.player['last_name'] ?? widget.player['lastname'] ?? ''}'.trim();
    final first = '${widget.player['first_name'] ?? widget.player['firstname'] ?? ''}'.trim();
    final full = '${widget.player['full_name'] ?? widget.player['fullName'] ?? widget.player['name'] ?? ''}'.trim();
    final joined = <String>[last, first].where((e) => e.isNotEmpty).join(' ').trim();
    return joined.isNotEmpty ? joined : (full.isNotEmpty ? full : 'Игрок');
  }

  String get _sectionTitle {
    switch (widget.section) {
      case WorkspacePlayerSection.card:
        return 'Карточка игрока';
      case WorkspacePlayerSection.diary:
        return 'Дневник';
      case WorkspacePlayerSection.readiness:
        return 'Готовность';
      case WorkspacePlayerSection.activity:
        return 'Активность';
      case WorkspacePlayerSection.matches:
        return 'Матчи';
      case WorkspacePlayerSection.testing:
        return 'Тестирование';
      case WorkspacePlayerSection.health:
        return 'Здоровье';
      case WorkspacePlayerSection.documents:
        return 'Документы';
    }
  }

  bool get _canUpload =>
      widget.section == WorkspacePlayerSection.health ||
      widget.section == WorkspacePlayerSection.documents;

  bool get _canCreateDiary => widget.section == WorkspacePlayerSection.diary;

  bool get _documentsOnly => widget.section == WorkspacePlayerSection.documents;

  String get _serverParentKey {
    final playerId = _bridge.resolvePlayerId(widget.player);
    return 'player:$playerId:${widget.section.name}';
  }

  String get _localStorageKey {
    final playerId = _bridge.resolvePlayerId(widget.player);
    return 'sportoteka_os_player_records_v2_${widget.clubId}_${playerId}_${widget.section.name}';
  }

  @override
  void initState() {
    super.initState();
    _serverStorage = WorkspaceServerStorage(clubId: widget.clubId);
    _search.addListener(_onSearch);
    _load().then((_) {
      if (mounted && widget.createOnOpen && _canCreateDiary) _createLocalRecord();
    });
  }

  @override
  void dispose() {
    _search
      ..removeListener(_onSearch)
      ..dispose();
    super.dispose();
  }

  void _onSearch() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<Map<String, dynamic>> rows;
      switch (widget.section) {
        case WorkspacePlayerSection.card:
          rows = <Map<String, dynamic>>[<String, dynamic>{
            'id': _bridge.resolvePlayerId(widget.player),
            'title': 'Карточка игрока',
            'type': 'Системный документ',
            'date': widget.player['updated_at'] ?? widget.player['created_at'] ?? '',
          }];
          break;
        case WorkspacePlayerSection.diary:
          rows = await _bridge.loadDiary(
            player: widget.player,
            teamId: widget.teamId,
            clubId: widget.clubId,
          );
          break;
        case WorkspacePlayerSection.readiness:
          // Готовность в текущем профиле вычисляется из реальных оценок,
          // посещаемости и нагрузки. Не создаём для неё отдельные fake notes.
          rows = await _bridge.loadDiary(
            player: widget.player,
            teamId: widget.teamId,
            clubId: widget.clubId,
          );
          break;
        case WorkspacePlayerSection.activity:
          rows = await _bridge.loadPlayerActivity(player: widget.player, teamId: widget.teamId);
          break;
        case WorkspacePlayerSection.matches:
          rows = await _bridge.loadTeamMatches(player: widget.player, teamId: widget.teamId);
          break;
        case WorkspacePlayerSection.testing:
          rows = await _bridge.loadTestingSessions(
            player: widget.player,
            clubId: widget.clubId,
            teamId: widget.teamId,
          );
          break;
        case WorkspacePlayerSection.health:
        case WorkspacePlayerSection.documents:
          rows = await _bridge.loadMedicalRecords(widget.player);
          if (_documentsOnly) {
            rows = rows.where(_looksLikeDocument).toList();
          }
          break;
      }

      rows = rows.map((row) => Map<String, dynamic>.from(row)).toList();
      var legacyRows = <Map<String, dynamic>>[];
      if (_canCreateDiary) {
        legacyRows = await _readLocalRecords();
        if (legacyRows.isNotEmpty) {
          legacyRows = await _migrateLegacyDiaryRecords(rows, legacyRows);
          if (legacyRows.isEmpty) {
            rows = await _bridge.loadDiary(
              player: widget.player,
              teamId: widget.teamId,
              clubId: widget.clubId,
            );
          }
        }
      }

      // Only an old Diary draft that could not yet be migrated may be shown
      // beside canonical data. Real Matches/Activity/Testing/etc never mix
      // with Workspace-only copies anymore.
      final visibleRows = <Map<String, dynamic>>[
        ...rows.map((row) => Map<String, dynamic>.from(row)),
        ...legacyRows,
      ]..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));

      if (!mounted) return;
      setState(() {
        _localRecords = legacyRows;
        _records = visibleRows;
        _selected = visibleRows.isNotEmpty ? visibleRows.first : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final legacyRows = _canCreateDiary ? await _readLocalRecords() : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _localRecords = legacyRows;
        _records = legacyRows;
        _selected = legacyRows.isNotEmpty ? legacyRows.first : null;
        _loading = false;
      });
    }
  }

  bool _isLocalRecord(Map<String, dynamic> row) => row['_workspace_local'] == true;

  Future<List<Map<String, dynamic>>> _readLocalRecords() async {
    if (!_canCreateDiary) return <Map<String, dynamic>>[];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localStorageKey);
    var local = <Map<String, dynamic>>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          local = decoded
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .where(_isLocalRecord)
              .toList();
        }
      } catch (_) {}
    }

    try {
      var snapshot = await _serverStorage.load();
      final serverNodes = snapshot.nodes
          .where((node) => node.parentId == _serverParentKey && node.kind == WorkspaceFinderNodeKind.note)
          .toList();
      final serverIds = serverNodes.map((e) => e.id).toSet();
      final unsynced = local.where((row) => !serverIds.contains('${row['id'] ?? ''}')).toList();
      for (final row in unsynced) {
        final id = '${row['id'] ?? ''}';
        if (id.isEmpty) continue;
        final node = WorkspaceFinderNode(
          id: id,
          title: '${row['title'] ?? 'Рабочая заметка'}',
          subtitle: '${row['subtitle'] ?? 'Редактируемая заметка'}',
          kind: WorkspaceFinderNodeKind.note,
          parentId: _serverParentKey,
          createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
          updatedAt: DateTime.tryParse('${row['updated_at'] ?? ''}'),
        );
        await _serverStorage.createNode(node);
        await _serverStorage.saveDocument(
          clientUid: id,
          title: node.title,
          body: '${row['workspace_note'] ?? ''}',
        );
      }
      if (unsynced.isNotEmpty) snapshot = await _serverStorage.load();
      final rows = <Map<String, dynamic>>[];
      for (final node in snapshot.nodes.where((n) => n.parentId == _serverParentKey && n.kind == WorkspaceFinderNodeKind.note)) {
        rows.add(<String, dynamic>{
          'id': node.id,
          '_workspace_local': true,
          '_workspace_server': true,
          'title': node.title,
          'subtitle': node.subtitle,
          'type': 'Рабочая заметка',
          'workspace_note': snapshot.noteBodies[node.id] ?? '',
          'created_at': node.createdAt?.toIso8601String() ?? '',
          'updated_at': node.updatedAt?.toIso8601String() ?? '',
        });
      }
      _serverAvailable = true;
      return rows;
    } catch (_) {
      _serverAvailable = false;
      return local;
    }
  }

  Future<List<Map<String, dynamic>>> _migrateLegacyDiaryRecords(
    List<Map<String, dynamic>> canonicalRows,
    List<Map<String, dynamic>> legacyRows,
  ) async {
    if (!_canCreateDiary || legacyRows.isEmpty) return legacyRows;

    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final row in legacyRows) {
      var date = _dateOf(row);
      if (date.year <= 1970) date = DateTime.now();
      final key = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(row);
    }

    try {
      for (final entry in byDate.entries) {
        final date = DateTime.tryParse(entry.key) ?? DateTime.now();
        final existing = canonicalRows
            .where((row) => '${row['_workspace_diary_source'] ?? ''}' == 'player_diary')
            .where((row) {
              final d = _dateOf(row);
              return d.year == date.year && d.month == date.month && d.day == date.day;
            })
            .map((row) => '${row['note'] ?? ''}'.trim())
            .where((text) => text.isNotEmpty)
            .toList();
        final migrated = <String>[];
        for (final row in entry.value) {
          final title = '${row['title'] ?? ''}'.trim();
          final body = '${row['workspace_note'] ?? ''}'.trim();
          final block = <String>[
            if (title.isNotEmpty && title != 'Новая заметка' && title != 'Рабочая заметка') title,
            if (body.isNotEmpty) body,
          ].join('\n\n').trim();
          if (block.isNotEmpty) migrated.add(block);
        }
        final noteParts = <String>[...existing, ...migrated];
        final unique = <String>[];
        for (final text in noteParts) {
          if (text.isNotEmpty && !unique.contains(text)) unique.add(text);
        }
        if (unique.isEmpty) continue;
        await _bridge.saveDiaryNote(
          player: widget.player,
          clubId: widget.clubId,
          teamId: widget.teamId,
          note: unique.join('\n\n'),
          date: date,
        );
      }

      for (final row in legacyRows) {
        final id = '${row['id'] ?? ''}'.trim();
        if (id.isEmpty) continue;
        try {
          await _serverStorage.deleteNode(id);
        } catch (_) {}
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localStorageKey);
      return <Map<String, dynamic>>[];
    } catch (_) {
      // Server Phase 25 may not be deployed yet. Keep old drafts visible and
      // retry migration on the next refresh instead of losing user data.
      return legacyRows;
    }
  }

  Future<void> _persistLocalRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localStorageKey, jsonEncode(_localRecords));
  }

  bool _looksLikeDocument(Map<String, dynamic> row) {
    final type = '${row['type'] ?? row['record_type'] ?? ''}'.toLowerCase();
    return type.contains('документ') || type.contains('document') || type.contains('file');
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.trim().toLowerCase();
    final rows = _records.where((r) {
      if (q.isEmpty) return true;
      final hay = '${_titleOf(r)} ${_subtitleOf(r)} ${_dateLabel(r)}'.toLowerCase();
      return hay.contains(q);
    }).map((e) => Map<String, dynamic>.from(e)).toList();
    switch (_sort) {
      case _SortMode.newest:
        rows.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
        break;
      case _SortMode.oldest:
        rows.sort((a, b) => _dateOf(a).compareTo(_dateOf(b)));
        break;
      case _SortMode.title:
        rows.sort((a, b) => _titleOf(a).toLowerCase().compareTo(_titleOf(b).toLowerCase()));
        break;
    }
    return rows;
  }

  String _titleOf(Map<String, dynamic> row) {
    if (_isLocalRecord(row)) {
      final value = '${row['title'] ?? ''}'.trim();
      return value.isEmpty ? 'Рабочая заметка' : value;
    }
    if (widget.section == WorkspacePlayerSection.matches) {
      final opponent = '${row['opponent'] ?? row['opponent_name'] ?? ''}'.trim();
      final competition = '${row['competition_name'] ?? row['event_type'] ?? ''}'.trim();
      return opponent.isNotEmpty ? 'Матч — $opponent' : (competition.isNotEmpty ? competition : 'Матч');
    }
    if (widget.section == WorkspacePlayerSection.testing) {
      final category = '${row['category'] ?? ''}'.trim();
      final stage = '${row['stage'] ?? ''}'.trim();
      return 'Тестирование${category.isEmpty ? '' : ' · ${_categoryRu(category)}'}${stage.isEmpty ? '' : ' · $stage'}';
    }
    if (widget.section == WorkspacePlayerSection.activity) {
      return '${row['title'] ?? row['event_title'] ?? row['name'] ?? row['training_title'] ?? 'Тренировка'}'.trim();
    }
    if (widget.section == WorkspacePlayerSection.diary || widget.section == WorkspacePlayerSection.readiness) {
      return '${row['title'] ?? row['training_title'] ?? row['event_title'] ?? 'Запись дневника'}'.trim();
    }
    return '${row['title'] ?? row['name'] ?? row['type'] ?? row['record_type'] ?? 'Документ'}'.trim();
  }

  String _subtitleOf(Map<String, dynamic> row) {
    if (_isLocalRecord(row)) {
      final value = '${row['subtitle'] ?? ''}'.trim();
      return value.isEmpty ? 'Редактируемая заметка' : value;
    }
    if (widget.section == WorkspacePlayerSection.matches) {
      final our = '${row['our_score'] ?? ''}'.trim();
      final opp = '${row['opponent_score'] ?? ''}'.trim();
      final competition = '${row['competition_name'] ?? row['event_type'] ?? ''}'.trim();
      final score = our.isNotEmpty && opp.isNotEmpty ? '$our:$opp' : '';
      return <String>[competition, score].where((e) => e.isNotEmpty).join(' · ');
    }
    if (widget.section == WorkspacePlayerSection.activity) {
      return <String>[
        '${row['mark'] ?? row['status'] ?? row['attendance_status'] ?? ''}'.trim(),
        '${row['coach_note'] ?? row['trainer_note'] ?? row['note'] ?? ''}'.trim(),
      ].where((e) => e.isNotEmpty).join(' · ');
    }
    if (widget.section == WorkspacePlayerSection.testing) {
      return '${row['title'] ?? row['name'] ?? row['session_name'] ?? 'Контрольные показатели'}'.trim();
    }
    if (widget.section == WorkspacePlayerSection.diary || widget.section == WorkspacePlayerSection.readiness) {
      return '${row['player_note'] ?? row['self_note'] ?? row['diary_note'] ?? row['note'] ?? row['comment'] ?? ''}'.trim();
    }
    return '${row['comment'] ?? row['value'] ?? row['type'] ?? row['record_type'] ?? ''}'.trim();
  }


  DateTime _dateOf(Map<String, dynamic> row) {
    for (final key in const <String>[
      'test_date', 'match_date', 'event_date', 'start_at', 'date',
      'record_date', 'created_at', 'updated_at', 'uploaded_at',
    ]) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isEmpty) continue;
      final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
      if (parsed != null) return parsed;
    }
    return DateTime(1970);
  }

  String _dateLabel(Map<String, dynamic> row) {
    final d = _dateOf(row);
    if (d.year <= 1970) return 'Без даты';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  String _categoryRu(String value) {
    switch (value.toLowerCase()) {
      case 'physical':
        return 'Физика';
      case 'technical':
        return 'Техника';
      case 'tactical':
        return 'Тактика';
      default:
        return value;
    }
  }

  Future<void> _createLocalRecord() async {
    if (!_canCreateDiary) return;
    final today = DateTime.now();
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (routeContext, animation, secondaryAnimation) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: WorkspaceDocumentEditor(
              initialTitle: 'Заметка тренера',
              initialBody: '',
              contextLabel: 'Игрок · Дневник',
              contextName: _playerName,
              documentType: 'Запись дневника',
              onSave: (title, body) async {
                final cleanTitle = title.trim();
                final cleanBody = body.trim();
                final note = <String>[
                  if (cleanTitle.isNotEmpty && cleanTitle != 'Заметка тренера') cleanTitle,
                  if (cleanBody.isNotEmpty) cleanBody,
                ].join('\n\n').trim();
                if (note.isEmpty) return;
                await _bridge.saveDiaryNote(
                  player: widget.player,
                  clubId: widget.clubId,
                  teamId: widget.teamId,
                  note: note,
                  date: today,
                );
              },
              onClose: () => Navigator.of(routeContext).maybePop(),
            ),
          ),
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(.018, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
    );
    if (!mounted) return;
    await _load();
    await widget.onRefresh?.call();
  }

  Future<void> _openLocalRecord(Map<String, dynamic> record) async {
    final id = '${record['id'] ?? ''}';
    final initialTitle = _titleOf(record);
    final initialBody = '${record['workspace_note'] ?? ''}';

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (routeContext, animation, secondaryAnimation) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: WorkspaceDocumentEditor(
              initialTitle: initialTitle,
              initialBody: initialBody,
              contextLabel: 'Игрок · $_sectionTitle',
              contextName: _playerName,
              documentType: 'Рабочая заметка',
              onSave: (title, body) => _updateLocalRecord(id, title, body),
              onClose: () => Navigator.of(routeContext).maybePop(),
            ),
          ),
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(.018, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _updateLocalRecord(String id, String title, String body) async {
    final now = DateTime.now().toIso8601String();
    Map<String, dynamic> update(Map<String, dynamic> row) {
      if ('${row['id'] ?? ''}' != id) return row;
      return <String, dynamic>{
        ...row,
        'title': title.trim().isEmpty ? 'Рабочая заметка' : title.trim(),
        'subtitle': _bodyPreview(body),
        'workspace_note': body,
        'updated_at': now,
      };
    }

    setState(() {
      _localRecords = _localRecords.map(update).toList();
      _records = _records.map(update).toList();
      final selectedId = '${_selected?['id'] ?? ''}';
      if (selectedId == id) {
        _selected = _records.firstWhere((row) => '${row['id'] ?? ''}' == id);
      }
    });
    await _persistLocalRecords();
    final matches = _localRecords.where((row) => '${row['id'] ?? ''}' == id);
    if (matches.isNotEmpty) await _syncUpdateRecord(matches.first);
  }

  Future<void> _syncCreateRecord(Map<String, dynamic> row) async {
    if (!_serverAvailable) {
      try {
        await _serverStorage.load();
        _serverAvailable = true;
      } catch (_) {
        return;
      }
    }
    final id = '${row['id'] ?? ''}';
    if (id.isEmpty) return;
    try {
      final node = WorkspaceFinderNode(
        id: id,
        title: '${row['title'] ?? 'Рабочая заметка'}',
        subtitle: '${row['subtitle'] ?? 'Редактируемая заметка'}',
        kind: WorkspaceFinderNodeKind.note,
        parentId: _serverParentKey,
        createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
        updatedAt: DateTime.tryParse('${row['updated_at'] ?? ''}'),
      );
      await _serverStorage.createNode(node);
      await _serverStorage.saveDocument(clientUid: id, title: node.title, body: '${row['workspace_note'] ?? ''}');
    } catch (_) {
      _serverAvailable = false;
    }
  }

  Future<void> _syncUpdateRecord(Map<String, dynamic> row) async {
    if (!_serverAvailable) return;
    final id = '${row['id'] ?? ''}';
    if (id.isEmpty) return;
    try {
      final node = WorkspaceFinderNode(
        id: id,
        title: '${row['title'] ?? 'Рабочая заметка'}',
        subtitle: '${row['subtitle'] ?? ''}',
        kind: WorkspaceFinderNodeKind.note,
        parentId: _serverParentKey,
        updatedAt: DateTime.now(),
      );
      await _serverStorage.updateNode(node);
      await _serverStorage.saveDocument(clientUid: id, title: node.title, body: '${row['workspace_note'] ?? ''}');
    } catch (_) {
      _serverAvailable = false;
    }
  }

  String _bodyPreview(String body) {
    final clean = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return 'Редактируемая заметка';
    return clean.length <= 92 ? clean : '${clean.substring(0, 92)}…';
  }

  Future<void> _duplicateRecord(Map<String, dynamic> source) async {
    final now = DateTime.now();
    final body = _isLocalRecord(source)
        ? '${source['workspace_note'] ?? ''}'
        : <String>[
            'Копия записи из раздела «$_sectionTitle»',
            '',
            'Источник: ${_titleOf(source)}',
            'Дата: ${_dateLabel(source)}',
            if (_subtitleOf(source).trim().isNotEmpty) '',
            if (_subtitleOf(source).trim().isNotEmpty) _subtitleOf(source),
          ].join('\n');
    final copy = <String, dynamic>{
      'id': 'workspace_${now.microsecondsSinceEpoch}',
      '_workspace_local': true,
      'title': 'Копия — ${_titleOf(source)}',
      'subtitle': _bodyPreview(body),
      'type': 'Рабочая копия',
      'workspace_note': body,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    setState(() {
      _localRecords = <Map<String, dynamic>>[copy, ..._localRecords];
      _records = <Map<String, dynamic>>[copy, ..._records];
      _selected = copy;
    });
    await _persistLocalRecords();
    await _syncCreateRecord(copy);
    if (mounted) await _openLocalRecord(copy);
  }

  Future<void> _deleteLocalRecord(Map<String, dynamic> record) async {
    if (!_isLocalRecord(record)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Удалить заметку?', style: AppTypography.sectionTitle(color: _text)),
        content: Text('«${_titleOf(record)}» будет удалена из этого раздела игрока.', style: AppTypography.secondary(color: _muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Удалить', style: AppTypography.action(color: _danger))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = '${record['id'] ?? ''}';
    setState(() {
      _localRecords.removeWhere((row) => '${row['id'] ?? ''}' == id);
      _records.removeWhere((row) => '${row['id'] ?? ''}' == id);
      _selected = _records.isEmpty ? null : _records.first;
    });
    await _persistLocalRecords();
    if (_serverAvailable) {
      try {
        await _serverStorage.deleteNode(id);
      } catch (_) {
        _serverAvailable = false;
      }
    }
  }

  Future<void> _openRecord(Map<String, dynamic> record) async {
    setState(() => _selected = record);
    if (_isLocalRecord(record)) {
      await _openLocalRecord(record);
      return;
    }
    var openRecord = Map<String, dynamic>.from(record);
    if (widget.section == WorkspacePlayerSection.testing) {
      openRecord = await _bridge.enrichTestingSessionForPlayer(
        player: widget.player,
        clubId: widget.clubId,
        teamId: widget.teamId,
        session: openRecord,
      );
      if (!mounted) return;
    }
    final child = WorkspacePlayerSectionDocument(
      player: widget.player,
      clubId: widget.clubId,
      teamId: widget.teamId,
      teamName: widget.teamName,
      section: widget.section,
      record: openRecord,
      recordTitle: _titleOf(openRecord),
      onRefresh: () async {
        await _load();
        await widget.onRefresh?.call();
      },
    );
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(child: child),
        ),
        transitionsBuilder: (_, animation, __, routeChild) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(.018, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: routeChild,
          ),
        ),
      ),
    );
  }

  Future<void> _showContext(Map<String, dynamic> record, Offset global) async {
    setState(() => _selected = record);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<_ContextAction>(
      context: context,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      position: RelativeRect.fromRect(
        Rect.fromPoints(global, global),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<_ContextAction>>[
        PopupMenuItem(
          value: _ContextAction.open,
          height: 38,
          child: Text(_isLocalRecord(record) ? 'Редактировать' : 'Открыть', style: AppTypography.menuTitle(color: _text)),
        ),
        if (_isLocalRecord(record))
          PopupMenuItem(
            value: _ContextAction.duplicate,
            height: 38,
            child: Text('Создать копию', style: AppTypography.menuTitle(color: _text)),
          ),
        PopupMenuItem(
          value: _ContextAction.properties,
          height: 38,
          child: Text('Свойства', style: AppTypography.menuTitle(color: _text)),
        ),
        if (_isLocalRecord(record)) const PopupMenuDivider(),
        if (_isLocalRecord(record))
          PopupMenuItem(
            value: _ContextAction.delete,
            height: 38,
            child: Text('Удалить', style: AppTypography.menuTitle(color: _danger)),
          ),
      ],
    );
    if (!mounted || selected == null) return;
    if (selected == _ContextAction.open) {
      await _openRecord(record);
    } else if (selected == _ContextAction.duplicate) {
      await _duplicateRecord(record);
    } else if (selected == _ContextAction.delete) {
      await _deleteLocalRecord(record);
    } else {
      await _showProperties(record);
    }
  }

  Future<void> _showProperties(Map<String, dynamic> record) async {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) {
      setState(() => _selected = record);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: _PropertiesPanel(
            title: _titleOf(record),
            date: _dateLabel(record),
            sectionTitle: _sectionTitle,
            record: record,
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    if (!_canUpload || _uploading) return;
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    await _upload(result.files.first);
  }

  Future<void> _upload(PlatformFile file) async {
    final meta = await _askUploadMeta(file.name);
    if (meta == null) return;
    setState(() => _uploading = true);
    try {
      await _bridge.uploadMedicalAttachment(
        player: widget.player,
        file: file,
        title: meta.$1,
        type: _documentsOnly ? 'Документ' : meta.$2,
        comment: meta.$3,
        date: meta.$4,
      );
      await _load();
      await widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось добавить файл: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<(String, String, String, DateTime)?> _askUploadMeta(String fileName) async {
    final title = TextEditingController(text: fileName);
    final comment = TextEditingController();
    var type = _documentsOnly ? 'Документ' : 'Справка';
    var date = DateTime.now();
    final result = await showDialog<(String, String, String, DateTime)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(_documentsOnly ? 'Новый документ' : 'Новый медицинский файл', style: AppTypography.sectionTitle(color: _text)),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, style: AppTypography.formText(color: _text), decoration: const InputDecoration(labelText: 'Название')),
                if (!_documentsOnly) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: const <String>['Справка', 'Допуск', 'Заключение', 'Анализ', 'Травма', 'Реабилитация', 'Документ']
                        .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setLocal(() => type = v ?? type),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(controller: comment, maxLines: 3, style: AppTypography.formText(color: _text), decoration: const InputDecoration(labelText: 'Комментарий')),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: date);
                      if (picked != null) setLocal(() => date = picked);
                    },
                    child: Text('Дата: ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _green),
              onPressed: () => Navigator.pop(ctx, (title.text.trim().isEmpty ? fileName : title.text.trim(), type, comment.text.trim(), date)),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    comment.dispose();
    return result;
  }

  Future<void> _handleDrop(List<XFile> files) async {
    if (!_canUpload || files.isEmpty || _uploading) return;
    final x = files.first;
    final bytes = kIsWeb ? await x.readAsBytes() : null;
    await _upload(PlatformFile(name: x.name, size: bytes?.length ?? 0, path: kIsWeb ? null : x.path, bytes: bytes));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final mobile = constraints.maxWidth < 680;
      final showInspector = constraints.maxWidth >= 900;
      final list = _visible;
      final body = Column(
        children: [
          _BrowserHeader(
            playerName: _playerName,
            sectionTitle: _sectionTitle,
            count: _records.length,
            mobile: mobile,
            uploading: _uploading,
            canUpload: _canUpload,
            canCreate: _canCreateDiary,
            onBack: () => Navigator.of(context).maybePop(),
            onRefresh: _load,
            onCreate: _createLocalRecord,
            onUpload: _pickAndUpload,
          ),
          const Divider(height: 1, color: _line),
          _Toolbar(
            search: _search,
            sort: _sort,
            mobile: mobile,
            onSort: (v) => setState(() => _sort = v),
          ),
          const Divider(height: 1, color: _line),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFFFF3F1),
              child: Text(_error!, style: AppTypography.caption(color: _danger)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _green))
                : list.isEmpty
                    ? _EmptyState(canUpload: _canUpload, canCreate: _canCreateDiary, onCreate: _createLocalRecord, onUpload: _pickAndUpload)
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(mobile ? 8 : 12, 6, mobile ? 8 : 12, 18),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: _line),
                        itemBuilder: (_, i) {
                          final r = list[i];
                          return _RecordRow(
                            title: _titleOf(r),
                            subtitle: _subtitleOf(r),
                            date: _dateLabel(r),
                            selected: identical(_selected, r) || _sameRecord(_selected, r),
                            section: widget.section,
                            onTap: () {
                              if (mobile) {
                                _openRecord(r);
                              } else {
                                setState(() => _selected = r);
                              }
                            },
                            onOpen: () => _openRecord(r),
                            onCopy: _isLocalRecord(r) ? () => _duplicateRecord(r) : null,
                            onDelete: _isLocalRecord(r) ? () => _deleteLocalRecord(r) : null,
                            onProperties: () => _showProperties(r),
                            onSecondary: (p) => _showContext(r, p),
                          );
                        },
                      ),
          ),
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(color: _soft, border: Border(top: BorderSide(color: _line))),
            child: Row(
              children: [
                Text('${list.length} объектов', style: AppTypography.caption(color: _muted)),
                const Spacer(),
                Text('SPORTOTEKA PLAYER FILES', style: AppTypography.menuGroup(color: _muted)),
              ],
            ),
          ),
        ],
      );

      Widget wrapped = body;
      if (_canUpload) {
        wrapped = DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (d) async {
            setState(() => _dragging = false);
            await _handleDrop(d.files);
          },
          child: Stack(
            children: [
              Positioned.fill(child: body),
              if (_dragging)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: _green.withOpacity(.07),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _green, width: 1.2)),
                        child: Text('Отпустите файл — он будет привязан к игроку', style: AppTypography.itemTitle(color: _green)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      if (!showInspector) return ColoredBox(color: Colors.white, child: wrapped);
      return ColoredBox(
        color: Colors.white,
        child: Row(
          children: [
            Expanded(child: wrapped),
            Container(width: 1, color: _line),
            SizedBox(
              width: 286,
              child: _selected == null
                  ? const _InspectorEmpty()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      child: _PropertiesPanel(
                        title: _titleOf(_selected!),
                        date: _dateLabel(_selected!),
                        sectionTitle: _sectionTitle,
                        record: _selected!,
                        onOpen: () => _openRecord(_selected!),
                      ),
                    ),
            ),
          ],
        ),
      );
    });
  }

  bool _sameRecord(Map<String, dynamic>? a, Map<String, dynamic> b) {
    if (a == null) return false;
    for (final key in const <String>['id', 'match_id', 'event_id', 'session_id', 'test_id']) {
      final av = '${a[key] ?? ''}'.trim();
      final bv = '${b[key] ?? ''}'.trim();
      if (av.isNotEmpty && bv.isNotEmpty && av == bv) return true;
    }
    return _titleOf(a) == _titleOf(b) && _dateLabel(a) == _dateLabel(b);
  }
}

class _BrowserHeader extends StatelessWidget {
  const _BrowserHeader({
    required this.playerName,
    required this.sectionTitle,
    required this.count,
    required this.mobile,
    required this.uploading,
    required this.canUpload,
    required this.canCreate,
    required this.onBack,
    required this.onRefresh,
    required this.onCreate,
    required this.onUpload,
  });
  final String playerName;
  final String sectionTitle;
  final int count;
  final bool mobile;
  final bool uploading;
  final bool canUpload;
  final bool canCreate;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCreate;
  final Future<void> Function() onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mobile ? 62 : 70,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, size: 19, color: _WorkspacePlayerSectionBrowserState._text)),
          const SizedBox(width: 4),
          const _FileGlyph(size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sectionTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.screenTitle(color: _WorkspacePlayerSectionBrowserState._text)),
                const SizedBox(height: 2),
                Text('$playerName · $count записей', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.secondary(color: _WorkspacePlayerSectionBrowserState._muted)),
              ],
            ),
          ),
          if (canCreate) ...[
            if (mobile)
              IconButton(
                tooltip: 'Новая заметка',
                onPressed: () { onCreate(); },
                icon: const Icon(Icons.add_rounded, size: 21, color: _WorkspacePlayerSectionBrowserState._green),
              )
            else
              FilledButton.icon(
                onPressed: () { onCreate(); },
                style: FilledButton.styleFrom(
                  backgroundColor: _WorkspacePlayerSectionBrowserState._green,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: Text('Новая заметка', style: AppTypography.actionStrong(color: Colors.white)),
              ),
            const SizedBox(width: 4),
          ],
          if (canUpload)
            TextButton(
              onPressed: uploading ? null : () { onUpload(); },
              child: Text(uploading ? 'Загрузка…' : 'Добавить файл', style: AppTypography.actionStrong(color: _WorkspacePlayerSectionBrowserState._green)),
            ),
          IconButton(tooltip: 'Обновить', onPressed: () { onRefresh(); }, icon: const Icon(Icons.refresh_rounded, size: 18)),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.search, required this.sort, required this.mobile, required this.onSort});
  final TextEditingController search;
  final _SortMode sort;
  final bool mobile;
  final ValueChanged<_SortMode> onSort;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: mobile ? 52 : 54,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: search,
              style: AppTypography.formText(color: _WorkspacePlayerSectionBrowserState._text),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Поиск по названию, дате, типу…',
                hintStyle: AppTypography.formHint(color: _WorkspacePlayerSectionBrowserState._muted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: _WorkspacePlayerSectionBrowserState._soft,
                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<_SortMode>(
            tooltip: 'Сортировка',
            color: Colors.white,
            onSelected: onSort,
            itemBuilder: (_) => [
              PopupMenuItem(value: _SortMode.newest, child: Text('Сначала новые', style: AppTypography.menuTitle())),
              PopupMenuItem(value: _SortMode.oldest, child: Text('Сначала старые', style: AppTypography.menuTitle())),
              PopupMenuItem(value: _SortMode.title, child: Text('По названию', style: AppTypography.menuTitle())),
            ],
            icon: const Icon(Icons.swap_vert_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.selected,
    required this.section,
    required this.onTap,
    required this.onOpen,
    this.onCopy,
    required this.onProperties,
    required this.onSecondary,
    this.onDelete,
  });
  final String title;
  final String subtitle;
  final String date;
  final bool selected;
  final WorkspacePlayerSection section;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final VoidCallback onProperties;
  final ValueChanged<Offset> onSecondary;

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: selected ? _WorkspacePlayerSectionBrowserState._greenSoft : Colors.white,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onOpen,
        onLongPress: onProperties,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: [
              _RecordGlyph(section: section, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _WorkspacePlayerSectionBrowserState._text)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.secondary(color: _WorkspacePlayerSectionBrowserState._muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 96, child: Text(date, textAlign: TextAlign.right, style: AppTypography.captionMedium(color: _WorkspacePlayerSectionBrowserState._text))),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Действия',
                color: Colors.white,
                surfaceTintColor: Colors.white,
                onSelected: (value) {
                  if (value == 'open') onOpen();
                  if (value == 'copy') onCopy?.call();
                  if (value == 'properties') onProperties();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'open', child: Text(onDelete == null ? 'Открыть' : 'Редактировать', style: AppTypography.menuTitle())),
                  if (onCopy != null) PopupMenuItem(value: 'copy', child: Text('Создать копию', style: AppTypography.menuTitle())),
                  PopupMenuItem(value: 'properties', child: Text('Свойства', style: AppTypography.menuTitle())),
                  if (onDelete != null) const PopupMenuDivider(),
                  if (onDelete != null) PopupMenuItem(value: 'delete', child: Text('Удалить', style: AppTypography.menuTitle(color: _WorkspacePlayerSectionBrowserState._danger))),
                ],
                icon: const Icon(Icons.more_horiz_rounded, size: 19),
              ),
            ],
          ),
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (d) => onSecondary(d.globalPosition),
      child: content,
    );
  }
}

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({required this.title, required this.date, required this.sectionTitle, required this.record, this.onOpen});
  final String title;
  final String date;
  final String sectionTitle;
  final Map<String, dynamic> record;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    String first(Iterable<String> keys) {
      for (final key in keys) {
        final value = '${record[key] ?? ''}'.trim();
        if (value.isNotEmpty && value != 'null') return value;
      }
      return '—';
    }
    final rawType = first(const <String>['type', 'record_type', 'category', 'event_type']);
    final type = rawType == '—' ? sectionTitle : rawType;
    final status = first(const <String>['status', 'mark', 'attendance_status', 'rating']);
    final author = first(const <String>['author', 'created_by_name', 'trainer_name', 'coach_name', 'created_by', 'trainer_id']);
    final updated = first(const <String>['updated_at', 'uploaded_at', 'created_at']);
    final team = first(const <String>['team_name', 'teamName', 'team_id']);
    final file = first(const <String>['file_name', 'filename', 'title', 'file_url', 'file', 'url', 'document_url', 'pdf_url']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [const _FileGlyph(size: 38), const SizedBox(width: 10), Expanded(child: Text('Свойства', style: AppTypography.sectionTitle(color: _WorkspacePlayerSectionBrowserState._text)))]),
        const SizedBox(height: 16),
        Text(title, style: AppTypography.itemTitle(color: _WorkspacePlayerSectionBrowserState._text)),
        const SizedBox(height: 14),
        _Prop(label: 'Дата', value: date),
        _Prop(label: 'Тип', value: type),
        if (status != '—' && status != type) _Prop(label: 'Статус / оценка', value: status),
        if (team != '—') _Prop(label: 'Команда', value: team),
        if (author != '—') _Prop(label: 'Автор / создал', value: author),
        if (updated != '—') _Prop(label: 'Обновлено', value: updated),
        if (file != '—') _Prop(label: 'Файл', value: file),
        if (onOpen != null) const Spacer() else const SizedBox(height: 8),
        if (onOpen != null)
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(backgroundColor: _WorkspacePlayerSectionBrowserState._green),
            child: Text('Открыть', style: AppTypography.actionStrong(color: Colors.white)),
          ),
      ],
    );
  }
}

class _Prop extends StatelessWidget {
  const _Prop({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTypography.caption(color: _WorkspacePlayerSectionBrowserState._muted)),
          const SizedBox(height: 3),
          Text(value, maxLines: 4, overflow: TextOverflow.ellipsis, style: AppTypography.secondaryMedium(color: _WorkspacePlayerSectionBrowserState._text)),
        ]),
      );
}

class _InspectorEmpty extends StatelessWidget {
  const _InspectorEmpty();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text('Выберите запись — свойства появятся здесь', textAlign: TextAlign.center, style: AppTypography.secondary(color: _WorkspacePlayerSectionBrowserState._muted)),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canUpload, required this.canCreate, required this.onCreate, required this.onUpload});
  final bool canUpload;
  final bool canCreate;
  final VoidCallback onCreate;
  final VoidCallback onUpload;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const _FileGlyph(size: 52),
            const SizedBox(height: 12),
            Text('Записей пока нет', style: AppTypography.sectionTitle(color: _WorkspacePlayerSectionBrowserState._text)),
            const SizedBox(height: 5),
            Text(
              canUpload
                  ? 'Перетащите сюда файл или добавьте его кнопкой сверху.'
                  : canCreate
                      ? 'Создайте первую запись дневника.'
                      : 'Когда в основном разделе появятся данные, они будут показаны здесь.',
              textAlign: TextAlign.center,
              style: AppTypography.secondary(color: _WorkspacePlayerSectionBrowserState._muted),
            ),
            if (canCreate) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onCreate,
                style: FilledButton.styleFrom(backgroundColor: _WorkspacePlayerSectionBrowserState._green, elevation: 0),
                child: Text('Новая заметка', style: AppTypography.actionStrong(color: Colors.white)),
              ),
            ],
            if (canUpload) ...[
              const SizedBox(height: 6),
              TextButton(onPressed: onUpload, child: Text('Добавить файл', style: AppTypography.actionStrong(color: _WorkspacePlayerSectionBrowserState._green))),
            ],
          ]),
        ),
      );
}

class _FileGlyph extends StatelessWidget {
  const _FileGlyph({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _RecordGlyphPainter(_WorkspacePlayerSectionBrowserState._green));
}

class _RecordGlyph extends StatelessWidget {
  const _RecordGlyph({required this.section, required this.size});
  final WorkspacePlayerSection section;
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _RecordGlyphPainter(_WorkspacePlayerSectionBrowserState._green, section: section));
}

class _RecordGlyphPainter extends CustomPainter {
  const _RecordGlyphPainter(this.color, {this.section});
  final Color color;
  final WorkspacePlayerSection? section;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.55..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = color;
    final fill = Paint()..style = PaintingStyle.fill..color = color.withOpacity(.06);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(size.width*.18, size.height*.08, size.width*.64, size.height*.82), Radius.circular(size.width*.08));
    canvas.drawRRect(r, fill);
    canvas.drawRRect(r, p);
    final x = size.width*.60;
    canvas.drawLine(Offset(x, size.height*.08), Offset(x, size.height*.28), p);
    canvas.drawLine(Offset(x, size.height*.28), Offset(size.width*.82, size.height*.28), p);
    canvas.drawLine(Offset(size.width*.31, size.height*.48), Offset(size.width*.69, size.height*.48), p);
    canvas.drawLine(Offset(size.width*.31, size.height*.61), Offset(size.width*.64, size.height*.61), p);
    if (section == WorkspacePlayerSection.health) {
      canvas.drawLine(Offset(size.width*.40, size.height*.75), Offset(size.width*.60, size.height*.75), p);
      canvas.drawLine(Offset(size.width*.50, size.height*.65), Offset(size.width*.50, size.height*.84), p);
    }
  }
  @override
  bool shouldRepaint(covariant _RecordGlyphPainter oldDelegate) => oldDelegate.color != color || oldDelegate.section != section;
}

enum _SortMode { newest, oldest, title }
enum _ContextAction { open, duplicate, properties, delete }
