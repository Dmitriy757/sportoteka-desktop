// lib/presentation/my_team_screen/my_team_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/routes/app_routes.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_screen.dart';

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

  static const String getTeamsByCoachUrl = "$apiBase/get_team_by_coach.php";
  static const String getPlayersUrl = "$apiBase/get_players.php";

  /// ✅ multipart: team_id + logo(file)
  static const String updateTeamPhotoUrl = "$apiBase/update_team_photo.php";

  // =============================
  // STATE
  // =============================
  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> players = [];

  bool isLoading = true;
  bool isPlayersLoading = false;

  int selectedTeamId = 0;
  String selectedTeamName = "";
  String selectedTeamLogo = ""; // url or ""

  final bg = const Color(0xFFF3F5F8);

  @override
  void initState() {
    super.initState();

    final passedTeamId = widget.teamId;
    final passedTeamName = (widget.teamName ?? "").trim();

    if (passedTeamId != null && passedTeamId > 0) {
      selectedTeamId = passedTeamId;
      selectedTeamName = passedTeamName.isEmpty ? "Команда" : passedTeamName;

      isLoading = false;
      fetchPlayers(selectedTeamId);
    } else {
      fetchTeams();
    }
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

  void _snackErr(String message) {
    Get.snackbar(
      "Ошибка",
      message,
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      colorText: Theme.of(context).colorScheme.onErrorContainer,
      margin: const EdgeInsets.all(12),
    );
  }

  void _snackOk(String message) {
    Get.snackbar(
      "Готово",
      message,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      colorText: Theme.of(context).colorScheme.onPrimaryContainer,
      margin: const EdgeInsets.all(12),
    );
  }

  // =============================
  // LOAD TEAMS (coach)
  // =============================
  Future<void> fetchTeams() async {
    setState(() => isLoading = true);

    final coachId = await PrefUtils.getUserId();
    if (coachId == null) {
      _snackErr("Пользователь не найден");
      setState(() => isLoading = false);
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
        _snackErr("Команды не найдены");
      }

      setState(() => isLoading = false);
    } catch (e) {
      _snackErr("Ошибка подключения: $e");
      setState(() => isLoading = false);
    }
  }

  // =============================
  // LOAD PLAYERS
  // =============================
  Future<void> fetchPlayers(int teamId) async {
    setState(() {
      isPlayersLoading = true;
      players.clear();
    });

    try {
      final resp = await http.post(
        Uri.parse(getPlayersUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"team_id": teamId}),
      );

      final data = _decode(resp);

      if (data["status"] == "success") {
        await Future.delayed(const Duration(milliseconds: 200));
        players = List<Map<String, dynamic>>.from(data["players"] ?? []);
        setState(() => isPlayersLoading = false);
      } else {
        _snackErr(_asStr(data["message"]).isEmpty
            ? "Не удалось загрузить игроков"
            : _asStr(data["message"]));
        setState(() => isPlayersLoading = false);
      }
    } catch (e) {
      _snackErr("Ошибка подключения: $e");
      setState(() => isPlayersLoading = false);
    }
  }

  // =============================
  // TEAM PICK
  // =============================
  void _selectTeam(Map<String, dynamic> team) {
    final id = _asInt(team["id"]);
    final name = _asStr(team["name"]).trim();
    final logo = _asStr(team["logo"]).trim();

    setState(() {
      selectedTeamId = id;
      selectedTeamName = name.isEmpty ? "Команда #$id" : name;
      selectedTeamLogo = logo;
    });

    fetchPlayers(id);
  }

  void _backLogic() {
    final isClubMode = (widget.teamId != null && widget.teamId! > 0);

    if (isClubMode) {
      Navigator.pop(context);
      return;
    }

    // тренерский режим
    if (selectedTeamId != 0) {
      setState(() {
        selectedTeamId = 0;
        selectedTeamName = "";
        selectedTeamLogo = "";
        players.clear();
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

        // обновим и в списке teams
        for (final t in teams) {
          if (_asInt(t["id"]) == selectedTeamId) {
            t["logo"] = selectedTeamLogo;
            break;
          }
        }
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
  // UI
  // =============================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: _backLogic,
      ),
      title: Text(
        selectedTeamId == 0 ? "Мои команды" : selectedTeamName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
      ),
      actions: [
        IconButton(
          tooltip: "Обновить",
          onPressed: () async {
            if (selectedTeamId == 0) {
              await fetchTeams();
            } else {
              await fetchPlayers(selectedTeamId);
            }
          },
          icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _teamHeaderCard() {
    final primary = Theme.of(context).colorScheme.primary;
    final logo = selectedTeamLogo.trim();

    ImageProvider? logoProvider;
    if (logo.isNotEmpty) logoProvider = NetworkImage(logo);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.95), primary.withOpacity(0.55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.18),
                backgroundImage: logoProvider,
                child: logoProvider == null
                    ? const Icon(Icons.shield_outlined,
                        color: Colors.white, size: 28)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  onTap: _pickAndUploadTeamLogo,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: const Icon(Icons.photo_camera_outlined, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedTeamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Team ID: $selectedTeamId • Игроков: ${players.length}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
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

  Widget _sectionTitle(String title, String right) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Text(
            right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Сетка модулей в стиле TeamDashboardScreen
  Widget _modulesGridSliver() {
    final primary = Theme.of(context).colorScheme.primary;

    final items = <Map<String, dynamic>>[
      {
        "t": "Состав",
        "s": "Игроки, профили",
        "i": Icons.groups_2_outlined,
        "onTap": () {},
      },
      {
        "t": "Описание",
        "s": "Информация о команде",
        "i": Icons.info_outline,
        "onTap": () => Get.toNamed(
          AppRoutes.teamDescriptionScreen,
          arguments: selectedTeamId,
        ),
      },
      {
        "t": "Матчи",
        "s": "Список матчей",
        "i": Icons.sports_soccer_outlined,
        "onTap": () => Get.toNamed(
          AppRoutes.teamMatchesScreen,
          arguments: selectedTeamId,
        ),
      },
      {
        "t": "Календарь",
        "s": "Тренировки и игры",
        "i": Icons.calendar_month_outlined,
        "onTap": () => Get.to(
          () => TeamCalendarScreen(
            teamId: selectedTeamId,
            teamName: selectedTeamName,
          ),
        ),
      },
      {
        "t": "Руководство",
        "s": "Персонал команды",
        "i": Icons.groups_outlined,
        "onTap": () => Get.toNamed(
          AppRoutes.teamManagementScreen,
          arguments: selectedTeamId,
        ),
      },
      {
        "t": "Билеты",
        "s": "Ссылка/продажи",
        "i": Icons.confirmation_num_outlined,
        "onTap": () => Get.toNamed(
          AppRoutes.teamTicketsScreen,
          arguments: selectedTeamId,
        ),
      },
    ];

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final it = items[i];
            return Material(
              color: Colors.white,
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
                          color: primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(it["i"] as IconData, color: primary),
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
                            color: Color(0xFF6B7280),
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
          childCount: items.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
      ),
    );
  }

  Widget _addPlayerButtonBox() {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            if (selectedTeamId == 0) {
              _snackErr("Сначала выберите команду");
              return;
            }
            Get.toNamed(
              AppRoutes.addPlayerScreen,
              arguments: {"teamId": selectedTeamId},
            );
          },
          icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
          label: const Text(
            "Добавить игрока",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _playerTile(Map<String, dynamic> p) {
    final firstName = _asStr(p["first_name"]).trim();
    final lastName = _asStr(p["last_name"]).trim();
    final position = _asStr(p["position"]).trim();

    final name = ("$firstName $lastName").trim();
    final letter = firstName.isNotEmpty
        ? firstName[0].toUpperCase()
        : (lastName.isNotEmpty ? lastName[0].toUpperCase() : "И");

    return InkWell(
      onTap: () => Get.toNamed(
        AppRoutes.playerProfileScreen,
        arguments: p,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? "Игрок" : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    position.isEmpty ? "Без позиции" : position,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _shimmerPlayersSliver() {
    return SliverToBoxAdapter(
      child: Padding(
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamsList() {
    if (teams.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_off, size: 44, color: Color(0xFF9CA3AF)),
              SizedBox(height: 12),
              Text(
                "Команд пока нет",
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: teams.length,
      itemBuilder: (_, i) {
        final t = teams[i];
        final id = _asInt(t["id"]);
        final name = _asStr(t["name"]).trim();
        final cat = _asStr(t["category"]).trim();
        final logo = _asStr(t["logo"]).trim();

        ImageProvider? logoProvider;
        if (logo.isNotEmpty) logoProvider = NetworkImage(logo);

        return InkWell(
          onTap: () => _selectTeam(t),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.10),
                  backgroundImage: logoProvider,
                  child: logoProvider == null
                      ? Icon(Icons.shield_outlined,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? "Команда #$id" : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cat.isEmpty ? "Team ID: $id" : "$cat • Team ID: $id",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ Главное: единый скролл экрана команды (модули + кнопка + игроки)
  Widget _teamScrollableBody() {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(child: _teamHeaderCard()),
        SliverToBoxAdapter(child: _sectionTitle("Основные модули", "6")),
        _modulesGridSliver(),
        SliverToBoxAdapter(child: _addPlayerButtonBox()),
        SliverToBoxAdapter(child: _sectionTitle("Игроки", "${players.length}")),

        if (isPlayersLoading)
          _shimmerPlayersSliver()
        else if (players.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                children: [
                  Icon(Icons.group_off, size: 44, color: Color(0xFF9CA3AF)),
                  SizedBox(height: 12),
                  Text(
                    "Игроков пока нет",
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 16 + bottomSafe),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _playerTile(players[i]),
                childCount: players.length,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTeam = selectedTeamId != 0;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (!showTeam)
              ? _teamsList()
              : _teamScrollableBody(),
    );
  }
}
