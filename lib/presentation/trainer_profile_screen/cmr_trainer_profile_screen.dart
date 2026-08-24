// lib/presentation/trainer_profile_screen/cmr_trainer_profile_screen.dart
//
// Подробный рабочий профиль тренера.
// Единый серверный профиль используется и клубом, и самим тренером.
//
// Разделы:
// 1. Карточка тренера
// 2. Команды и локации
// 3. Расписание
// 4. Планы-конспекты
// 5. Тестирование

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/plans/plan_detail_screen.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_club_ai_assistant_panel.dart';
import 'package:sportoteka/presentation/trainer_profile_screen/trainer_hr_sections.dart';
import 'package:sportoteka/presentation/testing/cmr_testing_panel.dart';

enum TrainerProfileSection {
  card,
  work,
  schedule,
  attendance,
  plans,
  testing,
  health,
  documents,
}

class CmrTrainerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> trainer;
  final int clubId;
  final String clubName;
  final bool embeddedInWorkspace;
  final bool allowEdit;
  final VoidCallback? onClose;
  final VoidCallback? onMessage;
  final VoidCallback? onAssign;
  final List<Map<String, dynamic>> availableTeams;
  final Future<bool> Function(int teamId, String profile)? onAssignTeam;
  final VoidCallback? onChanged;

  const CmrTrainerProfileScreen({
    super.key,
    required this.trainer,
    required this.clubId,
    required this.clubName,
    this.embeddedInWorkspace = true,
    this.allowEdit = false,
    this.onClose,
    this.onMessage,
    this.onAssign,
    this.availableTeams = const <Map<String, dynamic>>[],
    this.onAssignTeam,
    this.onChanged,
  });

  @override
  State<CmrTrainerProfileScreen> createState() =>
      _CmrTrainerProfileScreenState();
}

