import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/core/app_export.dart';


// ==================== CMR clean style ====================

class _CmrDashColors {
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF6F8FA);
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color green = Color(0xFF1F7A4D);
  static const Color greenSoft = Color(0xFFF2F7F4);
  static const Color orange = Color(0xFFEA580C);
  static const Color violet = Color(0xFF7C3AED);
}

class _CmrDashText {
  static TextStyle title(double size) => TextStyle(
        color: _CmrDashColors.text,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.12,
      );

  static TextStyle section() => const TextStyle(
        color: _CmrDashColors.text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.18,
      );

  static TextStyle value(double size) => TextStyle(
        color: _CmrDashColors.text,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );

  static TextStyle muted(double size) => TextStyle(
        color: _CmrDashColors.muted,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.35,
      );
}

class _CmrDashDecor {
  static BoxDecoration panel() => BoxDecoration(
        color: _CmrDashColors.panel,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.018),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration softCard({double radius = 22}) => BoxDecoration(
        color: _CmrDashColors.soft,
        borderRadius: BorderRadius.circular(radius),
      );
}

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
  late final dio.Dio _dio;
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
    _dio = dio.Dio(dio.BaseOptions(
      baseUrl: widget.apiBaseUrl.endsWith('/') ? widget.apiBaseUrl : '${widget.apiBaseUrl}/',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      responseType: dio.ResponseType.plain,
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
    final title = _isPlayer ? 'Панель игрока' : 'Рабочая панель';
    final subtitle = _isPlayer
        ? _playerSubtitle()
        : teams.isEmpty
            ? 'Ключевые события команды'
            : 'Команды: ${teams.length}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: title,
                subtitle: subtitle,
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 16 : 20),
              _SummaryStrip(
                summary: summary,
                isPlayer: _isPlayer,
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 16 : 20),
              _buildSectionsVertical(sections, isMobile),
            ],
          ),
        );
      },
    );
  }

  /// Вертикальные секции - каждая идёт последовательно сверху вниз
  Widget _buildSectionsVertical(Map<String, dynamic> sections, bool isMobile) {
    final sectionList = _getSectionList(sections);
    
    return Column(
      children: sectionList.asMap().entries.map((entry) {
        final section = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: entry.key == sectionList.length - 1 ? 0 : (isMobile ? 16 : 20)),
          child: _SectionWithRows(
            title: section.title,
            icon: section.icon,
            color: section.color,
            rows: section.rows,
            emptyTitle: section.emptyTitle,
            emptySubtitle: section.emptySubtitle,
            actionText: section.actionText,
            onTapAll: section.onTapAll,
            builder: section.builder,
            isMobile: isMobile,
          ),
        );
      }).toList(),
    );
  }

  List<_SectionData> _getSectionList(Map<String, dynamic> sections) {
    final items = <_SectionData>[];

    if (_isPlayer) {
      items.addAll([
        _SectionData(
          title: 'События',
          icon: Icons.event_available_rounded,
          color: _CmrDashColors.green,
          rows: _asList(sections['events']),
          emptyTitle: 'Событий пока нет',
          emptySubtitle: 'Тренировки и игры появятся здесь.',
          builder: (row) => _eventRow(row),
        ),
        _SectionData(
          title: 'Матчи',
          icon: Icons.sports_soccer_rounded,
          color: _CmrDashColors.green,
          rows: _asList(sections['matches']),
          emptyTitle: 'Матчей пока нет',
          emptySubtitle: 'Ближайшие и прошедшие игры будут здесь.',
          builder: (row) => _matchRow(row),
        ),
        _SectionData(
          title: 'Посещаемость',
          icon: Icons.check_circle_rounded,
          color: _CmrDashColors.green,
          rows: _asList(sections['attendance']),
          emptyTitle: 'Отметок пока нет',
          emptySubtitle: 'Отметки посещаемости появятся здесь.',
          builder: (row) => _attendanceRow(row),
        ),
        _SectionData(
          title: 'Оценки и тесты',
          actionText: 'Открыть',
          icon: Icons.fact_check_rounded,
          color: _CmrDashColors.orange,
          rows: [..._asList(sections['ratings']), ..._asList(sections['testing'])].take(5).toList(),
          emptyTitle: 'Данных пока нет',
          emptySubtitle: 'Оценки тренера и тестирования будут здесь.',
          onTapAll: () => widget.onOpenModule?.call('testing'),
          builder: (row) => row.containsKey('rating') ? _ratingRow(row) : _testingRow(row),
        ),
      ]);
    } else {
      items.addAll([
        _SectionData(
          title: 'Ближайшие события',
          icon: Icons.event_available_rounded,
          color: _CmrDashColors.green,
          rows: _asList(sections['events']),
          emptyTitle: 'Событий пока нет',
          emptySubtitle: 'Тренировки, игры и встречи появятся здесь.',
          builder: (row) => _eventRow(row),
        ),
        _SectionData(
          title: 'Матчи',
          icon: Icons.sports_soccer_rounded,
          color: _CmrDashColors.green,
          rows: _asList(sections['matches']),
          emptyTitle: 'Матчей пока нет',
          emptySubtitle: 'Ближайшие и последние матчи будут здесь.',
          builder: (row) => _matchRow(row),
        ),
        _SectionData(
          title: 'Посещаемость',
          icon: Icons.how_to_reg_rounded,
          color: _CmrDashColors.green,
          rows: _asList(sections['attendance']),
          emptyTitle: 'Отметок пока нет',
          emptySubtitle: 'Последние отметки игроков появятся здесь.',
          builder: (row) => _attendanceRow(row),
        ),
        _SectionData(
          title: 'Оценки',
          actionText: 'Открыть',
          icon: Icons.star_rounded,
          color: _CmrDashColors.orange,
          rows: _asList(sections['ratings']),
          emptyTitle: 'Оценок пока нет',
          emptySubtitle: 'Оценки игроков появятся здесь.',
          builder: (row) => _ratingRow(row),
        ),
        _SectionData(
          title: 'Тестирование',
          actionText: 'Открыть',
          icon: Icons.fact_check_rounded,
          color: _CmrDashColors.orange,
          rows: _asList(sections['testing']),
          emptyTitle: 'Тестов пока нет',
          emptySubtitle: 'Последние тестирования появятся здесь.',
          onTapAll: () => widget.onOpenModule?.call('testing'),
          builder: (row) => _testingRow(row),
        ),
      ]);
    }

    final withData = items.where((e) => e.rows.isNotEmpty).toList();
    return withData.isNotEmpty ? withData : items.take(3).toList();
  }

  // ==================== СТРОКИ ДЛЯ РАЗНЫХ ТИПОВ ДАННЫХ ====================
  
  Widget _eventRow(Map<String, dynamic> row) {
    return _DashboardRow(
      icon: Icons.event_available_rounded,
      color: _CmrDashColors.green,
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
      color: _CmrDashColors.green,
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
      color: _CmrDashColors.green,
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
      color: _CmrDashColors.orange,
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
      color: _CmrDashColors.orange,
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
      color: _CmrDashColors.violet,
      title: title,
      subtitle: _firstNotEmpty([row['last_message'], row['sender_name']], fallback: 'Нет сообщений'),
      trailing: _shortDate(_s(row['date'])),
      teamName: '',
      onTap: chatId > 0 ? () => widget.onOpenChat?.call(chatId, title) : () => widget.onOpenModule?.call('chats'),
    );
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ====================

  Widget _loadingView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          SizedBox(width: 12),
          Text('Загрузка панели...', style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 12),
          const Text(
            'Не удалось загрузить панель',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            _error,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _CmrDashColors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
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
}

// ==================== ДАННЫЕ СЕКЦИИ ====================

class _SectionData {
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> rows;
  final String emptyTitle;
  final String emptySubtitle;
  final String? actionText;
  final VoidCallback? onTapAll;
  final Widget Function(Map<String, dynamic>) builder;

  _SectionData({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.actionText,
    this.onTapAll,
    required this.builder,
  });
}

// ==================== ВИДЖЕТ СЕКЦИИ СО СТРОКАМИ ====================

class _SectionWithRows extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> rows;
  final String emptyTitle;
  final String emptySubtitle;
  final String? actionText;
  final VoidCallback? onTapAll;
  final Widget Function(Map<String, dynamic>) builder;
  final bool isMobile;

  const _SectionWithRows({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.actionText,
    this.onTapAll,
    required this.builder,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.018),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _CmrDashColors.greenSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: _CmrDashText.section(),
                  ),
                ),
                if (actionText != null && actionText!.isNotEmpty)
                  _ActionButton(
                    text: actionText!,
                    color: color,
                    onTap: onTapAll,
                  ),
              ],
            ),
          ),

          if (rows.isEmpty)
            _EmptyState(
              icon: icon,
              title: emptyTitle,
              subtitle: emptySubtitle,
            )
          else
            ...rows.asMap().entries.map((entry) => Column(
                  children: [
                    builder(entry.value),
                    if (entry.key != rows.length - 1)
                      const SizedBox(height: 2),
                  ],
                )),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.text,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: onTap == null ? const Color(0xFF94A3B8) : color,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        children: [
          Icon(icon, color: _CmrDashColors.green.withOpacity(.35), size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ==================== ОСТАЛЬНЫЕ ВИДЖЕТЫ (Header, Summary, DashboardRow) ====================

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isMobile;

  const _Header({
    required this.title,
    required this.subtitle,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: _CmrDashDecor.panel(),
      child: Row(
        children: [
          Container(
            width: isMobile ? 46 : 52,
            height: isMobile ? 46 : 52,
            decoration: BoxDecoration(
              color: _CmrDashColors.greenSoft,
              borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
            ),
            child: const Icon(Icons.dashboard_customize_rounded, color: _CmrDashColors.green, size: 24),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _CmrDashText.title(isMobile ? 20 : 23),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: _CmrDashText.muted(isMobile ? 12 : 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final Map<String, dynamic> summary;
  final bool isPlayer;
  final bool isMobile;

  const _SummaryStrip({
    required this.summary,
    required this.isPlayer,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = isPlayer
        ? [
            ['События', summary['events'], Icons.event_available_rounded],
            ['Матчи', summary['matches'], Icons.sports_soccer_rounded],
            ['Отметки', summary['attendance'], Icons.how_to_reg_rounded],
            ['Оценки', summary['ratings'], Icons.star_rounded],
          ]
        : [
            ['Команды', summary['teams'], Icons.groups_rounded],
            ['События', summary['events'], Icons.event_available_rounded],
            ['Матчи', summary['matches'], Icons.sports_soccer_rounded],
            ['Отметки', summary['attendance'], Icons.how_to_reg_rounded],
            ['Оценки', summary['ratings'], Icons.star_rounded],
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? items.length : (constraints.maxWidth >= 560 ? 3 : 2);
        final gap = isMobile ? 10.0 : 12.0;
        final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((e) {
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: EdgeInsets.all(isMobile ? 12 : 14),
                decoration: _CmrDashDecor.softCard(radius: 22),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _CmrDashColors.greenSoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(e[2] as IconData, color: _CmrDashColors.green, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e[1] ?? 0}', style: _CmrDashText.title(isMobile ? 18 : 20)),
                          const SizedBox(height: 2),
                          Text('${e[0]}', style: _CmrDashText.muted(11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: _CmrDashDecor.softCard(radius: 20),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _CmrDashColors.greenSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _CmrDashText.value(13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: _CmrDashText.muted(11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    trailing,
                    style: const TextStyle(
                      color: _CmrDashColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

Map<String, dynamic> _decodeServerMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return <String, dynamic>{};

  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}

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