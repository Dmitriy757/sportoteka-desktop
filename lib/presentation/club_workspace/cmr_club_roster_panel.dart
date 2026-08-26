// lib/presentation/club_workspace/cmr_club_roster_panel.dart
// Typography uses the centralized Sportoteka AppTypography / Inter system.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';

import 'package:sportoteka/presentation/player_profile_screen/cmr_player_profile_screen.dart';
import 'package:sportoteka/presentation/player_profile_screen/models/player_profile_models.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_player_parent_access_panel.dart';
import 'package:sportoteka/presentation/add_player_screen/add_player_screen.dart';

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

  static TextStyle section() =>
      AppTypography.subsectionTitle(color: _CmrRosterColors.text);

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

  static TextStyle caption() =>
      AppTypography.captionMedium(color: _CmrRosterColors.subtle);

  static TextStyle pill() =>
      AppTypography.chip(color: _CmrRosterColors.text, active: true);

  static TextStyle tab() =>
      AppTypography.tab(color: _CmrRosterColors.text);

  static TextStyle tabSelected() =>
      AppTypography.tab(color: _CmrRosterColors.text, active: true);

  static TextStyle action() =>
      AppTypography.action(color: _CmrRosterColors.text);

  static TextStyle danger() => AppTypography.custom(
        size: 11.8,
        weight: FontWeight.w500,
        color: _CmrRosterColors.red,
        letterSpacing: 0,
      );

  // Точная типографика внутреннего меню Tracker -> Аналитика.
  static TextStyle navLabel({required bool active}) => AppTypography.menuTitle(
        color: active ? _CmrRosterColors.greenDark : _CmrRosterColors.text,
        weight: active ? FontWeight.w600 : FontWeight.w500,
      );

  static TextStyle navSubtitle({required bool active}) => AppTypography.menuSubtitle(
        color: active
            ? _CmrRosterColors.greenDark.withOpacity(.68)
            : _CmrRosterColors.muted2,
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

  /// Необязательный user_id текущего тренера/руководителя.
  /// Если не передан, Parent Access сам получает его из PrefUtils.
  final int? currentUserId;

  final List<Map<String, dynamic>> players;

  /// Максимальное количество игроков для текущего тарифа.
  /// null = без клиентского ограничения.
  final int? maxPlayers;

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
    this.currentUserId,
    required this.players,
    this.maxPlayers,
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

  bool _showProfileMenu = false;
  bool _showFullProfileInRightPane = false;
  bool _showAddPlayerInRightPane = false;
  Map<String, dynamic>? _rightPanePlayer;
  PlayerProfileSection _profileSection = PlayerProfileSection.card;

  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _getClubTeamsUrl = '$_apiBase/get_club_teams.php';
  static const String _movePlayerTeamUrl = '$_apiBase/move_player_team.php';
  static const String _getUnassignedPlayersUrl =
      '$_apiBase/get_unassigned_players.php';
  static const String _getArchivedPlayersUrl =
      '$_apiBase/get_archived_players.php';
  static const String _restoreArchivedPlayerUrl =
      '$_apiBase/restore_player.php';

  int _rosterInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  String _rosterText(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  dynamic _decodeRosterResponse(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  int _teamId(Map<String, dynamic> team) => _rosterInt(
        team['id'] ?? team['team_id'] ?? team['teamId'],
      );

  String _teamTitle(Map<String, dynamic> team) {
    final value = _rosterText(
      team['name'] ??
          team['team_name'] ??
          team['teamName'] ??
          team['title'],
    );
    return value.isEmpty ? 'Команда #${_teamId(team)}' : value;
  }

  int? _ageGroupFromName(String value) {
    final match = RegExp(
      r'\bU\s*([0-9]{1,2})\b',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  Future<List<Map<String, dynamic>>> _loadTransferTeams() async {
    final response = await http
        .post(
          Uri.parse(_getClubTeamsUrl),
          body: {'club_id': '${widget.clubId}'},
        )
        .timeout(const Duration(seconds: 12));

    final data = _decodeRosterResponse(response.body);

    List raw = const [];
    if (data is Map && data['teams'] is List) {
      raw = data['teams'] as List;
    } else if (data is Map && data['data'] is List) {
      raw = data['data'] as List;
    } else if (data is List) {
      raw = data;
    }

    final currentId = widget.selectedTeamId ?? 0;
    final currentAge = _ageGroupFromName(widget.teamName);

    final rows = raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) {
          final id = _teamId(row);
          return id > 0 && id != currentId;
        })
        .toList();

    rows.sort((a, b) {
      final ageA = _ageGroupFromName(_teamTitle(a));
      final ageB = _ageGroupFromName(_teamTitle(b));

      final aRecommended =
          currentAge != null && ageA == currentAge + 1;
      final bRecommended =
          currentAge != null && ageB == currentAge + 1;

      if (aRecommended != bRecommended) {
        return aRecommended ? -1 : 1;
      }

      if (ageA != null && ageB != null && ageA != ageB) {
        return ageA.compareTo(ageB);
      }

      return _teamTitle(a).compareTo(_teamTitle(b));
    });

    return rows;
  }

  Future<bool> _movePlayerToTeam(
    Map<String, dynamic> player,
    int targetTeamId,
    String targetTeamName,
  ) async {
    final playerId = _rosterInt(
      player['id'] ??
          player['player_id'] ??
          player['playerId'],
    );
    if (playerId <= 0) {
      Get.snackbar(
        'Перевод игрока',
        'Не найден player_id',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse(_movePlayerTeamUrl),
            headers: const {
              'Content-Type':
                  'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'club_id': widget.clubId,
              'player_id': playerId,
              'target_team_id': targetTeamId,
              'actor_user_id': widget.currentUserId ?? 0,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeRosterResponse(response.body);
      final ok = data is Map &&
          (data['success'] == true ||
              data['status'] == 'success');

      if (!ok) {
        final message = data is Map
            ? _rosterText(
                data['message'] ??
                    data['error'] ??
                    'Сервер не подтвердил перевод',
              )
            : 'Сервер вернул некорректный ответ';
        throw Exception(message);
      }

      if (!mounted) return true;

      setState(() {
        _showFullProfileInRightPane = false;
        _rightPanePlayer = null;
      });

      Get.snackbar(
        targetTeamId > 0
            ? 'Игрок переведён'
            : 'Игрок отвязан',
        targetTeamId > 0
            ? '${_playerName(player)} → $targetTeamName'
            : '${_playerName(player)} → Без команды',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _CmrRosterColors.green,
        colorText: Colors.white,
      );

      await widget.onRefresh?.call();
      return true;
    } catch (error) {
      if (mounted) {
        Get.snackbar(
          'Не удалось изменить команду',
          '$error',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _CmrRosterColors.red,
          colorText: Colors.white,
        );
      }
      return false;
    }
  }

  Future<void> _openTransferPicker(
    Map<String, dynamic> player, {
    String? sourceTeamName,
  }) async {
    List<Map<String, dynamic>> teams;
    try {
      teams = await _loadTransferTeams();
    } catch (error) {
      if (mounted) {
        Get.snackbar(
          'Команды',
          'Не удалось загрузить список: $error',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return;
    }

    if (!mounted) return;

    final sourceTitle =
        sourceTeamName?.trim().isNotEmpty == true
            ? sourceTeamName!.trim()
            : widget.teamName;
    final sourceAge = _ageGroupFromName(sourceTitle);

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 540,
            maxHeight: 650,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(18, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _CmrRosterColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Перевести игрока',
                            style:
                                _CmrRosterText.title(16.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_playerName(player)} · $sourceTitle',
                            style:
                                _CmrRosterText.muted(10.8),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                color: _CmrRosterColors.line,
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(18, 11, 18, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Родительский доступ и действующие ключи '
                    'сохранятся после перевода.',
                    style: _CmrRosterText.muted(10.4),
                  ),
                ),
              ),
              Flexible(
                child: teams.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Других команд клуба нет',
                          style:
                              _CmrRosterText.muted(11.5),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                          10,
                          4,
                          10,
                          14,
                        ),
                        itemCount: teams.length,
                        separatorBuilder: (_, __) =>
                            const Divider(
                          height: 1,
                          color: _CmrRosterColors.line,
                        ),
                        itemBuilder: (_, index) {
                          final team = teams[index];
                          final title = _teamTitle(team);
                          final age =
                              _ageGroupFromName(title);
                          final recommended =
                              sourceAge != null &&
                                  age == sourceAge + 1;

                          return Material(
                            color: recommended
                                ? _CmrRosterColors
                                    .greenSoft2
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () => Navigator.pop(
                                dialogContext,
                                team,
                              ),
                              borderRadius:
                                  BorderRadius.circular(10),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: recommended
                                          ? 7
                                          : 5,
                                      height: recommended
                                          ? 7
                                          : 5,
                                      decoration:
                                          BoxDecoration(
                                        color: recommended
                                            ? _CmrRosterColors
                                                .green
                                            : _CmrRosterColors
                                                .subtle,
                                        shape:
                                            BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            title,
                                            style:
                                                _CmrRosterText
                                                    .value(12),
                                          ),
                                          if (recommended) ...[
                                            const SizedBox(
                                              height: 2,
                                            ),
                                            Text(
                                              'Следующая возрастная команда',
                                              style:
                                                  _CmrRosterText
                                                      .muted(
                                                9.8,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Выбрать',
                                      style:
                                          _CmrRosterText
                                              .action()
                                              .copyWith(
                                                color:
                                                    _CmrRosterColors
                                                        .greenDark,
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
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;

    await _movePlayerToTeam(
      player,
      _teamId(selected),
      _teamTitle(selected),
    );
  }

  Future<void> _confirmUnbindPlayer(
    Map<String, dynamic> player,
  ) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Отвязать игрока от команды?',
            ),
            content: Text(
              '${_playerName(player)} будет помещён в '
              '«Без команды».\n\n'
              'Профиль, история, дневник, трекер и '
              'родительские доступы сохранятся.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _CmrRosterColors.graphiteButton,
                ),
                child: const Text('Отвязать'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    await _movePlayerToTeam(
      player,
      0,
      'Без команды',
    );
  }

  Future<List<Map<String, dynamic>>>
      _loadUnassignedPlayers() async {
    final response = await http
        .post(
          Uri.parse(_getUnassignedPlayersUrl),
          body: {'club_id': '${widget.clubId}'},
        )
        .timeout(const Duration(seconds: 12));

    final data = _decodeRosterResponse(response.body);

    List raw = const [];
    if (data is Map && data['players'] is List) {
      raw = data['players'] as List;
    } else if (data is Map && data['items'] is List) {
      raw = data['items'] as List;
    } else if (data is List) {
      raw = data;
    }

    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _openUnassignedPlayers() async {
    List<Map<String, dynamic>> rows;
    try {
      rows = await _loadUnassignedPlayers();
    } catch (error) {
      if (mounted) {
        Get.snackbar(
          'Без команды',
          'Не удалось загрузить список: $error',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
            maxHeight: 650,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(18, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _CmrRosterColors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Игроки без команды',
                            style:
                                _CmrRosterText.title(16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Можно снова привязать к любой команде клуба',
                            style:
                                _CmrRosterText.muted(10.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                color: _CmrRosterColors.line,
              ),
              Flexible(
                child: rows.isEmpty
                    ? Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(28),
                          child: Text(
                            'Список пуст',
                            style:
                                _CmrRosterText.muted(11.5),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(10),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) =>
                            const Divider(
                          height: 1,
                          color: _CmrRosterColors.line,
                        ),
                        itemBuilder: (_, index) {
                          final player = rows[index];
                          final lastTeam = _rosterText(
                            player[
                                'last_team_name'],
                          );

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        _playerName(player),
                                        style:
                                            _CmrRosterText
                                                .value(11.8),
                                      ),
                                      if (lastTeam
                                          .isNotEmpty) ...[
                                        const SizedBox(
                                          height: 2,
                                        ),
                                        Text(
                                          'Был в $lastTeam',
                                          style:
                                              _CmrRosterText
                                                  .muted(
                                            9.8,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(
                                      dialogContext,
                                    );
                                    await _openTransferPicker(
                                      player,
                                      sourceTeamName:
                                          lastTeam.isEmpty
                                              ? 'Без команды'
                                              : lastTeam,
                                    );
                                  },
                                  child: const Text(
                                    'Привязать',
                                  ),
                                ),
                              ],
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

  Future<List<Map<String, dynamic>>>
      _loadArchivedPlayers() async {
    final response = await http
        .post(
          Uri.parse(_getArchivedPlayersUrl),
          headers: const {
            'Content-Type':
                'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'club_id': widget.clubId,
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = _decodeRosterResponse(response.body);

    List raw = const [];
    if (data is Map && data['players'] is List) {
      raw = data['players'] as List;
    } else if (data is Map && data['items'] is List) {
      raw = data['items'] as List;
    } else if (data is List) {
      raw = data;
    }

    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _restoreArchivedPlayer(
    Map<String, dynamic> player,
  ) async {
    final playerId = _rosterInt(
      player['player_id'] ??
          player['id'],
    );

    if (playerId <= 0) {
      Get.snackbar(
        'Архив',
        'Не найден player_id',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(_restoreArchivedPlayerUrl),
            headers: const {
              'Content-Type':
                  'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'club_id': widget.clubId,
              'player_id': playerId,
              'actor_user_id':
                  widget.currentUserId ?? 0,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data =
          _decodeRosterResponse(response.body);

      final ok = data is Map &&
          (data['success'] == true ||
              data['status'] == 'success');

      if (!ok) {
        final message = data is Map
            ? _rosterText(
                data['message'] ??
                    data['error'] ??
                    'Сервер не подтвердил восстановление',
              )
            : 'Некорректный ответ сервера';

        throw Exception(message);
      }

      if (!mounted) return;

      Get.snackbar(
        'Игрок восстановлен',
        '${_playerName(player)} → '
        '${_rosterText(data['team_name']).isEmpty ? 'прежняя команда' : _rosterText(data['team_name'])}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor:
            _CmrRosterColors.green,
        colorText: Colors.white,
      );

      await widget.onRefresh?.call();
    } catch (error) {
      if (!mounted) return;

      Get.snackbar(
        'Не удалось восстановить',
        '$error',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _CmrRosterColors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _openArchivedPlayers() async {
    List<Map<String, dynamic>> rows;

    try {
      rows = await _loadArchivedPlayers();
    } catch (error) {
      if (mounted) {
        Get.snackbar(
          'Архив',
          'Не удалось загрузить архив: $error',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 590,
            maxHeight: 680,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  16,
                  12,
                  12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration:
                          const BoxDecoration(
                        color:
                            _CmrRosterColors.greenDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Архив игроков',
                            style:
                                _CmrRosterText.title(
                              16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Данные не удаляются. Игрока можно восстановить в прежнюю команду.',
                            style:
                                _CmrRosterText.muted(
                              10.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(
                        dialogContext,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                color: _CmrRosterColors.line,
              ),
              Flexible(
                child: rows.isEmpty
                    ? Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(
                            30,
                          ),
                          child: Text(
                            'Архив пуст',
                            style:
                                _CmrRosterText.muted(
                              11.5,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding:
                            const EdgeInsets.all(10),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) =>
                            const Divider(
                          height: 1,
                          color:
                              _CmrRosterColors.line,
                        ),
                        itemBuilder: (_, index) {
                          final player = rows[index];
                          final teamName =
                              _rosterText(
                            player[
                                'original_team_name'],
                          );
                          final archivedAt =
                              _rosterText(
                            player['archived_at'],
                          );
                          final linkedRows =
                              _rosterInt(
                            player[
                                'linked_rows_total'],
                          );

                          return Padding(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin:
                                      const EdgeInsets
                                          .only(
                                    top: 6,
                                  ),
                                  decoration:
                                      const BoxDecoration(
                                    color:
                                        _CmrRosterColors
                                            .greenDark,
                                    shape:
                                        BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        _playerName(
                                          player,
                                        ),
                                        style:
                                            _CmrRosterText
                                                .value(
                                          11.8,
                                        ),
                                      ),
                                      if (teamName
                                          .isNotEmpty) ...[
                                        const SizedBox(
                                          height: 2,
                                        ),
                                        Text(
                                          'Команда: $teamName',
                                          style:
                                              _CmrRosterText
                                                  .muted(
                                            9.8,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(
                                        height: 2,
                                      ),
                                      Text(
                                        <String>[
                                          if (archivedAt
                                              .isNotEmpty)
                                            'Архив: $archivedAt',
                                          if (linkedRows >
                                              0)
                                            'Связанных записей: $linkedRows',
                                        ].join(' · '),
                                        style:
                                            _CmrRosterText
                                                .muted(
                                          9.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                TextButton(
                                  onPressed:
                                      () async {
                                    Navigator.pop(
                                      dialogContext,
                                    );
                                    await _restoreArchivedPlayer(
                                      player,
                                    );
                                  },
                                  child: const Text(
                                    'Восстановить',
                                  ),
                                ),
                              ],
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
      // Локальный выбор игрока не сбрасываем на обычном rebuild родителя.
      // Сбрасываем только если реально сменилась команда либо выбранного
      // игрока больше нет в текущем составе.
      final teamChanged = oldWidget.selectedTeamId != widget.selectedTeamId;
      final localKey = _playerIdentity(_rightPanePlayer);
      final localStillExists = localKey.isNotEmpty &&
          widget.players.any((p) => _playerIdentity(p) == localKey);
      if (teamChanged || !localStillExists) {
        _rightPanePlayer = null;
        _showProfileMenu = false;
        _showFullProfileInRightPane = false;
        if (teamChanged) _showAddPlayerInRightPane = false;
      }
      return;
    }

    final oldKey = _playerIdentity(oldWidget.selectedPlayer);
    final newKey = _playerIdentity(selected);
    if (oldKey != newKey) {
      _rightPanePlayer = Map<String, dynamic>.from(selected);
      _profileSection = PlayerProfileSection.card;
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
      // ВАЖНО: widget.onOpenPlayer здесь не вызываем. В родительском
      // workspace этот callback может сам переключать экран на подробный
      // профиль. Полный профиль открываем только локально после явного
      // нажатия «Открыть профиль».
      if (!mounted) return;
      setState(() {
        _rightPanePlayer = mp;
        _profileSection = PlayerProfileSection.card;
        _showProfileMenu = true;
        _showFullProfileInRightPane = true;
        _showAddPlayerInRightPane = false;
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

  void _selectProfileSection(PlayerProfileSection section) {
    if (!mounted) return;
    setState(() {
      _profileSection = section;
      _showProfileMenu = true;
      _showFullProfileInRightPane = true;
      _showAddPlayerInRightPane = false;
    });
  }

  void _backToRosterList() {
    if (!mounted) return;
    setState(() {
      _showProfileMenu = false;
      _showFullProfileInRightPane = false;
      _showAddPlayerInRightPane = false;
      // _rightPanePlayer и ScrollController сохраняем намеренно:
      // при возврате состав открывается на том же игроке и том же scroll offset.
    });
  }

  void _handleOpenPlayer(Map<String, dynamic> player, bool mobile) {
    final selected = Map<String, dynamic>.from(player);
    selected['team_id'] ??= selected['teamId'] ?? widget.selectedTeamId;
    selected['teamId'] ??= selected['team_id'] ?? widget.selectedTeamId;
    selected['club_id'] ??= selected['clubId'] ?? widget.clubId;
    selected['clubId'] ??= selected['club_id'] ?? widget.clubId;
    selected['team_name'] ??= widget.teamName;
    selected['teamName'] ??= widget.teamName;

    // Первый клик по игроку НЕ открывает полный профиль и НЕ заменяет
    // список игроков меню профиля. Слева остаётся состав, справа показываем
    // только компактный обзор с отдельной кнопкой «Открыть профиль».
    // Также не вызываем widget.onOpenPlayer: в родительском workspace этот
    // callback может сразу переводить на подробный экран.
    setState(() {
      _rightPanePlayer = selected;
      _profileSection = PlayerProfileSection.card;
      _showProfileMenu = false;
      _showFullProfileInRightPane = false;
      _showAddPlayerInRightPane = false;
    });

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
              clubId: widget.clubId,
              teamId: widget.selectedTeamId ?? 0,
              currentUserId: widget.currentUserId,
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
    const codeWord = 'АРХИВ';

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
                                    'Переместить игрока в архив?',
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
                            'Игрок исчезнет из активного состава, но профиль, аналитика, трекер, дневник, тесты, медицина, посещаемость, матчи и родительские связи останутся на сервере. Для подтверждения введите $codeWord.',
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
                            'Ошибка архивации: $errorText',
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
                                title: deleting ? 'Архивация...' : 'В архив',
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
          _showProfileMenu = false;
          _showFullProfileInRightPane = false;
        }
      });

      await widget.onRefresh?.call();
      if (!mounted) return;

      Get.snackbar(
        'Игрок перемещён в архив',
        name,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _CmrRosterColors.green,
        colorText: Colors.white,
      );
    } finally {
      codeController.dispose();
    }
  }

  void _handleAddPlayer() {
    final limit = widget.maxPlayers;

    if (limit != null && limit > 0 && widget.players.length >= limit) {
      Get.snackbar(
        'Лимит базовой подписки',
        'В одной команде доступно до $limit игроков. '
        'Сейчас в составе: ${widget.players.length}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.white,
        colorText: _CmrRosterColors.text,
        icon: const Icon(
          Icons.info_outline_rounded,
          color: _CmrRosterColors.green,
        ),
      );
      return;
    }

    final teamId = widget.selectedTeamId ?? 0;
    if (teamId <= 0) {
      Get.snackbar(
        'Команда',
        'Сначала выберите команду',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final width = MediaQuery.maybeOf(context)?.size.width ?? 0;

    // На планшете/ПК форма живёт в той же правой области состава.
    // На телефоне сохраняем старый отдельный маршрут через callback родителя.
    if (width >= 640) {
      setState(() {
        _showAddPlayerInRightPane = true;
        _showProfileMenu = false;
        _showFullProfileInRightPane = false;
      });
      return;
    }

    widget.onAddPlayer();
  }

  Future<void> _handleEmbeddedPlayerSaved(
    Map<String, dynamic> createdPlayer,
  ) async {
    await widget.onRefresh?.call();
    if (!mounted) return;

    final createdId = _rosterInt(
      createdPlayer['id'] ??
          createdPlayer['player_id'] ??
          createdPlayer['playerId'],
    );
    final createdEmail = _rosterText(createdPlayer['email']).toLowerCase();

    Map<String, dynamic>? resolved;
    for (final player in widget.players) {
      final id = _rosterInt(
        player['id'] ?? player['player_id'] ?? player['playerId'],
      );
      final email = _rosterText(player['email']).toLowerCase();
      if ((createdId > 0 && id == createdId) ||
          (createdEmail.isNotEmpty && email == createdEmail)) {
        resolved = Map<String, dynamic>.from(player);
        break;
      }
    }

    setState(() {
      _showAddPlayerInRightPane = false;
      _showProfileMenu = false;
      _showFullProfileInRightPane = false;
      _rightPanePlayer = resolved ?? Map<String, dynamic>.from(createdPlayer);
    });
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
          final profilePlayer = _rightPanePlayer ?? widget.selectedPlayer;

          // Обычный состав имеет ту же ширину, что левые панели
          // «Команды» и «Тренеры». Внутреннее меню профиля игрока
          // сохраняет прежнюю компактную Tracker-ширину.
          final trackerMenuWidth = constraints.maxWidth >= 1700
              ? 306.0
              : (constraints.maxWidth >= 1440
                  ? 286.0
                  : (constraints.maxWidth >= 1180 ? 262.0 : 232.0));

          final rosterListWidth = math.min(
            compact ? 430.0 : 480.0,
            constraints.maxWidth * (compact ? .43 : .45),
          );

          final profileMenuWidth = math.min(
            math.max(trackerMenuWidth, 232.0),
            constraints.maxWidth * .42,
          );

          final listWidth = mobile
              ? constraints.maxWidth
              : (_showProfileMenu && profilePlayer != null
                  ? profileMenuWidth
                  : rosterListWidth);

          final rosterList = _RosterListPanel(
            teamName: widget.teamName,
            playersCount: widget.players.length,
            visibleCount: visiblePlayers.length,
            searchController: _searchC,
            scrollController: _scrollC,
            filter: _filter,
            onFilterChanged: (value) => setState(() => _filter = value),
            onAddPlayer: _handleAddPlayer,
            onRefresh: widget.onRefresh,
            onDeletePlayer: _confirmDeletePlayer,
            onMovePlayer: _openTransferPicker,
            onUnbindPlayer: _confirmUnbindPlayer,
            onOpenUnassigned: _openUnassignedPlayers,
            onOpenArchive: _openArchivedPlayers,
            players: visiblePlayers,
            selectedKey: _playerIdentity(_rightPanePlayer ?? widget.selectedPlayer),
            playerIdentity: _playerIdentity,
            onOpenPlayer: (player) => _handleOpenPlayer(player, mobile),
            compact: compact,
            mobile: mobile,
          );

          final list = !mobile &&
                  _showProfileMenu &&
                  profilePlayer != null
              ? _PlayerProfileNavigationPanel(
                  player: profilePlayer,
                  teamName: widget.teamName,
                  selectedSection: _profileSection,
                  onSelect: _selectProfileSection,
                  onBack: _backToRosterList,
                )
              : rosterList;

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
                      child: _showAddPlayerInRightPane
                          ? AddPlayerScreen(
                              key: ValueKey(
                                'right-add-player-${widget.selectedTeamId ?? 0}',
                              ),
                              teamId: widget.selectedTeamId ?? 0,
                              teamName: widget.teamName,
                              embeddedInWorkspace: true,
                              onCancel: () {
                                if (!mounted) return;
                                setState(() {
                                  _showAddPlayerInRightPane = false;
                                });
                              },
                              onSaved: _handleEmbeddedPlayerSaved,
                            )
                          : _showFullProfileInRightPane &&
                                  (_rightPanePlayer ?? widget.selectedPlayer) != null
                              ? CmrPlayerProfileScreen(
                              key: ValueKey(
                                'right-profile-${_playerIdentity(_rightPanePlayer ?? widget.selectedPlayer)}',
                              ),
                              player: Map<String, dynamic>.from(
                                _rightPanePlayer ?? widget.selectedPlayer!,
                              ),
                              embeddedInWorkspace: true,
                              // Навигация полностью живёт слева, как в Tracker.
                              // Поэтому горизонтальные вкладки и дублирующий ×
                              // в шапке встроенного профиля не показываем.
                              showSectionTabs: false,
                              externalSection: _profileSection,
                              onSectionChanged: _selectProfileSection,
                            )
                          : _PlayerDetailPanel(
                              player: profilePlayer,
                              teamName: widget.teamName,
                              clubId: widget.clubId,
                              teamId: widget.selectedTeamId ?? 0,
                              currentUserId: widget.currentUserId,
                              onOpenFullProfile: profilePlayer == null
                                  ? null
                                  : () => _openFullProfile(profilePlayer),
                              onDeletePlayer: profilePlayer == null ||
                                      widget.onDeletePlayer == null
                                  ? null
                                  : () => _confirmDeletePlayer(profilePlayer),
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
  final ValueChanged<Map<String, dynamic>> onMovePlayer;
  final ValueChanged<Map<String, dynamic>> onUnbindPlayer;
  final VoidCallback onOpenUnassigned;
  final VoidCallback onOpenArchive;
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
    required this.onMovePlayer,
    required this.onUnbindPlayer,
    required this.onOpenUnassigned,
    required this.onOpenArchive,
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
              onOpenUnassigned: onOpenUnassigned,
              onOpenArchive: onOpenArchive,
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
                    child: ListView.separated(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        10,
                        6,
                        10,
                        mobile
                            ? _CmrRosterDecor.mobileDockScrollInset
                            : 12,
                      ),
                      itemCount: players.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, index) {
                        final player = players[index];
                        final active = selectedKey.isNotEmpty &&
                            selectedKey == playerIdentity(player);
                        return _PlayerTile(
                          player: player,
                          active: active,
                          index: index,
                          onTap: () => onOpenPlayer(player),
                          onMove: () => onMovePlayer(player),
                          onUnbind: () => onUnbindPlayer(player),
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
  final VoidCallback onOpenUnassigned;
  final VoidCallback onOpenArchive;
  final bool mobile;

  const _RosterToolbar({
    required this.teamName,
    required this.onAddPlayer,
    required this.onRefresh,
    required this.onOpenUnassigned,
    required this.onOpenArchive,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 330;

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
                    style: mobile
                        ? AppTypography.screenTitle(color: _CmrRosterColors.text)
                        : _CmrRosterText.title(16.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrRosterText.muted(mobile ? 12 : 11.5),
                  ),
                ],
              ),
            ),
            if (narrow) ...[
              PopupMenuButton<String>(
                tooltip: 'Действия со списком',
                elevation: 0,
                color: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (value == 'refresh') onRefresh?.call();
                    if (value == 'unassigned') onOpenUnassigned();
                    if (value == 'archive') onOpenArchive();
                  });
                },
                itemBuilder: (_) => [
                  if (onRefresh != null)
                    PopupMenuItem<String>(
                      value: 'refresh',
                      child: Text(
                        'Обновить',
                        style: _CmrRosterText.action(),
                      ),
                    ),
                  PopupMenuItem<String>(
                    value: 'unassigned',
                    child: Text(
                      'Без команды',
                      style: _CmrRosterText.action(),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'archive',
                    child: Text(
                      'Архив',
                      style: _CmrRosterText.action(),
                    ),
                  ),
                ],
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _CmrRosterColors.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '•••',
                    style: _CmrRosterText.action().copyWith(
                      color: _CmrRosterColors.muted2,
                      fontSize: 11.5,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _CmrRosterIconButton(
                icon: Icons.person_add_alt_1_rounded,
                tooltip: 'Добавить игрока',
                onTap: onAddPlayer,
                emphasized: true,
                compact: true,
              ),
            ] else ...[
              if (onRefresh != null && !mobile) ...[
                _CmrRosterIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Обновить',
                  onTap: () => onRefresh?.call(),
                  compact: true,
                ),
                const SizedBox(width: 6),
              ],
              Material(
                color: _CmrRosterColors.soft,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  onTap: onOpenUnassigned,
                  borderRadius: BorderRadius.circular(9),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: mobile ? 8 : 10,
                      vertical: 8,
                    ),
                    child: Text(
                      mobile ? 'Без ком.' : 'Без команды',
                      style: _CmrRosterText.action().copyWith(
                        color: _CmrRosterColors.graphiteSoft,
                        fontSize: mobile ? 11.2 : 10.7,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: _CmrRosterColors.greenSoft2,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  onTap: onOpenArchive,
                  borderRadius: BorderRadius.circular(9),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: mobile ? 8 : 10,
                      vertical: 8,
                    ),
                    child: Text(
                      'Архив',
                      style: _CmrRosterText.action().copyWith(
                        color: _CmrRosterColors.greenDark,
                        fontSize: mobile ? 11.2 : 10.7,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _CmrRosterIconButton(
                icon: Icons.person_add_alt_1_rounded,
                tooltip: 'Добавить игрока',
                onTap: onAddPlayer,
                emphasized: true,
                compact: true,
              ),
            ],
          ],
        );
      },
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
              style: mobile
                  ? AppTypography.formText(color: _CmrRosterColors.text)
                  : _CmrRosterText.value(13),
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
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrRosterText.action().copyWith(
                  color: active
                      ? _CmrRosterColors.greenDark
                      : _CmrRosterColors.muted2,
                  fontSize: dense ? 12.0 : 11.4,
                  fontWeight: active
                      ? FontWeight.w700
                      : FontWeight.w500,
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

class _PlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool active;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onMove;
  final VoidCallback onUnbind;
  final VoidCallback onDelete;
  final bool mobile;

  const _PlayerTile({
    required this.player,
    required this.active,
    required this.index,
    required this.onTap,
    required this.onMove,
    required this.onUnbind,
    required this.onDelete,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final name = _playerName(player);
    final position = _playerPosition(player);
    final number = _jerseyNumber(player);
    final photo = _playerPhotoUrl(player);
    final age = _ageLabel(player);
    final polar = _playerHasPolar(player);
    final gps = _playerHasGps(player);
    final activity = _playerActivityLabel(player);

    final subtitleParts = <String>[
      position.isEmpty ? 'Без амплуа' : position,
      if (age.isNotEmpty) age,
      if (number.isNotEmpty) '№ $number',
      if (gps) 'GPS',
      if (polar) 'POLAR',
      if (activity.isNotEmpty) activity,
    ];

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          decoration: BoxDecoration(
            color: active
                ? _CmrRosterColors.greenSoft
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CmrGlowDot(
                color: active
                    ? _CmrRosterColors.green
                    : _CmrRosterColors.muted2,
                size: active ? 6.4 : 4.8,
                opacity: active ? 1 : .48,
                halo: active,
              ),
              const SizedBox(width: 9),
              _CmrRosterAvatar(
                photo: photo,
                name: name,
                size: mobile ? 40 : 38,
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
                      style: _CmrRosterText.navLabel(active: active).copyWith(
                        fontSize: mobile ? 12.0 : 11.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleParts.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrRosterText.navSubtitle(active: active).copyWith(
                        fontSize: mobile ? 11.2 : 10.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              _RosterPlayerActionsButton(
                onMove: onMove,
                onUnbind: onUnbind,
                onDelete: onDelete,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerProfileNavigationPanel extends StatelessWidget {
  final Map<String, dynamic> player;
  final String teamName;
  final PlayerProfileSection selectedSection;
  final ValueChanged<PlayerProfileSection> onSelect;
  final VoidCallback onBack;

  const _PlayerProfileNavigationPanel({
    required this.player,
    required this.teamName,
    required this.selectedSection,
    required this.onSelect,
    required this.onBack,
  });

  static const List<
      ({
        PlayerProfileSection section,
        String label,
        String subtitle,
      })> _items = [
    (
      section: PlayerProfileSection.card,
      label: 'Карточка игрока',
      subtitle: 'основные данные и профиль',
    ),
    (
      section: PlayerProfileSection.diary,
      label: 'Дневник',
      subtitle: 'оценки, самооценка и заметки',
    ),
    (
      section: PlayerProfileSection.readiness,
      label: 'Готовность',
      subtitle: 'readiness и нагрузка',
    ),
    (
      section: PlayerProfileSection.activity,
      label: 'Активность',
      subtitle: 'тренировки и показатели',
    ),
    (
      section: PlayerProfileSection.matches,
      label: 'Матчи',
      subtitle: 'игры и статистика',
    ),
    (
      section: PlayerProfileSection.testing,
      label: 'Тестирование',
      subtitle: 'тесты и динамика',
    ),
    (
      section: PlayerProfileSection.health,
      label: 'Здоровье',
      subtitle: 'медицина и физические данные',
    ),
    (
      section: PlayerProfileSection.documents,
      label: 'Документы',
      subtitle: 'файлы и документы игрока',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, index) {
                final item = _items[index];
                final active = selectedSection == item.section ||
                    (item.section == PlayerProfileSection.card &&
                        selectedSection == PlayerProfileSection.overview) ||
                    (item.section == PlayerProfileSection.activity &&
                        selectedSection == PlayerProfileSection.analytics);

                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: () => onSelect(item.section),
                    borderRadius: BorderRadius.circular(9),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
                      decoration: BoxDecoration(
                        color: active
                            ? _CmrRosterColors.greenSoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: _CmrGlowDot(
                              color: active
                                  ? _CmrRosterColors.green
                                  : _CmrRosterColors.muted2,
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
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _CmrRosterText.navLabel(
                                    active: active,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _CmrRosterText.navSubtitle(
                                    active: active,
                                  ),
                                ),
                              ],
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
          Container(height: 1, color: _CmrRosterColors.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
                  decoration: BoxDecoration(
                    color: _CmrRosterColors.soft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: _CmrGlowDot(
                          color: _CmrRosterColors.green,
                          size: 6.4,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'К списку игроков',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _CmrRosterText.navLabel(active: false),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_playerName(player)} · $teamName',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _CmrRosterText.navSubtitle(active: false),
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


class _CmrGlowDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  final bool halo;

  const _CmrGlowDot({
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
                  BoxShadow(
                    color: color.withOpacity(.07),
                    blurRadius: size * 3,
                    spreadRadius: .5,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _CmrDotCluster extends StatelessWidget {
  final Color color;
  final bool light;

  const _CmrDotCluster({
    this.color = _CmrRosterColors.green,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = light ? Colors.white : color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CmrGlowDot(color: c, size: 3.5, opacity: .25, halo: false),
        const SizedBox(width: 3),
        _CmrGlowDot(color: c, size: 4.5, opacity: .48, halo: false),
        const SizedBox(width: 3),
        _CmrGlowDot(color: c, size: 5.5, opacity: .72, halo: false),
        const SizedBox(width: 3),
        _CmrGlowDot(color: c, size: 6.5),
      ],
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
        _CmrGlowDot(
          color: color,
          size: 6,
        ),
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
      child: _CmrGlowDot(
        color: color,
        size: 8,
      ),
    );
  }
}

class _RosterActiveDot extends StatelessWidget {
  const _RosterActiveDot();

  @override
  Widget build(BuildContext context) {
    return const _CmrGlowDot(
      color: _CmrRosterColors.green,
      size: 6,
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
      width: 18,
      height: 18,
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
                color: active
                    ? _CmrRosterColors.green
                    : _CmrRosterColors.muted,
                fontSize: number.length == 1 ? 10.5 : 9.6,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            )
          : Center(
              child: _CmrGlowDot(
                color: active
                    ? _CmrRosterColors.green
                    : _CmrRosterColors.muted2,
                size: 6,
                opacity: active ? 1 : .72,
                halo: active,
              ),
            ),
    );
  }
}

// ==================== Правая панель игрока ====================

class _PlayerDetailPanel extends StatelessWidget {
  final Map<String, dynamic>? player;
  final String teamName;
  final int clubId;
  final int teamId;
  final int? currentUserId;
  final VoidCallback? onOpenFullProfile;
  final Future<void> Function()? onDeletePlayer;
  final VoidCallback? onClose;
  final ScrollController? scrollController;

  const _PlayerDetailPanel({
    required this.player,
    required this.teamName,
    required this.clubId,
    required this.teamId,
    required this.currentUserId,
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
    final photo = _playerPhotoUrl(p);
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
        const SizedBox(height: 18),
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

        // Parent Access deliberately lives BELOW the player overview.
        // One parent ListView, no fixed 420px nested scroll.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              _CmrRosterColors.green.withOpacity(.022),
              _CmrRosterColors.soft,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _CmrRosterColors.green.withOpacity(.025),
                blurRadius: 18,
                spreadRadius: -10,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: CmrPlayerParentAccessPanel(
            key: ValueKey(
              'parent-access-${_first(p, const ['player_id', 'id'])}',
            ),
            player: p,
            clubId: clubId,
            teamId: teamId,
            currentUserId: currentUserId,
            compact: true,
            inlineInParentScroll: true,
          ),
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
          _CmrGlowDot(
            color: enabled ? color : _CmrRosterColors.line,
            size: 7,
            halo: enabled,
          ),
          const SizedBox(width: 7),
          Expanded(child: Text(title, style: _CmrRosterText.value(11.5))),
          _CmrGlowDot(
            color: enabled ? color : _CmrRosterColors.line,
            size: 5,
            opacity: enabled ? .48 : 1,
            halo: false,
          ),
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
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(
                    height: 1,
                    thickness: .55,
                    color: _CmrRosterColors.line,
                  ),
              ],
            ],
          ),
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
            const _CmrGlowDot(
              color: _CmrRosterColors.greenDark,
              size: 6,
              halo: false,
            ),
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
  final VoidCallback onMove;
  final VoidCallback onUnbind;
  final VoidCallback onDelete;
  final bool compact;

  const _RosterPlayerActionsButton({
    required this.onMove,
    required this.onUnbind,
    required this.onDelete,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_RosterPlayerAction>(
      tooltip: 'Действия с игроком',
      elevation: 0,
      color: _CmrRosterColors.panel,
      surfaceTintColor: _CmrRosterColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          _CmrRosterDecor.mobileInnerRadius,
        ),
      ),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: (action) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          switch (action) {
            case _RosterPlayerAction.move:
              onMove();
              break;
            case _RosterPlayerAction.unbind:
              onUnbind();
              break;
            case _RosterPlayerAction.delete:
              onDelete();
              break;
          }
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem<_RosterPlayerAction>(
          value: _RosterPlayerAction.move,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 3,
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _CmrRosterColors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'Перевести в команду…',
                style: _CmrRosterText.value(10.8),
              ),
            ],
          ),
        ),
        PopupMenuItem<_RosterPlayerAction>(
          value: _RosterPlayerAction.unbind,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 3,
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _CmrRosterColors.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'Отвязать от команды',
                style: _CmrRosterText.value(10.8),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<_RosterPlayerAction>(
          value: _RosterPlayerAction.delete,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 3,
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _CmrRosterColors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'В архив',
                style: _CmrRosterText.danger(),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: compact ? 28 : 38,
        height: compact ? 28 : 38,
        decoration: BoxDecoration(
          color: _CmrRosterColors.soft,
          borderRadius: BorderRadius.circular(
            compact
                ? 10
                : _CmrRosterDecor.mobileInnerRadius,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '•••',
          style: _CmrRosterText.action().copyWith(
            color: _CmrRosterColors.muted2,
            fontSize: compact ? 11.5 : 13,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

enum _RosterPlayerAction {
  move,
  unbind,
  delete,
}

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
                        ? _CmrRosterColors.green.withOpacity(.055)
                        : Colors.white.withOpacity(.68),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(action.accent ? .9 : .55),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
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
                    'В архив',
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
  if (value.startsWith('/')) return 'https://sportotekaapp.ru$value';

  final cleaned = value.replaceFirst(RegExp(r'^\./+'), '');
  if (cleaned.startsWith('uploads/')) {
    return 'https://sportotekaapp.ru/$cleaned';
  }

  // В профиле игрока относительное имя фото хранится как файл uploads/.
  // Старый roster ошибочно собирал URL от корня домена, поэтому фото могло
  // стабильно получать 404.
  return 'https://sportotekaapp.ru/uploads/$cleaned';
}

String _playerPhotoUrl(Map<String, dynamic> player) {
  const keys = <String>[
    'photo',
    'photo_url',
    'photoUrl',
    'avatar',
    'avatar_url',
    'avatarUrl',
    'image',
    'image_url',
    'imageUrl',
    'player_photo',
    'playerPhoto',
    'profile_photo',
    'profilePhoto',
    'photo_path',
    'photoPath',
    'avatar_path',
    'avatarPath',
  ];

  final direct = _first(player, keys);
  if (direct.isNotEmpty) return _absoluteUrl(direct);

  // Некоторые API возвращают медиа внутри profile/player/media.
  for (final containerKey in const ['profile', 'player', 'media']) {
    final nested = player[containerKey];
    if (nested is Map) {
      final value = _first(Map<String, dynamic>.from(nested), keys);
      if (value.isNotEmpty) return _absoluteUrl(value);
    }
  }
  return '';
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

