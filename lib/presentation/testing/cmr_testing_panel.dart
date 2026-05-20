// lib/presentation/testing/cmr_testing_panel.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

class CmrTestingPanel extends StatefulWidget {
  final int clubId;
  final int teamId;
  final String clubName;
  final String teamName;
  final String? initialStage;
  final int? userId;
  final String? initialDate;
  final VoidCallback? onBackToMenu;

  const CmrTestingPanel({
    super.key,
    required this.clubId,
    required this.teamId,
    required this.clubName,
    required this.teamName,
    this.initialStage,
    this.userId,
    this.initialDate,
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
  String? error;

  bool _infoPanelCollapsed = false;
  String _positionFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> stages = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> tests = [];
  List<Map<String, dynamic>> normatives = [];
  List<Map<String, dynamic>> players = [];

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    stage = _initialStageForTeam();
    _selectedDate = _parseDate(widget.initialDate) ?? DateTime.now();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _searchController.dispose();
    super.dispose();
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

    // Прыжок в длину в интерфейсе ведём в сантиметрах.
    // Если в старых сохранённых данных попалось значение в метрах (2,19),
    // показываем его тренеру как 219.
    if (testCode == 'long_jump' && parsed != null && parsed > 0 && parsed < 20) {
      return _formatNumber(parsed * 100, fraction: 0);
    }

    return raw.replaceAll('.', ',');
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
      case 'МЯЧ+ВОРОТА+СОПЕРНИК+ПАРТНЁР':
      case 'М+В+С+ПАРТНЕР':
      case 'М+В+С+ПАРТНЁР':
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
      'январь', 'февраль', 'март', 'апрель', 'май', 'июнь',
      'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'
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

      // Важно: если на выбранную дату тестирования ещё нет,
      // не берём старые результаты, даже если get_testing_matrix вернул последнюю сессию.
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

  Future<void> _save() async {
    setState(() => saving = true);
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
      sessionId = _asInt(data['session_id']);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Результаты сохранены')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _categoryTitle(String code) {
    for (final c in categories) {
      if (_asStr(c['code']) == code) return _asStr(c['title']);
    }
    switch (code) {
      case 'technical': return 'Техническая подготовка';
      case 'tactical': return 'Тактическая подготовка';
      default: return 'Физическая подготовка';
    }
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
    // Прыжок в длину в таблице и нормативе показываем в сантиметрах.
    // На всякий случай, если тренер введёт 2,19, для расчёта считаем это 219 см.
    if (testCode == 'long_jump' && value > 0 && value < 20) {
      return value * 100;
    }
    return value;
  }

  _Rating _finalFor(Map<String, dynamic> p) {
    int points = 0;
    int count = 0;
    for (final t in tests) {
      final code = _asStr(t['code']);
      final rating = _ratingFor(code, _controllers[_key(_playerId(p), code)]?.text ?? '');
      if (rating.points > 0) {
        points += rating.points;
        count++;
      }
    }
    if (count == 0) return _Rating.empty();
    final avg = points / count;
    if (avg >= 3.6) return _Rating('excellent', const Color(0xFF22C55E), 'Отлично', points: 4);
    if (avg >= 2.6) return _Rating('good', const Color(0xFFFACC15), 'Хорошо', points: 3);
    if (avg >= 1.6) return _Rating('satisfactory', const Color(0xFFFB923C), 'Удовлетворительно', points: 2);
    return _Rating('poor', const Color(0xFFEF4444), 'Неудовлетворительно', points: 1);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 760;
    return Container(
      color: _C.page,
      child: Column(
        children: [
          _header(isMobile),
          const Divider(height: 1, color: _C.line),
          if (saving) const LinearProgressIndicator(minHeight: 2, color: _C.green),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: _C.green))
                : error != null
                    ? _error()
                    : isMobile
                        ? _mobileBody()
                        : _desktopBody(),
          ),
        ],
      ),
    );
  }

  Widget _header(bool mobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(mobile ? 10 : 16, 10, mobile ? 10 : 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBackToMenu,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Назад',
          ),
          const SizedBox(width: 4),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _C.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.fact_check_rounded, color: _C.greenDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Тестирование', maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.h1.copyWith(fontSize: mobile ? 18 : 22)),
                const SizedBox(height: 2),
                Text('${widget.clubName} • ${widget.teamName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption),
              ],
            ),
          ),
          if (!mobile) ...[
            _filterBar(compact: false),
            const SizedBox(width: 10),
          ],
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: _C.greenDark,
              foregroundColor: Colors.white,
              fixedSize: const Size(42, 42),
              minimumSize: const Size(42, 42),
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: _C.greenDark.withOpacity(.25),
            ),
            onPressed: _openFullscreen,
            tooltip: 'Открыть тестирование во весь экран',
            icon: const Icon(Icons.open_in_full_rounded, size: 20),
          ),
          const SizedBox(width: 8),
          _exportButton(mobile: mobile),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _C.greenDark, foregroundColor: Colors.white),
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(mobile ? 'Сохранить' : 'Сохранить результаты'),
          ),
        ],
      ),
    );
  }

  Widget _filterBar({required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _drop(
          value: category,
          items: categories.isEmpty
              ? const [
                  {'code': 'physical', 'title': 'Физическая подготовка'},
                  {'code': 'technical', 'title': 'Техническая подготовка'},
                  {'code': 'tactical', 'title': 'Тактическая подготовка'},
                ]
              : categories,
          onChanged: (v) {
            if (v == null) return;
            setState(() { category = v; sessionId = 0; });
            _load();
          },
          compact: compact,
        ),
        const SizedBox(width: 8),
        _stageChip(compact: compact),
      ],
    );
  }

  Widget _stageChip({required bool compact}) {
    return Tooltip(
      message: 'Этап подготовки автоматически привязан к выбранной команде',
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: _C.greenSoft, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 15, color: _C.greenDark),
            const SizedBox(width: 6),
            Text(
              compact ? stage : 'Этап $stage',
              style: _C.body.copyWith(fontSize: compact ? 12 : 13, color: _C.greenDark, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drop({required String value, required List<Map<String, dynamic>> items, required ValueChanged<String?> onChanged, required bool compact}) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: _C.input, borderRadius: BorderRadius.circular(14)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          borderRadius: BorderRadius.circular(16),
          style: _C.body.copyWith(fontSize: compact ? 12 : 13),
          onChanged: onChanged,
          items: items.map((e) => DropdownMenuItem<String>(
            value: _asStr(e['code']),
            child: Text(compact ? _asStr(e['code']) : _asStr(e['title']), overflow: TextOverflow.ellipsis),
          )).toList(),
        ),
      ),
    );
  }

  Widget _desktopBody() {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: _infoPanelCollapsed ? 58 : 292,
          child: _side(),
        ),
        const VerticalDivider(width: 1, color: _C.line),
        Expanded(child: _tableArea()),
      ],
    );
  }

  Widget _mobileBody() {
    return Column(
      children: [
        Container(color: Colors.white, padding: const EdgeInsets.all(10), child: _filterBar(compact: true)),
        const Divider(height: 1, color: _C.line),
        Expanded(child: _tableArea()),
      ],
    );
  }

  Widget _side() {
    if (_infoPanelCollapsed) {
      return Container(
        color: Colors.white,
        child: Column(
          children: [
            const SizedBox(height: 10),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: _C.greenDark,
                foregroundColor: Colors.white,
                fixedSize: const Size(42, 42),
                minimumSize: const Size(42, 42),
                shape: const CircleBorder(),
                elevation: 2,
                shadowColor: _C.greenDark.withOpacity(.25),
              ),
              onPressed: () => setState(() => _infoPanelCollapsed = false),
              tooltip: 'Показать подсказки и тесты',
              icon: const Icon(Icons.keyboard_double_arrow_right_rounded, size: 20),
            ),
            const SizedBox(height: 12),
            RotatedBox(
              quarterTurns: 3,
              child: Text('Подсказки', style: _C.caption.copyWith(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
            child: Row(
              children: [
                Expanded(child: Text('Подсказки и тесты', style: _C.h2)),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: _C.greenDark,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(38, 38),
                    minimumSize: const Size(38, 38),
                    shape: const CircleBorder(),
                    elevation: 2,
                    shadowColor: _C.greenDark.withOpacity(.25),
                  ),
                  onPressed: () => setState(() => _infoPanelCollapsed = true),
                  tooltip: 'Свернуть панель влево',
                  icon: const Icon(Icons.keyboard_double_arrow_left_rounded, size: 19),
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
                Text('Тесты в этом этапе', style: _C.h2),
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
      decoration: BoxDecoration(color: _C.tile, borderRadius: BorderRadius.circular(18), border: Border.all(color: _C.line.withOpacity(.75))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_2_rounded, size: 18, color: _C.greenDark),
              const SizedBox(width: 8),
              Expanded(child: Text('Амплуа игроков', style: _C.h2)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _positionChip('all', 'Все', players.length),
              ...items.map((e) => _positionChip(e.key, e.key, e.value)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _positionChip(String value, String label, int count) {
    final active = _positionFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() => _positionFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _C.greenDark : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _C.greenDark : _C.line),
        ),
        child: Text(
          '$label · $count',
          style: _C.caption.copyWith(
            color: active ? Colors.white : _C.text,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _testHint(Map<String, dynamic> t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _C.tile, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.sports_soccer_rounded, color: _C.greenDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_asStr(t['short_title']), style: _C.body.copyWith(fontWeight: FontWeight.w900)),
                Text(_unitForTest(t), style: _C.caption),
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
      decoration: BoxDecoration(color: _C.greenSoft, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: _C.h2.copyWith(color: _C.greenDark)),
        const SizedBox(height: 6),
        Text(text, style: _C.caption.copyWith(color: _C.greenDark, height: 1.25)),
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

  List<Map<String, dynamic>> get _visiblePlayers {
    final query = _searchController.text.trim().toLowerCase();
    return players.where((p) {
      final pos = _playerPosition(p);
      if (_positionFilter != 'all' && pos != _positionFilter) return false;
      if (query.isEmpty) return true;
      final haystack = '${_playerFullName(p)} ${_shortPlayerName(p)} ${_playerPosition(p)} ${p['number'] ?? p['player_number'] ?? ''}'.toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Widget _playerAvatar(Map<String, dynamic> p) {
    final url = _playerAvatarUrl(p);
    final initials = _initials(_playerFullName(p));
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 17,
        backgroundColor: _C.greenSoft,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        child: const SizedBox.shrink(),
      );
    }
    return CircleAvatar(
      radius: 17,
      backgroundColor: _C.greenSoft,
      child: Text(initials, style: const TextStyle(color: _C.greenDark, fontWeight: FontWeight.w900, fontSize: 11)),
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

    // В ответах API часто приходит порядок «Имя Фамилия».
    // Поэтому в запасном варианте фамилией считаем последний элемент,
    // а имя сокращаем до первой буквы.
    final surname = parts.last;
    final nameInitial = parts.first.isNotEmpty ? ' ${parts.first.substring(0, 1).toUpperCase()}.' : '';
    return '$surname$nameInitial';
  }

  Widget _tableArea() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          LayoutBuilder(builder: (context, c) => _dateCalendarBar(compact: c.maxWidth < 720)),
          const Divider(height: 1, color: _C.line),
          _tableToolbar(),
          const Divider(height: 1, color: _C.line),
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
                  _dateStepButton(Icons.chevron_left_rounded, () => _selectTestingDate(_selectedDate.subtract(const Duration(days: 1))), 'Предыдущий день'),
                  _dateStepButton(Icons.chevron_right_rounded, () => _selectTestingDate(_selectedDate.add(const Duration(days: 1))), 'Следующий день'),
                ]),
                const SizedBox(height: 8),
                _dateStatusChip(label, hasData),
              ],
            )
          : Row(
              children: [
                _dateSelectorButton(),
                const SizedBox(width: 8),
                _dateStepButton(Icons.chevron_left_rounded, () => _selectTestingDate(_selectedDate.subtract(const Duration(days: 1))), 'Предыдущий день'),
                _dateStepButton(Icons.chevron_right_rounded, () => _selectTestingDate(_selectedDate.add(const Duration(days: 1))), 'Следующий день'),
                const SizedBox(width: 10),
                _dateStatusChip(label, hasData),
                const Spacer(),
                if (sessions.isNotEmpty)
                  Text('Сохранённых дат: ${sessions.length}', style: _C.caption.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
    );
  }

  Widget _dateSelectorButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _showCalendarDialog,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _C.greenSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.greenDark.withOpacity(.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded, color: _C.greenDark, size: 19),
            const SizedBox(width: 8),
            Text(_dateRu(_selectedDate), style: _C.body.copyWith(color: _C.greenDark, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _C.greenDark, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _dateStepButton(IconData icon, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(color: _C.input, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.line)),
          child: Icon(icon, size: 20, color: _C.text),
        ),
      ),
    );
  }

  Widget _dateStatusChip(String label, bool hasData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: hasData ? const Color(0xFFEAF8F0) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasData ? Icons.check_circle_rounded : Icons.edit_calendar_rounded, size: 16, color: hasData ? _C.greenDark : const Color(0xFFC2410C)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _C.caption.copyWith(
                color: hasData ? _C.greenDark : const Color(0xFFC2410C),
                fontWeight: FontWeight.w900,
              ),
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
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 30, offset: const Offset(0, 18)),
                  ]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: _C.greenSoft, borderRadius: BorderRadius.circular(15)),
                            child: const Icon(Icons.calendar_month_rounded, color: _C.greenDark),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Дата тестирования', style: _C.h1.copyWith(fontSize: 20))),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(color: _C.tile, borderRadius: BorderRadius.circular(18)),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => localSetState(() => visibleMonth = DateTime(visibleMonth.year, visibleMonth.month - 1)),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Expanded(child: Center(child: Text(_monthTitle(visibleMonth), style: _C.h2.copyWith(fontSize: 16)))),
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
                            .map((d) => Expanded(child: Center(child: Text(d, style: _C.caption.copyWith(fontWeight: FontWeight.w900)))))
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
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => localSetState(() => picked = date),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected ? _C.greenDark : saved ? _C.greenSoft : today ? _C.input : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: selected ? _C.greenDark : saved ? _C.greenDark.withOpacity(.28) : _C.line.withOpacity(.75)),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      '$day',
                                      style: _C.body.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: selected ? Colors.white : _C.text,
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
                                          color: selected ? Colors.white : _C.greenDark,
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
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _C.greenDark,
                                  side: const BorderSide(color: _C.greenDark, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  textStyle: _C.body.copyWith(fontWeight: FontWeight.w900),
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
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _C.greenDark,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  textStyle: _C.body.copyWith(fontWeight: FontWeight.w900),
                                ),
                                onPressed: () => Navigator.pop(dialogContext, picked),
                                child: FittedBox(child: Text(_hasSessionOn(picked) ? 'Открыть дату' : 'Создать на дату')),
                              ),
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


  Widget _tableToolbar() {
    final visible = _visiblePlayers.length;
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 720;
        final search = TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            hintText: 'Поиск по игроку...',
            filled: true,
            fillColor: _C.input,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            suffixIcon: _searchController.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
        );

        final positions = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _positionChip('all', 'Все амплуа', players.length),
              const SizedBox(width: 6),
              ..._positionItems.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _positionChip(e.key, e.key, e.value),
                  )),
            ],
          ),
        );

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    search,
                    const SizedBox(height: 8),
                    positions,
                    const SizedBox(height: 6),
                    Text('Показано: $visible из ${players.length}', style: _C.caption.copyWith(fontWeight: FontWeight.w800)),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(width: 280, child: search),
                    const SizedBox(width: 10),
                    Expanded(child: positions),
                    const SizedBox(width: 10),
                    Text('Показано: $visible из ${players.length}', style: _C.caption.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
        );
      },
    );
  }

  Widget _table() {
    if (tests.isEmpty) {
      return const Center(child: Text('Для выбранного этапа пока нет тестов'));
    }
    if (players.isEmpty) {
      return const Center(child: Text('В команде нет игроков'));
    }

    final tablePlayers = _visiblePlayers;
    if (tablePlayers.isEmpty) {
      return const Center(child: Text('По выбранному поиску или амплуа игроков не найдено'));
    }

    return Container(
      color: Colors.white,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: DataTable(
              headingRowHeight: 48,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 64,
              columnSpacing: 14,
              border: TableBorder(horizontalInside: BorderSide(color: _C.line.withOpacity(.75))),
              columns: [
                const DataColumn(label: SizedBox(width: 210, child: Text('Игрок'))),
                ...tests.map((t) => DataColumn(label: SizedBox(width: 126, child: Text('${_asStr(t['short_title'])}\n${_unitForTest(t)}', maxLines: 2)))),
                const DataColumn(label: SizedBox(width: 150, child: Text('Итоговая оценка'))),
              ],
              rows: tablePlayers.map((p) => _row(p)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(Map<String, dynamic> p) {
    final playerId = _playerId(p);
    final finalRating = _finalFor(p);
    return DataRow(cells: [
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
                    style: _C.body.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(_playerPosition(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption.copyWith(fontSize: 10.5)),
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
      DataCell(_ratingPill(finalRating)),
    ]);
  }

  Widget _valueCell(TextEditingController c, _Rating rating, String testCode) {
    return StatefulBuilder(builder: (context, localSetState) {
      final r = _ratingFor(testCode, c.text);
      return Container(
        width: 126,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: r.color.withOpacity(r.label.isEmpty ? 0 : .14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) { localSetState(() {}); setState(() {}); },
          textAlign: TextAlign.center,
          style: _C.body.copyWith(fontWeight: FontWeight.w900),
          decoration: InputDecoration(
            isDense: true,
            hintText: '—',
            border: InputBorder.none,
            helperText: r.label.isEmpty ? null : r.label,
            helperStyle: TextStyle(fontSize: 10, color: _darken(r.color), fontWeight: FontWeight.w800),
          ),
        ),
      );
    });
  }

  Widget _ratingPill(_Rating r) {
    if (r.label.isEmpty) return const Text('—', style: _C.caption);
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: r.color.withOpacity(.16), borderRadius: BorderRadius.circular(999)),
      child: Text(r.label, textAlign: TextAlign.center, style: TextStyle(color: _darken(r.color), fontWeight: FontWeight.w900, fontSize: 12)),
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
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12),
        decoration: BoxDecoration(
          color: _C.input,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.file_download_outlined, size: 18, color: _C.text),
            if (!mobile) ...[
              const SizedBox(width: 7),
              Text('Экспорт', style: _C.body.copyWith(fontWeight: FontWeight.w900)),
            ],
          ],
        ),
      ),
    );
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: _C.page,
          body: SafeArea(
            child: CmrTestingPanel(
              clubId: widget.clubId,
              teamId: widget.teamId,
              clubName: widget.clubName,
              teamName: widget.teamName,
              initialStage: stage,
              userId: widget.userId,
              initialDate: _dateIso(_selectedDate),
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
    buffer.writeln('body{font-family:Arial, sans-serif;} table{border-collapse:collapse;width:100%;} th,td{border:1px solid #cbd5e1;padding:8px;font-size:12px;} th{background:#eaf8f0;} .title{font-size:18px;font-weight:700;margin-bottom:12px;}');
    buffer.writeln('</style></head><body>');
    buffer.writeln('<div class="title">${_escapeHtml(_exportTitle())}</div>');
    buffer.writeln('<table>');
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
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEAF8F0)),
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: .5),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                decoration: const BoxDecoration(
                  color: _C.greenSoft,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.sports_soccer_rounded, color: _C.greenDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title.isEmpty ? 'Описание теста' : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _C.h1.copyWith(fontSize: 18)),
                          const SizedBox(height: 3),
                          Text('${_categoryTitle(category)} • $stage • ${_asStr(t['unit'])}', style: _C.caption.copyWith(color: _C.greenDark)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), tooltip: 'Закрыть'),
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
                          Text('Графическая схема', style: _C.h2.copyWith(fontSize: 15)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBFDFB),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _C.line),
                              ),
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
                          Text(_schemeLegend(code), style: _C.caption.copyWith(height: 1.25)),
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
      decoration: BoxDecoration(color: _C.tile, borderRadius: BorderRadius.circular(18), border: Border.all(color: _C.line.withOpacity(.75))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: _C.greenSoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _C.greenDark, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _C.h2),
                const SizedBox(height: 5),
                Text(text, style: _C.caption.copyWith(height: 1.35)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _C.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Нормативы для $stage', style: _C.h2),
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
                  SizedBox(width: 154, child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(_asStr(n['label']), maxLines: 1, softWrap: false, style: _C.caption.copyWith(fontWeight: FontWeight.w900, color: _darken(color))))),
                  Expanded(child: Text(range, textAlign: TextAlign.right, style: _C.caption)),
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
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 42),
        const SizedBox(height: 10),
        Text(error ?? 'Ошибка', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _load, child: const Text('Повторить')),
      ]),
    ),
  );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((e) => e.substring(0, 1).toUpperCase()).join();
  }

  Color _darken(Color c) => Color.fromARGB(c.alpha, (c.red * .65).round(), (c.green * .65).round(), (c.blue * .65).round());

  static const _defaultStages = [
    {'code':'U6','title':'U6'}, {'code':'U7','title':'U7'}, {'code':'U8','title':'U8'}, {'code':'U9','title':'U9'},
    {'code':'U10','title':'U10'}, {'code':'U11','title':'U11'}, {'code':'U12','title':'U12'}, {'code':'U13','title':'U13'},
    {'code':'U14','title':'U14'}, {'code':'U15','title':'U15'}, {'code':'U16','title':'U16'}, {'code':'U17','title':'U17'},
  ];
}


