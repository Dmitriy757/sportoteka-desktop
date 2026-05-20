// lib/presentation/club_workspace/club_workspace_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/create_challenge_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/create_quiz_screen.dart';
import 'package:sportoteka/presentation/manager_mode/screens/manager_dashboard_screen.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_screen.dart';
import 'package:sportoteka/presentation/team_description_screen/team_description_screen.dart';
import 'package:sportoteka/presentation/team_matches_screen/team_matches_screen.dart';
import 'package:sportoteka/presentation/team_roster_screen/team_roster_screen.dart';
import 'package:sportoteka/presentation/team_screen/team_dashboard_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/team_video_analysis_screen.dart';
import 'package:sportoteka/presentation/training_graphics/training_graphics_screen.dart';
import 'package:sportoteka/presentation/video_lessons/video_lessons_screen.dart';
import 'package:sportoteka/routes/app_routes.dart';
import 'package:sportoteka/presentation/plans/cmr_plans_panel.dart';
import 'package:sportoteka/presentation/team_calendar_screen/cmr_calendar_panel.dart';
import 'package:sportoteka/presentation/team_video_analysis/cmr_video_analysis_panel.dart';
import 'package:sportoteka/presentation/team_attendance_screen/cmr_attendance_panel.dart';
import 'package:sportoteka/presentation/team_matches_screen/cmr_team_matches_panel.dart';
import 'package:sportoteka/presentation/testing/cmr_testing_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_club_trainers_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_chats_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_game_zone_panel.dart';

enum ClubSection {
  overview,
  teams,
  teamDashboard,
  roster,
  trainers,
  teamTrainers,
  playerProfile,
  matches,
  calendar,
  trainings,
  plans,
  graphics,
  videoAnalysis,
  description,
  chat,
  videoLessons,
  attendance,
  testing,
  challenges,
  challengeCreate,
  quizzes,
  quizCreate,
  rating,
  manager,
  miniGames,
  medical,
  parents,
  settings,
}

class ClubWorkspaceScreen extends StatefulWidget {
  const ClubWorkspaceScreen({super.key});

  @override
  State<ClubWorkspaceScreen> createState() => _ClubWorkspaceScreenState();
}

