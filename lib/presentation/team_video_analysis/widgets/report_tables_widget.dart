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
    return math.max(0, constraints.maxWidth - 24);
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
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
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      success.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const Text(
                      'Точные',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      fail.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const Text(
                      'Неточные',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const Text(
                      'Эффективность',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
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
      padding: EdgeInsets.only(right: isLast ? 8 : 4),
      alignment: Alignment.center,
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          height: 1.2,
        ),
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
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
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: titleFontSize,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "К   С   Д",
            style: TextStyle(
              fontSize: subFontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
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
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
        ),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
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
    
    return SingleChildScrollView(
      child: Column(
        children: [
            Padding(
  padding: const EdgeInsets.all(16),
  child: Row(
    children: [
      if (onBack != null)
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF2563EB),
            ),
            tooltip: 'Назад',
          ),
        ),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildExportButton(
                  icon: Icons.table_chart,
                  label: 'Excel',
                  color: Colors.green,
                  onTap: _exportToExcel,
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.grey.shade200,
                ),
                _buildExportButton(
                  icon: Icons.picture_as_pdf,
                  label: 'PDF',
                  color: Colors.red,
                  onTap: _exportToPdf,
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.grey.shade200,
                ),
                _buildExportButton(
                  icon: Icons.more_horiz,
                  label: 'Ещё',
                  color: const Color(0xFF2563EB),
                  onTap: () => _showExportMenu(context),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
),
          if (reportLoading) const LinearProgressIndicator(minHeight: 4),
          
          // Баннеры командной статистики
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoBanner(
                        title: 'Эффективность команды',
                        value: '${teamMainEfficiency.round()}%',
                        icon: Icons.analytics_outlined,
                        color: const Color(0xFF2563EB),
                        subtitle: 'По основным действиям',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoBanner(
                        title: 'Точность передач',
                        value: '${teamPassEfficiency.round()}%',
                        icon: Icons.compare_arrows_rounded,
                        color: const Color(0xFF7C3AED),
                        subtitle: 'Всего ${_filteredPassReportRows.length} игроков',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoBanner(
                        title: 'Эффективность вратарей',
                        value: '${teamGkEfficiency.round()}%',
                        icon: Icons.sports_handball,
                        color: const Color(0xFFDC2626),
                        subtitle: 'По всем действиям',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoBanner(
                        title: 'Всего игроков',
                        value: '${_filteredMainReportRows.length}',
                        icon: Icons.people_outline_rounded,
                        color: const Color(0xFFF59E0B),
                        subtitle: 'Приняли участие',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          _buildMainReportTable(),
          const SizedBox(height: 16),
          _buildPassReportTable(),
          const SizedBox(height: 16),
          _buildGoalkeeperReportTable(),
          const SizedBox(height: 20),
        ],
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
        final double titleFont = _responsiveFont(
          constraints,
          phone: 16,
          tablet: 18,
        );
        final double subTitleFont = _responsiveFont(
          constraints,
          phone: 12,
          tablet: 13,
        );
        final double headerFont = _responsiveFont(
          constraints,
          phone: 10,
          tablet: 11.5,
        );
        final double nameFont = _responsiveFont(
          constraints,
          phone: 14,
          tablet: 15.5,
        );
        final double metricFont = _responsiveFont(
          constraints,
          phone: 11,
          tablet: 12.5,
        );
        final double totalMetricFont = _responsiveFont(
          constraints,
          phone: 13,
          tablet: 14,
        );
        final double percentFont = _responsiveFont(
          constraints,
          phone: 13,
          tablet: 14,
        );
        final EdgeInsets innerPadding = _tableInnerPadding(constraints);

        final double avatarSize = _responsiveAvatar(
          constraints,
          phone: 36,
          tablet: 42,
        );

        final double playerW = playerNameWidth * scale;
        final double gapW = rowGap * scale;
        final double feintW = (metricWidth + 10) * scale;
        final double metricW = metricWidth * scale;
        final double metricSmallW = metricWidthSmall * scale;
        final double totalW = totalWidth * scale;
        final double percentW = percentWidth * scale;

        final grouped = _groupRows(_filteredMainReportRows);

        Widget buildMetricCell(String value, {Color? color, bool isTotal = false}) {
          final parts = value.split('/');
          final success = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
          final fail = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          final total = success + fail;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: color ?? Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isTotal
                    ? const Color(0xFF2563EB).withOpacity(0.3)
                    : Colors.grey.shade200,
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (total > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        success.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        fail.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isTotal ? totalMetricFont : metricFont,
                    fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                    color: isTotal ? const Color(0xFF2563EB) : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          );
        }

        Widget buildPlayerRow(Map<String, dynamic> player) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: playerW,
                  child: Row(
                    children: [
                      _buildPlayerAvatar(player, size: avatarSize),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          player['player_name'] ?? 'Неизвестно',
                          style: TextStyle(
                            fontSize: nameFont,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: gapW),
                SizedBox(width: feintW, child: buildMetricCell(player['feint_dribble'] ?? '0/0')),
                SizedBox(width: metricW, child: buildMetricCell(player['shot_on_goal'] ?? '0/0')),
                SizedBox(width: metricW, child: buildMetricCell(player['tackle_duel'] ?? '0/0')),
                SizedBox(width: metricW, child: buildMetricCell(player['interception'] ?? '0/0')),
                SizedBox(width: metricW, child: buildMetricCell(player['recovery'] ?? '0/0')),
                SizedBox(width: metricW, child: buildMetricCell(player['header_play'] ?? '0/0')),
                SizedBox(width: metricSmallW, child: buildMetricCell(player['throw_ins'] ?? '0/0')),
                SizedBox(width: metricW, child: buildMetricCell(player['pass_avp'] ?? '0/0')),
                SizedBox(
                  width: totalW,
                  child: buildMetricCell(player['ttd_total'] ?? '0/0', isTotal: true),
                ),
                Container(
                  width: percentW,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: Formatters.getEffectColor(player['effect_percent'] ?? 0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${player['effect_percent'] ?? 0}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: percentFont,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
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
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: playerW,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            "Игрок",
                            style: TextStyle(
                              fontSize: isTablet ? 13 : 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      _buildHeaderCell("Финт+\nДриблинг", feintW, fontSize: headerFont),
                      _buildHeaderCell("Удары", metricW, fontSize: headerFont),
                      _buildHeaderCell("Отбор", metricW, fontSize: headerFont),
                      _buildHeaderCell("Перехват", metricW, fontSize: headerFont),
                      _buildHeaderCell("Подбор", metricW, fontSize: headerFont),
                      _buildHeaderCell("Голова", metricW, fontSize: headerFont),
                      _buildHeaderCell("Ауты", metricSmallW, fontSize: headerFont),
                      _buildHeaderCell("Пас АВП", metricW, fontSize: headerFont),
                      _buildHeaderCell("Всего\nТТД", totalW, fontSize: headerFont),
                      _buildHeaderCell("%", percentW, isLast: true, fontSize: headerFont),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in grouped.entries) ...[
                  _buildSectionHeader(
                    _groupTitle(entry.key),
                    _groupColor(entry.key),
                    fontSize: isTablet ? 17 : 16,
                    vertical: isTablet ? 14 : 12,
                    horizontal: isTablet ? 18 : 16,
                  ),
                  ...entry.value.map(buildPlayerRow),
                  const SizedBox(height: 12),
                ],
                
                // Командная статистика
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people_outline, color: const Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Статистика команды',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildActionStatsBanner(
                            title: 'Финт / Дриблинг',
                            success: teamStats['feint_dribble']?['success'] ?? 0,
                            fail: teamStats['feint_dribble']?['fail'] ?? 0,
                            color: const Color(0xFF2563EB),
                          ),
                          _buildActionStatsBanner(
                            title: 'Удары',
                            success: teamStats['shot_on_goal']?['success'] ?? 0,
                            fail: teamStats['shot_on_goal']?['fail'] ?? 0,
                            color: const Color(0xFF059669),
                          ),
                          _buildActionStatsBanner(
                            title: 'Отбор',
                            success: teamStats['tackle_duel']?['success'] ?? 0,
                            fail: teamStats['tackle_duel']?['fail'] ?? 0,
                            color: const Color(0xFFDC2626),
                          ),
                          _buildActionStatsBanner(
                            title: 'Перехват',
                            success: teamStats['interception']?['success'] ?? 0,
                            fail: teamStats['interception']?['fail'] ?? 0,
                            color: const Color(0xFF7C3AED),
                          ),
                          _buildActionStatsBanner(
                            title: 'Подбор',
                            success: teamStats['recovery']?['success'] ?? 0,
                            fail: teamStats['recovery']?['fail'] ?? 0,
                            color: const Color(0xFFF59E0B),
                          ),
                          _buildActionStatsBanner(
                            title: 'Игра головой',
                            success: teamStats['header_play']?['success'] ?? 0,
                            fail: teamStats['header_play']?['fail'] ?? 0,
                            color: const Color(0xFF8B5CF6),
                          ),
                          _buildActionStatsBanner(
                            title: 'Ауты',
                            success: teamStats['throw_ins']?['success'] ?? 0,
                            fail: teamStats['throw_ins']?['fail'] ?? 0,
                            color: const Color(0xFFEC489A),
                          ),
                          _buildActionStatsBanner(
                            title: 'Пас АВП',
                            success: teamStats['pass_avp']?['success'] ?? 0,
                            fail: teamStats['pass_avp']?['fail'] ?? 0,
                            color: const Color(0xFF14B8A6),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sports_soccer,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Технико-тактические действия",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleFont,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "С выявлением процента эффективности",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: subTitleFont,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _needsHorizontalScroll(constraints)
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: content,
                    )
                  : content,
            ],
          ),
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
        final double titleFont = _responsiveFont(
          constraints,
          phone: 16,
          tablet: 18,
        );
        final double subTitleFont = _responsiveFont(
          constraints,
          phone: 12,
          tablet: 13,
        );
        final double headerFont = _responsiveFont(
          constraints,
          phone: 11,
          tablet: 12,
        );
        final double subHeaderFont = _responsiveFont(
          constraints,
          phone: 10,
          tablet: 11,
        );
        final double nameFont = _responsiveFont(
          constraints,
          phone: 12,
          tablet: 13.5,
        );
        final double metricFont = _responsiveFont(
          constraints,
          phone: 9,
          tablet: 10,
        );
        final double metricMainFont = _responsiveFont(
          constraints,
          phone: 11,
          tablet: 12,
        );
        final double percentFont = _responsiveFont(
          constraints,
          phone: 11,
          tablet: 12.5,
        );
        final EdgeInsets innerPadding = _tableInnerPadding(constraints);

        final double avatarSize = _responsiveAvatar(
          constraints,
          phone: 32,
          tablet: 38,
        );

        final double playerW = passPlayerWidth * scale;
        final double gapW = rowGap * scale;
        final double metricW = passMetricWidth * scale;
        final double totalW = passTotalWidth * scale;
        final double percentW = passPercentWidth * scale;

        final grouped = _groupRows(_filteredPassReportRows);

        Widget buildPassCell(String value, {bool isTotal = false}) {
          final parts = value.split('/');
          final success = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
          final fail = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: isTotal
                  ? const Color(0xFF7C3AED).withOpacity(0.10)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isTotal
                    ? const Color(0xFF7C3AED).withOpacity(0.22)
                    : Colors.grey.shade200,
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      success.toString(),
                      style: TextStyle(
                        fontSize: metricMainFont,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    const Text("/", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      fail.toString(),
                      style: TextStyle(
                        fontSize: metricMainFont,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: metricFont,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        Widget buildPlayerRow(Map<String, dynamic> player) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: playerW,
                  child: Row(
                    children: [
                      _buildPlayerAvatar(player, size: avatarSize),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          player['player_name'] ?? 'Неизвестно',
                          style: TextStyle(
                            fontSize: nameFont,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: gapW),
                SizedBox(width: metricW, child: buildPassCell(player['forward_short'] ?? '0/0')),
                SizedBox(width: metricW, child: buildPassCell(player['forward_medium'] ?? '0/0')),
                SizedBox(width: metricW, child: buildPassCell(player['forward_long'] ?? '0/0')),
                SizedBox(width: metricW, child: buildPassCell(player['side_short'] ?? '0/0')),
                SizedBox(width: metricW, child: buildPassCell(player['side_medium'] ?? '0/0')),
                SizedBox(width: metricW, child: buildPassCell(player['side_long'] ?? '0/0')),
                SizedBox(width: metricW, child: buildPassCell(player['back_short'] ?? '0/0')),
                SizedBox(width: metricW, child: buildPassCell(player['back_medium'] ?? '0/0')),
                SizedBox(width: metricW, child: buildPassCell(player['back_long'] ?? '0/0')),
                SizedBox(width: totalW, child: buildPassCell(player['total'] ?? '0/0', isTotal: true)),
                SizedBox(
                  width: percentW,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: Formatters.getEffectColor(player['effect_percent'] ?? 0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${player['effect_percent'] ?? 0}%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: percentFont,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
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
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: playerW,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            "Игрок",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isTablet ? 13 : 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: gapW),
                      _buildPassHeaderGroup(
                        "Вперед",
                        metricW * 3,
                        titleFontSize: headerFont,
                        subFontSize: subHeaderFont,
                      ),
                      _buildPassHeaderGroup(
                        "Поперек",
                        metricW * 3,
                        titleFontSize: headerFont,
                        subFontSize: subHeaderFont,
                      ),
                      _buildPassHeaderGroup(
                        "Назад",
                        metricW * 3,
                        titleFontSize: headerFont,
                        subFontSize: subHeaderFont,
                      ),
                      SizedBox(
                        width: totalW,
                        child: Text(
                          "Всего",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: headerFont,
                            color: const Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: percentW,
                        child: Text(
                          "Эфф.",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: headerFont,
                            color: const Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in grouped.entries) ...[
                  _buildPassSectionHeader(
                    _groupTitle(entry.key),
                    _groupColor(entry.key),
                    fontSize: isTablet ? 13 : 12,
                    vertical: isTablet ? 7 : 6,
                    horizontal: isTablet ? 12 : 10,
                  ),
                  ...entry.value.map(buildPlayerRow),
                  const SizedBox(height: 12),
                ],
                
                // Командная статистика передач
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.compare_arrows, color: const Color(0xFF7C3AED), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Статистика передач команды',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildActionStatsBanner(
                            title: 'Вперед К',
                            success: passStats['forward_short']?['success'] ?? 0,
                            fail: passStats['forward_short']?['fail'] ?? 0,
                            color: const Color(0xFF2563EB),
                          ),
                          _buildActionStatsBanner(
                            title: 'Вперед С',
                            success: passStats['forward_medium']?['success'] ?? 0,
                            fail: passStats['forward_medium']?['fail'] ?? 0,
                            color: const Color(0xFF3B82F6),
                          ),
                          _buildActionStatsBanner(
                            title: 'Вперед Д',
                            success: passStats['forward_long']?['success'] ?? 0,
                            fail: passStats['forward_long']?['fail'] ?? 0,
                            color: const Color(0xFF60A5FA),
                          ),
                          _buildActionStatsBanner(
                            title: 'Поперек К',
                            success: passStats['side_short']?['success'] ?? 0,
                            fail: passStats['side_short']?['fail'] ?? 0,
                            color: const Color(0xFF059669),
                          ),
                          _buildActionStatsBanner(
                            title: 'Поперек С',
                            success: passStats['side_medium']?['success'] ?? 0,
                            fail: passStats['side_medium']?['fail'] ?? 0,
                            color: const Color(0xFF10B981),
                          ),
                          _buildActionStatsBanner(
                            title: 'Поперек Д',
                            success: passStats['side_long']?['success'] ?? 0,
                            fail: passStats['side_long']?['fail'] ?? 0,
                            color: const Color(0xFF34D399),
                          ),
                          _buildActionStatsBanner(
                            title: 'Назад К',
                            success: passStats['back_short']?['success'] ?? 0,
                            fail: passStats['back_short']?['fail'] ?? 0,
                            color: const Color(0xFFDC2626),
                          ),
                          _buildActionStatsBanner(
                            title: 'Назад С',
                            success: passStats['back_medium']?['success'] ?? 0,
                            fail: passStats['back_medium']?['fail'] ?? 0,
                            color: const Color(0xFFEF4444),
                          ),
                          _buildActionStatsBanner(
                            title: 'Назад Д',
                            success: passStats['back_long']?['success'] ?? 0,
                            fail: passStats['back_long']?['fail'] ?? 0,
                            color: const Color(0xFFF87171),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF7C3AED),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.compare_arrows,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Анализ передач",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleFont,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Детальная статистика",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: subTitleFont,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _needsHorizontalScroll(constraints)
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: content,
                    )
                  : content,
            ],
          ),
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
        final double titleFont = _responsiveFont(
          constraints,
          phone: 16,
          tablet: 18,
        );
        final double subTitleFont = _responsiveFont(
          constraints,
          phone: 12,
          tablet: 13,
        );
        final double headerFont = _responsiveFont(
          constraints,
          phone: 11,
          tablet: 12,
        );
        final double nameFont = _responsiveFont(
          constraints,
          phone: 12,
          tablet: 13.5,
        );
        final double metricMainFont = _responsiveFont(
          constraints,
          phone: 11,
          tablet: 12,
        );
        final double metricSubFont = _responsiveFont(
          constraints,
          phone: 9,
          tablet: 10,
        );
        final double percentFont = _responsiveFont(
          constraints,
          phone: 11,
          tablet: 12.5,
        );
        final EdgeInsets innerPadding = _tableInnerPadding(constraints);

        final double avatarSize = _responsiveAvatar(
          constraints,
          phone: 28,
          tablet: 34,
        );

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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isTotal
                    ? const Color(0xFFDC2626).withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        success.toString(),
                        style: TextStyle(
                          fontSize: metricMainFont,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                      const Text("/", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        fail.toString(),
                        style: TextStyle(
                          fontSize: metricMainFont,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: metricSubFont,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: metricMainFont,
                fontWeight: FontWeight.w700,
              ),
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
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: playerW,
                        child: Text(
                          "Игрок",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFont,
                          ),
                        ),
                      ),
                      SizedBox(width: gapW),
                      SizedBox(
                        width: metricSmallW,
                        child: Text(
                          "Проп.",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFont,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: metricSmallW,
                        child: Text(
                          "Сейвы",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFont,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: metricW,
                        child: Text(
                          "Ввод\nрук.",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFont,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: metricW,
                        child: Text(
                          "Выходы",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFont,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: metricSmallW,
                        child: Text(
                          "Бой",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFont,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: metricSmallW,
                        child: Text(
                          "Перехв.",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFont,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: outsideW,
                        child: Text(
                          "За штраф.",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFont,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: passW,
                        child: Text(
                          "Передачи",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFont,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: totalW,
                        child: Text(
                          "Всего",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFont,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: percentW,
                        child: Text(
                          "Эфф.",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFont,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                ...goalkeepers.map((gk) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: playerW,
                          child: Row(
                            children: [
                              _buildPlayerAvatar(
                                gk,
                                size: avatarSize,
                                isGoalkeeper: true,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  gk['player_name'] ?? 'Неизвестно',
                                  style: TextStyle(
                                    fontSize: nameFont,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: gapW),
                        SizedBox(width: metricSmallW, child: buildGkCell(gk['conceded'] ?? 0)),
                        SizedBox(width: metricSmallW, child: buildGkCell(gk['saves'] ?? 0)),
                        SizedBox(width: metricW, child: buildGkCell(gk['hand_distribution'] ?? '0/0')),
                        SizedBox(width: metricW, child: buildGkCell(gk['coming_out'] ?? '0/0')),
                        SizedBox(width: metricSmallW, child: buildGkCell(gk['close_combat'] ?? '0/0')),
                        SizedBox(width: metricSmallW, child: buildGkCell(gk['interceptions'] ?? '0/0')),
                        SizedBox(width: outsideW, child: buildGkCell(gk['outside_box'] ?? '0/0')),
                        SizedBox(
                          width: passW,
                          child: Row(
                            children: [
                              Expanded(child: buildGkCell(gk['pass_short'] ?? '0/0')),
                              const SizedBox(width: 1),
                              Expanded(child: buildGkCell(gk['pass_medium'] ?? '0/0')),
                              const SizedBox(width: 1),
                              Expanded(child: buildGkCell(gk['pass_long'] ?? '0/0')),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: totalW,
                          child: buildGkCell(gk['ttd_total'] ?? '0/0', isTotal: true),
                        ),
                        SizedBox(
                          width: percentW,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              color: Formatters.getEffectColor(gk['effect_percent'] ?? 0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${gk['effect_percent'] ?? 0}%',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: percentFont,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );

        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sports_handball,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Вратарская статистика",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleFont,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Детальный анализ действий вратарей",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: subTitleFont,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _needsHorizontalScroll(constraints)
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: content,
                    )
                  : content,
            ],
          ),
        );
      },
    );
  }
}