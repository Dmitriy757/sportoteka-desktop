// lib/presentation/plans/cmr_plans_panel.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/plans/plan_detail_screen.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/presentation/plans/api/training_graphics_api.dart';

class CmrPlansPanel extends StatefulWidget {
  final int clubId;
  final String clubName;
  final int? teamId;
  final String teamName;

  /// ВАЖНО:
  /// Используй это, чтобы кнопка назад возвращала не в профиль,
  /// а обратно в меню CMR.
  final VoidCallback? onBackToMenu;

  const CmrPlansPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teamId,
    required this.teamName,
    this.onBackToMenu,
  });

  @override
  State<CmrPlansPanel> createState() => _CmrPlansPanelState();
}

class _CmrPlansPanelState extends State<CmrPlansPanel> {
  bool loading = true;
  bool saving = false;
  String? error;

  int? selectedFolderId;
  String selectedFolderTitle = 'Все материалы';

  List<Map<String, dynamic>> folders = [];
  List<Map<String, dynamic>> _allFolders = [];

  List<Map<String, dynamic>> plans = [];
  List<Map<String, dynamic>> graphics = [];
  List<Map<String, dynamic>> files = [];
  bool loadingMaterials = false;
  String? materialsError;

  Map<String, dynamic>? selectedPlan;

  final TextEditingController searchCtrl = TextEditingController();
  final TextEditingController themeCtrl = TextEditingController();
  final TextEditingController cycleCtrl = TextEditingController();
  final TextEditingController descriptionCtrl = TextEditingController();
  final TextEditingController dateCtrl = TextEditingController();

  bool editMode = false;
  bool showFoldersList = false;
  final Set<int> _expandedFolderIds = <int>{};

