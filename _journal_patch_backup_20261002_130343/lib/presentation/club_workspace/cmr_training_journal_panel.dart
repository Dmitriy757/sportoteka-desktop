import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_sync_signal.dart';

class CmrTrainingJournalPanel extends StatefulWidget {
  const CmrTrainingJournalPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teamId,
    required this.teamName,
    required this.currentUserId,
  });

  final int clubId;
  final String clubName;
  final int teamId;
  final String teamName;
  final int currentUserId;

  @override
  State<CmrTrainingJournalPanel> createState() =>
      _CmrTrainingJournalPanelState();
}

class _CmrTrainingJournalPanelState extends State<CmrTrainingJournalPanel> {
  static const String _apiBase = 'https://sportotekaapp.ru/api/journal';
  static const Color _green = Color(0xFF00A750);
  static const Color _greenDark = Color(0xFF067A46);
  static const Color _greenSoft = Color(0xFFF3FAF6);
  static const Color _ink = Color(0xFF0B0F14);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _line = Color(0xFFE9ECEA);
  static const Color _soft = Color(0xFFFAFBFA);
  static const Color _canvas = Color(0xFFF6F7F6);

  Timer? _syncTimer;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _data = <String, dynamic>{};
  final Map<int, Map<String, dynamic>> _playerMetrics =
      <int, Map<String, dynamic>>{};
  int _tab = 0;
  late String _academicYear;
  late DateTime _attendanceMonth;

  static const List<_JournalTabDef> _tabs = <_JournalTabDef>[
    _JournalTabDef('Обложка', Icons.menu_book_rounded),
    _JournalTabDef('I. Учебный план', Icons.view_timeline_rounded),
    _JournalTabDef('II. Расписание', Icons.calendar_view_week_rounded),
    _JournalTabDef('III. Процесс', Icons.fact_check_rounded),
    _JournalTabDef('IV. Спортсмены', Icons.groups_2_rounded),
    _JournalTabDef('V. Самоконтроль', Icons.verified_user_rounded),
    _JournalTabDef('Документ', Icons.description_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _academicYear = _defaultAcademicYear();
    _attendanceMonth = _defaultAttendanceMonth(_academicYear);
    WorkspaceSyncSignal.calendarRevision
        .addListener(_onExternalCalendarChanged);
    _load();
    _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_saving) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WorkspaceSyncSignal.calendarRevision
        .removeListener(_onExternalCalendarChanged);
    super.dispose();
  }

  void _onExternalCalendarChanged() {
    final changedTeamId = WorkspaceSyncSignal.lastCalendarTeamId;
    if (changedTeamId > 0 && changedTeamId != widget.teamId) return;
    if (!mounted || _saving) return;
    _load(silent: true);
  }

