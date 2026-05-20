// lib/presentation/team_screen/team_dashboard_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/routes/app_routes.dart';
import 'package:sportoteka/presentation/team_roster_screen/team_roster_screen.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_screen.dart';
import 'package:sportoteka/presentation/team_attendance_screen/team_attendance_journal_screen.dart';
import 'package:sportoteka/presentation/training_graphics/training_graphics_screen.dart';
import 'package:sportoteka/presentation/plans/plan_detail_screen.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';


class TeamDashboardScreen extends StatefulWidget {
  final int teamId;
  final String teamName;

  final int clubId;
  final String clubName;

  const TeamDashboardScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
  });
  @override
  State<TeamDashboardScreen> createState() => _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends State<TeamDashboardScreen> {
  // =============================
  // ✅ API
  // =============================
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getTeamProfileUrl = "$apiBase/get_team_profile.php";
  static const String updateTeamProfileUrl = "$apiBase/update_team_profile.php";
  static const String deleteTeamUrl = "$apiBase/delete_team.php";

  // =============================
  // ✅ STATE
  // =============================
  late String teamName;
  String teamCategory = "";
  String? teamLogoUrl; // network
  File? teamLogoFile; // local preview

  bool isEditing = false;
  bool isSaving = false;
  bool isDeleting = false;

  bool profileLoading = false;
  String? profileError;

  final TextEditingController teamNameCtrl = TextEditingController();
  final TextEditingController teamCategoryCtrl = TextEditingController();
  XFile? newLogoX;

  // =============================
  // МОДУЛИ КОМАНДЫ
  // =============================
  late final List<Map<String, dynamic>> _mainItems = [
    {
      "t": "Состав команды",
      "s": "Игроки, добавление, профили",
      "i": Icons.groups_2_outlined,
      "theme": ModuleThemes.basic,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeamRosterScreen(
            teamId: teamId,
            teamName: teamName,
          ),
        ),
      ),
    },
    {
      "t": "Календарь",
      "s": "Тренировки, игры, мероприятия",
      "i": Icons.calendar_month_outlined,
      "theme": ModuleThemes.calendar,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => TeamCalendarScreen(
              teamId: teamId,
              teamName: teamName,
            ),
          ),
    },
    {
      "t": "Журнал посещаемости",
      "s": "Даты и мероприятия из календаря",
      "i": Icons.fact_check_outlined,
      "theme": ModuleThemes.attendance,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => TeamAttendanceJournalScreen(
              teamId: teamId,
              teamName: teamName,
            ),
          ),
    },
    {
      "t": "Матчи",
      "s": "Список матчей и результаты",
      "i": Icons.sports_soccer_outlined,
      "theme": ModuleThemes.basic,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.toNamed(
            AppRoutes.teamMatchesScreen,
            arguments: teamId,
          ),
    },
    {
      "t": "Командный чат",
      "s": "Общий чат внутри команды",
      "i": Icons.forum_outlined,
      "theme": ModuleThemes.chat,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Get.snackbar("Модуль", "Чат подключим следующим этапом"),
    },
    {
      "t": "Визитная карточка",
      "s": "Информация о команде",
      "i": Icons.info_outline,
      "theme": ModuleThemes.basic,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.toNamed(
            AppRoutes.teamDescriptionScreen,
            arguments: teamId,
          ),
    },
  ];

  late final List<Map<String, dynamic>> _proItems = [
  {
    "t": "Графический редактор",
    "s": "Построение тренировок",
    "i": Icons.draw_outlined,
    "theme": ModuleThemes.editor,
    "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
          () => TrainingGraphicsScreen(
            clubId: widget.clubId,
            clubName: widget.clubName,
            teamId: teamId,
            teamName: teamName,
          ),
        ),
  },
  {
    "t": "Планы-конспекты",
    "s": "База хранения планов",
    "i": Icons.menu_book_outlined,
    "theme": ModuleThemes.plans,
    "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
          () => PlanFoldersScreen(
            clubId: widget.clubId,
            clubName: widget.clubName,
            teamId: teamId,
            selectMode: false,
            browsePlansMode: false,
          ),
        ),
  },
  {
    "t": "Видеоанализ",
    "s": "Разбор игр и тренировок",
    "i": Icons.video_camera_back_outlined,
    "theme": ModuleThemes.video,
    "onTap": (BuildContext context, int teamId, String teamName) =>
        Get.snackbar("Модуль", "Видеоанализ подключим следующим этапом"),
  },
  {
    "t": "Тепловая карта",
    "s": "Тепловые зоны активности",
    "i": Icons.map_outlined,
    "theme": ModuleThemes.analytics,
    "onTap": (BuildContext context, int teamId, String teamName) =>
        Get.snackbar("Модуль", "Тепловую карту подключим следующим этапом"),
  },
  {
    "t": "Тестирование",
    "s": "Тесты и анализ результатов",
    "i": Icons.quiz_outlined,
    "theme": ModuleThemes.basic,
    "onTap": (BuildContext context, int teamId, String teamName) =>
        Get.snackbar("Модуль", "Тестирование подключим следующим этапом"),
  },
  {
    "t": "AI-анализ техники",
    "s": "AI разбор техники игрока",
    "i": Icons.auto_awesome_outlined,
    "theme": ModuleThemes.analytics,
    "onTap": (BuildContext context, int teamId, String teamName) =>
        Get.snackbar("Модуль", "AI-технику подключим следующим этапом"),
  },
  {
    "t": "AR-Paint цели",
    "s": "Цели на поле в AR",
    "i": Icons.center_focus_strong_outlined,
    "theme": ModuleThemes.editor,
    "onTap": (BuildContext context, int teamId, String teamName) =>
        Get.snackbar("Модуль", "AR-Paint подключим следующим этапом"),
  },
  {
    "t": "AI-план тренировок",
    "s": "Генерация плана тренировок",
    "i": Icons.psychology_alt_outlined,
    "theme": ModuleThemes.analytics,
    "onTap": (BuildContext context, int teamId, String teamName) =>
        Get.snackbar("Модуль", "AI-план подключим следующим этапом"),
  },
  {
    "t": "One Ring",
    "s": "Занесение результатов в программу",
    "i": Icons.ring_volume_outlined,
    "theme": ModuleThemes.basic,
    "onTap": (BuildContext context, int teamId, String teamName) =>
        Get.snackbar("Модуль", "One Ring подключим следующим этапом"),
  },
  {
    "t": "Файлообменник",
    "s": "Материалы и документы команды",
    "i": Icons.folder_shared_outlined,
    "theme": ModuleThemes.basic,
    "onTap": (BuildContext context, int teamId, String teamName) =>
        Get.snackbar("Модуль", "Файлообмен подключим следующим этапом"),
  },
  {
    "t": "Новости команды",
    "s": "Лента новостей команды",
    "i": Icons.feed_outlined,
    "theme": ModuleThemes.news,
    "onTap": (BuildContext context, int teamId, String teamName) =>
        Get.snackbar("Модуль", "Новости подключим следующим этапом"),
  },
];

  @override
  void initState() {
    super.initState();
    teamName = widget.teamName;
    teamNameCtrl.text = teamName;
    teamCategoryCtrl.text = teamCategory;
    _loadTeamProfileSilent();
  }

  @override
  void dispose() {
    teamNameCtrl.dispose();
    teamCategoryCtrl.dispose();
    super.dispose();
  }

  // =============================
  // HELPERS
  // =============================
  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final j = json.decode(resp.body);
      if (j is Map<String, dynamic>) return j;
      return {"success": false};
    } catch (_) {
      return {"success": false};
    }
  }

  String _asStr(dynamic v) => (v ?? "").toString();

  String? _normalizePhoto(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;

    if (s.startsWith("http://") || s.startsWith("https://")) return s;

    if (!s.startsWith("/")) s = "/$s";
    return "https://sportotekaapp.ru$s";
  }

  /// ✅ анти-кэш для картинки (чтобы лого менялось сразу)
  String? _bust(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;
    final sep = u.contains("?") ? "&" : "?";
    return "$u${sep}v=${DateTime.now().millisecondsSinceEpoch}";
  }

  Future<void> _pickTeamLogo() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (x != null) {
      setState(() {
        newLogoX = x;
        teamLogoFile = File(x.path); // ✅ сразу локальный preview
      });
    }
  }

  // =============================
  // API: LOAD PROFILE (silent)
  // =============================
  Future<void> _loadTeamProfileSilent() async {
    if (!mounted) return;
    setState(() {
      profileLoading = true;
      profileError = null;
    });

    try {
      final resp = await http
          .post(
            Uri.parse(getTeamProfileUrl),
            body: {"team_id": widget.teamId.toString()},
          )
          .timeout(const Duration(seconds: 10));

      final data = _decode(resp);
      if (!mounted) return;

      final ok = (data["success"] == true) || (data["status"] == "success");
      final team =
          (data["team"] is Map) ? Map<String, dynamic>.from(data["team"]) : null;

      if (ok && team != null) {
        final serverName = _asStr(team["name"]).trim();
        final serverCat = _asStr(team["category"]).trim();
        final serverLogoRaw = _normalizePhoto(_asStr(team["logo"]));
        final serverLogo = _bust(serverLogoRaw); // ✅ всегда новый url

        setState(() {
          if (serverName.isNotEmpty) teamName = serverName;
          teamCategory = serverCat;
          teamLogoUrl = serverLogo;
          profileLoading = false;

          if (!isEditing) {
            teamNameCtrl.text = teamName;
            teamCategoryCtrl.text = teamCategory;
          }
        });
      } else {
        setState(() {
          profileLoading = false;
          final msg = _asStr(data["message"]).trim();
          profileError = msg.isNotEmpty ? msg : "Не удалось загрузить профиль";
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        profileLoading = false;
        profileError = "Сетевая ошибка";
      });
    }
  }

  // =============================
  // API: UPDATE
  // =============================
  Future<void> _updateTeamProfile() async {
    final name = teamNameCtrl.text.trim();
    final cat = teamCategoryCtrl.text.trim();

    if (name.isEmpty) {
      Get.snackbar("Ошибка", "Введите название команды");
      return;
    }

    if (!mounted) return;
    setState(() => isSaving = true);

    try {
      final uri = Uri.parse(updateTeamProfileUrl);
      final req = http.MultipartRequest("POST", uri);

      req.fields["team_id"] = widget.teamId.toString();

      // ✅ совместимость: сервер может ждать team_name или name
      req.fields["team_name"] = name;
      req.fields["name"] = name;

      // ✅ category
      req.fields["category"] = cat;

      // ✅ файл отправляем ОДИН раз (logo)
      if (newLogoX != null) {
        req.files.add(await http.MultipartFile.fromPath("logo", newLogoX!.path));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final resp = await http.Response.fromStream(streamed);

      final data = _decode(resp);
      if (!mounted) return;

      final ok = (data["success"] == true) || (data["status"] == "success");
      if (ok) {
        // ✅ закрываем редактирование и убираем локальный preview
        setState(() {
          isEditing = false;
          newLogoX = null;
          teamLogoFile = null;
        });

        // ✅ подтянем актуальное с сервера (имя/категория/лого)
        await _loadTeamProfileSilent();

        // ✅ финальный "пинок" против кэша даже если url одинаковый
        if (mounted) {
          setState(() {
            teamLogoUrl = _bust(teamLogoUrl);
          });
        }

        Get.snackbar("Готово", "Команда обновлена");
      } else {
        final msg = _asStr(data["message"]).trim();
        final err = _asStr(data["error"]).trim();
        Get.snackbar(
          "Ошибка",
          (msg.isNotEmpty ? msg : "Не удалось обновить") +
              (err.isNotEmpty ? "\n$err" : ""),
        );
      }
    } catch (e) {
      Get.snackbar("Сеть", "Ошибка соединения");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // =============================
  // ✅ DELETE
  // =============================
  Future<void> _deleteTeam() async {
    if (isDeleting) return;

    final confirmCtrl = TextEditingController();
    bool acknowledged = false;
    bool canDelete = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            void recompute() {
              final wordOk = confirmCtrl.text.trim().toLowerCase() == "удалить";
              final next = acknowledged && wordOk;
              if (next != canDelete) {
                setD(() => canDelete = next);
              } else {
                setD(() {});
              }
            }

            return AlertDialog(
              title: const Text("Удалить команду навсегда?"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Это действие необратимо.\n\n"
                    "1) Поставьте галочку.\n"
                    "2) Введите слово подтверждения: «Удалить».",
                    style: TextStyle(height: 1.25),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: acknowledged,
                    onChanged: (v) {
                      acknowledged = v == true;
                      recompute();
                    },
                    title: const Text(
                      "Я понимаю, что команда будет удалена без восстановления",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Введите: Удалить",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => recompute(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Отмена"),
                ),
                ElevatedButton(
                  onPressed: canDelete ? () => Navigator.pop(ctx, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text("Удалить"),
                ),
              ],
            );
          },
        );
      },
    );

    confirmCtrl.dispose();
    if (ok != true) return;

    if (!mounted) return;
    setState(() => isDeleting = true);

    try {
      final resp = await http
          .post(
            Uri.parse(deleteTeamUrl),
            body: {"team_id": widget.teamId.toString()},
          )
          .timeout(const Duration(seconds: 10));

      final data = _decode(resp);
      final okResp = (data["success"] == true) || (data["status"] == "success");

      if (okResp) {
        Get.snackbar("Готово", "Команда удалена");
        if (mounted) Navigator.pop(context, true);
      } else {
        final msg = _asStr(data["message"]).trim();
        Get.snackbar("Ошибка", msg.isNotEmpty ? msg : "Не удалось удалить");
      }
    } catch (_) {
      Get.snackbar("Сеть", "Ошибка соединения");
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
  }

  // =============================
  // UI pieces
  // =============================
  Widget _buildDefaultLogo() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.sports_soccer_outlined,
          size: 30,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }

  Widget _teamAvatar() {
    return GestureDetector(
      onTap: isEditing ? _pickTeamLogo : null,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primaryGreen.withOpacity(0.28),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: (teamLogoFile != null)
                  ? Image.file(
                      teamLogoFile!,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    )
                  : (teamLogoUrl != null && teamLogoUrl!.isNotEmpty)
                      ? Image.network(
                          teamLogoUrl!,
                          key: ValueKey(teamLogoUrl), // ✅ форс перерисовки
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultLogo(),
                        )
                      : _buildDefaultLogo(),
            ),
            if (isEditing)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.edit, size: 16, color: AppColors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamHeader() {
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
              _teamAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: isEditing
                    ? Column(
                        children: [
                          TextField(
                            controller: teamNameCtrl,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              hintText: "Название команды",
                              hintStyle:
                                  TextStyle(color: AppColors.textTertiary),
                              border: InputBorder.none,
                              counterText: "",
                            ),
                            maxLength: 50,
                          ),
                          TextField(
                            controller: teamCategoryCtrl,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              hintText: "Категория / спорт (например Футбол)",
                              hintStyle:
                                  TextStyle(color: AppColors.textTertiary),
                              border: InputBorder.none,
                              counterText: "",
                            ),
                            maxLength: 30,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teamName,
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
                            teamCategory.isNotEmpty
                                ? teamCategory
                                : "Категория не указана",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isEditing = true;
                                    teamNameCtrl.text = teamName;
                                    teamCategoryCtrl.text = teamCategory;
                                  });
                                },
                                child: const Text(
                                  "Редактировать",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (profileLoading)
                                const Text(
                                  "обновление…",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else if (profileError != null)
                                const Text(
                                  "offline",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            setState(() {
                              isEditing = false;
                              teamNameCtrl.text = teamName;
                              teamCategoryCtrl.text = teamCategory;
                              newLogoX = null;
                              teamLogoFile = null;
                            });
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("Отмена"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving ? null : _updateTeamProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Text("Сохранить"),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // =============================
  // UI (main)
  // =============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          teamName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Обновить профиль",
            onPressed: _loadTeamProfileSilent,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: [
          _buildTeamHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  title: "Основные модули",
                  right: "всего: ${_mainItems.length}",
                ),
                const SizedBox(height: 8),
                _ModulesGrid(
                  items: _mainItems,
                  teamId: widget.teamId,
                  teamName: teamName,
                ),
                const SizedBox(height: 16),
                _SectionTitle(
                  title: "Профессиональные инструменты",
                  right: "всего: ${_proItems.length}",
                ),
                const SizedBox(height: 8),
                _ModulesGrid(
                  items: _proItems,
                  teamId: widget.teamId,
                  teamName: teamName,
                ),
                const SizedBox(height: 18),
                const _SectionTitle(title: "Опасная зона", right: ""),
                const SizedBox(height: 8),
                _UnsafeDeleteCard(
                  isDeleting: isDeleting,
                  onDelete: _deleteTeam,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================
// UI WIDGETS
// =============================
class _ModulesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int teamId;
  final String teamName;

  const _ModulesGrid({
    required this.items,
    required this.teamId,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
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

        return Material(
          color: theme.color,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => (it["onTap"] as Function)(context, teamId, teamName),
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
                    child: Icon(it["i"] as IconData, color: theme.iconColor),
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
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String right;

  const _SectionTitle({required this.title, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
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
    );
  }
}

class _UnsafeDeleteCard extends StatelessWidget {
  final bool isDeleting;
  final VoidCallback onDelete;

  const _UnsafeDeleteCard({
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ModuleThemes.danger.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: ModuleThemes.danger.iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Удаление команды",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: ModuleThemes.danger.iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Команда будет удалена без возможности восстановления.\n"
            "Для подтверждения нужно ввести слово «Удалить» в диалоге.",
            style: TextStyle(
              fontSize: 12,
              height: 1.25,
              color: ModuleThemes.danger.iconColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isDeleting ? null : onDelete,
              icon: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.delete_outline, color: ModuleThemes.danger.iconColor),
              label: Text(
                "Удалить команду",
                style: TextStyle(color: ModuleThemes.danger.iconColor),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ModuleThemes.danger.iconColor,
                side: BorderSide(color: ModuleThemes.danger.iconColor.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================
// THEMES (если у тебя уже есть в другом файле — удали этот блок и импортни свой)
// =============================
class ModuleTheme {
  final Color color;
  final Color iconColor;
  const ModuleTheme({required this.color, required this.iconColor});
}

class ModuleThemes {
  static const basic =
      ModuleTheme(color: Color(0xFFF3F4F6), iconColor: AppColors.textPrimary);
  static const calendar =
      ModuleTheme(color: Color(0xFFEFF6FF), iconColor: Color(0xFF2563EB));
  static const attendance =
      ModuleTheme(color: Color(0xFFF0FDF4), iconColor: Color(0xFF16A34A));
  static const chat =
      ModuleTheme(color: Color(0xFFFFF7ED), iconColor: Color(0xFFEA580C));
  static const editor =
      ModuleTheme(color: Color(0xFFF5F3FF), iconColor: Color(0xFF7C3AED));
  static const plans =
      ModuleTheme(color: Color(0xFFFDF2F8), iconColor: Color(0xFFDB2777));
  static const video =
      ModuleTheme(color: Color(0xFFFEE2E2), iconColor: Color(0xFFDC2626));
  static const analytics =
      ModuleTheme(color: Color(0xFFECFEFF), iconColor: Color(0xFF0891B2));
  static const news =
      ModuleTheme(color: Color(0xFFFAFAF9), iconColor: Color(0xFF0F172A));
  static const danger =
      ModuleTheme(color: Color(0xFFFFEBEE), iconColor: Color(0xFFB91C1C));
}
