import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/community_screen/create_post_editor_screen.dart';
import 'package:sportoteka/presentation/community_screen/post_blocks.dart';
import 'package:sportoteka/routes/app_routes.dart';


// ==================== CMR Пресс-служба: единый стиль состава ====================

class _CmrPressColors {
  static const Color bg = Colors.white;
  static const Color panel = Colors.white;
  static const Color glass = Colors.white;

  static const Color workspace = Color(0xFFF6F7F6);
  static const Color soft = Color(0xFFF7F8F7);
  static const Color soft2 = Color(0xFFF2F4F2);

  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF374151);
  static const Color muted2 = Color(0xFF5F6670);
  static const Color subtle = Color(0xFF8A9099);

  static const Color line = Color(0xFFE9ECEA);
  static const Color graphite = Color(0xFF111827);
  static const Color graphiteSoft = Color(0xFF4B5563);

  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color greenSoft2 = Color(0xFFF8FEFA);
  static const Color greenBorder = Color(0xFFD7F0E2);

  static const Color red = Color(0xFFD92D20);
}

class _CmrPressText {
  static TextStyle title(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _CmrPressColors.text,
        height: 1.18,
        letterSpacing: 0,
        features: const <FontFeature>[
          FontFeature.tabularFigures(),
        ],
      );

  static TextStyle section() =>
      AppTypography.subsectionTitle(color: _CmrPressColors.text);

  static TextStyle value(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _CmrPressColors.text,
        height: 1.18,
        letterSpacing: 0,
        features: const <FontFeature>[
          FontFeature.tabularFigures(),
        ],
      );

  static TextStyle muted(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: _CmrPressColors.muted2,
        height: 1.32,
        letterSpacing: 0,
      );

  static TextStyle caption() =>
      AppTypography.captionMedium(color: _CmrPressColors.subtle);

  static TextStyle action() =>
      AppTypography.action(color: _CmrPressColors.text);

  static TextStyle navLabel({required bool active}) =>
      AppTypography.menuTitle(
        color: active
            ? _CmrPressColors.greenDark
            : _CmrPressColors.text,
        weight: active ? FontWeight.w600 : FontWeight.w500,
      );

  static TextStyle navSubtitle({required bool active}) =>
      AppTypography.menuSubtitle(
        color: active
            ? _CmrPressColors.greenDark.withOpacity(.68)
            : _CmrPressColors.muted2,
      );
}

class _CmrPressDecor {
  static const double mobileRadius = 18;
  static const double desktopRadius = 20;
  static const double innerRadius = 12;

  static List<BoxShadow> get windowShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 28,
          spreadRadius: -18,
          offset: const Offset(0, 16),
        ),
      ];

  static BoxDecoration softCard({
    double radius = innerRadius,
    bool active = false,
  }) =>
      BoxDecoration(
        color: active
            ? _CmrPressColors.greenSoft
            : _CmrPressColors.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: active
              ? _CmrPressColors.greenBorder
              : _CmrPressColors.line.withOpacity(.55),
          width: .7,
        ),
      );
}

class _PressGlowDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  final bool halo;

  const _PressGlowDot({
    required this.color,
    this.size = 6,
    this.opacity = 1,
    this.halo = true,
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
          boxShadow: halo
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withOpacity(.18),
                    blurRadius: size * 1.9,
                    spreadRadius: .2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _PressDotCluster extends StatelessWidget {
  const _PressDotCluster();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PressGlowDot(
          color: _CmrPressColors.green,
          size: 3.5,
          opacity: .25,
          halo: false,
        ),
        SizedBox(width: 3),
        _PressGlowDot(
          color: _CmrPressColors.green,
          size: 4.5,
          opacity: .48,
          halo: false,
        ),
        SizedBox(width: 3),
        _PressGlowDot(
          color: _CmrPressColors.green,
          size: 5.5,
          opacity: .72,
          halo: false,
        ),
        SizedBox(width: 3),
        _PressGlowDot(
          color: _CmrPressColors.green,
          size: 6.5,
        ),
      ],
    );
  }
}

class CmrPressAssistantScreen extends StatefulWidget {
  final int userId;
  final int clubId;
  final int teamId;
  final String clubName;
  final String teamName;
  final String sportName;
  final bool embedded;
  final VoidCallback? onClose;

  const CmrPressAssistantScreen({
    super.key,
    required this.userId,
    this.clubId = 0,
    this.teamId = 0,
    this.clubName = '',
    this.teamName = '',
    this.sportName = 'Футбол',
    this.embedded = false,
    this.onClose,
  });

  @override
  State<CmrPressAssistantScreen> createState() =>
      _CmrPressAssistantScreenState();
}

