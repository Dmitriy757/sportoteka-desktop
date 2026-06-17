// lib/presentation/club_workspace/cmr_club_overview_panel.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/presentation/testing/cmr_testing_panel.dart';

// ==================== Цветовая схема один в один как в CmrClubTrainersPanel ====================

class _CmrColors {
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF6F8FA);
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color green = Color(0xFF1F7A4D);
  static const Color greenDark = Color(0xFF1F7A4D);
  static const Color greenSoft = Color(0xFFF2F7F4);
  static const Color greenBorder = Color(0xFFD7E8DE);
  static const Color red = Color(0xFFD92D20);
}

// ==================== Текстовые стили один в один как в CmrClubTrainersPanel ====================

class _CmrText {
  static TextStyle title(double size) => TextStyle(
        color: _CmrColors.text,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.12,
      );

  static TextStyle section() => const TextStyle(
        color: _CmrColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        height: 1.18,
      );

  static TextStyle value(double size) => TextStyle(
        color: _CmrColors.text,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.35,
      );

  static TextStyle muted(double size) => TextStyle(
        color: _CmrColors.muted,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.42,
      );

  static TextStyle caption() => const TextStyle(
        color: _CmrColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.15,
      );

  static TextStyle pill() => const TextStyle(
        color: _CmrColors.text,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      );

  static TextStyle tab() => const TextStyle(
        color: _CmrColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      );

  static TextStyle tabSelected() => const TextStyle(
        color: _CmrColors.green,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      );

  static TextStyle action() => const TextStyle(
        color: _CmrColors.green,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      );

  static TextStyle danger() => const TextStyle(
        color: _CmrColors.red,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      );
}

// ==================== Декораторы один в один как в CmrClubTrainersPanel ====================

class _CmrDecor {
  static BoxDecoration panel() => BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE8EEF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration softCard({double radius = 22}) => BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(radius),
      );
}

class CmrClubOverviewPanel extends StatelessWidget {
  final int clubId;
  final String clubName;
  final String? clubLogo;
  final String clubDescription;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> trainers;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> latestPlans;
  final List<Map<String, dynamic>> news;
  final List<Map<String, dynamic>> latestTrainings;
  final List<Map<String, dynamic>> latestTests;
  final List<Map<String, dynamic>> players;
  final int playersCount;
  final int? selectedTeamId;
  final String selectedTeamName;
  final bool trainerAssignedMode;
  final int trainerWorkspaceId;
  final ValueChanged<Map<String, dynamic>> onTeamChanged;
  final VoidCallback onRefresh;
  final VoidCallback onEditClub;
  final VoidCallback onCreateTeam;
  final VoidCallback onEditTeam;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenPlans;
  final VoidCallback onOpenChats;
  final VoidCallback? onOpenTrainings;
  final VoidCallback? onOpenTesting;
  final ValueChanged<Map<String, dynamic>>? onOpenPlayer;
  final ValueChanged<Map<String, dynamic>>? onExportPlan;
  final ValueChanged<Map<String, dynamic>>? onExportEvent;
  final ValueChanged<Map<String, dynamic>>? onExportTraining;
  final ValueChanged<Map<String, dynamic>>? onExportTesting;
  final VoidCallback? onExportOverview;

