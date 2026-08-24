// lib/presentation/team_roster/team_roster_screen.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:sportoteka/routes/app_routes.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

// ✅ ЧАТ
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';

// ✅ Печать / PDF
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class TeamRosterScreen extends StatefulWidget {
  final int teamId;
  final String teamName;
  final bool embedded;

  const TeamRosterScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    this.embedded = false,
  });

  @override
  State<TeamRosterScreen> createState() => _TeamRosterScreenState();
}

enum _RosterTab { players, staff, parents, managers }

class _RosterPalette {
  static const Color bg = Colors.white;
  static const Color card = Colors.white;
  static const Color soft =
      Color(0xFFF7F9F8);
  static const Color soft2 =
      Color(0xFFF2F5F3);
  static const Color text =
      Color(0xFF0B0F14);
  static const Color muted =
      Color(0xFF667085);
  static const Color muted2 =
      Color(0xFF98A2B3);
  static const Color line =
      Color(0xFFEDF0EE);
  static const Color green =
      Color(0xFF00A750);
  static const Color greenDark =
      Color(0xFF067A46);
  static const Color greenSoft =
      Color(0xFFF3FAF6);

  // aliases kept for old helper widgets
  static const Color blue =
      greenDark;
  static const Color blueSoft =
      greenSoft;
  static const Color cyan =
      green;
  static const Color orange =
      Color(0xFFF59E0B);
  static const Color purple =
      greenDark;
  static const Color rose =
      Color(0xFFD92D20);
}


