import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_video_analysis/video_match_review_screen.dart';

/// Новый единый экран детального матча для видеоанализа.
///
/// Визуальная модель повторяет Tracker: одна рабочая сцена, одно левое меню,
/// нижняя шкала времени и контекстные инспекторы. Старый VideoMatchReviewScreen
/// используется только как движок видео/AI/TTD без собственного shell/chrome.
class TeamMatchVideoWorkspaceScreen extends StatefulWidget {
  const TeamMatchVideoWorkspaceScreen({
    super.key,
    required this.matchId,
    required this.teamId,
    this.clubId = 0,
    this.teamName = '',
    this.clubName = '',
    this.initialMatch,
  });

  final int matchId;
  final int teamId;
  final int clubId;
  final String teamName;
  final String clubName;
  final Map<String, dynamic>? initialMatch;

  @override
  State<TeamMatchVideoWorkspaceScreen> createState() =>
      _TeamMatchVideoWorkspaceScreenState();
}

class _TeamMatchVideoWorkspaceScreenState
    extends State<TeamMatchVideoWorkspaceScreen> {
  static const _detailUrl =
      'https://sportotekaapp.ru/api/get_team_match_detail.php';

  static const _green = Color(0xFF00A750);
  static const _greenSoft = Color(0xFFF3FAF6);
  static const _ink = Color(0xFF0B0F14);
  static const _muted = Color(0xFF5F6670);
  static const _line = Color(0xFFE9ECEA);
  static const _soft = Color(0xFFF7F8F7);

  final VideoMatchReviewPlaybackController _playback =
      VideoMatchReviewPlaybackController();
  final ChunkUploadService _chunkUploadService = ChunkUploadService();

  Map<String, dynamic>? _match;
  bool _loading = true;
  bool _uploadingVideo = false;
  double _uploadProgress = 0.0;
  String _uploadText = '';
  String? _error;
  int _coachId = 0;
  String _sceneSection = 'video';
  String? _inspectorSection;

  // V8.1 mockup parity: one shared event timeline/filmstrip below the video.
  String _timelineFilter = 'all';
  final Map<int, Future<Uint8List?>> _timelineThumbCache = <int, Future<Uint8List?>>{};

  @override
  void initState() {
    super.initState();
    if (widget.initialMatch != null) {
      _match = Map<String, dynamic>.from(widget.initialMatch!);
    }
    _playback.addListener(_onPlaybackChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _playback.removeListener(_onPlaybackChanged);
    _playback.dispose();
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String _s(dynamic value) => (value ?? '').toString().trim();
  int _i(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final raw = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      final start = raw.indexOf('{');
      if (start < 0) return <String, dynamic>{};
      final json = jsonDecode(raw.substring(start));
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return Map<String, dynamic>.from(json);
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      _coachId = await PrefUtils.getUserId() ?? 0;
      final response = await http
          .post(
            Uri.parse(_detailUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'match_id': widget.matchId,
              'team_id': widget.teamId,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decode(response);
      final ok = data['success'] == true || data['status'] == 'success';
      if (!ok) {
        throw Exception(_s(data['message']).isEmpty
            ? 'Не удалось загрузить матч'
            : _s(data['message']));
      }

      final loaded = data['match'] is Map
          ? Map<String, dynamic>.from(data['match'] as Map)
          : <String, dynamic>{};

      final directVideos = data['videos'];
      if (directVideos is List) loaded['videos'] = directVideos;
      if ((loaded['videos'] is! List || (loaded['videos'] as List).isEmpty) &&
          data['match_videos'] is List) {
        loaded['videos'] = data['match_videos'];
      }
      if ((loaded['videos'] is! List || (loaded['videos'] as List).isEmpty) &&
          data['data'] is Map &&
          (data['data'] as Map)['videos'] is List) {
        loaded['videos'] = (data['data'] as Map)['videos'];
      }

      if (!mounted) return;
      setState(() => _match = loaded);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _videos =>
      ((_match?['videos'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);

  String? _videoUrl(Map<String, dynamic> video) {
    final raw = _s(video['video_url']).isNotEmpty
        ? _s(video['video_url'])
        : _s(video['file_url']).isNotEmpty
            ? _s(video['file_url'])
            : _s(video['url']);
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://sportotekaapp.ru${raw.startsWith('/') ? raw : '/$raw'}';
  }

  Map<String, dynamic>? get _primaryVideo {
    final valid = _videos.where((video) => _videoUrl(video) != null).toList();
    if (valid.isEmpty) return null;

    for (final video in valid) {
      final type = _s(video['video_type'] ?? video['type']).toLowerCase();
      if (type == 'full' ||
          type == 'match' ||
          type == 'recording' ||
          type == 'main') {
        return video;
      }
    }
    return valid.first;
  }

  String get _teamName {
    for (final value in <dynamic>[
      _match?['our_team'],
      _match?['team_name'],
      widget.teamName,
    ]) {
      final text = _s(value);
      if (text.isNotEmpty && !RegExp(r'^#?\d+$').hasMatch(text)) return text;
    }
    return 'Команда';
  }

  String get _opponent {
    final value = _s(_match?['opponent'] ?? _match?['away_team_name']);
    return value.isEmpty ? 'Соперник' : value;
  }

  String get _matchTitle {
    final explicit = _s(_match?['title'] ?? _match?['match_title']);
    if (explicit.isNotEmpty) return explicit;
    final a = _s(_match?['our_score']).isEmpty ? '0' : _s(_match?['our_score']);
    final b = _s(_match?['opponent_score']).isEmpty
        ? '0'
        : _s(_match?['opponent_score']);
    return '$_teamName $a:$b $_opponent';
  }

  String get _score {
    final a = _s(_match?['our_score']).isEmpty ? '0' : _s(_match?['our_score']);
    final b = _s(_match?['opponent_score']).isEmpty
        ? '0'
        : _s(_match?['opponent_score']);
    return '$a : $b';
  }

  Future<void> _pickAndUploadFullVideo() async {
    if (_uploadingVideo) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp4', 'mov', 'm4v', 'avi'],
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      final path = picked.path;
      if (path == null || path.trim().isEmpty) {
        _showMessage('Видео', 'Не удалось получить путь к выбранному файлу.');
        return;
      }

      final file = File(path);
      if (!await file.exists()) {
        _showMessage('Видео', 'Выбранный файл не найден.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _uploadingVideo = true;
        _uploadProgress = 0.0;
        _uploadText = 'Подготовка видео...';
      });

      final upload = await _chunkUploadService.uploadVideoInChunks(
        videoFile: file,
        matchId: widget.matchId,
        teamId: widget.teamId,
        coachId: _coachId,
        notes: 'Полное видео матча',
        onProgress: (progress, text) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = progress.clamp(0.0, 1.0).toDouble();
            _uploadText = text;
          });
        },
      );

      if (!mounted) return;
      final ok = upload['success'] == true;
      if (!ok) {
        _showMessage(
          'Ошибка загрузки',
          _s(upload['message']).isEmpty
              ? 'Не удалось загрузить видео.'
              : _s(upload['message']),
        );
        return;
      }

      _showMessage('Готово', 'Видео прикреплено к матчу.');
      await _load();
      if (!mounted) return;
      setState(() {
        _sceneSection = 'video';
        _inspectorSection = null;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('Видео', 'Ошибка загрузки: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingVideo = false;
          _uploadProgress = 0.0;
          _uploadText = '';
        });
      }
    }
  }

  void _showMessage(String title, String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title: $text')),
    );
  }

  Future<void> _openSection(String section) async {
    switch (section) {
      // Центральная сцена. При переключении сцены инспектор закрывается,
      // чтобы не было ощущения двух разных экранов, наложенных друг на друга.
      case 'video':
        setState(() {
          _sceneSection = 'video';
          _inspectorSection = null;
        });
        _playback.openVideo();
        break;
      case 'map':
        setState(() {
          _sceneSection = 'map';
          _inspectorSection = null;
        });
        _playback.openMap();
        break;
      case 'review':
        setState(() {
          _sceneSection = 'review';
          _inspectorSection = null;
        });
        // Разбор начинается на стоп-кадре видео. Если тренеру нужен разбор
        // 3D-карты — он сначала открывает карту, затем включает чертёж внутри
        // самой сцены. Здесь не делаем скрытый переход на другой экран.
        _playback.openVideo();
        _playback.toggleTacticalReview(forceEnabled: true);
        break;
      case 'report':
        setState(() {
          _sceneSection = 'report';
          _inspectorSection = null;
        });
        _playback.openReport();
        break;

      // Инспекторы данных. Видео остаётся активной центральной сценой.
      case 'journal':
        setState(() {
          _sceneSection = 'video';
          _inspectorSection = 'journal';
        });
        _playback.openEpisodes();
        break;
      case 'players':
        setState(() {
          _sceneSection = 'video';
          _inspectorSection = 'players';
        });
        _playback.openPlayers();
        break;
      case 'ttd':
        // Legacy deeplink/shortcut: manual TTD no longer opens a separate
        // module. It is now the confirmation/correction workspace inside AI.
        setState(() {
          _sceneSection = 'video';
          _inspectorSection = 'ai';
        });
        _playback.openManualConfirmation();
        break;
      case 'ai':
        setState(() {
          _sceneSection = 'video';
          _inspectorSection = 'ai';
        });
        _playback.openAiVideo();
        break;
    }
  }

  bool _isNavActive(_WorkspaceNavItem item) {
    if (item.group == 'scene' || item.group == 'result') {
      return _sceneSection == item.id ||
          (item.id == 'review' && _playback.tacticalReviewEnabled);
    }
    return _inspectorSection == item.id;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: AppTypography.custom(
        size: 12,
        color: _ink,
        weight: FontWeight.w500,
        height: 1.22,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              return Column(
                children: [
                  _buildHeader(compact: compact),
                  Container(height: 1, color: _line),
                  _buildPrimaryNavigation(compact: compact),
                  Container(height: 1, color: _line),
                  Expanded(child: _buildWorkspaceBody()),
                  Container(height: 1, color: _line),
                  _buildTimeline(compact: compact),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool compact}) {
    return SizedBox(
      height: compact ? 56 : 62,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
        child: Row(
          children: [
            _roundIcon(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Назад к матчам',
              onTap: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 10),
            Container(
              width: compact ? 36 : 40,
              height: compact ? 36 : 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _greenSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.slow_motion_video_rounded,
                  color: _green, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _matchTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sectionTitle(color: _ink).copyWith(
                      fontSize: compact ? 14.5 : 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Единый видеоразбор • $_teamName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(color: _muted),
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              _aiHeaderPill(),
              const SizedBox(width: 8),
              _headerPill(Icons.sports_soccer_outlined,
                  '${_playback.aiEventsCount} событий'),
              const SizedBox(width: 8),
              _headerPill(Icons.bar_chart_rounded,
                  '${_playback.aiSuggestionsCount} ТТД'),
              const SizedBox(width: 8),
              _headerPill(Icons.groups_2_outlined,
                  '${_playback.resolvedPlayersCount}/${_playback.playersCount} игроков опознано'),
              const SizedBox(width: 8),
            ],
            _roundIcon(
              icon: _uploadingVideo
                  ? Icons.hourglass_top_rounded
                  : Icons.video_call_outlined,
              tooltip: _primaryVideo == null ? 'Добавить видео' : 'Добавить ещё видео',
              onTap: _uploadingVideo ? () {} : _pickAndUploadFullVideo,
            ),
            const SizedBox(width: 6),
            _roundIcon(
              icon: Icons.refresh_rounded,
              tooltip: 'Обновить матч',
              onTap: _load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiHeaderPill() {
    final active = _playback.aiRunning || _playback.aiLoading;
    final ready = _playback.aiEventsCount > 0 || _playback.aiSuggestionsCount > 0;
    final label = _playback.aiLoading
        ? 'AI ${(_playback.aiProgress * 100).round()}%'
        : active
            ? 'AI работает'
            : ready
                ? 'AI готов'
                : 'AI не запущен';

    return Material(
      color: active || ready ? _greenSoft : _soft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openSection('ai'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 15, color: active || ready ? _green : _muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.secondaryMedium(
                  color: active || ready ? _ink : _muted,
                ).copyWith(fontSize: 10.8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerPill(IconData icon, String label) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _muted),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.secondaryMedium(color: _ink)
                  .copyWith(fontSize: 11.3)),
        ],
      ),
    );
  }

  Widget _roundIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 19, color: _ink),
          ),
        ),
      ),
    );
  }

  // V8.1: exact structure of the approved unified workspace mockup.
  // Manual TTD remains inside AI confirmation; it is not a top-level module.
  List<_WorkspaceNavItem> get _navItems => const [
        _WorkspaceNavItem(
          'video',
          'Видео',
          'основная запись',
          Icons.play_circle_outline_rounded,
          group: 'scene',
        ),
        _WorkspaceNavItem(
          'ai',
          'AI-анализ',
          'трекинг и события',
          Icons.auto_awesome_rounded,
          group: 'data',
        ),
        _WorkspaceNavItem(
          'map',
          '3D карта',
          'позиции и маршруты',
          Icons.view_in_ar_rounded,
          group: 'scene',
        ),
        _WorkspaceNavItem(
          'review',
          'Разбор',
          'чертёж и тактика',
          Icons.draw_rounded,
          group: 'scene',
        ),
        _WorkspaceNavItem(
          'journal',
          'Эпизоды',
          'журнал и таймкоды',
          Icons.video_library_outlined,
          group: 'data',
        ),
        _WorkspaceNavItem(
          'players',
          'Игроки',
          'состав и AI-треки',
          Icons.people_alt_outlined,
          group: 'data',
        ),
        _WorkspaceNavItem(
          'report',
          'Отчёт',
          'итог матча',
          Icons.assignment_outlined,
          group: 'result',
        ),
      ];

  Widget _buildPrimaryNavigation({required bool compact}) {
    return SizedBox(
      height: compact ? 52 : 50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 14,
          vertical: compact ? 6 : 7,
        ),
        child: Row(
          children: [
            for (int index = 0; index < _navItems.length; index++) ...[
              Builder(
                builder: (context) {
                  final item = _navItems[index];
                  final active = _isNavActive(item);
                  return Material(
                    color: active ? _ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      onTap: () => _openSection(item.id),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        height: 36,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10 : 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 16,
                              color: active ? Colors.white : _muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item.title,
                              style: AppTypography.action(
                                color: active ? Colors.white : _muted,
                              ).copyWith(
                                fontSize: compact ? 10.4 : 10.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (index != _navItems.length - 1)
                const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRail() {
    return Container(
      width: 190,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, index) {
                final item = _navItems[index];
                final previousGroup = index == 0 ? '' : _navItems[index - 1].group;
                final showGroup = index == 0 || previousGroup != item.group;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showGroup) ...[
                      if (index != 0) const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 5),
                        child: Text(
                          item.group == 'scene'
                              ? 'СЦЕНА'
                              : item.group == 'data'
                                  ? 'ДАННЫЕ МАТЧА'
                                  : 'РЕЗУЛЬТАТ',
                          style: AppTypography.caption(color: _muted).copyWith(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .65,
                          ),
                        ),
                      ),
                    ],
                    _desktopNavItem(item),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: _line),
          const SizedBox(height: 8),
          _desktopFooterAction(
            icon: Icons.arrow_back_rounded,
            title: 'К матчам',
            subtitle: 'закрыть видеоразбор',
            onTap: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }

  Widget _desktopNavItem(_WorkspaceNavItem item) {
    final active = _isNavActive(item);
    return Material(
      color: active ? _greenSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openSection(item.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: active ? 30 : 0,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              if (active) const SizedBox(width: 7),
              Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : _soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon,
                    size: 17, color: active ? _green : _muted),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.menuTitle(
                        color: active ? _ink : _muted,
                      ).copyWith(fontSize: 11.4),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(color: _muted)
                          .copyWith(fontSize: 9.6),
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

  Widget _desktopFooterAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _soft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _muted),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.menuTitle(color: _ink)
                            .copyWith(fontSize: 10.8)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTypography.caption(color: _muted)
                            .copyWith(fontSize: 9.2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNav() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        scrollDirection: Axis.horizontal,
        itemCount: _navItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (_, index) {
          final item = _navItems[index];
          final active = _isNavActive(item);
          return Material(
            color: active ? _greenSoft : _soft,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _openSection(item.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(minWidth: 68),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(item.icon,
                        size: 17, color: active ? _green : _muted),
                    const SizedBox(width: 6),
                    Text(
                      item.title,
                      style: AppTypography.action(
                        color: active ? _ink : _muted,
                      ).copyWith(fontSize: 10.8),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkspaceBody() {
    if (_loading && _match == null) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _match == null) {
      return _workspaceMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось открыть матч',
        text: _error!,
        action: 'Повторить',
        onTap: _load,
      );
    }

    final video = _primaryVideo;
    final url = video == null ? null : _videoUrl(video);
    if (video == null || url == null) {
      return _buildNoVideoWorkspace();
    }

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          if (_inspectorSection == 'ai') _buildAiVideoStatusStrip(),
          Expanded(
            child: VideoMatchReviewScreen(
              key: ValueKey('new-video-workspace-${widget.matchId}-${_i(video['id'])}'),
              matchId: widget.matchId,
              teamId: widget.teamId,
              teamName: _teamName,
              coachId: _coachId,
              matchTitle: _matchTitle,
              videoUrl: url,
              videoId: _i(video['id']),
              embedded: true,
              forceLandscape: false,
              railOnLeft: false,
              playbackController: _playback,
              showInternalVideoControls: false,
              externalWorkspaceShell: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRerunAi() async {
    if (_playback.aiLoading || _playback.aiRunning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Пересчитать AI-анализ?'),
        content: const Text(
          'Текущий результат останется доступен до завершения нового анализа. '
          'Запускайте пересчёт только после изменения состава, цветов команд или серверного AI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Пересчитать'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _playback.startAiAnalysis();
    }
  }

  Widget _buildAiVideoStatusStrip() {
    final hasResults =
        _playback.aiEventsCount > 0 || _playback.aiSuggestionsCount > 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        return Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding:
              EdgeInsets.fromLTRB(compact ? 8 : 12, 6, compact ? 8 : 12, 6),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _line)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _greenSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: _green),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compact ? 'AI анализ' : 'AI-анализ матча',
                      style: AppTypography.menuTitle(color: _ink)
                          .copyWith(fontSize: 11.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _playback.aiStatusText.isEmpty
                          ? 'События, игроки, TTD и подтверждение в одном рабочем блоке.'
                          : _playback.aiStatusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(color: _muted)
                          .copyWith(fontSize: 9.8),
                    ),
                  ],
                ),
              ),
              if (!compact && hasResults) ...[
                _miniAiCount('События', _playback.aiEventsCount),
                const SizedBox(width: 6),
                _miniAiCount('AI TTD', _playback.aiSuggestionsCount),
                const SizedBox(width: 8),
              ],
              if (_playback.aiLoading || _playback.aiRunning)
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _green,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 7),
                        Text(
                          'AI работает',
                          style: AppTypography.action(color: _ink)
                              .copyWith(fontSize: 10.3),
                        ),
                      ],
                    ],
                  ),
                )
              else if (!hasResults)
                FilledButton.icon(
                  onPressed: _playback.startAiAnalysis,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                  label: Text(
                    compact ? 'AI' : 'Запустить AI',
                    style: AppTypography.action(color: Colors.white)
                        .copyWith(fontSize: 10.5),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 12, vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                )
              else ...[
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 15, color: _green),
                      if (!compact) ...[
                        const SizedBox(width: 6),
                        Text(
                          'AI готов',
                          style: AppTypography.action(color: _ink)
                              .copyWith(fontSize: 10.3),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Действия AI',
                  onSelected: (value) {
                    if (value == 'rerun') _confirmRerunAi();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'rerun',
                      child: Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Пересчитать анализ'),
                        ],
                      ),
                    ),
                  ],
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(Icons.more_horiz_rounded, size: 19),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _miniAiCount(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(9)),
      child: Text(
        '$label $value',
        style: AppTypography.caption(color: _ink).copyWith(fontSize: 9.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildNoVideoWorkspace() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.video_file_outlined, color: _green, size: 30),
                ),
                const SizedBox(height: 14),
                Text(
                  'Добавьте полную запись матча',
                  textAlign: TextAlign.center,
                  style: AppTypography.sectionTitle(color: _ink),
                ),
                const SizedBox(height: 7),
                Text(
                  'После загрузки в этой же рабочей области сразу будут доступны видео, AI-трекинг, AI TTD, ручное подтверждение, 3D-карта, эпизоды и тактический разбор.',
                  textAlign: TextAlign.center,
                  style: AppTypography.secondary(color: _muted),
                ),
                const SizedBox(height: 16),
                if (_uploadingVideo) ...[
                  LinearProgressIndicator(
                    value: _uploadProgress <= 0 ? null : _uploadProgress,
                    minHeight: 7,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _uploadText.isEmpty ? 'Загрузка...' : _uploadText,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption(color: _muted),
                  ),
                  const SizedBox(height: 14),
                ],
                FilledButton.icon(
                  onPressed: _uploadingVideo ? null : _pickAndUploadFullVideo,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(_uploadingVideo ? 'Загрузка...' : 'Выбрать видео'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _workspaceMessage({
    required IconData icon,
    required String title,
    required String text,
    required String action,
    required VoidCallback onTap,
  }) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: _green, size: 28),
                ),
                const SizedBox(height: 14),
                Text(title,
                    textAlign: TextAlign.center,
                    style: AppTypography.sectionTitle(color: _ink)),
                const SizedBox(height: 7),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppTypography.secondary(color: _muted),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(action),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(Duration duration) {
    final total = duration.inSeconds.clamp(0, 24 * 60 * 60);
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildTimeline({required bool compact}) {
    final duration = _playback.duration;
    final position = _playback.position;
    final maxMs = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final currentMs = position.inMilliseconds.clamp(0, maxMs);

    if (!_playback.attached) {
      return SizedBox(height: compact ? 50 : 168);
    }

    if (compact) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
        child: Row(
          children: [
            _timelineButton(
              icon: _playback.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onTap: _playback.togglePlayPause,
              primary: true,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: [
                  _timelineTrack(
                    currentMs: currentMs,
                    maxMs: maxMs,
                    compact: true,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(position),
                          style: AppTypography.caption(color: _muted)),
                      Text(_fmt(duration),
                          style: AppTypography.caption(color: _muted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _timelineTextButton(
                '${_playback.speed.toStringAsFixed(_playback.speed == 1 ? 0 : 2)}×',
                _playback.cycleSpeed),
            const SizedBox(width: 5),
            _timelineButton(
              icon: Icons.add_photo_alternate_outlined,
              onTap: _playback.createEpisodeFromCurrentFrame,
            ),
          ],
        ),
      );
    }

    return Container(
      height: 168,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                _eventFilterChip('all', 'Все события', Icons.view_timeline_outlined),
                const SizedBox(width: 5),
                _eventFilterChip('goal', 'Голы', Icons.sports_soccer_rounded),
                const SizedBox(width: 5),
                _eventFilterChip('pass', 'Передачи', Icons.compare_arrows_rounded),
                const SizedBox(width: 5),
                _eventFilterChip('shot', 'Удары', Icons.track_changes_rounded),
                const SizedBox(width: 5),
                _eventFilterChip('card', 'Карточки', Icons.style_outlined),
                const SizedBox(width: 5),
                _eventFilterChip('ttd', 'ТТД', Icons.query_stats_rounded),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _playback.createEpisodeFromCurrentFrame,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                  label: Text(
                    'Добавить эпизод',
                    style: AppTypography.action(color: _ink).copyWith(fontSize: 10.2),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _line),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 38,
            child: Row(
              children: [
                _timelineButton(
                    icon: Icons.replay_10_rounded,
                    onTap: () => _playback.seekRelative(-10)),
                const SizedBox(width: 4),
                _timelineButton(
                  icon: _playback.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onTap: _playback.togglePlayPause,
                  primary: true,
                ),
                const SizedBox(width: 4),
                _timelineButton(
                    icon: Icons.forward_10_rounded,
                    onTap: () => _playback.seekRelative(10)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 43,
                  child: Text(_fmt(position),
                      textAlign: TextAlign.center,
                      style: AppTypography.secondaryMedium(color: _ink)
                          .copyWith(fontSize: 10)),
                ),
                Expanded(
                  child: _timelineTrack(
                    currentMs: currentMs,
                    maxMs: maxMs,
                    compact: false,
                  ),
                ),
                SizedBox(
                  width: 43,
                  child: Text(_fmt(duration),
                      textAlign: TextAlign.center,
                      style: AppTypography.caption(color: _muted)),
                ),
                const SizedBox(width: 8),
                _timelineTextButton(
                    '${_playback.speed.toStringAsFixed(_playback.speed == 1 ? 0 : 2)}×',
                    _playback.cycleSpeed),
                const SizedBox(width: 4),
                _timelineButton(
                  icon: Icons.fullscreen_rounded,
                  onTap: _playback.toggleFullscreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildEpisodeFilmstrip()),
        ],
      ),
    );
  }

  Widget _eventFilterChip(String id, String title, IconData icon) {
    final active = _timelineFilter == id;
    return Material(
      color: active ? _greenSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => setState(() => _timelineFilter = id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? _green : _muted),
              const SizedBox(width: 5),
              Text(
                title,
                style: AppTypography.action(color: active ? _green : _muted)
                    .copyWith(fontSize: 9.8, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _episodeTitle(Map<String, dynamic> episode) {
    final raw = _s(episode['event_title']).isNotEmpty
        ? _s(episode['event_title'])
        : _s(episode['title']);
    if (raw.isNotEmpty) return raw;
    final sec = _i(episode['timecode_seconds']);
    return 'Эпизод ${_fmt(Duration(seconds: sec))}';
  }

  int _episodeTimeMs(Map<String, dynamic> episode) {
    final raw = episode['timecode_seconds'] ??
        episode['video_time_seconds'] ??
        episode['time_seconds'];
    final seconds = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.0;
    return (seconds * 1000).round();
  }

  String _episodePreviewUrl(Map<String, dynamic> episode) {
    for (final key in const [
      'snapshot_url',
      'screenshot_url',
      'frame_url',
      'thumbnail_url',
      'thumbnail',
      'image_url',
      'image',
      'snapshot_path',
    ]) {
      final raw = _s(episode[key]);
      if (raw.isEmpty || raw.toLowerCase() == 'null') continue;
      if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
      if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
      return 'https://sportotekaapp.ru/$raw';
    }
    return '';
  }

  bool _episodeMatchesFilter(Map<String, dynamic> episode) {
    if (_timelineFilter == 'all') return true;
    final text = '${_episodeTitle(episode)} ${_s(episode['event_type'])}'
        .toLowerCase();
    switch (_timelineFilter) {
      case 'goal':
        return text.contains('гол') || text.contains('goal');
      case 'pass':
        return text.contains('пас') || text.contains('передач') || text.contains('pass');
      case 'shot':
        return text.contains('удар') || text.contains('shot');
      case 'card':
        return text.contains('карточ') || text.contains('card');
      case 'ttd':
        return text.contains('ttd') || text.contains('ттд') ||
            (episode['children'] is List && (episode['children'] as List).isNotEmpty);
      default:
        return true;
    }
  }

  Future<Uint8List?> _generatedTimelineThumb(int timeMs) {
    final video = _primaryVideo;
    if (video == null) return Future<Uint8List?>.value(null);
    final url = _videoUrl(video);
    if (url == null || url.isEmpty) return Future<Uint8List?>.value(null);
    return _timelineThumbCache.putIfAbsent(
      timeMs,
      () => FrameCaptureHelper.captureFrame(
        videoPath: url,
        timeMs: timeMs,
        quality: 55,
      ),
    );
  }

  Widget _timelineEpisodePreview(Map<String, dynamic> episode, String preview, int timeMs) {
    Widget generated() => FutureBuilder<Uint8List?>(
      future: _generatedTimelineThumb(timeMs),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
        }
        return Container(
          color: _soft,
          alignment: Alignment.center,
          child: const Icon(Icons.movie_creation_outlined, size: 17, color: _muted),
        );
      },
    );

    if (preview.isEmpty) return generated();
    return Image.network(
      preview,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => generated(),
    );
  }

  Widget _buildEpisodeFilmstrip() {
    final items = _playback.episodePreviewItems
        .where(_episodeMatchesFilter)
        .take(18)
        .toList(growable: false);

    if (items.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _timelineFilter == 'all'
              ? 'Эпизоды появятся здесь после AI-разбора или ручного добавления.'
              : 'В этой категории пока нет эпизодов.',
          style: AppTypography.caption(color: _muted).copyWith(fontSize: 9.5),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 7),
      itemBuilder: (context, index) {
        final episode = items[index];
        final timeMs = _episodeTimeMs(episode);
        final preview = _episodePreviewUrl(episode);
        final active = (_playback.position.inMilliseconds - timeMs).abs() <= 1500;
        return InkWell(
          onTap: () => _playback.openEpisode(episode),
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: active ? _green : _line,
                        width: active ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _timelineEpisodePreview(episode, preview, timeMs),
                        Positioned(
                          left: 5,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.72),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _fmt(Duration(milliseconds: timeMs)),
                              style: AppTypography.caption(color: Colors.white)
                                  .copyWith(fontSize: 8.4, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _episodeTitle(episode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(color: active ? _green : _ink)
                      .copyWith(fontSize: 9.1, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _timelineTrack({
    required int currentMs,
    required int maxMs,
    required bool compact,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 1.0;
        final episodes = _playback.episodePreviewItems.take(compact ? 24 : 48).toList(growable: false);
        final aiTimes = _playback.aiEventTimesMs.take(60);
        final suggestionTimes = _playback.aiSuggestionTimesMs.take(60);

        double xFor(int timeMs, {double markerWidth = 18}) {
          final f = maxMs <= 0 ? 0.0 : (timeMs / maxMs).clamp(0.0, 1.0).toDouble();
          return (width * f - markerWidth / 2)
              .clamp(0.0, math.max(0.0, width - markerWidth))
              .toDouble();
        }

        ({IconData icon, Color color}) styleFor(Map<String, dynamic> episode) {
          final t = '${_episodeTitle(episode)} ${_s(episode['event_type'])}'.toLowerCase();
          if (t.contains('гол') || t.contains('goal')) {
            return (icon: Icons.sports_soccer_rounded, color: const Color(0xFFDC2626));
          }
          if (t.contains('удар') || t.contains('shot')) {
            return (icon: Icons.track_changes_rounded, color: const Color(0xFF64748B));
          }
          if (t.contains('пас') || t.contains('передач') || t.contains('pass')) {
            return (icon: Icons.compare_arrows_rounded, color: const Color(0xFF7C3AED));
          }
          if (t.contains('карточ') || t.contains('card')) {
            return (icon: Icons.style_rounded, color: const Color(0xFFF59E0B));
          }
          if (t.contains('перехват')) {
            return (icon: Icons.swap_horiz_rounded, color: _green);
          }
          return (icon: Icons.circle, color: _green);
        }

        Widget smallTick(int timeMs, Color color, double bottom) {
          final left = xFor(timeMs, markerWidth: 3);
          return Positioned(
            left: left,
            bottom: bottom,
            child: Container(
              width: 3,
              height: compact ? 6 : 8,
              decoration: BoxDecoration(
                color: color.withOpacity(.75),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          );
        }

        return SizedBox(
          height: compact ? 27 : 42,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 4,
                right: 4,
                top: compact ? 11 : 18,
                child: Container(height: 1, color: _line),
              ),
              if (!compact)
                for (int i = 0; i <= 6; i++)
                  Positioned(
                    left: (math.max(0.0, width - 1) * (i / 6))
                        .clamp(0.0, math.max(0.0, width - 1))
                        .toDouble(),
                    top: 16,
                    child: Column(
                      children: [
                        Container(width: 1, height: 6, color: _line),
                        const SizedBox(height: 10),
                        Text(
                          '${i * 15}′',
                          style: AppTypography.caption(color: _muted)
                              .copyWith(fontSize: 7.8),
                        ),
                      ],
                    ),
                  ),
              for (final time in aiTimes)
                smallTick(time, _green, compact ? 1 : 3),
              for (final time in suggestionTimes)
                smallTick(time, const Color(0xFFF59E0B), compact ? 1 : 3),
              if (!compact)
                for (final episode in episodes)
                  Positioned(
                    left: xFor(_episodeTimeMs(episode), markerWidth: 20),
                    top: 7,
                    child: Builder(
                      builder: (_) {
                        final style = styleFor(episode);
                        return Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: style.color.withOpacity(.35)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.035),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          child: Icon(style.icon, size: 11.5, color: style.color),
                        );
                      },
                    ),
                  ),
              Positioned.fill(
                child: Slider(
                  value: currentMs.toDouble(),
                  min: 0,
                  max: maxMs.toDouble(),
                  onChanged: (value) => _playback.seekToFraction(
                    maxMs == 0 ? 0 : value / maxMs,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _timelineButton({
    required IconData icon,
    required FutureOr<void> Function() onTap,
    bool primary = false,
  }) {
    return Material(
      color: primary ? _green : _soft,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon,
              size: 19, color: primary ? Colors.white : _muted),
        ),
      ),
    );
  }

  Widget _timelineTextButton(String label, FutureOr<void> Function() onTap) {
    return Material(
      color: _soft,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 38,
          constraints: const BoxConstraints(minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(label,
              style: AppTypography.action(color: _ink).copyWith(fontSize: 10.7)),
        ),
      ),
    );
  }
}

class _WorkspaceNavItem {
  const _WorkspaceNavItem(
    this.id,
    this.title,
    this.subtitle,
    this.icon, {
    this.group = 'data',
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String group;
}
