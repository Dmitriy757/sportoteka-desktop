// lib/presentation/club_workspace/cmr_club_roster_panel.dart
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/routes/app_routes.dart';

// ==================== Цветовая схема ====================

class _CmrRosterColors {
  // Премиальная CMR-система: бело-графитовая база и точечный зелёный Sportoteka.
  static const Color bg = Color(0xFFF5F6F7);
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF8F9FA);
  static const Color soft2 = Color(0xFFF1F3F5);

  // Контрастная типографика: серый только для вторичных подписей.
  static const Color text = Color(0xFF0B0F14);
  static const Color text2 = Color(0xFF182230);
  static const Color muted = Color(0xFF374151);
  static const Color muted2 = Color(0xFF6B7280);

  static const Color graphite = Color(0xFF111827);
  static const Color graphiteSoft = Color(0xFF1F2937);

  // Фирменный зелёный — только как тонкий дорогой акцент.
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color greenSoft2 = Color(0xFFF8FEFA);
  static const Color greenBorder = Color(0xFFD7F0E2);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF7ED);
  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F1);
  static const Color redBorder = Color(0xFFFEE4E2);
  static const Color line = Color(0xFFE5E7EB);
}

// ==================== Текстовые стили ====================

class _CmrRosterText {
  static const String font = 'Roboto';

  static double _compact(double size) => size <= 10 ? size : size - 1.25;

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required Color color,
    double height = 1.18,
    double letterSpacing = -0.12,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontFamily: font,
      color: color,
      fontSize: _compact(size),
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: features,
    );
  }

  static TextStyle title(double size) => _base(
        size: size,
        weight: FontWeight.w900,
        color: _CmrRosterColors.text,
        height: 1.12,
        letterSpacing: -0.25,
      );

  static TextStyle section() => _base(
        size: 15.5,
        weight: FontWeight.w900,
        color: _CmrRosterColors.text,
        height: 1.12,
        letterSpacing: -0.22,
      );

  static TextStyle value(double size) => _base(
        size: size,
        weight: FontWeight.w800,
        color: _CmrRosterColors.text2,
        height: 1.22,
        features: const [FontFeature.tabularFigures()],
      );

  static TextStyle muted(double size) => _base(
        size: size,
        weight: FontWeight.w700,
        color: _CmrRosterColors.muted,
        height: 1.34,
        letterSpacing: -0.05,
      );

  static TextStyle caption() => _base(
        size: 12,
        weight: FontWeight.w800,
        color: _CmrRosterColors.muted2,
        height: 1.12,
        letterSpacing: .08,
      );

  static TextStyle pill({Color? color}) => _base(
        size: 12,
        weight: FontWeight.w800,
        color: color ?? _CmrRosterColors.text2,
        height: 1,
      );

  static TextStyle tab({bool active = false}) => _base(
        size: 13,
        weight: FontWeight.w900,
        color: active ? Colors.white : _CmrRosterColors.text2,
        height: 1,
      );

  static TextStyle action({Color color = _CmrRosterColors.text}) => _base(
        size: 13,
        weight: FontWeight.w900,
        color: color,
        height: 1.1,
      );

  static TextStyle danger() => _base(
        size: 13,
        weight: FontWeight.w900,
        color: _CmrRosterColors.red,
        height: 1.1,
      );
}

// ==================== Декораторы ====================

class _CmrRosterDecor {
  static double _hardRadius(double radius, {double max = 14}) => math.min(radius, max);

  static BoxDecoration panel({double radius = 14, bool elevated = false}) => BoxDecoration(
        color: _CmrRosterColors.panel,
        borderRadius: BorderRadius.circular(_hardRadius(radius, max: 14)),
        border: Border.all(color: _CmrRosterColors.line, width: 1),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      );

