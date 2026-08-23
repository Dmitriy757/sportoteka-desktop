// lib/presentation/player_team/player_team_dashboard_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/routes/app_routes.dart';

import 'package:sportoteka/presentation/team_roster_screen/team_roster_screen.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_screen.dart';
import 'package:sportoteka/presentation/team_attendance_screen/team_attendance_journal_screen.dart';

class PlayerTeamDashboardScreen extends StatefulWidget {
  const PlayerTeamDashboardScreen({super.key});

  @override
  State<PlayerTeamDashboardScreen> createState() => _PlayerTeamDashboardScreenState();
}

class _PlayerTeamDashboardScreenState extends State<PlayerTeamDashboardScreen> {
  // =============================
  // API
  // =============================
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getMyTeamUrl = "$apiBase/get_my_team.php"; // <-- твой PHP

  bool loading = true;
  String? error;

  int userId = 0;

  // Ответ API
  int playerId = 0;
  int teamId = 0;

  String teamName = "";
  String teamCategory = "";
  String teamLogo = "";

  int clubId = 0;
  String clubName = "";
  String clubLogo = "";

  // =============================
  // lifecycle
  // =============================
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    userId = await PrefUtils.getUserId() ?? 0;
    if (userId <= 0) {
      setState(() {
        loading = false;
        error = "Не найден userId. Выполните вход заново.";
      });
      return;
    }
    await _load();
  }

  // =============================
  // helpers
  // =============================
  Map<String, dynamic> _decode(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) return j;
      return {"success": false, "message": "Некорректный ответ сервера"};
    } catch (_) {
      return {"success": false, "message": "Ошибка JSON"};
    }
  }

  Widget _netImage(String url, {double? w, double? h, BoxFit fit = BoxFit.cover}) {
    if (url.trim().isEmpty) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.sports_soccer, color: AppColors.primaryGreen, size: (w ?? 48) * 0.5),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        width: w,
        height: h,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.sports_soccer, color: AppColors.primaryGreen, size: (w ?? 48) * 0.5),
        ),
      ),
    );
  }

  // =============================
  // API load
  // =============================
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final uri = Uri.parse(getMyTeamUrl).replace(queryParameters: {
        "user_id": userId.toString(),
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      final data = _decode(res.body);

      final ok = data["success"] == true;
      if (!ok) {
        setState(() {
          loading = false;
          error = (data["message"] ?? "Игрок не привязан к команде").toString();
        });
        return;
      }

      final team = (data["team"] is Map) ? Map<String, dynamic>.from(data["team"]) : <String, dynamic>{};

      setState(() {
        playerId = int.tryParse((team["player_id"] ?? "0").toString()) ?? 0;
        teamId = int.tryParse((team["team_id"] ?? "0").toString()) ?? 0;

        teamName = (team["team_name"] ?? "").toString();
        teamCategory = (team["team_category"] ?? "").toString();
        teamLogo = (team["team_logo"] ?? "").toString();

        clubId = int.tryParse((team["club_id"] ?? "0").toString()) ?? 0;
        clubName = (team["club_name"] ?? "").toString();
        clubLogo = (team["club_logo"] ?? "").toString();

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = "Сетевая ошибка. Проверь интернет.";
      });
    }
  }

  // =============================
  // UI
  // =============================
  Widget _headerCard() {
    final title = teamName.isNotEmpty ? teamName : "Команда";
    final subtitle = [
      if (clubName.trim().isNotEmpty) clubName.trim(),
      if (teamCategory.trim().isNotEmpty) teamCategory.trim(),
    ].join(" • ");

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [AppColors.cardShadow],
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _netImage(teamLogo.isNotEmpty ? teamLogo : clubLogo, w: 72, h: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle.isNotEmpty ? subtitle : "Информация о команде",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _pill("player_id: $playerId"),
                    const SizedBox(width: 8),
                    _pill("team_id: $teamId"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _grid() {
    final items = <_DashItem>[
      _DashItem(
        title: "Состав команды",
        subtitle: "Игроки и профили",
        icon: Icons.groups_2_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamRosterScreen(teamId: teamId, teamName: teamName.isEmpty ? "Команда" : teamName),
          ),
        ),
      ),
      _DashItem(
        title: "Календарь",
        subtitle: "Тренировки и матчи",
        icon: Icons.calendar_month_outlined,
        onTap: () => Get.to(() => TeamCalendarScreen(teamId: teamId, teamName: teamName.isEmpty ? "Команда" : teamName)),
      ),
      _DashItem(
        title: "Посещаемость",
        subtitle: "Журнал команды",
        icon: Icons.fact_check_outlined,
        onTap: () => Get.to(() => TeamAttendanceJournalScreen(teamId: teamId, teamName: teamName.isEmpty ? "Команда" : teamName)),
      ),
      _DashItem(
        title: "Матчи",
        subtitle: "Список и результаты",
        icon: Icons.sports_soccer_outlined,
        onTap: () => Get.toNamed(AppRoutes.teamMatchesScreen, arguments: teamId),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        itemBuilder: (_, i) => _DashCard(item: items[i]),
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 70, color: AppColors.textTertiary.withOpacity(0.6)),
            const SizedBox(height: 14),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 220,
              child: ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Обновить"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================
  // build
  // =============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Моя команда",
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            tooltip: "Обновить",
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
              ? _emptyState(error!)
              : (teamId <= 0)
                  ? _emptyState("Команда не найдена. Проверь привязку игрока к команде.")
                  : ListView(
                      children: [
                        _headerCard(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Row(
                            children: const [
                              Expanded(
                                child: Text(
                                  "Разделы команды",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _grid(),
                      ],
                    ),
    );
  }
}

// =============================
// UI atoms
// =============================
class _DashItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  _DashItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _DashCard extends StatelessWidget {
  final _DashItem item;

  const _DashCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [AppColors.cardShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: AppColors.primaryGreen),
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
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
                  item.subtitle,
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
  }
}