class _ClubWorkspaceScreenState extends State<ClubWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getClubProfileUrl = '$apiBase/get_club_profile.php';
  static const String getClubTeamsUrl = '$apiBase/get_club_teams.php';
  static const String getClubTrainersUrl = '$apiBase/get_club_trainers.php';
  static const String getTeamTrainersUrl = '$apiBase/get_team_trainers.php';
  static const String getClubEventsUrl = '$apiBase/get_club_events.php';
  static const String getPlayersUrl = '$apiBase/get_players.php';
  static const String updateClubProfileUrl = '$apiBase/update_club_profile.php';
  static const String updateTeamProfileUrl = '$apiBase/update_team_profile.php';

  int currentUserId = 0;
  int clubId = 0;

  bool loading = true;
  bool refreshing = false;
  bool loadingPlayers = false;
  String? error;

  String clubName = 'Клуб';
  String? clubLogo;
  String clubDescription = '';
  bool savingProfile = false;
  bool hasActiveSubscription = false;

  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> trainers = [];
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> players = [];

  int? selectedTeamId;
  String selectedTeamName = 'Команда не выбрана';
  Map<String, dynamic>? selectedTeam;
  Map<String, dynamic>? selectedPlayer;

  ClubSection selectedSection = ClubSection.overview;

  late final AnimationController _introController;
  bool _introStarted = false;
  bool _introFinished = false;
  bool _mobileGestureHintShown = false;

  static const List<ClubSection> _mobileSwipeSections = <ClubSection>[
    ClubSection.overview,
    ClubSection.teams,
    ClubSection.roster,
    ClubSection.calendar,
    ClubSection.trainers,
    ClubSection.matches,
    ClubSection.plans,
    ClubSection.videoAnalysis,
    ClubSection.attendance,
    ClubSection.testing,
    ClubSection.chat,
    ClubSection.graphics,
    ClubSection.manager,
    ClubSection.videoLessons,
  ];

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2650),
    );

    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _introFinished = true);
      }
    });

    _boot();
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    currentUserId = await PrefUtils.getUserId() ?? 0;
    clubId = currentUserId;
    await _loadAll(initial: true);
  }

  Future<void> _loadAll({bool initial = false}) async {
    if (!mounted) return;
    setState(() {
      if (initial) loading = true;
      refreshing = !initial;
      error = null;
    });

    await _safeLoad(_loadClubProfile);
    await _safeLoad(_loadTeams);
    await _safeLoad(_loadTrainers);
    await _safeLoad(_loadEvents);

    if (selectedTeamId == null && teams.isNotEmpty) {
      await _selectTeam(teams.first, openTeam: false);
    }

    if (!mounted) return;
    setState(() {
      loading = false;
      refreshing = false;
    });

    if (!_introStarted) {
      _introStarted = true;
      _introController.forward(from: 0);
    }
  }

  Future<void> _safeLoad(Future<void> Function() loader) async {
    try {
      await loader();
    } catch (_) {}
  }

  Future<void> _loadClubProfile() async {
    // Важно: этот экран должен работать с тем же club_id, что и старый
    // ClubDashboardScreen. Поэтому профиль клуба грузим через POST club_id
    // и НЕ перезаписываем clubId из ответа: в некоторых ответах поле id
    // может быть id записи/пользователя, из-за чего тренеры считались как 0.
    final response = await http
        .post(Uri.parse(getClubProfileUrl), body: {'club_id': clubId.toString()})
        .timeout(const Duration(seconds: 10));

    final data = _decode(response.body);
    if (data is Map && data['success'] == true) {
      final raw = data['club'] ?? data['data'] ?? data;
      if (raw is Map) {
        clubName = _asString(raw['club_name']) ??
            _asString(raw['name']) ??
            _asString(raw['title']) ??
            clubName;

        clubLogo = _asString(raw['photo']) ??
            _asString(raw['logo']) ??
            _asString(raw['logo_url']) ??
            _asString(raw['avatar']) ??
            clubLogo;

        clubDescription = _asString(raw['club_description']) ??
            _asString(raw['description']) ??
            _asString(raw['about']) ??
            clubDescription;

        hasActiveSubscription = _asBool(
          raw['subscription_active'] ??
              raw['has_subscription'] ??
              raw['is_pro'] ??
              raw['pro_active'] ??
              raw['premium_active'] ??
              raw['tariff_active'] ??
              raw['subscription_status'] ??
              raw['tariff_status'],
        );
      }
    }
  }

  Future<void> _loadTeams() async {
    final response = await http
        .post(Uri.parse(getClubTeamsUrl), body: {'club_id': clubId.toString()})
        .timeout(const Duration(seconds: 10));

    final data = _decode(response.body);

    if (data is Map && data['success'] == true && data['teams'] is List) {
      teams = List<Map<String, dynamic>>.from(
        (data['teams'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } else {
      teams = _extractList(data, keys: const ['teams', 'data', 'items']);
    }
  }

  Future<void> _loadTrainers() async {
    // 1) Сначала пробуем прямой список тренеров клуба, как в ClubTrainersScreen.
    // 2) Если сервер вместо JSON отдаёт HTML/404, берём тренеров из рабочих
    //    экранов состава: get_team_trainers.php по каждой команде клуба.
    trainers = [];

    if (clubId <= 0) {
      debugPrint('Club workspace trainers skipped: club_id is empty');
      return;
    }

    try {
      final resp = await http
          .post(
            Uri.parse(getClubTrainersUrl),
            body: {'club_id': clubId.toString()},
          )
          .timeout(const Duration(seconds: 10));

      final data = _tryDecodeJson(resp.body);
      if (data != null) {
        final list = _extractTrainersList(data);
        if (list.isNotEmpty) {
          trainers = _uniqueTrainers(list);
          debugPrint(
            'Club workspace trainers loaded from club endpoint '
            'club_id=$clubId count=${trainers.length}',
          );
          return;
        }
      } else {
        debugPrint(
          'Club workspace trainers club endpoint returned non-json '
          'club_id=$clubId status=${resp.statusCode}: ${_shortBody(resp.body)}',
        );
      }
    } catch (e) {
      debugPrint('Club workspace trainers club endpoint error club_id=$clubId: $e');
    }

    // Fallback: в team_roster_screen.dart тренеры команды грузятся именно так:
    // POST get_team_trainers.php { team_id: ... } -> trainers[]
    final byTeams = await _loadTrainersFromTeams();
    trainers = _uniqueTrainers(byTeams);
    debugPrint(
      'Club workspace trainers loaded from teams fallback '
      'club_id=$clubId teams=${teams.length} count=${trainers.length}',
    );
  }

  Future<List<Map<String, dynamic>>> _loadTrainersFromTeams() async {
    if (teams.isEmpty) return [];

    final result = <Map<String, dynamic>>[];

    for (final team in teams) {
      final teamId = _asInt(team['id'] ?? team['team_id'] ?? team['teamId']);
      if (teamId <= 0) continue;

      try {
        final resp = await http
            .post(
              Uri.parse(getTeamTrainersUrl),
              headers: const {'Content-Type': 'application/json; charset=utf-8'},
              body: jsonEncode({'team_id': teamId}),
            )
            .timeout(const Duration(seconds: 8));

        dynamic data = _tryDecodeJson(resp.body);

        // Если сервер принимает только form body, пробуем второй вариант.
        if (data == null || _extractTrainersList(data).isEmpty) {
          final formResp = await http
              .post(
                Uri.parse(getTeamTrainersUrl),
                body: {'team_id': teamId.toString()},
              )
              .timeout(const Duration(seconds: 8));
          data = _tryDecodeJson(formResp.body);
          if (data == null) {
            debugPrint(
              'Club workspace team trainers non-json '
              'team_id=$teamId status=${formResp.statusCode}: ${_shortBody(formResp.body)}',
            );
          }
        }

        final list = _extractTrainersList(data);
        for (final t in list) {
          final item = Map<String, dynamic>.from(t);
          item['team_id'] = item['team_id'] ?? teamId;
          item['teamId'] = item['teamId'] ?? teamId;
          item['team_name'] = item['team_name'] ??
              item['teamName'] ??
              _asString(team['name']) ??
              _asString(team['team_name']) ??
              _asString(team['title']) ??
              'Команда';
          result.add(item);
        }
      } catch (e) {
        debugPrint('Club workspace team trainers error team_id=$teamId: $e');
      }
    }

    return result;
  }

  List<Map<String, dynamic>> _uniqueTrainers(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    for (final raw in list) {
      final item = Map<String, dynamic>.from(raw);
      final key = _trainerUniqueKey(item);
      if (seen.add(key)) out.add(item);
    }

    return out;
  }

  String _trainerUniqueKey(Map<String, dynamic> t) {
    final id = _asInt(
      t['trainer_id'] ??
          t['trainerId'] ??
          t['coach_id'] ??
          t['coachId'] ??
          t['user_id'] ??
          t['userId'] ??
          t['id'],
    );
    if (id > 0) return 'id:$id';

    final email = (_asString(t['email']) ?? '').trim().toLowerCase();
    if (email.isNotEmpty) return 'email:$email';

    final name = [
      _asString(t['first_name']),
      _asString(t['last_name']),
      _asString(t['name']),
      _asString(t['full_name']),
    ].whereType<String>().join('|').trim().toLowerCase();
    return name.isNotEmpty ? 'name:$name' : 'raw:${jsonEncode(t)}';
  }

  Future<void> _loadEvents() async {
    final response = await http
        .get(Uri.parse('$getClubEventsUrl?club_id=$clubId'))
        .timeout(const Duration(seconds: 10));
    events = _extractList(
      _decode(response.body),
      keys: const ['events', 'data', 'items'],
    );
  }

  Future<void> _loadPlayersForTeam(int teamId) async {
    if (!mounted) return;

    setState(() {
      loadingPlayers = true;
      players = [];
      selectedPlayer = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(getPlayersUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'team_id': teamId}),
          )
          .timeout(const Duration(seconds: 12));

      debugPrint('Club workspace get_players JSON team_id=$teamId');
      debugPrint('Club workspace get_players response=${response.body}');

      final data = jsonDecode(response.body);
      final ok = data is Map &&
          (data['status'] == 'success' || data['success'] == true);
      final loaded = ok
          ? List<Map<String, dynamic>>.from(data['players'] ?? []).map((p) {
              p['team_id'] = teamId;
              p['teamId'] = teamId;
              p['club_id'] = clubId;
              p['clubId'] = clubId;
              p['team_name'] = selectedTeamName;
              p['teamName'] = selectedTeamName;
              return p;
            }).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        players = loaded;
        selectedPlayer = loaded.isNotEmpty ? loaded.first : null;
        loadingPlayers = false;
      });

      // Если игроков нет, не показываем всплывающие окна — пустое состояние есть в списке.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        players = [];
        selectedPlayer = null;
        loadingPlayers = false;
      });
      debugPrint('Club workspace players load error: $e');
    }
  }

  Future<void> _selectTeam(Map<String, dynamic> team,
      {bool openTeam = false}) async {
    final id = _asInt(
        team['id'] ?? team['team_id'] ?? team['teamId'] ?? team['teamID']);

    if (!mounted) return;

    setState(() {
      selectedTeam = team;
      selectedTeamId = id;
      selectedTeamName = _asString(team['name']) ??
          _asString(team['team_name']) ??
          _asString(team['title']) ??
          'Команда';

      // После выбора активной команды автоматически возвращаемся
      // в основную панель клуба. Если где-то явно нужен полный экран
      // команды, передавай openTeam: true.
      selectedSection = openTeam ? ClubSection.teamDashboard : ClubSection.overview;
    });

    if (id > 0) {
      await _loadPlayersForTeam(id);
      if (mounted) {
        Get.snackbar('Команда активна', selectedTeamName);
      }
    } else {
      Get.snackbar('Команда', 'У выбранной команды нет корректного ID');
    }
  }


  String _selectedTeamStage() {
    return _stageFromTeam(selectedTeam, fallbackName: selectedTeamName) ?? 'U13';
  }

  String? _stageFromTeam(Map<String, dynamic>? team, {String? fallbackName}) {
    final values = <String>[];
    if (team != null) {
      for (final key in const [
        'stage',
        'stage_code',
        'stageCode',
        'age_group',
        'ageGroup',
        'age',
        'team_age',
        'teamAge',
        'category',
        'sport_category',
        'name',
        'team_name',
        'title',
      ]) {
        final v = _asString(team[key]);
        if (v != null && v.trim().isNotEmpty) values.add(v);
      }
    }
    if (fallbackName != null && fallbackName.trim().isNotEmpty) values.add(fallbackName);

    for (final raw in values) {
      final stage = _normalizeStage(raw);
      if (stage != null) return stage;
    }
    return null;
  }

  String? _normalizeStage(String raw) {
    final t = raw.trim().toUpperCase().replaceAll(' ', '');
    final u = RegExp(r'U-?([0-9]{1,2})').firstMatch(t);
    if (u != null) {
      final n = int.tryParse(u.group(1)!);
      if (n != null && n >= 6 && n <= 17) return 'U$n';
    }

    final years = RegExp(r'(^|[^0-9])([6-9]|1[0-7])([^0-9]|$)').firstMatch(t);
    if (years != null) {
      final n = int.tryParse(years.group(2)!);
      if (n != null && n >= 6 && n <= 17) return 'U$n';
    }

    switch (t) {
      case 'МЯЧ':
        return 'U6';
      case 'МЯЧ+ВОРОТА':
      case 'М+ВОРОТА':
      case 'МВ':
        return 'U7';
      case 'МЯЧ+ВОРОТА+СОПЕРНИК':
      case 'М+В+СОПЕРНИК':
      case 'МВС':
        return 'U8';
      case 'МЯЧ+ВОРОТА+СОПЕРНИК+ПАРТНЕР':
      case 'МЯЧ+ВОРОТА+СОПЕРНИК+ПАРТНЁР':
      case 'М+В+С+ПАРТНЕР':
      case 'М+В+С+ПАРТНЁР':
      case 'МВСП':
        return 'U9';
    }
    return null;
  }

  Map<String, dynamic> _playerArgs(Map<String, dynamic> player) {
    final mp = Map<String, dynamic>.from(player);

    mp['team_id'] = selectedTeamId ?? mp['team_id'] ?? mp['teamId'];
    mp['teamId'] = selectedTeamId ?? mp['teamId'] ?? mp['team_id'];
    mp['club_id'] = clubId;
    mp['clubId'] = clubId;
    mp['team_name'] = selectedTeamName;
    mp['teamName'] = selectedTeamName;

    return mp;
  }

  void _openPlayer(Map<String, dynamic> player) {
    final mp = _playerArgs(player);

    setState(() {
      selectedPlayer = mp;
      selectedSection = ClubSection.roster;
    });
  }

  void _openPlayerProfile(Map<String, dynamic> player) {
    final mp = _playerArgs(player);

    setState(() {
      selectedPlayer = mp;
    });

    Get.toNamed(
      AppRoutes.playerProfileScreen,
      arguments: mp,
    );
  }


  Future<void> _openEditClubDialog() async {
    final nameCtrl = TextEditingController(text: clubName);
    final descCtrl = TextEditingController(text: clubDescription);
    XFile? pickedLogo;
    final picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 14,
                  bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Редактирование клуба',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _C.text,
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final x = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                          maxWidth: 1400,
                        );
                        if (x != null) setSheetState(() => pickedLogo = x);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _C.soft,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _C.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              backgroundImage: pickedLogo != null
                                  ? FileImage(File(pickedLogo!.path))
                                  : (clubLogo != null && clubLogo!.isNotEmpty
                                      ? NetworkImage(clubLogo!) as ImageProvider
                                      : null),
                              child: pickedLogo == null &&
                                      (clubLogo == null || clubLogo!.isEmpty)
                                  ? const Icon(Icons.shield_rounded,
                                      color: _C.primaryGreen)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Логотип клуба',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: _C.text)),
                                  SizedBox(height: 3),
                                  Text('Нажмите, чтобы заменить изображение',
                                      style: TextStyle(
                                          color: _C.muted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_rounded, color: _C.primaryGreen),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Название клуба',
                        filled: true,
                        fillColor: _C.soft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Описание клуба',
                        filled: true,
                        fillColor: _C.soft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: savingProfile
                          ? null
                          : () async {
                              await _saveClubProfile(
                                name: nameCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                logo: pickedLogo,
                              );
                              if (mounted) Navigator.pop(context);
                            },
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: const Text('Сохранить',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.primaryGreen,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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

  Future<void> _saveClubProfile({
    required String name,
    required String description,
    XFile? logo,
  }) async {
    if (name.isEmpty) {
      Get.snackbar('Клуб', 'Введите название клуба');
      return;
    }
    if (!mounted) return;
    setState(() => savingProfile = true);
    try {
      final req = http.MultipartRequest('POST', Uri.parse(updateClubProfileUrl));
      req.fields['club_id'] = clubId.toString();
      req.fields['club_name'] = name;
      req.fields['name'] = name;
      req.fields['club_description'] = description;
      req.fields['description'] = description;
      if (logo != null) {
        req.files.add(await http.MultipartFile.fromPath('club_logo', logo.path));
      }
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp.body);
      final ok = data is Map && (data['success'] == true || data['status'] == 'success');
      if (ok) {
        final raw = data is Map ? (data['club'] ?? data['data']) : null;
        setState(() {
          clubName = name;
          clubDescription = description;
          if (raw is Map) {
            clubLogo = _asString(raw['logo']) ??
                _asString(raw['logo_url']) ??
                _asString(raw['photo']) ??
                _asString(raw['avatar']) ??
                clubLogo;
          }
        });
        await _loadClubProfile();
        Get.snackbar('Готово', 'Данные клуба обновлены');
      } else {
        Get.snackbar('Ошибка', data is Map ? '${data['message'] ?? data['error'] ?? 'Не удалось сохранить'}' : 'Не удалось сохранить');
      }
    } catch (e) {
      Get.snackbar('Сеть', 'Ошибка сохранения: $e');
    } finally {
      if (mounted) setState(() => savingProfile = false);
    }
  }

  Future<void> _openEditTeamDialog() async {
    if (!_hasTeam || selectedTeam == null) {
      Get.snackbar('Команда', 'Сначала выберите команду');
      return;
    }

    final nameCtrl = TextEditingController(text: selectedTeamName);
    final categoryCtrl = TextEditingController(
      text: _asString(selectedTeam?['category'] ?? selectedTeam?['sport'] ?? selectedTeam?['age_group']) ?? 'Футбол',
    );
    final oldLogo = _asString(selectedTeam?['logo'] ?? selectedTeam?['logo_url'] ?? selectedTeam?['photo']);
    XFile? pickedLogo;
    final picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 14,
                  bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        _IconBadge(icon: Icons.tune_rounded, size: 46, iconSize: 23),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Редактирование команды',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _C.text)),
                              SizedBox(height: 3),
                              Text('Название, категория и логотип команды',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _C.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final x = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                          maxWidth: 1400,
                        );
                        if (x != null) setSheetState(() => pickedLogo = x);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _C.soft,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _C.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              backgroundImage: pickedLogo != null
                                  ? FileImage(File(pickedLogo!.path))
                                  : (oldLogo != null && oldLogo.isNotEmpty
                                      ? NetworkImage(oldLogo) as ImageProvider
                                      : null),
                              child: pickedLogo == null &&
                                      (oldLogo == null || oldLogo.isEmpty)
                                  ? const Icon(Icons.groups_2_rounded,
                                      color: _C.primaryGreen)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Логотип команды',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: _C.text)),
                                  SizedBox(height: 3),
                                  Text('Нажмите, чтобы заменить изображение',
                                      style: TextStyle(
                                          color: _C.muted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_rounded, color: _C.primaryGreen),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Название команды',
                        filled: true,
                        fillColor: _C.soft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: categoryCtrl,
                      decoration: InputDecoration(
                        labelText: 'Категория / вид спорта',
                        filled: true,
                        fillColor: _C.soft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: savingProfile
                          ? null
                          : () async {
                              await _saveSelectedTeamProfile(
                                name: nameCtrl.text.trim(),
                                category: categoryCtrl.text.trim(),
                                logo: pickedLogo,
                              );
                              if (mounted) Navigator.pop(context);
                            },
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: const Text('Сохранить',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.primaryGreen,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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

  Future<void> _saveSelectedTeamProfile({
    required String name,
    required String category,
    XFile? logo,
  }) async {
    if (!_hasTeam) return;
    if (name.isEmpty) {
      Get.snackbar('Команда', 'Введите название команды');
      return;
    }
    if (!mounted) return;
    setState(() => savingProfile = true);
    try {
      final req = http.MultipartRequest('POST', Uri.parse(updateTeamProfileUrl));
      req.fields['team_id'] = selectedTeamId.toString();
      req.fields['team_name'] = name;
      req.fields['name'] = name;
      req.fields['category'] = category.isEmpty ? 'Футбол' : category;
      if (logo != null) {
        req.files.add(await http.MultipartFile.fromPath('logo', logo.path));
      }
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp.body);
      final ok = data is Map && (data['success'] == true || data['status'] == 'success');
      if (ok) {
        setState(() {
          selectedTeamName = name;
          selectedTeam = {
            ...?selectedTeam,
            'name': name,
            'team_name': name,
            'category': category.isEmpty ? 'Футбол' : category,
          };
        });
        await _loadTeams();
        if (selectedTeamId != null && selectedTeamId! > 0) {
          await _loadPlayersForTeam(selectedTeamId!);
        }
        Get.snackbar('Готово', 'Данные команды обновлены');
      } else {
        Get.snackbar('Ошибка', data is Map ? '${data['message'] ?? data['error'] ?? 'Не удалось сохранить'}' : 'Не удалось сохранить');
      }
    } catch (e) {
      Get.snackbar('Сеть', 'Ошибка сохранения: $e');
    } finally {
      if (mounted) setState(() => savingProfile = false);
    }
  }

  void _openGameModule(ClubSection section) {
    final isGameSection = section == ClubSection.challengeCreate ||
        section == ClubSection.challenges ||
        section == ClubSection.quizCreate ||
        section == ClubSection.quizzes ||
        section == ClubSection.rating ||
        section == ClubSection.miniGames ||
        section == ClubSection.manager;

    if (isGameSection && !_hasTeam) {
      Get.snackbar('Команда', 'Сначала выберите команду');
      return;
    }

    final args = {
      'team_id': selectedTeamId,
      'teamId': selectedTeamId,
      'user_id': currentUserId,
      'team_name': selectedTeamName,
    };

    switch (section) {
      case ClubSection.challengeCreate:
        Get.to(() => const CreateChallengeScreen(), arguments: args);
        break;
      case ClubSection.quizCreate:
        Get.to(() => const CreateQuizScreen(), arguments: args);
        break;
      case ClubSection.manager:
        Get.to(() => ManagerDashboardScreen(
              teamId: selectedTeamId!,
              userId: currentUserId,
              teamName: selectedTeamName,
            ));
        break;
      case ClubSection.challenges:
      case ClubSection.quizzes:
      case ClubSection.rating:
      case ClubSection.miniGames:
        setState(() => selectedSection = section);
        break;
      default:
        setState(() => selectedSection = section);
    }
  }

  void _openCreateTeam() async {
    await Get.toNamed(AppRoutes.createTeamScreen);
    _loadAll();
  }

  void _openFullTeamDashboard() {
    if (!_hasTeam) return;
    Get.to(() => TeamDashboardScreen(
          teamId: selectedTeamId!,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        ));
  }

  Future<void> _openFullModulesMenu() async {
    final section = await showGeneralDialog<ClubSection>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть меню',
      barrierColor: Colors.black.withOpacity(.28),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _FullModulesMenuOverlay(
          clubName: clubName,
          clubLogo: clubLogo,
          selectedTeamName: selectedTeamName,
          selectedSection: selectedSection,
          items: _fullMenuItems,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: Transform.scale(
            scale: .975 + (.025 * curved.value),
            child: child,
          ),
        );
      },
    );

    if (section == null || !mounted) return;

    if (section == ClubSection.challengeCreate || section == ClubSection.quizCreate) {
      _openGameModule(section);
      return;
    }

    setState(() => selectedSection = section);
  }

  List<_FullMenuItem> get _fullMenuItems => const [
        _FullMenuItem(ClubSection.overview, Icons.space_dashboard_rounded, 'Обзор', 'Клуб, команды, тренеры'),
        _FullMenuItem(ClubSection.teams, Icons.account_tree_rounded, 'Команды', 'Выбор и создание команд'),
        _FullMenuItem(ClubSection.roster, Icons.groups_2_rounded, 'Состав', 'Игроки и профили'),
        _FullMenuItem(ClubSection.trainers, Icons.badge_rounded, 'Тренеры', 'Специалисты клуба'),
        _FullMenuItem(ClubSection.matches, Icons.sports_soccer_rounded, 'Матчи', 'Игры и результаты'),
        _FullMenuItem(ClubSection.calendar, Icons.calendar_month_rounded, 'Календарь', 'Тренировки и события'),
        _FullMenuItem(ClubSection.attendance, Icons.fact_check_rounded, 'Посещаемость', 'Журнал занятий'),
        _FullMenuItem(ClubSection.testing, Icons.science_rounded, 'Тестирование', 'Физика, техника, тактика'),
        _FullMenuItem(ClubSection.plans, Icons.folder_copy_rounded, 'Планы', 'Конспекты тренера'),
        _FullMenuItem(ClubSection.graphics, Icons.draw_rounded, 'Графика', 'Схемы и упражнения'),
        _FullMenuItem(ClubSection.videoAnalysis, Icons.analytics_rounded, 'Видеоанализ', 'AI, ТТД и статистика'),
        _FullMenuItem(ClubSection.chat, Icons.forum_rounded, 'Чаты', 'Командное общение'),
        _FullMenuItem(ClubSection.videoLessons, Icons.video_library_rounded, 'Видеоуроки', 'Материалы тренеров'),
        _FullMenuItem(ClubSection.miniGames, Icons.videogame_asset_rounded, 'Игровая зона', 'Задания, квизы и рейтинг'),
        _FullMenuItem(ClubSection.manager, Icons.psychology_alt_rounded, 'Менеджер', 'Тактика и состав'),
        _FullMenuItem(ClubSection.medical, Icons.medical_information_rounded, 'Медкарта', 'Состояние игроков'),
        _FullMenuItem(ClubSection.parents, Icons.family_restroom_rounded, 'Родители', 'Доступы и связь'),
        _FullMenuItem(ClubSection.settings, Icons.tune_rounded, 'Настройки', 'Права и модули'),
      ];


  void _openFullRosterScreen() {
    if (!_hasTeam) return;
    Get.to(() =>
        TeamRosterScreen(teamId: selectedTeamId!, teamName: selectedTeamName));
  }

  void _openFullMatches() {
    if (!_hasTeam) return;
    Get.to(() => const TeamMatchesScreen(), arguments: {
      'teamId': selectedTeamId,
      'teamName': selectedTeamName,
    });
  }

  void _openFullCalendar() {
    if (!_hasTeam) return;
    Get.to(() =>
        TeamCalendarScreen(teamId: selectedTeamId!, teamName: selectedTeamName));
  }

  void _openFullPlans() {
    Get.to(() => PlanFoldersScreen(
          clubId: clubId,
          clubName: clubName,
          teamId: selectedTeamId,
          selectMode: false,
          browsePlansMode: false,
        ));
  }

  void _openFullGraphics() {
    Get.to(() => TrainingGraphicsScreen(
          teamId: selectedTeamId,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        ));
  }

  void _openFullVideoAnalysis() {
    if (!_hasTeam) return;
    Get.to(() => TeamVideoAnalysisScreen(
          teamId: selectedTeamId!,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        ));
  }

  void _openFullTeamDescription() {
    if (!_hasTeam) return;
    Get.to(() => const TeamDescriptionScreen(), arguments: selectedTeamId);
  }

  void _openFullChat() {
    final userId = currentUserId > 0 ? currentUserId : clubId;
    Get.to(() => ChatScreen(userId: userId));
  }

  void _openFullVideoLessons() {
    final userId = currentUserId > 0 ? currentUserId : clubId;
    Get.to(() => VideoLessonsScreen(
          ownerUserId: userId,
          ownerName: clubName,
          isMyMode: true,
          embedded: false,
        ));
  }

  bool get _hasTeam => selectedTeamId != null && selectedTeamId! > 0;

  dynamic _decode(String body) {
    final data = _tryDecodeJson(body);
    if (data != null) return data;
    return <String, dynamic>{};
  }

  dynamic _tryDecodeJson(String body) {
    final raw = body.trim();
    if (raw.isEmpty) return null;

    // Быстрый отсев HTML-ответов: 404, PHP warning page, редирект и т.п.
    final lower = raw.length > 80 ? raw.substring(0, 80).toLowerCase() : raw.toLowerCase();
    if (lower.startsWith('<!doctype') || lower.startsWith('<html')) {
      return null;
    }

    try {
      return jsonDecode(raw);
    } catch (_) {
      // Иногда сервер добавляет warning/notice до или после JSON.
      final startObj = raw.indexOf('{');
      final startArr = raw.indexOf('[');
      final starts = [startObj, startArr].where((e) => e >= 0).toList();
      if (starts.isEmpty) return null;

      final start = starts.reduce(math.min);
      final startedWithObject = start == startObj || startArr < 0;
      final end = startedWithObject ? raw.lastIndexOf('}') : raw.lastIndexOf(']');
      if (end <= start) return null;

      final sliced = raw.substring(start, end + 1).trim();
      try {
        return jsonDecode(sliced);
      } catch (_) {
        return null;
      }
    }
  }

  String _shortBody(String body, {int max = 180}) {
    final oneLine = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= max) return oneLine;
    return '${oneLine.substring(0, max)}…';
  }

  List<Map<String, dynamic>> _extractList(dynamic data,
      {required List<String> keys}) {
    dynamic raw = data;
    if (data is Map) {
      for (final key in keys) {
        if (data[key] is List) {
          raw = data[key];
          break;
        }
      }
    }
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _extractTrainersList(dynamic data) {
    // Основной рабочий формат: { success: true, trainers: [...] }
    final direct = _extractList(
      data,
      keys: const ['trainers', 'coaches', 'users', 'items', 'data', 'result'],
    );
    if (direct.isNotEmpty) return direct;

    // Частые вложенные форматы: { data: { trainers: [...] } }
    if (data is Map) {
      for (final key in const ['data', 'result', 'response', 'payload']) {
        final nested = data[key];
        if (nested is Map) {
          final list = _extractList(
            nested,
            keys: const ['trainers', 'coaches', 'users', 'items', 'data'],
          );
          if (list.isNotEmpty) return list;
        }
      }
    }

    return [];
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  String? _asString(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value > 0;
    final text = '${value ?? ''}'.trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'active' ||
        text == 'paid' ||
        text == 'pro' ||
        text == 'premium' ||
        text == 'активна';
  }

  bool _isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return math.min(size.width, size.height) >= 600;
  }

  bool _isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return baseSize * 0.7;
    if (width < 400) return baseSize * 0.8;
    if (width < 600) return baseSize * 0.9;
    if (width < 900) return baseSize * 0.95;
    return baseSize;
  }

  double _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 10.0;
    if (width < 400) return 12.0;
    if (width < 600) return 14.0;
    return 16.0;
  }

  void _handleWorkspaceBack() {
    if (selectedSection != ClubSection.overview) {
      setState(() => selectedSection = ClubSection.overview);
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tablet = _isTablet(context);
    final landscape = _isLandscape(context);

    if (loading) {
      return const Scaffold(
        backgroundColor: _C.bg,
        body: Center(child: CircularProgressIndicator(color: _C.primaryGreen)),
      );
    }

    if (tablet && !landscape) {
      return _RotateTabletHint(clubName: clubName, clubLogo: clubLogo);
    }

    if (tablet && landscape) return _buildWorkspace();
    return _buildMobileVersion();
  }

  Widget _buildMobileVersion() {
    _scheduleMobileGestureHint();

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        top: true,
        bottom: false,
        child: _buildMobileSwipeShell(),
      ),
      bottomNavigationBar: _buildMobileBottomNav(),
    );
  }

  Widget _buildMobileSwipeShell() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 260) return;

        if (velocity < 0) {
          _goToNextMobileSection();
        } else {
          _goToPreviousMobileSection();
        }
      },
      child: _buildMobileContent(),
    );
  }

  void _goToNextMobileSection() {
    final index = _mobileSwipeSections.indexOf(selectedSection);
    if (index < 0) {
      setState(() => selectedSection = ClubSection.overview);
      return;
    }

    final nextIndex = (index + 1).clamp(0, _mobileSwipeSections.length - 1).toInt();
    if (nextIndex == index) return;
    setState(() => selectedSection = _mobileSwipeSections[nextIndex]);
  }

  void _goToPreviousMobileSection() {
    final index = _mobileSwipeSections.indexOf(selectedSection);
    if (index < 0) {
      setState(() => selectedSection = ClubSection.overview);
      return;
    }

    final previousIndex = (index - 1).clamp(0, _mobileSwipeSections.length - 1).toInt();
    if (previousIndex == index) return;
    setState(() => selectedSection = _mobileSwipeSections[previousIndex]);
  }

  void _scheduleMobileGestureHint() {
    if (_mobileGestureHintShown) return;
    _mobileGestureHintShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isTablet(context)) return;
      _showMobileGestureHint();
    });
  }

  void _showMobileGestureHint() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MobileGestureHintSheet(),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    final fontSize = _getResponsiveFontSize(context, 18);
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 58,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: _BackCircleButton(onTap: _handleWorkspaceBack),
        ),
      ),
      title: Text(
        'Кабинет клуба',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: _C.text,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: () => _loadAll(),
          icon: Icon(Icons.refresh_rounded,
              size: _getResponsiveFontSize(context, 24)),
          tooltip: 'Обновить',
        ),
      ],
    );
  }


  Widget _buildCmrGameZone({CmrGameZoneMode mode = CmrGameZoneMode.all}) {
    return _TeamGuard(
      hasTeam: _hasTeam,
      child: CmrGameZonePanel(
        clubId: clubId,
        clubName: clubName,
        teamId: selectedTeamId!,
        teamName: selectedTeamName,
        userId: currentUserId,
        initialMode: mode,
      ),
    );
  }

  Widget _buildMobileContent() {
    final padding = _getResponsivePadding(context);
    final fontSize = _getResponsiveFontSize(context, 16);

    switch (selectedSection) {
      case ClubSection.overview:
        return _MobileOverview(padding: padding, fontSize: fontSize);
      case ClubSection.teams:
        return _MobileTeams(padding: padding, fontSize: fontSize);
      case ClubSection.roster:
        return _MobileRoster(padding: padding, fontSize: fontSize);
      case ClubSection.trainers:
      case ClubSection.teamTrainers:
        return CmrClubTrainersPanel(
          clubId: clubId,
          clubName: clubName,
          teams: teams,
          selectedTeamId: selectedTeamId,
          selectedTeamName: selectedTeamName,
          onChanged: () async {
            await _safeLoad(_loadTrainers);
            if (mounted) setState(() {});
          },
          onOpenTeams: () => setState(() => selectedSection = ClubSection.teams),
          onOpenRoster: () => setState(() => selectedSection = ClubSection.roster),
        );
      case ClubSection.matches:
        if (!_hasTeam) return const _NeedTeam();
        return CmrTeamMatchesPanel(
          teamId: selectedTeamId!,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        );
      case ClubSection.calendar:
        if (!_hasTeam) return const _NeedTeam();
        return CmrCalendarPanel(
          teamId: selectedTeamId!,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        );
      case ClubSection.trainings:
        return _MobileTrainings(padding: padding, fontSize: fontSize);
      case ClubSection.plans:
        if (!_hasTeam) return const _NeedTeam();
        return CmrPlansPanel(
          clubId: clubId,
          clubName: clubName,
          teamId: selectedTeamId,
          teamName: selectedTeamName,
        );
      case ClubSection.videoAnalysis:
        if (!_hasTeam) return const _NeedTeam();
        return CmrVideoAnalysisPanel(
          teamId: selectedTeamId!,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        );
      case ClubSection.attendance:
        if (!_hasTeam) return const _NeedTeam();
        return CmrAttendancePanel(
          teamId: selectedTeamId!,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        );
      case ClubSection.testing:
        if (!_hasTeam) return const _NeedTeam();
        return CmrTestingPanel(
          clubId: clubId,
          teamId: selectedTeamId!,
          clubName: clubName,
          teamName: selectedTeamName,
          initialStage: _selectedTeamStage(),
          userId: currentUserId,
        );

      case ClubSection.challenges:
        return _buildCmrGameZone(mode: CmrGameZoneMode.challenges);
      case ClubSection.challengeCreate:
        _openGameModule(ClubSection.challengeCreate);
        return const _NeedTeam();
      case ClubSection.quizzes:
        return _buildCmrGameZone(mode: CmrGameZoneMode.quizzes);
      case ClubSection.quizCreate:
        _openGameModule(ClubSection.quizCreate);
        return const _NeedTeam();
      case ClubSection.rating:
        return _buildCmrGameZone(mode: CmrGameZoneMode.rating);
      case ClubSection.manager:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Менеджер команды',
          subtitle: 'Тактика, состав, игровые сценарии и симуляция матчей.',
          icon: Icons.psychology_alt_rounded,
          primaryText: 'Открыть менеджер',
          onPrimary: () => _openGameModule(ClubSection.manager),
        );
      case ClubSection.miniGames:
        return _buildCmrGameZone();
      case ClubSection.chat:
        final userId = currentUserId > 0 ? currentUserId : clubId;
        if (userId <= 0) {
          return const _SolidPlaceholder(
            icon: Icons.forum_rounded,
            title: 'Чаты недоступны',
            subtitle: 'Не удалось определить пользователя для загрузки чатов.',
            chips: ['Личные', 'Группы', 'Команда'],
          );
        }
        return CmrChatsPanel(
          userId: userId,
          clubName: clubName,
          teamId: selectedTeamId,
          teamName: selectedTeamName,
        );
      case ClubSection.graphics:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Графический редактор',
          subtitle:
              'Тактические схемы, упражнения и визуальные конспекты.',
          icon: Icons.draw_rounded,
          primaryText: 'Открыть редактор',
          onPrimary: _openFullGraphics,
        );
      case ClubSection.description:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Визитка команды',
          subtitle: 'Описание команды, публичная информация.',
          icon: Icons.article_rounded,
          primaryText: 'Открыть визитку',
          onPrimary: _openFullTeamDescription,
        );
      case ClubSection.videoLessons:
        return _TeamModulePanel(
          hasTeam: true,
          title: 'Видеоуроки',
          subtitle: 'Обучающие материалы и видео.',
          icon: Icons.video_library_rounded,
          primaryText: 'Открыть видеоуроки',
          onPrimary: _openFullVideoLessons,
        );
      default:
        return const _SolidPlaceholder(
          icon: Icons.construction_rounded,
          title: 'В разработке',
          subtitle: 'Этот раздел оптимизируется для мобильной версии.',
          chips: ['Клуб', 'Мобайл', 'Планшет'],
        );
    }
  }

  Widget _MobileOverview({required double padding, required double fontSize}) {
    return RefreshIndicator(
      onRefresh: () => _loadAll(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMobileBanner(fontSize),
            SizedBox(height: padding),
            _buildMobileStatsRow(fontSize),
            SizedBox(height: padding),
            _buildMobileCompletenessCard(fontSize),
            SizedBox(height: padding),
            _buildMobileTeamInfo(fontSize),
            SizedBox(height: padding),
            _buildMobileQuickActions(fontSize),
            SizedBox(height: padding),
            _buildMobileEvents(fontSize),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBanner(double fontSize) {
    return Container(
      padding: EdgeInsets.all(fontSize * 1.2),
      decoration: _mobileCardDecoration(radius: 20),
      child: Column(
        children: [
          if (clubLogo != null && clubLogo!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                clubLogo!,
                height: 72,
                width: 72,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: _C.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: _C.primaryGreen,
                    size: 36,
                  ),
                ),
              ),
            ),
          SizedBox(height: fontSize * 0.8),
          Text(
            clubName,
            style: TextStyle(
              fontSize: fontSize * 1.4,
              fontWeight: FontWeight.w900,
              color: _C.text,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: fontSize * 0.4),
          Text(
            'Рабочий кабинет клуба',
            style: TextStyle(
              fontSize: fontSize * 0.85,
              color: _C.muted,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (clubDescription.trim().isNotEmpty) ...[
            SizedBox(height: fontSize * 0.45),
            Text(
              clubDescription.trim(),
              style: TextStyle(
                fontSize: fontSize * 0.78,
                color: _C.muted,
                height: 1.32,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: fontSize * 0.8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallActionChip(
                icon: Icons.edit_rounded,
                label: 'Редактировать клуб',
                onTap: _openEditClubDialog,
              ),
              _SmallActionChip(
                icon: Icons.image_rounded,
                label: 'Логотип',
                onTap: _openEditClubDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCompletenessCard(double fontSize) {
    final items = <String>[];

    if (clubDescription.trim().isEmpty) items.add('Описание клуба');
    if (clubLogo == null || clubLogo!.trim().isEmpty) items.add('Логотип клуба');
    if (teams.isEmpty) items.add('Команды');
    if (trainers.isEmpty) items.add('Тренеры');
    if (selectedTeamId == null || selectedTeamId! <= 0) items.add('Активная команда');
    if (players.isEmpty) items.add('Игроки активной команды');
    if (events.isEmpty) items.add('События клуба');

    return Container(
      padding: EdgeInsets.all(fontSize),
      decoration: _mobileCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: _C.primaryGreen, size: 22),
              SizedBox(width: fontSize * 0.5),
              Expanded(
                child: Text(
                  items.isEmpty ? 'Профиль клуба заполнен' : 'Что желательно заполнить',
                  style: TextStyle(
                    fontSize: fontSize * 1.02,
                    fontWeight: FontWeight.w900,
                    color: _C.text,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: fontSize * 0.55),
          Text(
            items.isEmpty
                ? 'Основные данные выглядят аккуратно. Можно переходить к работе с командой.'
                : 'Эти пункты помогут сделать экран клуба понятнее для тренеров, игроков и родителей.',
            style: TextStyle(
              color: _C.muted,
              fontSize: fontSize * 0.78,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: fontSize * 0.7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (items.isEmpty ? ['Готово'] : items).map((item) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: fontSize * 0.65,
                  vertical: fontSize * 0.42,
                ),
                decoration: BoxDecoration(
                  color: items.isEmpty ? _C.primaryGreen.withOpacity(0.1) : _C.soft2,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: items.isEmpty ? _C.primaryGreen.withOpacity(0.25) : _C.border,
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    color: items.isEmpty ? _C.primaryGreen : _C.text,
                    fontSize: fontSize * 0.72,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatsRow(double fontSize) {
    return Container(
      padding: EdgeInsets.all(fontSize * 0.8),
      decoration: _mobileCardDecoration(radius: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _buildMobileStat(
            value: '${teams.length}',
            label: 'Команды',
            icon: Icons.account_tree_rounded,
            color: _C.blue,
            fontSize: fontSize,
          )),
          Expanded(child: _buildMobileStat(
            value: '${players.length}',
            label: 'Игроки',
            icon: Icons.groups_2_rounded,
            color: _C.primaryGreen,
            fontSize: fontSize,
          )),
          Expanded(child: _buildMobileStat(
            value: '${trainers.length}',
            label: 'Тренеры',
            icon: Icons.badge_rounded,
            color: _C.purple,
            fontSize: fontSize,
          )),
          Expanded(child: _buildMobileStat(
            value: '${events.length}',
            label: 'События',
            icon: Icons.event_available_rounded,
            color: _C.orange,
            fontSize: fontSize,
          )),
        ],
      ),
    );
  }

  Widget _buildMobileStat({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required double fontSize,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: fontSize * 0.3),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize * 1.2,
            fontWeight: FontWeight.w900,
            color: _C.text,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize * 0.7,
            color: _C.muted,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMobileTeamInfo(double fontSize) {
    return Container(
      padding: EdgeInsets.all(fontSize),
      decoration: _mobileCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: _C.footballGreen, size: 22),
              SizedBox(width: fontSize * 0.5),
              Text(
                'Активная команда',
                style: TextStyle(
                  fontSize: fontSize * 1.1,
                  fontWeight: FontWeight.w900,
                  color: _C.text,
                ),
              ),
            ],
          ),
          SizedBox(height: fontSize * 0.6),
          Container(
            padding: EdgeInsets.all(fontSize * 0.6),
            decoration: BoxDecoration(
              color: _C.footballGreenSoft,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: _C.footballGreen.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedTeamName,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: _C.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: fontSize * 0.5),
                Text(
                  '${players.length} игроков',
                  style: TextStyle(
                    fontSize: fontSize * 0.8,
                    color: _C.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: fontSize * 0.8),
          Row(
            children: [
              Expanded(
                child: _MobileActionButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Сменить',
                  onTap: () =>
                      setState(() => selectedSection = ClubSection.teams),
                  fontSize: fontSize,
                ),
              ),
              SizedBox(width: fontSize * 0.5),
              Expanded(
                child: _MobileActionButton(
                  icon: Icons.groups_2_rounded,
                  label: 'Состав',
                  onTap: () =>
                      setState(() => selectedSection = ClubSection.roster),
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _MobileActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double fontSize,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: fontSize * 0.55,
          horizontal: fontSize * 0.65,
        ),
        decoration: BoxDecoration(
          color: _C.primaryGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF374151), size: fontSize),
            SizedBox(width: fontSize * 0.25),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize * 0.78,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileQuickActions(double fontSize) {
    final actions = [
      {
        'icon': Icons.badge_rounded,
        'label': 'Тренеры',
        'section': ClubSection.trainers,
        'color': _C.purple,
      },
      {
        'icon': Icons.sports_soccer_rounded,
        'label': 'Матчи',
        'section': ClubSection.matches,
        'color': _C.orange,
      },
      {
        'icon': Icons.calendar_month_rounded,
        'label': 'Календарь',
        'section': ClubSection.calendar,
        'color': _C.teal,
      },
      {
        'icon': Icons.folder_copy_rounded,
        'label': 'Планы',
        'section': ClubSection.plans,
        'color': _C.blue,
      },
      {
        'icon': Icons.analytics_rounded,
        'label': 'Видеоанализ',
        'section': ClubSection.videoAnalysis,
        'color': _C.purple,
      },
      {
        'icon': Icons.science_rounded,
        'label': 'Тестирование',
        'section': ClubSection.testing,
        'color': _C.greenDark,
      },
      {
        'icon': Icons.forum_rounded,
        'label': 'Чаты',
        'section': ClubSection.chat,
        'color': _C.greenDark,
      },
      {
        'icon': Icons.psychology_alt_rounded,
        'label': 'Менеджер',
        'section': ClubSection.manager,
        'color': _C.teal,
      },
    ];

    return Container(
      padding: EdgeInsets.all(fontSize),
      decoration: _mobileCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Быстрые действия',
            style: TextStyle(
              fontSize: fontSize * 1.1,
              fontWeight: FontWeight.w900,
              color: _C.text,
            ),
          ),
          SizedBox(height: fontSize * 0.8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: fontSize * 0.5,
              crossAxisSpacing: fontSize * 0.5,
              childAspectRatio: 1.18,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return _buildQuickActionCard(
                icon: action['icon'] as IconData,
                label: action['label'] as String,
                section: action['section'] as ClubSection,
                color: action['color'] as Color,
                fontSize: fontSize,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required ClubSection section,
    required Color color,
    required double fontSize,
  }) {
    return InkWell(
      onTap: () => _openGameModule(section),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: fontSize * 1.5),
            SizedBox(height: fontSize * 0.3),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize * 0.61,
                fontWeight: FontWeight.w800,
                color: _C.text,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileEvents(double fontSize) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(fontSize),
      decoration: _mobileCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ближайшие события',
            style: TextStyle(
              fontSize: fontSize * 1.1,
              fontWeight: FontWeight.w900,
              color: _C.text,
            ),
          ),
          SizedBox(height: fontSize * 0.6),
          ...events.take(3).map((event) {
            final title =
                _asString(event['title'] ?? event['name']) ?? 'Событие';
            final date = _asString(
                    event['date'] ?? event['event_date'] ?? event['start_date']) ??
                'Дата не указана';
            return Container(
              margin: EdgeInsets.only(bottom: fontSize * 0.5),
              padding: EdgeInsets.all(fontSize * 0.6),
              decoration: BoxDecoration(
                color: _C.soft2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _C.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: fontSize * 0.5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: fontSize * 0.9,
                            fontWeight: FontWeight.w700,
                            color: _C.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: fontSize * 0.75,
                            color: _C.muted,
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

  Widget _MobileTeams({required double padding, required double fontSize}) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(padding),
          padding: EdgeInsets.all(fontSize * 0.8),
          decoration: _mobileCardDecoration(radius: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Команды клуба',
                  style: TextStyle(
                    fontSize: fontSize * 1.2,
                    fontWeight: FontWeight.w900,
                    color: _C.text,
                  ),
                ),
              ),
              IconButton(
                onPressed: _openCreateTeam,
                icon: Icon(Icons.add_circle_rounded,
                    color: _C.primaryGreen, size: fontSize * 1.8),
              ),
            ],
          ),
        ),
        Expanded(
          child: teams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_tree_rounded,
                          size: fontSize * 3, color: _C.muted),
                      SizedBox(height: padding),
                      Text(
                        'Нет команд',
                        style:
                            TextStyle(fontSize: fontSize, color: _C.muted),
                      ),
                      SizedBox(height: padding),
                      ElevatedButton.icon(
                        onPressed: _openCreateTeam,
                        icon: const Icon(Icons.add),
                        label: const Text('Создать команду'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: padding * 1.5,
                            vertical: padding,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadAll(),
                  child: ListView.builder(
                    padding: EdgeInsets.all(padding),
                    itemCount: teams.length,
                    itemBuilder: (context, index) {
                      final team = teams[index];
                      final id =
                          _asInt(team['id'] ?? team['team_id']);
                      final name =
                          _asString(team['name']) ?? 'Команда';
                      final subtitle =
                          _asString(team['age_group']) ??
                              'Футбол';
                      final logo = _asString(team['logo']);
                      final isActive = id == selectedTeamId;

                      return Card(
                        margin:
                            EdgeInsets.only(bottom: padding * 0.75),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          side: BorderSide(
                            color: isActive
                                ? _C.primaryGreen.withOpacity(0.3)
                                : _C.border,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        elevation: isActive ? 4 : 1,
                        child: ListTile(
                          contentPadding: EdgeInsets.all(
                              padding * 0.75),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: _C.soft,
                            backgroundImage:
                                logo != null && logo.isNotEmpty
                                    ? NetworkImage(logo)
                                    : null,
                            child: logo == null ||
                                    logo.isEmpty
                                ? Icon(Icons.shield_rounded,
                                    color: _C.primaryGreen,
                                    size: 28)
                                : null,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: fontSize,
                              color: isActive
                                  ? _C.primaryGreen
                                  : _C.text,
                            ),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: TextStyle(
                                fontSize: fontSize * 0.8),
                          ),
                          trailing: isActive
                              ? Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: padding * 0.5,
                                    vertical: padding * 0.25,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _C.primaryGreen
                                        .withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(
                                            20),
                                  ),
                                  child: Text(
                                    'Активна',
                                    style: TextStyle(
                                      color: _C.primaryGreen,
                                      fontSize:
                                          fontSize * 0.7,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () => _selectTeam(team),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _MobileRoster({required double padding, required double fontSize}) {
    if (!_hasTeam) return const _NeedTeam();

    if (loadingPlayers) {
      return const Center(
          child: CircularProgressIndicator(color: _C.primaryGreen));
    }

    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(padding),
          padding: EdgeInsets.all(fontSize * 0.8),
          decoration: _mobileCardDecoration(radius: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Состав команды',
                      style: TextStyle(
                        fontSize: fontSize * 1.1,
                        fontWeight: FontWeight.w900,
                        color: _C.text,
                      ),
                    ),
                    SizedBox(height: fontSize * 0.2),
                    Text(
                      selectedTeamName,
                      style: TextStyle(
                        fontSize: fontSize * 0.85,
                        color: _C.muted,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      if (selectedTeamId != null &&
                          selectedTeamId! > 0) {
                        Get.toNamed(
                          AppRoutes.addPlayerScreen,
                          arguments: {
                            'team_id': selectedTeamId,
                            'teamId': selectedTeamId,
                            'club_id': clubId,
                            'clubId': clubId,
                            'team_name': selectedTeamName,
                            'teamName': selectedTeamName,
                          },
                        )?.then((_) {
                          if (selectedTeamId != null) {
                            _loadPlayersForTeam(
                                selectedTeamId!);
                          }
                        });
                      } else {
                        Get.snackbar('Команда',
                            'Сначала выберите команду');
                      }
                    },
                    icon: Icon(Icons.person_add_alt_1_rounded,
                        color: _C.primaryGreen,
                        size: fontSize * 1.4),
                  ),
                  SizedBox(width: padding * 0.25),
                  IconButton(
                    onPressed: _openFullRosterScreen,
                    icon: Icon(Icons.open_in_new_rounded,
                        color: _C.primaryGreen,
                        size: fontSize * 1.4),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: players.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_rounded,
                          size: fontSize * 3, color: _C.muted),
                      SizedBox(height: padding),
                      Text(
                        'Игроки не найдены',
                        style: TextStyle(
                            fontSize: fontSize,
                            color: _C.muted),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      selectedTeamId != null
                          ? _loadPlayersForTeam(selectedTeamId!)
                          : Future.value(),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                        horizontal: padding),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      final first =
                          _asString(player['first_name']) ?? '';
                      final last =
                          _asString(player['last_name']) ?? '';
                      final name = '$first $last'.trim().isEmpty
                          ? 'Игрок'
                          : '$first $last';
                      final position =
                          _asString(player['position']) ??
                              'Амплуа';
                      final photo =
                          _asString(player['photo']);
                      final isActive =
                          selectedPlayer?['id'] ==
                              player['id'];

                      return Card(
                        margin: EdgeInsets.only(
                            bottom: padding * 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          side: BorderSide(
                            color: isActive
                                ? _C.blue.withOpacity(0.3)
                                : _C.border,
                          ),
                        ),
                        child: ListTile(
                          contentPadding:
                              EdgeInsets.symmetric(
                            horizontal: padding * 0.75,
                            vertical: padding * 0.3,
                          ),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: _C.soft,
                            backgroundImage: photo != null &&
                                    photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                            child: photo == null ||
                                    photo.isEmpty
                                ? Icon(Icons.person,
                                    color: _C.muted,
                                    size: 22)
                                : null,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: fontSize * 0.95,
                              color: isActive
                                  ? _C.blue
                                  : _C.text,
                            ),
                          ),
                          subtitle: Text(
                            position,
                            style: TextStyle(
                                fontSize: fontSize * 0.8),
                          ),
                          trailing: isActive
                              ? const Icon(
                                  Icons.check_circle,
                                  color: _C.blue,
                                  size: 20,
                                )
                              : const Icon(
                                  Icons.chevron_right,
                                  color: _C.muted,
                                  size: 20,
                                ),
                          onTap: () => _openPlayerProfile(player),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _MobileTrainings({required double padding, required double fontSize}) {
    if (!_hasTeam) return const _NeedTeam();

    final modules = [
      {
        'icon': Icons.folder_copy_rounded,
        'title': 'Планы-конспекты',
        'section': ClubSection.plans,
        'color': _C.blue,
      },
      {
        'icon': Icons.draw_rounded,
        'title': 'Графика',
        'section': ClubSection.graphics,
        'color': _C.purple,
      },
      {
        'icon': Icons.calendar_month_rounded,
        'title': 'Календарь',
        'section': ClubSection.calendar,
        'color': _C.teal,
      },
      {
        'icon': Icons.fact_check_rounded,
        'title': 'Посещаемость',
        'section': ClubSection.attendance,
        'color': _C.orange,
      },
      {
        'icon': Icons.science_rounded,
        'title': 'Тестирование',
        'section': ClubSection.testing,
        'color': _C.greenDark,
      },
      {
        'icon': Icons.analytics_rounded,
        'title': 'Видеоанализ',
        'section': ClubSection.videoAnalysis,
        'color': _C.purple,
      },
      {
        'icon': Icons.psychology_alt_rounded,
        'title': 'Менеджер',
        'section': ClubSection.manager,
        'color': _C.teal,
      },
      {
        'icon': Icons.videogame_asset_rounded,
        'title': 'Игровая зона',
        'section': ClubSection.miniGames,
        'color': _C.teal,
      },
      {
        'icon': Icons.badge_rounded,
        'title': 'Тренеры клуба',
        'section': ClubSection.trainers,
        'color': _C.purple,
      },
    ];

    return GridView.builder(
      padding: EdgeInsets.all(padding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: padding,
        crossAxisSpacing: padding,
        childAspectRatio: 1.3,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return _buildMobileModuleCard(
          icon: module['icon'] as IconData,
          title: module['title'] as String,
          section: module['section'] as ClubSection,
          color: module['color'] as Color,
          fontSize: fontSize,
        );
      },
    );
  }

  Widget _buildMobileModuleCard({
    required IconData icon,
    required String title,
    required ClubSection section,
    required Color color,
    required double fontSize,
  }) {
    return InkWell(
      onTap: () => setState(() => selectedSection = section),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: _mobileCardDecoration(radius: 18),
        padding: EdgeInsets.all(fontSize * 0.7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: fontSize * 3.2,
              height: fontSize * 3.2,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: fontSize * 1.8),
            ),
            SizedBox(height: fontSize * 0.6),
            Text(
              title,
              style: TextStyle(
                fontSize: fontSize * 0.85,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBottomNav() {
    final fontSize = _getResponsiveFontSize(context, 11);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.space_dashboard_rounded,
                label: 'Обзор',
                section: ClubSection.overview,
                fontSize: fontSize,
              ),
              _buildNavItem(
                icon: Icons.account_tree_rounded,
                label: 'Команды',
                section: ClubSection.teams,
                fontSize: fontSize,
              ),
              _buildNavItem(
                icon: Icons.groups_2_rounded,
                label: 'Состав',
                section: ClubSection.roster,
                fontSize: fontSize,
              ),
              _buildNavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Календарь',
                section: ClubSection.calendar,
                fontSize: fontSize,
              ),
              _buildMoreNavItem(
                fontSize: fontSize,
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _openMobileMoreMenu() {
    final items = <_MobileMoreMenuItem>[
      _MobileMoreMenuItem(
        icon: Icons.badge_rounded,
        title: 'Тренеры клуба',
        subtitle: 'Штаб и назначения',
        section: ClubSection.trainers,
        color: _C.purple,
      ),
      _MobileMoreMenuItem(
        icon: Icons.sports_soccer_rounded,
        title: 'Матчи',
        subtitle: 'Игры и результаты',
        section: ClubSection.matches,
        color: _C.orange,
      ),
      _MobileMoreMenuItem(
        icon: Icons.folder_copy_rounded,
        title: 'Планы',
        subtitle: 'Планы-конспекты',
        section: ClubSection.plans,
        color: _C.blue,
        pro: true,
      ),
      _MobileMoreMenuItem(
        icon: Icons.analytics_rounded,
        title: 'Видеоанализ',
        subtitle: 'AI и разбор игр',
        section: ClubSection.videoAnalysis,
        color: _C.purple,
        pro: true,
      ),
      _MobileMoreMenuItem(
        icon: Icons.forum_rounded,
        title: 'Чаты',
        subtitle: 'Командное общение',
        section: ClubSection.chat,
        color: _C.greenDark,
      ),
      _MobileMoreMenuItem(
        icon: Icons.fact_check_rounded,
        title: 'Посещаемость',
        subtitle: 'Журнал команды',
        section: ClubSection.attendance,
        color: _C.orange,
        pro: true,
      ),
      _MobileMoreMenuItem(
        icon: Icons.science_rounded,
        title: 'Тестирование',
        subtitle: 'Физика, техника, тактика',
        section: ClubSection.testing,
        color: _C.greenDark,
        pro: true,
      ),
      _MobileMoreMenuItem(
        icon: Icons.draw_rounded,
        title: 'Графика',
        subtitle: 'Схемы и упражнения',
        section: ClubSection.graphics,
        color: _C.purple,
        pro: true,
      ),
      _MobileMoreMenuItem(
        icon: Icons.psychology_alt_rounded,
        title: 'Менеджер',
        subtitle: 'Управление игрой',
        section: ClubSection.manager,
        color: _C.teal,
        pro: true,
      ),
      _MobileMoreMenuItem(
        icon: Icons.video_library_rounded,
        title: 'Видеоуроки',
        subtitle: 'Обучение',
        section: ClubSection.videoLessons,
        color: _C.blue,
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _MobileMoreBottomSheet(
          clubName: clubName,
          selectedTeamName: selectedTeamName,
          hasTeam: _hasTeam,
          currentSection: selectedSection,
          items: items,
          hasActiveSubscription: hasActiveSubscription,
          onSelect: (section) {
            Navigator.of(sheetContext).pop();
            _openGameModule(section);
          },
        );
      },
    );
  }

  Widget _buildMoreNavItem({required double fontSize}) {
    final moreSections = <ClubSection>{
      ClubSection.trainers,
      ClubSection.teamTrainers,
      ClubSection.matches,
      ClubSection.plans,
      ClubSection.videoAnalysis,
      ClubSection.chat,
      ClubSection.attendance,
      ClubSection.testing,
      ClubSection.graphics,
      ClubSection.manager,
      ClubSection.miniGames,
      ClubSection.videoLessons,
    };
    final isActive = moreSections.contains(selectedSection);

    return Expanded(
      child: InkWell(
        onTap: _openMobileMoreMenu,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: fontSize * 3.1,
                height: fontSize * 2.45,
                decoration: BoxDecoration(
                  color: isActive ? _C.primaryGreen.withOpacity(.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isActive ? _C.primaryGreen.withOpacity(.22) : Colors.transparent,
                  ),
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  size: fontSize * 1.8,
                  color: isActive ? _C.primaryGreen : _C.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ещё',
                style: TextStyle(
                  fontSize: fontSize * 0.9,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive ? _C.primaryGreen : _C.muted,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

    bool _isSectionVisibleActive(ClubSection section) {
    if (selectedSection == section) return true;

    if (section == ClubSection.roster &&
        selectedSection == ClubSection.playerProfile) {
      return true;
    }

    if (section == ClubSection.trainers &&
        selectedSection == ClubSection.teamTrainers) {
      return true;
    }

    return false;
  }

Widget _buildNavItem({
    required IconData icon,
    required String label,
    required ClubSection section,
    required double fontSize,
  }) {
    final isActive = _isSectionVisibleActive(section);
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedSection = section),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: fontSize * 2,
                color: isActive ? _C.primaryGreen : _C.muted,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize * 0.9,
                  fontWeight:
                      isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive ? _C.primaryGreen : _C.muted,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _mobileCardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _C.border.withOpacity(0.8)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _buildWorkspace() {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _introController,
          builder: (context, _) {
            final appValue = CurvedAnimation(
              parent: _introController,
              curve: const Interval(.64, 1, curve: Curves.easeOutCubic),
            ).value;

            return Stack(
              children: [
                Opacity(
                  opacity: appValue,
                  child: Transform.scale(
                    scale: .965 + (.035 * appValue),
                    child: Transform.translate(
                      offset: Offset(0, 26 * (1 - appValue)),
                      child: Row(
                        children: [
                          _Sidebar(
                            clubName: clubName,
                            clubLogo: clubLogo,
                            clubDescription: clubDescription,
                            selectedTeamName: selectedTeamName,
                            selectedTeamId: selectedTeamId,
                            teams: teams,
                            teamsCount: teams.length,
                            playersCount: players.length,
                            trainersCount: trainers.length,
                            selectedSection: selectedSection,
                            onSelect: (section) =>
                                setState(() => selectedSection = section),
                            onTeamSelected: (team) => _selectTeam(team),
                            onOpenFullMenu: _openFullModulesMenu,
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Padding(
                                key: ValueKey(selectedSection.name),
                                padding: const EdgeInsets.fromLTRB(0, 10, 12, 12),
                                child: _buildContent(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_introFinished)
                  Positioned.fill(
                      child: _ClubIntroSplash(
                          animation: _introController)),
              ],
            );
          },
        ),
      ),
    );
  }

  String _titleFor(ClubSection section) {
    switch (section) {
      case ClubSection.overview:
        return 'Рабочий кабинет клуба';
      case ClubSection.teams:
        return 'Команды клуба';
      case ClubSection.teamDashboard:
        return selectedTeamName;
      case ClubSection.roster:
        return 'Состав команды';
      case ClubSection.trainers:
        return 'Тренеры клуба';
      case ClubSection.teamTrainers:
        return 'Тренеры команды';
      case ClubSection.playerProfile:
        return 'Профиль игрока';
      case ClubSection.matches:
        return 'Матчи';
      case ClubSection.calendar:
        return 'Календарь';
      case ClubSection.trainings:
        return 'Тренировки';
      case ClubSection.plans:
        return 'Планы-конспекты';
      case ClubSection.graphics:
        return 'Графический редактор';
      case ClubSection.videoAnalysis:
        return 'Видеоанализ';
      case ClubSection.description:
        return 'Визитка команды';
      case ClubSection.chat:
        return 'Чаты';
      case ClubSection.videoLessons:
        return 'Видеоуроки';
      case ClubSection.attendance:
        return 'Посещаемость';
      case ClubSection.testing:
        return 'Тестирование';
      case ClubSection.challenges:
        return 'Задания команды';
      case ClubSection.challengeCreate:
        return 'Создать задание';
      case ClubSection.quizzes:
        return 'Игровая зона';
      case ClubSection.quizCreate:
        return 'Создать квиз';
      case ClubSection.rating:
        return 'Рейтинг команды';
      case ClubSection.manager:
        return 'Менеджер команды';
      case ClubSection.miniGames:
        return 'Игровая зона';
      case ClubSection.medical:
        return 'Медкарта';
      case ClubSection.parents:
        return 'Родители';
      case ClubSection.settings:
        return 'Настройки';
    }
  }

  String _subtitleFor(ClubSection section) {
    switch (section) {
      case ClubSection.overview:
        return 'Команды, игроки, матчи, тренировки и аналитика в одном экране';
      case ClubSection.teams:
        return 'Крупные карточки команд и быстрое создание новой команды';
      case ClubSection.teamDashboard:
        return 'Единая панель выбранной команды';
      case ClubSection.roster:
        return 'Игроки, карточки, профиль и быстрые действия';
      case ClubSection.trainers:
        return 'Тренеры, специалисты и доступы клуба';
      case ClubSection.teamTrainers:
        return 'Назначение тренеров и специалистов к выбранной команде';
      case ClubSection.playerProfile:
        return 'Профиль игрока без выхода из рабочего кабинета';
      case ClubSection.matches:
        return 'Игры, результаты, календарь матчей и отчёты';
      case ClubSection.calendar:
        return 'Тренировки, матчи, события и расписание';
      case ClubSection.trainings:
        return 'Планы, графика, посещаемость и оценка тренировок';
      case ClubSection.plans:
        return 'База планов и конспектов тренера';
      case ClubSection.graphics:
        return 'Тактические схемы и упражнения';
      case ClubSection.videoAnalysis:
        return 'AI-анализ, видео, ТТД и статистика матча';
      case ClubSection.description:
        return 'Описание команды, информация и публичная карточка';
      case ClubSection.chat:
        return 'Командное и клубное общение';
      case ClubSection.videoLessons:
        return 'Обучающие материалы, папки и видео тренеров';
      case ClubSection.attendance:
        return 'Журнал посещаемости, события и оценка тренировок';
      case ClubSection.testing:
        return 'Оценка физической, технической и тактической подготовленности игроков';
      case ClubSection.challenges:
        return 'Задания для игроков и контроль выполнения';
      case ClubSection.challengeCreate:
        return 'Новое задание для активной команды';
      case ClubSection.quizzes:
        return 'Вопросы, задания и активность игроков';
      case ClubSection.quizCreate:
        return 'Создание нового квиза для команды';
      case ClubSection.rating:
        return 'Очки, активность и лидерборд команды';
      case ClubSection.manager:
        return 'Тактика, состав и игровые сценарии';
      case ClubSection.miniGames:
        return 'Игровые механики команды: задания, квизы и рейтинги';
      case ClubSection.medical:
        return 'Контроль состояния, травм и документов';
      case ClubSection.parents:
        return 'Доступы родителей и коммуникация';
      case ClubSection.settings:
        return 'Настройка модулей и прав доступа';
    }
  }

  Widget _buildContent() {
    switch (selectedSection) {
      case ClubSection.overview:
        return _OverviewPanel(
          clubName: clubName,
          clubLogo: clubLogo,
          clubDescription: clubDescription,
          teams: teams,
          trainers: trainers,
          events: events,
          playersCount: players.length,
          selectedTeamName: selectedTeamName,
          selectedTeamId: selectedTeamId,
          onTeamChanged: (team) => _selectTeam(team),
          onCreateTeam: _openCreateTeam,
          onEditClub: _openEditClubDialog,
          onEditTeam: _openEditTeamDialog,
          onOpenTeams: () =>
              setState(() => selectedSection = ClubSection.teams),
          onOpenRoster: () =>
              setState(() => selectedSection = ClubSection.roster),
          onOpenTrainers: () =>
              setState(() => selectedSection = ClubSection.trainers),
          onOpenTeamTrainers: () =>
              setState(() => selectedSection = ClubSection.trainers),
          onOpenMatches: () =>
              setState(() => selectedSection = ClubSection.matches),
          onOpenVideo: () =>
              setState(() => selectedSection = ClubSection.videoAnalysis),
        );
      case ClubSection.teams:
        return _TeamsPanel(
          teams: teams,
          selectedTeamId: selectedTeamId,
          onOpenTeam: (team) => _selectTeam(team),
          onCreateTeam: _openCreateTeam,
        );
      case ClubSection.teamDashboard:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Панель команды',
          subtitle:
              'Откройте полный рабочий экран команды или используйте модули слева.',
          icon: Icons.dashboard_customize_rounded,
          primaryText: 'Открыть панель команды',
          onPrimary: _openFullTeamDashboard,
          quickActions: [
            _ModuleQuickAction('Состав', Icons.groups_2_rounded,
                () => setState(() => selectedSection = ClubSection.roster)),
            _ModuleQuickAction('Матчи', Icons.sports_soccer_rounded,
                () => setState(() => selectedSection = ClubSection.matches)),
            _ModuleQuickAction('Календарь', Icons.calendar_month_rounded,
                () => setState(() => selectedSection = ClubSection.calendar)),
            _ModuleQuickAction(
                'Видеоанализ',
                Icons.analytics_rounded,
                () => setState(
                    () => selectedSection = ClubSection.videoAnalysis)),
          ],
        );
      case ClubSection.roster:
        return _TeamGuard(
          hasTeam: _hasTeam,
          child: _RosterPanel(
            teamName: selectedTeamName,
            selectedTeamId: selectedTeamId,
            clubId: clubId,
            players: players,
            loading: loadingPlayers,
            selectedPlayer: selectedPlayer,
            onRefresh: selectedTeamId == null
                ? null
                : () => _loadPlayersForTeam(selectedTeamId!),
            onOpenPlayer: _openPlayer,
            onOpenFullRoster: _openFullRosterScreen,
            onAddPlayer: () {
              if (selectedTeamId == null || selectedTeamId! <= 0) {
                Get.snackbar('Команда', 'Сначала выберите команду');
                return;
              }

              Get.toNamed(
                AppRoutes.addPlayerScreen,
                arguments: {
                  'team_id': selectedTeamId,
                  'teamId': selectedTeamId,
                  'club_id': clubId,
                  'clubId': clubId,
                  'team_name': selectedTeamName,
                  'teamName': selectedTeamName,
                },
              )?.then((_) {
                if (selectedTeamId != null) {
                  _loadPlayersForTeam(selectedTeamId!);
                }
              });
            },
          ),
        );
      case ClubSection.trainers:
      case ClubSection.teamTrainers:
        return CmrClubTrainersPanel(
          clubId: clubId,
          clubName: clubName,
          teams: teams,
          selectedTeamId: selectedTeamId,
          selectedTeamName: selectedTeamName,
          onChanged: () async {
            await _safeLoad(_loadTrainers);
            if (mounted) setState(() {});
          },
          onOpenTeams: () => setState(() => selectedSection = ClubSection.teams),
          onOpenRoster: () => setState(() => selectedSection = ClubSection.roster),
        );
      case ClubSection.playerProfile:
        return _TeamGuard(
          hasTeam: _hasTeam,
          child: _PlayerPanel(
            player: selectedPlayer,
            teamName: selectedTeamName,
            onBack: () =>
                setState(() => selectedSection = ClubSection.roster),
            onOpenFull: selectedPlayer == null
                ? null
                : () {
                    final mp =
                        Map<String, dynamic>.from(selectedPlayer!);

                    mp['team_id'] = selectedTeamId;
                    mp['teamId'] = selectedTeamId;
                    mp['club_id'] = clubId;
                    mp['clubId'] = clubId;
                    mp['team_name'] = selectedTeamName;
                    mp['teamName'] = selectedTeamName;

                    Get.toNamed(AppRoutes.playerProfileScreen,
                        arguments: mp);
                  },
          ),
        );
      case ClubSection.matches:
        return _TeamGuard(
            hasTeam: _hasTeam,
            child: CmrTeamMatchesPanel(
                teamId: selectedTeamId!,
                teamName: selectedTeamName,
                clubId: clubId,
                clubName: clubName));
      case ClubSection.calendar:
        return _TeamGuard(
            hasTeam: _hasTeam,
            child: CmrCalendarPanel(
                teamId: selectedTeamId!,
                teamName: selectedTeamName,
                clubId: clubId,
                clubName: clubName));
      case ClubSection.trainings:
        return _TrainingsPanel(
          hasTeam: _hasTeam,
          onOpenPlans: () =>
              setState(() => selectedSection = ClubSection.plans),
          onOpenGraphics: () =>
              setState(() => selectedSection = ClubSection.graphics),
          onOpenCalendar: () =>
              setState(() => selectedSection = ClubSection.calendar),
          onOpenFullTeam: _openFullTeamDashboard,
        );
      case ClubSection.plans:
        return _TeamGuard(
            hasTeam: _hasTeam,
            child: CmrPlansPanel(
                clubId: clubId,
                clubName: clubName,
                teamId: selectedTeamId,
                teamName: selectedTeamName));
      case ClubSection.graphics:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Графический редактор',
          subtitle:
              'Тактические схемы, упражнения и визуальные конспекты.',
          icon: Icons.draw_rounded,
          primaryText: 'Открыть редактор',
          onPrimary: _openFullGraphics,
          quickActions: [
            _ModuleQuickAction('Планы', Icons.folder_copy_rounded,
                () => setState(() => selectedSection = ClubSection.plans)),
            _ModuleQuickAction(
                'Видеоанализ',
                Icons.analytics_rounded,
                () => setState(
                    () => selectedSection = ClubSection.videoAnalysis)),
          ],
        );
      case ClubSection.videoAnalysis:
        return _TeamGuard(
            hasTeam: _hasTeam,
            child: CmrVideoAnalysisPanel(
                teamId: selectedTeamId!,
                teamName: selectedTeamName,
                clubId: clubId,
                clubName: clubName));
      case ClubSection.description:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Визитка команды',
          subtitle:
              'Описание команды, публичная информация, история и контакты.',
          icon: Icons.article_rounded,
          primaryText: 'Открыть визитку',
          onPrimary: _openFullTeamDescription,
          quickActions: [
            _ModuleQuickAction('Состав', Icons.groups_2_rounded,
                () => setState(() => selectedSection = ClubSection.roster)),
            _ModuleQuickAction('Матчи', Icons.sports_soccer_rounded,
                () => setState(() => selectedSection = ClubSection.matches)),
          ],
        );
      case ClubSection.chat:
        final userId = currentUserId > 0 ? currentUserId : clubId;

        return CmrChatsPanel(
          userId: userId,
          clubName: clubName,
          teamId: selectedTeamId,
          teamName: selectedTeamName,
        );
      case ClubSection.videoLessons:
        return _TeamModulePanel(
          hasTeam: true,
          title: 'Видеоуроки клуба',
          subtitle:
              'Папки с обучающими материалами, видео тренеров и методическая база для игроков.',
          icon: Icons.video_library_rounded,
          primaryText: 'Открыть видеоуроки',
          onPrimary: _openFullVideoLessons,
          quickActions: [
            _ModuleQuickAction('Планы', Icons.folder_copy_rounded,
                () => setState(() => selectedSection = ClubSection.plans)),
            _ModuleQuickAction('Графика', Icons.draw_rounded,
                () => setState(() => selectedSection = ClubSection.graphics)),
            _ModuleQuickAction('Состав', Icons.groups_2_rounded,
                () => setState(() => selectedSection = ClubSection.roster)),
          ],
        );
      case ClubSection.attendance:
        return _TeamGuard(
            hasTeam: _hasTeam,
            child: CmrAttendancePanel(
                teamId: selectedTeamId!,
                teamName: selectedTeamName,
                clubId: clubId,
                clubName: clubName));
      case ClubSection.testing:
        return _TeamGuard(
          hasTeam: _hasTeam,
          child: CmrTestingPanel(
            clubId: clubId,
            teamId: selectedTeamId!,
            clubName: clubName,
            teamName: selectedTeamName,
            initialStage: _selectedTeamStage(),
            userId: currentUserId,
          ),
        );

      case ClubSection.challenges:
        return _buildCmrGameZone(mode: CmrGameZoneMode.challenges);
      case ClubSection.challengeCreate:
        _openGameModule(ClubSection.challengeCreate);
        return const _NeedTeam();
      case ClubSection.quizzes:
        return _buildCmrGameZone(mode: CmrGameZoneMode.quizzes);
      case ClubSection.quizCreate:
        _openGameModule(ClubSection.quizCreate);
        return const _NeedTeam();
      case ClubSection.rating:
        return _buildCmrGameZone(mode: CmrGameZoneMode.rating);
      case ClubSection.manager:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Менеджер команды',
          subtitle: 'Тактика, состав, игровые сценарии и симуляция матчей.',
          icon: Icons.psychology_alt_rounded,
          primaryText: 'Открыть менеджер',
          onPrimary: () => _openGameModule(ClubSection.manager),
        );
      case ClubSection.miniGames:
        return _buildCmrGameZone();
      case ClubSection.medical:
        return const _SolidPlaceholder(
            icon: Icons.medical_information_rounded,
            title: 'Медкарта игроков',
            subtitle:
                'Здесь можно подключить медицинские записи, травмы, осмотры, вакцинации и документы по игрокам.',
            chips: ['Осмотры', 'Травмы', 'Вакцинация', 'Документы', 'История']);
      case ClubSection.parents:
        return const _SolidPlaceholder(
            icon: Icons.family_restroom_rounded,
            title: 'Родители и доступы',
            subtitle:
                'Раздел для доступа родителей к данным ребёнка, уведомлений, согласований и общения.',
            chips: ['Доступы', 'Уведомления', 'Чат', 'Карточки детей']);
      case ClubSection.settings:
        return const _SolidPlaceholder(
            icon: Icons.tune_rounded,
            title: 'Настройки рабочего кабинета',
            subtitle:
                'Следующим шагом сюда можно добавить порядок модулей, видимость разделов и права ролей.',
            chips: ['Меню', 'Роли', 'Виджеты', 'Оформление']);
    }
  }
}


class _SmallActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _C.primaryGreen.withOpacity(.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _C.primaryGreen.withOpacity(.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _C.primaryGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _C.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _C {
  static const Color bg = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE7ECF2);

  static const Color black = Color(0xFF111827);
  static const Color graphite = Color(0xFF334155);
  static const Color active = Color(0xFFF1F5F9);
  static const Color soft = Color(0xFFF7FAF8);
  static const Color soft2 = Color(0xFFFAFBFA);
  static const Color accent = Color(0xFF94A3B8);

  static const Color primaryGreen = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF008C40);
  static const Color footballGreen = Color(0xFF178A45);
  static const Color footballGreenSoft = Color(0xFFEAF5EE);
  static const Color greenSoft = Color(0xFFF0FAF4);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFFF3E8FF);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF1E8);
  static const Color teal = Color(0xFF0F766E);
  static const Color tealSoft = Color(0xFFE6F6F4);
  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEE2E2);

  static Color accentForSection(ClubSection section) {
    switch (section) {
      case ClubSection.overview:
        return primaryGreen;
      case ClubSection.teams:
      case ClubSection.trainers:
      case ClubSection.teamTrainers:
      case ClubSection.teamDashboard:
      case ClubSection.roster:
      case ClubSection.playerProfile:
        return blue;
      case ClubSection.matches:
        return orange;
      case ClubSection.calendar:
      case ClubSection.attendance:
        return teal;
      case ClubSection.videoAnalysis:
      case ClubSection.graphics:
      case ClubSection.testing:
        return purple;
      case ClubSection.trainings:
      case ClubSection.plans:
      case ClubSection.videoLessons:
        return footballGreen;
      case ClubSection.medical:
        return red;
      case ClubSection.chat:
      case ClubSection.parents:
      case ClubSection.description:
      case ClubSection.settings:
        return graphite;
      case ClubSection.challenges:
      case ClubSection.challengeCreate:
      case ClubSection.quizzes:
      case ClubSection.quizCreate:
      case ClubSection.rating:
      case ClubSection.manager:
      case ClubSection.miniGames:
        return purple;
    }
  }

  static Color softFor(Color color) {
    if (color == blue) return blueSoft;
    if (color == purple) return purpleSoft;
    if (color == orange) return orangeSoft;
    if (color == teal) return tealSoft;
    if (color == red) return redSoft;
    if (color == footballGreen || color == primaryGreen || color == greenDark)
      return footballGreenSoft;
    return soft;
  }

  static Color accentForIcon(IconData icon) {
    if (icon == Icons.groups_2_rounded ||
        icon == Icons.account_tree_rounded ||
        icon == Icons.dashboard_customize_rounded ||
        icon == Icons.person_search_rounded) return blue;
    if (icon == Icons.sports_soccer_rounded ||
        icon == Icons.sports_score_rounded) return orange;
    if (icon == Icons.calendar_month_rounded ||
        icon == Icons.event_available_rounded ||
        icon == Icons.event_note_outlined ||
        icon == Icons.fact_check_rounded) return teal;
    if (icon == Icons.analytics_rounded || icon == Icons.draw_rounded)
      return purple;
    if (icon == Icons.medical_information_rounded ||
        icon == Icons.health_and_safety_rounded) return red;
    if (icon == Icons.folder_copy_rounded ||
        icon == Icons.fitness_center_rounded ||
        icon == Icons.video_library_rounded) return footballGreen;
    return primaryGreen;
  }
}

class _Sidebar extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String clubDescription;
  final String selectedTeamName;
  final int? selectedTeamId;
  final List<Map<String, dynamic>> teams;
  final int teamsCount;
  final int playersCount;
  final int trainersCount;
  final ClubSection selectedSection;
  final ValueChanged<ClubSection> onSelect;
  final ValueChanged<Map<String, dynamic>> onTeamSelected;
  final VoidCallback onOpenFullMenu;

  const _Sidebar({
    required this.clubName,
    required this.clubLogo,
    required this.clubDescription,
    required this.selectedTeamName,
    required this.selectedTeamId,
    required this.teams,
    required this.teamsCount,
    required this.playersCount,
    required this.trainersCount,
    required this.selectedSection,
    required this.onSelect,
    required this.onTeamSelected,
    required this.onOpenFullMenu,
  });

  bool _sectionIsActive(ClubSection itemSection) {
    if (itemSection == selectedSection) return true;

    if (itemSection == ClubSection.roster &&
        selectedSection == ClubSection.playerProfile) {
      return true;
    }

    if (itemSection == ClubSection.trainers &&
        selectedSection == ClubSection.teamTrainers) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[
      _NavItem(ClubSection.overview, Icons.space_dashboard_rounded, 'Обзор'),
      _NavItem(ClubSection.trainers, Icons.badge_rounded, 'Тренеры'),
      _NavItem(ClubSection.roster, Icons.groups_2_rounded, 'Состав'),
      _NavItem(ClubSection.matches, Icons.sports_soccer_rounded, 'Матчи'),
      _NavItem(
          ClubSection.calendar, Icons.calendar_month_rounded, 'Календарь'),
      _NavItem(ClubSection.plans, Icons.folder_copy_rounded, 'Планы'),
      _NavItem(ClubSection.graphics, Icons.draw_rounded, 'Графика'),
      _NavItem(
          ClubSection.videoAnalysis, Icons.analytics_rounded, 'Видеоанализ'),
      _NavItem(ClubSection.chat, Icons.forum_rounded, 'Чаты'),
      _NavItem(
          ClubSection.videoLessons, Icons.video_library_rounded, 'Видеоуроки'),
      _NavItem(
          ClubSection.attendance, Icons.fact_check_rounded, 'Посещаемость'),
      _NavItem(ClubSection.testing, Icons.science_rounded, 'Тестирование'),
      _NavItem(ClubSection.manager, Icons.psychology_alt_rounded, 'Менеджер'),
      _NavItem(ClubSection.miniGames, Icons.videogame_asset_rounded, 'Игровая зона'),
      _NavItem(ClubSection.medical, Icons.medical_information_rounded,
          'Медкарта'),
      _NavItem(
          ClubSection.parents, Icons.family_restroom_rounded, 'Родители'),
      _NavItem(ClubSection.settings, Icons.tune_rounded, 'Настройки'),
    ];

    return Container(
      width: 274,
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.055),
              blurRadius: 30,
              offset: const Offset(0, 18))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _C.soft2,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _C.border)),
            child: Row(
              children: [
                _LogoBox(url: clubLogo, size: 52, bgColor: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clubName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _C.text,
                                height: 1.05,
                                fontSize: 13.2,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 5,
                          runSpacing: 3,
                          children: [
                            _MiniCountPill(value: '$teamsCount', label: 'команд'),
                            _MiniCountPill(value: '$playersCount', label: 'игроков'),
                            _MiniCountPill(value: '$trainersCount', label: 'тренеров'),
                          ],
                        ),
                      ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _C.footballGreenSoft,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: _C.footballGreen.withOpacity(.16))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.shield_rounded,
                        size: 18, color: _C.footballGreen),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Активная команда',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _C.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    _SidebarTeamPickerButton(
                      teams: teams,
                      selectedTeamId: selectedTeamId,
                      onTeamSelected: onTeamSelected,
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(selectedTeamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _C.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ]),
          ),
          const SizedBox(height: 12),
          _SidebarFullMenuButton(onTap: onOpenFullMenu),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, index) {
                final item = items[index];
                final active = _sectionIsActive(item.section);
                final accent = _C.accentForSection(item.section);
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onSelect(item.section),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: active
                          ? _C.softFor(accent)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: active
                          ? Border.all(color: accent.withOpacity(.16))
                          : null,
                    ),
                    child: Row(children: [
                      Icon(item.icon,
                          size: 21,
                          color: active ? accent : _C.muted),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: active ? _C.text : _C.text,
                                  fontWeight: active
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  fontSize: item.label.length > 10 ? 10.6 : 11.8))),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _SidebarTeamPickerButton extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final int? selectedTeamId;
  final ValueChanged<Map<String, dynamic>> onTeamSelected;

  const _SidebarTeamPickerButton({
    required this.teams,
    required this.selectedTeamId,
    required this.onTeamSelected,
  });

  int _teamId(Map<String, dynamic> team) {
    final raw = team['id'] ?? team['team_id'] ?? team['teamId'] ?? team['teamID'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _teamName(Map<String, dynamic> team) {
    final raw = team['name'] ?? team['team_name'] ?? team['title'];
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? 'Команда' : value;
  }

  String _teamSubtitle(Map<String, dynamic> team) {
    final raw = team['age_group'] ?? team['sport'] ?? team['category'];
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? 'Футбол' : value;
  }

  String? _teamLogo(Map<String, dynamic> team) {
    final raw = team['logo'] ?? team['logo_url'] ?? team['photo'] ?? team['image'];
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Выбрать команду',
      enabled: teams.isNotEmpty,
      offset: const Offset(0, 42),
      elevation: 14,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: _C.border.withOpacity(.9)),
      ),
      constraints: const BoxConstraints(
        minWidth: 248,
        maxWidth: 292,
        maxHeight: 420,
      ),
      onSelected: (index) {
        if (index >= 0 && index < teams.length) {
          onTeamSelected(teams[index]);
        }
      },
      itemBuilder: (context) {
        if (teams.isEmpty) {
          return const [
            PopupMenuItem<int>(
              enabled: false,
              value: -1,
              child: Text('Команды пока не созданы'),
            ),
          ];
        }

        return List.generate(teams.length, (index) {
          final team = teams[index];
          final id = _teamId(team);
          final active = id > 0 && id == selectedTeamId;
          final logo = _teamLogo(team);

          return PopupMenuItem<int>(
            value: index,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: active ? _C.footballGreenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? _C.footballGreen.withOpacity(.22) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: active ? Colors.white : _C.soft2,
                    backgroundImage: logo != null ? NetworkImage(logo) : null,
                    child: logo == null
                        ? Icon(Icons.shield_rounded,
                            size: 18,
                            color: active ? _C.footballGreen : _C.muted)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _teamName(team),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _C.text,
                            fontSize: 12.6,
                            fontWeight: active ? FontWeight.w900 : FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _teamSubtitle(team),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.muted,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _C.footballGreen,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ],
                ],
              ),
            ),
          );
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: teams.isEmpty ? _C.soft2 : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: teams.isEmpty
                ? _C.border
                : _C.footballGreen.withOpacity(.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.075),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: teams.isEmpty ? _C.muted : _C.footballGreen,
          size: 22,
        ),
      ),
    );
  }
}


class _SidebarFullMenuButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SidebarFullMenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF6B7280),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.apps_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Полное меню',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.6,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.open_in_full_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullMenuItem {
  final ClubSection section;
  final IconData icon;
  final String title;
  final String subtitle;

  const _FullMenuItem(this.section, this.icon, this.title, this.subtitle);
}

class _FullModulesMenuOverlay extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String selectedTeamName;
  final ClubSection selectedSection;
  final List<_FullMenuItem> items;

  const _FullModulesMenuOverlay({
    required this.clubName,
    required this.clubLogo,
    required this.selectedTeamName,
    required this.selectedSection,
    required this.items,
  });

  bool _sectionIsActive(ClubSection itemSection) {
    if (itemSection == selectedSection) return true;

    if (itemSection == ClubSection.roster &&
        selectedSection == ClubSection.playerProfile) {
      return true;
    }

    if (itemSection == ClubSection.trainers &&
        selectedSection == ClubSection.teamTrainers) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1280 ? 6 : width >= 980 ? 5 : width >= 720 ? 4 : 2;
    final compact = width < 720;

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 18, compact ? 10 : 16, compact ? 12 : 18, 16),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(compact ? 24 : 30),
                  border: Border.all(color: _C.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.045),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _LogoBox(url: clubLogo, size: compact ? 44 : 54, bgColor: _C.soft2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clubName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _C.text,
                              fontSize: compact ? 16 : 19,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedTeamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _SmallIconButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: compact ? 9 : 12,
                    crossAxisSpacing: compact ? 9 : 12,
                    childAspectRatio: compact ? 1.52 : 1.42,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final active = _sectionIsActive(item.section);
                    return _FullModuleTile(
                      item: item,
                      active: active,
                      onTap: () => Navigator.of(context).pop(item.section),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullModuleTile extends StatelessWidget {
  final _FullMenuItem item;
  final bool active;
  final VoidCallback onTap;

  const _FullModuleTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _C.accentForSection(item.section);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? _C.softFor(accent) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? accent.withOpacity(.24) : _C.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(active ? .055 : .035),
                blurRadius: active ? 18 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _C.softFor(accent),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withOpacity(.14)),
                    ),
                    child: Icon(item.icon, color: accent, size: 20),
                  ),
                  const Spacer(),
                  if (active)
                    Icon(Icons.check_circle_rounded, color: accent, size: 18)
                  else
                    const Icon(Icons.chevron_right_rounded, color: _C.muted, size: 18),
                ],
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCountPill extends StatelessWidget {
  final String value;
  final String label;

  const _MiniCountPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.border),
      ),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                color: _C.text,
                fontSize: 10.8,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: ' $label',
              style: const TextStyle(
                color: _C.muted,
                fontSize: 9.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _MobileGestureHintSheet extends StatelessWidget {
  const _MobileGestureHintSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(left: 4, bottom: 16),
                decoration: BoxDecoration(
                  color: _C.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _C.primaryGreen.withOpacity(.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _C.primaryGreen.withOpacity(.16)),
                    ),
                    child: const Icon(
                      Icons.swipe_rounded,
                      color: _C.primaryGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Управление жестами',
                          style: TextStyle(
                            color: _C.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Шапку убрали, чтобы на телефоне было больше места для клуба и команды.',
                          style: TextStyle(
                            color: _C.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _GestureTipRow(
                icon: Icons.keyboard_arrow_left_rounded,
                title: 'Листайте экран влево или вправо',
                text: 'Так можно быстро переходить между разделами панели клуба.',
              ),
              const SizedBox(height: 10),
              const _GestureTipRow(
                icon: Icons.keyboard_arrow_down_rounded,
                title: 'Потяните экран вниз',
                text: 'Так обновляются данные клуба, команд, событий и состава.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  child: const Text('Понятно'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GestureTipRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _GestureTipRow({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.border),
            ),
            child: Icon(icon, color: _C.primaryGreen, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final ClubSection section;
  final IconData icon;
  final String label;
  const _NavItem(this.section, this.icon, this.label);
}

class _BackCircleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackCircleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _C.soft,
            border: Border.all(color: _C.border),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _C.text,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final ClubSection selectedSection;
  final String selectedTeamName;
  final int? selectedTeamId;
  final List<Map<String, dynamic>> teams;
  final ValueChanged<Map<String, dynamic>> onTeamChanged;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onCreateTeam;
  final VoidCallback onEditClub;
  final VoidCallback onEditTeam;
  final bool refreshing;

  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.selectedSection,
    required this.selectedTeamName,
    required this.selectedTeamId,
    required this.teams,
    required this.onTeamChanged,
    required this.onBack,
    required this.onRefresh,
    required this.onCreateTeam,
    required this.onEditClub,
    required this.onEditTeam,
    required this.refreshing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _C.accentForSection(selectedSection);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 24,
              offset: const Offset(0, 12))
        ],
      ),
      child: Row(children: [
        _BackCircleButton(onTap: onBack),
        const SizedBox(width: 10),
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: _C.softFor(accent),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withOpacity(.18))),
            child:
                Icon(Icons.dashboard_customize_rounded, color: accent, size: 22)),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: _C.text)),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _C.muted,
                      height: 1.15,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w700)),
            ])),
        const SizedBox(width: 12),
        _TeamChooser(
            teams: teams,
            selectedTeamName: selectedTeamName,
            selectedTeamId: selectedTeamId,
            onTeamChanged: onTeamChanged),
        const SizedBox(width: 8),
        _TopToolButton(
            icon: Icons.edit_rounded,
            text: 'Клуб',
            onTap: onEditClub),
        const SizedBox(width: 8),
        _TopToolButton(
            icon: Icons.tune_rounded,
            text: 'Команда',
            onTap: onEditTeam),
        const SizedBox(width: 8),
        _TopToolButton(
            icon: Icons.add_rounded,
            text: 'Новая',
            onTap: onCreateTeam),
        const SizedBox(width: 8),
        _IconCircleButton(
            icon: refreshing
                ? Icons.sync_rounded
                : Icons.refresh_rounded,
            onTap: onRefresh),
      ]),
    );
  }
}


class _TopToolButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _TopToolButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: _C.soft2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _C.primaryGreen, size: 17),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _C.text,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ]),
      ),
    );
  }
}


