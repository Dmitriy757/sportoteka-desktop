import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/core/app_export.dart';

class CmrDashboardPanel extends StatefulWidget {
  final String apiBaseUrl;
  final int userId;
  final String role;
  final int coachId;
  final int clubId;
  final int teamId;
  final int playerId;
  final VoidCallback? onOpenWorkspace;
  final void Function(int chatId, String chatName)? onOpenChat;
  final void Function(String moduleId)? onOpenModule;

  const CmrDashboardPanel({
    super.key,
    required this.apiBaseUrl,
    required this.userId,
    required this.role,
    this.coachId = 0,
    this.clubId = 0,
    this.teamId = 0,
    this.playerId = 0,
    this.onOpenWorkspace,
    this.onOpenChat,
    this.onOpenModule,
  });

  @override
  State<CmrDashboardPanel> createState() => _CmrDashboardPanelState();
}

class _CmrDashboardPanelState extends State<CmrDashboardPanel> {
  late final Dio _dio;
  bool _loading = true;
  String _error = '';
  Map<String, dynamic> _data = {};

  bool get _isPlayer => widget.role == 'player' || widget.role == 'parent';

  bool get _isClub {
    final r = widget.role.trim().toLowerCase();
    return r == 'club' || r == 'clubs' || r == 'клуб';
  }

  bool get _isCoach {
    final r = widget.role.trim().toLowerCase();
    return r == 'coach' || r == 'trainer' || r == 'тренер' || r == 'coaches';
  }