  int get _activeFolderId => selectedFolderId ?? 0;

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? 0}') ?? 0;
  }

  String _asStr(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  List<Map<String, dynamic>> _itemsFromResponse(Map<String, dynamic> r) {
    final raw = (r['items'] as List?) ??
        (r['data'] as List?) ??
        (r['files'] as List?) ??
        (r['graphics'] as List?) ??
        (r['schemes'] as List?) ??
        const [];

    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  bool get _hasTeam => widget.teamId != null && widget.teamId! > 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    themeCtrl.dispose();
    cycleCtrl.dispose();
    descriptionCtrl.dispose();
    dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final foldersResp = await PlanFoldersApi.list(
        clubId: widget.clubId,
      );

      if (foldersResp['success'] != true) {
        throw foldersResp['message'] ?? 'Не удалось загрузить папки';
      }

      _processFoldersResponse(foldersResp);

      await _loadPlansForTeam();

      if (!mounted) return;
      setState(() {
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  void _processFoldersResponse(Map<String, dynamic> response) {
    final tree = (response['tree'] as List?) ??
        (response['folders'] as List?) ??
        (response['data'] as List?) ??
        (response['items'] as List?) ??
        [];

    final flatFolders = <Map<String, dynamic>>[];

    void walk(List list, [int level = 0, int? parentId]) {
      for (final item in list) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);

          map['_level'] = level;

          if (_asInt(map['parent_id']) == 0 && parentId != null) {
            map['parent_id'] = parentId;
          }

          flatFolders.add(map);

          final children = (map['children'] as List?) ?? [];
          if (children.isNotEmpty) {
            walk(children, level + 1, _asInt(map['id']));
          }
        }
      }
    }

    walk(tree);

    _allFolders = flatFolders;
    folders = List<Map<String, dynamic>>.from(flatFolders);

    // По умолчанию все папки закрыты.
    // Видны только папки верхнего уровня, подпапки открываются по нажатию на стрелку.
    _expandedFolderIds.clear();
  }

  Future<void> _loadPlansForTeam() async {
    try {
      final resp = await TrainingPlansApi.listPlans(
        clubId: widget.clubId,
        teamId: _hasTeam ? widget.teamId! : 0,
        folderId: selectedFolderId ?? 0,
      );

      if (resp['success'] != true) {
        throw resp['message'] ?? 'Не удалось загрузить планы';
      }

      final raw = (resp['items'] as List?) ??
          (resp['data'] as List?) ??
          (resp['plans'] as List?) ??
          const [];

      var loadedPlans = raw.whereType<Map>().map((e) {
        final map = Map<String, dynamic>.from(e);

        final folderId = _asInt(map['folder_id']);
        if (_asStr(map['folder_title']).isEmpty && folderId > 0) {
          map['folder_title'] = _folderTitleFromList(_allFolders, folderId);
        }

        return map;
      }).toList();

      if (_hasTeam) {
        loadedPlans = loadedPlans.where((p) {
          final planTeamId = _asInt(p['team_id']);

          if (planTeamId == 0) return true;

          return planTeamId == widget.teamId;
        }).toList();
      }

      _rebuildVisibleFoldersForTeam(loadedPlans);

      if (selectedFolderId != null &&
          selectedFolderId! > 0 &&
          !_folderExistsInVisibleList(selectedFolderId!)) {
        selectedFolderId = null;
        selectedFolderTitle = 'Все материалы';
      }

      loadedPlans.sort((a, b) {
        final ad = _asStr(a['created_at']).isNotEmpty
            ? _asStr(a['created_at'])
            : _asStr(a['plan_date']);

        final bd = _asStr(b['created_at']).isNotEmpty
            ? _asStr(b['created_at'])
            : _asStr(b['plan_date']);

        return bd.compareTo(ad);
      });

      final q = searchCtrl.text.trim().toLowerCase();
      var filteredPlans = loadedPlans;

      if (q.isNotEmpty) {
        filteredPlans = loadedPlans.where((p) {
          return _asStr(p['theme']).toLowerCase().contains(q) ||
              _asStr(p['cycle_title']).toLowerCase().contains(q) ||
              _asStr(p['trainer_name']).toLowerCase().contains(q) ||
              _asStr(p['team_name']).toLowerCase().contains(q) ||
              _asStr(p['folder_title']).toLowerCase().contains(q);
        }).toList();
      }

      await _loadMaterialsForCurrentFolder(silent: true);

      final oldPlanId = _asInt(selectedPlan?['id']);
      Map<String, dynamic>? nextSelected = selectedPlan == null
          ? null
          : Map<String, dynamic>.from(selectedPlan!);

      if (oldPlanId > 0) {
        for (final p in filteredPlans) {
          if (_asInt(p['id']) == oldPlanId) {
            nextSelected = p;
            break;
          }
        }
      }

      // Важно для CMR: выбор папки меняет только центральную колонку.
      // Открытый справа план не сбрасываем, даже если его нет в текущей папке.
      nextSelected ??= filteredPlans.isNotEmpty ? filteredPlans.first : null;

      if (!mounted) return;

      setState(() {
        plans = filteredPlans;
        selectedPlan = nextSelected;
      });

      _syncEditors();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        plans = [];
        // Не сбрасываем открытый справа план при ошибке загрузки папки.
      });
    }
  }

  Future<void> _loadMaterialsForCurrentFolder({bool silent = false}) async {
    final teamId = _hasTeam ? widget.teamId! : 0;
    final folderId = _activeFolderId;

    if (!silent && mounted) {
      setState(() {
        loadingMaterials = true;
        materialsError = null;
      });
    } else {
      loadingMaterials = true;
      materialsError = null;
    }

    try {
      final results = await Future.wait<Map<String, dynamic>>([
        TrainingGraphicsApi.list(
          clubId: widget.clubId,
          teamId: teamId,
          folderId: folderId,
        ),
        TrainingFilesApi.list(
          clubId: widget.clubId,
          teamId: teamId,
          folderId: folderId,
        ),
      ]);

      final graphicsResp = results[0];
      final filesResp = results[1];

      if (graphicsResp['success'] != true) {
        throw graphicsResp['message'] ?? 'Не удалось загрузить схемы';
      }
      if (filesResp['success'] != true) {
        throw filesResp['message'] ?? 'Не удалось загрузить файлы';
      }

      var nextGraphics = _itemsFromResponse(graphicsResp);
      var nextFiles = _itemsFromResponse(filesResp);

      final q = searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        nextGraphics = nextGraphics.where((g) {
          return _asStr(g['title']).toLowerCase().contains(q) ||
              _asStr(g['name']).toLowerCase().contains(q);
        }).toList();
        nextFiles = nextFiles.where((f) {
          return _asStr(f['title']).toLowerCase().contains(q) ||
              _asStr(f['file_name']).toLowerCase().contains(q) ||
              _asStr(f['file_ext']).toLowerCase().contains(q);
        }).toList();
      }

      if (!mounted) {
        graphics = nextGraphics;
        files = nextFiles;
        loadingMaterials = false;
        return;
      }

      setState(() {
        graphics = nextGraphics;
        files = nextFiles;
        loadingMaterials = false;
        materialsError = null;
      });
    } catch (e) {
      if (!mounted) {
        loadingMaterials = false;
        materialsError = '$e';
        return;
      }
      setState(() {
        graphics = [];
        files = [];
        loadingMaterials = false;
        materialsError = '$e';
      });
    }
  }

  void _rebuildVisibleFoldersForTeam(List<Map<String, dynamic>> teamPlans) {
    if (!_hasTeam) {
      folders = List<Map<String, dynamic>>.from(_allFolders);
      return;
    }

    final usedFolderIds = <int>{};

    for (final p in teamPlans) {
      final folderId = _asInt(p['folder_id']);
      if (folderId > 0) {
        usedFolderIds.add(folderId);
        _collectParents(folderId, usedFolderIds);
      }
    }

    final filtered = <Map<String, dynamic>>[];

    for (final f in _allFolders) {
      final folderId = _asInt(f['id']);
      final folderTeamId = _asInt(f['team_id']);

      final isGlobalFolder = folderTeamId == 0;
      final isTeamFolder = folderTeamId == widget.teamId;
      final hasTeamPlansInside = usedFolderIds.contains(folderId);

      if (isTeamFolder || hasTeamPlansInside || isGlobalFolder) {
        filtered.add(f);
      }
    }

    folders = filtered;
  }

  void _collectParents(int folderId, Set<int> result) {
    final folder = _allFolders.firstWhereOrNull(
      (f) => _asInt(f['id']) == folderId,
    );

    if (folder == null) return;

    final parentId = _asInt(folder['parent_id']);
    if (parentId > 0 && !result.contains(parentId)) {
      result.add(parentId);
      _collectParents(parentId, result);
    }
  }

  bool _folderHasChildren(int folderId) {
    return folders.any((f) => _asInt(f['parent_id']) == folderId);
  }

  bool _folderIsExpanded(int folderId) {
    return _expandedFolderIds.contains(folderId);
  }

  void _toggleFolderExpanded(int folderId) {
    if (folderId <= 0) return;

    setState(() {
      if (_expandedFolderIds.contains(folderId)) {
        _expandedFolderIds.remove(folderId);
      } else {
        _expandedFolderIds.add(folderId);
      }
    });
  }

  bool _isFolderVisible(Map<String, dynamic> folder) {
    var parentId = _asInt(folder['parent_id']);
    if (parentId <= 0) return true;

    while (parentId > 0) {
      if (!_expandedFolderIds.contains(parentId)) return false;

      final parent = folders.firstWhereOrNull((f) => _asInt(f['id']) == parentId);
      if (parent == null) return true;
      parentId = _asInt(parent['parent_id']);
    }

    return true;
  }

  List<Map<String, dynamic>> get _visibleFolders {
    return folders.where(_isFolderVisible).toList();
  }

  bool _folderExistsInVisibleList(int folderId) {
    for (final f in folders) {
      if (_asInt(f['id']) == folderId) return true;
    }
    return false;
  }

  String _folderTitleFromList(
    List<Map<String, dynamic>> list,
    int folderId,
  ) {
    for (final f in list) {
      if (_asInt(f['id']) == folderId) {
        return _asStr(f['title']);
      }
    }
    return '';
  }

  String _folderTitleById(int id) {
    for (final f in _allFolders) {
      if (_asInt(f['id']) == id) return _asStr(f['title']);
    }
    return '';
  }

  void _syncEditors() {
    final p = selectedPlan;

    themeCtrl.text = _asStr(p?['theme']);
    cycleCtrl.text = _asStr(p?['cycle_title']);
    descriptionCtrl.text = _asStr(
      p?['description'] ??
          p?['plan_description'] ??
          p?['comment'] ??
          p?['notes'],
    );
    dateCtrl.text = _asStr(p?['plan_date'] ?? p?['created_at']);
  }

  void _selectFolder(Map<String, dynamic>? folder) {
    setState(() {
      selectedFolderId = folder == null ? null : _asInt(folder['id']);
      selectedFolderTitle = folder == null
          ? 'Все материалы'
          : (_asStr(folder['title']).isEmpty
              ? 'Папка'
              : _asStr(folder['title']));
      editMode = false;
      showFoldersList = false;

      if (folder != null) {
        final folderId = _asInt(folder['id']);
        if (folderId > 0) _expandedFolderIds.add(folderId);
        var parentId = _asInt(folder['parent_id']);
        while (parentId > 0) {
          _expandedFolderIds.add(parentId);
          final parent = folders.firstWhereOrNull((f) => _asInt(f['id']) == parentId);
          if (parent == null) break;
          parentId = _asInt(parent['parent_id']);
        }
      }
    });

    _loadPlansForTeam();
  }

  void _selectPlan(Map<String, dynamic> plan) {
    setState(() {
      selectedPlan = plan;
      editMode = false;
    });

    _syncEditors();
  }

  void _handleBack() {
    if (editMode) {
      setState(() => editMode = false);
      _syncEditors();
      return;
    }

    if (showFoldersList) {
      setState(() => showFoldersList = false);
      return;
    }

    if (selectedPlan != null && _isMobile(context)) {
      setState(() => selectedPlan = null);
      return;
    }

    if (widget.onBackToMenu != null) {
      widget.onBackToMenu!();
      return;
    }

    Get.back();
  }

  Future<void> _createFolder() async {
    final parentId = selectedFolderId;
    final titleCtrl = TextEditingController();
    String type = parentId == null ? 'age' : 'custom';

    final ok = await Get.dialog<bool>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final isMobile = _isMobile(context);

            Widget typeCard({
              required String value,
              required String title,
              required String text,
              required IconData icon,
            }) {
              final selected = type == value;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setLocalState(() => type = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? _C.greenSoft : _C.input,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? _C.green.withOpacity(.32) : _C.line,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: selected ? Colors.white : Colors.white.withOpacity(.75),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                icon,
                                color: selected ? _C.greenDark : _C.muted,
                                size: 17,
                              ),
                            ),
                            const Spacer(),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: selected ? _C.green : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: selected ? _C.green : _C.line),
                              ),
                              child: selected
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? _C.greenDark : _C.text,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _C.caption.copyWith(
                            color: selected ? _C.greenDark : _C.muted,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? MediaQuery.of(context).size.width - 28 : 560,
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 20, 18, isMobile ? 12 : 16, 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF4FBF7), Colors.white],
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _C.greenSoft,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _C.green.withOpacity(.12)),
                            ),
                            child: const Icon(Icons.create_new_folder_rounded, color: _C.greenDark, size: 25),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Новая папка',
                                  style: _C.h1.copyWith(fontSize: isMobile ? 18 : 20),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  parentId == null
                                      ? 'Создаём раздел в корне файлового браузера'
                                      : 'Создаём подпапку внутри «$selectedFolderTitle»',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _C.body.copyWith(fontSize: 12.2),
                                ),
                              ],
                            ),
                          ),
                          _SquareTool(
                            icon: Icons.close_rounded,
                            onTap: () => Get.back(result: false),
                            tooltip: 'Закрыть',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(isMobile ? 14 : 20, 4, isMobile ? 14 : 20, isMobile ? 14 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: titleCtrl,
                            autofocus: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => Get.back(result: true),
                            style: const TextStyle(
                              color: _C.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Название папки',
                              hintText: 'Например: U-10, Атака, Схемы стандартов',
                              prefixIcon: const Icon(Icons.folder_rounded, color: _C.greenDark),
                              filled: true,
                              fillColor: _C.input,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(color: _C.green, width: 1.4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Тип папки',
                            style: TextStyle(color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 9),
                          isMobile
                              ? Column(
                                  children: [
                                    Row(
                                      children: [
                                        typeCard(value: 'age', title: 'Возраст', text: 'U-8, U-10, U-12', icon: Icons.groups_2_rounded),
                                        const SizedBox(width: 8),
                                        typeCard(value: 'category', title: 'Категория', text: 'Атака, оборона', icon: Icons.category_rounded),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        typeCard(value: 'custom', title: 'Своя', text: 'Любой раздел', icon: Icons.tune_rounded),
                                        const Expanded(child: SizedBox()),
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    typeCard(value: 'age', title: 'Возраст', text: 'U-8, U-10, U-12', icon: Icons.groups_2_rounded),
                                    const SizedBox(width: 10),
                                    typeCard(value: 'category', title: 'Категория', text: 'Атака, оборона', icon: Icons.category_rounded),
                                    const SizedBox(width: 10),
                                    typeCard(value: 'custom', title: 'Своя', text: 'Любой раздел', icon: Icons.tune_rounded),
                                  ],
                                ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _C.greenSoft,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: _C.greenDark, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'После создания папка появится слева в дереве, а по центру будут планы, схемы и файлы.',
                                    style: _C.caption.copyWith(color: _C.greenDark, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Get.back(result: false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _C.text,
                                    side: const BorderSide(color: _C.line),
                                    minimumSize: const Size.fromHeight(46),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  child: const Text('Отмена'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => Get.back(result: true),
                                  icon: const Icon(Icons.add_rounded, size: 19),
                                  label: const Text('Создать'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _C.green,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size.fromHeight(46),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => saving = true);

    try {
      final r = await PlanFoldersApi.create(
        clubId: widget.clubId,
        parentId: parentId,
        title: title,
        type: type,
        createdBy: widget.clubId,
      );

      if (r['success'] != true) {
        throw r['message'] ?? 'Не удалось создать папку';
      }

      await _load();
      Get.snackbar('Готово', 'Папка создана');
    } catch (e) {
      Get.snackbar('Ошибка', '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _renameSelectedFolder() async {
    final id = selectedFolderId;

    if (id == null || id <= 0) {
      Get.snackbar('Папка', 'Выберите папку для переименования');
      return;
    }

    final titleCtrl = TextEditingController(text: selectedFolderTitle);

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Переименовать папку'),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Новое название',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => saving = true);

    try {
      final r = await PlanFoldersApi.rename(
        clubId: widget.clubId,
        folderId: id,
        title: title,
      );

      if (r['success'] != true) {
        throw r['message'] ?? 'Не удалось переименовать папку';
      }

      selectedFolderTitle = title;

      await _load();
      Get.snackbar('Готово', 'Папка переименована');
    } catch (e) {
      Get.snackbar('Ошибка', '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _deleteSelectedFolder() async {
    final id = selectedFolderId;

    if (id == null || id <= 0) {
      Get.snackbar('Папка', 'Выберите папку для удаления');
      return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Удалить папку?'),
        content: Text(
          'Папка «$selectedFolderTitle» будет удалена. '
          'Если внутри есть материалы, сервер может запретить удаление.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(
              foregroundColor: _C.red,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => saving = true);

    try {
      final r = await PlanFoldersApi.remove(
        clubId: widget.clubId,
        folderId: id,
      );

      if (r['success'] != true) {
        throw r['message'] ?? 'Не удалось удалить папку';
      }

      selectedFolderId = null;
      selectedFolderTitle = 'Все материалы';

      await _load();
      Get.snackbar('Готово', 'Папка удалена');
    } catch (e) {
      Get.snackbar('Ошибка', '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _renameSelectedPlan() async {
    final plan = selectedPlan;
    if (plan == null) {
      Get.snackbar('План', 'Выберите план для переименования');
      return;
    }

    final planId = _asInt(plan['id']);
    if (planId <= 0) return;

    final titleCtrl = TextEditingController(text: _planTitle(plan));

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Переименовать план'),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Get.back(result: true),
          decoration: const InputDecoration(
            labelText: 'Название плана',
            hintText: 'Например: Выход из обороны через фланг',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => saving = true);

    try {
      final payload = <String, dynamic>{
        'id': planId,
        'plan_id': planId,
        'club_id': widget.clubId,
        'team_id': widget.teamId ?? _asInt(plan['team_id']),
        'folder_id': _asInt(plan['folder_id']) > 0 ? _asInt(plan['folder_id']) : _activeFolderId,
        'theme': title,
        'cycle_title': _asStr(plan['cycle_title']),
        'description': _asStr(plan['description'] ?? plan['plan_description'] ?? plan['comment'] ?? plan['notes']),
        'plan_description': _asStr(plan['description'] ?? plan['plan_description'] ?? plan['comment'] ?? plan['notes']),
        'plan_date': _asStr(plan['plan_date'] ?? plan['created_at']),
      };

      final response = await http
          .post(
            Uri.parse('${TrainingPlansApi.base}/update_training_plan.php'),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body);
      if (data is! Map || data['success'] != true) {
        throw data is Map ? (data['message'] ?? 'Не удалось переименовать план') : 'Не удалось переименовать план';
      }

      if (!mounted) return;
      setState(() {
        selectedPlan = Map<String, dynamic>.from(plan)..['theme'] = title;
        themeCtrl.text = title;
      });

      await _loadPlansForTeam();
      Get.snackbar('Готово', 'План переименован');
    } catch (e) {
      Get.snackbar('Ошибка', '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _deleteSelectedPlan() async {
    final plan = selectedPlan;
    if (plan == null) return;

    final planId = _asInt(plan['id']);
    if (planId <= 0) return;

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Удалить план?'),
        content: Text('План «${_planTitle(plan)}» будет удалён.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => saving = true);

    try {
      final r = await TrainingPlansApi.deletePlan(
        clubId: widget.clubId,
        planId: planId,
      );

      if (r['success'] != true) {
        throw r['message'] ?? 'Не удалось удалить план';
      }

      selectedPlan = null;

      await _loadPlansForTeam();
      Get.snackbar('Готово', 'План удалён');
    } catch (e) {
      Get.snackbar('Ошибка', '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _saveSelectedPlan() async {
    final plan = selectedPlan;
    if (plan == null) return;

    final planId = _asInt(plan['id']);
    if (planId <= 0) return;

    setState(() => saving = true);

    try {
      final payload = <String, dynamic>{
        'id': planId,
        'plan_id': planId,
        'club_id': widget.clubId,
        'team_id': widget.teamId ?? _asInt(plan['team_id']),
        'folder_id': _asInt(plan['folder_id']) > 0 ? _asInt(plan['folder_id']) : _activeFolderId,
        'theme': themeCtrl.text.trim(),
        'cycle_title': cycleCtrl.text.trim(),
        'description': descriptionCtrl.text.trim(),
        'plan_description': descriptionCtrl.text.trim(),
        'plan_date': dateCtrl.text.trim(),
      };

      final response = await http
          .post(
            Uri.parse('${TrainingPlansApi.base}/update_training_plan.php'),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body);

      if (data is! Map || data['success'] != true) {
        throw data is Map
            ? (data['message'] ?? 'Не удалось сохранить')
            : 'Не удалось сохранить';
      }

      if (!mounted) return;

      setState(() => editMode = false);

      await _loadPlansForTeam();
      Get.snackbar('Готово', 'План сохранён');
    } catch (e) {
      Get.snackbar(
        'Сохранение',
        'Не удалось сохранить. Ошибка: $e',
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }


  Map<String, dynamic> _planDetailArgs(Map<String, dynamic> plan) {
    return {
      'planId': _asInt(plan['id']),
      'clubId': widget.clubId,
      'clubName': widget.clubName,
      'teamId': widget.teamId ?? _asInt(plan['team_id']),
      'teamName': _asStr(plan['team_name']).isNotEmpty ? _asStr(plan['team_name']) : widget.teamName,
      'folderId': _asInt(plan['folder_id']) > 0 ? _asInt(plan['folder_id']) : _activeFolderId,
      'folderName': _folderTitleById(_asInt(plan['folder_id'])).isNotEmpty ? _folderTitleById(_asInt(plan['folder_id'])) : selectedFolderTitle,
      'trainerName': _asStr(plan['trainer_name']),
    };
  }

  void _openFullFoldersScreen() {
    Get.to(
      () => PlanFoldersScreen(
        clubId: widget.clubId,
        clubName: widget.clubName,
        teamId: widget.teamId,
        selectMode: false,
        browsePlansMode: false,
      ),
    );
  }

  void _openFullPlanScreen() {
    final plan = selectedPlan;
    if (plan == null) return;

    Get.to(
      () => const PlanDetailScreen(),
      arguments: _planDetailArgs(plan),
    );
  }

  String _planTitle(Map<String, dynamic> plan) {
    final theme = _asStr(plan['theme']);
    if (theme.isNotEmpty) return theme;

    final cycle = _asStr(plan['cycle_title']);
    if (cycle.isNotEmpty) return cycle;

    return 'План #${_asInt(plan['id'])}';
  }

  bool _isMobile(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width < 600;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);

    if (loading) return _buildLoading(isMobile);

    if (error != null) {
      return _CmrEmptyState(
        title: 'Не удалось загрузить планы',
        text: error!,
        actionText: 'Повторить',
        onAction: _load,
        isMobile: isMobile,
      );
    }

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(color: _C.page),
          child: isMobile ? _buildMobileFinder() : _buildFinderLayout(),
        ),
        if (saving)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(
              minHeight: 3,
              color: _C.green,
              backgroundColor: _C.greenSoft,
            ),
          ),
      ],
    );
  }

  Widget _buildLoading(bool isMobile) {
    return Container(
      color: _C.page,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          decoration: _C.panelDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _PlanMark(size: 64),
              const SizedBox(height: 18),
              Text(
                'Загружаем файловый журнал планов',
                textAlign: TextAlign.center,
                style: _C.h1.copyWith(fontSize: isMobile ? 18 : 22),
              ),
              const SizedBox(height: 8),
              const Text(
                'Собираем папки, планы-конспекты и материалы команды',
                textAlign: TextAlign.center,
                style: _C.body,
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(
                  minHeight: 5,
                  color: _C.green,
                  backgroundColor: _C.greenSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinderLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final sidebarWidth = width < 1180 ? 224.0 : 238.0;
        final filesWidth = width < 1180 ? 286.0 : 306.0;

        return Row(
          children: [
            SizedBox(width: sidebarWidth, child: _buildSidebar()),
            const VerticalDivider(width: 1, thickness: 1, color: _C.line),
            SizedBox(width: filesWidth, child: _buildFilesColumn()),
            const VerticalDivider(width: 1, thickness: 1, color: _C.line),
            Expanded(child: _buildPreviewPane()),
          ],
        );
      },
    );
  }

  Widget _buildMobileFinder() {
    final showPlan = selectedPlan != null && !showFoldersList;

    return Column(
      children: [
        _buildMobileTopBar(),
        const Divider(height: 1, color: _C.line),
        Expanded(
          child: showPlan
              ? _buildPreviewPane(compact: true)
              : showFoldersList
                  ? _buildSidebar(mobile: true)
                  : _buildFilesColumn(mobile: true),
        ),
      ],
    );
  }

  Widget _buildMobileTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          _SquareTool(
            icon: Icons.arrow_back_rounded,
            onTap: _handleBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              selectedPlan != null
                  ? _planTitle(selectedPlan!)
                  : showFoldersList
                      ? 'Папки планов'
                      : 'Материалы',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _C.h1.copyWith(fontSize: 15),
            ),
          ),
          const SizedBox(width: 8),
          _SquareTool(
            icon: showFoldersList ? Icons.article_rounded : Icons.folder_rounded,
            onTap: () => setState(() => showFoldersList = !showFoldersList),
          ),
          const SizedBox(width: 6),
          _SquareTool(icon: Icons.refresh_rounded, onTap: saving ? null : _load),
        ],
      ),
    );
  }

  Widget _buildSidebar({bool mobile = false}) {
    final rootActive = selectedFolderId == null;

    return Container(
      color: _C.sidebar,
      child: Column(
        children: [
          if (!mobile)
            _FinderHeader(
              title: 'Планы',
              subtitle: widget.teamName.isEmpty
                  ? widget.clubName
                  : '${widget.clubName} • ${widget.teamName}',
              onBack: _handleBack,
              onRefresh: saving ? null : _load,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, mobile ? 12 : 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: _ActionPill(
                    label: 'Папка',
                    icon: Icons.create_new_folder_rounded,
                    onTap: saving ? null : _createFolder,
                  ),
                ),
                const SizedBox(width: 8),
                _SquareTool(
                  icon: Icons.drive_file_rename_outline_rounded,
                  onTap: saving ? null : _renameSelectedFolder,
                  tooltip: 'Переименовать папку',
                ),
                const SizedBox(width: 8),
                _SquareTool(
                  icon: Icons.delete_outline_rounded,
                  danger: true,
                  onTap: saving ? null : _deleteSelectedFolder,
                  tooltip: 'Удалить папку',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.line),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              itemCount: _visibleFolders.length + 1,
              itemBuilder: (_, index) {
                if (index == 0) {
                  return _FinderFolderTile(
                    title: 'Все материалы',
                    subtitle: '${plans.length} план${_ruPlural(plans.length, '', 'а', 'ов')}',
                    level: 0,
                    active: rootActive,
                    system: true,
                    hasChildren: folders.isNotEmpty,
                    expanded: false,
                    onTap: () => _selectFolder(null),
                  );
                }

                final f = _visibleFolders[index - 1];
                final title = _asStr(f['title']).isEmpty ? 'Папка' : _asStr(f['title']);
                final folderId = _asInt(f['id']);
                final hasChildren = _folderHasChildren(folderId);

                return _FinderFolderTile(
                  title: title,
                  subtitle: _folderCounterText(f),
                  level: _asInt(f['_level']),
                  active: selectedFolderId == folderId,
                  hasChildren: hasChildren,
                  expanded: _folderIsExpanded(folderId),
                  onToggle: hasChildren ? () => _toggleFolderExpanded(folderId) : null,
                  onTap: () => _selectFolder(f),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesColumn({bool mobile = false}) {
    final total = plans.length + graphics.length + files.length;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildFileToolbar(mobile: mobile),
          const Divider(height: 1, color: _C.line),
          _BrowserTableHeader(mobile: mobile),
          const Divider(height: 1, color: _C.line),
          Expanded(
            child: RefreshIndicator(
              color: _C.green,
              onRefresh: () async => _loadPlansForTeam(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
                children: [
                  if (loadingMaterials) const _MaterialsLoading(),
                  if (materialsError != null) ...[
                    _BrowserGroupLabel(
                      title: 'Материалы',
                      count: 0,
                      icon: Icons.warning_amber_rounded,
                    ),
                    _CompactEmptyBlock(
                      title: 'Материалы не загрузились',
                      text: materialsError!,
                    ),
                  ],
                  if (plans.isNotEmpty) ...[
                    _BrowserGroupLabel(
                      title: 'Планы-конспекты',
                      count: plans.length,
                      icon: Icons.description_rounded,
                    ),
                    ...plans.map((plan) {
                      final active = _asInt(plan['id']) == _asInt(selectedPlan?['id']);
                      return _BrowserFileRow(
                        title: _planTitle(plan),
                        subtitle: _asStr(plan['trainer_name']).isNotEmpty
                            ? _asStr(plan['trainer_name'])
                            : (_asStr(plan['team_name']).isNotEmpty ? _asStr(plan['team_name']) : 'План-конспект'),
                        folder: _asStr(plan['folder_title']).isNotEmpty
                            ? _asStr(plan['folder_title'])
                            : _folderTitleById(_asInt(plan['folder_id'])),
                        date: _shortDate(_asStr(plan['plan_date']).isNotEmpty
                            ? _asStr(plan['plan_date'])
                            : _asStr(plan['created_at'])),
                        badge: _planBadgesText(plan),
                        icon: Icons.description_rounded,
                        active: active,
                        onTap: () => _selectPlan(plan),
                        onRename: active ? _renameSelectedPlan : null,
                      );
                    }),
                  ],
                  if (!loadingMaterials && graphics.isNotEmpty) ...[
                    _BrowserGroupLabel(
                      title: 'Схемы',
                      count: graphics.length,
                      icon: Icons.account_tree_rounded,
                      hint: 'зажмите и перетащите вправо',
                    ),
                    ...graphics.map((g) => _DraggableMaterialTile(
                          data: g,
                          type: 'scheme',
                          title: _asStr(g['title']).isNotEmpty
                              ? _asStr(g['title'])
                              : (_asStr(g['name']).isNotEmpty ? _asStr(g['name']) : 'Схема #${_asInt(g['id'])}'),
                          subtitle: 'Схема • нажмите для просмотра',
                          folder: '',
                          date: _shortDate(_asStr(g['created_at'])),
                          icon: Icons.account_tree_rounded,
                          previewUrl: _materialImageUrl(g),
                          onPreview: () => _openSchemePreview(g),
                        )),
                  ],
                  if (!loadingMaterials && files.isNotEmpty) ...[
                    _BrowserGroupLabel(
                      title: 'Файлы',
                      count: files.length,
                      icon: Icons.insert_drive_file_rounded,
                      hint: 'docx, xlsx, pdf, изображения',
                    ),
                    ...files.map((f) => _DraggableMaterialTile(
                          data: f,
                          type: 'file',
                          title: _asStr(f['title']).isNotEmpty
                              ? _asStr(f['title'])
                              : (_asStr(f['file_name']).isNotEmpty ? _asStr(f['file_name']) : 'Файл #${_asInt(f['id'])}'),
                          subtitle: _asStr(f['file_ext']).isNotEmpty
                              ? _asStr(f['file_ext']).toUpperCase()
                              : 'Файл',
                          folder: '',
                          date: _shortDate(_asStr(f['created_at'])),
                          icon: _fileIcon(_asStr(f['file_ext']).isNotEmpty ? _asStr(f['file_ext']) : _asStr(f['file_name'])),
                          previewUrl: _materialImageUrl(f),
                        )),
                  ],
                  if (!loadingMaterials && materialsError == null && total == 0)
                    const _FinderEmpty(
                      title: 'Папка пустая',
                      text: 'Выберите папку слева. Здесь одним списком появятся планы, схемы и файлы для перетаскивания.',
                    ),
                  if (!loadingMaterials && materialsError == null && plans.isEmpty && (graphics.isNotEmpty || files.isNotEmpty))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: _CompactEmptyBlock(
                        title: 'План не выбран',
                        text: 'Выберите план выше или откройте другой раздел. Материалы уже можно перетаскивать в редактор справа.',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _absoluteMaterialUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == 'null') return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;

    final apiBase = TrainingPlansApi.base;
    final origin = apiBase.endsWith('/api')
        ? apiBase.substring(0, apiBase.length - 4)
        : apiBase.replaceFirst(RegExp(r'/api/?$'), '');

    if (value.startsWith('/')) return '$origin$value';
    if (value.startsWith('uploads/')) return '$origin/$value';
    return '$apiBase/$value';
  }

  String _materialImageUrl(Map<String, dynamic> item) {
    final candidates = <String>[
      _asStr(item['thumbnail_url']),
      _asStr(item['thumb_url']),
      _asStr(item['preview_url']),
      _asStr(item['image_url']),
      _asStr(item['scheme_url']),
      _asStr(item['file_url']),
      _asStr(item['url']),
      _asStr(item['path']),
      _asStr(item['file_path']),
      _asStr(item['image']),
      _asStr(item['thumbnail']),
      _asStr(item['file_name']),
    ];

    for (final c in candidates) {
      final lower = c.toLowerCase();
      if (lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp') ||
          lower.contains('.jpg?') ||
          lower.contains('.jpeg?') ||
          lower.contains('.png?') ||
          lower.contains('.webp?')) {
        return _absoluteMaterialUrl(c);
      }
    }

    return '';
  }

  void _openSchemePreview(Map<String, dynamic> scheme) {
    final title = _asStr(scheme['title']).isNotEmpty
        ? _asStr(scheme['title'])
        : (_asStr(scheme['name']).isNotEmpty ? _asStr(scheme['name']) : 'Схема');
    final imageUrl = _materialImageUrl(scheme);

    if (imageUrl.isEmpty) {
      Get.snackbar('Схема', 'У этой схемы не найдено изображение для просмотра');
      return;
    }

    Get.dialog(
      _SchemePreviewDialog(
        title: title,
        imageUrl: imageUrl,
        subtitle: 'Просмотр схемы',
      ),
      barrierColor: Colors.black.withOpacity(.72),
    );
  }

  IconData _fileIcon(String value) {
    final v = value.toLowerCase();
    if (v.endsWith('.png') || v.endsWith('.jpg') || v.endsWith('.jpeg') || v.endsWith('.webp') || v == 'png' || v == 'jpg' || v == 'jpeg' || v == 'webp') {
      return Icons.image_rounded;
    }
    if (v.endsWith('.pdf') || v == 'pdf') return Icons.picture_as_pdf_rounded;
    if (v.endsWith('.doc') || v.endsWith('.docx') || v == 'doc' || v == 'docx') return Icons.article_rounded;
    if (v.endsWith('.xls') || v.endsWith('.xlsx') || v == 'xls' || v == 'xlsx') return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Widget _buildFileToolbar({bool mobile = false}) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(mobile ? 10 : 10, mobile ? 8 : 8, mobile ? 10 : 10, mobile ? 8 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _C.greenSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.folder_open_rounded, color: _C.greenDark, size: 17),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Материалы',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _C.h1.copyWith(fontSize: mobile ? 14 : 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${plans.length} планов • ${graphics.length} схем • ${files.length} файлов',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _C.caption.copyWith(fontSize: mobile ? 10 : 10.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SquareTool(
                icon: Icons.refresh_rounded,
                onTap: saving ? null : () => _loadPlansForTeam(),
                tooltip: 'Обновить список',
              ),
              if (selectedPlan != null) ...[
                const SizedBox(width: 6),
                _SquareTool(
                  icon: Icons.drive_file_rename_outline_rounded,
                  onTap: saving ? null : _renameSelectedPlan,
                  tooltip: 'Переименовать выбранный план',
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          TextField(
            controller: searchCtrl,
            onSubmitted: (_) => _loadPlansForTeam(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'Поиск: план, схема, файл',
              hintStyle: const TextStyle(fontSize: 11.5, color: _C.muted),
              prefixIcon: const Icon(Icons.search_rounded, size: 19),
              suffixIcon: searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchCtrl.clear();
                        _loadPlansForTeam();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: true,
              fillColor: _C.input,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (selectedPlan != null) ...[
            const SizedBox(height: 8),
            _PinnedPlanChip(title: _planTitle(selectedPlan!)),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewPane({bool compact = false}) {
    final plan = selectedPlan;

    if (plan == null) {
      return const ColoredBox(
        color: _C.preview,
        child: _FinderEmpty(
          title: 'Выберите план',
          text: 'Справа откроется полный редактор плана-конспекта: цели, упражнения, схемы и вложения.',
        ),
      );
    }

    final planId = _asInt(plan['id']);
    if (planId <= 0) {
      return const ColoredBox(
        color: _C.preview,
        child: _FinderEmpty(
          title: 'План без ID',
          text: 'Невозможно открыть детальный редактор для плана без идентификатора.',
        ),
      );
    }

    final media = MediaQuery.of(context);

    return Container(
      color: _C.preview,
      child: MediaQuery(
        data: media.copyWith(
          textScaler: TextScaler.linear(compact ? .96 : .92),
        ),
        child: PlanDetailScreen(
          key: ValueKey('cmr_plan_editor_$planId'),
          embedded: true,
          initialArgs: _planDetailArgs(plan),
          onOpenFullscreen: _openFullPlanScreen,
          onSaved: (_) async {
            await _loadPlansForTeam();
            final refreshed = plans.where((p) => _asInt(p['id']) == planId).toList();
            if (!mounted) return;
            if (refreshed.isNotEmpty) {
              setState(() => selectedPlan = refreshed.first);
            }
          },
        ),
      ),
    );
  }

  int _folderPlanCount(Map<String, dynamic> folder) {
    final direct = _asInt(
      folder['plans_count'] ??
          folder['plan_count'] ??
          folder['items_count'] ??
          folder['materials_count'] ??
          folder['count'],
    );
    return direct;
  }

  int _folderFilesCount(Map<String, dynamic> folder) {
    return _asInt(
      folder['attachments_count'] ??
          folder['files_count'] ??
          folder['documents_count'] ??
          folder['docs_count'],
    );
  }

  int _folderSchemesCount(Map<String, dynamic> folder) {
    return _asInt(
      folder['schemes_count'] ??
          folder['schema_count'] ??
          folder['images_count'] ??
          folder['scheme_count'],
    );
  }

  String _folderCounterText(Map<String, dynamic> folder) {
    final parts = <String>[];
    final planCount = _folderPlanCount(folder);
    final filesCount = _folderFilesCount(folder);
    final schemesCount = _folderSchemesCount(folder);

    if (planCount > 0) parts.add('$planCount план${_ruPlural(planCount, '', 'а', 'ов')}');
    if (schemesCount > 0) parts.add('$schemesCount схем${_ruPlural(schemesCount, 'а', 'ы', '')}');
    if (filesCount > 0) parts.add('$filesCount файл${_ruPlural(filesCount, '', 'а', 'ов')}');

    if (parts.isNotEmpty) return parts.join(' • ');
    return _folderTypeLabel(_asStr(folder['type']));
  }

  int _planFilesCount(Map<String, dynamic> plan) {
    return _asInt(
      plan['attachments_count'] ??
          plan['files_count'] ??
          plan['documents_count'] ??
          plan['docs_count'],
    );
  }

  int _planSchemesCount(Map<String, dynamic> plan) {
    final rawSchemes = plan['schemes'];
    if (rawSchemes is List) return rawSchemes.length;

    return _asInt(
      plan['schemes_count'] ??
          plan['schema_count'] ??
          plan['images_count'] ??
          plan['scheme_count'],
    );
  }

  String _planBadgesText(Map<String, dynamic> plan) {
    final schemesCount = _planSchemesCount(plan);
    final filesCount = _planFilesCount(plan);
    final parts = <String>[];

    if (schemesCount > 0) parts.add('схемы $schemesCount');
    if (filesCount > 0) parts.add('файлы $filesCount');

    return parts.join(' • ');
  }

  String _ruPlural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }

  String _folderTypeLabel(String type) {
    switch (type) {
      case 'age':
        return 'Возраст';
      case 'category':
        return 'Категория';
      case 'custom':
        return 'Папка';
      default:
        return type.isEmpty ? 'Папка' : type;
    }
  }

  String _shortDate(String value) {
    final v = value.trim();
    if (v.isEmpty || v == 'null') return '';
    return v.length > 10 ? v.substring(0, 10) : v;
  }
}

class _C {
  static const Color page = Colors.white;
  static const Color sidebar = Color(0xFFFAFCFB);
  static const Color preview = Colors.white;
  static const Color input = Color(0xFFF6F8F7);
  static const Color green = Color(0xFF168A4A);
  static const Color greenDark = Color(0xFF0F6A38);
  static const Color greenSoft = Color(0xFFEAF7EF);
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color line = Color(0xFFE7ECE9);
  static const Color red = Color(0xFFDC2626);

  static BoxDecoration get panelDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static const TextStyle h1 = TextStyle(
    color: text,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    height: 1.12,
  );

  static const TextStyle body = TextStyle(
    color: muted,
    fontSize: 12.2,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    color: muted,
    fontSize: 10.6,
    fontWeight: FontWeight.w700,
  );
}

class _FinderHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;

  const _FinderHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Row(
        children: [
          _SquareTool(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 10),
          const _PlanMark(size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.h1),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SquareTool(icon: Icons.refresh_rounded, onTap: onRefresh),
        ],
      ),
    );
  }
}

class _PlanMark extends StatelessWidget {
  final double size;

  const _PlanMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PlanMarkPainter()),
    );
  }
}

class _PlanMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .15, size.height * .08, size.width * .68, size.height * .82),
      Radius.circular(size.width * .13),
    );
    final fill = Paint()..color = _C.greenSoft;
    final stroke = Paint()
      ..color = _C.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .055;
    canvas.drawRRect(r, fill);
    canvas.drawRRect(r, stroke);

    final line = Paint()
      ..color = _C.greenDark
      ..strokeWidth = size.width * .045
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (.30 + i * .18);
      canvas.drawLine(Offset(size.width * .30, y), Offset(size.width * .68, y), line);
    }

    final ball = Paint()..color = Colors.white;
    final ballStroke = Paint()
      ..color = _C.greenDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .035;
    final c = Offset(size.width * .78, size.height * .76);
    canvas.drawCircle(c, size.width * .16, ball);
    canvas.drawCircle(c, size.width * .16, ballStroke);
    canvas.drawCircle(c, size.width * .045, Paint()..color = _C.greenDark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FinderFolderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int level;
  final bool active;
  final bool system;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggle;
  final VoidCallback onTap;

  const _FinderFolderTile({
    required this.title,
    required this.subtitle,
    required this.level,
    required this.active,
    required this.onTap,
    this.system = false,
    this.hasChildren = false,
    this.expanded = false,
    this.onToggle,
  });

 @override
Widget build(BuildContext context) {
  return Padding(
    padding: EdgeInsets.only(
      left: (level.clamp(0, 4) * 10).toDouble(),
      bottom: 4,
    ),
    child: Material(
      color: active ? _C.greenSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 38,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: active
                  ? Border.all(
                      color: _C.green.withOpacity(.18),
                    )
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: hasChildren
                      ? InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onToggle,
                          child: Icon(
                            expanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                            color: active ? _C.greenDark : const Color(0xFF98A2B3),
                            size: 18,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 4),
                Icon(
                  system ? Icons.inventory_2_rounded : Icons.folder_rounded,
                  color: active ? _C.greenDark : const Color(0xFF98A2B3),
                  size: 18,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active
                              ? _C.greenDark
                              : _C.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _C.caption.copyWith(
                          fontSize: 9.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}

class _MiniSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _MiniSectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _C.greenDark),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _C.input,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('$count', style: const TextStyle(color: _C.muted, fontSize: 10.5, fontWeight: FontWeight.w900)),
        ),
        if (actionIcon != null) ...[
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(actionIcon, size: 16, color: _C.muted),
            ),
          ),
        ],
      ],
    );
  }
}

class _MaterialsLoading extends StatelessWidget {
  const _MaterialsLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _C.input, borderRadius: BorderRadius.circular(14)),
      child: const Row(
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _C.green)),
          SizedBox(width: 10),
          Expanded(child: Text('Загружаем схемы и файлы...', style: _C.caption)),
        ],
      ),
    );
  }
}

class _CompactEmptyBlock extends StatelessWidget {
  final String title;
  final String text;

  const _CompactEmptyBlock({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _C.input, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(text, style: _C.caption.copyWith(height: 1.35)),
        ],
      ),
    );
  }
}

class _DraggableMaterialTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String type;
  final String title;
  final String subtitle;
  final String folder;
  final String date;
  final IconData icon;
  final String previewUrl;
  final VoidCallback? onPreview;

  const _DraggableMaterialTile({
    required this.data,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.folder,
    required this.date,
    required this.icon,
    this.previewUrl = '',
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final payload = <String, dynamic>{
      ...data,
      '_drag_type': type,
      'material_type': type,
    };

    final child = _BrowserFileRow(
      title: title,
      subtitle: subtitle,
      folder: '',
      date: date,
      badge: type == 'scheme' ? 'схема' : 'файл',
      icon: icon,
      active: false,
      draggable: true,
      previewUrl: previewUrl,
      onTap: onPreview ?? () {},
      onPreview: onPreview,
    );

    return LongPressDraggable<Map<String, dynamic>>(
      data: payload,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 330,
          child: _BrowserFileRow(
            title: title,
            subtitle: 'Отпустите в редакторе плана',
            folder: '',
            date: date,
            badge: type == 'scheme' ? 'схема' : 'файл',
            icon: icon,
            active: true,
            draggable: true,
            previewUrl: previewUrl,
            onTap: () {},
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: .45, child: child),
      child: child,
    );
  }
}

class _BrowserTableHeader extends StatelessWidget {
  final bool mobile;

  const _BrowserTableHeader({required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFCFDFC),
      padding: EdgeInsets.fromLTRB(10, mobile ? 6 : 6, 10, mobile ? 6 : 6),
      child: Row(
        children: [
          const SizedBox(width: 30),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text('Название', style: _C.caption.copyWith(fontSize: 9.8)),
          ),
          if (!mobile) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 58,
              child: Text('Дата', textAlign: TextAlign.right, style: _C.caption.copyWith(fontSize: 9.8)),
            ),
          ],
          const SizedBox(width: 30),
        ],
      ),
    );
  }
}

class _BrowserGroupLabel extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final String? hint;

  const _BrowserGroupLabel({
    required this.title,
    required this.count,
    required this.icon,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 7, 6, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _C.greenDark),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(color: _C.text, fontSize: 10.8, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(color: _C.input, borderRadius: BorderRadius.circular(999)),
            child: Text('$count', style: const TextStyle(color: _C.muted, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
          if (hint != null) ...[
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _C.caption.copyWith(fontSize: 9.8),
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

class _BrowserFileRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String folder;
  final String date;
  final String badge;
  final IconData icon;
  final bool active;
  final bool draggable;
  final String previewUrl;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onPreview;

  const _BrowserFileRow({
    required this.title,
    required this.subtitle,
    required this.folder,
    required this.date,
    required this.badge,
    required this.icon,
    required this.active,
    required this.onTap,
    this.draggable = false,
    this.previewUrl = '',
    this.onRename,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 720;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? _C.greenSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.fromLTRB(7, 4, 6, 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: active ? Border.all(color: _C.green.withOpacity(.18)) : null,
            ),
            child: Row(
              children: [
                _FileThumb(
                  icon: icon,
                  active: active,
                  previewUrl: previewUrl,
                  onTap: onPreview,
                ),
                const SizedBox(width: 7),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? _C.greenDark : _C.text,
                          fontSize: 11.8,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              subtitle.isEmpty ? 'Материал' : subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _C.caption.copyWith(fontSize: 9.8),
                            ),
                          ),
                          if (badge.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _TinyBadge(text: badge),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 58,
                    child: Text(
                      date.isEmpty ? '—' : date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: _C.caption.copyWith(fontSize: 9.8),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                if (onRename != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onRename,
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.drive_file_rename_outline_rounded, color: _C.greenDark, size: 16),
                    ),
                  )
                else if (draggable)
                  const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.drag_indicator_rounded, color: _C.muted, size: 16),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.chevron_right_rounded, color: _C.muted, size: 16),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FileThumb extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String previewUrl;
  final VoidCallback? onTap;

  const _FileThumb({
    required this.icon,
    required this.active,
    required this.previewUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = previewUrl.trim().isNotEmpty;

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: hasImage
          ? Image.network(
              previewUrl,
              width: 30,
              height: 30,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                icon,
                color: active ? _C.greenDark : _C.muted,
                size: 17,
              ),
            )
          : Icon(icon, color: active ? _C.greenDark : _C.muted, size: 18),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: active ? Colors.white : _C.input,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: hasImage ? _C.line : Colors.transparent),
            ),
            child: content,
          ),
          if (hasImage)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 9),
              ),
            ),
        ],
      ),
    );
  }
}

