// lib/presentation/club_workspace/cmr_club_trainers_panel.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';

class CmrClubTrainersPanel extends StatefulWidget {
  final int clubId;
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final int? selectedTeamId;
  final String selectedTeamName;
  final VoidCallback? onChanged;
  final VoidCallback? onOpenRoster;
  final VoidCallback? onOpenTeams;

  const CmrClubTrainersPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teams,
    required this.selectedTeamId,
    required this.selectedTeamName,
    this.onChanged,
    this.onOpenRoster,
    this.onOpenTeams,
  });

  @override
  State<CmrClubTrainersPanel> createState() => _CmrClubTrainersPanelState();
}

enum _CmrStaffFilter { all, main, coaches, assistants, doctors, noTeam }

class _CmrClubTrainersPanelState extends State<CmrClubTrainersPanel> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getClubTrainersUrl = '$apiBase/get_club_trainers.php';
  static const String getTeamTrainersUrl = '$apiBase/get_team_trainers.php';
  static const String searchTrainerByEmailUrl = '$apiBase/search_trainer_by_email.php';
  static const String linkTrainerToClubUrl = '$apiBase/link_trainer_to_club.php';
  static const String unlinkTrainerFromClubUrl = '$apiBase/unlink_trainer_from_club.php';
  static const String linkTrainerToTeamUrl = '$apiBase/link_trainer_to_team.php';
  static const String unlinkTrainerFromTeamUrl = '$apiBase/unlink_trainer_from_team.php';
  static const String getTrainerProfileUrl = '$apiBase/get_trainer_profile.php';
  static const String updateTrainerProfileUrl = '$apiBase/update_trainer_profile.php';
  static const String createChatUrl = '$apiBase/create_chat.php';

  final TextEditingController _searchC = TextEditingController();
  final ScrollController _listScroll = ScrollController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _selectedIndex = 0;
  _CmrStaffFilter _filter = _CmrStaffFilter.all;
  List<Map<String, dynamic>> _trainers = [];
  final Map<int, Future<Map<String, dynamic>>> _trainerProfileFutures = {};

  @override
  void initState() {
    super.initState();
    _searchC.addListener(() => setState(() {}));
    _load();
  }

  @override
  void didUpdateWidget(covariant CmrClubTrainersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clubId != widget.clubId || oldWidget.teams.length != widget.teams.length) {
      _load();
    }
  }

  @override
  void dispose() {
    _searchC.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final clubList = await _loadClubTrainers();
      final teamList = await _loadTeamTrainers();
      final merged = _mergeTrainers([...clubList, ...teamList]);
      if (!mounted) return;
      setState(() {
        _trainerProfileFutures.clear();
        _trainers = merged;
        _selectedIndex = _selectedIndex.clamp(0, math.max(0, _trainers.length - 1));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить тренеров: $e';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadClubTrainers() async {
    if (widget.clubId <= 0) return [];
    try {
      final resp = await http
          .post(Uri.parse(getClubTrainersUrl), body: {'club_id': '${widget.clubId}'})
          .timeout(const Duration(seconds: 12));
      final data = _tryDecode(resp.body);
      return _extractList(data, const ['trainers', 'coaches', 'users', 'items', 'data']);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadTeamTrainers() async {
    final result = <Map<String, dynamic>>[];
    for (final team in widget.teams) {
      final teamId = _teamId(team);
      if (teamId <= 0) continue;
      try {
        dynamic data = await _postJson(getTeamTrainersUrl, {'team_id': teamId});
        var list = _extractList(data, const ['trainers', 'coaches', 'users', 'items', 'data']);
        if (list.isEmpty) {
          data = await _postForm(getTeamTrainersUrl, {'team_id': '$teamId'});
          list = _extractList(data, const ['trainers', 'coaches', 'users', 'items', 'data']);
        }
        for (final raw in list) {
          final item = Map<String, dynamic>.from(raw);
          item['team_id'] ??= teamId;
          item['team_name'] ??= _teamName(team);
          item['team_logo'] ??= _teamLogo(team);
          result.add(item);
        }
      } catch (_) {}
    }
    return result;
  }

  List<Map<String, dynamic>> _mergeTrainers(List<Map<String, dynamic>> list) {
    final map = <String, Map<String, dynamic>>{};
    for (final raw in list) {
      final item = Map<String, dynamic>.from(raw);
      final id = _trainerId(item);
      final email = _s(item['email']).toLowerCase();
      final key = id > 0 ? 'id:$id' : email.isNotEmpty ? 'email:$email' : 'name:${_trainerName(item).toLowerCase()}';
      final existing = map[key];
      if (existing == null) {
        item['id'] = id > 0 ? id : item['id'];
        item['teams'] = _trainerTeams(item);
        map[key] = item;
      } else {
        final mergedTeams = _trainerTeams(existing);
        for (final team in _trainerTeams(item)) {
          final tid = _teamId(team);
          if (!mergedTeams.any((t) => _teamId(t) == tid && tid > 0)) mergedTeams.add(team);
        }
        existing['teams'] = mergedTeams;
        for (final e in item.entries) {
          if (_s(existing[e.key]).isEmpty && _s(e.value).isNotEmpty) existing[e.key] = e.value;
        }
      }
    }

    final out = map.values.toList();
    out.sort((a, b) {
      final mainA = _isMain(a) ? 0 : 1;
      final mainB = _isMain(b) ? 0 : 1;
      if (mainA != mainB) return mainA.compareTo(mainB);
      return _trainerName(a).toLowerCase().compareTo(_trainerName(b).toLowerCase());
    });
    return out;
  }

  List<Map<String, dynamic>> get _visibleTrainers {
    final q = _searchC.text.trim().toLowerCase();
    return _trainers.where((trainer) {
      final haystack = [
        _trainerName(trainer),
        _trainerRole(trainer),
        _trainerEmail(trainer),
        _trainerPhone(trainer),
        _trainerTeams(trainer).map(_teamName).join(' '),
      ].join(' ').toLowerCase();
      final matchesSearch = q.isEmpty || haystack.contains(q);
      if (!matchesSearch) return false;
      switch (_filter) {
        case _CmrStaffFilter.all:
          return true;
        case _CmrStaffFilter.main:
          return _isMain(trainer);
        case _CmrStaffFilter.coaches:
          return _detectGroup(trainer) == _CmrStaffFilter.coaches;
        case _CmrStaffFilter.assistants:
          return _detectGroup(trainer) == _CmrStaffFilter.assistants;
        case _CmrStaffFilter.doctors:
          return _detectGroup(trainer) == _CmrStaffFilter.doctors;
        case _CmrStaffFilter.noTeam:
          return _trainerTeams(trainer).isEmpty;
      }
    }).toList();
  }

  _CmrStaffFilter _detectGroup(Map<String, dynamic> trainer) {
    if (_isMain(trainer)) return _CmrStaffFilter.main;
    final raw = '${_trainerRole(trainer)} ${_s(trainer['staff_role'])} ${_s(trainer['role_code'])} ${_s(trainer['position_code'])}'.toLowerCase();
    if (raw.contains('мед') || raw.contains('врач') || raw.contains('doctor') || raw.contains('med')) return _CmrStaffFilter.doctors;
    if (raw.contains('ассист') || raw.contains('помощ') || raw.contains('assistant')) return _CmrStaffFilter.assistants;
    return _CmrStaffFilter.coaches;
  }

  bool _isMain(Map<String, dynamic> trainer) {
    if (_b(trainer['is_main_any']) || _b(trainer['is_main'])) return true;
    final raw = '${_s(trainer['profile'])} ${_s(trainer['link_profile'])} ${_s(trainer['role'])}'.toLowerCase();
    if (raw.contains('main') || raw.contains('head') || raw.contains('глав')) return true;
    final id = _trainerId(trainer);
    return _trainerTeams(trainer).any((team) {
      final profile = _s(team['link_profile'] ?? team['profile']).toLowerCase();
      final mainCoachId = _i(team['main_coach_id']);
      return profile == 'main' || profile == 'head' || (mainCoachId > 0 && mainCoachId == id);
    });
  }

  Future<void> _searchAndAddTrainer() async {
    final emailC = TextEditingController();
    final found = <Map<String, dynamic>>[];
    bool searching = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            Future<void> search() async {
              final email = emailC.text.trim();
              if (email.isEmpty) return;
              setSheet(() => searching = true);
              try {
                final data = await _postForm(searchTrainerByEmailUrl, {'email': email});
                final list = _extractList(data, const ['trainers', 'trainer', 'users', 'data', 'items']);
                found
                  ..clear()
                  ..addAll(list);
              } catch (_) {
                found.clear();
              }
              setSheet(() => searching = false);
            }

            Future<void> addToClub(Map<String, dynamic> trainer) async {
              final trainerId = _trainerId(trainer);
              if (trainerId <= 0) return;
              final ok = await _saveAction(() => _postForm(linkTrainerToClubUrl, {
                    'club_id': '${widget.clubId}',
                    'trainer_id': '$trainerId',
                  }));
              if (ok) {
                if (mounted) Navigator.pop(context);
                await _afterMutation('Тренер добавлен в клуб');
              }
            }

            Future<void> assignToTeam(Map<String, dynamic> trainer) async {
              final trainerId = _trainerId(trainer);
              if (trainerId <= 0) return;
              final team = await _pickTeam();
              if (team == null) return;
              final profile = await _pickProfileType();
              if (profile == null) return;
              final ok = await _linkTrainerToTeam(trainerId, _teamId(team), profile);
              if (ok) {
                if (mounted) Navigator.pop(context);
                await _afterMutation('Тренер назначен в команду');
              }
            }

            return _CmrBottomPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CmrSheetHandle(),
                  _CmrSheetTitle(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Добавить тренера',
                    subtitle: 'Найдите пользователя по email, добавьте в клуб или сразу назначьте в команду.',
                  ),
                  const SizedBox(height: 16),
                  _CmrInput(
                    controller: emailC,
                    hint: 'Email тренера',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => search(),
                    suffix: IconButton(onPressed: search, icon: const Icon(Icons.search_rounded)),
                  ),
                  const SizedBox(height: 14),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.all(22),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (found.isEmpty)
                    const _CmrNotice(
                      icon: Icons.search_rounded,
                      title: 'Введите email',
                      text: 'После поиска здесь появятся найденные пользователи с ролью тренера.',
                    )
                  else
                    ...found.map((trainer) {
                      final name = _trainerName(trainer);
                      final email = _trainerEmail(trainer);
                      final photo = _trainerPhoto(trainer);
                      return _CmrSearchTrainerTile(
                        name: name,
                        email: email,
                        photo: photo,
                        onAddClub: () => addToClub(trainer),
                        onAssignTeam: () => assignToTeam(trainer),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );

    emailC.dispose();
  }

  Future<void> _editTrainer(Map<String, dynamic> trainer) async {
    final trainerId = _trainerId(trainer);
    if (trainerId <= 0) {
      Get.snackbar('Тренер', 'Не найден ID тренера');
      return;
    }

    final positionC = TextEditingController(text: _trainerRole(trainer));
    final birthdayC = TextEditingController();
    final experienceC = TextEditingController();
    final bioC = TextEditingController();
    final picker = ImagePicker();
    XFile? pickedPhoto;
    String currentPhoto = _trainerPhoto(trainer);
    bool loadingProfile = true;
    bool savingProfile = false;

    Future<void> loadProfile(void Function(void Function()) setSheet) async {
      try {
        final data = await _postJson(getTrainerProfileUrl, {'trainer_id': trainerId});
        final p = _pickMap(data, const ['profile', 'trainer', 'user', 'data']) ?? data;
        positionC.text = _s(p['position']).isNotEmpty ? _s(p['position']) : positionC.text;
        birthdayC.text = _s(p['birthday']);
        experienceC.text = _s(p['experience']);
        bioC.text = _s(p['bio']);
        final serverPhoto = _normalizeImage(_s(p['photo'] ?? p['photo_url'] ?? p['avatar']));
        if (serverPhoto.isNotEmpty) currentPhoto = serverPhoto;
      } catch (_) {}
      setSheet(() => loadingProfile = false);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            if (loadingProfile) {
              Future.microtask(() => loadProfile(setSheet));
            }

            Future<void> pickPhoto() async {
              final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (x != null) setSheet(() => pickedPhoto = x);
            }

            Future<void> save() async {
              setSheet(() => savingProfile = true);
              try {
                http.Response resp;
                if (pickedPhoto != null) {
                  final req = http.MultipartRequest('POST', Uri.parse(updateTrainerProfileUrl));
                  req.fields['trainer_id'] = '$trainerId';
                  req.fields['position'] = positionC.text.trim();
                  req.fields['birthday'] = birthdayC.text.trim();
                  req.fields['experience'] = experienceC.text.trim();
                  req.fields['bio'] = bioC.text.trim();
                  req.files.add(await http.MultipartFile.fromPath('photo', File(pickedPhoto!.path).path));
                  final streamed = await req.send();
                  resp = http.Response(await streamed.stream.bytesToString(), streamed.statusCode);
                } else {
                  resp = await http.post(
                    Uri.parse(updateTrainerProfileUrl),
                    headers: const {'Content-Type': 'application/json; charset=utf-8'},
                    body: jsonEncode({
                      'trainer_id': trainerId,
                      'position': positionC.text.trim(),
                      'birthday': birthdayC.text.trim(),
                      'experience': experienceC.text.trim(),
                      'bio': bioC.text.trim(),
                    }),
                  );
                }
                final data = _tryDecode(resp.body);
                final ok = data is Map && (data['success'] == true || data['status'] == 'success');
                if (!ok) throw Exception(_s(data is Map ? data['message'] : ''));
                if (mounted) Navigator.pop(context);
                await _afterMutation('Профиль тренера обновлён');
              } catch (e) {
                Get.snackbar('Ошибка', 'Не удалось сохранить профиль');
              }
              if (mounted) setSheet(() => savingProfile = false);
            }

            return _CmrBottomPanel(
              maxHeightFactor: .92,
              child: loadingProfile
                  ? const Padding(
                      padding: EdgeInsets.all(38),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CmrSheetHandle(),
                        _CmrSheetTitle(
                          icon: Icons.edit_rounded,
                          title: 'Редактирование тренера',
                          subtitle: _trainerName(trainer),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: InkWell(
                            onTap: pickPhoto,
                            borderRadius: BorderRadius.circular(28),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                pickedPhoto != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(28),
                                        child: Image.file(File(pickedPhoto!.path), width: 104, height: 104, fit: BoxFit.cover),
                                      )
                                    : _CmrAvatar(photo: currentPhoto, name: _trainerName(trainer), size: 104),
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _CmrColors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                    ),
                                    child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _CmrInput(controller: positionC, hint: 'Должность / роль', icon: Icons.badge_rounded),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _CmrInput(controller: birthdayC, hint: 'Дата рождения', icon: Icons.cake_rounded)),
                            const SizedBox(width: 10),
                            Expanded(child: _CmrInput(controller: experienceC, hint: 'Опыт', icon: Icons.workspace_premium_rounded)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _CmrInput(controller: bioC, hint: 'Описание / биография', icon: Icons.notes_rounded, maxLines: 4),
                        const SizedBox(height: 16),
                        _CmrPrimaryButton(
                          icon: Icons.save_rounded,
                          title: savingProfile ? 'Сохранение...' : 'Сохранить изменения',
                          onTap: savingProfile ? null : save,
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );

    positionC.dispose();
    birthdayC.dispose();
    experienceC.dispose();
    bioC.dispose();
  }

  Future<void> _assignTrainer(Map<String, dynamic> trainer) async {
    final trainerId = _trainerId(trainer);
    if (trainerId <= 0) return;
    final team = await _pickTeam();
    if (team == null) return;
    final profile = await _pickProfileType();
    if (profile == null) return;
    final ok = await _linkTrainerToTeam(trainerId, _teamId(team), profile);
    if (ok) await _afterMutation('Тренер назначен в команду');
  }

  Future<bool> _linkTrainerToTeam(int trainerId, int teamId, String profile) async {
    if (trainerId <= 0 || teamId <= 0) return false;
    return _saveAction(() => _postJson(linkTrainerToTeamUrl, {
          'team_id': teamId,
          'trainer_id': trainerId,
          'profile': profile,
        }));
  }

  Future<void> _unlinkTrainerFromTeam(Map<String, dynamic> trainer) async {
    final trainerId = _trainerId(trainer);
    final teams = _trainerTeams(trainer);
    if (trainerId <= 0 || teams.isEmpty) {
      Get.snackbar('Команды', 'У тренера нет назначений');
      return;
    }
    final team = await _pickTeam(from: teams, title: 'Отвязать от команды');
    if (team == null) return;
    final ok = await _confirm(
      title: 'Отвязать тренера?',
      text: 'Назначение в команду «${_teamName(team)}» будет удалено.',
      danger: true,
      confirmText: 'Отвязать',
    );
    if (ok != true) return;
    final success = await _saveAction(() => _postJson(unlinkTrainerFromTeamUrl, {
          'team_id': _teamId(team),
          'trainer_id': trainerId,
        }));
    if (success) await _afterMutation('Тренер отвязан от команды');
  }

  Future<void> _removeFromClub(Map<String, dynamic> trainer) async {
    final trainerId = _trainerId(trainer);
    if (trainerId <= 0) return;
    final ok = await _confirm(
      title: 'Удалить из клуба?',
      text: 'Тренер будет удалён из списка специалистов клуба. Назначения лучше предварительно проверить.',
      confirmText: 'Удалить',
      danger: true,
    );
    if (ok != true) return;
    final success = await _saveAction(() => _postForm(unlinkTrainerFromClubUrl, {
          'club_id': '${widget.clubId}',
          'trainer_id': '$trainerId',
        }));
    if (success) await _afterMutation('Тренер удалён из клуба');
  }

  Future<bool> _saveAction(Future<dynamic> Function() request) async {
    if (!mounted) return false;
    setState(() => _saving = true);
    try {
      final data = await request();
      final ok = data is Map && (data['success'] == true || data['status'] == 'success');
      if (!ok) {
        final msg = data is Map ? _s(data['message']) : '';
        Get.snackbar('Ошибка', msg.isEmpty ? 'Операция не выполнена' : msg);
      }
      return ok;
    } catch (e) {
      Get.snackbar('Ошибка', 'Не удалось выполнить действие');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _afterMutation(String message) async {
    _trainerProfileFutures.clear();
    Get.snackbar('Готово', message);
    await _load();
    widget.onChanged?.call();
  }

  Future<Map<String, dynamic>?> _pickTeam({List<Map<String, dynamic>>? from, String title = 'Выберите команду'}) async {
    final source = from ?? widget.teams;
    if (source.isEmpty) {
      Get.snackbar('Команды', 'Сначала добавьте команду клуба');
      return null;
    }
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CmrBottomPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CmrSheetHandle(),
            _CmrSheetTitle(icon: Icons.groups_2_rounded, title: title, subtitle: 'Назначение тренера будет привязано к выбранной команде.'),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: source.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final team = source[index];
                  return _CmrTeamPickTile(
                    name: _teamName(team),
                    logo: _teamLogo(team),
                    onTap: () => Navigator.pop(context, team),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickProfileType() {
    const variants = [
      ('main', 'Главный тренер', Icons.workspace_premium_rounded),
      ('extra', 'Тренер / специалист', Icons.sports_rounded),
      ('assistant', 'Ассистент', Icons.support_agent_rounded),
      ('doctor', 'Медик', Icons.health_and_safety_rounded),
      ('manager', 'Администратор', Icons.admin_panel_settings_rounded),
    ];
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CmrBottomPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CmrSheetHandle(),
            _CmrSheetTitle(icon: Icons.badge_rounded, title: 'Роль в команде', subtitle: 'Выберите, как тренер будет отображаться в штабе команды.'),
            const SizedBox(height: 12),
            for (final item in variants)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CmrRolePickTile(
                  icon: item.$3,
                  title: item.$2,
                  onTap: () => Navigator.pop(context, item.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirm({required String title, required String text, required String confirmText, bool danger = false}) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CmrBottomPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _CmrSheetHandle(),
            _CmrRoundIcon(icon: danger ? Icons.warning_amber_rounded : Icons.verified_rounded, color: danger ? _CmrColors.red : _CmrColors.green, size: 58),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: _CmrText.title(20)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: _CmrText.body(13.5)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _CmrSecondaryButton(title: 'Отмена', onTap: () => Navigator.pop(context, false))),
                const SizedBox(width: 10),
                Expanded(child: _CmrPrimaryButton(icon: Icons.check_rounded, title: confirmText, color: danger ? _CmrColors.red : _CmrColors.green, onTap: () => Navigator.pop(context, true))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        final visible = _visibleTrainers;
        final selected = visible.isEmpty ? null : visible[_selectedIndex.clamp(0, visible.length - 1)];
        final assigned = _trainers.where((t) => _trainerTeams(t).isNotEmpty).length;
        final mainCount = _trainers.where(_isMain).length;
        final doctorsCount = _trainers.where((t) => _detectGroup(t) == _CmrStaffFilter.doctors).length;

        if (_selectedIndex >= visible.length && visible.isNotEmpty) {
          Future.microtask(() {
            if (mounted) setState(() => _selectedIndex = 0);
          });
        }

        final list = _buildListPanel(visible, assigned, mainCount, doctorsCount, compact);
        final details = _buildDetailsPanel(selected, compact);

        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_error != null) {
          return _CmrErrorState(text: _error!, onRetry: _load);
        }

        if (compact) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              SizedBox(height: 600, child: list),
              const SizedBox(height: 12),
              SizedBox(height: 620, child: details),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: math.min(450, constraints.maxWidth * .42), child: list),
            const SizedBox(width: 12),
            Expanded(child: details),
          ],
        );
      },
    );
  }


  Future<Map<String, dynamic>> _loadTrainerProfileForCard(Map<String, dynamic> trainer) {
    final trainerId = _trainerId(trainer);
    if (trainerId <= 0) return Future.value(trainer);

    return _trainerProfileFutures.putIfAbsent(trainerId, () async {
      try {
        final data = await _postJson(getTrainerProfileUrl, {'trainer_id': trainerId});
        final raw = _pickMap(data, const ['profile', 'trainer', 'user', 'data']) ?? data;
        final merged = <String, dynamic>{...trainer};

        if (raw is Map) {
          raw.forEach((key, value) {
            if (value != null && value.toString().trim().isNotEmpty) {
              merged[key.toString()] = value;
            }
          });
        }

        if (!_hasUsefulTeams(merged) && _hasUsefulTeams(trainer)) {
          merged['teams'] = trainer['teams'];
          merged['team_id'] = trainer['team_id'];
          merged['team_name'] = trainer['team_name'];
        }

        return merged;
      } catch (_) {
        return trainer;
      }
    });
  }

  bool _hasUsefulTeams(Map<String, dynamic> trainer) {
    final teams = trainer['teams'];
    if (teams is List && teams.isNotEmpty) return true;
    return _i(trainer['team_id'] ?? trainer['teamId']) > 0 || _s(trainer['team_name'] ?? trainer['teamName']).isNotEmpty;
  }

  Future<void> _messageTrainer(Map<String, dynamic> trainer) async {
    final peerId = _trainerId(trainer);
    if (peerId <= 0) {
      Get.snackbar('Чат', 'Не найден ID тренера');
      return;
    }

    final currentUserId = await PrefUtils.getUserId() ?? 0;
    if (currentUserId <= 0) {
      Get.snackbar('Чат', 'Не найден текущий пользователь');
      return;
    }

    if (currentUserId == peerId) {
      Get.snackbar('Чат', 'Это ваш профиль тренера');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(createChatUrl),
        body: {
          'type': 'private',
          'user_id': currentUserId.toString(),
          'peer_id': peerId.toString(),
        },
      );

      final data = _tryDecode(response.body);
      final ok = response.statusCode == 200 && data is Map && data['success'] == true;

      if (!ok) {
        final msg = data is Map ? _s(data['error'] ?? data['message']) : '';
        Get.snackbar('Чат', msg.isEmpty ? 'Не удалось открыть чат' : msg);
        return;
      }

      final chatId = _i(data['chat_id'] ?? data['id']);
      if (chatId <= 0) {
        Get.snackbar('Чат', 'Сервер не вернул ID чата');
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            chatId: chatId,
            userId: currentUserId,
            chatName: _trainerName(trainer),
          ),
        ),
      );
    } catch (e) {
      Get.snackbar('Чат', 'Ошибка открытия чата');
    }
  }

  Widget _buildListPanel(List<Map<String, dynamic>> visible, int assigned, int mainCount, int doctorsCount, bool compact) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: _CmrDecor.card(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CmrRoundIcon(icon: Icons.badge_rounded, color: _CmrColors.black, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CMR тренеров', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(18)),
                    const SizedBox(height: 4),
                    Text('${widget.clubName} · ${_trainers.length} специалистов', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.body(12)),
                  ],
                ),
              ),
              _CmrHelpButton(
                title: 'Как работать с тренерами',
                text: 'Это единая рабочая панель: добавление, редактирование, назначение к команде и просмотр карточки тренера без перехода на старые экраны.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _CmrPrimaryButton(icon: Icons.person_add_alt_1_rounded, title: 'Добавить', onTap: _saving ? null : _searchAndAddTrainer)),
              const SizedBox(width: 10),
              Expanded(child: _CmrSecondaryButton(icon: Icons.add_link_rounded, title: 'Назначить', onTap: _saving || _trainers.isEmpty ? null : () => _assignTrainer(_visibleTrainers.isEmpty ? _trainers.first : _visibleTrainers[_selectedIndex.clamp(0, _visibleTrainers.length - 1)]))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _CmrStatCard(value: '${_trainers.length}', label: 'в клубе', icon: Icons.groups_2_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _CmrStatCard(value: '$assigned', label: 'назначены', icon: Icons.link_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _CmrStatCard(value: '$mainCount', label: 'главные', icon: Icons.workspace_premium_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _CmrStatCard(value: '$doctorsCount', label: 'медики', icon: Icons.health_and_safety_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          _CmrInput(controller: _searchC, hint: 'Поиск по ФИО, роли, команде, email', icon: Icons.search_rounded),
          const SizedBox(height: 10),
          _buildFilters(),
          const SizedBox(height: 12),
          Expanded(
            child: visible.isEmpty
                ? _CmrEmptyState(
                    title: _trainers.isEmpty ? 'Тренеры пока не добавлены' : 'Ничего не найдено',
                    text: _trainers.isEmpty ? 'Добавьте тренера по email или назначьте специалиста в команду.' : 'Измените поиск или фильтр.',
                    buttonText: 'Добавить тренера',
                    onTap: _searchAndAddTrainer,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _CmrColors.green,
                    child: ListView.separated(
                      controller: _listScroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final trainer = visible[index];
                        return _CmrTrainerTile(
                          active: index == _selectedIndex,
                          name: _trainerName(trainer),
                          role: _trainerRole(trainer),
                          team: _teamsText(trainer),
                          photo: _trainerPhoto(trainer),
                          main: _isMain(trainer),
                          onTap: () => setState(() => _selectedIndex = index),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel(Map<String, dynamic>? trainer, bool compact) {
    if (trainer == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: _CmrDecor.card(radius: 30),
        child: _CmrEmptyState(
          title: 'Выберите тренера',
          text: 'Подробная карточка, редактирование, назначения и чат появятся справа.',
          buttonText: 'Добавить тренера',
          onTap: _searchAndAddTrainer,
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadTrainerProfileForCard(trainer),
      initialData: trainer,
      builder: (context, snapshot) {
        final t = snapshot.data ?? trainer;
        final name = _trainerName(t);
        final role = _trainerRole(t);
        final teams = _trainerTeams(t);
        final phone = _trainerPhone(t);
        final email = _trainerEmail(t);
        final birthday = _trainerBirthday(t);
        final experience = _trainerExperience(t);
        final city = _trainerCity(t);
        final specialization = _trainerSpecialization(t);
        final bio = _trainerBio(t);

        return Container(
          padding: EdgeInsets.all(compact ? 14 : 18),
          decoration: _CmrDecor.card(radius: 30),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CmrAvatar(photo: _trainerPhoto(t), name: name, size: compact ? 82 : 104),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.title(compact ? 20 : 24)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _CmrChip(text: role, icon: Icons.badge_rounded),
                              _CmrChip(
                                text: _isMain(t) ? 'Главный' : 'Специалист',
                                icon: Icons.verified_rounded,
                                color: _isMain(t) ? _CmrColors.green : _CmrColors.muted,
                              ),
                              _CmrChip(text: teams.isEmpty ? 'Без команды' : '${teams.length} команд', icon: Icons.groups_2_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Действия',
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      onSelected: (value) {
                        if (value == 'message') _messageTrainer(t);
                        if (value == 'edit') _editTrainer(t);
                        if (value == 'assign') _assignTrainer(t);
                        if (value == 'unlink_team') _unlinkTrainerFromTeam(t);
                        if (value == 'remove_club') _removeFromClub(t);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'message', child: Text('Написать тренеру')),
                        PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                        PopupMenuItem(value: 'assign', child: Text('Назначить в команду')),
                        PopupMenuItem(value: 'unlink_team', child: Text('Отвязать от команды')),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'remove_club', child: Text('Удалить из клуба')),
                      ],
                      child: const _CmrRoundIcon(icon: Icons.more_horiz_rounded, color: _CmrColors.black, size: 42),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _CmrPrimaryButton(icon: Icons.chat_bubble_rounded, title: 'Написать', onTap: _saving ? null : () => _messageTrainer(t))),
                    const SizedBox(width: 10),
                    Expanded(child: _CmrSecondaryButton(icon: Icons.edit_rounded, title: 'Редактировать', onTap: _saving ? null : () => _editTrainer(t))),
                  ],
                ),
                const SizedBox(height: 10),
                _CmrSecondaryButton(icon: Icons.add_link_rounded, title: 'Назначить в команду', onTap: _saving ? null : () => _assignTrainer(t)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _CmrInfoCard(icon: Icons.badge_rounded, label: 'Должность', value: role, maxLines: 2)),
                    const SizedBox(width: 10),
                    Expanded(child: _CmrInfoCard(icon: Icons.groups_2_rounded, label: 'Команды', value: teams.isEmpty ? 'Не назначен' : '${teams.length}', maxLines: 2)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _CmrInfoCard(icon: Icons.workspace_premium_rounded, label: 'Опыт', value: experience.isEmpty ? 'Не указан' : experience, maxLines: 2)),
                    const SizedBox(width: 10),
                    Expanded(child: _CmrInfoCard(icon: Icons.cake_rounded, label: 'Дата рождения', value: birthday.isEmpty ? 'Не указана' : birthday, maxLines: 2)),
                  ],
                ),
                const SizedBox(height: 10),
                if (city.isNotEmpty || specialization.isNotEmpty)
                  Row(
                    children: [
                      Expanded(child: _CmrInfoCard(icon: Icons.location_city_rounded, label: 'Город', value: city.isEmpty ? 'Не указан' : city, maxLines: 2)),
                      const SizedBox(width: 10),
                      Expanded(child: _CmrInfoCard(icon: Icons.sports_soccer_rounded, label: 'Специализация', value: specialization.isEmpty ? 'Не указана' : specialization, maxLines: 2)),
                    ],
                  ),
                if (city.isNotEmpty || specialization.isNotEmpty) const SizedBox(height: 10),
                _CmrContactRow(icon: Icons.phone_rounded, label: 'Телефон', value: phone.isEmpty ? 'Не указан' : phone),
                const SizedBox(height: 8),
                _CmrContactRow(icon: Icons.mail_rounded, label: 'Email', value: email.isEmpty ? 'Не указан' : email),
                const SizedBox(height: 14),
                _CmrProfileBlock(
                  icon: Icons.notes_rounded,
                  title: 'О тренере',
                  text: bio.isEmpty ? 'Описание пока не заполнено. Нажмите «Редактировать», чтобы добавить биографию, опыт и специализацию.' : bio,
                ),
                const SizedBox(height: 14),
                _CmrNotice(
                  icon: Icons.tips_and_updates_rounded,
                  title: 'Рабочая подсказка',
                  text: 'Карточка тренера заполняется один раз и дальше используется в назначениях, командах и коммуникации клуба.',
                ),
                const SizedBox(height: 14),
                Text('Назначения к командам', style: _CmrText.title(16)),
                const SizedBox(height: 10),
                teams.isEmpty
                    ? _CmrEmptyMini(text: 'Тренер пока не назначен ни в одну команду.')
                    : ListView.separated(
                        itemCount: teams.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final team = teams[index];
                          final profile = _profileTitle(_s(team['link_profile'] ?? team['profile']));
                          return _CmrAssignedTeamTile(
                            name: _teamName(team),
                            logo: _teamLogo(team),
                            profile: profile,
                            main: profile == 'Главный тренер',
                          );
                        },
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    final items = [
      (_CmrStaffFilter.all, 'Все'),
      (_CmrStaffFilter.main, 'Главные'),
      (_CmrStaffFilter.coaches, 'Тренеры'),
      (_CmrStaffFilter.assistants, 'Ассистенты'),
      (_CmrStaffFilter.doctors, 'Медики'),
      (_CmrStaffFilter.noTeam, 'Без команды'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final active = _filter == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() {
                _filter = item.$1;
                _selectedIndex = 0;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _CmrColors.greenSoft : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? _CmrColors.green.withOpacity(.35) : _CmrColors.border),
                ),
                child: Text(item.$2, style: TextStyle(color: active ? _CmrColors.greenDark : _CmrColors.muted, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _teamsText(Map<String, dynamic> trainer) {
    final teams = _trainerTeams(trainer);
    if (teams.isEmpty) return 'Команда не назначена';
    if (teams.length == 1) return _teamName(teams.first);
    return '${_teamName(teams.first)} +${teams.length - 1}';
  }

  String _profileTitle(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'main' || v == 'head' || v.contains('глав')) return 'Главный тренер';
    if (v.contains('assistant') || v.contains('ассист')) return 'Ассистент';
    if (v.contains('doctor') || v.contains('med') || v.contains('мед')) return 'Медик';
    if (v.contains('manager') || v.contains('admin')) return 'Администратор';
    return 'Тренер';
  }

  int _trainerId(Map<String, dynamic> t) => _i(t['id'] ?? t['trainer_id'] ?? t['trainerId'] ?? t['user_id'] ?? t['userId'] ?? t['coach_id']);
  String _trainerName(Map<String, dynamic> t) {
    final full = _s(t['full_name'] ?? t['fullName'] ?? t['name']);
    if (full.isNotEmpty) return full;
    final name = '${_s(t['first_name'])} ${_s(t['last_name'])}'.trim();
    return name.isEmpty ? 'Тренер' : name;
  }

  String _trainerRole(Map<String, dynamic> t) {
    final raw = _s(t['position'] ?? t['role_title'] ?? t['specialization'] ?? t['staff_role'] ?? t['role'] ?? t['profile']);
    if (raw.isEmpty || raw == 'extra') return 'Тренер';
    if (raw == 'main') return 'Главный тренер';
    if (raw == 'doctor') return 'Медик';
    if (raw == 'assistant') return 'Ассистент';
    return raw;
  }

  String _trainerEmail(Map<String, dynamic> t) => _s(t['email']);
  String _trainerPhone(Map<String, dynamic> t) => _s(t['phone'] ?? t['telephone'] ?? t['phone_number'] ?? t['mobile']);
  String _trainerBirthday(Map<String, dynamic> t) => _s(t['birthday'] ?? t['birth_date'] ?? t['date_birth'] ?? t['dob']);
  String _trainerExperience(Map<String, dynamic> t) => _s(t['experience'] ?? t['experience_text'] ?? t['work_experience']);
  String _trainerBio(Map<String, dynamic> t) => _s(t['bio'] ?? t['description'] ?? t['about'] ?? t['about_me']);
  String _trainerCity(Map<String, dynamic> t) => _s(t['city'] ?? t['town']);
  String _trainerSpecialization(Map<String, dynamic> t) => _s(t['specialization'] ?? t['speciality'] ?? t['category']);

  String _trainerPhoto(Map<String, dynamic> t) => _normalizeImage(_s(t['photo'] ?? t['avatar'] ?? t['image'] ?? t['photo_url'] ?? t['avatar_url']));

  List<Map<String, dynamic>> _trainerTeams(Map<String, dynamic> t) {
    final rawTeams = t['teams'];
    if (rawTeams is List) return rawTeams.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final teamId = _i(t['team_id'] ?? t['teamId']);
    final teamName = _s(t['team_name'] ?? t['teamName']);
    if (teamId > 0 || teamName.isNotEmpty) {
      return [
        {
          'team_id': teamId,
          'team_name': teamName.isEmpty ? 'Команда #$teamId' : teamName,
          'team_logo': t['team_logo'] ?? t['teamLogo'],
          'link_profile': t['link_profile'] ?? t['profile'],
          'main_coach_id': t['main_coach_id'],
        }
      ];
    }
    return [];
  }

  int _teamId(Map<String, dynamic> team) => _i(team['id'] ?? team['team_id'] ?? team['teamId']);
  String _teamName(Map<String, dynamic> team) => _s(team['name'] ?? team['team_name'] ?? team['title']).isEmpty ? 'Команда' : _s(team['name'] ?? team['team_name'] ?? team['title']);
  String _teamLogo(Map<String, dynamic> team) => _normalizeImage(_s(team['logo_url'] ?? team['logo'] ?? team['team_logo'] ?? team['photo']));

  Future<Map<String, dynamic>> _postForm(String url, Map<String, String> body) async {
    final resp = await http.post(Uri.parse(url), body: body).timeout(const Duration(seconds: 16));
    final data = _tryDecode(resp.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'success': false, 'message': 'Некорректный ответ сервера'};
  }

  Future<Map<String, dynamic>> _postJson(String url, Map<String, dynamic> body) async {
    final resp = await http
        .post(Uri.parse(url), headers: const {'Content-Type': 'application/json; charset=utf-8'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 16));
    final data = _tryDecode(resp.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'success': false, 'message': 'Некорректный ответ сервера'};
  }

  dynamic _tryDecode(String body) {
    try {
      final start = body.indexOf('{');
      final arrayStart = body.indexOf('[');
      final cut = start >= 0 && (arrayStart < 0 || start < arrayStart) ? body.substring(start) : arrayStart >= 0 ? body.substring(arrayStart) : body;
      return jsonDecode(cut);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic data, List<String> keys) {
    if (data is List) return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map) {
      for (final key in keys) {
        final value = data[key];
        if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (value is Map && (key == 'trainer' || key == 'user')) return [Map<String, dynamic>.from(value)];
      }
      for (final key in keys) {
        final nested = data[key];
        if (nested is Map) {
          final list = _extractList(nested, keys);
          if (list.isNotEmpty) return list;
        }
      }
    }
    return [];
  }

  Map<String, dynamic>? _pickMap(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String _normalizeImage(String raw) {
    final url = raw.trim();
    if (url.isEmpty || url == 'null') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('www.sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('/')) return 'https://sportotekaapp.ru$url';
    if (url.startsWith('uploads/')) return 'https://sportotekaapp.ru/$url';
    return 'https://sportotekaapp.ru/uploads/$url';
  }

  String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  int _i(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  bool _b(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = _s(value).toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
}

class _CmrColors {
  static const Color bg = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color border = Color(0xFFE5E7EB);
  static const Color black = Color(0xFF111827);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF047044);
  static const Color greenSoft = Color(0xFFEAFBF2);
  static const Color red = Color(0xFFDC2626);
}

class _CmrText {
  static TextStyle title(double size) => TextStyle(color: _CmrColors.text, fontSize: size, fontWeight: FontWeight.w900, height: 1.08);
  static TextStyle body(double size) => TextStyle(color: _CmrColors.muted, fontSize: size, fontWeight: FontWeight.w700, height: 1.25);
}

class _CmrDecor {
  static BoxDecoration card({double radius = 24}) => BoxDecoration(
        color: _CmrColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _CmrColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 18, offset: const Offset(0, 8))],
      );
}

class _CmrAvatar extends StatelessWidget {
  final String photo;
  final String name;
  final double size;
  const _CmrAvatar({required this.photo, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? 'Т'
        : name.trim().split(RegExp(r'\s+')).take(2).map((e) => e.isEmpty ? '' : e[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _CmrColors.greenSoft, borderRadius: BorderRadius.circular(size * .27), border: Border.all(color: _CmrColors.border)),
      clipBehavior: Clip.antiAlias,
      child: photo.isEmpty
          ? Center(child: Text(initials, style: TextStyle(color: _CmrColors.greenDark, fontSize: size * .28, fontWeight: FontWeight.w900)))
          : Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(initials, style: TextStyle(color: _CmrColors.greenDark, fontSize: size * .28, fontWeight: FontWeight.w900)))),
    );
  }
}

class _CmrRoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _CmrRoundIcon({required this.icon, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color == _CmrColors.green ? _CmrColors.greenSoft : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(size * .35)),
      child: Icon(icon, color: color, size: size * .48),
    );
  }
}

class _CmrPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color color;
  const _CmrPrimaryButton({required this.icon, required this.title, required this.onTap, this.color = _CmrColors.green});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .55 : 1,
        child: Container(
          height: 48,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(17), boxShadow: [BoxShadow(color: color.withOpacity(.18), blurRadius: 18, offset: const Offset(0, 8))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 19), const SizedBox(width: 8), Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)))]),
        ),
      ),
    );
  }
}

class _CmrSecondaryButton extends StatelessWidget {
  final IconData? icon;
  final String title;
  final VoidCallback? onTap;
  const _CmrSecondaryButton({this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .55 : 1,
        child: Container(
          height: 48,
          decoration: BoxDecoration(color: _CmrColors.bg, borderRadius: BorderRadius.circular(17), border: Border.all(color: _CmrColors.border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (icon != null) ...[Icon(icon, color: _CmrColors.text, size: 19), const SizedBox(width: 8)], Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _CmrColors.text, fontSize: 12.5, fontWeight: FontWeight.w900)))]),
        ),
      ),
    );
  }
}

