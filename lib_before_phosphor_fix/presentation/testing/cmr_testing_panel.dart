// lib/presentation/testing/cmr_testing_panel.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';

// ==================== Цветовая схема (унифицирована с матчами) ====================

class _CmrTestColors {
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF7F8F7);
  static const Color soft2 = Color(0xFFF2F4F2);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF475467);
  static const Color muted2 = Color(0xFF667085);
  static const Color line = Color(0xFFE9ECEA);
  static const Color graphite = Color(0xFF111827);
  static const Color graphite2 = Color(0xFF1F2937);

  // Фирменный зелёный — только как точечный акцент.
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color greenBorder = Color(0xFFD7F0E2);

  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F1);
  static const Color redBorder = Color(0xFFFEE4E2);
  static const Color yellow = Color(0xFFFACC15);
  static const Color orange = Color(0xFFFB923C);
}

// ==================== Текстовые стили ====================

class _CmrTestText {
  static TextStyle title(double size) {
    return AppTypography.custom(
      size: size,
      weight: FontWeight.w600,
      color: _CmrTestColors.text,
      height: 1.10,
      letterSpacing: -0.2,
    );
  }

  static TextStyle section() {
    return AppTypography.custom(
      size: 14,
      weight: FontWeight.w600,
      color: _CmrTestColors.text,
      height: 1.14,
      letterSpacing: -0.14,
    );
  }

  static TextStyle value(double size) {
    return AppTypography.custom(
      size: size,
      weight: FontWeight.w700,
      color: _CmrTestColors.text,
      height: 1.16,
      letterSpacing: -0.12,
    );
  }

  static TextStyle muted(double size) {
    return AppTypography.custom(
      size: size,
      weight: FontWeight.w500,
      color: _CmrTestColors.muted,
      height: 1.28,
    );
  }

  static TextStyle caption() {
    return AppTypography.custom(
      size: 10.5,
      weight: FontWeight.w500,
      color: _CmrTestColors.muted2,
      height: 1.14,
    );
  }

  static TextStyle pill() {
    return AppTypography.custom(
      size: 11,
      weight: FontWeight.w600,
      color: _CmrTestColors.text,
      height: 1,
    );
  }

  static TextStyle tab() {
    return AppTypography.custom(
      size: 11.5,
      weight: FontWeight.w500,
      color: _CmrTestColors.text,
      height: 1,
    );
  }

  static TextStyle tabSelected() {
    return AppTypography.custom(
      size: 11.5,
      weight: FontWeight.w700,
      color: _CmrTestColors.text,
      height: 1,
    );
  }

  static TextStyle action() {
    return AppTypography.custom(
      size: 11.5,
      weight: FontWeight.w700,
      color: _CmrTestColors.text,
      height: 1,
    );
  }

  static TextStyle danger() {
    return AppTypography.custom(
      size: 11.5,
      weight: FontWeight.w600,
      color: _CmrTestColors.red,
      height: 1,
    );
  }
}

// ==================== Декораторы ====================

class _CmrTestDecor {
  static double _radius(double value) => value > 12 ? 12 : value;

  static BoxDecoration panel({double radius = 12}) {
    return BoxDecoration(
      color: _CmrTestColors.panel,
      borderRadius: BorderRadius.circular(_radius(radius)),
      boxShadow: const [],
    );
  }

  static BoxDecoration softCard({double radius = 10, bool active = false}) {
    return BoxDecoration(
      color: active ? _CmrTestColors.greenSoft : const Color(0xFFF7F8F7),
      borderRadius: BorderRadius.circular(_radius(radius)),
    );
  }
}

class CmrTestingPanel extends StatefulWidget {
  final int clubId;
  final int teamId;
  final String clubName;
  final String teamName;
  final String? initialStage;
  final String? initialCategory;
  final int? userId;
  final String? initialDate;
  final int? initialPlayerId;
  final String? initialPlayerName;
  final VoidCallback? onBackToMenu;

  const CmrTestingPanel({
    super.key,
    required this.clubId,
    required this.teamId,
    required this.clubName,
    required this.teamName,
    this.initialStage,
    this.initialCategory,
    this.userId,
    this.initialDate,
    this.initialPlayerId,
    this.initialPlayerName,
    this.onBackToMenu,
  });

  @override
  State<CmrTestingPanel> createState() => _CmrTestingPanelState();
}

class _CmrTestingPanelState extends State<CmrTestingPanel> {
  static const String _playersUrl = 'https://sportotekaapp.ru/api/get_players_by_team.php';

  String category = 'physical';
  String stage = 'U13';
  int sessionId = 0;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> sessions = [];
  bool sessionsLoading = false;
  bool loading = true;
  bool saving = false;
  bool _silentSaving = false;
  Timer? _autosaveTimer;
  String? error;

  bool _infoPanelCollapsed = true;
  String _positionFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _mobilePlayersScrollController = ScrollController();
  bool _mobileToolsCollapsed = false;
  int _focusedPlayerId = 0;
  String _focusedPlayerName = '';

  List<Map<String, dynamic>> stages = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> tests = [];
  List<Map<String, dynamic>> normatives = [];
  List<Map<String, dynamic>> players = [];

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    category = _normalizeInitialCategory(widget.initialCategory) ?? category;
    stage = _initialStageForTeam();
    _selectedDate = _parseDate(widget.initialDate) ?? DateTime.now();
    _focusedPlayerId = widget.initialPlayerId ?? 0;
    _focusedPlayerName = _asStr(widget.initialPlayerName);
    if (_focusedPlayerName.isNotEmpty) {
      _searchController.text = _focusedPlayerName;
    }
    _searchController.addListener(_handleSearchChanged);
    _mobilePlayersScrollController.addListener(_handleMobilePlayersScroll);
    _load();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _mobilePlayersScrollController.removeListener(_handleMobilePlayersScroll);
    _mobilePlayersScrollController.dispose();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleMobilePlayersScroll() {
    if (!mounted || !_mobilePlayersScrollController.hasClients) return;
    final shouldCollapse = _mobilePlayersScrollController.offset > 28;
    if (shouldCollapse != _mobileToolsCollapsed) {
      setState(() => _mobileToolsCollapsed = shouldCollapse);
    }
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _clearFocusedPlayer() {
    _focusedPlayerId = 0;
    _focusedPlayerName = '';
    _searchController.clear();
    if (mounted) setState(() {});
  }

  void _expandMobileTools() {
    if (!_mobileToolsCollapsed) return;
    setState(() => _mobileToolsCollapsed = false);
  }

  String _key(int playerId, String testCode) => '${playerId}_$testCode';

  TextEditingController _ctrl(int playerId, String testCode, dynamic value) {
    final k = _key(playerId, testCode);
    if (!_controllers.containsKey(k)) {
      _controllers[k] = TextEditingController(text: _numText(testCode, value));
    }
    return _controllers[k]!;
  }

  String _numText(String testCode, dynamic v) {
    final raw = '${v ?? ''}'.trim();
    if (raw.isEmpty || raw == 'null') return '';

    final parsed = _toDouble(raw);
    if (parsed == null) return raw.replaceAll('.', ',');

    if (testCode == 'long_jump' && parsed > 0 && parsed < 20) {
      return _formatNumber(parsed * 100, fraction: 0);
    }

    return _formatNumber(parsed, fraction: 2);
  }

  String _formatNumber(num value, {int fraction = 2}) {
    var s = value.toStringAsFixed(fraction).replaceAll('.', ',');
    while (s.contains(',') && s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith(',')) s = s.substring(0, s.length - 1);
    return s;
  }

  double? _toDouble(String raw) {
    final s = raw.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  double? _toNormDouble(dynamic raw) {
    final s = '${raw ?? ''}'.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (s.isEmpty || s == 'null') return null;
    return double.tryParse(s);
  }

  String? _normalizeInitialCategory(String? raw) {
    if (raw == null) return null;
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return null;
    switch (t) {
      case 'physical':
      case 'technical':
      case 'tactical':
      case 'psychological':
      case 'mental':
      case 'theory':
      case 'theoretical':
      case 'medical':
      case 'functional':
        return t;
      default:
        if (t.contains('физ') || t.contains('physical') || t.contains('fitness')) return 'physical';
        if (t.contains('тех') || t.contains('technical') || t.contains('technique')) return 'technical';
        if (t.contains('так') || t.contains('tactical')) return 'tactical';
        if (t.contains('псих') || t.contains('mental') || t.contains('psych')) return 'psychological';
        if (t.contains('теор') || t.contains('theory')) return 'theory';
        if (t.contains('функ') || t.contains('мед') || t.contains('functional') || t.contains('medical')) return 'functional';
        return t;
    }
  }

  String _initialStageForTeam() {
    return _normalizeStage(widget.initialStage) ?? _stageFromText(widget.teamName) ?? 'U13';
  }

  String? _normalizeStage(String? raw) {
    if (raw == null) return null;
    final t = raw.trim().toUpperCase().replaceAll(' ', '');
    final direct = RegExp(r'U-?([0-9]{1,2})').firstMatch(t);
    if (direct != null) {
      final n = int.tryParse(direct.group(1)!);
      if (n != null && n >= 6 && n <= 17) return 'U$n';
    }
    final age = RegExp(r'(^|[^0-9])([6-9]|1[0-7])([^0-9]|$)').firstMatch(t);
    if (age != null) {
      final n = int.tryParse(age.group(2)!);
      if (n != null && n >= 6 && n <= 17) return 'U$n';
    }
    switch (t) {
      case 'МЯЧ':
        return 'U6';
      case 'МЯЧ+ВОРОТА':
      case 'М+ВОРОТА':
      case 'МВ':
        return 'U7';
      case 'МЯЧ+ВОРОТА+СОПЕРНИК':
      case 'М+В+СОПЕРНИК':
      case 'МВС':
        return 'U8';
      case 'МЯЧ+ВОРОТА+СОПЕРНИК+ПАРТНЕР':
      case 'М+В+С+ПАРТНЕР':
      case 'МВСП':
        return 'U9';
    }
    return null;
  }

  String? _stageFromText(String text) {
    return _normalizeStage(text);
  }

  String _asStr(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? 0}') ?? 0;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s.substring(0, s.length >= 10 ? 10 : s.length));
    } catch (_) {
      return null;
    }
  }

  String _dateIso(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.toIso8601String().substring(0, 10);
  }

