// lib/presentation/club_trainers/team_trainers_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/club_trainers/edit_trainer_profile_screen.dart';
import 'package:sportoteka/presentation/my_team_screen/my_team_screen.dart';

class _ApiEndpoints {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getTeamTrainers = '$apiBase/get_team_trainers.php';
  static const String linkTrainerToTeam = '$apiBase/link_trainer_to_team.php';
  static const String unlinkTrainerFromTeam = '$apiBase/unlink_trainer_from_team.php';
  static const String searchTrainerByEmail = '$apiBase/search_trainer_by_email.php';
  static const String getClubProfile = '$apiBase/get_club_profile.php';
  static const String getTrainerProfile = '$apiBase/get_trainer_profile.php';
}

class _Ui {
  static const Color primary = Color(0xFF0F7A3A);
  static const Color primarySoft = Color(0xFFEAF7EF);
  static const Color accent = Color(0xFF2563EB);
  static const Color bg = Color(0xFFF6F8FB);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF111827);
  static const Color muted = Color(0xFF64748B);
  static const Color faint = Color(0xFF94A3B8);
  static const Color line = Color(0xFFE5E7EB);
  static const Color danger = Color(0xFFDC2626);

  static bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= 760;
  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 1080;

  static TextStyle title(double size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: text,
        height: 1.08,
      );

  static TextStyle body(double size, {Color? color, FontWeight weight = FontWeight.w700}) => TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? muted,
        height: 1.15,
      );
}

enum StaffRoleGroup {
  all,
  mainCoaches,
  coaches,
  assistantCoaches,
  goalkeeperCoaches,
  methodists,
  doctors,
  press,
  managers,
}

class _RoleUi {
  final StaffRoleGroup key;
  final String title;
  final String subtitle;
  final IconData icon;

  const _RoleUi(this.key, this.title, this.subtitle, this.icon);
}

const List<_RoleUi> _roleTabs = [
  _RoleUi(StaffRoleGroup.all, 'Все', 'Весь штаб', Icons.groups_2_rounded),
  _RoleUi(StaffRoleGroup.mainCoaches, 'Главные', 'Главные тренеры', Icons.workspace_premium_rounded),
  _RoleUi(StaffRoleGroup.coaches, 'Тренеры', 'Тренерский состав', Icons.sports_rounded),
  _RoleUi(StaffRoleGroup.assistantCoaches, 'Ассистенты', 'Помощники тренера', Icons.support_agent_rounded),
  _RoleUi(StaffRoleGroup.goalkeeperCoaches, 'Вратари', 'Тренеры вратарей', Icons.sports_handball_rounded),
  _RoleUi(StaffRoleGroup.methodists, 'Методисты', 'Подготовка и планы', Icons.menu_book_rounded),
  _RoleUi(StaffRoleGroup.doctors, 'Медики', 'Спорт-медицина', Icons.health_and_safety_rounded),
  _RoleUi(StaffRoleGroup.press, 'Медиа', 'Пресс-служба', Icons.campaign_rounded),
  _RoleUi(StaffRoleGroup.managers, 'Админ.', 'Менеджмент', Icons.admin_panel_settings_rounded),
];

class _Utils {
  static int asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static bool asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final v = value.toLowerCase().trim();
      return v == 'true' || v == '1' || v == 'yes' || v == 'main';
    }
    if (value is num) return value != 0;
    return false;
  }

  static String asString(dynamic value) => (value ?? '').toString();

  static Map<String, dynamic> decodeResponse(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return {'status': 'error', 'message': 'Пустой ответ сервера'};

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'status': 'success', 'data': decoded};
    } catch (_) {
      final start = body.indexOf('{');
      final end = body.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          final decoded = jsonDecode(body.substring(start, end + 1));
          if (decoded is Map<String, dynamic>) return decoded;
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      return {
        'status': 'error',
        'message': body.startsWith('<') ? 'Сервер вернул HTML вместо JSON' : 'Ошибка парсинга JSON',
        'raw': body.length > 220 ? body.substring(0, 220) : body,
      };
    }
  }

  static Future<Map<String, dynamic>> postJson(String url, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 16));
    final json = decodeResponse(response);
    if ((json['status'] == 'error' || json['success'] == false) && _Utils.asString(json['raw']).startsWith('<')) {
      return json;
    }
    return json;
  }

  static Future<Map<String, dynamic>> postForm(String url, Map<String, String> body) async {
    final response = await http.post(Uri.parse(url), body: body).timeout(const Duration(seconds: 16));
    return decodeResponse(response);
  }

  static String? normalizeImage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    String url = raw.trim();
    if (url == 'null') return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('www.sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('/')) return 'https://sportotekaapp.ru$url';
    if (url.startsWith('uploads/')) return 'https://sportotekaapp.ru/$url';
    return 'https://sportotekaapp.ru/uploads/$url';
  }

  static String getTrainerName(Map<String, dynamic> trainer) {
    final firstName = asString(trainer['first_name']).trim();
    final lastName = asString(trainer['last_name']).trim();
    final fullName = asString(trainer['fullName'] ?? trainer['full_name'] ?? trainer['name']).trim();
    final name = '$firstName $lastName'.trim();
    if (name.isNotEmpty) return name;
    if (fullName.isNotEmpty) return fullName;
    final id = asInt(trainer['id']);
    return id > 0 ? 'Тренер $id' : 'Тренер';
  }

  static String trainerPhoto(Map<String, dynamic> trainer) {
    final keys = ['photo_url', 'avatar_url', 'avatar', 'photo', 'image', 'logo'];
    for (final key in keys) {
      final value = asString(trainer[key]).trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }
}

class TeamTrainersScreen extends StatefulWidget {
  final int clubId;
  final String clubName;
  final List<dynamic> teams;
  final String? clubLogoUrl;

  const TeamTrainersScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teams,
    this.clubLogoUrl,
  });

  @override
  State<TeamTrainersScreen> createState() => _TeamTrainersScreenState();
}