class _CmrInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  const _CmrInput({required this.controller, required this.hint, required this.icon, this.maxLines = 1, this.suffix, this.keyboardType, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: _CmrColors.text, fontSize: 13, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _CmrColors.muted, fontSize: 12.5, fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, color: _CmrColors.muted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _CmrColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: _CmrColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: _CmrColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: _CmrColors.green, width: 1.2)),
      ),
    );
  }
}

class _CmrStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _CmrStatCard({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _CmrColors.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _CmrColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _CmrColors.greenDark, size: 17), const SizedBox(height: 6), Text(value, style: _CmrText.title(15)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.body(10))]),
    );
  }
}

class _CmrTrainerTile extends StatelessWidget {
  final bool active;
  final String name;
  final String role;
  final String team;
  final String photo;
  final bool main;
  final VoidCallback onTap;
  const _CmrTrainerTile({required this.active, required this.name, required this.role, required this.team, required this.photo, required this.main, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? _CmrColors.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? _CmrColors.green.withOpacity(.35) : _CmrColors.border),
        ),
        child: Row(children: [
          _CmrAvatar(photo: photo, name: name, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(14.5))), if (main) const Icon(Icons.workspace_premium_rounded, color: _CmrColors.greenDark, size: 17)]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [_CmrChip(text: role, dense: true), _CmrChip(text: team, dense: true, icon: Icons.groups_2_rounded)]),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(active ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: active ? _CmrColors.green : _CmrColors.muted, size: 22),
        ]),
      ),
    );
  }
}

