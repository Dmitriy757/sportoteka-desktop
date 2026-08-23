// lib/presentation/match_live/match_live_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/advanced_video_analysis/advanced_video_analysis_screen.dart';
import 'package:sportoteka/presentation/advanced_video_analysis/models/analysis_result.dart';
import 'package:sportoteka/presentation/advanced_video_analysis/services/websocket_service.dart';
import 'package:sportoteka/presentation/advanced_video_analysis/widgets/analysis_overlay_widget.dart';

class MatchLiveScreen extends StatefulWidget {
  final int teamId;
  final int? clubId;
  final int? matchId;
  final int? fieldId;
  final int? coachId;
  final String teamName;
  final String matchTitle;
  final String videoUrl;
  final Map<String, dynamic> teamColors;
  final Map<String, dynamic> fieldConfig;
  final List<Map<String, dynamic>> players;
  final List<int> sessionIds;
  final String? initialMode;

  const MatchLiveScreen({
    super.key,
    required this.teamId,
    this.clubId,
    this.matchId,
    this.fieldId,
    this.coachId,
    required this.teamName,
    this.matchTitle = '',
    this.videoUrl = '',
    this.teamColors = const {},
    this.fieldConfig = const {},
    this.players = const [],
    this.sessionIds = const [],
    this.initialMode,
  });

