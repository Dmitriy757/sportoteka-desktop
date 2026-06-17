import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/team_video_analysis/models/ttd_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/screens/episode_annotation_editor_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/screens/fullscreen_image_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/api_constants.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/formatters.dart';

class EpisodeTtdDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? episode;
  final Map<String, dynamic>? initialEvent;
  final int? eventId;
  final int? videoId;
  final List<Map<String, dynamic>> players;
  final int matchId;
  final int teamId;
  final int coachId;
  final Future<void> Function()? onEpisodeUpdated;

  const EpisodeTtdDetailScreen({
    super.key,
    this.episode,
    this.initialEvent,
    this.eventId,
    this.videoId,
    required this.players,
    required this.matchId,
    required this.teamId,
    required this.coachId,
    this.onEpisodeUpdated,
  });

  @override
  State<EpisodeTtdDetailScreen> createState() => _EpisodeTtdDetailScreenState();
}

class _EpisodeColors {
  static const bg = Color(0xFFF6F7FB);
  static const bgSoft = Color(0xFFF1F5F9);
  static const panel = Color(0xFFFFFFFF);
  static const panelSoft = Color(0xFFF8FAFC);
  static const panelSoft2 = Color(0xFFEEF2F7);
  static const border = Color(0xFFE2E8F0);

  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const textSoft = Color(0xFF94A3B8);

  static const green = Color(0xFF22C55E);
  static const greenDark = Color(0xFF16A34A);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF7C3AED);
  static const teal = Color(0xFF0F766E);
  static const white = Color(0xFFFFFFFF);

  static const black = Color(0xFF111111);
  static const blackSoft = Color(0xFF1E1E1E);
  static const blackCard = Color(0xFF16181D);
}

