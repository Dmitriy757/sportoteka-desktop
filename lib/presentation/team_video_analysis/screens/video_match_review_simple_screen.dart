import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/api_constants.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/formatters.dart';
import 'package:flutter/services.dart';

class QuickTtdAction {
  final String code;
  final String title;
  final bool isPositive;
  final int rating;
  final IconData icon;

  const QuickTtdAction({
    required this.code,
    required this.title,
    required this.isPositive,
    required this.rating,
    required this.icon,
  });
}

const List<QuickTtdAction> quickTtdActions = [
  QuickTtdAction(
    code: 'pass_success',
    title: 'Передача +',
    isPositive: true,
    rating: 8,
    icon: Icons.arrow_forward_rounded,
  ),
  QuickTtdAction(
    code: 'pass_fail',
    title: 'Передача -',
    isPositive: false,
    rating: 3,
    icon: Icons.close_rounded,
  ),
  QuickTtdAction(
    code: 'tackle_success',
    title: 'Отбор +',
    isPositive: true,
    rating: 8,
    icon: Icons.shield_rounded,
  ),
  QuickTtdAction(
    code: 'tackle_fail',
    title: 'Отбор -',
    isPositive: false,
    rating: 3,
    icon: Icons.gpp_bad_rounded,
  ),
  QuickTtdAction(
    code: 'shot_success',
    title: 'Удар +',
    isPositive: true,
    rating: 9,
    icon: Icons.sports_soccer_rounded,
  ),
  QuickTtdAction(
    code: 'shot_fail',
    title: 'Удар -',
    isPositive: false,
    rating: 4,
    icon: Icons.sports_soccer_outlined,
  ),
  QuickTtdAction(
    code: 'dribble_success',
    title: 'Обводка +',
    isPositive: true,
    rating: 8,
    icon: Icons.directions_run_rounded,
  ),
  QuickTtdAction(
    code: 'dribble_fail',
    title: 'Обводка -',
    isPositive: false,
    rating: 3,
    icon: Icons.do_not_disturb_alt_rounded,
  ),
  QuickTtdAction(
    code: 'interception',
    title: 'Перехват',
    isPositive: true,
    rating: 7,
    icon: Icons.ads_click_rounded,
  ),
  QuickTtdAction(
    code: 'loss',
    title: 'Потеря',
    isPositive: false,
    rating: 2,
    icon: Icons.remove_circle_outline_rounded,
  ),
  QuickTtdAction(
    code: 'foul',
    title: 'Фол',
    isPositive: false,
    rating: 2,
    icon: Icons.warning_amber_rounded,
  ),
  QuickTtdAction(
    code: 'goal',
    title: 'Гол',
    isPositive: true,
    rating: 10,
    icon: Icons.emoji_events_rounded,
  ),
  QuickTtdAction(
    code: 'assist',
    title: 'Ассист',
    isPositive: true,
    rating: 9,
    icon: Icons.star_rounded,
  ),
];

class VideoMatchReviewSimpleScreen extends StatefulWidget {
  final int matchId;
  final int teamId;
  final String teamName;
  final int coachId;
  final String matchTitle;
  final String videoUrl;

  const VideoMatchReviewSimpleScreen({
    super.key,
    required this.matchId,
    required this.teamId,
    required this.teamName,
    required this.coachId,
    required this.matchTitle,
    required this.videoUrl,
  });

  @override
  State<VideoMatchReviewSimpleScreen> createState() =>
      _VideoMatchReviewSimpleScreenState();
}