class _SchemePreviewDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;

  const _SchemePreviewDialog({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 34,
        vertical: isMobile ? 14 : 28,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? size.width - 20 : 980,
              maxHeight: size.height * .88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 58,
                  padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: _C.line)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _C.greenSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.account_tree_rounded, color: _C.greenDark, size: 20),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _C.text, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _C.caption,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SquareTool(
                        icon: Icons.close_rounded,
                        onTap: () => Get.back(),
                        tooltip: 'Закрыть',
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    color: const Color(0xFFF5F7F6),
                    padding: EdgeInsets.all(isMobile ? 8 : 14),
                    child: InteractiveViewer(
                      minScale: .75,
                      maxScale: 4,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                width: 260,
                                height: 180,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: _C.green,
                                    value: progress.expectedTotalBytes == null
                                        ? null
                                        : progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              width: 320,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _C.line),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_rounded, color: _C.muted, size: 42),
                                  SizedBox(height: 10),
                                  Text(
                                    'Не удалось открыть изображение схемы',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: _C.text, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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

class _TinyBadge extends StatelessWidget {
  final String text;

  const _TinyBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.line),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _C.muted, fontSize: 9.5, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _FinderPlanRow extends StatelessWidget {
  final String title;
  final String folder;
  final String trainer;
  final String date;
  final String materials;
  final bool active;
  final VoidCallback onTap;

  const _FinderPlanRow({
    required this.title,
    required this.folder,
    required this.trainer,
    required this.date,
    required this.materials,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (folder.isNotEmpty) folder,
      if (trainer.isNotEmpty) trainer,
      if (date.isNotEmpty) date,
    ].join(' • ');

    return Material(
      color: active ? _C.greenSoft : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? _C.green.withOpacity(.20) : Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: active ? Colors.white : _C.input,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.description_rounded, color: active ? _C.greenDark : _C.muted, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 13.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(meta.isEmpty ? 'План-конспект' : meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption),
                    if (materials.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _InlineBadges(text: materials),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: active ? _C.greenDark : _C.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}


class _PinnedPlanChip extends StatelessWidget {
  final String title;

  const _PinnedPlanChip({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.green.withOpacity(.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.push_pin_rounded, color: _C.greenDark, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.greenDark,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineBadges extends StatelessWidget {
  final String text;

  const _InlineBadges({required this.text});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: text.split(' • ').where((e) => e.trim().isNotEmpty).map((part) {
        final isScheme = part.toLowerCase().contains('схем');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: isScheme ? const Color(0xFFEAF3FF) : _C.input,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isScheme ? Icons.map_outlined : Icons.attach_file_rounded,
                size: 12,
                color: isScheme ? const Color(0xFF2563EB) : _C.muted,
              ),
              const SizedBox(width: 4),
              Text(
                part,
                style: TextStyle(
                  color: isScheme ? const Color(0xFF1D4ED8) : _C.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FullEditorBanner extends StatelessWidget {
  final String title;
  final String text;
  final VoidCallback onTap;

  const _FullEditorBanner({required this.title, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.greenSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.green.withOpacity(.16)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.dashboard_customize_rounded, color: _C.greenDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.greenDark, fontSize: 13.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.greenDark, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.32)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen_rounded, color: Colors.white, size: 17),
                    SizedBox(width: 6),
                    Text('Открыть', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinderEditorSection extends StatelessWidget {
  final String title;
  final bool editMode;
  final TextEditingController controller;
  final String value;
  final int maxLines;

  const _FinderEditorSection({
    required this.title,
    required this.editMode,
    required this.controller,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (editMode)
            TextField(
              controller: controller,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                filled: true,
                fillColor: _C.input,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.line),
                ),
              ),
            )
          else
            Text(value, style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w700, height: 1.42)),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetaPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
          Text(value, style: const TextStyle(color: _C.text, fontSize: 11.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _HintStrip extends StatelessWidget {
  final String text;
  const _HintStrip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.green.withOpacity(.14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _C.greenDark, size: 18),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: const TextStyle(color: _C.greenDark, fontSize: 12, fontWeight: FontWeight.w800, height: 1.35))),
        ],
      ),
    );
  }
}

class _SquareTool extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  final String? tooltip;

  const _SquareTool({required this.icon, required this.onTap, this.danger = false, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final w = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFF1F2) : _C.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: danger ? const Color(0xFFFECACA) : _C.line),
        ),
        child: Icon(icon, color: danger ? _C.red : _C.greenDark, size: 19),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionPill({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _C.green,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: _C.green.withOpacity(.12), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 7),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const _PrimaryButton({required this.text, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: _C.green,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const _DangerButton({required this.text, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        foregroundColor: _C.red,
        side: const BorderSide(color: Color(0xFFFECACA)),
        minimumSize: const Size(126, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _FinderEmpty extends StatelessWidget {
  final String title;
  final String text;
  final String? actionText;
  final VoidCallback? onTap;

  const _FinderEmpty({required this.title, required this.text, this.actionText, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PlanMark(size: 58),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: _C.h1.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: _C.body),
            if (actionText != null && onTap != null) ...[
              const SizedBox(height: 16),
              _ActionPill(label: actionText!, icon: Icons.open_in_new_rounded, onTap: onTap),
            ],
          ],
        ),
      ),
    );
  }
}

class _CmrEmptyState extends StatelessWidget {
  final String title;
  final String text;
  final String? actionText;
  final VoidCallback? onAction;
  final bool isMobile;

  const _CmrEmptyState({required this.title, required this.text, this.actionText, this.onAction, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.page,
      child: _FinderEmpty(
        title: title,
        text: text,
        actionText: actionText,
        onTap: onAction,
      ),
    );
  }
}