class _CmrPressAssistantScreenState extends State<CmrPressAssistantScreen> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';

  // Алиасы оставлены, чтобы не затрагивать рабочую бизнес-логику экрана.
  static const Color _bg = _CmrPressColors.workspace;
  static const Color _card = _CmrPressColors.panel;
  static const Color _border = _CmrPressColors.line;
  static const Color _green = _CmrPressColors.green;
  static const Color _greenDark = _CmrPressColors.greenDark;
  static const Color _text = _CmrPressColors.text;
  static const Color _muted = _CmrPressColors.muted2;
  static const Color _line = _CmrPressColors.line;
  static const Color _soft = _CmrPressColors.soft;
  static const Color _greenSoft = _CmrPressColors.greenSoft;

  bool _loading = true;
  bool _savingName = false;
  bool _savingPassword = false;
  bool _profileOpen = false;
  bool _editorOpen = false;
  String? _error;
  Map<String, dynamic>? _editingPost;
  List<Map<String, dynamic>> _posts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _pressAssignments = <Map<String, dynamic>>[];

  int _activeTeamId = 0;
  int _activeClubId = 0;
  String _activeTeamName = '';
  String _activeClubName = '';
  String _activeSportName = '';

  String _firstName = '';
  String _lastName = '';
  String _email = '';

  late final TextEditingController _firstNameC;
  late final TextEditingController _lastNameC;
  late final TextEditingController _currentPasswordC;
  late final TextEditingController _newPasswordC;
  late final TextEditingController _repeatPasswordC;

  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideRepeatPassword = true;

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  @override
  void initState() {
    super.initState();
    _firstNameC = TextEditingController();
    _lastNameC = TextEditingController();
    _currentPasswordC = TextEditingController();
    _newPasswordC = TextEditingController();
    _repeatPasswordC = TextEditingController();

    _activeTeamId = widget.teamId;
    _activeClubId = widget.clubId;
    _activeTeamName = widget.teamName;
    _activeClubName = widget.clubName;
    _activeSportName = widget.sportName;
    _load();
  }

  @override
  void dispose() {
    _firstNameC.dispose();
    _lastNameC.dispose();
    _currentPasswordC.dispose();
    _newPasswordC.dispose();
    _repeatPasswordC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadUser();
      await _loadAssignments();
      await _loadPosts();
    } catch (e) {
      _error = 'Не удалось загрузить пресс-кабинет: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUser() async {
    var userId = widget.userId;
    if (userId <= 0) userId = await PrefUtils.getUserId() ?? 0;
    if (userId <= 0) return;

    final response = await http
        .get(Uri.parse('$_apiBase/get_user.php?user_id=$userId'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return;

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    Map<String, dynamic> data = <String, dynamic>{};
    if (decoded is Map && decoded['user'] is Map) {
      data = Map<String, dynamic>.from(decoded['user'] as Map);
    } else if (decoded is Map) {
      data = Map<String, dynamic>.from(decoded);
    }

    if (!mounted) return;
    final firstName = _s(data['first_name'] ?? data['firstName']);
    final lastName = _s(data['last_name'] ?? data['lastName']);
    final email = _s(data['email']);

    setState(() {
      _firstName = firstName;
      _lastName = lastName;
      _email = email;
      _firstNameC.text = firstName;
      _lastNameC.text = lastName;
    });
  }

  Future<void> _loadAssignments() async {
    var userId = widget.userId;
    if (userId <= 0) userId = await PrefUtils.getUserId() ?? 0;
    if (userId <= 0) return;

    final response = await http.post(
      Uri.parse('$_apiBase/get_trainer_profile.php'),
      headers: const <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(<String, dynamic>{
        'trainer_id': userId,
      }),
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      return;
    }

    List<dynamic> raw = const <dynamic>[];
    if (decoded is Map && decoded['press_assignments'] is List) {
      raw = decoded['press_assignments'] as List;
    } else if (decoded is Map &&
        decoded['profile'] is Map &&
        (decoded['profile'] as Map)['press_assignments'] is List) {
      raw = (decoded['profile'] as Map)['press_assignments'] as List;
    }

    final rows = <Map<String, dynamic>>[];
    final seen = <int>{};

    for (final item in raw) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final teamId = _asInt(row['team_id'] ?? row['teamId']);
      if (teamId <= 0 || seen.contains(teamId)) continue;
      seen.add(teamId);
      rows.add(row);
    }

    if (rows.isEmpty && widget.teamId > 0) {
      rows.add(<String, dynamic>{
        'team_id': widget.teamId,
        'team_name': widget.teamName,
        'club_id': widget.clubId,
        'club_name': widget.clubName,
        'sport': widget.sportName,
        'profile': 'press_assistant',
      });
    }

    if (rows.isEmpty) return;

    Map<String, dynamic> active = rows.first;
    if (_activeTeamId > 0) {
      for (final row in rows) {
        if (_asInt(row['team_id']) == _activeTeamId) {
          active = row;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _pressAssignments = rows;

      final hasWholeClubScope = rows.any(
        (row) => _s(row['scope']).trim().toLowerCase() == 'all',
      );

      if (widget.teamId <= 0 && hasWholeClubScope) {
        _applyClubScope();
      } else {
        _applyActiveAssignment(active);
      }
    });
  }

  void _applyActiveAssignment(Map<String, dynamic> row) {
    _activeTeamId = _asInt(row['team_id'] ?? row['teamId']);
    _activeClubId = _asInt(row['club_id'] ?? row['clubId']);
    _activeTeamName = _s(row['team_name'] ?? row['teamName']);
    _activeClubName = _s(row['club_name'] ?? row['clubName']);
    _activeSportName = _s(row['sport']);
    if (_activeSportName.isEmpty) _activeSportName = widget.sportName;
  }

  Future<void> _selectAssignment(int teamId) async {
    Map<String, dynamic>? selected;
    for (final row in _pressAssignments) {
      if (_asInt(row['team_id']) == teamId) {
        selected = row;
        break;
      }
    }
    if (selected == null) return;

    if (mounted) {
      setState(() {
        _editorOpen = false;
        _editingPost = null;
        _posts = <Map<String, dynamic>>[];
        _applyActiveAssignment(selected!);
      });
    }

    await _loadPosts();
  }

  Future<void> _loadPosts() async {
    var userId = widget.userId;
    if (userId <= 0) userId = await PrefUtils.getUserId() ?? 0;
    if (userId <= 0) return;

    final clubId = _resolvedClubId;
    if (clubId <= 0) {
      throw Exception('Для пресс-службы не определён клуб');
    }

    if (_activeTeamId <= 0 && !_canPublishWholeClub) {
      // Пользователь с доступом только к выбранным командам работает
      // в конкретной команде, а не во всём клубе.
      if (_pressAssignments.isEmpty) {
        throw Exception('Нет доступных команд пресс-службы');
      }
      _applyActiveAssignment(_pressAssignments.first);
    }

    final uri = Uri.parse('$_apiBase/get_press_team_posts.php').replace(
      queryParameters: <String, String>{
        'user_id': '$userId',
        'club_id': '$clubId',
        'team_id': '$_activeTeamId',
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      Map<String, dynamic>? errorData;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          errorData = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}

      final message = _s(
        errorData?['message'] ??
            errorData?['error'],
      );

      throw Exception(
        message.isEmpty ? 'HTTP ${response.statusCode}' : message,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final List<dynamic> raw = decoded is List
        ? decoded
        : decoded is Map && decoded['posts'] is List
            ? decoded['posts'] as List
            : const <dynamic>[];

    final result = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is! Map) continue;

      // НЕ фильтруем по category/sportName.
      // Старые публикации могли иметь другую категорию, хотя принадлежат
      // этому же пользователю/клубу/команде.
      result.add(Map<String, dynamic>.from(item));
    }

    result.sort((a, b) {
      DateTime parse(dynamic value) =>
          DateTime.tryParse(_s(value).replaceAll(' ', 'T')) ??
          DateTime(1970);
      return parse(b['created_at']).compareTo(parse(a['created_at']));
    });

    if (!mounted) return;
    setState(() => _posts = result);
  }

  String get _displayName {
    final value = '$_firstName $_lastName'.trim();
    return value.isEmpty ? 'Пресс-ассистент' : value;
  }

  bool get _canPublishWholeClub {
    return _pressAssignments.any(
      (row) => _s(row['scope']).trim().toLowerCase() == 'all',
    );
  }

  int get _resolvedClubId {
    if (_activeClubId > 0) return _activeClubId;
    if (widget.clubId > 0) return widget.clubId;
    for (final row in _pressAssignments) {
      final id = _asInt(row['club_id'] ?? row['clubId']);
      if (id > 0) return id;
    }
    return 0;
  }

  String get _resolvedClubName {
    if (_activeClubName.trim().isNotEmpty) return _activeClubName.trim();
    if (widget.clubName.trim().isNotEmpty) return widget.clubName.trim();
    for (final row in _pressAssignments) {
      final name = _s(row['club_name'] ?? row['clubName']).trim();
      if (name.isNotEmpty) return name;
    }
    return 'Клуб';
  }

  String _teamNameById(int teamId) {
    for (final row in _pressAssignments) {
      if (_asInt(row['team_id'] ?? row['teamId']) != teamId) continue;
      final name = _s(row['team_name'] ?? row['teamName']).trim();
      if (name.isNotEmpty) return name;
    }
    return '';
  }

  void _applyClubScope() {
    _activeTeamId = 0;
    _activeClubId = _resolvedClubId;
    _activeTeamName = 'Весь клуб';
    _activeClubName = _resolvedClubName;

    if (_activeSportName.trim().isEmpty && _pressAssignments.isNotEmpty) {
      _activeSportName = _s(_pressAssignments.first['sport']);
    }
    if (_activeSportName.trim().isEmpty) {
      _activeSportName = widget.sportName;
    }
  }

  Future<void> _selectClubScope() async {
    if (!_canPublishWholeClub) return;

    if (mounted) {
      setState(() {
        _profileOpen = false;
        _editorOpen = false;
        _editingPost = null;
        _posts = <Map<String, dynamic>>[];
        _applyClubScope();
      });
    }

    await _loadPosts();
  }

  void _openNewPost() {
    if (!mounted) return;
    setState(() {
      _profileOpen = false;
      _editingPost = null;
      _editorOpen = true;
    });
  }

  String _normalizePostMediaUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return '';

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    var clean = value;

    if (clean.startsWith('file://')) {
      final uploadsIndex = clean.lastIndexOf('/uploads/');
      if (uploadsIndex >= 0) {
        clean = clean.substring(uploadsIndex + 1);
      } else {
        return '';
      }
    }

    clean = clean.replaceFirst(RegExp(r'^\./+'), '');

    if (clean.startsWith('/api/uploads/')) {
      return 'https://sportotekaapp.ru$clean';
    }
    if (clean.startsWith('api/uploads/')) {
      return 'https://sportotekaapp.ru/$clean';
    }
    if (clean.startsWith('/uploads/')) {
      return 'https://sportotekaapp.ru/api$clean';
    }
    if (clean.startsWith('uploads/')) {
      return 'https://sportotekaapp.ru/api/$clean';
    }

    return clean;
  }

  List<PostBlock> _blocksFromPost(Map<String, dynamic> post) {
    final body = _s(post['body'] ?? post['text'] ?? post['caption']);
    if (body.isEmpty) return const <PostBlock>[];

    final html = body.contains('<')
        ? body
        : '<p>${const HtmlEscape().convert(body)}</p>';

    final parsed = PostHtmlParser.htmlToBlocks(html);

    return parsed.map<PostBlock>((block) {
      if (block is ImageBlock) {
        return ImageBlock(
          _normalizePostMediaUrl(block.url),
        );
      }

      if (block is VideoBlock) {
        return VideoBlock(
          url: _normalizePostMediaUrl(block.url),
          title: block.title,
          thumbnail: _normalizePostMediaUrl(block.thumbnail),
        );
      }

      return block;
    }).toList();
  }

  void _openEditPost(Map<String, dynamic> post) {
    if (!mounted) return;
    setState(() {
      _editingPost = Map<String, dynamic>.from(post);
      _editorOpen = true;
    });
  }

  Future<void> _closeEditor({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      _editorOpen = false;
      _editingPost = null;
    });
    if (refresh) await _loadPosts();
  }

  Future<int> _resolvedUserId() async {
    var userId = widget.userId;
    if (userId <= 0) userId = await PrefUtils.getUserId() ?? 0;
    return userId;
  }

  Map<String, dynamic>? _decodeMap(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  String _apiMessage(Map<String, dynamic>? data, String fallback) {
    if (data == null) return fallback;
    final message = _s(
      data['message'] ??
          data['error'] ??
          data['detail'],
    );
    return message.isEmpty ? fallback : message;
  }

  Future<void> _saveProfileName() async {
    if (_savingName) return;

    final firstName = _firstNameC.text.trim();
    final lastName = _lastNameC.text.trim();

    if (firstName.isEmpty) {
      _snack('Укажите имя');
      return;
    }
    if (lastName.isEmpty) {
      _snack('Укажите фамилию');
      return;
    }

    final userId = await _resolvedUserId();
    if (userId <= 0) {
      _snack('Не найден пользователь');
      return;
    }

    if (mounted) setState(() => _savingName = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/update_press_profile.php'),
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(<String, dynamic>{
              'user_id': userId,
              'first_name': firstName,
              'last_name': lastName,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeMap(response);
      final ok = response.statusCode == 200 &&
          data != null &&
          (data['success'] == true ||
              _s(data['status']).toLowerCase() == 'success');

      if (!ok) {
        _snack(_apiMessage(data, 'Не удалось сохранить имя и фамилию'));
        return;
      }

      Map<String, dynamic> savedUser = const <String, dynamic>{};
      if (data?['user'] is Map) {
        savedUser = Map<String, dynamic>.from(data!['user'] as Map);
      } else if (data?['profile'] is Map) {
        savedUser = Map<String, dynamic>.from(data!['profile'] as Map);
      }

      final savedFirst = _s(
        savedUser['first_name'] ?? savedUser['firstName'],
      );
      final savedLast = _s(
        savedUser['last_name'] ?? savedUser['lastName'],
      );

      if (!mounted) return;
      setState(() {
        _firstName = savedFirst.isEmpty ? firstName : savedFirst;
        _lastName = savedLast.isEmpty ? lastName : savedLast;
        _firstNameC.text = _firstName;
        _lastNameC.text = _lastName;
      });

      // Обновляем локальные данные сразу, чтобы ФИО поменялось
      // в Workspace и других экранах без нового входа.
      await PrefUtils.setUserFirstName(_firstName);
      await PrefUtils.setUserLastName(_lastName);

      // Финальная синхронизация с тем же get_user.php, откуда профиль читается
      // при обычном входе в приложение.
      await _loadUser();

      _snack('Имя и фамилия сохранены');
    } catch (e) {
      _snack('Не удалось сохранить профиль: $e');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    if (_savingPassword) return;

    final currentPassword = _currentPasswordC.text;
    final newPassword = _newPasswordC.text;
    final repeatPassword = _repeatPasswordC.text;

    if (currentPassword.isEmpty) {
      _snack('Введите текущий пароль');
      return;
    }
    if (newPassword.length < 8) {
      _snack('Новый пароль должен содержать минимум 8 символов');
      return;
    }
    if (newPassword != repeatPassword) {
      _snack('Новые пароли не совпадают');
      return;
    }
    if (newPassword == currentPassword) {
      _snack('Новый пароль должен отличаться от текущего');
      return;
    }

    final userId = await _resolvedUserId();
    if (userId <= 0) {
      _snack('Не найден пользователь');
      return;
    }

    if (mounted) setState(() => _savingPassword = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/change_press_password.php'),
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(<String, dynamic>{
              'user_id': userId,
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeMap(response);
      final ok = response.statusCode == 200 &&
          data != null &&
          (data['success'] == true ||
              _s(data['status']).toLowerCase() == 'success');

      if (!ok) {
        _snack(_apiMessage(data, 'Не удалось изменить пароль'));
        return;
      }

      _currentPasswordC.clear();
      _newPasswordC.clear();
      _repeatPasswordC.clear();

      _snack('Пароль изменён');
    } catch (e) {
      _snack('Не удалось изменить пароль: $e');
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  void _goToWorkspace() {
    if (!mounted) return;
    Get.offAllNamed(AppRoutes.workspaceHubScreen);
  }

  void _openProfile() {
    if (!mounted) return;
    setState(() {
      _profileOpen = true;
      _editorOpen = false;
      _editingPost = null;
      _firstNameC.text = _firstName;
      _lastNameC.text = _lastName;
    });
  }

  void _openFeed() {
    if (!mounted) return;
    setState(() {
      _profileOpen = false;
      _editorOpen = false;
      _editingPost = null;
    });
  }


  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _brandDots() => const _PressDotCluster();


  Widget _buildHeader({required bool mobile}) {
    return Container(
      constraints: BoxConstraints(minHeight: mobile ? 58 : 62),
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 10 : 14,
        vertical: 9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _CmrPressColors.line,
            width: .55,
          ),
        ),
      ),
      child: Row(
        children: [
          const _PressDotCluster(),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Пресс-служба',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mobile
                      ? AppTypography.screenTitle(
                          color: _CmrPressColors.text,
                        )
                      : _CmrPressText.title(16.5),
                ),
                const SizedBox(height: 3),
                Text(
                  _workspaceContextLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CmrPressText.muted(
                    mobile ? 12 : 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (!mobile && !_profileOpen) ...[
            Material(
              color: _CmrPressColors.greenSoft2,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: _openNewPost,
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  child: Text(
                    'Новая новость',
                    style: _CmrPressText.action().copyWith(
                      color: _CmrPressColors.greenDark,
                      fontSize: 10.8,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (mobile && !_profileOpen)
            IconButton(
              tooltip: 'Новая новость',
              onPressed: _openNewPost,
              icon: const Icon(
                Icons.add_rounded,
                size: 20,
                color: _CmrPressColors.greenDark,
              ),
            ),
          if (widget.onClose != null)
            IconButton(
              tooltip: 'Закрыть',
              onPressed: widget.onClose,
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: _CmrPressColors.muted2,
              ),
            ),
        ],
      ),
    );
  }


  String get _workspaceContextLabel {
    final parts = <String>[
      if (_activeClubName.trim().isNotEmpty) _activeClubName.trim(),
      if (_activeTeamName.trim().isNotEmpty) _activeTeamName.trim(),
    ];
    return parts.isEmpty ? 'Новости назначенных команд' : parts.join(' • ');
  }

  Widget _buildProfileStrip() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final showScopeSelector =
            _pressAssignments.length > 1 || _canPublishWholeClub;

        Widget selector;

        if (showScopeSelector) {
          selector = DropdownButtonFormField<int>(
            value: _activeTeamId,
            isExpanded: true,
            style: _CmrPressText.value(11.4),
            decoration: InputDecoration(
              labelText: 'Рабочая область',
              labelStyle: _CmrPressText.caption(),
              filled: true,
              fillColor: _CmrPressColors.soft,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: _CmrPressColors.line,
                  width: .7,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: _CmrPressColors.line,
                  width: .7,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: _CmrPressColors.green,
                  width: 1,
                ),
              ),
            ),
            items: <DropdownMenuItem<int>>[
              if (_canPublishWholeClub)
                DropdownMenuItem<int>(
                  value: 0,
                  child: Text(
                    'Весь клуб',
                    style: _CmrPressText.value(11.4),
                  ),
                ),
              ..._pressAssignments.map(
                (row) => DropdownMenuItem<int>(
                  value: _asInt(row['team_id']),
                  child: Text(
                    _s(row['team_name']).isEmpty
                        ? 'Команда #${_asInt(row['team_id'])}'
                        : _s(row['team_name']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrPressText.value(11.4),
                  ),
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null || value == _activeTeamId) return;
              if (value == 0) {
                _selectClubScope();
              } else {
                _selectAssignment(value);
              }
            },
          );
        } else {
          selector = Container(
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _CmrPressColors.soft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _CmrPressColors.line.withOpacity(.7),
                width: .7,
              ),
            ),
            child: Row(
              children: [
                const _PressGlowDot(
                  color: _CmrPressColors.green,
                  size: 6,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _activeTeamId <= 0 && _canPublishWholeClub
                        ? 'Весь клуб'
                        : _activeTeamName.isEmpty
                            ? 'Назначенная команда'
                            : _activeTeamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrPressText.value(11.4),
                  ),
                ),
              ],
            ),
          );
        }

        final identity = Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _CmrPressColors.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _displayName.trim().isEmpty
                    ? 'П'
                    : _displayName.trim().substring(0, 1).toUpperCase(),
                style: _CmrPressText.title(13.5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrPressText.value(11.8),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _canPublishWholeClub
                        ? 'Доступ ко всем командам клуба'
                        : 'Доступ: ${_pressAssignments.length} команд(ы)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrPressText.muted(10.2),
                  ),
                ],
              ),
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 14,
            10,
            compact ? 10 : 14,
            8,
          ),
          color: Colors.transparent,
          child: compact
              ? Column(
                  children: [
                    identity,
                    const SizedBox(height: 9),
                    selector,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: identity,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: selector,
                    ),
                  ],
                ),
        );
      },
    );
  }


  Widget _buildSideRail(double width) {
    Widget item({
      required String title,
      required String subtitle,
      required bool active,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
            decoration: BoxDecoration(
              color: active
                  ? _CmrPressColors.greenSoft
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: _PressGlowDot(
                    color: active
                        ? _CmrPressColors.green
                        : _CmrPressColors.muted2,
                    size: active ? 6.4 : 4.8,
                    opacity: active ? 1 : .48,
                    halo: active,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrPressText.navLabel(active: active),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrPressText.navSubtitle(active: active),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(mobile: false),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 8, 7),
                    child: Text(
                      'РАБОЧАЯ ОБЛАСТЬ',
                      style: AppTypography.custom(
                        size: 8.8,
                        weight: FontWeight.w600,
                        color: _CmrPressColors.subtle,
                        height: 1.1,
                        letterSpacing: .35,
                      ),
                    ),
                  ),
                  if (_canPublishWholeClub)
                    item(
                      title: 'Весь клуб',
                      subtitle: 'общеклубные и командные новости',
                      active: _activeTeamId <= 0,
                      onTap: () {
                        _selectClubScope();
                      },
                    ),
                  if (_canPublishWholeClub)
                    const SizedBox(height: 4),
                  for (final row in _pressAssignments) ...[
                    item(
                      title: _s(row['team_name']).trim().isEmpty
                          ? 'Команда #${_asInt(row['team_id'])}'
                          : _s(row['team_name']).trim(),
                      subtitle: 'новости команды',
                      active: _activeTeamId > 0 &&
                          _activeTeamId == _asInt(row['team_id']),
                      onTap: () {
                        final id = _asInt(row['team_id']);
                        if (id > 0) _selectAssignment(id);
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                  const SizedBox(height: 5),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: _CmrPressColors.line,
                  ),
                  const SizedBox(height: 9),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 8, 7),
                    child: Text(
                      'РАЗДЕЛЫ',
                      style: AppTypography.custom(
                        size: 8.8,
                        weight: FontWeight.w600,
                        color: _CmrPressColors.subtle,
                        height: 1.1,
                        letterSpacing: .35,
                      ),
                    ),
                  ),
                  item(
                    title: 'Пресс-лента',
                    subtitle: 'ваши публикации и новости',
                    active: !_profileOpen && !_editorOpen,
                    onTap: _openFeed,
                  ),
                  const SizedBox(height: 4),
                  item(
                    title: 'Новая новость',
                    subtitle: _canPublishWholeClub
                        ? 'команда или весь клуб'
                        : 'для назначенной команды',
                    active: _editorOpen && _editingPost == null,
                    onTap: _openNewPost,
                  ),
                  const SizedBox(height: 4),
                  item(
                    title: 'Профиль',
                    subtitle: 'имя и безопасность',
                    active: _profileOpen,
                    onTap: _openProfile,
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: _CmrPressColors.line,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  onTap: _goToWorkspace,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
                    decoration: BoxDecoration(
                      color: _CmrPressColors.soft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: _PressGlowDot(
                            color: _CmrPressColors.green,
                            size: 6.4,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'К Workspace',
                                style: _CmrPressText.navLabel(
                                  active: false,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _CmrPressText.navSubtitle(
                                  active: false,
                                ),
                              ),
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
      ),
    );
  }


  Widget _buildWorkingArea({
    required bool mobile,
  }) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          if (mobile) _buildHeader(mobile: true),
          if (mobile && !_editorOpen && !_profileOpen)
            _buildProfileStrip(),
          Expanded(
            child: _editorOpen
                ? _editor()
                : _profileOpen
                    ? _buildLimitedProfile()
                    : _buildNewsList(),
          ),
        ],
      ),
    );
  }


  InputDecoration _profileInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: _CmrPressText.caption(),
      prefixIcon: Icon(
        icon,
        size: 17,
        color: _CmrPressColors.muted2,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _CmrPressColors.soft,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 11,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: _CmrPressColors.line,
          width: .7,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: _CmrPressColors.line,
          width: .7,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: _CmrPressColors.green,
          width: 1,
        ),
      ),
    );
  }


  Widget _passwordEye({
    required bool hidden,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: hidden ? 'Показать пароль' : 'Скрыть пароль',
      onPressed: onPressed,
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 18,
      ),
    );
  }

  Widget _buildLimitedProfile() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        Widget sectionHeader({
          required String title,
          required String subtitle,
          required Color dotColor,
        }) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _PressGlowDot(
                  color: dotColor,
                  size: 6.2,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _CmrPressText.value(12.4),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: _CmrPressText.muted(10.1),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        Widget actionButton({
          required String label,
          required bool busy,
          required VoidCallback? onTap,
        }) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: busy
                  ? _CmrPressColors.soft2
                  : _CmrPressColors.greenSoft,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: busy ? null : onTap,
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: busy
                          ? _CmrPressColors.line
                          : _CmrPressColors.greenBorder,
                      width: .7,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (busy)
                        const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: _CmrPressColors.greenDark,
                          ),
                        )
                      else
                        const _PressGlowDot(
                          color: _CmrPressColors.green,
                          size: 5.8,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: _CmrPressText.action().copyWith(
                          color: _CmrPressColors.greenDark,
                          fontSize: 10.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final nameFields = compact
            ? <Widget>[
                TextField(
                  controller: _firstNameC,
                  textInputAction: TextInputAction.next,
                  decoration: _profileInputDecoration(
                    label: 'Имя',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 9),
                TextField(
                  controller: _lastNameC,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_savingName) _saveProfileName();
                  },
                  decoration: _profileInputDecoration(
                    label: 'Фамилия',
                    icon: Icons.badge_outlined,
                  ),
                ),
              ]
            : <Widget>[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameC,
                        textInputAction: TextInputAction.next,
                        decoration: _profileInputDecoration(
                          label: 'Имя',
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextField(
                        controller: _lastNameC,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_savingName) _saveProfileName();
                        },
                        decoration: _profileInputDecoration(
                          label: 'Фамилия',
                          icon: Icons.badge_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          children: [
            Row(
              children: [
                const _PressDotCluster(),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Профиль',
                        style: _CmrPressText.title(15.2),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Личные данные пресс-службы',
                        style: _CmrPressText.muted(10.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: _CmrPressDecor.softCard(radius: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sectionHeader(
                    title: 'Имя и фамилия',
                    subtitle:
                        'Используются в подписи публикаций и рабочем кабинете',
                    dotColor: _CmrPressColors.green,
                  ),
                  const SizedBox(height: 12),
                  ...nameFields,
                  const SizedBox(height: 9),
                  TextFormField(
                    initialValue: _email,
                    readOnly: true,
                    enabled: false,
                    decoration: _profileInputDecoration(
                      label: 'Email',
                      icon: Icons.alternate_email_rounded,
                    ),
                  ),
                  const SizedBox(height: 11),
                  actionButton(
                    label: _savingName
                        ? 'Сохранение...'
                        : 'Сохранить имя и фамилию',
                    busy: _savingName,
                    onTap: _saveProfileName,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: _CmrPressDecor.softCard(radius: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sectionHeader(
                    title: 'Безопасность',
                    subtitle:
                        'Для смены пароля сначала подтвердите текущий пароль',
                    dotColor: _CmrPressColors.greenDark,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _currentPasswordC,
                    obscureText: _hideCurrentPassword,
                    autofillHints: const <String>[
                      AutofillHints.password,
                    ],
                    decoration: _profileInputDecoration(
                      label: 'Текущий пароль',
                      icon: Icons.key_outlined,
                      suffixIcon: _passwordEye(
                        hidden: _hideCurrentPassword,
                        onPressed: () => setState(
                          () => _hideCurrentPassword =
                              !_hideCurrentPassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _newPasswordC,
                    obscureText: _hideNewPassword,
                    autofillHints: const <String>[
                      AutofillHints.newPassword,
                    ],
                    decoration: _profileInputDecoration(
                      label: 'Новый пароль',
                      icon: Icons.lock_reset_rounded,
                      suffixIcon: _passwordEye(
                        hidden: _hideNewPassword,
                        onPressed: () => setState(
                          () => _hideNewPassword =
                              !_hideNewPassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _repeatPasswordC,
                    obscureText: _hideRepeatPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_savingPassword) _changePassword();
                    },
                    decoration: _profileInputDecoration(
                      label: 'Повторите новый пароль',
                      icon: Icons.verified_user_outlined,
                      suffixIcon: _passwordEye(
                        hidden: _hideRepeatPassword,
                        onPressed: () => setState(
                          () => _hideRepeatPassword =
                              !_hideRepeatPassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  actionButton(
                    label: _savingPassword
                        ? 'Изменение...'
                        : 'Изменить пароль',
                    busy: _savingPassword,
                    onTap: _changePassword,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildPostTile(Map<String, dynamic> post) {
    final title =
        _s(post['title']).isEmpty ? 'Без заголовка' : _s(post['title']);
    final created = _s(post['created_at']);
    final body = _s(post['body'] ?? post['text']);
    final plain = body
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final normalizedTeamId = _asInt(
      post['_press_team_id'] ?? post['team_id'],
    );
    final normalizedScope =
        _s(post['_press_scope']).trim().toLowerCase();

    final scopeLabel = normalizedScope == 'club' || normalizedTeamId <= 0
        ? 'Весь клуб'
        : _s(post['_press_team_name']).trim().isNotEmpty
            ? _s(post['_press_team_name']).trim()
            : _teamNameById(normalizedTeamId).isNotEmpty
                ? _teamNameById(normalizedTeamId)
                : 'Команда';

    final clubPost =
        normalizedScope == 'club' || normalizedTeamId <= 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () => _openEditPost(post),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PressGlowDot(
                color: clubPost
                    ? _CmrPressColors.green
                    : _CmrPressColors.muted2,
                size: clubPost ? 6.4 : 4.8,
                opacity: clubPost ? 1 : .48,
                halo: clubPost,
              ),
              const SizedBox(width: 9),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _CmrPressColors.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.article_outlined,
                  color: _CmrPressColors.greenDark,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrPressText.value(11),
                    ),
                    if (plain.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        plain,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrPressText.muted(10.2),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      <String>[
                        scopeLabel,
                        if (created.isNotEmpty) created,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrPressText.caption(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _CmrPressColors.subtle,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildNewsList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _CmrPressColors.green,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: _CmrPressText.muted(11.5),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _load,
                child: Text(
                  'Повторить',
                  style: _CmrPressText.action().copyWith(
                    color: _CmrPressColors.greenDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 26,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _CmrPressColors.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.newspaper_outlined,
                  color: _CmrPressColors.muted2,
                  size: 20,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                'Новостей пока нет',
                style: _CmrPressText.title(14.2),
              ),
              const SizedBox(height: 5),
              Text(
                'Создайте первую публикацию для выбранной команды или всего клуба.',
                textAlign: TextAlign.center,
                style: _CmrPressText.muted(11.2),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _openNewPost,
                child: Text(
                  'Создать новость',
                  style: _CmrPressText.action().copyWith(
                    color: _CmrPressColors.greenDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: _CmrPressColors.green,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
        itemCount: _posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, index) => _buildPostTile(_posts[index]),
      ),
    );
  }


  Widget _editor() {
    final post = _editingPost;

    var editorTeamId = _activeTeamId;
    var editorClubId = _resolvedClubId;
    var editorTeamName = _activeTeamId <= 0 ? 'Весь клуб' : _activeTeamName;

    if (post != null) {
      final normalizedTeamId = _asInt(
        post['_press_team_id'] ??
            post['team_id'],
      );
      final normalizedClubId = _asInt(
        post['_press_club_id'] ??
            post['club_id'],
      );
      final normalizedScope =
          _s(post['_press_scope']).trim().toLowerCase();

      editorTeamId = normalizedScope == 'club' ? 0 : normalizedTeamId;
      if (normalizedClubId > 0) editorClubId = normalizedClubId;

      if (editorTeamId <= 0) {
        editorTeamName = 'Весь клуб';
      } else {
        final normalizedTeamName =
            _s(post['_press_team_name']).trim();
        editorTeamName = normalizedTeamName.isNotEmpty
            ? normalizedTeamName
            : _teamNameById(editorTeamId);
      }
    }

    return CreatePostEditorScreen(
      sportName:
          _activeSportName.isEmpty ? widget.sportName : _activeSportName,
      isEdit: post != null,
      postId: post == null ? null : _asInt(post['id']),
      initialTitle: post == null ? '' : _s(post['title']),
      initialCoverUrl: post == null
          ? ''
          : _normalizePostMediaUrl(
              _s(
                post['image'] ??
                    post['image_url'] ??
                    post['cover_url'],
              ),
            ),
      initialBlocks:
          post == null ? const <PostBlock>[] : _blocksFromPost(post),
      embedded: true,
      teamId: editorTeamId,
      teamName: editorTeamName,
      clubId: editorClubId,
      pressMode: true,
      authorLabel: _displayName,
      onClose: () => _closeEditor(),
      onSaved: () => _closeEditor(refresh: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: _CmrPressColors.workspace,
        colorScheme: base.colorScheme.copyWith(
          primary: _CmrPressColors.greenDark,
          secondary: _CmrPressColors.green,
          surface: Colors.white,
        ),
        textTheme: base.textTheme.apply(
          fontFamily: AppTypography.fontFamily,
          bodyColor: _CmrPressColors.text,
          displayColor: _CmrPressColors.text,
        ),
      ),
      child: Material(
        color: _CmrPressColors.workspace,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 640;
            final compact = constraints.maxWidth < 980;

            final menuWidth = constraints.maxWidth >= 1700
                ? 306.0
                : (constraints.maxWidth >= 1440
                    ? 286.0
                    : (constraints.maxWidth >= 1180 ? 262.0 : 232.0));

            if (mobile) {
              return Container(
                width: double.infinity,
                color: _CmrPressColors.workspace,
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    _CmrPressDecor.mobileRadius,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        _CmrPressDecor.mobileRadius,
                      ),
                    ),
                    child: _buildWorkingArea(
                      mobile: true,
                    ),
                  ),
                ),
              );
            }

            final radius = compact
                ? _CmrPressDecor.mobileRadius
                : _CmrPressDecor.desktopRadius;

            return Container(
              width: double.infinity,
              color: _CmrPressColors.workspace,
              padding: EdgeInsets.all(compact ? 8 : 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(radius),
                    boxShadow: _CmrPressDecor.windowShadow,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSideRail(menuWidth),
                      Container(
                        width: 1,
                        color: _CmrPressColors.line,
                      ),
                      Expanded(
                        child: _buildWorkingArea(
                          mobile: false,
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
    );
  }
}
