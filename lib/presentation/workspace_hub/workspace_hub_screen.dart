import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/club_workspace/club_workspace_screen.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_press_assistant_screen.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';
import 'package:sportoteka/presentation/player_screen/player_dashboard_screen.dart';
import 'package:sportoteka/routes/app_routes.dart';

/// Стартовый экран после авторизации.
///
/// Доступ:
/// - клуб: «Клубный кабинет» + «Мой профиль»;
/// - тренер с назначенной командой: «Кабинет тренера» + «Мой профиль»;
/// - тренер без команды: только «Мой профиль»;
/// - игрок: «Центр игрока» + «Моя команда».
///
/// В этой версии специально нет LayoutBuilder, MouseRegion, Spacer и
/// Row(crossAxisAlignment: stretch) внутри вертикального scroll.
/// Это исключает конфликт неограниченных constraints на macOS.
class WorkspaceHubScreen extends StatefulWidget {
  const WorkspaceHubScreen({super.key});

  @override
  State<WorkspaceHubScreen> createState() => _WorkspaceHubScreenState();
}

class _WorkspaceHubScreenState extends State<WorkspaceHubScreen> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _getTrainerTeamsUrl =
      '$_apiBase/get_team_by_coach.php';

  static const Color _bg = Color(0xFFF6F7F6);
  static const Color _panel = Colors.white;
  static const Color _soft = Color(0xFFF7F8F7);
  static const Color _text = Color(0xFF0B0F14);
  static const Color _secondary = Color(0xFF5F6670);
  static const Color _subtle = Color(0xFF8A9099);
  static const Color _divider = Color(0xFFE9ECEA);
  static const Color _green = Color(0xFF00A750);
  static const Color _greenDark = Color(0xFF067A46);
  static const Color _greenSoft = Color(0xFFF3FAF6);
  static const Color _greenBorder = Color(0xFFD7F0E2);

  bool _loading = true;

  String _role = '';
  String _firstName = '';
  String _lastName = '';

  String? _clubName;
  String? _teamName;
  String? _teamLogoUrl;
  String? _clubLogoUrl;
  String? _userAvatarUrl;
  int? _teamId;
  Map<String, dynamic>? _player;

  bool _coachHasAssignedTeam = false;

  // Пресс-служба — дополнительный доступ, а не users.role.
  // Поэтому читаем назначения отдельно и показываем отдельный Workspace.
  final List<Map<String, dynamic>> _pressAssignments =
      <Map<String, dynamic>>[];

  bool get _hasPressAccess => _pressAssignments.isNotEmpty;

  String get _normalizedRole => _role.trim().toLowerCase();

  bool get _isClub =>
      _normalizedRole == 'club' ||
      _normalizedRole == 'admin' ||
      _normalizedRole == 'клуб' ||
      _normalizedRole.contains('club');

  bool get _isCoach =>
      _normalizedRole == 'coach' ||
      _normalizedRole == 'trainer' ||
      _normalizedRole == 'тренер' ||
      _normalizedRole.contains('coach') ||
      _normalizedRole.contains('trainer') ||
      _normalizedRole.contains('тренер');

  bool get _isPlayer =>
      _normalizedRole == 'player' ||
      _normalizedRole == 'игрок' ||
      _normalizedRole.contains('player') ||
      _normalizedRole.contains('игрок');

  String get _fullName {
    final value = '$_firstName $_lastName'.trim();
    return value.isEmpty ? 'Пользователь' : value;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = await PrefUtils.getUserId() ?? 0;

      _firstName = await PrefUtils.getUserFirstName();
      _lastName = await PrefUtils.getUserLastName();
      _role = await PrefUtils.getRole();

      if (userId > 0) {
        await _loadUserFromServer(userId);

        // Нужен всем ролям: тренер/медик/ассистент может дополнительно
        // иметь пресс-доступ, не теряя основной должности.
        await _loadPressAssignments(userId);

        if (_isCoach) {
          await _loadAssignedTeamForCoach(userId);
        }
      }
    } catch (e) {
      debugPrint('WorkspaceHub load error: $e');
    }

    if (!mounted) return;

    // Единственный rebuild после полной загрузки Hub.
    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadUserFromServer(int userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_apiBase/get_user.php?user_id=$userId'))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return;

      final root = Map<String, dynamic>.from(decoded);

      final user = root['user'] is Map
          ? Map<String, dynamic>.from(root['user'] as Map)
          : root;

      final player = root['player'] is Map
          ? Map<String, dynamic>.from(root['player'] as Map)
          : null;

      final team = root['player_team'] is Map
          ? Map<String, dynamic>.from(root['player_team'] as Map)
          : null;

      _firstName =
          '${user['first_name'] ?? user['firstName'] ?? _firstName}'.trim();
      _lastName =
          '${user['last_name'] ?? user['lastName'] ?? _lastName}'.trim();
      _role = '${user['role'] ?? _role}'.trim();
      _player = player;

      final club = root['club'] is Map
          ? Map<String, dynamic>.from(root['club'] as Map)
          : null;

      final userAvatar = _normalizeMediaUrl(
        user['avatar_url'] ??
            user['avatarUrl'] ??
            user['avatar'] ??
            user['photo_url'] ??
            user['photoUrl'] ??
            user['photo'] ??
            user['image_url'] ??
            user['imageUrl'] ??
            user['image'] ??
            user['profile_photo'] ??
            user['profilePhoto'] ??
            user['avatar_path'] ??
            user['avatarPath'] ??
            root['avatar_url'] ??
            root['avatar'] ??
            root['photo_url'] ??
            root['photo'] ??
            player?['avatar_url'] ??
            player?['avatarUrl'] ??
            player?['avatar'] ??
            player?['photo_url'] ??
            player?['photoUrl'] ??
            player?['photo'] ??
            player?['profile_photo'] ??
            player?['profilePhoto'] ??
            player?['avatar_path'] ??
            player?['avatarPath'],
      );

      if (userAvatar != null && userAvatar.isNotEmpty) {
        _userAvatarUrl = userAvatar;
      }

      final directClubLogo = _normalizeMediaUrl(
        user['club_logo_url'] ??
            user['clubLogoUrl'] ??
            user['club_logo'] ??
            user['clubLogo'] ??
            root['club_logo_url'] ??
            root['clubLogoUrl'] ??
            root['club_logo'] ??
            root['clubLogo'] ??
            club?['logo_url'] ??
            club?['logoUrl'] ??
            club?['logo'] ??
            club?['image_url'] ??
            club?['imageUrl'] ??
            club?['image'] ??
            club?['logo_path'] ??
            club?['logoPath'],
      );

      if (directClubLogo != null && directClubLogo.isNotEmpty) {
        _clubLogoUrl = directClubLogo;
      }

      final directClubName = _cleanString(
        user['club_name'] ??
            user['clubName'] ??
            user['organization_name'] ??
            user['organizationName'] ??
            club?['name'] ??
            club?['club_name'] ??
            club?['title'],
      );

      if (directClubName.isNotEmpty) {
        _clubName = directClubName;
      }

      if (team != null) {
        final loadedTeamId = _asInt(team['id'] ?? team['team_id']);
        final loadedTeamName =
            _cleanString(team['name'] ?? team['team_name']);
        final loadedClubName =
            _cleanString(team['club_name'] ?? team['clubName']);
        final loadedTeamLogo = _normalizeMediaUrl(
          team['logo_url'] ??
              team['logoUrl'] ??
              team['logo'] ??
              team['team_logo'] ??
              team['teamLogo'],
        );

        if (loadedTeamId > 0) _teamId = loadedTeamId;
        if (loadedTeamName.isNotEmpty) _teamName = loadedTeamName;
        if (loadedClubName.isNotEmpty) _clubName = loadedClubName;
        if (loadedTeamLogo != null && loadedTeamLogo.isNotEmpty) {
          _teamLogoUrl = loadedTeamLogo;
        }

        final loadedClubLogo = _normalizeMediaUrl(
          team['club_logo_url'] ??
              team['clubLogoUrl'] ??
              team['club_logo'] ??
              team['clubLogo'],
        );

        if (loadedClubLogo != null && loadedClubLogo.isNotEmpty) {
          _clubLogoUrl = loadedClubLogo;
        }
      }
    } catch (e) {
      debugPrint('WorkspaceHub get_user error: $e');
    }
  }

  Future<void> _loadPressAssignments(int userId) async {
    _pressAssignments.clear();
    if (userId <= 0) return;

    bool isPressValue(dynamic value) {
      final v = '${value ?? ''}'.trim().toLowerCase();
      return v == 'press_assistant' ||
          v == 'press' ||
          v == 'press_service' ||
          v.contains('press_assistant') ||
          v.contains('пресс');
    }

    void collect(dynamic node, List<Map<String, dynamic>> out) {
      if (node is Map) {
        final map = Map<String, dynamic>.from(node);

        final looksLikePressAssignment =
            isPressValue(map['profile']) ||
            isPressValue(map['link_profile']) ||
            isPressValue(map['staff_role']) ||
            isPressValue(map['position_code']);

        final teamId = _asInt(map['team_id'] ?? map['teamId']);
        final clubId = _asInt(map['club_id'] ?? map['clubId']);

        if (looksLikePressAssignment && (teamId > 0 || clubId > 0)) {
          final key = '$clubId:$teamId';
          final exists = out.any((item) {
            final itemClubId = _asInt(item['club_id'] ?? item['clubId']);
            final itemTeamId = _asInt(item['team_id'] ?? item['teamId']);
            return '$itemClubId:$itemTeamId' == key;
          });

          if (!exists) out.add(map);
        }

        for (final value in map.values) {
          collect(value, out);
        }
        return;
      }

      if (node is List) {
        for (final value in node) {
          collect(value, out);
        }
      }
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/get_trainer_profile.php'),
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(<String, dynamic>{
              'trainer_id': userId,
              'user_id': userId,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final found = <Map<String, dynamic>>[];
      collect(decoded, found);

      _pressAssignments
        ..clear()
        ..addAll(found);

      if (_pressAssignments.isNotEmpty) {
        final first = _pressAssignments.first;

        final club = _cleanString(
          first['club_name'] ?? first['clubName'],
        );
        final team = _cleanString(
          first['team_name'] ?? first['teamName'],
        );

        if ((_clubName ?? '').trim().isEmpty && club.isNotEmpty) {
          _clubName = club;
        }
        if ((_teamName ?? '').trim().isEmpty && team.isNotEmpty) {
          _teamName = team;
        }
      }
    } catch (e) {
      debugPrint('WorkspaceHub press access error: $e');
    }
  }

  Future<void> _loadAssignedTeamForCoach(int userId) async {
    _coachHasAssignedTeam = false;

    try {
      final response = await http
          .post(
            Uri.parse(
              '$_getTrainerTeamsUrl'
              '?coach_id=$userId'
              '&trainer_id=$userId',
            ),
            body: {
              'coach_id': userId.toString(),
              'trainer_id': userId.toString(),
            },
          )
          .timeout(const Duration(seconds: 12));

      final decoded = _tryDecode(response.body);

      final teams = _extractList(
        decoded,
        keys: const [
          'teams',
          'assigned_teams',
          'data',
          'items',
          'result',
        ],
      );

      for (final item in teams) {
        final id = _asInt(
          item['id'] ?? item['team_id'] ?? item['teamId'],
        );

        if (id <= 0) continue;

        final name = _cleanString(
          item['name'] ??
              item['team_name'] ??
              item['teamName'] ??
              item['title'],
        );

        final club = _cleanString(
          item['club_name'] ??
              item['clubName'] ??
              item['club_title'],
        );

        _coachHasAssignedTeam = true;
        _teamId = id;

        if (name.isNotEmpty) _teamName = name;
        if (club.isNotEmpty) _clubName = club;

        final logo = _normalizeMediaUrl(
          item['logo_url'] ??
              item['logoUrl'] ??
              item['logo'] ??
              item['team_logo'] ??
              item['teamLogo'],
        );

        if (logo != null && logo.isNotEmpty) {
          _teamLogoUrl = logo;
        }

        final clubLogo = _normalizeMediaUrl(
          item['club_logo_url'] ??
              item['clubLogoUrl'] ??
              item['club_logo'] ??
              item['clubLogo'],
        );

        if (clubLogo != null && clubLogo.isNotEmpty) {
          _clubLogoUrl = clubLogo;
        }

        return;
      }
    } catch (e) {
      debugPrint('WorkspaceHub coach teams error: $e');
    }
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _extractList(
    dynamic data, {
    required List<String> keys,
  }) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);

      for (final key in keys) {
        final value = map[key];

        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        if (value is Map) {
          final nested = Map<String, dynamic>.from(value);

          for (final nestedKey in keys) {
            final nestedValue = nested[nestedKey];

            if (nestedValue is List) {
              return nestedValue
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }
          }

          final id = _asInt(nested['id'] ?? nested['team_id']);

          if (id > 0) {
            return [nested];
          }
        }
      }

      final directId = _asInt(map['id'] ?? map['team_id']);

      if (directId > 0) {
        return [map];
      }
    }

    return const <Map<String, dynamic>>[];
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  String _cleanString(dynamic value) {
    final result = '${value ?? ''}'.trim();

    if (result.isEmpty || result.toLowerCase() == 'null') {
      return '';
    }

    return result;
  }

  String? _normalizeMediaUrl(dynamic value) {
    final raw = '${value ?? ''}'.trim();

    if (raw.isEmpty || raw.toLowerCase() == 'null') {
      return null;
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final clean = raw.replaceFirst(RegExp(r'^/+'), '');
    return 'https://sportotekaapp.ru/$clean';
  }

  Future<void> _openWorkspace() async {
    final userId = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;

    if (_isPlayer) {
      Get.to<void>(
        () => MyProfileScreen(userId: userId),
      );
      return;
    }

    if (_isCoach) {
      if (!_coachHasAssignedTeam || (_teamId ?? 0) <= 0) {
        Get.snackbar(
          'Кабинет тренера',
          'Тренеру пока не назначена команда.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      Get.to<void>(
        () => const ClubWorkspaceScreen(),
        arguments: <String, dynamic>{
          'mode': 'trainer_workspace',
          if (userId > 0) 'trainer_id': userId,
          'initial_team_id': _teamId,
        },
      );
      return;
    }

    if (_isClub) {
      Get.to<void>(
        () => const ClubWorkspaceScreen(),
        arguments: <String, dynamic>{
          'mode': 'club_workspace',
          if (userId > 0) 'club_id': userId,
          if ((_teamId ?? 0) > 0) 'initial_team_id': _teamId,
        },
      );
      return;
    }

    Get.snackbar(
      'Рабочее пространство',
      'Для этой роли отдельное рабочее пространство пока не назначено.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _openPressWorkspace() async {
    final userId = await PrefUtils.getUserId() ?? 0;
    if (!mounted || userId <= 0) return;

    if (_pressAssignments.isEmpty) {
      Get.snackbar(
        'Пресс-служба',
        'Для аккаунта пока не назначен пресс-доступ.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final first = _pressAssignments.first;

    final clubId = _asInt(first['club_id'] ?? first['clubId']);
    final teamId = _asInt(first['team_id'] ?? first['teamId']);
    final clubName = _cleanString(
      first['club_name'] ?? first['clubName'],
    );
    final teamName = _cleanString(
      first['team_name'] ?? first['teamName'],
    );
    final sportName = _cleanString(first['sport']);

    Get.to<void>(
      () => CmrPressAssistantScreen(
        userId: userId,
        clubId: clubId,
        teamId: teamId,
        clubName: clubName,
        teamName: teamName,
        sportName: sportName.isEmpty ? 'Футбол' : sportName,
        embedded: false,
      ),
    );
  }

  Future<void> _openPlayerTeam() async {
    final userId = await PrefUtils.getUserId() ?? 0;

    if (!mounted) return;
    if (!_isPlayer) return;

    final teamId = _teamId ?? 0;
    final teamName = (_teamName ?? '').trim();

    if (teamId <= 0) {
      Get.snackbar(
        'Моя команда',
        'К игроку пока не привязана команда.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.to<void>(
      () => PlayerDashboardScreen(
        teamId: teamId,
        teamName: teamName.isNotEmpty ? teamName : 'Моя команда',
        userId: userId,
        teamLogo: _teamLogoUrl,
      ),
    );
  }

  Future<void> _openProfile() async {
    final userId = await PrefUtils.getUserId();

    if (!mounted) return;

    Get.to<void>(
      () => MyProfileScreen(userId: userId),
    );
  }

  Future<void> _logoutFromProfile() async {
    await _clearLocalProfileSession();
    if (!mounted) return;
    Get.offAllNamed(AppRoutes.loginScreen);
  }

  Future<void> _clearLocalProfileSession() async {
    try {
      await PrefUtils.setIsSignIn(false);
    } catch (_) {}

    try {
      await PrefUtils.setUserId(0);
    } catch (_) {}

    try {
      await PrefUtils.setUserFirstName('');
    } catch (_) {}

    try {
      await PrefUtils.setUserLastName('');
    } catch (_) {}

    try {
      await PrefUtils.setUserEmail('');
    } catch (_) {}

    try {
      await PrefUtils.setRole('');
    } catch (_) {}

    try {
      await PrefUtils.setUserPhoto('');
    } catch (_) {}
  }

  _HubCardData? get _workspaceCard {
    if (_isPlayer) {
      return _HubCardData(
        title: 'Центр игрока',
        subtitle: 'Лента, поиск людей, видеоуроки, чаты и площадки',
        imageUrl: _userAvatarUrl,
        circularImage: true,
        onTap: _openWorkspace,
      );
    }

    if (_isCoach) {
      if (!_coachHasAssignedTeam) {
        return null;
      }

      final context = <String>[
        if ((_clubName ?? '').trim().isNotEmpty)
          _clubName!.trim(),
        if ((_teamName ?? '').trim().isNotEmpty)
          _teamName!.trim(),
      ].join(' · ');

      return _HubCardData(
        title: 'Мой кабинет тренера',
        subtitle: context.isNotEmpty
            ? '$context · личное рабочее пространство тренера'
            : 'Расписание, планы, тестирование, чаты и отчёты',
        imageUrl: _teamLogoUrl ?? _clubLogoUrl,
        onTap: _openWorkspace,
      );
    }

    if (_isClub) {
      final club = (_clubName ?? '').trim();

      return _HubCardData(
        title: 'Клубный кабинет',
        subtitle: club.isNotEmpty
            ? '$club · команды, тренеры, состав и аналитика'
            : 'Команды, тренеры, состав, календарь и аналитика',
        imageUrl: _clubLogoUrl,
        onTap: _openWorkspace,
      );
    }

    return null;
  }

  _HubCardData? get _pressCard {
    if (!_hasPressAccess) return null;

    final first = _pressAssignments.first;

    final firstClub = _cleanString(
      first['club_name'] ?? first['clubName'],
    );
    final firstTeam = _cleanString(
      first['team_name'] ?? first['teamName'],
    );

    final assignmentCount = _pressAssignments.length;

    final context = <String>[
      if (firstClub.isNotEmpty) firstClub,
      if (assignmentCount == 1 && firstTeam.isNotEmpty) firstTeam,
    ].join(' · ');

    final scope = assignmentCount > 1
        ? '$assignmentCount команд'
        : context.isNotEmpty
            ? context
            : 'назначенная команда';

    return _HubCardData(
      title: 'Пресс-служба',
      subtitle:
          '$scope · только пресс-лента, свои новости и разрешённые команды',
      imageUrl: _clubLogoUrl ?? _teamLogoUrl ?? _userAvatarUrl,
      circularImage: false,
      onTap: _openPressWorkspace,
    );
  }

  _HubCardData get _profileCard {
    return _HubCardData(
      title: 'Мой профиль',
      subtitle: 'Лента, поиск людей, видеоуроки, чаты и площадки',
      imageUrl: _userAvatarUrl,
      circularImage: true,
      onTap: _openProfile,
    );
  }

  _HubCardData get _playerTeamCard {
    final context = <String>[
      if ((_clubName ?? '').trim().isNotEmpty)
        _clubName!.trim(),
      if ((_teamName ?? '').trim().isNotEmpty)
        _teamName!.trim(),
    ].join(' · ');

    return _HubCardData(
      title: 'Моя команда',
      subtitle: context.isNotEmpty
          ? '$context · состав, календарь, матчи и командная жизнь'
          : 'Состав, календарь, матчи и командная жизнь',
      imageUrl: _teamLogoUrl ?? _clubLogoUrl,
      onTap: _openPlayerTeam,
    );
  }

  _HubCardData get _secondaryCard {
    return _isPlayer ? _playerTeamCard : _profileCard;
  }

  String get _choiceSubtitle {
    if (_hasPressAccess && _isCoach && _coachHasAssignedTeam) {
      return 'Выберите кабинет тренера, пресс-службу или личный профиль.';
    }

    if (_hasPressAccess && _isClub) {
      return 'Выберите клубный кабинет, пресс-службу или личный профиль.';
    }

    if (_hasPressAccess && _isPlayer) {
      return 'Выберите свой профиль, команду или пресс-службу.';
    }

    if (_hasPressAccess) {
      return 'Выберите CMR пресс-службы или личный профиль.';
    }

    if (_isCoach && _coachHasAssignedTeam) {
      return 'Выберите «Мой кабинет тренера» или личный профиль.';
    }

    if (_isCoach) {
      return 'Личный профиль доступен. Кабинет тренера появится '
          'после назначения команды.';
    }

    if (_isClub) {
      return 'Выберите клубный кабинет или личный профиль.';
    }

    if (_isPlayer) {
      return 'Выберите свой профиль или команду.';
    }

    return 'Продолжите работу в личном профиле.';
  }

  String get _accessHint {
    if (_hasPressAccess) {
      return 'CMR пресс-службы ограничен назначенными командами: '
          'сотрудник видит свою пресс-ленту и работает только со своими новостями.';
    }

    if (_isClub) {
      return 'Аккаунт клуба открывает клубное пространство '
          'и личный профиль.';
    }

    if (_isCoach && _coachHasAssignedTeam) {
      return 'Тренеру доступна назначенная рабочая зона '
          'и личный профиль.';
    }

    if (_isCoach) {
      return 'Кабинет тренера станет доступен '
          'после назначения команды.';
    }

    if (_isPlayer) {
      return 'Центр игрока открывает личную социальную зону, '
          'а «Моя команда» — только привязанную команду.';
    }

    return 'Доступные разделы определяются ролью '
        'и разрешениями аккаунта.';
  }

  String get _accountRoleLine {
    if (_isCoach && _coachHasAssignedTeam) {
      final team = (_teamName ?? '').trim();
      final base = team.isNotEmpty ? 'Тренер · $team' : 'Тренер';
      return _hasPressAccess ? '$base · Пресс-служба' : base;
    }

    if (_isCoach) {
      return _hasPressAccess ? 'Тренер · Пресс-служба' : 'Тренер';
    }

    if (_isClub) {
      return _hasPressAccess ? 'Клуб · Пресс-служба' : 'Клуб';
    }

    if (_isPlayer) {
      final team = (_teamName ?? '').trim();
      final base = team.isNotEmpty ? 'Игрок · $team' : 'Игрок';
      return _hasPressAccess ? '$base · Пресс-служба' : base;
    }

    if (_hasPressAccess) return 'Пресс-служба';

    return _role.trim().isEmpty
        ? 'Sportoteka'
        : _role.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              color: _green,
              strokeWidth: 2.2,
            ),
          ),
        ),
      );
    }

    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 700;
    final desktop = size.width >= 980;

    return Scaffold(
      backgroundColor: mobile ? _panel : _bg,
      body: SafeArea(
        child: mobile
            ? _buildMobile()
            : _buildWide(
                size,
                desktop: desktop,
              ),
      ),
    );
  }

  Widget _buildWide(
    Size size, {
    required bool desktop,
  }) {
    final horizontal = desktop ? 28.0 : 18.0;
    final vertical = desktop ? 24.0 : 16.0;

    final availableWidth =
        (size.width - horizontal * 2).clamp(320.0, 1180.0);

    final availableHeight =
        (size.height - vertical * 2).clamp(320.0, 1000.0);

    final leftWidth = desktop ? 360.0 : 300.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: vertical,
      ),
      child: Center(
        child: SizedBox(
          width: availableWidth,
          height: availableHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _divider,
                width: .8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.035),
                  blurRadius: 28,
                  spreadRadius: -18,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  SizedBox(
                    width: leftWidth,
                    height: availableHeight,
                    child: _buildWideIntroPane(
                      desktop: desktop,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: availableHeight,
                    color: _divider,
                  ),
                  Expanded(
                    child: SizedBox(
                      height: availableHeight,
                      child: _buildWideChoicePane(
                        desktop: desktop,
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

  Widget _buildWideIntroPane({
    required bool desktop,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 34 : 26,
        desktop ? 30 : 24,
        desktop ? 34 : 26,
        desktop ? 28 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrand(
            compact: false,
          ),
          SizedBox(
            height: desktop ? 92 : 64,
          ),
          Text(
            'Выберите, с чем\nвы хотите работать',
            style: _title(
              desktop ? 28 : 25,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sportoteka показывает только те рабочие пространства, '
            'которые доступны вашему аккаунту.',
            style: _body(
              desktop ? 13.4 : 13,
            ),
          ),
          SizedBox(
            height: desktop ? 90 : 64,
          ),
          _buildAccountMini(),
          const SizedBox(height: 18),
          _buildWideLogoutButton(),
          const SizedBox(height: 18),
          _buildFooter(
            mobile: false,
          ),
        ],
      ),
    );
  }

  Widget _buildWideChoicePane({
    required bool desktop,
  }) {
    final workspace = _workspaceCard;
    final press = _pressCard;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 50 : 34,
        desktop ? 54 : 40,
        desktop ? 50 : 34,
        desktop ? 42 : 34,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 540,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Куда вы хотите войти?',
                style: _title(
                  desktop ? 27 : 25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _choiceSubtitle,
                style: _body(13),
              ),
              SizedBox(
                height: desktop ? 32 : 26,
              ),
              if (workspace != null) ...[
                _WorkspaceChoiceCard(
                  data: workspace,
                  compact: false,
                ),
                const SizedBox(height: 12),
              ],
              if (press != null) ...[
                _WorkspaceChoiceCard(
                  data: press,
                  compact: false,
                ),
                const SizedBox(height: 12),
              ],
              _WorkspaceChoiceCard(
                data: _secondaryCard,
                compact: false,
              ),
              if (_isCoach &&
                  !_coachHasAssignedTeam) ...[
                const SizedBox(height: 14),
                const _TrainerNoTeamNotice(),
              ],
              const SizedBox(height: 20),
              Text(
                _accessHint,
                style: AppTypography.custom(
                  size: 10.5,
                  weight: FontWeight.w400,
                  color: _subtle,
                  height: 1.4,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobile() {
    final workspace = _workspaceCard;
    final press = _pressCard;

    return ColoredBox(
      color: _panel,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBrand(
                        compact: true,
                      ),
                      const SizedBox(height: 34),
                      _buildAccountMini(),
                      const SizedBox(height: 32),
                      Text(
                        'Куда вы хотите войти?',
                        style: _title(25),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _choiceSubtitle,
                        style: _body(12.5),
                      ),
                      const SizedBox(height: 24),
                      if (workspace != null) ...[
                        _WorkspaceChoiceCard(
                          data: workspace,
                          compact: true,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (press != null) ...[
                        _WorkspaceChoiceCard(
                          data: press,
                          compact: true,
                        ),
                        const SizedBox(height: 10),
                      ],
                      _WorkspaceChoiceCard(
                        data: _secondaryCard,
                        compact: true,
                      ),
                      if (_isCoach &&
                          !_coachHasAssignedTeam) ...[
                        const SizedBox(height: 12),
                        const _TrainerNoTeamNotice(
                          compact: true,
                        ),
                      ],
                      const SizedBox(height: 22),
                      Text(
                        _accessHint,
                        style: AppTypography.custom(
                          size: 10.4,
                          weight: FontWeight.w400,
                          color: _subtle,
                          height: 1.4,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMobileLogoutButton(),
                        const SizedBox(height: 12),
                        _buildFooter(
                          mobile: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrand({
    required bool compact,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SportotekaMark(
          size: compact ? 34 : 40,
        ),
        const SizedBox(width: 10),
        Text(
          'SPORTOTEKA',
          style: AppTypography.custom(
            size: compact ? 15.2 : 16.4,
            weight: FontWeight.w700,
            color: _text,
            height: 1,
            letterSpacing: .15,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountMini() {
    return Row(
      children: [
        _HubIdentityImage(
          imageUrl: _userAvatarUrl,
          size: 46,
          circular: true,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.custom(
                  size: 12.8,
                  weight: FontWeight.w600,
                  color: _text,
                  height: 1.18,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _accountRoleLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.custom(
                  size: 10.5,
                  weight: FontWeight.w400,
                  color: _secondary,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWideLogoutButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: _soft,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: _logoutFromProfile,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.logout_rounded,
                  size: 16,
                  color: _secondary,
                ),
                const SizedBox(width: 7),
                Text(
                  'Выйти из профиля',
                  style: AppTypography.custom(
                    size: 10.8,
                    weight: FontWeight.w600,
                    color: _secondary,
                    height: 1.2,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLogoutButton() {
    return Material(
      color: _soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _logoutFromProfile,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 17,
                color: _secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Выйти из профиля',
                style: AppTypography.custom(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: _secondary,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter({
    required bool mobile,
  }) {
    return Padding(
      padding: mobile
          ? const EdgeInsets.only(
              top: 2,
              bottom: 0,
            )
          : EdgeInsets.zero,
      child: Text(
        '© Sportoteka · Все права защищены',
        textAlign: mobile
            ? TextAlign.center
            : TextAlign.left,
        style: AppTypography.custom(
          size: 10.3,
          weight: FontWeight.w400,
          color: _subtle,
          height: 1.4,
          letterSpacing: 0,
        ),
      ),
    );
  }

  TextStyle _title(double size) {
    return AppTypography.custom(
      size: size,
      weight: FontWeight.w600,
      color: _text,
      height: 1.12,
      letterSpacing: 0,
    );
  }

  TextStyle _body(double size) {
    return AppTypography.custom(
      size: size,
      weight: FontWeight.w400,
      color: _secondary,
      height: 1.48,
      letterSpacing: 0,
    );
  }
}

class _HubCardData {
  const _HubCardData({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageUrl,
    this.circularImage = false,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool circularImage;
  final VoidCallback onTap;
}

class _WorkspaceChoiceCard extends StatelessWidget {
  const _WorkspaceChoiceCard({
    required this.data,
    required this.compact,
  });

  final _HubCardData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(compact ? 14 : 12),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(compact ? 14 : 12),
        child: Container(
          constraints: BoxConstraints(
            minHeight: compact ? 96 : 112,
          ),
          decoration: BoxDecoration(
            color: compact
                ? _WorkspaceHubScreenState._soft
                : _WorkspaceHubScreenState._panel,
            borderRadius: BorderRadius.circular(compact ? 14 : 12),
            border: compact
                ? null
                : Border.all(
                    color: _WorkspaceHubScreenState._divider,
                    width: .8,
                  ),
          ),
          padding: EdgeInsets.fromLTRB(
            compact ? 13 : 16,
            compact ? 13 : 15,
            compact ? 12 : 15,
            compact ? 13 : 15,
          ),
          child: Row(
            children: [
              if (!compact) ...[
                Container(
                  width: 3,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _WorkspaceHubScreenState._green,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 15),
              ],
              _HubIdentityImage(
                imageUrl: data.imageUrl,
                size: compact ? 50 : 56,
                circular: data.circularImage,
              ),
              SizedBox(
                width: compact ? 12 : 15,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.custom(
                        size: compact ? 13.8 : 14.8,
                        weight: FontWeight.w600,
                        color:
                            _WorkspaceHubScreenState._text,
                        height: 1.18,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.subtitle,
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.custom(
                        size: compact ? 11 : 11.6,
                        weight: FontWeight.w400,
                        color: _WorkspaceHubScreenState
                            ._secondary,
                        height: 1.38,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _SportotekaDots(
                color:
                    _WorkspaceHubScreenState._greenDark,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubIdentityImage extends StatelessWidget {
  const _HubIdentityImage({
    required this.imageUrl,
    required this.size,
    this.circular = false,
  });

  final String? imageUrl;
  final double size;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    final radius = circular ? size / 2 : 11.0;

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _WorkspaceHubScreenState._greenSoft,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: const _SportotekaDots(
          color: _WorkspaceHubScreenState._greenDark,
        ),
      );
    }

    if (url.isEmpty) {
      return fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}

class _TrainerNoTeamNotice extends StatelessWidget {
  const _TrainerNoTeamNotice({
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: _WorkspaceHubScreenState._soft,
        borderRadius: BorderRadius.circular(compact ? 12 : 10),
        border: compact
            ? null
            : Border.all(
                color: _WorkspaceHubScreenState._divider,
                width: .7,
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: _SportotekaDots(
              color:
                  _WorkspaceHubScreenState._subtle,
              compact: true,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Кабинет тренера появится после назначения '
              'тренера на команду.',
              style: AppTypography.custom(
                size: 10.7,
                weight: FontWeight.w400,
                color:
                    _WorkspaceHubScreenState._secondary,
                height: 1.4,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SportotekaMark extends StatelessWidget {
  const _SportotekaMark({
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const Center(
        child: _SportotekaDots(
          color:
              _WorkspaceHubScreenState._green,
          brand: true,
        ),
      ),
    );
  }
}

class _SportotekaDots extends StatelessWidget {
  const _SportotekaDots({
    required this.color,
    this.compact = false,
    this.brand = false,
  });

  final Color color;
  final bool compact;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final scale = brand
        ? 1.18
        : compact
            ? .72
            : 1.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: <Widget>[
        _SportotekaDot(
          size: 3.4 * scale,
          color: color,
          opacity: .32,
        ),
        SizedBox(width: 3.2 * scale),
        _SportotekaDot(
          size: 4.4 * scale,
          color: color,
          opacity: .55,
        ),
        SizedBox(width: 3.2 * scale),
        _SportotekaDot(
          size: 5.4 * scale,
          color: color,
          opacity: .78,
        ),
        SizedBox(width: 3.2 * scale),
        _SportotekaDot(
          size: 6.4 * scale,
          color: color,
          opacity: 1,
        ),
      ],
    );
  }
}

class _SportotekaDot extends StatelessWidget {
  const _SportotekaDot({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
