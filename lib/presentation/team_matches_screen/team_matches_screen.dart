// lib/presentation/team_matches_screen/team_matches_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_matches_screen/team_match_detail_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/team_match_video_workspace_screen.dart';

class TeamMatchesScreen extends StatefulWidget {
  const TeamMatchesScreen({super.key});

  @override
  State<TeamMatchesScreen> createState() => _TeamMatchesScreenState();
}

enum _MatchesFilter { all, upcoming, past }

class _TeamMatchesScreenState extends State<TeamMatchesScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getUrl = "$apiBase/get_team_matches.php";
  static const String addUrl = "$apiBase/add_team_match.php";
  static const String deleteUrl = "$apiBase/delete_team_match.php";
  static const String getUserUrl = "$apiBase/get_user.php";

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> matches = [];
  bool loading = true;

  late int teamId;
  late String teamName;

  _MatchesFilter _filter = _MatchesFilter.upcoming;

  int userId = 0;
  String role = "";

  bool get canManageMatches => role.toLowerCase() != "player";

  Color get primary => Theme.of(context).colorScheme.primary;
  Color get bg => const Color(0xFFF3F5F8);

  @override
  void initState() {
    super.initState();
    teamId = _readTeamId(Get.arguments);
    teamName = _readTeamName(Get.arguments);
    _searchCtrl.addListener(_onSearchChanged);
    _initAndLoad();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    final uid = await PrefUtils.getUserId();
    userId = uid ?? 0;

    if (userId > 0) {
      role = await _fetchRoleByUser(userId);
    } else {
      role = "";
    }

    await load();
  }

  Future<String> _fetchRoleByUser(int uid) async {
    try {
      final uri = Uri.parse("$getUserUrl?user_id=$uid");
      final resp = await http.get(uri);
      final data = jsonDecode(resp.body);

      if (data is! Map) return "";
      final ok = data["success"] == true || data["status"] == "success";
      if (!ok) return "";

      final user = data["user"];
      if (user is Map) {
        return (user["role"] ?? "").toString().trim().toLowerCase();
      }
      return "";
    } catch (_) {
      return "";
    }
  }

  int _readTeamId(dynamic arg) {
    if (arg is int) return arg;
    if (arg is String) return int.tryParse(arg) ?? 0;
    if (arg is Map) {
      final v = arg["teamId"] ?? arg["team_id"] ?? arg["id"];
      return int.tryParse(v?.toString() ?? "") ?? 0;
    }
    return int.tryParse(arg?.toString() ?? "") ?? 0;
  }

  String _readTeamName(dynamic arg) {
    if (arg is Map) {
      final v = arg["teamName"] ?? arg["team_name"] ?? arg["name"];
      return (v ?? "").toString().trim();
    }
    return "";
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final res = await http.post(
        Uri.parse(getUrl),
        headers: const {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: jsonEncode({
          "team_id": teamId,
        }),
      );

      debugPrint("GET MATCHES RESPONSE: ${res.body}");

      final raw = res.body.trim();
      final jsonStart = raw.indexOf('{');

      if (jsonStart == -1) {
        Get.snackbar("Ошибка", "Сервер вернул некорректный ответ");
        if (mounted) setState(() => loading = false);
        return;
      }

      final cleanJson = raw.substring(jsonStart);
      final data = jsonDecode(cleanJson);

      if (data is Map &&
          (data["status"] == "success" || data["success"] == true)) {
        final list = (data["matches"] as List?) ?? [];
        matches = list.map((e) => Map<String, dynamic>.from(e)).toList();

        matches.sort((a, b) {
          final da = _parseDate(_s(a["match_date"]));
          final db = _parseDate(_s(b["match_date"]));
          return da.compareTo(db);
        });
      } else {
        Get.snackbar(
          "Ошибка",
          data["message"]?.toString() ?? "Не удалось загрузить матчи",
        );
      }
    } catch (e) {
      debugPrint("GET MATCHES ERROR: $e");
      Get.snackbar("Ошибка сети", "Проверь интернет и API");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openAddMatchSheet() async {
  if (!canManageMatches) {
    Get.snackbar("Доступ ограничен", "Игрок не может добавлять матчи");
    return;
  }

  if (teamId <= 0) {
    Get.snackbar("Ошибка", "Не удалось определить team_id");
    return;
  }

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddMatchSheet(
      primary: primary,
      onSubmit: ({
        required String eventType,
        required String opponent,
        required String ourScore,
        required String opponentScore,
        required String matchDate,
        required String competitionName,
        required String tourLabel,
        required String stadium,
        required String referees,
        required String notes,
      }) async {
        return await _addMatch(
          eventType: eventType,
          opponent: opponent,
          ourScore: ourScore,
          opponentScore: opponentScore,
          matchDate: matchDate,
          competitionName: competitionName,
          tourLabel: tourLabel,
          stadium: stadium,
          referees: referees,
          notes: notes,
        );
      },
    ),
  );

  if (created == true) {
    await load();
    Get.snackbar("Готово", "Матч добавлен");
  }
}

  Future<bool> _addMatch({
    required String eventType,
    required String opponent,
    required String ourScore,
    required String opponentScore,
    required String matchDate,
    required String competitionName,
    required String tourLabel,
    required String stadium,
    required String referees,
    required String notes,
  }) async {
    if (!canManageMatches) {
      Get.snackbar("Доступ ограничен", "Игрок не может добавлять матчи");
      return false;
    }

    final opp = opponent.trim();

    if (opp.isEmpty) {
      Get.snackbar("Ошибка", "Укажи соперника");
      return false;
    }

    if (matchDate.trim().isEmpty) {
      Get.snackbar("Ошибка", "Укажи дату матча");
      return false;
    }


    try {
      final res = await http.post(
        Uri.parse(addUrl),
        headers: const {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: jsonEncode({
  "team_id": teamId,
  "team_name": teamName.trim().isEmpty ? "Команда #$teamId" : teamName,
  "event_type": eventType,
  "opponent": opp,
  "our_score": int.tryParse(ourScore.trim()) ?? 0,
  "opponent_score": int.tryParse(opponentScore.trim()) ?? 0,
  "match_date": matchDate,
  "competition_name": competitionName.trim(),
  "tour_label": tourLabel.trim(),
  "stadium": stadium.trim(),
  "referees": referees.trim(),
  "notes": notes.trim(),
}),
      ).timeout(const Duration(seconds: 20));

      debugPrint("ADD MATCH STATUS: ${res.statusCode}");
      debugPrint("ADD MATCH RAW RESPONSE: ${res.body}");

      final raw = res.body.trim();
      final jsonStart = raw.indexOf('{');

      if (jsonStart == -1) {
        Get.snackbar("Ошибка", "Сервер вернул некорректный ответ");
        return false;
      }

      final cleanJson = raw.substring(jsonStart);
      final data = jsonDecode(cleanJson);

      if (data is Map &&
          (data["status"] == "success" || data["success"] == true)) {
        return true;
      } else {
        Get.snackbar(
          "Ошибка",
          data["message"]?.toString() ?? "Не удалось добавить матч",
        );
        return false;
      }
    } catch (e) {
      debugPrint("ADD MATCH ERROR: $e");
      Get.snackbar("Ошибка", "Проверь API add_team_match.php");
      return false;
    }
  }

  Future<void> _deleteMatch(int matchId) async {
    if (!canManageMatches) {
      Get.snackbar("Доступ ограничен", "Игрок не может удалять матчи");
      return;
    }
    if (matchId <= 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Удалить матч?"),
        content: const Text("Действие нельзя отменить."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final res = await http.post(
        Uri.parse(deleteUrl),
        body: {
          "id": matchId.toString(),
          "team_id": teamId.toString(),
        },
      );

      final raw = res.body.trim();
      final jsonStart = raw.indexOf('{');

      if (jsonStart == -1) {
        Get.snackbar("Ошибка", "Сервер вернул некорректный ответ");
        return;
      }

      final cleanJson = raw.substring(jsonStart);
      final data = jsonDecode(cleanJson);

      if (data is Map &&
          (data["status"] == "success" || data["success"] == true)) {
        Get.snackbar("Готово", "Матч удалён");
        await load();
      } else {
        Get.snackbar(
          "Ошибка",
          data["message"]?.toString() ?? "Не удалось удалить матч",
        );
      }
    } catch (e) {
      debugPrint("DELETE MATCH ERROR: $e");
      Get.snackbar("Ошибка сети", "Проверь интернет и API");
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() {});
    });
  }

  String _s(dynamic v) => (v ?? "").toString().trim();
  int _i(dynamic v) => int.tryParse((v ?? "").toString()) ?? 0;

  DateTime _parseDate(String s) {
    try {
      final t = s.trim();

      if (t.contains('.')) {
        final p = t.split('.');
        if (p.length == 3) {
          final dd = int.tryParse(p[0]) ?? 1;
          final mm = int.tryParse(p[1]) ?? 1;
          final yy = int.tryParse(p[2]) ?? 2000;
          return DateTime(yy, mm, dd);
        }
      }

      if (t.contains('-')) {
        final d = DateTime.tryParse(t);
        if (d != null) return DateTime(d.year, d.month, d.day);
      }
    } catch (_) {}

    return DateTime(2000, 1, 1);
  }

  String _formatRu(DateTime d) {
    String two(int v) => v.toString().padLeft(2, "0");
    return "${two(d.day)}.${two(d.month)}.${d.year}";
  }

  bool _isUpcoming(DateTime d) {
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    return !d.isBefore(t0);
  }

  String _eventTypeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'championship':
        return 'Чемпионат';
      case 'friendly':
        return 'Товарищеский';
      case 'tournament':
        return 'Турнир';
      default:
        return raw.isEmpty ? 'Матч' : raw;
    }
  }

  List<Map<String, dynamic>> _filteredMatches() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);

    Iterable<Map<String, dynamic>> list = matches;

    if (_filter == _MatchesFilter.upcoming) {
      list = list.where((m) => !_parseDate(_s(m["match_date"])).isBefore(t0));
    } else if (_filter == _MatchesFilter.past) {
      list = list.where((m) => _parseDate(_s(m["match_date"])).isBefore(t0));
    }

    if (q.isNotEmpty) {
      list = list.where((m) {
        final opp = _s(m["opponent"]).toLowerCase();
        final date = _s(m["match_date"]).toLowerCase();
        final type = _s(m["event_type"]).toLowerCase();
        final competition = _s(m["competition_name"]).toLowerCase();
        return opp.contains(q) ||
            date.contains(q) ||
            type.contains(q) ||
            competition.contains(q);
      });
    }

    final out = list.toList();
    out.sort((a, b) {
      return _parseDate(_s(a["match_date"]))
          .compareTo(_parseDate(_s(b["match_date"])));
    });
    return out;
  }

  Map<String, List<Map<String, dynamic>>> _groupByMonth(
    List<Map<String, dynamic>> list,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};

    for (final m in list) {
      final d = _parseDate(_s(m["match_date"]));
      final key = "${_monthRu(d.month)} ${d.year}";
      map.putIfAbsent(key, () => []);
      map[key]!.add(m);
    }

    for (final k in map.keys) {
      map[k]!.sort((a, b) {
        return _parseDate(_s(a["match_date"]))
            .compareTo(_parseDate(_s(b["match_date"])));
      });
    }

    return map;
  }

  String _monthRu(int m) {
    const months = [
      "январь",
      "февраль",
      "март",
      "апрель",
      "май",
      "июнь",
      "июль",
      "август",
      "сентябрь",
      "октябрь",
      "ноябрь",
      "декабрь"
    ];
    if (m < 1 || m > 12) return "месяц";
    return months[m - 1];
  }

  bool _shouldOpenMatchFullscreen(BuildContext context) {
    // На iOS/Android планшет должен вести себя как мобильная версия:
    // открываем детали матча на весь экран, а не как desktop-окно.
    final isDesktopPlatform = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (!isDesktopPlatform) return true;

    // На реальном ПК оконный режим оставляем только для нормальной ширины.
    // Если desktop-окно сильно узкое, также открываем fullscreen.
    final width = MediaQuery.of(context).size.width;
    return width < 900;
  }

  Future<void> _openMatchDetail(Map<String, dynamic> match, int matchId) async {
    // Один новый маршрут детального матча: Tracker-подобный видео workspace.
    // На desktop/tablet/phone используется один адаптивный экран.
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => TeamMatchVideoWorkspaceScreen(
          matchId: matchId,
          teamId: teamId,
          teamName: teamName,
          initialMatch: Map<String, dynamic>.from(match),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredMatches();
    final grouped = _groupByMonth(list);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Text(
          "Матчи команды",
          style: AppTypography.screenTitle(),
        ),
        actions: [
          IconButton(
            tooltip: "Обновить",
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: (!loading && canManageMatches)
          ? FloatingActionButton.extended(
              onPressed: _openAddMatchSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text("Добавить"),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _topPanel()),
            SliverToBoxAdapter(child: const SizedBox(height: 12)),
            if (loading) ...[
              SliverToBoxAdapter(child: _skeleton()),
            ] else if (matches.isEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _MatteSurface(
                    child: Text(
                      "Нет запланированных матчей.",
                      style: AppTypography.emptyText(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (list.isEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _MatteSurface(
                    child: Text(
                      "Ничего не найдено по фильтрам или поиску.",
                      style: AppTypography.emptyText(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    grouped.entries.expand((entry) sync* {
                      yield _MonthHeader(
                        title: entry.key,
                        count: entry.value.length,
                      );
                      yield const SizedBox(height: 10);

                      for (final m in entry.value) {
                        final id = _i(m["id"]);
                        final d = _parseDate(_s(m["match_date"]));
                        final upcoming = _isUpcoming(d);
                        final rawDate = _s(m["match_date"]);
                        final dateText =
                            rawDate.contains('-') ? _formatRu(d) : rawDate;

                        yield Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MatchTileMatte(
                            primary: primary,
                            eventType:
                                _eventTypeLabel(_s(m["event_type"])),
                            opponent: _s(m["opponent"]),
                            date: dateText,
                            competitionName: _s(m["competition_name"]),
                            score:
                                "${_s(m["our_score"]).isEmpty ? "0" : _s(m["our_score"])}:"
                                "${_s(m["opponent_score"]).isEmpty ? "0" : _s(m["opponent_score"])}",
                            upcoming: upcoming,
                            canDelete: canManageMatches && id > 0,
                            onDelete: () => _deleteMatch(id),
                            onTap: () => _openMatchDetail(m, id),
                          ),
                        );
                      }

                      yield const SizedBox(height: 6);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _topPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          _MatteSearch(
            controller: _searchCtrl,
            hint: "Поиск по сопернику, турниру или дате",
            onClear: () {
              _searchCtrl.clear();
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChipMatte(
                  label: "Все",
                  icon: Icons.layers_outlined,
                  selected: _filter == _MatchesFilter.all,
                  onTap: () => setState(() => _filter = _MatchesFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChipMatte(
                  label: "Предстоящие",
                  icon: Icons.schedule_rounded,
                  selected: _filter == _MatchesFilter.upcoming,
                  onTap: () => setState(() => _filter = _MatchesFilter.upcoming),
                ),
                const SizedBox(width: 8),
                _FilterChipMatte(
                  label: "Прошедшие",
                  icon: Icons.history_rounded,
                  selected: _filter == _MatchesFilter.past,
                  onTap: () => setState(() => _filter = _MatchesFilter.past),
                ),
                const SizedBox(width: 8),
                if (_searchCtrl.text.trim().isNotEmpty)
                  _FilterChipMatte(
                    label: "Сбросить поиск",
                    icon: Icons.close_rounded,
                    selected: true,
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                  ),
              ],
            ),
          ),
          if (!canManageMatches) ...[
            const SizedBox(height: 10),
            _MatteSurface(
              child: Text(
                "Игрок может только просматривать матчи. Добавление и удаление доступно тренеру.",
                style: AppTypography.secondaryMedium(
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _skeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: List.generate(
          6,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MatteSurface(
              child: Row(
                children: const [
                  _SkeletonBox(size: 46),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonLine(widthFactor: 0.85),
                        SizedBox(height: 10),
                        _SkeletonLine(widthFactor: 0.45),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMatchSheet extends StatefulWidget {
  final Color primary;
  final Future<bool> Function({
    required String eventType,
    required String opponent,
    required String ourScore,
    required String opponentScore,
    required String matchDate,
    required String competitionName,
    required String tourLabel,
    required String stadium,
    required String referees,
    required String notes,
  }) onSubmit;

  const _AddMatchSheet({
    required this.primary,
    required this.onSubmit,
  });

  @override
  State<_AddMatchSheet> createState() => _AddMatchSheetState();
}

class _AddMatchSheetState extends State<_AddMatchSheet> {
  final TextEditingController _opponentCtrl = TextEditingController();
  final TextEditingController _ourScoreCtrl = TextEditingController(text: "0");
  final TextEditingController _opponentScoreCtrl =
      TextEditingController(text: "0");
  final TextEditingController _competitionCtrl = TextEditingController();
  final TextEditingController _tourCtrl = TextEditingController();
  final TextEditingController _stadiumCtrl = TextEditingController();
  final TextEditingController _refereesCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  DateTime? _picked;
  bool _saving = false;
  String _eventType = "championship";

  @override
  void dispose() {
    _opponentCtrl.dispose();
    _ourScoreCtrl.dispose();
    _opponentScoreCtrl.dispose();
    _competitionCtrl.dispose();
    _tourCtrl.dispose();
    _stadiumCtrl.dispose();
    _refereesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, "0");
  String _dateRu(DateTime d) => "${_two(d.day)}.${_two(d.month)}.${d.year}";
  String _dateIso(DateTime d) => "${d.year}-${_two(d.month)}-${_two(d.day)}";

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 2, 1, 1);
    final last = DateTime(now.year + 3, 12, 31);

    final res = await showDatePicker(
      context: context,
      initialDate: _picked ?? now,
      firstDate: first,
      lastDate: last,
      helpText: "Выберите дату матча",
    );

    if (res != null) {
      setState(() => _picked = DateTime(res.year, res.month, res.day));
    }
  }

  Future<void> _submit() async {
    final opp = _opponentCtrl.text.trim();
    final d = _picked;

    if (opp.isEmpty || d == null) {
      Get.snackbar("Ошибка", "Заполни соперника и дату матча");
      return;
    }

    setState(() => _saving = true);

    try {
      final ok = await widget.onSubmit(
        eventType: _eventType,
        opponent: opp,
        ourScore: _ourScoreCtrl.text.trim(),
        opponentScore: _opponentScoreCtrl.text.trim(),
        matchDate: _dateIso(d),
        competitionName: _competitionCtrl.text.trim(),
        tourLabel: _tourCtrl.text.trim(),
        stadium: _stadiumCtrl.text.trim(),
        referees: _refereesCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );

      if (ok && mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final canSave =
        _opponentCtrl.text.trim().isNotEmpty && _picked != null && !_saving;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Icon(
                          Icons.sports_soccer_rounded,
                          color: widget.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Добавить матч",
                          style: AppTypography.screenTitle(),
                        ),
                      ),
                      IconButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _MatteSurface(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _eventType,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        labelText: "Тип матча",
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "championship",
                          child: Text("Чемпионат"),
                        ),
                        DropdownMenuItem(
                          value: "friendly",
                          child: Text("Товарищеский"),
                        ),
                        DropdownMenuItem(
                          value: "tournament",
                          child: Text("Турнир"),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() => _eventType = v);
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _opponentCtrl,
                    icon: Icons.shield_outlined,
                    hint: "Соперник",
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _ourScoreCtrl,
                          icon: Icons.looks_one_rounded,
                          hint: "Наш счёт",
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _opponentScoreCtrl,
                          icon: Icons.looks_two_rounded,
                          hint: "Счёт соперника",
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _MatteSurface(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    onTap: _saving ? null : _pickDate,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _picked == null
                                ? "Выбрать дату матча"
                                : _dateRu(_picked!),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _picked == null
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _competitionCtrl,
                    icon: Icons.emoji_events_outlined,
                    hint: "Турнир / соревнование",
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _tourCtrl,
                    icon: Icons.format_list_numbered_rounded,
                    hint: "Тур / этап",
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _stadiumCtrl,
                    icon: Icons.location_on_outlined,
                    hint: "Стадион",
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _refereesCtrl,
                    icon: Icons.gavel_rounded,
                    hint: "Судьи",
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _notesCtrl,
                    icon: Icons.notes_rounded,
                    hint: "Примечания",
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: canSave ? _submit : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_saving ? "Сохранение..." : "Сохранить"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return _MatteSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 10 : 0),
            child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                hintStyle: AppTypography.formHint(color: const Color(0xFF94A3B8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatteSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const _MatteSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }
}

class _MatteSearch extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onClear;

  const _MatteSearch({
    required this.controller,
    required this.hint,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return _MatteSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 22, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                hintStyle: AppTypography.formHint(color: const Color(0xFF94A3B8)),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

class _FilterChipMatte extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipMatte({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFEFF6FF) : Colors.white;
    final border = selected ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB);
    final text = selected ? const Color(0xFF1D4ED8) : const Color(0xFF334155);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: text),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.chip(color: text, active: selected)),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final String title;
  final int count;

  const _MonthHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: AppTypography.menuGroup(
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text("$count", style: AppTypography.badge(color: const Color(0xFF334155))),
        ),
      ],
    );
  }
}

class _MatchTileMatte extends StatelessWidget {
  final Color primary;
  final String eventType;
  final String opponent;
  final String date;
  final String competitionName;
  final String score;
  final bool upcoming;
  final bool canDelete;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const _MatchTileMatte({
    required this.primary,
    required this.eventType,
    required this.opponent,
    required this.date,
    required this.competitionName,
    required this.score,
    required this.upcoming,
    this.canDelete = false,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeBg = upcoming ? const Color(0xFFEFFDF5) : const Color(0xFFF1F5F9);
    final badgeBorder = upcoming ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB);
    final badgeText = upcoming ? const Color(0xFF166534) : const Color(0xFF334155);
    final icon = upcoming ? Icons.schedule_rounded : Icons.history_rounded;

    return _MatteSurface(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Icon(Icons.sports_soccer_rounded, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent.isEmpty ? "Соперник" : opponent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.itemTitle(),
                ),
                const SizedBox(height: 6),
                Text(
                  eventType,
                  style: AppTypography.secondaryMedium(
                    color: const Color(0xFF2563EB),
                  ),
                ),
                if (competitionName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    competitionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.secondaryMedium(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: badgeText),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            style: AppTypography.chip(
                              color: badgeText,
                              active: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        "Счёт: $score",
                        style: AppTypography.chip(
                          color: const Color(0xFF0F172A),
                          active: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              if (canDelete)
                IconButton(
                  tooltip: "Удалить",
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: const Color(0xFFEF4444),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;

  const _SkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double size;

  const _SkeletonBox({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}