  void _openWorkspaceFromPanel() {
    final effectiveClubId = widget.clubId > 0 ? widget.clubId : widget.userId;
    final effectiveTrainerId = widget.coachId > 0 ? widget.coachId : widget.userId;

    if (_isClub) {
      Get.toNamed(
        AppRoutes.clubDashboardScreen,
        arguments: {
          'mode': 'club_profile',
          'club_id': effectiveClubId,
        },
      );
      return;
    }

    if (_isCoach) {
      Get.toNamed(
        AppRoutes.clubDashboardScreen,
        arguments: {
          'mode': 'trainer_assigned',
          'trainer_id': effectiveTrainerId,
          'coach_id': effectiveTrainerId,
          if (widget.clubId > 0) 'club_id': widget.clubId,
          if (widget.teamId > 0) 'team_id': widget.teamId,
        },
      );
      return;
    }

    if (widget.teamId > 0) {
      Get.toNamed(
        '/myTeamScreen',
        arguments: {
          'team_id': widget.teamId,
          'mode': _isPlayer ? 'player_team' : 'dashboard_team',
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: widget.apiBaseUrl.endsWith('/') ? widget.apiBaseUrl : '${widget.apiBaseUrl}/',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.plain,
    ));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final res = await _dio.get('get_cmr_dashboard.php', queryParameters: {
        'user_id': widget.userId,
        'role': widget.role,
        'coach_id': widget.coachId > 0 ? widget.coachId : widget.userId,
        'club_id': widget.clubId,
        'team_id': widget.teamId,
        'player_id': widget.playerId,
        'period_days': 120,
        'limit': 6,
      });

      final body = _decodeServerMap(res.data);
      final success = body['success'] == true || body['status'] == 'success';
      if (!success) {
        throw Exception((body['message'] ?? 'Не удалось загрузить приборную панель').toString());
      }

      if (!mounted) return;
      setState(() {
        _data = body;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    if (_error.isNotEmpty) return _errorView();

    final sections = _asMap(_data['sections']);
    final summary = _asMap(_data['summary']);
    final teams = _asList(_data['teams']);
    final title = _isPlayer ? 'Моя приборная панель' : 'Приборная панель тренера';
    final subtitle = _isPlayer
        ? _playerSubtitle()
        : teams.isEmpty
            ? 'Команды не найдены'
            : 'Последние события по ${teams.length} командам';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: title,
            subtitle: subtitle,
          ),
          const SizedBox(height: 12),
          _SummaryStrip(summary: summary, isPlayer: _isPlayer),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              final cards = _buildCards(sections);
              if (!wide) {
                return Column(children: cards.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList());
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: cards.where((e) => cards.indexOf(e).isEven).map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList())),
                  const SizedBox(width: 12),
                  Expanded(child: Column(children: cards.where((e) => cards.indexOf(e).isOdd).map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList())),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCards(Map<String, dynamic> sections) {
    if (_isPlayer) {
      return [
        _sectionCard(
          title: 'МОИ СОБЫТИЯ',
          icon: Icons.event_available_rounded,
          color: const Color(0xFF2563EB),
          rows: _asList(sections['events']),
          emptyTitle: 'Событий пока нет',
          emptySubtitle: 'Тренировки и игры появятся здесь.',
          builder: (row) => _eventRow(row),
          onTapAll: null,
        ),
        _sectionCard(
          title: 'МОИ МАТЧИ',
          icon: Icons.sports_soccer_rounded,
          color: const Color(0xFF16A34A),
          rows: _asList(sections['matches']),
          emptyTitle: 'Матчей пока нет',
          emptySubtitle: 'Здесь будут ближайшие и прошедшие игры.',
          builder: (row) => _matchRow(row),
          onTapAll: null,
        ),
        _sectionCard(
          title: 'ПОСЕЩЕНИЯ',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF0891B2),
          rows: _asList(sections['attendance']),
          emptyTitle: 'Отметок пока нет',
          emptySubtitle: 'Последние отметки посещаемости появятся здесь.',
          builder: (row) => _attendanceRow(row),
          onTapAll: null,
        ),
        _sectionCard(
          title: 'ОЦЕНКИ И ТЕСТЫ',
          actionText: 'контроль',
          icon: Icons.fact_check_rounded,
          color: const Color(0xFFEA580C),
          rows: [..._asList(sections['ratings']), ..._asList(sections['testing'])].take(5).toList(),
          emptyTitle: 'Оценок пока нет',
          emptySubtitle: 'Оценки тренера и тестирования будут здесь.',
          builder: (row) => row.containsKey('rating') ? _ratingRow(row) : _testingRow(row),
          onTapAll: () => widget.onOpenModule?.call('testing'),
        ),
        _sectionCard(
          title: 'ЧАТЫ',
          actionText: 'чат',
          icon: Icons.forum_rounded,
          color: const Color(0xFF7C3AED),
          rows: _asList(sections['chats']),
          emptyTitle: 'Нет сообщений',
          emptySubtitle: 'Последние сообщения появятся здесь.',
          builder: (row) => _chatRow(row),
          onTapAll: () => widget.onOpenModule?.call('chats'),
        ),
      ];
    }

    return [
      _sectionCard(
        title: 'БЛИЖАЙШИЕ СОБЫТИЯ',
        icon: Icons.event_available_rounded,
        color: const Color(0xFF2563EB),
        rows: _asList(sections['events']),
        emptyTitle: 'Событий пока нет',
        emptySubtitle: 'Тренировки, игры и встречи появятся здесь.',
        builder: (row) => _eventRow(row),
        onTapAll: null,
      ),
      _sectionCard(
        title: 'МАТЧИ',
        icon: Icons.sports_soccer_rounded,
        color: const Color(0xFF16A34A),
        rows: _asList(sections['matches']),
        emptyTitle: 'Матчей пока нет',
        emptySubtitle: 'Ближайшие и последние матчи будут здесь.',
        builder: (row) => _matchRow(row),
        onTapAll: null,
      ),
      _sectionCard(
        title: 'ПОСЕЩЕНИЯ',
        icon: Icons.how_to_reg_rounded,
        color: const Color(0xFF0891B2),
        rows: _asList(sections['attendance']),
        emptyTitle: 'Отметок пока нет',
        emptySubtitle: 'Последние отметки игроков появятся здесь.',
        builder: (row) => _attendanceRow(row),
        onTapAll: null,
      ),
      _sectionCard(
        title: 'ОЦЕНКИ',
        actionText: 'оценки',
        icon: Icons.star_rounded,
        color: const Color(0xFFF59E0B),
        rows: _asList(sections['ratings']),
        emptyTitle: 'Оценок пока нет',
        emptySubtitle: 'Последние оценки игроков будут здесь.',
        builder: (row) => _ratingRow(row),
        onTapAll: null,
      ),
      _sectionCard(
        title: 'ТЕСТИРОВАНИЕ',
        actionText: 'контроль',
        icon: Icons.fact_check_rounded,
        color: const Color(0xFFEA580C),
        rows: _asList(sections['testing']),
        emptyTitle: 'Тестов пока нет',
        emptySubtitle: 'Последние тестирования появятся здесь.',
        builder: (row) => _testingRow(row),
        onTapAll: () => widget.onOpenModule?.call('testing'),
      ),
      _sectionCard(
        title: 'ЧАТЫ',
        actionText: 'чат',
        icon: Icons.forum_rounded,
        color: const Color(0xFF7C3AED),
        rows: _asList(sections['chats']),
        emptyTitle: 'Нет сообщений',
        emptySubtitle: 'Последние командные и личные сообщения будут здесь.',
        builder: (row) => _chatRow(row),
        onTapAll: () => widget.onOpenModule?.call('chats'),
      ),
    ];
  }

  Widget _sectionCard({
    required String title,
    String? actionText,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> rows,
    required String emptyTitle,
    required String emptySubtitle,
    required Widget Function(Map<String, dynamic>) builder,
    VoidCallback? onTapAll,
  }) {
    return Container(
      decoration: _cardDecoration(radius: 22),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .65, color: Color(0xFF64748B)),
                  ),
                ),
                if (actionText != null && actionText.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Text(
                      actionText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: onTapAll == null ? const Color(0xFF94A3B8) : color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (rows.isEmpty)
            _DashboardRow(
              icon: icon,
              color: const Color(0xFF94A3B8),
              title: emptyTitle,
              subtitle: emptySubtitle,
              trailing: '',
              teamName: '',
              onTap: onTapAll,
            )
          else
            ...rows.map((row) => Column(children: [const Divider(height: 1, color: Color(0xFFEFF3F7), indent: 66), builder(row)])),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _eventRow(Map<String, dynamic> row) {
    return _DashboardRow(
      icon: Icons.event_available_rounded,
      color: const Color(0xFF2563EB),
      title: _s(row['title'], fallback: 'Событие'),
      subtitle: _firstNotEmpty([row['location'], row['subtitle'], row['notes'], _eventType(row['type'])]),
      trailing: _shortDate(_s(row['date'])),
      teamName: _teamName(row),
      onTap: null,
    );
  }

  Widget _matchRow(Map<String, dynamic> row) {
    final team = _firstNotEmpty([row['team_name'], row['stored_team_name']], fallback: 'Команда');
    final opponent = _s(row['opponent'], fallback: 'Соперник');
    final score = '${_s(row['our_score'], fallback: '0')}:${_s(row['opponent_score'], fallback: '0')}';
    return _DashboardRow(
      icon: Icons.sports_soccer_rounded,
      color: const Color(0xFF16A34A),
      title: '$team — $opponent',
      subtitle: _firstNotEmpty([row['competition_name'], row['stadium'], row['event_type']], fallback: 'Матч'),
      trailing: score == '0:0' ? _shortDate(_s(row['date'])) : score,
      teamName: team,
      onTap: null,
    );
  }

  Widget _attendanceRow(Map<String, dynamic> row) {
    return _DashboardRow(
      icon: Icons.how_to_reg_rounded,
      color: const Color(0xFF0891B2),
      title: _firstNotEmpty([row['player_name'], row['event_title']], fallback: 'Посещаемость'),
      subtitle: _firstNotEmpty([row['event_title'], row['note']], fallback: _attendanceStatus(row['status'])),
      trailing: _attendanceStatus(row['status']),
      teamName: _teamName(row),
      onTap: null,
    );
  }

  Widget _ratingRow(Map<String, dynamic> row) {
    return _DashboardRow(
      icon: Icons.star_rounded,
      color: const Color(0xFFF59E0B),
      title: _firstNotEmpty([row['player_name'], row['event_title']], fallback: 'Оценка'),
      subtitle: _firstNotEmpty([row['event_title']], fallback: 'Оценка тренера'),
      trailing: '${_s(row['rating'], fallback: '0')}/5',
      teamName: _teamName(row),
      onTap: null,
    );
  }

  Widget _testingRow(Map<String, dynamic> row) {
    final count = int.tryParse('${row['results_count'] ?? 0}') ?? 0;
    return _DashboardRow(
      icon: Icons.fact_check_rounded,
      color: const Color(0xFFEA580C),
      title: _s(row['title'], fallback: 'Тестирование'),
      subtitle: '${_s(row['category_code'], fallback: 'контроль')} • ${_s(row['stage_code'], fallback: 'этап')}',
      trailing: count > 0 ? '$count рез.' : _shortDate(_s(row['date'])),
      teamName: _teamName(row),
      onTap: () => widget.onOpenModule?.call('testing'),
    );
  }

  Widget _chatRow(Map<String, dynamic> row) {
    final chatId = int.tryParse('${row['id'] ?? 0}') ?? 0;
    final title = _s(row['title'], fallback: 'Чат');
    return _DashboardRow(
      icon: Icons.forum_rounded,
      color: const Color(0xFF7C3AED),
      title: title,
      subtitle: _firstNotEmpty([row['last_message'], row['sender_name']], fallback: 'Нет сообщений'),
      trailing: _shortDate(_s(row['date'])),
      teamName: '',
      onTap: chatId > 0 ? () => widget.onOpenChat?.call(chatId, title) : () => widget.onOpenModule?.call('chats'),
    );
  }

  void _openTeamFromDashboard(Map<String, dynamic> team) {
    final teamId = _asInt(team['id'] ?? team['team_id']);
    if (teamId <= 0) {
      _openWorkspaceFromPanel();
      return;
    }

    final clubId = _asInt(team['club_id'] ?? team['clubId'] ?? widget.clubId);
    final mode = _isPlayer
        ? 'player_team'
        : _isCoach
            ? 'coach_my'
            : _isClub
                ? 'club_assigned'
                : 'dashboard';

    Get.toNamed(
      '/myTeamScreen',
      arguments: {
        'team_id': teamId,
        if (clubId > 0) 'club_id': clubId,
        'mode': mode,
      },
    );
  }

  Widget _loadingView() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 26),
      child: const Row(
        children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
          SizedBox(width: 12),
          Expanded(child: Text('Загружаем приборную панель...', style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Панель не загрузилась', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text(_error, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Повторить')),
        ],
      ),
    );
  }

  String _playerSubtitle() {
    final player = _asMap(_data['player']);
    final name = _s(player['player_name']).trim();
    final team = _s(player['team_name']).trim();
    if (name.isNotEmpty && team.isNotEmpty) return '$name • $team';
    if (team.isNotEmpty) return team;
    return 'Последние события игрока';
  }

  BoxDecoration _cardDecoration({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFE5EAF1)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 18, offset: const Offset(0, 8))],
    );
  }
}


