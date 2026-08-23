// lib/presentation/club_workspace/cmr_club_roster_panel.dart
// Typography uses the centralized Sportoteka AppTypography / Inter system.
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/core/theme/app_typography.dart';

import 'package:sportoteka/presentation/player_profile_screen/cmr_player_profile_screen.dart';

// ==================== Цветовая схема ====================

class _CmrRosterColors {
  static const Color bg = Colors.white;
  static const Color panel = Colors.white;
  static const Color glass = Colors.white;
  static const Color soft = Color(0xFFF7F8F7);
  static const Color soft2 = Color(0xFFF2F4F2);
  static const Color active = Colors.white;

  static const Color text = Color(0xFF0B0F14);
  static const Color text2 = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF374151);
  static const Color muted2 = Color(0xFF5F6670);
  static const Color subtle = Color(0xFF8A9099);
  static const Color line = Color(0xFFE9ECEA);
  static const Color divider = Color(0xFFE9ECEA);
  static const Color graphite = Color(0xFF111827);
  static const Color graphiteSoft = Color(0xFF4B5563);
  static const Color graphite2 = Color(0xFF1F2937);
  static const Color graphiteButton = Color(0xFF111827);
  static const Color graphiteButtonHover = Color(0xFF374151);

  // Фирменный цвет — только как тонкий премиальный акцент.
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color greenSoft2 = Color(0xFFF8FEFA);
  static const Color greenBorder = Color(0xFFD7F0E2);

  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F1);
  static const Color redBorder = Color(0xFFFEE4E2);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFF7E8);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF7ED);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
}

// ==================== Текстовые стили ====================


class _CmrRosterText {
  static TextStyle title(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _CmrRosterColors.text,
        height: 1.18,
        letterSpacing: 0,
        features: const <FontFeature>[
          FontFeature.tabularFigures(),
        ],
      );

  static TextStyle section() => AppTypography.custom(
        size: 12.2,
        weight: FontWeight.w600,
        color: _CmrRosterColors.text,
        height: 1.20,
        letterSpacing: 0,
      );

  static TextStyle value(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _CmrRosterColors.text,
        height: 1.18,
        letterSpacing: 0,
        features: const <FontFeature>[
          FontFeature.tabularFigures(),
        ],
      );

  static TextStyle muted(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: _CmrRosterColors.muted2,
        height: 1.32,
        letterSpacing: 0,
      );

  static TextStyle caption() => AppTypography.custom(
        size: 10.8,
        weight: FontWeight.w500,
        color: _CmrRosterColors.subtle,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle pill() => AppTypography.custom(
        size: 11.2,
        weight: FontWeight.w600,
        color: _CmrRosterColors.text,
        letterSpacing: 0,
      );

  static TextStyle tab() => AppTypography.custom(
        size: 11.8,
        weight: FontWeight.w600,
        color: _CmrRosterColors.text,
        letterSpacing: 0,
      );

  static TextStyle tabSelected() => AppTypography.custom(
        size: 11.8,
        weight: FontWeight.w700,
        color: _CmrRosterColors.text,
        letterSpacing: 0,
      );

  static TextStyle action() => AppTypography.custom(
        size: 11.8,
        weight: FontWeight.w600,
        color: _CmrRosterColors.text,
        letterSpacing: 0,
      );

  static TextStyle danger() => AppTypography.custom(
        size: 11.8,
        weight: FontWeight.w500,
        color: _CmrRosterColors.red,
        letterSpacing: 0,
      );
}


class _CmrRosterDecor {
  // Геометрия приведена к Tracker Workspace: мобильный — карточки 18,
  // планшет/ПК — единые окна 16, внутренние блоки 12.
  static const double mobilePagePadding = 2.0;
  static const double mobileCardRadius = 18.0;
  static const double mobileInnerRadius = 12.0;
  static const double mobileButtonRadius = 14.0;
  static const double tabletCardRadius = 16.0;
  static const double tabletInnerRadius = 12.0;
  static const double sheetRadius = 18.0;
  // Хвост прокрутки под плавающий мобильный Dock Workspace.
  static const double mobileDockScrollInset = 132.0;

