import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_api_service.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_ai_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_analytics_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_calendar_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_live_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_matches_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_overview_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_roster_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_staff_access_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_teams_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_tournaments_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_video_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_workspace_os_panel.dart';

enum EsportsWorkspaceSection {
  overview,
  teams,
  roster,
  matches,
  calendar,
  tournaments,
  live,
  video,
  analytics,
  ai,
  staff,
  workspaceOs,
}

class EsportsWorkspaceScreen extends StatefulWidget {
  final int clubId;
  final int userId;
  final String clubName;
  final String? clubLogoUrl;

  /// Filled when HUB opens this workspace through Staff Access.
  final int? staffAccessId;
  final String? staffRoleCode;
  final Set<int>? allowedTeamIds;
  final Set<int>? allowedAthleteIds;

  /// True for a normal esports-player account opening its own direction.
  /// It prevents the player from receiving owner/admin controls.
  final bool athleteOnly;

  const EsportsWorkspaceScreen({
    super.key,
    required this.clubId,
    required this.userId,
    required this.clubName,
    this.clubLogoUrl,
    this.staffAccessId,
    this.staffRoleCode,
    this.allowedTeamIds,
    this.allowedAthleteIds,
    this.athleteOnly = false,
  });

  @override
  State<EsportsWorkspaceScreen> createState() => _EsportsWorkspaceScreenState();
}

class _EsportsWorkspaceScreenState extends State<EsportsWorkspaceScreen> {
  EsportsWorkspaceSection _section = EsportsWorkspaceSection.teams;
  bool _loading = true;
  bool _refreshing = false;
  String? _serverError;

  List<Map<String, dynamic>> _teams = const [];
  List<Map<String, dynamic>> _athletes = const [];
  List<Map<String, dynamic>> _matches = const [];
  List<Map<String, dynamic>> _tournaments = const [];
  List<Map<String, dynamic>> _streams = const [];
  List<Map<String, dynamic>> _recordings = const [];
  List<Map<String, dynamic>> _reports = const [];

  Map<String, dynamic>? _selectedTeam;
  Map<String, dynamic>? _liveInitialMatch;

