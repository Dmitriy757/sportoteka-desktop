// lib/presentation/plans/cmr_plans_panel.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/plans/plan_detail_screen.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/presentation/plans/plans_embedded_file_viewer.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
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

enum _UnsavedDraftChoice { stay, openOther, exitWithoutSaving }
enum _ExplorerViewMode { grid, list }

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
  bool _showPreviewPane = true;
  _ExplorerViewMode _viewMode = _ExplorerViewMode.grid;
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

  bool get _hasUnsavedLocalDraft {
    final plan = selectedPlan;
    if (plan == null) return false;

    final isLocalDraft = plan['_is_local_draft'] == true ||
        '${plan['_is_local_draft']}'.toLowerCase() == 'true';

    return _asInt(plan['id'] ?? plan['plan_id']) <= 0 || isLocalDraft;
  }

  Future<_UnsavedDraftChoice> _confirmCloseUnsavedDraft({
    required String openOtherText,
  }) async {
    if (!_hasUnsavedLocalDraft) return _UnsavedDraftChoice.openOther;

    final isMobile = _isMobile(context);

    final result = await Get.dialog<_UnsavedDraftChoice>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 24,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? MediaQuery.of(context).size.width - 28 : 520,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 22,
                    isMobile ? 16 : 20,
                    isMobile ? 16 : 22,
                    16,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFF7ED), Colors.white],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.edit_document,
                          color: Color(0xFFC2410C),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'План не сохранён',
                              style: _C.h1.copyWith(fontSize: isMobile ? 18 : 21),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Открыт новый черновик. Сохраните его или подтвердите переход, чтобы не потерять данные.',
                              style: _C.body.copyWith(fontSize: isMobile ? 12.5 : 13.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 14 : 20,
                    6,
                    isMobile ? 14 : 20,
                    isMobile ? 14 : 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Get.back(result: _UnsavedDraftChoice.stay),
                          icon: const Icon(Icons.save_rounded, size: 19),
                          label: const Text('Остаться и сохранить'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _C.graphite,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Get.back(result: _UnsavedDraftChoice.openOther),
                          icon: const Icon(Icons.folder_open_rounded, size: 19),
                          label: Text(openOtherText),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _C.text,
                            side: const BorderSide(color: _C.line),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => Get.back(result: _UnsavedDraftChoice.exitWithoutSaving),
                          icon: const Icon(Icons.delete_outline_rounded, size: 19),
                          label: const Text('Выйти без сохранения'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFB91C1C),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
      barrierDismissible: false,
    );

    return result ?? _UnsavedDraftChoice.stay;
  }

  Future<void> _selectFolder(Map<String, dynamic>? folder) async {
    final nextFolderId = folder == null ? null : _asInt(folder['id']);
    if (selectedFolderId == nextFolderId) return;

    final draftChoice = await _confirmCloseUnsavedDraft(
      openOtherText: 'Открыть другую папку',
    );
    if (draftChoice == _UnsavedDraftChoice.stay) return;

    if (!mounted) return;
    setState(() {
      selectedPlan = null;
      selectedFolderId = nextFolderId;
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

    await _loadPlansForTeam();
  }

  Future<void> _selectPlan(Map<String, dynamic> plan) async {
    final currentPlanId = _asInt(selectedPlan?['id'] ?? selectedPlan?['plan_id']);
    final nextPlanId = _asInt(plan['id'] ?? plan['plan_id']);
    final sameSavedPlan = currentPlanId > 0 && currentPlanId == nextPlanId;
    if (sameSavedPlan) return;

    final draftChoice = await _confirmCloseUnsavedDraft(
      openOtherText: 'Открыть другой',
    );
    if (draftChoice == _UnsavedDraftChoice.stay) return;

    if (!mounted) return;
    setState(() {
      selectedPlan = plan;
      editMode = false;
      showFoldersList = false;
    });

    _syncEditors();
  }

  Future<void> _handleBack() async {
    if (_hasUnsavedLocalDraft) {
      final draftChoice = await _confirmCloseUnsavedDraft(
        openOtherText: 'Открыть другой',
      );
      if (draftChoice == _UnsavedDraftChoice.stay) return;

      if (!mounted) return;
      setState(() {
        selectedPlan = null;
        editMode = false;
      });

      if (draftChoice == _UnsavedDraftChoice.openOther) {
        _syncEditors();
        return;
      }
    }

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
                                borderRadius: BorderRadius.circular(18),
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
                            fontWeight: FontWeight.w700,
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
                              fontWeight: FontWeight.w700,
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
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Тип папки',
                            style: TextStyle(color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w700),
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
                                  onPressed: () => Get.back(result: _UnsavedDraftChoice.stay),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _C.text,
                                    side: const BorderSide(color: _C.line),
                                    minimumSize: const Size.fromHeight(46),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
                                    backgroundColor: _C.graphite,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size.fromHeight(46),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 12, 16),
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
                        ),
                        child: const Icon(Icons.drive_file_rename_outline_rounded, color: _C.greenDark, size: 24),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Переименовать папку', style: _C.h1.copyWith(fontSize: 20)),
                            const SizedBox(height: 4),
                            Text(
                              'Новое название будет видно в дереве папок и в сетке материалов.',
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
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: Column(
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
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Название папки',
                          hintText: 'Например: Микроциклы, Ведение мяча',
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
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Get.back(result: _UnsavedDraftChoice.stay),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _C.text,
                                side: const BorderSide(color: _C.line),
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              child: const Text('Отмена'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Get.back(result: true),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Сохранить'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _C.graphite,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
        ),
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


  Map<String, dynamic>? _decodeLooseJson(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(trimmed.substring(start, end + 1));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    return null;
  }

  int _planIdFromResponse(Map<String, dynamic> data) {
    final candidates = <dynamic>[
      data['plan_id'],
      data['id'],
      data['new_id'],
      data['insert_id'],
      data['created_id'],
    ];

    final nestedKeys = ['plan', 'item', 'data'];
    for (final key in nestedKeys) {
      final nested = data[key];
      if (nested is Map) {
        candidates.add(nested['plan_id']);
        candidates.add(nested['id']);
      }
    }

    for (final value in candidates) {
      final id = _asInt(value);
      if (id > 0) return id;
    }

    return 0;
  }

  Future<Map<String, dynamic>> _postPlanJson(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    final response = await http
        .post(
          Uri.parse('${TrainingPlansApi.base}/$endpoint'),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 14));

    final data = _decodeLooseJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw 'HTTP ${response.statusCode}: ${response.body}';
    }

    if (data == null) {
      throw response.body.isEmpty ? 'Сервер вернул пустой ответ' : response.body;
    }

    return data;
  }

  Future<void> _createPlanInCurrentFolder() async {
    if (saving) return;

    final folderId = _activeFolderId;
    final folderTitle = folderId > 0 ? selectedFolderTitle : 'Все материалы';
    final now = DateTime.now();
    final date = [
      now.year.toString().padLeft(4, '0'),
      now.month.toString().padLeft(2, '0'),
      now.day.toString().padLeft(2, '0'),
    ].join('-');

    final draft = <String, dynamic>{
      'id': 0,
      'plan_id': 0,
      'club_id': widget.clubId,
      'club_name': widget.clubName,
      'team_id': widget.teamId ?? 0,
      'team_name': widget.teamName,
      'folder_id': folderId,
      'folder_title': folderTitle,
      'folder_name': folderTitle,
      'theme': 'Новый план',
      'cycle_title': 'Недельный цикл',
      'description': '',
      'plan_description': '',
      'plan_date': date,
      'date': date,
      'location': 'Тренировочное поле',
      'players_count': 12,
      'duration_min': 90,
      'created_at': date,
      '_is_local_draft': true,
    };

    if (!mounted) return;

    setState(() {
      selectedPlan = draft;
      editMode = true;
    });

    _syncEditors();

    Get.snackbar(
      'Новый план',
      'Черновик открыт справа. Заполните поля и нажмите сохранить — план будет создан на сервере.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
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
            Uri.parse('${TrainingPlansApi.base}/create_training_plan.php'),
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
            Uri.parse('${TrainingPlansApi.base}/create_training_plan.php'),
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
        // Верхнюю полоску загрузки убрали, чтобы правый блок с кнопками
        // «Сохранить» и действиями не отделялся линией от белого фона.
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
                  backgroundColor: _C.graphite,
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
        final sidebarWidth = width < 1160 ? 238.0 : 252.0;
        final previewWidth = width < 1260 ? 0.0 : (width < 1460 ? 430.0 : 500.0);
        final showPreview = _showPreviewPane && previewWidth > 0;

        return Container(
          color: _C.page,
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: _C.explorerDecoration,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildExplorerTopBar(),
                const _PaneDivider(horizontal: true),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(width: sidebarWidth, child: _buildSidebar()),
                      const _PaneDivider(),
                      Expanded(child: _buildFilesColumn()),
                      if (showPreview) ...[
                        const _PaneDivider(),
                        SizedBox(width: previewWidth, child: _buildPreviewPane()),
                      ],
                    ],
                  ),
                ),
                _buildExplorerStatusBar(showPreview: showPreview),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExplorerTopBar() {
    final subtitle = widget.teamName.isEmpty
        ? widget.clubName
        : '${widget.clubName} • ${widget.teamName}';

    return Container(
      height: 66,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          const _PlanMark(size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Планы',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _C.h1.copyWith(fontSize: 15.4),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _C.caption.copyWith(fontSize: 10.6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ExplorerCommand(
            icon: Icons.note_add_rounded,
            label: 'Новый план',
            primary: true,
            onTap: saving ? null : _createPlanInCurrentFolder,
          ),
          const SizedBox(width: 8),
          _ExplorerCommand(
            icon: Icons.create_new_folder_rounded,
            label: 'Папка',
            onTap: saving ? null : _createFolder,
          ),
          const SizedBox(width: 8),
          _RoundTool(icon: Icons.refresh_rounded, onTap: saving ? null : _load, tooltip: 'Обновить'),
          const SizedBox(width: 8),
          _RoundTool(
            icon: _showPreviewPane ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined,
            onTap: () => setState(() => _showPreviewPane = !_showPreviewPane),
            tooltip: _showPreviewPane ? 'Скрыть область просмотра' : 'Показать область просмотра',
          ),
        ],
      ),
    );
  }

  Widget _buildExplorerStatusBar({required bool showPreview}) {
    final total = _currentChildFolders.length + plans.length + graphics.length + files.length;
    return Container(
      height: 34,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.folder_open_rounded, size: 15, color: _C.muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$selectedFolderTitle • $total объект${_ruPlural(total, '', 'а', 'ов')} • ${plans.length} план${_ruPlural(plans.length, '', 'а', 'ов')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _C.caption.copyWith(fontSize: 10.3),
            ),
          ),
          if (!showPreview)
            Text(
              'Просмотр скрыт',
              style: _C.caption.copyWith(fontSize: 10.2),
            ),
        ],
      ),
    );
  }


  Widget _buildMobileFinder() {
    final showPlan = selectedPlan != null && !showFoldersList;

    return Container(
      color: _C.page,
      child: Column(
        children: [
          _buildMobileTopBar(),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _SoftPanel(
                child: showPlan
                    ? _buildPreviewPane(compact: true)
                    : showFoldersList
                        ? _buildSidebar(mobile: true)
                        : _buildFilesColumn(mobile: true),
              ),
            ),
          ),
        ],
      ),
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
          Padding(
            padding: EdgeInsets.fromLTRB(12, mobile ? 12 : 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Навигация',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _C.h1.copyWith(fontSize: mobile ? 14.2 : 13.6),
                      ),
                    ),
                    _RoundTool(
                      icon: Icons.refresh_rounded,
                      size: 34,
                      onTap: saving ? null : _load,
                      tooltip: 'Обновить',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ExplorerCommand(
                        label: 'Папка',
                        icon: Icons.create_new_folder_rounded,
                        compact: true,
                        onTap: saving ? null : _createFolder,
                      ),
                    ),
                    const SizedBox(width: 7),
                    _RoundTool(
                      icon: Icons.drive_file_rename_outline_rounded,
                      size: 34,
                      onTap: saving ? null : _renameSelectedFolder,
                      tooltip: 'Переименовать папку',
                    ),
                    const SizedBox(width: 7),
                    _RoundTool(
                      icon: Icons.delete_outline_rounded,
                      danger: true,
                      size: 34,
                      onTap: saving ? null : _deleteSelectedFolder,
                      tooltip: 'Удалить папку',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _PaneDivider(horizontal: true),
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
    final childFolders = _currentChildFolders;
    final total = childFolders.length + plans.length + graphics.length + files.length;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildFileToolbar(mobile: mobile),
          const _PaneDivider(horizontal: true),
          Expanded(
            child: RefreshIndicator(
              color: _C.green,
              onRefresh: () async => _loadPlansForTeam(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final hasInfoCard = loadingMaterials || materialsError != null || total == 0;

                  if (_viewMode == _ExplorerViewMode.list && !mobile) {
                    return _buildExplorerListView(
                      childFolders: childFolders,
                      hasInfoCard: hasInfoCard,
                    );
                  }

                  final width = constraints.maxWidth;
                  final columns = mobile
                      ? 2
                      : width >= 820
                          ? 5
                          : width >= 650
                              ? 4
                              : width >= 460
                                  ? 3
                                  : 2;
                  final spacing = mobile ? 10.0 : 10.0;
                  final aspect = mobile ? .82 : .90;

                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(mobile ? 10 : 12, 12, mobile ? 10 : 12, 18),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: aspect,
                    ),
                    itemCount: 1 + total + (hasInfoCard ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (index == 0) {
                        return _CreatePlanGridCard(
                          title: 'Новый план',
                          text: selectedFolderId == null
                              ? 'Создать в корне материалов'
                              : 'Создать в «$selectedFolderTitle»',
                          onTap: saving ? null : _createPlanInCurrentFolder,
                        );
                      }

                      if (loadingMaterials && index == 1) {
                        return const _FinderGridInfoCard(
                          icon: Icons.sync_rounded,
                          title: 'Загрузка',
                          text: 'Собираем файлы, схемы и планы',
                          spinning: true,
                        );
                      }

                      if (!loadingMaterials && materialsError != null && index == 1) {
                        return _FinderGridInfoCard(
                          icon: Icons.warning_amber_rounded,
                          title: 'Ошибка',
                          text: materialsError!,
                        );
                      }

                      if (!loadingMaterials && materialsError == null && total == 0 && index == 1) {
                        return const _FinderGridInfoCard(
                          icon: Icons.folder_open_rounded,
                          title: 'Папка пустая',
                          text: 'Здесь пока нет материалов. Начните с кнопки «Новый план».',
                        );
                      }

                      var i = index - 1;
                      if (hasInfoCard) i -= 1;

                      if (i < childFolders.length) {
                        final f = childFolders[i];
                        final folderId = _asInt(f['id']);
                        final title = _asStr(f['title']).isEmpty ? 'Папка' : _asStr(f['title']);
                        return _FinderGridItem(
                          title: title,
                          subtitle: _folderCounterText(f),
                          icon: Icons.folder_rounded,
                          accentIcon: _folderHasChildren(folderId)
                              ? Icons.keyboard_arrow_right_rounded
                              : Icons.folder_open_rounded,
                          active: selectedFolderId == folderId,
                          onTap: () => _selectFolder(f),
                        );
                      }
                      i -= childFolders.length;

                      if (i < plans.length) {
                        final plan = plans[i];
                        final active = _asInt(plan['id']) == _asInt(selectedPlan?['id']);
                        return _FinderGridItem(
                          title: _planTitle(plan),
                          subtitle: _asStr(plan['trainer_name']).isNotEmpty
                              ? _asStr(plan['trainer_name'])
                              : (_asStr(plan['team_name']).isNotEmpty ? _asStr(plan['team_name']) : 'План-конспект'),
                          meta: _shortDate(_asStr(plan['plan_date']).isNotEmpty
                              ? _asStr(plan['plan_date'])
                              : _asStr(plan['created_at'])),
                          badge: _planBadgesText(plan),
                          icon: Icons.description_rounded,
                          active: active,
                          onTap: () => _selectPlan(plan),
                          onRename: active ? _renameSelectedPlan : null,
                        );
                      }
                      i -= plans.length;

                      if (i < graphics.length) {
                        final g = graphics[i];
                        final title = _asStr(g['title']).isNotEmpty
                            ? _asStr(g['title'])
                            : (_asStr(g['name']).isNotEmpty ? _asStr(g['name']) : 'Схема #${_asInt(g['id'])}');
                        return _DraggableMaterialGridItem(
                          data: g,
                          type: 'scheme',
                          title: title,
                          subtitle: 'Схема',
                          meta: _shortDate(_asStr(g['created_at'])),
                          icon: Icons.account_tree_rounded,
                          previewUrl: _materialImageUrl(g),
                          onPreview: () => _openSchemePreview(g),
                        );
                      }
                      i -= graphics.length;

                      final f = files[i];
                      final title = _asStr(f['title']).isNotEmpty
                          ? _asStr(f['title'])
                          : (_asStr(f['file_name']).isNotEmpty ? _asStr(f['file_name']) : 'Файл #${_asInt(f['id'])}');
                      final ext = _asStr(f['file_ext']).isNotEmpty ? _asStr(f['file_ext']).toUpperCase() : 'Файл';
                      return _DraggableMaterialGridItem(
                        data: f,
                        type: 'file',
                        title: title,
                        subtitle: ext,
                        meta: _shortDate(_asStr(f['created_at'])),
                        icon: _fileIcon(_asStr(f['file_ext']).isNotEmpty ? _asStr(f['file_ext']) : _asStr(f['file_name'])),
                        previewUrl: _materialImageUrl(f),
                        onPreview: () => _openFilePreview(f),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorerListView({
    required List<Map<String, dynamic>> childFolders,
    required bool hasInfoCard,
  }) {
    final rows = <Widget>[];

    rows.add(
      _ExplorerListRow(
        title: 'Новый план',
        subtitle: selectedFolderId == null ? 'Создать в корне материалов' : 'Создать в «$selectedFolderTitle»',
        type: 'План',
        meta: 'Черновик',
        icon: Icons.note_add_rounded,
        active: false,
        create: true,
        onTap: saving ? null : _createPlanInCurrentFolder,
      ),
    );

    if (loadingMaterials) {
      rows.add(const _ExplorerListRow(
        title: 'Загрузка',
        subtitle: 'Собираем файлы, схемы и планы',
        type: 'Система',
        meta: '',
        icon: Icons.sync_rounded,
        active: false,
      ));
    } else if (materialsError != null) {
      rows.add(_ExplorerListRow(
        title: 'Ошибка',
        subtitle: materialsError!,
        type: 'Ошибка',
        meta: '',
        icon: Icons.warning_amber_rounded,
        active: false,
      ));
    } else if (childFolders.isEmpty && plans.isEmpty && graphics.isEmpty && files.isEmpty) {
      rows.add(const _ExplorerListRow(
        title: 'Папка пустая',
        subtitle: 'Здесь пока нет материалов',
        type: 'Папка',
        meta: '',
        icon: Icons.folder_open_rounded,
        active: false,
      ));
    }

    for (final f in childFolders) {
      final folderId = _asInt(f['id']);
      rows.add(_ExplorerListRow(
        title: _asStr(f['title']).isEmpty ? 'Папка' : _asStr(f['title']),
        subtitle: _folderCounterText(f),
        type: 'Папка',
        meta: _folderHasChildren(folderId) ? 'есть подпапки' : '',
        icon: Icons.folder_rounded,
        active: selectedFolderId == folderId,
        onTap: () => _selectFolder(f),
      ));
    }

    for (final plan in plans) {
      final active = _asInt(plan['id']) == _asInt(selectedPlan?['id']);
      rows.add(_ExplorerListRow(
        title: _planTitle(plan),
        subtitle: _asStr(plan['trainer_name']).isNotEmpty
            ? _asStr(plan['trainer_name'])
            : (_asStr(plan['team_name']).isNotEmpty ? _asStr(plan['team_name']) : 'План-конспект'),
        type: 'План',
        meta: _shortDate(_asStr(plan['plan_date']).isNotEmpty ? _asStr(plan['plan_date']) : _asStr(plan['created_at'])),
        badge: _planBadgesText(plan),
        icon: Icons.description_rounded,
        active: active,
        onTap: () => _selectPlan(plan),
        onRename: active ? _renameSelectedPlan : null,
      ));
    }

    for (final g in graphics) {
      rows.add(_ExplorerListRow(
        title: _asStr(g['title']).isNotEmpty
            ? _asStr(g['title'])
            : (_asStr(g['name']).isNotEmpty ? _asStr(g['name']) : 'Схема #${_asInt(g['id'])}'),
        subtitle: 'Схема тренировки',
        type: 'Схема',
        meta: _shortDate(_asStr(g['created_at'])),
        icon: Icons.account_tree_rounded,
        active: false,
        onTap: () => _openSchemePreview(g),
      ));
    }

    for (final f in files) {
      final title = _asStr(f['title']).isNotEmpty
          ? _asStr(f['title'])
          : (_asStr(f['file_name']).isNotEmpty ? _asStr(f['file_name']) : 'Файл #${_asInt(f['id'])}');
      final ext = _asStr(f['file_ext']).isNotEmpty ? _asStr(f['file_ext']).toUpperCase() : 'Файл';
      rows.add(_ExplorerListRow(
        title: title,
        subtitle: ext,
        type: ext,
        meta: _shortDate(_asStr(f['created_at'])),
        icon: _fileIcon(_asStr(f['file_ext']).isNotEmpty ? _asStr(f['file_ext']) : _asStr(f['file_name'])),
        active: false,
        onTap: () => _openFilePreview(f),
      ));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
      children: [
        const _ExplorerListHeader(),
        ...rows,
      ],
    );
  }

  List<Map<String, dynamic>> get _currentChildFolders {
    final parentId = _activeFolderId;
    final list = folders.where((f) => _asInt(f['parent_id']) == parentId).toList();
    list.sort((a, b) => _asStr(a['title']).toLowerCase().compareTo(_asStr(b['title']).toLowerCase()));
    return list;
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

  String _materialFileUrl(Map<String, dynamic> item) {
    final candidates = <String>[
      _asStr(item['file_url']),
      _asStr(item['url']),
      _asStr(item['path']),
      _asStr(item['file_path']),
      _asStr(item['download_url']),
      _asStr(item['secure_url']),
      _asStr(item['file_name']),
    ];

    for (final c in candidates) {
      final value = c.trim();
      if (value.isEmpty || value == 'null') continue;
      return _absoluteMaterialUrl(value);
    }

    return '';
  }

  void _openFilePreview(Map<String, dynamic> file) {
    final title = _asStr(file['title']).isNotEmpty
        ? _asStr(file['title'])
        : (_asStr(file['file_name']).isNotEmpty ? _asStr(file['file_name']) : 'Файл');
    final url = _materialFileUrl(file);

    if (url.isEmpty) {
      Get.snackbar('Файл', 'Не найдена ссылка для просмотра файла');
      return;
    }

    final ext = _fileExtension(url, fallback: _asStr(file['file_ext']));
    final lower = url.toLowerCase();
    final isImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'png' ||
        ext == 'webp';
    final isPdf = lower.endsWith('.pdf') || ext == 'pdf';
    final isOffice = const <String>{'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'rtf'}.contains(ext);
    final isText = const <String>{'txt', 'csv', 'json'}.contains(ext);

    Widget viewer;
    IconData icon;
    String subtitle;

    if (isImage) {
      icon = Icons.image_rounded;
      subtitle = 'Изображение открыто внутри программы';
      viewer = Container(
        color: const Color(0xFFF6F7F8),
        padding: const EdgeInsets.all(14),
        child: InteractiveViewer(
          minScale: .65,
          maxScale: 4,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _CmrFileViewerFallback(url: url, text: 'Не удалось загрузить изображение.'),
            ),
          ),
        ),
      );
    } else if (isPdf) {
      icon = Icons.picture_as_pdf_rounded;
      subtitle = 'PDF открыт внутри программы';
      viewer = Container(
        color: Colors.white,
        child: SfPdfViewer.network(url),
      );
    } else if (isOffice) {
      icon = Icons.article_rounded;
      subtitle = 'Документ открыт внутри программы';
      viewer = PlansEmbeddedFileViewer(
        url: _officeViewerUrl(url),
        sourceUrl: url,
        title: title,
      );
    } else if (isText) {
      icon = Icons.description_rounded;
      subtitle = 'Файл открыт внутри программы';
      viewer = PlansEmbeddedFileViewer(
        url: url,
        sourceUrl: url,
        title: title,
      );
    } else {
      icon = Icons.insert_drive_file_rounded;
      subtitle = 'Предпросмотр файла';
      viewer = _CmrFileViewerFallback(
        url: url,
        text: 'Для этого типа файла нет нативного просмотрщика. Файл оставлен внутри окна программы — ссылку можно скопировать или скачать.',
      );
    }

    Get.dialog(
      _CmrFileWindowDialog(
        title: title,
        subtitle: subtitle,
        icon: icon,
        child: viewer,
      ),
      barrierColor: Colors.black.withOpacity(.18),
      barrierDismissible: false,
    );
  }

  String _fileExtension(String url, {String fallback = ''}) {
    final f = fallback.trim().replaceAll('.', '').toLowerCase();
    if (f.isNotEmpty && f != 'null') return f;

    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).split('?').first.split('#').first;
  }

  String _officeViewerUrl(String url) {
    // Встроенный просмотр Word/Excel/PowerPoint внутри Web/desktop-окна.
    // Не открывает новый браузер, а отдаёт URL в iframe/embedded viewer.
    return 'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(url)}';
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
      padding: EdgeInsets.fromLTRB(mobile ? 10 : 12, mobile ? 8 : 10, mobile ? 10 : 12, mobile ? 8 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildBreadcrumbs()),
              const SizedBox(width: 8),
              if (!mobile) ...[
                _SegmentedIconButton(
                  icon: Icons.grid_view_rounded,
                  active: _viewMode == _ExplorerViewMode.grid,
                  tooltip: 'Плитка',
                  onTap: () => setState(() => _viewMode = _ExplorerViewMode.grid),
                ),
                const SizedBox(width: 5),
                _SegmentedIconButton(
                  icon: Icons.view_list_rounded,
                  active: _viewMode == _ExplorerViewMode.list,
                  tooltip: 'Список',
                  onTap: () => setState(() => _viewMode = _ExplorerViewMode.list),
                ),
              ],
              const SizedBox(width: 8),
              _RoundTool(
                icon: Icons.refresh_rounded,
                size: 34,
                onTap: saving ? null : () => _loadPlansForTeam(),
                tooltip: 'Обновить список',
              ),
              if (selectedPlan != null) ...[
                const SizedBox(width: 6),
                _RoundTool(
                  icon: Icons.drive_file_rename_outline_rounded,
                  size: 34,
                  onTap: saving ? null : _renameSelectedPlan,
                  tooltip: 'Переименовать выбранный план',
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onSubmitted: (_) => _loadPlansForTeam(),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.text),
                  decoration: InputDecoration(
                    hintText: 'Поиск в планах, схемах и файлах',
                    hintStyle: const TextStyle(fontSize: 11, color: _C.muted, fontWeight: FontWeight.w600),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _C.muted),
                    suffixIcon: searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              searchCtrl.clear();
                              _loadPlansForTeam();
                            },
                            icon: const Icon(Icons.close_rounded, size: 17),
                          ),
                    filled: true,
                    fillColor: _C.input,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (selectedPlan != null) ...[
                const SizedBox(width: 8),
                Flexible(child: _PinnedPlanChip(title: _planTitle(selectedPlan!))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    final crumbs = <_ExplorerBreadcrumbData>[
      _ExplorerBreadcrumbData('Все материалы', () => _selectFolder(null)),
    ];

    final activeId = selectedFolderId ?? 0;
    if (activeId > 0) {
      final chain = <Map<String, dynamic>>[];
      Map<String, dynamic>? current = _allFolders.firstWhereOrNull((f) => _asInt(f['id']) == activeId);
      while (current != null) {
        chain.insert(0, current);
        final parentId = _asInt(current['parent_id']);
        current = parentId > 0 ? _allFolders.firstWhereOrNull((f) => _asInt(f['id']) == parentId) : null;
      }
      for (final f in chain) {
        final id = _asInt(f['id']);
        final title = _asStr(f['title']).isEmpty ? 'Папка' : _asStr(f['title']);
        crumbs.add(_ExplorerBreadcrumbData(title, () => _selectFolder(f)));
      }
    }

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _C.input,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: crumbs.length,
        separatorBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 3),
          child: Icon(Icons.chevron_right_rounded, size: 16, color: _C.muted),
        ),
        itemBuilder: (_, index) {
          final c = crumbs[index];
          final active = index == crumbs.length - 1;
          return Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: active ? null : c.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                child: Text(
                  c.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? _C.text : _C.muted,
                    fontSize: 11.2,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
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

    final media = MediaQuery.of(context);

    return Container(
      color: _C.preview,
      child: MediaQuery(
        data: media.copyWith(
          textScaler: TextScaler.linear(compact ? .96 : .92),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: PlanDetailScreen(
                key: ValueKey('cmr_plan_editor_$planId'),
                embedded: true,
                initialArgs: _planDetailArgs(plan),
                onOpenFullscreen: _openFullPlanScreen,
                onSaved: (result) async {
                  final savedPlanId = _asInt(
                    result['plan_id'] ??
                        result['id'] ??
                        result['new_id'] ??
                        result['insert_id'] ??
                        (result['plan'] is Map ? result['plan']['id'] : null) ??
                        (result['data'] is Map ? result['data']['id'] : null),
                  );

                  await _loadPlansForTeam();

                  final targetId = savedPlanId > 0 ? savedPlanId : planId;
                  final refreshed = plans.where((p) => _asInt(p['id']) == targetId).toList();
                  if (!mounted) return;
                  if (refreshed.isNotEmpty) {
                    setState(() => selectedPlan = refreshed.first);
                  }
                },
              ),
            ),

            // Маска на 1 px убирает тонкую верхнюю линию встроенного редактора,
            // не затрагивая кнопки «Сохранить» и остальные действия.
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: ColoredBox(color: Colors.white),
            ),
          ],
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


class _SoftPanel extends StatelessWidget {
  final Widget child;

  const _SoftPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _C.panelDecoration,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _C {
  static const Color page = Color(0xFFF7F8FA);
  static const Color sidebar = Colors.white;
  static const Color preview = Colors.white;

  // Премиальная CMR-палитра: бело-графитовая основа,
  // зелёный используется только как фирменный микро-акцент.
  static const Color graphite = Color(0xFF111827);
  static const Color graphiteSoft = Color(0xFF1F2937);
  static const Color soft = Color(0xFFF8F9FA);
  static const Color input = Color(0xFFF6F7F8);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF087A46);
  static const Color greenSoft = Color(0xFFF3FBF6);
  static const Color greenBorder = Color(0xFFCFEFDD);
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color line = Color(0xFFE5E7EB);
  static const Color red = Color(0xFFD92D20);

  static BoxDecoration get panelDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration get explorerDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.030),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration softCard({double radius = 18}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      );

  static const TextStyle h1 = TextStyle(
    color: text,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.12,
  );

  static const TextStyle body = TextStyle(
    color: muted,
    fontSize: 11.8,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    color: muted,
    fontSize: 10.2,
    fontWeight: FontWeight.w700,
  );
}

class _GenericFilePreviewDialog extends StatelessWidget {
  final String title;
  final String url;

  const _GenericFilePreviewDialog({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: Container(
        width: width < 720 ? width - 44 : 620,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.12),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _RoundTool(icon: Icons.insert_drive_file_rounded, onTap: null, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _C.h1.copyWith(fontSize: 15),
                  ),
                ),
                _RoundTool(icon: Icons.close_rounded, onTap: () => Get.back(), size: 36),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Файл найден, но встроенный просмотр доступен для PDF и изображений. Ссылку можно использовать для загрузки или открытия через системный просмотрщик.',
              style: _C.body,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.input,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.line),
              ),
              child: SelectableText(
                url,
                style: _C.caption.copyWith(fontSize: 10.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CmrFileWindowDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _CmrFileWindowDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  State<_CmrFileWindowDialog> createState() => _CmrFileWindowDialogState();
}

class _CmrFileWindowDialogState extends State<_CmrFileWindowDialog> {
  bool _minimized = false;
  bool _maximized = false;
  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 780;

    if (_minimized) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              Positioned(
                left: isSmall ? 12 : 26,
                bottom: isSmall ? 12 : 24,
                child: _minimizedBar(),
              ),
            ],
          ),
        ),
      );
    }

    final defaultWidth = isSmall ? size.width - 22 : (size.width * .78).clamp(820.0, 1180.0);
    final defaultHeight = isSmall ? size.height - 34 : (size.height * .80).clamp(560.0, 820.0);
    final windowWidth = _maximized ? size.width - 26 : defaultWidth;
    final windowHeight = _maximized ? size.height - 26 : defaultHeight;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            Positioned(
              left: _maximized ? 13 : (size.width - windowWidth) / 2 + _offset.dx,
              top: _maximized ? 13 : (size.height - windowHeight) / 2 + _offset.dy,
              child: SizedBox(
                width: windowWidth,
                height: windowHeight,
                child: _windowBody(isSmall: isSmall),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _minimizedBar() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        height: 54,
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            _FileWindowControl(icon: Icons.open_in_full_rounded, onTap: () => setState(() => _minimized = false)),
            const SizedBox(width: 8),
            Icon(widget.icon, color: _C.muted, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _C.text, fontSize: 12.4, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            _FileWindowControl(icon: Icons.close_rounded, onTap: () => Get.back(), danger: true),
          ],
        ),
      ),
    );
  }

  Widget _windowBody({required bool isSmall}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_maximized ? 22 : 26),
          border: Border.all(color: _C.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.14),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: _maximized ? null : (d) => setState(() => _offset += d.delta),
              child: Container(
                height: isSmall ? 56 : 62,
                padding: EdgeInsets.fromLTRB(isSmall ? 10 : 14, 9, isSmall ? 10 : 14, 9),
                decoration: const BoxDecoration(color: Colors.white),
                child: Row(
                  children: [
                    _FileWindowControl(icon: Icons.close_rounded, onTap: () => Get.back(), danger: true),
                    const SizedBox(width: 7),
                    _FileWindowControl(icon: Icons.remove_rounded, onTap: () => setState(() => _minimized = true)),
                    const SizedBox(width: 7),
                    _FileWindowControl(
                      icon: _maximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
                      onTap: () => setState(() => _maximized = !_maximized),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _C.input,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.line),
                      ),
                      child: Icon(widget.icon, color: _C.muted, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _C.text, fontSize: 14.2, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _C.caption.copyWith(fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _PaneDivider(horizontal: true),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _FileWindowControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;

  const _FileWindowControl({required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFF1F2) : _C.input,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: danger ? const Color(0xFFFECACA) : _C.line),
        ),
        child: Icon(icon, size: 18, color: danger ? _C.red : _C.muted),
      ),
    );
  }
}

