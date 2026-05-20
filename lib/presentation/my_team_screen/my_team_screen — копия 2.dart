import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/routes/app_routes.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_screen.dart';
import 'package:sportoteka/presentation/team_roster_screen/team_roster_screen.dart';
import 'package:sportoteka/presentation/team_attendance_screen/team_attendance_journal_screen.dart';
import 'package:sportoteka/presentation/team_attendance_screen/team_attendance_screen.dart';

// =============================
// ✅ ТЕМЫ МОДУЛЕЙ (как в TeamDashboardScreen)
// =============================
enum ModuleTheme {
  basic,
  calendar,
  attendance,
  chat,
  editor,
  plans,
  video,
  analytics,
  news,
  danger,
}

extension ModuleThemeExtension on ModuleTheme {
  Color get color {
    switch (this) {
      case ModuleTheme.basic:
        return AppColors.card;
      case ModuleTheme.calendar:
        return const Color(0xFFE8F5E9);
      case ModuleTheme.attendance:
        return const Color(0xFFE3F2FD);
      case ModuleTheme.chat:
        return const Color(0xFFF3E5F5);
      case ModuleTheme.editor:
        return const Color(0xFFFFF8E1);
      case ModuleTheme.plans:
        return const Color(0xFFF1F8E9);
      case ModuleTheme.video:
        return const Color(0xFFE8EAF6);
      case ModuleTheme.analytics:
        return const Color(0xFFE0F2F1);
      case ModuleTheme.news:
        return const Color(0xFFECEFF1);
      case ModuleTheme.danger:
        return const Color(0xFFFFEBEE);
    }
  }

  Color get iconColor {
    switch (this) {
      case ModuleTheme.basic:
        return AppColors.primaryGreen;
      case ModuleTheme.calendar:
        return const Color(0xFF2E7D32);
      case ModuleTheme.attendance:
        return const Color(0xFF1565C0);
      case ModuleTheme.chat:
        return const Color(0xFF7B1FA2);
      case ModuleTheme.editor:
        return const Color(0xFFF57C00);
      case ModuleTheme.plans:
        return const Color(0xFF558B2F);
      case ModuleTheme.video:
        return const Color(0xFF3949AB);
      case ModuleTheme.analytics:
        return const Color(0xFF00897B);
      case ModuleTheme.news:
        return const Color(0xFF455A64);
      case ModuleTheme.danger:
        return const Color(0xFFD32F2F);
    }
  }
}

class ModuleThemes {
  static final ModuleTheme basic = ModuleTheme.basic;
  static final ModuleTheme calendar = ModuleTheme.calendar;
  static final ModuleTheme attendance = ModuleTheme.attendance;
  static final ModuleTheme chat = ModuleTheme.chat;
  static final ModuleTheme editor = ModuleTheme.editor;
  static final ModuleTheme plans = ModuleTheme.plans;
  static final ModuleTheme video = ModuleTheme.video;
  static final ModuleTheme analytics = ModuleTheme.analytics;
  static final ModuleTheme news = ModuleTheme.news;
  static final ModuleTheme danger = ModuleTheme.danger;
}

class MyTeamScreen extends StatefulWidget {
  /// ✅ если пришли — значит экран открыт как "команда клуба"
  final int? teamId;
  final String? teamName;

  const MyTeamScreen({
    super.key,
    this.teamId,
    this.teamName,
  });

  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  // =============================
  // ✅ API
  // =============================
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String checkTeamClubAccessUrl =
      "$apiBase/check_team_club_access.php";
  static const String getTeamsByCoachUrl = "$apiBase/get_team_by_coach.php";
  static const String getPlayersUrl = "$apiBase/get_players.php";
  static const String updateTeamPhotoUrl = "$apiBase/update_team_photo.php";
  static const String getMyTeamsUrl = "$apiBase/get_my_teams.php";
  static const String getTeamEventsUrl = "$apiBase/get_team_events.php";

