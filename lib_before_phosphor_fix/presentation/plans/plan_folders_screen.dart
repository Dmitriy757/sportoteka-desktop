// lib/presentation/plans/plan_folders_screen.dart
import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/plans/file_pdf_viewer_screen.dart';
import 'package:sportoteka/presentation/plans/plan_detail_screen.dart';
import 'package:sportoteka/presentation/training_graphics/training_graphics_screen.dart';

import 'api/training_graphics_api.dart';

/// ================== CMR ПАЛИТРА ==================
class ClubDashboardPalette {
  static const primaryGreen = Color(0xFF1F8A4C);
  static const primaryGreenDark = Color(0xFF0B3324);
  static const primaryGreenLight = Color(0xFF7BA88D);
  static const lightGreen = Color(0xFFF1F6F3);
  static const superLightGreen = Color(0xFFF7FAF8);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF111827);
  static const textMuted = Color(0xFF667085);
  static const textLight = Color(0xFF98A2B3);
  static const background = Color(0xFFF6F8F7);
  static const border = Color(0xFFE3E8E5);
  static const divider = Color(0xFFE8EEEA);
  static const darkPanel = Color(0xFF0B3324);

  static const cardShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 18,
    offset: Offset(0, 10),
  );

  static const greenGradient = LinearGradient(
    colors: [Color(0xFF0B3324), Color(0xFF176B3A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _HeaderStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStatChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.66),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// ================== API helpers ==================
class _ApiUtil {
  static Map<String, dynamic> decode(http.Response r) {
    final body = (r.body).trim();

    if (body.isEmpty) {
      return {
        "success": false,
        "message": "Empty response",
        "statusCode": r.statusCode,
      };
    }

    final lower = body.toLowerCase();
    if (body.startsWith("<") ||
        lower.contains("<br") ||
        lower.contains("<b>") ||
        lower.contains("<html")) {
      return {
        "success": false,
        "message": "Server returned HTML (not JSON). Check PHP warnings/errors.",
        "raw": body.length > 2000 ? body.substring(0, 2000) : body,
        "statusCode": r.statusCode,
      };
    }

    try {
      final j = json.decode(body);
      if (j is Map<String, dynamic>) return j;
      return {
        "success": false,
        "message": "Bad JSON: not a map",
        "raw": body,
        "statusCode": r.statusCode,
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Bad JSON: $e",
        "raw": body.length > 2000 ? body.substring(0, 2000) : body,
        "statusCode": r.statusCode,
      };
    }
  }
}

/// ================== API (folders) ==================
class PlanFoldersApi {
  static const String base = "https://sportotekaapp.ru/api";

  static Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    final r = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: jsonEncode(body),
    );

    debugPrint("POST $url");
    debugPrint("REQ: ${jsonEncode(body)}");
    debugPrint("RES(${r.statusCode}): ${r.body}");

    return _ApiUtil.decode(r);
  }

  static Future<Map<String, dynamic>> list({required int clubId}) async {
    return _postJson("$base/list_plan_folders.php", {"club_id": clubId});
  }

  static Future<Map<String, dynamic>> create({
    required int clubId,
    int? parentId,
    required String title,
    required String type,
    required int createdBy,
  }) async {
    final r = await http.post(
      Uri.parse("$base/create_plan_folder.php"),
      body: {
        "club_id": clubId.toString(),
        "parent_id": (parentId ?? 0).toString(),
        "name": title.trim(),
        "title": title.trim(),
        "type": type,
        "created_by": createdBy.toString(),
      },
    );

    return _ApiUtil.decode(r);
  }

  static Future<Map<String, dynamic>> rename({
    required int clubId,
    required int folderId,
    required String title,
  }) async {
    final t = title.trim();
    return _postJson("$base/rename_plan_folder.php", {
      "club_id": clubId,
      "folder_id": folderId,
      "title": t,
      "name": t,
    });
  }

  static Future<Map<String, dynamic>> remove({
    required int clubId,
    required int folderId,
  }) async {
    return _postJson("$base/delete_plan_folder.php", {
      "club_id": clubId,
      "folder_id": folderId,
    });
  }
}

/// ================== API (plans list + delete) ==================
class TrainingPlansApi {
  static const String base = "https://sportotekaapp.ru/api";

  static Future<Map<String, dynamic>> listPlans({
    required int clubId,
    int teamId = 0,
    int? folderId,
  }) async {
    final safeFolderId = folderId ?? 0;

    final payload = <String, dynamic>{
      "club_id": clubId,
      "clubId": clubId,
      "team_id": teamId,
      "teamId": teamId,
      "folder_id": safeFolderId,
      "folderId": safeFolderId,
    };

    final r = await http.post(
      Uri.parse("$base/list_training_plans.php"),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: jsonEncode(payload),
    );

    return _ApiUtil.decode(r);
  }

  static Future<Map<String, dynamic>> deletePlan({
    required int clubId,
    required int planId,
  }) async {
    final payload = <String, dynamic>{
      "club_id": clubId,
      "clubId": clubId,
      "plan_id": planId,
      "planId": planId,
    };

    final r = await http.post(
      Uri.parse("$base/delete_training_plan.php"),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: jsonEncode(payload),
    );

    return _ApiUtil.decode(r);
  }
}

/// ================== API (files) ==================
class TrainingFilesApi {
  static const String base = "https://sportotekaapp.ru/api";

  static Future<Map<String, dynamic>> list({
    required int clubId,
    required int teamId,
    required int folderId,
  }) async {
    final r = await http.post(
      Uri.parse("$base/list_files.php"),
      body: {
        "club_id": clubId.toString(),
        "team_id": teamId.toString(),
        "folder_id": folderId.toString(),
      },
    );

    return _ApiUtil.decode(r);
  }

  static Future<Map<String, dynamic>> deleteFile({
    required int clubId,
    required int fileId,
  }) async {
    final r = await http.post(
      Uri.parse("$base/delete_file.php"),
      body: {
        "club_id": clubId.toString(),
        "id": fileId.toString(),
      },
    );

    return _ApiUtil.decode(r);
  }
}

/// ================== API (graphics delete fallback) ==================
class _TrainingGraphicsDeleteApi {
  static const String base = "https://sportotekaapp.ru/api";

  static Future<Map<String, dynamic>> deleteGraphic({
    required int clubId,
    required int graphicId,
  }) async {
    final payload = <String, dynamic>{
      "club_id": clubId,
      "clubId": clubId,
      "id": graphicId,
      "graphic_id": graphicId,
    };

    final r = await http.post(
      Uri.parse("$base/delete_training_graphic.php"),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: jsonEncode(payload),
    );

    return _ApiUtil.decode(r);
  }
}

/// ================== SCREEN ==================
class PlanFoldersScreen extends StatefulWidget {
  final int clubId;
  final String clubName;

  final bool browsePlansMode;
  final int? teamId;

  final bool selectMode;
  final bool selectGraphicsMode;
  final List<int> preselectedGraphicIds;

  final int? initialParentId;
  final String? initialParentTitle;

  const PlanFoldersScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.teamId,
    this.selectMode = false,
    this.selectGraphicsMode = false,
    this.preselectedGraphicIds = const [],
    this.browsePlansMode = false,
    this.initialParentId,
    this.initialParentTitle,
  });

  @override
  State<PlanFoldersScreen> createState() => _PlanFoldersScreenState();
}

enum _ViewMode { grid, list }

class _PlanFoldersScreenState extends State<PlanFoldersScreen> {
  bool loading = true;
  bool busy = false;
  String? error;

  bool loadingGraphics = false;
  String? graphicsError;
  List<Map<String, dynamic>> graphics = [];

  bool loadingPlans = false;
  String? plansError;
  List<Map<String, dynamic>> plans = [];

  bool loadingFiles = false;
  String? filesError;
  List<Map<String, dynamic>> files = [];

  double fileUploadProgress = 0;
  bool uploadingFile = false;
  String uploadFileLabel = "";

  int? parentId;
  String parentTitle = "Все материалы";

  final searchCtrl = TextEditingController();
  final List<Map<String, dynamic>> crumbs = [];
  List<Map<String, dynamic>> folders = [];
  List<dynamic> _tree = [];

  _ViewMode viewMode = _ViewMode.list;