  static List<BoxShadow> get windowShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 28,
          spreadRadius: -18,
          offset: const Offset(0, 16),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.015),
          blurRadius: 16,
          spreadRadius: -11,
          offset: const Offset(0, 9),
        ),
      ];

  static BoxDecoration workspaceBg() => const BoxDecoration(
        color: _CmrRosterColors.bg,
      );

  static BoxDecoration panel({double radius = tabletCardRadius, bool elevated = true}) => BoxDecoration(
        color: _CmrRosterColors.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _CmrRosterColors.line.withOpacity(.55), width: .7),
        boxShadow: elevated ? cardShadow : null,
      );

  static BoxDecoration unifiedWindow({double radius = tabletCardRadius}) => BoxDecoration(
        color: _CmrRosterColors.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.transparent, width: 0),
        boxShadow: windowShadow,
      );

  static BoxDecoration seamlessPane({double radius = 0}) => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration softCard({double radius = mobileInnerRadius, bool active = false}) => BoxDecoration(
        color: active ? _CmrRosterColors.greenSoft : _CmrRosterColors.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: active ? _CmrRosterColors.greenBorder : _CmrRosterColors.line.withOpacity(.55), width: .7),
      );

  static BoxDecoration fluentSurface({double radius = mobileInnerRadius, bool active = false}) => BoxDecoration(
        color: active ? _CmrRosterColors.greenSoft : _CmrRosterColors.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: active ? _CmrRosterColors.greenBorder : _CmrRosterColors.line.withOpacity(.78), width: .85),
      );

  static BoxDecoration greenCard({double radius = mobileInnerRadius}) => BoxDecoration(
        color: _CmrRosterColors.greenSoft,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _CmrRosterColors.greenBorder, width: .85),
        boxShadow: cardShadow,
      );
}

class CmrClubRosterPanel extends StatefulWidget {
  final String teamName;
  final int? selectedTeamId;
  final int clubId;
  final List<Map<String, dynamic>> players;
  final bool loading;
  final Map<String, dynamic>? selectedPlayer;
  final Future<void> Function()? onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpenPlayer;
  final ValueChanged<Map<String, dynamic>>? onOpenFullPlayer;
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
    this.onOpenFullPlayer,
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

