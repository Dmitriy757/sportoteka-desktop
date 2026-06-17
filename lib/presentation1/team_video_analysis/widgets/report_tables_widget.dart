import 'dart:io';
import 'dart:math' as math;

import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/formatters.dart';
import 'package:flutter/services.dart' show rootBundle;

class ReportTablesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> mainReportRows;
  final List<Map<String, dynamic>> passReportRows;
  final List<Map<String, dynamic>> goalkeeperReportRows;
  final bool reportLoading;
  final List<Map<String, dynamic>> selectedMatchPlayers;
  final VoidCallback? onBack; 
  
  
  const ReportTablesWidget({
  super.key,
  required this.mainReportRows,
  required this.passReportRows,
  required this.goalkeeperReportRows,
  required this.reportLoading,
  required this.selectedMatchPlayers,
  this.onBack,
});


  // =========================
  // CMR PREMIUM STYLE
  // =========================

  static const Color _cmrBg = Color(0xFFF5F6F7);
  static const Color _cmrPanel = Colors.white;
  static const Color _cmrSoft = Color(0xFFF8F9FA);
  static const Color _cmrText = Color(0xFF0B0F14);
  static const Color _cmrText2 = Color(0xFF182230);
  static const Color _cmrMuted = Color(0xFF374151);
  static const Color _cmrMuted2 = Color(0xFF6B7280);
  static const Color _cmrGraphite = Color(0xFF111827);
  static const Color _cmrGreen = Color(0xFF00A750);
  static const Color _cmrGreenDark = Color(0xFF067A46);
  static const Color _cmrGreenSoft = Color(0xFFF3FBF7);
  static const Color _cmrGreenBorder = Color(0xFFD7F0E2);
  static const Color _cmrLine = Color(0xFFE5E7EB);
  static const Color _cmrRed = Color(0xFFD92D20);

  TextStyle _cmrTitle(double size) => TextStyle(
        fontFamily: 'Roboto',
        color: _cmrText,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.12,
        letterSpacing: -0.25,
      );

  TextStyle _cmrValue(double size, {Color? color}) => TextStyle(
        fontFamily: 'Roboto',
        color: color ?? _cmrText2,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.12,
      );

  TextStyle _cmrMutedStyle(double size, {Color? color, FontWeight? weight}) => TextStyle(
        fontFamily: 'Roboto',
        color: color ?? _cmrMuted,
        fontSize: size,
        fontWeight: weight ?? FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.05,
      );

  BoxDecoration _cmrPanelDecoration({double radius = 14, bool elevated = false}) {
    return BoxDecoration(
      color: _cmrPanel,
      borderRadius: BorderRadius.circular(math.min(radius, 14)),
      border: Border.all(color: _cmrLine, width: 1),
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
  }

  BoxDecoration _cmrSoftDecoration({bool active = false, Color? accent}) {
    final accentColor = accent ?? _cmrGreen;
    return BoxDecoration(
      color: active ? _cmrPanel : _cmrSoft,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: active ? accentColor.withOpacity(.38) : _cmrLine,
        width: active ? 1.15 : 1,
      ),
    );
  }


Set<String> _selectedPlayerIds() {
  return selectedMatchPlayers
      .map((p) => Formatters.safeString(p['id']))
      .where((id) => id.isNotEmpty)
      .toSet();
}

String _rowPlayerId(Map<String, dynamic> row) {
  final candidates = [
    row['player_id'],
    row['id'],
    row['user_id'],
  ];

  for (final value in candidates) {
    final id = Formatters.safeString(value);
    if (id.isNotEmpty) return id;
  }

  return '';
}

List<Map<String, dynamic>> _filterRowsBySelectedPlayers(
  List<Map<String, dynamic>> rows,
) {
  final selectedIds = _selectedPlayerIds();

  if (selectedIds.isEmpty) return rows;

  return rows.where((row) {
    final rowId = _rowPlayerId(row);
    return rowId.isNotEmpty && selectedIds.contains(rowId);
  }).toList();
}

List<Map<String, dynamic>> get _filteredMainReportRows =>
    _filterRowsBySelectedPlayers(mainReportRows);

List<Map<String, dynamic>> get _filteredPassReportRows =>
    _filterRowsBySelectedPlayers(passReportRows);