  const CmrClubOverviewPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.clubLogo,
    required this.clubDescription,
    required this.teams,
    required this.trainers,
    required this.events,
    required this.latestPlans,
    this.news = const <Map<String, dynamic>>[],
    this.latestTrainings = const <Map<String, dynamic>>[],
    this.latestTests = const <Map<String, dynamic>>[],
    this.players = const <Map<String, dynamic>>[],
    required this.playersCount,
    required this.selectedTeamId,
    required this.selectedTeamName,
    required this.trainerAssignedMode,
    required this.trainerWorkspaceId,
    required this.onTeamChanged,
    required this.onRefresh,
    required this.onEditClub,
    required this.onCreateTeam,
    required this.onEditTeam,
    required this.onOpenTeams,
    required this.onOpenRoster,
    required this.onOpenTrainers,
    required this.onOpenMatches,
    required this.onOpenCalendar,
    required this.onOpenPlans,
    required this.onOpenChats,
    this.onOpenTrainings,
    this.onOpenTesting,
    this.onOpenPlayer,
    this.onExportPlan,
    this.onExportEvent,
    this.onExportTraining,
    this.onExportTesting,
    this.onExportOverview,
  });

  String _s(Object? value, [String fallback = '']) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  int _i(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

  int _teamId(Map<String, dynamic> team) => _i(team['id'] ?? team['team_id'] ?? team['teamId']);

  String _teamName(Map<String, dynamic> team) =>
      _s(team['name'] ?? team['team_name'] ?? team['title'], 'Команда');

  String _teamSubtitle(Map<String, dynamic> team) =>
      _s(team['age_group'] ?? team['category'] ?? team['sport'], 'Футбол');

  String? _image(Map<String, dynamic>? item) {
    if (item == null) return null;
    final raw = _s(
      item['logo'] ??
          item['logo_url'] ??
          item['photo'] ??
          item['photo_url'] ??
          item['avatar'] ??
          item['avatar_url'] ??
          item['image'] ??
          item['image_url'] ??
          item['profile_photo'] ??
          item['player_photo'] ??
          item['photo_path'],
    );
    if (raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/$raw';
  }

  Map<String, dynamic>? _activeTeam() {
    for (final team in teams) {
      if (_teamId(team) == selectedTeamId) return team;
    }
    return teams.isNotEmpty ? teams.first : null;
  }


  int _itemTeamId(Map<String, dynamic> item) => _i(
        item['team_id'] ??
            item['teamId'] ??
            item['team'] ??
            item['club_team_id'] ??
            item['owner_team_id'],
      );

  int _itemTrainerId(Map<String, dynamic> item) => _i(
        item['trainer_id'] ??
            item['trainerId'] ??
            item['coach_id'] ??
            item['coachId'] ??
            item['author_id'] ??
            item['created_by'] ??
            item['user_id'],
      );

  Set<int> get _visibleTeamIds {
    final ids = <int>{};
    for (final team in teams) {
      final id = _teamId(team);
      if (id > 0) ids.add(id);
    }
    return ids;
  }

  bool _inVisibleScope(Map<String, dynamic> item) {
    if (!trainerAssignedMode) return true;
    final teamId = _itemTeamId(item);
    final ids = _visibleTeamIds;
    if (teamId > 0 && ids.contains(teamId)) return true;
    final trainerId = _itemTrainerId(item);
    if (trainerWorkspaceId > 0 && trainerId == trainerWorkspaceId) return true;
    return teamId == 0 && trainerId == 0 && ids.isEmpty;
  }

  List<Map<String, dynamic>> _scoped(List<Map<String, dynamic>> source) {
    if (!trainerAssignedMode) return source;
    return source.where(_inVisibleScope).toList();
  }

  List<Map<String, dynamic>> get _scopedEvents => _scoped(events);
  List<Map<String, dynamic>> get _scopedPlans => _scoped(latestPlans);
  List<Map<String, dynamic>> get _scopedNews => _scoped(news);
  List<Map<String, dynamic>> get _scopedPlayers => _scoped(players);

  String _playerName(Map<String, dynamic> player) {
    final full = _s(
      player['full_name'] ??
          player['fullName'] ??
          player['player_name'] ??
          player['playerName'] ??
          player['name'] ??
          player['fio'],
    );
    if (full.isNotEmpty) return full;
    final last = _s(player['last_name'] ?? player['lastName'] ?? player['lastname'] ?? player['surname']);
    final first = _s(player['first_name'] ?? player['firstName'] ?? player['firstname']);
    final middle = _s(player['middle_name'] ?? player['middleName'] ?? player['middlename']);
    final name = [last, first, middle].where((e) => e.trim().isNotEmpty).join(' ').trim();
    return name.isEmpty ? 'Игрок' : name;
  }

  String _playerPosition(Map<String, dynamic> player) => _s(
        player['position'] ?? player['role'] ?? player['amplua'] ?? player['amp'] ?? player['player_position'],
        'Позиция не указана',
      );

  int _playerId(Map<String, dynamic> player) => _i(
        player['id'] ??
            player['player_id'] ??
            player['playerId'] ??
            player['student_id'] ??
            player['athlete_id'],
      );

  String _playerTeamName(Map<String, dynamic> player) => _s(
        player['team_name'] ?? player['teamName'] ?? player['club_team_name'],
        selectedTeamName.isEmpty ? 'Команда' : selectedTeamName,
      );

  String _nameKey(String value) => value
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
      .trim();

  String _playerWarningKey(Map<String, dynamic> player) {
    final id = _playerId(player);
    if (id > 0) return 'id:$id';
    return 'name:${_nameKey(_playerName(player))}|team:${_nameKey(_playerTeamName(player))}';
  }

  bool _warningMatchesPlayer(_CmrTestWarning warning, Map<String, dynamic> player) {
    final playerId = _playerId(player);
    if (warning.playerId > 0 && playerId > 0 && warning.playerId == playerId) return true;

    final playerName = _nameKey(_playerName(player));
    final warningName = _nameKey(warning.playerName);
    if (playerName.isEmpty || warningName.isEmpty) return false;

    final teamId = _itemTeamId(player);
    if (warning.teamId > 0 && teamId > 0 && warning.teamId != teamId) return false;

    return playerName == warningName || playerName.contains(warningName) || warningName.contains(playerName);
  }

  List<_CmrTestWarning> _warningsForPlayer(
    Map<String, dynamic> player,
    List<_CmrTestWarning> warnings,
  ) {
    return warnings.where((warning) => _warningMatchesPlayer(warning, player)).toList();
  }

  Map<String, dynamic> _playerStubFromWarning(_CmrTestWarning warning) {
    return <String, dynamic>{
      if (warning.playerId > 0) 'id': warning.playerId,
      if (warning.playerId > 0) 'player_id': warning.playerId,
      if (warning.teamId > 0) 'team_id': warning.teamId,
      'team_name': warning.teamName,
      'full_name': warning.playerName,
      'name': warning.playerName,
      if (warning.photo.isNotEmpty) 'photo': warning.photo,
      if (warning.photo.isNotEmpty) 'photo_url': warning.photo,
      'position': warning.teamName.isEmpty ? 'Нужно внимание тренера' : warning.teamName,
      '_cmr_from_warning': true,
    };
  }

  List<Map<String, dynamic>> _playersWithWarningPriority(
    List<Map<String, dynamic>> source,
    List<_CmrTestWarning> warnings, {
    int limit = 8,
    bool onlyWithWarnings = false,
  }) {
    final unique = <String, Map<String, dynamic>>{};

    for (final player in source) {
      unique[_playerWarningKey(player)] = Map<String, dynamic>.from(player);
    }

    for (final warning in warnings) {
      final nameKey = _nameKey(warning.playerName);
      if (nameKey.isEmpty || nameKey == 'игроки команды' || nameKey == 'игрок') continue;

      final alreadyExists = unique.values.any((player) => _warningMatchesPlayer(warning, player));
      if (!alreadyExists) {
        final stub = _playerStubFromWarning(warning);
        unique[_playerWarningKey(stub)] = stub;
      }
    }

    final result = unique.values.toList();
    result.sort((a, b) {
      final aw = _warningsForPlayer(a, warnings).length;
      final bw = _warningsForPlayer(b, warnings).length;
      if (aw != bw) return bw.compareTo(aw);
      return _playerName(a).compareTo(_playerName(b));
    });

    final visible = onlyWithWarnings
        ? result.where((player) => _warningsForPlayer(player, warnings).isNotEmpty).toList()
        : result;

    return visible.take(limit).toList();
  }

  String _warningPreviewForPlayer(Map<String, dynamic> player, List<_CmrTestWarning> warnings) {
    final items = _warningsForPlayer(player, warnings);
    if (items.isEmpty) return '';
    final first = items.first;
    if (items.length == 1) return first.message;
    return '${items.length} предупреждения: ${first.message}';
  }

  void _openTestingForWarning(BuildContext context, _CmrTestWarning warning) {
    final teamId = warning.teamId > 0 ? warning.teamId : (selectedTeamId ?? 0);
    final teamName = warning.teamName.trim().isNotEmpty && warning.teamName.trim() != 'Команда'
        ? warning.teamName.trim()
        : (selectedTeamName.trim().isNotEmpty ? selectedTeamName.trim() : 'Команда');

    if (teamId <= 0) {
      onOpenTesting?.call();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: CmrTestingPanel(
              clubId: clubId,
              teamId: teamId,
              clubName: clubName,
              teamName: teamName,
              initialPlayerId: warning.playerId > 0 ? warning.playerId : null,
              initialPlayerName: warning.playerName.trim().isNotEmpty ? warning.playerName.trim() : null,
              onBackToMenu: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
    );
  }

  void _openAllWarningsSheet(BuildContext context, List<_CmrTestWarning> warnings) {
    if (warnings.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CmrAllWarningsSheet(
        warnings: warnings,
        onOpenTesting: onOpenTesting,
        onOpenWarning: (warning) => _openTestingForWarning(context, warning),
      ),
    );
  }

  String _latestTrainingTitle() {
    final items = _trainingItems;
    if (items.isEmpty) return 'Тренировок нет';
    return _s(items.first['title'] ?? items.first['name'] ?? items.first['training_title'], 'Тренировка');
  }

  List<Map<String, dynamic>> get _trainingItems {
    final base = latestTrainings.isNotEmpty
        ? latestTrainings
        : _scopedEvents.where((event) {
            final type = _s(event['type'] ?? event['event_type'] ?? event['category'] ?? event['kind']).toLowerCase();
            final title = _s(event['title'] ?? event['name'] ?? event['event_title']).toLowerCase();
            return type.contains('training') ||
                type.contains('трен') ||
                title.contains('тренировка') ||
                title.contains('занятие');
          }).toList();
    final items = _scoped(base);
    items.sort((a, b) {
      final ad = DateTime.tryParse(_s(a['date'] ?? a['training_date'] ?? a['start_at'] ?? a['created_at']).replaceAll(' ', 'T'));
      final bd = DateTime.tryParse(_s(b['date'] ?? b['training_date'] ?? b['start_at'] ?? b['created_at']).replaceAll(' ', 'T'));
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return items.take(6).toList();
  }

  List<Map<String, dynamic>> get _testingItems => _scoped(latestTests).take(6).toList();

  List<Map<String, dynamic>> get _matchEvents {
    final result = _scopedEvents.where((event) {
      final type = _s(event['type'] ?? event['event_type'] ?? event['category'] ?? event['kind']).toLowerCase();
      final title = _s(event['title'] ?? event['name'] ?? event['event_title']).toLowerCase();
      return type.contains('match') ||
          type.contains('game') ||
          type.contains('матч') ||
          type.contains('игра') ||
          title.contains('матч') ||
          title.contains('игра') ||
          title.contains('турнир') ||
          title.contains('кубок') ||
          title.contains('чемпионат');
    }).toList();
    final source = result.isEmpty ? _scopedEvents : result;
    source.sort((a, b) {
      final ad = DateTime.tryParse(_s(a['date'] ?? a['event_date'] ?? a['start_date'] ?? a['start_at'] ?? a['startAt'] ?? a['match_date']).replaceAll(' ', 'T'));
      final bd = DateTime.tryParse(_s(b['date'] ?? b['event_date'] ?? b['start_date'] ?? b['start_at'] ?? b['startAt'] ?? b['match_date']).replaceAll(' ', 'T'));
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return source.take(6).toList();
  }

  List<Map<String, dynamic>> get _visibleNews {
    if (_scopedNews.isNotEmpty) return _scopedNews.take(4).toList();
    return _scopedEvents.where((event) {
      final type = _s(event['type'] ?? event['event_type'] ?? event['category']).toLowerCase();
      return type.contains('news') || type.contains('нов');
    }).take(4).toList();
  }

  String _dateText(Map<String, dynamic> item) {
    final raw = _s(item['date'] ?? item['event_date'] ?? item['start_date'] ?? item['start_at'] ?? item['startAt'] ?? item['start'] ?? item['match_date'] ?? item['created_at']);
    if (raw.isEmpty) return 'Дата не указана';
    final parsed = DateTime.tryParse(raw.replaceAll(' ', 'T'));
    if (parsed == null) return raw.length > 16 ? raw.substring(0, 16) : raw;
    final d = parsed.day.toString().padLeft(2, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    final hasTime = parsed.hour != 0 || parsed.minute != 0;
    return hasTime ? '$d.$m • $hh:$mm' : '$d.$m.${parsed.year}';
  }

  String _trainerName(Map<String, dynamic> item) {
    final explicit = _s(item['trainer_name'] ?? item['coach_name'] ?? item['author_name'] ?? item['created_by_name']);
    if (explicit.isNotEmpty) return explicit;
    final first = _s(item['first_name'] ?? item['firstname']);
    final last = _s(item['last_name'] ?? item['lastname']);
    final full = _s(item['full_name'] ?? item['fullName'] ?? item['name'], '$first $last').trim();
    return full.isEmpty ? 'Тренер' : full;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * .82;
        final activeTeam = _activeTeam();
        final selectedName = activeTeam == null ? selectedTeamName : _teamName(activeTeam);

        return SizedBox(
          height: height,
          child: _buildUnifiedOverview(
            context,
            activeTeam,
            selectedName,
            compact: compact,
            width: constraints.maxWidth,
          ),
        );
      },
    );
  }

  Widget _buildUnifiedOverview(
    BuildContext context,
    Map<String, dynamic>? activeTeam,
    String selectedName, {
    required bool compact,
    required double width,
  }) {
    final twoColumns = !compact && width >= 1040;
    final medium = !compact && width >= 820;

    return _CmrScrollPanel(
      onRefresh: onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _overviewBanner(activeTeam, selectedName, compact: compact),
          const SizedBox(height: 14),
          _statsGrid(compact: compact),
          const SizedBox(height: 14),
          _CmrNotice(
            icon: trainerAssignedMode ? Icons.lock_open_rounded : Icons.dashboard_customize_rounded,
            title: trainerAssignedMode ? 'Обзор закреплённых команд' : 'Единая сводка клуба',
            text: trainerAssignedMode
                ? 'Тренер видит только свои команды: события, планы, тесты, новости и связь собраны в одной рабочей панели.'
                : 'Здесь собраны события по всем командам клуба, последние планы, новости, чаты и быстрые действия в одном аккуратном рабочем блоке.',
          ),
          const SizedBox(height: 18),
          _simpleSectionTitle('Быстрый доступ'),
          const SizedBox(height: 10),
          _euroKpiStrip(wrap: compact),
          const SizedBox(height: 12),
          if (twoColumns)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: _clubEventsSummaryBlock(context)),
                const SizedBox(width: 12),
                Expanded(flex: 13, child: _exportHubBlock(context)),
              ],
            )
          else ...[
            _clubEventsSummaryBlock(context),
            const SizedBox(height: 12),
            _exportHubBlock(context),
          ],
          const SizedBox(height: 12),
          _playersAndTestingBlock(context),
          const SizedBox(height: 12),
          if (twoColumns)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: _matchCalendarBlock(context)),
                const SizedBox(width: 12),
                Expanded(flex: 13, child: _plansBlock(context)),
              ],
            )
          else ...[
            _matchCalendarBlock(context),
            const SizedBox(height: 12),
            _plansBlock(context),
          ],
          const SizedBox(height: 12),
          if (medium)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _trainingSummaryBlock(context)),
                const SizedBox(width: 12),
                Expanded(child: _newsFeedBlock()),
              ],
            )
          else ...[
            _trainingSummaryBlock(context),
            const SizedBox(height: 12),
            _newsFeedBlock(),
          ],
          const SizedBox(height: 12),
          if (medium)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _communicationBlock()),
                const SizedBox(width: 12),
                Expanded(child: _managementBlock()),
              ],
            )
          else ...[
            _communicationBlock(),
            const SizedBox(height: 12),
            _managementBlock(),
          ],
        ],
      ),
    );
  }
  void _showExportMessage(BuildContext context, String title) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('$title: подключите обработчик экспорта в родительском экране'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _teamNameFromItem(Map<String, dynamic> item) {
    return _s(
      item['team_name'] ??
          item['teamName'] ??
          item['club_name'] ??
          item['clubName'] ??
          item['team_title'] ??
          item['group_name'],
      selectedTeamName.trim().isEmpty ? 'Все команды' : selectedTeamName,
    );
  }

  Map<String, List<Map<String, dynamic>>> _eventsGroupedByTeam() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final event in _matchEvents) {
      final key = _teamNameFromItem(event);
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(event);
    }
    return grouped;
  }

  Widget _clubEventsSummaryBlock(BuildContext context) {
    final grouped = _eventsGroupedByTeam();
    final totalEvents = _matchEvents.length;
    final activeTeams = grouped.keys.where((e) => e.trim().isNotEmpty).length;
    final nextTitle = _nextEventTitle();

    return _CmrBlock(
      icon: Icons.event_note_rounded,
      title: 'События по всем командам',
      actionTitle: 'Календарь',
      onAction: onOpenCalendar,
      child: Column(
        children: [
          _adaptiveGrid(
            minItemWidth: 150,
            maxColumns: 3,
            children: [
              _CmrMetricPill(
                icon: Icons.calendar_month_rounded,
                value: '$totalEvents',
                label: 'событий',
              ),
              _CmrMetricPill(
                icon: Icons.account_tree_rounded,
                value: '$activeTeams',
                label: 'команд',
              ),
              _CmrMetricPill(
                icon: Icons.assignment_rounded,
                value: '${_scopedPlans.length}',
                label: 'планов',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CmrInfoTile(
            icon: Icons.flag_rounded,
            title: totalEvents == 0 ? 'Нет ближайших событий' : nextTitle,
            subtitle: totalEvents == 0
                ? 'Добавьте матчи, тренировки или клубные события'
                : '${_dateText(_matchEvents.first)} · ${_teamNameFromItem(_matchEvents.first)}',
            onTap: onOpenCalendar,
          ),
          if (grouped.isNotEmpty) ...[
            const SizedBox(height: 2),
            ...grouped.entries.take(4).map((entry) {
              final first = entry.value.first;
              return _CmrInfoTile(
                icon: Icons.groups_rounded,
                title: entry.key,
                subtitle: '${entry.value.length} событий · ближайшее: ${_dateText(first)}',
                trailing: 'Открыть',
                onTap: onOpenCalendar,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _trainingSummaryBlock(BuildContext context) {
    final trainings = _trainingItems;
    return _CmrBlock(
      icon: Icons.fitness_center_rounded,
      title: 'Тренировки',
      actionTitle: 'Открыть',
      onAction: onOpenTrainings ?? onOpenCalendar,
      child: trainings.isEmpty
          ? _CmrSoftState(
              icon: Icons.fitness_center_rounded,
              title: 'Тренировки пока не найдены',
              text: trainerAssignedMode
                  ? 'Здесь появятся тренировки по закреплённым за тренером командам.'
                  : 'Здесь появятся тренировки по всем командам клуба.',
              buttonText: 'Открыть календарь',
              onTap: onOpenTrainings ?? onOpenCalendar,
            )
          : Column(
              children: trainings.map((training) {
                final title = _s(training['title'] ?? training['name'] ?? training['training_title'], 'Тренировка');
                final team = _teamNameFromItem(training);
                final trainer = _trainerName(training);
                return _CmrInfoTile(
                  icon: Icons.sports_handball_rounded,
                  title: title,
                  subtitle: '${_dateText(training)} · $team · $trainer',
                  trailing: _s(training['status'] ?? training['type'], ''),
                  onTap: onOpenTrainings ?? onOpenCalendar,
                );
              }).toList(),
            ),
    );
  }

  Widget _playersAndTestingBlock(BuildContext context) {
    return FutureBuilder<_CmrLiveOverviewData>(
      future: _loadLiveOverviewData(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? _CmrLiveOverviewData(
          players: _scopedPlayers,
          tests: _testingItems,
          warnings: _warningsFromLocalTests(),
        );
        final isLoading = snapshot.connectionState == ConnectionState.waiting && data.players.isEmpty && data.tests.isEmpty;
        final warnings = data.warnings;
        final priorityPlayers = _playersWithWarningPriority(
          data.players,
          warnings,
          limit: 12,
          onlyWithWarnings: warnings.isNotEmpty,
        );
        return _CmrBlock(
          icon: Icons.fact_check_rounded,
          title: 'Игроки и тесты',
          actionTitle: warnings.isNotEmpty ? 'Все ${warnings.length}' : 'Тесты',
          onAction: warnings.isNotEmpty ? () => _openAllWarningsSheet(context, warnings) : onOpenTesting,
          child: isLoading
              ? const _CmrInlineEmpty(
                  icon: Icons.hourglass_top_rounded,
                  title: 'Загружаем игроков и тесты',
                  text: 'Проверяем последние сессии тестирования по доступным командам.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (warnings.isNotEmpty) ...[
                      _CmrWarningsCompactHeader(
                        totalCount: warnings.length,
                        visibleCount: priorityPlayers.length,
                        onShowAll: () => _openAllWarningsSheet(context, warnings),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _playersMiniGrid(priorityPlayers, warnings),
                    const SizedBox(height: 10),
                    _testsMiniList(data.tests),
                  ],
                ),
        );
      },
    );
  }

  Widget _playersMiniGrid(List<Map<String, dynamic>> items, List<_CmrTestWarning> warnings) {
    if (items.isEmpty) {
      return const _CmrInlineEmpty(
        icon: Icons.groups_2_rounded,
        title: 'Игроки не загружены',
        text: 'Когда список игроков будет доступен, они появятся небольшими карточками.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 560
                ? 3
                : constraints.maxWidth >= 390
                    ? 2
                    : 1;
        final spacing = 10.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((player) {
            final playerWarnings = _warningsForPlayer(player, warnings);
            final hasWarning = playerWarnings.isNotEmpty;
            return SizedBox(
              width: width,
              child: _CmrPlayerMiniCard(
                name: _playerName(player),
                subtitle: _playerPosition(player),
                photo: _image(player),
                badge: _s(player['number'] ?? player['player_number'] ?? player['shirt_number']),
                hasWarning: hasWarning,
                warningCount: playerWarnings.length,
                warningText: _warningPreviewForPlayer(player, warnings),
                onTap: hasWarning
                    ? () => _openTestingForWarning(context, playerWarnings.first)
                    : (onOpenPlayer == null ? null : () => onOpenPlayer!(player)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _testsMiniList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return _CmrInfoTile(
        icon: Icons.rule_rounded,
        title: 'Последние тесты не найдены',
        subtitle: 'Откройте раздел тестирования, чтобы добавить результаты игроков',
        onTap: onOpenTesting,
      );
    }
    return Column(
      children: items.take(4).map((test) {
        final title = _s(test['title'] ?? test['name'] ?? test['category_title'], 'Тестирование');
        final team = _teamNameFromItem(test);
        final badCount = _i(test['poor_count'] ?? test['warnings_count'] ?? test['bad_count']);
        return _CmrInfoTile(
          icon: badCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
          title: title,
          subtitle: '${_dateText(test)} · $team${badCount > 0 ? ' · предупреждений: $badCount' : ''}',
          trailing: badCount > 0 ? 'Важно' : 'Ок',
          onTap: onOpenTesting,
        );
      }).toList(),
    );
  }

  List<_CmrTestWarning> _warningsFromLocalTests() {
    final warnings = <_CmrTestWarning>[];
    for (final test in _testingItems) {
      final badCount = _i(test['poor_count'] ?? test['warnings_count'] ?? test['bad_count']);
      if (badCount <= 0) continue;
      warnings.add(_CmrTestWarning(
        playerId: _i(test['player_id'] ?? test['playerId'] ?? test['athlete_id']),
        teamId: _itemTeamId(test),
        playerName: _s(test['player_name'] ?? test['full_name'], 'Игроки команды'),
        testTitle: _s(test['title'] ?? test['name'] ?? test['category_title'], 'Тестирование'),
        teamName: _teamNameFromItem(test),
        weakCount: badCount,
        severity: badCount >= 3 ? 'critical' : 'warning',
        message: 'Есть слабые оценки: $badCount. Тренеру стоит проверить нагрузку и индивидуальный план.',
        photo: _image(test) ?? '',
      ));
    }
    return warnings;
  }

  Future<_CmrLiveOverviewData> _loadLiveOverviewData() async {
    final ids = _visibleTeamIds.toList();
    final resultPlayers = <Map<String, dynamic>>[];
    final resultTests = <Map<String, dynamic>>[];
    final warnings = <_CmrTestWarning>[];

    if (_scopedPlayers.isNotEmpty) {
      resultPlayers.addAll(_scopedPlayers);
    }

    for (final team in teams) {
      final teamId = _teamId(team);
      if (teamId <= 0) continue;
      if (trainerAssignedMode && ids.isNotEmpty && !ids.contains(teamId)) continue;
      final teamName = _teamName(team);
      if (resultPlayers.where((p) => _itemTeamId(p) == teamId).isEmpty) {
        resultPlayers.addAll(await _fetchPlayersForTeam(teamId, teamName));
      }
      final latest = await _fetchLatestTestingForTeam(teamId, teamName);
      resultTests.addAll(latest.tests);
      warnings.addAll(latest.warnings);
    }

    final localTests = _testingItems;
    if (localTests.isNotEmpty) resultTests.insertAll(0, localTests);
    warnings.insertAll(0, _warningsFromLocalTests());

    final uniquePlayers = <int, Map<String, dynamic>>{};
    final noIdPlayers = <Map<String, dynamic>>[];
    final noIdKeys = <String>{};
    for (final p in resultPlayers) {
      final id = _playerId(p);
      if (id > 0) {
        uniquePlayers[id] = p;
      } else {
        final key = _playerWarningKey(p);
        if (noIdKeys.add(key)) noIdPlayers.add(p);
      }
    }

    final allPlayers = [...uniquePlayers.values, ...noIdPlayers];
    final enrichedWarnings = _uniqueWarnings(warnings)
        .map((warning) => _warningWithPlayerData(warning, allPlayers))
        .toList();

    return _CmrLiveOverviewData(
      players: allPlayers,
      tests: resultTests.take(6).toList(),
      warnings: enrichedWarnings,
    );
  }

  _CmrTestWarning _warningWithPlayerData(
    _CmrTestWarning warning,
    List<Map<String, dynamic>> players,
  ) {
    Map<String, dynamic>? player;
    for (final item in players) {
      if (_warningMatchesPlayer(warning, item)) {
        player = item;
        break;
      }
    }
    if (player == null) return warning;

    final playerName = _playerName(player);
    final photo = _image(player) ?? warning.photo;
    final teamName = _playerTeamName(player);

    if (playerName == warning.playerName && photo == warning.photo && teamName == warning.teamName) {
      return warning;
    }

    return _CmrTestWarning(
      playerId: warning.playerId > 0 ? warning.playerId : _playerId(player),
      teamId: warning.teamId > 0 ? warning.teamId : _itemTeamId(player),
      playerName: playerName == 'Игрок' ? warning.playerName : playerName,
      testTitle: warning.testTitle,
      teamName: teamName == 'Команда' ? warning.teamName : teamName,
      message: warning.message,
      photo: photo,
      weakCount: warning.weakCount,
      severity: warning.severity,
    );
  }

  List<_CmrTestWarning> _uniqueWarnings(List<_CmrTestWarning> source) {
    final map = <String, _CmrTestWarning>{};
    for (final warning in source) {
      final idPart = warning.playerId > 0 ? 'id:${warning.playerId}' : 'name:${_nameKey(warning.playerName)}';
      final teamPart = warning.teamId > 0 ? 'team:${warning.teamId}' : 'team:${_nameKey(warning.teamName)}';
      final key = '$idPart|$teamPart|${_nameKey(warning.testTitle)}|${_nameKey(warning.message)}';
      map[key] = warning;
    }
    return map.values.toList();
  }

  Future<List<Map<String, dynamic>>> _fetchPlayersForTeam(int teamId, String teamName) async {
    try {
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_players_by_team.php').replace(
        queryParameters: {'team_id': '$teamId'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final decoded = _decodeLoose(response.body);
      final raw = decoded is Map
          ? (decoded['players'] ?? decoded['data'] ?? decoded['items'] ?? <dynamic>[])
          : decoded;
      if (raw is! List) return <Map<String, dynamic>>[];
      return raw.whereType<Map>().map((e) {
        final item = Map<String, dynamic>.from(e);
        item['team_id'] ??= teamId;
        item['team_name'] ??= teamName;
        return item;
      }).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<_CmrTestingLoadResult> _fetchLatestTestingForTeam(int teamId, String teamName) async {
    try {
      // Для обзора берём матрицу напрямую: она сама может вернуть последнюю сессию и игроков.
      // Так панель не зависит от get_testing_sessions.php, где часто нужны category/stage.
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_testing_matrix.php').replace(
        queryParameters: {
          'club_id': '$clubId',
          'team_id': '$teamId',
          'category': 'physical',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final decoded = _decodeLoose(response.body);
      if (decoded is! Map || decoded['success'] != true) return const _CmrTestingLoadResult();

      final sessionId = _i(decoded['session_id'] ?? decoded['id']);
      final rawPlayers = decoded['players'] ?? <dynamic>[];
      final players = rawPlayers is List
          ? rawPlayers.whereType<Map>().map((e) {
              final item = Map<String, dynamic>.from(e);
              item['team_id'] ??= teamId;
              item['team_name'] ??= teamName;
              return item;
            }).toList()
          : <Map<String, dynamic>>[];
      if (sessionId <= 0 && players.isEmpty) return const _CmrTestingLoadResult();

      final warnings = _warningsFromMatrixPlayers(players, teamId, teamName, 'Физическое тестирование');
      final testedCount = players.where((player) {
        final results = player['results'];
        return results is Map && results.values.any((v) => v is Map && _s(v['value']).isNotEmpty);
      }).length;

      final item = <String, dynamic>{
        'id': sessionId,
        'session_id': sessionId,
        'team_id': teamId,
        'team_name': teamName,
        'title': 'Физическое тестирование',
        'name': 'Физическое тестирование',
        'category_title': 'Тесты игроков',
        'results_count': testedCount,
        'poor_count': warnings.length,
        'warnings_count': warnings.length,
      };

      return _CmrTestingLoadResult(
        tests: sessionId > 0 || testedCount > 0 ? [item] : const <Map<String, dynamic>>[],
        warnings: warnings,
      );
    } catch (_) {
      return const _CmrTestingLoadResult();
    }
  }

  Future<List<_CmrTestWarning>> _fetchWarningsForTesting(int teamId, String teamName, Map<String, dynamic> session) async {
    try {
      final date = _s(session['test_date'] ?? session['date'] ?? session['created_at']);
      final stage = _s(session['stage'], 'U13');
      final category = _s(session['category'], 'physical');
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_testing_matrix.php').replace(
        queryParameters: {
          'club_id': '$clubId',
          'team_id': '$teamId',
          'category': category,
          'stage': stage,
          if (date.isNotEmpty) 'test_date': date.length >= 10 ? date.substring(0, 10) : date,
          if (_i(session['id']) > 0) 'session_id': '${_i(session['id'])}',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final decoded = _decodeLoose(response.body);
      final rawPlayers = decoded is Map ? (decoded['players'] ?? <dynamic>[]) : <dynamic>[];
      final players = rawPlayers is List
          ? rawPlayers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final warnings = <_CmrTestWarning>[];
      for (final player in players) {
        final results = player['results'];
        if (results is! Map) continue;
        final weak = <String>[];
        results.forEach((key, value) {
          if (value is Map) {
            final rating = _s(value['rating'] ?? value['rating_code'] ?? value['code']).toLowerCase();
            final label = _s(value['label'] ?? value['rating_label']).toLowerCase();
            if (rating.contains('poor') || label.contains('неуд') || label.contains('слаб')) {
              weak.add('$key');
            }
          }
        });
        if (weak.isEmpty) continue;
        warnings.add(_CmrTestWarning(
          playerId: _playerId(player),
          teamId: teamId,
          playerName: _playerName(player),
          testTitle: _s(session['title'] ?? session['name'], 'Тестирование'),
          teamName: teamName,
          weakCount: weak.length,
          severity: weak.length >= 3 ? 'critical' : 'warning',
          message: 'Слабая оценка по ${weak.take(2).join(', ')}. Проверьте нагрузку и добавьте индивидуальную корректировку.',
          photo: _image(player) ?? '',
        ));
      }
      return warnings;
    } catch (_) {
      return <_CmrTestWarning>[];
    }
  }

  List<_CmrTestWarning> _warningsFromMatrixPlayers(
    List<Map<String, dynamic>> players,
    int teamId,
    String teamName,
    String testTitle,
  ) {
    final warnings = <_CmrTestWarning>[];
    for (final player in players) {
      final results = player['results'];
      if (results is! Map) continue;

      final weak = <String>[];
      results.forEach((key, value) {
        if (value is Map) {
          final rating = _s(value['rating'] ?? value['rating_code'] ?? value['code']).toLowerCase();
          final label = _s(value['label'] ?? value['rating_label']).toLowerCase();
          final points = _i(value['points']);
          if (rating.contains('poor') ||
              label.contains('неуд') ||
              label.contains('слаб') ||
              (points > 0 && points <= 1)) {
            weak.add(_s(value['short_title'] ?? value['test_title'] ?? value['title'] ?? key, '$key'));
          }
        }
      });

      if (weak.isEmpty) continue;

      final weakText = weak.take(3).join(', ');
      final extra = weak.length > 3 ? ' и ещё ${weak.length - 3}' : '';
      warnings.add(_CmrTestWarning(
        playerId: _playerId(player),
        teamId: teamId,
        playerName: _playerName(player),
        testTitle: testTitle,
        teamName: teamName,
        weakCount: weak.length,
        severity: weak.length >= 3 ? 'critical' : 'warning',
        message: 'Слабая оценка по $weakText$extra. Проверьте нагрузку и добавьте индивидуальную корректировку.',
        photo: _image(player) ?? '',
      ));
    }
    return warnings;
  }

  dynamic _decodeLoose(String body) {
    final clean = body.trim();
    final object = clean.indexOf('{');
    final array = clean.indexOf('[');
    final starts = [object, array].where((e) => e >= 0).toList();
    if (starts.isEmpty) return <String, dynamic>{};
    final start = starts.reduce((a, b) => a < b ? a : b);
    return jsonDecode(clean.substring(start));
  }

  Widget _exportHubBlock(BuildContext context) {
    final latestPlan = _scopedPlans.isNotEmpty ? _scopedPlans.first : null;
    final latestEvent = _matchEvents.isNotEmpty ? _matchEvents.first : null;

    return _CmrBlock(
      icon: Icons.ios_share_rounded,
      title: 'Экспорт и отчёты',
      actionTitle: 'Обновить',
      onAction: onRefresh,
      child: _adaptiveGrid(
        minItemWidth: 210,
        maxColumns: 2,
        children: [
          _CmrExportAction(
            icon: Icons.picture_as_pdf_rounded,
            title: 'Сводка клуба',
            subtitle: 'Команды, события, планы',
            enabled: true,
            onTap: onExportOverview ?? () => _showExportMessage(context, 'Экспорт сводки клуба'),
          ),
          _CmrExportAction(
            icon: Icons.description_rounded,
            title: 'План',
            subtitle: latestPlan == null
                ? 'Нет плана'
                : _s(latestPlan['title'] ?? latestPlan['name'] ?? latestPlan['plan_title'], 'Последний план'),
            enabled: latestPlan != null,
            onTap: latestPlan == null
                ? null
                : () {
                    if (onExportPlan != null) {
                      onExportPlan!(latestPlan);
                    } else {
                      _showExportMessage(context, 'Экспорт плана');
                    }
                  },
          ),
          _CmrExportAction(
            icon: Icons.event_available_rounded,
            title: 'Событие',
            subtitle: latestEvent == null
                ? 'Нет события'
                : _s(latestEvent['title'] ?? latestEvent['name'], 'Ближайшее событие'),
            enabled: latestEvent != null,
            onTap: latestEvent == null
                ? null
                : () {
                    if (onExportEvent != null) {
                      onExportEvent!(latestEvent);
                    } else {
                      _showExportMessage(context, 'Экспорт события');
                    }
                  },
          ),
          _CmrExportAction(
            icon: Icons.fitness_center_rounded,
            title: 'Тренировка',
            subtitle: _trainingItems.isEmpty ? 'Нет тренировок' : _latestTrainingTitle(),
            enabled: _trainingItems.isNotEmpty,
            onTap: _trainingItems.isEmpty
                ? null
                : () {
                    if (onExportTraining != null) {
                      onExportTraining!(_trainingItems.first);
                    } else {
                      _showExportMessage(context, 'Экспорт тренировки');
                    }
                  },
          ),
          _CmrExportAction(
            icon: Icons.fact_check_rounded,
            title: 'Тесты',
            subtitle: _testingItems.isEmpty ? 'Нет тестов' : _s(_testingItems.first['title'] ?? _testingItems.first['name'], 'Последний тест'),
            enabled: _testingItems.isNotEmpty || onOpenTesting != null,
            onTap: _testingItems.isNotEmpty && onExportTesting != null
                ? () => onExportTesting!(_testingItems.first)
                : onOpenTesting,
          ),
          _CmrExportAction(
            icon: Icons.summarize_rounded,
            title: 'Отчёт тренера',
            subtitle: trainerAssignedMode ? 'По моим командам' : 'По всем командам',
            enabled: true,
            onTap: onExportOverview ?? () => _showExportMessage(context, 'Экспорт отчёта'),
          ),
        ],
      ),
    );
  }

  Widget _overviewBanner(Map<String, dynamic>? activeTeam, String selectedName, {required bool compact}) {
    final title = clubName.trim().isEmpty ? 'Клуб' : clubName.trim();
    final description = clubDescription.trim().isEmpty
        ? 'Единая рабочая панель клуба'
        : clubDescription.trim();

    return _CmrBanner(
      title: title,
      subtitle: description,
      icon: Icons.space_dashboard_rounded,
      logo: clubLogo,
      fallback: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CmrCornerIconButton(
            icon: Icons.edit_rounded,
            tooltip: 'Редактор клуба',
            onTap: onEditClub,
          ),
          const SizedBox(width: 8),
          _CmrHelpButton(
            title: 'Как читать обзор',
            text: 'Сводка показывает события, тренировки, планы, тесты, игроков и предупреждения. У клуба видны все команды, у тренера — только закреплённые команды.',
          ),
        ],
      ),
    );
  }

  Widget _quickActions({required bool compact}) {
    final firstRow = Row(
      children: [
        Expanded(
          child: _CmrPrimaryButton(
            icon: Icons.add_rounded,
            title: 'Команда',
            onTap: onCreateTeam,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CmrSecondaryButton(
            icon: Icons.edit_rounded,
            title: 'Клуб',
            onTap: onEditClub,
          ),
        ),
      ],
    );

    final secondRow = Row(
      children: [
        Expanded(
          child: _CmrSecondaryButton(
            icon: Icons.groups_2_rounded,
            title: 'Состав',
            onTap: onOpenRoster,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CmrSecondaryButton(
            icon: Icons.badge_rounded,
            title: 'Тренеры',
            onTap: onOpenTrainers,
          ),
        ),
      ],
    );

    return Column(
      children: [
        firstRow,
        const SizedBox(height: 10),
        secondRow,
      ],
    );
  }

  Widget _statsGrid({required bool compact}) {
    final assignedTeams = teams.length;
    final items = [
      _CmrStatData(value: '$assignedTeams', label: trainerAssignedMode ? 'мои команды' : 'команд', icon: Icons.account_tree_rounded, onTap: onOpenTeams),
      _CmrStatData(value: '${_scopedPlayers.isNotEmpty ? _scopedPlayers.length : playersCount}', label: 'игрока', icon: Icons.groups_2_rounded, onTap: onOpenRoster),
      _CmrStatData(value: '${_scopedEvents.length}', label: 'событий', icon: Icons.calendar_month_rounded, onTap: onOpenCalendar),
      _CmrStatData(value: '${_trainingItems.length}', label: 'тренировок', icon: Icons.fitness_center_rounded, onTap: onOpenTrainings ?? onOpenCalendar),
      _CmrStatData(value: '${_scopedPlans.length}', label: 'планов', icon: Icons.assignment_rounded, onTap: onOpenPlans),
    ];

    if (compact) {
      return _adaptiveGrid(
        minItemWidth: 122,
        maxColumns: 3,
        spacing: 8,
        children: items
            .map((item) => _CmrStatCard(
                  value: item.value,
                  label: item.label,
                  icon: item.icon,
                  onTap: item.onTap,
                ))
            .toList(),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: _CmrStatCard(
              value: items[i].value,
              label: items[i].label,
              icon: items[i].icon,
              onTap: items[i].onTap,
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _adaptiveGrid({
    required List<Widget> children,
    double spacing = 10,
    double minItemWidth = 170,
    int maxColumns = 2,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite ? constraints.maxWidth : minItemWidth;
        final columns = math.max(1, math.min(maxColumns, available ~/ minItemWidth));
        final itemWidth = (available - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }

  Widget _teamSelector(Map<String, dynamic>? activeTeam, String selectedName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _CmrDecor.softCard(radius: 22),
      child: Row(
        children: [
          _CmrAvatar(photo: _image(activeTeam) ?? '', name: selectedName, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedName.trim().isEmpty ? 'Команда не выбрана' : selectedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CmrText.title(15),
                ),
                const SizedBox(height: 4),
                Text(
                  activeTeam == null ? 'Выберите команду для работы' : _teamSubtitle(activeTeam),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CmrText.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<Map<String, dynamic>>(
            tooltip: 'Выбрать команду',
            onSelected: onTeamChanged,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            itemBuilder: (context) {
              if (teams.isEmpty) {
                return const [
                  PopupMenuItem<Map<String, dynamic>>(
                    enabled: false,
                    child: Text('Команд пока нет'),
                  ),
                ];
              }
              return teams.map((team) {
                final selected = _teamId(team) == selectedTeamId;
                return PopupMenuItem<Map<String, dynamic>>(
                  value: team,
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: selected ? _CmrColors.green : _CmrColors.muted,
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _teamName(team),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _CmrText.tab(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _CmrColors.greenSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _CmrColors.greenBorder),
              ),
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: _CmrColors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 36),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: _CmrText.section())),
      ],
    );
  }

  Widget _simpleSectionTitle(String title) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _CmrText.section(),
    );
  }


  String _nextEventTitle() {
    if (_matchEvents.isEmpty) return 'Нет ближайших событий';
    final event = _matchEvents.first;
    return _s(event['title'] ?? event['name'], 'Событие');
  }

  String _latestPlanTitle() {
    if (_scopedPlans.isEmpty) return 'Планы не добавлены';
    final plan = _scopedPlans.first;
    return _s(plan['title'] ?? plan['name'] ?? plan['plan_title'], 'План-конспект');
  }


  Future<List<Map<String, dynamic>>> _loadChatsPreview() async {
    if (trainerWorkspaceId <= 0) return <Map<String, dynamic>>[];
    try {
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_user_chats.php').replace(
        queryParameters: {'user_id': '$trainerWorkspaceId'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final body = response.body.trim();
      final start = body.indexOf('{');
      final jsonText = start >= 0 ? body.substring(start) : body;
      final decoded = jsonDecode(jsonText);
      final raw = decoded is Map<String, dynamic>
          ? (decoded['data'] ?? decoded['items'] ?? decoded['chats'] ?? decoded['groups'] ?? <dynamic>[])
          : decoded;
      if (raw is! List) return <Map<String, dynamic>>[];
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).take(3).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  String _chatTitle(Map<String, dynamic> chat) {
    return _s(
      chat['name'] ??
          chat['chat_name'] ??
          chat['title'] ??
          chat['group_name'] ??
          chat['peer_name'] ??
          chat['other_user_name'],
      'Чат команды',
    );
  }

  String _chatSubtitle(Map<String, dynamic> chat) {
    final last = _s(chat['last_message'] ?? chat['last_message_text'] ?? chat['message'] ?? chat['content']);
    if (last.isNotEmpty) return last;
    final members = _i(chat['members_count'] ?? chat['member_count'] ?? chat['members']);
    if (members > 0) return '$members участников';
    return 'Открыть переписку';
  }

  Widget _euroKpiStrip({bool wrap = false}) {
    final cards = [
      _CmrFocusCard(
        icon: Icons.sports_soccer_rounded,
        title: 'Матчи',
        value: _matchEvents.isEmpty ? 'Календарь пуст' : _nextEventTitle(),
        subtitle: _matchEvents.isEmpty ? 'Добавьте игру' : _dateText(_matchEvents.first),
        onTap: onOpenCalendar,
      ),
      _CmrFocusCard(
        icon: Icons.campaign_rounded,
        title: 'Новости',
        value: _visibleNews.isEmpty ? 'Лента пуста' : _s(_visibleNews.first['title'] ?? _visibleNews.first['name'], 'Новость клуба'),
        subtitle: _visibleNews.isEmpty ? 'Посты тренеров и клуба' : _dateText(_visibleNews.first),
        onTap: onRefresh,
      ),
      _CmrFocusCard(
        icon: Icons.assignment_turned_in_rounded,
        title: 'Планы',
        value: _latestPlanTitle(),
        subtitle: _scopedPlans.isEmpty ? 'Создайте первый план' : _trainerName(_scopedPlans.first),
        onTap: onOpenPlans,
      ),
      _CmrFocusCard(
        icon: Icons.forum_rounded,
        title: 'Связь',
        value: 'Командные чаты',
        subtitle: trainerAssignedMode ? 'По вашим командам' : 'По всем командам',
        onTap: onOpenChats,
      ),
    ];

    if (wrap) {
      return _adaptiveGrid(
        minItemWidth: 176,
        maxColumns: 2,
        spacing: 10,
        children: cards,
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _focusStrip() {
    return Row(
      children: [
        Expanded(
          child: _CmrFocusCard(
            icon: Icons.sports_soccer_rounded,
            title: 'Ближайшее',
            value: _nextEventTitle(),
            subtitle: _matchEvents.isEmpty ? 'Откройте календарь' : _dateText(_matchEvents.first),
            onTap: onOpenCalendar,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CmrFocusCard(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Последний план',
            value: _latestPlanTitle(),
            subtitle: _scopedPlans.isEmpty ? 'Создайте первый план' : _trainerName(_scopedPlans.first),
            onTap: onOpenPlans,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CmrFocusCard(
            icon: Icons.forum_rounded,
            title: 'Связь',
            value: selectedTeamId == null ? 'Команда не выбрана' : 'Командный чат',
            subtitle: trainerAssignedMode ? 'По вашим командам' : 'По всем командам клуба',
            onTap: onOpenChats,
          ),
        ),
      ],
    );
  }

  Widget _managementBlock() {
    return _CmrBlock(
      icon: Icons.grid_view_rounded,
      title: 'Рабочие разделы',
      child: _adaptiveGrid(
        minItemWidth: 170,
        maxColumns: 2,
        children: [
          _CmrHubTile(
            icon: Icons.fitness_center_rounded,
            title: 'Тренировки',
            subtitle: _trainingItems.isEmpty ? 'Нет записей' : '${_trainingItems.length} ближайших',
            onTap: onOpenTrainings ?? onOpenCalendar,
          ),
          _CmrHubTile(
            icon: Icons.fact_check_rounded,
            title: 'Тесты игроков',
            subtitle: 'Оценки и предупреждения',
            onTap: onOpenTesting,
          ),
          _CmrHubTile(
            icon: Icons.calendar_month_rounded,
            title: 'Календарь',
            subtitle: trainerAssignedMode ? 'Мои команды' : 'Все команды клуба',
            onTap: onOpenCalendar,
          ),
          _CmrHubTile(
            icon: Icons.edit_rounded,
            title: 'Редактор клуба',
            subtitle: 'Логотип и описание',
            onTap: onEditClub,
          ),
        ],
      ),
    );
  }

  Widget _newsCompactBlock() {
    final visibleNews = _visibleNews;
    return _CmrBlock(
      icon: Icons.campaign_rounded,
      title: 'Новости и объявления',
      child: visibleNews.isEmpty
          ? _CmrInlineEmpty(
              icon: Icons.campaign_rounded,
              title: 'Новостная лента не подключена',
              text: 'Блок оставлен компактным, чтобы не занимать рабочее пространство пустой карточкой.',
            )
          : Column(
              children: visibleNews.map((item) {
                return _CmrInfoTile(
                  icon: Icons.article_rounded,
                  title: _s(item['title'] ?? item['name'], 'Новость'),
                  subtitle: _dateText(item),
                );
              }).toList(),
            ),
    );
  }


  Widget _matchCalendarBlock(BuildContext context) {
    final matches = _matchEvents;
    return _CmrBlock(
      icon: Icons.calendar_month_rounded,
      title: 'Календарь матчей',
      actionTitle: 'Открыть',
      onAction: onOpenCalendar,
      child: matches.isEmpty
          ? _CmrSoftState(
              icon: Icons.event_available_rounded,
              title: 'Матчей пока нет',
              text: 'Здесь должны быть ближайшие игры, турниры и события выбранной команды.',
              buttonText: 'Открыть календарь',
              onTap: onOpenCalendar,
            )
          : Column(
              children: matches.map((event) {
                final title = _s(event['title'] ?? event['name'] ?? event['event_title'], 'Матч команды');
                final opponent = _s(event['opponent'] ?? event['opponent_name'] ?? event['team_away'] ?? event['rival']);
                final place = _s(event['location'] ?? event['place'] ?? event['stadium']);
                final subtitleParts = <String>[_dateText(event)];
                if (opponent.isNotEmpty) subtitleParts.add('соперник: $opponent');
                if (place.isNotEmpty) subtitleParts.add(place);
                return _CmrMatchTile(
                  title: title,
                  subtitle: subtitleParts.join(' · '),
                  onTap: onOpenCalendar,
                );
              }).toList(),
            ),
    );
  }

  Widget _newsFeedBlock() {
    final items = _visibleNews;
    return _CmrBlock(
      icon: Icons.newspaper_rounded,
      title: 'Лента клуба',
      actionTitle: 'Обновить',
      onAction: onRefresh,
      child: items.isEmpty
          ? _CmrSoftState(
              icon: Icons.campaign_rounded,
              title: 'Новостей пока нет',
              text: 'Когда тренер или клуб добавит пост в ленту, он появится здесь в компактном виде.',
              buttonText: 'Обновить',
              onTap: onRefresh,
            )
          : Column(
              children: items.take(5).map((item) {
                return _CmrNewsTile(
                  title: _s(item['title'] ?? item['name'] ?? item['caption'], 'Новость клуба'),
                  subtitle: _s(item['body'] ?? item['text'] ?? item['description'] ?? item['content'], 'Публикация из ленты клуба'),
                  meta: '${_trainerName(item)} · ${_dateText(item)}',
                );
              }).toList(),
            ),
    );
  }

  Widget _calendarBlock() {
    return _CmrBlock(
      icon: Icons.event_available_rounded,
      title: 'События и матчи',
      actionTitle: 'Календарь',
      onAction: onOpenCalendar,
      child: _matchEvents.isEmpty
          ? _CmrSoftState(
              icon: Icons.calendar_month_rounded,
              title: 'Календарь пока пуст',
              text: 'Добавьте матч, тренировку или событие команды.',
              buttonText: 'Открыть календарь',
              onTap: onOpenCalendar,
            )
          : Column(
              children: _matchEvents.map((event) {
                return _CmrInfoTile(
                  icon: Icons.sports_soccer_rounded,
                  title: _s(event['title'] ?? event['name'], 'Событие'),
                  subtitle: '${_dateText(event)} · ${_s(event['team_name'] ?? event['teamName'], selectedTeamName)}',
                  onTap: onOpenCalendar,
                );
              }).toList(),
            ),
    );
  }

  Widget _plansBlock(BuildContext context) {
    return _CmrBlock(
      icon: Icons.assignment_turned_in_rounded,
      title: 'Планы тренеров',
      actionTitle: 'Планы',
      onAction: onOpenPlans,
      child: _scopedPlans.isEmpty
          ? _CmrSoftState(
              icon: Icons.note_add_rounded,
              title: 'Планов пока нет',
              text: 'Здесь будут последние планы-конспекты с автором и командой.',
              buttonText: 'Открыть планы',
              onTap: onOpenPlans,
            )
          : Column(
              children: _scopedPlans.take(5).map((plan) {
                final trainer = _trainerName(plan);
                final team = _s(plan['team_name'] ?? plan['teamName'], selectedTeamName);
                return _CmrInfoTile(
                  icon: Icons.description_rounded,
                  title: _s(plan['title'] ?? plan['name'] ?? plan['plan_title'], 'План-конспект'),
                  subtitle: '$trainer · $team',
                  trailing: _dateText(plan),
                  onTap: onOpenPlans,
                );
              }).toList(),
            ),
    );
  }

  Widget _newsBlock() {
    final visibleNews = _visibleNews;
    return _CmrBlock(
      icon: Icons.campaign_rounded,
      title: 'Новости клуба',
      child: visibleNews.isEmpty
          ? const _CmrInlineEmpty(
              icon: Icons.campaign_rounded,
              title: 'Новостная лента не подключена',
              text: 'После подключения новости будут отображаться здесь коротким списком.',
            )
          : Column(
              children: visibleNews.map((item) {
                return _CmrInfoTile(
                  icon: Icons.article_rounded,
                  title: _s(item['title'] ?? item['name'], 'Новость'),
                  subtitle: _dateText(item),
                );
              }).toList(),
            ),
    );
  }

  Widget _communicationBlock() {
    return _CmrBlock(
      icon: Icons.forum_rounded,
      title: 'Чаты и штаб',
      actionTitle: 'Чаты',
      onAction: onOpenChats,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadChatsPreview(),
        builder: (context, snapshot) {
          final chats = snapshot.data ?? const <Map<String, dynamic>>[];
          return Column(
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const _CmrInlineEmpty(
                  icon: Icons.forum_rounded,
                  title: 'Загружаем чаты',
                  text: 'Проверяем командные и личные переписки.',
                )
              else if (chats.isEmpty)
                _CmrInfoTile(
                  icon: Icons.chat_bubble_rounded,
                  title: 'Командные чаты',
                  subtitle: trainerAssignedMode ? 'Чаты закреплённых команд' : 'Чаты всех команд клуба',
                  onTap: onOpenChats,
                )
              else
                ...chats.map((chat) => _CmrInfoTile(
                      icon: Icons.chat_bubble_rounded,
                      title: _chatTitle(chat),
                      subtitle: _chatSubtitle(chat),
                      trailing: _dateText(chat),
                      onTap: onOpenChats,
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _CmrLiveOverviewData {
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> tests;
  final List<_CmrTestWarning> warnings;

  const _CmrLiveOverviewData({
    this.players = const <Map<String, dynamic>>[],
    this.tests = const <Map<String, dynamic>>[],
    this.warnings = const <_CmrTestWarning>[],
  });
}

class _CmrTestingLoadResult {
  final List<Map<String, dynamic>> tests;
  final List<_CmrTestWarning> warnings;

  const _CmrTestingLoadResult({
    this.tests = const <Map<String, dynamic>>[],
    this.warnings = const <_CmrTestWarning>[],
  });
}

class _CmrTestWarning {
  final int playerId;
  final int teamId;
  final String playerName;
  final String testTitle;
  final String teamName;
  final String message;
  final String photo;
  final int weakCount;
  final String severity;

  const _CmrTestWarning({
    this.playerId = 0,
    this.teamId = 0,
    required this.playerName,
    required this.testTitle,
    required this.teamName,
    required this.message,
    this.photo = '',
    this.weakCount = 1,
    this.severity = 'warning',
  });
}

class _CmrScrollPanel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRefresh;

  const _CmrScrollPanel({
    required this.child,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;
        return Container(
          padding: EdgeInsets.all(mobile ? 10 : 18),
          decoration: mobile
              ? BoxDecoration(
                  color: _CmrColors.panel,
                  borderRadius: BorderRadius.circular(22),
                )
              : _CmrDecor.panel(),
          child: RefreshIndicator(
            onRefresh: () async => onRefresh?.call(),
            color: _CmrColors.green,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _CmrBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? logo;
  final String fallback;
  final Widget? trailing;

  const _CmrBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.logo,
    required this.fallback,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 520;
        final avatarSize = mobile ? 46.0 : 58.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(mobile ? 14 : 18),
          decoration: _CmrDecor.softCard(radius: mobile ? 24 : 28),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CmrAvatar(photo: logo ?? '', name: fallback, size: avatarSize, icon: icon),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrText.title(17),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          trailing!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrText.muted(12),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _CmrAvatar(photo: logo ?? '', name: fallback, size: avatarSize, icon: icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrText.title(20),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrText.muted(12.5),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 10),
                      trailing!,
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _CmrSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionTitle;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _CmrSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionTitle,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(19)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _CmrSecondaryButton(icon: actionIcon, title: actionTitle, onTap: onAction),
      ],
    );
  }
}

class _CmrBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String actionTitle;
  final VoidCallback? onAction;
  final Widget child;

  const _CmrBlock({
    required this.icon,
    required this.title,
    required this.child,
    this.actionTitle = '',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 520;
        final veryNarrow = constraints.maxWidth < 340;
        final hasAction = actionTitle.trim().isNotEmpty && onAction != null;
        final header = Row(
          children: [
            _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: mobile ? 36 : 40),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: mobile ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrText.section(),
              ),
            ),
            if (hasAction && !veryNarrow) ...[
              const SizedBox(width: 8),
              _CmrMiniAction(title: actionTitle, onTap: onAction!),
            ],
          ],
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(mobile ? 12 : 16),
          decoration: _CmrDecor.softCard(radius: mobile ? 22 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              if (hasAction && veryNarrow) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _CmrMiniAction(title: actionTitle, onTap: onAction!),
                ),
              ],
              const SizedBox(height: 12),
              child,
            ],
          ),
        );
      },
    );
  }
}

class _CmrInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  const _CmrInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 430;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.all(mobile ? 10 : 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: mobile ? 34 : 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: mobile ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrText.title(mobile ? 13 : 13.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: mobile ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrText.caption(),
                          ),
                        ],
                      ),
                    ),
                    if (trailing.trim().isNotEmpty && !mobile) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 96),
                        child: Text(trailing, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
                      ),
                    ],
                    if (onTap != null) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: _CmrColors.green, size: 22),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class _CmrMatchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _CmrMatchTile({required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _CmrColors.green,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.8)),
                      const SizedBox(height: 4),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.muted(12)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: _CmrColors.green, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CmrNewsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;

  const _CmrNewsTile({required this.title, required this.subtitle, required this.meta});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CmrRoundIcon(icon: Icons.article_rounded, color: _CmrColors.green, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.8)),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.muted(12)),
                  const SizedBox(height: 6),
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CmrFocusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback? onTap;

  const _CmrFocusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8EEF2)),
          ),
          child: Row(
            children: [
              _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
                    const SizedBox(height: 3),
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.8)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.muted(11.4)),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: _CmrColors.green, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _CmrHubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _CmrHubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8EEF2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 36),
              const SizedBox(height: 14),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.5)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
            ],
          ),
        ),
      ),
    );
  }
}



class _CmrMetricPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _CmrMetricPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EEF2)),
      ),
      child: Row(
        children: [
          _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(17)),
                const SizedBox(height: 3),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _CmrExportAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const _CmrExportAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : .48,
          child: Container(
            constraints: const BoxConstraints(minHeight: 78),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE8EEF2)),
            ),
            child: Row(
              children: [
                _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.8)),
                      const SizedBox(height: 4),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  enabled ? Icons.file_download_rounded : Icons.lock_outline_rounded,
                  color: enabled ? _CmrColors.green : _CmrColors.muted,
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _CmrInlineEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _CmrInlineEmpty({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.5)),
                const SizedBox(height: 3),
                Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CmrSoftState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String? buttonText;
  final VoidCallback? onTap;

  const _CmrSoftState({
    required this.icon,
    required this.title,
    required this.text,
    this.buttonText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 46),
          const SizedBox(height: 12),
          Text(title, style: _CmrText.title(15)),
          const SizedBox(height: 5),
          Text(text, style: _CmrText.muted(12.5)),
          if (buttonText != null && onTap != null) ...[
            const SizedBox(height: 14),
            _CmrPrimaryButton(icon: Icons.arrow_forward_rounded, title: buttonText!, onTap: onTap),
          ],
        ],
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft,
        border: Border.all(color: _CmrColors.greenBorder),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.5)),
                const SizedBox(height: 3),
                Text(text, style: _CmrText.muted(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CmrCornerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _CmrCornerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: _CmrColors.green, size: 20),
          ),
        ),
      ),
    );
  }
}


class _CmrAllWarningsSheet extends StatefulWidget {
  final List<_CmrTestWarning> warnings;
  final VoidCallback? onOpenTesting;
  final ValueChanged<_CmrTestWarning>? onOpenWarning;

  const _CmrAllWarningsSheet({
    required this.warnings,
    this.onOpenTesting,
    this.onOpenWarning,
  });

  @override
  State<_CmrAllWarningsSheet> createState() => _CmrAllWarningsSheetState();
}

class _CmrAllWarningsSheetState extends State<_CmrAllWarningsSheet> {
  String _query = '';
  String _team = 'Все команды';

  List<String> get _teams {
    final teams = widget.warnings
        .map((e) => e.teamName.trim())
        .where((e) => e.isNotEmpty && e != 'Команда')
        .toSet()
        .toList()
      ..sort();
    return ['Все команды', ...teams];
  }

  List<_CmrTestWarning> get _filteredWarnings {
    final q = _query.toLowerCase().replaceAll('ё', 'е').trim();
    return widget.warnings.where((warning) {
      final inTeam = _team == 'Все команды' || warning.teamName == _team;
      if (!inTeam) return false;
      if (q.isEmpty) return true;
      final haystack = [
        warning.playerName,
        warning.teamName,
        warning.testTitle,
        warning.message,
      ].join(' ').toLowerCase().replaceAll('ё', 'е');
      return haystack.contains(q);
    }).toList();
  }

  int get _criticalCount => widget.warnings.where((warning) => warning.severity == 'critical' || warning.weakCount >= 3).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredWarnings;
    final height = MediaQuery.of(context).size.height * .88;

    return SafeArea(
      top: false,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E7EC),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Все предупреждения по игрокам', style: _CmrText.title(18)),
                      const SizedBox(height: 3),
                      Text(
                        'Всего: ${widget.warnings.length} · критичных: $_criticalCount',
                        style: _CmrText.muted(12.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Поиск по игроку, команде или тесту',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: _CmrColors.soft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _teams.map((team) {
                  final selected = team == _team;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: selected,
                      label: Text(team),
                      onSelected: (_) => setState(() => _team = team),
                      selectedColor: _CmrColors.greenSoft,
                      backgroundColor: _CmrColors.soft,
                      labelStyle: TextStyle(
                        color: selected ? _CmrColors.green : _CmrColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const _CmrInlineEmpty(
                      icon: Icons.search_off_rounded,
                      title: 'Ничего не найдено',
                      text: 'Измените поиск или выберите другую команду.',
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _CmrWarningListTile(
                        warning: filtered[index],
                        onTap: widget.onOpenWarning == null
                            ? (widget.onOpenTesting == null
                                ? null
                                : () {
                                    Navigator.of(context).pop();
                                    widget.onOpenTesting?.call();
                                  })
                            : () {
                                Navigator.of(context).pop();
                                widget.onOpenWarning?.call(filtered[index]);
                              },
                      ),
                    ),
            ),
            if (widget.onOpenTesting != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _CmrPrimaryButton(
                  icon: Icons.fact_check_rounded,
                  title: 'Открыть раздел тестирования',
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onOpenTesting?.call();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CmrWarningListTile extends StatelessWidget {
  final _CmrTestWarning warning;
  final VoidCallback? onTap;

  const _CmrWarningListTile({
    required this.warning,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final critical = warning.severity == 'critical' || warning.weakCount >= 3;
    final color = critical ? const Color(0xFFD92D20) : const Color(0xFFEA580C);
    final playerName = warning.playerName.trim().isEmpty ? 'Игрок' : warning.playerName.trim();
    final subtitle = [warning.teamName, warning.testTitle]
        .where((e) => e.trim().isNotEmpty && e.trim() != 'Команда')
        .join(' · ');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: critical ? const Color(0xFFFFF1F3) : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _CmrAvatar(
                    photo: warning.photo,
                    name: playerName,
                    size: 44,
                    icon: Icons.person_rounded,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            playerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrText.title(14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            critical ? 'Критично' : 'Внимание',
                            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrText.muted(12.2),
                      ),
                    const SizedBox(height: 7),
                    Text(
                      warning.message,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.28),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Открыть тестирование',
                            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_rounded, size: 15, color: color),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CmrWarningsCompactHeader extends StatelessWidget {
  final int totalCount;
  final int visibleCount;
  final VoidCallback onShowAll;

  const _CmrWarningsCompactHeader({
    required this.totalCount,
    required this.visibleCount,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 430;
        final title = 'Показано игроков: $visibleCount · предупреждений: $totalCount';
        final action = TextButton.icon(
          onPressed: onShowAll,
          icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
          label: Text('Все $totalCount'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFEA580C),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(20),
          ),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.2)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerLeft, child: action),
                  ],
                )
              : Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.2)),
                    ),
                    const SizedBox(width: 8),
                    action,
                  ],
                ),
        );
      },
    );
  }
}

