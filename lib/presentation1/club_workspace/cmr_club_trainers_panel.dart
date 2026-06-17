// lib/presentation/club_workspace/cmr_club_trainers_panel.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';

// ==================== Глобальные вспомогательные функции ====================

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

String _trainerPhoto(Map<String, dynamic> t) => _normalizeImage(_s(t['photo'] ?? t['avatar'] ?? t['image'] ?? t['photo_url'] ?? t['avatar_url']));

bool _isMain(Map<String, dynamic> trainer) {
  if (_b(trainer['is_main_any']) || _b(trainer['is_main'])) return true;
  final raw = '${_s(trainer['profile'])} ${_s(trainer['link_profile'])} ${_s(trainer['role'])}'.toLowerCase();
  if (raw.contains('main') || raw.contains('head') || raw.contains('глав')) return true;
  return false;
}

String _trainerEmail(Map<String, dynamic> t) => _s(t['email']);
String _trainerPhone(Map<String, dynamic> t) => _s(t['phone'] ?? t['telephone'] ?? t['phone_number'] ?? t['mobile']);
String _trainerBirthday(Map<String, dynamic> t) => _s(t['birthday'] ?? t['birth_date'] ?? t['date_birth'] ?? t['dob']);
String _trainerExperience(Map<String, dynamic> t) => _s(t['experience'] ?? t['experience_text'] ?? t['work_experience']);
String _trainerBio(Map<String, dynamic> t) => _s(t['bio'] ?? t['description'] ?? t['about'] ?? t['about_me']);
String _trainerCity(Map<String, dynamic> t) => _s(t['city'] ?? t['town']);
String _trainerSpecialization(Map<String, dynamic> t) => _s(t['specialization'] ?? t['speciality'] ?? t['category']);

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

String _teamName(Map<String, dynamic> team) => _s(team['name'] ?? team['team_name'] ?? team['title']).isEmpty ? 'Команда' : _s(team['name'] ?? team['team_name'] ?? team['title']);
String _teamLogo(Map<String, dynamic> team) => _normalizeImage(_s(team['logo_url'] ?? team['logo'] ?? team['team_logo'] ?? team['photo']));

String _profileTitle(String raw) {
  final v = raw.trim().toLowerCase();
  if (v == 'main' || v == 'head' || v.contains('глав')) return 'Главный тренер';
  if (v.contains('assistant') || v.contains('ассист')) return 'Ассистент';
  if (v.contains('doctor') || v.contains('med') || v.contains('мед')) return 'Медик';
  if (v.contains('manager') || v.contains('admin')) return 'Администратор';
  return 'Тренер';
}

String _teamsText(Map<String, dynamic> trainer) {
  final teams = _trainerTeams(trainer);
  if (teams.isEmpty) return 'Команда не назначена';
  if (teams.length == 1) return _teamName(teams.first);
  return '${_teamName(teams.first)} +${teams.length - 1}';
}

// ==================== Цветовая схема ====================

class _CmrColors {
  static const Color bg = Color(0xFFF5F6F7);
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF8F9FA);
  static const Color soft2 = Color(0xFFF1F3F5);
  static const Color active = Colors.white;

  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF374151);
  static const Color muted2 = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color graphite = Color(0xFF111827);
  static const Color graphite2 = Color(0xFF1F2937);

  // Фирменный цвет — только как тонкий премиальный акцент.
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color greenSoft2 = Color(0xFFF8FEFA);
  static const Color greenBorder = Color(0xFFD7F0E2);

  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F1);
  static const Color redBorder = Color(0xFFFEE4E2);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFF7E8);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
}

// ==================== Текстовые стили ====================

class _CmrText {
  static const String family = 'Roboto';

