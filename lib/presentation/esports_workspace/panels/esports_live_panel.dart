import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_api_service.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsLivePanel extends StatefulWidget {
  final int clubId;
  final int userId;
  final int? selectedTeamId;
  final String selectedTeamName;
  final List<Map<String, dynamic>> matches;
  final Map<String, dynamic>? initialMatch;
  final bool canManage;
  final Future<void> Function() onRefresh;

  const EsportsLivePanel({
    super.key,
    required this.clubId,
    required this.userId,
    required this.selectedTeamId,
    required this.selectedTeamName,
    required this.matches,
    required this.initialMatch,
    required this.canManage,
    required this.onRefresh,
  });

  @override
  State<EsportsLivePanel> createState() => _EsportsLivePanelState();
}

class _EsportsLivePanelState extends State<EsportsLivePanel> {
  Timer? _pollTimer;
  Map<String, dynamic>? _match;
  Map<String, dynamic>? _stream;
  List<Map<String, dynamic>> _events = const [];
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _match = widget.initialMatch ?? _findLiveOrNext();
    _loadCurrent();
  }

  @override
  void didUpdateWidget(covariant EsportsLivePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMatch != oldWidget.initialMatch && widget.initialMatch != null) {
      _match = widget.initialMatch;
      _stream = null;
      _events = const [];
      _loadCurrent();
    }
  }

  Map<String, dynamic>? _findLiveOrNext() {
    for (final m in widget.matches) {
      final status = esportsText(m['status']).toLowerCase();
      if (status == 'live' || status == 'on_air') return m;
    }
    return widget.matches.isNotEmpty ? widget.matches.first : null;
  }

  int _matchId(Map<String, dynamic>? m) => esportsInt(m?['id'] ?? m?['match_id']);
  int get _streamId => esportsInt(_stream?['id'] ?? _stream?['stream_id']);

  Future<void> _loadCurrent() async {
    _pollTimer?.cancel();
    if (!mounted) return;
    setState(() => _error = null);

    final matchId = _matchId(_match);
    if (matchId <= 0) return;

    final list = await EsportsApiService.streams(
      clubId: widget.clubId,
      teamId: widget.selectedTeamId,
    );
    if (!mounted) return;

    Map<String, dynamic>? current;
    for (final s in list) {
      if (esportsInt(s['match_id']) == matchId) {
        current = s;
        break;
      }
    }
    setState(() => _stream = current);
    _startPollingIfNeeded();
  }

  void _startPollingIfNeeded() {
    _pollTimer?.cancel();
    final status = esportsText(_stream?['status']).toLowerCase();
    if (_streamId <= 0 || !(status == 'live' || status == 'on_air')) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    _poll();
  }

  Future<void> _poll() async {
    if (_streamId <= 0) return;
    final status = await EsportsApiService.streamStatus(_streamId);
    final events = await EsportsApiService.liveAiEvents(_streamId);
    if (!mounted) return;
    setState(() {
      if (status['success'] == true) {
        final raw = status['stream'] ?? status['data'];
        if (raw is Map) _stream = Map<String, dynamic>.from(raw);
      }
      _events = events;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    final matchId = _matchId(_match);
    if (matchId <= 0) {
      setState(() => _error = 'Сначала создайте и выберите матч.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    final result = await EsportsApiService.prepareStream({
      'club_id': widget.clubId,
      'actor_user_id': widget.userId,
      'team_id': widget.selectedTeamId,
      'match_id': matchId,
      'source_type': 'obs',
      'recording_enabled': true,
      'ai_enabled': true,
      'game_title': esportsText(_match?['game_title'] ?? _match?['game']),
    });
    if (!mounted) return;
    if (result['success'] != true && result['status'] != 'success') {
      setState(() {
        _working = false;
        _error = esportsText(result['message'] ?? result['error']).isEmpty
            ? 'Не удалось подготовить эфир.'
            : esportsText(result['message'] ?? result['error']);
      });
      return;
    }
    final raw = result['stream'] ?? result['data'];
    setState(() {
      _stream = raw is Map ? Map<String, dynamic>.from(raw) : Map<String, dynamic>.from(result);
      _working = false;
    });
  }

  Future<void> _start() async {
    if (_streamId <= 0) return;
    setState(() {
      _working = true;
      _error = null;
    });
    final result = await EsportsApiService.startStream({
      'stream_id': _streamId,
      'club_id': widget.clubId,
      'actor_user_id': widget.userId,
    });
    if (!mounted) return;
    if (result['success'] != true && result['status'] != 'success') {
      setState(() {
        _working = false;
        _error = esportsText(result['message'] ?? result['error']);
      });
      return;
    }
    final raw = result['stream'] ?? result['data'];
    setState(() {
      if (raw is Map) _stream = Map<String, dynamic>.from(raw);
      _working = false;
    });
    _startPollingIfNeeded();
    await widget.onRefresh();
  }

  Future<void> _stop() async {
    if (_streamId <= 0) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Завершить эфир?'),
            content: const Text(
              'Запись будет сохранена, после чего Sportoteka запустит полный AI Match Report.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Отмена')),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Завершить')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() {
      _working = true;
      _error = null;
    });
    final result = await EsportsApiService.stopStream({
      'stream_id': _streamId,
      'club_id': widget.clubId,
      'actor_user_id': widget.userId,
      'generate_ai_report': true,
      'save_recording': true,
    });
    if (!mounted) return;
    if (result['success'] != true && result['status'] != 'success') {
      setState(() {
        _working = false;
        _error = esportsText(result['message'] ?? result['error']);
      });
      return;
    }
    _pollTimer?.cancel();
    final raw = result['stream'] ?? result['data'];
    setState(() {
      if (raw is Map) _stream = Map<String, dynamic>.from(raw);
      _working = false;
    });
    await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final match = _match;
    if (match == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
        children: const [
          EsportsEmptyState(
            icon: Icons.sensors_rounded,
            title: 'Для эфира нужен матч',
            text: 'Создайте матч в разделе «Матчи», затем откройте его и нажмите «Подготовить эфир».',
          ),
        ],
      );
    }

    final status = esportsText(_stream?['status']).toLowerCase();
    final live = status == 'live' || status == 'on_air';
    final prepared = _streamId > 0 && !live && status != 'finished' && status != 'completed';
    final finished = status == 'finished' || status == 'completed';
    final streamUrl = esportsText(_stream?['rtmp_url'] ?? _stream?['ingest_url']);
    final streamKey = esportsText(_stream?['stream_key']);

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 900;
        final video = _videoWorkspace(match, live: live, prepared: prepared, finished: finished, streamUrl: streamUrl, streamKey: streamKey);
        final ai = _aiPane(live: live);
        if (narrow) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 108),
            children: [
              SizedBox(height: 620, child: video),
              const SizedBox(height: 10),
              SizedBox(height: 520, child: ai),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 96),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 7, child: video),
              const SizedBox(width: 10),
              SizedBox(width: 360, child: ai),
            ],
          ),
        );
      },
    );
  }

  Widget _videoWorkspace(
    Map<String, dynamic> match, {
    required bool live,
    required bool prepared,
    required bool finished,
    required String streamUrl,
    required String streamKey,
  }) {
    return Container(
      decoration: esportsCardDecoration(radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: EsportsColors.line)),
            ),
            child: Row(children: [
              if (live) const EsportsStatusPill(label: '● LIVE', danger: true) else EsportsStatusPill(label: finished ? 'Завершён' : prepared ? 'OBS готов' : 'Подготовка', active: prepared),
              const SizedBox(width: 10),
              Expanded(child: Text(_matchTitle(match), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.action(color: EsportsColors.text))),
              if (_working)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: EsportsColors.green)),
            ]),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 330),
              color: const Color(0xFF101418),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(live ? Icons.live_tv_rounded : Icons.sports_esports_rounded, color: Colors.white.withOpacity(.9), size: 58),
                  const SizedBox(height: 12),
                  Text(
                    live ? 'Прямой эфир Sportoteka Esports' : finished ? 'Эфир завершён · VOD обрабатывается' : 'Окно стрима',
                    style: AppTypography.custom(size: 16, weight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    live ? 'Игровой поток + запись + Live AI' : 'Источник OBS / RTMP',
                    style: AppTypography.custom(size: 11, weight: FontWeight.w400, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!live && !finished && _streamId <= 0)
                  EsportsActionButton(
                    icon: Icons.settings_input_antenna_rounded,
                    label: 'Подготовить OBS / RTMP',
                    onTap: widget.canManage && !_working ? _prepare : null,
                  ),
                if (prepared && !live) ...[
                  _credential('RTMP сервер', streamUrl, obscure: false),
                  const SizedBox(height: 7),
                  _credential('Stream Key', streamKey, obscure: true),
                  const SizedBox(height: 10),
                  EsportsActionButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Начать эфир',
                    onTap: widget.canManage && !_working ? _start : null,
                  ),
                ],
                if (live)
                  Row(children: [
                    Expanded(child: EsportsActionButton(icon: Icons.bookmark_add_outlined, label: 'Сохранить момент', onTap: widget.canManage ? () {} : null, primary: false)),
                    const SizedBox(width: 8),
                    Expanded(child: EsportsActionButton(icon: Icons.stop_rounded, label: 'Завершить эфир', onTap: widget.canManage && !_working ? _stop : null, danger: true)),
                  ]),
                if (finished)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: EsportsColors.greenSoft, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      'Запись сохраняется в Видеоцентре. Полный AI Match Report запускается автоматически после завершения эфира.',
                      style: AppTypography.custom(size: 11, weight: FontWeight.w500, color: EsportsColors.greenDark, height: 1.35),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 9),
                  Text(_error!, style: AppTypography.custom(size: 11, weight: FontWeight.w500, color: EsportsColors.red)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _credential(String label, String value, {required bool obscure}) {
    final shown = value.isEmpty ? 'Сервер вернёт после подготовки эфира' : (obscure ? '••••••••••••••••' : value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(11)),
      child: Row(children: [
        SizedBox(width: 92, child: Text(label, style: AppTypography.captionMedium(color: EsportsColors.muted))),
        Expanded(child: Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.action(color: EsportsColors.text))),
        if (value.isNotEmpty)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label скопирован')));
            },
            icon: const Icon(Icons.copy_rounded, size: 17, color: EsportsColors.muted),
          ),
      ]),
    );
  }

  Widget _aiPane({required bool live}) {
    return Container(
      decoration: esportsCardDecoration(radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: EsportsColors.line))),
            child: Row(children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: EsportsColors.greenSoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.auto_awesome_rounded, size: 18, color: EsportsColors.greenDark)),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LIVE AI', style: AppTypography.action(color: EsportsColors.text)),
                const SizedBox(height: 2),
                Text(live ? 'Анализ потока в реальном времени' : 'Запустится вместе с эфиром', style: AppTypography.captionMedium(color: EsportsColors.muted)),
              ])),
              EsportsStatusPill(label: live ? 'AI ON' : 'Ожидание', active: live),
            ]),
          ),
          Expanded(
            child: _events.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Text(
                        live
                            ? 'ИИ получает видеопоток. События появятся здесь автоматически.'
                            : 'Во время эфира здесь будут голы, опасные моменты, потери, смены схемы и краткие подсказки.',
                        textAlign: TextAlign.center,
                        style: AppTypography.custom(size: 11.5, weight: FontWeight.w400, color: EsportsColors.muted, height: 1.4),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (_, index) => _eventCard(_events[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final time = esportsText(event['match_time'] ?? event['timecode'] ?? event['time']);
    final type = esportsText(event['type'] ?? event['event_type']);
    final text = esportsText(event['text'] ?? event['message'] ?? event['summary']);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(11)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 5), decoration: const BoxDecoration(color: EsportsColors.green, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text([time, type].where((e) => e.isNotEmpty).join(' · '), style: AppTypography.custom(size: 9.8, weight: FontWeight.w600, color: EsportsColors.greenDark)),
          const SizedBox(height: 3),
          Text(text.isEmpty ? 'Событие ИИ' : text, style: AppTypography.custom(size: 11, weight: FontWeight.w400, color: EsportsColors.text, height: 1.35)),
        ])),
      ]),
    );
  }

  String _matchTitle(Map<String, dynamic> match) {
    final title = esportsText(match['title']);
    if (title.isNotEmpty) return title;
    final parts = [esportsText(match['team_name']), esportsText(match['opponent'])].where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? 'Киберспортивный матч' : parts.join(' — ');
  }
}
