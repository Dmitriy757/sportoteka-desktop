import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/presentation/team_video_analysis/video_thumbnail_helper.dart';
import 'package:sportoteka/presentation/team_video_analysis/video_player_tracking_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/player_tracking_painter.dart';

class VideoMatchReviewScreen extends StatefulWidget {
  final int matchId;
  final int teamId;
  final String teamName;
  final int coachId;
  final String matchTitle;
  final String videoUrl;

  const VideoMatchReviewScreen({
    super.key,
    required this.matchId,
    required this.teamId,
    required this.teamName,
    required this.coachId,
    required this.matchTitle,
    required this.videoUrl,
  });

  @override
  State<VideoMatchReviewScreen> createState() => _VideoMatchReviewScreenState();
}

class _VideoMatchReviewScreenState extends State<VideoMatchReviewScreen>
    with SingleTickerProviderStateMixin {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getPlayersUrl = "$apiBase/get_players_by_team.php";
  static const String addEventUrl = "$apiBase/add_video_event.php";
  static const String getEventsUrl = "$apiBase/get_video_events_by_match.php";
  static const String deleteEventUrl = "$apiBase/delete_video_event.php";
  static const String getMatchTtdReportUrl = "$apiBase/get_match_ttd_report.php";

  late VideoPlayerController _controller;
  late TabController _tabController;

  bool _videoReady = false;
  bool _loading = true;
  bool _saving = false;
  bool _quickSaving = false;
  bool _generatingSnapshot = false;
  bool _reportLoading = false;
  bool _creatingEpisode = false;
  bool _isVideoFullscreen = false;
  bool _trackingMode = false;
bool _showTrackingPanel = true;
bool _showTrackingTrails = true;
bool _showTrackingLabels = true;

TrackedPlayer? _selectedTrackedPlayer;
PlayerMarkerType _selectedMarkerType = PlayerMarkerType.triangle;
Color _selectedMarkerColor = const Color(0xFF22C55E);

final List<TrackedPlayer> _trackedPlayers = [];

  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _episodes = [];
  List<Map<String, dynamic>> _filteredPlayers = [];

  List<Map<String, dynamic>> _mainReportRows = [];
  List<Map<String, dynamic>> _passReportRows = [];
  List<Map<String, dynamic>> _goalkeeperReportRows = [];

  Map<String, dynamic>? _selectedPlayer;
  Map<String, dynamic>? _selectedEpisode;

  File? _currentSnapshotFile;
  int _currentSnapshotMs = 0;

  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _playerSearchCtrl = TextEditingController();

  String _eventType = "goal";
  int _rating = 5;
  bool _isPositive = true;
  String _ttdSection = 'main';

  final List<Map<String, dynamic>> _eventTypes = const [
    {
      "code": "goal",
      "title": "Гол",
      "positive": true,
      "icon": Icons.sports_soccer,
      "color": Color(0xFF16A34A),
    },
    {
      "code": "assist",
      "title": "Голевая",
      "positive": true,
      "icon": Icons.assistant_direction,
      "color": Color(0xFF2563EB),
    },
    {
      "code": "shot_on_goal",
      "title": "Удар",
      "positive": true,
      "icon": Icons.ads_click,
      "color": Color(0xFF0EA5E9),
    },
    {
      "code": "pass_avp",
      "title": "Пас в АВП",
      "positive": true,
      "icon": Icons.compare_arrows_rounded,
      "color": Color(0xFF2563EB),
    },
    {
      "code": "tackle_duel",
      "title": "Отбор",
      "positive": true,
      "icon": Icons.shield_outlined,
      "color": Color(0xFF059669),
    },
    {
      "code": "mistake",
      "title": "Ошибка",
      "positive": false,
      "icon": Icons.error_outline,
      "color": Color(0xFFDC2626),
    },
  ];

  final List<Map<String, dynamic>> _mainTtd = const [
    {
      "code": "feint_dribble",
      "title": "Финт+обводка / Дриблинг",
      "color": Color(0xFF7C3AED),
    },
    {
      "code": "shot_on_goal",
      "title": "Удары в ворота",
      "color": Color(0xFFF59E0B),
    },
    {
      "code": "tackle_duel",
      "title": "Отбор / единоборства",
      "color": Color(0xFF059669),
    },
    {
      "code": "interception_ball",
      "title": "Перехват мяча",
      "color": Color(0xFF0891B2),
    },
    {
      "code": "recovery_ball",
      "title": "Подбор мяча",
      "color": Color(0xFF10B981),
    },
    {
      "code": "header_play",
      "title": "Игра головой",
      "color": Color(0xFF84CC16),
    },
    {
      "code": "throw_ins",
      "title": "Ауты",
      "color": Color(0xFFF97316),
    },
    {
      "code": "pass_avp",
      "title": "Пас в АВП",
      "color": Color(0xFF2563EB),
    },
  ];

  final List<Map<String, dynamic>> _passTtd = const [
    {"code": "pass_forward_short", "title": "Вперёд • К", "color": Color(0xFF2563EB)},
    {"code": "pass_forward_medium", "title": "Вперёд • С", "color": Color(0xFF3B82F6)},
    {"code": "pass_forward_long", "title": "Вперёд • Д", "color": Color(0xFF60A5FA)},
    {"code": "pass_side_short", "title": "Поперёк • К", "color": Color(0xFF0EA5E9)},
    {"code": "pass_side_medium", "title": "Поперёк • С", "color": Color(0xFF06B6D4)},
    {"code": "pass_side_long", "title": "Поперёк • Д", "color": Color(0xFF22D3EE)},
    {"code": "pass_back_short", "title": "Назад • К", "color": Color(0xFF14B8A6)},
    {"code": "pass_back_medium", "title": "Назад • С", "color": Color(0xFF10B981)},
    {"code": "pass_back_long", "title": "Назад • Д", "color": Color(0xFF34D399)},
  ];

  final List<Map<String, dynamic>> _goalkeeperTtd = const [
    {"code": "gk_conceded", "title": "Пропущен. голы", "color": Color(0xFFDC2626), "singleOnly": true},
    {"code": "gk_saves", "title": "Сейвы", "color": Color(0xFFF59E0B), "singleOnly": true},
    {"code": "gk_hand_distribution", "title": "Ввод мяча рукой", "color": Color(0xFF2563EB)},
    {"code": "gk_coming_out", "title": "Игра на выходах", "color": Color(0xFF7C3AED)},
    {"code": "gk_close_combat", "title": "Ближний бой", "color": Color(0xFF0EA5E9)},
    {"code": "gk_interceptions", "title": "Перехваты", "color": Color(0xFF0891B2)},
    {"code": "gk_outside_box", "title": "За пределами штрафной", "color": Color(0xFF16A34A)},
    {"code": "gk_pass_short", "title": "Передачи • К", "color": Color(0xFF14B8A6)},
    {"code": "gk_pass_medium", "title": "Передачи • С", "color": Color(0xFF10B981)},
    {"code": "gk_pass_long", "title": "Передачи • Д", "color": Color(0xFF84CC16)},
  ];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _videoReady = true;
        });
      });

    _playerSearchCtrl.addListener(_applyPlayerFilter);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller.dispose();
    _noteCtrl.dispose();
    _titleCtrl.dispose();
    _playerSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([
      _loadPlayers(),
      _loadMatchData(),
    ]);

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) return j;
      return {"success": false};
    } catch (_) {
      return {"success": false};
    }
  }

  String _s(dynamic v) => (v ?? "").toString();
  int _i(dynamic v) => int.tryParse(_s(v)) ?? 0;

  String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    return "https://sportotekaapp.ru${s.startsWith('/') ? s : '/$s'}";
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return "${h.toString().padLeft(2, '0')}:$m:$s";
    return "$m:$s";
  }

  String _playerFirstName(Map<String, dynamic> p) {
    return _s(p["first_name"]).isNotEmpty ? _s(p["first_name"]) : _s(p["name"]);
  }

  String _playerLastName(Map<String, dynamic> p) {
    return _s(p["last_name"]).isNotEmpty ? _s(p["last_name"]) : _s(p["surname"]);
  }

  String _playerFullName(Map<String, dynamic> p) {
    return "${_playerLastName(p)} ${_playerFirstName(p)}".trim();
  }

  String _playerPhoto(Map<String, dynamic> p) {
    return _s(p["photo"]).isNotEmpty ? _s(p["photo"]) : _s(p["image"]);
  }

  String _playerPosition(Map<String, dynamic> p) => _s(p["position"]);

  String _eventTypeTitle(String code) {
    for (final e in _eventTypes) {
      if (_s(e["code"]) == code) return _s(e["title"]);
    }
    for (final e in _mainTtd) {
      if (_s(e["code"]) == code) return _s(e["title"]);
    }
    for (final e in _passTtd) {
      if (_s(e["code"]) == code) return _s(e["title"]);
    }
    for (final e in _goalkeeperTtd) {
      if (_s(e["code"]) == code) return _s(e["title"]);
    }
    return code;
  }

  void _enterFullscreen() {
    if (!mounted) return;
    setState(() {
      _isVideoFullscreen = true;
    });
  }

  void _exitFullscreen() {
    if (!mounted) return;
    setState(() {
      _isVideoFullscreen = false;
    });
  }

  void _toggleFullscreen() {
    if (!mounted) return;
    setState(() {
      _isVideoFullscreen = !_isVideoFullscreen;
    });
  }

  void _applyPlayerFilter() {
    final q = _playerSearchCtrl.text.trim().toLowerCase();

    if (q.isEmpty) {
      _filteredPlayers = List<Map<String, dynamic>>.from(_players);
    } else {
      _filteredPlayers = _players.where((player) {
        final firstName = _playerFirstName(player).toLowerCase();
        final lastName = _playerLastName(player).toLowerCase();
        final position = _playerPosition(player).toLowerCase();
        final fullName = _playerFullName(player).toLowerCase();

        return firstName.contains(q) ||
            lastName.contains(q) ||
            fullName.contains(q) ||
            position.contains(q);
      }).toList();
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadPlayers() async {
    try {
      debugPrint('Loading players from: $getPlayersUrl?team_id=${widget.teamId}');

      final response = await http.get(
        Uri.parse('$getPlayersUrl?team_id=${widget.teamId}'),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Players response status: ${response.statusCode}');
      debugPrint('Players response body: ${response.body}');

      final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      final decoded = jsonDecode(body);

      if (decoded is List) {
        _players = List<Map<String, dynamic>>.from(decoded);
      } else if (decoded is Map<String, dynamic>) {
        if (decoded["players"] is List) {
          _players = List<Map<String, dynamic>>.from(decoded["players"]);
        } else if (decoded["data"] is List) {
          _players = List<Map<String, dynamic>>.from(decoded["data"]);
        } else {
          _players = [];
        }
      } else {
        _players = [];
      }

      debugPrint('Players loaded: ${_players.length}');
      _filteredPlayers = List<Map<String, dynamic>>.from(_players);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading players: $e');
      _players = [];
      _filteredPlayers = [];
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadMatchData() async {
    try {
      if (mounted) setState(() => _reportLoading = true);

      debugPrint('=' * 50);
      debugPrint('Loading match data for match_id: ${widget.matchId}');

      final response = await http.post(
        Uri.parse(getMatchTtdReportUrl),
        body: {"match_id": widget.matchId.toString()},
      ).timeout(const Duration(seconds: 20));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      final data = _decode(response);

      if (data["success"] == true) {
        setState(() {
          _episodes = (data["episodes"] is List)
              ? List<Map<String, dynamic>>.from(data["episodes"])
              : [];
          _mainReportRows = (data["main_report"] is List)
              ? List<Map<String, dynamic>>.from(data["main_report"])
              : [];
          _passReportRows = (data["pass_report"] is List)
              ? List<Map<String, dynamic>>.from(data["pass_report"])
              : [];
          _goalkeeperReportRows = (data["goalkeeper_report"] is List)
              ? List<Map<String, dynamic>>.from(data["goalkeeper_report"])
              : [];
        });

        debugPrint('Episodes loaded: ${_episodes.length}');
        debugPrint('Main report rows: ${_mainReportRows.length}');

        if (_episodes.isEmpty) {
          Get.snackbar(
            "Внимание",
            "Эпизоды не найдены. Создайте новый эпизод.",
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } else {
        debugPrint('Failed to load match data: ${data["message"]}');
        Get.snackbar(
          "Ошибка",
          "Не удалось загрузить данные: ${data["message"]}",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('LOAD MATCH DATA ERROR: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_videoReady) return;

    if (_controller.value.isPlaying) {
      await _controller.pause();
      if (mounted) setState(() {});
    } else {
      if (!_isVideoFullscreen) {
        _enterFullscreen();
      }
      await _controller.play();
      if (mounted) setState(() {});
    }
  }

  Future<void> _seekRelative(int seconds) async {
    if (!_videoReady) return;

    final current = _controller.value.position;
    final duration = _controller.value.duration;
    Duration target = current + Duration(seconds: seconds);

    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;

    await _controller.seekTo(target);
    if (mounted) setState(() {});
  }

  Future<void> _pauseAndCaptureSnapshot() async {
    if (!_videoReady) return;

    if (_controller.value.isPlaying) {
      await _controller.pause();
    }

    final pos = _controller.value.position;
    final timeMs = pos.inMilliseconds;

    if (mounted) {
      setState(() {
        _generatingSnapshot = true;
      });
    }

    final snap = await VideoThumbnailHelper.generateSnapshotFile(
      videoUrl: widget.videoUrl,
      timeMs: timeMs,
      quality: 95,
      maxWidth: 1600,
    );

    if (!mounted) return;

    setState(() {
      _currentSnapshotFile = snap;
      _currentSnapshotMs = timeMs;
      _generatingSnapshot = false;
    });

    if (snap == null) {
      Get.snackbar("Внимание", "Не удалось создать стоп-кадр");
    }
  }

  Future<void> _createEpisodeFromCurrentFrame() async {
    if (_creatingEpisode) return;
    if (!_videoReady) return;

    setState(() => _creatingEpisode = true);

    try {
      await _pauseAndCaptureSnapshot();

      final pos = _controller.value.position;
      final totalSeconds = pos.inSeconds;
      final minute = pos.inMinutes;
      final second = pos.inSeconds.remainder(60);

      final playerId = _selectedPlayer != null ? _i(_selectedPlayer!["id"]) : 0;

      debugPrint('Creating episode at ${minute}:$second, player_id: $playerId');

      final req = http.MultipartRequest("POST", Uri.parse(addEventUrl));
      req.fields["match_id"] = widget.matchId.toString();
      req.fields["team_id"] = widget.teamId.toString();
      req.fields["player_id"] = playerId.toString();
      req.fields["coach_id"] = widget.coachId.toString();
      req.fields["event_type"] = "episode";
      req.fields["event_title"] = _titleCtrl.text.trim().isNotEmpty
          ? _titleCtrl.text.trim()
          : "Эпизод ${_formatDuration(Duration(seconds: totalSeconds))}";
      req.fields["note"] = _noteCtrl.text.trim();
      req.fields["minute"] = minute.toString();
      req.fields["second"] = second.toString();
      req.fields["timecode_seconds"] = totalSeconds.toString();
      req.fields["rating"] = _rating.toString();
      req.fields["is_positive"] = "1";

      if (_currentSnapshotFile != null && await _currentSnapshotFile!.exists()) {
        debugPrint('Adding snapshot file: ${_currentSnapshotFile!.path}');
        req.files.add(
          await http.MultipartFile.fromPath(
            "snapshot",
            _currentSnapshotFile!.path,
          ),
        );
      }

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);

      debugPrint('Create episode response status: ${resp.statusCode}');
      debugPrint('Create episode response body: ${resp.body}');

      final data = _decode(resp);

      if (data["success"] == true) {
        debugPrint('Episode created successfully with ID: ${data["event_id"]}');

        await Future.delayed(const Duration(milliseconds: 500));

        await _loadMatchData();

        _titleCtrl.clear();
        _noteCtrl.clear();

        if (_episodes.isNotEmpty) {
          setState(() {
            _selectedEpisode = _episodes.first;
          });
          debugPrint('Selected first episode: ${_episodes.first['id']}');
        }

        Get.snackbar(
          "Готово",
          "Эпизод создан",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white,
        );
      } else {
        debugPrint('Failed to create episode: ${data["message"]}');
        Get.snackbar(
          "Ошибка",
          _s(data["message"]).isNotEmpty ? _s(data["message"]) : "Не удалось создать эпизод",
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('CREATE EPISODE ERROR: $e');
      Get.snackbar("Ошибка", "Не удалось создать эпизод: $e");
    } finally {
      if (mounted) {
        setState(() => _creatingEpisode = false);
      }
    }
  }

  Future<void> _selectEpisode(Map<String, dynamic> episode) async {
    debugPrint('Selecting episode: ${episode['id']}');

    setState(() {
      _selectedEpisode = episode;
    });

    final timeSec = _i(episode["timecode_seconds"]);
    if (_videoReady && timeSec > 0) {
      await _controller.pause();
      await _controller.seekTo(Duration(seconds: timeSec));
    }

    _titleCtrl.text = _s(episode["event_title"]);
    _noteCtrl.text = _s(episode["note"]);

    final playerId = _i(episode["player_id"]);
    if (playerId > 0) {
      final foundPlayer = _players.where((p) => _i(p["id"]) == playerId).toList();
      if (foundPlayer.isNotEmpty) {
        setState(() {
          _selectedPlayer = foundPlayer.first;
        });
      }
    }
  }

  Future<void> _clearSelectedEpisode() async {
    setState(() {
      _selectedEpisode = null;
    });
    _titleCtrl.clear();
    _noteCtrl.clear();
  }

  Future<void> _editEpisode(Map<String, dynamic> episode) async {
    _titleCtrl.text = _s(episode["event_title"]);
    _noteCtrl.text = _s(episode["note"]);

    Get.dialog(
      AlertDialog(
        title: const Text("Редактировать эпизод"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Название эпизода",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: "Заметка",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _updateEpisode(episode['id']);
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEpisode(int episodeId) async {
    try {
      final response = await http.post(
        Uri.parse("$apiBase/update_video_event.php"),
        body: {
          "event_id": episodeId.toString(),
          "event_title": _titleCtrl.text.trim(),
          "note": _noteCtrl.text.trim(),
        },
      );

      final data = _decode(response);

      if (data["success"] == true) {
        await _loadMatchData();
        Get.snackbar("Готово", "Эпизод обновлен");
      } else {
        Get.snackbar("Ошибка", "Не удалось обновить эпизод");
      }
    } catch (e) {
      Get.snackbar("Ошибка", "Сетевая ошибка");
    }
  }

  Future<void> _saveQuickTtd({
    required String metricCode,
    required String metricTitle,
    required bool isSuccess,
  }) async {
    if (_selectedPlayer == null) {
      Get.snackbar("Ошибка", "Сначала выбери игрока");
      return;
    }

    if (_selectedEpisode == null) {
      Get.snackbar("Ошибка", "Сначала выбери эпизод из списка справа");
      return;
    }

    setState(() => _quickSaving = true);

    try {
      final totalSeconds = _i(_selectedEpisode!["timecode_seconds"]);

      final req = http.MultipartRequest("POST", Uri.parse(addEventUrl));
      req.fields["match_id"] = widget.matchId.toString();
      req.fields["team_id"] = widget.teamId.toString();
      req.fields["player_id"] = _s(_selectedPlayer!["id"]);
      req.fields["coach_id"] = widget.coachId.toString();
      req.fields["parent_event_id"] = _i(_selectedEpisode!["id"]).toString();
      req.fields["event_type"] = metricCode;
      req.fields["event_title"] = metricTitle;
      req.fields["note"] = _noteCtrl.text.trim();
      req.fields["timecode_seconds"] = totalSeconds.toString();
      req.fields["rating"] = isSuccess ? "8" : "3";
      req.fields["is_positive"] = isSuccess ? "1" : "0";

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp);

      if (data["success"] == true) {
        await _loadMatchData();
        Get.snackbar(
          "Сохранено",
          "$metricTitle • ${isSuccess ? "удачно" : "неудачно"}",
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          "Ошибка",
          _s(data["message"]).isNotEmpty ? _s(data["message"]) : "Не удалось сохранить",
        );
      }
    } catch (e) {
      debugPrint('SAVE QUICK TTD ERROR: $e');
      Get.snackbar("Ошибка", "Сбой при сохранении");
    } finally {
      setState(() => _quickSaving = false);
    }
  }

  Future<void> _saveSingleTtd({
    required String metricCode,
    required String metricTitle,
    required int value,
  }) async {
    if (_selectedPlayer == null) {
      Get.snackbar("Ошибка", "Сначала выбери игрока");
      return;
    }

    if (_selectedEpisode == null) {
      Get.snackbar("Ошибка", "Сначала выбери эпизод из списка справа");
      return;
    }

    setState(() => _quickSaving = true);

    try {
      final totalSeconds = _i(_selectedEpisode!["timecode_seconds"]);

      final req = http.MultipartRequest("POST", Uri.parse(addEventUrl));
      req.fields["match_id"] = widget.matchId.toString();
      req.fields["team_id"] = widget.teamId.toString();
      req.fields["player_id"] = _s(_selectedPlayer!["id"]);
      req.fields["coach_id"] = widget.coachId.toString();
      req.fields["parent_event_id"] = _i(_selectedEpisode!["id"]).toString();
      req.fields["event_type"] = metricCode;
      req.fields["event_title"] = metricTitle;
      req.fields["note"] = _noteCtrl.text.trim();
      req.fields["timecode_seconds"] = totalSeconds.toString();
      req.fields["rating"] = value.toString();
      req.fields["is_positive"] = "1";

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp);

      if (data["success"] == true) {
        await _loadMatchData();
        Get.snackbar("Сохранено", "$metricTitle • $value");
      } else {
        Get.snackbar(
          "Ошибка",
          _s(data["message"]).isNotEmpty ? _s(data["message"]) : "Не удалось сохранить",
        );
      }
    } catch (_) {
      Get.snackbar("Ошибка", "Сбой при сохранении");
    } finally {
      setState(() => _quickSaving = false);
    }
  }

  Future<void> _saveEvent() async {
    if (_selectedPlayer == null) {
      Get.snackbar("Ошибка", "Сначала выбери игрока");
      return;
    }

    if (_selectedEpisode == null) {
      Get.snackbar("Ошибка", "Сначала выбери эпизод из списка справа");
      return;
    }

    if (_controller.value.isPlaying) {
      await _controller.pause();
    }

    setState(() => _saving = true);

    try {
      final totalSeconds = _i(_selectedEpisode!["timecode_seconds"]);

      final req = http.MultipartRequest("POST", Uri.parse(addEventUrl));
      req.fields["match_id"] = widget.matchId.toString();
      req.fields["team_id"] = widget.teamId.toString();
      req.fields["player_id"] = _s(_selectedPlayer!["id"]);
      req.fields["coach_id"] = widget.coachId.toString();
      req.fields["parent_event_id"] = _i(_selectedEpisode!["id"]).toString();
      req.fields["event_type"] = _eventType;
      req.fields["event_title"] = _titleCtrl.text.trim();
      req.fields["note"] = _noteCtrl.text.trim();
      req.fields["timecode_seconds"] = totalSeconds.toString();
      req.fields["rating"] = _rating.toString();
      req.fields["is_positive"] = _isPositive ? "1" : "0";

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp);

      if (data["success"] == true) {
        _titleCtrl.clear();
        _noteCtrl.clear();
        await _loadMatchData();
        Get.snackbar("Готово", "Правка эпизода сохранена");
      } else {
        Get.snackbar(
          "Ошибка",
          _s(data["message"]).isNotEmpty ? _s(data["message"]) : "Не удалось сохранить",
        );
      }
    } catch (_) {
      Get.snackbar("Ошибка", "Сбой при сохранении");
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteEvent(int eventId) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Удалить эпизод?"),
        content: const Text("Эпизод и его дочерние действия будут удалены."),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final resp = await http.post(
        Uri.parse(deleteEventUrl),
        body: {"event_id": eventId.toString()},
      ).timeout(const Duration(seconds: 15));

      final data = _decode(resp);

      if (data["success"] == true) {
        if (_selectedEpisode != null && _i(_selectedEpisode!["id"]) == eventId) {
          setState(() {
            _selectedEpisode = null;
          });
        }
        await _loadMatchData();
        Get.snackbar("Готово", "Эпизод удалён");
      } else {
        Get.snackbar(
          "Ошибка",
          _s(data["message"]).isNotEmpty ? _s(data["message"]) : "Не удалось удалить эпизод",
        );
      }
    } catch (_) {
      Get.snackbar("Ошибка", "Сетевая ошибка");
    }
  }

  List<Map<String, dynamic>> _reportRowsByGroup(
    List<Map<String, dynamic>> rows,
    String group,
  ) {
    return rows.where((r) => _s(r["group_key"]) == group).toList();
  }

  Widget _buildCompactHeader() {
    final selectedEpisodeId =
        _selectedEpisode != null ? "EP-${_i(_selectedEpisode!["id"])}" : null;

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => Get.back(),
              color: AppColors.textPrimary,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.matchTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  widget.teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildCompactTab(
                  title: "Видео",
                  icon: Icons.videocam_rounded,
                  index: 0,
                ),
                _buildCompactTab(
                  title: "Эпизоды",
                  icon: Icons.photo_library_rounded,
                  index: 0,
                ),
                _buildCompactTab(
                  title: "ТТД",
                  icon: Icons.table_chart_rounded,
                  index: 1,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () async {
                await _loadPlayers();
                await _loadMatchData();
              },
              color: AppColors.primaryGreen,
              padding: EdgeInsets.zero,
            ),
          ),
          if (selectedEpisodeId != null) ...[
            const SizedBox(width: 8),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedEpisodeId,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _clearSelectedEpisode,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF2563EB),
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

  Widget _buildCompactTab({
    required String title,
    required IconData icon,
    required int index,
    bool isLast = false,
  }) {
    final isSelected = _tabController.index == index;

    return InkWell(
      onTap: () => _tabController.animateTo(index),
      borderRadius: BorderRadius.horizontal(
        left: index == 0 ? const Radius.circular(20) : Radius.zero,
        right: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: index == 0 ? const Radius.circular(20) : Radius.zero,
            right: isLast ? const Radius.circular(20) : Radius.zero,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainReportTable() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sports_soccer,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Технико-тактические действия",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "С выявлением процента эффективности",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Основные",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildMainTableContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTableContent() {
    const double avatarSize = 36;

    final defenders = _reportRowsByGroup(_mainReportRows, 'def');
    final mids = _reportRowsByGroup(_mainReportRows, 'mid');
    final fwds = _reportRowsByGroup(_mainReportRows, 'fwd');
    final others = _reportRowsByGroup(_mainReportRows, 'other');

    Widget buildSectionHeader(String title, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildMetricCell(String value, {Color? color, bool isTotal = false}) {
      final parts = value.split('/');
      final success = int.tryParse(parts[0]) ?? 0;
      final fail = int.tryParse(parts[1]) ?? 0;
      final total = success + fail;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color ?? Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isTotal ? const Color(0xFF2563EB).withOpacity(0.3) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (total > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    success.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    fail.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: isTotal ? 14 : 12,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                color: isTotal ? const Color(0xFF2563EB) : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildPlayerRow(Map<String, dynamic> player) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 200,
              child: Row(
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        (player['player_name']?.toString().isNotEmpty == true)
                            ? player['player_name'][0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      player['player_name'] ?? 'Неизвестно',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              child: buildMetricCell(player['feint_dribble'] ?? '0/0'),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: buildMetricCell(player['shot_on_goal'] ?? '0/0'),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: buildMetricCell(player['tackle_duel'] ?? '0/0'),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: buildMetricCell(player['interception'] ?? '0/0'),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: buildMetricCell(player['recovery'] ?? '0/0'),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: buildMetricCell(player['header_play'] ?? '0/0'),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: buildMetricCell(player['throw_ins'] ?? '0/0'),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: buildMetricCell(player['pass_avp'] ?? '0/0'),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: buildMetricCell(
                player['ttd_total'] ?? '0/0',
                isTotal: true,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _getEffectColor(player['effect_percent'] ?? 0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${player['effect_percent'] ?? 0}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 200,
                child: const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text(
                    "Игрок",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              _buildHeaderCell("Финт+\nДриблинг", 120),
              _buildHeaderCell("Удары", 100),
              _buildHeaderCell("Отбор", 100),
              _buildHeaderCell("Перехват", 100),
              _buildHeaderCell("Подбор", 100),
              _buildHeaderCell("Голова", 100),
              _buildHeaderCell("Ауты", 80),
              _buildHeaderCell("Пас АВП", 100),
              _buildHeaderCell("Всего ТТД", 100),
              _buildHeaderCell("%", 80, isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (defenders.isNotEmpty) ...[
          buildSectionHeader("Защитники", const Color(0xFF059669)),
          const SizedBox(height: 8),
          ...defenders.map((p) => buildPlayerRow(p)),
          const SizedBox(height: 16),
        ],
        if (mids.isNotEmpty) ...[
          buildSectionHeader("Полузащитники", const Color(0xFF2563EB)),
          const SizedBox(height: 8),
          ...mids.map((p) => buildPlayerRow(p)),
          const SizedBox(height: 16),
        ],
        if (fwds.isNotEmpty) ...[
          buildSectionHeader("Нападающие", const Color(0xFFDC2626)),
          const SizedBox(height: 8),
          ...fwds.map((p) => buildPlayerRow(p)),
          const SizedBox(height: 16),
        ],
        if (others.isNotEmpty) ...[
          buildSectionHeader("Другие", const Color(0xFF7C3AED)),
          const SizedBox(height: 8),
          ...others.map((p) => buildPlayerRow(p)),
        ],
      ],
    );
  }

  Widget _buildHeaderCell(String title, double width, {bool isLast = false}) {
    return Container(
      width: width,
      padding: EdgeInsets.only(right: isLast ? 16 : 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          height: 1.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Color _getEffectColor(int percent) {
    if (percent >= 80) return const Color(0xFF16A34A);
    if (percent >= 60) return const Color(0xFFEAB308);
    if (percent >= 40) return const Color(0xFFF97316);
    return const Color(0xFFDC2626);
  }

  Widget _buildPassReportTable() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF7C3AED),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.compare_arrows,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Анализ передач",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Детальная статистика по всем передачам",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPassTableContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassTableContent() {
    final defenders = _reportRowsByGroup(_passReportRows, 'def');
    final mids = _reportRowsByGroup(_passReportRows, 'mid');
    final fwds = _reportRowsByGroup(_passReportRows, 'fwd');

    Widget buildPassCell(String value, {bool isTotal = false}) {
      final parts = value.split('/');
      final success = int.tryParse(parts[0]) ?? 0;
      final fail = int.tryParse(parts[1]) ?? 0;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isTotal ? const Color(0xFF7C3AED).withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  success.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const Text("/", style: TextStyle(color: Colors.grey)),
                Text(
                  fail.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildPlayerRow(Map<String, dynamic> player) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 180,
              child: Text(
                player['player_name'] ?? 'Неизвестно',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(width: 50, child: buildPassCell(player['forward_short'] ?? '0/0')),
            SizedBox(width: 50, child: buildPassCell(player['forward_medium'] ?? '0/0')),
            SizedBox(width: 50, child: buildPassCell(player['forward_long'] ?? '0/0')),
            SizedBox(width: 50, child: buildPassCell(player['side_short'] ?? '0/0')),
            SizedBox(width: 50, child: buildPassCell(player['side_medium'] ?? '0/0')),
            SizedBox(width: 50, child: buildPassCell(player['side_long'] ?? '0/0')),
            SizedBox(width: 50, child: buildPassCell(player['back_short'] ?? '0/0')),
            SizedBox(width: 50, child: buildPassCell(player['back_medium'] ?? '0/0')),
            SizedBox(width: 50, child: buildPassCell(player['back_long'] ?? '0/0')),
            SizedBox(
              width: 70,
              child: buildPassCell(player['total'] ?? '0/0', isTotal: true),
            ),
            SizedBox(
              width: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _getEffectColor(player['effect_percent'] ?? 0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${player['effect_percent'] ?? 0}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const SizedBox(width: 180, child: Text("Игрок", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 16),
              _buildPassHeaderGroup("Вперед", 150),
              _buildPassHeaderGroup("Поперек", 150),
              _buildPassHeaderGroup("Назад", 150),
              const SizedBox(width: 70, child: Text("Всего", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 70, child: Text("Эффект.", style: TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        if (defenders.isNotEmpty) ...[
          _buildPassSectionHeader("Защитники", const Color(0xFF059669)),
          ...defenders.map((p) => buildPlayerRow(p)),
        ],
        if (mids.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPassSectionHeader("Полузащитники", const Color(0xFF2563EB)),
          ...mids.map((p) => buildPlayerRow(p)),
        ],
        if (fwds.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPassSectionHeader("Нападающие", const Color(0xFFDC2626)),
          ...fwds.map((p) => buildPlayerRow(p)),
        ],
      ],
    );
  }

  Widget _buildPassHeaderGroup(String title, double width) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Text("К", style: TextStyle(fontSize: 10)),
              Text("С", style: TextStyle(fontSize: 10)),
              Text("Д", style: TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassSectionHeader(String title, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildGoalkeeperReportTable() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sports_handball,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Вратарская статистика",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Детальный анализ действий вратарей",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildGoalkeeperTableContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalkeeperTableContent() {
    final goalkeepers = _reportRowsByGroup(_goalkeeperReportRows, 'gk');

    Widget buildGkCell(dynamic value, {bool isTotal = false}) {
      if (value is String && value.contains('/')) {
        final parts = value.split('/');
        final success = int.tryParse(parts[0]) ?? 0;
        final fail = int.tryParse(parts[1]) ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isTotal ? const Color(0xFFDC2626).withOpacity(0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    success.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const Text("/", style: TextStyle(color: Colors.grey)),
                  Text(
                    fail.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const SizedBox(width: 180, child: Text("Игрок", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 16),
              const SizedBox(width: 70, child: Text("Проп.", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 70, child: Text("Сейвы", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 80, child: Text("Ввод рукой", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 80, child: Text("Выходы", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 70, child: Text("Бой", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 70, child: Text("Перехв.", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 100, child: Text("За штраф.", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 120, child: Text("Передачи", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 70, child: Text("Всего", style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 70, child: Text("Эффект.", style: TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        ...goalkeepers.map((gk) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 180,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.sports_handball,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          gk['player_name'] ?? 'Неизвестно',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(width: 70, child: buildGkCell(gk['conceded'] ?? 0)),
                SizedBox(width: 70, child: buildGkCell(gk['saves'] ?? 0)),
                SizedBox(width: 80, child: buildGkCell(gk['hand_distribution'] ?? '0/0')),
                SizedBox(width: 80, child: buildGkCell(gk['coming_out'] ?? '0/0')),
                SizedBox(width: 70, child: buildGkCell(gk['close_combat'] ?? '0/0')),
                SizedBox(width: 70, child: buildGkCell(gk['interceptions'] ?? '0/0')),
                SizedBox(width: 100, child: buildGkCell(gk['outside_box'] ?? '0/0')),
                SizedBox(
                  width: 120,
                  child: Row(
                    children: [
                      Expanded(child: buildGkCell(gk['pass_short'] ?? '0/0')),
                      const SizedBox(width: 2),
                      Expanded(child: buildGkCell(gk['pass_medium'] ?? '0/0')),
                      const SizedBox(width: 2),
                      Expanded(child: buildGkCell(gk['pass_long'] ?? '0/0')),
                    ],
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: buildGkCell(gk['ttd_total'] ?? '0/0', isTotal: true),
                ),
                SizedBox(
                  width: 70,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getEffectColor(gk['effect_percent'] ?? 0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${gk['effect_percent'] ?? 0}%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFullscreenVideoOverlay() {
    if (!_videoReady) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onDoubleTap: _togglePlayPause,
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio == 0
                      ? 16 / 9
                      : _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _exitFullscreen,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.matchTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            widget.teamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _creatingEpisode
                          ? null
                          : () async {
                              _exitFullscreen();
                              await Future.delayed(const Duration(milliseconds: 150));
                              await _createEpisodeFromCurrentFrame();
                            },
                      icon: _creatingEpisode
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text("Сделать эпизод"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          _formatDuration(_controller.value.position),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _seekRelative(-10),
                          icon: const Icon(Icons.replay_10, color: Colors.white),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: _togglePlayPause,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _seekRelative(10),
                          icon: const Icon(Icons.forward_10, color: Colors.white),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _exitFullscreen,
                          icon: const Icon(
                            Icons.fullscreen_exit_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_controller.value.duration),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: _videoReady
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: GestureDetector(
                        onDoubleTap: _toggleFullscreen,
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio == 0
                              ? 16 / 9
                              : _controller.value.aspectRatio,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: VideoPlayer(_controller),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: InkWell(
                                  onTap: _toggleFullscreen,
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.45),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isVideoFullscreen
                                          ? Icons.fullscreen_exit_rounded
                                          : Icons.fullscreen_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          if (_videoReady) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formatDuration(_controller.value.position),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _seekRelative(-10),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(Icons.replay_10, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _togglePlayPause,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _seekRelative(10),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(Icons.forward_10, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _toggleFullscreen,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      _isVideoFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _creatingEpisode
                      ? null
                      : () async {
                          if (_isVideoFullscreen) {
                            _exitFullscreen();
                            await Future.delayed(const Duration(milliseconds: 150));
                          }
                          await _createEpisodeFromCurrentFrame();
                        },
                  icon: _creatingEpisode
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text("Создать эпизод"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Get.snackbar(
                            "Рисование",
                            "Следующим этапом подключим маркер, линии, круг, квадрат и текст.",
                          );
                        },
                        icon: const Icon(Icons.draw_outlined, size: 18),
                        color: Colors.white,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      Container(width: 1, height: 20, color: Colors.white.withOpacity(0.2)),
                      IconButton(
                        onPressed: () {
                          Get.snackbar(
                            "Нарезки видео",
                            "Следующим этапом подключим начало/конец нарезки и сохранение в матч.",
                          );
                        },
                        icon: const Icon(Icons.content_cut_outlined, size: 18),
                        color: Colors.white,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDuration(_controller.value.duration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayersCompact() {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Игроки",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _playerSearchCtrl,
            decoration: InputDecoration(
              hintText: "Поиск",
              prefixIcon: const Icon(Icons.search_rounded, size: 16),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredPlayers.length,
              itemBuilder: (_, i) {
                final player = _filteredPlayers[i];
                final selected = _selectedPlayer != null &&
                    _s(_selectedPlayer!["id"]) == _s(player["id"]);

                final firstName = _playerFirstName(player);
                final lastName = _playerLastName(player);
                final photo = _normalizeUrl(_playerPhoto(player));

                return InkWell(
                  onTap: () => setState(() => _selectedPlayer = player),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFEAF2FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFE5E7EB),
                          backgroundImage: photo != null ? NetworkImage(photo) : null,
                          child: photo == null
                              ? Text(
                                  (lastName.isNotEmpty
                                          ? lastName[0]
                                          : firstName.isNotEmpty
                                              ? firstName[0]
                                              : "?")
                                      .toUpperCase(),
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "$lastName $firstName".trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
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
    );
  }

  Widget _buildSectionTab({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTtdMiniCard(Map<String, dynamic> metric) {
    final title = _s(metric["title"]);
    final code = _s(metric["code"]);
    final color = metric["color"] as Color;
    final singleOnly = metric["singleOnly"] == true;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, height: 1.2),
            ),
          ),
          const SizedBox(height: 4),
          if (singleOnly)
            InkWell(
              onTap: _quickSaving
                  ? null
                  : () => _saveSingleTtd(
                        metricCode: code,
                        metricTitle: title,
                        value: 1,
                      ),
              child: Container(
                height: 26,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text("+1", style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _quickSaving
                        ? null
                        : () => _saveQuickTtd(
                              metricCode: code,
                              metricTitle: title,
                              isSuccess: true,
                            ),
                    child: Container(
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text("+", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: _quickSaving
                        ? null
                        : () => _saveQuickTtd(
                              metricCode: code,
                              metricTitle: title,
                              isSuccess: false,
                            ),
                    child: Container(
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text("–", style: TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTtdCompact() {
    final currentPlayerText = _selectedPlayer == null
        ? "Выбери игрока"
        : _playerFullName(_selectedPlayer!);

    List<Map<String, dynamic>> visibleItems;
    if (_ttdSection == 'passes') {
      visibleItems = _passTtd;
    } else if (_ttdSection == 'gk') {
      visibleItems = _goalkeeperTtd;
    } else {
      visibleItems = _mainTtd;
    }

    return Container(
      width: 300,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "ТТД / правки эпизода",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (_quickSaving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              currentPlayerText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _selectedEpisode != null
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _selectedEpisode != null
                  ? "Выбран эпизод: EP-${_i(_selectedEpisode!["id"])}"
                  : "Эпизод не выбран — выбери эпизод справа",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSectionTab(
                  title: "Осн",
                  selected: _ttdSection == 'main',
                  onTap: () => setState(() => _ttdSection = 'main'),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSectionTab(
                  title: "Пас",
                  selected: _ttdSection == 'passes',
                  onTap: () => setState(() => _ttdSection = 'passes'),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSectionTab(
                  title: "Вр",
                  selected: _ttdSection == 'gk',
                  onTap: () => setState(() => _ttdSection = 'gk'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 230,
            child: GridView.builder(
              itemCount: visibleItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.3,
              ),
              itemBuilder: (_, i) => _buildTtdMiniCard(visibleItems[i]),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Заметка тренера",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Комментарий к эпизоду, подсказка игроку, разбор ошибки...",
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text(
              "Ручная правка по эпизоду",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            children: [
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _eventTypes.map((item) {
                  final selected = _eventType == item["code"];
                  final color = item["color"] as Color;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _eventType = _s(item["code"]);
                        _isPositive = item["positive"] == true;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? color.withOpacity(0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? color : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        _s(item["title"]),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? color : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              if (_currentSnapshotFile != null)
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(_currentSnapshotFile!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: "Заголовок дочернего действия",
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Slider(
                value: _rating.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: _rating.toString(),
                onChanged: (v) {
                  setState(() => _rating = v.round());
                },
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPositive ? AppColors.primaryGreen : AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _saving ? "Сохранение..." : "Сохранить правку",
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChildAction(Map<String, dynamic> action) {
    final isPositive = (action['is_positive'] ?? 1) > 0;
    final playerName = action['player'] != null
        ? _playerFullName(action['player'])
        : (action['player_name'] ?? 'Неизвестный игрок');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPositive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.check_circle : Icons.error,
            size: 14,
            color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action['event_title'] ?? _eventTypeTitle(action['event_type'] ?? ''),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  playerName,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (action['rating'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${action['rating']}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(Map<String, dynamic> episode) {
    debugPrint('Building episode card for episode: ${episode['id']}');

    final isSelected =
        _selectedEpisode != null && _selectedEpisode!['id'] == episode['id'];
    final timeSec = episode['timecode_seconds'] ?? 0;
    final snapshotUrl = episode['snapshot_url'];
    final children = episode['children'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSelected ? 0.1 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _selectEpisode(episode),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 90,
                      height: 70,
                      color: Colors.grey.shade200,
                      child: snapshotUrl != null && snapshotUrl.isNotEmpty
                          ? Image.network(
                              snapshotUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.image, color: Colors.grey),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode['event_title'] ?? 'Эпизод',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Время: ${_formatDuration(Duration(seconds: timeSec))}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (episode['player_id'] != null && episode['player_id'] > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Игрок ID: ${episode['player_id']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteEvent(episode['id']);
                      } else if (value == 'edit') {
                        _editEpisode(episode);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Редактировать'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Удалить', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, size: 18),
                  ),
                ],
              ),
            ),
            if (children.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Действия (${children.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...children.take(3).map((child) => _buildChildAction(child)),
                    if (children.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'и еще ${children.length - 3}...',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodesList() {
    debugPrint('Building episodes list with ${_episodes.length} episodes');

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.photo_library, size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Text(
                  "Эпизоды матча",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_episodes.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _creatingEpisode
                  ? null
                  : () async {
                      if (_isVideoFullscreen) {
                        _exitFullscreen();
                        await Future.delayed(const Duration(milliseconds: 150));
                      }
                      await _createEpisodeFromCurrentFrame();
                    },
              icon: _creatingEpisode
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: const Text("Создать эпизод с текущего кадра"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _episodes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Нет эпизодов",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Нажми кнопку выше, чтобы создать\nпервый эпизод",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _episodes.length,
                    itemBuilder: (context, index) {
                      debugPrint('Building episode card for index $index');
                      final episode = _episodes[index];
                      return _buildEpisodeCard(episode);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoEpisodesTab() {
    return Column(
      children: [
        _buildCompactHeader(),
        const SizedBox(height: 4),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildVideoSection(),
              ),
              const SizedBox(width: 8),
              if (!_isVideoFullscreen) _buildPlayersCompact(),
              if (!_isVideoFullscreen) const SizedBox(width: 8),
              if (!_isVideoFullscreen) _buildTtdCompact(),
              if (!_isVideoFullscreen) const SizedBox(width: 8),
              if (!_isVideoFullscreen) _buildEpisodesList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        _buildCompactHeader(),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_reportLoading)
                  const LinearProgressIndicator(minHeight: 4),
                _buildMainReportTable(),
                _buildPassReportTable(),
                _buildGoalkeeperReportTable(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackPortrait() {
    return const Center(
      child: Text(
        "Для удобной работы открой экран в горизонтальном режиме",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7FB),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: null,
        toolbarHeight: 0,
        bottom: PreferredSize(
          preferredSize: Size.zero,
          child: Container(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 8.0,
                    right: 8.0,
                    top: 0,
                    bottom: 8.0,
                  ),
                  child: isLandscape
                      ? TabBarView(
                          controller: _tabController,
                          physics: _isVideoFullscreen
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          children: [
                            _buildVideoEpisodesTab(),
                            _buildReportsTab(),
                          ],
                        )
                      : _buildFallbackPortrait(),
                ),
                if (_isVideoFullscreen && isLandscape)
                  Positioned.fill(
                    child: _buildFullscreenVideoOverlay(),
                  ),
              ],
            ),
    );
  }
}