class _TestSchemePainter extends CustomPainter {
  final String code;
  final String title;

  const _TestSchemePainter({required this.code, required this.title});

  @override
  void paint(Canvas canvas, Size size) {
    final field = RRect.fromRectAndRadius(Offset(18, 18) & Size(size.width - 36, size.height - 36), const Radius.circular(18));
    final bg = Paint()..color = const Color(0xFFEAF8F0);
    final line = Paint()
      ..color = const Color(0xFF087A43)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dash = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.5
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
    final p = Paint()..color = const Color(0xFF087A43)..strokeWidth = 4..strokeCap = StrokeCap.round;
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
    final paint = Paint()..color = const Color(0xFF087A43)..strokeWidth = 2..style = PaintingStyle.stroke;
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
    final paint = Paint()..color = const Color(0xFF087A43)..strokeWidth = 4;
    canvas.drawLine(Offset(x, y - 70), Offset(x, y + 35), paint);
    _cone(canvas, Offset(x, y - 70)); _cone(canvas, Offset(x, y + 35));
    _arrow(canvas, Offset(x + 16, y), Offset(size.width * .78, y));
    _label(canvas, '1 м линия старта', Offset(x - 50, y + 52));
    _label(canvas, 'измерение прыжка', Offset(size.width * .46, y - 36));
  }