class _CmrTrainerProfileScreenState
    extends State<CmrTrainerProfileScreen> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';

  static const String _profileUrl =
      '$_apiBase/get_trainer_profile.php';
  static const String _updateProfileUrl =
      '$_apiBase/update_trainer_profile.php';
  static const String _teamEventsUrl =
      '$_apiBase/get_team_events.php';
  static const String _testingSessionsUrl =
      '$_apiBase/get_testing_sessions.php';
  static const String _testingMatrixUrl =
      '$_apiBase/get_testing_matrix.php';
  static const String _testingPlayersUrl =
      '$_apiBase/get_players_by_team.php';
  static const String _trainingPlansUrl =
      '$_apiBase/list_training_plans.php';
  static const String _latestTrainingPlansUrl =
      '$_apiBase/get_latest_training_plans.php';

  TrainerProfileSection _section = TrainerProfileSection.card;

  bool _loading = false;
  bool _refreshing = false;
  bool _saving = false;
  bool _aiOpen = false;
  String? _error;

  late Map<String, dynamic> _profile;
  List<Map<String, dynamic>> _schedule = <Map<String, dynamic>>[];

  // 0 = все команды тренера.
  int _plansTeamId = 0;
  int _testingTeamId = 0;

  late DateTime _scheduleCursor;
  late DateTime _scheduleSelected;

  late DateTime _plansCursor;
  late DateTime _plansSelected;
  bool _plansDateFilterActive = false;
  bool _plansLoading = false;

  late DateTime _testingCursor;
  late DateTime _testingSelected;
  bool _testingDateFilterActive = false;
  List<Map<String, dynamic>> _trainerPlans =
      <Map<String, dynamic>>[];
  Map<String, dynamic>? _selectedPlanPreview;

  final Map<int, List<Map<String, dynamic>>> _testingByTeam =
      <int, List<Map<String, dynamic>>>{};
  final Set<int> _testingLoadingTeams = <int>{};

  Map<String, dynamic>? _selectedTestingSession;
  bool _testingDetailLoading = false;
  String? _testingDetailError;
  List<Map<String, dynamic>> _testingDetailPlayers =
      <Map<String, dynamic>>[];

  bool _editorOpen = false;
  bool _assignTeamOpen = false;
  bool _assignTeamSaving = false;
  int _assignTeamId = 0;
  String _assignProfile = 'extra';
  XFile? _pickedPhoto;

  late final TextEditingController _positionC;
  late final TextEditingController _specializationC;
  late final TextEditingController _cityC;
  late final TextEditingController _locationsC;
  late final TextEditingController _birthdayC;
  late final TextEditingController _experienceC;
  late final TextEditingController _phoneC;
  late final TextEditingController _bioC;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.trainer);

    _positionC = TextEditingController();
    _specializationC = TextEditingController();
    _cityC = TextEditingController();
    _locationsC = TextEditingController();
    _birthdayC = TextEditingController();
    _experienceC = TextEditingController();
    _phoneC = TextEditingController();
    _bioC = TextEditingController();

    final now = DateTime.now();
    _scheduleSelected =
        DateTime(now.year, now.month, now.day);
    _scheduleCursor =
        DateTime(now.year, now.month, 1);

    _plansSelected =
        DateTime(now.year, now.month, now.day);
    _plansCursor =
        DateTime(now.year, now.month, 1);
    _plansDateFilterActive = false;

    _testingSelected =
        DateTime(now.year, now.month, now.day);
    _testingCursor =
        DateTime(now.year, now.month, 1);
    _testingDateFilterActive = false;

    // Сразу показываем данные, которые уже пришли из списка тренеров.
    _fillEditor();
    _load();
  }

  @override
  void didUpdateWidget(
    covariant CmrTrainerProfileScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final oldId = _trainerId(oldWidget.trainer);
    final newId = _trainerId(widget.trainer);

    if (oldId != newId) {
      _profile = Map<String, dynamic>.from(widget.trainer);
      _section = TrainerProfileSection.card;
      _editorOpen = false;
      _testingByTeam.clear();
      _testingLoadingTeams.clear();
      _selectedTestingSession = null;
      _testingDetailLoading = false;
      _testingDetailError = null;
      _testingDetailPlayers = <Map<String, dynamic>>[];
      _trainerPlans = <Map<String, dynamic>>[];
      _selectedPlanPreview = null;
      _plansTeamId = 0;

      final now = DateTime.now();
      _plansSelected =
          DateTime(now.year, now.month, now.day);
      _plansCursor =
          DateTime(now.year, now.month, 1);
      _plansDateFilterActive = false;

      _testingSelected =
          DateTime(now.year, now.month, now.day);
      _testingCursor =
          DateTime(now.year, now.month, 1);
      _testingDateFilterActive = false;

      _assignTeamOpen = false;
      _assignTeamSaving = false;
      _assignTeamId = 0;
      _assignProfile = 'extra';

      _fillEditor();
      _load();
    }
  }

  @override
  void dispose() {
    _positionC.dispose();
    _specializationC.dispose();
    _cityC.dispose();
    _locationsC.dispose();
    _birthdayC.dispose();
    _experienceC.dispose();
    _phoneC.dispose();
    _bioC.dispose();
    super.dispose();
  }

  String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  int _i(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_s(value)) ?? 0;
  }

  int _trainerId(Map<String, dynamic> trainer) => _i(
        trainer['user_id'] ??
            trainer['userId'] ??
            trainer['trainer_id'] ??
            trainer['trainerId'] ??
            trainer['coach_id'] ??
            trainer['id'],
      );

  int _teamId(Map<String, dynamic> team) => _i(
        team['id'] ??
            team['team_id'] ??
            team['teamId'],
      );

  String _normalizeImage(String raw) {
    final url = raw.trim();
    if (url.isEmpty || url == 'null') return '';
    if (url.startsWith('http://') ||
        url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) {
      return 'https://sportotekaapp.ru$url';
    }
    if (url.startsWith('uploads/')) {
      return 'https://sportotekaapp.ru/$url';
    }
    return 'https://sportotekaapp.ru/uploads/$url';
  }

  String get _name {
    final full = _s(
      _profile['full_name'] ??
          _profile['fullName'] ??
          _profile['name'],
    );
    if (full.isNotEmpty) return full;

    final first = _s(_profile['first_name']);
    final last = _s(_profile['last_name']);
    final joined = '$first $last'.trim();
    return joined.isEmpty ? 'Тренер' : joined;
  }

  String get _role {
    final raw = _s(
      _profile['position'] ??
          _profile['role_title'] ??
          _profile['specialization'] ??
          _profile['staff_role'] ??
          _profile['role'],
    );
    if (raw.isEmpty || raw == 'extra') return 'Тренер';
    if (raw == 'main') return 'Главный тренер';
    if (raw == 'assistant') return 'Ассистент';
    if (raw == 'doctor') return 'Медик';
    return raw;
  }

  String get _photo => _normalizeImage(
        _s(
          _profile['photo'] ??
              _profile['photo_url'] ??
              _profile['avatar'] ??
              _profile['avatar_url'],
        ),
      );

  String get _email => _s(_profile['email']);

  String get _phone => _s(
        _profile['phone'] ??
            _profile['telephone'] ??
            _profile['phone_number'] ??
            _profile['mobile'],
      );

  String get _birthday => _s(
        _profile['birthday'] ??
            _profile['birth_date'] ??
            _profile['date_birth'] ??
            _profile['dob'],
      );

  String get _experience => _s(
        _profile['experience'] ??
            _profile['experience_text'] ??
            _profile['work_experience'],
      );

  String get _bio => _s(
        _profile['bio'] ??
            _profile['description'] ??
            _profile['about'] ??
            _profile['about_me'],
      );

  String get _city => _s(
        _profile['city'] ??
            _profile['town'],
      );

  String get _specialization => _s(
        _profile['specialization'] ??
            _profile['speciality'] ??
            _profile['category'],
      );

  List<Map<String, dynamic>> get _teams {
    final raw = _profile['teams'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final id = _i(
      _profile['team_id'] ??
          _profile['teamId'],
    );
    final name = _s(
      _profile['team_name'] ??
          _profile['teamName'],
    );

    if (id <= 0 && name.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    return <Map<String, dynamic>>[
      <String, dynamic>{
        'team_id': id,
        'team_name':
            name.isEmpty ? 'Команда #$id' : name,
        'team_logo':
            _profile['team_logo'] ??
            _profile['teamLogo'],
        'link_profile':
            _profile['link_profile'] ??
            _profile['profile'],
      },
    ];
  }

  String _teamName(Map<String, dynamic> team) {
    final name = _s(
      team['name'] ??
          team['team_name'] ??
          team['title'],
    );
    return name.isEmpty ? 'Команда' : name;
  }

  String _teamLogo(Map<String, dynamic> team) {
    return _normalizeImage(
      _s(
        team['logo_url'] ??
            team['logo'] ??
            team['team_logo'] ??
            team['photo'],
      ),
    );
  }

  String _teamRole(Map<String, dynamic> team) {
    final raw = _s(
      team['link_profile'] ??
          team['profile'] ??
          team['role'],
    ).toLowerCase();

    if (raw == 'main' ||
        raw == 'head' ||
        raw.contains('глав')) {
      return 'Главный тренер';
    }
    if (raw.contains('assistant') ||
        raw.contains('ассист')) {
      return 'Ассистент';
    }
    if (raw.contains('doctor') ||
        raw.contains('мед')) {
      return 'Медик';
    }
    if (raw.contains('manager') ||
        raw.contains('admin')) {
      return 'Администратор';
    }
    return 'Тренер';
  }

  DateTime? _date(dynamic raw) {
    final value = _s(raw);
    if (value.isEmpty) return null;
    return DateTime.tryParse(
      value.replaceFirst(' ', 'T'),
    );
  }

  dynamic _decode(String body) {
    try {
      final startObject = body.indexOf('{');
      final startList = body.indexOf('[');

      if (startObject < 0 && startList < 0) {
        return null;
      }

      final start = startObject >= 0 &&
              (startList < 0 || startObject < startList)
          ? startObject
          : startList;

      return jsonDecode(body.substring(start));
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _extractList(
    dynamic data,
    List<String> keys,
  ) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (data is Map) {
      for (final key in keys) {
        final value = data[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      for (final key in keys) {
        final nested = data[key];
        if (nested is Map) {
          final list = _extractList(nested, keys);
          if (list.isNotEmpty) return list;
        }
      }
    }

    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _pickMap(
    dynamic data,
    List<String> keys,
  ) {
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final value = data[key];
        if (value is Map) {
          return Map<String, dynamic>.from(value);
        }
      }
      return data;
    }

    if (data is Map) {
      final converted = Map<String, dynamic>.from(data);
      for (final key in keys) {
        final value = converted[key];
        if (value is Map) {
          return Map<String, dynamic>.from(value);
        }
      }
      return converted;
    }

    return null;
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _refreshing = true;
      _error = null;
    });

    final trainerId = _trainerId(_profile);

    try {
      if (trainerId > 0) {
        final response = await http
            .post(
              Uri.parse(_profileUrl),
              headers: const <String, String>{
                'Content-Type':
                    'application/json; charset=utf-8',
              },
              body: jsonEncode(
                <String, dynamic>{
                  'trainer_id': trainerId,
                },
              ),
            )
            .timeout(const Duration(seconds: 15));

        final data = _decode(response.body);
        final loaded = _pickMap(
          data,
          const <String>[
            'profile',
            'trainer',
            'user',
            'data',
          ],
        );

        if (loaded != null) {
          final merged = <String, dynamic>{
            ..._profile,
          };

          for (final entry in loaded.entries) {
            if (entry.value != null &&
                _s(entry.value).isNotEmpty) {
              merged[entry.key] = entry.value;
            }
          }

          // Назначения из списка клуба не теряем,
          // если get_trainer_profile их не возвращает.
          if (merged['teams'] is! List ||
              (merged['teams'] as List).isEmpty) {
            merged['teams'] = _teams;
          }

          _profile = merged;
        }
      }

      _schedule = await _loadSchedule();
      _trainerPlans = await _loadTrainerPlans();

      if (!_plansDateFilterActive &&
          _trainerPlans.isNotEmpty) {
        final latestPlanDate =
            _planAddedDate(_trainerPlans.first);
        if (latestPlanDate != null) {
          _plansCursor = DateTime(
            latestPlanDate.year,
            latestPlanDate.month,
            1,
          );
        }
      }

      if (_teams.isNotEmpty) {
        _testingTeamId =
            _testingTeamId > 0
                ? _testingTeamId
                : _teamId(_teams.first);
      }

      _fillEditor();

      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      // Основной payload уже есть из списка тренеров.
      // Сетевая ошибка догрузки не должна выбрасывать пользователя
      // из рабочего профиля в полноэкранную ошибку.
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = null;
      });
    }
  }

  Future<List<Map<String, dynamic>>>
      _loadSchedule() async {
    final rows = <Map<String, dynamic>>[];

    for (final team in _teams) {
      final teamId = _teamId(team);
      if (teamId <= 0) continue;

      try {
        final uri = Uri.parse(
          _teamEventsUrl,
        ).replace(
          queryParameters: <String, String>{
            'team_id': '$teamId',
          },
        );

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 12));

        final data = _decode(response.body);
        final events = _extractList(
          data,
          const <String>[
            'events',
            'items',
            'rows',
            'data',
          ],
        );

        for (final event in events) {
          rows.add(
            <String, dynamic>{
              ...event,
              'team_id': teamId,
              'team_name': _teamName(team),
            },
          );
        }
      } catch (_) {
        // Одна команда не должна ломать весь профиль.
      }
    }

    rows.sort((a, b) {
      final da = _date(
            a['start_at'] ??
                a['date'] ??
                a['event_date'],
          ) ??
          DateTime(2100);
      final db = _date(
            b['start_at'] ??
                b['date'] ??
                b['event_date'],
          ) ??
          DateTime(2100);
      return da.compareTo(db);
    });

    return rows;
  }

  Future<List<Map<String, dynamic>>>
      _loadTrainerPlans() async {
    final trainerId = _trainerId(_profile);

    if (trainerId <= 0 || widget.clubId <= 0) {
      return const <Map<String, dynamic>>[];
    }

    if (mounted) {
      setState(() => _plansLoading = true);
    }

    final result =
        <String, Map<String, dynamic>>{};

    void addPlans(
      List<Map<String, dynamic>> plans, {
      int fallbackTeamId = 0,
      String fallbackTeamName = '',
      bool backendFilteredByTrainer = false,
    }) {
      for (final rawPlan in plans) {
        final plan =
            Map<String, dynamic>.from(rawPlan);

        if (!backendFilteredByTrainer) {
          // В club_training_plans тренер хранится прежде всего в coach_id.
          // created_by здесь НЕ используем: это может быть клубный аккаунт,
          // который создал запись от имени тренера.
          final ownerId = _i(
            plan['coach_id'] ??
                plan['trainer_id'],
          );

          final trainerName = _s(
            plan['trainer_name'] ??
                plan['coach_name'],
          ).toLowerCase();

          final profileName =
              _name.trim().toLowerCase();

          if (ownerId > 0 &&
              ownerId != trainerId) {
            continue;
          }

          if (ownerId <= 0) {
            if (trainerName.isEmpty ||
                profileName.isEmpty ||
                trainerName != profileName) {
              continue;
            }
          }
        }

        final rawTeamId = _i(
          plan['team_id'] ??
              plan['teamId'],
        );

        final resolvedTeamId =
            rawTeamId > 0
                ? rawTeamId
                : fallbackTeamId;

        final knownTeam =
            _teamById(resolvedTeamId);

        final rawTeamName = _s(
          plan['team_name'] ??
              plan['teamName'],
        );

        plan['_team_id'] =
            resolvedTeamId;

        plan['_team_name'] =
            rawTeamName.isNotEmpty
                ? rawTeamName
                : knownTeam != null
                    ? _teamName(knownTeam)
                    : fallbackTeamName.isNotEmpty
                        ? fallbackTeamName
                        : 'Команда';

        final id = _i(
          plan['id'] ??
              plan['plan_id'],
        );

        final created = _s(
          plan['created_at'] ??
              plan['plan_date'] ??
              plan['date'],
        );

        final key = id > 0
            ? 'id:$id'
            : '${plan['_team_id']}|'
                '${_s(plan['theme'] ?? plan['title'])}|'
                '$created';

        result[key] = plan;
      }
    }

    try {
      // Основной GET — тот же endpoint, который используется
      // в club_workspace_screen для последних планов тренера.
      try {
        final uri = Uri.parse(
          _latestTrainingPlansUrl,
        ).replace(
          queryParameters: <String, String>{
            'club_id': '${widget.clubId}',
            'trainer_id': '$trainerId',
            'limit': '500',
          },
        );

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 15));

        addPlans(
          _extractList(
            _decode(response.body),
            const <String>[
              'plans',
              'items',
              'data',
              'result',
              'rows',
            ],
          ),
          backendFilteredByTrainer: true,
        );
      } catch (_) {}

      // Fallback по каждой команде — на случай старой версии endpoint.
      if (result.isEmpty && _teams.isNotEmpty) {
        for (final team in _teams) {
          final teamId = _teamId(team);
          if (teamId <= 0) continue;

          try {
            final uri = Uri.parse(
              _latestTrainingPlansUrl,
            ).replace(
              queryParameters: <String, String>{
                'club_id': '${widget.clubId}',
                'team_id': '$teamId',
                'trainer_id': '$trainerId',
                'limit': '500',
              },
            );

            final response = await http
                .get(uri)
                .timeout(const Duration(seconds: 12));

            addPlans(
              _extractList(
                _decode(response.body),
                const <String>[
                  'plans',
                  'items',
                  'data',
                  'result',
                  'rows',
                ],
              ),
              fallbackTeamId: teamId,
              fallbackTeamName: _teamName(team),
              backendFilteredByTrainer: true,
            );
          } catch (_) {}
        }
      }

      // Последний fallback — старый list_training_plans.php.
      if (result.isEmpty) {
        final sources = _teams.isEmpty
            ? <Map<String, dynamic>>[
                const <String, dynamic>{
                  'team_id': 0,
                  'team_name': 'Без команды',
                },
              ]
            : _teams;

        for (final team in sources) {
          final teamId = _teamId(team);

          try {
            final response = await http
                .post(
                  Uri.parse(_trainingPlansUrl),
                  headers: const <String, String>{
                    'Content-Type':
                        'application/json; charset=utf-8',
                  },
                  body: jsonEncode(
                    <String, dynamic>{
                      'club_id': widget.clubId,
                      'clubId': widget.clubId,
                      'team_id': teamId,
                      'teamId': teamId,
                      'folder_id': 0,
                      'folderId': 0,
                    },
                  ),
                )
                .timeout(
                  const Duration(seconds: 12),
                );

            addPlans(
              _extractList(
                _decode(response.body),
                const <String>[
                  'items',
                  'data',
                  'plans',
                  'rows',
                  'result',
                ],
              ),
              fallbackTeamId: teamId,
              fallbackTeamName: _teamName(team),
            );
          } catch (_) {}
        }
      }

      final rows = result.values.toList()
        ..sort((a, b) {
          final da =
              _planAddedDate(a) ??
                  DateTime(1970);
          final db =
              _planAddedDate(b) ??
                  DateTime(1970);
          return db.compareTo(da);
        });

      return rows;
    } finally {
      if (mounted) {
        setState(
          () => _plansLoading = false,
        );
      }
    }
  }

  DateTime? _planAddedDate(
    Map<String, dynamic> plan,
  ) {
    return _date(
      plan['created_at'] ??
          plan['plan_date'] ??
          plan['date'],
    );
  }

  DateTime? _planTrainingDate(
    Map<String, dynamic> plan,
  ) {
    return _date(
      plan['plan_date'] ??
          plan['date'] ??
          plan['created_at'],
    );
  }

  int _planTeamId(
    Map<String, dynamic> plan,
  ) {
    return _i(
      plan['_team_id'] ??
          plan['team_id'] ??
          plan['teamId'],
    );
  }

  String _planTeamName(
    Map<String, dynamic> plan,
  ) {
    final value = _s(
      plan['_team_name'] ??
          plan['team_name'] ??
          plan['teamName'],
    );
    return value.isEmpty
        ? 'Команда'
        : value;
  }

  String _planTitle(
    Map<String, dynamic> plan,
  ) {
    final theme = _s(
      plan['theme'] ??
          plan['title'] ??
          plan['name'],
    );
    if (theme.isNotEmpty) return theme;

    final cycle =
        _s(plan['cycle_title']);
    if (cycle.isNotEmpty) return cycle;

    final id = _i(
      plan['id'] ??
          plan['plan_id'],
    );
    return id > 0
        ? 'План #$id'
        : 'План-конспект';
  }

  String _planDescription(
    Map<String, dynamic> plan,
  ) {
    return _s(
      plan['description'] ??
          plan['plan_description'] ??
          plan['comment'] ??
          plan['notes'],
    );
  }

  void _openTrainingPlan(
    Map<String, dynamic> plan,
  ) {
    final planId = _i(
      plan['id'] ??
          plan['plan_id'],
    );

    if (planId <= 0) {
      _snack(
        'План ещё не сохранён на сервере',
      );
      return;
    }

    final teamId = _planTeamId(plan);

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlanDetailScreen(
          initialArgs: <String, dynamic>{
            'planId': planId,
            'plan_id': planId,
            'clubId': widget.clubId,
            'club_id': widget.clubId,
            'clubName': widget.clubName,
            'club_name': widget.clubName,
            'teamId': teamId,
            'team_id': teamId,
            'teamName': _planTeamName(plan),
            'team_name': _planTeamName(plan),
            'folderId': _i(
              plan['folder_id'],
            ),
            'folder_id': _i(
              plan['folder_id'],
            ),
            'trainerName': _name,
            'trainer_name': _name,
          },
        ),
      ),
    );
  }

  void _fillEditor() {
    _positionC.text = _role;
    _specializationC.text = _specialization;
    _cityC.text = _city;
    _birthdayC.text = _birthday;
    _experienceC.text = _experience;
    _phoneC.text = _phone;
    _bioC.text = _bio;

    final storedLocations = _s(
      _profile['work_locations'] ??
          _profile['locations'],
    );

    if (storedLocations.isNotEmpty) {
      _locationsC.text = storedLocations;
    } else {
      _locationsC.text =
          _locationNames.join(', ');
    }
  }

  List<String> get _locationNames {
    final values = <String>{};

    for (final event in _schedule) {
      final location = _s(
        event['location'] ??
            event['venue'] ??
            event['address'] ??
            event['place'],
      );
      if (location.isNotEmpty) values.add(location);
    }

    final stored = _s(
      _profile['work_locations'] ??
          _profile['locations'],
    );

    if (stored.isNotEmpty) {
      for (final piece in stored.split(',')) {
        final value = piece.trim();
        if (value.isNotEmpty) values.add(value);
      }
    }

    return values.toList();
  }

  List<Map<String, dynamic>> get _upcomingSchedule {
    final now = DateTime.now();
    final floor =
        DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));

    return _schedule.where((event) {
      final date = _date(
        event['start_at'] ??
            event['date'] ??
            event['event_date'],
      );
      return date != null && !date.isBefore(floor);
    }).toList();
  }

  Future<void> _pickPhoto() async {
    if (!widget.allowEdit) return;

    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
    );

    if (x != null && mounted) {
      setState(() => _pickedPhoto = x);
    }
  }

  bool _success(dynamic data) {
    if (data is! Map) return false;

    if (data['success'] == true ||
        data['success'] == 1) {
      return true;
    }

    final status = _s(data['status']).toLowerCase();
    return status == 'success' || status == 'ok';
  }

  Future<void> _saveProfile() async {
    if (_saving || !widget.allowEdit) return;

    final trainerId = _trainerId(_profile);
    if (trainerId <= 0) {
      _snack('Не найден ID тренера');
      return;
    }

    setState(() => _saving = true);

    try {
      final actorUserId =
          await PrefUtils.getUserId() ?? 0;
      final actorRole =
          (await PrefUtils.getRole())
              .trim()
              .toLowerCase();

      http.Response response;

      final fields = <String, String>{
        'actor_user_id': '$actorUserId',
        'actor_role': actorRole,
        'trainer_id': '$trainerId',
        'position': _positionC.text.trim(),
        'specialization':
            _specializationC.text.trim(),
        'city': _cityC.text.trim(),
        'work_locations':
            _locationsC.text.trim(),
        'birthday': _birthdayC.text.trim(),
        'experience': _experienceC.text.trim(),
        'phone': _phoneC.text.trim(),
        'bio': _bioC.text.trim(),
      };

      if (_pickedPhoto != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse(_updateProfileUrl),
        );

        request.fields.addAll(fields);
        request.files.add(
          await http.MultipartFile.fromPath(
            'photo',
            File(_pickedPhoto!.path).path,
          ),
        );

        final streamed = await request.send();
        response = http.Response(
          await streamed.stream.bytesToString(),
          streamed.statusCode,
        );
      } else {
        response = await http.post(
          Uri.parse(_updateProfileUrl),
          headers: const <String, String>{
            'Content-Type':
                'application/json; charset=utf-8',
          },
          body: jsonEncode(
            <String, dynamic>{
              'trainer_id': trainerId,
              'actor_user_id':
                  actorUserId,
              'actor_role': actorRole,
              'position': _positionC.text.trim(),
              'specialization':
                  _specializationC.text.trim(),
              'city': _cityC.text.trim(),
              'work_locations':
                  _locationsC.text.trim(),
              'birthday': _birthdayC.text.trim(),
              'experience':
                  _experienceC.text.trim(),
              'phone': _phoneC.text.trim(),
              'bio': _bioC.text.trim(),
            },
          ),
        );
      }

      final data = _decode(response.body);

      if (!_success(data)) {
        final message = data is Map
            ? _s(
                data['message'] ??
                    data['error'],
              )
            : '';
        _snack(
          message.isEmpty
              ? 'Не удалось сохранить профиль'
              : message,
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _editorOpen = false;
        _pickedPhoto = null;
      });

      await _load();
      widget.onChanged?.call();

      _snack('Профиль тренера обновлён');
    } catch (e) {
      _snack('Ошибка сохранения: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: _TpText.body(
            11,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _openProfileEditor() {
    if (!widget.allowEdit || !mounted) return;

    setState(() {
      _aiOpen = false;
      _assignTeamOpen = false;
      _editorOpen = true;
    });
  }

  void _toggleTrainerAi() {
    if (!mounted) return;

    final trainerId = _trainerId(_profile);

    if (trainerId <= 0) {
      _snack('Не найден ID тренера для ИИ');
      return;
    }

    setState(() {
      _editorOpen = false;
      _assignTeamOpen = false;
      _aiOpen = !_aiOpen;
    });
  }

  void _selectSection(
    TrainerProfileSection section,
  ) {
    if (!mounted) return;

    setState(() {
      _section = section;
      _editorOpen = false;
      _assignTeamOpen = false;
      _aiOpen = false;
    });

    if (section == TrainerProfileSection.testing &&
        _testingTeamId > 0) {
      _ensureTesting(_testingTeamId);
    }
  }

  List<Map<String, dynamic>> get _assignableTeams {
    final source = widget.availableTeams.isNotEmpty
        ? widget.availableTeams
        : _teams;

    final seen = <int>{};
    final rows = <Map<String, dynamic>>[];

    for (final raw in source) {
      final team =
          Map<String, dynamic>.from(raw);
      final id = _teamId(team);
      if (id <= 0 || !seen.add(id)) continue;
      rows.add(team);
    }

    return rows;
  }

  bool _trainerAlreadyInTeam(int teamId) {
    return _teams.any(
      (team) => _teamId(team) == teamId,
    );
  }

  void _openAssignTeamPanel() {
    if (!mounted) return;

    final teams = _assignableTeams;
    final firstNotAssigned = teams.where(
      (team) =>
          !_trainerAlreadyInTeam(
            _teamId(team),
          ),
    );

    setState(() {
      _editorOpen = false;
      _aiOpen = false;
      _assignTeamOpen = true;
      _assignTeamId =
          firstNotAssigned.isNotEmpty
              ? _teamId(firstNotAssigned.first)
              : teams.isNotEmpty
                  ? _teamId(teams.first)
                  : 0;
      _assignProfile = 'extra';
    });
  }

  Future<void> _saveTeamAssignment() async {
    if (_assignTeamSaving ||
        _assignTeamId <= 0 ||
        widget.onAssignTeam == null) {
      return;
    }

    if (_trainerAlreadyInTeam(
      _assignTeamId,
    )) {
      _snack(
        'Тренер уже назначен в эту команду',
      );
      return;
    }

    setState(
      () => _assignTeamSaving = true,
    );

    try {
      final ok =
          await widget.onAssignTeam!(
        _assignTeamId,
        _assignProfile,
      );

      if (!ok) return;

      if (!mounted) return;

      setState(() {
        _assignTeamOpen = false;
      });

      await _load();
      widget.onChanged?.call();
      _snack('Команда добавлена тренеру');
    } catch (e) {
      _snack(
        'Не удалось назначить команду: $e',
      );
    } finally {
      if (mounted) {
        setState(
          () => _assignTeamSaving = false,
        );
      }
    }
  }

  Map<String, dynamic>? _teamById(int id) {
    for (final team in _teams) {
      if (_teamId(team) == id) return team;
    }
    return null;
  }

  String _testingStage(
    Map<String, dynamic>? team,
  ) {
    if (team == null) return 'U13';

    final direct = _s(
      team['stage'] ??
          team['stage_code'] ??
          team['category_code'] ??
          team['age_group'] ??
          team['ageGroup'] ??
          team['team_stage'] ??
          team['category'] ??
          team['team_category'],
    ).toUpperCase();

    final directMatch =
        RegExp(r'U\d{1,2}')
            .firstMatch(direct);

    if (directMatch != null) {
      return directMatch.group(0)!;
    }

    final numeric =
        int.tryParse(
          direct.replaceAll(
            RegExp(r'[^0-9]'),
            '',
          ),
        ) ??
        0;

    if (numeric > 0 && numeric <= 25) {
      return 'U$numeric';
    }

    final name =
        _teamName(team).toUpperCase();

    final nameMatch =
        RegExp(r'U\d{1,2}')
            .firstMatch(name);

    if (nameMatch != null) {
      return nameMatch.group(0)!;
    }

    return 'U13';
  }

  Future<void> _ensureTesting(
    int teamId, {
    bool force = false,
  }) async {
    if (teamId <= 0 ||
        _testingLoadingTeams.contains(teamId)) {
      return;
    }

    if (!force &&
        _testingByTeam.containsKey(teamId)) {
      return;
    }

    _testingLoadingTeams.add(teamId);

    if (force) {
      _testingByTeam.remove(teamId);
    }

    if (mounted) setState(() {});

    final team = _teamById(teamId);
    final stage = _testingStage(team);

    const categories = <String>[
      'physical',
      'technical',
      'tactical',
      'psychological',
      'theory',
      'functional',
    ];

    final rows = <Map<String, dynamic>>[];

    Future<List<Map<String, dynamic>>> fetchCategory(
      String category, {
      required bool includeStage,
    }) async {
      final params = <String, String>{
        'club_id': '${widget.clubId}',
        'team_id': '$teamId',
        'category': category,
        if (includeStage && stage.isNotEmpty)
          'stage': stage,
      };

      final uri = Uri.parse(
        _testingSessionsUrl,
      ).replace(queryParameters: params);

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 14));

      return _extractList(
        _decode(response.body),
        const <String>[
          'sessions',
          'items',
          'rows',
          'data',
          'result',
        ],
      );
    }

    try {
      for (final category in categories) {
        try {
          var list = await fetchCategory(
            category,
            includeStage: true,
          );

          // Старые сессии могли быть записаны без stage.
          // Если строгий запрос пуст — повторяем только club/team/category.
          if (list.isEmpty) {
            list = await fetchCategory(
              category,
              includeStage: false,
            );
          }

          for (final session in list) {
            rows.add(
              <String, dynamic>{
                ...session,
                '_category': category,
                '_stage': _s(
                  session['stage'],
                ).isNotEmpty
                    ? _s(session['stage'])
                    : stage,
                '_team_id': teamId,
                '_team_name':
                    team == null
                        ? 'Команда'
                        : _teamName(team),
              },
            );
          }
        } catch (_) {}
      }

      final unique =
          <String, Map<String, dynamic>>{};

      for (final row in rows) {
        final id = _i(
          row['id'] ??
              row['session_id'],
        );

        final category =
            _s(row['_category']);

        final date = _s(
          row['test_date'] ??
              row['date'] ??
              row['created_at'],
        );

        final key = id > 0
            ? '$category|id:$id'
            : '$category|$date|'
                '${_s(row['title'] ?? row['name'])}';

        unique[key] = row;
      }

      final finalRows =
          unique.values.toList()
            ..sort((a, b) {
              final da = _date(
                    a['test_date'] ??
                        a['date'] ??
                        a['created_at'],
                  ) ??
                  DateTime(1970);

              final db = _date(
                    b['test_date'] ??
                        b['date'] ??
                        b['created_at'],
                  ) ??
                  DateTime(1970);

              return db.compareTo(da);
            });

      _testingByTeam[teamId] =
          finalRows;

      // В общем режиме календарь открываем на месяце
      // последней реально найденной сессии.
      if (!_testingDateFilterActive &&
          finalRows.isNotEmpty) {
        final latest = _date(
          finalRows.first['test_date'] ??
              finalRows.first['date'] ??
              finalRows.first['created_at'],
        );

        if (latest != null) {
          _testingCursor = DateTime(
            latest.year,
            latest.month,
            1,
          );
        }
      }
    } finally {
      _testingLoadingTeams.remove(teamId);
      if (mounted) setState(() {});
    }
  }

  String _sectionTitle(
    TrainerProfileSection section,
  ) {
    switch (section) {
      case TrainerProfileSection.card:
        return 'Карточка тренера';
      case TrainerProfileSection.work:
        return 'Команды и локации';
      case TrainerProfileSection.schedule:
        return 'Расписание';
      case TrainerProfileSection.attendance:
        return 'Посещаемость';
      case TrainerProfileSection.plans:
        return 'Планы-конспекты';
      case TrainerProfileSection.testing:
        return 'Тестирование';
      case TrainerProfileSection.health:
        return 'Здоровье';
      case TrainerProfileSection.documents:
        return 'Документы';
    }
  }

  Color _sectionColor(
    TrainerProfileSection section,
  ) {
    switch (section) {
      case TrainerProfileSection.card:
        return _TpColors.green;
      case TrainerProfileSection.work:
        return _TpColors.greenDark;
      case TrainerProfileSection.schedule:
        return _TpColors.amber;
      case TrainerProfileSection.attendance:
        return _TpColors.greenDark;
      case TrainerProfileSection.plans:
        return _TpColors.green;
      case TrainerProfileSection.testing:
        return _TpColors.red;
      case TrainerProfileSection.health:
        return _TpColors.red;
      case TrainerProfileSection.documents:
        return _TpColors.greenDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator(
            color: _TpColors.green,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_error != null) {
      return ColoredBox(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _TpEmpty(
              title: 'Не удалось загрузить тренера',
              text: _error!,
              action: 'Повторить',
              onTap: _load,
            ),
          ),
        ),
      );
    }

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= 760;

        final Widget? rightPanel =
            _assignTeamOpen
                ? _TrainerAssignTeamPanel(
                    trainerName: _name,
                    teams: _assignableTeams,
                    selectedTeamId:
                        _assignTeamId,
                    selectedProfile:
                        _assignProfile,
                    saving:
                        _assignTeamSaving,
                    isAlreadyAssigned:
                        _trainerAlreadyInTeam,
                    teamIdOf: _teamId,
                    teamNameOf: _teamName,
                    teamLogoOf: _teamLogo,
                    onTeamChanged: (id) {
                      if (!mounted) return;
                      setState(
                        () => _assignTeamId = id,
                      );
                    },
                    onProfileChanged: (value) {
                      if (!mounted) return;
                      setState(
                        () => _assignProfile =
                            value,
                      );
                    },
                    onClose: () {
                      if (!mounted) return;
                      setState(
                        () => _assignTeamOpen =
                            false,
                      );
                    },
                    onSave: _saveTeamAssignment,
                  )
                : _editorOpen
                    ? _TrainerEditorPanel(
                        name: _name,
                        email: _email,
                        photo: _photo,
                        pickedPhoto:
                            _pickedPhoto,
                        positionC:
                            _positionC,
                        specializationC:
                            _specializationC,
                        cityC: _cityC,
                        locationsC:
                            _locationsC,
                        birthdayC:
                            _birthdayC,
                        experienceC:
                            _experienceC,
                        phoneC: _phoneC,
                        bioC: _bioC,
                        saving: _saving,
                        onPickPhoto:
                            _pickPhoto,
                        onClose: () {
                          if (mounted) {
                            setState(
                              () => _editorOpen =
                                  false,
                            );
                          }
                        },
                        onSave: _saveProfile,
                      )
                    : _aiOpen
                        ? CmrClubAiAssistantPanel(
                            clubId: widget.clubId,
                            userId:
                                _trainerId(_profile),
                            teamId: _teams.isEmpty
                                ? null
                                : _teamId(
                                    _teams.first,
                                  ),
                            clubName:
                                widget.clubName,
                            teamName: _teams.isEmpty
                                ? null
                                : _teamName(
                                    _teams.first,
                                  ),
                            initialPayload:
                                <String, dynamic>{
                              'scope':
                                  'trainer_profile',
                              'trainer_id':
                                  _trainerId(
                                _profile,
                              ),
                              'trainer_name':
                                  _name,
                              'club_id':
                                  widget.clubId,
                              if (_teams.isNotEmpty)
                                'team_id': _teamId(
                                  _teams.first,
                                ),
                            },
                            onBack: () {
                              if (!mounted) {
                                return;
                              }
                              setState(
                                () =>
                                    _aiOpen =
                                        false,
                              );
                            },
                          )
                        : null;

        if (!desktop) {
          if (rightPanel != null) {
            return rightPanel;
          }

          return ColoredBox(
            color: Colors.white,
            child: Column(
              children: <Widget>[
                _profileHeader(
                  compactShell: true,
                ),
                _mobileSectionBar(),
                Expanded(
                  child: _mainContent(
                    showHeader: false,
                  ),
                ),
              ],
            ),
          );
        }

        final navWidth =
            constraints.maxWidth >= 1100
                ? 242.0
                : 218.0;

        final core = Row(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: navWidth,
              child: _leftNavigation(),
            ),
            Container(
              width: 1,
              color: _TpColors.line,
            ),
            Expanded(
              child: Column(
                children: <Widget>[
                  _profileHeader(
                    compactShell: true,
                  ),
                  Expanded(
                    child: _mainContent(
                      showHeader: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        if (rightPanel == null) {
          return core;
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: core,
            ),
            Container(
              width: 1,
              color: _TpColors.line,
            ),
            SizedBox(
              width: 430,
              child: rightPanel,
            ),
          ],
        );
      },
    );

    if (widget.embeddedInWorkspace) {
      return ColoredBox(
        color: Colors.white,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: _TpColors.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ColoredBox(
              color: Colors.white,
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileHeader({
    bool compactShell = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            compactShell ||
            constraints.maxWidth < 700;

        final veryCompact =
            constraints.maxWidth < 520;

        final avatarSize =
            compact ? 40.0 : 46.0;

        final teamName =
            _teams.isEmpty
                ? ''
                : _teamName(
                    _teams.first,
                  );

        final subtitle = <String>[
          _role,
          if (_specialization.isNotEmpty)
            _specialization,
          if (teamName.isNotEmpty)
            teamName
          else if (widget.clubName.isNotEmpty)
            widget.clubName,
        ].where((item) => item.trim().isNotEmpty).join(
              ' · ',
            );

        return Container(
          height: compact ? 62 : 68,
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 14,
            8,
            compact ? 12 : 14,
            8,
          ),
          decoration:
              const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: _TpColors.line,
                width: .65,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              InkWell(
                onTap: widget.allowEdit
                    ? _openProfileEditor
                    : null,
                borderRadius:
                    BorderRadius.circular(10),
                child: _TpAvatar(
                  photo: _photo,
                  name: _name,
                  size: avatarSize,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            _name,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                _TpText.title(
                              compact
                                  ? 14
                                  : 15,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        const _TpDotCluster(
                          color:
                              _TpColors.green,
                          compact: true,
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...<
                        Widget>[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            _TpText.body(
                          compact
                              ? 9.5
                              : 10.2,
                          color:
                              _TpColors.muted,
                          weight:
                              FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!veryCompact)
                _TpHeaderAction(
                  label: compact
                      ? 'ИИ'
                      : 'ИИ тренера',
                  dotColor:
                      _TpColors.greenDark,
                  onTap:
                      _toggleTrainerAi,
                  emphasized: true,
                  active: _aiOpen,
                ),
              if (!veryCompact &&
                  widget.onMessage != null) ...<
                  Widget>[
                const SizedBox(width: 6),
                _TpHeaderAction(
                  label: compact
                      ? 'Чат'
                      : 'Сообщение',
                  dotColor:
                      _TpColors.green,
                  onTap:
                      widget.onMessage!,
                ),
              ],
              if (veryCompact) ...<Widget>[
                _TpHeaderAction(
                  label: 'ИИ',
                  dotColor:
                      _TpColors.greenDark,
                  onTap:
                      _toggleTrainerAi,
                  emphasized: true,
                  active: _aiOpen,
                ),
                if (widget.onMessage != null) ...<
                    Widget>[
                  const SizedBox(width: 5),
                  _TpHeaderAction(
                    label: 'Чат',
                    dotColor:
                        _TpColors.green,
                    onTap:
                        widget.onMessage!,
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }


  Widget _leftNavigation() {
    final contextLine = <String>[
      if (_role.isNotEmpty) _role,
      if (widget.clubName.trim().isNotEmpty)
        widget.clubName.trim(),
    ].join(' · ');

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.fromLTRB(
                8,
                10,
                8,
                10,
              ),
              children:
                  TrainerProfileSection.values
                      .map(_navItem)
                      .toList(),
            ),
          ),
          if (widget.allowEdit) ...<Widget>[
            Container(
              height: 1,
              color: _TpColors.line,
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                8,
                10,
                6,
              ),
              child: Material(
                color:
                    _TpColors.greenSoft,
                borderRadius:
                    BorderRadius.circular(9),
                child: InkWell(
                  onTap:
                      _openProfileEditor,
                  borderRadius:
                      BorderRadius.circular(9),
                  child: Container(
                    constraints:
                        const BoxConstraints(
                      minHeight: 42,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      children: <Widget>[
                        const _TpDot(
                          color:
                              _TpColors.green,
                          size: 5.8,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: Text(
                            'Редактировать',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                _TpText.body(
                              9.7,
                              color:
                                  _TpColors.greenDark,
                              weight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          Container(
            height: 1,
            color: _TpColors.line,
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              10,
              8,
              10,
              10,
            ),
            child: Material(
              color: _TpColors.soft,
              borderRadius:
                  BorderRadius.circular(9),
              child: InkWell(
                onTap: widget.onClose,
                borderRadius:
                    BorderRadius.circular(9),
                child: Container(
                  constraints:
                      const BoxConstraints(
                    minHeight: 48,
                  ),
                  padding:
                      const EdgeInsets.fromLTRB(
                    10,
                    7,
                    8,
                    7,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding:
                            EdgeInsets.only(
                          top: 5,
                        ),
                        child: _TpDot(
                          color:
                              _TpColors.green,
                          size: 6.2,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'К списку тренеров',
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  _TpText.body(
                                9.8,
                                weight:
                                    FontWeight.w600,
                              ),
                            ),
                            if (contextLine
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                contextLine,
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    _TpText.body(
                                  8.4,
                                  color:
                                      _TpColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _navItem(
    TrainerProfileSection section,
  ) {
    final active = _section == section;
    final color = _sectionColor(section);

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: active
            ? _TpColors.greenSoft
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: () => _selectSection(section),
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            height: 38,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
              ),
              child: Row(
                children: <Widget>[
                  _TpDot(
                    color: color,
                    size: active ? 6 : 4.5,
                    opacity: active ? 1 : .68,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _sectionTitle(section),
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: _TpText.body(
                        10.2,
                        color: active
                            ? _TpColors.greenDark
                            : _TpColors.text,
                        weight: active
                            ? FontWeight.w600
                            : FontWeight.w500,
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

  Widget _mobileSectionBar() {
    return Container(
      height: 52,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _TpColors.line,
            width: .65,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (!widget.embeddedInWorkspace &&
              widget.onClose != null) ...<Widget>[
            Material(
              color: _TpColors.soft,
              borderRadius:
                  BorderRadius.circular(8),
              child: InkWell(
                onTap: widget.onClose,
                borderRadius:
                    BorderRadius.circular(8),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 13,
                    color: _TpColors.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:
                  TrainerProfileSection.values.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 4),
              itemBuilder: (_, index) {
                final item =
                    TrainerProfileSection
                        .values[index];
                final active =
                    _section == item;
                final color =
                    _sectionColor(item);

                return Material(
                  color: active
                      ? _TpColors.greenSoft
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () =>
                        _selectSection(item),
                    borderRadius:
                        BorderRadius.circular(8),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 9,
                      ),
                      child: Row(
                        children: <Widget>[
                          _TpDot(
                            color: color,
                            size:
                                active ? 5.5 : 4,
                            opacity:
                                active ? 1 : .65,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _sectionTitle(item),
                            style: _TpText.body(
                              9.6,
                              color: active
                                  ? _TpColors
                                      .greenDark
                                  : _TpColors.text,
                              weight: active
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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

  Widget _mainContent({
    bool showHeader = true,
  }) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          if (showHeader)
            _contentHeader(),
          Expanded(
            child: _sectionContent(),
          ),
        ],
      ),
    );
  }

  Widget _contentHeader() {
    return Container(
      height: 58,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _TpColors.line,
            width: .65,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          _TpDotCluster(
            color: _sectionColor(_section),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _sectionTitle(_section),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _TpText.title(14.2),
            ),
          ),
          if (_refreshing) ...<Widget>[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: _TpColors.green,
              ),
            ),
            const SizedBox(width: 9),
          ],
        ],
      ),
    );
  }

  Widget _sectionContent() {
    switch (_section) {
      case TrainerProfileSection.card:
        return _cardSection();
      case TrainerProfileSection.work:
        return _workSection();
      case TrainerProfileSection.schedule:
        return _scheduleSection();
      case TrainerProfileSection.attendance:
        return TrainerHrSectionPanel(
          kind: TrainerHrSectionKind.attendance,
          trainerId: _trainerId(_profile),
          clubId: widget.clubId,
          clubName: widget.clubName,
          trainerName: _name,
          teams: _teams,
          schedule: _schedule,
          allowEdit: widget.allowEdit,
          onChanged: widget.onChanged,
        );
      case TrainerProfileSection.plans:
        return _plansSection();
      case TrainerProfileSection.testing:
        return _testingSection();
      case TrainerProfileSection.health:
        return TrainerHrSectionPanel(
          kind: TrainerHrSectionKind.health,
          trainerId: _trainerId(_profile),
          clubId: widget.clubId,
          clubName: widget.clubName,
          trainerName: _name,
          teams: _teams,
          schedule: _schedule,
          allowEdit: widget.allowEdit,
          onChanged: widget.onChanged,
        );
      case TrainerProfileSection.documents:
        return TrainerHrSectionPanel(
          kind: TrainerHrSectionKind.documents,
          trainerId: _trainerId(_profile),
          clubId: widget.clubId,
          clubName: widget.clubName,
          trainerName: _name,
          teams: _teams,
          schedule: _schedule,
          allowEdit: widget.allowEdit,
          onChanged: widget.onChanged,
        );
    }
  }

  Widget _cardSection() {
    final locations = _locationNames;
    final upcoming = _upcomingSchedule;

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        12,
        14,
        24,
      ),
      children: <Widget>[
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: _photo.isEmpty
                  ? null
                  : () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            _TpPhotoDialog(
                          photo: _photo,
                          name: _name,
                        ),
                      ),
              child: _TpAvatar(
                photo: _photo,
                name: _name,
                size: 70,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _role.toUpperCase(),
                    style: _TpText.body(
                      8.2,
                      color:
                          _TpColors.greenDark,
                      weight: FontWeight.w600,
                    ).copyWith(
                      letterSpacing: .24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _name,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: _TpText.title(16.5),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.clubName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: _TpText.body(
                      10.4,
                      color: _TpColors.muted,
                    ),
                  ),
                  if (_specialization.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _specialization,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: _TpText.body(
                        9.6,
                        color:
                            _TpColors.muted2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _metricsStrip(
          <({String value, String label})>[
            (
              value: '${_teams.length}',
              label: 'Команды',
            ),
            (
              value: '${locations.length}',
              label: 'Локации',
            ),
            (
              value: '${upcoming.length}',
              label: 'В расписании',
            ),
            (
              value:
                  _experience.isEmpty
                      ? '—'
                      : _experience,
              label: 'Опыт',
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _TpSectionTitle(
          title: 'Рабочая информация',
          color: _TpColors.greenDark,
        ),
        const SizedBox(height: 5),
        _TpInfoRow(
          label: 'Должность',
          value: _role,
        ),
        _TpInfoRow(
          label: 'Специализация',
          value: _specialization.isEmpty
              ? 'Не указана'
              : _specialization,
        ),
        _TpInfoRow(
          label: 'Город',
          value:
              _city.isEmpty
                  ? 'Не указан'
                  : _city,
        ),
        _TpInfoRow(
          label: 'Дата рождения',
          value: _birthday.isEmpty
              ? 'Не указана'
              : _birthday,
        ),
        _TpInfoRow(
          label: 'Email',
          value: _email.isEmpty
              ? 'Не указан'
              : _email,
        ),
        _TpInfoRow(
          label: 'Телефон',
          value: _phone.isEmpty
              ? 'Не указан'
              : _phone,
        ),
        const SizedBox(height: 16),
        const _TpSectionTitle(
          title: 'О тренере',
          color: _TpColors.green,
        ),
        const SizedBox(height: 7),
        Text(
          _bio.isEmpty
              ? 'Описание пока не заполнено.'
              : _bio,
          style: _TpText.body(
            10.8,
            color: _TpColors.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _metricsStrip(
    List<({String value, String label})> items,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
        horizontal: 5,
      ),
      decoration: BoxDecoration(
        color: _TpColors.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0;
              i < items.length;
              i++) ...<Widget>[
            Expanded(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: <Widget>[
                  Text(
                    items[i].value,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: _TpText.title(11.8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].label,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: _TpText.body(
                      8.5,
                      color: _TpColors.muted2,
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              Container(
                width: 1,
                height: 26,
                color: _TpColors.line,
              ),
          ],
        ],
      ),
    );
  }

  Widget _workSection() {
    final locations = _locationNames;

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        12,
        14,
        24,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            const _TpDotCluster(
              color: _TpColors.greenDark,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Команды, с которыми работает тренер',
                style: _TpText.title(12.2),
              ),
            ),
            if (widget.onAssignTeam != null ||
                widget.onAssign != null)
              _TpAction(
                title: 'Добавить команду',
                color: _TpColors.greenDark,
                onTap:
                    widget.onAssignTeam != null
                        ? _openAssignTeamPanel
                        : widget.onAssign!,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_teams.isEmpty)
          const _TpEmpty(
            title: 'Команды не назначены',
            text:
                'Назначение появится здесь после привязки тренера к команде.',
          )
        else
          ..._teams.map(
            (team) => _TpTeamRow(
              photo: _teamLogo(team),
              name: _teamName(team),
              role: _teamRole(team),
            ),
          ),
        const SizedBox(height: 18),
        const _TpSectionTitle(
          title: 'Рабочие локации',
          color: _TpColors.amber,
        ),
        const SizedBox(height: 7),
        if (locations.isEmpty)
          Text(
            'Локации пока не указаны. Они автоматически собираются из расписания команд и могут быть сохранены в профиле тренера.',
            style: _TpText.body(
              10.4,
              color: _TpColors.muted,
              height: 1.38,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: locations
                .map(
                  (location) => _TpPill(
                    text: location,
                    color:
                        _TpColors.amber,
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 18),
        const _TpSectionTitle(
          title: 'Связь с расписанием',
          color: _TpColors.green,
        ),
        const SizedBox(height: 7),
        Text(
          'Расписание занятий собирается из календарей назначенных команд. Клуб и тренер поэтому видят одинаковые даты, места и команды.',
          style: _TpText.body(
            10.4,
            color: _TpColors.muted,
            height: 1.38,
          ),
        ),
      ],
    );
  }

  Widget _scheduleSection() {
    final rows = _schedule;

    List<Map<String, dynamic>> eventsForDay(DateTime day) {
      return rows.where((event) {
        final date = _date(
          event['start_at'] ??
              event['date'] ??
              event['event_date'],
        );

        return date != null &&
            date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).toList()
        ..sort((a, b) {
          final da = _date(
                a['start_at'] ??
                    a['date'] ??
                    a['event_date'],
              ) ??
              DateTime(2100);
          final db = _date(
                b['start_at'] ??
                    b['date'] ??
                    b['event_date'],
              ) ??
              DateTime(2100);
          return da.compareTo(db);
        });
    }

    final selectedRows = eventsForDay(_scheduleSelected);

    final marks = <String, int>{};
    for (final event in rows) {
      final date = _date(
        event['start_at'] ??
            event['date'] ??
            event['event_date'],
      );
      if (date == null) continue;

      final key =
          '${date.year}-${date.month}-${date.day}';
      marks[key] = (marks[key] ?? 0) + 1;
    }

    void selectDate(DateTime date) {
      final normalized =
          DateTime(date.year, date.month, date.day);

      if (!mounted) return;
      setState(() {
        _scheduleSelected = normalized;

        if (_scheduleCursor.year != normalized.year ||
            _scheduleCursor.month != normalized.month) {
          _scheduleCursor =
              DateTime(normalized.year, normalized.month, 1);
        }
      });
    }

    void shiftMonth(int delta) {
      if (!mounted) return;
      setState(() {
        _scheduleCursor = DateTime(
          _scheduleCursor.year,
          _scheduleCursor.month + delta,
          1,
        );
      });
    }

    void today() {
      final now = DateTime.now();
      selectDate(
        DateTime(now.year, now.month, now.day),
      );
    }

    Widget calendarWindow({
      required bool phone,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(phone ? 18 : 20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: phone ? 56 : 58,
              padding: EdgeInsets.fromLTRB(
                phone ? 11 : 13,
                8,
                phone ? 9 : 11,
                8,
              ),
              color: Colors.white,
              child: Row(
                children: <Widget>[
                  Container(
                    width: phone ? 36 : 38,
                    height: phone ? 36 : 38,
                    decoration: BoxDecoration(
                      color: _TpColors.soft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: _TpDotCluster(
                        color: _TpColors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          _TpTrainerCalendar.monthTitle(
                            _scheduleCursor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _TpText.title(
                            14.4,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_TpTrainerCalendar.dateLabel(_scheduleSelected)} · '
                          '${selectedRows.length} ${_TpTrainerCalendar.eventWord(selectedRows.length)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _TpText.body(
                            9.8,
                            color: _TpColors.muted,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TpCalendarIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => shiftMonth(-1),
                  ),
                  const SizedBox(width: 5),
                  _TpCalendarIconButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => shiftMonth(1),
                  ),
                  const SizedBox(width: 5),
                  _TpCalendarIconButton(
                    icon: Icons.today_rounded,
                    onTap: today,
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: _TpColors.line,
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  phone ? 11 : 13,
                  phone ? 11 : 13,
                  phone ? 11 : 13,
                  phone ? 13 : 15,
                ),
                child: _TpTrainerMonthCalendar(
                  cursor: _scheduleCursor,
                  selected: _scheduleSelected,
                  marks: marks,
                  onSelect: selectDate,
                  roomy: true,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget selectedWindow({
      required bool phone,
    }) {
      return _TpTrainerSelectedDayPanel(
        selected: _scheduleSelected,
        events: selectedRows,
        compact: phone,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 720;

        if (mobile) {
          final first = DateTime(
            _scheduleCursor.year,
            _scheduleCursor.month,
            1,
          );
          final daysInMonth = DateTime(
            _scheduleCursor.year,
            _scheduleCursor.month + 1,
            0,
          ).day;
          final rowsCount =
              ((first.weekday - 1 + daysInMonth + 6) ~/ 7);

          final calendarHeight =
              rowsCount >= 6 ? 430.0 : 398.0;

          final infoHeight = selectedRows.isEmpty
              ? 230.0
              : math.max(
                  270.0,
                  math.min(
                    420.0,
                    150.0 + selectedRows.length * 92.0,
                  ),
                ).toDouble();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              8,
              8,
              8,
              24,
            ),
            children: <Widget>[
              SizedBox(
                height: calendarHeight,
                child: calendarWindow(phone: true),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: infoHeight,
                child: selectedWindow(phone: true),
              ),
            ],
          );
        }

        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight - 16
            : 520.0;

        final calendarWidth = math.min(
          480.0,
          math.max(
            360.0,
            constraints.maxWidth * .42,
          ),
        ).toDouble();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            8,
            8,
            8,
            8,
          ),
          child: SizedBox(
            height: height,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: calendarWidth,
                    child: calendarWindow(phone: false),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: selectedWindow(phone: false),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _teamSelector({
    required int value,
    required ValueChanged<int> onChanged,
    Color color = _TpColors.green,
  }) {
    if (_teams.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        itemCount: _teams.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 5),
        itemBuilder: (_, index) {
          final team = _teams[index];
          final id = _teamId(team);
          final active = id == value;

          return Material(
            color: active
                ? color.withOpacity(.08)
                : _TpColors.soft,
            borderRadius:
                BorderRadius.circular(8),
            child: InkWell(
              onTap: () => onChanged(id),
              borderRadius:
                  BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                ),
                child: Row(
                  children: <Widget>[
                    _TpDot(
                      color: active
                          ? color
                          : _TpColors.muted2,
                      size: active ? 5.5 : 4,
                      opacity: active ? 1 : .6,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _teamName(team),
                      style: _TpText.body(
                        9.5,
                        weight: active
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: active
                            ? _TpColors.greenDark
                            : _TpColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _plansSection() {
    if (_plansLoading &&
        _trainerPlans.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: _TpColors.green,
          strokeWidth: 2,
        ),
      );
    }

    final visiblePlans = _plansTeamId <= 0
        ? _trainerPlans
        : _trainerPlans
            .where(
              (plan) =>
                  _planTeamId(plan) ==
                  _plansTeamId,
            )
            .toList();

    List<Map<String, dynamic>> plansForDay(
      DateTime day,
    ) {
      return visiblePlans.where((plan) {
        final date = _planAddedDate(plan);

        return date != null &&
            date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).toList()
        ..sort((a, b) {
          final da =
              _planAddedDate(a) ??
                  DateTime(1970);
          final db =
              _planAddedDate(b) ??
                  DateTime(1970);
          return db.compareTo(da);
        });
    }

    final selectedPlans =
        _plansDateFilterActive
            ? plansForDay(_plansSelected)
            : List<Map<String, dynamic>>.from(
                visiblePlans,
              );

    final marks = <String, int>{};
    for (final plan in visiblePlans) {
      final date = _planAddedDate(plan);
      if (date == null) continue;

      final key =
          _TpTrainerCalendar.key(date);
      marks[key] =
          (marks[key] ?? 0) + 1;
    }

    final selectedPreview =
        _selectedPlanPreview;

    final previewStillVisible =
        selectedPreview != null &&
        selectedPlans.any(
          (plan) {
            final a = _i(
              plan['id'] ??
                  plan['plan_id'],
            );
            final b = _i(
              selectedPreview['id'] ??
                  selectedPreview['plan_id'],
            );

            if (a > 0 && b > 0) {
              return a == b;
            }

            return identical(
              plan,
              selectedPreview,
            );
          },
        );

    if (!previewStillVisible &&
        _selectedPlanPreview != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        if (!mounted) return;
        setState(
          () => _selectedPlanPreview = null,
        );
      });
    }

    void selectDate(DateTime date) {
      final normalized = DateTime(
        date.year,
        date.month,
        date.day,
      );

      if (!mounted) return;

      setState(() {
        _plansSelected = normalized;
        _plansDateFilterActive = true;
        _selectedPlanPreview = null;

        if (_plansCursor.year !=
                normalized.year ||
            _plansCursor.month !=
                normalized.month) {
          _plansCursor = DateTime(
            normalized.year,
            normalized.month,
            1,
          );
        }
      });
    }

    void shiftMonth(int delta) {
      if (!mounted) return;

      setState(() {
        _plansCursor = DateTime(
          _plansCursor.year,
          _plansCursor.month + delta,
          1,
        );
        _plansDateFilterActive = false;
        _selectedPlanPreview = null;
      });
    }

    void today() {
      final now = DateTime.now();
      selectDate(
        DateTime(
          now.year,
          now.month,
          now.day,
        ),
      );
    }

    Widget teamFilter() {
      if (_teams.length <= 1) {
        return const SizedBox.shrink();
      }

      return SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding:
              const EdgeInsets.fromLTRB(
            8,
            5,
            8,
            5,
          ),
          children: <Widget>[
            _TpPlanTeamChip(
              label: 'Все команды',
              active: _plansTeamId == 0,
              onTap: () {
                if (!mounted) return;
                setState(() {
                  _plansTeamId = 0;
                  _plansDateFilterActive = false;
                  _selectedPlanPreview = null;
                });
              },
            ),
            const SizedBox(width: 5),
            for (final team in _teams) ...<
                Widget>[
              _TpPlanTeamChip(
                label: _teamName(team),
                active:
                    _plansTeamId ==
                    _teamId(team),
                onTap: () {
                  if (!mounted) return;
                  setState(() {
                    _plansTeamId =
                        _teamId(team);
                    _plansDateFilterActive = false;
                    _selectedPlanPreview =
                        null;
                  });
                },
              ),
              const SizedBox(width: 5),
            ],
          ],
        ),
      );
    }

    Widget calendarWindow({
      required bool phone,
    }) {
      return Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: phone ? 56 : 58,
              padding: EdgeInsets.fromLTRB(
                phone ? 11 : 13,
                8,
                phone ? 9 : 11,
                8,
              ),
              color: Colors.white,
              child: Row(
                children: <Widget>[
                  Container(
                    width: phone ? 36 : 38,
                    height: phone ? 36 : 38,
                    decoration: BoxDecoration(
                      color: _TpColors.soft,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: _TpDotCluster(
                        color:
                            _TpColors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          _TpTrainerCalendar
                              .monthTitle(
                            _plansCursor,
                          ),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: _TpText.title(
                            14.4,
                            weight:
                                FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _plansDateFilterActive
                              ? '${_TpTrainerCalendar.dateLabel(_plansSelected)} · '
                                  '${selectedPlans.length} ${_TpPlanCalendar.planWord(selectedPlans.length)}'
                              : 'Все даты · '
                                  '${selectedPlans.length} ${_TpPlanCalendar.planWord(selectedPlans.length)}',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: _TpText.body(
                            9.8,
                            color:
                                _TpColors.muted,
                            weight:
                                FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TpCalendarIconButton(
                    icon: Icons
                        .chevron_left_rounded,
                    onTap: () =>
                        shiftMonth(-1),
                  ),
                  const SizedBox(width: 5),
                  _TpCalendarIconButton(
                    icon: Icons
                        .chevron_right_rounded,
                    onTap: () =>
                        shiftMonth(1),
                  ),
                  const SizedBox(width: 5),
                  _TpCalendarIconButton(
                    icon: Icons.today_rounded,
                    onTap: today,
                  ),
                  const SizedBox(width: 5),
                  _TpCalendarTextButton(
                    text: 'Все',
                    active:
                        !_plansDateFilterActive,
                    onTap: () {
                      if (!mounted) return;
                      setState(() {
                        _plansDateFilterActive =
                            false;
                        _selectedPlanPreview =
                            null;
                      });
                    },
                  ),
                ],
              ),
            ),
            if (_teams.length > 1)
              teamFilter(),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  11,
                  8,
                  11,
                  12,
                ),
                child:
                    _TpTrainerMonthCalendar(
                  cursor: _plansCursor,
                  selected:
                      _plansDateFilterActive
                          ? _plansSelected
                          : DateTime(1900, 1, 1),
                  marks: marks,
                  onSelect:
                      selectDate,
                  roomy: true,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget infoWindow({
      required bool phone,
    }) {
      return _TpTrainerPlansDayPanel(
        selected: _plansSelected,
        allDates:
            !_plansDateFilterActive,
        plans: selectedPlans,
        selectedPlan:
            previewStillVisible
                ? selectedPreview
                : null,
        compact: phone,
        titleOf: _planTitle,
        teamOf: _planTeamName,
        descriptionOf:
            _planDescription,
        addedDateOf:
            _planAddedDate,
        trainingDateOf:
            _planTrainingDate,
        onDetails: (plan) {
          if (!mounted) return;
          setState(
            () =>
                _selectedPlanPreview =
                    Map<String, dynamic>.from(
              plan,
            ),
          );
        },
        onOpenPlan:
            _openTrainingPlan,
      );
    }

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final mobile =
            constraints.maxWidth < 720;

        if (mobile) {
          final first = DateTime(
            _plansCursor.year,
            _plansCursor.month,
            1,
          );
          final daysInMonth = DateTime(
            _plansCursor.year,
            _plansCursor.month + 1,
            0,
          ).day;

          final rowsCount =
              ((first.weekday -
                          1 +
                          daysInMonth +
                          6) ~/
                      7);

          final calendarHeight =
              rowsCount >= 6
                  ? (_teams.length > 1
                      ? 456.0
                      : 420.0)
                  : (_teams.length > 1
                      ? 424.0
                      : 390.0);

          final infoHeight =
              selectedPlans.isEmpty
                  ? 230.0
                  : math
                      .max(
                        330.0,
                        math.min(
                          570.0,
                          210.0 +
                              selectedPlans
                                      .length *
                                  76.0 +
                              (previewStillVisible
                                  ? 170.0
                                  : 0.0),
                        ),
                      )
                      .toDouble();

          return ListView(
            padding:
                const EdgeInsets.fromLTRB(
              8,
              8,
              8,
              24,
            ),
            children: <Widget>[
              SizedBox(
                height:
                    calendarHeight,
                child: calendarWindow(
                  phone: true,
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: infoHeight,
                child: infoWindow(
                  phone: true,
                ),
              ),
            ],
          );
        }

        final height =
            constraints.maxHeight.isFinite
                ? constraints.maxHeight - 16
                : 520.0;

        final calendarWidth =
            math
                .min(
                  480.0,
                  math.max(
                    360.0,
                    constraints.maxWidth *
                        .42,
                  ),
                )
                .toDouble();

        return Padding(
          padding:
              const EdgeInsets.fromLTRB(
            8,
            8,
            8,
            8,
          ),
          child: SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: calendarWidth,
                  child: calendarWindow(
                    phone: false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: infoWindow(
                    phone: false,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  String _testingCategoryKey(
    Map<String, dynamic> session,
  ) {
    final raw = _s(
      session['_category'] ??
          session['category'] ??
          session['test_category'],
    ).toLowerCase();
    return raw.isEmpty ? 'physical' : raw;
  }

  int _testingSessionId(
    Map<String, dynamic> session,
  ) =>
      _i(
        session['session_id'] ??
            session['id'],
      );

  String _testingDateIso(
    Map<String, dynamic> session,
  ) {
    final date = _date(
      session['test_date'] ??
          session['date'] ??
          session['created_at'],
    );
    if (date == null) return '';

    String two(int value) =>
        value.toString().padLeft(2, '0');

    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  int _testingPlayerId(
    Map<String, dynamic> player,
  ) =>
      _i(
        player['player_id'] ??
            player['playerId'] ??
            player['user_id'] ??
            player['id'],
      );

  String _testingPlayerName(
    Map<String, dynamic> player,
  ) {
    final last = _s(
      player['last_name'] ??
          player['lastname'] ??
          player['surname'],
    );
    final first = _s(
      player['first_name'] ??
          player['firstname'],
    );

    final joined = '$last $first'.trim();
    if (joined.isNotEmpty) return joined;

    final direct = _s(
      player['player_name'] ??
          player['full_name'] ??
          player['fullName'] ??
          player['name'],
    );

    if (direct.isNotEmpty &&
        direct.toLowerCase() != 'игрок' &&
        direct.toLowerCase() != 'player') {
      return direct;
    }

    final id = _testingPlayerId(player);
    return id > 0 ? 'Игрок #$id' : 'Игрок';
  }

  dynamic _decodeTestingAny(String body) {
    final clear = body.trim();
    if (clear.isEmpty) return <String, dynamic>{};

    final objectStart = clear.indexOf('{');
    final arrayStart = clear.indexOf('[');

    final starts = <int>[
      if (objectStart >= 0) objectStart,
      if (arrayStart >= 0) arrayStart,
    ];

    if (starts.isEmpty) {
      return <String, dynamic>{};
    }

    starts.sort();
    try {
      return jsonDecode(
        clear.substring(starts.first),
      );
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<List<Map<String, dynamic>>>
      _loadTestingTeamPlayers(
    int teamId,
  ) async {
    if (teamId <= 0) {
      return <Map<String, dynamic>>[];
    }

    final uri = Uri.parse(
      _testingPlayersUrl,
    ).replace(
      queryParameters: <String, String>{
        'team_id': '$teamId',
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 15),
        );

    final decoded =
        _decodeTestingAny(response.body);

    if (decoded is! Map) {
      return <Map<String, dynamic>>[];
    }

    if (decoded['status'] != 'success' &&
        decoded['success'] != true) {
      return <Map<String, dynamic>>[];
    }

    final raw =
        (decoded['players'] as List?) ??
            (decoded['data'] as List?) ??
            (decoded['items'] as List?) ??
            const <dynamic>[];

    final players = raw
        .whereType<Map>()
        .map(
          (e) => Map<String, dynamic>.from(e),
        )
        .where(
          (player) =>
              _testingPlayerId(player) > 0,
        )
        .toList();

    players.sort(
      (a, b) => _testingPlayerName(a)
          .toLowerCase()
          .compareTo(
            _testingPlayerName(b)
                .toLowerCase(),
          ),
    );

    return players;
  }

  Set<int> _testingIdentityIds(
    Map<String, dynamic> player,
  ) {
    final ids = <int>{};

    for (final key in const <String>[
      'player_id',
      'playerId',
      'user_id',
      'userId',
      'account_id',
      'accountId',
      'id',
    ]) {
      final value = _i(player[key]);
      if (value > 0) {
        ids.add(value);
      }
    }

    return ids;
  }

  String _testingIdentityName(
    Map<String, dynamic> player,
  ) {
    final value =
        _testingPlayerName(player)
            .toLowerCase()
            .replaceAll('ё', 'е')
            .replaceAll(
              RegExp(r'[^a-zа-я0-9]+'),
              ' ',
            )
            .trim();

    if (value.isEmpty ||
        value == 'игрок' ||
        value.startsWith('игрок ')) {
      return '';
    }

    return value;
  }

  String _testingIdentityPhoto(
    Map<String, dynamic> player,
  ) {
    final raw = _normalizeImage(
      _s(
        player['photo'] ??
            player['photo_url'] ??
            player['avatar'] ??
            player['avatar_url'] ??
            player['image'],
      ),
    );

    if (raw.isEmpty) return '';

    final uri = Uri.tryParse(raw);
    final path = (uri?.path ?? raw)
        .toLowerCase()
        .trim();

    if (path.isEmpty) return '';

    return path;
  }

  bool _testingRawHasValue(
    dynamic raw,
  ) {
    if (raw == null) return false;

    if (raw is Map) {
      for (final key in const <String>[
        'value',
        'result',
        'score',
        'points',
        'measurement',
        'rating',
      ]) {
        if (!raw.containsKey(key)) {
          continue;
        }

        if (_testingRawHasValue(
          raw[key],
        )) {
          return true;
        }
      }

      return false;
    }

    if (raw is List) {
      return raw.any(
        _testingRawHasValue,
      );
    }

    final value = _s(raw);
    return value.isNotEmpty &&
        value.toLowerCase() != 'null';
  }

  bool _testingPlayerHasStoredResults(
    Map<String, dynamic> player,
  ) {
    final explicit = _i(
      player['filled_count'] ??
          player['completed_count'] ??
          player['results_count'] ??
          player['filled_results'],
    );

    if (explicit > 0) return true;

    final results =
        player['results'] ??
            player['tests'] ??
            player['matrix'] ??
            player['items'];

    if (results is Map) {
      return results.values.any(
        _testingRawHasValue,
      );
    }

    if (results is List) {
      return results.any(
        _testingRawHasValue,
      );
    }

    return false;
  }

  int _findTestingMatrixMatch(
    Map<String, dynamic> rosterPlayer,
    List<Map<String, dynamic>> matrixPlayers,
    Set<int> usedIndexes,
  ) {
    final rosterIds =
        _testingIdentityIds(
      rosterPlayer,
    );

    // 1. Сначала совпадение по любому реальному ID.
    if (rosterIds.isNotEmpty) {
      for (var i = 0;
          i < matrixPlayers.length;
          i++) {
        if (usedIndexes.contains(i)) {
          continue;
        }

        final matrixIds =
            _testingIdentityIds(
          matrixPlayers[i],
        );

        if (matrixIds.any(
          rosterIds.contains,
        )) {
          return i;
        }
      }
    }

    // 2. Потом точное ФИО.
    final rosterName =
        _testingIdentityName(
      rosterPlayer,
    );

    if (rosterName.isNotEmpty) {
      for (var i = 0;
          i < matrixPlayers.length;
          i++) {
        if (usedIndexes.contains(i)) {
          continue;
        }

        final matrixName =
            _testingIdentityName(
          matrixPlayers[i],
        );

        if (matrixName.isNotEmpty &&
            matrixName == rosterName) {
          return i;
        }
      }
    }

    // 3. Последний безопасный fallback — то же фото.
    final rosterPhoto =
        _testingIdentityPhoto(
      rosterPlayer,
    );

    if (rosterPhoto.isNotEmpty) {
      for (var i = 0;
          i < matrixPlayers.length;
          i++) {
        if (usedIndexes.contains(i)) {
          continue;
        }

        final matrixPhoto =
            _testingIdentityPhoto(
          matrixPlayers[i],
        );

        if (matrixPhoto.isNotEmpty &&
            matrixPhoto == rosterPhoto) {
          return i;
        }
      }
    }

    return -1;
  }

  List<Map<String, dynamic>>
      _mergeTestingPlayersWithRoster(
    List<Map<String, dynamic>> roster,
    List<Map<String, dynamic>> matrixPlayers,
  ) {
    // Если состав загрузился, именно он является главным списком.
    // Matrix только добавляет результаты.
    if (roster.isEmpty) {
      final onlyMatrix =
          <Map<String, dynamic>>[];

      for (final raw in matrixPlayers) {
        final item =
            Map<String, dynamic>.from(
          raw,
        );

        // Не показываем технические пустые "Игрок #123".
        final hasRealName =
            _testingIdentityName(item)
                .isNotEmpty;

        if (!hasRealName &&
            !_testingPlayerHasStoredResults(
              item,
            )) {
          continue;
        }

        final photo =
            _normalizeImage(
          _s(
            item['photo'] ??
                item['photo_url'] ??
                item['avatar'] ??
                item['avatar_url'] ??
                item['image'],
          ),
        );

        if (photo.isNotEmpty) {
          item['photo'] = photo;
          item['photo_url'] = photo;
        }

        onlyMatrix.add(item);
      }

      return onlyMatrix;
    }

    final merged =
        <Map<String, dynamic>>[];
    final usedMatrixIndexes =
        <int>{};

    for (final rawRoster in roster) {
      final item =
          Map<String, dynamic>.from(
        rawRoster,
      );

      final rosterId =
          _testingPlayerId(item);

      if (rosterId <= 0) {
        continue;
      }

      final matchIndex =
          _findTestingMatrixMatch(
        item,
        matrixPlayers,
        usedMatrixIndexes,
      );

      if (matchIndex >= 0) {
        usedMatrixIndexes.add(
          matchIndex,
        );

        final matrix =
            matrixPlayers[
                matchIndex];

        if (matrix['results'] != null) {
          item['results'] =
              matrix['results'];
        }

        for (final key
            in const <String>[
          'tests',
          'matrix',
          'items',
          'filled_count',
          'completed_count',
          'results_count',
          'filled_results',
          'poor_count',
          'warnings_count',
          'bad_count',
          'weak_count',
        ]) {
          if (matrix[key] != null) {
            item[key] = matrix[key];
          }
        }

        // Сохраняем исходные matrix ID только как служебные.
        item['_matrix_player_id'] =
            _testingPlayerId(
          matrix,
        );
      }

      // Основной ID строки всегда остаётся ID игрока из roster.
      item['id'] = rosterId;
      item['player_id'] =
          rosterId;

      final resolvedName =
          _testingPlayerName(item);

      if (resolvedName.isNotEmpty &&
          !resolvedName.startsWith(
            'Игрок #',
          ) &&
          resolvedName != 'Игрок') {
        item['player_name'] =
            resolvedName;
      }

      final photo =
          _normalizeImage(
        _s(
          item['photo'] ??
              item['photo_url'] ??
              item['avatar'] ??
              item['avatar_url'] ??
              item['image'],
        ),
      );

      if (photo.isNotEmpty) {
        item['photo'] = photo;
        item['photo_url'] = photo;
      }

      merged.add(item);
    }

    // Matrix-строки, которые не совпали с roster, добавляем
    // только как реальные исторические результаты.
    // Пустые технические "Игрок #102" больше не дублируют состав.
    for (var i = 0;
        i < matrixPlayers.length;
        i++) {
      if (usedMatrixIndexes
          .contains(i)) {
        continue;
      }

      final matrix =
          Map<String, dynamic>.from(
        matrixPlayers[i],
      );

      if (!_testingPlayerHasStoredResults(
        matrix,
      )) {
        continue;
      }

      // Если по фото/имени это всё же уже присутствующий игрок,
      // вторую строку не добавляем.
      final matrixName =
          _testingIdentityName(
        matrix,
      );
      final matrixPhoto =
          _testingIdentityPhoto(
        matrix,
      );
      final matrixIds =
          _testingIdentityIds(
        matrix,
      );

      final duplicate =
          merged.any((existing) {
        final existingIds =
            _testingIdentityIds(
          existing,
        );

        if (matrixIds.isNotEmpty &&
            existingIds.any(
              matrixIds.contains,
            )) {
          return true;
        }

        final existingName =
            _testingIdentityName(
          existing,
        );

        if (matrixName.isNotEmpty &&
            existingName.isNotEmpty &&
            matrixName ==
                existingName) {
          return true;
        }

        final existingPhoto =
            _testingIdentityPhoto(
          existing,
        );

        return matrixPhoto.isNotEmpty &&
            existingPhoto.isNotEmpty &&
            matrixPhoto ==
                existingPhoto;
      });

      if (duplicate) {
        continue;
      }

      final photo =
          _normalizeImage(
        _s(
          matrix['photo'] ??
              matrix['photo_url'] ??
              matrix['avatar'] ??
              matrix['avatar_url'] ??
              matrix['image'],
        ),
      );

      if (photo.isNotEmpty) {
        matrix['photo'] = photo;
        matrix['photo_url'] =
            photo;
      }

      merged.add(matrix);
    }

    merged.sort(
      (a, b) =>
          _testingPlayerName(a)
              .toLowerCase()
              .compareTo(
                _testingPlayerName(b)
                    .toLowerCase(),
              ),
    );

    return merged;
  }

  Future<Map<String, dynamic>> _loadTestingMatrix(
    Map<String, dynamic> session,
    Map<String, dynamic> team, {
    required bool withStage,
  }) async {
    final category =
        _testingCategoryKey(session);

    final stage = _s(
      session['_stage'] ??
          session['stage'],
    ).isNotEmpty
        ? _s(
            session['_stage'] ??
                session['stage'],
          )
        : _testingStage(team);

    final params = <String, String>{
      'club_id': '${widget.clubId}',
      'team_id': '${_teamId(team)}',
      'category': category,
      if (withStage && stage.isNotEmpty)
        'stage': stage,
      if (_testingDateIso(session).isNotEmpty)
        'test_date': _testingDateIso(session),
      if (_testingSessionId(session) > 0)
        'session_id':
            '${_testingSessionId(session)}',
    };

    final uri = Uri.parse(
      _testingMatrixUrl,
    ).replace(
      queryParameters: params,
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 15),
        );

    final decoded =
        _decode(response.body);

    return decoded is Map
        ? Map<String, dynamic>.from(
            decoded,
          )
        : <String, dynamic>{};
  }

  Future<void> _openTestingSessionDetail(
    Map<String, dynamic> session,
    Map<String, dynamic> team,
  ) async {
    if (!mounted) return;

    setState(() {
      _selectedTestingSession =
          Map<String, dynamic>.from(
        session,
      );
      _testingDetailLoading = true;
      _testingDetailError = null;
      _testingDetailPlayers =
          <Map<String, dynamic>>[];
    });

    try {
      var matrix =
          await _loadTestingMatrix(
        session,
        team,
        withStage: true,
      );

      dynamic rawPlayers =
          matrix['players'];

      if (rawPlayers is! List ||
          rawPlayers.isEmpty) {
        final fallback =
            await _loadTestingMatrix(
          session,
          team,
          withStage: false,
        );

        if (fallback.isNotEmpty) {
          matrix = fallback;
          rawPlayers =
              fallback['players'];
        }
      }

      final matrixPlayers =
          rawPlayers is List
              ? rawPlayers
                  .whereType<Map>()
                  .map(
                    (e) =>
                        Map<String, dynamic>.from(
                      e,
                    ),
                  )
                  .toList()
              : <Map<String, dynamic>>[];

      List<Map<String, dynamic>>
          roster =
          <Map<String, dynamic>>[];

      try {
        roster =
            await _loadTestingTeamPlayers(
          _teamId(team),
        );
      } catch (_) {
        // Если состав временно не загрузился,
        // результаты matrix всё равно показываем.
      }

      final players =
          _mergeTestingPlayersWithRoster(
        roster,
        matrixPlayers,
      );

      final rawTests =
          matrix['tests'] ??
              matrix['test_items'] ??
              matrix['columns'];

      final totalTests =
          rawTests is List
              ? rawTests.length
              : 0;

      final matrixTests =
          rawTests is List
              ? rawTests
                  .whereType<Map>()
                  .map(
                    (e) =>
                        Map<String, dynamic>.from(
                      e,
                    ),
                  )
                  .toList()
              : <Map<String, dynamic>>[];

      for (final player in players) {
        if (totalTests > 0) {
          player['_testing_total_count'] =
              totalTests;
        }

        // Сохраняем тесты и ID именно той matrix/session,
        // из которой рассчитан счётчик заполненных значений.
        player['_testing_tests'] =
            matrixTests;
        player['_testing_session_id'] =
            _testingSessionId(session);
        player['_testing_date'] =
            _testingDateIso(session);
        player['_testing_category'] =
            _testingCategoryKey(session);
      }

      if (!mounted) return;

      final current =
          _selectedTestingSession;

      if (current == null ||
          _testingSessionId(current) !=
              _testingSessionId(session) ||
          _testingCategoryKey(current) !=
              _testingCategoryKey(session)) {
        return;
      }

      setState(() {
        _testingDetailPlayers = players;
        _testingDetailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _testingDetailLoading = false;
        _testingDetailError =
            'Не удалось загрузить результаты игроков: $e';
      });
    }
  }

  void _closeTestingSessionDetail() {
    if (!mounted) return;
    setState(() {
      _selectedTestingSession = null;
      _testingDetailLoading = false;
      _testingDetailError = null;
      _testingDetailPlayers =
          <Map<String, dynamic>>[];
    });
  }

  void _openFullTesting(
    Map<String, dynamic> session,
    Map<String, dynamic> team, {
    Map<String, dynamic>? player,
  }) {
    final category =
        _testingCategoryKey(session);

    final stage = _s(
      session['_stage'] ??
          session['stage'],
    ).isNotEmpty
        ? _s(
            session['_stage'] ??
                session['stage'],
          )
        : _testingStage(team);

    final playerId = player == null
        ? 0
        : _testingPlayerId(player);

    final playerName = player == null
        ? ''
        : _testingPlayerName(player);

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: CmrTestingPanel(
              clubId: widget.clubId,
              teamId: _teamId(team),
              clubName: widget.clubName,
              teamName: _teamName(team),
              initialStage: stage,
              initialCategory: category,
              initialDate:
                  _testingDateIso(session)
                          .isEmpty
                      ? null
                      : _testingDateIso(
                          session,
                        ),
              initialPlayerId:
                  playerId > 0
                      ? playerId
                      : null,
              initialPlayerName:
                  playerName.isEmpty
                      ? null
                      : playerName,
              onBackToMenu: () =>
                  Navigator.of(
                    routeContext,
                  ).pop(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _testingSection() {
    if (_teams.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _TpEmpty(
          title: 'Нет назначенной команды',
          text:
              'Тестирование тренера связано с командами, с которыми он работает.',
        ),
      );
    }

    final team =
        _teamById(_testingTeamId) ??
        _teams.first;

    final teamId = _teamId(team);

    final loading =
        _testingLoadingTeams.contains(teamId);

    final rows =
        _testingByTeam[teamId] ??
        const <Map<String, dynamic>>[];

    if (!_testingByTeam.containsKey(teamId) &&
        !loading) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureTesting(teamId),
      );
    }

    bool sameDay(
      DateTime a,
      DateTime b,
    ) =>
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;

    DateTime? sessionDate(
      Map<String, dynamic> row,
    ) {
      return _date(
        row['test_date'] ??
            row['date'] ??
            row['created_at'],
      );
    }

    final visibleRows =
        _testingDateFilterActive
            ? rows
                .where((row) {
                  final date =
                      sessionDate(row);

                  return date != null &&
                      sameDay(
                        date,
                        _testingSelected,
                      );
                })
                .toList()
            : List<Map<String, dynamic>>.from(
                rows,
              );

    final marks = <String, int>{};

    for (final row in rows) {
      final date = sessionDate(row);
      if (date == null) continue;

      final key =
          _TpTrainerCalendar.key(date);

      marks[key] =
          (marks[key] ?? 0) + 1;
    }

    void selectDate(DateTime date) {
      if (!mounted) return;

      final normalized =
          DateTime(
        date.year,
        date.month,
        date.day,
      );

      setState(() {
        _testingSelected = normalized;
        _testingDateFilterActive = true;
        _selectedTestingSession = null;
        _testingDetailPlayers =
            <Map<String, dynamic>>[];
        _testingDetailError = null;

        if (_testingCursor.year !=
                normalized.year ||
            _testingCursor.month !=
                normalized.month) {
          _testingCursor = DateTime(
            normalized.year,
            normalized.month,
            1,
          );
        }
      });
    }

    void shiftMonth(int delta) {
      if (!mounted) return;

      setState(() {
        _testingCursor = DateTime(
          _testingCursor.year,
          _testingCursor.month + delta,
          1,
        );
        _testingDateFilterActive = false;
      });
    }

    void today() {
      final now = DateTime.now();
      selectDate(
        DateTime(
          now.year,
          now.month,
          now.day,
        ),
      );
    }

    Widget calendarWindow({
      required bool phone,
    }) {
      return Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: phone ? 56 : 58,
              padding: EdgeInsets.fromLTRB(
                phone ? 11 : 13,
                8,
                phone ? 9 : 11,
                8,
              ),
              color: Colors.white,
              child: Row(
                children: <Widget>[
                  Container(
                    width: phone ? 36 : 38,
                    height: phone ? 36 : 38,
                    decoration: BoxDecoration(
                      color: _TpColors.soft,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: _TpDotCluster(
                        color:
                            _TpColors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          _TpTrainerCalendar
                              .monthTitle(
                            _testingCursor,
                          ),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: _TpText.title(
                            14.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _testingDateFilterActive
                              ? '${_TpTrainerCalendar.dateLabel(_testingSelected)} · '
                                  '${visibleRows.length} ${_TpTestingCalendar.sessionWord(visibleRows.length)}'
                              : 'Все даты · '
                                  '${rows.length} ${_TpTestingCalendar.sessionWord(rows.length)}',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: _TpText.body(
                            9.7,
                            color:
                                _TpColors.muted,
                            weight:
                                FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TpCalendarIconButton(
                    icon:
                        Icons.chevron_left_rounded,
                    onTap: () =>
                        shiftMonth(-1),
                  ),
                  const SizedBox(width: 5),
                  _TpCalendarIconButton(
                    icon:
                        Icons.chevron_right_rounded,
                    onTap: () =>
                        shiftMonth(1),
                  ),
                  const SizedBox(width: 5),
                  _TpCalendarIconButton(
                    icon: Icons.today_rounded,
                    onTap: today,
                  ),
                  const SizedBox(width: 5),
                  _TpCalendarTextButton(
                    text: 'Все',
                    active:
                        !_testingDateFilterActive,
                    onTap: () {
                      if (!mounted) return;
                      setState(() {
                        _testingDateFilterActive =
                            false;
                        _selectedTestingSession = null;
                        _testingDetailPlayers =
                            <Map<String, dynamic>>[];
                        _testingDetailError = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: _TpColors.line,
            ),
            _teamSelector(
              value: teamId,
              color: _TpColors.red,
              onChanged: (id) {
                if (!mounted) return;

                setState(() {
                  _testingTeamId = id;
                  _testingDateFilterActive =
                      false;
                  _selectedTestingSession = null;
                  _testingDetailPlayers =
                      <Map<String, dynamic>>[];
                  _testingDetailError = null;
                });

                _ensureTesting(
                  id,
                  force: true,
                );
              },
            ),
            Container(
              height: 1,
              color: _TpColors.line,
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  10,
                  11,
                  10,
                  12,
                ),
                child:
                    _TpTrainerMonthCalendar(
                  cursor: _testingCursor,
                  selected:
                      _testingDateFilterActive
                          ? _testingSelected
                          : DateTime(
                              1900,
                              1,
                              1,
                            ),
                  marks: marks,
                  onSelect: selectDate,
                  roomy: true,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget listWindow({
      required bool phone,
    }) {
      if (loading && rows.isEmpty) {
        return const ColoredBox(
          color: Colors.white,
          child: Center(
            child: CircularProgressIndicator(
              color: _TpColors.green,
              strokeWidth: 2,
            ),
          ),
        );
      }

      return ColoredBox(
        color: Colors.white,
        child: Column(
          children: <Widget>[
            Container(
              height: phone ? 52 : 54,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Row(
                children: <Widget>[
                  const _TpDotCluster(
                    color: _TpColors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Сессии тестирования',
                          style:
                              _TpText.title(12.6),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _testingDateFilterActive
                              ? '${_TpTrainerCalendar.dateLabel(_testingSelected)} · ${_teamName(team)}'
                              : 'Общий список · ${_teamName(team)}',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: _TpText.body(
                            9,
                            color:
                                _TpColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color:
                            _TpColors.green,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: _TpColors.line,
            ),
            Expanded(
              child: _selectedTestingSession != null
                  ? _TpTestingSessionDetail(
                      session:
                          _selectedTestingSession!,
                      players:
                          _testingDetailPlayers,
                      loading:
                          _testingDetailLoading,
                      error:
                          _testingDetailError,
                      teamName:
                          _teamName(team),
                      onBack:
                          _closeTestingSessionDetail,
                      onOpenTesting: () =>
                          _openFullTesting(
                        _selectedTestingSession!,
                        team,
                      ),
                    )
                  : _TpTestingList(
                      teamName:
                          _teamName(team),
                      stage:
                          _testingStage(team),
                      rows: visibleRows,
                      scopeLabel:
                          _testingDateFilterActive
                              ? _TpTrainerCalendar
                                  .dateLabel(
                                    _testingSelected,
                                  )
                              : 'Все даты',
                      onOpenSession: (session) =>
                          _openTestingSessionDetail(
                        session,
                        team,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final mobile =
            constraints.maxWidth < 720;

        if (mobile) {
          final first = DateTime(
            _testingCursor.year,
            _testingCursor.month,
            1,
          );

          final daysInMonth = DateTime(
            _testingCursor.year,
            _testingCursor.month + 1,
            0,
          ).day;

          final rowsCount =
              ((first.weekday -
                          1 +
                          daysInMonth +
                          6) ~/
                      7);

          final calendarHeight =
              rowsCount >= 6
                  ? 455.0
                  : 420.0;

          final listHeight = math
              .max(
                260.0,
                math.min(
                  620.0,
                  180.0 +
                      visibleRows.length *
                          65.0,
                ),
              )
              .toDouble();

          return ListView(
            padding:
                const EdgeInsets.fromLTRB(
              8,
              8,
              8,
              24,
            ),
            children: <Widget>[
              SizedBox(
                height: calendarHeight,
                child: calendarWindow(
                  phone: true,
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: listHeight,
                child: listWindow(
                  phone: true,
                ),
              ),
            ],
          );
        }

        final calendarWidth = math
            .min(
              480.0,
              math.max(
                360.0,
                constraints.maxWidth * .42,
              ),
            )
            .toDouble();

        return Padding(
          padding:
              const EdgeInsets.fromLTRB(
            8,
            8,
            8,
            8,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: calendarWidth,
                child: calendarWindow(
                  phone: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: listWindow(
                  phone: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

class _TpColors {
  static const Color page = Color(0xFFF6F7F6);
  static const Color soft = Color(0xFFF7F9F8);
  static const Color line = Color(0xFFEEF1EF);

  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF667085);
  static const Color muted2 = Color(0xFF98A2B3);

  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);

  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFD92D20);
    static const Color redSoft = Color(0xFFFFF1F1);
static const Color blue = Color(0xFF2563EB);
}

class _TpText {
  static TextStyle title(
    double size, {
    Color color = _TpColors.text,
    FontWeight weight = FontWeight.w600,
  }) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: 1.18,
      letterSpacing: 0,
      features: const <FontFeature>[
        FontFeature.tabularFigures(),
      ],
    );
  }

  static TextStyle body(
    double size, {
    Color color = _TpColors.text,
    FontWeight weight = FontWeight.w400,
    double height = 1.25,
  }) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: height,
      letterSpacing: 0,
    );
  }
}

class _TpDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _TpDot({
    required this.color,
    this.size = 5,
    this.opacity = 1,
  });

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
          boxShadow: opacity >= .95
              ? <BoxShadow>[
                  BoxShadow(
                    color:
                        color.withOpacity(.17),
                    blurRadius: size * 2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _TpDotCluster extends StatelessWidget {
  final Color color;
  final bool compact;

  const _TpDotCluster({
    this.color = _TpColors.green,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scale =
        compact ? .78 : 1.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _TpDot(
          color: color,
          size: 3.4 * scale,
          opacity: .34,
        ),
        SizedBox(width: 3 * scale),
        _TpDot(
          color: color,
          size: 4.4 * scale,
          opacity: .56,
        ),
        SizedBox(width: 3 * scale),
        _TpDot(
          color: color,
          size: 5.4 * scale,
          opacity: .78,
        ),
        SizedBox(width: 3 * scale),
        _TpDot(
          color: color,
          size: 6.4 * scale,
        ),
      ],
    );
  }
}


class _TpAvatar extends StatelessWidget {
  final String photo;
  final String name;
  final double size;

  const _TpAvatar({
    required this.photo,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    final initials = parts.isEmpty
        ? 'Т'
        : parts
            .take(2)
            .map(
              (e) => e[0].toUpperCase(),
            )
            .join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _TpColors.soft,
        borderRadius: BorderRadius.circular(
          math.min(12.0, size * .18).toDouble(),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isEmpty
          ? Center(
              child: Text(
                initials,
                style: _TpText.title(
                  size * .28,
                  color:
                      _TpColors.greenDark,
                ),
              ),
            )
          : Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Center(
                child: Text(
                  initials,
                  style: _TpText.title(
                    size * .28,
                    color:
                        _TpColors.greenDark,
                  ),
                ),
              ),
            ),
    );
  }
}

class _TpHeaderAction extends StatelessWidget {
  final String label;
  final Color dotColor;
  final VoidCallback onTap;
  final bool emphasized;
  final bool compact;
  final bool active;

  const _TpHeaderAction({
    required this.label,
    required this.dotColor,
    required this.onTap,
    this.emphasized = false,
    this.compact = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final background =
        emphasized || active
            ? _TpColors.greenSoft
            : _TpColors.soft;

    return Material(
      color: background,
      borderRadius:
          BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(9),
        child: Container(
          height: 36,
          padding:
              EdgeInsets.symmetric(
            horizontal:
                compact ? 10 : 11,
          ),
          alignment: Alignment.center,
          child: compact
              ? Text(
                  label,
                  style:
                      _TpText.title(14),
                )
              : Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: <Widget>[
                    _TpDot(
                      color: dotColor,
                      size:
                          emphasized
                              ? 6
                              : 5,
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Text(
                      label,
                      style:
                          _TpText.body(
                        10.2,
                        color:
                            emphasized ||
                                    active
                                ? _TpColors
                                    .greenDark
                                : _TpColors
                                    .text,
                        weight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TpAction extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _TpAction({
    required this.title,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled
          ? color
          : color.withOpacity(.07),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _TpDot(
                color: filled
                    ? Colors.white
                    : color,
                size: 4.5,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: _TpText.body(
                    9.5,
                    color: filled
                        ? Colors.white
                        : color,
                    weight: FontWeight.w600,
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

class _TpSectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _TpSectionTitle({
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _TpDot(
          color: color,
          size: 5.5,
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: _TpText.title(11.8),
        ),
      ],
    );
  }
}

class _TpInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _TpInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 42,
      ),
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _TpColors.line,
            width: .55,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: _TpText.body(
                9.2,
                color: _TpColors.muted2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style: _TpText.body(
                10.5,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TpTeamRow extends StatelessWidget {
  final String photo;
  final String name;
  final String role;

  const _TpTeamRow({
    required this.photo,
    required this.name,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 58,
      ),
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _TpColors.line,
            width: .55,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          _TpAvatar(
            photo: photo,
            name: name,
            size: 40,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: _TpText.title(10.8),
                ),
                const SizedBox(height: 3),
                Text(
                  role,
                  style: _TpText.body(
                    9.1,
                    color:
                        _TpColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const _TpDot(
            color: _TpColors.green,
            size: 5,
          ),
        ],
      ),
    );
  }
}

class _TpPill extends StatelessWidget {
  final String text;
  final Color color;

  const _TpPill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.065),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _TpDot(
            color: color,
            size: 4.2,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: _TpText.body(
              9.1,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TpTrainerCalendar {
  static String key(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  static String monthTitle(DateTime date) {
    const months = <String>[
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  static String dateLabel(DateTime date) {
    const months = <String>[
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];

    return '${date.day} ${months[date.month - 1]}';
  }

  static String eventWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;

    if (mod10 == 1 && mod100 != 11) {
      return 'занятие';
    }
    if (mod10 >= 2 &&
        mod10 <= 4 &&
        (mod100 < 10 || mod100 >= 20)) {
      return 'занятия';
    }
    return 'занятий';
  }
}

class _TpCalendarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TpCalendarIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _TpColors.soft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 16,
            color: _TpColors.greenDark,
          ),
        ),
      ),
    );
  }
}

class _TpCalendarTextButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _TpCalendarTextButton({
    required this.text,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? _TpColors.greenSoft
          : _TpColors.soft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 30,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            child: Center(
              child: Text(
                text,
                style: _TpText.body(
                  8.8,
                  color: active
                      ? _TpColors.greenDark
                      : _TpColors.muted,
                  weight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TpTestingCalendar {
  static String sessionWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;

    if (mod10 == 1 && mod100 != 11) {
      return 'сессия';
    }

    if (mod10 >= 2 &&
        mod10 <= 4 &&
        (mod100 < 10 || mod100 >= 20)) {
      return 'сессии';
    }

    return 'сессий';
  }
}

class _TpTrainerMonthCalendar extends StatelessWidget {
  final DateTime cursor;
  final DateTime selected;
  final Map<String, int> marks;
  final ValueChanged<DateTime> onSelect;
  final bool roomy;

  const _TpTrainerMonthCalendar({
    required this.cursor,
    required this.selected,
    required this.marks,
    required this.onSelect,
    this.roomy = false,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = <String>[
      'Пн',
      'Вт',
      'Ср',
      'Чт',
      'Пт',
      'Сб',
      'Вс',
    ];

    final first =
        DateTime(cursor.year, cursor.month, 1);
    final daysInMonth =
        DateTime(cursor.year, cursor.month + 1, 0).day;
    final prevMonthDays =
        DateTime(cursor.year, cursor.month, 0).day;
    final leading = first.weekday - 1;
    final total =
        ((leading + daysInMonth + 6) ~/ 7) * 7;
    final rowsCount = total ~/ 7;

    Widget grid(
      double maxHeight,
      double maxWidth,
    ) {
      final gap = roomy ? 7.0 : 6.0;
      final cellWidth =
          (maxWidth - gap * 6) / 7;

      final bounded =
          maxHeight.isFinite && maxHeight > 0;

      final availableHeight = bounded
          ? math.max(
              0.0,
              (maxHeight -
                      gap * (rowsCount - 1)) /
                  rowsCount,
            )
          : cellWidth / 1.18;

      final targetHeight = cellWidth / 1.18;
      final preferredHeight = roomy
          ? math.max(
              42.0,
              math.min(58.0, targetHeight),
            )
          : math.max(
              34.0,
              math.min(44.0, targetHeight),
            );

      final cellHeight = bounded
          ? math.min(
              preferredHeight,
              availableHeight,
            ).toDouble()
          : preferredHeight.toDouble();

      final children = <Widget>[];

      for (int row = 0;
          row < rowsCount;
          row++) {
        final rowCells = <Widget>[];

        for (int col = 0; col < 7; col++) {
          final index = row * 7 + col;
          final dayNumber =
              index - leading + 1;

          late DateTime day;
          bool inMonth = true;

          if (dayNumber < 1) {
            day = DateTime(
              cursor.year,
              cursor.month - 1,
              prevMonthDays + dayNumber,
            );
            inMonth = false;
          } else if (dayNumber > daysInMonth) {
            day = DateTime(
              cursor.year,
              cursor.month + 1,
              dayNumber - daysInMonth,
            );
            inMonth = false;
          } else {
            day = DateTime(
              cursor.year,
              cursor.month,
              dayNumber,
            );
          }

          final count =
              marks[_TpTrainerCalendar.key(day)] ?? 0;

          rowCells.add(
            Expanded(
              child: SizedBox(
                height: cellHeight,
                child: _TpTrainerCalendarDayCell(
                  day: day,
                  inMonth: inMonth,
                  selected:
                      _TpTrainerCalendar.sameDay(
                    day,
                    selected,
                  ),
                  today:
                      _TpTrainerCalendar.sameDay(
                    day,
                    DateTime.now(),
                  ),
                  count: count,
                  roomy: roomy,
                  onTap: () => onSelect(
                    DateTime(
                      day.year,
                      day.month,
                      day.day,
                    ),
                  ),
                ),
              ),
            ),
          );

          if (col != 6) {
            rowCells.add(
              SizedBox(width: gap),
            );
          }
        }

        children.add(
          Row(children: rowCells),
        );

        if (row != rowsCount - 1) {
          children.add(
            SizedBox(height: gap),
          );
        }
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }

    return LayoutBuilder(
      builder: (context, outer) {
        final header = Row(
          children: weekdays
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: _TpText.body(
                        9.4,
                        color: _TpColors.muted,
                        weight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );

        final gridWidget = LayoutBuilder(
          builder: (context, box) =>
              grid(
            box.maxHeight,
            box.maxWidth,
          ),
        );

        return Column(
          children: <Widget>[
            header,
            const SizedBox(height: 8),
            if (outer.maxHeight.isFinite)
              Expanded(child: gridWidget)
            else
              gridWidget,
          ],
        );
      },
    );
  }
}

class _TpTrainerCalendarDayCell extends StatelessWidget {
  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final int count;
  final bool roomy;
  final VoidCallback onTap;

  const _TpTrainerCalendarDayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.count,
    required this.roomy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final has = count > 0;

    final background = selected
        ? _TpColors.greenSoft
        : has
            ? Colors.white
            : inMonth
                ? _TpColors.page
                : Colors.white;

    final textColor = selected
        ? _TpColors.greenDark
        : inMonth
            ? today
                ? _TpColors.green
                : _TpColors.text
            : _TpColors.muted2.withOpacity(.68);

    return Material(
      color: Colors.transparent,
      borderRadius:
          BorderRadius.circular(roomy ? 12 : 11),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(roomy ? 12 : 11),
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 160),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius:
                BorderRadius.circular(
              roomy ? 12 : 11,
            ),
            boxShadow: selected
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x07111827),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: <Widget>[
              Center(
                child: Text(
                  '${day.day}',
                  maxLines: 1,
                  style: _TpText.body(
                    roomy ? 10.8 : 10.1,
                    color: textColor,
                    weight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
              if (has)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    constraints:
                        const BoxConstraints(
                      minWidth: 14,
                    ),
                    height: 14,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _TpColors.green,
                      borderRadius:
                          BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: _TpText.body(
                          8.0,
                          color: Colors.white,
                          weight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              if (selected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: has ? 4 : 5,
                  child: Center(
                    child: Container(
                      width: has ? 4 : 6,
                      height: has ? 4 : 6,
                      decoration:
                          const BoxDecoration(
                        color: _TpColors.green,
                        shape: BoxShape.circle,
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
}

class _TpTrainerSelectedDayPanel extends StatelessWidget {
  final DateTime selected;
  final List<Map<String, dynamic>> events;
  final bool compact;

  const _TpTrainerSelectedDayPanel({
    required this.selected,
    required this.events,
    required this.compact,
  });

  String _s(dynamic value) =>
      '${value ?? ''}'.trim();

  DateTime? _date(dynamic value) {
    final text = _s(value);
    if (text.isEmpty) return null;
    return DateTime.tryParse(
      text.replaceFirst(' ', 'T'),
    );
  }

  String _two(int value) =>
      value.toString().padLeft(2, '0');

  String _time(DateTime? value) {
    if (value == null) return '—';
    return '${_two(value.hour)}:${_two(value.minute)}';
  }

  String _eventType(Map<String, dynamic> event) {
    final raw = _s(
      event['type'] ??
          event['event_type'] ??
          event['kind'],
    ).toLowerCase();

    if (raw.contains('match') ||
        raw.contains('игр')) {
      return 'Матч';
    }
    if (raw.contains('test') ||
        raw.contains('тест')) {
      return 'Тестирование';
    }
    if (raw.contains('meeting') ||
        raw.contains('собран')) {
      return 'Собрание';
    }
    return 'Тренировка';
  }

  Color _eventColor(Map<String, dynamic> event) {
    final type = _eventType(event);
    if (type == 'Матч') return _TpColors.red;
    if (type == 'Тестирование') {
      return _TpColors.amber;
    }
    if (type == 'Собрание') {
      return _TpColors.greenDark;
    }
    return _TpColors.green;
  }

  @override
  Widget build(BuildContext context) {
    final locations = events
        .map(
          (e) => _s(
            e['location'] ??
                e['venue'] ??
                e['address'] ??
                e['place'],
          ),
        )
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final teams = events
        .map((e) => _s(e['team_name']))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(compact ? 18 : 20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x07111827),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: compact ? 52 : 54,
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 12,
              7,
              compact ? 9 : 10,
              7,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: _TpColors.line,
                  width: .65,
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: compact ? 32 : 34,
                  height: compact ? 32 : 34,
                  decoration: BoxDecoration(
                    color: _TpColors.soft,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: _TpDot(
                      color: _TpColors.greenDark,
                      size: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Занятия дня',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _TpText.title(
                          13.2,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_TpTrainerCalendar.dateLabel(selected)} · '
                        '${events.length} ${_TpTrainerCalendar.eventWord(events.length)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _TpText.body(
                          9.7,
                          color: _TpColors.muted,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                10,
                9,
                10,
                6,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _TpDayMetric(
                      label: 'Команд',
                      value: '${teams.length}',
                      color: _TpColors.green,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _TpDayMetric(
                      label: 'Локаций',
                      value: '${locations.length}',
                      color: _TpColors.amber,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _TpDayMetric(
                      label: 'Событий',
                      value: '${events.length}',
                      color: _TpColors.greenDark,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: <Widget>[
                          const _TpDotCluster(
                            color:
                                _TpColors.muted2,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'На выбранный день занятий нет',
                            textAlign:
                                TextAlign.center,
                            style: _TpText.body(
                              10.8,
                              color:
                                  _TpColors.muted,
                              weight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(
                      10,
                      0,
                      10,
                      10,
                    ),
                    itemCount: events.length,
                    separatorBuilder:
                        (_, __) =>
                            const SizedBox(
                      height: 6,
                    ),
                    itemBuilder:
                        (context, index) {
                      final event =
                          events[index];

                      final start = _date(
                        event['start_at'] ??
                            event['date'] ??
                            event['event_date'],
                      );

                      final title = _s(
                        event['title'],
                      ).isEmpty
                          ? 'Занятие'
                          : _s(
                              event['title'],
                            );

                      final team =
                          _s(event['team_name']);

                      final location = _s(
                        event['location'] ??
                            event['venue'] ??
                            event['address'] ??
                            event['place'],
                      );

                      final type =
                          _eventType(event);
                      final color =
                          _eventColor(event);

                      return Material(
                        color: _TpColors.soft,
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(
                            10,
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: <Widget>[
                              SizedBox(
                                width: 46,
                                child: Text(
                                  _time(start),
                                  style: _TpText.title(
                                    10.8,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 7,
                              ),
                              _TpDot(
                                color: color,
                                size: 6,
                              ),
                              const SizedBox(
                                width: 8,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                            style:
                                                _TpText.title(
                                              10.8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 6,
                                        ),
                                        _TpPill(
                                          text: type,
                                          color: color,
                                        ),
                                      ],
                                    ),
                                    if (team.isNotEmpty ||
                                        location
                                            .isNotEmpty) ...<
                                        Widget>[
                                      const SizedBox(
                                        height: 4,
                                      ),
                                      Text(
                                        <String>[
                                          if (team
                                              .isNotEmpty)
                                            team,
                                          if (location
                                              .isNotEmpty)
                                            location,
                                        ].join(' · '),
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            _TpText.body(
                                          9.2,
                                          color:
                                              _TpColors
                                                  .muted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
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

class _TpDayMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TpDayMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: _TpColors.soft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: <Widget>[
          _TpDot(
            color: color,
            size: 5,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: _TpText.title(10.7),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: _TpText.body(
                    8.1,
                    color: _TpColors.muted2,
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

class _TpPlanCalendar {
  static String planWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;

    if (mod10 == 1 && mod100 != 11) {
      return 'план';
    }

    if (mod10 >= 2 &&
        mod10 <= 4 &&
        (mod100 < 10 || mod100 >= 20)) {
      return 'плана';
    }

    return 'планов';
  }
}

class _TpPlanTeamChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TpPlanTeamChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? _TpColors.greenSoft
          : _TpColors.soft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 9,
          ),
          child: Row(
            children: <Widget>[
              _TpDot(
                color: active
                    ? _TpColors.green
                    : _TpColors.muted2,
                size: active ? 5 : 4,
                opacity: active ? 1 : .58,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: _TpText.body(
                  9.1,
                  color: active
                      ? _TpColors.greenDark
                      : _TpColors.muted,
                  weight: active
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TpTrainerPlansDayPanel extends StatelessWidget {
  final DateTime selected;
  final bool allDates;
  final List<Map<String, dynamic>> plans;
  final Map<String, dynamic>? selectedPlan;
  final bool compact;

  final String Function(
    Map<String, dynamic>,
  ) titleOf;

  final String Function(
    Map<String, dynamic>,
  ) teamOf;

  final String Function(
    Map<String, dynamic>,
  ) descriptionOf;

  final DateTime? Function(
    Map<String, dynamic>,
  ) addedDateOf;

  final DateTime? Function(
    Map<String, dynamic>,
  ) trainingDateOf;

  final ValueChanged<
      Map<String, dynamic>> onDetails;

  final ValueChanged<
      Map<String, dynamic>> onOpenPlan;

  const _TpTrainerPlansDayPanel({
    required this.selected,
    required this.allDates,
    required this.plans,
    required this.selectedPlan,
    required this.compact,
    required this.titleOf,
    required this.teamOf,
    required this.descriptionOf,
    required this.addedDateOf,
    required this.trainingDateOf,
    required this.onDetails,
    required this.onOpenPlan,
  });

  String _s(dynamic value) =>
      '${value ?? ''}'.trim();

  String _two(int value) =>
      value.toString().padLeft(2, '0');

  String _date(DateTime? value) {
    if (value == null) return '—';

    return '${_two(value.day)}.'
        '${_two(value.month)}.'
        '${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final preview = selectedPlan;

    final teams = plans
        .map(teamOf)
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .length;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: compact ? 52 : 54,
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 12,
              7,
              compact ? 9 : 10,
              7,
            ),
            color: Colors.white,
            child: Row(
              children: <Widget>[
                Container(
                  width: compact ? 32 : 34,
                  height: compact ? 32 : 34,
                  decoration: BoxDecoration(
                    color: _TpColors.soft,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: _TpDot(
                      color:
                          _TpColors.greenDark,
                      size: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Планы тренера',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: _TpText.title(
                          13.2,
                          weight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        allDates
                            ? 'Все даты · '
                                '${plans.length} ${_TpPlanCalendar.planWord(plans.length)}'
                            : '${_TpTrainerCalendar.dateLabel(selected)} · '
                                '${plans.length} ${_TpPlanCalendar.planWord(plans.length)}',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: _TpText.body(
                          9.7,
                          color:
                              _TpColors.muted,
                          weight:
                              FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (plans.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                7,
                10,
                6,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _TpDayMetric(
                      label: 'Планов',
                      value:
                          '${plans.length}',
                      color:
                          _TpColors.green,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _TpDayMetric(
                      label: 'Команд',
                      value: '$teams',
                      color:
                          _TpColors.greenDark,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: plans.isEmpty
                ? Center(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 18,
                      ),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: <Widget>[
                          const _TpDotCluster(
                            color:
                                _TpColors.muted2,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            'В этот день тренер планы не добавлял',
                            textAlign:
                                TextAlign.center,
                            style: _TpText.body(
                              10.8,
                              color:
                                  _TpColors.muted,
                              weight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(
                      10,
                      0,
                      10,
                      8,
                    ),
                    itemCount: plans.length,
                    separatorBuilder:
                        (_, __) =>
                            const SizedBox(
                      height: 5,
                    ),
                    itemBuilder:
                        (context, index) {
                      final plan =
                          plans[index];

                      final cycle = _s(
                        plan['cycle_title'] ??
                            plan['cycle'],
                      );

                      final location = _s(
                        plan['location'] ??
                            plan['place'] ??
                            plan[
                                'training_place'],
                      );

                      return Material(
                        color: _TpColors.soft,
                        borderRadius:
                            BorderRadius.circular(
                          9,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(
                            10,
                            9,
                            8,
                            9,
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .center,
                            children: <Widget>[
                              const _TpDot(
                                color:
                                    _TpColors.green,
                                size: 5.5,
                              ),
                              const SizedBox(
                                width: 8,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: <Widget>[
                                    Text(
                                      titleOf(plan),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          _TpText.title(
                                        10.7,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 3,
                                    ),
                                    Text(
                                      <String>[
                                        teamOf(plan),
                                        if (cycle
                                            .isNotEmpty)
                                          cycle,
                                        if (location
                                            .isNotEmpty)
                                          location,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          _TpText.body(
                                        8.9,
                                        color:
                                            _TpColors
                                                .muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 7,
                              ),
                              Material(
                                color:
                                    Colors.white,
                                borderRadius:
                                    BorderRadius.circular(
                                  8,
                                ),
                                child: InkWell(
                                  onTap: () =>
                                      onDetails(
                                    plan,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(
                                    8,
                                  ),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 8,
                                      vertical: 7,
                                    ),
                                    child: Text(
                                      'Подробнее',
                                      style:
                                          _TpText.body(
                                        8.8,
                                        color:
                                            _TpColors
                                                .greenDark,
                                        weight:
                                            FontWeight
                                                .w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (preview != null)
            _TpTrainerPlanPreview(
              plan: preview,
              title: titleOf(preview),
              team: teamOf(preview),
              description:
                  descriptionOf(preview),
              addedDate:
                  addedDateOf(preview),
              trainingDate:
                  trainingDateOf(preview),
              onOpen: () =>
                  onOpenPlan(preview),
            ),
        ],
      ),
    );
  }
}

class _TpTrainerPlanPreview extends StatelessWidget {
  final Map<String, dynamic> plan;
  final String title;
  final String team;
  final String description;
  final DateTime? addedDate;
  final DateTime? trainingDate;
  final VoidCallback onOpen;

  const _TpTrainerPlanPreview({
    required this.plan,
    required this.title,
    required this.team,
    required this.description,
    required this.addedDate,
    required this.trainingDate,
    required this.onOpen,
  });

  String _s(dynamic value) =>
      '${value ?? ''}'.trim();

  String _two(int value) =>
      value.toString().padLeft(2, '0');

  String _date(DateTime? value) {
    if (value == null) return '—';
    return '${_two(value.day)}.'
        '${_two(value.month)}.'
        '${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cycle = _s(
      plan['cycle_title'] ??
          plan['cycle'],
    );

    final location = _s(
      plan['location'] ??
          plan['place'] ??
          plan['training_place'],
    );

    return Container(
      color: _TpColors.soft,
      padding:
          const EdgeInsets.fromLTRB(
        11,
        10,
        11,
        11,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _TpDotCluster(
                color: _TpColors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: _TpText.title(11.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            description.isEmpty
                ? 'Краткое описание для этого плана пока не заполнено.'
                : description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: _TpText.body(
              9.3,
              color: _TpColors.muted,
              height: 1.34,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: <Widget>[
              _TpPlanMeta(
                label: team,
                color:
                    _TpColors.greenDark,
              ),
              _TpPlanMeta(
                label:
                    'Добавлен ${_date(addedDate)}',
                color:
                    _TpColors.green,
              ),
              if (trainingDate != null)
                _TpPlanMeta(
                  label:
                      'План ${_date(trainingDate)}',
                  color:
                      _TpColors.amber,
                ),
              if (cycle.isNotEmpty)
                _TpPlanMeta(
                  label: cycle,
                  color:
                      _TpColors.greenDark,
                ),
              if (location.isNotEmpty)
                _TpPlanMeta(
                  label: location,
                  color:
                      _TpColors.muted,
                ),
            ],
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerRight,
            child: _TpAction(
              title:
                  'Перейти к плану-конспекту',
              color:
                  _TpColors.green,
              filled: true,
              onTap: onOpen,
            ),
          ),
        ],
      ),
    );
  }
}

class _TpPlanMeta extends StatelessWidget {
  final String label;
  final Color color;

  const _TpPlanMeta({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withOpacity(.055),
        borderRadius:
            BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: <Widget>[
          _TpDot(
            color: color,
            size: 3.8,
            opacity: .8,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: _TpText.body(
              8.2,
              color:
                  _TpColors.muted,
              weight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TpTestingList extends StatelessWidget {
  final String teamName;
  final String stage;
  final List<Map<String, dynamic>> rows;
  final String scopeLabel;
  final ValueChanged<Map<String, dynamic>>
      onOpenSession;

  const _TpTestingList({
    required this.teamName,
    required this.stage,
    required this.rows,
    required this.scopeLabel,
    required this.onOpenSession,
  });

  String _s(dynamic value) =>
      '${value ?? ''}'.trim();

  DateTime? _date(dynamic raw) {
    final value = _s(raw);
    if (value.isEmpty) return null;
    return DateTime.tryParse(
      value.replaceFirst(' ', 'T'),
    );
  }

  String _category(String raw) {
    switch (raw) {
      case 'physical':
        return 'Физическая';
      case 'technical':
        return 'Техническая';
      case 'tactical':
        return 'Тактическая';
      case 'psychological':
        return 'Психология';
      case 'theory':
        return 'Теория';
      case 'functional':
        return 'Функциональная';
      default:
        return raw.isEmpty
            ? 'Тестирование'
            : raw;
    }
  }

  Color _categoryColor(String raw) {
    switch (raw) {
      case 'physical':
        return _TpColors.green;
      case 'technical':
        return _TpColors.amber;
      case 'tactical':
        return _TpColors.greenDark;
      case 'psychological':
        return _TpColors.red;
      case 'theory':
        return _TpColors.blue;
      default:
        return _TpColors.green;
    }
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        24,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            const _TpDotCluster(
              color: _TpColors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    teamName,
                    style: _TpText.title(11.8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stage.isEmpty
                        ? scopeLabel
                        : 'Этап: $stage · $scopeLabel',
                    style: _TpText.body(
                      9,
                      color: _TpColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${rows.length}',
              style: _TpText.title(
                12,
                color: _TpColors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const SizedBox(
            height: 220,
            child: _TpEmpty(
              title: 'Сессий тестирования нет',
              text:
                  'Когда команда создаст тестовую сессию, она появится здесь у тренера.',
            ),
          )
        else
          ...rows.map((row) {
            final category =
                _s(row['_category']);
            final color =
                _categoryColor(category);

            final date = _date(
              row['test_date'] ??
                  row['date'] ??
                  row['created_at'],
            );

            final title = _s(
              row['title'] ??
                  row['name'] ??
                  row['session_title'],
            );

            return Material(
              color: Colors.white,
              child: InkWell(
                onTap: () =>
                    onOpenSession(row),
                child: Container(
                  constraints:
                      const BoxConstraints(
                    minHeight: 58,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                  decoration:
                      const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _TpColors.line,
                        width: .55,
                      ),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                  _TpDot(
                    color: color,
                    size: 6,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title.isEmpty
                              ? _category(
                                  category,
                                )
                              : title,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              _TpText.title(10.7),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_category(category)} · ${_dateLabel(date)}',
                          style: _TpText.body(
                            9.1,
                            color:
                                _TpColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: _TpColors.muted2,
                  ),
                ],
              ),
                ),
              ),
            );
          }),
      ],
    );
  }
}


class _TpTestingSessionDetail
    extends StatefulWidget {
  final Map<String, dynamic> session;
  final List<Map<String, dynamic>> players;
  final bool loading;
  final String? error;
  final String teamName;
  final VoidCallback onBack;
  final VoidCallback onOpenTesting;

  const _TpTestingSessionDetail({
    required this.session,
    required this.players,
    required this.loading,
    required this.error,
    required this.teamName,
    required this.onBack,
    required this.onOpenTesting,
  });

  @override
  State<_TpTestingSessionDetail>
      createState() =>
          _TpTestingSessionDetailState();
}

class _TpTestingSessionDetailState
    extends State<_TpTestingSessionDetail> {
  Map<String, dynamic>? _selectedPlayer;

  String _s(dynamic value) =>
      '${value ?? ''}'.trim();

  int _playerId(
    Map<String, dynamic> player,
  ) =>
      int.tryParse(
        '${player['player_id'] ?? player['id'] ?? player['user_id'] ?? 0}',
      ) ??
      0;

  String _playerName(
    Map<String, dynamic> player,
  ) {
    final last = _s(
      player['last_name'] ??
          player['lastname'] ??
          player['surname'],
    );
    final first = _s(
      player['first_name'] ??
          player['firstname'],
    );

    final joined = '$last $first'.trim();
    if (joined.isNotEmpty) return joined;

    final direct = _s(
      player['player_name'] ??
          player['full_name'] ??
          player['fullName'] ??
          player['name'],
    );

    if (direct.isNotEmpty &&
        direct.toLowerCase() != 'игрок' &&
        direct.toLowerCase() != 'player') {
      return direct;
    }

    final id = _playerId(player);
    return id > 0 ? 'Игрок #$id' : 'Игрок';
  }

  String _playerPhoto(
    Map<String, dynamic> player,
  ) {
    var value = _s(
      player['photo'] ??
          player['photo_url'] ??
          player['avatar'] ??
          player['avatar_url'] ??
          player['image'],
    );

    if (value.isEmpty ||
        value == 'null') {
      return '';
    }

    if (value.startsWith('http://') ||
        value.startsWith('https://')) {
      return value;
    }

    if (value.startsWith('//')) {
      return 'https:$value';
    }

    if (value.startsWith('/')) {
      return 'https://sportotekaapp.ru$value';
    }

    if (value.startsWith('uploads/')) {
      return 'https://sportotekaapp.ru/$value';
    }

    return 'https://sportotekaapp.ru/uploads/$value';
  }

  String _playerPosition(
    Map<String, dynamic> player,
  ) {
    return _s(
      player['position'] ??
          player['amplua'] ??
          player['role'] ??
          player['position_name'],
    );
  }

  String _testingResultValueText(
    dynamic raw,
  ) {
    if (raw == null) return '';

    if (raw is Map) {
      for (final key in const <String>[
        'value',
        'result',
        'score',
        'points',
        'measurement',
      ]) {
        if (!raw.containsKey(key) ||
            raw[key] == null) {
          continue;
        }

        final nested =
            _testingResultValueText(
          raw[key],
        );

        if (nested.isNotEmpty) {
          return nested;
        }
      }

      return '';
    }

    if (raw is List) {
      for (final item in raw) {
        final nested =
            _testingResultValueText(item);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
      return '';
    }

    final value = _s(raw);
    if (value.isEmpty ||
        value.toLowerCase() == 'null') {
      return '';
    }

    return value;
  }

  String _testingResultUnit(
    dynamic raw,
    Map<String, dynamic> test,
  ) {
    if (raw is Map) {
      final fromResult = _s(
        raw['unit'] ??
            raw['measurement_unit'],
      );
      if (fromResult.isNotEmpty) {
        return fromResult;
      }
    }

    return _s(
      test['unit'] ??
          test['measurement_unit'],
    );
  }

  int _resultCount(
    Map<String, dynamic> player,
  ) {
    final explicit = int.tryParse(
          _s(
            player['filled_count'] ??
                player['completed_count'] ??
                player['results_count'] ??
                player['filled_results'],
          ),
        ) ??
        0;

    final results =
        player['results'] ??
            player['tests'] ??
            player['matrix'] ??
            player['items'];

    var calculated = 0;

    if (results is Map) {
      for (final raw in results.values) {
        if (_testingResultValueText(raw)
            .isNotEmpty) {
          calculated++;
        }
      }
    } else if (results is List) {
      for (final raw in results) {
        if (_testingResultValueText(raw)
            .isNotEmpty) {
          calculated++;
        }
      }
    }

    return calculated > explicit
        ? calculated
        : explicit;
  }

  int _totalResultCount(
    Map<String, dynamic> player,
  ) {
    final explicit = int.tryParse(
          _s(
            player['_testing_total_count'] ??
                player['tests_count'] ??
                player['total_tests'] ??
                player['total_count'],
          ),
        ) ??
        0;

    if (explicit > 0) return explicit;

    final tests = player['_testing_tests'];
    if (tests is List &&
        tests.isNotEmpty) {
      return tests.length;
    }

    final results =
        player['results'] ??
            player['tests'] ??
            player['matrix'] ??
            player['items'];

    if (results is Map) {
      return results.length;
    }

    if (results is List) {
      return results.length;
    }

    return 0;
  }

  String _filledResultText(
    Map<String, dynamic> player,
  ) {
    final filled = _resultCount(player);
    final total = _totalResultCount(player);

    if (total > 0) {
      return '$filled из $total заполнено';
    }

    return '$filled заполнено';
  }

  List<String> _weakResults(
    Map<String, dynamic> player,
  ) {
    final results = player['results'];
    if (results is! Map) {
      return const <String>[];
    }

    final weak = <String>[];

    results.forEach((key, raw) {
      if (raw is! Map) return;

      final rating = _s(
        raw['rating'] ??
            raw['rating_code'] ??
            raw['code'] ??
            raw['status'],
      ).toLowerCase();

      final label = _s(
        raw['rating_label'] ??
            raw['label'] ??
            raw['status_label'],
      ).toLowerCase();

      if (rating.contains('poor') ||
          rating.contains('bad') ||
          rating.contains('red') ||
          label.contains('слаб') ||
          label.contains('плохо') ||
          label.contains('неуд')) {
        final title = _s(
          raw['short_title'] ??
              raw['title'] ??
              raw['name'],
        );
        weak.add(
          title.isEmpty ? '$key' : title,
        );
      }
    });

    return weak;
  }

  List<Map<String, dynamic>> _resultRows(
    Map<String, dynamic> player,
  ) {
    final rawResults = player['results'];
    if (rawResults is! Map) {
      return <Map<String, dynamic>>[];
    }

    final testsRaw =
        player['_testing_tests'];

    final tests = testsRaw is List
        ? testsRaw
            .whereType<Map>()
            .map(
              (e) =>
                  Map<String, dynamic>.from(e),
            )
            .toList()
        : <Map<String, dynamic>>[];

    final testByCode =
        <String, Map<String, dynamic>>{};

    for (final test in tests) {
      final code = _s(
        test['code'] ??
            test['test_code'] ??
            test['id'],
      );
      if (code.isNotEmpty) {
        testByCode[code] = test;
      }
    }

    final out =
        <Map<String, dynamic>>[];

    rawResults.forEach((key, raw) {
      final code = '$key';
      final value =
          _testingResultValueText(raw);

      if (value.isEmpty) return;

      final test =
          testByCode[code] ??
              <String, dynamic>{};

      final title = _s(
        test['title'] ??
            test['name'] ??
            test['short_title'] ??
            (raw is Map
                ? raw['title'] ??
                    raw['name'] ??
                    raw['short_title']
                : null),
      );

      final unit =
          _testingResultUnit(
        raw,
        test,
      );

      final rating = raw is Map
          ? _s(
              raw['rating_label'] ??
                  raw['label'] ??
                  raw['status_label'] ??
                  raw['rating'] ??
                  raw['status'],
            )
          : '';

      out.add(
        <String, dynamic>{
          'code': code,
          'title':
              title.isEmpty ? code : title,
          'value': value,
          'unit': unit,
          'rating': rating,
        },
      );
    });

    return out;
  }

  void _openPlayer(
    Map<String, dynamic> player,
  ) {
    setState(() {
      _selectedPlayer =
          Map<String, dynamic>.from(
        player,
      );
    });
  }

  void _closePlayer() {
    setState(() {
      _selectedPlayer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedPlayer != null) {
      return _playerDetail(
        _selectedPlayer!,
      );
    }

    final title = _s(
      widget.session['title'] ??
          widget.session['name'] ??
          widget.session['session_title'],
    );

    final category = _s(
      widget.session['_category'] ??
          widget.session['category'],
    );

    final date = _s(
      widget.session['test_date'] ??
          widget.session['date'] ??
          widget.session['created_at'],
    );

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 58,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 11,
              ),
              child: Row(
                children: <Widget>[
                  Material(
                    color: _TpColors.soft,
                    borderRadius:
                        BorderRadius.circular(8),
                    child: InkWell(
                      onTap: widget.onBack,
                      borderRadius:
                          BorderRadius.circular(8),
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          Icons
                              .chevron_left_rounded,
                          size: 17,
                          color:
                              _TpColors.greenDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _TpDotCluster(
                    color: _TpColors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title.isEmpty
                              ? 'Тестирование'
                              : title,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              _TpText.title(12.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          <String>[
                            widget.teamName,
                            if (category.isNotEmpty)
                              category,
                            if (date.isNotEmpty)
                              date.length >= 10
                                  ? date.substring(0, 10)
                                  : date,
                          ].join(' · '),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: _TpText.body(
                            8.8,
                            color:
                                _TpColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TpAction(
                    title:
                        'Открыть тестирование',
                    color: _TpColors.green,
                    filled: true,
                    onTap:
                        widget.onOpenTesting,
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 1,
            color: _TpColors.line,
          ),
          Expanded(
            child: widget.loading
                ? const Center(
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          _TpColors.green,
                    ),
                  )
                : widget.error != null
                    ? _TpEmpty(
                        title:
                            'Не удалось загрузить результаты',
                        text:
                            widget.error!,
                      )
                    : widget.players.isEmpty
                        ? const _TpEmpty(
                            title:
                                'Игроков в сессии нет',
                            text:
                                'В матрице тестирования пока нет результатов игроков.',
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                              10,
                              8,
                              10,
                              18,
                            ),
                            itemCount:
                                widget.players.length,
                            separatorBuilder:
                                (_, __) =>
                                    const SizedBox(
                              height: 5,
                            ),
                            itemBuilder:
                                (context, index) {
                              final player =
                                  widget.players[index];

                              final weak =
                                  _weakResults(
                                player,
                              );

                              final color =
                                  weak.isEmpty
                                      ? _TpColors.green
                                      : weak.length >= 3
                                          ? _TpColors.red
                                          : _TpColors.amber;

                              final playerName =
                                  _playerName(
                                player,
                              );

                              final playerPhoto =
                                  _playerPhoto(
                                player,
                              );

                              final position =
                                  _playerPosition(
                                player,
                              );

                              return Material(
                                color:
                                    _TpColors.soft,
                                borderRadius:
                                    BorderRadius
                                        .circular(9),
                                child: InkWell(
                                  onTap: () =>
                                      _openPlayer(
                                    player,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(9),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets
                                            .all(10),
                                    child: Row(
                                      children: <
                                          Widget>[
                                        _TpDot(
                                          color: color,
                                          size: 5.5,
                                        ),
                                        const SizedBox(
                                          width: 8,
                                        ),
                                        _TpAvatar(
                                          photo:
                                              playerPhoto,
                                          name:
                                              playerName,
                                          size: 36,
                                        ),
                                        const SizedBox(
                                          width: 9,
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: <
                                                Widget>[
                                              Text(
                                                playerName,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                style:
                                                    _TpText
                                                        .title(
                                                  10.6,
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 2,
                                              ),
                                              Text(
                                                <String>[
                                                  if (position
                                                      .isNotEmpty)
                                                    position,
                                                  _filledResultText(
                                                    player,
                                                  ),
                                                  if (weak
                                                      .isNotEmpty)
                                                    '${weak.length} слабых · ${weak.take(2).join(', ')}',
                                                ].join(
                                                  ' · ',
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                style:
                                                    _TpText
                                                        .body(
                                                  8.7,
                                                  color:
                                                      _TpColors
                                                          .muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 7,
                                        ),
                                        Text(
                                          'Подробнее',
                                          style:
                                              _TpText.body(
                                            8.7,
                                            color:
                                                _TpColors
                                                    .greenDark,
                                            weight:
                                                FontWeight
                                                    .w600,
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 3,
                                        ),
                                        const Icon(
                                          Icons
                                              .chevron_right_rounded,
                                          size: 15,
                                          color:
                                              _TpColors
                                                  .muted2,
                                        ),
                                      ],
                                    ),
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

  Widget _playerDetail(
    Map<String, dynamic> player,
  ) {
    final playerName =
        _playerName(player);
    final playerPhoto =
        _playerPhoto(player);
    final position =
        _playerPosition(player);
    final results =
        _resultRows(player);
    final weak =
        _weakResults(player);

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 62,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 11,
              ),
              child: Row(
                children: <Widget>[
                  Material(
                    color: _TpColors.soft,
                    borderRadius:
                        BorderRadius.circular(8),
                    child: InkWell(
                      onTap: _closePlayer,
                      borderRadius:
                          BorderRadius.circular(8),
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          Icons
                              .chevron_left_rounded,
                          size: 17,
                          color:
                              _TpColors.greenDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  _TpAvatar(
                    photo: playerPhoto,
                    name: playerName,
                    size: 38,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          playerName,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              _TpText.title(11.8),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          <String>[
                            if (position.isNotEmpty)
                              position,
                            _filledResultText(
                              player,
                            ),
                          ].join(' · '),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              _TpText.body(
                            8.6,
                            color:
                                _TpColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _TpDotCluster(
                    color: _TpColors.green,
                    compact: true,
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 1,
            color: _TpColors.line,
          ),
          Expanded(
            child: results.isEmpty
                ? const _TpEmpty(
                    title:
                        'Заполненных результатов нет',
                    text:
                        'Для этого игрока в выбранной сессии значения тестов не сохранены.',
                  )
                : ListView(
                    padding:
                        const EdgeInsets.fromLTRB(
                      11,
                      10,
                      11,
                      18,
                    ),
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const _TpDotCluster(
                            color:
                                _TpColors.green,
                            compact: true,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              'Результаты игрока',
                              style:
                                  _TpText.title(
                                11.2,
                              ),
                            ),
                          ),
                          Text(
                            '${results.length}',
                            style:
                                _TpText.title(
                              10,
                            ),
                          ),
                        ],
                      ),
                      if (weak.isNotEmpty) ...<
                          Widget>[
                        const SizedBox(
                          height: 8,
                        ),
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 9,
                            vertical: 7,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                _TpColors
                                    .redSoft,
                            borderRadius:
                                BorderRadius
                                    .circular(8),
                          ),
                          child: Text(
                            '${weak.length} слабых показателей · ${weak.take(3).join(', ')}',
                            style:
                                _TpText.body(
                              8.8,
                              color:
                                  _TpColors.red,
                              weight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ...results.map(
                        (row) {
                          final value =
                              _s(row['value']);
                          final unit =
                              _s(row['unit']);
                          final rating =
                              _s(row['rating']);

                          return Container(
                            constraints:
                                const BoxConstraints(
                              minHeight: 46,
                            ),
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 9,
                              vertical: 7,
                            ),
                            decoration:
                                const BoxDecoration(
                              border: Border(
                                bottom:
                                    BorderSide(
                                  color:
                                      _TpColors
                                          .line,
                                  width: .6,
                                ),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                const _TpDot(
                                  color:
                                      _TpColors
                                          .green,
                                  size: 5,
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: <Widget>[
                                      Text(
                                        _s(
                                          row['title'],
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            _TpText
                                                .body(
                                          9.2,
                                          weight:
                                              FontWeight
                                                  .w600,
                                        ),
                                      ),
                                      if (rating
                                          .isNotEmpty) ...<
                                          Widget>[
                                        const SizedBox(
                                          height: 2,
                                        ),
                                        Text(
                                          rating,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              _TpText
                                                  .body(
                                            7.8,
                                            color:
                                                _TpColors
                                                    .muted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  unit.isEmpty
                                      ? value
                                      : '$value $unit',
                                  style:
                                      _TpText.title(
                                    10.8,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}


class _TrainerAssignTeamPanel extends StatelessWidget {
  final String trainerName;
  final List<Map<String, dynamic>> teams;
  final int selectedTeamId;
  final String selectedProfile;
  final bool saving;
  final bool Function(int teamId) isAlreadyAssigned;
  final int Function(Map<String, dynamic>) teamIdOf;
  final String Function(Map<String, dynamic>) teamNameOf;
  final String Function(Map<String, dynamic>) teamLogoOf;
  final ValueChanged<int> onTeamChanged;
  final ValueChanged<String> onProfileChanged;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const _TrainerAssignTeamPanel({
    required this.trainerName,
    required this.teams,
    required this.selectedTeamId,
    required this.selectedProfile,
    required this.saving,
    required this.isAlreadyAssigned,
    required this.teamIdOf,
    required this.teamNameOf,
    required this.teamLogoOf,
    required this.onTeamChanged,
    required this.onProfileChanged,
    required this.onClose,
    required this.onSave,
  });

  String _roleTitle(String value) {
    switch (value) {
      case 'main':
        return 'Главный тренер';
      case 'assistant':
        return 'Ассистент';
      case 'doctor':
        return 'Медик';
      case 'manager':
        return 'Администратор';
      default:
        return 'Тренер / специалист';
    }
  }

  @override
  Widget build(BuildContext context) {
    const roles = <String>[
      'main',
      'extra',
      'assistant',
      'doctor',
      'manager',
    ];

    final selectedIsAssigned =
        selectedTeamId > 0 &&
            isAlreadyAssigned(
              selectedTeamId,
            );

    return Material(
      color: Colors.white,
      child: SafeArea(
        left: false,
        child: Column(
          children: <Widget>[
            Container(
              height: 58,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              decoration:
                  const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _TpColors.line,
                    width: .65,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const _TpDotCluster(
                    color:
                        _TpColors.greenDark,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Добавить команду',
                          style:
                              _TpText.title(13.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trainerName,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: _TpText.body(
                            9,
                            color:
                                _TpColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: _TpColors.soft,
                    borderRadius:
                        BorderRadius.circular(8),
                    child: InkWell(
                      onTap:
                          saving ? null : onClose,
                      borderRadius:
                          BorderRadius.circular(8),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color:
                              _TpColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: teams.isEmpty
                  ? const _TpEmpty(
                      title:
                          'Команд клуба пока нет',
                      text:
                          'Сначала создайте команду клуба, после чего её можно будет назначить тренеру.',
                    )
                  : ListView(
                      padding:
                          const EdgeInsets.fromLTRB(
                        12,
                        12,
                        12,
                        18,
                      ),
                      children: <Widget>[
                        const _TpSectionTitle(
                          title: 'Команда',
                          color:
                              _TpColors.greenDark,
                        ),
                        const SizedBox(height: 7),
                        for (final team in teams) ...<
                            Widget>[
                          Builder(
                            builder: (context) {
                              final id =
                                  teamIdOf(team);
                              final selected =
                                  id ==
                                  selectedTeamId;
                              final assigned =
                                  isAlreadyAssigned(
                                    id,
                                  );

                              return Material(
                                color: selected
                                    ? _TpColors
                                        .greenSoft
                                    : _TpColors.soft,
                                borderRadius:
                                    BorderRadius
                                        .circular(9),
                                child: InkWell(
                                  onTap: saving
                                      ? null
                                      : () =>
                                          onTeamChanged(
                                            id,
                                          ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(9),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets
                                            .all(9),
                                    child: Row(
                                      children: <Widget>[
                                        _TpAvatar(
                                          photo:
                                              teamLogoOf(
                                            team,
                                          ),
                                          name:
                                              teamNameOf(
                                            team,
                                          ),
                                          size: 34,
                                        ),
                                        const SizedBox(
                                          width: 8,
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: <Widget>[
                                              Text(
                                                teamNameOf(
                                                  team,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                style:
                                                    _TpText
                                                        .title(
                                                  9.9,
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 2,
                                              ),
                                              Text(
                                                assigned
                                                    ? 'Уже назначена'
                                                    : 'Доступна для назначения',
                                                style:
                                                    _TpText
                                                        .body(
                                                  8.4,
                                                  color: assigned
                                                      ? _TpColors
                                                          .muted2
                                                      : _TpColors
                                                          .greenDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _TpDot(
                                          color: selected
                                              ? _TpColors
                                                  .green
                                              : assigned
                                                  ? _TpColors
                                                      .muted2
                                                  : _TpColors
                                                      .greenDark,
                                          size: selected
                                              ? 6
                                              : 4.5,
                                          opacity:
                                              assigned &&
                                                      !selected
                                                  ? .45
                                                  : 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 5),
                        ],
                        const SizedBox(height: 14),
                        const _TpSectionTitle(
                          title: 'Роль в команде',
                          color: _TpColors.amber,
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: roles.map((role) {
                            final active =
                                selectedProfile ==
                                    role;

                            return Material(
                              color: active
                                  ? _TpColors
                                      .greenSoft
                                  : _TpColors.soft,
                              borderRadius:
                                  BorderRadius
                                      .circular(8),
                              child: InkWell(
                                onTap: saving
                                    ? null
                                    : () =>
                                        onProfileChanged(
                                          role,
                                        ),
                                borderRadius:
                                    BorderRadius
                                        .circular(8),
                                child: Padding(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 9,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: <Widget>[
                                      _TpDot(
                                        color: active
                                            ? _TpColors
                                                .green
                                            : _TpColors
                                                .muted2,
                                        size: active
                                            ? 5.5
                                            : 4,
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      Text(
                                        _roleTitle(
                                          role,
                                        ),
                                        style:
                                            _TpText.body(
                                          8.8,
                                          color: active
                                              ? _TpColors
                                                  .greenDark
                                              : _TpColors
                                                  .text,
                                          weight:
                                              active
                                                  ? FontWeight
                                                      .w600
                                                  : FontWeight
                                                      .w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (selectedIsAssigned) ...<
                            Widget>[
                          const SizedBox(height: 14),
                          Container(
                            padding:
                                const EdgeInsets
                                    .all(10),
                            decoration:
                                BoxDecoration(
                              color:
                                  _TpColors.soft,
                              borderRadius:
                                  BorderRadius
                                      .circular(9),
                            ),
                            child: Text(
                              'Эта команда уже есть в назначениях тренера. Выберите другую команду.',
                              style:
                                  _TpText.body(
                                9,
                                color:
                                    _TpColors.muted,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                10,
                12,
                12,
              ),
              decoration:
                  const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: _TpColors.line,
                    width: .65,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _TpAction(
                      title: 'Закрыть',
                      color:
                          _TpColors.muted,
                      onTap:
                          saving ? () {} : onClose,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _TpAction(
                      title: saving
                          ? 'Назначение...'
                          : 'Назначить',
                      color:
                          _TpColors.green,
                      filled: true,
                      onTap: saving ||
                              selectedTeamId <= 0 ||
                              selectedIsAssigned
                          ? () {}
                          : onSave,
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

class _TrainerEditorPanel extends StatelessWidget {
  final String name;
  final String email;
  final String photo;
  final XFile? pickedPhoto;

  final TextEditingController positionC;
  final TextEditingController specializationC;
  final TextEditingController cityC;
  final TextEditingController locationsC;
  final TextEditingController birthdayC;
  final TextEditingController experienceC;
  final TextEditingController phoneC;
  final TextEditingController bioC;

  final bool saving;
  final VoidCallback onPickPhoto;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const _TrainerEditorPanel({
    required this.name,
    required this.email,
    required this.photo,
    required this.pickedPhoto,
    required this.positionC,
    required this.specializationC,
    required this.cityC,
    required this.locationsC,
    required this.birthdayC,
    required this.experienceC,
    required this.phoneC,
    required this.bioC,
    required this.saving,
    required this.onPickPhoto,
    required this.onClose,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        left: false,
        child: Column(
          children: <Widget>[
            Container(
              height: 58,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              decoration:
                  const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _TpColors.line,
                    width: .65,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const _TpDotCluster(),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Редактирование',
                          style:
                              _TpText.title(13.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: _TpText.body(
                            9,
                            color:
                                _TpColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: _TpColors.soft,
                    borderRadius:
                        BorderRadius.circular(8),
                    child: InkWell(
                      onTap:
                          saving ? null : onClose,
                      borderRadius:
                          BorderRadius.circular(8),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color:
                              _TpColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(
                  14,
                  12,
                  14,
                  18,
                ),
                children: <Widget>[
                  Center(
                    child: InkWell(
                      onTap: onPickPhoto,
                      borderRadius:
                          BorderRadius.circular(12),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          if (pickedPhoto != null)
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                              child: Image.file(
                                File(
                                  pickedPhoto!.path,
                                ),
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            _TpAvatar(
                              photo: photo,
                              name: name,
                              size: 84,
                            ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration:
                                  BoxDecoration(
                                color:
                                    _TpColors.green,
                                borderRadius:
                                    BorderRadius.circular(
                                  8,
                                ),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons
                                    .photo_camera_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TpEditorField(
                    controller: positionC,
                    label: 'Должность / роль',
                  ),
                  _TpEditorField(
                    controller: specializationC,
                    label: 'Специализация',
                  ),
                  _TpEditorField(
                    controller: cityC,
                    label: 'Город',
                  ),
                  _TpEditorField(
                    controller: locationsC,
                    label:
                        'Рабочие локации',
                    hint:
                        'Манеж, стадион, адрес...',
                  ),
                  _TpEditorField(
                    controller: birthdayC,
                    label: 'Дата рождения',
                  ),
                  _TpEditorField(
                    controller: experienceC,
                    label: 'Опыт',
                  ),
                  _TpEditorField(
                    controller: phoneC,
                    label: 'Телефон',
                  ),
                  _TpReadOnlyField(
                    label: 'Email',
                    value: email.isEmpty
                        ? 'Не указан'
                        : email,
                  ),
                  _TpEditorField(
                    controller: bioC,
                    label: 'О тренере',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Изменения сохраняются в общем профиле тренера. После сохранения тот же профиль видит клубный аккаунт.',
                    style: _TpText.body(
                      9.2,
                      color: _TpColors.muted,
                      height: 1.38,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                10,
                12,
                12,
              ),
              decoration:
                  const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: _TpColors.line,
                    width: .65,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _TpAction(
                      title: 'Закрыть',
                      color:
                          _TpColors.muted,
                      onTap: saving
                          ? () {}
                          : onClose,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _TpAction(
                      title: saving
                          ? 'Сохранение...'
                          : 'Сохранить',
                      color:
                          _TpColors.green,
                      filled: true,
                      onTap: saving
                          ? () {}
                          : onSave,
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

class _TpEditorField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  const _TpEditorField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: _TpText.body(
              9,
              color: _TpColors.muted,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: _TpText.body(10.4),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: _TpText.body(
                10,
                color:
                    _TpColors.muted2,
              ),
              filled: true,
              fillColor: _TpColors.soft,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TpReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _TpReadOnlyField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: _TpText.body(
              9,
              color: _TpColors.muted,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: _TpColors.soft,
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: _TpText.body(
                10.4,
                color: _TpColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TpEmpty extends StatelessWidget {
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onTap;

  const _TpEmpty({
    required this.title,
    required this.text,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _TpDotCluster(),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _TpText.title(11.8),
            ),
            const SizedBox(height: 5),
            Text(
              text,
              textAlign: TextAlign.center,
              style: _TpText.body(
                9.6,
                color: _TpColors.muted,
                height: 1.35,
              ),
            ),
            if (action != null &&
                onTap != null) ...<Widget>[
              const SizedBox(height: 12),
              _TpAction(
                title: action!,
                color: _TpColors.green,
                onTap: onTap!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TpPhotoDialog extends StatelessWidget {
  final String photo;
  final String name;

  const _TpPhotoDialog({
    required this.photo,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor:
          const Color(0xFF20242A),
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: <Widget>[
          Center(
            child: InteractiveViewer(
              minScale: .5,
              maxScale: 4,
              child: Image.network(photo),
            ),
          ),
          Positioned(
            top: 22,
            right: 16,
            child: IconButton(
              onPressed: () =>
                  Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
