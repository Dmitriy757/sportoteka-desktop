// lib/presentation/plans/plan_detail_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart' as cross;

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart'; // только если где-то используешь PdfPageFormat
import 'package:share_plus/share_plus.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/plans/plan_exporter.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/presentation/plans/pdf_preview_screen.dart';
import 'package:sportoteka/presentation/training_graphics/training_graphics_screen.dart';

/// ================== ПАЛИТРА (ФК ГОМЕЛЬ #00a750) ==================
class ClubDashboardPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);
  static const lightGreen = Color(0xFFE8F5E9);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF111827);
  static const textMuted = Color(0xFF667085);
  static const textLight = Color(0xFF98A2B3);
  static const background = Color(0xFFF7F9F8);
  static const border = Colors.transparent;

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// ================== КОНСТАНТЫ РЕАЛЬНОГО КЛУБА ==================
class RealClubConstants {
  static const int id = 164;
  static const String name = "ФК Гомель";
  static const String primaryColor = "#00a750";
}

/// ================== API ==================
class PlanApi {
  static const String base = "https://sportotekaapp.ru/api";

  static Future<Map<String, dynamic>> getPlan(int planId) async {
    final r = await http.post(
      Uri.parse("$base/get_training_plan_detail.php"),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: jsonEncode({"plan_id": planId, "planId": planId, "id": planId}),
    );
    return _decode(r);
  }

  static Future<Map<String, dynamic>> createPlan(Map<String, dynamic> body) async {
    // ВАЖНО: create_training_plan.php используется и для создания, и для обновления.
    // Создание и обновление отправляем в create_training_plan.php: этот endpoint принимает plan_id = 0/>0
    // как черновик без plan_id, но с маркерами create/action для PHP.
    final payload = _normalizePlanPayload(body, create: true);
    payload["action"] = "create";
    payload["mode"] = "create";
    payload["is_new"] = 1;
    payload["draft"] = 1;

    final jsonResult = await _postJson("create_training_plan.php", payload);
    if (_isOk(jsonResult)) return _markOk(jsonResult);

    final formResult = await _postForm("create_training_plan.php", payload);
    if (_isOk(formResult)) return _markOk(formResult);

    return _betterError(jsonResult, formResult);
  }

  static Future<Map<String, dynamic>> updatePlan(Map<String, dynamic> body) async {
    final payload = _normalizePlanPayload(body, create: false);

    final jsonResult = await _postJson("create_training_plan.php", payload);
    if (_isOk(jsonResult)) return _markOk(jsonResult);

    final formResult = await _postForm("create_training_plan.php", payload);
    if (_isOk(formResult)) return _markOk(formResult);

    return _betterError(jsonResult, formResult);
  }

  static bool _isOk(Map<String, dynamic> r) {
    final s = r["success"];
    final status = r["status"];
    return s == true || s == 1 || s == "1" || s == "true" || status == "success" || status == true;
  }

  static Map<String, dynamic> _markOk(Map<String, dynamic> r) {
    return {...r, "success": true};
  }

  static Map<String, dynamic> _betterError(Map<String, dynamic> a, Map<String, dynamic> b) {
    // Не маскируем полезную диагностику JSON-ответа form-ответом.
    final aDetails = (a["details"] ?? a["debug"] ?? "").toString().trim();
    if (aDetails.isNotEmpty) return a;

    final aCode = _asIntStatic(a["statusCode"]);
    final bCode = _asIntStatic(b["statusCode"]);
    if (aCode == 404 && bCode != 404) return b;
    if ((a["message"] ?? "").toString().toLowerCase().contains("html") && bCode != 404) return b;

    final bDetails = (b["details"] ?? b["debug"] ?? "").toString().trim();
    if (bDetails.isNotEmpty) return b;
    if ((b["message"] ?? "").toString().isNotEmpty) return b;
    return a;
  }

  static Future<Map<String, dynamic>> _postJson(String endpoint, Map<String, dynamic> payload) async {
    try {
      final r = await http
          .post(
            Uri.parse("$base/$endpoint"),
            headers: {"Content-Type": "application/json; charset=utf-8"},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = _decode(r);
      decoded["endpoint"] = endpoint;
      decoded["transport"] = "json";
      return decoded;
    } catch (e) {
      return {"success": false, "message": "$e", "endpoint": endpoint, "transport": "json"};
    }
  }

  static Future<Map<String, dynamic>> _postForm(String endpoint, Map<String, dynamic> payload) async {
    try {
      final fields = <String, String>{};
      payload.forEach((key, value) {
        if (value == null) return;
        if (value is Map || value is List) {
          fields[key] = jsonEncode(value);
        } else {
          fields[key] = value.toString();
        }
      });

      final r = await http
          .post(Uri.parse("$base/$endpoint"), body: fields)
          .timeout(const Duration(seconds: 15));
      final decoded = _decode(r);
      decoded["endpoint"] = endpoint;
      decoded["transport"] = "form";
      return decoded;
    } catch (e) {
      return {"success": false, "message": "$e", "endpoint": endpoint, "transport": "form"};
    }
  }

  static Map<String, dynamic> _normalizePlanPayload(Map<String, dynamic> body, {required bool create}) {
    final payload = Map<String, dynamic>.from(body);

    final planId = _asIntStatic(payload["plan_id"] ?? payload["planId"] ?? payload["id"]);
    if (!create && planId > 0) {
      payload["id"] = planId;
      payload["plan_id"] = planId;
      payload["planId"] = planId;
    } else {
      payload.remove("id");
      payload.remove("plan_id");
      payload.remove("planId");
    }

    final clubId = _asIntStatic(payload["club_id"] ?? payload["clubId"]);
    final teamId = _asIntStatic(payload["team_id"] ?? payload["teamId"]);
    final folderId = _asIntStatic(payload["folder_id"] ?? payload["folderId"]);
    final coachId = _asIntStatic(payload["coach_id"] ?? payload["trainer_id"] ?? payload["created_by"] ?? payload["user_id"]);

    payload["club_id"] = clubId;
    payload["clubId"] = clubId;
    payload["team_id"] = teamId;
    payload["teamId"] = teamId;
    payload["folder_id"] = folderId;
    payload["folderId"] = folderId;

    if (coachId > 0) {
      payload["coach_id"] = coachId;
      payload["trainer_id"] = coachId;
      payload["created_by"] = coachId;
      payload["user_id"] = coachId;
    }

    final title = _firstString(payload, ["theme", "title", "name"]);
    payload["theme"] = title.isEmpty ? "Новый план" : title;
    payload["title"] = payload["theme"];
    payload["name"] = payload["theme"];

    final date = _firstString(payload, ["plan_date", "date", "created_at"]);
    payload["plan_date"] = date.isEmpty ? _todayIsoStatic() : date;
    payload["date"] = payload["plan_date"];

    final cycle = _firstString(payload, ["cycle_title", "cycle"]);
    payload["cycle_title"] = cycle.isEmpty ? "Недельный цикл" : cycle;
    payload["cycle"] = payload["cycle_title"];

    final location = _firstString(payload, ["location", "place", "training_place"]);
    payload["location"] = location.isEmpty ? "Тренировочное поле" : location;
    payload["place"] = payload["location"];
    payload["training_place"] = payload["location"];

    final duration = _asIntStatic(payload["duration_min"] ?? payload["duration"] ?? payload["minutes"]);
    payload["duration_min"] = duration > 0 ? duration : 90;
    payload["duration"] = payload["duration_min"];
    payload["minutes"] = payload["duration_min"];

    final players = _asIntStatic(payload["players_count"] ?? payload["players"]);
    payload["players_count"] = players > 0 ? players : 0;
    payload["players"] = payload["players_count"];

    final desc = _firstString(payload, ["description", "plan_description", "comment", "notes"]);
    payload["description"] = desc;
    payload["plan_description"] = desc;
    payload["comment"] = desc;
    payload["notes"] = desc;

    final exercises = payload["exercises"];
    if (exercises is List) {
      payload["exercises"] = exercises;
      payload["items"] = exercises;
      payload["exercises_json"] = jsonEncode(exercises);
      payload["items_json"] = jsonEncode(exercises);
    } else if (exercises is String && exercises.trim().isNotEmpty) {
      payload["exercises_json"] = exercises;
      payload["items_json"] = exercises;
    } else {
      payload["exercises"] = <Map<String, dynamic>>[];
      payload["items"] = <Map<String, dynamic>>[];
      payload["exercises_json"] = "[]";
      payload["items_json"] = "[]";
    }

    final goals = payload["goals"];
    if (goals is Map || goals is List) payload["goals_json"] = jsonEncode(goals);

    final equipment = payload["equipment"];
    if (equipment is Map || equipment is List) payload["equipment_json"] = jsonEncode(equipment);

    payload["source"] = "cmr_plans_panel";
    return payload;
  }

  static String _firstString(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final text = (payload[key] ?? "").toString().trim();
      if (text.isNotEmpty && text != "null") return text;
    }
    return "";
  }

  static int _asIntStatic(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse("${v ?? 0}") ?? 0;
  }

  static String _todayIsoStatic() {
    final d = DateTime.now();
    return "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  static Map<String, dynamic> _decode(http.Response r) {
    final body = r.body.trim();

    if (body.isEmpty) {
      return {"success": false, "message": "Пустой ответ сервера", "statusCode": r.statusCode};
    }

    final lower = body.toLowerCase();
    if (body.startsWith("<") || lower.contains("<br") || lower.contains("<b>") || lower.contains("<html")) {
      return {
        "success": false,
        "message": "HTTP ${r.statusCode}: сервер вернул HTML вместо JSON",
        "raw": body.length > 1800 ? body.substring(0, 1800) : body,
        "statusCode": r.statusCode,
      };
    }

    try {
      final j = json.decode(body);
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
      return {"success": false, "message": "Bad JSON: not a map", "raw": body, "statusCode": r.statusCode};
    } catch (e) {
      return {
        "success": false,
        "message": "Bad JSON: $e",
        "raw": body.length > 1800 ? body.substring(0, 1800) : body,
        "statusCode": r.statusCode,
      };
    }
  }
}

/// ================== API (архив экспортов) ==================
class PlanExportsApi {
  static const String base = "https://sportotekaapp.ru/api";

  static Future<Map<String, dynamic>> uploadExport({
    required int clubId,
    required int teamId,
    required int planId,
    required int createdBy,
    required String format, // "pdf" | "doc"
    required Uint8List bytes,
    required String filename,
  }) async {
    final uri = Uri.parse("$base/upload_plan_export.php");
    final req = http.MultipartRequest("POST", uri);

    req.fields["club_id"] = clubId.toString();
    req.fields["team_id"] = teamId.toString();
    req.fields["plan_id"] = planId.toString();
    req.fields["created_by"] = createdBy.toString();
    req.fields["format"] = format;

    req.files.add(http.MultipartFile.fromBytes("file", bytes, filename: filename));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    try {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return {"success": false, "message": "Bad JSON", "raw": resp.body};
    }
  }