class _EpisodeTtdDetailScreenState extends State<EpisodeTtdDetailScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _selectedEpisode;
  Map<String, dynamic>? _selectedEvent;
  List<Map<String, dynamic>> _timeEvents = [];
  Map<String, dynamic>? _selectedPlayer;

  String _ttdSection = 'main';
  bool _quickSaving = false;
  bool _episodeRefreshing = false;

  String? _message;
  bool _isMessageError = false;

  final TextEditingController _noteCtrl = TextEditingController();
  late AnimationController _animationController;

  bool get _isEventMode =>
      widget.initialEvent != null ||
      widget.eventId != null ||
      (widget.episode == null && widget.videoId != null);

  String _s(dynamic v) => (v ?? '').toString().trim();

  int _i(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(_s(v)) ?? 0;
  }

  double _d(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(_s(v)) ?? 0.0;
  }

  bool _b(dynamic v) {
    if (v is bool) return v;
    final sv = _s(v).toLowerCase();
    return sv == '1' || sv == 'true' || sv == 'yes';
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
    return _normalizeMediaUrl(
      _s(p["photo"]).isNotEmpty ? _s(p["photo"]) : _s(p["image"]),
    );
  }

  String _playerPosition(Map<String, dynamic> p) {
    return _s(p["position"]).isNotEmpty ? _s(p["position"]) : 'Без позиции';
  }

  String _baseOrigin() {
    final api = ApiConstants.apiBase;
    final uri = Uri.tryParse(api);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return '';
    return '${uri.scheme}://${uri.host}';
  }

  String _normalizeMediaUrl(dynamic raw) {
    final value = _s(raw);
    if (value.isEmpty) return '';

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final origin = _baseOrigin();
    if (origin.isEmpty) return value;

    if (value.startsWith('/')) {
      return '$origin$value';
    }

    if (value.startsWith('uploads/')) {
      return '$origin/$value';
    }

    if (value.startsWith('api/')) {
      return '$origin/$value';
    }

    return '$origin/$value';
  }

  String _extractSnapshotUrl(Map<String, dynamic> map) {
    final candidates = [
      map['snapshot_url'],
      map['snapshot'],
      map['screenshot_url'],
      map['screen_url'],
      map['image_url'],
      map['image'],
      map['photo'],
      map['frame_url'],
      map['thumbnail'],
      map['snapshot_path'],
    ];

    for (final c in candidates) {
      final normalized = _normalizeMediaUrl(c);
      if (normalized.isNotEmpty) return normalized;
    }

    return '';
  }

  List<Map<String, dynamic>> _childrenList() {
    final raw = (_selectedEpisode['children'] as List?) ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  List<Map<String, dynamic>> _filteredChildrenBySelectedPlayer() {
    final children = _childrenList();
    if (_selectedPlayer == null) return children;

    final selectedId = _i(_selectedPlayer!['id']);
    return children.where((e) => _i(e['player_id']) == selectedId).toList();
  }

  List<TtdMetric> get _allMetrics => <TtdMetric>[
        ...mainTtd,
        ...passTtd,
        ...goalkeeperTtd,
      ];

  String _normalizeMetricCode(dynamic rawCode, {dynamic rawTitle}) {
    final code = _s(rawCode).toLowerCase().replaceAll('ё', 'е').trim();
    final title = _s(rawTitle).toLowerCase().replaceAll('ё', 'е').trim();

    const aliases = <String, String>{
      'финт': 'feint_dribble',
      'обводка': 'feint_dribble',
      'дриблинг': 'feint_dribble',
      'удар': 'shot_on_goal',
      'удары': 'shot_on_goal',
      'отбор': 'tackle_duel',
      'единоборство': 'tackle_duel',
      'перехват': 'interception_ball',
      'перехват мяча': 'interception_ball',
      'подбор': 'recovery_ball',
      'подбор мяча': 'recovery_ball',
      'игра головой': 'header_play',
      'головой': 'header_play',
      'аут': 'throw_ins',
      'ауты': 'throw_ins',
      'пас в авп': 'pass_avp',
      'передача в авп': 'pass_avp',
      'вперед к': 'pass_forward_short',
      'вперёд к': 'pass_forward_short',
      'вперед с': 'pass_forward_medium',
      'вперёд с': 'pass_forward_medium',
      'вперед д': 'pass_forward_long',
      'вперёд д': 'pass_forward_long',
      'поперек к': 'pass_side_short',
      'поперёк к': 'pass_side_short',
      'поперек с': 'pass_side_medium',
      'поперёк с': 'pass_side_medium',
      'поперек д': 'pass_side_long',
      'поперёк д': 'pass_side_long',
      'назад к': 'pass_back_short',
      'назад • к': 'pass_back_short',
      'назад с': 'pass_back_medium',
      'назад • с': 'pass_back_medium',
      'назад д': 'pass_back_long',
      'назад • д': 'pass_back_long',
      'пропущен гол': 'gk_conceded',
      'пропущенные голы': 'gk_conceded',
      'сейв': 'gk_saves',
      'сейвы': 'gk_saves',
      'ввод рукой': 'gk_hand_distribution',
      'ввод мяча рукой': 'gk_hand_distribution',
      'игра на выходах': 'gk_coming_out',
      'выход': 'gk_coming_out',
      'ближний бой': 'gk_close_combat',
      'close_combat': 'gk_close_combat',
      'перехваты': 'gk_interceptions',
      'interceptions': 'gk_interceptions',
      'за пределами штрафной': 'gk_outside_box',
      'вне штрафной': 'gk_outside_box',
      'передачи к': 'gk_pass_short',
      'передачи • к': 'gk_pass_short',
      'передачи с': 'gk_pass_medium',
      'передачи • с': 'gk_pass_medium',
      'передачи д': 'gk_pass_long',
      'передачи • д': 'gk_pass_long',
    };

    if (aliases.containsKey(code)) return aliases[code]!;
    if (aliases.containsKey(title)) return aliases[title]!;

    for (final metric in _allMetrics) {
      final metricCode = metric.code.toLowerCase().replaceAll('ё', 'е').trim();
      final metricTitle = metric.title.toLowerCase().replaceAll('ё', 'е').trim();

      if (code == metricCode || title == metricCode) return metric.code;
      if (code == metricTitle || title == metricTitle) return metric.code;
    }

    for (final metric in _allMetrics) {
      final metricTitle = metric.title.toLowerCase().replaceAll('ё', 'е').trim();

      if (title.isNotEmpty &&
          (metricTitle.contains(title) || title.contains(metricTitle))) {
        return metric.code;
      }

      if (code.isNotEmpty &&
          (metricTitle.contains(code) || code.contains(metricTitle))) {
        return metric.code;
      }
    }

    return code.isNotEmpty ? code : title;
  }

  bool _isSingleMetricCode(String code) {
    for (final metric in _allMetrics) {
      if (metric.code == code) {
        return metric.singleOnly;
      }
    }
    return false;
  }

  Map<String, Map<String, int>> _buildEpisodeStats() {
    final actions = _filteredChildrenBySelectedPlayer();
    final Map<String, Map<String, int>> stats = {};

    for (final action in actions) {
      final rawType = action['event_type'];
      final rawTitle = action['event_title'];

      final code = _normalizeMetricCode(rawType, rawTitle: rawTitle);
      if (code.isEmpty) continue;

      final isPositive = _b(action['is_positive']);
      final rating = _i(action['rating']);

      stats.putIfAbsent(
        code,
        () => {
          'success': 0,
          'fail': 0,
          'single': 0,
        },
      );

      if (_isSingleMetricCode(code)) {
        final delta = rating != 0 ? rating.abs() : 1;
        stats[code]!['single'] = (stats[code]!['single'] ?? 0) + delta;
      } else {
        if (isPositive) {
          stats[code]!['success'] = (stats[code]!['success'] ?? 0) + 1;
        } else {
          stats[code]!['fail'] = (stats[code]!['fail'] ?? 0) + 1;
        }
      }
    }

    return stats;
  }

  int _episodeSuccessTotal() {
    final stats = _buildEpisodeStats();
    return stats.values.fold<int>(0, (sum, e) => sum + (e['success'] ?? 0));
  }

  int _episodeFailTotal() {
    final stats = _buildEpisodeStats();
    return stats.values.fold<int>(0, (sum, e) => sum + (e['fail'] ?? 0));
  }

  int _episodeSingleTotal() {
    final stats = _buildEpisodeStats();
    return stats.values.fold<int>(0, (sum, e) => sum + (e['single'] ?? 0));
  }

  int _episodeActionsTotal() {
    return _filteredChildrenBySelectedPlayer().length;
  }

  int _episodeFilledMetricsCount() {
    final stats = _buildEpisodeStats();
    return stats.values.where((e) {
      return (e['success'] ?? 0) > 0 ||
          (e['fail'] ?? 0) > 0 ||
          (e['single'] ?? 0) > 0;
    }).length;
  }

  String _successPercent(int success, int fail) {
    final total = success + fail;
    if (total <= 0) return '0%';
    final percent = ((success / total) * 100).round();
    return '$percent%';
  }

  String _metricSectionByCode(String code) {
    if (passTtd.any((m) => m.code == code)) return 'passes';
    if (goalkeeperTtd.any((m) => m.code == code)) return 'gk';
    return 'main';
  }

  String _sectionTitle(String section) {
    switch (section) {
      case 'passes':
        return 'Передачи';
      case 'gk':
        return 'Вратарские';
      case 'main':
      default:
        return 'Основные';
    }
  }

  List<String> _orderedFilledMetricCodes() {
    final stats = _buildEpisodeStats();

    final filledCodes = stats.entries
        .where((e) {
          final item = e.value;
          return (item['success'] ?? 0) > 0 ||
              (item['fail'] ?? 0) > 0 ||
              (item['single'] ?? 0) > 0;
        })
        .map((e) => e.key)
        .toList();

    int sectionOrder(String section) {
      switch (section) {
        case 'main':
          return 0;
        case 'passes':
          return 1;
        case 'gk':
          return 2;
        default:
          return 99;
      }
    }

    int metricOrderInSection(String code) {
      final all = [
        ...mainTtd,
        ...passTtd,
        ...goalkeeperTtd,
      ];

      final index = all.indexWhere((m) => m.code == code);
      return index == -1 ? 999 : index;
    }

    filledCodes.sort((a, b) {
      final sectionA = _metricSectionByCode(a);
      final sectionB = _metricSectionByCode(b);

      final sectionCompare =
          sectionOrder(sectionA).compareTo(sectionOrder(sectionB));
      if (sectionCompare != 0) return sectionCompare;

      return metricOrderInSection(a).compareTo(metricOrderInSection(b));
    });

    return filledCodes;
  }

  String _getPlayerNameFromAction(Map<String, dynamic> action) {
    if (action['player_id'] != null) {
      final playerId = _i(action['player_id']);
      final foundPlayer = widget.players.firstWhere(
        (p) => _i(p['id']) == playerId,
        orElse: () => <String, dynamic>{},
      );

      if (foundPlayer.isNotEmpty) {
        final fullName = _playerFullName(foundPlayer);
        if (fullName.isNotEmpty) return fullName;
      }
    }

    if (action['player'] != null && action['player'] is Map<String, dynamic>) {
      final playerData = action['player'] as Map<String, dynamic>;

      if (_s(playerData['full_name']).isNotEmpty) {
        return _s(playerData['full_name']);
      }

      final firstName = _s(playerData['first_name']).isNotEmpty
          ? _s(playerData['first_name'])
          : _s(playerData['name']);
      final lastName = _s(playerData['last_name']).isNotEmpty
          ? _s(playerData['last_name'])
          : _s(playerData['surname']);

      final fullName = "$lastName $firstName".trim();
      if (fullName.isNotEmpty && fullName != " ") {
        return fullName;
      }

      if (playerData['jersey_number'] != null) {
        return "Игрок #${playerData['jersey_number']}";
      }

      if (playerData['id'] != null) {
        return "Игрок ${playerData['id']}";
      }
    }

    if (_s(action['player_name']).isNotEmpty) {
      return _s(action['player_name']);
    }

    return 'Неизвестный игрок';
  }

  String _metricTitleByCode(String code) {
    for (final metric in _allMetrics) {
      if (metric.code == code) return metric.title;
    }
    return TtdHelpers.getEventTypeTitle(code);
  }

  void _openFullscreenImage(String imageUrl) {
    final normalized = _normalizeMediaUrl(imageUrl);
    if (normalized.isEmpty) {
      _showMessage('Скрин не найден', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenImageScreen(imageUrl: normalized),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();

    _selectedEpisode = widget.episode != null
        ? Map<String, dynamic>.from(widget.episode!)
        : <String, dynamic>{};

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isEventMode) {
        _fetchEventBasedDetail();
      } else {
        _fetchEpisodeDetail(silent: true);
      }
    });
  }

  @override
  void didUpdateWidget(EpisodeTtdDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldEpisodeId = _i(oldWidget.episode?['id']);
    final newEpisodeId = _i(widget.episode?['id']);
    final oldEventId =
        oldWidget.eventId ?? _i(oldWidget.initialEvent?['id']);
    final newEventId = widget.eventId ?? _i(widget.initialEvent?['id']);

    if (oldEpisodeId != newEpisodeId || oldEventId != newEventId) {
      setState(() {
        _selectedEpisode = widget.episode != null
            ? Map<String, dynamic>.from(widget.episode!)
            : <String, dynamic>{};
        _selectedEvent = widget.initialEvent != null
            ? Map<String, dynamic>.from(widget.initialEvent!)
            : null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isEventMode) {
          _fetchEventBasedDetail();
        } else {
          _fetchEpisodeDetail(silent: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadTtdEventById(int id) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.apiBase}/get_ttd_event_detail.php?id=$id'),
      headers: const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    );

    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (data['success'] == true && data['event'] is Map) {
      return Map<String, dynamic>.from(data['event'] as Map);
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _loadNearEvents({
    required int videoId,
    required double timeSeconds,
    int window = 8,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConstants.apiBase}/get_ttd_events_near_time.php'
        '?video_id=$videoId&time=$timeSeconds&window=$window',
      ),
      headers: const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    );

    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (data['success'] == true && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return [];
  }

  Map<String, dynamic> _mapTtdEventToLegacyAction(Map<String, dynamic> e) {
    final result = _s(e['result']).toLowerCase();
    final isPositive = result == 'success';
    final rating = _i(e['rating']);

    return {
      'id': e['id'],
      'match_id': e['match_id'] ?? widget.matchId,
      'team_id': e['team_id'] ?? widget.teamId,
      'player_id': e['player_id'],
      'coach_id': e['created_by'] ?? widget.coachId,
      'parent_event_id': e['episode_id'] ?? 0,
      'event_type': _s(e['ttd_code']).isNotEmpty ? e['ttd_code'] : e['event_type'],
      'event_title': _s(e['ttd_title']).isNotEmpty ? e['ttd_title'] : e['event_title'],
      'note': e['note'] ?? '',
      'timecode_seconds': _d(e['video_time_seconds']),
      'rating': rating,
      'is_positive': isPositive ? 1 : 0,
      'snapshot_url': e['snapshot_path'] ?? e['snapshot_url'],
      'player_name': e['player_name'],
      'player': {
        'id': e['player_id'],
        'first_name': e['first_name'],
        'last_name': e['last_name'],
        'name': e['name'],
        'surname': e['surname'],
        'photo': e['photo'],
        'image': e['image'],
        'position': e['position'],
        'full_name': e['player_name'],
        'jersey_number': e['jersey_number'],
      },
      'created_at': e['created_at'],
    };
  }

  Map<String, dynamic> _buildPseudoEpisodeFromEvent(
    Map<String, dynamic> event,
    List<Map<String, dynamic>> items,
  ) {
    final pseudoChildren = items.map(_mapTtdEventToLegacyAction).toList();

    return {
      'id': event['id'],
      'event_title': _s(event['ttd_title']).isNotEmpty
          ? event['ttd_title']
          : (_s(event['event_title']).isNotEmpty
              ? event['event_title']
              : 'Событие ТТД'),
      'note': event['note'] ?? '',
      'timecode_seconds': _d(event['video_time_seconds']),
      'snapshot_url': event['snapshot_path'] ?? event['snapshot_url'],
      'children': pseudoChildren,
    };
  }

  Future<void> _fetchEventBasedDetail() async {
    if (mounted) {
      setState(() => _episodeRefreshing = true);
    }

    try {
      Map<String, dynamic>? event = widget.initialEvent != null
          ? Map<String, dynamic>.from(widget.initialEvent!)
          : null;

      final fallbackEventId = widget.eventId ?? _i(event?['id']);

      if ((event == null || event.isEmpty) && fallbackEventId > 0) {
        event = await _loadTtdEventById(fallbackEventId);
      }

      if (event == null || event.isEmpty) {
        _showMessage('Не удалось загрузить событие', isError: true);
        return;
      }

      _selectedEvent = event;

      final eventPlayerId = _i(event['player_id']);
      if (eventPlayerId > 0) {
        final matched = widget.players.where((p) => _i(p['id']) == eventPlayerId);
        if (matched.isNotEmpty) {
          _selectedPlayer = matched.first;
        }
      }

      final videoId = _i(event['video_id']) > 0
          ? _i(event['video_id'])
          : (widget.videoId ?? 0);

      final time = _d(event['video_time_seconds']);
      final items = videoId > 0
          ? await _loadNearEvents(videoId: videoId, timeSeconds: time)
          : <Map<String, dynamic>>[];

      _timeEvents = items;

      final pseudoEpisode = _buildPseudoEpisodeFromEvent(
        event,
        items.isNotEmpty ? items : [event],
      );

      if (!mounted) return;

      final eventNote = _s(event['note']);

      setState(() {
        _selectedEpisode = pseudoEpisode;
        if (_noteCtrl.text.trim().isEmpty && eventNote.isNotEmpty) {
          _noteCtrl.text = eventNote;
        }
      });

      if (widget.onEpisodeUpdated != null) {
        await widget.onEpisodeUpdated!();
      }
    } catch (e) {
      _showMessage('Ошибка загрузки события: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _episodeRefreshing = false);
      }
    }
  }

  Future<void> _fetchEpisodeDetail({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _episodeRefreshing = true);
    }

    try {
      final oldEpisode = Map<String, dynamic>.from(_selectedEpisode);
      final oldEpisodeSnapshot = _extractSnapshotUrl(oldEpisode);

      final oldChildrenById = <int, Map<String, dynamic>>{};
      final oldChildren = (oldEpisode['children'] as List?) ?? [];
      for (final item in oldChildren) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          oldChildrenById[_i(map['id'])] = map;
        }
      }

      final uri = Uri.parse(
        '${ApiConstants.apiBase}/get_episode_detail.php'
        '?episode_id=${_i(_selectedEpisode["id"])}'
        '&_ts=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http.get(
        uri,
        headers: const {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data['success'] == true && data['episode'] is Map<String, dynamic>) {
        if (!mounted) return;

        final episode = Map<String, dynamic>.from(data['episode']);
        final rawChildren = episode['children'] as List? ?? [];

        final children = rawChildren.map((e) {
          final child = Map<String, dynamic>.from(e as Map);

          final actionId = _i(child['id']);
          final oldChild = oldChildrenById[actionId];
          final newSnap = _extractSnapshotUrl(child);
          final oldSnap = oldChild != null ? _extractSnapshotUrl(oldChild) : '';

          if (newSnap.isEmpty && oldSnap.isNotEmpty) {
            child['snapshot_url'] = oldSnap;
          }

          return child;
        }).toList();

        episode['children'] = children;

        final newEpisodeSnap = _extractSnapshotUrl(episode);
        if (newEpisodeSnap.isEmpty && oldEpisodeSnapshot.isNotEmpty) {
          episode['snapshot_url'] = oldEpisodeSnapshot;
        }

        setState(() {
          _selectedEpisode = episode;
        });

        if (widget.onEpisodeUpdated != null) {
          await widget.onEpisodeUpdated!();
        }
      } else {
        _showMessage(
          _s(data['message']).isNotEmpty
              ? _s(data['message'])
              : 'Не удалось обновить эпизод',
          isError: true,
        );
      }
    } catch (e) {
      _showMessage('Ошибка загрузки эпизода: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _episodeRefreshing = false);
      }
    }
  }

  Future<void> _refreshEpisodeLocally() async {
    if (_isEventMode) {
      await _fetchEventBasedDetail();
    } else {
      await _fetchEpisodeDetail();
    }
  }

  void _appendActionLocally({
    required String metricCode,
    required String metricTitle,
    required bool isPositive,
    int rating = 0,
  }) {
    if (_selectedPlayer == null) return;

    final currentChildren = _childrenList();
    final playerMap = Map<String, dynamic>.from(_selectedPlayer!);
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    final newAction = <String, dynamic>{
      'id': tempId,
      'match_id': widget.matchId,
      'team_id': widget.teamId,
      'player_id': _i(playerMap['id']),
      'coach_id': widget.coachId,
      'parent_event_id': _i(_selectedEpisode['id']),
      'event_type': metricCode,
      'event_title': metricTitle,
      'note': _noteCtrl.text.trim(),
      'timecode_seconds': _d(_selectedEpisode['timecode_seconds']),
      'rating': rating,
      'is_positive': isPositive ? 1 : 0,
      'snapshot_url': null,
      'created_at': DateTime.now().toIso8601String(),
      'player': {
        'id': _i(playerMap['id']),
        'first_name': _playerFirstName(playerMap),
        'last_name': _playerLastName(playerMap),
        'name': _s(playerMap['name']),
        'surname': _s(playerMap['surname']),
        'photo': _playerPhoto(playerMap),
        'image': _s(playerMap['image']),
        'position': _playerPosition(playerMap),
        'full_name': _playerFullName(playerMap),
        'jersey_number': playerMap['jersey_number'],
      },
      'player_name': _playerFullName(playerMap),
    };

    currentChildren.insert(0, newAction);

    setState(() {
      _selectedEpisode = {
        ..._selectedEpisode,
        'children': currentChildren,
      };
    });
  }

  void _updateActionLocally({
    required int actionId,
    required String note,
    required bool isPositive,
  }) {
    final currentChildren = _childrenList();

    for (int i = 0; i < currentChildren.length; i++) {
      if (_i(currentChildren[i]['id']) == actionId) {
        currentChildren[i] = {
          ...currentChildren[i],
          'note': note,
          'is_positive': isPositive ? 1 : 0,
        };
        break;
      }
    }

    setState(() {
      _selectedEpisode = {
        ..._selectedEpisode,
        'children': currentChildren,
      };
    });
  }

  void _removeActionLocally(int actionId) {
    final currentChildren =
        _childrenList().where((e) => _i(e['id']) != actionId).toList();

    setState(() {
      _selectedEpisode = {
        ..._selectedEpisode,
        'children': currentChildren,
      };
    });
  }

  Map<String, Map<String, dynamic>> _groupActionsByType(List<dynamic> actions) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (var action in actions) {
      if (action is! Map<String, dynamic>) continue;

      final actionMap = Map<String, dynamic>.from(action);
      final type = _normalizeMetricCode(
        actionMap['event_type'],
        rawTitle: actionMap['event_title'],
      );
      final isPositive = _b(actionMap['is_positive']);
      final title = _s(actionMap['event_title']).isNotEmpty
          ? _s(actionMap['event_title'])
          : _metricTitleByCode(type);

      final key = '${type}_${isPositive ? 1 : 0}';

      if (!grouped.containsKey(key)) {
        grouped[key] = {
          'key': key,
          'type': type,
          'title': title,
          'isPositive': isPositive,
          'actions': <Map<String, dynamic>>[],
          'count': 0,
        };
      }

      final group = grouped[key]!;
      (group['actions'] as List<Map<String, dynamic>>).add(actionMap);
      group['count'] = (group['count'] as int) + 1;
    }

    return grouped;
  }

  Future<void> _editTtdAction(Map<String, dynamic> action) async {
    final TextEditingController commentCtrl =
        TextEditingController(text: action['note']?.toString() ?? '');

    bool isPositive = _b(action['is_positive']);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: _EpisodeColors.panel,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _EpisodeColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Редактировать действие',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _EpisodeColors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: _EpisodeColors.text),
                      decoration: InputDecoration(
                        labelText: 'Комментарий',
                        labelStyle:
                            const TextStyle(color: _EpisodeColors.textMuted),
                        filled: true,
                        fillColor: _EpisodeColors.bgSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: _EpisodeColors.bgSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SwitchListTile(
                        value: isPositive,
                        onChanged: (v) => setLocalState(() => isPositive = v),
                        title: const Text(
                          'Успешное действие',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _EpisodeColors.text,
                          ),
                        ),
                        activeColor: _EpisodeColors.green,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Отмена',
                              style: TextStyle(color: _EpisodeColors.textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _updateTtdAction(
                                actionId: _i(action['id']),
                                note: commentCtrl.text.trim(),
                                isPositive: isPositive,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _EpisodeColors.green,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Сохранить'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateTtdAction({
    required int actionId,
    required String note,
    required bool isPositive,
  }) async {
    setState(() => _quickSaving = true);

    try {
      late final Uri uri;
      late final Map<String, String> bodyMap;

      if (_isEventMode) {
        uri = Uri.parse('${ApiConstants.apiBase}/update_ttd_event.php');
        bodyMap = {
          'id': actionId.toString(),
          'ttd_code': '',
          'ttd_title': '',
          'result': isPositive ? 'success' : 'fail',
          'video_time_seconds': _d(_selectedEpisode['timecode_seconds']).toString(),
          'minute': Duration(
            milliseconds:
                (_d(_selectedEpisode['timecode_seconds']) * 1000).round(),
          ).inMinutes.toString(),
          'second': (Duration(
                    milliseconds:
                        (_d(_selectedEpisode['timecode_seconds']) * 1000).round(),
                  ).inSeconds %
                  60)
              .toString(),
          'note': note,
          'coach_comment': '',
          'episode_id': '0',
          'snapshot_path': '',
          'drawing_path': '',
        };

        final action = _childrenList().firstWhere(
          (e) => _i(e['id']) == actionId,
          orElse: () => <String, dynamic>{},
        );

        if (action.isNotEmpty) {
          bodyMap['ttd_code'] = _s(action['event_type']);
          bodyMap['ttd_title'] = _s(action['event_title']);
          bodyMap['video_time_seconds'] = _d(action['timecode_seconds']).toString();
          final d = Duration(
            milliseconds: (_d(action['timecode_seconds']) * 1000).round(),
          );
          bodyMap['minute'] = d.inMinutes.toString();
          bodyMap['second'] = (d.inSeconds % 60).toString();
          bodyMap['snapshot_path'] = _extractSnapshotUrl(action);
        }
      } else {
        uri = Uri.parse(ApiConstants.updateEventUrl);
        bodyMap = {
          'event_id': actionId.toString(),
          'note': note,
          'is_positive': isPositive ? '1' : '0',
        };
      }

      final response = await http.post(uri, body: bodyMap);

      final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data['success'] == true) {
        _updateActionLocally(
          actionId: actionId,
          note: note,
          isPositive: isPositive,
        );

        _showMessage('Действие обновлено');

        if (_isEventMode) {
          await _fetchEventBasedDetail();
        } else {
          await _fetchEpisodeDetail(silent: true);
        }
      } else {
        _showMessage(
          _s(data['message']).isNotEmpty
              ? _s(data['message'])
              : 'Ошибка обновления',
          isError: true,
        );
      }
    } catch (_) {
      _showMessage('Сетевая ошибка', isError: true);
    } finally {
      if (mounted) {
        setState(() => _quickSaving = false);
      }
    }
  }

  Future<void> _deleteTtdAction(int actionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: _EpisodeColors.panel,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _EpisodeColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Удалить действие?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _EpisodeColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Это действие будет удалено безвозвратно',
                style: TextStyle(color: _EpisodeColors.textMuted),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(color: _EpisodeColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _EpisodeColors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Удалить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _quickSaving = true);

    try {
      late final Uri uri;
      late final Map<String, String> bodyMap;

      if (_isEventMode) {
        uri = Uri.parse('${ApiConstants.apiBase}/delete_ttd_event.php');
        bodyMap = {'id': actionId.toString()};
      } else {
        uri = Uri.parse(ApiConstants.deleteEventUrl);
        bodyMap = {'event_id': actionId.toString()};
      }

      final response = await http.post(uri, body: bodyMap);

      final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data['success'] == true) {
        _removeActionLocally(actionId);

        _showMessage('Действие удалено');

        if (_isEventMode) {
          await _fetchEventBasedDetail();
        } else {
          await _fetchEpisodeDetail(silent: true);
        }
      } else {
        _showMessage(
          _s(data['message']).isNotEmpty
              ? _s(data['message'])
              : 'Ошибка удаления',
          isError: true,
        );
      }
    } catch (_) {
      _showMessage('Сетевая ошибка', isError: true);
    } finally {
      if (mounted) {
        setState(() => _quickSaving = false);
      }
    }
  }

  Future<void> _saveQuickTtd({
    required String metricCode,
    required String metricTitle,
    required bool isSuccess,
  }) async {
    if (_selectedPlayer == null) {
      _showMessage("Сначала выбери игрока", isError: true);
      return;
    }

    setState(() => _quickSaving = true);

    try {
      if (_isEventMode) {
        final currentEvent = _selectedEvent;
        final currentVideoId = _i(currentEvent?['video_id']) > 0
            ? _i(currentEvent?['video_id'])
            : (widget.videoId ?? 0);

        final currentTime = _d(currentEvent?['video_time_seconds']) > 0
            ? _d(currentEvent?['video_time_seconds'])
            : _d(_selectedEpisode['timecode_seconds']);

        final duration = Duration(
          milliseconds: (currentTime * 1000).round(),
        );

        final req = http.MultipartRequest(
          "POST",
          Uri.parse('${ApiConstants.apiBase}/add_ttd_event.php'),
        );

        req.fields["video_id"] = currentVideoId.toString();
        req.fields["match_id"] = widget.matchId.toString();
        req.fields["team_id"] = widget.teamId.toString();
        req.fields["player_id"] = _s(_selectedPlayer!["id"]);
        req.fields["ttd_code"] = metricCode;
        req.fields["ttd_title"] = metricTitle;
        req.fields["result"] = isSuccess ? "success" : "fail";
        req.fields["video_time_seconds"] = currentTime.toStringAsFixed(3);
        req.fields["minute"] = duration.inMinutes.toString();
        req.fields["second"] = (duration.inSeconds % 60).toString();
        req.fields["note"] = _noteCtrl.text.trim();
        req.fields["coach_comment"] = "";
        req.fields["episode_id"] = "0";
        req.fields["snapshot_path"] = "";
        req.fields["drawing_path"] = "";
        req.fields["created_by"] = widget.coachId.toString();

        final streamed = await req.send().timeout(const Duration(seconds: 60));
        final resp = await http.Response.fromStream(streamed);

        final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
        final data = jsonDecode(body) as Map<String, dynamic>;

        if (data["success"] == true) {
          _appendActionLocally(
            metricCode: metricCode,
            metricTitle: metricTitle,
            isPositive: isSuccess,
          );

          _showMessage("$metricTitle • ${isSuccess ? "✅" : "❌"}");
          HapticFeedback.lightImpact();

          await _fetchEventBasedDetail();
        } else {
          _showMessage(
            _s(data["message"]).isNotEmpty
                ? _s(data["message"])
                : "Не удалось сохранить",
            isError: true,
          );
        }
      } else {
        final totalSeconds = _i(_selectedEpisode["timecode_seconds"]);

        final req = http.MultipartRequest(
          "POST",
          Uri.parse(ApiConstants.addEventUrl),
        );
        req.fields["match_id"] = widget.matchId.toString();
        req.fields["team_id"] = widget.teamId.toString();
        req.fields["player_id"] = _s(_selectedPlayer!["id"]);
        req.fields["coach_id"] = widget.coachId.toString();
        req.fields["parent_event_id"] = _i(_selectedEpisode["id"]).toString();
        req.fields["event_type"] = metricCode;
        req.fields["event_title"] = metricTitle;
        req.fields["note"] = _noteCtrl.text.trim();
        req.fields["timecode_seconds"] = totalSeconds.toString();
        req.fields["is_positive"] = isSuccess ? "1" : "0";

        final streamed = await req.send().timeout(const Duration(seconds: 60));
        final resp = await http.Response.fromStream(streamed);

        final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
        final data = jsonDecode(body) as Map<String, dynamic>;

        if (data["success"] == true) {
          _appendActionLocally(
            metricCode: metricCode,
            metricTitle: metricTitle,
            isPositive: isSuccess,
          );

          _showMessage("$metricTitle • ${isSuccess ? "✅" : "❌"}");
          HapticFeedback.lightImpact();

          await _fetchEpisodeDetail(silent: true);
        } else {
          _showMessage(
            _s(data["message"]).isNotEmpty
                ? _s(data["message"])
                : "Не удалось сохранить",
            isError: true,
          );
        }
      }
    } catch (_) {
      _showMessage("Сбой при сохранении", isError: true);
    } finally {
      if (mounted) {
        setState(() => _quickSaving = false);
      }
    }
  }

  Future<void> _saveSingleTtd({
    required String metricCode,
    required String metricTitle,
    required int value,
  }) async {
    if (_selectedPlayer == null) {
      _showMessage("Сначала выбери игрока", isError: true);
      return;
    }

    setState(() => _quickSaving = true);

    try {
      if (_isEventMode) {
        final currentEvent = _selectedEvent;
        final currentVideoId = _i(currentEvent?['video_id']) > 0
            ? _i(currentEvent?['video_id'])
            : (widget.videoId ?? 0);

        final currentTime = _d(currentEvent?['video_time_seconds']) > 0
            ? _d(currentEvent?['video_time_seconds'])
            : _d(_selectedEpisode['timecode_seconds']);

        final duration = Duration(
          milliseconds: (currentTime * 1000).round(),
        );

        final req = http.MultipartRequest(
          "POST",
          Uri.parse('${ApiConstants.apiBase}/add_ttd_event.php'),
        );

        req.fields["video_id"] = currentVideoId.toString();
        req.fields["match_id"] = widget.matchId.toString();
        req.fields["team_id"] = widget.teamId.toString();
        req.fields["player_id"] = _s(_selectedPlayer!["id"]);
        req.fields["ttd_code"] = metricCode;
        req.fields["ttd_title"] = metricTitle;
        req.fields["result"] = value >= 0 ? "success" : "fail";
        req.fields["video_time_seconds"] = currentTime.toStringAsFixed(3);
        req.fields["minute"] = duration.inMinutes.toString();
        req.fields["second"] = (duration.inSeconds % 60).toString();
        req.fields["note"] = _noteCtrl.text.trim();
        req.fields["coach_comment"] = "";
        req.fields["episode_id"] = "0";
        req.fields["snapshot_path"] = "";
        req.fields["drawing_path"] = "";
        req.fields["created_by"] = widget.coachId.toString();

        final streamed = await req.send().timeout(const Duration(seconds: 60));
        final resp = await http.Response.fromStream(streamed);

        final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
        final data = jsonDecode(body) as Map<String, dynamic>;

        if (data["success"] == true) {
          _appendActionLocally(
            metricCode: metricCode,
            metricTitle: metricTitle,
            isPositive: value >= 0,
            rating: value,
          );

          _showMessage("$metricTitle • ${value >= 0 ? '+' : ''}$value");
          HapticFeedback.lightImpact();

          await _fetchEventBasedDetail();
        } else {
          _showMessage(
            _s(data["message"]).isNotEmpty
                ? _s(data["message"])
                : "Не удалось сохранить",
            isError: true,
          );
        }
      } else {
        final totalSeconds = _i(_selectedEpisode["timecode_seconds"]);

        final req = http.MultipartRequest(
          "POST",
          Uri.parse(ApiConstants.addEventUrl),
        );
        req.fields["match_id"] = widget.matchId.toString();
        req.fields["team_id"] = widget.teamId.toString();
        req.fields["player_id"] = _s(_selectedPlayer!["id"]);
        req.fields["coach_id"] = widget.coachId.toString();
        req.fields["parent_event_id"] = _i(_selectedEpisode["id"]).toString();
        req.fields["event_type"] = metricCode;
        req.fields["event_title"] = metricTitle;
        req.fields["note"] = _noteCtrl.text.trim();
        req.fields["timecode_seconds"] = totalSeconds.toString();
        req.fields["rating"] = value.toString();
        req.fields["is_positive"] = value >= 0 ? "1" : "0";

        final streamed = await req.send().timeout(const Duration(seconds: 60));
        final resp = await http.Response.fromStream(streamed);

        final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
        final data = jsonDecode(body) as Map<String, dynamic>;

        if (data["success"] == true) {
          _appendActionLocally(
            metricCode: metricCode,
            metricTitle: metricTitle,
            isPositive: value >= 0,
            rating: value,
          );

          _showMessage("$metricTitle • ${value >= 0 ? '+' : ''}$value");
          HapticFeedback.lightImpact();

          await _fetchEpisodeDetail(silent: true);
        } else {
          _showMessage(
            _s(data["message"]).isNotEmpty
                ? _s(data["message"])
                : "Не удалось сохранить",
            isError: true,
          );
        }
      }
    } catch (_) {
      _showMessage("Сбой при сохранении", isError: true);
    } finally {
      if (mounted) {
        setState(() => _quickSaving = false);
      }
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    setState(() {
      _message = text;
      _isMessageError = isError;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _message == text) {
        setState(() => _message = null);
      }
    });
  }

  Widget _buildVeoTopBar(String title) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: _EpisodeColors.panel,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: _EpisodeColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        _buildVeoCircleButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _EpisodeColors.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Match analytics • episode review • TTD details',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _EpisodeColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (_selectedPlayer != null)
          Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _EpisodeColors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _EpisodeColors.black.withOpacity(0.10),
              ),
            ),
            child: Text(
              _playerFullName(_selectedPlayer!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _EpisodeColors.black,
              ),
            ),
          ),
        const SizedBox(width: 10),
        if (_episodeRefreshing)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _EpisodeColors.panelSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _EpisodeColors.border),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                strokeWidth: 2.1,
                color: _EpisodeColors.black,
              ),
            ),
          )
        else
          _buildVeoCircleButton(
            icon: Icons.refresh_rounded,
            onTap: _refreshEpisodeLocally,
            accent: true,
          ),
      ],
    ),
  );
}


 Widget _buildVeoCircleButton({
  required IconData icon,
  required VoidCallback onTap,
  bool accent = false,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accent ? _EpisodeColors.black : _EpisodeColors.panelSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent ? _EpisodeColors.black : _EpisodeColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: accent ? Colors.white : _EpisodeColors.text,
        ),
      ),
    ),
  );
}

  Widget _buildModernPanel({
  required String title,
  required Widget child,
  Widget? trailing,
  Color? accentColor,
}) {
  final color = accentColor ?? _EpisodeColors.black;

  IconData icon;
  if (title == 'ТТД') {
    icon = Icons.sports_soccer_rounded;
  } else if (title == 'Игроки') {
    icon = Icons.groups_rounded;
  } else {
    icon = Icons.ondemand_video_rounded;
  }

  return Container(
    decoration: BoxDecoration(
      color: _EpisodeColors.panel,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: _EpisodeColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _EpisodeColors.text,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
        Container(height: 1, color: _EpisodeColors.border),
        Expanded(child: child),
      ],
    ),
  );
}

  Widget _buildModernSectionTab({
  required IconData icon,
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _EpisodeColors.black : _EpisodeColors.panelSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _EpisodeColors.black : _EpisodeColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : _EpisodeColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : _EpisodeColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
  Widget _buildGradientActionButton({
  required String label,
  required Color color,
  required VoidCallback? onTap,
  bool isSingle = false,
}) {
  return StatefulBuilder(
    builder: (context, setInnerState) {
      bool isPressed = false;

      return GestureDetector(
        onTapDown: (_) => setInnerState(() => isPressed = true),
        onTapUp: (_) {
          setInnerState(() => isPressed = false);
          if (onTap != null) onTap();
        },
        onTapCancel: () => setInnerState(() => isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: isSingle ? 42 : 46,
          decoration: BoxDecoration(
            color: isPressed ? color.withOpacity(0.82) : color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isPressed ? 0.16 : 0.24),
                blurRadius: isPressed ? 4 : 10,
                offset: Offset(0, isPressed ? 1 : 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color == _EpisodeColors.amber ? Colors.black : Colors.white,
                fontSize: isSingle ? 16 : 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    },
  );
}
Widget _buildTtdCard(TtdMetric metric) {
  return FadeTransition(
    opacity: _animationController,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          splashColor: metric.color.withOpacity(0.04),
          highlightColor: metric.color.withOpacity(0.02),
          onTap: () {},
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _EpisodeColors.panelSoft,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: metric.color.withOpacity(0.18),
                width: 1.1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: metric.color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        metric.singleOnly
                            ? Icons.score_outlined
                            : Icons.sports_soccer_rounded,
                        size: 15,
                        color: metric.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        metric.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _EpisodeColors.text,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (metric.singleOnly)
                  _buildGradientActionButton(
                    label: "+1",
                    color: _EpisodeColors.amber,
                    onTap: _quickSaving
                        ? null
                        : () => _saveSingleTtd(
                              metricCode: metric.code,
                              metricTitle: metric.title,
                              value: 1,
                            ),
                    isSingle: true,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildGradientActionButton(
                          label: "+",
                          color: _EpisodeColors.green,
                          onTap: _quickSaving
                              ? null
                              : () => _saveQuickTtd(
                                    metricCode: metric.code,
                                    metricTitle: metric.title,
                                    isSuccess: true,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGradientActionButton(
                          label: "−",
                          color: _EpisodeColors.red,
                          onTap: _quickSaving
                              ? null
                              : () => _saveQuickTtd(
                                    metricCode: metric.code,
                                    metricTitle: metric.title,
                                    isSuccess: false,
                                  ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
  Widget _buildModernStatChip({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _EpisodeColors.panelSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _EpisodeColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTtdColumn() {
    List<TtdMetric> visibleItems;
    if (_ttdSection == 'passes') {
      visibleItems = passTtd;
    } else if (_ttdSection == 'gk') {
      visibleItems = goalkeeperTtd;
    } else {
      visibleItems = mainTtd;
    }

    return _buildModernPanel(
      title: 'ТТД',
      trailing: _quickSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _EpisodeColors.green,
              ),
            )
          : null,
      accentColor: _EpisodeColors.green,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModernSectionTab(
                  icon: Icons.grid_view_rounded,
                  label: "Основные",
                  selected: _ttdSection == 'main',
                  onTap: () => setState(() => _ttdSection = 'main'),
                ),
                _buildModernSectionTab(
                  icon: Icons.compare_arrows_rounded,
                  label: "Передачи",
                  selected: _ttdSection == 'passes',
                  onTap: () => setState(() => _ttdSection = 'passes'),
                ),
                _buildModernSectionTab(
                  icon: Icons.sports_handball,
                  label: "Вратарские",
                  selected: _ttdSection == 'gk',
                  onTap: () => setState(() => _ttdSection = 'gk'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: visibleItems.length,
                itemBuilder: (context, index) {
                  final metric = visibleItems[index];
                  return _buildTtdCard(metric);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildPlayersColumn() {
  return _buildModernPanel(
    title: 'Игроки',
    trailing: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${widget.players.length}',
        style: const TextStyle(
          color: _EpisodeColors.black,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    accentColor: _EpisodeColors.black,
    child: ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.players.length,
      itemBuilder: (context, index) {
        final player = widget.players[index];
        final isSelected = _selectedPlayer != null &&
            _s(_selectedPlayer!["id"]) == _s(player["id"]);

        final fullName = _playerFullName(player);
        final firstName = _playerFirstName(player);
        final lastName = _playerLastName(player);
        final photo = _playerPhoto(player);
        final position = _playerPosition(player);

        final fallbackLetter = (lastName.isNotEmpty
                ? lastName[0]
                : firstName.isNotEmpty
                    ? firstName[0]
                    : "?")
            .toUpperCase();

        return FadeTransition(
          opacity: _animationController,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    final tappedId = _s(player["id"]);
                    final currentId =
                        _selectedPlayer != null ? _s(_selectedPlayer!["id"]) : '';

                    if (currentId == tappedId) {
                      _selectedPlayer = null;
                    } else {
                      _selectedPlayer = player;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.black.withOpacity(0.06)
                        : _EpisodeColors.panelSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? _EpisodeColors.black
                          : _EpisodeColors.border,
                      width: isSelected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.black.withOpacity(0.06),
                        backgroundImage:
                            photo.isNotEmpty ? NetworkImage(photo) : null,
                        child: photo.isEmpty
                            ? Text(
                                fallbackLetter,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _EpisodeColors.black,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName.isNotEmpty ? fullName : 'Без имени',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? _EpisodeColors.black
                                    : _EpisodeColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              position,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _EpisodeColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? _EpisodeColors.black
                            : const Color(0xFFCBD5E1),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
  Widget _buildEpisodeColumn() {
    final timeSec = _d(_selectedEpisode["timecode_seconds"]).round();
    final children = _filteredChildrenBySelectedPlayer();
    final snapshotUrl = _extractSnapshotUrl(_selectedEpisode);
    final title = _selectedEpisode['event_title']?.toString() ?? 'Момент';
    final episodeNote = _selectedEpisode['note']?.toString() ?? '';

    final success = _episodeSuccessTotal();
    final fail = _episodeFailTotal();
    final single = _episodeSingleTotal();
    final totalActions = _episodeActionsTotal();
    final efficiency = _successPercent(success, fail);
    final filled = _episodeFilledMetricsCount();

    final grouped = _groupActionsByType(children);

    return _buildModernPanel(
      title: _isEventMode ? 'Момент' : 'Эпизод',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _EpisodeColors.green.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _EpisodeColors.green.withOpacity(0.20),
          ),
        ),
        child: Text(
          _isEventMode
              ? 'EV-${_i(_selectedEpisode["id"])}'
              : 'EP-${_i(_selectedEpisode["id"])}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _EpisodeColors.green,
          ),
        ),
      ),
      accentColor: _EpisodeColors.green,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (snapshotUrl.isNotEmpty)
              FadeTransition(
                opacity: _animationController,
                child: Container(
                  height: 185,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: _EpisodeColors.panelSoft,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () => _openFullscreenImage(snapshotUrl),
                        child: Hero(
                          tag: 'episode_snapshot_${_selectedEpisode['id']}',
                          child: Image.network(
                            snapshotUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: _EpisodeColors.panelSoft,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 40,
                                  color: _EpisodeColors.textSoft,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.40),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Row(
                          children: [
                            _buildGlassIconButton(
                              icon: Icons.zoom_out_map,
                              onTap: () => _openFullscreenImage(snapshotUrl),
                            ),
                            const SizedBox(width: 8),
                            _buildGlassIconButton(
                              icon: Icons.draw_rounded,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EpisodeAnnotationEditorScreen(
                                      episodeId: _i(_selectedEpisode["id"]),
                                      coachId: widget.coachId,
                                      imageUrl: snapshotUrl,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (snapshotUrl.isNotEmpty) const SizedBox(height: 16),

            _buildModernInfoTile(
              label: _isEventMode ? 'Название момента' : 'Название эпизода',
              value: title,
              icon: Icons.movie_creation_outlined,
            ),
            const SizedBox(height: 10),
            _buildModernInfoTile(
              label: 'Время',
              value: Formatters.formatDuration(Duration(seconds: timeSec)),
              icon: Icons.access_time_rounded,
            ),
            if (_selectedPlayer != null) ...[
              const SizedBox(height: 10),
              _buildModernInfoTile(
                label: 'Выбранный игрок',
                value: _playerFullName(_selectedPlayer!),
                icon: Icons.person_outline_rounded,
              ),
            ],
            if (episodeNote.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildModernInfoTile(
                label: _isEventMode ? 'Заметка к моменту' : 'Заметка к эпизоду',
                value: episodeNote,
                icon: Icons.notes_rounded,
              ),
            ],

            const SizedBox(height: 20),

            const Text(
              'Статистика эпизода',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _EpisodeColors.text,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildModernStatChip(
                  title: 'Всего',
                  value: '$totalActions',
                  color: _EpisodeColors.white,
                  icon: Icons.analytics_outlined,
                ),
                const SizedBox(width: 8),
                _buildModernStatChip(
                  title: 'Успешно',
                  value: '$success',
                  color: _EpisodeColors.green,
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(width: 8),
                _buildModernStatChip(
                  title: 'Неудачно',
                  value: '$fail',
                  color: _EpisodeColors.red,
                  icon: Icons.error_outline,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildModernStatChip(
                  title: 'Счёт',
                  value: '$single',
                  color: _EpisodeColors.amber,
                  icon: Icons.pin_outlined,
                ),
                const SizedBox(width: 8),
                _buildModernStatChip(
                  title: 'Эффективность',
                  value: efficiency,
                  color: _EpisodeColors.green,
                  icon: Icons.pie_chart_outline,
                ),
                const SizedBox(width: 8),
                _buildModernStatChip(
                  title: 'Метрик',
                  value: '$filled',
                  color: _EpisodeColors.violet,
                  icon: Icons.table_rows_rounded,
                ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              _selectedPlayer == null
                  ? 'Полная статистика по моменту'
                  : 'Статистика по ${_playerFullName(_selectedPlayer!)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _EpisodeColors.text,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildModernStatsList(),

            const SizedBox(height: 20),

            const Text(
              'Комментарий тренера',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _EpisodeColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _EpisodeColors.bgSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _EpisodeColors.border),
              ),
              child: TextField(
                controller: _noteCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 13, color: _EpisodeColors.text),
                decoration: const InputDecoration(
                  hintText: 'Добавьте комментарий к действиям...',
                  hintStyle: TextStyle(color: _EpisodeColors.textSoft),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),

            if (_message != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isMessageError
                      ? _EpisodeColors.red.withOpacity(0.10)
                      : _EpisodeColors.green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isMessageError
                        ? _EpisodeColors.red.withOpacity(0.25)
                        : _EpisodeColors.green.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isMessageError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: _isMessageError
                          ? _EpisodeColors.red
                          : _EpisodeColors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _isMessageError
                              ? _EpisodeColors.red
                              : _EpisodeColors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            Row(
              children: [
                Text(
                  _isEventMode
                      ? 'Действия рядом по времени'
                      : 'Действия в эпизоде',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _EpisodeColors.text,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _EpisodeColors.panelSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _EpisodeColors.border),
                  ),
                  child: Text(
                    '${children.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _EpisodeColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (grouped.isNotEmpty)
              ...grouped.values.map(_buildModernGroupedAction)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _EpisodeColors.panelSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _EpisodeColors.border),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.sports_soccer_rounded,
                      size: 48,
                      color: _EpisodeColors.textSoft,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Пока нет действий для выбранного игрока.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _EpisodeColors.textSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Нажмите + или − в блоке ТТД, чтобы добавить действие.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _EpisodeColors.textSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInfoTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _EpisodeColors.panelSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _EpisodeColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _EpisodeColors.green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _EpisodeColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _EpisodeColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _EpisodeColors.text,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatRow(String code) {
    final stats = _buildEpisodeStats();
    final normalizedCode = _normalizeMetricCode(code);
    final item = stats[normalizedCode] ??
        const {
          'success': 0,
          'fail': 0,
          'single': 0,
        };

    final success = item['success'] ?? 0;
    final fail = item['fail'] ?? 0;
    final single = item['single'] ?? 0;
    final hasValue = success > 0 || fail > 0 || single > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hasValue ? _EpisodeColors.panelSoft : _EpisodeColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasValue ? _EpisodeColors.border : _EpisodeColors.bgSoft,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _metricTitleByCode(normalizedCode),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasValue ? FontWeight.w800 : FontWeight.w600,
                color: hasValue
                    ? _EpisodeColors.text
                    : _EpisodeColors.textMuted,
              ),
            ),
          ),
          if (!_isSingleMetricCode(normalizedCode)) ...[
            _buildModernMiniBadge(
              title: 'Уд',
              value: '$success',
              color: _EpisodeColors.green,
            ),
            const SizedBox(width: 6),
            _buildModernMiniBadge(
              title: 'Неуд',
              value: '$fail',
              color: _EpisodeColors.red,
            ),
            const SizedBox(width: 6),
            _buildModernMiniBadge(
              title: '%',
              value: _successPercent(success, fail),
              color: _EpisodeColors.blue,
            ),
          ] else ...[
            _buildModernMiniBadge(
              title: 'Счёт',
              value: '$single',
              color: _EpisodeColors.amber,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernMiniBadge({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildModernStatsList() {
    final filledCodes = _orderedFilledMetricCodes();

    final widgets = <Widget>[];

    if (filledCodes.isEmpty) {
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _EpisodeColors.panelSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _EpisodeColors.border),
          ),
          child: const Text(
            'По выбранному игроку пока нет статистики.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _EpisodeColors.textMuted,
            ),
          ),
        ),
      );
      return widgets;
    }

    String? previousSection;

    for (final code in filledCodes) {
      final section = _metricSectionByCode(code);

      if (previousSection != section) {
        if (previousSection != null) {
          widgets.add(const SizedBox(height: 8));
        }

        widgets.add(
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _EpisodeColors.green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _sectionTitle(section),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _EpisodeColors.green,
              ),
            ),
          ),
        );

        previousSection = section;
      }

      widgets.add(_buildModernStatRow(code));
    }

    return widgets;
  }

  Widget _buildModernGroupedAction(Map<String, dynamic> group) {
    final isPositiveGroup = group['isPositive'] as bool;
    final actions = (group['actions'] as List<Map<String, dynamic>>)
        .where((action) {
          if (_selectedPlayer == null) return true;
          return _i(action['player_id']) == _i(_selectedPlayer!['id']);
        })
        .toList();

    if (actions.isEmpty) return const SizedBox.shrink();

    final count = actions.length;

    final Map<String, Map<String, dynamic>> playerStats = {};

    for (var action in actions) {
      final playerName = _getPlayerNameFromAction(action);
      final isActionPositive = _b(action['is_positive']);

      if (!playerStats.containsKey(playerName)) {
        playerStats[playerName] = {
          'name': playerName,
          'positive': 0,
          'negative': 0,
          'total': 0,
          'actions': <Map<String, dynamic>>[],
        };
      }

      final stat = playerStats[playerName]!;
      if (isActionPositive) {
        stat['positive'] = (stat['positive'] as int) + 1;
      } else {
        stat['negative'] = (stat['negative'] as int) + 1;
      }
      stat['total'] = (stat['total'] as int) + 1;
      (stat['actions'] as List<Map<String, dynamic>>).add(action);
    }

    final sortedPlayers = playerStats.values.toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    final Color accent =
        isPositiveGroup ? _EpisodeColors.green : _EpisodeColors.red;

    final Color groupBg = isPositiveGroup
        ? _EpisodeColors.green.withOpacity(0.05)
        : _EpisodeColors.red.withOpacity(0.05);

    final Color groupBorder = isPositiveGroup
        ? _EpisodeColors.green.withOpacity(0.18)
        : _EpisodeColors.red.withOpacity(0.18);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: groupBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: groupBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPositiveGroup ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group['title']?.toString() ?? 'Действие',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _EpisodeColors.text,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _EpisodeColors.panelSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _EpisodeColors.border),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...sortedPlayers.map((stat) {
            final playerName = stat['name'] as String;
            final positive = stat['positive'] as int;
            final negative = stat['negative'] as int;
            final playerActions = stat['actions'] as List<Map<String, dynamic>>;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _EpisodeColors.panelSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _EpisodeColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          playerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _EpisodeColors.text,
                          ),
                        ),
                      ),
                      if (positive > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _EpisodeColors.green.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+$positive',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _EpisodeColors.green,
                            ),
                          ),
                        ),
                      if (negative > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _EpisodeColors.red.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '-$negative',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _EpisodeColors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...playerActions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final action = entry.value;
                    final isActionPositive = _b(action['is_positive']);
                    final note = _s(action['note']);
                    final normalizedType = _normalizeMetricCode(
                      action['event_type'],
                      rawTitle: action['event_title'],
                    );
                    final actionTitle = _s(action['event_title']).isNotEmpty
                        ? _s(action['event_title'])
                        : _metricTitleByCode(normalizedType);

                    final snapshotUrl = _extractSnapshotUrl(action);

                    return Container(
                      margin: EdgeInsets.only(
                        bottom: index == playerActions.length - 1 ? 0 : 8,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isActionPositive
                            ? _EpisodeColors.green.withOpacity(0.08)
                            : _EpisodeColors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActionPositive
                              ? _EpisodeColors.green.withOpacity(0.20)
                              : _EpisodeColors.red.withOpacity(0.20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isActionPositive ? Icons.check_circle : Icons.error,
                                size: 16,
                                color: isActionPositive
                                    ? _EpisodeColors.green
                                    : _EpisodeColors.red,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      actionTitle,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _EpisodeColors.text,
                                      ),
                                    ),
                                    if (note.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        note,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: _EpisodeColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCompactIconButton(
                                    icon: Icons.edit,
                                    color: _EpisodeColors.green,
                                    onTap: () => _editTtdAction(action),
                                    tooltip: 'Редактировать',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCompactIconButton(
                                    icon: Icons.delete_outline,
                                    color: _EpisodeColors.red,
                                    onTap: () => _deleteTtdAction(_i(action['id'])),
                                    tooltip: 'Удалить',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (snapshotUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _openFullscreenImage(snapshotUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  children: [
                                    Image.network(
                                      snapshotUrl,
                                      height: 100,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 100,
                                        color: _EpisodeColors.bgSoft,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 30,
                                            color: _EpisodeColors.textSoft,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.zoom_out_map,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.42),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEventMode
        ? "Детальный разбор ТТД"
        : "Детальный разбор эпизода";

    return Scaffold(
      backgroundColor: _EpisodeColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _buildVeoTopBar(title),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildTtdColumn()),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _buildPlayersColumn()),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: _buildEpisodeColumn()),
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