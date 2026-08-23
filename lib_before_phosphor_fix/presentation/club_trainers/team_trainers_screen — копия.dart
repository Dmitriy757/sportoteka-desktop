// lib/presentation/club_trainers/team_trainers_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/club_trainers/edit_trainer_profile_screen.dart';

/// TeamTrainersScreen
/// ✅ Показывает тренеров (привязанных пользователей) выбранной команды
/// ✅ Привязка по email + выбор роли (main/doctor/admin/extra)
/// ✅ Поиск по ФИО/email/роли/визитке (если поля есть в API)
/// ✅ Визитка тренера (информационный экран) + кнопка "Редактировать"
class TeamTrainersScreen extends StatefulWidget {
  final int clubId;
  final String clubName;

  /// из get_club_teams.php
  /// ⚠️ формат может быть {id,name} или {team_id,team_name} и т.п.
  final List<dynamic> teams;

  const TeamTrainersScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teams,
  });

  @override
  State<TeamTrainersScreen> createState() => _TeamTrainersScreenState();
}

class _TeamTrainersScreenState extends State<TeamTrainersScreen> {
  // ✅ API
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getTeamTrainersUrl = "$apiBase/get_team_trainers.php";
  static const String linkTrainerToTeamUrl = "$apiBase/link_trainer_to_team.php";
  static const String unlinkTrainerFromTeamUrl = "$apiBase/unlink_trainer_from_team.php";
  static const String searchTrainerByEmailUrl = "$apiBase/search_trainer_by_email.php";

  bool loading = true;
  String? error;

  int? selectedTeamId;
  String selectedTeamName = "Выберите команду";
  String? selectedTeamLogoUrl; // ✅ для красивого выбора

  List<Map<String, dynamic>> trainers = [];
  List<Map<String, dynamic>> filtered = [];

  final TextEditingController _searchCtrl = TextEditingController();

