import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_api_service.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsMatchesPanel extends StatefulWidget {
  final int clubId;
  final int userId;
  final int? selectedTeamId;
  final String selectedTeamName;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> matches;
  final bool canManage;
  final Future<void> Function() onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpenLive;

  const EsportsMatchesPanel({
    super.key,
    required this.clubId,
    required this.userId,
    required this.selectedTeamId,
    required this.selectedTeamName,
    required this.teams,
    required this.matches,
    required this.canManage,
    required this.onRefresh,
    required this.onOpenLive,
  });

  @override
  State<EsportsMatchesPanel> createState() => _EsportsMatchesPanelState();
}

class _EsportsMatchesPanelState extends State<EsportsMatchesPanel> {
  final _search = TextEditingController();
  Map<String, dynamic>? _selected;
  bool _createMode = false;
  String _filter = 'Все';

  @override
  void initState() {
    super.initState();
    _search.addListener(_rebuild);
    _sync();
  }

  @override
  void didUpdateWidget(covariant EsportsMatchesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matches.length != widget.matches.length ||
        oldWidget.selectedTeamId != widget.selectedTeamId) {
      _sync();
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _sync() {
    final base = _base;
    if (_selected != null) {
      final current = _id(_selected!);
      for (final match in base) {
        if (_id(match) == current) {
          _selected = match;
          return;
        }
      }
    }
    _selected = base.isNotEmpty ? base.first : null;
  }

  @override
  void dispose() {
    _search.removeListener(_rebuild);
    _search.dispose();
    super.dispose();
  }

  int _id(Map<String, dynamic> m) => esportsInt(m['id'] ?? m['match_id'] ?? m['matchId']);
  int _teamId(Map<String, dynamic> m) => esportsInt(m['team_id'] ?? m['teamId']);

  List<Map<String, dynamic>> get _base => widget.matches.where((m) {
        if ((widget.selectedTeamId ?? 0) <= 0) return true;
        final id = _teamId(m);
        return id <= 0 || id == widget.selectedTeamId;
      }).toList(growable: false);

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _base.where((m) {
      final status = esportsText(m['status']).toLowerCase();
      if (_filter == 'LIVE' && !(status == 'live' || status == 'on_air')) return false;
      if (_filter == 'Предстоящие' && !{'scheduled', 'upcoming', 'planned'}.contains(status)) return false;
      if (_filter == 'Завершённые' && !{'finished', 'completed', 'done'}.contains(status)) return false;
      if (q.isEmpty) return true;
      final hay = [
        _title(m),
        esportsText(m['game_title'] ?? m['game']),
        esportsText(m['tournament_name'] ?? m['tournament']),
        esportsText(m['score']),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList(growable: false);
  }

  String _title(Map<String, dynamic> m) {
    final title = esportsText(m['title']);
    if (title.isNotEmpty) return title;
    final home = esportsText(m['home_name'] ?? m['team_name']);
    final away = esportsText(m['away_name'] ?? m['opponent']);
    final joined = [home, away].where((e) => e.isNotEmpty).join(' — ');
    return joined.isEmpty ? 'Киберспортивный матч' : joined;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 680) return _phone();
        final leftWidth = c.maxWidth < 980 ? 330.0 : 430.0;
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: esportsCardDecoration(radius: 16),
              child: Row(
                children: [
                  SizedBox(width: leftWidth, child: _listPane()),
                  const SizedBox(width: 1, child: ColoredBox(color: EsportsColors.line)),
                  Expanded(child: _rightPane()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _phone() {
    if (_createMode) {
      return _MatchEditor(
        clubId: widget.clubId,
        actorUserId: widget.userId,
        selectedTeamId: widget.selectedTeamId,
        teams: widget.teams,
        onClose: () => setState(() => _createMode = false),
        onSaved: (_) async {
          setState(() => _createMode = false);
          await widget.onRefresh();
        },
      );
    }
    if (_selected != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          Row(children: [
            Expanded(child: EsportsPanelHeader(title: 'Матчи', subtitle: widget.selectedTeamName)),
            IconButton(onPressed: () => setState(() => _selected = null), icon: const Icon(Icons.list_alt_rounded)),
          ]),
          const SizedBox(height: 10),
          _details(_selected!),
        ],
      );
    }
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: _topControls(compact: true)),
      Expanded(child: _list()),
    ]);
  }

  Widget _listPane() => Column(
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 10), child: _topControls()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 9),
            child: TextField(controller: _search, style: esportsFieldTextStyle(), decoration: esportsInputDecoration('Поиск матча', icon: Icons.search_rounded)),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              children: [
                for (final f in const ['Все', 'Предстоящие', 'LIVE', 'Завершённые']) ...[
                  _filterChip(f),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: EsportsColors.line),
          Expanded(child: _list()),
        ],
      );

  Widget _topControls({bool compact = false}) => Row(
        children: [
          Expanded(
            child: EsportsPanelHeader(
              title: 'Матчи',
              subtitle: widget.selectedTeamName.trim().isEmpty ? 'Календарь и результаты Esports' : widget.selectedTeamName,
            ),
          ),
          if (widget.canManage)
            compact
                ? IconButton(onPressed: () => setState(() => _createMode = true), icon: const Icon(Icons.add_rounded, color: EsportsColors.greenDark))
                : EsportsActionButton(icon: Icons.add_rounded, label: 'Матч', onTap: () => setState(() => _createMode = true)),
        ],
      );

  Widget _filterChip(String value) {
    final active = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: active ? EsportsColors.greenSoft : EsportsColors.soft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(value, style: AppTypography.custom(size: 10, weight: active ? FontWeight.w600 : FontWeight.w500, color: active ? EsportsColors.greenDark : EsportsColors.muted)),
      ),
    );
  }

  Widget _list() {
    final list = _visible;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_base.isEmpty ? 'Матчей пока нет' : 'Ничего не найдено', style: AppTypography.captionMedium(color: EsportsColors.muted)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 5),
      itemBuilder: (_, index) {
        final m = list[index];
        final active = _selected != null && _id(_selected!) == _id(m);
        final status = esportsText(m['status']).toLowerCase();
        final isLive = status == 'live' || status == 'on_air';
        return Material(
          color: active ? EsportsColors.greenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: () => setState(() => _selected = m),
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(color: active ? Colors.white : EsportsColors.soft, borderRadius: BorderRadius.circular(11)),
                    child: Icon(isLive ? Icons.sensors_rounded : Icons.stadium_outlined, color: isLive ? EsportsColors.red : EsportsColors.greenDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_title(m), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.action(color: EsportsColors.text)),
                      const SizedBox(height: 3),
                      Text([
                        esportsText(m['score']),
                        esportsText(m['game_title'] ?? m['game']),
                        esportsText(m['start_at'] ?? m['date']),
                      ].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.captionMedium(color: EsportsColors.muted)),
                    ]),
                  ),
                  if (isLive) const EsportsStatusPill(label: 'LIVE', danger: true) else const Icon(Icons.chevron_right_rounded, size: 18, color: EsportsColors.subtle),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rightPane() {
    if (_createMode) {
      return _MatchEditor(
        clubId: widget.clubId,
        actorUserId: widget.userId,
        selectedTeamId: widget.selectedTeamId,
        teams: widget.teams,
        onClose: () => setState(() => _createMode = false),
        onSaved: (m) async {
          setState(() {
            _createMode = false;
            _selected = m;
          });
          await widget.onRefresh();
        },
      );
    }
    if (_selected == null) {
      return EsportsEmptyState(
        icon: Icons.stadium_outlined,
        title: 'Выберите матч',
        text: 'Справа будут счёт, турнир, статус трансляции, VOD, Live AI и итоговый AI Match Report.',
        action: widget.canManage ? EsportsActionButton(icon: Icons.add_rounded, label: 'Добавить матч', onTap: () => setState(() => _createMode = true)) : null,
      );
    }
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 100), child: _details(_selected!));
  }

  Widget _details(Map<String, dynamic> m) {
    final status = esportsText(m['status']).toLowerCase();
    final isLive = status == 'live' || status == 'on_air';
    final finished = {'finished', 'completed', 'done'}.contains(status);
    final recording = esportsText(m['recording_url'] ?? m['vod_url']).isNotEmpty;
    final aiReady = esportsBool(m['ai_ready']) || esportsText(m['ai_status']).toLowerCase() == 'ready';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(color: isLive ? EsportsColors.redSoft : EsportsColors.greenSoft, borderRadius: BorderRadius.circular(15)), child: Icon(isLive ? Icons.sensors_rounded : Icons.stadium_outlined, color: isLive ? EsportsColors.red : EsportsColors.greenDark, size: 27)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title(m), style: AppTypography.custom(size: 20, weight: FontWeight.w600, color: EsportsColors.text)),
            const SizedBox(height: 4),
            Text([
              esportsText(m['tournament_name'] ?? m['tournament']),
              esportsText(m['game_title'] ?? m['game']),
              esportsText(m['start_at'] ?? m['date']),
            ].where((e) => e.isNotEmpty).join(' · '), style: AppTypography.captionMedium(color: EsportsColors.muted)),
          ])),
          EsportsStatusPill(label: isLive ? 'LIVE' : finished ? 'Завершён' : 'Запланирован', active: !finished && !isLive, danger: isLive),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(esportsText(m['home_name'] ?? m['team_name']).isEmpty ? widget.selectedTeamName : esportsText(m['home_name'] ?? m['team_name']), style: AppTypography.action(color: EsportsColors.text)),
            const SizedBox(width: 18),
            Text(esportsText(m['score']).isEmpty ? '— : —' : esportsText(m['score']), style: AppTypography.custom(size: 27, weight: FontWeight.w700, color: EsportsColors.text)),
            const SizedBox(width: 18),
            Text(esportsText(m['away_name'] ?? m['opponent']).isEmpty ? 'Соперник' : esportsText(m['away_name'] ?? m['opponent']), style: AppTypography.action(color: EsportsColors.text)),
          ]),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (isLive)
            EsportsActionButton(icon: Icons.sensors_rounded, label: 'Открыть Live + AI', onTap: () => widget.onOpenLive(m), danger: true)
          else if (!finished)
            EsportsActionButton(icon: Icons.videocam_outlined, label: 'Подготовить эфир', onTap: () => widget.onOpenLive(m)),
          EsportsActionButton(icon: Icons.video_library_outlined, label: recording ? 'Смотреть VOD' : 'Запись не готова', onTap: recording ? () {} : null, primary: false),
          EsportsActionButton(icon: Icons.auto_awesome_rounded, label: aiReady ? 'AI Match Report' : 'AI после матча', onTap: aiReady ? () {} : null, primary: false),
        ]),
        const SizedBox(height: 14),
        _statGrid(m),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: esportsCardDecoration(radius: 13),
          child: Text(
            'Цикл матча: запланирован → подготовка стрима → LIVE + Live AI → завершён → сохранение VOD → полный AI-анализ.',
            style: AppTypography.custom(size: 11.5, weight: FontWeight.w400, color: EsportsColors.muted, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _statGrid(Map<String, dynamic> m) {
    final values = <List<String>>[
      ['Владение', esportsText(m['possession']).isEmpty ? '—' : esportsText(m['possession'])],
      ['Удары', esportsText(m['shots']).isEmpty ? '—' : esportsText(m['shots'])],
      ['xG', esportsText(m['xg']).isEmpty ? '—' : esportsText(m['xg'])],
      ['Передачи', esportsText(m['pass_accuracy']).isEmpty ? '—' : esportsText(m['pass_accuracy'])],
    ];
    return LayoutBuilder(builder: (context, c) {
      final width = (c.maxWidth - 9) / 2;
      return Wrap(spacing: 9, runSpacing: 9, children: values.map((v) => SizedBox(width: width, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(12)), child: Row(children: [Expanded(child: Text(v[0], style: AppTypography.captionMedium(color: EsportsColors.muted))), Text(v[1], style: AppTypography.action(color: EsportsColors.text))])))).toList());
    });
  }
}