class _TeamRosterScreenState extends State<TeamRosterScreen>
    with SingleTickerProviderStateMixin {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String deletePlayerUrl = '$apiBase/delete_player.php';
  static const String getUserUrl = '$apiBase/get_user.php';
  static const String getPlayersUrl = '$apiBase/get_players.php';
  static const String getManagersUrl = '$apiBase/get_club_managers.php';
  static const String getParentsUrl = '$apiBase/get_team_parents.php';
  static const String getTeamTrainersUrl = '$apiBase/get_team_trainers.php';
  static const String getTrainerProfileUrl = '$apiBase/get_trainer_profile.php';
  static const String getTeamProfileUrl = '$apiBase/get_team_profile.php';

  late final TabController _tab;

  bool loading = true;
  String? error;

  int userId = 0;
  int clubId = 0;
  String role = '';
  String? teamLogoUrl;

  bool get canEditRoster => role != 'player';

  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> staff = [];
  List<Map<String, dynamic>> parents = [];
  List<Map<String, dynamic>> managers = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _RosterTab.values.length, vsync: this)
      ..addListener(() {
        if (!_tab.indexIsChanging && mounted) setState(() {});
      });

    final args = Get.arguments;
    if (args is Map) clubId = _safeInt(args['clubId']);

    _initAndLoad();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    final uid = await PrefUtils.getUserId();
    userId = uid ?? 0;

    if (userId > 0) role = await _fetchRoleByUser(userId);
    if (clubId <= 0 && userId > 0) clubId = await _fetchClubIdByUser(userId);

    await Future.wait([
      _loadTeamProfileSilent(),
      _loadAll(),
    ]);
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await Future.wait([
        _fetchPlayers(),
        _fetchStaffByTeam(),
        _fetchParents(),
        _fetchManagers(),
      ]);

      players = _sortByFio(players);
      staff = _sortByFio(staff);
      parents = _sortByFio(parents);
      managers = _sortByFio(managers);
    } catch (e) {
      error = 'Ошибка загрузки: $e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String> _fetchRoleByUser(int uid) async {
    try {
      final resp = await http.get(Uri.parse('$getUserUrl?user_id=$uid'));
      final data = jsonDecode(resp.body);
      if (data is! Map) return '';
      final ok = data['success'] == true || data['status'] == 'success';
      if (!ok) return '';
      final user = data['user'];
      return user is Map ? (user['role'] ?? '').toString().trim() : '';
    } catch (_) {
      return '';
    }
  }

  Future<int> _fetchClubIdByUser(int uid) async {
    try {
      final resp = await http.get(Uri.parse('$getUserUrl?user_id=$uid'));
      final data = jsonDecode(resp.body);
      if (data is! Map) return 0;
      final ok = data['success'] == true || data['status'] == 'success';
      if (!ok) return 0;

      final user = data['user'];
      final cidFromUser = _safeInt(user is Map ? user['club_id'] : null);
      if (cidFromUser > 0) return cidFromUser;

      final team = data['team'];
      final cidFromTeam = _safeInt(team is Map ? team['club_id'] : null);
      if (cidFromTeam > 0) return cidFromTeam;

      final teams = data['teams'];
      if (teams is List && teams.isNotEmpty) {
        final first = teams.first;
        final cidFromTeams = _safeInt(first is Map ? first['club_id'] : null);
        if (cidFromTeams > 0) return cidFromTeams;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String? _normalizeTeamLogo(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('sportotekaapp.ru/')) return 'https://$value';
    if (value.startsWith('www.sportotekaapp.ru/')) return 'https://$value';
    if (value.startsWith('/')) return 'https://sportotekaapp.ru$value';
    return 'https://sportotekaapp.ru/$value';
  }

  String? _cacheBust(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _loadTeamProfileSilent() async {
    try {
      final resp = await http
          .post(
            Uri.parse(getTeamProfileUrl),
            body: {'team_id': widget.teamId.toString()},
          )
          .timeout(const Duration(seconds: 10));

      final data = _decodeMap(resp.body);
      final ok = data['success'] == true || data['status'] == 'success';
      final team = data['team'];
      if (!ok || team is! Map) return;

      final rawLogo = team['logo'] ?? team['logo_url'] ?? team['photo'] ?? team['image'];
      final logo = _cacheBust(_normalizeTeamLogo(rawLogo));
      if (mounted && logo != null) {
        setState(() => teamLogoUrl = logo);
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _postList(
    String url,
    Map<String, dynamic> body,
    String key,
  ) async {
    final resp = await http.post(
      Uri.parse(url),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    );

    final data = jsonDecode(resp.body);
    final ok = data is Map &&
        (data['status'] == 'success' || data['success'] == true);

    if (!ok) {
      final msg = (data is Map ? (data['message'] ?? data['error']) : null) ??
          'Не удалось загрузить данные';
      throw msg;
    }

    return data is Map ? List<Map<String, dynamic>>.from(data[key] ?? []) : [];
  }

  Future<void> _fetchPlayers() async {
    try {
      players = await _postList(getPlayersUrl, {'team_id': widget.teamId}, 'players');
    } catch (_) {
      players = [];
    }
  }

  Future<void> _fetchParents() async {
    try {
      parents = await _postList(getParentsUrl, {'team_id': widget.teamId}, 'parents');
    } catch (_) {
      parents = [];
    }
  }

  Future<void> _fetchManagers() async {
    if (clubId <= 0) {
      managers = [];
      return;
    }
    try {
      managers = await _postList(getManagersUrl, {'club_id': clubId}, 'managers');
    } catch (_) {
      managers = [];
    }
  }

  Future<void> _fetchStaffByTeam() async {
    try {
      staff = await _postList(getTeamTrainersUrl, {'team_id': widget.teamId}, 'trainers');
      staff = await _enrichStaffWithProfiles(staff);
    } catch (_) {
      staff = [];
    }
  }

  Future<List<Map<String, dynamic>>> _enrichStaffWithProfiles(
    List<Map<String, dynamic>> list,
  ) async {
    if (list.isEmpty) return list;

    Future<Map<String, dynamic>?> loadProfile(int trainerId) async {
      try {
        final resp = await http.post(
          Uri.parse(getTrainerProfileUrl),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'trainer_id': trainerId}),
        );
        final data = jsonDecode(resp.body);
        if (data is Map) {
          final ok = data['status'] == 'success' || data['success'] == true;
          final obj = data['trainer'] ?? data['profile'];
          if (ok && obj is Map) return Map<String, dynamic>.from(obj);
        }
      } catch (_) {}
      return null;
    }

    const int chunk = 6;
    final out = <Map<String, dynamic>>[];

    for (int i = 0; i < list.length; i += chunk) {
      final part = list.skip(i).take(chunk).toList();
      final futures = part.map((t) async {
        final m = Map<String, dynamic>.from(t);
        final tid = _pickTrainerId(m);
        final hasPosition =
            _s(m['position']).isNotEmpty || _s(m['role_title']).isNotEmpty;

        if (tid > 0 && !hasPosition) {
          final prof = await loadProfile(tid);
          if (prof != null) {
            if (_s(m['position']).isEmpty) m['position'] = prof['position'];
            if (_s(m['birthday']).isEmpty) m['birthday'] = prof['birthday'];
            if (_s(m['experience']).isEmpty) m['experience'] = prof['experience'];
            if (_s(m['bio']).isEmpty) m['bio'] = prof['bio'];
            if (_s(m['photo']).isEmpty) m['photo'] = prof['photo'];
            if (_s(m['photo_url']).isEmpty) m['photo_url'] = prof['photo_url'];
            if (_s(m['email']).isEmpty) m['email'] = prof['email'];
            if (m['user_id'] == null && prof['user_id'] != null) {
              m['user_id'] = prof['user_id'];
            }
          }
        }
        return m;
      }).toList();
      out.addAll(await Future.wait(futures));
    }

    return out;
  }

  int _safeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _fio(Map<String, dynamic> x) {
    final last = _s(x['last_name']);
    final first = _s(x['first_name']);
    final middle = _s(x['middle_name']);
    final fio = [last, first, middle].where((e) => e.isNotEmpty).join(' ');
    return fio.isEmpty ? _s(x['name']) : fio;
  }

  List<Map<String, dynamic>> _sortByFio(List<Map<String, dynamic>> list) {
    final copy = [...list];
    copy.sort((a, b) {
      final al = _s(a['last_name']).toLowerCase();
      final af = _s(a['first_name']).toLowerCase();
      final bl = _s(b['last_name']).toLowerCase();
      final bf = _s(b['first_name']).toLowerCase();
      final c1 = al.compareTo(bl);
      if (c1 != 0) return c1;
      return af.compareTo(bf);
    });
    return copy;
  }

  int _pickTrainerId(Map<String, dynamic> t) {
    int asInt(dynamic v) => v is int ? v : int.tryParse((v ?? '').toString()) ?? 0;
    final candidates = [
      t['trainer_id'],
      t['trainerId'],
      t['id'],
      t['user_id'],
      t['uid'],
      t['trainer_user_id'],
      t['trainer_profile_id'],
    ];
    for (final c in candidates) {
      final v = asInt(c);
      if (v > 0) return v;
    }
    return 0;
  }

  int _pickPlayerId(Map<String, dynamic> m) {
    int asInt(dynamic v) => v is int ? v : int.tryParse((v ?? '').toString()) ?? 0;
    final candidates = [m['id'], m['player_id'], m['playerId'], m['uid']];
    for (final c in candidates) {
      final v = asInt(c);
      if (v > 0) return v;
    }
    return 0;
  }

  Future<bool> _confirmDeletePlayer(String fio) async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text('Удалить игрока?'),
            content: Text(
              fio.isEmpty ? 'Удалить игрока из команды?' : 'Удалить "$fio" из команды?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _deletePlayer(Map<String, dynamic> p) async {
    if (!canEditRoster) {
      Get.snackbar(
        'Доступ ограничен',
        'Игрок не может изменять состав команды',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    final playerId = _pickPlayerId(p);
    final fio = _fio(p);

    if (playerId <= 0) {
      Get.snackbar(
        'Удаление',
        'Не найден id игрока. Ключи: ${p.keys.toList()}',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    final okConfirm = await _confirmDeletePlayer(fio);
    if (!okConfirm) return;

    try {
      if (mounted) {
        setState(() => players.removeWhere((x) => _pickPlayerId(x) == playerId));
      }

      final resp = await http.post(
        Uri.parse(deletePlayerUrl),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'player_id': playerId, 'team_id': widget.teamId}),
      );

      final data = jsonDecode(resp.body);
      final success = data is Map &&
          (data['success'] == true || data['status'] == 'success');

      if (!success) {
        final msg = (data is Map ? (data['message'] ?? data['error']) : null) ??
            'Не удалось удалить';
        await _fetchPlayers();
        if (mounted) setState(() {});
        Get.snackbar('Удаление', msg, snackPosition: SnackPosition.BOTTOM);
        return;
      }

      Get.snackbar('Удаление', 'Игрок удалён', snackPosition: SnackPosition.BOTTOM);
      await _fetchPlayers();
      if (mounted) setState(() {});
    } catch (e) {
      await _fetchPlayers();
      if (mounted) setState(() {});
      Get.snackbar('Удаление', 'Ошибка: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _printPlayersTable() async {
    if (players.isEmpty) {
      Get.snackbar('Печать', 'Нет игроков для печати');
      return;
    }

    final doc = pw.Document();

    Future<pw.ImageProvider?> loadPhoto(String url) async {
      try {
        if (url.isEmpty) return null;
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200) return pw.MemoryImage(resp.bodyBytes);
      } catch (_) {}
      return null;
    }

    pw.Widget headerCell(String text) => pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            text,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          ),
        );

    pw.Widget cell(String text) => pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
        );

    final rows = <pw.TableRow>[];

    for (final p in players) {
      final fio = _fio(p);
      final dob = _s(p['birth_date']);
      final position = _s(p['position']);
      final foot = _s(p['foot']);
      final number = _s(p['number']);
      final metrics = _s(p['metrics']).isNotEmpty ? _s(p['metrics']) : _s(p['sport_data']);
      final photoUrl = _s(p['photo_url']).isNotEmpty ? _s(p['photo_url']) : _s(p['photo']);
      final img = photoUrl.startsWith('http') ? await loadPhoto(photoUrl) : null;
      final letter = fio.isNotEmpty ? fio.substring(0, 1).toUpperCase() : 'И';

      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 18,
                    height: 18,
                    decoration: const pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: PdfColors.grey300,
                    ),
                    child: img != null
                        ? pw.ClipOval(child: pw.Image(img, fit: pw.BoxFit.cover))
                        : pw.Center(
                            child: pw.Text(
                              letter,
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Text(
                      fio.isEmpty ? 'Игрок' : fio,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
            cell(dob),
            cell(position),
            cell(foot),
            cell(number),
            cell(metrics),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        build: (_) => [
          pw.Text(
            'Состав команды: ${widget.teamName}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.2),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.3),
              3: pw.FlexColumnWidth(1.5),
              4: pw.FlexColumnWidth(1.1),
              5: pw.FlexColumnWidth(1.7),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  headerCell('ФИО с фото'),
                  headerCell('Дата рождения'),
                  headerCell('Амплуа'),
                  headerCell('Профильная\nнога'),
                  headerCell('Игровой\nномер'),
                  headerCell('Метрики'),
                ],
              ),
              ...rows,
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  _RosterTab get _currentTab => _RosterTab.values[_tab.index];

  int get _currentCount {
    switch (_currentTab) {
      case _RosterTab.players:
        return players.length;
      case _RosterTab.staff:
        return staff.length;
      case _RosterTab.parents:
        return parents.length;
      case _RosterTab.managers:
        return managers.length;
    }
  }

  Widget _compactTab({
    required int index,
    required String title,
    required int count,
    required IconData icon,
  }) {
    final active =
        _tab.index == index;

    return Expanded(
      child: Material(
        color: active
            ? _RosterPalette.greenSoft
            : _RosterPalette.soft,
        borderRadius:
            BorderRadius.circular(9),
        child: InkWell(
          onTap: () =>
              _tab.animateTo(index),
          borderRadius:
              BorderRadius.circular(9),
          child: Container(
            height: 38,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 16,
                  color: active
                      ? _RosterPalette
                          .greenDark
                      : _RosterPalette
                          .muted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$title $count',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        AppTypography.custom(
                      size: 9.2,
                      weight:
                          FontWeight.w600,
                      color: active
                          ? _RosterPalette
                              .greenDark
                          : _RosterPalette
                              .muted,
                      height: 1.1,
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

  Widget _buildCompactRoster() {
    return Column(
      children: <Widget>[
        Container(
          height: 58,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          decoration:
              const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color:
                    _RosterPalette.line,
                width: .6,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              _TeamLogoAvatar(
                teamName:
                    widget.teamName,
                logoUrl: teamLogoUrl,
                size: 34,
                compact: true,
              ),
              const SizedBox(width: 9),
              const _RosterDots(),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: <Widget>[
                    Text(
                      'Состав',
                      style:
                          AppTypography.custom(
                        size: 13,
                        weight:
                            FontWeight.w600,
                        color:
                            _RosterPalette.text,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.teamName,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          AppTypography.custom(
                        size: 8.7,
                        weight:
                            FontWeight.w400,
                        color:
                            _RosterPalette.muted,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              if (canEditRoster)
                _RosterTextAction(
                  label: 'Печать',
                  onTap:
                      _printPlayersTable,
                ),
              const SizedBox(width: 5),
              _RosterTextAction(
                label: 'Обновить',
                onTap: () async {
                  await Future.wait(
                    <Future<void>>[
                      _loadTeamProfileSilent(),
                      _loadAll(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            10,
            8,
            10,
            7,
          ),
          child: Row(
            children: <Widget>[
              _compactTab(
                index: 0,
                title: 'Игроки',
                count: players.length,
                icon:
                    Icons.people_alt_outlined,
              ),
              const SizedBox(width: 5),
              _compactTab(
                index: 1,
                title: 'Штаб',
                count: staff.length,
                icon:
                    Icons.sports_outlined,
              ),
              const SizedBox(width: 5),
              _compactTab(
                index: 2,
                title: 'Родители',
                count: parents.length,
                icon: Icons
                    .family_restroom_outlined,
              ),
              const SizedBox(width: 5),
              _compactTab(
                index: 3,
                title: 'Руководство',
                count: managers.length,
                icon:
                    Icons.apartment_outlined,
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: <Widget>[
              _PlayersTabModern(
                key:
                    const PageStorageKey(
                  'roster_players_tab',
                ),
                teamId: widget.teamId,
                players: players,
                canEdit: canEditRoster,
                canOpenPlayerProfile:
                    role != 'player',
                onAddPlayer:
                    canEditRoster
                        ? () =>
                            Get.toNamed(
                              AppRoutes
                                  .addPlayerScreen,
                              arguments:
                                  <String,
                                      dynamic>{
                                'teamId':
                                    widget
                                        .teamId,
                              },
                            )
                        : null,
                onPlayerTap: (p) {
                  final mp =
                      Map<String,
                          dynamic>.from(
                    p,
                  );
                  mp['team_id'] =
                      widget.teamId;
                  mp['teamId'] =
                      widget.teamId;
                  mp['club_id'] =
                      clubId;
                  mp['team_name'] =
                      widget.teamName;
                  Get.toNamed(
                    AppRoutes
                        .playerProfileScreen,
                    arguments: mp,
                  );
                },
                onPlayerDelete:
                    _deletePlayer,
              ),
              _StaffTabModern(
                key:
                    const PageStorageKey(
                  'roster_staff_tab',
                ),
                items: staff,
                emptyText:
                    'Тренеры команды не назначены.',
                onTapTrainer: (t) {
                  final tid =
                      _pickTrainerId(t);
                  final name = _fio(t);
                  if (tid <= 0) {
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TrainerProfileViewScreen(
                        trainerId: tid,
                        trainerName:
                            name.isEmpty
                                ? 'Тренер #$tid'
                                : name,
                        trainerPhotoRaw:
                            (t['photo_url'] ??
                                    t['photo'])
                                ?.toString(),
                        trainerEmailRaw:
                            t['email']
                                ?.toString(),
                      ),
                    ),
                  );
                },
              ),
              _PeopleTabModern(
                key:
                    const PageStorageKey(
                  'roster_parents_tab',
                ),
                items: parents,
                emptyText:
                    'Родители не найдены.',
                icon: Icons
                    .family_restroom_outlined,
                accent:
                    _RosterPalette.green,
              ),
              _PeopleTabModern(
                key:
                    const PageStorageKey(
                  'roster_managers_tab',
                ),
                items: managers,
                emptyText:
                    clubId <= 0
                        ? 'Не найден club_id.'
                        : 'Руководство не найдено.',
                icon: Icons
                    .apartment_outlined,
                accent:
                    _RosterPalette.greenDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final firm =
        AppTypography.custom(
      size: 11,
      weight: FontWeight.w400,
      color: _RosterPalette.text,
    );

    final theme =
        Theme.of(context).copyWith(
      scaffoldBackgroundColor:
          Colors.white,
      colorScheme:
          Theme.of(context)
              .colorScheme
              .copyWith(
        primary:
            _RosterPalette.green,
      ),
      textTheme:
          Theme.of(context)
              .textTheme
              .apply(
        fontFamily:
            firm.fontFamily,
        bodyColor:
            _RosterPalette.text,
        displayColor:
            _RosterPalette.text,
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor:
            Colors.white,
        body: SafeArea(
          bottom: false,
          child: loading
              ? const _RosterLoadingView()
              : error != null
                  ? _ErrorBlock(
                      text: error!,
                      onRetry:
                          _loadAll,
                    )
                  : _buildCompactRoster(),
        ),
      ),
    );
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'club':
        return 'Клуб';
      case 'coach':
      case 'trainer':
        return 'Тренер';
      case 'player':
        return 'Игрок';
      case 'parent':
        return 'Родитель';
      case 'federation':
        return 'Федерация';
      case 'manager':
        return 'Менеджер';
      case 'admin':
        return 'Администратор';
      default:
        return 'Пользователь';
    }
  }

  String _tabTitle(_RosterTab t) {
    switch (t) {
      case _RosterTab.players:
        return 'Состав команды';
      case _RosterTab.staff:
        return 'Тренерский штаб';
      case _RosterTab.parents:
        return 'Родители игроков';
      case _RosterTab.managers:
        return 'Руководство клуба';
    }
  }

  String _sectionSubtitle(_RosterTab t) {
    switch (t) {
      case _RosterTab.players:
        return canEditRoster
            ? ''
            : 'Просмотр состава без права редактирования';
      case _RosterTab.staff:
        return 'Профили тренеров и быстрый переход в чат';
      case _RosterTab.parents:
        return 'Контакты родителей, привязанных к команде';
      case _RosterTab.managers:
        return 'Ответственные лица и руководство клуба';
    }
  }
}


class _RosterDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _RosterDot({
    required this.color,
    required this.size,
    this.opacity = 1,
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
        ),
      ),
    );
  }
}

class _RosterDots extends StatelessWidget {
  final Color color;

  const _RosterDots({
    this.color =
        _RosterPalette.green,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: <Widget>[
        _RosterDot(
          color: color,
          size: 3.4,
          opacity: .32,
        ),
        const SizedBox(width: 3),
        _RosterDot(
          color: color,
          size: 4.4,
          opacity: .55,
        ),
        const SizedBox(width: 3),
        _RosterDot(
          color: color,
          size: 5.4,
          opacity: .78,
        ),
        const SizedBox(width: 3),
        _RosterDot(
          color: color,
          size: 6.4,
        ),
      ],
    );
  }
}

class _RosterTextAction
    extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RosterTextAction({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          _RosterPalette.greenSoft,
      borderRadius:
          BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(9),
        child: Container(
          height: 32,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 8,
          ),
          child: Row(
            children: <Widget>[
              const _RosterDot(
                color:
                    _RosterPalette.green,
                size: 5,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style:
                    AppTypography.custom(
                  size: 8.6,
                  weight:
                      FontWeight.w600,
                  color:
                      _RosterPalette
                          .greenDark,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SimpleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _RosterPalette.line),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _RosterPalette.text),
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _RosterPalette.line),
          ),
          child: Icon(icon, size: 19, color: _RosterPalette.text),
        ),
      ),
    );
  }
}

class _CollapsedTeamTitle extends StatelessWidget {
  final String teamName;
  final String? logoUrl;
  final String subtitle;

  const _CollapsedTeamTitle({
    required this.teamName,
    required this.logoUrl,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TeamLogoAvatar(teamName: teamName, logoUrl: logoUrl, size: 36, compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                teamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _RosterPalette.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _RosterPalette.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamLogoAvatar extends StatelessWidget {
  final String teamName;
  final String? logoUrl;
  final double size;
  final bool compact;

  const _TeamLogoAvatar({
    required this.teamName,
    required this.logoUrl,
    required this.size,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final letter = teamName.trim().isNotEmpty ? teamName.trim().substring(0, 1).toUpperCase() : 'К';
    final url = (logoUrl ?? '').trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 12 : 22),
        border: Border.all(color: Colors.white.withOpacity(0.85), width: compact ? 1 : 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _fallback(letter),
              placeholder: (_, __) => _fallback(letter),
            )
          : _fallback(letter),
    );
  }

  Widget _fallback(String letter) {
    return Container(
      color: const Color(0xFFEAFBF1),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: _RosterPalette.greenDark,
          fontSize: compact ? 15 : 26,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RosterTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final String currentTitle;
  final String currentSubtitle;
  final int currentCount;
  final int playersCount;
  final int staffCount;
  final int parentsCount;
  final int managersCount;
  final ValueChanged<int> onTabTap;
  final bool dense;

  const _RosterTabsHeaderDelegate({
    required this.controller,
    required this.currentTitle,
    required this.currentSubtitle,
    required this.currentCount,
    required this.playersCount,
    required this.staffCount,
    required this.parentsCount,
    required this.managersCount,
    required this.onTabTap,
    this.dense = false,
  });

  @override
  double get minExtent => dense ? 82 : 108;

  @override
  double get maxExtent => dense ? 112 : 176;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final collapse = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final verticalPad = lerpDouble(8, 6, collapse)!;
    final bottomPad = lerpDouble(10, 8, collapse)!;
    final gap = lerpDouble(10, 6, collapse)!;

    return Container(
      color: _RosterPalette.bg,
      padding: EdgeInsets.fromLTRB(16, verticalPad, 16, bottomPad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RosterStatsStrip(
            activeIndex: controller.index,
            compactFactor: collapse,
            items: [
              _RosterStatData('Игроки', '$playersCount', Icons.people_alt_rounded, _RosterPalette.green),
              _RosterStatData('Штаб', '$staffCount', Icons.sports_rounded, _RosterPalette.blue),
              _RosterStatData('Родители', '$parentsCount', Icons.family_restroom_rounded, _RosterPalette.orange),
              _RosterStatData('Руководство', '$managersCount', Icons.apartment_rounded, _RosterPalette.purple),
            ],
            onTap: onTabTap,
          ),
          SizedBox(height: gap),
          _SectionHeader(
            title: currentTitle,
            subtitle: currentSubtitle,
            count: currentCount,
            compactFactor: collapse,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _RosterTabsHeaderDelegate oldDelegate) {
    return oldDelegate.controller.index != controller.index ||
        oldDelegate.currentTitle != currentTitle ||
        oldDelegate.currentCount != currentCount ||
        oldDelegate.playersCount != playersCount ||
        oldDelegate.staffCount != staffCount ||
        oldDelegate.parentsCount != parentsCount ||
        oldDelegate.managersCount != managersCount ||
        oldDelegate.dense != dense;
  }
}

class _RosterTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onPrint;

  const _RosterTopBar({
    required this.onBack,
    required this.onRefresh,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Команда',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: _RosterPalette.text,
            ),
          ),
        ),
        _RoundIconButton(icon: Icons.print_rounded, onTap: onPrint),
        const SizedBox(width: 8),
        _RoundIconButton(icon: Icons.refresh_rounded, onTap: onRefresh),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _RosterPalette.line),
            boxShadow: const [
              BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 8)),
            ],
          ),
          child: Icon(icon, size: 20, color: _RosterPalette.text),
        ),
      ),
    );
  }
}

class _RosterHero extends StatelessWidget {
  final String teamName;
  final String? logoUrl;
  final String role;
  final String activeSection;
  final int totalPlayers;
  final int totalStaff;
  final int totalParents;
  final int totalManagers;
  final bool canEdit;
  final VoidCallback? onAddPlayer;

  const _RosterHero({
    required this.teamName,
    required this.logoUrl,
    required this.role,
    required this.activeSection,
    required this.totalPlayers,
    required this.totalStaff,
    required this.totalParents,
    required this.totalManagers,
    required this.canEdit,
    required this.onAddPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalPlayers + totalStaff + totalParents + totalManagers;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _RosterPalette.line),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: _DecorCircle(size: 120, opacity: 0.12),
          ),
          Positioned(
            right: 30,
            bottom: -48,
            child: _DecorCircle(size: 135, opacity: 0.10),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroPill(icon: Icons.verified_rounded, text: role),
                  _HeroPill(icon: Icons.layers_rounded, text: activeSection),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _TeamLogoAvatar(teamName: teamName, logoUrl: logoUrl, size: 68),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      teamName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _RosterPalette.text,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Единый центр состава: игроки, штаб, родители и руководство в одной удобной панели.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _RosterPalette.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, c) {
                  final compact = c.maxWidth < 390;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _HeroMetric(value: '$totalPlayers', label: 'игроков'),
                      _HeroMetric(value: '$totalStaff', label: 'тренеров'),
                      _HeroMetric(value: '$total', label: 'всего'),
                      if (canEdit && onAddPlayer != null)
                        SizedBox(
                          width: compact ? double.infinity : null,
                          child: _HeroActionButton(onTap: onAddPlayer!),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecorCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _RosterPalette.blueSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _RosterPalette.blue),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _RosterPalette.blue,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String value;
  final String label;

  const _HeroMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _RosterPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _RosterPalette.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _RosterPalette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeroActionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: _RosterPalette.green, size: 18),
              SizedBox(width: 8),
              Text(
                'Добавить игрока',
                style: TextStyle(
                  color: _RosterPalette.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RosterStatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _RosterStatData(this.title, this.value, this.icon, this.color);
}

class _RosterStatsStrip extends StatelessWidget {
  final int activeIndex;
  final double compactFactor;
  final List<_RosterStatData> items;
  final ValueChanged<int> onTap;

  const _RosterStatsStrip({
    required this.activeIndex,
    required this.compactFactor,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 620;
        final height = lerpDouble(78, 50, compactFactor)!;
        final spacing = lerpDouble(10, 7, compactFactor)!;
        final itemWidth = lerpDouble(136, 112, compactFactor)!;

        if (isWide) {
          return SizedBox(
            height: height,
            child: Row(
              children: List.generate(items.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == items.length - 1 ? 0 : spacing),
                    child: _StatCard(
                      data: items[i],
                      active: i == activeIndex,
                      compactFactor: compactFactor,
                      onTap: () => onTap(i),
                    ),
                  ),
                );
              }),
            ),
          );
        }
        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: spacing),
            itemBuilder: (_, i) => SizedBox(
              width: itemWidth,
              child: _StatCard(
                data: items[i],
                active: i == activeIndex,
                compactFactor: compactFactor,
                onTap: () => onTap(i),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final _RosterStatData data;
  final bool active;
  final double compactFactor;
  final VoidCallback onTap;

  const _StatCard({
    required this.data,
    required this.active,
    required this.compactFactor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = lerpDouble(22, 16, compactFactor)!;
    final padding = lerpDouble(11, 8, compactFactor)!;
    final iconBox = lerpDouble(34, 28, compactFactor)!;
    final iconSize = lerpDouble(21, 16, compactFactor)!;
    final valueSize = lerpDouble(18, 14, compactFactor)!;
    final titleSize = lerpDouble(12, 10, compactFactor)!;
    final gap = lerpDouble(10, 7, compactFactor)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: active ? data.color.withOpacity(0.45) : _RosterPalette.line),
            boxShadow: [
              BoxShadow(
                color: active ? data.color.withOpacity(0.13) : const Color(0x0C000000),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(lerpDouble(16, 11, compactFactor)!),
                ),
                child: Icon(data.icon, color: data.color, size: iconSize),
              ),
              SizedBox(width: gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data.value,
                      style: TextStyle(
                        fontSize: valueSize,
                        fontWeight: FontWeight.w800,
                        color: _RosterPalette.text,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: lerpDouble(5, 3, compactFactor)!),
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: _RosterPalette.muted,
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

class _RosterTabs extends StatelessWidget {
  final TabController controller;

  const _RosterTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _RosterPalette.line),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _RosterPalette.blueSoft,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        labelColor: _RosterPalette.blue,
        unselectedLabelColor: _RosterPalette.text,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        tabs: const [
          _ModernTab(icon: Icons.people_alt_outlined, text: 'Игроки'),
          _ModernTab(icon: Icons.sports_rounded, text: 'Тренерский штаб'),
          _ModernTab(icon: Icons.family_restroom_outlined, text: 'Родители'),
          _ModernTab(icon: Icons.apartment_rounded, text: 'Руководство'),
        ],
      ),
    );
  }
}

class _ModernTab extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ModernTab({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(text),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final double compactFactor;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
    this.compactFactor = 0,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = lerpDouble(18, 15, compactFactor)!;
    final subSize = lerpDouble(12.5, 10.5, compactFactor)!;
    final badgePadH = lerpDouble(12, 9, compactFactor)!;
    final badgePadV = lerpDouble(8, 5, compactFactor)!;
    return Padding(
      padding: EdgeInsets.only(bottom: lerpDouble(8, 3, compactFactor)!),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _RosterPalette.text,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _RosterPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _RosterPalette.line),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontWeight: FontWeight.w900, color: _RosterPalette.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayersTabModern extends StatelessWidget {
  final int teamId;
  final List<Map<String, dynamic>> players;
  final bool canEdit;
  final bool canOpenPlayerProfile;
  final VoidCallback? onAddPlayer;
  final ValueChanged<Map<String, dynamic>> onPlayerTap;
  final ValueChanged<Map<String, dynamic>> onPlayerDelete;

  const _PlayersTabModern({
    super.key,
    required this.teamId,
    required this.players,
    required this.canEdit,
    required this.canOpenPlayerProfile,
    required this.onAddPlayer,
    required this.onPlayerTap,
    required this.onPlayerDelete,
  });

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _fio(Map<String, dynamic> x) {
    final last = _s(x['last_name']);
    final first = _s(x['first_name']);
    final middle = _s(x['middle_name']);
    final fio = [last, first, middle].where((e) => e.isNotEmpty).join(' ');
    return fio.isEmpty ? _s(x['name']) : fio;
  }

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          if (canEdit && onAddPlayer != null) ...[
            _AddPlayerWideButton(onTap: onAddPlayer!),
            const SizedBox(height: 12),
          ],
          const _ModernEmptyState(
            icon: Icons.people_alt_outlined,
            title: 'Игроки не найдены',
            text: 'Добавьте первого игрока, чтобы сформировать состав команды.',
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final columns = w >= 1180 ? 4 : (w >= 820 ? 3 : (w >= 560 ? 2 : 1));
        final ratio = columns == 1 ? 3.35 : (columns == 2 ? 2.65 : 2.35);

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (canEdit && onAddPlayer != null) ...[
                    _AddPlayerWideButton(onTap: onAddPlayer!),
                    const SizedBox(height: 12),
                  ],
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: ratio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final p = players[i];
                    final name = _fio(p);
                    final pos = _s(p['position']).isEmpty ? 'Без позиции' : _s(p['position']);
                    final number = _s(p['number']);
                    final foot = _s(p['foot']);
                    final photo = _s(p['photo_url']).isNotEmpty ? _s(p['photo_url']) : _s(p['photo']);
                    final birth = _s(p['birth_date']);
                    final metrics = _s(p['metrics']).isNotEmpty ? _s(p['metrics']) : _s(p['sport_data']);

                    return _PlayerRosterCard(
                      name: name.isEmpty ? 'Игрок' : name,
                      position: pos,
                      number: number,
                      foot: foot,
                      birth: birth,
                      metrics: metrics,
                      photoUrl: photo,
                      canEdit: canEdit,
                      canOpen: canOpenPlayerProfile,
                      onTap: canOpenPlayerProfile ? () => onPlayerTap(p) : null,
                      onDelete: canEdit ? () => onPlayerDelete(p) : null,
                    );
                  },
                  childCount: players.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AddPlayerWideButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPlayerWideButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _RosterPalette.green.withOpacity(0.22)),
            boxShadow: const [
              BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 8)),
            ],
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFEAFBF1),
                child: Icon(Icons.person_add_alt_1_rounded, color: _RosterPalette.green),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Добавить игрока',
                      style: TextStyle(color: _RosterPalette.text, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Заполнить профиль, позицию, номер и спортивные данные',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _RosterPalette.muted, fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: _RosterPalette.green),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerRosterCard extends StatelessWidget {
  final String name;
  final String position;
  final String number;
  final String foot;
  final String birth;
  final String metrics;
  final String photoUrl;
  final bool canEdit;
  final bool canOpen;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _PlayerRosterCard({
    required this.name,
    required this.position,
    required this.number,
    required this.foot,
    required this.birth,
    required this.metrics,
    required this.photoUrl,
    required this.canEdit,
    required this.canOpen,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _SmartAvatar(name: name, photoUrl: photoUrl, size: 52, radius: 16, accent: _RosterPalette.green),
              if (number.isNotEmpty)
                Positioned(
                  right: -7,
                  bottom: -7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: _RosterPalette.text,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '№$number',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: _RosterPalette.text, fontSize: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  position,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _RosterPalette.muted, fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (foot.isNotEmpty) _MiniInfoPill(icon: Icons.directions_run_rounded, text: foot),
                    if (birth.isNotEmpty) _MiniInfoPill(icon: Icons.cake_rounded, text: birth.length >= 10 ? birth.substring(0, 10) : birth),
                    if (metrics.isNotEmpty) _MiniInfoPill(icon: Icons.query_stats_rounded, text: metrics),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (canEdit)
                PopupMenuButton<String>(
                  tooltip: 'Действия',
                  onSelected: (v) {
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Удалить из команды'),
                        ],
                      ),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.more_vert_rounded, color: _RosterPalette.muted),
                  ),
                ),
              if (canOpen) const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffTabModern extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyText;
  final ValueChanged<Map<String, dynamic>> onTapTrainer;

  const _StaffTabModern({
    super.key,
    required this.items,
    required this.emptyText,
    required this.onTapTrainer,
  });

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _fio(Map<String, dynamic> x) {
    final last = _s(x['last_name']);
    final first = _s(x['first_name']);
    final middle = _s(x['middle_name']);
    final fio = [last, first, middle].where((e) => e.isNotEmpty).join(' ');
    return fio.isEmpty ? _s(x['name']) : fio;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          _ModernEmptyState(icon: Icons.sports_rounded, title: 'Тренерский штаб пуст', text: emptyText),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 1180 ? 4 : (c.maxWidth >= 820 ? 3 : (c.maxWidth >= 560 ? 2 : 1));
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 3.1 : (columns == 2 ? 2.55 : 2.25),
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final t = items[i];
            final fio = _fio(t);
            final photo = _s(t['photo_url']).isNotEmpty ? _s(t['photo_url']) : _s(t['photo']);
            final position = _s(t['position']);
            final roleTitle = _s(t['role_title']);
            final email = _s(t['email']);
            final subtitle = position.isNotEmpty
                ? position
                : (roleTitle.isNotEmpty ? roleTitle : (email.isNotEmpty ? email : 'Тренер'));

            return _StaffCard(
              name: fio.isEmpty ? 'Тренер' : fio,
              subtitle: subtitle,
              photoUrl: photo,
              onTap: () => onTapTrainer(t),
            );
          },
        );
      },
    );
  }
}

class _StaffCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String photoUrl;
  final VoidCallback onTap;

  const _StaffCard({
    required this.name,
    required this.subtitle,
    required this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _SmartAvatar(name: name, photoUrl: photoUrl, size: 58, radius: 18, accent: _RosterPalette.blue),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: _RosterPalette.text, fontSize: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _RosterPalette.muted, fontWeight: FontWeight.w700, fontSize: 12, height: 1.25),
                ),
                const SizedBox(height: 8),
                const _MiniInfoPill(icon: Icons.chat_bubble_outline_rounded, text: 'Открыть визитку'),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}

class _PeopleTabModern extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyText;
  final IconData icon;
  final Color accent;

  const _PeopleTabModern({
    super.key,
    required this.items,
    required this.emptyText,
    required this.icon,
    required this.accent,
  });

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _fio(Map<String, dynamic> x) {
    final last = _s(x['last_name']);
    final first = _s(x['first_name']);
    final middle = _s(x['middle_name']);
    final fio = [last, first, middle].where((e) => e.isNotEmpty).join(' ');
    return fio.isEmpty ? _s(x['name']) : fio;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [_ModernEmptyState(icon: icon, title: 'Пока пусто', text: emptyText)],
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 1180 ? 4 : (c.maxWidth >= 820 ? 3 : (c.maxWidth >= 560 ? 2 : 1));
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 3.25 : (columns == 2 ? 2.75 : 2.45),
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final x = items[i];
            final fio = _fio(x);
            final roleTitle = _s(x['role_title']);
            final role = _s(x['role']);
            final email = _s(x['email']);
            final phone = _s(x['phone']);
            final photo = _s(x['photo_url']).isNotEmpty ? _s(x['photo_url']) : _s(x['photo']);
            final subtitle = roleTitle.isNotEmpty
                ? roleTitle
                : (role.isNotEmpty ? role : (email.isNotEmpty ? email : 'Пользователь'));

            return _PersonModernCard(
              name: fio.isEmpty ? 'Пользователь' : fio,
              subtitle: subtitle,
              email: email,
              phone: phone,
              photoUrl: photo,
              accent: accent,
            );
          },
        );
      },
    );
  }
}

class _PersonModernCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String email;
  final String phone;
  final String photoUrl;
  final Color accent;

  const _PersonModernCard({
    required this.name,
    required this.subtitle,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _SmartAvatar(name: name, photoUrl: photoUrl, size: 54, radius: 18, accent: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: _RosterPalette.text, fontSize: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _RosterPalette.muted, fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (email.isNotEmpty) _MiniInfoPill(icon: Icons.mail_outline_rounded, text: email),
                    if (phone.isNotEmpty) _MiniInfoPill(icon: Icons.phone_rounded, text: phone),
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

class _ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const _ModernCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _RosterPalette.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );

    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: box,
      ),
    );
  }
}

class _SmartAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;
  final double size;
  final double radius;
  final Color accent;

  const _SmartAvatar({
    required this.name,
    required this.photoUrl,
    required this.size,
    required this.radius,
    required this.accent,
  });

  String? _normalizeImage(String raw) {
    if (raw.trim().isEmpty) return null;
    var url = raw.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('www.sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('/')) return 'https://sportotekaapp.ru$url';
    if (url.startsWith('uploads/')) return 'https://sportotekaapp.ru/$url';
    return 'https://sportotekaapp.ru/uploads/$url';
  }

  @override
  Widget build(BuildContext context) {
    final url = _normalizeImage(photoUrl);
    final letter = (name.isNotEmpty ? name.substring(0, 1) : 'И').toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? _fallback(letter)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (_, __) => _fallback(letter),
              errorWidget: (_, __, ___) => _fallback(letter),
            ),
    );
  }

  Widget _fallback(String letter) {
    return Container(
      color: accent.withOpacity(0.10),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: size * 0.38),
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniInfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _RosterPalette.soft2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _RosterPalette.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _RosterPalette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _ModernEmptyState({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _RosterPalette.line),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: _RosterPalette.blueSoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: _RosterPalette.blue, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: _RosterPalette.text),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _RosterPalette.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _RosterLoadingView extends StatelessWidget {
  const _RosterLoadingView();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  _shimmerBox(width: 44, height: 44, radius: 16),
                  const SizedBox(width: 10),
                  Expanded(child: _shimmerBox(height: 44, radius: 16)),
                  const SizedBox(width: 10),
                  _shimmerBox(width: 44, height: 44, radius: 16),
                ],
              ),
              const SizedBox(height: 14),
              _shimmerBox(height: 210, radius: 28),
              const SizedBox(height: 14),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, __) => _shimmerBox(width: 152, height: 92, radius: 22),
                ),
              ),
              const SizedBox(height: 14),
              _shimmerBox(height: 56, radius: 22),
              const SizedBox(height: 16),
              ...List.generate(
                7,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _shimmerBox(height: 88, radius: 22),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  static Widget _shimmerBox({double? width, required double height, required double radius}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: Colors.white,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ErrorBlock({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _RosterPalette.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
                const SizedBox(height: 12),
                const Text('Ошибка загрузки', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 6),
                Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _RosterPalette.muted)),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Повторить')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ======================================================
// ✅ VIEW TRAINER PROFILE (ВИЗИТКА + КНОПКА ЧАТА)
// ======================================================
class TrainerProfileViewScreen extends StatefulWidget {
  final int trainerId;
  final String trainerName;
  final String? trainerPhotoRaw;
  final String? trainerEmailRaw;

  const TrainerProfileViewScreen({
    super.key,
    required this.trainerId,
    required this.trainerName,
    this.trainerPhotoRaw,
    this.trainerEmailRaw,
  });

  @override
  State<TrainerProfileViewScreen> createState() => _TrainerProfileViewScreenState();
}

class _TrainerProfileViewScreenState extends State<TrainerProfileViewScreen> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getUrl = '$apiBase/get_trainer_profile.php';
  static const String getOrCreateDirectChatUrl =
      'https://sportotekaapp.ru/api/get_or_create_direct_chat.php';

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _profile = {};

  String _s(dynamic v) => (v ?? '').toString().trim();

  Map<String, dynamic> _decode(String s) {
    try {
      final j = jsonDecode(s);
      return j is Map ? Map<String, dynamic>.from(j) : {};
    } catch (_) {
      return {};
    }
  }

  String? _normalizeImage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var url = raw.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('www.sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('/')) return 'https://sportotekaapp.ru$url';
    if (url.startsWith('uploads/')) return 'https://sportotekaapp.ru/$url';
    return 'https://sportotekaapp.ru/uploads/$url';
  }

  int _pickTrainerUserIdForChat(Map<String, dynamic> p) {
    int asInt(dynamic v) => v is int ? v : int.tryParse((v ?? '').toString()) ?? 0;
    final candidates = [p['user_id'], p['trainer_user_id'], p['uid'], p['id']];
    for (final c in candidates) {
      final v = asInt(c);
      if (v > 0) return v;
    }
    return 0;
  }

  Future<int?> _getOrCreateDirectChat({required int myUserId, required int otherUserId}) async {
    try {
      final res = await http.post(
        Uri.parse(getOrCreateDirectChatUrl),
        body: {'user_id': myUserId.toString(), 'other_user_id': otherUserId.toString()},
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is Map) {
        final ok = data['success'] == true || data['status'] == 'success';
        if (!ok) return null;
        return int.tryParse((data['chat_id'] ?? data['id'] ?? '').toString());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openChatToTrainer({required String trainerName}) async {
    final myId = (await PrefUtils.getUserId()) ?? 0;
    if (myId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не найден userId. Перезайдите в аккаунт.')),
      );
      return;
    }

    final trainerUserId = _pickTrainerUserIdForChat(_profile);
    if (trainerUserId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не найден user_id тренера в профиле. Ключи: ${_profile.keys.toList()}')),
      );
      return;
    }

    final chatId = await _getOrCreateDirectChat(myUserId: myId, otherUserId: trainerUserId);
    if (chatId == null || chatId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать/открыть чат')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(chatId: chatId, userId: myId, chatName: trainerName),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http.post(
        Uri.parse(getUrl),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'trainer_id': widget.trainerId}),
      );
      final data = _decode(resp.body);
      final ok = data['status'] == 'success' || data['success'] == true;
      final obj = data['trainer'] ?? data['profile'];
      if (ok && obj is Map) {
        _profile = Map<String, dynamic>.from(obj);
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _isLoading = false;
          _error = _s(data['message']).isEmpty ? 'Не удалось загрузить' : _s(data['message']);
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Ошибка загрузки: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _normalizeImage(
      _s(_profile['photo_url']).isNotEmpty
          ? _s(_profile['photo_url'])
          : (_s(_profile['photo']).isNotEmpty ? _s(_profile['photo']) : (widget.trainerPhotoRaw ?? '')),
    );
    final email = _s(_profile['email']).isNotEmpty ? _s(_profile['email']) : _s(widget.trainerEmailRaw);
    final position = _s(_profile['position']);
    final bio = _s(_profile['bio']);
    final birthdayRaw = _s(_profile['birthday']);
    final birthday = birthdayRaw.length >= 10 ? birthdayRaw.substring(0, 10) : birthdayRaw;
    final experience = _s(_profile['experience']);
    final displayName = widget.trainerName.isEmpty ? 'Тренер #${widget.trainerId}' : widget.trainerName;

    return Scaffold(
      backgroundColor: _RosterPalette.bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _RosterPalette.green))
            : _error != null
                ? _TrainerErrorState(error: _error!, onRetry: _loadProfile)
                : RefreshIndicator(
                    color: _RosterPalette.green,
                    onRefresh: () async => _loadProfile(),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: _RosterTopBar(
                              onBack: () => Get.back(),
                              onRefresh: _loadProfile,
                              onPrint: () {},
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: _TrainerHeroCard(
                              name: displayName,
                              email: email,
                              photo: photo,
                              position: position,
                              trainerId: widget.trainerId,
                              onChatTap: () => _openChatToTrainer(trainerName: displayName),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              if (birthday.isNotEmpty)
                                _TrainerInfoCard(icon: Icons.cake_rounded, title: 'Дата рождения', content: birthday),
                              if (birthday.isNotEmpty) const SizedBox(height: 12),
                              if (experience.isNotEmpty)
                                _TrainerInfoCard(icon: Icons.work_history_rounded, title: 'Опыт / карьера', content: experience),
                              if (experience.isNotEmpty) const SizedBox(height: 12),
                              if (bio.isNotEmpty)
                                _TrainerInfoCard(icon: Icons.description_rounded, title: 'О тренере', content: bio),
                              if (birthday.isEmpty && experience.isEmpty && bio.isEmpty) const _TrainerEmptyInfoHint(),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _TrainerHeroCard extends StatelessWidget {
  final String name;
  final String email;
  final String? photo;
  final String position;
  final int trainerId;
  final VoidCallback onChatTap;

  const _TrainerHeroCard({
    required this.name,
    required this.email,
    required this.photo,
    required this.position,
    required this.trainerId,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      color: Colors.white,
      child: Row(
        children: <Widget>[
          _TrainerCircleNetworkImage(
            imageUrl: photo,
            size: 58,
            borderColor:
                _RosterPalette.line,
            borderWidth: 1,
            fallback: Container(
              color:
                  _RosterPalette.soft,
              alignment:
                  Alignment.center,
              child:
                  const _RosterDots(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      AppTypography.custom(
                    size: 13,
                    weight:
                        FontWeight.w600,
                    color:
                        _RosterPalette.text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  position.isNotEmpty
                      ? position
                      : (email.isNotEmpty
                          ? email
                          : 'ID $trainerId'),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      AppTypography.custom(
                    size: 9.1,
                    weight:
                        FontWeight.w400,
                    color:
                        _RosterPalette.muted,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          _RosterTextAction(
            label: 'Написать',
            onTap: onChatTap,
          ),
        ],
      ),
    );
  }
}

class _TrainerInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _TrainerInfoCard({required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _RosterPalette.green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: _RosterPalette.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _RosterPalette.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(fontSize: 15, color: _RosterPalette.muted, height: 1.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TrainerCircleNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double borderWidth;
  final Color borderColor;
  final Color? glow;
  final Widget fallback;

  const _TrainerCircleNetworkImage({
    required this.imageUrl,
    required this.size,
    required this.borderWidth,
    required this.borderColor,
    required this.fallback,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: glow != null ? [BoxShadow(color: glow!, blurRadius: 22, offset: const Offset(0, 10))] : null,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: (imageUrl == null || imageUrl!.isEmpty)
            ? fallback
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => const Center(
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _TrainerEmptyInfoHint extends StatelessWidget {
  const _TrainerEmptyInfoHint();

  @override
  Widget build(BuildContext context) {
    return const _ModernEmptyState(
      icon: Icons.info_outline_rounded,
      title: 'Информация не заполнена',
      text: 'Дата рождения, опыт и описание тренера пока не добавлены.',
    );
  }
}

class _TrainerErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _TrainerErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _ErrorBlock(text: error, onRetry: onRetry);
  }
}