class _TeamsOverviewPanel extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final int activeTeamId;
  final String title;
  final String subtitle;
  final void Function(Map<String, dynamic> team) onOpenTeam;
  final VoidCallback? onOpenWorkspace;

  const _TeamsOverviewPanel({
    required this.teams,
    required this.activeTeamId,
    required this.title,
    required this.subtitle,
    required this.onOpenTeam,
    this.onOpenWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 620;
        final tablet = width >= 620 && width < 980;
        final visibleTeams = teams.take(compact ? 8 : 12).toList();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5EAF1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.groups_2_rounded, color: Color(0xFF16A34A), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onOpenWorkspace != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onOpenWorkspace,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE5EAF1)),
                        ),
                        child: const Text(
                          'панель',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (compact)
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visibleTeams.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final team = visibleTeams[index];
                      return SizedBox(
                        width: 238,
                        child: _TeamDashboardTile(
                          team: team,
                          selected: _teamId(team) == activeTeamId && activeTeamId > 0,
                          compact: true,
                          onTap: () => onOpenTeam(team),
                        ),
                      );
                    },
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleTeams.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: width >= 1280 ? 4 : (tablet ? 2 : 3),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 92,
                  ),
                  itemBuilder: (_, index) {
                    final team = visibleTeams[index];
                    return _TeamDashboardTile(
                      team: team,
                      selected: _teamId(team) == activeTeamId && activeTeamId > 0,
                      compact: false,
                      onTap: () => onOpenTeam(team),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  static int _teamId(Map<String, dynamic> team) => _asInt(team['id'] ?? team['team_id']);
}

class _TeamDashboardTile extends StatelessWidget {
  final Map<String, dynamic> team;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _TeamDashboardTile({
    required this.team,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = _firstNotEmpty([team['name'], team['team_name'], team['title']], fallback: 'Команда');
    final category = _firstNotEmpty([team['category'], team['sport'], team['sport_name']], fallback: 'Экран команды');
    final logoUrl = _firstNotEmpty([team['logo'], team['team_logo'], team['logo_url'], team['image']]);
    final color = selected ? const Color(0xFF16A34A) : const Color(0xFF2563EB);

    return Material(
      color: selected ? const Color(0xFFEFFDF4) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.all(compact ? 11 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? color.withOpacity(.35) : const Color(0xFFE5EAF1)),
          ),
          child: Row(
            children: [
              _TeamDashboardAvatar(
                logoUrl: logoUrl,
                name: name,
                color: color,
              ),
              const SizedBox(width: 10),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Открыть экран команды',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 20, color: color.withOpacity(.72)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamDashboardAvatar extends StatelessWidget {
  final String logoUrl;
  final String name;
  final Color color;

  const _TeamDashboardAvatar({
    required this.logoUrl,
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedLogo = _normalizeImageUrl(logoUrl);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(.14)),
      ),
      child: normalizedLogo.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                normalizedLogo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              ),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    final trimmedName = name.trim();
    final letter = trimmedName.isEmpty ? 'К' : trimmedName.substring(0, 1).toUpperCase();
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}


class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;

        final titleBlock = Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(.10), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF2563EB), size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.05)),
                  const SizedBox(height: 5),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        );

        return titleBlock;
      },
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final Map<String, dynamic> summary;
  final bool isPlayer;

  const _SummaryStrip({required this.summary, required this.isPlayer});

  @override
  Widget build(BuildContext context) {
    final items = isPlayer
        ? [
            ['События', summary['events']],
            ['Матчи', summary['matches']],
            ['Отметки', summary['attendance']],
            ['Оценки', summary['ratings']],
            ['Тесты', summary['testing']],
          ]
        : [
            ['Команды', summary['teams']],
            ['События', summary['events']],
            ['Матчи', summary['matches']],
            ['Отметки', summary['attendance']],
            ['Оценки', summary['ratings']],
            ['Тесты', summary['testing']],
          ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((e) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5EAF1))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${e[1] ?? 0}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(width: 6),
                Text('${e[0]}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DashboardRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String trailing;
  final String teamName;
  final VoidCallback? onTap;

  const _DashboardRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.teamName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.trim().isEmpty ? 'Без названия' : title.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF111827), height: 1.12)),
                const SizedBox(height: 4),
                Text(subtitle.trim().isEmpty ? 'Нет описания' : subtitle.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B), height: 1.15)),
                if (teamName.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
                    child: Text(teamName.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF475569))),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (trailing.trim().isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxWidth: 92),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.14))),
              child: Text(trailing.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: content);
  }
}


