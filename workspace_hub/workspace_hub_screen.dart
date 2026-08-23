import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/club_workspace/club_workspace_screen.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';
import 'package:sportoteka/presentation/player_profile_screen/cmr_player_profile_screen.dart';

/// Стартовый экран после авторизации.
///
/// Важно: он НЕ даёт доступ к чужим ролям. Карточка рабочего пространства
/// строится только из подтверждённой роли пользователя. Второй пункт всегда —
/// личный социальный профиль Sportoteka.
class WorkspaceHubScreen extends StatefulWidget {
  const WorkspaceHubScreen({super.key});

  @override
  State<WorkspaceHubScreen> createState() => _WorkspaceHubScreenState();
}

class _WorkspaceHubScreenState extends State<WorkspaceHubScreen> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const Color _green = Color(0xFF079447);
  static const Color _ink = Color(0xFF161A22);
  static const Color _muted = Color(0xFF6B7280);

  bool _loading = true;
  String _role = '';
  String _firstName = '';
  String _lastName = '';
  String? _photoUrl;
  String? _clubName;
  String? _teamName;
  int? _teamId;
  Map<String, dynamic>? _player;

  String get _normalizedRole => _role.trim().toLowerCase();
  bool get _isClub => _normalizedRole == 'club' ||
      _normalizedRole == 'admin' ||
      _normalizedRole == 'клуб' ||
      _normalizedRole.contains('club');
  bool get _isCoach => _normalizedRole == 'coach' ||
      _normalizedRole == 'trainer' ||
      _normalizedRole == 'тренер' ||
      _normalizedRole.contains('coach') ||
      _normalizedRole.contains('trainer');
  bool get _isPlayer => _normalizedRole == 'player' ||
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
    final userId = await PrefUtils.getUserId() ?? 0;
    final first = await PrefUtils.getUserFirstName();
    final last = await PrefUtils.getUserLastName();
    final role = await PrefUtils.getRole();
    final photo = await PrefUtils.getUserPhoto();

    if (!mounted) return;
    setState(() {
      _firstName = first;
      _lastName = last;
      _role = role;
      _photoUrl = _normalizeMediaUrl(photo);
    });

    if (userId > 0) {
      try {
        final response = await http
            .get(Uri.parse('$_apiBase/get_user.php?user_id=$userId'))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map) {
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

            if (!mounted) return;
            setState(() {
              _firstName = '${user['first_name'] ?? user['firstName'] ?? _firstName}'.trim();
              _lastName = '${user['last_name'] ?? user['lastName'] ?? _lastName}'.trim();
              _role = '${user['role'] ?? _role}'.trim();
              _photoUrl = _normalizeMediaUrl(
                    user['photo_url'] ?? user['photo_urls'] ?? user['photo'],
                  ) ??
                  _photoUrl;
              _player = player;
              if (team != null) {
                _teamId = _asInt(team['id'] ?? team['team_id']);
                _teamName = '${team['name'] ?? team['team_name'] ?? ''}'.trim();
                _clubName = '${team['club_name'] ?? team['clubName'] ?? ''}'.trim();
              }
            });
          }
        }
      } catch (_) {
        // Локальные данные PrefUtils уже позволяют открыть разрешённую зону.
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  String? _normalizeMediaUrl(dynamic value) {
    final raw = '${value ?? ''}'.trim();
    if (raw.isEmpty || raw == 'null') return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final clean = raw.replaceFirst(RegExp(r'^/+'), '');
    return 'https://sportotekaapp.ru/$clean';
  }

  Future<void> _openWorkspace() async {
    final userId = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;

    if (_isPlayer) {
      if (_player == null || _player!.isEmpty) {
        Get.snackbar(
          'Центр игрока',
          'К аккаунту пока не привязан профиль игрока. Обратитесь в клуб или администратору.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final payload = <String, dynamic>{
        ..._player!,
        if ((_teamId ?? 0) > 0) 'team_id': _teamId,
        if ((_teamId ?? 0) > 0) 'teamId': _teamId,
        if ((_teamName ?? '').isNotEmpty) 'team_name': _teamName,
        if ((_teamName ?? '').isNotEmpty) 'teamName': _teamName,
        if ((_clubName ?? '').isNotEmpty) 'club_name': _clubName,
      };

      Get.to<void>(() => CmrPlayerProfileScreen(player: payload));
      return;
    }

    if (_isClub || _isCoach) {
      final args = <String, dynamic>{
        'mode': _isCoach ? 'trainer_workspace' : 'club_workspace',
        if (_isClub && userId > 0) 'club_id': userId,
        if (_isCoach && userId > 0) 'trainer_id': userId,
        if ((_teamId ?? 0) > 0) 'initial_team_id': _teamId,
      };
      Get.to<void>(() => const ClubWorkspaceScreen(), arguments: args);
      return;
    }

    Get.snackbar(
      'Рабочее пространство',
      'Для этой роли отдельное рабочее пространство пока не назначено.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _openProfile() async {
    final userId = await PrefUtils.getUserId();
    if (!mounted) return;
    Get.to<void>(() => MyProfileScreen(userId: userId));
  }

  _HubCardData get _workspaceCard {
    if (_isPlayer) {
      return _HubCardData(
        title: 'ЦЕНТР ИГРОКА',
        subtitle: (_teamName ?? '').isNotEmpty
            ? '${_teamName!} · тренировки, показатели, матчи и развитие'
            : 'Тренировки, показатели, матчи и развитие',
        asset: 'assets/images/workspace_hub/player_workspace.png',
        icon: Icons.person_search_outlined,
        onTap: _openWorkspace,
      );
    }
    if (_isCoach) {
      return _HubCardData(
        title: 'ТРЕНЕРСКИЙ ЦЕНТР',
        subtitle: (_teamName ?? '').isNotEmpty
            ? '${_teamName!} · команды, тренировки, аналитика и планы'
            : 'Команды, тренировки, аналитика и планы',
        asset: 'assets/images/workspace_hub/coach_workspace.png',
        icon: Icons.sports_soccer_rounded,
        onTap: _openWorkspace,
      );
    }
    if (_isClub) {
      return _HubCardData(
        title: 'КЛУБНЫЙ РАЗДЕЛ',
        subtitle: (_clubName ?? '').isNotEmpty
            ? '${_clubName!} · управление командами, игроками и матчами'
            : 'Управление командами, игроками, тренировками и матчами',
        asset: 'assets/images/workspace_hub/club_workspace.png',
        icon: Icons.shield_outlined,
        onTap: _openWorkspace,
      );
    }
    return _HubCardData(
      title: 'МОЯ SPORTOTEKA',
      subtitle: 'Личный кабинет и доступные сервисы',
      asset: 'assets/images/workspace_hub/personal_profile.png',
      icon: Icons.apps_rounded,
      onTap: _openWorkspace,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F8F7),
        body: Center(
          child: CircularProgressIndicator(color: _green, strokeWidth: 2.5),
        ),
      );
    }

    final profileCard = _HubCardData(
      title: 'МОЙ ПРОФИЛЬ',
      subtitle: 'Публикации, медиа, сообщения и настройки',
      asset: 'assets/images/workspace_hub/personal_profile.png',
      icon: Icons.person_outline_rounded,
      onTap: _openProfile,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final desktop = constraints.maxWidth >= 1080;
            return Stack(
              children: [
                const Positioned.fill(child: _HubBackground()),
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 16 : 34,
                    compact ? 16 : 24,
                    compact ? 16 : 34,
                    compact ? 34 : 28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopBar(compact),
                          SizedBox(height: compact ? 34 : 48),
                          Text(
                            'Добро пожаловать!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                              fontSize: compact ? 30 : 43,
                              height: 1.05,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Выберите раздел для продолжения',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w500,
                              fontSize: compact ? 15 : 19,
                            ),
                          ),
                          SizedBox(height: compact ? 28 : 40),
                          if (compact)
                            Column(
                              children: [
                                _WorkspaceCard(data: _workspaceCard, compact: true),
                                const SizedBox(height: 16),
                                _WorkspaceCard(data: profileCard, compact: true),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(child: _WorkspaceCard(data: _workspaceCard, tall: desktop)),
                                const SizedBox(width: 26),
                                Expanded(child: _WorkspaceCard(data: profileCard, tall: desktop)),
                              ],
                            ),
                          SizedBox(height: compact ? 20 : 28),
                          Text(
                            _accessHint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF8B929D),
                              fontSize: 11.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String get _accessHint {
    if (_isClub) return 'Аккаунт клуба открывает только клубное пространство и личный профиль.';
    if (_isCoach) return 'Тренер видит назначенные ему команды и личный профиль.';
    if (_isPlayer) return 'Игрок видит только собственный спортивный центр и личный профиль.';
    return 'Доступные разделы определяются ролью и разрешениями аккаунта.';
  }

  Widget _buildTopBar(bool compact) {
    return Row(
      children: [
        Container(
          width: compact ? 36 : 42,
          height: compact ? 36 : 42,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'S',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'SPORTOTEKA',
          style: TextStyle(
            color: _ink,
            fontSize: compact ? 17 : 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
        const Spacer(),
        if (!compact) ...[
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            backgroundImage: (_photoUrl ?? '').isNotEmpty ? NetworkImage(_photoUrl!) : null,
            child: (_photoUrl ?? '').isEmpty
                ? const Icon(Icons.person_rounded, color: _green)
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            'Привет, $_fullName!',
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ],
    );
  }
}

class _HubCardData {
  const _HubCardData({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String asset;
  final IconData icon;
  final VoidCallback onTap;
}

class _WorkspaceCard extends StatefulWidget {
  const _WorkspaceCard({
    required this.data,
    this.compact = false,
    this.tall = true,
  });

  final _HubCardData data;
  final bool compact;
  final bool tall;

  @override
  State<_WorkspaceCard> createState() => _WorkspaceCardState();
}

class _WorkspaceCardState extends State<_WorkspaceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.compact ? 24 : 30);
    final height = widget.compact ? 220.0 : (widget.tall ? 410.0 : 340.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.014 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.data.onTap,
            borderRadius: radius,
            child: Ink(
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF079447).withOpacity(_hovered ? .20 : .11),
                    blurRadius: _hovered ? 44 : 30,
                    spreadRadius: -12,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        widget.data.asset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF2F7F4)),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withOpacity(.98),
                              Colors.white.withOpacity(widget.compact ? .83 : .76),
                              Colors.white.withOpacity(widget.compact ? .22 : .08),
                            ],
                            stops: const [0, .52, 1],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(widget.compact ? 22 : 30),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: widget.compact ? 225 : 260),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: widget.compact ? 48 : 58,
                                height: widget.compact ? 48 : 58,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1FBF6),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(widget.data.icon, color: const Color(0xFF079447), size: widget.compact ? 26 : 31),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                widget.data.title,
                                style: TextStyle(
                                  color: const Color(0xFF171A20),
                                  fontSize: widget.compact ? 17 : 22,
                                  fontWeight: FontWeight.w900,
                                  height: 1.08,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                widget.data.subtitle,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF5F6670),
                                  fontSize: widget.compact ? 12.2 : 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.42,
                                ),
                              ),
                              const SizedBox(height: 21),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: widget.compact ? 43 : 50,
                                height: widget.compact ? 43 : 50,
                                decoration: BoxDecoration(
                                  color: _hovered ? const Color(0xFF079447) : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: _hovered ? Colors.white : const Color(0xFF079447),
                                  size: 25,
                                ),
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
          ),
        ),
      ),
    );
  }
}

class _HubBackground extends StatelessWidget {
  const _HubBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: Color(0xFFF5F7F6)),
        Positioned(
          left: -140,
          bottom: -180,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
            child: Container(
              width: 430,
              height: 430,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF55D49A).withOpacity(.24),
              ),
            ),
          ),
        ),
        Positioned(
          right: -170,
          top: -150,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
            child: Container(
              width: 460,
              height: 460,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFCFD8FF).withOpacity(.30),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