  bool _showFullProfileInRightPane = false;
  Map<String, dynamic>? _rightPanePlayer;

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
  void didUpdateWidget(covariant CmrClubRosterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final selected = widget.selectedPlayer;
    if (selected == null) {
      _rightPanePlayer = null;
      _showFullProfileInRightPane = false;
      return;
    }

    final oldKey = _playerIdentity(oldWidget.selectedPlayer);
    final newKey = _playerIdentity(selected);
    if (oldKey != newKey) {
      _rightPanePlayer = Map<String, dynamic>.from(selected);
    }
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

  bool _shouldOpenFullProfileInWorkspace() {
    // Дизайн состава не трогаем. Меняем только способ открытия профиля.
    // Внутреннее CMR-окно оставляем только для настоящего широкого ПК.
    // Многие планшеты/iPad в браузере могут определяться как macOS/desktop,
    // поэтому одной проверки defaultTargetPlatform недостаточно.
    if (widget.onOpenFullPlayer == null) return false;

    final size = MediaQuery.maybeOf(context)?.size;
    final width = size?.width ?? 0;
    if (width < 1400) return false;

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  Future<void> _openFullProfile(
    Map<String, dynamic> player, {
    Duration delay = Duration.zero,
  }) async {
    final mp = Map<String, dynamic>.from(player);
    mp['team_id'] ??= mp['teamId'] ?? widget.selectedTeamId;
    mp['teamId'] ??= mp['team_id'] ?? widget.selectedTeamId;
    mp['club_id'] ??= mp['clubId'] ?? widget.clubId;
    mp['clubId'] ??= mp['club_id'] ?? widget.clubId;
    mp['team_name'] ??= widget.teamName;
    mp['teamName'] ??= widget.teamName;

    final width = MediaQuery.sizeOf(context).width;

    // На планшете и ПК полный профиль раскрывается внутри правой рабочей
    // области состава. Список игроков слева остаётся доступен.
    if (width >= 640) {
      widget.onOpenPlayer(mp);
      if (!mounted) return;
      setState(() {
        _rightPanePlayer = mp;
        _showFullProfileInRightPane = true;
      });
      return;
    }

    // На телефоне правой области недостаточно — используем отдельный экран.
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (!mounted) return;

    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'cmr_player_profile'),
        builder: (_) => CmrPlayerProfileScreen(player: mp),
      ),
    );
  }

  void _handleOpenPlayer(Map<String, dynamic> player, bool mobile) {
    widget.onOpenPlayer(player);

    if (!mobile) {
      setState(() {
        _rightPanePlayer = Map<String, dynamic>.from(player);
      });
      return;
    }

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
                _openFullProfile(
                  player,
                  delay: const Duration(milliseconds: 180),
                );
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

    final deletePlayer = widget.onDeletePlayer;
    final name = _playerName(player);
    const codeWord = 'УДАЛИТЬ';

    if (deletePlayer == null) {
      Get.snackbar(
        'Удаление не подключено',
        'В родительском экране не передан onDeletePlayer.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _CmrRosterColors.red,
        colorText: Colors.white,
      );
      return;
    }

    final codeController = TextEditingController();

    try {
      final deleted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          var deleting = false;
          String? errorText;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              final canDelete =
                  codeController.text.trim().toUpperCase() == codeWord;

              Future<void> submitDelete() async {
                if (deleting || !canDelete) return;

                setDialogState(() {
                  deleting = true;
                  errorText = null;
                });

                try {
                  await deletePlayer(player);

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    deleting = false;
                    errorText = e.toString();
                  });
                }
              }

              return PopScope(
                canPop: !deleting,
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 24,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    padding: const EdgeInsets.all(20),
                    decoration: _CmrRosterDecor.panel(
                      radius: _CmrRosterDecor.mobileCardRadius,
                    ),
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
                                borderRadius: BorderRadius.circular(
                                  _CmrRosterDecor.mobileInnerRadius,
                                ),
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
                                  Text(
                                    'Удалить игрока?',
                                    style: _CmrRosterText.title(20),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _CmrRosterText.muted(12.5),
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
                            borderRadius: BorderRadius.circular(
                              _CmrRosterDecor.mobileInnerRadius,
                            ),
                          ),
                          child: Text(
                            'Игрок будет удалён из состава. Для подтверждения введите слово $codeWord.',
                            style: _CmrRosterText.muted(12.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: codeController,
                          enabled: !deleting,
                          autofocus: true,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setDialogState(() {
                            errorText = null;
                          }),
                          onSubmitted: (_) => submitDelete(),
                          decoration: InputDecoration(
                            hintText: codeWord,
                            filled: true,
                            fillColor: _CmrRosterColors.soft,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          style: _CmrRosterText.title(14),
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Ошибка удаления: $errorText',
                            style: _CmrRosterText.muted(11.5).copyWith(
                              color: _CmrRosterColors.red,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _CmrRosterOutlineButton(
                                title: 'Отмена',
                                onTap: deleting
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _CmrRosterDangerButton(
                                title: deleting ? 'Удаление...' : 'Удалить',
                                enabled: canDelete && !deleting,
                                onTap: submitDelete,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (!mounted || deleted != true) return;

      setState(() {
        final deletedKey = _playerIdentity(player);
        if (_playerIdentity(_rightPanePlayer) == deletedKey) {
          _rightPanePlayer = null;
          _showFullProfileInRightPane = false;
        }
      });

      await widget.onRefresh?.call();
      if (!mounted) return;

      Get.snackbar(
        'Игрок удалён',
        name,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _CmrRosterColors.green,
        colorText: Colors.white,
      );
    } finally {
      codeController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator(color: _CmrRosterColors.green));
    }

    final visiblePlayers = _visiblePlayers;

    return Container(
      decoration: _CmrRosterDecor.workspaceBg(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 640;
          final compact = constraints.maxWidth < 980;
          final listWidth = _showFullProfileInRightPane
              ? math.min(compact ? 300.0 : 340.0, constraints.maxWidth * .30)
              : math.min(
                  compact ? 430.0 : 480.0,
                  constraints.maxWidth * (compact ? .43 : .45),
                );

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
            return Container(
              width: double.infinity,
              color: const Color(0xFFF6F7F6),
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: list,
                  ),
                ),
              ),
            );
          }

          return Container(
            width: double.infinity,
            color: const Color(0xFFF6F7F6),
            padding: EdgeInsets.all(compact ? 8 : 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 18 : 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(compact ? 18 : 20),
                  boxShadow: _CmrRosterDecor.windowShadow,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: listWidth, child: list),
                    Container(width: 1, color: _CmrRosterColors.line),
                    Expanded(
                      child: _showFullProfileInRightPane &&
                              (_rightPanePlayer ?? widget.selectedPlayer) != null
                          ? CmrPlayerProfileScreen(
                              key: ValueKey(
                                'right-profile-${_playerIdentity(_rightPanePlayer ?? widget.selectedPlayer)}',
                              ),
                              player: Map<String, dynamic>.from(
                                _rightPanePlayer ?? widget.selectedPlayer!,
                              ),
                              embeddedInWorkspace: true,
                              onClose: () {
                                if (!mounted) return;
                                setState(() => _showFullProfileInRightPane = false);
                              },
                            )
                          : _PlayerDetailPanel(
                              player: widget.selectedPlayer,
                              teamName: widget.teamName,
                              onOpenFullProfile: widget.selectedPlayer == null
                                  ? null
                                  : () => _openFullProfile(widget.selectedPlayer!),
                              onDeletePlayer: widget.selectedPlayer == null ||
                                      widget.onDeletePlayer == null
                                  ? null
                                  : () => _confirmDeletePlayer(widget.selectedPlayer!),
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12, vertical: mobile ? 10 : 10),
            decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: _CmrRosterColors.line, width: .55)),
      ),
            child: _RosterToolbar(
              teamName: teamName,
              onAddPlayer: onAddPlayer,
              onRefresh: onRefresh,
              mobile: mobile,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12, vertical: 8),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: _RosterSearch(controller: searchController, mobile: mobile),
          ),
          Container(
            height: mobile ? 44 : 46,
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 10 : 12,
              vertical: 5,
            ),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: _RosterFilterBar(value: filter, onChanged: onFilterChanged, mobile: mobile),
          ),
          Expanded(
            child: players.isEmpty
                ? _RosterEmptyState(onAddPlayer: onAddPlayer)
                : RefreshIndicator(
                    color: _CmrRosterColors.green,
                    onRefresh: onRefresh ?? () async {},
                    child: ListView.builder(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: 0,
                        bottom: mobile
                            ? _CmrRosterDecor.mobileDockScrollInset
                            : 12,
                      ),
                      itemCount: players.length,
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
                style: _CmrRosterText.muted(mobile ? 11 : 11.5),
              ),
            ],
          ),
        ),
        if (onRefresh != null && !mobile) ...[
          _CmrRosterIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Обновить',
            onTap: () => onRefresh?.call(),
            compact: true,
          ),
          const SizedBox(width: 6),
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
      height: mobile ? 42 : 42,
      decoration: BoxDecoration(
        color: _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CmrRosterColors.line.withOpacity(.7), width: .7),
      ),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _CmrRosterColors.muted2, size: 16),
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
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(
            minHeight: dense ? 34 : 36,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 9 : 11,
            vertical: dense ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: active
                ? _CmrRosterColors.greenSoft
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active
                  ? _CmrRosterColors.greenBorder
                  : Colors.transparent,
              width: .8,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _CmrRosterColors.green.withOpacity(.055),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: dense ? 13.5 : 14,
                color: active
                    ? _CmrRosterColors.greenDark
                    : _CmrRosterColors.subtle,
              ),
              SizedBox(width: dense ? 5 : 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrRosterText.action().copyWith(
                  color: active
                      ? _CmrRosterColors.greenDark
                      : _CmrRosterColors.muted2,
                  fontSize: dense ? 11.0 : 11.4,
                  fontWeight: active
                      ? FontWeight.w700
                      : FontWeight.w500,
                  height: 1,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 6),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _CmrRosterColors.green,
                    shape: BoxShape.circle,
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
    final position = _playerPosition(player);
    final number = _jerseyNumber(player);
    final photo = _absoluteUrl(
      _first(
        player,
        const ['photo', 'avatar', 'image', 'photo_url', 'avatar_url'],
      ),
    );
    final age = _ageLabel(player);
    final polar = _playerHasPolar(player);
    final gps = _playerHasGps(player);
    final activity = _playerActivityLabel(player);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: BoxConstraints(minHeight: mobile ? 80 : 76),
          padding: EdgeInsets.fromLTRB(
            mobile ? 10 : 12,
            9,
            mobile ? 10 : 12,
            9,
          ),
          decoration: BoxDecoration(
            color: active
                ? _CmrRosterColors.greenSoft2
                : Colors.white,
            border: const Border(
              bottom: BorderSide(
                color: _CmrRosterColors.line,
                width: .65,
              ),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 3,
                height: mobile ? 50 : 48,
                decoration: BoxDecoration(
                  color: active
                      ? _CmrRosterColors.green
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 9),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _CmrRosterAvatar(
                    photo: photo,
                    name: name,
                    size: mobile ? 52 : 50,
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: _PlayerStatusBadge(
                      number: number,
                      active: active,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrRosterText.title(
                              mobile ? 14.2 : 14.0,
                            ),
                          ),
                        ),
                        if (activity.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _ActivityDot(label: activity),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        position.isEmpty ? 'Без амплуа' : position,
                        if (age.isNotEmpty) age,
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrRosterText.muted(11.4),
                    ),
                    if (polar || gps) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (polar)
                            const _InlineStatusDot(
                              label: 'POLAR',
                              color: _CmrRosterColors.red,
                            ),
                          if (polar && gps)
                            const SizedBox(width: 12),
                          if (gps)
                            const _InlineStatusDot(
                              label: 'GPS',
                              color: _CmrRosterColors.blue,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (mobile)
                _RosterPlayerActionsButton(
                  onDelete: onDelete,
                  compact: true,
                )
              else
                _ChevronBadge(active: active),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool active;
  final Color? accent;

  const _MiniPlayerChip({
    required this.text,
    required this.icon,
    this.active = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? (active ? _CmrRosterColors.green : _CmrRosterColors.muted2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(active || accent != null ? .075 : .045),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: active ? _CmrRosterColors.greenDark : _CmrRosterColors.graphiteSoft,
              fontSize: 11.4,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}


class _InlineStatusDot extends StatelessWidget {
  final String label;
  final Color color;
  const _InlineStatusDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: _CmrRosterColors.subtle, fontSize: 10.2, fontWeight: FontWeight.w700, letterSpacing: .2)),
      ],
    );
  }
}

class _ActivityDot extends StatelessWidget {
  final String label;
  const _ActivityDot({required this.label});

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final color = lower.contains('сегодня')
        ? _CmrRosterColors.green
        : lower.contains('вчера')
            ? _CmrRosterColors.amber
            : _CmrRosterColors.muted2;
    return Tooltip(
      message: label,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(.22), blurRadius: 5)],
        ),
      ),
    );
  }
}