  void _drawShot(Canvas canvas, Size size) {
    final goal = Rect.fromLTWH(size.width * .65, size.height * .34, size.width * .18, size.height * .32);
    canvas.drawRect(goal, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawRect(goal, Paint()..color = const Color(0xFF087A43)..strokeWidth = 2..style = PaintingStyle.stroke);
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
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF087A43)..strokeWidth = 2..style = PaintingStyle.stroke);
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
    final p = Paint()..color = const Color(0xFF087A43)..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, p);
    final dir = (b - a);
    final len = dir.distance == 0 ? 1 : dir.distance;
    final ux = dir.dx / len, uy = dir.dy / len;
    final left = Offset(b.dx - ux * 12 - uy * 6, b.dy - uy * 12 + ux * 6);
    final right = Offset(b.dx - ux * 12 + uy * 6, b.dy - uy * 12 - ux * 6);
    canvas.drawLine(b, left, p); canvas.drawLine(b, right, p);
  }

  void _flag(Canvas canvas, Offset o, String text) {
    canvas.drawCircle(o, 7, Paint()..color = const Color(0xFF087A43));
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
    canvas.drawRect(Rect.fromCenter(center: o, width: 10, height: 70), Paint()..color = const Color(0xFF087A43)..strokeWidth = 2..style = PaintingStyle.stroke);
  }

  void _label(Canvas canvas, String text, Offset o, {Color color = const Color(0xFF15221B), double size = 11, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 150);
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(covariant _TestSchemePainter oldDelegate) => oldDelegate.code != code || oldDelegate.title != title;
}

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
      if (v <= m[1]!) return const _Rating('excellent', Color(0xFF22C55E), 'Отлично', points: 4);
      if (v <= m[2]!) return const _Rating('good', Color(0xFFFACC15), 'Хорошо', points: 3);
      if (v <= m[3]!) return const _Rating('satisfactory', Color(0xFFFB923C), 'Удовлетворительно', points: 2);
      return const _Rating('poor', Color(0xFFEF4444), 'Неудовлетворительно', points: 1);
    }
    if (v >= m[0]!) return const _Rating('excellent', Color(0xFF22C55E), 'Отлично', points: 4);
    if (v >= m[1]!) return const _Rating('good', Color(0xFFFACC15), 'Хорошо', points: 3);
    if (v >= m[2]!) return const _Rating('satisfactory', Color(0xFFFB923C), 'Удовлетворительно', points: 2);
    return const _Rating('poor', Color(0xFFEF4444), 'Неудовлетворительно', points: 1);
  }
}

class _C {
  static const page = Color(0xFFF7FAF8);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF087A43);
  static const greenSoft = Color(0xFFEAF8F0);
  static const line = Color(0xFFE6ECE8);
  static const input = Color(0xFFF3F7F5);
  static const tile = Color(0xFFF6F9F7);
  static const text = Color(0xFF15221B);
  static const muted = Color(0xFF647067);
  static const h1 = TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w900);
  static const h2 = TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w900);
  static const body = TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600);
  static const caption = TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600);
}