List<Map<String, dynamic>> get _filteredGoalkeeperReportRows =>
    _filterRowsBySelectedPlayers(goalkeeperReportRows);
  // =========================
  // БАЗОВЫЕ РАЗМЕРЫ
  // =========================

  static const double playerNameWidth = 180;
  static const double playerNameWidthSmall = 150;
  static const double metricWidth = 70;
  static const double metricWidthSmall = 60;
  static const double percentWidth = 70;
  static const double totalWidth = 70;
  static const double rowGap = 8;

  static const double passPlayerWidth = 180;
  static const double passMetricWidth = 60;
  static const double passTotalWidth = 76;
  static const double passPercentWidth = 76;

  static const double mainTableWidth =
      playerNameWidth +
      rowGap +
      (metricWidth + 10) +
      metricWidth +
      metricWidth +
      metricWidth +
      metricWidth +
      metricWidth +
      metricWidthSmall +
      metricWidth +
      totalWidth +
      percentWidth;

  static const double commonTableMinWidth = mainTableWidth;

  // =========================
  // RESPONSIVE HELPERS
  // =========================

  double _usableWidth(BoxConstraints constraints) {
    return math.max(0.0, constraints.maxWidth - 24);
  }

  double _tableScale(BoxConstraints constraints) {
    final usable = _usableWidth(constraints);
    if (usable <= commonTableMinWidth) return 1.0;
    return usable / commonTableMinWidth;
  }

  double _tableWidth(BoxConstraints constraints) {
    final usable = _usableWidth(constraints);
    return usable > commonTableMinWidth ? usable : commonTableMinWidth;
  }

  bool _needsHorizontalScroll(BoxConstraints constraints) {
    return _usableWidth(constraints) < commonTableMinWidth;
  }

  bool _isTablet(BoxConstraints constraints) {
    return constraints.maxWidth >= 700;
  }

  double _responsiveFont(
    BoxConstraints constraints, {
    required double phone,
    required double tablet,
  }) {
    return _isTablet(constraints) ? tablet : phone;
  }

  EdgeInsets _tableInnerPadding(BoxConstraints constraints) {
    return EdgeInsets.all(_isTablet(constraints) ? 16 : 12);
  }

  double _responsiveAvatar(
    BoxConstraints constraints, {
    required double phone,
    required double tablet,
  }) {
    return _isTablet(constraints) ? tablet : phone;
  }

  // =========================
  // ГРУППЫ / КАТЕГОРИИ
  // =========================

  String _normalizeGroupKey(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    if (key.isEmpty) return 'no_role';

    switch (key) {
      case 'def':
      case 'defender':
      case 'defenders':
        return 'def';
      case 'mid':
      case 'mf':
      case 'midfielder':
      case 'midfielders':
        return 'mid';
      case 'fwd':
      case 'fw':
      case 'att':
      case 'forward':
      case 'forwards':
      case 'striker':
        return 'fwd';
      case 'gk':
      case 'goalkeeper':
      case 'keeper':
        return 'gk';
      case 'sub':
      case 'subs':
      case 'bench':
      case 'reserve':
      case 'res':
        return 'bench';
      case 'other':
      case 'others':
      case 'unknown':
        return 'no_role';
      default:
        return key;
    }
  }

  String _groupTitle(String key) {
    switch (key) {
      case 'def':
        return 'Защитники';
      case 'mid':
        return 'Полузащитники';
      case 'fwd':
        return 'Нападающие';
      case 'gk':
        return 'Вратари';
      case 'bench':
        return 'Запасные';
      case 'no_role':
        return 'Игроки без указанного амплуа';
      default:
        return 'Категория: ${key.toUpperCase()}';
    }
  }

  Color _groupColor(String key) {
    switch (key) {
      case 'def':
        return const Color(0xFF059669);
      case 'mid':
        return const Color(0xFF2563EB);
      case 'fwd':
        return const Color(0xFFDC2626);
      case 'gk':
        return const Color(0xFFB91C1C);
      case 'bench':
        return const Color(0xFFF59E0B);
      case 'no_role':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF6B7280);
    }
  }

  List<Map<String, dynamic>> _reportRowsByGroup(
    List<Map<String, dynamic>> rows,
    String group,
  ) {
    final normalized = _normalizeGroupKey(group);
    return rows
        .where(
          (r) =>
              _normalizeGroupKey(Formatters.safeString(r['group_key'])) ==
              normalized,
        )
        .toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupRows(
    List<Map<String, dynamic>> rows, {
    bool includeGoalkeepers = false,
  }) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final row in rows) {
      final key = _normalizeGroupKey(Formatters.safeString(row['group_key']));
      if (!includeGoalkeepers && key == 'gk') continue;
      grouped.putIfAbsent(key, () => []).add(row);
    }

    const preferredOrder = ['def', 'mid', 'fwd', 'bench', 'no_role'];
    final ordered = <String, List<Map<String, dynamic>>>{};

    for (final key in preferredOrder) {
      if (grouped.containsKey(key) && grouped[key]!.isNotEmpty) {
        ordered[key] = grouped[key]!;
      }
    }

    for (final entry in grouped.entries) {
      if (!ordered.containsKey(entry.key) && entry.value.isNotEmpty) {
        ordered[entry.key] = entry.value;
      }
    }

    return ordered;
  }

  // =========================
  // СТАТИСТИКА ПО КОМАНДЕ
  // =========================

  /// Получить статистику по команде для основного отчета
  Map<String, Map<String, dynamic>> _getTeamMainStats() {
    final stats = <String, Map<String, dynamic>>{};
    
    for (final player in _filteredMainReportRows) {
      final actions = [
        'feint_dribble',
        'shot_on_goal',
        'tackle_duel',
        'interception',
        'recovery',
        'header_play',
        'throw_ins',
        'pass_avp',
      ];
      
      for (final action in actions) {
        final value = player[action] ?? '0/0';
        final parts = value.toString().split('/');
        final success = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
        final fail = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        
        if (!stats.containsKey(action)) {
          stats[action] = {'success': 0, 'fail': 0, 'total': 0};
        }
        
        stats[action]!['success'] = (stats[action]!['success'] ?? 0) + success;
        stats[action]!['fail'] = (stats[action]!['fail'] ?? 0) + fail;
        stats[action]!['total'] = (stats[action]!['success'] ?? 0) + (stats[action]!['fail'] ?? 0);
      }
    }
    
    return stats;
  }

  /// Получить статистику по команде для передач
  Map<String, Map<String, dynamic>> _getTeamPassStats() {
    final stats = <String, Map<String, dynamic>>{};
    
    final passTypes = [
      'forward_short', 'forward_medium', 'forward_long',
      'side_short', 'side_medium', 'side_long',
      'back_short', 'back_medium', 'back_long',
    ];
    
    for (final player in _filteredPassReportRows) {
      for (final passType in passTypes) {
        final value = player[passType] ?? '0/0';
        final parts = value.toString().split('/');
        final success = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
        final fail = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        
        if (!stats.containsKey(passType)) {
          stats[passType] = {'success': 0, 'fail': 0, 'total': 0};
        }
        
        stats[passType]!['success'] = (stats[passType]!['success'] ?? 0) + success;
        stats[passType]!['fail'] = (stats[passType]!['fail'] ?? 0) + fail;
        stats[passType]!['total'] = (stats[passType]!['success'] ?? 0) + (stats[passType]!['fail'] ?? 0);
      }
    }
    
    return stats;
  }

  /// Получить общую эффективность команды по основным действиям
  double _getTeamMainEfficiency() {
    int totalSuccess = 0;
    int totalFail = 0;
    
    for (final player in _filteredMainReportRows) {
      final actions = [
        'feint_dribble', 'shot_on_goal', 'tackle_duel',
        'interception', 'recovery', 'header_play',
        'throw_ins', 'pass_avp',
      ];
      
      for (final action in actions) {
        final value = player[action] ?? '0/0';
        final parts = value.toString().split('/');
        totalSuccess += parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
        totalFail += parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      }
    }
    
    final total = totalSuccess + totalFail;
    if (total == 0) return 0.0;
    return (totalSuccess / total) * 100;
  }

  /// Получить общую эффективность команды по передачам
  double _getTeamPassEfficiency() {
    int totalSuccess = 0;
    int totalFail = 0;
    
    final passTypes = [
      'forward_short', 'forward_medium', 'forward_long',
      'side_short', 'side_medium', 'side_long',
      'back_short', 'back_medium', 'back_long',
    ];
    
    for (final player in _filteredPassReportRows) {
      for (final passType in passTypes) {
        final value = player[passType] ?? '0/0';
        final parts = value.toString().split('/');
        totalSuccess += parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
        totalFail += parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      }
    }
    
    final total = totalSuccess + totalFail;
    if (total == 0) return 0.0;
    return (totalSuccess / total) * 100;
  }

  /// Получить общую эффективность вратарей
  double _getTeamGoalkeeperEfficiency() {
    int totalSuccess = 0;
    int totalFail = 0;
    
    final gkActions = [
      'hand_distribution', 'coming_out', 'close_combat',
      'interceptions', 'outside_box',
      'pass_short', 'pass_medium', 'pass_long',
    ];
    
    for (final gk in _filteredGoalkeeperReportRows) {
      for (final action in gkActions) {
        final value = gk[action] ?? '0/0';
        final parts = value.toString().split('/');
        totalSuccess += parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
        totalFail += parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      }
    }
    
    final total = totalSuccess + totalFail;
    if (total == 0) return 0.0;
    return (totalSuccess / total) * 100;
  }

  // =========================
  // AVATAR
  // =========================

  String? _resolveAvatarUrl(Map<String, dynamic> player) {
    final keys = [
      'avatar',
      'avatar_url',
      'photo',
      'photo_url',
      'image',
      'image_url',
      'player_photo',
      'player_avatar',
      'profile_image',
      'profile_photo',
    ];

    for (final key in keys) {
      final value = player[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  Widget _buildPlayerAvatar(
    Map<String, dynamic> player, {
    double size = 36,
    bool isGoalkeeper = false,
  }) {
    final avatarUrl = _resolveAvatarUrl(player);
    final playerName = (player['player_name'] ?? '').toString().trim();
    final initial = playerName.isNotEmpty ? playerName[0].toUpperCase() : '?';
    final borderRadius = BorderRadius.circular(size * 0.32);

    if (avatarUrl != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: isGoalkeeper
                ? const Color(0xFFDC2626).withOpacity(0.25)
                : const Color(0xFF2563EB).withOpacity(0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackAvatar(
              initial,
              size: size,
              isGoalkeeper: isGoalkeeper,
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _buildFallbackAvatar(
                initial,
                size: size,
                isGoalkeeper: isGoalkeeper,
              );
            },
          ),
        ),
      );
    }

    return _buildFallbackAvatar(
      initial,
      size: size,
      isGoalkeeper: isGoalkeeper,
    );
  }

  Widget _buildFallbackAvatar(
    String initial, {
    required double size,
    bool isGoalkeeper = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGoalkeeper
              ? const [Color(0xFFDC2626), Color(0xFFB91C1C)]
              : [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // =========================
  // БАННЕРЫ
  // =========================

  Widget _buildInfoBanner({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(12),
      decoration: _cmrPanelDecoration(radius: 14, elevated: true),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _cmrPanel,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color.withOpacity(.32), width: 1),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _cmrMutedStyle(11.5, color: _cmrMuted2, weight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Flexible(child: Text(value, style: _cmrTitle(21), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _cmrMutedStyle(11, color: _cmrMuted2, weight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildActionStatsBanner({
    required String title,
    required int success,
    required int fail,
    required Color color,
  }) {
    final total = success + fail;
    final percent = total > 0 ? ((success / total) * 100).round() : 0;

    Widget miniValue(String label, String value, Color valueColor) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: _cmrValue(16, color: valueColor)),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrMutedStyle(10.2, color: _cmrMuted2)),
          ],
        ),
      );
    }

    return Container(
      width: 224,
      padding: const EdgeInsets.all(12),
      decoration: _cmrSoftDecoration(active: true, accent: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrTitle(12.5)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              miniValue('Точные', success.toString(), _cmrGreenDark),
              Container(width: 1, height: 34, color: _cmrLine),
              const SizedBox(width: 10),
              miniValue('Неточные', fail.toString(), _cmrRed),
              Container(width: 1, height: 34, color: _cmrLine),
              const SizedBox(width: 10),
              miniValue('Эфф.', '$percent%', color),
            ],
          ),
        ],
      ),
    );
  }


  // =========================
  // EXPORT
  // =========================

  Future<void> _exportToExcel() async {
    final excelFile = excel.Excel.createExcel();
    excelFile.rename(excelFile.getDefaultSheet()!, 'Отчет');
    final sheetObject = excelFile['Отчет'];

    sheetObject.appendRow(['Технико-тактические действия']);
    sheetObject.appendRow([
      'Игрок',
      'Финт/Дриблинг',
      'Удары',
      'Отбор',
      'Перехват',
      'Подбор',
      'Голова',
      'Ауты',
      'Пас АВП',
      'Всего ТТД',
      '%',
    ]);

    for (final player in _filteredMainReportRows) {
      sheetObject.appendRow([
        player['player_name'] ?? '',
        player['feint_dribble'] ?? '0/0',
        player['shot_on_goal'] ?? '0/0',
        player['tackle_duel'] ?? '0/0',
        player['interception'] ?? '0/0',
        player['recovery'] ?? '0/0',
        player['header_play'] ?? '0/0',
        player['throw_ins'] ?? '0/0',
        player['pass_avp'] ?? '0/0',
        player['ttd_total'] ?? '0/0',
        '${player['effect_percent'] ?? 0}%',
      ]);
    }

    // Добавляем командную статистику
    sheetObject.appendRow([]);
    sheetObject.appendRow(['КОМАНДНАЯ СТАТИСТИКА']);
    sheetObject.appendRow(['Действие', 'Точные', 'Неточные', 'Всего', 'Эффективность']);
    
    final teamStats = _getTeamMainStats();
    final actionNames = {
      'feint_dribble': 'Финт/Дриблинг',
      'shot_on_goal': 'Удары',
      'tackle_duel': 'Отбор',
      'interception': 'Перехват',
      'recovery': 'Подбор',
      'header_play': 'Игра головой',
      'throw_ins': 'Ауты',
      'pass_avp': 'Пас АВП',
    };
    
    for (final entry in teamStats.entries) {
      final success = entry.value['success'] ?? 0;
      final fail = entry.value['fail'] ?? 0;
      final total = success + fail;
      final percent = total > 0 ? ((success / total) * 100).round() : 0;
      
      sheetObject.appendRow([
        actionNames[entry.key] ?? entry.key,
        success,
        fail,
        total,
        '$percent%',
      ]);
    }
    
    sheetObject.appendRow([]);
    sheetObject.appendRow(['Общая эффективность команды: ${_getTeamMainEfficiency().round()}%']);

    sheetObject.appendRow([]);
    sheetObject.appendRow(['Анализ передач']);
    sheetObject.appendRow([
      'Игрок',
      'Вперед К',
      'Вперед С',
      'Вперед Д',
      'Поперек К',
      'Поперек С',
      'Поперек Д',
      'Назад К',
      'Назад С',
      'Назад Д',
      'Всего',
      '%',
    ]);

    for (final player in _filteredPassReportRows) {
      sheetObject.appendRow([
        player['player_name'] ?? '',
        player['forward_short'] ?? '0/0',
        player['forward_medium'] ?? '0/0',
        player['forward_long'] ?? '0/0',
        player['side_short'] ?? '0/0',
        player['side_medium'] ?? '0/0',
        player['side_long'] ?? '0/0',
        player['back_short'] ?? '0/0',
        player['back_medium'] ?? '0/0',
        player['back_long'] ?? '0/0',
        player['total'] ?? '0/0',
        '${player['effect_percent'] ?? 0}%',
      ]);
    }
    
    // Командная статистика передач
    sheetObject.appendRow([]);
    sheetObject.appendRow(['КОМАНДНАЯ СТАТИСТИКА ПЕРЕДАЧ']);
    sheetObject.appendRow(['Направление', 'Дистанция', 'Точные', 'Неточные', 'Всего', 'Эффективность']);
    
    final passStats = _getTeamPassStats();
    final passNames = {
      'forward_short': ['Вперед', 'Короткие'],
      'forward_medium': ['Вперед', 'Средние'],
      'forward_long': ['Вперед', 'Длинные'],
      'side_short': ['Поперек', 'Короткие'],
      'side_medium': ['Поперек', 'Средние'],
      'side_long': ['Поперек', 'Длинные'],
      'back_short': ['Назад', 'Короткие'],
      'back_medium': ['Назад', 'Средние'],
      'back_long': ['Назад', 'Длинные'],
    };
    
    for (final entry in passStats.entries) {
      final success = entry.value['success'] ?? 0;
      final fail = entry.value['fail'] ?? 0;
      final total = success + fail;
      final percent = total > 0 ? ((success / total) * 100).round() : 0;
      final nameInfo = passNames[entry.key] ?? [entry.key, ''];
      
      sheetObject.appendRow([
        nameInfo[0],
        nameInfo[1],
        success,
        fail,
        total,
        '$percent%',
      ]);
    }
    
    sheetObject.appendRow([]);
    sheetObject.appendRow(['Общая эффективность передач: ${_getTeamPassEfficiency().round()}%']);

    sheetObject.appendRow([]);
    sheetObject.appendRow(['Вратарская статистика']);
    sheetObject.appendRow([
      'Игрок',
      'Пропущено',
      'Сейвы',
      'Ввод рукой',
      'Выходы',
      'Бой',
      'Перехваты',
      'За штрафной',
      'Пас К',
      'Пас С',
      'Пас Д',
      'Всего',
      '%',
    ]);

    for (final player in _filteredGoalkeeperReportRows) {
      sheetObject.appendRow([
        player['player_name'] ?? '',
        player['conceded'] ?? 0,
        player['saves'] ?? 0,
        player['hand_distribution'] ?? '0/0',
        player['coming_out'] ?? '0/0',
        player['close_combat'] ?? '0/0',
        player['interceptions'] ?? '0/0',
        player['outside_box'] ?? '0/0',
        player['pass_short'] ?? '0/0',
        player['pass_medium'] ?? '0/0',
        player['pass_long'] ?? '0/0',
        player['ttd_total'] ?? '0/0',
        '${player['effect_percent'] ?? 0}%',
      ]);
    }
    
    sheetObject.appendRow([]);
    sheetObject.appendRow(['Общая эффективность вратарей: ${_getTeamGoalkeeperEfficiency().round()}%']);

    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(path);
    await file.writeAsBytes(excelFile.encode()!);
    await Share.shareXFiles([XFile(path)], text: 'Экспорт отчета');
  }

  Future<void> _exportToPdf() async {
  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    ),
  );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Отчет по ТТД',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          pw.Text(
            'Командная статистика',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Общая эффективность команды: ${_getTeamMainEfficiency().round()}%',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 20),

          pw.Text(
            'Технико-тактические действия',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),

          pw.Table.fromTextArray(
            headers: [
              'Игрок',
              'Финт',
              'Удары',
              'Отбор',
              'Перехват',
              'Подбор',
              'Голова',
              'Ауты',
              'Пас АВП',
              'Всего',
              '%',
            ],
            data: _filteredMainReportRows.map((player) => [
              player['player_name'] ?? '',
              player['feint_dribble'] ?? '0/0',
              player['shot_on_goal'] ?? '0/0',
              player['tackle_duel'] ?? '0/0',
              player['interception'] ?? '0/0',
              player['recovery'] ?? '0/0',
              player['header_play'] ?? '0/0',
              player['throw_ins'] ?? '0/0',
              player['pass_avp'] ?? '0/0',
              player['ttd_total'] ?? '0/0',
              '${player['effect_percent'] ?? 0}%',
            ]).toList(),
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontSize: 9,
            ),
            cellStyle: pw.TextStyle(
              font: regularFont,
              fontSize: 8,
            ),
          ),

          pw.SizedBox(height: 20),
          pw.Text(
            'Анализ передач',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Общая эффективность передач: ${_getTeamPassEfficiency().round()}%',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 10),

          pw.Table.fromTextArray(
            headers: [
              'Игрок',
              'Вперед К',
              'Вперед С',
              'Вперед Д',
              'Поперек К',
              'Поперек С',
              'Поперек Д',
              'Назад К',
              'Назад С',
              'Назад Д',
              'Всего',
              '%',
            ],
            data: _filteredPassReportRows.map((player) => [
              player['player_name'] ?? '',
              player['forward_short'] ?? '0/0',
              player['forward_medium'] ?? '0/0',
              player['forward_long'] ?? '0/0',
              player['side_short'] ?? '0/0',
              player['side_medium'] ?? '0/0',
              player['side_long'] ?? '0/0',
              player['back_short'] ?? '0/0',
              player['back_medium'] ?? '0/0',
              player['back_long'] ?? '0/0',
              player['total'] ?? '0/0',
              '${player['effect_percent'] ?? 0}%',
            ]).toList(),
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontSize: 9,
            ),
            cellStyle: pw.TextStyle(
              font: regularFont,
              fontSize: 8,
            ),
          ),

          pw.SizedBox(height: 20),
          pw.Text(
            'Вратарская статистика',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Общая эффективность вратарей: ${_getTeamGoalkeeperEfficiency().round()}%',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 10),

          pw.Table.fromTextArray(
            headers: [
              'Игрок',
              'Проп.',
              'Сейвы',
              'Ввод рукой',
              'Выходы',
              'Бой',
              'Перехв.',
              'За штраф.',
              'Пас К',
              'Пас С',
              'Пас Д',
              'Всего',
              '%',
            ],
            data: _filteredGoalkeeperReportRows.map((player) => [
              player['player_name'] ?? '',
              player['conceded']?.toString() ?? '0',
              player['saves']?.toString() ?? '0',
              player['hand_distribution'] ?? '0/0',
              player['coming_out'] ?? '0/0',
              player['close_combat'] ?? '0/0',
              player['interceptions'] ?? '0/0',
              player['outside_box'] ?? '0/0',
              player['pass_short'] ?? '0/0',
              player['pass_medium'] ?? '0/0',
              player['pass_long'] ?? '0/0',
              player['ttd_total'] ?? '0/0',
              '${player['effect_percent'] ?? 0}%',
            ]).toList(),
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontSize: 9,
            ),
            cellStyle: pw.TextStyle(
              font: regularFont,
              fontSize: 8,
            ),
          ),
        ];
      },
    ),
  );

  final directory = await getApplicationDocumentsDirectory();
  final path =
      '${directory.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf';

  final file = File(path);
  await file.writeAsBytes(await pdf.save());

  await Share.shareXFiles([XFile(path)], text: 'Экспорт отчета');
}

  void _showExportMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Экспорт отчета',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.table_chart, color: Colors.green.shade700),
              ),
              title: const Text('Экспорт в Excel'),
              subtitle: const Text('Сохранить как таблицу'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.picture_as_pdf, color: Colors.red.shade700),
              ),
              title: const Text('Экспорт в PDF'),
              subtitle: const Text('Сохранить как документ'),
              onTap: () {
                Navigator.pop(context);
                _exportToPdf();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =========================
  // UI HELPERS
  // =========================

  Widget _buildHeaderCell(
    String title,
    double width, {
    bool isLast = false,
    double fontSize = 10,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.only(right: isLast ? 8 : 4, left: 4),
      alignment: Alignment.center,
      child: Text(
        title,
        style: _cmrMutedStyle(fontSize, color: _cmrMuted2, weight: FontWeight.w900),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }


  Widget _buildSectionHeader(
    String title,
    Color color, {
    double fontSize = 16,
    double vertical = 12,
    double horizontal = 16,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      margin: const EdgeInsets.only(bottom: 8, top: 2),
      decoration: BoxDecoration(
        color: _cmrPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cmrLine),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: _cmrTitle(fontSize), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(.22)),
            ),
            child: Text('ГРУППА', style: _cmrMutedStyle(10, color: color, weight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }


  Widget _buildPassHeaderGroup(
    String title,
    double width, {
    double titleFontSize = 11,
    double subFontSize = 10,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: _cmrMutedStyle(titleFontSize, color: _cmrMuted2, weight: FontWeight.w900)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _cmrPanel,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _cmrLine),
            ),
            child: Text('К   С   Д', style: _cmrMutedStyle(subFontSize, color: _cmrMuted2, weight: FontWeight.w900), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }


  Widget _buildPassSectionHeader(
    String title,
    Color color, {
    double fontSize = 12,
    double vertical = 6,
    double horizontal = 10,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 2),
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: _cmrPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cmrLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(title, style: _cmrTitle(fontSize)),
        ],
      ),
    );
  }


  Widget _buildExportButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withOpacity(.08),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: color.withOpacity(.22)),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Text(label, style: _cmrMutedStyle(12.5, color: _cmrText, weight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }




  Widget _buildEmptyTableState({required String title, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: _cmrSoftDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _cmrPanel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cmrLine),
            ),
            child: Icon(icon, color: _cmrMuted2, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _cmrTitle(14)),
                const SizedBox(height: 4),
                Text('Данные появятся после заполнения отчёта по матчу.', style: _cmrMutedStyle(12, color: _cmrMuted2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTableShell({
    required BoxConstraints constraints,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Widget content,
    String? badge,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: _cmrPanelDecoration(radius: 14, elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _cmrPanel,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withOpacity(.38), width: 1),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _cmrTitle(16.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(subtitle, style: _cmrMutedStyle(12, color: _cmrMuted2), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _cmrGreenSoft,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _cmrGreenBorder),
                    ),
                    child: Text(badge, style: _cmrMutedStyle(11.5, color: _cmrGreenDark, weight: FontWeight.w900)),
                  ),
                ],
              ],
            ),
          ),
          Container(height: 1, color: _cmrLine),
          _needsHorizontalScroll(constraints)
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: content)
              : content,
        ],
      ),
    );
  }

  Widget _buildCmrTableHeader({required List<Widget> children, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: _cmrSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cmrLine),
      ),
      child: Row(children: children),
    );
  }

  Widget _buildCmrPercentCell(dynamic value, double width, double fontSize) {
    final percent = value ?? 0;
    final rawColor = Formatters.getEffectColor(percent);
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: rawColor,
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(color: rawColor.withOpacity(.18), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Text(
          '$percent%',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    final teamMainEfficiency = _getTeamMainEfficiency();
    final teamPassEfficiency = _getTeamPassEfficiency();
    final teamGkEfficiency = _getTeamGoalkeeperEfficiency();

    return Container(
      color: _cmrBg,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  if (onBack != null)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      decoration: _cmrPanelDecoration(radius: 12, elevated: true),
                      child: IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded, color: _cmrText),
                        tooltip: 'Назад',
                      ),
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: _cmrPanelDecoration(radius: 12, elevated: true),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildExportButton(icon: Icons.table_chart_rounded, label: 'Excel', color: _cmrGreenDark, onTap: _exportToExcel),
                            Container(height: 28, width: 1, color: _cmrLine),
                            _buildExportButton(icon: Icons.picture_as_pdf_rounded, label: 'PDF', color: _cmrRed, onTap: _exportToPdf),
                            Container(height: 28, width: 1, color: _cmrLine),
                            _buildExportButton(icon: Icons.more_horiz_rounded, label: 'Ещё', color: _cmrGraphite, onTap: () => _showExportMenu(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (reportLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: LinearProgressIndicator(minHeight: 3, color: _cmrGreen),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mobile = constraints.maxWidth < 680;
                  final cards = [
                    _buildInfoBanner(title: 'Эффективность команды', value: '${teamMainEfficiency.round()}%', icon: Icons.analytics_outlined, color: _cmrGreen, subtitle: 'По основным действиям'),
                    _buildInfoBanner(title: 'Точность передач', value: '${teamPassEfficiency.round()}%', icon: Icons.compare_arrows_rounded, color: const Color(0xFF2563EB), subtitle: 'Всего ${_filteredPassReportRows.length} игроков'),
                    _buildInfoBanner(title: 'Эффективность вратарей', value: '${teamGkEfficiency.round()}%', icon: Icons.sports_handball_rounded, color: _cmrRed, subtitle: 'По всем действиям'),
                    _buildInfoBanner(title: 'Всего игроков', value: '${_filteredMainReportRows.length}', icon: Icons.people_outline_rounded, color: _cmrGraphite, subtitle: 'Приняли участие'),
                  ];

                  if (mobile) {
                    return Column(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          cards[i],
                          if (i != cards.length - 1) const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]),
                      const SizedBox(height: 10),
                      Row(children: [Expanded(child: cards[2]), const SizedBox(width: 10), Expanded(child: cards[3])]),
                    ],
                  );
                },
              ),
            ),
            _buildMainReportTable(),
            _buildPassReportTable(),
            _buildGoalkeeperReportTable(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  // =========================
  // MAIN TABLE
  // =========================

  Widget _buildMainReportTable() {
    final teamStats = _getTeamMainStats();

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _tableScale(constraints);
        final tableWidth = _tableWidth(constraints);
        final bool isTablet = _isTablet(constraints);
        final double titleFont = _responsiveFont(constraints, phone: 15.5, tablet: 16.5);
        final double headerFont = _responsiveFont(constraints, phone: 10.5, tablet: 11.2);
        final double nameFont = _responsiveFont(constraints, phone: 13.2, tablet: 14.2);
        final double metricFont = _responsiveFont(constraints, phone: 11, tablet: 12);
        final double percentFont = _responsiveFont(constraints, phone: 12, tablet: 13);
        final EdgeInsets innerPadding = _tableInnerPadding(constraints);
        final double avatarSize = _responsiveAvatar(constraints, phone: 36, tablet: 40);

        final double playerW = playerNameWidth * scale;
        final double gapW = rowGap * scale;
        final double feintW = (metricWidth + 10) * scale;
        final double metricW = metricWidth * scale;
        final double metricSmallW = metricWidthSmall * scale;
        final double totalW = totalWidth * scale;
        final double percentW = percentWidth * scale;
        final grouped = _groupRows(_filteredMainReportRows);

        Widget buildMetricCell(String value, {Color? accent, bool isTotal = false}) {
          final parts = value.split('/');
          final success = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
          final fail = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          final total = success + fail;
          final activeAccent = accent ?? _cmrGreen;

          return Container(
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: _cmrSoftDecoration(active: isTotal, accent: activeAccent),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(success.toString(), style: _cmrValue(metricFont, color: _cmrGreenDark)),
                    Text(' / ', style: _cmrMutedStyle(metricFont - 1, color: _cmrMuted2, weight: FontWeight.w800)),
                    Text(fail.toString(), style: _cmrValue(metricFont, color: _cmrRed)),
                  ],
                ),
                if (total > 0) ...[
                  const SizedBox(height: 2),
                  Text(value, textAlign: TextAlign.center, style: _cmrMutedStyle(metricFont - 1, color: isTotal ? activeAccent : _cmrMuted2, weight: FontWeight.w800)),
                ],
              ],
            ),
          );
        }

        Widget buildPlayerRow(Map<String, dynamic> player, Color groupColor) {
          return Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: _cmrPanelDecoration(radius: 11),
            child: Row(
              children: [
                Container(width: 3, height: isTablet ? 46 : 42, decoration: BoxDecoration(color: groupColor, borderRadius: BorderRadius.circular(99))),
                const SizedBox(width: 8),
                SizedBox(
                  width: math.max(0.0, playerW - 11),
                  child: Row(
                    children: [
                      _buildPlayerAvatar(player, size: avatarSize),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(player['player_name'] ?? 'Неизвестно', style: _cmrTitle(nameFont), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Text('ТТД игрока', style: _cmrMutedStyle(10.5, color: _cmrMuted2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: gapW),
                SizedBox(width: feintW, child: buildMetricCell(player['feint_dribble'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildMetricCell(player['shot_on_goal'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildMetricCell(player['tackle_duel'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildMetricCell(player['interception'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildMetricCell(player['recovery'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildMetricCell(player['header_play'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricSmallW, child: buildMetricCell(player['throw_ins'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildMetricCell(player['pass_avp'] ?? '0/0', accent: groupColor)),
                SizedBox(width: totalW, child: buildMetricCell(player['ttd_total'] ?? '0/0', accent: groupColor, isTotal: true)),
                _buildCmrPercentCell(player['effect_percent'] ?? 0, percentW, percentFont),
              ],
            ),
          );
        }

        final content = Padding(
          padding: innerPadding,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCmrTableHeader(
                  children: [
                    SizedBox(width: playerW, child: Padding(padding: const EdgeInsets.only(left: 8), child: Text('Игрок', style: _cmrMutedStyle(headerFont + 1, color: _cmrMuted2, weight: FontWeight.w900)))),
                    SizedBox(width: gapW),
                    _buildHeaderCell('Финт+\nДриблинг', feintW, fontSize: headerFont),
                    _buildHeaderCell('Удары', metricW, fontSize: headerFont),
                    _buildHeaderCell('Отбор', metricW, fontSize: headerFont),
                    _buildHeaderCell('Перехват', metricW, fontSize: headerFont),
                    _buildHeaderCell('Подбор', metricW, fontSize: headerFont),
                    _buildHeaderCell('Голова', metricW, fontSize: headerFont),
                    _buildHeaderCell('Ауты', metricSmallW, fontSize: headerFont),
                    _buildHeaderCell('Пас АВП', metricW, fontSize: headerFont),
                    _buildHeaderCell('Всего\nТТД', totalW, fontSize: headerFont),
                    _buildHeaderCell('%', percentW, isLast: true, fontSize: headerFont),
                  ],
                ),
                const SizedBox(height: 10),
                if (grouped.isEmpty)
                  _buildEmptyTableState(title: 'Нет данных по ТТД', icon: Icons.sports_soccer_rounded)
                else
                  for (final entry in grouped.entries) ...[
                    _buildSectionHeader(_groupTitle(entry.key), _groupColor(entry.key), fontSize: isTablet ? 15.5 : 14.5, vertical: isTablet ? 10 : 9, horizontal: isTablet ? 12 : 10),
                    ...entry.value.map((player) => buildPlayerRow(player, _groupColor(entry.key))),
                    const SizedBox(height: 6),
                  ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _cmrSoftDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(width: 30, height: 30, decoration: BoxDecoration(color: _cmrPanel, borderRadius: BorderRadius.circular(9), border: Border.all(color: _cmrGreen.withOpacity(.35))), child: const Icon(Icons.people_outline_rounded, color: _cmrGreen, size: 17)),
                        const SizedBox(width: 10),
                        Text('Статистика команды', style: _cmrTitle(titleFont)),
                      ]),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildActionStatsBanner(title: 'Финт / Дриблинг', success: teamStats['feint_dribble']?['success'] ?? 0, fail: teamStats['feint_dribble']?['fail'] ?? 0, color: _cmrGreen),
                          _buildActionStatsBanner(title: 'Удары', success: teamStats['shot_on_goal']?['success'] ?? 0, fail: teamStats['shot_on_goal']?['fail'] ?? 0, color: const Color(0xFF2563EB)),
                          _buildActionStatsBanner(title: 'Отбор', success: teamStats['tackle_duel']?['success'] ?? 0, fail: teamStats['tackle_duel']?['fail'] ?? 0, color: _cmrRed),
                          _buildActionStatsBanner(title: 'Перехват', success: teamStats['interception']?['success'] ?? 0, fail: teamStats['interception']?['fail'] ?? 0, color: const Color(0xFF7C3AED)),
                          _buildActionStatsBanner(title: 'Подбор', success: teamStats['recovery']?['success'] ?? 0, fail: teamStats['recovery']?['fail'] ?? 0, color: const Color(0xFFEA580C)),
                          _buildActionStatsBanner(title: 'Игра головой', success: teamStats['header_play']?['success'] ?? 0, fail: teamStats['header_play']?['fail'] ?? 0, color: const Color(0xFF8B5CF6)),
                          _buildActionStatsBanner(title: 'Ауты', success: teamStats['throw_ins']?['success'] ?? 0, fail: teamStats['throw_ins']?['fail'] ?? 0, color: const Color(0xFFEC4899)),
                          _buildActionStatsBanner(title: 'Пас АВП', success: teamStats['pass_avp']?['success'] ?? 0, fail: teamStats['pass_avp']?['fail'] ?? 0, color: const Color(0xFF14B8A6)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        return _buildReportTableShell(
          constraints: constraints,
          title: 'Технико-тактические действия',
          subtitle: 'Профессиональная таблица действий игроков и эффективности',
          icon: Icons.sports_soccer_rounded,
          accent: _cmrGreen,
          badge: '${_getTeamMainEfficiency().round()}% командно',
          content: content,
        );
      },
    );
  }


  // =========================
  // PASS TABLE
  // =========================

  Widget _buildPassReportTable() {
    final passStats = _getTeamPassStats();

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _tableScale(constraints);
        final tableWidth = _tableWidth(constraints);
        final bool isTablet = _isTablet(constraints);
        final double titleFont = _responsiveFont(constraints, phone: 15.5, tablet: 16.5);
        final double headerFont = _responsiveFont(constraints, phone: 10.5, tablet: 11.5);
        final double subHeaderFont = _responsiveFont(constraints, phone: 9.5, tablet: 10.5);
        final double nameFont = _responsiveFont(constraints, phone: 13, tablet: 14);
        final double metricFont = _responsiveFont(constraints, phone: 10.5, tablet: 11.3);
        final double percentFont = _responsiveFont(constraints, phone: 12, tablet: 13);
        final EdgeInsets innerPadding = _tableInnerPadding(constraints);
        final double avatarSize = _responsiveAvatar(constraints, phone: 34, tablet: 38);

        final double playerW = passPlayerWidth * scale;
        final double gapW = rowGap * scale;
        final double metricW = passMetricWidth * scale;
        final double totalW = passTotalWidth * scale;
        final double percentW = passPercentWidth * scale;
        final grouped = _groupRows(_filteredPassReportRows);

        Widget buildPassCell(String value, {Color? accent, bool isTotal = false}) {
          final parts = value.split('/');
          final success = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
          final fail = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          final activeAccent = accent ?? const Color(0xFF2563EB);

          return Container(
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: _cmrSoftDecoration(active: isTotal, accent: activeAccent),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(success.toString(), style: _cmrValue(metricFont, color: _cmrGreenDark)),
                  Text('/', style: _cmrMutedStyle(metricFont - 1, color: _cmrMuted2, weight: FontWeight.w800)),
                  Text(fail.toString(), style: _cmrValue(metricFont, color: _cmrRed)),
                ]),
                const SizedBox(height: 2),
                Text(value, style: _cmrMutedStyle(metricFont - 1, color: isTotal ? activeAccent : _cmrMuted2, weight: FontWeight.w800)),
              ],
            ),
          );
        }

        Widget buildPlayerRow(Map<String, dynamic> player, Color groupColor) {
          return Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: _cmrPanelDecoration(radius: 11),
            child: Row(
              children: [
                Container(width: 3, height: isTablet ? 44 : 40, decoration: BoxDecoration(color: groupColor, borderRadius: BorderRadius.circular(99))),
                const SizedBox(width: 8),
                SizedBox(
                  width: math.max(0.0, playerW - 11),
                  child: Row(children: [
                    _buildPlayerAvatar(player, size: avatarSize),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(player['player_name'] ?? 'Неизвестно', style: _cmrTitle(nameFont), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text('Передачи: К / С / Д', style: _cmrMutedStyle(10.5, color: _cmrMuted2)),
                    ])),
                  ]),
                ),
                SizedBox(width: gapW),
                SizedBox(width: metricW, child: buildPassCell(player['forward_short'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildPassCell(player['forward_medium'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildPassCell(player['forward_long'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildPassCell(player['side_short'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildPassCell(player['side_medium'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildPassCell(player['side_long'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildPassCell(player['back_short'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildPassCell(player['back_medium'] ?? '0/0', accent: groupColor)),
                SizedBox(width: metricW, child: buildPassCell(player['back_long'] ?? '0/0', accent: groupColor)),
                SizedBox(width: totalW, child: buildPassCell(player['total'] ?? '0/0', accent: groupColor, isTotal: true)),
                _buildCmrPercentCell(player['effect_percent'] ?? 0, percentW, percentFont),
              ],
            ),
          );
        }

        final content = Padding(
          padding: innerPadding,
          child: SizedBox(
            width: tableWidth,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildCmrTableHeader(children: [
                SizedBox(width: playerW, child: Padding(padding: const EdgeInsets.only(left: 8), child: Text('Игрок', style: _cmrMutedStyle(headerFont + 1, color: _cmrMuted2, weight: FontWeight.w900)))),
                SizedBox(width: gapW),
                _buildPassHeaderGroup('Вперед', metricW * 3, titleFontSize: headerFont, subFontSize: subHeaderFont),
                _buildPassHeaderGroup('Поперек', metricW * 3, titleFontSize: headerFont, subFontSize: subHeaderFont),
                _buildPassHeaderGroup('Назад', metricW * 3, titleFontSize: headerFont, subFontSize: subHeaderFont),
                _buildHeaderCell('Всего', totalW, fontSize: headerFont),
                _buildHeaderCell('Эфф.', percentW, isLast: true, fontSize: headerFont),
              ]),
              const SizedBox(height: 10),
              if (grouped.isEmpty)
                _buildEmptyTableState(title: 'Нет данных по передачам', icon: Icons.compare_arrows_rounded)
              else
                for (final entry in grouped.entries) ...[
                  _buildPassSectionHeader(_groupTitle(entry.key), _groupColor(entry.key), fontSize: isTablet ? 13 : 12.5, vertical: isTablet ? 8 : 7, horizontal: isTablet ? 11 : 10),
                  ...entry.value.map((player) => buildPlayerRow(player, _groupColor(entry.key))),
                  const SizedBox(height: 6),
                ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _cmrSoftDecoration(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 30, height: 30, decoration: BoxDecoration(color: _cmrPanel, borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFF2563EB).withOpacity(.32))), child: const Icon(Icons.compare_arrows_rounded, color: Color(0xFF2563EB), size: 17)),
                    const SizedBox(width: 10),
                    Text('Статистика передач команды', style: _cmrTitle(titleFont)),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _buildActionStatsBanner(title: 'Вперед К', success: passStats['forward_short']?['success'] ?? 0, fail: passStats['forward_short']?['fail'] ?? 0, color: const Color(0xFF2563EB)),
                    _buildActionStatsBanner(title: 'Вперед С', success: passStats['forward_medium']?['success'] ?? 0, fail: passStats['forward_medium']?['fail'] ?? 0, color: const Color(0xFF3B82F6)),
                    _buildActionStatsBanner(title: 'Вперед Д', success: passStats['forward_long']?['success'] ?? 0, fail: passStats['forward_long']?['fail'] ?? 0, color: const Color(0xFF60A5FA)),
                    _buildActionStatsBanner(title: 'Поперек К', success: passStats['side_short']?['success'] ?? 0, fail: passStats['side_short']?['fail'] ?? 0, color: _cmrGreen),
                    _buildActionStatsBanner(title: 'Поперек С', success: passStats['side_medium']?['success'] ?? 0, fail: passStats['side_medium']?['fail'] ?? 0, color: const Color(0xFF10B981)),
                    _buildActionStatsBanner(title: 'Поперек Д', success: passStats['side_long']?['success'] ?? 0, fail: passStats['side_long']?['fail'] ?? 0, color: const Color(0xFF34D399)),
                    _buildActionStatsBanner(title: 'Назад К', success: passStats['back_short']?['success'] ?? 0, fail: passStats['back_short']?['fail'] ?? 0, color: _cmrRed),
                    _buildActionStatsBanner(title: 'Назад С', success: passStats['back_medium']?['success'] ?? 0, fail: passStats['back_medium']?['fail'] ?? 0, color: const Color(0xFFEF4444)),
                    _buildActionStatsBanner(title: 'Назад Д', success: passStats['back_long']?['success'] ?? 0, fail: passStats['back_long']?['fail'] ?? 0, color: const Color(0xFFF87171)),
                  ]),
                ]),
              ),
            ]),
          ),
        );

        return _buildReportTableShell(
          constraints: constraints,
          title: 'Анализ передач',
          subtitle: 'Направление, дистанция и точность передач по игрокам',
          icon: Icons.compare_arrows_rounded,
          accent: const Color(0xFF2563EB),
          badge: '${_getTeamPassEfficiency().round()}% точность',
          content: content,
        );
      },
    );
  }


  // =========================
  // GOALKEEPER TABLE
  // =========================

  Widget _buildGoalkeeperReportTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _tableScale(constraints);
        final tableWidth = _tableWidth(constraints);
        final bool isTablet = _isTablet(constraints);
        final double headerFont = _responsiveFont(constraints, phone: 10.5, tablet: 11.5);
        final double nameFont = _responsiveFont(constraints, phone: 13, tablet: 14);
        final double metricMainFont = _responsiveFont(constraints, phone: 10.5, tablet: 11.5);
        final double metricSubFont = _responsiveFont(constraints, phone: 9, tablet: 9.8);
        final double percentFont = _responsiveFont(constraints, phone: 12, tablet: 13);
        final EdgeInsets innerPadding = _tableInnerPadding(constraints);
        final double avatarSize = _responsiveAvatar(constraints, phone: 34, tablet: 38);

        final double playerW = playerNameWidthSmall * scale;
        final double gapW = rowGap * scale;
        final double metricSmallW = metricWidthSmall * scale;
        final double metricW = metricWidth * scale;
        final double outsideW = (metricWidth + 10) * scale;
        final double passW = (metricWidth * 1.5) * scale;
        final double totalW = totalWidth * scale;
        final double percentW = percentWidth * scale;
        final goalkeepers = _reportRowsByGroup(_filteredGoalkeeperReportRows, 'gk');

        Widget buildGkCell(dynamic value, {bool isTotal = false}) {
          if (value is String && value.contains('/')) {
            final parts = value.split('/');
            final success = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
            final fail = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

            return Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: _cmrSoftDecoration(active: isTotal, accent: _cmrRed),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(success.toString(), style: _cmrValue(metricMainFont, color: _cmrGreenDark)),
                  Text('/', style: _cmrMutedStyle(metricMainFont - 1, color: _cmrMuted2, weight: FontWeight.w800)),
                  Text(fail.toString(), style: _cmrValue(metricMainFont, color: _cmrRed)),
                ]),
                const SizedBox(height: 2),
                Text(value, style: _cmrMutedStyle(metricSubFont, color: isTotal ? _cmrRed : _cmrMuted2, weight: FontWeight.w800)),
              ]),
            );
          }

          return Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: _cmrSoftDecoration(),
            child: Center(child: Text(value.toString(), textAlign: TextAlign.center, style: _cmrValue(metricMainFont))),
          );
        }

        Widget headerText(String text, double width, {TextAlign align = TextAlign.center}) {
          return SizedBox(width: width, child: Text(text, textAlign: align, maxLines: 2, overflow: TextOverflow.ellipsis, style: _cmrMutedStyle(headerFont, color: _cmrMuted2, weight: FontWeight.w900)));
        }

        final content = Padding(
          padding: innerPadding,
          child: SizedBox(
            width: tableWidth,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildCmrTableHeader(children: [
                SizedBox(width: playerW, child: Padding(padding: const EdgeInsets.only(left: 8), child: Text('Игрок', style: _cmrMutedStyle(headerFont + 1, color: _cmrMuted2, weight: FontWeight.w900)))),
                SizedBox(width: gapW),
                headerText('Проп.', metricSmallW),
                headerText('Сейвы', metricSmallW),
                headerText('Ввод\nрук.', metricW),
                headerText('Выходы', metricW),
                headerText('Бой', metricSmallW),
                headerText('Перехв.', metricSmallW),
                headerText('За штраф.', outsideW),
                headerText('Передачи', passW),
                headerText('Всего', totalW),
                headerText('Эфф.', percentW),
              ]),
              const SizedBox(height: 10),
              if (goalkeepers.isEmpty)
                _buildEmptyTableState(title: 'Нет данных по вратарям', icon: Icons.sports_handball_rounded)
              else ...[
                _buildSectionHeader('Вратари', _cmrRed, fontSize: isTablet ? 15.5 : 14.5, vertical: isTablet ? 10 : 9, horizontal: isTablet ? 12 : 10),
                ...goalkeepers.map((gk) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: _cmrPanelDecoration(radius: 11),
                    child: Row(children: [
                      Container(width: 3, height: isTablet ? 44 : 40, decoration: BoxDecoration(color: _cmrRed, borderRadius: BorderRadius.circular(99))),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: math.max(0.0, playerW - 11),
                        child: Row(children: [
                          _buildPlayerAvatar(gk, size: avatarSize, isGoalkeeper: true),
                          const SizedBox(width: 9),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(gk['player_name'] ?? 'Неизвестно', style: _cmrTitle(nameFont), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Text('Вратарская линия', style: _cmrMutedStyle(10.5, color: _cmrMuted2)),
                          ])),
                        ]),
                      ),
                      SizedBox(width: gapW),
                      SizedBox(width: metricSmallW, child: buildGkCell(gk['conceded'] ?? 0)),
                      SizedBox(width: metricSmallW, child: buildGkCell(gk['saves'] ?? 0)),
                      SizedBox(width: metricW, child: buildGkCell(gk['hand_distribution'] ?? '0/0')),
                      SizedBox(width: metricW, child: buildGkCell(gk['coming_out'] ?? '0/0')),
                      SizedBox(width: metricSmallW, child: buildGkCell(gk['close_combat'] ?? '0/0')),
                      SizedBox(width: metricSmallW, child: buildGkCell(gk['interceptions'] ?? '0/0')),
                      SizedBox(width: outsideW, child: buildGkCell(gk['outside_box'] ?? '0/0')),
                      SizedBox(width: passW, child: Row(children: [
                        Expanded(child: buildGkCell(gk['pass_short'] ?? '0/0')),
                        const SizedBox(width: 2),
                        Expanded(child: buildGkCell(gk['pass_medium'] ?? '0/0')),
                        const SizedBox(width: 2),
                        Expanded(child: buildGkCell(gk['pass_long'] ?? '0/0')),
                      ])),
                      SizedBox(width: totalW, child: buildGkCell(gk['ttd_total'] ?? '0/0', isTotal: true)),
                      _buildCmrPercentCell(gk['effect_percent'] ?? 0, percentW, percentFont),
                    ]),
                  );
                }),
              ],
            ]),
          ),
        );

        return _buildReportTableShell(
          constraints: constraints,
          title: 'Вратарская статистика',
          subtitle: 'Сейвы, ввод мяча, выходы и передачи вратарей',
          icon: Icons.sports_handball_rounded,
          accent: _cmrRed,
          badge: '${_getTeamGoalkeeperEfficiency().round()}% эффективно',
          content: content,
        );
      },
    );
  }

}