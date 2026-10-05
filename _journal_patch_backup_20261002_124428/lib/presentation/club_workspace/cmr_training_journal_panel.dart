import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  static const Color _green = Color(0xFF198754);
  static const Color _greenSoft = Color(0xFFEAF7F0);
  static const Color _ink = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _line = Color(0xFFE5E7EB);
  static const Color _canvas = Color(0xFFF6F7F8);

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _data = <String, dynamic>{};
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
    _load();
  }

  @override
  void didUpdateWidget(covariant CmrTrainingJournalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId ||
        oldWidget.clubId != widget.clubId) {
      _data = <String, dynamic>{};
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

  Map<String, dynamic> get _journal => _map(_data['journal']);
  Map<String, dynamic> get _club => _map(_data['club']);
  Map<String, dynamic> get _clubJournal => _map(_data['club_journal_profile']);
  Map<String, dynamic> get _team => _map(_data['team']);
  List<Map<String, dynamic>> get _trainers => _list(_data['trainers']);
  List<Map<String, dynamic>> get _players => _list(_data['players']);
  List<Map<String, dynamic>> get _parents => _list(_data['parents']);
  List<Map<String, dynamic>> get _curriculum => _list(_data['curriculum']);
  List<Map<String, dynamic>> get _schedule => _list(_data['schedule']);
  List<Map<String, dynamic>> get _briefings => _list(_data['briefings']);
  List<Map<String, dynamic>> get _quality => _list(_data['quality_controls']);
  Map<String, dynamic> get _attendance => _map(_data['attendance']);
  List<Map<String, dynamic>> get _monthSnapshots =>
      _list(_data['month_snapshots']);

  int get _journalId => _int(_journal['id']);

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
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
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

    return Container(
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
    );
  }

  Widget _buildHeader() {
    final group = _text(_journal['group_type']);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
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
                  '${widget.teamName}${group.isEmpty ? '' : ' · $group'} · данные синхронизируются с модулями клуба',
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
            onTap: () => setState(() => _tab = index),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: active ? _greenSoft : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? _green : _line),
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

  String get _structuralUnit =>
      _text(_clubJournal['structural_unit_name']).isNotEmpty
          ? _text(_clubJournal['structural_unit_name'])
          : widget.teamName;

  String get _schoolName => _text(_clubJournal['school_name']).isNotEmpty
      ? _text(_clubJournal['school_name'])
      : 'Детско-юношеская спортивная школа';

  String get _sportName =>
      _text(_team['sport']).isNotEmpty ? _text(_team['sport']) : 'Футбол';

  String get _trainerNames => _trainers
      .map((e) => _text(e['full_name']))
      .where((e) => e.isNotEmpty)
      .join(', ');

  Widget _buildCover() {
    return _pageScroll([
      _SectionHeading(
        title: 'Титульный лист',
        subtitle:
            'Клуб, команда, тренеры и вид спорта подставляются автоматически. Специальные поля журнала можно настроить здесь.',
        action: OutlinedButton.icon(
          onPressed: _editMeta,
          icon: const Icon(Icons.edit_rounded, size: 17),
          label: const Text('Настроить'),
        ),
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
            _InfoPair('Команда', widget.teamName),
            _InfoPair('Вид спорта', _sportName),
            _InfoPair('Тренеры',
                _trainerNames.isEmpty ? 'Не назначены' : _trainerNames),
          ],
        ),
      ),
    ]);
  }

  Future<void> _editMeta() async {
    final legal = TextEditingController(text: _legalName);
    final unit = TextEditingController(text: _structuralUnit);
    final school = TextEditingController(text: _schoolName);
    final study = TextEditingController(text: _text(_journal['study_year']));
    final adjacent =
        TextEditingController(text: _text(_journal['adjacent_trainer_name']));
    var group = _text(_journal['group_type']);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Настройки титульного листа'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: legal,
                      decoration: const InputDecoration(
                          labelText:
                              'Полное наименование клуба / организации')),
                  TextField(
                      controller: unit,
                      decoration: const InputDecoration(
                          labelText: 'Структурное подразделение')),
                  TextField(
                      controller: school,
                      decoration: const InputDecoration(
                          labelText: 'Спортивная школа / подразделение')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value:
                        <String>['', 'НП', 'УТ', 'СПС', 'ВСМ'].contains(group)
                            ? group
                            : '',
                    decoration: const InputDecoration(labelText: 'Группа'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Не выбрано')),
                      DropdownMenuItem(value: 'НП', child: Text('НП')),
                      DropdownMenuItem(value: 'УТ', child: Text('УТ')),
                      DropdownMenuItem(value: 'СПС', child: Text('СПС')),
                      DropdownMenuItem(value: 'ВСМ', child: Text('ВСМ')),
                    ],
                    onChanged: (v) => setLocal(() => group = v ?? ''),
                  ),
                  TextField(
                      controller: study,
                      decoration:
                          const InputDecoration(labelText: 'Год обучения')),
                  TextField(
                      controller: adjacent,
                      decoration: const InputDecoration(
                          labelText: 'Тренер по смежной подготовке')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _post('save_meta', {
      'legal_name': legal.text.trim(),
      'structural_unit_name': unit.text.trim(),
      'school_name': school.text.trim(),
      'group_type': group,
      'study_year': study.text.trim(),
      'adjacent_trainer_name': adjacent.text.trim(),
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
    if (category.isEmpty) category = 'theory';
    final sourceHours = _map(item?['hours']);
    final controllers = <int, TextEditingController>{
      for (var m = 1; m <= 12; m++)
        m: TextEditingController(
            text: _number(_double(sourceHours['$m'] ?? sourceHours[m]))),
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
              item == null ? 'Новая строка учебного плана' : 'Учебный план'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                      controller: title,
                      decoration: const InputDecoration(
                          labelText: 'Содержание занятий')),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Раздел'),
                    items: const [
                      DropdownMenuItem(
                          value: 'theory',
                          child: Text('Теоретические занятия')),
                      DropdownMenuItem(value: 'gpp', child: Text('ОФП')),
                      DropdownMenuItem(value: 'spp', child: Text('СФП')),
                      DropdownMenuItem(
                          value: 'competition', child: Text('Соревнования')),
                    ],
                    onChanged: (v) => setLocal(() => category = v ?? 'theory'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _academicMonths().map((month) {
                      return SizedBox(
                        width: 104,
                        child: TextField(
                          controller: controllers[month.month],
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                              labelText: _monthShort(month.month),
                              suffixText: 'ч'),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (item != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context, false);
                  final ok = await _confirm('Удалить строку учебного плана?');
                  if (ok)
                    await _post('delete_curriculum_item',
                        {'item_id': _int(item['id'])});
                },
                child: const Text('Удалить',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сохранить')),
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
        for (var m = 1; m <= 12; m++) '$m': _double(controllers[m]!.text)
      },
    });
  }

  Widget _buildSchedule() {
    return _pageScroll([
      _SectionHeading(
        title: 'Раздел II. Расписание учебно-тренировочных занятий',
        subtitle:
            'Постоянные правила расписания команды. Изменения сохраняются как единый источник для цифрового журнала.',
        action: FilledButton.icon(
          onPressed: () => _editScheduleRule(null),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Добавить занятие'),
        ),
      ),
      const SizedBox(height: 14),
      if (_schedule.isEmpty)
        const _EmptyBlock(
          icon: Icons.calendar_today_outlined,
          title: 'Расписание ещё не задано',
          subtitle: 'Добавьте дни недели, время и место занятий.',
        )
      else
        ...List.generate(7, (index) {
          final weekday = index + 1;
          final rows =
              _schedule.where((e) => _int(e['weekday']) == weekday).toList();
          if (rows.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _JournalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_weekdayName(weekday),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...rows.map((row) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: _greenSoft,
                          child: Icon(Icons.schedule_rounded,
                              color: _green, size: 19),
                        ),
                        title: Text(
                            '${_time(row['start_time'])}${_text(row['end_time']).isEmpty ? '' : ' – ${_time(row['end_time'])}'}'),
                        subtitle: Text([
                          _text(row['location']),
                          _validity(row),
                          _text(row['note']),
                        ].where((e) => e.isNotEmpty).join(' · ')),
                        trailing: IconButton(
                          onPressed: () => _editScheduleRule(row),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      )),
                ],
              ),
            ),
          );
        }),
    ]);
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

  String _time(dynamic raw) {
    final value = _text(raw);
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  String _validity(Map<String, dynamic> row) {
    final from = _text(row['valid_from']);
    final to = _text(row['valid_to']);
    if (from.isEmpty && to.isEmpty) return '';
    return '${from.isEmpty ? '…' : from} — ${to.isEmpty ? '…' : to}';
  }

  Future<void> _editScheduleRule(Map<String, dynamic>? row) async {
    var weekday = _int(row?['weekday']);
    if (weekday < 1) weekday = 1;
    final start = TextEditingController(
        text: _time(row?['start_time']).isEmpty
            ? '17:00'
            : _time(row?['start_time']));
    final end = TextEditingController(text: _time(row?['end_time']));
    final location = TextEditingController(text: _text(row?['location']));
    final note = TextEditingController(text: _text(row?['note']));
    final from = TextEditingController(text: _text(row?['valid_from']));
    final to = TextEditingController(text: _text(row?['valid_to']));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
              row == null ? 'Добавить занятие' : 'Редактировать расписание'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: weekday,
                    decoration: const InputDecoration(labelText: 'День недели'),
                    items: [
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem(value: d, child: Text(_weekdayName(d)))
                    ],
                    onChanged: (v) => setLocal(() => weekday = v ?? 1),
                  ),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: start,
                            decoration: const InputDecoration(
                                labelText: 'Начало HH:MM'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: end,
                            decoration: const InputDecoration(
                                labelText: 'Окончание HH:MM'))),
                  ]),
                  TextField(
                      controller: location,
                      decoration: const InputDecoration(labelText: 'Место')),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: from,
                            decoration: const InputDecoration(
                                labelText: 'Действует с YYYY-MM-DD'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: to,
                            decoration: const InputDecoration(
                                labelText: 'до YYYY-MM-DD'))),
                  ]),
                  TextField(
                      controller: note,
                      decoration:
                          const InputDecoration(labelText: 'Примечание')),
                ],
              ),
            ),
          ),
          actions: [
            if (row != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context, false);
                  if (await _confirm('Удалить правило расписания?')) {
                    await _post(
                        'delete_schedule_rule', {'id': _int(row['id'])});
                  }
                },
                child: const Text('Удалить',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _post('save_schedule_rule', {
      if (row != null) 'id': _int(row['id']),
      'weekday': weekday,
      'start_time': start.text.trim(),
      'end_time': end.text.trim(),
      'location': location.text.trim(),
      'valid_from': from.text.trim(),
      'valid_to': to.text.trim(),
      'note': note.text.trim(),
    });
  }

  Widget _buildAttendance() {
    final days =
        DateUtils.getDaysInMonth(_attendanceMonth.year, _attendanceMonth.month);
    final closed = _monthIsClosed(_attendanceMonth);
    return _pageScroll([
      _SectionHeading(
        title: 'Раздел III. Учебно-тренировочный процесс',
        subtitle:
            'Игроки × дни месяца. Пустая ячейка остаётся пустой: отсутствие отметки больше не считается присутствием автоматически.',
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
      ..._players.map((player) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _playerCard(player),
          )),
    ]);
  }

  Widget _playerCard(Map<String, dynamic> player) {
    final playerId = _int(player['id']);
    final jp = _map(player['journal_profile']);
    final med = _map(player['medical_summary']);
    final parent = _parentForPlayer(playerId);
    final pp = _map(parent?['journal_profile']);
    final briefing = _latestBriefing(playerId);
    final school = [
      _text(jp['institution_name']),
      _text(jp['class_name']),
    ].where((e) => e.isNotEmpty).join(' · ');
    return _JournalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _greenSoft,
                child: Text(_initials(_text(player['full_name'])),
                    style: const TextStyle(
                        color: _green, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_text(player['full_name']),
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                        [
                          if (_text(player['birth_date']).isNotEmpty)
                            'р. ${_text(player['birth_date'])}',
                          if (_text(player['position']).isNotEmpty)
                            _text(player['position']),
                          if (_text(player['jersey_number']).isNotEmpty)
                            '№ ${_text(player['jersey_number'])}',
                        ].join(' · '),
                        style: const TextStyle(color: _muted, fontSize: 12.5)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                  onPressed: () => _editPlayer(player),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Данные')),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'pre')
                    _saveMedicalExam(player, 'preliminary_exam');
                  if (value == 'periodic')
                    _saveMedicalExam(player, 'periodic_exam');
                  if (value == 'briefing') _saveBriefing(player);
                  if (value == 'parent' && parent != null) _editParent(parent);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'pre', child: Text('Предварительный медосмотр')),
                  const PopupMenuItem(
                      value: 'periodic',
                      child: Text('Периодический медосмотр')),
                  const PopupMenuItem(
                      value: 'briefing',
                      child: Text('Инструктаж по безопасности')),
                  if (parent != null)
                    const PopupMenuItem(
                        value: 'parent', child: Text('Сведения о родителе')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 22,
            runSpacing: 12,
            children: [
              _InfoPair(
                  'Зачисление',
                  _text(jp['enrollment_date']).isEmpty
                      ? '—'
                      : _text(jp['enrollment_date'])),
              _InfoPair(
                  'Разряд',
                  _text(jp['sport_rank']).isEmpty
                      ? '—'
                      : _text(jp['sport_rank'])),
              _InfoPair('Форма / обувь',
                  '${_text(jp['uniform_size']).isEmpty ? '—' : _text(jp['uniform_size'])} / ${_text(jp['shoe_size']).isEmpty ? '—' : _text(jp['shoe_size'])}'),
              _InfoPair('Учёба', school.isEmpty ? '—' : school),
              _InfoPair(
                  'Предв. медосмотр',
                  _text(med['preliminary_exam_date']).isEmpty
                      ? '—'
                      : _text(med['preliminary_exam_date'])),
              _InfoPair(
                  'Период. медосмотр',
                  _text(med['periodic_exam_date']).isEmpty
                      ? '—'
                      : _text(med['periodic_exam_date'])),
              _InfoPair('Родитель',
                  parent == null ? '—' : _text(parent['full_name'])),
              _InfoPair(
                  'Работа родителя',
                  parent == null
                      ? '—'
                      : [_text(pp['occupation']), _text(pp['work_phone'])]
                          .where((e) => e.isNotEmpty)
                          .join(' · ')),
              _InfoPair(
                  'Инструктаж',
                  briefing == null
                      ? '—'
                      : '${_text(briefing['briefing_date'])}${_text(briefing['trainer_signed_at']).isEmpty ? '' : ' · тренер ✓'}'),
            ],
          ),
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
    TextEditingController c(String key) =>
        TextEditingController(text: _text(jp[key]));
    final enrollment = c('enrollment_date');
    final rank = c('sport_rank');
    final uniform = c('uniform_size');
    final shoe = c('shoe_size');
    final institution = c('institution_name');
    final className = c('class_name');
    final institutionAddress = c('institution_address');
    final study = c('study_or_work');
    final homeAddress = c('home_address');
    final homePhone = c('home_phone');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text(player['full_name'])),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: enrollment,
                          decoration: const InputDecoration(
                              labelText: 'Дата зачисления YYYY-MM-DD'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: rank,
                          decoration: const InputDecoration(
                              labelText: 'Спортивный разряд')))
                ]),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: uniform,
                          decoration: const InputDecoration(
                              labelText: 'Размер формы'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: shoe,
                          decoration:
                              const InputDecoration(labelText: 'Размер обуви')))
                ]),
                TextField(
                    controller: institution,
                    decoration: const InputDecoration(
                        labelText: 'Учреждение образования / организация')),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: className,
                          decoration:
                              const InputDecoration(labelText: 'Класс'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: study,
                          decoration: const InputDecoration(
                              labelText: 'Место учёбы / работы')))
                ]),
                TextField(
                    controller: institutionAddress,
                    decoration:
                        const InputDecoration(labelText: 'Адрес учреждения')),
                TextField(
                    controller: homeAddress,
                    decoration:
                        const InputDecoration(labelText: 'Домашний адрес')),
                TextField(
                    controller: homePhone,
                    decoration:
                        const InputDecoration(labelText: 'Домашний телефон')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить')),
        ],
      ),
    );
    if (saved != true) return;
    await _post('save_player_profile', {
      'player_id': _int(player['id']),
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
    final occupation = c('occupation');
    final workplace = c('workplace');
    final workPhone = c('work_phone');
    final homeAddress = c('home_address');
    final homePhone = c('home_phone');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Родитель: ${_text(parent['full_name'])}'),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: occupation,
                decoration:
                    const InputDecoration(labelText: 'Должность / профессия')),
            TextField(
                controller: workplace,
                decoration: const InputDecoration(labelText: 'Место работы')),
            TextField(
                controller: workPhone,
                decoration:
                    const InputDecoration(labelText: 'Рабочий телефон')),
            TextField(
                controller: homeAddress,
                decoration: const InputDecoration(labelText: 'Домашний адрес')),
            TextField(
                controller: homePhone,
                decoration:
                    const InputDecoration(labelText: 'Домашний телефон')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить')),
        ],
      ),
    );
    if (saved != true) return;
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'preliminary_exam'
            ? 'Предварительный медосмотр'
            : 'Периодический медосмотр'),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Дата YYYY-MM-DD')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить')),
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
            'Инструктаж по безопасности проведения занятий физической культурой и спортом');
    var playerSigned = false;
    var trainerSigned = true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Инструктаж: ${_text(player['full_name'])}'),
          content: SizedBox(
            width: 560,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: date,
                  decoration:
                      const InputDecoration(labelText: 'Дата YYYY-MM-DD')),
              TextField(
                  controller: type,
                  decoration:
                      const InputDecoration(labelText: 'Вид инструктажа'),
                  maxLines: 2),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: playerSigned,
                  onChanged: (v) => setLocal(() => playerSigned = v ?? false),
                  title: const Text('Подпись спортсмена подтверждена')),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: trainerSigned,
                  onChanged: (v) => setLocal(() => trainerSigned = v ?? false),
                  title: const Text('Подпись тренера подтверждена')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сохранить')),
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
        action: FilledButton.icon(
          onPressed: () => _editQuality(null),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Добавить запись'),
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
            : _text(row?['control_date']));
    final title = TextEditingController(text: _text(row?['title']));
    final assessment =
        TextEditingController(text: _text(row?['quality_assessment']));
    final count =
        TextEditingController(text: '${_int(row?['participants_count'])}');
    final responsible = TextEditingController(
        text: _text(row?['responsible_name']).isEmpty
            ? _trainerNames.split(',').firstOrNull ?? ''
            : _text(row?['responsible_name']));
    var signed = _text(row?['signed_at']).isNotEmpty;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Самоконтроль качества'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(children: [
                TextField(
                    controller: date,
                    decoration:
                        const InputDecoration(labelText: 'Дата YYYY-MM-DD')),
                TextField(
                    controller: title,
                    decoration: const InputDecoration(
                        labelText: 'Наименование мероприятия')),
                TextField(
                    controller: assessment,
                    decoration:
                        const InputDecoration(labelText: 'Оценка качества'),
                    maxLines: 4),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: count,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Количество участников'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: responsible,
                          decoration: const InputDecoration(
                              labelText: 'Ответственное лицо')))
                ]),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: signed,
                    onChanged: (v) => setLocal(() => signed = v ?? false),
                    title: const Text('Подпись / подтверждение')),
              ]),
            ),
          ),
          actions: [
            if (row != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context, false);
                  if (await _confirm('Удалить запись самоконтроля?')) {
                    await _post(
                        'delete_quality_control', {'id': _int(row['id'])});
                  }
                },
                child: const Text('Удалить',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сохранить')),
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
        action: FilledButton.icon(
          onPressed: _journalId <= 0 ? null : _openPrintable,
          icon: const Icon(Icons.print_rounded, size: 18),
          label: const Text('Печать / PDF'),
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
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text('${s.mark} — ${s.title}',
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF4B5563))),
              ))
          .toList(),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 8))
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 12)],
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