  // =============================
  // STATE
  // =============================
  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> assignedTeams = [];
  List<Map<String, dynamic>> players = [];

  bool isLoading = true;
  bool isPlayersLoading = false;

  int selectedTeamId = 0;
  String selectedTeamName = "";
  String selectedTeamLogo = "";

  String selectedAccessLevel = "";
  bool isClubAssignedTeam = false;
  String openMode = "";

  bool _createAutoOpened = false;

  @override
  void initState() {
    super.initState();

    int? passedTeamId = widget.teamId;
    String passedTeamName = (widget.teamName ?? "").trim();

    final args = Get.arguments;
    if ((passedTeamId == null || passedTeamId == 0) && args is Map) {
      final a = Map<String, dynamic>.from(args);

      final tId = _asInt(a["team_id"] ?? a["teamId"]);
      if (tId > 0) passedTeamId = tId;

      final tName = (a["team_name"] ?? a["teamName"] ?? "").toString().trim();
      if (tName.isNotEmpty) passedTeamName = tName;

      openMode = (a["mode"] ?? "").toString().trim();

      final al = (a["access_level"] ?? a["accessLevel"] ?? "").toString().trim();
      if (al.isNotEmpty) selectedAccessLevel = al;
    }

    if (passedTeamId != null && passedTeamId > 0) {
      selectedTeamId = passedTeamId;
      selectedTeamName = passedTeamName.isEmpty ? "Команда" : passedTeamName;
      isClubAssignedTeam = true;
      openMode = "club_assigned";
      isLoading = false;
      fetchPlayers(selectedTeamId);
      _loadClubAccess(selectedTeamId);
      return;
    }

    _loadAllTeams();
  }

  Future<void> _loadAllTeams() async {
    setState(() => isLoading = true);

    await fetchTeams(silent: true);
    await fetchAssignedTeams(silent: true);

    if (teams.isEmpty && assignedTeams.isEmpty) {
      _autoOpenCreateIfNeeded();
    }

    if (mounted) setState(() => isLoading = false);
  }

  // =============================
  // HELPERS
  // =============================
  Map<String, dynamic> _decode(http.Response r) {
    try {
      final j = json.decode(r.body);
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return {"status": "error"};
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _asStr(dynamic v) => (v ?? "").toString();

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == "1" || v.toLowerCase() == "true";
    return false;
  }

  String _normAccess(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return "";
    if (s.contains("admin") || s.contains("owner") || s.contains("root")) {
      return "admin";
    }
    if (s.contains("edit") || s.contains("write") || s.contains("coach")) {
      return "edit";
    }
    if (s.contains("view") || s.contains("read")) {
      return "view";
    }
    if (s.contains("pro") || s.contains("premium") || s.contains("club")) {
      return "edit";
    }
    return s;
  }

  bool get canEditTeam {
    if (!isClubAssignedTeam) return true;
    final a = _normAccess(selectedAccessLevel);
    return a == "admin" || a == "edit" || a.isEmpty;
  }

  bool _detectClubAssigned(Map<String, dynamic> team) {
    final clubId = _asInt(team["club_id"] ?? team["clubId"]);
    final fromClub = _asBool(team["from_club"] ?? team["is_club_team"]);
    final accessLevel = _asStr(team["access_level"] ?? team["team_access"] ?? "");

    if (clubId > 0) return true;
    if (fromClub) return true;

    if (accessLevel.isNotEmpty) {
      final s = accessLevel.toLowerCase();
      if (s.contains("club") ||
          s.contains("pro") ||
          s.contains("premium") ||
          s.contains("view") ||
          s.contains("edit") ||
          s.contains("admin")) {
        return true;
      }
    }
    return false;
  }

  void _snackErr(String message) {
    Get.snackbar(
      "Ошибка",
      message,
      backgroundColor: AppColors.error.withOpacity(0.9),
      colorText: AppColors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
    );
  }

  void _snackOk(String message) {
    Get.snackbar(
      "Готово",
      message,
      backgroundColor: AppColors.primaryGreen.withOpacity(0.9),
      colorText: AppColors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
    );
  }

  Future<void> _loadClubAccess(int teamId) async {
    try {
      final resp = await http.post(
        Uri.parse(checkTeamClubAccessUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"team_id": teamId}),
      );

      final data = _decode(resp);
      if (!mounted) return;

      if (data["status"] == "success" || data["success"] == true) {
        setState(() {
          isClubAssignedTeam = _asInt(data["club_id"]) > 0 ||
              _asBool(data["club_assigned"]) ||
              _asBool(data["is_club_assigned"]) ||
              _asBool(data["clubTeam"]);
        });
      }
    } catch (_) {}
  }