class _CmrWarningPanel extends StatelessWidget {
  final List<_CmrTestWarning> warnings;
  final int totalCount;
  final VoidCallback? onTap;
  final ValueChanged<_CmrTestWarning>? onWarningTap;
  final VoidCallback? onShowAll;

  const _CmrWarningPanel({
    required this.warnings,
    this.totalCount = 0,
    this.onTap,
    this.onWarningTap,
    this.onShowAll,
  });

  int get _displayTotal => totalCount > 0 ? totalCount : warnings.length;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onShowAll ?? onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Предупреждения для тренера',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _CmrText.title(14.5),
                        ),
                        Text(
                          'Игроков с риском: $_displayTotal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _CmrText.muted(11.5),
                        ),
                      ],
                    ),
                  ),
                  if (_displayTotal > warnings.length)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('Все $_displayTotal', style: _CmrText.caption()),
                    ),
                  if (onShowAll != null || onWarningTap != null || onTap != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.chevron_right_rounded, color: Color(0xFFEA580C)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ...warnings.map((warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white.withOpacity(.62),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: onWarningTap == null ? onTap : () => onWarningTap!(warning),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CmrAvatar(
                                photo: warning.photo,
                                name: warning.playerName,
                                size: 34,
                                icon: Icons.person_rounded,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      warning.playerName.trim().isEmpty ? 'Игрок' : warning.playerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _CmrText.title(12.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${warning.teamName} · ${warning.message}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: _CmrText.muted(12.2),
                                    ),
                                  ],
                                ),
                              ),
                              if (onWarningTap != null || onTap != null)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6, top: 6),
                                  child: Icon(Icons.arrow_forward_rounded, color: Color(0xFFEA580C), size: 17),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )),
              if (_displayTotal > warnings.length) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onShowAll,
                    icon: const Icon(Icons.format_list_bulleted_rounded, size: 17),
                    label: Text('Показать все $_displayTotal'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEA580C),
                      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
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