class _CmrFileViewerFallback extends StatelessWidget {
  final String url;
  final String text;

  const _CmrFileViewerFallback({required this.url, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7F8),
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _C.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _C.greenSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.greenBorder),
                      ),
                      child: const Icon(Icons.insert_drive_file_rounded, color: _C.greenDark, size: 19),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Файл найден',
                        style: _C.h1.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(text, style: _C.body.copyWith(fontSize: 11.8)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _C.input,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _C.line),
                  ),
                  child: SelectableText(url, style: _C.caption.copyWith(fontSize: 10.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplorerBreadcrumbData {
  final String title;
  final VoidCallback onTap;

  const _ExplorerBreadcrumbData(this.title, this.onTap);
}

class _PaneDivider extends StatelessWidget {
  final bool horizontal;

  const _PaneDivider({this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: horizontal ? double.infinity : 1,
      height: horizontal ? 1 : double.infinity,
      child: const ColoredBox(color: _C.line),
    );
  }
}

class _RoundTool extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  final String? tooltip;
  final double size;

  const _RoundTool({
    required this.icon,
    required this.onTap,
    this.danger = false,
    this.tooltip,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final w = InkWell(
      borderRadius: BorderRadius.circular(size * .35),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFF1F2) : _C.input,
          borderRadius: BorderRadius.circular(size * .35),
          border: Border.all(color: danger ? const Color(0xFFFECACA) : _C.line),
        ),
        child: Icon(icon, color: danger ? _C.red : _C.muted, size: size * .48),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

class _ExplorerCommand extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool compact;

  const _ExplorerCommand({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
      onTap: onTap,
      child: Container(
        height: compact ? 34 : 40,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13),
        decoration: BoxDecoration(
          color: primary ? _C.greenSoft : _C.input,
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          border: Border.all(color: primary ? _C.greenBorder : _C.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary ? _C.greenDark : _C.muted, size: compact ? 16 : 17),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primary ? _C.greenDark : _C.text,
                  fontSize: compact ? 11.2 : 11.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;

  const _SegmentedIconButton({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active ? _C.greenSoft : _C.input,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? _C.greenBorder : _C.line),
          ),
          child: Icon(icon, size: 17, color: active ? _C.greenDark : _C.muted),
        ),
      ),
    );
  }
}

class _ExplorerListHeader extends StatelessWidget {
  const _ExplorerListHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.line)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 42),
          Expanded(flex: 5, child: Text('Имя', style: _C.caption.copyWith(fontSize: 10.3))),
          Expanded(flex: 2, child: Text('Тип', style: _C.caption.copyWith(fontSize: 10.3))),
          Expanded(flex: 2, child: Text('Дата', style: _C.caption.copyWith(fontSize: 10.3))),
          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _ExplorerListRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String type;
  final String meta;
  final String badge;
  final IconData icon;
  final bool active;
  final bool create;
  final VoidCallback? onTap;
  final VoidCallback? onRename;

  const _ExplorerListRow({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.meta,
    required this.icon,
    required this.active,
    this.badge = '',
    this.create = false,
    this.onTap,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: active ? _C.greenSoft : (create ? const Color(0xFFFAFFFC) : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: active ? _C.greenBorder : _C.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : _C.input,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? _C.greenBorder : _C.line),
                  ),
                  child: Icon(icon, color: active || create ? _C.greenDark : _C.muted, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 11.8, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption.copyWith(fontSize: 9.8)),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: Text(type, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption.copyWith(fontSize: 10.2))),
                Expanded(flex: 2, child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption.copyWith(fontSize: 10.2))),
                if (badge.isNotEmpty) _TinyBadge(text: badge),
                SizedBox(
                  width: 36,
                  child: onRename == null
                      ? const Icon(Icons.chevron_right_rounded, size: 18, color: _C.muted)
                      : IconButton(
                          tooltip: 'Переименовать',
                          onPressed: onRename,
                          icon: const Icon(Icons.drive_file_rename_outline_rounded, size: 17, color: _C.greenDark),
                          visualDensity: VisualDensity.compact,
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
        bottom: 5,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: active ? Border.all(color: _C.line) : null,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(.025),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                    color: active ? _C.green : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: hasChildren
                      ? InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onToggle,
                          child: Icon(
                            expanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                            color: active ? _C.graphite : const Color(0xFF98A2B3),
                            size: 18,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: active ? _C.greenSoft : _C.input,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: active ? _C.greenBorder : _C.line),
                  ),
                  child: Icon(
                    system ? Icons.inventory_2_rounded : Icons.folder_rounded,
                    color: active ? _C.greenDark : _C.muted,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? _C.graphite : _C.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _C.caption.copyWith(fontSize: 9.8),
                      ),
                    ],
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
            style: const TextStyle(color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _C.input,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('$count', style: const TextStyle(color: _C.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
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


class _CreatePlanGridCard extends StatelessWidget {
  final String title;
  final String text;
  final VoidCallback? onTap;

  const _CreatePlanGridCard({
    required this.title,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.025),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _C.green,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _C.input,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.line),
                    ),
                    child: const Icon(Icons.note_add_rounded, color: _C.greenDark, size: 22),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.graphite,
                  fontSize: 13.6,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _C.caption.copyWith(fontSize: 10.5, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinderGridInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool spinning;

  const _FinderGridInfoCard({
    required this.icon,
    required this.title,
    required this.text,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _C.softCard(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _C.input,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.line),
            ),
            child: spinning
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2, color: _C.green),
                  )
                : Icon(icon, color: _C.graphite, size: 20),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _C.text, fontSize: 12.8, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: _C.caption.copyWith(height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _FinderGridItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;
  final String badge;
  final IconData icon;
  final IconData? accentIcon;
  final bool active;
  final String previewUrl;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onPreview;

  const _FinderGridItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.onTap,
    this.meta = '',
    this.badge = '',
    this.accentIcon,
    this.previewUrl = '',
    this.onRename,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = previewUrl.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? _C.greenBorder : _C.line, width: active ? 1.2 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(active ? .045 : .025),
                blurRadius: active ? 16 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _C.input,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: active ? _C.greenBorder : _C.line),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: hasImage
                              ? Image.network(
                                  previewUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Icon(icon, color: active ? _C.greenDark : _C.muted, size: 32),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    icon,
                                    color: active ? _C.greenDark : const Color(0xFF98A2B3),
                                    size: icon == Icons.folder_rounded ? 40 : 34,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (active)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _C.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (accentIcon != null)
                      Positioned(
                        right: 7,
                        bottom: 7,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.96),
                            shape: BoxShape.circle,
                            border: Border.all(color: _C.line),
                          ),
                          child: Icon(accentIcon, size: 16, color: _C.graphite),
                        ),
                      ),
                    if (onRename != null)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: onRename,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.96),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _C.line),
                            ),
                            child: const Icon(Icons.drive_file_rename_outline_rounded, color: _C.greenDark, size: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? _C.graphite : _C.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle.isEmpty ? 'Материал' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _C.caption.copyWith(fontSize: 10.2),
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(meta, style: _C.caption.copyWith(fontSize: 9.8)),
                  ],
                ],
              ),
              if (badge.isNotEmpty) ...[
                const SizedBox(height: 5),
                _TinyBadge(text: badge),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DraggableMaterialGridItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final String type;
  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
  final String previewUrl;
  final VoidCallback? onPreview;

  const _DraggableMaterialGridItem({
    required this.data,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.meta,
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

    final child = _FinderGridItem(
      title: title,
      subtitle: subtitle,
      meta: meta,
      badge: type == 'scheme' ? 'схема' : 'файл',
      icon: icon,
      active: false,
      previewUrl: previewUrl,
      onTap: onPreview ?? () {},
      onPreview: onPreview,
      accentIcon: Icons.drag_indicator_rounded,
    );

    return LongPressDraggable<Map<String, dynamic>>(
      data: payload,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 170,
          height: 190,
          child: _FinderGridItem(
            title: title,
            subtitle: 'Отпустите в редакторе',
            meta: meta,
            badge: type == 'scheme' ? 'схема' : 'файл',
            icon: icon,
            active: true,
            previewUrl: previewUrl,
            onTap: () {},
            accentIcon: Icons.add_rounded,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: .45, child: child),
      child: child,
    );
  }
}

class _MaterialsLoading extends StatelessWidget {
  const _MaterialsLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.line)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
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
      color: Colors.white,
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
            style: const TextStyle(color: _C.text, fontSize: 10.8, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: _C.line)),
            child: Text('$count', style: const TextStyle(color: _C.muted, fontSize: 10, fontWeight: FontWeight.w700)),
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
    final compact = width < 640;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.fromLTRB(7, 4, 6, 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
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
                          color: active ? _C.graphite : _C.text,
                          fontSize: 11.8,
                          fontWeight: FontWeight.w700,
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
              color: active ? Colors.white : _C.soft,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _C.line),
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
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _C.greenSoft,
                          borderRadius: BorderRadius.circular(18),
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
                              style: const TextStyle(color: _C.text, fontSize: 15, fontWeight: FontWeight.w700),
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
                                    style: TextStyle(color: _C.text, fontWeight: FontWeight.w700),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.line),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _C.muted, fontSize: 9.5, fontWeight: FontWeight.w700),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: active ? Colors.white : _C.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.description_rounded, color: active ? _C.greenDark : _C.muted, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.greenBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: _C.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          const Icon(Icons.push_pin_rounded, color: _C.greenDark, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.graphite,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w700,
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.line),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 38,
                decoration: BoxDecoration(
                  color: _C.green,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _C.input,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.line),
                ),
                child: const Icon(Icons.dashboard_customize_rounded, color: _C.greenDark, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.graphite, fontSize: 13.2, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: _C.caption.copyWith(height: 1.28)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(color: _C.graphite, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen_rounded, color: _C.green, size: 16),
                    SizedBox(width: 6),
                    Text('Открыть', style: TextStyle(color: Colors.white, fontSize: 11.8, fontWeight: FontWeight.w700)),
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
          Text(title, style: const TextStyle(color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
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
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
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
          Text('$label: ', style: const TextStyle(color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(color: _C.text, fontSize: 11.5, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: _C.green,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _C.greenSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.greenBorder),
            ),
            child: const Icon(Icons.info_outline_rounded, color: _C.greenDark, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(color: _C.graphite, fontSize: 12, fontWeight: FontWeight.w600, height: 1.35))),
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
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFF1F2) : _C.input,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: danger ? const Color(0xFFFECACA) : _C.line),
        ),
        child: Icon(icon, color: danger ? _C.red : _C.muted, size: 19),
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
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _C.greenSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.greenBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _C.greenDark, size: 17),
            const SizedBox(width: 7),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.greenDark, fontSize: 11.8, fontWeight: FontWeight.w800))),
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
      icon: Icon(icon, size: 18, color: _C.green),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: _C.graphite,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
        side: const BorderSide(color: _C.line),
        minimumSize: const Size(126, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