  // Desktop CMR window workspace. Esports intentionally follows the same
  // interaction model as Club Workspace: desktop shortcuts, floating windows,
  // active-team shortcut and a bottom Dock.
  final List<_EsportsWorkspaceWindowState> _openWindows = <_EsportsWorkspaceWindowState>[];
  final Map<EsportsWorkspaceSection, Offset> _desktopIconPositions = <EsportsWorkspaceSection, Offset>{};
  int _windowZCounter = 0;
  bool _desktopInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadAll(initial: true);
  }

  int _id(Map<String, dynamic> m) => esportsInt(m['id'] ?? m['team_id'] ?? m['teamId']);

  String get _role => (widget.staffRoleCode ?? '').trim().toLowerCase();
  bool get _isOwner => !widget.athleteOnly && (widget.staffAccessId ?? 0) <= 0 && _role.isEmpty;
  bool get _isAdminStaff => {'esports_admin', 'esports_manager'}.contains(_role);
  bool get _isHeadCoach => _role == 'esports_head_coach';
  bool get _isCoach => {'esports_head_coach', 'esports_coach'}.contains(_role);
  bool get _isAnalyst => _role == 'esports_analyst';
  bool get _isStreamer => _role == 'esports_streamer';

  bool get _canManageTeams => _isOwner || _isAdminStaff;
  bool get _canManageRoster => _isOwner || _isAdminStaff || _isCoach;
  bool get _canManageMatches => _isOwner || _isAdminStaff || _isCoach;
  bool get _canManageLive => _isOwner || _isAdminStaff || _isCoach || _isStreamer;
  bool get _canManageTournaments => _isOwner || _isAdminStaff || _isHeadCoach;
  bool get _canManageStaff => _isOwner || _isAdminStaff;

  Set<EsportsWorkspaceSection> get _visibleSections {
    if (widget.athleteOnly) {
      return {
        EsportsWorkspaceSection.overview,
        EsportsWorkspaceSection.teams,
        EsportsWorkspaceSection.roster,
        EsportsWorkspaceSection.matches,
        EsportsWorkspaceSection.calendar,
        EsportsWorkspaceSection.tournaments,
        EsportsWorkspaceSection.live,
        EsportsWorkspaceSection.video,
        EsportsWorkspaceSection.analytics,
        EsportsWorkspaceSection.ai,
        EsportsWorkspaceSection.workspaceOs,
      };
    }
    if (_isAnalyst) {
      return {
        EsportsWorkspaceSection.overview,
        EsportsWorkspaceSection.matches,
        EsportsWorkspaceSection.calendar,
        EsportsWorkspaceSection.tournaments,
        EsportsWorkspaceSection.video,
        EsportsWorkspaceSection.analytics,
        EsportsWorkspaceSection.ai,
        EsportsWorkspaceSection.workspaceOs,
      };
    }
    if (_isStreamer) {
      return {
        EsportsWorkspaceSection.overview,
        EsportsWorkspaceSection.matches,
        EsportsWorkspaceSection.calendar,
        EsportsWorkspaceSection.live,
        EsportsWorkspaceSection.video,
        EsportsWorkspaceSection.ai,
        EsportsWorkspaceSection.workspaceOs,
      };
    }
    return {
      EsportsWorkspaceSection.overview,
      EsportsWorkspaceSection.teams,
      EsportsWorkspaceSection.roster,
      EsportsWorkspaceSection.matches,
      EsportsWorkspaceSection.calendar,
      EsportsWorkspaceSection.tournaments,
      EsportsWorkspaceSection.live,
      EsportsWorkspaceSection.video,
      EsportsWorkspaceSection.analytics,
      EsportsWorkspaceSection.ai,
      if (_canManageStaff) EsportsWorkspaceSection.staff,
      EsportsWorkspaceSection.workspaceOs,
    };
  }

  Future<void> _loadAll({bool initial = false}) async {
    if (!mounted) return;
    setState(() {
      if (initial) _loading = true;
      _refreshing = !initial;
      _serverError = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        EsportsApiService.teams(clubId: widget.clubId, userId: widget.userId),
        EsportsApiService.athletes(clubId: widget.clubId, userId: widget.userId),
        EsportsApiService.matches(clubId: widget.clubId),
        EsportsApiService.tournaments(clubId: widget.clubId),
        EsportsApiService.streams(clubId: widget.clubId),
        EsportsApiService.recordings(clubId: widget.clubId),
        EsportsApiService.aiReports(clubId: widget.clubId),
      ]);

      var teams = List<Map<String, dynamic>>.from(results[0] as List);
      var athletes = List<Map<String, dynamic>>.from(results[1] as List);
      var matches = List<Map<String, dynamic>>.from(results[2] as List);
      var tournaments = List<Map<String, dynamic>>.from(results[3] as List);
      var streams = List<Map<String, dynamic>>.from(results[4] as List);
      var recordings = List<Map<String, dynamic>>.from(results[5] as List);
      var reports = List<Map<String, dynamic>>.from(results[6] as List);

      final allowedTeams = widget.allowedTeamIds;
      if (allowedTeams != null && allowedTeams.isNotEmpty) {
        teams = teams.where((team) => allowedTeams.contains(_id(team))).toList();
        bool allowedByTeam(Map<String, dynamic> row) {
          final teamId = esportsInt(row['team_id'] ?? row['teamId']);
          return teamId <= 0 || allowedTeams.contains(teamId);
        }
        athletes = athletes.where(allowedByTeam).toList();
        matches = matches.where(allowedByTeam).toList();
        tournaments = tournaments.where(allowedByTeam).toList();
        streams = streams.where(allowedByTeam).toList();
        recordings = recordings.where(allowedByTeam).toList();
        reports = reports.where(allowedByTeam).toList();
      }

      final allowedAthletes = widget.allowedAthleteIds;
      if (allowedAthletes != null && allowedAthletes.isNotEmpty) {
        athletes = athletes.where((a) => allowedAthletes.contains(esportsInt(a['id'] ?? a['player_id']))).toList();
      }

      if (!mounted) return;
      setState(() {
        _teams = teams;
        _athletes = athletes;
        _matches = matches;
        _tournaments = tournaments;
        _streams = streams;
        _recordings = recordings;
        _reports = reports;
        _syncSelectedTeam();
      });
    } catch (error) {
      if (mounted) {
        setState(() => _serverError = 'Esports API пока не вернул все рабочие данные: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _syncSelectedTeam() {
    if (_selectedTeam != null) {
      final current = _id(_selectedTeam!);
      for (final team in _teams) {
        if (_id(team) == current) {
          _selectedTeam = team;
          return;
        }
      }
    }
    _selectedTeam = _teams.isNotEmpty ? _teams.first : null;
  }

  int? get _selectedTeamId {
    final id = _selectedTeam == null ? 0 : _id(_selectedTeam!);
    return id > 0 ? id : null;
  }

  String get _selectedTeamName {
    final name = esportsText(_selectedTeam?['name'] ?? _selectedTeam?['team_name']);
    return name.isEmpty ? 'Команда не выбрана' : name;
  }

  List<Map<String, dynamic>> get _selectedAthletes => _athletes.where((a) {
        if (_selectedTeamId == null) return true;
        final teamId = esportsInt(a['team_id'] ?? a['teamId']);
        return teamId <= 0 || teamId == _selectedTeamId;
      }).toList(growable: false);

  List<Map<String, dynamic>> get _selectedMatches => _matches.where((m) {
        if (_selectedTeamId == null) return true;
        final teamId = esportsInt(m['team_id'] ?? m['teamId']);
        return teamId <= 0 || teamId == _selectedTeamId;
      }).toList(growable: false);

  List<Map<String, dynamic>> get _selectedTournaments => _tournaments.where((t) {
        if (_selectedTeamId == null) return true;
        final teamId = esportsInt(t['team_id'] ?? t['teamId']);
        return teamId <= 0 || teamId == _selectedTeamId;
      }).toList(growable: false);

  bool get _desktopWide => (MediaQuery.maybeOf(context)?.size.width ?? 0) >= 1180;

  void _selectSection(EsportsWorkspaceSection section) {
    if (!_visibleSections.contains(section)) return;
    if (_desktopWide) {
      _openWindow(section);
      return;
    }
    setState(() => _section = section);
  }

  void _openLiveForMatch(Map<String, dynamic> match) {
    _liveInitialMatch = match;
    if (_desktopWide) {
      _openWindow(EsportsWorkspaceSection.live);
      return;
    }
    setState(() => _section = EsportsWorkspaceSection.live);
  }

  ThemeData _esportsTheme(BuildContext context) {
    final base = Theme.of(context);
    final family = AppTypography.fontFamily;

    TextStyle style(
      double size,
      FontWeight weight, {
      Color color = EsportsColors.text,
      double? height,
    }) {
      final baseStyle = height == null
          ? AppTypography.custom(
              size: size,
              weight: weight,
              color: color,
            )
          : AppTypography.custom(
              size: size,
              weight: weight,
              color: color,
              height: height,
            );
      return baseStyle.copyWith(fontFamily: family);
    }

    return base.copyWith(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textTheme: base.textTheme.apply(
        fontFamily: family,
        bodyColor: EsportsColors.text,
        displayColor: EsportsColors.text,
      ).copyWith(
        bodyLarge: style(12.5, FontWeight.w400),
        bodyMedium: style(11.5, FontWeight.w400),
        bodySmall: style(10.5, FontWeight.w400, color: EsportsColors.muted),
        titleLarge: style(17, FontWeight.w600),
        titleMedium: style(12.5, FontWeight.w600),
        titleSmall: style(11.5, FontWeight.w600),
        labelLarge: style(11.5, FontWeight.w600),
        labelMedium: style(10.5, FontWeight.w600),
        labelSmall: style(9.5, FontWeight.w600),
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: family,
        bodyColor: EsportsColors.text,
        displayColor: EsportsColors.text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        labelStyle: style(10.5, FontWeight.w500, color: EsportsColors.muted),
        floatingLabelStyle: style(10, FontWeight.w600, color: EsportsColors.greenDark),
        hintStyle: style(11.5, FontWeight.w400, color: EsportsColors.subtle),
        helperStyle: style(9.8, FontWeight.w400, color: EsportsColors.muted),
        errorStyle: style(9.8, FontWeight.w500, color: EsportsColors.red),
      ),
      popupMenuTheme: PopupMenuThemeData(
        textStyle: style(11.5, FontWeight.w500),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        titleTextStyle: style(11.5, FontWeight.w600),
        subtitleTextStyle: style(10.5, FontWeight.w400, color: EsportsColors.muted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _esportsTheme(context);

    if (_loading) {
      return Theme(
        data: theme,
        child: const Scaffold(
          backgroundColor: EsportsColors.bg,
          body: SafeArea(
            child: Center(
              child: CircularProgressIndicator(color: EsportsColors.green),
            ),
          ),
        ),
      );
    }

    final media = MediaQuery.of(context);
    final desktop = media.size.width >= 1180;
    if (desktop) {
      if (!_desktopInitialized) {
        _desktopInitialized = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_desktopWide) return;
          _openWindow(EsportsWorkspaceSection.teams);
        });
      }
      return Theme(
        data: theme,
        child: Scaffold(
          backgroundColor: EsportsColors.bg,
          body: SafeArea(child: _desktopWorkspace(media.size)),
        ),
      );
    }

    final phone = media.size.width < 720;
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: EsportsColors.bg,
        body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  _header(phone: phone),
                  const Divider(height: 1, color: EsportsColors.line),
                  if (_serverError != null) _serverNotice(),
                  Expanded(child: _content()),
                ],
              ),
            ),
            if (_refreshing)
              const Positioned.fill(
                bottom: 70,
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color(0x22FFFFFF),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: EsportsColors.green,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: phone ? 10 : 18,
              right: phone ? 10 : 18,
              bottom: phone ? 8 : 14,
              child: phone ? _mobileDock() : _desktopDock(),
            ),
          ],
          ),
        ),
      ),
    );
  }

  List<EsportsWorkspaceSection> get _desktopModules => <EsportsWorkspaceSection>[
        EsportsWorkspaceSection.workspaceOs,
        EsportsWorkspaceSection.teams,
        EsportsWorkspaceSection.roster,
        EsportsWorkspaceSection.matches,
        EsportsWorkspaceSection.calendar,
        EsportsWorkspaceSection.tournaments,
        EsportsWorkspaceSection.live,
        EsportsWorkspaceSection.video,
        EsportsWorkspaceSection.analytics,
        EsportsWorkspaceSection.ai,
        if (_canManageStaff) EsportsWorkspaceSection.staff,
      ].where(_visibleSections.contains).toList(growable: false);

  Widget _desktopWorkspace(Size desktopSize) {
    final visible = _openWindows.where((w) => !w.minimized).toList(growable: false)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: _EsportsWorkspaceWallpaper()),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onSecondaryTapDown: (details) => _showDesktopBackgroundMenu(details),
          ),
        ),
        Positioned.fill(child: _desktopIconsLayer(desktopSize)),
        Positioned(
          top: 20,
          right: 22,
          child: _EsportsActiveTeamShortcut(
            teamName: _selectedTeamName,
            hasTeam: _selectedTeamId != null,
            onChange: () => _openWindow(EsportsWorkspaceSection.teams),
          ),
        ),
        for (final window in visible) _positionedWindow(window, desktopSize),
        if (_refreshing)
          const Positioned.fill(
            bottom: 82,
            child: IgnorePointer(
              child: ColoredBox(
                color: Color(0x22FFFFFF),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: EsportsColors.green,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: _EsportsWorkspaceDock(
            modules: _desktopModules,
            openWindows: _openWindows,
            activeSection: _section,
            titleFor: _title,
            iconFor: _icon,
            onOpenStart: _openDesktopModulesMenu,
            onOpenSearch: _openDesktopSearch,
            onOpenAi: () => _openWindow(EsportsWorkspaceSection.ai),
            onOpenSection: _openWindow,
            onOpenSettings: _openDesktopSettings,
            onRefresh: () => _loadAll(),
            onHome: () => Navigator.of(context).maybePop(),
          ),
        ),
        if (_serverError != null)
          Positioned(
            left: 240,
            right: 240,
            top: 18,
            child: _serverNotice(),
          ),
      ],
    );
  }

  Widget _desktopIconsLayer(Size desktopSize) {
    return Stack(
      children: [
        for (int index = 0; index < _desktopModules.length; index++)
          _desktopIcon(_desktopModules[index], index, desktopSize),
      ],
    );
  }

  Widget _desktopIcon(
    EsportsWorkspaceSection section,
    int index,
    Size desktopSize,
  ) {
    final defaultPosition = Offset(
      24 + (index ~/ 6) * 104.0,
      22 + (index % 6) * 100.0,
    );
    final position = _desktopIconPositions[section] ?? defaultPosition;
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: _EsportsDesktopIcon(
        icon: _icon(section),
        label: _desktopShortTitle(section),
        onTap: () => _openWindow(section),
        onDragUpdate: (delta) {
          final maxX = math.max(12.0, desktopSize.width - 96);
          final maxY = math.max(12.0, desktopSize.height - 178);
          setState(() {
            _desktopIconPositions[section] = Offset(
              (position.dx + delta.dx).clamp(12.0, maxX).toDouble(),
              (position.dy + delta.dy).clamp(12.0, maxY).toDouble(),
            );
          });
        },
      ),
    );
  }

  String _desktopShortTitle(EsportsWorkspaceSection section) => switch (section) {
        EsportsWorkspaceSection.workspaceOs => 'Спортотека\nOS',
        EsportsWorkspaceSection.teams => 'Команды',
        EsportsWorkspaceSection.roster => 'Состав',
        EsportsWorkspaceSection.matches => 'Матчи',
        EsportsWorkspaceSection.calendar => 'Календарь',
        EsportsWorkspaceSection.tournaments => 'Турниры',
        EsportsWorkspaceSection.live => 'Live',
        EsportsWorkspaceSection.video => 'Видео',
        EsportsWorkspaceSection.analytics => 'Аналитика',
        EsportsWorkspaceSection.ai => 'ИИ',
        EsportsWorkspaceSection.staff => 'Staff',
        EsportsWorkspaceSection.overview => 'Обзор',
      };

  _EsportsWorkspaceWindowState? _windowFor(EsportsWorkspaceSection section) {
    for (final window in _openWindows) {
      if (window.section == section) return window;
    }
    return null;
  }

  void _openWindow(EsportsWorkspaceSection section) {
    if (!_visibleSections.contains(section)) return;
    final existing = _windowFor(section);
    setState(() {
      _section = section;
      if (existing != null) {
        existing.minimized = false;
        existing.zIndex = ++_windowZCounter;
        return;
      }
      final offset = (_openWindows.length % 6) * 34.0;
      _openWindows.add(
        _EsportsWorkspaceWindowState(
          id: 'esports_${section.name}_${DateTime.now().microsecondsSinceEpoch}',
          section: section,
          position: Offset(62 + offset, 46 + offset),
          size: _defaultWindowSize(section),
          zIndex: ++_windowZCounter,
        ),
      );
    });
  }

  Size _defaultWindowSize(EsportsWorkspaceSection section) {
    switch (section) {
      case EsportsWorkspaceSection.teams:
      case EsportsWorkspaceSection.roster:
      case EsportsWorkspaceSection.matches:
      case EsportsWorkspaceSection.live:
        return const Size(1040, 680);
      case EsportsWorkspaceSection.workspaceOs:
      case EsportsWorkspaceSection.video:
      case EsportsWorkspaceSection.analytics:
      case EsportsWorkspaceSection.ai:
      case EsportsWorkspaceSection.staff:
      case EsportsWorkspaceSection.tournaments:
      case EsportsWorkspaceSection.calendar:
      case EsportsWorkspaceSection.overview:
        return const Size(980, 650);
    }
  }

  Widget _positionedWindow(
    _EsportsWorkspaceWindowState window,
    Size desktopSize,
  ) {
    final minWidth = math.min(520.0, math.max(360.0, desktopSize.width - 24));
    final minHeight = math.min(420.0, math.max(300.0, desktopSize.height - 112));
    final safeWidth = window.size.width
        .clamp(minWidth, math.max(minWidth, desktopSize.width - 24))
        .toDouble();
    final safeHeight = window.size.height
        .clamp(minHeight, math.max(minHeight, desktopSize.height - 106))
        .toDouble();
    final maxLeft = math.max(8.0, desktopSize.width - safeWidth - 8);
    final maxTop = math.max(8.0, desktopSize.height - safeHeight - 96);
    final left = window.position.dx.clamp(8.0, maxLeft).toDouble();
    final top = window.position.dy.clamp(8.0, maxTop).toDouble();

    final child = _EsportsFloatingWindow(
      title: _title(window.section),
      subtitle: window.section == EsportsWorkspaceSection.teams
          ? widget.clubName
          : _selectedTeamName,
      icon: _icon(window.section),
      active: _section == window.section,
      maximized: window.maximized,
      onTap: () => _bringWindowToFront(window),
      onClose: () => _closeWindow(window),
      onMinimize: () => _minimizeWindow(window),
      onMaximize: () => _toggleMaximize(window),
      onDragUpdate: (delta) => _moveWindow(window, delta, desktopSize),
      onResizeUpdate: (delta) => _resizeWindow(window, delta, desktopSize),
      child: _buildSectionContent(window.section),
    );

    if (window.maximized) {
      return Positioned(left: 12, top: 12, right: 12, bottom: 92, child: child);
    }
    return Positioned(
      left: left,
      top: top,
      width: safeWidth,
      height: safeHeight,
      child: child,
    );
  }

  void _bringWindowToFront(_EsportsWorkspaceWindowState window) {
    setState(() {
      _section = window.section;
      window.minimized = false;
      window.zIndex = ++_windowZCounter;
    });
  }

  void _closeWindow(_EsportsWorkspaceWindowState window) {
    setState(() {
      _openWindows.removeWhere((w) => w.id == window.id);
      if (_openWindows.isNotEmpty) {
        final sorted = [..._openWindows]
          ..sort((a, b) => b.zIndex.compareTo(a.zIndex));
        _section = sorted.first.section;
      }
    });
  }

  void _minimizeWindow(_EsportsWorkspaceWindowState window) {
    setState(() => window.minimized = true);
  }

  void _toggleMaximize(_EsportsWorkspaceWindowState window) {
    setState(() {
      _section = window.section;
      window.maximized = !window.maximized;
      window.minimized = false;
      window.zIndex = ++_windowZCounter;
    });
  }

  void _moveWindow(
    _EsportsWorkspaceWindowState window,
    Offset delta,
    Size desktopSize,
  ) {
    setState(() {
      window.maximized = false;
      final maxX = math.max(8.0, desktopSize.width - window.size.width - 8);
      final maxY = math.max(8.0, desktopSize.height - window.size.height - 100);
      window.position = Offset(
        (window.position.dx + delta.dx).clamp(8.0, maxX).toDouble(),
        (window.position.dy + delta.dy).clamp(8.0, maxY).toDouble(),
      );
      window.zIndex = ++_windowZCounter;
      _section = window.section;
    });
  }

  void _resizeWindow(
    _EsportsWorkspaceWindowState window,
    Offset delta,
    Size desktopSize,
  ) {
    setState(() {
      window.maximized = false;
      final maxWidth = math.max(520.0, desktopSize.width - window.position.dx - 12);
      final maxHeight = math.max(420.0, desktopSize.height - window.position.dy - 102);
      window.size = Size(
        (window.size.width + delta.dx).clamp(520.0, maxWidth).toDouble(),
        (window.size.height + delta.dy).clamp(420.0, maxHeight).toDouble(),
      );
      window.zIndex = ++_windowZCounter;
      _section = window.section;
    });
  }

  Future<void> _showDesktopBackgroundMenu(TapDownDetails details) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        0,
        0,
      ),
      color: Colors.white.withOpacity(.99),
      elevation: 14,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: const [
        PopupMenuItem(value: 'refresh', child: Text('Обновить')),
        PopupMenuItem(value: 'settings', child: Text('Настройки рабочего стола')),
      ],
    );
    if (!mounted) return;
    if (action == 'refresh') await _loadAll();
    if (action == 'settings') _openDesktopSettings();
  }

  Future<void> _openDesktopModulesMenu() async {
    final selected = await showGeneralDialog<EsportsWorkspaceSection>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть меню',
      barrierColor: Colors.black.withOpacity(.28),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => _EsportsModulesMenu(
        clubName: widget.clubName,
        clubLogoUrl: widget.clubLogoUrl,
        modules: _desktopModules,
        activeSection: _section,
        titleFor: _title,
        iconFor: _icon,
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      ),
    );
    if (selected != null) _openWindow(selected);
  }

  Future<void> _openDesktopSearch() async {
    final selected = await showDialog<EsportsWorkspaceSection>(
      context: context,
      barrierColor: Colors.black.withOpacity(.20),
      builder: (_) => _EsportsModuleSearchDialog(
        modules: _desktopModules,
        titleFor: _title,
        iconFor: _icon,
      ),
    );
    if (selected != null) _openWindow(selected);
  }

  void _openDesktopSettings() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.18),
      builder: (_) => const _EsportsDesktopSettingsDialog(),
    );
  }

  Widget _header({required bool phone}) {
    return Container(
      height: phone ? 62 : 72,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: phone ? 12 : 18),
      child: Row(children: [
        Material(
          color: EsportsColors.soft,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(10),
            child: const SizedBox(width: 36, height: 36, child: Icon(Icons.arrow_back_rounded, size: 18, color: EsportsColors.muted)),
          ),
        ),
        const SizedBox(width: 10),
        _logo(phone ? 38 : 44),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.clubName.trim().isEmpty ? 'Sportoteka Esports' : widget.clubName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.custom(size: phone ? 14 : 16, weight: FontWeight.w600, color: EsportsColors.text),
              ),
              const SizedBox(height: 2),
              Text(
                _selectedTeam == null ? 'Киберспортивное направление' : 'Esports · $_selectedTeamName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.captionMedium(color: EsportsColors.muted),
              ),
            ],
          ),
        ),
        if (!phone && _selectedTeam != null)
          PopupMenuButton<int>(
            tooltip: 'Выбрать киберкоманду',
            onSelected: (id) {
              for (final team in _teams) {
                if (_id(team) == id) {
                  setState(() => _selectedTeam = team);
                  break;
                }
              }
            },
            itemBuilder: (_) => _teams.map((team) => PopupMenuItem<int>(value: _id(team), child: Text(esportsText(team['name'] ?? team['team_name']), style: esportsFieldTextStyle()))).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(11)),
              child: Row(children: [
                const Icon(Icons.groups_2_outlined, size: 17, color: EsportsColors.greenDark),
                const SizedBox(width: 7),
                Text(_selectedTeamName, style: AppTypography.action(color: EsportsColors.text)),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded, size: 17, color: EsportsColors.muted),
              ]),
            ),
          ),
        const SizedBox(width: 8),
        IconButton(onPressed: () => _loadAll(), icon: const Icon(Icons.refresh_rounded, color: EsportsColors.greenDark)),
      ]),
    );
  }

  Widget _serverNotice() => Container(
        width: double.infinity,
        color: const Color(0xFFFFFBEB),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(_serverError!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.custom(size: 10.5, weight: FontWeight.w500, color: const Color(0xFF92400E))),
      );

  Widget _content() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 170),
      child: KeyedSubtree(
        key: ValueKey('${_section.name}-${_selectedTeamId ?? 0}'),
        child: _buildSectionContent(_section),
      ),
    );
  }

  Widget _buildSectionContent(EsportsWorkspaceSection section) {
    return switch (section) {
      EsportsWorkspaceSection.overview => EsportsOverviewPanel(
          clubName: widget.clubName,
          teams: _teams,
          athletes: _athletes,
          matches: _matches,
          tournaments: _tournaments,
          streams: _streams,
          onOpenTeams: () => _selectSection(EsportsWorkspaceSection.teams),
          onOpenRoster: () => _selectSection(EsportsWorkspaceSection.roster),
          onOpenMatches: () => _selectSection(EsportsWorkspaceSection.matches),
          onOpenLive: () => _selectSection(EsportsWorkspaceSection.live),
        ),
      EsportsWorkspaceSection.teams => EsportsTeamsPanel(
          clubId: widget.clubId,
          userId: widget.userId,
          clubName: widget.clubName,
          teams: _teams,
          selectedTeamId: _selectedTeamId,
          onSelectTeam: (team) => setState(() => _selectedTeam = team),
          onRefresh: () => _loadAll(),
          canManage: _canManageTeams,
          onOpenRoster: () => _selectSection(EsportsWorkspaceSection.roster),
          onOpenMatches: () => _selectSection(EsportsWorkspaceSection.matches),
          onOpenCalendar: () => _selectSection(EsportsWorkspaceSection.calendar),
          onOpenStaff: _canManageStaff
              ? () => _selectSection(EsportsWorkspaceSection.staff)
              : null,
        ),
      EsportsWorkspaceSection.roster => EsportsRosterPanel(
          clubId: widget.clubId,
          userId: widget.userId,
          selectedTeamId: _selectedTeamId,
          selectedTeamName: _selectedTeamName,
          athletes: _athletes,
          teams: _teams,
          matches: _selectedMatches,
          recordings: _recordings,
          reports: _reports,
          allowedAthleteIds: widget.allowedAthleteIds,
          canManage: _canManageRoster,
          onRefresh: () => _loadAll(),
        ),
      EsportsWorkspaceSection.matches => EsportsMatchesPanel(
          clubId: widget.clubId,
          userId: widget.userId,
          selectedTeamId: _selectedTeamId,
          selectedTeamName: _selectedTeamName,
          teams: _teams,
          matches: _matches,
          canManage: _canManageMatches,
          onRefresh: () => _loadAll(),
          onOpenLive: _openLiveForMatch,
        ),
      EsportsWorkspaceSection.calendar => EsportsCalendarPanel(
          matches: _selectedMatches,
          tournaments: _selectedTournaments,
          selectedTeamName: _selectedTeamName,
        ),
      EsportsWorkspaceSection.tournaments => EsportsTournamentsPanel(
          clubId: widget.clubId,
          userId: widget.userId,
          selectedTeamId: _selectedTeamId,
          teams: _teams,
          tournaments: _tournaments,
          canManage: _canManageTournaments,
          onRefresh: () => _loadAll(),
        ),
      EsportsWorkspaceSection.live => EsportsLivePanel(
          clubId: widget.clubId,
          userId: widget.userId,
          selectedTeamId: _selectedTeamId,
          selectedTeamName: _selectedTeamName,
          matches: _selectedMatches,
          initialMatch: _liveInitialMatch,
          canManage: _canManageLive,
          onRefresh: () => _loadAll(),
        ),
      EsportsWorkspaceSection.video => EsportsVideoPanel(
          recordings: _recordings,
          streams: _streams,
          selectedTeamName: _selectedTeamName,
          onOpenLive: () => _selectSection(EsportsWorkspaceSection.live),
        ),
      EsportsWorkspaceSection.analytics => EsportsAnalyticsPanel(
          matches: _selectedMatches,
          athletes: _selectedAthletes,
          selectedTeamName: _selectedTeamName,
        ),
      EsportsWorkspaceSection.ai => EsportsAiPanel(
          clubId: widget.clubId,
          matches: _selectedMatches,
          reports: _reports,
          selectedTeamName: _selectedTeamName,
          onRefresh: () => _loadAll(),
        ),
      EsportsWorkspaceSection.staff => EsportsStaffAccessPanel(
          clubId: widget.clubId,
          actorUserId: widget.userId,
          clubName: widget.clubName,
          teams: _teams,
          athletes: _athletes,
        ),
      EsportsWorkspaceSection.workspaceOs => EsportsWorkspaceOsPanel(
          clubName: widget.clubName,
          teams: _teams,
          athletes: _athletes,
          matches: _matches,
          recordings: _recordings,
          reports: _reports,
        ),
    };
  }

  Widget _mobileDock() {
    final primary = <EsportsWorkspaceSection>[
      EsportsWorkspaceSection.teams,
      EsportsWorkspaceSection.roster,
      EsportsWorkspaceSection.matches,
      EsportsWorkspaceSection.live,
    ].where(_visibleSections.contains).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F1).withOpacity(.97),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFDCE6E0)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 26, spreadRadius: -10, offset: const Offset(0, 12))],
          ),
          child: Row(children: [
            _mobileDockIcon(EsportsWorkspaceSection.overview),
            for (final s in primary) _mobileDockIcon(s),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openMore,
                child: const Center(child: Icon(Icons.more_horiz_rounded, size: 21, color: Color(0xFF475467))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _mobileDockIcon(EsportsWorkspaceSection s) {
    final active = _section == s;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectSection(s),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            width: active ? 42 : 37,
            height: 36,
            decoration: BoxDecoration(color: active ? const Color(0xFFDDF2E6) : Colors.transparent, borderRadius: BorderRadius.circular(999)),
            child: Icon(_icon(s), size: active ? 21 : 20, color: active ? EsportsColors.greenDark : const Color(0xFF475467)),
          ),
        ),
      ),
    );
  }

  Widget _desktopDock() {
    final sections = _visibleSections.toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.96),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFE3E8EF)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 24, spreadRadius: -10, offset: const Offset(0, 12))],
              ),
              child: Row(children: [
                _dockButton(EsportsWorkspaceSection.overview),
                const SizedBox(width: 6),
                const SizedBox(height: 30, width: 1, child: ColoredBox(color: EsportsColors.line)),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final s in sections.where((s) => s != EsportsWorkspaceSection.overview)) ...[
                        _dockButton(s),
                        const SizedBox(width: 5),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(width: 6),
                const SizedBox(height: 30, width: 1, child: ColoredBox(color: EsportsColors.line)),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Обновить',
                  child: InkWell(
                    onTap: () => _loadAll(),
                    borderRadius: BorderRadius.circular(13),
                    child: const SizedBox(width: 40, height: 40, child: Icon(Icons.refresh_rounded, size: 20, color: EsportsColors.muted)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dockButton(EsportsWorkspaceSection s) {
    final active = _section == s;
    return Tooltip(
      message: _title(s),
      child: InkWell(
        onTap: () => _selectSection(s),
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: active ? EsportsColors.greenSoft : Colors.transparent, borderRadius: BorderRadius.circular(13)),
          child: Icon(_icon(s), size: 20, color: active ? EsportsColors.greenDark : EsportsColors.muted),
        ),
      ),
    );
  }

  Future<void> _openMore() async {
    final selected = await showModalBottomSheet<EsportsWorkspaceSection>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: _visibleSections.map((s) => ListTile(
            leading: Icon(_icon(s), color: _section == s ? EsportsColors.greenDark : EsportsColors.muted),
            title: Text(_title(s)),
            selected: _section == s,
            onTap: () => Navigator.of(context).pop(s),
          )).toList(),
        ),
      ),
    );
    if (selected != null) _selectSection(selected);
  }

  Widget _logo(double size) {
    final url = (widget.clubLogoUrl ?? '').trim();
    final fallback = Container(width: size, height: size, decoration: BoxDecoration(color: EsportsColors.greenSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.sports_esports_rounded, color: EsportsColors.greenDark));
    if (url.isEmpty) return fallback;
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback));
  }

  String _title(EsportsWorkspaceSection s) => switch (s) {
        EsportsWorkspaceSection.overview => 'Обзор',
        EsportsWorkspaceSection.teams => 'Команды',
        EsportsWorkspaceSection.roster => 'Состав',
        EsportsWorkspaceSection.matches => 'Матчи',
        EsportsWorkspaceSection.calendar => 'Календарь',
        EsportsWorkspaceSection.tournaments => 'Турниры',
        EsportsWorkspaceSection.live => 'Live',
        EsportsWorkspaceSection.video => 'Видео',
        EsportsWorkspaceSection.analytics => 'Аналитика',
        EsportsWorkspaceSection.ai => 'ИИ',
        EsportsWorkspaceSection.staff => 'Staff',
        EsportsWorkspaceSection.workspaceOs => 'Sportoteka OS',
      };

  IconData _icon(EsportsWorkspaceSection s) => switch (s) {
        EsportsWorkspaceSection.overview => Icons.home_rounded,
        EsportsWorkspaceSection.teams => Icons.account_tree_outlined,
        EsportsWorkspaceSection.roster => Icons.groups_2_outlined,
        EsportsWorkspaceSection.matches => Icons.stadium_outlined,
        EsportsWorkspaceSection.calendar => Icons.calendar_month_outlined,
        EsportsWorkspaceSection.tournaments => Icons.emoji_events_outlined,
        EsportsWorkspaceSection.live => Icons.sensors_rounded,
        EsportsWorkspaceSection.video => Icons.video_library_outlined,
        EsportsWorkspaceSection.analytics => Icons.query_stats_rounded,
        EsportsWorkspaceSection.ai => Icons.auto_awesome_rounded,
        EsportsWorkspaceSection.staff => Icons.badge_outlined,
        EsportsWorkspaceSection.workspaceOs => Icons.folder_open_rounded,
      };
}