class _CmrChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final bool dense;
  const _CmrChip({required this.text, this.icon, this.color = _CmrColors.text, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: dense ? 170 : 210),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 5 : 7),
        decoration: BoxDecoration(
          color: _CmrColors.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _CmrColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 13 : 15, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: dense ? 10.5 : 11.5, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CmrInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;
  const _CmrInfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CmrColors.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _CmrColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _CmrColors.greenDark, size: 18),
          const SizedBox(height: 7),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.body(10.5)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: _CmrText.title(13),
          ),
        ],
      ),
    );
  }
}

class _CmrProfileBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _CmrProfileBlock({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _CmrColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _CmrColors.greenDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _CmrText.title(13.5)),
                const SizedBox(height: 5),
                Text(text, style: _CmrText.body(12.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CmrContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _CmrContactRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _CmrColors.border)),
      child: Row(children: [Icon(icon, color: _CmrColors.muted, size: 20), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: _CmrText.body(10.5)), const SizedBox(height: 2), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(13))]))]),
    );
  }
}

class _CmrNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _CmrNotice({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: _CmrColors.greenSoft, borderRadius: BorderRadius.circular(20), border: Border.all(color: _CmrColors.green.withOpacity(.12))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _CmrColors.greenDark, size: 20), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _CmrText.title(13.5)), const SizedBox(height: 3), Text(text, style: _CmrText.body(12))]))]),
    );
  }
}