class _TeamTrainersScreenState extends State<TeamTrainersScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _trainers = [];
  List<Map<String, dynamic>> _filteredTrainers = [];
  String? _clubLogoUrl;
  StaffRoleGroup _selectedGroup = StaffRoleGroup.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    _clubLogoUrl = _Utils.normalizeImage(widget.clubLogoUrl);
    if (_clubLogoUrl == null) await _loadClubLogo();
    if (widget.teams.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _trainers = [];
        _filteredTrainers = [];
      });
      return;
    }
    await _loadTrainers();
  }

  Future<void> _loadClubLogo() async {
    try {
      final response = await http
          .get(Uri.parse('${_ApiEndpoints.getClubProfile}?club_id=${widget.clubId}'))
          .timeout(const Duration(seconds: 10));

      // На сервере этот endpoint иногда может отсутствовать и возвращать HTML/404.
      // Для экрана тренеров логотип клуба не критичен, поэтому просто молча
      // оставляем логотип из widget.clubLogoUrl или заглушку.
      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final data = _Utils.decodeResponse(response);
      if (data['status'] == 'error') return;

      final club = data['club'] is Map ? Map<String, dynamic>.from(data['club'] as Map) : data;
      final rawLogo = _Utils.asString(club['photo_url'] ?? club['photo'] ?? club['logo_url'] ?? club['logo']);
      final resolvedLogo = _Utils.normalizeImage(rawLogo);
      if (mounted) setState(() => _clubLogoUrl = resolvedLogo);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _loadTeamTrainersById(int teamId) async {
    var data = await _Utils.postJson(_ApiEndpoints.getTeamTrainers, {'team_id': teamId});
    if (_extractTrainerList(data).isNotEmpty || _Utils.asString(data['raw']).startsWith('<') == false) return data;

    data = await _Utils.postForm(_ApiEndpoints.getTeamTrainers, {'team_id': '$teamId'});
    if (_extractTrainerList(data).isNotEmpty) return data;

    try {
      final response = await http.get(Uri.parse('${_ApiEndpoints.getTeamTrainers}?team_id=$teamId'));
      return _Utils.decodeResponse(response);
    } catch (_) {
      return data;
    }
  }

  List<dynamic> _extractTrainerList(Map<String, dynamic> data) {
    final possible = [
      data['trainers'],
      data['data'],
      data['items'],
      data['staff'],
      data['coaches'],
      data['users'],
    ];
    for (final value in possible) {
      if (value is List) return value;
      if (value is Map && value['trainers'] is List) return value['trainers'] as List;
    }
    return const [];
  }

  Future<void> _loadTrainers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _trainers = [];
      _filteredTrainers = [];
    });

    try {
      final teamMeta = <int, Map<String, dynamic>>{};
      for (final rawTeam in widget.teams) {
        final teamId = _getTeamId(rawTeam);
        if (teamId <= 0) continue;
        teamMeta[teamId] = {
          'team_id': teamId,
          'team_name': _getTeamName(rawTeam),
          'team_logo': _getTeamLogo(rawTeam),
        };
      }

      final teamIds = teamMeta.keys.toList();
      if (teamIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Не найдены команды для загрузки тренеров';
        });
        return;
      }

      final results = await Future.wait(
        teamIds.map((teamId) async {
          final data = await _loadTeamTrainersById(teamId);
          final trainers = _extractTrainerList(data);
          final mainCoachId = _Utils.asInt(data['main_coach_id'] ?? data['main_trainer_id'] ?? data['head_coach_id']);
          return {'team_id': teamId, 'main_coach_id': mainCoachId, 'trainers': trainers, 'raw': data};
        }),
      );

      final aggregated = <int, Map<String, dynamic>>{};

      for (final result in results) {
        final teamId = _Utils.asInt(result['team_id']);
        final teamData = teamMeta[teamId];
        if (teamData == null) continue;

        final mainCoachId = _Utils.asInt(result['main_coach_id']);
        final trainers = result['trainers'] is List ? result['trainers'] as List : const [];

        for (final t in trainers) {
          if (t is! Map) continue;
          final trainerMap = Map<String, dynamic>.from(t);
          final trainerId = _Utils.asInt(
            trainerMap['id'] ?? trainerMap['trainer_id'] ?? trainerMap['user_id'] ?? trainerMap['coach_id'],
          );
          if (trainerId <= 0) continue;

          trainerMap['id'] = trainerId;
          final base = aggregated.putIfAbsent(trainerId, () {
            final copy = Map<String, dynamic>.from(trainerMap);
            copy['teams'] = <Map<String, dynamic>>[];
            copy['is_main_any'] = false;
            copy['profile'] = 'extra';
            return copy;
          });

          final linkProfile = _Utils.asString(
            trainerMap['profile'] ?? trainerMap['role'] ?? trainerMap['staff_role'] ?? trainerMap['position_code'],
          ).trim().toLowerCase();
          final isMainHere = linkProfile == 'main' || linkProfile == 'head' || (mainCoachId > 0 && trainerId == mainCoachId);

          if (isMainHere) {
            base['is_main_any'] = true;
            base['profile'] = 'main';
          }

          final teams = (base['teams'] as List).cast<Map<String, dynamic>>();
          if (!teams.any((team) => _Utils.asInt(team['team_id']) == teamId)) {
            teams.add({
              ...teamData,
              'link_profile': isMainHere ? 'main' : linkProfile,
              'main_coach_id': mainCoachId,
            });
          }
        }
      }

      final list = aggregated.values.toList()
        ..sort((a, b) {
          final mA = _Utils.asBool(a['is_main_any']);
          final mB = _Utils.asBool(b['is_main_any']);
          if (mA && !mB) return -1;
          if (mB && !mA) return 1;
          return _Utils.getTrainerName(a).toLowerCase().compareTo(_Utils.getTrainerName(b).toLowerCase());
        });

      if (!mounted) return;
      setState(() {
        _trainers = list;
        _filteredTrainers = List.of(list);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось загрузить тренеров';
      });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    final source = _trainers;
    if (query.isEmpty) {
      if (mounted) setState(() => _filteredTrainers = List.of(source));
      return;
    }

    if (!mounted) return;
    setState(() {
      _filteredTrainers = source.where((trainer) {
        final name = _Utils.getTrainerName(trainer).toLowerCase();
        final email = _Utils.asString(trainer['email']).toLowerCase();
        final phone = _Utils.asString(trainer['phone']).toLowerCase();
        final position = _Utils.asString(trainer['position']).toLowerCase();
        final teams = trainer['teams'] is List ? trainer['teams'] as List : const [];
        final teamNames = teams.whereType<Map>().map((team) => _Utils.asString(team['team_name']).toLowerCase()).join(' ');
        return name.contains(query) || email.contains(query) || phone.contains(query) || position.contains(query) || teamNames.contains(query);
      }).toList();
    });
  }

  StaffRoleGroup _detectGroup(Map<String, dynamic> trainer) {
    final isMainAny = _Utils.asBool(trainer['is_main_any']);
    if (isMainAny) return StaffRoleGroup.mainCoaches;

    final raw = _Utils.asString(
      trainer['staff_role'] ?? trainer['role_code'] ?? trainer['position_code'] ?? trainer['position'] ?? trainer['profile'],
    ).toLowerCase();

    if (raw.contains('assistant') || raw.contains('ассист') || raw.contains('помощ')) return StaffRoleGroup.assistantCoaches;
    if (raw.contains('goalkeeper') || raw.contains('врат')) return StaffRoleGroup.goalkeeperCoaches;
    if (raw.contains('method') || raw.contains('метод')) return StaffRoleGroup.methodists;
    if (raw.contains('doctor') || raw.contains('med') || raw.contains('врач') || raw.contains('мед')) return StaffRoleGroup.doctors;
    if (raw.contains('press') || raw.contains('media') || raw.contains('пресс') || raw.contains('медиа')) return StaffRoleGroup.press;
    if (raw.contains('manager') || raw.contains('admin') || raw.contains('менедж') || raw.contains('админ')) return StaffRoleGroup.managers;
    return StaffRoleGroup.coaches;
  }

  Map<StaffRoleGroup, List<Map<String, dynamic>>> _groupedTrainers(List<Map<String, dynamic>> list) {
    final map = <StaffRoleGroup, List<Map<String, dynamic>>>{};
    for (final trainer in list) {
      final group = _detectGroup(trainer);
      (map[group] ??= []).add(trainer);
    }
    for (final entry in map.entries) {
      entry.value.sort((a, b) => _Utils.getTrainerName(a).toLowerCase().compareTo(_Utils.getTrainerName(b).toLowerCase()));
    }
    return map;
  }

  int _countForGroup(StaffRoleGroup group) {
    if (group == StaffRoleGroup.all) return _filteredTrainers.length;
    return _filteredTrainers.where((trainer) => _detectGroup(trainer) == group).length;
  }

  List<Map<String, dynamic>> _listForSelectedGroup() {
    if (_selectedGroup == StaffRoleGroup.all) return _filteredTrainers;
    return _filteredTrainers.where((trainer) => _detectGroup(trainer) == _selectedGroup).toList();
  }

  int _getTeamId(dynamic team) {
    if (team is Map) {
      final map = Map<String, dynamic>.from(team);
      final id = _Utils.asInt(map['id']);
      if (id > 0) return id;
      return _Utils.asInt(map['team_id']);
    }
    return 0;
  }

  String _getTeamName(dynamic team) {
    if (team is Map) {
      final map = Map<String, dynamic>.from(team);
      final name = _Utils.asString(map['name']).trim();
      if (name.isNotEmpty) return name;
      final teamName = _Utils.asString(map['team_name']).trim();
      if (teamName.isNotEmpty) return teamName;
    }
    return 'Команда';
  }

  String? _getTeamLogo(dynamic team) {
    if (team is Map) {
      final map = Map<String, dynamic>.from(team);
      for (final key in ['logo_url', 'logo', 'photo_url', 'photo', 'image']) {
        final raw = _Utils.asString(map[key]).trim();
        if (raw.isNotEmpty) return _Utils.normalizeImage(raw);
      }
    }
    return null;
  }

    Future<Map<String, dynamic>?> _showTeamPicker(List<dynamic> teams) async {
    if (!mounted) return null;
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _TeamPickerSheet(
        teams: teams,
        teamIdExtractor: _getTeamId,
        teamNameExtractor: _getTeamName,
        teamLogoExtractor: _getTeamLogo,
      ),
    );
  }

    Future<void> _addTrainer() async {
    if (widget.teams.isEmpty) {
      Get.snackbar('Команды', 'Сначала добавьте команду');
      return;
    }

    final pickedTrainer = await _pickTrainerByEmailSheet();
    if (!mounted || pickedTrainer == null) return;

    final trainerId = _Utils.asInt(
      pickedTrainer['id'] ?? pickedTrainer['trainer_id'] ?? pickedTrainer['user_id'],
    );
    if (trainerId <= 0) {
      Get.snackbar('Ошибка', 'Не удалось определить ID тренера');
      return;
    }

    // Важно: команду выбираем уже после закрытия первого bottom sheet.
    // Нельзя открывать второй showModalBottomSheet поверх StatefulBuilder первого:
    // именно это часто вызывает framework assertion `_dependents.isEmpty`.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    final selectedTeam = await _showTeamPicker(widget.teams);
    if (!mounted || selectedTeam == null) return;

    final teamId = _getTeamId(selectedTeam);
    if (teamId <= 0) {
      Get.snackbar('Ошибка', 'Не удалось определить команду');
      return;
    }

    try {
      final data = await _Utils.postJson(_ApiEndpoints.linkTrainerToTeam, {
        'team_id': teamId,
        'trainer_id': trainerId,
        'profile': 'extra',
      });

      if (!mounted) return;

      if (data['status'] == 'success' || data['success'] == true) {
        await _loadTrainers();
        if (!mounted) return;
        Get.snackbar('Готово', 'Тренер привязан к команде');
      } else {
        final message = _Utils.asString(data['message']).trim();
        Get.snackbar('Ошибка', message.isEmpty ? 'Не удалось привязать тренера' : message);
      }
    } catch (_) {
      if (!mounted) return;
      Get.snackbar('Ошибка', 'Не удалось привязать тренера');
    }
  }

  Future<Map<String, dynamic>?> _pickTrainerByEmailSheet() async {
    final emailController = TextEditingController();
    final foundTrainers = <Map<String, dynamic>>[];
    bool isSearching = false;

    try {
      return await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (innerContext, setSheetState) {
              Future<void> searchTrainer() async {
                final email = emailController.text.trim();
                if (email.isEmpty) {
                  setSheetState(() => foundTrainers.clear());
                  return;
                }

                setSheetState(() => isSearching = true);

                try {
                  var response = await http
                      .post(Uri.parse(_ApiEndpoints.searchTrainerByEmail), body: {'email': email})
                      .timeout(const Duration(seconds: 16));

                  if (!innerContext.mounted) return;

                  var data = _Utils.decodeResponse(response);
                  if (_extractTrainerList(data).isEmpty && data['trainer'] is Map) {
                    data = {'trainers': [data['trainer']]};
                  }

                  final trainers = _extractTrainerList(data)
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();

                  setSheetState(() {
                    foundTrainers
                      ..clear()
                      ..addAll(trainers);
                    isSearching = false;
                  });
                } catch (_) {
                  if (!innerContext.mounted) return;
                  setSheetState(() {
                    foundTrainers.clear();
                    isSearching = false;
                  });
                }
              }

              return _BottomPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetHandle(),
                    Row(
                      children: [
                        _IconBox(icon: Icons.person_add_alt_1_rounded, color: _Ui.primary, size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Добавить тренера', style: _Ui.title(20)),
                              const SizedBox(height: 3),
                              Text('Найдите сотрудника по email, затем выберите команду', style: _Ui.body(12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _InputBox(
                      controller: emailController,
                      hint: 'Email тренера',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      onSubmitted: (_) => searchTrainer(),
                      suffix: IconButton(
                        icon: const Icon(Icons.search_rounded, color: _Ui.primary),
                        onPressed: searchTrainer,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isSearching)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (foundTrainers.isEmpty)
                      _SoftNotice(
                        icon: Icons.search_rounded,
                        title: 'Введите email',
                        text: 'После поиска здесь появится найденный тренер.',
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(innerContext).height * 0.46),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: foundTrainers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final trainer = foundTrainers[index];
                            final name = _Utils.getTrainerName(trainer);
                            final email = _Utils.asString(trainer['email']).trim();
                            final photo = _Utils.normalizeImage(_Utils.trainerPhoto(trainer));

                            return _MiniTrainerResult(
                              name: name,
                              email: email,
                              photo: photo,
                              onTap: () => Navigator.of(sheetContext).pop(trainer),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      emailController.dispose();
    }
  }

  Future<void> _unlinkTrainer(Map<String, dynamic> trainer) async {
    final teams = trainer['teams'] is List
        ? (trainer['teams'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    if (teams.isEmpty) {
      Get.snackbar('Команды', 'У тренера нет привязок');
      return;
    }

    final selectedTeam = await _showTeamPicker(teams);
    if (selectedTeam == null) return;

    final trainerId = _Utils.asInt(trainer['id']);
    final teamId = _Utils.asInt(selectedTeam['team_id'] ?? selectedTeam['id']);
    if (trainerId <= 0 || teamId <= 0) return;

    final linkProfile = _Utils.asString(selectedTeam['link_profile']).trim().toLowerCase();
    final mainCoachId = _Utils.asInt(selectedTeam['main_coach_id']);
    final isMainHere = linkProfile == 'main' || (mainCoachId > 0 && trainerId == mainCoachId);

    if (isMainHere) {
      Get.snackbar('Нельзя отвязать', 'Этот тренер назначен главным в выбранной команде.');
      return;
    }

    final confirmed = await _confirmSheet(
      title: 'Отвязать тренера?',
      text: 'Тренер будет отвязан от команды «${_Utils.asString(selectedTeam['team_name'] ?? selectedTeam['name'])}».',
      confirmText: 'Отвязать',
      danger: true,
    );
    if (confirmed != true) return;

    try {
      final res = await _Utils.postJson(_ApiEndpoints.unlinkTrainerFromTeam, {'team_id': teamId, 'trainer_id': trainerId});
      if (res['status'] == 'success' || res['success'] == true) {
        await _loadTrainers();
        Get.snackbar('Готово', 'Тренер отвязан');
      } else {
        Get.snackbar('Ошибка', _Utils.asString(res['message']).isEmpty ? 'Не удалось отвязать' : _Utils.asString(res['message']));
      }
    } catch (_) {
      Get.snackbar('Ошибка', 'Не удалось отвязать');
    }
  }

  Future<void> _setMainCoach(Map<String, dynamic> trainer) async {
    final trainerId = _Utils.asInt(trainer['id']);
    if (trainerId <= 0) return;
    final teams = trainer['teams'] is List
        ? (trainer['teams'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    if (teams.isEmpty) {
      Get.snackbar('Команды', 'Сначала привяжите тренера к команде');
      return;
    }

    final selectedTeam = await _showTeamPicker(teams);
    if (selectedTeam == null) return;
    final teamId = _Utils.asInt(selectedTeam['team_id'] ?? selectedTeam['id']);
    if (teamId <= 0) return;

    final confirmed = await _confirmSheet(
      title: 'Назначить главным?',
      text: 'Тренер станет главным для команды «${_Utils.asString(selectedTeam['team_name'] ?? selectedTeam['name'])}».',
      confirmText: 'Назначить',
    );
    if (confirmed != true) return;

    try {
      final res = await _Utils.postJson(_ApiEndpoints.linkTrainerToTeam, {
        'team_id': teamId,
        'trainer_id': trainerId,
        'profile': 'main',
      });
      if (res['status'] == 'success' || res['success'] == true) {
        await _loadTrainers();
        Get.snackbar('Готово', 'Главный тренер назначен');
      } else {
        Get.snackbar('Ошибка', _Utils.asString(res['message']).isEmpty ? 'Не удалось назначить' : _Utils.asString(res['message']));
      }
    } catch (_) {
      Get.snackbar('Ошибка', 'Не удалось назначить');
    }
  }

  Future<bool?> _confirmSheet({
    required String title,
    required String text,
    required String confirmText,
    bool danger = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BottomPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            _IconBox(icon: danger ? Icons.warning_amber_rounded : Icons.verified_user_rounded, color: danger ? _Ui.danger : _Ui.primary, size: 54),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: _Ui.title(20)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: _Ui.body(13.5)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: danger ? _Ui.danger : _Ui.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openChatWithTrainer({required int trainerId, required String trainerName, required String trainerEmail}) {
    Get.snackbar('Чат', 'Маршрут чата для тренера пока не подключён');
  }

  Future<void> _openTrainerProfile(Map<String, dynamic> trainer) async {
    final result = await Get.to<bool>(
      () => ClubTrainerCardScreen(
        clubName: widget.clubName,
        trainer: trainer,
        teams: trainer['teams'] is List ? (trainer['teams'] as List).cast<Map<String, dynamic>>() : [],
        clubTeams: widget.teams,
        onWrite: () {
          _openChatWithTrainer(
            trainerId: _Utils.asInt(trainer['id']),
            trainerName: _Utils.getTrainerName(trainer),
            trainerEmail: _Utils.asString(trainer['email']),
          );
        },
      ),
    );
    if (result == true) await _loadTrainers();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = _Ui.isTablet(context);
    final visible = _listForSelectedGroup();
    final grouped = _groupedTrainers(visible);

    return Scaffold(
      backgroundColor: _Ui.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _Ui.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: _addTrainer,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
        label: Text(isTablet ? 'Добавить тренера' : 'Добавить', style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        color: _Ui.primary,
        onRefresh: () async {
          await _loadClubLogo();
          await _loadTrainers();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: _Ui.bg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              expandedHeight: isTablet ? 96 : 82,
              leadingWidth: 64,
              leading: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Center(
                  child: _RoundButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Get.back()),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 72, right: 16, bottom: isTablet ? 18 : 16),
                title: Text(
                  'Тренеры команды',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _Ui.title(isTablet ? 20 : 17),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _RoundButton(icon: Icons.refresh_rounded, onTap: () async => _loadTrainers()),
                ),
              ],
            ),
            if (widget.teams.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(icon: Icons.group_off_rounded, title: 'Нет команд', subtitle: 'Сначала создайте команду клуба.'),
              )
            else if (_isLoading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              SliverFillRemaining(hasScrollBody: false, child: _ErrorState(error: _errorMessage!, onRetry: _loadTrainers))
            else if (isTablet)
              SliverToBoxAdapter(child: _buildTabletBody(context, visible, grouped))
            else
              SliverToBoxAdapter(child: _buildMobileBody(context, visible, grouped)),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBody(
    BuildContext context,
    List<Map<String, dynamic>> visible,
    Map<StaffRoleGroup, List<Map<String, dynamic>>> grouped,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      child: Column(
        children: [
          _HeaderCard(
            clubName: widget.clubName,
            clubLogoUrl: _clubLogoUrl,
            trainersCount: _trainers.length,
            teamsCount: widget.teams.length,
            compact: true,
          ),
          const SizedBox(height: 12),
          _SearchBar(controller: _searchController, onClear: _searchController.clear, compact: true),
          const SizedBox(height: 12),
          _RoleTabsBar(selected: _selectedGroup, onSelect: (g) => setState(() => _selectedGroup = g), countOf: _countForGroup, compact: true),
          const SizedBox(height: 14),
          if (_filteredTrainers.isEmpty || visible.isEmpty)
            const _NoResultsState()
          else
            _TrainerList(
              selectedGroup: _selectedGroup,
              visible: visible,
              grouped: grouped,
              onOpen: _openTrainerProfile,
              onChat: (trainer) => _openChatWithTrainer(
                trainerId: _Utils.asInt(trainer['id']),
                trainerName: _Utils.getTrainerName(trainer),
                trainerEmail: _Utils.asString(trainer['email']),
              ),
              onUnlink: _unlinkTrainer,
              onSetMain: _setMainCoach,
              compact: true,
            ),
        ],
      ),
    );
  }

  Widget _buildTabletBody(
    BuildContext context,
    List<Map<String, dynamic>> visible,
    Map<StaffRoleGroup, List<Map<String, dynamic>>> grouped,
  ) {
    final maxWidth = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.fromLTRB(maxWidth >= 1100 ? 28 : 20, 8, maxWidth >= 1100 ? 28 : 20, 110),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: maxWidth >= 1100 ? 330 : 292,
            child: Column(
              children: [
                _HeaderCard(
                  clubName: widget.clubName,
                  clubLogoUrl: _clubLogoUrl,
                  trainersCount: _trainers.length,
                  teamsCount: widget.teams.length,
                  compact: false,
                ),
                const SizedBox(height: 14),
                _SearchBar(controller: _searchController, onClear: _searchController.clear, compact: false),
                const SizedBox(height: 14),
                _RoleSideMenu(selected: _selectedGroup, onSelect: (g) => setState(() => _selectedGroup = g), countOf: _countForGroup),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _Ui.line),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: _filteredTrainers.isEmpty || visible.isEmpty
                  ? const _NoResultsState()
                  : _TrainerList(
                      selectedGroup: _selectedGroup,
                      visible: visible,
                      grouped: grouped,
                      onOpen: _openTrainerProfile,
                      onChat: (trainer) => _openChatWithTrainer(
                        trainerId: _Utils.asInt(trainer['id']),
                        trainerName: _Utils.getTrainerName(trainer),
                        trainerEmail: _Utils.asString(trainer['email']),
                      ),
                      onUnlink: _unlinkTrainer,
                      onSetMain: _setMainCoach,
                      compact: false,
                      grid: true,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerList extends StatelessWidget {
  final StaffRoleGroup selectedGroup;
  final List<Map<String, dynamic>> visible;
  final Map<StaffRoleGroup, List<Map<String, dynamic>>> grouped;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<Map<String, dynamic>> onChat;
  final ValueChanged<Map<String, dynamic>> onUnlink;
  final ValueChanged<Map<String, dynamic>> onSetMain;
  final bool compact;
  final bool grid;

  const _TrainerList({
    required this.selectedGroup,
    required this.visible,
    required this.grouped,
    required this.onOpen,
    required this.onChat,
    required this.onUnlink,
    required this.onSetMain,
    required this.compact,
    this.grid = false,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    if (selectedGroup == StaffRoleGroup.all) {
      for (final tab in _roleTabs) {
        if (tab.key == StaffRoleGroup.all) continue;
        final list = grouped[tab.key] ?? const <Map<String, dynamic>>[];
        if (list.isEmpty) continue;
        widgets.add(_RoleSectionBanner(title: tab.title, subtitle: tab.subtitle, icon: tab.icon, count: list.length, compact: compact));
        widgets.add(const SizedBox(height: 10));
        widgets.add(_CardsWrap(list: list, onOpen: onOpen, onChat: onChat, onUnlink: onUnlink, onSetMain: onSetMain, compact: compact, grid: grid));
        widgets.add(SizedBox(height: compact ? 12 : 16));
      }
    } else {
      final tab = _roleTabs.firstWhere((e) => e.key == selectedGroup, orElse: () => _roleTabs.first);
      widgets.add(_RoleSectionBanner(title: tab.title, subtitle: tab.subtitle, icon: tab.icon, count: visible.length, compact: compact));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_CardsWrap(list: visible, onOpen: onOpen, onChat: onChat, onUnlink: onUnlink, onSetMain: onSetMain, compact: compact, grid: grid));
    }
    if (widgets.isEmpty) return const _NoResultsState();
    return Column(children: widgets);
  }
}

class _CardsWrap extends StatelessWidget {
  final List<Map<String, dynamic>> list;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<Map<String, dynamic>> onChat;
  final ValueChanged<Map<String, dynamic>> onUnlink;
  final ValueChanged<Map<String, dynamic>> onSetMain;
  final bool compact;
  final bool grid;

  const _CardsWrap({
    required this.list,
    required this.onOpen,
    required this.onChat,
    required this.onUnlink,
    required this.onSetMain,
    required this.compact,
    required this.grid,
  });

  @override
  Widget build(BuildContext context) {
    if (!grid) {
      return Column(
        children: list
            .map((trainer) => _TrainerCard(
                  trainer: trainer,
                  onTap: () => onOpen(trainer),
                  onChat: () => onChat(trainer),
                  onUnlink: () => onUnlink(trainer),
                  onSetMain: () => onSetMain(trainer),
                  compact: compact,
                ))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 2;
        final spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: list
              .map((trainer) => SizedBox(
                    width: width,
                    child: _TrainerCard(
                      trainer: trainer,
                      onTap: () => onOpen(trainer),
                      onChat: () => onChat(trainer),
                      onUnlink: () => onUnlink(trainer),
                      onSetMain: () => onSetMain(trainer),
                      compact: false,
                      denseTablet: true,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String clubName;
  final String? clubLogoUrl;
  final int trainersCount;
  final int teamsCount;
  final bool compact;

  const _HeaderCard({
    required this.clubName,
    required this.clubLogoUrl,
    required this.trainersCount,
    required this.teamsCount,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 22 : 26),
        border: Border.all(color: _Ui.line),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleNetworkImage(
                imageUrl: clubLogoUrl,
                size: compact ? 50 : 62,
                borderColor: _Ui.primary.withOpacity(0.22),
                borderWidth: 2,
                fallback: Icon(Icons.shield_rounded, color: _Ui.primary, size: compact ? 26 : 32),
              ),
              SizedBox(width: compact ? 10 : 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clubName, maxLines: compact ? 2 : 3, overflow: TextOverflow.ellipsis, style: _Ui.title(compact ? 17 : 21)),
                    const SizedBox(height: 5),
                    Text('Тренерский штаб', maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.body(compact ? 12 : 13, color: _Ui.primary, weight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          Row(
            children: [
              Expanded(child: _MiniStat(icon: Icons.groups_2_rounded, value: '$teamsCount', label: 'команд')),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(icon: Icons.sports_rounded, value: '$trainersCount', label: 'тренеров')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _MiniStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: _Ui.primarySoft, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _Ui.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(text: '$value ', style: _Ui.title(15)),
                  TextSpan(text: label, style: _Ui.body(11.5, weight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;
  final bool compact;

  const _SearchBar({required this.controller, required this.onClear, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 48 : 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Ui.line),
      ),
      child: TextField(
        controller: controller,
        style: _Ui.body(compact ? 13 : 14, color: _Ui.text, weight: FontWeight.w800),
        decoration: InputDecoration(
          hintText: compact ? 'Поиск тренера...' : 'Поиск тренера, email или команды...',
          hintStyle: _Ui.body(compact ? 12.5 : 13, color: _Ui.faint),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded, color: _Ui.faint, size: 21),
          suffixIcon: controller.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded, size: 19), onPressed: onClear) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _RoleTabsBar extends StatelessWidget {
  final StaffRoleGroup selected;
  final ValueChanged<StaffRoleGroup> onSelect;
  final int Function(StaffRoleGroup) countOf;
  final bool compact;

  const _RoleTabsBar({required this.selected, required this.onSelect, required this.countOf, required this.compact});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 72 : 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _roleTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, i) {
          final tab = _roleTabs[i];
          final active = tab.key == selected;
          return _RolePill(tab: tab, active: active, count: countOf(tab.key), compact: compact, onTap: () => onSelect(tab.key));
        },
      ),
    );
  }
}

class _RoleSideMenu extends StatelessWidget {
  final StaffRoleGroup selected;
  final ValueChanged<StaffRoleGroup> onSelect;
  final int Function(StaffRoleGroup) countOf;

  const _RoleSideMenu({required this.selected, required this.onSelect, required this.countOf});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _Ui.line)),
      child: Column(
        children: _roleTabs.map((tab) {
          final active = tab.key == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: InkWell(
              onTap: () => onSelect(tab.key),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? _Ui.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: active ? _Ui.primary.withOpacity(0.2) : Colors.transparent),
                ),
                child: Row(
                  children: [
                    _IconBox(icon: tab.icon, color: active ? _Ui.primary : _Ui.muted, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tab.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.body(13, color: _Ui.text, weight: FontWeight.w900)),
                          Text(tab.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.body(10.8, color: _Ui.muted, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CountBadge(countOf(tab.key), active: active),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final _RoleUi tab;
  final bool active;
  final int count;
  final bool compact;
  final VoidCallback onTap;

  const _RolePill({required this.tab, required this.active, required this.count, required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: compact ? 132 : 162,
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: active ? _Ui.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? _Ui.primary.withOpacity(0.25) : _Ui.line),
        ),
        child: Row(
          children: [
            _IconBox(icon: tab.icon, color: active ? _Ui.primary : _Ui.muted, size: compact ? 34 : 40),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tab.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.body(compact ? 12.2 : 13, color: _Ui.text, weight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('$count', maxLines: 1, style: _Ui.body(compact ? 11 : 12, color: active ? _Ui.primary : _Ui.muted, weight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSectionBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int count;
  final bool compact;

  const _RoleSectionBanner({required this.title, required this.subtitle, required this.icon, required this.count, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 11 : 12),
      decoration: BoxDecoration(color: _Ui.primarySoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Ui.primary.withOpacity(0.14))),
      child: Row(
        children: [
          _IconBox(icon: icon, color: _Ui.primary, size: compact ? 38 : 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.title(compact ? 14.5 : 15.5)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.body(compact ? 11.3 : 12.2)),
              ],
            ),
          ),
          _CountBadge(count, active: true),
        ],
      ),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  final Map<String, dynamic> trainer;
  final VoidCallback onTap;
  final VoidCallback onChat;
  final VoidCallback onUnlink;
  final VoidCallback onSetMain;
  final bool compact;
  final bool denseTablet;

  const _TrainerCard({
    required this.trainer,
    required this.onTap,
    required this.onChat,
    required this.onUnlink,
    required this.onSetMain,
    required this.compact,
    this.denseTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = _Utils.getTrainerName(trainer);
    final email = _Utils.asString(trainer['email']).trim();
    final position = _Utils.asString(trainer['position']).trim();
    final isMainAny = _Utils.asBool(trainer['is_main_any']);
    final photo = _Utils.normalizeImage(_Utils.trainerPhoto(trainer));
    final teams = trainer['teams'] is List ? (trainer['teams'] as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    final avatarSize = denseTablet ? 48.0 : (compact ? 48.0 : 54.0);

    return Padding(
      padding: EdgeInsets.only(bottom: denseTablet ? 0 : 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _Ui.line),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CircleNetworkImage(
                    imageUrl: photo,
                    size: avatarSize,
                    borderColor: _Ui.primary.withOpacity(0.18),
                    borderWidth: 1.5,
                    fallback: Icon(Icons.person_rounded, color: _Ui.primary, size: avatarSize * 0.52),
                  ),
                  SizedBox(width: compact ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.title(compact ? 14.5 : 15.5))),
                            if (isMainAny) ...[
                              const SizedBox(width: 6),
                              _TinyBadge('ГЛАВНЫЙ', color: _Ui.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(position.isNotEmpty ? position : (email.isNotEmpty ? email : 'Тренер команды'), maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.body(compact ? 11.5 : 12.2)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _SmallAction(icon: Icons.chat_bubble_outline_rounded, onTap: onChat),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'main') onSetMain();
                      if (value == 'unlink') onUnlink();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'main', child: _PopupItem(icon: Icons.workspace_premium_rounded, text: 'Назначить главным', color: _Ui.primary)),
                      PopupMenuItem(value: 'unlink', child: _PopupItem(icon: Icons.link_off_rounded, text: 'Отвязать от команды', color: _Ui.danger)),
                    ],
                    child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.more_vert_rounded, color: _Ui.muted, size: 21)),
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 12),
              if (teams.isEmpty)
                _TinyBadge('НЕТ ПРИВЯЗКИ К КОМАНДЕ', color: _Ui.muted)
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final team in teams.take(denseTablet ? 2 : 3))
                      _TeamChip(title: _Utils.asString(team['team_name']).trim().isEmpty ? 'Команда' : _Utils.asString(team['team_name']).trim()),
                    if (teams.length > (denseTablet ? 2 : 3)) _TeamChip(title: '+${teams.length - (denseTablet ? 2 : 3)}'),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _PopupItem({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Expanded(child: Text(text))]);
  }
}

class _TeamChip extends StatelessWidget {
  final String title;
  const _TeamChip({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: _Ui.primarySoft, borderRadius: BorderRadius.circular(999), border: Border.all(color: _Ui.primary.withOpacity(0.12))),
      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.body(11.2, color: _Ui.primary, weight: FontWeight.w900)),
    );
  }
}

class ClubTrainerCardScreen extends StatefulWidget {
  final String clubName;
  final Map<String, dynamic> trainer;
  final List<Map<String, dynamic>> teams;
  final List<dynamic> clubTeams;
  final VoidCallback onWrite;

  const ClubTrainerCardScreen({
    super.key,
    required this.clubName,
    required this.trainer,
    required this.teams,
    required this.clubTeams,
    required this.onWrite,
  });

  @override
  State<ClubTrainerCardScreen> createState() => _ClubTrainerCardScreenState();
}

class _ClubTrainerCardScreenState extends State<ClubTrainerCardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final trainerId = _Utils.asInt(widget.trainer['id']);
    if (trainerId <= 0) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _Utils.postJson(_ApiEndpoints.getTrainerProfile, {'trainer_id': trainerId});
      Map<String, dynamic> pick(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
      final ok = response['success'] == true || response['status'] == 'success';
      final profile = ok
          ? (pick(response['profile']).isNotEmpty
              ? pick(response['profile'])
              : pick(response['trainer']).isNotEmpty
                  ? pick(response['trainer'])
                  : pick(response['user']).isNotEmpty
                      ? pick(response['user'])
                      : pick(response['data']).isNotEmpty
                          ? pick(response['data'])
                          : response)
          : <String, dynamic>{};
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _getClubTeamId(dynamic team) {
    if (team is Map) return _Utils.asInt(team['id'] ?? team['team_id']);
    return 0;
  }

  String _getClubTeamName(dynamic team) {
    if (team is Map) return _Utils.asString(team['name'] ?? team['team_name']).trim().isEmpty ? 'Команда' : _Utils.asString(team['name'] ?? team['team_name']).trim();
    return 'Команда';
  }

  String? _getClubTeamLogo(dynamic team) {
    if (team is Map) return _Utils.normalizeImage(_Utils.asString(team['logo_url'] ?? team['logo'] ?? team['photo_url'] ?? team['photo']));
    return null;
  }

  void _openTeam(Map<String, dynamic> team) {
    final teamId = _Utils.asInt(team['team_id'] ?? team['id']);
    final teamName = _Utils.asString(team['team_name'] ?? team['name']).trim();
    if (teamId <= 0) return;
    Get.to(() => MyTeamScreen(teamId: teamId, teamName: teamName.isEmpty ? 'Команда' : teamName));
  }

  Future<void> _linkToAnotherTeam() async {
    final trainerId = _Utils.asInt(widget.trainer['id']);
    if (trainerId <= 0) return;
    if (widget.clubTeams.isEmpty) {
      Get.snackbar('Команды', 'У клуба нет команд');
      return;
    }

    final selectedTeam = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _TeamPickerSheet(
        teams: widget.clubTeams,
        teamIdExtractor: _getClubTeamId,
        teamNameExtractor: _getClubTeamName,
        teamLogoExtractor: _getClubTeamLogo,
      ),
    );
    if (selectedTeam == null) return;
    final teamId = _getClubTeamId(selectedTeam);
    if (teamId <= 0) return;

    final data = await _Utils.postJson(_ApiEndpoints.linkTrainerToTeam, {
      'team_id': teamId,
      'trainer_id': trainerId,
      'profile': 'extra',
    });
    if (data['status'] == 'success' || data['success'] == true) {
      Get.snackbar('Готово', 'Тренер привязан к команде');
      Get.back(result: true);
    } else {
      Get.snackbar('Ошибка', _Utils.asString(data['message']).isEmpty ? 'Не удалось привязать' : _Utils.asString(data['message']));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = _Ui.isTablet(context);
    final name = _Utils.getTrainerName(widget.trainer);
    final email = _Utils.asString(widget.trainer['email']).trim();
    final rawPhotoFromProfile = _Utils.trainerPhoto(_profile);
    final rawPhotoFromTrainer = _Utils.trainerPhoto(widget.trainer);
    final photo = _Utils.normalizeImage(rawPhotoFromProfile.trim().isNotEmpty ? rawPhotoFromProfile : rawPhotoFromTrainer);
    final position = _Utils.asString(_profile['position'] ?? widget.trainer['position']).trim();
    final bio = _Utils.asString(_profile['bio'] ?? _profile['description']).trim();
    final birthday = _Utils.asString(_profile['birthday'] ?? _profile['birth_date']).trim();
    final experience = _Utils.asString(_profile['experience'] ?? _profile['experience_years']).trim();

    return Scaffold(
      backgroundColor: _Ui.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: _Ui.bg,
            pinned: true,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Center(child: _RoundButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Get.back())),
            ),
            title: Text('Визитка тренера', maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.title(isTablet ? 20 : 17)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _RoundButton(
                  icon: Icons.edit_rounded,
                  onTap: () async {
                    final saved = await Get.to<bool>(() => EditTrainerProfileScreen(trainerId: _Utils.asInt(widget.trainer['id']), trainerName: name));
                    if (saved == true) {
                      await _loadProfile();
                      Get.back(result: true);
                    }
                  },
                ),
              ),
            ],
          ),
          if (_isLoading)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(isTablet ? 24 : 16, 8, isTablet ? 24 : 16, 34),
                child: isTablet
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 340,
                            child: _TrainerProfileCard(
                              name: name,
                              email: email,
                              photo: photo,
                              position: position,
                              clubName: widget.clubName,
                              teams: widget.teams,
                              onWrite: widget.onWrite,
                              onLinkTeam: _linkToAnotherTeam,
                              onTeamTap: _openTeam,
                              compact: false,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(child: _TrainerDetailsPanel(bio: bio, birthday: birthday, experience: experience, teams: widget.teams, onTeamTap: _openTeam)),
                        ],
                      )
                    : Column(
                        children: [
                          _TrainerProfileCard(
                            name: name,
                            email: email,
                            photo: photo,
                            position: position,
                            clubName: widget.clubName,
                            teams: widget.teams,
                            onWrite: widget.onWrite,
                            onLinkTeam: _linkToAnotherTeam,
                            onTeamTap: _openTeam,
                            compact: true,
                          ),
                          const SizedBox(height: 14),
                          _TrainerDetailsPanel(bio: bio, birthday: birthday, experience: experience, teams: widget.teams, onTeamTap: _openTeam),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrainerProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String? photo;
  final String position;
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final VoidCallback onWrite;
  final VoidCallback onLinkTeam;
  final ValueChanged<Map<String, dynamic>> onTeamTap;
  final bool compact;

  const _TrainerProfileCard({
    required this.name,
    required this.email,
    required this.photo,
    required this.position,
    required this.clubName,
    required this.teams,
    required this.onWrite,
    required this.onLinkTeam,
    required this.onTeamTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: _Ui.line), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Column(
        children: [
          _CircleNetworkImage(imageUrl: photo, size: compact ? 88 : 104, borderColor: _Ui.primary.withOpacity(0.22), borderWidth: 2, fallback: Icon(Icons.person_rounded, color: _Ui.primary, size: compact ? 44 : 52)),
          const SizedBox(height: 14),
          Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: _Ui.title(compact ? 22 : 24)),
          const SizedBox(height: 6),
          if (email.isNotEmpty) Text(email, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.body(compact ? 12.5 : 13.5)),
          if (position.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TinyBadge(position, color: _Ui.primary),
          ],
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.shield_rounded, label: 'Клуб', value: clubName),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _ActionButton(icon: Icons.chat_bubble_outline_rounded, label: 'Написать', onTap: onWrite)),
              const SizedBox(width: 10),
              Expanded(child: _ActionButton(icon: Icons.link_rounded, label: 'Привязать', onTap: onLinkTeam)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainerDetailsPanel extends StatelessWidget {
  final String bio;
  final String birthday;
  final String experience;
  final List<Map<String, dynamic>> teams;
  final ValueChanged<Map<String, dynamic>> onTeamTap;

  const _TrainerDetailsPanel({required this.bio, required this.birthday, required this.experience, required this.teams, required this.onTeamTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: _Ui.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Информация', style: _Ui.title(18)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoMini(icon: Icons.cake_rounded, label: 'Дата рождения', value: birthday.isEmpty ? 'Не указана' : birthday),
              _InfoMini(icon: Icons.timeline_rounded, label: 'Опыт', value: experience.isEmpty ? 'Не указан' : experience),
              _InfoMini(icon: Icons.groups_2_rounded, label: 'Команд', value: '${teams.length}'),
            ],
          ),
          const SizedBox(height: 16),
          Text('О тренере', style: _Ui.title(16)),
          const SizedBox(height: 8),
          Text(bio.isEmpty ? 'Описание тренера пока не заполнено.' : bio, style: _Ui.body(13.5, weight: FontWeight.w700)),
          const SizedBox(height: 18),
          Text('Команды тренера', style: _Ui.title(16)),
          const SizedBox(height: 10),
          if (teams.isEmpty)
            const _SoftNotice(icon: Icons.link_off_rounded, title: 'Нет привязок', text: 'Тренер пока не привязан к командам.')
          else
            Column(
              children: teams.map((team) {
                final teamName = _Utils.asString(team['team_name'] ?? team['name']).trim();
                final logoUrl = _Utils.normalizeImage(_Utils.asString(team['team_logo'] ?? team['logo_url'] ?? team['logo']));
                final lp = _Utils.asString(team['link_profile']).trim().toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onTeamTap(team),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _Ui.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Ui.line)),
                      child: Row(
                        children: [
                          _CircleNetworkImage(imageUrl: logoUrl, size: 42, borderColor: _Ui.primary.withOpacity(0.15), borderWidth: 1, fallback: const Icon(Icons.groups_2_rounded, color: _Ui.primary)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(teamName.isEmpty ? 'Команда' : teamName, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.title(14))),
                          if (lp == 'main') _TinyBadge('ГЛАВНЫЙ', color: _Ui.primary),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: _Ui.faint),
                        ],
                      ),
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

class _InfoMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoMini({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _Ui.isTablet(context) ? 190 : double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _Ui.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Ui.line)),
      child: Row(
        children: [
          _IconBox(icon: icon, color: _Ui.primary, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.body(11.2)),
              const SizedBox(height: 2),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.title(13.5)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TeamPickerSheet extends StatelessWidget {
  final List<dynamic> teams;
  final int Function(dynamic) teamIdExtractor;
  final String Function(dynamic) teamNameExtractor;
  final String? Function(dynamic) teamLogoExtractor;

  const _TeamPickerSheet({required this.teams, required this.teamIdExtractor, required this.teamNameExtractor, required this.teamLogoExtractor});

  @override
  Widget build(BuildContext context) {
    return _BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(),
          Text('Выберите команду', style: _Ui.title(20)),
          const SizedBox(height: 5),
          Text('Тренер будет привязан к выбранной команде.', style: _Ui.body(13)),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: teams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final team = teams[index];
                final id = teamIdExtractor(team);
                final name = teamNameExtractor(team);
                final logo = teamLogoExtractor(team);
                return InkWell(
                  onTap: id <= 0 ? null : () => Navigator.pop(context, team is Map<String, dynamic> ? team : Map<String, dynamic>.from(team as Map)),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _Ui.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Ui.line)),
                    child: Row(
                      children: [
                        _CircleNetworkImage(imageUrl: logo, size: 44, borderColor: _Ui.primary.withOpacity(0.14), borderWidth: 1, fallback: const Icon(Icons.groups_2_rounded, color: _Ui.primary)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.title(14.5))),
                        const Icon(Icons.check_circle_outline_rounded, color: _Ui.primary, size: 21),
                      ],
                    ),
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

class _CircleNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double borderWidth;
  final Color borderColor;
  final Widget fallback;

  const _CircleNetworkImage({required this.imageUrl, required this.size, required this.borderWidth, required this.borderColor, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: borderColor, width: borderWidth)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: imageUrl == null || imageUrl!.isEmpty
            ? Center(child: fallback)
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, _) => const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                errorWidget: (context, _, __) => Center(child: fallback),
              ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _IconBox({required this.icon, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(size * 0.34)),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool active;
  const _CountBadge(this.count, {required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: active ? _Ui.primary.withOpacity(0.12) : _Ui.bg, borderRadius: BorderRadius.circular(999)),
      child: Text('$count', style: _Ui.body(11.5, color: active ? _Ui.primary : _Ui.muted, weight: FontWeight.w900)),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _TinyBadge(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.18))),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.3)),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: _Ui.primarySoft, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 18, color: _Ui.primary),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: _Ui.line), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 5))]),
        child: Icon(icon, size: 19, color: _Ui.text),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(color: _Ui.primarySoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: _Ui.primary.withOpacity(0.12))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: _Ui.primary),
            const SizedBox(width: 6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.body(12.5, color: _Ui.primary, weight: FontWeight.w900))),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _Ui.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Ui.line)),
      child: Row(
        children: [
          _IconBox(icon: icon, color: _Ui.primary, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: _Ui.body(11.2)),
              const SizedBox(height: 2),
              Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: _Ui.title(13.5)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _InputBox({required this.controller, required this.hint, required this.icon, this.keyboardType, this.onSubmitted, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: _Ui.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Ui.line)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          prefixIcon: Icon(icon, color: _Ui.faint),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        ),
      ),
    );
  }
}

class _MiniTrainerResult extends StatelessWidget {
  final String name;
  final String email;
  final String? photo;
  final VoidCallback onTap;
  const _MiniTrainerResult({required this.name, required this.email, required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _Ui.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Ui.line)),
          child: Row(
            children: [
              _CircleNetworkImage(imageUrl: photo, size: 42, borderColor: _Ui.primary.withOpacity(0.15), borderWidth: 1, fallback: const Icon(Icons.person_rounded, color: _Ui.primary)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.title(14)),
                  if (email.isNotEmpty) Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Ui.body(12)),
                ]),
              ),
              const Icon(Icons.add_link_rounded, color: _Ui.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final Widget child;
  const _BottomPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: child,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: _Ui.line, borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

class _SoftNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _SoftNotice({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _Ui.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Ui.line)),
      child: Row(
        children: [
          _IconBox(icon: icon, color: _Ui.muted, size: 40),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _Ui.title(14)), const SizedBox(height: 2), Text(text, style: _Ui.body(12.2))])),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _IconBox(icon: icon, color: _Ui.muted, size: 72),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: _Ui.title(19)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: _Ui.body(13.5)),
        ]),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _IconBox(icon: Icons.error_outline_rounded, color: _Ui.danger, size: 72),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center, style: _Ui.title(18)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: _Ui.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: const Text('Повторить'),
          ),
        ]),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        _IconBox(icon: Icons.manage_search_rounded, color: _Ui.muted, size: 70),
        const SizedBox(height: 14),
        Text('Тренеры не найдены', textAlign: TextAlign.center, style: _Ui.title(18)),
        const SizedBox(height: 7),
        Text('Попробуйте изменить поиск или добавьте тренера.', textAlign: TextAlign.center, style: _Ui.body(13)),
      ]),
    );
  }
}