class _EsportsWorkspaceWindowState {
  final String id;
  final EsportsWorkspaceSection section;
  Offset position;
  Size size;
  bool minimized;
  bool maximized;
  int zIndex;

  _EsportsWorkspaceWindowState({
    required this.id,
    required this.section,
    required this.position,
    required this.size,
    required this.zIndex,
    this.minimized = false,
    this.maximized = false,
  });
}

class _EsportsWorkspaceWallpaper extends StatelessWidget {
  const _EsportsWorkspaceWallpaper();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FBF8), Color(0xFFEAF8F0), Color(0xFFF5F7FA)],
        ),
      ),
      child: CustomPaint(painter: _EsportsWorkspacePatternPainter()),
    );
  }
}

class _EsportsWorkspacePatternPainter extends CustomPainter {
  const _EsportsWorkspacePatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = EsportsColors.green.withOpacity(.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 56) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 56) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [EsportsColors.green.withOpacity(.12), Colors.transparent],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .78, size.height * .20),
          radius: 360,
        ),
      );
    canvas.drawCircle(Offset(size.width * .78, size.height * .20), 360, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EsportsDesktopIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDragUpdate;

  const _EsportsDesktopIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onDragUpdate,
  });

  @override
  State<_EsportsDesktopIcon> createState() => _EsportsDesktopIconState();
}

