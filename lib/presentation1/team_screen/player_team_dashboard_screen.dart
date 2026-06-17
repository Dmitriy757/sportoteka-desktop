import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/presentation/team_roster_screen/team_roster_screen.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_screen.dart';
import 'package:sportoteka/presentation/player_attendance/my_attendance_screen.dart';
import 'package:sportoteka/routes/app_routes.dart';

class PlayerTeamDashboardScreen extends StatefulWidget {
  final int teamId;
  final String teamName;
  final String? teamLogo;

  const PlayerTeamDashboardScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    this.teamLogo,
  });

  @override
  State<PlayerTeamDashboardScreen> createState() =>
      _PlayerTeamDashboardScreenState();
}

class _PlayerTeamDashboardScreenState extends State<PlayerTeamDashboardScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getTeamProfileUrl = "$apiBase/get_team_profile.php";

  String teamName = "";
  String teamCategory = "";
  String? teamLogoUrl;

  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();

    teamName = widget.teamName.trim().isNotEmpty
        ? widget.teamName.trim()
        : "Команда #${widget.teamId}";

    teamLogoUrl = _normalizePhoto(widget.teamLogo);

    _loadTeamProfile();
  }

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final body = resp.body.trim();
      if (body.isEmpty) {
        return {"success": false, "message": "EMPTY_BODY"};
      }

      final j = json.decode(body);

      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);

      return {"success": false, "message": "INVALID_JSON_FORMAT"};
    } catch (_) {
      return {"success": false, "message": "JSON_DECODE_ERROR"};
    }
  }

  String _asStr(dynamic v) => (v ?? "").toString();

  String? _normalizePhoto(String? raw) {
    if (raw == null) return null;

    var s = raw.trim();
    if (s.isEmpty) return null;

    if (s.startsWith("http://") || s.startsWith("https://")) {
      return s;
    }

    if (s.startsWith("uploads/")) {
      return "https://sportotekaapp.ru/$s";
    }

    if (!s.startsWith("/")) s = "/$s";
    return "https://sportotekaapp.ru$s";
  }

  Future<void> _loadTeamProfile() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final resp = await http.post(
        Uri.parse(getTeamProfileUrl),
        body: {"team_id": widget.teamId.toString()},
      ).timeout(const Duration(seconds: 10));

      debugPrint("TEAM PROFILE RESPONSE: ${resp.body}");

      final data = _decode(resp);
      final ok = (data["success"] == true) || (data["status"] == "success");

      Map<String, dynamic>? team;
      if (data["team"] is Map) {
        team = Map<String, dynamic>.from(data["team"]);
      } else if (data["data"] is Map) {
        team = Map<String, dynamic>.from(data["data"]);
      } else if (data.isNotEmpty) {
        team = data;
      }

      if (!mounted) return;

      if (ok && team != null) {
        final serverName = _asStr(
          team["team_name"] ??
              team["name"] ??
              team["title"],
        ).trim();

        final serverCat = _asStr(
          team["category"] ??
              team["sport_type"] ??
              team["sport"] ??
              team["type"],
        ).trim();

        final serverLogo = _normalizePhoto(
          _asStr(
            team["team_logo"] ??
                team["logo"] ??
                team["logo_url"] ??
                team["image"] ??
                team["photo"],
          ),
        );

        debugPrint("TEAM PROFILE PARSED NAME: $serverName");
        debugPrint("TEAM PROFILE PARSED CATEGORY: $serverCat");
        debugPrint("TEAM PROFILE PARSED LOGO: $serverLogo");

        setState(() {
          if (serverName.isNotEmpty) {
            teamName = serverName;
          }

          if (serverCat.isNotEmpty) {
            teamCategory = serverCat;
          }

          if (serverLogo != null && serverLogo.isNotEmpty) {
            teamLogoUrl = serverLogo;
          }

          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          error = _asStr(data["message"]).trim().isNotEmpty
              ? _asStr(data["message"]).trim()
              : null;
        });
      }
    } catch (e) {
      debugPrint("TEAM PROFILE ERROR: $e");

      if (!mounted) return;
      setState(() {
        loading = false;
        error = "Сетевая ошибка";
      });
    }
  }

  Widget _logo() {
    return Container(
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
        child: (teamLogoUrl != null && teamLogoUrl!.isNotEmpty)
            ? Image.network(
                teamLogoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.primaryGreen.withOpacity(0.10),
      child: const Center(
        child: Icon(
          Icons.sports_soccer_outlined,
          color: AppColors.primaryGreen,
          size: 28,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _items => [
        {
          "t": "Состав команды",
          "s": "Игроки и профили",
          "i": Icons.groups_2_outlined,
          "theme": ModuleThemes.basic,
          "onTap": () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeamRosterScreen(
                    teamId: widget.teamId,
                    teamName: teamName,
                  ),
                ),
              ),
        },
        {
          "t": "Календарь",
          "s": "Тренировки, игры",
          "i": Icons.calendar_month_outlined,
          "theme": ModuleThemes.calendar,
          "onTap": () => Get.to(
                () => TeamCalendarScreen(
                  teamId: widget.teamId,
                  teamName: teamName,
                ),
              ),
        },
        {
          "t": "Моя посещаемость",
          "s": "Только мои статусы",
          "i": Icons.fact_check_outlined,
          "theme": ModuleThemes.attendance,
          "onTap": () => Get.to(
                () => MyAttendanceScreen(
                  teamId: widget.teamId,
                  teamName: teamName,
                ),
              ),
        },
        {
          "t": "Матчи",
          "s": "Список и результаты",
          "i": Icons.sports_soccer_outlined,
          "theme": ModuleThemes.basic,
          "onTap": () => Get.toNamed(
                AppRoutes.teamMatchesScreen,
                arguments: widget.teamId,
              ),
        },
        {
          "t": "Командный чат",
          "s": "Общий чат команды",
          "i": Icons.forum_outlined,
          "theme": ModuleThemes.chat,
          "onTap": () => Get.snackbar(
                "Модуль",
                "Чат подключим следующим этапом",
              ),
        },
      ];

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
            onPressed: _loadTeamProfile,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: loading && teamName.isEmpty && (teamLogoUrl == null || teamLogoUrl!.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : error != null && teamName.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [AppColors.cardShadow],
                      ),
                      child: Row(
                        children: [
                          _logo(),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  teamName.isNotEmpty
                                      ? teamName
                                      : "Команда #${widget.teamId}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
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
                                const Text(
                                  "Режим игрока (только просмотр)",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textTertiary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionTitle(
                      title: "Модули команды",
                      right: "всего: ${_items.length}",
                    ),
                    const SizedBox(height: 8),
                    _ModulesGrid(items: _items),
                  ],
                ),
    );
  }
}

class _ModulesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _ModulesGrid({required this.items});

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
            onTap: it["onTap"] as VoidCallback,
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
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String right;

  const _SectionTitle({
    required this.title,
    required this.right,
  });

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