class _CmrPlayerMiniCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? photo;
  final String badge;
  final bool hasWarning;
  final int warningCount;
  final String warningText;
  final VoidCallback? onTap;

  const _CmrPlayerMiniCard({
    required this.name,
    required this.subtitle,
    required this.photo,
    required this.badge,
    this.hasWarning = false,
    this.warningCount = 0,
    this.warningText = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final warningColor = hasWarning ? const Color(0xFFEA580C) : _CmrColors.green;
    final bgColor = hasWarning ? const Color(0xFFFFF7ED) : Colors.white;
    final badgeText = hasWarning ? (warningCount > 1 ? 'Внимание · $warningCount' : 'Внимание') : (badge.trim().isNotEmpty ? '#$badge' : '');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 132,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: hasWarning
                ? [
                    BoxShadow(
                      color: warningColor.withOpacity(.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CmrAvatar(photo: photo ?? '', name: name, size: 42, icon: Icons.person_rounded),
                  const Spacer(),
                  if (badgeText.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: hasWarning ? Colors.white : _CmrColors.greenSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasWarning ? warningColor : _CmrColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.5)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
              if (hasWarning) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: warningColor),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        warningText.isEmpty ? 'Есть слабые оценки' : warningText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: warningColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CmrAvatar extends StatelessWidget {
  final String photo;
  final String name;
  final double size;
  final IconData? icon;

  const _CmrAvatar({
    required this.photo,
    required this.name,
    required this.size,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? 'К'
        : name.trim().split(RegExp(r'\s+')).take(2).map((e) => e.isEmpty ? '' : e[0].toUpperCase()).join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(size * .32),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isEmpty
          ? Center(
              child: icon == null
                  ? Text(initials, style: _CmrText.title(size * .32))
                  : Icon(icon, color: _CmrColors.green, size: size * .46),
            )
          : Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: Text(initials, style: _CmrText.title(size * .32))),
            ),
    );
  }
}

class _CmrRoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _CmrRoundIcon({
    required this.icon,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color == _CmrColors.green ? _CmrColors.greenSoft : _CmrColors.soft,
        border: Border.all(color: color == _CmrColors.green ? _CmrColors.greenBorder : Colors.transparent),
        borderRadius: BorderRadius.circular(size * .34),
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

  const _CmrPrimaryButton({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color = _CmrColors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
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

class _CmrSecondaryButton extends StatelessWidget {
  final IconData? icon;
  final String title;
  final VoidCallback? onTap;

  const _CmrSecondaryButton({
    this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: _CmrColors.soft,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: _CmrColors.text),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrText.tab(),
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

class _CmrMiniAction extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _CmrMiniAction({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.action()),
        ),
      ),
    );
  }
}

class _CmrStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _CmrStatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EEF2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: _CmrColors.green, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(16)),
                    const SizedBox(height: 2),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CmrHelpButton extends StatelessWidget {
  final String title;
  final String text;

  const _CmrHelpButton({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) {
                return _CmrBottomPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _CmrSheetHandle(),
                      _CmrRoundIcon(icon: Icons.help_outline_rounded, color: _CmrColors.green, size: 58),
                      const SizedBox(height: 14),
                      Text(title, textAlign: TextAlign.center, style: _CmrText.title(20)),
                      const SizedBox(height: 8),
                      Text(text, textAlign: TextAlign.center, style: _CmrText.muted(14)),
                      const SizedBox(height: 18),
                      _CmrPrimaryButton(
                        icon: Icons.check_rounded,
                        title: 'Понятно',
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.help_outline_rounded, color: _CmrColors.green, size: 20),
          ),
        ),
      ),
    );
  }
}

class _CmrBottomPanel extends StatelessWidget {
  final Widget child;

  const _CmrBottomPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: _CmrDecor.panel(),
        child: child,
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
        decoration: BoxDecoration(
          color: const Color(0xFFE4E7EC),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _CmrStatData {
  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CmrStatData({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
  });
}
