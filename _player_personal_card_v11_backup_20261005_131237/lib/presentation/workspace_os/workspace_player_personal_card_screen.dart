import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_player_data_bridge.dart';

class WorkspacePlayerPersonalCardScreen extends StatefulWidget {
  const WorkspacePlayerPersonalCardScreen({
    super.key,
    required this.player,
    required this.clubId,
    this.teamId,
    this.teamName = '',
    this.currentUserId = 0,
    this.onRefresh,
  });

  final Map<String, dynamic> player;
  final int clubId;
  final int? teamId;
  final String teamName;
  final int currentUserId;
  final Future<void> Function()? onRefresh;

  @override
  State<WorkspacePlayerPersonalCardScreen> createState() =>
      _WorkspacePlayerPersonalCardScreenState();
}

class _WorkspacePlayerPersonalCardScreenState
    extends State<WorkspacePlayerPersonalCardScreen> {
  static const _api = 'https://sportotekaapp.ru/api/player_card';
  static const _green = Color(0xFF0B8F55);
  static const _greenSoft = Color(0xFFF2F8F5);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);
  static const _soft = Color(0xFFF7F8F7);
  static const _danger = Color(0xFFB42318);

  final _bridge = WorkspacePlayerDataBridge();
  bool _loading = true;
  bool _syncing = false;
  bool _exporting = false;
  String? _error;
  Map<String, dynamic> _data = <String, dynamic>{};

  int get _playerId => _bridge.resolvePlayerId(widget.player);
  int get _teamId => _bridge.resolveTeamId(widget.player, widget.teamId);
  Map<String, dynamic> get _resolved => _map(_data['resolved']);
  List<Map<String, dynamic>> get _tests => _list(_data['tests']);
  List<Map<String, dynamic>> get _results => _list(_data['results']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _map(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  List<Map<String, dynamic>> _list(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  String _t(dynamic value) {
    final s = '${value ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  String _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = _t(row[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _ymd(dynamic value) {
    final raw = _t(value);
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }

  String get _playerName {
    final name = _t(_resolved['full_name']);
    if (name.isNotEmpty) return name;
    final last = _first(widget.player, const ['last_name', 'lastname']);
    final first = _first(widget.player, const ['first_name', 'firstname']);
    return '$last $first'.trim().isEmpty ? 'Игрок' : '$last $first'.trim();
  }

  Uri _uri(String path, [Map<String, String>? extra]) {
    return Uri.parse('$_api/$path').replace(queryParameters: <String, String>{
      'player_id': '$_playerId',
      'club_id': '${widget.clubId}',
      if (_teamId > 0) 'team_id': '$_teamId',
      if (widget.currentUserId > 0) 'user_id': '${widget.currentUserId}',
      ...?extra,
    });
  }

  Future<void> _load({bool syncSources = true}) async {
    if (_playerId <= 0) {
      setState(() {
        _loading = false;
        _error = 'Не удалось определить player_id';
      });
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await http
          .get(_uri('index.php', const {'action': 'bootstrap'}))
          .timeout(const Duration(seconds: 25));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['success'] != true) {
        throw StateError(
            '${decoded is Map ? decoded['message'] : 'Ошибка API'}');
      }
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(decoded);
        _loading = false;
      });
      if (syncSources) await _syncFromSportoteka();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<Map<String, dynamic>> _post(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final response = await http
        .post(
          _uri('index.php'),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(<String, dynamic>{
            'action': action,
            'player_id': _playerId,
            'club_id': widget.clubId,
            'team_id': _teamId,
            'user_id': widget.currentUserId,
            ...payload,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['success'] != true) {
      throw StateError('${decoded is Map ? decoded['message'] : 'Ошибка API'}');
    }
    final result = Map<String, dynamic>.from(decoded);
    if (mounted) setState(() => _data = result);
    return result;
  }

  bool _matchBelongsToPlayer(Map<String, dynamic> row) {
    final playerIds = <int>{
      _playerId,
      int.tryParse(_t(_resolved['user_id'])) ?? 0,
    }..remove(0);
    if (playerIds.isEmpty) return false;
    for (final key in const <String>[
      'player_id',
      'footballer_id',
      'athlete_id',
      'user_id',
      'playerId',
      'player_user_id',
      'member_id',
    ]) {
      final id = int.tryParse(_t(row[key])) ?? 0;
      if (playerIds.contains(id)) return true;
    }
    for (final raw in <dynamic>[
      row['players'],
      row['participants'],
      row['lineup'],
      row['squad'],
      row['roster'],
      row['player_ids'],
      row['participant_ids'],
    ]) {
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final id = int.tryParse(_first(
                    Map<String, dynamic>.from(item), const [
                  'player_id',
                  'footballer_id',
                  'athlete_id',
                  'user_id',
                  'id'
                ])) ??
                0;
            if (playerIds.contains(id)) return true;
          } else {
            final id = int.tryParse('$item') ?? 0;
            if (playerIds.contains(id)) return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> _syncFromSportoteka() async {
    if (_syncing || _teamId <= 0) return;
    setState(() => _syncing = true);
    try {
      final testRows = <Map<String, dynamic>>[];
      final sessions = await _bridge.loadTestingSessions(
        player: widget.player,
        clubId: widget.clubId,
        teamId: _teamId,
      );
      final selectedSessions = sessions.take(12).toList(growable: false);
      for (var i = 0; i < selectedSessions.length; i++) {
        final session = selectedSessions[i];
        final enriched = await _bridge.enrichTestingSessionForPlayer(
          player: widget.player,
          clubId: widget.clubId,
          teamId: _teamId,
          session: session,
        );
        final sessionId = _first(enriched, const ['session_id', 'id']);
        final date =
            _ymd(_first(enriched, const ['test_date', 'date', 'created_at']));
        final metrics = _list(enriched['workspace_results']);
        for (var j = 0; j < metrics.length; j++) {
          final metric = metrics[j];
          final code = _first(metric, const ['code', 'id']);
          final title = _first(metric, const ['title', 'name', 'code']);
          final value = _first(metric, const ['value', 'result', 'score']);
          final unit = _t(metric['unit']);
          final rating = _first(metric, const ['rating', 'status']);
          final rendered = <String>[
            '$value${unit.isEmpty ? '' : ' $unit'}'.trim(),
            if (rating.isNotEmpty) rating,
          ].where((e) => e.isNotEmpty).join(' · ');
          if (title.isEmpty || rendered.isEmpty) continue;
          testRows.add(<String, dynamic>{
            'source_key':
                'testing:${sessionId.isEmpty ? '$date:$i' : sessionId}:${code.isEmpty ? j : code}',
            'test_date': date,
            'title': title,
            'result': rendered,
            'sort_order': i * 100 + j,
          });
        }
      }

      final resultRows = <Map<String, dynamic>>[];
      final matches = await _bridge.loadTeamMatches(
        player: widget.player,
        teamId: _teamId,
      );
      final playerMatches =
          matches.where(_matchBelongsToPlayer).take(30).toList();
      for (var i = 0; i < playerMatches.length; i++) {
        final match = playerMatches[i];
        final id = _first(match, const ['match_id', 'id', 'event_id']);
        final date = _ymd(_first(
          match,
          const [
            'match_date',
            'date',
            'event_date',
            'scheduled_at',
            'start_at'
          ],
        ));
        final opponent = _first(
          match,
          const ['opponent', 'opponent_name', 'opponent_team', 'rival_name'],
        );
        final competition = _first(
          match,
          const [
            'competition_name',
            'tournament_name',
            'competition',
            'league_name'
          ],
        );
        final name = competition.isNotEmpty
            ? competition
            : (opponent.isNotEmpty ? 'Матч — $opponent' : 'Матч');
        final city = _first(match, const ['city', 'location', 'place']);
        final country = _first(match, const ['country', 'country_name']);
        final our = _first(match,
            const ['our_score', 'team_score', 'score_for', 'home_score']);
        final opp = _first(
            match, const ['opponent_score', 'score_against', 'away_score']);
        final score = our.isNotEmpty && opp.isNotEmpty
            ? '$our:$opp'
            : _first(match, const ['result', 'score']);
        resultRows.add(<String, dynamic>{
          'source_key': 'match:${id.isEmpty ? '$date:$i:$opponent' : id}',
          'competition_name': name,
          'event_date': date,
          'city_country': <String>[city, country]
              .where((e) => e.isNotEmpty)
              .toSet()
              .join(', '),
          'sport_program': _t(_resolved['sport_program']),
          'result': score,
          'place':
              _first(match, const ['place', 'position_place', 'final_place']),
          'rank_info': _first(match, const ['rank_info', 'sport_rank', 'rank']),
          'national_team':
              _first(match, const ['national_team', 'national_team_status']),
          'sort_order': i,
        });
      }

      await _post('sync_sources', <String, dynamic>{
        'tests': testRows,
        'results': resultRows,
      });
    } catch (_) {
      // Карточка остаётся доступной даже если один из старых модулей тестов/матчей
      // на конкретном сервере не отвечает.
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _editMeta() async {
    final r = _resolved;
    final fields = <_CardFieldDef>[
      _CardFieldDef('middle_name', 'Отчество', _t(r['middle_name'])),
      _CardFieldDef('birth_place', 'Место рождения', _t(r['birth_place'])),
      _CardFieldDef(
          'identity_doc_name', 'Документ', _t(r['identity_doc_name'])),
      _CardFieldDef(
          'identity_doc_series', 'Серия', _t(r['identity_doc_series'])),
      _CardFieldDef(
          'identity_doc_number', 'Номер', _t(r['identity_doc_number'])),
      _CardFieldDef('identity_doc_issue_date', 'Дата выдачи YYYY-MM-DD',
          _t(r['identity_doc_issue_date'])),
      _CardFieldDef('identity_doc_issuer_code', 'Код органа',
          _t(r['identity_doc_issuer_code'])),
      _CardFieldDef('identity_doc_issuer_name', 'Кем выдан',
          _t(r['identity_doc_issuer_name']),
          lines: 2),
      _CardFieldDef('study_work_position', 'Профессия / должность',
          _t(r['study_work_position'])),
      _CardFieldDef('education', 'Образование', _t(r['education']), lines: 2),
      _CardFieldDef('enrollment_order_number', 'Номер приказа о зачислении',
          _t(r['enrollment_order_number'])),
      _CardFieldDef(
          'transfer_info', 'Перевод / направление', _t(r['transfer_info']),
          lines: 2),
      _CardFieldDef('restoration_info', 'Восстановление / зачисление в группу',
          _t(r['restoration_info']),
          lines: 2),
      _CardFieldDef('training_institution', 'Учреждение спортивной подготовки',
          _t(r['training_institution']),
          lines: 2),
      _CardFieldDef('training_coaches_text',
          'Тренеры, обеспечивавшие подготовку', _t(r['training_coaches_text']),
          lines: 2),
      _CardFieldDef('personal_trainer_name', 'Личный тренер',
          _t(r['personal_trainer_name'])),
      _CardFieldDef('preparation_duration', 'Продолжительность подготовки',
          _t(r['preparation_duration']),
          lines: 2),
      _CardFieldDef('preparation_funding', 'Источник финансирования',
          _t(r['preparation_funding'])),
      _CardFieldDef(
          'sport_program', 'Вид спорта / программа', _t(r['sport_program'])),
      _CardFieldDef(
          'judging_category', 'Судейская категория', _t(r['judging_category']),
          lines: 2),
      _CardFieldDef('director_name', 'Директор', _t(r['director_name'])),
    ];
    final controllers = <String, TextEditingController>{
      for (final f in fields) f.key: TextEditingController(text: f.value),
    };
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 760,
          constraints: const BoxConstraints(maxHeight: 820),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Редактировать личную карточку',
                          style: AppTypography.screenTitle(color: _text)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _line),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: fields.map((f) {
                      final wide = f.lines > 1;
                      return SizedBox(
                        width: wide ? 716 : 350,
                        child: _SoftField(
                          controller: controllers[f.key]!,
                          label: f.label,
                          maxLines: f.lines,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: _greenButtonStyle(),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (save != true) {
      for (final c in controllers.values) c.dispose();
      return;
    }
    final payload = <String, dynamic>{
      for (final f in fields) f.key: controllers[f.key]!.text.trim(),
    };
    for (final c in controllers.values) c.dispose();
    try {
      await _post('save_meta', payload);
      if (mounted) _snack('Личная карточка сохранена');
    } catch (e) {
      if (mounted) _snack('Не удалось сохранить: $e', error: true);
    }
  }

  ButtonStyle _greenButtonStyle() => FilledButton.styleFrom(
        backgroundColor: _greenSoft,
        foregroundColor: _green,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );

  Future<Uint8List> _fetchExport(String type) async {
    final response = await http
        .get(_uri(type == 'pdf' ? 'export_pdf.php' : 'export_docx.php'))
        .timeout(const Duration(seconds: 90));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'Сервер вернул ${response.statusCode}: ${response.body}');
    }
    return response.bodyBytes;
  }

  String _safeFileBase() {
    final n =
        _playerName.replaceAll(RegExp(r'[^A-Za-zА-Яа-яЁё0-9 _-]'), '').trim();
    return 'Личная карточка спортсмена ${n.isEmpty ? _playerId : n}';
  }

  Future<void> _openPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _fetchExport('pdf');
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFFF3F4F3),
            appBar: AppBar(
              title: Text(_safeFileBase(), style: AppTypography.itemTitle()),
            ),
            body: SfPdfViewer.memory(bytes),
          ),
        ),
      );
    } catch (e) {
      if (mounted) _snack('PDF не открылся: $e', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveExport(String type) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _fetchExport(type);
      final ext = type == 'pdf' ? 'pdf' : 'docx';
      final path = await FilePicker.saveFile(
        dialogTitle: type == 'pdf' ? 'Сохранить PDF' : 'Сохранить DOCX',
        fileName: '${_safeFileBase()}.$ext',
        type: FileType.custom,
        allowedExtensions: <String>[ext],
      );
      if (path == null || path.trim().isEmpty) return;
      await File(path).writeAsBytes(bytes, flush: true);
      if (mounted) _snack('${ext.toUpperCase()} сохранён');
    } catch (e) {
      if (mounted) _snack('Не удалось сохранить: $e', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveToPlayerDocuments() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    Directory? temp;
    try {
      final pdf = await _fetchExport('pdf');
      final docx = await _fetchExport('docx');
      temp = await Directory.systemTemp.createTemp('sportoteka_player_card_');
      final base = _safeFileBase();
      final pdfFile = File('${temp.path}/$base.pdf');
      final docxFile = File('${temp.path}/$base.docx');
      await pdfFile.writeAsBytes(pdf, flush: true);
      await docxFile.writeAsBytes(docx, flush: true);
      for (final item in <(File, String)>[
        (pdfFile, 'PDF'),
        (docxFile, 'DOCX')
      ]) {
        final file = PlatformFile(
          name: item.$1.path.split(Platform.pathSeparator).last,
          size: await item.$1.length(),
          path: item.$1.path,
        );
        await _bridge.uploadMedicalAttachment(
          player: widget.player,
          file: file,
          title: '$base · ${item.$2}',
          type: 'Документ',
          comment:
              'Сформировано из цифровой личной карточки спортсмена Sportoteka',
          date: DateTime.now(),
        );
      }
      await widget.onRefresh?.call();
      if (mounted) _snack('PDF и DOCX добавлены в документы игрока');
    } catch (e) {
      if (mounted) _snack('Не удалось добавить в документы: $e', error: true);
    } finally {
      if (temp != null) {
        try {
          await temp.delete(recursive: true);
        } catch (_) {}
      }
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _addTest() async {
    final date = TextEditingController();
    final title = TextEditingController();
    final result = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('Добавить норматив',
            style: AppTypography.sectionTitle(color: _text)),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SoftField(controller: date, label: 'Дата YYYY-MM-DD'),
              const SizedBox(height: 10),
              _SoftField(controller: title, label: 'Вид норматива'),
              const SizedBox(height: 10),
              _SoftField(controller: result, label: 'Результат'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена')),
          FilledButton(
            style: _greenButtonStyle(),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      try {
        await _post('save_test', <String, dynamic>{
          'test_date': date.text.trim(),
          'title': title.text.trim(),
          'result': result.text.trim(),
        });
      } catch (e) {
        if (mounted) _snack('Не удалось добавить норматив: $e', error: true);
      }
    }
    date.dispose();
    title.dispose();
    result.dispose();
  }

  Future<void> _addResult() async {
    final fields = <_CardFieldDef>[
      const _CardFieldDef('competition_name', 'Соревнование', ''),
      const _CardFieldDef('event_date', 'Дата YYYY-MM-DD', ''),
      const _CardFieldDef('city_country', 'Город / страна', ''),
      _CardFieldDef(
          'sport_program', 'Вид спорта', _t(_resolved['sport_program'])),
      const _CardFieldDef('result', 'Спортивный результат', ''),
      const _CardFieldDef('place', 'Место', ''),
      const _CardFieldDef('rank_info', 'Присвоение звания / разряда', '',
          lines: 2),
      const _CardFieldDef('national_team', 'Сборная команда', '', lines: 2),
    ];
    final controllers = <String, TextEditingController>{
      for (final f in fields) f.key: TextEditingController(text: f.value),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 680,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Добавить спортивный результат',
                  style: AppTypography.sectionTitle(color: _text)),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: fields
                        .map((f) => SizedBox(
                              width: f.lines > 1 ? 640 : 314,
                              child: _SoftField(
                                  controller: controllers[f.key]!,
                                  label: f.label,
                                  maxLines: f.lines),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Отмена')),
                  const SizedBox(width: 8),
                  FilledButton(
                      style: _greenButtonStyle(),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Добавить')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && controllers['competition_name']!.text.trim().isNotEmpty) {
      try {
        await _post('save_result', <String, dynamic>{
          for (final f in fields) f.key: controllers[f.key]!.text.trim(),
        });
      } catch (e) {
        if (mounted) _snack('Не удалось добавить результат: $e', error: true);
      }
    }
    for (final c in controllers.values) c.dispose();
  }

  Future<void> _captureSignature() async {
    final signature = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AthleteSignatureDialog(name: _playerName),
    );
    if (signature == null) return;
    try {
      await _post('save_signature', <String, dynamic>{
        'signature_json': signature,
        'athlete_signature_name': _playerName,
      });
      if (mounted) _snack('Подпись спортсмена сохранена');
    } catch (e) {
      if (mounted) _snack('Не удалось сохранить подпись: $e', error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _danger : _green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1, color: _line),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFF3F1),
              child:
                  Text(_error!, style: AppTypography.caption(color: _danger)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _green))
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Назад',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Личная карточка спортсмена',
                    style: AppTypography.sectionTitle(color: _text)),
                const SizedBox(height: 2),
                Text('$_playerName · Документы игрока',
                    style: AppTypography.caption(color: _muted)),
              ],
            ),
          ),
          if (_syncing || _exporting)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _green),
              ),
            ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Action(
                icon: Icons.edit_outlined,
                label: 'Редактировать',
                onTap: _editMeta),
            _Action(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Открыть PDF',
                onTap: _openPdf),
            _Action(
                icon: Icons.save_alt_rounded,
                label: 'Сохранить PDF',
                onTap: () => _saveExport('pdf')),
            _Action(
                icon: Icons.description_outlined,
                label: 'Сохранить DOCX',
                onTap: () => _saveExport('docx')),
            _Action(
                icon: Icons.folder_special_outlined,
                label: 'В документы игрока',
                onTap: _saveToPlayerDocuments),
          ],
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: 'Основные данные',
          icon: Icons.badge_outlined,
          child: Wrap(
            spacing: 22,
            runSpacing: 14,
            children: [
              _Info('ФИО', _playerName, width: 300),
              _Info('Дата рождения', _t(_resolved['birth_date'])),
              _Info('Место рождения', _t(_resolved['birth_place']), width: 260),
              _Info('Телефон', _t(_resolved['phone'])),
              _Info('Учёба / работа', _t(_resolved['study_work']), width: 300),
              _Info('Образование', _t(_resolved['education']), width: 300),
              _Info('Родители', _t(_resolved['parents_text']), width: 600),
              _Info(
                  'Зачисление',
                  <String>[
                    _t(_resolved['enrollment_order_number']).isEmpty
                        ? ''
                        : 'пр. № ${_t(_resolved['enrollment_order_number'])}',
                    _t(_resolved['enrollment_date']),
                  ].where((e) => e.isNotEmpty).join(' · '),
                  width: 300),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Спортивная подготовка',
          icon: Icons.sports_soccer_rounded,
          child: Wrap(
            spacing: 22,
            runSpacing: 14,
            children: [
              _Info('Учреждение', _t(_resolved['training_institution']),
                  width: 360),
              _Info('Тренеры', _t(_resolved['training_coaches_text']),
                  width: 360),
              _Info('Личный тренер', _t(_resolved['personal_trainer_name']),
                  width: 300),
              _Info('Продолжительность', _t(_resolved['preparation_duration']),
                  width: 300),
              _Info('Финансирование', _t(_resolved['preparation_funding']),
                  width: 260),
              _Info('Вид спорта', _t(_resolved['sport_program'])),
              _Info('Судейская категория', _t(_resolved['judging_category']),
                  width: 300),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _dataTableCard(
          title: 'Контрольно-переводные нормативы',
          icon: Icons.fact_check_outlined,
          onAdd: _addTest,
          columns: const ['Дата', 'Норматив', 'Результат', 'Источник'],
          rows: _tests
              .map((row) => <String>[
                    _t(row['test_date']),
                    _t(row['title']),
                    _t(row['result']),
                    _t(row['source']) == 'testing' ? 'Тестирование' : 'Вручную',
                  ])
              .toList(),
        ),
        const SizedBox(height: 12),
        _dataTableCard(
          title: 'Спортивные результаты',
          icon: Icons.emoji_events_outlined,
          onAdd: _addResult,
          columns: const [
            'Соревнование',
            'Дата',
            'Город',
            'Вид спорта',
            'Результат',
            'Место'
          ],
          rows: _results
              .map((row) => <String>[
                    _t(row['competition_name']),
                    _t(row['event_date']),
                    _t(row['city_country']),
                    _t(row['sport_program']),
                    _t(row['result']),
                    _t(row['place']),
                  ])
              .toList(),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Подпись спортсмена',
          icon: Icons.draw_rounded,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _t(_resolved['athlete_signed_at']).isEmpty
                      ? 'Подпись ещё не добавлена'
                      : 'Подписано: ${_t(_resolved['athlete_signed_at'])}',
                  style: AppTypography.body(color: _muted),
                ),
              ),
              FilledButton.icon(
                style: _greenButtonStyle(),
                onPressed: _captureSignature,
                icon: const Icon(Icons.draw_rounded, size: 17),
                label: Text(_t(_resolved['athlete_signed_at']).isEmpty
                    ? 'Подписать'
                    : 'Переподписать'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: _greenSoft, borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: _green, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: AppTypography.itemTitle(color: _text)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _dataTableCard({
    required String title,
    required IconData icon,
    required List<String> columns,
    required List<List<String>> rows,
    VoidCallback? onAdd,
  }) {
    final content = rows.isEmpty
        ? Text('Данных пока нет', style: AppTypography.body(color: _muted))
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(_greenSoft),
              dividerThickness: .6,
              columns: columns
                  .map((c) => DataColumn(
                        label: Text(
                          c,
                          style: AppTypography.captionMedium(color: _green),
                        ),
                      ))
                  .toList(),
              rows: rows
                  .map((row) => DataRow(
                        cells: row
                            .map((cell) => DataCell(Text(
                                  cell.isEmpty ? '—' : cell,
                                  style: AppTypography.caption(color: _text),
                                )))
                            .toList(),
                      ))
                  .toList(),
            ),
          );
    return _sectionCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onAdd != null) ...[
            Align(
              alignment: Alignment.centerRight,
              child: _Action(
                icon: Icons.add_rounded,
                label: 'Добавить',
                onTap: onAdd,
              ),
            ),
            const SizedBox(height: 10),
          ],
          content,
        ],
      ),
    );
  }
}

class _CardFieldDef {
  const _CardFieldDef(this.key, this.label, this.value, {this.lines = 1});
  final String key;
  final String label;
  final String value;
  final int lines;
}

class _SoftField extends StatelessWidget {
  const _SoftField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label,
              style: AppTypography.captionMedium(
                  color: _WorkspacePlayerPersonalCardScreenState._muted)),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: AppTypography.body(
              color: _WorkspacePlayerPersonalCardScreenState._text),
          decoration: InputDecoration(
            filled: true,
            fillColor: _WorkspacePlayerPersonalCardScreenState._soft,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(
                color: _WorkspacePlayerPersonalCardScreenState._green,
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _WorkspacePlayerPersonalCardScreenState._greenSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 17,
                  color: _WorkspacePlayerPersonalCardScreenState._green),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTypography.actionStrong(
                      color: _WorkspacePlayerPersonalCardScreenState._green)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value, {this.width = 220});
  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.captionMedium(
                  color: _WorkspacePlayerPersonalCardScreenState._muted)),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? '—' : value.trim(),
            style: AppTypography.bodyMedium(
                color: _WorkspacePlayerPersonalCardScreenState._text),
          ),
        ],
      ),
    );
  }
}