  final Map<int, int> _folderItemsCountCache = {};
  final Map<int, bool> _folderItemsCountLoading = {};

  final Set<int> _selectedGraphics = <int>{};

  @override
  void initState() {
    super.initState();

    parentId = (widget.initialParentId == null || widget.initialParentId == 0)
        ? null
        : widget.initialParentId;

    parentTitle = widget.initialParentTitle?.trim().isNotEmpty == true
        ? widget.initialParentTitle!.trim()
        : "Все материалы";

    crumbs.clear();
    crumbs.add({"id": null, "title": "Все материалы"});

    if (parentId != null) {
      crumbs.add({"id": parentId, "title": parentTitle});
    }

    _selectedGraphics.addAll(widget.preselectedGraphicIds.where((x) => x > 0));

    _load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) {
      if (v.isEmpty || v == "null") return 0;
      return int.tryParse(v) ?? 0;
    }
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return 0;
  }

  String _asStr(dynamic v) => (v ?? "").toString();

  bool get _isSearching => searchCtrl.text.trim().isNotEmpty;

  bool get _isSelectGraphics => widget.selectGraphicsMode == true;

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final r = await PlanFoldersApi.list(clubId: widget.clubId);

      if (r["success"] != true) {
        setState(() {
          loading = false;
          error = (r["message"] ?? "Не удалось загрузить папки").toString();
        });
        return;
      }

      _tree = (r["tree"] as List?) ?? [];
      folders = _extractFolders(_tree, parentId);

      final query = searchCtrl.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        folders = folders
            .where(
              (folder) => _asStr(folder["title"]).toLowerCase().contains(query),
            )
            .toList();
      }

      setState(() => loading = false);

      await Future.wait([
        _loadPlans(),
        _loadGraphics(),
        _loadFiles(),
      ]);

      if (!_isSearching) {
        _warmUpFolderCounts(folders);
      }
    } catch (e) {
      setState(() {
        loading = false;
        error = "Ошибка загрузки: $e";
      });
    }
  }

  List<Map<String, dynamic>> _extractFolders(
    List<dynamic> tree,
    int? targetParentId,
  ) {
    List<Map<String, dynamic>> result = [];

    void traverse(List<dynamic> nodes) {
      for (final node in nodes) {
        if (node is! Map) continue;

        final map = Map<String, dynamic>.from(node);
        final nodeParentId = _asInt(map["parent_id"]);

        if (nodeParentId == (targetParentId ?? 0)) {
          result.add(map);
        }

        final children = (map["children"] as List?) ?? [];
        if (children.isNotEmpty) {
          traverse(children);
        }
      }
    }

    traverse(tree);
    return result;
  }

  Future<void> _loadGraphics() async {
    setState(() {
      loadingGraphics = true;
      graphicsError = null;
    });

    final int teamId = widget.teamId ?? 0;

    try {
      final r = await TrainingGraphicsApi.list(
        clubId: widget.clubId,
        teamId: teamId,
        folderId: parentId ?? 0,
      );

      if (r["success"] != true) {
        throw Exception((r["message"] ?? "Не удалось загрузить схемы").toString());
      }

      final items = (r["items"] as List?) ?? [];
      var list =
          items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      final query = searchCtrl.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        list = list
            .where((g) => _asStr(g["title"]).toLowerCase().contains(query))
            .toList();
      }

      setState(() {
        graphics = list;
        loadingGraphics = false;
      });
    } catch (e) {
      setState(() {
        loadingGraphics = false;
        graphicsError = "Ошибка загрузки схем: $e";
      });
    }
  }

  Future<void> _loadPlans() async {
    setState(() {
      loadingPlans = true;
      plansError = null;
    });

    final int teamId = widget.teamId ?? 0;

    try {
      final r = await TrainingPlansApi.listPlans(
        clubId: widget.clubId,
        teamId: teamId,
        folderId: parentId ?? 0,
      );

      if (r["success"] != true) {
        throw Exception((r["message"] ?? "Не удалось загрузить планы").toString());
      }

      final items = (r["items"] as List?) ?? (r["data"] as List?) ?? [];
      var list =
          items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      final query = searchCtrl.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        list = list.where((p) {
          final title = _asStr(p["cycle_title"]).toLowerCase();
          final theme = _asStr(p["theme"]).toLowerCase();
          final trainer = _asStr(p["trainer_name"]).toLowerCase();
          final team = _asStr(p["team_name"]).toLowerCase();
          final createdAt = _asStr(p["created_at"]).toLowerCase();
          final date = _asStr(p["plan_date"]).toLowerCase();
          return title.contains(query) ||
              theme.contains(query) ||
              trainer.contains(query) ||
              team.contains(query) ||
              createdAt.contains(query) ||
              date.contains(query);
        }).toList();
      }

      list.sort((a, b) {
        final ad = _safeDate(
          _asStr(a["created_at"]).isNotEmpty
              ? _asStr(a["created_at"])
              : _asStr(a["plan_date"]),
        );
        final bd = _safeDate(
          _asStr(b["created_at"]).isNotEmpty
              ? _asStr(b["created_at"])
              : _asStr(b["plan_date"]),
        );
        return bd.compareTo(ad);
      });

      setState(() {
        plans = list;
        loadingPlans = false;
      });
    } catch (e) {
      setState(() {
        loadingPlans = false;
        plansError = "Ошибка загрузки планов: $e";
      });
    }
  }

  Future<void> _loadFiles() async {
    setState(() {
      loadingFiles = true;
      filesError = null;
    });

    final int teamId = widget.teamId ?? 0;

    try {
      final r = await TrainingFilesApi.list(
        clubId: widget.clubId,
        teamId: teamId,
        folderId: parentId ?? 0,
      );

      if (r["success"] != true) {
        throw Exception((r["message"] ?? "Не удалось загрузить файлы").toString());
      }

      final items = (r["items"] as List?) ?? [];
      var list =
          items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      final query = searchCtrl.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        list = list.where((file) {
          final title = _asStr(file["title"]).toLowerCase();
          final fileName = _asStr(file["file_name"]).toLowerCase();
          final ext = _asStr(file["file_ext"]).toLowerCase();
          return title.contains(query) ||
              fileName.contains(query) ||
              ext.contains(query);
        }).toList();
      }

      setState(() {
        files = list;
        loadingFiles = false;
      });
    } catch (e) {
      setState(() {
        loadingFiles = false;
        filesError = "Ошибка загрузки файлов: $e";
      });
    }
  }

  DateTime _safeDate(String s) {
    if (s.trim().isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    final normalized = s.trim().replaceAll('T', ' ');
    final dt = DateTime.tryParse(normalized) ??
        DateTime.tryParse(normalized.split(' ').first);
    return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _goIntoFolder(Map<String, dynamic> folder) {
    final id = _asInt(folder["id"]);
    final title = _asStr(folder["title"]).trim();

    setState(() {
      parentId = id;
      parentTitle = title.isEmpty ? "Папка" : title;

      if (crumbs.isEmpty || crumbs.last["id"] != id) {
        crumbs.add({"id": id, "title": parentTitle});
      }

      searchCtrl.clear();
    });

    _load();
  }

  void _goToCrumb(int index) {
    final target = crumbs[index];
    final targetId = target["id"] as int?;
    final normalizedId = (targetId == null || targetId == 0) ? null : targetId;

    setState(() {
      parentId = normalizedId;
      parentTitle = (target["title"] ?? "Все материалы").toString();
      while (crumbs.length > index + 1) {
        crumbs.removeLast();
      }
      searchCtrl.clear();
    });

    _load();
  }

  void _warmUpFolderCounts(List<Map<String, dynamic>> list) {
    for (final f in list) {
      final fid = _asInt(f["id"]);
      if (fid <= 0) continue;
      if (_folderItemsCountCache.containsKey(fid)) continue;
      _loadFolderItemsCount(fid);
    }
  }

  Future<void> _loadFolderItemsCount(int folderId) async {
    if (_folderItemsCountLoading[folderId] == true) return;
    _folderItemsCountLoading[folderId] = true;

    try {
      final int teamId = widget.teamId ?? 0;

      final results = await Future.wait([
        TrainingPlansApi.listPlans(
          clubId: widget.clubId,
          teamId: teamId,
          folderId: folderId,
        ),
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

      final plansResp = results[0];
      final graphicsResp = results[1];
      final filesResp = results[2];

      final plansItems =
          (plansResp["items"] as List?) ?? (plansResp["data"] as List?) ?? const [];
      final graphicsItems = (graphicsResp["items"] as List?) ?? const [];
      final filesItems = (filesResp["items"] as List?) ?? const [];

      final count = plansItems.length + graphicsItems.length + filesItems.length;

      if (!mounted) return;
      setState(() {
        _folderItemsCountCache[folderId] = count;
      });
    } catch (_) {
      //
    } finally {
      _folderItemsCountLoading[folderId] = false;
    }
  }

  int _folderCount(Map<String, dynamic> folder) {
    final fid = _asInt(folder["id"]);
    if (_folderItemsCountCache.containsKey(fid)) {
      return _folderItemsCountCache[fid] ?? 0;
    }

    final raw = folder["items_count"];
    final fromApi = raw is int ? raw : int.tryParse((raw ?? "0").toString()) ?? 0;

    if (fid > 0) {
      _loadFolderItemsCount(fid);
    }
    return fromApi;
  }

  void _toggleGraphicSelected(int gid) {
    if (gid <= 0) return;
    setState(() {
      if (_selectedGraphics.contains(gid)) {
        _selectedGraphics.remove(gid);
      } else {
        _selectedGraphics.add(gid);
      }
    });
  }

  void _attachSelectedAndClose() {
    if (_selectedGraphics.isEmpty) return;
    Get.back(result: _selectedGraphics.toList());
  }

  Future<void> _deletePlan(Map<String, dynamic> plan) async {
    final planId = _asInt(plan["id"]);
    if (planId <= 0) return;

    final title = _asStr(plan["theme"]).trim().isNotEmpty
        ? _asStr(plan["theme"]).trim()
        : "План #$planId";

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Удалить план?"),
        content: Text(
          "План «$title» будет удалён. Это действие нельзя отменить.",
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("Отмена"),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => busy = true);
    try {
      final r = await TrainingPlansApi.deletePlan(
        clubId: widget.clubId,
        planId: planId,
      );
      if (r["success"] == true) {
        _showSuccessSnackbar("План удалён");
        await _loadPlans();
      } else {
        _showErrorSnackbar(r["message"] ?? "Не удалось удалить");
      }
    } catch (e) {
      _showErrorSnackbar("Сетевая ошибка: $e");
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deleteGraphic(Map<String, dynamic> graphic) async {
    final gid = _asInt(graphic["id"]);
    if (gid <= 0) return;

    final title = _asStr(graphic["title"]).trim().isNotEmpty
        ? _asStr(graphic["title"]).trim()
        : "Схема #$gid";

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Удалить схему?"),
        content: Text(
          "Схема «$title» будет удалена. Это действие нельзя отменить.",
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("Отмена"),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => busy = true);
    try {
      final r = await _TrainingGraphicsDeleteApi.deleteGraphic(
        clubId: widget.clubId,
        graphicId: gid,
      );
      if (r["success"] == true) {
        _showSuccessSnackbar("Схема удалена");
        await _loadGraphics();
      } else {
        _showErrorSnackbar(r["message"] ?? "Не удалось удалить");
      }
    } catch (e) {
      _showErrorSnackbar("Сетевая ошибка: $e");
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deleteFile(Map<String, dynamic> file) async {
    final fileId = _asInt(file["id"]);
    if (fileId <= 0) return;

    final title = _asStr(file["title"]).trim().isNotEmpty
        ? _asStr(file["title"]).trim()
        : "Файл #$fileId";

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Удалить файл?"),
        content: Text(
          "Файл «$title» будет удалён. Это действие нельзя отменить.",
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("Отмена"),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => busy = true);
    try {
      final r = await TrainingFilesApi.deleteFile(
        clubId: widget.clubId,
        fileId: fileId,
      );

      if (r["success"] == true) {
        _showSuccessSnackbar("Файл удалён");
        await _loadFiles();
        await _load();
      } else {
        _showErrorSnackbar(r["message"] ?? "Не удалось удалить файл");
      }
    } catch (e) {
      _showErrorSnackbar("Сетевая ошибка: $e");
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      "Успешно",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: ClubDashboardPalette.primaryGreenDark,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      "Ошибка",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  String _getEstimatedTime() {
    final remaining = 1.0 - (fileUploadProgress / 100);
    if (remaining <= 0) return "завершено";
    final seconds = (remaining * 30).ceil();
    if (seconds < 60) return "$seconds сек";
    return "${seconds ~/ 60} мин ${seconds % 60} сек";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubDashboardPalette.background,
      appBar: _buildAppBar(),
      floatingActionButton: _buildFloatingActions(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    final title = widget.selectMode
        ? "Выбор папки"
        : (_isSelectGraphics ? "Выбор схем" : "Планы и схемы");

    return AppBar(
      elevation: 0,
      backgroundColor: ClubDashboardPalette.background,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: ClubDashboardPalette.text),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: ClubDashboardPalette.text,
              fontSize: 18,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.clubName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: ClubDashboardPalette.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        if (_isSelectGraphics)
          TextButton(
            onPressed: _selectedGraphics.isEmpty ? null : _attachSelectedAndClose,
            child: Text(
              "Прикрепить (${_selectedGraphics.length})",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _selectedGraphics.isEmpty
                    ? const Color(0xFF9CA3AF)
                    : ClubDashboardPalette.text,
              ),
            ),
          ),
        if (widget.selectMode)
          IconButton(
            tooltip: "Выбрать эту папку",
            onPressed: () {
              if (parentId == null || parentId! <= 0) {
                _showErrorSnackbar("Откройте нужную папку и нажмите ✓");
                return;
              }
              Navigator.pop(context, {
                "id": parentId,
                "title": parentTitle,
              });
            },
            icon: Container(
              decoration: const BoxDecoration(
                color: ClubDashboardPalette.primaryGreenDark,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            ),
          ),
        IconButton(
          tooltip: "Обновить",
          onPressed: loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildFloatingActions() {
    if (widget.selectMode || _isSelectGraphics) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.extended(
      heroTag: "fab_add_main",
      onPressed: busy || uploadingFile ? null : _showAddMenu,
      backgroundColor: ClubDashboardPalette.primaryGreenDark,
      foregroundColor: Colors.white,
      icon: uploadingFile
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.add_rounded),
      label: Text(
        uploadingFile
            ? "Загрузка ${fileUploadProgress.toStringAsFixed(0)}%"
            : "Добавить",
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: ClubDashboardPalette.primaryGreenDark,
        ),
      );
    }

    if (error != null) {
      return _ErrorView(text: error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: ClubDashboardPalette.primaryGreenDark,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeaderCard(),
                const SizedBox(height: 14),
                _buildCrumbsBar(),
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 14),
                if (uploadingFile) ...[
                  _buildFileUploadProgressCard(),
                  const SizedBox(height: 14),
                ],
              ]),
            ),
          ),
          if (!_isSearching)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildViewModeToggle(),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final folderLabel = parentId == null ? "Корень" : "В папке";
    final isTablet = MediaQuery.of(context).size.width >= 760;

    return Container(
      padding: EdgeInsets.all(isTablet ? 22 : 18),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.darkPanel,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: ClubDashboardPalette.darkPanel.withOpacity(0.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isTablet ? 72 : 58,
            height: isTablet ? 72 : 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.library_books_rounded,
              color: ClubDashboardPalette.primaryGreenDark,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.clubName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: isTablet ? 24 : 19,
                    height: 1.06,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "CMR-база тренировочных материалов: папки, планы, схемы и файлы",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 13 : 12,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeaderStatChip(label: "Папки", value: folders.length.toString()),
                    _HeaderStatChip(label: "Планы", value: plans.length.toString()),
                    _HeaderStatChip(label: "Схемы", value: graphics.length.toString()),
                    _HeaderStatChip(label: "Файлы", value: files.length.toString()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  parentId == null ? Icons.home_rounded : Icons.folder_open_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  folderLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCrumbsBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ClubDashboardPalette.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ClubDashboardPalette.border),
        ),
        child: Row(
          children: crumbs.asMap().entries.map((entry) {
            final index = entry.key;
            final crumb = entry.value;
            final isLast = index == crumbs.length - 1;

            return Row(
              children: [
                GestureDetector(
                  onTap: isLast ? null : () => _goToCrumb(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      crumb["title"]?.toString() ?? "",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isLast
                            ? ClubDashboardPalette.primaryGreen
                            : ClubDashboardPalette.textMuted,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ClubDashboardPalette.border),
        boxShadow: const [ClubDashboardPalette.cardShadow],
      ),
      child: TextField(
        controller: searchCtrl,
        onChanged: (_) => _load(),
        style: const TextStyle(
          color: ClubDashboardPalette.text,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: "Поиск по папкам, планам, схемам и файлам…",
          hintStyle: const TextStyle(
            color: ClubDashboardPalette.textLight,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: ClubDashboardPalette.primaryGreenDark,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          suffixIcon: searchCtrl.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchCtrl.clear();
                    _load();
                  },
                  icon: const Icon(Icons.close_rounded, size: 20),
                )
              : null,
        ),
      ),
    );
  }


  Widget _buildViewModeToggle() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildViewModeButton(
              mode: _ViewMode.grid,
              icon: Icons.grid_view_rounded,
              label: "Сетка",
              isActive: viewMode == _ViewMode.grid,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildViewModeButton(
              mode: _ViewMode.list,
              icon: Icons.list_rounded,
              label: "Список",
              isActive: viewMode == _ViewMode.list,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildViewModeButton({
    required _ViewMode mode,
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return TextButton(
      onPressed: () => setState(() => viewMode = mode),
      style: TextButton.styleFrom(
        backgroundColor: isActive
            ? ClubDashboardPalette.primaryGreenDark
            : ClubDashboardPalette.superLightGreen,
        foregroundColor: isActive ? Colors.white : ClubDashboardPalette.textMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: isActive ? Colors.white : ClubDashboardPalette.textMuted,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: isActive ? Colors.white : ClubDashboardPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final hasFolders = folders.isNotEmpty;
    final hasGraphics = graphics.isNotEmpty;
    final hasFiles = files.isNotEmpty;

    final hasPlans = plans.isNotEmpty;
    final showPlans = !_isSelectGraphics && hasPlans;

    final nothingToShow =
        !hasFolders && !hasGraphics && !showPlans && !hasFiles;

    if (nothingToShow) {
      return SliverFillRemaining(
        child: _EmptyState(
          title: "Здесь пока пусто",
          subtitle: _isSelectGraphics
              ? "В этой папке нет схем. Перейдите в другую папку или создайте схему."
              : "Создайте первую папку, план или загрузите файл",
          icon: Icons.folder_open_rounded,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (hasFolders) ...[
            _buildSectionTitle(
              title: "Папки",
              count: folders.length,
              icon: Icons.folder_rounded,
            ),
            const SizedBox(height: 12),
            viewMode == _ViewMode.grid ? _buildFoldersGrid() : _buildFoldersList(),
            const SizedBox(height: 24),
          ],
          if (showPlans) ...[
            _buildSectionTitle(
              title: "Планы тренировок",
              count: plans.length,
              icon: Icons.menu_book_rounded,
            ),
            const SizedBox(height: 12),
            viewMode == _ViewMode.grid ? _buildPlansGrid() : _buildPlansList(),
            const SizedBox(height: 24),
          ],
          if (hasGraphics) ...[
            _buildSectionTitle(
              title: "Схемы тренировок",
              count: graphics.length,
              icon: Icons.sports_soccer_rounded,
            ),
            const SizedBox(height: 12),
            viewMode == _ViewMode.grid
                ? _buildGraphicsGrid()
                : _buildGraphicsList(),
            const SizedBox(height: 24),
          ],
          if (hasFiles) ...[
            _buildSectionTitle(
              title: "Файлы",
              count: files.length,
              icon: Icons.attach_file_rounded,
            ),
            const SizedBox(height: 12),
            viewMode == _ViewMode.grid ? _buildFilesGrid() : _buildFilesList(),
            const SizedBox(height: 24),
          ],
        ]),
      ),
    );
  }

  int _crossAxisCountForWidth(double w) {
    if (w >= 900) return 4;
    if (w >= 700) return 3;
    if (w >= 450) return 2;
    return 2;
  }

  Widget _buildFoldersGrid() {
    final w = MediaQuery.of(context).size.width;
    final crossAxisCount = _crossAxisCountForWidth(w);
    final childAspectRatio = w < 400 ? 1.05 : (w < 500 ? 1.0 : 1.12);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final f = folders[index];
        final count = _folderCount(f);
        return _FolderGridItem(
          folder: f,
          itemsCount: count,
          onTap: _goIntoFolder,
          onRename: (widget.selectMode || _isSelectGraphics)
              ? null
              : _renameFolder,
          onDelete: (widget.selectMode || _isSelectGraphics)
              ? null
              : _deleteFolder,
        );
      },
    );
  }

  Widget _buildFoldersList() {
    return Column(
      children: folders.map((folder) {
        final count = _folderCount(folder);
        return _FolderListItem(
          folder: folder,
          itemsCount: count,
          onTap: _goIntoFolder,
          onRename: (widget.selectMode || _isSelectGraphics)
              ? null
              : _renameFolder,
          onDelete: (widget.selectMode || _isSelectGraphics)
              ? null
              : _deleteFolder,
        );
      }).toList(),
    );
  }

  Widget _buildPlansGrid() {
    final w = MediaQuery.of(context).size.width;
    final crossAxisCount = _crossAxisCountForWidth(w);
    final childAspectRatio = w < 400 ? 1.10 : (w < 500 ? 1.04 : 1.16);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: plans.length,
      itemBuilder: (context, index) => _PlanGridItem(
        plan: plans[index],
        onTap: _openPlan,
        onDelete: (widget.selectMode || _isSelectGraphics)
            ? null
            : _deletePlan,
      ),
    );
  }

  Widget _buildPlansList() {
    return Column(
      children: plans
          .map(
            (plan) => _PlanListItem(
              plan: plan,
              onTap: _openPlan,
              onDelete: (widget.selectMode || _isSelectGraphics)
                  ? null
                  : _deletePlan,
            ),
          )
          .toList(),
    );
  }

  Widget _buildGraphicsGrid() {
    final w = MediaQuery.of(context).size.width;
    final crossAxisCount = _crossAxisCountForWidth(w);
    final childAspectRatio = w < 400 ? 0.98 : (w < 500 ? 0.94 : 1.06);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: graphics.length,
      itemBuilder: (context, index) {
        final g = graphics[index];
        final gid = _asInt(g["id"]);
        final selected = _selectedGraphics.contains(gid);

        return _GraphicGridItem(
          graphic: g,
          onTap: _isSelectGraphics
              ? (_) => _toggleGraphicSelected(gid)
              : _openGraphic,
          onDelete: (widget.selectMode || _isSelectGraphics)
              ? null
              : _deleteGraphic,
          selectMode: _isSelectGraphics,
          selected: selected,
          onAttachTap: () => _toggleGraphicSelected(gid),
        );
      },
    );
  }

  Widget _buildGraphicsList() {
    return Column(
      children: graphics.map((g) {
        final gid = _asInt(g["id"]);
        final selected = _selectedGraphics.contains(gid);

        return _GraphicListItem(
          graphic: g,
          onTap: _isSelectGraphics
              ? (_) => _toggleGraphicSelected(gid)
              : _openGraphic,
          onDelete: (widget.selectMode || _isSelectGraphics)
              ? null
              : _deleteGraphic,
          selectMode: _isSelectGraphics,
          selected: selected,
          onAttachTap: () => _toggleGraphicSelected(gid),
        );
      }).toList(),
    );
  }

  Widget _buildFilesGrid() {
    final w = MediaQuery.of(context).size.width;
    final crossAxisCount = _crossAxisCountForWidth(w);
    final childAspectRatio = w < 400 ? 1.05 : (w < 500 ? 1.0 : 1.10);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) => _FileGridItem(
        file: files[index],
        onTap: _openFile,
        onDelete: (widget.selectMode || _isSelectGraphics)
            ? null
            : _deleteFile,
      ),
    );
  }

  Widget _buildFilesList() {
    return Column(
      children: files
          .map(
            (file) => _FileListItem(
              file: file,
              onTap: _openFile,
              onDelete: (widget.selectMode || _isSelectGraphics)
                  ? null
                  : _deleteFile,
            ),
          )
          .toList(),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required int count,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ClubDashboardPalette.superLightGreen,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: ClubDashboardPalette.border),
            ),
            child: Icon(icon, color: ClubDashboardPalette.primaryGreenDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: ClubDashboardPalette.text,
                height: 1.1,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: ClubDashboardPalette.superLightGreen,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ClubDashboardPalette.border),
            ),
            child: Text(
              "$count",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: ClubDashboardPalette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlan() async {
    await Get.to(
      () => const PlanDetailScreen(),
      arguments: {
        "planId": 0,
        "clubId": widget.clubId,
        "clubName": widget.clubName,
        "teamId": widget.teamId ?? 0,
        "teamName": "Команда",
        "folderId": parentId ?? 0,
        "folderName": parentTitle,
        "trainerName": "Тренер",
      },
    );
    _loadPlans();
  }

  Future<void> _createFolder() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FolderCreateSheet(parentTitle: parentTitle),
    );

    if (result == null) return;

    final title = result["title"]?.toString().trim() ?? "";
    final type = result["type"]?.toString() ?? "custom";

    if (title.isEmpty) {
      _showErrorSnackbar("Введите название папки");
      return;
    }

    setState(() => busy = true);
    try {
      final createdBy = await PrefUtils.getUserId() ?? 0;
      final r = await PlanFoldersApi.create(
        clubId: widget.clubId,
        parentId: parentId,
        title: title,
        type: type,
        createdBy: createdBy,
      );

      if (r["success"] == true) {
        _showSuccessSnackbar("Папка создана");
        _load();
      } else {
        _showErrorSnackbar(r["message"] ?? "Не удалось создать");
      }
    } catch (e) {
      _showErrorSnackbar("Сетевая ошибка: $e");
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ClubDashboardPalette.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.create_new_folder_outlined,
                      color: ClubDashboardPalette.primaryGreenDark,
                    ),
                  ),
                  title: const Text(
                    "Создать папку",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text("Добавить новую папку в текущий раздел"),
                  onTap: () {
                    Navigator.pop(context);
                    _createFolder();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ClubDashboardPalette.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.note_add_rounded,
                      color: ClubDashboardPalette.primaryGreenDark,
                    ),
                  ),
                  title: const Text(
                    "Создать план",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text("Добавить новый тренировочный план"),
                  onTap: () {
                    Navigator.pop(context);
                    _createPlan();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.redAccent, Colors.deepOrangeAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text(
                    "Загрузить файл",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    "PDF, DOC, DOCX, TXT, XLS, PPT и другие",
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadFile();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadFile() async {
    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.any,
    );

    if (picked == null || picked.files.isEmpty) return;

    final pickedFile = picked.files.single;
    if (pickedFile.path == null || pickedFile.path!.isEmpty) {
      _showErrorSnackbar("Не удалось получить путь к файлу");
      return;
    }

    final fileName = pickedFile.name.trim();
    final fileSize = pickedFile.size;
    final fileExt = fileName.split('.').last.toLowerCase();

    final initialTitle = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    // Показываем диалог с превью файла
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FileUploadDialog(
        fileName: fileName,
        fileSize: fileSize,
        fileExt: fileExt,
        initialTitle: initialTitle,
      ),
    );

    if (result == null) return;

    final title = result['title'] as String;
    final userId = await PrefUtils.getUserId() ?? 0;

    // Показываем прогресс в отдельном виджете
    if (!mounted) return;

    _UploadProgressWidget.show(
      context: context,
      fileName: fileName,
      onUpload: (updateProgress) async {
        try {
          final client = dio.Dio(
            dio.BaseOptions(
              connectTimeout: const Duration(minutes: 5),
              sendTimeout: const Duration(minutes: 60),
              receiveTimeout: const Duration(minutes: 60),
            ),
          );

          final formData = dio.FormData.fromMap({
            "club_id": widget.clubId.toString(),
            "team_id": (widget.teamId ?? 0).toString(),
            "folder_id": (parentId ?? 0).toString(),
            "created_by": userId.toString(),
            "title": title,
            "file": await dio.MultipartFile.fromFile(
              pickedFile.path!,
              filename: pickedFile.name,
            ),
          });

          final response = await client.post(
            "https://sportotekaapp.ru/api/upload_file.php",
            data: formData,
            onSendProgress: (sent, total) {
              final progress = total > 0 ? sent / total : 0.0;
              updateProgress(progress);
            },
          );

          final dynamic raw = response.data;
          final Map<String, dynamic> data = raw is Map<String, dynamic>
              ? raw
              : jsonDecode(raw.toString()) as Map<String, dynamic>;

          if (data["success"] == true) {
            _showSuccessSnackbar("Файл успешно загружен");
            await _loadFiles();
            await _load();
            return true;
          } else {
            _showErrorSnackbar(data["message"] ?? "Не удалось загрузить файл");
            return false;
          }
        } catch (e) {
          _showErrorSnackbar("Ошибка загрузки: $e");
          return false;
        }
      },
    );
  }

  Widget _buildFileUploadProgressCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ClubDashboardPalette.primaryGreen.withOpacity(0.05),
            ClubDashboardPalette.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ClubDashboardPalette.primaryGreen.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: ClubDashboardPalette.primaryGreen.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        ClubDashboardPalette.primaryGreen,
                        ClubDashboardPalette.primaryGreenDark,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: ClubDashboardPalette.primaryGreen.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.cloud_upload_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Загрузка файла",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        uploadFileLabel.isEmpty ? "Подготовка..." : uploadFileLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: ClubDashboardPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ClubDashboardPalette.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${fileUploadProgress.toStringAsFixed(0)}%",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: ClubDashboardPalette.primaryGreenDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: fileUploadProgress / 100,
                minHeight: 8,
                backgroundColor: ClubDashboardPalette.primaryGreen.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  ClubDashboardPalette.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: ClubDashboardPalette.textMuted.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  "Осталось примерно ${_getEstimatedTime()}",
                  style: TextStyle(
                    fontSize: 11,
                    color: ClubDashboardPalette.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openPlan(Map<String, dynamic> plan) {
    if (widget.browsePlansMode) {
      Navigator.pop(context, {
        "plan_id": _asInt(plan["id"]),
        "folder_id": parentId,
        "folder_name": parentTitle,
      });
      return;
    }

    Get.to(
      () => const PlanDetailScreen(),
      arguments: {
        "planId": _asInt(plan["id"]),
        "clubId": widget.clubId,
        "clubName": widget.clubName,
        "teamId": widget.teamId ?? _asInt(plan["team_id"]),
        "teamName": _asStr(plan["team_name"]),
        "folderId": parentId,
        "folderName": parentTitle,
        "trainerName": _asStr(plan["trainer_name"]),
      },
    );
  }

  void _openGraphic(Map<String, dynamic> graphic) {
    final int teamId = widget.teamId ?? _asInt(graphic["team_id"]);

    final String teamName = _asStr(graphic["team_name"]).trim().isNotEmpty
        ? _asStr(graphic["team_name"]).trim()
        : "Команда";

    Get.to(
      () => TrainingGraphicsScreen(
        clubId: widget.clubId,
        clubName: widget.clubName,
        teamId: teamId,
        teamName: teamName,
        graphicId: _asInt(graphic["id"]) > 0 ? _asInt(graphic["id"]) : null,
        initialFolderId: (parentId ?? 0) > 0 ? (parentId ?? 0) : null,
        initialFolderTitle: parentTitle,
        initialDocJson: graphic["doc_json"],
      ),
    );
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    final url = _asStr(file["file_url"]).trim();
    final title = _asStr(file["title"]).trim().isNotEmpty
        ? _asStr(file["title"]).trim()
        : "Файл";
    final ext = _asStr(file["file_ext"]).trim().toLowerCase();

    if (url.isEmpty) {
      _showErrorSnackbar("У файла отсутствует ссылка");
      return;
    }

    if (ext == "pdf") {
      Get.to(
        () => FilePdfViewerScreen(
          url: url,
          title: title,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showErrorSnackbar("Некорректная ссылка на файл");
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok) {
      _showErrorSnackbar("Не удалось открыть файл");
    }
  }

  Future<void> _renameFolder(Map<String, dynamic> folder) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FolderCreateSheet(
        parentTitle: parentTitle,
        initialTitle: _asStr(folder["title"]),
        initialType: _asStr(folder["type"]),
        isEdit: true,
      ),
    );

    if (result == null) return;

    final title = result["title"]?.toString().trim() ?? "";
    if (title.isEmpty) return;

    setState(() => busy = true);
    try {
      final r = await PlanFoldersApi.rename(
        clubId: widget.clubId,
        folderId: _asInt(folder["id"]),
        title: title,
      );

      if (r["success"] == true) {
        _showSuccessSnackbar("Папка переименована");
        _load();
      } else {
        _showErrorSnackbar(r["message"] ?? "Не удалось переименовать");
      }
    } catch (e) {
      _showErrorSnackbar("Сетевая ошибка: $e");
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deleteFolder(Map<String, dynamic> folder) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Удалить папку?"),
        content: Text(
          "Папка «${_asStr(folder["title"])}» будет удалена вместе со всем содержимым. Это действие нельзя отменить.",
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("Отмена"),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => busy = true);
    try {
      final r = await PlanFoldersApi.remove(
        clubId: widget.clubId,
        folderId: _asInt(folder["id"]),
      );

      if (r["success"] == true) {
        _showSuccessSnackbar("Папка удалена");
        _load();
      } else {
        _showErrorSnackbar(r["message"] ?? "Не удалось удалить");
      }
    } catch (e) {
      _showErrorSnackbar("Сетевая ошибка: $e");
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

/// ================== FILE UPLOAD DIALOG ==================
class _FileUploadDialog extends StatefulWidget {
  final String fileName;
  final int fileSize;
  final String fileExt;
  final String initialTitle;

  const _FileUploadDialog({
    required this.fileName,
    required this.fileSize,
    required this.fileExt,
    required this.initialTitle,
  });

  @override
  State<_FileUploadDialog> createState() => _FileUploadDialogState();
}

class _FileUploadDialogState extends State<_FileUploadDialog> {
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image_rounded;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file_rounded;
      case 'mp3':
      case 'wav':
        return Icons.audio_file_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.redAccent;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return ClubDashboardPalette.primaryGreen;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.purple;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileColor = _getFileColor(widget.fileExt);
    final fileIcon = _getFileIcon(widget.fileExt);
    final fileSizeFormatted = _formatFileSize(widget.fileSize);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: fileColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(fileIcon, color: fileColor, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Загрузка файла",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Информация о файле
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ClubDashboardPalette.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClubDashboardPalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.fileName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: fileColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.fileExt.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: fileColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Размер: $fileSizeFormatted",
                    style: const TextStyle(
                      fontSize: 12,
                      color: ClubDashboardPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Поле ввода названия
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Название файла",
                hintText: "Введите название файла",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ClubDashboardPalette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ClubDashboardPalette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: ClubDashboardPalette.primaryGreenDark,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: ClubDashboardPalette.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                suffixIcon: _titleController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () => _titleController.clear(),
                        icon: const Icon(Icons.clear, size: 20),
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 24),

            // Кнопки действий
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: ClubDashboardPalette.border),
                    ),
                    child: const Text("Отмена"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final title = _titleController.text.trim();
                      Navigator.pop(context, {
                        'title': title.isEmpty ? widget.fileName : title,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClubDashboardPalette.primaryGreenDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Загрузить",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ================== UPLOAD PROGRESS WIDGET ==================
class _UploadProgressWidget extends StatefulWidget {
  final String fileName;
  final Future<bool> Function(Function(double) onProgress) onUpload;

  const _UploadProgressWidget({
    required this.fileName,
    required this.onUpload,
  });

  static void show({
    required BuildContext context,
    required String fileName,
    required Future<bool> Function(Function(double) onProgress) onUpload,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UploadProgressWidget(
        fileName: fileName,
        onUpload: onUpload,
      ),
    );
  }

  @override
  State<_UploadProgressWidget> createState() => _UploadProgressWidgetState();
}

class _UploadProgressWidgetState extends State<_UploadProgressWidget>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  String _status = "Подготовка...";
  bool _isUploading = true;
  bool _isSuccess = false;
  bool _isError = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();

    _startUpload();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startUpload() async {
    final success = await widget.onUpload((progress) {
      if (mounted) {
        setState(() {
          _progress = progress;
          if (progress < 0.99) {
            _status = "Загрузка ${(progress * 100).toStringAsFixed(0)}%";
          } else {
            _status = "Завершение...";
          }
        });
      }
    });

    if (mounted) {
      setState(() {
        _isUploading = false;
        if (success) {
          _isSuccess = true;
          _status = "Загружено!";
          _progress = 1.0;
        } else {
          _isError = true;
          _status = "Ошибка загрузки";
        }
      });

      if (success) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          await _animationController.reverse();
          Navigator.pop(context);
        }
      }
    }
  }

  void _retry() {
    setState(() {
      _isUploading = true;
      _isError = false;
      _progress = 0.0;
      _status = "Подготовка...";
    });
    _startUpload();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Анимированная иконка
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? ClubDashboardPalette.primaryGreen.withOpacity(0.1)
                      : _isError
                          ? Colors.red.withOpacity(0.1)
                          : ClubDashboardPalette.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: _isSuccess
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: ClubDashboardPalette.primaryGreenDark,
                        size: 48,
                      )
                    : _isError
                        ? const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.red,
                            size: 48,
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(
                                  value: _progress,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    ClubDashboardPalette.primaryGreen,
                                  ),
                                ),
                              ),
                              Text(
                                "${(_progress * 100).toStringAsFixed(0)}%",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: ClubDashboardPalette.primaryGreenDark,
                                ),
                              ),
                            ],
                          ),
              ),

              const SizedBox(height: 20),

              // Название файла
              Text(
                widget.fileName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Статус
              Text(
                _status,
                style: TextStyle(
                  fontSize: 14,
                  color: _isError ? Colors.red : ClubDashboardPalette.textMuted,
                ),
                textAlign: TextAlign.center,
              ),

              if (_isUploading) ...[
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ClubDashboardPalette.primaryGreen,
                    ),
                  ),
                ),
              ],

              if (_isError) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Закрыть"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _retry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ClubDashboardPalette.primaryGreenDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Повторить"),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// ================== FOLDER TYPE UI ==================
class _FolderTypeUi {
  static String typeLabel(String type) {
    switch (type) {
      case "age":
        return "Возраст";
      case "category":
        return "Категория";
      default:
        return "Папка";
    }
  }

  static IconData typeIcon(String type, {String? title}) {
    final t = (title ?? "").trim().toLowerCase();
    final isU = t.startsWith("u") || t.startsWith("u-") || t.startsWith("u ");
    if (type == "age" || isU) return Icons.groups_2_rounded;
    if (type == "category") return Icons.grid_view_rounded;
    return Icons.folder_rounded;
  }
}

/// ================== ITEMS ==================
class _FolderGridItem extends StatelessWidget {
  final Map<String, dynamic> folder;
  final int itemsCount;
  final Function(Map<String, dynamic>) onTap;
  final Future<void> Function(Map<String, dynamic>)? onRename;
  final Future<void> Function(Map<String, dynamic>)? onDelete;

  const _FolderGridItem({
    required this.folder,
    required this.itemsCount,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = (folder["title"] ?? "").toString().trim();
    final type = (folder["type"] ?? "custom").toString();

    final icon = _FolderTypeUi.typeIcon(type, title: title);
    final label = _FolderTypeUi.typeLabel(type);

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;
    final fontSize = isCompact ? 11.0 : 12.5;
    final iconSize = isCompact ? 20.0 : 22.0;

    return GestureDetector(
      onTap: () => onTap(folder),
      child: Container(
        decoration: BoxDecoration(
          color: ClubDashboardPalette.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ClubDashboardPalette.border),
          boxShadow: const [ClubDashboardPalette.cardShadow],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -18,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: ClubDashboardPalette.primaryGreen.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            if (onRename != null || onDelete != null)
              Positioned(
                top: 6,
                right: 6,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 16),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  itemBuilder: (context) => [
                    if (onRename != null)
                      PopupMenuItem(
                        value: "rename",
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: ClubDashboardPalette.text,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Переименовать",
                              style: TextStyle(
                                fontSize: 13,
                                color: ClubDashboardPalette.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: "delete",
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Удалить",
                              style: TextStyle(fontSize: 13, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (value) {
                    if (value == "rename") onRename?.call(folder);
                    if (value == "delete") onDelete?.call(folder);
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isCompact ? 40 : 46,
                    height: isCompact ? 40 : 46,
                    decoration: BoxDecoration(
                      color: ClubDashboardPalette.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: ClubDashboardPalette.primaryGreenDark,
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      title.isNotEmpty ? title : "Папка",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: fontSize,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ClubDashboardPalette.primaryGreen.withOpacity(
                              0.10,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: ClubDashboardPalette.primaryGreenDark,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ClubDashboardPalette.superLightGreen,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ClubDashboardPalette.border,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "$itemsCount",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: ClubDashboardPalette.text,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 8,
                              color: ClubDashboardPalette.textMuted,
                            ),
                          ],
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
  }
}

class _FolderListItem extends StatelessWidget {
  final Map<String, dynamic> folder;
  final int itemsCount;
  final Function(Map<String, dynamic>) onTap;
  final Future<void> Function(Map<String, dynamic>)? onRename;
  final Future<void> Function(Map<String, dynamic>)? onDelete;

  const _FolderListItem({
    required this.folder,
    required this.itemsCount,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = (folder["title"] ?? "").toString().trim();
    final type = (folder["type"] ?? "custom").toString();

    final icon = _FolderTypeUi.typeIcon(type, title: title);
    final label = _FolderTypeUi.typeLabel(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubDashboardPalette.border),
        boxShadow: const [ClubDashboardPalette.cardShadow],
      ),
      child: ListTile(
        onTap: () => onTap(folder),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: ClubDashboardPalette.lightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: ClubDashboardPalette.primaryGreen),
        ),
        title: Text(
          title.isNotEmpty ? title : "Папка",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        subtitle: Text(
          "$label • $itemsCount материалов",
          style: const TextStyle(
            fontSize: 12,
            color: ClubDashboardPalette.textMuted,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (itemsCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ClubDashboardPalette.superLightGreen,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: ClubDashboardPalette.border),
                ),
                child: Text(
                  "$itemsCount",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            if (onRename != null || onDelete != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                itemBuilder: (context) => [
                  if (onRename != null)
                    const PopupMenuItem(
                      value: "rename",
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18),
                          SizedBox(width: 8),
                          Text("Переименовать"),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: "delete",
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text("Удалить", style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
                onSelected: (value) {
                  if (value == "rename") onRename?.call(folder);
                  if (value == "delete") onDelete?.call(folder);
                },
              ),
            const Icon(
              Icons.chevron_right_rounded,
              color: ClubDashboardPalette.textMuted,
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _PlanGridItem extends StatelessWidget {
  final Map<String, dynamic> plan;
  final Function(Map<String, dynamic>) onTap;
  final Future<void> Function(Map<String, dynamic>)? onDelete;

  const _PlanGridItem({
    required this.plan,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = (plan["theme"] ?? plan["cycle_title"] ?? "").toString().trim();
    final date = (plan["created_at"] ?? plan["plan_date"] ?? "").toString().trim();
    final trainer = (plan["trainer_name"] ?? "").toString().trim();
    final team = (plan["team_name"] ?? "").toString().trim();

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;
    final fontSize = isCompact ? 11.5 : 12.5;

    return GestureDetector(
      onTap: () => onTap(plan),
      child: Container(
        decoration: BoxDecoration(
          color: ClubDashboardPalette.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ClubDashboardPalette.border),
          boxShadow: const [ClubDashboardPalette.cardShadow],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: isCompact ? 40 : 46,
                    height: isCompact ? 40 : 46,
                    decoration: BoxDecoration(
                      color: ClubDashboardPalette.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: ClubDashboardPalette.primaryGreenDark,
                      size: isCompact ? 20 : 22,
                    ),
                  ),
                  const Spacer(),
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 16),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: "delete",
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Удалить", style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == "delete") onDelete?.call(plan);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title.isNotEmpty ? title : "План",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: fontSize,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (date.isNotEmpty)
                Text(
                  date.length > 10 ? date.substring(0, 10) : date,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ClubDashboardPalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (team.isNotEmpty)
                Text(
                  team,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ClubDashboardPalette.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (trainer.isNotEmpty)
                Text(
                  trainer,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ClubDashboardPalette.primaryGreenDark,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const Spacer(),
              Row(
                children: const [
                  Text(
                    "Открыть",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ClubDashboardPalette.primaryGreenDark,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: ClubDashboardPalette.primaryGreenDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanListItem extends StatelessWidget {
  final Map<String, dynamic> plan;
  final Function(Map<String, dynamic>) onTap;
  final Future<void> Function(Map<String, dynamic>)? onDelete;

  const _PlanListItem({
    required this.plan,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = (plan["theme"] ?? plan["cycle_title"] ?? "").toString().trim();
    final date = (plan["created_at"] ?? plan["plan_date"] ?? "").toString().trim();
    final trainer = (plan["trainer_name"] ?? "").toString().trim();
    final team = (plan["team_name"] ?? "").toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubDashboardPalette.border),
        boxShadow: const [ClubDashboardPalette.cardShadow],
      ),
      child: ListTile(
        onTap: () => onTap(plan),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: ClubDashboardPalette.lightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: ClubDashboardPalette.primaryGreenDark,
          ),
        ),
        title: Text(
          title.isNotEmpty ? title : "План",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        subtitle: Text(
          [
            if (date.isNotEmpty) "Создан: $date",
            if (team.isNotEmpty) "Команда: $team",
            if (trainer.isNotEmpty) "Тренер: $trainer",
          ].join("\n"),
          style: const TextStyle(
            fontSize: 12,
            color: ClubDashboardPalette.textMuted,
            height: 1.25,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: "delete",
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Удалить", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (v) {
                  if (v == "delete") onDelete?.call(plan);
                },
              ),
            const Icon(
              Icons.chevron_right_rounded,
              color: ClubDashboardPalette.textMuted,
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _GraphicGridItem extends StatelessWidget {
  final Map<String, dynamic> graphic;
  final Function(Map<String, dynamic>) onTap;
  final Future<void> Function(Map<String, dynamic>)? onDelete;

  final bool selectMode;
  final bool selected;
  final VoidCallback? onAttachTap;

  const _GraphicGridItem({
    required this.graphic,
    required this.onTap,
    this.onDelete,
    this.selectMode = false,
    this.selected = false,
    this.onAttachTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (graphic["title"] ?? "").toString().trim();
    final preview = (graphic["preview_url"] ?? "").toString().trim();
    final createdAt = (graphic["created_at"] ?? "").toString().trim();

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;
    final fontSize = isCompact ? 11.5 : 12.5;
    final previewHeight = isCompact ? 70.0 : 80.0;

    return GestureDetector(
      onTap: () => onTap(graphic),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? ClubDashboardPalette.superLightGreen
              : ClubDashboardPalette.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? ClubDashboardPalette.primaryGreen
                : ClubDashboardPalette.border,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: const [ClubDashboardPalette.cardShadow],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        height: previewHeight,
                        color: ClubDashboardPalette.lightGreen,
                        child: preview.isEmpty
                            ? Icon(
                                Icons.sports_soccer_rounded,
                                color: ClubDashboardPalette.primaryGreenDark,
                                size: isCompact ? 28 : 32,
                              )
                            : Image.network(preview, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (!selectMode && onDelete != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 16),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: "delete",
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Удалить", style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == "delete") onDelete?.call(graphic);
                      },
                    )
                  else if (selectMode)
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? ClubDashboardPalette.primaryGreen
                          : const Color(0xFF9CA3AF),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title.isNotEmpty ? title : "Схема",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: fontSize,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (createdAt.isNotEmpty)
                Text(
                  createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ClubDashboardPalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              if (selectMode)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onAttachTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected
                          ? ClubDashboardPalette.primaryGreen
                          : ClubDashboardPalette.primaryGreenDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      selected ? "Выбрано" : "Прикрепить",
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                )
              else
                Row(
                  children: const [
                    Text(
                      "Просмотр",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: ClubDashboardPalette.primaryGreenDark,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: ClubDashboardPalette.primaryGreenDark,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GraphicListItem extends StatelessWidget {
  final Map<String, dynamic> graphic;
  final Function(Map<String, dynamic>) onTap;
  final Future<void> Function(Map<String, dynamic>)? onDelete;

  final bool selectMode;
  final bool selected;
  final VoidCallback? onAttachTap;

  const _GraphicListItem({
    required this.graphic,
    required this.onTap,
    this.onDelete,
    this.selectMode = false,
    this.selected = false,
    this.onAttachTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (graphic["title"] ?? "").toString().trim();
    final preview = (graphic["preview_url"] ?? "").toString().trim();
    final createdAt = (graphic["created_at"] ?? "").toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? ClubDashboardPalette.superLightGreen
            : ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? ClubDashboardPalette.primaryGreen
              : ClubDashboardPalette.border,
          width: selected ? 1.4 : 1,
        ),
        boxShadow: const [ClubDashboardPalette.cardShadow],
      ),
      child: ListTile(
        onTap: () => onTap(graphic),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 52,
            height: 52,
            color: ClubDashboardPalette.lightGreen,
            child: preview.isEmpty
                ? const Icon(
                    Icons.sports_soccer_rounded,
                    color: ClubDashboardPalette.primaryGreenDark,
                  )
                : Image.network(preview, fit: BoxFit.cover),
          ),
        ),
        title: Text(
          title.isNotEmpty ? title : "Схема",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        subtitle: Text(
          createdAt.isNotEmpty
              ? "Создана: ${createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt}"
              : "",
          style: const TextStyle(
            fontSize: 12,
            color: ClubDashboardPalette.textMuted,
          ),
        ),
        trailing: selectMode
            ? ElevatedButton(
                onPressed: onAttachTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected
                      ? ClubDashboardPalette.primaryGreen
                      : ClubDashboardPalette.primaryGreenDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  selected ? "Выбрано" : "Прикрепить",
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: "delete",
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Удалить", style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == "delete") onDelete?.call(graphic);
                      },
                    ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ClubDashboardPalette.textMuted,
                  ),
                ],
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _FileGridItem extends StatelessWidget {
  final Map<String, dynamic> file;
  final Function(Map<String, dynamic>) onTap;
  final Future<void> Function(Map<String, dynamic>)? onDelete;

  const _FileGridItem({
    required this.file,
    required this.onTap,
    this.onDelete,
  });

  String _formatBytes(dynamic value) {
    final bytes = int.tryParse((value ?? "0").toString()) ?? 0;
    if (bytes <= 0) return "";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  IconData _iconByExt(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _colorByExt(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.redAccent;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
        return Colors.blueAccent;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return ClubDashboardPalette.primaryGreen;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (file["title"] ?? "").toString().trim();
    final createdAt = (file["created_at"] ?? "").toString().trim();
    final fileName = (file["file_name"] ?? "").toString().trim();
    final ext = (file["file_ext"] ?? "").toString().trim().toLowerCase();
    final sizeText = _formatBytes(file["file_size"]);

    final color = _colorByExt(ext);
    final icon = _iconByExt(ext);

    return GestureDetector(
      onTap: () => onTap(file),
      child: Container(
        decoration: BoxDecoration(
          color: ClubDashboardPalette.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ClubDashboardPalette.border),
          boxShadow: const [ClubDashboardPalette.cardShadow],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 16),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: "delete",
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Удалить", style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == "delete") onDelete?.call(file);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title.isNotEmpty ? title : "Файл",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              if (fileName.isNotEmpty)
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ClubDashboardPalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (ext.isNotEmpty)
                Text(
                  ext.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (sizeText.isNotEmpty)
                Text(
                  sizeText,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ClubDashboardPalette.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (createdAt.isNotEmpty)
                Text(
                  createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ClubDashboardPalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    "Открыть",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final Map<String, dynamic> file;
  final Function(Map<String, dynamic>) onTap;
  final Future<void> Function(Map<String, dynamic>)? onDelete;

  const _FileListItem({
    required this.file,
    required this.onTap,
    this.onDelete,
  });

  String _formatBytes(dynamic value) {
    final bytes = int.tryParse((value ?? "0").toString()) ?? 0;
    if (bytes <= 0) return "";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  IconData _iconByExt(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _colorByExt(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.redAccent;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
        return Colors.blueAccent;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return ClubDashboardPalette.primaryGreen;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (file["title"] ?? "").toString().trim();
    final createdAt = (file["created_at"] ?? "").toString().trim();
    final fileName = (file["file_name"] ?? "").toString().trim();
    final ext = (file["file_ext"] ?? "").toString().trim().toLowerCase();
    final sizeText = _formatBytes(file["file_size"]);

    final subtitleParts = <String>[
      if (fileName.isNotEmpty) fileName,
      if (ext.isNotEmpty) ext.toUpperCase(),
      if (sizeText.isNotEmpty) sizeText,
      if (createdAt.isNotEmpty)
        "Создан: ${createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt}",
    ];

    final color = _colorByExt(ext);
    final icon = _iconByExt(ext);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubDashboardPalette.border),
        boxShadow: const [ClubDashboardPalette.cardShadow],
      ),
      child: ListTile(
        onTap: () => onTap(file),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title.isNotEmpty ? title : "Файл",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitleParts.join("\n"),
          style: const TextStyle(
            fontSize: 12,
            color: ClubDashboardPalette.textMuted,
            height: 1.25,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: "delete",
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Удалить", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (v) {
                  if (v == "delete") onDelete?.call(file);
                },
              ),
            const Icon(
              Icons.chevron_right_rounded,
              color: ClubDashboardPalette.textMuted,
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

/// ================== SHEET / EMPTY / ERROR ==================
class _FolderCreateSheet extends StatefulWidget {
  final String parentTitle;
  final String? initialTitle;
  final String? initialType;
  final bool isEdit;

  const _FolderCreateSheet({
    required this.parentTitle,
    this.initialTitle,
    this.initialType,
    this.isEdit = false,
  });

  @override
  State<_FolderCreateSheet> createState() => __FolderCreateSheetState();
}

class __FolderCreateSheetState extends State<_FolderCreateSheet> {
  late TextEditingController titleController;
  String selectedType = "custom";

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.initialTitle ?? "");
    selectedType = widget.initialType ?? "custom";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEdit ? "Переименовать папку" : "Новая папка",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isEdit
                          ? "В папке: ${widget.parentTitle}"
                          : "Будет создана в папке: ${widget.parentTitle}",
                      style: const TextStyle(
                        color: ClubDashboardPalette.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: "Название папки",
                        hintText: "Например: U12 или Техника ведения",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    if (!widget.isEdit) ...[
                      const SizedBox(height: 20),
                      const Text(
                        "Тип папки",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _TypeChip(
                            label: "Возраст",
                            value: "age",
                            selected: selectedType == "age",
                            onSelected: () => setState(() => selectedType = "age"),
                          ),
                          const SizedBox(width: 8),
                          _TypeChip(
                            label: "Категория",
                            value: "category",
                            selected: selectedType == "category",
                            onSelected: () =>
                                setState(() => selectedType = "category"),
                          ),
                          const SizedBox(width: 8),
                          _TypeChip(
                            label: "Своя",
                            value: "custom",
                            selected: selectedType == "custom",
                            onSelected: () =>
                                setState(() => selectedType = "custom"),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ClubDashboardPalette.text,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Отмена"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (titleController.text.trim().isEmpty) return;
                              Navigator.pop(context, {
                                "title": titleController.text.trim(),
                                "type": selectedType,
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClubDashboardPalette.primaryGreenDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(widget.isEdit ? "Сохранить" : "Создать"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
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

class _TypeChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  const _TypeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? ClubDashboardPalette.primaryGreen.withOpacity(0.1)
                : ClubDashboardPalette.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? ClubDashboardPalette.primaryGreen
                  : ClubDashboardPalette.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected
                    ? ClubDashboardPalette.primaryGreen
                    : ClubDashboardPalette.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: ClubDashboardPalette.lightGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: ClubDashboardPalette.primaryGreenDark,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ClubDashboardPalette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ClubDashboardPalette.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.text,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 20),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ClubDashboardPalette.text,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Повторить"),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubDashboardPalette.primaryGreenDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}