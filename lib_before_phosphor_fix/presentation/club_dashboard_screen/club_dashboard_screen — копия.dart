import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_screen/team_dashboard_screen.dart';
import 'package:sportoteka/presentation/club_calendar_screen/club_calendar_screen.dart';
import 'package:sportoteka/presentation/club_attendance/attendance_screen.dart';
import 'package:sportoteka/presentation/club_trainers/team_trainers_screen.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/core/utils/media_utils.dart';

import 'package:sportoteka/core/subscription/subscription_access.dart';
import 'package:sportoteka/core/subscription/subscription_service.dart';
import 'package:sportoteka/core/subscription/premium_bottom_sheet.dart';

/// ================== ЗЕЛЕНАЯ ЦВЕТОВАЯ ПАЛИТРА (ФК ГОМЕЛЬ #00a750) ==================
class ClubDashboardPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);
  static const accentGreen = Color(0xFF7ED321);
  static const lightGreen = Color(0xFFE8F5E9);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);
  static const textLight = Color(0xFF999999);
  static const background = Color(0xFFF8F9FA);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const lightGreenGradient = LinearGradient(
    colors: [Color(0xFFF5FFF9), Color(0xFFE8F5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ClubDashboardScreen extends StatefulWidget {
  const ClubDashboardScreen({super.key});

  @override
  State<ClubDashboardScreen> createState() => _ClubDashboardScreenState();
}

class _ClubDashboardScreenState extends State<ClubDashboardScreen>
    with SingleTickerProviderStateMixin {
  // =============================
  // ✅ ДОМЕН И API
  // =============================
  static const String apiBase = "https://sportotekaapp.ru/api";

  static const String getClubTeamsUrl = "$apiBase/get_club_teams.php";
  static const String getClubTrainersUrl = "$apiBase/get_club_trainers.php";
  static const String getClubEventsUrl = "$apiBase/get_club_events.php";
  static const String createTeamUrl = "$apiBase/club_create_team.php";
  static const String getClubProfileUrl = "$apiBase/get_club_profile.php";
  static const String updateClubProfileUrl = "$apiBase/update_club_profile.php";
  static const String getTrainingPlansUrl = "$apiBase/get_training_plans.php";
  static const String linkEventPlanUrl = "$apiBase/link_event_plan.php";
  static const String searchTrainerByEmailUrl =
      "$apiBase/search_trainer_by_email.php";

  static const String getUserClubPrefsUrl =
      "$apiBase/get_user_club_dashboard_prefs.php";
  static const String saveUserClubPrefsUrl =
      "$apiBase/save_user_club_dashboard_prefs.php";

  int clubId = 0;
  bool loading = true;
  String? error;

  List<dynamic> teams = [];
  List<dynamic> trainers = [];
  List<dynamic> events = [];
  List<dynamic> plans = [];

  int? selectedTeamId;
  String selectedTeamName = "Выберите команду";

  SubscriptionAccess _subscription = SubscriptionAccess.free();

  // =============================
  // ✅ КАСТОМИЗАЦИЯ / ПОРЯДОК
  // =============================
  bool _editLayoutMode = false;
  Color _dashboardBgColor = ClubDashboardPalette.background;

  List<Map<String, dynamic>> _moduleItems = [];
  Map<String, dynamic> _moduleStyles = {};

  Map<int, dynamic> _teamStyles = {};
  List<dynamic> _orderedTeams = [];

  final List<Color> _presetColors = const [
    Color(0xFFFFFFFF),
    Color(0xFFF8F9FA),
    Color(0xFFE8F5E9),
    Color(0xFFDFF3FF),
    Color(0xFFFFF4E6),
    Color(0xFFF3E8FF),
    Color(0xFFFFEEF2),
    Color(0xFFEFFAF0),
    Color(0xFF1F2937),
    Color(0xFF111827),
    Color(0xFF00A750),
    Color(0xFF0066CC),
    Color(0xFF7E3AED),
    Color(0xFFFF9500),
    Color(0xFFFF6B6B),
    Color(0xFF00B8D4),
    Color(0xFF222222),
    Color(0xFF666666),
  ];

  String? _cacheBust(String? url) {
    if (url == null || url.isEmpty) return null;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return url.contains("?") ? "$url&v=$ts" : "$url?v=$ts";
  }

  // ✅ ДАННЫЕ КЛУБА ДЛЯ ШАПКИ
  String clubName = "Название клуба";
  String? clubLogoPath;
  File? clubLogoFile;
  bool isEditingClubInfo = false;
  TextEditingController clubNameController = TextEditingController();
  XFile? newLogoFile;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _moduleItems = List<Map<String, dynamic>>.from(_clubModuleBanners());

    _boot();
  }

  @override
  void dispose() {
    _animationController.dispose();
    clubNameController.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    clubId = await PrefUtils.getUserId() ?? 0;
    await _reloadAll();
  }

  Future<void> _reloadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await Future.wait([
        _loadTeams(),
        _loadTrainers(),
        _loadEvents(),
        _loadPlansSafe(),
        _loadClubProfile(),
        
      ]);

      _subscription = await SubscriptionService.getUserSubscription(
        userId: clubId,
        role: 'club',
      );

      await _loadUserPrefs();

      if (_orderedTeams.isEmpty) {
        _orderedTeams = List<dynamic>.from(teams);
      }

      if (selectedTeamId == null && _orderedTeams.isNotEmpty) {
        final t0 = _orderedTeams.first as Map<String, dynamic>;
        selectedTeamId = _asInt(t0["id"]);
        selectedTeamName = _asString(t0["name"]) ?? "Команда";
      }

      if (mounted) {
        setState(() => loading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = "Ошибка загрузки данных клуба.";
        });
      }
    }
  }

  Future<void> _loadClubProfile() async {
    try {
      final resp = await http.post(
        Uri.parse(getClubProfileUrl),
        body: {"club_id": clubId.toString()},
      );

      final data = _decode(resp);

      if (mounted) {
        setState(() {
          if (data["success"] == true && data["club"] is Map) {
            final clubData = data["club"] as Map<String, dynamic>;

            clubName =
                _asString(clubData["club_name"])?.trim() ?? "Название клуба";
            final normalized =
                MediaUtils.normalizeUrl(_asString(clubData["photo"]));
            clubLogoPath = _cacheBust(normalized);
            clubLogoFile = null;

            clubNameController.text = clubName;
          } else {
            clubName = "Название клуба";
            clubNameController.text = clubName;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          clubName = "Название клуба";
          clubNameController.text = clubName;
        });
      }
    }
  }

  Future<void> _updateClubProfile() async {
    if (clubNameController.text.trim().isEmpty) {
      Get.snackbar("Ошибка", "Введите название клуба");
      return;
    }

    Get.snackbar("Обновление", "Сохраняем изменения...");

    try {
      final uri = Uri.parse(updateClubProfileUrl);
      final req = http.MultipartRequest("POST", uri);

      req.fields["club_id"] = clubId.toString();
      req.fields["club_name"] = clubNameController.text.trim();

      final picked = newLogoFile;

      if (picked != null) {
        req.files.add(await http.MultipartFile.fromPath("club_logo", picked.path));
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp);

      if (data["success"] == true) {
        Get.snackbar("Готово", "Данные клуба обновлены");

        if (!mounted) return;
        setState(() {
          clubName = clubNameController.text.trim();

          final clubMap = (data["club"] is Map)
              ? Map<String, dynamic>.from(data["club"])
              : null;
          final newPhoto = clubMap?["photo"]?.toString();
          final normalized = MediaUtils.normalizeUrl(newPhoto);
          if (normalized != null && normalized.isNotEmpty) {
            clubLogoPath = normalized;
          }

          if (picked != null) {
            clubLogoFile = File(picked.path);
          }

          isEditingClubInfo = false;
          newLogoFile = null;
        });
      } else {
        Get.snackbar(
          "Ошибка",
          _asString(data["message"]) ?? "Не удалось обновить профиль",
        );
      }
    } catch (e) {
      Get.snackbar("Сеть", "Ошибка соединения: $e");
    }
  }

  Future<void> _loadTeams() async {
    final resp = await http.post(
      Uri.parse(getClubTeamsUrl),
      body: {"club_id": clubId.toString()},
    );
    final data = _decode(resp);
    if (data["success"] == true) {
      teams = (data["teams"] as List?) ?? [];
    } else {
      teams = [];
    }
  }

  Future<void> _loadTrainers() async {
    final resp = await http.post(
      Uri.parse(getClubTrainersUrl),
      body: {"club_id": clubId.toString()},
    );
    final data = _decode(resp);
    if (data["success"] == true) {
      trainers = (data["trainers"] as List?) ?? [];
    } else {
      trainers = [];
    }
  }

  Future<void> _loadEvents() async {
    final resp = await http.post(
      Uri.parse(getClubEventsUrl),
      body: {"club_id": clubId.toString()},
    );
    final data = _decode(resp);
    if (data["success"] == true) {
      events = (data["events"] as List?) ?? [];
    } else {
      events = [];
    }
  }

  Future<void> _loadPlansSafe() async {
    try {
      final resp = await http.post(
        Uri.parse(getTrainingPlansUrl),
        body: {"club_id": clubId.toString()},
      );
      final data = _decode(resp);
      if (data["success"] == true) {
        plans = (data["plans"] as List?) ?? [];
      } else {
        plans = [];
      }
    } catch (_) {
      plans = [];
    }
  }

  Future<void> _loadUserPrefs() async {
    try {
      final resp = await http.post(
        Uri.parse(getUserClubPrefsUrl),
        body: {
          "user_id": clubId.toString(),
          "club_id": clubId.toString(),
        },
      );

      final data = _decode(resp);

      if (data["success"] == true && data["prefs"] != null) {
        final prefs = Map<String, dynamic>.from(data["prefs"]);

        final bgColorHex = _asString(prefs["bg_color"]);
        if (bgColorHex != null && bgColorHex.isNotEmpty) {
          _dashboardBgColor = _colorFromHex(bgColorHex);
        } else {
          _dashboardBgColor = ClubDashboardPalette.background;
        }

        final currentModules = List<Map<String, dynamic>>.from(_clubModuleBanners());

        final moduleOrderRaw = _asString(prefs["module_order"]);
        if (moduleOrderRaw != null && moduleOrderRaw.isNotEmpty) {
          final ids = List<String>.from(json.decode(moduleOrderRaw));
          _moduleItems = [];

          for (final id in ids) {
            for (final item in currentModules) {
              if (item["type"].toString() == id) {
                _moduleItems.add(item);
                break;
              }
            }
          }

          for (final item in currentModules) {
            final exists = _moduleItems.any((e) => e["type"] == item["type"]);
            if (!exists) _moduleItems.add(item);
          }
        } else {
          _moduleItems = currentModules;
        }

        final moduleStylesRaw = _asString(prefs["module_styles"]);
        if (moduleStylesRaw != null && moduleStylesRaw.isNotEmpty) {
          _moduleStyles = Map<String, dynamic>.from(json.decode(moduleStylesRaw));
        } else {
          _moduleStyles = {};
        }

        final teamOrderRaw = _asString(prefs["team_order"]);
        if (teamOrderRaw != null && teamOrderRaw.isNotEmpty) {
          final ids = List<int>.from(json.decode(teamOrderRaw));
          _orderedTeams = _sortByIdList(teams, ids);
        } else {
          _orderedTeams = List<dynamic>.from(teams);
        }

        final teamStylesRaw = _asString(prefs["team_styles"]);
        if (teamStylesRaw != null && teamStylesRaw.isNotEmpty) {
          final raw = Map<String, dynamic>.from(json.decode(teamStylesRaw));
          _teamStyles = raw.map((k, v) => MapEntry(int.tryParse(k) ?? 0, v));
        } else {
          _teamStyles = {};
        }
      } else {
        _orderedTeams = List<dynamic>.from(teams);
        _moduleItems = List<Map<String, dynamic>>.from(_clubModuleBanners());
        _moduleStyles = {};
        _teamStyles = {};
        _dashboardBgColor = ClubDashboardPalette.background;
      }
    } catch (_) {
      _orderedTeams = List<dynamic>.from(teams);
      _moduleItems = List<Map<String, dynamic>>.from(_clubModuleBanners());
      _moduleStyles = {};
      _teamStyles = {};
      _dashboardBgColor = ClubDashboardPalette.background;
    }
  }

  Future<void> _saveUserPrefs() async {
    try {
      final moduleOrder =
          _moduleItems.map((e) => e["type"].toString()).toList();

      final teamOrder = _orderedTeams
          .map((e) => _asInt((e as Map<String, dynamic>)["id"]))
          .toList();

      await http.post(
        Uri.parse(saveUserClubPrefsUrl),
        body: {
          "user_id": clubId.toString(),
          "club_id": clubId.toString(),
          "bg_color": _colorToHex(_dashboardBgColor),
          "module_order": json.encode(moduleOrder),
          "module_styles": json.encode(_moduleStyles),
          "team_order": json.encode(teamOrder),
          "team_styles": json.encode(
            _teamStyles.map((k, v) => MapEntry(k.toString(), v)),
          ),
          "folder_order": json.encode([]),
          "folder_styles": json.encode({}),
        },
      );
    } catch (_) {}
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();

    if (body.startsWith("<!DOCTYPE") ||
        body.startsWith("<html") ||
        body.startsWith("<")) {
      return {
        "success": false,
        "message": "Server returned HTML вместо JSON",
        "_status": resp.statusCode,
        "_raw_head": body.substring(0, body.length > 400 ? 400 : body.length),
      };
    }

    try {
      final j = json.decode(body);
      if (j is Map<String, dynamic>) return j;
      return {
        "success": false,
        "message": "Invalid JSON structure",
        "_status": resp.statusCode,
        "_raw_head": body.substring(0, body.length > 400 ? 400 : body.length),
      };
    } catch (e) {
      return {
        "success": false,
        "message": "JSON parse error: $e",
        "_status": resp.statusCode,
        "_raw_head": body.substring(0, body.length > 400 ? 400 : body.length),
      };
    }
  }

  Future<List<Map<String, dynamic>>> _searchTrainerByEmail(
    String email, {
    bool debug = false,
  }) async {
    try {
      final clean = email.trim();
      if (clean.isEmpty) return [];

      final uri = Uri.parse(searchTrainerByEmailUrl).replace(queryParameters: {
        if (debug) "debug": "1",
      });

      final resp = await http.post(
        uri,
        body: {"email": clean},
      );

      final data = _decode(resp);

      if (debug) {
        Get.snackbar(
          "DEBUG search_trainer_by_email.php",
          resp.body.length > 600 ? resp.body.substring(0, 600) : resp.body,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 6),
        );
      }

      if (data["success"] == true && data["trainers"] is List) {
        final list = (data["trainers"] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return list;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _pickTrainerByEmailSheet() async {
    final emailCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    return await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSB) {
            Future<void> doSearch({bool debug = false}) async {
              final q = emailCtrl.text.trim();
              if (q.isEmpty) {
                setSB(() => results = []);
                return;
              }
              setSB(() => searching = true);
              final r = await _searchTrainerByEmail(q, debug: debug);
              setSB(() {
                searching = false;
                results = r;
              });

              if (!debug && r.isEmpty) {
                Get.snackbar(
                  "Не найдено",
                  "Тренер с таким email не найден.\nПроверь точный email и что role = coach.",
                  snackPosition: SnackPosition.BOTTOM,
                  margin: const EdgeInsets.all(12),
                );
              }
            }

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
                        "Поиск тренера по email (role=coach)",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => doSearch(),
                      decoration: InputDecoration(
                        labelText: "Точный email тренера",
                        hintText: "Aleks_er@bk.ru",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => doSearch(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => doSearch(),
                            icon: const Icon(Icons.search),
                            label: const Text("Найти"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => doSearch(debug: true),
                            icon: const Icon(Icons.bug_report_outlined),
                            label: const Text("DEBUG"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (searching)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      )
                    else if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          "Введите точный email и нажмите «Найти».",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final t = results[i];
                            final id = _asInt(t["id"]);
                            final email = (t["email"] ?? "").toString();
                            final fn = (t["first_name"] ?? "").toString();
                            final ln = (t["last_name"] ?? "").toString();
                            final name = ("$fn $ln").trim();
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: ClubDashboardPalette.lightGreen,
                                child: Icon(
                                  Icons.person_outline,
                                  color: ClubDashboardPalette.primaryGreen,
                                ),
                              ),
                              title: Text(
                                name.isEmpty ? "Тренер #$id" : name,
                              ),
                              subtitle: Text(email),
                              onTap: () => Navigator.pop(context, {
                                "id": id,
                                "name": name.isEmpty ? "Тренер #$id" : name,
                                "email": email,
                              }),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickTeam() async {
    final source = _orderedTeams.isNotEmpty ? _orderedTeams : teams;

    if (source.isEmpty) {
      Get.snackbar("Команды", "Список команд пуст");
      return;
    }

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            itemBuilder: (context, i) {
              final t = source[i] as Map<String, dynamic>;
              final id = _asInt(t["id"]);
              final name = _asString(t["name"]) ?? "Команда #$id";
              final cat = _asString(t["category"]) ?? "";
              final isSelected = selectedTeamId == id;

              return ListTile(
                onTap: () => Navigator.pop(context, t),
                leading: CircleAvatar(
                  backgroundColor: ClubDashboardPalette.lightGreen,
                  child: Icon(
                    Icons.group_outlined,
                    color: ClubDashboardPalette.primaryGreen,
                  ),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
                subtitle: cat.isEmpty ? null : Text(cat),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: ClubDashboardPalette.primaryGreen,
                      )
                    : const Icon(Icons.chevron_right),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: source.length,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedTeamId = _asInt(picked["id"]);
        selectedTeamName = _asString(picked["name"]) ?? "Команда";
      });
    }
  }

  void _openSelectedTeam() {
    final tid = selectedTeamId ?? 0;
    if (tid <= 0) {
      Get.snackbar("Команда", "Сначала выберите команду");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamDashboardScreen(
          teamId: tid,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        ),
      ),
    );
  }

  Future<void> _createTeamDialog() async {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: "Футбол");
    XFile? pickedLogo;
    final ImagePicker picker = ImagePicker();

    int? selectedCoachId;
    String selectedCoachName = "Не выбран";

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
            child: StatefulBuilder(
              builder: (context, setSB) {
                return Column(
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
                        "Создать команду",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Название команды",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(
                        labelText: "Категория (вид спорта)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await _pickTrainerByEmailSheet();
                        if (picked != null) {
                          setSB(() {
                            selectedCoachId = _asInt(picked["id"]);
                            selectedCoachName =
                                _asString(picked["name"]) ??
                                    "Тренер #$selectedCoachId";
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: ClubDashboardPalette.lightGreen,
                              child: Icon(
                                selectedCoachId == null
                                    ? Icons.person_search_outlined
                                    : Icons.person_outline,
                                color: ClubDashboardPalette.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Тренер",
                                    style: TextStyle(
                                      color:
                                          ClubDashboardPalette.textMuted,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedCoachName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await _pickTrainerByEmailSheet();
                                if (picked != null) {
                                  setSB(() {
                                    selectedCoachId = _asInt(picked["id"]);
                                    selectedCoachName =
                                        _asString(picked["name"]) ??
                                            "Тренер #$selectedCoachId";
                                  });
                                }
                              },
                              child: const Text("Выбрать"),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final x = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                          maxWidth: 1200,
                        );
                        if (x != null) {
                          setSB(() => pickedLogo = x);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: ClubDashboardPalette.lightGreen,
                              backgroundImage: pickedLogo != null
                                  ? FileImage(File(pickedLogo!.path))
                                  : null,
                              child: pickedLogo == null
                                  ? Icon(
                                      Icons.image_outlined,
                                      color:
                                          ClubDashboardPalette.primaryGreen,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pickedLogo == null
                                    ? "Выбрать логотип команды (необязательно)"
                                    : "Логотип выбран ✅",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            Get.snackbar(
                              "Ошибка",
                              "Введите название команды",
                            );
                            return;
                          }
                          if (selectedCoachId == null ||
                              selectedCoachId == 0) {
                            Get.snackbar(
                              "Ошибка",
                              "Выберите тренера (coach)",
                            );
                            return;
                          }
                          Navigator.pop(context);
                          await _createTeam(
                            name: nameCtrl.text.trim(),
                            category: categoryCtrl.text.trim(),
                            coachId: selectedCoachId!,
                            logo: pickedLogo,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              ClubDashboardPalette.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Создать",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _createTeam({
    required String name,
    required String category,
    required int coachId,
    XFile? logo,
  }) async {
    Get.snackbar("Команда", "Создаю...");

    try {
      final uri = Uri.parse(createTeamUrl);

      final req = http.MultipartRequest("POST", uri);

      req.fields["club_id"] = clubId.toString();
      req.fields["coach_id"] = coachId.toString();
      req.fields["name"] = name;
      req.fields["category"] = category.isEmpty ? "Футбол" : category;

      if (logo != null) {
        req.files.add(await http.MultipartFile.fromPath("logo", logo.path));
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      final data = _decode(resp);

      if (data["success"] == true) {
        Get.snackbar("Готово", "Команда создана");
        await _reloadAll();
      } else {
        Get.snackbar(
          "Ошибка",
          _asString(data["message"]) ?? "Не удалось создать команду",
        );
      }
    } catch (e) {
      Get.snackbar("Сеть", "Ошибка соединения: $e");
    }
  }

  Future<void> _linkEventPlan({
    required int eventId,
    required int planId,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse(linkEventPlanUrl),
        body: {
          "event_id": eventId.toString(),
          "plan_id": planId.toString(),
        },
      );
      final data = _decode(resp);
      if (data["success"] == true) {
        Get.snackbar("Готово", "План привязан к событию");
      } else {
        Get.snackbar(
          "Ошибка",
          _asString(data["message"]) ?? "Не удалось привязать план",
        );
      }
    } catch (_) {
      Get.snackbar("Сеть", "Ошибка соединения");
    }
  }

  Future<Map<String, dynamic>> _loadAllClubBundle() async {
    List<dynamic> localTeams = teams;
    List<dynamic> localTrainers = trainers;
    List<dynamic> localEvents = events;

    Map<String, dynamic>? clubProfile;

    try {
      final resp = await http.post(
        Uri.parse(getClubProfileUrl),
        body: {"club_id": clubId.toString()},
      );
      final data = _decode(resp);
      if (data["success"] == true && data["club"] is Map) {
        clubProfile = Map<String, dynamic>.from(data["club"]);
      }
    } catch (_) {}

    try {
      if (localTeams.isEmpty) {
        final resp = await http.post(
          Uri.parse(getClubTeamsUrl),
          body: {"club_id": clubId.toString()},
        );
        final data = _decode(resp);
        if (data["success"] == true) {
          localTeams = (data["teams"] as List?) ?? [];
        }
      }
      if (localTrainers.isEmpty) {
        final resp = await http.post(
          Uri.parse(getClubTrainersUrl),
          body: {"club_id": clubId.toString()},
        );
        final data = _decode(resp);
        if (data["success"] == true) {
          localTrainers = (data["trainers"] as List?) ?? [];
        }
      }
      if (localEvents.isEmpty) {
        final resp = await http.post(
          Uri.parse(getClubEventsUrl),
          body: {"club_id": clubId.toString()},
        );
        final data = _decode(resp);
        if (data["success"] == true) {
          localEvents = (data["events"] as List?) ?? [];
        }
      }
    } catch (_) {}

    return {
      "club_id": clubId,
      "club": clubProfile,
      "teams": localTeams,
      "trainers": localTrainers,
      "events": localEvents,
    };
  }

 Future<bool> _ensureFeature(
  String featureCode, {
  required String title,
  required String description,
}) async {
  debugPrint('CLUB CHECK FEATURE: $featureCode');
  debugPrint('CLUB FEATURES BEFORE: ${_subscription.features}');
  debugPrint('CLUB USER ID: $clubId');

  if (_subscription.has(featureCode)) return true;

  final activated = await showPremiumBottomSheet(
    context,
    title: title,
    description: description,
  );

  debugPrint('CLUB ACTIVATED RESULT: $activated');

  if (activated) {
    try {
      _subscription = await SubscriptionService.getUserSubscription(
        userId: clubId,
        role: 'club',
      );

      debugPrint('CLUB FEATURES AFTER: ${_subscription.features}');

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('REFRESH CLUB SUBSCRIPTION ERROR: $e');
    }
  }

  return _subscription.has(featureCode);
}
  String _mapClubModuleToFeature(ClubModuleType type) {
    switch (type) {
      case ClubModuleType.trainingEditor:
        return 'club_training_editor';
      case ClubModuleType.videoAnalysis:
        return 'club_video_analysis';
      case ClubModuleType.plansBase:
        return 'club_plans';
      case ClubModuleType.heatmap:
        return 'club_heatmap';
      default:
        return '';
    }
  }

  bool _isPremiumClubModule(ClubModuleType type) {
    return type == ClubModuleType.trainingEditor ||
        type == ClubModuleType.videoAnalysis ||
        type == ClubModuleType.plansBase ||
        type == ClubModuleType.heatmap;
  }

  void _openModule(ClubModuleType type) async {
    if (type == ClubModuleType.trainingEditor) {
      final ok = await _ensureFeature(
        'club_training_editor',
        title: 'Графический редактор',
        description:
            'Профессиональный графический редактор доступен только по подписке клуба.',
      );
      if (!ok) return;
    }

    if (type == ClubModuleType.videoAnalysis) {
      final ok = await _ensureFeature(
        'club_video_analysis',
        title: 'Видеоанализ',
        description:
            'Инструменты видеоанализа доступны только по платному тарифу.',
      );
      if (!ok) return;
    }

    if (type == ClubModuleType.plansBase) {
      final ok = await _ensureFeature(
        'club_plans',
        title: 'Планы и конспекты',
        description:
            'База планов и конспектов доступна только по подписке клуба.',
      );
      if (!ok) return;

      final tid = selectedTeamId ?? 0;
      if (tid <= 0) {
        Get.snackbar("Команда", "Сначала выберите команду");
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlanFoldersScreen(
            clubId: clubId,
            clubName: clubName,
            teamId: tid,
          ),
        ),
      );
      return;
    }

    if (type == ClubModuleType.heatmap) {
      final ok = await _ensureFeature(
        'club_heatmap',
        title: 'Heatmap',
        description:
            'Тепловые карты и аналитика доступны только на PRO-тарифе.',
      );
      if (!ok) return;
    }

    if (type == ClubModuleType.trainers) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeamTrainersScreen(
            clubId: clubId,
            clubName: clubName,
            teams: teams,
          ),
        ),
      );
      return;
    }

    if (type == ClubModuleType.calendar) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClubCalendarScreen(
            clubId: clubId,
            clubName: clubName,
            teams: teams,
          ),
        ),
      );
      return;
    }

    if (type == ClubModuleType.attendance) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttendanceScreen(
            clubId: clubId,
            clubName: clubName,
            teams: teams,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubModuleScreen(
          clubId: clubId,
          type: type,
          loadBundle: _loadAllClubBundle,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _clubModuleBanners() {
    return [
      {
        "type": ClubModuleType.clubInfo,
        "title": "Профиль клуба",
        "subtitle": "Описание, адрес, команды",
        "icon": Icons.shield_outlined,
        "color": ClubDashboardPalette.lightGreen,
        "iconColor": ClubDashboardPalette.primaryGreen,
      },
      {
        "type": ClubModuleType.trainers,
        "title": "Тренеры",
        "subtitle": "Список тренеров клуба",
        "icon": Icons.people_outline,
        "color": const Color(0xFFE8F2FF),
        "iconColor": const Color(0xFF0066CC),
      },
      {
        "type": ClubModuleType.calendar,
        "title": "Календарь",
        "subtitle": "События всех команд",
        "icon": Icons.calendar_month_outlined,
        "color": const Color(0xFFE8F8E8),
        "iconColor": ClubDashboardPalette.primaryGreen,
      },
      {
        "type": ClubModuleType.attendance,
        "title": "Посещаемость",
        "subtitle": "Журнал отметок",
        "icon": Icons.fact_check_outlined,
        "color": const Color(0xFFE6F7FF),
        "iconColor": const Color(0xFF007AFF),
      },
      {
        "type": ClubModuleType.clubChat,
        "title": "Чат клуба",
        "subtitle": "Тренеры + админ",
        "icon": Icons.forum_outlined,
        "color": const Color(0xFFF0F2FF),
        "iconColor": const Color(0xFF7E3AED),
      },
      {
        "type": ClubModuleType.plansBase,
        "title": "Планы",
        "subtitle": "Конспекты и шаблоны",
        "icon": Icons.menu_book_outlined,
        "color": const Color(0xFFFFF4E6),
        "iconColor": const Color(0xFFFF9500),
      },
      {
        "type": ClubModuleType.trainingEditor,
        "title": "Редактор",
        "subtitle": "Схемы/упражнения",
        "icon": Icons.draw_outlined,
        "color": const Color(0xFFF3E8FF),
        "iconColor": const Color(0xFF7E3AED),
      },
      {
        "type": ClubModuleType.videoAnalysis,
        "title": "Видеоанализ",
        "subtitle": "Разбор матчей",
        "icon": Icons.video_camera_back_outlined,
        "color": const Color(0xFFFFF9E6),
        "iconColor": const Color(0xFFFFCC00),
      },
      {
        "type": ClubModuleType.heatmap,
        "title": "Heatmap",
        "subtitle": "Тепловая карта",
        "icon": Icons.grid_view_rounded,
        "color": const Color(0xFFE8F5FF),
        "iconColor": const Color(0xFF00B8D4),
      },
      {
        "type": ClubModuleType.clubNews,
        "title": "Новости",
        "subtitle": "Лента клуба",
        "icon": Icons.newspaper_outlined,
        "color": const Color(0xFFFFF0F0),
        "iconColor": const Color(0xFFFF6B6B),
      },
    ];
  }

  Future<void> _openDashboardBgPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetColors.map((c) {
                final isSelected = _dashboardBgColor.value == c.value;
                return GestureDetector(
                  onTap: () async {
                    setState(() => _dashboardBgColor = c);
                    Navigator.pop(context);
                    await _saveUserPrefs();
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openModuleStyleSheet(String typeKey) async {
    final current = Map<String, dynamic>.from(_moduleStyles[typeKey] ?? {});

    String? bgColor = current["bgColor"];
    String? textColor = current["textColor"];
    String? iconColor = current["iconColor"];
    String? iconBgColor = current["iconBgColor"];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSB) {
            Widget colorPickerRow(
              String title,
              String? selected,
              Function(String) onPick,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetColors.map((c) {
                      final hex = _colorToHex(c);
                      final isSelected = selected == hex;
                      return GestureDetector(
                        onTap: () => setSB(() => onPick(hex)),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  colorPickerRow(
                    "Цвет фона",
                    bgColor,
                    (v) => bgColor = v,
                  ),
                  const SizedBox(height: 16),
                  colorPickerRow(
                    "Цвет текста",
                    textColor,
                    (v) => textColor = v,
                  ),
                  const SizedBox(height: 16),
                  colorPickerRow(
                    "Цвет иконки",
                    iconColor,
                    (v) => iconColor = v,
                  ),
                  const SizedBox(height: 16),
                  colorPickerRow(
                    "Фон иконки",
                    iconBgColor,
                    (v) => iconBgColor = v,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _moduleStyles[typeKey] = {
                            "bgColor": bgColor,
                            "textColor": textColor,
                            "iconColor": iconColor,
                            "iconBgColor": iconBgColor,
                          };
                        });
                        Navigator.pop(context);
                        await _saveUserPrefs();
                      },
                      child: const Text("Сохранить"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openTeamStyleSheet(int teamId) async {
    final current = Map<String, dynamic>.from(_teamStyles[teamId] ?? {});

    String? bgColor = current["bgColor"];
    String? textColor = current["textColor"];
    String? subTextColor = current["subTextColor"];
    String? iconBgColor = current["iconBgColor"];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final maxHeight = MediaQuery.of(context).size.height * 0.82;

        return SafeArea(
          top: false,
          child: SizedBox(
            height: maxHeight,
            child: StatefulBuilder(
              builder: (context, setSB) {
                Widget colorRow(
                  String title,
                  String? selected,
                  Function(String) onPick,
                ) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _presetColors.map((c) {
                          final hex = _colorToHex(c);
                          final isSelected = selected == hex;

                          return GestureDetector(
                            onTap: () => setSB(() => onPick(hex)),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Настройка карточки команды",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            colorRow("Фон карточки", bgColor, (v) => bgColor = v),
                            const SizedBox(height: 20),
                            colorRow("Цвет названия", textColor, (v) => textColor = v),
                            const SizedBox(height: 20),
                            colorRow("Цвет подписи", subTextColor, (v) => subTextColor = v),
                            const SizedBox(height: 20),
                            colorRow("Фон иконки", iconBgColor, (v) => iconBgColor = v),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              _teamStyles[teamId] = {
                                "bgColor": bgColor,
                                "textColor": textColor,
                                "subTextColor": subTextColor,
                                "iconBgColor": iconBgColor,
                              };
                            });
                            Navigator.pop(context);
                            await _saveUserPrefs();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClubDashboardPalette.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Сохранить",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    String value = hex.replaceAll('#', '');
    if (value.length == 6) buffer.write('ff');
    buffer.write(value);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  List<dynamic> _sortByIdList(List<dynamic> source, List<int> ids) {
    final map = <int, dynamic>{};
    for (final item in source) {
      final m = item as Map<String, dynamic>;
      map[_asInt(m["id"])] = item;
    }

    final result = <dynamic>[];
    for (final id in ids) {
      if (map.containsKey(id)) {
        result.add(map[id]);
      }
    }

    for (final item in source) {
      if (!result.contains(item)) {
        result.add(item);
      }
    }

    return result;
  }

  Widget _buildClubHeader() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ClubDashboardPalette.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: isEditingClubInfo ? _pickClubLogo : null,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ClubDashboardPalette.primaryGreen.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (clubLogoFile != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(35),
                            child: Image.file(
                              clubLogoFile!,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          )
                        else if (clubLogoPath != null && clubLogoPath!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(35),
                            child: Image.network(
                              clubLogoPath!,
                              key: ValueKey(clubLogoPath),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultLogo();
                              },
                            ),
                          )
                        else
                          _buildDefaultLogo(),
                        if (isEditingClubInfo)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: ClubDashboardPalette.primaryGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: isEditingClubInfo
                      ? TextField(
                          controller: clubNameController,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ClubDashboardPalette.text,
                          ),
                          decoration: InputDecoration(
                            hintText: "Введите название клуба",
                            hintStyle: const TextStyle(
                              color: ClubDashboardPalette.textLight,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.done, size: 20),
                              onPressed: () {
                                if (clubNameController.text.trim().isNotEmpty) {
                                  _updateClubProfile();
                                }
                              },
                            ),
                          ),
                          maxLength: 50,
                        )
                      : GestureDetector(
                          onLongPress: () {
                            setState(() {
                              isEditingClubInfo = true;
                              clubNameController.text = clubName;
                            });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clubName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: ClubDashboardPalette.text,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Нажмите и удерживайте для редактирования",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ClubDashboardPalette.textLight,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            if (isEditingClubInfo)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isEditingClubInfo = false;
                          clubNameController.text = clubName;
                          newLogoFile = null;
                        });
                      },
                      child: const Text(
                        "Отмена",
                        style: TextStyle(
                          color: ClubDashboardPalette.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _updateClubProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ClubDashboardPalette.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Сохранить",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultLogo() {
    return Container(
      decoration: BoxDecoration(
        color: ClubDashboardPalette.primaryGreen.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.sports_soccer_outlined,
          size: 32,
          color: ClubDashboardPalette.primaryGreen,
        ),
      ),
    );
  }

  Future<void> _pickClubLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      setState(() {
        newLogoFile = pickedFile;
        clubLogoFile = File(pickedFile.path);
      });
    }
  }

  Widget _buildModuleBanner(
    Map<String, dynamic> item, {
    Map<String, dynamic>? styleData,
    bool editMode = false,
    VoidCallback? onCustomize,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = MediaQuery.of(context).size.width > 600;

        final bgColor = styleData?["bgColor"] != null
            ? _colorFromHex(styleData!["bgColor"])
            : item['color'] as Color;

        final iconColor = styleData?["iconColor"] != null
            ? _colorFromHex(styleData!["iconColor"])
            : item['iconColor'] as Color;

        final textColor = styleData?["textColor"] != null
            ? _colorFromHex(styleData!["textColor"])
            : Colors.black;

        final iconBgColor = styleData?["iconBgColor"] != null
            ? _colorFromHex(styleData!["iconBgColor"])
            : Colors.white;

        final moduleType = item['type'] as ClubModuleType;
        final featureCode = _mapClubModuleToFeature(moduleType);
        final showProBadge = _isPremiumClubModule(moduleType) &&
            !_subscription.has(featureCode);

        return Stack(
          children: [
            Material(
              color: bgColor,
              borderRadius: BorderRadius.circular(isTablet ? 12 : 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(isTablet ? 12 : 16),
                onTap: editMode ? null : () => _openModule(moduleType),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(isTablet ? 12 : 16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isTablet ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTablet ? 8 : 10),
                              decoration: BoxDecoration(
                                color: iconBgColor,
                                borderRadius: BorderRadius.circular(
                                  isTablet ? 8 : 12,
                                ),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                size: isTablet ? 20 : 24,
                                color: iconColor,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                        SizedBox(height: isTablet ? 8 : 12),
                        Text(
                          item['title'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: isTablet ? 13 : 14,
                            color: textColor,
                          ),
                        ),
                        if (!isTablet) const SizedBox(height: 4),
                        Text(
                          item['subtitle'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isTablet ? 11 : 12,
                            color: textColor.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showProBadge)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    "PRO",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            if (editMode)
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: onCustomize,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.palette_outlined,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCreateTeamButton() {
    return FloatingActionButton(
      onPressed: _createTeamDialog,
      backgroundColor: ClubDashboardPalette.primaryGreen,
      foregroundColor: ClubDashboardPalette.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.add, size: 24),
    );
  }

  Future<int?> _pickPlanId(BuildContext context) async {
    if (plans.isEmpty) return null;
    return await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            itemBuilder: (context, i) {
              final p = plans[i] as Map<String, dynamic>;
              final id = _asInt(p["id"]);
              final title = _asString(p["title"]) ??
                  _asString(p["name"]) ??
                  "План #$id";
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: ClubDashboardPalette.lightGreen,
                  child: Icon(
                    Icons.menu_book,
                    color: ClubDashboardPalette.primaryGreen,
                  ),
                ),
                title: Text(title),
                onTap: () => Navigator.pop(context, id),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: plans.length,
          ),
        );
      },
    );
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: _dashboardBgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ClubDashboardPalette.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Панель клуба",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: ClubDashboardPalette.text,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: "Фон панели",
            onPressed: _openDashboardBgPicker,
            icon: const Icon(
              Icons.format_color_fill_outlined,
              color: Colors.black87,
            ),
          ),
          IconButton(
            tooltip: _editLayoutMode
                ? "Готово"
                : "Редактировать панель",
            onPressed: () async {
              setState(() => _editLayoutMode = !_editLayoutMode);
              if (!_editLayoutMode) {
                await _saveUserPrefs();
              }
            },
            icon: Icon(
              _editLayoutMode ? Icons.check : Icons.edit_outlined,
              color: Colors.black87,
            ),
          ),
          IconButton(
            tooltip: "Обновить",
            onPressed: _reloadAll,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: _buildCreateTeamButton(),
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: ClubDashboardPalette.primaryGreen,
                ),
              )
            : error != null
                ? _ErrorView(text: error!, onRetry: _reloadAll)
                : RefreshIndicator(
                    onRefresh: _reloadAll,
                    color: ClubDashboardPalette.primaryGreen,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildClubHeader()),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 24 : 16,
                            0,
                            isTablet ? 24 : 16,
                            12,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _TopStatsCard(
                              teamsCount: teams.length,
                              trainersCount: trainers.length,
                              eventsCount: events.length,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 24 : 16,
                            0,
                            isTablet ? 24 : 16,
                            16,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _TeamPickerCard(
                              teamName: selectedTeamName,
                              onPick: _pickTeam,
                              onOpen: _openSelectedTeam,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 24 : 16,
                            0,
                            isTablet ? 24 : 16,
                            8,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _SectionTitle(
                              title: "Команды клуба",
                              right: "всего: ${_orderedTeams.length}",
                            ),
                          ),
                        ),
                        if (_orderedTeams.isEmpty)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              isTablet ? 24 : 16,
                              0,
                              isTablet ? 24 : 16,
                              16,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: const _EmptyHint(
                                text:
                                    "Команд пока нет. Нажмите + чтобы создать.",
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              isTablet ? 24 : 16,
                              0,
                              isTablet ? 24 : 16,
                              24,
                            ),
                            sliver: SliverReorderableList(
                              itemCount: _orderedTeams.length,
                              itemBuilder: (context, index) {
                                final team =
                                    _orderedTeams[index] as Map<String, dynamic>;
                                final teamId = _asInt(team["id"]);

                                return Container(
                                  key: ValueKey("team_$teamId"),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      if (_editLayoutMode)
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: Container(
                                            width: 40,
                                            height: 56,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.drag_handle,
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: _TeamTile(
                                          team: team,
                                          selectedId: selectedTeamId,
                                          styleData: _teamStyles[teamId],
                                          onCustomize: _editLayoutMode
                                              ? () => _openTeamStyleSheet(teamId)
                                              : null,
                                          onTap: () {
                                            setState(() {
                                              selectedTeamId =
                                                  _asInt(team["id"]);
                                              selectedTeamName =
                                                  _asString(team["name"]) ??
                                                      "Команда";
                                            });
                                            _openSelectedTeam();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onReorder: (oldIndex, newIndex) async {
                                if (!_editLayoutMode) return;
                                if (newIndex > oldIndex) newIndex -= 1;

                                setState(() {
                                  final item =
                                      _orderedTeams.removeAt(oldIndex);
                                  _orderedTeams.insert(newIndex, item);
                                });

                                await _saveUserPrefs();
                              },
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 24 : 16,
                            0,
                            isTablet ? 24 : 16,
                            8,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _SectionTitle(
                              title: "Модули клуба",
                              right: "${_moduleItems.length} модулей",
                            ),
                          ),
                        ),
                        if (_editLayoutMode)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              isTablet ? 24 : 16,
                              0,
                              isTablet ? 24 : 16,
                              32,
                            ),
                            sliver: SliverReorderableList(
                              itemCount: _moduleItems.length,
                              proxyDecorator: (child, index, animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, _) {
                                    return Material(
                                      color: Colors.transparent,
                                      elevation: 8,
                                      borderRadius: BorderRadius.circular(16),
                                      child: child,
                                    );
                                  },
                                );
                              },
                              itemBuilder: (context, index) {
                                final item = _moduleItems[index];
                                final typeKey = item["type"].toString();

                                return Container(
                                  key: ValueKey("module_$typeKey"),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: Container(
                                          width: 40,
                                          height: isTablet ? 145 : 138,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.drag_handle),
                                        ),
                                      ),
                                      Expanded(
                                        child: SizedBox(
                                          height: isTablet ? 145 : 138,
                                          child: _buildModuleBanner(
                                            item,
                                            styleData: _moduleStyles[typeKey]
                                                    is Map<String, dynamic>
                                                ? _moduleStyles[typeKey]
                                                : (_moduleStyles[typeKey] is Map
                                                    ? Map<String, dynamic>.from(
                                                        _moduleStyles[typeKey],
                                                      )
                                                    : null),
                                            editMode: true,
                                            onCustomize: () =>
                                                _openModuleStyleSheet(typeKey),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onReorder: (oldIndex, newIndex) async {
                                if (newIndex > oldIndex) newIndex -= 1;

                                setState(() {
                                  final item = _moduleItems.removeAt(oldIndex);
                                  _moduleItems.insert(newIndex, item);
                                });

                                await _saveUserPrefs();
                              },
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              isTablet ? 24 : 16,
                              0,
                              isTablet ? 24 : 16,
                              32,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isTablet ? 3 : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: isTablet ? 1.2 : 1.4,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = _moduleItems[index];
                                  final typeKey = item["type"].toString();

                                  return _buildModuleBanner(
                                    item,
                                    styleData: _moduleStyles[typeKey]
                                        is Map<String, dynamic>
                                        ? _moduleStyles[typeKey]
                                        : (_moduleStyles[typeKey] is Map
                                            ? Map<String, dynamic>.from(
                                                _moduleStyles[typeKey],
                                              )
                                            : null),
                                  );
                                },
                                childCount: _moduleItems.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

enum ClubModuleType {
  clubInfo,
  trainers,
  calendar,
  attendance,
  clubChat,
  trainingEditor,
  plansBase,
  videoAnalysis,
  heatmap,
  clubNews,
}

class ClubModuleScreen extends StatefulWidget {
  final int clubId;
  final ClubModuleType type;
  final Future<Map<String, dynamic>> Function() loadBundle;

  const ClubModuleScreen({
    super.key,
    required this.clubId,
    required this.type,
    required this.loadBundle,
  });

  @override
  State<ClubModuleScreen> createState() => _ClubModuleScreenState();
}

class _ClubModuleScreenState extends State<ClubModuleScreen>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  String? error;
  Map<String, dynamic>? bundle;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      bundle = null;
    });

    try {
      final b = await widget.loadBundle();
      if (!mounted) return;
      setState(() {
        bundle = b;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = "Не удалось загрузить данные модуля.";
      });
    }
  }

  String _title() {
    switch (widget.type) {
      case ClubModuleType.clubInfo:
        return "Профиль клуба";
      case ClubModuleType.trainers:
        return "Тренеры клуба";
      case ClubModuleType.calendar:
        return "Календарь клуба";
      case ClubModuleType.attendance:
        return "Журнал посещений";
      case ClubModuleType.clubChat:
        return "Общий чат клуба";
      case ClubModuleType.trainingEditor:
        return "Графический редактор";
      case ClubModuleType.plansBase:
        return "Планы / конспекты";
      case ClubModuleType.videoAnalysis:
        return "Видеоанализ";
      case ClubModuleType.heatmap:
        return "Тепловая карта";
      case ClubModuleType.clubNews:
        return "Лента новостей клуба";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubDashboardPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ClubDashboardPalette.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _title(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: ClubDashboardPalette.text,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: "Обновить",
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: ClubDashboardPalette.primaryGreen,
                ),
              )
            : error != null
                ? _ErrorView(text: error!, onRetry: _load)
                : _ClubModuleBody(
                    type: widget.type,
                    bundle: bundle ?? const {},
                  ),
      ),
    );
  }
}

class _ClubModuleBody extends StatelessWidget {
  final ClubModuleType type;
  final Map<String, dynamic> bundle;

  const _ClubModuleBody({
    required this.type,
    required this.bundle,
  });

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _asStr(dynamic v) => (v ?? "").toString();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final club =
        bundle["club"] is Map ? Map<String, dynamic>.from(bundle["club"]) : null;
    final teams = (bundle["teams"] as List?) ?? [];
    final trainers = (bundle["trainers"] as List?) ?? [];
    final events = (bundle["events"] as List?) ?? [];

    Widget header = Container(
      padding: const EdgeInsets.all(14),
      margin: EdgeInsets.fromLTRB(
        isTablet ? 24 : 16,
        12,
        isTablet ? 24 : 16,
        12,
      ),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: ClubDashboardPalette.lightGreen,
            child: Icon(
              Icons.shield_outlined,
              color: ClubDashboardPalette.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleForType(type),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Команд: ${teams.length} • Тренеров: ${trainers.length} • Событий: ${events.length}",
                  style: const TextStyle(
                    color: ClubDashboardPalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget body;
    switch (type) {
      case ClubModuleType.clubInfo:
        body = _clubInfoView(club, teams);
        break;
      case ClubModuleType.trainers:
        body = _trainersView(trainers);
        break;
      case ClubModuleType.calendar:
        body = _calendarView(events);
        break;
      case ClubModuleType.attendance:
        body = _stubView("Журнал посещений", "");
        break;
      case ClubModuleType.clubChat:
        body = _stubView("Общий чат", "");
        break;
      case ClubModuleType.trainingEditor:
        body = _stubView("Графический редактор", "");
        break;
      case ClubModuleType.plansBase:
        body = _stubView("База планов-конспектов", "");
        break;
      case ClubModuleType.videoAnalysis:
        body = _stubView("Видеоанализ", "");
        break;
      case ClubModuleType.heatmap:
        body = _stubView("Тепловая карта игры", "");
        break;
      case ClubModuleType.clubNews:
        body = _stubView("Лента новостей клуба", "");
        break;
    }

    return ListView(
      children: [
        header,
        Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 24 : 16,
            0,
            isTablet ? 24 : 16,
            24,
          ),
          child: body,
        ),
      ],
    );
  }

  static String _titleForType(ClubModuleType type) {
    switch (type) {
      case ClubModuleType.clubInfo:
        return "Профиль клуба";
      case ClubModuleType.trainers:
        return "Тренеры клуба";
      case ClubModuleType.calendar:
        return "Календарь клуба";
      case ClubModuleType.attendance:
        return "Журнал посещений";
      case ClubModuleType.clubChat:
        return "Общий чат клуба";
      case ClubModuleType.trainingEditor:
        return "Графический редактор";
      case ClubModuleType.plansBase:
        return "Планы / конспекты";
      case ClubModuleType.videoAnalysis:
        return "Видеоанализ";
      case ClubModuleType.heatmap:
        return "Тепловая карта";
      case ClubModuleType.clubNews:
        return "Новости клуба";
    }
  }

  Widget _clubInfoView(Map<String, dynamic>? club, List<dynamic> teams) {
    final clubName = club == null ? "Клуб" : _asStr(club["club_name"]).trim();
    final desc = club == null ? "" : _asStr(club["club_description"]).trim();
    final address = club == null ? "" : _asStr(club["club_address"]).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _whiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clubName.isEmpty ? "Клуб" : clubName,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              if (desc.isNotEmpty)
                Text(
                  desc,
                  style: const TextStyle(
                    color: ClubDashboardPalette.text,
                    height: 1.25,
                  ),
                )
              else
                const Text(
                  "Описание клуба пока недоступно",
                  style: TextStyle(
                    color: ClubDashboardPalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _whiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Состав клуба (команды)",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (teams.isEmpty)
                const Text(
                  "Команд нет.",
                  style: TextStyle(color: ClubDashboardPalette.textMuted),
                )
              else
                ...teams.take(20).map((e) {
                  final t = e as Map<String, dynamic>;
                  final id = _asInt(t["id"]);
                  final name = _asStr(t["name"]);
                  final cat = _asStr(t["category"]);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 18,
                          color: ClubDashboardPalette.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name.isEmpty ? "Команда #$id" : name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (cat.isNotEmpty)
                          Text(
                            cat,
                            style: const TextStyle(
                              color: ClubDashboardPalette.textMuted,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trainersView(List<dynamic> trainers) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Тренеры",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (trainers.isEmpty)
            const Text(
              "Тренеры не найдены.",
              style: TextStyle(color: ClubDashboardPalette.textMuted),
            )
          else
            ...trainers.map((e) {
              final t = e as Map<String, dynamic>;
              final fn = _asStr(t["first_name"]);
              final ln = _asStr(t["last_name"]);
              final email = _asStr(t["email"]);
              final name = ("$fn $ln").trim();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: ClubDashboardPalette.lightGreen,
                  child: Icon(
                    Icons.person_outline,
                    color: ClubDashboardPalette.primaryGreen,
                  ),
                ),
                title: Text(
                  name.isEmpty ? "Тренер" : name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: email.isEmpty ? null : Text(email),
              );
            }),
        ],
      ),
    );
  }

  Widget _calendarView(List<dynamic> events) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "События всех команд",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            const Text(
              "Событий нет.",
              style: TextStyle(color: ClubDashboardPalette.textMuted),
            )
          else
            ...events.take(30).map((e) {
              final ev = e as Map<String, dynamic>;
              final title = _asStr(ev["title"]).isNotEmpty
                  ? _asStr(ev["title"])
                  : _asStr(ev["name"]);
              final date = _asStr(ev["event_date"]).isNotEmpty
                  ? _asStr(ev["event_date"])
                  : _asStr(ev["date"]);
              final team = _asStr(ev["team_name"]);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: ClubDashboardPalette.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? "Событие" : title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (date.isNotEmpty) date,
                              if (team.isNotEmpty) team,
                            ].join(" • "),
                            style: const TextStyle(
                              color: ClubDashboardPalette.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _stubView(String title, String text) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: ClubDashboardPalette.text,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "",
            style: TextStyle(
              color: ClubDashboardPalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
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
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 44,
              color: ClubDashboardPalette.primaryGreen,
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubDashboardPalette.primaryGreen,
              ),
              child: const Text(
                "Повторить",
                style: TextStyle(color: Colors.white),
              ),
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
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: ClubDashboardPalette.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TopStatsCard extends StatelessWidget {
  final int teamsCount;
  final int trainersCount;
  final int eventsCount;

  const _TopStatsCard({
    required this.teamsCount,
    required this.trainersCount,
    required this.eventsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: ClubDashboardPalette.greenGradient,
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
          _StatChip(title: "Команды", value: "$teamsCount"),
          const SizedBox(width: 10),
          _StatChip(title: "Тренеры", value: "$trainersCount"),
          const SizedBox(width: 10),
          _StatChip(title: "События", value: "$eventsCount"),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String title;
  final String value;

  const _StatChip({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamPickerCard extends StatelessWidget {
  final String teamName;
  final VoidCallback onPick;
  final VoidCallback onOpen;

  const _TeamPickerCard({
    required this.teamName,
    required this.onPick,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: ClubDashboardPalette.lightGreen,
                child: Icon(
                  Icons.sports_soccer_outlined,
                  color: ClubDashboardPalette.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Выбранная команда",
                      style: TextStyle(
                        color: ClubDashboardPalette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text("Сменить"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ClubDashboardPalette.primaryGreen,
                  side: BorderSide(
                    color: ClubDashboardPalette.primaryGreen.withOpacity(0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpen,
              icon: const Icon(
                Icons.open_in_new_rounded,
                color: Colors.white,
              ),
              label: const Text(
                "Открыть панель команды",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubDashboardPalette.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? right;

  const _SectionTitle({
    required this.title,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
        if (right != null)
          Text(
            right!,
            style: const TextStyle(
              color: ClubDashboardPalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _TeamTile extends StatelessWidget {
  final Map<String, dynamic> team;
  final int? selectedId;
  final VoidCallback onTap;
  final dynamic styleData;
  final VoidCallback? onCustomize;

  const _TeamTile({
    required this.team,
    required this.selectedId,
    required this.onTap,
    this.styleData,
    this.onCustomize,
  });

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _asStr(dynamic v) => (v ?? "").toString();

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    String value = hex.replaceAll('#', '');
    if (value.length == 6) buffer.write('ff');
    buffer.write(value);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final id = _asInt(team["id"]);
    final name = _asStr(team["name"]).trim();
    final cat = _asStr(team["category"]).trim();
    final city = _asStr(team["city"]).trim();
    final isSelected = selectedId == id;

    final logoUrl = MediaUtils.normalizeUrl(team["logo"]?.toString());

    final Map<String, dynamic> s = styleData is Map<String, dynamic>
        ? styleData as Map<String, dynamic>
        : (styleData is Map ? Map<String, dynamic>.from(styleData) : {});

    final bgColor = s["bgColor"] != null
        ? _colorFromHex(s["bgColor"])
        : ClubDashboardPalette.white;

    final textColor = s["textColor"] != null
        ? _colorFromHex(s["textColor"])
        : Colors.black;

    final subTextColor = s["subTextColor"] != null
        ? _colorFromHex(s["subTextColor"])
        : ClubDashboardPalette.textMuted;

    final iconBgColor = s["iconBgColor"] != null
        ? _colorFromHex(s["iconBgColor"])
        : ClubDashboardPalette.lightGreen;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: ClubDashboardPalette.primaryGreen.withOpacity(0.35),
                  width: 2,
                )
              : Border.all(color: ClubDashboardPalette.border),
        ),
        child: ListTile(
          tileColor: Colors.transparent,
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClubDashboardPalette.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: logoUrl != null
                  ? Image.network(
                      logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.group_outlined,
                        size: 20,
                        color: ClubDashboardPalette.primaryGreen,
                      ),
                    )
                  : Icon(
                      Icons.group_outlined,
                      size: 20,
                      color: ClubDashboardPalette.primaryGreen,
                    ),
            ),
          ),
          title: Text(
            name.isEmpty ? "Команда #$id" : name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          subtitle: Text(
            [
              if (cat.isNotEmpty) cat,
              if (city.isNotEmpty) city,
            ].join(" • "),
            style: TextStyle(
              color: subTextColor,
              fontSize: 12,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onCustomize != null)
                InkWell(
                  onTap: onCustomize,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ClubDashboardPalette.border),
                    ),
                    child: const Icon(Icons.palette_outlined, size: 16),
                  ),
                ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ClubDashboardPalette.border),
                ),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.chevron_right,
                  size: 18,
                  color: isSelected
                      ? ClubDashboardPalette.primaryGreen
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}