class _EsportsDesktopIconState extends State<_EsportsDesktopIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (details) => widget.onDragUpdate(details.delta),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 84,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withOpacity(.62)
                : Colors.white.withOpacity(.30),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withOpacity(_hovered ? .72 : .34),
              width: .7,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.96),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: const Color(0xFF344054), size: 27),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.custom(
                  size: 11,
                  weight: FontWeight.w600,
                  color: const Color(0xFF111827),
                  height: 1.08,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EsportsActiveTeamShortcut extends StatelessWidget {
  final String teamName;
  final bool hasTeam;
  final VoidCallback onChange;

  const _EsportsActiveTeamShortcut({
    required this.teamName,
    required this.hasTeam,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final safeName = hasTeam ? teamName : 'Команда не выбрана';
    return Container(
      width: 380,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EsportsColors.green.withOpacity(.23)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 26,
            spreadRadius: -14,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: EsportsColors.greenSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: EsportsColors.greenDark,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'АКТИВНАЯ КИБЕРКОМАНДА',
                  style: AppTypography.custom(
                    size: 9.6,
                    weight: FontWeight.w700,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  safeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.custom(
                    size: 13,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF344054),
              backgroundColor: const Color(0xFFF4F6F4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Сменить'),
          ),
        ],
      ),
    );
  }
}

class _EsportsFloatingWindow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final bool maximized;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<Offset> onResizeUpdate;
  final Widget child;

  const _EsportsFloatingWindow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.maximized,
    required this.onTap,
    required this.onClose,
    required this.onMinimize,
    required this.onMaximize,
    required this.onDragUpdate,
    required this.onResizeUpdate,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(maximized ? 14 : 18),
          border: Border.all(
            color: active
                ? Colors.white.withOpacity(.85)
                : const Color(0xFFE8ECEA).withOpacity(.70),
            width: .8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(active ? .16 : .10),
              blurRadius: active ? 38 : 28,
              spreadRadius: -12,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: onMaximize,
                    onPanUpdate: maximized ? null : (d) => onDragUpdate(d.delta),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: const Color(0xFFFBFCFB),
                      child: Row(
                        children: [
                          _WindowControlButton(
                            icon: Icons.close_rounded,
                            tooltip: 'Закрыть',
                            onTap: onClose,
                          ),
                          const SizedBox(width: 5),
                          _WindowControlButton(
                            icon: Icons.remove_rounded,
                            tooltip: 'Свернуть',
                            onTap: onMinimize,
                          ),
                          const SizedBox(width: 5),
                          _WindowControlButton(
                            icon: maximized
                                ? Icons.close_fullscreen_rounded
                                : Icons.open_in_full_rounded,
                            tooltip: maximized ? 'Восстановить' : 'Развернуть',
                            onTap: onMaximize,
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: EsportsColors.greenSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: EsportsColors.greenDark, size: 19),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.custom(
                                    size: 13.5,
                                    weight: FontWeight.w700,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.custom(
                                    size: 10.5,
                                    weight: FontWeight.w500,
                                    color: const Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE9ECEA)),
                  Expanded(child: child),
                ],
              ),
            ),
            if (!maximized)
              Positioned(
                right: 1,
                bottom: 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) => onResizeUpdate(d.delta),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(
                        Icons.drag_handle_rounded,
                        size: 14,
                        color: Color(0xFF98A2B3),
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
}

class _WindowControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _WindowControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE1E5EA), width: .7),
          ),
          child: Icon(icon, size: 11, color: const Color(0xFF667085)),
        ),
      ),
    );
  }
}