class _TeamChooser extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final String selectedTeamName;
  final int? selectedTeamId;
  final ValueChanged<Map<String, dynamic>> onTeamChanged;

  const _TeamChooser({
    required this.teams,
    required this.selectedTeamName,
    required this.selectedTeamId,
    required this.onTeamChanged,
  });

  String _teamName(Map<String, dynamic> team) {
    return '${team['name'] ?? team['team_name'] ?? team['title'] ?? 'Команда'}';
  }

  String _teamSubtitle(Map<String, dynamic> team) {
    final value = '${team['age_group'] ?? team['category'] ?? team['sport'] ?? ''}'.trim();
    return value.isEmpty ? 'Рабочая команда клуба' : value;
  }

  String? _teamLogo(Map<String, dynamic> team) {
    final value = '${team['logo'] ?? team['logo_url'] ?? team['photo'] ?? ''}'.trim();
    return value.isEmpty ? null : value;
  }

  int _teamId(Map<String, dynamic> team) {
    return int.tryParse('${team['id'] ?? team['team_id'] ?? 0}') ?? 0;
  }

  Map<String, dynamic>? _selectedTeam() {
    for (final team in teams) {
      if (_teamId(team) == selectedTeamId) return team;
    }
    return null;
  }

  Future<void> _openTeamPicker(BuildContext context) async {
    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала создайте команду')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final width = MediaQuery.of(sheetContext).size.width;
        final isWide = width >= 760;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            isWide ? 24 : 12,
            0,
            isWide ? 24 : 12,
            12,
          ),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * .82,
                maxWidth: 980,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.14),
                    blurRadius: 38,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 5,
                    width: 54,
                    margin: const EdgeInsets.only(top: 12, bottom: 10),
                    decoration: BoxDecoration(
                      color: _C.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 14, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _C.greenSoft,
                                _C.primaryGreen.withOpacity(.16),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.account_tree_rounded,
                            color: _C.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Выбор команды',
                                style: TextStyle(
                                  color: _C.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Выберите команду для работы в обзоре клуба',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _C.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? 2 : 1,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: isWide ? 4.9 : 4.35,
                      ),
                      itemCount: teams.length,
                      itemBuilder: (_, index) {
                        final team = teams[index];
                        final id = _teamId(team);
                        final active = id == selectedTeamId;
                        return _TeamPickerTile(
                          name: _teamName(team),
                          subtitle: _teamSubtitle(team),
                          logo: _teamLogo(team),
                          active: active,
                          onTap: () => Navigator.pop(sheetContext, team),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) onTeamChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final team = _selectedTeam();
    final subtitle = team == null ? 'Команда не выбрана' : _teamSubtitle(team);
    final logo = team == null ? null : _teamLogo(team);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => _openTeamPicker(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              _C.greenSoft.withOpacity(.50),
              _C.soft2.withOpacity(.82),
            ],
          ),
        ),
        child: Row(
          children: [
                                   _LogoBox(url: logo, size: 54, bgColor: Colors.white),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Активная команда',
                    style: TextStyle(
                      color: _C.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedTeamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 18,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Сменить',
                    style: TextStyle(
                      color: _C.primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _C.primaryGreen,
                    size: 20,
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

class _TeamPickerTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? logo;
  final bool active;
  final VoidCallback onTap;

  const _TeamPickerTile({
    required this.name,
    required this.subtitle,
    required this.logo,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _C.greenSoft : _C.soft2,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _LogoBox(url: logo, size: 44, bgColor: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                active ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: active ? _C.primaryGreen : _C.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _OverviewControlCenter extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final String selectedTeamName;
  final int? selectedTeamId;
  final ValueChanged<Map<String, dynamic>> onTeamChanged;
  final VoidCallback onCreateTeam;
  final VoidCallback onEditClub;
  final VoidCallback onEditTeam;

  const _OverviewControlCenter({
    required this.teams,
    required this.selectedTeamName,
    required this.selectedTeamId,
    required this.onTeamChanged,
    required this.onCreateTeam,
    required this.onEditClub,
    required this.onEditTeam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 760;
          final actions = [
            _OverviewActionButton(
              icon: Icons.edit_note_rounded,
              title: 'Редактор клуба',
              subtitle: 'Название, логотип, описание',
              onTap: onEditClub,
            ),
            _OverviewActionButton(
              icon: Icons.tune_rounded,
              title: 'Редактор команды',
              subtitle: 'Данные активной команды',
              onTap: onEditTeam,
            ),
            _OverviewActionButton(
              icon: Icons.add_rounded,
              title: 'Новая команда',
              subtitle: 'Создать структуру клуба',
              filled: true,
              onTap: onCreateTeam,
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _OverviewControlTitle(),
              const SizedBox(height: 16),
              _TeamChooser(
                teams: teams,
                selectedTeamName: selectedTeamName,
                selectedTeamId: selectedTeamId,
                onTeamChanged: onTeamChanged,
              ),
              const SizedBox(height: 14),
              if (compact)
                Column(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      actions[i],
                      if (i != actions.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      Expanded(child: actions[i]),
                      if (i != actions.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewControlTitle extends StatelessWidget {
  const _OverviewControlTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _C.greenSoft,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _C.primaryGreen.withOpacity(.16)),
          ),
          child: const Icon(
            Icons.space_dashboard_rounded,
            color: _C.primaryGreen,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Рабочий обзор клуба',
                style: TextStyle(
                  color: _C.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Активная команда, действия и состояние клуба в одном месте',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _C.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const _HelpCircle(
          title: 'Как работать с обзором клуба',
          text: 'Обзор — это стартовый рабочий экран. Здесь выбирается активная команда, проверяется состояние клуба и выполняются быстрые действия без лишних переходов.',
          steps: [
            'Сначала выберите активную команду — от неё зависят состав, тренеры, матчи и календарь.',
            'Через быстрые действия добавляйте игроков, открывайте тренеров, матчи и видеоанализ.',
            'В правой колонке следите за подсказками: что заполнить и что проверить перед работой.',
            'Если данных мало, обзор подскажет, с чего лучше начать.',
          ],
        ),
      ],
    );
  }
}

class _OverviewActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;

  const _OverviewActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? _C.primaryGreen : Colors.white;
    final fg = filled ? Colors.white : _C.text;
    final sub = filled ? Colors.white.withOpacity(.82) : _C.muted;
    final iconBg = filled ? Colors.white.withOpacity(.16) : _C.greenSoft;
    final iconColor = filled ? Colors.white : _C.primaryGreen;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: filled ? _C.primaryGreen.withOpacity(.25) : _C.border,
          ),
          boxShadow: [
            BoxShadow(
              color: filled
                  ? _C.primaryGreen.withOpacity(.15)
                  : Colors.black.withOpacity(.025),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 21, color: iconColor),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: sub,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
}


class _OverviewPanel extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String clubDescription;
  final String selectedTeamName;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> trainers;
  final List<Map<String, dynamic>> events;
  final int playersCount;
  final int? selectedTeamId;
  final ValueChanged<Map<String, dynamic>> onTeamChanged;
  final VoidCallback onCreateTeam;
  final VoidCallback onEditClub;
  final VoidCallback onEditTeam;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenTeamTrainers;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenVideo;

  const _OverviewPanel(
      {required this.clubName,
      required this.clubLogo,
      required this.clubDescription,
      required this.selectedTeamName,
      required this.teams,
      required this.trainers,
      required this.events,
      required this.playersCount,
      required this.selectedTeamId,
      required this.onTeamChanged,
      required this.onCreateTeam,
      required this.onEditClub,
      required this.onEditTeam,
      required this.onOpenTeams,
      required this.onOpenRoster,
      required this.onOpenTrainers,
      required this.onOpenTeamTrainers,
      required this.onOpenMatches,
      required this.onOpenVideo});

  String _teamName(Map<String, dynamic> team) {
    final raw = '${team['name'] ?? team['team_name'] ?? team['title'] ?? 'Команда'}'.trim();
    return raw.isEmpty || raw == 'null' ? 'Команда' : raw;
  }

  String _teamSubtitle(Map<String, dynamic> team) {
    final raw = '${team['age_group'] ?? team['category'] ?? team['sport'] ?? 'Футбол'}'.trim();
    return raw.isEmpty || raw == 'null' ? 'Футбол' : raw;
  }

  String? _teamLogo(Map<String, dynamic> team) {
    final raw = '${team['logo'] ?? team['logo_url'] ?? team['photo'] ?? ''}'.trim();
    return raw.isEmpty || raw == 'null' ? null : raw;
  }

  bool _isSelectedTeam(Map<String, dynamic> team) {
    final id = int.tryParse('${team['id'] ?? team['team_id'] ?? 0}') ?? 0;
    return selectedTeamId != null && id == selectedTeamId;
  }

  Map<String, dynamic>? _activeTeam() {
    for (final team in teams) {
      if (_isSelectedTeam(team)) return team;
    }
    return teams.isNotEmpty ? teams.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final safeTeamName = selectedTeamName.trim().isEmpty ? 'Команда не выбрана' : selectedTeamName.trim();
    final activeTeam = _activeTeam();
    final eventItems = events.take(3).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Обзор должен работать как рабочее окно: слева управление,
        // справа подробности. Поэтому включаем две колонки раньше,
        // чтобы на macOS/планшете блоки не шли друг за другом.
        final twoColumns = constraints.maxWidth >= 720;
        final leftWidth = math.min(
          constraints.maxWidth >= 1180 ? 430.0 : 380.0,
          math.max(300.0, constraints.maxWidth * .40),
        );

        final leftBlock = _overviewLeftBlock(
          context: context,
          safeTeamName: safeTeamName,
          activeTeam: activeTeam,
        );
        final rightBlock = _overviewRightBlock(
          context: context,
          safeTeamName: safeTeamName,
          activeTeam: activeTeam,
          eventItems: eventItems,
        );

        return ListView(
          padding: const EdgeInsets.only(right: 2, bottom: 24),
          children: [
            if (twoColumns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: leftWidth, child: leftBlock),
                  const SizedBox(width: 14),
                  Expanded(child: rightBlock),
                ],
              )
            else ...[
              leftBlock,
              const SizedBox(height: 14),
              rightBlock,
            ],
          ],
        );
      },
    );
  }

  Widget _overviewLeftBlock({
    required BuildContext context,
    required String safeTeamName,
    required Map<String, dynamic>? activeTeam,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LogoBox(url: clubLogo, size: 64, bgColor: const Color(0xFFF1FBF4)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFFAF3),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFD8F3E1)),
                          ),
                          child: const Text(
                            'Обзор клуба',
                            style: TextStyle(
                              color: _C.primaryGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const _HelpCircle(
                          title: 'Обзор',
                          text: 'Это стартовый рабочий экран клуба. Слева — управление и выбор команды, справа — только ключевая информация по активной команде.',
                          steps: [
                            'Выберите активную команду.',
                            'Проверьте состав, тренеров и ближайшие события.',
                            'Для детальной работы переходите в нужный модуль.',
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      clubName.trim().isEmpty ? 'Клуб' : clubName.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 20,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      safeTeamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _teamSelectCard(activeTeam),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _miniMetric('Команды', teams.length.toString(), Icons.account_tree_rounded, const Color(0xFFEFF6FF), const Color(0xFF2563EB), onOpenTeams)),
              const SizedBox(width: 10),
              Expanded(child: _miniMetric('Игроки', playersCount.toString(), Icons.groups_2_rounded, const Color(0xFFEFFAF3), _C.primaryGreen, onOpenRoster)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _miniMetric('Тренеры', trainers.length.toString(), Icons.badge_rounded, const Color(0xFFFFF7ED), const Color(0xFFEA580C), onOpenTrainers)),
              const SizedBox(width: 10),
              Expanded(child: _miniMetric('События', events.length.toString(), Icons.event_note_rounded, const Color(0xFFF5F3FF), const Color(0xFF7C3AED), onOpenMatches)),
            ],
          ),
          const SizedBox(height: 16),
          _actionRow(icon: Icons.edit_rounded, title: 'Редактировать клуб', subtitle: 'Название, описание и логотип', onTap: onEditClub),
          const SizedBox(height: 8),
          _actionRow(icon: Icons.add_rounded, title: 'Новая команда', subtitle: 'Создать команду в клубе', onTap: onCreateTeam),
          const SizedBox(height: 8),
          _actionRow(icon: Icons.tune_rounded, title: 'Редактировать команду', subtitle: 'Данные активной команды', onTap: onEditTeam),
        ],
      ),
    );
  }

  Widget _overviewRightBlock({
    required BuildContext context,
    required String safeTeamName,
    required Map<String, dynamic>? activeTeam,
    required List<Map<String, dynamic>> eventItems,
  }) {
    final teamSubtitle = activeTeam == null ? 'Выберите команду для работы' : _teamSubtitle(activeTeam);
    final teamLogo = activeTeam == null ? null : _teamLogo(activeTeam);
    final description = clubDescription.trim().isEmpty
        ? 'Краткий обзор без лишней информации: состав, тренеры, события и быстрые переходы к рабочим разделам.'
        : clubDescription.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LogoBox(url: teamLogo ?? clubLogo, size: 76, bgColor: const Color(0xFFF8FAFC)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeTeamName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 24,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      teamSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(Icons.groups_2_rounded, '$playersCount игроков'),
                        _pill(Icons.badge_rounded, '${trainers.length} тренеров'),
                        _pill(Icons.event_available_rounded, '${events.length} событий'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _roundIconButton(Icons.edit_rounded, onEditTeam),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.border),
            ),
            child: Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.text,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final compactModules = c.maxWidth < 520;
              final modules = [
                _largeModule(icon: Icons.groups_2_rounded, title: 'Состав', subtitle: 'Игроки команды', onTap: onOpenRoster),
                _largeModule(icon: Icons.badge_rounded, title: 'Тренеры', subtitle: 'Штаб команды', onTap: onOpenTeamTrainers),
                _largeModule(icon: Icons.sports_soccer_rounded, title: 'Матчи', subtitle: 'Игры и ТТД', onTap: onOpenMatches),
              ];

              if (compactModules) {
                return Column(
                  children: [
                    for (int i = 0; i < modules.length; i++) ...[
                      modules[i],
                      if (i != modules.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: modules[0]),
                  const SizedBox(width: 10),
                  Expanded(child: modules[1]),
                  const SizedBox(width: 10),
                  Expanded(child: modules[2]),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 620) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _eventsMiniList(eventItems)),
                    const SizedBox(width: 12),
                    SizedBox(width: 220, child: _readinessMiniCard()),
                  ],
                );
              }
              return Column(
                children: [
                  _eventsMiniList(eventItems),
                  const SizedBox(height: 12),
                  _readinessMiniCard(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _teamSelectCard(Map<String, dynamic>? activeTeam) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          _LogoBox(url: activeTeam == null ? null : _teamLogo(activeTeam), size: 46, bgColor: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Активная команда',
                  style: TextStyle(color: _C.muted, fontSize: 11, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  activeTeam == null ? 'Команда не выбрана' : _teamName(activeTeam),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          PopupMenuButton<Map<String, dynamic>>(
            tooltip: 'Выбрать команду',
            onSelected: onTeamChanged,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            itemBuilder: (context) {
              if (teams.isEmpty) {
                return [
                  const PopupMenuItem<Map<String, dynamic>>(
                    enabled: false,
                    child: Text('Команд пока нет'),
                  ),
                ];
              }
              return teams.map((team) {
                final active = _isSelectedTeam(team);
                return PopupMenuItem<Map<String, dynamic>>(
                  value: team,
                  child: Row(
                    children: [
                      Icon(active ? Icons.check_circle_rounded : Icons.circle_outlined, color: active ? _C.primaryGreen : _C.muted, size: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_teamName(team), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                            Text(_teamSubtitle(team), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _C.primaryGreen,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _C.primaryGreen.withOpacity(.20), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String title, String value, IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: fg.withOpacity(.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(color: fg, fontSize: 20, height: 1, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _actionRow({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: const Color(0xFFF1FBF4), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: _C.primaryGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _C.muted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _C.primaryGreen, size: 15),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: _C.text, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _roundIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: const Color(0xFFF1FBF4), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD8F3E1))),
        child: Icon(icon, color: _C.primaryGreen, size: 20),
      ),
    );
  }

  Widget _largeModule({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: const Color(0xFFEFFAF3), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: _C.primaryGreen, size: 22),
            ),
            const SizedBox(height: 14),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _eventsMiniList(List<Map<String, dynamic>> eventItems) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Ближайшее', style: TextStyle(color: _C.text, fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              InkWell(
                onTap: onOpenMatches,
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text('Открыть', style: TextStyle(color: _C.primaryGreen, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (eventItems.isEmpty)
            const Text('Событий пока нет. Добавьте матч или тренировку в календаре команды.', style: TextStyle(color: _C.muted, fontSize: 12, height: 1.35, fontWeight: FontWeight.w700))
          else
            for (int i = 0; i < eventItems.length; i++) ...[
              _eventMiniTile(eventItems[i]),
              if (i != eventItems.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _eventMiniTile(Map<String, dynamic> event) {
    final title = '${event['title'] ?? event['name'] ?? event['event_title'] ?? 'Событие'}'.trim();
    final date = '${event['date'] ?? event['event_date'] ?? event['start_at'] ?? event['created_at'] ?? ''}'.trim();
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: _C.border)),
          child: const Icon(Icons.event_rounded, color: _C.primaryGreen, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.isEmpty || title == 'null' ? 'Событие' : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w900)),
              if (date.isNotEmpty && date != 'null') ...[
                const SizedBox(height: 2),
                Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _readinessMiniCard() {
    final ready = [
      teams.isNotEmpty,
      selectedTeamId != null && selectedTeamId! > 0,
      playersCount > 0,
      trainers.isNotEmpty,
      events.isNotEmpty,
    ].where((e) => e).length;
    final percent = (ready / 5 * 100).round();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFAF3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8F3E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded, color: _C.primaryGreen, size: 24),
          const SizedBox(height: 12),
          Text('$percent%', style: const TextStyle(color: _C.primaryGreen, fontSize: 26, height: 1, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Заполненность', style: TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Минимум данных для удобной работы клуба.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: _C.muted, fontSize: 11, height: 1.25, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _OverviewCheckItem {
  final String title;
  final bool done;
  const _OverviewCheckItem(this.title, this.done);
}

class _OverviewWorkHero extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String clubDescription;
  final String selectedTeamName;
  final int percent;
  final VoidCallback onEditClub;

  const _OverviewWorkHero({
    required this.clubName,
    required this.clubLogo,
    required this.clubDescription,
    required this.selectedTeamName,
    required this.percent,
    required this.onEditClub,
  });

  @override
  Widget build(BuildContext context) {
    final description = clubDescription.trim().isEmpty
        ? 'Добавьте описание клуба, чтобы тренерам и родителям было проще понимать структуру и задачи.'
        : clubDescription.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 620;
          final top = Row(
            children: [
              _LogoBox(
                url: clubLogo,
                size: compact ? 66 : 78,
                bgColor: _C.greenSoft,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _C.greenSoft,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: _C.primaryGreen.withOpacity(.18)),
                          ),
                          child: const Text(
                            'Рабочий центр',
                            style: TextStyle(
                              color: _C.primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            selectedTeamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      clubName.trim().isEmpty ? 'Клуб' : clubName,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.text,
                        fontSize: compact ? 22 : 27,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 16),
                _OverviewProgressBadge(percent: percent),
                const SizedBox(width: 10),
                _RosterHeaderAction(
                  icon: Icons.edit_rounded,
                  tooltip: 'Редактировать клуб',
                  onTap: onEditClub,
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                top,
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _OverviewProgressBadge(percent: percent)),
                    const SizedBox(width: 10),
                    _RosterHeaderAction(
                      icon: Icons.edit_rounded,
                      tooltip: 'Редактировать клуб',
                      onTap: onEditClub,
                    ),
                  ],
                ),
              ],
            );
          }

          return top;
        },
      ),
    );
  }
}

class _OverviewProgressBadge extends StatelessWidget {
  final int percent;
  const _OverviewProgressBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.primaryGreen.withOpacity(.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$percent%',
            style: const TextStyle(
              color: _C.primaryGreen,
              fontSize: 21,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'готовность',
            style: TextStyle(
              color: _C.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewStatsStrip extends StatelessWidget {
  final int teamsCount;
  final int playersCount;
  final int trainersCount;
  final int eventsCount;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenTrainers;

  const _OverviewStatsStrip({
    required this.teamsCount,
    required this.playersCount,
    required this.trainersCount,
    required this.eventsCount,
    required this.onOpenTeams,
    required this.onOpenRoster,
    required this.onOpenTrainers,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 820 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
        final itemWidth = (c.maxWidth - (columns - 1) * 10) / columns;
        final items = [
          _OverviewStatCard(
            icon: Icons.account_tree_rounded,
            title: 'Команды',
            value: '$teamsCount',
            subtitle: 'структура клуба',
            onTap: onOpenTeams,
          ),
          _OverviewStatCard(
            icon: Icons.groups_2_rounded,
            title: 'Игроки',
            value: '$playersCount',
            subtitle: 'в активной команде',
            onTap: onOpenRoster,
          ),
          _OverviewStatCard(
            icon: Icons.badge_rounded,
            title: 'Тренеры',
            value: '$trainersCount',
            subtitle: 'штаб клуба',
            onTap: onOpenTrainers,
          ),
          _OverviewStatCard(
            icon: Icons.event_available_rounded,
            title: 'События',
            value: '$eventsCount',
            subtitle: 'календарь клуба',
            onTap: () {},
          ),
        ];

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) => SizedBox(width: itemWidth, child: item)).toList(),
        );
      },
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  const _OverviewStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(radius: 24),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _C.greenSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: _C.primaryGreen, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
}

class _OverviewQuickActionsGrid extends StatelessWidget {
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenTeamTrainers;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenVideo;
  final VoidCallback onCreateTeam;

  const _OverviewQuickActionsGrid({
    required this.onOpenRoster,
    required this.onOpenTrainers,
    required this.onOpenTeamTrainers,
    required this.onOpenMatches,
    required this.onOpenVideo,
    required this.onCreateTeam,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _OverviewModuleCard(
        icon: Icons.groups_2_rounded,
        title: 'Состав',
        subtitle: 'игроки и карточки',
        active: true,
        onTap: onOpenRoster,
      ),
      _OverviewModuleCard(
        icon: Icons.badge_rounded,
        title: 'Тренеры',
        subtitle: 'штаб и назначения',
        active: true,
        onTap: onOpenTrainers,
      ),
      _OverviewModuleCard(
        icon: Icons.manage_accounts_rounded,
        title: 'Тренеры команды',
        subtitle: 'привязка к составу',
        onTap: onOpenTeamTrainers,
      ),
      _OverviewModuleCard(
        icon: Icons.sports_soccer_rounded,
        title: 'Матчи',
        subtitle: 'расписание и результаты',
        onTap: onOpenMatches,
      ),
      _OverviewModuleCard(
        icon: Icons.video_camera_back_rounded,
        title: 'Видеоанализ',
        subtitle: 'матчи и разбор',
        onTap: onOpenVideo,
      ),
      _OverviewModuleCard(
        icon: Icons.add_rounded,
        title: 'Новая команда',
        subtitle: 'добавить в клуб',
        onTap: onCreateTeam,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Быстрые действия',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _HelpCircle(
                title: 'Быстрые действия',
                text: 'Это рабочие карточки для быстрых переходов. Они не дублируют левое меню, а помогают тренеру сразу открыть нужное действие из обзора.',
                steps: [
                  'Откройте состав, если нужно быстро проверить игрока.',
                  'Откройте тренеров, если нужно посмотреть штаб или назначение.',
                  'Матчи и видеоанализ размещены рядом, потому что обычно используются вместе.',
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 760 ? 3 : (c.maxWidth >= 500 ? 2 : 1);
              final itemWidth = (c.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: actions.map((item) => SizedBox(width: itemWidth, child: item)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OverviewModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  const _OverviewModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? _C.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? _C.primaryGreen.withOpacity(.24) : _C.border,
            width: active ? 1.3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: active ? _C.primaryGreen.withOpacity(.10) : Colors.black.withOpacity(.025),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: active ? Colors.white : _C.soft2,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: active ? _C.primaryGreen.withOpacity(.16) : _C.border),
              ),
              child: Icon(icon, color: active ? _C.primaryGreen : _C.black, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: active ? _C.primaryGreen : _C.soft2,
                shape: BoxShape.circle,
                border: Border.all(color: active ? _C.primaryGreen : _C.border),
              ),
              child: Icon(
                active ? Icons.check_rounded : Icons.chevron_right_rounded,
                color: active ? Colors.white : _C.muted,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewEventsCard extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  const _OverviewEventsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    return _SolidCard(
      title: 'Ближайшие события',
      helpText: 'Здесь отображаются ближайшие события клуба. Блок помогает быстро понять, что запланировано по клубу и командам.',
      helpSteps: const [
        'Добавляйте события в календаре клуба или команды.',
        'Проверяйте дату и название события перед тренировкой или матчем.',
        'Если событий нет, блок покажет пустое состояние без ошибки.',
      ],
      child: events.isEmpty
          ? const _EmptyText('Пока нет событий для отображения.')
          : Column(
              children: events.map((event) {
                final title = '${event['title'] ?? event['name'] ?? 'Событие'}';
                final date = '${event['date'] ?? event['event_date'] ?? event['start_date'] ?? ''}';
                return _EventRow(title: title, date: date);
              }).toList(),
            ),
    );
  }
}

class _OverviewReadinessCard extends StatelessWidget {
  final int percent;
  final List<_OverviewCheckItem> items;

  const _OverviewReadinessCard({
    required this.percent,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _C.greenSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.verified_rounded, color: _C.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Готовность клуба',
                      style: TextStyle(
                        color: _C.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$percent% заполнено',
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 9,
              backgroundColor: _C.soft2,
              color: _C.primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          Column(
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Icon(
                      item.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: item.done ? _C.primaryGreen : _C.muted,
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: item.done ? _C.text : _C.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _OverviewAdvicePanel extends StatelessWidget {
  final int playersCount;
  final int trainersCount;
  final int eventsCount;
  final String selectedTeamName;
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenMatches;

  const _OverviewAdvicePanel({
    required this.playersCount,
    required this.trainersCount,
    required this.eventsCount,
    required this.selectedTeamName,
    required this.onOpenRoster,
    required this.onOpenTrainers,
    required this.onOpenMatches,
  });

  @override
  Widget build(BuildContext context) {
    final tips = <_OverviewTipData>[];
    if (playersCount <= 0) {
      tips.add(_OverviewTipData(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Добавьте игроков',
        text: 'Состав пустой — начните с добавления игроков в активную команду.',
        onTap: onOpenRoster,
      ));
    }
    if (trainersCount <= 0) {
      tips.add(_OverviewTipData(
        icon: Icons.badge_rounded,
        title: 'Добавьте тренеров',
        text: 'Штаб клуба пока пустой. Добавьте тренера и назначьте его в команду.',
        onTap: onOpenTrainers,
      ));
    }
    if (eventsCount <= 0) {
      tips.add(_OverviewTipData(
        icon: Icons.event_available_rounded,
        title: 'Запланируйте событие',
        text: 'Добавьте тренировку или матч, чтобы обзор стал рабочим календарём.',
        onTap: onOpenMatches,
      ));
    }
    if (tips.isEmpty) {
      tips.add(_OverviewTipData(
        icon: Icons.task_alt_rounded,
        title: 'Можно работать',
        text: 'Основные данные заполнены. Проверьте состав, тренеров и ближайшие матчи.',
        onTap: onOpenRoster,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.022),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Подсказки для работы',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < tips.length; i++) ...[
            _OverviewTipCard(data: tips[i]),
            if (i != tips.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _OverviewTipData {
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  const _OverviewTipData({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });
}

class _OverviewTipCard extends StatelessWidget {
  final _OverviewTipData data;
  const _OverviewTipCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: const Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _C.muted, size: 20),
          ],
        ),
      ),
    );
  }
}


class _OverviewLiveFeedCard extends StatelessWidget {
  final String clubName;
  final String selectedTeamName;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> trainers;
  final int playersCount;
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenTeams;

  const _OverviewLiveFeedCard({
    required this.clubName,
    required this.selectedTeamName,
    required this.events,
    required this.teams,
    required this.trainers,
    required this.playersCount,
    required this.onOpenRoster,
    required this.onOpenTrainers,
    required this.onOpenMatches,
    required this.onOpenTeams,
  });

  String _value(Map<String, dynamic> source, List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = '${source[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final items = <_OverviewFeedItem>[];

    for (final event in events.take(4)) {
      final title = _value(event, const ['title', 'name', 'event_title'], 'Событие клуба');
      final date = _value(event, const ['date', 'event_date', 'start_date', 'created_at'], 'Дата не указана');
      items.add(_OverviewFeedItem(
        icon: Icons.event_available_rounded,
        title: title,
        subtitle: date,
        label: 'Событие',
        tint: const Color(0xFFEFF6FF),
        color: const Color(0xFF2563EB),
        onTap: onOpenMatches,
      ));
    }

    for (final trainer in trainers.take(3)) {
      final first = _value(trainer, const ['first_name', 'firstname'], '');
      final last = _value(trainer, const ['last_name', 'lastname'], '');
      final full = _value(trainer, const ['full_name', 'fullName', 'name'], '$first $last').trim();
      items.add(_OverviewFeedItem(
        icon: Icons.badge_rounded,
        title: full.isEmpty ? 'Тренерский штаб' : full,
        subtitle: _value(trainer, const ['role', 'position', 'specialization'], 'Тренер клуба'),
        label: 'Тренер',
        tint: _C.greenSoft,
        color: _C.primaryGreen,
        onTap: onOpenTrainers,
      ));
    }

    for (final team in teams.take(3)) {
      final title = _value(team, const ['name', 'title', 'team_name'], 'Команда клуба');
      items.add(_OverviewFeedItem(
        icon: Icons.groups_2_rounded,
        title: title,
        subtitle: title == selectedTeamName ? 'Активная команда' : 'Команда клуба',
        label: title == selectedTeamName ? 'Активна' : 'Команда',
        tint: const Color(0xFFF8FAFC),
        color: _C.black,
        onTap: onOpenTeams,
      ));
    }

    if (items.isEmpty) {
      items.addAll([
        _OverviewFeedItem(
          icon: Icons.groups_2_rounded,
          title: selectedTeamName,
          subtitle: playersCount > 0 ? '$playersCount игроков в активной команде' : 'Добавьте игроков в состав',
          label: 'Состав',
          tint: _C.greenSoft,
          color: _C.primaryGreen,
          onTap: onOpenRoster,
        ),
        _OverviewFeedItem(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Чаты и сообщения',
          subtitle: 'После подключения API здесь появятся последние сообщения команды',
          label: 'Чат',
          tint: const Color(0xFFF3E8FF),
          color: const Color(0xFF7C3AED),
          onTap: onOpenTeams,
        ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _C.greenSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _C.primaryGreen.withOpacity(.16)),
                ),
                child: const Icon(Icons.dynamic_feed_rounded, color: _C.primaryGreen, size: 23),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Живая лента',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.text,
                        fontSize: 17,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'События, команды, тренеры и рабочая активность',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.muted,
                        fontSize: 12,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _HelpCircle(
                title: 'Живая лента обзора',
                text: 'Правая колонка не заменяет выбор команды. Она показывает последние рабочие действия клуба: события, тренеров, команды, а после подключения API — сообщения чатов, медкарту и аналитику.',
                steps: [
                  'Выбор команды остаётся в центральном блоке обзора.',
                  'В ленте справа отображается то, что уже есть в базе и относится к клубу.',
                  'Нажмите на строку ленты, чтобы быстро перейти к нужному модулю.',
                  'Когда добавим API активности, сюда попадут сообщения чатов и старые записи из базы.',
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: _C.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$clubName · $selectedTeamName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < items.take(8).length; i++) ...[
            _OverviewFeedTile(item: items[i], active: i == 0),
            if (i != items.take(8).length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _OverviewFeedItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String label;
  final Color tint;
  final Color color;
  final VoidCallback onTap;

  const _OverviewFeedItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.tint,
    required this.color,
    required this.onTap,
  });
}

class _OverviewFeedTile extends StatelessWidget {
  final _OverviewFeedItem item;
  final bool active;

  const _OverviewFeedTile({required this.item, required this.active});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF1FBF4) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? const Color(0xFF86E1A6) : _C.border,
            width: active ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: active ? const Color(0x2200C853) : Colors.black.withOpacity(.025),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.tint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: item.color.withOpacity(.10)),
              ),
              child: Icon(item.icon, color: item.color, size: 21),
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
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 13,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: active ? Colors.white : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: active ? const Color(0xFFBBF7D0) : _C.border),
                        ),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active ? _C.primaryGreen : _C.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: active ? _C.primaryGreen : const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: active ? _C.primaryGreen : _C.border),
              ),
              child: Icon(
                active ? Icons.check_rounded : Icons.chevron_right_rounded,
                color: active ? Colors.white : _C.muted,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewActivityCard extends StatelessWidget {
  final int teamsCount;
  final int playersCount;
  final int trainersCount;
  final int eventsCount;

  const _OverviewActivityCard({
    required this.teamsCount,
    required this.playersCount,
    required this.trainersCount,
    required this.eventsCount,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      _OverviewActivityRowData(Icons.account_tree_rounded, 'Структура клуба', '$teamsCount команд'),
      _OverviewActivityRowData(Icons.groups_2_rounded, 'Активный состав', '$playersCount игроков'),
      _OverviewActivityRowData(Icons.badge_rounded, 'Тренерский штаб', '$trainersCount тренеров'),
      _OverviewActivityRowData(Icons.event_note_rounded, 'Планирование', '$eventsCount событий'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Сводка активности',
            style: TextStyle(
              color: _C.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < rows.length; i++) ...[
            _OverviewActivityRow(data: rows[i]),
            if (i != rows.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _OverviewActivityRowData {
  final IconData icon;
  final String title;
  final String value;
  const _OverviewActivityRowData(this.icon, this.title, this.value);
}

class _OverviewActivityRow extends StatelessWidget {
  final _OverviewActivityRowData data;
  const _OverviewActivityRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _C.soft2,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(data.icon, color: _C.black, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          data.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _C.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CompletionInfoCard extends StatelessWidget {
  final String clubDescription;
  final String? clubLogo;
  final int teamsCount;
  final int trainersCount;
  final int playersCount;
  final int eventsCount;
  final String selectedTeamName;

  const _CompletionInfoCard({
    required this.clubDescription,
    required this.clubLogo,
    required this.teamsCount,
    required this.trainersCount,
    required this.playersCount,
    required this.eventsCount,
    required this.selectedTeamName,
  });

  @override
  Widget build(BuildContext context) {
    final missing = <String>[];

    if (clubDescription.trim().isEmpty) missing.add('Описание клуба');
    if (clubLogo == null || clubLogo!.trim().isEmpty) missing.add('Логотип клуба');
    if (teamsCount <= 0) missing.add('Команды');
    if (trainersCount <= 0) missing.add('Тренеры');
    if (selectedTeamName.trim().isEmpty || selectedTeamName == 'Команда не выбрана') {
      missing.add('Активная команда');
    }
    if (playersCount <= 0) missing.add('Игроки активной команды');
    if (eventsCount <= 0) missing.add('События клуба');

    final complete = missing.isEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: _C.primaryGreen,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  complete ? 'Профиль клуба заполнен' : 'Что желательно заполнить',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _C.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            complete
                ? 'Основные данные клуба выглядят аккуратно. Можно переходить к работе с командой.'
                : 'Эти пункты помогут сделать экран клуба понятнее для тренеров, игроков и родителей.',
            style: const TextStyle(
              color: _C.muted,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (complete ? ['Готово'] : missing).map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: complete ? _C.primaryGreen.withOpacity(0.1) : _C.soft2,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: complete ? _C.primaryGreen.withOpacity(0.25) : _C.border,
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    color: complete ? _C.primaryGreen : _C.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TeamsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final int? selectedTeamId;
  final ValueChanged<Map<String, dynamic>> onOpenTeam;
  final VoidCallback onCreateTeam;

  const _TeamsPanel(
      {required this.teams,
      required this.selectedTeamId,
      required this.onOpenTeam,
      required this.onCreateTeam});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _TeamsHeader(onCreateTeam: onCreateTeam),
      const SizedBox(height: 12),
      Expanded(
        child: teams.isEmpty
            ? _EmptyTeams(onCreateTeam: onCreateTeam)
            : GridView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.35),
                itemCount: teams.length,
                itemBuilder: (_, index) {
                  final team = teams[index];
                  final id = int.tryParse(
                          '${team['id'] ?? team['team_id'] ?? 0}') ??
                      0;
                  final name =
                      '${team['name'] ?? team['team_name'] ?? 'Команда'}';
                  final subtitle =
                      '${team['age_group'] ?? team['category'] ?? team['sport'] ?? 'Футбол'}';
                  final logo =
                      '${team['logo'] ?? team['logo_url'] ?? team['photo'] ?? ''}';
                  return _TeamCard(
                      name: name,
                      subtitle: subtitle,
                      logo: logo.isEmpty ? null : logo,
                      active: id == selectedTeamId,
                      onTap: () => onOpenTeam(team));
                },
              ),
      ),
    ]);
  }
}

class _TeamsHeader extends StatelessWidget {
  final VoidCallback onCreateTeam;
  const _TeamsHeader({required this.onCreateTeam});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 28),
      child: Row(children: [
        const _IconBadge(icon: Icons.account_tree_rounded, size: 54),
        const SizedBox(width: 14),
        const Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Команды клуба',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _C.text)),
              SizedBox(height: 4),
              Text(
                  'Создавайте команды, выбирайте активную и переходите к рабочим модулям.',
                  style: TextStyle(
                      color: _C.muted,
                      fontWeight: FontWeight.w600)),
            ])),
        _GreenButton(
            icon: Icons.add_rounded,
            text: 'Добавить команду',
            onTap: onCreateTeam,
            large: true),
      ]),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? logo;
  final bool active;
  final VoidCallback onTap;

  const _TeamCard(
      {required this.name,
      required this.subtitle,
      required this.logo,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: active ? _C.blueSoft : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: active
                  ? _C.blue.withOpacity(.28)
                  : _C.border,
              width: active ? 1.4 : 1),
          boxShadow: [
            BoxShadow(
                color: active
                    ? _C.blue.withOpacity(.12)
                    : Colors.black.withOpacity(.035),
                blurRadius: 22,
                offset: const Offset(0, 12))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _LogoBox(
                    url: logo,
                    size: 58,
                    bgColor: active ? Colors.white : _C.soft),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: active ? Colors.white : _C.soft2,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: active
                              ? _C.blue.withOpacity(.18)
                              : _C.border)),
                  child: Text(active ? 'Активна' : 'Открыть',
                      style: TextStyle(
                          color: active ? _C.blue : _C.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ),
              ]),
              const Spacer(),
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 19,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: active ? _C.blue : _C.text)),
              const SizedBox(height: 7),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _C.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
      ),
    );
  }
}


class _RosterPanel extends StatelessWidget {
  final String teamName;
  final int? selectedTeamId;
  final int clubId;
  final List<Map<String, dynamic>> players;
  final bool loading;
  final Map<String, dynamic>? selectedPlayer;
  final Future<void> Function()? onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpenPlayer;
  final VoidCallback onOpenFullRoster;
  final VoidCallback onAddPlayer;

  const _RosterPanel({
    required this.teamName,
    required this.selectedTeamId,
    required this.clubId,
    required this.players,
    required this.loading,
    required this.selectedPlayer,
    required this.onRefresh,
    required this.onOpenPlayer,
    required this.onOpenFullRoster,
    required this.onAddPlayer,
  });

  String _playerIdentity(Map<String, dynamic>? player) {
    if (player == null) return '';

    const idKeys = [
      'id',
      'player_id',
      'playerId',
      'user_id',
      'userId',
      'member_id',
      'memberId',
    ];

    for (final key in idKeys) {
      final value = '${player[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null' && value != '0') {
        return '$key:$value';
      }
    }

    final first = '${player['first_name'] ?? player['firstname'] ?? ''}'.trim();
    final last = '${player['last_name'] ?? player['lastname'] ?? ''}'.trim();
    final full = '${player['fullName'] ?? player['full_name'] ?? player['name'] ?? ''}'.trim();
    final birth = '${player['birth_date'] ?? player['birthDate'] ?? player['birthday'] ?? ''}'.trim();

    final fallback = [first, last, full, birth]
        .where((value) => value.isNotEmpty && value != 'null')
        .join('|');

    return fallback.isEmpty ? '' : 'fallback:$fallback';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: _C.primaryGreen),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final listWidth = math.min(430.0, constraints.maxWidth * .42);

        final rosterList = Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(radius: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.groups_2_rounded,
                      color: _C.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Состав команды',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 18,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$teamName · ${players.length} игроков',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HelpCircle(
                    title: 'Как работать с составом',
                    text:
                        'Состав — рабочая зона тренера. Здесь удобно быстро открыть карточку игрока, проверить данные и перейти в полный профиль.',
                    steps: const [
                      'Нажмите на игрока в списке, чтобы открыть подробности справа.',
                      'Добавляйте игроков через кнопку с плюсом — они будут привязаны к выбранной команде.',
                      'Используйте полный состав, когда нужно работать с большим списком и расширенными действиями.',
                    ],
                    icon: Icons.tips_and_updates_rounded,
                    size: 38,
                  ),
                  const SizedBox(width: 8),
                  _RosterHeaderAction(
                    icon: Icons.person_add_alt_1_rounded,
                    tooltip: 'Добавить игрока',
                    onTap: onAddPlayer,
                  ),
                  const SizedBox(width: 8),
                  _RosterHeaderAction(
                    icon: Icons.open_in_full_rounded,
                    tooltip: 'Открыть полный состав',
                    onTap: onOpenFullRoster,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _RosterAdviceCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Совет тренеру',
                text:
                    'Заполните амплуа, номер, рост и вес — карточки состава станут информативнее и удобнее для анализа.',
              ),
              const SizedBox(height: 14),
              Expanded(
                child: players.isEmpty
                    ? const Center(
                        child: _EmptyText('Игроки пока не найдены.'),
                      )
                    : RefreshIndicator(
                        color: _C.primaryGreen,
                        onRefresh: onRefresh ?? () async {},
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: players.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final player = players[index];
                            final playerKey = _playerIdentity(player);
                            final selectedKey = _playerIdentity(selectedPlayer);
                            final active = selectedPlayer != null &&
                                playerKey.isNotEmpty &&
                                playerKey == selectedKey;

                            return _PlayerTile(
                              player: player,
                              active: active,
                              index: index,
                              onTap: () => onOpenPlayer(player),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );

        final details = _PlayerPanel(
          player: selectedPlayer,
          teamName: teamName,
          onBack: null,
          onOpenFull: selectedPlayer == null
              ? null
              : () {
                  final mp = Map<String, dynamic>.from(selectedPlayer!);
                  mp['team_id'] ??= mp['teamId'];
                  mp['teamId'] ??= mp['team_id'];

                  Get.toNamed(
                    AppRoutes.playerProfileScreen,
                    arguments: mp,
                  );
                },
        );

        if (compact) {
          return Column(
            children: [
              SizedBox(height: 460, child: rosterList),
              const SizedBox(height: 12),
              Expanded(child: details),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: listWidth, child: rosterList),
            const SizedBox(width: 12),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class _RosterHeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RosterHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
            boxShadow: const [
              BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Icon(icon, color: _C.black, size: 20),
        ),
      ),
    );
  }
}

class _RosterAdviceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _RosterAdviceCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF2D98A)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFF92400E), size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool active;
  final int index;
  final VoidCallback onTap;

  const _PlayerTile({
    required this.player,
    required this.active,
    required this.index,
    required this.onTap,
  });

  String _field(List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = '${player[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }

  String _photoUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    final cleaned = value.startsWith('/') ? value.substring(1) : value;
    return 'https://sportotekaapp.ru/$cleaned';
  }

  @override
  Widget build(BuildContext context) {
    final first = _field(const ['first_name', 'firstname']);
    final last = _field(const ['last_name', 'lastname']);
    final name = ('$first $last').trim().isEmpty
        ? _field(const ['fullName', 'full_name', 'name'], 'Игрок')
        : ('$first $last').trim();
    final position = _field(const ['position', 'role'], 'Амплуа');
    final rawPhoto = _field(const ['photo', 'avatar', 'image', 'photo_url', 'avatar_url']);
    final photo = _photoUrl(rawPhoto);
    final number = _field(
      const ['number', 'player_number', 'shirt_number'],
      '${index + 1}',
    );
    final height = _field(const ['height']);
    final weight = _field(const ['weight']);
    final metrics = <String>[
      if (height.isNotEmpty) '$height см',
      if (weight.isNotEmpty) '$weight кг',
    ].join(' · ');

    final badgeBg = active ? _C.primaryGreen : const Color(0xFFF8FAFC);
    final borderColor = active
        ? _C.primaryGreen.withOpacity(.34)
        : const Color(0xFFE5E7EB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? _C.greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: active ? 1.2 : 1),
            boxShadow: [
              BoxShadow(
                color: active
                    ? _C.primaryGreen.withOpacity(.10)
                    : Colors.black.withOpacity(.025),
                blurRadius: active ? 18 : 12,
                offset: Offset(0, active ? 8 : 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _TrainerAvatar(photo: photo, name: name, size: 50),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active ? Colors.white : _C.muted,
                            fontSize: number.length > 2 ? 8 : 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 14.5,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _RosterInfoPill(
                          text: position,
                          color: _C.graphite,
                          bg: const Color(0xFFF7F7F8),
                        ),
                        _RosterInfoPill(
                          text: metrics.isEmpty ? 'Данные игрока' : metrics,
                          color: _C.graphite,
                          bg: const Color(0xFFF1F5F9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: active ? _C.primaryGreen : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? _C.primaryGreen : _C.border,
                  ),
                ),
                child: Icon(
                  active ? Icons.check_rounded : Icons.chevron_right_rounded,
                  color: active ? Colors.white : _C.muted,
                  size: active ? 17 : 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RosterInfoPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;

  const _RosterInfoPill({
    required this.text,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _C.border.withOpacity(.75)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  final Map<String, dynamic>? player;
  final String teamName;
  final VoidCallback? onBack;
  final VoidCallback? onOpenFull;

  const _PlayerPanel({
    required this.player,
    required this.teamName,
    required this.onBack,
    required this.onOpenFull,
  });

  String _text(String key, [String fallback = '—']) {
    final value = player?[key];
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _firstNonEmpty(List<String> keys, [String fallback = '—']) {
    for (final key in keys) {
      final value = _text(key, '');
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return const _SolidPlaceholder(
        icon: Icons.person_search_rounded,
        title: 'Выберите игрока',
        subtitle: 'Нажмите на игрока в составе, чтобы открыть его карточку.',
        chips: ['Профиль', 'Метрики', 'Медкарта'],
      );
    }

    final first = _text('first_name', '');
    final last = _text('last_name', '');
    final fullName = _firstNonEmpty(const ['fullName', 'full_name'], '$first $last').trim();
    final name = fullName.isEmpty ? _text('name', 'Игрок') : fullName;
    final photo = _firstNonEmpty(const ['photo', 'avatar', 'image'], '');
    final position = _firstNonEmpty(const ['position', 'role'], 'Амплуа не указано');
    final number = _firstNonEmpty(const ['number', 'player_number', 'shirt_number']);
    final birth = _firstNonEmpty(const ['birthDate', 'birth_date', 'birthday']);
    final email = _text('email');
    final nationality = _firstNonEmpty(const ['nationality', 'citizenship', 'nationa']);
    final height = _text('height');
    final weight = _text('weight');
    final sportData = _firstNonEmpty(const ['sport_data', 'sportData'], '');

    return Container(
      decoration: _cardDecoration(radius: 30),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Row(
              children: [
                if (onBack != null) ...[
                  _RosterHeaderAction(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Назад',
                    onTap: onBack!,
                  ),
                  const SizedBox(width: 12),
                ],
                _LogoBox(
                  url: photo.isEmpty ? null : photo,
                  size: 88,
                  bgColor: const Color(0xFFF8FAFC),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.text,
                          fontSize: 25,
                          height: 1.06,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _RosterInfoPill(text: position, color: _C.graphite, bg: const Color(0xFFF7F7F8)),
                          _RosterInfoPill(text: '№ $number', color: _C.graphite, bg: const Color(0xFFF1F5F9)),
                          _RosterInfoPill(text: teamName, color: _C.graphite, bg: const Color(0xFFF8FAFC)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onOpenFull != null) ...[
                  const SizedBox(width: 12),
                  _RosterFullProfileButton(onTap: onOpenFull!),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Дата рождения',
                        value: birth,
                        icon: Icons.cake_rounded,
                        bg: const Color(0xFFFFF7ED),
                        iconColor: const Color(0xFFEA580C),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Амплуа',
                        value: position,
                        icon: Icons.sports_soccer_rounded,
                        bg: const Color(0xFFEAF7EE),
                        iconColor: const Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Номер',
                        value: number,
                        icon: Icons.tag_rounded,
                        bg: const Color(0xFFF1F5F9),
                        iconColor: _C.graphite,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Рост',
                        value: height,
                        icon: Icons.height_rounded,
                        bg: const Color(0xFFF1F5F9),
                        iconColor: _C.graphite,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Вес',
                        value: weight,
                        icon: Icons.monitor_weight_outlined,
                        bg: const Color(0xFFF1F5F9),
                        iconColor: _C.graphite,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Гражданство',
                        value: nationality,
                        icon: Icons.flag_rounded,
                        bg: const Color(0xFFFFFBEB),
                        iconColor: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SolidCard(
                  title: 'Контакты',
                  helpText:
                      'Контактные данные нужны для связи с игроком или родителем. Если email пустой — проверьте карточку игрока.',
                  helpSteps: const [
                    'Откройте полный профиль игрока.',
                    'Проверьте email и дополнительные контакты.',
                    'После правки вернитесь в состав и обновите список.',
                  ],
                  child: _ProfileLine(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: email,
                  ),
                ),
                const SizedBox(height: 12),
                _SolidCard(
                  title: 'Спортивные данные',
                  helpText:
                      'Этот блок можно использовать для краткой характеристики игрока: ведущая нога, сильные стороны, текущие показатели и заметки тренера.',
                  helpSteps: const [
                    'Заполните ключевые спортивные данные в профиле игрока.',
                    'Не перегружайте текст — оставьте только полезное для тренера.',
                    'Для подробной аналитики используйте отдельные метрики и дневник тренировок.',
                  ],
                  child: Text(
                    sportData.isEmpty
                        ? 'Спортивные данные пока не заполнены.'
                        : sportData,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterFullProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RosterFullProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new_rounded, color: _C.black, size: 18),
            SizedBox(width: 8),
            Text(
              'Полный профиль',
              style: TextStyle(
                color: _C.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color bg;
  final Color iconColor;

  const _RosterMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.bg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: iconColor.withOpacity(.12)),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingsPanel extends StatelessWidget {
  final bool hasTeam;
  final VoidCallback onOpenPlans;
  final VoidCallback onOpenGraphics;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenFullTeam;

  const _TrainingsPanel(
      {required this.hasTeam,
      required this.onOpenPlans,
      required this.onOpenGraphics,
      required this.onOpenCalendar,
      required this.onOpenFullTeam});

  @override
  Widget build(BuildContext context) {
    if (!hasTeam) return const _NeedTeam();
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        _ModuleCard(
            icon: Icons.folder_copy_rounded,
            title: 'Планы-конспекты',
            subtitle: 'Папки, программы, вложения',
            onTap: onOpenPlans),
        _ModuleCard(
            icon: Icons.draw_rounded,
            title: 'Графический редактор',
            subtitle: 'Схемы и упражнения',
            onTap: onOpenGraphics),
        _ModuleCard(
            icon: Icons.calendar_month_rounded,
            title: 'Календарь тренировок',
            subtitle: 'Расписание и события',
            onTap: onOpenCalendar),
        _ModuleCard(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Посещаемость и оценка',
            subtitle: 'Журнал и рейтинг тренировки',
            onTap: onOpenFullTeam),
      ],
    );
  }
}




class _MobileMoreMenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final ClubSection section;
  final Color color;
  final bool pro;

  const _MobileMoreMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.section,
    required this.color,
    this.pro = false,
  });
}

class _MobileMoreBottomSheet extends StatelessWidget {
  final String clubName;
  final String selectedTeamName;
  final bool hasTeam;
  final ClubSection currentSection;
  final List<_MobileMoreMenuItem> items;
  final bool hasActiveSubscription;
  final ValueChanged<ClubSection> onSelect;

  const _MobileMoreBottomSheet({
    required this.clubName,
    required this.selectedTeamName,
    required this.hasTeam,
    required this.currentSection,
    required this.items,
    required this.hasActiveSubscription,
    required this.onSelect,
  });

  bool _needsTeam(ClubSection section) {
    return section == ClubSection.roster ||
        section == ClubSection.matches ||
        section == ClubSection.calendar ||
        section == ClubSection.plans ||
        section == ClubSection.videoAnalysis ||
        section == ClubSection.attendance ||
        section == ClubSection.graphics ||
        section == ClubSection.description ||
        section == ClubSection.challenges ||
        section == ClubSection.challengeCreate ||
        section == ClubSection.quizzes ||
        section == ClubSection.quizCreate ||
        section == ClubSection.rating ||
        section == ClubSection.manager ||
        section == ClubSection.miniGames;
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: h * .88),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: EdgeInsets.fromLTRB(14, 10, 14, 14 + bottom),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD0D5DD),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.text,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _C.text.withOpacity(.12),
                  blurRadius: 18,
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
                    color: Colors.white.withOpacity(.10),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: Colors.white.withOpacity(.12)),
                  ),
                  child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Разделы клуба',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hasTeam
                            ? 'Активная команда: $selectedTeamName'
                            : 'Выберите команду, чтобы открыть командные модули',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ProStatusPill(active: hasActiveSubscription, dark: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.34,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final active = item.section == currentSection ||
                    (item.section == ClubSection.trainers && currentSection == ClubSection.teamTrainers);
                final needsTeam = _needsTeam(item.section) && !hasTeam;
                final locked = item.pro && !hasActiveSubscription;

                return _MobileMoreTile(
                  item: item,
                  active: active,
                  disabled: needsTeam,
                  locked: locked,
                  onTap: () {
                    if (needsTeam) {
                      Get.snackbar('Команда', 'Сначала выберите активную команду');
                      return;
                    }
                    onSelect(item.section);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileMoreTile extends StatelessWidget {
  final _MobileMoreMenuItem item;
  final bool active;
  final bool disabled;
  final bool locked;
  final VoidCallback onTap;

  const _MobileMoreTile({
    required this.item,
    required this.active,
    required this.disabled,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = disabled ? .48 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active ? item.color.withOpacity(.10) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? item.color.withOpacity(.28) : _C.border,
                width: active ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.035),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item.icon, color: item.color, size: 21),
                        ),
                        const Spacer(),
                        if (item.pro) _ProStatusPill(active: !locked),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 13,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      disabled ? 'Выберите команду' : item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 10.5,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (active)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(Icons.check_circle_rounded, color: item.color, size: 19),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainersModuleContent extends StatefulWidget {
  final List<Map<String, dynamic>> trainers;
  final int teamsCount;
  final int playersCount;
  final String selectedTeamName;
  final bool proActive;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenRoster;

  const _TrainersModuleContent({
    required this.trainers,
    required this.teamsCount,
    required this.playersCount,
    required this.selectedTeamName,
    required this.proActive,
    required this.onOpenTrainers,
    required this.onOpenTeams,
    required this.onOpenRoster,
  });

  @override
  State<_TrainersModuleContent> createState() => _TrainersModuleContentState();
}

class _TrainersModuleContentState extends State<_TrainersModuleContent> {
  int selectedIndex = 0;

  String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  int _i(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  String _trainerName(Map<String, dynamic> trainer) {
    final full = _s(trainer['full_name']).isNotEmpty
        ? _s(trainer['full_name'])
        : _s(trainer['fullName']).isNotEmpty
            ? _s(trainer['fullName'])
            : _s(trainer['name']).isNotEmpty
                ? _s(trainer['name'])
                : '${_s(trainer['first_name'])} ${_s(trainer['last_name'])}'.trim();
    return full.isEmpty ? 'Тренер' : full;
  }

  String _trainerRole(Map<String, dynamic> trainer) {
    final raw = (_s(trainer['role']).isNotEmpty
            ? _s(trainer['role'])
            : _s(trainer['position']).isNotEmpty
                ? _s(trainer['position'])
                : _s(trainer['specialization']))
        .trim();
    if (raw.isEmpty) return 'Тренер';
    final lower = raw.toLowerCase();
    if (lower == 'coach' || lower == 'trainer') return 'Тренер';
    if (lower == 'head coach') return 'Главный тренер';
    if (lower == 'assistant coach') return 'Ассистент тренера';
    if (lower == 'manager') return 'Менеджер';
    if (lower == 'admin' || lower == 'administrator') return 'Администратор';
    return raw;
  }

  String _trainerTeam(Map<String, dynamic> trainer) {
    final teamName = _s(trainer['team_name'] ?? trainer['teamName']);
    if (teamName.isNotEmpty) return teamName;
    final teamId = _i(trainer['team_id'] ?? trainer['teamId']);
    if (teamId > 0) return 'Команда #$teamId';
    return 'Команда не назначена';
  }

  String _trainerPhone(Map<String, dynamic> trainer) =>
      _s(trainer['phone'] ?? trainer['phone_number'] ?? trainer['mobile']);

  String _trainerEmail(Map<String, dynamic> trainer) => _s(trainer['email']);

  String _trainerPhoto(Map<String, dynamic> trainer) {
    final raw = _s(trainer['photo'] ??
        trainer['avatar'] ??
        trainer['image'] ??
        trainer['photo_url'] ??
        trainer['avatar_url']);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
    return 'https://sportotekaapp.ru/$cleaned';
  }

  bool _hasActiveTeam() {
    return widget.selectedTeamName.trim().isNotEmpty &&
        widget.selectedTeamName != 'Команда не выбрана';
  }

  int _assignedCount() {
    return widget.trainers.where((trainer) {
      final teamId = _i(trainer['team_id'] ?? trainer['teamId']);
      final teamName = _s(trainer['team_name'] ?? trainer['teamName']);
      return teamId > 0 || teamName.isNotEmpty;
    }).length;
  }

  @override
  void didUpdateWidget(covariant _TrainersModuleContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selectedIndex >= widget.trainers.length) selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final trainers = widget.trainers;
    final selectedTrainer = trainers.isEmpty
        ? null
        : trainers[selectedIndex.clamp(0, trainers.length - 1)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final listWidth = math.min(430.0, constraints.maxWidth * .42);

        final trainersList = Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(radius: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.badge_rounded,
                      color: _C.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Тренеры клуба',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _C.text,
                            fontSize: 18,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.selectedTeamName} · ${trainers.length} тренеров',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _HelpCircle(
                    title: 'Как работать с тренерами',
                    text:
                        'Тренеры — рабочая зона управления специалистами клуба. Здесь удобно выбрать тренера, проверить роль, команду и контакты.',
                    steps: [
                      'Нажмите на тренера в списке, чтобы открыть подробности справа.',
                      'Проверяйте привязку к команде, роль, телефон и email в карточке справа.',
                      'Используйте кнопку редактирования, чтобы перейти к управлению тренерами клуба.',
                    ],
                    icon: Icons.tips_and_updates_rounded,
                    size: 38,
                  ),
                  const SizedBox(width: 8),
                  _RosterHeaderAction(
                    icon: Icons.manage_accounts_rounded,
                    tooltip: 'Управление тренерами',
                    onTap: widget.onOpenTrainers,
                  ),
                  const SizedBox(width: 8),
                  _RosterHeaderAction(
                    icon: Icons.groups_2_rounded,
                    tooltip: 'Открыть состав',
                    onTap: widget.onOpenRoster,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _RosterAdviceCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Совет по штабу',
                text:
                    'Заполните роль, контакты и команду тренера — так в рабочем окне сразу видно, кто за что отвечает.',
              ),
              const SizedBox(height: 14),
              Expanded(
                child: trainers.isEmpty
                    ? Center(
                        child: _TrainerEmptyInline(onOpenTrainers: widget.onOpenTrainers),
                      )
                    : RefreshIndicator(
                        color: _C.primaryGreen,
                        onRefresh: () async {},
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: trainers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final trainer = trainers[index];
                            return _TrainerWorkTile(
                              trainer: trainer,
                              active: index == selectedIndex,
                              index: index,
                              name: _trainerName(trainer),
                              role: _trainerRole(trainer),
                              team: _trainerTeam(trainer),
                              photo: _trainerPhoto(trainer),
                              onTap: () => setState(() => selectedIndex = index),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );

        final details = _TrainerPanelCard(
          trainer: selectedTrainer,
          trainerName: _trainerName,
          trainerRole: _trainerRole,
          trainerTeam: _trainerTeam,
          trainerPhone: _trainerPhone,
          trainerEmail: _trainerEmail,
          trainerPhoto: _trainerPhoto,
          onEdit: widget.onOpenTrainers,
          onOpenRoster: widget.onOpenRoster,
        );

        if (compact) {
          return Column(
            children: [
              SizedBox(height: 460, child: trainersList),
              const SizedBox(height: 12),
              Expanded(child: details),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: listWidth, child: trainersList),
            const SizedBox(width: 12),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class _TrainerWorkTile extends StatelessWidget {
  final Map<String, dynamic> trainer;
  final bool active;
  final int index;
  final String name;
  final String role;
  final String team;
  final String photo;
  final VoidCallback onTap;

  const _TrainerWorkTile({
    required this.trainer,
    required this.active,
    required this.index,
    required this.name,
    required this.role,
    required this.team,
    required this.photo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initialsBg = active ? _C.primaryGreen : const Color(0xFFF8FAFC);
    final borderColor = active ? _C.primaryGreen.withOpacity(.34) : const Color(0xFFE5E7EB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? _C.greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: active ? 1.2 : 1),
            boxShadow: [
              BoxShadow(
                color: active
                    ? _C.primaryGreen.withOpacity(.10)
                    : Colors.black.withOpacity(.025),
                blurRadius: active ? 18 : 12,
                offset: Offset(0, active ? 8 : 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _TrainerAvatar(photo: photo, name: name, size: 50),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: initialsBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: active ? Colors.white : _C.muted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 14.5,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _RosterInfoPill(
                          text: role,
                          color: _C.graphite,
                          bg: const Color(0xFFF7F7F8),
                        ),
                        _RosterInfoPill(
                          text: team,
                          color: _C.graphite,
                          bg: const Color(0xFFF1F5F9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: active ? _C.primaryGreen : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(color: active ? _C.primaryGreen : _C.border),
                ),
                child: Icon(
                  active ? Icons.check_rounded : Icons.chevron_right_rounded,
                  color: active ? Colors.white : _C.muted,
                  size: active ? 17 : 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainerPanelCard extends StatelessWidget {
  final Map<String, dynamic>? trainer;
  final String Function(Map<String, dynamic>) trainerName;
  final String Function(Map<String, dynamic>) trainerRole;
  final String Function(Map<String, dynamic>) trainerTeam;
  final String Function(Map<String, dynamic>) trainerPhone;
  final String Function(Map<String, dynamic>) trainerEmail;
  final String Function(Map<String, dynamic>) trainerPhoto;
  final VoidCallback onEdit;
  final VoidCallback onOpenRoster;

  const _TrainerPanelCard({
    required this.trainer,
    required this.trainerName,
    required this.trainerRole,
    required this.trainerTeam,
    required this.trainerPhone,
    required this.trainerEmail,
    required this.trainerPhoto,
    required this.onEdit,
    required this.onOpenRoster,
  });

  @override
  Widget build(BuildContext context) {
    if (trainer == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(radius: 30),
        child: const Center(
          child: _EmptyText('Выберите тренера слева.'),
        ),
      );
    }

    final t = trainer!;
    final name = trainerName(t);
    final role = trainerRole(t);
    final team = trainerTeam(t);
    final phone = trainerPhone(t);
    final email = trainerEmail(t);
    final photo = trainerPhoto(t);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrainerAvatar(photo: photo, name: name, size: 86),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 22,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _RosterInfoPill(
                          text: role,
                          color: _C.graphite,
                          bg: const Color(0xFFF7F7F8),
                        ),
                        _RosterInfoPill(
                          text: team,
                          color: _C.graphite,
                          bg: const Color(0xFFF1F5F9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _HelpCircle(
                title: 'Карточка тренера',
                text:
                    'Здесь отображается краткая информация по выбранному специалисту: роль, команда и контакты.',
                steps: const [
                  'Проверьте, назначен ли тренер к нужной команде.',
                  'Заполните телефон и email, чтобы быстро связаться со специалистом.',
                  'Через редактирование можно обновить данные тренера.',
                ],
                icon: Icons.info_outline_rounded,
                size: 38,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _RosterMetricCard(
                  icon: Icons.badge_rounded,
                  title: 'Роль',
                  value: role,
                  bg: const Color(0xFFF7F7F8),
                  iconColor: _C.graphite,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RosterMetricCard(
                  icon: Icons.groups_2_rounded,
                  title: 'Команда',
                  value: team,
                  bg: const Color(0xFFF1F5F9),
                  iconColor: _C.graphite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TrainerContactTile(
            kind: _TrainerGlyphKind.phone,
            title: 'Телефон',
            value: phone.isEmpty ? 'Не указан' : phone,
          ),
          const SizedBox(height: 8),
          _TrainerContactTile(
            kind: _TrainerGlyphKind.mail,
            title: 'Email',
            value: email.isEmpty ? 'Не указан' : email,
          ),
          const SizedBox(height: 14),
          _RosterAdviceCard(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Подсказка',
            text:
                'Для рабочего процесса лучше назначать каждому тренеру конкретную команду и роль: главный тренер, ассистент, тренер вратарей или администратор.',
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _TrainerPanelButton(
                  icon: Icons.manage_accounts_rounded,
                  title: 'Редактировать',
                  onTap: onEdit,
                  filled: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrainerPanelButton(
                  icon: Icons.groups_2_rounded,
                  title: 'Состав',
                  onTap: onOpenRoster,
                  filled: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainerPanelButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool filled;

  const _TrainerPanelButton({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled ? _C.primaryGreen : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: filled ? _C.primaryGreen : _C.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? Colors.white : _C.text, size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: filled ? Colors.white : _C.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerEmptyInline extends StatelessWidget {
  final VoidCallback onOpenTrainers;
  const _TrainerEmptyInline({required this.onOpenTrainers});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.badge_rounded, color: _C.black, size: 28),
        ),
        const SizedBox(height: 12),
        const Text(
          'Тренеры пока не добавлены',
          textAlign: TextAlign.center,
          style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Добавьте тренера или назначьте специалиста к команде.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _C.muted, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        _TrainerPanelButton(
          icon: Icons.manage_accounts_rounded,
          title: 'Управление тренерами',
          onTap: onOpenTrainers,
          filled: true,
        ),
      ],
    );
  }
}


class _TrainerTopStrip extends StatelessWidget {
  final int trainersCount;
  final int assignedCount;
  final String selectedTeamName;
  final bool hasActiveTeam;
  final bool proActive;
  final VoidCallback onEdit;

  const _TrainerTopStrip({
    required this.trainersCount,
    required this.assignedCount,
    required this.selectedTeamName,
    required this.hasActiveTeam,
    required this.proActive,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 760;
    final teamText = hasActiveTeam ? selectedTeamName : 'Команда не выбрана';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            _C.greenSoft.withOpacity(.30),
            _C.soft2.withOpacity(.72),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.022),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TrainerSmallStat(value: '$trainersCount', label: 'тренеров'),
                    const SizedBox(width: 8),
                    _TrainerSmallStat(value: '$assignedCount', label: 'назначено'),
                    const Spacer(),
                    _ProStatusPill(active: proActive),
                    const SizedBox(width: 8),
                    const _HelpCircle(
                      title: 'Как работать с тренерами',
                      text: 'Раздел тренеров показывает специалистов клуба и помогает быстро открыть карточку тренера, проверить контакты и назначение к команде.',
                      steps: [
                        'Выберите тренера в списке слева или сверху на телефоне.',
                        'Справа откроется подробная карточка с фото, ролью, командой и контактами.',
                        'Нажмите «Редактировать», чтобы перейти к управлению тренерами клуба.',
                      ],
                      size: 32,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TrainerTeamLine(teamText: teamText),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _TrainerEditButton(onTap: onEdit),
                ),
              ],
            )
          : Row(
              children: [
                _TrainerSmallStat(value: '$trainersCount', label: 'тренеров'),
                const SizedBox(width: 8),
                _TrainerSmallStat(value: '$assignedCount', label: 'назначено'),
                const SizedBox(width: 12),
                Expanded(child: _TrainerTeamLine(teamText: teamText)),
                const SizedBox(width: 10),
                _ProStatusPill(active: proActive),
                const SizedBox(width: 8),
                const _HelpCircle(
                  title: 'Как работать с тренерами',
                  text: 'Раздел тренеров показывает специалистов клуба и помогает быстро открыть карточку тренера, проверить контакты и назначение к команде.',
                  steps: [
                    'Выберите тренера в списке слева.',
                    'Справа откроется подробная карточка с фото, ролью, командой и контактами.',
                    'Нажмите «Редактировать», чтобы перейти к управлению тренерами клуба.',
                  ],
                  size: 32,
                ),
                const SizedBox(width: 10),
                _TrainerEditButton(onTap: onEdit),
              ],
            ),
    );
  }
}

class _TrainerSmallStat extends StatelessWidget {
  final String value;
  final String label;
  const _TrainerSmallStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: _C.primaryGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w900)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: _C.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TrainerTeamLine extends StatelessWidget {
  final String teamText;
  const _TrainerTeamLine({required this.teamText});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: _C.primaryGreen, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teamText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrainerEditButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TrainerEditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: _C.primaryGreen,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _C.primaryGreen.withOpacity(.14),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TrainerGlyph(kind: _TrainerGlyphKind.clipboard, color: Colors.white, size: 18),
            SizedBox(width: 7),
            Text(
              'Редактировать',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerCompactList extends StatelessWidget {
  final List<Map<String, dynamic>> trainers;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String Function(Map<String, dynamic>) trainerName;
  final String Function(Map<String, dynamic>) trainerRole;
  final String Function(Map<String, dynamic>) trainerTeam;
  final String Function(Map<String, dynamic>) trainerPhoto;
  final bool isMobile;

  const _TrainerCompactList({
    required this.trainers,
    required this.selectedIndex,
    required this.onSelect,
    required this.trainerName,
    required this.trainerRole,
    required this.trainerTeam,
    required this.trainerPhoto,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(radius: 26),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: List.generate(trainers.length, (index) {
          final trainer = trainers[index];
          final selected = index == selectedIndex;
          return Padding(
            padding: EdgeInsets.only(bottom: index == trainers.length - 1 ? 0 : 8),
            child: _TrainerCompactRow(
              trainer: trainer,
              selected: selected,
              onTap: () => onSelect(index),
              name: trainerName(trainer),
              role: trainerRole(trainer),
              team: trainerTeam(trainer),
              photo: trainerPhoto(trainer),
              isMobile: isMobile,
            ),
          );
        }),
      ),
    );
  }
}

class _TrainerCompactRow extends StatelessWidget {
  final Map<String, dynamic> trainer;
  final bool selected;
  final VoidCallback onTap;
  final String name;
  final String role;
  final String team;
  final String photo;
  final bool isMobile;

  const _TrainerCompactRow({
    required this.trainer,
    required this.selected,
    required this.onTap,
    required this.name,
    required this.role,
    required this.team,
    required this.photo,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        decoration: BoxDecoration(
          color: selected ? _C.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _C.primaryGreen.withOpacity(.22) : Colors.transparent),
        ),
        child: Row(
          children: [
            _TrainerAvatar(photo: photo, name: name, size: isMobile ? 42 : 46),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _C.text,
                      fontSize: isMobile ? 13.2 : 14.2,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _TrainerMicroChip(text: role, color: _C.primaryGreen),
                      _TrainerMicroChip(text: team, color: _C.blue),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _TrainerSelectionMark(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _TrainerDetailWorkCard extends StatelessWidget {
  final Map<String, dynamic> trainer;
  final String Function(Map<String, dynamic>) trainerName;
  final String Function(Map<String, dynamic>) trainerRole;
  final String Function(Map<String, dynamic>) trainerTeam;
  final String Function(Map<String, dynamic>) trainerPhone;
  final String Function(Map<String, dynamic>) trainerEmail;
  final String Function(Map<String, dynamic>) trainerPhoto;
  final VoidCallback onEdit;
  final bool compact;

  const _TrainerDetailWorkCard({
    required this.trainer,
    required this.trainerName,
    required this.trainerRole,
    required this.trainerTeam,
    required this.trainerPhone,
    required this.trainerEmail,
    required this.trainerPhoto,
    required this.onEdit,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = trainerName(trainer);
    final role = trainerRole(trainer);
    final team = trainerTeam(trainer);
    final phone = trainerPhone(trainer);
    final email = trainerEmail(trainer);
    final photo = trainerPhoto(trainer);

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            _C.greenSoft.withOpacity(.32),
            _C.soft2.withOpacity(.70),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.022),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrainerAvatar(photo: photo, name: name, size: compact ? 70 : 84),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.text,
                        fontSize: compact ? 17 : 19,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _TrainerMicroChip(text: role, color: _C.primaryGreen),
                        _TrainerMicroChip(text: team, color: _C.blue),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TrainerContactTile(
            kind: _TrainerGlyphKind.phone,
            title: 'Телефон',
            value: phone.isEmpty ? 'Не указан' : phone,
          ),
          const SizedBox(height: 8),
          _TrainerContactTile(
            kind: _TrainerGlyphKind.mail,
            title: 'Email',
            value: email.isEmpty ? 'Не указан' : email,
          ),
          const SizedBox(height: 8),
          _TrainerContactTile(
            kind: _TrainerGlyphKind.team,
            title: 'Команда',
            value: team,
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: _TrainerEditButton(onTap: onEdit)),
        ],
      ),
    );
  }
}

class _TrainerAvatar extends StatelessWidget {
  final String photo;
  final String name;
  final double size;
  const _TrainerAvatar({required this.photo, required this.name, required this.size});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'Т';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(size * .36),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.026),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: hasPhoto
          ? Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _InitialsBadge(initials: _initials),
            )
          : _InitialsBadge(initials: _initials),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  final String initials;
  const _InitialsBadge({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: _C.primaryGreen,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TrainerMicroChip extends StatelessWidget {
  final String text;
  final Color color;
  const _TrainerMicroChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _C.softFor(color),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          height: 1.05,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}



enum _TrainerGlyphKind { staff, whistle, clipboard, phone, mail, team, check, arrow }

class _TrainerGlyphBadge extends StatelessWidget {
  final _TrainerGlyphKind kind;
  final double size;
  const _TrainerGlyphBadge({required this.kind, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(size * .34),
        border: Border.all(color: _C.primaryGreen.withOpacity(.10)),
      ),
      child: Center(
        child: _TrainerGlyph(kind: kind, color: _C.primaryGreen, size: size * .48),
      ),
    );
  }
}

class _TrainerSelectionMark extends StatelessWidget {
  final bool selected;
  const _TrainerSelectionMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: selected ? 24 : 22,
      height: selected ? 24 : 22,
      decoration: BoxDecoration(
        color: selected ? _C.primaryGreen : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: selected ? _C.primaryGreen : _C.border),
      ),
      child: Center(
        child: _TrainerGlyph(
          kind: selected ? _TrainerGlyphKind.check : _TrainerGlyphKind.arrow,
          color: selected ? Colors.white : _C.muted,
          size: selected ? 14 : 13,
        ),
      ),
    );
  }
}

class _TrainerGlyph extends StatelessWidget {
  final _TrainerGlyphKind kind;
  final Color color;
  final double size;
  const _TrainerGlyph({required this.kind, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TrainerGlyphPainter(kind: kind, color: color),
      ),
    );
  }
}

class _TrainerGlyphPainter extends CustomPainter {
  final _TrainerGlyphKind kind;
  final Color color;
  const _TrainerGlyphPainter({required this.kind, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * .105).clamp(1.4, 2.4)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color..style = PaintingStyle.fill;

    switch (kind) {
      case _TrainerGlyphKind.staff:
        canvas.drawCircle(Offset(w * .36, h * .30), w * .13, p);
        canvas.drawCircle(Offset(w * .64, h * .30), w * .13, p);
        canvas.drawArc(Rect.fromLTWH(w * .15, h * .48, w * .42, h * .34), math.pi, math.pi, false, p);
        canvas.drawArc(Rect.fromLTWH(w * .43, h * .48, w * .42, h * .34), math.pi, math.pi, false, p);
        canvas.drawLine(Offset(w * .50, h * .16), Offset(w * .50, h * .86), p..strokeWidth = (w * .07).clamp(1.2, 2.0));
        break;
      case _TrainerGlyphKind.whistle:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .18, h * .34, w * .54, h * .36), Radius.circular(w * .16)), p);
        canvas.drawCircle(Offset(w * .42, h * .52), w * .07, p);
        canvas.drawPath(Path()..moveTo(w*.72,h*.42)..lineTo(w*.92,h*.34)..lineTo(w*.82,h*.54), p);
        break;
      case _TrainerGlyphKind.clipboard:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.22,h*.16,w*.56,h*.70), Radius.circular(w*.10)), p);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.36,h*.10,w*.28,h*.16), Radius.circular(w*.06)), p);
        canvas.drawLine(Offset(w*.36,h*.42), Offset(w*.64,h*.42), p);
        canvas.drawLine(Offset(w*.36,h*.58), Offset(w*.60,h*.58), p);
        break;
      case _TrainerGlyphKind.phone:
        canvas.drawPath(Path()
          ..moveTo(w*.30,h*.18)..cubicTo(w*.20,h*.26,w*.24,h*.48,w*.42,h*.66)
          ..cubicTo(w*.58,h*.82,w*.78,h*.84,w*.86,h*.72), p);
        canvas.drawLine(Offset(w*.30,h*.18), Offset(w*.42,h*.30), p);
        canvas.drawLine(Offset(w*.70,h*.62), Offset(w*.86,h*.72), p);
        break;
      case _TrainerGlyphKind.mail:
        final r = Rect.fromLTWH(w*.14,h*.24,w*.72,h*.52);
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(w*.09)), p);
        canvas.drawPath(Path()..moveTo(w*.18,h*.30)..lineTo(w*.50,h*.55)..lineTo(w*.82,h*.30), p);
        break;
      case _TrainerGlyphKind.team:
        canvas.drawCircle(Offset(w*.34,h*.34), w*.11, p);
        canvas.drawCircle(Offset(w*.66,h*.34), w*.11, p);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.18,h*.56,w*.64,h*.24), Radius.circular(w*.12)), p);
        break;
      case _TrainerGlyphKind.check:
        canvas.drawPath(Path()..moveTo(w*.24,h*.52)..lineTo(w*.43,h*.70)..lineTo(w*.78,h*.30), p);
        break;
      case _TrainerGlyphKind.arrow:
        canvas.drawPath(Path()..moveTo(w*.36,h*.22)..lineTo(w*.64,h*.50)..lineTo(w*.36,h*.78), p);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TrainerGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}

class _TrainerContactTile extends StatelessWidget {
  final _TrainerGlyphKind kind;
  final String title;
  final String value;
  const _TrainerContactTile({required this.kind, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _TrainerGlyph(kind: kind, color: _C.primaryGreen, size: 18),
          const SizedBox(width: 9),
          SizedBox(
            width: 72,
            child: Text(
              title,
              style: const TextStyle(color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerEmptyWorkarea extends StatelessWidget {
  final VoidCallback onOpenTrainers;
  const _TrainerEmptyWorkarea({required this.onOpenTrainers});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(radius: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TrainerGlyphBadge(kind: _TrainerGlyphKind.staff, size: 62),
          const SizedBox(height: 12),
          const Text(
            'Тренеры пока не добавлены',
            textAlign: TextAlign.center,
            style: TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Добавьте тренера или назначьте специалиста к команде.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _C.muted, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          _TrainerEditButton(onTap: onOpenTrainers),
        ],
      ),
    );
  }
}


class _TrainerMobileSummaryCard extends StatelessWidget {
  final bool proActive;
  final int percent;
  final String selectedTeamName;
  final bool hasActiveTeam;
  final int trainersCount;
  final int assignedCount;
  final int infoPercent;
  final String adminName;
  final VoidCallback onOpenTrainers;

  const _TrainerMobileSummaryCard({
    required this.proActive,
    required this.percent,
    required this.selectedTeamName,
    required this.hasActiveTeam,
    required this.trainersCount,
    required this.assignedCount,
    required this.infoPercent,
    required this.adminName,
    required this.onOpenTrainers,
  });

  @override
  Widget build(BuildContext context) {
    final teamText = hasActiveTeam ? selectedTeamName : 'Команда не выбрана';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _C.blueSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.border),
                ),
                child: const Icon(
                  Icons.supervisor_account_rounded,
                  color: _C.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Тренеры клуба',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 18,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ProStatusPill(active: proActive),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Команда: $teamText',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MobileTrainerNumber(value: '$trainersCount', label: 'тренеров'),
              const SizedBox(width: 8),
              _MobileTrainerNumber(value: '$assignedCount', label: 'назначено'),
              const SizedBox(width: 8),
              _MobileTrainerNumber(value: '$infoPercent%', label: 'данные'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Text(
                    'заполненность раздела',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _C.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 100) / 100,
              minHeight: 8,
              backgroundColor: _C.soft,
              color: _C.primaryGreen,
            ),
          ),
          if (adminName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ответственный: $adminName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileTrainerNumber extends StatelessWidget {
  final String value;
  final String label;

  const _MobileTrainerNumber({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: _C.soft2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.text,
                fontSize: 16,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerHeroPanel extends StatelessWidget {
  final bool isMobile;
  final bool proActive;
  final int percent;
  final String selectedTeamName;
  final bool hasActiveTeam;
  final int trainersCount;
  final int assignedCount;
  final int infoPercent;
  final String adminName;

  const _TrainerHeroPanel({
    required this.isMobile,
    required this.proActive,
    required this.percent,
    required this.selectedTeamName,
    required this.hasActiveTeam,
    required this.trainersCount,
    required this.assignedCount,
    required this.infoPercent,
    required this.adminName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: _C.black,
        borderRadius: BorderRadius.circular(isMobile ? 24 : 30),
        boxShadow: [
          BoxShadow(
            color: _C.black.withOpacity(.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isMobile ? 50 : 60,
                height: isMobile ? 50 : 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(.14)),
                ),
                child: const Icon(Icons.supervisor_account_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Тренерский штаб',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _ProStatusPill(active: proActive, dark: true),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      hasActiveTeam
                          ? 'Активная команда: $selectedTeamName. Раздел показывает назначения, заполненность профилей и готовность тренерского блока.'
                          : 'Выберите активную команду, чтобы управлять назначениями и видеть точную заполненность.',
                      maxLines: isMobile ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.72),
                        fontSize: isMobile ? 12 : 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 34 : 42,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'готовность раздела',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 100) / 100,
              minHeight: 9,
              backgroundColor: Colors.white.withOpacity(.12),
              color: _C.primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TrainerDarkChip(text: '$trainersCount тренеров'),
              _TrainerDarkChip(text: '$assignedCount назначено'),
              _TrainerDarkChip(text: 'информация $infoPercent%'),
              if (adminName.isNotEmpty) _TrainerDarkChip(text: 'ответственный: $adminName'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainerStatusPanel extends StatelessWidget {
  final bool isMobile;
  final int percent;
  final List<String> missing;
  final int trainersCount;
  final int assignedCount;
  final int filledProfiles;
  final int infoPercent;
  final VoidCallback onOpenTrainers;

  const _TrainerStatusPanel({
    required this.isMobile,
    required this.percent,
    required this.missing,
    required this.trainersCount,
    required this.assignedCount,
    required this.filledProfiles,
    required this.infoPercent,
    required this.onOpenTrainers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 15 : 18),
      decoration: _cardDecoration(radius: isMobile ? 22 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.fact_check_rounded, color: _C.primaryGreen, size: 21),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Заполненность данных тренеров',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TrainerChecklistRow(title: 'Тренеры добавлены', done: trainersCount > 0),
          _TrainerChecklistRow(title: 'Есть назначения к командам', done: assignedCount > 0),
          _TrainerChecklistRow(title: 'Профили заполнены', done: filledProfiles > 0),
          _TrainerChecklistRow(title: 'Контакты, роли и фото заполнены', done: infoPercent >= 70),
          const SizedBox(height: 12),
          if (missing.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: missing.map((item) => _TrainerHintChip(text: item)).toList(),
            )
          else
            const Text(
              'Раздел выглядит хорошо: тренеры добавлены, назначения и основные данные заполнены.',
              style: TextStyle(
                color: _C.muted,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _TrainerListPreview extends StatelessWidget {
  final List<Map<String, dynamic>> trainers;
  final bool isMobile;
  final String Function(Map<String, dynamic>) trainerName;
  final String Function(Map<String, dynamic>) trainerRole;
  final int Function(Map<String, dynamic>) fillPercent;

  const _TrainerListPreview({
    required this.trainers,
    required this.isMobile,
    required this.trainerName,
    required this.trainerRole,
    required this.fillPercent,
  });

  String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  @override
  Widget build(BuildContext context) {
    final visible = trainers.take(isMobile ? 3 : 4).toList();
    return Container(
      padding: EdgeInsets.all(isMobile ? 15 : 18),
      decoration: _cardDecoration(radius: isMobile ? 22 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Краткая информация по тренерам',
            style: TextStyle(
              color: _C.text,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...visible.map((trainer) {
            final name = trainerName(trainer).isEmpty ? 'Тренер' : trainerName(trainer);
            final role = trainerRole(trainer).isEmpty ? 'Роль не указана' : trainerRole(trainer);
            final team = _s(trainer['team_name'] ?? trainer['teamName']);
            final percent = fillPercent(trainer);

            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _C.soft2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _C.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _C.blueSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.border),
                    ),
                    child: const Icon(Icons.person_rounded, color: _C.blue, size: 21),
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
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          team.isEmpty ? role : '$role • $team',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TrainerPercentBadge(percent: percent),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TrainerDarkChip extends StatelessWidget {
  final String text;
  const _TrainerDarkChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TrainerChecklistRow extends StatelessWidget {
  final String title;
  final bool done;

  const _TrainerChecklistRow({required this.title, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: done ? _C.primaryGreen : _C.muted,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: done ? _C.text : _C.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerPercentBadge extends StatelessWidget {
  final int percent;

  const _TrainerPercentBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _C.primaryGreen.withOpacity(.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _C.primaryGreen.withOpacity(.22)),
      ),
      child: Text(
        '$percent%',
        style: const TextStyle(
          color: _C.primaryGreen,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TrainerMiniMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _TrainerMiniMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: _C.blue, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerHintChip extends StatelessWidget {
  final String text;

  const _TrainerHintChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _C.soft2,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _C.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _C.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TrainerActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _TrainerActionButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _C.soft2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _C.blue, size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _ProStatusPill extends StatelessWidget {
  final bool active;
  final bool dark;

  const _ProStatusPill({required this.active, this.dark = false});

  @override
  Widget build(BuildContext context) {
    // Такой же компактный бейдж, как в старом меню:
    // активная подписка — просто PRO, нет доступа — замок + PRO.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!active) ...[
            const Icon(
              Icons.lock_rounded,
              size: 11,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
          ],
          const Text(
            'PRO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamModulePanel extends StatelessWidget {
  final bool hasTeam;
  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryText;
  final VoidCallback onPrimary;
  final Widget? customContent;
  final List<_ModuleQuickAction> quickActions;
  final bool proActive;
  final bool showFullModuleCard;

  const _TeamModulePanel(
      {required this.hasTeam,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.primaryText,
      required this.onPrimary,
      this.customContent,
      this.quickActions = const [],
      this.proActive = false,
      this.showFullModuleCard = true});

  @override
  Widget build(BuildContext context) {
    if (!hasTeam) return const _NeedTeam();

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final columns = isMobile ? 2 : (width < 1180 ? 2 : 3);
    final headerPadding = isMobile ? 16.0 : 20.0;
    final iconSize = isMobile ? 52.0 : 60.0;
    final titleSize = isMobile ? 16.2 : 18.2;
    final subtitleSize = isMobile ? 11.4 : 12.2;

    final internalCards = <_ModuleQuickAction>[
      ...quickActions,
      if (showFullModuleCard)
        _ModuleQuickAction('Полный модуль', Icons.open_in_new_rounded, onPrimary),
    ];

    return ListView(
      padding: EdgeInsets.only(right: isMobile ? 0 : 2, bottom: 24),
      children: [
        Container(
          padding: EdgeInsets.all(headerPadding),
          decoration: _cardDecoration(radius: isMobile ? 24 : 30),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconBadge(icon: icon, size: iconSize, iconSize: 27),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: isMobile ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900,
                                  color: _C.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _C.muted,
                                  height: 1.25,
                                  fontSize: subtitleSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ProStatusPill(active: proActive),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _GreenButton(
                        icon: Icons.open_in_new_rounded,
                        text: primaryText,
                        onTap: onPrimary,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _IconBadge(icon: icon, size: iconSize, iconSize: 31),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: titleSize,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              color: _C.text,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _C.muted,
                              height: 1.28,
                              fontSize: subtitleSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ProStatusPill(active: proActive),
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 0,
                      child: _GreenButton(
                        icon: Icons.open_in_new_rounded,
                        text: primaryText,
                        onTap: onPrimary,
                        large: width > 1120,
                      ),
                    ),
                  ],
                ),
        ),
        if (customContent != null) ...[
          const SizedBox(height: 12),
          customContent!,
        ],
        if (internalCards.isNotEmpty) ...[
          const SizedBox(height: 12),
          GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isMobile ? 1.55 : 2.25,
          ),
          itemCount: internalCards.length,
          itemBuilder: (_, index) {
            final action = internalCards[index];
            return _ModuleCard(
              icon: action.icon,
              title: action.text,
              subtitle: index == internalCards.length - 1
                  ? 'Открыть рабочий экран'
                  : 'Быстрое действие',
              onTap: action.onTap,
            );
          },
          ),
        ],
      ],
    );
  }
}

class _ModuleQuickAction {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  const _ModuleQuickAction(this.text, this.icon, this.onTap);
}

class _TeamGuard extends StatelessWidget {
  final bool hasTeam;
  final Widget child;
  const _TeamGuard({required this.hasTeam, required this.child});
  @override
  Widget build(BuildContext context) =>
      hasTeam ? child : const _NeedTeam();
}

class _NeedTeam extends StatelessWidget {
  const _NeedTeam();
  @override
  Widget build(BuildContext context) => const _SolidPlaceholder(
      icon: Icons.info_rounded,
      title: 'Сначала выберите команду',
      subtitle:
          'Откройте раздел «Команды клуба» и выберите команду для работы.',
      chips: ['Команды', 'Состав', 'Матчи']);
}

class _SolidPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> chips;
  const _SolidPlaceholder(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.chips});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration(radius: 32),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBadge(icon: icon, size: 76, iconSize: 38),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _C.text)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _C.muted, height: 1.45)),
              const SizedBox(height: 18),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: chips
                      .map((e) => _LightChip(text: e))
                      .toList()),
            ]),
      ),
    );
  }
}

class _SolidCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final String? helpText;
  final List<String> helpSteps;
  const _SolidCard({
    required this.title,
    required this.child,
    this.trailing,
    this.helpText,
    this.helpSteps = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 28),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _C.text))),
              if (helpText != null) ...[
                const SizedBox(width: 8),
                _HelpCircle(
                  title: title,
                  text: helpText!,
                  steps: helpSteps,
                  size: 32,
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ]),
            const SizedBox(height: 14),
            child,
          ]),
    );
  }
}

class _ClubHeroCard extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String clubDescription;

  const _ClubHeroCard({
    required this.clubName,
    required this.clubLogo,
    required this.clubDescription,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 1120;
    final description = clubDescription.trim().isEmpty
        ? 'Единый рабочий кабинет клуба: команды, составы, тренеры, события и аналитика.'
        : clubDescription.trim();

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            _C.greenSoft.withOpacity(.34),
            _C.soft2.withOpacity(.76),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.022),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogoBox(url: clubLogo, size: compact ? 58 : 70, bgColor: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _C.text,
                    fontSize: compact ? 18 : 21,
                    height: 1.06,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: compact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _C.muted,
                    fontSize: compact ? 12.2 : 13.2,
                    height: 1.36,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String title;
  final Color color;
  const _HeroStat(
      {required this.value,
      required this.title,
      this.color = _C.primaryGreen});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: _C.softFor(color),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.16))),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 1),
        Text(title,
            style: const TextStyle(
                color: _C.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  const _MetricCard(
      {required this.icon,
      required this.title,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(radius: 22),
        child: Row(
          children: [
            _IconBadge(icon: icon, size: 38, iconSize: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: _C.accentForIcon(icon),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ModuleCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _C.accentForIcon(icon);
    final width = MediaQuery.of(context).size.width;
    final mobile = width < 700;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(mobile ? 13 : 16),
        decoration: _cardDecoration(radius: 24),
        child: Row(
          children: [
            _IconBadge(icon: icon, size: mobile ? 40 : 46, iconSize: mobile ? 20 : 23),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mobile ? 12.2 : 14.2,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      color: _C.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: mobile ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _C.muted,
                      fontSize: mobile ? 10.4 : 11.2,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: accent, size: mobile ? 20 : 24),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _ActionPill({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _C.accentForIcon(icon);
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 210),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _C.softFor(accent),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: accent.withOpacity(.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 17),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool large;
  const _GreenButton(
      {required this.icon,
      required this.text,
      required this.onTap,
      this.large = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: EdgeInsets.symmetric(
          horizontal: large ? 18 : 13,
          vertical: large ? 14 : 11,
        ),
        decoration: BoxDecoration(
          color: _C.primaryGreen,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _C.primaryGreen.withOpacity(.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: large ? 21 : 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: large ? 12.2 : 11.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _WhiteButton(
      {required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _C.black, size: 19),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  color: _C.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 13)),
        ]),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconCircleButton(
      {required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: _C.soft2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.border)),
          child: Icon(icon, color: _C.primaryGreen)),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallIconButton(
      {required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: _C.soft2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.border)),
          child: Icon(icon,
              color: _C.primaryGreen, size: 20)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  const _MiniStat(
      {required this.title, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final accent = icon == null
        ? _C.primaryGreen
        : _C.accentForIcon(icon!);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _C.softFor(accent),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: accent.withOpacity(.12))),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icon != null)
                Icon(icon, color: accent, size: 15),
              if (icon != null) const SizedBox(width: 6),
              Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _C.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)))
            ]),
            const SizedBox(height: 5),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _C.text,
                    fontWeight: FontWeight.w900)),
          ]),
    );
  }
}

class _DarkChip extends StatelessWidget {
  final String text;
  const _DarkChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: Colors.white.withOpacity(.06))),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800)),
    );
  }
}

class _LightChip extends StatelessWidget {
  final String text;
  const _LightChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(.86),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _C.border)),
      child: Text(text,
          style: const TextStyle(
              color: _C.black,
              fontWeight: FontWeight.w800)),
    );
  }
}

class _EventRow extends StatelessWidget {
  final String title;
  final String date;
  const _EventRow({required this.title, required this.date});

  @override
  Widget build(BuildContext context) {
    const accent = _C.teal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _C.tealSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: accent.withOpacity(.16))),
      child: Row(children: [
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(.9),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(
                Icons.event_available_rounded,
                color: accent,
                size: 18)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _C.text))),
        const SizedBox(width: 10),
        Text(date,
            style: const TextStyle(
                color: _C.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;
  const _EmptyText(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      style: const TextStyle(
          color: _C.muted, height: 1.4));
}

class _EmptyTeams extends StatelessWidget {
  final VoidCallback onCreateTeam;
  const _EmptyTeams({required this.onCreateTeam});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _SolidPlaceholder(
        icon: Icons.account_tree_rounded,
        title: 'Команды ещё не добавлены',
        subtitle:
            'Создайте первую команду клуба, чтобы открыть состав, матчи и тренировочный процесс.',
        chips: const ['Команда', 'Состав', 'Матчи'],
      ),
    );
  }
}

class _LargeActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _LargeActionButton(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(radius: 24),
        child: Row(children: [
          _IconBadge(icon: icon, size: 50, iconSize: 28),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _C.text)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: _C.muted)),
              ])),
          Icon(Icons.chevron_right_rounded,
              color: _C.accentForIcon(icon)),
        ]),
      ),
    );
  }
}

class _LogoBox extends StatelessWidget {
  final String? url;
  final double size;
  final Color? bgColor;
  const _LogoBox(
      {required this.url, required this.size, this.bgColor});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null &&
        url!.trim().isNotEmpty &&
        url != 'null';
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: bgColor ?? _C.soft,
          borderRadius:
              BorderRadius.circular(size * .34),
          border: Border.all(
              color: Colors.black.withOpacity(.045))),
      child: hasUrl
          ? Image.network(url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                  Icons.shield_rounded,
                  color: _C.primaryGreen,
                  size: size * .48))
          : Icon(Icons.shield_rounded,
              color: _C.primaryGreen,
              size: size * .48),
    );
  }
}

class _RotateTabletHint extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  const _RotateTabletHint(
      {required this.clubName, required this.clubLogo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Center(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(30),
          decoration: _cardDecoration(radius: 34),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LogoBox(
                    url: clubLogo,
                    size: 78,
                    bgColor: _C.soft),
                const SizedBox(height: 20),
                Text(clubName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _C.text)),
                const SizedBox(height: 8),
                const Text(
                    'Для полноценного рабочий кабинет-кабинета поверните планшет горизонтально.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _C.muted,
                        height: 1.45)),
                const SizedBox(height: 22),
                const Icon(
                    Icons.screen_rotation_alt_rounded,
                    color: _C.primaryGreen,
                    size: 58),
              ]),
        ),
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _ProfileLine(
      {required this.icon,
      required this.title,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon,
          color: _C.accentForIcon(icon), size: 22),
      const SizedBox(width: 12),
      Text('$title:',
          style: const TextStyle(
              color: _C.muted,
              fontWeight: FontWeight.w700)),
      const SizedBox(width: 8),
      Expanded(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _C.text,
                  fontWeight: FontWeight.w900))),
    ]);
  }
}