class _RosterActiveDot extends StatelessWidget {
  const _RosterActiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: _CmrRosterColors.green,
        shape: BoxShape.circle,
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
        color: active ? _CmrRosterColors.greenSoft : Colors.white,
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
        border: Border.all(color: active ? _CmrRosterColors.green.withOpacity(.18) : _CmrRosterColors.line),
      ),
      alignment: Alignment.center,
      child: number.isNotEmpty && number.length <= 2
          ? Text(
              number,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: active ? _CmrRosterColors.green : _CmrRosterColors.muted,
                fontSize: number.length == 1 ? 10.5 : 9.6,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            )
          : Icon(
              Icons.sports_soccer_rounded,
              color: active ? _CmrRosterColors.green : _CmrRosterColors.muted,
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
        decoration: onClose == null
            ? _CmrRosterDecor.seamlessPane()
            : _CmrRosterDecor.panel(radius: _CmrRosterDecor.sheetRadius),
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
      padding: EdgeInsets.fromLTRB(18, onClose == null ? 18 : 10, 18, 20),
      children: [
        if (onClose != null) ...[
          const _ModalGrabber(),
          const SizedBox(height: 8),
        ],
        _PlayerDetailHeader(
          name: name,
          position: position,
          number: number,
          teamName: teamName,
          photo: photo,
          onClose: onClose,
        ),
        const SizedBox(height: 12),
        _InspectorActionGroup(
          actions: [
            _InspectorAction(
              icon: Icons.person_outline_rounded,
              title: 'Открыть профиль',
              subtitle: 'Полная карточка игрока',
              onTap: onOpenFullProfile,
              accent: true,
            ),
            _InspectorAction(
              icon: Icons.edit_outlined,
              title: 'Редактировать',
              subtitle: 'Изменить данные и амплуа',
              onTap: onOpenFullProfile,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _PlayerMetricsStrip(
          age: age.isEmpty ? '—' : age,
          height: height.isEmpty ? '—' : '$height см',
          weight: weight.isEmpty ? '—' : '$weight кг',
          number: number.isEmpty ? '—' : '№ $number',
        ),
        const SizedBox(height: 18),
        _PlayerConnectionCard(
          polar: _playerHasPolar(p),
          gps: _playerHasGps(p),
          activity: _playerActivityLabel(p),
        ),
        const SizedBox(height: 18),
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
        const SizedBox(height: 18),
        _InspectorActionGroup(
          title: 'Быстрый переход',
          actions: [
            _InspectorAction(
              icon: Icons.analytics_outlined,
              title: 'Метрики',
              subtitle: 'Нагрузка и показатели',
              onTap: onOpenFullProfile,
            ),
            _InspectorAction(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Тренировки',
              subtitle: 'История занятий игрока',
              onTap: onOpenFullProfile,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeletePlayerButton(onTap: onDeletePlayer),
      ],
    );

    final radius = onClose == null ? 0.0 : _CmrRosterDecor.sheetRadius;
    return Container(
      clipBehavior: onClose == null ? Clip.none : Clip.antiAlias,
      decoration: onClose == null
          ? _CmrRosterDecor.seamlessPane()
          : _CmrRosterDecor.panel(radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}


class _ModalGrabber extends StatelessWidget {
  const _ModalGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: _CmrRosterColors.line,
          borderRadius: BorderRadius.circular(99),
        ),
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
        Stack(
          clipBehavior: Clip.none,
          children: [
            _CmrRosterAvatar(photo: photo, name: name, size: 96),
            Positioned(right: -4, bottom: -4, child: _PlayerStatusBadge(number: number, active: true)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: _CmrRosterText.title(22), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _CmrRosterPill(text: position, active: true),
                  if (number.isNotEmpty) _CmrRosterPill(text: '№ $number', active: true),
                  _CmrRosterPill(text: teamName),
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
      decoration: _CmrRosterDecor.greenCard(radius: _CmrRosterDecor.mobileInnerRadius),
      child: Row(
        children: [
          _CmrRosterRoundIcon(icon: Icons.person_rounded, color: _CmrRosterColors.green, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(position, style: _CmrRosterText.title(17), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
              ),
              child: Text('№ $number', style: _CmrRosterText.value(15)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerMetricsStrip extends StatelessWidget {
  final String age;
  final String height;
  final String weight;
  final String number;

  const _PlayerMetricsStrip({
    required this.age,
    required this.height,
    required this.weight,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final items = <({String value, String label})>[
      (value: age, label: 'Возраст'),
      (value: height, label: 'Рост'),
      (value: weight, label: 'Вес'),
      (value: number, label: 'Номер'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return Wrap(
            spacing: 0,
            runSpacing: compact ? 14 : 0,
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: compact
                      ? constraints.maxWidth / 2
                      : constraints.maxWidth / 4,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 10,
                      right: i == items.length - 1 ? 0 : 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].value,
                          style: _CmrRosterText.title(15.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(items[i].label, style: _CmrRosterText.caption()),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlayerConnectionCard extends StatelessWidget {
  final bool polar;
  final bool gps;
  final String activity;

  const _PlayerConnectionCard({
    required this.polar,
    required this.gps,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Состояние', style: _CmrRosterText.section())),
              if (activity.isNotEmpty) _StatusLabel(text: activity),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _ConnectionItem(
                  icon: Icons.favorite_rounded,
                  title: 'Polar',
                  enabled: polar,
                  activeColor: _CmrRosterColors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConnectionItem(
                  icon: Icons.satellite_alt_rounded,
                  title: 'GPS',
                  enabled: gps,
                  activeColor: _CmrRosterColors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool enabled;
  final Color activeColor;

  const _ConnectionItem({required this.icon, required this.title, required this.enabled, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? activeColor : _CmrRosterColors.muted2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: enabled ? color.withOpacity(.065) : _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: enabled ? color : _CmrRosterColors.line, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Expanded(child: Text(title, style: _CmrRosterText.value(11.5))),
          Container(width: 7, height: 7, decoration: BoxDecoration(color: enabled ? color : _CmrRosterColors.line, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final String text;
  const _StatusLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    final color = lower.contains('сегодня')
        ? _CmrRosterColors.green
        : lower.contains('вчера')
            ? _CmrRosterColors.amber
            : _CmrRosterColors.muted2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w500)),
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
      decoration: _CmrRosterDecor.softCard(radius: _CmrRosterDecor.mobileInnerRadius),
      child: Row(
        children: [
          _CmrRosterRoundIcon(icon: icon, color: _CmrRosterColors.green, size: 38),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _CmrRosterText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: _CmrRosterText.title(15.5), maxLines: 1, overflow: TextOverflow.ellipsis),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Text(title, style: _CmrRosterText.section()),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _CmrRosterColors.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
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
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 98, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrRosterText.caption())),
        const SizedBox(width: 10),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: _CmrRosterText.value(11.6), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Row(children: [
            const Icon(Icons.notes_rounded, color: _CmrRosterColors.muted2, size: 15),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: _CmrRosterText.section())),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(text, style: _CmrRosterText.muted(11.4)),
        ),
      ]),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius)),
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
              borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_outline_rounded, color: _CmrRosterColors.red, size: 18),
                const SizedBox(width: 8),
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
          borderRadius: BorderRadius.circular(compact ? 10 : _CmrRosterDecor.mobileInnerRadius),
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
      borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _CmrRosterColors.soft,
            borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
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
      borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? _CmrRosterColors.red : _CmrRosterColors.soft,
            borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: enabled ? Colors.white : _CmrRosterColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
  final VoidCallback? onTap;
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
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
        child: Ink(
          decoration: _CmrRosterDecor.fluentSurface(
            radius: 10,
            active: emphasized,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
            onTap: onTap,
            child: Opacity(
              opacity: onTap == null ? .45 : 1,
              child: SizedBox(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                child: Icon(
                  icon,
                  color: emphasized
                      ? _CmrRosterColors.green
                      : _CmrRosterColors.text,
                  size: compact ? 15 : 16,
                ),
              ),
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
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isEmpty
          ? Center(child: Text(initials, style: _CmrRosterText.title(size * .32)))
          : Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(initials, style: _CmrRosterText.title(size * .32)),
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
        color: _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
      ),
      child: Icon(
        icon,
        color: color,
        size: size * .52,
      ),
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
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
      ),
      child: Icon(icon, color: _CmrRosterColors.muted, size: 18),
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
    final accent = active ? _CmrRosterColors.green : _CmrRosterColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: _CmrRosterColors.soft,
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: accent.withOpacity(.08),
                borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
              ),
              child: Icon(icon, size: 12, color: accent),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _CmrRosterText.muted(11),
            ),
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
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? _CmrRosterColors.greenSoft : Colors.white.withOpacity(.76),
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
        border: Border.all(color: active ? _CmrRosterColors.greenBorder : _CmrRosterColors.line, width: .7),
      ),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: active ? _CmrRosterColors.green : _CmrRosterColors.muted2,
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
      borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.close_rounded, color: _CmrRosterColors.muted, size: 22),
        ),
      ),
    );
  }
}


class _InspectorAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool accent;

  const _InspectorAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });
}

class _InspectorActionGroup extends StatelessWidget {
  final String? title;
  final List<_InspectorAction> actions;

  const _InspectorActionGroup({this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: Text(title!, style: _CmrRosterText.section()),
          ),
        ],
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _CmrRosterColors.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                _InspectorActionRow(action: actions[i]),
                if (i != actions.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 50),
                    child: Divider(height: 1, thickness: .55, color: _CmrRosterColors.line),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InspectorActionRow extends StatelessWidget {
  final _InspectorAction action;
  const _InspectorActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final enabled = action.onTap != null;
    final iconColor = action.accent
        ? _CmrRosterColors.greenDark
        : _CmrRosterColors.graphiteSoft;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: action.accent
                        ? _CmrRosterColors.green.withOpacity(.08)
                        : Colors.white.withOpacity(.72),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(action.icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(action.title, style: _CmrRosterText.action()),
                      const SizedBox(height: 2),
                      Text(action.subtitle, style: _CmrRosterText.muted(10.8)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: action.accent
                      ? _CmrRosterColors.green
                      : _CmrRosterColors.subtle,
                ),
              ],
            ),
          ),
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
      color: _CmrRosterColors.green,
      borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            height: 38,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileButtonRadius), border: Border.all(color: _CmrRosterColors.green, width: .8)),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.4, fontWeight: FontWeight.w500))),
            ]),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileInnerRadius),
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            height: 38,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(_CmrRosterDecor.mobileButtonRadius), border: Border.all(color: _CmrRosterColors.line, width: .8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(text, style: _CmrRosterText.action(), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .45 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: onTap == null ? _CmrRosterColors.muted : _CmrRosterColors.red,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Удалить игрока',
                    style: _CmrRosterText.danger().copyWith(fontSize: 11.4),
                  ),
                ],
              ),
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: const BoxDecoration(
          color: _CmrRosterColors.panel,
          border: Border(bottom: BorderSide(color: _CmrRosterColors.line, width: .7)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _CmrRosterRoundIcon(icon: Icons.group_off_rounded, color: _CmrRosterColors.muted, size: 42),
          const SizedBox(height: 10),
          Text('Игроки не найдены', textAlign: TextAlign.center, style: _CmrRosterText.title(14.2)),
          const SizedBox(height: 5),
          Text('Измените фильтр или добавьте первого игрока в выбранную команду.', textAlign: TextAlign.center, style: _CmrRosterText.muted(11.2)),
          const SizedBox(height: 12),
          _PrimaryActionButton(icon: Icons.add_rounded, text: 'Добавить игрока', onTap: onAddPlayer),
        ]),
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
  if (value.startsWith('//')) return 'https:$value';
  if (value.startsWith('sportotekaapp.ru/')) return 'https://$value';
  if (value.startsWith('www.sportotekaapp.ru/')) return 'https://$value';
  final cleaned = value.startsWith('/') ? value.substring(1) : value;
  return 'https://sportotekaapp.ru/$cleaned';
}