  String _dateRu(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  String _monthTitle(DateTime d) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasSessionOn(DateTime d) {
    final iso = _dateIso(d);
    return sessions.any((s) => _asStr(s['test_date']) == iso);
  }

  int _sessionIdForDate(DateTime d) {
    final iso = _dateIso(d);
    for (final s in sessions) {
      if (_asStr(s['test_date']) == iso) return _asInt(s['id']);
    }
    return 0;
  }

  Future<void> _loadSessionsOnly() async {
    try {
      final uri = Uri.parse('${TestingApi.base}/get_testing_sessions.php').replace(queryParameters: {
        'club_id': '${widget.clubId}',
        'team_id': '${widget.teamId}',
        'category': category,
        'stage': stage,
      });

      final r = await http.get(uri).timeout(const Duration(seconds: 16));
      final data = _decode(r.body);
      if (data['success'] != true) throw data['message'] ?? 'Не удалось загрузить даты тестирований';
      sessions = _list(data['sessions']);
    } catch (_) {
      sessions = [];
    }
  }

  Future<void> _selectTestingDate(DateTime date) async {
    final clean = DateTime(date.year, date.month, date.day);
    setState(() {
      _selectedDate = clean;
      sessionId = _sessionIdForDate(clean);
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await _loadSessionsOnly();
      final selectedSessionId = _sessionIdForDate(_selectedDate);
      sessionId = selectedSessionId;

      final uri = Uri.parse('${TestingApi.base}/get_testing_matrix.php').replace(queryParameters: {
        'club_id': '${widget.clubId}',
        'team_id': '${widget.teamId}',
        'category': category,
        'stage': stage,
        'test_date': _dateIso(_selectedDate),
        if (selectedSessionId > 0) 'session_id': '$selectedSessionId',
      });

      final r = await http.get(uri);
      final data = _decode(r.body);
      if (data['success'] != true) throw data['message'] ?? 'Не удалось загрузить тестирование';

      final matrixPlayers = selectedSessionId > 0 ? _list(data['players']) : <Map<String, dynamic>>[];
      final teamPlayers = await _fetchTeamPlayers();
      final mergedPlayers = _mergePlayersWithResults(teamPlayers, matrixPlayers);

      _controllers.clear();
      setState(() {
        sessionId = selectedSessionId;
        stages = _list(data['stages']);
        categories = _list(data['categories']);
        tests = _list(data['tests']);
        normatives = _list(data['normatives']);
        players = mergedPlayers;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  Map<String, dynamic> _decode(String body) {
    final idx = body.indexOf('{');
    final clean = idx >= 0 ? body.substring(idx) : body;
    return Map<String, dynamic>.from(jsonDecode(clean));
  }

  List<Map<String, dynamic>> _list(dynamic v) {
    return (v as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchTeamPlayers() async {
    final uri = Uri.parse(_playersUrl).replace(queryParameters: {
      'team_id': widget.teamId.toString(),
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 16));
    final data = _decodeAny(res.body);

    if (data is! Map) {
      throw Exception('Некорректный ответ списка игроков');
    }

    if (data['status'] != 'success' && data['success'] != true) {
      throw Exception('${data['message'] ?? 'Не удалось загрузить игроков команды'}');
    }

    final raw = (data['players'] as List?) ??
        (data['data'] as List?) ??
        (data['items'] as List?) ??
        const [];

    final loaded = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => _playerId(e) > 0)
        .toList();

    loaded.sort((a, b) => _shortPlayerName(a).toLowerCase().compareTo(_shortPlayerName(b).toLowerCase()));
    return loaded;
  }

  dynamic _decodeAny(String body) {
    final clear = body.trim();
    final obj = clear.indexOf('{');
    final arr = clear.indexOf('[');
    final starts = [obj, arr].where((e) => e >= 0).toList();
    if (starts.isEmpty) return {};
    final start = starts.reduce((a, b) => a < b ? a : b);
    return jsonDecode(clear.substring(start));
  }

  List<Map<String, dynamic>> _mergePlayersWithResults(
    List<Map<String, dynamic>> teamPlayers,
    List<Map<String, dynamic>> matrixPlayers,
  ) {
    final resultsByPlayerId = <int, dynamic>{};

    for (final p in matrixPlayers) {
      final id = _playerId(p);
      if (id <= 0) continue;
      final results = p['results'];
      if (results != null) resultsByPlayerId[id] = results;
    }

    final source = teamPlayers.isNotEmpty ? teamPlayers : matrixPlayers;
    final merged = source.map((p) {
      final copy = Map<String, dynamic>.from(p);
      final id = _playerId(copy);
      copy['id'] = id;
      if (resultsByPlayerId.containsKey(id)) {
        copy['results'] = resultsByPlayerId[id];
      }
      return copy;
    }).where((p) => _playerId(p) > 0).toList();

    merged.sort((a, b) => _shortPlayerName(a).toLowerCase().compareTo(_shortPlayerName(b).toLowerCase()));
    return merged;
  }

  void _onResultChanged(StateSetter localRefresh) {
    localRefresh(() {});
    setState(() {});
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    if (loading || tests.isEmpty || players.isEmpty) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _save(showFeedback: false, reloadAfterSave: false);
    });
  }

  Future<void> _manualSave() async {
    _autosaveTimer?.cancel();
    await _save(showFeedback: true, reloadAfterSave: true);
  }

  Future<void> _save({bool showFeedback = true, bool reloadAfterSave = true}) async {
    if (_silentSaving || saving) {
      if (!showFeedback) _scheduleAutosave();
      return;
    }

    if (showFeedback) {
      setState(() => saving = true);
    } else {
      _silentSaving = true;
    }

    try {
      final rows = <Map<String, dynamic>>[];
      for (final p in players) {
        final playerId = _playerId(p);
        for (final t in tests) {
          final code = _asStr(t['code']);
          rows.add({
            'player_id': playerId,
            'test_code': code,
            'value': _controllers[_key(playerId, code)]?.text.trim() ?? '',
          });
        }
      }

      final r = await http.post(
        Uri.parse('${TestingApi.base}/save_testing_results.php'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'club_id': widget.clubId,
          'team_id': widget.teamId,
          'category': category,
          'stage': stage,
          'session_id': sessionId,
          'created_by': widget.userId ?? 0,
          'title': 'Тестирование ${_categoryTitle(category)} $stage',
          'test_date': _dateIso(_selectedDate),
          'results': rows,
        }),
      );
      final data = _decode(r.body);
      if (data['success'] != true) throw data['message'] ?? 'Не удалось сохранить';

      final newSessionId = _asInt(data['session_id']);
      if (newSessionId > 0) sessionId = newSessionId;

      if (reloadAfterSave) {
        await _load();
      } else {
        await _loadSessionsOnly();
      }

      if (!mounted || !showFeedback) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Результаты сохранены')));
    } catch (e) {
      if (!mounted || !showFeedback) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (showFeedback) {
        if (mounted) setState(() => saving = false);
      } else {
        _silentSaving = false;
      }
    }
  }

  String _categoryTitle(String code) {
    switch (code) {
      case 'physical':
        return 'Физическая подготовка';
      case 'technical':
        return 'Техническая подготовка';
      case 'tactical':
        return 'Тактическая подготовка';
      case 'psychological':
      case 'mental':
        return 'Психологическая подготовка';
      case 'theory':
      case 'theoretical':
        return 'Теория';
      case 'medical':
      case 'functional':
        return 'Функциональное состояние';
      default:
        for (final c in categories) {
          if (_asStr(c['code']) == code) {
            final title = _asStr(c['title']);
            if (title.isNotEmpty && title != code) return _ruCategoryTitle(title);
          }
        }
        return 'Раздел подготовки';
    }
  }

  String _ruCategoryTitle(String raw) {
    final t = raw.trim();
    final l = t.toLowerCase();
    if (l.contains('physical') || l.contains('fitness')) return 'Физическая подготовка';
    if (l.contains('technical') || l.contains('technique')) return 'Техническая подготовка';
    if (l.contains('tactical') || l.contains('tactic')) return 'Тактическая подготовка';
    if (l.contains('psych') || l.contains('mental')) return 'Психологическая подготовка';
    if (l.contains('theory') || l.contains('theoretical')) return 'Теория';
    if (l.contains('medical') || l.contains('functional')) return 'Функциональное состояние';
    return t;
  }

  IconData _categoryIcon(String code) {
    switch (code) {
      case 'physical':
        return Icons.directions_run_rounded;
      case 'technical':
        return Icons.sports_soccer_rounded;
      case 'tactical':
        return Icons.account_tree_rounded;
      case 'psychological':
      case 'mental':
        return Icons.psychology_rounded;
      case 'theory':
      case 'theoretical':
        return Icons.menu_book_rounded;
      case 'medical':
      case 'functional':
        return Icons.monitor_heart_rounded;
      default:
        return Icons.fact_check_rounded;
    }
  }

  String _categoryHint(String code) {
    switch (code) {
      case 'physical':
        return 'скорость, прыжки, выносливость';
      case 'technical':
        return 'ведение, пас, удар, мяч';
      case 'tactical':
        return 'игровые решения и взаимодействия';
      case 'psychological':
      case 'mental':
        return 'концентрация и устойчивость';
      case 'theory':
      case 'theoretical':
        return 'знания и понимание игры';
      case 'medical':
      case 'functional':
        return 'самочувствие и контроль';
      default:
        return 'тесты выбранного раздела';
    }
  }

  List<Map<String, dynamic>> get _categoryItems {
    final List<Map<String, dynamic>> base = categories.isEmpty
        ? [
            {'code': 'physical'},
            {'code': 'technical'},
            {'code': 'tactical'},
          ]
        : categories;
    return base
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => _asStr(e['code']).isNotEmpty)
        .toList();
  }

  _Rating _ratingFor(String testCode, String text) {
    final value = _toDouble(text);
    if (value == null) return _Rating.empty();

    final test = tests.firstWhere((e) => _asStr(e['code']) == testCode, orElse: () => {});
    final lower = _asInt(test['lower_is_better']) == 1;

    for (final n in normatives) {
      if (_asStr(n['test_code']) != testCode) continue;
      final min = _toNormDouble(n['min_value']);
      final max = _toNormDouble(n['max_value']);
      final normalizedValue = _normalizeValueForNorm(testCode, value, min, max);
      final minOk = min == null || normalizedValue >= min;
      final maxOk = max == null || normalizedValue <= max;
      if (minOk && maxOk) {
        return _Rating.fromHex(
          _asStr(n['rating']),
          _asStr(n['color_hex']),
          _asStr(n['label']),
          points: _asInt(n['points']),
        );
      }
    }

    if (category == 'physical') {
      final map = _PhysicalNorms.norms[stage]?[testCode];
      if (map != null) {
        final v = (testCode == 'long_jump' && value > 0 && value < 20) ? value * 100 : value;
        return _PhysicalNorms.rate(v, map, lower);
      }
    }
    return _Rating('', Colors.transparent, '');
  }

  double _normalizeValueForNorm(String testCode, double value, double? min, double? max) {
    if (testCode == 'long_jump' && value > 0 && value < 20) {
      return value * 100;
    }
    return value;
  }

  _Rating _finalFor(Map<String, dynamic> p) {
    int points = 0;
    int count = 0;
    final playerId = _playerId(p);
    final results = p['results'];

    for (final t in tests) {
      final code = _asStr(t['code']);

      final controllerText = _controllers[_key(playerId, code)]?.text;
      final storedValue = results is Map && results[code] is Map ? results[code]['value'] : null;
      final valueText = controllerText ?? _numText(code, storedValue);

      final rating = _ratingFor(code, valueText);
      if (rating.points > 0) {
        points += rating.points;
        count++;
      }
    }

    if (count == 0) return _Rating.empty();
    final avg = points / count;
    if (avg >= 3.6) return _Rating('excellent', _CmrTestColors.green, 'Отлично', points: 4);
    if (avg >= 2.6) return _Rating('good', _CmrTestColors.yellow, 'Хорошо', points: 3);
    if (avg >= 1.6) return _Rating('satisfactory', _CmrTestColors.orange, 'Удовлетворительно', points: 2);
    return _Rating('poor', _CmrTestColors.red, 'Неудовлетворительно', points: 1);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 680;

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        color: const Color(0xFFF6F7F6),
        child: Column(
          children: [
            _header(isMobile),
            if (saving) const LinearProgressIndicator(minHeight: 2, color: _CmrTestColors.green),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: _CmrTestColors.green))
                  : error != null
                      ? _error()
                      : isMobile
                          ? _mobileBody()
                          : _desktopBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(bool mobile) {
    return Container(
      margin: EdgeInsets.fromLTRB(mobile ? 8 : 10, mobile ? 8 : 10, mobile ? 8 : 10, 6),
      padding: EdgeInsets.fromLTRB(mobile ? 10 : 12, 8, mobile ? 10 : 12, 8),
      decoration: _CmrTestDecor.panel(radius: 12),
      child: Row(
        children: [
          _IconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: widget.onBackToMenu,
            tooltip: 'Назад',
            compact: mobile,
          ),
          if (mobile) ...[
            const SizedBox(width: 4),
            _IconBox(icon: Icons.fact_check_rounded, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Тестирование',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrTestText.title(17),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.clubName} • ${widget.teamName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrTestText.muted(11),
                  ),
                ],
              ),
            ),
          ],
          if (!mobile) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _filterBar(compact: false),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (!mobile) ...[
            _IconButton(
              icon: Icons.open_in_full_rounded,
              onPressed: _openFullscreen,
              tooltip: 'Открыть тестирование во весь экран',
              compact: mobile,
            ),
            const SizedBox(width: 8),
          ],
          _exportButton(mobile: mobile),
          const SizedBox(width: 8),
          _IconButton(
            icon: Icons.save_rounded,
            onPressed: saving ? null : _manualSave,
            tooltip: 'Сохранить результаты',
            filled: true,
            compact: mobile,
            isLoading: saving,
          ),
        ],
      ),
    );
  }

