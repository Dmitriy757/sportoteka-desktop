import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:sportoteka/presentation/team_video_analysis/match_video_player_screen.dart';

class PlayerMatchDetailScreen extends StatefulWidget {
  final int matchId;
  final int playerId;
  final String playerName;
  final String? opponent;
  final String? tournament;
  final String? score;
  final String? matchDate;
  final String? videoUrl;

  const PlayerMatchDetailScreen({
    super.key,
    required this.matchId,
    required this.playerId,
    required this.playerName,
    this.opponent,
    this.tournament,
    this.score,
    this.matchDate,
    this.videoUrl,
  });

  @override
  State<PlayerMatchDetailScreen> createState() =>
      _PlayerMatchDetailScreenState();
}

class _PlayerMatchDetailScreenState extends State<PlayerMatchDetailScreen> {
  static const String _apiBase = "https://sportotekaapp.ru/api";

  bool isLoading = true;
  String? error;

  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> episodes = [];
  List<Map<String, dynamic>> mainReport = [];
  List<Map<String, dynamic>> passReport = [];
  List<Map<String, dynamic>> goalkeeperReport = [];
  List<Map<String, dynamic>> playerVideoTotals = [];

  Map<String, dynamic>? selectedPlayerMain;
  Map<String, dynamic>? selectedPlayerPass;
  Map<String, dynamic>? selectedPlayerGoalkeeper;
  Map<String, dynamic>? selectedPlayerTotals;
  List<Map<String, dynamic>> selectedPlayerEpisodes = [];

  int _asInt(dynamic v) => v is int ? v : int.tryParse("${v ?? 0}") ?? 0;
  String _asStr(dynamic v) => (v ?? "").toString();