  static Future<void> open(
    BuildContext context, {
    required Map<String, dynamic> params,
    String? initialMode,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchLiveScreen(
          teamId: _int(params['teamId'] ?? params['team_id']),
          clubId: _nullableInt(params['clubId'] ?? params['club_id']),
          matchId: _nullableInt(params['matchId'] ?? params['match_id']),
          fieldId: _nullableInt(params['fieldId'] ?? params['field_id']),
          coachId: _nullableInt(params['coachId'] ?? params['coach_id']),
          teamName: (params['teamName'] ?? params['team_name'] ?? 'Команда').toString(),
          matchTitle: (params['matchTitle'] ?? params['match_title'] ?? '').toString(),
          videoUrl: (params['videoUrl'] ?? params['video_url'] ?? '').toString(),
          teamColors: _map(params['teamColors'] ?? params['team_colors']),
          fieldConfig: _map(params['fieldConfig'] ?? params['field_config']),
          players: _mapList(params['players']),
          sessionIds: _intList(params['sessionIds'] ?? params['session_ids']),
          initialMode: initialMode,
        ),
      ),
    );
  }

  @override
  State<MatchLiveScreen> createState() => _MatchLiveScreenState();

  static int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
  static int? _nullableInt(dynamic value) {
    final parsed = _int(value);
    return parsed > 0 ? parsed : null;
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static List<Map<String, dynamic>> _mapList(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
  static List<int> _intList(dynamic value) => value is List
      ? value.map(_int).where((id) => id > 0).toSet().toList()
      : <int>[];
}

class _MatchLiveScreenState extends State<MatchLiveScreen> {
  static const green = Color(0xFF00A750);
  static const ink = Color(0xFF17221C);
  static const muted = Color(0xFF6B766F);
  static const line = Color(0xFFE1E8E3);
  static const canvas = Color(0xFFF4F7F5);

  final WebSocketService _service = WebSocketService();
  StreamSubscription<AnalysisResult>? _analysisSub;
  StreamSubscription<Map<String, dynamic>>? _packetSub;
  StreamSubscription<String>? _statusSub;
  AnalysisResult? _frame;
  List<Map<String, dynamic>> _cameras = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _advice = [];
  Map<String, dynamic> _telemetry = {};
  Map<String, dynamic>? _report;
  Map<String, dynamic>? _dataset;
  final Map<int, int> _playerBindings = {};
  String _status = 'Выберите режим';
  String _matchLiveId = '';
  String? _cameraId;
  bool _liveMode = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _analysisSub = _service.analysisStream.listen(_onFrame);
    _packetSub = _service.packetStream.listen(_onPacket);
    _statusSub = _service.statusStream.listen((value) {
      if (mounted) setState(() => _status = value);
    });
    if (widget.initialMode == 'live') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _chooseLive());
    } else if (widget.initialMode == 'recording') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _chooseRecording());
    }
  }

  @override
  void dispose() {
    _service.stop(matchLiveId: _matchLiveId);
    _analysisSub?.cancel();
    _packetSub?.cancel();
    _statusSub?.cancel();
    _service.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _params => {
        'sourceMode': _liveMode ? 'live' : 'recording',
        'matchId': widget.matchId,
        'clubId': widget.clubId,
        'teamId': widget.teamId,
        'fieldId': widget.fieldId,
        'teamName': widget.teamName,
        'matchTitle': widget.matchTitle,
        'videoUrl': widget.videoUrl,
        'cameraId': _cameraId,
        'teamColors': widget.teamColors,
        'fieldConfig': widget.fieldConfig,
        'players': widget.players,
        'sessionIds': widget.sessionIds,
      };

  Future<void> _chooseRecording() async {
    if (widget.videoUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала загрузите запись матча')),
      );
      return;
    }
    await AdvancedVideoAnalysisScreen.show(context, params: {
      ..._params,
      'sourceMode': 'recording',
    });
  }

  Future<void> _chooseLive() async {
    setState(() {
      _liveMode = true;
      _starting = true;
      _status = 'Получаю доступные камеры…';
    });
    await _service.connectControl();
    if (mounted) setState(() => _starting = false);
  }

  void _onPacket(Map<String, dynamic> packet) {
    if (!mounted) return;
    final type = (packet['type'] ?? '').toString();
    setState(() {
      if (type == 'camera_list') {
        _cameras = MatchLiveScreen._mapList(packet['cameras']);
        if (_cameras.length == 1) _cameraId = (_cameras.first['id'] ?? '').toString();
      } else if (type == 'match_started') {
        _matchLiveId = (packet['match_live_id'] ?? '').toString();
      } else if (type == 'event_reviewed') {
        final reviewed = MatchLiveScreen._map(packet['event']);
        final id = (reviewed['id'] ?? '').toString();
        final index = _events.indexWhere((e) => (e['id'] ?? '').toString() == id);
        if (index >= 0) _events[index] = reviewed;
      } else if (type == 'match_report') {
        _report = MatchLiveScreen._map(packet['report']);
      } else if (type == 'training_dataset') {
        _dataset = MatchLiveScreen._map(packet['dataset']);
      }
    });
  }

  void _onFrame(AnalysisResult result) {
    if (!mounted) return;
    final combinedEvents = <Map<String, dynamic>>[
      ...result.events,
      ...result.recentEvents,
    ];
    final combinedAdvice = <Map<String, dynamic>>[
      ...result.advice,
      ...result.recentAdvice,
    ];
    setState(() {
      _frame = result;
      if (result.matchLiveId.isNotEmpty) _matchLiveId = result.matchLiveId;
      _telemetry = result.telemetry;
      _mergeById(_events, combinedEvents, max: 80);
      _mergeById(_advice, combinedAdvice, max: 30);
    });
  }

  static void _mergeById(
    List<Map<String, dynamic>> target,
    List<Map<String, dynamic>> incoming, {
    required int max,
  }) {
    for (final item in incoming) {
      final id = (item['id'] ?? '${item['event_type']}_${item['time_ms']}').toString();
      target.removeWhere((old) =>
          (old['id'] ?? '${old['event_type']}_${old['time_ms']}').toString() == id);
      target.insert(0, item);
    }
    if (target.length > max) target.removeRange(max, target.length);
  }

  Future<void> _startCamera() async {
    final cameraId = _cameraId;
    if (cameraId == null || cameraId.isEmpty) return;
    setState(() {
      _starting = true;
      _frame = null;
      _events.clear();
      _advice.clear();
      _report = null;
    });
    await _service.connectRequest({
      'action': 'start_live_match',
      ..._snakeParams(_params),
      'camera_id': cameraId,
      'record': true,
    });
    if (mounted) setState(() => _starting = false);
  }

  Map<String, dynamic> _snakeParams(Map<String, dynamic> params) => {
        'source_mode': params['sourceMode'],
        'match_id': params['matchId'],
        'club_id': params['clubId'],
        'team_id': params['teamId'],
        'field_id': params['fieldId'],
        'team_name': params['teamName'],
        'match_title': params['matchTitle'],
        'team_colors': params['teamColors'],
        'field_config': params['fieldConfig'],
        'players': params['players'],
        'session_ids': params['sessionIds'],
      }..removeWhere((_, value) => value == null);

  Uint8List? get _previewBytes {
    final raw = _frame?.frameJpegBase64 ?? '';
    if (raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SPORTOTEKA MATCH AI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          Text(widget.matchTitle.isEmpty ? widget.teamName : widget.matchTitle,
              style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          if (_matchLiveId.isNotEmpty)
            TextButton.icon(
              onPressed: () => _service.requestReport(_matchLiveId),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Отчёт'),
            ),
          if (_matchLiveId.isNotEmpty)
            TextButton.icon(
              onPressed: () => _service.requestTrainingDataset(matchLiveId: _matchLiveId),
              icon: const Icon(Icons.model_training_outlined, size: 18),
              label: Text(_dataset == null ? 'Датасет' : 'Датасет ${_dataset!['count'] ?? 0}'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: !_liveMode ? _modePicker() : _liveWorkspace(),
    );
  }

  Widget _modePicker() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Как анализируем матч?',
                style: TextStyle(color: ink, fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Видео, GPS-трекеры и Polar объединяются в одной временной шкале.',
                textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 14)),
            const SizedBox(height: 28),
            LayoutBuilder(builder: (context, c) {
              final cards = [
                _modeCard(
                  icon: Icons.videocam_rounded,
                  title: 'Матч онлайн',
                  subtitle: 'IP/RTSP-камера, запись эфира, события и подсказки тренеру в реальном времени.',
                  action: 'Выбрать камеру',
                  onTap: _chooseLive,
                ),
                _modeCard(
                  icon: Icons.video_library_rounded,
                  title: 'Анализ записи',
                  subtitle: 'Загруженное видео, синхронизация с GPS/Polar и итоговый отчёт по матчу.',
                  action: widget.videoUrl.isEmpty ? 'Нет записи' : 'Открыть запись',
                  onTap: widget.videoUrl.isEmpty ? null : _chooseRecording,
                ),
              ];
              return c.maxWidth > 720
                  ? Row(children: [Expanded(child: cards[0]), const SizedBox(width: 18), Expanded(child: cards[1])])
                  : Column(children: [cards[0], const SizedBox(height: 16), cards[1]]);
            }),
          ]),
        ),
      ),
    );
  }

  Widget _modeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 250),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: green.withOpacity(.11), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: green, size: 34)),
            const SizedBox(height: 22),
            Text(title, style: const TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(subtitle, style: const TextStyle(color: muted, height: 1.45)),
            const Spacer(),
            Row(children: [Text(action, style: TextStyle(color: onTap == null ? muted : green, fontWeight: FontWeight.w900)), const SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, color: onTap == null ? muted : green, size: 19)]),
          ]),
        ),
      ),
    );
  }

  Widget _liveWorkspace() {
    return LayoutBuilder(builder: (context, c) {
      final video = _videoPanel();
      final side = _sidePanel();
      return Padding(
        padding: const EdgeInsets.all(14),
        child: c.maxWidth >= 1000
            ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 7, child: video), const SizedBox(width: 14), Expanded(flex: 3, child: side)])
            : ListView(children: [SizedBox(height: 520, child: video), const SizedBox(height: 14), SizedBox(height: 620, child: side)]),
      );
    });
  }

  Widget _videoPanel() {
    final bytes = _previewBytes;
    final frame = _frame;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _cameraId,
                decoration: const InputDecoration(labelText: 'Камера стадиона', border: OutlineInputBorder(), isDense: true),
                items: _cameras.map((camera) {
                  final id = (camera['id'] ?? '').toString();
                  return DropdownMenuItem(value: id, child: Text((camera['name'] ?? id).toString()));
                }).toList(),
                onChanged: (value) => setState(() => _cameraId = value),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: green),
              onPressed: _starting || (_cameraId ?? '').isEmpty ? null : _startCamera,
              icon: const Icon(Icons.fiber_manual_record, size: 17),
              label: const Text('Старт'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _matchLiveId.isEmpty ? null : () => _service.stop(matchLiveId: _matchLiveId), child: const Text('Стоп')),
          ]),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF111814),
            child: bytes == null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.videocam_outlined, color: Colors.white38, size: 54), const SizedBox(height: 12), Text(_cameras.isEmpty ? _status : 'Выберите камеру и нажмите «Старт»', style: const TextStyle(color: Colors.white70))]))
                : Stack(fit: StackFit.expand, children: [
                    Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
                    if (frame != null)
                      AnalysisOverlayWidget(players: frame.players, stats: frame.stats, videoSize: Size.zero, ball: frame.ball),
                    Positioned(left: 12, top: 12, child: _liveBadge(frame)),
                  ]),
          ),
        ),
        if (frame != null && frame.players.isNotEmpty) _bindingStrip(frame),
        _statsStrip(),
      ]),
    );
  }

  Widget _bindingStrip(AnalysisResult frame) {
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: frame.players.map((detected) {
          final trackId = detected.trackId;
          final playerId = _playerBindings[trackId];
          final roster = widget.players.cast<Map<String, dynamic>?>().firstWhere(
                (item) => MatchLiveScreen._int(item?['id'] ?? item?['player_id']) == playerId,
                orElse: () => null,
              );
          final name = roster == null
              ? 'Трек $trackId → игрок'
              : (roster['name'] ?? roster['player_name'] ?? 'Игрок $playerId').toString();
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ActionChip(
              avatar: Icon(roster == null ? Icons.link_rounded : Icons.check_rounded, size: 16, color: roster == null ? muted : green),
              label: Text(name, style: TextStyle(color: roster == null ? ink : green, fontWeight: FontWeight.w800, fontSize: 10.5)),
              onPressed: widget.players.isEmpty || trackId <= 0 || _matchLiveId.isEmpty
                  ? null
                  : () => _bindTrack(trackId),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _bindTrack(int trackId) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Связать видеотрек с GPS/Polar', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('После привязки скорость, спринты, нагрузка и ЧСС берутся с датчиков игрока.'),
            ),
            ...widget.players.map((player) {
              final id = MatchLiveScreen._int(player['id'] ?? player['player_id']);
              final name = (player['name'] ?? player['player_name'] ?? 'Игрок $id').toString();
              return ListTile(
                leading: CircleAvatar(backgroundColor: green.withOpacity(.1), foregroundColor: green, child: Text((player['number'] ?? '').toString())),
                title: Text(name),
                subtitle: Text((player['position'] ?? '').toString()),
                onTap: id <= 0 ? null : () => Navigator.pop(context, player),
              );
            }),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final playerId = MatchLiveScreen._int(selected['id'] ?? selected['player_id']);
    if (playerId <= 0) return;
    final name = (selected['name'] ?? selected['player_name'] ?? 'Игрок $playerId').toString();
    setState(() => _playerBindings[trackId] = playerId);
    _service.bindPlayer(
      matchLiveId: _matchLiveId,
      trackId: trackId,
      playerId: playerId,
      playerName: name,
    );
  }

  Widget _liveBadge(AnalysisResult? frame) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: Colors.black.withOpacity(.68), borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('LIVE · ${frame?.players.length ?? 0} игроков · ${frame?.ball == null ? 'мяч —' : 'мяч ✓'}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _statsStrip() {
    final rawReportStats = _report?['stats'];
    final Map<String, dynamic> stats = _frame?.stats ??
        (rawReportStats is Map
            ? Map<String, dynamic>.from(rawReportStats)
            : const <String, dynamic>{});
    final items = <String, dynamic>{
      'Владение': stats['possession'] == null ? '—' : '${stats['possession']}%',
      'Передачи': stats['passes'] ?? 0,
      'Удары': stats['shots'] ?? 0,
      'В створ': stats['shots_on_target'] ?? 0,
      'Голы': stats['goals'] ?? 0,
      'GPS': stats['telemetry_players_count'] ?? 0,
      'Polar': stats['polar_players_count'] ?? 0,
    };
    return SizedBox(
      height: 72,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: items.entries.map((entry) => Container(width: 95, padding: const EdgeInsets.symmetric(vertical: 10), child: Column(children: [Text(entry.value.toString(), style: const TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w900)), Text(entry.key, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700))]))).toList()),
    );
  }

  Widget _sidePanel() {
    return DefaultTabController(
      length: 3,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
        child: Column(children: [
          const TabBar(labelColor: green, unselectedLabelColor: muted, indicatorColor: green, tabs: [Tab(text: 'События'), Tab(text: 'Подсказки'), Tab(text: 'GPS / Polar')]),
          Expanded(child: TabBarView(children: [_eventsList(), _adviceList(), _telemetryList()])),
        ]),
      ),
    );
  }

  Widget _eventsList() {
    if (_events.isEmpty) return _empty('AI-события появятся во время матча');
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _events.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final event = _events[index];
        final id = (event['id'] ?? '').toString();
        final status = (event['status'] ?? 'review_required').toString();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 42, padding: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(color: green.withOpacity(.1), borderRadius: BorderRadius.circular(8)), child: Text(_minute(event['time_ms']), textAlign: TextAlign.center, style: const TextStyle(color: green, fontSize: 10, fontWeight: FontWeight.w900))),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_eventName(event['event_type']), style: const TextStyle(color: ink, fontWeight: FontWeight.w800)), Text('${(_double(event['confidence']) * 100).round()}% · ${status == 'review_required' ? 'нужна проверка' : status}', style: const TextStyle(color: muted, fontSize: 10))])),
            if (status == 'review_required' && id.isNotEmpty) ...[
              IconButton(tooltip: 'Подтвердить и добавить в датасет', onPressed: () => _service.reviewEvent(eventId: id, confirmed: true, coachId: widget.coachId), icon: const Icon(Icons.check_circle, color: green, size: 21)),
              IconButton(tooltip: 'Отклонить', onPressed: () => _service.reviewEvent(eventId: id, confirmed: false, coachId: widget.coachId), icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 21)),
            ],
          ]),
        );
      },
    );
  }

  Widget _adviceList() {
    if (_advice.isEmpty) return _empty('Здесь появятся подсказки тренеру с причиной');
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _advice.length,
      itemBuilder: (_, index) {
        final item = _advice[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: green.withOpacity(.065), borderRadius: BorderRadius.circular(10), border: Border.all(color: green.withOpacity(.18))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((item['title'] ?? 'Наблюдение').toString(), style: const TextStyle(color: ink, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text((item['message'] ?? '').toString(), style: const TextStyle(color: ink, fontSize: 12)), if ((item['reason'] ?? '').toString().isNotEmpty) ...[const SizedBox(height: 5), Text('Почему: ${item['reason']}', style: const TextStyle(color: muted, fontSize: 10))]]),
        );
      },
    );
  }

  Widget _telemetryList() {
    final players = MatchLiveScreen._mapList(_telemetry['players']);
    if (players.isEmpty) return _empty('Ожидаю GPS-трекеры и Polar команды');
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: players.length,
      itemBuilder: (_, index) {
        final player = players[index];
        final name = (player['player_name'] ?? player['name'] ?? 'Игрок ${player['player_id'] ?? ''}').toString();
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: CircleAvatar(backgroundColor: green.withOpacity(.1), foregroundColor: green, child: Text((player['number'] ?? index + 1).toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          subtitle: Text('${_value(player, ['speed_kmh', 'current_speed_kmh'])} км/ч · ${_value(player, ['distance_m'])} м · нагрузка ${_value(player, ['load_score', 'load'])}', style: const TextStyle(fontSize: 10)),
          trailing: Text('${_value(player, ['heart_rate_bpm', 'current_hr'])} bpm', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900)),
        );
      },
    );
  }

  Widget _empty(String text) => Center(child: Padding(padding: const EdgeInsets.all(22), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: muted))));

  static String _minute(dynamic timeMs) {
    final seconds = MatchLiveScreen._int(timeMs) ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  static String _eventName(dynamic raw) {
    const names = {
      'pass': 'Передача',
      'interception': 'Перехват',
      'shot': 'Удар',
      'shot_on_target': 'Удар в створ',
      'goal': 'Гол',
      'ball_out': 'Мяч вне поля',
      'corner_candidate': 'Возможный угловой',
      'free_kick_candidate': 'Возможный штрафной',
    };
    final key = raw?.toString() ?? '';
    return names[key] ?? key.replaceAll('_', ' ');
  }

  static String _value(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().isNotEmpty) {
        if (value is num) return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
        return value.toString();
      }
    }
    return '0';
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