class _HelpCircle extends StatelessWidget {
  final String title;
  final String text;
  final List<String> steps;
  final IconData icon;
  final double size;

  const _HelpCircle({
    required this.title,
    required this.text,
    this.steps = const [],
    this.icon = Icons.help_outline_rounded,
    this.size = 34,
  });

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 620),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.10),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _C.greenSoft,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(icon, color: _C.primaryGreen, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 18,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: _C.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 13.5,
                      height: 1.42,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (steps.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ...List.generate(steps.length, (index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: _C.greenSoft,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: _C.primaryGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                steps[index],
                                style: const TextStyle(
                                  color: _C.text,
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Помощь',
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => _open(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: _C.primaryGreen, size: size * .55),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;
  const _IconBadge(
      {required this.icon,
      this.size = 58,
      this.iconSize = 30,
      this.color});

  @override
  Widget build(BuildContext context) {
    final accent = color ?? _C.accentForIcon(icon);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: _C.softFor(accent),
          borderRadius:
              BorderRadius.circular(size * .34),
          border: Border.all(
              color: accent.withOpacity(.18))),
      child: Icon(icon, color: accent, size: iconSize),
    );
  }
}

BoxDecoration _cardDecoration({double radius = 28}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _C.border),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
    ],
  );
}

class _ClubChatPanel extends StatelessWidget {
  final int userId;
  final VoidCallback onOpenFullChat;