class _EsportsWorkspaceDock extends StatelessWidget {
  final List<EsportsWorkspaceSection> modules;
  final List<_EsportsWorkspaceWindowState> openWindows;
  final EsportsWorkspaceSection activeSection;
  final String Function(EsportsWorkspaceSection) titleFor;
  final IconData Function(EsportsWorkspaceSection) iconFor;
  final VoidCallback onOpenStart;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenAi;
  final ValueChanged<EsportsWorkspaceSection> onOpenSection;
  final VoidCallback onOpenSettings;
  final VoidCallback onRefresh;
  final VoidCallback onHome;

  const _EsportsWorkspaceDock({
    required this.modules,
    required this.openWindows,
    required this.activeSection,
    required this.titleFor,
    required this.iconFor,
    required this.onOpenStart,
    required this.onOpenSearch,
    required this.onOpenAi,
    required this.onOpenSection,
    required this.onOpenSettings,
    required this.onRefresh,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final running = openWindows.map((w) => w.section).toSet();
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(MediaQuery.of(context).size.width - 28, 1080),
        ),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.96),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE3E8EF)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 24,
                spreadRadius: -10,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DockButton(icon: Icons.grid_view_rounded, tooltip: 'Все модули', onTap: onOpenStart),
              const SizedBox(width: 6),
              _DockButton(icon: Icons.search_rounded, tooltip: 'Поиск', onTap: onOpenSearch),
              const SizedBox(width: 5),
              _DockButton(
                icon: Icons.auto_awesome_rounded,
                tooltip: 'СПОРТОТЕКА ИИ',
                active: activeSection == EsportsWorkspaceSection.ai,
                running: running.contains(EsportsWorkspaceSection.ai),
                iconColor: EsportsColors.greenDark,
                onTap: onOpenAi,
              ),
              const SizedBox(width: 8),
              const _DockDivider(),
              const SizedBox(width: 8),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final section in modules) ...[
                        _DockButton(
                          icon: iconFor(section),
                          tooltip: titleFor(section),
                          active: activeSection == section,
                          running: running.contains(section),
                          minimized: openWindows.any((w) => w.section == section && w.minimized),
                          onTap: () => onOpenSection(section),
                        ),
                        const SizedBox(width: 5),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const _DockDivider(),
              const SizedBox(width: 8),
              _DockButton(icon: Icons.tune_rounded, tooltip: 'Настройки рабочего стола', onTap: onOpenSettings),
              const SizedBox(width: 5),
              _DockButton(icon: Icons.refresh_rounded, tooltip: 'Обновить', onTap: onRefresh),
              const SizedBox(width: 5),
              _DockButton(icon: Icons.home_rounded, tooltip: 'На главную', onTap: onHome),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockDivider extends StatelessWidget {
  const _DockDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: const Color(0xFFE3E8EF),
      );
}

