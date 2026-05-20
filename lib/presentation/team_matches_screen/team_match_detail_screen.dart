import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_video_analysis/match_video_player_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/video_match_review_screen.dart';

class TeamMatchDetailScreen extends StatefulWidget {
  const TeamMatchDetailScreen({super.key});

  @override
  State<TeamMatchDetailScreen> createState() => _TeamMatchDetailScreenState();
}

class _TeamMatchDetailScreenState extends State<TeamMatchDetailScreen>
    with SingleTickerProviderStateMixin {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String detailUrl = "$apiBase/get_team_match_detail.php";
  static const String updateUrl = "$apiBase/update_team_match_info.php";
  static const String deleteVideoUrl = "$apiBase/delete_match_video.php";
  static const String ttdReportUrl = "$apiBase/get_match_ttd_report.php";

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  bool _isHeaderVisible = true;
  bool loading = true;
  bool loadingTtd = false;
  bool saving = false;
  bool uploadingVideo = false;
  bool _isMatchInfoEditing = false;

  int matchId = 0;
  int teamId = 0;
  int _coachId = 0;
  String teamName = "Моя команда";

  Map<String, dynamic>? match;

  final ChunkUploadService _chunkUploadService = ChunkUploadService();

  final _competitionCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _tourCtrl = TextEditingController();
  final _stadiumCtrl = TextEditingController();
  final _refereesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _shotsCtrl = TextEditingController();
  final _shotsOnTargetCtrl = TextEditingController();
  final _cornersCtrl = TextEditingController();
  final _offsidesCtrl = TextEditingController();
  final _possessionCtrl = TextEditingController();
  final _yellowCtrl = TextEditingController();
  final _redCtrl = TextEditingController();

  final _coachCommentCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _search = '';
  String? _selectedMainTtdPlayerKey;
  String? _selectedGoalkeeperKey;

  List<Map<String, dynamic>> ttdPlayers = [];
  List<Map<String, dynamic>> episodes = [];
  List<Map<String, dynamic>> mainReport = [];
  List<Map<String, dynamic>> passReport = [];
  List<Map<String, dynamic>> goalkeeperReport = [];
  List<Map<String, dynamic>> playerVideoTotals = [];

  String? _selectedUploadVideoPath;
  String? _selectedUploadVideoName;
  int? _selectedUploadVideoSize;

  String? _selectedUploadThumbPath;
  String? _selectedUploadThumbName;
  int? _selectedUploadThumbSize;

  // Цветовая схема в стиле TeamMatchesScreen
  Color get primary => AppColors.primaryGreen;
  Color get bg => Colors.white;
  Color get cardBg => Colors.white;
  Color get textPrimary => const Color(0xFF1E293B);
  Color get textSecondary => const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _scrollController.addListener(_onScroll);
    _readArgs();
    _init();
  }

  Future<void> _init() async {
    _coachId = await PrefUtils.getUserId() ?? 0;
    await load();
    await _loadTtdReport();
  }

  void _readArgs() {
    final args = Get.arguments;
    if (args is Map) {
      matchId = int.tryParse((args["match_id"] ?? "0").toString()) ?? 0;
      teamId = int.tryParse((args["team_id"] ?? "0").toString()) ?? 0;
      teamName = (args["team_name"] ?? "Моя команда").toString();

      developer.log(
        'Received args: matchId=$matchId, teamId=$teamId, teamName=$teamName',
      );
    }
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && _isHeaderVisible) {
      setState(() => _isHeaderVisible = false);
    } else if (_scrollController.offset <= 50 && !_isHeaderVisible) {
      setState(() => _isHeaderVisible = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();

    _competitionCtrl.dispose();
    _dateCtrl.dispose();
    _tourCtrl.dispose();
    _stadiumCtrl.dispose();
    _refereesCtrl.dispose();
    _notesCtrl.dispose();

    _shotsCtrl.dispose();
    _shotsOnTargetCtrl.dispose();
    _cornersCtrl.dispose();
    _offsidesCtrl.dispose();
    _possessionCtrl.dispose();
    _yellowCtrl.dispose();
    _redCtrl.dispose();

    _coachCommentCtrl.dispose();
    _searchCtrl.dispose();

    super.dispose();
  }

  String _s(dynamic v) => (v ?? "").toString().trim();

  int _i(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

  double _d(dynamic v) => double.tryParse('${v ?? 0}') ?? 0;

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

  Map<String, dynamic> _decodeResponse(http.Response resp) {
    try {
      final raw = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      final start = raw.indexOf('{');
      if (start == -1) {
        return {"success": false, "message": "Некорректный ответ"};
      }
      final clean = raw.substring(start);
      final data = jsonDecode(clean);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {"success": false, "message": "Некорректный JSON"};
    } catch (_) {
      return {"success": false, "message": "Ошибка разбора ответа"};
    }
  }

  String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    return "https://sportotekaapp.ru${s.startsWith('/') ? s : '/$s'}";
  }

  bool _looksLikeOnlyId(String value) {
    final clean = value.trim();
    return clean.isEmpty || RegExp(r'^#?\d+$').hasMatch(clean);
  }

  String _firstReadableTeamName(Map<String, dynamic> source) {
    final variants = [
      source["team_name"],
      source["team_title"],
      source["our_team"],
      source["club_team_name"],
      source["home_team_name"],
      source["name"],
    ];

    for (final value in variants) {
      final label = _s(value);
      if (label.isNotEmpty && !_looksLikeOnlyId(label)) {
        return label;
      }
    }

    return _looksLikeOnlyId(teamName) ? "Моя команда" : teamName;
  }

  String? _playerPhotoUrl(Map<String, dynamic> row) {
    final directKeys = [
      "photo",
      "avatar",
      "image",
      "photo_url",
      "avatar_url",
      "player_photo",
      "player_avatar",
      "player_image",
      "profile_photo",
      "profile_image",
    ];

    String? fromMap(Map<String, dynamic> source) {
      for (final key in directKeys) {
        final value = _s(source[key]);
        final url = _normalizeUrl(value);
        if (url != null && url.isNotEmpty) return url;
      }
      return null;
    }

    final direct = fromMap(row);
    if (direct != null) return direct;

    for (final nestedKey in ["player", "user", "athlete", "profile"]) {
      final nested = row[nestedKey];
      if (nested is Map) {
        final url = fromMap(Map<String, dynamic>.from(nested));
        if (url != null) return url;
      }
    }

    final rowId = _playerId(row);
    final rowName = _playerName(row).toLowerCase();

    for (final list in [ttdPlayers, playerVideoTotals, mainReport, passReport]) {
      for (final item in list) {
        final sameId = rowId.isNotEmpty && _playerId(item) == rowId;
        final sameName = rowName.isNotEmpty && _playerName(item).toLowerCase() == rowName;
        if (sameId || sameName) {
          final url = fromMap(item);
          if (url != null) return url;

          for (final nestedKey in ["player", "user", "athlete", "profile"]) {
            final nested = item[nestedKey];
            if (nested is Map) {
              final nestedUrl = fromMap(Map<String, dynamic>.from(nested));
              if (nestedUrl != null) return nestedUrl;
            }
          }
        }
      }
    }

    final matchPlayers = ((match?["players"] as List?) ?? const [])
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .toList();

    for (final item in matchPlayers) {
      final sameId = rowId.isNotEmpty && _playerId(item) == rowId;
      final sameName = rowName.isNotEmpty && _playerName(item).toLowerCase() == rowName;
      if (sameId || sameName) {
        final url = fromMap(item);
        if (url != null) return url;
      }
    }

    return null;
  }

  String _playerId(Map<String, dynamic> row) {
    for (final key in ["player_id", "id", "user_id", "athlete_id", "student_id"]) {
      final value = _s(row[key]);
      if (value.isNotEmpty && value != "0" && value.toLowerCase() != "null") {
        return value;
      }
    }
    final player = row["player"];
    if (player is Map) {
      return _playerId(Map<String, dynamic>.from(player));
    }
    return "";
  }

  String _playerName(Map<String, dynamic> row) {
    final first = _s(row["first_name"] ?? row["firstname"]);
    final last = _s(row["last_name"] ?? row["lastname"]);
    final full = "$first $last".trim();
    if (full.isNotEmpty) return full;
    for (final key in ["player_name", "fullName", "full_name", "name", "title"]) {
      final value = _s(row[key]);
      if (value.isNotEmpty) return value;
    }
    final player = row["player"];
    if (player is Map) {
      return _playerName(Map<String, dynamic>.from(player));
    }
    return "Игрок";
  }

  String _mainTtdPlayerKey(Map<String, dynamic> row) {
    final id = _playerId(row);
    if (id.isNotEmpty) return "id:$id";
    return "name:${_playerName(row).toLowerCase()}";
  }

  List<Map<String, dynamic>> _filteredMainTtdRows() {
    return mainReport.where((row) {
      return _matchesSearch(_playerName(row));
    }).toList();
  }

  Map<String, dynamic> _summaryMainTtdRow(List<Map<String, dynamic>> rows) {
    const keys = [
      "feint_dribble",
      "shot_on_goal",
      "tackle_duel",
      "interception",
      "recovery",
      "header_play",
      "throw_ins",
      "pass_avp",
    ];

    final result = <String, dynamic>{
      "player_name": "Суммарно по матчу",
      "full_name": "Суммарно по матчу",
    };

    for (final key in keys) {
      result[key] = rows.fold<int>(0, (sum, row) => sum + _mainTtdValue(row, key));
    }

    result["ttd_total"] = rows.fold<int>(0, (sum, row) => sum + _mainTtdTotal(row));

    var effectSum = 0.0;
    var effectCount = 0;
    for (final row in rows) {
      final value = _d(row["effect_percent"]);
      if (value > 0) {
        effectSum += value;
        effectCount++;
      }
    }
    result["effect_percent"] = effectCount == 0 ? 0 : (effectSum / effectCount).toStringAsFixed(1);
    return result;
  }

  int _numericValue(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.round();

    final raw = v.toString().replaceAll(',', '.').trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null' || raw == '—') return 0;

    // В отчётах ТТД часто приходит формат "успешно/неуспешно", например "4/2".
    // Для бейджа игрока и суммарного ТТД показываем общий объём действий: 4 + 2 = 6.
    if (raw.contains('/')) {
      return raw
          .split('/')
          .map((part) => double.tryParse(part.trim())?.round() ?? 0)
          .fold<int>(0, (sum, value) => sum + value);
    }

    return double.tryParse(raw)?.round() ?? 0;
  }

  int _valueFromNested(dynamic raw, String key) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      var total = 0;

      if (map.containsKey(key)) total += _numericValue(map[key]);

      final aliases = _mainTtdAliases[key] ?? const <String>[];
      for (final alias in aliases) {
        if (map.containsKey(alias)) total += _numericValue(map[alias]);
      }

      final byCode = map[key];
      if (byCode is Map) {
        total += _numericValue(byCode["total"]);
        total += _numericValue(byCode["count"]);
        total += _numericValue(byCode["value"]);
        total += _numericValue(byCode["success"]);
        total += _numericValue(byCode["fail"]);
      }

      for (final nested in ["success", "fail", "single", "totals", "metrics", "items", "actions", "ttd"]) {
        total += _valueFromNested(map[nested], key);
      }

      return total;
    }

    if (raw is List) {
      var total = 0;
      for (final item in raw) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final code = _s(map["code"] ?? map["key"] ?? map["type"] ?? map["action"] ?? map["action_code"]);
          final title = _s(map["title"] ?? map["name"] ?? map["label"]);
          final aliases = _mainTtdAliases[key] ?? const <String>[];
          final matches = code == key || aliases.contains(code) || aliases.contains(title);
          if (matches) {
            total += _numericValue(map["total"]);
            total += _numericValue(map["count"]);
            total += _numericValue(map["value"]);
            total += _numericValue(map["success"]);
            total += _numericValue(map["fail"]);
            total += _numericValue(map["single"]);
          } else {
            total += _valueFromNested(map, key);
          }
        }
      }
      return total;
    }

    return 0;
  }

  static const Map<String, List<String>> _mainTtdAliases = {
    "feint_dribble": ["dribble", "feint", "обводки", "финты", "Обводки / финты"],
    "shot_on_goal": ["shots", "shot", "shots_on_goal", "удары", "Удары по воротам"],
    "tackle_duel": ["tackles", "duels", "tackle", "отборы", "единоборства", "Отборы / единоборства"],
    "interception": ["interceptions", "перехваты", "Перехваты"],
    "recovery": ["recoveries", "подборы", "Подборы"],
    "header_play": ["headers", "header", "игра головой", "Игра головой"],
    "throw_ins": ["throw_in", "throwins", "вбрасывания", "Вбрасывания"],
    "pass_avp": ["avp", "key_pass", "key_passes", "острые передачи", "Острые передачи"],
  };

  int _mainTtdValue(Map<String, dynamic> row, String key) {
    var total = 0;

    total += _numericValue(row[key]);

    final aliases = _mainTtdAliases[key] ?? const <String>[];
    for (final alias in aliases) {
      total += _numericValue(row[alias]);
    }

    for (final nested in ["success", "fail", "single", "totals", "metrics", "items", "actions", "ttd"]) {
      total += _valueFromNested(row[nested], key);
    }

    return total;
  }

  int _mainTtdTotal(Map<String, dynamic> row) {
    final direct = _numericValue(row["ttd_total"] ?? row["total_ttd"] ?? row["total"] ?? row["actions_total"]);
    if (direct > 0) return direct;

    const mainKeys = [
      "feint_dribble",
      "shot_on_goal",
      "tackle_duel",
      "interception",
      "recovery",
      "header_play",
      "throw_ins",
      "pass_avp",
    ];

    var total = 0;
    for (final key in mainKeys) {
      total += _mainTtdValue(row, key);
    }

    if (total > 0) return total;

    for (final groupKey in ["success", "fail", "single"]) {
      final raw = row[groupKey];
      if (raw is Map) {
        for (final value in raw.values) {
          total += _numericValue(value);
        }
      }
    }

    return total;
  }

  int _goalkeeperTotal(Map<String, dynamic> row) {
    final direct = _numericValue(row["ttd_total"] ?? row["total_ttd"] ?? row["total"] ?? row["actions_total"]);
    if (direct > 0) return direct;

    const keys = [
      "saves",
      "conceded",
      "hand_distribution",
      "coming_out",
      "close_combat",
      "interceptions",
      "interceptions_gk",
      "outside_box",
      "pass_short",
      "pass_medium",
      "pass_long",
      "gk_pass_short",
      "gk_pass_medium",
      "gk_pass_long",
    ];

    var total = 0;
    for (final key in keys) {
      total += _numericValue(row[key]);
      for (final nested in ["success", "fail", "single", "totals", "metrics", "items", "actions", "ttd"]) {
        total += _valueFromNested(row[nested], key);
      }
    }
    return total;
  }

  Widget _cmrHint({
    required String title,
    required String text,
    IconData icon = Icons.tips_and_updates_outlined,
    Color? color,
  }) {
    final c = color ?? primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: c, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatVideoTitle(String raw, String fallback) {
    final title = raw.trim();
    if (title.isEmpty) return fallback;
    return title;
  }

  String _videoMeta(Map<String, dynamic> video) {
    final parts = <String>[];
    final created = _s(video["created_at"]).isEmpty
        ? _s(video["uploaded_at"])
        : _s(video["created_at"]);
    final size = _i(video["file_size"]);

    if (created.isNotEmpty) parts.add(created);
    if (size > 0) parts.add(_formatFileSize(size));

    return parts.isEmpty ? "Видео матча" : parts.join(" • ");
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 Б";
    const suffixes = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
    double size = bytes.toDouble();
    int i = 0;
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    final digits = size >= 100 ? 0 : (size >= 10 ? 1 : 2);
    return "${size.toStringAsFixed(digits)} ${suffixes[i]}";
  }

  String _matchTitleForReview() {
    final title = _s(match?["title"]);
    if (title.isNotEmpty) return title;

    final ourTeam =
        _s(match?["our_team"]).isEmpty ? teamName : _s(match?["our_team"]);
    final opponent =
        _s(match?["opponent"]).isEmpty ? "Соперник" : _s(match?["opponent"]);
    final ourScore =
        _s(match?["our_score"]).isEmpty ? "0" : _s(match?["our_score"]);
    final oppScore = _s(match?["opponent_score"]).isEmpty
        ? "0"
        : _s(match?["opponent_score"]);

    return "$ourTeam $ourScore:$oppScore $opponent";
  }

  Future<void> load() async {
    setState(() => loading = true);

    try {
      final resp = await http
          .post(
            Uri.parse(detailUrl),
            headers: const {"Content-Type": "application/json; charset=utf-8"},
            body: jsonEncode({
              "match_id": matchId,
              "team_id": teamId,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeResponse(resp);

      if (data["success"] == true || data["status"] == "success") {
        match = Map<String, dynamic>.from(data["match"] ?? {});
        final loadedTeamName = _firstReadableTeamName(match!);
        if (!_looksLikeOnlyId(loadedTeamName)) {
          teamName = loadedTeamName;
        }
        _fillControllers();
      } else {
        Get.snackbar(
          "Ошибка загрузки",
          data["message"]?.toString() ?? "Не удалось загрузить данные матча",
        );
      }
    } catch (_) {
      Get.snackbar(
        "Ошибка сети",
        "Проверьте интернет-соединение",
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadTtdReport() async {
    if (matchId <= 0) return;

    setState(() => loadingTtd = true);

    try {
      final uri = Uri.parse(ttdReportUrl).replace(
        queryParameters: {
          "match_id": "$matchId",
          "team_id": "$teamId",
        },
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 30));

      final data = _decodeResponse(resp);

      debugPrint("TTD RESPONSE: ${resp.body}");

      if (data["success"] == true) {
        setState(() {
          ttdPlayers = ((data["players"] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          episodes = ((data["episodes"] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          mainReport = ((data["main_report"] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          passReport = ((data["pass_report"] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          goalkeeperReport =
              ((data["goalkeeper_report"] as List?) ?? const [])
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();

          playerVideoTotals =
              ((data["player_video_totals"] as List?) ?? const [])
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
        });
      } else {
        debugPrint("TTD ERROR: ${data["message"]}");
        setState(() {
          ttdPlayers = [];
          episodes = [];
          mainReport = [];
          passReport = [];
          goalkeeperReport = [];
          playerVideoTotals = [];
        });
      }
    } catch (e) {
      debugPrint("TTD LOAD ERROR: $e");
      setState(() {
        ttdPlayers = [];
        episodes = [];
        mainReport = [];
        passReport = [];
        goalkeeperReport = [];
        playerVideoTotals = [];
      });
    } finally {
      if (mounted) setState(() => loadingTtd = false);
    }
  }

  void _fillControllers() {
    final m = match ?? {};

    _competitionCtrl.text = _s(m["competition_name"]);
    _dateCtrl.text = _s(m["info_date"]);
    _tourCtrl.text = _s(m["tour_label"]);
    _stadiumCtrl.text = _s(m["stadium"]);
    _refereesCtrl.text = _s(m["referees"]);
    _notesCtrl.text = _s(m["notes"]);

    _shotsCtrl.text = _s(m["shots"]);
    _shotsOnTargetCtrl.text = _s(m["shots_on_target"]);
    _cornersCtrl.text = _s(m["corners"]);
    _offsidesCtrl.text = _s(m["offsides"]);
    _possessionCtrl.text = _s(m["possession"]);
    _yellowCtrl.text = _s(m["yellow_cards"]);
    _redCtrl.text = _s(m["red_cards"]);

    _coachCommentCtrl.text = _s(m["ttd_text"]);
  }

  Future<void> _saveAll() async {
    setState(() => saving = true);

    try {
      final resp = await http
          .post(
            Uri.parse(updateUrl),
            headers: const {"Content-Type": "application/json; charset=utf-8"},
            body: jsonEncode({
              "match_id": matchId,
              "team_id": teamId,
              "competition_name": _competitionCtrl.text.trim(),
              "info_date": _dateCtrl.text.trim(),
              "tour_label": _tourCtrl.text.trim(),
              "stadium": _stadiumCtrl.text.trim(),
              "referees": _refereesCtrl.text.trim(),
              "notes": _notesCtrl.text.trim(),
              "shots": _shotsCtrl.text.trim(),
              "shots_on_target": _shotsOnTargetCtrl.text.trim(),
              "corners": _cornersCtrl.text.trim(),
              "offsides": _offsidesCtrl.text.trim(),
              "possession": _possessionCtrl.text.trim(),
              "yellow_cards": _yellowCtrl.text.trim(),
              "red_cards": _redCtrl.text.trim(),
              "ttd_text": _coachCommentCtrl.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(resp);

      if (data["success"] == true || data["status"] == "success") {
        Get.snackbar(
          "Успешно",
          "Информация по матчу сохранена",
          backgroundColor: primary,
          colorText: Colors.white,
        );
        await load();
        await _loadTtdReport();
      } else {
        Get.snackbar(
          "Ошибка сохранения",
          data["message"]?.toString() ?? "Не удалось сохранить изменения",
        );
      }
    } catch (_) {
      Get.snackbar(
        "Ошибка сети",
        "Не удалось сохранить изменения",
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _matteSurface({required Widget child, VoidCallback? onTap}) {
    // Плоская поверхность без эффекта «карточка в карточке».
    // Используем только белый фон и лёгкие отступы, чтобы весь экран выглядел единым полотном.
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: Colors.white,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _buildHeaderCard() {
  final title = _s(match?["title"]).isEmpty ? "Матч" : _s(match?["title"]);
  final eventType = _eventTypeLabel(_s(match?["event_type"]));
  final competition = _s(match?["competition_name"]);
  final date = _s(match?["match_date"]).isEmpty
      ? _s(match?["info_date"])
      : _s(match?["match_date"]);

  final ourTeam =
      _s(match?["our_team"]).isEmpty ? teamName : _s(match?["our_team"]);
  final opponent =
      _s(match?["opponent"]).isEmpty ? "Соперник" : _s(match?["opponent"]);

  final ourScore =
      _s(match?["our_score"]).isEmpty ? "0" : _s(match?["our_score"]);
  final oppScore = _s(match?["opponent_score"]).isEmpty
      ? "0"
      : _s(match?["opponent_score"]);

  // Рассчитываем высоту динамически
  double headerHeight = 0;
  if (_isHeaderVisible) {
    headerHeight = 200; // базовая высота
    if (competition.isNotEmpty || date.isNotEmpty) {
      headerHeight += 40; // добавляем на дополнительный ряд
    }
    if (title.length > 30) {
      headerHeight += 20; // на длинный заголовок
    }
  }

  return AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
    height: _isHeaderVisible ? headerHeight : 0,
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: _isHeaderVisible
        ? _matteSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (eventType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primary.withOpacity(0.22),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          eventType,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildScoreBlock(ourTeam, ourScore, isHome: true),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        ":",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildScoreBlock(opponent, oppScore, isHome: false),
                    ),
                  ],
                ),
                if (competition.isNotEmpty || date.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (competition.isNotEmpty)
                        _buildInfoChip(
                          icon: Icons.emoji_events_outlined,
                          text: competition,
                        ),
                      if (date.isNotEmpty)
                        _buildInfoChip(
                          icon: Icons.calendar_today_outlined,
                          text: date,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          )
        : null,
  );
}


  Widget _buildOverviewScoreCard({bool compact = false}) {
    final ourTeam = _s(match?["our_team"]).isEmpty ? teamName : _s(match?["our_team"]);
    final opponent = _s(match?["opponent"]).isEmpty ? "Соперник" : _s(match?["opponent"]);
    final ourScore = _s(match?["our_score"]).isEmpty ? "0" : _s(match?["our_score"]);
    final oppScore = _s(match?["opponent_score"]).isEmpty ? "0" : _s(match?["opponent_score"]);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _scoreTeamName(
              ourTeam,
              align: TextAlign.right,
              color: primary,
              compact: compact,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: BoxConstraints(
              minWidth: compact ? 76 : 92,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 9 : 10,
            ),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: primary.withOpacity(0.18)),
            ),
            child: Text(
              '$ourScore : $oppScore',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 24 : 30,
                height: 1,
                fontWeight: FontWeight.w900,
                color: primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _scoreTeamName(
              opponent,
              align: TextAlign.left,
              color: const Color(0xFF334155),
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreTeamName(
    String title, {
    required TextAlign align,
    required Color color,
    bool compact = false,
  }) {
    return Text(
      title,
      textAlign: align,
      maxLines: compact ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 12 : 14,
        height: 1.15,
        fontWeight: FontWeight.w900,
        color: color,
      ),
    );
  }

  Widget _buildScoreBlock(
    String team,
    String score, {
    required bool isHome,
    bool compact = false,
  }) {
    final accent = isHome ? primary : const Color(0xFF475569);

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 7 : 9,
        horizontal: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: isHome ? primary.withOpacity(0.09) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHome ? primary.withOpacity(0.26) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            team,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            score,
            style: TextStyle(
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _overviewAccent(int index) {
    const colors = [
      Color(0xFF0EA5E9),
      Color(0xFF22C55E),
      Color(0xFFF97316),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
      Color(0xFF14B8A6),
    ];
    return colors[index % colors.length];
  }

  Widget _overviewCircleButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.22)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }

  Widget _overviewDot({required Color color, double size = 9}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.75),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _overviewMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.16)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    if (hint != null && hint.trim().isNotEmpty)
                      Tooltip(
                        message: hint,
                        child: Icon(
                          Icons.help_outline_rounded,
                          size: 15,
                          color: color.withOpacity(0.85),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewMetricGrid({required bool isWide}) {
    final items = [
      _OverviewMetricData(
        label: 'Всего действий',
        value: '$_totalActions',
        icon: Icons.analytics_outlined,
        color: _overviewAccent(0),
        hint: 'Сумма всех ТТД по игрокам в этом матче.',
      ),
      _OverviewMetricData(
        label: 'Успешно',
        value: '$_totalSuccess',
        icon: Icons.check_circle_outline,
        color: _overviewAccent(1),
        hint: 'Количество положительно выполненных действий.',
      ),
      _OverviewMetricData(
        label: 'Неудачно',
        value: '$_totalFail',
        icon: Icons.cancel_outlined,
        color: _overviewAccent(4),
        hint: 'Действия, которые требуют разбора на тренировке.',
      ),
      _OverviewMetricData(
        label: 'Эффективность',
        value: '${_efficiency.toStringAsFixed(1)}%',
        icon: Icons.trending_up,
        color: _overviewAccent(3),
        hint: 'Процент успешных действий от общего количества.',
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(
              child: _overviewMetricTile(
                label: items[i].label,
                value: items[i].value,
                icon: items[i].icon,
                color: items[i].color,
                hint: items[i].hint,
              ),
            ),
            if (i != items.length - 1) const SizedBox(width: 10),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _overviewMetricTile(label: items[0].label, value: items[0].value, icon: items[0].icon, color: items[0].color, hint: items[0].hint)),
            const SizedBox(width: 10),
            Expanded(child: _overviewMetricTile(label: items[1].label, value: items[1].value, icon: items[1].icon, color: items[1].color, hint: items[1].hint)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _overviewMetricTile(label: items[2].label, value: items[2].value, icon: items[2].icon, color: items[2].color, hint: items[2].hint)),
            const SizedBox(width: 10),
            Expanded(child: _overviewMetricTile(label: items[3].label, value: items[3].value, icon: items[3].icon, color: items[3].color, hint: items[3].hint)),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        splashBorderRadius: BorderRadius.circular(18),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicator: BoxDecoration(
          color: primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary.withOpacity(0.18),
            width: 1.1,
          ),
        ),
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(height: 42, text: "Обзор"),
          Tab(height: 42, text: "Основные ТТД"),
          Tab(height: 42, text: "Передачи"),
          Tab(height: 42, text: "Игроки"),
          Tab(height: 42, text: "Эпизоды"),
          Tab(height: 42, text: "Нарезка"),
          Tab(height: 42, text: "Видео"),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    String? subtitle,
    Widget? trailing,
  }) {
    final hasTitle = title.trim().isNotEmpty;
    final hasHeader = hasTitle || trailing != null;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  if (hasTitle)
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: textPrimary,
                          height: 1.15,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (trailing != null) trailing,
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1.35,
              ),
            ),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: maxLines > 1 ? 14 : 12,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardCard({
    required String label,
    required String value,
    required IconData icon,
    Color? accent,
  }) {
    final color = accent ?? primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallBadge(String label, String value, {Color? color}) {
    final c = color ?? textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: c,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required VoidCallback? onPressed,
    required String title,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
        label: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _emptyState(String text, {IconData icon = Icons.inbox_outlined}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.25,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _searchField({String hint = "Поиск..."}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.25),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  bool _matchesSearch(String value) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    return value.toLowerCase().contains(q);
  }

  int get _totalSuccess {
    int sum = 0;
    for (final row in playerVideoTotals) {
      final success = Map<String, dynamic>.from(row["success"] ?? {});
      for (final v in success.values) {
        sum += _i(v);
      }
      final single = Map<String, dynamic>.from(row["single"] ?? {});
      sum += _i(single["saves"]);
    }
    return sum;
  }

  int get _totalFail {
    int sum = 0;
    for (final row in playerVideoTotals) {
      final fail = Map<String, dynamic>.from(row["fail"] ?? {});
      for (final v in fail.values) {
        sum += _i(v);
      }
      final single = Map<String, dynamic>.from(row["single"] ?? {});
      sum += _i(single["conceded"]);
    }
    return sum;
  }

  int get _totalActions => _totalSuccess + _totalFail;

  double get _efficiency {
    final total = _totalActions;
    if (total <= 0) return 0;
    return (_totalSuccess / total) * 100;
  }

  void _exportPdfStub() {
    Get.snackbar(
      "PDF",
      "Экспорт отчёта в разработке",
      backgroundColor: primary,
      colorText: Colors.white,
    );
  }

  Widget _buildOverviewTab() {
    final isWide = MediaQuery.of(context).size.width > 900;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        _buildCompactMatchSummaryCard(isWide: isWide),
        const SizedBox(height: 14),
        _overviewMetricGrid(isWide: isWide),
        const SizedBox(height: 14),
        _buildMatchStatsStrip(isWide: isWide),
        if (_isMatchInfoEditing) ...[
          const SizedBox(height: 14),
          _buildMatchInfoEditor(),
        ],
      ],
    );
  }

  Widget _buildCompactMatchSummaryCard({required bool isWide}) {
    final competition = _s(_competitionCtrl.text);
    final date = _s(_dateCtrl.text);
    final stadium = _s(_stadiumCtrl.text);
    final tour = _s(_tourCtrl.text);
    final comment = _s(_coachCommentCtrl.text);
    final notes = _s(_notesCtrl.text);
    final description = comment.isNotEmpty ? comment : notes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildOverviewScoreCard(compact: !isWide)),
              const SizedBox(width: 8),
              _overviewCircleButton(
                icon: _isMatchInfoEditing ? Icons.close_rounded : Icons.edit_rounded,
                tooltip: _isMatchInfoEditing ? 'Скрыть редактор' : 'Редактировать матч',
                color: _isMatchInfoEditing ? const Color(0xFFEF4444) : primary,
                onTap: () => setState(() => _isMatchInfoEditing = !_isMatchInfoEditing),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (competition.isNotEmpty)
                _CmrMiniPill(icon: Icons.emoji_events_outlined, text: competition),
              if (date.isNotEmpty)
                _CmrMiniPill(icon: Icons.calendar_today_outlined, text: date),
              if (tour.isNotEmpty)
                _CmrMiniPill(icon: Icons.flag_outlined, text: tour),
              if (stadium.isNotEmpty)
                _CmrMiniPill(icon: Icons.stadium_outlined, text: stadium),
              if (competition.isEmpty && date.isEmpty && tour.isEmpty && stadium.isEmpty)
                _CmrMiniPill(icon: Icons.info_outline_rounded, text: 'Заполните данные матча'),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 17, color: primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.32,
                        color: textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchStatsStrip({required bool isWide}) {
    final stats = [
      _OverviewMetricData(
        label: 'Удары',
        value: _s(_shotsCtrl.text).isEmpty ? '—' : _s(_shotsCtrl.text),
        icon: Icons.sports_soccer_rounded,
        color: _overviewAccent(0),
      ),
      _OverviewMetricData(
        label: 'В створ',
        value: _s(_shotsOnTargetCtrl.text).isEmpty ? '—' : _s(_shotsOnTargetCtrl.text),
        icon: Icons.adjust_rounded,
        color: _overviewAccent(1),
      ),
      _OverviewMetricData(
        label: 'Угловые',
        value: _s(_cornersCtrl.text).isEmpty ? '—' : _s(_cornersCtrl.text),
        icon: Icons.flag_circle_outlined,
        color: _overviewAccent(2),
      ),
      _OverviewMetricData(
        label: 'Владение',
        value: _possessionCtrl.text.isEmpty ? '—' : '${_possessionCtrl.text}%',
        icon: Icons.pie_chart_outline_rounded,
        color: _overviewAccent(5),
      ),
      _OverviewMetricData(
        label: 'Жёлтые',
        value: _s(_yellowCtrl.text).isEmpty ? '—' : _s(_yellowCtrl.text),
        icon: Icons.style_outlined,
        color: const Color(0xFFF59E0B),
      ),
      _OverviewMetricData(
        label: 'Красные',
        value: _s(_redCtrl.text).isEmpty ? '—' : _s(_redCtrl.text),
        icon: Icons.style_rounded,
        color: const Color(0xFFEF4444),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.query_stats_rounded, size: 18, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Матчевые показатели',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
              ),
              Tooltip(
                message: 'Короткая сводка без лишнего текста. Данные можно изменить через кнопку редактирования сверху.',
                child: Icon(Icons.help_outline_rounded, size: 18, color: textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 980 ? 6 : constraints.maxWidth > 620 ? 3 : 2;
              final spacing = 10.0;
              final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: stats.map((item) {
                  return SizedBox(
                    width: itemWidth,
                    child: _overviewStatMiniTile(item),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _overviewStatMiniTile(_OverviewMetricData item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: item.color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchInfoEditor() {
    return _buildSectionCard(
      title: "Редактирование матча",
      trailing: TextButton.icon(
        onPressed: () => setState(() => _isMatchInfoEditing = false),
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text("Готово"),
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth > 720;
              if (!twoColumns) {
                return Column(
                  children: [
                    _input("Турнир / первенство", _competitionCtrl),
                    _input("Дата", _dateCtrl, hint: "ГГГГ-ММ-ДД"),
                    _input("Тур / этап", _tourCtrl),
                    _input("Стадион", _stadiumCtrl),
                    _input("Судьи", _refereesCtrl),
                    _input("Примечания", _notesCtrl, maxLines: 3),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _input("Турнир / первенство", _competitionCtrl),
                        _input("Дата", _dateCtrl, hint: "ГГГГ-ММ-ДД"),
                        _input("Тур / этап", _tourCtrl),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _input("Стадион", _stadiumCtrl),
                        _input("Судьи", _refereesCtrl),
                        _input("Примечания", _notesCtrl, maxLines: 3),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          _input(
            "Комментарий тренера",
            _coachCommentCtrl,
            maxLines: 5,
            hint: "Короткий вывод по игре, сильные стороны и что улучшить...",
          ),
        ],
      ),
    );
  }

  Widget _reportRowMain(Map<String, dynamic> row) {
    final playerName = _s(row["player_name"]).isEmpty ? "Игрок" : _s(row["player_name"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            playerName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _smallBadge("Обводки", _s(row["feint_dribble"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Удары", _s(row["shot_on_goal"]))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _smallBadge("Отборы", _s(row["tackle_duel"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Перехваты", _s(row["interception"]))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _smallBadge("Подборы", _s(row["recovery"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Головой", _s(row["header_play"]))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _smallBadge("Вбрасывания", _s(row["throw_ins"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Острые пасы", _s(row["pass_avp"]))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _smallBadge(
                  "Итого",
                  "${_mainTtdTotal(row)}",
                  color: primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallBadge(
                  "Эффект",
                  "${_s(row["effect_percent"])}%",
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainTtdTab() {
    if (loadingTtd) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final filtered = _filteredMainTtdRows();
    final selectedRow = _selectedMainTtdPlayerKey == null
        ? null
        : filtered.cast<Map<String, dynamic>?>().firstWhere(
              (row) => row != null && _mainTtdPlayerKey(row) == _selectedMainTtdPlayerKey,
              orElse: () => null,
            );
    final summaryRow = _summaryMainTtdRow(filtered);
    final isCompact = MediaQuery.of(context).size.width < 820;
    final panelHeight = max(
      320.0,
      min(540.0, MediaQuery.of(context).size.height - (isCompact ? 260 : 330)),
    );

    if (isCompact) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionCard(
            title: "",
            subtitle: "",
            child: Column(
              children: [
                _searchField(hint: "Поиск по игроку..."),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  _emptyState("Нет данных по основным ТТД")
                else ...[
                  _buildMainTtdPlayerList(filtered, compact: true),
                  const SizedBox(height: 12),
                  _buildMainTtdDetailsCard(selectedRow ?? summaryRow, isSummary: selectedRow == null),
                ],
              ],
            ),
          ),
          if (goalkeeperReport.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildGoalkeeperTtdPanel(compact: true),
          ],
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: "",
          subtitle: "",
          child: Column(
            children: [
              _searchField(hint: "Поиск по игроку..."),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                _emptyState("Нет данных по основным ТТД")
              else
                SizedBox(
                  height: panelHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 316,
                        height: panelHeight,
                        child: _buildMainTtdPlayerList(filtered),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SizedBox(
                          height: panelHeight,
                          child: _buildMainTtdDetailsCard(
                            selectedRow ?? summaryRow,
                            isSummary: selectedRow == null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (goalkeeperReport.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildGoalkeeperTtdPanel(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainTtdPlayerList(List<Map<String, dynamic>> rows, {bool compact = false}) {
    final selectedKey = _selectedMainTtdPlayerKey;
    final summaryActive = selectedKey == null;

    final playerButtons = rows.map((row) {
      final key = _mainTtdPlayerKey(row);
      final name = _playerName(row);
      final position = _translatePosition(_s(row["group_key"] ?? row["position"] ?? row["role"]));
      return _mainTtdPlayerButton(
        title: name,
        subtitle: position,
        active: selectedKey == key,
        imageUrl: _playerPhotoUrl(row),
        onTap: () => setState(() => _selectedMainTtdPlayerKey = key),
        total: _mainTtdTotal(row),
      );
    }).toList();

    final summaryButton = _mainTtdPlayerButton(
      title: "Вся команда",
      subtitle: "суммарно по матчу",
      active: summaryActive,
      imageUrl: null,
      onTap: () => setState(() => _selectedMainTtdPlayerKey = null),
      total: _i(_summaryMainTtdRow(rows)["ttd_total"]),
    );

    if (compact) {
      final compactItems = [summaryButton, ...playerButtons];
      return SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: compactItems.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => SizedBox(width: 220, child: compactItems[index]),
        ),
      );
    }

    final items = <Widget>[
      summaryButton,
      const SizedBox(height: 8),
      for (final button in playerButtons) ...[
        button,
        const SizedBox(height: 8),
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Scrollbar(
        thumbVisibility: false,
        child: ListView(
          primary: false,
          padding: EdgeInsets.zero,
          children: items,
        ),
      ),
    );
  }

  Widget _mainTtdPlayerButton({
    required String title,
    required String subtitle,
    required bool active,
    required String? imageUrl,
    required VoidCallback onTap,
    required int total,
  }) {
    return Material(
      color: active ? primary.withOpacity(0.10) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? primary.withOpacity(0.35) : const Color(0xFFE5E7EB),
              width: active ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              imageUrl == null
                  ? Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.groups_2_outlined, color: primary, size: 22),
                    )
                  : _PlayerAvatar(
                      imageUrl: imageUrl,
                      name: title,
                      primary: primary,
                      size: 42,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? primary : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$total',
                  style: TextStyle(
                    color: active ? Colors.white : textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainTtdDetailsCard(Map<String, dynamic> row, {required bool isSummary}) {
    final title = isSummary ? "Суммарные ТТД команды" : _playerName(row);
    final subtitle = isSummary ? "Общая картина по матчу" : "Индивидуальная карточка действий";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              isSummary
                  ? Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.analytics_outlined, color: primary, size: 28),
                    )
                  : _PlayerAvatar(
                      imageUrl: _playerPhotoUrl(row),
                      name: title,
                      primary: primary,
                      size: 52,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Scrollbar(
              thumbVisibility: false,
              child: SingleChildScrollView(
                primary: false,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final twoCols = c.maxWidth > 520;
                    final children = [
                      _ttdMetricCard("Обводки", "${_mainTtdValue(row, "feint_dribble")}", Icons.directions_run_rounded),
                      _ttdMetricCard("Удары", "${_mainTtdValue(row, "shot_on_goal")}", Icons.sports_soccer_rounded),
                      _ttdMetricCard("Отборы", "${_mainTtdValue(row, "tackle_duel")}", Icons.shield_outlined),
                      _ttdMetricCard("Перехваты", "${_mainTtdValue(row, "interception")}", Icons.swap_horiz_rounded),
                      _ttdMetricCard("Подборы", "${_mainTtdValue(row, "recovery")}", Icons.restart_alt_rounded),
                      _ttdMetricCard("Игра головой", "${_mainTtdValue(row, "header_play")}", Icons.sports_handball_outlined),
                      _ttdMetricCard("Вбрасывания", "${_mainTtdValue(row, "throw_ins")}", Icons.north_east_rounded),
                      _ttdMetricCard("Острые пасы", "${_mainTtdValue(row, "pass_avp")}", Icons.trending_up_rounded),
                    ];

                    if (!twoCols) {
                      return Column(
                        children: children
                            .map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: e))
                            .toList(),
                      );
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: children
                          .map((e) => SizedBox(width: (c.maxWidth - 8) / 2, child: e))
                          .toList(),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _smallBadge("Итого", "${_mainTtdTotal(row)}", color: primary)),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Эффективность", "${_s(row["effect_percent"])}%", color: Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ttdMetricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.isEmpty ? "0" : value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportRowPass(Map<String, dynamic> row) {
    final playerName = _s(row["player_name"]).isEmpty ? "Игрок" : _s(row["player_name"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            playerName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _smallBadge("Вперёд к.", _s(row["forward_short"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Вперёд с.", _s(row["forward_medium"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Вперёд д.", _s(row["forward_long"]))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _smallBadge("Поперёк к.", _s(row["side_short"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Поперёк с.", _s(row["side_medium"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Поперёк д.", _s(row["side_long"]))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _smallBadge("Назад к.", _s(row["back_short"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Назад с.", _s(row["back_medium"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Назад д.", _s(row["back_long"]))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _smallBadge(
                  "Итого",
                  _s(row["total"]),
                  color: primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallBadge(
                  "Эффект",
                  "${_s(row["effect_percent"])}%",
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassesTab() {
    if (loadingTtd) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final filtered = passReport.where((row) {
      return _matchesSearch(_s(row["player_name"]));
    }).toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: "Передачи",
          subtitle: "Разбивка по направлениям и длине",
          child: Column(
            children: [
              _searchField(hint: "Поиск по игроку..."),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                _emptyState("Нет данных по передачам")
              else
                ...filtered.map(_reportRowPass),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalkeeperTtdPanel({bool compact = false}) {
    if (goalkeeperReport.isEmpty) return const SizedBox.shrink();

    final selectedRow = _selectedGoalkeeperKey == null
        ? goalkeeperReport.first
        : goalkeeperReport.cast<Map<String, dynamic>?>().firstWhere(
              (row) => row != null && _mainTtdPlayerKey(row) == _selectedGoalkeeperKey,
              orElse: () => goalkeeperReport.first,
            )!;

    if (compact || goalkeeperReport.length == 1) {
      return _buildSectionCard(
        title: "Вратарская статистика",
        subtitle: "Та же логика: выбираем вратаря и смотрим действия в компактной карточке",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (goalkeeperReport.length > 1) ...[
              SizedBox(
                height: 76,
                child: ListView.separated(
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  itemCount: goalkeeperReport.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final row = goalkeeperReport[index];
                    final key = _mainTtdPlayerKey(row);
                    return SizedBox(
                      width: 220,
                      child: _mainTtdPlayerButton(
                        title: _playerName(row),
                        subtitle: "вратарь",
                        active: _selectedGoalkeeperKey == key || (_selectedGoalkeeperKey == null && index == 0),
                        imageUrl: _playerPhotoUrl(row),
                        onTap: () => setState(() => _selectedGoalkeeperKey = key),
                        total: _goalkeeperTotal(row),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 330,
              child: _goalkeeperTile(selectedRow),
            ),
          ],
        ),
      );
    }

    final h = 330.0;
    return _buildSectionCard(
      title: "Вратарская статистика",
      subtitle: "Слева список вратарей, справа зафиксированная карточка действий",
      child: SizedBox(
        height: h,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 316,
              height: h,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Scrollbar(
                  thumbVisibility: false,
                  child: ListView.separated(
                    primary: false,
                    padding: EdgeInsets.zero,
                    itemCount: goalkeeperReport.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final row = goalkeeperReport[index];
                      final key = _mainTtdPlayerKey(row);
                      return _mainTtdPlayerButton(
                        title: _playerName(row),
                        subtitle: "вратарь",
                        active: _selectedGoalkeeperKey == key || (_selectedGoalkeeperKey == null && index == 0),
                        imageUrl: _playerPhotoUrl(row),
                        onTap: () => setState(() => _selectedGoalkeeperKey = key),
                        total: _goalkeeperTotal(row),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: h,
                child: _goalkeeperTile(selectedRow),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalkeeperTile(Map<String, dynamic> row) {
    final playerName = _s(row["player_name"]).isEmpty ? "Вратарь" : _s(row["player_name"]);
    final total = _goalkeeperTotal(row);
    final effect = _s(row["effect_percent"]).isEmpty ? "0" : _s(row["effect_percent"]);

    final items = [
      _ttdMetricCard("Сейвы", _s(row["saves"]), Icons.sports_handball_outlined),
      _ttdMetricCard("Пропущено", _s(row["conceded"]), Icons.remove_circle_outline_rounded),
      _ttdMetricCard("Ввод рукой", _s(row["hand_distribution"]), Icons.pan_tool_alt_outlined),
      _ttdMetricCard("Выходы", _s(row["coming_out"]), Icons.open_in_full_rounded),
      _ttdMetricCard("Ближний бой", _s(row["close_combat"]), Icons.shield_outlined),
      _ttdMetricCard("Перехваты", _s(row["interceptions"]).isEmpty ? _s(row["interceptions_gk"]) : _s(row["interceptions"]), Icons.swap_horiz_rounded),
      _ttdMetricCard("Вне штрафной", _s(row["outside_box"]), Icons.crop_free_rounded),
      _ttdMetricCard("Пас короткий", _s(row["pass_short"]).isEmpty ? _s(row["gk_pass_short"]) : _s(row["pass_short"]), Icons.short_text_rounded),
      _ttdMetricCard("Пас средний", _s(row["pass_medium"]).isEmpty ? _s(row["gk_pass_medium"]) : _s(row["pass_medium"]), Icons.horizontal_rule_rounded),
      _ttdMetricCard("Пас длинный", _s(row["pass_long"]).isEmpty ? _s(row["gk_pass_long"]) : _s(row["pass_long"]), Icons.trending_flat_rounded),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _PlayerAvatar(
                imageUrl: _playerPhotoUrl(row),
                name: playerName,
                primary: primary,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Вратарские действия по матчу",
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _smallBadge("Итого", "$total", color: primary),
              const SizedBox(width: 8),
              _smallBadge("Эффект", "$effect%", color: Colors.blue),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Scrollbar(
              thumbVisibility: false,
              child: ListView.separated(
                primary: false,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) => items[index],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_PlayerMetricItem> _buildMetricsFromVideoTotals(Map<String, dynamic> row) {
  final success = Map<String, dynamic>.from(row["success"] ?? {});
  final fail = Map<String, dynamic>.from(row["fail"] ?? {});
  final single = Map<String, dynamic>.from(row["single"] ?? {});

  // Расширенный маппинг для всех метрик
  final metricTitles = <String, String>{
    // Полевые игроки
    'feint_dribble': 'Обводки / финты',
    'shot_on_goal': 'Удары по воротам',
    'tackle_duel': 'Отборы / единоборства',
    'interception': 'Перехваты',
    'recovery': 'Подборы',
    'header_play': 'Игра головой',
    'throw_ins': 'Вбрасывания',
    'pass_avp': 'Острые передачи',
    // Передачи
    'forward_short': 'Передачи вперёд короткие',
    'forward_medium': 'Передачи вперёд средние',
    'forward_long': 'Передачи вперёд длинные',
    'side_short': 'Передачи поперёк короткие',
    'side_medium': 'Передачи поперёк средние',
    'side_long': 'Передачи поперёк длинные',
    'back_short': 'Передачи назад короткие',
    'back_medium': 'Передачи назад средние',
    'back_long': 'Передачи назад длинные',
    // Вратарь
    'hand_distribution': 'Ввод мяча рукой',
    'coming_out': 'Игра на выходах',
    'close_combat': 'Ближний бой',
    'interceptions_gk': 'Перехваты вратаря',
    'interceptions': 'Перехваты вратаря',
    'outside_box': 'Игра за штрафной',
    'pass_short': 'Передачи вратаря короткие',
    'pass_medium': 'Передачи вратаря средние',
    'pass_long': 'Передачи вратаря длинные',
    'gk_pass_short': 'Передачи вратаря короткие',
    'gk_pass_medium': 'Передачи вратаря средние',
    'gk_pass_long': 'Передачи вратаря длинные',
    // Общие для всех
    'saves': 'Сейвы',
    'conceded': 'Пропущенные голы',
    'goal': 'Голы',
    'assist': 'Голевые передачи',
    'yellow_card': 'Жёлтые карточки',
    'red_card': 'Красные карточки',
    'foul': 'Фолы',
    'foul_on': 'Фолы на себе',
    'offside': 'Офсайды',
    'corner': 'Угловые',
    'free_kick': 'Штрафные удары',
    'penalty': 'Пенальти',
  };

  final items = <_PlayerMetricItem>[];

  // Собираем все ключи из success, fail и single
  final allKeys = <String>{};
  allKeys.addAll(success.keys);
  allKeys.addAll(fail.keys);
  allKeys.addAll(single.keys);

  for (final code in allKeys) {
    final s = _i(success[code]);
    final f = _i(fail[code]);
    final singleValue = _i(single[code]);
    
    // Пропускаем нулевые значения
    if (s + f + singleValue <= 0) continue;

    // Получаем название или используем сам код с преобразованием
    String title = metricTitles[code] ?? _normalizeKey(code);
    
    if (singleValue > 0) {
      items.add(
        _PlayerMetricItem(
          code: code,
          title: title,
          success: singleValue,
          fail: 0,
        ),
      );
    } else {
      items.add(
        _PlayerMetricItem(
          code: code,
          title: title,
          success: s,
          fail: f,
        ),
      );
    }
  }

  items.sort((a, b) => b.total.compareTo(a.total));
  return items;
}

// Вспомогательная функция для преобразования snake_case в читаемый текст
String _normalizeKey(String key) {
  // Разбиваем по подчёркиваниям
  final parts = key.split('_');
  
  // Словарь для перевода отдельных слов
  const wordMap = {
    'gk': 'вратаря',
    'pass': 'передачи',
    'short': 'короткие',
    'medium': 'средние',
    'long': 'длинные',
    'forward': 'вперёд',
    'back': 'назад',
    'side': 'поперёк',
    'hand': 'рукой',
    'distribution': 'ввод',
    'coming': 'выходы',
    'out': 'игра',
    'close': 'ближний',
    'combat': 'бой',
    'interceptions': 'перехваты',
    'outside': 'вне',
    'box': 'штрафной',
    'feint': 'обводки',
    'dribble': 'финты',
    'shot': 'удары',
    'goal': 'ворота',
    'tackle': 'отборы',
    'duel': 'единоборства',
    'interception': 'перехваты',
    'recovery': 'подборы',
    'header': 'игра',
    'play': 'головой',
    'throw': 'вбрасывания',
    'ins': 'ауты',
    'avp': 'острые',
    'saves': 'сейвы',
    'conceded': 'пропущенные',
  };
  
  // Переводим каждую часть
  final translatedParts = parts.map((part) {
    return wordMap[part.toLowerCase()] ?? part;
  }).toList();
  
  // Собираем обратно с заглавной буквы
  String result = translatedParts.join(' ');
  if (result.isNotEmpty) {
    result = result[0].toUpperCase() + result.substring(1);
  }
  
  return result;
}
 Widget _playerTotalsTile(Map<String, dynamic> row) {
  final playerName = _s(row["player_name"]).isEmpty ? "Игрок" : _s(row["player_name"]);
  final groupKey = _s(row["group_key"]);
  
  // Переводим амплуа игрока
  String position = _translatePosition(groupKey);
  
  final metrics = _buildMetricsFromVideoTotals(row);

  int totalSuccess = 0;
  int totalFail = 0;
  for (final m in metrics) {
    totalSuccess += m.success;
    totalFail += m.fail;
  }
  final total = totalSuccess + totalFail;
  final efficiency = total > 0 ? (totalSuccess / total) * 100 : 0.0;

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x07000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      leading: _PlayerAvatar(
        imageUrl: _playerPhotoUrl(row),
        name: playerName,
        primary: primary,
        size: 46,
      ),
      title: Text(
        playerName,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        position,
        style: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      children: [
        Row(
          children: [
            Expanded(child: _smallBadge("Всего", '$total')),
            const SizedBox(width: 8),
            Expanded(
              child: _smallBadge(
                "Успешно",
                '$totalSuccess',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _smallBadge(
                "Ошибки",
                '$totalFail',
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (metrics.isEmpty)
          Text(
            "Нет детальных метрик",
            style: TextStyle(color: textSecondary),
          )
        else
          ...metrics.map((m) {
            final eff = m.total > 0 ? (m.success / m.total) * 100 : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _smallBadge("Всего", '${m.total}')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _smallBadge(
                          "Успешно",
                          '${m.success}',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _smallBadge(
                          "Ошибка",
                          '${m.fail}',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (eff / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Эффективность: ${eff.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    ),
  );
}

// Функция для перевода амплуа игрока
String _translatePosition(String key) {
  switch (key.toUpperCase()) {
    case 'GK':
      return 'Вратарь';
    case 'DEF':
      return 'Защитник';
    case 'MID':
      return 'Полузащитник';
    case 'FWD':
      return 'Нападающий';
    default:
      return key.isEmpty ? 'Игрок' : key;
  }
}
  Widget _buildPlayersTab() {
    if (loadingTtd) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final filtered = playerVideoTotals.where((row) {
      return _matchesSearch(_s(row["player_name"]));
    }).toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: "Игроки",
          subtitle: "Сводные ТТД за весь матч",
          child: Column(
            children: [
              _searchField(hint: "Поиск по игроку..."),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                _emptyState("Нет данных по игрокам")
              else
                ...filtered.map(_playerTotalsTile),
            ],
          ),
        ),
      ],
    );
  }

  Widget _episodeTile(Map<String, dynamic> episode) {
    final title = _s(episode["event_title"]).isEmpty
        ? (_s(episode["note"]).isEmpty ? "Эпизод" : _s(episode["note"]))
        : _s(episode["event_title"]);

    final minute = _i(episode["minute"]);
    final second = _i(episode["second"]);
    final snapshotUrl = _normalizeUrl(_s(episode["snapshot_url"]));
    final children = ((episode["children"] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final player = episode["player"] is Map
        ? Map<String, dynamic>.from(episode["player"])
        : <String, dynamic>{};

    final playerName = _s(player["full_name"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: snapshotUrl != null && snapshotUrl.isNotEmpty
              ? Image.network(
                  snapshotUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                )
              : Container(
                  width: 56,
                  height: 56,
                  color: const Color(0xFFF1F5F9),
                  child: const Icon(Icons.video_library_outlined),
                ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          "${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}"
          "${playerName.isEmpty ? "" : " • $playerName"}",
          style: TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          if (_s(episode["note"]).isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _s(episode["note"]),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (children.isEmpty)
            Text(
              "Нет дочерних действий",
              style: TextStyle(color: textSecondary),
            )
          else
            ...children.map((child) {
              final childTitle = _s(child["event_title"]).isEmpty
                  ? _s(child["event_type"])
                  : _s(child["event_title"]);

              final childPlayer = child["player"] is Map
                  ? Map<String, dynamic>.from(child["player"])
                  : <String, dynamic>{};

              final childPlayerName = _s(childPlayer["full_name"]);
              final positive = _i(child["is_positive"]) > 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: positive
                      ? Colors.green.withOpacity(0.07)
                      : Colors.red.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: positive
                        ? Colors.green.withOpacity(0.18)
                        : Colors.red.withOpacity(0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      positive
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                      color: positive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        childPlayerName.isEmpty
                            ? childTitle
                            : "$childTitle • $childPlayerName",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEpisodesTab() {
    if (loadingTtd) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final filtered = episodes.where((e) {
      final title = _s(e["event_title"]);
      final note = _s(e["note"]);
      final player = e["player"] is Map
          ? Map<String, dynamic>.from(e["player"])
          : <String, dynamic>{};
      final playerName = _s(player["full_name"]);

      return _matchesSearch("$title $note $playerName");
    }).toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: "Эпизоды матча",
          subtitle: "Эпизоды и привязанные действия",
          child: Column(
            children: [
              _searchField(hint: "Поиск по эпизодам, заметкам, игрокам..."),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                _emptyState("Эпизоды не найдены", icon: Icons.movie_filter_outlined)
              else
                ...filtered.map(_episodeTile),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showUploadVideoSheet(String type) async {
    _selectedUploadVideoPath = null;
    _selectedUploadVideoName = null;
    _selectedUploadVideoSize = null;

    _selectedUploadThumbPath = null;
    _selectedUploadThumbName = null;
    _selectedUploadThumbSize = null;

    bool localSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSB) {
            Future<void> pickVideo() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.video,
                  allowMultiple: false,
                  withData: false,
                );

                if (result == null || result.files.isEmpty) return;

                final picked = result.files.first;
                if (picked.path == null || picked.path!.isEmpty) {
                  Get.snackbar("Ошибка", "Не удалось получить путь к видео");
                  return;
                }

                final file = File(picked.path!);
                if (!await file.exists()) {
                  Get.snackbar("Ошибка", "Файл не найден");
                  return;
                }

                _selectedUploadVideoPath = picked.path!;
                _selectedUploadVideoName = picked.name;
                _selectedUploadVideoSize = await file.length();

                if (ctx.mounted) setSB(() {});
              } catch (e) {
                Get.snackbar("Ошибка", "Не удалось выбрать видео: $e");
              }
            }

            Future<void> pickThumb() async {
              final x = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 1400,
              );

              if (x == null) return;

              final file = File(x.path);
              final size = await file.length();

              _selectedUploadThumbPath = x.path;
              _selectedUploadThumbName = x.name;
              _selectedUploadThumbSize = size;

              if (ctx.mounted) setSB(() {});
            }

            final title =
                type == "highlight" ? "Загрузить нарезку" : "Загрузить полное видео";

            return SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 6,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.video_library_outlined,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: localSaving ? null : pickVideo,
                            icon: const Icon(Icons.video_library_outlined),
                            label: Text(
                              _selectedUploadVideoPath == null
                                  ? "Выбрать видео"
                                  : "Видео выбрано",
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        if (_selectedUploadVideoPath != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedUploadVideoName ?? "Видео",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Размер: ${_formatFileSize(_selectedUploadVideoSize ?? 0)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: localSaving ? null : pickThumb,
                            icon: const Icon(Icons.image_outlined),
                            label: Text(
                              _selectedUploadThumbPath == null
                                  ? "Выбрать превью"
                                  : "Превью выбрано",
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        if (_selectedUploadThumbPath != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              "${_selectedUploadThumbName ?? "Превью"} • ${_formatFileSize(_selectedUploadThumbSize ?? 0)}",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: localSaving
                                ? null
                                : () async {
                                    if (_selectedUploadVideoPath == null ||
                                        _selectedUploadVideoPath!.isEmpty) {
                                      Get.snackbar(
                                        "Ошибка",
                                        "Сначала выберите видео",
                                      );
                                      return;
                                    }

                                    final videoFile = File(_selectedUploadVideoPath!);
                                    if (!await videoFile.exists()) {
                                      Get.snackbar(
                                        "Ошибка",
                                        "Выбранный файл не найден",
                                      );
                                      return;
                                    }

                                    setSB(() => localSaving = true);

                                    if (Navigator.of(ctx).canPop()) {
                                      Navigator.of(ctx).pop();
                                    }

                                    await _uploadVideoWithChunks(
                                      type: type,
                                      video: videoFile,
                                      thumbnail: _selectedUploadThumbPath != null
                                          ? File(_selectedUploadThumbPath!)
                                          : null,
                                    );
                                  },
                            icon: localSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload_outlined),
                            label: Text(
                              localSaving ? "Подготовка..." : "Сохранить видео",
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _uploadVideoWithChunks({
    required String type,
    required File video,
    File? thumbnail,
  }) async {
    if (matchId <= 0) {
      Get.snackbar("Ошибка", "Некорректный match_id");
      return;
    }

    setState(() => uploadingVideo = true);

    final progressNotifier = ValueNotifier<double>(0.0);
    final textNotifier = ValueNotifier<String>("Подготовка...");

    _showUploadingDialog(
      progressNotifier: progressNotifier,
      textNotifier: textNotifier,
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final notes = type == "highlight" ? "Видео момента" : "Полное видео матча";

      final result = await _chunkUploadService.uploadVideoInChunks(
        videoFile: video,
        thumbnailFile: thumbnail,
        matchId: matchId,
        teamId: teamId,
        coachId: _coachId,
        notes: notes,
        videoType: type,
        onProgress: (progress, text) {
          progressNotifier.value = progress.clamp(0.0, 1.0);
          textNotifier.value = text;
        },
      );

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (result["success"] == true) {
        Get.snackbar(
          "Успешно",
          "Видео добавлено",
          backgroundColor: primary,
          colorText: Colors.white,
        );
        await load();
      } else {
        Get.snackbar(
          "Ошибка загрузки",
          _s(result["message"]).isNotEmpty
              ? _s(result["message"])
              : "Не удалось загрузить видео",
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      Get.snackbar(
        "Ошибка сети",
        "Не удалось загрузить видео: $e",
      );
    } finally {
      progressNotifier.dispose();
      textNotifier.dispose();
      if (mounted) setState(() => uploadingVideo = false);
    }
  }

  void _showUploadingDialog({
    required ValueNotifier<double> progressNotifier,
    required ValueNotifier<String> textNotifier,
  }) {
    Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (_, progress, __) {
              return ValueListenableBuilder<String>(
                valueListenable: textNotifier,
                builder: (_, text, __) {
                  return SizedBox(
                    width: 320,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Загрузка видео",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Пожалуйста, не закрывай приложение",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress <= 0 ? null : progress,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: AlwaysStoppedAnimation<Color>(primary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          text,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _watchVideo(String videoUrl, {String? title}) {
    final normalized = _normalizeUrl(videoUrl) ?? "";
    if (normalized.isEmpty) {
      Get.snackbar("Видео", "URL отсутствует");
      return;
    }

    Get.to(
      () => MatchVideoPlayerScreen(
        videoUrl: normalized,
        title: title ?? _matchTitleForReview(),
      ),
    );
  }

  Future<void> _openMatchVideoAnalysis(Map<String, dynamic> video) async {
  final videoUrl = _s(video["video_url"]);
  final normalized = _normalizeUrl(videoUrl) ?? "";

  if (normalized.isEmpty) {
    Get.snackbar("Внимание", "Видео матча отсутствует");
    return;
  }

  await Get.to(
    () => VideoMatchReviewScreen(
      matchId: matchId,
      teamId: teamId,
      coachId: _coachId,
      teamName: teamName,
      videoUrl: normalized,
      videoId: matchId,
      matchTitle: _matchTitleForReview(),
    ),
  );

  await _loadTtdReport();
  if (mounted) {
    setState(() {});
  }
}
 
    Future<void> _deleteVideo(Map<String, dynamic> video) async {
    final videoId = int.tryParse('${video["id"] ?? 0}') ?? 0;
    final fileName =
        _s(video["file_name"]).isEmpty ? "видео" : _s(video["file_name"]);

    if (videoId <= 0) {
      Get.snackbar(
        "Ошибка",
        "Не найден id видео",
      );
      return;
    }

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          "Удалить видео?",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text('Вы действительно хотите удалить "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final resp = await http
          .post(
            Uri.parse(deleteVideoUrl),
            headers: const {"Content-Type": "application/json; charset=utf-8"},
            body: jsonEncode({
              "video_id": videoId,
              "match_id": matchId,
              "team_id": teamId,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeResponse(resp);

      if (data["success"] == true || data["status"] == "success") {
        Get.snackbar(
          "Успешно",
          "Видео удалено",
          backgroundColor: primary,
          colorText: Colors.white,
        );
        await load();
      } else {
        Get.snackbar(
          "Ошибка удаления",
          data["message"]?.toString() ?? "Не удалось удалить видео",
        );
      }
    } catch (_) {
      Get.snackbar(
        "Ошибка сети",
        "Не удалось удалить видео",
      );
    }
  }

  Widget _buildHighlightsTab() {
    final videos = ((match?["videos"] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => _s(e["video_type"]) == "highlight")
        .toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: "Нарезка моментов",
          subtitle: "Короткие фрагменты игры для разбора — в таком же компактном виде, как видео матча",
          trailing: ElevatedButton.icon(
            onPressed: uploadingVideo ? null : () => _showUploadVideoSheet("highlight"),
            icon: const Icon(Icons.video_library_outlined, size: 17),
            label: Text(uploadingVideo ? "Загрузка..." : "Добавить"),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (videos.isEmpty)
                _emptyState("Видеонарезок пока нет", icon: Icons.video_collection_outlined)
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: videos.map((v) {
                    final rawTitle = _s(v["file_name"]);
                    final title = _formatVideoTitle(rawTitle, "Видео момента");
                    return _VideoTile(
                      title: title,
                      subtitle: _videoMeta(v),
                      url: _s(v["video_url"]),
                      onWatch: () => _watchVideo(
                        _s(v["video_url"]),
                        title: title,
                      ),
                      onDelete: () => _deleteVideo(v),
                      primary: primary,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideosTab() {
    final videos = ((match?["videos"] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => _s(e["video_type"]) == "full")
        .toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: "Видео матча",
          subtitle: "Полные записи игры без широких растянутых баннеров",
          trailing: ElevatedButton.icon(
            onPressed:
                uploadingVideo ? null : () => _showUploadVideoSheet("full"),
            icon: const Icon(Icons.cloud_upload_outlined, size: 17),
            label: Text(uploadingVideo ? "Загрузка..." : "Добавить"),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (videos.isEmpty)
                _emptyState("Видео матча пока нет", icon: Icons.videocam_off_outlined)
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: videos.map((v) {
                    final rawTitle = _s(v["file_name"]);
                    final title = _formatVideoTitle(rawTitle, "Видео матча");
                    return _VideoTile(
                      title: title,
                      subtitle: _videoMeta(v),
                      url: _s(v["video_url"]),
                      onWatch: () => _watchVideo(
                        _s(v["video_url"]),
                        title: title,
                      ),
                      onAnalyze: () => _openMatchVideoAnalysis(v),
                      onDelete: () => _deleteVideo(v),
                      primary: primary,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<_MatchDetailNavItem> get _matchNavItems => const [
        _MatchDetailNavItem(
          title: "Обзор",
          subtitle: "данные матча",
          icon: Icons.dashboard_customize_outlined,
        ),
        _MatchDetailNavItem(
          title: "Основные ТТД",
          subtitle: "действия",
          icon: Icons.query_stats_rounded,
        ),
        _MatchDetailNavItem(
          title: "Передачи",
          subtitle: "точность",
          icon: Icons.sync_alt_rounded,
        ),
        _MatchDetailNavItem(
          title: "Игроки",
          subtitle: "вклад",
          icon: Icons.groups_2_outlined,
        ),
        _MatchDetailNavItem(
          title: "Эпизоды",
          subtitle: "моменты",
          icon: Icons.movie_filter_outlined,
        ),
        _MatchDetailNavItem(
          title: "Нарезка",
          subtitle: "фрагменты",
          icon: Icons.video_library_outlined,
        ),
        _MatchDetailNavItem(
          title: "Видео",
          subtitle: "полная игра",
          icon: Icons.play_circle_outline_rounded,
        ),
      ];

  String get _currentTabTitle {
    final index = _tabController.index.clamp(0, _matchNavItems.length - 1);
    return _matchNavItems[index].title;
  }

  Widget _buildActiveTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildMainTtdTab(),
        _buildPassesTab(),
        _buildPlayersTab(),
        _buildEpisodesTab(),
        _buildHighlightsTab(),
        _buildVideosTab(),
      ],
    );
  }

  Widget _buildCmrTopBar({
    required bool compact,
    required String title,
    required String opponent,
    required String date,
    required String competition,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE5E7EB).withOpacity(0.9),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: compact ? 40 : 44,
              height: compact ? 40 : 44,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primary.withOpacity(0.18)),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => Get.back(),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: primary,
                  size: compact ? 21 : 23,
                ),
                tooltip: "Назад",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        compact ? _currentTabTitle : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 16 : 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        compact
                            ? "$teamName • $opponent"
                            : [
                                teamName,
                                if (opponent.isNotEmpty) "соперник: $opponent",
                                if (date.isNotEmpty) date,
                                if (competition.isNotEmpty) competition,
                              ].join(" • "),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            if (!compact)
              _CmrToolbarButton(
                label: "PDF",
                icon: Icons.picture_as_pdf_outlined,
                onTap: _exportPdfStub,
                primary: primary,
              ),
            if (!compact) const SizedBox(width: 8),
            _CmrToolbarButton(
              label: compact ? "" : (saving ? "Сохранение" : "Сохранить"),
              icon: saving ? Icons.hourglass_top_rounded : Icons.save_rounded,
              onTap: saving ? null : _saveAll,
              primary: primary,
              filled: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCmrSidebar({
    required String title,
    required String opponent,
    required String date,
    required String score,
  }) {
    return Container(
      width: 248,
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.sports_soccer_rounded,
                          color: primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Детали матча",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CmrMiniPill(icon: Icons.scoreboard_outlined, text: score),
                      if (date.isNotEmpty)
                        _CmrMiniPill(icon: Icons.calendar_today_outlined, text: date),
                      if (opponent.isNotEmpty)
                        _CmrMiniPill(icon: Icons.shield_outlined, text: opponent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  itemCount: _matchNavItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = _matchNavItems[index];
                    final active = _tabController.index == index;
                    return _MatchSidebarButton(
                      item: item,
                      active: active,
                      primary: primary,
                      onTap: () {
                        _tabController.animateTo(index);
                        setState(() {});
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMenuSheet() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Меню матча",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _matchNavItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _matchNavItems[index];
                      final active = _tabController.index == index;
                      return _MatchSidebarButton(
                        item: item,
                        active: active,
                        primary: primary,
                        onTap: () {
                          Get.back();
                          _tabController.animateTo(index);
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCmrCompactNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_matchNavItems.length, (index) {
                      final item = _matchNavItems[index];
                      final active = _tabController.index == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            _tabController.animateTo(index);
                            setState(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: active ? primary.withOpacity(0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: active
                                    ? primary.withOpacity(0.25)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 18,
                                  color: active ? primary : textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: active ? primary : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _buildMobileMenuSheet(),
              );
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.menu_rounded, color: primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _s(match?["title"]).isEmpty ? "Матч" : _s(match?["title"]);
    final competition = _s(match?["competition_name"]);
    final date = _s(match?["match_date"]).isEmpty
        ? _s(match?["info_date"])
        : _s(match?["match_date"]);
    final opponent =
        _s(match?["opponent"]).isEmpty ? "Соперник" : _s(match?["opponent"]);
    final ourScore =
        _s(match?["our_score"]).isEmpty ? "0" : _s(match?["our_score"]);
    final oppScore = _s(match?["opponent_score"]).isEmpty
        ? "0"
        : _s(match?["opponent_score"]);
    final score = "$ourScore:$oppScore";

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 980;
        final isTablet = constraints.maxWidth >= 720 && constraints.maxWidth < 980;
        final compact = !isDesktop;

        final page = Scaffold(
          backgroundColor: bg,
          body: loading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primary),
                      const SizedBox(height: 16),
                      Text(
                        "Загрузка данных матча...",
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildCmrTopBar(
                      compact: compact,
                      title: title,
                      opponent: opponent,
                      date: date,
                      competition: competition,
                    ),
                    Expanded(
                      child: isDesktop
                          ? Row(
                              children: [
                                _buildCmrSidebar(
                                  title: title,
                                  opponent: opponent,
                                  date: date,
                                  score: score,
                                ),
                                Expanded(
                                  child: Container(
                                    color: Colors.white,
                                    child: Column(
                                      children: [
                                        Expanded(child: _buildActiveTabContent()),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildCmrCompactNav(),
                                Expanded(child: _buildActiveTabContent()),
                              ],
                            ),
                    ),
                  ],
                ),
          floatingActionButton: compact
              ? FloatingActionButton.extended(
                  onPressed: saving ? null : _saveAll,
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(saving ? "Сохранение" : "Сохранить"),
                )
              : null,
        );

        return page;
      },
    );
  }
}



class _OverviewMetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;

  const _OverviewMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.hint,
  });
}

class _MatchDetailNavItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const _MatchDetailNavItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _CmrToolbarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color primary;
  final bool filled;

  const _CmrToolbarButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: filled ? Colors.white : primary),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 12 : 14),
          decoration: BoxDecoration(
            color: filled ? primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: filled ? primary : const Color(0xFFE5E7EB),
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _CmrMiniPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CmrMiniPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchSidebarButton extends StatelessWidget {
  final _MatchDetailNavItem item;
  final bool active;
  final Color primary;
  final VoidCallback onTap;

  const _MatchSidebarButton({
    required this.item,
    required this.active,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? primary : const Color(0xFF64748B);
    final titleColor = active ? const Color(0xFF0F172A) : const Color(0xFF334155);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active ? primary.withOpacity(0.11) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? primary.withOpacity(0.25) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: active ? Colors.white : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? primary.withOpacity(0.22)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Icon(item.icon, color: fg, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: active ? primary : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String url;
  final VoidCallback onWatch;
  final VoidCallback? onAnalyze;
  final VoidCallback? onDelete;
  final Color primary;

  const _VideoTile({
    required this.title,
    this.subtitle,
    required this.url,
    required this.onWatch,
    this.onAnalyze,
    this.onDelete,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width >= 1100
        ? 330.0
        : width >= 720
            ? 300.0
            : double.infinity;

    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1.15,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: primary.withOpacity(0.18),
                      width: 1.1,
                    ),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          height: 1.15,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _VideoActionPill(
                  label: "Смотреть",
                  icon: Icons.visibility_outlined,
                  onTap: onWatch,
                  foreground: primary,
                  background: Colors.white,
                  borderColor: primary.withOpacity(0.18),
                ),
                if (onAnalyze != null)
                  _VideoActionPill(
                    label: "Анализ",
                    icon: Icons.analytics_outlined,
                    onTap: onAnalyze!,
                    foreground: Colors.white,
                    background: primary,
                    borderColor: primary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color foreground;
  final Color background;
  final Color borderColor;

  const _VideoActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.foreground,
    required this.background,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12.5,
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

class _PlayerAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final Color primary;
  final double size;

  const _PlayerAvatar({
    required this.imageUrl,
    required this.name,
    required this.primary,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e.substring(0, 1).toUpperCase())
        .join();

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.34),
      child: Container(
        width: size,
        height: size,
        color: primary.withOpacity(0.10),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(initials),
              )
            : _fallback(initials),
      ),
    );
  }

  Widget _fallback(String initials) {
    return Center(
      child: Text(
        initials.isEmpty ? "И" : initials,
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.28,
        ),
      ),
    );
  }
}

class _PlayerMetricItem {
  final String code;
  final String title;
  final int success;
  final int fail;

  const _PlayerMetricItem({
    required this.code,
    required this.title,
    required this.success,
    required this.fail,
  });

  int get total => success + fail;
}

class TeamVideoUploadDraft {
  final String uploadId;
  final String videoPath;
  final String? thumbnailPath;
  final int matchId;
  final int teamId;
  final int coachId;
  final String notes;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final int lastUploadedChunk;
  final String videoType;

  const TeamVideoUploadDraft({
    required this.uploadId,
    required this.videoPath,
    required this.thumbnailPath,
    required this.matchId,
    required this.teamId,
    required this.coachId,
    required this.notes,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.lastUploadedChunk,
    required this.videoType,
  });

  Map<String, dynamic> toJson() => {
        'upload_id': uploadId,
        'video_path': videoPath,
        'thumbnail_path': thumbnailPath,
        'match_id': matchId,
        'team_id': teamId,
        'coach_id': coachId,
        'notes': notes,
        'file_name': fileName,
        'file_size': fileSize,
        'total_chunks': totalChunks,
        'last_uploaded_chunk': lastUploadedChunk,
        'video_type': videoType,
      };

  factory TeamVideoUploadDraft.fromJson(Map<String, dynamic> json) {
    return TeamVideoUploadDraft(
      uploadId: (json['upload_id'] ?? '').toString(),
      videoPath: (json['video_path'] ?? '').toString(),
      thumbnailPath: json['thumbnail_path']?.toString(),
      matchId: int.tryParse('${json['match_id']}') ?? 0,
      teamId: int.tryParse('${json['team_id']}') ?? 0,
      coachId: int.tryParse('${json['coach_id']}') ?? 0,
      notes: (json['notes'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      fileSize: int.tryParse('${json['file_size']}') ?? 0,
      totalChunks: int.tryParse('${json['total_chunks']}') ?? 0,
      lastUploadedChunk: int.tryParse('${json['last_uploaded_chunk']}') ?? -1,
      videoType: (json['video_type'] ?? 'full').toString(),
    );
  }
}

class ChunkUploadService {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String uploadChunkUrl =
      "$apiBase/upload_team_match_video_chunk.php";
  static const String completeUploadUrl =
      "$apiBase/complete_team_match_video_upload.php";
  static const String uploadStatusUrl =
      "$apiBase/get_team_match_upload_status.php";
  static const String cancelUploadUrl =
      "$apiBase/cancel_team_match_video_upload.php";

  static const String _draftKey = 'team_video_upload_draft_v1';

  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  Future<Map<String, dynamic>> uploadVideoInChunks({
    required File videoFile,
    File? thumbnailFile,
    required int matchId,
    required int teamId,
    required int coachId,
    required String notes,
    required String videoType,
    required void Function(double progress, String text) onProgress,
    String? resumeUploadId,
  }) async {
    if (!await videoFile.exists()) {
      return {
        "success": false,
        "message": "Видео файл не найден",
      };
    }

    final fileLength = await videoFile.length();
    final fileName = videoFile.uri.pathSegments.last;
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'mp4';

    const int chunkSize = 1 * 1024 * 1024;
    final int totalChunks = (fileLength / chunkSize).ceil();

    final uploadId = resumeUploadId ??
        _buildUploadId(
          matchId: matchId,
          teamId: teamId,
          coachId: coachId,
          fileName: fileName,
          fileLength: fileLength,
          videoType: videoType,
        );

    final existingDraft = await loadDraft();
    if (existingDraft == null || existingDraft.uploadId != uploadId) {
      await _saveDraft(
        TeamVideoUploadDraft(
          uploadId: uploadId,
          videoPath: videoFile.path,
          thumbnailPath: thumbnailFile?.path,
          matchId: matchId,
          teamId: teamId,
          coachId: coachId,
          notes: notes,
          fileName: fileName,
          fileSize: fileLength,
          totalChunks: totalChunks,
          lastUploadedChunk: -1,
          videoType: videoType,
        ),
      );
    }

    final uploadedChunks = await fetchUploadedChunks(uploadId);
    final raf = videoFile.openSync(mode: FileMode.read);

    try {
      for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        if (uploadedChunks.contains(chunkIndex)) {
          final progress = (chunkIndex + 1) / totalChunks;
          onProgress(
            progress.clamp(0.0, 0.97),
            "Пропуск чанка ${chunkIndex + 1}/$totalChunks",
          );
          await _updateDraftLastChunk(chunkIndex);
          continue;
        }

        final int start = chunkIndex * chunkSize;
        final int end = min(start + chunkSize, fileLength);
        final int currentSize = end - start;

        raf.setPositionSync(start);
        final chunkBytes = raf.readSync(currentSize);

        final formData = FormData.fromMap({
          "upload_id": uploadId,
          "match_id": matchId.toString(),
          "team_id": teamId.toString(),
          "coach_id": coachId.toString(),
          "file_name": fileName,
          "file_ext": ext,
          "file_size": fileLength.toString(),
          "chunk_index": chunkIndex.toString(),
          "total_chunks": totalChunks.toString(),
          "chunk_size": currentSize.toString(),
          "notes": notes,
          "video_type": videoType,
          "chunk": MultipartFile.fromBytes(
            chunkBytes,
            filename: "chunk_$chunkIndex.part",
          ),
        });

        final response = await _postChunkWithRetry(formData);
        final decoded = _decodePlain(response.data);

        if (decoded["success"] != true) {
          return {
            "success": false,
            "message":
                decoded["message"] ?? "Ошибка загрузки чанка ${chunkIndex + 1}",
          };
        }

        await _updateDraftLastChunk(chunkIndex);

        final progress = (chunkIndex + 1) / totalChunks;
        onProgress(
          progress.clamp(0.0, 0.97),
          "Загружено ${chunkIndex + 1} из $totalChunks",
        );
      }
    } finally {
      raf.closeSync();
    }

    onProgress(0.98, "Сборка файла на сервере...");

    String? thumbnailBase64;
    String? thumbnailName;

    if (thumbnailFile != null && await thumbnailFile.exists()) {
      final bytes = await thumbnailFile.readAsBytes();
      thumbnailBase64 = base64Encode(bytes);
      thumbnailName = thumbnailFile.uri.pathSegments.last;
    }

    final completeResp = await dio.post(
      completeUploadUrl,
      data: FormData.fromMap({
        "upload_id": uploadId,
        "match_id": matchId.toString(),
        "team_id": teamId.toString(),
        "coach_id": coachId.toString(),
        "file_name": fileName,
        "file_ext": ext,
        "file_size": fileLength.toString(),
        "total_chunks": totalChunks.toString(),
        "notes": notes,
        "video_type": videoType,
        if (thumbnailBase64 != null) "thumbnail_base64": thumbnailBase64,
        if (thumbnailName != null) "thumbnail_name": thumbnailName,
      }),
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    final result = _decodePlain(completeResp.data);

    if (result["success"] == true) {
      await clearDraft();
    }

    onProgress(1.0, "Загрузка завершена");
    return result;
  }

  Future<Response<dynamic>> _postChunkWithRetry(FormData formData) async {
    DioException? lastError;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        return await dio.post(
          uploadChunkUrl,
          data: formData,
          options: Options(
            contentType: 'multipart/form-data',
          ),
        );
      } on DioException catch (e) {
        lastError = e;
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }

    throw lastError ??
        DioException(
          requestOptions: RequestOptions(path: uploadChunkUrl),
          error: "Не удалось загрузить чанк",
        );
  }

  Future<Set<int>> fetchUploadedChunks(String uploadId) async {
    try {
      final resp = await dio.post(
        uploadStatusUrl,
        data: FormData.fromMap({
          "upload_id": uploadId,
        }),
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      final decoded = _decodePlain(resp.data);
      if (decoded["success"] == true && decoded["uploaded_chunks"] is List) {
        return (decoded["uploaded_chunks"] as List)
            .map((e) => int.tryParse('$e') ?? -1)
            .where((e) => e >= 0)
            .toSet();
      }
    } catch (_) {}

    return <int>{};
  }

  Future<void> cancelUploadOnServer(String uploadId) async {
    try {
      await dio.post(
        cancelUploadUrl,
        data: FormData.fromMap({
          "upload_id": uploadId,
        }),
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
    } catch (_) {}
  }

  Future<void> _saveDraft(TeamVideoUploadDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
  }

  Future<TeamVideoUploadDraft?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return TeamVideoUploadDraft.fromJson(map);
      }
      if (map is Map) {
        return TeamVideoUploadDraft.fromJson(Map<String, dynamic>.from(map));
      }
    } catch (_) {}

    return null;
  }

  Future<void> _updateDraftLastChunk(int chunkIndex) async {
    final draft = await loadDraft();
    if (draft == null) return;

    final updated = TeamVideoUploadDraft(
      uploadId: draft.uploadId,
      videoPath: draft.videoPath,
      thumbnailPath: draft.thumbnailPath,
      matchId: draft.matchId,
      teamId: draft.teamId,
      coachId: draft.coachId,
      notes: draft.notes,
      fileName: draft.fileName,
      fileSize: draft.fileSize,
      totalChunks: draft.totalChunks,
      lastUploadedChunk: chunkIndex,
      videoType: draft.videoType,
    );

    await _saveDraft(updated);
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  String _buildUploadId({
    required int matchId,
    required int teamId,
    required int coachId,
    required String fileName,
    required int fileLength,
    required String videoType,
  }) {
    final raw =
        "$matchId|$teamId|$coachId|$fileName|$fileLength|$videoType|resume-stable";
    return md5.convert(utf8.encode(raw)).toString();
  }

  Map<String, dynamic> _decodePlain(dynamic rawResponse) {
    try {
      final body = (rawResponse ?? "").toString().trim();
      final start = body.indexOf('{');
      if (start == -1) {
        return {
          "success": false,
          "message": "Некорректный ответ сервера",
        };
      }
      final clean = body.substring(start);
      final j = jsonDecode(clean);
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
      return {"success": false, "message": "Пустой JSON"};
    } catch (e) {
      return {"success": false, "message": "Ошибка разбора ответа: $e"};
    }
  }
}