  Color get primary => const Color(0xFF00C853);
  Color get bg => const Color(0xFFF3F5F8);
  Color get cardBg => Colors.white;
  Color get textPrimary => const Color(0xFF1E293B);
  Color get textSecondary => const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadMatchDetail();
  }

  String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    return "https://sportotekaapp.ru${s.startsWith('/') ? s : '/$s'}";
  }

  void _watchVideo() {
    final normalized = _normalizeUrl(widget.videoUrl) ?? "";
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Видео отсутствует")),
      );
      return;
    }

    Get.to(
      () => MatchVideoPlayerScreen(
        videoUrl: normalized,
        title: "Матч — ${widget.playerName}",
      ),
    );
  }

  Future<void> _loadMatchDetail() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final uri = Uri.parse(
        "$_apiBase/get_match_ttd_report.php?match_id=${widget.matchId}",
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        throw "Ошибка сервера: ${res.statusCode}";
      }

      final body = res.body.trim();
      if (body.isEmpty) {
        throw "Сервер вернул пустой ответ";
      }

      final data = jsonDecode(body);

      if (data is! Map || data["success"] != true) {
        throw (data is Map
                ? (data["message"] ?? "Ошибка загрузки отчёта")
                : "Ошибка загрузки отчёта")
            .toString();
      }

      players = ((data["players"] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      episodes = ((data["episodes"] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      mainReport = ((data["main_report"] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      passReport = ((data["pass_report"] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      goalkeeperReport = ((data["goalkeeper_report"] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      playerVideoTotals = ((data["player_video_totals"] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      _bindSelectedPlayerData();

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  void _bindSelectedPlayerData() {
    selectedPlayerMain = null;
    selectedPlayerPass = null;
    selectedPlayerGoalkeeper = null;
    selectedPlayerTotals = null;
    selectedPlayerEpisodes = [];

    for (final row in mainReport) {
      if (_asInt(row["player_id"]) == widget.playerId) {
        selectedPlayerMain = row;
        break;
      }
    }

    for (final row in passReport) {
      if (_asInt(row["player_id"]) == widget.playerId) {
        selectedPlayerPass = row;
        break;
      }
    }

    for (final row in goalkeeperReport) {
      if (_asInt(row["player_id"]) == widget.playerId) {
        selectedPlayerGoalkeeper = row;
        break;
      }
    }

    for (final row in playerVideoTotals) {
      if (_asInt(row["player_id"]) == widget.playerId) {
        selectedPlayerTotals = row;
        break;
      }
    }

    selectedPlayerEpisodes = episodes.where((e) {
      final pid = _asInt(e["player_id"]);
      final playerMap = e["player"];
      final nestedPlayerId = playerMap is Map ? _asInt(playerMap["id"]) : 0;
      return pid == widget.playerId || nestedPlayerId == widget.playerId;
    }).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _prettyDate(String? raw) {
    final s = (raw ?? "").trim();
    if (s.isEmpty) return "-";
    final d = DateTime.tryParse(s.replaceAll(' ', 'T'));
    if (d == null) return s;
    return DateFormat('dd.MM.yyyy').format(d);
  }

  String _normalizeMetricTitle(String key) {
    const map = {
      'feint_dribble': 'Обводки / финты',
      'shot_on_goal': 'Удар по воротам',
      'tackle_duel': 'Единоборство / отбор',
      'interception': 'Перехват',
      'recovery': 'Подбор',
      'header_play': 'Игра головой',
      'throw_ins': 'Аут',
      'pass_avp': 'Острая передача',
      'forward_short': 'Вперёд короткая',
      'forward_medium': 'Вперёд средняя',
      'forward_long': 'Вперёд длинная',
      'side_short': 'Поперёк короткая',
      'side_medium': 'Поперёк средняя',
      'side_long': 'Поперёк длинная',
      'back_short': 'Назад короткая',
      'back_medium': 'Назад средняя',
      'back_long': 'Назад длинная',
      'hand_distribution': 'Ввод рукой',
      'coming_out': 'Игра на выходах',
      'close_combat': 'Ближний бой',
      'interceptions_gk': 'Перехват вратаря',
      'outside_box': 'Игра вне штрафной',
      'pass_short': 'Короткая передача',
      'pass_medium': 'Средняя передача',
      'pass_long': 'Длинная передача',
      'saves': 'Сейв',
      'conceded': 'Пропущенный гол',
      'goal': 'Гол',
      'assist': 'Голевая передача',
      'yellow_card': 'Жёлтая карточка',
      'red_card': 'Красная карточка',
      'substitution': 'Замена',
      'injury': 'Травма',
      'offside': 'Офсайд',
      'foul': 'Фол',
      'foul_on': 'Фол на себе',
      'penalty': 'Пенальти',
      'save': 'Сейв',
      'corner': 'Угловой',
      'free_kick': 'Штрафной удар',
      'kick_off': 'Начальный удар',
      'throw_in': 'Аут',
      'goal_kick': 'Удар от ворот',
    };
    return map[key] ?? key;
  }

  Widget _matteSurface({required Widget child, VoidCallback? onTap}) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return _matteSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _pill(String title, String value, {Color? color}) {
    final c = color ?? primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.withOpacity(0.18)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: textSecondary),
          children: [
            TextSpan(
              text: "$title: ",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String title, String value, {Color? accentColor}) {
    final c = accentColor ?? primary;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: c,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return _sectionCard(
      title: "Общая информация",
      icon: Icons.emoji_events_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill(
            "Соперник",
            widget.opponent?.isNotEmpty == true ? widget.opponent! : "-",
          ),
          _pill(
            "Турнир",
            widget.tournament?.isNotEmpty == true ? widget.tournament! : "-",
          ),
          _pill("Дата", _prettyDate(widget.matchDate)),
          _pill(
            "Счёт",
            widget.score?.isNotEmpty == true ? widget.score! : "-",
            color: Colors.blue.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerMainStats() {
    final row = selectedPlayerMain;

    if (row == null) {
      return _sectionCard(
        title: "Основные ТТД",
        icon: Icons.analytics_rounded,
        child: Text(
          "Нет данных по ТТД игрока",
          style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
        ),
      );
    }

    final keys = [
      'feint_dribble',
      'shot_on_goal',
      'tackle_duel',
      'interception',
      'recovery',
      'header_play',
      'throw_ins',
      'pass_avp',
    ];

    return _sectionCard(
      title: "Основные ТТД",
      icon: Icons.analytics_rounded,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill("Всего", _asStr(row["ttd_total"])),
              _pill(
                "Эффективность",
                "${_asStr(row["effect_percent"])}%",
                color: Colors.blue.shade700,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...keys.map((key) => _metricTile(
                _normalizeMetricTitle(key),
                _asStr(row[key]),
              )),
        ],
      ),
    );
  }

  Widget _buildPassStats() {
    final row = selectedPlayerPass;

    if (row == null) {
      return const SizedBox.shrink();
    }

    final keys = [
      'forward_short',
      'forward_medium',
      'forward_long',
      'side_short',
      'side_medium',
      'side_long',
      'back_short',
      'back_medium',
      'back_long',
    ];

    return _sectionCard(
      title: "Передачи",
      icon: Icons.compare_arrows_rounded,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill("Всего", _asStr(row["total"])),
              _pill(
                "Эффективность",
                "${_asStr(row["effect_percent"])}%",
                color: Colors.deepPurple.shade700,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...keys.map((key) => _metricTile(
                _normalizeMetricTitle(key),
                _asStr(row[key]),
                accentColor: Colors.deepPurple.shade700,
              )),
        ],
      ),
    );
  }

  Widget _buildGoalkeeperStats() {
    final row = selectedPlayerGoalkeeper;
    if (row == null) return const SizedBox.shrink();

    final keys = [
      'conceded',
      'saves',
      'hand_distribution',
      'coming_out',
      'close_combat',
      'interceptions',
      'outside_box',
      'pass_short',
      'pass_medium',
      'pass_long',
    ];

    return _sectionCard(
      title: "Вратарская статистика",
      icon: Icons.shield_rounded,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill("Всего", _asStr(row["ttd_total"])),
              _pill(
                "Эффективность",
                "${_asStr(row["effect_percent"])}%",
                color: Colors.orange.shade700,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...keys.map((key) => _metricTile(
                _normalizeMetricTitle(key),
                _asStr(row[key]),
                accentColor: Colors.orange.shade700,
              )),
        ],
      ),
    );
  }

  Widget _buildVideoTotals() {
    final row = selectedPlayerTotals;
    if (row == null) return const SizedBox.shrink();

    final success = (row["success"] is Map)
        ? Map<String, dynamic>.from(row["success"])
        : <String, dynamic>{};

    final fail = (row["fail"] is Map)
        ? Map<String, dynamic>.from(row["fail"])
        : <String, dynamic>{};

    final single = (row["single"] is Map)
        ? Map<String, dynamic>.from(row["single"])
        : <String, dynamic>{};

    final keys = <String>{
      ...success.keys,
      ...fail.keys,
      ...single.keys,
    }.toList();

    keys.sort();

    return _sectionCard(
      title: "Видеоотчёт",
      icon: Icons.video_collection_rounded,
      child: Column(
        children: keys.map((key) {
          final hasPair = success.containsKey(key) || fail.containsKey(key);
          final value = hasPair
              ? "${_asInt(success[key])}/${_asInt(fail[key])}"
              : _asStr(single[key]);

          return _metricTile(
            _normalizeMetricTitle(key),
            value,
            accentColor: const Color(0xFF00BFA5),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEpisodes() {
    return _sectionCard(
      title: "Моменты игрока",
      icon: Icons.movie_creation_outlined,
      child: selectedPlayerEpisodes.isEmpty
          ? Text(
              "По этому игроку эпизоды пока не найдены",
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              children: selectedPlayerEpisodes.map((episode) {
                final title = _asStr(episode["event_title"]).isNotEmpty
                    ? _asStr(episode["event_title"])
                    : (_asStr(episode["event_type"]).isNotEmpty
                        ? _normalizeMetricTitle(_asStr(episode["event_type"]))
                        : "Эпизод");

                final note = _asStr(episode["note"]);
                final minute = _asInt(episode["minute"]);
                final second = _asInt(episode["second"]);
                final snapshotUrl = _asStr(episode["snapshot_url"]);
                final children = (episode["children"] is List)
                    ? List<Map<String, dynamic>>.from(
                        (episode["children"] as List).whereType<Map>(),
                      )
                    : <Map<String, dynamic>>[];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (snapshotUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              snapshotUrl,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 120,
                                color: Colors.grey.shade100,
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          ),
                        if (snapshotUrl.isNotEmpty) const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}",
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: primary.withOpacity(0.1)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.notes_rounded,
                                  size: 16,
                                  color: textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.3,
                                      color: textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (children.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            "Действия в эпизоде",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...children.map((child) {
                            final rawType = _asStr(child["event_type"]);
                            final childTitle = rawType.isNotEmpty
                                ? _normalizeMetricTitle(rawType)
                                : "Действие";
                            final isPositive =
                                _asInt(child["is_positive"]) > 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    (isPositive ? Colors.green : Colors.red)
                                        .withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      (isPositive ? Colors.green : Colors.red)
                                          .withOpacity(0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isPositive
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    size: 16,
                                    color: isPositive
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      childTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildVideoButton() {
    final url = _normalizeUrl(widget.videoUrl);
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return _matteSurface(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _watchVideo,
          icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white),
          label: const Text(
            "Смотреть видео матча",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text(
          "Матч — ${widget.playerName}",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadMatchDetail,
            icon: Icon(Icons.refresh_rounded, color: primary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMatchDetail,
        color: primary,
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: primary))
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _buildOverview(),
                      const SizedBox(height: 12),
                      _buildVideoButton(),
                      const SizedBox(height: 12),
                      _buildPlayerMainStats(),
                      if (selectedPlayerPass != null) ...[
                        const SizedBox(height: 12),
                        _buildPassStats(),
                      ],
                      if (selectedPlayerGoalkeeper != null) ...[
                        const SizedBox(height: 12),
                        _buildGoalkeeperStats(),
                      ],
                      if (selectedPlayerTotals != null) ...[
                        const SizedBox(height: 12),
                        _buildVideoTotals(),
                      ],
                      const SizedBox(height: 12),
                      _buildEpisodes(),
                    ],
                  ),
      ),
    );
  }
}