class _CmrAssignedTeamTile extends StatelessWidget {
  final String name;
  final String logo;
  final String profile;
  final bool main;
  const _CmrAssignedTeamTile({required this.name, required this.logo, required this.profile, required this.main});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: main ? _CmrColors.greenSoft : _CmrColors.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: main ? _CmrColors.green.withOpacity(.2) : _CmrColors.border)),
      child: Row(children: [_CmrAvatar(photo: logo, name: name, size: 42), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.5)), const SizedBox(height: 3), Text(profile, style: _CmrText.body(11.5))])), if (main) const Icon(Icons.workspace_premium_rounded, color: _CmrColors.greenDark, size: 19)]),
    );
  }
}

class _CmrEmptyState extends StatelessWidget {
  final String title;
  final String text;
  final String buttonText;
  final VoidCallback onTap;
  const _CmrEmptyState({required this.title, required this.text, required this.buttonText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [const _CmrRoundIcon(icon: Icons.badge_rounded, color: _CmrColors.black, size: 58), const SizedBox(height: 12), Text(title, textAlign: TextAlign.center, style: _CmrText.title(16)), const SizedBox(height: 6), Text(text, textAlign: TextAlign.center, style: _CmrText.body(12.5)), const SizedBox(height: 14), SizedBox(width: 190, child: _CmrPrimaryButton(icon: Icons.person_add_alt_1_rounded, title: buttonText, onTap: onTap))]),
    );
  }
}