  const _ClubChatPanel({
    required this.userId,
    required this.onOpenFullChat,
  });

  @override
  Widget build(BuildContext context) {
    if (userId <= 0) {
      return const _SolidPlaceholder(
        icon: Icons.forum_rounded,
        title: 'Чаты недоступны',
        subtitle:
            'Не удалось определить пользователя для загрузки чатов.',
        chips: ['Личные', 'Группы', 'Команда'],
      );
    }

    return Container(
      decoration: _cardDecoration(radius: 30),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            decoration: BoxDecoration(
              color: _C.purpleSoft,
              border: Border(
                bottom: BorderSide(
                    color: _C.purple.withOpacity(.12)),
              ),
            ),
            child: Row(
              children: [
                const _IconBadge(
                  icon: Icons.forum_rounded,
                  size: 48,
                  iconSize: 24,
                  color: _C.purple,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Чаты клуба',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _C.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Личные диалоги, группы и командное общение внутри рабочий кабинет',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _C.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _SmallIconButton(
                  icon: Icons.open_in_new_rounded,
                  onTap: onOpenFullChat,
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: ChatScreen(
                userId: userId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubIntroSplash extends StatelessWidget {
  final Animation<double> animation;
  const _ClubIntroSplash({required this.animation});

  @override
  Widget build(BuildContext context) {
    final ballValue = CurvedAnimation(
            parent: animation,
            curve:
                const Interval(0, .42, curve: Curves.elasticOut))
        .value;
    final titleValue = CurvedAnimation(
            parent: animation,
            curve: const Interval(.16, .55,
                curve: Curves.easeOutCubic))
        .value;
    final sloganValue = CurvedAnimation(
            parent: animation,
            curve: const Interval(.32, .68,
                curve: Curves.easeOutCubic))
        .value;
    final fadeOut = CurvedAnimation(
            parent: animation,
            curve: const Interval(.72, 1,
                curve: Curves.easeInOut))
        .value;

    return IgnorePointer(
      child: Opacity(
        opacity: 1 - fadeOut,
        child: Container(
          color: _C.bg,
          child: Stack(children: [
            Positioned(
                top: -120,
                right: -80,
                child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.primaryGreen
                            .withOpacity(.055)))),
            Positioned(
                bottom: -140,
                left: -90,
                child: Container(
                    width: 360,
                    height: 360,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.blue
                            .withOpacity(.055)))),
            Center(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale:
                          .55 + (.45 * ballValue),
                      child: Transform.rotate(
                        angle: (1 - ballValue) *
                            -0.55,
                        child: Container(
                          width: 124,
                          height: 124,
                          decoration: BoxDecoration(
                              color:
                                  _C.primaryGreen,
                              borderRadius:
                                  BorderRadius
                                      .circular(38),
                              boxShadow: [
                                BoxShadow(
                                    color: _C.primaryGreen
                                        .withOpacity(
                                            .28),
                                    blurRadius: 38,
                                    offset: const Offset(
                                        0, 20))
                              ]),
                          child: const Icon(
                              Icons
                                  .sports_soccer_rounded,
                              color: Colors.white,
                              size: 62),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Opacity(
                        opacity: titleValue,
                        child: Transform.translate(
                            offset: Offset(
                                0,
                                28 *
                                    (1 -
                                        titleValue)),
                            child: const Text(
                                'СПОРТОТЕКА',
                                textAlign:
                                    TextAlign.center,
                                style: TextStyle(
                                    color: _C.text,
                                    fontSize: 48,
                                    height: 1,
                                    letterSpacing:
                                        4.5,
                                    fontWeight:
                                        FontWeight
                                            .w900)))),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: sloganValue,
                      child:
                          Transform.translate(
                        offset: Offset(
                            0,
                            20 *
                                (1 -
                                    sloganValue)),
                        child: Container(
                          padding: const EdgeInsets
                              .symmetric(
                              horizontal: 22,
                              vertical: 11),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius
                                      .circular(99),
                              border: Border.all(
                                  color:
                                      _C.border),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors
                                        .black
                                        .withOpacity(
                                            .045),
                                    blurRadius: 18,
                                    offset: const Offset(
                                        0, 8))
                              ]),
                          child: const Text(
                              'Вперёд к победам!',
                              style: TextStyle(
                                  color: _C.muted,
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                  letterSpacing:
                                      .3)),
                        ),
                      ),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}