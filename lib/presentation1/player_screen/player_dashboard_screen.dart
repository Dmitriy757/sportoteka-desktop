// lib/presentation/player_screen/player_dashboard_screen.dart
import 'dart:convert';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/routes/app_routes.dart';
import 'package:sportoteka/presentation/team_roster_screen/team_roster_screen.dart';
import 'package:sportoteka/presentation/team_calendar_screen/player_team_calendar_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/team_rating_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_challenges_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_battles_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_quizzes_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_match_games_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_highlights_screen.dart';

class PlayerDashboardScreen extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int userId;
  final String? teamLogo;

  const PlayerDashboardScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.userId,
    this.teamLogo,
  });

  @override
  State<PlayerDashboardScreen> createState() => _PlayerDashboardScreenState();
}

class _PlayerDashboardScreenState extends State<PlayerDashboardScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getTeamProfileUrl = "$apiBase/get_team_profile.php";
  static const String getGameZoneSummaryUrl =
      "$apiBase/get_game_zone_summary.php";

  late String teamName;
  String teamCategory = "";
  String? teamLogoUrl;

  bool profileLoading = false;
  String? profileError;

  bool summaryLoading = true;
  Map<String, dynamic>? summary;
  String? summaryError;

  late final List<Map<String, dynamic>> _teamItems = [
    {
      "t": "Состав команды",
      "s": "Игроки, роли и профили команды",
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
      "s": "Тренировки, игры и мероприятия",
      "i": Icons.calendar_month_outlined,
      "theme": ModuleThemes.calendar,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => PlayerTeamCalendarScreen(
              teamId: teamId,
              teamName: teamName,
            ),
          ),
    },
   {
  "t": "Матчи",
  "s": "Матчи команды и личный анализ",
  "i": Icons.sports_soccer_outlined,
  "theme": ModuleThemes.basic,
  "onTap": (BuildContext context, int teamId, String teamName) async {

    final userId = await PrefUtils.getUserId();

    if (userId == null) {
      Get.snackbar("Ошибка", "Пользователь не найден");
      return;
    }

    try {
      final res = await http.get(
        Uri.parse("https://sportotekaapp.ru/api/get_user.php?user_id=$userId"),
      );

      final data = jsonDecode(res.body);

      final role = (data["user"]?["role"] ?? "").toString().toLowerCase();

      if (role == "player") {
        /// 👉 Игрок — новый экран
        Get.toNamed(
          AppRoutes.playerMatchesScreen,
          arguments: {
            "teamId": teamId,
            "teamName": teamName,
          },
        );
      } else {
        /// 👉 Тренер / федерация — старый экран
        Get.toNamed(
          AppRoutes.teamMatchesScreen,
          arguments: {
            "teamId": teamId,
            "teamName": teamName,
          },
        );
      }
    } catch (e) {
      Get.snackbar("Ошибка", "Не удалось определить роль");
    }
  },
},
    {
      "t": "Командный чат",
      "s": "Общий чат внутри команды",
      "i": Icons.forum_outlined,
      "theme": ModuleThemes.chat,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Get.snackbar("Модуль", "Чат подключим следующим этапом"),
    },
  ];

  late final List<Map<String, dynamic>> _gameZoneItems = [
    {
      "t": "Рейтинг команды",
      "s": "Очки, активность и соревнование между игроками",
      "i": Icons.emoji_events_outlined,
      "theme": ModuleThemes.rating,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => const TeamRatingScreen(),
            arguments: {
              "team_id": teamId,
              "user_id": widget.userId,
              "team_name": teamName,
            },
          ),
    },
    {
      "t": "Челленджи",
      "s": "Ежедневные и недельные задания",
      "i": Icons.flag_outlined,
      "theme": ModuleThemes.challenge,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => const PlayerChallengesScreen(),
            arguments: {
              "team_id": teamId,
              "user_id": widget.userId,
              "team_name": teamName,
            },
          ),
    },
    {
      "t": "Битва игроков",
      "s": "Соревнования 1 на 1 внутри команды",
      "i": Icons.local_fire_department_outlined,
      "theme": ModuleThemes.battle,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => const PlayerBattlesScreen(),
            arguments: {
              "team_id": teamId,
              "user_id": widget.userId,
              "team_name": teamName,
            },
          ),
    },
    {
      "t": "Футбольные квизы",
      "s": "Викторины и быстрые очки",
      "i": Icons.quiz_outlined,
      "theme": ModuleThemes.quiz,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => const PlayerQuizzesScreen(),
            arguments: {
              "team_id": teamId,
              "user_id": widget.userId,
              "team_name": teamName,
            },
          ),
    },
    {
      "t": "Мини-игры к матчам",
      "s": "Прогнозы по ближайшим играм",
      "i": Icons.sports_score_outlined,
      "theme": ModuleThemes.matchGames,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => const PlayerMatchGamesScreen(),
            arguments: {
              "team_id": teamId,
              "user_id": widget.userId,
              "team_name": teamName,
            },
          ),
    },
    {
      "t": "Мои лучшие моменты",
      "s": "Голы, передачи, финты и видео",
      "i": Icons.ondemand_video_outlined,
      "theme": ModuleThemes.highlights,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => const PlayerHighlightsScreen(),
            arguments: {
              "team_id": teamId,
              "user_id": widget.userId,
              "team_name": teamName,
            },
          ),
    },
  ];

  late final List<Map<String, dynamic>> _personalItems = [
    {
      "t": "Мои тренировки",
      "s": "Личные тренировки и прогресс",
      "i": Icons.fitness_center_outlined,
      "theme": ModuleThemes.analytics,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Get.snackbar("Модуль", "Мои тренировки подключим следующим этапом"),
    },
    {
      "t": "Самооценка",
      "s": "Оцени тренировку и напиши заметку",
      "i": Icons.rate_review_outlined,
      "theme": ModuleThemes.analytics,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Get.toNamed(
            AppRoutes.playerSelfAssessmentScreen,
            arguments: {
              "team_id": teamId,
              "user_id": widget.userId,
              "team_name": teamName,
            },
          ),
    },
  ];

  @override
  void initState() {
    super.initState();
    teamName = widget.teamName.trim().isNotEmpty
        ? widget.teamName.trim()
        : "Команда #${widget.teamId}";
    teamLogoUrl = _bust(_normalizePhoto(widget.teamLogo));
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await Future.wait([
      _loadTeamProfileSilent(),
      _loadGameZoneSummary(),
    ]);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final body = resp.body.trim();
      if (body.isEmpty) return {"success": false, "message": "EMPTY_BODY"};

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
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    if (s.startsWith("uploads/")) return "https://sportotekaapp.ru/$s";
    if (!s.startsWith("/")) s = "/$s";
    return "https://sportotekaapp.ru$s";
  }

  String? _bust(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final sep = url.contains("?") ? "&" : "?";
    return "$url${sep}v=${DateTime.now().millisecondsSinceEpoch}";
  }

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

      debugPrint("PLAYER DASHBOARD TEAM PROFILE RESPONSE: ${resp.body}");

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
          team["team_name"] ?? team["name"] ?? team["title"],
        ).trim();

        final serverCategory = _asStr(
          team["category"] ??
              team["sport_type"] ??
              team["sport"] ??
              team["type"],
        ).trim();

        final serverLogo = _bust(
          _normalizePhoto(
            _asStr(
              team["team_logo"] ??
                  team["logo"] ??
                  team["logo_url"] ??
                  team["image"] ??
                  team["photo"],
            ),
          ),
        );

        debugPrint("PLAYER DASHBOARD PARSED NAME: $serverName");
        debugPrint("PLAYER DASHBOARD PARSED CATEGORY: $serverCategory");
        debugPrint("PLAYER DASHBOARD PARSED LOGO: $serverLogo");

        setState(() {
          if (serverName.isNotEmpty) {
            teamName = serverName;
          }

          if (serverCategory.isNotEmpty) {
            teamCategory = serverCategory;
          }

          if (serverLogo != null && serverLogo.isNotEmpty) {
            teamLogoUrl = serverLogo;
          }

          profileLoading = false;
        });
      } else {
        setState(() {
          profileLoading = false;
          profileError = _asStr(data["message"]).trim().isEmpty
              ? "Не удалось загрузить профиль"
              : _asStr(data["message"]).trim();
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

  Future<void> _loadGameZoneSummary() async {
    if (!mounted) return;
    setState(() {
      summaryLoading = true;
      summaryError = null;
    });

    try {
      final resp = await http
          .post(
            Uri.parse(getGameZoneSummaryUrl),
            body: {
              "team_id": widget.teamId.toString(),
              "user_id": widget.userId.toString(),
            },
          )
          .timeout(const Duration(seconds: 12));

      final data = _decode(resp);
      if (!mounted) return;

      if (data["success"] == true) {
        setState(() {
          summary = data;
          summaryLoading = false;
        });
      } else {
        setState(() {
          summaryLoading = false;
          summaryError = _asStr(data["message"]).trim().isEmpty
              ? "Не удалось загрузить игровую зону"
              : _asStr(data["message"]).trim();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        summaryLoading = false;
        summaryError = "Сетевая ошибка";
      });
    }
  }

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
                key: ValueKey(teamLogoUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultLogo(),
              )
            : _buildDefaultLogo(),
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
      child: Row(
        children: [
          _teamAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.primaryGreen.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        "Режим игрока • VIEW",
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
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
    );
  }

  Widget _miniStat(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameZoneSummaryCard() {
    if (summaryLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF00A750), Color(0xFF31C96C)],
          ),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    if (summaryError != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                summaryError!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: _loadGameZoneSummary,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
    }

    final myRank = summary?["my_rank"]?.toString() ?? "0";
    final myPoints = summary?["my_points"]?.toString() ?? "0";
    final streak = summary?["streak_days"]?.toString() ?? "0";
    final challenge = summary?["challenge_of_day"] as Map<String, dynamic>?;
    final quiz = summary?["quiz_of_day"] as Map<String, dynamic>?;
    final battle = summary?["battle_preview"] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF00A750), Color(0xFF31C96C)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Твоя игровая зона',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniStat('Место', '#$myRank')),
              const SizedBox(width: 10),
              Expanded(child: _miniStat('Очки', myPoints)),
              const SizedBox(width: 10),
              Expanded(child: _miniStat('Серия', '$streak дн.')),
            ],
          ),
          if (challenge != null) ...[
            const SizedBox(height: 14),
            _summaryTile(
              icon: Icons.flag_outlined,
              title: 'Челлендж дня',
              subtitle: challenge["title"]?.toString() ?? '',
              buttonText: 'Открыть',
              onTap: () => Get.to(
                () => const PlayerChallengesScreen(),
                arguments: {
                  "team_id": widget.teamId,
                  "user_id": widget.userId,
                  "team_name": teamName,
                },
              ),
            ),
          ],
          if (quiz != null) ...[
            const SizedBox(height: 10),
            _summaryTile(
              icon: Icons.quiz_outlined,
              title: 'Квиз дня',
              subtitle: quiz["title"]?.toString() ?? '',
              buttonText: 'Пройти',
              onTap: () => Get.to(
                () => const PlayerQuizzesScreen(),
                arguments: {
                  "team_id": widget.teamId,
                  "user_id": widget.userId,
                  "team_name": teamName,
                },
              ),
            ),
          ],
          if (battle != null) ...[
            const SizedBox(height: 10),
            _summaryTile(
              icon: Icons.local_fire_department_outlined,
              title: 'Ближайшая битва',
              subtitle: battle["title"]?.toString() ?? '',
              buttonText: 'Смотреть',
              onTap: () => Get.to(
                () => const PlayerBattlesScreen(),
                arguments: {
                  "team_id": widget.teamId,
                  "user_id": widget.userId,
                  "team_name": teamName,
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(
              buttonText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadTeamProfileSilent(),
      _loadGameZoneSummary(),
    ]);
  }

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
            tooltip: "Обновить",
            onPressed: _refreshAll,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
          children: [
            _buildTeamHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    title: "Модули команды",
                    right: "всего: ${_teamItems.length}",
                  ),
                  const SizedBox(height: 8),
                  _ModulesGrid(
                    items: _teamItems,
                    teamId: widget.teamId,
                    teamName: teamName,
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    title: "Игровая зона команды",
                    right: "всего: ${_gameZoneItems.length}",
                  ),
                  const SizedBox(height: 8),
                  _buildGameZoneSummaryCard(),
                  _ModulesGrid(
                    items: _gameZoneItems,
                    teamId: widget.teamId,
                    teamName: teamName,
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    title: "Личное развитие",
                    right: "всего: ${_personalItems.length}",
                  ),
                  const SizedBox(height: 8),
                  _ModulesGrid(
                    items: _personalItems,
                    teamId: widget.teamId,
                    teamName: teamName,
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

class ModuleTheme {
  final Color color;
  final Color iconColor;

  const ModuleTheme({
    required this.color,
    required this.iconColor,
  });
}

class ModuleThemes {
  static const basic = ModuleTheme(
    color: Color(0xFFF3F4F6),
    iconColor: AppColors.textPrimary,
  );

  static const calendar = ModuleTheme(
    color: Color(0xFFEFF6FF),
    iconColor: Color(0xFF2563EB),
  );

  static const chat = ModuleTheme(
    color: Color(0xFFFFF7ED),
    iconColor: Color(0xFFEA580C),
  );

  static const analytics = ModuleTheme(
    color: Color(0xFFECFEFF),
    iconColor: Color(0xFF0891B2),
  );

  static const rating = ModuleTheme(
    color: Color(0xFFFFF7D6),
    iconColor: Color(0xFFEAB308),
  );

  static const challenge = ModuleTheme(
    color: Color(0xFFEAFBF1),
    iconColor: Color(0xFF16A34A),
  );

  static const battle = ModuleTheme(
    color: Color(0xFFFFEAEA),
    iconColor: Color(0xFFDC2626),
  );

  static const quiz = ModuleTheme(
    color: Color(0xFFF6EEFF),
    iconColor: Color(0xFF7C3AED),
  );

  static const matchGames = ModuleTheme(
    color: Color(0xFFEAF2FF),
    iconColor: Color(0xFF2563EB),
  );

  static const highlights = ModuleTheme(
    color: Color(0xFFFFF1E8),
    iconColor: Color(0xFFEA580C),
  );
}