  static TextStyle title(double size) => TextStyle(
        color: _CmrColors.text,
        fontFamily: family,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.08,
        letterSpacing: -.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle section() => const TextStyle(
        color: _CmrColors.text,
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        height: 1.16,
        letterSpacing: -.1,
      );

  static TextStyle value(double size) => TextStyle(
        color: _CmrColors.text,
        fontFamily: family,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.22,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle muted(double size) => TextStyle(
        color: _CmrColors.muted,
        fontFamily: family,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.32,
      );

  static TextStyle caption() => const TextStyle(
        color: _CmrColors.muted2,
        fontFamily: family,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        height: 1.12,
        letterSpacing: .1,
      );

  static TextStyle pill() => const TextStyle(
        color: _CmrColors.text,
        fontFamily: family,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      );

  static TextStyle tab() => const TextStyle(
        color: _CmrColors.text,
        fontFamily: family,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      );

  static TextStyle tabSelected() => const TextStyle(
        color: _CmrColors.text,
        fontFamily: family,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      );

  static TextStyle action() => const TextStyle(
        color: _CmrColors.text,
        fontFamily: family,
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
      );

  static TextStyle danger() => const TextStyle(
        color: _CmrColors.red,
        fontFamily: family,
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
      );
}

// ==================== Декораторы ====================

class _CmrDecor {
  static double _hardRadius(double radius, {double max = 16}) => math.min(radius, max);

  static BoxDecoration panel({double radius = 16}) => BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(_hardRadius(radius, max: 16)),
        border: Border.all(color: _CmrColors.line, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration softCard({double radius = 14, bool active = false}) => BoxDecoration(
        color: active ? _CmrColors.panel : _CmrColors.soft,
        borderRadius: BorderRadius.circular(_hardRadius(radius, max: 16)),
        border: Border.all(
          color: active ? _CmrColors.green.withOpacity(.42) : _CmrColors.line,
          width: active ? 1.2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(.04),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      );

  static BoxDecoration greenCard({double radius = 14}) => BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(_hardRadius(radius, max: 16)),
        border: Border.all(color: _CmrColors.green.withOpacity(.30), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      );
}

// ==================== Диалог для полноэкранного просмотра фото ====================

class _FullscreenPhotoDialog extends StatelessWidget {
  final String photoUrl;
  final String name;

  const _FullscreenPhotoDialog({
    required this.photoUrl,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                photoUrl,
                errorBuilder: (_, __, ___) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image, size: 80, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      'Не удалось загрузить фото',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Основной виджет ====================

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
  _CmrStaffFilter _filter = _CmrStaffFilter.all;
  String _selectedTrainerKey = '';
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

  String _trainerIdentity(Map<String, dynamic>? trainer) {
    if (trainer == null) return '';
    final id = _trainerId(trainer);
    if (id > 0) return 'id:$id';

    final email = _trainerEmail(trainer).toLowerCase();
    if (email.isNotEmpty) return 'email:$email';

    final fallback = [
      _trainerName(trainer),
      _trainerBirthday(trainer),
      _trainerPhone(trainer),
    ].where((value) => value.trim().isNotEmpty).join('|').toLowerCase();

    return fallback.isEmpty ? '' : 'fallback:$fallback';
  }

  Map<String, dynamic>? _selectedTrainerFrom(List<Map<String, dynamic>> visible) {
    if (visible.isEmpty) return null;
    if (_selectedTrainerKey.isNotEmpty) {
      for (final trainer in visible) {
        if (_trainerIdentity(trainer) == _selectedTrainerKey) return trainer;
      }
    }
    return visible.first;
  }

  Future<void> _handleOpenTrainer(Map<String, dynamic> trainer, bool mobile) async {
    final key = _trainerIdentity(trainer);
    if (!mobile && mounted) {
      setState(() => _selectedTrainerKey = key);
    }

    final profileData = await _loadTrainerProfileForCard(trainer);
    if (!mounted) return;

    if (mobile) {
      setState(() => _selectedTrainerKey = _trainerIdentity(profileData));
      await _openTrainerModal(profileData, loadProfile: false);
      return;
    }

    final profileKey = _trainerIdentity(profileData);
    setState(() {
      _selectedTrainerKey = profileKey.isEmpty ? key : profileKey;
      final idx = _trainers.indexWhere((item) => _trainerIdentity(item) == key || _trainerIdentity(item) == profileKey);
      if (idx >= 0) {
        _trainers[idx] = <String, dynamic>{..._trainers[idx], ...profileData};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTrainers;
    final assigned = _trainers.where((t) => _trainerTeams(t).isNotEmpty).length;
    final mainCount = _trainers.where(_isMain).length;
    final doctorsCount = _trainers.where((t) => _detectGroup(t) == _CmrStaffFilter.doctors).length;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _CmrErrorState(text: _error!, onRetry: _load);
    }

    return _buildMainLayout(visible, assigned, mainCount, doctorsCount);
  }

  Widget _buildMainLayout(List<Map<String, dynamic>> visible, int assigned, int mainCount, int doctorsCount) {
    final selected = _selectedTrainerFrom(visible);
    final selectedKey = _trainerIdentity(selected);

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 720;
        final compact = constraints.maxWidth < 980;
        final listWidth = math.min(480.0, constraints.maxWidth * .45);

        final list = _TrainerListPanel(
          clubName: widget.clubName,
          trainersCount: _trainers.length,
          visibleCount: visible.length,
          assignedCount: assigned,
          mainCount: mainCount,
          doctorsCount: doctorsCount,
          searchController: _searchC,
          scrollController: _listScroll,
          filter: _filter,
          onFilterChanged: (value) => setState(() => _filter = value),
          trainers: visible,
          selectedKey: selectedKey,
          trainerIdentity: _trainerIdentity,
          onOpenTrainer: (trainer) => _handleOpenTrainer(trainer, mobile),
          onAddTrainer: _saving ? null : _searchAndAddTrainer,
          onAssignTrainer: _saving || _trainers.isEmpty
              ? null
              : () => _assignTrainer(selected ?? (_visibleTrainers.isEmpty ? _trainers.first : _visibleTrainers.first)),
          onRefresh: _load,
          mobile: mobile,
          compact: compact,
        );

        if (mobile) {
          return Container(
            width: double.infinity,
            color: _CmrColors.bg,
            child: list,
          );
        }

        return Container(
          color: _CmrColors.bg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: listWidth, child: list),
              const SizedBox(width: 12),
              Expanded(
                child: _TrainerDetailPanel(
                  trainer: selected,
                  clubName: widget.clubName,
                  selectedTeamName: widget.selectedTeamName,
                  onMessage: selected == null ? null : () => _messageTrainer(selected),
                  onEdit: selected == null ? null : () => _editTrainer(selected),
                  onAssign: selected == null ? null : () => _assignTrainer(selected),
                  onUnlinkTeam: selected == null ? null : () => _unlinkTrainerFromTeam(selected),
                  onRemoveClub: selected == null ? null : () => _removeFromClub(selected),
                  onAddTrainer: _saving ? null : _searchAndAddTrainer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTrainerModal(Map<String, dynamic> trainer, {bool loadProfile = true}) async {
    if (!mounted) return;

    final profileData = loadProfile ? await _loadTrainerProfileForCard(trainer) : trainer;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.18),
      builder: (_) => _TrainerModalSheet(
        trainer: profileData,
        onMessage: () => _messageTrainer(profileData, closeCurrentSheet: true),
        onEdit: () => _editTrainer(profileData, closeCurrentSheet: true),
        onAssign: () => _assignTrainer(profileData, closeCurrentSheet: true),
        onUnlinkTeam: () => _unlinkTrainerFromTeam(profileData, closeCurrentSheet: true),
        onRemoveClub: () => _removeFromClub(profileData, closeCurrentSheet: true),
      ),
    );
  }

  Future<void> _openTrainerDetails(Map<String, dynamic> trainer) async {
    Navigator.pop(context);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainerProfileScreen(
          trainer: trainer,
          onMessage: () => _messageTrainer(trainer),
          onEdit: () => _editTrainer(trainer),
          onAssign: () => _assignTrainer(trainer),
          onUnlinkTeam: () => _unlinkTrainerFromTeam(trainer),
          onRemoveClub: () => _removeFromClub(trainer),
        ),
      ),
    );
  }

  // ==================== Вспомогательные методы ====================

  int _trainerId(Map<String, dynamic> t) => _i(t['id'] ?? t['trainer_id'] ?? t['trainerId'] ?? t['user_id'] ?? t['userId'] ?? t['coach_id']);
  int _teamId(Map<String, dynamic> team) => _i(team['id'] ?? team['team_id'] ?? team['teamId']);

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

  Future<Map<String, dynamic>> _loadTrainerProfileForCard(Map<String, dynamic> trainer) async {
    final trainerId = _trainerId(trainer);
    if (trainerId <= 0) return trainer;

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
      return merged;
    } catch (_) {
      return trainer;
    }
  }

  Future<void> _messageTrainer(Map<String, dynamic> trainer, {bool closeCurrentSheet = false}) async {
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
      if (closeCurrentSheet) {
        Navigator.of(context).pop();
        await Future<void>.delayed(const Duration(milliseconds: 220));
        if (!mounted) return;
      }
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

  Future<void> _searchAndAddTrainer() async {
    if (!mounted) return;

    final emailC = TextEditingController();
    final found = <Map<String, dynamic>>[];
    bool searching = false;

    try {
      final action = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheet) {
              Future<void> search() async {
                final email = emailC.text.trim();
                if (email.isEmpty) {
                  if (!sheetContext.mounted) return;
                  setSheet(() {
                    searching = false;
                    found.clear();
                  });
                  return;
                }

                if (!sheetContext.mounted) return;
                setSheet(() => searching = true);

                try {
                  final data = await _postForm(searchTrainerByEmailUrl, {'email': email});
                  final list = _extractList(data, const ['trainers', 'trainer', 'users', 'data', 'items']);
                  if (!sheetContext.mounted) return;
                  setSheet(() {
                    found
                      ..clear()
                      ..addAll(list);
                    searching = false;
                  });
                } catch (_) {
                  if (!sheetContext.mounted) return;
                  setSheet(() {
                    found.clear();
                    searching = false;
                  });
                }
              }

              void closeWithAction(String type, Map<String, dynamic> trainer) {
                Navigator.of(sheetContext).pop(<String, dynamic>{
                  'type': type,
                  'trainer': Map<String, dynamic>.from(trainer),
                });
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
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(sheetContext).height * .42,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: found.length,
                          itemBuilder: (_, index) {
                            final trainer = found[index];
                            final name = _trainerName(trainer);
                            final email = _trainerEmail(trainer);
                            final photo = _trainerPhoto(trainer);
                            return _CmrSearchTrainerTile(
                              name: name,
                              email: email,
                              photo: photo,
                              onAddClub: () => closeWithAction('club', trainer),
                              onAssignTeam: () => closeWithAction('team', trainer),
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

      if (!mounted || action == null) return;

      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;

      final trainerRaw = action['trainer'];
      if (trainerRaw is! Map) return;
      final trainer = Map<String, dynamic>.from(trainerRaw);
      final trainerId = _trainerId(trainer);
      if (trainerId <= 0) return;

      final type = _s(action['type']);

      if (type == 'club') {
        final ok = await _saveAction(() => _postForm(linkTrainerToClubUrl, {
              'club_id': '${widget.clubId}',
              'trainer_id': '$trainerId',
            }));
        if (ok) await _afterMutation('Тренер добавлен в клуб');
        return;
      }

      if (type == 'team') {
        final team = await _pickTeam();
        if (!mounted || team == null) return;

        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (!mounted) return;

        final profile = await _pickProfileType();
        if (!mounted || profile == null) return;

        final ok = await _linkTrainerToTeam(trainerId, _teamId(team), profile);
        if (ok) await _afterMutation('Тренер назначен в команду');
      }
    } finally {
      emailC.dispose();
    }
  }

  Future<void> _editTrainer(Map<String, dynamic> trainer, {bool closeCurrentSheet = false}) async {
    if (closeCurrentSheet) {
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 220));
    }
    
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
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                pickedPhoto != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
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
                                      borderRadius: BorderRadius.circular(9),
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

  Future<void> _assignTrainer(Map<String, dynamic> trainer, {bool closeCurrentSheet = false}) async {
    if (closeCurrentSheet) {
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 220));
    }
    
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

  Future<void> _unlinkTrainerFromTeam(Map<String, dynamic> trainer, {bool closeCurrentSheet = false}) async {
    if (closeCurrentSheet) {
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 220));
    }
    
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

  Future<void> _removeFromClub(Map<String, dynamic> trainer, {bool closeCurrentSheet = false}) async {
    if (closeCurrentSheet) {
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 220));
    }
    
    final trainerId = _trainerId(trainer);
    if (trainerId <= 0) return;
    final ok = await _confirm(
      title: 'Удалить из клуба?',
      text: 'Тренер будет удалён из списка специалистов клуба.',
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
      ('main', 'Главный тренер', Icons.workspace_premium_rounded, _CmrColors.green),
      ('extra', 'Тренер / специалист', Icons.sports_rounded, _CmrColors.blue),
      ('assistant', 'Ассистент', Icons.support_agent_rounded, _CmrColors.amber),
      ('doctor', 'Медик', Icons.health_and_safety_rounded, _CmrColors.red),
      ('manager', 'Администратор', Icons.admin_panel_settings_rounded, _CmrColors.muted),
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
                  color: item.$4,
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
            Text(text, textAlign: TextAlign.center, style: _CmrText.muted(14)),
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
}


// ==================== Панель тренеров в стиле раздела «Состав» ====================

class _TrainerListPanel extends StatelessWidget {
  final String clubName;
  final int trainersCount;
  final int visibleCount;
  final int assignedCount;
  final int mainCount;
  final int doctorsCount;
  final TextEditingController searchController;
  final ScrollController? scrollController;
  final _CmrStaffFilter filter;
  final ValueChanged<_CmrStaffFilter> onFilterChanged;
  final List<Map<String, dynamic>> trainers;
  final String selectedKey;
  final String Function(Map<String, dynamic>?) trainerIdentity;
  final ValueChanged<Map<String, dynamic>> onOpenTrainer;
  final VoidCallback? onAddTrainer;
  final VoidCallback? onAssignTrainer;
  final Future<void> Function()? onRefresh;
  final bool mobile;
  final bool compact;

  const _TrainerListPanel({
    required this.clubName,
    required this.trainersCount,
    required this.visibleCount,
    required this.assignedCount,
    required this.mainCount,
    required this.doctorsCount,
    required this.searchController,
    required this.scrollController,
    required this.filter,
    required this.onFilterChanged,
    required this.trainers,
    required this.selectedKey,
    required this.trainerIdentity,
    required this.onOpenTrainer,
    required this.onAddTrainer,
    required this.onAssignTrainer,
    required this.onRefresh,
    required this.mobile,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final padding = mobile ? 10.0 : 12.0;

    return Container(
      decoration: _CmrDecor.panel(radius: mobile ? 14 : 16),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrainerHeader(
            clubName: clubName,
            trainersCount: trainersCount,
            visibleCount: visibleCount,
            assignedCount: assignedCount,
            mainCount: mainCount,
            doctorsCount: doctorsCount,
            onAddTrainer: onAddTrainer,
            onAssignTrainer: onAssignTrainer,
            onRefresh: onRefresh,
            mobile: mobile,
          ),
          SizedBox(height: mobile ? 10 : 12),
          _TrainerSearch(controller: searchController, mobile: mobile),
          const SizedBox(height: 8),
          _TrainerFilterBar(value: filter, onChanged: onFilterChanged, mobile: mobile),
          SizedBox(height: mobile ? 9 : 10),
          Expanded(
            child: trainers.isEmpty
                ? _TrainerEmptyState(
                    title: trainersCount == 0 ? 'Тренеры пока не добавлены' : 'Ничего не найдено',
                    text: trainersCount == 0
                        ? 'Добавьте тренера по email или назначьте специалиста в команду.'
                        : 'Измените поиск или фильтр.',
                    onTap: onAddTrainer,
                  )
                : RefreshIndicator(
                    color: _CmrColors.green,
                    onRefresh: onRefresh ?? () async {},
                    child: ListView.separated(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: mobile ? 20 : 8),
                      itemCount: trainers.length,
                      separatorBuilder: (_, __) => SizedBox(height: mobile ? 6 : 7),
                      itemBuilder: (_, index) {
                        final trainer = trainers[index];
                        final active = selectedKey.isNotEmpty && selectedKey == trainerIdentity(trainer);
                        return _TrainerTile(
                          trainer: trainer,
                          active: active,
                          onTap: () => onOpenTrainer(trainer),
                          mobile: mobile,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrainerHeader extends StatelessWidget {
  final String clubName;
  final int trainersCount;
  final int visibleCount;
  final int assignedCount;
  final int mainCount;
  final int doctorsCount;
  final VoidCallback? onAddTrainer;
  final VoidCallback? onAssignTrainer;
  final Future<void> Function()? onRefresh;
  final bool mobile;

  const _TrainerHeader({
    required this.clubName,
    required this.trainersCount,
    required this.visibleCount,
    required this.assignedCount,
    required this.mainCount,
    required this.doctorsCount,
    required this.onAddTrainer,
    required this.onAssignTrainer,
    required this.onRefresh,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = clubName.trim().isEmpty ? 'Специалисты клуба' : clubName;

    return Row(
      children: [
        Container(
          width: mobile ? 34 : 36,
          height: mobile ? 34 : 36,
          decoration: BoxDecoration(
            color: _CmrColors.graphite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _CmrColors.green.withOpacity(.36)),
          ),
          child: const Icon(Icons.badge_rounded, color: _CmrColors.green, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Тренеры',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrText.title(mobile ? 15.5 : 16.5),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrText.muted(mobile ? 11 : 11.5),
              ),
            ],
          ),
        ),
        if (onRefresh != null && !mobile) ...[
          _TrainerIconButton(icon: Icons.refresh_rounded, tooltip: 'Обновить', onTap: onRefresh!, compact: true),
          const SizedBox(width: 6),
        ],
        _TrainerIconButton(
          icon: Icons.person_add_alt_1_rounded,
          tooltip: 'Добавить тренера',
          onTap: onAddTrainer,
          emphasized: true,
          compact: true,
        ),
        if (onAssignTrainer != null) ...[
          const SizedBox(width: 6),
          _TrainerIconButton(
            icon: Icons.add_link_rounded,
            tooltip: 'Назначить в команду',
            onTap: onAssignTrainer,
            compact: true,
          ),
        ],
      ],
    );
  }
}

class _TinyCounter extends StatelessWidget {
  final String text;
  const _TinyCounter({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 30),
      height: 28,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _CmrColors.graphite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _CmrColors.green.withOpacity(.42)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _TrainerStatChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _TrainerStatChip({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CmrColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: _CmrColors.green),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(18)),
                const SizedBox(height: 3),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.muted(10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool emphasized;
  final bool compact;

  const _TrainerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.emphasized = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: emphasized ? _CmrColors.graphite : _CmrColors.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .45 : 1,
            child: SizedBox(
              width: compact ? 34 : 38,
              height: compact ? 34 : 38,
              child: Icon(icon, color: emphasized ? _CmrColors.green : _CmrColors.text, size: compact ? 17 : 18),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainerSearch extends StatelessWidget {
  final TextEditingController controller;
  final bool mobile;

  const _TrainerSearch({required this.controller, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mobile ? 40 : 42,
      decoration: _CmrDecor.softCard(radius: mobile ? 10 : 11),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _CmrColors.muted, size: 21),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Поиск тренера, роли или команды...',
                border: InputBorder.none,
                isDense: true,
              ),
              style: _CmrText.value(mobile ? 12.5 : 13),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: controller.clear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: _CmrColors.muted, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrainerFilterBar extends StatelessWidget {
  final _CmrStaffFilter value;
  final ValueChanged<_CmrStaffFilter> onChanged;
  final bool mobile;

  const _TrainerFilterBar({required this.value, required this.onChanged, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final items = <_CmrStaffFilter, _StaffFilterData>{
      _CmrStaffFilter.all: const _StaffFilterData('Все', Icons.groups_2_rounded),
      _CmrStaffFilter.main: const _StaffFilterData('Главные', Icons.workspace_premium_rounded),
      _CmrStaffFilter.coaches: const _StaffFilterData('Тренеры', Icons.sports_rounded),
      _CmrStaffFilter.assistants: const _StaffFilterData('Ассистенты', Icons.support_agent_rounded),
      _CmrStaffFilter.doctors: const _StaffFilterData('Медики', Icons.health_and_safety_rounded),
      _CmrStaffFilter.noTeam: const _StaffFilterData('Без команды', Icons.link_off_rounded),
    };

    return SizedBox(
      height: mobile ? 33 : 35,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: mobile ? 6 : 8),
        itemBuilder: (_, index) {
          final filter = items.keys.elementAt(index);
          final data = items[filter]!;
          final active = filter == value;
          return _StaffFilterPill(
            label: data.label,
            icon: data.icon,
            active: active,
            onTap: () => onChanged(filter),
            dense: mobile,
          );
        },
      ),
    );
  }
}

class _StaffFilterData {
  final String label;
  final IconData icon;
  const _StaffFilterData(this.label, this.icon);
}

class _StaffFilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool dense;

  const _StaffFilterPill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: dense ? 9 : 11, vertical: dense ? 7 : 8),
          decoration: BoxDecoration(
            color: active ? _CmrColors.graphite : _CmrColors.soft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? _CmrColors.green.withOpacity(.45) : _CmrColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dense ? 18 : 20,
                height: dense ? 18 : 20,
                decoration: BoxDecoration(
                  color: active ? _CmrColors.green.withOpacity(.18) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: active ? _CmrColors.green : _CmrColors.muted, size: dense ? 14 : 15),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : _CmrColors.text,
                  fontSize: dense ? 11.5 : 12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainerTile extends StatelessWidget {
  final Map<String, dynamic> trainer;
  final bool active;
  final VoidCallback onTap;
  final bool mobile;

  const _TrainerTile({
    required this.trainer,
    required this.active,
    required this.onTap,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final name = _trainerName(trainer);
    final role = _trainerRole(trainer);
    final team = _teamsText(trainer);
    final photo = _trainerPhoto(trainer);
    final main = _isMain(trainer);
    final phone = _trainerPhone(trainer);
    final email = _trainerEmail(trainer);
    final contact = phone.isNotEmpty ? phone : email;
    final meta = [role, team, if (contact.isNotEmpty) contact].where((e) => e.trim().isNotEmpty).join('  •  ');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: EdgeInsets.symmetric(horizontal: mobile ? 9 : 10, vertical: mobile ? 8 : 9),
          decoration: BoxDecoration(
            color: _CmrColors.panel,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: active ? _CmrColors.green.withOpacity(.42) : _CmrColors.line),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(.035),
                      blurRadius: 12,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: 3,
                height: mobile ? 42 : 46,
                decoration: BoxDecoration(
                  color: active ? _CmrColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(width: active ? 8 : 6),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _CmrAvatar(photo: photo, name: name, size: mobile ? 40 : 44),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: _TrainerStatusBadge(main: main, active: active),
                  ),
                ],
              ),
              SizedBox(width: mobile ? 9 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrText.title(mobile ? 13.4 : 14.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.isEmpty ? 'Данные не заполнены' : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrText.muted(mobile ? 10.8 : 11.2),
                    ),
                  ],
                ),
              ),
              if (!mobile) ...[
                const SizedBox(width: 8),
                _ChevronBadge(active: active),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainerStatusBadge extends StatelessWidget {
  final bool main;
  final bool active;

  const _TrainerStatusBadge({required this.main, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        color: main || active ? _CmrColors.graphite : _CmrColors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: main || active ? _CmrColors.green.withOpacity(.45) : _CmrColors.line),
      ),
      child: Icon(
        main ? Icons.workspace_premium_rounded : Icons.badge_rounded,
        color: main || active ? _CmrColors.green : _CmrColors.muted,
        size: 12,
      ),
    );
  }
}

class _ChevronBadge extends StatelessWidget {
  final bool active;

  const _ChevronBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: active ? _CmrColors.graphite : _CmrColors.soft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? _CmrColors.green.withOpacity(.45) : _CmrColors.line),
      ),
      child: Icon(Icons.chevron_right_rounded, size: 18, color: active ? _CmrColors.green : _CmrColors.muted2),
    );
  }
}

class _TrainerDetailPanel extends StatelessWidget {
  final Map<String, dynamic>? trainer;
  final String clubName;
  final String selectedTeamName;
  final VoidCallback? onMessage;
  final VoidCallback? onEdit;
  final VoidCallback? onAssign;
  final VoidCallback? onUnlinkTeam;
  final VoidCallback? onRemoveClub;
  final VoidCallback? onAddTrainer;

  const _TrainerDetailPanel({
    required this.trainer,
    required this.clubName,
    required this.selectedTeamName,
    required this.onMessage,
    required this.onEdit,
    required this.onAssign,
    required this.onUnlinkTeam,
    required this.onRemoveClub,
    required this.onAddTrainer,
  });

  @override
  Widget build(BuildContext context) {
    final t = trainer;
    if (t == null) {
      return Container(
        decoration: _CmrDecor.panel(),
        padding: const EdgeInsets.all(18),
        child: _TrainerEmptyDetail(onAddTrainer: onAddTrainer),
      );
    }

    final name = _trainerName(t);
    final role = _trainerRole(t);
    final photo = _trainerPhoto(t);
    final teams = _trainerTeams(t);
    final phone = _trainerPhone(t);
    final email = _trainerEmail(t);
    final birthday = _trainerBirthday(t);
    final experience = _trainerExperience(t);
    final city = _trainerCity(t);
    final specialization = _trainerSpecialization(t);
    final bio = _trainerBio(t);
    final main = _isMain(t);

    return Container(
      decoration: _CmrDecor.panel(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _TrainerDetailHeader(
              name: name,
              role: role,
              photo: photo,
              clubName: clubName,
              main: main,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TrainerPrimaryActionButton(
                    icon: Icons.edit_rounded,
                    text: 'Редактировать',
                    onTap: onEdit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TrainerSecondaryActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: 'Сообщение',
                    onTap: onMessage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TrainerDetailSection(
              title: 'Данные тренера',
              children: [
                _TrainerDetailRow(icon: Icons.badge_rounded, label: 'Роль', value: role),
                _TrainerDetailRow(icon: Icons.apartment_rounded, label: 'Клуб', value: clubName),
                _TrainerDetailRow(icon: Icons.groups_2_rounded, label: 'Команды', value: teams.isEmpty ? 'Команда не назначена' : teams.map(_teamName).join(', ')),
                if (selectedTeamName.trim().isNotEmpty) _TrainerDetailRow(icon: Icons.flag_rounded, label: 'Активная команда', value: selectedTeamName),
                _TrainerDetailRow(icon: Icons.location_city_rounded, label: 'Город', value: city.isEmpty ? 'Не указан' : city),
                _TrainerDetailRow(icon: Icons.auto_awesome_rounded, label: 'Специализация', value: specialization.isEmpty ? 'Не указана' : specialization),
              ],
            ),
            const SizedBox(height: 14),
            _TrainerDetailSection(
              title: 'Контакты',
              children: [
                _TrainerDetailRow(icon: Icons.mail_outline_rounded, label: 'Email', value: email.isEmpty ? 'Не указан' : email),
                _TrainerDetailRow(icon: Icons.phone_rounded, label: 'Телефон', value: phone.isEmpty ? 'Не указан' : phone),
              ],
            ),
            const SizedBox(height: 14),
            _TrainerCommentBox(
              title: 'О тренере',
              text: bio.isEmpty ? 'Описание пока не заполнено.' : bio,
            ),
            const SizedBox(height: 14),
            _TrainerSecondaryActionButton(icon: Icons.add_link_rounded, text: 'Назначить в команду', onTap: onAssign),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _TrainerDangerActionButton(icon: Icons.link_off_rounded, text: 'Отвязать', onTap: onUnlinkTeam, color: _CmrColors.amber)),
                const SizedBox(width: 10),
                Expanded(child: _TrainerDangerActionButton(icon: Icons.delete_outline_rounded, text: 'Удалить из клуба', onTap: onRemoveClub, color: _CmrColors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerDetailHeader extends StatelessWidget {
  final String name;
  final String role;
  final String photo;
  final String clubName;
  final bool main;

  const _TrainerDetailHeader({
    required this.name,
    required this.role,
    required this.photo,
    required this.clubName,
    required this.main,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () {
                if (photo.isNotEmpty) {
                  showDialog(context: context, builder: (_) => _FullscreenPhotoDialog(photoUrl: photo, name: name));
                }
              },
              child: _CmrAvatar(photo: photo, name: name, size: 52),
            ),
            Positioned(right: -4, bottom: -4, child: _TrainerStatusBadge(main: main, active: true)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: _CmrText.title(17.5), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _CmrPill(text: role, icon: Icons.badge_rounded, color: _CmrColors.green),
                  _CmrPill(text: clubName, icon: Icons.apartment_rounded),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrainerSummaryCard extends StatelessWidget {
  final String role;
  final String clubName;
  final int teamsCount;
  final bool main;

  const _TrainerSummaryCard({required this.role, required this.clubName, required this.teamsCount, required this.main});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _CmrDecor.greenCard(radius: 26),
      child: Row(
        children: [
          _CmrRoundIcon(icon: main ? Icons.workspace_premium_rounded : Icons.sports_rounded, color: _CmrColors.green, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: _CmrText.title(17), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Text(clubName, style: _CmrText.muted(12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
                  ),
            child: Text(teamsCount == 0 ? 'Без команды' : '$teamsCount ком.', style: _CmrText.title(15)),
          ),
        ],
      ),
    );
  }
}

class _TrainerMiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TrainerMiniMetric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _CmrDecor.softCard(radius: 20),
      child: Row(
        children: [
          _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 38),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _CmrText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: _CmrText.title(15.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerDetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _TrainerDetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _CmrDecor.softCard(radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: _CmrColors.green, borderRadius: BorderRadius.circular(99))),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: _CmrText.section())),
            ],
          ),
          const SizedBox(height: 9),
          ...children,
        ],
      ),
    );
  }
}

class _TrainerDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TrainerDetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _CmrText.caption()),
                const SizedBox(height: 3),
                Text(value, style: _CmrText.value(12.8), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerCommentBox extends StatelessWidget {
  final String title;
  final String text;

  const _TrainerCommentBox({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _CmrDecor.softCard(radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CmrRoundIcon(icon: Icons.notes_rounded, color: _CmrColors.green, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: _CmrText.section())),
            ],
          ),
          const SizedBox(height: 10),
          Text(text, style: _CmrText.muted(12.5)),
        ],
      ),
    );
  }
}

class _TrainerPrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _TrainerPrimaryActionButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrColors.graphite,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _CmrColors.green, size: 19),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainerSecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _TrainerSecondaryActionButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrColors.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _CmrColors.green, size: 18),
                const SizedBox(width: 7),
                Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.action())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainerDangerActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final Color color;

  const _TrainerDangerActionButton({required this.icon, required this.text, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainerEmptyState extends StatelessWidget {
  final String title;
  final String text;
  final VoidCallback? onTap;

  const _TrainerEmptyState({required this.title, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: _CmrDecor.softCard(radius: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CmrRoundIcon(icon: Icons.badge_rounded, color: _CmrColors.muted, size: 58),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: _CmrText.title(16)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: _CmrText.muted(12.5)),
            const SizedBox(height: 14),
            SizedBox(
              width: 190,
              child: _CmrPrimaryButton(icon: Icons.person_add_alt_1_rounded, title: 'Добавить тренера', onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerEmptyDetail extends StatelessWidget {
  final VoidCallback? onAddTrainer;

  const _TrainerEmptyDetail({required this.onAddTrainer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: _CmrDecor.softCard(radius: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CmrRoundIcon(icon: Icons.badge_rounded, color: _CmrColors.green, size: 62),
            const SizedBox(height: 14),
            Text('Выберите тренера', textAlign: TextAlign.center, style: _CmrText.title(18)),
            const SizedBox(height: 7),
            Text(
              'Слева откройте карточку тренера — здесь появятся профиль, команды, контакты и действия.',
              textAlign: TextAlign.center,
              style: _CmrText.muted(13),
            ),
            const SizedBox(height: 16),
            SizedBox(width: 210, child: _CmrPrimaryButton(icon: Icons.person_add_alt_1_rounded, title: 'Добавить тренера', onTap: onAddTrainer)),
          ],
        ),
      ),
    );
  }
}

// ==================== Модальное окно тренера ====================

class _TrainerModalSheet extends StatefulWidget {
  final Map<String, dynamic> trainer;
  final VoidCallback onMessage;
  final VoidCallback onEdit;
  final VoidCallback onAssign;
  final VoidCallback onUnlinkTeam;
  final VoidCallback onRemoveClub;

  const _TrainerModalSheet({
    required this.trainer,
    required this.onMessage,
    required this.onEdit,
    required this.onAssign,
    required this.onUnlinkTeam,
    required this.onRemoveClub,
  });

  @override
  State<_TrainerModalSheet> createState() => _TrainerModalSheetState();
}

class _TrainerModalSheetState extends State<_TrainerModalSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted || _selectedTab == _tabController.index) return;
      setState(() => _selectedTab = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _trainerName(widget.trainer);
    final role = _trainerRole(widget.trainer);
    final photo = _trainerPhoto(widget.trainer);
    final isMain = _isMain(widget.trainer);
    final teams = _trainerTeams(widget.trainer);
    final phone = _trainerPhone(widget.trainer);
    final email = _trainerEmail(widget.trainer);
    final birthday = _trainerBirthday(widget.trainer);
    final experience = _trainerExperience(widget.trainer);
    final city = _trainerCity(widget.trainer);
    final specialization = _trainerSpecialization(widget.trainer);
    final bio = _trainerBio(widget.trainer);

    final screen = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = math.min(screen.height * .92, 760.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottomInset > 0 ? bottomInset : 10),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: sheetHeight,
          constraints: const BoxConstraints(maxWidth: 720),
          decoration: BoxDecoration(
            color: _CmrColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _CmrColors.line),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 24, offset: const Offset(0, 14))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _ModalTopBar(name: name),
              _ModalHeaderCard(
                name: name,
                role: role,
                photo: photo,
                isMain: isMain,
                teamsCount: teams.length,
              ),
              _ModalQuickActions(
                onMessage: widget.onMessage,
                onEdit: widget.onEdit,
                onAssign: widget.onAssign,
              ),
              _ModalTabBar(
                controller: _tabController,
                selectedTab: _selectedTab,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ModalOverviewTab(
                      role: role,
                      experience: experience,
                      birthday: birthday,
                      city: city,
                      specialization: specialization,
                      bio: bio,
                    ),
                    _ModalAssignmentsTab(teams: teams),
                    _ModalContactsTab(phone: phone, email: email),
                  ],
                ),
              ),
              _ModalBottomDangerActions(
                onUnlinkTeam: widget.onUnlinkTeam,
                onRemoveClub: widget.onRemoveClub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalTopBar extends StatelessWidget {
  final String name;

  const _ModalTopBar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
      child: Column(
        children: [
          const _CmrSheetHandle(),
          Row(
            children: [
              _CmrRoundIcon(icon: Icons.badge_rounded, color: _CmrColors.green, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Профиль тренера', style: _CmrText.title(16)),
                    const SizedBox(height: 2),
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.muted(12)),
                  ],
                ),
              ),
              Material(
                color: _CmrColors.soft,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(Icons.close_rounded, color: _CmrColors.text, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModalHeaderCard extends StatelessWidget {
  final String name;
  final String role;
  final String photo;
  final bool isMain;
  final int teamsCount;

  const _ModalHeaderCard({
    required this.name,
    required this.role,
    required this.photo,
    required this.isMain,
    required this.teamsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CmrColors.green.withOpacity(.30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 12, offset: const Offset(0, 7))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (photo.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (_) => _FullscreenPhotoDialog(photoUrl: photo, name: name),
                );
              }
            },
            child: Stack(
              children: [
                _CmrAvatar(photo: photo, name: name, size: 76),
                if (isMain)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _CmrColors.graphite,
                        borderRadius: const BorderRadius.all(Radius.circular(7)),
                        border: Border.all(color: _CmrColors.green.withOpacity(.45)),
                      ),
                      child: const Icon(Icons.check_rounded, color: _CmrColors.green, size: 15),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.title(20)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _ModalPill(text: role, icon: Icons.badge_rounded, color: _CmrColors.green),
                    if (isMain) const _ModalPill(text: 'Главный', icon: Icons.verified_rounded, color: _CmrColors.green),
                    _ModalPill(
                      text: teamsCount == 0 ? 'Без команды' : '$teamsCount ${_modalTeamWord(teamsCount)}',
                      icon: Icons.groups_2_rounded,
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

  String _modalTeamWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'команда';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'команды';
    return 'команд';
  }
}

class _ModalQuickActions extends StatelessWidget {
  final VoidCallback onMessage;
  final VoidCallback onEdit;
  final VoidCallback onAssign;

  const _ModalQuickActions({
    required this.onMessage,
    required this.onEdit,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _ModalActionButton(
            icon: Icons.chat_bubble_rounded,
            label: 'Сообщение',
            color: _CmrColors.green,
            onTap: onMessage,
          ),
          const SizedBox(width: 8),
          _ModalActionButton(
            icon: Icons.edit_rounded,
            label: 'Редактировать',
            color: _CmrColors.blue,
            onTap: onEdit,
          ),
          const SizedBox(width: 8),
          _ModalActionButton(
            icon: Icons.add_link_rounded,
            label: 'Назначить',
            color: _CmrColors.amber,
            onTap: onAssign,
          ),
        ],
      ),
    );
  }
}

class _ModalTabBar extends StatelessWidget {
  final TabController controller;
  final int selectedTab;

  const _ModalTabBar({required this.controller, required this.selectedTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _CmrColors.green.withOpacity(.38)),
        ),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: _CmrColors.text,
        unselectedLabelColor: _CmrColors.muted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'Обзор'),
          Tab(text: 'Команды'),
          Tab(text: 'Связь'),
        ],
      ),
    );
  }
}

class _ModalPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;

  const _ModalPill({
    required this.text,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? _CmrColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _CmrColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: accent.withOpacity(.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 13, color: accent),
          ),
          const SizedBox(width: 6),
          Text(text, style: _CmrText.muted(12)),
        ],
      ),
    );
  }
}

class _ModalActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModalActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 21, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModalBottomDangerActions extends StatelessWidget {
  final VoidCallback onUnlinkTeam;
  final VoidCallback onRemoveClub;

  const _ModalBottomDangerActions({required this.onUnlinkTeam, required this.onRemoveClub});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: _ModalDangerButton(
                icon: Icons.link_off_rounded,
                label: 'Отвязать от команды',
                onTap: onUnlinkTeam,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModalDangerButton(
                icon: Icons.delete_outline_rounded,
                label: 'Удалить из клуба',
                onTap: onRemoveClub,
                isRed: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalDangerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isRed;

  const _ModalDangerButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isRed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRed ? _CmrColors.red : _CmrColors.amber;
    return Material(
      color: color.withOpacity(.09),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalOverviewTab extends StatelessWidget {
  final String role;
  final String experience;
  final String birthday;
  final String city;
  final String specialization;
  final String bio;

  const _ModalOverviewTab({
    required this.role,
    required this.experience,
    required this.birthday,
    required this.city,
    required this.specialization,
    required this.bio,
  });

  @override
  Widget build(BuildContext context) {
    final info = <_ModalInfoData>[
      _ModalInfoData(Icons.badge_rounded, 'Должность', role),
      _ModalInfoData(Icons.workspace_premium_rounded, 'Опыт', experience.isEmpty ? 'Не указан' : experience),
      _ModalInfoData(Icons.cake_rounded, 'Дата рождения', birthday.isEmpty ? 'Не указана' : birthday),
      _ModalInfoData(Icons.location_city_rounded, 'Город', city.isEmpty ? 'Не указан' : city),
      if (specialization.isNotEmpty) _ModalInfoData(Icons.sports_soccer_rounded, 'Специализация', specialization),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 520;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: info
                    .map(
                      (item) => SizedBox(
                        width: twoColumns ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth,
                        child: _ModalInfoRow(icon: item.icon, label: item.label, value: item.value),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: _CmrDecor.softCard(radius: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CmrRoundIcon(icon: Icons.notes_rounded, color: _CmrColors.green, size: 30),
                    const SizedBox(width: 10),
                    Text('О тренере', style: _CmrText.title(15)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  bio.isEmpty ? 'Описание пока не заполнено. Можно добавить опыт, задачи тренера и направление работы с командой.' : bio,
                  style: _CmrText.muted(13.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalInfoData {
  final IconData icon;
  final String label;
  final String value;

  const _ModalInfoData(this.icon, this.label, this.value);
}

class _ModalAssignmentsTab extends StatelessWidget {
  final List<Map<String, dynamic>> teams;

  const _ModalAssignmentsTab({required this.teams});

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return _ModalEmptyBlock(
        icon: Icons.groups_2_rounded,
        title: 'Нет назначений',
        text: 'Назначьте тренера в команду, чтобы он появился в тренерском штабе.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      itemCount: teams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final team = teams[index];
        final profile = _profileTitle(_s(team['link_profile'] ?? team['profile']));
        final isHead = profile == 'Главный тренер';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: _CmrDecor.softCard(radius: 22),
          child: Row(
            children: [
              _CmrAvatar(photo: _teamLogo(team), name: _teamName(team), size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_teamName(team), maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(15)),
                    const SizedBox(height: 4),
                    Text(profile, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.muted(12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: isHead ? _CmrColors.greenSoft : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isHead ? Icons.workspace_premium_rounded : Icons.sports_rounded,
                  size: 17,
                  color: isHead ? _CmrColors.green : _CmrColors.muted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModalContactsTab extends StatelessWidget {
  final String phone;
  final String email;

  const _ModalContactsTab({
    required this.phone,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        children: [
          _ModalContactCard(
            icon: Icons.phone_rounded,
            label: 'Телефон',
            value: phone.isEmpty ? 'Не указан' : phone,
            color: _CmrColors.green,
          ),
          const SizedBox(height: 10),
          _ModalContactCard(
            icon: Icons.mail_rounded,
            label: 'Email',
            value: email.isEmpty ? 'Не указан' : email,
            color: _CmrColors.blue,
          ),
          const SizedBox(height: 12),
          _CmrNotice(
            icon: Icons.info_outline_rounded,
            title: 'Быстрая связь',
            text: 'Кнопка «Сообщение» сверху откроет личный чат с тренером.',
          ),
        ],
      ),
    );
  }
}

class _ModalInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ModalInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _CmrDecor.softCard(radius: 20),
      child: Row(
        children: [
          _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 38),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
                const SizedBox(height: 3),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.value(13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ModalContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _CmrDecor.softCard(radius: 22),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _CmrText.caption()),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _CmrColors.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalEmptyBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _ModalEmptyBlock({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: _CmrDecor.softCard(radius: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 58),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: _CmrText.title(18)),
              const SizedBox(height: 7),
              Text(text, textAlign: TextAlign.center, style: _CmrText.muted(13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Компактные компоненты ====================

class _CompactTrainersHeader extends StatelessWidget {
  final String clubName;
  final int trainersCount;
  final int assigned;
  final int mainCount;
  final int doctorsCount;
  final VoidCallback? onAddTrainer;
  final VoidCallback? onAssignTrainer;

  const _CompactTrainersHeader({
    required this.clubName,
    required this.trainersCount,
    required this.assigned,
    required this.mainCount,
    required this.doctorsCount,
    this.onAddTrainer,
    this.onAssignTrainer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CmrRoundIcon(icon: Icons.badge_rounded, color: _CmrColors.green, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Тренеры', style: _CmrText.title(16)),
                    Text(clubName, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.muted(11)),
                  ],
                ),
              ),
              _CompactActionButton(icon: Icons.person_add_alt_1_rounded, onTap: onAddTrainer),
              const SizedBox(width: 8),
              _CompactActionButton(icon: Icons.add_link_rounded, onTap: onAssignTrainer),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CompactStatChip(value: '$trainersCount', label: 'в клубе', icon: Icons.groups_2_rounded),
                const SizedBox(width: 6),
                _CompactStatChip(value: '$assigned', label: 'назначены', icon: Icons.link_rounded),
                const SizedBox(width: 6),
                _CompactStatChip(value: '$mainCount', label: 'главные', icon: Icons.workspace_premium_rounded),
                const SizedBox(width: 6),
                _CompactStatChip(value: '$doctorsCount', label: 'медики', icon: Icons.health_and_safety_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CompactActionButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrColors.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(padding: const EdgeInsets.all(10), child: Icon(icon, size: 20, color: _CmrColors.green)),
      ),
    );
  }
}

class _CompactStatChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _CompactStatChip({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: _CmrColors.soft, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _CmrColors.green),
          const SizedBox(width: 4),
          Text(value, style: _CmrText.title(12)),
          const SizedBox(width: 2),
          Text(label, style: _CmrText.muted(10)),
        ],
      ),
    );
  }
}

class _CompactSearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _CompactSearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: _CmrText.title(13),
      decoration: InputDecoration(
        hintText: 'Поиск тренера...',
        hintStyle: _CmrText.muted(12),
        prefixIcon: Icon(Icons.search_rounded, color: _CmrColors.muted, size: 18),
        filled: true,
        fillColor: _CmrColors.soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}

class _CompactFilters extends StatelessWidget {
  final _CmrStaffFilter currentFilter;
  final ValueChanged<_CmrStaffFilter> onFilterChanged;

  const _CompactFilters({required this.currentFilter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
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
          final active = currentFilter == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onFilterChanged(item.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? _CmrColors.panel : _CmrColors.soft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: active ? _CmrColors.green.withOpacity(.42) : _CmrColors.line),
                  ),
                  child: Text(
                    item.$2,
                    style: active ? _CmrText.tabSelected().copyWith(fontSize: 12) : _CmrText.tab().copyWith(fontSize: 12),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CmrTrainerTile extends StatelessWidget {
  final String name;
  final String role;
  final String team;
  final String photo;
  final bool main;
  final VoidCallback onTap;

  const _CmrTrainerTile({
    required this.name,
    required this.role,
    required this.team,
    required this.photo,
    required this.main,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _CmrColors.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _CmrAvatar(photo: photo, name: name, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(14.5)),
                        ),
                        if (main) Icon(Icons.workspace_premium_rounded, color: _CmrColors.green, size: 17),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _CmrPill(text: role, icon: Icons.badge_rounded),
                        _CmrPill(text: team, icon: Icons.groups_2_rounded),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: _CmrColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CmrPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;

  const _CmrPill({required this.text, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final accent = color ?? _CmrColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _CmrColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: accent.withOpacity(.08),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, size: 12, color: accent),
          ),
          const SizedBox(width: 5),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.muted(11))),
        ],
      ),
    );
  }
}

class _CmrAvatar extends StatefulWidget {
  final String photo;
  final String name;
  final double size;

  const _CmrAvatar({required this.photo, required this.name, required this.size});

  @override
  State<_CmrAvatar> createState() => _CmrAvatarState();
}

class _CmrAvatarState extends State<_CmrAvatar> {
  bool _hasError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resetLoadingState();
  }

  @override
  void didUpdateWidget(_CmrAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo) _resetLoadingState();
  }

  void _resetLoadingState() {
    _hasError = false;
    _isLoading = widget.photo.isNotEmpty;
  }

  void _onImageLoaded() {
    if (mounted) setState(() => _isLoading = false);
  }

  void _onImageError() {
    if (mounted) setState(() {
      _hasError = true;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.name.trim().isEmpty
        ? 'Т'
        : widget.name.trim().split(RegExp(r'\s+')).take(2).map((e) => e.isEmpty ? '' : e[0].toUpperCase()).join();

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(math.min(widget.size * .18, 12)),
        border: Border.all(color: _CmrColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: _hasError || widget.photo.isEmpty
          ? Center(child: Text(initials, style: _CmrText.title(widget.size * .32)))
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  widget.photo,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _onImageLoaded());
                      return child;
                    }
                    return Center(
                      child: SizedBox(
                        width: widget.size * 0.3,
                        height: widget.size * 0.3,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _CmrColors.green,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) {
                    _onImageError();
                    return Center(child: Text(initials, style: _CmrText.title(widget.size * .32)));
                  },
                ),
                if (_isLoading) Container(color: Colors.white.withOpacity(0.5)),
              ],
            ),
    );
  }
}

class _CmrRoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _CmrRoundIcon({required this.icon, required this.color, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(math.min(size * .22, 10)),
        border: Border.all(color: color == _CmrColors.green ? _CmrColors.green.withOpacity(.26) : _CmrColors.line),
      ),
      child: Icon(icon, size: size * .52, color: color),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: color == _CmrColors.green ? _CmrColors.graphite : color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color == _CmrColors.green ? _CmrColors.green.withOpacity(.42) : color.withOpacity(.25)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color == _CmrColors.green ? _CmrColors.green : Colors.white),
                const SizedBox(width: 8),
                Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CmrSecondaryButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _CmrSecondaryButton({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            decoration: BoxDecoration(color: _CmrColors.soft, borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Center(child: Text(title, style: _CmrText.tab())),
          ),
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

  const _CmrInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.suffix,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: _CmrText.title(13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _CmrText.muted(12.5),
        prefixIcon: Icon(icon, color: _CmrColors.muted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _CmrColors.soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
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
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: _CmrDecor.softCard(radius: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CmrRoundIcon(icon: Icons.badge_rounded, color: _CmrColors.muted, size: 58),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: _CmrText.title(16)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: _CmrText.muted(12.5)),
            const SizedBox(height: 14),
            SizedBox(width: 190, child: _CmrPrimaryButton(icon: Icons.person_add_alt_1_rounded, title: buttonText, onTap: onTap)),
          ],
        ),
      ),
    );
  }
}

class _CmrErrorState extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _CmrErrorState({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: _CmrDecor.panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _CmrColors.red, size: 42),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: _CmrText.muted(13)),
            const SizedBox(height: 14),
            SizedBox(width: 160, child: _CmrPrimaryButton(icon: Icons.refresh_rounded, title: 'Повторить', onTap: onRetry)),
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(16),
      decoration: _CmrDecor.softCard(radius: 24),
      child: Row(
        children: [
          _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _CmrText.title(14)),
                const SizedBox(height: 4),
                Text(text, style: _CmrText.muted(13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CmrBottomPanel extends StatelessWidget {
  final Widget child;
  final double maxHeightFactor;

  const _CmrBottomPanel({required this.child, this.maxHeightFactor = .86});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: h * maxHeightFactor),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: _CmrDecor.panel(),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _CmrSheetHandle extends StatelessWidget {
  const _CmrSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: const Color(0xFFD0D5DD), borderRadius: BorderRadius.circular(99)),
      ),
    );
  }
}

class _CmrSheetTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CmrSheetTitle({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 50),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _CmrText.title(20)),
              const SizedBox(height: 4),
              Text(subtitle, style: _CmrText.muted(12.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CmrSearchTrainerTile extends StatelessWidget {
  final String name;
  final String email;
  final String photo;
  final VoidCallback onAddClub;
  final VoidCallback onAssignTeam;

  const _CmrSearchTrainerTile({
    required this.name,
    required this.email,
    required this.photo,
    required this.onAddClub,
    required this.onAssignTeam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _CmrDecor.softCard(radius: 22),
      child: Column(
        children: [
          Row(
            children: [
              _CmrAvatar(photo: photo, name: name, size: 48),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(14)),
                    Text(email.isEmpty ? 'Email не указан' : email, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.muted(11.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _CmrSecondaryButton(title: 'В клуб', onTap: onAddClub)),
              const SizedBox(width: 8),
              Expanded(child: _CmrPrimaryButton(icon: Icons.add_link_rounded, title: 'В команду', onTap: onAssignTeam)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CmrTeamPickTile extends StatelessWidget {
  final String name;
  final String logo;
  final VoidCallback onTap;

  const _CmrTeamPickTile({required this.name, required this.logo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: _CmrDecor.softCard(radius: 20),
          child: Row(
            children: [
              _CmrAvatar(photo: logo, name: name, size: 42),
              const SizedBox(width: 10),
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(14))),
              const Icon(Icons.chevron_right_rounded, color: _CmrColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CmrRolePickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _CmrRolePickTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: _CmrDecor.softCard(radius: 20),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: _CmrText.title(14))),
              const Icon(Icons.chevron_right_rounded, color: _CmrColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

  // ==================== ПОЛНОЭКРАННЫЙ ПРОФИЛЬ ТРЕНЕРА ====================

class TrainerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> trainer;
  final VoidCallback onMessage;
  final VoidCallback onEdit;
  final VoidCallback onAssign;
  final VoidCallback onUnlinkTeam;
  final VoidCallback onRemoveClub;

  const TrainerProfileScreen({
    super.key,
    required this.trainer,
    required this.onMessage,
    required this.onEdit,
    required this.onAssign,
    required this.onUnlinkTeam,
    required this.onRemoveClub,
  });

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _selectedTab = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _trainerName(widget.trainer);
    final role = _trainerRole(widget.trainer);
    final photo = _trainerPhoto(widget.trainer);
    final isMain = _isMain(widget.trainer);
    final teams = _trainerTeams(widget.trainer);
    final phone = _trainerPhone(widget.trainer);
    final email = _trainerEmail(widget.trainer);
    final birthday = _trainerBirthday(widget.trainer);
    final experience = _trainerExperience(widget.trainer);
    final city = _trainerCity(widget.trainer);
    final specialization = _trainerSpecialization(widget.trainer);
    final bio = _trainerBio(widget.trainer);

    return Scaffold(
      backgroundColor: _CmrColors.panel,
      body: Column(
        children: [
          // Кастомный AppBar
          _ProfileAppBar(
            name: name,
            onBack: () => Navigator.pop(context),
          ),
          // Основной контент
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Header с фото
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    name: name,
                    role: role,
                    photo: photo,
                    isMain: isMain,
                    teamsCount: teams.length,
                  ),
                ),
                // Кнопки действий
                SliverToBoxAdapter(
                  child: _ProfileActions(
                    onMessage: widget.onMessage,
                    onEdit: widget.onEdit,
                    onAssign: widget.onAssign,
                  ),
                ),
                // TabBar
                SliverToBoxAdapter(
                  child: _ProfileTabBar(
                    tabController: _tabController,
                    selectedTab: _selectedTab,
                  ),
                ),
                // TabBarView content
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ProfileOverviewTab(
                        role: role,
                        experience: experience,
                        birthday: birthday,
                        city: city,
                        specialization: specialization,
                        bio: bio,
                      ),
                      _ProfileAssignmentsTab(teams: teams),
                      _ProfileContactsTab(phone: phone, email: email),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Нижние кнопки
          _ProfileBottomButtons(
            onUnlinkTeam: widget.onUnlinkTeam,
            onRemoveClub: widget.onRemoveClub,
          ),
        ],
      ),
    );
  }
}

// ==================== КОМПОНЕНТЫ ПРОФИЛЯ ====================

class _ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String name;
  final VoidCallback onBack;

  const _ProfileAppBar({
    required this.name,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 48, left: 16, right: 16, bottom: 12),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
      ),
      child: Row(
        children: [
          Material(
            color: _CmrColors.soft,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.arrow_back_rounded, size: 22, color: _CmrColors.text),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _CmrRoundIcon(icon: Icons.badge_rounded, color: _CmrColors.green, size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Профиль тренера', style: _CmrText.title(16)),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: _CmrText.muted(12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(88);
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String role;
  final String photo;
  final bool isMain;
  final int teamsCount;

  const _ProfileHeader({
    required this.name,
    required this.role,
    required this.photo,
    required this.isMain,
    required this.teamsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (photo.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (_) => _FullscreenPhotoDialog(photoUrl: photo, name: name),
                );
              }
            },
            child: _CmrAvatar(photo: photo, name: name, size: 120),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: _CmrText.title(26),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _ProfilePill(text: role, icon: Icons.badge_rounded),
              if (isMain)
                _ProfilePill(
                  text: 'Главный тренер',
                  icon: Icons.verified_rounded,
                  color: _CmrColors.green,
                ),
              _ProfilePill(
                text: teamsCount == 0 ? 'Без команды' : '$teamsCount ${_teamWord(teamsCount)}',
                icon: Icons.groups_2_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _teamWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'команда';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'команды';
    return 'команд';
  }
}

class _ProfilePill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;

  const _ProfilePill({
    required this.text,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? _CmrColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _CmrColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 7),
          Text(text, style: _CmrText.muted(13)),
        ],
      ),
    );
  }
}

class _ProfileActions extends StatelessWidget {
  final VoidCallback onMessage;
  final VoidCallback onEdit;
  final VoidCallback onAssign;

  const _ProfileActions({
    required this.onMessage,
    required this.onEdit,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ProfileActionButton(
              icon: Icons.chat_bubble_rounded,
              label: 'Сообщение',
              color: _CmrColors.green,
              onTap: onMessage,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ProfileActionButton(
              icon: Icons.edit_rounded,
              label: 'Редактировать',
              color: _CmrColors.blue,
              onTap: onEdit,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ProfileActionButton(
              icon: Icons.add_link_rounded,
              label: 'Назначить',
              color: _CmrColors.amber,
              onTap: onAssign,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrColors.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTabBar extends StatelessWidget {
  final TabController tabController;
  final int selectedTab;

  const _ProfileTabBar({
    required this.tabController,
    required this.selectedTab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(40),
      ),
      child: TabBar(
        controller: tabController,
        indicator: BoxDecoration(
          color: _CmrColors.graphite,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: _CmrColors.green.withOpacity(.38)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: _CmrColors.muted,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Обзор'),
          Tab(text: 'Назначения'),
          Tab(text: 'Контакты'),
        ],
      ),
    );
  }
}

class _ProfileOverviewTab extends StatelessWidget {
  final String role;
  final String experience;
  final String birthday;
  final String city;
  final String specialization;
  final String bio;

  const _ProfileOverviewTab({
    required this.role,
    required this.experience,
    required this.birthday,
    required this.city,
    required this.specialization,
    required this.bio,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileInfoCard(
            icon: Icons.badge_rounded,
            label: 'Должность',
            value: role,
          ),
          const SizedBox(height: 12),
          _ProfileInfoCard(
            icon: Icons.workspace_premium_rounded,
            label: 'Опыт работы',
            value: experience.isEmpty ? 'Не указан' : experience,
          ),
          const SizedBox(height: 12),
          _ProfileInfoCard(
            icon: Icons.cake_rounded,
            label: 'Дата рождения',
            value: birthday.isEmpty ? 'Не указана' : birthday,
          ),
          const SizedBox(height: 12),
          _ProfileInfoCard(
            icon: Icons.location_city_rounded,
            label: 'Город',
            value: city.isEmpty ? 'Не указан' : city,
          ),
          if (specialization.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ProfileInfoCard(
              icon: Icons.sports_soccer_rounded,
              label: 'Специализация',
              value: specialization,
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _CmrDecor.softCard(radius: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _CmrColors.soft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _CmrColors.green.withOpacity(.26)),
                      ),
                      child: Icon(Icons.notes_rounded, size: 20, color: _CmrColors.green),
                    ),
                    const SizedBox(width: 12),
                    Text('О тренере', style: _CmrText.title(16)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  bio.isEmpty ? 'Описание пока не заполнено.' : bio,
                  style: _CmrText.muted(14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _CmrDecor.softCard(radius: 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 42,
            decoration: BoxDecoration(
              color: _CmrColors.soft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _CmrColors.green.withOpacity(.26)),
            ),
            child: Icon(icon, size: 24, color: _CmrColors.green),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _CmrText.caption()),
                const SizedBox(height: 4),
                Text(value, style: _CmrText.value(15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAssignmentsTab extends StatelessWidget {
  final List<Map<String, dynamic>> teams;

  const _ProfileAssignmentsTab({required this.teams});

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_2_rounded, size: 72, color: _CmrColors.muted.withOpacity(0.4)),
            const SizedBox(height: 20),
            Text('Нет назначений', style: _CmrText.title(20)),
            const SizedBox(height: 8),
            Text(
              'Тренер пока не назначен ни в одну команду',
              style: _CmrText.muted(14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: teams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final team = teams[index];
        final profile = _profileTitle(_s(team['link_profile'] ?? team['profile']));
        final isMainCoach = _i(team['main_coach_id']) > 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _CmrDecor.softCard(radius: 20),
          child: Row(
            children: [
              _CmrAvatar(photo: _teamLogo(team), name: _teamName(team), size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _teamName(team),
                      style: _CmrText.title(16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.badge_rounded, size: 12, color: _CmrColors.muted),
                        const SizedBox(width: 4),
                        Text(profile, style: _CmrText.muted(12)),
                      ],
                    ),
                  ],
                ),
              ),
              if (isMainCoach || profile == 'Главный тренер')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _CmrColors.panel,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _CmrColors.green.withOpacity(.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 12, color: _CmrColors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Главный',
                        style: TextStyle(color: _CmrColors.green, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileContactsTab extends StatelessWidget {
  final String phone;
  final String email;

  const _ProfileContactsTab({
    required this.phone,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _ProfileContactCard(
            icon: Icons.phone_rounded,
            label: 'Телефон',
            value: phone.isEmpty ? 'Не указан' : phone,
            color: _CmrColors.green,
            onTap: phone.isNotEmpty
                ? () {
                    // Можно добавить вызов телефонного звонка
                  }
                : null,
          ),
          const SizedBox(height: 16),
          _ProfileContactCard(
            icon: Icons.mail_rounded,
            label: 'Email',
            value: email.isEmpty ? 'Не указан' : email,
            color: _CmrColors.blue,
            onTap: email.isNotEmpty
                ? () {
                    // Можно добавить отправку email
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _ProfileContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _ProfileContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: _CmrDecor.softCard(radius: 24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: _CmrText.caption()),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _CmrColors.text),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: _CmrColors.muted, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBottomButtons extends StatelessWidget {
  final VoidCallback onUnlinkTeam;
  final VoidCallback onRemoveClub;

  const _ProfileBottomButtons({
    required this.onUnlinkTeam,
    required this.onRemoveClub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: _ProfileDangerButton(
                icon: Icons.link_off_rounded,
                label: 'Отвязать от команды',
                onTap: onUnlinkTeam,
                color: _CmrColors.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileDangerButton(
                icon: Icons.delete_outline_rounded,
                label: 'Удалить из клуба',
                onTap: onRemoveClub,
                color: _CmrColors.red,
                isRed: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDangerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isRed;

  const _ProfileDangerButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.isRed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrColors.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