  /// ✅ ВАЖНО: list_plan_exports.php теперь требует user_id и отдаёт secure_url
  static Future<Map<String, dynamic>> listExports({
    required int planId,
    required int userId,
  }) async {
    final uri = Uri.parse("$base/list_plan_exports.php?plan_id=$planId&user_id=$userId");
    final r = await http.get(uri);
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return {"success": false, "message": "Bad JSON", "raw": r.body};
    }
  }

  static Future<Map<String, dynamic>> deleteExport({required int exportId}) async {
    final r = await http.post(
      Uri.parse("$base/delete_plan_export.php"),
      headers: {"Content-Type": "application/x-www-form-urlencoded; charset=utf-8"},
      body: {"export_id": exportId.toString()},
    );

    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return {"success": false, "message": "Bad JSON", "raw": r.body};
    }
  }
}


/// ================== API (вложения к плану: схемы, PDF, DOC, изображения) ==================
class PlanAttachmentsApi {
  static const String base = "https://sportotekaapp.ru/api";

  static Future<Map<String, dynamic>> listAttachments({
    required int planId,
    required int userId,
  }) async {
    final uri = Uri.parse("$base/list_plan_attachments.php?plan_id=$planId&user_id=$userId");
    final r = await http.get(uri);
    return _decode(r);
  }

  static Future<Map<String, dynamic>> uploadAttachment({
    required int clubId,
    required int teamId,
    required int planId,
    required int createdBy,
    required Uint8List bytes,
    required String filename,
  }) async {
    final uri = Uri.parse("$base/upload_plan_attachment.php");
    final req = http.MultipartRequest("POST", uri);

    req.fields["club_id"] = clubId.toString();
    req.fields["team_id"] = teamId.toString();
    req.fields["plan_id"] = planId.toString();
    req.fields["created_by"] = createdBy.toString();
    req.files.add(http.MultipartFile.fromBytes("file", bytes, filename: filename));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    return _decode(resp);
  }

  static Future<Map<String, dynamic>> deleteAttachment({required int attachmentId}) async {
    final r = await http.post(
      Uri.parse("$base/delete_plan_attachment.php"),
      headers: {"Content-Type": "application/x-www-form-urlencoded; charset=utf-8"},
      body: {"attachment_id": attachmentId.toString()},
    );
    return _decode(r);
  }

  static Map<String, dynamic> _decode(http.Response r) {
    final body = r.body.trim();
    if (body.isEmpty) {
      return {"success": false, "message": "Empty response", "statusCode": r.statusCode};
    }
    final lower = body.toLowerCase();
    if (body.startsWith("<") || lower.contains("<br") || lower.contains("<html")) {
      return {"success": false, "message": "Server returned HTML instead of JSON", "raw": body};
    }
    try {
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) return j;
      return {"success": false, "message": "Bad JSON: not a map", "raw": body};
    } catch (e) {
      return {"success": false, "message": "Bad JSON: $e", "raw": body};
    }
  }
}

/// ================== SCREEN ==================
class PlanDetailScreen extends StatefulWidget {
  final bool embedded;
  final Map<String, dynamic>? initialArgs;
  final VoidCallback? onOpenFullscreen;
  final VoidCallback? onClose;
  final ValueChanged<Map<String, dynamic>>? onSaved;

  const PlanDetailScreen({
    super.key,
    this.embedded = false,
    this.initialArgs,
    this.onOpenFullscreen,
    this.onClose,
    this.onSaved,
  });

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> with SingleTickerProviderStateMixin {
  // КЛУБ - ВСЕГДА ваш реальный клуб 164
  late int clubId;
  String clubName = "Клуб";

  // КОМАНДА (опционально)
  int? teamId;
  String teamName = "Команда";

  // ПЛАН
  int? planId;
  String trainerName = "Тренер";

  // ПАПКА
  int? folderId;
  String? folderName;

  // UI состояния
  bool loading = true;
  bool saving = false;
  String? error;

  // ✅ Архив экспортов (PDF/DOC)
  List<Map<String, dynamic>> exports = [];
  bool exportsLoading = false;

  // ✅ Вложения к плану: схемы, PDF, DOC, картинки. Можно выбирать файлы или перетаскивать в область.
  List<Map<String, dynamic>> attachments = [];
  bool attachmentsLoading = false;
  bool uploadingAttachments = false;
  bool hoveringDropZone = false;

  // ✅ Состояние аккордеона по датам: key(YYYY-MM-DD) -> expanded
  final Map<String, bool> _exportsExpanded = {};

  // controllers
  final cycleCtrl = TextEditingController();
  final dateCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final themeCtrl = TextEditingController();
  final playersCtrl = TextEditingController(text: "12");
  final durationCtrl = TextEditingController(text: "90");

  final goalTechCtrl = TextEditingController();
  final goalTactCtrl = TextEditingController();
  final goalFitCtrl = TextEditingController();
  final goalMentCtrl = TextEditingController();

  final equipmentCtrl = TextEditingController();

  final signedRoleCtrl = TextEditingController(text: "Тренер-преподаватель");
  final signedByCtrl = TextEditingController();

  // exercises list
  List<Map<String, dynamic>> exercises = [];

  late final AnimationController _anim;

  // Флаг: вход под клубом или тренером
  bool isClubAccount = false;
  int? userAccountId; // ID пользователя в системе

  // ================== LIFECYCLE ==================
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _initFromArgs();
  }

  @override
  void dispose() {
    _anim.dispose();
    cycleCtrl.dispose();
    dateCtrl.dispose();
    locationCtrl.dispose();
    themeCtrl.dispose();
    playersCtrl.dispose();
    durationCtrl.dispose();
    goalTechCtrl.dispose();
    goalTactCtrl.dispose();
    goalFitCtrl.dispose();
    goalMentCtrl.dispose();
    equipmentCtrl.dispose();
    signedRoleCtrl.dispose();
    signedByCtrl.dispose();
    super.dispose();
  }

