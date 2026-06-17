import 'package:flutter/material.dart';

class TtdMetric {
  final String code;
  final String title;
  final Color color;
  final bool singleOnly;

  const TtdMetric({
    required this.code,
    required this.title,
    required this.color,
    this.singleOnly = false,
  });
}

// Основные ТТД
const List<TtdMetric> mainTtd = [
  TtdMetric(code: "feint_dribble", title: "Финт+обводка / Дриблинг", color: Color(0xFF7C3AED)),
  TtdMetric(code: "shot_on_goal", title: "Удары в ворота", color: Color(0xFFF59E0B)),
  TtdMetric(code: "tackle_duel", title: "Отбор / единоборства", color: Color(0xFF059669)),
  TtdMetric(code: "interception_ball", title: "Перехват мяча", color: Color(0xFF0891B2)),
  TtdMetric(code: "recovery_ball", title: "Подбор мяча", color: Color(0xFF10B981)),
  TtdMetric(code: "header_play", title: "Игра головой", color: Color(0xFF84CC16)),
  TtdMetric(code: "throw_ins", title: "Ауты", color: Color(0xFFF97316)),
  TtdMetric(code: "pass_avp", title: "Пас в АВП", color: Color(0xFF2563EB)),
];

// Передачи
const List<TtdMetric> passTtd = [
  TtdMetric(code: "pass_forward_short", title: "Вперёд • К", color: Color(0xFF2563EB)),
  TtdMetric(code: "pass_forward_medium", title: "Вперёд • С", color: Color(0xFF3B82F6)),
  TtdMetric(code: "pass_forward_long", title: "Вперёд • Д", color: Color(0xFF60A5FA)),
  TtdMetric(code: "pass_side_short", title: "Поперёк • К", color: Color(0xFF0EA5E9)),
  TtdMetric(code: "pass_side_medium", title: "Поперёк • С", color: Color(0xFF06B6D4)),
  TtdMetric(code: "pass_side_long", title: "Поперёк • Д", color: Color(0xFF22D3EE)),
  TtdMetric(code: "pass_back_short", title: "Назад • К", color: Color(0xFF14B8A6)),
  TtdMetric(code: "pass_back_medium", title: "Назад • С", color: Color(0xFF10B981)),
  TtdMetric(code: "pass_back_long", title: "Назад • Д", color: Color(0xFF34D399)),
];

// Вратарские
const List<TtdMetric> goalkeeperTtd = [
  TtdMetric(code: "gk_conceded", title: "Пропущен. голы", color: Color(0xFFDC2626), singleOnly: true),
  TtdMetric(code: "gk_saves", title: "Сейвы", color: Color(0xFFF59E0B), singleOnly: true),
  TtdMetric(code: "gk_hand_distribution", title: "Ввод мяча рукой", color: Color(0xFF2563EB)),
  TtdMetric(code: "gk_coming_out", title: "Игра на выходах", color: Color(0xFF7C3AED)),
  TtdMetric(code: "gk_close_combat", title: "Ближний бой", color: Color(0xFF0EA5E9)),
  TtdMetric(code: "gk_interceptions", title: "Перехваты", color: Color(0xFF0891B2)),
  TtdMetric(code: "gk_outside_box", title: "За пределами штрафной", color: Color(0xFF16A34A)),
  TtdMetric(code: "gk_pass_short", title: "Передачи • К", color: Color(0xFF14B8A6)),
  TtdMetric(code: "gk_pass_medium", title: "Передачи • С", color: Color(0xFF10B981)),
  TtdMetric(code: "gk_pass_long", title: "Передачи • Д", color: Color(0xFF84CC16)),
];

// Типы событий
const List<Map<String, dynamic>> eventTypes = [
  {"code": "goal", "title": "Гол", "positive": true, "icon": Icons.sports_soccer, "color": Color(0xFF16A34A)},
  {"code": "assist", "title": "Голевая", "positive": true, "icon": Icons.assistant_direction, "color": Color(0xFF2563EB)},
  {"code": "shot_on_goal", "title": "Удар", "positive": true, "icon": Icons.ads_click, "color": Color(0xFF0EA5E9)},
  {"code": "pass_avp", "title": "Пас в АВП", "positive": true, "icon": Icons.compare_arrows_rounded, "color": Color(0xFF2563EB)},
  {"code": "tackle_duel", "title": "Отбор", "positive": true, "icon": Icons.shield_outlined, "color": Color(0xFF059669)},
  {"code": "mistake", "title": "Ошибка", "positive": false, "icon": Icons.error_outline, "color": Color(0xFFDC2626)},
];

// Вспомогательные функции для работы с ТТД
class TtdHelpers {
  static String getEventTypeTitle(String code) {
    for (final e in eventTypes) {
      if (e["code"] == code) return e["title"].toString();
    }
    for (final e in mainTtd) {
      if (e.code == code) return e.title;
    }
    for (final e in passTtd) {
      if (e.code == code) return e.title;
    }
    for (final e in goalkeeperTtd) {
      if (e.code == code) return e.title;
    }
    return code;
  }

  static List<TtdMetric> getTtdListBySection(String section) {
    switch (section) {
      case 'passes':
        return passTtd;
      case 'gk':
        return goalkeeperTtd;
      default:
        return mainTtd;
    }
  }

  static IconData getIconForCode(String code) {
    if (code.contains('pass')) return Icons.compare_arrows_rounded;
    if (code.contains('shot') || code.contains('goal')) return Icons.sports_soccer;
    if (code.contains('tackle') || code.contains('duel')) return Icons.shield_outlined;
    if (code.contains('interception')) return Icons.timeline_outlined;
    if (code.contains('recovery')) return Icons.restart_alt_rounded;
    if (code.contains('header')) return Icons.sports_mma;
    if (code.contains('throw')) return Icons.sports_handball;
    if (code.contains('gk')) return Icons.sports_handball;
    if (code.contains('feint') || code.contains('dribble')) return Icons.swap_horiz_rounded;
    return Icons.circle_outlined;
  }
}