import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/plans/pdf_preview_screen.dart';
import 'package:sportoteka/presentation/plans/plan_detail_screen.dart';
import 'package:sportoteka/presentation/plans/plan_exporter.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_server_storage.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_root_data_bridge.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';

enum WorkspaceLiveBlockType { plan, match, training, player, tracker, testing, video, document }

class WorkspaceLiveBlock {
  const WorkspaceLiveBlock({
    required this.type,
    required this.entityId,
    required this.title,
    this.subtitle = '',
    this.date = '',
    this.snapshotExportId,
    this.snapshotUrl = '',
    this.snapshotFileName = '',
    this.snapshotAt = '',
    this.entityKey = '',
    this.moduleKey = '',
    this.meta = const <String, dynamic>{},
  });

  final WorkspaceLiveBlockType type;
  final int entityId;
  final String entityKey;
  final String moduleKey;
  final Map<String, dynamic> meta;
  final String title;
  final String subtitle;
  final String date;
  final int? snapshotExportId;
  final String snapshotUrl;
  final String snapshotFileName;
  final String snapshotAt;

  WorkspaceLiveBlock copyWith({
    String? title,
    String? subtitle,
    String? date,
    int? snapshotExportId,
    String? snapshotUrl,
    String? snapshotFileName,
    String? snapshotAt,
    String? entityKey,
    String? moduleKey,
    Map<String, dynamic>? meta,
  }) {
    return WorkspaceLiveBlock(
      type: type,
      entityId: entityId,
      entityKey: entityKey ?? this.entityKey,
      moduleKey: moduleKey ?? this.moduleKey,
      meta: meta ?? this.meta,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      date: date ?? this.date,
      snapshotExportId: snapshotExportId ?? this.snapshotExportId,
      snapshotUrl: snapshotUrl ?? this.snapshotUrl,
      snapshotFileName: snapshotFileName ?? this.snapshotFileName,
      snapshotAt: snapshotAt ?? this.snapshotAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.name,
        'entity_id': entityId,
        if (entityKey.isNotEmpty) 'entity_key': entityKey,
        if (moduleKey.isNotEmpty) 'module_key': moduleKey,
        if (meta.isNotEmpty) 'meta': meta,
        'title': title,
        'subtitle': subtitle,
        'date': date,
        if (snapshotExportId != null) 'snapshot_export_id': snapshotExportId,
        if (snapshotUrl.isNotEmpty) 'snapshot_url': snapshotUrl,
        if (snapshotFileName.isNotEmpty) 'snapshot_file_name': snapshotFileName,
        if (snapshotAt.isNotEmpty) 'snapshot_at': snapshotAt,
      };

  static WorkspaceLiveBlock? fromJson(Map<String, dynamic> json) {
    final typeName = '${json['type'] ?? ''}'.trim();
    final type = WorkspaceLiveBlockType.values.where((e) => e.name == typeName).firstOrNull;
    final id = _asInt(json['entity_id'] ?? json['id']);
    final entityKey = '${json['entity_key'] ?? ''}'.trim();
    if (type == null || (id <= 0 && entityKey.isEmpty)) return null;
    final rawMeta = json['meta'];
    return WorkspaceLiveBlock(
      type: type,
      entityId: id,
      entityKey: entityKey,
      moduleKey: '${json['module_key'] ?? ''}'.trim(),
      meta: rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : const <String, dynamic>{},
      title: '${json['title'] ?? _defaultTitle(type)}'.trim(),
      subtitle: '${json['subtitle'] ?? ''}'.trim(),
      date: '${json['date'] ?? ''}'.trim(),
      snapshotExportId: _asNullableInt(json['snapshot_export_id']),
      snapshotUrl: '${json['snapshot_url'] ?? ''}'.trim(),
      snapshotFileName: '${json['snapshot_file_name'] ?? ''}'.trim(),
      snapshotAt: '${json['snapshot_at'] ?? ''}'.trim(),
    );
  }

  static String _defaultTitle(WorkspaceLiveBlockType type) {
    switch (type) {
      case WorkspaceLiveBlockType.plan: return 'План-конспект';
      case WorkspaceLiveBlockType.match: return 'Матч';
      case WorkspaceLiveBlockType.training: return 'Тренировка';
      case WorkspaceLiveBlockType.player: return 'Игрок';
      case WorkspaceLiveBlockType.tracker: return 'Tracker';
      case WorkspaceLiveBlockType.testing: return 'Тестирование';
      case WorkspaceLiveBlockType.video: return 'Видео';
      case WorkspaceLiveBlockType.document: return 'Документ';
    }
  }

  static int _asInt(dynamic value) => int.tryParse('${value ?? ''}'.trim()) ?? 0;
  static int? _asNullableInt(dynamic value) {
    final parsed = _asInt(value);
    return parsed > 0 ? parsed : null;
  }
}

class WorkspaceLiveBlocksRepository {
  WorkspaceLiveBlocksRepository({required this.documentKey});

  final String documentKey;

  static String _prefsKey(String key) => 'sportoteka_workspace_live_blocks_v1_$key';