class _DockButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final bool running;
  final bool minimized;
  final Color? iconColor;

  const _DockButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.running = false,
    this.minimized = false,
    this.iconColor,
  });

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.active
        ? const Color(0xFFF0F2F5)
        : _hovered
            ? const Color(0xFFF3F5F7)
            : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(17),
          child: SizedBox(
            width: widget.active ? 46 : 40,
            height: 45,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: widget.active ? 46 : 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: widget.active
                          ? const Color(0xFFE3E8EF)
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor ?? const Color(0xFF344054),
                    size: 21,
                  ),
                ),
                if (widget.running)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: widget.minimized ? 12 : 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.minimized
                            ? const Color(0xFF98A2B3)
                            : const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(999),
                      ),
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

class _EsportsModulesMenu extends StatelessWidget {
  final String clubName;
  final String? clubLogoUrl;
  final List<EsportsWorkspaceSection> modules;
  final EsportsWorkspaceSection activeSection;
  final String Function(EsportsWorkspaceSection) titleFor;
  final IconData Function(EsportsWorkspaceSection) iconFor;

  const _EsportsModulesMenu({
    required this.clubName,
    required this.clubLogoUrl,
    required this.modules,
    required this.activeSection,
    required this.titleFor,
    required this.iconFor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: math.min(760, MediaQuery.of(context).size.width - 64),
          constraints: const BoxConstraints(maxHeight: 620),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.18),
                blurRadius: 50,
                spreadRadius: -12,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: EsportsColors.greenSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sports_esports_rounded, color: EsportsColors.greenDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clubName,
                          style: AppTypography.custom(size: 16, weight: FontWeight.w700, color: EsportsColors.text),
                        ),
                        Text(
                          'Киберспортивное направление',
                          style: AppTypography.captionMedium(color: EsportsColors.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded, color: Color(0xFF344054)),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFE9ECEA)),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisExtent: 96,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: modules.length,
                  itemBuilder: (_, index) {
                    final section = modules[index];
                    final active = activeSection == section;
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(section),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: active ? EsportsColors.greenSoft : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: active ? EsportsColors.green.withOpacity(.2) : const Color(0xFFE9ECEA)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: active ? Colors.white : const Color(0xFFF7F8F7),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(iconFor(section), color: const Color(0xFF344054), size: 22),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              titleFor(section),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.custom(size: 10.5, weight: FontWeight.w600, color: EsportsColors.text, height: 1.08),
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
        ),
      ),
    );
  }
}