class _MatchEditor extends StatefulWidget {
  final int clubId;
  final int actorUserId;
  final int? selectedTeamId;
  final List<Map<String, dynamic>> teams;
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onSaved;

  const _MatchEditor({required this.clubId, required this.actorUserId, required this.selectedTeamId, required this.teams, required this.onClose, required this.onSaved});

  @override
  State<_MatchEditor> createState() => _MatchEditorState();
}

class _MatchEditorState extends State<_MatchEditor> {
  final _opponent = TextEditingController();
  final _tournament = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController();
  int? _teamId;
  String _game = 'EA Sports FC';
  String _platform = 'Cross-platform';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _teamId = widget.selectedTeamId ?? (widget.teams.isNotEmpty ? esportsInt(widget.teams.first['id'] ?? widget.teams.first['team_id']) : null);
  }

  @override
  void dispose() {
    _opponent.dispose();
    _tournament.dispose();
    _date.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if ((_teamId ?? 0) <= 0 || _opponent.text.trim().isEmpty) {
      setState(() => _error = 'Выберите команду и укажите соперника.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, dynamic>{
      'club_id': widget.clubId,
      'actor_user_id': widget.actorUserId,
      'team_id': _teamId,
      'opponent': _opponent.text.trim(),
      'tournament_name': _tournament.text.trim(),
      'game_title': _game,
      'platform': _platform,
      'date': _date.text.trim(),
      'time': _time.text.trim(),
      'status': 'scheduled',
      'ai_enabled': true,
      'recording_enabled': true,
    };
    final result = await EsportsApiService.createMatch(payload);
    if (!mounted) return;
    if (result['success'] != true && result['status'] != 'success') {
      setState(() {
        _saving = false;
        _error = esportsText(result['message'] ?? result['error']).isEmpty ? 'Не удалось создать матч.' : esportsText(result['message'] ?? result['error']);
      });
      return;
    }
    final raw = result['match'] ?? result['data'];
    widget.onSaved(<String, dynamic>{...payload, if (raw is Map) ...Map<String, dynamic>.from(raw)});
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EsportsPanelHeader(title: 'Новый матч', subtitle: 'Матч сразу готов к подключению Live, записи и ИИ', trailing: IconButton(onPressed: _saving ? null : widget.onClose, icon: const Icon(Icons.close_rounded))),
        const SizedBox(height: 16),
        if (widget.teams.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<int>(
              style: esportsFieldTextStyle(),
              value: _teamId,
              decoration: esportsInputDecoration('Команда', icon: Icons.groups_2_outlined),
              items: widget.teams.map((team) {
                final id = esportsInt(team['id'] ?? team['team_id']);
                final name = esportsText(team['name'] ?? team['team_name']);
                return DropdownMenuItem<int>(value: id, child: Text(name.isEmpty ? 'Команда #$id' : name, style: esportsFieldTextStyle()));
              }).where((e) => e.value != null && e.value! > 0).toList(),
              onChanged: (v) => setState(() => _teamId = v),
            ),
          ),
        _field(_opponent, 'Соперник'),
        _field(_tournament, 'Турнир / лига'),
        _two(
          _dropdown('Игра', _game, const ['EA Sports FC', 'eFootball'], (v) => setState(() => _game = v)),
          _dropdown('Платформа', _platform, const ['Cross-platform', 'PlayStation 5', 'Xbox Series', 'PC', 'Nintendo Switch'], (v) => setState(() => _platform = v)),
        ),
        _two(_field(_date, 'Дата YYYY-MM-DD'), _field(_time, 'Время HH:MM')),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: EsportsColors.greenSoft, borderRadius: BorderRadius.circular(12)),
          child: Text('Для матча будут доступны: OBS/стрим, запись VOD, Live AI и автоматический AI Match Report после завершения.', style: AppTypography.custom(size: 11, weight: FontWeight.w500, color: EsportsColors.greenDark, height: 1.35)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppTypography.custom(size: 11, weight: FontWeight.w500, color: EsportsColors.red)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: EsportsActionButton(icon: Icons.close_rounded, label: 'Отмена', onTap: _saving ? null : widget.onClose, primary: false)),
          const SizedBox(width: 9),
          Expanded(flex: 2, child: EsportsActionButton(icon: Icons.add_rounded, label: _saving ? 'Создаём…' : 'Создать матч', onTap: _saving ? null : _save)),
        ]),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, style: esportsFieldTextStyle(), decoration: esportsInputDecoration(label)));
  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          style: esportsFieldTextStyle(),
          value: value,
          isExpanded: true,
          decoration: esportsInputDecoration(label),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      overflow: TextOverflow.ellipsis,
                      style: esportsFieldTextStyle(),
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
  Widget _two(Widget a, Widget b) => LayoutBuilder(builder: (context, c) => c.maxWidth < 560 ? Column(children: [a, b]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]));
}