  Future<List<WorkspaceLiveBlock>> load() async {
    final prefs = await SharedPreferences.getInstance();
    List<WorkspaceLiveBlock> local = _decode(prefs.getString(_prefsKey(documentKey)) ?? '');

    final clubId = await PrefUtils.getUserClubId() ?? 0;
    final userId = await PrefUtils.getUserId() ?? 0;
    if (clubId <= 0) return local;

    try {
      final storage = WorkspaceServerStorage(clubId: clubId, userId: userId);
      final raw = await storage.loadLiveBlocks(documentKey);
      final server = _decode(raw);
      if (server.isNotEmpty) {
        await prefs.setString(_prefsKey(documentKey), raw);
        return server;
      }
      if (raw.trim() == '[]' && local.isNotEmpty) {
        await storage.saveLiveBlocks(documentKey: documentKey, blocksJson: jsonEncode(local.map((e) => e.toJson()).toList()));
        return local;
      }
      if (raw.trim() == '[]') return <WorkspaceLiveBlock>[];
    } catch (_) {}
    return local;
  }

  Future<void> save(List<WorkspaceLiveBlock> blocks) async {
    final raw = jsonEncode(blocks.map((e) => e.toJson()).toList());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(documentKey), raw);

    final clubId = await PrefUtils.getUserClubId() ?? 0;
    final userId = await PrefUtils.getUserId() ?? 0;
    if (clubId <= 0) return;
    try {
      final storage = WorkspaceServerStorage(clubId: clubId, userId: userId);
      await storage.saveLiveBlocks(documentKey: documentKey, blocksJson: raw);
    } catch (_) {
      // Local cache remains authoritative until Phase 26 server API is deployed.
    }
  }

  static List<WorkspaceLiveBlock> _decode(String raw) {
    if (raw.trim().isEmpty) return <WorkspaceLiveBlock>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <WorkspaceLiveBlock>[];
      return decoded
          .whereType<Map>()
          .map((e) => WorkspaceLiveBlock.fromJson(Map<String, dynamic>.from(e)))
          .whereType<WorkspaceLiveBlock>()
          .toList();
    } catch (_) {
      return <WorkspaceLiveBlock>[];
    }
  }
}


class WorkspaceLiveBlockRuntime {
  static int clubId = 0;
  static List<Map<String, dynamic>> teams = const <Map<String, dynamic>>[];
  static List<Map<String, dynamic>> players = const <Map<String, dynamic>>[];
  static List<Map<String, dynamic>> trainers = const <Map<String, dynamic>>[];
  static int? selectedTeamId;
  static String selectedTeamName = '';
  static ValueChanged<String>? onOpenModule;
  static Future<void> Function(Map<String, dynamic> player)? onOpenPlayer;

  static void configure({
    required int clubIdValue,
    required List<Map<String, dynamic>> teamsValue,
    required List<Map<String, dynamic>> playersValue,
    required List<Map<String, dynamic>> trainersValue,
    int? selectedTeamIdValue,
    String selectedTeamNameValue = '',
    ValueChanged<String>? onOpenModuleValue,
    Future<void> Function(Map<String, dynamic> player)? onOpenPlayerValue,
  }) {
    clubId = clubIdValue;
    teams = teamsValue;
    players = playersValue;
    trainers = trainersValue;
    selectedTeamId = selectedTeamIdValue;
    selectedTeamName = selectedTeamNameValue;
    onOpenModule = onOpenModuleValue;
    onOpenPlayer = onOpenPlayerValue;
  }
}

class WorkspaceLiveBlockContext extends InheritedWidget {
  const WorkspaceLiveBlockContext({
    super.key,
    required super.child,
    required this.clubId,
    required this.teams,
    required this.players,
    required this.trainers,
    this.selectedTeamId,
    this.selectedTeamName = '',
    this.onOpenModule,
    this.onOpenPlayer,
  });

  final int clubId;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> trainers;
  final int? selectedTeamId;
  final String selectedTeamName;
  final ValueChanged<String>? onOpenModule;
  final Future<void> Function(Map<String, dynamic> player)? onOpenPlayer;

  static WorkspaceLiveBlockContext? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceLiveBlockContext>();

  @override
  bool updateShouldNotify(covariant WorkspaceLiveBlockContext oldWidget) =>
      clubId != oldWidget.clubId ||
      selectedTeamId != oldWidget.selectedTeamId ||
      selectedTeamName != oldWidget.selectedTeamName ||
      teams.length != oldWidget.teams.length ||
      players.length != oldWidget.players.length ||
      trainers.length != oldWidget.trainers.length;
}

Future<WorkspaceLiveBlock?> showWorkspaceLiveBlockPicker(
  BuildContext context,
  WorkspaceLiveBlockType type,
) async {
  if (type == WorkspaceLiveBlockType.plan) return showWorkspacePlanPicker(context);
  return showModalBottomSheet<WorkspaceLiveBlock>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WorkspaceGenericBlockPickerSheet(type: type),
  );
}


/// Встроенный picker для Sportoteka OS. На планшете/desktop редактор может
/// показывать его справа внутри того же окна, без route/dialog/bottom sheet.
class WorkspaceLiveBlockPickerPane extends StatelessWidget {
  const WorkspaceLiveBlockPickerPane({
    super.key,
    required this.type,
    required this.onSelected,
    required this.onClose,
  });

  final WorkspaceLiveBlockType type;
  final ValueChanged<WorkspaceLiveBlock> onSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final child = type == WorkspaceLiveBlockType.plan
        ? _WorkspacePlanPickerSheet(
            embedded: true,
            onSelected: onSelected,
            onClose: onClose,
          )
        : _WorkspaceGenericBlockPickerSheet(
            type: type,
            embedded: true,
            onSelected: onSelected,
            onClose: onClose,
          );

