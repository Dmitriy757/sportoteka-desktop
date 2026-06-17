// lib/presentation/player_matches_screen/player_matches_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/player_screen/player_match_detail_screen.dart';

class PlayerMatchesScreen extends StatefulWidget {
  const PlayerMatchesScreen({super.key});

  @override
  State<PlayerMatchesScreen> createState() => _PlayerMatchesScreenState();
}

enum _MatchesFilter { all, upcoming, past }

class _PlayerMatchesScreenState extends State<PlayerMatchesScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getMatchesUrl = "$apiBase/get_team_matches.php";
  static const String getUserUrl = "$apiBase/get_user.php";

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> matches = [];
  bool loading = true;
  String? error;

  late int teamId;
  late String teamName;

  int userId = 0;
  int playerId = 0;
  String playerName = "Игрок";

  _MatchesFilter _filter = _MatchesFilter.upcoming;

  Color get primary => const Color(0xFF00C853);
  Color get bg => const Color(0xFFF3F5F8);
  Color get cardBg => Colors.white;
  Color get textPrimary => const Color(0xFF1E293B);
  Color get textSecondary => const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    teamId = _readTeamId(Get.arguments);
    teamName = _readTeamName(Get.arguments);
    _searchCtrl.addListener(_onSearchChanged);
    _init();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final uid = await PrefUtils.getUserId();
      userId = uid ?? 0;

      if (userId <= 0) {
        throw "Не удалось определить пользователя";
      }

      await _loadCurrentPlayer();
      await _loadMatches();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _loadCurrentPlayer() async {
    final uri = Uri.parse("$getUserUrl?user_id=$userId");
    final res = await http.get(uri).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw "Ошибка загрузки профиля игрока";
    }

    final raw = res.body.trim();
    if (raw.isEmpty) {
      throw "Пустой ответ сервера";
    }

    final data = jsonDecode(raw);

    if (data is! Map || data["success"] != true) {
      throw (data is Map ? data["error"] ?? data["message"] : "Ошибка профиля")
          .toString();
    }

    final player = data["player"];
    final user = data["user"];

    if (player is Map) {
      playerId = _asInt(player["id"]);
      final firstName = _asStr(player["first_name"]);
      final lastName = _asStr(player["last_name"]);
      final fullName = "$firstName $lastName".trim();
      if (fullName.isNotEmpty) {
        playerName = fullName;
      }
    }

    if (playerId <= 0 && user is Map) {
      final firstName = _asStr(user["first_name"]);
      final lastName = _asStr(user["last_name"]);
      final fullName = "$firstName $lastName".trim();
      if (fullName.isNotEmpty) {
        playerName = fullName;
      }
    }

    if (playerId <= 0) {
      throw "Для этого пользователя не найден профиль игрока";
    }
  }

  Future<void> _loadMatches() async {
    try {
      final res = await http.post(
        Uri.parse(getMatchesUrl),
        headers: const {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: jsonEncode({
          "team_id": teamId,
        }),
      ).timeout(const Duration(seconds: 20));

      final raw = res.body.trim();
      final jsonStart = raw.indexOf('{');

      if (jsonStart == -1) {
        throw "Сервер вернул некорректный ответ";
      }

      final cleanJson = raw.substring(jsonStart);
      final data = jsonDecode(cleanJson);

      if (data is Map &&
          (data["status"] == "success" || data["success"] == true)) {
        final list = (data["matches"] as List?) ?? [];

        matches = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        matches.sort((a, b) {
          final da = _parseDate(_asStr(a["match_date"]));
          final db = _parseDate(_asStr(b["match_date"]));
          return da.compareTo(db);
        });

        if (!mounted) return;
        setState(() {
          loading = false;
          error = null;
        });
      } else {
        throw data["message"]?.toString() ?? "Не удалось загрузить матчи";
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _refresh() async {
    await _loadMatches();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() {});
    });
  }

  int _readTeamId(dynamic arg) {
    if (arg is int) return arg;
    if (arg is String) return int.tryParse(arg) ?? 0;
    if (arg is Map) {
      final v = arg["teamId"] ?? arg["team_id"] ?? arg["id"];
      return int.tryParse(v?.toString() ?? "") ?? 0;
    }
    return 0;
  }

  String _readTeamName(dynamic arg) {
    if (arg is Map) {
      final v = arg["teamName"] ?? arg["team_name"] ?? arg["name"];
      return (v ?? "").toString().trim();
    }
    return "";
  }

  int _asInt(dynamic v) => v is int ? v : int.tryParse("${v ?? 0}") ?? 0;
  String _asStr(dynamic v) => (v ?? "").toString().trim();

  DateTime _parseDate(String s) {
    try {
      final t = s.trim();

      if (t.contains('.')) {
        final p = t.split('.');
        if (p.length == 3) {
          final dd = int.tryParse(p[0]) ?? 1;
          final mm = int.tryParse(p[1]) ?? 1;
          final yy = int.tryParse(p[2]) ?? 2000;
          return DateTime(yy, mm, dd);
        }
      }

      final d = DateTime.tryParse(t);
      if (d != null) return DateTime(d.year, d.month, d.day);
    } catch (_) {}

    return DateTime(2000, 1, 1);
  }

  String _formatRu(DateTime d) {
    String two(int v) => v.toString().padLeft(2, "0");
    return "${two(d.day)}.${two(d.month)}.${d.year}";
  }

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

  List<Map<String, dynamic>> _filteredMatches() {
    final q = _searchCtrl.text.trim().toLowerCase();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Iterable<Map<String, dynamic>> list = matches;

    if (_filter == _MatchesFilter.upcoming) {
      list = list.where((m) => !_parseDate(_asStr(m["match_date"])).isBefore(today));
    } else if (_filter == _MatchesFilter.past) {
      list = list.where((m) => _parseDate(_asStr(m["match_date"])).isBefore(today));
    }

    if (q.isNotEmpty) {
      list = list.where((m) {
        final opponent = _asStr(m["opponent"]).toLowerCase();
        final competition = _asStr(m["competition_name"]).toLowerCase();
        final date = _asStr(m["match_date"]).toLowerCase();
        final eventType = _asStr(m["event_type"]).toLowerCase();

        return opponent.contains(q) ||
            competition.contains(q) ||
            date.contains(q) ||
            eventType.contains(q);
      });
    }

    final out = list.toList();
    out.sort((a, b) {
      return _parseDate(_asStr(a["match_date"]))
          .compareTo(_parseDate(_asStr(b["match_date"])));
    });

    return out;
  }

  Map<String, List<Map<String, dynamic>>> _groupByMonth(
    List<Map<String, dynamic>> list,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};

    for (final m in list) {
      final d = _parseDate(_asStr(m["match_date"]));
      final key = "${_monthRu(d.month)} ${d.year}";
      map.putIfAbsent(key, () => []);
      map[key]!.add(m);
    }

    return map;
  }

  String _monthRu(int m) {
    const months = [
      "январь",
      "февраль",
      "март",
      "апрель",
      "май",
      "июнь",
      "июль",
      "август",
      "сентябрь",
      "октябрь",
      "ноябрь",
      "декабрь"
    ];
    if (m < 1 || m > 12) return "месяц";
    return months[m - 1];
  }

  Widget _matteSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredMatches();
    final grouped = _groupByMonth(list);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Матчи игрока",
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              playerName,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : _refresh,
            icon: Icon(Icons.refresh_rounded, color: primary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    _matteSurface(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: "Поиск по сопернику, турниру или дате",
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _PlayerFilterChip(
                            label: "Все",
                            icon: Icons.layers_outlined,
                            selected: _filter == _MatchesFilter.all,
                            onTap: () => setState(() => _filter = _MatchesFilter.all),
                          ),
                          const SizedBox(width: 8),
                          _PlayerFilterChip(
                            label: "Предстоящие",
                            icon: Icons.schedule_rounded,
                            selected: _filter == _MatchesFilter.upcoming,
                            onTap: () =>
                                setState(() => _filter = _MatchesFilter.upcoming),
                          ),
                          const SizedBox(width: 8),
                          _PlayerFilterChip(
                            label: "Прошедшие",
                            icon: Icons.history_rounded,
                            selected: _filter == _MatchesFilter.past,
                            onTap: () => setState(() => _filter = _MatchesFilter.past),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _matteSurface(
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.insights_rounded, color: primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Здесь ты можешь смотреть предстоящие и прошедшие матчи, а также открывать детальный ТТД-анализ по себе.",
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            if (loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: List.generate(
                      5,
                      (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _matteSurface(
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 12,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5E7EB),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      height: 12,
                                      width: 140,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5E7EB),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _matteSurface(
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            else if (matches.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _matteSurface(
                    child: Text(
                      "Матчей пока нет.",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            else if (list.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _matteSurface(
                    child: Text(
                      "По текущему фильтру матчи не найдены.",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    grouped.entries.expand((entry) sync* {
                      yield _PlayerMonthHeader(
                        title: entry.key,
                        count: entry.value.length,
                      );
                      yield const SizedBox(height: 10);

                      for (final m in entry.value) {
                        final d = _parseDate(_asStr(m["match_date"]));
                        final upcoming = _isUpcoming(d);

                        yield Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PlayerMatchTile(
                            primary: primary,
                            opponent: _asStr(m["opponent"]),
                            eventType: _eventTypeLabel(_asStr(m["event_type"])),
                            competitionName: _asStr(m["competition_name"]),
                            date: _formatRu(d),
                            score:
                                "${_asStr(m["our_score"]).isEmpty ? "0" : _asStr(m["our_score"])}:"
                                "${_asStr(m["opponent_score"]).isEmpty ? "0" : _asStr(m["opponent_score"])}",
                            upcoming: upcoming,
                            onTap: () {
                              Get.to(
                                () => PlayerMatchDetailScreen(
                                  matchId: _asInt(m["id"]),
                                  playerId: playerId,
                                  playerName: playerName,
                                  opponent: _asStr(m["opponent"]),
                                  tournament: _asStr(m["competition_name"]),
                                  score:
                                      "${_asStr(m["our_score"]).isEmpty ? "0" : _asStr(m["our_score"])}:"
                                      "${_asStr(m["opponent_score"]).isEmpty ? "0" : _asStr(m["opponent_score"])}",
                                  matchDate: _asStr(m["match_date"]),
                                  videoUrl: _asStr(
                                    m["video_url"].toString().isNotEmpty
                                        ? m["video_url"]
                                        : m["match_video_url"],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PlayerFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFE8F5E9) : Colors.white;
    final border = selected ? const Color(0xFF81C784) : const Color(0xFFE5E7EB);
    final text = selected ? const Color(0xFF1B5E20) : const Color(0xFF334155);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: text),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerMonthHeader extends StatelessWidget {
  final String title;
  final int count;

  const _PlayerMonthHeader({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            "$count",
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _PlayerMatchTile extends StatelessWidget {
  final Color primary;
  final String opponent;
  final String eventType;
  final String competitionName;
  final String date;
  final String score;
  final bool upcoming;
  final VoidCallback onTap;

  const _PlayerMatchTile({
    required this.primary,
    required this.opponent,
    required this.eventType,
    required this.competitionName,
    required this.date,
    required this.score,
    required this.upcoming,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeBg = upcoming ? const Color(0xFFEFFDF5) : const Color(0xFFF1F5F9);
    final badgeBorder = upcoming ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB);
    final badgeText = upcoming ? const Color(0xFF166534) : const Color(0xFF334155);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.sports_soccer_rounded, color: primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opponent.isEmpty ? "Соперник" : opponent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      eventType,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    if (competitionName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        competitionName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: badgeBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                upcoming ? Icons.schedule_rounded : Icons.history_rounded,
                                size: 16,
                                color: badgeText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                date,
                                style: TextStyle(
                                  color: badgeText,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            "Счёт: $score",
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}