  static BoxDecoration softCard({double radius = 10, bool active = false}) => BoxDecoration(
        color: active ? _CmrRosterColors.panel : _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(_hardRadius(radius, max: 12)),
        border: Border.all(
          color: active ? _CmrRosterColors.green.withOpacity(.42) : _CmrRosterColors.line,
          width: active ? 1.2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      );

  static BoxDecoration greenCard({double radius = 10}) => BoxDecoration(
        color: _CmrRosterColors.panel,
        borderRadius: BorderRadius.circular(_hardRadius(radius, max: 12)),
        border: Border.all(color: _CmrRosterColors.green.withOpacity(.38), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      );
}

// ==================== Основной виджет ====================

class CmrClubRosterPanel extends StatefulWidget {
  final String teamName;
  final int? selectedTeamId;
  final int clubId;
  final List<Map<String, dynamic>> players;
  final bool loading;
  final Map<String, dynamic>? selectedPlayer;
  final Future<void> Function()? onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpenPlayer;
  final VoidCallback onOpenFullRoster;
  final VoidCallback onAddPlayer;
  final Future<void> Function(Map<String, dynamic> player)? onDeletePlayer;

  const CmrClubRosterPanel({
    super.key,
    required this.teamName,
    required this.selectedTeamId,
    required this.clubId,
    required this.players,
    required this.loading,
    required this.selectedPlayer,
    required this.onRefresh,
    required this.onOpenPlayer,
    required this.onOpenFullRoster,
    required this.onAddPlayer,
    this.onDeletePlayer,
  });

  @override
  State<CmrClubRosterPanel> createState() => _CmrClubRosterPanelState();
}

enum _RosterFilter { all, goalkeepers, defenders, midfielders, forwards, withoutPosition }

class _CmrClubRosterPanelState extends State<CmrClubRosterPanel> {
  final TextEditingController _searchC = TextEditingController();
  final ScrollController _scrollC = ScrollController();
  _RosterFilter _filter = _RosterFilter.all;

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _searchC.removeListener(_onSearchChanged);
    _searchC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visiblePlayers {
    final q = _searchC.text.trim().toLowerCase();
    return widget.players.where((player) {
      final position = _playerPosition(player).toLowerCase();
      final haystack = [
        _playerName(player),
        _playerPosition(player),
        _first(player, const ['number', 'player_number', 'shirt_number']),
        _first(player, const ['email', 'phone']),
        _first(player, const ['sport_data', 'sportData']),
      ].join(' ').toLowerCase();

      final matchesSearch = q.isEmpty || haystack.contains(q);
      if (!matchesSearch) return false;

      switch (_filter) {
        case _RosterFilter.all:
          return true;
        case _RosterFilter.goalkeepers:
          return position.contains('врат') || position.contains('gk') || position.contains('goal');
        case _RosterFilter.defenders:
          return position.contains('защит') || position.contains('def');
        case _RosterFilter.midfielders:
          return position.contains('полу') || position.contains('mid');
        case _RosterFilter.forwards:
          return position.contains('напад') ||
              position.contains('форвар') ||
              position.contains('striker') ||
              position.contains('forward');
        case _RosterFilter.withoutPosition:
          return position.isEmpty || position == 'амплуа' || position == 'не указано';
      }
    }).toList();
  }

  String _playerIdentity(Map<String, dynamic>? player) {
    if (player == null) return '';
    const idKeys = [
      'id',
      'player_id',
      'playerId',
      'user_id',
      'userId',
      'member_id',
      'memberId',
    ];

    for (final key in idKeys) {
      final value = _s(player[key]);
      if (value.isNotEmpty && value != '0') return '$key:$value';
    }

    final fallback = [
      _s(player['first_name'] ?? player['firstname']),
      _s(player['last_name'] ?? player['lastname']),
      _s(player['fullName'] ?? player['full_name'] ?? player['name']),
      _s(player['birth_date'] ?? player['birthDate'] ?? player['birthday']),
    ].where((value) => value.isNotEmpty).join('|');

    return fallback.isEmpty ? '' : 'fallback:$fallback';
  }

  void _openFullProfile(Map<String, dynamic> player) {
    final mp = Map<String, dynamic>.from(player);
    mp['team_id'] ??= mp['teamId'] ?? widget.selectedTeamId;
    mp['teamId'] ??= mp['team_id'] ?? widget.selectedTeamId;
    mp['club_id'] ??= mp['clubId'] ?? widget.clubId;
    mp['clubId'] ??= mp['club_id'] ?? widget.clubId;

    Get.toNamed(
      AppRoutes.playerProfileScreen,
      arguments: mp,
    );
  }

  void _handleOpenPlayer(Map<String, dynamic> player, bool mobile) {
    widget.onOpenPlayer(player);
    if (!mobile) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: .88,
          minChildSize: .45,
          maxChildSize: .96,
          expand: false,
          builder: (context, controller) {
            return _PlayerDetailPanel(
              player: player,
              teamName: widget.teamName,
              scrollController: controller,
              onOpenFullProfile: () {
                Navigator.of(sheetContext).pop();
                _openFullProfile(player);
              },
              onDeletePlayer: widget.onDeletePlayer == null
                  ? null
                  : () async {
                      Navigator.of(sheetContext).pop();
                      await _confirmDeletePlayer(player);
                    },
              onClose: () => Navigator.of(sheetContext).pop(),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeletePlayer(Map<String, dynamic> player) async {
    if (!mounted) return;

    final name = _playerName(player);
    const codeWord = 'УДАЛИТЬ';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var typedCode = '';
        var deleting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canDelete = typedCode.trim().toUpperCase() == codeWord;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.all(20),
                decoration: _CmrRosterDecor.panel(radius: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: _CmrRosterColors.redSoft,
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(color: _CmrRosterColors.redBorder),
                          ),
                          child: const Icon(
                            Icons.delete_forever_rounded,
                            color: _CmrRosterColors.red,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Удалить игрока?', style: _CmrRosterText.title(20)),
                              const SizedBox(height: 4),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _CmrRosterText.muted(13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _CmrRosterColors.redSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _CmrRosterColors.redBorder),
                      ),
                      child: Text(
                        'Игрок будет удалён из состава. Это действие нельзя будет отменить без повторного добавления игрока.',
                        style: _CmrRosterText.muted(13),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Введите кодовое слово: $codeWord', style: _CmrRosterText.title(14)),
                    const SizedBox(height: 10),
                    TextField(
                      enabled: !deleting,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) => setDialogState(() => typedCode = value),
                      onSubmitted: (_) {
                        if (!deleting && canDelete) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: codeWord,
                        filled: true,
                        fillColor: _CmrRosterColors.soft,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: _CmrRosterColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: _CmrRosterColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: _CmrRosterColors.green, width: 1.5),
                        ),
                      ),
                      style: _CmrRosterText.title(14),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _CmrRosterOutlineButton(
                            title: 'Отмена',
                            onTap: deleting ? null : () => Navigator.of(dialogContext).pop(false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CmrRosterDangerButton(
                            title: deleting ? 'Удаление...' : 'Удалить',
                            enabled: canDelete && !deleting,
                            onTap: () {
                              setDialogState(() => deleting = true);
                              Navigator.of(dialogContext).pop(true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || confirmed != true) return;

    final deletePlayer = widget.onDeletePlayer;
    if (deletePlayer == null) {
      Get.snackbar(
        'Удаление не подключено',
        'Передайте onDeletePlayer в CmrClubRosterPanel и вызовите API delete_player.php.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;

      await deletePlayer(player);
      if (!mounted) return;

      Get.snackbar(
        'Игрок удалён',
        name,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _CmrRosterColors.green,
        colorText: Colors.white,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onRefresh?.call();
      });
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Не удалось удалить игрока',
        '$e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _CmrRosterColors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator(color: _CmrRosterColors.green));
    }

    final visiblePlayers = _visiblePlayers;

    return Container(
      color: _CmrRosterColors.bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 720;
          final compact = constraints.maxWidth < 980;
          final listWidth = math.min(480.0, constraints.maxWidth * .45);

          final list = _RosterListPanel(
            teamName: widget.teamName,
            playersCount: widget.players.length,
            visibleCount: visiblePlayers.length,
            searchController: _searchC,
            scrollController: _scrollC,
            filter: _filter,
            onFilterChanged: (value) => setState(() => _filter = value),
            onAddPlayer: widget.onAddPlayer,
            onRefresh: widget.onRefresh,
            onDeletePlayer: _confirmDeletePlayer,
            players: visiblePlayers,
            selectedKey: _playerIdentity(widget.selectedPlayer),
            playerIdentity: _playerIdentity,
            onOpenPlayer: (player) => _handleOpenPlayer(player, mobile),
            compact: compact,
            mobile: mobile,
          );

          if (mobile) {
            return SizedBox(width: double.infinity, child: list);
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: listWidth, child: list),
              const SizedBox(width: 12),
              Expanded(
                child: _PlayerDetailPanel(
                  player: widget.selectedPlayer,
                  teamName: widget.teamName,
                  onOpenFullProfile: widget.selectedPlayer == null
                      ? null
                      : () => _openFullProfile(widget.selectedPlayer!),
                  onDeletePlayer: widget.selectedPlayer == null || widget.onDeletePlayer == null
                      ? null
                      : () => _confirmDeletePlayer(widget.selectedPlayer!),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==================== Левая панель состава ====================

class _RosterListPanel extends StatelessWidget {
  final String teamName;
  final int playersCount;
  final int visibleCount;
  final TextEditingController searchController;
  final ScrollController? scrollController;
  final _RosterFilter filter;
  final ValueChanged<_RosterFilter> onFilterChanged;
  final VoidCallback onAddPlayer;
  final Future<void> Function()? onRefresh;
  final ValueChanged<Map<String, dynamic>> onDeletePlayer;
  final List<Map<String, dynamic>> players;
  final String selectedKey;
  final String Function(Map<String, dynamic>?) playerIdentity;
  final ValueChanged<Map<String, dynamic>> onOpenPlayer;
  final bool compact;
  final bool mobile;

  const _RosterListPanel({
    required this.teamName,
    required this.playersCount,
    required this.visibleCount,
    required this.searchController,
    required this.scrollController,
    required this.filter,
    required this.onFilterChanged,
    required this.onAddPlayer,
    required this.onRefresh,
    required this.onDeletePlayer,
    required this.players,
    required this.selectedKey,
    required this.playerIdentity,
    required this.onOpenPlayer,
    required this.compact,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final padding = mobile ? 10.0 : 12.0;

    return Container(
      decoration: _CmrRosterDecor.panel(radius: mobile ? 14 : 16, elevated: true),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RosterToolbar(
            teamName: teamName,
            onAddPlayer: onAddPlayer,
            onRefresh: onRefresh,
            mobile: mobile,
          ),
          SizedBox(height: mobile ? 10 : 12),
          _RosterSearch(controller: searchController, mobile: mobile),
          const SizedBox(height: 8),
          _RosterFilterBar(value: filter, onChanged: onFilterChanged, mobile: mobile),
          SizedBox(height: mobile ? 9 : 10),
          Expanded(
            child: players.isEmpty
                ? _RosterEmptyState(onAddPlayer: onAddPlayer)
                : RefreshIndicator(
                    color: _CmrRosterColors.green,
                    onRefresh: onRefresh ?? () async {},
                    child: ListView.separated(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: mobile ? 20 : 8),
                      itemCount: players.length,
                      separatorBuilder: (_, __) => SizedBox(height: mobile ? 6 : 7),
                      itemBuilder: (_, index) {
                        final player = players[index];
                        final active = selectedKey.isNotEmpty && selectedKey == playerIdentity(player);
                        return _PlayerTile(
                          player: player,
                          active: active,
                          index: index,
                          onTap: () => onOpenPlayer(player),
                          onDelete: () => onDeletePlayer(player),
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

class _RosterToolbar extends StatelessWidget {
  final String teamName;
  final VoidCallback onAddPlayer;
  final Future<void> Function()? onRefresh;
  final bool mobile;

  const _RosterToolbar({
    required this.teamName,
    required this.onAddPlayer,
    required this.onRefresh,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: mobile ? 34 : 36,
          height: mobile ? 34 : 36,
          decoration: BoxDecoration(
            color: _CmrRosterColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _CmrRosterColors.green.withOpacity(.42), width: 1),
          ),
          child: const Icon(Icons.groups_2_rounded, color: _CmrRosterColors.green, size: 18),
        ),
        SizedBox(width: mobile ? 9 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Игроки',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrRosterText.title(mobile ? 15.5 : 16.5),
              ),
              const SizedBox(height: 3),
              Text(
                teamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrRosterText.muted(mobile ? 11.2 : 12),
              ),
            ],
          ),
        ),
        if (onRefresh != null && !mobile) ...[
          _CmrRosterIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Обновить',
            onTap: onRefresh!,
            compact: true,
          ),
          const SizedBox(width: 7),
        ],
        _CmrRosterIconButton(
          icon: Icons.person_add_alt_1_rounded,
          tooltip: 'Добавить игрока',
          onTap: onAddPlayer,
          emphasized: true,
          compact: true,
        ),
      ],
    );
  }
}

class _RosterSearch extends StatelessWidget {
  final TextEditingController controller;
  final bool mobile;

  const _RosterSearch({required this.controller, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mobile ? 40 : 42,
      decoration: _CmrRosterDecor.softCard(radius: mobile ? 10 : 11),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _CmrRosterColors.muted, size: 21),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Поиск по игроку, амплуа или номеру...',
                border: InputBorder.none,
                isDense: true,
              ),
              style: _CmrRosterText.value(mobile ? 12.5 : 13),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: controller.clear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: _CmrRosterColors.muted, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _RosterFilterBar extends StatelessWidget {
  final _RosterFilter value;
  final ValueChanged<_RosterFilter> onChanged;
  final bool mobile;

  const _RosterFilterBar({required this.value, required this.onChanged, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final items = <_RosterFilter, _FilterData>{
      _RosterFilter.all: const _FilterData('Все', Icons.groups_2_rounded),
      _RosterFilter.goalkeepers: const _FilterData('Вратари', Icons.sports_handball_rounded),
      _RosterFilter.defenders: const _FilterData('Защита', Icons.shield_rounded),
      _RosterFilter.midfielders: const _FilterData('Полузащита', Icons.hub_rounded),
      _RosterFilter.forwards: const _FilterData('Атака', Icons.sports_soccer_rounded),
      _RosterFilter.withoutPosition: const _FilterData('Без амплуа', Icons.help_outline_rounded),
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
          return _FilterPill(
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

class _FilterData {
  final String label;
  final IconData icon;
  const _FilterData(this.label, this.icon);
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool dense;

  const _FilterPill({
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
            color: active ? _CmrRosterColors.graphite : _CmrRosterColors.soft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? _CmrRosterColors.green.withOpacity(.42) : _CmrRosterColors.line,
              width: active ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dense ? 18 : 20,
                height: dense ? 18 : 20,
                decoration: BoxDecoration(
                  color: active ? Colors.white.withOpacity(.08) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: active ? _CmrRosterColors.green.withOpacity(.5) : _CmrRosterColors.line,
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: active ? _CmrRosterColors.green : _CmrRosterColors.muted, size: dense ? 14 : 15),
              ),
              const SizedBox(width: 7),
              Text(label, style: _CmrRosterText.tab(active: active)),
              if (active) ...[
                const SizedBox(width: 7),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: _CmrRosterColors.green, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool active;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool mobile;

  const _PlayerTile({
    required this.player,
    required this.active,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final name = _playerName(player);
    final position = _playerPosition(player).isEmpty ? 'Амплуа не указано' : _playerPosition(player);
    final photo = _absoluteUrl(_first(player, const ['photo', 'avatar', 'image', 'photo_url', 'avatar_url']));
    final number = _jerseyNumber(player);
    final height = _first(player, const ['height']);
    final weight = _first(player, const ['weight']);
    final age = _ageLabel(player);
    final metric = [
      if (number.isNotEmpty) '№ $number',
      if (age.isNotEmpty) age,
      if (height.isNotEmpty) '$height см',
      if (weight.isNotEmpty) '$weight кг',
    ].join('  •  ');
    final meta = [position, if (metric.isNotEmpty) metric].where((e) => e.trim().isNotEmpty).join('  •  ');

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
            color: _CmrRosterColors.panel,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active ? _CmrRosterColors.green.withOpacity(.42) : _CmrRosterColors.line,
              width: active ? 1.2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
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
                  color: active ? _CmrRosterColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(width: active ? 8 : 6),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _CmrRosterAvatar(photo: photo, name: name, size: mobile ? 40 : 44),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: _PlayerStatusBadge(number: number, active: active),
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
                      style: _CmrRosterText.title(mobile ? 13.4 : 14.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.isEmpty ? 'Данные не заполнены' : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrRosterText.muted(mobile ? 10.8 : 11.2),
                    ),
                  ],
                ),
              ),
              if (!mobile) ...[
                const SizedBox(width: 8),
                _RosterPlayerActionsButton(onDelete: onDelete, compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerStatusBadge extends StatelessWidget {
  final String number;
  final bool active;

  const _PlayerStatusBadge({required this.number, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        color: active ? _CmrRosterColors.graphite : _CmrRosterColors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? _CmrRosterColors.green.withOpacity(.58) : _CmrRosterColors.line,
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: number.isNotEmpty && number.length <= 2
          ? Text(
              number,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: active ? Colors.white : _CmrRosterColors.muted,
                fontSize: number.length == 1 ? 10 : 9,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            )
          : Icon(
              Icons.sports_soccer_rounded,
              color: active ? Colors.white : _CmrRosterColors.muted,
              size: 12,
            ),
    );
  }
}

// ==================== Правая панель игрока ====================

class _PlayerDetailPanel extends StatelessWidget {
  final Map<String, dynamic>? player;
  final String teamName;
  final VoidCallback? onOpenFullProfile;
  final Future<void> Function()? onDeletePlayer;
  final VoidCallback? onClose;
  final ScrollController? scrollController;

  const _PlayerDetailPanel({
    required this.player,
    required this.teamName,
    this.onOpenFullProfile,
    this.onDeletePlayer,
    this.onClose,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final p = player;
    if (p == null) {
      return Container(
        decoration: _CmrRosterDecor.panel(radius: 14, elevated: true),
        padding: const EdgeInsets.all(18),
        child: const _NoPlayerSelected(),
      );
    }

    final name = _playerName(p);
    final position = _playerPosition(p).isEmpty ? 'Амплуа не указано' : _playerPosition(p);
    final photo = _absoluteUrl(_first(p, const ['photo', 'avatar', 'image', 'photo_url', 'avatar_url']));
    final number = _jerseyNumber(p);
    final birth = _first(p, const ['birth_date', 'birthDate', 'birthday', 'date_birth']);
    final age = _ageLabel(p);
    final height = _first(p, const ['height']);
    final weight = _first(p, const ['weight']);
    final citizenship = _first(p, const ['citizenship', 'country', 'nationality']);
    final email = _first(p, const ['email']);
    final phone = _first(p, const ['phone']);
    final sportData = _first(p, const ['sport_data', 'sportData']);
    final idText = _first(p, const ['id', 'player_id', 'playerId', 'user_id', 'userId']);

    final content = ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(14),
      children: [
        _PlayerDetailHeader(
          name: name,
          position: position,
          number: number,
          teamName: teamName,
          photo: photo,
          onClose: onClose,
        ),
        const SizedBox(height: 12),
        _PrimaryActionButton(
          icon: Icons.open_in_new_rounded,
          text: 'Открыть профиль',
          onTap: onOpenFullProfile,
        ),
        const SizedBox(height: 12),
        _PlayerSummaryCard(
          name: name,
          position: position,
          number: number,
          age: age,
          teamName: teamName,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final twoColumns = c.maxWidth >= 520;
            final cards = [
              _MiniMetric(icon: Icons.cake_rounded, label: 'Возраст', value: age.isEmpty ? '—' : age),
              _MiniMetric(icon: Icons.height_rounded, label: 'Рост', value: height.isEmpty ? '—' : '$height см'),
              _MiniMetric(icon: Icons.monitor_weight_rounded, label: 'Вес', value: weight.isEmpty ? '—' : '$weight кг'),
              if (number.isNotEmpty) _MiniMetric(icon: Icons.tag_rounded, label: 'Номер', value: '№ $number'),
            ];

            if (!twoColumns) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i != cards.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            }

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: (c.maxWidth - 10) / 2,
                    child: card,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _DetailSection(
          title: 'Данные игрока',
          children: [
            _DetailRow(icon: Icons.sports_soccer_rounded, label: 'Амплуа', value: position),
            _DetailRow(icon: Icons.groups_2_rounded, label: 'Команда', value: teamName),
            _DetailRow(icon: Icons.event_rounded, label: 'Дата рождения', value: birth.isEmpty ? 'Не указана' : birth),
            _DetailRow(icon: Icons.flag_rounded, label: 'Гражданство', value: citizenship.isEmpty ? 'Не указано' : citizenship),
            if (email.isNotEmpty) _DetailRow(icon: Icons.mail_outline_rounded, label: 'Email', value: email),
            if (phone.isNotEmpty) _DetailRow(icon: Icons.phone_rounded, label: 'Телефон', value: phone),
            if (idText.isNotEmpty) _DetailRow(icon: Icons.badge_outlined, label: 'ID игрока', value: idText),
          ],
        ),
        const SizedBox(height: 10),
        _CommentBox(
          title: 'Спортивные данные',
          text: sportData.isEmpty
              ? 'Дополнительные спортивные показатели пока не заполнены.'
              : sportData,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SecondaryActionButton(
                icon: Icons.analytics_outlined,
                text: 'Метрики',
                onTap: onOpenFullProfile,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SecondaryActionButton(
                icon: Icons.assignment_turned_in_outlined,
                text: 'Тренировки',
                onTap: onOpenFullProfile,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SecondaryActionButton(
                icon: Icons.edit_rounded,
                text: 'Редактировать',
                onTap: onOpenFullProfile,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DeletePlayerButton(onTap: onDeletePlayer),
      ],
    );

    return Container(
      decoration: _CmrRosterDecor.panel(radius: onClose == null ? 14 : 14, elevated: true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }
}

class _PlayerDetailHeader extends StatelessWidget {
  final String name;
  final String position;
  final String number;
  final String teamName;
  final String photo;
  final VoidCallback? onClose;

  const _PlayerDetailHeader({
    required this.name,
    required this.position,
    required this.number,
    required this.teamName,
    required this.photo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CmrRosterAvatar(photo: photo, name: name, size: 54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: _CmrRosterText.title(19), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CmrRosterPill(text: position, icon: Icons.sports_soccer_rounded, active: true),
                  if (number.isNotEmpty) _CmrRosterPill(text: '№ $number', icon: Icons.tag_rounded, active: true),
                  _CmrRosterPill(text: teamName, icon: Icons.groups_2_rounded),
                ],
              ),
            ],
          ),
        ),
        if (onClose != null) ...[
          const SizedBox(width: 10),
          _CloseButton(onTap: onClose!),
        ],
      ],
    );
  }
}

class _PlayerSummaryCard extends StatelessWidget {
  final String name;
  final String position;
  final String number;
  final String age;
  final String teamName;

  const _PlayerSummaryCard({
    required this.name,
    required this.position,
    required this.number,
    required this.age,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _CmrRosterDecor.greenCard(radius: 12),
      child: Row(
        children: [
          _CmrRosterRoundIcon(icon: Icons.person_rounded, color: _CmrRosterColors.green, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(position, style: _CmrRosterText.title(15.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Text(
                  '$teamName${age.isEmpty ? '' : ' · $age'}',
                  style: _CmrRosterText.muted(12.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (number.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _CmrRosterColors.soft,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _CmrRosterColors.line, width: 1),
              ),
              child: Text('№ $number', style: _CmrRosterText.value(15)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniMetric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _CmrRosterDecor.softCard(radius: 12),
      child: Row(
        children: [
          _SmallIcon(icon: icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _CmrRosterText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: _CmrRosterText.title(16), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _CmrRosterDecor.softCard(radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: _CmrRosterColors.green,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(title, style: _CmrRosterText.section())),
            ],
          ),
          const SizedBox(height: 9),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CmrRosterRoundIcon(icon: icon, color: _CmrRosterColors.green, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _CmrRosterText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(value, style: _CmrRosterText.value(12.8), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentBox extends StatelessWidget {
  final String title;
  final String text;

  const _CommentBox({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _CmrRosterDecor.softCard(radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CmrRosterRoundIcon(icon: Icons.notes_rounded, color: _CmrRosterColors.green, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: _CmrRosterText.section())),
            ],
          ),
          const SizedBox(height: 10),
          Text(text, style: _CmrRosterText.muted(12.5)),
        ],
      ),
    );
  }
}

class _NoPlayerSelected extends StatelessWidget {
  const _NoPlayerSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CmrRosterRoundIcon(icon: Icons.person_search_rounded, color: _CmrRosterColors.green, size: 70),
          const SizedBox(height: 16),
          Text('Выберите игрока', style: _CmrRosterText.title(22), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Нажмите на карточку игрока слева — справа откроются данные, быстрые действия и переход в профиль.',
            style: _CmrRosterText.muted(13.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ==================== Общие компоненты ====================

class _RosterPlayerActionsButton extends StatelessWidget {
  final VoidCallback onDelete;
  final bool compact;

  const _RosterPlayerActionsButton({required this.onDelete, required this.compact});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_RosterPlayerAction>(
      tooltip: 'Дополнительно',
      elevation: 0,
      color: _CmrRosterColors.panel,
      surfaceTintColor: _CmrRosterColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: _CmrRosterColors.line)),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: (action) {
        switch (action) {
          case _RosterPlayerAction.delete:
            WidgetsBinding.instance.addPostFrameCallback((_) => onDelete());
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_RosterPlayerAction>(
          value: _RosterPlayerAction.delete,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: _CmrRosterColors.redSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_outline_rounded, color: _CmrRosterColors.red, size: 18),
                const SizedBox(width: 9),
                Text('Удалить игрока', style: _CmrRosterText.danger()),
              ],
            ),
          ),
        ),
      ],
      child: Container(
        width: compact ? 26 : 38,
        height: compact ? 26 : 38,
        decoration: BoxDecoration(
          color: _CmrRosterColors.soft,
          borderRadius: BorderRadius.circular(compact ? 8 : 9),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.more_horiz_rounded,
          color: _CmrRosterColors.muted2,
          size: compact ? 17 : 20,
        ),
      ),
    );
  }
}

enum _RosterPlayerAction { delete }

class _CmrRosterOutlineButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _CmrRosterOutlineButton({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _CmrRosterColors.soft,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _CmrRosterColors.line, width: 1),
          ),
          child: Text(title, style: _CmrRosterText.title(14)),
        ),
      ),
    );
  }
}

class _CmrRosterDangerButton extends StatelessWidget {
  final String title;
  final bool enabled;
  final VoidCallback onTap;

  const _CmrRosterDangerButton({
    required this.title,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? _CmrRosterColors.red : _CmrRosterColors.soft,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: enabled ? Colors.white : _CmrRosterColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CmrRosterIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool emphasized;
  final bool compact;

  const _CmrRosterIconButton({
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
        color: emphasized ? _CmrRosterColors.graphite : _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            child: Icon(
              icon,
              color: emphasized ? _CmrRosterColors.green : _CmrRosterColors.text,
              size: compact ? 17 : 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _CmrRosterAvatar extends StatelessWidget {
  final String photo;
  final String name;
  final double size;

  const _CmrRosterAvatar({required this.photo, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CmrRosterColors.soft,
        shape: BoxShape.circle,
        border: Border.all(color: _CmrRosterColors.green.withOpacity(.32), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isEmpty
          ? Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: _CmrRosterColors.greenDark,
                  fontSize: size * .28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: _CmrRosterColors.greenDark,
                    fontSize: size * .28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

class _CmrRosterRoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _CmrRosterRoundIcon({required this.icon, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color == _CmrRosterColors.green ? _CmrRosterColors.panel : _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(math.min(size * .22, 10)),
        border: Border.all(
          color: color == _CmrRosterColors.green ? _CmrRosterColors.green.withOpacity(.34) : _CmrRosterColors.line,
          width: 1,
        ),
      ),
      child: Icon(icon, color: color, size: size * .52),
    );
  }
}

class _SmallIcon extends StatelessWidget {
  final IconData icon;
  final bool soft;

  const _SmallIcon({required this.icon, this.soft = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: soft ? Colors.white : _CmrRosterColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: soft ? _CmrRosterColors.line : _CmrRosterColors.green.withOpacity(.34), width: 1),
      ),
      child: Icon(icon, color: soft ? _CmrRosterColors.muted : _CmrRosterColors.green, size: 18),
    );
  }
}

class _CmrRosterPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool active;

  const _CmrRosterPill({required this.text, this.icon, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? _CmrRosterColors.panel : _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? _CmrRosterColors.green.withOpacity(.36) : _CmrRosterColors.line, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: active ? _CmrRosterColors.green : _CmrRosterColors.muted),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _CmrRosterText.pill(color: active ? _CmrRosterColors.green : _CmrRosterColors.text),
          ),
        ],
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
        color: active ? _CmrRosterColors.graphite : _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? _CmrRosterColors.green.withOpacity(.42) : _CmrRosterColors.line, width: 1),
      ),
      child: Icon(
        Icons.chevron_right_rounded,
        color: active ? _CmrRosterColors.green : _CmrRosterColors.muted2,
        size: 18,
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrRosterColors.soft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.close_rounded, color: _CmrRosterColors.muted, size: 22),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _PrimaryActionButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrRosterColors.graphite,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _CmrRosterColors.green, size: 19),
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

class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _SecondaryActionButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrRosterColors.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _CmrRosterColors.green, size: 18),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    text,
                    style: _CmrRosterText.action(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _DeletePlayerButton extends StatelessWidget {
  final Future<void> Function()? onTap;

  const _DeletePlayerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? _CmrRosterColors.soft : _CmrRosterColors.panel,
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
                Icon(Icons.delete_outline_rounded, color: onTap == null ? _CmrRosterColors.muted : _CmrRosterColors.red, size: 18),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Удалить игрока',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onTap == null ? _CmrRosterColors.muted : _CmrRosterColors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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

class _RosterEmptyState extends StatelessWidget {
  final VoidCallback onAddPlayer;
  const _RosterEmptyState({required this.onAddPlayer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: _CmrRosterDecor.softCard(radius: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CmrRosterRoundIcon(icon: Icons.group_off_rounded, color: _CmrRosterColors.muted, size: 62),
            const SizedBox(height: 14),
            Text('Игроки не найдены', textAlign: TextAlign.center, style: _CmrRosterText.title(17)),
            const SizedBox(height: 7),
            Text(
              'Измените фильтр или добавьте первого игрока в выбранную команду.',
              textAlign: TextAlign.center,
              style: _CmrRosterText.muted(13),
            ),
            const SizedBox(height: 16),
            _PrimaryActionButton(
              icon: Icons.person_add_alt_1_rounded,
              text: 'Добавить игрока',
              onTap: onAddPlayer,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Вспомогательные функции ====================

String _s(dynamic value) {
  final text = '${value ?? ''}'.trim();
  return text == 'null' ? '' : text;
}

String _first(Map<String, dynamic> map, List<String> keys, [String fallback = '']) {
  for (final key in keys) {
    final value = _s(map[key]);
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String _playerName(Map<String, dynamic> player) {
  final first = _first(player, const ['first_name', 'firstname']);
  final last = _first(player, const ['last_name', 'lastname']);
  final full = _first(player, const ['fullName', 'full_name', 'name', 'fio']);
  final combined = '$first $last'.trim();
  if (combined.isNotEmpty) return combined;
  return full.isEmpty ? 'Игрок' : full;
}

String _playerPosition(Map<String, dynamic> player) {
  return _first(player, const ['position', 'role', 'amplua', 'player_position']);
}


String _jerseyNumber(Map<String, dynamic> player) {
  return _first(player, const ['number', 'player_number', 'shirt_number']);
}

String _absoluteUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == 'null') return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final cleaned = value.startsWith('/') ? value.substring(1) : value;
  return 'https://sportotekaapp.ru/$cleaned';
}

String _ageLabel(Map<String, dynamic> player) {
  final direct = _first(player, const ['age']);
  if (direct.isNotEmpty && direct != '0') {
    final years = int.tryParse(direct);
    if (years != null) return '$years ${_yearWord(years)}';
    return direct;
  }

  final birthRaw = _first(player, const ['birth_date', 'birthDate', 'birthday', 'date_birth']);
  final birth = _parseDate(birthRaw);
  if (birth == null) return '';

  final now = DateTime.now();
  var years = now.year - birth.year;
  final hadBirthday = now.month > birth.month || (now.month == birth.month && now.day >= birth.day);
  if (!hadBirthday) years--;
  if (years <= 0 || years > 80) return '';
  return '$years ${_yearWord(years)}';
}

DateTime? _parseDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  try {
    return DateTime.tryParse(value);
  } catch (_) {}

  final m = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
  if (m != null) {
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (d != null && mo != null && y != null) {
      return DateTime(y, mo, d);
    }
  }
  return null;
}

String _yearWord(int value) {
  final v = value.abs();
  final lastTwo = v % 100;
  final last = v % 10;
  if (lastTwo >= 11 && lastTwo <= 14) return 'лет';
  if (last == 1) return 'год';
  if (last >= 2 && last <= 4) return 'года';
  return 'лет';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'И';
  if (parts.length == 1) {
    final text = parts.first;
    return text.isEmpty ? 'И' : text.substring(0, 1).toUpperCase();
  }
  return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}