    // Picker живёт внутри самописного OS-окна, где выше по дереву может не быть
    // Material. TextField/ListTile требуют Material ancestor.
    return Material(
      color: Colors.white,
      child: child,
    );
  }
}

class _WorkspaceGenericBlockPickerSheet extends StatefulWidget {
  const _WorkspaceGenericBlockPickerSheet({
    required this.type,
    this.embedded = false,
    this.onSelected,
    this.onClose,
  });
  final WorkspaceLiveBlockType type;
  final bool embedded;
  final ValueChanged<WorkspaceLiveBlock>? onSelected;
  final VoidCallback? onClose;

  @override
  State<_WorkspaceGenericBlockPickerSheet> createState() => _WorkspaceGenericBlockPickerSheetState();
}

class _WorkspaceGenericBlockPickerSheetState extends State<_WorkspaceGenericBlockPickerSheet> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE6EAE7);

  final _search = TextEditingController();
  List<WorkspaceFinderNode> _nodes = <WorkspaceFinderNode>[];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _folderKey {
    switch (widget.type) {
      case WorkspaceLiveBlockType.match: return 'matches';
      case WorkspaceLiveBlockType.training: return 'trainings';
      case WorkspaceLiveBlockType.tracker: return 'tracker';
      case WorkspaceLiveBlockType.testing: return 'testing';
      case WorkspaceLiveBlockType.video: return 'video';
      case WorkspaceLiveBlockType.document: return 'documents';
      case WorkspaceLiveBlockType.player: return 'players';
      case WorkspaceLiveBlockType.plan: return 'plans';
    }
  }

  String get _title {
    switch (widget.type) {
      case WorkspaceLiveBlockType.match: return 'Вставить матч';
      case WorkspaceLiveBlockType.training: return 'Вставить тренировку';
      case WorkspaceLiveBlockType.player: return 'Вставить игрока';
      case WorkspaceLiveBlockType.tracker: return 'Вставить Tracker';
      case WorkspaceLiveBlockType.testing: return 'Вставить тестирование';
      case WorkspaceLiveBlockType.video: return 'Вставить видео';
      case WorkspaceLiveBlockType.document: return 'Вставить документ';
      case WorkspaceLiveBlockType.plan: return 'Вставить план-конспект';
    }
  }

  Future<void> _load() async {
    final scope = WorkspaceLiveBlockContext.maybeOf(context);
    final clubId = scope?.clubId ?? WorkspaceLiveBlockRuntime.clubId;
    final teams = scope?.teams ?? WorkspaceLiveBlockRuntime.teams;
    final players = scope?.players ?? WorkspaceLiveBlockRuntime.players;
    final trainers = scope?.trainers ?? WorkspaceLiveBlockRuntime.trainers;
    final selectedTeamId = scope?.selectedTeamId ?? WorkspaceLiveBlockRuntime.selectedTeamId;
    final selectedTeamName = scope?.selectedTeamName ?? WorkspaceLiveBlockRuntime.selectedTeamName;
    if (clubId <= 0 && players.isEmpty && teams.isEmpty) {
      if (mounted) setState(() { _loading = false; _error = 'Контекст Workspace пока недоступен.'; });
      return;
    }
    try {
      List<WorkspaceFinderNode> rows;
      if (widget.type == WorkspaceLiveBlockType.player) {
        rows = players.map((raw) {
          final player = Map<String, dynamic>.from(raw);
          final id = _entityId(player);
          final last = '${player['last_name'] ?? player['lastname'] ?? ''}'.trim();
          final first = '${player['first_name'] ?? player['firstname'] ?? ''}'.trim();
          final full = '${player['full_name'] ?? player['name'] ?? ''}'.trim();
          final title = <String>[last, first].where((e) => e.isNotEmpty).join(' ').trim();
          final team = '${player['team_name'] ?? player['teamName'] ?? ''}'.trim();
          final position = '${player['position'] ?? player['amplua'] ?? ''}'.trim();
          return WorkspaceFinderNode(
            id: 'live:player:$id',
            title: title.isNotEmpty ? title : (full.isEmpty ? 'Игрок' : full),
            subtitle: <String>[team, position].where((e) => e.isNotEmpty).join(' · '),
            kind: WorkspaceFinderNodeKind.player,
            moduleKey: 'players',
            payload: player,
            isSystem: true,
          );
        }).toList();
      } else {
        final bridge = WorkspaceRootDataBridge(
          clubId: clubId,
          teams: teams,
          players: players,
          trainers: trainers,
          selectedTeamId: selectedTeamId,
          selectedTeamName: selectedTeamName,
        );
        rows = await bridge.loadFolder(_folderKey);
      }
      if (!mounted) return;
      setState(() { _nodes = rows; _loading = false; _error = ''; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  List<WorkspaceFinderNode> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _nodes;
    return _nodes.where((node) => '${node.title} ${node.subtitle}'.toLowerCase().contains(q)).toList();
  }

  WorkspaceLiveBlock _blockFor(WorkspaceFinderNode node) {
    final payload = Map<String, dynamic>.from(node.payload ?? const <String, dynamic>{});
    final id = _entityId(payload);
    final meta = <String, dynamic>{};
    const keys = <String>[
      'team_name', 'position', 'amplua', 'number', 'shirt_number',
      'score', 'result', 'final_score', 'opponent', 'opponent_name',
      'location', 'venue', 'type', 'event_type', 'category', 'status',
      'distance_m', 'total_distance_m', 'max_speed_kmh', 'max_hr', 'avg_hr',
      'file_name', 'document_type', 'record_type', 'duration', 'duration_min',
      'player_name', 'trainer_name', 'title', 'name', 'url', 'file_url',
    ];
    for (final key in keys) {
      final value = payload[key];
      if (value != null && '$value'.trim().isNotEmpty && '$value'.toLowerCase() != 'null') meta[key] = value;
    }
    return WorkspaceLiveBlock(
      type: widget.type,
      entityId: id,
      entityKey: node.id,
      moduleKey: node.moduleKey ?? _folderKey,
      title: node.title,
      subtitle: node.subtitle,
      date: _friendlyNodeDate(node),
      meta: meta,
    );
  }

  void _finish(WorkspaceLiveBlock block) {
    if (widget.embedded) {
      widget.onSelected?.call(block);
    } else {
      Navigator.of(context).pop(block);
    }
  }

  void _close() {
    if (widget.embedded) {
      widget.onClose?.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * .78;
    final panel = Container(
          height: widget.embedded ? double.infinity : height.clamp(420, 720).toDouble(),
          constraints: widget.embedded ? const BoxConstraints() : const BoxConstraints(maxWidth: 780),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: widget.embedded ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(18)),
            border: widget.embedded ? const Border(left: BorderSide(color: _line)) : null,
          ),
          child: Column(
            children: [
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
                child: Row(children: [
                  const _BrandDotsTile(size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_title, style: AppTypography.sectionTitle(color: _text))),
                  IconButton(onPressed: _close, icon: const Icon(Icons.close_rounded, size: 20, color: _muted)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _search,
                  style: AppTypography.formText(color: _text),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Поиск…',
                    hintStyle: AppTypography.formHint(color: _muted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF4F6F4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _green))
                    : _error.isNotEmpty
                        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error, textAlign: TextAlign.center, style: AppTypography.secondary(color: _muted))))
                        : _visible.isEmpty
                            ? Center(child: Text('Ничего не найдено', style: AppTypography.secondary(color: _muted)))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                                itemCount: _visible.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, indent: 48, color: _line),
                                itemBuilder: (_, index) {
                                  final node = _visible[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    leading: const _BrandDotsTile(),
                                    title: Text(node.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _text)),
                                    subtitle: node.subtitle.isEmpty ? null : Text(node.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.secondary(color: _muted)),
                                    onTap: () => _finish(_blockFor(node)),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
    if (widget.embedded) {
      return Material(color: Colors.white, child: panel);
    }
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: panel,
      ),
    );
  }
}