class _CmrEmptyMini extends StatelessWidget {
  final String text;
  const _CmrEmptyMini({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text, textAlign: TextAlign.center, style: _CmrText.body(13)));
  }
}

class _CmrErrorState extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _CmrErrorState({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Container(padding: const EdgeInsets.all(22), decoration: _CmrDecor.card(), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, color: _CmrColors.red, size: 42), const SizedBox(height: 10), Text(text, textAlign: TextAlign.center, style: _CmrText.body(13)), const SizedBox(height: 14), SizedBox(width: 160, child: _CmrPrimaryButton(icon: Icons.refresh_rounded, title: 'Повторить', onTap: onRetry))])));
  }
}

class _CmrHelpButton extends StatelessWidget {
  final String title;
  final String text;
  const _CmrHelpButton({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _CmrBottomPanel(child: Column(mainAxisSize: MainAxisSize.min, children: [const _CmrSheetHandle(), const _CmrRoundIcon(icon: Icons.help_outline_rounded, color: _CmrColors.green, size: 58), const SizedBox(height: 14), Text(title, style: _CmrText.title(20)), const SizedBox(height: 8), Text(text, textAlign: TextAlign.center, style: _CmrText.body(13.5))])),
      ),
      child: const _CmrRoundIcon(icon: Icons.help_outline_rounded, color: _CmrColors.black, size: 42),
    );
  }
}