class _VideoMatchReviewSimpleScreenState
    extends State<VideoMatchReviewSimpleScreen> {
  late VideoPlayerController _controller;

  bool _loading = true;
  bool _videoReady = false;
  bool _saving = false;

  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _filteredPlayers = [];
  Map<String, dynamic>? _selectedPlayer;

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  String _statusText = 'Выберите игрока и действие';
  String? _lastActionTitle;
@override
void initState() {
  super.initState();

  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  _setupVideo();
  _loadPlayers();
  _searchCtrl.addListener(_applyPlayerFilter);
}

@override
void dispose() {
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  _controller.dispose();
  _searchCtrl.dispose();
  _noteCtrl.dispose();
  super.dispose();
}
  void _setupVideo() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _videoReady = true;
        });
      });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  String _s(dynamic v) => Formatters.safeString(v);

  String _playerFullName(Map<String, dynamic> p) {
    final firstName =
        (p['first_name'] ?? p['firstname'] ?? '').toString().trim();
    final lastName = (p['last_name'] ?? p['lastname'] ?? '').toString().trim();
    final name = (p['name'] ?? '').toString().trim();
    final fio = (p['fio'] ?? '').toString().trim();

    final fullName = '$firstName $lastName'.trim();

    if (fullName.isNotEmpty) return fullName;
    if (fio.isNotEmpty) return fio;
    if (name.isNotEmpty) return name;

    return 'Игрок';
  }

  String _playerPhoto(Map<String, dynamic> p) {
    final raw = (p['photo'] ?? p['photo_url'] ?? p['avatar'] ?? '')
        .toString()
        .trim();

    if (raw.isEmpty) return '';

    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/$raw';
  }

  String _playerPosition(Map<String, dynamic> p) {
    return (p['position'] ?? p['player_position'] ?? '').toString().trim();
  }

  Widget _buildPlayerAvatar(String photo) {
    if (photo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          photo,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlayerAvatarFallback(),
        ),
      );
    }

    return _buildPlayerAvatarFallback();
  }

  Widget _buildPlayerAvatarFallback() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Color(0xFF64748B),
      ),
    );
  }

  Future<void> _loadPlayers() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.getPlayersUrl}?team_id=${widget.teamId}'),
      );

      final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      final decoded = jsonDecode(body);

      if (decoded is List) {
        _players = List<Map<String, dynamic>>.from(decoded);
      } else if (decoded is Map<String, dynamic>) {
        if (decoded["players"] is List) {
          _players = List<Map<String, dynamic>>.from(decoded["players"]);
        } else if (decoded["data"] is List) {
          _players = List<Map<String, dynamic>>.from(decoded["data"]);
        }
      }

      _filteredPlayers = List<Map<String, dynamic>>.from(_players);
    } catch (e) {
      debugPrint('LOAD PLAYERS ERROR: $e');
      _players = [];
      _filteredPlayers = [];
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _applyPlayerFilter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filteredPlayers = List<Map<String, dynamic>>.from(_players);
      } else {
        _filteredPlayers = _players.where((p) {
          final fullName = _playerFullName(p).toLowerCase();
          final position = _playerPosition(p).toLowerCase();
          return fullName.contains(q) || position.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (!_videoReady) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
    if (mounted) setState(() {});
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

  Future<void> _saveQuickEvent(QuickTtdAction action) async {
    if (_selectedPlayer == null) {
      setState(() {
        _statusText = 'Сначала выберите игрока';
      });
      return;
    }

    if (!_videoReady) return;

    setState(() {
      _saving = true;
      _statusText = 'Сохранение...';
    });

    try {
      final pos = _controller.value.position;
      final totalSeconds = pos.inSeconds;
      final minute = pos.inMinutes;
      final second = pos.inSeconds.remainder(60);

      final req = http.MultipartRequest(
        "POST",
        Uri.parse(ApiConstants.addEventUrl),
      );

      req.fields["match_id"] = widget.matchId.toString();
      req.fields["team_id"] = widget.teamId.toString();
      req.fields["player_id"] = _s(_selectedPlayer!["id"]);
      req.fields["coach_id"] = widget.coachId.toString();
      req.fields["event_type"] = action.code;
      req.fields["event_title"] = action.title;
      req.fields["note"] = _noteCtrl.text.trim();
      req.fields["minute"] = minute.toString();
      req.fields["second"] = second.toString();
      req.fields["timecode_seconds"] = totalSeconds.toString();
      req.fields["rating"] = action.rating.toString();
      req.fields["is_positive"] = action.isPositive ? "1" : "0";

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final data = Formatters.decodeResponse(resp);

      if (data["success"] == true) {
        setState(() {
          _lastActionTitle = action.title;
          _statusText =
              'Сохранено: ${_playerFullName(_selectedPlayer!)} • ${action.title} • ${Formatters.formatDuration(pos)}';
        });
      } else {
        setState(() {
          _statusText = 'Ошибка: ${data["message"] ?? "не удалось сохранить"}';
        });
      }
    } catch (e) {
      setState(() {
        _statusText = 'Сетевая ошибка';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Get.back(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.matchTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.teamName} • Быстрый режим',
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _saving
                  ? Colors.orange.withOpacity(0.10)
                  : Colors.green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _saving ? 'Сохраняем...' : 'Онлайн',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _saving ? Colors.orange : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPanel() {
    if (!_videoReady) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio == 0
                    ? 16 / 9
                    : _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.black87,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
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
                      Formatters.formatDuration(_controller.value.position),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _seekRelative(-10),
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                    ),
                    InkWell(
                      onTap: _togglePlayPause,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 54,
                        height: 54,
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
                    IconButton(
                      onPressed: () => _seekRelative(10),
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      Formatters.formatDuration(_controller.value.duration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Поиск игрока',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredPlayers.isEmpty
                ? const Center(
                    child: Text(
                      'Игроки не найдены',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    itemCount: _filteredPlayers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final player = _filteredPlayers[index];
                      final isSelected = _selectedPlayer != null &&
                          _s(_selectedPlayer!['id']) == _s(player['id']);

                      final photo = _playerPhoto(player);
                      final position = _playerPosition(player);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedPlayer = player;
                            _statusText =
                                'Выбран игрок: ${_playerFullName(player)}';
                          });
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFDBEAFE)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildPlayerAvatar(photo),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _playerFullName(player),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? const Color(0xFF1D4ED8)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      position.isEmpty
                                          ? 'Без позиции'
                                          : position,
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
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF2563EB),
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

  Widget _buildTtdPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Быстрые ТТД',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (_selectedPlayer != null)
                  Flexible(
                    child: Text(
                      _playerFullName(_selectedPlayer!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                hintText: 'Комментарий (необязательно)',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              itemCount: quickTtdActions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.35,
              ),
              itemBuilder: (context, index) {
                final action = quickTtdActions[index];
                final isPositive = action.isPositive;

                return InkWell(
                  onTap: _saving ? null : () => _saveQuickEvent(action),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? Colors.green.withOpacity(0.08)
                          : Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPositive
                            ? Colors.green.withOpacity(0.22)
                            : Colors.red.withOpacity(0.22),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isPositive
                                ? Colors.green.withOpacity(0.14)
                                : Colors.red.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            action.icon,
                            size: 18,
                            color: isPositive ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            action.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
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

  Widget _buildBottomStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
          if (_lastActionTitle != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _lastActionTitle!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rightPanelWidth = constraints.maxWidth > 1200
            ? 420.0
            : constraints.maxWidth > 950
                ? 360.0
                : 320.0;

        return Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildVideoPanel(),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: rightPanelWidth,
                      child: Column(
                        children: [
                          Expanded(
                            flex: 4,
                            child: _buildPlayerPanel(),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            flex: 5,
                            child: _buildTtdPanel(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomStatusBar(),
          ],
        );
      },
    );
  }

  Widget _buildPortraitFallback() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Для быстрого анализа открой экран в горизонтальном режиме',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isLandscape
              ? _buildLandscapeLayout()
              : _buildPortraitFallback(),
    );
  }
}