bool _boolish(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = _s(value).toLowerCase();
  return const {'1', 'true', 'yes', 'on', 'connected', 'active', 'assigned'}.contains(text);
}

bool _playerHasPolar(Map<String, dynamic> player) {
  const keys = [
    'polar_connected', 'polarConnected', 'has_polar', 'hasPolar',
    'polar_assigned', 'polarAssigned', 'heart_rate_connected',
    'hr_connected', 'hrConnected', 'polar_id', 'polarId',
  ];
  for (final key in keys) {
    final value = player[key];
    if (_boolish(value)) return true;
    final text = _s(value);
    if ((key.endsWith('_id') || key.endsWith('Id')) && text.isNotEmpty && text != '0') return true;
  }
  return false;
}

bool _playerHasGps(Map<String, dynamic> player) {
  const keys = [
    'gps_connected', 'gpsConnected', 'has_gps', 'hasGps',
    'tracker_connected', 'trackerConnected', 'tracker_assigned',
    'trackerAssigned', 'device_connected', 'gps_id', 'gpsId',
    'tracker_id', 'trackerId',
  ];
  for (final key in keys) {
    final value = player[key];
    if (_boolish(value)) return true;
    final text = _s(value);
    if ((key.endsWith('_id') || key.endsWith('Id')) && text.isNotEmpty && text != '0') return true;
  }
  return false;
}

String _playerActivityLabel(Map<String, dynamic> player) {
  final direct = _first(player, const [
    'activity_label', 'activityLabel', 'last_training_label',
    'lastTrainingLabel', 'training_status', 'trainingStatus',
  ]);
  if (direct.isNotEmpty) return direct;

  final raw = _first(player, const [
    'last_training_at', 'lastTrainingAt', 'last_session_at',
    'lastSessionAt', 'last_activity_at', 'lastActivityAt',
  ]);
  final date = _parseDate(raw);
  if (date == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  if (diff < 7) return '$diff дн. назад';
  return 'Нет свежих данных';
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