  // ================== HELPERS ==================

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty || s == "null") return 0;
      return int.tryParse(s) ?? 0;
    }
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return 0;
  }

  String _asStr(dynamic v) {
    if (v == null) return "";
    final str = v.toString();
    return str == "null" ? "" : str;
  }

  List<int> _asIntList(dynamic v) {
    if (v == null) return <int>[];

    if (v is List) {
      return v.map((x) => _asInt(x)).where((x) => x > 0).toList();
    }

    // иногда сервер может прислать строку JSON: "[1,2,3]"
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty || s == "null") return <int>[];
      try {
        final decoded = json.decode(s);
        if (decoded is List) {
          return decoded.map((x) => _asInt(x)).where((x) => x > 0).toList();
        }
      } catch (_) {
        // если строка вида "1,2,3"
        return s
            .split(",")
            .map((e) => int.tryParse(e.trim()) ?? 0)
            .where((x) => x > 0)
            .toList();
      }
    }

    return <int>[];
  }

  String _todayIso() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  String _rangeWeekTitle() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: (now.weekday - 1)));
    final sunday = monday.add(const Duration(days: 6));
    String f(DateTime dt) =>
        "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
    return "${f(monday)}-${f(sunday)}";
  }

  Map<String, dynamic> _emptyExercise(int pos) {
    return {
      "pos": pos,
      "title": "",
      "duration_min": 0,
      "intensity": "",
      "repetitions": "",
      "work_time": "",
      "pause_time": "",
      "organization": "",
      "coach_focus": "",
      "schemes": <int>[],
    };
  }

  // ================== EXPORTS HELPERS (INSIDE STATE) ==================

  DateTime? _parseDate(dynamic v) {
    final s = _asStr(v).trim();
    if (s.isEmpty || s == "null") return null;

    // "YYYY-MM-DD HH:mm:ss" -> "YYYY-MM-DDTHH:mm:ss"
    try {
      if (s.contains(" ") && !s.contains("T")) {
        return DateTime.parse(s.replaceFirst(" ", "T"));
      }
      return DateTime.parse(s);
    } catch (_) {}

    // fallback: only date
    final onlyDate = s.split(" ").first;
    try {
      return DateTime.parse(onlyDate);
    } catch (_) {}

    return null;
  }

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  String _prettyDateTitle(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);

    final diff = today.difference(day).inDays;
    if (diff == 0) return "Сегодня";
    if (diff == 1) return "Вчера";

    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year}";
  }

  String _timeStr(DateTime dt) {
    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(dt.hour)}:${two(dt.minute)}";
  }

 Future<void> _loadExports() async {
    if (planId == null || planId! <= 0) return;

    if (!mounted) return;
    setState(() => exportsLoading = true);

    try {
      final userId = await PrefUtils.getUserId() ?? 0;
      if (userId <= 0) {
        debugPrint("Exports: userId missing");
        if (mounted) setState(() => exportsLoading = false);
        return;
      }

      final r = await PlanExportsApi.listExports(planId: planId!, userId: userId);

      if (r["success"] == true) {
        final listAny = r["items"] ?? r["exports"] ?? r["data"] ?? [];
        final list = (listAny is List)
            ? listAny.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];

        list.sort((a, b) {
          final da = _parseDate(a["created_at"] ?? a["date"]) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = _parseDate(b["created_at"] ?? b["date"]) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });

        final keys = <String>[];
        for (final e in list) {
          final dt = _parseDate(e["created_at"] ?? e["date"]) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final k = _dateKey(dt);
          if (!keys.contains(k)) keys.add(k);
        }

        if (_exportsExpanded.isEmpty) {
          for (int i = 0; i < keys.length; i++) {
            _exportsExpanded[keys[i]] = (i == 0);
          }
        } else {
          for (int i = 0; i < keys.length; i++) {
            _exportsExpanded.putIfAbsent(keys[i], () => (i == 0));
          }
          final toRemove = _exportsExpanded.keys.where((k) => !keys.contains(k)).toList();
          for (final k in toRemove) {
            _exportsExpanded.remove(k);
          }
        }

        if (!mounted) return;
        setState(() => exports = list);
      } else {
        debugPrint("Exports list error: ${r["message"]} ${r["raw"]}");
      }
    } catch (e) {
      debugPrint("Exports list exception: $e");
    } finally {
      if (mounted) setState(() => exportsLoading = false);
    }
  }

   Future<void> _uploadExportAndRefresh({
    required String format,
    required Uint8List bytes,
    required String filename,
  }) async {
    if (planId == null || planId! <= 0) {
      Get.snackbar(
        "Сначала сохраните план",
        "Архив экспортов доступен после сохранения плана.",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    final createdBy = await PrefUtils.getUserId() ?? 0;

    try {
      final r = await PlanExportsApi.uploadExport(
        clubId: clubId,
        teamId: (teamId ?? 0),
        planId: planId!,
        createdBy: createdBy,
        format: format,
        bytes: bytes,
        filename: filename,
      );

      if (r["success"] == true) {
        await _loadExports();
      await _loadAttachments();
        Get.snackbar(
          "Экспорт сохранён",
          "Файл добавлен в архив",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      } else {
        Get.snackbar(
          "Не удалось загрузить",
          (r["message"] ?? "Ошибка сервера").toString(),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      }
    } catch (e) {
      Get.snackbar(
        "Ошибка",
        "Не удалось загрузить в архив: $e",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  Future<void> _shareLink(String url) async {
    try {
      await Share.share(url);
    } catch (e) {
      Get.snackbar(
        "Ошибка",
        "Не удалось поделиться: $e",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  Future<void> _shareBytesAsFile(Uint8List bytes, String fileName) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/$fileName");
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path)], text: "План-конспект");
    } catch (e) {
      Get.snackbar(
        "Ошибка",
        "Не удалось сохранить/поделиться: $e",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }
  
   // 👇 ВСТАВИТЬ ВОТ СЮДА
  Future<Uint8List> _downloadBytesFromUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) throw Exception("Bad URL: $url");

    final headers = <String, String>{};

    final r = await http.get(uri, headers: headers);

    if (r.statusCode != 200) {
      final sample = r.body.length > 400 ? r.body.substring(0, 400) : r.body;
      throw Exception("HTTP ${r.statusCode}: $sample");
    }
    return r.bodyBytes;
  }


  Future<void> _openExport(Map<String, dynamic> e) async {
    final format = _asStr(e["format"]).toLowerCase().trim();
    final name = _asStr(e["file_name"] ?? e["filename"] ?? e["name"] ?? "export");
    final secureUrl = _asStr(e["secure_url"]).trim();

    if (secureUrl.isEmpty) {
      Get.snackbar("Ошибка", "secure_url не найден", snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      return;
    }

    try {
      // ✅ PDF: скачали bytes -> открываем preview
      if (format == "pdf") {
        final bytes = await _downloadBytesFromUrl(secureUrl);
        Get.to(() => PdfPreviewScreen(
              fileName: name.endsWith(".pdf") ? name : "$name.pdf",
              buildPdf: (PdfPageFormat _) async => bytes,
            ));
        return;
      }

      // ✅ DOC: скачали bytes -> share as file
      final bytes = await _downloadBytesFromUrl(secureUrl);
      await _shareBytesAsFile(bytes, name.endsWith(".doc") ? name : "$name.doc");
    } catch (err) {
      Get.snackbar(
        "Ошибка",
        "Не удалось открыть экспорт: $err",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  // ================== DOWNLOAD HELPERS ==================
  // Скачиваем bytes по secure_url (поддержка редиректов, куки, базовые проверки)
  
  Future<void> _deleteExport(Map<String, dynamic> e) async {
    final id = _asInt(e["id"] ?? e["export_id"]);
    if (id <= 0) {
      Get.snackbar("Ошибка", "export_id не найден", snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      return;
    }

    final name = _asStr(e["file_name"] ?? e["filename"] ?? e["name"] ?? "файл");

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Удалить экспорт?"),
        content: Text("Файл “$name” будет удалён из архива."),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Удалить", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final r = await PlanExportsApi.deleteExport(exportId: id);
      if (r["success"] == true) {
        await _loadExports();
        Get.snackbar("Удалено", "Экспорт удалён", snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      } else {
        Get.snackbar("Ошибка", (r["message"] ?? "Не удалось удалить").toString(),
            snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      }
    } catch (err) {
      Get.snackbar("Ошибка", "Не удалось удалить: $err", snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
    }
  }

  void _toggleGroup(String key) {
    setState(() {
      _exportsExpanded[key] = !(_exportsExpanded[key] ?? false);
    });
  }


  // ================== ATTACHMENTS HELPERS ==================

  String _attachmentName(Map<String, dynamic> e) {
    return _asStr(e["file_name"] ?? e["filename"] ?? e["name"] ?? e["original_name"] ?? "файл");
  }

  String _attachmentUrl(Map<String, dynamic> e) {
    return _asStr(e["secure_url"] ?? e["url"] ?? e["file_url"] ?? e["path"]);
  }

  Future<void> _loadAttachments() async {
    if (planId == null || planId! <= 0) return;
    if (!mounted) return;
    setState(() => attachmentsLoading = true);

    try {
      final userId = await PrefUtils.getUserId() ?? 0;
      final r = await PlanAttachmentsApi.listAttachments(planId: planId!, userId: userId);
      if (r["success"] == true) {
        final raw = r["items"] ?? r["attachments"] ?? r["data"] ?? [];
        final list = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        list.sort((a, b) => _asStr(b["created_at"]).compareTo(_asStr(a["created_at"])));
        if (mounted) setState(() => attachments = list);
      } else {
        debugPrint("Attachments list error: ${r["message"]} ${r["raw"]}");
      }
    } catch (e) {
      debugPrint("Attachments list exception: $e");
    } finally {
      if (mounted) setState(() => attachmentsLoading = false);
    }
  }

  Future<void> _pickPlanAttachments() async {
    if (uploadingAttachments) return;
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'png', 'jpg', 'jpeg', 'webp', 'svg'],
    );
    if (result == null || result.files.isEmpty) return;

    final files = <_PendingAttachment>[];
    for (final f in result.files) {
      Uint8List? bytes = f.bytes;
      if (bytes == null && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) continue;
      files.add(_PendingAttachment(filename: f.name, bytes: bytes));
    }
    await _uploadPendingAttachments(files);
  }

  Future<void> _handleDroppedAttachments(List<cross.XFile> dropped) async {
    if (dropped.isEmpty || uploadingAttachments) return;
    final files = <_PendingAttachment>[];
    for (final f in dropped) {
      try {
        final bytes = await f.readAsBytes();
        if (bytes.isEmpty) continue;
        final name = f.name.trim().isEmpty ? f.path.split(Platform.pathSeparator).last : f.name;
        files.add(_PendingAttachment(filename: name, bytes: bytes));
      } catch (e) {
        debugPrint("Drop file read error: $e");
      }
    }
    await _uploadPendingAttachments(files);
  }

  Future<void> _uploadPendingAttachments(List<_PendingAttachment> files) async {
    if (files.isEmpty) return;

    if (planId == null || planId! <= 0) {
      Get.snackbar(
        "Сначала сохраните план",
        "После сохранения появится возможность прикреплять схемы, DOC/PDF и изображения.",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    setState(() => uploadingAttachments = true);
    try {
      final createdBy = await PrefUtils.getUserId() ?? 0;
      int uploaded = 0;
      for (final f in files) {
        final r = await PlanAttachmentsApi.uploadAttachment(
          clubId: clubId,
          teamId: teamId ?? 0,
          planId: planId!,
          createdBy: createdBy,
          bytes: f.bytes,
          filename: f.filename,
        );
        if (r["success"] == true) uploaded++; else debugPrint("Attachment upload failed: ${r["message"]} ${r["raw"]}");
      }
      await _loadAttachments();
      Get.snackbar(
        uploaded > 0 ? "Файлы прикреплены" : "Не удалось прикрепить",
        uploaded > 0 ? "Добавлено файлов: $uploaded" : "Проверьте PHP endpoint upload_plan_attachment.php",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } catch (e) {
      Get.snackbar("Ошибка", "Не удалось загрузить файлы: $e", snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
    } finally {
      if (mounted) setState(() => uploadingAttachments = false);
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> e) async {
    final url = _attachmentUrl(e);
    final name = _attachmentName(e);
    if (url.isEmpty) {
      Get.snackbar("Ошибка", "Ссылка на файл не найдена", snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      return;
    }
    try {
      final bytes = await _downloadBytesFromUrl(url);
      await _shareBytesAsFile(bytes, name);
    } catch (err) {
      Get.snackbar("Ошибка", "Не удалось открыть файл: $err", snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
    }
  }

  Future<void> _deleteAttachment(Map<String, dynamic> e) async {
    final id = _asInt(e["id"] ?? e["attachment_id"]);
    if (id <= 0) {
      Get.snackbar("Ошибка", "attachment_id не найден", snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Удалить вложение?"),
        content: Text("Файл “${_attachmentName(e)}” будет удалён из плана."),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Удалить", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final r = await PlanAttachmentsApi.deleteAttachment(attachmentId: id);
    if (r["success"] == true) {
      await _loadAttachments();
      Get.snackbar("Удалено", "Вложение удалено", snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
    } else {
      Get.snackbar("Ошибка", (r["message"] ?? "Не удалось удалить").toString(), snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
    }
  }

  // ==================== DATA LOADING ====================

  Future<String> _loadCoachName(int userId) async {
    try {
      final resp = await http.post(
        Uri.parse("https://sportotekaapp.ru/api/get_user.php"),
        body: {"id": userId.toString()},
      );

      final data = json.decode(resp.body);

      if (data is Map && (data["success"] == true || data["status"] == "success")) {
        final u = (data["user"] ?? data["data"] ?? data["profile"]);
        if (u is Map) {
          final fn = (u["first_name"] ?? "").toString().trim();
          final ln = (u["last_name"] ?? "").toString().trim();
          final full = "$fn $ln".trim();
          if (full.isNotEmpty) return full;
        }
      }
    } catch (e) {
      debugPrint("Ошибка загрузки имени тренера: $e");
    }

    return "Тренер";
  }

  Future<int> _getClubIdByTeam(int teamId) async {
    try {
      final resp = await http.post(
        Uri.parse("https://sportotekaapp.ru/api/get_team.php"),
        body: {"team_id": teamId.toString()},
      );

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is Map && data["success"] == true) {
          final team = data["team"] ?? data["data"];
          if (team is Map) {
            final clubIdFromTeam = team["club_id"] ?? team["clubId"] ?? team["club"]?["id"];
            if (clubIdFromTeam != null) {
              final cid = int.tryParse(clubIdFromTeam.toString()) ?? 0;
              if (cid > 0) return cid;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Ошибка получения clubId по teamId: $e");
    }
    return 0;
  }

  Future<Map<String, dynamic>?> _loadClubData(int clubId) async {
    try {
      final resp = await http.post(
        Uri.parse("https://sportotekaapp.ru/api/get_club.php"),
        body: {"club_id": clubId.toString()},
      );

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is Map && data["success"] == true) {
          return Map<String, dynamic>.from(data["club"] ?? data["data"] ?? {});
        }
      }
    } catch (e) {
      debugPrint("Ошибка загрузки данных клуба: $e");
    }
    return null;
  }

  Future<void> _checkAccountType() async {
    try {
      final userId = await PrefUtils.getUserId();
      final userClubId = await PrefUtils.getUserClubId();
      final role = (PrefUtils.getRole() ?? "").toString().toLowerCase().trim();

      final isClubRole = role == "club" || role == "manager";

      if (isClubRole) {
        isClubAccount = true;
      } else if (userClubId != null && userClubId == RealClubConstants.id) {
        isClubAccount = true;
      } else {
        isClubAccount = false;
      }

      userAccountId = userId;
    } catch (e) {
      debugPrint("❌ Ошибка проверки типа аккаунта: $e");
      isClubAccount = false;
    }
  }

  Future<void> _initFromArgs() async {
    try {
      final raw = widget.initialArgs ?? Get.arguments;
      final args = raw is Map<String, dynamic> ? raw : <String, dynamic>{};

      await _checkAccountType();

      // ====== 1) TEAM from args (if exists) ======
      final possibleTeamId = args["teamId"] ?? args["team_id"] ?? args["team"];
      if (possibleTeamId != null && possibleTeamId.toString().trim().isNotEmpty && possibleTeamId.toString() != "null") {
        teamId = _asInt(possibleTeamId);
      }

      final possibleTeamName = args["teamName"] ?? args["team_name"] ?? args["teamName"];
      if (possibleTeamName != null &&
          possibleTeamName.toString().trim().isNotEmpty &&
          possibleTeamName.toString() != "null") {
        teamName = possibleTeamName.toString().trim();
      }

      // ====== 2) CLUB resolution ======
      if (isClubAccount) {
        clubId = RealClubConstants.id;
        clubName = RealClubConstants.name;
      } else {
        // trainer mode: try clubId by team, else from args, else from prefs, else fallback
        if (teamId != null && teamId! > 0) {
          final cid = await _getClubIdByTeam(teamId!);
          clubId = cid > 0 ? cid : RealClubConstants.id;
        } else {
          final possibleClubId = args["clubId"] ?? args["club_id"] ?? args["club"];
          if (possibleClubId != null &&
              possibleClubId.toString().trim().isNotEmpty &&
              possibleClubId.toString() != "null") {
            clubId = _asInt(possibleClubId);
          } else {
            final savedClubId = await PrefUtils.getUserClubId();
            if (savedClubId != null && savedClubId > 0) {
              clubId = savedClubId;
            } else {
              clubId = 1; // fallback
            }
          }
        }

        // clubName from args/prefs/server
        final possibleClubName = args["clubName"] ?? args["club_name"] ?? args["clubName"];
        if (possibleClubName != null &&
            possibleClubName.toString().trim().isNotEmpty &&
            possibleClubName.toString() != "null") {
          clubName = possibleClubName.toString().trim();
        } else {
          final savedClubName = await PrefUtils.getUserClubName();
          if (savedClubName.isNotEmpty) {
            clubName = savedClubName;
          } else {
            final clubData = await _loadClubData(clubId);
            if (clubData != null) {
              clubName = _asStr(clubData["name"] ?? clubData["club_name"]);
            }
          }
        }
      }

      // force real club name if id matches
      if (clubId == RealClubConstants.id) {
        clubName = RealClubConstants.name;
      }

      // persist
      await PrefUtils.setUserClubId(clubId);
      await PrefUtils.setUserClubName(clubName);

      // ====== 3) folder from args (optional) ======
      final possibleFolderId = args["folderId"] ?? args["folder_id"] ?? args["folder"];
      if (possibleFolderId != null &&
          possibleFolderId.toString().trim().isNotEmpty &&
          possibleFolderId.toString() != "null") {
        folderId = _asInt(possibleFolderId);
      }

      final possibleFolderName = args["folderName"] ?? args["folder_name"] ?? args["folderName"];
      if (possibleFolderName != null &&
          possibleFolderName.toString().trim().isNotEmpty &&
          possibleFolderName.toString() != "null") {
        folderName = possibleFolderName.toString().trim();
      }

      // ====== 4) planId from args ======
      final possiblePlanId = args["planId"] ?? args["plan_id"] ?? args["id"];
      final pid = _asInt(possiblePlanId);
      planId = pid > 0 ? pid : null;

      // ====== 5) trainer name ======
      final possibleTrainerName = args["trainerName"] ?? args["trainer_name"] ?? args["trainer"];
      if (possibleTrainerName != null &&
          possibleTrainerName.toString().trim().isNotEmpty &&
          possibleTrainerName.toString() != "null") {
        trainerName = possibleTrainerName.toString().trim();
      }

      // ====== 6) auto coach name ======
final userId = await PrefUtils.getUserId() ?? 0;
if (userId > 0) {
  final fullName = await _loadCoachName(userId);
  if (!mounted) return;

  // trainerName можно подтянуть, это не подпись
  if (trainerName.trim().isEmpty || trainerName == "Тренер") trainerName = fullName;

  // ✅ ВАЖНО: подпись ФИО НЕ заполняем автоматически — оставляем пустым
  // if (signedByCtrl.text.trim().isEmpty) signedByCtrl.text = fullName;
}
      // ====== 7) load/create plan ======
      if (planId != null && planId! > 0) {
        await _load();
      } else {
        dateCtrl.text = _asStr(args["date"] ?? args["plan_date"]).isNotEmpty
            ? _asStr(args["date"] ?? args["plan_date"])
            : _todayIso();
        cycleCtrl.text = _asStr(args["cycle_title"] ?? args["cycle"]).isNotEmpty
            ? _asStr(args["cycle_title"] ?? args["cycle"])
            : "Недельный цикл ${_rangeWeekTitle()}";
        themeCtrl.text = _asStr(args["theme"] ?? args["title"] ?? args["name"]).isNotEmpty
            ? _asStr(args["theme"] ?? args["title"] ?? args["name"])
            : "Новый план";
        locationCtrl.text = _asStr(args["location"] ?? args["place"]).isNotEmpty
            ? _asStr(args["location"] ?? args["place"])
            : "Тренировочное поле";
        playersCtrl.text = _asStr(args["players_count"] ?? args["players"]).isNotEmpty
            ? _asStr(args["players_count"] ?? args["players"])
            : playersCtrl.text;
        durationCtrl.text = _asStr(args["duration_min"] ?? args["duration"] ?? args["minutes"]).isNotEmpty
            ? _asStr(args["duration_min"] ?? args["duration"] ?? args["minutes"])
            : durationCtrl.text;
        exercises = [_emptyExercise(1)];
        for (final e in exercises) {
          e["schemes"] = _asIntList(e["schemes"]);
        }
        if (!mounted) return;
        setState(() => loading = false);
      }

      await _loadExports();
      await _loadAttachments();
    } catch (e) {
      debugPrint("❌ ОШИБКА в _initFromArgs: $e");
      if (!mounted) return;
      setState(() {
        loading = false;
        error = "Ошибка инициализации: $e";
      });
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final r = await PlanApi.getPlan(planId!);

      if (r["success"] != true) {
        if (!mounted) return;

        final raw = (r["raw"] ?? "").toString();
        setState(() {
          loading = false;
          error = (r["message"] ?? "Не удалось загрузить план").toString() + (raw.isNotEmpty ? "\n\nRAW:\n$raw" : "");
        });
        return;
      }

      final dynamic planAny = r["plan"] ?? r["data"] ?? r;
      final Map<String, dynamic> p =
          (planAny is Map) ? Map<String, dynamic>.from(planAny) : <String, dynamic>{};

      final Map<String, dynamic> goals =
          (p["goals"] is Map) ? Map<String, dynamic>.from(p["goals"]) : <String, dynamic>{};

      final exAny = r["exercises"] ?? r["items"] ?? [];
      exercises = (exAny is List)
          ? exAny.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      for (final e in exercises) {
        if (!e.containsKey("schemes")) e["schemes"] = <int>[];
        e["schemes"] = _asIntList(e["schemes"]);
      }

      // club/team/folder from server
      final serverClubId = _asInt(p["club_id"]);
      if (serverClubId > 0) clubId = serverClubId;
      if (clubId == RealClubConstants.id) clubName = RealClubConstants.name;

      final serverClubName = _asStr(p["club_name"] ?? p["club"]).trim();
      if (serverClubName.isNotEmpty) clubName = serverClubName;

      final serverTeamId = _asInt(p["team_id"]);
      if (serverTeamId > 0) teamId = serverTeamId;

      final serverTeamName = _asStr(p["team_name"] ?? p["team"]).trim();
      if (serverTeamName.isNotEmpty) teamName = serverTeamName;

      final serverFolderId = _asInt(p["folder_id"]);
      if (serverFolderId > 0) folderId = serverFolderId;

      final serverFolderName = _asStr(p["folder_name"]).trim();
      if (serverFolderName.isNotEmpty) folderName = serverFolderName;

      // main fields
      cycleCtrl.text = _asStr(p["cycle_title"]);
      dateCtrl.text = _asStr(p["date"] ?? p["plan_date"]);
      locationCtrl.text = _asStr(p["location"]);
      themeCtrl.text = _asStr(p["theme"]);
      playersCtrl.text = _asStr(p["players_count"] ?? 0);
      durationCtrl.text = _asStr(p["duration_min"] ?? 90);

      goalTechCtrl.text = _asStr(goals["technique"] ?? p["goal_tech"]);
      goalTactCtrl.text = _asStr(goals["tactics"] ?? p["goal_tact"]);
      goalFitCtrl.text = _asStr(goals["fitness"] ?? p["goal_fit"]);
      goalMentCtrl.text = _asStr(goals["mentality"] ?? p["goal_ment"]);

      final eqVal = p["equipment"];
      if (eqVal is List) {
        equipmentCtrl.text = eqVal.map((e) => e.toString()).join(", ");
      } else {
        equipmentCtrl.text = _asStr(eqVal);
      }

      signedRoleCtrl.text = _asStr(p["signed_role"] ?? signedRoleCtrl.text);
      signedByCtrl.text = _asStr(p["signed_by"] ?? signedByCtrl.text);

      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = "Ошибка загрузки: $e";
      });
    }
  }

  Future<void> _selectFolder() async {
    if (clubId <= 0) {
      Get.snackbar(
        "Недостаточно данных",
        "Для выбора папки нужен club_id",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    final result = await Get.to(
      () => PlanFoldersScreen(
        clubId: clubId,
        clubName: clubName,
        teamId: teamId ?? 0,
        selectMode: true,
        initialParentId: 0,
        initialParentTitle: "Планы-конспекты",
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        folderId = _asInt(result["id"]);
        folderName = _asStr(result["title"]);
      });
    }
  }

Future<void> _pickSchemesForExercise(int exerciseIndex) async {
  if (exerciseIndex < 0 || exerciseIndex >= exercises.length) return;

  final current = _asIntList(exercises[exerciseIndex]["schemes"]); // List<int>

  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TrainingGraphicsScreen(
        clubId: clubId,
        clubName: clubName,

        teamId: teamId ?? 0,          // ✅ важно: int, не int?
        teamName: teamName,

        selectMode: true,
        preselectedIds: current,      // ✅ List<int>
      ),
    ),
  );

  List<int> picked = <int>[];
  if (result is List) {
    picked = result.map((e) => _asInt(e)).where((x) => x > 0).toList();
  } else if (result is Map) {
    picked = _asIntList(result["selected"] ?? result["ids"] ?? result["schemes"]);
  }

  if (!mounted) return;
  setState(() {
    final copy = List<Map<String, dynamic>>.from(exercises);
    final ex = Map<String, dynamic>.from(copy[exerciseIndex]);
    ex["schemes"] = picked;
    copy[exerciseIndex] = ex;
    exercises = copy;
  });
}

  Future<void> _save() async {
    if (saving) return;

    if (cycleCtrl.text.trim().isEmpty ||
        dateCtrl.text.trim().isEmpty ||
        themeCtrl.text.trim().isEmpty ||
        locationCtrl.text.trim().isEmpty) {
      Get.snackbar(
        "Проверка",
        "Заполните: цикл, дата, тема, место проведения",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    if (clubId <= 0) {
      Get.snackbar(
        "Ошибка",
        "clubId не задан",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    try {
      // если папка не выбрана — спросим
      if (folderId == null || folderId! <= 0) {
        final confirm = await Get.dialog<bool>(
          AlertDialog(
            title: const Text("Сохранение без папки"),
            content: const Text("План будет сохранён без папки. Вы хотите выбрать папку сейчас?"),
            actions: [
              TextButton(onPressed: () => Get.back(result: false), child: const Text("Без папки")),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(backgroundColor: ClubDashboardPalette.primaryGreen),
                child: const Text("Выбрать папку", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _selectFolder();
          return;
        }
      }

      if (!mounted) return;
      setState(() => saving = true);

      final equipmentList = equipmentCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      for (int i = 0; i < exercises.length; i++) {
        exercises[i]["pos"] = i + 1;
      }

      final coachId = await PrefUtils.getUserId() ?? 0;
      final int effectivePlanId = (planId ?? 0) > 0 ? planId! : 0;

      final payload = <String, dynamic>{
        if (effectivePlanId > 0) "plan_id": effectivePlanId,
        "club_id": clubId,
        "club_name": clubName,
        "team_id": (teamId ?? 0),
        "team_name": teamName,
        if (folderId != null && folderId! > 0) "folder_id": folderId,
        if (coachId > 0) "coach_id": coachId,
        "trainer": trainerName,
        "cycle_title": cycleCtrl.text.trim(),
        "date": dateCtrl.text.trim(),
        "plan_date": dateCtrl.text.trim(),
        "location": locationCtrl.text.trim().isEmpty ? "Тренировочное поле" : locationCtrl.text.trim(),
        "place": locationCtrl.text.trim().isEmpty ? "Тренировочное поле" : locationCtrl.text.trim(),
        "players_count": int.tryParse(playersCtrl.text.trim()) ?? 0,
        "duration_min": int.tryParse(durationCtrl.text.trim()) ?? 90,
        "duration": int.tryParse(durationCtrl.text.trim()) ?? 90,
        "minutes": int.tryParse(durationCtrl.text.trim()) ?? 90,
        "theme": themeCtrl.text.trim(),
        "title": themeCtrl.text.trim(),
        "name": themeCtrl.text.trim(),
        "goals": {
          "technique": goalTechCtrl.text.trim(),
          "tactics": goalTactCtrl.text.trim(),
          "fitness": goalFitCtrl.text.trim(),
          "mentality": goalMentCtrl.text.trim(),
        },
        "equipment": equipmentList,
        "signed_role": signedRoleCtrl.text.trim(),
        "signed_by": signedByCtrl.text.trim(),
        "exercises": exercises.map((e) {
          return {
            if ((_asInt(e["id"])) > 0) "id": _asInt(e["id"]),
            "pos": _asInt(e["pos"]),
            "title": _asStr(e["title"]),
            "duration_min": _asInt(e["duration_min"]),
            "intensity": _asStr(e["intensity"]),
            "repetitions": _asStr(e["repetitions"]),
            "work_time": _asStr(e["work_time"]),
            "pause_time": _asStr(e["pause_time"]),
            "organization": _asStr(e["organization"]),
            "coach_focus": _asStr(e["coach_focus"]),
            "schemes": _asIntList(e["schemes"]),
          };
        }).toList(),
      };

      final r = (effectivePlanId == 0) ? await PlanApi.createPlan(payload) : await PlanApi.updatePlan(payload);

      final saveOk = r["success"] == true ||
          r["success"] == 1 ||
          r["success"] == "1" ||
          r["success"] == "true" ||
          r["status"] == "success" ||
          r["status"] == true;

      if (saveOk) {
        final newId = _asInt(
          r["plan_id"] ??
              r["id"] ??
              r["new_id"] ??
              r["insert_id"] ??
              (r["plan"] is Map ? r["plan"]["id"] : null) ??
              (r["data"] is Map ? r["data"]["id"] : null),
        );
        if ((planId == null || planId! <= 0) && newId > 0) planId = newId;

        Get.snackbar(
          "Готово",
          "План сохранён",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );

        final result = {"success": true, "plan_id": planId, "folder_id": folderId};

        if (widget.embedded) {
          widget.onSaved?.call(result);
          await _loadAttachments();
        } else if (mounted) {
          Navigator.pop(context, result);
        }
        return;
      }

      final endpoint = (r["endpoint"] ?? "").toString();
      final transport = (r["transport"] ?? "").toString();
      final raw = (r["raw"] ?? "").toString();
      final details = (r["details"] ?? r["debug"] ?? "").toString();
      final tech = [
        if (endpoint.isNotEmpty) endpoint,
        if (transport.isNotEmpty) transport,
      ].join(" • ");
      final rawShort = raw.isEmpty ? "" : "\n${raw.length > 260 ? raw.substring(0, 260) : raw}";
      final detailsShort = details.isEmpty ? "" : "\n${details.length > 360 ? details.substring(0, 360) : details}";
      Get.snackbar(
        "Ошибка",
        "${(r["message"] ?? "Не удалось сохранить").toString()}${tech.isNotEmpty ? " ($tech)" : ""}$detailsShort$rawShort",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } catch (e) {
      Get.snackbar(
        "Сеть",
        "Ошибка: $e",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  // ==================== UI ====================

  Widget _whiteCard({required Widget child}) {
    final clean = widget.embedded;

    return Container(
      padding: EdgeInsets.all(clean ? 10 : 14),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(clean ? 12 : 16),
        border: clean ? null : Border.all(color: ClubDashboardPalette.border),
        boxShadow: clean
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: ClubDashboardPalette.primaryGreen),
        filled: true,
        fillColor: ClubDashboardPalette.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ClubDashboardPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ClubDashboardPalette.primaryGreen.withOpacity(0.7), width: 1.6),
        ),
      ),
    );
  }

  Future<void> _handleExportPlan() async {
    if (saving) return;

    final header = {
      "cycle": cycleCtrl.text.trim(),
      "date": dateCtrl.text.trim(),
      "location": locationCtrl.text.trim(),
      "theme": themeCtrl.text.trim(),
      "goal_tech": goalTechCtrl.text.trim(),
      "goal_tact": goalTactCtrl.text.trim(),
      "goal_fit": goalFitCtrl.text.trim(),
      "goal_ment": goalMentCtrl.text.trim(),
      "equipment": equipmentCtrl.text.trim(),
    };

    final playersCount = int.tryParse(playersCtrl.text.trim()) ?? 0;
    final durationMin = int.tryParse(durationCtrl.text.trim()) ?? 90;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text("Сохранить в PDF"),
                onTap: () => Navigator.pop(context, "pdf"),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text("Сохранить в DOC (Word)"),
                onTap: () => Navigator.pop(context, "doc"),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null) return;

    final safeDate = dateCtrl.text.trim().isEmpty ? "date" : dateCtrl.text.trim();
    final fileBase = "plan_${planId ?? "new"}_$safeDate";

    if (choice == "pdf") {
      try {
        final logoData = await rootBundle.load('assets/icons/logofc.png');
        final logoBytes = logoData.buffer.asUint8List();

        final pdfBytes = await PlanExporter.buildPlanPdf(
          header: header,
          exercises: exercises,
          clubName: clubName,
          trainerName: trainerName,
          teamName: teamName,
          playersCount: playersCount,
          durationMin: durationMin,
          signedRole: signedRoleCtrl.text.trim(),
          signedBy: signedByCtrl.text.trim(),
          clubLogoBytes: logoBytes,
        );

        await _uploadExportAndRefresh(
          format: "pdf",
          bytes: pdfBytes,
          filename: "$fileBase.pdf",
        );

        Get.to(() => PdfPreviewScreen(
              fileName: "$fileBase.pdf",
              buildPdf: (format) async => pdfBytes,
            ));
      } catch (e) {
        Get.snackbar(
          "PDF ошибка",
          e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      }
      return;
    }

    if (choice == "doc") {
      final bytes = await PlanExporter.buildPlanDocHtml(
        header: header,
        exercises: exercises,
        clubName: clubName,
        trainerName: trainerName,
        teamName: teamName,
        playersCount: playersCount,
        durationMin: durationMin,
        signedRole: signedRoleCtrl.text.trim(),
        signedBy: signedByCtrl.text.trim(),
      );

      await _uploadExportAndRefresh(
        format: "doc",
        bytes: bytes,
        filename: "$fileBase.doc",
      );

      await _shareBytesAsFile(bytes, "$fileBase.doc");
    }
  }

  Widget _cmrActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool primary = false,
    bool compact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: compact ? 34 : 36,
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11),
        decoration: BoxDecoration(
          color: primary ? ClubDashboardPalette.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary ? ClubDashboardPalette.primaryGreen : ClubDashboardPalette.border,
          ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: ClubDashboardPalette.primaryGreen.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 16 : 17, color: primary ? Colors.white : ClubDashboardPalette.text),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: primary ? Colors.white : ClubDashboardPalette.text,
                fontWeight: FontWeight.w500,
                fontSize: compact ? 11.2 : 11.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cmrIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ClubDashboardPalette.border),
          ),
          child: Icon(icon, size: 17, color: ClubDashboardPalette.text),
        ),
      ),
    );
  }

  Widget _buildCmrTopBar({required bool embedded, required bool compact}) {
    final embeddedCompact = embedded;
    return Container(
      padding: EdgeInsets.fromLTRB(
        embeddedCompact ? 10 : (compact ? 12 : 16),
        embeddedCompact ? 7 : (compact ? 10 : 12),
        embeddedCompact ? 8 : (compact ? 12 : 16),
        embeddedCompact ? 7 : (compact ? 10 : 12),
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          if (!embedded) ...[
            _cmrIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Назад',
              onTap: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            width: embeddedCompact ? 32 : (compact ? 38 : 44),
            height: embeddedCompact ? 32 : (compact ? 38 : 44),
            decoration: BoxDecoration(
              color: ClubDashboardPalette.lightGreen,
              borderRadius: BorderRadius.circular(embeddedCompact ? 11 : 14),
              border: Border.all(color: ClubDashboardPalette.primaryGreen.withOpacity(0.18)),
            ),
            child: const Icon(Icons.article_outlined, color: ClubDashboardPalette.primaryGreen),
          ),
          SizedBox(width: embeddedCompact ? 9 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _DetailDotCluster(compact: true),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        planId == null ? 'Новый план-конспект' : 'План-конспект',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ClubDashboardPalette.text,
                          fontWeight: FontWeight.w600,
                          fontSize: embeddedCompact ? 13.2 : (compact ? 14.2 : 16),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: embeddedCompact ? 1 : 3),
                Text(
                  '${clubName.isEmpty ? 'Клуб' : clubName} • ${teamName.isEmpty ? 'Команда' : teamName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ClubDashboardPalette.textMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: embeddedCompact ? 10.2 : 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!compact) ...[
            if (embedded && widget.onOpenFullscreen != null) ...[
              _cmrActionButton(
                icon: Icons.open_in_full_rounded,
                label: 'На весь экран',
                onTap: widget.onOpenFullscreen,
              ),
              const SizedBox(width: 8),
            ],
            _cmrActionButton(
              icon: Icons.ios_share_rounded,
              label: 'Экспорт',
              onTap: _handleExportPlan,
            ),
            const SizedBox(width: 8),
            _cmrActionButton(
              icon: Icons.save_rounded,
              label: saving ? 'Сохраняем...' : 'Сохранить',
              onTap: saving ? null : _save,
              primary: true,
            ),
            if (embedded && widget.onClose != null) ...[
              const SizedBox(width: 6),
              _cmrIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Закрыть план',
                onTap: widget.onClose,
              ),
            ],
          ] else ...[
            if (embedded && widget.onOpenFullscreen != null)
              _cmrIconButton(
                icon: Icons.open_in_full_rounded,
                tooltip: 'На весь экран',
                onTap: widget.onOpenFullscreen,
              ),
            const SizedBox(width: 6),
            _cmrIconButton(
              icon: Icons.ios_share_rounded,
              tooltip: 'Экспорт',
              onTap: _handleExportPlan,
            ),
            const SizedBox(width: 6),
            _cmrIconButton(
              icon: Icons.save_rounded,
              tooltip: 'Сохранить',
              onTap: saving ? null : _save,
            ),
            if (embedded && widget.onClose != null) ...[
              const SizedBox(width: 6),
              _cmrIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Закрыть план',
                onTap: widget.onClose,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _cmrSection({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DetailDot(size: 6.5),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ClubDashboardPalette.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: ClubDashboardPalette.primaryGreen, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5),
                    ),
                    if ((subtitle ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ClubDashboardPalette.textMuted,
                          fontWeight: FontWeight.w500,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _cmrMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ClubDashboardPalette.primaryGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: ClubDashboardPalette.textMuted, fontSize: 10.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value.trim().isEmpty ? '—' : value.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCmrHero(bool compact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      themeCtrl.text.trim().isEmpty ? 'Тема тренировки не заполнена' : themeCtrl.text.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: ClubDashboardPalette.text,
                        fontSize: compact ? 18 : 22,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CmrMiniBadge(icon: Icons.folder_outlined, text: folderName?.trim().isNotEmpty == true ? folderName!.trim() : 'Без папки'),
                        _CmrMiniBadge(icon: Icons.person_outline_rounded, text: trainerName.trim().isEmpty ? 'Тренер' : trainerName.trim()),
                        _CmrMiniBadge(icon: Icons.fitness_center_outlined, text: '${exercises.length} упражн.'),
                        _CmrMiniBadge(icon: Icons.attach_file_rounded, text: '${attachments.length} файл.'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final twoCols = c.maxWidth < 520;
              final metrics = [
                _cmrMetric('Дата', dateCtrl.text, Icons.event_outlined),
                _cmrMetric('Цикл', cycleCtrl.text, Icons.calendar_today_outlined),
                _cmrMetric('Игроки', playersCtrl.text, Icons.groups_outlined),
                _cmrMetric('Минуты', durationCtrl.text, Icons.timer_outlined),
              ];
              if (twoCols) {
                return Column(
                  children: [
                    Row(children: [Expanded(child: metrics[0]), const SizedBox(width: 8), Expanded(child: metrics[1])]),
                    const SizedBox(height: 8),
                    Row(children: [Expanded(child: metrics[2]), const SizedBox(width: 8), Expanded(child: metrics[3])]),
                  ],
                );
              }
              return Row(
                children: [
                  for (int i = 0; i < metrics.length; i++) ...[
                    Expanded(child: metrics[i]),
                    if (i != metrics.length - 1) const SizedBox(width: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainEditorColumn() {
    return Column(
      children: [
        _cmrSection(
          title: 'Основная информация',
          icon: Icons.tune_rounded,
          subtitle: 'Дата, место, цикл и параметры занятия.',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _input(label: "Недельный цикл", controller: cycleCtrl, icon: Icons.calendar_today_outlined)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _input(
                      label: "Дата (YYYY-MM-DD)",
                      controller: dateCtrl,
                      icon: Icons.event_outlined,
                      hint: "2025-02-17",
                      keyboard: TextInputType.datetime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _input(label: "К-во игроков", controller: playersCtrl, icon: Icons.groups_outlined, keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _input(label: "Длительность (мин)", controller: durationCtrl, icon: Icons.timer_outlined, keyboard: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 10),
              _input(label: "Место проведения", controller: locationCtrl, icon: Icons.location_on_outlined),
              const SizedBox(height: 10),
              _input(label: "Тема", controller: themeCtrl, icon: Icons.track_changes_outlined),
            ],
          ),
        ),
        _cmrSection(
          title: 'Цели занятия',
          icon: Icons.flag_outlined,
          subtitle: 'Разделите задачу тренировки на технику, тактику, физику и ментальность.',
          child: Column(
            children: [
              _input(label: "Техника", controller: goalTechCtrl, icon: Icons.sports_soccer_outlined),
              const SizedBox(height: 10),
              _input(label: "Тактика", controller: goalTactCtrl, icon: Icons.extension_outlined),
              const SizedBox(height: 10),
              _input(label: "Физическая подготовка", controller: goalFitCtrl, icon: Icons.fitness_center_outlined),
              const SizedBox(height: 10),
              _input(label: "Ментальность", controller: goalMentCtrl, icon: Icons.psychology_outlined),
            ],
          ),
        ),
        _cmrSection(
          title: 'Инвентарь',
          icon: Icons.inventory_2_outlined,
          child: _input(
            label: "Например: мячи, манишки, фишки...",
            controller: equipmentCtrl,
            icon: Icons.inventory_2_outlined,
            hint: "мячи, манишки, фишки, конусы, ворота",
          ),
        ),
        _ExercisesBlock(
          exercises: exercises,
          onChanged: (list) => setState(() => exercises = list),
          onOpenSchemes: (exerciseIndex) => _pickSchemesForExercise(exerciseIndex),
        ),
        const SizedBox(height: 12),
        _cmrSection(
          title: 'Подпись',
          icon: Icons.edit_outlined,
          child: Column(
            children: [
              _input(label: "Должность", controller: signedRoleCtrl, icon: Icons.badge_outlined),
              const SizedBox(height: 10),
              _input(label: "ФИО", controller: signedByCtrl, icon: Icons.edit_outlined),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSideRail() {
    return Column(
      children: [
        _PlanAttachmentsCard(
          attachments: attachments,
          loading: attachmentsLoading,
          uploading: uploadingAttachments,
          hovering: hoveringDropZone,
          onPickFiles: _pickPlanAttachments,
          onDropped: _handleDroppedAttachments,
          onHoverChanged: (value) => setState(() => hoveringDropZone = value),
          onOpen: _openAttachment,
          onDelete: _deleteAttachment,
          fileName: _attachmentName,
        ),
        const SizedBox(height: 12),
        _ExportsArchiveCard(
          exports: exports,
          loading: exportsLoading,
          expanded: _exportsExpanded,
          onToggleGroup: _toggleGroup,
          onRefresh: _loadExports,
          onShareLink: _shareLink,
          onDelete: _deleteExport,
          onOpen: _openExport,
          parseDate: _parseDate,
          dateKey: _dateKey,
          prettyDateTitle: _prettyDateTitle,
          timeStr: _timeStr,
        ),
        const SizedBox(height: 12),
        _FolderSelectorCard(
          folderId: folderId,
          folderName: folderName,
          onTap: _selectFolder,
        ),
        const SizedBox(height: 12),
        _cmrSection(
          title: 'Контекст',
          icon: Icons.info_outline_rounded,
          subtitle: 'План сохраняется в выбранной команде и папке.',
          child: Column(
            children: [
              _cmrMetric('Клуб', clubName, Icons.business_outlined),
              const SizedBox(height: 8),
              _cmrMetric('Команда', teamName, Icons.groups_outlined),
              const SizedBox(height: 8),
              _cmrMetric('Тренер', trainerName, Icons.person_outline_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCmrEditorList({required bool embedded}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final pad = embedded ? 12.0 : 16.0;

        return RefreshIndicator(
          onRefresh: () async {
            if (planId != null) await _load();
            await _loadExports();
            await _loadAttachments();
          },
          color: ClubDashboardPalette.primaryGreen,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 28 + MediaQuery.of(context).viewInsets.bottom),
            children: [
              _buildCmrHero(compact),
              if (compact) ...[
                _buildSideRail(),
                const SizedBox(height: 12),
                _buildMainEditorColumn(),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _buildMainEditorColumn()),
                    const SizedBox(width: 12),
                    SizedBox(width: embedded ? 330 : 360, child: _buildSideRail()),
                  ],
                ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : _save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, color: Colors.white),
                  label: Text(
                    saving ? "Сохранение..." : "Сохранить план",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClubDashboardPalette.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCmrBody({required bool embedded}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        if (loading) {
          return const Center(
            child: CircularProgressIndicator(color: ClubDashboardPalette.primaryGreen),
          );
        }

        if (error != null) {
          return _ErrorView(
            text: error!,
            onRetry: () async {
              if (planId != null) await _load();
              else if (mounted) setState(() => loading = false);
            },
          );
        }

        return Column(
          children: [
            _buildCmrTopBar(embedded: embedded, compact: compact),
            if (saving)
              const LinearProgressIndicator(
                minHeight: 3,
                color: ClubDashboardPalette.primaryGreen,
                backgroundColor: ClubDashboardPalette.lightGreen,
              ),
            Expanded(child: _buildCmrEditorList(embedded: embedded)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final planTextTheme = baseTheme.textTheme.apply(
      fontFamily: AppTypography.custom(
        size: 13,
        weight: FontWeight.w400,
        color: ClubDashboardPalette.text,
      ).fontFamily,
    );

    final Widget content;
    if (widget.embedded) {
      content = Material(
        color: Colors.white,
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
          child: _buildCmrBody(embedded: true),
        ),
      );
    } else {
      content = Scaffold(
        backgroundColor: ClubDashboardPalette.background,
        body: SafeArea(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
            child: _buildCmrBody(embedded: false),
          ),
        ),
      );
    }

    return Theme(
      data: baseTheme.copyWith(textTheme: planTextTheme),
      child: DefaultTextStyle.merge(
        style: AppTypography.custom(
          size: 12.5,
          weight: FontWeight.w400,
          color: ClubDashboardPalette.text,
          height: 1.25,
        ),
        child: content,
      ),
    );
  }

}

/// ---------- UI widgets ----------

class _DetailDot extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  final bool glow;

  const _DetailDot({
    this.size = 6,
    this.color = ClubDashboardPalette.primaryGreen,
    this.opacity = 1,
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow
              ? [BoxShadow(color: color.withOpacity(.16), blurRadius: size * 2, spreadRadius: .2)]
              : null,
        ),
      ),
    );
  }
}

class _DetailDotCluster extends StatelessWidget {
  final bool compact;
  const _DetailDotCluster({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final f = compact ? .82 : 1.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DetailDot(size: 3.5 * f, opacity: .22, glow: false),
        SizedBox(width: 3 * f),
        _DetailDot(size: 4.5 * f, opacity: .42, glow: false),
        SizedBox(width: 3 * f),
        _DetailDot(size: 5.5 * f, opacity: .68, glow: false),
        SizedBox(width: 3 * f),
        _DetailDot(size: 6.5 * f),
      ],
    );
  }
}

class _CmrMiniBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CmrMiniBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ClubDashboardPalette.primaryGreen),
          const SizedBox(width: 6),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ClubDashboardPalette.text,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingAttachment {
  final String filename;
  final Uint8List bytes;

  const _PendingAttachment({required this.filename, required this.bytes});
}

class _PlanAttachmentsCard extends StatelessWidget {
  final List<Map<String, dynamic>> attachments;
  final bool loading;
  final bool uploading;
  final bool hovering;
  final VoidCallback onPickFiles;
  final ValueChanged<List<cross.XFile>> onDropped;
  final ValueChanged<bool> onHoverChanged;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final String Function(Map<String, dynamic>) fileName;

  const _PlanAttachmentsCard({
    required this.attachments,
    required this.loading,
    required this.uploading,
    required this.hovering,
    required this.onPickFiles,
    required this.onDropped,
    required this.onHoverChanged,
    required this.onOpen,
    required this.onDelete,
    required this.fileName,
  });

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (n.endsWith('.doc') || n.endsWith('.docx')) return Icons.description_outlined;
    if (n.endsWith('.xls') || n.endsWith('.xlsx')) return Icons.table_chart_outlined;
    if (n.endsWith('.ppt') || n.endsWith('.pptx')) return Icons.slideshow_outlined;
    if (n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.webp') || n.endsWith('.svg')) {
      return Icons.image_outlined;
    }
    return Icons.attach_file_rounded;
  }

  bool _isImage(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.webp') || n.endsWith('.svg');
  }

  int _countWhere(bool Function(String name) test) {
    var count = 0;
    for (final e in attachments) {
      if (test(fileName(e))) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final schemesCount = _countWhere(_isImage);
    final docsCount = _countWhere((name) {
      final n = name.toLowerCase();
      return n.endsWith('.pdf') || n.endsWith('.doc') || n.endsWith('.docx') || n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.ppt') || n.endsWith('.pptx');
    });
    final otherCount = attachments.length - schemesCount - docsCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hovering ? ClubDashboardPalette.primaryGreen : ClubDashboardPalette.border, width: hovering ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: ClubDashboardPalette.lightGreen, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.drive_folder_upload_outlined, color: ClubDashboardPalette.primaryGreen, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Файлы и схемы', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    SizedBox(height: 2),
                    Text('Перетащите схему, PDF, DOC или изображение', style: TextStyle(color: ClubDashboardPalette.textMuted, fontSize: 11.5, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (loading || uploading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ClubDashboardPalette.primaryGreen)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _AttachmentCounter(label: 'Всего', value: attachments.length, icon: Icons.attach_file_rounded),
              _AttachmentCounter(label: 'Схемы', value: schemesCount, icon: Icons.image_outlined, accent: true),
              _AttachmentCounter(label: 'Документы', value: docsCount, icon: Icons.description_outlined),
              if (otherCount > 0) _AttachmentCounter(label: 'Другие', value: otherCount, icon: Icons.more_horiz_rounded),
            ],
          ),
          const SizedBox(height: 10),
          DropTarget(
            onDragEntered: (_) => onHoverChanged(true),
            onDragExited: (_) => onHoverChanged(false),
            onDragDone: (details) {
              onHoverChanged(false);
              onDropped(details.files);
            },
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: uploading ? null : onPickFiles,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: hovering ? ClubDashboardPalette.lightGreen : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hovering ? ClubDashboardPalette.primaryGreen : ClubDashboardPalette.border,
                    width: hovering ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, color: hovering ? ClubDashboardPalette.primaryGreenDark : ClubDashboardPalette.primaryGreen, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            uploading ? 'Загрузка файлов...' : 'Перетащить или выбрать файл',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: ClubDashboardPalette.text, fontWeight: FontWeight.w500, fontSize: 12.5),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'PDF, DOC, Excel, PPT, PNG/JPG/WebP/SVG',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: ClubDashboardPalette.textMuted, fontSize: 10.8, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...attachments.map((e) {
              final name = fileName(e);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFCFD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ClubDashboardPalette.border),
                ),
                child: Row(
                  children: [
                    Icon(_iconFor(name), color: _isImage(name) ? const Color(0xFF2563EB) : ClubDashboardPalette.primaryGreen, size: 20),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.2)),
                    ),
                    IconButton(tooltip: 'Открыть', onPressed: () => onOpen(e), icon: const Icon(Icons.open_in_new_rounded, size: 18), visualDensity: VisualDensity.compact),
                    IconButton(tooltip: 'Удалить', onPressed: () => onDelete(e), icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18), visualDensity: VisualDensity.compact),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _AttachmentCounter extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final bool accent;

  const _AttachmentCounter({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: accent ? const Color(0xFFEAF3FF) : const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent ? const Color(0xFF2563EB) : ClubDashboardPalette.textMuted),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              color: accent ? const Color(0xFF1D4ED8) : ClubDashboardPalette.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  final bool isClubAccount;
  final int clubId;
  final String clubName;

  const _AccountTypeCard({
    required this.isClubAccount,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isClubAccount ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isClubAccount ? Colors.orange.shade100 : Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isClubAccount ? Icons.business : Icons.person,
                color: isClubAccount ? Colors.orange.shade700 : Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                isClubAccount ? "Аккаунт КЛУБА" : "Аккаунт ТРЕНЕРА",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: isClubAccount ? Colors.orange.shade800 : Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isClubAccount
                ? "Вы вошли под аккаунтом клуба. Все планы будут создаваться для этого клуба."
                : "Вы вошли под аккаунтом тренера. Планы будут создаваться для выбранной команды.",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "Клуб: $clubName",
            style: TextStyle(
              color: isClubAccount ? Colors.orange.shade700 : Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String clubName;
  final String teamName;
  final String trainerName;
  final bool isRealClub;
  final bool isClubAccount;

  const _HeaderCard({
    required this.clubName,
    required this.teamName,
    required this.trainerName,
    required this.isRealClub,
    required this.isClubAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: ClubDashboardPalette.greenGradient,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isClubAccount ? Icons.business : Icons.menu_book_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        clubName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                    ),
                    if (isRealClub) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "РЕАЛЬНЫЙ",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w500, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  isClubAccount ? "Клуб-аккаунт" : "Тренер: $trainerName",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RealClubInfoCard extends StatelessWidget {
  final int clubId;
  final String clubName;

  const _RealClubInfoCard({
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                "Реальный клуб",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Используется ваш реальный клуб:",
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            "$clubName",
            style: TextStyle(
              color: Colors.green.shade800,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Все планы будут автоматически сохраняться в этом клубе.",
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubFoldersInfoCard extends StatelessWidget {
  final int clubId;
  final String clubName;
  final VoidCallback onViewFolders;

  const _ClubFoldersInfoCard({
    required this.clubId,
    required this.clubName,
    required this.onViewFolders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                "Папки клуба",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Клуб: $clubName",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "Папки создаются для клуба. Убедитесь, что папки созданы для этого клуба.",
            style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewFolders,
              icon: Icon(Icons.folder_open, color: Colors.blue.shade700),
              label: Text(
                "Посмотреть папки клуба",
                style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.blue.shade400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderSelectorCard extends StatelessWidget {
  final int? folderId;
  final String? folderName;
  final VoidCallback onTap;

  const _FolderSelectorCard({
    required this.folderId,
    required this.folderName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasFolder = folderId != null && folderId! > 0;
    final displayName = hasFolder ? (folderName?.isNotEmpty == true ? folderName! : "Папка #$folderId") : "Без папки";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClubDashboardPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.folder_outlined, color: ClubDashboardPalette.primaryGreen, size: 20),
              SizedBox(width: 8),
              Text("Папка для сохранения", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: hasFolder ? ClubDashboardPalette.lightGreen : ClubDashboardPalette.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFolder ? ClubDashboardPalette.primaryGreen.withOpacity(0.3) : ClubDashboardPalette.border,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasFolder ? Icons.folder : Icons.folder_open_outlined,
                    color: hasFolder ? ClubDashboardPalette.primaryGreen : Colors.grey.shade500,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: hasFolder ? ClubDashboardPalette.text : Colors.grey.shade600,
                          ),
                        ),
                        if (hasFolder && folderId != null)
                          Text(
                            "ID: $folderId",
                            style: const TextStyle(
                              color: ClubDashboardPalette.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFolder ? "План будет сохранён в этой папке" : "Нажмите, чтобы выбрать папку для сохранения плана",
            style: const TextStyle(color: ClubDashboardPalette.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ⚠️ дальше твои _ExercisesBlock / _ExerciseCard / _ErrorView остаются как есть
// (я их не менял — ниже просто оставляю твою версию без правок)

class _ExercisesBlock extends StatelessWidget {
  final List<Map<String, dynamic>> exercises;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final void Function(int exerciseIndex) onOpenSchemes;

  const _ExercisesBlock({
    required this.exercises,
    required this.onChanged,
    required this.onOpenSchemes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClubDashboardPalette.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Упражнения", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 10),
          if (exercises.isEmpty)
            const Text("Пока нет упражнений.", style: TextStyle(color: ClubDashboardPalette.textMuted))
          else
            ...List.generate(exercises.length, (i) {
              final e = exercises[i];
              return _ExerciseCard(
                index: i,
                data: e,
                onChanged: (updated) {
                  final copy = List<Map<String, dynamic>>.from(exercises);
                  copy[i] = updated;
                  onChanged(copy);
                },
                onDelete: () {
                  final copy = List<Map<String, dynamic>>.from(exercises);
                  copy.removeAt(i);
                  for (int k = 0; k < copy.length; k++) {
                    copy[k]["pos"] = k + 1;
                  }
                  onChanged(copy);
                },
                onMoveUp: i == 0
                    ? null
                    : () {
                        final copy = List<Map<String, dynamic>>.from(exercises);
                        final tmp = copy[i - 1];
                        copy[i - 1] = copy[i];
                        copy[i] = tmp;
                        for (int k = 0; k < copy.length; k++) {
                          copy[k]["pos"] = k + 1;
                        }
                        onChanged(copy);
                      },
                onMoveDown: i == exercises.length - 1
                    ? null
                    : () {
                        final copy = List<Map<String, dynamic>>.from(exercises);
                        final tmp = copy[i + 1];
                        copy[i + 1] = copy[i];
                        copy[i] = tmp;
                        for (int k = 0; k < copy.length; k++) {
                          copy[k]["pos"] = k + 1;
                        }
                        onChanged(copy);
                      },
                onSchemes: () => onOpenSchemes(i),
              );
            }),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final copy = List<Map<String, dynamic>>.from(exercises);
                copy.add({
                  "pos": copy.length + 1,
                  "title": "",
                  "duration_min": 0,
                  "intensity": "",
                  "repetitions": "",
                  "work_time": "",
                  "pause_time": "",
                  "organization": "",
                  "coach_focus": "",
                  "schemes": <int>[],
                });
                onChanged(copy);
              },
              icon: const Icon(Icons.add),
              label: const Text("Добавить упражнение"),
              style: OutlinedButton.styleFrom(
                foregroundColor: ClubDashboardPalette.primaryGreen,
                side: BorderSide(color: ClubDashboardPalette.primaryGreen.withOpacity(0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onSchemes;

  const _ExerciseCard({
    required this.index,
    required this.data,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onSchemes,
  });

  int _asInt(dynamic v) => v is int ? v : int.tryParse((v ?? "").toString()) ?? 0;
  String _asStr(dynamic v) => (v ?? "").toString();

  int _schemesCount(dynamic v) {
    if (v == null) return 0;
    if (v is List) return v.length;
    final s = v.toString().trim();
    if (s.isEmpty || s == "null") return 0;

    if (s.startsWith("[") && s.endsWith("]")) {
      try {
        final decoded = json.decode(s);
        if (decoded is List) return decoded.length;
      } catch (_) {}
    }

    if (s.contains(",")) return s.split(",").where((e) => e.trim().isNotEmpty).length;

    return int.tryParse(s) != null ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final title = _asStr(data["title"]);
    final dur = _asInt(data["duration_min"]);
    final schemesCount = _schemesCount(data["schemes"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ClubDashboardPalette.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(fontWeight: FontWeight.w500, color: ClubDashboardPalette.primaryGreen),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.isEmpty ? "Упражнение" : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: ClubDashboardPalette.border),
                ),
                child: Text("$dur мин", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _smallField(
            label: "Название",
            value: title,
            onTap: () => _editTextSheet(
              context,
              title: "Название упражнения",
              hint: "Например: Рондо 4x2",
              initial: title,
              info: "Коротко и понятно: что делают игроки.",
              maxLines: 2,
              onDone: (v) => onChanged({...data, "title": v}),
            ),
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _smallField(
                  label: "Длительность (мин)",
                  value: dur == 0 ? "" : "$dur",
                  onTap: () => _editTextSheet(
                    context,
                    title: "Длительность (мин)",
                    hint: "Например: 12",
                    initial: dur == 0 ? "" : "$dur",
                    info: "Укажи длительность одного упражнения в минутах.",
                    keyboard: TextInputType.number,
                    maxLines: 1,
                    onDone: (v) {
                      final x = int.tryParse(v.trim()) ?? 0;
                      onChanged({...data, "duration_min": x});
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallField(
                  label: "Интенсивность",
                  value: _asStr(data["intensity"]),
                  onTap: () => _editTextSheet(
                    context,
                    title: "Интенсивность",
                    hint: "Низкая / Средняя / Высокая",
                    initial: _asStr(data["intensity"]),
                    info: "Можно писать словами или % (например 70–80%).",
                    maxLines: 1,
                    onDone: (v) => onChanged({...data, "intensity": v}),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _smallField(
                  label: "Повторы",
                  value: _asStr(data["repetitions"]),
                  onTap: () => _editTextSheet(
                    context,
                    title: "Количество повторений",
                    hint: "Например: 6",
                    initial: _asStr(data["repetitions"]),
                    info: "Если упражнение по сериям — укажи количество повторов/серий.",
                    maxLines: 1,
                    onDone: (v) => onChanged({...data, "repetitions": v}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallField(
                  label: "Время работы",
                  value: _asStr(data["work_time"]),
                  onTap: () => _editTextSheet(
                    context,
                    title: "Время работы",
                    hint: "Например: 30с",
                    initial: _asStr(data["work_time"]),
                    info: "Можно: 30с / 1мин / 2:30 и т.д.",
                    maxLines: 1,
                    onDone: (v) => onChanged({...data, "work_time": v}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallField(
                  label: "Пауза",
                  value: _asStr(data["pause_time"]),
                  onTap: () => _editTextSheet(
                    context,
                    title: "Пауза",
                    hint: "Например: 20с",
                    initial: _asStr(data["pause_time"]),
                    info: "Пауза между повторами/сериями.",
                    maxLines: 1,
                    onDone: (v) => onChanged({...data, "pause_time": v}),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          _smallField(
            label: "Организация",
            value: _asStr(data["organization"]),
            onTap: () => _editTextSheet(
              context,
              title: "Организация",
              hint: "Как расставлены игроки/зоны/правила",
              initial: _asStr(data["organization"]),
              info: "Подробно опиши расстановку, правила, ограничения касаний и т.п.",
              maxLines: 6,
              onDone: (v) => onChanged({...data, "organization": v}),
            ),
          ),

          const SizedBox(height: 8),
          _smallField(
            label: "Тренерский акцент",
            value: _asStr(data["coach_focus"]),
            onTap: () => _editTextSheet(
              context,
              title: "Тренерский акцент",
              hint: "На что обращаем внимание",
              initial: _asStr(data["coach_focus"]),
              info: "Например: качество первого касания, сканирование поля, скорость решений.",
              maxLines: 6,
              onDone: (v) => onChanged({...data, "coach_focus": v}),
            ),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSchemes,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text("Схемы ($schemesCount)"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ClubDashboardPalette.primaryGreen,
                    side: BorderSide(color: ClubDashboardPalette.primaryGreen.withOpacity(0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Вверх",
                onPressed: onMoveUp,
                icon: Icon(Icons.arrow_upward_rounded, color: onMoveUp == null ? Colors.grey.shade400 : Colors.black87),
              ),
              IconButton(
                tooltip: "Вниз",
                onPressed: onMoveDown,
                icon: Icon(Icons.arrow_downward_rounded, color: onMoveDown == null ? Colors.grey.shade400 : Colors.black87),
              ),
              IconButton(
                tooltip: "Удалить",
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final v = value.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ClubDashboardPalette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: ClubDashboardPalette.textMuted,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              v.isEmpty ? "—" : v,
              style: TextStyle(
                color: v.isEmpty ? Colors.grey.shade500 : ClubDashboardPalette.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Новый редактор: тянущаяся снизу модалка + скролл + баннер + клавиатура не перекрывает
 Future<void> _editTextSheet(
  BuildContext context, {
  required String title,
  required String initial,
  required ValueChanged<String> onDone,
  String? hint,
  String? info,
  TextInputType? keyboard,
  int maxLines = 2,
}) async {
  final c = TextEditingController(text: initial);
  final focus = FocusNode();

  final res = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (sheetCtx) {
      final media = MediaQuery.of(sheetCtx);
      final inset = media.viewInsets.bottom;
      final maxH = media.size.height * 0.92; // ✅ лист всегда “высокий”

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!focus.hasFocus) focus.requestFocus();
      });

      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: inset), // ✅ поднимаем над клавиатурой
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: "Закрыть",
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),

                  if ((info ?? "").trim().isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _InfoBanner(text: info!.trim()),
                    ),
                  ] else
                    const SizedBox(height: 6),

                  // ✅ тело со скроллом
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          TextField(
                            controller: c,
                            focusNode: focus,
                            maxLines: maxLines,
                            keyboardType: keyboard,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => Navigator.pop(sheetCtx, c.text),
                            decoration: InputDecoration(
                              hintText: hint,
                              filled: true,
                              fillColor: ClubDashboardPalette.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: ClubDashboardPalette.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: ClubDashboardPalette.primaryGreen.withOpacity(0.75),
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(sheetCtx, c.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ClubDashboardPalette.primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text(
                                "Готово",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  focus.dispose();

  if (res != null) onDone(res);
}

}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.lightGreen.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubDashboardPalette.primaryGreen.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ClubDashboardPalette.primaryGreen.withOpacity(0.25)),
            ),
            child: const Icon(Icons.info_outline, size: 18, color: ClubDashboardPalette.primaryGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: ClubDashboardPalette.text,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _ErrorView extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _ErrorView({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 44, color: ClubDashboardPalette.primaryGreen),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            if (onRetry != null)
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

/// ✅ Архив экспортов: secure_url + Open + Share link + Delete
class _ExportsArchiveCard extends StatelessWidget {
  final List<Map<String, dynamic>> exports;
  final bool loading;

  final Map<String, bool> expanded;
  final void Function(String key) onToggleGroup;

  final Future<void> Function() onRefresh;
  final Future<void> Function(String url) onShareLink;
  final void Function(Map<String, dynamic> item) onDelete;
  final Future<void> Function(Map<String, dynamic> item) onOpen;

  final DateTime? Function(dynamic v) parseDate;
  final String Function(DateTime dt) dateKey;
  final String Function(DateTime dt) prettyDateTitle;
  final String Function(DateTime dt) timeStr;

  const _ExportsArchiveCard({
    required this.exports,
    required this.loading,
    required this.expanded,
    required this.onToggleGroup,
    required this.onRefresh,
    required this.onShareLink,
    required this.onDelete,
    required this.onOpen,
    required this.parseDate,
    required this.dateKey,
    required this.prettyDateTitle,
    required this.timeStr,
  });

  String _asStr(dynamic v) => (v ?? "").toString();
  int _asInt(dynamic v) => int.tryParse((v ?? "").toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    // группируем
    final Map<String, List<Map<String, dynamic>>> groups = {};
    final Map<String, DateTime> groupDates = {};

    for (final e in exports) {
      final dt = parseDate(e["created_at"] ?? e["date"]) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final k = dateKey(dt);
      groups.putIfAbsent(k, () => []).add(e);
      groupDates[k] = dt;
    }

    final keys = groups.keys.toList()
      ..sort((a, b) {
        final da = groupDates[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = groupDates[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClubDashboardPalette.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.archive_outlined, color: ClubDashboardPalette.primaryGreen),
              const SizedBox(width: 8),
              const Expanded(
                child: Text("Архив экспортов (PDF/DOC)", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              ),
              IconButton(
                tooltip: "Обновить",
                onPressed: () async => await onRefresh(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ClubDashboardPalette.primaryGreen),
                ),
              ),
            )
          else if (exports.isEmpty)
            const Text(
              "Пока нет экспортов. Сделайте экспорт PDF/DOC — файл появится здесь.",
              style: TextStyle(color: ClubDashboardPalette.textMuted, fontWeight: FontWeight.w500),
            )
          else
            Column(
              children: [
                for (final k in keys) ...[
                  _ExportsDateChipHeader(
                    title: prettyDateTitle(groupDates[k] ?? DateTime.now()),
                    count: groups[k]!.length,
                    isExpanded: expanded[k] ?? false,
                    onTap: () => onToggleGroup(k),
                  ),
                  const SizedBox(height: 8),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: (expanded[k] ?? false) ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    firstChild: Column(
                      children: groups[k]!.map((e) {
                        final name = _asStr(e["filename"] ?? e["name"] ?? "file");
                        final format = _asStr(e["format"]).toLowerCase();
                        final dt = parseDate(e["created_at"] ?? e["date"]);
                        final time = dt == null ? "" : timeStr(dt);
                        final secureUrl = _asStr(e["secure_url"]).trim();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ClubDashboardPalette.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ClubDashboardPalette.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: ClubDashboardPalette.border),
                                ),
                                child: Icon(
                                  format == "pdf" ? Icons.picture_as_pdf : Icons.description_outlined,
                                  color: format == "pdf" ? Colors.redAccent : ClubDashboardPalette.primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      time.isEmpty ? format.toUpperCase() : "${format.toUpperCase()} • $time",
                                      style: const TextStyle(
                                        color: ClubDashboardPalette.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
  tooltip: "Открыть",
  onPressed: secureUrl.isEmpty ? null : () => onOpen(e),
  icon: const Icon(Icons.open_in_new_rounded),
),
IconButton(
  tooltip: "Поделиться ссылкой",
  onPressed: secureUrl.isEmpty ? null : () => onShareLink(secureUrl),
  icon: const Icon(Icons.ios_share_rounded),
),
                              IconButton(
                                tooltip: "Удалить",
                                onPressed: () => onDelete(e),
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    secondChild: const SizedBox(height: 0),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ExportsDateChipHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool isExpanded;
  final VoidCallback onTap;

  const _ExportsDateChipHeader({
    required this.title,
    required this.count,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // серый чип + счётчик + стрелка
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6), // серый чип
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    "$count",
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          AnimatedRotation(
            turns: isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
