import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/theme/app_typography.dart';

import 'package:sportoteka/presentation/player_screen/player_id_resolver.dart';
import 'package:sportoteka/presentation/player_screen/widgets/player_self_rating_sheet.dart';


class _SaColors {
  static const Color green =
      Color(0xFF00A750);
  static const Color greenDark =
      Color(0xFF067A46);
  static const Color greenSoft =
      Color(0xFFF3FAF6);
  static const Color text =
      Color(0xFF0B0F14);
  static const Color muted =
      Color(0xFF667085);
  static const Color muted2 =
      Color(0xFF98A2B3);
  static const Color soft =
      Color(0xFFF7F9F8);
  static const Color line =
      Color(0xFFEDF0EE);
  static const Color amber =
      Color(0xFFF59E0B);
  static const Color red =
      Color(0xFFD92D20);
}

class _SaText {
  static TextStyle title(
    double size,
  ) =>
      AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _SaColors.text,
        height: 1.12,
      );

  static TextStyle body(
    double size, {
    Color color =
        _SaColors.muted,
    FontWeight weight =
        FontWeight.w400,
  }) =>
      AppTypography.custom(
        size: size,
        weight: weight,
        color: color,
        height: 1.22,
      );
}

class _SaDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _SaDot({
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

class _SaDots extends StatelessWidget {
  final Color color;
  final bool compact;

  const _SaDots({
    this.color = _SaColors.green,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scale =
        compact ? .76 : 1.0;
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: <Widget>[
        _SaDot(
          color: color,
          size: 3.4 * scale,
          opacity: .32,
        ),
        SizedBox(width: 3 * scale),
        _SaDot(
          color: color,
          size: 4.4 * scale,
          opacity: .55,
        ),
        SizedBox(width: 3 * scale),
        _SaDot(
          color: color,
          size: 5.4 * scale,
          opacity: .78,
        ),
        SizedBox(width: 3 * scale),
        _SaDot(
          color: color,
          size: 6.4 * scale,
        ),
      ],
    );
  }
}

class _SaAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SaAction({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _SaColors.greenSoft,
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
            horizontal: 9,
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: <Widget>[
              const _SaDot(
                color:
                    _SaColors.green,
                size: 5,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: _SaText.body(
                  8.8,
                  color:
                      _SaColors.greenDark,
                  weight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RateFilter { all, unrated, rated }

class PlayerSelfAssessmentScreen extends StatefulWidget {
  final int? teamId;
  final int? userId;
  final int? playerId;
  final bool readOnly;
  final bool embedded;

  const PlayerSelfAssessmentScreen({
    super.key,
    this.teamId,
    this.userId,
    this.playerId,
    this.readOnly = false,
    this.embedded = false,
  });

  @override
  State<PlayerSelfAssessmentScreen> createState() => _PlayerSelfAssessmentScreenState();
}

class _PlayerSelfAssessmentScreenState extends State<PlayerSelfAssessmentScreen> {
  static const apiBase = "https://sportotekaapp.ru/api";

  bool loading = true;
  String? error;

  int teamId = 0;
  int userId = 0;
  int playerId = 0;

  List<Map<String, dynamic>> pastEvents = [];
  final Map<int, Map<String, dynamic>> myByEventId = {}; // event_id -> {rating,note}

  _RateFilter filter = _RateFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  int _asInt(dynamic v) => v is int ? v : int.tryParse("${v ?? 0}") ?? 0;
  String _asStr(dynamic v) => (v ?? "").toString();

  String _eventTitle(Map<String, dynamic> e) {
    final t = _asStr(e["title"]).trim();
    final n = _asStr(e["name"]).trim();
    return t.isNotEmpty ? t : (n.isNotEmpty ? n : "Тренировка");
  }

  String _eventDate(Map<String, dynamic> e) {
    final s1 = _asStr(e["end_at"]).trim();
    final s2 = _asStr(e["start_at"]).trim();
    return s2.isNotEmpty ? s2 : s1;
  }

  String _eventEnd(Map<String, dynamic> e) => _asStr(e["end_at"]).trim();

  DateTime? _parseMySqlDateTime(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    if (s.contains(".")) s = s.split(".").first;
    s = s.replaceAll("T", " ");

    final parts = s.split(" ");
    if (parts.isEmpty) return null;

    final dp = parts[0].split("-");
    if (dp.length != 3) return null;

    final y = int.tryParse(dp[0]) ?? 0;
    final m = int.tryParse(dp[1]) ?? 0;
    final d = int.tryParse(dp[2]) ?? 0;
    if (y == 0 || m == 0 || d == 0) return null;

    int hh = 0, mm = 0, ss = 0;
    if (parts.length > 1) {
      final tp = parts[1].split(":");
      if (tp.isNotEmpty) hh = int.tryParse(tp[0]) ?? 0;
      if (tp.length > 1) mm = int.tryParse(tp[1]) ?? 0;
      if (tp.length > 2) ss = int.tryParse(tp[2]) ?? 0;
    }

    return DateTime(y, m, d, hh, mm, ss);
  }

  bool _isPast(Map<String, dynamic> e) {
    final endDt = _parseMySqlDateTime(_eventEnd(e));
    final startDt = _parseMySqlDateTime(_asStr(e["start_at"]).trim());
    final now = DateTime.now();

    if (endDt != null) return endDt.isBefore(now);
    if (startDt != null) return startDt.isBefore(now);
    return true;
  }

  Future<void> _init() async {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (widget.teamId != null || widget.userId != null) {
      teamId = widget.teamId ?? 0;
      userId = widget.userId ?? 0;
    } else if (args is Map) {
      teamId = _asInt(args["team_id"]);
      userId = _asInt(args["user_id"]);
    } else {
      teamId = 0;
      userId = 0;
    }

    if (teamId <= 0 || userId <= 0) {
      setState(() {
        loading = false;
        error = "team_id/user_id не передан";
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    final pid = (widget.playerId ?? 0) > 0
        ? widget.playerId!
        : await PlayerIdResolver.resolvePlayerId(apiBase: apiBase, userId: userId);
    if (!mounted) return;

    if (pid <= 0) {
      setState(() {
        loading = false;
        error = "Не удалось определить player_id";
      });
      return;
    }

    playerId = pid;
    await _loadEventsAndMy();
  }

  Future<void> _loadEventsAndMy() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final r1 = await http
          .get(Uri.parse("$apiBase/get_team_events.php?team_id=$teamId"))
          .timeout(const Duration(seconds: 12));

      final d1 = jsonDecode(r1.body);
      if (d1 is Map && d1["success"] != true && d1["status"] != "success") {
        throw (d1["message"] ?? "Не удалось загрузить тренировки").toString();
      }

      final list = (d1 is Map ? (d1["items"] ?? d1["events"] ?? []) : []) as List;
      final events = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      final r2 = await http
          .get(Uri.parse("$apiBase/get_my_self_assessments.php?team_id=$teamId&player_id=$playerId"))
          .timeout(const Duration(seconds: 12));

      final d2 = jsonDecode(r2.body);

      myByEventId.clear();
      if (d2 is Map && (d2["success"] == true || d2["status"] == "success")) {
        final items2 = (d2["items"] ?? d2["data"] ?? []) as List;
        for (final x in items2) {
          if (x is Map) {
            final m = Map<String, dynamic>.from(x);
            final eid = _asInt(m["event_id"]);
            if (eid > 0) myByEventId[eid] = m;
          }
        }
      }

      final past = events.where(_isPast).toList();
      past.sort((a, b) => _asStr(b["start_at"]).compareTo(_asStr(a["start_at"])));

      if (!mounted) return;
      setState(() {
        pastEvents = past;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
        pastEvents = [];
      });
    }
  }

  Future<void> _openEvent(Map<String, dynamic> e) async {
    if (widget.readOnly) {
      await _openActionsSheet(e);
      return;
    }
    final eventId = _asInt(e["id"]);
    if (eventId <= 0) return;

    final title = "${_eventTitle(e)} • ${_eventDate(e)}";

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerSelfRatingSheet(
        apiBase: apiBase,
        teamId: teamId,
        eventId: eventId,
        playerId: playerId,
        title: title,
      ),
    );

    if (saved == true) {
      await _loadEventsAndMy();
    }
  }

  // ===================== UI (как TeamCalendarScreen) =====================

  static const Color _bg = Colors.white;

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(12)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _SaColors.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  Widget _pill(
    String text,
    bool active,
    VoidCallback onTap, {
    required Color primary,
  }) {
    return Expanded(
      child: Material(
        color: active
            ? _SaColors.greenSoft
            : _SaColors.soft,
        borderRadius:
            BorderRadius.circular(9),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Center(
              child: Text(
                text,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: _SaText.body(
                  9.2,
                  color: active
                      ? _SaColors.greenDark
                      : _SaColors.muted,
                  weight:
                      FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredList() {
    if (filter == _RateFilter.all) return pastEvents;

    return pastEvents.where((e) {
      final eid = _asInt(e["id"]);
      final rated = myByEventId.containsKey(eid);
      if (filter == _RateFilter.rated) return rated;
      return !rated;
    }).toList();
  }

  Future<void> _openActionsSheet(Map<String, dynamic> e) async {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final primary = Theme.of(context).colorScheme.primary;

    final eid = _asInt(e["id"]);
    final mine = myByEventId[eid];
    final rated = mine != null;
    final rt = rated ? _asInt(mine["rating"]) : 0;
    final note = rated ? _asStr(mine["note"]).trim() : "";

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + pad),
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _eventTitle(e),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Закрыть"),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _eventDate(e),
                    style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),

                if (rated) ...[
                  _card(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.star_rounded, color: primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Моя оценка: ★ $rt/5", style: const TextStyle(fontWeight: FontWeight.w900)),
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(note, style: const TextStyle(color: Color(0xFF374151), fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                if (!widget.readOnly) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _openEvent(e);
                      },
                      icon: Icon(rated ? Icons.edit : Icons.check_circle_outline),
                      label: Text(rated ? "Изменить оценку" : "Оценить"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _assessmentTile(
    Map<String, dynamic> event, {
    bool closeSheetFirst = false,
  }) {
    final eventId =
        _asInt(event['id']);
    final title =
        _eventTitle(event);
    final date =
        _eventDate(event);
    final mine =
        myByEventId[eventId];
    final rated = mine != null;
    final rating = rated
        ? _asInt(mine['rating'])
        : 0;

    return Material(
      color: _SaColors.soft,
      borderRadius:
          BorderRadius.circular(10),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(10),
        onTap: () async {
          if (closeSheetFirst) {
            Navigator.pop(context);
            await Future<void>.delayed(
              const Duration(
                milliseconds: 80,
              ),
            );
          }
          await _openEvent(event);
        },
        onLongPress: () =>
            _openActionsSheet(event),
        child: Container(
          constraints:
              const BoxConstraints(
            minHeight: 58,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          child: Row(
            children: <Widget>[
              _SaDot(
                color: rated
                    ? _SaColors.green
                    : _SaColors.amber,
                size: 6,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          _SaText.title(10.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      date,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          _SaText.body(8.7),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rated
                    ? '$rating / 5'
                    : 'Оценить',
                style: _SaText.body(
                  9,
                  color: rated
                      ? _SaColors.greenDark
                      : _SaColors.amber,
                  weight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color:
                    _SaColors.muted2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        _filteredList();

    int countRated() {
      var count = 0;
      for (final event
          in pastEvents) {
        if (myByEventId.containsKey(
          _asInt(event['id']),
        )) {
          count++;
        }
      }
      return count;
    }

    final ratedCount =
        countRated();
    final totalCount =
        pastEvents.length;
    final unratedCount =
        (totalCount - ratedCount)
            .clamp(0, totalCount);

    Widget content() {
      if (loading) {
        return const Center(
          child:
              CircularProgressIndicator(
            strokeWidth: 2,
            color: _SaColors.green,
          ),
        );
      }

      if (error != null) {
        return Center(
          child: Padding(
            padding:
                const EdgeInsets.all(18),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: <Widget>[
                const _SaDots(
                  color:
                      _SaColors.red,
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  'Не удалось загрузить',
                  style:
                      _SaText.title(11.5),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  error!,
                  textAlign:
                      TextAlign.center,
                  style:
                      _SaText.body(9),
                ),
                const SizedBox(
                  height: 10,
                ),
                _SaAction(
                  label: 'Повторить',
                  onTap:
                      _loadEventsAndMy,
                ),
              ],
            ),
          ),
        );
      }

      return ListView(
        padding:
            const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          20,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              const _SaDots(),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Самооценка',
                      style:
                          _SaText.title(
                        13,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      '$ratedCount оценено · $unratedCount ожидают оценки',
                      style:
                          _SaText.body(
                        8.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _pill(
                'Все $totalCount',
                filter ==
                    _RateFilter.all,
                () => setState(
                  () => filter =
                      _RateFilter.all,
                ),
                primary:
                    _SaColors.green,
              ),
              const SizedBox(width: 6),
              _pill(
                'Не оценено $unratedCount',
                filter ==
                    _RateFilter.unrated,
                () => setState(
                  () => filter =
                      _RateFilter.unrated,
                ),
                primary:
                    _SaColors.green,
              ),
              const SizedBox(width: 6),
              _pill(
                'Оценено $ratedCount',
                filter ==
                    _RateFilter.rated,
                () => setState(
                  () => filter =
                      _RateFilter.rated,
                ),
                primary:
                    _SaColors.green,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
                vertical: 22,
              ),
              decoration:
                  BoxDecoration(
                color:
                    _SaColors.soft,
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: Column(
                children: <Widget>[
                  const _SaDots(
                    color:
                        _SaColors.muted2,
                  ),
                  const SizedBox(
                    height: 9,
                  ),
                  Text(
                    'Ничего не найдено',
                    style:
                        _SaText.title(
                      10.8,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    'Измените выбранный фильтр',
                    style:
                        _SaText.body(
                      8.8,
                    ),
                  ),
                ],
              ),
            )
          else
            ...filtered.map(
              (event) => Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 5,
                ),
                child:
                    _assessmentTile(
                  event,
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor:
          Colors.white,
      appBar: widget.embedded
          ? null
          : AppBar(
              toolbarHeight: 56,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor:
                  Colors.white,
              surfaceTintColor:
                  Colors.transparent,
              titleSpacing: 12,
              title: Row(
                children: <Widget>[
                  const _SaDots(),
                  const SizedBox(
                    width: 9,
                  ),
                  Text(
                    'Самооценка',
                    style:
                        _SaText.title(
                      13.5,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                _SaAction(
                  label: 'Обновить',
                  onTap:
                      _loadEventsAndMy,
                ),
                const SizedBox(
                  width: 10,
                ),
              ],
              bottom:
                  const PreferredSize(
                preferredSize:
                    Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  thickness: .6,
                  color:
                      _SaColors.line,
                ),
              ),
            ),
      body: content(),
    );
  }

  Future<void> _showAllSheet(
    List<Map<String, dynamic>> list,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            constraints:
                BoxConstraints(
              maxHeight:
                  MediaQuery.sizeOf(
                            context,
                          )
                          .height *
                      .82,
            ),
            padding:
                const EdgeInsets.fromLTRB(
              12,
              10,
              12,
              16,
            ),
            decoration:
                const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(
                top:
                    Radius.circular(20),
              ),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color:
                        _SaColors.line,
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Row(
                  children: <Widget>[
                    const _SaDots(
                      compact: true,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child: Text(
                        'Все тренировки (${list.length})',
                        style:
                            _SaText.title(
                          11.5,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(
                        context,
                      ),
                      child: Text(
                        'Закрыть',
                        style:
                            _SaText.body(
                          9,
                          color:
                              _SaColors
                                  .greenDark,
                          weight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 8,
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount:
                        list.length,
                    separatorBuilder:
                        (_, __) =>
                            const SizedBox(
                      height: 5,
                    ),
                    itemBuilder:
                        (_, index) =>
                            _assessmentTile(
                      list[index],
                      closeSheetFirst:
                          true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}