class _EsportsModuleSearchDialog extends StatefulWidget {
  final List<EsportsWorkspaceSection> modules;
  final String Function(EsportsWorkspaceSection) titleFor;
  final IconData Function(EsportsWorkspaceSection) iconFor;

  const _EsportsModuleSearchDialog({
    required this.modules,
    required this.titleFor,
    required this.iconFor,
  });

  @override
  State<_EsportsModuleSearchDialog> createState() => _EsportsModuleSearchDialogState();
}

class _EsportsModuleSearchDialogState extends State<_EsportsModuleSearchDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _controller.text.trim().toLowerCase();
    final visible = widget.modules.where((s) => widget.titleFor(s).toLowerCase().contains(q)).toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _controller,
                style: esportsFieldTextStyle(),
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Поиск модуля',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF7F8F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (_, index) {
                  final section = visible[index];
                  return ListTile(
                    leading: Icon(widget.iconFor(section), color: EsportsColors.greenDark),
                    title: Text(widget.titleFor(section), style: esportsFieldTextStyle()),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(section),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EsportsDesktopSettingsDialog extends StatelessWidget {
  const _EsportsDesktopSettingsDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Настройки рабочего стола'),
      content: const SizedBox(
        width: 440,
        child: Text(
          'Рабочий стол Esports использует тот же CMR-принцип: ярлыки, плавающие окна и нижний Dock. Настройки направления и Staff находятся внутри соответствующих модулей.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(backgroundColor: EsportsColors.green),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}