int _entityId(Map<String, dynamic> row) {
  for (final key in const <String>['id', 'player_id', 'match_id', 'event_id', 'session_id', 'test_id', 'plan_id', 'document_id', 'record_id']) {
    final value = int.tryParse('${row[key] ?? ''}'.trim()) ?? 0;
    if (value > 0) return value;
  }
  return 0;
}

String _friendlyNodeDate(WorkspaceFinderNode node) {
  final date = node.updatedAt ?? node.createdAt;
  if (date == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}

SportotekaWorkspaceIconKind _iconForType(WorkspaceLiveBlockType type) {
  switch (type) {
    case WorkspaceLiveBlockType.plan: return SportotekaWorkspaceIconKind.plans;
    case WorkspaceLiveBlockType.match: return SportotekaWorkspaceIconKind.matches;
    case WorkspaceLiveBlockType.training: return SportotekaWorkspaceIconKind.trainings;
    case WorkspaceLiveBlockType.player: return SportotekaWorkspaceIconKind.players;
    case WorkspaceLiveBlockType.tracker: return SportotekaWorkspaceIconKind.tracker;
    case WorkspaceLiveBlockType.testing: return SportotekaWorkspaceIconKind.testing;
    case WorkspaceLiveBlockType.video: return SportotekaWorkspaceIconKind.video;
    case WorkspaceLiveBlockType.document: return SportotekaWorkspaceIconKind.documents;
  }
}

String _labelForType(WorkspaceLiveBlockType type) {
  switch (type) {
    case WorkspaceLiveBlockType.plan: return 'ПЛАН-КОНСПЕКТ';
    case WorkspaceLiveBlockType.match: return 'МАТЧ';
    case WorkspaceLiveBlockType.training: return 'ТРЕНИРОВКА';
    case WorkspaceLiveBlockType.player: return 'ИГРОК';
    case WorkspaceLiveBlockType.tracker: return 'TRACKER';
    case WorkspaceLiveBlockType.testing: return 'ТЕСТИРОВАНИЕ';
    case WorkspaceLiveBlockType.video: return 'ВИДЕО';
    case WorkspaceLiveBlockType.document: return 'ДОКУМЕНТ';
  }
}

Future<WorkspaceLiveBlock?> showWorkspacePlanPicker(BuildContext context) async {
  return showModalBottomSheet<WorkspaceLiveBlock>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WorkspacePlanPickerSheet(),
  );
}

class _WorkspacePlanPickerSheet extends StatefulWidget {
  const _WorkspacePlanPickerSheet({
    this.embedded = false,
    this.onSelected,
    this.onClose,
  });

  final bool embedded;
  final ValueChanged<WorkspaceLiveBlock>? onSelected;
  final VoidCallback? onClose;