  @override
  void didUpdateWidget(covariant CmrTrainingJournalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId ||
        oldWidget.clubId != widget.clubId) {
      _data = <String, dynamic>{};
      _playerMetrics.clear();
      _error = null;
      _load();
    }
  }

  String _defaultAcademicYear() {
    final now = DateTime.now();
    final start = now.month >= 9 ? now.year : now.year - 1;
    return '$start/${start + 1}';
  }

  DateTime _defaultAttendanceMonth(String academicYear) {
    final years = academicYear.split('/');
    final start = int.tryParse(years.first) ?? DateTime.now().year;
    final now = DateTime.now();
    final from = DateTime(start, 9, 1);
    final to = DateTime(start + 1, 8, 31);
    if (!now.isBefore(from) && !now.isAfter(to)) {
      return DateTime(now.year, now.month, 1);
    }
    return from;
  }

  Map<String, dynamic> _map(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  List<Map<String, dynamic>> _list(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  String _text(dynamic value) {
    final s = '${value ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_text(value)) ?? 0;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_text(value).replaceAll(',', '.')) ?? 0;
  }

  Map<String, dynamic> _extractMetricsPayload(Map<String, dynamic> response) {
    dynamic source =
        response['metrics'] ?? response['player'] ?? response['data'];
    if (source is Map) {
      final mapped = Map<String, dynamic>.from(source);
      final nested = mapped['metrics'] ?? mapped['player'];
      if (nested is Map) return Map<String, dynamic>.from(nested);
      return mapped;
    }
    return response;
  }

  Future<void> _hydratePlayerMetrics(List<Map<String, dynamic>> players) async {
    final pending = players.where((player) {
      final playerId = _int(player['id'] ?? player['player_id']);
      return playerId > 0 && !_playerMetrics.containsKey(playerId);
    }).toList(growable: false);
    if (pending.isEmpty) return;

    const chunkSize = 6;
    for (var offset = 0; offset < pending.length; offset += chunkSize) {
      final chunk =
          pending.skip(offset).take(chunkSize).toList(growable: false);
      final rows = await Future.wait<MapEntry<int, Map<String, dynamic>>?>(
        chunk.map((player) async {
          final playerId = _int(player['id'] ?? player['player_id']);
          final userId = _int(player['user_id'] ?? player['userId']);
          try {
            final uri = Uri.parse(
                    'https://sportotekaapp.ru/api/medical/get_player_metrics.php')
                .replace(queryParameters: <String, String>{
              'player_id': '$playerId',
              if (userId > 0) 'user_id': '$userId',
            });
            final response =
                await http.get(uri).timeout(const Duration(seconds: 10));
            final raw = response.body.trim();
            if (raw.isEmpty || raw.startsWith('<')) return null;
            final decoded = jsonDecode(raw);
            if (decoded is! Map) return null;
            return MapEntry<int, Map<String, dynamic>>(
              playerId,
              _extractMetricsPayload(Map<String, dynamic>.from(decoded)),
            );
          } catch (_) {
            return null;
          }
        }),
      );
      if (!mounted) return;
      var changed = false;
      for (final row in rows) {
        if (row == null) continue;
        _playerMetrics[row.key] = row.value;
        changed = true;
      }
      if (changed) setState(() {});
    }
  }

  String _metricText(Map<String, dynamic> player, List<String> keys) {
    final playerId = _int(player['id'] ?? player['player_id']);
    final metrics = _playerMetrics[playerId] ?? const <String, dynamic>{};
    for (final key in keys) {
      final value = _text(metrics[key]);
      if (value.isNotEmpty && value != '0' && value != '0.0') return value;
    }
    for (final key in keys) {
      final value = _text(player[key]);
      if (value.isNotEmpty && value != '0' && value != '0.0') return value;
    }
    return '';
  }

  String _ageFromBirth(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final birth = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (birth == null) return '';
    final now = DateTime.now();
    var years = now.year - birth.year;
    final hadBirthday = now.month > birth.month ||
        (now.month == birth.month && now.day >= birth.day);
    if (!hadBirthday) years--;
    return years > 0 && years < 90 ? '$years лет' : '';
  }

  String _playerPhotoUrl(Map<String, dynamic> player) {
    final raw = _text(player['photo_url']).isNotEmpty
        ? _text(player['photo_url'])
        : _text(player['photo']);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    if (raw.startsWith('uploads/')) return 'https://sportotekaapp.ru/$raw';
    return 'https://sportotekaapp.ru/uploads/$raw';
  }

  Map<String, dynamic> get _journal => _map(_data['journal']);
  Map<String, dynamic> get _club => _map(_data['club']);
  Map<String, dynamic> get _clubJournal => _map(_data['club_journal_profile']);
  Map<String, dynamic> get _team => _map(_data['team']);
  List<Map<String, dynamic>> get _allTrainers =>
      _list(_data['all_trainers']).isNotEmpty
          ? _list(_data['all_trainers'])
          : _list(_data['trainers']);
  List<Map<String, dynamic>> get _trainers => _list(_data['trainers']);
  List<Map<String, dynamic>> get _players => _list(_data['players']);
  List<Map<String, dynamic>> get _parents => _list(_data['parents']);
  List<Map<String, dynamic>> get _curriculum => _list(_data['curriculum']);
  List<Map<String, dynamic>> get _schedule => _list(_data['schedule']);
  List<Map<String, dynamic>> get _trainingEvents =>
      _list(_data['training_events'])
          .where((e) =>
              !_map(e).containsKey('journal_training_like') ||
              _int(e['journal_training_like']) == 1)
          .toList(growable: false);
  List<Map<String, dynamic>> get _signatures => _list(_data['signatures']);
  List<Map<String, dynamic>> get _briefings => _list(_data['briefings']);
  List<Map<String, dynamic>> get _quality => _list(_data['quality_controls']);
  Map<String, dynamic> get _attendance => _map(_data['attendance']);
  List<Map<String, dynamic>> get _monthSnapshots =>
      _list(_data['month_snapshots']);

  int get _journalId => _int(_journal['id']);

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final uri = Uri.parse('$_apiBase/index.php').replace(queryParameters: {
        'action': 'bootstrap',
        'club_id': '${widget.clubId}',
        'team_id': '${widget.teamId}',
        'user_id': '${widget.currentUserId}',
        'academic_year': _academicYear,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 18));
      final raw = response.body.trim();
      if (raw.isEmpty || raw.startsWith('<')) {
        throw Exception('Сервер вернул некорректный ответ');
      }
      final decoded = jsonDecode(raw);
      final payload = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      if (payload['success'] != true) {
        throw Exception(_text(payload['message']).isEmpty
            ? 'Не удалось загрузить журнал'
            : _text(payload['message']));
      }
      final data = _map(payload['data']);
      if (!mounted) return;
      setState(() {
        _data = data;
        if (!silent) _loading = false;
      });
      unawaited(_hydratePlayerMetrics(_list(data['players'])));
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<bool> _post(String action, Map<String, dynamic> body) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'action': action,
        'journal_id': _journalId,
        'club_id': widget.clubId,
        'team_id': widget.teamId,
        'user_id': widget.currentUserId,
        'academic_year': _academicYear,
        ...body,
      };
      final response = await http
          .post(
            Uri.parse('$_apiBase/index.php'),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 18));
      final decoded = jsonDecode(response.body);
      final map = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      if (map['success'] != true) {
        throw Exception(_text(map['message']).isEmpty
            ? 'Не удалось сохранить изменения'
            : _text(map['message']));
      }
      if (!mounted) return true;
      setState(() => _data = _map(map['data']));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
        ));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _academicYearOptions() {
    final now = DateTime.now();
    final base = now.month >= 9 ? now.year : now.year - 1;
    return <String>[
      for (var y = base - 2; y <= base + 2; y++) '$y/${y + 1}',
    ];
  }

  List<DateTime> _academicMonths() {
    final start =
        int.tryParse(_academicYear.split('/').first) ?? DateTime.now().year;
    return <DateTime>[
      for (var i = 0; i < 12; i++) DateTime(start, 9 + i, 1),
    ];
  }

  String _monthTitle(DateTime date) {
    const names = <String>[
      'январь',
      'февраль',
      'март',
      'апрель',
      'май',
      'июнь',
      'июль',
      'август',
      'сентябрь',
      'октябрь',
      'ноябрь',
      'декабрь',
    ];
    return '${names[date.month - 1]} ${date.year}';
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _yearMonth(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  bool _monthIsClosed(DateTime date) {
    final ym = _yearMonth(date);
    for (final row in _monthSnapshots) {
      if (_text(row['year_month']) == ym && _text(row['reopened_at']).isEmpty) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic>? _parentForPlayer(int playerId) {
    for (final parent in _parents) {
      final ids = parent['player_ids'];
      if (ids is List && ids.any((e) => _int(e) == playerId)) return parent;
    }
    return null;
  }

  Map<String, dynamic>? _latestBriefing(int playerId) {
    for (final briefing in _briefings) {
      if (_int(briefing['player_id']) == playerId) return briefing;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _JournalCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 38),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final baseTheme = Theme.of(context);
    return Theme(
      data: baseTheme.copyWith(
        scaffoldBackgroundColor: _canvas,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F3F3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          labelStyle: const TextStyle(color: _muted, fontSize: 12),
          floatingLabelStyle:
              const TextStyle(color: _ink, fontWeight: FontWeight.w600),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF222526),
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: BorderSide.none,
            backgroundColor: const Color(0xFFF0F2F2),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
      ),
      child: Container(
        color: _canvas,
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildCurrentTab()),
                  if (_saving)
                    const Positioned(
                      top: 10,
                      right: 18,
                      child: _SavingPill(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final group = _text(_journal['group_type']);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.menu_book_rounded, color: _green),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Журнал учебно-тренировочного процесса',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_teamDisplayName${group.isEmpty ? '' : ' · $group'} · живые данные клуба',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _academicYearOptions().contains(_academicYear)
                  ? _academicYear
                  : _academicYearOptions().first,
              borderRadius: BorderRadius.circular(14),
              items: _academicYearOptions()
                  .map((year) => DropdownMenuItem(
                        value: year,
                        child: Text('$year уч. год'),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null || value == _academicYear) return;
                setState(() {
                  _academicYear = value;
                  _attendanceMonth = _defaultAttendanceMonth(value);
                });
                _load();
              },
            ),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 54,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final active = index == _tab;
          final tab = _tabs[index];
          return InkWell(
            onTap: () {
              setState(() => _tab = index);
              _load(silent: true);
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: active ? _greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: null,
              ),
              child: Row(
                children: [
                  Icon(tab.icon, size: 17, color: active ? _green : _muted),
                  const SizedBox(width: 7),
                  Text(
                    tab.title,
                    style: TextStyle(
                      color: active ? _green : _ink,
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_tab) {
      case 0:
        return _buildCover();
      case 1:
        return _buildCurriculum();
      case 2:
        return _buildSchedule();
      case 3:
        return _buildAttendance();
      case 4:
        return _buildPlayers();
      case 5:
        return _buildQuality();
      default:
        return _buildDocumentPreview();
    }
  }

  Widget _pageScroll(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: children,
    );
  }

  String get _legalName => _text(_clubJournal['legal_name']).isNotEmpty
      ? _text(_clubJournal['legal_name'])
      : (_text(_club['club_name']).isNotEmpty
          ? _text(_club['club_name'])
          : widget.clubName);

  String get _teamDisplayName =>
      _text(_team['name']).isNotEmpty ? _text(_team['name']) : widget.teamName;

  String get _structuralUnit =>
      _text(_clubJournal['structural_unit_name']).isNotEmpty
          ? _text(_clubJournal['structural_unit_name'])
          : _teamDisplayName;

  String get _schoolName => _text(_clubJournal['school_name']).isNotEmpty
      ? _text(_clubJournal['school_name'])
      : 'Детско-юношеская спортивная школа';

  String get _sportName =>
      _text(_team['sport']).isNotEmpty ? _text(_team['sport']) : 'Футбол';

  String get _trainerNames => _trainers
      .map((e) => _text(e['full_name']))
      .where((e) => e.isNotEmpty)
      .join(', ');

  int get _signedTrainerCount => _trainers.where((trainer) {
        final id = _int(trainer['id']);
        return id > 0 && _signatureFor(id) != null;
      }).length;

  Widget _coverActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        _JournalSoftAction(
          icon: Icons.draw_rounded,
          label: _signedTrainerCount > 0
              ? 'Подпись $_signedTrainerCount/${_trainers.length}'
              : 'Подпись тренера',
          accent: true,
          onTap: _openSignatureManager,
        ),
        _JournalSoftAction(
          icon: Icons.tune_rounded,
          label: 'Настроить',
          onTap: _editMeta,
        ),
      ],
    );
  }

  Future<void> _openSignatureManager() async {
    final trainers = _trainers.isEmpty
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'id': widget.currentUserId,
              'full_name': 'Тренер',
            }
          ]
        : _trainers;

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 650),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 34,
                spreadRadius: -18,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _JournalDotCluster(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Подпись тренера',
                          style: AppTypography.custom(
                            size: 17,
                            weight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Выберите тренера и распишитесь мышью, пальцем или стилусом.',
                          style: AppTypography.custom(
                            size: 11.5,
                            weight: FontWeight.w400,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: trainers.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: _line,
                  ),
                  itemBuilder: (_, index) {
                    final trainer = trainers[index];
                    final signature = _signatureFor(_int(trainer['id']));
                    return InkWell(
                      onTap: () => Navigator.pop(dialogContext, trainer),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            _JournalStatusDot(
                              active: signature != null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _text(trainer['full_name']).isEmpty
                                        ? 'Тренер'
                                        : _text(trainer['full_name']),
                                    style: AppTypography.custom(
                                      size: 12.5,
                                      weight: FontWeight.w600,
                                      color: _ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    signature == null
                                        ? 'Подпись не добавлена'
                                        : 'Подписано ${_text(signature['signed_at'])}',
                                    style: AppTypography.custom(
                                      size: 10.5,
                                      weight: FontWeight.w400,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (signature != null)
                              _SignaturePreview(
                                json: _text(signature['signature_json']),
                                width: 105,
                                height: 36,
                              ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _muted,
                              size: 18,
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
    if (selected == null || !mounted) return;
    await _captureTrainerSignature(selected);
  }

  Widget _buildCover() {
    return _pageScroll([
      _SectionHeading(
        title: 'Титульный лист',
        subtitle:
            'Клуб, команда, тренеры и вид спорта подставляются автоматически. Специальные поля журнала можно настроить здесь.',
        action: _coverActions(),
      ),
      const SizedBox(height: 14),
      Center(
        child: _PaperPage(
          portrait: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 18),
              const Text('ЖУРНАЛ',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 8),
              Text(
                'Учёта учебно-тренировочного процесса за $_academicYear учебный год',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 34),
              const Text('Обособленного структурного подразделения',
                  style: TextStyle(fontFamily: 'serif', fontSize: 15)),
              const SizedBox(height: 8),
              Text('«$_structuralUnit»',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 8),
              Text(_schoolName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'serif', fontSize: 15)),
              Text(_legalName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'serif', fontSize: 15)),
              const SizedBox(height: 34),
              _CoverLine('отделения (вид спорта)', _sportName),
              _CoverLine(
                  'группы (ВСМ, СПС, УТ, НП)', _text(_journal['group_type'])),
              _CoverLine('года обучения', _text(_journal['study_year'])),
              _CoverLine('Тренер(ы)', _trainerNames),
              _CoverLine('Тренер по смежной подготовке',
                  _text(_journal['adjacent_trainer_name'])),
              const Spacer(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Условные обозначения: • — присутствие; н — отсутствие; б — болезнь; с — соревнования; у — учебно-тренировочный сбор; сол — спортивно-оздоровительный лагерь.',
                  style: TextStyle(
                      fontFamily: 'serif', fontSize: 11, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _JournalCard(
        child: Wrap(
          spacing: 26,
          runSpacing: 12,
          children: [
            _InfoPair('Источник клуба', _legalName),
            _InfoPair('Команда', _teamDisplayName),
            _InfoPair('Вид спорта', _sportName),
            _InfoPair('Тренеры',
                _trainerNames.isEmpty ? 'Не назначены' : _trainerNames),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _buildTrainerSignatures(),
    ]);
  }

  Map<String, dynamic>? _signatureFor(int signerId) {
    for (final row in _signatures) {
      if (_int(row['signer_user_id']) == signerId &&
          _text(row['signer_role']) == 'trainer') {
        return row;
      }
    }
    return null;
  }

  Widget _buildTrainerSignatures() {
    final trainers = _trainers.isEmpty
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'id': widget.currentUserId,
              'full_name': 'Тренер',
            }
          ]
        : _trainers;
    return _JournalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Подпись тренера',
            style: TextStyle(
                color: _ink, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Подпишите стилусом, мышью или пальцем. Подпись попадёт в печатный журнал и PDF.',
            style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          ...trainers.map((trainer) {
            final signerId = _int(trainer['id']);
            final signature = _signatureFor(signerId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(trainer['full_name']).isEmpty
                                ? 'Тренер'
                                : _text(trainer['full_name']),
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            signature == null
                                ? 'Подпись не добавлена'
                                : 'Подписано ${_text(signature['signed_at'])}',
                            style:
                                const TextStyle(color: _muted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    if (signature != null)
                      _SignaturePreview(
                        json: _text(signature['signature_json']),
                        width: 130,
                        height: 44,
                      ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => _captureTrainerSignature(trainer),
                      icon: const Icon(Icons.draw_rounded, size: 17),
                      label: Text(
                          signature == null ? 'Подписать' : 'Переподписать'),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _captureTrainerSignature(Map<String, dynamic> trainer) async {
    final signerId =
        _int(trainer['id']) > 0 ? _int(trainer['id']) : widget.currentUserId;
    final signerName = _text(trainer['full_name']).isEmpty
        ? 'Тренер'
        : _text(trainer['full_name']);
    final signatureJson = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SignatureCaptureDialog(signerName: signerName),
    );
    if (signatureJson == null || signatureJson.isEmpty) return;
    await _post('save_signature', {
      'signer_user_id': signerId,
      'signer_role': 'trainer',
      'signer_name': signerName,
      'signature_json': signatureJson,
    });
  }

  Future<void> _editMeta() async {
    final teamName = TextEditingController(text: _teamDisplayName);
    final sport = TextEditingController(text: _sportName);
    final legal = TextEditingController(text: _legalName);
    final unit = TextEditingController(text: _structuralUnit);
    final school = TextEditingController(text: _schoolName);
    final study = TextEditingController(text: _text(_journal['study_year']));
    final adjacent =
        TextEditingController(text: _text(_journal['adjacent_trainer_name']));
    var group = _text(_journal['group_type']);

    final allTrainers = _allTrainers;
    final selectedTrainerIds = _trainers
        .map((trainer) => _int(trainer['id']))
        .where((id) => id > 0)
        .toSet();
    if (selectedTrainerIds.isEmpty) {
      selectedTrainerIds.addAll(
        allTrainers.map((trainer) => _int(trainer['id'])).where((id) => id > 0),
      );
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 34,
                  spreadRadius: -18,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const _JournalDotCluster(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Титульный лист',
                            style: AppTypography.custom(
                              size: 18,
                              weight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Все изменения сразу сохраняются в общих данных клуба и команды.',
                            style: AppTypography.custom(
                              size: 11.5,
                              weight: FontWeight.w400,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _JournalEditorSectionTitle(
                          'Команда и организация',
                        ),
                        _JournalField(
                          controller: teamName,
                          label: 'Команда',
                          hint: 'Название команды',
                        ),
                        _JournalField(
                          controller: sport,
                          label: 'Вид спорта',
                          hint: 'Футбол',
                        ),
                        _JournalField(
                          controller: legal,
                          label: 'Полное наименование клуба / организации',
                        ),
                        _JournalField(
                          controller: unit,
                          label: 'Структурное подразделение',
                        ),
                        _JournalField(
                          controller: school,
                          label: 'Спортивная школа / подразделение',
                        ),
                        const SizedBox(height: 18),
                        const _JournalEditorSectionTitle(
                          'Группа и год обучения',
                        ),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: <String>['НП', 'УТ', 'СПС', 'ВСМ']
                              .map(
                                (value) => _JournalChoiceChip(
                                  label: value,
                                  active: group == value,
                                  onTap: () => setLocal(() => group = value),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        _JournalField(
                          controller: study,
                          label: 'Год обучения',
                          hint: 'Например: 2',
                        ),
                        const SizedBox(height: 18),
                        const _JournalEditorSectionTitle(
                          'Тренеры журнала',
                        ),
                        Text(
                          'Выберите тренеров, которые должны быть указаны на обложке и подписывать журнал.',
                          style: AppTypography.custom(
                            size: 11,
                            weight: FontWeight.w400,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (allTrainers.isEmpty)
                          const _JournalInlineNotice(
                            text:
                                'У команды пока нет назначенных тренеров. Сначала назначьте тренера в карточке команды.',
                          )
                        else
                          ...allTrainers.map((trainer) {
                            final id = _int(trainer['id']);
                            final active = selectedTrainerIds.contains(id);
                            return _JournalTrainerChoice(
                              name: _text(trainer['full_name']).isEmpty
                                  ? 'Тренер #$id'
                                  : _text(trainer['full_name']),
                              subtitle: _text(trainer['profile']).isEmpty
                                  ? 'тренер команды'
                                  : _text(trainer['profile']),
                              active: active,
                              onTap: () {
                                setLocal(() {
                                  if (active) {
                                    if (selectedTrainerIds.length > 1) {
                                      selectedTrainerIds.remove(id);
                                    }
                                  } else {
                                    selectedTrainerIds.add(id);
                                  }
                                });
                              },
                            );
                          }),
                        const SizedBox(height: 10),
                        _JournalField(
                          controller: adjacent,
                          label: 'Тренер по смежной подготовке',
                          hint: 'Необязательно',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;

    await _post('save_meta', {
      'team_name': teamName.text.trim(),
      'sport': sport.text.trim(),
      'legal_name': legal.text.trim(),
      'structural_unit_name': unit.text.trim(),
      'school_name': school.text.trim(),
      'group_type': group,
      'study_year': study.text.trim(),
      'adjacent_trainer_name': adjacent.text.trim(),
      'trainer_ids': selectedTrainerIds.toList(growable: false),
    });
  }

  Widget _buildCurriculum() {
    final months = _academicMonths();
    return _pageScroll([
      _SectionHeading(
        title: 'Раздел I. Учебный план',
        subtitle:
            'Теория, ОФП, СФП и соревнования с количеством академических часов по месяцам.',
        action: FilledButton.icon(
          onPressed: () => _editCurriculumItem(null),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Добавить строку'),
        ),
      ),
      const SizedBox(height: 14),
      _JournalCard(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            headingRowHeight: 48,
            columns: [
              const DataColumn(
                  label:
                      SizedBox(width: 220, child: Text('Содержание занятий'))),
              ...months
                  .map((m) => DataColumn(label: Text(_monthShort(m.month)))),
              const DataColumn(label: Text('Всего')),
              const DataColumn(label: Text('')),
            ],
            rows: _curriculum.map((item) {
              final hours = _map(item['hours']);
              var total = 0.0;
              final cells = <DataCell>[];
              for (final month in months) {
                final value =
                    _double(hours['${month.month}'] ?? hours[month.month]);
                total += value;
                cells.add(DataCell(Text(_number(value))));
              }
              return DataRow(cells: [
                DataCell(SizedBox(
                  width: 220,
                  child: Text(_text(item['title']),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                )),
                ...cells,
                DataCell(Text(_number(total),
                    style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(IconButton(
                  tooltip: 'Редактировать',
                  onPressed: () => _editCurriculumItem(item),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    ]);
  }

  String _monthShort(int month) {
    const names = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек'
    ];
    return names[month - 1];
  }

  String _number(double value) {
    if (value == 0) return '';
    if ((value - value.roundToDouble()).abs() < .001) return '${value.round()}';
    return value.toStringAsFixed(1);
  }

  Future<void> _editCurriculumItem(Map<String, dynamic>? item) async {
    final title = TextEditingController(text: _text(item?['title']));
    var category = _text(item?['category']);
    if (!const ['theory', 'gpp', 'spp', 'competition'].contains(category)) {
      category = 'theory';
    }
    final sourceHours = _map(item?['hours']);
    final controllers = <int, TextEditingController>{
      for (var m = 1; m <= 12; m++)
        m: TextEditingController(
          text: _number(_double(sourceHours['$m'] ?? sourceHours[m])),
        ),
    };

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => _JournalDialogFrame(
          title: item == null ? 'Новая строка учебного плана' : 'Учебный план',
          subtitle:
              'Часы и содержание используются в официальном Разделе I журнала.',
          maxWidth: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _JournalField(
                  controller: title,
                  label: 'Содержание занятий',
                  hint: 'Например: тактическая подготовка',
                ),
                const _JournalEditorSectionTitle('Раздел подготовки'),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: const <String, String>{
                    'theory': 'Теория',
                    'gpp': 'ОФП',
                    'spp': 'СФП',
                    'competition': 'Соревнования',
                  }
                      .entries
                      .map((entry) => _JournalChoiceChip(
                            label: entry.value,
                            active: category == entry.key,
                            onTap: () => setLocal(() => category = entry.key),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 18),
                const _JournalEditorSectionTitle(
                    'Академические часы по месяцам'),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 620
                        ? (constraints.maxWidth - 30) / 4
                        : (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 0,
                      children: _academicMonths()
                          .map((month) => SizedBox(
                                width: width,
                                child: _JournalField(
                                  controller: controllers[month.month]!,
                                  label: _monthTitle(month),
                                  hint: '0',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (item != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext, false);
                  if (await _confirm('Удалить строку учебного плана?')) {
                    await _post('delete_curriculum_item',
                        {'item_id': _int(item['id'])});
                  }
                },
                child: const Text('Удалить',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _post('save_curriculum_item', {
      if (item != null) 'item_id': _int(item['id']),
      'category': category,
      'title': title.text.trim(),
      'sort_order': _int(item?['sort_order']) == 0
          ? (_curriculum.length + 1) * 10
          : _int(item?['sort_order']),
      'hours': {
        for (var m = 1; m <= 12; m++) '$m': _double(controllers[m]!.text),
      },
    });
  }

  Widget _buildSchedule() {
    final months = _academicMonths();
    return _pageScroll([
      _SectionHeading(
        title: 'Раздел II. Расписание учебно-тренировочных занятий',
        subtitle:
            'Расписание формируется из уже существующих тренировок календаря. Нажмите на ячейку месяца и дня недели — откроются реальные тренировки для редактирования.',
        action: _JournalSoftAction(
          icon: Icons.add_rounded,
          label: 'Добавить тренировку',
          accent: true,
          onTap: () => _editTrainingEvent(null),
        ),
      ),
      const SizedBox(height: 14),
      _JournalInlineNotice(
        text:
            'Связь двусторонняя: изменение тренировки здесь меняет team_events и календарь команды; изменения в календаре автоматически появляются в журнале.',
        icon: Icons.sync_rounded,
      ),
      const SizedBox(height: 12),
      if (_trainingEvents.isEmpty)
        _EmptyBlock(
          icon: Icons.calendar_today_outlined,
          title: 'Тренировок за $_academicYear пока нет',
          subtitle:
              'Если тренировки уже есть в календаре, нажмите «Обновить». V1.3 читает старые события независимо от legacy-значения type.',
        )
      else
        _JournalCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1180,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: const BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 118,
                          child: Text(
                            'Месяц',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _muted,
                            ),
                          ),
                        ),
                        ...List<Widget>.generate(
                          7,
                          (index) => Expanded(
                            child: Text(
                              _weekdayName(index + 1),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                                color: _muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...months.map((month) {
                    return Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: _line, width: .65),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 118,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 15,
                              ),
                              child: Text(
                                _monthTitle(month),
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          ...List<Widget>.generate(7, (index) {
                            final weekday = index + 1;
                            final events =
                                _eventsForMonthWeekday(month, weekday);
                            return Expanded(
                              child: _ScheduleCell(
                                text: _scheduleCellText(events),
                                count: events.length,
                                onTap: () => _openScheduleCell(
                                  month,
                                  weekday,
                                  events,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 12),
      _JournalCard(
        child: Row(
          children: [
            const _JournalDotCluster(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_trainingEvents.length} занятий календаря вошли в расписание $_academicYear.',
                style: AppTypography.custom(
                  size: 11.5,
                  weight: FontWeight.w500,
                  color: _ink,
                ),
              ),
            ),
            TextButton(
              onPressed: _load,
              child: const Text('Обновить'),
            ),
          ],
        ),
      ),
    ]);
  }

  List<Map<String, dynamic>> _eventsForMonthWeekday(
    DateTime month,
    int weekday,
  ) {
    final rows = _trainingEvents.where((event) {
      final dt = _parseServerDateTime(_text(event['start_at']));
      return dt != null &&
          dt.year == month.year &&
          dt.month == month.month &&
          dt.weekday == weekday;
    }).toList(growable: false);
    rows.sort((a, b) => _text(a['start_at']).compareTo(_text(b['start_at'])));
    return rows;
  }

  String _scheduleCellText(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return '';
    final slots = <String>[];
    for (final event in events) {
      final time = _eventTimeRange(event);
      final location = _text(event['location']);
      final slot = [time, location]
          .where((value) => value.trim().isNotEmpty)
          .join(' · ');
      if (slot.isNotEmpty && !slots.contains(slot)) slots.add(slot);
    }
    if (slots.length <= 2) return slots.join('\n');
    return '${slots.take(2).join('\n')}\n+${slots.length - 2}';
  }

  DateTime _firstWeekdayInMonth(DateTime month, int weekday) {
    var value = DateTime(month.year, month.month, 1, 17);
    while (value.weekday != weekday) {
      value = value.add(const Duration(days: 1));
    }
    return value;
  }

  Future<void> _openScheduleCell(
    DateTime month,
    int weekday,
    List<Map<String, dynamic>> events,
  ) async {
    final action = await showDialog<Object?>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650, maxHeight: 700),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 34,
                spreadRadius: -18,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const _JournalDotCluster(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_monthTitle(month)} · ${_weekdayName(weekday)}',
                          style: AppTypography.custom(
                            size: 17,
                            weight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Редактируются реальные тренировки календаря.',
                          style: AppTypography.custom(
                            size: 11,
                            weight: FontWeight.w400,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: events.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'В этом месяце занятий на этот день недели нет.',
                          style: TextStyle(color: _muted, fontSize: 12.5),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: _line,
                        ),
                        itemBuilder: (_, index) {
                          final event = events[index];
                          return InkWell(
                            onTap: () => Navigator.pop(dialogContext, event),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  const _JournalStatusDot(active: true),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _text(event['title']).isEmpty
                                              ? 'Тренировка'
                                              : _text(event['title']),
                                          style: const TextStyle(
                                            color: _ink,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          [
                                            _eventDateText(event),
                                            _eventTimeRange(event),
                                            _text(event['location']),
                                          ]
                                              .where((value) =>
                                                  value.trim().isNotEmpty)
                                              .join(' · '),
                                          style: const TextStyle(
                                            color: _muted,
                                            fontSize: 10.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.edit_outlined,
                                    size: 17,
                                    color: _muted,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    _firstWeekdayInMonth(month, weekday),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Добавить тренировку'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action is DateTime) {
      await _editTrainingEvent(null, initialDate: action);
      return;
    }
    if (action is Map) {
      await _editTrainingEvent(Map<String, dynamic>.from(action));
    }
  }

  DateTime? _parseServerDateTime(String raw) {
    if (raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
  }

  String _eventDateText(Map<String, dynamic> event) {
    final dt = _parseServerDateTime(_text(event['start_at']));
    if (dt == null) return _text(event['start_at']);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} · ${_weekdayName(dt.weekday)}';
  }

  String _eventTimeRange(Map<String, dynamic> event) {
    final start = _parseServerDateTime(_text(event['start_at']));
    final end = _parseServerDateTime(_text(event['end_at']));
    String hhmm(DateTime? value) => value == null
        ? ''
        : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    final a = hhmm(start);
    final b = hhmm(end);
    return b.isEmpty ? a : '$a–$b';
  }

  String _weekdayName(int value) =>
      const <int, String>{
        1: 'Понедельник',
        2: 'Вторник',
        3: 'Среда',
        4: 'Четверг',
        5: 'Пятница',
        6: 'Суббота',
        7: 'Воскресенье',
      }[value] ??
      '';

  Future<void> _editTrainingEvent(
    Map<String, dynamic>? row, {
    DateTime? initialDate,
  }) async {
    final existingStart = _parseServerDateTime(_text(row?['start_at']));
    final existingEnd = _parseServerDateTime(_text(row?['end_at']));
    final now = DateTime.now();
    final initial = existingStart ??
        initialDate ??
        DateTime(now.year, now.month, now.day, 17);
    final date = TextEditingController(text: _dateKey(initial));
    final start = TextEditingController(
      text:
          '${initial.hour.toString().padLeft(2, '0')}:${initial.minute.toString().padLeft(2, '0')}',
    );
    final end = TextEditingController(
      text: existingEnd == null
          ? ''
          : '${existingEnd.hour.toString().padLeft(2, '0')}:${existingEnd.minute.toString().padLeft(2, '0')}',
    );
    final title = TextEditingController(
      text: _text(row?['title']).isEmpty ? 'Тренировка' : _text(row?['title']),
    );
    final location = TextEditingController(text: _text(row?['location']));
    final notes = TextEditingController(text: _text(row?['notes']));
    var type = _text(row?['type']);
    if (!const ['training', 'theory', 'gym'].contains(type)) type = 'training';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
              row == null ? 'Новая тренировка' : 'Редактировать тренировку'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _JournalField(
                    controller: title,
                    label: 'Название',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _JournalField(
                          controller: date,
                          label: 'Дата',
                          hint: 'YYYY-MM-DD',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _JournalField(
                          controller: start,
                          label: 'Начало',
                          hint: 'HH:MM',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _JournalField(
                          controller: end,
                          label: 'Окончание',
                          hint: 'HH:MM',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SoftChoice<String>(
                    value: type,
                    label: 'Тип занятия',
                    values: const {
                      'training': 'Тренировка',
                      'theory': 'Теория',
                      'gym': 'ОФП / зал',
                    },
                    onChanged: (value) => setLocal(() => type = value),
                  ),
                  const SizedBox(height: 10),
                  _JournalField(
                    controller: location,
                    label: 'Место проведения',
                  ),
                  const SizedBox(height: 10),
                  _JournalField(
                    controller: notes,
                    label: 'Примечание',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (row != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext, false);
                  if (await _confirm(
                      'Удалить тренировку? Она исчезнет и из календаря команды.')) {
                    final ok = await _post(
                        'delete_training_event', {'id': _int(row['id'])});
                    if (ok)
                      WorkspaceSyncSignal.calendarChanged(
                          teamId: widget.teamId);
                  }
                },
                child: const Text('Удалить',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final startAt = '${date.text.trim()} ${start.text.trim()}';
    final endAt =
        end.text.trim().isEmpty ? '' : '${date.text.trim()} ${end.text.trim()}';
    final ok = await _post('save_training_event', {
      if (row != null) 'id': _int(row['id']),
      'type': type,
      'title': title.text.trim(),
      'start_at': startAt,
      'end_at': endAt,
      'location': location.text.trim(),
      'notes': notes.text.trim(),
    });
    if (ok) WorkspaceSyncSignal.calendarChanged(teamId: widget.teamId);
  }

  Widget _buildAttendance() {
    final days =
        DateUtils.getDaysInMonth(_attendanceMonth.year, _attendanceMonth.month);
    final closed = _monthIsClosed(_attendanceMonth);
    return _pageScroll([
      _SectionHeading(
        title: 'Раздел III. Учебно-тренировочный процесс',
        subtitle:
            'Данные поднимаются из уже проведённых тренировок и существующей посещаемости команды. Изменение отметки здесь синхронизируется обратно с посещаемостью тренировки.',
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton<DateTime>(
                value: _academicMonths().firstWhere(
                  (m) =>
                      m.year == _attendanceMonth.year &&
                      m.month == _attendanceMonth.month,
                  orElse: () => _academicMonths().first,
                ),
                items: _academicMonths()
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text(_monthTitle(m))))
                    .toList(),
                onChanged: (m) {
                  if (m != null) setState(() => _attendanceMonth = m);
                },
              ),
            ),
            const SizedBox(width: 10),
            if (closed)
              OutlinedButton.icon(
                onPressed: () => _reopenMonth(_attendanceMonth),
                icon: const Icon(Icons.lock_open_rounded, size: 17),
                label: const Text('Открыть месяц'),
              )
            else
              FilledButton.icon(
                onPressed: () => _closeMonth(_attendanceMonth),
                icon: const Icon(Icons.lock_rounded, size: 17),
                label: const Text('Закрыть месяц'),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _AttendanceLegend(),
      const SizedBox(height: 12),
      _JournalCard(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _attendanceHeader(days),
              ..._players.map((p) => _attendanceRow(p, days, closed)),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _attendanceHeader(int days) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: [
          _gridCell('Фамилия, имя', width: 210, bold: true, alignLeft: true),
          for (var day = 1; day <= days; day++)
            _gridCell('$day', width: 38, bold: true),
          _gridCell('Итого', width: 58, bold: true),
        ],
      ),
    );
  }

  Widget _attendanceRow(Map<String, dynamic> player, int days, bool closed) {
    final playerId = _int(player['id']);
    final byPlayer = _map(_attendance['$playerId'] ?? _attendance[playerId]);
    var presentCount = 0;
    for (var day = 1; day <= days; day++) {
      final date = DateTime(_attendanceMonth.year, _attendanceMonth.month, day);
      final cell = _map(byPlayer[_dateKey(date)]);
      if (_text(cell['status']) == 'present') presentCount++;
    }
    return Row(
      children: [
        _gridCell(_text(player['full_name']), width: 210, alignLeft: true),
        for (var day = 1; day <= days; day++)
          _attendanceCell(playerId, day, byPlayer, closed),
        _gridCell('$presentCount', width: 58, bold: true),
      ],
    );
  }

  Widget _gridCell(String text,
      {required double width, bool bold = false, bool alignLeft = false}) {
    return Container(
      width: width,
      height: 40,
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(
            right: BorderSide(color: _line), bottom: BorderSide(color: _line)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 11.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
      ),
    );
  }

  Widget _attendanceCell(
      int playerId, int day, Map<String, dynamic> byPlayer, bool closed) {
    final date = DateTime(_attendanceMonth.year, _attendanceMonth.month, day);
    final key = _dateKey(date);
    final cell = _map(byPlayer[key]);
    final status = _text(cell['status']);
    final mark = _attendanceMark(status);
    return InkWell(
      onTap: closed
          ? null
          : () =>
              _chooseAttendance(playerId, date, status, _text(cell['note'])),
      child: Container(
        width: 38,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: status.isEmpty ? Colors.white : _statusSoft(status),
          border: const Border(
              right: BorderSide(color: _line),
              bottom: BorderSide(color: _line)),
        ),
        child: Text(mark,
            style: TextStyle(
              color: status.isEmpty ? _muted : _statusColor(status),
              fontWeight: FontWeight.w800,
              fontSize: mark.length > 1 ? 10 : 13,
            )),
      ),
    );
  }

  Future<void> _chooseAttendance(
      int playerId, DateTime date, String current, String note) async {
    final selected = await showModalBottomSheet<_AttendanceStatus>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Очистить отметку'),
              selected: current.isEmpty,
              onTap: () => Navigator.pop(
                  context, const _AttendanceStatus('', '', 'Очистить')),
            ),
            ..._attendanceStatuses.map((s) => ListTile(
                  leading: CircleAvatar(
                      backgroundColor: _statusSoft(s.value),
                      child: Text(s.mark,
                          style: TextStyle(
                              color: _statusColor(s.value),
                              fontWeight: FontWeight.w800))),
                  title: Text(s.title),
                  trailing: current == s.value
                      ? const Icon(Icons.check_rounded, color: _green)
                      : null,
                  onTap: () => Navigator.pop(context, s),
                )),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _post('set_attendance', {
      'player_id': playerId,
      'day_date': _dateKey(date),
      'status': selected.value,
      'note': note,
    });
  }

  Future<void> _closeMonth(DateTime month) async {
    if (!await _confirm(
        'Закрыть ${_monthTitle(month)}? Будет создана подписанная версия месяца.'))
      return;
    await _post('close_month', {'year_month': _yearMonth(month)});
  }

  Future<void> _reopenMonth(DateTime month) async {
    if (!await _confirm(
        'Открыть ${_monthTitle(month)} для исправлений? Подписанная версия сохранится в истории.'))
      return;
    await _post('reopen_month', {'year_month': _yearMonth(month)});
  }

  String _attendanceMark(String status) {
    for (final s in _attendanceStatuses) {
      if (s.value == status) return s.mark;
    }
    if (status == 'late') return 'оп';
    if (status == 'injured') return 'тр';
    if (status == 'individual') return 'ип';
    if (status == 'dayoff') return 'в';
    return '';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return _green;
      case 'absent':
        return const Color(0xFFDC2626);
      case 'sick':
        return const Color(0xFFEA580C);
      case 'competition':
        return const Color(0xFF2563EB);
      case 'training_camp':
      case 'sport_camp':
        return const Color(0xFF7C3AED);
      default:
        return _muted;
    }
  }

  Color _statusSoft(String status) => _statusColor(status).withOpacity(.10);

  Widget _buildPlayers() {
    return _pageScroll([
      const _SectionHeading(
        title: 'Раздел IV. Сведения о спортсменах-учащихся',
        subtitle:
            'Данные состава берутся из профилей игроков. Школа, зачисление, разряд, форма и обувь сохраняются в общем профиле цифрового журнала.',
      ),
      const SizedBox(height: 14),
      if (_players.isEmpty)
        _EmptyBlock(
          icon: Icons.groups_2_outlined,
          title: 'Состав команды пока не получен',
          subtitle:
              'Нажмите «Обновить». Журнал читает тот же состав и профиль, которые используются в карточке команды.',
        )
      else
        ..._players.map((player) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _playerCard(player),
            )),
    ]);
  }

  Widget _playerCard(Map<String, dynamic> player) {
    final playerId = _int(player['id'] ?? player['player_id']);
    final jp = _map(player['journal_profile']);
    final med = _map(player['medical_summary']);
    final parent = _parentForPlayer(playerId);
    final pp = _map(parent?['journal_profile']);
    final briefing = _latestBriefing(playerId);
    final school = [
      _text(jp['institution_name']),
      _text(jp['class_name']),
    ].where((e) => e.isNotEmpty).join(' · ');

    final birth = _text(player['birth_date']).isNotEmpty
        ? _text(player['birth_date'])
        : _text(player['birthDate']);
    final age = _ageFromBirth(birth);
    final height = _metricText(
      player,
      const ['height', 'height_cm', 'heightCm'],
    );
    final weight = _metricText(
      player,
      const ['weight', 'weight_kg', 'weightKg'],
    );
    final number = _text(player['jersey_number']).isNotEmpty
        ? _text(player['jersey_number'])
        : _text(player['number']);

    return _JournalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _JournalAvatar(
                name: _text(player['full_name']),
                photo: _playerPhotoUrl(player),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(player['full_name']),
                      style: AppTypography.custom(
                        size: 15,
                        weight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (birth.isNotEmpty) 'р. $birth',
                        if (_text(player['position']).isNotEmpty)
                          _text(player['position']),
                        if (number.isNotEmpty) '№ $number',
                      ].join(' · '),
                      style: AppTypography.custom(
                        size: 11.3,
                        weight: FontWeight.w400,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              _JournalSoftAction(
                icon: Icons.edit_outlined,
                label: 'Данные',
                accent: true,
                onTap: () => _editPlayer(player),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                elevation: 0,
                color: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'pre') {
                    _saveMedicalExam(player, 'preliminary_exam');
                  }
                  if (value == 'periodic') {
                    _saveMedicalExam(player, 'periodic_exam');
                  }
                  if (value == 'briefing') _saveBriefing(player);
                  if (value == 'parent' && parent != null) {
                    _editParent(parent);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'pre',
                    child: Text('Предварительный медосмотр'),
                  ),
                  const PopupMenuItem(
                    value: 'periodic',
                    child: Text('Периодический медосмотр'),
                  ),
                  const PopupMenuItem(
                    value: 'briefing',
                    child: Text('Инструктаж по безопасности'),
                  ),
                  if (parent != null)
                    const PopupMenuItem(
                      value: 'parent',
                      child: Text('Сведения о родителе'),
                    ),
                ],
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '•••',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _JournalPlayerMetrics(
            age: age,
            height: height,
            weight: weight,
            number: number,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _InfoPair(
                'Дата рождения',
                birth.isEmpty ? '—' : birth,
              ),
              _InfoPair(
                'Гражданство',
                [
                  _text(player['nationality']),
                  _text(player['citizenship']),
                  _text(player['country']),
                ].firstWhere((e) => e.isNotEmpty, orElse: () => '—'),
              ),
              _InfoPair(
                'Email',
                _text(player['email']).isEmpty ? '—' : _text(player['email']),
              ),
              _InfoPair(
                'Телефон',
                _text(player['phone']).isEmpty ? '—' : _text(player['phone']),
              ),
              _InfoPair(
                'Зачисление',
                _text(jp['enrollment_date']).isEmpty
                    ? '—'
                    : _text(jp['enrollment_date']),
              ),
              _InfoPair(
                'Разряд',
                _text(jp['sport_rank']).isEmpty ? '—' : _text(jp['sport_rank']),
              ),
              _InfoPair(
                'Форма / обувь',
                '${_text(jp['uniform_size']).isEmpty ? '—' : _text(jp['uniform_size'])} / '
                    '${_text(jp['shoe_size']).isEmpty ? '—' : _text(jp['shoe_size'])}',
              ),
              _InfoPair('Учёба', school.isEmpty ? '—' : school),
              _InfoPair(
                'Предв. медосмотр',
                _text(med['preliminary_exam_date']).isEmpty
                    ? '—'
                    : _text(med['preliminary_exam_date']),
              ),
              _InfoPair(
                'Период. медосмотр',
                _text(med['periodic_exam_date']).isEmpty
                    ? '—'
                    : _text(med['periodic_exam_date']),
              ),
              _InfoPair(
                'Родитель',
                parent == null ? '—' : _text(parent['full_name']),
              ),
              _InfoPair(
                'Работа родителя',
                parent == null
                    ? '—'
                    : [
                        _text(pp['occupation']),
                        _text(pp['work_phone']),
                      ].where((e) => e.isNotEmpty).join(' · '),
              ),
              _InfoPair(
                'Инструктаж',
                briefing == null
                    ? '—'
                    : '${_text(briefing['briefing_date'])}'
                        '${_text(briefing['trainer_signed_at']).isEmpty ? '' : ' · тренер ✓'}',
              ),
            ],
          ),
          if (_text(player['sport_data']).isNotEmpty) ...[
            const SizedBox(height: 14),
            _JournalInlineNotice(
              icon: Icons.sports_soccer_rounded,
              text: _text(player['sport_data']),
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String name) {
    final words = name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2);
    return words.map((e) => e.substring(0, 1).toUpperCase()).join();
  }

  Future<void> _editPlayer(Map<String, dynamic> player) async {
    final jp = _map(player['journal_profile']);
    TextEditingController profileController(String key) =>
        TextEditingController(text: _text(jp[key]));

    final firstName = TextEditingController(text: _text(player['first_name']));
    final lastName = TextEditingController(text: _text(player['last_name']));
    final birthDate = TextEditingController(
      text: _text(player['birth_date']).isNotEmpty
          ? _text(player['birth_date'])
          : _text(player['birthDate']),
    );
    final position = TextEditingController(text: _text(player['position']));
    final jerseyNumber = TextEditingController(
      text: _text(player['jersey_number']).isNotEmpty
          ? _text(player['jersey_number'])
          : _text(player['number']),
    );
    final nationality = TextEditingController(
      text: [
        _text(player['nationality']),
        _text(player['citizenship']),
        _text(player['country']),
      ].firstWhere((e) => e.isNotEmpty, orElse: () => ''),
    );
    final email = TextEditingController(text: _text(player['email']));
    final phone = TextEditingController(text: _text(player['phone']));
    final enrollment = profileController('enrollment_date');
    final rank = profileController('sport_rank');
    final uniform = profileController('uniform_size');
    final shoe = profileController('shoe_size');
    final institution = profileController('institution_name');
    final className = profileController('class_name');
    final institutionAddress = profileController('institution_address');
    final study = profileController('study_or_work');
    final homeAddress = profileController('home_address');
    final homePhone = profileController('home_phone');

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 34,
                spreadRadius: -18,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _JournalAvatar(
                    name: _text(player['full_name']),
                    photo: _playerPhotoUrl(player),
                    size: 42,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(player['full_name']).isEmpty
                              ? 'Данные игрока'
                              : _text(player['full_name']),
                          style: AppTypography.custom(
                            size: 18,
                            weight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Изменения общих полей сразу попадут в профиль игрока.',
                          style: AppTypography.custom(
                            size: 11,
                            weight: FontWeight.w400,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    icon: const Icon(Icons.close_rounded, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _JournalEditorSectionTitle(
                        'Основные данные профиля',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _JournalField(
                              controller: lastName,
                              label: 'Фамилия',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _JournalField(
                              controller: firstName,
                              label: 'Имя',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _JournalField(
                              controller: birthDate,
                              label: 'Дата рождения',
                              hint: 'YYYY-MM-DD',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _JournalField(
                              controller: position,
                              label: 'Амплуа / позиция',
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 120,
                            child: _JournalField(
                              controller: jerseyNumber,
                              label: 'Номер',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _JournalField(
                              controller: nationality,
                              label: 'Гражданство',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _JournalField(
                              controller: phone,
                              label: 'Телефон',
                            ),
                          ),
                        ],
                      ),
                      _JournalField(
                        controller: email,
                        label: 'Email',
                      ),
                      const SizedBox(height: 16),
                      const _JournalEditorSectionTitle(
                        'Официальные данные журнала',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _JournalField(
                              controller: enrollment,
                              label: 'Дата зачисления',
                              hint: 'YYYY-MM-DD',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _JournalField(
                              controller: rank,
                              label: 'Спортивный разряд',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _JournalField(
                              controller: uniform,
                              label: 'Размер формы',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _JournalField(
                              controller: shoe,
                              label: 'Размер обуви',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _JournalEditorSectionTitle('Учёба и контакты'),
                      _JournalField(
                        controller: institution,
                        label: 'Учреждение образования / организация',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _JournalField(
                              controller: className,
                              label: 'Класс',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _JournalField(
                              controller: study,
                              label: 'Место учёбы / работы',
                            ),
                          ),
                        ],
                      ),
                      _JournalField(
                        controller: institutionAddress,
                        label: 'Адрес учреждения',
                      ),
                      _JournalField(
                        controller: homeAddress,
                        label: 'Домашний адрес',
                      ),
                      _JournalField(
                        controller: homePhone,
                        label: 'Домашний телефон',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Сохранить всё'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;

    final coreOk = await _post('save_player_core', {
      'player_id': _int(player['id'] ?? player['player_id']),
      'first_name': firstName.text.trim(),
      'last_name': lastName.text.trim(),
      'birth_date': birthDate.text.trim(),
      'position': position.text.trim(),
      'jersey_number': jerseyNumber.text.trim(),
      'nationality': nationality.text.trim(),
      'email': email.text.trim(),
      'phone': phone.text.trim(),
    });
    if (!coreOk) return;
    await _post('save_player_profile', {
      'player_id': _int(player['id'] ?? player['player_id']),
      'enrollment_date': enrollment.text.trim(),
      'sport_rank': rank.text.trim(),
      'uniform_size': uniform.text.trim(),
      'shoe_size': shoe.text.trim(),
      'institution_name': institution.text.trim(),
      'class_name': className.text.trim(),
      'institution_address': institutionAddress.text.trim(),
      'study_or_work': study.text.trim(),
      'home_address': homeAddress.text.trim(),
      'home_phone': homePhone.text.trim(),
    });
  }

  Future<void> _editParent(Map<String, dynamic> parent) async {
    final p = _map(parent['journal_profile']);
    TextEditingController c(String key) =>
        TextEditingController(text: _text(p[key]));
    final firstName = TextEditingController(text: _text(parent['first_name']));
    final lastName = TextEditingController(text: _text(parent['last_name']));
    final email = TextEditingController(text: _text(parent['email']));
    final phone = TextEditingController(text: _text(parent['phone']));
    final occupation = c('occupation');
    final workplace = c('workplace');
    final workPhone = c('work_phone');
    final homeAddress = c('home_address');
    final homePhone = c('home_phone');

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _JournalDialogFrame(
        title: 'Родитель',
        subtitle: _text(parent['full_name']).isEmpty
            ? 'Связанные данные родителя'
            : _text(parent['full_name']),
        maxWidth: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _JournalEditorSectionTitle('Основные данные'),
              Row(children: [
                Expanded(
                    child:
                        _JournalField(controller: lastName, label: 'Фамилия')),
                const SizedBox(width: 10),
                Expanded(
                    child: _JournalField(controller: firstName, label: 'Имя')),
              ]),
              Row(children: [
                Expanded(
                    child: _JournalField(controller: email, label: 'Email')),
                const SizedBox(width: 10),
                Expanded(
                    child: _JournalField(controller: phone, label: 'Телефон')),
              ]),
              const SizedBox(height: 8),
              const _JournalEditorSectionTitle(
                  'Данные для официального журнала'),
              _JournalField(
                  controller: occupation, label: 'Должность / профессия'),
              _JournalField(controller: workplace, label: 'Место работы'),
              Row(children: [
                Expanded(
                    child: _JournalField(
                        controller: workPhone, label: 'Рабочий телефон')),
                const SizedBox(width: 10),
                Expanded(
                    child: _JournalField(
                        controller: homePhone, label: 'Домашний телефон')),
              ]),
              _JournalField(
                  controller: homeAddress,
                  label: 'Домашний адрес',
                  maxLines: 2),
            ],
          ),
        ),
        actions: [
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Сохранить всё'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final coreOk = await _post('save_parent_core', {
      'parent_user_id': _int(parent['parent_user_id']),
      'first_name': firstName.text.trim(),
      'last_name': lastName.text.trim(),
      'email': email.text.trim(),
      'phone': phone.text.trim(),
    });
    if (!coreOk) return;
    await _post('save_parent_profile', {
      'parent_user_id': _int(parent['parent_user_id']),
      'occupation': occupation.text.trim(),
      'workplace': workplace.text.trim(),
      'work_phone': workPhone.text.trim(),
      'home_address': homeAddress.text.trim(),
      'home_phone': homePhone.text.trim(),
    });
  }

  Future<void> _saveMedicalExam(
      Map<String, dynamic> player, String type) async {
    final controller = TextEditingController(text: _dateKey(DateTime.now()));
    final preliminary = type == 'preliminary_exam';
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _JournalDialogFrame(
        title: preliminary
            ? 'Предварительный медосмотр'
            : 'Периодический медосмотр',
        subtitle: _text(player['full_name']),
        maxWidth: 520,
        child: _JournalField(
          controller: controller,
          label: 'Дата осмотра',
          hint: 'YYYY-MM-DD',
        ),
        actions: [
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    await _post('save_medical_exam', {
      'player_id': _int(player['id']),
      'record_type': type,
      'record_date': controller.text.trim(),
    });
  }

  Future<void> _saveBriefing(Map<String, dynamic> player) async {
    final date = TextEditingController(text: _dateKey(DateTime.now()));
    final type = TextEditingController(
      text:
          'Инструктаж по безопасности проведения занятий физической культурой и спортом',
    );
    var playerSigned = false;
    var trainerSigned = true;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => _JournalDialogFrame(
          title: 'Инструктаж',
          subtitle: _text(player['full_name']),
          maxWidth: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _JournalField(
                  controller: date, label: 'Дата', hint: 'YYYY-MM-DD'),
              _JournalField(
                  controller: type, label: 'Вид инструктажа', maxLines: 3),
              _JournalToggleRow(
                title: 'Подпись спортсмена подтверждена',
                value: playerSigned,
                onChanged: (value) => setLocal(() => playerSigned = value),
              ),
              const SizedBox(height: 7),
              _JournalToggleRow(
                title: 'Подпись тренера подтверждена',
                value: trainerSigned,
                onChanged: (value) => setLocal(() => trainerSigned = value),
              ),
            ],
          ),
          actions: [
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _post('save_safety_briefing', {
      'player_id': _int(player['id']),
      'briefing_date': date.text.trim(),
      'briefing_type': type.text.trim(),
      'trainer_id': widget.currentUserId,
      'player_signed': playerSigned ? 1 : 0,
      'trainer_signed': trainerSigned ? 1 : 0,
    });
  }

  Widget _buildQuality() {
    return _pageScroll([
      _SectionHeading(
        title: 'Раздел V. Самоконтроль качества',
        subtitle:
            'Мероприятия, оценка качества, количество участников и ответственное лицо.',
        action: _JournalSoftAction(
          icon: Icons.add_rounded,
          label: 'Добавить запись',
          accent: true,
          onTap: () => _editQuality(null),
        ),
      ),
      const SizedBox(height: 14),
      if (_quality.isEmpty)
        const _EmptyBlock(
          icon: Icons.verified_user_outlined,
          title: 'Записей пока нет',
          subtitle:
              'Добавьте мероприятие по самоконтролю качества тренировочного процесса.',
        )
      else
        ..._quality.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _JournalCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: _greenSoft,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.verified_rounded, color: _green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_text(row['title']),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                                '${_text(row['control_date'])} · участников: ${_int(row['participants_count'])} · ${_text(row['responsible_name'])}',
                                style: const TextStyle(
                                    color: _muted, fontSize: 12.5)),
                            if (_text(row['quality_assessment'])
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(_text(row['quality_assessment']),
                                  style: const TextStyle(height: 1.4)),
                            ],
                          ]),
                    ),
                    IconButton(
                        onPressed: () => _editQuality(row),
                        icon: const Icon(Icons.edit_outlined)),
                  ],
                ),
              ),
            )),
    ]);
  }

  Future<void> _editQuality(Map<String, dynamic>? row) async {
    final date = TextEditingController(
      text: _text(row?['control_date']).isEmpty
          ? _dateKey(DateTime.now())
          : _text(row?['control_date']),
    );
    final title = TextEditingController(text: _text(row?['title']));
    final assessment =
        TextEditingController(text: _text(row?['quality_assessment']));
    final count =
        TextEditingController(text: '${_int(row?['participants_count'])}');
    final responsible = TextEditingController(
      text: _text(row?['responsible_name']).isEmpty
          ? (_trainerNames.split(',').firstOrNull ?? '')
          : _text(row?['responsible_name']),
    );
    var signed = _text(row?['signed_at']).isNotEmpty;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => _JournalDialogFrame(
          title: 'Самоконтроль качества',
          subtitle: 'Раздел V официального журнала',
          maxWidth: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _JournalField(
                    controller: date, label: 'Дата', hint: 'YYYY-MM-DD'),
                _JournalField(
                    controller: title, label: 'Наименование мероприятия'),
                _JournalField(
                    controller: assessment,
                    label: 'Оценка качества',
                    maxLines: 4),
                Row(children: [
                  Expanded(
                    child: _JournalField(
                      controller: count,
                      label: 'Количество участников',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _JournalField(
                          controller: responsible,
                          label: 'Ответственное лицо')),
                ]),
                _JournalToggleRow(
                  title: 'Подпись / подтверждение ответственного лица',
                  value: signed,
                  onChanged: (value) => setLocal(() => signed = value),
                ),
              ],
            ),
          ),
          actions: [
            if (row != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext, false);
                  if (await _confirm('Удалить запись самоконтроля?')) {
                    await _post(
                        'delete_quality_control', {'id': _int(row['id'])});
                  }
                },
                child: const Text('Удалить',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _post('save_quality_control', {
      if (row != null) 'id': _int(row['id']),
      'control_date': date.text.trim(),
      'title': title.text.trim(),
      'quality_assessment': assessment.text.trim(),
      'participants_count': _int(count.text),
      'responsible_user_id': widget.currentUserId,
      'responsible_name': responsible.text.trim(),
      'signed': signed ? 1 : 0,
    });
  }

  Widget _buildDocumentPreview() {
    return _pageScroll([
      _SectionHeading(
        title: 'Документ А4',
        subtitle:
            'Печатная версия собирается из тех же живых данных. В браузере её можно распечатать или сохранить в PDF.',
        action: _journalId <= 0
            ? null
            : _JournalSoftAction(
                icon: Icons.print_rounded,
                label: 'Печать / PDF',
                accent: true,
                onTap: _openPrintable,
              ),
      ),
      const SizedBox(height: 14),
      Center(
        child: _PaperPage(
          portrait: true,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text('ЖУРНАЛ',
                  style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(
                  'Учёта учебно-тренировочного процесса за $_academicYear учебный год',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 30),
              Text('«$_structuralUnit»',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_schoolName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'serif', fontSize: 15)),
              Text(_legalName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'serif', fontSize: 15)),
              const SizedBox(height: 28),
              _CoverLine('вид спорта', _sportName),
              _CoverLine('группа', _text(_journal['group_type'])),
              _CoverLine('год обучения', _text(_journal['study_year'])),
              _CoverLine('тренер(ы)', _trainerNames),
              const Spacer(),
              Text(
                  'Разделы I–V формируются автоматически: учебный план · расписание · посещаемость · сведения об игроках · самоконтроль.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'serif', fontSize: 11.5, height: 1.4)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      _JournalCard(
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: _green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Печатная версия содержит все 12 месячных листов раздела III, обе части раздела IV и раздел V. Для PDF нажмите «Печать / PDF» и выберите сохранение в PDF в системном окне печати.',
                style: const TextStyle(
                    color: _muted, fontSize: 12.5, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Future<void> _openPrintable() async {
    final uri = Uri.parse('$_apiBase/print.php')
        .replace(queryParameters: {'journal_id': '$_journalId'});
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть печатную версию')));
    }
  }

  Future<bool> _confirm(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Подтверждение'),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Продолжить')),
            ],
          ),
        ) ??
        false;
  }
}

class _TrainingEventTile extends StatelessWidget {
  const _TrainingEventTile({
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.type,
    required this.onEdit,
  });

  final String title;
  final String date;
  final String time;
  final String location;
  final String type;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (type) {
      'theory' => 'Теория',
      'gym' => 'ОФП / зал',
      _ => 'Тренировка',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Material(
        color: const Color(0xFFF5F6F6),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sports_soccer_rounded,
                      size: 19, color: Color(0xFF198754)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                        [date, time, if (location.isNotEmpty) location]
                            .where((e) => e.isNotEmpty)
                            .join(' · '),
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(typeLabel,
                      style: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftChoice<T> extends StatelessWidget {
  const _SoftChoice({
    required this.value,
    required this.label,
    required this.values,
    required this.onChanged,
  });

  final T value;
  final String label;
  final Map<T, String> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 7, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10.5)),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(14),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              items: values.entries
                  .map((entry) => DropdownMenuItem<T>(
                        value: entry.key,
                        child: Text(entry.value,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogSectionTitle extends StatelessWidget {
  const _DialogSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

List<List<Offset>> _decodeSignatureStrokes(String raw) {
  if (raw.trim().isEmpty) return <List<Offset>>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <List<Offset>>[];
    final strokes = <List<Offset>>[];
    for (final stroke in decoded) {
      if (stroke is! List) continue;
      final points = <Offset>[];
      for (final point in stroke) {
        if (point is List && point.length >= 2) {
          final x = point[0] is num
              ? (point[0] as num).toDouble()
              : double.tryParse('${point[0]}');
          final y = point[1] is num
              ? (point[1] as num).toDouble()
              : double.tryParse('${point[1]}');
          if (x != null && y != null)
            points.add(
                Offset(x.clamp(0, 1).toDouble(), y.clamp(0, 1).toDouble()));
        }
      }
      if (points.isNotEmpty) strokes.add(points);
    }
    return strokes;
  } catch (_) {
    return <List<Offset>>[];
  }
}

class _SignaturePreview extends StatelessWidget {
  const _SignaturePreview({
    required this.json,
    this.width = 150,
    this.height = 50,
  });

  final String json;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SignaturePainter(_decodeSignatureStrokes(json)),
      ),
    );
  }
}

class _SignatureCaptureDialog extends StatefulWidget {
  const _SignatureCaptureDialog({required this.signerName});
  final String signerName;

  @override
  State<_SignatureCaptureDialog> createState() =>
      _SignatureCaptureDialogState();
}

class _SignatureCaptureDialogState extends State<_SignatureCaptureDialog> {
  final List<List<Offset>> _strokes = <List<Offset>>[];

  Offset _normalized(Offset p, Size size) {
    final width = size.width <= 0 ? 1.0 : size.width;
    final height = size.height <= 0 ? 1.0 : size.height;
    return Offset(
      (p.dx / width).clamp(0.0, 1.0).toDouble(),
      (p.dy / height).clamp(0.0, 1.0).toDouble(),
    );
  }

  String _json() => jsonEncode(
        _strokes
            .where((stroke) => stroke.isNotEmpty)
            .map((stroke) =>
                stroke.map((point) => <double>[point.dx, point.dy]).toList())
            .toList(),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Подпись тренера',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(widget.signerName,
                            style: const TextStyle(
                                color: Color(0xFF6B7280), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, 260);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      setState(() => _strokes.add(
                          <Offset>[_normalized(details.localPosition, size)]));
                    },
                    onPanUpdate: (details) {
                      if (_strokes.isEmpty) return;
                      setState(() => _strokes.last
                          .add(_normalized(details.localPosition, size)));
                    },
                    child: Container(
                      width: size.width,
                      height: size.height,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8F8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                                painter: _SignaturePainter(_strokes)),
                          ),
                          if (_strokes.isEmpty)
                            const Center(
                              child: Text(
                                'Проведите стилусом, пальцем или мышью',
                                style: TextStyle(
                                    color: Color(0xFF9CA3AF), fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _strokes.isEmpty
                        ? null
                        : () => setState(() => _strokes.removeLast()),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Отменить штрих'),
                  ),
                  TextButton.icon(
                    onPressed: _strokes.isEmpty
                        ? null
                        : () => setState(_strokes.clear),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Очистить'),
                  ),
                  const Spacer(),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _strokes.isEmpty
                        ? null
                        : () => Navigator.pop(context, _json()),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Вставить подпись'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF191B1C)
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        final p =
            Offset(stroke.first.dx * size.width, stroke.first.dy * size.height);
        canvas.drawCircle(p, 1.1, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path();
      for (var i = 0; i < stroke.length; i++) {
        final point =
            Offset(stroke[i].dx * size.width, stroke[i].dy * size.height);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

class _JournalTabDef {
  const _JournalTabDef(this.title, this.icon);
  final String title;
  final IconData icon;
}

class _AttendanceStatus {
  const _AttendanceStatus(this.value, this.mark, this.title);
  final String value;
  final String mark;
  final String title;
}

const List<_AttendanceStatus> _attendanceStatuses = <_AttendanceStatus>[
  _AttendanceStatus('present', '•', 'Присутствовал'),
  _AttendanceStatus('absent', 'н', 'Отсутствовал'),
  _AttendanceStatus('sick', 'б', 'Отсутствовал по болезни'),
  _AttendanceStatus('competition', 'с', 'Участие в соревнованиях'),
  _AttendanceStatus('training_camp', 'у', 'Учебно-тренировочный сбор'),
  _AttendanceStatus('sport_camp', 'сол', 'Спортивно-оздоровительный лагерь'),
];

class _AttendanceLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _attendanceStatuses
          .map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${s.mark} — ${s.title}',
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF4B5563))),
              ))
          .toList(),
    );
  }
}

class _JournalDotCluster extends StatelessWidget {
  const _JournalDotCluster();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _JournalGlowDot(size: 3.5, opacity: .28),
        SizedBox(width: 3),
        _JournalGlowDot(size: 4.5, opacity: .5),
        SizedBox(width: 3),
        _JournalGlowDot(size: 5.5, opacity: .74),
        SizedBox(width: 3),
        _JournalGlowDot(size: 6.5, opacity: 1),
      ],
    );
  }
}

class _JournalGlowDot extends StatelessWidget {
  const _JournalGlowDot({
    this.size = 6,
    this.opacity = 1,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _CmrTrainingJournalPanelState._green,
          shape: BoxShape.circle,
          boxShadow: opacity > .7
              ? [
                  BoxShadow(
                    color:
                        _CmrTrainingJournalPanelState._green.withOpacity(.16),
                    blurRadius: size * 2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _JournalStatusDot extends StatelessWidget {
  const _JournalStatusDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 7 : 6,
      height: active ? 7 : 6,
      decoration: BoxDecoration(
        color: active
            ? _CmrTrainingJournalPanelState._green
            : _CmrTrainingJournalPanelState._line,
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: _CmrTrainingJournalPanelState._green.withOpacity(.18),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
    );
  }
}

class _JournalSoftAction extends StatelessWidget {
  const _JournalSoftAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent
        ? _CmrTrainingJournalPanelState._greenDark
        : _CmrTrainingJournalPanelState._ink;
    return Material(
      color: accent
          ? _CmrTrainingJournalPanelState._greenSoft
          : _CmrTrainingJournalPanelState._soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTypography.custom(
                  size: 11.2,
                  weight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalDialogFrame extends StatelessWidget {
  const _JournalDialogFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.actions,
    this.maxWidth = 680,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        width: maxWidth,
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 820),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 34,
              spreadRadius: -18,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _JournalDotCluster(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.custom(
                          size: 17.5,
                          weight: FontWeight.w600,
                          color: _CmrTrainingJournalPanelState._ink,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.custom(
                            size: 11.2,
                            weight: FontWeight.w400,
                            color: _CmrTrainingJournalPanelState._muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(child: child),
            const SizedBox(height: 14),
            Row(children: actions),
          ],
        ),
      ),
    );
  }
}

class _JournalToggleRow extends StatelessWidget {
  const _JournalToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value
          ? _CmrTrainingJournalPanelState._greenSoft
          : _CmrTrainingJournalPanelState._soft,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              _JournalStatusDot(active: value),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.custom(
                    size: 11.8,
                    weight: value ? FontWeight.w600 : FontWeight.w500,
                    color: value
                        ? _CmrTrainingJournalPanelState._greenDark
                        : _CmrTrainingJournalPanelState._ink,
                  ),
                ),
              ),
              Icon(
                value ? Icons.check_rounded : Icons.add_rounded,
                size: 17,
                color: value
                    ? _CmrTrainingJournalPanelState._green
                    : _CmrTrainingJournalPanelState._muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalEditorSectionTitle extends StatelessWidget {
  const _JournalEditorSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          const _JournalStatusDot(active: true),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTypography.custom(
              size: 12.3,
              weight: FontWeight.w600,
              color: _CmrTrainingJournalPanelState._ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalField extends StatelessWidget {
  const _JournalField({
    required this.controller,
    required this.label,
    this.hint = '',
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 5),
            child: Text(
              label,
              style: AppTypography.custom(
                size: 10.2,
                weight: FontWeight.w600,
                color: _CmrTrainingJournalPanelState._muted,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _CmrTrainingJournalPanelState._soft,
              borderRadius: BorderRadius.circular(11),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint.isEmpty ? null : hint,
                hintStyle: AppTypography.custom(
                  size: 12.2,
                  weight: FontWeight.w400,
                  color: const Color(0xFF9CA3AF),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: maxLines > 1 ? 11 : 12,
                ),
              ),
              style: AppTypography.custom(
                size: 12.5,
                weight: FontWeight.w500,
                color: _CmrTrainingJournalPanelState._ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalChoiceChip extends StatelessWidget {
  const _JournalChoiceChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? _CmrTrainingJournalPanelState._greenSoft
          : _CmrTrainingJournalPanelState._soft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _JournalStatusDot(active: active),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTypography.custom(
                  size: 11.5,
                  weight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? _CmrTrainingJournalPanelState._greenDark
                      : _CmrTrainingJournalPanelState._ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalTrainerChoice extends StatelessWidget {
  const _JournalTrainerChoice({
    required this.name,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? _CmrTrainingJournalPanelState._greenSoft
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              _JournalStatusDot(active: active),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.custom(
                        size: 12.2,
                        weight: FontWeight.w600,
                        color: _CmrTrainingJournalPanelState._ink,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.custom(
                          size: 10.2,
                          weight: FontWeight.w400,
                          color: _CmrTrainingJournalPanelState._muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                active ? Icons.check_rounded : Icons.add_rounded,
                size: 17,
                color: active
                    ? _CmrTrainingJournalPanelState._greenDark
                    : _CmrTrainingJournalPanelState._muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalInlineNotice extends StatelessWidget {
  const _JournalInlineNotice({
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: _CmrTrainingJournalPanelState._soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: _CmrTrainingJournalPanelState._greenDark,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: AppTypography.custom(
                size: 11.2,
                weight: FontWeight.w400,
                color: _CmrTrainingJournalPanelState._muted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCell extends StatelessWidget {
  const _ScheduleCell({
    required this.text,
    required this.count,
    required this.onTap,
  });

  final String text;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasData = text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 5, 3, 5),
      child: Material(
        color: hasData
            ? _CmrTrainingJournalPanelState._greenSoft
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
              child: hasData
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          text,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.custom(
                            size: 10.1,
                            weight: FontWeight.w600,
                            color: _CmrTrainingJournalPanelState._greenDark,
                            height: 1.25,
                          ),
                        ),
                        if (count > 1) ...[
                          const SizedBox(height: 4),
                          Text(
                            '$count занятий',
                            style: AppTypography.custom(
                              size: 8.8,
                              weight: FontWeight.w400,
                              color: _CmrTrainingJournalPanelState._muted,
                            ),
                          ),
                        ],
                      ],
                    )
                  : const Center(
                      child: Text(
                        '—',
                        style: TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 11,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JournalAvatar extends StatelessWidget {
  const _JournalAvatar({
    required this.name,
    this.photo = '',
    this.size = 40,
  });

  final String name;
  final String photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2);
    final initials = words.map((e) => e.substring(0, 1).toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _CmrTrainingJournalPanelState._greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isEmpty
          ? Text(
              initials.isEmpty ? 'И' : initials,
              style: AppTypography.custom(
                size: size * .28,
                weight: FontWeight.w600,
                color: _CmrTrainingJournalPanelState._greenDark,
              ),
            )
          : Image.network(
              photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initials.isEmpty ? 'И' : initials,
                  style: AppTypography.custom(
                    size: size * .28,
                    weight: FontWeight.w600,
                    color: _CmrTrainingJournalPanelState._greenDark,
                  ),
                ),
              ),
            ),
    );
  }
}

class _JournalPlayerMetrics extends StatelessWidget {
  const _JournalPlayerMetrics({
    required this.age,
    required this.height,
    required this.weight,
    required this.number,
  });

  final String age;
  final String height;
  final String weight;
  final String number;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value})>[
      (label: 'Возраст', value: age.isEmpty ? '—' : age),
      (
        label: 'Рост',
        value: height.isEmpty
            ? '—'
            : (height.toLowerCase().contains('см') ? height : '$height см'),
      ),
      (
        label: 'Вес',
        value: weight.isEmpty
            ? '—'
            : (weight.toLowerCase().contains('кг') ? weight : '$weight кг'),
      ),
      (
        label: 'Номер',
        value: number.isEmpty ? '—' : '№ $number',
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: _CmrTrainingJournalPanelState._soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Text(
                    items[i].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.custom(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: _CmrTrainingJournalPanelState._ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i].label,
                    style: AppTypography.custom(
                      size: 9.5,
                      weight: FontWeight.w500,
                      color: _CmrTrainingJournalPanelState._muted,
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              Container(
                width: 1,
                height: 28,
                color: _CmrTrainingJournalPanelState._line,
              ),
          ],
        ],
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard(
      {required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 20,
            spreadRadius: -14,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(
      {required this.title, required this.subtitle, this.action});
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12.5, height: 1.4)),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 14), action!],
      ],
    );
  }
}

class _InfoPair extends StatelessWidget {
  const _InfoPair(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '—' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PaperPage extends StatelessWidget {
  const _PaperPage({required this.child, this.portrait = false});
  final Widget child;
  final bool portrait;

  @override
  Widget build(BuildContext context) {
    final width = portrait ? 620.0 : 860.0;
    final height = portrait ? 876.0 : 608.0;
    return Container(
      width: math.min(width, MediaQuery.sizeOf(context).width - 52),
      height: height,
      padding: const EdgeInsets.fromLTRB(38, 42, 38, 34),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD1D5DB)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x16000000), blurRadius: 24, offset: Offset(0, 10))
        ],
      ),
      child: child,
    );
  }
}

class _CoverLine extends StatelessWidget {
  const _CoverLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$label  ',
              style: const TextStyle(fontFamily: 'serif', fontSize: 14)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black87))),
              child: Text(value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _JournalCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Icon(icon, size: 36, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 10),
            Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Color(0xFF6B7280), fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _SavingPill extends StatelessWidget {
  const _SavingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12)],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 7),
          Text('Сохранение…',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