  // =============================
  // LOAD TEAMS (coach)
  // =============================
  Future<void> fetchTeams({bool silent = false}) async {
    if (!silent && mounted) setState(() => isLoading = true);

    final coachId = await PrefUtils.getUserId();
    if (coachId == null) {
      teams = [];
      if (!silent && mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse(getTeamsByCoachUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"coach_id": coachId}),
      );

      final data = _decode(resp);

      if (data["status"] == "success" && data["teams"] is List) {
        teams = List<Map<String, dynamic>>.from(data["teams"]);
      } else {
        teams = [];
      }

      if (teams.length == 1 && selectedTeamId == 0 && widget.teamId == null) {
        _selectTeam(teams.first, forceClub: false);
      }

      if (!silent && mounted) setState(() => isLoading = false);
    } catch (_) {
      teams = [];
      if (!silent && mounted) setState(() => isLoading = false);
    }
  }

  // =============================
  // LOAD ASSIGNED TEAMS (user)
  // =============================
  Future<void> fetchAssignedTeams({bool silent = false}) async {
    final userId = await PrefUtils.getUserId();
    if (userId == null) {
      assignedTeams = [];
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse(getMyTeamsUrl),
        body: {"user_id": userId.toString()},
      );

      final data = _decode(resp);

      if ((data["success"] == true || data["status"] == "success") &&
          data["teams"] is List) {
        assignedTeams = (data["teams"] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        assignedTeams = [];
      }

      if (teams.isEmpty && assignedTeams.isNotEmpty && selectedTeamId == 0) {
        _selectAssignedTeam(assignedTeams.first);
      }

      if (!silent && mounted) setState(() {});
    } catch (_) {
      assignedTeams = [];
    }
  }

  void _autoOpenCreateIfNeeded() {
    if (assignedTeams.isNotEmpty) return;
    if (_createAutoOpened) return;
    _createAutoOpened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Get.toNamed(AppRoutes.createTeamScreen)?.then((_) {
        _createAutoOpened = false;
        _loadAllTeams();
      });
    });
  }

  // =============================
  // LOAD PLAYERS
  // =============================
  Future<void> fetchPlayers(int teamId) async {
    if (mounted) {
      setState(() {
        isPlayersLoading = true;
        players.clear();
      });
    }

    try {
      final resp = await http.post(
        Uri.parse(getPlayersUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"team_id": teamId}),
      );

      final data = _decode(resp);

      if (data["status"] == "success" || data["success"] == true) {
        await Future.delayed(const Duration(milliseconds: 150));
        players = List<Map<String, dynamic>>.from(data["players"] ?? []);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => isPlayersLoading = false);
    }
  }

  // =============================
  // TEAM PICK
  // =============================
  void _selectTeam(Map<String, dynamic> team, {required bool forceClub}) {
    final id = _asInt(team["id"]);
    final name = _asStr(team["name"]).trim();
    final logo = _asStr(team["logo"]).trim();

    setState(() {
      selectedTeamId = id;
      selectedTeamName = name.isEmpty ? "Команда #$id" : name;
      selectedTeamLogo = logo;
      isClubAssignedTeam = forceClub ? true : _detectClubAssigned(team);
      openMode = forceClub ? "club_assigned" : "coach_my";
      selectedAccessLevel = "admin";
    });

    fetchPlayers(id);
    _loadClubAccess(id);
  }

  void _selectAssignedTeam(Map<String, dynamic> t) {
    final id = _asInt(t["team_id"] ?? t["id"]);
    final name = _asStr(t["team_name"] ?? t["name"]).trim();
    final logo = _asStr(t["logo"]).trim();
    final access = _asStr(t["access_level"]).trim();

    setState(() {
      selectedTeamId = id;
      selectedTeamName = name.isEmpty ? "Команда #$id" : name;
      selectedTeamLogo = logo;
      isClubAssignedTeam = true;
      openMode = "club_assigned";
      selectedAccessLevel = access;
    });

    fetchPlayers(id);
  }

  void _backLogic() {
    final isClubMode = (widget.teamId != null && widget.teamId! > 0) ||
        openMode == "club_assigned";

    if (isClubMode && widget.teamId != null && widget.teamId! > 0) {
      Navigator.pop(context);
      return;
    }

    if (selectedTeamId != 0) {
      setState(() {
        selectedTeamId = 0;
        selectedTeamName = "";
        selectedTeamLogo = "";
        players.clear();
        isClubAssignedTeam = false;
        openMode = "";
        selectedAccessLevel = "";
      });
      return;
    }

    Navigator.pop(context);
  }

  // =============================
  // UPDATE TEAM PHOTO
  // =============================
  Future<void> _pickAndUploadTeamLogo() async {
    if (selectedTeamId == 0) {
      _snackErr("Сначала выберите команду");
      return;
    }

    if (!canEditTeam) {
      _snackErr("У вас доступ только для просмотра");
      return;
    }

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1400,
    );
    if (x == null) return;

    try {
      _snackOk("Загружаю фото...");

      final req = http.MultipartRequest("POST", Uri.parse(updateTeamPhotoUrl));
      req.fields["team_id"] = selectedTeamId.toString();

      final uid = await PrefUtils.getUserId();
      if (uid != null) req.fields["user_id"] = uid.toString();

      req.files.add(await http.MultipartFile.fromPath("logo", x.path));

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp);

      if (data["success"] == true || data["status"] == "success") {
        final newLogo = _asStr(data["logo"]).trim();
        if (newLogo.isNotEmpty) {
          setState(() => selectedTeamLogo = newLogo);
        }
        _snackOk("Фото команды обновлено ✅");
      } else {
        _snackErr(_asStr(data["message"]).isEmpty
            ? "Не удалось обновить фото"
            : _asStr(data["message"]));
      }
    } catch (e) {
      _snackErr("Ошибка загрузки: $e");
    }
  }

  // =============================
  // Attendance: pick eventId + eventTitle
  // =============================
  Future<List<Map<String, dynamic>>> _fetchTeamEvents() async {
    final resp = await http.post(
      Uri.parse(getTeamEventsUrl),
      body: {"team_id": selectedTeamId.toString()},
    ).timeout(const Duration(seconds: 10));

    final data = _decode(resp);

    if ((data["success"] == true || data["status"] == "success") &&
        data["events"] is List) {
      return (data["events"] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  String _eventTitle(Map<String, dynamic> e) {
    final t = _asStr(e["title"]).trim();
    final n = _asStr(e["name"]).trim();
    return t.isNotEmpty ? t : (n.isNotEmpty ? n : "Событие");
  }

  String _eventDate(Map<String, dynamic> e) {
    final d1 = _asStr(e["event_date"]).trim();
    final d2 = _asStr(e["date"]).trim();
    final d3 = _asStr(e["start_date"]).trim();
    return d1.isNotEmpty ? d1 : (d2.isNotEmpty ? d2 : d3);
  }

  Future<void> _openAttendancePicker() async {
    if (selectedTeamId == 0) return;

    try {
      final events = await _fetchTeamEvents();
      if (!mounted) return;

      if (events.isEmpty) {
        Get.snackbar(
          "Посещаемость",
          "Событий нет. Добавьте тренировку/игру в календарь.",
        );
        return;
      }

      events.sort((a, b) => _eventDate(a).compareTo(_eventDate(b)));

      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => SafeArea(
          top: false,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = events[i];
              final title = _eventTitle(e);
              final date = _eventDate(e);

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.event_available_outlined, color: Color(0xFF1565C0)),
                ),
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: date.isEmpty ? null : Text(date),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, e),
              );
            },
          ),
        ),
      );

      if (picked == null) return;

      final pickedEventId = _asInt(picked["id"]);
      final pickedTitle = _eventTitle(picked);

      if (pickedEventId == 0) {
        Get.snackbar("Ошибка", "Не удалось определить eventId");
        return;
      }

      Get.to(() => TeamAttendanceScreen(
            teamId: selectedTeamId,
            teamName: selectedTeamName,
            eventId: pickedEventId,
            eventTitle: pickedTitle,
          ));
    } catch (_) {
      Get.snackbar("Ошибка", "Не удалось открыть посещаемость");
    }
  }

  // =============================
  // UI COMPONENTS
  // =============================

  // ✅ ШАПКА КОМАНДЫ (как в TeamDashboardScreen)
  Widget _buildTeamHeader() {
    final accessTag = _normAccess(selectedAccessLevel);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.card,
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Аватар команды
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.28),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(35),
                      child: selectedTeamLogo.isNotEmpty
                          ? Image.network(
                              selectedTeamLogo,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildDefaultLogo(),
                            )
                          : _buildDefaultLogo(),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: InkWell(
                      onTap: canEditTeam ? _pickAndUploadTeamLogo : null,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: canEditTeam
                              ? AppColors.primaryGreen
                              : AppColors.textTertiary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          canEditTeam
                              ? Icons.photo_camera_outlined
                              : Icons.lock_outline,
                          size: 16,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedTeamName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Team ID: $selectedTeamId • Игроков: ${players.length}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (isClubAssignedTeam)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: AppColors.primaryGreen.withOpacity(0.25)),
                        ),
                        child: Text(
                          "Клубный доступ • ${accessTag.isEmpty ? "PRO" : accessTag.toUpperCase()}",
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultLogo() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(Icons.shield_outlined,
            size: 30, color: AppColors.primaryGreen),
      ),
    );
  }

  // ✅ КОМПОНЕНТЫ ДЛЯ ГРИДА МОДУЛЕЙ
  Widget _sectionTitle(String title, String right) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Text(
            right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modulesGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        final theme = it["theme"] as ModuleTheme;
        final enabled = (it["enabled"] as bool?) ?? true;

        return Material(
          color: theme.color,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? it["onTap"] as VoidCallback : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.55,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        it["i"] as IconData,
                        color: theme.iconColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      it["t"] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        height: 1.15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        it["s"] as String,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.2,
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
  }

  // ✅ СПИСОК КОМАНД (две секции: тренерские + назначенные)
  Widget _teamsList() {
    if (teams.isEmpty && assignedTeams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_off, size: 44, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              const Text(
                "Команд пока нет",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.toNamed(AppRoutes.createTeamScreen)
                      ?.then((_) => _loadAllTeams()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Создать команду",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (teams.isNotEmpty) ...[
          const Text(
            "Мои команды",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...teams.map((t) => _teamListTile(t, isAssigned: false)),
          const SizedBox(height: 18),
        ],
        if (assignedTeams.isNotEmpty) ...[
          const Text(
            "Команды клуба (доступ)",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...assignedTeams.map((t) => _teamListTile(t, isAssigned: true)),
        ],
      ],
    );
  }

  Widget _teamListTile(Map<String, dynamic> t, {required bool isAssigned}) {
    final id = isAssigned ? _asInt(t["team_id"] ?? t["id"]) : _asInt(t["id"]);
    final name = _asStr(isAssigned ? (t["team_name"] ?? t["name"]) : t["name"])
        .trim();
    final cat = _asStr(t["category"]).trim();
    final logo = _asStr(t["logo"]).trim();
    final accessLevel = _asStr(t["access_level"]).trim();

    return InkWell(
      onTap: () {
        if (isAssigned) {
          _selectAssignedTeam(t);
        } else {
          _selectTeam(t, forceClub: false);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [AppColors.cardShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: logo.isNotEmpty
                    ? Image.network(
                        logo,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildListTileLogo(isAssigned),
                      )
                    : _buildListTileLogo(isAssigned),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.isEmpty ? "Команда #$id" : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isAssigned)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            (_normAccess(accessLevel).isEmpty
                                ? "ДОСТУП"
                                : _normAccess(accessLevel).toUpperCase()),
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cat.isEmpty ? "Team ID: $id" : "$cat • Team ID: $id",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildListTileLogo(bool isAssigned) {
    return Container(
      decoration: BoxDecoration(
        color: isAssigned
            ? const Color(0xFFE3F2FD)
            : AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Icon(
          Icons.shield_outlined,
          color: isAssigned
              ? const Color(0xFF1565C0)
              : AppColors.primaryGreen,
          size: 22,
        ),
      ),
    );
  }

  // ✅ ШИММЕР ДЛЯ ЗАГРУЗКИ
  Widget _shimmerTeams() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      child: Column(
        children: List.generate(
          6,
          (i) => Shimmer.fromColors(
            baseColor: const Color(0xFFE9EDF2),
            highlightColor: Colors.white,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ ТЕЛО С ВЫБРАННОЙ КОМАНДОЙ
  Widget _teamScrollableBody() {
    final mainItems = <Map<String, dynamic>>[
      {
        "t": "Состав команды",
        "s": "Игроки, добавление, профили",
        "i": Icons.groups_2_outlined,
        "theme": ModuleThemes.basic,
        "enabled": true,
        "onTap": () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamRosterScreen(
                  teamId: selectedTeamId,
                  teamName: selectedTeamName,
                ),
              ),
            ),
      },
      {
        "t": "Календарь",
        "s": "Тренировки, игры, мероприятия",
        "i": Icons.calendar_month_outlined,
        "theme": ModuleThemes.calendar,
        "enabled": true,
        "onTap": () => Get.to(() => TeamCalendarScreen(
              teamId: selectedTeamId,
              teamName: selectedTeamName,
            )),
      },
      {
        "t": "Журнал посещаемости",
        "s": "Сводная таблица по датам",
        "i": Icons.fact_check_outlined,
        "theme": ModuleThemes.attendance,
        "enabled": true,
        "onTap": () => Get.to(() => TeamAttendanceJournalScreen(
              teamId: selectedTeamId,
              teamName: selectedTeamName,
            )),
      },
      {
        "t": "Посещаемость по событию",
        "s": "Выбор тренировки/игры из календаря",
        "i": Icons.event_available_outlined,
        "theme": ModuleThemes.attendance,
        "enabled": true,
        "onTap": _openAttendancePicker,
      },
      {
        "t": "Матчи",
        "s": "Список матчей и результаты",
        "i": Icons.sports_soccer_outlined,
        "theme": ModuleThemes.basic,
        "enabled": true,
        "onTap": () => Get.toNamed(
          AppRoutes.teamMatchesScreen,
          arguments: selectedTeamId,
        ),
      },
      {
        "t": "Командный чат",
        "s": "Общий чат внутри команды",
        "i": Icons.forum_outlined,
        "theme": ModuleThemes.chat,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "Чат подключим следующим этапом"),
      },
      {
        "t": "Визитная карточка",
        "s": "Информация о команде",
        "i": Icons.info_outline,
        "theme": ModuleThemes.basic,
        "enabled": true,
        "onTap": () => Get.toNamed(
          AppRoutes.teamDescriptionScreen,
          arguments: selectedTeamId,
        ),
      },
    ];

    final proItems = <Map<String, dynamic>>[
      {
        "t": "Графический редактор",
        "s": "Построение тренировок",
        "i": Icons.draw_outlined,
        "theme": ModuleThemes.editor,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "Редактор подключим следующим этапом"),
      },
      {
        "t": "Планы-конспекты",
        "s": "База хранения планов",
        "i": Icons.menu_book_outlined,
        "theme": ModuleThemes.plans,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "Планы подключим следующим этапом"),
      },
      {
        "t": "Видеоанализ",
        "s": "Разбор игр и тренировок",
        "i": Icons.video_camera_back_outlined,
        "theme": ModuleThemes.video,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "Видеоанализ подключим следующим этапом"),
      },
      {
        "t": "Тепловая карта",
        "s": "Тепловые зоны активности",
        "i": Icons.map_outlined,
        "theme": ModuleThemes.analytics,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "Тепловую карту подключим следующим этапом"),
      },
      {
        "t": "Тестирование",
        "s": "Тесты и анализ результатов",
        "i": Icons.quiz_outlined,
        "theme": ModuleThemes.basic,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "Тестирование подключим следующим этапом"),
      },
      {
        "t": "AI-анализ техники",
        "s": "AI разбор техники игрока",
        "i": Icons.auto_awesome_outlined,
        "theme": ModuleThemes.analytics,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "AI-технику подключим следующим этапом"),
      },
      {
        "t": "AR-Paint цели",
        "s": "Цели на поле в AR",
        "i": Icons.center_focus_strong_outlined,
        "theme": ModuleThemes.editor,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "AR-Paint подключим следующим этапом"),
      },
      {
        "t": "AI-план тренировок",
        "s": "Генерация плана тренировок",
        "i": Icons.psychology_alt_outlined,
        "theme": ModuleThemes.analytics,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "AI-план подключим следующим этапом"),
      },
      {
        "t": "One Ring",
        "s": "Занесение результатов в программу",
        "i": Icons.ring_volume_outlined,
        "theme": ModuleThemes.basic,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "One Ring подключим следующим этапом"),
      },
      {
        "t": "Файлообменник",
        "s": "Материалы и документы команды",
        "i": Icons.folder_shared_outlined,
        "theme": ModuleThemes.basic,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "Файлообмен подключим следующим этапом"),
      },
      {
        "t": "Новости команды",
        "s": "Лента новостей команды",
        "i": Icons.feed_outlined,
        "theme": ModuleThemes.news,
        "enabled": true,
        "onTap": () =>
            Get.snackbar("Модуль", "Новости подключим следующим этапом"),
      },
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        _buildTeamHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                "Основные модули",
                "всего: ${mainItems.length}",
              ),
              const SizedBox(height: 8),
              _modulesGrid(mainItems),
              const SizedBox(height: 16),
              _sectionTitle(
                "Профессиональные инструменты",
                "всего: ${proItems.length}",
              ),
              const SizedBox(height: 8),
              _modulesGrid(proItems),
            ],
          ),
        ),
      ],
    );
  }

  // =============================
  // MAIN BUILD
  // =============================
  @override
  Widget build(BuildContext context) {
    final showTeam = selectedTeamId != 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _backLogic,
        ),
        title: Text(
          selectedTeamId == 0 ? "Команды" : selectedTeamName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Обновить",
            onPressed: () async {
              if (selectedTeamId == 0) {
                await _loadAllTeams();
              } else {
                await fetchPlayers(selectedTeamId);
                await _loadClubAccess(selectedTeamId);
              }
            },
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: isLoading
          ? _shimmerTeams()
          : (!showTeam)
              ? _teamsList()
              : _teamScrollableBody(),
    );
  }
}