  @override
  State<_WorkspacePlanPickerSheet> createState() => _WorkspacePlanPickerSheetState();
}

class _WorkspacePlanPickerSheetState extends State<_WorkspacePlanPickerSheet> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE6EAE7);

  final _search = TextEditingController();
  List<Map<String, dynamic>> _plans = <Map<String, dynamic>>[];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final clubId = await PrefUtils.getUserClubId() ?? 0;
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_latest_training_plans.php').replace(
        queryParameters: <String, String>{
          if (clubId > 0) 'club_id': '$clubId',
          'limit': '500',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      final rows = _rows(decoded);
      rows.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
      if (!mounted) return;
      setState(() {
        _plans = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _plans;
    return _plans.where((row) {
      final hay = <String>[
        _titleOf(row),
        '${row['team_name'] ?? row['team'] ?? ''}',
        '${row['trainer_name'] ?? row['coach_name'] ?? ''}',
        '${row['date'] ?? row['plan_date'] ?? ''}',
      ].join(' ').toLowerCase();
      return hay.contains(query);
    }).toList();
  }

  void _finish(WorkspaceLiveBlock block) {
    if (widget.embedded) {
      widget.onSelected?.call(block);
    } else {
      Navigator.of(context).pop(block);
    }
  }

  void _close() {
    if (widget.embedded) {
      widget.onClose?.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height * .78;
    final panel = Container(
          height: widget.embedded ? double.infinity : height,
          constraints: widget.embedded ? const BoxConstraints() : const BoxConstraints(maxWidth: 860),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: widget.embedded ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(20)),
            border: widget.embedded ? const Border(left: BorderSide(color: _line)) : null,
          ),
          child: Column(
            children: [
              if (!widget.embedded) ...[
                const SizedBox(height: 10),
                Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDE2DE), borderRadius: BorderRadius.circular(999))),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  children: [
                    const _BrandDotsTile(size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Вставить план-конспект', style: AppTypography.screenTitle(color: _text)),
                          const SizedBox(height: 2),
                          Text('Выберите реальный план — в документ вставится живая ссылка на него.', style: AppTypography.secondary(color: _muted)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _close, icon: const Icon(Icons.close_rounded, size: 20, color: _muted)),
                  ],
                ),
              ),
              const Divider(height: 1, color: _line),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _search,
                  style: AppTypography.formText(color: _text),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Поиск по теме, команде, тренеру, дате…',
                    hintStyle: AppTypography.formHint(color: _muted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF4F6F4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _green))
                    : _error.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Не удалось загрузить планы', style: AppTypography.sectionTitle(color: _text)),
                                  const SizedBox(height: 6),
                                  Text(_error, textAlign: TextAlign.center, style: AppTypography.secondary(color: _muted)),
                                  const SizedBox(height: 12),
                                  TextButton(onPressed: _load, child: Text('Повторить', style: AppTypography.actionStrong(color: _green))),
                                ],
                              ),
                            ),
                          )
                        : _visible.isEmpty
                            ? Center(child: Text('Планы не найдены', style: AppTypography.secondary(color: _muted)))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                                itemCount: _visible.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, indent: 54, color: _line),
                                itemBuilder: (_, index) {
                                  final row = _visible[index];
                                  final id = _idOf(row);
                                  final title = _titleOf(row);
                                  final date = _friendlyDate('${row['date'] ?? row['plan_date'] ?? row['created_at'] ?? ''}');
                                  final team = '${row['team_name'] ?? row['team'] ?? ''}'.trim();
                                  final trainer = '${row['trainer_name'] ?? row['coach_name'] ?? row['trainer'] ?? ''}'.trim();
                                  final subtitle = <String>[if (team.isNotEmpty) team, if (trainer.isNotEmpty) trainer].join(' · ');
                                  return ListTile(
                                    enabled: id > 0,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    leading: const _BrandDotsTile(),
                                    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _text)),
                                    subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.secondary(color: _muted)),
                                    trailing: Text(date, style: AppTypography.captionMedium(color: _muted)),
                                    onTap: id <= 0
                                        ? null
                                        : () => _finish(
                                              WorkspaceLiveBlock(
                                                type: WorkspaceLiveBlockType.plan,
                                                entityId: id,
                                                title: title,
                                                subtitle: subtitle,
                                                date: date,
                                              ),
                                            ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
    if (widget.embedded) {
      return Material(color: Colors.white, child: panel);
    }
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: panel,
      ),
    );
  }

  static List<Map<String, dynamic>> _rows(dynamic decoded) {
    if (decoded is List) return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (decoded is Map) {
      for (final key in const <String>['plans', 'items', 'data', 'result', 'rows']) {
        final raw = decoded[key];
        if (raw is List) return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  static int _idOf(Map<String, dynamic> row) => int.tryParse('${row['plan_id'] ?? row['id'] ?? ''}'.trim()) ?? 0;
  static String _titleOf(Map<String, dynamic> row) {
    final value = '${row['theme'] ?? row['title'] ?? row['name'] ?? 'План-конспект'}'.trim();
    return value.isEmpty ? 'План-конспект' : value;
  }

  static DateTime _dateOf(Map<String, dynamic> row) {
    final raw = '${row['date'] ?? row['plan_date'] ?? row['updated_at'] ?? row['created_at'] ?? ''}'.trim().replaceFirst(' ', 'T');
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _friendlyDate(String raw) {
    final parsed = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
    if (parsed == null) return raw.trim();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year}';
  }
}

class WorkspaceLiveBlockCard extends StatefulWidget {
  const WorkspaceLiveBlockCard({
    super.key,
    required this.block,
    required this.onChanged,
    required this.onRemove,
    this.readOnly = false,
  });

  final WorkspaceLiveBlock block;
  final ValueChanged<WorkspaceLiveBlock> onChanged;
  final VoidCallback onRemove;
  final bool readOnly;

  @override
  State<WorkspaceLiveBlockCard> createState() => _WorkspaceLiveBlockCardState();
}

class _WorkspaceLiveBlockCardState extends State<WorkspaceLiveBlockCard> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE4E9E5);

  bool _loadingPdf = false;
  Map<String, dynamic>? _detail;
  bool _detailLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshDetail();
  }

  @override
  void didUpdateWidget(covariant WorkspaceLiveBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.entityId != widget.block.entityId) _refreshDetail();
  }

  Future<void> _refreshDetail() async {
    if (widget.block.type != WorkspaceLiveBlockType.plan || _detailLoading) return;
    _detailLoading = true;
    try {
      final data = await PlanApi.getPlan(widget.block.entityId);
      if (!mounted) return;
      setState(() => _detail = data);
    } catch (_) {
      // The cached block title still remains usable offline.
    } finally {
      _detailLoading = false;
    }
  }

  Map<String, dynamic> get _plan {
    final raw = _detail?['plan'] ?? _detail?['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> get _exercises {
    final raw = _detail?['exercises'] ?? _detail?['items'];
    return raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
  }

  String get _title {
    final value = '${_plan['theme'] ?? widget.block.title}'.trim();
    return value.isEmpty ? 'План-конспект' : value;
  }

  String get _date {
    final raw = '${_plan['date'] ?? _plan['plan_date'] ?? widget.block.date}'.trim();
    return _friendlyDate(raw);
  }

  String get _team => '${_plan['team_name'] ?? _plan['team'] ?? widget.block.subtitle.split(' · ').firstOrNull ?? ''}'.trim();
  int get _duration => int.tryParse('${_plan['duration_min'] ?? _plan['duration'] ?? ''}'.trim()) ?? 0;
  int get _players => int.tryParse('${_plan['players_count'] ?? _plan['players'] ?? ''}'.trim()) ?? 0;

  Future<void> _openPlan() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlanDetailScreen(
          initialArgs: <String, dynamic>{
            'planId': widget.block.entityId,
            if (_plan['team_id'] != null) 'teamId': _plan['team_id'],
            if (_team.isNotEmpty) 'teamName': _team,
          },
        ),
      ),
    );
    await _refreshDetail();
  }

  Future<void> _handlePdf() async {
    if (_loadingPdf) return;
    if (widget.block.snapshotUrl.isNotEmpty) {
      await _openSnapshot(widget.block.snapshotUrl, widget.block.snapshotFileName);
      return;
    }
    await _createSnapshot();
  }

  Future<void> _createSnapshot() async {
    setState(() => _loadingPdf = true);
    try {
      final detail = _detail ?? await PlanApi.getPlan(widget.block.entityId);
      final planRaw = detail['plan'] ?? detail['data'] ?? <String, dynamic>{};
      final plan = planRaw is Map ? Map<String, dynamic>.from(planRaw) : <String, dynamic>{};
      final goalsRaw = plan['goals'];
      final goals = goalsRaw is Map ? Map<String, dynamic>.from(goalsRaw) : <String, dynamic>{};
      final exRaw = detail['exercises'] ?? detail['items'] ?? <dynamic>[];
      final exercises = exRaw is List ? exRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

      final header = <String, dynamic>{
        'cycle': '${plan['cycle_title'] ?? plan['cycle'] ?? ''}',
        'date': '${plan['date'] ?? plan['plan_date'] ?? ''}',
        'location': '${plan['location'] ?? ''}',
        'theme': '${plan['theme'] ?? widget.block.title}',
        'goal_tech': '${goals['technique'] ?? plan['goal_tech'] ?? ''}',
        'goal_tact': '${goals['tactics'] ?? plan['goal_tact'] ?? ''}',
        'goal_fit': '${goals['fitness'] ?? plan['goal_fit'] ?? ''}',
        'goal_ment': '${goals['mentality'] ?? plan['goal_ment'] ?? ''}',
        'equipment': plan['equipment'] ?? '',
      };

      Uint8List? logo;
      try {
        final bytes = await rootBundle.load('assets/icons/logofc.png');
        logo = bytes.buffer.asUint8List();
      } catch (_) {}

      final clubName = '${plan['club_name'] ?? plan['club'] ?? 'Клуб'}'.trim();
      final teamName = '${plan['team_name'] ?? plan['team'] ?? 'Команда'}'.trim();
      final trainerName = '${plan['trainer_name'] ?? plan['coach_name'] ?? plan['trainer'] ?? 'Тренер'}'.trim();
      final playersCount = int.tryParse('${plan['players_count'] ?? 0}') ?? 0;
      final durationMin = int.tryParse('${plan['duration_min'] ?? 90}') ?? 90;
      final signedRole = '${plan['signed_role'] ?? 'Тренер'}'.trim();
      final signedBy = '${plan['signed_by'] ?? trainerName}'.trim();

      final pdfBytes = await PlanExporter.buildPlanPdf(
        header: header,
        exercises: exercises,
        clubName: clubName,
        trainerName: trainerName,
        teamName: teamName,
        playersCount: playersCount,
        durationMin: durationMin,
        signedRole: signedRole,
        signedBy: signedBy,
        clubLogoBytes: logo,
      );

      final clubId = int.tryParse('${plan['club_id'] ?? ''}') ?? (await PrefUtils.getUserClubId() ?? 0);
      final teamId = int.tryParse('${plan['team_id'] ?? ''}') ?? 0;
      final userId = await PrefUtils.getUserId() ?? 0;
      final fileName = 'plan_${widget.block.entityId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      if (clubId > 0 && userId > 0) {
        await PlanExportsApi.uploadExport(
          clubId: clubId,
          teamId: teamId,
          planId: widget.block.entityId,
          createdBy: userId,
          format: 'pdf',
          bytes: pdfBytes,
          filename: fileName,
        );

        try {
          final listed = await PlanExportsApi.listExports(planId: widget.block.entityId, userId: userId);
          final itemsRaw = listed['items'] ?? listed['exports'] ?? listed['data'];
          if (itemsRaw is List && itemsRaw.isNotEmpty) {
            final items = itemsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
            items.sort((a, b) => _sortExportDate(b).compareTo(_sortExportDate(a)));
            final newest = items.first;
            final url = '${newest['secure_url'] ?? newest['url'] ?? ''}'.trim();
            final exportId = int.tryParse('${newest['id'] ?? newest['export_id'] ?? ''}'.trim());
            final actualName = '${newest['file_name'] ?? newest['filename'] ?? fileName}'.trim();
            widget.onChanged(
              widget.block.copyWith(
                title: _title,
                subtitle: <String>[if (_team.isNotEmpty) _team, if (_duration > 0) '$_duration мин'].join(' · '),
                date: _date,
                snapshotExportId: exportId,
                snapshotUrl: url,
                snapshotFileName: actualName,
                snapshotAt: DateTime.now().toIso8601String(),
              ),
            );
          }
        } catch (_) {}
      }

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PdfPreviewScreen(fileName: fileName, buildPdf: (_) async => pdfBytes),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось создать PDF: $e')));
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  Future<void> _openSnapshot(String url, String name) async {
    try {
      final absolute = url.startsWith('http://') || url.startsWith('https://')
          ? url
          : 'https://sportotekaapp.ru/${url.replaceFirst(RegExp(r'^/+'), '')}';
      final response = await http.get(Uri.parse(absolute)).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('HTTP ${response.statusCode}');
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PdfPreviewScreen(
            fileName: name.isEmpty ? 'plan_${widget.block.entityId}.pdf' : name,
            buildPdf: (_) async => response.bodyBytes,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть PDF: $e')));
    }
  }


  Future<void> _openGeneric() async {
    final scope = WorkspaceLiveBlockContext.maybeOf(context);
    final players = scope?.players ?? WorkspaceLiveBlockRuntime.players;
    final openPlayer = scope?.onOpenPlayer ?? WorkspaceLiveBlockRuntime.onOpenPlayer;
    final openModule = scope?.onOpenModule ?? WorkspaceLiveBlockRuntime.onOpenModule;
    if (widget.block.type == WorkspaceLiveBlockType.player && openPlayer != null) {
      Map<String, dynamic>? player;
      for (final raw in players) {
        if (_entityId(raw) == widget.block.entityId) { player = raw; break; }
      }
      if (player != null) {
        await openPlayer(Map<String, dynamic>.from(player));
        return;
      }
    }
    final module = widget.block.moduleKey.trim();
    if (module.isNotEmpty && openModule != null) openModule(module);
  }

  Widget _buildGenericCard(BuildContext context) {
    final block = widget.block;
    final lines = <String>[];
    if (block.date.isNotEmpty) lines.add(block.date);
    if (block.subtitle.isNotEmpty) lines.add(block.subtitle);
    final meta = block.meta;
    void addMetric(String label, List<String> keys, {String suffix = ''}) {
      for (final key in keys) {
        final raw = '${meta[key] ?? ''}'.trim();
        if (raw.isNotEmpty && raw.toLowerCase() != 'null') { lines.add('$label$raw$suffix'); return; }
      }
    }
    switch (block.type) {
      case WorkspaceLiveBlockType.match:
        addMetric('Счёт ', const <String>['score', 'result', 'final_score']);
        break;
      case WorkspaceLiveBlockType.training:
        addMetric('', const <String>['location', 'venue']);
        break;
      case WorkspaceLiveBlockType.player:
        addMetric('', const <String>['team_name']);
        addMetric('', const <String>['position', 'amplua']);
        addMetric('№', const <String>['number', 'shirt_number']);
        break;
      case WorkspaceLiveBlockType.tracker:
        addMetric('Дистанция ', const <String>['distance_m', 'total_distance_m'], suffix: ' м');
        addMetric('Max ', const <String>['max_speed_kmh'], suffix: ' км/ч');
        addMetric('ЧСС ', const <String>['max_hr']);
        break;
      case WorkspaceLiveBlockType.testing:
        addMetric('', const <String>['category', 'type']);
        addMetric('', const <String>['status']);
        break;
      case WorkspaceLiveBlockType.video:
        break;
      case WorkspaceLiveBlockType.document:
        addMetric('', const <String>['document_type', 'record_type', 'file_name']);
        break;
      case WorkspaceLiveBlockType.plan:
        break;
    }
    final unique = <String>[];
    for (final line in lines) { if (line.trim().isNotEmpty && !unique.contains(line.trim())) unique.add(line.trim()); }
    final scope = WorkspaceLiveBlockContext.maybeOf(context);
    final openPlayer = scope?.onOpenPlayer ?? WorkspaceLiveBlockRuntime.onOpenPlayer;
    final openModule = scope?.onOpenModule ?? WorkspaceLiveBlockRuntime.onOpenModule;
    final canOpen = (block.type == WorkspaceLiveBlockType.player && openPlayer != null) || (block.moduleKey.isNotEmpty && openModule != null);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 10, 11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: _line)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: const Color(0xFFEAF5EF), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: SportotekaWorkspaceIcon(kind: _iconForType(block.type), size: 24, color: _green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text(_labelForType(block.type), style: AppTypography.menuGroup(color: _green)), const SizedBox(width: 7), const _BrandDots()]),
              const SizedBox(height: 5),
              Text(block.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _text)),
              if (unique.isNotEmpty) ...[const SizedBox(height: 4), Text(unique.take(4).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.secondary(color: _muted))],
            ]),
          ),
          if (canOpen) TextButton(onPressed: _openGeneric, child: Text(block.type == WorkspaceLiveBlockType.player ? 'Открыть' : 'Раздел', style: AppTypography.actionStrong(color: _green))),
          if (!widget.readOnly)
            PopupMenuButton<String>(
              tooltip: 'Ещё',
              color: Colors.white,
              onSelected: (value) { if (value == 'remove') widget.onRemove(); },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'remove', child: Text('Убрать из документа', style: AppTypography.menuTitle(color: const Color(0xFFB63A3A)))),
              ],
              icon: const Icon(Icons.more_horiz_rounded, size: 19, color: _muted),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.block.type != WorkspaceLiveBlockType.plan) return _buildGenericCard(context);
    final meta = <String>[
      if (_date.isNotEmpty) _date,
      if (_team.isNotEmpty) _team,
      if (_duration > 0) '$_duration мин',
      if (_players > 0) '$_players игроков',
      if (_exercises.isNotEmpty) '${_exercises.length} упражнений',
    ];
    final hasSnapshot = widget.block.snapshotUrl.isNotEmpty;

    Widget actions({required bool compact}) => Wrap(
          spacing: compact ? 2 : 4,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(onPressed: _openPlan, child: Text('Открыть', style: AppTypography.actionStrong(color: _green))),
            TextButton(
              onPressed: _loadingPdf ? null : _handlePdf,
              child: Text(_loadingPdf ? 'PDF…' : 'PDF', style: AppTypography.actionStrong(color: _green)),
            ),
            if (!widget.readOnly)
              PopupMenuButton<String>(
                tooltip: 'Ещё',
                color: Colors.white,
                onSelected: (value) {
                  if (value == 'refresh_pdf') _createSnapshot();
                  if (value == 'remove') widget.onRemove();
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'refresh_pdf', child: Text(hasSnapshot ? 'Зафиксировать PDF заново' : 'Зафиксировать PDF', style: AppTypography.menuTitle())),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(value: 'remove', child: Text('Убрать из документа', style: AppTypography.menuTitle(color: const Color(0xFFB63A3A)))),
                ],
              ),
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('ПЛАН-КОНСПЕКТ', style: AppTypography.menuGroup(color: _green)),
                const SizedBox(width: 7),
                const _BrandDots(),
                if (hasSnapshot) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE8F4ED), borderRadius: BorderRadius.circular(999)),
                    child: Text('PDF сохранён', style: AppTypography.captionMedium(color: _green)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Text(_title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _text)),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(meta.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.secondary(color: _muted)),
            ],
          ],
        );

        return Container(
          padding: EdgeInsets.fromLTRB(compact ? 11 : 14, 12, compact ? 9 : 12, 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAF8),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _line),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const _BrandDotsTile(size: 38), const SizedBox(width: 10), Expanded(child: content)]),
                    const SizedBox(height: 7),
                    Align(alignment: Alignment.centerRight, child: actions(compact: true)),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _BrandDotsTile(size: 42),
                    const SizedBox(width: 12),
                    Expanded(child: content),
                    const SizedBox(width: 10),
                    actions(compact: false),
                  ],
                ),
        );
      },
    );
  }

  static DateTime _sortExportDate(Map<String, dynamic> row) {
    final raw = '${row['created_at'] ?? row['date'] ?? ''}'.trim().replaceFirst(' ', 'T');
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _friendlyDate(String raw) {
    final parsed = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
    if (parsed == null) return raw.trim();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year}';
  }
}


class _BrandDotsTile extends StatelessWidget {
  const _BrandDotsTile({this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F8F4),
          borderRadius: BorderRadius.circular(size * .28),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _BrandDot(),
              SizedBox(width: 3),
              _BrandDot(),
              SizedBox(width: 3),
              _BrandDot(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandDot extends StatelessWidget {
  const _BrandDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 4.2,
        height: 4.2,
        decoration: const BoxDecoration(
          color: Color(0xFF0B8F55),
          shape: BoxShape.circle,
        ),
      );
}

class _BrandDots extends StatelessWidget {
  const _BrandDots();
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: index == 1 ? const Color(0xFF17A36A) : const Color(0xFFB8D9C6), shape: BoxShape.circle),
            ),
          ),
        ),
      );
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
