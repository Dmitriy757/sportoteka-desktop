// lib/presentation/team_matches_screen/cmr_team_matches_panel.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_matches_screen/team_match_detail_screen.dart';

// ==================== Цветовая схема (унифицирована) ====================

class _CmrMatchColors {
  // Windows 11 / Fluent Premium: светлая база, графит и 3–4 спокойных акцента.
  // Цветные элементы оставляем для статусов, активных состояний и главных действий.
  static const Color ink = Color(0xFF0B0F14);
  static const Color ink2 = Color(0xFF111827);
  static const Color inkSoft = Color(0xFF1F2937);
  static const Color iconSoft2 = Color(0xFFF8F9FA);

  static const Color panel = Colors.white;
  static const Color workspace = Colors.white;
  static const Color surface = Color(0xFFFAFBFC);
  static const Color soft = Color(0xFFF6F7F9);
  static const Color soft2 = Color(0xFFF5F7FB);
  static const Color border = Color(0xFFF0F2F4);
  static const Color borderStrong = Color(0xFFE5E7EB);

  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF374151);
  static const Color muted2 = Color(0xFF6B7280);

  static const Color icon = Color(0xFF344054);
  static const Color iconSoft = Color(0xFFF2F4F7);
  static const Color iconBorder = Color(0xFFE6EAF0);

  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color greenSoft2 = Color(0xFFF8FEFA);
  static const Color greenBorder = Color(0xFFDCEFE5);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanSoft = Color(0xFFEFFBFF);
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetSoft = Color(0xFFF5F0FF);
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkSoft = Color(0xFFFFF1F8);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color mint = Color(0xFF10B981);

  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEF2F2);
  static const Color redBorder = Color(0xFFF7C8C4);
  static const Color glass = Color(0xF8FFFFFF);
}

Color _matchWinAccent(int index) {
  const colors = <Color>[
    _CmrMatchColors.green,
    _CmrMatchColors.blue,
    _CmrMatchColors.cyan,
    _CmrMatchColors.violet,
    _CmrMatchColors.pink,
    _CmrMatchColors.amber,
  ];
  return colors[index.abs() % colors.length];
}

Color _matchWinAccentSoft(int index) {
  const colors = <Color>[
    _CmrMatchColors.greenSoft,
    _CmrMatchColors.blueSoft,
    _CmrMatchColors.cyanSoft,
    _CmrMatchColors.violetSoft,
    _CmrMatchColors.pinkSoft,
    _CmrMatchColors.amberSoft,
  ];
  return colors[index.abs() % colors.length];
}

// ==================== Текстовые стили ====================

class _CmrMatchText {
  // Windows 11 / Fluent typography.
  static const String font = 'Segoe UI';
  static const List<String> fallback = <String>[
    'SF Pro Display',
    'SF Pro Text',
    'Inter',
    'Roboto',
    'Arial',
  ];

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required Color color,
    double height = 1.18,
    double letterSpacing = -0.10,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontFamily: font,
      fontFamilyFallback: fallback,
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: features,
    );
  }

  static TextStyle title(double size) => _base(
        size: size,
        weight: FontWeight.w700,
        color: _CmrMatchColors.text,
        height: 1.08,
        letterSpacing: -0.38,
      );

  static TextStyle section() => _base(
        size: 13.4,
        weight: FontWeight.w700,
        color: _CmrMatchColors.text,
        height: 1.12,
        letterSpacing: -0.22,
      );

  static TextStyle value(double size) => _base(
        size: size,
        weight: FontWeight.w700,
        color: _CmrMatchColors.text,
        height: 1.08,
        letterSpacing: -0.28,
        features: const [FontFeature.tabularFigures()],
      );

  static TextStyle muted(double size) => _base(
        size: size,
        weight: FontWeight.w500,
        color: _CmrMatchColors.muted,
        height: 1.34,
        letterSpacing: -0.05,
      );

  static TextStyle caption() => _base(
        size: 10.8,
        weight: FontWeight.w600,
        color: _CmrMatchColors.muted2,
        height: 1.08,
        letterSpacing: .08,
      );

  static TextStyle pill({Color? color}) => _base(
        size: 11.2,
        weight: FontWeight.w700,
        color: color ?? _CmrMatchColors.text,
        height: 1.05,
      );

  static TextStyle tab({bool active = false}) => _base(
        size: 11.8,
        weight: FontWeight.w700,
        color: active ? _CmrMatchColors.greenDark : _CmrMatchColors.text,
        height: 1,
      );

  static TextStyle tabSelected() => tab(active: true);

  static TextStyle action() => _base(
        size: 11.8,
        weight: FontWeight.w700,
        color: _CmrMatchColors.text,
        height: 1.05,
      );

  static TextStyle whiteAction({double size = 11.8}) => _base(
        size: size,
        weight: FontWeight.w700,
        color: Colors.white,
        height: 1.05,
      );

  static TextStyle danger() => _base(
        size: 11.8,
        weight: FontWeight.w700,
        color: _CmrMatchColors.red,
        height: 1,
      );
}

// ==================== Декораторы ====================


class _CmrMatchDecor {
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.045),
          blurRadius: 34,
          spreadRadius: -14,
          offset: const Offset(0, 20),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(.025),
          blurRadius: 10,
          spreadRadius: -7,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get microShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 18,
          spreadRadius: -12,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get panelShadow => softShadow;

  static BoxDecoration workspaceBg() => const BoxDecoration(
        color: Color(0xFFF6F7F9),
      );

  static BoxDecoration panel({double radius = 22}) => BoxDecoration(
        color: _CmrMatchColors.panel,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: softShadow,
      );

  static BoxDecoration unifiedWindow({double radius = 24}) => BoxDecoration(
        color: _CmrMatchColors.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(.86), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 38,
            spreadRadius: -18,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: _CmrMatchColors.blue.withOpacity(.035),
            blurRadius: 24,
            spreadRadius: -18,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration seamlessPane({double radius = 0}) => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration fluentSurface({
    double radius = 16,
    Color accent = _CmrMatchColors.green,
    bool active = false,
    bool elevated = true,
  }) {
    return BoxDecoration(
      color: active ? Colors.white.withOpacity(.96) : Colors.white.withOpacity(.82),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: active ? Color.alphaBlend(accent.withOpacity(.18), Colors.white) : Colors.white.withOpacity(.78),
        width: 1,
      ),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(active ? .040 : .025),
                blurRadius: active ? 20 : 14,
                spreadRadius: -12,
                offset: Offset(0, active ? 12 : 8),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration softCard({double radius = 18, bool active = false, Color? tint}) => BoxDecoration(
        color: active ? Colors.white.withOpacity(.96) : (tint ?? _CmrMatchColors.surface),
        borderRadius: BorderRadius.circular(radius),
        border: active ? Border.all(color: _CmrMatchColors.greenBorder) : null,
        boxShadow: active ? microShadow : null,
      );

  static BoxDecoration accentCard({required Color color, double radius = 18}) => BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(.08), Colors.white),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Color.alphaBlend(color.withOpacity(.16), Colors.white)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.08),
            blurRadius: 22,
            spreadRadius: -13,
            offset: const Offset(0, 12),
          ),
        ],
      );

  static BoxDecoration glassCard({double radius = 22, Color? tint}) => BoxDecoration(
        color: tint ?? Colors.white.withOpacity(.72),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: null,
      );
}

// ==================== Основной виджет ====================

enum CmrMatchesFilter { all, upcoming, past }
enum CmrMatchKindFilter { all, tournament, friendly, home, away }
enum _MatchesWorkPanel { list, details, editor }