  // ---------------------------
  // Helpers
  // ---------------------------
  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _asStr(dynamic v) => (v ?? "").toString();

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final j = json.decode(resp.body);
      if (j is Map<String, dynamic>) return j;
      return {"status": "error", "message": "bad json"};
    } catch (_) {
      return {"status": "error", "message": "bad json"};
    }
  }

  String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    if (!s.startsWith("/")) s = "/$s";
    return "https://sportotekaapp.ru$s";
  }

  /// ✅ photo в users часто хранится как: user_7_xxx.jpg (без uploads)
  /// поэтому делаем более умный нормализатор
  String? _normalizeUserPhoto(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;

    // если в БД уже лежит "uploads/...." — просто приклеим домен
    if (s.startsWith("uploads/") || s.startsWith("/uploads/")) {
      if (!s.startsWith("/")) s = "/$s";
      return "https://sportotekaapp.ru$s";
    }

    // если это просто "user_7_....jpg" — считаем, что лежит в /uploads/
    // (если у тебя другой путь — скажи, поменяем)
    if (!s.startsWith("/")) s = "/uploads/$s";
    return "https://sportotekaapp.ru$s";
  }

  Future<Map<String, dynamic>> _postJson(String url, Map<String, dynamic> body) async {
    final resp = await http.post(
      Uri.parse(url),
      headers: const {"Content-Type": "application/json; charset=utf-8"},
      body: jsonEncode(body),
    );

    // ignore: avoid_print
    print("API POST $url -> ${resp.statusCode}");
    // ignore: avoid_print
    print("API BODY: ${resp.body}");

    return _decode(resp);
  }

  String _pickAnyStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = (m[k] ?? "").toString().trim();
      if (v.isNotEmpty) return v;
    }
    return "";
  }

  /// ✅ ВАЖНО: teams могут приходить с разными ключами: id/name или team_id/team_name
  int _teamIdFrom(dynamic t) {
    if (t is Map) {
      final m = Map<String, dynamic>.from(t as Map);
      final id = _asInt(m["id"]);
      if (id > 0) return id;
      return _asInt(m["team_id"]);
    }
    return 0;
  }

  String _teamNameFrom(dynamic t) {
    if (t is Map) {
      final m = Map<String, dynamic>.from(t as Map);
      final n1 = _asStr(m["name"]).trim();
      if (n1.isNotEmpty) return n1;
      final n2 = _asStr(m["team_name"]).trim();
      if (n2.isNotEmpty) return n2;
    }
    return "Команда";
  }

  String? _teamLogoFrom(dynamic t) {
    if (t is Map) {
      final m = Map<String, dynamic>.from(t as Map);

      // ✅ приоритет: logo_url (если PHP его формирует)
      final lu = _asStr(m["logo_url"]).trim();
      if (lu.isNotEmpty) return _normalizeUrl(lu);

      final logo = _asStr(m["logo"]).trim();
      if (logo.isNotEmpty) return _normalizeUrl(logo);
    }
    return null;
  }

  String _teamCategoryFrom(dynamic t) {
    if (t is Map) {
      final m = Map<String, dynamic>.from(t as Map);
      final c = _asStr(m["category"]).trim();
      if (c.isNotEmpty) return c;
    }
    return "";
  }

  // ---------------------------
  // Init
  // ---------------------------
  @override
  void initState() {
    super.initState();

    _searchCtrl.addListener(_applyFilter);

    if (widget.teams.isNotEmpty) {
      final t0 = widget.teams.first;
      selectedTeamId = _teamIdFrom(t0);
      selectedTeamName = _teamNameFrom(t0);
      selectedTeamLogoUrl = _teamLogoFrom(t0);

      if ((selectedTeamId ?? 0) > 0) {
        _loadTeamTrainers();
      } else {
        setState(() {
          loading = false;
          error =
              "Не найден team_id/id в списке команд.\nПроверь формат get_club_teams.php (нужен id или team_id).";
        });
      }
    } else {
      loading = false;
    }
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => filtered = List.of(trainers));
      return;
    }

    setState(() {
      filtered = trainers.where((t) {
        final fn = _asStr(t["first_name"]).toLowerCase();
        final ln = _asStr(t["last_name"]).toLowerCase();
        final email = _asStr(t["email"]).toLowerCase();

        final profile = (_asStr(t["profile"]).trim().isEmpty
                ? _asStr(t["link_type"]).trim()
                : _asStr(t["profile"]).trim())
            .toLowerCase();

        final pos = _pickAnyStr(t, ["position", "role_title", "title"]).toLowerCase();
        final bio = _pickAnyStr(t, ["bio", "about", "description"]).toLowerCase();

        return fn.contains(q) ||
            ln.contains(q) ||
            email.contains(q) ||
            profile.contains(q) ||
            pos.contains(q) ||
            bio.contains(q);
      }).toList();
    });
  }

  // ---------------------------
  // Data
  // ---------------------------
  Future<void> _loadTeamTrainers() async {
    final teamId = selectedTeamId ?? 0;
    if (teamId <= 0) {
      setState(() {
        loading = false;
        error = "team_id = 0 (не выбрана команда или неверный формат teams)";
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
      trainers = [];
      filtered = [];
    });

    try {
      // ignore: avoid_print
      print("TeamTrainersScreen load team_id=$teamId team_name=$selectedTeamName");

      final data = await _postJson(getTeamTrainersUrl, {"team_id": teamId});

      if ((data["status"] == "success" || data["success"] == true) && data["trainers"] is List) {
        trainers = (data["trainers"] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        trainers = [];
        final msg = _asStr(data["message"]).trim();
        error = msg.isEmpty ? "API вернул пусто/ошибку: ${_asStr(data["status"])}" : msg;
      }

      filtered = List.of(trainers);

      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = "Ошибка загрузки: $e";
      });
    }
  }

  Future<List<Map<String, dynamic>>> _searchTrainerByEmail(String email) async {
    try {
      final clean = email.trim();
      if (clean.isEmpty) return [];

      // ⚠️ search_trainer_by_email.php принимает form-data
      final resp = await http.post(
        Uri.parse(searchTrainerByEmailUrl),
        body: {"email": clean},
      );
      final data = _decode(resp);

      if ((data["success"] == true || data["status"] == "success") && data["trainers"] is List) {
        return (data["trainers"] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// ✅ Шаг 1: ищем тренера по email и выбираем его
  Future<Map<String, dynamic>?> _pickTrainerByEmailSheet() async {
    final emailCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    return await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSB) {
            Future<void> doSearch() async {
              final q = emailCtrl.text.trim();
              if (q.isEmpty) {
                setSB(() => results = []);
                return;
              }
              setSB(() => searching = true);
              final r = await _searchTrainerByEmail(q);
              setSB(() {
                searching = false;
                results = r;
              });

              if (r.isEmpty) {
                Get.snackbar(
                  "Не найдено",
                  "Профиль с таким email не найден.",
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
                        "Добавить тренера по email",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Введите точный email тренера (роль coach).\nДалее выберите тип доступа в команде.",
                        style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => doSearch(),
                      decoration: InputDecoration(
                        labelText: "Точный email",
                        hintText: "coach@mail.com",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: doSearch,
                        ),
                      ),
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
                          "Введите email и нажмите поиск.",
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
                            final fn = _asStr(t["first_name"]);
                            final ln = _asStr(t["last_name"]);
                            final email = _asStr(t["email"]);
                            final role = _asStr(t["role"]).trim();
                            final name = ("$fn $ln").trim();

                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                              title: Text(name.isEmpty ? "Профиль #$id" : name),
                              subtitle: Text(role.isEmpty ? email : "$email • роль: $role"),
                              onTap: () => Navigator.pop(context, {
                                "id": id,
                                "name": name,
                                "email": email,
                                "role": role,
                              }),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// ✅ Шаг 2: выбрать тип профиля в команде
  Future<String?> _pickTeamProfileTypeSheet() async {
    const items = [
      {"k": "main", "t": "Главный тренер", "s": "Полный доступ"},
      {"k": "doctor", "t": "Врач", "s": "Доступ к медкарте"},
      {"k": "admin", "t": "Пользователь клуба", "s": "Управление составом и модулями"},
      {"k": "extra", "t": "Тренер / ассистент", "s": "Доп. тренер/ассистент"},
    ];

    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = items[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  child: Icon(Icons.badge_outlined, color: Theme.of(context).colorScheme.primary),
                ),
                title: Text(it["t"]!, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(it["s"]!, style: const TextStyle(color: Color(0xFF6B7280))),
                onTap: () => Navigator.pop(context, it["k"]),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _linkTrainer(int trainerId, {required String profile}) async {
    final teamId = selectedTeamId ?? 0;
    if (teamId <= 0) {
      Get.snackbar("Команда", "Сначала выберите команду");
      return;
    }

    try {
      final data = await _postJson(linkTrainerToTeamUrl, {
        "team_id": teamId,
        "trainer_id": trainerId,
        "profile": profile, // main/extra/doctor/admin
      });

      if (data["status"] == "success" || data["success"] == true) {
        Get.snackbar(
          "Готово",
          "Пользователь привязан к команде",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        await _loadTeamTrainers();
      } else {
        Get.snackbar(
          "Ошибка",
          _asStr(data["message"]).isEmpty ? "Не удалось" : _asStr(data["message"]),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      }
    } catch (e) {
      Get.snackbar(
        "Сеть",
        "Ошибка: $e",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  Future<void> _unlinkTrainer(int trainerId) async {
    final teamId = selectedTeamId ?? 0;
    if (teamId <= 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Отвязать пользователя?"),
        content: Text("Профиль будет отвязан от команды «$selectedTeamName»."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Отвязать",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final data = await _postJson(unlinkTrainerFromTeamUrl, {
        "team_id": teamId,
        "trainer_id": trainerId,
      });

      if (data["status"] == "success" || data["success"] == true) {
        Get.snackbar(
          "Готово",
          "Профиль отвязан",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        await _loadTeamTrainers();
      } else {
        Get.snackbar(
          "Ошибка",
          _asStr(data["message"]).isEmpty ? "Не удалось" : _asStr(data["message"]),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      }
    } catch (e) {
      Get.snackbar(
        "Сеть",
        "Ошибка: $e",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  Future<void> _pickTeam() async {
    if (widget.teams.isEmpty) return;

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: _TeamPickerSheet(
            teams: widget.teams,
            selectedTeamId: selectedTeamId ?? 0,
            teamIdFrom: _teamIdFrom,
            teamNameFrom: _teamNameFrom,
            teamLogoFrom: _teamLogoFrom,
            teamCategoryFrom: _teamCategoryFrom,
          ),
        );
      },
    );

    if (picked != null) {
      final id = _teamIdFrom(picked);
      final name = _teamNameFrom(picked);
      final logo = _teamLogoFrom(picked);

      setState(() {
        selectedTeamId = id;
        selectedTeamName = name;
        selectedTeamLogoUrl = logo;
      });

      if ((selectedTeamId ?? 0) > 0) {
        await _loadTeamTrainers();
      } else {
        setState(() {
          error = "Выбранная команда без id/team_id. Проверь get_club_teams.php";
        });
      }
    }
  }

  String _profileTitle(String profile) {
    switch (profile) {
      case "main":
        return "Главный тренер";
      case "doctor":
        return "Врач";
      case "admin":
        return "Админ клуба";
      case "extra":
      default:
        return "Тренер / ассистент";
    }
  }

  String _profileBadgeText(String profile) {
    switch (profile) {
      case "admin":
        return "ADMIN";
      case "doctor":
        return "MED";
      case "main":
        return "MAIN";
      default:
        return "COACH";
    }
  }

  Color _profileBadgeColor(BuildContext context, String profile) {
    final primary = Theme.of(context).colorScheme.primary;
    switch (profile) {
      case "doctor":
        return Colors.teal;
      case "admin":
        return Colors.deepPurple;
      case "main":
        return primary;
      case "extra":
      default:
        return primary;
    }
  }

  void _openChatWithTrainer(int trainerId, String trainerName) {
    Get.snackbar(
      "Чат",
      "Открыть чат с: $trainerName (id=$trainerId)",
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Тренеры",
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: "Сменить команду",
            onPressed: _pickTeam,
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.black87),
          ),
          IconButton(
            tooltip: "Обновить",
            onPressed: _loadTeamTrainers,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        onPressed: () async {
          if ((selectedTeamId ?? 0) <= 0) {
            Get.snackbar("Команда", "Сначала выберите команду");
            return;
          }

          final pickedUser = await _pickTrainerByEmailSheet();
          if (pickedUser == null) return;

          final userId = _asInt(pickedUser["id"]);
          if (userId <= 0) return;

          final profile = await _pickTeamProfileTypeSheet();
          if (profile == null || profile.isEmpty) return;

          await _linkTrainer(userId, profile: profile);
        },
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text(
          "Добавить тренера",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: widget.teams.isEmpty
          ? const Center(child: Text("У клуба нет команд."))
          : loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? _ErrorView(text: error!, onRetry: _loadTeamTrainers)
                  : RefreshIndicator(
                      onRefresh: _loadTeamTrainers,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _HeroHeader(
                            clubName: widget.clubName,
                            teamName: selectedTeamName,
                            teamLogoUrl: selectedTeamLogoUrl,
                            count: trainers.length,
                            onPickTeam: _pickTeam,
                          ),
                          const SizedBox(height: 12),
                          _SearchBox(controller: _searchCtrl),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  "Тренерско-преподавательский состав",
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                              ),
                              Text(
                                "всего: ${filtered.length}",
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (filtered.isEmpty)
                            const _EmptyHint(
                              text:
                                  "Пока нет тренеров у выбранной команды.\nНажмите «Добавить тренера» и привяжите по email.",
                            )
                          else
                            ...filtered.map((t) {
                              final id = _asInt(t["id"]);
                              final fn = _asStr(t["first_name"]).trim();
                              final ln = _asStr(t["last_name"]).trim();
                              final email = _asStr(t["email"]).trim();

                              final photo = _normalizeUserPhoto(_asStr(t["photo"]));

                              final profile = _asStr(t["profile"]).trim().isEmpty
                                  ? _asStr(t["link_type"]).trim()
                                  : _asStr(t["profile"]).trim();
                              final p = profile.isEmpty ? "extra" : profile;

                              final name = ("$fn $ln").trim().isEmpty
                                  ? "Профиль #$id"
                                  : ("$fn $ln").trim();

                              final badgeText = _profileBadgeText(p);
                              final badgeColor = _profileBadgeColor(context, p);
                              final roleTitle = _profileTitle(p);

                              return _TrainerTileCard(
                                primary: primary,
                                badgeColor: badgeColor,
                                badgeText: badgeText,
                                name: name,
                                subtitle: roleTitle,
                                email: email.isEmpty ? "email не указан" : email,
                                photoUrl: photo,
                                onTap: () async {
                                  final res = await Get.to<bool>(() => TeamTrainerCardScreen(
                                        clubName: widget.clubName,
                                        teamName: selectedTeamName,
                                        profileTitle: _profileTitle(p),
                                        profileCode: p,
                                        trainer: t,
                                      ));
                                  if (res == true) {
                                    await _loadTeamTrainers();
                                  }
                                },
                                onChat: () => _openChatWithTrainer(id, name),
                                onUnlink: () => _unlinkTrainer(id),
                                canUnlink: p != "main",
                              );
                            }),
                        ],
                      ),
                    ),
    );
  }
}

// ============================================================================
// Визитка тренера (экран) — грузит данные из get_trainer_profile.php
// ============================================================================
class TeamTrainerCardScreen extends StatefulWidget {
  final String clubName;
  final String teamName;
  final String profileTitle;
  final String profileCode;
  final Map<String, dynamic> trainer;

  const TeamTrainerCardScreen({
    super.key,
    required this.clubName,
    required this.teamName,
    required this.profileTitle,
    required this.profileCode,
    required this.trainer,
  });

  @override
  State<TeamTrainerCardScreen> createState() => _TeamTrainerCardScreenState();
}

class _TeamTrainerCardScreenState extends State<TeamTrainerCardScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getUrl = "$apiBase/get_trainer_profile.php";

  bool loading = true;
  String? error;

  Map<String, dynamic> profile = {}; // position,bio,birthday,experience

  String _asStr(dynamic v) => (v ?? "").toString();

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      final j = json.decode(r.body);
      return j is Map<String, dynamic> ? j : {"status": "error", "message": "bad json"};
    } catch (_) {
      return {"status": "error", "message": "bad json"};
    }
  }

  String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    if (!s.startsWith("/")) s = "/$s";
    return "https://sportotekaapp.ru$s";
  }

  String? _normalizeUserPhoto(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;

    if (s.startsWith("uploads/") || s.startsWith("/uploads/")) {
      if (!s.startsWith("/")) s = "/$s";
      return "https://sportotekaapp.ru$s";
    }

    if (!s.startsWith("/")) s = "/uploads/$s";
    return "https://sportotekaapp.ru$s";
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final trainerId = _asInt(widget.trainer["id"]);
    if (trainerId <= 0) {
      setState(() {
        loading = false;
        error = "trainer_id = 0";
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final resp = await http.post(
        Uri.parse(getUrl),
        headers: const {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode({"trainer_id": trainerId}),
      );

      // ignore: avoid_print
      print("CARD get_trainer_profile RESP ${resp.statusCode}: ${resp.body}");

      final data = _decode(resp);

      if ((data["success"] == true || data["status"] == "success") && data["profile"] is Map) {
        profile = Map<String, dynamic>.from(data["profile"]);
      } else {
        profile = {};
      }

      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = "$e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8);
    final primary = Theme.of(context).colorScheme.primary;

    final id = _asInt(widget.trainer["id"]);
    final fn = _asStr(widget.trainer["first_name"]).trim();
    final ln = _asStr(widget.trainer["last_name"]).trim();
    final email = _asStr(widget.trainer["email"]).trim();
    final name = ("$fn $ln").trim().isEmpty ? "Профиль #$id" : ("$fn $ln").trim();

    final photoRaw = _asStr(widget.trainer["photo"]).trim();
    final photo = _normalizeUserPhoto(photoRaw.isEmpty ? null : photoRaw);

    // ✅ ВАЖНО: берём визитку из profile, который пришёл из get_trainer_profile.php
    final pos = _asStr(profile["position"]).trim();
    final bio = _asStr(profile["bio"]).trim();
    final born = _asStr(profile["birthday"]).trim();
    final career = _asStr(profile["experience"]).trim();

    Color badgeColor() {
      switch (widget.profileCode) {
        case "doctor":
          return Colors.teal;
        case "admin":
          return Colors.deepPurple;
        case "main":
          return primary;
        default:
          return primary;
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Визитка",
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
        ),
        actions: [
          IconButton(
            tooltip: "Обновить",
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            onPressed: _loadProfile,
          ),
          IconButton(
            tooltip: "Редактировать",
            icon: const Icon(Icons.edit_outlined, color: Colors.black87),
            onPressed: () async {
              final saved = await Get.to<bool>(() => EditTrainerProfileScreen(
                    trainerId: id,
                    trainerName: name,
                  ));
              if (saved == true) {
                await _loadProfile();
                Get.back(result: true);
              }
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: primary.withOpacity(0.25), width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: photo != null
                                  ? Image.network(
                                      photo,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _fallbackAvatar(primary),
                                    )
                                  : _fallbackAvatar(primary),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900, fontSize: 18)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: badgeColor().withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        widget.profileTitle,
                                        style: TextStyle(
                                            color: badgeColor(),
                                            fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    if (pos.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: primary.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          pos,
                                          style: TextStyle(
                                              color: primary,
                                              fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.clubName,
                                  style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.teamName,
                                  style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (email.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (born.isNotEmpty) _InfoSection(title: "Дата рождения", text: born),
                    if (born.isNotEmpty) const SizedBox(height: 12),
                    if (career.isNotEmpty) _InfoSection(title: "Опыт / карьера", text: career),
                    if (career.isNotEmpty) const SizedBox(height: 12),
                    _InfoSection(
                      title: "Описание",
                      text: bio.isNotEmpty
                          ? bio
                          : "Описание тренера пока не заполнено.\nНажмите «Редактировать» и заполните профиль.",
                    ),
                  ],
                ),
    );
  }

  Widget _fallbackAvatar(Color primary) {
    return Container(
      color: primary.withOpacity(0.10),
      child: Icon(Icons.person_outline, color: primary),
    );
  }
}

// ============================================================================
// UI pieces
// ============================================================================

class _HeroHeader extends StatelessWidget {
  final String clubName;
  final String teamName;
  final String? teamLogoUrl;
  final int count;
  final VoidCallback onPickTeam;

  const _HeroHeader({
    required this.clubName,
    required this.teamName,
    required this.teamLogoUrl,
    required this.count,
    required this.onPickTeam,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.school_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Тренерский штаб",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$clubName • всего: $count",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                _LogoCircle(url: teamLogoUrl, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    teamName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                _PrimaryPillButton(
                  text: "Сменить",
                  icon: Icons.swap_horiz_rounded,
                  onTap: onPickTeam,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBox({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: "Поиск: ФИО, email, роль, описание",
          icon: Icon(Icons.search),
        ),
      ),
    );
  }
}

class _TrainerTileCard extends StatelessWidget {
  final Color primary;
  final Color badgeColor;
  final String badgeText;

  final String name;
  final String subtitle;
  final String email;
  final String? photoUrl;

  final VoidCallback onTap;
  final VoidCallback onChat;
  final VoidCallback onUnlink;
  final bool canUnlink;

  const _TrainerTileCard({
    required this.primary,
    required this.badgeColor,
    required this.badgeText,
    required this.name,
    required this.subtitle,
    required this.email,
    required this.photoUrl,
    required this.onTap,
    required this.onChat,
    required this.onUnlink,
    required this.canUnlink,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: primary.withOpacity(0.12),
              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                  ? NetworkImage(photoUrl!)
                  : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? Icon(Icons.person_outline, color: primary, size: 28)
                  : null,
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
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == "unlink") onUnlink();
                        },
                        itemBuilder: (_) => [
                          if (canUnlink)
                            const PopupMenuItem(
                              value: "unlink",
                              child: Row(
                                children: [
                                  Icon(Icons.link_off, color: Colors.red, size: 18),
                                  SizedBox(width: 10),
                                  Text("Отвязать от команды",
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.more_horiz),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: primary, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 18, color: primary),
                      const SizedBox(width: 8),
                      const Text(
                        "Открыть визитку",
                        style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: "Написать",
                        onPressed: onChat,
                        icon: Icon(Icons.chat_bubble_outline, color: primary),
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

class _InfoSection extends StatelessWidget {
  final String title;
  final String text;

  const _InfoSection({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
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
            const Icon(Icons.wifi_off_rounded, size: 44),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text("Повторить")),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Красивый выбор команд (Sheet)
// ============================================================================
class _TeamPickerSheet extends StatelessWidget {
  final List<dynamic> teams;
  final int selectedTeamId;
  final int Function(dynamic t) teamIdFrom;
  final String Function(dynamic t) teamNameFrom;
  final String? Function(dynamic t) teamLogoFrom;
  final String Function(dynamic t) teamCategoryFrom;

  const _TeamPickerSheet({
    required this.teams,
    required this.selectedTeamId,
    required this.teamIdFrom,
    required this.teamNameFrom,
    required this.teamLogoFrom,
    required this.teamCategoryFrom,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 5,
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Выбор команды",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
            itemCount: teams.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final raw = teams[i];
              final id = teamIdFrom(raw);
              final name = teamNameFrom(raw);
              final logo = teamLogoFrom(raw);
              final cat = teamCategoryFrom(raw);
              final isSel = selectedTeamId == id;

              final subtitle = <String>[
                if (cat.isNotEmpty) cat,
                "ID: $id",
              ].join(" • ");

              return InkWell(
                onTap: () {
                  final map = (raw is Map)
                      ? Map<String, dynamic>.from(raw as Map)
                      : <String, dynamic>{};
                  Navigator.pop(context, map);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? primary.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _LogoCircle(url: logo, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? "Команда #$id" : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: isSel ? primary : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
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
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? primary.withOpacity(0.14) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSel ? Icons.check_circle : Icons.chevron_right,
                              size: 18,
                              color: isSel ? primary : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isSel ? "Выбрано" : "Открыть",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isSel ? primary : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Маленькие UI helpers
// ============================================================================
class _LogoCircle extends StatelessWidget {
  final String? url;
  final double size;

  const _LogoCircle({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: primary.withOpacity(0.18)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: (url != null && url!.isNotEmpty)
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(primary),
              )
            : _fallback(primary),
      ),
    );
  }

  Widget _fallback(Color primary) {
    return Container(
      color: primary.withOpacity(0.08),
      child: Icon(Icons.shield_outlined, color: primary),
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryPillButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