class _AthleteSignatureDialog extends StatefulWidget {
  const _AthleteSignatureDialog({required this.name});
  final String name;

  @override
  State<_AthleteSignatureDialog> createState() =>
      _AthleteSignatureDialogState();
}

class _AthleteSignatureDialogState extends State<_AthleteSignatureDialog> {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  Size _size = Size.zero;

  void _start(DragStartDetails d) {
    if (_size.width <= 0 || _size.height <= 0) return;
    setState(() => _strokes.add(<Offset>[d.localPosition]));
  }

  void _update(DragUpdateDetails d) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(d.localPosition));
  }

  String _json() {
    if (_size.width <= 0 || _size.height <= 0) return '[]';
    return jsonEncode(_strokes
        .map((stroke) => stroke
            .map((p) => <double>[
                  (p.dx / _size.width).clamp(0.0, 1.0),
                  (p.dy / _size.height).clamp(0.0, 1.0),
                ])
            .toList())
        .toList());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 660,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Подпись спортсмена',
                style: AppTypography.sectionTitle(
                    color: _WorkspacePlayerPersonalCardScreenState._text)),
            const SizedBox(height: 4),
            Text(widget.name,
                style: AppTypography.caption(
                    color: _WorkspacePlayerPersonalCardScreenState._muted)),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                _size = Size(constraints.maxWidth, 230);
                return GestureDetector(
                  onPanStart: _start,
                  onPanUpdate: _update,
                  child: Container(
                    height: 230,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFBFA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _WorkspacePlayerPersonalCardScreenState._line),
                    ),
                    child: CustomPaint(
                      painter: _SignaturePainter(_strokes),
                      size: Size.infinite,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(_strokes.clear),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Очистить'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _WorkspacePlayerPersonalCardScreenState._greenSoft,
                    foregroundColor:
                        _WorkspacePlayerPersonalCardScreenState._green,
                    elevation: 0,
                  ),
                  onPressed: _strokes.isEmpty
                      ? null
                      : () => Navigator.pop(context, _json()),
                  child: const Text('Сохранить подпись'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF171B18)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