class CmrTeamMatchesPanel extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;

  const CmrTeamMatchesPanel({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<CmrTeamMatchesPanel> createState() => _CmrTeamMatchesPanelState();
}

class _CmrTeamMatchesPanelState extends State<CmrTeamMatchesPanel> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getUrl = '$apiBase/get_team_matches.php';
  static const String addUrl = '$apiBase/add_team_match.php';
  static const String deleteUrl = '$apiBase/delete_team_match.php';
  static const String getUserUrl = '$apiBase/get_user.php';

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  bool loading = true;
  bool refreshing = false;
  String? error;

  int userId = 0;
  String role = '';
  CmrMatchesFilter filter = CmrMatchesFilter.all;
  CmrMatchKindFilter matchKindFilter = CmrMatchKindFilter.all;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? selectedDay;
  int openingMatchId = 0;
  int selectedMatchId = 0;
  int calendarRevision = 0;
  _MatchesWorkPanel _workPanel = _MatchesWorkPanel.list;

  List<Map<String, dynamic>> matches = [];

  bool get canEdit => role.toLowerCase().trim() != 'player';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    userId = await PrefUtils.getUserId() ?? 0;
    role = userId > 0 ? await _fetchRoleByUser(userId) : '';
    await _fetch(initial: true);
  }

  Future<String> _fetchRoleByUser(int uid) async {
    try {
      final res = await http.get(Uri.parse('$getUserUrl?user_id=$uid')).timeout(const Duration(seconds: 15));
      final data = _decodeJsonMap(res.body);
      final ok = data['success'] == true || data['status'] == 'success';
      if (!ok) return '';
      final user = data['user'];
      if (user is Map) return (user['role'] ?? '').toString().trim().toLowerCase();
    } catch (_) {}
    return '';
  }

  Future<void> _fetch({bool initial = false}) async {
    if (!mounted) return;
    setState(() {
      if (initial) {
        loading = true;
      } else {
        refreshing = true;
      }
      error = null;
    });

    try {
      final res = await http.post(
        Uri.parse(getUrl),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'team_id': widget.teamId}),
      ).timeout(const Duration(seconds: 20));

      final data = _decodeJsonMap(res.body);
      final ok = data['status'] == 'success' || data['success'] == true;
      if (!ok) throw Exception(data['message']?.toString() ?? 'Не удалось загрузить матчи');

      final list = (data['matches'] as List?) ?? [];
      final parsed = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      parsed.sort((a, b) => _parseDate(_s(a['match_date'])).compareTo(_parseDate(_s(b['match_date']))));

      if (!mounted) return;
      setState(() {
        matches = parsed;

        final hasSelectedMatch = selectedMatchId > 0 && parsed.any((m) => _matchId(m) == selectedMatchId);
        if (!hasSelectedMatch) {
          selectedMatchId = parsed.isEmpty ? 0 : _matchId(parsed.last);
        }

        if (initial || !_hasMatchesInMonth(parsed, selectedMonth)) {
          selectedMonth = _bestMonthForMatches(parsed);
          selectedDay = null;
          filter = CmrMatchesFilter.all;
          calendarRevision++;
        }

        loading = false;
        refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        refreshing = false;
        error = e.toString();
      });
    }
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    final raw = body.trim();
    final start = raw.indexOf('{');
    if (start < 0) throw Exception('Сервер вернул некорректный ответ');
    final decoded = jsonDecode(raw.substring(start));
    if (decoded is! Map) throw Exception('Некорректный формат ответа API');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _openCreate() async {
    if (!canEdit) return;
    if (widget.teamId <= 0) {
      Get.snackbar('Ошибка', 'Не удалось определить team_id');
      return;
    }

    final width = MediaQuery.maybeOf(context)?.size.width ?? 1000;
    if (width >= 600) {
      setState(() => _workPanel = _MatchesWorkPanel.editor);
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CmrAddMatchSheet(onSubmit: _addMatch),
    );

    if (created == true) {
      await _fetch();
      Get.snackbar('Готово', 'Матч добавлен');
    }
  }

  void _closeWorkPanel() {
    setState(() => _workPanel = _MatchesWorkPanel.list);
  }

  Future<void> _handleInlineMatchSaved() async {
    await _fetch();
    if (!mounted) return;
    setState(() => _workPanel = _MatchesWorkPanel.list);
    Get.snackbar('Готово', 'Матч добавлен');
  }

  Future<bool> _addMatch({
    required String eventType,
    required String opponent,
    required String ourScore,
    required String opponentScore,
    required String matchDate,
    required String competitionName,
    required String tourLabel,
    required String stadium,
    required String referees,
    required String notes,
  }) async {
    if (!canEdit) return false;
    if (opponent.trim().isEmpty || matchDate.trim().isEmpty) {
      Get.snackbar('Ошибка', 'Укажите соперника и дату матча');
      return false;
    }

    try {
      final res = await http.post(
        Uri.parse(addUrl),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'team_id': widget.teamId,
          'team_name': widget.teamName.trim().isEmpty ? 'Команда #${widget.teamId}' : widget.teamName,
          'event_type': eventType,
          'opponent': opponent.trim(),
          'our_score': int.tryParse(ourScore.trim()) ?? 0,
          'opponent_score': int.tryParse(opponentScore.trim()) ?? 0,
          'match_date': matchDate,
          'competition_name': competitionName.trim(),
          'tour_label': tourLabel.trim(),
          'stadium': stadium.trim(),
          'referees': referees.trim(),
          'notes': notes.trim(),
        }),
      ).timeout(const Duration(seconds: 20));

      final data = _decodeJsonMap(res.body);
      final ok = data['status'] == 'success' || data['success'] == true;
      if (!ok) {
        Get.snackbar('Ошибка', data['message']?.toString() ?? 'Не удалось добавить матч');
        return false;
      }
      return true;
    } catch (e) {
      Get.snackbar('Ошибка', 'Проверь API add_team_match.php');
      return false;
    }
  }

  Future<void> _deleteMatch(Map<String, dynamic> match) async {
    if (!canEdit) return;
    final id = _i(match['id']);
    if (id <= 0) return;

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Удалить матч?'),
        content: Text('Матч с ${_s(match['opponent']).isEmpty ? 'соперником' : _s(match['opponent'])} будет удалён.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: _CmrMatchColors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final res = await http.post(Uri.parse(deleteUrl), body: {
        'id': id.toString(),
        'team_id': widget.teamId.toString(),
      }).timeout(const Duration(seconds: 20));

      final data = _decodeJsonMap(res.body);
      final success = data['status'] == 'success' || data['success'] == true;
      if (!success) throw Exception(data['message']?.toString() ?? 'Не удалось удалить матч');
      await _fetch();
      Get.snackbar('Готово', 'Матч удалён');
    } catch (e) {
      Get.snackbar('Ошибка', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _openDetails(Map<String, dynamic> match) async {
    final id = _i(match['id'] ?? match['match_id']);
    if (id <= 0 || openingMatchId != 0) return;

    if (mounted) setState(() => openingMatchId = id);

    try {
      // Детальный разбор матча больше не открываем через Get.to().
      // Он должен появляться как независимое CMR-окно поверх списка матчей.
      showTeamMatchDetailCmrWindow(
        context,
        matchId: id,
        teamId: widget.teamId,
        teamName: widget.teamName,
        clubId: widget.clubId,
        clubName: widget.clubName,
        initialMatch: Map<String, dynamic>.from(match),
        onClosed: () {
          if (mounted) _fetch();
        },
      );
    } finally {
      if (mounted) setState(() => openingMatchId = 0);
    }
  }

  Future<void> _handleMatchTap(Map<String, dynamic> match) async {
    final id = _matchId(match);
    if (id <= 0) return;

    final d = _parseDate(_s(match['match_date'] ?? match['date'] ?? match['start_at']));
    if (mounted) {
      setState(() {
        selectedMatchId = id;
        selectedDay = DateTime(d.year, d.month, d.day);
        selectedMonth = DateTime(d.year, d.month, 1);
        calendarRevision++;
      });
    }

    await _openDetails(match);
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() {});
    });
  }

  String _s(dynamic v) => (v ?? '').toString().trim();
  int _i(dynamic v) => int.tryParse((v ?? '').toString()) ?? 0;
  int _matchId(Map<String, dynamic> m) => _i(m['match_id'] ?? m['id']);

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthTitleLower(DateTime d) {
    const months = ['январь', 'февраль', 'март', 'апрель', 'май', 'июнь', 'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'];
    return '${months[d.month - 1]} ${d.year}';
  }

  Color _softFor(Color color) => Color.alphaBlend(color.withOpacity(.065), Colors.white);

  String _matchVideoUrl(Map<String, dynamic> m) => _s(m['video_url'] ?? m['video'] ?? m['video_path'] ?? m['match_video_url']);

  bool _hasMatchTtd(Map<String, dynamic> m) {
    final direct = _s(m['ttd_text'] ?? m['ttd'] ?? m['ttd_report'] ?? m['auto_ttd']);
    final flag = _s(m['has_ttd'] ?? m['ttd_exists']).toLowerCase();
    return direct.isNotEmpty || flag == '1' || flag == 'true' || flag == 'yes';
  }

  String _matchCoachComment(Map<String, dynamic> m) => _s(m['notes'] ?? m['coach_comment'] ?? m['comment'] ?? m['trainer_comment']);

  Color _matchResultColor(Map<String, dynamic> m) {
    final ourRaw = _s(m['our_score']);
    final oppRaw = _s(m['opponent_score']);
    if (ourRaw.isEmpty && oppRaw.isEmpty) return _CmrMatchColors.muted;
    final our = _i(ourRaw);
    final opp = _i(oppRaw);
    if (our > opp) return _CmrMatchColors.green;
    if (our == opp) return const Color(0xFFF59E0B);
    return _CmrMatchColors.red;
  }

  String _matchResultLabel(Map<String, dynamic> m) {
    final ourRaw = _s(m['our_score']);
    final oppRaw = _s(m['opponent_score']);
    if (ourRaw.isEmpty && oppRaw.isEmpty) return 'Без счёта';
    final our = _i(ourRaw);
    final opp = _i(oppRaw);
    if (our > opp) return 'Победа';
    if (our == opp) return 'Ничья';
    return 'Поражение';
  }

  void _selectMatchForPane(Map<String, dynamic> match) {
    final d = _parseDate(_s(match['match_date'] ?? match['date'] ?? match['start_at']));
    setState(() {
      selectedMatchId = _matchId(match);
      selectedDay = DateTime(d.year, d.month, d.day);
      selectedMonth = DateTime(d.year, d.month, 1);
      _workPanel = _MatchesWorkPanel.details;
      calendarRevision++;
    });
  }

  DateTime _parseDate(String s) {
    try {
      final t = s.trim();
      if (t.contains('.')) {
        final p = t.split('.');
        if (p.length == 3) return DateTime(int.tryParse(p[2]) ?? 2000, int.tryParse(p[1]) ?? 1, int.tryParse(p[0]) ?? 1);
      }
      final d = DateTime.tryParse(t);
      if (d != null) return DateTime(d.year, d.month, d.day);
    } catch (_) {}
    return DateTime(2000, 1, 1);
  }

  String _dateRu(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  bool _isUpcoming(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !d.isBefore(today);
  }

  String _eventTypeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'championship':
        return 'Чемпионат';
      case 'friendly':
        return 'Товарищеский';
      case 'tournament':
        return 'Турнир';
      default:
        return raw.isEmpty ? 'Матч' : raw;
    }
  }

  List<Map<String, dynamic>> _matchesForDay(DateTime day) {
    return matches.where((m) {
      final d = _parseDate(_s(m['match_date'] ?? m['date'] ?? m['start_at']));
      return _sameDay(d, day);
    }).toList();
  }

  Iterable<Map<String, dynamic>> _applyKindFilter(Iterable<Map<String, dynamic>> source) {
    switch (matchKindFilter) {
      case CmrMatchKindFilter.tournament:
        return source.where(_isTournamentMatch);
      case CmrMatchKindFilter.friendly:
        return source.where(_isFriendlyMatch);
      case CmrMatchKindFilter.home:
        return source.where(_isHomeMatch);
      case CmrMatchKindFilter.away:
        return source.where(_isAwayMatch);
      case CmrMatchKindFilter.all:
        return source;
    }
  }

  bool _isTournamentMatch(Map<String, dynamic> m) {
    final raw = '${_s(m['event_type'])} ${_s(m['competition_name'])} ${_s(m['tournament'])}'.toLowerCase();
    if (raw.contains('friendly') || raw.contains('товарищ')) return false;
    return raw.contains('tournament') ||
        raw.contains('championship') ||
        raw.contains('league') ||
        raw.contains('cup') ||
        raw.contains('турнир') ||
        raw.contains('чемпион') ||
        raw.contains('кубок') ||
        _s(m['competition_name']).isNotEmpty;
  }

  bool _isFriendlyMatch(Map<String, dynamic> m) {
    final raw = '${_s(m['event_type'])} ${_s(m['competition_name'])}'.toLowerCase();
    return raw.contains('friendly') || raw.contains('товарищ');
  }

  bool _isHomeMatch(Map<String, dynamic> m) {
    final raw = '${_s(m['home_away'])} ${_s(m['venue_type'])} ${_s(m['place_type'])} ${_s(m['is_home'])}'.toLowerCase();
    return raw == '1' || raw == 'true' || raw.contains('home') || raw.contains('дома');
  }

  bool _isAwayMatch(Map<String, dynamic> m) {
    final raw = '${_s(m['home_away'])} ${_s(m['venue_type'])} ${_s(m['place_type'])} ${_s(m['is_away'])}'.toLowerCase();
    return raw == '1' || raw == 'true' || raw.contains('away') || raw.contains('guest') || raw.contains('гости') || raw.contains('в гостях');
  }

  List<Map<String, dynamic>> _visibleMatches() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final first = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    Iterable<Map<String, dynamic>> list = matches.where((m) {
      final d = _parseDate(_s(m['match_date']));
      return !d.isBefore(first) && d.isBefore(next);
    });

    list = _applyKindFilter(list);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (filter == CmrMatchesFilter.upcoming) {
      list = list.where((m) => !_parseDate(_s(m['match_date'])).isBefore(today));
    } else if (filter == CmrMatchesFilter.past) {
      list = list.where((m) => _parseDate(_s(m['match_date'])).isBefore(today));
    }

    if (q.isNotEmpty) {
      list = list.where((m) {
        final text = '${_s(m['opponent'])} ${_s(m['match_date'])} ${_s(m['event_type'])} ${_s(m['competition_name'])} ${_s(m['stadium'])}'.toLowerCase();
        return text.contains(q);
      });
    }

    final out = list.toList();
    out.sort((a, b) => _parseDate(_s(a['match_date'])).compareTo(_parseDate(_s(b['match_date']))));
    return out;
  }

  List<Map<String, dynamic>> _profileVisibleMatches() {
    final q = _searchCtrl.text.trim().toLowerCase();
    Iterable<Map<String, dynamic>> list = matches;

    final first = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    list = list.where((m) {
      final d = _parseDate(_s(m['match_date'] ?? m['date'] ?? m['start_at']));
      return !d.isBefore(first) && d.isBefore(next);
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (selectedDay != null) {
      list = list.where((m) => _sameDay(_parseDate(_s(m['match_date'] ?? m['date'] ?? m['start_at'])), selectedDay!));
    } else if (filter == CmrMatchesFilter.upcoming) {
      list = list.where((m) => !_parseDate(_s(m['match_date'])).isBefore(today));
    } else if (filter == CmrMatchesFilter.past) {
      list = list.where((m) => _parseDate(_s(m['match_date'])).isBefore(today));
    }

    list = _applyKindFilter(list);

    if (q.isNotEmpty) {
      list = list.where((m) {
        final text = '${_s(m['opponent'])} ${_s(m['match_date'])} ${_s(m['event_type'])} ${_s(m['competition_name'])} ${_s(m['stadium'])}'.toLowerCase();
        return text.contains(q);
      });
    }

    final out = list.toList();
    out.sort((a, b) => _parseDate(_s(a['match_date'])).compareTo(_parseDate(_s(b['match_date']))));
    return out;
  }

  String _scoreText(Map<String, dynamic> m) {
    final ourRaw = _s(m['our_score']);
    final oppRaw = _s(m['opponent_score']);
    final our = _i(ourRaw);
    final opp = _i(oppRaw);
    final d = _parseDate(_s(m['match_date'] ?? m['date'] ?? m['start_at']));
    if ((ourRaw.isEmpty && oppRaw.isEmpty) || (_isUpcoming(d) && our == 0 && opp == 0)) return '–:–';
    return '$our:$opp';
  }

  bool _scoreIsEmpty(Map<String, dynamic> m) => _scoreText(m) == '–:–';

  String _matchTimeText(Map<String, dynamic> m) {
    final direct = _s(m['match_time'] ?? m['time'] ?? m['start_time'] ?? m['kickoff_time']);
    if (direct.isNotEmpty) {
      final normalized = direct.length >= 5 ? direct.substring(0, 5) : direct;
      return normalized;
    }
    final rawDate = _s(m['match_date'] ?? m['date'] ?? m['start_at']);
    final parsed = DateTime.tryParse(rawDate);
    if (parsed != null && (parsed.hour != 0 || parsed.minute != 0)) {
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  String _matchTypeText(Map<String, dynamic> m) {
    final raw = _s(m['event_type']).toLowerCase();
    if (raw.contains('friendly') || raw.contains('товарищ')) return 'Товарищеский';
    if (raw.contains('tournament') || raw.contains('championship') || raw.contains('cup') || raw.contains('турнир') || raw.contains('чемпион') || raw.contains('кубок')) return 'Турнирный';
    if (_s(m['competition_name']).isNotEmpty) return 'Турнирный';
    return _eventTypeLabel(_s(m['event_type']));
  }

  String _matchDisplayStatus(Map<String, dynamic> m) {
    if (_scoreIsEmpty(m)) return _isUpcoming(_parseDate(_s(m['match_date']))) ? 'Впереди' : 'Без счёта';
    return _matchResultLabel(m);
  }

  Color _matchDisplayColor(Map<String, dynamic> m) {
    if (_scoreIsEmpty(m)) return _isUpcoming(_parseDate(_s(m['match_date']))) ? _CmrMatchColors.blue : _CmrMatchColors.muted;
    return _matchResultColor(m);
  }

  Map<String, dynamic>? _selectedMatchForDetails(List<Map<String, dynamic>> timeline) {
    if (selectedMatchId > 0) {
      for (final m in matches) {
        if (_matchId(m) == selectedMatchId) return m;
      }
    }
    if (timeline.isNotEmpty) return timeline.first;
    if (matches.isNotEmpty) return matches.first;
    return null;
  }

  List<Map<String, dynamic>> _monthMatches() {
    final first = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    return matches.where((m) {
      final d = _parseDate(_s(m['match_date']));
      return !d.isBefore(first) && d.isBefore(next);
    }).toList();
  }

  Map<DateTime, List<Map<String, dynamic>>> _monthMap() {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final m in _monthMatches()) {
      final d = _parseDate(_s(m['match_date']));
      final key = DateTime(d.year, d.month, d.day);
      (map[key] ??= []).add(m);
    }
    return map;
  }

  int _wins(Iterable<Map<String, dynamic>> list) => list.where((m) => _i(m['our_score']) > _i(m['opponent_score'])).length;
  int _draws(Iterable<Map<String, dynamic>> list) => list.where((m) => _i(m['our_score']) == _i(m['opponent_score'])).length;
  int _losses(Iterable<Map<String, dynamic>> list) => list.where((m) => _i(m['our_score']) < _i(m['opponent_score'])).length;

  void _prevMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
      selectedDay = null;
      filter = CmrMatchesFilter.all;
      calendarRevision++;
    });
  }

  void _nextMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
      selectedDay = null;
      filter = CmrMatchesFilter.all;
      calendarRevision++;
    });
  }

  void _thisMonth() {
    final now = DateTime.now();
    setState(() {
      selectedMonth = DateTime(now.year, now.month, 1);
      selectedDay = null;
      filter = CmrMatchesFilter.all;
      calendarRevision++;
    });
  }

  bool _hasMatchesInMonth(List<Map<String, dynamic>> source, DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final next = DateTime(month.year, month.month + 1, 1);
    return source.any((m) {
      final d = _parseDate(_s(m['match_date']));
      return !d.isBefore(first) && d.isBefore(next);
    });
  }

  DateTime _bestMonthForMatches(List<Map<String, dynamic>> source) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    if (source.isEmpty) return currentMonth;
    if (_hasMatchesInMonth(source, selectedMonth)) {
      return DateTime(selectedMonth.year, selectedMonth.month, 1);
    }
    if (_hasMatchesInMonth(source, currentMonth)) return currentMonth;

    final today = DateTime(now.year, now.month, now.day);
    final upcoming = source.where((m) {
      final d = _parseDate(_s(m['match_date']));
      return !d.isBefore(today);
    }).toList();

    upcoming.sort((a, b) => _parseDate(_s(a['match_date'])).compareTo(_parseDate(_s(b['match_date']))));
    if (upcoming.isNotEmpty) {
      final d = _parseDate(_s(upcoming.first['match_date']));
      return DateTime(d.year, d.month, 1);
    }

    final archive = [...source];
    archive.sort((a, b) => _parseDate(_s(b['match_date'])).compareTo(_parseDate(_s(a['match_date']))));
    final d = _parseDate(_s(archive.first['match_date']));
    return DateTime(d.year, d.month, 1);
  }

  List<Map<String, dynamic>> _pastMatchesAll() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = matches.where((m) {
      final d = _parseDate(_s(m['match_date']));
      return d.isBefore(today);
    }).toList();
    list.sort((a, b) => _parseDate(_s(b['match_date'])).compareTo(_parseDate(_s(a['match_date']))));
    return list;
  }

  List<DateTime> _archiveMonths(List<Map<String, dynamic>> archive) {
    final seen = <String>{};
    final out = <DateTime>[];
    for (final m in archive) {
      final d = _parseDate(_s(m['match_date']));
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      if (seen.add(key)) {
        out.add(DateTime(d.year, d.month, 1));
      }
    }
    out.sort((a, b) => b.compareTo(a));
    return out;
  }

  void _openArchiveSheet() {
    final archive = _pastMatchesAll();
    setState(() => filter = CmrMatchesFilter.past);

    if (archive.isEmpty) {
      Get.snackbar('Архив матчей', 'Прошедших матчей пока нет');
      return;
    }

    final months = _archiveMonths(archive);
    DateTime activeMonth = months.firstWhere(
      (m) => m.year == selectedMonth.year && m.month == selectedMonth.month,
      orElse: () => months.first,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final activeList = archive.where((m) {
              final d = _parseDate(_s(m['match_date']));
              return d.year == activeMonth.year && d.month == activeMonth.month;
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.55,
              maxChildSize: 0.96,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  decoration: _CmrMatchDecor.panel(),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _CmrMatchColors.soft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: _CmrMatchColors.soft,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(Icons.history_rounded, color: _CmrMatchColors.text, size: 19),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Архив матчей',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _CmrMatchText.title(20),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${archive.length} прошедших • ${_monthTitle(activeMonth)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _CmrMatchText.caption(),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 46,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: months.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, index) {
                              final m = months[index];
                              final active = m.year == activeMonth.year && m.month == activeMonth.month;
                              final count = archive.where((x) {
                                final d = _parseDate(_s(x['match_date']));
                                return d.year == m.year && d.month == m.month;
                              }).length;

                              return _ArchiveMonthChip(
                                title: _monthTitle(m),
                                count: count,
                                active: active,
                                onTap: () {
                                  setSheetState(() => activeMonth = m);
                                  setState(() => selectedMonth = m);
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ArchiveMiniStat(
                                  title: 'Матчи',
                                  value: '${activeList.length}',
                                  icon: Icons.sports_soccer_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ArchiveMiniStat(
                                  title: 'Победы',
                                  value: '${_wins(activeList)}',
                                  icon: Icons.emoji_events_outlined,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ArchiveMiniStat(
                                  title: 'Баланс',
                                  value: '${_wins(activeList)}-${_draws(activeList)}-${_losses(activeList)}',
                                  icon: Icons.timeline_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: activeList.isEmpty
                              ? const _MiniEmpty(text: 'В этом месяце архивных матчей нет')
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                                  itemCount: activeList.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                                  itemBuilder: (_, index) {
                                    final m = activeList[index];
                                    return _CmrMatchTile(
                                      eventType: _eventTypeLabel(_s(m['event_type'])),
                                      opponent: _s(m['opponent']),
                                      date: _dateRu(_parseDate(_s(m['match_date']))),
                                      competition: _s(m['competition_name']),
                                      stadium: _s(m['stadium']),
                                      score: '${_i(m['our_score'])}:${_i(m['opponent_score'])}',
                                      upcoming: false,
                                      active: _matchId(m) == selectedMatchId,
                                      canEdit: canEdit,
                                      compact: true,
                                      onTap: () {
                                        Navigator.pop(context);
                                        setState(() {
                                          selectedMonth = activeMonth;
                                          filter = CmrMatchesFilter.past;
                                        });
                                        _openDetails(m);
                                      },
                                      onDelete: () => _deleteMatch(m),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _monthTitle(DateTime d) {
    const months = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        width: double.infinity,
        decoration: _CmrMatchDecor.panel(),
        child: const Center(child: CircularProgressIndicator(color: _CmrMatchColors.green)),
      );
    }

    if (error != null) {
      return _CmrEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Не удалось загрузить матчи',
        text: error!,
        actionText: 'Повторить',
        onAction: () => _fetch(initial: true),
      );
    }

    final monthList = _monthMatches();
    final monthMap = _monthMap();
    final timeline = _profileVisibleMatches();
    final selected = _selectedMatchForDetails(timeline);

    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: _CmrMatchText.font,
        fontFamilyFallback: _CmrMatchText.fallback,
        color: _CmrMatchColors.text,
        height: 1.18,
        letterSpacing: -0.08,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final isPhone = c.maxWidth < 640;
          if (isPhone) {
            return _buildPhoneLayout(visible: _visibleMatches(), monthList: monthList, monthMap: monthMap);
          }

          // В CMR-режиме список, детали и редактор всегда живут справа,
          // чтобы снизу не появлялся второй рабочий блок.
          return _buildTabletMatchesWorkspace(
            timeline: timeline,
            monthList: monthList,
            monthMap: monthMap,
            selected: selected,
            constraints: c,
          );
        },
      ),
    );
  }

  double _matchesCalendarColumnWidth(BoxConstraints constraints) {
    // Геометрия как в Club Teams: слева стабильная колонка до 480 px,
    // на узких экранах не сжимается ниже комфортных 320 px.
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 1180.0;
    return math.min(480.0, math.max(320.0, width * .42));
  }

  
Widget _buildTabletMatchesWorkspace({
    required List<Map<String, dynamic>> timeline,
    required List<Map<String, dynamic>> monthList,
    required Map<DateTime, List<Map<String, dynamic>>> monthMap,
    required Map<String, dynamic>? selected,
    required BoxConstraints constraints,
  }) {
    final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 780.0;
    final calendarWidth = _matchesCalendarColumnWidth(constraints);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Container(
        decoration: _CmrMatchDecor.workspaceBg(),
        padding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: _CmrMatchDecor.unifiedWindow(radius: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: calendarWidth,
                  child: _buildMatchesMainPanel(
                    monthList: monthList,
                    monthMap: monthMap,
                  ),
                ),
                Container(width: 1, color: _CmrMatchColors.border.withOpacity(.78)),
                Expanded(
                  child: _buildMatchesRightPane(
                    timeline: timeline,
                    monthList: monthList,
                    selected: selected,
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchesMainPanel({
    required List<Map<String, dynamic>> monthList,
    required Map<DateTime, List<Map<String, dynamic>>> monthMap,
  }) {
    return _buildStrictMatchesCalendarWindow(monthMap, monthList);
  }

  Widget _buildMatchesRightPane({
    required List<Map<String, dynamic>> timeline,
    required List<Map<String, dynamic>> monthList,
    required Map<String, dynamic>? selected,
    bool compact = false,
  }) {
    if (_workPanel == _MatchesWorkPanel.editor) {
      return _buildInlineMatchEditorPane(compact: compact);
    }

    if (_workPanel == _MatchesWorkPanel.details && selected != null) {
      return _buildMatchDetailsPane(selected, compact: compact);
    }

    return _buildMatchesRightListPanel(timeline, monthList, compact: compact);
  }

  Widget _buildInlineMatchEditorPane({bool compact = false}) {
    return _StrictMatchesCard(
      icon: Icons.edit_calendar_rounded,
      title: 'Редактор матча',
      subtitle: 'Заполните данные — форма остаётся справа, без нижнего окна',
      trailing: _ProfileRoundButton(icon: Icons.close_rounded, onTap: _closeWorkPanel),
      child: _CmrAddMatchSheet(
        onSubmit: _addMatch,
        embedded: true,
        onClose: _closeWorkPanel,
        onSaved: _handleInlineMatchSaved,
      ),
    );
  }

  Widget _buildMatchesRightListPanel(
    List<Map<String, dynamic>> timeline,
    List<Map<String, dynamic>> monthList, {
    bool compact = false,
  }) {
    final selectedDayMatches = selectedDay == null ? const <Map<String, dynamic>>[] : _matchesForDay(selectedDay!);
    final title = selectedDay == null ? 'Матчи периода' : 'Матчи дня';
    final subtitle = selectedDay == null
        ? '${_monthTitle(selectedMonth)} · ${timeline.length} ${_pluralMatch(timeline.length)}'
        : '${_dateRu(selectedDay!)} · ${selectedDayMatches.length} ${_pluralMatch(selectedDayMatches.length)}';
    final upcomingCount = matches.where((m) => _isUpcoming(_parseDate(_s(m['match_date'])))).length;
    final archiveCount = _pastMatchesAll().length;
    final goalsFor = monthList.fold<int>(0, (v, m) => v + _i(m['our_score']));
    final goalsAgainst = monthList.fold<int>(0, (v, m) => v + _i(m['opponent_score']));
    final next = _nextUpcomingMatch();

    return _StrictMatchesCard(
      icon: Icons.view_agenda_rounded,
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfileRoundButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
          if (canEdit) ...[
            const SizedBox(width: 7),
            _ProfileRoundButton(icon: Icons.add_rounded, onTap: _openCreate),
          ],
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MatchSideKpi(
                  icon: Icons.today_rounded,
                  label: selectedDay == null ? 'Период' : 'День',
                  value: selectedDay == null ? '${monthList.length}' : '${selectedDayMatches.length}',
                  hint: selectedDay == null ? 'в месяце' : 'на дату',
                  color: _CmrMatchColors.green,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MatchSideKpi(
                  icon: Icons.event_available_rounded,
                  label: 'Впереди',
                  value: '$upcomingCount',
                  hint: 'будущие',
                  color: _CmrMatchColors.blue,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MatchSideKpi(
                  icon: Icons.history_rounded,
                  label: 'Архив',
                  value: '$archiveCount',
                  hint: 'прошедшие',
                  color: _CmrMatchColors.violet,
                ),
              ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 8),
            _MatchNextStrip(
              opponent: _s(next['opponent']).isEmpty ? 'Ближайший матч' : _s(next['opponent']),
              meta: '${_dateRu(_parseDate(_s(next['match_date'] ?? next['date'] ?? next['start_at'])))} · ${_matchTypeText(next)}',
              score: _scoreText(next),
              color: _matchDisplayColor(next),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MatchSideKpi(
                  icon: Icons.trending_up_rounded,
                  label: 'Голы',
                  value: '$goalsFor:$goalsAgainst',
                  hint: 'заб/проп',
                  color: _CmrMatchColors.cyan,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MatchSideKpi(
                  icon: Icons.timeline_rounded,
                  label: 'Баланс',
                  value: '${_wins(monthList)}-${_draws(monthList)}-${_losses(monthList)}',
                  hint: 'В-Н-П',
                  color: _CmrMatchColors.pink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CmrSearch(
            controller: _searchCtrl,
            hint: 'Поиск матча',
            compact: true,
            onClear: () {
              _searchCtrl.clear();
              setState(() {});
            },
          ),
          if (selectedDay != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _SelectedDateChip(
                text: 'Показаны матчи за ${_dateRu(selectedDay!)}',
                onClear: () => setState(() {
                  selectedDay = null;
                  selectedMatchId = 0;
                  _workPanel = _MatchesWorkPanel.list;
                  calendarRevision++;
                }),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDay == null ? 'Список матчей' : 'Матчи выбранного дня',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrMatchText.title(14.6).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  selectedDay == null ? _monthTitle(selectedMonth) : _dateRu(selectedDay!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CmrMatchText.muted(11.2).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: timeline.isEmpty
                ? _MiniEmpty(text: monthList.isEmpty ? 'В этом месяце матчей нет' : 'Матчи скрыты фильтром или поиском')
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: timeline.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (_, i) => _buildProfileMatchCard(timeline[i], compact: true),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesPanelToolbar(List<Map<String, dynamic>> monthList) {
    final upcomingCount = matches.where((m) => _isUpcoming(_parseDate(_s(m['match_date'])))).length;
    final selectedDayMatches = selectedDay == null ? const <Map<String, dynamic>>[] : _matchesForDay(selectedDay!);
    final selectedText = selectedDay == null ? '${monthList.length} ${_pluralMatch(monthList.length)} в месяце' : '${selectedDayMatches.length} ${_pluralMatch(selectedDayMatches.length)} за ${_dateRu(selectedDay!)}';

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _CmrMatchColors.iconSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.sports_soccer_rounded, color: _CmrMatchColors.icon, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Матчи', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.title(16.5)),
              const SizedBox(height: 3),
              Text(
                '${widget.teamName.trim().isEmpty ? 'Команда' : widget.teamName} · $_monthTitleText · впереди: $upcomingCount · $selectedText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrMatchText.muted(12),
              ),
            ],
          ),
        ),
        _WorkspaceIconButton(icon: Icons.today_rounded, onTap: _thisMonth),
        const SizedBox(width: 7),
        _WorkspaceIconButton(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
        const SizedBox(width: 7),
        _WorkspaceIconButton(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
        const SizedBox(width: 7),
        _WorkspaceIconButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
        if (canEdit) ...[
          const SizedBox(width: 7),
          _WorkspaceIconButton(icon: Icons.add_rounded, onTap: _openCreate),
        ],
      ],
    );
  }

  String get _monthTitleText => _monthTitle(selectedMonth);

  Widget _buildMatchesWorkspaceHeader(
    List<Map<String, dynamic>> monthList,
    List<Map<String, dynamic>> timeline,
    Map<String, dynamic>? selected,
  ) {
    final next = _nextUpcomingMatch();
    final selectedDayMatches = selectedDay == null ? const <Map<String, dynamic>>[] : _matchesForDay(selectedDay!);
    final periodText = _monthTitle(selectedMonth);
    final selectedText = selectedDay == null ? 'день не выбран' : _dateRu(selectedDay!);
    final selectedCount = selectedDay == null ? '${timeline.length} в списке' : '${selectedDayMatches.length} ${_pluralMatch(selectedDayMatches.length)}';

    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: _CmrMatchDecor.softShadow,
      ),
      padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _CmrMatchColors.iconSoft,
              borderRadius: BorderRadius.circular(7),
              border: null,
            ),
            child: const Icon(Icons.sports_soccer_rounded, color: _CmrMatchColors.icon, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 34,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.teamName.trim().isEmpty ? 'Команда' : widget.teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _CmrMatchColors.text, fontSize: 13.65, fontWeight: FontWeight.w600, height: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.clubName.trim().isEmpty ? 'Матчи команды' : widget.clubName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _CmrMatchColors.muted, fontSize: 10.05, fontWeight: FontWeight.w600, height: 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 28,
            child: _MatchTopLine(
              label: 'Период',
              value: periodText,
              subvalue: '$selectedText · $selectedCount',
              icon: Icons.date_range_rounded,
              color: _CmrMatchColors.icon,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 26,
            child: _MatchTopLine(
              label: 'Ближайший матч',
              value: next == null ? 'Нет матчей' : (_s(next['opponent']).isEmpty ? 'Соперник' : _s(next['opponent'])),
              subvalue: next == null ? 'Добавьте матч в календарь' : '${_dateRu(_parseDate(_s(next['match_date'])))} · ${_matchTypeText(next)}',
              icon: next == null ? Icons.event_busy_rounded : Icons.event_available_rounded,
              color: next == null ? _CmrMatchColors.muted : _matchDisplayColor(next),
            ),
          ),
          const SizedBox(width: 8),
          _WorkspaceIconButton(icon: Icons.today_rounded, onTap: _thisMonth),
          const SizedBox(width: 5),
          _WorkspaceIconButton(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
          const SizedBox(width: 5),
          _WorkspaceIconButton(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
          const SizedBox(width: 5),
          _WorkspaceIconButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
          if (canEdit) ...[
            const SizedBox(width: 5),
            _WorkspaceIconButton(icon: Icons.add_rounded, onTap: _openCreate),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchesInfoRows(List<Map<String, dynamic>> monthList) {
    final goalsFor = monthList.fold<int>(0, (v, m) => v + _i(m['our_score']));
    final goalsAgainst = monthList.fold<int>(0, (v, m) => v + _i(m['opponent_score']));
    final selectedDayMatches = selectedDay == null ? const <Map<String, dynamic>>[] : _matchesForDay(selectedDay!);
    final upcomingCount = matches.where((m) => _isUpcoming(_parseDate(_s(m['match_date'])))).length;
    final archiveCount = _pastMatchesAll().length;
    final balance = '${_wins(monthList)}-${_draws(monthList)}-${_losses(monthList)}';

    final items = [
      _MatchKpiData(label: 'Период', value: '${monthList.length}', icon: Icons.dashboard_customize_rounded, color: _CmrMatchColors.green, hint: _monthTitle(selectedMonth)),
      _MatchKpiData(label: 'День', value: selectedDay == null ? '—' : '${selectedDayMatches.length}', icon: Icons.today_rounded, color: _CmrMatchColors.blue, hint: selectedDay == null ? 'не выбран' : _dateRu(selectedDay!)),
      _MatchKpiData(label: 'Впереди', value: '$upcomingCount', icon: Icons.event_available_rounded, color: _CmrMatchColors.cyan, hint: 'будущие игры'),
      _MatchKpiData(label: 'Архив', value: '$archiveCount', icon: Icons.history_rounded, color: _CmrMatchColors.violet, hint: 'прошедшие'),
      _MatchKpiData(label: 'Голы', value: '$goalsFor:$goalsAgainst', icon: Icons.trending_up_rounded, color: _CmrMatchColors.amber, hint: 'забито/пропущено'),
      _MatchKpiData(label: 'Баланс', value: balance, icon: Icons.timeline_rounded, color: _CmrMatchColors.pink, hint: 'В-Н-П'),
    ];

    return SizedBox(
      height: 42,
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 5.0;
          final wide = c.maxWidth >= 1040;
          if (wide) {
            return Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  Expanded(child: _MatchInfoCell(item: items[i])),
                  if (i != items.length - 1) const SizedBox(width: gap),
                ],
              ],
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (_, index) => SizedBox(width: 156, child: _MatchInfoCell(item: items[index])),
            separatorBuilder: (_, __) => const SizedBox(width: gap),
            itemCount: items.length,
          );
        },
      ),
    );
  }

  Widget _buildStrictMatchesCalendarWindow(
    Map<DateTime, List<Map<String, dynamic>>> monthMap,
    List<Map<String, dynamic>> monthList,
  ) {
    final selectedText = selectedDay == null ? 'день не выбран' : _dateRu(selectedDay!);
    return _StrictMatchesCard(
      icon: Icons.calendar_month_rounded,
      title: _monthTitle(selectedMonth),
      subtitle: '${widget.teamName.trim().isEmpty ? 'Команда' : widget.teamName} · $selectedText · ${monthList.length} ${_pluralMatch(monthList.length)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfileRoundButton(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
          const SizedBox(width: 6),
          _ProfileRoundButton(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
          const SizedBox(width: 6),
          _ProfileRoundButton(icon: Icons.today_rounded, onTap: _thisMonth),
          const SizedBox(width: 6),
          _ProfileRoundButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
          if (canEdit) ...[
            const SizedBox(width: 6),
            _ProfileRoundButton(icon: Icons.add_rounded, onTap: _openCreate),
          ],
        ],
      ),
      child: Column(
        children: [
          _buildMatchesInfoRows(monthList),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 250, child: _buildProfileFilters()),
              const SizedBox(width: 8),
              Expanded(child: _buildMatchKindFilters()),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(7),
                child: LayoutBuilder(
                  builder: (context, calendarBox) => _MonthMatchesGrid(
                    key: ValueKey('strict-matches-calendar-${selectedMonth.year}-${selectedMonth.month}-$calendarRevision'),
                    month: selectedMonth,
                    selectedDay: selectedDay,
                    matchesByDay: monthMap,
                    dateText: _dateRu,
                    compact: false,
                    maxHeight: calendarBox.maxHeight,
                    onDayTap: (day, list) {
                      setState(() {
                        selectedDay = day;
                        selectedMatchId = list.isNotEmpty ? _matchId(list.first) : 0;
                        _workPanel = _MatchesWorkPanel.list;
                        calendarRevision++;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesListWindow(
    List<Map<String, dynamic>> timeline,
    List<Map<String, dynamic>> monthList, {
    bool compact = false,
  }) {
    final title = selectedDay == null ? 'Матчи периода' : 'Матчи дня';
    final subtitle = selectedDay == null ? _monthTitle(selectedMonth) : _dateRu(selectedDay!);

    return _StrictMatchesCard(
      icon: Icons.view_agenda_rounded,
      title: title,
      subtitle: '$subtitle · ${timeline.length} ${_pluralMatch(timeline.length)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WorkspaceIconButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
          if (canEdit) ...[
            const SizedBox(width: 6),
            _WorkspaceIconButton(icon: Icons.add_rounded, onTap: _openCreate),
          ],
        ],
      ),
      child: Column(
        children: [
          _CmrSearch(
            controller: _searchCtrl,
            hint: compact ? 'Поиск матча' : 'Поиск по сопернику, турниру, стадиону...',
            compact: true,
            onClear: () {
              _searchCtrl.clear();
              setState(() {});
            },
          ),
          if (selectedDay != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: _SelectedDateChip(
                text: 'Показаны матчи за ${_dateRu(selectedDay!)}',
                onClear: () => setState(() {
                  selectedDay = null;
                  selectedMatchId = 0;
                  calendarRevision++;
                }),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Expanded(
            child: timeline.isEmpty
                ? _MiniEmpty(text: monthList.isEmpty ? 'В этом месяце матчей нет' : 'Матчи есть в календаре, но скрыты фильтром или поиском')
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: timeline.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final m = timeline[i];
                      return _buildProfileMatchCard(m, compact: true);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _nextUpcomingMatch() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final future = matches.where((m) => !_parseDate(_s(m['match_date'])).isBefore(today)).toList()
      ..sort((a, b) => _parseDate(_s(a['match_date'])).compareTo(_parseDate(_s(b['match_date']))));
    if (future.isNotEmpty) return future.first;
    final sorted = matches.toList()..sort((a, b) => _parseDate(_s(b['match_date'])).compareTo(_parseDate(_s(a['match_date']))));
    return sorted.isEmpty ? null : sorted.first;
  }

  String _pluralMatch(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'матч';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'матча';
    return 'матчей';
  }

  Widget _buildProfileMatchesCenter({
    required List<Map<String, dynamic>> timeline,
    required Map<DateTime, List<Map<String, dynamic>>> monthMap,
    required double maxWidth,
  }) {
    final listTitle = selectedDay == null ? 'Матчи за ${_monthTitle(selectedMonth)}' : 'Матчи за ${_dateRu(selectedDay!)}';

    return RefreshIndicator(
      color: _CmrMatchColors.green,
      onRefresh: () => _fetch(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSlimProfileCalendar(monthMap),
          const SizedBox(height: 14),
          _buildMatchKindFilters(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    listTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrMatchText.title(18.5).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (canEdit)
                  _ProfileActionButton(
                    icon: Icons.add_rounded,
                    text: 'Матч',
                    onTap: _openCreate,
                  ),
                const SizedBox(width: 8),
                _ProfileRoundButton(
                  icon: refreshing ? Icons.sync_rounded : Icons.tune_rounded,
                  onTap: () => _fetch(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildProfileFilters(),
          const SizedBox(height: 10),
          _CmrSearch(
            controller: _searchCtrl,
            hint: 'Поиск по сопернику, турниру, стадиону...',
            compact: true,
            onClear: () {
              _searchCtrl.clear();
              setState(() {});
            },
          ),
          if (selectedDay != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: _SelectedDateChip(
                text: 'Показаны матчи за ${_dateRu(selectedDay!)}',
                onClear: () => setState(() {
                  selectedDay = null;
                  selectedMatchId = 0;
                  calendarRevision++;
                }),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (timeline.isEmpty)
            _MiniEmpty(text: selectedDay == null ? 'Матчи пока не найдены' : 'На выбранную дату матчей нет')
          else
            _buildProfileMatchCardsList(timeline, maxWidth: maxWidth),
        ],
      ),
    );
  }

  Widget _buildMatchKindFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _KindFilterChip(
            icon: Icons.calendar_month_rounded,
            text: 'Все матчи',
            active: matchKindFilter == CmrMatchKindFilter.all,
            onTap: () => setState(() => matchKindFilter = CmrMatchKindFilter.all),
          ),
          const SizedBox(width: 8),
          _KindFilterChip(
            icon: Icons.emoji_events_outlined,
            text: 'Турнирные',
            active: matchKindFilter == CmrMatchKindFilter.tournament,
            onTap: () => setState(() => matchKindFilter = CmrMatchKindFilter.tournament),
          ),
          const SizedBox(width: 8),
          _KindFilterChip(
            icon: Icons.handshake_outlined,
            text: 'Товарищеские',
            active: matchKindFilter == CmrMatchKindFilter.friendly,
            onTap: () => setState(() => matchKindFilter = CmrMatchKindFilter.friendly),
          ),
          const SizedBox(width: 8),
          _KindFilterChip(
            icon: Icons.home_outlined,
            text: 'Дома',
            active: matchKindFilter == CmrMatchKindFilter.home,
            onTap: () => setState(() => matchKindFilter = CmrMatchKindFilter.home),
          ),
          const SizedBox(width: 8),
          _KindFilterChip(
            icon: Icons.flight_takeoff_rounded,
            text: 'В гостях',
            active: matchKindFilter == CmrMatchKindFilter.away,
            onTap: () => setState(() => matchKindFilter = CmrMatchKindFilter.away),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFilters() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _CmrMatchColors.soft,
        borderRadius: BorderRadius.circular(14),
        border: null,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentedTab(
              text: 'Все',
              active: filter == CmrMatchesFilter.all && selectedDay == null,
              onTap: () => setState(() {
                filter = CmrMatchesFilter.all;
                selectedDay = null;
              }),
            ),
          ),
          Expanded(
            child: _SegmentedTab(
              text: 'Впереди',
              active: filter == CmrMatchesFilter.upcoming && selectedDay == null,
              onTap: () => setState(() {
                filter = CmrMatchesFilter.upcoming;
                selectedDay = null;
              }),
            ),
          ),
          Expanded(
            child: _SegmentedTab(
              text: 'Архив',
              active: filter == CmrMatchesFilter.past && selectedDay == null,
              onTap: () => setState(() {
                filter = CmrMatchesFilter.past;
                selectedDay = null;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlimProfileCalendar(Map<DateTime, List<Map<String, dynamic>>> monthMap) {
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final first = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final prevMonthDays = DateTime(selectedMonth.year, selectedMonth.month, 0).day;
    final leading = first.weekday - 1;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: null,
        boxShadow: null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ProfileCalendarArrow(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_monthTitle(selectedMonth), style: _CmrMatchText.title(16.5).copyWith(fontWeight: FontWeight.w600)),
                      if (refreshing) ...[
                        const SizedBox(width: 8),
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _CmrMatchColors.green)),
                      ],
                    ],
                  ),
                ),
              ),
              _ProfileCalendarArrow(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
              const SizedBox(width: 8),
              _ProfileRoundButton(icon: Icons.calendar_today_rounded, onTap: _thisMonth),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: weekdays
                .map((d) => Expanded(child: Center(child: Text(d, style: _CmrMatchText.caption().copyWith(fontSize: 10.75, fontWeight: FontWeight.w600)))))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            key: ValueKey('profile-like-team-calendar-${selectedMonth.year}-${selectedMonth.month}-$calendarRevision'),
            itemCount: total,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              childAspectRatio: 1.18,
            ),
            itemBuilder: (_, index) {
              final dayNumber = index - leading + 1;
              late DateTime day;
              var inMonth = true;
              if (dayNumber < 1) {
                day = DateTime(selectedMonth.year, selectedMonth.month - 1, prevMonthDays + dayNumber);
                inMonth = false;
              } else if (dayNumber > daysInMonth) {
                day = DateTime(selectedMonth.year, selectedMonth.month + 1, dayNumber - daysInMonth);
                inMonth = false;
              } else {
                day = DateTime(selectedMonth.year, selectedMonth.month, dayNumber);
              }

              final list = inMonth ? (monthMap[DateTime(day.year, day.month, day.day)] ?? const <Map<String, dynamic>>[]) : _matchesForDay(day);
              final has = list.isNotEmpty;
              final now = DateTime.now();
              final today = _sameDay(day, DateTime(now.year, now.month, now.day));
              final selected = selectedDay != null && _sameDay(day, selectedDay!);

              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () {
                    setState(() {
                      selectedDay = day;
                      selectedMonth = DateTime(day.year, day.month, 1);
                      if (has) selectedMatchId = _matchId(list.first);
                      calendarRevision++;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(.96)
                          : has
                              ? Colors.white
                              : (inMonth ? _CmrMatchColors.soft : _CmrMatchColors.soft2),
                      borderRadius: BorderRadius.circular(15),
                      border: selected ? Border.all(color: _CmrMatchColors.greenBorder) : null,
                      boxShadow: selected ? _CmrMatchDecor.microShadow : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: selected
                                  ? _CmrMatchColors.greenDark
                                  : inMonth
                                      ? (today ? _CmrMatchColors.green : _CmrMatchColors.text)
                                      : _CmrMatchColors.muted2.withOpacity(.72),
                              fontSize: 12.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (has)
                          Positioned(
                            top: 3,
                            right: 4,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 16),
                              height: 16,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: _CmrMatchColors.green,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Center(
                                child: Text(
                                  '${list.length}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (selected)
                          const Positioned(
                            bottom: 5,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: SizedBox(
                                width: 6,
                                height: 6,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(color: _CmrMatchColors.icon, shape: BoxShape.circle),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMatchCardsList(List<Map<String, dynamic>> rows, {required double maxWidth}) {
    return Column(
      children: rows
          .map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildProfileMatchCard(m, compact: maxWidth < 560),
            ),
          )
          .toList(),
    );
  }

  Widget _buildProfileMatchCard(Map<String, dynamic> m, {required bool compact}) {
    final id = _matchId(m);
    final opponent = _s(m['opponent']).isEmpty ? 'Соперник не указан' : _s(m['opponent']);
    final tournament = _s(m['competition_name'] ?? m['tournament'] ?? m['event_type']);
    final date = _dateRu(_parseDate(_s(m['match_date'] ?? m['date'] ?? m['start_at'])));
    final time = _matchTimeText(m);
    final score = _scoreText(m);
    final active = id > 0 && id == selectedMatchId;
    final statusColor = _matchDisplayColor(m);
    final statusLabel = _matchDisplayStatus(m);
    final stadium = _s(m['stadium']).isEmpty ? 'Стадион не указан' : _s(m['stadium']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectMatchForPane(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 9 : 10),
          decoration: _CmrMatchDecor.fluentSurface(
            radius: 14,
            accent: statusColor,
            active: active,
            elevated: active,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 3,
                height: compact ? 52 : 58,
                decoration: BoxDecoration(
                  color: active ? _CmrMatchColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(width: compact ? 9 : 11),
              _TeamLogoCircle(active: active, compact: compact),
              SizedBox(width: compact ? 10 : 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            opponent,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrMatchText.title(compact ? 13.4 : 14.2),
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 6),
                          const _MatchActiveDot(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [date, if (time.isNotEmpty) time].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrMatchText.muted(compact ? 10.8 : 11.2),
                    ),
                    if (tournament.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        tournament,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrMatchText.muted(compact ? 10.6 : 11.0),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: _CmrMatchColors.muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            stadium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrMatchText.caption().copyWith(fontSize: compact ? 10.2 : 10.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ProfileScoreBadge(score: score, color: statusColor, compact: compact),
                  const SizedBox(height: 8),
                  _StatusPill(text: statusLabel, color: statusColor, icon: _scoreIsEmpty(m) ? Icons.schedule_rounded : Icons.emoji_events_outlined, compact: compact),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchDetailsPane(Map<String, dynamic>? match, {bool compact = false}) {
    Widget emptyState() {
      return Container(
        decoration: _CmrMatchDecor.seamlessPane(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: _CmrMatchDecor.fluentSurface(
                    radius: 16,
                    accent: _CmrMatchColors.green,
                    active: true,
                    elevated: false,
                  ),
                  child: const Icon(Icons.analytics_outlined, color: _CmrMatchColors.green, size: 23),
                ),
                const SizedBox(height: 12),
                Text('Выберите матч', style: _CmrMatchText.title(17)),
                const SizedBox(height: 6),
                Text(
                  'Справа появится краткая карточка и вход в экран разбора матча.',
                  textAlign: TextAlign.center,
                  style: _CmrMatchText.muted(12.2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (match == null) return emptyState();

    final id = _matchId(match);
    final opponent = _s(match['opponent']).isEmpty ? 'Соперник не указан' : _s(match['opponent']);
    final tournament = _s(match['competition_name'] ?? match['tournament'] ?? match['event_type']);
    final date = _dateRu(_parseDate(_s(match['match_date'] ?? match['date'] ?? match['start_at'])));
    final time = _matchTimeText(match);
    final score = _scoreText(match);
    final hasVideo = _matchVideoUrl(match).isNotEmpty;
    final hasTtd = _hasMatchTtd(match);
    final notes = _matchCoachComment(match);
    final stadium = _s(match['stadium']);
    final referees = _s(match['referees']);
    final inspector = _s(match['inspector'] ?? match['match_inspector']);
    final statusColor = _matchDisplayColor(match);
    final statusLabel = _matchDisplayStatus(match);
    final isOpening = openingMatchId == id && id > 0;
    final typeText = _matchTypeText(match);
    final readyParts = <bool>[hasVideo, hasTtd, notes.isNotEmpty, !_scoreIsEmpty(match)];
    final readyCount = readyParts.where((v) => v).length;
    final readyPercent = readyCount / readyParts.length;

    Widget miniMetric({
      required IconData icon,
      required String title,
      required String value,
      required Color color,
    }) {
      return Expanded(
        child: Container(
          height: compact ? 72 : 78,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: _CmrMatchDecor.fluentSurface(
            radius: 14,
            accent: color,
            active: true,
            elevated: false,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 15, color: color),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.value(compact ? 13.0 : 14.0).copyWith(color: _CmrMatchColors.text)),
                  const SizedBox(height: 2),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.caption().copyWith(fontSize: 10.3)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget readinessLine(String title, bool done, IconData icon) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: done ? _CmrMatchColors.greenSoft : _CmrMatchColors.soft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 13, color: done ? _CmrMatchColors.green : _CmrMatchColors.muted2),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrMatchText.muted(11.6).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(done ? 'готово' : 'нет', style: _CmrMatchText.caption().copyWith(color: done ? _CmrMatchColors.greenDark : _CmrMatchColors.muted2)),
          ],
        ),
      );
    }

    return Container(
      decoration: _CmrMatchDecor.seamlessPane(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(compact ? 12 : 14, compact ? 12 : 14, compact ? 12 : 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: _CmrMatchDecor.fluentSurface(
                    radius: 14,
                    accent: statusColor,
                    active: true,
                    elevated: false,
                  ),
                  child: Icon(Icons.sports_soccer_rounded, color: statusColor, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opponent, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrMatchText.title(compact ? 17 : 18.5).copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _ProfileMetaPill(icon: Icons.calendar_today_rounded, text: [date, if (time.isNotEmpty) time].join(' · '), color: _CmrMatchColors.muted),
                          _ProfileMetaPill(icon: Icons.fact_check_outlined, text: typeText.isEmpty ? 'Матч' : typeText, color: _CmrMatchColors.blue),
                          _StatusPill(text: statusLabel, color: statusColor, icon: _scoreIsEmpty(match) ? Icons.schedule_rounded : Icons.emoji_events_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ProfileRoundButton(icon: Icons.close_rounded, onTap: _closeWorkPanel),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 14 : 16),
              decoration: _CmrMatchDecor.fluentSurface(
                radius: 18,
                accent: _CmrMatchColors.green,
                active: true,
                elevated: false,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Экран разбора матча', style: _CmrMatchText.section()),
                            const SizedBox(height: 5),
                            Text(
                              'Откройте полную аналитику: видео, ТТД, события, физику и ИИ-выводы.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _CmrMatchText.muted(11.8),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(.72), borderRadius: BorderRadius.circular(14)),
                        child: Text(score, style: _CmrMatchText.value(compact ? 17 : 19).copyWith(color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _LargeGreenButton(
                    icon: isOpening ? Icons.hourglass_top_rounded : Icons.monitor_heart_outlined,
                    text: isOpening ? 'Открываю разбор...' : 'Открыть разбор матча',
                    onTap: id <= 0 || isOpening ? null : () => _openDetails(match),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                miniMetric(icon: Icons.play_circle_outline_rounded, title: 'Видео', value: hasVideo ? 'Есть' : 'Нет', color: hasVideo ? _CmrMatchColors.green : _CmrMatchColors.muted2),
                const SizedBox(width: 8),
                miniMetric(icon: Icons.bar_chart_rounded, title: 'ТТД', value: hasTtd ? 'Есть' : 'Нет', color: hasTtd ? _CmrMatchColors.blue : _CmrMatchColors.muted2),
                const SizedBox(width: 8),
                miniMetric(icon: Icons.insights_rounded, title: 'Готовность', value: '${(readyPercent * 100).round()}%', color: _CmrMatchColors.violet),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: _CmrMatchDecor.fluentSurface(
                radius: 16,
                accent: _CmrMatchColors.blue,
                active: false,
                elevated: false,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist_rtl_rounded, size: 15, color: _CmrMatchColors.icon),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Материалы для анализа', style: _CmrMatchText.section().copyWith(fontSize: 12.6))),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: readyPercent.clamp(0.0, 1.0).toDouble(),
                      backgroundColor: _CmrMatchColors.soft,
                      valueColor: const AlwaysStoppedAnimation<Color>(_CmrMatchColors.green),
                    ),
                  ),
                  const SizedBox(height: 9),
                  readinessLine('Счёт и базовые данные', !_scoreIsEmpty(match), Icons.scoreboard_rounded),
                  readinessLine('Видео матча', hasVideo, Icons.movie_creation_outlined),
                  readinessLine('ТТД / статистика', hasTtd, Icons.bar_chart_rounded),
                  readinessLine('Комментарий тренера', notes.isNotEmpty, Icons.format_quote_rounded),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DetailsGroup(
              children: [
                _DetailRow(icon: Icons.emoji_events_outlined, title: 'Турнир', value: tournament.isEmpty ? 'Не указан' : tournament),
                _DetailRow(icon: Icons.location_on_outlined, title: 'Стадион', value: stadium.isEmpty ? 'Не указан' : stadium),
                _DetailRow(icon: Icons.sports_rounded, title: 'Судьи', value: referees.isEmpty ? 'Не указаны' : referees),
                _DetailRow(icon: Icons.person_search_outlined, title: 'Инспектор', value: inspector.isEmpty ? 'Нет' : inspector),
              ],
            ),
            const SizedBox(height: 12),
            _ProfileNoteBlock(
              icon: Icons.format_quote_rounded,
              title: 'Комментарий тренера',
              text: notes.isEmpty ? 'Комментарий пока не заполнен' : notes,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DetailsActionButton(
                    icon: Icons.play_circle_outline_rounded,
                    label: 'Видео',
                    onTap: hasVideo && id > 0 ? () => _openDetails(match) : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DetailsActionButton(
                    icon: Icons.analytics_outlined,
                    label: 'ТТД',
                    onTap: hasTtd && id > 0 ? () => _openDetails(match) : null,
                  ),
                ),
              ],
            ),
            if (canEdit) ...[
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _deleteMatch(match),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: _CmrMatchDecor.fluentSurface(
                    radius: 14,
                    accent: _CmrMatchColors.red,
                    active: false,
                    elevated: false,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_outline_rounded, color: _CmrMatchColors.red, size: 15),
                      const SizedBox(width: 7),
                      Text('Удалить матч', style: _CmrMatchText.danger().copyWith(fontSize: 11.4)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneLayout({
    required List<Map<String, dynamic>> visible,
    required List<Map<String, dynamic>> monthList,
    required Map<DateTime, List<Map<String, dynamic>>> monthMap,
  }) {
    final upcomingCount = matches.where((m) => _isUpcoming(_parseDate(_s(m['match_date'])))).length;
    final listTitle = filter == CmrMatchesFilter.upcoming
        ? 'Будущие матчи за ${_monthTitle(selectedMonth)}'
        : filter == CmrMatchesFilter.past
            ? 'Архив за ${_monthTitle(selectedMonth)}'
            : 'Матчи за ${_monthTitle(selectedMonth)}';

    return RefreshIndicator(
      color: _CmrMatchColors.green,
      onRefresh: () => _fetch(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            decoration: _CmrMatchDecor.panel(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: _CmrMatchColors.panel,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CmrIconBox(icon: Icons.sports_soccer_rounded, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.teamName.trim().isEmpty ? 'Команда' : widget.teamName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _CmrMatchText.title(16.5),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Матчи и календарь команды',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: _CmrMatchColors.muted, fontWeight: FontWeight.w600, fontSize: 11.05),
                                ),
                              ],
                            ),
                          ),
                          _HeaderIconButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _HeroStat(value: '${matches.length}', title: 'всего', compact: true)),
                          const SizedBox(width: 8),
                          Expanded(child: _HeroStat(value: '$upcomingCount', title: 'впереди', compact: true)),
                          const SizedBox(width: 8),
                          Expanded(child: _HeroStat(value: canEdit ? 'Да' : 'Нет', title: 'редакт.', compact: true)),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: _CmrSearch(
                    controller: _searchCtrl,
                    hint: 'Поиск матча',
                    compact: true,
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(child: _FilterButton(text: 'Все', active: filter == CmrMatchesFilter.all, compact: true, onTap: () => setState(() => filter = CmrMatchesFilter.all))),
                      const SizedBox(width: 8),
                      Expanded(child: _FilterButton(text: 'Впереди', active: filter == CmrMatchesFilter.upcoming, compact: true, onTap: () => setState(() => filter = CmrMatchesFilter.upcoming))),
                      const SizedBox(width: 8),
                      Expanded(child: _FilterButton(text: 'Архив', active: filter == CmrMatchesFilter.past, compact: true, onTap: () => setState(() => filter = CmrMatchesFilter.past))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: _CmrMatchDecor.panel(),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: _CmrMatchColors.panel,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CmrIconBox(icon: Icons.event_available_rounded, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_monthTitle(selectedMonth), maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrMatchText.title(18)),
                                const SizedBox(height: 4),
                                Text('П ${_wins(monthList)} • Н ${_draws(monthList)} • Пор ${_losses(monthList)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.caption()),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _TopActionButton(icon: Icons.today_rounded, text: 'Текущий месяц', compact: true, onTap: _thisMonth)),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_left_rounded, compact: true, onTap: _prevMonth),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_right_rounded, compact: true, onTap: _nextMonth),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildStatsRow(monthList, isPhone: true),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  child: SizedBox(
                    height: 330,
                    child: _MonthMatchesGrid(
                      key: ValueKey('phone-matches-calendar-${selectedMonth.year}-${selectedMonth.month}-$calendarRevision'),
                      month: selectedMonth,
                      selectedDay: selectedDay,
                      matchesByDay: monthMap,
                      dateText: _dateRu,
                      compact: true,
                      onDayTap: (day, list) {
                        setState(() {
                          selectedDay = day;
                          calendarRevision++;
                        });

                        if (list.isEmpty) return;
                        if (list.length == 1) {
                          _showMatchPreviewSheet(list.first);
                          return;
                        }
                        _showDayMatches(day, list);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: _CmrMatchDecor.panel(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SelectedMatchesHeader(
                    title: listTitle,
                    canEdit: canEdit,
                    compact: true,
                    onAdd: _openCreate,
                  ),
                  const SizedBox(height: 10),
                  if (visible.isEmpty)
                    _MiniEmpty(text: monthList.isEmpty ? 'В этом месяце матчей нет' : 'Матчи есть в календаре, но скрыты фильтром или поиском')
                  else
                    ...List.generate(visible.length, (i) {
                      final m = visible[i];
                      return Padding(
                        padding: EdgeInsets.only(bottom: i == visible.length - 1 ? 0 : 8),
                        child: _CmrMatchTile(
                          eventType: _eventTypeLabel(_s(m['event_type'])),
                          opponent: _s(m['opponent']),
                          date: _dateRu(_parseDate(_s(m['match_date']))),
                          competition: _s(m['competition_name']),
                          stadium: _s(m['stadium']),
                          score: '${_i(m['our_score'])}:${_i(m['opponent_score'])}',
                          upcoming: _isUpcoming(_parseDate(_s(m['match_date']))),
                          active: _matchId(m) == selectedMatchId,
                          canEdit: canEdit,
                          compact: true,
                          onTap: () => _handleMatchTap(m),
                          onDelete: () => _deleteMatch(m),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(List<Map<String, dynamic>> visible, List<Map<String, dynamic>> monthList, {bool isPhone = false}) {
    final upcomingCount = matches.where((m) => _isUpcoming(_parseDate(_s(m['match_date'])))).length;

    return Container(
      decoration: _CmrMatchDecor.panel(),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(isPhone ? 14 : 18, isPhone ? 14 : 18, isPhone ? 14 : 18, isPhone ? 12 : 18),
            decoration: BoxDecoration(
              color: _CmrMatchColors.panel,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CmrIconBox(icon: Icons.sports_soccer_rounded, size: isPhone ? 36 : 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.teamName.trim().isEmpty ? 'Команда' : widget.teamName,
                            maxLines: isPhone ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrMatchText.title(isPhone ? 16.5 : 19),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Матчи и календарь команды',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrMatchText.muted(isPhone ? 11.5 : 12),
                          ),
                        ],
                      ),
                    ),
                    if (!isPhone) _HeaderIconButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
                  ],
                ),
                SizedBox(height: isPhone ? 12 : 16),
                Row(
                  children: [
                    Expanded(child: _HeroStat(value: '${matches.length}', title: 'всего', compact: isPhone)),
                    const SizedBox(width: 8),
                    Expanded(child: _HeroStat(value: '$upcomingCount', title: 'впереди', compact: isPhone)),
                    const SizedBox(width: 8),
                    Expanded(child: _HeroStat(value: canEdit ? 'Да' : 'Нет', title: 'редакт.', compact: isPhone)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isPhone ? 12 : 14, isPhone ? 12 : 14, isPhone ? 12 : 14, 10),
            child: _CmrSearch(
              controller: _searchCtrl,
              hint: isPhone ? 'Поиск матча' : 'Поиск по сопернику, турниру, стадиону',
              compact: isPhone,
              onClear: () {
                _searchCtrl.clear();
                setState(() {});
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isPhone ? 12 : 14, 0, isPhone ? 12 : 14, 10),
            child: Row(
              children: [
                Expanded(child: _FilterButton(text: 'Все', active: filter == CmrMatchesFilter.all, compact: isPhone, onTap: () => setState(() => filter = CmrMatchesFilter.all))),
                const SizedBox(width: 8),
                Expanded(child: _FilterButton(text: 'Впереди', active: filter == CmrMatchesFilter.upcoming, compact: isPhone, onTap: () => setState(() => filter = CmrMatchesFilter.upcoming))),
                const SizedBox(width: 8),
                Expanded(child: _FilterButton(text: 'Архив', active: filter == CmrMatchesFilter.past, compact: isPhone, onTap: _openArchiveSheet)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isPhone ? 12 : 14, 0, isPhone ? 12 : 14, 10),
            child: _SelectedMatchesHeader(
              title: _monthTitle(selectedMonth),
              canEdit: canEdit,
              compact: isPhone,
              onAdd: _openCreate,
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? _MiniEmpty(text: monthList.isEmpty ? 'В этом месяце матчей нет' : 'Матчи есть в календаре, но скрыты фильтром или поиском')
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(isPhone ? 12 : 14, 0, isPhone ? 12 : 14, 14),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => SizedBox(height: isPhone ? 8 : 10),
                    itemBuilder: (_, i) {
                      final m = visible[i];
                      return _CmrMatchTile(
                        eventType: _eventTypeLabel(_s(m['event_type'])),
                        opponent: _s(m['opponent']),
                        date: _dateRu(_parseDate(_s(m['match_date']))),
                        competition: _s(m['competition_name']),
                        stadium: _s(m['stadium']),
                        score: '${_i(m['our_score'])}:${_i(m['opponent_score'])}',
                        upcoming: _isUpcoming(_parseDate(_s(m['match_date']))),
                        active: _matchId(m) == selectedMatchId,
                        canEdit: canEdit,
                        compact: isPhone,
                        onTap: () => _handleMatchTap(m),
                        onDelete: () => _deleteMatch(m),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarArea(Map<DateTime, List<Map<String, dynamic>>> monthMap, List<Map<String, dynamic>> monthList, {bool isPhone = false}) {
    return Container(
      decoration: _CmrMatchDecor.panel(),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isPhone ? 14 : 18),
            decoration: const BoxDecoration(
              color: _CmrMatchColors.panel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: isPhone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CmrIconBox(icon: Icons.event_available_rounded, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_monthTitle(selectedMonth), maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrMatchText.title(18)),
                                const SizedBox(height: 4),
                                Text('П ${_wins(monthList)} • Н ${_draws(monthList)} • Пор ${_losses(monthList)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.caption()),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _TopActionButton(icon: Icons.today_rounded, text: 'Текущий месяц', compact: true, onTap: _thisMonth)),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_left_rounded, compact: true, onTap: _prevMonth),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_right_rounded, compact: true, onTap: _nextMonth),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _CmrIconBox(icon: Icons.event_available_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_monthTitle(selectedMonth), maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.title(22)),
                            const SizedBox(height: 4),
                            Text('Победы ${_wins(monthList)} • Ничьи ${_draws(monthList)} • Поражения ${_losses(monthList)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.muted(12.5)),
                          ],
                        ),
                      ),
                      _TopActionButton(icon: Icons.today_rounded, text: 'Этот месяц', onTap: _thisMonth),
                      const SizedBox(width: 8),
                      _SquareButton(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
                      const SizedBox(width: 8),
                      _SquareButton(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
                    ],
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(isPhone ? 12 : 14),
            child: _buildStatsRow(monthList, isPhone: isPhone),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(isPhone ? 10 : 14, 0, isPhone ? 10 : 14, isPhone ? 10 : 14),
              child: _MonthMatchesGrid(
                key: ValueKey('matches-calendar-${selectedMonth.year}-${selectedMonth.month}-$calendarRevision'),
                month: selectedMonth,
                selectedDay: selectedDay,
                matchesByDay: monthMap,
                dateText: _dateRu,
                compact: isPhone,
                onDayTap: (day, list) {
                  setState(() {
                    selectedDay = day;
                    calendarRevision++;
                  });

                  if (list.isEmpty) return;

                  if (isPhone && list.length == 1) {
                    _showMatchPreviewSheet(list.first);
                    return;
                  }

                  _showDayMatches(day, list);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<Map<String, dynamic>> monthList, {bool isPhone = false}) {
    final goalsFor = monthList.fold<int>(0, (v, m) => v + _i(m['our_score']));
    final goalsAgainst = monthList.fold<int>(0, (v, m) => v + _i(m['opponent_score']));
    final cards = [
      _MetricCard(icon: Icons.sports_soccer_rounded, title: 'Матчи', value: '${monthList.length}', compact: isPhone),
      _MetricCard(icon: Icons.trending_up_rounded, title: 'Голы', value: '$goalsFor:$goalsAgainst', compact: isPhone),
      _MetricCard(icon: Icons.emoji_events_outlined, title: 'Победы', value: '${_wins(monthList)}', compact: isPhone),
      _MetricCard(icon: Icons.timeline_rounded, title: 'Баланс', value: '${_wins(monthList)}-${_draws(monthList)}-${_losses(monthList)}', compact: isPhone),
    ];

    if (isPhone) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.65,
        children: cards,
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 10),
        Expanded(child: cards[1]),
        const SizedBox(width: 10),
        Expanded(child: cards[2]),
        const SizedBox(width: 10),
        Expanded(child: cards[3]),
      ],
    );
  }

  Future<void> _showDayMatches(DateTime day, List<Map<String, dynamic>> list) async {
    if (!mounted) return;

    final isPhone = (MediaQuery.maybeOf(context)?.size.width ?? 1000) < 600;

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: isPhone ? .62 : .46,
        minChildSize: isPhone ? .42 : .28,
        maxChildSize: .90,
        expand: false,
        builder: (_, scrollController) => Container(
          margin: EdgeInsets.fromLTRB(isPhone ? 8 : 12, 0, isPhone ? 8 : 12, isPhone ? 8 : 12),
          decoration: _CmrMatchDecor.panel(),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.all(isPhone ? 12 : 14),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _CmrMatchColors.soft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _CmrIconBox(icon: Icons.sports_soccer_rounded, size: isPhone ? 36 : 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Матчи • ${_dateRu(day)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrMatchText.title(isPhone ? 17 : 18),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...list.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CmrMatchTile(
                      eventType: _eventTypeLabel(_s(m['event_type'])),
                      opponent: _s(m['opponent']),
                      date: _dateRu(_parseDate(_s(m['match_date']))),
                      competition: _s(m['competition_name']),
                      stadium: _s(m['stadium']),
                      score: '${_i(m['our_score'])}:${_i(m['opponent_score'])}',
                      upcoming: _isUpcoming(_parseDate(_s(m['match_date']))),
                      active: _matchId(m) == selectedMatchId,
                      canEdit: canEdit,
                      compact: isPhone,
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await Future.delayed(const Duration(milliseconds: 80));
                        await _handleMatchTap(m);
                      },
                      onDelete: () => _deleteMatch(m),
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

  Future<void> _showMatchPreviewSheet(Map<String, dynamic> match) async {
    if (!mounted) return;

    final opponent = _s(match['opponent']).isEmpty ? 'Соперник' : _s(match['opponent']);
    final eventType = _eventTypeLabel(_s(match['event_type']));
    final date = _dateRu(_parseDate(_s(match['match_date'])));
    final score = '${_i(match['our_score'])}:${_i(match['opponent_score'])}';
    final competition = _s(match['competition_name']);
    final tour = _s(match['tour_label']);
    final stadium = _s(match['stadium']);
    final referees = _s(match['referees']);
    final notes = _s(match['notes']);
    final upcoming = _isUpcoming(_parseDate(_s(match['match_date'])));

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: .68,
          minChildSize: .42,
          maxChildSize: .92,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              decoration: _CmrMatchDecor.panel(),
              child: SafeArea(
                top: false,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _CmrMatchColors.soft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CmrIconBox(icon: Icons.sports_soccer_rounded, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opponent,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _CmrMatchText.title(20),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$eventType • $date',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _CmrMatchText.muted(12.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _CmrMatchDecor.softCard(radius: 22),
                      child: Row(
                        children: [
                          Expanded(
                            child: _MatchPreviewStat(
                              title: 'Счёт',
                              value: score,
                              icon: Icons.scoreboard_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MatchPreviewStat(
                              title: upcoming ? 'Статус' : 'Итог',
                              value: upcoming ? 'Скоро' : 'Архив',
                              icon: upcoming ? Icons.event_available_rounded : Icons.history_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MatchInfoRow(icon: Icons.emoji_events_outlined, title: 'Турнир', value: competition.isEmpty ? 'Не указан' : competition),
                    _MatchInfoRow(icon: Icons.flag_rounded, title: 'Тур', value: tour.isEmpty ? 'Не указан' : tour),
                    _MatchInfoRow(icon: Icons.stadium_rounded, title: 'Стадион', value: stadium.isEmpty ? 'Не указан' : stadium),
                    _MatchInfoRow(icon: Icons.sports_rounded, title: 'Судьи', value: referees.isEmpty ? 'Не указаны' : referees),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: _CmrMatchDecor.softCard(radius: 18),
                        child: Text(
                          notes,
                          style: _CmrMatchText.value(12.5),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _SheetPrimaryButton(
                            icon: Icons.open_in_new_rounded,
                            text: 'Открыть матч',
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await Future.delayed(const Duration(milliseconds: 80));
                              await _openDetails(match);
                            },
                          ),
                        ),
                        if (canEdit) ...[
                          const SizedBox(width: 10),
                          _SheetIconButton(
                            icon: Icons.delete_outline_rounded,
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await Future.delayed(const Duration(milliseconds: 80));
                              await _deleteMatch(match);
                            },
                          ),
                        ],
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
  }
}

// ==================== Компоненты ====================


class _MatchKpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String hint;

  const _MatchKpiData({required this.label, required this.value, required this.icon, required this.color, required this.hint});
}

class _MatchInfoCell extends StatelessWidget {
  final _MatchKpiData item;

  const _MatchInfoCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final tint = Color.alphaBlend(item.color.withOpacity(.065), Colors.white);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(item.color.withOpacity(.045), Colors.white),
        borderRadius: BorderRadius.circular(13),
        boxShadow: _CmrMatchDecor.microShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 7),
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(color: item.color.withOpacity(.075), borderRadius: BorderRadius.circular(8)),
            child: Icon(item.icon, color: item.color, size: 13),
          ),
          const SizedBox(width: 7),
          Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.value(13.8)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.caption().copyWith(color: _CmrMatchColors.text, fontSize: 9.35)),
                const SizedBox(height: 2),
                Text(item.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.caption().copyWith(fontSize: 8.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _MatchSideKpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final Color color;

  const _MatchSideKpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = Color.alphaBlend(color.withOpacity(.055), Colors.white);
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(.045), Colors.white),
        borderRadius: BorderRadius.circular(14),
        boxShadow: _CmrMatchDecor.microShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(color.withOpacity(.08), Colors.white),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 11.5),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: _CmrMatchText.value(14.8),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _CmrMatchText.caption().copyWith(color: _CmrMatchColors.text, fontSize: 9.25),
          ),
          const SizedBox(height: 1),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _CmrMatchText.caption().copyWith(fontSize: 8.35),
          ),
        ],
      ),
    );
  }
}

class _MatchNextStrip extends StatelessWidget {
  final String opponent;
  final String meta;
  final String score;
  final Color color;

  const _MatchNextStrip({
    required this.opponent,
    required this.meta,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color == _CmrMatchColors.muted ? _CmrMatchColors.blue : color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withOpacity(.045), Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _CmrMatchDecor.microShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 9),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Color.alphaBlend(accent.withOpacity(.08), Colors.white),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.event_available_rounded, color: accent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(opponent, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.title(13.8)),
                const SizedBox(height: 3),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.muted(10.8)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ProfileScoreBadge(score: score, color: accent, compact: true),
        ],
      ),
    );
  }
}


class _MatchTopLine extends StatelessWidget {
  final String label;
  final String value;
  final String subvalue;
  final IconData icon;
  final Color color;

  const _MatchTopLine({required this.label, required this.value, required this.subvalue, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final tint = Color.alphaBlend(color.withOpacity(.09), Colors.white);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(.045), Colors.white),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _CmrMatchDecor.microShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(width: 7),
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 13),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.caption().copyWith(fontSize: 9.05)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.action().copyWith(fontSize: 10.75))),
                    const SizedBox(width: 5),
                    Flexible(child: Text(subvalue, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.caption().copyWith(fontSize: 9.05))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



class _StrictMatchesCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final bool dense;

  const _StrictMatchesCard({required this.icon, required this.title, required this.subtitle, required this.child, this.trailing, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final accent = _matchWinAccent(icon.codePoint);
    final outerPadding = dense ? 10.0 : 12.0;
    final iconSize = dense ? 36.0 : 40.0;

    final header = Row(
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: _CmrMatchDecor.fluentSurface(
            radius: dense ? 13 : 14,
            accent: accent,
            elevated: false,
          ),
          child: Icon(icon, color: accent, size: dense ? 17 : 19),
        ),
        SizedBox(width: dense ? 8 : 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrMatchText.title(dense ? 14.0 : 16.0),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrMatchText.muted(dense ? 10.4 : 11.3),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[SizedBox(width: dense ? 6 : 8), trailing!],
      ],
    );

    return Container(
      decoration: _CmrMatchDecor.seamlessPane(),
      padding: EdgeInsets.all(outerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          SizedBox(height: dense ? 10 : 12),
          if (dense) child else Expanded(child: child),
        ],
      ),
    );
  }
}


class _WorkspaceIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _WorkspaceIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emphasized = icon == Icons.add_rounded;
    final radius = BorderRadius.circular(13);
    final accent = emphasized ? _CmrMatchColors.green : _CmrMatchColors.icon;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: _CmrMatchDecor.fluentSurface(
            radius: 13,
            accent: emphasized ? _CmrMatchColors.green : _CmrMatchColors.blue,
            active: emphasized,
            elevated: false,
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
      ),
    );
  }
}


class _KindFilterChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _KindFilterChip({required this.icon, required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _CmrMatchDecor.fluentSurface(
            radius: 999,
            accent: _CmrMatchColors.green,
            active: active,
            elevated: false,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? _CmrMatchColors.green : _CmrMatchColors.muted2),
              const SizedBox(width: 7),
              Text(
                text,
                style: _CmrMatchText.action().copyWith(
                  color: active ? _CmrMatchColors.greenDark : _CmrMatchColors.text.withOpacity(.78),
                  fontSize: 11.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SegmentedTab extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _SegmentedTab({required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: _CmrMatchDecor.fluentSurface(
            radius: 14,
            accent: _CmrMatchColors.green,
            active: active,
            elevated: false,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (active) ...[
                Container(width: 5, height: 5, decoration: const BoxDecoration(color: _CmrMatchColors.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CmrMatchText.action().copyWith(
                    color: active ? _CmrMatchColors.greenDark : _CmrMatchColors.text.withOpacity(.70),
                    fontSize: 11.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _TeamLogoCircle extends StatelessWidget {
  final bool active;
  final bool compact;

  const _TeamLogoCircle({required this.active, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 46.0 : 52.0;
    final accent = active ? _CmrMatchColors.green : _CmrMatchColors.blue;
    return Container(
      width: size,
      height: size,
      decoration: _CmrMatchDecor.fluentSurface(
        radius: size * .34,
        accent: accent,
        active: active,
        elevated: false,
      ),
      child: Icon(Icons.sports_soccer_rounded, color: accent, size: compact ? 23 : 26),
    );
  }
}


class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  final bool compact;

  const _StatusPill({required this.text, required this.color, required this.icon, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 6 : 7),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(.055), Colors.white),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: color.withOpacity(.07), blurRadius: 14, spreadRadius: -10, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 13, color: color),
          const SizedBox(width: 5),
          Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.pill(color: color).copyWith(fontSize: compact ? 10.8 : 11.5)),
        ],
      ),
    );
  }
}


class _DetailsGroup extends StatelessWidget {
  final List<Widget> children;

  const _DetailsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: null,
      ),
      child: Column(children: children),
    );
  }
}


class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.icon, required this.title, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _CmrMatchColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _CmrMatchText.muted(12.1).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: _CmrMatchText.value(12.2).copyWith(color: valueColor ?? _CmrMatchColors.text, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DetailsActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final accent = _matchWinAccent(icon.codePoint);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: _CmrMatchDecor.fluentSurface(
            radius: 15,
            accent: accent,
            active: enabled,
            elevated: false,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: enabled ? accent : _CmrMatchColors.muted2),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: enabled ? _CmrMatchText.action().copyWith(fontSize: 11.15, color: _CmrMatchColors.text) : _CmrMatchText.caption().copyWith(color: _CmrMatchColors.muted2, fontSize: 11.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SelectedDateChip extends StatelessWidget {
  final String text;
  final VoidCallback onClear;

  const _SelectedDateChip({required this.text, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: _CmrMatchDecor.fluentSurface(
        radius: 999,
        accent: _CmrMatchColors.green,
        active: true,
        elevated: false,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_alt_rounded, color: _CmrMatchColors.green, size: 15),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _CmrMatchText.action().copyWith(color: _CmrMatchColors.greenDark, fontSize: 11.5),
            ),
          ),
          const SizedBox(width: 7),
          InkWell(borderRadius: BorderRadius.circular(99), onTap: onClear, child: const Icon(Icons.close_rounded, color: _CmrMatchColors.green, size: 15)),
        ],
      ),
    );
  }
}


class _ProfileRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ProfileRoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emphasized = icon == Icons.add_rounded;
    final radius = BorderRadius.circular(13);
    final accent = emphasized ? _CmrMatchColors.green : _CmrMatchColors.icon;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: _CmrMatchDecor.fluentSurface(
            radius: 13,
            accent: emphasized ? _CmrMatchColors.green : _CmrMatchColors.blue,
            active: emphasized,
            elevated: false,
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
      ),
    );
  }
}


class _ProfileCalendarArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ProfileCalendarArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF334155), size: 18),
      ),
    );
  }
}


class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _ProfileActionButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: _CmrMatchDecor.fluentSurface(
          radius: 999,
          accent: _CmrMatchColors.green,
          active: enabled,
          elevated: false,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: enabled ? _CmrMatchColors.green : _CmrMatchColors.muted),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(color: enabled ? _CmrMatchColors.greenDark : _CmrMatchColors.muted, fontSize: 11.55, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}



class _ProfileScoreBadge extends StatelessWidget {
  final String score;
  final Color color;
  final bool compact;

  const _ProfileScoreBadge({required this.score, required this.color, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 50 : 56),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 7 : 8),
      decoration: _CmrMatchDecor.fluentSurface(
        radius: 15,
        accent: color,
        active: true,
        elevated: false,
      ),
      child: Text(score, textAlign: TextAlign.center, style: _CmrMatchText.action().copyWith(color: color, fontSize: compact ? 12.4 : 13.2)),
    );
  }
}

class _ProfileMetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ProfileMetaPill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: Color.alphaBlend(color.withOpacity(.065), Colors.white), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10.75, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileNoteBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _ProfileNoteBlock({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(color: _CmrMatchColors.soft, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 1),
          Icon(icon, size: 14, color: _CmrMatchColors.icon),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(color: Color(0xFF475467), fontSize: 11.05, fontWeight: FontWeight.w600, height: 1.35),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(color: Color(0xFF101828), fontSize: 11.05, fontWeight: FontWeight.w600, height: 1.35)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactProfileButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool compact;

  const _CompactProfileButton({required this.icon, required this.label, required this.onTap, required this.compact});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 12, vertical: compact ? 7 : 9),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : _CmrMatchColors.soft,
          borderRadius: BorderRadius.circular(999),
          border: null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 12 : 14, color: enabled ? _CmrMatchColors.icon : _CmrMatchColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: enabled ? _CmrMatchColors.text : _CmrMatchColors.muted, fontSize: compact ? 11.0 : 11.8, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}



class _LargeGreenButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _LargeGreenButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: _CmrMatchDecor.fluentSurface(
          radius: 12,
          accent: _CmrMatchColors.green,
          active: enabled,
          elevated: false,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? _CmrMatchColors.green : _CmrMatchColors.muted, size: 16),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(color: enabled ? _CmrMatchColors.greenDark : _CmrMatchColors.muted, fontSize: 12.55, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}


class _DetailInfoPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _DetailInfoPill({required this.icon, required this.title, required this.value, this.color = _CmrMatchColors.green});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Color.alphaBlend(color.withOpacity(.065), Colors.white), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text('$title: ', style: TextStyle(color: color, fontSize: 10.95, fontWeight: FontWeight.w600)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 10.95, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _MonthMatchesGrid extends StatelessWidget {
  final DateTime month;
  final DateTime? selectedDay;
  final Map<DateTime, List<Map<String, dynamic>>> matchesByDay;
  final String Function(DateTime) dateText;
  final void Function(DateTime day, List<Map<String, dynamic>> matches) onDayTap;
  final bool compact;
  final double? maxHeight;

  const _MonthMatchesGrid({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.matchesByDay,
    required this.dateText,
    required this.onDayTap,
    this.compact = false,
    this.maxHeight,
  });

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Color _matchBadgeColor(Map<String, dynamic> match) {
    final ourRaw = '${match['our_score'] ?? ''}'.trim();
    final oppRaw = '${match['opponent_score'] ?? ''}'.trim();
    if (ourRaw.isEmpty && oppRaw.isEmpty) return _CmrMatchColors.blue;
    final our = int.tryParse(ourRaw) ?? 0;
    final opp = int.tryParse(oppRaw) ?? 0;
    if (our > opp) return _CmrMatchColors.green;
    if (our == opp) return _CmrMatchColors.amber;
    return _CmrMatchColors.red;
  }

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final prevMonthDays = DateTime(month.year, month.month, 0).day;
    final leading = first.weekday - 1;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final rowsCount = total ~/ 7;

    return Column(
      children: [
        Row(
          children: weekdays
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        color: _CmrMatchColors.muted,
                        fontSize: 10.55,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, gridBox) {
            const gap = 5.0;
            final availableWidth = gridBox.maxWidth.isFinite ? gridBox.maxWidth : MediaQuery.sizeOf(context).width;
            final maxGridHeight = maxHeight != null && maxHeight!.isFinite ? math.max(180.0, maxHeight! - 20.0) : null;
            final cellWidth = (availableWidth - gap * 6) / 7;
            final naturalCellHeight = cellWidth / 1.22;
            final fittedCellHeight = maxGridHeight == null
                ? naturalCellHeight
                : (maxGridHeight - gap * (rowsCount - 1)) / rowsCount;
            final cellHeight = maxGridHeight == null
                ? naturalCellHeight
                : math.max(36.0, math.min(naturalCellHeight, fittedCellHeight));
            final ratio = math.max(.82, math.min(2.75, cellWidth / cellHeight));

            return GridView.builder(
              key: ValueKey('cmr-matches-calendar-${month.year}-${month.month}-${selectedDay?.toIso8601String() ?? 'none'}'),
              itemCount: total,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: ratio,
              ),
              itemBuilder: (_, index) {
                final dayNumber = index - leading + 1;
                late DateTime day;
                var inMonth = true;

                if (dayNumber < 1) {
                  day = DateTime(month.year, month.month - 1, prevMonthDays + dayNumber);
                  inMonth = false;
                } else if (dayNumber > daysInMonth) {
                  day = DateTime(month.year, month.month + 1, dayNumber - daysInMonth);
                  inMonth = false;
                } else {
                  day = DateTime(month.year, month.month, dayNumber);
                }

                final dayKey = DateTime(day.year, day.month, day.day);
                final list = matchesByDay[dayKey] ?? const <Map<String, dynamic>>[];
                final hasMatches = list.isNotEmpty;
                final now = DateTime.now();
                final isToday = _sameDay(day, DateTime(now.year, now.month, now.day));
                final isSelected = selectedDay != null && _sameDay(day, selectedDay!);

                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onDayTap(day, list),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(.96)
                            : hasMatches
                                ? _CmrMatchColors.iconSoft2
                                : _CmrMatchColors.soft,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected ? Border.all(color: _CmrMatchColors.greenBorder) : null,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                color: isSelected
                                    ? _CmrMatchColors.greenDark
                                    : inMonth
                                        ? (isToday ? _CmrMatchColors.icon : _CmrMatchColors.text)
                                        : _CmrMatchColors.muted.withOpacity(.64),
                                fontSize: maxHeight == null ? 13 : 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (hasMatches)
                            Positioned(
                              top: 2,
                              right: 3,
                              child: _SegmentedMatchBadge(
                                colors: list.map(_matchBadgeColor).take(3).toList(growable: false),
                                count: list.length,
                                size: maxHeight == null ? 16 : 15,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _SegmentedMatchBadge extends StatelessWidget {
  final List<Color> colors;
  final int count;
  final double size;

  const _SegmentedMatchBadge({required this.colors, required this.count, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SegmentedMatchBadgePainter(colors: colors, borderColor: Colors.white),
        child: count > 1
            ? Center(
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.4,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _SegmentedMatchBadgePainter extends CustomPainter {
  final List<Color> colors;
  final Color borderColor;

  const _SegmentedMatchBadgePainter({required this.colors, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final safeColors = colors.isEmpty ? const [_CmrMatchColors.green] : colors;
    final fill = Paint()..style = PaintingStyle.fill;
    if (safeColors.length == 1) {
      fill.color = safeColors.first;
      canvas.drawOval(rect, fill);
    } else {
      final sweep = (math.pi * 2) / safeColors.length;
      var start = -math.pi / 2;
      for (final color in safeColors) {
        fill.color = color;
        canvas.drawArc(rect, start, sweep, true, fill);
        start += sweep;
      }
    }
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = borderColor;
    canvas.drawOval(rect.deflate(.75), border);
  }

  @override
  bool shouldRepaint(covariant _SegmentedMatchBadgePainter oldDelegate) {
    if (oldDelegate.borderColor != borderColor) return true;
    if (oldDelegate.colors.length != colors.length) return true;
    for (var i = 0; i < colors.length; i++) {
      if (oldDelegate.colors[i] != colors[i]) return true;
    }
    return false;
  }
}

class _MatchPreviewStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MatchPreviewStat({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _CmrMatchColors.panel,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _CmrMatchColors.icon, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrMatchText.value(16),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrMatchText.caption(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _MatchInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: _CmrMatchDecor.softCard(radius: 18),
        child: Row(
          children: [
            Icon(icon, color: _CmrMatchColors.icon, size: 16),
            const SizedBox(width: 10),
            SizedBox(
              width: 76,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrMatchText.caption(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _CmrMatchText.value(13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _SheetPrimaryButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrMatchColors.green,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.05),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SheetIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrMatchColors.panel,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          child: Icon(icon, color: _CmrMatchColors.muted),
        ),
      ),
    );
  }
}

class _CmrAddMatchSheet extends StatefulWidget {
  final Future<bool> Function({
    required String eventType,
    required String opponent,
    required String ourScore,
    required String opponentScore,
    required String matchDate,
    required String competitionName,
    required String tourLabel,
    required String stadium,
    required String referees,
    required String notes,
  }) onSubmit;
  final bool embedded;
  final VoidCallback? onClose;
  final Future<void> Function()? onSaved;

  const _CmrAddMatchSheet({
    required this.onSubmit,
    this.embedded = false,
    this.onClose,
    this.onSaved,
  });

  @override
  State<_CmrAddMatchSheet> createState() => _CmrAddMatchSheetState();
}

class _CmrAddMatchSheetState extends State<_CmrAddMatchSheet> {
  final opponent = TextEditingController();
  final ourScore = TextEditingController(text: '0');
  final opponentScore = TextEditingController(text: '0');
  final competition = TextEditingController();
  final tour = TextEditingController();
  final stadium = TextEditingController();
  final referees = TextEditingController();
  final notes = TextEditingController();

  DateTime? picked;
  bool saving = false;
  String eventType = 'championship';

  @override
  void dispose() {
    opponent.dispose();
    ourScore.dispose();
    opponentScore.dispose();
    competition.dispose();
    tour.dispose();
    stadium.dispose();
    referees.dispose();
    notes.dispose();
    super.dispose();
  }

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _ru(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      initialDate: picked ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3, 12, 31),
      helpText: 'Выберите дату матча',
    );
    if (res != null) setState(() => picked = DateTime(res.year, res.month, res.day));
  }

  Future<void> _submit() async {
    if (opponent.text.trim().isEmpty || picked == null) {
      Get.snackbar('Ошибка', 'Заполните соперника и дату матча');
      return;
    }
    setState(() => saving = true);
    try {
      final ok = await widget.onSubmit(
        eventType: eventType,
        opponent: opponent.text,
        ourScore: ourScore.text,
        opponentScore: opponentScore.text,
        matchDate: _iso(picked!),
        competitionName: competition.text,
        tourLabel: tour.text,
        stadium: stadium.text,
        referees: referees.text,
        notes: notes.text,
      );
      if (ok && mounted) {
        if (widget.embedded) {
          await widget.onSaved?.call();
        } else {
          Navigator.pop(context, true);
        }
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget form({required bool includeHeader, required EdgeInsets padding}) {
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (includeHeader) ...[
              Row(
                children: [
                  _CmrIconBox(icon: Icons.add_rounded),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Добавить матч', style: _CmrMatchText.title(19))),
                  IconButton(onPressed: saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _CmrFieldShell(
              child: DropdownButtonFormField<String>(
                value: eventType,
                decoration: const InputDecoration(border: InputBorder.none, labelText: 'Тип матча'),
                items: const [
                  DropdownMenuItem(value: 'championship', child: Text('Чемпионат')),
                  DropdownMenuItem(value: 'friendly', child: Text('Товарищеский')),
                  DropdownMenuItem(value: 'tournament', child: Text('Турнир')),
                ],
                onChanged: saving ? null : (v) => setState(() => eventType = v ?? 'championship'),
              ),
            ),
            const SizedBox(height: 10),
            _CmrTextField(controller: opponent, icon: Icons.shield_outlined, hint: 'Соперник', onChanged: (_) => setState(() {})),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _CmrTextField(controller: ourScore, icon: Icons.looks_one_rounded, hint: 'Наш счёт', keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _CmrTextField(controller: opponentScore, icon: Icons.looks_two_rounded, hint: 'Счёт соперника', keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 10),
            _CmrFieldShell(
              onTap: saving ? null : _pickDate,
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 18, color: _CmrMatchColors.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      picked == null ? 'Выбрать дату матча' : _ru(picked!),
                      style: _CmrMatchText.value(14).copyWith(
                        color: picked == null ? _CmrMatchColors.muted : _CmrMatchColors.text,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _CmrMatchColors.muted),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _CmrTextField(controller: competition, icon: Icons.emoji_events_outlined, hint: 'Турнир / соревнование'),
            const SizedBox(height: 10),
            _CmrTextField(controller: tour, icon: Icons.format_list_numbered_rounded, hint: 'Тур / этап'),
            const SizedBox(height: 10),
            _CmrTextField(controller: stadium, icon: Icons.location_on_outlined, hint: 'Стадион'),
            const SizedBox(height: 10),
            _CmrTextField(controller: referees, icon: Icons.gavel_rounded, hint: 'Судьи'),
            const SizedBox(height: 10),
            _CmrTextField(controller: notes, icon: Icons.notes_rounded, hint: 'Примечания', maxLines: widget.embedded ? 4 : 3),
            const SizedBox(height: 14),
            Row(
              children: [
                if (widget.embedded) ...[
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : widget.onClose,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Отмена'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _CmrMatchColors.muted,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: widget.embedded ? 2 : 1,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: !saving && opponent.text.trim().isNotEmpty && picked != null ? _submit : null,
                      icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                      label: Text(saving ? 'Сохранение...' : 'Сохранить матч'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _CmrMatchColors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (widget.embedded) {
      return form(includeHeader: false, padding: EdgeInsets.zero);
    }

    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          margin: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 720),
          decoration: _CmrMatchDecor.panel(),
          child: form(includeHeader: true, padding: const EdgeInsets.all(16)),
        ),
      ),
    );
  }
}

class _CmrMatchTile extends StatelessWidget {
  final String eventType;
  final String opponent;
  final String date;
  final String competition;
  final String stadium;
  final String score;
  final bool upcoming;
  final bool active;
  final bool canEdit;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CmrMatchTile({
    required this.eventType,
    required this.opponent,
    required this.date,
    required this.competition,
    required this.stadium,
    required this.score,
    required this.upcoming,
    required this.canEdit,
    required this.onTap,
    required this.onDelete,
    this.active = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = opponent.trim().isEmpty ? 'Соперник' : opponent.trim();
    final primaryMeta = [eventType, date].where((e) => e.trim().isNotEmpty).join('  •  ');
    final secondaryMeta = [competition, stadium].where((e) => e.trim().isNotEmpty).join('  •  ');
    final radius = BorderRadius.circular(11);
    final stripHeight = compact ? 42.0 : 46.0;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 10, vertical: compact ? 8 : 9),
          decoration: BoxDecoration(
            color: _CmrMatchColors.panel,
            borderRadius: radius,
            border: null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(.035),
                      blurRadius: 12,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: 3,
                height: stripHeight,
                decoration: BoxDecoration(
                  color: active ? _CmrMatchColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(width: active ? 8 : 6),
              _MatchEventAvatar(active: active, upcoming: upcoming, compact: compact),
              SizedBox(width: compact ? 9 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrMatchText.title(compact ? 13.4 : 14.2),
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 6),
                          const _MatchActiveDot(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      primaryMeta.isEmpty ? 'Матч команды' : primaryMeta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrMatchText.muted(compact ? 10.8 : 11.2),
                    ),
                    if (!compact && secondaryMeta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        secondaryMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrMatchText.muted(10.8).copyWith(color: _CmrMatchColors.muted2),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              _MatchScoreMiniBadge(score: score, active: active, compact: compact),
              if (!compact) ...[
                const SizedBox(width: 8),
                if (canEdit)
                  _MatchActionBadge(active: active, onDelete: onDelete)
                else
                  _MatchChevronBadge(active: active),
              ] else if (canEdit) ...[
                const SizedBox(width: 6),
                _MatchActionBadge(active: active, onDelete: onDelete, compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchActiveDot extends StatelessWidget {
  const _MatchActiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _CmrMatchColors.green,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: _CmrMatchColors.green.withOpacity(.26), blurRadius: 10, spreadRadius: 1)],
      ),
    );
  }
}


class _MatchEventAvatar extends StatelessWidget {
  final bool active;
  final bool upcoming;
  final bool compact;

  const _MatchEventAvatar({required this.active, required this.upcoming, required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 44.0;
    final accent = active ? _CmrMatchColors.green : (upcoming ? _CmrMatchColors.blue : _CmrMatchColors.violet);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      width: size,
      height: size,
      decoration: _CmrMatchDecor.fluentSurface(
        radius: 14,
        accent: accent,
        active: active,
        elevated: false,
      ),
      child: Icon(
        upcoming ? Icons.sports_soccer_rounded : Icons.history_rounded,
        color: accent,
        size: compact ? 20 : 22,
      ),
    );
  }
}


class _MatchScoreMiniBadge extends StatelessWidget {
  final String score;
  final bool active;
  final bool compact;

  const _MatchScoreMiniBadge({required this.score, required this.active, required this.compact});

  @override
  Widget build(BuildContext context) {
    final value = score.trim().isEmpty ? '—' : score.trim();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      constraints: BoxConstraints(minWidth: compact ? 42 : 48),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 6 : 7),
      decoration: _CmrMatchDecor.fluentSurface(
        radius: 999,
        accent: _CmrMatchColors.green,
        active: active,
        elevated: false,
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _CmrMatchText.value(compact ? 12.8 : 13.6).copyWith(
          color: active ? _CmrMatchColors.greenDark : _CmrMatchColors.text,
        ),
      ),
    );
  }
}


class _MatchChevronBadge extends StatelessWidget {
  final bool active;

  const _MatchChevronBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      width: 30,
      height: 30,
      decoration: _CmrMatchDecor.fluentSurface(
        radius: 10,
        accent: _CmrMatchColors.green,
        active: active,
        elevated: false,
      ),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 19,
        color: active ? _CmrMatchColors.green : _CmrMatchColors.muted,
      ),
    );
  }
}


class _MatchActionBadge extends StatelessWidget {
  final bool active;
  final bool compact;
  final VoidCallback onDelete;

  const _MatchActionBadge({required this.active, required this.onDelete, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Дополнительно',
      elevation: 14,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      icon: Container(
        width: compact ? 28 : 30,
        height: compact ? 28 : 30,
        decoration: _CmrMatchDecor.fluentSurface(
          radius: 10,
          accent: _CmrMatchColors.green,
          active: active,
          elevated: false,
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          color: active ? _CmrMatchColors.green : _CmrMatchColors.muted,
          size: compact ? 17 : 18,
        ),
      ),
      onSelected: (v) {
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, color: _CmrMatchColors.red, size: 16),
              const SizedBox(width: 8),
              Text('Удалить', style: _CmrMatchText.danger()),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool active;
  final bool compact;

  const _MiniBadge({required this.text, required this.icon, required this.active, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 8, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        color: _CmrMatchColors.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 12, color: active ? _CmrMatchColors.icon : _CmrMatchColors.muted),
          const SizedBox(width: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _CmrMatchText.pill().copyWith(
              color: active ? _CmrMatchColors.icon : _CmrMatchColors.muted,
              fontSize: compact ? 10.2 : 10.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool compact;

  const _MetricCard({required this.icon, required this.title, required this.value, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 7 : 9),
      decoration: _CmrMatchDecor.softCard(radius: compact ? 14 : 17),
      child: Row(
        children: [
          Icon(icon, color: _CmrMatchColors.icon, size: compact ? 13 : 15),
          SizedBox(width: compact ? 6 : 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.value(compact ? 12.8 : 14.4)),
                const SizedBox(height: 1),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.caption().copyWith(fontSize: compact ? 9.4 : 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedMatchesHeader extends StatelessWidget {
  final String title;
  final bool canEdit;
  final bool compact;
  final VoidCallback onAdd;

  const _SelectedMatchesHeader({required this.title, required this.canEdit, required this.onAdd, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.title(compact ? 14 : 15))),
        if (canEdit) _TopActionButton(icon: Icons.add_rounded, text: compact ? 'Добавить' : 'Матч', compact: compact, onTap: onAdd),
      ],
    );
  }
}

class _CmrSearch extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onClear;
  final bool compact;

  const _CmrSearch({required this.controller, required this.hint, required this.onClear, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return _CmrFieldShell(
      compact: compact,
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: compact ? 17 : 19, color: _CmrMatchColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: _CmrMatchText.value(compact ? 13 : 14),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                hintStyle: _CmrMatchText.muted(compact ? 12.5 : 14),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (controller.text.isNotEmpty) IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear),
        ],
      ),
    );
  }
}

class _CmrTextField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _CmrTextField({required this.controller, required this.icon, required this.hint, this.keyboardType, this.maxLines = 1, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _CmrFieldShell(
      child: Row(crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
        Padding(padding: EdgeInsets.only(top: maxLines > 1 ? 10 : 0), child: Icon(icon, size: 18, color: _CmrMatchColors.muted)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isDense: true,
              hintStyle: _CmrMatchText.muted(13),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CmrFieldShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool compact;

  const _CmrFieldShell({required this.child, this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 7 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.78),
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: Colors.white.withOpacity(.82)),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(compact ? 15 : 17), onTap: onTap, child: box),
    );
  }
}

class _ArchiveMonthChip extends StatelessWidget {
  final String title;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _ArchiveMonthChip({required this.title, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _matchWinAccent(title.hashCode);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _CmrMatchDecor.fluentSurface(
            radius: 16,
            accent: accent,
            active: active,
            elevated: false,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: _CmrMatchText.tab().copyWith(color: active ? accent : _CmrMatchColors.text)),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: active ? Color.alphaBlend(accent.withOpacity(.08), Colors.white) : _matchWinAccentSoft(count), borderRadius: BorderRadius.circular(99)),
                child: Text('$count', style: _CmrMatchText.caption().copyWith(color: accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveMiniStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ArchiveMiniStat({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: _CmrMatchDecor.softCard(radius: 14),
      child: Row(
        children: [
          Icon(icon, color: _CmrMatchColors.text, size: 13),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CmrMatchText.caption().copyWith(fontSize: 9.15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CmrMatchText.value(12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _FilterButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  final bool compact;

  const _FilterButton({required this.text, required this.active, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        onTap: onTap,
        child: Container(
          height: compact ? 36 : 42,
          alignment: Alignment.center,
          decoration: _CmrMatchDecor.fluentSurface(
            radius: compact ? 14 : 16,
            accent: _CmrMatchColors.green,
            active: active,
            elevated: false,
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _CmrMatchText.tab().copyWith(
              color: active ? _CmrMatchColors.greenDark : _CmrMatchColors.text,
            ),
          ),
        ),
      ),
    );
  }
}


class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool compact;

  const _TopActionButton({required this.icon, required this.text, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(compact ? 15 : 17),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 15 : 17),
        onTap: onTap,
        child: Container(
          height: compact ? 38 : 42,
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
          decoration: _CmrMatchDecor.fluentSurface(
            radius: compact ? 15 : 17,
            accent: _CmrMatchColors.green,
            active: true,
            elevated: false,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 15 : 16, color: _CmrMatchColors.green),
              const SizedBox(width: 6),
              Flexible(
                child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrMatchText.action().copyWith(color: _CmrMatchColors.greenDark, fontSize: compact ? 11.2 : 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const _SquareButton({required this.icon, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 38.0 : 42.0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(compact ? 14 : 15),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 14 : 15),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: _CmrMatchDecor.fluentSurface(
            radius: compact ? 14 : 15,
            accent: _CmrMatchColors.green,
            active: true,
            elevated: false,
          ),
          child: Icon(icon, color: _CmrMatchColors.green, size: compact ? 18 : 21),
        ),
      ),
    );
  }
}


class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: _CmrMatchDecor.fluentSurface(
            radius: 16,
            accent: _CmrMatchColors.green,
            active: true,
            elevated: false,
          ),
          child: Icon(icon, color: _CmrMatchColors.green, size: 18),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String title;
  final bool compact;

  const _HeroStat({required this.value, required this.title, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 9, vertical: compact ? 6 : 8),
      decoration: _CmrMatchDecor.softCard(radius: compact ? 13 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _CmrMatchText.value(compact ? 13 : 15).copyWith(color: _CmrMatchColors.text),
          ),
          const SizedBox(height: 1),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _CmrMatchText.caption().copyWith(fontSize: compact ? 9.2 : 9.8),
          ),
        ],
      ),
    );
  }
}

class _CmrIconBox extends StatelessWidget {
  final IconData icon;
  final bool dark;
  final double size;

  const _CmrIconBox({required this.icon, this.dark = false, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(.08) : _CmrMatchColors.iconSoft,
        borderRadius: BorderRadius.circular(size * .35),
        border: null,
      ),
      child: Icon(icon, color: dark ? Colors.white : _CmrMatchColors.icon, size: size * .48),
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  final String text;

  const _MiniEmpty({required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: _CmrMatchText.muted(13).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
}

class _CmrEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String actionText;
  final VoidCallback onAction;

  const _CmrEmptyState({
    required this.icon,
    required this.title,
    required this.text,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(22),
        decoration: _CmrMatchDecor.panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _CmrMatchColors.icon, size: 38),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: _CmrMatchText.title(18)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: _CmrMatchText.muted(13)),
            const SizedBox(height: 16),
            _TopActionButton(icon: Icons.refresh_rounded, text: actionText, onTap: onAction),
          ],
        ),
      ),
    );
  }
}