  Widget _filterBar({required bool compact}) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _categorySegment(compact: true),
          const SizedBox(height: 8),
          _stageChip(compact: true),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _categorySegment(compact: false),
        const SizedBox(width: 8),
        _stageChip(compact: compact),
      ],
    );
  }

  Widget _categorySegment({required bool compact}) {
    final items = _categoryItems;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
        final isTightDesktopHeader = !compact && availableWidth < 680;
        final isVeryTightHeader = !compact && availableWidth < 620;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: items.map((e) {
              final code = _asStr(e['code']);
              final active = category == code;
              return Padding(
                padding: EdgeInsets.only(right: compact ? 7 : 6),
                child: _CategoryChip(
                  code: code,
                  title: _categoryTitle(code),
                  hint: _categoryHint(code),
                  icon: _categoryIcon(code),
                  active: active,
                  compact: compact,
                  isTightDesktop: isTightDesktopHeader,
                  isVeryTight: isVeryTightHeader,
                  onTap: () {
                    if (category == code) return;
                    setState(() {
                      category = code;
                      sessionId = 0;
                    });
                    _load();
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _stageChip({required bool compact}) {
    return Container(
      height: compact ? 40 : 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _CmrTestColors.greenSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _CmrTestColors.green,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 7),
          const Icon(Icons.lock_rounded, size: 15, color: _CmrTestColors.green),
          const SizedBox(width: 6),
          Text(
            compact ? stage : 'Этап $stage',
            style: _CmrTestText.action().copyWith(fontSize: compact ? 12 : 13),
          ),
        ],
      ),
    );
  }

  Widget _desktopBody() {
    return Container(
      color: _CmrTestColors.panel,
      child: _tableArea(),
    );
  }

  Widget _mobileBody() {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _mobileToolsCollapsed
              ? _mobileCollapsedTestingTools()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      child: _filterBar(compact: true),
                    ),
                    const SizedBox(height: 6),
                    _dateCalendarBar(compact: true),
                    const SizedBox(height: 6),
                    _tableToolbar(),
                    if (_hasFocusedPlayer) _focusedPlayerBanner(compact: true),
                    const SizedBox(height: 6),
                  ],
                ),
        ),
        Expanded(child: _table()),
      ],
    );
  }

  Widget _mobileCollapsedTestingTools() {
    final visible = _visiblePlayers.length;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: _expandMobileTools,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          decoration: const BoxDecoration(
            color: Colors.white,
            
          ),
          child: Row(
            children: [
              _IconBox(icon: Icons.tune_rounded, size: 36),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_categoryTitle(category)} • $stage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrTestText.value(12.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${_dateRu(_selectedDate)} • показано $visible из ${players.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrTestText.caption(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _expandMobileTools,
                tooltip: 'Показать фильтры',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _CmrTestColors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _side() {
    if (_infoPanelCollapsed) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 0, 12),
        decoration: _CmrTestDecor.panel(),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _IconButton(
              icon: Icons.keyboard_double_arrow_right_rounded,
              onPressed: () => setState(() => _infoPanelCollapsed = false),
              tooltip: 'Показать подсказки и тесты',
              compact: true,
            ),
            const SizedBox(height: 12),
            RotatedBox(
              quarterTurns: 3,
              child: Text('Подсказки', style: _CmrTestText.caption()),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 0, 12),
      decoration: _CmrTestDecor.panel(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
            child: Row(
              children: [
                Expanded(child: Text('Подсказки и тесты', style: _CmrTestText.section())),
                _IconButton(
                  icon: Icons.keyboard_double_arrow_left_rounded,
                  onPressed: () => setState(() => _infoPanelCollapsed = true),
                  tooltip: 'Свернуть панель влево',
                  compact: true,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              children: [
                _infoCard('Как работает', 'Выберите вид подготовки. Этап берётся из выбранной команды автоматически, таблица показывает только нужные тесты, а после ввода результата сразу подсвечивает оценку.'),
                const SizedBox(height: 12),
                _infoCard('Итоговая оценка', 'Считается по среднему баллу тестов: отлично = 4, хорошо = 3, удовлетворительно = 2, неудовлетворительно = 1.'),
                const SizedBox(height: 12),
                _infoCard('Ранги', 'После сохранения можно открыть рейтинг по отдельному тесту, по виду подготовки и затем общий рейтинг по всем видам.'),
                const SizedBox(height: 16),
                _positionDistribution(),
                const SizedBox(height: 18),
                Text('Тесты в этом этапе', style: _CmrTestText.section()),
                const SizedBox(height: 8),
                ...tests.map(_testHint),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionDistribution() {
    final items = _positionItems;
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _CmrTestDecor.softCard(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_2_rounded, size: 18, color: _CmrTestColors.green),
              const SizedBox(width: 8),
              Expanded(child: Text('Амплуа игроков', style: _CmrTestText.section())),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PositionChip(value: 'all', label: 'Все', count: players.length, active: _positionFilter == 'all', onTap: () => setState(() => _positionFilter = 'all')),
              ...items.map((e) => _PositionChip(
                    value: e.key,
                    label: e.key,
                    count: e.value,
                    active: _positionFilter == e.key,
                    onTap: () => setState(() => _positionFilter = e.key),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _testHint(Map<String, dynamic> t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: _CmrTestDecor.softCard(radius: 16),
      child: Row(
        children: [
          const Icon(Icons.sports_soccer_rounded, color: _CmrTestColors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_asStr(t['short_title']), style: _CmrTestText.value(12.5)),
                Text(_unitForTest(t), style: _CmrTestText.caption()),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showTestInfo(t),
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            tooltip: 'Как проводится тест',
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String title, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _CmrTestColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _CmrTestColors.greenBorder, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: _CmrTestText.section().copyWith(color: _CmrTestColors.text)),
        const SizedBox(height: 6),
        Text(text, style: _CmrTestText.caption().copyWith(height: 1.25)),
      ]),
    );
  }

  String _unitForTest(Map<String, dynamic> t) {
    final code = _asStr(t['code']);
    if (code == 'long_jump') return 'см';
    return _asStr(t['unit']);
  }

  String _playerPosition(Map<String, dynamic> p) {
    final raw = [
      p['position'],
      p['amplua'],
      p['amplua_title'],
      p['role'],
      p['player_position'],
      p['position_name'],
    ].map(_asStr).firstWhere((e) => e.isNotEmpty && e != 'null', orElse: () => 'Без амплуа');
    return raw.trim().isEmpty ? 'Без амплуа' : raw.trim();
  }

  List<MapEntry<String, int>> get _positionItems {
    final counts = <String, int>{};
    for (final p in players) {
      final pos = _playerPosition(p);
      counts[pos] = (counts[pos] ?? 0) + 1;
    }
    final entries = counts.entries.toList();
    entries.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return entries;
  }

  String _normText(String value) => value
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
      .trim();

  bool _isFocusedPlayer(Map<String, dynamic> p) {
    if (_focusedPlayerId > 0 && _playerId(p) == _focusedPlayerId) return true;
    final focusedName = _normText(_focusedPlayerName);
    if (focusedName.isEmpty) return false;
    final full = _normText(_playerFullName(p));
    final short = _normText(_shortPlayerName(p));
    final tokens = focusedName.split(' ').where((e) => e.length > 1).toList();
    final tokenMatch = tokens.isNotEmpty && tokens.every((token) => full.contains(token) || short.contains(token));
    return full == focusedName || full.contains(focusedName) || focusedName.contains(full) || short == focusedName || tokenMatch;
  }

  bool get _hasFocusedPlayer => _focusedPlayerId > 0 || _focusedPlayerName.trim().isNotEmpty;

  List<Map<String, dynamic>> get _visiblePlayers {
    final query = _normText(_searchController.text);
    return players.where((p) {
      final pos = _playerPosition(p);
      if (_positionFilter != 'all' && pos != _positionFilter) return false;
      if (_focusedPlayerId > 0 && query.isEmpty) return _isFocusedPlayer(p);
      if (query.isEmpty) return true;
      final haystack = _normText(
        '${_playerFullName(p)} ${_shortPlayerName(p)} ${_playerPosition(p)} ${_playerId(p)} ${p['number'] ?? p['player_number'] ?? ''}',
      );
      return haystack.contains(query) || _isFocusedPlayer(p);
    }).toList();
  }

  Widget _playerAvatar(Map<String, dynamic> p) {
    final url = _playerAvatarUrl(p);
    final initials = _initials(_playerFullName(p));
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 17,
        backgroundColor: _CmrTestColors.greenSoft,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        child: const SizedBox.shrink(),
      );
    }
    return CircleAvatar(
      radius: 17,
      backgroundColor: _CmrTestColors.greenSoft,
      child: Text(initials, style: const TextStyle(color: _CmrTestColors.green, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }

  String _playerAvatarUrl(Map<String, dynamic> p) {
    final raw = [
      p['avatar'],
      p['avatar_url'],
      p['photo'],
      p['photo_url'],
      p['image'],
      p['image_url'],
      p['profile_photo'],
    ].map(_asStr).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    if (clean.startsWith('uploads/')) return 'https://sportotekaapp.ru/$clean';
    return 'https://sportotekaapp.ru/uploads/$clean';
  }

  int _playerId(Map<String, dynamic> p) {
    final candidates = [
      p['id'],
      p['player_id'],
      p['user_id'],
      p['student_id'],
    ];
    for (final v in candidates) {
      final id = _asInt(v);
      if (id > 0) return id;
    }
    return 0;
  }

  String _playerFullName(Map<String, dynamic> p) {
    final full = [
      p['fullName'],
      p['full_name'],
      p['fio'],
      p['player_name'],
    ].map(_asStr).firstWhere((e) => e.isNotEmpty && e != 'null', orElse: () => '');
    if (full.isNotEmpty) return full;

    final last = [
      p['last_name'],
      p['surname'],
      p['lastname'],
      p['family'],
    ].map(_asStr).firstWhere((e) => e.isNotEmpty && e != 'null', orElse: () => '');

    final first = [
      p['first_name'],
      p['firstname'],
      p['name'],
    ].map(_asStr).firstWhere((e) => e.isNotEmpty && e != 'null', orElse: () => '');

    final middle = [
      p['middle_name'],
      p['patronymic'],
    ].map(_asStr).firstWhere((e) => e.isNotEmpty && e != 'null', orElse: () => '');

    final result = [last, first, middle].where((e) => e.isNotEmpty).join(' ').trim();
    return result;
  }

  String _shortPlayerName(Map<String, dynamic> p) {
    final last = [
      p['last_name'],
      p['surname'],
      p['lastname'],
      p['family'],
    ].map(_asStr).firstWhere((e) => e.isNotEmpty && e != 'null', orElse: () => '');

    final first = [
      p['first_name'],
      p['firstname'],
      p['name'],
    ].map(_asStr).firstWhere((e) => e.isNotEmpty && e != 'null', orElse: () => '');

    if (last.isNotEmpty) {
      final initial = first.isNotEmpty ? ' ${first.substring(0, 1).toUpperCase()}.' : '';
      return '$last$initial';
    }

    final full = _playerFullName(p).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (full.isEmpty) return '';
    final parts = full.split(' ').where((e) => e.trim().isNotEmpty).toList();
    if (parts.length == 1) return parts.first;

    final surname = parts.last;
    final nameInitial = parts.first.isNotEmpty ? ' ${parts.first.substring(0, 1).toUpperCase()}.' : '';
    return '$surname$nameInitial';
  }

  Widget _tableArea() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          LayoutBuilder(builder: (context, c) => _dateCalendarBar(compact: c.maxWidth < 640)),
          const SizedBox(height: 2),
          _tableToolbar(),
          if (_hasFocusedPlayer) _focusedPlayerBanner(compact: false),
          const SizedBox(height: 2),
          Expanded(child: _table()),
        ],
      ),
    );
  }

  Widget _dateCalendarBar({required bool compact}) {
    final hasData = sessionId > 0 || _hasSessionOn(_selectedDate);
    final label = hasData ? 'Открыто сохранённое тестирование' : 'Новая дата, результатов пока нет';

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(14, compact ? 10 : 12, 14, compact ? 8 : 10),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: _dateSelectorButton()),
                  const SizedBox(width: 8),
                  _SquareButton(icon: Icons.chevron_left_rounded, onTap: () => _selectTestingDate(_selectedDate.subtract(const Duration(days: 1))), compact: compact),
                  _SquareButton(icon: Icons.chevron_right_rounded, onTap: () => _selectTestingDate(_selectedDate.add(const Duration(days: 1))), compact: compact),
                ]),
                const SizedBox(height: 8),
                _dateStatusChip(label, hasData),
              ],
            )
          : Row(
              children: [
                _dateSelectorButton(),
                const SizedBox(width: 8),
                _SquareButton(icon: Icons.chevron_left_rounded, onTap: () => _selectTestingDate(_selectedDate.subtract(const Duration(days: 1))), compact: compact),
                _SquareButton(icon: Icons.chevron_right_rounded, onTap: () => _selectTestingDate(_selectedDate.add(const Duration(days: 1))), compact: compact),
                const SizedBox(width: 10),
                _dateStatusChip(label, hasData),
                const Spacer(),
                if (sessions.isNotEmpty)
                  Text('Сохранённых дат: ${sessions.length}', style: _CmrTestText.caption()),
              ],
            ),
    );
  }

  Widget _dateSelectorButton() {
    return _ActionButton(
      icon: Icons.calendar_month_rounded,
      text: _dateRu(_selectedDate),
      onTap: _showCalendarDialog,
    );
  }

  Widget _dateStatusChip(String label, bool hasData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: hasData ? _CmrTestColors.panel : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.transparent, width: 0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasData ? Icons.check_circle_rounded : Icons.edit_calendar_rounded, size: 16, color: hasData ? _CmrTestColors.green : _CmrTestColors.orange),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _CmrTestText.caption().copyWith(color: hasData ? _CmrTestColors.green : _CmrTestColors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCalendarDialog() async {
    DateTime visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
    DateTime picked = _selectedDate;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, localSetState) {
            final first = DateTime(visibleMonth.year, visibleMonth.month, 1);
            final daysInMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
            final leading = (first.weekday + 6) % 7;
            final cells = leading + daysInMonth;
            final totalCells = ((cells + 6) ~/ 7) * 7;

            return Dialog(
              insetPadding: const EdgeInsets.all(18),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _CmrTestDecor.panel(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _IconBox(icon: Icons.calendar_month_rounded, size: 42),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Дата тестирования', style: _CmrTestText.title(20))),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: _CmrTestDecor.softCard(radius: 18),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => localSetState(() => visibleMonth = DateTime(visibleMonth.year, visibleMonth.month - 1)),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Expanded(child: Center(child: Text(_monthTitle(visibleMonth), style: _CmrTestText.section().copyWith(fontSize: 16)))),
                            IconButton(
                              onPressed: () => localSetState(() => visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + 1)),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                            .map((d) => Expanded(child: Center(child: Text(d, style: _CmrTestText.caption()))))
                            .toList(),
                      ),
                      const SizedBox(height: 6),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
                        itemCount: totalCells,
                        itemBuilder: (_, i) {
                          final day = i - leading + 1;
                          if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
                          final date = DateTime(visibleMonth.year, visibleMonth.month, day);
                          final selected = _sameDay(date, picked);
                          final today = _sameDay(date, DateTime.now());
                          final saved = _hasSessionOn(date);

                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => localSetState(() => picked = date),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected ? _CmrTestColors.graphite : saved ? _CmrTestColors.greenSoft : today ? _CmrTestColors.soft2 : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      '$day',
                                      style: _CmrTestText.value(13).copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: selected ? Colors.white : _CmrTestColors.text,
                                      ),
                                    ),
                                  ),
                                  if (saved)
                                    Positioned(
                                      right: 7,
                                      bottom: 6,
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: selected ? Colors.white : _CmrTestColors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _CmrTestColors.graphite,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () {
                                localSetState(() {
                                  picked = DateTime.now();
                                  visibleMonth = DateTime(picked.year, picked.month);
                                });
                              },
                              child: const FittedBox(child: Text('Сегодня')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _CmrTestColors.graphite,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () => Navigator.pop(dialogContext, picked),
                              child: FittedBox(child: Text(_hasSessionOn(picked) ? 'Открыть дату' : 'Создать на дату')),
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

    if (result != null) {
      await _selectTestingDate(result);
    }
  }

  Widget _focusedPlayerBanner({required bool compact}) {
    final label = _focusedPlayerName.trim().isNotEmpty
        ? _focusedPlayerName.trim()
        : (_focusedPlayerId > 0 ? 'игрок #$_focusedPlayerId' : 'выбранный игрок');

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(compact ? 10 : 14, 0, compact ? 10 : 14, compact ? 6 : 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: _CmrTestColors.panel,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_search_rounded, color: _CmrTestColors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Показан игрок из предупреждения: $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _CmrTestText.value(compact ? 12.5 : 13).copyWith(color: _CmrTestColors.green),
            ),
          ),
          TextButton(
            onPressed: _clearFocusedPlayer,
            style: TextButton.styleFrom(
              foregroundColor: _CmrTestColors.graphite,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: const Text('Показать всех'),
          ),
        ],
      ),
    );
  }

  Widget _tableToolbar() {
    final visible = _visiblePlayers.length;
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 640;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchField(
                      controller: _searchController,
                      hint: 'Быстро найти игрока, номер или амплуа...',
                      compact: true,
                      onClear: _clearFocusedPlayer,
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _PositionChip(value: 'all', label: 'Все амплуа', count: players.length, active: _positionFilter == 'all', onTap: () => setState(() => _positionFilter = 'all')),
                          const SizedBox(width: 6),
                          ..._positionItems.map((e) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _PositionChip(
                                  value: e.key,
                                  label: e.key,
                                  count: e.value,
                                  active: _positionFilter == e.key,
                                  onTap: () => setState(() => _positionFilter = e.key),
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Показано: $visible из ${players.length}', style: _CmrTestText.caption()),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: _SearchField(
                        controller: _searchController,
                        hint: 'Поиск игрока, номера или амплуа...',
                        compact: false,
                        onClear: _clearFocusedPlayer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _PositionChip(value: 'all', label: 'Все амплуа', count: players.length, active: _positionFilter == 'all', onTap: () => setState(() => _positionFilter = 'all')),
                            const SizedBox(width: 6),
                            ..._positionItems.map((e) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _PositionChip(
                                    value: e.key,
                                    label: e.key,
                                    count: e.value,
                                    active: _positionFilter == e.key,
                                    onTap: () => setState(() => _positionFilter = e.key),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Показано: $visible из ${players.length}', style: _CmrTestText.caption()),
                  ],
                ),
        );
      },
    );
  }

  Widget _table() {
    if (tests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_soccer_rounded, size: 48, color: _CmrTestColors.muted),
            const SizedBox(height: 12),
            Text(
              'Для выбранного этапа пока нет тестов',
              style: _CmrTestText.muted(14),
            ),
          ],
        ),
      );
    }
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded, size: 48, color: _CmrTestColors.muted),
            const SizedBox(height: 12),
            Text(
              'В команде нет игроков',
              style: _CmrTestText.muted(14),
            ),
          ],
        ),
      );
    }

    final tablePlayers = _visiblePlayers;
    if (tablePlayers.isEmpty) {
      return const Center(child: Text('По выбранному поиску или амплуа игроков не найдено'));
    }

    final isMobile = MediaQuery.sizeOf(context).width < 680;
    if (isMobile) return _mobileTestingCards(tablePlayers);

    return Container(
      color: Colors.white,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: DataTable(
              headingRowHeight: 46,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 64,
              columnSpacing: 14,
              headingTextStyle: _CmrTestText.caption().copyWith(fontWeight: FontWeight.w700),
              dataTextStyle: _CmrTestText.value(11.5),
              columns: [
                const DataColumn(
                  label: SizedBox(
                    width: 210,
                    child: Text(
                      'Игрок',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ...tests.map(
                  (t) {
                    final title = _asStr(t['short_title']).isEmpty ? _asStr(t['title']) : _asStr(t['short_title']);
                    return DataColumn(
                      label: SizedBox(
                        width: 126,
                        child: Text(
                          '$title\n${_unitForTest(t)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
                const DataColumn(
                  label: SizedBox(
                    width: 126,
                    child: Text(
                      'Итоговая оценка',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              rows: tablePlayers.map((p) => _row(p)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileTestingCards(List<Map<String, dynamic>> tablePlayers) {
    return ListView.separated(
      controller: _mobilePlayersScrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      itemCount: tablePlayers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _mobilePlayerCard(tablePlayers[index], index + 1),
    );
  }

  Widget _mobilePlayerCard(Map<String, dynamic> p, int index) {
    final playerId = _playerId(p);
    final finalRating = _finalFor(p);
    final focused = _isFocusedPlayer(p);
    return Container(
      decoration: focused
          ? BoxDecoration(
              color: _CmrTestColors.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _CmrTestColors.green.withOpacity(.22), width: 1),
            )
          : _CmrTestDecor.panel(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                _playerAvatar(p),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shortPlayerName(p).isEmpty ? 'Игрок #$playerId' : _shortPlayerName(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrTestText.value(15),
                      ),
                      const SizedBox(height: 2),
                      Text(_playerPosition(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrTestText.caption()),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (focused) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: _CmrTestColors.green,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      'Найден',
                      style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                _ratingPill(finalRating),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, c) {
                final oneColumn = c.maxWidth < 340;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: oneColumn ? 1 : 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: oneColumn ? 2.35 : 1.24,
                  ),
                  itemCount: tests.length,
                  itemBuilder: (_, i) {
                    final t = tests[i];
                    final code = _asStr(t['code']);
                    final results = p['results'];
                    final old = results is Map ? (results[code] is Map ? results[code]['value'] : null) : null;
                    final c = _ctrl(playerId, code, old);
                    return _mobileValueTile(t, c, code);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileValueTile(Map<String, dynamic> test, TextEditingController c, String testCode) {
    return StatefulBuilder(builder: (context, localSetState) {
      final r = _ratingFor(testCode, c.text);
      final hasRating = r.label.isNotEmpty;
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: hasRating ? r.color.withOpacity(.08) : _CmrTestColors.soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _asStr(test['short_title']).isEmpty ? _asStr(test['title']) : _asStr(test['short_title']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrTestText.value(11),
                  ),
                ),
                Text(_unitForTest(test), style: _CmrTestText.caption().copyWith(fontSize: 9)),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TextField(
                controller: c,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                onChanged: (_) => _onResultChanged(localSetState),
                textAlign: TextAlign.center,
                style: _CmrTestText.value(18),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  hintText: '0',
                  filled: true,
                  fillColor: Colors.white,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasRating ? r.label : 'ввод результата',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _CmrTestText.caption().copyWith(
                fontSize: 10,
                color: hasRating ? _darken(r.color) : _CmrTestColors.muted,
              ),
            ),
          ],
        ),
      );
    });
  }

  DataRow _row(Map<String, dynamic> p) {
    final playerId = _playerId(p);
    final finalRating = _finalFor(p);
    final focused = _isFocusedPlayer(p);
    return DataRow(
      color: focused
          ? MaterialStateProperty.all(_CmrTestColors.soft)
          : null,
      cells: [
      DataCell(SizedBox(
        width: 210,
        child: Row(
          children: [
            _playerAvatar(p),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shortPlayerName(p).isEmpty ? 'Игрок #$playerId' : _shortPlayerName(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrTestText.value(12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _playerPosition(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _CmrTestText.caption().copyWith(fontSize: 10),
                        ),
                      ),
                      if (focused) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _CmrTestColors.green,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Text(
                            'Найден',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      )),
      ...tests.map((t) {
        final code = _asStr(t['code']);
        final results = p['results'];
        final old = results is Map ? (results[code] is Map ? results[code]['value'] : null) : null;
        final c = _ctrl(playerId, code, old);
        final rating = _ratingFor(code, c.text);
        return DataCell(_valueCell(c, rating, code));
      }),
      DataCell(_ratingCell(finalRating)),
    ]);
  }

  Widget _valueCell(TextEditingController c, _Rating rating, String testCode) {
    return StatefulBuilder(builder: (context, localSetState) {
      final r = _ratingFor(testCode, c.text);
      return Container(
        width: 126,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _CmrTestColors.panel,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _onResultChanged(localSetState),
          textAlign: TextAlign.center,
          style: _CmrTestText.value(12),
          decoration: InputDecoration(
            isDense: true,
            hintText: '—',
            border: InputBorder.none,
            helperText: r.label.isEmpty ? null : r.label,
            helperStyle: TextStyle(fontSize: 9, color: _darken(r.color), fontWeight: FontWeight.w600),
          ),
        ),
      );
    });
  }

  Widget _ratingCell(_Rating r) {
    final hasRating = r.label.isNotEmpty;
    return SizedBox(
      width: 126,
      child: Center(
        child: Text(
          hasRating ? r.label : '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: hasRating
              ? TextStyle(color: _darken(r.color), fontWeight: FontWeight.w700, fontSize: 11)
              : _CmrTestText.caption(),
        ),
      ),
    );
  }

  Widget _ratingPill(_Rating r) {
    if (r.label.isEmpty) {
      return const SizedBox(
        width: 116,
        child: Center(child: Text('—')),
      );
    }

    return SizedBox(
      width: 116,
      child: Center(
        child: Text(
          r.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: _darken(r.color), fontWeight: FontWeight.w700, fontSize: 11),
        ),
      ),
    );
  }

  Widget _exportButton({required bool mobile}) {
    return PopupMenuButton<String>(
      tooltip: 'Экспорт таблицы',
      onSelected: (v) {
        if (v == 'excel') _exportAsExcel();
        if (v == 'word') _exportAsWord();
        if (v == 'pdf') _exportAsPdf();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'excel', child: Text('Экспорт в Excel')),
        PopupMenuItem(value: 'word', child: Text('Экспорт в Word')),
        PopupMenuItem(value: 'pdf', child: Text('Экспорт в PDF')),
      ],
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _CmrTestColors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _CmrTestColors.line, width: 1),
        ),
        child: const Icon(Icons.file_download_outlined, size: 19, color: _CmrTestColors.muted),
      ),
    );
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: _CmrTestColors.panel,
          body: SafeArea(
            child: CmrTestingPanel(
              clubId: widget.clubId,
              teamId: widget.teamId,
              clubName: widget.clubName,
              teamName: widget.teamName,
              initialStage: stage,
              initialCategory: category,
              userId: widget.userId,
              initialDate: _dateIso(_selectedDate),
              initialPlayerId: _focusedPlayerId > 0 ? _focusedPlayerId : null,
              initialPlayerName: _focusedPlayerName.trim().isNotEmpty ? _focusedPlayerName.trim() : null,
              onBackToMenu: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  List<List<String>> _exportRows() {
    final rows = <List<String>>[];
    rows.add([
      'ФИО',
      ...tests.map((t) => '${_asStr(t['short_title'])} (${_unitForTest(t)})'),
      'Итоговая оценка',
    ]);

    for (final p in players) {
      final playerId = _playerId(p);
      final row = <String>[_shortPlayerName(p).isEmpty ? 'Игрок #$playerId' : _shortPlayerName(p)];
      for (final t in tests) {
        final code = _asStr(t['code']);
        row.add(_controllers[_key(playerId, code)]?.text.trim() ?? '');
      }
      row.add(_finalFor(p).label);
      rows.add(row);
    }
    return rows;
  }

  String _exportTitle() => 'Тестирование — ${widget.teamName} — ${_categoryTitle(category)} — $stage — ${_dateRu(_selectedDate)}';

  Future<File> _writeTempFile(String filename, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final safe = filename.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _openExported(File file) async {
    if (!mounted) return;
    await OpenFilex.open(file.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Файл создан: ${file.path}')));
  }

  String _htmlTable({required bool forExcel}) {
    final rows = _exportRows();
    final buffer = StringBuffer();
    buffer.writeln('<html><head><meta charset="utf-8">');
    buffer.writeln('<style>');
    buffer.writeln('body{font-family:Arial, sans-serif;} table{border-collapse:collapse;width:100%;} th,td{border:1px solid #E2E8F0;padding:8px;font-size:12px;} th{background:#F2F7F4;} .title{font-size:18px;font-weight:700;margin-bottom:12px;}');
    buffer.writeln('</style></head><body>');
    buffer.writeln('<div class="title">${_escapeHtml(_exportTitle())}</div>');
    buffer.writeln('<td>');
    for (var i = 0; i < rows.length; i++) {
      final tag = i == 0 ? 'th' : 'td';
      buffer.writeln('<tr>');
      for (final cell in rows[i]) {
        buffer.writeln('<$tag>${_escapeHtml(cell)}</$tag>');
      }
      buffer.writeln('</tr>');
    }
    buffer.writeln('</table></body></html>');
    return buffer.toString();
  }

  String _escapeHtml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Future<void> _exportAsExcel() async {
    try {
      final file = await _writeTempFile(
        'testing_${widget.teamId}_${category}_${stage}_${_dateIso(_selectedDate)}.xls',
        utf8.encode(_htmlTable(forExcel: true)),
      );
      await _openExported(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось создать Excel: $e')));
    }
  }

  Future<void> _exportAsWord() async {
    try {
      final file = await _writeTempFile(
        'testing_${widget.teamId}_${category}_${stage}_${_dateIso(_selectedDate)}.doc',
        utf8.encode(_htmlTable(forExcel: false)),
      );
      await _openExported(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось создать Word: $e')));
    }
  }

  Future<({pw.Font? regular, pw.Font? bold})> _loadPdfFonts() async {
    Future<pw.Font?> load(String path) async {
      try {
        final data = await rootBundle.load(path);
        return pw.Font.ttf(data);
      } catch (_) {
        return null;
      }
    }

    return (
      regular: await load('assets/fonts/Roboto-Regular.ttf'),
      bold: await load('assets/fonts/Roboto-Bold.ttf'),
    );
  }

  Future<void> _exportAsPdf() async {
    try {
      final fonts = await _loadPdfFonts();
      final theme = fonts.regular == null
          ? null
          : pw.ThemeData.withFont(base: fonts.regular!, bold: fonts.bold ?? fonts.regular!);

      final doc = pw.Document(theme: theme);
      final rows = _exportRows();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => [
            pw.Text(_exportTitle(), style: pw.TextStyle(font: fonts.bold, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: rows.first,
              data: rows.skip(1).toList(),
              headerStyle: pw.TextStyle(font: fonts.bold, fontWeight: pw.FontWeight.bold, fontSize: 8),
              cellStyle: pw.TextStyle(font: fonts.regular, fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F7F4)),
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: .5),
            ),
          ],
        ),
      );
      final file = await _writeTempFile('testing_${widget.teamId}_${category}_${stage}_${_dateIso(_selectedDate)}.pdf', await doc.save());
      await _openExported(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось создать PDF: $e')));
    }
  }

  void _showTestInfo(Map<String, dynamic> t) {
    final code = _asStr(t['code']);
    final title = _asStr(t['title']);
    final description = _asStr(t['description']);
    final schemeText = _asStr(t['scheme_text']);
    final testNormatives = normatives.where((n) => _asStr(n['test_code']) == code).toList();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
          decoration: _CmrTestDecor.panel(),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                decoration: BoxDecoration(
                  color: _CmrTestColors.panel,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  border: const Border(bottom: BorderSide(color: _CmrTestColors.line, width: 1)),
                ),
                child: Row(
                  children: [
                    _IconBox(icon: Icons.sports_soccer_rounded, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title.isEmpty ? 'Описание теста' : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrTestText.title(18)),
                          const SizedBox(height: 3),
                          Text('${_categoryTitle(category)} • $stage • ${_asStr(t['unit'])}', style: _CmrTestText.caption().copyWith(color: _CmrTestColors.green)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(_), icon: const Icon(Icons.close_rounded), tooltip: 'Закрыть'),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final twoColumns = c.maxWidth >= 760;
                    final left = ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _methodBlock(
                          'Как проводится',
                          description.isEmpty ? _defaultMethodText(code) : description,
                          Icons.assignment_rounded,
                        ),
                        const SizedBox(height: 10),
                        _methodBlock('Размеры и схема', schemeText.isEmpty ? _defaultSchemeText(code) : schemeText, Icons.straighten_rounded),
                        const SizedBox(height: 10),
                        _methodBlock('Попытки и результат', _attemptText(t), Icons.fact_check_rounded),
                        const SizedBox(height: 10),
                        _methodBlock(
                          'Стандартизация',
                          'Проводите тест на одном и том же покрытии. У игроков должна быть одинаковая обувь и одежда. Исключайте влияние ветра, осадков и температуры. Результат вносится в таблицу, оценка и цвет рассчитываются автоматически.',
                          Icons.verified_rounded,
                        ),
                        if (testNormatives.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _normativesPreview(testNormatives, code),
                        ],
                      ],
                    );
                    final right = Padding(
                      padding: EdgeInsets.fromLTRB(twoColumns ? 0 : 16, twoColumns ? 16 : 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Графическая схема', style: _CmrTestText.section().copyWith(fontSize: 15)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: _CmrTestDecor.softCard(radius: 20),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: CustomPaint(
                                  painter: _TestSchemePainter(code: code, title: _asStr(t['short_title'])),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_schemeLegend(code), style: _CmrTestText.caption().copyWith(height: 1.25)),
                        ],
                      ),
                    );
                    if (twoColumns) {
                      return Row(children: [Expanded(flex: 5, child: left), Expanded(flex: 4, child: right)]);
                    }
                    return ListView(
                      children: [
                        SizedBox(height: 390, child: right),
                        SizedBox(height: 520, child: left),
                      ],
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

  Widget _methodBlock(String title, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _CmrTestDecor.softCard(radius: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: icon, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _CmrTestText.section()),
                const SizedBox(height: 5),
                Text(text, style: _CmrTestText.caption().copyWith(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _normValueTextForDisplay(String testCode, dynamic raw) {
    final v = _toNormDouble(raw);
    if (v == null) return '';
    final display = (testCode == 'throw_distance' && v > 20) ? v / 100 : v;
    return _formatNumber(display);
  }

  Widget _normativesPreview(List<Map<String, dynamic>> rows, String testCode) {
    rows.sort((a, b) => _asInt(b['points']).compareTo(_asInt(a['points'])));
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _CmrTestDecor.softCard(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Нормативы для $stage', style: _CmrTestText.section()),
          const SizedBox(height: 8),
          ...rows.map((n) {
            final color = _Rating.fromHex(_asStr(n['rating']), _asStr(n['color_hex']), _asStr(n['label'])).color;
            final min = _normValueTextForDisplay(testCode, n['min_value']);
            final max = _normValueTextForDisplay(testCode, n['max_value']);
            final range = min.isEmpty && max.isNotEmpty
                ? 'до $max'
                : max.isEmpty && min.isNotEmpty
                    ? 'от $min'
                    : '$min–$max';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
                  const SizedBox(width: 8),
                  SizedBox(width: 154, child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(_asStr(n['label']), maxLines: 1, softWrap: false, style: _CmrTestText.caption().copyWith(fontWeight: FontWeight.w700, color: _darken(color))))),
                  Expanded(child: Text(range, textAlign: TextAlign.right, style: _CmrTestText.caption())),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _attemptText(Map<String, dynamic> t) {
    final attempts = _asInt(t['attempts_count']);
    final rule = _asStr(t['best_attempt_rule']);
    final unit = _unitForTest(t);
    final ruleText = switch (rule) {
      'min' => 'в таблицу заносится лучший минимальный результат',
      'max' => 'в таблицу заносится лучший максимальный результат',
      'sum' => 'в таблицу заносится сумма / количество успешных действий',
      _ => 'результат заносится вручную по методике теста',
    };
    return 'Количество попыток: $attempts. Единица измерения: $unit. $ruleText.';
  }

  String _defaultMethodText(String code) {
    const m = {
      'run_10m': 'Игрок стартует по сигналу и пробегает 10 м по прямому коридору. Выполняются 2 попытки, фиксируется лучший результат.',
      'long_jump': 'Игрок выполняет прыжок с места от линии старта. Выполняются 3 попытки, измеряется лучший результат от линии до ближайшего следа приземления.',
      'run_30m': 'Игрок стартует по сигналу и пробегает 30 м по прямому коридору. Выполняются 2 попытки, фиксируется лучший результат.',
      'shuttle_3x10': 'Игрок выполняет челночный бег вокруг двух стоек на расстоянии 10 м. Всего 3 отрезка по 10 м, фиксируется лучший результат из 2 попыток.',
      'dribble_10m': 'Игрок ведёт мяч по коридору 10 м. В каждом отрезке 2 м должно быть минимум одно касание мяча. Первая попытка правой ногой, вторая — левой.',
      'dribble_direction_10m': 'Игрок ведёт мяч через 4 ворот шириной 0,5 м, расположенных на дистанции 10 м. Первая попытка правой ногой, вторая — левой.',
      'dribble_3x10': 'Игрок ведёт мяч вокруг двух стоек на дистанции 10 м по схеме 3×10 м. Первая попытка правой ногой, вторая — левой.',
      'shot_accuracy': 'Игрок выполняет 6 ударов по неподвижному мячу: 3 правой и 3 левой. Оценивается количество попаданий в заданную зону ворот.',
      'pass_accuracy': 'После ведения 5 м игрок выполняет передачу в зону шириной 1,5 м. Выполняются 3 передачи правой и 3 левой ногой.',
      'throw_distance': 'Игрок выполняет вбрасывание мяча из-за головы в коридор шириной 3 м. Фиксируется лучший результат из 3 попыток.',
      'head_juggling': 'Игрок подбрасывает мяч руками и выполняет жонглирование головой в круге диаметром 10 м. Фиксируется лучший результат из 3 попыток.',
      'one_vs_one_line': 'Игра 1×1: нападающий должен обыграть защитника и пересечь лицевую линию с мячом. Каждый игрок выполняет 10 атак.',
      'one_vs_one_goal': 'Игра 1×1 в двое ворот: нападающий должен обыграть защитника и забить ударом из-за 6-метровой линии.',
      'feints_1x1': 'Игра 1×1 с акцентом на финты. Нападающий должен обыграть защитника и пересечь лицевую линию.',
      'tackle_1x1': 'Игра 1×1 в обороне. Защитник получает балл, если не даёт себя обыграть, и дополнительный балл за гол после отбора.',
      'pass_game_2x1': 'Игровое упражнение 2×1. Два нападающих выполняют передачи на своих половинах поля, защитник пытается перехватить мяч.',
      'receive_game_2x1': 'Игровое упражнение 2×1. Оценивается приём мяча, после которого выполнена точная передача партнёру.',
      'position_2x1': 'Игра 2×1 с комбинациями: стенка, забегание, скрещивание. Оценивается успешное открывание и результативная атака.',
      'space_reduction_4x2': 'Игра 4×2. Защитники сокращают пространство, оказывают давление и получают баллы за перехваты, отборы и вынужденные ошибки.',
      'pressing_2x2': 'Игра 2×2. Защитники прессингуют соперников, не дают завести мяч за линию и могут получить дополнительный балл за гол после перехвата.',
    };
    return m[code] ?? 'Методика проведения теста добавлена в справочник и отображается из базы.';
  }

  String _defaultSchemeText(String code) {
    const m = {
      'run_10m': 'Прямой беговой коридор: длина 10 м, ширина 1,5 м.',
      'long_jump': 'Линия старта между двумя стойками на расстоянии 1 м. Измерение рулеткой от линии старта.',
      'run_30m': 'Прямой беговой коридор: длина 30 м, ширина 1,5 м.',
      'shuttle_3x10': 'Две стойки на расстоянии 10 м. Движение туда–обратно–туда.',
      'dribble_10m': 'Коридор ведения 10 м × 0,5 м, 5 отрезков по 2 м.',
      'dribble_direction_10m': 'Коридор 10 м × 2 м, 4 ворот шириной 0,5 м через каждые 2 м.',
      'dribble_3x10': 'Две стойки на расстоянии 10 м, ведение мяча 3×10 м вокруг стоек.',
      'shot_accuracy': 'U7–U9: 11 м до мини-ворот. U10–U13: 16,5 м до стандартных ворот. U14–U17: 20,15 м.',
      'pass_accuracy': 'Коридор 2 м. Ведение 5 м, затем передача в ворота/зону 1,5 м. Дистанция передачи: 5/10/15 м по возрасту.',
      'throw_distance': 'Коридор шириной 3 м, линия старта между стойками 1 м, измерение дальности вбрасывания.',
      'head_juggling': 'Круг диаметром 10 м.',
      'one_vs_one_line': 'Поле 10×10 м. Игроки стартуют с противоположных лицевых линий.',
      'one_vs_one_goal': 'Поле 15×10 м, зона удара за 6-метровой линией, мини-ворота и малые ворота.',
      'feints_1x1': 'Поле 10×8 м, малые ворота 1,5 м на линии нападающего.',
      'tackle_1x1': 'Поле 10×8 м, мини-футбольные ворота.',
      'pass_game_2x1': 'Поле 15×10 м, центральная линия, 2 малых ворот шириной 1,5 м.',
      'receive_game_2x1': 'Поле 15×10 м, центральная линия, 2 малых ворот шириной 1,5 м.',
      'position_2x1': 'Поле 15×10 м, центральная линия, 2 малых ворот шириной 1,5 м.',
      'space_reduction_4x2': 'Поле 15×12 м, 6 малых ворот шириной 1,5 м.',
      'pressing_2x2': 'Поле 15×12 м, 2 малых ворот шириной 1,5 м.',
    };
    return m[code] ?? 'Схема строится по размерам, указанным в методике.';
  }

  String _schemeLegend(String code) {
    if (code.contains('dribble')) return 'Зелёная линия показывает движение игрока с мячом. Конусы/стойки отмечены точками, размеры указаны на схеме.';
    if (code.contains('run') || code == 'shuttle_3x10') return 'Старт, финиш и стойки показаны на схеме. Для скоростных тестов важно одинаковое покрытие и одинаковые условия.';
    if (code.contains('shot')) return 'Показаны дистанция удара, ворота и зоны точности. Дистанция меняется по возрасту.';
    if (code.contains('pass')) return 'Показаны зона ведения, коридор передачи и целевая зона между стойками.';
    return 'Схема даёт тренеру быстрый ориентир по расстановке игроков, ворот, линий и размеров площадки.';
  }

  Widget _error() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, color: _CmrTestColors.red, size: 42),
        const SizedBox(height: 10),
        Text(error ?? 'Ошибка', textAlign: TextAlign.center, style: _CmrTestText.muted(14)),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _load,
          style: OutlinedButton.styleFrom(
            foregroundColor: _CmrTestColors.graphite,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Повторить'),
        ),
      ]),
    ),
  );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((e) => e.substring(0, 1).toUpperCase()).join();
  }

  Color _darken(Color c) => Color.fromARGB(c.alpha, (c.red * .7).round(), (c.green * .7).round(), (c.blue * .7).round());
}

// ==================== Компоненты ====================

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool filled;
  final bool compact;
  final bool isLoading;

  const _IconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.filled = false,
    this.compact = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 38.0;
    final bgColor = filled ? _CmrTestColors.greenSoft : _CmrTestColors.soft;
    final fgColor = filled ? _CmrTestColors.greenDark : _CmrTestColors.graphite;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isLoading ? null : onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.transparent, width: 0),
          ),
          child: isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _CmrTestColors.greenDark))
              : Icon(icon, color: fgColor, size: size * 0.48),
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final double size;

  const _IconBox({required this.icon, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CmrTestColors.panel,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: _CmrTestColors.green, size: size * 0.48),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _CmrTestColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _CmrTestColors.line, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _CmrTestColors.green, size: 19),
              const SizedBox(width: 8),
              Text(text, style: _CmrTestText.action()),
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
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _CmrTestColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _CmrTestColors.line, width: 1),
          ),
          child: Icon(icon, color: _CmrTestColors.text, size: size * 0.55),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String code;
  final String title;
  final String hint;
  final IconData icon;
  final bool active;
  final bool compact;
  final bool isTightDesktop;
  final bool isVeryTight;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.code,
    required this.title,
    required this.hint,
    required this.icon,
    required this.active,
    required this.compact,
    required this.isTightDesktop,
    required this.isVeryTight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleFontSize = compact ? 11.2 : (isVeryTight ? 10.4 : isTightDesktop ? 10.9 : 11.6);
    final iconBox = compact ? 30.0 : (isTightDesktop ? 23.0 : 25.0);
    final iconSize = compact ? 16.0 : (isTightDesktop ? 13.5 : 14.5);
    final horizontalPadding = compact ? 11.0 : (isTightDesktop ? 9.0 : 11.0);
    final verticalPadding = compact ? 10.0 : 8.0;
    final radius = BorderRadius.circular(10);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: compact ? 158 : null,
          constraints: compact ? const BoxConstraints(minHeight: 58) : const BoxConstraints(minHeight: 38),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: active ? _CmrTestColors.greenSoft : _CmrTestColors.panel,
            borderRadius: radius,

          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                child: Row(
                  mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : _CmrTestColors.panel,
                        borderRadius: BorderRadius.circular(compact ? 10 : 9),
                      ),
                      child: Icon(icon, size: iconSize, color: active ? _CmrTestColors.green : _CmrTestColors.muted),
                    ),
                    SizedBox(width: compact ? 7 : 6),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: compact ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: _CmrTestText.value(titleFontSize).copyWith(
                                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                                color: _CmrTestColors.text,
                              ),
                            ),
                          ),
                        ],
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
  }
}

class _PositionChip extends StatelessWidget {
  final String value;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _PositionChip({
    required this.value,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: active ? _CmrTestColors.greenSoft : _CmrTestColors.panel,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$label · $count',
            style: _CmrTestText.caption().copyWith(
              color: _CmrTestColors.text,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onClear;
  final bool compact;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onClear,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 6 : 7),
      decoration: _CmrTestDecor.softCard(radius: compact ? 14 : 16),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: compact ? 19 : 22, color: _CmrTestColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: _CmrTestText.value(compact ? 13 : 14),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                hintStyle: _CmrTestText.muted(compact ? 12.5 : 14),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

// ==================== Остальные классы ====================

class TestingApi {
  static const String base = 'https://sportotekaapp.ru/api';
}

class _Rating {
  final String code;
  final Color color;
  final String label;
  final int points;
  const _Rating(this.code, this.color, this.label, {this.points = 0});
  factory _Rating.empty() => const _Rating('', Colors.transparent, '', points: 0);
  factory _Rating.fromHex(String code, String hex, String label, {int? points}) {
    final clean = hex.replaceAll('#', '');
    final value = int.tryParse('FF$clean', radix: 16) ?? 0x00000000;
    final autoPoints = code == 'excellent' ? 4 : code == 'good' ? 3 : code == 'satisfactory' ? 2 : code == 'poor' ? 1 : 0;
    return _Rating(code, Color(value), label, points: points ?? autoPoints);
  }
}

class _PhysicalNorms {
  static final Map<String, Map<String, List<double?>>> norms = {
    'U6': {'run_10m':[null,2.25,2.30,2.35], 'long_jump':[120,110,100,null]},
    'U7': {'run_10m':[null,2.20,2.25,2.30], 'long_jump':[140,130,120,null], 'run_30m':[null,5.70,5.85,6.00], 'shuttle_3x10':[null,8.90,9.10,9.30]},
    'U8': {'run_10m':[null,2.15,2.20,2.25], 'long_jump':[160,150,140,null], 'run_30m':[null,5.50,5.65,5.80], 'shuttle_3x10':[null,8.60,8.80,9.00]},
    'U9': {'run_10m':[null,2.10,2.15,2.20], 'long_jump':[180,170,160,null], 'run_30m':[null,5.30,5.45,5.60], 'shuttle_3x10':[null,8.30,8.50,8.70]},
    'U10': {'run_10m':[null,2.05,2.10,2.15], 'long_jump':[200,190,180,null], 'run_30m':[null,5.10,5.25,5.40], 'shuttle_3x10':[null,8.00,8.20,8.40]},
    'U11': {'run_10m':[null,2.05,2.10,2.15], 'long_jump':[200,190,180,null], 'run_30m':[null,5.10,5.25,5.40], 'shuttle_3x10':[null,8.00,8.20,8.40]},
    'U12': {'run_10m':[null,2.00,2.05,2.10], 'long_jump':[210,200,190,null], 'run_30m':[null,4.90,5.05,5.20], 'shuttle_3x10':[null,7.75,7.95,8.15]},
    'U13': {'run_10m':[null,1.95,2.00,2.05], 'long_jump':[220,210,200,null], 'run_30m':[null,4.70,4.85,5.00], 'shuttle_3x10':[null,7.50,7.70,7.90]},
    'U14': {'run_10m':[null,1.90,1.95,2.00], 'long_jump':[230,220,210,null], 'run_30m':[null,4.50,4.65,4.80], 'shuttle_3x10':[null,7.25,7.45,7.65]},
    'U15': {'run_10m':[null,1.85,1.90,1.95], 'long_jump':[240,230,220,null], 'run_30m':[null,4.30,4.45,4.60], 'shuttle_3x10':[null,7.00,7.20,7.40]},
    'U16': {'run_10m':[null,1.80,1.85,1.90], 'long_jump':[250,240,230,null], 'run_30m':[null,4.15,4.30,4.45], 'shuttle_3x10':[null,6.75,6.95,7.15]},
    'U17': {'run_10m':[null,1.75,1.80,1.85], 'long_jump':[260,250,240,null], 'run_30m':[null,4.00,4.15,4.30], 'shuttle_3x10':[null,6.50,6.70,6.90]},
  };

  static _Rating rate(double v, List<double?> m, bool lowerIsBetter) {
    if (lowerIsBetter) {
      if (v <= m[1]!) return const _Rating('excellent', _CmrTestColors.green, 'Отлично', points: 4);
      if (v <= m[2]!) return const _Rating('good', _CmrTestColors.yellow, 'Хорошо', points: 3);
      if (v <= m[3]!) return const _Rating('satisfactory', _CmrTestColors.orange, 'Удовлетворительно', points: 2);
      return const _Rating('poor', _CmrTestColors.red, 'Неудовлетворительно', points: 1);
    }
    if (v >= m[0]!) return const _Rating('excellent', _CmrTestColors.green, 'Отлично', points: 4);
    if (v >= m[1]!) return const _Rating('good', _CmrTestColors.yellow, 'Хорошо', points: 3);
    if (v >= m[2]!) return const _Rating('satisfactory', _CmrTestColors.orange, 'Удовлетворительно', points: 2);
    return const _Rating('poor', _CmrTestColors.red, 'Неудовлетворительно', points: 1);
  }
}

// ==================== _TestSchemePainter ====================

class _TestSchemePainter extends CustomPainter {
  final String code;
  final String title;

  const _TestSchemePainter({required this.code, required this.title});

  @override
  void paint(Canvas canvas, Size size) {
    final field = RRect.fromRectAndRadius(Offset(18, 18) & Size(size.width - 36, size.height - 36), const Radius.circular(18));
    final bg = Paint()..color = const Color(0xFFF2F7F4);
    final line = Paint()
      ..color = const Color(0xFF1F7A4D)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(field, bg);
    canvas.drawRRect(field, line);

    final c = code.toLowerCase();
    if (c == 'run_10m') return _drawStraight(canvas, size, '10 м', '1,5 м');
    if (c == 'run_30m') return _drawStraight(canvas, size, '30 м', '1,5 м');
    if (c == 'shuttle_3x10') return _drawShuttle(canvas, size, withBall: false);
    if (c == 'dribble_10m') return _drawDribbleLanes(canvas, size);
    if (c == 'dribble_direction_10m') return _drawDribbleGates(canvas, size);
    if (c == 'dribble_3x10') return _drawShuttle(canvas, size, withBall: true);
    if (c == 'long_jump') return _drawJump(canvas, size);
    if (c == 'shot_accuracy') return _drawShot(canvas, size);
    if (c == 'pass_accuracy') return _drawPass(canvas, size);
    if (c == 'throw_distance') return _drawThrow(canvas, size);
    if (c == 'head_juggling') return _drawCircle(canvas, size, 'Ø 10 м');
    if (c.contains('4x2')) return _drawGame(canvas, size, '15 м', '12 м', attackers: 4, defenders: 2, goals: 6);
    if (c.contains('2x2')) return _drawGame(canvas, size, '15 м', '12 м', attackers: 2, defenders: 2, goals: 2);
    if (c.contains('2x1') || c.contains('position')) return _drawGame(canvas, size, '15 м', '10 м', attackers: 2, defenders: 1, goals: 2);
    if (c.contains('goal')) return _drawShotGame(canvas, size);
    if (c.contains('1x1') || c.contains('one_vs_one') || c.contains('feints') || c.contains('tackle')) return _drawGame(canvas, size, c.contains('feints') || c.contains('tackle') ? '10 м' : '10 м', c.contains('feints') || c.contains('tackle') ? '8 м' : '10 м', attackers: 1, defenders: 1, goals: c.contains('line') ? 0 : 1);
    _drawGame(canvas, size, '15 м', '10 м', attackers: 2, defenders: 1, goals: 2);
  }

  void _drawStraight(Canvas canvas, Size size, String length, String width) {
    final p = Paint()..color = const Color(0xFF1F7A4D)..strokeWidth = 4..strokeCap = StrokeCap.round;
    final y = size.height * .52;
    final x1 = size.width * .18;
    final x2 = size.width * .82;
    canvas.drawLine(Offset(x1, y), Offset(x2, y), p);
    _flag(canvas, Offset(x1, y), 'Старт');
    _flag(canvas, Offset(x2, y), 'Финиш');
    _arrow(canvas, Offset(x1 + 20, y), Offset(x2 - 20, y));
    _label(canvas, length, Offset(size.width * .48, y - 38));
    _label(canvas, width, Offset(x1 - 8, y + 32));
  }

  void _drawShuttle(Canvas canvas, Size size, {required bool withBall}) {
    final y = size.height * .52;
    final a = Offset(size.width * .28, y);
    final b = Offset(size.width * .72, y);
    _cone(canvas, a); _cone(canvas, b);
    _arrow(canvas, Offset(a.dx + 10, y - 18), Offset(b.dx - 10, y - 18));
    _arrow(canvas, Offset(b.dx - 10, y + 4), Offset(a.dx + 10, y + 4));
    _arrow(canvas, Offset(a.dx + 10, y + 26), Offset(b.dx - 10, y + 26));
    if (withBall) _ball(canvas, Offset(a.dx + 24, y - 34));
    _label(canvas, '10 м', Offset(size.width * .48, y - 62));
    _label(canvas, withBall ? 'ведение 3×10 м' : 'челнок 3×10 м', Offset(size.width * .40, y + 54));
  }

  void _drawDribbleLanes(Canvas canvas, Size size) {
    final left = size.width * .2, right = size.width * .8, top = size.height * .42, bottom = size.height * .58;
    final paint = Paint()..color = const Color(0xFF1F7A4D)..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
    for (var i = 1; i < 5; i++) {
      final x = left + (right - left) / 5 * i;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 1);
    }
    _arrow(canvas, Offset(left + 12, (top + bottom) / 2), Offset(right - 12, (top + bottom) / 2));
    _ball(canvas, Offset(left + 30, (top + bottom) / 2 - 22));
    _label(canvas, '10 м', Offset(size.width * .48, top - 36));
    _label(canvas, '5 зон по 2 м', Offset(size.width * .42, bottom + 18));
    _label(canvas, '0,5 м', Offset(left - 2, bottom + 44));
  }

  void _drawDribbleGates(Canvas canvas, Size size) {
    final left = size.width * .22, right = size.width * .78, y = size.height * .52;
    _arrow(canvas, Offset(left, y), Offset(right, y));
    for (var i = 0; i < 4; i++) {
      final x = left + (right - left) / 3 * i;
      _gate(canvas, Offset(x, y), vertical: i.isOdd);
    }
    _ball(canvas, Offset(left - 16, y - 24));
    _label(canvas, '10 м', Offset(size.width * .48, y - 70));
    _label(canvas, '4 ворот по 0,5 м', Offset(size.width * .38, y + 54));
    _label(canvas, 'коридор 2 м', Offset(size.width * .39, y + 78));
  }

  void _drawJump(Canvas canvas, Size size) {
    final x = size.width * .28;
    final y = size.height * .66;
    final paint = Paint()..color = const Color(0xFF1F7A4D)..strokeWidth = 4;
    canvas.drawLine(Offset(x, y - 70), Offset(x, y + 35), paint);
    _cone(canvas, Offset(x, y - 70)); _cone(canvas, Offset(x, y + 35));
    _arrow(canvas, Offset(x + 16, y), Offset(size.width * .78, y));
    _label(canvas, '1 м линия старта', Offset(x - 50, y + 52));
    _label(canvas, 'измерение прыжка', Offset(size.width * .46, y - 36));
  }

  void _drawShot(Canvas canvas, Size size) {
    final goal = Rect.fromLTWH(size.width * .65, size.height * .34, size.width * .18, size.height * .32);
    canvas.drawRect(goal, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawRect(goal, Paint()..color = const Color(0xFF1F7A4D)..strokeWidth = 2..style = PaintingStyle.stroke);
    canvas.drawLine(Offset(goal.left + goal.width * .33, goal.top), Offset(goal.left + goal.width * .33, goal.bottom), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 1);
    canvas.drawLine(Offset(goal.left + goal.width * .67, goal.top), Offset(goal.left + goal.width * .67, goal.bottom), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 1);
    final ball = Offset(size.width * .26, size.height * .58);
    _ball(canvas, ball);
    _arrow(canvas, Offset(ball.dx + 18, ball.dy - 8), Offset(goal.left - 12, goal.center.dy));
    _label(canvas, '11 / 16,5 / 20,15 м', Offset(size.width * .36, size.height * .44));
    _label(canvas, 'зоны точности', Offset(goal.left - 10, goal.top - 26));
  }

  void _drawShotGame(Canvas canvas, Size size) {
    _drawGame(canvas, size, '15 м', '10 м', attackers: 1, defenders: 1, goals: 2);
    _label(canvas, 'удар из-за 6 м', Offset(size.width * .42, size.height * .72));
  }

  void _drawPass(Canvas canvas, Size size) {
    final y = size.height * .56;
    final start = Offset(size.width * .18, y);
    final pass = Offset(size.width * .42, y);
    final target = Offset(size.width * .76, y);
    _ball(canvas, start);
    _arrow(canvas, start.translate(16, 0), pass);
    _arrow(canvas, pass, target.translate(-22, 0));
    _gate(canvas, target, vertical: true);
    _label(canvas, 'ведение 5 м', Offset(size.width * .24, y - 42));
    _label(canvas, 'передача 5/10/15 м', Offset(size.width * .47, y - 42));
    _label(canvas, 'зона 1,5 м', Offset(size.width * .68, y + 42));
  }

  void _drawThrow(Canvas canvas, Size size) {
    final y = size.height * .62;
    final start = Offset(size.width * .22, y);
    _gate(canvas, start, vertical: true);
    _arrow(canvas, start.translate(26, -8), Offset(size.width * .78, y - 46));
    _label(canvas, 'коридор 3 м', Offset(size.width * .18, y + 48));
    _label(canvas, 'измерение дальности', Offset(size.width * .46, y - 74));
  }

  void _drawCircle(Canvas canvas, Size size, String label) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .28;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white.withOpacity(.8)..style = PaintingStyle.fill);
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1F7A4D)..strokeWidth = 2..style = PaintingStyle.stroke);
    _ball(canvas, center.translate(-14, -16));
    _label(canvas, label, center.translate(-24, radius + 18));
  }

  void _drawGame(Canvas canvas, Size size, String length, String width, {required int attackers, required int defenders, required int goals}) {
    final left = size.width * .18, right = size.width * .82, top = size.height * .25, bottom = size.height * .75;
    final mid = (left + right) / 2;
    canvas.drawLine(Offset(mid, top), Offset(mid, bottom), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 1.2);
    for (var i = 0; i < attackers; i++) _player(canvas, Offset(left + 40, top + 38 + i * 34), const Color(0xFF22C55E), 'Н');
    for (var i = 0; i < defenders; i++) _player(canvas, Offset(right - 40, top + 52 + i * 38), const Color(0xFFEF4444), 'З');
    if (goals > 0) {
      _miniGoal(canvas, Offset(left, (top + bottom) / 2));
      _miniGoal(canvas, Offset(right, (top + bottom) / 2));
    }
    _arrow(canvas, Offset(left + 70, (top + bottom) / 2), Offset(right - 76, (top + bottom) / 2));
    _label(canvas, length, Offset(size.width * .48, top - 32));
    _label(canvas, width, Offset(left - 22, (top + bottom) / 2));
  }

  void _arrow(Canvas canvas, Offset a, Offset b) {
    final p = Paint()..color = const Color(0xFF1F7A4D)..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, p);
    final dir = (b - a);
    final len = dir.distance == 0 ? 1 : dir.distance;
    final ux = dir.dx / len, uy = dir.dy / len;
    final left = Offset(b.dx - ux * 12 - uy * 6, b.dy - uy * 12 + ux * 6);
    final right = Offset(b.dx - ux * 12 + uy * 6, b.dy - uy * 12 - ux * 6);
    canvas.drawLine(b, left, p); canvas.drawLine(b, right, p);
  }

  void _flag(Canvas canvas, Offset o, String text) {
    canvas.drawCircle(o, 7, Paint()..color = const Color(0xFF1F7A4D));
    _label(canvas, text, o.translate(-22, 16));
  }

  void _cone(Canvas canvas, Offset o) {
    final path = Path()..moveTo(o.dx, o.dy - 10)..lineTo(o.dx - 9, o.dy + 9)..lineTo(o.dx + 9, o.dy + 9)..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFF59E0B));
  }

  void _gate(Canvas canvas, Offset o, {required bool vertical}) {
    if (vertical) {
      _cone(canvas, o.translate(0, -18)); _cone(canvas, o.translate(0, 18));
    } else {
      _cone(canvas, o.translate(-18, 0)); _cone(canvas, o.translate(18, 0));
    }
  }

  void _ball(Canvas canvas, Offset o) {
    canvas.drawCircle(o, 9, Paint()..color = Colors.white);
    canvas.drawCircle(o, 9, Paint()..color = const Color(0xFF111827)..strokeWidth = 1.4..style = PaintingStyle.stroke);
    canvas.drawCircle(o, 2.5, Paint()..color = const Color(0xFF111827));
  }

  void _player(Canvas canvas, Offset o, Color color, String text) {
    canvas.drawCircle(o, 14, Paint()..color = color.withOpacity(.9));
    _label(canvas, text, o.translate(-5, -7), color: Colors.white, size: 10, bold: true);
  }

  void _miniGoal(Canvas canvas, Offset o) {
    canvas.drawRect(Rect.fromCenter(center: o, width: 10, height: 70), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromCenter(center: o, width: 10, height: 70), Paint()..color = const Color(0xFF1F7A4D)..strokeWidth = 2..style = PaintingStyle.stroke);
  }

  void _label(Canvas canvas, String text, Offset o, {Color color = const Color(0xFF101828), double size = 11, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w700)),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 150);
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(covariant _TestSchemePainter oldDelegate) => oldDelegate.code != code || oldDelegate.title != title;
}