// lib/presentation/club_plans/club_plans_base_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';

/// ✅ Палитра как у ClubDashboardScreen
class ClubDashboardPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const lightGreen = Color(0xFFE8F5E9);
  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);
  static const textLight = Color(0xFF999999);
  static const background = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ClubPlansBaseScreen extends StatefulWidget {
  final int clubId;
  final String clubName;
  final String? clubLogoUrl; // можно передать из панели клуба

  const ClubPlansBaseScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.clubLogoUrl,
  });

  @override
  State<ClubPlansBaseScreen> createState() => _ClubPlansBaseScreenState();
}

class _ClubPlansBaseScreenState extends State<ClubPlansBaseScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String rootUrl = "$apiBase/get_plan_root.php";
  static const String childrenUrl = "$apiBase/get_plan_children.php";
  static const String searchUrl = "$apiBase/search_plans.php";
  static const String createFolderUrl = "$apiBase/create_plan_folder.php";
  static const String uploadFileUrl = "$apiBase/upload_plan_file.php";

  bool loading = true;
  String? error;

  int? rootId;
  int? currentFolderId;

  final List<_Crumb> crumbs = [];
  final TextEditingController searchC = TextEditingController();

  List<Map<String, dynamic>> folders = [];
  List<Map<String, dynamic>> files = [];

  // поиск
  bool searching = false;
  List<Map<String, dynamic>> searchItems = [];

  bool get isEditor {
    // ✅ подстрой под свои роли: editor/manager/club_admin
    final role = (PrefUtils.getUserRoleSync() ?? "").toString().toLowerCase();
    return role == "editor" || role == "manager" || role == "club_admin" || role == "admin";
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _loadRoot();
  }

  Future<void> _loadRoot() async {
    setState(() {
      loading = true;
      error = null;
      folders = [];
      files = [];
      searchItems = [];
      searching = false;
      crumbs.clear();
    });

    try {
      final resp = await http.post(Uri.parse(rootUrl), body: {
        "club_id": widget.clubId.toString(),
      });
      final data = _decode(resp);

      if (data["success"] == true) {
        rootId = _asInt(data["root_id"]);
        currentFolderId = rootId;

        crumbs.add(_Crumb(id: rootId!, title: "Планы"));

        folders = (data["folders"] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        files = [];
        setState(() => loading = false);
      } else {
        setState(() {
          loading = false;
          error = _asStr(data["message"]).isEmpty ? "Ошибка загрузки" : _asStr(data["message"]);
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        error = "Сетевая ошибка: $e";
      });
    }
  }

  Future<void> _openFolder(int folderId, String title) async {
    setState(() {
      loading = true;
      error = null;
      searching = false;
      searchItems = [];
    });

    try {
      final resp = await http.post(Uri.parse(childrenUrl), body: {
        "club_id": widget.clubId.toString(),
        "parent_id": folderId.toString(),
      });
      final data = _decode(resp);

      if (data["success"] == true) {
        folders = (data["folders"] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        files = (data["files"] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        currentFolderId = folderId;

        // обновляем хлебные крошки
        final idx = crumbs.indexWhere((c) => c.id == folderId);
        if (idx == -1) {
          crumbs.add(_Crumb(id: folderId, title: title));
        } else {
          crumbs.removeRange(idx + 1, crumbs.length);
        }

        setState(() => loading = false);
      } else {
        setState(() {
          loading = false;
          error = _asStr(data["message"]).isEmpty ? "Ошибка загрузки" : _asStr(data["message"]);
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        error = "Сетевая ошибка: $e";
      });
    }
  }

  Future<void> _goCrumb(_Crumb c) async {
    await _openFolder(c.id, c.title);
  }

  Future<void> _doSearch() async {
    final q = searchC.text.trim();
    if (q.isEmpty) {
      setState(() {
        searching = false;
        searchItems = [];
      });
      return;
    }

    setState(() {
      searching = true;
      loading = true;
      error = null;
      searchItems = [];
    });

    try {
      final resp = await http.post(Uri.parse(searchUrl), body: {
        "club_id": widget.clubId.toString(),
        "q": q,
      });

      final data = _decode(resp);
      if (data["success"] == true) {
        searchItems = (data["items"] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        setState(() => loading = false);
      } else {
        setState(() {
          loading = false;
          error = _asStr(data["message"]).isEmpty ? "Ошибка поиска" : _asStr(data["message"]);
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        error = "Сетевая ошибка: $e";
      });
    }
  }

  Future<void> _createFolderDialog() async {
    if (!isEditor) {
      Get.snackbar("Доступ", "Только менеджер/редактор может создавать папки");
      return;
    }
    final nameC = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Создать папку",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameC,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: "Название папки (например: Ведение мяча)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final name = nameC.text.trim();
                      if (name.isEmpty) return;
                      Navigator.pop(context);
                      await _createFolder(name);
                    },
                    icon: const Icon(Icons.create_new_folder_outlined, color: Colors.white),
                    label: const Text("Создать", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClubDashboardPalette.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createFolder(String name) async {
    if (currentFolderId == null) return;

    try {
      final userId = await PrefUtils.getUserId() ?? 0;

      final resp = await http.post(Uri.parse(createFolderUrl), body: {
        "club_id": widget.clubId.toString(),
        "parent_id": currentFolderId.toString(),
        "name": name,
        "folder_type": "custom",
        "created_by": userId.toString(),
      });

      final data = _decode(resp);
      if (data["success"] == true) {
        Get.snackbar("Готово", "Папка создана");
        await _openFolder(currentFolderId!, crumbs.last.title);
      } else {
        Get.snackbar("Ошибка", _asStr(data["message"]).isEmpty ? "Не удалось создать" : _asStr(data["message"]));
      }
    } catch (e) {
      Get.snackbar("Сеть", "Ошибка: $e");
    }
  }

  Future<void> _uploadFileDialog() async {
    if (!isEditor) {
      Get.snackbar("Доступ", "Только менеджер/редактор может загружать файлы");
      return;
    }
    if (currentFolderId == null) return;

    final titleC = TextEditingController();
    final keywordsC = TextEditingController();

    // выбираем файл (jpg/docx/xlsx)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["jpg", "jpeg", "png", "docx", "xlsx"],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    final ext = path.split('.').last.toLowerCase();
    titleC.text = result.files.single.name;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Row(
                  children: [
                    _fileIcon(ext),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        result.files.single.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleC,
                  decoration: const InputDecoration(
                    labelText: "Название материала",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: keywordsC,
                  decoration: const InputDecoration(
                    labelText: "Ключевые слова (через запятую)",
                    hintText: "ведение мяча, финты, техника",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final title = titleC.text.trim();
                      if (title.isEmpty) return;
                      Navigator.pop(context);
                      await _uploadFile(path: path, title: title, keywords: keywordsC.text.trim());
                    },
                    icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                    label: const Text("Загрузить", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClubDashboardPalette.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadFile({
    required String path,
    required String title,
    required String keywords,
  }) async {
    try {
      final userId = await PrefUtils.getUserId() ?? 0;
      final uri = Uri.parse(uploadFileUrl);
      final req = http.MultipartRequest("POST", uri);

      req.fields["club_id"] = widget.clubId.toString();
      req.fields["folder_id"] = currentFolderId.toString();
      req.fields["title"] = title;
      req.fields["keywords"] = keywords;
      req.fields["description"] = "";
      req.fields["uploaded_by"] = userId.toString();

      req.files.add(await http.MultipartFile.fromPath("file", path));

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp);

      if (data["success"] == true) {
        Get.snackbar("Готово", "Файл загружен");
        await _openFolder(currentFolderId!, crumbs.last.title);
      } else {
        Get.snackbar("Ошибка", _asStr(data["message"]).isEmpty ? "Не удалось загрузить" : _asStr(data["message"]));
      }
    } catch (e) {
      Get.snackbar("Сеть", "Ошибка: $e");
    }
  }

  Future<void> _openFileUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar("Ошибка", "Не удалось открыть файл");
    }
  }

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final j = json.decode(resp.body);
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return {"success": false, "message": "bad json"};
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _asStr(dynamic v) => (v ?? "").toString();

  Widget _fileIcon(String ext) {
    IconData icon = Icons.insert_drive_file_outlined;
    Color bg = const Color(0xFFF3F4F6);
    Color fg = const Color(0xFF111827);

    if (["jpg","jpeg","png"].contains(ext)) { icon = Icons.image_outlined; bg = ClubDashboardPalette.lightGreen; fg = ClubDashboardPalette.primaryGreen; }
    if (ext == "docx") { icon = Icons.description_outlined; bg = const Color(0xFFE8F2FF); fg = const Color(0xFF0066CC); }
    if (ext == "xlsx") { icon = Icons.grid_on_outlined; bg = const Color(0xFFE8F8E8); fg = ClubDashboardPalette.primaryGreen; }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: Icon(icon, color: fg),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubDashboardPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ClubDashboardPalette.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Планы / Конспекты",
          style: TextStyle(fontWeight: FontWeight.w900, color: ClubDashboardPalette.text, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: "Обновить",
            onPressed: () async {
              if (currentFolderId == null || currentFolderId == rootId) {
                await _loadRoot();
              } else {
                await _openFolder(currentFolderId!, crumbs.last.title);
              }
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: isEditor
          ? _PlansFab(
              onCreateFolder: _createFolderDialog,
              onUpload: _uploadFileDialog,
            )
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: ClubDashboardPalette.primaryGreen))
          : error != null
              ? _ErrorView(text: error!, onRetry: _loadRoot)
              : RefreshIndicator(
                  onRefresh: () async {
                    if (currentFolderId == null || currentFolderId == rootId) {
                      await _loadRoot();
                    } else {
                      await _openFolder(currentFolderId!, crumbs.last.title);
                    }
                  },
                  color: ClubDashboardPalette.primaryGreen,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _HeaderCard(
                        clubName: widget.clubName,
                        logoUrl: widget.clubLogoUrl,
                      ),
                      const SizedBox(height: 12),

                      _SearchBar(
                        controller: searchC,
                        onSearch: _doSearch,
                        onClear: () {
                          searchC.clear();
                          setState(() {
                            searching = false;
                            searchItems = [];
                          });
                        },
                      ),
                      const SizedBox(height: 10),

                      _Breadcrumbs(
                        crumbs: crumbs,
                        onTap: _goCrumb,
                      ),
                      const SizedBox(height: 12),

                      if (searching) ...[
                        _SectionTitle(title: "Результаты поиска", right: "найдено: ${searchItems.length}"),
                        const SizedBox(height: 8),
                        if (searchItems.isEmpty)
                          const _EmptyHint(text: "Ничего не найдено. Попробуйте другое слово.")
                        else
                          ...searchItems.map((x) {
                            final title = _asStr(x["title"]);
                            final folderName = _asStr(x["folder_name"]);
                            final url = _asStr(x["file_url"]);
                            final ext = _asStr(x["file_type"]);
                            return _FileTile(
                              title: title,
                              subtitle: folderName.isEmpty ? "Материал" : "Папка: $folderName",
                              ext: ext,
                              onTap: () => _openFileUrl(url),
                            );
                          }),
                      ] else ...[
                        _SectionTitle(title: "Папки", right: "всего: ${folders.length}"),
                        const SizedBox(height: 8),
                        if (folders.isEmpty)
                          const _EmptyHint(text: "Папок пока нет. Менеджер может создать структуру.")
                        else
                          ...folders.map((f) {
                            final id = _asInt(f["id"]);
                            final name = _asStr(f["name"]);
                            final type = _asStr(f["folder_type"]);
                            return _FolderTile(
                              title: name,
                              subtitle: type == "age" ? "Возраст" : "Раздел",
                              onTap: () => _openFolder(id, name),
                            );
                          }),

                        const SizedBox(height: 14),

                        _SectionTitle(title: "Материалы", right: "всего: ${files.length}"),
                        const SizedBox(height: 8),
                        if (files.isEmpty)
                          const _EmptyHint(text: "В этой папке пока нет файлов (jpg/docx/xlsx).")
                        else
                          ...files.map((x) {
                            final title = _asStr(x["title"]);
                            final url = _asStr(x["file_url"]);
                            final ext = _asStr(x["file_type"]);
                            final kw = _asStr(x["keywords"]);
                            return _FileTile(
                              title: title,
                              subtitle: kw.isEmpty ? "Открыть" : "Ключевые: $kw",
                              ext: ext,
                              onTap: () => _openFileUrl(url),
                            );
                          }),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _Crumb {
  final int id;
  final String title;
  _Crumb({required this.id, required this.title});
}

class _HeaderCard extends StatelessWidget {
  final String clubName;
  final String? logoUrl;

  const _HeaderCard({required this.clubName, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: ClubDashboardPalette.greenGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: ClipOval(
              child: (logoUrl != null && logoUrl!.isNotEmpty)
                  ? Image.network(logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
                  : _fallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  "База планов-конспектов • схемы • микроциклы",
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => const Center(
        child: Icon(Icons.menu_book_outlined, color: Colors.white, size: 26),
      );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.search, color: ClubDashboardPalette.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                hintText: "Поиск: «ведение мяча», «техника», «микроцикл»...",
                border: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              tooltip: "Очистить",
            ),
          ElevatedButton(
            onPressed: onSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: ClubDashboardPalette.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text("Найти", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  final List<_Crumb> crumbs;
  final Future<void> Function(_Crumb) onTap;

  const _Breadcrumbs({required this.crumbs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: crumbs.map((c) {
        final isLast = c == crumbs.last;
        return InkWell(
          onTap: () => onTap(c),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isLast ? ClubDashboardPalette.lightGreen : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ClubDashboardPalette.border),
            ),
            child: Text(
              c.title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isLast ? ClubDashboardPalette.primaryGreen : ClubDashboardPalette.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? right;

  const _SectionTitle({required this.title, this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
        if (right != null)
          Text(right!, style: const TextStyle(color: ClubDashboardPalette.textMuted, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _FolderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FolderTile({required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: ClubDashboardPalette.lightGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.folder_outlined, color: ClubDashboardPalette.primaryGreen),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, style: const TextStyle(color: ClubDashboardPalette.textMuted, fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String ext;
  final VoidCallback onTap;

  const _FileTile({
    required this.title,
    required this.subtitle,
    required this.ext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.insert_drive_file_outlined;
    Color bg = const Color(0xFFF3F4F6);
    Color fg = const Color(0xFF111827);

    final e = ext.toLowerCase();
    if (["jpg","jpeg","png"].contains(e)) { icon = Icons.image_outlined; bg = ClubDashboardPalette.lightGreen; fg = ClubDashboardPalette.primaryGreen; }
    if (e == "docx") { icon = Icons.description_outlined; bg = const Color(0xFFE8F2FF); fg = const Color(0xFF0066CC); }
    if (e == "xlsx") { icon = Icons.grid_on_outlined; bg = const Color(0xFFE8F8E8); fg = ClubDashboardPalette.primaryGreen; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: fg),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ClubDashboardPalette.textMuted, fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.open_in_new_rounded),
      ),
    );
  }
}

class _PlansFab extends StatelessWidget {
  final VoidCallback onCreateFolder;
  final VoidCallback onUpload;

  const _PlansFab({required this.onCreateFolder, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: ClubDashboardPalette.primaryGreen,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.add),
      onPressed: () async {
        await showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.create_new_folder_outlined),
                    title: const Text("Создать папку", style: TextStyle(fontWeight: FontWeight.w900)),
                    onTap: () { Navigator.pop(context); onCreateFolder(); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined),
                    title: const Text("Загрузить файл (jpg/docx/xlsx)", style: TextStyle(fontWeight: FontWeight.w900)),
                    onTap: () { Navigator.pop(context); onUpload(); },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _ErrorView({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 44, color: ClubDashboardPalette.primaryGreen),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: ClubDashboardPalette.primaryGreen),
              child: const Text("Повторить", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: Text(text, style: const TextStyle(color: ClubDashboardPalette.textMuted, fontWeight: FontWeight.w700)),
    );
  }
}

/// ✅ PrefUtils helper (если у тебя нет sync роли — добавь)
extension _RoleSync on PrefUtils {
  static String? getUserRoleSync() {
    // если у тебя уже есть метод — просто используй его
    // заглушка на случай отсутствия
    return null;
  }
}
