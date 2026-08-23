// lib/presentation/attendance/cmr_attendance_panel.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class CmrAttendancePanel extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;
  final String teamLogoUrl;
  final bool fullScreen;

  const CmrAttendancePanel({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
    this.teamLogoUrl = '',
    this.fullScreen = false,
  });

  @override
  State<CmrAttendancePanel> createState() => _CmrAttendancePanelState();
}

class _CmrAttendancePanelState extends State<CmrAttendancePanel> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String playersUrl = '$apiBase/get_players_by_team.php';
  static const String getTeamEventsUrl = '$apiBase/get_team_events.php';
  static const String getAttendanceUrl = '$apiBase/get_team_attendance.php';
  static const String setAttendanceUrl = '$apiBase/set_team_attendance.php';
  static const String getTeamProfileUrl = '$apiBase/get_team_profile.php';
  static const String notifyTrainingStartedUrl = '$apiBase/notify_training_started.php';

  static const String kStatusUnset = 'unset';

  static const double _leftWidth = 238;
  static const double _cellWidth = 58;
  static const double _headerHeight = 48;
  static const double _rowHeight = 60;

  bool loading = true;
  bool saving = false;
  String? error;
  String? teamLogoUrl;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int? selectedEventId;
  String selectedEventTitle = 'Все мероприятия';

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> players = [];
  final Map<int, Map<String, Map<String, dynamic>>> attendanceByEvent = {};

  final TextEditingController searchC = TextEditingController();
  String filter = 'all';

  int? editingEventId;
  int? editingPlayerId;
  Map<String, dynamic>? editingEvent;
  Map<String, dynamic>? editingPlayer;
  String editingStatus = kStatusUnset;

  Map<String, int> stats = const {
    'unset': 0,
    'present': 0,
    'absent': 0,
    'late': 0,
    'injured': 0,
    'individual': 0,
    'dayoff': 0,
    'total': 0,
  };

  @override
  void initState() {
    super.initState();
    teamLogoUrl = _cacheBust(_normalizeTeamLogo(widget.teamLogoUrl));
    searchC.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  dynamic _decode(String body) {
    final clear = body.trim();
    final obj = clear.indexOf('{');
    final arr = clear.indexOf('[');
    final starts = [obj, arr].where((e) => e >= 0).toList();
    if (starts.isEmpty) return {};
    final start = starts.reduce((a, b) => a < b ? a : b);
    return jsonDecode(clear.substring(start));
  }


  String? _normalizeTeamLogo(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty || value == 'null') return null;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('sportotekaapp.ru/')) return 'https://$value';
    if (value.startsWith('www.sportotekaapp.ru/')) return 'https://$value';
    if (value.startsWith('/')) return 'https://sportotekaapp.ru$value';
    if (value.startsWith('uploads/')) return 'https://sportotekaapp.ru/$value';
    return 'https://sportotekaapp.ru/$value';
  }

  String? _cacheBust(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _loadTeamProfileSilent() async {
    try {
      final res = await http
          .post(
            Uri.parse(getTeamProfileUrl),
            body: {'team_id': widget.teamId.toString()},
          )
          .timeout(const Duration(seconds: 10));

      final data = _decode(res.body);
      if (data is! Map) return;

      final ok = data['success'] == true || data['status'] == 'success';
      final team = data['team'];
      if (!ok || team is! Map) return;

      final rawLogo = team['logo'] ?? team['logo_url'] ?? team['photo'] ?? team['image'];
      final logo = _cacheBust(_normalizeTeamLogo(rawLogo));
      if (logo == null || logo.trim().isEmpty) return;

      teamLogoUrl = logo;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  int _daysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 1)
        .subtract(const Duration(days: 1))
        .day;
  }

  String _monthTitle() {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];
    return '${months[selectedMonth.month - 1]} ${selectedMonth.year}';
  }

  String _eventTitle(Map<String, dynamic> e) {
    final title = '${e['title'] ?? ''}'.trim();
    final name = '${e['name'] ?? ''}'.trim();
    return title.isNotEmpty ? title : (name.isNotEmpty ? name : 'Мероприятие');
  }

  String _prettyDate(String iso) {
    if (iso.length < 10) return iso;
    return '${iso.substring(8, 10)}.${iso.substring(5, 7)}';
  }

  String _prettyTime(Map<String, dynamic> e) {
    final value = '${e['start_at'] ?? e['event_date'] ?? ''}'.trim();
    if (value.length >= 16) return value.substring(11, 16);
    return '';
  }

  String _eventDateLabel(Map<String, dynamic> e) {
    final iso = '${e['start_at'] ?? e['event_date'] ?? ''}';
    final date = _prettyDate(iso);
    final time = _prettyTime(e);
    return time.isEmpty ? date : '$date\n$time';
  }

  String _playerName(Map<String, dynamic> p) {
    final full = '${p['fullName'] ?? p['full_name'] ?? ''}'.trim();
    if (full.isNotEmpty && full != 'null') return full;
    final first = '${p['first_name'] ?? ''}'.trim();
    final last = '${p['last_name'] ?? ''}'.trim();
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Игрок' : name;
  }

  String _playerSub(Map<String, dynamic> p) {
    final parts = <String>[];
    final number = '${p['number'] ?? p['player_number'] ?? ''}'.trim();
    final pos = '${p['position'] ?? ''}'.trim();
    if (number.isNotEmpty && number != 'null') parts.add('№$number');
    if (pos.isNotEmpty && pos != 'null') parts.add(pos);
    return parts.isEmpty ? 'Игрок команды' : parts.join(' · ');
  }

  String? _photo(Map<String, dynamic> p) {
    final raw = '${p['photo'] ?? p['photo_url'] ?? p['avatar'] ?? ''}'.trim();
    if (raw.isEmpty || raw == 'null') return null;
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/uploads/$raw';
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
      events = [];
      players = [];
      attendanceByEvent.clear();
      selectedEventId = null;
      selectedEventTitle = 'Все мероприятия';
    });

    try {
      await Future.wait([_loadTeamProfileSilent(), _fetchPlayers(), _fetchEventsForMonth()]);
      await _fetchAttendanceForEvents();
      _calculateStats();
    } catch (e) {
      if (mounted) error = '$e';
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _fetchPlayers() async {
    final uri = Uri.parse(playersUrl).replace(queryParameters: {
      'team_id': widget.teamId.toString(),
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 16));
    final data = _decode(res.body);
    if (data is! Map) throw Exception('Некорректный ответ игроков');
    if (data['status'] != 'success' && data['success'] != true) {
      throw Exception('${data['message'] ?? 'Не удалось загрузить игроков'}');
    }
    final raw = (data['players'] as List?) ?? (data['data'] as List?) ?? const [];
    players = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    players.sort((a, b) => _playerName(a).toLowerCase().compareTo(_playerName(b).toLowerCase()));
  }

  Future<void> _fetchEventsForMonth() async {
    final from = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-01';
    final to = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-${_daysInMonth(selectedMonth).toString().padLeft(2, '0')}';
    final uri = Uri.parse(getTeamEventsUrl).replace(queryParameters: {
      'team_id': widget.teamId.toString(),
      'from': from,
      'to': to,
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 16));
    final data = _decode(res.body);
    if (data is! Map) throw Exception('Некорректный ответ мероприятий');
    if (data['success'] != true && data['status'] != 'success') {
      throw Exception('${data['message'] ?? 'Не удалось загрузить мероприятия'}');
    }
    final raw = (data['items'] as List?) ?? (data['events'] as List?) ?? (data['data'] as List?) ?? const [];
    events = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    events.sort((a, b) => '${a['start_at'] ?? a['event_date'] ?? ''}'.compareTo('${b['start_at'] ?? b['event_date'] ?? ''}'));
  }

  Future<void> _fetchAttendanceForEvents() async {
    if (events.isEmpty) return;
    const batchSize = 5;
    for (int i = 0; i < events.length; i += batchSize) {
      final batch = events.skip(i).take(batchSize).toList();
      await Future.wait(batch.map((event) async {
        final eventId = _asInt(event['id']);
        if (eventId <= 0) return;
        try {
          final uri = Uri.parse(getAttendanceUrl).replace(queryParameters: {
            'event_id': eventId.toString(),
          });
          final res = await http.get(uri).timeout(const Duration(seconds: 12));
          final data = _decode(res.body);
          if (data is Map && data['success'] == true) {
            final items = (data['items'] as Map?) ?? const {};
            attendanceByEvent[eventId] = items.map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from((v as Map?) ?? const {})));
          }
        } catch (_) {}
      }));
    }
  }

  Future<void> _reloadAttendanceForEvent(int eventId) async {
    try {
      final uri = Uri.parse(getAttendanceUrl).replace(queryParameters: {'event_id': '$eventId'});
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      final data = _decode(res.body);
      if (data is Map && data['success'] == true) {
        final items = (data['items'] as Map?) ?? const {};
        if (!mounted) return;
        setState(() {
          attendanceByEvent[eventId] = items.map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from((v as Map?) ?? const {})));
        });
      }
    } catch (_) {}
  }

  String _getStatusForEvent(int playerId, int eventId) {
    final row = attendanceByEvent[eventId]?[playerId.toString()];
    final status = '${row?['status'] ?? ''}'.trim();
    return status.isEmpty || status == 'null' ? kStatusUnset : status;
  }

  String _getAggregatedStatus(int playerId) {
    bool hasAny = false;
    bool hasPresent = false;
    bool hasLate = false;
    bool hasInjured = false;
    bool hasIndividual = false;
    bool hasDayOff = false;
    for (final event in events) {
      final eventId = _asInt(event['id']);
      final s = _getStatusForEvent(playerId, eventId);
      if (s == kStatusUnset) continue;
      hasAny = true;
      if (s == 'absent') return 'absent';
      if (s == 'late') hasLate = true;
      if (s == 'injured') hasInjured = true;
      if (s == 'individual') hasIndividual = true;
      if (s == 'dayoff') hasDayOff = true;
      if (s == 'present') hasPresent = true;
    }
    if (!hasAny) return kStatusUnset;
    if (hasLate) return 'late';
    if (hasInjured) return 'injured';
    if (hasIndividual) return 'individual';
    if (hasDayOff) return 'dayoff';
    if (hasPresent) return 'present';
    return kStatusUnset;
  }

  String _symbol(String status) {
    switch (status) {
      case 'present': return 'П';
      case 'absent': return 'Н';
      case 'late': return 'Б';
      case 'injured': return 'Т';
      case 'individual': return 'И';
      case 'dayoff': return 'В';
      default: return '';
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'present': return 'Присутствует';
      case 'absent': return 'Отсутствует';
      case 'late': return 'Болен';
      case 'injured': return 'Травма';
      case 'individual': return 'Индивидуально';
      case 'dayoff': return 'Выходной';
      default: return 'Не отмечено';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present': return const Color(0xFF22C55E);
      case 'absent': return const Color(0xFFEF4444);
      case 'late': return const Color(0xFFF59E0B);
      case 'injured': return const Color(0xFF8B5CF6);
      case 'individual': return const Color(0xFF0EA5E9);
      case 'dayoff': return const Color(0xFF94A3B8);
      default: return const Color(0xFFCBD5E1);
    }
  }

  void _calculateStats() {
    final next = {
      'unset': 0,
      'present': 0,
      'absent': 0,
      'late': 0,
      'injured': 0,
      'individual': 0,
      'dayoff': 0,
      'total': players.length,
    };
    for (final p in players) {
      final id = _asInt(p['id']);
      final status = selectedEventId == null ? _getAggregatedStatus(id) : _getStatusForEvent(id, selectedEventId!);
      next[status] = (next[status] ?? 0) + 1;
    }
    if (mounted) setState(() => stats = next);
  }

  List<Map<String, dynamic>> get _filteredPlayers {
    final query = searchC.text.trim().toLowerCase();
    return players.where((p) {
      final id = _asInt(p['id']);
      final status = selectedEventId == null ? _getAggregatedStatus(id) : _getStatusForEvent(id, selectedEventId!);
      if (filter != 'all' && status != filter) return false;
      if (query.isEmpty) return true;
      return _playerName(p).toLowerCase().contains(query) || _playerSub(p).toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _setStatusForEvent(int eventId, int playerId, String status) async {
    final markedBy = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;
    setState(() => saving = true);

    attendanceByEvent.putIfAbsent(eventId, () => {});
    setState(() {
      if (status == kStatusUnset) {
        attendanceByEvent[eventId]!.remove(playerId.toString());
      } else {
        attendanceByEvent[eventId]![playerId.toString()] = {'status': status, 'note': ''};
      }
    });

    try {
      final res = await http.post(Uri.parse(setAttendanceUrl), body: {
        'team_id': widget.teamId.toString(),
        'event_id': eventId.toString(),
        'player_id': playerId.toString(),
        'status': status == kStatusUnset ? '' : status,
        'note': '',
        'marked_by': markedBy.toString(),
      }).timeout(const Duration(seconds: 14));
      final data = _decode(res.body);
      var savedOk = res.statusCode >= 200 && res.statusCode < 300;
      if (data is Map && data['success'] == false) {
        savedOk = false;
        Get.snackbar('Ошибка', '${data['message'] ?? 'Не удалось сохранить отметку'}');
      }

      if (savedOk && status != kStatusUnset) {
        // Отдельный endpoint идемпотентен: первая отметка мероприятия создаёт
        // событие «Тренировка началась», повторные отметки push не дублируют.
        await _notifyTrainingStarted(
          eventId: eventId,
          markedBy: markedBy,
          status: status,
        );
      }

      await _reloadAttendanceForEvent(eventId);
      _calculateStats();
    } catch (_) {
      Get.snackbar('Ошибка сети', 'Не удалось сохранить посещаемость');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _notifyTrainingStarted({
    required int eventId,
    required int markedBy,
    required String status,
  }) async {
    if (widget.clubId <= 0 || widget.teamId <= 0 || eventId <= 0) return;
    try {
      await http.post(
        Uri.parse(notifyTrainingStartedUrl),
        body: {
          'club_id': widget.clubId.toString(),
          'team_id': widget.teamId.toString(),
          'event_id': eventId.toString(),
          'started_by': markedBy.toString(),
          'attendance_status': status,
        },
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Посещаемость уже сохранена. Ошибка push не должна откатывать отметку:
      // следующая отметка повторит вызов, а UNIQUE(event_id) защитит от дубля.
    }
  }


  String _exportStatusText(String status) {
    if (status == kStatusUnset || status.trim().isEmpty) return 'Не отмечено';
    return _statusText(status);
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _htmlCell(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  List<List<String>> _exportRows() {
    final rows = <List<String>>[
      ['Дата', 'Время', 'Мероприятие', 'Игрок', 'Статус', 'Примечание'],
    ];
    for (final event in events) {
      final eventId = _asInt(event['id']);
      if (eventId <= 0) continue;
      final dateRaw = '${event['start_at'] ?? event['event_date'] ?? ''}'.trim();
      final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
      final time = _prettyTime(event);
      final title = _eventTitle(event);
      final eventMap = attendanceByEvent[eventId] ?? const <String, Map<String, dynamic>>{};
      for (final player in players) {
        final playerId = _asInt(player['id']);
        final mark = eventMap[playerId.toString()];
        final status = '${mark?['status'] ?? kStatusUnset}';
        final note = '${mark?['note'] ?? ''}'.trim();
        rows.add([
          date,
          time,
          title,
          _playerName(player),
          _exportStatusText(status),
          note,
        ]);
      }
    }
    return rows;
  }

  Future<Directory> _exportDirectory() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  String _safeExportName(String raw) {
    final clean = raw
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return clean.isEmpty ? 'team' : clean;
  }

  Future<void> _exportExcel() async {
    try {
      final rows = _exportRows();
      if (rows.length <= 1) {
        Get.snackbar('Экспорт', 'За выбранный месяц нет мероприятий для экспорта');
        return;
      }

      final html = StringBuffer()
        ..writeln('<!doctype html><html><head><meta charset="utf-8"></head><body>')
        ..writeln('<h2>Журнал посещаемости · ${_htmlCell(widget.teamName)}</h2>')
        ..writeln('<p>${_htmlCell(widget.clubName)} · ${_htmlCell(_monthTitle())}</p>')
        ..writeln('<table border="1" cellspacing="0" cellpadding="5">');

      for (var i = 0; i < rows.length; i++) {
        html.writeln('<tr>');
        final tag = i == 0 ? 'th' : 'td';
        for (final cell in rows[i]) {
          html.writeln('<$tag>${_htmlCell(cell)}</$tag>');
        }
        html.writeln('</tr>');
      }
      html.writeln('</table></body></html>');

      final dir = await _exportDirectory();
      final file = File(
        '${dir.path}/attendance_${_safeExportName(widget.teamName)}_${selectedMonth.year}_${selectedMonth.month.toString().padLeft(2, '0')}.xls',
      );
      await file.writeAsString(html.toString(), encoding: utf8, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.ms-excel')],
        subject: 'Журнал посещаемости · ${widget.teamName}',
      );
    } catch (e) {
      Get.snackbar('Экспорт Excel', 'Не удалось создать файл: $e');
    }
  }

  Future<void> _exportPdf() async {
    try {
      final rows = _exportRows();
      if (rows.length <= 1) {
        Get.snackbar('Экспорт', 'За выбранный месяц нет мероприятий для экспорта');
        return;
      }

      final regularData = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
      final regular = pw.Font.ttf(regularData);
      final bold = pw.Font.ttf(boldData);

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      );

      final bodyRows = rows.skip(1).toList();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(22),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Журнал посещаемости · ${widget.teamName}',
                style: pw.TextStyle(font: bold, fontSize: 15),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                '${widget.clubName} · ${_monthTitle()}',
                style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Sportoteka · стр. ${context.pageNumber}',
              style: pw.TextStyle(font: regular, fontSize: 7.5, color: PdfColors.grey600),
            ),
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: rows.first,
              data: bodyRows,
              headerStyle: pw.TextStyle(font: bold, fontSize: 7.5),
              cellStyle: pw.TextStyle(font: regular, fontSize: 7.2),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: .35),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              columnWidths: const {
                0: pw.FixedColumnWidth(58),
                1: pw.FixedColumnWidth(38),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1.4),
                4: pw.FixedColumnWidth(68),
                5: pw.FlexColumnWidth(1.1),
              },
            ),
          ],
        ),
      );

      final dir = await _exportDirectory();
      final file = File(
        '${dir.path}/attendance_${_safeExportName(widget.teamName)}_${selectedMonth.year}_${selectedMonth.month.toString().padLeft(2, '0')}.pdf',
      );
      await file.writeAsBytes(await doc.save(), flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Журнал посещаемости · ${widget.teamName}',
      );
    } catch (e) {
      Get.snackbar('Экспорт PDF', 'Не удалось создать файл: $e');
    }
  }

  Map<String, dynamic>? _eventById(int eventId) {
    for (final e in events) {
      if (_asInt(e['id']) == eventId) return e;
    }
    return null;
  }

  Map<String, dynamic>? _playerById(int playerId) {
    for (final p in players) {
      if (_asInt(p['id']) == playerId) return p;
    }
    return null;
  }

  void _openAttendanceEditor(int eventId, int playerId, String currentStatus) {
    final event = _eventById(eventId);
    final player = _playerById(playerId);
    setState(() {
      editingEventId = eventId;
      editingPlayerId = playerId;
      editingEvent = event;
      editingPlayer = player;
      editingStatus = currentStatus;
      selectedEventId = eventId;
      selectedEventTitle = event == null ? 'Мероприятие' : _eventTitle(event);
    });
    _calculateStats();
  }

  void _closeAttendanceEditor() {
    setState(() {
      editingEventId = null;
      editingPlayerId = null;
      editingEvent = null;
      editingPlayer = null;
      editingStatus = kStatusUnset;
    });
  }

  Future<void> _applyEditorStatus(String status) async {
    final eventId = editingEventId;
    final playerId = editingPlayerId;
    if (eventId == null || playerId == null) return;
    setState(() => editingStatus = status);
    await _setStatusForEvent(eventId, playerId, status);
    if (!mounted) return;
    setState(() => editingStatus = _getStatusForEvent(playerId, eventId));
  }

  Widget _attendanceWorkspace() {
    final hasEditor = editingEventId != null && editingPlayerId != null;
    return LayoutBuilder(
      builder: (_, constraints) {
        final media = MediaQuery.of(context);
        final isTablet = media.size.shortestSide >= 600;
        final stackEditorBelow = !isTablet && constraints.maxWidth < 720;

        if (stackEditorBelow) {
          return Column(
            children: [
              Expanded(child: _journalTable()),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: hasEditor
                    ? Column(
                        key: const ValueKey('attendance-side-editor-mobile'),
                        children: [
                          const Divider(height: 1, color: _C.line),
                          SizedBox(
                            height: 248,
                            child: _attendanceEditorPanel(compact: true),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('attendance-side-editor-empty'),
                      ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _journalTable()),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: hasEditor
                  ? Row(
                      key: const ValueKey('attendance-side-editor-desktop'),
                      children: [
                        const VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: _C.line,
                        ),
                        SizedBox(
                          width: constraints.maxWidth < 900 ? 292 : 326,
                          child: _attendanceEditorPanel(
                            compact: constraints.maxWidth < 900,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(
                      key: ValueKey(
                        'attendance-side-editor-empty-desktop',
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _attendanceEditorPanel({bool compact = false}) {
    final event = editingEvent;
    final player = editingPlayer;
    final photo = player == null ? null : _photo(player);
    final status = editingStatus;
    final statusColor = _statusColor(status);
    final items = [
      [kStatusUnset, 'Очистить', '—', _C.subtle],
      ['present', 'Присутствует', 'П', const Color(0xFF22C55E)],
      ['absent', 'Отсутствует', 'Н', const Color(0xFFEF4444)],
      ['late', 'Болен', 'Б', const Color(0xFFF59E0B)],
      ['injured', 'Травма', 'Т', const Color(0xFF8B5CF6)],
      ['individual', 'Индивидуально', 'И', const Color(0xFF0EA5E9)],
      ['dayoff', 'Выходной', 'В', const Color(0xFF94A3B8)],
    ];

    if (event == null || player == null) {
      return ColoredBox(
        color: Colors.white,
        child: Center(
          child: Text(
            'Выберите ячейку посещаемости',
            style: _AttText.muted(11.2),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 14,
          compact ? 10 : 12,
          compact ? 12 : 14,
          compact ? 10 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _CmrDotCluster(),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Редактирование отметки',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _AttText.title(14.2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Статус игрока для выбранного события',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _AttText.muted(10.2),
                      ),
                    ],
                  ),
                ),
                _CompactIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Закрыть',
                  onTap: _closeAttendanceEditor,
                ),
              ],
            ),
            SizedBox(height: compact ? 10 : 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  statusColor.withOpacity(.045),
                  _C.soft,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: compact ? 38 : 42,
                    height: compact ? 38 : 42,
                    decoration: BoxDecoration(
                      color: _C.soft2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photo != null
                        ? Image.network(photo, fit: BoxFit.cover)
                        : const Center(
                            child: _CmrGlowDot(
                              color: _C.green,
                              size: 7,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _playerName(player),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _AttText.value(11.8),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _playerSub(player),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _AttText.muted(9.8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_eventDateLabel(event).replaceAll('\n', ' · ')} · ${_eventTitle(event)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _AttText.caption().copyWith(
                            color: status == kStatusUnset
                                ? _C.muted2
                                : statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
            Text('Статус', style: _AttText.section()),
            const SizedBox(height: 7),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: compact ? 4 : 2,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: compact ? 2.05 : 2.78,
                ),
                itemBuilder: (_, index) {
                  final code = items[index][0] as String;
                  final label = items[index][1] as String;
                  final symbol = items[index][2] as String;
                  final color = items[index][3] as Color;
                  return _EditorStatusTile(
                    code: code,
                    label: label,
                    symbol: symbol,
                    color: color,
                    active: code == status,
                    onTap: () => _applyEditorStatus(code),
                  );
                },
              ),
            ),
            if (saving) ...[
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  color: _C.green,
                  backgroundColor: _C.greenSoft,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showStatusSelector(
    int eventId,
    int playerId,
    String currentStatus,
  ) async {
    final items = [
      [kStatusUnset, 'Очистить', '—'],
      ['present', 'Присутствует', 'П'],
      ['absent', 'Отсутствует', 'Н'],
      ['late', 'Болен', 'Б'],
      ['injured', 'Травма', 'Т'],
      ['individual', 'Индивидуально', 'И'],
      ['dayoff', 'Выходной', 'В'],
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final width = MediaQuery.of(sheetContext).size.width;
        final crossAxisCount = width < 420 ? 2 : 3;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: width < 420 ? .76 : .62,
          minChildSize: .42,
          maxChildSize: .9,
          builder: (_, controller) {
            return Container(
              margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _C.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _CmrDotCluster(),
                  const SizedBox(height: 10),
                  Text(
                    'Отметка посещаемости',
                    style: _AttText.title(15.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Выберите статус игрока для выбранного мероприятия.',
                    style: _AttText.muted(10.8),
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 7,
                      mainAxisSpacing: 7,
                      childAspectRatio:
                          width < 420 ? 1.85 : 1.7,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final code = items[index][0];
                      final label = items[index][1];
                      final symbol = items[index][2];
                      final color = _statusColor(code);
                      return _EditorStatusTile(
                        code: code,
                        label: label,
                        symbol: symbol,
                        color: color,
                        active: code == currentStatus,
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _setStatusForEvent(
                            eventId,
                            playerId,
                            code,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openFullScreenJournal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CmrAttendancePanel(
          teamId: widget.teamId,
          teamName: widget.teamName,
          clubId: widget.clubId,
          clubName: widget.clubName,
          teamLogoUrl: teamLogoUrl ?? widget.teamLogoUrl,
          fullScreen: true,
        ),
      ),
    );
  }


  void _changeMonth(int delta) {
    setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + delta, 1));
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _LoadingPanel(
        teamName: widget.teamName,
        teamLogoUrl: teamLogoUrl ?? widget.teamLogoUrl,
      );
    }
    if (error != null) {
      return _ErrorPanel(text: error!, onRetry: _loadAll);
    }

    final workspace = DefaultTextStyle.merge(
      style: _AttText.body(11.5),
      child: Column(
        children: [
          _toolbar(),
          const Divider(height: 1, color: _C.line),
          _compactControlStrip(),
          const Divider(height: 1, color: _C.line),
          Expanded(child: _attendanceWorkspace()),
        ],
      ),
    );

    final content = Container(
      width: double.infinity,
      color: _C.workspace,
      padding: EdgeInsets.all(widget.fullScreen ? 8 : 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            widget.fullScreen ? 16 : 20,
          ),
          boxShadow: _C.windowShadow,
        ),
        child: workspace,
      ),
    );

    if (!widget.fullScreen) return content;

    return Scaffold(
      backgroundColor: _C.workspace,
      body: SafeArea(
        bottom: false,
        child: content,
      ),
    );
  }


  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final compact = constraints.maxWidth < 720;

          final title = Row(
            children: [
              if (widget.fullScreen) ...[
                _CmrAttendanceBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                  showLabel: constraints.maxWidth >= 860,
                ),
                const SizedBox(width: 10),
              ],
              _TeamLogoMark(
                logoUrl: teamLogoUrl ?? widget.teamLogoUrl,
                teamName: widget.teamName,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _CmrGlowDot(
                          color: _C.green,
                          size: 6.4,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Посещаемость',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _AttText.title(15.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.teamName} · ${widget.clubName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _AttText.muted(10.6),
                    ),
                  ],
                ),
              ),
            ],
          );

          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _MonthButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _changeMonth(-1),
                compact: true,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 116),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _C.soft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _monthTitle(),
                  textAlign: TextAlign.center,
                  style: _AttText.action(),
                ),
              ),
              _MonthButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _changeMonth(1),
                compact: true,
              ),
              _GhostButton(
                icon: Icons.refresh_rounded,
                text: 'Обновить',
                onTap: _loadAll,
                compact: true,
              ),
              _GhostButton(
                icon: Icons.picture_as_pdf_outlined,
                text: 'PDF',
                onTap: _exportPdf,
                compact: true,
              ),
              _GhostButton(
                icon: Icons.table_chart_outlined,
                text: 'Excel',
                onTap: _exportExcel,
                compact: true,
              ),
              if (!widget.fullScreen)
                _AccentButton(
                  icon: Icons.open_in_full_rounded,
                  text: 'На весь экран',
                  onTap: _openFullScreenJournal,
                  compact: true,
                ),
              if (saving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: _C.green,
                  ),
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 9),
                controls,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              controls,
            ],
          );
        },
      ),
    );
  }


  Widget _compactControlStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final compact = constraints.maxWidth < 880;

          final legend = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TinyStat(
                  title: 'Игроки',
                  value: '${stats['total'] ?? 0}',
                  color: _C.green,
                ),
                const SizedBox(width: 6),
                _TinyStat(
                  title: 'П',
                  value: '${stats['present'] ?? 0}',
                  color: const Color(0xFF22C55E),
                ),
                const SizedBox(width: 6),
                _TinyStat(
                  title: 'Нет',
                  value: '${stats['absent'] ?? 0}',
                  color: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 6),
                _TinyStat(
                  title: 'Болен',
                  value: '${stats['late'] ?? 0}',
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 6),
                _TinyStat(
                  title: 'Травма',
                  value: '${stats['injured'] ?? 0}',
                  color: const Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 6),
                _TinyStat(
                  title: 'Инд.',
                  value: '${stats['individual'] ?? 0}',
                  color: const Color(0xFF0EA5E9),
                ),
                const SizedBox(width: 6),
                _TinyStat(
                  title: 'Вых.',
                  value: '${stats['dayoff'] ?? 0}',
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
          );

          final search = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact
                    ? math.min(constraints.maxWidth - 52.0, 280.0)
                    : 280,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _C.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 15,
                      color: _C.muted2,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: TextField(
                        controller: searchC,
                        style: _AttText.value(11.6),
                        decoration: InputDecoration(
                          hintText: 'Поиск игрока',
                          hintStyle: _AttText.muted(10.8),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (searchC.text.trim().isNotEmpty)
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: searchC.clear,
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: _C.muted2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              _filterMenu(),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                legend,
                const SizedBox(height: 8),
                search,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: legend),
              const SizedBox(width: 10),
              search,
            ],
          );
        },
      ),
    );
  }


  Widget _filterMenu() {
    return PopupMenuButton<String>(
      initialValue: filter,
      tooltip: 'Фильтр',
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (v) => setState(() => filter = v),
      itemBuilder: (_) => [
        _attendanceFilterItem('all', 'Все игроки'),
        _attendanceFilterItem('present', 'Присутствуют'),
        _attendanceFilterItem('absent', 'Отсутствуют'),
        _attendanceFilterItem('late', 'Болеют'),
        _attendanceFilterItem('injured', 'Травмы'),
        _attendanceFilterItem('unset', 'Не отмечено'),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: filter == 'all' ? _C.soft : _C.greenSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CmrGlowDot(
              color: filter == 'all' ? _C.muted2 : _C.green,
              size: filter == 'all' ? 4.8 : 6,
              opacity: filter == 'all' ? .55 : 1,
              halo: filter != 'all',
            ),
            const SizedBox(width: 7),
            Text(
              'Фильтр',
              style: _AttText.action().copyWith(
                color: filter == 'all' ? _C.text : _C.greenDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _attendanceFilterItem(
    String value,
    String label,
  ) {
    final active = filter == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          _CmrGlowDot(
            color: active ? _C.green : _C.muted2,
            size: active ? 6 : 4.5,
            opacity: active ? 1 : .45,
            halo: active,
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: _AttText.action().copyWith(
              color: active ? _C.greenDark : _C.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _journalTable() {
    final filtered = _filteredPlayers;
    if (players.isEmpty) {
      return const _EmptyPanel(text: 'В команде пока нет игроков');
    }
    if (events.isEmpty) {
      return const _EmptyPanel(
        text: 'В выбранном месяце нет тренировок или мероприятий',
      );
    }
    if (filtered.isEmpty) {
      return const _EmptyPanel(text: 'По фильтру игроки не найдены');
    }

    final tableWidth = _leftWidth + events.length * _cellWidth;

    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: Column(
            children: [
              Row(
                children: [
                  _leftHeader(),
                  _rightHeader(),
                ],
              ),
              const Divider(height: 1, color: _C.line),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, index) {
                    final player = filtered[index];
                    return DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _C.line,
                            width: .55,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          _leftPlayerCell(player, index),
                          _rightStatusRow(player, index),
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

  Widget _leftHeader() {
    return Container(
      width: _leftWidth,
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: _C.soft,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const _CmrGlowDot(
            color: _C.green,
            size: 5.5,
            halo: false,
          ),
          const SizedBox(width: 8),
          Text(
            'Игроки (${_filteredPlayers.length})',
            style: _AttText.section(),
          ),
        ],
      ),
    );
  }

  Widget _rightHeader() {
    return Container(
      width: events.length * _cellWidth,
      height: _headerHeight,
      color: _C.soft,
      child: Row(
        children: events.map((event) {
          final eventId = _asInt(event['id']);
          final selected = eventId == selectedEventId;
          return SizedBox(
            width: _cellWidth,
            child: Tooltip(
              message: _eventTitle(event),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 5,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _C.greenSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _eventDateLabel(event),
                  textAlign: TextAlign.center,
                  style: _AttText.caption().copyWith(
                    color: selected ? _C.greenDark : _C.text,
                    height: 1.08,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _leftPlayerCell(
    Map<String, dynamic> player,
    int index,
  ) {
    final photo = _photo(player);
    final playerId = _asInt(player['id']);
    final status = selectedEventId == null
        ? _getAggregatedStatus(playerId)
        : _getStatusForEvent(playerId, selectedEventId!);
    final active = editingPlayerId == playerId;

    return Container(
      width: _leftWidth,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: active
          ? _C.greenSoft2
          : (index.isEven ? Colors.white : _C.soft.withOpacity(.42)),
      child: Row(
        children: [
          _CmrGlowDot(
            color: active
                ? _C.green
                : (status == kStatusUnset
                    ? _C.muted2
                    : _statusColor(status)),
            size: active ? 6.2 : 4.8,
            opacity: active ? 1 : .58,
            halo: active,
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _C.soft2,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo != null
                ? Image.network(photo, fit: BoxFit.cover)
                : Center(
                    child: Text(
                      _playerName(player)
                          .trim()
                          .split(RegExp(r'\s+'))
                          .where((e) => e.isNotEmpty)
                          .take(2)
                          .map((e) => e.substring(0, 1).toUpperCase())
                          .join(),
                      style: _AttText.value(10.4),
                    ),
                  ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _playerName(player),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _AttText.value(11.2).copyWith(
                    color: active ? _C.greenDark : _C.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _playerSub(player),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _AttText.muted(9.8).copyWith(
                    color: active
                        ? _C.greenDark.withOpacity(.68)
                        : _C.muted2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rightStatusRow(
    Map<String, dynamic> player,
    int index,
  ) {
    final playerId = _asInt(player['id']);
    final activePlayer = editingPlayerId == playerId;

    return Container(
      width: events.length * _cellWidth,
      height: _rowHeight,
      color: activePlayer
          ? _C.greenSoft2
          : (index.isEven ? Colors.white : _C.soft.withOpacity(.42)),
      child: Row(
        children: events.map((event) {
          final eventId = _asInt(event['id']);
          final status = _getStatusForEvent(playerId, eventId);
          final activeCell =
              editingEventId == eventId && editingPlayerId == playerId;

          return InkWell(
            onTap: () => _openAttendanceEditor(
              eventId,
              playerId,
              status,
            ),
            child: SizedBox(
              width: _cellWidth,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activeCell
                        ? _C.greenSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: _StatusCircle(
                    status: status,
                    symbol: _symbol(status),
                    size: activeCell ? 27 : 24,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _C {
  static const Color workspace = Color(0xFFF6F7F6);
  static const Color bg = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color header = Color(0xFFF7F8F7);
  static const Color soft = Color(0xFFF7F8F7);
  static const Color soft2 = Color(0xFFF2F4F2);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color greenSoft2 = Color(0xFFF8FEFA);
  static const Color greenBorder = Color(0xFFD7F0E2);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF5F6670);
  static const Color muted2 = Color(0xFF5F6670);
  static const Color subtle = Color(0xFF8A9099);
  static const Color line = Color(0xFFE9ECEA);
  static const Color border = Color(0xFFE9ECEA);
  static const Color blue = Color(0xFF2563EB);
  static const Color cyan = Color(0xFF06B6D4);

  static List<BoxShadow> get windowShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 28,
          spreadRadius: -18,
          offset: const Offset(0, 16),
        ),
      ];

  static BoxDecoration get card => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: line.withOpacity(.55),
          width: .7,
        ),
      );

  static BoxDecoration get cardCompact => const BoxDecoration(
        color: Colors.white,
      );

  static BoxDecoration get glassCard => const BoxDecoration(
        color: Colors.white,
      );
}

class _AttText {
  static TextStyle title(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _C.text,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle section() => AppTypography.custom(
        size: 11.8,
        weight: FontWeight.w600,
        color: _C.text,
        height: 1.2,
        letterSpacing: 0,
      );

  static TextStyle value(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _C.text,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle body(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: _C.text,
        height: 1.3,
        letterSpacing: 0,
      );

  static TextStyle muted(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: _C.muted2,
        height: 1.3,
        letterSpacing: 0,
      );

  static TextStyle caption() => AppTypography.custom(
        size: 10.1,
        weight: FontWeight.w500,
        color: _C.subtle,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle action() => AppTypography.custom(
        size: 10.9,
        weight: FontWeight.w600,
        color: _C.text,
        height: 1.1,
        letterSpacing: 0,
      );
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
              ? [
                  BoxShadow(
                    color: color.withOpacity(.17),
                    blurRadius: size * 1.8,
                    spreadRadius: .15,
                  ),
                  BoxShadow(
                    color: color.withOpacity(.06),
                    blurRadius: size * 3,
                    spreadRadius: .4,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _CmrDotCluster extends StatelessWidget {
  const _CmrDotCluster();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CmrGlowDot(
          color: _C.green,
          size: 3.4,
          opacity: .25,
          halo: false,
        ),
        SizedBox(width: 3),
        _CmrGlowDot(
          color: _C.green,
          size: 4.2,
          opacity: .45,
          halo: false,
        ),
        SizedBox(width: 3),
        _CmrGlowDot(
          color: _C.green,
          size: 5.2,
          opacity: .72,
          halo: false,
        ),
        SizedBox(width: 3),
        _CmrGlowDot(
          color: _C.green,
          size: 6.2,
        ),
      ],
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _C.soft,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 15,
              color: _C.muted2,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorStatusTile extends StatelessWidget {
  final String code;
  final String label;
  final String symbol;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _EditorStatusTile({
    required this.code,
    required this.label,
    required this.symbol,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final empty = code == _CmrAttendancePanelState.kStatusUnset;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: active
                ? color.withOpacity(.085)
                : _C.soft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active
                  ? color.withOpacity(.22)
                  : Colors.transparent,
              width: .75,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 23,
                height: 23,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: empty
                      ? Colors.white
                      : color.withOpacity(active ? .16 : .07),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: empty
                    ? Icon(
                        Icons.remove_rounded,
                        size: 12,
                        color: color,
                      )
                    : Text(
                        symbol,
                        style: _AttText.value(9.6).copyWith(
                          color: color,
                        ),
                      ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _AttText.action().copyWith(
                    color: active ? color : _C.text,
                  ),
                ),
              ),
              if (active)
                _CmrGlowDot(
                  color: color,
                  size: 5,
                  halo: false,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamLogoMark extends StatelessWidget {
  final String? logoUrl;
  final String teamName;
  final double size;

  const _TeamLogoMark({
    required this.logoUrl,
    required this.teamName,
    this.size = 36,
  });

  String? _normalizeImage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var url = raw.trim();
    if (url == 'null') return null;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('www.sportotekaapp.ru/')) {
      return 'https://$url';
    }
    if (url.startsWith('/')) return 'https://sportotekaapp.ru$url';
    if (url.startsWith('uploads/')) {
      return 'https://sportotekaapp.ru/$url';
    }
    return 'https://sportotekaapp.ru/$url';
  }

  Widget _fallback(String letter) {
    return Container(
      color: _C.soft,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: _AttText.title(size * .34),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _normalizeImage(logoUrl);
    final cleanName = teamName.trim();
    final letter = cleanName.isNotEmpty
        ? cleanName.characters.first.toUpperCase()
        : 'К';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _C.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? _fallback(letter)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => _fallback(letter),
              errorWidget: (_, __, ___) => _fallback(letter),
            ),
    );
  }
}

class _StatusCircle extends StatelessWidget {
  final String status;
  final String symbol;
  final double size;

  const _StatusCircle({
    required this.status,
    required this.symbol,
    required this.size,
  });

  Color get color {
    switch (status) {
      case 'present':
        return const Color(0xFF22C55E);
      case 'absent':
        return const Color(0xFFEF4444);
      case 'late':
        return const Color(0xFFF59E0B);
      case 'injured':
        return const Color(0xFF8B5CF6);
      case 'individual':
        return const Color(0xFF0EA5E9);
      case 'dayoff':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFFCBD5E1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty =
        status == _CmrAttendancePanelState.kStatusUnset;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: empty
            ? _C.soft2
            : color.withOpacity(.10),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: empty
          ? _CmrGlowDot(
              color: _C.subtle,
              size: 4,
              opacity: .35,
              halo: false,
            )
          : Text(
              symbol,
              style: _AttText.value(size * .38).copyWith(
                color: color,
              ),
            ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _TinyStat({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _C.soft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CmrGlowDot(
            color: color,
            size: 5.5,
            halo: false,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: _AttText.value(10.7).copyWith(
              color: _C.text,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: _AttText.caption(),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatPill({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _TinyStat(
      title: title,
      value: value,
      color: color,
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String status;
  final String label;

  const _LegendItem({
    required this.status,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusCircle(
            status: status,
            symbol: _symbolStatic(status),
            size: 16,
          ),
          const SizedBox(width: 5),
          Text(label, style: _AttText.caption()),
        ],
      ),
    );
  }

  static String _symbolStatic(String status) {
    switch (status) {
      case 'present':
        return 'П';
      case 'absent':
        return 'Н';
      case 'late':
        return 'Б';
      case 'injured':
        return 'Т';
      case 'individual':
        return 'И';
      case 'dayoff':
        return 'В';
      default:
        return '';
    }
  }
}

class _CmrAttendanceBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool showLabel;

  const _CmrAttendanceBackButton({
    required this.onTap,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.soft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: showLabel ? 10 : 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: _C.text,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 7),
                  Text(
                    'Назад',
                    style: _AttText.action(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _MonthButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const _MonthButton({
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final side = compact ? 34.0 : 36.0;
    return Material(
      color: _C.soft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: SizedBox(
          width: side,
          height: side,
          child: Icon(
            icon,
            color: _C.text,
            size: compact ? 17 : 19,
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool compact;

  const _GhostButton({
    required this.icon,
    required this.text,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.soft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          height: compact ? 34 : 36,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CmrGlowDot(
                color: _C.muted2,
                size: 4.5,
                opacity: .55,
                halo: false,
              ),
              const SizedBox(width: 6),
              Text(text, style: _AttText.action()),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool compact;

  const _AccentButton({
    required this.icon,
    required this.text,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.greenSoft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          height: compact ? 34 : 36,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _CmrGlowDot(
                color: _C.green,
                size: 5.5,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: _AttText.action().copyWith(
                  color: _C.greenDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatefulWidget {
  final String teamName;
  final String teamLogoUrl;

  const _LoadingPanel({
    this.teamName = '',
    this.teamLogoUrl = '',
  });

  @override
  State<_LoadingPanel> createState() => _LoadingPanelState();
}

class _LoadingPanelState extends State<_LoadingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _C.workspace,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(18),
          decoration: _C.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _controller,
                child: _TeamLogoMark(
                  logoUrl: widget.teamLogoUrl,
                  teamName: widget.teamName,
                  size: 64,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                'Загружаем журнал посещаемости',
                textAlign: TextAlign.center,
                style: _AttText.title(14),
              ),
              const SizedBox(height: 5),
              Text(
                'Подгружаем игроков, мероприятия и отметки',
                textAlign: TextAlign.center,
                style: _AttText.muted(10.8),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  color: _C.green,
                  backgroundColor: _C.greenSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ErrorPanel({
    required this.text,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _C.workspace,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(18),
          decoration: _C.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _CmrGlowDot(
                color: Color(0xFFD92D20),
                size: 7,
              ),
              const SizedBox(height: 12),
              Text(
                'Не удалось загрузить журнал',
                textAlign: TextAlign.center,
                style: _AttText.title(14.5),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                textAlign: TextAlign.center,
                style: _AttText.muted(11),
              ),
              const SizedBox(height: 14),
              _AccentButton(
                icon: Icons.refresh_rounded,
                text: 'Повторить',
                onTap: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String text;

  const _EmptyPanel({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _CmrDotCluster(),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: _AttText.title(13.5),
              ),
              const SizedBox(height: 5),
              Text(
                'Проверьте выбранный месяц или состав команды',
                textAlign: TextAlign.center,
                style: _AttText.muted(10.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