class _CmrBottomPanel extends StatelessWidget {
  final Widget child;
  final double maxHeightFactor;
  const _CmrBottomPanel({required this.child, this.maxHeightFactor = .86});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final h = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: h * maxHeightFactor),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 30, offset: const Offset(0, 15))]),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _CmrSheetHandle extends StatelessWidget {
  const _CmrSheetHandle();
  @override
  Widget build(BuildContext context) => Center(child: Container(width: 42, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFD0D5DD), borderRadius: BorderRadius.circular(99))));
}

class _CmrSheetTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _CmrSheetTitle({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Row(children: [_CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 50), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _CmrText.title(20)), const SizedBox(height: 4), Text(subtitle, style: _CmrText.body(12.5))]))]);
}

class _CmrSearchTrainerTile extends StatelessWidget {
  final String name;
  final String email;
  final String photo;
  final VoidCallback onAddClub;
  final VoidCallback onAssignTeam;
  const _CmrSearchTrainerTile({required this.name, required this.email, required this.photo, required this.onAddClub, required this.onAssignTeam});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _CmrColors.bg, borderRadius: BorderRadius.circular(22), border: Border.all(color: _CmrColors.border)),
      child: Column(children: [Row(children: [_CmrAvatar(photo: photo, name: name, size: 48), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(14)), Text(email.isEmpty ? 'Email не указан' : email, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.body(11.5))]))]), const SizedBox(height: 10), Row(children: [Expanded(child: _CmrSecondaryButton(icon: Icons.group_add_rounded, title: 'В клуб', onTap: onAddClub)), const SizedBox(width: 8), Expanded(child: _CmrPrimaryButton(icon: Icons.add_link_rounded, title: 'В команду', onTap: onAssignTeam))])]),
    );
  }
}

class _CmrTeamPickTile extends StatelessWidget {
  final String name;
  final String logo;
  final VoidCallback onTap;
  const _CmrTeamPickTile({required this.name, required this.logo, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _CmrColors.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _CmrColors.border)), child: Row(children: [_CmrAvatar(photo: logo, name: name, size: 42), const SizedBox(width: 10), Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(14))), const Icon(Icons.chevron_right_rounded, color: _CmrColors.muted)])));
}

class _CmrRolePickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _CmrRolePickTile({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: _CmrColors.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _CmrColors.border)), child: Row(children: [Icon(icon, color: _CmrColors.greenDark), const SizedBox(width: 10), Expanded(child: Text(title, style: _CmrText.title(14))), const Icon(Icons.check_circle_outline_rounded, color: _CmrColors.muted)])));
}