Map<String, dynamic> _decodeServerMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return <String, dynamic>{};

  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}

  // На сервере иногда вместе с JSON прилетает предупреждение PHP/HTML.
  // Берём JSON от первой фигурной скобки до последней.
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }

  return <String, dynamic>{
    'success': false,
    'status': 'error',
    'message': text.length > 260 ? '${text.substring(0, 260)}...' : text,
  };
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return <Map<String, dynamic>>[];
}

String _s(dynamic v, {String fallback = ''}) {
  final text = (v ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

String _firstNotEmpty(List<dynamic> values, {String fallback = ''}) {
  for (final v in values) {
    final text = _s(v);
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _teamName(Map<String, dynamic> row) => _firstNotEmpty([row['team_name'], row['stored_team_name']], fallback: '');

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}'.trim()) ?? 0;
}

String _normalizeImageUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty || value == 'null') return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  if (!value.startsWith('/')) value = '/$value';
  return 'https://sportotekaapp.ru$value';
}

String _attendanceStatus(dynamic raw) {
  switch (_s(raw)) {
    case 'present':
      return 'был';
    case 'absent':
      return 'нет';
    case 'late':
      return 'опоздал';
    case 'injured':
      return 'травма';
    case 'individual':
      return 'индив.';
    case 'dayoff':
      return 'отдых';
    default:
      return _s(raw, fallback: 'статус');
  }
}

String _eventType(dynamic raw) {
  switch (_s(raw)) {
    case 'training':
      return 'Тренировка';
    case 'league':
      return 'Официальная игра';
    case 'friendly':
      return 'Товарищеская игра';
    case 'theory':
      return 'Теория';
    case 'gym':
      return 'Зал';
    case 'day_off':
      return 'Восстановление';
    default:
      return _s(raw, fallback: 'Событие');
  }
}

String _shortDate(String raw) {
  if (raw.trim().isEmpty) return '';
  final normalized = raw.trim().replaceFirst(' ', 'T');
  final dt = DateTime.tryParse(normalized);
  if (dt == null) return raw.length > 10 ? raw.substring(0, 10) : raw;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final time = dt.hour == 0 && dt.minute == 0 ? '' : ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  if (day == today) return 'сегодня$time';
  if (day == today.add(const Duration(days: 1))) return 'завтра$time';
  if (day == today.subtract(const Duration(days: 1))) return 'вчера$time';

  return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}$time';
}
